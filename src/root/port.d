// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.root.port;

import core.stdc.ctype;
import core.stdc.string;
import core.math;

version(CRuntime_DigitalMars) __gshared extern (C) extern const(char)* __locale_decpoint;
version(CRuntime_Microsoft)   extern(C++) struct longdouble { real r; }

extern (C) float strtof(const(char)* p, char** endp);
extern (C) double strtod(const(char)* p, char** endp);

version(CRuntime_Microsoft)
    extern (C++) longdouble strtold_dm(const(char)* p, char** endp);
else
    extern (C) real strtold(const(char)* p, char** endp);

extern (C++) struct Port
{
    enum nan = double.nan;
    enum infinity = double.infinity;
    enum ldbl_max = real.max;
    enum ldbl_nan = real.nan;
    enum ldbl_infinity = real.infinity;
    version(DigitalMars)
    {
        static __gshared bool yl2x_supported = true;
        static __gshared bool yl2xp1_supported = true;
    }
    else
    {
        static __gshared bool yl2x_supported = false;
        static __gshared bool yl2xp1_supported = false;
    }
    static __gshared real snan;
    static this()
    {
        /*
         * Use a payload which is different from the machine NaN,
         * so that uninitialised variables can be
         * detected even if exceptions are disabled.
         */
        ushort* us = cast(ushort*)&snan;
        us[0] = 0;
        us[1] = 0;
        us[2] = 0;
        us[3] = 0xA000;
        us[4] = 0x7FFF;
    }

    static bool isNan(double r)
    {
        return !(r == r);
    }

    static real sqrt(real x)
    {
        return .sqrt(x);
    }

    static real fmodl(real a, real b)
    {
        return a % b;
    }

    static real fequal(real a, real b)
    {
        return memcmp(&a, &b, 10) == 0;
    }

    static int memicmp(const char* s1, const char* s2, size_t n)
    {
        int result = 0;

        for (int i = 0; i < n; i++)
        {
            char c1 = s1[i];
            char c2 = s2[i];

            result = c1 - c2;
            if (result)
            {
                result = toupper(c1) - toupper(c2);
                if (result)
                    break;
            }
        }
        return result;
    }

    static char* strupr(char* s)
    {
        char* t = s;

        while (*s)
        {
            *s = cast(char)toupper(*s);
            s++;
        }

        return t;
    }

    static int isSignallingNan(double r)
    {
        return isNan(r) && !(((cast(ubyte*)&r)[6]) & 8);
    }

    static int isSignallingNan(real r)
    {
        return isNan(r) && !(((cast(ubyte*)&r)[7]) & 0x40);
    }

    version(CRuntime_Microsoft)
    {
        static int isSignallingNan(longdouble ld)
        {
            return isSignallingNan(*cast(real*)&ld);
        }
    }

    static int isInfinity(double r)
    {
        return r is double.infinity || r is -double.infinity;
    }

    static float strtof(const(char)* p, char** endp)
    {
        version (CRuntime_DigitalMars)
        {
            auto save = __locale_decpoint;
            __locale_decpoint = ".";
        }
        auto r = .strtof(p, endp);
        version (CRuntime_DigitalMars) __locale_decpoint = save;
        return r;
    }

    static double strtod(const(char)* p, char** endp)
    {
        version (CRuntime_DigitalMars)
        {
            auto save = __locale_decpoint;
            __locale_decpoint = ".";
        }
        auto r = .strtod(p, endp);
        version (CRuntime_DigitalMars) __locale_decpoint = save;
        return r;
    }

    static real strtold(const(char)* p, char** endp)
    {
        version (CRuntime_DigitalMars)
        {
            auto save = __locale_decpoint;
            __locale_decpoint = ".";
        }

        version (CRuntime_Microsoft)
            auto r = .strtold_dm(p, endp).r;
        else
            auto r = .strtold(p, endp);
        version (CRuntime_DigitalMars) __locale_decpoint = save;
        return r;
    }

    static void yl2x_impl(real* x, real* y, real* res)
    {
        version(DigitalMars)
            *res = yl2x(*x, *y);
    }

    static void yl2xp1_impl(real* x, real* y, real* res)
    {
        version(DigitalMars)
            *res = yl2xp1(*x, *y);
    }

    // Little endian
    static void writelongLE(uint value, void* buffer)
    {
        auto p = cast(ubyte*)buffer;
        p[3] = cast(ubyte)(value >> 24);
        p[2] = cast(ubyte)(value >> 16);
        p[1] = cast(ubyte)(value >> 8);
        p[0] = cast(ubyte)(value);
    }

    // Little endian
    static uint readlongLE(void* buffer)
    {
        auto p = cast(ubyte*)buffer;
        return (((((p[3] << 8) | p[2]) << 8) | p[1]) << 8) | p[0];
    }

    // Big endian
    static void writelongBE(uint value, void* buffer)
    {
        auto p = cast(ubyte*)buffer;
        p[0] = cast(ubyte)(value >> 24);
        p[1] = cast(ubyte)(value >> 16);
        p[2] = cast(ubyte)(value >> 8);
        p[3] = cast(ubyte)(value);
    }

    // Big endian
    static uint readlongBE(void* buffer)
    {
        auto p = cast(ubyte*)buffer;
        return (((((p[0] << 8) | p[1]) << 8) | p[2]) << 8) | p[3];
    }

    // Little endian
    static uint readwordLE(void* buffer)
    {
        auto p = cast(ubyte*)buffer;
        return (p[1] << 8) | p[0];
    }

    // Big endian
    static uint readwordBE(void* buffer)
    {
        auto p = cast(ubyte*)buffer;
        return (p[0] << 8) | p[1];
    }
}
