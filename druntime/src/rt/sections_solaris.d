/**
 * Written in the D programming language.
 * This module provides Solaris-specific support for sections.
 *
 * OpenBSD (as of 6.9) lacks dlinfo, RTLD_NOLOAD, and dlpt_tls_modid.
 * Faking support caused problems.
 * That is why we are not using elf_shared on OpenBSD.
 *
 * Copyright: Copyright Martin Nowak 2012-2013.
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Martin Nowak
 * Source: $(DRUNTIMESRC rt/_sections_solaris.d)
 */

module rt.sections_solaris;

version (Solaris)
    version = SolarisOrOpenBSD;
else version (OpenBSD)
    version = SolarisOrOpenBSD;

version (SolarisOrOpenBSD):

// debug = PRINTF;

import rt.deh;
import rt.minfo;

debug (PRINTF) import core.stdc.stdio : printf;

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

    @property immutable(FuncTable)[] ehTables() const nothrow @nogc
    {
        auto pbeg = cast(immutable(FuncTable)*)&__start_deh;
        auto pend = cast(immutable(FuncTable)*)&__stop_deh;
        return pbeg[0 .. pend - pbeg];
    }

    @property inout(void[])[] gcRanges() inout return nothrow @nogc
    {
        return _gcRanges[];
    }

private:
    ModuleGroup _moduleGroup;
    void[][1] _gcRanges;
}

void initSections() nothrow @nogc
{
    auto mbeg = cast(immutable ModuleInfo**)&__start_minfo;
    auto mend = cast(immutable ModuleInfo**)&__stop_minfo;
    _sections.moduleGroup = ModuleGroup(mbeg[0 .. mend - mbeg]);

    auto pbeg = cast(void*)&__dso_handle;
    auto pend = cast(void*)&_end;
    _sections._gcRanges[0] = pbeg[0 .. pend - pbeg];
}

void finiSections() nothrow @nogc
{
}

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
    dg(rng.ptr, rng.ptr + rng.length);
}

private:

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
        int __dso_handle;
        int _end;
    }

    extern
    {
        void* _tlsstart;
        void* _tlsend;
    }
}
