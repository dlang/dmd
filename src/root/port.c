
/* Copyright (C) 1999-2021 by The D Language Foundation, All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * (See accompanying file LICENSE or copy at http://www.boost.org/LICENSE_1_0.txt)
 * https://github.com/D-Programming-Language/dmd/blob/master/src/root/port.c
 */

#include "port.h"

#if __DMC__
#include <math.h>
#include <float.h>
#include <fp.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>
#include <errno.h>

char *Port::strupr(char *s)
{
    return ::strupr(s);
}

int Port::memicmp(const char *s1, const char *s2, size_t n)
{
    return ::memicmp(s1, s2, n);
}

extern "C" const char * __cdecl __locale_decpoint;

bool Port::isFloat32LiteralOutOfRange(const char *p)
{
    errno = 0;
    const char *save = __locale_decpoint;
    __locale_decpoint = ".";
    ::strtof(p, NULL);
    __locale_decpoint = save;
    return errno == ERANGE;
}

bool Port::isFloat64LiteralOutOfRange(const char *p)
{
    errno = 0;
    const char *save = __locale_decpoint;
    __locale_decpoint = ".";
    ::strtod(p, NULL);
    __locale_decpoint = save;
    return errno == ERANGE;
}

#endif

#if _MSC_VER

// Disable useless warnings about unreferenced functions
#pragma warning (disable : 4514)

#include <math.h>
#include <float.h>  // for _isnan
#include <errno.h>
#include <string.h>
#include <ctype.h>
#include <wchar.h>
#include <stdlib.h>

char *Port::strupr(char *s)
{
    return ::strupr(s);
}

int Port::memicmp(const char *s1, const char *s2, size_t n)
{
    return ::memicmp(s1, s2, n);
}

bool Port::isFloat32LiteralOutOfRange(const char *p)
{
    errno = 0;
    _CRT_FLOAT flt;
    int res = _atoflt(&flt, (char*)p);
    if (res == _UNDERFLOW)
        errno = ERANGE;
    return errno == ERANGE;
}

bool Port::isFloat64LiteralOutOfRange(const char *p)
{
    errno = 0;
    _CRT_DOUBLE dbl;
    int res = _atodbl(&dbl, const_cast<char*> (p));
    if (res == _UNDERFLOW)
        errno = ERANGE;
    return errno == ERANGE;
}

#endif

#if __MINGW32__

#include <math.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <wchar.h>
#include <float.h>
#include <assert.h>
#include <errno.h>

char *Port::strupr(char *s)
{
    char *t = s;

    while (*s)
    {
        *s = toupper(*s);
        s++;
    }

    return t;
}

int Port::memicmp(const char *s1, const char *s2, size_t n)
{
    int result = 0;

    for (int i = 0; i < n; i++)
    {   char c1 = s1[i];
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

bool Port::isFloat32LiteralOutOfRange(const char *p)
{
    errno = 0;
    ::strtof(p, NULL);
    return errno == ERANGE;
}

bool Port::isFloat64LiteralOutOfRange(const char *p)
{
    errno = 0;
    ::strtod(p, NULL);
    return errno == ERANGE;
}

#endif

#if __linux__ || __APPLE__ || __FreeBSD__ || __OpenBSD__

#include <math.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <wchar.h>
#include <float.h>
#include <assert.h>
#include <errno.h>

char *Port::strupr(char *s)
{
    char *t = s;

    while (*s)
    {
        *s = toupper(*s);
        s++;
    }

    return t;
}

int Port::memicmp(const char *s1, const char *s2, size_t n)
{
    int result = 0;

    for (int i = 0; i < n; i++)
    {   char c1 = s1[i];
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

bool Port::isFloat32LiteralOutOfRange(const char *p)
{
    errno = 0;
    ::strtof(p, NULL);
    return errno == ERANGE;
}

bool Port::isFloat64LiteralOutOfRange(const char *p)
{
    errno = 0;
    ::strtod(p, NULL);
    return errno == ERANGE;
}

#endif

#if __sun

#define __C99FEATURES__ 1       // Needed on Solaris for NaN and more
#include <math.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <wchar.h>
#include <float.h>
#include <ieeefp.h>
#include <assert.h>
#include <errno.h>

char *Port::strupr(char *s)
{
    char *t = s;

    while (*s)
    {
        *s = toupper(*s);
        s++;
    }

    return t;
}

int Port::memicmp(const char *s1, const char *s2, size_t n)
{
    int result = 0;

    for (int i = 0; i < n; i++)
    {   char c1 = s1[i];
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

bool Port::isFloat32LiteralOutOfRange(const char *p)
{
    errno = 0;
    ::strtof(p, NULL);
    return errno == ERANGE;
}

bool Port::isFloat64LiteralOutOfRange(const char *p)
{
    errno = 0;
    ::strtod(p, NULL);
    return errno == ERANGE;
}

#endif

// Little endian
void Port::writelongLE(unsigned value, void* buffer)
{
    unsigned char *p = (unsigned char*)buffer;
    p[3] = (unsigned char)(value >> 24);
    p[2] = (unsigned char)(value >> 16);
    p[1] = (unsigned char)(value >> 8);
    p[0] = (unsigned char)(value);
}

// Little endian
unsigned Port::readlongLE(const void* buffer)
{
    const unsigned char *p = (const unsigned char*)buffer;
    return (((((p[3] << 8) | p[2]) << 8) | p[1]) << 8) | p[0];
}

// Big endian
void Port::writelongBE(unsigned value, void* buffer)
{
    unsigned char *p = (unsigned char*)buffer;
    p[0] = (unsigned char)(value >> 24);
    p[1] = (unsigned char)(value >> 16);
    p[2] = (unsigned char)(value >> 8);
    p[3] = (unsigned char)(value);
}

// Big endian
unsigned Port::readlongBE(const void* buffer)
{
    const unsigned char *p = (const unsigned char*)buffer;
    return (((((p[0] << 8) | p[1]) << 8) | p[2]) << 8) | p[3];
}

// Little endian
unsigned Port::readwordLE(const void *buffer)
{
    const unsigned char *p = (const unsigned char*)buffer;
    return (p[1] << 8) | p[0];
}

// Big endian
unsigned Port::readwordBE(const void *buffer)
{
    const unsigned char *p = (const unsigned char*)buffer;
    return (p[0] << 8) | p[1];
}

void Port::valcpy(void *dst, uint64_t val, size_t size)
{
    switch (size)
    {
        case 1: *(uint8_t *)dst = (uint8_t)val; break;
        case 2: *(uint16_t *)dst = (uint16_t)val; break;
        case 4: *(uint32_t *)dst = (uint32_t)val; break;
        case 8: *(uint64_t *)dst = (uint64_t)val; break;
        default: assert(0);
    }
}
