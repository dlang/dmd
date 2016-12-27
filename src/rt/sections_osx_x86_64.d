/**
 * Written in the D programming language.
 * This module provides OS X x86-64 specific support for sections.
 *
 * Copyright: Copyright Digital Mars 2016.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors: Walter Bright, Sean Kelly, Martin Nowak, Jacob Carlborg
 * Source: $(DRUNTIMESRC src/rt/_sections_osx_x86_64.d)
 */
module rt.sections_osx_x86_64;

version (OSX)
    version = Darwin;
else version (iOS)
    version = Darwin;
else version (TVOS)
    version = Darwin;
else version (WatchOS)
    version = Darwin;

version(Darwin):
version(X86_64):

// debug = PRINTF;
import core.stdc.stdio;
import core.stdc.string, core.stdc.stdlib;
import core.sys.posix.pthread;
import core.sys.osx.mach.dyld;
import core.sys.osx.mach.getsect;
import rt.deh, rt.minfo;
import rt.util.container.array;

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

/****
 * Boolean flag set to true while the runtime is initialized.
 */
__gshared bool _isRuntimeInitialized;

/****
 * Gets called on program startup just before GC is initialized.
 */
void initSections() nothrow @nogc
{
    _dyld_register_func_for_add_image(&sections_osx_onAddImage);
    _isRuntimeInitialized = true;
}

/***
 * Gets called on program shutdown just after GC is terminated.
 */
void finiSections() nothrow @nogc
{
    _sections._gcRanges.reset();
    _isRuntimeInitialized = false;
}

void[] initTLSRanges() nothrow @nogc
{
    void* start = null;
    size_t size = 0;
    _d_dyld_getTLSRange(&dummyTlsSymbol, &start, &size);
    assert(start && size, "Could not determine TLS range.");
    return start[0 .. size];
}

void finiTLSRanges(void[] rng) nothrow @nogc
{

}

void scanTLSRanges(void[] rng, scope void delegate(void* pbeg, void* pend) nothrow dg) nothrow
{
    dg(rng.ptr, rng.ptr + rng.length);
}

private:

extern(C) void _d_dyld_getTLSRange(void*, void**, size_t*) nothrow @nogc;

__gshared SectionGroup _sections;
ubyte dummyTlsSymbol;

extern (C) void sections_osx_onAddImage(in mach_header* h, intptr_t slide)
{
    foreach (e; dataSegs)
    {
        auto sect = getSection(h, slide, e.seg.ptr, e.sect.ptr);
        if (sect != null)
            _sections._gcRanges.insertBack((cast(void*)sect.ptr)[0 .. sect.length]);
    }

    auto minfosect = getSection(h, slide, "__DATA", "__minfodata");
    if (minfosect != null)
    {
        // no support for multiple images yet
        // take the sections from the last static image which is the executable
        if (_isRuntimeInitialized)
        {
            fprintf(stderr, "Loading shared libraries isn't yet supported on OSX.\n");
            return;
        }
        else if (_sections.modules.ptr !is null)
        {
            fprintf(stderr, "Shared libraries are not yet supported on OSX.\n");
        }

        debug(PRINTF) printf("  minfodata\n");
        auto p = cast(immutable(ModuleInfo*)*)minfosect.ptr;
        immutable len = minfosect.length / (*p).sizeof;

        _sections._moduleGroup = ModuleGroup(p[0 .. len]);
    }

    auto ehsect = getSection(h, slide, "__DATA", "__deh_eh");
    if (ehsect != null)
    {
        debug(PRINTF) printf("  deh_eh\n");
        auto p = cast(immutable(FuncTable)*)ehsect.ptr;
        immutable len = ehsect.length / (*p).sizeof;

        _sections._ehTables = p[0 .. len];
    }
}

struct SegRef
{
    string seg;
    string sect;
}

static immutable SegRef[] dataSegs = [{SEG_DATA, SECT_DATA},
                                      {SEG_DATA, SECT_BSS},
                                      {SEG_DATA, SECT_COMMON}];

ubyte[] getSection(in mach_header* header, intptr_t slide,
                   in char* segmentName, in char* sectionName)
{
    assert(header.magic == MH_MAGIC_64);
    auto sect = getsectbynamefromheader_64(cast(mach_header_64*)header,
                                        segmentName,
                                        sectionName);

    if (sect !is null && sect.size > 0)
        return (cast(ubyte*)sect.addr + slide)[0 .. cast(size_t)sect.size];
    return null;
}
