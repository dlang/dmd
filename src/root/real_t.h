
/* Copyright (c) 1999-2016 by Digital Mars
 * All Rights Reserved, written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * (See accompanying file LICENSE or copy at http://www.boost.org/LICENSE_1_0.txt)
 * https://github.com/D-Programming-Language/dmd/blob/master/src/root/port.h
 */

#ifndef REAL_T_H
#define REAL_T_H

#include "longdouble.h"

typedef longdouble real_t;

struct TargetReal
{
    static real_t  sin(real_t x);
    static real_t  cos(real_t x);
    static real_t  tan(real_t x);
    static real_t sqrt(real_t x);
    static real_t fabs(real_t x);

    static bool isIdentical(real_t a, real_t b);
    static bool isNaN(real_t r);
    static bool isSignallingNaN(real_t r);
    static bool isInfinity(real_t r);

    static real_t parse(const char *literal, bool *isOutOfRange = NULL);
    static int sprint(char *str, char fmt, real_t x);
};

#endif
