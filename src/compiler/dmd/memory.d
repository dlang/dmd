/**
 * This module exposes functionality for inspecting and manipulating memory.
 *
 * Copyright: Copyright Digital Mars 2000 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt>Boost License 1.0</a>.
 * Authors:   Walter Bright, Sean Kelly
 *
 *          Copyright Digital Mars 2000 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.memory;


private
{
    version( linux )
    {
        version = SimpleLibcStackEnd;

        version( SimpleLibcStackEnd )
        {
            extern (C) extern void* __libc_stack_end;
        }
    }
    extern (C) void gc_addRange( void* p, size_t sz );
    extern (C) void gc_removeRange( void* p );
}


/**
 *
 */
extern (C) void* rt_stackBottom()
{
    version( Windows )
    {
        asm
        {
            naked;
            mov EAX,FS:4;
            ret;
        }
    }
    else version( linux )
    {
        version( SimpleLibcStackEnd )
        {
            return __libc_stack_end;
        }
        else
        {
            // See discussion: http://autopackage.org/forums/viewtopic.php?t=22
            static void** libc_stack_end;

            if( libc_stack_end == libc_stack_end.init )
            {
                void* handle = dlopen( null, RTLD_NOW );
                libc_stack_end = cast(void**) dlsym( handle, "__libc_stack_end" );
                dlclose( handle );
            }
            return *libc_stack_end;
        }
    }
    else version( OSX )
    {
        return cast(void*) 0xc0000000;
    }
    else
    {
        static assert( false, "Operating system not supported." );
    }
}


/**
 *
 */
extern (C) void* rt_stackTop()
{
    version( D_InlineAsm_X86 )
    {
        asm
        {
            naked;
            mov EAX, ESP;
            ret;
        }
    }
    else
    {
        static assert( false, "Architecture not supported." );
    }
}


private
{
    version( Windows )
    {
        extern (C)
        {
            extern int _xi_a;   // &_xi_a just happens to be start of data segment
            extern int _edata;  // &_edata is start of BSS segment
            extern int _end;    // &_end is past end of BSS
        }
    }
    else version( linux )
    {
        extern (C)
        {
            extern int _data;
            extern int __data_start;
            extern int _end;
            extern int _data_start__;
            extern int _data_end__;
            extern int _bss_start__;
            extern int _bss_end__;
            extern int __fini_array_end;
        }

            alias __data_start  Data_Start;
            alias _end          Data_End;
    }
    else version( OSX )
    {
        extern (C) void _d_osx_image_init();
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
    else
    {
        static assert( false, "Operating system not supported." );
    }
}
