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
import src.core.sys.osx.mach.dyld;
import src.core.sys.osx.mach.getsect;

extern (C) extern __gshared ubyte[][2] _tls_data_array;

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

extern (C) void _d_osx_image_init()
{
}

/*********************************
 * The following is done separately because it must be done before Thread gets initialized.
 */

extern (C) void onAddImage2(in mach_header* h, intptr_t slide)
{
    //printf("onAddImage2()\n");

    if (auto sect = getSection(h, slide, "__DATA", "__tls_data"))
    {
        //printf("  tls_data %p %p\n", &sect[0], &sect[length]);
        /* BUG: this will fail if there are multiple images with __tls_data
         * sections. Not set up to handle that.
         */
        if (!_tls_data_array[0].ptr)
            _tls_data_array[0] = sect.ptr[0 .. sect.length];
    }

    if (auto sect = getSection(h, slide, "__DATA", "__tlscoal_nt"))
    {
        //printf("  tlscoal_nt %p %p\n", &sect[0], &sect[length]);
        /* BUG: this will fail if there are multiple images with __tlscoal_nt
         * sections. Not set up to handle that.
         */
        if (!_tls_data_array[1].ptr)
            _tls_data_array[1] = sect.ptr[0 .. sect.length];
    }
}


extern (C) void onRemoveImage2(in mach_header* h, intptr_t slide)
{
    //printf("onRemoveImage2()\n");
}


extern (C) void _d_osx_image_init2()
{
    //printf("_d_osx_image_init2()\n");
    _dyld_register_func_for_add_image( &onAddImage2 );
    _dyld_register_func_for_remove_image( &onRemoveImage2 );
}

