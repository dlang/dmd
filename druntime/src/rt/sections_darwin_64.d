/**
 * Written in the D programming language.
 * This module provides Darwin 64 bit specific support for sections.
 *
 * Copyright: Copyright Digital Mars 2016.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors: Jacob Carlborg
 * Source: $(DRUNTIMESRC rt/_sections_darwin_64.d)
 */
module rt.sections_darwin_64;

version (OSX)
    version = Darwin;
else version (iOS)
    version = Darwin;
else version (TVOS)
    version = Darwin;
else version (WatchOS)
    version = Darwin;

version (Darwin):
version (D_LP64):

import core.sys.darwin.mach.dyld;
import core.sys.darwin.mach.getsect;
import core.sys.posix.pthread;

import rt.util.utility : safeAssert;

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

/// Invokes the specified delegate for each (non-empty) data section.
void foreachDataSection(in mach_header* header, intptr_t slide,
                        scope void delegate(void[] sectionData) processor)
{
    foreach (section; [ SECT_DATA, SECT_BSS, SECT_COMMON ])
    {
        auto data = getSection(header, slide, SEG_DATA.ptr, section.ptr);
        if (data !is null)
            processor(data);
    }
}

/// Returns a section's memory range, or null if not found or empty.
void[] getSection(in mach_header* header, intptr_t slide,
                  in char* segmentName, in char* sectionName)
{
    safeAssert(header.magic == MH_MAGIC_64, "Unsupported header.");
    auto sect = getsectbynamefromheader_64(cast(mach_header_64*) header,
                                           segmentName, sectionName);

    if (sect !is null && sect.size > 0)
        return (cast(void*)sect.addr + slide)[0 .. cast(size_t) sect.size];
    return null;
}
