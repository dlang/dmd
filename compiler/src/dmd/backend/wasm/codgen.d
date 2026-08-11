/**
 * WebAssembly code generator.
 *
 * Translates DMD's backend IR (elem expression trees hung off a block CFG) into
 * WebAssembly bytecode. Companion to blocks.d (control-flow structuring) and
 * obj.d (the module/section writer that drives and links the result).
 *
 * Two-phase compilation:
 *   Phase 1 runs per function during e2ir, from `WasmObj_func_term`: it
 *   snapshots the function's local symbol table (`globsym`) and eagerly assigns
 *   shadow-frame offsets (`wasm_assignShadowOffsets`). Offsets must be fixed
 *   here because a nested function's IR bakes in the enclosing frame offset of
 *   each captured variable before that enclosing function is code-generated.
 *   Phase 2 (`wasm_codgen2`) is deferred to `WasmObj_term`, once every function,
 *   import and type in the module is known, so function/type/table indices are
 *   stable — WASM encodes them as fixed-width LEBs that cannot grow after the fact.
 *
 * Value model — WASM is a stack machine:
 *   `genElem` walks an elem tree, leaves its result on the operand stack, and
 *   returns whether it pushed a value. Scalar locals/params live in WASM locals.
 *   Anything whose address is taken (structs, static arrays, captured variables,
 *   spilled C-variadic args, hidden sret buffers) lives in a *shadow stack* frame
 *   in linear memory: the prologue subtracts the frame size from the imported
 *   `__stack_pointer` global into a base local, the epilogue restores it. D
 *   slices and delegates are lowered to two i32s (ptr+length / funcptr+context),
 *   matching LDC's -O0 ABI.
 *
 * Function / type / table index system:
 *   Codegen never bakes a final index; every index is emitted as a padded LEB
 *   plus a relocation recorded against a Symbol*, so wasm-ld can renumber at
 *   link time. Direct calls emit R_WASM.FUNCTION_INDEX_LEB; `call_indirect`
 *   emits a type-section index (R_WASM.TYPE_INDEX_LEB) and the imported
 *   `__indirect_function_table` number (R_WASM.TABLE_NUMBER_LEB); taking a
 *   function's address emits a table slot (R_WASM.TABLE_INDEX_SLEB); data
 *   addresses, the stack-pointer global and EH tags are relocatable too
 *   (MEMORY_ADDR_LEB / GLOBAL_INDEX_LEB / TAG_INDEX_LEB).
 *
 * `WasmCG` is the per-function generator state: operand-stack reachability,
 * temporary locals, shadow-frame layout, pending relocations, and the
 * call-context stack consumed while walking OPparam argument trees.
 */

module dmd.backend.wasm.codgen;

import dmd.backend.debugprint;
import core.stdc.stdio : printf;

import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.el;
import dmd.backend.oper;
import dmd.backend.ty;
import dmd.backend.type;
import dmd.backend.symbol;
import dmd.backend.rtlsym : getRtlsym, RTLSYM;
import dmd.backend.wasm.enums;
import dmd.backend.wasm.simd;
import dmd.backend.wasm.util : writeuLEB128_5;
import dmd.backend.wasm.obj;
import dmd.backend.wasm.blocks;

import dmd.common.outbuffer;

nothrow:

/// Returns: WASM type for element `e`
WASM_TYPE wasmType(elem* e)
{
    return wasmType(tybasic(e.Ety));
}

/// Integer type holding a pointer. Only 32-bit supported now, refactor this to a variable for wasm64
enum WASM_PTR = WASM_I32;

/// Returns: WASM type for backend `ty`
WASM_TYPE wasmType(tym_t ty)
{
    switch (tybasic(ty))
    {
    case TYbool, TYchar, TYschar, TYuchar, TYchar8,
        TYchar16, TYshort, TYwchar_t, TYushort,
        TYenum, TYint, TYuint, TYdchar, TYlong, TYulong:
        return WASM_I32;

    case TYnptr, TYptr, TYnullptr, TYref, TYnref, TYsptr,
        TYcptr, TYf16ptr, TYfptr, TYhptr, TYvptr, TYfgPtr,
        TYsharePtr, TYimmutPtr:
        return WASM_PTR;

    case TYllong, TYullong, TYcent, TYucent:
        return WASM_I64;

    case TYfloat, TYifloat:
        return WASM_F32;

    case TYdouble, TYdouble_alias, TYidouble, TYreal, TYireal:
        return WASM_F64;

    case TYnoreturn:
        return WASM_I32;

    case TYfloat4, TYdouble2, TYschar16, TYuchar16, TYshort8,
        TYushort8, TYlong4, TYulong4, TYllong2, TYullong2:
        return WASM_TYPE.V128;

    // These are not passed by value
    case TYstruct:
    case TYarray:
        return WASM_PTR;

    default:
        debug { printf("ty = %s, tybasic = %d\n", tym_str(ty), tybasic(ty)); }
        assert(0);
    }
}

/// Generate a fresh artificial symbol for an anonymous temporary local of the
/// given WASM value type. The per-function `locals` table holds `Symbol*`; the
/// value type is recovered from the symbol's D type via `wasmType`. EXNREF has no
/// `tym_t`, so its symbol is flagged `SFLwasmexnref` and given a placeholder type.
///
/// Returns: the generated symbol
Symbol* newTempLocal(WASM_TYPE ty) nothrow
{
    tym_t tym;
    final switch (ty)
    {
        case WASM_TYPE.I32:    tym = TYint;    break;
        case WASM_TYPE.I64:    tym = TYllong;  break;
        case WASM_TYPE.F32:    tym = TYfloat;  break;
        case WASM_TYPE.F64:    tym = TYdouble; break;
        case WASM_TYPE.V128:   tym = TYuchar16; break;
        case WASM_TYPE.EXNREF: tym = TYvoid;   break;
    }
    auto s = symbol_generate(SC.auto_, type_fake(tym));
    if (ty == WASM_TYPE.EXNREF)
        s.Sflags |= SFLwasmexnref;
    return s;
}

/// Returns: the WASM value type declared for local `l` in the code section
WASM_TYPE localWasmType(Symbol* l) nothrow
{
    return (l.Sflags & SFLwasmexnref) ? WASM_TYPE.EXNREF : wasmType(l.ty);
}

/// Duplicated: also in dvarstats.d
bool isParameter(Symbol* s)
{
    const sc = s.Sclass;
    return sc == SC.parameter || sc == SC.regpar || sc == SC.fastpar || sc == SC.shadowreg;
}

/// Returns: true if `ty` represents a real value (i.e. NOT void or noreturn).
bool typeHasValue(tym_t ty)
{
    return tybasic(ty) != TYvoid && tybasic(ty) != TYnoreturn;
}

/// Per-call scope used during OPparam tree traversal. The genElem recursion
/// over OPparam consumes one arg per leaf, advancing `nextParam` along the
/// callee's declared param list. Args past the declared list are queued in
/// `varArgs` when the callee is C-variadic (spilled to the shadow frame
/// after the recursion completes).
struct CallCtx
{
    param_t[] remainingParams;  /// remaining declared params (empty when out of declared)
    uint skipCount;             /// number of ABI-prepended leaves (hidden ret ptr, ethis,
                                /// nested-link) consumed before remainingParams advances
    bool isCVariadic;           /// true when callee takes `...`
    elem*[] varArgs;            /// args collected for the variadic shadow-frame spill
}

/// An integer tagged for unsigned LEB128 encoding by the variadic `WasmCG.emit`
struct Uleb
{
    uint v;

    void emit(ref WasmCG cg, ref OutBuffer buf) nothrow
    {
        buf.writeuLEB128(v);
    }
}

/// An integer tagged for signed LEB128 encoding by the variadic `WasmCG.emit`
struct Sleb
{
    long v;

    void emit(ref WasmCG cg, ref OutBuffer buf) nothrow
    {
        buf.writesLEB128(v);
    }
}

/// An integer tagged for 5-byte padded unsigned LEB128 encoding by `WasmCG.emit`,
/// leaving room for wasm-ld to overwrite the value during relocation.
struct UlebPad
{
    uint v;

    void emit(ref WasmCG cg, ref OutBuffer buf) nothrow
    {
        buf.writeuLEB128_5(v);
    }
}

/// An operand that records a `WasmReloc` at the current code offset and then
/// writes `symIdx` as a 5-byte padded ULEB128 placeholder for wasm-ld to patch
/// at link time. Handled by the variadic `WasmCG.emit`; constructed via the
/// `*Reloc` helpers.
struct RelocOp
{
    ubyte type;          /// R_WASM relocation kind
    uint symIdx = 0;     /// index written as the padded operand
    Symbol* sym = null;  /// referenced symbol, or null
    uint addend = 0;     /// byte offset added to `sym`'s address (data relocs only)

    void emit(ref WasmCG cg, ref OutBuffer buf) nothrow
    {
        cg.relocs ~= WasmReloc(cast(uint) buf.length, type, symIdx, addend, sym);
        buf.writeuLEB128_5(symIdx);
    }
}

RelocOp callReloc(uint fidx, Symbol* sym) => RelocOp(R_WASM.FUNCTION_INDEX_LEB, fidx, sym);
RelocOp tableIndexReloc(uint fidx, Symbol* sym) => RelocOp(R_WASM.TABLE_INDEX_SLEB, fidx, sym);
RelocOp dataAddrReloc(uint addr, uint addend, Symbol* sym) => RelocOp(R_WASM.MEMORY_ADDR_LEB, addr, sym, addend);

/// Per-function code-generation state
struct WasmCG
{
    OutBuffer code; /// bytecode being emitted
    Symbol*[] locals; /// local variable table (params first); temporaries hold a shared type-marker symbol
    uint numParams; /// number of parameters (= first numParams locals)
    WasmReloc[] relocs; /// relocations recorded in this function's code body

    bool hasShadowFrame;

    /// True when the frame's decremented __stack_pointer is written back to the
    /// imported global (and restored by the epilogue). Only needed when a callee
    /// might observe the stack pointer, i.e. the function makes a call (a plain
    /// `call`, an alloca, or a variadic/sret scratch alloc — all of which appear
    /// as OPcall/OPucall). A call-free framed function keeps the base in a local
    /// and never touches the global, matching LDC's -O0 output.
    bool framePublished;

    uint shadowBaseLocal; /// WASM local index holding the shadow frame base address
    uint shadowFrameSize; /// total size in bytes of shadow frame
    Symbol*[] shadowEntries; /// per-symbol shadow frame offsets

    /// Read-only by-value POD struct parameters whose fields are addressed
    /// directly through the incoming pointer instead of a copied shadow-frame
    /// slot (see paramReadOnlyPod). Maps the parameter symbol to the WASM local
    /// holding the caller-supplied pointer. Consulted by emitSymBase/emitSymAddr
    /// ahead of the shadow-frame path.
    uint[Symbol*] byRefParamLocal;

    /// Function return: true when this function returns via a hidden pointer
    /// (struct/array/slice/delegate). Set during wasm_codgen2 init so retexp
    /// emission can pick the right local type for the saved return value.
    bool retByHiddenPtr;

    /// Whether the point after the last emitted instruction is reachable by
    /// fall-through. Cleared by unconditional branches/returns, restored when a
    /// block frame that was a branch target closes. Lets the function epilogue
    /// skip the trailing `unreachable` when the body can't fall off the end.
    bool reachable = true;

    /// Scope for an in-progress call.
    /// Leaves of the OPparam tree consult the top of the stack to decide how to
    /// emit themselves (split slice into two i32s, queue as variadic, plain emit).
    CallCtx[] callCtxStack;

    /// Set by the statement driver (via genElemDiscard) immediately before a
    /// top-level genElem whose result is thrown away. genElem captures and
    /// clears it on entry, so nested subexpressions never see it. Assignment
    /// operators consult it to skip re-pushing their result value, sparing the
    /// caller a spill-and-drop the way a discard-aware x86 retregs pass would.
    bool discardResult;

    /// Scratch i32 local parking a caught exception payload while the landing
    /// pad store rearranges the stack. Lazily allocated, shared per function.
    uint caughtTmp = uint.max;

    /// Per-try exnref locals holding the in-flight exception across a finally
    /// body, keyed by the try's flag symbol (s2ir visitTryFinally EH_WASM).
    uint[Symbol*] exnLocals;

nothrow:

    /// Returns: function type index for `x`
    /// (Routes module-level state through WasmCG so the global can eventually go away.)
    auto internType(WasmFuncType x) => wmod_internType(x);

    /// Record that this module references the exception tag (forwards to obj so
    /// the tag section/import is emitted). Routed through WasmCG for the seam.
    void noteTagUse() => wmod_noteTagUse();

    /// Allocate an anonymous temp local of the given WASM type
    ///
    /// Returns: index of allocated temp in `locals` array
    uint allocTemp(WASM_TYPE ty)
    {
        const uint result = cast(uint) locals.length;
        locals ~= newTempLocal(ty);
        return result;
    }

    /// Allocate or look up a local for a symbol
    ///
    /// Returns: its index
    uint localFor(Symbol* s)
    {
        foreach (size_t i, Symbol* l; locals)
            if (l == s)
                return cast(uint) i;

        const uint result = cast(uint) locals.length;
        locals ~= s;
        return result;
    }

    /// Returns: true if symbol `s` lives in the shadow frame.
    static bool inShadow(Symbol* s) { return (s.Sflags & SFLwasmshadow) != 0; }

    /// Register a symbol in the shadow frame (idempotent).
    void registerShadow(Symbol* s)
    {
        assert(s.Stype);
        const uint sz = cast(uint) type_size(s.Stype);

        if (inShadow(s))
        {
            const uint end = cast(uint) s.Soffset + sz;
            if (end > shadowFrameSize)
                shadowFrameSize = end;
            return;
        }

        const uint al = Symbol_Salignsize(*s);
        const uint off = (shadowFrameSize + al - 1) & ~(al - 1);
        s.Soffset = off;
        s.Sflags |= SFLwasmshadow;
        shadowEntries ~= s;
        shadowFrameSize = off + sz;
    }

    /// Emit a mixed sequence in one call: `ubyte` arguments are opcodes
    /// written verbatim, `elem*` arguments are code-generated via `genElem`,
    /// integers wrapped in `uleb`/`sleb`/`UlebPad` are LEB128-encoded immediates,
    /// `float`/`double` are written as their raw little-endian bytes, a
    /// `ubyte[16]` is written verbatim (a `v128.const` lane immediate), and a
    /// `RelocOp` records a relocation and writes its padded index operand.
    void emit(Args...)(Args args)
    {
        foreach (a; args)
        {
            static if (is(typeof(a) : elem*))
                genElem(this, a);
            else static if (__traits(hasMember, typeof(a), "emit"))
                a.emit(this, code);
            else static if (is(typeof(a) == float))
                code.write(&a, float.sizeof);
            else static if (is(typeof(a) == double))
                code.write(&a, double.sizeof);
            else static if (is(typeof(a) == ubyte[16]))
                code.write(&a[0], 16);
            else static if (is(typeof(a) : ubyte))
                code.writeByte(a);
            else
                static assert(0, "can't emit " ~ typeof(a).stringof); // emit(a);
        }
    }

    void emitDataAddr(Symbol* sym, uint addend)
    {
        emit(OP.I32_CONST, dataAddrReloc(cast(uint)(sym.Soffset + addend), addend, sym));
    }

    void emitDataBase(Symbol* sym)
    {
        emit(OP.I32_CONST, dataAddrReloc(cast(uint) sym.Soffset, 0, sym));
    }

    /// Returns: the exnref local of the try/finally identified by its flag symbol
    uint exnLocalFor(Symbol* s)
    {
        if (auto p = s in exnLocals)
            return *p;
        const uint idx = allocTemp(WASM_TYPE.EXNREF);
        exnLocals[s] = idx;
        return idx;
    }

    /// Reserve `size` bytes on the shadow stack, leaving the new (lower) frame
    /// base in `local`. When `publish` is true the new base is also written back
    /// to __stack_pointer (`local = (__stack_pointer -= size)`) so callees see
    /// the reserved region; when false only the local is set
    /// (`local = __stack_pointer - size`), leaving the global untouched.
    void emitFrameAlloc(uint size, uint local, bool publish = true)
    {
        emit(OP.GLOBAL_GET, RelocOp(R_WASM.GLOBAL_INDEX_LEB),
            OP.I32_CONST, Sleb(cast(int) size), OP.I32_SUB);
        if (publish)
        {
            emit(OP.LOCAL_TEE, Uleb(local), OP.GLOBAL_SET, RelocOp(R_WASM.GLOBAL_INDEX_LEB));
        }
        else
        {
            emit(OP.LOCAL_SET, Uleb(local));
        }
    }

    /// Release a shadow-stack region reserved at base `local`:
    /// `__stack_pointer = local + size`.
    void emitFrameFree(uint local, uint size)
    {
        emit(OP.LOCAL_GET, Uleb(local), OP.I32_CONST, Sleb(cast(int) size), OP.I32_ADD,
            OP.GLOBAL_SET, RelocOp(R_WASM.GLOBAL_INDEX_LEB));
    }
}

private struct MemOps
{
    OP loadOp;
    OP storeOp;
}

private MemOps memOpsFor(tym_t ty) @safe
{
    switch (tybasic(ty))
    {
    case TYllong, TYullong:
        return MemOps(OP.I64_LOAD, OP.I64_STORE);
    case TYfloat, TYifloat:
        return MemOps(OP.F32_LOAD, OP.F32_STORE);
    case TYdouble, TYdouble_alias, TYreal, TYireal:
        return MemOps(OP.F64_LOAD, OP.F64_STORE);
    case TYschar:
        return MemOps(OP.I32_LOAD8_S, OP.I32_STORE8);
    case TYchar, TYuchar, TYbool:
        return MemOps(OP.I32_LOAD8_U, OP.I32_STORE8);
    case TYshort:
        return MemOps(OP.I32_LOAD16_S, OP.I32_STORE16);
    case TYwchar_t, TYushort:
        return MemOps(OP.I32_LOAD16_U, OP.I32_STORE16);
    default:
        return MemOps(OP.I32_LOAD, OP.I32_STORE);
    }
}

private int canonicalI32Const(int v, tym_t ty)
{
    switch (tybasic(ty))
    {
    case TYbool, TYchar, TYuchar:
        return v & 0xFF;
    case TYschar:
        return cast(byte) v;
    case TYwchar_t, TYushort, TYchar16:
        return v & 0xFFFF;
    case TYshort:
        return cast(short) v;
    default:
        return v;
    }
}

private void emitLoad(ref WasmCG cg, tym_t ty, uint offset = 0)
{
    if (tyvector(tybasic(ty)))
        return cg.emit(OP.FD_PREFIX, Uleb(WASM_SIMD.V128_LOAD), Uleb(4), Uleb(offset));

    const m = memOpsFor(ty);
    cg.emit(m.loadOp, Uleb(naturalAlign(m.loadOp)), Uleb(offset));
}

private void emitStore(ref WasmCG cg, tym_t ty, uint offset = 0)
{
    if (tyvector(tybasic(ty)))
        return cg.emit(OP.FD_PREFIX, Uleb(WASM_SIMD.V128_STORE), Uleb(4), Uleb(offset));

    const m = memOpsFor(ty);
    cg.emit(m.storeOp, Uleb(naturalAlign(m.storeOp)), Uleb(offset));
}

/// Store the caught exception payload (i32 on the value stack) into the
/// try's jcatchvar shadow slot. Called by the block structurer right after
/// a catch landing frame's OP.END.
void emitCaughtStore(ref WasmCG cg, Symbol* jcatchvar)
{
    if (cg.caughtTmp == uint.max)
        cg.caughtTmp = cg.allocTemp(WASM_I32);
    cg.emit(OP.LOCAL_SET, Uleb(cg.caughtTmp));
    const bool ok = cg.emitSymAddr(jcatchvar, 0);
    assert(ok);
    cg.emit(OP.LOCAL_GET, Uleb(cg.caughtTmp));
    cg.emitStore(TYnptr);
}

private void emitCoerce(ref WasmCG cg, WASM_TYPE from, WASM_TYPE to)
{
    if (from == to)
        return;

    static int X(WASM_TYPE from, WASM_TYPE to) { return from << 8 | to; }

    // Float to int uses the saturating trunc_sat family: the
    // plain trunc opcodes trap on NaN/out-of-range input, whereas D expects
    // native-style truncation without trapping:
    //   double d = 1e300;
    //   int i = cast(int) d; // i32.trunc_f64_s => "wasm trap: integer overflow"

    switch (X(from, to))
    {
        case X(WASM_F32, WASM_F64): return cg.emit(OP.F64_PROMOTE_F32);
        case X(WASM_F32, WASM_I32): return cg.emit(OP.FC_PREFIX, Uleb(WASM_FC.I32_TRUNC_SAT_F32_S));
        case X(WASM_F32, WASM_I64): return cg.emit(OP.FC_PREFIX, Uleb(WASM_FC.I64_TRUNC_SAT_F32_S));
        case X(WASM_F64, WASM_F32): return cg.emit(OP.F32_DEMOTE_F64);
        case X(WASM_F64, WASM_I32): return cg.emit(OP.FC_PREFIX, Uleb(WASM_FC.I32_TRUNC_SAT_F64_S));
        case X(WASM_F64, WASM_I64): return cg.emit(OP.FC_PREFIX, Uleb(WASM_FC.I64_TRUNC_SAT_F64_S));
        case X(WASM_I32, WASM_F32): return cg.emit(OP.F32_CONVERT_I32_S);
        case X(WASM_I32, WASM_F64): return cg.emit(OP.F64_CONVERT_I32_S);
        case X(WASM_I32, WASM_I64): return cg.emit(OP.I64_EXTEND_I32_S);
        case X(WASM_I64, WASM_F32): return cg.emit(OP.I32_WRAP_I64, OP.F32_REINTERPRET_I32);
        case X(WASM_I64, WASM_F64): return cg.emit(OP.F64_CONVERT_I64_S);
        case X(WASM_I64, WASM_I32): return cg.emit(OP.I32_WRAP_I64);
        default: assert(0);
    }
}

/// Returns: true if a storage class indicates a global living in linear memory
private bool isDataSym(FL fl) @safe @nogc nothrow
{
    switch (fl)
    {
    case FL.data, FL.tlsdata, FL.udata, FL.extern_, FL.csdata, FL.datseg:
        return true;
    default:
        return false;
    }
}

/// Returns: true if a symbol's storage class means it needs a WASM local (not global mem).
private bool isLocalSym(Symbol* s)
{
    return !isDataSym(s.Sfl) && s.Sfl != FL.func;
}

private void scanShadow(elem* e, ref WasmCG cg)
{
    if (!e)
        return;
    const op = e.Eoper;
    if (OTleaf(op))
    {
        if (op == OPrelconst && e.Vsym && isLocalSym(e.Vsym))
            cg.registerShadow(e.Vsym);
        return;
    }
    if (OTunary(op))
    {
        if (op == OPaddr && e.E1 && e.E1.Eoper == OPvar && e.E1.Vsym && isLocalSym(e.E1.Vsym))
            cg.registerShadow(e.E1.Vsym);
        scanShadow(e.E1, cg);
        return;
    }
    scanShadow(e.E1, cg);
    scanShadow(e.E2, cg);
}

/// Push the linear-memory address of `s + off` on the value stack.
/// Handles globals (FL.data, .csdata, .tlsdata, .udata, .datseg, .extern_)
/// and shadow-frame locals uniformly.
/// Returns: true if `s` is addressable through linear memory. Functions
/// (FL.func) return false — their "address" is a table index, not a memory
/// address, so callers handle them separately.
bool emitSymAddr(ref WasmCG cg, Symbol* s, uint off)
{
    if (isDataSym(s.Sfl))
    {
        cg.emit(OP.I32_CONST, dataAddrReloc(cast(uint)(s.Soffset + off), off, s));
        return true;
    }
    uint memOff;
    if (!cg.emitSymBase(s, off, memOff))
        return false;
    if (memOff != 0)
        cg.emit(OP.I32_CONST, Sleb(cast(int) memOff), OP.I32_ADD);
    return true;
}

/// Split form of `emitSymAddr`: pushes only the base address and returns the
/// residual constant offset that the caller must fold into the memarg of a
/// following load/store. Used to match LDC's `i32.const sym; i32.load offset=N`
/// pattern instead of materializing the full address with `i32.add`.
bool emitSymBase(ref WasmCG cg, Symbol* s, uint off, out uint memOff)
{
    if (auto p = s in cg.byRefParamLocal)
    {
        cg.emit(OP.LOCAL_GET, Uleb(*p));
        memOff = off;
        return true;
    }
    if (isDataSym(s.Sfl))
    {
        cg.emitDataBase(s);
        memOff = off;
        return true;
    }
    if (cg.inShadow(s))
    {
        cg.emit(OP.LOCAL_GET, Uleb(cg.shadowBaseLocal));
        memOff = cast(uint) s.Soffset + off;
        return true;
    }
    return false;
}

/// Emit `<addr> ; load.ty` for the symbol value at `s + off`.
/// Returns: true on success.
bool emitSymLoad(ref WasmCG cg, Symbol* s, uint off, tym_t ty)
{
    uint memOff;
    if (!cg.emitSymBase(s, off, memOff))
        return false;
    cg.emitLoad(ty, memOff);
    return true;
}

/// Fold a trailing constant into a load/store memarg offset. If `addr` is
/// `base + const` (constant on either side, integer, non-negative, in u32
/// range), return `base` and set `memOff` to the constant so the caller can
/// push only the base and encode the offset in the following load/store — e.g.
/// `p.y` becomes `<base>; i32.load offset=4` instead of `<base>; i32.const 4;
/// i32.add; i32.load`. Otherwise return `addr` unchanged with `memOff = 0`.
private elem* splitConstOffset(elem* addr, out uint memOff)
{
    memOff = 0;
    if (!addr || addr.Eoper != OPadd)
        return addr;
    elem* c;
    elem* base;
    if (addr.E2 && addr.E2.Eoper == OPconst)
    {
        c = addr.E2;
        base = addr.E1;
    }
    else if (addr.E1 && addr.E1.Eoper == OPconst)
    {
        c = addr.E1;
        base = addr.E2;
    }
    else
        return addr;
    const wt = c.wasmType;
    if (wt != WASM_I32 && wt != WASM_I64)
        return addr;
    const long v = (wt == WASM_I64) ? c.Vllong : cast(long) c.Vlong;
    if (v < 0 || v > uint.max)
        return addr;
    memOff = cast(uint) v;
    return base;
}

/// Push the linear-memory address of an lvalue elem on the value stack.
/// Handles OPvar (memory-backed via emitSymAddr) and OPind (recurse on E1).
/// Returns: true on success. False means the lvalue has no memory address
/// (e.g. an OPvar referring to a WASM local), and callers must fall back.
bool emitLValueAddr(ref WasmCG cg, elem* e)
{
    if (!e)
        return false;
    switch (e.Eoper)
    {
    case OPvar:
        return e.Vsym && cg.emitSymAddr(e.Vsym, cast(uint) e.Voffset);
    case OPind:
        cg.genElem(e.E1);
        return true;
    default:
        return false;
    }
}

/// Split form of `emitLValueAddr`: pushes only the base address and returns
/// the residual constant offset for the caller to fold into the memarg of the
/// following load/store.
bool emitLValueBase(ref WasmCG cg, elem* e, out uint memOff)
{
    if (!e)
        return false;
    switch (e.Eoper)
    {
    case OPvar:
        return e.Vsym && cg.emitSymBase(e.Vsym, cast(uint) e.Voffset, memOff);
    case OPind:
        cg.genElem(splitConstOffset(e.E1, memOff));
        return true;
    default:
        return false;
    }
}

/// A captured lvalue address that can be re-pushed onto the value stack
/// multiple times. For OPvar the address is re-emitted from the symbol
/// (cheap and side-effect free); for OPind the address expression is
/// evaluated once and stashed in an i32 temp.
struct SavedLValue
{
    Symbol* directSym;  /// OPvar: the symbol; null otherwise
    uint directOff;     /// OPvar: byte offset
    uint addrTemp;      /// non-OPvar: temp i32 local index holding the addr
    uint memOff;        /// non-OPvar: constant offset folded out of `base + const`
}

/// Evaluate `e`'s address-producing subexpressions once and return a
/// SavedLValue that can be replayed any number of times via `replayAddr`.
SavedLValue saveLValueAddr(ref WasmCG cg, elem* e)
{
    SavedLValue r;
    if (e.Eoper == OPvar && e.Vsym)
    {
        r.directSym = e.Vsym;
        r.directOff = cast(uint) e.Voffset;
        return r;
    }
    if (e.Eoper == OPind)
        cg.genElem(splitConstOffset(e.E1, r.memOff));
    else
    {
        const bool ok = cg.emitLValueAddr(e);
        assert(ok);
    }
    r.addrTemp = cg.allocTemp(WASM_I32);
    cg.emit(OP.LOCAL_SET, Uleb(r.addrTemp));
    return r;
}

/// Re-push the saved lvalue address onto the value stack.
/// Returns the constant offset the caller must pass to the following
/// load/store as the memarg offset (so `sym + Soffset` can be split into
/// `local.get base; i32.load offset=Soffset` etc.).
uint replayAddr(ref WasmCG cg, SavedLValue r)
{
    if (r.directSym)
    {
        uint memOff;
        const bool ok = cg.emitSymBase(r.directSym, r.directOff, memOff);
        assert(ok);
        return memOff;
    }
    cg.emit(OP.LOCAL_GET, Uleb(r.addrTemp));
    return r.memOff;
}

/// True if any elem in `e`'s tree reads the shadow-frame base beyond ordinary
/// frame-resident symbols: an explicit OPframeptr (nested-function context
/// pointer, va_start, or alloca base), or an `alloca` call whose bumped
/// __stack_pointer the epilogue must restore.
private bool elemNeedsFrameBase(elem* e)
{
    if (!e)
        return false;
    const op = e.Eoper;
    if (op == OPframeptr)
        return true;
    // A captured POD-struct param needs its spilled frame slot, so `&param`
    // must not collapse to the incoming pointer:
    //   struct S { double v; }
    //   struct B { double got; this(T)(T p) { double f() { return p.v; } got = f(); } }
    //   // p is read only inside f(): without the frame slot the nested read sees 0
    if (op == OPrelconst && e.Vsym &&
        (e.Vsym.Sclass == SC.parameter || e.Vsym.Sclass == SC.regpar ||
         e.Vsym.Sclass == SC.fastpar   || e.Vsym.Sclass == SC.shadowreg ||
         e.Vsym.Sclass == SC.auto_     || e.Vsym.Sclass == SC.register ||
         e.Vsym.Sclass == SC.stack))
        return true;
    if (OTleaf(op))
        return false;
    if (op == OPcall && e.E1 && e.E1.Eoper == OPvar && e.E1.Vsym)
    {
        import core.stdc.string : strcmp;
        if (strcmp(&e.E1.Vsym.Sident[0], "alloca") == 0)
            return true;
    }
    if (OTunary(op))
        return elemNeedsFrameBase(e.E1);
    return elemNeedsFrameBase(e.E1) || elemNeedsFrameBase(e.E2);
}

/// Scan every block of a function for an elem that reads the shadow-frame base
/// (see elemNeedsFrameBase). Used to decide whether a zero-size-frame function
/// can omit its prologue/epilogue entirely.
private bool funcNeedsFrameBase(block* startblock)
{
    for (block* b = startblock; b; b = b.Bnext)
        if (elemNeedsFrameBase(b.Belem))
            return true;
    return false;
}

/// True if `e`'s tree contains a call (OPcall/OPucall). Every wasm construct
/// that reads or mutates __stack_pointer mid-body — a plain call, an alloca, and
/// the variadic/sret scratch-frame allocs — is emitted from an OPcall/OPucall,
/// so a call-free function never touches the global stack pointer after entry.
private bool elemMakesCall(elem* e)
{
    if (!e)
        return false;
    const op = e.Eoper;
    if (op == OPcall || op == OPucall)
        return true;
    // These opers lower to a synthetic libm call (see genElem/emitBinop): the
    // callee reads __stack_pointer to build its own frame, so the enclosing
    // function must publish its decremented stack pointer like any other caller.
    switch (op)
    {
    case OPsin, OPcos, OPrint, OPrndtol, OPscale:
        return true;
    case OPmod, OPmodass:
        if (tyfloating(tybasic(e.Ety)) || (e.E1 && tyfloating(tybasic(e.E1.Ety))))
            return true;
        break;
    default:
        break;
    }
    if (OTleaf(op))
        return false;
    if (OTunary(op))
        return elemMakesCall(e.E1);
    return elemMakesCall(e.E1) || elemMakesCall(e.E2);
}

/// Scan every block of a function for a call. Used to decide whether a framed
/// function must publish its decremented __stack_pointer to the imported global
/// (and restore it) or can keep the frame base in a local only.
private bool funcMakesCall(block* startblock)
{
    for (block* b = startblock; b; b = b.Bnext)
        if (elemMakesCall(b.Belem))
            return true;
    return false;
}

/// True if `e`'s tree uses the by-value POD struct parameter `s` in a way that
/// requires it to own private, stable storage (a copied shadow-frame slot):
///  - its address is taken (OPrelconst: a `ref` pass, `&p`, or indirect write),
///  - it is used as a whole-struct value (OPvar of struct type: `return p`,
///    `q = p`, or an onward by-value pass `g(p)` that re-hands the pointer to
///    another callee — conservatively treated as unsafe), or
///  - it is written (any OTassign whose destination is the parameter itself,
///    covering `p = …`, `p.field = …`, `p.field op= …`, `p.field++`).
/// When none of these appear the parameter is read-only and its fields can be
/// loaded directly through the caller-supplied pointer.
private bool elemViolatesReadOnly(elem* e, Symbol* s)
{
    if (!e)
        return false;
    const op = e.Eoper;
    if (op == OPrelconst && e.Vsym is s)
        return true;
    if (op == OPvar && e.Vsym is s && tybasic(e.Ety) == TYstruct)
        return true;
    if (OTassign(op) && e.E1 && e.E1.Eoper == OPvar && e.E1.Vsym is s)
        return true;
    if (OTleaf(op))
        return false;
    if (OTunary(op))
        return elemViolatesReadOnly(e.E1, s);
    return elemViolatesReadOnly(e.E1, s) || elemViolatesReadOnly(e.E2, s);
}

/// True if the by-value POD struct parameter `s` is only ever read, so the
/// callee can address its fields through the incoming pointer rather than
/// copying the struct into a shadow-frame slot (matching LDC's -O0 output).
/// The caller gates this on the function having no nested-function context
/// (no OPframeptr), which is the one way `s` could be read at a frame offset
/// without an explicit reference in these block trees.
private bool paramReadOnlyPod(Symbol* s, block* startblock)
{
    for (block* b = startblock; b; b = b.Bnext)
        if (elemViolatesReadOnly(b.Belem, s))
            return false;
    return true;
}

/// Emit shadow stack frame prologue (called once at function entry).
/// Creates the shadow base local, gets __stack_pointer, subtracts frame size, stores back.
void emitShadowPrologue(ref WasmCG cg)
{
    cg.shadowBaseLocal = cg.allocTemp(WASM_I32);
    const uint fsz = (cg.shadowFrameSize + 15) & ~15u;

    cg.emitFrameAlloc(fsz, cg.shadowBaseLocal, cg.framePublished);
}

/// Emit shadow stack frame epilogue (restore __stack_pointer).
void emitShadowEpilogue(ref WasmCG cg)
{
    const uint fsz = (cg.shadowFrameSize + 15) & ~15u;

    cg.emitFrameFree(cg.shadowBaseLocal, fsz);
}

/// Truncate the result of a small integer operation back to the canonical
/// i32 form of `ty` (signed → sign-extended, unsigned → zero-extended,
/// matching memOpsFor loads), since WASM operations are at least 32-bit.
/// ---
/// char toUpper(char c) => (c >= 'a' && c <= 'z') ? cast(char)(c + ('A' - 'a')) : c;
/// // i32.add leaves bit 8 set for 'r'; a switch on the result then misses every case
/// ---
private void maskSmallInt(ref WasmCG cg, tym_t ty)
{
    if (tyfloating(ty))
        return;
    if (tyuns(ty))
        return zeroExtendSmallInt(cg, ty);
    switch (tysize(ty))
    {
    case 1:
        cg.emit(OP.I32_EXTEND8_S);
        break;
    case 2:
        cg.emit(OP.I32_EXTEND16_S);
        break;
    default:
        break;
    }
}

/// Zero-extend a small integer on the stack regardless of its type's sign
/// (for logical right shifts, where the sign-extended canonical form of a
/// signed operand would shift garbage bits in).
private void zeroExtendSmallInt(ref WasmCG cg, tym_t ty)
{
    switch (tysize(ty))
    {
    case 1:
        cg.emit(OP.I32_CONST, Sleb(0xFF), OP.I32_AND);
        break;
    case 2:
        cg.emit(OP.I32_CONST, Sleb(0xFFFF), OP.I32_AND);
        break;
    default:
        break;
    }
}

/// Prepare the left operand of a logical right shift (`OPshr`/`OPshrass`). A
/// signed sub-word operand is held in sign-extended canonical form (emitLoad,
/// prior arithmetic), whose high bits would shift down into the result; force
/// zero-extension. Unsigned operands are already zero-extended, and wider types
/// no-op inside zeroExtendSmallInt.
private void zeroExtendForLogicalShift(ref WasmCG cg, tym_t ty)
{
    if (!tyuns(ty))
        cg.zeroExtendSmallInt(ty);
}

private void genVarArgs(ref WasmCG cg, elem*[] varArgs, ref uint spLocal, ref uint vaFrameSize)
{
    vaFrameSize = 0;

    if (varArgs.length == 0)
    {
        cg.emit(OP.I32_CONST, Sleb(0));
        return;
    }

    enum VaKind
    {
        scalar,
        slicePair,
        aggregate
    }

    struct VaSlot
    {
        elem* e;
        uint off;
        VaKind kind;
        OP storeOp;
        uint alignLog2;
        bool promoteF32;
        uint byteSize;
    }

    VaSlot[] slots;
    uint offset = 0;
    foreach (va; varArgs)
    {
        VaKind kind = VaKind.scalar;
        OP storeOp;
        uint sz, al;
        bool promF32 = false;

        if (va.Eoper == OPparam)
        {
            kind = VaKind.slicePair;
            sz = 8;
            al = 2;
        }
        else if (va.Eoper == OPstrpar)
        {
            kind = VaKind.aggregate;
            type* st = va.ET;
            sz = st ? cast(uint) type_size(st) : 0;
            sz = (sz + 3) & ~3;
            const uint aln = st ? type_alignsize(st) : 4;
            al = aln >= 8 ? 3 : 2;
        }
        else switch (tybasic(va.Ety).wasmType)
        {
        case WASM_I64:
            storeOp = OP.I64_STORE;
            sz = 8;
            al = 3;
            break;
        case WASM_F64:
            storeOp = OP.F64_STORE;
            sz = 8;
            al = 3;
            break;
        case WASM_F32:
            storeOp = OP.F64_STORE;
            sz = 8;
            al = 3;
            promF32 = true;
            break;
        case WASM_I32:
            storeOp = OP.I32_STORE;
            sz = 4;
            al = 2;
            break;
        default:
            assert(0);
        }
        uint byteAlign = 1u << al;
        offset = (offset + byteAlign - 1) & ~(byteAlign - 1);
        slots ~= VaSlot(va, offset, kind, storeOp, al, promF32, sz);
        offset += sz;
    }
    vaFrameSize = (offset + 15) & ~15;

    spLocal = cg.allocTemp(WASM_I32);
    cg.emitFrameAlloc(vaFrameSize, spLocal);

    foreach (ref sl; slots)
    {
        final switch (sl.kind)
        {
        case VaKind.scalar:
            cg.emit(OP.LOCAL_GET, Uleb(spLocal), sl.e);
            if (sl.promoteF32)
                cg.emit(OP.F64_PROMOTE_F32);
            cg.emit(sl.storeOp, Uleb(sl.alignLog2), Uleb(sl.off));
            break;

        case VaKind.slicePair:
            cg.emit(OP.LOCAL_GET, Uleb(spLocal), sl.e.E2, OP.I32_STORE, Uleb(2), Uleb(sl.off));
            cg.emit(OP.LOCAL_GET, Uleb(spLocal), sl.e.E1, OP.I32_STORE, Uleb(2), Uleb(sl.off + 4));
            break;

        case VaKind.aggregate:
            if (sl.byteSize)
            {
                cg.emit(OP.LOCAL_GET, Uleb(spLocal));
                if (sl.off)
                    cg.emit(OP.I32_CONST, Sleb(sl.off), OP.I32_ADD);
                cg.emit(sl.e, OP.I32_CONST, Sleb(sl.byteSize));
                cg.emit(OP.FC_PREFIX, Uleb(WASM_FC.MEMORY_COPY), Uleb(0), Uleb(0));
            }
            break;
        }
    }

    cg.emit(OP.LOCAL_GET, Uleb(spLocal));
}

private elem* unwrapComma(ref WasmCG cg, elem* e)
{
    while (e && e.Eoper == OPcomma)
    {
        cg.genElemDiscard(e.E1);
        e = e.E2;
    }
    return e;
}

private bool emitSliceHalf(ref WasmCG cg, elem* e, bool ptrHalf)
{
    if (!e)
        return false;
    const uint half = ptrHalf ? 4u : 0u;
    uint memOff;
    if (e.Eoper == OPrelconst && e.Vsym &&
        cg.emitSymBase(e.Vsym, cast(uint) e.Voffset + half, memOff))
    {
        cg.emit(OP.I32_LOAD, Uleb(2), Uleb(memOff));
        return true;
    }
    const tym_t ety = tybasic(e.Ety);
    if (ety != TYdarray && ety != TYdelegate)
        return false;
    if (e.Eoper == OPvar && e.Vsym &&
        cg.emitSymBase(e.Vsym, cast(uint) e.Voffset + half, memOff))
    {
        cg.emit(OP.I32_LOAD, Uleb(2), Uleb(memOff));
        return true;
    }
    if (e.Eoper == OPind && e.E1)
    {
        cg.emit(e.E1, OP.I32_LOAD, Uleb(2), Uleb(half));
        return true;
    }
    return false;
}

private bool paramIsSlice(const(param_t)* p)
{
    if (!p || !p.Ptype)
        return false;
    return isSliceOrDelegate(cast(type*) p.Ptype);
}

private void emitSliceArg(ref WasmCG cg, elem* arg)
{
    elem* a = unwrapComma(cg, arg);
    if (a.Eoper == OPconst)
    {
        cg.emit(OP.I32_CONST, Sleb(0), OP.I32_CONST, Sleb(0));
        return;
    }
    if (a.Eoper == OPpair)
    {
        cg.emit(a.E1, a.E2);
        return;
    }
    if (a.Eoper == OPrpair)
    {
        cg.emit(a.E2, a.E1);
        return;
    }
    if (a.Eoper == OPparam)
    {
        cg.emit(a.E2, a.E1);
        return;
    }
    if (a.Eoper == OPind && a.E1 &&
        (tybasic(a.Ety) == TYdarray || tybasic(a.Ety) == TYdelegate))
    {
        cg.genElem(a.E1);
        loadSliceHalves(cg);
        return;
    }

    if (cg.emitSliceHalf(a, /*ptrHalf*/ false) &&
        cg.emitSliceHalf(a, /*ptrHalf*/ true))
        return;

    if (a.Eoper == OPcond)
    {
        cg.genElem(a.E1);
        cg.emitCondToI32(a.E1);
        const uint lenTmp = cg.allocTemp(WASM_I32);
        const uint ptrTmp = cg.allocTemp(WASM_I32);
        void emitArm(elem* arm)
        {
            cg.emitSliceArg(arm);
            cg.emit(OP.LOCAL_SET, Uleb(ptrTmp), OP.LOCAL_SET, Uleb(lenTmp));
        }
        cg.emit(OP.IF, WASM_VOID_BLOCK);
        emitArm(a.E2.E1);
        cg.emit(OP.ELSE);
        emitArm(a.E2.E2);
        cg.emit(OP.END, OP.LOCAL_GET, Uleb(lenTmp), OP.LOCAL_GET, Uleb(ptrTmp));
        return;
    }

    elem_print(arg);
    assert(0);
}

private bool emitStructParAddr(ref WasmCG cg, elem* e)
{
    e = unwrapComma(cg, e);
    if (e.Eoper == OPcond)
    {
        cg.genElem(e.E1);
        cg.emitCondToI32(e.E1);
        const uint addrTmp = cg.allocTemp(WASM_I32);
        cg.emit(OP.IF, WASM_VOID_BLOCK);
        if (!cg.emitStructParAddr(e.E2.E1))
            return false;
        cg.emit(OP.LOCAL_SET, Uleb(addrTmp), OP.ELSE);
        if (!cg.emitStructParAddr(e.E2.E2))
            return false;
        cg.emit(OP.LOCAL_SET, Uleb(addrTmp), OP.END, OP.LOCAL_GET, Uleb(addrTmp));
        return true;
    }
    // A struct rvalue arrives as `strpar(streq(_TMP, value))`: emitting the
    // streq performs the copy and leaves the temp's address on the stack.
    // Example: `f(S.init)` for a by-value struct parameter (structlit_rvalue.d).
    if (e.Eoper == OPstreq)
        return cg.genElem(e);
    if (e.Eoper == OPeq && e.E1)
    {
        if (cg.genElem(e))
            cg.emit(OP.DROP);
        return cg.emitLValueAddr(e.E1);
    }
    return cg.emitLValueAddr(e);
}

private void loadSliceHalves(ref WasmCG cg)
{
    const uint addrTmp = cg.allocTemp(WASM_I32);
    cg.emit(OP.LOCAL_TEE, Uleb(addrTmp), OP.I32_LOAD, Uleb(2), Uleb(0));
    cg.emit(OP.LOCAL_GET, Uleb(addrTmp), OP.I32_LOAD, Uleb(2), Uleb(4));
}

private bool isParamSpine(const(elem)* e)
{
    return e && e.Eoper == OPparam && tybasic(e.Ety) == TYvoid;
}

private size_t countParamLeaves(elem* e)
{
    if (!e)
        return 0;
    if (isParamSpine(e))
        return countParamLeaves(e.E1) + countParamLeaves(e.E2);
    return 1;
}

private void consumeCallArg(ref WasmCG cg, elem* e)
{
    if (!e)
        return;
    if (isParamSpine(e))
    {
        cg.emit(e);
        return;
    }
    CallCtx* ctx = &cg.callCtxStack[$ - 1];
    if (ctx.skipCount > 0)
    {
        ctx.skipCount--;
        cg.emit(e);
        return;
    }
    if (ctx.remainingParams.length > 0)
    {
        param_t* p = &ctx.remainingParams[0];
        ctx.remainingParams = ctx.remainingParams[1 .. $];
        if (paramIsSlice(p))
        {
            cg.emitSliceArg(e);
            return;
        }
    }
    else if (ctx.isCVariadic)
    {
        ctx.varArgs ~= e;
        return;
    }
    cg.emit(e);
}

/// Recover the function type of a call's callee. Prefers the callee symbol's
/// type, then the type attached to `e.E1`, then an indirect call through a
/// function-pointer variable. Returns null if none applies.
private type* resolveFuncType(elem* e, Symbol* calleeSym)
{
    if (calleeSym && calleeSym.Stype)
        return calleeSym.Stype;

    if (e.E1.ET && tyfunc(e.E1.ET.Tty))
        return e.E1.ET;

    // Resolve indirect calls (int function(int) fp = &foo)
    elem* fe = e.E1;
    if (fe && fe.Eoper == OPind && fe.E1)
        fe = fe.E1;
    Symbol* fsym = (fe && (fe.Eoper == OPvar || fe.Eoper == OPrelconst)) ? fe.Vsym : null;
    if (fsym && fsym.Stype)
    {
        type* st = fsym.Stype;
        if (st.Tnext && tyfunc(st.Tnext.Tty))
            return st.Tnext;
        if (tyfunc(st.Tty))
            return st;
    }
    return null;
}

private bool genCall(ref WasmCG cg, elem* e)
{
    Symbol* calleeSym = e.E1.Vsym;

    // yeah... this is how the backend checks for alloca
    if (calleeSym && e.E1.Eoper == OPvar && e.E2 && e.E2.Eoper != OPparam &&
        calleeSym.identifier == "alloca")
        return cg.genAlloca(e);

    type* fty = resolveFuncType(e, calleeSym);

    CallCtx ctx;
    ctx.remainingParams = (fty && fty.Tparamtypes) ? *fty.Tparamtypes : null;
    ctx.isCVariadic = fty !is null && variadic(fty) &&
        (fty.Tparamtypes !is null || dstyleVariadic(fty));

    if (!ctx.isCVariadic)
    {
        const size_t leaves = countParamLeaves(e.E2);
        if (leaves > ctx.remainingParams.length)
            ctx.skipCount = cast(int)(leaves - ctx.remainingParams.length);
    }
    else
    {
        if (fty && fty.Tnext && returnByPtr(fty.Tnext))
            ctx.skipCount++;
        if (calleeSym && calleeSym.Sfunc &&
            (calleeSym.Sfunc.Fflags & (Fmember | Fnested)))
            ctx.skipCount++;
        else if (!calleeSym && e.numParams)
            ctx.skipCount += e.numParams - 1;
        if (fty && dstyleVariadic(fty))
            ctx.skipCount++;
    }

    // An rtlsym slice return (e.g. _d_arraycopy) has no ehidden arg — the native
    // ABI returns slices in a register pair — but the WASM signature has a hidden
    // sret pointer first; when no hidden leaf was supplied, bump the stack pointer
    // for a scratch buffer and pass its address, restoring afterwards:
    //   struct S { this(inout ref S) inout {} ~this() {} }
    //   struct T { S[3] ss; this(int) { ss[] = makeStaticArray(); } }
    const bool retByPtrCall = fty && fty.Tnext && returnByPtr(fty.Tnext);
    uint sretLocal = uint.max;
    uint sretSize;
    if (retByPtrCall && !ctx.isCVariadic && ctx.skipCount == 0)
    {
        sretSize = cast(uint)((type_size(fty.Tnext) + 15) & ~15);
        sretLocal = cg.allocTemp(WASM_I32);
        cg.emitFrameAlloc(sretSize, sretLocal);
        cg.emit(OP.LOCAL_GET, Uleb(sretLocal));
    }

    cg.callCtxStack ~= ctx;
    consumeCallArg(cg, e.E2);
    elem*[] varArgs = cg.callCtxStack[$ - 1].varArgs;
    cg.callCtxStack.length--;

    uint spLocal;
    uint vaFrameSize;
    if (ctx.isCVariadic)
        cg.genVarArgs(varArgs, spLocal, vaFrameSize);

    if (calleeSym)
    {
        cg.emit(OP.CALL, callReloc(cg.funcIndex(calleeSym), calleeSym));
    }
    else
    {
        uint typeIdx;
        assert(fty);

        const uint nonLeading = (retByPtrCall ? 1 : 0) + (dstyleVariadic(fty) ? 1 : 0);
        const uint hiddenLeading = ctx.skipCount > nonLeading
            ? ctx.skipCount - nonLeading : 0;
        typeIdx = cg.internType(buildFuncType(fty, null, hiddenLeading));

        elem* fn = (e.E1.Eoper == OPind && e.E1.E1) ? e.E1.E1 : e.E1;
        cg.emit(fn, OP.CALL_INDIRECT,
            RelocOp(R_WASM.TYPE_INDEX_LEB, typeIdx, null), RelocOp(R_WASM.TABLE_NUMBER_LEB));
    }

    if (sretLocal != uint.max)
    {
        cg.emitFrameFree(sretLocal, sretSize);
        cg.emit(OP.LOCAL_GET, Uleb(sretLocal));
    }

    if (ctx.isCVariadic && varArgs.length)
        cg.emitFrameFree(spLocal, vaFrameSize);

    // Noreturn call: leave a polymorphic stack. The optimizer folds
    // `assert(false)` to OPne(call, 0), whose relop needs the call's value even
    // though the callee's signature is void: `unittest { assert(false); }`.
    if ((calleeSym && (calleeSym.Sflags & SFLexit)) || tybasic(e.Ety) == TYnoreturn)
        cg.emit(OP.UNREACHABLE);

    if (sretLocal != uint.max)
        return true;

    // Report what the callee's signature actually left on the stack — e.Ety can
    // disagree (a `ref void` return is a pointer to the frontend but no WASM
    // result), and a defining symbol may differ from a redeclaration:
    //   struct S { this(ref inout typeof(this)) {} ref opAssign(typeof(this)) {} }
    //   void emplace(S chunk, S args) { chunk = args; } // drop after resultless call
    if (calleeSym)
    {
        if (Symbol* def = definedFuncByName(calleeSym))
            if (def.Stype && tyfunc(def.Stype.Tty))
                return buildFuncType(def.Stype, def).results.length != 0;
    }
    if (fty)
        return buildFuncType(fty, calleeSym).results.length != 0;
    return typeHasValue(e.Ety);
}

private bool genAlloca(ref WasmCG cg, elem* e)
{
    const uint tmp = cg.allocTemp(WASM_I32);
    cg.emit(OP.GLOBAL_GET, RelocOp(R_WASM.GLOBAL_INDEX_LEB));
    cg.genElem(e.E2, WASM_I32);
    cg.emit(
        OP.I32_SUB, OP.I32_CONST, Sleb(~15), OP.I32_AND,
        OP.LOCAL_TEE, Uleb(tmp),
        OP.GLOBAL_SET, RelocOp(R_WASM.GLOBAL_INDEX_LEB),
        OP.LOCAL_GET, Uleb(tmp));
    return true;
}

/// Code generation for an element
/// Returns: true if the expression has a result on the stack after genElem
bool genElem(ref WasmCG cg, elem* e, WASM_TYPE type)
{
    const result = cg.genElem(e);
    if (result && typeHasValue(e.Ety))
        cg.emitCoerce(wasmType(e.Ety), type);
    return result;
}

/// Evaluate `e` at statement level for its side effects, discarding any result.
/// Assignment/increment operators use the discard flag to avoid materializing
/// their result; anything else that still leaves a value on the stack is dropped.
/// Returns: true if a value was produced (and dropped).
bool genElemDiscard(ref WasmCG cg, elem* e)
{
    if (!el_sideeffect(e))
        return false;
    cg.discardResult = true;
    const v = cg.genElem(e);
    cg.discardResult = false;
    if (v)
        cg.emit(OP.DROP);
    return v;
}

bool genElem(ref WasmCG cg, elem* e)
{
    if (!e)
        return false;

    const op = e.Eoper;
    const discard = cg.discardResult;
    cg.discardResult = false;

    bool unaryOp(OP op)
    {
        cg.emit(e.E1, op);
        return true;
    }

    bool truncSat(WASM_FC subop)
    {
        cg.emit(e.E1, OP.FC_PREFIX, Uleb(subop));
        return true;
    }

    bool libmCall(RTLSYM f32Sym, RTLSYM f64Sym)
    {
        cg.genElem(e.E1);
        Symbol* fn;
        final switch (e.E1.wasmType)
        {
        case WASM_F32: fn = getRtlsym(f32Sym); break;
        case WASM_F64: fn = getRtlsym(f64Sym); break;
        case WASM_I32:
        case WASM_I64:
        case WASM_TYPE.V128:
        case WASM_TYPE.EXNREF:
            assert(0);
        }
        cg.emit(OP.CALL, callReloc(cg.funcIndex(fn), fn));
        return true;
    }

    switch (op)
    {
    case OPcall:
    case OPucall:
        return cg.genCall(e);

    case OPmemgrow:
        cg.emit(e.E1, OP.MEMORY_GROW, Uleb(0));
        return true;

    case OPmemsize:
        cg.emit(OP.MEMORY_SIZE, Uleb(0));
        return true;

    case OPthrow:
        cg.noteTagUse();
        cg.genElem(e.E1, WASM_I32);
        cg.emit(OP.THROW, RelocOp(R_WASM.TAG_INDEX_LEB));
        return false;

    case OPrethrow:
        cg.emit(OP.LOCAL_GET, Uleb(cg.exnLocalFor(e.Vsym)), OP.THROW_REF);
        return false;

    case OPparam:
        consumeCallArg(cg, e.E2);
        consumeCallArg(cg, e.E1);
        return false;

    case OPconst:
        if (tybasic(e.Ety) == TYvoid)
            return false;
        switch (e.wasmType)
        {
        case WASM_I64:
            cg.emit(OP.I64_CONST, Sleb(e.Vllong));
            break;
        case WASM_F32:
            cg.emit(OP.F32_CONST, e.Vfloat);
            break;
        case WASM_F64:
            const tbF64 = tybasic(e.Ety);
            cg.emit(OP.F64_CONST, (tbF64 == TYreal || tbF64 == TYireal) ? cast(double) e.Vreal : e.Vdouble);
            break;
        case WASM_I32:
            // A sub-word constant must use its type's canonical i32 extension
            // (see memOpsFor), else e.g. `cast(ushort)s == 0xCCCC` mismatches a
            // zero-extended i32.load16_u against a sign-extended literal
            // (test15.d test39).
            cg.emit(OP.I32_CONST, Sleb(canonicalI32Const(cast(int) e.Vlong, e.Ety)));
            break;
        case WASM_TYPE.V128:
            cg.emit(OP.FD_PREFIX, Uleb(WASM_SIMD.V128_CONST), e.Vuchar16);
            break;
        default:
            assert(0);
        }
        return true;

    case OPvar:
        if (cg.emitSymLoad(e.Vsym, cast(uint) e.Voffset, e.Ety))
            return true;

        if (e.Vsym.Sfl == FL.func)
        {
            cg.emit(OP.I32_CONST, tableIndexReloc(cg.funcIndex(e.Vsym), e.Vsym));
            cg.emitLoad(e.Ety, cast(uint) e.Voffset);
            return true;
        }

        printf("wasm codegen OPvar symbol neither data nor shadow: %s\n", &e.Vsym.Sident[0]);
        elem_print(e);
        assert(0);

    case OPrelconst:
        if (Symbol* rs = e.Vsym)
        {
            if (rs.Sfl == FL.func)
            {
                cg.emit(OP.I32_CONST, tableIndexReloc(cg.funcIndex(rs), rs));
                return true;
            }

            cg.emitSymAddr(rs, cast(uint) e.Voffset);
            return true;
        }
        assert(0);

    case OPaddr:
        if (cg.emitLValueAddr(e.E1))
            return true;
        elem_print(e.E1);
        assert(0);

    case OPind:
        {
            uint off;
            cg.genElem(splitConstOffset(e.E1, off));
            cg.emitLoad(e.Ety, off);
            return true;
        }

    case OPeq:
        {
            const tym_t lty = tybasic(e.E1.Ety);

            elem* rhsTail = e.E2;
            while (rhsTail && rhsTail.Eoper == OPcomma)
                rhsTail = rhsTail.E2;

            if ((lty == TYdarray || lty == TYdelegate) &&
                rhsTail && (rhsTail.Eoper == OPpair || rhsTail.Eoper == OPrpair) &&
                cg.emitLValueAddr(e.E1))
            {
                for (elem* c = e.E2; c !is rhsTail; c = c.E2)
                    cg.genElemDiscard(c.E1);
                uint addrTmp = cg.allocTemp(WASM_I32);
                cg.emit(OP.LOCAL_SET, Uleb(addrTmp));
                elem* lo = (rhsTail.Eoper == OPpair) ? rhsTail.E1 : rhsTail.E2;
                elem* hi = (rhsTail.Eoper == OPpair) ? rhsTail.E2 : rhsTail.E1;
                cg.emit(OP.LOCAL_GET, Uleb(addrTmp), lo, OP.I32_STORE, Uleb(2), Uleb(0));
                cg.emit(OP.LOCAL_GET, Uleb(addrTmp), hi, OP.I32_STORE, Uleb(2), Uleb(4));
                return false;
            }
            const bool needValue = typeHasValue(e.Ety) && !discard;
            uint memOff;
            if (!el_sideeffect(e.E1) && !el_sideeffect(e.E2))
            {
                if (!cg.emitLValueBase(e.E1, memOff))
                {
                    elem_print(e);
                    assert(0);
                }
                cg.genElem(e.E2);
                uint vTmp;
                if (needValue)
                {
                    vTmp = cg.allocTemp(wasmType(e.E1.Ety));
                    cg.emit(OP.LOCAL_TEE, Uleb(vTmp));
                }
                cg.emitStore(e.E1.Ety, memOff);
                if (needValue)
                {
                    cg.emit(OP.LOCAL_GET, Uleb(vTmp));
                    return true;
                }
                return false;
            }
            uint valTmp = cg.allocTemp(wasmType(e.E1.Ety));
            cg.emit(e.E2, OP.LOCAL_SET, Uleb(valTmp));
            if (cg.emitLValueBase(e.E1, memOff))
            {
                cg.emit(OP.LOCAL_GET, Uleb(valTmp));
                cg.emitStore(e.E1.Ety, memOff);
                if (needValue)
                {
                    cg.emit(OP.LOCAL_GET, Uleb(valTmp));
                    return true;
                }
                return false;
            }
            elem_print(e);
            assert(0);
        }

    case OPaddass:
    case OPminass:
    case OPmulass:
    case OPdivass:
    case OPmodass:
    case OPandass:
    case OPorass:
    case OPxorass:
    case OPshlass:
    case OPshrass:
    case OPashrass:
        {
            if (e.E1.Eoper != OPvar && e.E1.Eoper != OPind)
            {
                cg.genElem(e.E2);
                return true;
            }
            auto lv = saveLValueAddr(cg, e.E1);
            const bool rhsPure = !el_sideeffect(e.E2);
            uint rTmp;
            if (!rhsPure)
            {
                cg.genElem(e.E2, wasmType(e));
                rTmp = cg.allocTemp(wasmType(e));
                cg.emit(OP.LOCAL_SET, Uleb(rTmp));
            }
            const bool needValue = typeHasValue(e.Ety) && !discard;
            const uint storeOff = replayAddr(cg, lv);
            const uint loadOff = replayAddr(cg, lv);
            cg.emitLoad(e.E1.Ety, loadOff);
            if (op == OPshrass)
                cg.zeroExtendForLogicalShift(e.E1.Ety);
            if (rhsPure)
                cg.genElem(e.E2, wasmType(e));
            else
                cg.emit(OP.LOCAL_GET, Uleb(rTmp));
            cg.emitBinop(opeqtoop(op), e.Ety, e.E1.Ety, e.E2.Ety);
            cg.maskSmallInt(e.E1.Ety);
            uint vTmp;
            if (needValue)
            {
                vTmp = cg.allocTemp(wasmType(e.E1.Ety));
                cg.emit(OP.LOCAL_TEE, Uleb(vTmp));
            }
            cg.emitStore(e.E1.Ety, storeOff);
            if (needValue)
            {
                cg.emit(OP.LOCAL_GET, Uleb(vTmp));
                return true;
            }
            return false;
        }

    case OPadd:
    case OPmin:
    case OPmul:
    case OPdiv:
    case OPmod:
    case OPand:
    case OPor:
    case OPxor:
    case OPshl:
    case OPshr:
    case OPashr:
    case OProl:
    case OPror:
        {
            const rty = wasmType(e.Ety);
            cg.genElem(e.E1, rty);
            if (op == OPshr)
                cg.zeroExtendForLogicalShift(e.Ety);
            cg.genElem(e.E2, rty);
            cg.emitBinop(op, e.Ety, e.E1.Ety, e.E2.Ety);
            switch (op)
            {
            case OPadd, OPmin, OPmul, OPshl, OPshr:
                cg.maskSmallInt(e.Ety);
                break;
            default:
                break;
            }
            return true;
        }

    case OPframeptr:
        cg.emit(OP.LOCAL_GET, Uleb(cg.shadowBaseLocal));
        return true;

    case OPva_start:
        {
            elem* eva = e.E1;
            if (e.E1.Eoper == OPrelconst && e.E1.Vsym && isParameter(e.E1.Vsym))
                eva = e.E2;
            cg.genElem(eva);
            cg.emit(OP.LOCAL_GET, Uleb(cg.numParams - 1), OP.I32_STORE, Uleb(2), Uleb(0));
        }
        return false;

    case OPpostinc:
    case OPpostdec:
    {
        assert(e.E1.Eoper == OPvar || e.E1.Eoper == OPind);
        auto lv = saveLValueAddr(cg, e.E1);
        const uint storeOff = replayAddr(cg, lv);
        const uint loadOff = replayAddr(cg, lv);
        cg.emitLoad(e.E1.Ety, loadOff);

        uint oldTmp;
        if (!discard)
        {
            oldTmp = cg.allocTemp(wasmType(e.E1));
            cg.emit(OP.LOCAL_TEE, Uleb(oldTmp));
        }

        cg.genElem(e.E2, wasmType(e.E1.Ety));
        cg.emitBinop(op == OPpostinc ? OPadd : OPmin, e.E1.Ety);
        cg.maskSmallInt(e.E1.Ety);
        cg.emitStore(e.E1.Ety, storeOff);

        if (!discard)
        {
            cg.emit(OP.LOCAL_GET, Uleb(oldTmp));
            return true;
        }
        return false;
    }

    case OPeqeq:
    case OPne:
    case OPlt:
    case OPle:
    case OPgt:
    case OPge:
    case OPunord:
    case OPlg:
    case OPleg:
    case OPule:
    case OPul:
    case OPuge:
    case OPug:
    case OPue:
    case OPngt:
    case OPnge:
    case OPnlt:
    case OPnle:
    case OPord:
    case OPnlg:
    case OPnleg:
    case OPnule:
    case OPnul:
    case OPnuge:
    case OPnug:
    case OPnue:
        cg.genElem(e.E1);
        cg.genElem(e.E2, e.E1.wasmType);
        cg.emitRelop(op, e.E1.Ety);
        return true;

    case OPneg:
        switch (e.wasmType)
        {
        case WASM_F32:
            return unaryOp(OP.F32_NEG);
        case WASM_F64:
            return unaryOp(OP.F64_NEG);

        case WASM_I64:
            cg.emit(OP.I64_CONST, Sleb(0), e.E1, OP.I64_SUB);
            return true;
        case WASM_I32:
            cg.emit(OP.I32_CONST, Sleb(0), e.E1, OP.I32_SUB);
            cg.maskSmallInt(e.Ety);
            return true;
        case WASM_TYPE.V128:
            cg.emit(e.E1, OP.FD_PREFIX, Uleb(vecNegSubop(e.Ety)));
            return true;
        default:
            assert(0);
        }

    case OPabs:
        final switch (e.wasmType)
        {
        case WASM_F32: return unaryOp(OP.F32_ABS);
        case WASM_F64: return unaryOp(OP.F64_ABS);
        case WASM_TYPE.V128:
        case WASM_TYPE.EXNREF:
            assert(0);
        case WASM_I32:
        case WASM_I64:
        {
            const bool is64 = (e.wasmType == WASM_I64);
            uint t = cg.allocTemp(is64 ? WASM_I64 : WASM_I32);
            cg.emit(e.E1, OP.LOCAL_TEE, Uleb(t));
            if (is64)
                cg.emit(OP.I64_CONST, Sleb(63), OP.I64_SHR_S);
            else
                cg.emit(OP.I32_CONST, Sleb(31), OP.I32_SHR_S);
            uint m = cg.allocTemp(is64 ? WASM_I64 : WASM_I32);
            cg.emit(OP.LOCAL_TEE, Uleb(m), OP.LOCAL_GET, Uleb(t));
            cg.emit(is64 ? OP.I64_XOR : OP.I32_XOR);
            cg.emit(OP.LOCAL_GET, Uleb(m));
            cg.emit(is64 ? OP.I64_SUB : OP.I32_SUB);
            return true;
        }
        }

    case OPsqrt:
        final switch (e.wasmType)
        {
        case WASM_F32: return unaryOp(OP.F32_SQRT);
        case WASM_F64: return unaryOp(OP.F64_SQRT);
        case WASM_I32:
        case WASM_I64:
        case WASM_TYPE.V128:
        case WASM_TYPE.EXNREF:
            assert(0);
        }

    case OPsin:
        return libmCall(RTLSYM.SINF, RTLSYM.SIN);
    case OPcos:
        return libmCall(RTLSYM.COSF, RTLSYM.COS);
    case OPrint:
        return libmCall(RTLSYM.RINTF, RTLSYM.RINT);
    case OPrndtol:
        return libmCall(RTLSYM.RNDTOLF, RTLSYM.RNDTOL);

    case OPyl2x:
    case OPyl2xp1:
    {
        const isF32 = e.E1.wasmType == WASM_F32;
        Symbol* fn = op == OPyl2x
            ? getRtlsym(isF32 ? RTLSYM.LOG2F : RTLSYM.LOG2)
            : getRtlsym(isF32 ? RTLSYM.LOG1PF : RTLSYM.LOG1P);
        cg.genElem(e.E1);
        cg.emit(OP.CALL, callReloc(cg.funcIndex(fn), fn));
        if (op == OPyl2xp1)
        {
            enum log2e = 1.4426950408889634074;
            if (isF32)
            {
                cg.emit(OP.F32_CONST, cast(float) log2e);
                cg.emit(OP.F32_MUL);
            }
            else
            {
                cg.emit(OP.F64_CONST, cast(double) log2e);
                cg.emit(OP.F64_MUL);
            }
        }
        cg.genElem(e.E2);
        cg.emit(isF32 ? OP.F32_MUL : OP.F64_MUL);
        return true;
    }

    case OPscale:
    {
        const resTy = e.wasmType;
        Symbol* fn;
        final switch (resTy)
        {
        case WASM_F32: fn = getRtlsym(RTLSYM.LDEXPF); break;
        case WASM_F64: fn = getRtlsym(RTLSYM.LDEXP); break;
        case WASM_I32:
        case WASM_I64:
        case WASM_TYPE.V128:
        case WASM_TYPE.EXNREF:
            assert(0);
        }
        // TODO: investigate this hack
        elem* sig = tyfloating(e.E1.Ety) ? e.E1 : e.E2;
        elem* expo = tyfloating(e.E1.Ety) ? e.E2 : e.E1;
        cg.genElem(sig);
        if (sig.wasmType != resTy)
            cg.emitCoerce(sig.wasmType, resTy);
        cg.genElem(expo);
        if (expo.wasmType != WASM_I32)
            cg.emitCoerce(expo.wasmType, WASM_I32);
        cg.emit(OP.CALL, callReloc(cg.funcIndex(fn), fn));
        return true;
    }

    case OPnegass:
    {
        assert(e.E1.Eoper == OPvar || e.E1.Eoper == OPind);
        auto lv = saveLValueAddr(cg, e.E1);
        const wty = e.E1.Ety.wasmType;
        const uint storeOff = replayAddr(cg, lv);
        if (wty == WASM_I32)
            cg.emit(OP.I32_CONST, Sleb(0));
        else if (wty == WASM_I64)
            cg.emit(OP.I64_CONST, Sleb(0));
        const uint loadOff = replayAddr(cg, lv);
        cg.emitLoad(e.E1.Ety, loadOff);
        final switch (wty)
        {
        case WASM_F32: cg.emit(OP.F32_NEG); break;
        case WASM_F64: cg.emit(OP.F64_NEG); break;
        case WASM_I32: cg.emit(OP.I32_SUB); break;
        case WASM_I64: cg.emit(OP.I64_SUB); break;
        case WASM_TYPE.V128:
        case WASM_TYPE.EXNREF: assert(0);
        }
        cg.maskSmallInt(e.E1.Ety);
        const uint vTmp = cg.allocTemp(wty);
        cg.emit(OP.LOCAL_TEE, Uleb(vTmp));
        cg.emitStore(e.E1.Ety, storeOff);
        cg.emit(OP.LOCAL_GET, Uleb(vTmp));
        return true;
    }

    case OPnot:
        cg.genElem(e.E1);
        cg.emitCondInvert(e.E1);
        return true;

    case OPcom:
        final switch (e.wasmType)
        {
        case WASM_I64:
            cg.emit(e.E1, OP.I64_CONST, Sleb(-1), OP.I64_XOR);
            return true;
        case WASM_I32:
            cg.emit(e.E1, OP.I32_CONST, Sleb(-1), OP.I32_XOR);
            cg.maskSmallInt(e.Ety);
            return true;
        case WASM_TYPE.V128:
            cg.emit(e.E1, OP.FD_PREFIX, Uleb(WASM_SIMD.V128_NOT));
            return true;
        case WASM_F32:
        case WASM_F64:
        case WASM_TYPE.EXNREF:
            assert(0);
        }

    case OPu8_16:
    case OPu16_32:
        cg.genElem(e.E1);
        return true;

    case OPs8_16: return unaryOp(OP.I32_EXTEND8_S);
    case OPs16_32: return unaryOp(OP.I32_EXTEND16_S);
    case OPu32_64: return unaryOp(OP.I64_EXTEND_I32_U);
    case OPs32_64: return unaryOp(OP.I64_EXTEND_I32_S);
    case OP64_32: return unaryOp(OP.I32_WRAP_I64);
    case OPd_f: return unaryOp(OP.F32_DEMOTE_F64);
    case OPf_d: return unaryOp(OP.F64_PROMOTE_F32);
    case OPd_s32: return truncSat(WASM_FC.I32_TRUNC_SAT_F64_S);
    case OPd_u32: return truncSat(WASM_FC.I32_TRUNC_SAT_F64_U);
    case OPd_s64: return truncSat(WASM_FC.I64_TRUNC_SAT_F64_S);
    case OPd_u64: return truncSat(WASM_FC.I64_TRUNC_SAT_F64_U);
    case OPs32_d: return unaryOp(OP.F64_CONVERT_I32_S);
    case OPu32_d: return unaryOp(OP.F64_CONVERT_I32_U);
    case OPs64_d: return unaryOp(OP.F64_CONVERT_I64_S);
    case OPu64_d: return unaryOp(OP.F64_CONVERT_I64_U);

    case OPs16_d:
        cg.emit(e.E1, OP.I32_EXTEND16_S, OP.F64_CONVERT_I32_S);
        return true;
    case OPu16_d:
        cg.emit(e.E1, OP.I32_CONST, Sleb(0xFFFF), OP.I32_AND, OP.F64_CONVERT_I32_U);
        return true;
    case OPd_s16:
        cg.genElem(e.E1);
        cg.emit(OP.FC_PREFIX, Uleb(WASM_FC.I32_TRUNC_SAT_F64_S), OP.I32_EXTEND16_S);
        return true;
    case OPd_u16:
        cg.genElem(e.E1);
        cg.emit(OP.FC_PREFIX, Uleb(WASM_FC.I32_TRUNC_SAT_F64_S), OP.I32_CONST, Sleb(0xFFFF), OP.I32_AND);
        return true;

    case OPd_ld:
    case OPld_d:
        cg.genElem(e.E1); // real == double on wasm
        return true;
    case OPld_u64:
        return truncSat(WASM_FC.I64_TRUNC_SAT_F64_U);
    case OP16_8:
        cg.emit(e.E1, OP.I32_CONST, Sleb(0xFF), OP.I32_AND);
        return true;

    case OP32_16:
        cg.emit(e.E1, OP.I32_CONST, Sleb(0xFFFF), OP.I32_AND);
        return true;

    case OPmsw:
    {
        elem* src = unwrapComma(cg, e.E1);
        if (cg.emitSliceHalf(src, /*ptrHalf*/ true))
            return true;
        cg.emit(src, OP.I64_CONST, Sleb(32), OP.I64_SHR_U, OP.I32_WRAP_I64);
        return true;
    }

    case OPstrpar:
        if (cg.emitStructParAddr(e.E1))
            return true;

        elem_print(e);
        assert(0);

    case OPpair:
    case OPrpair:
    {
        elem* lo = (op == OPpair) ? e.E1 : e.E2;
        elem* hi = (op == OPpair) ? e.E2 : e.E1;
        cg.emit(lo, OP.I64_EXTEND_I32_U, hi, OP.I64_EXTEND_I32_U,
            OP.I64_CONST, Sleb(32), OP.I64_SHL, OP.I64_OR);
        return true;
    }


    case OPcomma:
        cg.genElemDiscard(e.E1);
        if (discard)
        {
            cg.genElemDiscard(e.E2);
            return false;
        }
        return cg.genElem(e.E2);

    case OPcond:
    {
        cg.genElem(e.E1);
        cg.emitCondToI32(e.E1);
        const bool voidCond = !typeHasValue(e.Ety);
        cg.emit(OP.IF);
        if (voidCond)
            cg.emit(WASM_VOID_BLOCK);
        else
            cg.emit(e.wasmType);

        // An arm may push a different width than the cond's type (e2ir types
        // an AA struct-assign cond as the 8-byte struct but its arms yield an
        // opAssign ref); pad/coerce so the if-block type checks:
        //   void main() {
        //       struct Bar { int id; this(this) {} ~this() {} }
        //       Bar[string] bars;
        //       bars["test"] = Bar(42);
        //   }
        void fitArm(bool pushed, elem* arm)
        {
            if (voidCond)
            {
                if (pushed)
                    cg.emit(OP.DROP);
                return;
            }
            if (!pushed)
            {
                cg.emit(OP.I32_CONST, Sleb(0));
                cg.emitCoerce(WASM_I32, e.wasmType);
                return;
            }
            cg.emitCoerce(wasmType(arm.Ety), e.wasmType);
        }

        fitArm(cg.genElem(e.E2.E1), e.E2.E1);
        cg.emit(OP.ELSE);
        fitArm(cg.genElem(e.E2.E2), e.E2.E2);
        cg.emit(OP.END);
        return !voidCond;
    }

    case OPoror:
    case OPandand:
    {
        const bool isOr = op == OPoror;
        if (discard)
        {
            cg.emit(OP.BLOCK, WASM_VOID_BLOCK, e.E1);
            cg.emitCondToI32(e.E1, !isOr);
            cg.emit(OP.BR_IF, Uleb(0));
            cg.genElemDiscard(e.E2);
            cg.emit(OP.END);
            return false;
        }
        // Decide synth-vs-coerce from whether E2 actually pushed, not from
        // typeHasValue(E2.Ety): a nested OPoror/OPandand always leaves an i32
        // yet can be typed void, which would double-count. `a || b || dtor()`
        // in a struct destructor (test17246.d): a void RHS leaves nothing, so
        // synthesise a result for the if-block type check.
        void rhsToI32()
        {
            if (cg.genElem(e.E2))
                cg.emitCondToI32(e.E2);
            else
                cg.emit(OP.I32_CONST, Sleb(0));
        }
        cg.genElem(e.E1);
        cg.emitCondToI32(e.E1);
        cg.emit(OP.IF, WASM_I32);
        if (isOr)
            cg.emit(OP.I32_CONST, Sleb(1));
        else
            rhsToI32();
        cg.emit(OP.ELSE);
        if (isOr)
            rhsToI32();
        else
            cg.emit(OP.I32_CONST, Sleb(0));
        cg.emit(OP.END);
        return true;
    }

    case OPbool:
        cg.genElem(e.E1);
        cg.emitCondToI32(e.E1);
        return true;

    case OPb_8:
        cg.genElem(e.E1);
        return true;

    case OPhalt:
        cg.emit(OP.UNREACHABLE);
        return false;

    case OPvoid:
        return false;

    case OPinfo:
        return cg.genElem(e.E2);

    case OPddtor:
        if (e.E1)
            return cg.genElem(e.E1);
        return false;

    case OPsizeof:
        cg.emit(OP.I32_CONST, Sleb(cast(int) e.Vlong));
        return true;

    case OPstreq:
    {
        uint sz = e.ET ? cast(uint) type_size(e.ET) : 0;
        if (sz == 0)
            return false;

        uint dstTmp = cg.allocTemp(WASM_I32);
        genElemAddr(cg, e.E1);
        cg.emit(OP.LOCAL_TEE, Uleb(dstTmp));
        genElemAddr(cg, e.E2);
        cg.emit(OP.I32_CONST, Sleb(sz));
        cg.emit(OP.FC_PREFIX, Uleb(WASM_FC.MEMORY_COPY), Uleb(0), Uleb(0));
        cg.emit(OP.LOCAL_GET, Uleb(dstTmp));
        return true;
    }

    case OPmemcpy:
    {
        assert(e.E2.Eoper == OPparam);
        uint dstTmp = cg.allocTemp(WASM_I32);
        cg.emit(e.E1, OP.LOCAL_TEE, Uleb(dstTmp));
        cg.genElem(e.E2.E1, WASM_I32);
        cg.genElem(e.E2.E2, WASM_I32);
        cg.emit(OP.FC_PREFIX, Uleb(WASM_FC.MEMORY_COPY), Uleb(0), Uleb(0));
        cg.emit(OP.LOCAL_GET, Uleb(dstTmp));
        return true;
    }

    case OPmemset:
    {
        // IR: OPmemset(dst, OPparam(nelems, val)). Result is dst.
        //   struct BB { ulong bits; }
        //   BB[8] arr; arr[] = BB(0); // val is 8 bytes wide, nelems is 8
        assert(e.E2.Eoper == OPparam);
        elem* enelems = e.E2.E1;
        elem* evalue = e.E2.E2;
        const width = cast(uint) tysize(evalue.Ety);

        uint dstTmp = cg.allocTemp(WASM_I32);
        cg.emit(e.E1, OP.LOCAL_SET, Uleb(dstTmp));

        ulong splat(ulong v)
        {
            const b = v & 0xFF;
            return b * 0x0101_0101_0101_0101;
        }
        const ulong mask = width >= 8 ? ulong.max : (1UL << (width * 8)) - 1;

        // WASM memset only supports 1-byte elements
        // splat() mask checks whether 8-byte element is actually just 1 byte repeated 8 times
        if (width <= 1)
        {
            cg.emit(OP.LOCAL_GET, Uleb(dstTmp));
            cg.genElem(evalue, WASM_I32);
            cg.genElem(enelems, WASM_I32);
            cg.emit(OP.FC_PREFIX, Uleb(WASM_FC.MEMORY_FILL), Uleb(0));
        }
        else if (evalue.Eoper == OPconst && !tyfloating(evalue.Ety) &&
            (evalue.Vullong & mask) == (splat(evalue.Vullong) & mask))
        {
            cg.emit(OP.LOCAL_GET, Uleb(dstTmp), OP.I32_CONST, Sleb(evalue.Vullong & 0xFF));
            cg.genElem(enelems, WASM_I32);
            cg.emit(OP.I32_CONST, Sleb(width), OP.I32_MUL);
            cg.emit(OP.FC_PREFIX, Uleb(WASM_FC.MEMORY_FILL), Uleb(0));
        }
        else
        {
            // Can't use MEMORY_FILL, manual loop:
            //   val = evalue;
            //   cur = dst;
            //   end = cur + nelems * width;
            //   while (cur < end) { *cur = val; cur += width; }
            const vt = evalue.wasmType;
            uint valTmp = cg.allocTemp(vt);
            uint curTmp = cg.allocTemp(WASM_I32);
            uint endTmp = cg.allocTemp(WASM_I32);
            cg.emit(evalue, OP.LOCAL_SET, Uleb(valTmp),
                OP.LOCAL_GET, Uleb(dstTmp), OP.LOCAL_TEE, Uleb(curTmp));
            cg.genElem(enelems, WASM_I32);
            cg.emit(OP.I32_CONST, Sleb(width), OP.I32_MUL, OP.I32_ADD,
                OP.LOCAL_SET, Uleb(endTmp),
                OP.BLOCK, WASM_VOID_BLOCK, OP.LOOP, WASM_VOID_BLOCK,
                OP.LOCAL_GET, Uleb(curTmp), OP.LOCAL_GET, Uleb(endTmp),
                OP.I32_GE_U, OP.BR_IF, Uleb(1));
            cg.emit(OP.LOCAL_GET, Uleb(curTmp), OP.LOCAL_GET, Uleb(valTmp));
            cg.emitStore(evalue.Ety);
            cg.emit(OP.LOCAL_GET, Uleb(curTmp), OP.I32_CONST, Sleb(width),
                OP.I32_ADD, OP.LOCAL_SET, Uleb(curTmp),
                OP.BR, Uleb(0), OP.END, OP.END);
        }
        cg.emit(OP.LOCAL_GET, Uleb(dstTmp));
        return true;
    }

    case OPbsf:
        final switch (e.E1.wasmType)
        {
            case WASM_I64:
                cg.emit(e.E1, OP.I64_CTZ, OP.I32_WRAP_I64);
                return true;
            case WASM_I32:
                return unaryOp(OP.I32_CTZ);
            case WASM_F32:
            case WASM_F64:
            case WASM_TYPE.V128:
            case WASM_TYPE.EXNREF:
                assert(0);
        }

    case OPbsr:
        final switch (e.E1.wasmType)
        {
            case WASM_I64:
                cg.emit(OP.I64_CONST, Sleb(63), e.E1, OP.I64_CLZ, OP.I64_SUB, OP.I32_WRAP_I64);
                return true;
            case WASM_I32:
                cg.emit(OP.I32_CONST, Sleb(31), e.E1, OP.I32_CLZ, OP.I32_SUB);
                return true;
            case WASM_F32:
            case WASM_F64:
            case WASM_TYPE.V128:
            case WASM_TYPE.EXNREF:
                assert(0);
        }

    case OPpopcnt:
    {
        const opnd = e.E1.wasmType;
        cg.emit(e.E1, opnd == WASM_I64 ? OP.I64_POPCNT : OP.I32_POPCNT);
        if (opnd == WASM_I64 && e.wasmType == WASM_I32)
            cg.emit(OP.I32_WRAP_I64);
        else if (opnd == WASM_I32 && e.wasmType == WASM_I64)
            cg.emit(OP.I64_EXTEND_I32_U);
        return true;
    }

    case OPbswap:
        cg.emit(e.E1);
        if (e.wasmType == WASM_I64)
            cg.emitBswap64();
        else
            cg.emitBswap32();
        return true;

    case OPbtc:
    case OPbtr:
    case OPbts:
        cg.emitBitTestOp(op, e.E1, e.E2);
        return true;

    case OPbtst:
        {
            const rty = e.E1.wasmType;
            cg.genElem(e.E1, rty);
            cg.genElem(e.E2, rty);
            final switch (rty)
            {
            case WASM_I32:
                cg.emit(OP.I32_CONST, Sleb(31), OP.I32_AND, OP.I32_SHR_U, OP.I32_CONST, Sleb(1), OP.I32_AND);
                break;
            case WASM_I64:
                cg.emit(OP.I64_CONST, Sleb(63), OP.I64_AND, OP.I64_SHR_U, OP.I64_CONST, Sleb(1), OP.I64_AND);
                break;
            case WASM_F32:
            case WASM_F64:
            case WASM_TYPE.V128:
            case WASM_TYPE.EXNREF:
                assert(0);
            }
            return true;
        }

    case OPu64_128:
    case OPs64_128:
    case OP128_64:
    case OPc_r:
    case OPc_i:
    case OPvp_fp:
    case OPcvp_fp:
    case OPnp_fp:
    case OPvecfill:
        cg.emit(e.E1, OP.FD_PREFIX, Uleb(vecSplatSubop(e.Ety)));
        return true;

    case OPnp_f16p:
    case OPf16p_np:
    case OPoffset:
        printf("wasm codegen non-goal Eoper: %s\n", oper_str(e.Eoper));
        elem_print(e);
        assert(0);

    default:
        cg.emit(OP.UNREACHABLE);
        debug { import core.stdc.stdio : printf; printf("unimplemented e.Eoper: %s\n", oper_str(e.Eoper)); elem_print(e); }
        assert(0);
    }
}

private void emitBswap32(ref WasmCG cg)
{
    uint t = cg.allocTemp(WASM_I32);
    cg.emit(
        OP.LOCAL_TEE, Uleb(t),
        OP.I32_CONST, Sleb(24), OP.I32_SHR_U,
        OP.LOCAL_GET, Uleb(t), OP.I32_CONST, Sleb(8), OP.I32_SHR_U,
        OP.I32_CONST, Sleb(0x0000_FF00), OP.I32_AND, OP.I32_OR,
        OP.LOCAL_GET, Uleb(t), OP.I32_CONST, Sleb(8), OP.I32_SHL,
        OP.I32_CONST, Sleb(0x00FF_0000), OP.I32_AND, OP.I32_OR,
        OP.LOCAL_GET, Uleb(t), OP.I32_CONST, Sleb(24), OP.I32_SHL, OP.I32_OR
    );
}

private void emitBswap64(ref WasmCG cg)
{
    // t = input (i64 on stack);
    // lo = bswap32(t);
    // hi = bswap32(t >> 32);
    // result = (u64(lo) << 32) | u64(hi);
    uint t = cg.allocTemp(WASM_I64);
    uint lo = cg.allocTemp(WASM_I32);
    uint hi = cg.allocTemp(WASM_I32);
    cg.emit(OP.LOCAL_TEE, Uleb(t));

    cg.emit(OP.I32_WRAP_I64);
    cg.emitBswap32();
    cg.emit(OP.LOCAL_SET, Uleb(lo));

    cg.emit(OP.LOCAL_GET, Uleb(t), OP.I64_CONST, Sleb(32), OP.I64_SHR_U, OP.I32_WRAP_I64);
    cg.emitBswap32();
    cg.emit(OP.LOCAL_SET, Uleb(hi));

    cg.emit(OP.LOCAL_GET, Uleb(lo), OP.I64_EXTEND_I32_U, OP.I64_CONST, Sleb(32), OP.I64_SHL,
        OP.LOCAL_GET, Uleb(hi), OP.I64_EXTEND_I32_U, OP.I64_OR);
}

private void emitBitTestOp(ref WasmCG cg, uint op, elem* bitnumE, elem* ptrE)
{
    // bit = bitnumE;
    // addr = ptrE + (bit >> 5) * 4;   // word holding the bit
    // word = *addr;
    // mask = 1 << (bit & 31);
    // result = (word & mask) != 0;    // old bit value, left on stack
    // *addr = word <op> mask;         // bts: |, btr: & ~, btc: ^
    cg.emit(bitnumE);
    const uint bitTmp = cg.allocTemp(WASM_I32);
    const uint addrTmp = cg.allocTemp(WASM_I32);
    const uint wordTmp = cg.allocTemp(WASM_I32);
    const uint maskTmp = cg.allocTemp(WASM_I32);
    const uint resultTmp = cg.allocTemp(WASM_I32);

    cg.emit(
        OP.LOCAL_SET, Uleb(bitTmp), ptrE,
        OP.LOCAL_GET, Uleb(bitTmp), OP.I32_CONST, Sleb(5), OP.I32_SHR_U,
        OP.I32_CONST, Sleb(2), OP.I32_SHL, OP.I32_ADD,
        OP.LOCAL_TEE, Uleb(addrTmp), OP.I32_LOAD, Uleb(2), Uleb(0),
        OP.LOCAL_SET, Uleb(wordTmp),
        OP.I32_CONST, Sleb(1), OP.LOCAL_GET, Uleb(bitTmp),
        OP.I32_CONST, Sleb(31), OP.I32_AND, OP.I32_SHL,
        OP.LOCAL_TEE, Uleb(maskTmp),
        OP.LOCAL_GET, Uleb(wordTmp), OP.I32_AND, OP.I32_CONST, Sleb(0), OP.I32_NE,
        OP.LOCAL_SET, Uleb(resultTmp),
        OP.LOCAL_GET, Uleb(addrTmp), OP.LOCAL_GET, Uleb(wordTmp), OP.LOCAL_GET, Uleb(maskTmp)
    );

    switch (op)
    {
    case OPbts:
        cg.emit(OP.I32_OR);
        break;
    case OPbtr:
        cg.emit(OP.I32_CONST, Sleb(-1), OP.I32_XOR, OP.I32_AND);
        break;
    case OPbtc:
        cg.emit(OP.I32_XOR);
        break;
    default:
        assert(0);
    }
    cg.emit(OP.I32_STORE, Uleb(2), Uleb(0),
        OP.LOCAL_GET, Uleb(resultTmp));
}

private void genElemAddr(ref WasmCG cg, elem* e)
{
    if (!e)
    {
        cg.emit(OP.I32_CONST, Sleb(0));
        return;
    }
    if (!cg.emitLValueAddr(e))
        cg.genElem(e);
}

private ubyte pickByKind(tym_t ty, ubyte f32, ubyte f64, ubyte i64, ubyte i32)
{
    final switch (tybasic(ty).wasmType)
    {
    case WASM_F32: return f32;
    case WASM_F64: return f64;
    case WASM_I64: return i64;
    case WASM_I32: return i32;
    case WASM_TYPE.V128:
    case WASM_TYPE.EXNREF: assert(0);
    }
}

private void emitBinop(ref WasmCG cg, int op, tym_t ty, tym_t ty1 = TYint, tym_t ty2 = TYint)
{
    if (tyvector(ty))
    {
        cg.emit(OP.FD_PREFIX, Uleb(vecBinSubop(op, ty)));
        return;
    }
    if (op == OPmod && tyfloating(ty))
    {
        Symbol* fn = getRtlsym(tybasic(ty).wasmType == WASM_F32 ? RTLSYM.FMODF : RTLSYM.FMOD);
        cg.emit(OP.CALL, callReloc(cg.funcIndex(fn), fn));
        return;
    }
    static ubyte binOp(int op, tym_t ty, tym_t ty1, tym_t ty2)
    {
        alias U = OP.UNREACHABLE;
        const bool isUns = tyuns(ty) != 0 || tyuns(ty1) != 0 || tyuns(ty2) != 0;
        switch (op)
        {
        case OPadd: return pickByKind(ty, OP.F32_ADD, OP.F64_ADD, OP.I64_ADD, OP.I32_ADD);
        case OPmin: return pickByKind(ty, OP.F32_SUB, OP.F64_SUB, OP.I64_SUB, OP.I32_SUB);
        case OPmul: return pickByKind(ty, OP.F32_MUL, OP.F64_MUL, OP.I64_MUL, OP.I32_MUL);
        case OPdiv:
            return pickByKind(ty, OP.F32_DIV, OP.F64_DIV,
                isUns ? OP.I64_DIV_U : OP.I64_DIV_S,
                isUns ? OP.I32_DIV_U : OP.I32_DIV_S);
        case OPmod:
            return pickByKind(ty, U, U,
                isUns ? OP.I64_REM_U : OP.I64_REM_S,
                isUns ? OP.I32_REM_U : OP.I32_REM_S);
        case OPand:  return pickByKind(ty, U, U, OP.I64_AND, OP.I32_AND);
        case OPor:   return pickByKind(ty, U, U, OP.I64_OR, OP.I32_OR);
        case OPxor:  return pickByKind(ty, U, U, OP.I64_XOR, OP.I32_XOR);
        case OPshl:  return pickByKind(ty, U, U, OP.I64_SHL, OP.I32_SHL);
        case OPshr:  return pickByKind(ty, U, U, OP.I64_SHR_U, OP.I32_SHR_U);
        case OPashr: return pickByKind(ty, U, U, OP.I64_SHR_S, OP.I32_SHR_S);
        case OProl:  return pickByKind(ty, U, U, OP.I64_ROTL, OP.I32_ROTL);
        case OPror:  return pickByKind(ty, U, U, OP.I64_ROTR, OP.I32_ROTR);
        default:
            assert(0);
        }
    }

    cg.emit(binOp(op, ty, ty1, ty2));
}

private void emitRelop(ref WasmCG cg, int op, tym_t ty)
{
    if (tyvector(ty))
    {
        cg.emit(OP.FD_PREFIX, Uleb(vecRelSubop(op, ty)));
        return;
    }

    bool negate = false;

    {
        switch (op)
        {
        case OPngt:
        case OPule: op = OPgt;  negate = true; break;
        case OPnge:
        case OPul:  op = OPge;  negate = true; break;
        case OPnlt:
        case OPuge: op = OPlt;  negate = true; break;
        case OPnle:
        case OPug:  op = OPle;  negate = true; break;
        case OPue:
        case OPnlg:  op = OPlg;  negate = true; break;
        case OPunord:
        case OPnleg: op = OPleg; negate = true; break;
        case OPnule: op = OPgt; break;
        case OPnul:  op = OPge; break;
        case OPnuge: op = OPlt; break;
        case OPnug:  op = OPle; break;
        case OPnue:  op = OPlg; break;
        case OPord:  op = OPleg; break;
        default: break;
        }
    }

    if (op == OPlg || op == OPleg)
    {
        const WASM_TYPE wt = wasmType(ty);
        if (wt == WASM_F32 || wt == WASM_F64)
        {
            const uint yTmp = cg.allocTemp(wt);
            const uint xTmp = cg.allocTemp(wt);
            cg.emit(OP.LOCAL_SET, Uleb(yTmp), OP.LOCAL_SET, Uleb(xTmp));
            const ubyte feq = (wt == WASM_F32) ? OP.F32_EQ : OP.F64_EQ;
            cg.emit(OP.LOCAL_GET, Uleb(xTmp), OP.LOCAL_GET, Uleb(xTmp), feq,
                OP.LOCAL_GET, Uleb(yTmp), OP.LOCAL_GET, Uleb(yTmp), feq, OP.I32_AND);
            if (op == OPlg)
            {
                const ubyte fne = (wt == WASM_F32) ? OP.F32_NE : OP.F64_NE;
                cg.emit(OP.LOCAL_GET, Uleb(xTmp), OP.LOCAL_GET, Uleb(yTmp), fne, OP.I32_AND);
            }
            if (negate)
                cg.emit(OP.I32_EQZ);
            return;
        }
        if (op == OPleg)
        {
            cg.emit(OP.DROP, OP.DROP, OP.I32_CONST, Sleb(negate ? 0 : 1));
            return;
        }
        op = OPne;
    }

    static ubyte relOp(int op, tym_t ty)
    {
        const bool isUns = tyuns(ty) != 0;
        switch (op)
        {
        case OPeqeq: return pickByKind(ty, OP.F32_EQ, OP.F64_EQ, OP.I64_EQ, OP.I32_EQ);
        case OPne:   return pickByKind(ty, OP.F32_NE, OP.F64_NE, OP.I64_NE, OP.I32_NE);
        case OPlt:
            return pickByKind(ty, OP.F32_LT, OP.F64_LT,
                isUns ? OP.I64_LT_U : OP.I64_LT_S,
                isUns ? OP.I32_LT_U : OP.I32_LT_S);
        case OPle:
            return pickByKind(ty, OP.F32_LE, OP.F64_LE,
                isUns ? OP.I64_LE_U : OP.I64_LE_S,
                isUns ? OP.I32_LE_U : OP.I32_LE_S);
        case OPgt:
            return pickByKind(ty, OP.F32_GT, OP.F64_GT,
                isUns ? OP.I64_GT_U : OP.I64_GT_S,
                isUns ? OP.I32_GT_U : OP.I32_GT_S);
        case OPge:
            return pickByKind(ty, OP.F32_GE, OP.F64_GE,
                isUns ? OP.I64_GE_U : OP.I64_GE_S,
                isUns ? OP.I32_GE_U : OP.I32_GE_S);
        default:
            assert(0);
        }
    }
    cg.emit(relOp(op, ty));
    if (negate)
        cg.emit(OP.I32_EQZ);
}

/// Function index lookup, routed through WasmCG so the global lookup can
/// eventually become per-instance state.
///
/// Returns: index of `sfunc`
uint funcIndex(ref WasmCG cg, Symbol* sfunc)
{
    return funcIndex(sfunc);
}

/// Find the function defined in this module with the same name as `sfunc`,
/// which may be a distinct redeclaration symbol (C block-scope declarations).
/// Returns: the defining symbol, or null if the function isn't defined here.
Symbol* definedFuncByName(Symbol* sfunc)
{
    uint bodyIdx;
    if (lookupDefinedFuncBody(sfunc, bodyIdx))
        return cast(Symbol*) wasmFuncBodies[bodyIdx].sym;
    return null;
}

uint funcIndex(Symbol* sfunc)
{
    uint importIdx = importFuncIndex(sfunc);
    if (importIdx != uint.max)
        return importIdx;

    uint bodyIdx;
    if (lookupDefinedFuncBody(sfunc, bodyIdx))
        return wmod_numImports() + bodyIdx;

    if (sfunc && sfunc.Stype)
    {
        int idx = WasmObj_external(sfunc);
        return cast(uint) idx;
    }
    return 0;
}

/// Emit `condElem != 0` or `!condElem` depending on `invert`
void emitCondToI32(ref WasmCG cg, elem* condElem, bool invert = false)
{
    const tb = tybasic(condElem.Ety);
    if (tb == TYvoid || tb == TYnoreturn)
    {
        if (invert)
            cg.emit(OP.I32_EQZ);
        return;
    }

    switch (condElem.wasmType)
    {
    case WASM_I64:
        cg.emit(OP.I64_EQZ);

        if (!invert)
            cg.emit(OP.I32_EQZ);
        return;

    case WASM_F32:
        cg.emit(OP.F32_CONST, 0.0f, invert ? OP.F32_EQ : OP.F32_NE);
        return;

    case WASM_F64:
        cg.emit(OP.F64_CONST, 0.0, invert ? OP.F64_EQ : OP.F64_NE);
        return;

    case WASM_I32:
        cg.emit(OP.I32_CONST, Sleb(0), invert ? OP.I32_EQ : OP.I32_NE);
        return;

    default:
        assert(0);
    }
}

void emitCondInvert(ref WasmCG cg, elem* condElem)
{
    return cg.emitCondToI32(condElem, true);
}

/// Eagerly assign shadow-frame offsets to a function's parameters and locals.
///
/// WASM code generation is deferred to module finalization, but a nested
/// function's IR bakes the enclosing frame offset of each captured variable at
/// e2ir time (e2ir.d, the `soffset = s.Soffset` path).  If offsets were only
/// assigned during the deferred wasm_codgen2, every captured variable would
/// still read Soffset 0 and alias the first one.  Called from func_term (which
/// runs during e2ir, parent before child), this fixes the offsets in time.
///
/// Must use the same registration order as wasm_codgen2 (params then locals).
/// registerShadow is idempotent, so wasm_codgen2's later calls reuse these
/// offsets and only re-derive the frame size.
void wasm_assignShadowOffsets(Symbol* sfunc, Symbol*[] symtab)
{
    WasmCG cg;

    foreach (s; symtab)
        if (s.isParameter)
            cg.registerShadow(s);

    foreach (s; symtab)
    {
        if (s.isParameter)
            continue;
        if (s.Sclass == SC.auto_ || s.Sclass == SC.register || s.Sclass == SC.stack)
            cg.registerShadow(s);
    }
}

private bool isNonPodStruct(type* t)
{
    if (!t || tybasic(t.Tty) != TYstruct)
        return false;
    Symbol* tag = t.Ttag;
    return tag && tag.Sstruct && (tag.Sstruct.Sflags & STRnotpod) != 0;
}

private struct ParamSpill
{
    uint wasmLocalIdx;
    Symbol* sym;
    uint byteOffset;
    tym_t ty;
    uint copyBytes;
}

void wasm_codgen2(Symbol* sfunc, ref WasmFuncBody fb)
{
    WasmCG cg;

    ParamSpill[] paramSpills;

    block* startblock = sfunc.Sfunc.Fstartblock;
    const bool canElidePodParams = !funcNeedsFrameBase(startblock);

    foreach (s; fb.symtab)
    {
        if (!s.isParameter)
            continue;
        const tym_t pty = tybasic(s.ty());
        const bool isSliceDg = isSliceOrDelegate(s.Stype);
        const bool isStructLike = pty == TYstruct || pty == TYarray;
        const bool elidePodParam = canElidePodParams
            && pty == TYstruct && !isNonPodStruct(s.Stype)
            && paramReadOnlyPod(s, startblock);
        if (!elidePodParam)
            cg.registerShadow(s);
        if (!isSliceDg && !isStructLike && !typeHasValue(pty))
            continue;
        const uint i0 = cast(uint) cg.locals.length;
        if (isSliceDg)
        {
            cg.locals ~= newTempLocal(WASM_PTR);
            cg.locals ~= newTempLocal(WASM_PTR);
            paramSpills ~= ParamSpill(i0, s, 0, TYuint);
            paramSpills ~= ParamSpill(i0 + 1, s, 4, TYuint);
        }
        else if (isStructLike)
        {
            cg.locals ~= newTempLocal(WASM_PTR);
            if (elidePodParam)
                cg.byRefParamLocal[s] = i0;
            else if (isNonPodStruct(s.Stype))
                paramSpills ~= ParamSpill(i0, s, 0, TYuint);
            else
                paramSpills ~= ParamSpill(i0, s, 0, TYuint, cast(uint) type_size(s.Stype));
        }
        else
        {
            cg.locals ~= newTempLocal(wasmType(pty));
            paramSpills ~= ParamSpill(i0, s, 0, pty);
        }
    }
    WasmFuncType ft = wmod_funcTypeForSym(sfunc);
    while (cg.locals.length < ft.params.length)
    {
        ubyte v = ft.params[cg.locals.length];
        cg.locals ~= newTempLocal(cast(WASM_TYPE) v);
    }
    cg.numParams = cast(uint) ft.params.length;

    foreach (s; fb.symtab)
    {
        if (s.isParameter)
            continue;
        if (s.Sclass == SC.auto_ || s.Sclass == SC.register || s.Sclass == SC.stack)
            cg.registerShadow(s);
    }

    type* retType = sfunc.Stype.Tnext;
    assert(retType);
    const bool hasReturn = ft.results.length != 0;
    cg.retByHiddenPtr = returnByPtr(retType);

    cg.hasShadowFrame = cg.shadowFrameSize != 0
        || paramSpills.length != 0
        || cg.retByHiddenPtr
        || funcNeedsFrameBase(startblock);
    cg.framePublished = cg.hasShadowFrame && funcMakesCall(startblock);
    if (cg.hasShadowFrame)
        cg.emitShadowPrologue();

    foreach (ref sp; paramSpills)
    {
        const uint off = cast(uint) sp.sym.Soffset + sp.byteOffset;
        if (sp.copyBytes)
        {
            cg.emit(OP.LOCAL_GET, Uleb(cg.shadowBaseLocal));
            if (off)
                cg.emit(OP.I32_CONST, Sleb(cast(int) off), OP.I32_ADD);
            cg.emit(OP.LOCAL_GET, Uleb(sp.wasmLocalIdx), OP.I32_CONST, Sleb(sp.copyBytes));
            cg.emit(OP.FC_PREFIX, Uleb(WASM_FC.MEMORY_COPY), Uleb(0), Uleb(0));
            continue;
        }
        cg.emit(OP.LOCAL_GET, Uleb(cg.shadowBaseLocal), OP.LOCAL_GET, Uleb(sp.wasmLocalIdx));
        cg.emitStore(sp.ty, off);
    }

    if (startblock)
        genBlocksProper(cg, startblock, hasReturn);

    if (cg.reachable)
    {
        if (cg.framePublished)
            cg.emitShadowEpilogue();
        if (hasReturn)
            cg.emit(OP.UNREACHABLE);
    }

    fb.locals = cg.locals;
    fb.numParams = cg.numParams;
    fb.relocs = cg.relocs;
    fb.code.reset();
    fb.code.write(cg.code.peekSlice());
}
