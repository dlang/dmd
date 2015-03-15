
/* Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved, written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * (See accompanying file LICENSE or copy at http://www.boost.org/LICENSE_1_0.txt)
 * https://github.com/D-Programming-Language/dmd/blob/master/src/root/port.h
 */

#ifndef PORT_H
#define PORT_H

// Portable wrapper around compiler/system specific things.
// The idea is to minimize #ifdef's in the app code.

#include <stdlib.h> // for alloca
#include <stdint.h>

#include "longdouble.h"

#if _MSC_VER
#include <alloca.h>
typedef __int64 longlong;
typedef unsigned __int64 ulonglong;
#else
typedef long long longlong;
typedef unsigned long long ulonglong;
#endif

typedef unsigned char utf8_t;

struct Port
{
    static double nan;
    static longdouble ldbl_nan;
    static longdouble snan;

    static double infinity;
    static longdouble ldbl_infinity;

    static double dbl_max;
    static double dbl_min;
    static longdouble ldbl_max;

    static bool yl2x_supported;
    static bool yl2xp1_supported;

    static int isNan(double);
    static int isNan(longdouble);

    static int isSignallingNan(double);
    static int isSignallingNan(longdouble);

    static int isInfinity(double);

    static longdouble fmodl(longdouble x, longdouble y);
    static longdouble sqrt(longdouble x);
    static int fequal(longdouble x, longdouble y);

    static void yl2x_impl(longdouble* x, longdouble* y, longdouble* res);
    static void yl2xp1_impl(longdouble* x, longdouble* y, longdouble* res);

    static char *strupr(char *);

    static int memicmp(const char *s1, const char *s2, int n);
    static int stricmp(const char *s1, const char *s2);

    static float strtof(const char *p, char **endp);
    static double strtod(const char *p, char **endp);
    static longdouble strtold(const char *p, char **endp);

    static void writelongLE(unsigned value, void* buffer);
    static unsigned readlongLE(void* buffer);
    static void writelongBE(unsigned value, void* buffer);
    static unsigned readlongBE(void* buffer);
    static unsigned readwordLE(void* buffer);
    static unsigned readwordBE(void* buffer);
};

#endif
