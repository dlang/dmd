/**
 * Written in the D programming language.
 * This module provides OSX-specific support for sections.
 *
 * Copyright: Copyright Digital Mars 2008 - 2012.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Walter Bright, Sean Kelly, Martin Nowak
 * Source: $(DRUNTIMESRC src/rt/_sections_osx.d)
 */

module rt.sections_osx;

version(OSX):

// debug = PRINTF;
debug(PRINTF) import core.stdc.stdio;
import core.stdc.stdlib : malloc, free;
import rt.deh2, rt.minfo;
import rt.memory_osx;
import rt.util.container;
import src.core.sys.osx.mach.dyld;
import src.core.sys.osx.mach.getsect;

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

    @property inout(void[])[] gcRanges() inout
    {
        return _gcRanges[];
    }

    @property immutable(FuncTable)[] ehTables() const
    {
        return _ehTables[];
    }

private:
    immutable(FuncTable)[] _ehTables;
    ModuleGroup _moduleGroup;
    Array!(void[]) _gcRanges;
}

void initSections()
{
    _dyld_register_func_for_add_image(&sections_osx_onAddImage);
}

void finiSections()
{
    _sections._gcRanges.reset();
}

private:

__gshared SectionGroup _sections;

extern (C) void sections_osx_onAddImage(in mach_header* h, intptr_t slide)
{
    foreach (e; dataSegs)
    {
        if (auto sect = getSection(h, slide, e.seg.ptr, e.sect.ptr))
            _sections._gcRanges.insertBack((cast(void*)sect.ptr)[0 .. sect.length]);
    }

    if (auto sect = getSection(h, slide, "__DATA", "__minfodata"))
    {
        // no support for multiple images yet
        _sections.modules.ptr is null || assert(0);

        debug(PRINTF) printf("  minfodata\n");
        auto p = cast(ModuleInfo**)sect.ptr;
        immutable len = sect.length / (*p).sizeof;

        _sections._moduleGroup = ModuleGroup(p[0 .. len]);
    }

    if (auto sect = getSection(h, slide, "__DATA", "__deh_eh"))
    {
        // no support for multiple images yet
        _sections._ehTables.ptr is null || assert(0);

        debug(PRINTF) printf("  deh_eh\n");
        auto p = cast(immutable(FuncTable)*)sect.ptr;
        immutable len = sect.length / (*p).sizeof;

        _sections._ehTables = p[0 .. len];
    }
}

struct SegRef
{
    string seg;
    string sect;
}


static immutable SegRef[5] dataSegs = [{SEG_DATA, SECT_DATA},
                           {SEG_DATA, SECT_BSS},
                           {SEG_DATA, SECT_COMMON},
                                           // These two must match names used by compiler machobj.c
                           {SEG_DATA, "__tls_data"},
                           {SEG_DATA, "__tlscoal_nt"}];
