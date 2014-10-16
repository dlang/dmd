/**
 * Written in the D programming language.
 * This module provides Solaris-specific support for sections.
 *
 * Copyright: Copyright Martin Nowak 2012-2013.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Martin Nowak
 * Source: $(DRUNTIMESRC src/rt/_sections_solaris.d)
 */

module rt.sections_solaris;

version (Solaris):

// debug = PRINTF;
debug(PRINTF) import core.stdc.stdio;
import core.stdc.stdlib : malloc, free;
import rt.deh, rt.minfo;

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
    _sections.moduleGroup = ModuleGroup(getModuleInfos());

    auto pbeg = cast(void*)&__dso_handle;
    auto pend = cast(void*)&_end;
    _sections._gcRanges[0] = pbeg[0 .. pend - pbeg];
}

void finiSections()
{
    .free(cast(void*)_sections.modules.ptr);
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

void scanTLSRanges(void[] rng, scope void delegate(void* pbeg, void* pend) nothrow dg) nothrow
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
        int __dso_handle;
        int _end;
    }

    extern
    {
        void* _tlsstart;
        void* _tlsend;
    }
}
