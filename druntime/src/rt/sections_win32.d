/**
 * Written in the D programming language.
 * This module provides Win32-specific support for sections.
 *
 * Copyright: Copyright Digital Mars 2008 - 2012.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Walter Bright, Sean Kelly, Martin Nowak
 * Source: $(DRUNTIMESRC rt/_sections_win32.d)
 */

module rt.sections_win32;

version (CRuntime_DigitalMars):

// debug = PRINTF;
debug(PRINTF) import core.stdc.stdio;
import rt.minfo;
import core.stdc.stdlib : malloc, free;
import core.sys.windows.winbase : FreeLibrary, GetProcAddress, LoadLibraryA, LoadLibraryW;
import core.sys.windows.winnt : WCHAR;

struct SectionGroup
{
    static int opApply(scope int delegate(ref SectionGroup) dg)
    {
        return dg(_sections);
    }

    static int opApplyReverse(scope int delegate(ref SectionGroup) dg)
    {
        return dg(_sections);
    }

    @property immutable(ModuleInfo*)[] modules() const nothrow @nogc
    {
        return _moduleGroup.modules;
    }

    @property ref inout(ModuleGroup) moduleGroup() inout return nothrow @nogc
    {
        return _moduleGroup;
    }

    @property inout(void[])[] gcRanges() inout nothrow @nogc
    {
        return _gcRanges[];
    }

private:
    ModuleGroup _moduleGroup;
    void[][] _gcRanges;
}

shared(bool) conservative;

/****
 * Gets called on program startup just before GC is initialized.
 */
void initSections() nothrow @nogc
{
    _sections._moduleGroup = ModuleGroup(getModuleInfos());

    import rt.sections;
    conservative = !scanDataSegPrecisely();

    if (conservative)
    {
        _sections._gcRanges = (cast(void[]*) malloc(2 * (void[]).sizeof))[0..2];

        auto databeg = cast(void*)&_xi_a;
        auto dataend = cast(void*)_moduleinfo_array.ptr;
        _sections._gcRanges[0] = databeg[0 .. dataend - databeg];

        // skip module info and CONST segment
        auto bssbeg = cast(void*)&_edata;
        auto bssend = cast(void*)&_end;
        _sections._gcRanges[1] = bssbeg[0 .. bssend - bssbeg];
    }
    else
    {
        size_t count = &_DPend - &_DPbegin;
        auto ranges = cast(void[]*) malloc(count * (void[]).sizeof);
        size_t r = 0;
        void* prev = null;
        for (size_t i = 0; i < count; i++)
        {
            void* addr = (&_DPbegin)[i];
            if (prev + (void*).sizeof == addr)
                ranges[r-1] = ranges[r-1].ptr[0 .. ranges[r-1].length + (void*).sizeof];
            else
                ranges[r++] = (cast(void**)addr)[0..1];
            prev = addr;
        }
        _sections._gcRanges = ranges[0..r];
    }
}

/***
 * Gets called on program shutdown just after GC is terminated.
 */
void finiSections() nothrow @nogc
{
    free(_sections._gcRanges.ptr);
}

/***
 * Called once per thread; returns array of thread local storage ranges
 */
void[] initTLSRanges() nothrow @nogc
{
    auto pbeg = cast(void*)&_tlsstart;
    auto pend = cast(void*)&_tlsend;
    return pbeg[0 .. pend - pbeg];
}

void finiTLSRanges(void[] rng) nothrow @nogc
{
}

void scanTLSRanges(void[] rng, scope void delegate(void* pbeg, void* pend) nothrow dg) nothrow
{
    if (conservative)
    {
        dg(rng.ptr, rng.ptr + rng.length);
    }
    else
    {
        for (auto p = &_TPbegin; p < &_TPend; )
        {
            uint beg = *p++;
            uint end = beg + cast(uint)((void*).sizeof);
            while (p < &_TPend && *p == end)
            {
                end += (void*).sizeof;
                p++;
            }
            dg(rng.ptr + beg, rng.ptr + end);
        }
    }
}

private:

///////////////////////////////////////////////////////////////////////////////
// Compiler to runtime interface.
///////////////////////////////////////////////////////////////////////////////

__gshared SectionGroup _sections;

// Windows: this gets initialized by minit.asm
extern(C) __gshared immutable(ModuleInfo*)[] _moduleinfo_array;
extern(C) void _minit() nothrow @nogc;

immutable(ModuleInfo*)[] getModuleInfos() nothrow @nogc
out (result)
{
    foreach (m; result)
        assert(m !is null);
}
do
{
    // _minit directly alters the global _moduleinfo_array
    _minit();
    return _moduleinfo_array;
}

extern(C)
{
    extern __gshared
    {
        int _xi_a;      // &_xi_a just happens to be start of data segment
        int _edata;     // &_edata is start of BSS segment
        int _end;       // &_end is past end of BSS

        void* _DPbegin; // first entry in the array of pointers addresses
        void* _DPend;   // &_DPend points after last entry of array
        uint _TPbegin;  // first entry in the array of TLS offsets of pointers
        uint _TPend;    // &_DPend points after last entry of array
    }

    extern
    {
        int _tlsstart;
        int _tlsend;
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
