/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   public domain
 * License:     public domain
 * Source:      $(DMDSRC backend/_bcomplex.d)
 */

module ddmd.backend.bcomplex;

extern (C++):
@nogc:
nothrow:

// Roll our own for reliable bootstrapping


struct Complex_f
{
    float re, im;

    static Complex_f div(ref Complex_f x, ref Complex_f y);
    static Complex_f mul(ref Complex_f x, ref Complex_f y);
    static real abs(ref Complex_f z);
    static Complex_f sqrtc(ref Complex_f z);
}

struct Complex_d
{
    double re, im;

    static Complex_d div(ref Complex_d x, ref Complex_d y);
    static Complex_d mul(ref Complex_d x, ref Complex_d y);
    static real abs(ref Complex_d z);
    static Complex_d sqrtc(ref Complex_d z);
}

struct Complex_ld
{
    real re, im;

    static Complex_ld div(ref Complex_ld x, Complex_ld y);
    static Complex_ld mul(ref Complex_ld x, ref Complex_ld y);
    static real abs(ref Complex_ld z);
    static Complex_ld sqrtc(ref Complex_ld z);
}
