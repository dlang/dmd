/**
 * Written in the D programming language.
 * This module provides Win32-specific support for sections.
 *
 * Copyright: Copyright Digital Mars 2008 - 2012.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Walter Bright, Sean Kelly, Martin Nowak
 * Source: $(DRUNTIMESRC rt/_sections_win64.d)
 */

module rt.sections_win64;

version (CRuntime_Microsoft):

// debug = PRINTF;
debug(PRINTF) import core.stdc.stdio;
import core.memory;
import core.stdc.stdlib : calloc, malloc, free;
import core.sys.windows.winbase : FreeLibrary, GetCurrentThreadId, GetModuleHandleExW,
    GetProcAddress, LoadLibraryA, LoadLibraryW,
    GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS, GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT;
import core.sys.windows.winnt : WCHAR, IMAGE_DOS_HEADER, IMAGE_DOS_SIGNATURE, IMAGE_FILE_HEADER,
    IMAGE_NT_HEADERS, IMAGE_SECTION_HEADER, IMAGE_TLS_DIRECTORY, IMAGE_DIRECTORY_ENTRY_TLS;
import core.sys.windows.threadaux;
import core.thread;
import rt.deh, rt.minfo;
import core.internal.container.array;

version (DigitalMars) version (Win64) version = hasEHTables;

struct SectionGroup
{
    static int opApply(scope int delegate(ref SectionGroup) dg)
    {
        foreach (sec; _sections)
        {
            if (auto res = dg(*sec))
                return res;
        }
        return 0;
    }

    static int opApplyReverse(scope int delegate(ref SectionGroup) dg)
    {
        foreach_reverse (sec; _sections)
        {
            if (auto res = dg(*sec))
                return res;
        }
        return 0;
    }

    @property immutable(ModuleInfo*)[] modules() const nothrow @nogc
    {
        return _moduleGroup.modules;
    }

    @property ref inout(ModuleGroup) moduleGroup() inout return nothrow @nogc
    {
        return _moduleGroup;
    }

    version (hasEHTables)
    @property immutable(FuncTable)[] ehTables() const nothrow @nogc
    {
        return _ehTables[];
    }

    @property inout(void[])[] gcRanges() inout nothrow @nogc
    {
        return _gcRanges[];
    }

private:
    ModuleGroup _moduleGroup;
    void[][] _gcRanges;
    void* _handle;
    void[] _tpSection; // range with offsets of pointers in TLS
    version (hasEHTables) immutable(FuncTable)[] _ehTables;
}

shared(bool) conservative;

/****
 * Gets called on program startup just before GC is initialized.
 */
void initSections() nothrow @nogc
{
    initSections(&__ImageBase);
}

void initSections(void* handle) nothrow @nogc
{
    auto sectionGroup = cast(SectionGroup*)calloc(1, SectionGroup.sizeof);
    sectionGroup._moduleGroup = ModuleGroup(getModuleInfos(handle));
    sectionGroup._handle = handle;
    version (hasEHTables)
    {
        auto ehsec = findImageSection(handle, "._deh");
        if (ehsec.length)
        {
            // skip empty brace data, the first entry starts with a non-zero function pointer
            size_t pos = 0;
            while (pos + FuncTable.sizeof <= ehsec.length)
            {
                if ((*cast(FuncTable*)(ehsec.ptr + pos)).fptr)
                    break;
                pos += (void*).sizeof;
            }
            size_t cnt = (ehsec.length - pos) / FuncTable.sizeof;
            sectionGroup._ehTables = (cast(immutable(FuncTable*))(ehsec.ptr + pos))[0 .. cnt];
        }
    }

    // the ".data" image section includes both object file sections ".data" and ".bss"
    void[] dataSection = findImageSection(handle, ".data");
    debug(PRINTF) printf("found .data section: [%p,+%llx]\n", dataSection.ptr,
                         cast(ulong)dataSection.length);

    import rt.sections;
    conservative = !scanDataSegPrecisely();

    if (conservative)
    {
        sectionGroup._gcRanges = (cast(void[]*) malloc((void[]).sizeof))[0..1];
        sectionGroup._gcRanges[0] = dataSection;
    }
    else
    {
        // consolidate GC ranges for pointers in the .data segment
        void[] dpSection = findImageSection(handle, ".dp");
        debug(PRINTF) printf("found .dp section: [%p,+%llx]\n", dpSection.ptr,
                             cast(ulong)dpSsection.length);
        auto dp = cast(uint[]) dpSection;
        auto ranges = cast(void[]*) malloc(dp.length * (void[]).sizeof);
        size_t r = 0;
        void* prev = null;
        foreach (off; dp)
        {
            if (off == 0) // skip zero entries added by incremental linking
                continue; // assumes there is no D-pointer at the very beginning of .data
            void* addr = dataSection.ptr + off;
            debug(PRINTF) printf("  scan %p\n", addr);
            // combine consecutive pointers into single range
            if (prev + (void*).sizeof == addr)
                ranges[r-1] = ranges[r-1].ptr[0 .. ranges[r-1].length + (void*).sizeof];
            else
                ranges[r++] = (cast(void**)addr)[0..1];
            prev = addr;
        }
        sectionGroup._gcRanges = ranges[0..r];
        sectionGroup._tpSection = findImageSection(handle, ".tp");
    }
    _sections.insertBack(sectionGroup);
}

/***
 * Gets called on program shutdown just after GC is terminated.
 */
void finiSections() nothrow @nogc
{
    foreach_reverse (ref sec; _sections)
        finiSections(sec);
    _sections.reset();
}

void finiSections(SectionGroup* sec) nothrow @nogc
{
    .free(cast(void*)sec.modules.ptr);
    .free(sec._gcRanges.ptr);
    .free(sec);
}

private void scanTLSPrecise(const(uint)* tp_beg, const(uint)* tp_end, void* base,
                            scope void delegate(void* pbeg, void* pend) nothrow dg) nothrow
{
    for (auto p = tp_beg; p < tp_end; )
    {
        uint beg = *p++;
        uint end = beg + cast(uint)((void*).sizeof);
        while (p < tp_end && *p == end)
        {
            end += (void*).sizeof;
            p++;
        }
        dg(base + beg, base + end);
    }
}

version (Shared)
{
    void** initTLSRanges() nothrow @nogc
    {
        return getTEB();
    }
    void finiTLSRanges(void** teb) nothrow @nogc
    {
    }
    void scanTLSRanges(void** teb, scope void delegate(void* pbeg, void* pend) nothrow dg) nothrow
    {
        foreach (ref sec; _sections)
        {
            auto doshdr = cast(IMAGE_DOS_HEADER*)sec._handle;
            auto nthdr = cast(IMAGE_NT_HEADERS*)(sec._handle + doshdr.e_lfanew);
            auto dir = &(nthdr.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_TLS]);
            if (dir.Size >= IMAGE_TLS_DIRECTORY.sizeof)
            {
                auto tlsdir = cast(IMAGE_TLS_DIRECTORY*)(sec._handle + dir.VirtualAddress);
                auto tls_index = (cast(uint*)tlsdir.AddressOfIndex)[0];
                void** tlsarray = cast(void**)teb[11];

                void* beg = tlsarray[tls_index];
                auto size = tlsdir.EndAddressOfRawData - tlsdir.StartAddressOfRawData + tlsdir.SizeOfZeroFill;

                if (conservative)
                    dg( beg, beg + size);
                else
                    scanTLSPrecise(cast(uint*)&sec._tpSection[0], cast(uint*)&sec._tpSection[$], beg, dg);
            }
        }
    }
}
else // !Shared
{
/***
 * Called once per thread; returns array of thread local storage ranges
 */
void[] initTLSRanges() nothrow @nogc
{
    void* pbeg;
    void* pend;
    // with VS2017 15.3.1, the linker no longer puts TLS segments into a
    //  separate image section. That way _tls_start and _tls_end no
    //  longer generate offsets into .tls, but DATA.
    // Use the TEB entry to find the start of TLS instead and read the
    //  length from the TLS directory
    version (D_InlineAsm_X86)
    {
        asm @nogc nothrow
        {
            mov EAX, _tls_index;
            mov ECX, FS:[0x2C];     // _tls_array
            mov EAX, [ECX+4*EAX];
            mov pbeg, EAX;
            add EAX, [_tls_used+4]; // end
            sub EAX, [_tls_used+0]; // start
            mov pend, EAX;
        }
    }
    else version (D_InlineAsm_X86_64)
    {
        asm @nogc nothrow
        {
            xor RAX, RAX;
            mov EAX, _tls_index;
            mov RCX, 0x58;
            mov RCX, GS:[RCX];      // _tls_array (immediate value causes fixup)
            mov RAX, [RCX+8*RAX];
            mov pbeg, RAX;
            add RAX, [_tls_used+8]; // end
            sub RAX, [_tls_used+0]; // start
            mov pend, RAX;
        }
    }
    else
        static assert(false, "Architecture not supported.");

    return pbeg[0 .. pend - pbeg];
}

void finiTLSRanges(void[] rng) nothrow @nogc
{
}

void scanTLSRanges(void[] rng, scope void delegate(void* pbeg, void* pend) nothrow dg) nothrow
{
    if (conservative)
        dg(rng.ptr, rng.ptr + rng.length);
    else
        scanTLSPrecise(&_TP_beg, &_TP_end, rng.ptr, dg);
}
} // !Shared

extern(C) bool rt_initSharedModule(void* handle)
{
    initSections(handle);
    auto sectionGroup = _sections.back();

    foreach (rng; sectionGroup._gcRanges)
        GC.addRange(rng.ptr, rng.length);

    sectionGroup.moduleGroup.sortCtors();
    sectionGroup.moduleGroup.runCtors();

    foreach (t; Thread)
    {
        impersonate_thread(t.id, () => sectionGroup.moduleGroup.runTlsCtors());
    }
    return true;
}

extern(C) bool rt_termSharedModule(void* handle)
{
    size_t i;
    for(i = 0; i < _sections.length; i++)
        if (_sections[i]._handle == handle)
            break;
    if (i >= _sections.length)
        return false;
    auto sectionGroup = _sections[i];

    foreach (t; Thread)
    {
        impersonate_thread(t.id, () => sectionGroup.moduleGroup.runTlsDtors());
    }
    sectionGroup.moduleGroup.runDtors();
    foreach (rng; sectionGroup._gcRanges)
        GC.removeRange(rng.ptr);

    finiSections(sectionGroup);
    _sections.remove(i);

    return true;
}

private:

///////////////////////////////////////////////////////////////////////////////
// Compiler to runtime interface.
///////////////////////////////////////////////////////////////////////////////

__gshared Array!(SectionGroup*) _sections;

extern(C)
{
    extern __gshared void* _minfo_beg;
    extern __gshared void* _minfo_end;
}

immutable(ModuleInfo*)[] getModuleInfos(void* handle) nothrow @nogc
out (result)
{
    foreach (m; result)
        assert(m !is null);
}
do
{
    // the ".minfo" section consists of pointers to all ModuleInfos defined in object files linked into the image
    void[] minfoSection = findImageSection(handle, ".minfo");
    auto m = (cast(immutable(ModuleInfo*)*)minfoSection.ptr)[0 .. minfoSection.length / size_t.sizeof];
    /* Because of alignment inserted by the linker, various null pointers
     * are there. We need to filter them out.
     */
    auto p = m.ptr;
    auto pend = m.ptr + m.length;

    // count non-null pointers
    size_t cnt;
    for (; p < pend; ++p)
    {
        if (*p !is null) ++cnt;
    }

    auto result = (cast(immutable(ModuleInfo)**).malloc(cnt * size_t.sizeof))[0 .. cnt];

    p = m.ptr;
    cnt = 0;
    for (; p < pend; ++p)
        if (*p !is null) result[cnt++] = *p;

    return cast(immutable)result;
}

extern(C)
{
    /* Symbols created by the compiler/linker and inserted into the
     * object file that 'bracket' sections.
     */
    extern __gshared
    {
        void* __ImageBase;

        void* _deh_beg;
        void* _deh_end;

        uint _DP_beg;
        uint _DP_end;
        uint _TP_beg;
        uint _TP_end;

        void*[2] _tls_used; // start, end
        int _tls_index;
    }
}

///////////////////////////////////////////////////////////////////////////////
// dynamic loading
///////////////////////////////////////////////////////////////////////////////

/***********************************
 * These are a temporary means of providing a GC hook for DLL use.  They may be
 * replaced with some other similar functionality later.
 */
extern (C)
{
    void* gc_getProxy();
    void  gc_setProxy(void* p);
    void  gc_clrProxy();

    alias void  function(void*) gcSetFn;
    alias void  function()      gcClrFn;
}

/*******************************************
 * Loads a DLL written in D with the name 'name'.
 * Returns:
 *      opaque handle to the DLL if successfully loaded
 *      null if failure
 */
extern (C) void* rt_loadLibrary(const char* name)
{
    return initLibrary(.LoadLibraryA(name));
}

extern (C) void* rt_loadLibraryW(const WCHAR* name)
{
    return initLibrary(.LoadLibraryW(name));
}

void* initLibrary(void* mod)
{
    // BUG: LoadLibrary() call calls rt_init(), which fails if proxy is not set!
    // (What? LoadLibrary() is a Windows API call, it shouldn't call rt_init().)
    if (mod is null)
        return mod;
    gcSetFn gcSet = cast(gcSetFn) GetProcAddress(mod, "gc_setProxy");
    if (gcSet !is null)
    {   // BUG: Set proxy, but too late
        gcSet(gc_getProxy());
    }
    return mod;
}

/*************************************
 * Unloads DLL that was previously loaded by rt_loadLibrary().
 * Input:
 *      ptr     the handle returned by rt_loadLibrary()
 * Returns:
 *      1   succeeded
 *      0   some failure happened
 */
extern (C) int rt_unloadLibrary(void* ptr)
{
    gcClrFn gcClr  = cast(gcClrFn) GetProcAddress(ptr, "gc_clrProxy");
    if (gcClr !is null)
        gcClr();
    return FreeLibrary(ptr) != 0;
}

///////////////////////////////////////////////////////////////////////////////
// PE/COFF program header iteration
///////////////////////////////////////////////////////////////////////////////

bool compareSectionName(ref IMAGE_SECTION_HEADER section, string name) nothrow @nogc
{
    if (name[] != section.Name[0 .. name.length])
        return false;
    return name.length == 8 || section.Name[name.length] == 0;
}

void[] findImageSection(void* handle, string name) nothrow @nogc
{
    if (name.length > 8) // section name from string table not supported
        return null;
    IMAGE_DOS_HEADER* doshdr = cast(IMAGE_DOS_HEADER*)handle;
    if (doshdr.e_magic != IMAGE_DOS_SIGNATURE)
        return null;

    auto nthdr = cast(IMAGE_NT_HEADERS*)(handle + doshdr.e_lfanew);
    auto sections = cast(IMAGE_SECTION_HEADER*)(cast(void*)nthdr + IMAGE_NT_HEADERS.OptionalHeader.offsetof + nthdr.FileHeader.SizeOfOptionalHeader);
    for (ushort i = 0; i < nthdr.FileHeader.NumberOfSections; i++)
        if (compareSectionName(sections[i], name))
            return (handle + sections[i].VirtualAddress)[0 .. sections[i].Misc.VirtualSize];

    return null;
}

version (Shared) package void* handleForAddr(void* addr) nothrow @nogc
{
    void* hModule;
    if (!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                            cast(const(wchar)*) addr, &hModule))
        return null;
    return hModule;
}

// DLL entry point for druntime_shared.dll
version (Shared)
{
    import core.sys.windows.dll;
    mixin SimpleDllMain;
}
