
/* Copyright (c) 1999-2016 by Digital Mars
 * All Rights Reserved, written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * (See accompanying file LICENSE or copy at http://www.boost.org/LICENSE_1_0.txt)
 * https://github.com/D-Programming-Language/dmd/blob/master/src/root/port.h
 */

#ifndef CTFLOAT_H
#define CTFLOAT_H

#include "longdouble.h"

// Type used by the front-end for compile-time reals
#if IN_LLVM && _MSC_VER
// Make sure LDC built with MSVC uses double-precision compile-time reals,
// independent of whether it was built with DMD (80-bit reals) or LDC.
typedef double real_t;
#else
typedef longdouble real_t;
#endif

#if IN_LLVM
namespace llvm { class APFloat; }
#endif

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

#if IN_LLVM
    static real_t log(real_t x);
    static real_t fmin(real_t l, real_t r);
    static real_t fmax(real_t l, real_t r);
    static real_t floor(real_t x);
    static real_t ceil(real_t x);
    static real_t trunc(real_t x);
    static real_t round(real_t x);

    // implemented in gen/ctfloat.cpp
    static void _init();
    static void toAPFloat(real_t src, llvm::APFloat &dst);

    static bool isFloat32LiteralOutOfRange(const char *literal);
    static bool isFloat64LiteralOutOfRange(const char *literal);
#endif

    static bool isIdentical(real_t a, real_t b);
    static bool isNaN(real_t r);
    static bool isSNaN(real_t r);
    static bool isInfinity(real_t r);

    static real_t parse(const char *literal, bool *isOutOfRange = NULL);
    static int sprint(char *str, char fmt, real_t x);

    // Constant real values 0, 1, -1 and 0.5.
    static real_t zero;
    static real_t one;
    static real_t minusone;
    static real_t half;
};

#endif
