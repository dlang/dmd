/**
 * WebAssembly binary module writer.
 *
 * Implements the Obj interface for the WebAssembly binary format: emits the
 * type, function, export, memory, code and data sections plus the linking and
 * relocation custom sections wasm-ld consumes.
 *
 * It also drives codgen.d's two-phase compilation. Per function, `func_term`
 * records the IR (a WasmFuncBody) and snapshots the local symbol table; code generation is
 * deferred. `term` then, once the whole module is visible: (1) pre-registers
 * every externally-called function and every function pointer held in data as
 * an import, so import indices are frozen before any bytecode is emitted (WASM
 * indices are fixed-width LEBs); (2) interns the defined functions' types after
 * the imports, giving stable ld-compatible type indices; (3) runs `wasm_codgen2`
 * on each function; (4) writes the sections in canonical order.
 *
 * Linking model: this backend patches nothing itself. Function calls, function
 * pointers and data-to-data pointers are emitted as zero/placeholder operands
 * carrying a relocation entry (R_WASM.*) recorded against a Symbol*; wasm-ld
 * resolves the final memory addresses and table/function/type indices. Memory,
 * table and `__stack_pointer` are imported from the linker, not defined here.
 *
 * Data lives in two segments matching the backend's Segments enum: WASM_DATA
 * (initialized) and WASM_UDATA (BSS — still emitted as a real zero-filled
 * segment so `&bssSym` relocates like any other address).
 *
 * Spec: https://webassembly.github.io/spec/core/binary/index.html
 *
 * Copyright:   Copyright (C) 1999-2026 by The D Language Foundation, All Rights Reserved
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/backend/wasm/obj.d, _obj.d)
 */

module dmd.backend.wasm.obj;

import dmd.backend.cc;
import dmd.backend.symbol;
import dmd.backend.cdef;
import dmd.backend.code;
import dmd.backend.debugprint;
import dmd.backend.el;
import dmd.backend.obj;
import dmd.backend.ty;
import dmd.backend.type;
import dmd.backend.wasm.codgen;
import dmd.backend.wasm.enums;
import dmd.backend.wasm.util : ulebSize, slebSize, writeuLEB128_5;
import dmd.common.outbuffer;

// Segment indices used by the backend (must match dmd/backend/cdef.d Segments enum values like DATA and UDATA)
private enum : int
{
    WASM_DATA = 2,
    WASM_UDATA = 4
}

nothrow:
private void pushSegData(int idx)
{
    import dmd.backend.barray : Rarray;

    while (SegData.length <= idx)
    {
        seg_data** p = SegData.push();
        *p = new seg_data();
        (*p).SDseg = cast(int)(SegData.length - 1);
        (*p).SDbuf = new OutBuffer();
    }
}


/// WASM function type
struct WasmFuncType
{
    WASM_TYPE[] params;
    WASM_TYPE[] results;
}

/// Recorded function definition
struct WasmFunc
{
    uint typeIdx; /// index into typeSection; uint.max until pendingType is interned
    WasmFuncType pendingType; /// signature of a defined function awaiting interning (after phase 1)
    Symbol* sym;
    bool exported;
    const(char)[] importModule; /// for imports: module name
    const(char)[] importName; /// for @wasmImportName: import section name (overrides funcName)
    const(char)[] exportName; /// for @wasmExportName: export section name (overrides funcName)
}

/// A relocation inside a function's code body. `sym` is the target symbol (null
/// for type/global/table/tag relocs, whose target is derived from `type`).
/// `symIdx` caches an interned index: the type index for TYPE_INDEX_LEB relocs,
/// or a function index for func-reference relocs. `addend` applies to
/// MEMORY_ADDR_LEB (data-address) relocs.
struct WasmReloc
{
    uint offset;
    ubyte type;
    uint symIdx;
    uint addend;
    Symbol* sym;
}

/// A relocation lowered to its final serialized form: `sym` is the resolved
/// symbol-table index (not a Symbol*). Used when writing both the reloc.DATA
/// and reloc.CODE custom sections.
private struct EmitReloc
{
    uint offset;
    ubyte type;
    uint sym;
    uint addend;
}

struct WasmFuncBody
{
    Symbol* sym;
    Symbol*[] locals; /// params first; temporaries hold a shared type-marker symbol
    uint numParams;
    OutBuffer* code;
    Symbol*[] symtab; /// snapshot of the function's local symbol table (globsym at func_term time)

    WasmReloc[] relocs;
    uint codePayloadStart;
}

__gshared WasmFuncBody[] wasmFuncBodies;

/// Index of the import function whose symbol is exactly `sfunc`, or uint.max if
/// `sfunc` is not registered as an import. O(1) replacement for the linear scan
/// of the import region that funcIndex used to do per function reference.
uint importFuncIndex(const(Symbol)* sfunc)
{
    if (!sfunc)
        return uint.max;
    syncImportIndex();
    if (auto p = cast(Symbol*) sfunc in wmod.symIndex.importBySym)
        return *p;
    return uint.max;
}

/// Look up a defined function's index in wasmFuncBodies, matching by Symbol
/// identity first and then (for non-static C redeclarations) by name.
/// Returns: true and sets `bodyIdx` if found, else false.
bool lookupDefinedFuncBody(Symbol* sfunc, out uint bodyIdx)
{
    syncFuncBodyIndex();
    if (auto p = sfunc in wmod.symIndex.bodyBySym)
    {
        bodyIdx = *p;
        return true;
    }
    if (sfunc && sfunc.Sclass != SC.static_)
    {
        string name = cast(string) sfunc.identifier;
        if (auto p = name in wmod.symIndex.bodyByName)
        {
            bodyIdx = *p;
            return true;
        }
    }
    return false;
}

struct WasmDataSeg
{
    uint offset;
    OutBuffer* data;
    Symbol* sym;
    const(char)[] name;
    uint alignLog2 = 2;
    uint reserved;
}

private void checkSegFull(ref const WasmDataSeg ds)
{
    assert(ds.data.length() == ds.reserved, "wasm data segment not written to its reserved size");
}

/// Append a new data segment of `size` bytes at the next `align_`-aligned
/// linear-memory offset and make it the active segment.
/// Returns: the segment's assigned linear-memory offset
private uint pushDataSeg(uint size, uint align_, Symbol* sym, const(char)[] name)
{
    const uint base = (wmod.dataHeap + (align_ - 1)) & ~(align_ - 1);
    WasmDataSeg ds;
    ds.data = new OutBuffer();
    ds.offset = base;
    ds.sym = sym;
    ds.name = name;
    uint a = 1;
    uint log2 = 0;
    while (a < align_)
    {
        a <<= 1;
        log2++;
    }
    ds.alignLog2 = log2;
    ds.reserved = size;
    if (wmod.dataSegs.length)
        checkSegFull(wmod.dataSegs[$ - 1]);
    wmod.dataSegs ~= ds;
    wmod.segOpen = true;
    wmod.dataHeap = base + size;
    return base;
}

/// Lazy lookup caches over the append-only `wasmFuncBodies` and `wmod.funcs`
/// arrays and the data symbol table. A single Symbol* legitimately appears in
/// several maps at once, yielding a different number in each, because they index
/// different tables: a defined function has a slot in the body list, in the
/// module function index space, and under its name.
struct WasmSymIndex
{
    // Defined functions (a body is emitted in this module), keyed to their
    // position in `wasmFuncBodies`:
    //   int add(int a, int b) { return a + b; }
    uint[Symbol*] bodyBySym;
    uint[string] bodyByName;
    size_t bodyIndexed;

    // Imported functions: declared but defined elsewhere, occupying
    // `wmod.funcs[0 .. numImports]`:
    //   extern(C) int puts(const(char)*);   // body resolved by the linker/host
    uint[Symbol*] importBySym;
    size_t importIndexed;

    // Canonical function index per name: collapses same-named definitions (e.g.
    // comdat/weak template instances emitted in several modules) to one target so
    // a `call` doesn't dispatch to a shadowed duplicate:
    //   int foo(T)(T x) { return cast(int) x; }   // foo!int instantiated twice
    uint[string] canonByName;
    size_t canonLen = size_t.max;

    // Any function in the module function index space (imports + defined),
    // used to turn a call-target Symbol or name into its `call` immediate.
    uint[Symbol*] funcBySym;
    uint[string] funcByName;
    size_t funcLen = size_t.max;

    // Data symbols: globals, string literals, TypeInfo, ModuleInfo, ...:
    //   __gshared int counter = 5;
    uint[Symbol*] dataBySym;
    uint[string] dataByName;
}

struct WasmModule
{
    OutBuffer* objbuf;

    WasmFuncType[] funcTypes;
    WasmFunc[] funcs;
    uint numImports;
    WasmDataSeg[] dataSegs;

    bool segOpen;

    @property WasmDataSeg* activeSeg() nothrow return
    {
        return segOpen && dataSegs.length ? &dataSegs[$ - 1] : null;
    }

    @property uint activeSegIdx() const nothrow
    {
        assert(segOpen && dataSegs.length);
        return cast(uint)(dataSegs.length - 1);
    }

    uint dataHeap = 4; // next free byte offset in linear memory; starts at 4 to reserve address 0 as null

    /// Deferred relocations in data segments. Written as 0 at emit time;
    /// patched in WasmObj_term once all symbol addresses are known. `type`
    /// discriminates TABLE_INDEX_I32 (function-pointer, no addend) from
    /// MEMORY_ADDR_I32 (data-address, with addend).
    struct DataReloc
    {
        uint segIdx;
        uint dataByteOffset;
        ubyte type;
        Symbol* sym;
        uint addend;
    }

    DataReloc[] dataRelocations;

    uint tagTypeIdx = uint.max;

    /// pragma(crt_constructor) functions, emitted as WASM_INIT_FUNCS
    Symbol*[] initFuncs;

    OutBuffer scratch;

    WasmSymIndex symIndex;

nothrow:

    void internPendingTypes() nothrow
    {
        foreach (ref WasmFunc f; funcs)
        {
            if (f.typeIdx == uint.max)
                f.typeIdx = internType(f.pendingType);
        }
    }

    uint internType(const WasmFuncType ft)
    {
        foreach (size_t i, ref const WasmFuncType e; funcTypes)
        {
            if (e.params == ft.params && e.results == ft.results)
                return cast(uint) i;
        }
        funcTypes ~= WasmFuncType(ft.params.dup, ft.results.dup);
        return cast(uint)(funcTypes.length - 1);
    }
}

/// Global module instance (one per compilation unit)
private WasmModule* wmod;

/// Maps mangled function name to WebAssembly import module name.
private __gshared const(char)[][string] g_importModuleTable;

/**
 * Register a WebAssembly import module name for the given mangled function name.
 * Called from the frontend glue for @wasmImportModule("moduleName").
 */
void WasmObj_registerImportModule(const(char)[] mangledName, const(char)[] moduleName) nothrow
{
    g_importModuleTable[cast(string) mangledName] = moduleName;
}

/// Maps mangled function name to the WebAssembly import name it is imported under.
private __gshared const(char)[][string] g_importNameTable;

/**
 * Register a WebAssembly import name for the given mangled function name.
 * Called from the frontend glue for @wasmImportName("importName"). The import
 * is emitted under `importName` rather than under the symbol's link name,
 * which lets a `pragma(mangle)`d declaration import a differently named host
 * function.
 */
void WasmObj_registerImportName(const(char)[] mangledName, const(char)[] importName) nothrow
{
    g_importNameTable[cast(string) mangledName] = importName;
}

/// Maps mangled function name to the WebAssembly export name it should be exported under.
private __gshared const(char)[][string] g_exportNameTable;

/**
 * Register a WebAssembly export name for the given mangled function name.
 * Called from the frontend glue for @wasmExportName("exportName"). The
 * function is emitted into the export section under `exportName` and marked
 * so the linker keeps it without `--export-dynamic`.
 */
void WasmObj_registerExportName(const(char)[] mangledName, const(char)[] exportName) nothrow
{
    g_exportNameTable[cast(string) mangledName] = exportName;
}

private void applyWasmExportName(ref WasmFunc f, Symbol* s) nothrow
{
    if (!s)
        return;
    if (auto p = cast(string) s.identifier in g_exportNameTable)
    {
        f.exportName = *p;
        f.exported = true;
    }
}

public bool isSliceOrDelegate(type* t) @trusted nothrow
{
    if (!t || t.Tnext is null)
        return false;
    const tym_t tb = tybasic(t.Tty);
    return tb == TYdarray || tb == TYdelegate;
}

///: Returns true if the backend type is an aggregate (struct/array) that must be
/// returned via a hidden pointer parameter in the WASM calling convention.
bool returnByPtr(type* t)
{
    auto tb = tybasic(t.Tty);
    if (isSliceOrDelegate(t))
        return true;

    switch (tb)
    {
    case TYstruct:
    case TYarray:
        // alias Empty = void[0]; Empty f();
        return type_size(t) != 0;
    default:
        return false;
    }
}

/// Build a WasmFuncType from a backend function type.
/// Aggregates are passed/returned by pointer; aggregate return adds a hidden i32 first.
/// Slices and delegates are split into 2 params.
/// `sfunc` may be null for indirect calls
/// `hiddenLeadingPtrs` is the number of hidden i32 pointers (delegate context,
/// multi-context array, ...) that the caller prepends to the argument list but
/// that don't appear in `t`'s Tparamtypes. For indirect calls (sfunc == null)
/// it replaces the Fmember/Fnested fixup, which can't be consulted there; it
/// excludes the hidden return pointer, which `returnByPtr` already accounts for.
public WasmFuncType buildFuncType(type* t, Symbol* sfunc, uint hiddenLeadingPtrs = 0)
{
    WasmFuncType ft;

    if (sfunc)
    {
        if (sfunc.identifier == "_Dmain")
            return WasmFuncType([WASM_I32, WASM_PTR], [WASM_I32]);
        if (sfunc.identifier == "__main_argc_argv")
            return WasmFuncType([WASM_I32, WASM_I32], [WASM_I32]);
        if (sfunc.identifier == "__main_void")
            return WasmFuncType([], [WASM_I32]);
    }

    type* ret = t.Tnext;
    const bool hiddenPtr = returnByPtr(ret);
    if (hiddenPtr)
        ft.params ~= WASM_I32;

    foreach (_; 0 .. hiddenLeadingPtrs)
        ft.params ~= WASM_I32;
    if (sfunc && sfunc.Sfunc && (sfunc.Sfunc.Fflags & (Fmember | Fnested)))
        ft.params ~= WASM_I32;

    if (dstyleVariadic(t))
        ft.params ~= WASM_I32;

    const tym_t fty = tybasic(t.Tty);

    foreach (param_t p; t.Tparamtypes ? *t.Tparamtypes : null)
    {
        if (!p.Ptype || !typeHasValue(p.Ptype.Tty))
            continue;

        const tym_t pty = tybasic(p.Ptype.Tty);

        if (isSliceOrDelegate(p.Ptype))
        {
            ft.params ~= WASM_I32;
            ft.params ~= WASM_I32;
        }
        else if (pty == TYstruct || pty == TYarray)
        {
            ft.params ~= WASM_I32;
        }
        else
        {
            ft.params ~= wasmType(pty);
        }
    }

    if (variadic(t))
        ft.params ~= WASM_I32;

    if (!hiddenPtr && ret && typeHasValue(ret.Tty) && type_size(ret) != 0)
        ft.results ~= wasmType(ret.Tty);

    return ft;
}

private void writeCustomSection(ref OutBuffer out_, const(char)[] name, OutBuffer* payload)
{
    OutBuffer header;
    appendName(header, name);
    out_.writeByte(0); // custom section id
    out_.writeuLEB128(cast(uint)(header.length() + payload.length()));
    out_.write(header.peekSlice());
    out_.write(payload.peekSlice());
}


private void writeSection(ref OutBuffer out_, WASM_SECTION id, OutBuffer* payload)
{
    out_.writeByte(cast(ubyte) id);
    out_.writeuLEB128(cast(uint) payload.length());
    out_.write(payload.peekSlice());
}

private bool emitTypeSection(ref OutBuffer out_, ref WasmModule wmod)
{
    if (wmod.funcTypes.length == 0)
        return false;
    OutBuffer* s = &wmod.scratch;
    s.reset();
    s.writeuLEB128(cast(uint) wmod.funcTypes.length);
    foreach (ref const WasmFuncType ft; wmod.funcTypes)
    {
        s.writeByte(0x60);
        s.writeuLEB128(cast(uint) ft.params.length);
        foreach (ubyte v; ft.params)
            s.writeByte(v);
        s.writeuLEB128(cast(uint) ft.results.length);
        foreach (ubyte v; ft.results)
            s.writeByte(v);
    }
    writeSection(out_, WASM_SECTION.type_, s);
    return true;
}

private void appendImportHead(ref OutBuffer s, const(char)[] mod, const(char)[] name, WASM_EXPORT kind)
{
    appendName(s, mod);
    appendName(s, name);
    s.writeByte(kind);
}

/// Always written: every relocatable object imports linear memory and the
/// indirect function table from the linker.
private bool emitImportSection(ref OutBuffer out_, ref WasmModule wmod)
{
    OutBuffer* s = &wmod.scratch;
    s.reset();
    const count = wmod.numImports + 3;
    s.writeuLEB128(count);
    foreach (ref const WasmFunc f; wmod.funcs[0 .. wmod.numImports])
    {
        appendImportHead(*s, f.importModule, f.importName ? f.importName : funcName(f), WASM_EXPORT.FUNC);
        s.writeuLEB128(f.typeIdx);
    }
    appendImportHead(*s, "env", "__linear_memory", WASM_EXPORT.MEM);
    s.writeByte(WASM_LIMITS.NO_MAX);
    s.writeuLEB128(0);

    appendImportHead(*s, "env", "__stack_pointer", WASM_EXPORT.GLOBAL);
    s.writeByte(WASM_I32);
    s.writeByte(WASM_MUT.VAR);

    appendImportHead(*s, "env", "__indirect_function_table", WASM_EXPORT.TABLE);
    s.writeByte(WASM_REFTYPE.FUNCREF);
    s.writeByte(WASM_LIMITS.NO_MAX);
    s.writeuLEB128(0);
    writeSection(out_, WASM_SECTION.import_, s);
    return true;
}

/// Returns: true if section was actually written
private bool emitFunctionSection(ref OutBuffer out_, ref WasmModule wmod)
{
    const defined = cast(uint)(wmod.funcs.length - wmod.numImports);
    if (!defined)
        return false;
    OutBuffer* s = &wmod.scratch;
    s.reset();
    s.writeuLEB128(defined);
    foreach (ref const WasmFunc f; wmod.funcs[wmod.numImports .. $])
        s.writeuLEB128(f.typeIdx);
    writeSection(out_, WASM_SECTION.function_, s);
    return true;
}

/// Returns: true if section was actually written.
/// Only function exports are emitted; the linker provides the memory export.
private bool emitExportSection(ref OutBuffer out_, ref WasmModule wmod)
{
    OutBuffer* s = &wmod.scratch;
    s.reset();
    uint count = 0;
    foreach (ref const WasmFunc f; wmod.funcs)
        if (f.exported)
            ++count;
    if (!count)
        return false;
    s.writeuLEB128(count);
    foreach (size_t i, ref const WasmFunc f; wmod.funcs)
    {
        if (!f.exported)
            continue;
        appendName(*s, f.exportName.length ? f.exportName : funcName(f));
        s.writeByte(WASM_EXPORT.FUNC);
        s.writeuLEB128(cast(uint) i);
    }
    writeSection(out_, WASM_SECTION.export_, s);
    return true;
}

/// Returns: true if section was actually written
private bool emitCodeSection(ref OutBuffer out_, ref WasmModule wmod)
{
    uint defined = cast(uint)(wmod.funcs.length - wmod.numImports);
    if (!defined)
        return false;
    OutBuffer* s = &wmod.scratch;
    s.reset();
    s.writeuLEB128(defined);

    uint payloadOffset = ulebSize(defined);

    foreach (size_t fi, ref const WasmFunc f; wmod.funcs[wmod.numImports .. $])
    {
        WasmFuncBody* fb = fi < wasmFuncBodies.length ? &wasmFuncBodies[fi] : null;

        if (fb && fb.code.length())
        {
            ubyte[] codeBytes = fb.code.peekSlice();
            foreach (ref const WasmReloc r; fb.relocs)
            {
                if (r.type != R_WASM.FUNCTION_INDEX_LEB || !r.sym)
                    continue;
                uint idx = funcIdxBySym(wmod, r.sym);
                if (idx == uint.max || r.offset + 5 > codeBytes.length)
                    continue;
                uint v = idx;
                foreach (b; 0 .. 5)
                {
                    codeBytes[r.offset + b] = cast(ubyte)((v & 0x7f) | (b < 4 ? 0x80 : 0));
                    v >>= 7;
                }
            }
        }

        OutBuffer locBuf;
        uint numLocalGroups = 0;
        if (fb && fb.code.length())
        {
            numLocalGroups = cast(uint)(fb.locals.length - fb.numParams);
            locBuf.writeuLEB128(numLocalGroups);
            foreach (Symbol* l; fb.locals[fb.numParams .. $])
            {
                locBuf.writeuLEB128(1);
                locBuf.writeByte(localWasmType(l));
            }
        }
        else
        {
            locBuf.writeuLEB128(0);
        }

        uint codeLen = fb && fb.code.length() ? cast(uint) fb.code.length() : 1;
        uint bodySize = cast(uint)(locBuf.length() + codeLen + 1);
        uint bodySizeBytes = ulebSize(bodySize);

        if (fb)
            fb.codePayloadStart = payloadOffset + bodySizeBytes + cast(uint) locBuf.length();

        s.writeuLEB128(bodySize);
        s.write(locBuf.peekSlice());
        if (fb && fb.code.length())
            s.write(fb.code.peekSlice());
        else
            s.writeByte(OP.UNREACHABLE);
        s.writeByte(OP.END);

        payloadOffset += bodySizeBytes + bodySize;
    }
    writeSection(out_, WASM_SECTION.code, s);
    return true;
}

/// Tag section (id 13): one entry, the module's `__d_exception` throw tag.
/// Each tag = attribute byte 0x00 (exception) + type index of its signature.
/// Returns: true if section was actually written
private bool emitTagSection(ref OutBuffer out_, ref WasmModule wmod)
{
    if (wmod.tagTypeIdx == uint.max)
        return false;
    OutBuffer* s = &wmod.scratch;
    s.reset();
    s.writeuLEB128(1);
    s.writeByte(0x00);
    s.writeuLEB128(wmod.tagTypeIdx);
    writeSection(out_, WASM_SECTION.tag, s);
    return true;
}

/// Returns: true if section was actually written
private bool emitDataSection(ref OutBuffer out_, ref WasmModule wmod)
{
    if (!wmod.dataSegs.length)
        return false;
    OutBuffer* s = &wmod.scratch;
    s.reset();
    s.writeuLEB128(cast(uint) wmod.dataSegs.length);
    foreach (ref WasmDataSeg ds; wmod.dataSegs)
    {
        s.writeByte(0x00);
        s.writeByte(OP.I32_CONST);
        s.writesLEB128(cast(int) ds.offset);
        s.writeByte(OP.END);
        s.writeuLEB128(cast(uint) ds.data.length());
        s.write(ds.data.peekSlice());
    }
    writeSection(out_, WASM_SECTION.data, s);
    return true;
}

private bool emitLinkingSection(ref OutBuffer out_, ref WasmModule wmod)
{
    OutBuffer body_;
    body_.writeuLEB128(2);

    OutBuffer symtab;
    uint symCount = 0;
    uint[] initFuncSyms;
    Symbol*[] datasymsForLinking = buildDataSymtabOrder(wmod);

    foreach (size_t i, ref const WasmFunc f; wmod.funcs)
    {
        const(char)[] name = funcName(f);
        if (!name.length)
            continue;
        if (isShadowedFunc(wmod, i))
            continue;

        symCount++;
        symtab.writeByte(WASM_SYMTAB.FUNCTION);

        const isImport = i < wmod.numImports;
        uint flags;
        if (isImport)
        {
            flags = WASM_SYM.UNDEFINED;
        }
        else
        {
            flags = 0;
            if (f.exportName.length)
                flags |= WASM_SYM.EXPORTED;
            if (f.sym.Sclass == SC.comdat)
                flags |= WASM_SYM.BINDING_WEAK;
            else if (f.sym.Sclass == SC.static_)
                flags |= WASM_SYM.BINDING_LOCAL;
        }

        symtab.writeuLEB128(flags);
        symtab.writeuLEB128(cast(uint) i);
        if (!isImport)
            appendName(symtab, name);

        foreach (Symbol* ctor; wmod.initFuncs)
            if (ctor is f.sym)
                initFuncSyms ~= symCount - 1;
    }

    foreach (Symbol* sym; datasymsForLinking)
    {
        symCount++;
        uint segIdx = uint.max;
        foreach (size_t i, ref const WasmDataSeg ds; wmod.dataSegs)
        {
            if (ds.sym is sym)
            {
                segIdx = cast(uint) i;
                break;
            }
        }

        symtab.writeByte(WASM_SYMTAB.DATA);
        if (segIdx == uint.max)
        {
            symtab.writeuLEB128(WASM_SYM.UNDEFINED);
            appendName(symtab, sym.identifier);
        }
        else
        {
            uint dflags = 0;
            if (sym.Sclass == SC.comdat || sym.Sclass == SC.comdef)
                dflags |= WASM_SYM.BINDING_WEAK;
            else if (sym.Sclass != SC.global)
                dflags |= WASM_SYM.BINDING_LOCAL;
            symtab.writeuLEB128(dflags);
            appendName(symtab, sym.identifier);
            uint symSize = cast(uint) wmod.dataSegs[segIdx].data.length();
            symtab.writeuLEB128(segIdx);
            symtab.writeuLEB128(0);
            symtab.writeuLEB128(symSize);
        }
    }

    symCount++;
    symtab.writeByte(WASM_SYMTAB.TABLE);
    symtab.writeuLEB128(WASM_SYM.UNDEFINED);
    symtab.writeuLEB128(0);

    symCount++;
    symtab.writeByte(WASM_SYMTAB.GLOBAL);
    symtab.writeuLEB128(WASM_SYM.UNDEFINED);
    symtab.writeuLEB128(0);

    if (wmod.tagTypeIdx != uint.max)
    {
        symCount++;
        symtab.writeByte(WASM_SYMTAB.TAG);
        symtab.writeuLEB128(WASM_SYM.BINDING_WEAK);
        symtab.writeuLEB128(0);
        appendName(symtab, "__d_exception");
    }

    if (wmod.dataSegs.length > 0)
    {
        OutBuffer seginfo;
        seginfo.writeuLEB128(cast(uint) wmod.dataSegs.length);
        foreach (size_t i, ref const WasmDataSeg ds; wmod.dataSegs)
        {
            const(char)[] segName = ds.name.length ? ds.name : ".rodata";
            segName = utf8SanitizeName(segName);
            seginfo.writeuLEB128(cast(uint) segName.length);
            seginfo.write(segName.ptr, cast(uint) segName.length);
            seginfo.writeuLEB128(ds.alignLog2);
            const uint segFlags = ds.name == "minfo" ? WASM_SEG.RETAIN : 0;
            seginfo.writeuLEB128(segFlags);
        }

        body_.writeByte(WASM_LINKING.SEGMENT_INFO);
        body_.writeuLEB128(cast(uint) seginfo.length());
        body_.write(seginfo.peekSlice());
    }

    body_.writeByte(WASM_LINKING.SYMBOL_TABLE);
    body_.writeuLEB128(cast(uint)(ulebSize(symCount) + symtab.length()));
    body_.writeuLEB128(symCount);
    body_.write(symtab.peekSlice());

    if (initFuncSyms.length)
    {
        OutBuffer initFuncs;
        initFuncs.writeuLEB128(cast(uint) initFuncSyms.length);
        foreach (symIdx; initFuncSyms)
        {
            initFuncs.writeuLEB128(65535); // priority, as clang emits for a plain constructor
            initFuncs.writeuLEB128(symIdx);
        }

        body_.writeByte(WASM_LINKING.INIT_FUNCS);
        body_.writeuLEB128(cast(uint) initFuncs.length());
        body_.write(initFuncs.peekSlice());
    }

    writeCustomSection(out_, "linking", &body_);
    return true;
}

/// Emit "reloc.DATA" custom section with R_WASM.TABLE_INDEX_I32 entries for
/// function-table-index (function pointer) writes in the data section.
/// wasm-ld patches these with the correct table indices after linking.
/// dataSectionIdx: the 0-based section index of the data section in the module.
///
/// Returns: true if section was actually written
private bool emitRelocDataSection(ref OutBuffer out_, ref WasmModule wmod, uint dataSectionIdx)
{
    if (!wmod.dataRelocations.length || !wmod.dataSegs.length)
        return false;

    uint[] funcToSymIdx = buildFuncToSymIdx(wmod);
    buildDataSymtabOrder(wmod);
    const uint dataSymBase = countFuncSymtabEntries(wmod, funcToSymIdx);
    uint dataSymIdx(const(Symbol)* sym)
    {
        return dataSymIndex(wmod, dataSymBase, sym);
    }

    uint[] segDataStart;
    segDataStart.length = wmod.dataSegs.length;
    uint cursor = ulebSize(cast(uint) wmod.dataSegs.length);
    foreach (size_t i, ref const WasmDataSeg ds; wmod.dataSegs)
    {
        const uint sz = cast(uint) ds.data.length();
        const uint header = 1 /*kind*/ + 1 /*i32.const*/ + slebSize(cast(int) ds.offset)
                          + 1 /*end*/ + ulebSize(sz);
        segDataStart[i] = cursor + header;
        cursor += header + sz;
    }

    EmitReloc[] rels;

    foreach (ref WasmModule.DataReloc rel; wmod.dataRelocations)
    {
        if (rel.segIdx >= wmod.dataSegs.length)
            continue;
        const uint offset = segDataStart[rel.segIdx] + rel.dataByteOffset;
        if (rel.type == R_WASM.TABLE_INDEX_I32)
        {
            const uint funcIdx = funcIdxBySymOrName(wmod, rel.sym);
            if (funcIdx == uint.max || funcIdx >= funcToSymIdx.length)
                continue;
            uint sym = funcToSymIdx[funcIdx];
            if (sym == uint.max)
                continue;
            rels ~= EmitReloc(offset, R_WASM.TABLE_INDEX_I32, sym, 0);
        }
        else
        {
            if (!rel.sym)
                continue;
            uint sym = dataSymIdx(rel.sym);
            if (sym == uint.max)
                continue;
            rels ~= EmitReloc(offset, R_WASM.MEMORY_ADDR_I32, sym, rel.addend);
        }
    }

    if (!rels.length)
        return false;

    sortByOffset(rels);

    OutBuffer payload;
    payload.writeuLEB128(dataSectionIdx);
    payload.writeuLEB128(cast(uint) rels.length);
    foreach (ref EmitReloc r; rels)
    {
        payload.writeByte(r.type);
        payload.writeuLEB128(r.offset);
        payload.writeuLEB128(r.sym);
        if (r.type == R_WASM.MEMORY_ADDR_I32)
            payload.writesLEB128(cast(int) r.addend);
    }

    writeCustomSection(out_, "reloc.DATA", &payload);
    return true;
}

private bool emitRelocCodeSection(ref OutBuffer out_, ref WasmModule wmod, uint codeSectionIdx)
{
    uint[] funcToSymIdx = buildFuncToSymIdx(wmod);
    Symbol*[] datasyms = buildDataSymtabOrder(wmod);
    const uint dataSymBase = countFuncSymtabEntries(wmod, funcToSymIdx);
    const uint tableSymIdx = dataSymBase + cast(uint) datasyms.length;
    const uint globalSymIdx = tableSymIdx + 1;
    const uint tagSymIdx = globalSymIdx + 1;
    uint dataSymIdx(const(Symbol)* sym)
    {
        return dataSymIndex(wmod, dataSymBase, sym);
    }

    uint currentFuncIdx(ref const WasmReloc r)
    {
        if (r.sym)
        {
            uint fi = funcIdxBySymOrName(wmod, r.sym);
            if (fi != uint.max)
                return fi;
        }
        return r.symIdx;
    }

    uint totalRelocs = 0;
    foreach (ref const WasmFuncBody fb; wasmFuncBodies)
    {
        foreach (ref const WasmReloc r; fb.relocs)
        {
            if (r.type == R_WASM.MEMORY_ADDR_LEB)
            {
                if (r.sym && dataSymIdx(r.sym) != uint.max)
                    totalRelocs++;
                continue;
            }
            uint fi = currentFuncIdx(r);
            if (r.type == R_WASM.TYPE_INDEX_LEB ||
                r.type == R_WASM.GLOBAL_INDEX_LEB ||
                r.type == R_WASM.TABLE_NUMBER_LEB ||
                r.type == R_WASM.TAG_INDEX_LEB ||
                (fi < funcToSymIdx.length && funcToSymIdx[fi] != uint.max))
                totalRelocs++;
        }
    }
    if (!totalRelocs)
        return false;

    EmitReloc[] allRelocs;
    allRelocs.reserve(totalRelocs);

    foreach (ref const WasmFuncBody fb; wasmFuncBodies)
    {
        foreach (ref const WasmReloc r; fb.relocs)
        {
            uint idx;
            uint addend = 0;
            if (r.type == R_WASM.MEMORY_ADDR_LEB)
            {
                if (!r.sym)
                    continue;
                idx = dataSymIdx(r.sym);
                if (idx == uint.max)
                    continue;
                addend = r.addend;
            }
            else if (r.type == R_WASM.TYPE_INDEX_LEB)
            {
                idx = r.symIdx;
            }
            else if (r.type == R_WASM.GLOBAL_INDEX_LEB)
            {
                idx = globalSymIdx;
            }
            else if (r.type == R_WASM.TABLE_NUMBER_LEB)
            {
                idx = tableSymIdx;
            }
            else if (r.type == R_WASM.TAG_INDEX_LEB)
            {
                idx = tagSymIdx;
            }
            else
            {
                uint fi = currentFuncIdx(r);
                if (fi >= funcToSymIdx.length)
                    continue;
                idx = funcToSymIdx[fi];
                if (idx == uint.max)
                    continue;
            }
            allRelocs ~= EmitReloc(fb.codePayloadStart + r.offset, r.type, idx, addend);
        }
    }

    sortByOffset(allRelocs);

    OutBuffer payload;
    payload.writeuLEB128(codeSectionIdx);
    payload.writeuLEB128(cast(uint) allRelocs.length);

    foreach (ref const EmitReloc r; allRelocs)
    {
        payload.writeByte(r.type);
        payload.writeuLEB128(r.offset);
        payload.writeuLEB128(r.sym);
        if (r.type == R_WASM.MEMORY_ADDR_LEB)
            payload.writesLEB128(cast(int) r.addend);
    }

    writeCustomSection(out_, "reloc.CODE", &payload);
    return true;
}

private void sortByOffset(T)(T[] rels)
{
    for (size_t i = 1; i < rels.length; i++)
    {
        T v = rels[i];
        size_t j = i;
        while (j > 0 && rels[j - 1].offset > v.offset)
        {
            rels[j] = rels[j - 1];
            j--;
        }
        rels[j] = v;
    }
}

private uint countFuncSymtabEntries(ref WasmModule wmod, const uint[] funcToSymIdx)
{
    uint n = 0;
    foreach (size_t i; 0 .. funcToSymIdx.length)
        if (funcToSymIdx[i] != uint.max && !isShadowedFunc(wmod, i))
            n++;
    return n;
}

private uint dataSymIndex(ref WasmModule wmod, uint base, const(Symbol)* sym)
{
    if (!sym)
        return uint.max;
    if (auto p = cast(Symbol*) sym in wmod.symIndex.dataBySym)
        return base + *p;
    if (sym.Sident.ptr && dataSymVisible(sym))
        if (auto p = cast(string) sym.identifier in wmod.symIndex.dataByName)
            return base + *p;
    return uint.max;
}

private bool dataSymVisible(const(Symbol)* s)
{
    return s.Sclass == SC.comdat || s.Sclass == SC.global || s.Sclass == SC.extern_ ||
        s.Sclass == SC.comdef;
}

private Symbol*[] buildDataSymtabOrder(ref WasmModule wmod)
{
    Symbol*[] order;
    auto bySym = &wmod.symIndex.dataBySym;
    auto byName = &wmod.symIndex.dataByName;
    *bySym = null;
    *byName = null;
    void add(Symbol* sym)
    {
        if (!sym)
            return;
        if (sym in *bySym)
            return;
        const bool useName = sym.Sident.ptr && dataSymVisible(sym);
        string name = useName ? cast(string) sym.identifier : null;
        if (useName && name in *byName)
            return;
        uint idx = cast(uint) order.length;
        order ~= sym;
        (*bySym)[sym] = idx;
        if (useName)
            (*byName)[name] = idx;
    }
    foreach (ref const WasmDataSeg ds; wmod.dataSegs)
        if (ds.sym)
            add(cast(Symbol*) ds.sym);
    foreach (Symbol* sym; collectRelocDataSyms(wmod))
        add(sym);
    return order;
}

private Symbol*[] collectRelocDataSyms(ref WasmModule wmod)
{
    Symbol*[] datasyms;
    bool[Symbol*] seen;
    void add(Symbol* s)
    {
        if (!s || s in seen)
            return;
        seen[s] = true;
        datasyms ~= s;
    }
    foreach (ref const WasmFuncBody fb; wasmFuncBodies)
        foreach (ref const WasmReloc r; fb.relocs)
            if (r.type == R_WASM.MEMORY_ADDR_LEB)
                add(cast(Symbol*) r.sym);
    foreach (ref const WasmModule.DataReloc r; wmod.dataRelocations)
        if (r.type == R_WASM.MEMORY_ADDR_I32)
            add(cast(Symbol*) r.sym);
    return datasyms;
}

Obj WasmObj_init(OutBuffer* objbuf, const(char)* filename, const(char)* csegname)
{
    wmod = new WasmModule();
    wmod.objbuf = objbuf;
    wasmFuncBodies = null;

    SegData.reset();
    pushSegData(WASM_UDATA);

    return new Obj();
}

void WasmObj_initfile(const(char)* filename, const(char)* csegname, const(char)* modname)
{
}

void WasmObj_termfile()
{
}

void WasmObj_term(const(char)[] objfilename)
{
    WasmObj_term2(objfilename, *wmod, *wmod.objbuf);
    wmod = null;
}

import dmd.backend.oper;

void preRegisterExternals(elem* e)
{
    if (!e)
        return;

    const op = e.Eoper;

    if (op == OPvar || op == OPrelconst)
    {
        Symbol* s = e.Vsym;
        if (s && s.Stype && tyfunc(tybasic(s.Stype.Tty)) &&
            s.Sclass != SC.auto_ && s.Sclass != SC.parameter && s.Sclass != SC.fastpar)
            funcIndex(s);
        return;
    }

    if (OTleaf(op))
        return;

    if (OTunary(op))
    {
        preRegisterExternals(e.E1);
        return;
    }
    preRegisterExternals(e.E1);
    preRegisterExternals(e.E2);
}

void WasmObj_term2(const(char)[] objfilename, ref WasmModule wmod, ref OutBuffer out_)
{
    out_.put("\x00\x61\x73\x6D\x01\x00\x00\x00");

    {
        import dmd.backend.wasm.codgen : wasm_codgen2;

        foreach (ref WasmFuncBody fb; wasmFuncBodies)
        {
            if (!fb.sym || !fb.sym.Sfunc)
                continue;
            block* b = fb.sym.Sfunc.Fstartblock;
            for (; b; b = b.Bnext)
                preRegisterExternals(b.Belem);
        }
        // Data segments (vtables) hold function pointers to functions defined
        // in other objects; register those as imports too, so reloc.DATA has a
        // function symbol wasm-ld can assign a table slot to:
        //   class C { int x; }
        //   void main() { Object o = new C; assert(o.toString() != ""); }
        //   // C's vtable slot for the inherited Object.toString
        {
            import dmd.backend.wasm.codgen : funcIndex;
            foreach (ref rel; wmod.dataRelocations)
                if (rel.type == R_WASM.TABLE_INDEX_I32 && rel.sym)
                    funcIndex(rel.sym);
        }
        wmod.internPendingTypes();

        foreach (ref WasmFuncBody fb; wasmFuncBodies)
        {
            if (!fb.sym)
                continue;
            wasm_codgen2(cast(Symbol*) fb.sym, fb);
            if (config.vasm)
            {
                import core.stdc.stdio : printf;
                import dmd.backend.wasm.wat : wasmDisassemble;
                OutBuffer disasmBuf;
                wasmDisassemble(fb, disasmBuf);
                printf("%.*s", cast(int) disasmBuf.length, disasmBuf.peekChars());
            }
        }
    }

    foreach (ref const WasmDataSeg ds; wmod.dataSegs)
        checkSegFull(ds);

    uint sectionIdx = 0;
    sectionIdx += emitTypeSection(out_, wmod);
    sectionIdx += emitImportSection(out_, wmod);
    sectionIdx += emitFunctionSection(out_, wmod);
    sectionIdx += emitTagSection(out_, wmod);
    sectionIdx += emitExportSection(out_, wmod);

    uint codeSectionIdx = sectionIdx;
    sectionIdx += emitCodeSection(out_, wmod);

    uint dataSectionIdx = sectionIdx;
    sectionIdx += emitDataSection(out_, wmod);

    emitLinkingSection(out_, wmod);
    emitRelocDataSection(out_, wmod, dataSectionIdx);
    emitRelocCodeSection(out_, wmod, codeSectionIdx);
    emitTargetFeaturesSection(out_);
}

private void emitTargetFeaturesSection(ref OutBuffer out_)
{
    static immutable string[8] features =
        ["atomics", "bulk-memory", "exception-handling", "mutable-globals", "nontrapping-fptoint", "reference-types", "sign-ext", "simd128"];
    OutBuffer payload;
    payload.writeuLEB128(features.length);
    foreach (f; features)
    {
        payload.writeByte('+');
        payload.writeuLEB128(cast(uint) f.length);
        payload.write(f);
    }
    writeCustomSection(out_, "target_features", &payload);
}

void WasmObj_linnum(Srcpos srcpos, int seg, targ_size_t offset)
{
}

int WasmObj_codeseg(const char* name, int suffix)
{
    return 0;
}

void WasmObj_startaddress(Symbol* s)
{
}

bool WasmObj_includelib(scope const(char)[] name)
{
    return false;
}

bool WasmObj_linkerdirective(scope const(char)* p)
{
    return false;
}

bool WasmObj_allowZeroSize()
{
    return true;
}

void WasmObj_exestr(const(char)* p)
{
}

void WasmObj_user(const(char)* p)
{
}

void WasmObj_compiler(const(char)* p)
{
}

void WasmObj_wkext(Symbol* s1, Symbol* s2)
{
    assert(0, "wkext is x86-only, unreachable on wasm");
}

void WasmObj_alias(const(char)* n1, const(char)* n2)
{
}

void WasmObj_staticctor(Symbol* s, int dtor, int seg)
{
}

void WasmObj_staticdtor(Symbol* s)
{
}

void WasmObj_setModuleCtorDtor(Symbol* s, bool isCtor)
{
    assert(isCtor); // TargetC.crtDestructorsSupported is false for wasm
    wmod.initFuncs ~= s;
}

void WasmObj_ehtables(Symbol* sfunc, uint size, Symbol* ehsym)
{
}

void WasmObj_ehsections()
{
}

void WasmObj_moduleinfo(Symbol* scc)
{
    if (!scc)
        return;

    pushDataSeg(4, 4, null, "minfo");

    const uint segIdx = wmod.activeSegIdx;
    uint zero = 0;
    wmod.dataSegs[segIdx].data.write(&zero, 4);
    wmod.dataRelocations ~= WasmModule.DataReloc(segIdx, 0, R_WASM.MEMORY_ADDR_I32, scc, 0);

    wmod.segOpen = false;
}

int WasmObj_comdat(Symbol* s)
{
    if (!s || !s.Stype)
        return 0;

    if (s.Sseg >= 0 && s.Sseg < wmod.funcs.length && wmod.funcs[s.Sseg].sym == s)
        return s.Sseg;

    WasmFuncType ft;
    if (tybasic(s.Stype.Tty) != TYvoid)
    {
        ft = buildFuncType(s.Stype, s);
    }

    WasmFunc f;
    f.typeIdx = uint.max;
    f.pendingType = ft;
    f.sym = s;
    f.exported = (s.Sclass == SC.global);
    applyWasmExportName(f, s);

    s.Sseg = cast(int) wmod.funcs.length;
    wmod.funcs ~= f;
    return s.Sseg;
}

int WasmObj_comdatsize(Symbol* s, targ_size_t symsize)
{
    if (s && s.Stype && tyfunc(tybasic(s.Stype.Tty)))
        return WasmObj_comdat(s);
    s.Sseg = WASM_DATA;
    WasmObj_data_start(s, cast(targ_size_t) symsize, WASM_DATA);
    return WASM_DATA;
}

void WasmObj_setcodeseg(int seg)
{
}

seg_data* WasmObj_tlsseg()
{
    return SegData[WASM_DATA];
}

seg_data* WasmObj_tlsseg_bss()
{
    return SegData[WASM_UDATA];
}

seg_data* WasmObj_tlsseg_data()
{
    return SegData[WASM_DATA];
}

void WasmObj_export_symbol(Symbol* s, uint argsize)
{
    if (!s)
        return;
    foreach (ref WasmFunc f; wmod.funcs)
    {
        if (f.sym == s)
        {
            f.exported = true;
            return;
        }
    }
}

void WasmObj_pubdef(int seg, Symbol* s, targ_size_t offset)
{
    WasmObj_export_symbol(s, 0);
}

void WasmObj_pubdefsize(int seg, Symbol* s, targ_size_t offset, targ_size_t symsize)
{
    WasmObj_export_symbol(s, 0);
}

int WasmObj_external_def(const(char)* name)
{
    return 0;
}

int WasmObj_data_start(Symbol* sdata, targ_size_t datasize, int seg)
{
    if (!datasize)
        return 0;

    uint align_ = 4;
    if (sdata && sdata.Stype)
    {
        uint sz = tyalignsize(sdata.Stype.Tty);
        if (sz > 0 && sz <= 8)
            align_ = sz;
    }
    if (sdata && sdata.Salignment > cast(int) align_)
        align_ = cast(uint) sdata.Salignment;

    const uint base = pushDataSeg(cast(uint) datasize, align_, sdata,
        sdata ? sdata.identifier : null);

    if (sdata)
        sdata.Soffset = base;
    return 1;
}

WasmFuncType wmod_funcTypeForSym(Symbol* sfunc)
{
    if (sfunc.Sseg >= 0 && sfunc.Sseg < wmod.funcs.length && wmod.funcs[sfunc.Sseg].sym is sfunc)
        return wmod.funcs[sfunc.Sseg].pendingType;
    foreach (ref WasmFunc f; wmod.funcs)
        if (f.sym is sfunc)
            return f.pendingType;
    return buildFuncType(sfunc.Stype, sfunc);
}

int WasmObj_external(Symbol* s)
{
    if (!s || !s.Stype)
        return 0;
    const(char)[] id = s.identifier;

    foreach (size_t i, ref const WasmFunc f; wmod.funcs)
    {
        if (f.sym is s || funcName(f) == id)
        {
            s.Sseg = cast(int) i;
            return s.Sseg;
        }
    }
    WasmFuncType ft;
    if (tybasic(s.Stype.Tty) != TYvoid)
        ft = buildFuncType(s.Stype, s);
    WasmFunc f;
    f.typeIdx = wmod.internType(ft);
    f.sym = s;
    if (auto p = cast(string) id in g_importModuleTable)
        f.importModule = *p;
    else
        f.importModule = "env";
    if (auto p = cast(string) id in g_importNameTable)
        f.importName = *p;
    wmod.funcs = wmod.funcs[0 .. wmod.numImports] ~ [f] ~ wmod.funcs[wmod.numImports .. $];
    s.Sseg = cast(int) wmod.numImports;
    wmod.numImports++;
    return s.Sseg;
}

int WasmObj_common_block(Symbol* s, targ_size_t size, targ_size_t count)
{
    const uint total = cast(uint)(size * count);
    if (!total || !s)
        return WASM_DATA;

    uint align_ = 4;
    if (s.Stype)
    {
        uint sz = tyalignsize(s.Stype.Tty);
        if (sz > 0 && sz <= 8)
            align_ = sz;
    }
    if (s.Salignment > cast(int) align_)
        align_ = cast(uint) s.Salignment;

    const uint base = pushDataSeg(total, align_, s, s.identifier);
    foreach (_; 0 .. total)
        wmod.activeSeg.data.writeByte(0);
    s.Soffset = base;
    s.Sseg = WASM_DATA;
    wmod.segOpen = false;
    return WASM_DATA;
}

int WasmObj_common_block(Symbol* s, int flag, targ_size_t size, targ_size_t count)
{
    return WasmObj_common_block(s, size, count);
}

void WasmObj_lidata(int seg, targ_size_t offset, targ_size_t count)
{
    /* Zero runs inside an initializer are part of the object being emitted, but CDATA also
     * receives inter-literal alignment padding (see alignOffset in dout.d), and on wasm each
     * literal is its own segment carrying its own alignment, so that padding has no segment to
     * land in. Appending it to the finished segment makes that symbol's data longer than the
     * size pushDataSeg reserved: its address range overlaps the segment that follows, and
     * reftodatseg then resolves a pointer to that following segment against the wrong symbol
     * with a bogus addend, leaving the real literal unreferenced for --gc-sections to delete.
     * A finished segment is exactly full, so padding is the write that would overflow it.
     */
    if (seg == CDATA && wmod.activeSeg)
    {
        const seg_ = wmod.activeSeg;
        const uint written = cast(uint) seg_.data.length();
        const uint room = written >= seg_.reserved ? 0 : seg_.reserved - written;
        if (count > room)
            count = room;
    }
    WasmObj_write_zeros(null, count);
}

void WasmObj_write_zeros(seg_data* pseg, targ_size_t count)
{
    if (!wmod.activeSeg)
        return;
    foreach (_; 0 .. count)
        wmod.activeSeg.data.writeByte(0);
}

void WasmObj_write_byte(seg_data* pseg, uint _byte)
{
    if (wmod.activeSeg)
        wmod.activeSeg.data.writeByte(cast(ubyte) _byte);
}

void WasmObj_write_bytes(seg_data* pseg, const(void[]) a)
{
    if (wmod.activeSeg)
        wmod.activeSeg.data.write(a.ptr, a.length);
}

void WasmObj_byte(int seg, targ_size_t offset, uint _byte)
{
    WasmObj_write_byte(null, _byte);
}

size_t WasmObj_bytes(int seg, targ_size_t offset, const(void)[] data)
{
    if (wmod.activeSeg && data.ptr)
        wmod.activeSeg.data.write(data.ptr, data.length);
    return data.length;
}

void WasmObj_reftodatseg(int seg, targ_size_t offset, targ_size_t val, uint targetdatum, int flags)
{
    if (!wmod.activeSeg)
        return;
    const uint addr = cast(uint) val;
    foreach (size_t i, ref WasmDataSeg ds; wmod.dataSegs)
    {
        const uint len = cast(uint) ds.data.length();
        if (!(addr >= ds.offset && addr < ds.offset + len))
            continue;
        if (!ds.sym)
        {
            import dmd.backend.symbol : symbol_name;
            import core.stdc.stdio : snprintf;
            char[32] buf = void;
            const n = snprintf(buf.ptr, buf.length, ".rodata.%u", cast(uint) i);
            ds.sym = symbol_name(buf[0 .. n], SC.static_, tstypes[TYint]);
            ds.sym.Sfl = FL.data;
        }
        const uint segIdx = wmod.activeSegIdx;
        const uint dataOff = cast(uint) wmod.activeSeg.data.length();
        uint zero = 0;
        wmod.activeSeg.data.write(&zero, 4);
        wmod.dataRelocations ~= WasmModule.DataReloc(segIdx, dataOff, R_WASM.MEMORY_ADDR_I32, ds.sym, addr - ds.offset);
        return;
    }
    wmod.activeSeg.data.write(&addr, 4);
}

void WasmObj_reftocodeseg(int seg, targ_size_t offset, targ_size_t val)
{
}

int WasmObj_reftoident(int seg, targ_size_t offset, Symbol* s, targ_size_t val, int flags)
{
    auto active = wmod.activeSeg;
    if (!active)
        return 4;
    const uint segIdx = wmod.activeSegIdx;
    if (s && s.Stype && tyfunc(tybasic(s.Stype.Tty)))
    {
        uint dataOff = cast(uint) active.data.length;
        uint zero = 0;
        active.data.write(&zero, 4);
        wmod.dataRelocations ~= WasmModule.DataReloc(segIdx, dataOff, R_WASM.TABLE_INDEX_I32, s, 0);
        return 4;
    }
    if (s)
    {
        uint dataOff = cast(uint) active.data.length;
        uint zero = 0;
        active.data.write(&zero, 4);
        wmod.dataRelocations ~= WasmModule.DataReloc(segIdx, dataOff, R_WASM.MEMORY_ADDR_I32, s, cast(uint) val);
        return 4;
    }
    uint addr = cast(uint) val;
    active.data.write(&addr, 4);
    return 4;
}

void WasmObj_far16thunk(Symbol* s)
{
    assert(0, "far16thunk is 16-bit-x86-only, unreachable on wasm");
}

void WasmObj_fltused()
{
    assert(0, "fltused is x86-only, unreachable on wasm");
}

uint wmod_numImports()
{
    return wmod ? wmod.numImports : 0;
}

void wmod_noteTagUse()
{
    assert(wmod);
    if (wmod.tagTypeIdx == uint.max)
        wmod.tagTypeIdx = wmod.internType(WasmFuncType([WASM_TYPE.I32], []));
}

uint wmod_internType(WasmFuncType funcType)
{
    assert(wmod);
    return wmod.internType(funcType);
}

/// Look up the WASM signature recorded for `sfunc` when its body was registered
/// (via WasmObj_func_start).  Returns the registered param count, or uint.max
/// if the function isn't in this module.  Used by wasm_codgen2 so locals get
/// indexed past the implicit WASM params even when the source signature has
/// fewer params than the recorded sig (e.g. `_Dmain` normalisation).
uint wmod_recordedParamCount(Symbol* sfunc)
{
    if (!wmod || !sfunc)
        return uint.max;
    foreach (ref const WasmFunc f; wmod.funcs)
    {
        if (f.sym is sfunc)
            return cast(uint) f.pendingType.params.length;
    }
    return uint.max;
}

uint wmod_findFuncForType(uint typeIdx)
{
    assert(wmod);

    uint localFallback = uint.max;
    foreach (size_t i, ref const WasmFunc f; wmod.funcs)
    {
        if (f.typeIdx != typeIdx)
            continue;

        const(char)[] name = funcName(f);
        if (!name.length)
            continue;

        if (i < wmod.numImports)
            return cast(uint) i;

        if (localFallback == uint.max)
            localFallback = cast(uint) i;
    }
    return localFallback;
}

void wmod_recordDataAddrReloc(uint codeOffset, Symbol* sym, uint addend)
{
    if (!wasmFuncBodies.length)
        return;
    WasmReloc r;
    r.offset = codeOffset;
    r.type = R_WASM.MEMORY_ADDR_LEB;
    r.sym = sym;
    r.addend = addend;
    wasmFuncBodies[$ - 1].relocs ~= r;
}

uint allocRoData_wasm(const(void)* p, uint len, uint align_)
{
    return allocRoData(p, len, align_);
}

private uint allocRoData(const(void)* p, uint len, uint align_)
{
    import core.stdc.stdio : snprintf;
    char[32] buf;
    const n = snprintf(buf.ptr, buf.length, ".rodata.%u",
        cast(uint) wmod.dataSegs.length);
    const uint base = pushDataSeg(len, align_, null, buf[0 .. n].idup);
    if (p)
        wmod.activeSeg.data.write(p, len);
    else
        foreach (_; 0 .. len)
            wmod.activeSeg.data.writeByte(0);
    return base;
}

int WasmObj_data_readonly(void[] data, int* pseg)
{
    const len = cast(int) data.length;
    uint align_ = len >= 8 ? 8 : len >= 4 ? 4 : len >= 2 ? 2 : 1;
    uint off = allocRoData(cast(char*) data.ptr, len, align_);
    if (pseg)
        *pseg = 1;
    return cast(int) off;
}

int WasmObj_data_readonly(void[] data)
{
    int pseg;
    return WasmObj_data_readonly(data, &pseg);
}

int WasmObj_string_literal_segment(uint sz)
{
    return UNKNOWN;
}

Symbol* WasmObj_sym_cdata(tym_t ty, const(void)[] data)
{
    import dmd.backend.global : symboldata;

    uint align_ = cast(uint) tyalignsize(ty);
    if (align_ < 1)
        align_ = 1;
    uint off = allocRoData(cast(char*) data.ptr, cast(int) data.length, align_);
    Symbol* s = symboldata(off, ty);
    s.Sseg = 1;
    if (auto active = wmod.activeSeg)
        active.sym = s;
    return s;
}

void WasmObj_func_start(Symbol* sfunc)
{
    if (!sfunc || !sfunc.Stype)
        return;

    WasmFuncType ft = buildFuncType(sfunc.Stype, sfunc);

    WasmFunc f;
    f.typeIdx = uint.max;
    f.pendingType = ft;
    f.sym = sfunc;
    f.exported = (sfunc.Sclass == SC.global);
    applyWasmExportName(f, sfunc);
    wmod.funcs ~= f;
    sfunc.Sseg = cast(int)(wmod.funcs.length - 1);

    WasmFuncBody fb;
    fb.code = new OutBuffer();
    fb.sym = sfunc;
    wasmFuncBodies ~= fb;
}

/**
 * Emit an adjustor thunk as a real WASM function.
 *
 * An interface method's vtable slot holds a thunk that subtracts the
 * interface offset `d` from the incoming `this` pointer before forwarding to the
 * concrete method.
 *
 * Only the direct-call form (i == -1) produced by toThunkSymbol is handled;
 * the virtual-dispatch form (i != -1) is x86-specific and never reached here.
 *
 * Params:
 *   sthunk = the thunk's Symbol (e.g. _THUNK0)
 *   sfunc  = the concrete target function
 *   d      = signed byte offset added to the `this` pointer
 *   i      = vtbl index for a virtual call, or -1 for a direct call
 */
void WasmObj_thunk(Symbol* sthunk, Symbol* sfunc, uint p, tym_t thisty, int d, int i, uint d2)
{
    assert(i == -1, "wasm only supports direct-call adjustor thunks");

    WasmFuncType ft = wmod_funcTypeForSym(sfunc);

    WasmFunc f;
    f.typeIdx = uint.max;
    f.pendingType = ft;
    f.sym = sthunk;
    sthunk.Sseg = cast(int) wmod.funcs.length;
    wmod.funcs ~= f;

    const uint thisParamIndex = 0;

    WasmFuncBody fb;
    fb.code = new OutBuffer();
    fb.sym = null;
    fb.numParams = cast(uint) ft.params.length;
    foreach (ubyte v; ft.params)
        fb.locals ~= newTempLocal(cast(WASM_TYPE) v);

    foreach (uint pi; 0 .. cast(uint) ft.params.length)
    {
        fb.code.writeByte(OP.LOCAL_GET);
        fb.code.writeuLEB128(pi);
        if (pi == thisParamIndex && d != 0)
        {
            fb.code.writeByte(OP.I32_CONST);
            fb.code.writesLEB128(d);
            fb.code.writeByte(OP.I32_ADD);
        }
    }

    fb.code.writeByte(OP.CALL);
    fb.relocs ~= WasmReloc(cast(uint) fb.code.length,
        R_WASM.FUNCTION_INDEX_LEB, 0, 0, sfunc);
    (*fb.code).writeuLEB128_5(0u);

    wasmFuncBodies ~= fb;
}

void WasmObj_func_term(Symbol* sfunc)
{
    import dmd.backend.symbol : globsym;

    // Yes it's bad that this is how the glue layer passes symbols,
    // could use a refactor
    Symbol*[] symtab = globsym[].dup;

    foreach (ref WasmFuncBody fb; wasmFuncBodies)
    {
        if (fb.sym == sfunc)
        {
            fb.symtab = symtab;
            break;
        }
    }

    import dmd.backend.wasm.codgen : wasm_assignShadowOffsets;
    wasm_assignShadowOffsets(sfunc, symtab);
}

void WasmObj_write_pointerRef(Symbol* s, uint off)
{
}

int WasmObj_jmpTableSegment(Symbol* s)
{
    assert(0, "jmpTableSegment is x86-only; wasm switches lower to br_table");
}

Symbol* WasmObj_tlv_bootstrap()
{
    return null;
}

void WasmObj_gotref(Symbol* s)
{
    assert(0, "GOT/PIC is x86/ELF-only, unreachable on wasm");
}

Symbol* WasmObj_getGOTsym()
{
    assert(0, "GOT/PIC is x86/ELF-only, unreachable on wasm");
}

void WasmObj_refGOTsym()
{
    assert(0, "GOT/PIC is x86/ELF-only, unreachable on wasm");
}

private:

void syncFuncBodyIndex()
{
    auto ix = &wmod.symIndex;
    for (; ix.bodyIndexed < wasmFuncBodies.length; ix.bodyIndexed++)
    {
        Symbol* sym = cast(Symbol*) wasmFuncBodies[ix.bodyIndexed].sym;
        if (!sym)
            continue;
        ix.bodyBySym[sym] = cast(uint) ix.bodyIndexed;
        // Static functions don't participate in name matching, they can differ:
        // ---
        // // a.c: static int foo(void){return 1;} int getA(void){return foo();}
        // // b.c: static int foo(void){return 2;} int getB(void){return foo();}
        // ---
        if (sym.Sclass != SC.static_)
        {
            string name = cast(string) sym.identifier;
            if (name !in ix.bodyByName)
                ix.bodyByName[name] = cast(uint) ix.bodyIndexed;
        }
    }
}

void syncImportIndex()
{
    auto ix = &wmod.symIndex;
    for (; ix.importIndexed < wmod.numImports; ix.importIndexed++)
    {
        Symbol* s = cast(Symbol*) wmod.funcs[ix.importIndexed].sym;
        if (s && s !in ix.importBySym)
            ix.importBySym[s] = cast(uint) ix.importIndexed;
    }
}

const(char)[] utf8SanitizeName(const(char)[] name)
{
    static bool validUtf8(const(char)[] s)
    {
        import dmd.root.utf : utf_decodeChar;

        size_t i = 0;
        while (i < s.length)
        {
            dchar c;
            if (utf_decodeChar(s, i, c) !is null)
                return false;
        }
        return true;
    }
    if (validUtf8(name))
        return name;
    char[] r;
    foreach (char ch; name)
    {
        if (ch < 0x80)
            r ~= ch;
        else
        {
            enum hex = "0123456789ABCDEF";
            r ~= '$';
            r ~= hex[(ch >> 4) & 15];
            r ~= hex[ch & 15];
        }
    }
    return r;
}

void appendName(ref OutBuffer buf, const(char)[] name)
{
    name = utf8SanitizeName(name);
    buf.writeuLEB128(cast(uint) name.length);
    buf.write(name.ptr[0 .. name.length]);
}

const(char)[] funcName(ref const WasmFunc f)
{
    return f.sym ? f.sym.identifier : null;
}

void syncCanonicalFuncNames(ref WasmModule wmod)
{
    if (wmod.symIndex.canonLen == wmod.funcs.length)
        return;
    auto canon = &wmod.symIndex.canonByName;
    *canon = null;

    foreach (j; wmod.numImports .. wmod.funcs.length)
    {
        const(char)[] name = funcName(wmod.funcs[j]);
        auto sym = wmod.funcs[j].sym;
        if (!name.length || (sym && sym.Sclass == SC.static_))
            continue;
        string key = cast(string) name;
        if (key !in *canon)
            (*canon)[key] = cast(uint) j;
    }
    foreach (j; 0 .. wmod.numImports)
    {
        const(char)[] name = funcName(wmod.funcs[j]);
        if (!name.length)
            continue;
        string key = cast(string) name;
        if (key !in *canon)
            (*canon)[key] = cast(uint) j;
    }
    wmod.symIndex.canonLen = wmod.funcs.length;
}

void syncFuncIdxMaps(ref WasmModule wmod)
{
    if (wmod.symIndex.funcLen == wmod.funcs.length)
        return;
    auto bySym = &wmod.symIndex.funcBySym;
    auto byName = &wmod.symIndex.funcByName;
    *bySym = null;
    *byName = null;
    foreach (size_t k, ref const WasmFunc f; wmod.funcs)
    {
        if (f.sym)
        {
            Symbol* sym = cast(Symbol*) f.sym;
            if (sym !in *bySym)
                (*bySym)[sym] = cast(uint) k;
        }
        const(char)[] name = funcName(f);
        if (name.length)
        {
            string key = cast(string) name;
            if (key !in *byName)
                (*byName)[key] = cast(uint) k;
        }
    }
    wmod.symIndex.funcLen = wmod.funcs.length;
}

/// Returns: current wmod.funcs index of a function symbol, or uint.max if not registered.
uint funcIdxBySym(ref WasmModule wmod, const(Symbol)* sym)
{
    if (!sym)
        return uint.max;
    syncFuncIdxMaps(wmod);
    if (auto p = cast(Symbol*) sym in wmod.symIndex.funcBySym)
        return *p;
    return uint.max;
}

uint funcIdxBySymOrName(ref WasmModule wmod, const(Symbol)* sym)
{
    if (!sym)
        return uint.max;
    syncFuncIdxMaps(wmod);
    if (auto p = cast(Symbol*) sym in wmod.symIndex.funcBySym)
        return *p;
    if (sym.Sident.ptr)
        if (auto p = cast(string) sym.identifier in wmod.symIndex.funcByName)
            return *p;
    return uint.max;
}

private uint canonicalFuncForName(ref WasmModule wmod, size_t i)
{
    const(char)[] name = funcName(wmod.funcs[i]);
    if (!name.length)
        return cast(uint) i;
    if (wmod.funcs[i].sym && wmod.funcs[i].sym.Sclass == SC.static_)
        return cast(uint) i;
    syncCanonicalFuncNames(wmod);
    if (auto p = cast(string) name in wmod.symIndex.canonByName)
        return *p;
    return cast(uint) i;
}

private bool isShadowedFunc(ref WasmModule wmod, size_t i)
{
    return canonicalFuncForName(wmod, i) != i;
}

private uint[] buildFuncToSymIdx(ref WasmModule wmod)
{
    uint[] funcToSymIdx;
    funcToSymIdx.length = wmod.funcs.length;
    enum uint SHADOWED = uint.max - 1;
    uint si = 0;
    foreach (size_t i, ref const WasmFunc f; wmod.funcs)
    {
        const(char)[] name = funcName(f);
        if (!name.length)
        {
            funcToSymIdx[i] = uint.max;
            continue;
        }
        if (isShadowedFunc(wmod, i))
        {
            funcToSymIdx[i] = SHADOWED;
            continue;
        }
        funcToSymIdx[i] = si++;
    }
    foreach (size_t i; 0 .. wmod.funcs.length)
    {
        if (funcToSymIdx[i] != SHADOWED)
            continue;
        funcToSymIdx[i] = funcToSymIdx[canonicalFuncForName(wmod, i)];
    }
    return funcToSymIdx;
}
