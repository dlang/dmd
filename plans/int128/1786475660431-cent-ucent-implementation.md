# Plan: Implement `cent` and `ucent` (128-bit integers) in dmd

Target: this repo (fork of dmd master ~2.108). The parser is `Parser!(AST)` in `parse.d`, instantiated with `ASTCodegen` (`dmodule.d parseModule!ASTCodegen`) — parse output is the **classic tree** (`dmd.expression` etc.) directly; `astbase.d`/`ASTBase` is a parse-only mirror family **not** in the compiler's main path and needs no changes. Platforms: **x86-64 (`-m64`, MODEL=64)** fully; **32-bit x86 (`-m32`)** for arithmetic via `core.int128` calls (see decisions). ARM/AArch64 **out of scope** (guard shared-file changes behind `I16`/`AArch64` checks).

## Goal

Make `cent`/`ucent` real, working integer types: declaration, assignment, literals, all arithmetic/bitwise/compare ops, casts to/from 64-bit types, struct/array/param/return usage, full constant folding and CTFE. Codegen principle (user directive): **prefer hardware instructions where they exist, otherwise use `core.int128`**.

- On m64: inline hardware codegen for all arithmetic; hardware `DIV`/`IDIV` for 128÷64; `core.int128` calls for 128÷128 (no hardware exists).
- On m32: no 128-bit hardware exists → `core.int128` calls for all arithmetic ops (add/sub/mul/div/mod/shifts/bitwise/neg/com; comparisons via `lt`/`le` with operand swap for gt/ge; equality stays backend word-compare). Casts/moves/loads/stores stay backend-side (verify m32 plumbing).

**`int128`/`uns128` are NOT user-facing type names** — they exist only as internal enum names (`TY.Tint128/Tuns128` in `astenums.d`, `TOK.int128/TOK.uns128` in `tokens.d`, whose `toChars` are "cent"/"ucent"). The lexer has no `int128`/`uns128` keywords and none shall be added — those spellings lex as identifiers and fail lookup naturally. No parse cases, no docs, no spec text for them.

## Current state (verified)

Already present and working:
- Keywords `cent`/`ucent` parse to `TypeBasic Tint128/Tuns128` (`mtype.d`); `size()` returns 16 (`typesem.d visitBasic`); integral/unsigned flags set.
- Full implicit-conversion/result matrix in `impcnvtab.d` (e.g. `cent + long → cent`, `cent + ucent → Tuns128`, `cent + float → float`).
- Mangling: `'z' + 'i'/'k'` (`mangle/basic.d`) — identical on m32/m64.
- Backend `TYcent/TYucent`: 16 bytes, **align 8**, shared with `TYdelegate = TYcent`, `TYdarray = TYucent` (`backconfig.d`). Loads/stores/moves/pairs/passing/returns (`regmask`/`allocretregs`/`FuncParamRegs_alloc` two-GPR pair; m32 stack/`OPpair` push paths in `pushParams`/`movParams`), comparisons (`cdcmp` on I64), zero-tests (`tstresult`), and **complete constant folding via `dmd.common.int128` in `evalu8.d`** already work.
- `e2ir.d` cast cases for 128-bit (`OPs64_128`/`OPu64_128`/`OP128_64`, `Lpaint`) exist but are unreachable; float↔cent disabled with `static if (0)`.
- druntime `core.int128` (both in-repo `P:\dmd\druntime` **and** the external `P:\ProjectSidero\dmd2` install used by run.sh — verified) already provides everything needed: `add`, `sub`, `mul`, `div`, `udiv`, `rem`, `urem`, `and`, `or`, `xor`, `com`, `neg`, `abs`, `shl`, `shr`, `sar`, `lt`, `le`, `ult`, `ule` (int128.d). `TypeInfo_zi : TypeInfoGeneric!cent` / `TypeInfo_zk` gated on `is(cent)` (`rt/util/typeinfo.d`); `int128_t`/`uint128_t` aliases gated on `is(ucent)` (`core/stdc/stdint.d`).
- ABI: `argtypes_sysv_x64.d` passes Tint128 as two integer classes; `argtypes_x86.d` (m32) treats it as a single unit — audit.
- Verification tooling available: `Q:\Misc Software\clang+llvm-22.1.8-x86_64-pc-windows-msvc\bin` (clang + llvm-objdump, COFF-capable).

Blockers / gaps:
1. `typesem.d visitType` rejects all usage: "`cent` and `ucent` types are obsolete..." (the gate).
2. **No 128-bit constant representation** — `IntegerExp.value` is `dinteger_t` (64-bit); lexer caps literals at `ulong` (overflow = error); `sizemask` asserts on 128-bit (`typesem.d`); constfold and the CTFE interpreter are 64-bit only.
3. `glue/package.d totym` has no Tint128/Tuns128 case → `assert(0)`.
4. `e2ir visitInteger` → `el_long(TYcent, ...)` leaves `Vcent.hi` garbage.
5. **Backend x86-64 arithmetic is missing/wrong for 16-byte ints** (dead code today):
   - `cdorth` (x86/cod2.d): 16-byte operands get `numwords == 1` → single 64-bit op.
   - `cdneg`/`cdcom` (x86/cod2.d): pair sequences without REX.W on I64.
   - `cdshift` (x86/cod2.d): partial; small-const loop path without REX.W; verify all 0..127 cases.
   - `cdmul` (x86/cod2.d): 32-bit-only pair sequence on I64.
   - `cddiv`/`cdmod` (x86/cod2.d): 16-byte path calls 64-bit CLIB helpers → wrong; needs hardware DIV for 128÷64 and `core.int128` calls for 128÷128 (backend IR has **no branches**, only `OPcall`).
   - `cdshtlng` (x86/cod4.d): `OPs64_128` sign-extend missing REX.W (wrong on I64); m32 64→128 path unverified.
   - `cdbswap`: `assert(sz != 16)`.
   - `evalu8.d OPmsw`: result-size-keyed switch mishandles 16-byte sources.
   - `cod4.d` opass/`OPnegass`: `LLONGSIZE` on I16 asserts "not implemented yet".
   - `loaddata` flags-only zero-test path missing REX.W (latent).
6. `fail_compilation/fail22827.d` expects the obsolete-type error (must be replaced); `compilable/warn3882.d` has `static if (is(cent))` tests that will auto-activate.

## Design decisions

- **New expression type for 128-bit constants**: add `EXP.bigInteger` to the `EXP` enum (`tokens.d`) and a `BigIntegerExp` class in `expression.d` holding `dmd.common.int128.Int128` (mirrors `RealExp`; `type.ty` distinguishes cent/ucent). Do **not** widen `IntegerExp.value`. `parse.d` builds it directly (the parser emits codegen AST).
- **Alignment: 8** on x86 (both m32 and m64) — matches backend `_tyalignsize[TYcent]` (shared with delegates/darrays; changing it would break delegate ABI). Frontend `target.alignsize` special-cases Tint128/Tuns128 → 8. (Diverges from C `__int128` align 16 on x86-64 — acceptable, cent is D-only.)
- **Div/mod and m32 arithmetic via `core.int128`**: m64 → hardware everywhere except 128÷128, which calls `core.int128` (`div`/`udiv` for `/`, `rem`/`urem` for `%`). m32 → all arithmetic ops lower to `core.int128` calls (`add`/`sub`/`mul`/`div`/`udiv`/`rem`/`urem`/`and`/`or`/`xor`/`com`/`neg`/`shl`/`shr`/`sar`; gt/ge synthesized by operand swap over `lt`/`le`, gt/ge unsigned via `ult`/`ule` swap). References via new RTLSYM entries with the D-mangled symbol names. **No changes to `rt/llmath.d` or any druntime code.**
- **Literals > 64 bits in scope**: lexer produces `TOK.int128Literal`/`TOK.uns128Literal` (token enum entries already exist; lexer never emits them today) when a literal overflows `ulong`; parser builds `BigIntegerExp`.
- **Full CTFE/constfold support** via `dmd.common.int128` (a `dmd` module; backend already imports it — frontend may too).
- **float↔cent conversions out of scope**: reject at semantic with a clear "not supported" error; leave the `static if (0)` blocks in `e2ir.d` as-is.
- `.max`/`.min` implemented (needed by druntime `TypeInfoGeneric` which uses `T.max`).
- `is(cent)`/`is(ucent)` become true → druntime `TypeInfo_zi/zk` and `stdint` aliases activate on next druntime rebuild (no compiler work).

## Implementation tasks (ordered)

### M0 — Harness sanity
- Run `C:\Program Files\Git\bin\bash.exe compiler/src/test128/run.sh` (note: the prompt's path `compiler/srctest128int/run.sh` does not exist; the harness is `compiler/src/test128/run.sh`). Confirm build + empty `main` run works. `start.d.cg` is the expected `-vcg-ast` header output — regenerate whenever `start.d` changes.
- Extend `run.sh` with an m32 leg (pattern from `testsumtypematching/run.sh`): `dmd -m32 -run test128/start.d` (32-bit druntime/phobos come from the external dmd2 install — proven to work).

### M1 — Types work end-to-end for trivial code
1. `typesem.d visitType`: delete the obsolete-type error.
2. `target.d alignsize`: add `Tint128/Tuns128` → 8.
3. `typesem.d sizemask`: add Tint128/Tuns128 → `~0` (any 64-bit value fits; 128→64 narrowing is rejected at type level by `implicitConvTo(Type,Type)`/`dcast castTo` — verify).
4. `typesem.d visitBasic getProperty`: `cent.max/min`, `ucent.max/min` → `BigIntegerExp` (`cent.max = 0x7FFF...`, `ucent.max = 0xFFFF...`).
5. New `BigIntegerExp`:
   - `tokens.d` EXP enum: `EXP.bigInteger`; `expression.d`: class (ctor `(Loc, Int128, Type)`, `isBigIntegerExp`, `getInteger`, `syntaxCopy`, `accept`, `printExp`, `isConst` → 1, `toChars`), expClassSize table entry; `expressionsem.d Expression::toInteger/toUInteger` case (error if value doesn't fit 64 bits, else low 64).
   - `dmd.common.int128`: add `string toChars(Int128)` (decimal; hex variant for diagnostics) — needed by `BigIntegerExp.toChars` and error messages.
   - Mechanical: add `EXP.bigInteger` to every op-switch/visitor that handles `EXP.int64` (compile errors will point at `final switch`es): `dinterpret.d`, `optimize.d` dispatch, `ctfeexpr.d`, `e2ir.d`, `hdrgen.d`, `printast.d`, `semantic2/semantic3` expression visitors, `escape.d`, `safe.d`, `nogc.d`, `canthrow.d`, `sideeffect.d`, `mustuse.d`, `inlinecost.d`, `blockexit.d`, `dfa`, visitor mixins in `visitor/package.d`, `dcast.d` range checks, `enumsem.d` enum-value paths.
   - `dcast.d` expression-level `implicitConvTo`/`getIntRange`: handle `BigIntegerExp` (64-bit-value-always-fits semantics; Int128-based fit check).
6. `dcast.d castTo`: reject float/imaginary/complex ↔ cent casts with a clear error (out of scope feature).
7. Glue/codegen plumbing:
   - `glue/package.d totym`: `Tint128 → TYcent`, `Tuns128 → TYucent`.
   - `backend/el.d`: `el_cent(tym_t, Int128)` (OPconst + Vcent); `e2ir visitInteger`/`visitBigInteger`: 16-byte-typed constants via `el_cent` (also covers `cent.init` = IntegerExp(0) of 128-bit type).
   - `e2ir toElemCast`: verify the existing `X(Tint128,...)` cases now execute correctly (small→128 widening, `OPs64_128`/`OPu64_128`, `OP128_64`, `Lpaint` for cent↔ucent) on **both m64 and m32** (m32 `cdshtlng`/`cdlngsht`/`cdpair` paths need auditing — see M2/m32).
8. Backend x86-64 correctness (the bulk; all 16-byte paths need REX.W on I64):
   - `cdshtlng` (x86/cod4.d): fix `OPs64_128` sign-extension (REX.W).
   - `cdorth` (x86/cod2.d): 16-byte → `numwords = 2` with REX.W (ADD/ADC, SUB/SBB, OR, XOR, AND).
   - `cdneg`/`cdcom` (x86/cod2.d): 16-byte pair sequences with REX.W.
   - `cdshift` (x86/cod2.d): complete 16-byte shifts — const 0..127 (incl. 64 boundary) and variable counts; REX.W everywhere.
   - `cdmul` (x86/cod2.d): 128×128→128 via MUL cross-terms (lo·lo, lo·hi, hi·lo, carry-in).
   - `cddiv`/`cdmod` (x86/cod2.d): `OPremquo`/`OPdiv` with 16-byte dividend ÷ 8-byte divisor → hardware `DIV`/`IDIV` (RDX:RAX); 16÷16 → `core.int128` calls (M2).
   - `cod4.d` opass paths: `OPaddass`/`OPminass`/`OPandass`/`OPorass`/`OPxorass`/`OPnegass`/postinc/postdec for 16-byte (fix the `LLONGSIZE` I16 assert).
   - `evalu8.d OPmsw`: handle 16-byte source (key the case on source size).
   - `loaddata` (cod1.d) flags-only zero test: REX.W.
   - `cdbswap`: optional — implement 16-byte or keep assert (not reachable from D source without an intrinsic; do not advertise).
9. M1 tests in `test128/start.d`: `sizeof(cent)==16`, `alignof(cent)==8`, `cent.init == 0`, assignment from int/ulong literals, casts both directions (incl. negative → sign extension), struct/array containing cent, function params/returns (stack + registers), `cent.max/min`, `is(cent)`, `.init`, `enum cent e = 5`. Guard m32-only behavior in the test where needed (arith via calls vs inline is semantically identical — tests should pass unchanged on both).

### M2 — `core.int128` calls (128÷128 on m64; all arithmetic on m32)
- New RTLSYM entries (follow the existing enum/`symbolz` patterns in `backend/rtlsym.d`) whose symbol names are the **D-mangled names** of `core.int128`'s `div`/`udiv`/`rem`/`urem` (m64) plus `add`/`sub`/`mul`/`and`/`or`/`xor`/`com`/`neg`/`shl`/`shr`/`sar`/`lt`/`le`/`ult`/`ule` (m32). Determine the exact mangled strings by compiling a probe program that calls `core.int128.div` etc. and inspecting the emitted symbol (llvm-objdump, see M8); hardcode them with a comment referencing `core/int128.d` (precedent: hardcoded `_Dmain`). Signatures `Cent f(Cent, Cent)` match the existing TYcent param/return machinery on m64 (two GPRs) — verify `symbolz` linkage flags produce an undecorated name.
- `e2ir`: add a cent-binop lowering helper: on m64, `div`/`mod` with 16÷16 operands → `OPcall` (`div`/`udiv` per signedness of the divisor expression, `rem`/`urem` for `%`); on m32, **all** 128-bit binops/unops → `OPcall` (`gt`/`ge` → operand-swapped `lt`/`le`; unsigned via `ult`/`ule`; equality stays backend word-compare). Constant operands still fold in `evalu8` first.
- Verify m32 call plumbing end-to-end: 16-byte stack args (aligned 8, `pushParams`/`movParams` OPpair paths), 16-byte returns on m32 (hidden sret via `allocretregs` I32 stack path), m32 casts (`OPs64_128`/`OP128_64`/`cdpair` — add what's missing, it's word-level sign/zero extension).
- No druntime edits, no external-install sync.
- Test: div/mod matrix incl. signs, division by zero (runtime trap), `%` vs `/` consistency, 128÷64 fast path vs 128÷128 helper path (force 128-bit divisor via `cast(ucent)1 << 64`), full arithmetic matrix on m32, `abs` sanity. Same `start.d` assertions run on both m64 and m32 legs.

### M3 — 128-bit literals
- `lexer.d number()`: on ulong overflow, keep accumulating into `Int128`; emit `TOK.int128Literal` (or `uns128Literal` with `u`/`U` suffix); error only beyond 128 bits. Verify suffix handling (`u`/`U`/`L` combos) and hex/octal/binary forms.
- `parse.d`: literal tokens → `BigIntegerExp` (type `tint128`, or `tuns128` when `u`-suffixed). Rule: unsuffixed overflow literal is `cent`; `u`-suffixed is `ucent` (document in spec).
- `-vcg-ast` output (`start.d.cg`) will change — regenerate.
- Test: `cent c = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;` (=-1), `ucent c = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFu`, decimal `170141183460469231731687303715884105727`, `-2^127`, boundary `2^127-1` vs `2^127`, hex `0x80000000000000000000000000000000`.

### M4 — constfold (compile-time arithmetic)
- `constfold.d`: make `Neg, Com, Not, Add, Min, Mul, Div, Mod, Shl, Shr, Ushr, And, Or, Xor, Equal, Cmp, Cast` 128-aware: when operand types are Tint128/Tuns128 use `BigIntegerExp.value` + `dmd.common.int128` ops (`add/sub/mul/div/udiv/divmod/udivmod/and/or/xor/com/neg/shl/shr/sar/le/lt/ule/ult`), produce `BigIntegerExp` results. Result types from `impcnvtab` already correct.
- `Pow` (^^): support constant-folding via repeated `mul` (Int128); runtime `cent ^^ x` with non-constant exponent → clear "not supported" error for now (audit `e2ir visitPow`).
- `optimize.d` dispatch: route `EXP.bigInteger` leaves through the fold functions; the shift bound check (`size()*8 = 128`) is already correct.
- `Cast` in constfold: int↔cent via Int128 (narrowing wraps mod 2^n, widening sign/zero-extends); float↔cent stays an error.

### M5 — CTFE (dinterpret/ctfeexpr)
- `ctfeexpr.d`: `paintTypeOntoLiteral` (BigIntegerExp), `toCtfe` (cent), `assignInPlace` (BigIntegerExp set/get), `ctfeCast` (int↔cent via Int128; float↔cent error).
- `dinterpret.d`: dispatch case for `EXP.bigInteger` (identity leaf); `interpretCommon`/`interpretCompareCommon` (constfold fns now 128-aware — the fp dispatch works); audit every `toInteger`-on-value site for cent operands (error when >64 bits — e.g. array indices, `getInteger`-driven paths).
- `expressionsem.d toInteger` write-back sites — `BigIntegerExp` case must not silently truncate: error "value does not fit in 64 bits" (only 128-aware paths use `Int128`).
- Test: `enum cent a = 0x1234... + 1;` `static assert` arithmetic/comparison, CTFE function `cent f(cent x)` called at compile time (template value param `cent`), casts in CTFE.

### M6 — Semantic polish + regression
- Verify `importC` `__int128`/`unsigned __int128` now map to cent/ucent (`cparse.d` already routes type parsing through `integerTypeForSize(16)`; audit/replace the "not supported" errors at the expression/constant paths). Note: this is C interop, unrelated to the D names `int128`/`uns128` — those remain non-types.
- Remove/replace `compiler/test/fail_compilation/fail22827.d` (no longer an error; delete the test or convert expectations).
- Run `compilable/warn3882.d` — its `static if (is(cent))` sections should now compile and pass (validates checked-arithmetic wrappers over cent).
- Smoke-regress: compile a handful of existing `compiler/test/runnable`/`compilable` tests with the new dmd (full suite on Windows is out of scope).
- Negative tests in `test128/run.sh` (pattern from `testsumtypematching/run.sh`): float↔cent cast error; implicit `cent → long` narrowing error; runtime `^^` error.

### M7 — Docs
- `spec/lex.dd`: 128-bit integer literal rules; remove the `$(GDEPRECATED cent)`/`ucent` markers (lines ~1034/1123).
- `spec/types.dd` basic-types table: cent/ucent no longer deprecated; note size (16) and alignment (8). Do **not** add `int128`/`uns128` as type names.
- `spec/expression.dd`: casts involving cent; `spec/abi.dd` already has `TypeCent/TypeUcent` grammar.
- `changelog/`: entry.

### M8 — `core.int128` lowering & codegen verification (m64 + m32) — REQUIRED
Verify, not assume, that the `core.int128` calls lower correctly and codegen right on **both** x86 targets. Tooling: `Q:\Misc Software\clang+llvm-22.1.8-x86_64-pc-windows-msvc\bin` (`llvm-objdump.exe` handles COFF; `clang.exe` compiles C reference code).
1. **Mangled-name probes**: small D files calling `core.int128.{div,udiv,rem,urem,add,mul,...}`; compile `-c` with the built dmd on m64 and m32; `llvm-objdump -d` and extract the referenced symbol names; confirm they match the hardcoded RTLSYM strings exactly (any mismatch = link error, caught here first).
2. **Call-site inspection**: compile `test128` probe functions with `-c`; `llvm-objdump -d` the COFF objects and verify:
   - m64: 128÷64 div/mod = single `DIV`/`IDIV` (RDX:RAX); 128÷128 = `call` to `_D4core6int128...` with the right per-signedness symbol; all other arithmetic inline with REX.W (spot-check `ADD`/`ADC` pairs, `MUL` cross-term sequence, `SHLD`/`SHRD` shifts).
   - m32: every arithmetic op = `call` to the right `core.int128` symbol; 16-byte args passed on the stack (aligned), 16-byte returns via sret; casts/moves inline.
3. **Cross-check against clang**: compile C equivalents (`__int128`) with the provided clang (`-m64` and `-m32`), `llvm-objdump -d`, and compare instruction sequences as reference for add/mul/div/shift (clang uses inline hardware on m64 and libcalls on m32 — a direct structural comparison of our choices).
4. **Runtime verification**: the m64 and m32 legs of `run.sh` run the same `start.d` assertion suite (all ops on both targets); div-by-zero traps; results must be identical.
5. Record findings in the harness (comments in `run.sh` and/or a `verify128.sh` script) so regressions are re-checkable.

## Validation plan

- After each milestone: `C:\Program Files\Git\bin\bash.exe compiler/src/test128/run.sh` (clean build → copy to `P:\ProjectSidero\dmd2\windows\bin\dmd.exe` → `-run test128/start.d` on m64, plus the m32 leg).
- `start.d` is the accumulating assertion suite (M1→M3 sections above; identical assertions on m64 and m32); verify full 128-bit values via comparisons of cent-typed expressions (backend word-compare) and via `cast(ulong)(x >> 64)` / `cast(ulong)x` decomposition where useful.
- `run.sh` additionally runs negative-compilation checks (expect-fail cases) — follow the `testsumtypematching/run.sh` structure.
- Regenerate `start.d.cg` (the `-vcg-ast` golden file) after intended `start.d` changes.
- M8 objdump/clang verification (above) after M2 lands and again after M3-M5 (literals/CTFE don't change codegen, but re-verify before finishing).

## Risks / audit checklist

- **REX.W omissions** in 16-byte paths silently produce wrong code — audit every `sz == 2*REGSIZE` path in the x86 backend (`cdorth`, `cdneg`, `cdcom`, `cdshift`, `cdshtlng`, `cddiv`, `loaddata`, `cdeq`, `fixresult`, `pushParams`, `movParams`).
- **m32 call convention**: 16-byte stack args (alignment 8), sret returns (`allocretregs` I32 path), m32 cast paths (`cdshtlng`/`cdlngsht`/`cdpair`) — all unverified today; M2/M8 cover them.
- **`evalu8.d OPmsw`** 16-byte-source bug (result-size-keyed switch) — fix before relying on signed `< 0` tests of cent (`elcmp` uses `OPmsw`).
- **`el_tolong`** truncation sites (`el.d`) — audit that 128-bit values only pass through via explicit `OP128_64`.
- `cgelem eldiv`/`el64_32`/`gdag` interplay with the new `OPremquo` 16÷8 codegen — verify the `OP128_64` peeling and the div/mod recovery path.
- **Hardcoded D-mangled names** for `core.int128` calls: if druntime's attribute set ever changes, calls fail at link time (loud) — acceptable; M8 probe step keeps them pinned.
- **CTFE subtlety**: `assignInPlace`/`paintTypeOntoLiteral` and `toInteger` write-backs — silent truncation is the main danger; prefer errors.
- **DFA** (`dfa/fast/structure.d`) models Tint128 as 64-bit — accepted approximation; note as limitation.
- `warn3882.d` auto-activating cent checks may surface semantic gaps early — treat failures as feature work, not regressions.
- `enum E : cent` base types and `switch`-on-cent case matching — audit `enumsem`/case folding.

## Out of scope

- ARM/AArch64 backend 16-byte arithmetic (asserts remain).
- `int128`/`uns128` as D type names (never; they stay internal enum names only).
- float/imaginary/complex ↔ cent conversions (semantic error).
- `std.format`/`writeln` of cent (phobos-side work), `std.math` support.
- Runtime `cent ^^ cent` with dynamic exponent (error until a helper exists).
- m32 inline hardware arithmetic (all m32 ops libcall'd via `core.int128` by design).
- Full `compiler/test` suite automation on Windows (manual smoke instead).
- C++ interop of cent (mangling 'zi' exists; ABI for C++ `__int128` differs — document, don't implement).
- Any druntime changes (none needed: `core.int128` has every needed op; `TypeInfo_zi/zk` and `stdint` aliases are already in place).

## Follow-up for the implementer

- Confirm understanding of each change set as it lands (per AGENTS.md); audit generated `start.d.cg` diffs before committing to them.
- Do not commit; leave changes in the working tree for review.
