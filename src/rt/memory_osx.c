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
#ifdef __APPLE__


#include <mach-o/dyld.h>
#include <mach-o/getsect.h>

void gc_addRange( void* p, size_t sz );
void gc_removeRange( void* p );

typedef struct
{
    const char* seg;
    const char* sect;
} seg_ref;

const static seg_ref data_segs[] = {{SEG_DATA, SECT_DATA},
                                    {SEG_DATA, SECT_BSS},
                                    {SEG_DATA, SECT_COMMON},
                                    // These two must match names used by compiler machobj.c
                                    {SEG_DATA, "__tls_data"},
                                    {SEG_DATA, "__tlscoal_nt"},
                                   };
const static int NUM_DATA_SEGS   = sizeof(data_segs) / sizeof(seg_ref);


static void on_add_image( const struct mach_header* h, intptr_t slide )
{
    int i;

    for( i = 0; i < NUM_DATA_SEGS; ++i )
    {
        const struct section* sect = getsectbynamefromheader( h,
                                        data_segs[i].seg,
                                        data_segs[i].sect );
        if( sect == NULL || sect->size == 0 )
            continue;
        gc_addRange( (void*) sect->addr + slide, sect->size );
    }
}


static void on_remove_image( const struct mach_header* h, intptr_t slide )
{
    int i;

    for( i = 0; i < NUM_DATA_SEGS; ++i )
    {
        const struct section* sect = getsectbynamefromheader( h,
                                        data_segs[i].seg,
                                        data_segs[i].sect );
        if( sect == NULL || sect->size == 0 )
            continue;
        gc_removeRange( (void*) sect->addr + slide );
    }
}


void _d_osx_image_init()
{
    _dyld_register_func_for_add_image( &on_add_image );
    _dyld_register_func_for_remove_image( &on_remove_image );
}


#endif
