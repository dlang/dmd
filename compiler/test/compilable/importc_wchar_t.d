// EXTRA_SOURCES: imports/importc_wchar_t_c.c

import importc_wchar_t_c;

version (Windows)
{
    /+ On Windows, we expect C's `wchar_t` to be D's `wchar`. +/

    static assert(is(typeof(wchar_t_aggregate.w) == wchar));

    alias Func = extern(C) void function(const(wchar)* str);

    Func wcharT()
    {
        wchar c = 0;
        wchar_t_aggregate w = wchar_t_aggregate('W');
        w.p = &c;

        accept_wchar_t_string("Hello, World!");
        accept_wchar_t_string("Hello, World!"w.ptr);
        accept_wchar_t_string(&w.w);
        accept_wchar_t_string(w.p);

        static if (__traits(hasMember, importc_wchar_t_c, "accept_msvc___wchar_t_string"))
        {
            accept_msvc___wchar_t_string("Hello, World!");
            accept_msvc___wchar_t_string("Hello, World!"w.ptr);
            accept_msvc___wchar_t_string(&w.w);
        }

        return &accept_wchar_t_string;
    }
}
else
{
    /+ On non-Windows platforms, we expect C's `wchar_t` to be whatever `<stddef.h>` defined it as. +/

    alias WCharT = typeof(wchar_t_aggregate.w);
    static assert(__traits(isScalar, WCharT));

    alias Func = extern(C) void function(const(WCharT)* str);

    Func wcharT()
    {
        WCharT c = 0;
        wchar_t_aggregate w = wchar_t_aggregate('W');
        w.p = &c;

        accept_wchar_t_string(&w.w);
        accept_wchar_t_string(w.p);

        static if (WCharT.sizeof == 4)
        {
            accept_wchar_t_string(cast(const(WCharT)*) "Hello, World!"d.ptr);
        }
        else static if (WCharT.sizeof == 2)
        {
            accept_wchar_t_string(cast(const(WCharT)*) "Hello, World!"w.ptr);
        }
        else static if (WCharT.sizeof == 1)
        {
            accept_wchar_t_string(cast(const(WCharT)*) "Hello, World!".ptr);
        }

        return &accept_wchar_t_string;
    }
}
