
// Copyright (c) 1999-2012 by Digital Mars
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
#include <wchar.h>

double Port::nan = NAN;
double Port::infinity = INFINITY;
double Port::dbl_max = DBL_MAX;
double Port::dbl_min = DBL_MIN;
longdouble Port::ldbl_max = LDBL_MAX;

int Port::isNan(double r)
{
    return ::isnan(r);
}

int Port::isNan(longdouble r)
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

int Port::isSignallingNan(longdouble r)
{
    /* A signalling NaN is a NaN with 0 as the most significant bit of
     * its significand, which is bit 62 of 0..79 for 80 bit reals.
     */
    return isNan(r) && !((((unsigned char*)&r)[7]) & 0x40);
}

int Port::isInfinity(double r)
{
    return (::fpclassify(r) == FP_INFINITE);
}

longdouble Port::fmodl(longdouble x, longdouble y)
{
    return ::fmodl(x, y);
}

char *Port::strupr(char *s)
{
    return ::strupr(s);
}

int Port::memicmp(const char *s1, const char *s2, int n)
{
    return ::memicmp(s1, s2, n);
}

int Port::stricmp(const char *s1, const char *s2)
{
    return ::stricmp(s1, s2);
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

static unsigned long nanarray[2]= { 0xFFFFFFFF, 0x7FFFFFFF };
//static unsigned long nanarray[2] = {0,0x7FF80000 };
double Port::nan = (*(double *)nanarray);

//static unsigned long infinityarray[2] = {0,0x7FF00000 };
static double zero = 0;
double Port::infinity = 1 / zero;

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
    Port::infinity = std::numeric_limits<double>::infinity();
}

int Port::isNan(double r)
{
    return ::_isnan(r);
}

int Port::isNan(longdouble r)
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

int Port::isSignallingNan(longdouble r)
{
    /* MSVC doesn't have 80 bit long doubles
     */
    return isSignallingNan((double) r);
}

int Port::isInfinity(double r)
{
    return (::_fpclass(r) & (_FPCLASS_NINF | _FPCLASS_PINF));
}

longdouble Port::fmodl(longdouble x, longdouble y)
{
    return ::fmodl(x, y);
}

char *Port::strupr(char *s)
{
    return ::strupr(s);
}

int Port::memicmp(const char *s1, const char *s2, int n)
{
    return ::memicmp(s1, s2, n);
}

int Port::stricmp(const char *s1, const char *s2)
{
    return ::stricmp(s1, s2);
}

#endif

#if __MINGW32__

#include <math.h>
#include <time.h>
#include <sys/time.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <wchar.h>
#include <float.h>
#include <assert.h>

static double zero = 0;
double Port::nan = copysign(NAN, 1.0);
double Port::infinity = 1 / zero;
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
    assert(!signbit(Port::nan));
}

int Port::isNan(double r)
{
    return isnan(r);
}

int Port::isNan(longdouble r)
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

int Port::isSignallingNan(longdouble r)
{
    /* A signalling NaN is a NaN with 0 as the most significant bit of
     * its significand, which is bit 62 of 0..79 for 80 bit reals.
     */
    return isNan(r) && !((((unsigned char*)&r)[7]) & 0x40);
}

int Port::isInfinity(double r)
{
    return isinf(r);
}

longdouble Port::fmodl(longdouble x, longdouble y)
{
    return ::fmodl(x, y);
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

int Port::stricmp(const char *s1, const char *s2)
{
    int result = 0;

    for (;;)
    {   char c1 = *s1;
        char c2 = *s2;

        result = c1 - c2;
        if (result)
        {
            result = toupper(c1) - toupper(c2);
            if (result)
                break;
        }
        if (!c1)
            break;
        s1++;
        s2++;
    }
    return result;
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
#include <wchar.h>
#include <float.h>
#include <assert.h>

static double zero = 0;
double Port::nan = copysign(NAN, 1.0);
double Port::infinity = 1 / zero;
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
    assert(!signbit(Port::nan));

#if __FreeBSD__ && __i386__
    // LDBL_MAX comes out as infinity. Fix.
    static unsigned char x[sizeof(longdouble)] =
        { 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFE,0x7F };
    Port::ldbl_max = *(longdouble *)&x[0];
    // FreeBSD defaults to double precision. Switch to extended precision.
    fpsetprec(FP_PE);
#endif
}

int Port::isNan(double r)
{
#if __APPLE__
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 1080
    return __inline_isnand(r);
#else
    return __inline_isnan(r);
#endif
#elif __OpenBSD__
    return isnan(r);
#else
    #undef isnan
    return ::isnan(r);
#endif
}

int Port::isNan(longdouble r)
{
#if __APPLE__
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 1080
    return __inline_isnanl(r);
#else
    return __inline_isnan(r);
#endif
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

int Port::isSignallingNan(longdouble r)
{
    /* A signalling NaN is a NaN with 0 as the most significant bit of
     * its significand, which is bit 62 of 0..79 for 80 bit reals.
     */
    return isNan(r) && !((((unsigned char*)&r)[7]) & 0x40);
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

longdouble Port::fmodl(longdouble x, longdouble y)
{
#if __FreeBSD__ || __OpenBSD__
    return ::fmod(x, y);        // hack for now, fix later
#else
    return ::fmodl(x, y);
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

int Port::stricmp(const char *s1, const char *s2)
{
    int result = 0;

    for (;;)
    {   char c1 = *s1;
        char c2 = *s2;

        result = c1 - c2;
        if (result)
        {
            result = toupper(c1) - toupper(c2);
            if (result)
                break;
        }
        if (!c1)
            break;
        s1++;
        s2++;
    }
    return result;
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
#include <ctype.h>
#include <wchar.h>
#include <float.h>
#include <ieeefp.h>

static double zero = 0;
double Port::nan = NAN;
double Port::infinity = 1 / zero;
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
    // gcc nan's have the sign bit set by default, so turn it off
    // Need the volatile to prevent gcc from doing incorrect
    // constant folding.
    volatile longdouble foo;
    foo = NAN;
    if (signbit(foo))   // signbit sometimes, not always, set
        foo = -foo;     // turn off sign bit
    Port::nan = foo;
}

int Port::isNan(double r)
{
    return isnan(r);
}

int Port::isNan(longdouble r)
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

int Port::isSignallingNan(longdouble r)
{
    /* A signalling NaN is a NaN with 0 as the most significant bit of
     * its significand, which is bit 62 of 0..79 for 80 bit reals.
     */
    return isNan(r) && !((((unsigned char*)&r)[7]) & 0x40);
}

int Port::isInfinity(double r)
{
    return isinf(r);
}

longdouble Port::fmodl(longdouble x, longdouble y)
{
    return ::fmodl(x, y);
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
