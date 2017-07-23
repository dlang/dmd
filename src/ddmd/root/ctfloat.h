
/* Copyright (c) 1999-2016 by Digital Mars
 * All Rights Reserved, written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * (See accompanying file LICENSE or copy at http://www.boost.org/LICENSE_1_0.txt)
 * https://github.com/dlang/dmd/blob/master/src/root/ctfloat.h
 */

#ifndef CTFLOAT_H
#define CTFLOAT_H

#include "longdouble.h"

// Type used by the front-end for compile-time reals
typedef longdouble real_t;

// Compile-time floating-point helper
struct CTFloat
{
    static bool yl2x_supported;
    static bool yl2xp1_supported;

    static void yl2x(const real_t *x, const real_t *y, real_t *res);
    static void yl2xp1(const real_t *x, const real_t *y, real_t *res);

    static real_t sin(real_t x);
    static real_t cos(real_t x);
    static real_t tan(real_t x);
    static real_t sqrt(real_t x);
    static real_t fabs(real_t x);

    static bool isIdentical(real_t a, real_t b);
    static bool isNaN(real_t r);
    static bool isSNaN(real_t r);
    static bool isInfinity(real_t r);

    static real_t parse(const char *literal, bool *isOutOfRange = NULL);
    static int sprint(char *str, char fmt, real_t x);

    static size_t hash(real_t a);

    // Constant real values 0, 1, -1 and 0.5.
    static real_t zero;
    static real_t one;
    static real_t minusone;
    static real_t half;
};

#endif
