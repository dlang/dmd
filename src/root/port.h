
// Copyright (c) 1999-2012 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com

#ifndef PORT_H
#define PORT_H

// Portable wrapper around compiler/system specific things.
// The idea is to minimize #ifdef's in the app code.

#include "longdouble.h"

#if _MSC_VER
#include <float.h>  // for _isnan
#include <malloc.h> // for alloca
// According to VC 8.0 docs, long double is the same as double
longdouble strtold(const char *p,char **endp);
#define strtof  strtod
#define isnan   _isnan

typedef __int64 longlong;
typedef unsigned __int64 ulonglong;
#else
typedef long long longlong;
typedef unsigned long long ulonglong;
#endif

typedef double d_time;

struct Port
{
    static double nan;
    static double infinity;
    static double dbl_max;
    static double dbl_min;
    static longdouble ldbl_max;

#if __OpenBSD__
#elif __GNUC__
    // These conflict with macros in math.h, should rename them
    #undef isnan
    #undef isfinite
    #undef isinfinity
    #undef signbit
#endif
    static int isNan(double);
    static int isNan(longdouble);

    static int isSignallingNan(double);
    static int isSignallingNan(longdouble);

    static int isFinite(double);
    static int isInfinity(double);
    static int Signbit(double);

    static double floor(double);
    static double pow(double x, double y);

    static longdouble fmodl(longdouble x, longdouble y);

    static ulonglong strtoull(const char *p, char **pend, int base);

    static char *ull_to_string(char *buffer, ulonglong ull);
    static wchar_t *ull_to_string(wchar_t *buffer, ulonglong ull);

    // Convert ulonglong to double
    static double ull_to_double(ulonglong ull);

    // Get locale-dependent list separator
    static const char *list_separator();
    static const wchar_t *wlist_separator();

    static char *strupr(char *);

    static int memicmp(const char *s1, const char *s2, int n);
    static int stricmp(const char *s1, const char *s2);
};

#endif
