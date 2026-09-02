# Sumtype and Match Expression Implementation Plan

## Overview

This plan covers the addition of `__sumtype` declarations and `__match` expressions to the D programming language, followed by compiler implementation in DMD, a DIP document, and language specification changes.

**Status**: Draft
**Scope**: MVP — parse declarations, basic match expression, exhaustiveness checking. No niche optimization, no re-tagging destructors.

---

## 1. Language Design Summary

### 1.1 Declaration Syntax

Three forms are supported:

```d
// Form 1: Alias form
alias S = __sumtype(int | bool);

// Form 2: Direct form (unnamed)
__sumtype S = int | bool;

// Form 3: Block form (supports named variants)
__sumtype S {
    int x,
    bool y
}
```

**Duplicate type handling**: Unlabeled duplicate payload types are prohibited at compile time. Named variants (Form 3) allow disambiguation when the same type appears multiple times.

### 1.2 Match Expression Syntax

Lambda-like syntax with support for both expression bodies and block bodies:

```d
val.__match(
    (int i)    => i * 2,
    (string s) => s.length
)

// Block body form
val.__match(
    (int i) {
        auto x = i * 2;
        return x;
    },
    (string s) {
        return s.length;
    }
)
```

**Return type rules**:
- If all arms return type `T`, the match evaluates to `T`.
- If arms return distinct types `T1, T2, ...`, the result is `__sumtype(T1 | T2 | ...)`, enabling chaining.

### 1.3 Tag Strategy

Tags are computed as a hash of the variant type names at compile time. This ensures consistent tag values across compilation units and instances of the same sumtype.

### 1.4 1-Element Sum Types

`__sumtype(T)` degenerates to `alias S = T` — zero tag overhead, identical ABI.

### 1.5 `.init` Default

Defaults to the `.init` of the first listed variant. If `None` is present and listed first, uninitialized variables default to the empty state.

### 1.6 Value Semantics

Pattern match bindings strictly copy or move values. No `ref` access to internal fields.

### 1.7 `None` Type

Library-defined: `struct None;` (opaque unit type). Not a compiler built-in.

---

## 2. Implementation Phases

### Phase 1: Token and Keyword Infrastructure

**Files to modify**:

| File | Changes |
|------|---------|
| `compiler/src/dmd/tokens.d` | Add `sumtype_` to `TOK` enum (before `__attribute__`), add `__match_` to `TOK` enum. Add both to `keywords[]` array and `tochars[]` mapping. Add `MatchExp` to `EXP` enum. |
| `compiler/src/dmd/id.d` | Add `{ "sumtype", "__sumtype" }` and `{ "match", "__match" }` to `msgtable` array. |
| `compiler/src/dmd/astenums.d` | Add `Tsumtype` to `TY` enum (after `Ttag`). Add `MatchExp` to `EXP` enum if needed for expression dispatch. |

**Pattern reference**: Follow the exact pattern used for `TOK.__attribute__` (tokens.d:286) and `TOK.vector` (tokens.d:251).

### Phase 2: AST Type Representation

**Files to modify**:

| File | Changes |
|------|---------|
| `compiler/src/dmd/mtype.d` | Add `TypeSumType` class inheriting from `Type`. Fields: `Type[] variants`, `string[] variantNames` (optional, for named variants), `uint tagHash`. Add `sizeTy[Tsumtype]` entry. Implement `kind()`, `syntaxCopy()`, `accept()`. |
| `compiler/src/dmd/astbase.d` | Add mirror `TypeSumType` class in `ASTBase`. Update `sizeTy` array. |
| `compiler/src/dmd/astcodegen.d` | Add `alias Tsumtype = dmd.mtype.Tsumtype;` and alias for `TypeSumType`. |
| `compiler/src/dmd/visitor/parsetime.d` | Add `void visit(AST.TypeSumType t) { visit(cast(AST.Type)t); }` |

**Design**: `TypeSumType` stores the variant types and metadata. During semantic analysis, it is lowered to a `TypeStruct` with a tag field and union payload. The `TypeSumType` AST node persists for type-checking and match analysis.

### Phase 3: AST Match Expression

**Files to modify**:

| File | Changes |
|------|---------|
| `compiler/src/dmd/expression.d` | Add `MatchExp` class. Fields: `Expression arg` (the scrutinee), `TypeSumType sumType` (resolved type), `FuncExp[] arms` (or `Expression[]` with parameter info), `Type resultType` (computed). Implement `syntaxCopy()`, `accept()`. |
| `compiler/src/dmd/astbase.d` | Add mirror `MatchExp` class. |
| `compiler/src/dmd/visitor/parsetime.d` | Add `void visit(AST.MatchExp e) { visit(cast(AST.Expression)e); }` |

**MatchExp structure**:

```d
extern (C++) final class MatchExp : Expression
{
    Expression arg;           // scrutinee expression
    FuncExp[] arms;           // match arms (lambda-like)
    // Each arm: (Type pattern) => expr  or  (Type pattern) { stmts }

    override void accept(Visitor v) { v.visit(this); }
}
```

### Phase 4: Parser

**File**: `compiler/src/dmd/parse.d`

#### 4a. Parse `__sumtype` declarations

Add cases in `parseDeclarations()` for `TOK.sumtype_`:

- **Alias form**: `alias S = __sumtype(int | bool)` — handled in `parseAliasDeclarations()` by recognizing `__sumtype` after `=`.
- **Direct form**: `__sumtype S = int | bool` — new case in `parseDeclarations()`.
- **Block form**: `__sumtype S { int x, bool y }` — new case, similar to `parseAggregate()` for structs.

**Type parsing for `__sumtype(...)`**: Add `case TOK.sumtype_` in `parseBasicType()` (line ~4050). Parse `__sumtype(Type | Type | ...)` by collecting types separated by `TOK.or` into a `TypeSumType` AST node.

#### 4b. Parse `__match` expressions

Add `__match` as a postfix expression operator (like `.foo` or `.opDispatch`). Parse:

```
PostfixExpression:
    ...
    PrimaryExpression . __match ( MatchArmList )
```

**MatchArm**: `( Type Identifier ) => Expression` or `( Type Identifier ) BlockStatement`

**Grammar addition** (to `spec/expression.dd`):

```
MatchExpression:
    PrimaryExpression . __match ( MatchArmList )

MatchArmList:
    MatchArm
    MatchArm , MatchArmList

MatchArm:
    ( Type Identifier ) => AssignExpression
    ( Type Identifier ) BlockStatement
```

### Phase 5: Semantic Analysis

**Files to modify**:

| File | Changes |
|------|---------|
| `compiler/src/dmd/typesem.d` | Add `visit(TypeSumType)` — resolve variant types, compute tag hash, check for duplicate unlabeled types, handle 1-element degeneration to alias. |
| `compiler/src/dmd/expressionsem.d` | Add `visit(MatchExp)` — resolve scrutinee type, verify it's a sumtype, type-check each arm, compute result type (unified or synthesized sumtype), perform exhaustiveness check. |

#### 5a. TypeSumType Semantic (`typesem.d`)

1. Resolve each variant type via `typeSemantic()`.
2. Check for duplicate unlabeled types — error if found.
3. If only 1 variant, lower to alias (`alias S = T`).
4. Compute tag hash: `hash = hashOf(variantTypes.map!(t => t.toString()))`.
5. Generate the lowered struct representation:
   ```d
   struct __SumType_S {
       uint tag;  // hash-based
       union {
           T1 v1;
           T2 v2;
           ...
       }
   }
   ```

#### 5b. MatchExp Semantic (`expressionsem.d`)

1. Evaluate scrutinee expression via `expressionSemantic()`.
2. Resolve scrutinee type — must be a `TypeSumType`.
3. For each arm, resolve the pattern type and verify it matches a variant.
4. Type-check each arm body.
5. Compute result type:
   - If all arms return `T`, result is `T`.
   - Otherwise, synthesize `__sumtype(T1 | T2 | ...)`.
6. **Exhaustiveness check**: Verify all variants are covered. Use Maranget's matrix algorithm for exhaustive pattern compilation.
7. Lower to a chain of `if`/`else` with tag comparisons (or a `switch` on the tag).

#### 5c. Exhaustiveness Checking

Implement the exhaustiveness check from Maranget (2007):

1. Build a pattern matrix: rows = match arms, columns = sumtype variants.
2. Check that every variant appears in at least one arm.
3. For named variants with types, check type coverage.
4. Emit error for non-exhaustive matches: `"match is not exhaustive; missing variant: %s"`.
5. Emit warning for redundant arms: `"redundant match arm: %s is already covered"`.

### Phase 6: Code Generation

**File**: `compiler/src/dmd/e2ir.d` (or relevant codegen file)

#### 6a. Sumtype Codegen

The lowered struct generates standard struct codegen:
- Tag field: `uint` (hash of type names).
- Payload: anonymous union of variant types.
- `.init`: first variant's `.init` with tag set to its hash.
- `sizeof`: `uint.sizeof + max(variantTypes.map!(t => t.sizeof))`, aligned appropriately.

#### 6b. Match Expression Codegen

Lower `MatchExp` to a `switch` statement on the tag:

```d
// Source:
val.__match(
    (int i)    => i * 2,
    (string s) => s.length
)

// Lowered to:
({
    auto __scrutinee = val;
    switch (__scrutinee.tag) {
        case hash_int:    { auto i = __scrutinee.v1; return i * 2; }
        case hash_string: { auto s = __scrutinee.v2; return s.length; }
        default: assert(false, "non-exhaustive match");
    }
})
```

### Phase 7: Test Suite

**File**: `compiler/src/testsumtypematching/start.d`

Expand from the empty `void main() {}` to comprehensive test cases:

```d
void main() {
    // Test 1: Basic sumtype declaration
    alias S = __sumtype(int | bool);
    S val = 42;

    // Test 2: Direct form
    __sumtype T = int | bool;

    // Test 3: Block form with named variants
    __sumtype U {
        int x,
        bool y
    }

    // Test 4: Basic match
    auto result = val.__match(
        (int i)    => i * 2,
        (bool b) => b ? 1 : 0
    );

    // Test 5: Match chaining (sumtype synthesis)
    auto chained = val.__match(
        (int i)    => i * 2.0,    // returns double
        (bool b) => None()        // returns None
    ).__match(
        (double d) => format("%f", d),
        (None)     => "empty"
    );

    // Test 6: Block body match
    auto x = val.__match(
        (int i) {
            auto tmp = i * 2;
            return tmp;
        },
        (bool b) {
            return b ? 1 : 0;
        }
    );

    // Test 7: 1-element sumtype (degenerates to alias)
    alias Single = __sumtype(int);
    static assert(is(Single == int));

    // Test 8: Exhaustiveness check (compile-time error test)
    // __sumtype V = int | bool;
    // V v = 1;
    // auto bad = v.__match((int i) => i);  // ERROR: missing bool arm
}
```

Add test files in `compiler/test/` following existing patterns:
- `compilable/test_sumtype_basic.d` — basic compilation tests
- `fail_compilation/test_sumtype_exhaustiveness.d` — exhaustiveness error tests
- `runnable/test_sumtype_match.d` — runtime match tests

### Phase 8: DIP Document

**File**: `plans/DIP-sumtype.md`

Follow the DIP template structure:

1. **Title**: "Sum Types and Pattern Matching for D"
2. **Abstract**: Add `__sumtype` declarations and `__match` expressions to D
3. **Rationale**: Type safety, exhaustive matching, eliminating invalid states
4. **Prior Work**: Rust enums, Haskell ADTs, OCaml variants, Swift enums, TypeScript discriminated unions
5. **Description**: Full syntax, semantics, grammar changes, examples
6. **Breaking Changes**: None (uses `__sumtype` reserved keyword)
7. **Copyright & License**: CC0 1.0

### Phase 9: Spec Changes

**Files to modify**:

| File | Changes |
|------|---------|
| `spec/type.dd` | Add `SumType` section with grammar, semantics, and examples. Add to `BasicType` grammar rule. |
| `spec/expression.dd` | Add `MatchExpression` grammar rule and section. Document return type synthesis. |
| `spec/declaration.dd` | Add `SumTypeDeclaration` to grammar. Document all three declaration forms. |
| `spec/grammar.dd` | Update declaration and expression diagrams to include sumtype nodes. |

**Grammar additions to `type.dd`**:

```
$(GNAME BasicType):
    ...
    $(GLINK SumType)

$(GNAME SumType):
    $(D __sumtype) $(D $(LPAREN)) $(GLINK TypeList) $(D $(RPAREN))

$(GNAME TypeList):
    $(GLINK Type)
    $(GLINK Type) $(D |) $(GSELF TypeList)
```

**Grammar additions to `declaration.dd`**:

```
$(GNAME Declaration):
    ...
    $(GLINK SumTypeDeclaration)

$(GNAME SumTypeDeclaration):
    $(D __sumtype) $(GLINK Identifier) $(D =) $(GLINK SumType) $(D ;)
    $(D __sumtype) $(GLINK Identifier) $(GLINK SumTypeBody) $(D ;)

$(GNAME SumTypeBody):
    $(D {) $(GLINK SumTypeMemberList) $(D })

$(GNAME SumTypeMemberList):
    $(GLINK SumTypeMember)
    $(GLINK SumTypeMember) $(D ,) $(GSELF SumTypeMemberList)

$(GNAME SumTypeMember):
    $(GLINK Type) $(GLINK Identifier)$(OPT)
```

---

## 3. File Change Summary

### New Files

| File | Purpose |
|------|---------|
| `documents/DIP-sumtype.md` | DIP document |
| `spec/sumtype.dd` | Sumtype spec page (or add to `type.dd`) |
| `compiler/test/compilable/test_sumtype_basic.d` | Basic compilation tests |
| `compiler/test/fail_compilation/test_sumtype_exhaustiveness.d` | Exhaustiveness error tests |
| `compiler/test/runnable/test_sumtype_match.d` | Runtime match tests |

### Modified Files

| File | Phase | Changes |
|------|-------|---------|
| `compiler/src/dmd/tokens.d` | 1 | Add `TOK.sumtype_`, `TOK.__match_`, `EXP.MatchExp`; update `keywords[]`, `tochars[]` |
| `compiler/src/dmd/id.d` | 1 | Add `sumtype`/`__sumtype` and `match`/`__match` to `msgtable` |
| `compiler/src/dmd/astenums.d` | 1 | Add `Tsumtype` to `TY` enum |
| `compiler/src/dmd/mtype.d` | 2 | Add `TypeSumType` class, update `sizeTy` |
| `compiler/src/dmd/astbase.d` | 2 | Add mirror `TypeSumType`, update `sizeTy` |
| `compiler/src/dmd/astcodegen.d` | 2 | Add `Tsumtype` alias |
| `compiler/src/dmd/visitor/parsetime.d` | 2,3 | Add visit methods for `TypeSumType` and `MatchExp` |
| `compiler/src/dmd/expression.d` | 3 | Add `MatchExp` class |
| `compiler/src/dmd/parse.d` | 4 | Parse `__sumtype` declarations and `__match` expressions |
| `compiler/src/dmd/typesem.d` | 5 | Semantic analysis for `TypeSumType` |
| `compiler/src/dmd/expressionsem.d` | 5 | Semantic analysis for `MatchExp`, exhaustiveness checking |
| `compiler/src/dmd/e2ir.d` | 6 | Code generation for sumtype layout and match dispatch |
| `compiler/src/testsumtypematching/start.d` | 7 | Expand with test cases |
| `spec/type.dd` | 9 | Add sumtype grammar and documentation |
| `spec/expression.dd` | 9 | Add match expression grammar and documentation |
| `spec/declaration.dd` | 9 | Add sumtype declaration grammar |
| `spec/grammar.dd` | 9 | Update diagrams |

---

## 4. Build and Test Procedure

```bash
cd compiler/src
# Build the compiler
rdmd build.d --force DFLAGS="$DMFLAGS"

# Copy to test location
cp ../../generated/windows/release/64/dmd.exe p:/ProjectSidero/dmd2/windows/bin/

# Run sumtype tests
p:/ProjectSidero/dmd2/windows/bin/dmd -o- -verrors=0 testsumtypematching/start.d
```

---

## 5. Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| `__sumtype` keyword conflicts with existing `std.sumtype` library | Use `__` prefix (implementation-reserved). Library can be deprecated later. |
| Exhaustiveness checking complexity (Maranget algorithm) | Start with simple variant-level check; defer nested pattern exhaustiveness to later phase. |
| Match expression type synthesis creates complex inferred types | Limit synthesis depth; error on deeply nested inferred sumtypes. |
| Codegen for match arms with different return types | Lower to `switch` with each arm returning a tagged union; use `std.variant`-like layout internally. |
| 1-element sumtype degeneration breaks generic code | Document that `__sumtype(T)` is `is(T) == true`; generic constraints must account for this. |

---

## 6. Dependencies Between Phases

```
Phase 1 (Tokens) ──> Phase 2 (AST Type) ──> Phase 3 (AST Match)
                         │                        │
                         v                        v
                    Phase 4 (Parser) ─────> Phase 5 (Semantic)
                                                 │
                                                 v
                                            Phase 6 (Codegen)
                                                 │
                                                 v
                                            Phase 7 (Tests)

Phase 8 (DIP) and Phase 9 (Spec) can proceed in parallel with Phases 1-7.
```

---

## 7. Open Questions

1. **Implicit conversions in match arms**: Should `case long l` match an `int` variant? (Recommend: yes, via `implicitConvTo`.)
2. **Wildcard patterns**: Should `_` be supported as a catch-all? (Recommend: yes, for partial matching with exhaustiveness override.)
3. **Guard conditions**: Should `case int i if i > 0` be supported? (Recommend: defer to post-MVP.)
4. **`@safe`/`@nogc` inference**: Match expressions should inherit safety attributes from enclosing context.
5. **Template instantiation**: How do sumtypes interact with template parameter deduction? (Recommend: treat as nominal type, not structural.)
