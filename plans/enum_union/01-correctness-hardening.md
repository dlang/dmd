# Enum Union Correctness Hardening

## Goal

Fix the correctness, lifecycle, parser, header-generation, and diagnostic issues found in the review of commits `e174f31^..44ebdcb` without changing switch-expression lowering architecture. This plan must land and pass before the lowering redesign in `02-switch-statement-lowering.md` begins.

## Current State (verified at `44ebdcb`)

- The compiler builds successfully with `make dmd -j$(nproc)`.
- The feature-focused test set has seven failing targets, mostly stale expected diagnostics plus duplicate-symbol cascades.
- Payload positions currently accept literals and arbitrary expressions. This creates equality, evaluation-order, side-effect, and usefulness-analysis problems even though guards provide the same runtime expressiveness.
- Implicit conversion to an enum union skips payload copy constructors.
- If payload construction throws, the generated enum-union destructor can run for a payload that was never constructed.
- User code can assign the synthesized `.__tag` field and make destruction target the wrong variant or skip a live payload.
- Tuple-unpacking machinery exists for declarations, foreach variables, and function-literal parameters, but switch patterns do not reuse it.
- `-H` crashes when a switch expression contains parser container arms for `static foreach` or `static if`.
- Qualified type patterns with bindings do not parse.
- Variant UDAs are omitted from generated `.di` files.
- `enum union E : int` is accepted but the base type is discarded.
- The formal specification documents `case Red;` as a unit variant, while the parser deliberately requires `case Red()`.

## Constraints

1. Do not touch glue or backend code.
2. Keep the existing conditional-expression lowering until this plan is complete.
3. Generated AST must pass through normal semantic analysis; do not manually assign `.type` as a substitute for semantic rewriting.
4. Preserve source evaluation order and evaluate the switch condition exactly once.
5. Expose `.__tag` as a readable, non-addressable property while keeping its physical storage unavailable to source code.
6. Add a regression test before or with each behavioral fix.
7. Patterns select variants and introduce bindings; guards test values. Payload pattern positions do not execute user expressions.

## Implementation Tasks

### 1. Establish a clean baseline

- Update stale `TEST_OUTPUT` locations and diagnostics in the seven currently failing feature tests only after confirming each actual diagnostic is intended.
- Prevent duplicate named cases from entering member synthesis after the primary duplicate-case diagnostic. Do not merely add the cascading duplicate-symbol errors to expected output.
- Fix the two whitespace errors reported by `git diff --check`.
- Run every test added or changed in the feature range and record a clean baseline before behavioral edits.

Validation:

```console
cd compiler/test
tests=$(git -C ../.. diff --name-only e174f31^..44ebdcb -- compiler/test \
    | sed 's#^compiler/test/##' \
    | grep -E '^(compilable|runnable|fail_compilation)/.*\.d$' \
    | tr '\n' ' ')
./run.d $tests
```

### 2. Separate the public tag property from its storage

Files: `parse.d`, `typesem.d` or the owning member-lookup path, `traits.d`, tests.

- Preserve `value.__tag` as supported read access. It should produce a non-lvalue discriminant value that can be compared with `__traits(getTag, T, V)`.
- Reject assignment, compound assignment, increment/decrement, `ref` binding, and taking a mutable address through `value.__tag`.
- Do not make the physical field `const`: a const data member would change assignment and initialization semantics for the entire enum-union value.
- Split the implementation conceptually into a public compiler property named `__tag` and hidden backing storage. `EnumUnionDeclaration.tagVar` remains the compiler's direct handle to that storage.
- Mark the backing field explicitly as an enum-union implementation field. Prefer a dedicated declaration flag or owner relationship over recognizing a generated spelling.
- Source lookup of `__tag` should synthesize an rvalue read of `eu.tagVar`; compiler-generated code continues to use direct `DotVarExp` references to `eu.tagVar`.
- Ensure casts cannot accidentally obtain a mutable pointer through ordinary safe access. Explicit unsafe casts may retain D's normal ability to cast away qualifiers.

Reflection and header policy:

- Include `"__tag"` in `__traits(allMembers, T)`. It is an intentional, documented user-facing member name, and `allMembers` includes callable/property API as well as fields.
- Make `__traits(hasMember, T, "__tag")` and `__traits(getMember, value, "__tag")` work with the same read-only semantics.
- Exclude the physical backing field from `.tupleof`, field iteration, aggregate initialization, and field-oriented traits. It is representation, comparable to compiler-hidden class storage, not a logical payload field.
- Do not print a separate backing-field declaration in `.di` files. The emitted `enum union` declaration causes an importing compiler to recreate both storage and the `__tag` property.
- Do not print a synthetic getter declaration either unless enum-union declarations are later lowered to plain structs in `.di` output. Avoid representing one API twice.
- Document `__tag` as a read-only discriminant property, not as a mutable field or a promise about physical layout.

Tests:

- Direct reads work for mutable, `const`, `immutable`, and `shared` values.
- Direct and compound writes fail, including from the declaring module.
- Taking a mutable address and binding `ref` to `.__tag` fail.
- `__traits(allMembers)` contains exactly one `"__tag"` entry.
- `hasMember` and `getMember` expose the read-only property.
- `.tupleof` and field-oriented reflection exclude the backing storage.
- A generated `.di` can be imported and still provides readable, non-writable `.__tag`.
- Destruction remains correct for every variant.
- Existing tag reflection continues to work.

### 3. Centralize construction and restore value semantics

Files: `dcast.d`, `dsymbolsem.d`, optionally a small shared helper in the nearest owning frontend module.

- Replace the manually typed `ConstructExp` sequence in `constructEnumUnionVariant` with generated AST that is passed through normal semantic analysis.
- Use one construction strategy for implicit conversions and synthesized factories so they cannot diverge.
- Fully evaluate and construct the source payload before committing the enum-union discriminant.
- Construct into a staging aggregate that cannot run the enum-union destructor while incomplete (`STC.nodtor` or an equivalent established DMD mechanism).
- Set the tag only after the selected payload is fully constructed.
- Return/move the completed aggregate through normal return and copy/move lowering.
- Audit generated bare, positional, record, alias, and unit factories for the same exception window.
- Do not rely on raw bit copies for payloads with postblits or copy constructors.

Required tests:

- An lvalue payload invokes its copy constructor exactly once.
- An rvalue payload is moved/elided according to ordinary D rules.
- A throwing payload constructor does not invoke its destructor on uninitialized storage.
- Already-constructed payload temporaries are destroyed exactly once on failure.
- Record and positional variants containing elaborate structs behave identically.
- `const`, `immutable`, `shared`, static-array, and nested payloads retain qualifiers and lifecycle behavior.
- CTFE construction still works.

### 4. Restrict payload patterns to bindings and destructuring

Files: `parse.d`, `expression.d`, `expressionsem.d`, `decisiontree.d`, tests.

- Define payload-pattern positions as binding syntax, not expression syntax.
- Continue supporting positional bindings (`case Pair(x, y)`), record shorthand bindings (`case Item { x, y }`), renamed record bindings (`case Item { x: xBinding }`), rest bindings, and discard/wildcard syntax.
- Treat an identifier in a payload position unconditionally as a newly introduced binding; do not resolve it as an existing constant or variable.
- Reject literals, calls, operators, property access, and other expressions in positional and record payload positions with a focused diagnostic such as "value tests in patterns are not supported; bind the value and use an `if` guard".
- Express value tests through guards:

```d
case Item { x, y } if (x == 42 && y == 69) => action,
```

- Remove `CaseExpArm.patternChecks` and all generated payload `EqualExp` construction once no supported syntax needs them.
- Rewrite existing positive tests and documentation that use literal/expression payload patterns. Preserve equivalent behavior with bindings and guards.
- Keep variant identifiers, bare-type patterns, unit patterns, qualified patterns, and default arms unchanged.

Tests:

- Literal and arbitrary-expression positional patterns are rejected.
- Literal and arbitrary-expression record patterns are rejected.
- Renamed and shorthand record bindings remain valid and visible in guards/actions.
- An existing symbol with the same spelling as a binding does not turn the binding into a constant pattern.
- Guarded equivalents cover numbers, strings, enums, arrays, class references, and custom `opEquals` without special pattern semantics.

### 5. Simplify exhaustiveness and redundancy to variant coverage

Files: `decisiontree.d`, `expressionsem.d`, tests.

- Remove literal columns and `Expression.toString()` comparison from usefulness analysis.
- Because supported payload patterns only bind or discard values, they do not constrain coverage. Exhaustiveness is determined by enum-union variant coverage plus source `default`.
- A guarded arm does not cover its variant. A later unguarded arm for that variant does.
- An unguarded arm makes later arms for the same variant redundant; a source `default` makes all later arms redundant.
- Diagnose duplicate/unreachable arms in source order.
- Delete `decisiontree.d` if no remaining non-enum-union consumer requires the matrix algorithm; otherwise reduce its enum-union input to constructor-only patterns.
- Keep diagnostics phrased in source-level variant terms rather than synthetic payload columns.

Tests:

- Guarded arms alone do not prove coverage.
- A guarded arm followed by an unguarded arm for the same variant is valid.
- An arm after an unguarded arm for the same variant is redundant.
- Binding, rest, record, and tuple patterns do not alter variant coverage.
- Missing variants produce stable witness diagnostics.

### 6. Add tuple binding patterns by reusing unpack declarations

Files: `parse.d`, `attrib.d`, `dsymbolsem.d`, `expression.d`, `expressionsem.d`, `hdrgen.d`, tests.

- Do not gate switch tuple patterns on `-preview=tuples`. Reuse the implementation machinery without coupling the language-feature flags. If enum unions or switch expressions have their own feature gate, tuple patterns follow that gate only.
- Support nested tuple bindings wherever a selected payload component is tuple-like:

```d
case Wrapped((x, y)) => action,
case Record { point: (x, y), label } => action,
case Nested((head, (left, right))) => action,
```

- Positional variant argument lists remain variant destructuring. Parenthesized patterns nested inside an argument or record field denote tuple unpacking.
- Extract the recursive tuple-shape parser from `parseUnpackDeclaration` into a shared helper or add a pattern mode to it. Do not create a second tuple grammar.
- In pattern mode, bare identifiers imply `auto` bindings. Initially reject declaration-only storage classes, UDAs, explicit types, `ref`, `out`, and `auto ref`; those features have unclear matching semantics and can be added deliberately later.
- Represent each tuple binding with the existing `UnpackDeclaration` AST. Set its `_init` to the selected payload expression, place it in the arm-local scope, and invoke ordinary declaration semantic analysis so the existing `lowerUnpack` path performs tuple/sequence resolution.
- Reuse `lowerUnpack` behavior for alias-this tuples, expression sequences, arity diagnostics, nested unpacking, side-effect caching, inferred types, qualifiers, and declaration ownership.
- Do not copy `lowerUnpack` logic into `expressionsem.d`. If access is awkward, expose a narrowly scoped helper from the owning declaration-semantic module.
- Tuple patterns only introduce bindings; tuple elements cannot be literals or arbitrary expressions. Use a guard for value tests.
- Preserve the selected payload expression's single evaluation and declare each unpacked variable exactly once.
- Extend `CaseExpArm.syntaxCopy` and header/source printing for nested tuple pattern shapes.

Tests:

- Flat and recursively nested tuple patterns bind expected values.
- Tuple patterns work in positional variants and record fields.
- Alias-this tuple structs and expression-sequence payloads reuse declaration-unpacking behavior.
- Arity/type errors use the established unpack-declaration diagnostics where applicable.
- `const`, `immutable`, `shared`, and `scope` payload qualifiers propagate to bindings.
- Tuple payload access and alias-this expansion evaluate once.
- Bindings are visible in guards and actions but not in sibling arms.
- Tuple literals/expressions in binding positions are rejected and their guard equivalents work.

### 7. Correct side-effect analysis

File: `statementsem.d`.

- Replace the enum-union factory special case with recursive argument analysis: the generated call itself may be pure, but argument evaluation is not.
- Include the condition, binding initializers, guard, and action when deciding whether a discarded switch expression has an effect. Tuple-unpack caching must not hide initializer effects.
- Keep the diagnostic for genuinely effect-free switch expressions.

Tests:

- Side effects in factory arguments and tuple-binding initializers are accepted and run once.
- Pure construction with pure arms remains rejected when discarded.

### 8. Harden switch-expression parsing and printing

Files: `parse.d`, `hdrgen.d`, `expression.d`, tests.

- Extend type-pattern lookahead to recognize qualified types followed by a binding identifier.
- Reject `enum union` base types immediately with a focused diagnostic.
- Detect duplicate positional and shorthand binding names by checking scope insertion results and explicit field-use state.
- Reject value/expression payload patterns during parsing where possible, with recovery to the next arm delimiter.
- Teach `visitSwitch` to print or safely traverse `static foreach` and `static if` container arms before semantic flattening; never dereference a null `arm.action`.
- Emit variant UDAs before each case in generated headers.
- Add a generated-header round-trip test that compiles the `.di` and verifies UDA reflection.

Tests:

- `case package.Type value =>` parses and binds.
- Duplicate bindings produce one clear diagnostic.
- `-H` works for static foreach/static if arms.
- Variant UDAs survive generation and import.
- `enum union E : int` is rejected.

### 9. Reconcile the grammar and documentation

Files: `compiler/docs/enum union spec.md`, `compiler/docs/enum_union_guide.md`, syntax tests.

- Adopt the parser's unambiguous rule: named unit variants use `case Name()` and bare identifier forms denote types.
- Update grammar productions and every `case Red;`-style example.
- Specify that payload patterns contain bindings, discards, rest bindings, or nested tuple bindings only; all value predicates use `if` guards.
- Document tuple patterns as part of switch-expression pattern syntax, using the same recursive shape as unpack declarations without depending on their preview flag.
- Document `.__tag` as a read-only property and recommend comparing it with `__traits(getTag, T, V)` rather than hard-coded numeric values.
- Ensure declaration, reflection, pattern, and construction examples compile as documentation tests where practical.

### 10. Audit generated-node ownership and visitors

Files: `dstruct.d`, `visitor/parsetime.d`, relevant visitors.

- Add explicit `EnumUnionDeclaration` forwarding in parse-time/transitive visitors where consumers need to distinguish it from a plain struct.
- Replace positional assumptions such as `members[0]`/`members[1]` with `tagVar`, `payloadUnion`, and `variant.payloadVar` wherever possible.
- Verify `syntaxCopy` reconnects every synthesized declaration pointer, including payload declarations and the payload union, rather than retaining symbols from the source instance.
- Grep for bare `cast(EnumUnionDeclaration)` and require `isEnumUnionDeclaration()` for extern(C++) downcasts.

## Validation Matrix

Run after each task's narrow regression, then run all of the following at completion:

```console
make dmd -j$(nproc)
cd compiler/test
./run.d runnable/testenumunion.d
./run.d 'runnable/enum_union*.d'
./run.d 'compilable/enum_union*.d'
./run.d 'fail_compilation/enum_union*.d'
./run.d 'compilable/switch_expression*.d'
./run.d 'fail_compilation/switch_expression*.d'
./run.d runnable/unpacking.d fail_compilation/unpacking.d fail_compilation/unpack_semantic.d fail_compilation/unpacking_extern.d
./run.d unit_tests
git diff --check
```

Also build druntime and Phobos with the resulting compiler to catch accidental enum-union downcasts or aggregate-layout regressions.

## Exit Criteria

- No compiler crash or assertion for malformed or valid enum-union input.
- Enum-union construction obeys ordinary D copy/move/destruction semantics.
- Source programs can read `.__tag` but cannot mutate or alias its physical storage through ordinary language operations.
- Pattern bindings and destructuring preserve D evaluation order, qualifiers, and declaration semantics.
- The feature-focused suite and `git diff --check` are clean.
- The specification, guide, parser, and generated headers agree.

## Out of Scope

- Replacing conditional-expression lowering.
- Backend or glue changes.
- Niche optimization or discriminant elision.
- New projection or operator-forwarding features.
