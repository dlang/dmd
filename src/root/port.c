
// Copyright (c) 1999-2011 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com

#include "port.h"
#if __DMC__
#include <math.h>
#include <float.h>
#include <fp.h>
#include <time.h>
#include <stdlib.h>
#include <string.h>

double Port::nan = NAN;
double Port::infinity = INFINITY;
double Port::dbl_max = DBL_MAX;
double Port::dbl_min = DBL_MIN;
long double Port::ldbl_max = LDBL_MAX;

int Port::isNan(double r)
{
    return ::isnan(r);
}

int Port::isNan(long double r)
{
    return ::isnan(r);
}

int Port::isSignallingNan(double r)
{
    /* A signalling NaN is a NaN with 0 as the most significant bit of
     * its significand, which is bit 51 of 0..63 for 64 bit doubles.
     */
    return isNan(r) && !((((unsigned char*)&r)[6]) & 8);
}

int Port::isSignallingNan(long double r)
{
    /* A signalling NaN is a NaN with 0 as the most significant bit of
     * its significand, which is bit 62 of 0..79 for 80 bit reals.
     */
    return isNan(r) && !((((unsigned char*)&r)[7]) & 0x40);
}

int Port::isFinite(double r)
{
    return ::isfinite(r);
}

int Port::isInfinity(double r)
{
    return (::fpclassify(r) == FP_INFINITE);
}

int Port::Signbit(double r)
{
    return ::signbit(r);
}

double Port::floor(double d)
{
    return ::floor(d);
}

double Port::pow(double x, double y)
{
    return ::pow(x, y);
}

long double Port::fmodl(long double x, long double y)
{
    return ::fmodl(x, y);
}

unsigned long long Port::strtoull(const char *p, char **pend, int base)
{
    return ::strtoull(p, pend, base);
}

char *Port::ull_to_string(char *buffer, ulonglong ull)
{
    sprintf(buffer, "%llu", ull);
    return buffer;
}

wchar_t *Port::ull_to_string(wchar_t *buffer, ulonglong ull)
{
    swprintf(buffer, sizeof(ulonglong) * 3 + 1, L"%llu", ull);
    return buffer;
}

double Port::ull_to_double(ulonglong ull)
{
    return (double) ull;
}

const char *Port::list_separator()
{
    // LOCALE_SLIST for Windows
    return ",";
}

const wchar_t *Port::wlist_separator()
{
    // LOCALE_SLIST for Windows
    return L",";
}

char *Port::strupr(char *s)
{
    return ::strupr(s);
}

#endif

#if _MSC_VER

// Disable useless warnings about unreferenced functions
#pragma warning (disable : 4514)

#include <math.h>
#include <float.h>
#include <time.h>
#include <errno.h>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>
#include <limits> // for std::numeric_limits

static unsigned long nanarray[2]= { 0xFFFFFFFF, 0x7FFFFFFF };
//static unsigned long nanarray[2] = {0,0x7FF80000 };
double Port::nan = (*(double *)nanarray);

//static unsigned long infinityarray[2] = {0,0x7FF00000 };
static double zero = 0;
double Port::infinity = 1 / zero;

double Port::dbl_max = DBL_MAX;
double Port::dbl_min = DBL_MIN;
long double Port::ldbl_max = LDBL_MAX;

struct PortInitializer
{
    PortInitializer();
};

static PortInitializer portinitializer;

PortInitializer::PortInitializer()
{
    Port::infinity = std::numeric_limits<long double>::infinity();
}

int Port::isNan(double r)
{
    return ::_isnan(r);
}

int Port::isNan(long double r)
{
    return ::_isnan(r);
}

int Port::isSignallingNan(double r)
{
    /* A signalling NaN is a NaN with 0 as the most significant bit of
     * its significand, which is bit 51 of 0..63 for 64 bit doubles.
     */
    return isNan(r) && !((((unsigned char*)&r)[6]) & 8);
}

int Port::isSignallingNan(long double r)
{
    /* MSVC doesn't have 80 bit long doubles
     */
    return isSignallingNan((double) r);
}

int Port::isFinite(double r)
{
    return ::_finite(r);
}

int Port::isInfinity(double r)
{
    return (::_fpclass(r) & (_FPCLASS_NINF | _FPCLASS_PINF));
}

int Port::Signbit(double r)
{
    return (long)(((long *)&(r))[1] & 0x80000000);
}

double Port::floor(double d)
{
    return ::floor(d);
}

double Port::pow(double x, double y)
{
    if (y == 0)
        return 1;               // even if x is NAN
    return ::pow(x, y);
}

long double Port::fmodl(long double x, long double y)
{
    return ::fmodl(x, y);
}

unsigned _int64 Port::strtoull(const char *p, char **pend, int base)
{
    unsigned _int64 number = 0;
    int c;
    int error;
#ifndef ULLONG_MAX
    #define ULLONG_MAX ((unsigned _int64)~0I64)
#endif

    while (isspace((unsigned char)*p))         /* skip leading white space     */
        p++;
    if (*p == '+')
        p++;
    switch (base)
    {   case 0:
            base = 10;          /* assume decimal base          */
            if (*p == '0')
            {   base = 8;       /* could be octal               */
                    p++;
                    switch (*p)
                    {   case 'x':
                        case 'X':
                            base = 16;  /* hex                  */
                            p++;
                            break;
#if BINARY
                        case 'b':
                        case 'B':
                            base = 2;   /* binary               */
                            p++;
                            break;
#endif
                    }
            }
            break;
        case 16:                        /* skip over '0x' and '0X'      */
            if (*p == '0' && (p[1] == 'x' || p[1] == 'X'))
                    p += 2;
            break;
#if BINARY
        case 2:                 /* skip over '0b' and '0B'      */
            if (*p == '0' && (p[1] == 'b' || p[1] == 'B'))
                    p += 2;
            break;
#endif
    }
    error = 0;
    for (;;)
    {   c = *p;
        if (isdigit(c))
                c -= '0';
        else if (isalpha(c))
                c = (c & ~0x20) - ('A' - 10);
        else                    /* unrecognized character       */
                break;
        if (c >= base)          /* not in number base           */
                break;
        if ((ULLONG_MAX - c) / base < number)
                error = 1;
        number = number * base + c;
        p++;
    }
    if (pend)
        *pend = (char *)p;
    if (error)
    {   number = ULLONG_MAX;
        errno = ERANGE;
    }
    return number;
}

char *Port::ull_to_string(char *buffer, ulonglong ull)
{
    _ui64toa(ull, buffer, 10);
    return buffer;
}

wchar_t *Port::ull_to_string(wchar_t *buffer, ulonglong ull)
{
    _ui64tow(ull, buffer, 10);
    return buffer;
}

double Port::ull_to_double(ulonglong ull)
{   double d;

    if ((__int64) ull < 0)
    {
        // MSVC doesn't implement the conversion
        d = (double) (__int64)(ull -  0x8000000000000000i64);
        d += (double)(signed __int64)(0x7FFFFFFFFFFFFFFFi64) + 1.0;
    }
    else
        d = (double)(__int64)ull;
    return d;
}

const char *Port::list_separator()
{
    // LOCALE_SLIST for Windows
    return ",";
}

const wchar_t *Port::wlist_separator()
{
    // LOCALE_SLIST for Windows
    return L",";
}

char *Port::strupr(char *s)
{
    return ::strupr(s);
}

#endif

#if linux || __APPLE__ || __FreeBSD__ || __OpenBSD__

#include <math.h>
#if linux
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
#include <ctype.h>
#include <float.h>
#include <assert.h>

static double zero = 0;
double Port::nan = NAN;
double Port::infinity = 1 / zero;
double Port::dbl_max = 1.7976931348623157e308;
double Port::dbl_min = 5e-324;
long double Port::ldbl_max = LDBL_MAX;

struct PortInitializer
{
    PortInitializer();
};

static PortInitializer portinitializer;

PortInitializer::PortInitializer()
{
    // gcc nan's have the sign bit set by default, so turn it off
    // Need the volatile to prevent gcc from doing incorrect
    // constant folding.
    volatile long double foo;
    foo = NAN;
    if (signbit(foo))   // signbit sometimes, not always, set
        foo = -foo;     // turn off sign bit
    Port::nan = foo;

#if __FreeBSD__ && __i386__
    // LDBL_MAX comes out as infinity. Fix.
    static unsigned char x[sizeof(long double)] =
        { 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFE,0x7F };
    Port::ldbl_max = *(long double *)&x[0];
    // FreeBSD defaults to double precision. Switch to extended precision.
    fpsetprec(FP_PE);
#endif
}

int Port::isNan(double r)
{
#if __APPLE__
    return __inline_isnan(r);
#elif __OpenBSD__
    return isnan(r);
#else
    #undef isnan
    return ::isnan(r);
#endif
}

int Port::isNan(long double r)
{
#if __APPLE__
    return __inline_isnan(r);
#elif __OpenBSD__
    return isnan(r);
#else
    #undef isnan
    return ::isnan(r);
#endif
}

int Port::isSignallingNan(double r)
{
    /* A signalling NaN is a NaN with 0 as the most significant bit of
     * its significand, which is bit 51 of 0..63 for 64 bit doubles.
     */
    return isNan(r) && !((((unsigned char*)&r)[6]) & 8);
}

int Port::isSignallingNan(long double r)
{
    /* A signalling NaN is a NaN with 0 as the most significant bit of
     * its significand, which is bit 62 of 0..79 for 80 bit reals.
     */
    return isNan(r) && !((((unsigned char*)&r)[7]) & 0x40);
}

#undef isfinite
int Port::isFinite(double r)
{
    return ::finite(r);
}

int Port::isInfinity(double r)
{
#if __APPLE__
    return fpclassify(r) == FP_INFINITE;
#elif __OpenBSD__
    return isinf(r);
#else
    #undef isinf
    return ::isinf(r);
#endif
}

#undef signbit
int Port::Signbit(double r)
{
    union { double d; long long ll; } u;
    u.d =  r;
    return u.ll < 0;
}

double Port::floor(double d)
{
    return ::floor(d);
}

double Port::pow(double x, double y)
{
    return ::pow(x, y);
}

long double Port::fmodl(long double x, long double y)
{
#if __FreeBSD__ || __OpenBSD__
    return ::fmod(x, y);        // hack for now, fix later
#else
    return ::fmodl(x, y);
#endif
}

unsigned long long Port::strtoull(const char *p, char **pend, int base)
{
    return ::strtoull(p, pend, base);
}

char *Port::ull_to_string(char *buffer, ulonglong ull)
{
    sprintf(buffer, "%llu", ull);
    return buffer;
}

wchar_t *Port::ull_to_string(wchar_t *buffer, ulonglong ull)
{
#if __OpenBSD__
    assert(0);
#else
    swprintf(buffer, sizeof(ulonglong) * 3 + 1, L"%llu", ull);
#endif
    return buffer;
}

double Port::ull_to_double(ulonglong ull)
{
    return (double) ull;
}

const char *Port::list_separator()
{
    return ",";
}

const wchar_t *Port::wlist_separator()
{
    return L",";
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

#endif

#if __sun&&__SVR4

#define __C99FEATURES__ 1       // Needed on Solaris for NaN and more
#include <math.h>
#include <time.h>
#include <sys/time.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <float.h>
#include <ieeefp.h>

static double zero = 0;
double Port::nan = NAN;
double Port::infinity = 1 / zero;
double Port::dbl_max = 1.7976931348623157e308;
double Port::dbl_min = 5e-324;
long double Port::ldbl_max = LDBL_MAX;

struct PortInitializer
{
    PortInitializer();
};

static PortInitializer portinitializer;

PortInitializer::PortInitializer()
{
    // gcc nan's have the sign bit set by default, so turn it off
    // Need the volatile to prevent gcc from doing incorrect
    // constant folding.
    volatile long double foo;
    foo = NAN;
    if (signbit(foo))   // signbit sometimes, not always, set
        foo = -foo;     // turn off sign bit
    Port::nan = foo;
}

int Port::isNan(double r)
{
    return isnan(r);
}

int Port::isNan(long double r)
{
    return isnan(r);
}

int Port::isSignallingNan(double r)
{
    /* A signalling NaN is a NaN with 0 as the most significant bit of
     * its significand, which is bit 51 of 0..63 for 64 bit doubles.
     */
    return isNan(r) && !((((unsigned char*)&r)[6]) & 8);
}

int Port::isSignallingNan(long double r)
{
    /* A signalling NaN is a NaN with 0 as the most significant bit of
     * its significand, which is bit 62 of 0..79 for 80 bit reals.
     */
    return isNan(r) && !((((unsigned char*)&r)[7]) & 0x40);
}

#undef isfinite
int Port::isFinite(double r)
{
    return finite(r);
}

int Port::isInfinity(double r)
{
    return isinf(r);
}

#undef signbit
int Port::Signbit(double r)
{
    return (long)(((long *)&r)[1] & 0x80000000);
}

double Port::floor(double d)
{
    return ::floor(d);
}

double Port::pow(double x, double y)
{
    return ::pow(x, y);
}

unsigned long long Port::strtoull(const char *p, char **pend, int base)
{
    return ::strtoull(p, pend, base);
}

char *Port::ull_to_string(char *buffer, ulonglong ull)
{
    sprintf(buffer, "%llu", ull);
    return buffer;
}

wchar_t *Port::ull_to_string(wchar_t *buffer, ulonglong ull)
{
    swprintf(buffer, sizeof(ulonglong) * 3 + 1, L"%llu", ull);
    return buffer;
}

double Port::ull_to_double(ulonglong ull)
{
    return (double) ull;
}

const char *Port::list_separator()
{
    return ",";
}

const wchar_t *Port::wlist_separator()
{
    return L",";
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

#endif

#if IN_GCC

#include <math.h>
#include <bits/nan.h>
#include <bits/mathdef.h>
#include <time.h>
#include <sys/time.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>

static double zero = 0;
double Port::nan = NAN;
double Port::infinity = 1 / zero;
double Port::dbl_max = 1.7976931348623157e308;
double Port::dbl_min = 5e-324;
long double Port::ldbl_max = LDBL_MAX;

#include "d-gcc-real.h"
extern "C" bool real_isnan (const real_t *);

struct PortInitializer
{
    PortInitializer();
};

static PortInitializer portinitializer;

PortInitializer::PortInitializer()
{
    Port::infinity = real_t::getinfinity();
    Port::nan = real_t::getnan(real_t::LongDouble);
}

#undef isnan
int Port::isNan(double r)
{
#if __APPLE__
    return __inline_isnan(r);
#else
    return ::isnan(r);
#endif
}

int Port::isNan(long double r)
{
    return real_isnan(&r);
}

int Port::isSignallingNan(double r)
{
    /* A signalling NaN is a NaN with 0 as the most significant bit of
     * its significand, which is bit 51 of 0..63 for 64 bit doubles.
     */
    return isNan(r) && !((((unsigned char*)&r)[6]) & 8);
}

int Port::isSignallingNan(long double r)
{
    /* A signalling NaN is a NaN with 0 as the most significant bit of
     * its significand, which is bit 62 of 0..79 for 80 bit reals.
     */
    return isNan(r) && !((((unsigned char*)&r)[7]) & 0x40);
}

#undef isfinite
int Port::isFinite(double r)
{
    return ::finite(r);
}

#undef isinf
int Port::isInfinity(double r)
{
    return ::isinf(r);
}

#undef signbit
int Port::Signbit(double r)
{
    return (long)(((long *)&r)[1] & 0x80000000);
}

double Port::floor(double d)
{
    return ::floor(d);
}

double Port::pow(double x, double y)
{
    return ::pow(x, y);
}

unsigned long long Port::strtoull(const char *p, char **pend, int base)
{
    return ::strtoull(p, pend, base);
}

char *Port::ull_to_string(char *buffer, ulonglong ull)
{
    sprintf(buffer, "%llu", ull);
    return buffer;
}

wchar_t *Port::ull_to_string(wchar_t *buffer, ulonglong ull)
{
    swprintf(buffer, L"%llu", ull);
    return buffer;
}

double Port::ull_to_double(ulonglong ull)
{
    return (double) ull;
}

const char *Port::list_separator()
{
    return ",";
}

const wchar_t *Port::wlist_separator()
{
    return L",";
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

#endif

