/**
 * Written in the D programming language.
 * This module provides Win32-specific support for sections.
 *
 * Copyright: Copyright Digital Mars 2008 - 2012.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Walter Bright, Sean Kelly, Martin Nowak
 * Source: $(DRUNTIMESRC src/rt/_sections_win32.d)
 */

module rt.sections_win32;

version(Win32):

// debug = PRINTF;
debug(PRINTF) import core.stdc.stdio;
import rt.minfo;

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
    _sections._moduleGroup = ModuleGroup(getModuleInfos());
}

void finiSections()
{
}

private:

__gshared SectionGroup _sections;

// Windows: this gets initialized by minit.asm
extern(C) __gshared ModuleInfo*[] _moduleinfo_array;
extern(C) void _minit();

ModuleInfo*[] getModuleInfos()
out (result)
{
    foreach(m; result)
        assert(m !is null);
}
body
{
    // _minit directly alters the global _moduleinfo_array
    _minit();
    return _moduleinfo_array;
}
