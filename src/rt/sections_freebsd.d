/**
 * Written in the D programming language.
 * This module provides FreeBSD-specific support for sections.
 *
 * Copyright: Copyright Martin Nowak 2012-2013.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Martin Nowak
 * Source: $(DRUNTIMESRC src/rt/_sections_freebsd.d)
 */

module rt.sections_freebsd;

version (FreeBSD):

// debug = PRINTF;
debug(PRINTF) import core.stdc.stdio;
import core.stdc.stdlib : malloc, free;
import rt.deh2, rt.minfo;

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

    @property inout(ModuleInfo*)[] modules() inout
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
    version (X86_64)
        void[][2] _gcRanges;
    else
        void[][1] _gcRanges;
}

void initSections()
{
    _sections.moduleGroup = ModuleGroup(getModuleInfos());

    version (X86_64)
    {
        auto pbeg = cast(void*)&etext;
        auto pend = cast(void*)&_deh_end;
        _sections._gcRanges[0] = pbeg[0 .. pend - pbeg];
        pbeg = cast(void*)&__progname;
        pend = cast(void*)&_end;
        _sections._gcRanges[1] = pbeg[0 .. pend - pbeg];
    }
    else
    {
        auto pbeg = cast(void*)&etext;
        auto pend = cast(void*)&_end;
        _sections._gcRanges[0] = pbeg[0 .. pend - pbeg];
    }
}

void finiSections()
{
    .free(_sections.modules.ptr);
}

void[] initTLSRanges()
{
    auto pbeg = cast(void*)&_tlsstart;
    auto pend = cast(void*)&_tlsend;
    return pbeg[0 .. pend - pbeg];
}

void finiTLSRanges(void[] rng)
{
}

void scanTLSRanges(void[] rng, scope void delegate(void* pbeg, void* pend) dg)
{
    dg(rng.ptr, rng.ptr + rng.length);
}

private:

__gshared SectionGroup _sections;

// This linked list is created by a compiler generated function inserted
// into the .ctor list by the compiler.
struct ModuleReference
{
    ModuleReference* next;
    ModuleInfo*      mod;
}

extern (C) __gshared ModuleReference* _Dmodule_ref;   // start of linked list

ModuleInfo*[] getModuleInfos()
out (result)
{
    foreach(m; result)
        assert(m !is null);
}
body
{
    size_t len;
    ModuleReference *mr;

    for (mr = _Dmodule_ref; mr; mr = mr.next)
        len++;
    auto result = (cast(ModuleInfo**).malloc(len * size_t.sizeof))[0 .. len];
    len = 0;
    for (mr = _Dmodule_ref; mr; mr = mr.next)
    {   result[len] = mr.mod;
        len++;
    }
    return result;
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

        version (X86_64)
            size_t __progname;
    }

    extern
    {
        void* _tlsstart;
        void* _tlsend;
    }
}
