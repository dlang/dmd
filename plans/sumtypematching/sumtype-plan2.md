# Sumtype and Match Expression Implementation Plan (v3)

## Overview

Covers the `__sumtype` / `.match{}` implementation in DMD, building on existing infrastructure.

**Design decisions from prior discussion**:
1. **Index-based tags** — tags are sequential integers (0, 1, 2, ...) by declaration order.
2. **MatchExp not lowered** — stays as AST node through to e2ir and CTFE.
3. **Sumtype initialization** — `S(value)` and `S(name: value)` constructor syntax.
4. **Block form removed** — only alias and direct declaration forms.
5. **Value-only inference** — unnamed variants infer variant from value type.

**New requirements for v3**:
1. **`.match{}` syntax** — new `TOK.match_` token; `.match { arms }` instead of `.__match(arms)`.
2. **Direct chaining** — match results can be immediately matched again.
3. **Tag read-only in `@safe`** — `__tag` is readable but not writable from user code.
4. **Destructor on assignment** — `__xdtor` must destroy old value before storing new one; uses match semantics to dispatch.

---

## 1. Design

### 1.1 Match Syntax

```d
val.match {
    (int i)    => i * 2,
    (string s) => s.length
}
```

Token: `TOK.match_` — contextual keyword, not reserved. Only recognized after `.` in `parsePostExp`. The `match` identifier remains usable as a normal identifier in all other contexts.

Chaining:
```d
val.match {
    (int i)    => i * 2.0,
    (bool b)   => None()
}.match {
    (double d) => format("%f", d),
    (None _)   => "empty"
}
```

### 1.2 Tag Read-Only in `@safe`

`__tag` is a `uint` field on the lowered struct. The compiler generates all writes to `__tag` (construction, assignment, match dispatch). User code can read `__tag` but cannot write to it.

Implementation: make `__tag` field const so that it can be read but not modified.

### 1.3 Destructor (`__xdtor`)

The lowered sumtype struct must have a custom destructor that:
1. Reads `__tag` to determine the active variant.
2. Calls the destructor of only the active variant's payload (if non-trivial).

The standard `buildDtors` in `clone.d` iterates all fields and calls destructors. For sumtypes, variant fields are overlapped (union), so `buildDtors` skips them automatically (`v.overlapped == true`). We must ensure variant fields are marked overlapped.

A custom `__xdtor` is generated as part of `visitSumType` in `typesem.d`:

```d
// Pseudocode for generated destructor body:
void __xdtor() {
    switch (__tag) {
        case 0: if (typeof(__v0).stringof needs dtor) __v0.__xdtor(); break;
        case 1: if (typeof(__v1).stringof needs dtor) __v1.__xdtor(); break;
        // ...
    }
}
```

Assignment semantics (`s = newVal`):
1. Call `s.__xdtor()` to destroy old value.
2. Copy `newVal` into `s` (memcpy + postblit if lvalue).

### 1.4 Chaining

Match returns an expression value. Chaining works because `.match { }` is a postfix expression operator producing a result. No special support needed — the result of one match can be the scrutinee of the next.

For result type synthesis:
- If all arms return `T`, match result is `T`.
- If arms return distinct types, synthesize `__sumtype(T1 | T2 | ...)`.

---

## 2. Implementation Tasks

### Task 1: Token Changes

**File**: `compiler/src/dmd/tokens.d`

1. Add `match_` to `TOK` enum (near existing `__match_`).
2. Add `"match"` → `TOK.match_` to `tochars[]`.
3. Add `TOK.match_` to `keywords[]` array.
4. Do NOT add `TOK.match_` to `Ckwds[]` (not a reserved keyword — contextual only).
5. Keep `TOK.__match_` for now (deprecated, can remove later).

**File**: `compiler/src/dmd/id.d`

- No changes needed — `match` is a keyword token, not an identifier in `msgtable`.

### Task 2: Parser — `.match { }` Syntax

**File**: `compiler/src/dmd/parse.d`

In `parsePostExp` (line ~9515), after `TOK.dot`:

```d
// Current code checks for TOK.__match_
// Change to check for TOK.match_
if (token.value == TOK.match_)
{
    // Peek ahead: if next token is '{', it's a match expression
    // Otherwise, treat as property access: e.match
    if (peekNext() != TOK.leftCurly)
    {
        // Not a match expression — revert to property access
        // Create DotIdExp(e, "match") and continue
        auto id = Identifier.idPool("match");
        e = new AST.DotIdExp(loc, e, id);
        continue;
    }

    nextToken();  // consume 'match'
    check(TOK.leftCurly, "`match`");

    AST.FuncExp[] arms;
    while (token.value != TOK.rightCurly && token.value != TOK.endOfFile)
    {
        // Parse arm: (Type id) => expr  or  (Type id) { stmts }
        // (existing arm parsing code — unchanged)
        // ...
        if (token.value == TOK.comma)
            nextToken();
        else
            break;
    }

    check(TOK.rightCurly, "`match`");
    e = new AST.MatchExp(loc, e, arms);
    continue;
}
```

Key: arm parsing inside `{}` is identical to the existing `()` arm parsing — each arm is `(Type id) => expr` or `(Type id) { stmts }`.

### Task 3: Replace Hash Tags with Index Tags

#### 3a. `compiler/src/dmd/mtype.d`

- Remove `uint[] variantTagHashes` from `TypeSumType`.
- Remove `sumtypeVariantTagHashes` global associative array.
- Keep `sumtypeVariants` and `sumtypeVariantNames`.

Tag values are implicit: variant `i` has `__tag == i`.

#### 3b. `compiler/src/dmd/astbase.d`

- Remove `uint tagHash` from `TypeSumType` mirror.
- Ensure fields: `variants`, `variantNames`, `loweredStruct`.

#### 3c. `compiler/src/dmd/typesem.d` — `visitSumType`

Remove hash computation block. Remove `sumtypeVariantTagHashes[sd] = ...` assignment.

Tag values are just the field index (0, 1, 2, ...).

#### 3d. `compiler/src/dmd/expressionsem.d` — Auto-tag in AssignExp

Replace hash-based auto-tag (lines ~13348–13385) with index-based:

When assigning to a named variant field `s.x = 42`, find the field index `i` in the lowered struct, then prepend:
```d
s.__tag = i;  // index, not hash
```

#### 3e. `compiler/src/dmd/expressionsem.d` — MatchExp arm-to-variant mapping

Replace hash comparison. Map arms to variant indices:
- Named variants: match arm parameter name to `variantNames[i]`, assign index `i`.
- Unnamed variants: match arm parameter type to `variants[i]`, assign index `i`.
- Wildcard `_`: matches all unmatched variants.

**Do NOT generate `CondExp` chain.** Only validate mapping and compute result type.

### Task 4: Sumtype Constructor Initialization

**File**: `compiler/src/dmd/expressionsem.d`

In `visit(CallExp)`, when `e1` is a `TypeExp` whose type is a lowered sumtype struct (detected via `sumtypeVariants` map):

#### 4a. Named variant selection

`S(x: 5)`:
1. Look up variant name in `sumtypeVariantNames[sd]`, find index `i`.
2. Generate `StructLiteralExp`:
    - `elements[0]` = `IntegerExp(i)` (the `__tag` field).
    - `elements[i+1]` = the argument value.
    - All other elements = default `.init`.

#### 4b. Unnamed variant type inference

`S(42)`:
1. Get argument type after semantic.
2. Search `sumtypeVariants[sd]` for matching type via `implicitConvTo` or `equals`.
3. If exactly one match, use its index. Otherwise error.
4. Generate `StructLiteralExp` as above.

#### 4c. Code generation

`StructLiteralExp` goes through existing struct codegen. No special sumtype codegen needed for construction.

### Task 5: MatchExp in e2ir (Code Generation)

**File**: `compiler/src/dmd/glue/e2ir.d`

Replace `visitMatch` stub with conditional chain:

```d
elem* visitMatch(MatchExp me)
{
    // 1. Evaluate scrutinee to elem
    elem* scrut = toElem(me.arg, irs);

    // 2. Load __tag field (field[0] of the struct)
    // Use struct field offset 0 to get the uint tag
    elem* tag = el_una(OPind, TYuint, el_bin(OPadd, TYnptr,
        el_una(OPaddr, TYnptr, scrut), el_long(TYsize_t, 0)));

    // 3. Build conditional chain (right-to-left for correct nesting):
    //    if (tag == N) armN(scrut.fieldN) else if (tag == N-1) ... else assert(0)

    elem* defaultAssert = /* assert(0) elem */;
    elem* chain = defaultAssert;

    for (size_t i = me.arms.length; i > 0; )
    {
        i--;
        int variantIdx = me.armToVariant[i];

        // tag == variantIdx
        elem* cmp = el_bin(TYbool, OPeq,
            el_var(tag_sym), el_long(TYuint, variantIdx));

        // Extract payload field (field[variantIdx+1])
        elem* payload = /* load field at offset of fields[variantIdx+1] */;

        // Call arm function with payload
        elem* armCall = toElemCallForArm(me.arms[i], payload, irs);

        // chain = cmp ? armCall : chain
        chain = el_bin(TYcond, OPcond, cmp,
            el_bin(TYcolon, resultTy, armCall, chain));
    }

    return chain;
}
```

### Task 6: MatchExp in CTFE

**File**: `compiler/src/dmd/dinterpret.d`

Add `visit(MatchExp)` to `Interpreter`:

```d
override void visit(MatchExp me)
{
    // 1. Interpret scrutinee
    UnionExp ues = void;
    Expression scrut = interpret(&ues, me.arg, istate);
    if (exceptionOrCant(scrut))
        return;

    // 2. Read __tag from struct literal (field[0])
    auto sle = scrut.isStructLiteralExp();
    assert(sle);
    auto tagInt = (*sle.elements)[0].toInteger();

    // 3. Find matching arm by tag index
    int matchedArm = -1;
    for (size_t i = 0; i < me.arms.length; i++)
    {
        if (me.armToVariant[i] == cast(int)tagInt)
        {
            matchedArm = cast(int)i;
            break;
        }
    }
    if (matchedArm == -1)
    {
        error(me.loc, "non-exhaustive match at compile time");
        result = CTFEExp.cantexp;
        return;
    }

    // 4. Extract payload and call arm function
    auto payload = (*sle.elements)[tagInt + 1];
    auto armCall = new CallExp(me.loc, me.arms[matchedArm], payload);
    result = interpret(pue, armCall, istate, goal);
}
```

### Task 7: Destructor Generation

**File**: `compiler/src/dmd/typesem.d` — `visitSumType`

After generating the lowered struct, generate a custom destructor:

1. Ensure variant fields are marked as overlapped (union semantics):
   ```d
   foreach (field; sd.fields[1 .. $])  // skip __tag
       field.storage_class |= STC.overlapped;
   ```

2. Generate destructor body as AST:
   ```d
   auto dtorBody = new CompoundStatement(loc, [
       // switch (__tag) { case 0: ... case 1: ... }
       new SwitchStatement(loc, tagVarExp, caseStatements)
   ]);

   auto dtor = new DtorDeclaration(loc, Loc.initial, STC.safe | STC.nogc | STC.nothrow_,
       Id.__dtor, dtorBody);
   ```

3. Each case checks if the variant type has a non-trivial destructor:
   ```d
   // case i: this.__vi.__xdtor(); break;
   auto fieldExp = new DotVarExp(loc, thisExp, variantField);
   auto dtorCall = new CallExp(loc, new DotVarExp(loc, fieldExp, sdv.dtor));
   caseStmts ~= new CaseStatement(loc, IntegerExp.createLoc(i, loc),
       new CompoundStatement(loc, [
           new ExpStatement(loc, dtorCall),
           new BreakStatement(loc, null)
       ]));
   ```

4. Add `__xdtor` alias:
   ```d
   auto alias_ = new AliasDeclaration(Loc.initial, Id.__xdtor, dtor);
   sd.members.push(alias_);
   ```

### Task 8: Tag @safe Read-Only

**File**: `compiler/src/dmd/typesem.d` — `visitSumType`

When generating the `__tag` field:

```d
auto tagVar = new VarDeclaration(loc, Type.tuns32, tagId, null,
    STC.field | STC.const_);  // const for writes
```

The const will prevent writes to the tag field.

### Task 9: MatchExp Result Type for Chaining

**File**: `compiler/src/dmd/expressionsem.d` — `visit(MatchExp)`

When computing result type, if arms return distinct types `T1, T2, ...`:

```d
// Synthesize __sumtype(T1 | T2 | ...) as result type
auto resultVariants = new AST.Types();
// ... collect unique return types ...
exp.type = new TypeSumType(resultVariants[]);
```

This enables chaining: the result of one match is itself a sumtype that can be matched again.

### Task 10: Tests

**File**: `compiler/src/testsumtypematching/start.d`

```d
import core.stdc.stdio : printf;

void main() {
    // Basic unnamed sumtype
    alias S = __sumtype(int | bool);
    S val = 42;

    // Named sumtype
    alias T = __sumtype((int x) | (bool y));
    T t1 = T(x: 5);
    T t2 = T(y: true);

    // Unnamed constructor with type inference
    alias U = __sumtype(int | bool);
    U u1 = U(42);
    U u2 = U(false);

    // Match with new syntax
    auto result = val.match {
        (int i)    => i * 2,
        (bool b)   => b ? 1 : 0
    };

    // Chaining
    auto chained = val.match {
        (int i)    => i * 2.0,
        (bool b)   => None()
    }.match {
        (double d) => 42,
        (None _)   => 0
    };

    // Tag read in @safe
    @safe void testTag() {
        auto tag = val.__tag;  // OK: reading
        // val.__tag = 5;      // ERROR: writing in @safe
    }

    // 1-element sumtype
    alias Single = __sumtype(int);
    static assert(is(Single == int));
}
```

### Task 11: Exhaustiveness Checking

**File**: `compiler/src/dmd/expressionsem.d`

Refine existing check:
1. Every variant index `[0..N)` must have at least one arm (or wildcard).
2. Error: `"match is not exhaustive; missing variant %d (%s)"`.
3. Warning: `"redundant match arm for variant %d"`.

---

## 3. File Change Summary

| File | Changes |
|------|---------|
| `compiler/src/dmd/tokens.d` | Add `TOK.match_`, add to `keywords[]` and `tochars[]`. Keep `TOK.__match_` (deprecated). |
| `compiler/src/dmd/mtype.d` | Remove `variantTagHashes` from `TypeSumType`. Remove `sumtypeVariantTagHashes`. |
| `compiler/src/dmd/astbase.d` | Fix `TypeSumType` mirror: remove `tagHash`, add `loweredStruct`. |
| `compiler/src/dmd/typesem.d` | Remove hash computation. Generate custom `__xdtor` for sumtype. Mark variant fields overlapped. Mark `__tag` with `STC.system`. |
| `compiler/src/dmd/expressionsem.d` | **Major**: (1) Index-based auto-tag. (2) MatchExp: no CondExp lowering, store `armToVariant`. (3) Constructor init in `visit(CallExp)`. (4) Result type synthesis for chaining. |
| `compiler/src/dmd/glue/e2ir.d` | Implement `visitMatch` with conditional chain. |
| `compiler/src/dmd/dinterpret.d` | Add `visit(MatchExp)` for CTFE. |
| `compiler/src/dmd/parse.d` | Change `.match { }` syntax. Add `TOK.match_` handling in `parsePostExp`. |
| `compiler/src/testsumtypematching/start.d` | Add all test cases. |

---

## 4. Implementation Order

```
Task 1 (Tokens) ──> Task 2 (Parser .match{}) ──> Task 3 (Index tags)
                                                        │
                                                        v
Task 4 (Constructor init) ──> Task 7 (Destructor) ──> Task 8 (Tag @safe)
                         ──> Task 9 (Result type synthesis)
Task 5 (e2ir match) ──> Task 6 (CTFE match) ──> Task 10 (Tests)
Task 11 (Exhaustiveness) — refinement
```

---

## 5. Risks

| Risk | Mitigation |
|------|------------|
| Destructor switch on runtime `__tag` is slower than compile-time dispatch | Acceptable for MVP; optimize with jump tables for large sumtypes later. |
| Variant fields must be marked overlapped for correct dtor behavior | Test that `buildDtors` correctly skips overlapped fields. |
| Match arm function calls at CTFE need lambda evaluation | CTFE already handles `FuncExp` calls; verify with tests. |
| Result type synthesis for chaining creates nested sumtypes | Limit nesting depth; error on deeply nested types. |
| `.match` as contextual keyword after `.` may conflict with UFCS | Parser only triggers on `.match{` (with `{`), so `s.match(args)` still works as UFCS. |
