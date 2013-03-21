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
import core.stdc.string, core.stdc.stdlib;
import core.sys.posix.pthread;
import core.sys.osx.mach.dyld;
import core.sys.osx.mach.getsect;
import rt.deh2, rt.minfo;
import rt.util.container;

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
    immutable(void)[][2] _tlsImage;
}

void initSections()
{
    pthread_key_create(&_tlsKey, null);
    _dyld_register_func_for_add_image(&sections_osx_onAddImage);
}

void finiSections()
{
    _sections._gcRanges.reset();
    pthread_key_delete(_tlsKey);
}

void[]* initTLSRanges()
{
    return &getTLSBlock();
}

void finiTLSRanges(void[]* rng)
{
    .free(rng.ptr);
    .free(rng);
}

void scanTLSRanges(void[]* rng, scope void delegate(void* pbeg, void* pend) dg)
{
    dg(rng.ptr, rng.ptr + rng.length);
}

// NOTE: The Mach-O object file format does not allow for thread local
//       storage declarations. So instead we roll our own by putting tls
//       into the __tls_data and the __tlscoal_nt sections.
//
//       This function is called by the code emitted by the compiler.  It
//       is expected to translate an address into the TLS static data to
//       the corresponding address in the TLS dynamic per-thread data.

// NB: the compiler mangles this function as '___tls_get_addr' even though it is extern(D)
extern(D) void* ___tls_get_addr( void* p )
{
    immutable off = tlsOffset(p);
    auto tls = getTLSBlockAlloc();
    assert(off < tls.length);
    return tls.ptr + off;
}

private:

__gshared pthread_key_t _tlsKey;

size_t tlsOffset(void* p)
in
{
    assert(_sections._tlsImage[0].ptr !is null ||
           _sections._tlsImage[1].ptr !is null);
}
body
{
    // NOTE: p is an address in the TLS static data emitted by the
    //       compiler.  If it isn't, something is disastrously wrong.
    immutable off0 = cast(size_t)(p - _sections._tlsImage[0].ptr);
    if (off0 < _sections._tlsImage[0].length)
    {
        return off0;
    }
    immutable off1 = cast(size_t)(p - _sections._tlsImage[1].ptr);
    if (off1 < _sections._tlsImage[1].length)
    {
        size_t sz = (_sections._tlsImage[0].length + 15) & ~cast(size_t)15;
        return sz + off1;
    }
    assert(0);
}

ref void[] getTLSBlock()
{
    auto pary = cast(void[]*)pthread_getspecific(_tlsKey);
    if (pary is null)
    {
        pary = cast(void[]*).calloc(1, (void[]).sizeof);
        if (pthread_setspecific(_tlsKey, pary) != 0)
        {
            import core.stdc.stdio;
            perror("pthread_setspecific failed with");
            assert(0);
        }
    }
    return *pary;
}

ref void[] getTLSBlockAlloc()
{
    auto pary = &getTLSBlock();
    if (!pary.length)
    {
        auto imgs = _sections._tlsImage;
        immutable sz0 = (imgs[0].length + 15) & ~cast(size_t)15;
        immutable sz2 = sz0 + imgs[1].length;
        auto p = .malloc(sz2);
        memcpy(p, imgs[0].ptr, imgs[0].length);
        memcpy(p + sz0, imgs[1].ptr, imgs[1].length);
        *pary = p[0 .. sz2];
    }
    return *pary;
}


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

    if (auto sect = getSection(h, slide, "__DATA", "__tls_data"))
    {
        // no support for multiple images yet
        _sections._tlsImage[0].ptr is null || assert(0);

        debug(PRINTF) printf("  tls_data %p %p\n", sect.ptr, sect.ptr + sect.length);
        _sections._tlsImage[0] = (cast(immutable(void)*)sect.ptr)[0 .. sect.length];
    }

    if (auto sect = getSection(h, slide, "__DATA", "__tlscoal_nt"))
    {
        // no support for multiple images yet
        _sections._tlsImage[1].ptr is null || assert(0);

        debug(PRINTF) printf("  tlscoal_nt %p %p\n", sect.ptr, sect.ptr + sect.length);
        _sections._tlsImage[1] = (cast(immutable(void)*)sect.ptr)[0 .. sect.length];
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
    if (header.magic == MH_MAGIC)
    {
        auto sect = getsectbynamefromheader(header,
                                            segmentName,
                                            sectionName);

        if (sect !is null && sect.size > 0)
        {
            auto addr = cast(size_t) sect.addr;
            auto size = cast(size_t) sect.size;
            return (cast(ubyte*) addr)[slide .. slide + size];
        }
        return null;

    }
    else if (header.magic == MH_MAGIC_64)
    {
        auto header64 = cast(mach_header_64*) header;
        auto sect     = getsectbynamefromheader_64(header64,
                                                   segmentName,
                                                   sectionName);

        if (sect !is null && sect.size > 0)
        {
            auto addr = cast(size_t) sect.addr;
            auto size = cast(size_t) sect.size;
            return (cast(ubyte*) addr)[slide .. slide + size];
        }
        return null;
    }
    else
        return null;
}
