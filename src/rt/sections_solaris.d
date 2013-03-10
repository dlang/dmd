/**
 * Written in the D programming language.
 * This module provides Solaris-specific support for sections.
 *
 * Copyright: Copyright Martin Nowak 2012-2013.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Martin Nowak
 * Source: $(DRUNTIMESRC src/rt/_sections_solaris.d)
 */

module rt.sections_solaris;

version (Solaris):

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
        auto pbeg = cast(void*)&__dso_handle;
        auto pend = cast(void*)&_end;
        return pbeg[0 .. pend - pbeg];
    }

private:
    ModuleGroup _moduleGroup;
}

void initSections()
{
    _sections.moduleGroup = ModuleGroup(getModuleInfos());
}

void finiSections()
{
    .free(_sections.modules.ptr);
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
        int __dso_handle;
        int _end;
    }
}
