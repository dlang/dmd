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
import rt.minfo;
import rt.memory_osx;
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

private:
    ModuleGroup _moduleGroup;
}

void initSections()
{
    _dyld_register_func_for_add_image(&sections_osx_onAddImage);
}

void finiSections()
{
}

private:

__gshared SectionGroup _sections;

extern (C) void sections_osx_onAddImage(in mach_header* h, intptr_t slide)
{
    if (auto sect = getSection(h, slide, "__DATA", "__minfodata"))
    {
        // no support for multiple images yet
        _sections.modules.ptr is null || assert(0);

        debug(PRINTF) printf("  minfodata\n");
        auto p = cast(ModuleInfo**)sect.ptr;
        immutable len = sect.length / (*p).sizeof;

        _sections._moduleGroup = ModuleGroup(p[0 .. len]);
    }
}
