// public domain

#ifndef BCOMPLEX_H
#define BCOMPLEX_H 1

#if _MSC_VER
#include "longdouble.h"
#define fabsl fabs
#else
typedef long double longdouble;
#endif

// Avoid interfering with system <complex.h> and other
// such; roll our own for reliable bootstrapping

struct Complex_f
{   float re, im;

    static Complex_f div(Complex_f &x, Complex_f &y);
    static Complex_f mul(Complex_f &x, Complex_f &y);
    static longdouble abs(Complex_f &z);
    static Complex_f sqrtc(Complex_f &z);
};

struct Complex_d
{   double re, im;

    static Complex_d div(Complex_d &x, Complex_d &y);
    static Complex_d mul(Complex_d &x, Complex_d &y);
    static longdouble abs(Complex_d &z);
    static Complex_d sqrtc(Complex_d &z);
};

struct Complex_ld
{   longdouble re, im;

    static Complex_ld div(Complex_ld &x, Complex_ld &y);
    static Complex_ld mul(Complex_ld &x, Complex_ld &y);
    static longdouble abs(Complex_ld &z);
    static Complex_ld sqrtc(Complex_ld &z);
};

#endif
