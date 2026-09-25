# Frontend-Only Switch Statement Lowering

## Goal

Replace the enum-union switch expression's conditional-expression chain with a frontend-generated, immediately invoked function literal whose body contains an ordinary `SwitchStatement`. The existing glue and backend remain unchanged and choose branches or jump tables through the normal switch implementation.

This plan starts only after `01-correctness-hardening.md` is complete and green.

## Design Decision

Lower:

```d
auto result = switch (value)
{
    case Circle(radius) if (radius > 10) => large(radius),
    case Circle(radius) => small(radius),
    case Rectangle(width, height) => rectangle(width, height),
};
```

to the semantic equivalent of:

```d
auto result = delegate() {
    switch (value.__tag)
    {
        case CircleTag:
        {
            auto radius = value.circle.radius;
            if (radius > 10)
                return large(radius);
        }
        {
            auto radius = value.circle.radius;
            return small(radius);
        }
        case RectangleTag:
        {
            auto width = value.rectangle.width;
            auto height = value.rectangle.height;
            return rectangle(width, height);
        }
        default:
            assert(0);
    }
}();
```

The generated body references `tagVar` and payload declarations directly through compiler AST symbols. Source code sees the separate read-only `.__tag` property defined by the correctness plan, never the writable backing storage.

## Why This Shape

- It is frontend-only.
- It reuses normal statement semantic analysis, return lowering, equality rewriting, scope handling, CTFE, destructor insertion, and switch code generation.
- Dense enum-union tags naturally reach the backend's existing jump-table selection.
- One switch dispatch replaces repeated tag tests in a ternary chain.
- Guarded arms for one variant remain ordered inside one case.
- No new statement-expression AST node or glue visitor is required.

## Non-Goals

- Do not generate jump tables in the frontend.
- Do not add a general D statement-expression feature.
- Do not change source syntax, pattern syntax, or enum-union representation.
- Do not optimize payload-pattern dispatch beyond the ordinary frontend optimizer in the first implementation.

## Implementation Tasks

### 1. Add lowering-focused regression coverage first

Create tests that pass under the current implementation and must remain stable:

- Condition evaluated exactly once.
- Source arm priority with repeated variants and guards.
- Ordinary and nested tuple bindings are initialized before the guard and action.
- Value and `ref` results.
- `void` and `noreturn` arms.
- Elaborate return values with copy constructor, move constructor, postblit, and destructor counters.
- Captures of outer locals, `this`, nested-function context, and template parameters.
- `pure`, `nothrow`, `@safe`, `@nogc`, and `-betterC` contexts.
- CTFE and `static assert` evaluation.
- Tuple binding patterns, including alias-this tuple payloads and nested unpacking, independent of the regular declaration-unpacking preview flag.
- `scope`, DIP1000, and return-scope cases already supported by the old lowering.
- Debug, release, inline, and optimized configurations.

Keep the tests behavior-oriented; do not assert a particular backend instruction sequence except in a separate performance smoke check.

### 2. Split semantic analysis from executable AST construction

File: `expressionsem.d`; optionally introduce a small private helper module if the logic remains too large.

Refactor `visit(SwitchExp)` into explicit phases:

1. Semanticize and cache the condition once.
2. Expand static foreach/static if arms.
3. Resolve the enum-union type and variant declarations.
4. Normalize each source arm into compiler-owned pattern metadata.
5. Run exhaustiveness and redundancy analysis on that metadata.
6. Build an unsemanticized function body containing a `SwitchStatement`.
7. Semanticize the generated `CallExp` once in the original scope.

Do not semanticize arm actions or binding declarations in the outer function and then transplant them into the generated function. Their parent function, capture, return, destructor, and scope semantics must be established inside the generated function.

### 3. Introduce normalized arm metadata

Avoid using partially semanticized expression AST as both pattern description and executable code. Add a private normalized representation containing at least:

- Source location and source arm index.
- Variant index and variant declaration.
- Ordered payload field mappings.
- Ordinary binding names and types.
- Nested `UnpackDeclaration` binding shapes and their selected payload initializers.
- Guard expression.
- Action expression.
- Default-arm marker.
- Variant-coverage information produced by Plan 1.

The representation should retain syntax-copyable action and guard expressions plus binding-pattern AST until they are placed in the generated function body.

### 4. Create the inferred function literal

Follow the frontend precedent in `cparseStatementExpression` and `StaticForeach.wrapAndCall`:

- Create a `TypeFunction` with inferred return type and inferred attributes.
- Create a `FuncLiteralDeclaration` with `TOK.reserved` so normal semantic analysis infers delegate/function form and attributes.
- Set its body to the generated compound statement.
- Wrap it in `FuncExp`, then an empty-argument `CallExp`.
- Run `expressionSemantic(sc)` on the call and use that expression as the `SwitchExp` result.

Do not set `skipCodegen`: unlike CTFE-only wrappers, this function must execute at runtime.

Add an assertion or test that no `SwitchExp` reaches glue after successful semantic analysis.

### 5. Generate one switch case per variant tag

- Switch directly on a compiler-generated `DotVarExp(condition, eu.tagVar)`.
- Group normalized arms by variant index while preserving their source order within each group.
- Emit one `CaseStatement` for each variant represented by source arms.
- Emit a `DefaultStatement` only for impossible/corrupt tags or when needed for the source default path.
- Do not duplicate evaluation of the source condition.
- Use the existing tag type and exact integer values; do not introduce a second tag numbering scheme.

For a default source arm, prefer one shared return path after the switch rather than copying its action into every case:

```d
switch (tag)
{
    case ATag:
        // Try A arms, then break.
        break;
    case BTag:
        // Try B arms, then break.
        break;
    default:
        break;
}
return defaultAction;
```

Without a source default, emit a semantically analyzed unreachable assertion after the switch for defensive handling of invalid storage. Exhaustiveness guarantees that valid tags return from a case.

### 6. Generate arm-local bindings and guards

For each arm inside its variant case, emit a nested `CompoundStatement` so repeated binding names do not conflict:

1. Declare ordinary bindings in the arm scope.
2. For nested tuple patterns, emit the existing `UnpackDeclaration` initialized from the selected payload component and let ordinary declaration semantics lower it.
3. Evaluate the guard with all bindings visible.
4. Return the action when the guard succeeds, or unconditionally for an unguarded arm.
5. Continue to the next arm of the same tag when a guard fails.

Avoid reusing one `VarDeclaration` in multiple AST positions. Every generated binding declaration must have one owning `DeclarationExp`/declaration statement.

Do not flatten tuple bindings manually into `DotVarExp` chains in this lowering. Reuse the unpack declaration so alias-this tuples, expression sequences, nested arity checks, and temporary caching stay aligned with regular declarations.

### 7. Preserve return categories

The generated function must support:

- Value returns with ordinary copy/move/NRVO behavior.
- `ref` returns when every arm yields a compatible lvalue and the original switch expression is used as an lvalue.
- `void` results.
- Mixed ordinary and `noreturn` arms.
- Qualifier-preserving returns.

Use normal function semantic machinery to infer the common return type where possible. If DMD cannot infer the required `ref` category from the generated returns, set the function type's `STC.ref_` only after the existing switch-expression result-category analysis proves all reachable arms are valid ref results.

Do not lower through a shared result variable by default: that would add copies, complicate destruction, and lose `ref` identity.

### 8. Preserve captures and function attributes

- Let the inferred function literal capture condition/action dependencies normally.
- Verify immediate invocation does not cause GC allocation in `@nogc` code.
- Ensure captures of `scope` values cannot escape; the generated delegate is called immediately and never stored.
- Confirm inferred `pure`, `nothrow`, `@safe`, and `@nogc` attributes are no weaker than the enclosing expression requires.
- Verify diagnostics point to the source arm/action, not only to a generated function location.
- Test nested enum-union member functions using `switch (this)`.

If an immediately invoked delegate still allocates or causes attribute regressions, use an immediately invoked inferred `function` literal when there are no captures and retain a delegate only when captures are required. Do not work around failures in glue.

### 9. Simplify obsolete conditional lowering

After the switch-based path passes all tests:

- Delete the reverse `CondExp` fold and its manually typed `LogicalExp`, `EqualExp`, `CommaExp`, and fallback construction.
- Remove fields on `CaseExpArm` that existed only to support declaration threading through conditional expressions, if no other phase uses them.
- Retain source-level `SwitchExp`, `syntaxCopy`, printing, static-arm expansion, and normalized semantic metadata.
- Keep decision-tree usefulness checking independent from executable lowering.

### 10. Validate generated control flow

Functional validation:

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
```

Integration validation:

- Build druntime and Phobos.
- Compile representative switches with `-O`, `-inline`, `-release`, `-betterC`, and CTFE.
- Compare generated assembly for an enum union with at least five dense unit variants. Confirm it enters the existing switch lowering and that optimized builds may select a jump table; do not require a jump table when the backend's profitability heuristic chooses branches.
- Run `git diff --check`.

## Suggested Commit Sequence

1. Add behavior-preservation tests.
2. Introduce normalized arm metadata without changing generated code.
3. Add generated function/switch lowering behind a temporary compiler-internal toggle.
4. Enable it for unit and payload-free variants.
5. Add ordinary bindings, nested tuple unpacking, guards, and default routing.
6. Add value, `ref`, `void`, and `noreturn` result support.
7. Enable CTFE, attributes, and capture-sensitive cases.
8. Remove conditional-expression lowering and the temporary toggle.
9. Run integration builds and update implementation documentation.

## Exit Criteria

- Successful semantic analysis leaves no `SwitchExp` for glue.
- Runtime dispatch uses an ordinary frontend `SwitchStatement`.
- All behavior and diagnostics from Plan 1 remain intact.
- No additional copy, move, postblit, destructor, or closure allocation is introduced.
- Value, `ref`, `void`, `noreturn`, CTFE, and attribute-sensitive cases pass.
- The compiler, enum-union tests, druntime, and Phobos build cleanly.