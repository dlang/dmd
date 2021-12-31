/**
 * Portable routines for functions that have different implementations on different platforms.
 *
 * Copyright: Copyright (C) 1999-2022 by The D Language Foundation, All Rights Reserved
 * Authors:   Walter Bright, https://www.digitalmars.com
 * License:   $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/root/port.d, root/_port.d)
 * Documentation:  https://dlang.org/phobos/dmd_root_port.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/root/port.d
 */

module dmd.root.port;

import core.stdc.ctype;
import core.stdc.errno;
import core.stdc.string;
import core.stdc.stdint;
import core.stdc.stdio;
import core.stdc.stdlib;

nothrow @nogc:

private extern (C)
{
    version(CRuntime_DigitalMars) __gshared extern const(char)* __locale_decpoint;

    version(CRuntime_Microsoft)
    {
        enum _OVERFLOW  = 3;   /* overflow range error */
        enum _UNDERFLOW = 4;   /* underflow range error */

        int _atoflt(float*  value, const(char)* str);
        int _atodbl(double* value, const(char)* str);
    }
}

extern (C++) struct Port
{
    nothrow @nogc:

    static int memicmp(scope const char* s1, scope const char* s2, size_t n) pure
    {
        int result = 0;

        foreach (i; 0 .. n)
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

    static char* strupr(char* s) pure
    {
        char* t = s;

        while (*s)
        {
            *s = cast(char)toupper(*s);
            s++;
        }

        return t;
    }

    static bool isFloat32LiteralOutOfRange(scope const(char)* s)
    {
        errno = 0;
        version (CRuntime_DigitalMars)
        {
            auto save = __locale_decpoint;
            __locale_decpoint = ".";
        }
        version (CRuntime_Microsoft)
        {
            float r;
            int res = _atoflt(&r, s);
            if (res == _UNDERFLOW || res == _OVERFLOW)
                errno = ERANGE;
        }
        else
        {
            strtof(s, null);
        }
        version (CRuntime_DigitalMars) __locale_decpoint = save;
        return errno == ERANGE;
    }

    static bool isFloat64LiteralOutOfRange(scope const(char)* s)
    {
        errno = 0;
        version (CRuntime_DigitalMars)
        {
            auto save = __locale_decpoint;
            __locale_decpoint = ".";
        }
        version (CRuntime_Microsoft)
        {
            double r;
            int res = _atodbl(&r, s);
            if (res == _UNDERFLOW || res == _OVERFLOW)
                errno = ERANGE;
        }
        else
        {
            strtod(s, null);
        }
        version (CRuntime_DigitalMars) __locale_decpoint = save;
        return errno == ERANGE;
    }

    // Little endian
    static void writelongLE(uint value, scope void* buffer) pure
    {
        auto p = cast(ubyte*)buffer;
        p[3] = cast(ubyte)(value >> 24);
        p[2] = cast(ubyte)(value >> 16);
        p[1] = cast(ubyte)(value >> 8);
        p[0] = cast(ubyte)(value);
    }

    // Little endian
    static uint readlongLE(scope const void* buffer) pure
    {
        auto p = cast(const ubyte*)buffer;
        return (((((p[3] << 8) | p[2]) << 8) | p[1]) << 8) | p[0];
    }

    // Big endian
    static void writelongBE(uint value, scope void* buffer) pure
    {
        auto p = cast(ubyte*)buffer;
        p[0] = cast(ubyte)(value >> 24);
        p[1] = cast(ubyte)(value >> 16);
        p[2] = cast(ubyte)(value >> 8);
        p[3] = cast(ubyte)(value);
    }

    // Big endian
    static uint readlongBE(scope const void* buffer) pure
    {
        auto p = cast(const ubyte*)buffer;
        return (((((p[0] << 8) | p[1]) << 8) | p[2]) << 8) | p[3];
    }

    // Little endian
    static uint readwordLE(scope const void* buffer) pure
    {
        auto p = cast(const ubyte*)buffer;
        return (p[1] << 8) | p[0];
    }

    // Big endian
    static uint readwordBE(scope const void* buffer) pure
    {
        auto p = cast(const ubyte*)buffer;
        return (p[0] << 8) | p[1];
    }

    static void valcpy(scope void *dst, uint64_t val, size_t size) pure
    {
        assert((cast(size_t)dst) % size == 0);
        switch (size)
        {
            case 1: *cast(ubyte *)dst = cast(ubyte)val; break;
            case 2: *cast(ushort *)dst = cast(ushort)val; break;
            case 4: *cast(uint *)dst = cast(uint)val; break;
            case 8: *cast(ulong *)dst = cast(ulong)val; break;
            default: assert(0);
        }
    }
}
