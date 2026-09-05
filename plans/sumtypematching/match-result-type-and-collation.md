# Match Expression Result Type & Sumtype Collation

## Goal

1. Make `.match` expression result type depend on handler arm types (form a sumtype).
2. Remove the `__sumtype(Types)` inline parser syntax; keep only block declarations.
3. Add root-module collation so identical sumtype declarations are shared.

## Background

Today in `expressionsem.d:15852 visit(MatchExp)`, the result type is taken from the first semantically-analyzed arm body (`if (resultType is null) resultType = resolved.type;` at line ~16160). No unification across arms occurs, so the result type ignores all but the first arm.

Sumtypes lower to a `StructDeclaration` in `typesem.d:4768 visitSumType`. Every lowering creates a brand-new struct even when an identical set of variants already exists. Match expressions that produce sumtype results should also benefit from deduplication.

## Integer Promotion Rules

When unifying arm result types that are integer-like:

| Combination | Result |
|---|---|
| `int` + `uint` | `long` |
| `long` + `ulong` | **error** — no larger signed type exists |
| `short` + `ushort` | `int` |
| `byte` + `ubyte` | `short` |
| `int64` + `uint64` | **error** |
| Same signedness, different width | wider type of same signedness |

Non-integer types unify only if `equals`. Integer unification: find a signed type whose width is strictly greater than `max(signedWidth, unsignedWidth)`. If none exists, error.

Only ONE integer variant may exist in the result sumtype (preserving the existing single-integer-variant invariant from `typesem.d:4846`).

## Steps

### 1. Collect arm result types before building the result

**File**: `compiler/src/dmd/expressionsem.d` (`visit(MatchExp)`)

Restructure the function into two phases:

**Phase A — Analyze arms**: For each variant of the scrutinee, for each matching arm (current code ~16070–16163), build the arm body expression with parameter substitution and run `expressionSemantic`. Collect:
- The resolved expression per arm
- The resolved type per arm

Store these in temporary arrays indexed by variant index.

**Phase B — Unify result types**: After all arms are analyzed, iterate the collected types and produce the unified variant set:

```d
// Pseudocode
Type[] armTypes; // collected from Phase A
SumTypeVariantInfos resultVariants;
foreach (t in armTypes)
    unifyInto(resultVariants, t); // apply integer promotion rules, deduplicate
```

`unifyInto`:
- If `resultVariants` is empty, add the type.
- Else for each existing variant:
  - If `existing.equals(t)` → duplicate, skip.
  - If both integer-like → replace existing with promoted wider signed type.
  - Else → add as new variant.
- Error if integer promotion overflows (no wider signed type available).

### 2. Determine result type

After unification:

- **0 variants** (all arms errored): bail out.
- **1 variant**: `resultType = resultVariants[0].type` (no sumtype wrapper).
- **2+ variants**: build a result `TypeSumType` (lowered struct). Use the collation mechanism (Step 5) to find or create the shared struct.

### 3. Wrap arm bodies when result is a sumtype

When the result is a sumtype (2+ variants), each arm body expression must be wrapped in a `StructLiteralExp` that constructs the appropriate variant:

```d
// For arm with type t mapping to result variant index vi:
auto elements = new Expressions(resultSd.fields.length);
elements.zero;
(*elements)[0] = new IntegerExp(loc, vi, tagType);
(*elements)[vi + 1] = armBodyExpression; // implicit conv handled by sle semantic
auto sle = new StructLiteralExp(loc, resultSd, elements, resultSd.type);
armResult = sle.expressionSemantic(sc);
```

When the result is a single type, use arm bodies directly (current behavior).

The CondExp chain (current code ~16166–16179) then uses these wrapped expressions, with `cond.type = resultType`.

### 4. Remove `__sumtype(Types)` inline syntax from parser

**File**: `compiler/src/dmd/parse.d`

- Remove the `case TOK.sumtype_:` branch in `parseBasicType` (lines 4097–4099).
- Remove the `parseSumType()` function (lines 4115–4185) — this parses `__sumtype(Type | Type | ...)`.
- Keep `parseSumTypeVariant()` — it is used by `parseSumTypeDeclarations`.
- Keep `parseSumTypeDeclarations()` — this handles the block form `__sumtype S = Type | Type;`.

This means `__sumtype` can only appear as a declaration keyword (handled in `parseDeclDefs` → `parseSumTypeDeclarations`), never as an inline type expression.

### 5. Add root-module collation for sumtype declarations

**File**: `compiler/src/dmd/dmodule.d` + `compiler/src/dmd/typesem.d`

Add a hash map on `Module` (only used when `isRoot()`):

```d
// In Module
StructDeclaration[SumTypeKey] sumtypeCollations;
```

`SumTypeKey` is a comparable/hashable representation of a variant set:
- Sorted list of variant types (by `typeKey()` or comparable hash).
- For named variants: names must also match.

**Lookup/insert function**:

```d
StructDeclaration findOrAddSumType(Module root, SumTypeVariantInfos* variants, Loc loc, Scope* sc)
{
    auto key = SumTypeKey(variants);
    if (auto existing = key in root.sumtypeCollations)
        return existing;
    // ... create new struct as in visitSumType ...
    root.sumtypeCollations[key] = sd;
    return sd;
}
```

**In `visitSumType` (typesem.d:4768)**: after computing `variants` and before creating the `StructDeclaration`, check the root module for an existing match. If found, reuse it (return its type instead of creating a new struct).

**In match expression result building (expressionsem.d)**: use the same `findOrAddSumType` so result sumtypes are collated.

### 6. Update tests

**File**: `compiler/test/runnable/sumtypematching.d`

Replace all inline `__sumtype(Types)` usages with block declarations:

```d
// Before:
alias S1 = __sumtype(int | bool);

// After:
__sumtype S1 = int | bool;
```

Add new test sections:
- **Match result type**: verify that `int` + `uint` arms produce a sumtype with a `long` variant.
- **Match result integer overflow error**: verify that `long` + `ulong` arms produce a compile error.
- **Match result single type**: verify that all-`int` arms produce `int` directly.
- **Match result collation**: verify that two match expressions with the same arm types share the same result struct.

**File**: `compiler/test/fail_compilation/sumtypematching.d`

Update any inline syntax usage. Add error test for integer overflow in match result.

### 7. Update C++ headers

**Files**: `compiler/include/dmd/*.h`

The C++ headers mirror the D class layouts for ABI compatibility. Any change to D class fields requires matching updates:

| Header | Change |
|---|---|
| `compiler/include/dmd/module.h` | Add `sumtypeCollations` hash map field to `Module` class (if collation storage is added to Module) |
| `compiler/include/dmd/expression.h` | Add any new fields to `MatchExp` class if result sumtype info needs to be stored permanently (e.g., `StructDeclaration *resultLoweredStruct`) |
| `compiler/include/dmd/mtype.h` | Add any new fields to `TypeSumType` class if collation requires storing a key or parent reference |
| `compiler/include/dmd/aggregate.h` | Verify `sumtype` field on `StructDeclaration` is sufficient for collation lookups |

The token `sumtype_` in `compiler/include/dmd/tokens.h:262` and `Tsumtype` in `compiler/include/dmd/mtype.h:110` remain — they are still used for block declarations and AST representation.

**Important**: If the implementation adds new fields to D classes that have C++ mirror headers, the C++ headers MUST be updated to match the new class layout. The D compiler relies on these headers for ABI compatibility with DRuntime/Phobos.

## Affected Files

| File | Change |
|---|---|
| `compiler/src/dmd/expressionsem.d` | Two-phase arm analysis + result type unification + wrapping |
| `compiler/src/dmd/parse.d` | Remove inline `__sumtype(Types)` parsing |
| `compiler/src/dmd/typesem.d` | Root-module collation in `visitSumType` |
| `compiler/src/dmd/dmodule.d` | Add collation hash map to `Module` |
| `compiler/src/dmd/mtype.d` | Add `SumTypeKey` (if needed as separate struct) |
| `compiler/include/dmd/module.h` | Mirror collation storage field from `dmodule.d` |
| `compiler/include/dmd/expression.h` | Mirror any new `MatchExp` fields |
| `compiler/include/dmd/mtype.h` | Mirror any new `TypeSumType` fields |
| `compiler/test/runnable/sumtypematching.d` | Update inline syntax; add result-type tests |
| `compiler/test/fail_compilation/sumtypematching.d` | Update inline syntax; add overflow error test |

## Validation

1. Do NOT build manually — use the provided test script:
   ```bash
   "C:\Program Files\Git\bin\bash.exe" compiler/src/testsumtypematching/run.sh
   ```
   This script cleans, builds with `rdmd build.d`, installs the fresh dmd, and runs the full test suite automatically.

2. The script runs these tests in order:
   - `testsumtypematching/start.d` (basic smoke test)
   - `compiler/test/runnable/sumtypematching.d` (64-bit, then 32-bit)
   - `compiler/test/fail_compilation/sumtypematching.d` (expects compile errors)
   - `testsumtypematching/typecons.d` (with `-unittest`)

3. Verify:
   - All runnable tests pass (assertions hold)
   - `fail_compilation/sumtypematching.d` produces the expected errors
   - Match expressions with `int`+`uint` arms compile and produce `long` variant
   - Match expressions with `long`+`ulong` arms fail with a clear error
   - No duplicate `__SumType` structs appear in `-vcg-ast` output for identical variant sets

## Risks

- Integer promotion rules must match user's mental model exactly — ambiguous cases should error rather than guess.
- Collation must not break existing code that relies on sumtype struct identity (e.g. `is(T == __sumtype)` checks).
- Removing inline syntax is a breaking change for any code using `alias T = __sumtype(...)` form — must be coordinated with test updates.
- C++ header layout MUST match D class layout exactly — mismatches cause silent memory corruption in the compiled output.
