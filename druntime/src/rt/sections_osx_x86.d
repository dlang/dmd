/**
 * Written in the D programming language.
 * This module provides OS X x86 specific support for sections.
 *
 * Copyright: Copyright Digital Mars 2008 - 2016.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors: Walter Bright, Sean Kelly, Martin Nowak, Jacob Carlborg
 * Source: $(DRUNTIMESRC rt/_sections_osx_x86.d)
 */
module rt.sections_osx_x86;

version (OSX)
    version = Darwin;
else version (iOS)
    version = Darwin;
else version (TVOS)
    version = Darwin;
else version (WatchOS)
    version = Darwin;

version (Darwin):
version (X86):

// debug = PRINTF;

import core.internal.container.array;
import core.stdc.stdint : intptr_t;
import core.stdc.stdio : fprintf, perror, stderr;
import core.stdc.stdlib : calloc, free, malloc;
import core.stdc.string : memcpy;
import core.sys.darwin.mach.dyld : _dyld_register_func_for_add_image;
import core.sys.darwin.mach.getsect : getsectbynamefromheader;
import core.sys.darwin.mach.loader : mach_header, MH_MAGIC, SECT_BSS, SECT_COMMON, SECT_DATA, SEG_DATA;
import core.sys.posix.pthread : pthread_getspecific, pthread_key_create, pthread_key_delete, pthread_key_t,
    pthread_setspecific;
import rt.deh;
import rt.minfo;

debug (PRINTF) import core.stdc.stdio : printf;

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

    @property immutable(ModuleInfo*)[] modules() const nothrow @nogc
    {
        return _moduleGroup.modules;
    }

    @property ref inout(ModuleGroup) moduleGroup() inout return nothrow @nogc
    {
        return _moduleGroup;
    }

    @property inout(void[])[] gcRanges() inout nothrow @nogc
    {
        return _gcRanges[];
    }

    @property immutable(FuncTable)[] ehTables() const nothrow @nogc
    {
        return _ehTables[];
    }

private:
    immutable(FuncTable)[] _ehTables;
    ModuleGroup _moduleGroup;
    Array!(void[]) _gcRanges;
    immutable(void)[][2] _tlsImage;
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
    pthread_key_create(&_tlsKey, null);
    _dyld_register_func_for_add_image(&sections_osx_onAddImage);
    _isRuntimeInitialized = true;
}

/***
 * Gets called on program shutdown just after GC is terminated.
 */
void finiSections() nothrow @nogc
{
    _sections._gcRanges.reset();
    pthread_key_delete(_tlsKey);
    _isRuntimeInitialized = false;
}

void[]* initTLSRanges() nothrow @nogc
{
    return &getTLSBlock();
}

void finiTLSRanges(void[]* rng) nothrow @nogc
{
    .free(rng.ptr);
    .free(rng);
}

void scanTLSRanges(void[]* rng, scope void delegate(void* pbeg, void* pend) nothrow dg) nothrow
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

extern(C) void* __tls_get_addr( void* p )
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
do
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

ref void[] getTLSBlock() nothrow @nogc
{
    auto pary = cast(void[]*)pthread_getspecific(_tlsKey);
    if (pary is null)
    {
        pary = cast(void[]*).calloc(1, (void[]).sizeof);
        if (pthread_setspecific(_tlsKey, pary) != 0)
        {
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

extern (C) void sections_osx_onAddImage(const scope mach_header* h, intptr_t slide)
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
            fprintf(stderr, "Loading shared libraries isn't yet supported on Darwin.\n");
            return;
        }
        else if (_sections.modules.ptr !is null)
        {
            fprintf(stderr, "Shared libraries are not yet supported on Darwin.\n");
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

    auto tlssect = getSection(h, slide, "__DATA", "__tls_data");
    if (tlssect != null)
    {
        debug(PRINTF) printf("  tls_data %p %p\n", tlssect.ptr, tlssect.ptr + tlssect.length);
        _sections._tlsImage[0] = (cast(immutable(void)*)tlssect.ptr)[0 .. tlssect.length];
    }

    auto tlssect2 = getSection(h, slide, "__DATA", "__tlscoal_nt");
    if (tlssect2 != null)
    {
        debug(PRINTF) printf("  tlscoal_nt %p %p\n", tlssect2.ptr, tlssect2.ptr + tlssect2.length);
        _sections._tlsImage[1] = (cast(immutable(void)*)tlssect2.ptr)[0 .. tlssect2.length];
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
    assert(header.magic == MH_MAGIC);
    auto sect = getsectbynamefromheader(header, segmentName, sectionName);

    if (sect !is null && sect.size > 0)
        return (cast(ubyte*)sect.addr + slide)[0 .. cast(size_t)sect.size];
    return null;
}
