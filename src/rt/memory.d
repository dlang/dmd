/**
 * This module exposes functionality for inspecting and manipulating memory.
 *
 * Copyright: Copyright Digital Mars 2000 - 2010.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Walter Bright, Sean Kelly
 */

/*          Copyright Digital Mars 2000 - 2010.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.memory;


private
{
    version( GNU )
    {
        import gcc.builtins;
    }
    version( linux )
    {
        version = SimpleLibcStackEnd;

        version( SimpleLibcStackEnd )
        {
            extern (C) extern __gshared void* __libc_stack_end;
        }
    }
    version( FreeBSD )
    {
        extern (C) int sysctlbyname( const(char)*, void*, size_t*, void*, size_t );
    }
    version( Solaris )
    {
        version = SimpleLibcStackEnd;

        version( SimpleLibcStackEnd )
        {
            extern (C) extern __gshared void* __libc_stack_end;
        }
    }
    version( OSX )
    {
        import core.sys.osx.pthread;
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
        version( D_InlineAsm_X86 )
        {
            asm
            {
                naked;
                mov EAX,FS:4;
                ret;
            }
        }
        else version( D_InlineAsm_X86_64 )
        {
            static assert( false, "is this right?" );
            asm
            {
                naked;
                mov RAX,FS:8;
                ret;
            }
        }
        else
        {
            static assert( false, "Platform not supported." );
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
        return pthread_get_stackaddr_np(pthread_self());
    }
    else version( FreeBSD )
    {
        static void* kern_usrstack;

        if( kern_usrstack == kern_usrstack.init )
        {
            size_t len = kern_usrstack.sizeof;
            sysctlbyname( "kern.usrstack", &kern_usrstack, &len, null, 0 );
        }
        return kern_usrstack;
    }
    else version( Solaris )
    {
        return __libc_stack_end;
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
    else version( D_InlineAsm_X86_64 )
    {
        asm
        {
            naked;
            mov RAX, RSP;
            ret;
        }
    }
    else version( GNU )
    {
        return __builtin_frame_address(0);
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
