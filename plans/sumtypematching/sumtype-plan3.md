# Plan: Lower MatchExp to CondExp by Removing Function Support from Match Arms

## Goal

Remove block/function syntax support from match arms (only `=> expr` allowed), change the arm representation from `FuncExp[]` to `VarDeclaration[]`, and lower `MatchExp` to `CondExp` during semantic analysis. This eliminates the need for `MatchExp` handling in e2ir and the CTFE interpreter.

## Background

Currently, match arms are represented as `FuncExp[]` (function literals). The semantic phase wraps each arm in a `CallExp(arm, scrut.field_i)`, and both e2ir and ctfe must handle `MatchExp` with their own dispatch logic.

By restricting arms to expressions only (`=> expr`), the match can be lowered to a `CondExp` tree in semantic analysis. Each arm introduces a `VarDeclaration` in the CondExp branch. The body expression keeps its `IdentifierExp` references; symbol resolution happens when the CondExp is semantically analyzed.

Lowering example:
```
s.match { (int x) => x * 2, (bool y) => y ? 1 : 0 }
→
s.__tag == 0 ? (int x = s.__v0, x * 2) : (bool y = s.__v1, y ? 1 : 0)
```

No `assert(0)` needed since all variants are exhaustively handled (required).

With catch-all (untyped parameter):
```
s.match { (int x) => x * 2, (y) => 42 }
// sumtype has variants [int, bool, string]
→
s.__tag == 0 ? (int x = s.__v0, x * 2) : (int y = s.__v1, 42) : (string y = s.__v2, 42)
```

The untyped arm `(y)` is cloned per unmatched variant, each getting that variant's type.

Since `DotVarExp` now has `compilerOverlappedAccess` to safely access overlapped sumtype fields, this lowering is safe.

## Key Design Decisions

### `_` is just a regular identifier

`_` has no special meaning. `(x) => expr` and `(_) => expr` are identical in behavior. A parameter named `_` is not inherently a catch-all — it's the **absence of a type annotation** that makes an arm a catch-all.

### Typeless parameters (catch-all)

An arm without a type annotation like `(x) => expr` or `(_) => expr` is a catch-all. Its parameter type is inferred from the variant it matches during lowering. This is analogous to function literal parameter type inference.

- `(int x) => expr` — typed, matches only `int` variant
- `(x) => expr` — typeless, matches any variant (catch-all), type inferred per-variant
- `(ref int x) => expr` — typed with ref
- `(ref x) => expr` — typeless with ref

### Exhaustiveness is required

A match must handle all variants. The compiler checks:
1. Count variants covered by typed arms (by name or position).
2. If all covered AND catch-all present → **error**: redundant catch-all.
3. If not all covered AND no catch-all → **error**: non-exhaustive match.
4. If all covered and no catch-all → OK, no `assert(0)` in lowering.
5. If not all covered and catch-all present → OK, catch-all covers remaining.

When the match is exhaustive (which it must be), the CondExp chain covers all branches with no need for an `assert(0)` default.

## Changes

### 1. Parser: Remove block syntax, support typeless params and `ref`

**File: `compiler/src/dmd/parse.d` (lines 9513–9631)**

For each arm, the parser currently parses `(Type id)` or `(_)`, then checks for `=> expr` or `{ stmts }`.

Change to:

**a) Parse optional storage class and optional type:**
- Before parsing the type, check for `TOK.ref_` (and other storage qualifiers) and accumulate into `storageClass`.
- The type is optional: if the next token after storage class (or `(`) is an identifier followed by `)` or `=>`, the parameter is typeless (catch-all). If it's a type, parse it normally.
- Grammar: `arm := '(' [storageClass] [type] ident ')' '=>' expr`

**b) Remove block syntax:**
- Delete the `else if (token.value == TOK.leftCurly)` branches at lines 9563–9565 and 9602–9604.
- Change error messages from `"expected '=>' or '{' in match arm"` to `"expected '=>' in match arm"`.

**c) Create `VarDeclaration` instead of `FuncExp`:**
- For each arm, create an `AST.VarDeclaration` with:
  - `type`: the parameter type from parsing, or `null` if typeless (catch-all)
  - `ident`: the parameter identifier
  - `_init`: `AST.ExpInitializer` containing the body expression (after `=>`)
  - `storage_class`: accumulated storage classes (e.g., `STC.ref_`)
- Change `AST.FuncExp[] arms` local to `AST.VarDeclaration[] arms`.
- Update the `MatchExp` constructor call at line 9629 to pass `VarDeclaration[]`.

### 2. AST: Change MatchExp arm representation

**File: `compiler/src/dmd/expression.d` (lines 3969–4003)**

- Change `FuncExp[] arms` to `VarDeclaration[] arms`.
- Remove `variantCallExps` field (no longer needed).
- Keep `armToVariant`, `loweredStruct`, `sumtypeType` (used transiently during semantic).
- Update constructor to take `VarDeclaration[]`.
- Update `syntaxCopy()` to clone `VarDeclaration` arms via `vd.syntaxCopy(null)`.

**File: `compiler/src/dmd/astbase.d` (lines 6298–6315)**

- Mirror the same changes for the base AST `MatchExp` class.

### 3. Semantic: Lower MatchExp to CondExp

**File: `compiler/src/dmd/expressionsem.d` (lines 15840–16016)**

Major rewrite of `visit(MatchExp exp)`:

**Step 1 — Validate scrutinee**: ensure it's a sumtype, get variants, lowered struct, variant names.

**Step 2 — Classify arms**: For each arm `i`:
- Read its `VarDeclaration vd`.
- If `vd.type is null` → typeless/catch-all. Record `armToVariant[i] = -2`.
- If `vd.type !is null` → typed. Match by `vd.ident` against `variantNames` (name-based), falling back to positional index.

**Step 3 — Exhaustiveness check**:
- Count variants covered by typed arms (armToVariant >= 0).
- `numUncovered = numVariants - numCoveredByTyped`
- If `numUncovered == 0` AND catch-all present → **error**: `"redundant catch-all in match expression"`.
- If `numUncovered > 0` AND no catch-all → **error**: `"non-exhaustive match, missing variant for type '%s'"`.
- If `numUncovered > 0` AND catch-all present → OK, catch-all covers `numUncovered` variants.

**Step 4 — Build per-variant expressions**: For each variant `i` (0 to numVariants-1):
- Determine which arm handles this variant (named match or catch-all).
- Get the arm's `VarDeclaration armVD` and its body from `armVD._init.exp`.
- Create `DotVarExp(exp.arg, sd.fields[i+1])` with `compilerOverlappedAccess = true` and `type = variantField.type`.
- Create a **new** `VarDeclaration` for the CondExp branch:
  - `type`: For typed arms, use `armVD.type`. For catch-all, use `sd.fields[i+1].type` (inferred from variant).
  - `ident`: Use `armVD.ident`.
  - `storage_class`: Carry over `armVD.storage_class` (including `STC.ref_`) plus `STC.ctfe`.
  - `_init`: `ExpInitializer(DotVarExp(arg, sd.fields[i+1]))`.
- Build: `CommaExp(DeclarationExp(newVD), armBody)`.
  - The arm body is used **as-is** — it contains `IdentifierExp(name)` references that resolve to the new VarDeclaration during CondExp semantic analysis.
- Store result in `variantExprs[i]`.

**Step 5 — Build the CondExp chain** (right-folded):
```
Expression chain = variantExprs[numVariants - 1];
for (size_t i = numVariants - 1; i > 0;)
{
    i--;
    if (variantExprs[i] is null)
        continue;
    auto cmp = new EqualExp(exp.loc, EXP.equal, tag, new IntegerExp(exp.loc, i, tag.type));
    chain = new CondExp(exp.loc, cmp, variantExprs[i], chain);
}
```

No `assert(0)` — the match is exhaustive by construction (validated in step 3).

**Step 6 — Return**:
- Set `result = chain.expressionSemantic(sc)`. The MatchExp node is fully lowered and discarded.

### 4. Update cross-sumtype assignment lowering

**File: `compiler/src/dmd/expressionsem.d` (lines 12592–12647)**

Replace `FuncExp[]` arm construction with `VarDeclaration[]`:

```d
VarDeclaration[] arms;
foreach (i, srcVariant; srcTs.variants)
{
    auto paramIdent = Identifier.idPool("__p");
    auto paramRef = new IdentifierExp(exp.loc, paramIdent);
    auto ctorCall = new CallExp(exp.loc, new TypeExp(exp.loc, new TypeStruct(sd)), paramRef);
    auto vd = new VarDeclaration(exp.loc, srcVariant, paramIdent, new ExpInitializer(exp.loc, ctorCall));
    arms ~= vd;
}
auto matchExp = new MatchExp(exp.loc, e2x, arms);
```

### 5. Remove e2ir MatchExp handling

**File: `compiler/src/dmd/glue/e2ir.d`**

- Delete `visitMatch(MatchExp me)` (lines 3326–3400).
- Remove dispatch at line 4355.

### 6. Remove CTFE MatchExp handling

**File: `compiler/src/dmd/dinterpret.d`**

- Delete `visit(MatchExp me)` (lines 4980–5040).

### 7. Update hdrgen

**File: `compiler/src/dmd/hdrgen.d` (lines 3152–3166)**

- Update to print new arm format: `(type name) => body` or `(name) => body` for typeless.

### 8. Update sideeffect

**File: `compiler/src/dmd/sideeffect.d` (line 195)**

- Remove `case EXP.matchExp:`.

### 9. Update DFA walker

**File: `compiler/src/dmd/dfa/fast/expression.d` (line 1562)**

- Remove `case EXP.matchExp:`.

### 10. Visitor (no change needed)

**File: `compiler/src/dmd/visitor/parsetime.d` (line 208)**

- Keep as-is.

## Risk Areas

1. **Scrutinee side effects**: `exp.arg` appears in the tag DotVarExp and in each variant's initializer. If it has side effects, it would be evaluated multiple times. **Mitigation**: If `exp.arg.hasSideEffect()`, introduce a temp via `copyToTemp(STC.ref_, "__matchScrut", exp.arg)` and use `VarExp(tmp)` throughout.

2. **ref initialization**: The `VarDeclaration` with `STC.ref_` is initialized from a `DotVarExp` (an lvalue field access). This is valid for `ref` binding.

3. **Typeless arm matching multiple variants**: A typeless arm is cloned per uncovered variant. The body expression must type-check for all matched variant types. If it doesn't, it's a type error caught during CondExp semantic analysis.

4. **Cross-sumtype assignment lowering**: Must be updated from `FuncExp[]` to `VarDeclaration[]`.

## Validation

1. **Run sumtype/match test**: Execute `compiler/src/testsumtypematching/run.sh` via bash. Verify CG-AST output shows CondExp with DeclarationExp branches (not function calls).
2. **Verify block syntax rejection**: `(int x) { return x; }` should produce parse error.
3. **Verify typed arrow syntax**: `(int x) => x * 2` and `(ref int x) => x = 5` should compile and run.
4. **Verify typeless/catch-all**: `(x) => 42` should match any variant with type inferred.
5. **Verify cross-sumtype assignment**: `S2 s3 = s1;` should work.
6. **Verify exhaustiveness**: Missing variant without catch-all → error. Catch-all when all covered → error.
7. **Run full test suite**: `make -C compiler/test`.
