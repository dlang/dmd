// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.root.longdouble;

import core.stdc.stdio;

real ldouble(T)(T x)
{
    return cast(real)x;
}

size_t ld_sprint(char* str, int fmt, real x)
{
    if ((cast(real)cast(ulong)x) == x)
    {
        // ((1.5 -> 1 -> 1.0) == 1.5) is false
        // ((1.0 -> 1 -> 1.0) == 1.0) is true
        // see http://en.cppreference.com/w/cpp/io/c/fprintf
        char[5] sfmt = "%#Lg\0";
        sfmt[3] = cast(char)fmt;
        return sprintf(str, sfmt.ptr, x);
    }
    else
    {
        char[4] sfmt = "%Lg\0";
        sfmt[2] = cast(char)fmt;
        return sprintf(str, sfmt.ptr, x);
    }
}
