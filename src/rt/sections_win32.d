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
    _sections._moduleGroup = ModuleGroup(getModuleInfos());

    auto pbeg = cast(void*)&_xi_a;
    auto pend = cast(void*)&_end;
    _sections._gcRanges[0] = pbeg[0 .. pend - pbeg];
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

extern(C)
{
  extern __gshared
  {
    int _xi_a;      // &_xi_a just happens to be start of data segment
    //int _edata;   // &_edata is start of BSS segment
    int _end;       // &_end is past end of BSS
  }
}
