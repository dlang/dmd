/**
 * Support for 64-bit longs.
 *
 * Copyright: Copyright Digital Mars 2000 - 2012.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Walter Bright, Sean Kelly
 * Source: $(DRUNTIMESRC rt/_llmath.d)
 */

module rt.llmath;

extern (C):

void __ULDIV2__()
{
        assert(0);
}

void __ULDIV__()
{
        assert(0);
}

void __LDIV2__()
{
        assert(0);
}

void __LDIV__()
{
        assert(0);
}


version (Win32) version (CRuntime_Microsoft)
{
    extern(C) void _alldiv();
    extern(C) void _aulldiv();
    extern(C) void _allrem();
    extern(C) void _aullrem();

    void _ms_alldiv()
    {
        asm
        {
            naked            ;
            push ECX         ;
            push EBX         ;
            push EDX         ;
            push EAX         ;
            call _alldiv     ;
            ret              ;
        }
    }

    void _ms_aulldiv()
    {
        asm
        {
            naked            ;
            push ECX         ;
            push EBX         ;
            push EDX         ;
            push EAX         ;
            call _aulldiv    ;
            ret              ;
        }
    }

    void _ms_allrem()
    {
        asm
        {
            naked            ;
            push ECX         ;
            push EBX         ;
            push EDX         ;
            push EAX         ;
            call _allrem     ;
            mov EBX,EAX      ;
            mov ECX,EDX      ;
            ret              ;
        }
    }

    void _ms_aullrem()
    {
        asm
        {
            naked            ;
            push ECX         ;
            push EBX         ;
            push EDX         ;
            push EAX         ;
            call _aullrem    ;
            mov EBX,EAX      ;
            mov ECX,EDX      ;
            ret              ;
        }
    }
}
