# Borrow Checker for the Fast DFA Engine

## Goal

Add borrow checking to the fast DFA engine (`compiler/src/dmd/dfa/fast/`): when a function call returns a borrow (triggered by the UDA
`__fastdfa_returnborrow`), the engine must detect, efficiently, whether an object has been borrowed from or is a borrow, and enforce:

1. The owner cannot be mutated while the borrow is alive.
2. The owner must outlive the borrow.
3. A borrow variable cannot be changed (reassigned, set to null, etc.) unless it is loop-local (minor restriction).

The DFAVar*/DFAObject* relationship is many-to-many; we need a reverse index for the owner-mutation check.

## Current State (verified)

- Escape relationship strength already exists: `ParameterDFAInfo.EscapedRelationship` (func.d:210) —
  `Unknown=0b00, ByValue=0b01, PointerTo=0b10, Borrows=0b11`, stored 2 bits per target in `Inferrable.escapesInto` (return = bits 0-1,
  `this` = bits 2-3, params = bits 6+2*i).
- `convergeFunctionCall` (analysis.d:117-302) dispatches on the relationship at call sites; the `Borrows` case (analysis.d:181-182)
  currently does nothing.
- The write funnel is `seeWrite` (analysis.d:2932), called from `transferAssign` (analysis.d:1569, 1605); all writes (direct, `*p=`,
  `x[i]=`, `x.f=`, `x[]=`) resolve to root `DFAVar*`s there.
- `DFAObject` has no borrow state; `DFACommon` uses fixed-size hash buckets with pointer-sorted chains (`vars[16]` pattern, structure.d:
  77-80).
- UDAs are parsed with `foreachUda(sym, sc, dg)` (attribsem.d:64); precedent: `__FastDFAEscapeTest` in entry.d:327-441.
- Lifetimes: `DFAVar.youngestLifeTimeAllowedDepth` = declaring scope depth (expression.d:644), `oldestLifeTimeAllowedDepth` = codegen
  storage end (loop boundary, expression.d:643). Params/this/return: depth 1 (statement.d:323-414). Scope depths strictly decrease up the
  `parent` chain; the walk never revisits a popped depth.
- `return exp` assigns to the return var via `seeAssign(dfaCommon.getReturnVariable, ...)` (statement.d:580) — the borrow registration
  funnel covers returns too.
- `&x` yields the cell object `x.storageFor` via `transferAddressOf` (analysis.d:2387+). `makeObject(storageForVar)` is cached on the var (
  structure.d:692-710).
- Engine runs under `version (FastDFA)` + `global.params.useFastDFA` (`-preview=fastdfa`), per function in `fastDFA` (entry.d:78), called
  from semantic3.d:1465. `DFACommon` is a fresh local per function run.

## Design Decisions (resolved with user)

1. **UDA semantics**: `@__fastdfa_returnborrow` on a *function* means the return borrows from `this`; on a *parameter* it means the return
   borrows from that parameter. Encoded as `willEscape(-3, EscapedRelationship.Borrows)` on the source's `userSupplied` Inferrable. Both on
   the same function → error. Test syntax is parameter-placed: `int* f(@__fastdfa_returnborrow ref int x) { return &x; }`.
2. **Registry (liveness)**: flow-insensitive entries attached to the *borrower's declaring DFAScope* (found by walking `currentDFAScope` up
   to `depth == borrower.youngestLifeTimeAllowedDepth` — depths are unique on the chain). Entries die with the scope; the mutation check
   only consults the current scope chain, so a dead borrow no longer protects its owner, and a new borrow registers its own entry. No
   unregistration needed (scope freed → entry leaked into the run allocator, reclaimed with the region).
3. **Changing borrows ban**: a borrow variable cannot be *changed* (reassigned, set to null, etc.) unless the change happens inside a loop
   AND the variable is declared inside that loop. Concretely, at an assignment to var `b` whose current LHS lattice object is a borrow (
   `obj.isBorrow`), report an error iff `lastLoopyLabel.depth == 1` (no enclosing loop) OR
   `b.youngestLifeTimeAllowedDepth <= lastLoopyLabel.depth` (b declared at the loop level or outside it). Loop-local borrows (
   `int* b = borrow(&x); b = 0;` inside one loop iteration) may change freely. Branch-exclusive first assignments (if/else) are not flagged
   because each branch's lattice starts from the pre-if state.
4. **Registry semantics — path-sensitive replace/remove, no union**: entries on a scope are the *current* borrows of each var on the current
   path. When the lattice check (decision 3) says `b` currently holds a borrow and the change is allowed (loop-local), `b`'s existing
   entries are removed first, then the new borrow (if any) is registered. Branch-exclusive writes never remove each other's entries (the
   lattice is path-sensitive: a sibling branch's `b = 0` sees the pre-if state, not a borrow, so no removal). Conditional borrows still end
   up with both cells registered (each branch registers its own) — that is correct union behavior emerging naturally, not explicit union
   semantics.
5. **Outlive check — one level deep**: at registration, compare the borrower against the *direct* source's owner: if the direct source
   object is a cell → owner = `cell.storageFor`; if the direct source is itself a borrow object (`isBorrow`) → owner = that object's
   `holderVar` (the variable holding the borrowed value). Require
   `borrower.youngestLifeTimeAllowedDepth >= owner.youngestLifeTimeAllowedDepth`, stack owners only. A borrow-of-a-borrow may not outlive
   the variable holding the borrowed value; deeper chains compose transitively (each level enforces its own constraint). If `holderVar` is
   null (nested call result never held by a var), fall back to the ultimate cell's owner.
6. **Registry keying — transitive**: the mutation check is keyed by cell objects, so registration resolves the borrowsFrom chain
   *transitively* through borrow objects to the ultimate cells and keys the entry there. The extra indirection is handled automatically:
   `c = borrow(b)` keys `c`'s entry on the same cells as `b`'s, so mutating the owner is caught as long as either is alive — and since `c`
   may not outlive `b` (decision 5), `b`'s entry is always alive while `c` is.
7. **Cell resolution is additive**: the borrow checker uses its own resolution walk (base1/base2/derivedFrom/inCell/borrowsFrom → root cells
   with `storageFor`). Field and pointer-indirection sources (`&s.f`, `*p`) DO register against the root cell. Existing escape-analysis
   rules (`gotACell`/`walkIndirection` behavior at analysis.d:249-297) are not changed — additive rules only.
8. **Callee-side**: no body validation against the UDA in v1 (a callee that doesn't actually return a borrow causes call-site false
   positives — documented limitation).
9. **Call-site precedence**: when `userSupplied` declares `Borrows` into the return, `userSupplied.escapesInto` must win over
   `inferred.escapesInto` at analysis.d:216 (the body analysis can only infer ByValue/PointerTo, which would silently downgrade the UDA).
10. **Owner passed to a call**: an owner with an active borrow may only be passed to a function whose parameter cannot mutate it — the
    parameter must be const/immutable where it reaches the cell. Concretely, at each call-site argument whose object graph resolves to a
    borrowed cell: error unless (a) the parameter is by-ref and its type is const/immutable (`ref const(int)` ok, `ref int` error), or (b)
    the parameter is a pointer/array/class type whose pointee is const/immutable (`const(int)*` ok, `int*` error), or (c) the parameter is
    by-value non-reference (a copy — no reach to the cell, always ok). This covers `foo(&x)`, `foo(x)` by ref, and `foo(p)` where `p` points
    to the owner (the callee could mutate `*p`). **The borrow-source parameter is exempt**: an argument whose parameter is the designated
    borrow source (`userSupplied.willEscape(-3) == Borrows`, i.e. the `__fastdfa_returnborrow` parameter) is never flagged — multiple
    borrows from one owner are allowed (`b1 = borrow(&x); b2 = borrow(&x);` compiles). Reported unconditionally (not gated on `@safe`), like
    the owner-mutation check.

## Implementation Tasks

### 1. UDA parsing — `entry.d` (fastDFA, entry.d:78)

New private helper `applyBorrowUDA(FuncDeclaration fd, Scope* sc)` called after the walker setup, before `stmtWalker.start(fd)`:

- `ensureDFAParameters(fd);` (idempotent, utils.d:23)
- `foreachUda(fd, sc, ...)`: if `StructLiteralExp` with `sd.ident.toString == "__fastdfa_returnborrow"` →
  `fd.parametersDFAInfo.thisPointer.userSupplied.willEscape(-3, EscapedRelationship.Borrows)`.
- For each `vd` in `*fd.parameters`: `foreachUda(vd, sc, ...)` → `parameters[i].userSupplied.willEscape(-3, Borrows)`.
- Both function-level and parameter-level present → error via `errorSink` (use `global.errorSink`; entry.d already imports what's needed —
  mirror the `checkEscapes` style, entry.d:327-441).

### 2. Call-site Borrows handling — `analysis.d`

**a. Precedence fix** (analysis.d:216-217): copy `paramInfo.userSupplied` to a temp first (avoid the `willEscape` read-side shift mutation,
func.d:256 — same trick as report.d:273), and:

```d
ulong escapesInto = paramInfo.inferred.escapesInto != 0
? paramInfo.inferred.escapesInto : paramInfo.userSupplied.escapesInto;
if (tempUser.willEscape(-3) == ParameterDFAInfo.EscapedRelationship.Borrows)
escapesInto = paramInfo.userSupplied.escapesInto;
```

**b. `handleRelationshipConsequence`** `case Borrows` (analysis.d:181-182), mirroring the ByValue pattern:

```d
case ParameterDFAInfo.EscapedRelationship.Borrows:
cctx.obj = dfaCommon.makeObject(cctx.obj);
cctx.obj.isBorrow = true;
cctx.obj.borrowsFrom = source;
return;
```

The output-param loop (analysis.d:232-300) needs no change (UDA only sets the return slot).

**c. Call-site owner-passing check — `callFunction` (expression.d:2497-2682)**: in the explicit-argument branch (expression.d:2613-2642),
right after `argExp = this.walk(arg)` (expression.d:2637) and before `seeFunctionCallArgument`, call a new helper
`checkBorrowArgument(argExp, argOffset, loc)`:

- `DFAObject* argObj = argExp.getContextObject;` — if null, nothing to check (by-value non-reference argument, or unknown).
-
`Parameter* param = toCallFunctionType !is null && toCallFunctionType.parameterList.parameters !is null && argOffset < length ? (*toCallFunctionType.parameterList.parameters)[argOffset] : null;` —
if null (C varargs, function pointers without parameters), skip (conservative).
- `paramCanMutate(ParameterDFAInfo* paramInfo, Parameter* param)`:
    - `paramInfo.isByRef` (ref/out/autoref) → return `!(param.type.hasConst || param.type.isImmutable)`.
    - `param.type` is Tpointer/Tarray/Taarray/Tclass/Tdelegate/Tsarray → return
      `!(param.type.nextOf().hasConst || param.type.nextOf().isImmutable)`.
    - Otherwise (by-value value type) → false (a copy, no reach to the cell).
- If `paramCanMutate` is true:
  `dfaCommon.resolveBorrowCells(argObj, (cellVar, cellObj) { if (dfaCommon.isCellBorrowed(cellObj)) reporter.onBorrowOwnerPassedToMutatingFunction(cellObj, param, loc); });`

**Borrow-source exemption**: at the top of `checkBorrowArgument`, copy `list.each[i].paramInfo.userSupplied` to a temp and skip the whole
check when `temp.willEscape(-3) == ParameterDFAInfo.EscapedRelationship.Borrows` (the parameter is the designated borrow source via the
UDA — same temp-copy trick as task 2a). This is what allows multiple borrows of one owner: `b1 = borrow(&x); b2 = borrow(&x);` both pass
`&x` to a mutable `ref` parameter that is the borrow source, and neither is flagged; any *other* function receiving the borrowed owner still
needs const/immutable parameters.

The check runs against the *current* registry state. The `this`-argument branch (expression.d:2573-2603) is not covered in v1 (needs the
called method's this-mutability; extension point with the identical mechanism).

### 3. Structure additions — `structure.d`

- `DFAObject` (structure.d:1970): add fields `DFAObject* borrowsFrom;` (the *direct* source — one level deep, never collapsed at creation),
  `bool isBorrow;`, and `DFAVar* holderVar;` (the variable currently holding this borrow value; set at registration, most recent wins) near
  `derivedFrom`/`inCell`.
- `makeObject(DFAObject* base1)` and `makeObject(DFAObject* base1, DFAObject* base2)` (structure.d:712-735): propagate
  `isBorrow = base1.isBorrow || base2.isBorrow`. Do NOT propagate `borrowsFrom`/`holderVar` (conditional combine bases are walked at
  registration instead).
- New `struct DFABorrowEntry { DFAVar* borrower; DFAObject* borrowedFrom; Loc loc; DFABorrowEntry* next; }` — flat per-scope list.
- `DFAScope` (structure.d:2321): add `DFABorrowEntry* borrowEntries;` (public, like other fields).
- `DFAAllocator`: add `DFABorrowEntry* freelistborrow;` + `makeBorrowEntry(DFAVar*, DFAObject*, Loc)` via `allocInternal!DFABorrowEntry` (
  structure.d:1394), + `free(DFABorrowEntry*)`; free the list inside `free(DFAScope)` (structure.d:1277) — or simply leak (region reclaims
  at function end); prefer the freelist for consistency.
- `DFACommon` helpers:
    - `DFAScope* findDeclaringScope(DFAVar* var)`: walk `currentDFAScope` up while `sc.depth > var.youngestLifeTimeAllowedDepth`; return
      that scope (assert non-null: the var is in scope at the assignment).
    - `void registerBorrow(DFAVar* borrower, DFAObject* cell, ref Loc loc)`: scan `findDeclaringScope(borrower).borrowEntries` for an
      existing `(borrower, cell)` pair; prepend if absent.
    - `void removeBorrowEntries(DFAVar* borrower)`: scan `findDeclaringScope(borrower).borrowEntries` and unlink every entry with that
      borrower (free via `DFAAllocator.free(DFABorrowEntry*)`). Only ever called when the var's current lattice is a borrow (path-sensitive
      guard), so sibling-branch entries survive.
    - `bool isCellBorrowed(DFAObject* cell)`: walk `currentDFAScope` up the parent chain, scanning each scope's `borrowEntries` for
      `borrowedFrom is cell`; return true on first match. Shared by the owner-mutation check and the call-site argument check.
    - `void resolveBorrowCells(DFAObject* obj, scope void delegate(DFAVar* cellVar, DFAObject* cellObj) del)`: **additive** walk used only
      by the borrow checker — traverses `base1`, `base2`, `derivedFrom`, `inCell`, and `borrowsFrom` chains to the root objects, delivering
      each root whose `storageFor` is a non-null, non-base variable. Handles `&x`, `&s.field`, `*p`, conditional combines, and
      borrow-of-borrow chains transitively. Does not modify `walkIndirection`/`gotACell`.

### 4. Registration + ban + outlive checks — `transferAssign` (analysis.d:1380)

After `wasDereferenced` is computed (analysis.d:1457), inside `if (assignToCtx !is null)`, guarded by
`lrCctx !is null && lrCctx.obj !is null`:

1. **Dereference store** (`wasDereferenced`, e.g. `*p = borrow(&x)`): the borrow lives in memory, not a tracked variable.
   `reporter.onBorrowStoredThroughDereference(loc)` — that function gates the error on the analyzed function being `@safe` (
   `dfaCommon.currentFunction.type.isTypeFunction.trust == TRUST.safe`); `@system` code accepts it silently with no registration. No other
   checks apply.
2. **Change/ban check** (`!wasDereferenced`): `DFAConsequence* lhsCctx = assignTo.getContext;` — if
   `lhsCctx.obj !is null && lhsCctx.obj.isBorrow && !construct`:
    - `const loopDepth = dfaCommon.lastLoopyLabel.depth;`
    - If `loopDepth == 1 || assignToCtx.youngestLifeTimeAllowedDepth <= loopDepth` →
      `reporter.onBorrowVariableReassignment(assignToCtx, loc)` (b is a borrow declared outside the nearest loop, or there is no loop —
      matching `int* b = borrow(&x); for(;;) b = null;` being an error).
    - Else (loop-local borrow): `dfaCommon.removeBorrowEntries(assignToCtx)` — drop the var's existing entries before the new value is
      registered below.
3. **Registration + outlive** (guarded additionally by `!wasDereferenced`): add
   `DFAObject.walkBorrowSources(scope void delegate(DFAObject* borrowsFrom) del)`: recursive over `base1`, `base2`, and `borrowsFrom`. For
   each direct `borrowsFrom` source `S` of `lrCctx.obj`:
    - **Direct owner (one level deep)**: if `S.isBorrow` → `DFAVar* owner = S.holderVar;` (fallback if null: resolve `S` via
      `resolveBorrowCells` and use the first cell's `storageFor`). Else → resolve `S` via `resolveBorrowCells`; owner = `cell.storageFor` of
      the resolved cell.
    - **Outlive check**: if owner non-null and the cell is a stack cell (`cell.onTheStack` or `owner.isStackVar`): if
      `assignToCtx.youngestLifeTimeAllowedDepth < owner.youngestLifeTimeAllowedDepth` →
      `reporter.onBorrowOutlivesOwner(assignToCtx, owner, loc)`. Params (depth 1) always pass; heap/global owners skipped.
    - **Transitive keying**: resolve `S` via `resolveBorrowCells` (which follows borrow objects transitively) and
      `dfaCommon.registerBorrow(assignToCtx, cell, loc)` for each cell — the entry keys the mutation check on the ultimate owner cell.
    - Record the holder: for each direct borrow node `S` processed, set `S.holderVar = assignToCtx` (most recent holder wins) so deeper
      borrows check against it.
    - Skip registration entirely for a non-stack owner (no lifetime constraint, nothing to protect).

`removeBorrowEntries(DFAVar* borrower)` (DFACommon helper): scan the borrower's declaring scope's `borrowEntries` and unlink all entries
with `borrower` — called only when the lattice says the var currently holds a borrow, so sibling-branch entries are never removed.

This single funnel covers: direct `b = borrow(&x)`, construct `int* b = borrow(&x);`, propagation `b2 = b1` (registers `b2` too, keyed on
the same cells), conditional borrows (combine objects walk both bases), field/pointer sources (`borrow(&s.f)`, `borrow(*p)` via the additive
resolution), borrow-of-borrow (`c = borrow(b)` — outlive vs `b`, keyed transitively on `x`'s cell), loop-local changes (remove +
re-register), and `return borrow(...)` (return var is the assignTo).

### 5. Owner-mutation check — `seeWrite` (analysis.d:2932)

- Add `ref Loc loc` parameter to `seeWrite`; update both callers (analysis.d:1569, 1605; `constructVariable` → `seeAssign` chain already
  passes loc).
- In the `walkRoots` delegate (analysis.d:2943), after `root.writeCount++`:
  ```d
  if (root.storageFor !is null)
      checkBorrowMutation(root.storageFor, loc);
  ```
  (`storageFor` is only materialized when the address was taken — zero churn for plain vars.)
- New `void checkBorrowMutation(DFAObject* cell, ref Loc loc)`: `dfaCommon.isCellBorrowed` gives the first matching entry; on a match →
  `reporter.onBorrowOwnerMutation(entry, loc)` (report once per write). O(depth × borrows-per-scope); depths are small and borrows are rare.

### 6. Reporting — `report.d`

Add to `DFAReporter` (follow existing `errorSink.error` + `errorSupplemental` style):

- `onBorrowOwnerMutation(DFABorrowEntry* entry, ref const Loc loc)`: "Cannot mutate the owner of an active borrow" + supplement at
  `entry.loc` "Borrowed here" + borrower declaration.
- `onBorrowOutlivesOwner(DFAVar* borrower, DFAVar* owner, ref const Loc loc)`: "A borrow cannot outlive the variable it borrows from" +
  owner/borrower declaration supplements.
- `onBorrowVariableReassignment(DFAVar* borrower, ref const Loc loc)`: "Cannot change a borrow variable declared outside of a loop" +
  borrower declaration.
- `onBorrowStoredThroughDereference(ref const Loc loc)`: "Cannot store a borrow through a dereference in @safe code" — gated internally on
  `dfaCommon.currentFunction.type.isTypeFunction.trust == TRUST.safe` (the `TRUST` import already exists in report.d, used at report.d:286);
  `@system` functions accept the pattern silently.
- `onBorrowOwnerPassedToMutatingFunction(DFAObject* cell, Parameter* param, ref const Loc loc)`: "Cannot pass the owner of an active borrow
  to a function that may mutate it" + supplement naming the parameter (`param.ident` when present) + "Parameter must be const or
  immutable" + the borrow site supplement (find the entry via `isCellBorrowed`).
- `report.d` needs `DFABorrowEntry` import — it already imports `dmd.dfa.fast.structure`.

### 7. Tests

No new test files. Extend the existing `__fastdfa_escape_test` files (they already carry `REQUIRED_ARGS: -preview=fastdfa` and `#line 1000`;
add `struct __fastdfa_returnborrow {}` to the test module). The fail_compilation file's `TEST_OUTPUT` block pins exact line numbers — append
new cases and update the block (all following line numbers shift).

`compiler/test/compilable/__fastdfa_escape_test.d` (must compile, no errors):

- Callee: `int* f(@__fastdfa_returnborrow ref int x) { return &x; }`; caller borrow + read; owner mutation *after* the borrow's block ends (
  no error).
- Borrow of a parameter; param mutation after the borrow's block ends (no error).
- Struct method with function-level UDA: `int* get() @__fastdfa_returnborrow` (borrows from `this`); mutating the struct instance after the
  borrow's block ends (no error).
- Multiple concurrent borrowers of one owner: `b1 = borrow(&x); b2 = borrow(&x);` while `b1` is still alive (the second borrow call must
  compile — the borrow-source parameter is exempt from the const/immutable check; both borrows block owner mutation); borrow of a field (
  `borrow(&s.field)`); borrow through a pointer (`borrow(p)` where `p = &x`).
- **Struct owner**: `struct S { int field; }` — `int* b = borrow(&s);` (the struct has no DFAObject* of its own; the source resolves through
  the *cell of the variable* `s`); read via the borrow; mutate `s.field` after the borrow's block ends (no error); pass `&s` to `const(S)*`
  and `ref const(S)` parameters while borrowed (no error).
- `b2 = b1` propagation; conditional borrow (`cond ? borrow(&x) : borrow(&y)`); borrow-of-borrow `c = borrow(b)` where `c` dies before `b`;
  `if (c) b = borrow(&x); else b = 0;` (branch-exclusive, no error).
- Loop-local borrow changes: `for (;;) { int* b = borrow(&x); b = 0; }` (allowed — b is loop-local; x is not protected after `b = 0` within
  the iteration).
- Borrow created inside a loop assigned to an outer var: `int* b; for (;;) { b = borrow(&x); }` (allowed — first assignment; owner still
  protected after the loop via the entry on b's declaring scope).
- `@system` dereference store: `void sys(int* p) { *p = borrow(&x); }` (no error, no registration).
- Passing the borrowed owner to const-accepting calls: `foo(const(int)* p)` and `foo(ref const(int) x)` while the owner is borrowed (no
  error); passing the borrow var itself to a `const(int)*` parameter (no error).
- Borrow of heap (`borrow(new int)`) — no checks.

`compiler/test/fail_compilation/__fastdfa_escape_test.d` (errors, regenerate `TEST_OUTPUT`):

- Owner mutation while borrow alive: direct straight-line (`x = 5` after `b = borrow(&x)`), inside a nested scope while the borrow is alive,
  through the borrow (`*b = 5`), and through an index (`b[i] = 5`).
- **Struct owner mutation while borrowed**: `s.field = 5;` and `s = S(0);` while the borrow of `&s` is alive (both write the root var `s`;
  the cell check must fire).
- Borrow outlives owner: block-scoped owner (struct with destructor) assigned to an outer var; `return borrow(&local);`.
- Borrow-of-borrow outlives its direct source: `c = borrow(b)` with `c` declared outside `b`'s block.
- Changing a borrow declared outside a loop: `int* b = borrow(&x); for (;;) b = null; // error`; also straight-line
  `b = borrow(&x); b = null;` and `b = borrow(&y);`.
- `@safe` dereference store: `void safe1(int* p) @safe { *p = borrow(&x); }` (error).
- Passing the borrowed owner to a mutating parameter: `foo(int* p)` with `foo(&x)` while x is borrowed; `foo(ref int x)`; `foo(S* p)` with
  `foo(&s)` while s (struct) is borrowed; and passing the borrow var itself (`foo(b)` where the parameter is `int*`).
- UDA on both function and parameter (conflicting sources).

### 8. Verification

- Build: `cd compiler/src && rdmd build.d` (per AGENTS.md).
- Run the DFA tests with the user's harness: `C:\Program Files\Git\bin\bash.exe testdfa/run.sh` (note: `testdfa/run.sh` is a local script
  outside the repo; not present in `P:\dmd`).
- Regression: the existing `__fastdfa_escape_test` cases must still pass, confirming the precedence change (task 2a) does not alter
  inferred-escape behavior — the flip only applies when `userSupplied` declares `Borrows`, which no existing case uses.

## Known Limitations (v1 — acceptable, document in code comments)

1. Same-scope declaration order is NOT a limitation: `int* b; int x; b = borrow(&x);` in one scope is fine, and destructor-pinned owners are
   already handled by the existing variable-lifetime and compiler scoping rules (a struct with a destructor pins
   `oldestLifeTimeAllowedDepth` to its exact scope, expression.d:646-663).
2. The `this` argument of method calls on a borrowed owner is not checked in v1 (needs the called method's this-mutability; the mechanism is
   identical to the explicit-argument check and is the natural extension point).
3. The callee body is not validated against `__fastdfa_returnborrow` (a lying callee causes call-site false positives).
4. A borrow-of-a-borrow whose direct source object has no `holderVar` (nested call result never held by a variable) falls back to the
   ultimate cell's owner for the outlive check — slightly looser than one-level-deep.
5. `@system` code that stores a borrow through a dereference (`*p = borrow(&x)`) gets no borrow protections at all (deliberate — the error
   is gated on `@safe`).
6. Goto-label regions count as "loops" for the change-ban allowance (`lastLoopyLabel` is also set for labels) — a borrow declared inside a
   label region may be changed there.
7. The call-site argument check skips arguments when the parameter type is unavailable (C varargs, parameterless function pointers) —
   conservative skip, no error.

## Out of Scope

- `@escape(return^)` syntax parsing (UDA is the v1 trigger).
- `@live`/DIP1021 `dmd.ob` integration.
- Borrowing into output parameters (only the return slot is handled).
- Cross-function borrow tracking (no separate compilation support).

## Audit Reminder (per AGENTS.md)

When this work is intended to be contributed back to dmd upstream, audit the changes before contributing. Confirm understanding of each
change (particularly the `userSupplied`/`inferred` precedence change in task 2a, which affects call-site escape dispatch).
