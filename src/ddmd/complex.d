/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _complex.d)
 */

module ddmd.complex;

import ddmd.root.ctfloat;

struct complex_t
{
    real_t re;
    real_t im;

    this() @disable;

    this(real_t re)
    {
        this(re, CTFloat.zero);
    }

    this(real_t re, real_t im)
    {
        this.re = re;
        this.im = im;
    }

    complex_t opAdd(complex_t y)
    {
        return complex_t(re + y.re, im + y.im);
    }

    complex_t opSub(complex_t y)
    {
        return complex_t(re - y.re, im - y.im);
    }

    complex_t opNeg()
    {
        return complex_t(-re, -im);
    }

    complex_t opMul(complex_t y)
    {
        return complex_t(re * y.re - im * y.im, im * y.re + re * y.im);
    }

    complex_t opMul_r(real_t x)
    {
        return complex_t(x) * this;
    }

    complex_t opMul(real_t y)
    {
        return this * complex_t(y);
    }

    complex_t opDiv(real_t y)
    {
        return this / complex_t(y);
    }

    complex_t opDiv(complex_t y)
    {
        if (CTFloat.fabs(y.re) < CTFloat.fabs(y.im))
        {
            const r = y.re / y.im;
            const den = y.im + r * y.re;
            return complex_t((re * r + im) / den, (im * r - re) / den);
        }
        else
        {
            const r = y.im / y.re;
            const den = y.re + r * y.im;
            return complex_t((re + r * im) / den, (im - r * re) / den);
        }
    }

    bool opCast(T : bool)()
    {
        return re || im;
    }

    int opEquals(complex_t y)
    {
        return re == y.re && im == y.im;
    }
}

extern (C++) real_t creall(complex_t x)
{
    return x.re;
}

extern (C++) real_t cimagl(complex_t x)
{
    return x.im;
}
