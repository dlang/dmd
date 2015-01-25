/**
 * Written in the D programming language.
 * This module provides Win32-specific support for sections.
 *
 * Copyright: Copyright Digital Mars 2008 - 2012.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Walter Bright, Sean Kelly, Martin Nowak
 * Source: $(DRUNTIMESRC src/rt/_sections_win64.d)
 */

module rt.sections_win64;

version(CRuntime_Microsoft):

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

    version(Win64)
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
    void[][2] _gcRanges;
}

void initSections()
{
    _sections._moduleGroup = ModuleGroup(getModuleInfos());

    auto pbeg = cast(void*)&_data_beg;
    auto pend = cast(void*)&_data_end;
    _sections._gcRanges[0] = pbeg[0 .. pend - pbeg];

    pbeg = cast(void*)&_bss_beg;
    pend = cast(void*)&_bss_end;
    _sections._gcRanges[1] = pbeg[0 .. pend - pbeg];
}

void finiSections()
{
    .free(cast(void*)_sections.modules.ptr);
}

void[] initTLSRanges()
{
    auto pbeg = cast(void*)&_tls_start;
    auto pend = cast(void*)&_tls_end;
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

extern(C)
{
    extern __gshared void* _minfo_beg;
    extern __gshared void* _minfo_end;
}

immutable(ModuleInfo*)[] getModuleInfos()
out (result)
{
    foreach(m; result)
        assert(m !is null);
}
body
{
    auto m = (cast(immutable(ModuleInfo*)*)&_minfo_beg)[1 .. &_minfo_end - &_minfo_beg];
    /* Because of alignment inserted by the linker, various null pointers
     * are there. We need to filter them out.
     */
    auto p = m.ptr;
    auto pend = m.ptr + m.length;

    // count non-null pointers
    size_t cnt;
    for (; p < pend; ++p)
    {
        if (*p !is null) ++cnt;
    }

    auto result = (cast(immutable(ModuleInfo)**).malloc(cnt * size_t.sizeof))[0 .. cnt];

    p = m.ptr;
    cnt = 0;
    for (; p < pend; ++p)
        if (*p !is null) result[cnt++] = *p;

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

        void* _data_beg;
        void* _data_end;

        void* _bss_beg;
        void* _bss_end;
    }

    extern
    {
        int _tls_start;
        int _tls_end;
    }
}
