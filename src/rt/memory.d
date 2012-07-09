/**
 * This module exposes functionality for inspecting and manipulating memory.
 *
 * Copyright: Copyright Digital Mars 2000 - 2010.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Walter Bright, Sean Kelly
 */

/*          Copyright Digital Mars 2000 - 2010.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.memory;


private
{
    extern (C) void gc_addRange( void* p, size_t sz );
    extern (C) void gc_removeRange( void* p );


    version( Windows )
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
    else version( linux )
    {
        extern (C)
        {
            extern __gshared
            {
                int _data;
                int __data_start;
                int _end;
                int _data_start__;
                int _data_end__;
                int _bss_start__;
                int _bss_end__;
                int __fini_array_end;
            }
        }

            alias __data_start  Data_Start;
            alias _end          Data_End;
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
                int etext;
                int _end;
            }
        }
    }
}


void initStaticDataGC()
{
    version( Windows )
    {
        gc_addRange( &_xi_a, cast(size_t) &_end - cast(size_t) &_xi_a );
    }
    else version( linux )
    {
        gc_addRange( &__data_start, cast(size_t) &_end - cast(size_t) &__data_start );
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
        gc_addRange( &etext, cast(size_t) &_end - cast(size_t) &etext );
    }
    else
    {
        static assert( false, "Operating system not supported." );
    }
}
