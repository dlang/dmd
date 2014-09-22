
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

double Port::nan = NAN;
longdouble Port::ldbl_nan = NAN;
longdouble Port::snan;

double Port::infinity = INFINITY;
longdouble Port::ldbl_infinity = INFINITY;

double Port::dbl_max = DBL_MAX;
double Port::dbl_min = DBL_MIN;
longdouble Port::ldbl_max = LDBL_MAX;

bool Port::yl2x_supported = true;
bool Port::yl2xp1_supported = true;

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

longdouble Port::sqrt(longdouble x)
{
    return ::sqrtl(x);
}

longdouble Port::fmodl(longdouble x, longdouble y)
{
    return ::fmodl(x, y);
}

int Port::fequal(longdouble x, longdouble y)
{
    /* In some cases, the REALPAD bytes get garbage in them,
     * so be sure and ignore them.
     */
    return memcmp(&x, &y, 10) == 0;
}

void Port::yl2x_impl(longdouble* x, longdouble* y, longdouble* res)
{
    *res = _inline_yl2x(*x, *y);
}

void Port::yl2xp1_impl(longdouble* x, longdouble* y, longdouble* res)
{
    *res = _inline_yl2xp1(*x, *y);
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


extern "C" const char * __cdecl __locale_decpoint;

float Port::strtof(const char *buffer, char **endp)
{
    const char *save = __locale_decpoint;
    __locale_decpoint = ".";
    float result = ::strtof(buffer, endp);
    __locale_decpoint = save;
    return result;
}

double Port::strtod(const char *buffer, char **endp)
{
    const char *save = __locale_decpoint;
    __locale_decpoint = ".";
    double result = ::strtod(buffer, endp);
    __locale_decpoint = save;
    return result;
}

longdouble Port::strtold(const char *buffer, char **endp)
{
    const char *save = __locale_decpoint;
    __locale_decpoint = ".";
    longdouble result = ::strtold(buffer, endp);
    __locale_decpoint = save;
    return result;
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

#if _M_IX86 || _M_X64
bool Port::yl2x_supported = true;
bool Port::yl2xp1_supported = true;
#else
bool Port::yl2x_supported = false;
bool Port::yl2xp1_supported = false;
#endif

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

longdouble Port::sqrt(longdouble x)
{
    return ::sqrtl(x);
}

longdouble Port::fmodl(longdouble x, longdouble y)
{
    return ::fmodl(x, y);
}

int Port::fequal(longdouble x, longdouble y)
{
    /* In some cases, the REALPAD bytes get garbage in them,
     * so be sure and ignore them.
     */
    return memcmp(&x, &y, 10) == 0;
}

#if _M_IX86
void Port::yl2x_impl(longdouble* x, longdouble* y, longdouble* res)
{
    __asm
    {
        mov eax, y
        mov ebx, x
        mov ecx, res
        finit
        fld tbyte ptr [eax]
        fld tbyte ptr [ebx]
        fyl2x
        fwait
        fstp tbyte ptr [ecx]
    }
}

void Port::yl2xp1_impl(longdouble* x, longdouble* y, longdouble* res)
{
    __asm
    {
        mov eax, y
        mov ebx, x
        mov ecx, res
        finit
        fld tbyte ptr [eax]
        fld tbyte ptr [ebx]
        fyl2xp1
        fwait
        fstp tbyte ptr [ecx]
    }
}
#elif _M_X64

//defined in ldfpu.asm
void ld_yl2x(long_double *x, long_double *y, long_double *r);
void ld_yl2xp1(long_double *x, long_double *y, long_double *r);

void Port::yl2x_impl(longdouble* x, longdouble* y, longdouble* res)
{
    ld_yl2x(x, y, res);
}

void Port::yl2xp1_impl(longdouble* x, longdouble* y, longdouble* res)
{
    ld_yl2xp1(x, y, res);
}
#else

void Port::yl2x_impl(longdouble* x, longdouble* y, longdouble* res)
{
    assert(0);
}

void Port::yl2xp1_impl(longdouble* x, longdouble* y, longdouble* res)
{
    assert(0);
}

#endif

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

float Port::strtof(const char *p, char **endp)
{
    return static_cast<float>(::strtod(p, endp));
}

double Port::strtod(const char *p, char **endp)
{
    return ::strtod(p, endp);
}

// from backend/strtold.c, renamed to avoid clash with decl in stdlib.h
longdouble strtold_dm(const char *p,char **endp);

longdouble Port::strtold(const char *p, char **endp)
{
    return ::strtold_dm(p, endp);
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

double Port::nan;
longdouble Port::ldbl_nan;
longdouble Port::snan;

static double zero = 0;
double Port::infinity = 1 / zero;
longdouble Port::ldbl_infinity = 1 / zero;

double Port::dbl_max = 1.7976931348623157e308;
double Port::dbl_min = 5e-324;
longdouble Port::ldbl_max = LDBL_MAX;

#if _X86_ || __x86_64__
bool Port::yl2x_supported = true;
bool Port::yl2xp1_supported = true;
#else
bool Port::yl2x_supported = false;
bool Port::yl2xp1_supported = false;
#endif

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

longdouble Port::sqrt(longdouble x)
{
    return ::sqrtl(x);
}

longdouble Port::fmodl(longdouble x, longdouble y)
{
    return ::fmodl(x, y);
}

int Port::fequal(longdouble x, longdouble y)
{
    /* In some cases, the REALPAD bytes get garbage in them,
     * so be sure and ignore them.
     */
    return memcmp(&x, &y, 10) == 0;
}

#if _X86_ || __x86_64__
void Port::yl2x_impl(longdouble* x, longdouble* y, longdouble* res)
{
    __asm__ volatile("fyl2x": "=t" (*res): "u" (*y), "0" (*x) : "st(1)" );
}

void Port::yl2xp1_impl(longdouble* x, longdouble* y, longdouble* res)
{
    __asm__ volatile("fyl2xp1": "=t" (*res): "u" (*y), "0" (*x) : "st(1)" );
}
#else
void Port::yl2x_impl(longdouble* x, longdouble* y, longdouble* res)
{
    assert(0);
}

void Port::yl2xp1_impl(longdouble* x, longdouble* y, longdouble* res)
{
    assert(0);
}
#endif

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

float Port::strtof(const char *p, char **endp)
{
    return ::strtof(p, endp);
}

double Port::strtod(const char *p, char **endp)
{
    return ::strtod(p, endp);
}

longdouble Port::strtold(const char *p, char **endp)
{
    return ::__mingw_strtold(p, endp);
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

double Port::nan;
longdouble Port::ldbl_nan;
longdouble Port::snan;

static double zero = 0;
double Port::infinity = 1 / zero;
longdouble Port::ldbl_infinity = 1 / zero;

double Port::dbl_max = 1.7976931348623157e308;
double Port::dbl_min = 5e-324;
longdouble Port::ldbl_max = LDBL_MAX;

#if __i386 || __x86_64__
bool Port::yl2x_supported = true;
bool Port::yl2xp1_supported = true;
#else
bool Port::yl2x_supported = false;
bool Port::yl2xp1_supported = false;
#endif

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

int Port::isNan(double r)
{
#if __APPLE__
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 1080
    return __inline_isnand(r);
#else
    return __inline_isnan(r);
#endif
#elif __FreeBSD__ || __OpenBSD__
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
#elif __FreeBSD__ || __OpenBSD__
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
#elif __FreeBSD__ || __OpenBSD__
    return isinf(r);
#else
    #undef isinf
    return ::isinf(r);
#endif
}

longdouble Port::sqrt(longdouble x)
{
    return ::sqrtl(x);
}

longdouble Port::fmodl(longdouble x, longdouble y)
{
#if __FreeBSD__ && __FreeBSD_version < 800000 || __OpenBSD__
    return ::fmod(x, y);        // hack for now, fix later
#else
    return ::fmodl(x, y);
#endif
}

int Port::fequal(longdouble x, longdouble y)
{
    /* In some cases, the REALPAD bytes get garbage in them,
     * so be sure and ignore them.
     */
    return memcmp(&x, &y, 10) == 0;
}

#if __i386 || __x86_64__
void Port::yl2x_impl(longdouble* x, longdouble* y, longdouble* res)
{
    __asm__ volatile("fyl2x": "=t" (*res): "u" (*y), "0" (*x) : "st(1)" );
}

void Port::yl2xp1_impl(longdouble* x, longdouble* y, longdouble* res)
{
    __asm__ volatile("fyl2xp1": "=t" (*res): "u" (*y), "0" (*x) : "st(1)" );
}
#else
void Port::yl2x_impl(longdouble* x, longdouble* y, longdouble* res)
{
    assert(0);
}

void Port::yl2xp1_impl(longdouble* x, longdouble* y, longdouble* res)
{
    assert(0);
}
#endif

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

float Port::strtof(const char *p, char **endp)
{
    return ::strtof(p, endp);
}

double Port::strtod(const char *p, char **endp)
{
    return ::strtod(p, endp);
}

longdouble Port::strtold(const char *p, char **endp)
{
    return ::strtold(p, endp);
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

double Port::nan;
longdouble Port::ldbl_nan;
longdouble Port::snan;

static double zero = 0;
double Port::infinity = 1 / zero;
longdouble Port::ldbl_infinity = 1 / zero;

double Port::dbl_max = 1.7976931348623157e308;
double Port::dbl_min = 5e-324;
longdouble Port::ldbl_max = LDBL_MAX;

#if __i386 || __x86_64__
bool Port::yl2x_supported = true;
bool Port::yl2xp1_supported = true;
#else
bool Port::yl2x_supported = false;
bool Port::yl2xp1_supported = false;
#endif

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

longdouble Port::sqrt(longdouble x)
{
    return ::sqrtl(x);
}

longdouble Port::fmodl(longdouble x, longdouble y)
{
    return ::fmodl(x, y);
}

int Port::fequal(longdouble x, longdouble y)
{
    /* In some cases, the REALPAD bytes get garbage in them,
     * so be sure and ignore them.
     */
    return memcmp(&x, &y, 10) == 0;
}
#if __i386
void Port::yl2x_impl(long double* x, long double* y, long double* res)
{
    __asm__ volatile("movl %0, %%eax;"    // move x, y, res to registers
                     "movl %1, %%ebx;"
                     "movl %2, %%ecx;"
                     "finit;"             // initialize FPU
                     "fldt (%%ebx);"      // push *y and *x to the FPU stack
                     "fldt (%%eax);"      // "t" suffix means tbyte
                     "fyl2x; fwait;"      // do operation and wait
                     "fstpt (%%ecx)"      // pop result to a *res
                     :                          // output: empty
                     :"r"(x), "r"(y), "r"(res)  // input: x => %0, y => %1, res => %2
                     :"%eax", "%ebx", "%ecx");  // clobbered register: eax, ebc, ecx
}

void Port::yl2xp1_impl(long double* x, long double* y, long double* res)
{
    __asm__ volatile("movl %0, %%eax;"    // move x, y, res to registers
                     "movl %1, %%ebx;"
                     "movl %2, %%ecx;"
                     "finit;"             // initialize FPU
                     "fldt (%%ebx);"      // push *y and *x to the FPU stack
                     "fldt (%%eax);"      // "t" suffix means tbyte
                     "yl2xp1; fwait;"     // do operation and wait
                     "fstpt (%%ecx)"      // pop result to a *res
                     :                          // output: empty
                     :"r"(x), "r"(y), "r"(res)  // input: x => %0, y => %1, res => %2
                     :"%eax", "%ebx", "%ecx");  // clobbered register: eax, ebc, ecx
#elif __x86_64__
void Port::yl2x_impl(long double* x, long double* y, long double* res)
{
    __asm__ volatile("movq %0, %%rcx;"    // move x, y, res to registers
                     "movq %1, %%rdx;"
                     "movq %2, %%r8;"
                     "finit;"             // initialize FPU
                     "fldt (%%rdx);"      // push *y and *x to the FPU stack
                     "fldt (%%rcx);"      // "t" suffix means tbyte
                     "fyl2x; fwait;"      // do operation and wait
                     "fstpt (%%r8)"       // pop result to a *res
                     :                          // output: empty
                     :"r"(x), "r"(y), "r"(res)  // input: x => %0, y => %1, res => %2
                     :"%rcx", "%rdx", "%r8");   // clobbered register: rcx, rdx, r8
}

void Port::yl2xp1_impl(long double* x, long double* y, long double* res)
{
    __asm__ volatile("movq %0, %%rcx;"    // move x, y, res to registers
                     "movq %1, %%rdx;"
                     "movq %2, %%r8;"
                     "finit;"             // initialize FPU
                     "fldt (%%rdx);"      // push *y and *x to the FPU stack
                     "fldt (%%rcx);"      // "t" suffix means tbyte
                     "yl2xp1; fwait;"     // do operation and wait
                     "fstpt (%%r8)"       // pop result to a *res
                     :                          // output: empty
                     :"r"(x), "r"(y), "r"(res)  // input: x => %0, y => %1, res => %2
                     :"%rcx", "%rdx", "%r8");   // clobbered register: rcx, rdx, r8
}
#else
void Port::yl2x_impl(longdouble* x, longdouble* y, longdouble* res)
{
    assert(0);
}

void Port::yl2xp1_impl(longdouble* x, longdouble* y, longdouble* res)
{
    assert(0);
}
#endif

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

float Port::strtof(const char *p, char **endp)
{
    return ::strtof(p, endp);
}

double Port::strtod(const char *p, char **endp)
{
    return ::strtod(p, endp);
}

longdouble Port::strtold(const char *p, char **endp)
{
    return ::strtold(p, endp);
}

#endif
