
// Copyright (c) 1999-2002 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com

#ifndef PORT_H
#define PORT_H

// Portable wrapper around compiler/system specific things.
// The idea is to minimize #ifdef's in the app code.

#ifndef TYPEDEFS
#define TYPEDEFS

#include <wchar.h>

#if _MSC_VER
typedef __int64 longlong;
typedef unsigned __int64 ulonglong;
#else
typedef long long longlong;
typedef unsigned long long ulonglong;
#endif

#endif

typedef double d_time;

struct Port
{
    static double nan;
    static double infinity;
    static double dbl_max;
    static double dbl_min;

#if __GNUC__
    // These conflict with macros in math.h, should rename them
    #undef isnan
    #undef isfinite
    #undef isinfinity
    #undef signbit
#endif
    static int isNan(double);
    static int isFinite(double);
    static int isInfinity(double);
    static int Signbit(double);

    static double floor(double);
    static double pow(double x, double y);

    static ulonglong strtoull(const char *p, char **pend, int base);

    static char *ull_to_string(char *buffer, ulonglong ull);
    static wchar_t *ull_to_string(wchar_t *buffer, ulonglong ull);

    // Convert ulonglong to double
    static double ull_to_double(ulonglong ull);

    // Get locale-dependent list separator
    static char *list_separator();
    static wchar_t *wlist_separator();
};

#endif
