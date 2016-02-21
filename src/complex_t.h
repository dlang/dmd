
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2016 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/dlang/dmd/blob/master/src/complex_t.h
 */

#ifndef DMD_COMPLEX_T_H
#define DMD_COMPLEX_T_H

#include "real_t.h"

/* Roll our own complex type for compilers that don't support complex
 */

struct complex_t
{
    real_t re;
    real_t im;

    complex_t() { this->re = 0; this->im = 0; }
    complex_t(real_t re) { this->re = re; this->im = 0; }
    complex_t(real_t re, real_t im) { this->re = re; this->im = im; }

    complex_t operator + (complex_t y) { complex_t r; r.re = re + y.re; r.im = im + y.im; return r; }
    complex_t operator - (complex_t y) { complex_t r; r.re = re - y.re; r.im = im - y.im; return r; }
    complex_t operator - () { complex_t r; r.re = -re; r.im = -im; return r; }
    complex_t operator * (complex_t y) { return complex_t(re * y.re - im * y.im, im * y.re + re * y.im); }

    complex_t operator / (complex_t y)
    {
        if (TargetReal::fabs(y.re) < TargetReal::fabs(y.im))
        {
            real_t r = y.re / y.im;
            real_t den = y.im + r * y.re;
            return complex_t((re * r + im) / den,
                             (im * r - re) / den);
        }
        else
        {
            real_t r = y.im / y.re;
            real_t den = y.re + r * y.im;
            return complex_t((re + r * im) / den,
                             (im - r * re) / den);
        }
    }

    operator bool () { return re || im; }

    int operator == (complex_t y) { return re == y.re && im == y.im; }
    int operator != (complex_t y) { return re != y.re || im != y.im; }
};

inline complex_t operator * (real_t x, complex_t y) { return complex_t(x) * y; }
inline complex_t operator * (complex_t x, real_t y) { return x * complex_t(y); }
inline complex_t operator / (complex_t x, real_t y) { return x / complex_t(y); }


inline real_t creall(complex_t x)
{
    return x.re;
}

inline real_t cimagl(complex_t x)
{
    return x.im;
}

#endif
