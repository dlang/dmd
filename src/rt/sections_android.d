/**
 * Written in the D programming language.
 * This module provides bionic-specific support for sections.
 *
 * Copyright: Copyright Martin Nowak 2012-2013.
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Martin Nowak
 * Source: $(DRUNTIMESRC rt/_sections_android.d)
 */

module rt.sections_android;

version (CRuntime_Bionic):

version (X86)    version = X86_Any;
version (X86_64) version = X86_Any;

// debug = PRINTF;
debug(PRINTF) import core.stdc.stdio;
import core.stdc.stdlib : malloc, free;
import rt.deh, rt.minfo;
import core.sys.posix.pthread;
import core.stdc.stdlib : calloc;
import core.stdc.string : memcpy;

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

    @property ref inout(ModuleGroup) moduleGroup() inout nothrow @nogc
    {
        return _moduleGroup;
    }

    @property immutable(FuncTable)[] ehTables() const nothrow @nogc
    {
        auto pbeg = cast(immutable(FuncTable)*)&__start_deh;
        auto pend = cast(immutable(FuncTable)*)&__stop_deh;
        return pbeg[0 .. pend - pbeg];
    }

    @property inout(void[])[] gcRanges() inout nothrow @nogc
    {
        return _gcRanges[];
    }

private:
    ModuleGroup _moduleGroup;
    void[][1] _gcRanges;
}

void initSections() nothrow @nogc
{
    pthread_key_create(&_tlsKey, null);

    auto mbeg = cast(immutable ModuleInfo**)&__start_minfo;
    auto mend = cast(immutable ModuleInfo**)&__stop_minfo;
    _sections.moduleGroup = ModuleGroup(mbeg[0 .. mend - mbeg]);

    auto pbeg = cast(void*)&_tlsend;
    auto pend = cast(void*)&__bss_end__;
    // _tlsend is a 32-bit int and may not be 64-bit void*-aligned, so align pbeg.
    version (D_LP64) pbeg = cast(void*)(cast(size_t)(pbeg + 7) & ~cast(size_t)7);
    _sections._gcRanges[0] = pbeg[0 .. pend - pbeg];
}

void finiSections() nothrow @nogc
{
    pthread_key_delete(_tlsKey);
}

void[]* initTLSRanges() nothrow @nogc
{
    return &getTLSBlock();
}

void finiTLSRanges(void[]* rng) nothrow @nogc
{
    .free(rng.ptr);
    .free(rng);
}

void scanTLSRanges(void[]* rng, scope void delegate(void* pbeg, void* pend) nothrow dg) nothrow
{
    dg(rng.ptr, rng.ptr + rng.length);
}

/* NOTE: The Bionic C library ignores thread-local data stored in the normal
 *       .tbss/.tdata ELF sections, which are marked with the SHF_TLS/STT_TLS
 *       flags.  So instead we roll our own by keeping TLS data in the
 *       .tdata/.tbss sections but removing the SHF_TLS/STT_TLS flags, and
 *       access the TLS data using this function and the _tlsstart/_tlsend
 *       symbols as delimiters.
 *
 *       This function is called by the code emitted by the compiler.  It
 *       is expected to translate an address in the TLS static data to
 *       the corresponding address in the TLS dynamic per-thread data.
 */

extern(C) void* __tls_get_addr( void* p ) nothrow @nogc
{
    debug(PRINTF) printf("  __tls_get_addr input - %p\n", p);
    immutable offset = cast(size_t)(p - cast(void*)&_tlsstart);
    auto tls = getTLSBlockAlloc();
    assert(offset < tls.length);
    return tls.ptr + offset;
}

private:

__gshared pthread_key_t _tlsKey;

ref void[] getTLSBlock() nothrow @nogc
{
    auto pary = cast(void[]*)pthread_getspecific(_tlsKey);
    if (pary is null)
    {
        pary = cast(void[]*).calloc(1, (void[]).sizeof);
        if (pthread_setspecific(_tlsKey, pary) != 0)
        {
            import core.stdc.stdio;
            perror("pthread_setspecific failed with");
            assert(0);
        }
    }
    return *pary;
}

ref void[] getTLSBlockAlloc() nothrow @nogc
{
    auto pary = &getTLSBlock();
    if (!pary.length)
    {
        auto pbeg = cast(void*)&_tlsstart;
        auto pend = cast(void*)&_tlsend;
        auto p = .malloc(pend - pbeg);
        memcpy(p, pbeg, pend - pbeg);
        *pary = p[0 .. pend - pbeg];
    }
    return *pary;
}

__gshared SectionGroup _sections;

extern(C)
{
    /* Symbols created by the compiler/linker and inserted into the
     * object file that 'bracket' sections.
     */
    extern __gshared
    {
        void* __start_deh;
        void* __stop_deh;
        void* __start_minfo;
        void* __stop_minfo;

        version (X86_Any)
        {
            // the x86 linker scripts don't provide __bss_end__; use _end instead
            size_t _end;
            alias __bss_end__ = _end;
        }
        else
        {
            size_t __bss_end__;
        }

        int _tlsstart;
        int _tlsend;
    }
}
