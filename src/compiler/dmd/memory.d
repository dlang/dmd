/**
 * This module exposes functionality for inspecting and manipulating memory.
 *
 * Copyright: Copyright (C) 2005-2006 Digital Mars, www.digitalmars.com.
 *            All rights reserved.
 * License:
 *  This software is provided 'as-is', without any express or implied
 *  warranty. In no event will the authors be held liable for any damages
 *  arising from the use of this software.
 *
 *  Permission is granted to anyone to use this software for any purpose,
 *  including commercial applications, and to alter it and redistribute it
 *  freely, in both source and binary form, subject to the following
 *  restrictions:
 *
 *  o  The origin of this software must not be misrepresented; you must not
 *     claim that you wrote the original software. If you use this software
 *     in a product, an acknowledgment in the product documentation would be
 *     appreciated but is not required.
 *  o  Altered source versions must be plainly marked as such, and must not
 *     be misrepresented as being the original software.
 *  o  This notice may not be removed or altered from any source
 *     distribution.
 * Authors:   Walter Bright, Sean Kelly
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

    alias void delegate( void*, void* ) scanFn;
}


/**
 *
 */
extern (C) void rt_scanStaticData( scanFn scan )
{
    version( Windows )
    {
        scan( &_xi_a, &_end );
    }
    else version( linux )
    {
        scan( &__data_start, &_end );
    }
    else
    {
        static assert( false, "Operating system not supported." );
    }
}
