/**
 * Compiler implementation of the D programming language
 * http://dlang.org
 *
 * Copyright: Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:   Walter Bright, http://www.digitalmars.com
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(DMDSRC root/_port.d)
 */

module ddmd.root.port;

import core.stdc.ctype;
import core.stdc.errno;
import core.stdc.string;
import core.stdc.stdio;
import core.stdc.stdlib;

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

    static bool isFloat32LiteralOutOfRange(const(char)* s)
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

    static bool isFloat64LiteralOutOfRange(const(char)* s)
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

    static void valcpy(void *dst, ulong val, size_t size)
    {
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
