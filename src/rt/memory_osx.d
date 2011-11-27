/**
 * This module provides OSX-specific support routines for memory.d.
 *
 * Copyright: Copyright Digital Mars 2008 - 2010.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Walter Bright, Sean Kelly
 */

/*          Copyright Digital Mars 2008 - 2010.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.memory_osx;

version(OSX):

import src.core.sys.osx.mach.dyld;
import src.core.sys.osx.mach.getsect;

extern (C) void gc_addRange( void* p, size_t sz );
extern (C) void gc_removeRange( void* p );


struct SegRef
{
    string seg;
    string sect;
}


enum SegRef[5] dataSegs = [{SEG_DATA, SECT_DATA},
                           {SEG_DATA, SECT_BSS},
                           {SEG_DATA, SECT_COMMON},
				           // These two must match names used by compiler machobj.c
                           {SEG_DATA, "__tls_data"},
                           {SEG_DATA, "__tlscoal_nt"}];


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


extern (C) void onAddImage(in mach_header* h, intptr_t slide)
{
    foreach(i, e; dataSegs)
    {
        if (auto sect = getSection(h, slide, e.seg.ptr, e.sect.ptr))
            gc_addRange(sect.ptr, sect.length);
    }
}


extern (C) void onRemoveImage(in mach_header* h, intptr_t slide)
{
    foreach(i, e; dataSegs)
    {
        if (auto sect = getSection(h, slide, e.seg.ptr, e.sect.ptr))
            gc_removeRange(sect.ptr);
    }
}


extern (C) void _d_osx_image_init()
{
    _dyld_register_func_for_add_image( &onAddImage );
    _dyld_register_func_for_remove_image( &onRemoveImage );
}
