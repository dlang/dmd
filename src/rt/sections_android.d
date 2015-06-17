/**
 * Written in the D programming language.
 * This module provides bionic-specific support for sections.
 *
 * Copyright: Copyright Martin Nowak 2012-2013.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Martin Nowak
 * Source: $(DRUNTIMESRC src/rt/_sections_android.d)
 */

module rt.sections_android;

version (CRuntime_Bionic):

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

    @property immutable(ModuleInfo*)[] modules() const
    {
        return _moduleGroup.modules;
    }

    @property ref inout(ModuleGroup) moduleGroup() inout
    {
        return _moduleGroup;
    }

    @property immutable(FuncTable)[] ehTables() const
    {
        auto pbeg = cast(immutable(FuncTable)*)&_deh_beg;
        auto pend = cast(immutable(FuncTable)*)&_deh_end;
        return pbeg[0 .. pend - pbeg];
    }

    @property inout(void[])[] gcRanges() inout
    {
        return _gcRanges[];
    }

private:
    ModuleGroup _moduleGroup;
    void[][1] _gcRanges;
}

void initSections()
{
    pthread_key_create(&_tlsKey, null);
    _sections.moduleGroup = ModuleGroup(getModuleInfos());

    auto pbeg = cast(void*)&etext;
    auto pend = cast(void*)&_end;
    _sections._gcRanges[0] = pbeg[0 .. pend - pbeg];
}

void finiSections()
{
    .free(cast(void*)_sections.modules.ptr);
    pthread_key_delete(_tlsKey);
}

void[]* initTLSRanges()
{
    return &getTLSBlock();
}

void finiTLSRanges(void[]* rng)
{
    .free(rng.ptr);
    .free(rng);
}

void scanTLSRanges(void[]* rng, scope void delegate(void* pbeg, void* pend) nothrow dg) nothrow
{
    dg(rng.ptr, rng.ptr + rng.length);
}

/* NOTE: The Bionic C library does not allow storing thread-local data
 *       in the normal .tbss/.tdata ELF sections. So instead we roll our
 *       own by simply putting tls into the non-tls .data/.bss sections
 *       and using the _tlsstart/_tlsend symbols as delimiters of the tls
 *       data.
 *
 *       This function is called by the code emitted by the compiler.  It
 *       is expected to translate an address in the TLS static data to
 *       the corresponding address in the TLS dynamic per-thread data.
 */

// NB: the compiler mangles this function as '___tls_get_addr' even though it is extern(D)
extern(D) void* ___tls_get_addr( void* p )
{
    debug(PRINTF) printf("  ___tls_get_addr input - %p\n", p);
    immutable offset = cast(size_t)(p - cast(void*)&_tlsstart);
    auto tls = getTLSBlockAlloc();
    assert(offset < tls.length);
    return tls.ptr + offset;
}

private:

__gshared pthread_key_t _tlsKey;

ref void[] getTLSBlock()
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

ref void[] getTLSBlockAlloc()
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

// This linked list is created by a compiler generated function inserted
// into the .ctor list by the compiler.
struct ModuleReference
{
    ModuleReference* next;
    ModuleInfo* mod;
}

extern (C) __gshared immutable(ModuleReference*) _Dmodule_ref;   // start of linked list

immutable(ModuleInfo*)[] getModuleInfos()
out (result)
{
    foreach(m; result)
        assert(m !is null);
}
body
{
    size_t len;
    immutable(ModuleReference)* mr;

    for (mr = _Dmodule_ref; mr; mr = mr.next)
        len++;
    auto result = (cast(immutable(ModuleInfo)**).malloc(len * size_t.sizeof))[0 .. len];
    len = 0;
    for (mr = _Dmodule_ref; mr; mr = mr.next)
    {   result[len] = mr.mod;
        len++;
    }
    return cast(immutable)result;
}

extern(C)
{
    /* Symbols created by the compiler/linker and inserted into the
     * object file that 'bracket' sections.
     */
    extern __gshared
    {
        void* _deh_beg;
        void* _deh_end;

        size_t etext;
        size_t _end;

        void* _tlsstart;
        void* _tlsend;
    }
}
