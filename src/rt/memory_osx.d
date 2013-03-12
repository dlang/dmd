/**
 * Written in the D programming language.
 * This module provides OSX-specific support routines for memory.d.
 *
 * Copyright: Copyright Digital Mars 2008 - 2012.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Walter Bright, Sean Kelly
 * Source: $(DRUNTIMESRC src/rt/_memory_osx.d)
 */

module rt.memory_osx;

version(OSX):

//import core.stdc.stdio;   // printf
import core.sys.osx.mach.dyld;
import core.sys.osx.mach.getsect;

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
