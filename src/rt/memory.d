/**
 * This module tells the garbage collector about the static data and bss segments,
 * so the GC can scan them for roots. It does not deal with thread local static data.
 *
 * Copyright: Copyright Digital Mars 2000 - 2012.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Walter Bright, Sean Kelly
 * Source: $(DRUNTIMESRC src/rt/_memory.d)
 */

module rt.memory;


private
{
    extern (C) void gc_addRange( void* p, size_t sz );
    extern (C) void gc_removeRange( void* p );


    version( Win32 )
    {
        extern (C)
        {
            extern __gshared
            {
                int _xi_a;   // &_xi_a just happens to be start of data segment
                int _edata;  // &_edata is start of BSS segment
                int _end;    // &_end is past end of BSS
            }
        }
    }
    else version( Win64 )
    {
        extern (C)
        {
            extern __gshared
            {
                int __xc_a;      // &__xc_a just happens to be start of data segment
                //int _edata;    // &_edata is start of BSS segment
                void* _deh_beg;  // &_deh_beg is past end of BSS
            }
        }
    }
    else version( linux )
    {
        extern (C)
        {
            extern __gshared
            {
                int __data_start;
                int end;
            }
        }
    }
    else version( OSX )
    {
        extern (C) void _d_osx_image_init();
    }
    else version( FreeBSD )
    {
        extern (C)
        {
            extern __gshared
            {
                size_t etext;
                size_t _end;
            }
        }
        version (X86_64)
        {
            extern (C)
            {
                extern __gshared
                {
                    size_t _deh_end;
                    size_t __progname;
                }
            }
        }
    }
    else version( Solaris )
    {
        extern (C)
        {
            extern __gshared
            {
                int __dso_handle;
                int _end;
            }
        }
    }
}


void initStaticDataGC()
{
    version( Win32 )
    {
        gc_addRange( &_xi_a, cast(size_t) &_end - cast(size_t) &_xi_a );
    }
    else version( Win64 )
    {
        gc_addRange( &__xc_a, cast(size_t) &_deh_beg - cast(size_t) &__xc_a );
    }
    else version( linux )
    {
        gc_addRange( &__data_start, cast(size_t) &end - cast(size_t) &__data_start );
    }
    else version( OSX )
    {
        _d_osx_image_init();
    }
    else version( FreeBSD )
    {
        version (X86_64)
        {
            gc_addRange( &etext, cast(size_t) &_deh_end - cast(size_t) &etext );
            gc_addRange( &__progname, cast(size_t) &_end - cast(size_t) &__progname );
        }
        else
        {
            gc_addRange( &etext, cast(size_t) &_end - cast(size_t) &etext );
        }
    }
    else version( Solaris )
    {
        gc_addRange(&__dso_handle, cast(size_t)&_end - cast(size_t)&__dso_handle);
    }
    else
    {
        static assert( false, "Operating system not supported." );
    }
}
