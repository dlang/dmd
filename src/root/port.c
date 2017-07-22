
/* Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved, written by Walter Bright
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
#include <time.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>
#include <errno.h>

double Port::nan = NAN;
longdouble Port::ldbl_nan = NAN;
longdouble Port::snan;

double Port::infinity = INFINITY;
longdouble Port::ldbl_infinity = INFINITY;

double Port::dbl_max = DBL_MAX;
double Port::dbl_min = DBL_MIN;
longdouble Port::ldbl_max = LDBL_MAX;

struct PortInitializer
{
    PortInitializer();
};

static PortInitializer portinitializer;

PortInitializer::PortInitializer()
{
    union
    {   unsigned int ui[4];
        longdouble     ld;
    } snan = {{ 0, 0xA0000000, 0x7FFF, 0 }};

    Port::snan = snan.ld;
}

char *Port::strupr(char *s)
{
    return ::strupr(s);
}

int Port::memicmp(const char *s1, const char *s2, int n)
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
#include <time.h>
#include <errno.h>
#include <string.h>
#include <ctype.h>
#include <wchar.h>
#include <stdlib.h>
#include <limits> // for std::numeric_limits

double Port::nan;
longdouble Port::ldbl_nan;
longdouble Port::snan;

double Port::infinity;
longdouble Port::ldbl_infinity;

double Port::dbl_max = DBL_MAX;
double Port::dbl_min = DBL_MIN;
longdouble Port::ldbl_max = LDBL_MAX;

struct PortInitializer
{
    PortInitializer();
};

static PortInitializer portinitializer;

PortInitializer::PortInitializer()
{
    union {
        unsigned long ul[2];
        double d;
    } nan = {{ 0, 0x7FF80000 }};

    Port::nan = nan.d;
    Port::ldbl_nan = ld_qnan;
    Port::snan = ld_snan;
    Port::infinity = std::numeric_limits<double>::infinity();
    Port::ldbl_infinity = ld_inf;

    _set_abort_behavior(_WRITE_ABORT_MSG, _WRITE_ABORT_MSG | _CALL_REPORTFAULT); // disable crash report
}

char *Port::strupr(char *s)
{
    return ::strupr(s);
}

int Port::memicmp(const char *s1, const char *s2, int n)
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
#include <time.h>
#include <sys/time.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <wchar.h>
#include <float.h>
#include <assert.h>
#include <errno.h>

double Port::nan;
longdouble Port::ldbl_nan;
longdouble Port::snan;

static double zero = 0;
double Port::infinity = 1 / zero;
longdouble Port::ldbl_infinity = 1 / zero;

double Port::dbl_max = 1.7976931348623157e308;
double Port::dbl_min = 5e-324;
longdouble Port::ldbl_max = LDBL_MAX;

struct PortInitializer
{
    PortInitializer();
};

static PortInitializer portinitializer;

PortInitializer::PortInitializer()
{
    union
    {   unsigned int ui[2];
        double d;
    } nan = {{ 0, 0x7FF80000 }};

    Port::nan = nan.d;
    assert(!signbit(Port::nan));

    union
    {   unsigned int ui[4];
        longdouble ld;
    } ldbl_nan = {{ 0, 0xC0000000, 0x7FFF, 0}};

    Port::ldbl_nan = ldbl_nan.ld;
    assert(!signbit(Port::ldbl_nan));

    union
    {   unsigned int ui[4];
        longdouble     ld;
    } snan = {{ 0, 0xA0000000, 0x7FFF, 0 }};

    Port::snan = snan.ld;
}

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

int Port::memicmp(const char *s1, const char *s2, int n)
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
#if __linux__
#include <bits/nan.h>
#include <bits/mathdef.h>
#endif
#if __FreeBSD__ && __i386__
#include <ieeefp.h>
#endif
#include <time.h>
#include <sys/time.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <wchar.h>
#include <float.h>
#include <assert.h>
#include <errno.h>

double Port::nan;
longdouble Port::ldbl_nan;
longdouble Port::snan;

static double zero = 0;
double Port::infinity = 1 / zero;
longdouble Port::ldbl_infinity = 1 / zero;

double Port::dbl_max = 1.7976931348623157e308;
double Port::dbl_min = 5e-324;
longdouble Port::ldbl_max = LDBL_MAX;

struct PortInitializer
{
    PortInitializer();
};

static PortInitializer portinitializer;

PortInitializer::PortInitializer()
{
    union
    {   unsigned int ui[2];
        double d;
    } nan = {{ 0, 0x7FF80000 }};

    Port::nan = nan.d;
    assert(!signbit(Port::nan));

    union
    {   unsigned int ui[4];
        longdouble ld;
    } ldbl_nan = {{ 0, 0xC0000000, 0x7FFF, 0}};

    Port::ldbl_nan = ldbl_nan.ld;
    assert(!signbit(Port::ldbl_nan));

    union
    {   unsigned int ui[4];
        longdouble     ld;
    } snan = {{ 0, 0xA0000000, 0x7FFF, 0 }};

    Port::snan = snan.ld;

#if __FreeBSD__ && __i386__
    // LDBL_MAX comes out as infinity. Fix.
    static unsigned char x[sizeof(longdouble)] =
        { 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFE,0x7F };
    Port::ldbl_max = *(longdouble *)&x[0];
    // FreeBSD defaults to double precision. Switch to extended precision.
    fpsetprec(FP_PE);
#endif
}

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

int Port::memicmp(const char *s1, const char *s2, int n)
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
#include <time.h>
#include <sys/time.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <wchar.h>
#include <float.h>
#include <ieeefp.h>
#include <assert.h>
#include <errno.h>

double Port::nan;
longdouble Port::ldbl_nan;
longdouble Port::snan;

static double zero = 0;
double Port::infinity = 1 / zero;
longdouble Port::ldbl_infinity = 1 / zero;

double Port::dbl_max = 1.7976931348623157e308;
double Port::dbl_min = 5e-324;
longdouble Port::ldbl_max = LDBL_MAX;

struct PortInitializer
{
    PortInitializer();
};

static PortInitializer portinitializer;

PortInitializer::PortInitializer()
{
    union
    {   unsigned int ui[2];
        double d;
    } nan = {{ 0, 0x7FF80000 }};

    Port::nan = nan.d;
    assert(!signbit(Port::nan));

    union
    {   unsigned int ui[4];
        longdouble ld;
    } ldbl_nan = {{ 0, 0xC0000000, 0x7FFF, 0}};

    Port::ldbl_nan = ldbl_nan.ld;
    assert(!signbit(Port::ldbl_nan));

    union
    {   unsigned int ui[4];
        longdouble     ld;
    } snan = {{ 0, 0xA0000000, 0x7FFF, 0 }};

    Port::snan = snan.ld;
}

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

int Port::memicmp(const char *s1, const char *s2, int n)
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
unsigned Port::readlongLE(void* buffer)
{
    unsigned char *p = (unsigned char*)buffer;
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
unsigned Port::readlongBE(void* buffer)
{
    unsigned char *p = (unsigned char*)buffer;
    return (((((p[0] << 8) | p[1]) << 8) | p[2]) << 8) | p[3];
}

// Little endian
unsigned Port::readwordLE(void *buffer)
{
    unsigned char *p = (unsigned char*)buffer;
    return (p[1] << 8) | p[0];
}

// Big endian
unsigned Port::readwordBE(void *buffer)
{
    unsigned char *p = (unsigned char*)buffer;
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
