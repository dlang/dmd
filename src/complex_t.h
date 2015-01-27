
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/complex_t.h
 */

#ifndef DMD_COMPLEX_T_H
#define DMD_COMPLEX_T_H

/* Roll our own complex type for compilers that don't support complex
 */

struct complex_t
{
    longdouble re;
    longdouble im;

    complex_t() { this->re = 0; this->im = 0; }
    complex_t(longdouble re) { this->re = re; this->im = 0; }
    complex_t(double re) { this->re = re; this->im = 0; }
    complex_t(longdouble re, longdouble im) { this->re = re; this->im = im; }
    complex_t(double re, double im) { this->re = re; this->im = im; }

    complex_t operator + (complex_t y) { complex_t r; r.re = re + y.re; r.im = im + y.im; return r; }
    complex_t operator - (complex_t y) { complex_t r; r.re = re - y.re; r.im = im - y.im; return r; }
    complex_t operator - () { complex_t r; r.re = -re; r.im = -im; return r; }
    complex_t operator * (complex_t y) { return complex_t(re * y.re - im * y.im, im * y.re + re * y.im); }

    complex_t operator / (complex_t y)
    {
        longdouble abs_y_re = y.re < 0 ? -y.re : y.re;
        longdouble abs_y_im = y.im < 0 ? -y.im : y.im;
        longdouble r, den;

        if (abs_y_re < abs_y_im)
        {
            r = y.re / y.im;
            den = y.im + r * y.re;
            return complex_t((re * r + im) / den,
                             (im * r - re) / den);
        }
        else
        {
            r = y.im / y.re;
            den = y.re + r * y.im;
            return complex_t((re + r * im) / den,
                             (im - r * re) / den);
        }
    }

    operator bool () { return re || im; }

    int operator == (complex_t y) { return re == y.re && im == y.im; }
    int operator != (complex_t y) { return re != y.re || im != y.im; }
};

inline complex_t operator * (longdouble x, complex_t y) { return complex_t(x) * y; }
inline complex_t operator * (complex_t x, longdouble y) { return x * complex_t(y); }
inline complex_t operator / (complex_t x, longdouble y) { return x / complex_t(y); }


inline longdouble creall(complex_t x)
{
    return x.re;
}

inline longdouble cimagl(complex_t x)
{
    return x.im;
}

#endif
