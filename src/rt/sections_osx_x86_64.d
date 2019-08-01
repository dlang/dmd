/**
 * Written in the D programming language.
 * This module provides OS X x86-64 specific support for sections.
 *
 * Copyright: Copyright Digital Mars 2016.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors: Walter Bright, Sean Kelly, Martin Nowak, Jacob Carlborg
 * Source: $(DRUNTIMESRC rt/_sections_osx_x86_64.d)
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

version (Darwin):
version (X86_64):

// debug = PRINTF;
import core.stdc.stdio;
import core.stdc.string, core.stdc.stdlib;
import core.sys.posix.pthread;
import core.sys.darwin.mach.dyld;
import core.sys.darwin.mach.getsect;

import rt.deh, rt.minfo;
import rt.util.container.array;
import rt.util.utility : safeAssert;

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

    @property ref inout(ModuleGroup) moduleGroup() inout nothrow @nogc
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
    static ubyte tlsAnchor;

    auto range = getTLSRange(&tlsAnchor);
    safeAssert(range !is null, "Could not determine TLS range.");
    return range;
}

void finiTLSRanges(void[] rng) nothrow @nogc
{

}

void scanTLSRanges(void[] rng, scope void delegate(void* pbeg, void* pend) nothrow dg) nothrow
{
    dg(rng.ptr, rng.ptr + rng.length);
}

private:

__gshared SectionGroup _sections;

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
    safeAssert(header.magic == MH_MAGIC_64, "Unsupported header.");
    auto sect = getsectbynamefromheader_64(cast(mach_header_64*)header,
                                        segmentName,
                                        sectionName);

    if (sect !is null && sect.size > 0)
        return (cast(ubyte*)sect.addr + slide)[0 .. cast(size_t)sect.size];
    return null;
}

extern (C) size_t malloc_size(const void* ptr) nothrow @nogc;

/**
 * Returns the TLS range of the image containing the specified TLS symbol,
 * or null if none was found.
 */
void[] getTLSRange(const void* tlsSymbol) nothrow @nogc
{
    foreach (i ; 0 .. _dyld_image_count)
    {
        const header = cast(const(mach_header_64)*) _dyld_get_image_header(i);
        auto tlvInfo = tlvInfo(header);

        if (tlvInfo.foundTLSRange(tlsSymbol))
            return tlvInfo.tlv_addr[0 .. tlvInfo.tlv_size];
    }

    return null;
}

/**
 * Returns `true` if the correct TLS range was found.
 *
 * If the given `info` is located in the same image as the given `tlsSymbol`
 * this will return `true`.
 *
 * Params:
 *  info = the TLV info containing the TLV base address
 *  tlsSymbol = the TLS symbol to search for
 *
 * Returns: `true` if the correct TLS range was found
 */
bool foundTLSRange(const ref dyld_tlv_info info, const void* tlsSymbol) pure nothrow @nogc
{
    return info.tlv_addr <= tlsSymbol &&
        tlsSymbol < (info.tlv_addr + info.tlv_size);
}


/// TLV info.
struct dyld_tlv_info
{
    /// sizeof(dyld_tlv_info)
    size_t info_size;

    /// Base address of TLV storage
    void* tlv_addr;

    /// Byte size of TLV storage
    size_t tlv_size;
}

/**
 * Returns the TLV info for the given image.
 *
 * Params:
 *  header = the image to look for the TLV info in
 *
 * Returns: the TLV info
 */
dyld_tlv_info tlvInfo(const mach_header_64* header) nothrow @nogc
{
    const key = header.firstTLVKey;
    auto tlvAddress = key == pthread_key_t.max ? null : pthread_getspecific(key);

    dyld_tlv_info info = {
        info_size: dyld_tlv_info.sizeof,
        tlv_addr: tlvAddress,
        tlv_size: tlvAddress ? malloc_size(tlvAddress) : 0
    };

    return info;
}

/**
 * Returns the first TLV key for the given image.
 *
 * The TLV key is a key that associates a value of type `dyld_tlv_info` with a
 * thread. Each thread local variable has an associates TLV key. The TLV keys
 * are all the same for each image.
 *
 * Params:
 *  header = the image to look for the TLV key in
 *
 * Returns: the first TLV key for the given image or `pthread_key_t.max` if no
 *  key was found.
 */
pthread_key_t firstTLVKey(const mach_header_64* header) pure nothrow @nogc
{
    intptr_t slide = 0;
    bool slideComputed = false;
    const size = mach_header_64.sizeof;
    auto command = cast(const(load_command)*)(cast(ubyte*) header + size);

    foreach (_; 0 .. header.ncmds)
    {
        if (command.cmd == LC_SEGMENT_64)
        {
            auto segment = cast(const segment_command_64*) command;

            if (!slideComputed && segment.filesize != 0)
            {
                slide = cast(uintptr_t) header - segment.vmaddr;
                slideComputed = true;
            }

            foreach (const ref section; segment.sections)
            {
                if ((section.flags & SECTION_TYPE) != S_THREAD_LOCAL_VARIABLES)
                    continue;

                return section.firstTLVDescriptor(slide).key;
            }
        }

        command = cast(const(load_command)*)(cast(ubyte*) command + command.cmdsize);
    }

    return pthread_key_t.max;
}

/**
 * Returns the first TLV descriptor of the given section.
 *
 * Params:
 *  section = the section to get the TLV descriptor from
 *  slide = the slide
 *
 * Returns: the TLV descriptor
 */
const(tlv_descriptor)* firstTLVDescriptor(const ref section_64 section, intptr_t slide) pure nothrow @nogc
{
    return cast(const(tlv_descriptor)*)(section.addr + slide);
}

/**
 * Returns the sections of the given segment.
 *
 * Params:
 *  segment = the segment to get the sections from
 *
 * Returns: the sections.
 */
const(section_64)[] sections(const segment_command_64* segment) pure nothrow @nogc
{
    const size = segment_command_64.sizeof;
    const firstSection = cast(const(section_64)*)(cast(ubyte*) segment + size);
    return firstSection[0 .. segment.nsects];
}
