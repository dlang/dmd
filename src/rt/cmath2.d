/**
 * Runtime support for complex arithmetic code generation (for Posix).
 *
 * Copyright: Copyright Digital Mars 2001 - 2011.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Walter Bright, Sean Kelly
 */

/*          Copyright Digital Mars 2001 - 2011.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.cmath2;

private import core.stdc.math;

extern (C):

/****************************
 * Multiply two complex floating point numbers, x and y.
 * Input:
 *      x.re    ST3
 *      x.im    ST2
 *      y.re    ST1
 *      y.im    ST0
 * Output:
 *      ST1     real part
 *      ST0     imaginary part
 */

void _Cmul()
{
    // p.re = x.re * y.re - x.im * y.im;
    // p.im = x.im * y.re + x.re * y.im;
    asm
    {   naked                   ;
        fld     ST(1)           ; // x.re
        fmul    ST,ST(4)        ; // ST0 = x.re * y.re

        fld     ST(1)           ; // y.im
        fmul    ST,ST(4)        ; // ST0 = x.im * y.im

        fsubp   ST(1),ST        ; // ST0 = x.re * y.re - x.im * y.im

        fld     ST(3)           ; // x.im
        fmul    ST,ST(3)        ; // ST0 = x.im * y.re

        fld     ST(5)           ; // x.re
        fmul    ST,ST(3)        ; // ST0 = x.re * y.im

        faddp   ST(1),ST        ; // ST0 = x.im * y.re + x.re * y.im

        fxch    ST(4),ST        ;
        fstp    ST(0)           ;
        fxch    ST(4),ST        ;
        fstp    ST(0)           ;
        fstp    ST(0)           ;
        fstp    ST(0)           ;

        ret                     ;
    }
/+
    if (isnan(x) && isnan(y))
    {
        // Recover infinities that computed as NaN+ iNaN ...
        int recalc = 0;
        if ( isinf( a) || isinf( b) )
        {   // z is infinite
            // "Box" the infinity and change NaNs in the other factor to 0
            a = copysignl( isinf( a) ? 1.0 : 0.0, a);
            b = copysignl( isinf( b) ? 1.0 : 0.0, b);
            if (isnan( c)) c = copysignl( 0.0, c);
            if (isnan( d)) d = copysignl( 0.0, d);
            recalc = 1;
        }
        if (isinf(c) || isinf(d))
        {   // w is infinite
            // "Box" the infinity and change NaNs in the other factor to 0
            c = copysignl( isinf( c) ? 1.0 : 0.0, c);
            d = copysignl( isinf( d) ? 1.0 : 0.0, d);
            if (isnan( a)) a = copysignl( 0.0, a);
            if (isnan( b)) b = copysignl( 0.0, b);
            recalc = 1;
        }
        if (!recalc && (isinf(ac) || isinf(bd) ||
            isinf(ad) || isinf(bc)))
        {
            // Recover infinities from overflow by changing NaNs to 0 ...
            if (isnan( a)) a = copysignl( 0.0, a);
            if (isnan( b)) b = copysignl( 0.0, b);
            if (isnan( c)) c = copysignl( 0.0, c);
            if (isnan( d)) d = copysignl( 0.0, d);
            recalc = 1;
        }
        if (recalc)
        {
            x = INFINITY * (a * c - b * d);
            y = INFINITY * (a * d + b * c);
        }
    }
+/
}

/****************************
 * Divide two complex floating point numbers, x / y.
 * Input:
 *      x.re    ST3
 *      x.im    ST2
 *      y.re    ST1
 *      y.im    ST0
 * Output:
 *      ST1     real part
 *      ST0     imaginary part
 */

void _Cdiv()
{
    real x_re, x_im;
    real y_re, y_im;
    real q_re, q_im;
    real r;
    real den;

    asm
    {
        fstp    y_im    ;
        fstp    y_re    ;
        fstp    x_im    ;
        fstp    x_re    ;
    }

    if (fabs(y_re) < fabs(y_im))
    {
        r = y_re / y_im;
        den = y_im + r * y_re;
        q_re = (x_re * r + x_im) / den;
        q_im = (x_im * r - x_re) / den;
    }
    else
    {
        r = y_im / y_re;
        den = y_re + r * y_im;
        q_re = (x_re + r * x_im) / den;
        q_im = (x_im - r * x_re) / den;
    }
//printf("q.re = %g, q.im = %g\n", (double)q_re, (double)q_im);
/+
    if (isnan(q_re) && isnan(q_im))
    {
        real denom = y_re * y_re + y_im * y_im;

        // non-zero / zero
        if (denom == 0.0 && (!isnan(x_re) || !isnan(x_im)))
        {
            q_re = copysignl(INFINITY, y_re) * x_re;
            q_im = copysignl(INFINITY, y_re) * x_im;
        }
        // infinite / finite
        else if ((isinf(x_re) || isinf(x_im)) && isfinite(y_re) && isfinite(y_im))
        {
            x_re = copysignl(isinf(x_re) ? 1.0 : 0.0, x_re);
            x_im = copysignl(isinf(x_im) ? 1.0 : 0.0, x_im);
            q_re = INFINITY * (x_re * y_re + x_im * y_im);
            q_im = INFINITY * (x_im * y_re - x_re * y_im);
        }
        // finite / infinite
        else if (isinf(logbw) && isfinite(x_re) && isfinite(x_im))
        {
            y_re = copysignl(isinf(y_re) ? 1.0 : 0.0, y_re);
            y_im = copysignl(isinf(y_im) ? 1.0 : 0.0, y_im);
            q_re = 0.0 * (x_re * y_re + x_im * y_im);
            q_im = 0.0 * (x_im * y_re - x_re * y_im);
        }
    }
    return q_re + q_im * 1.0i;
+/
    asm
    {
        fld     q_re;
        fld     q_im;
    }
}

/****************************
 * Compare two complex floating point numbers, x and y.
 * Input:
 *      x.re    ST3
 *      x.im    ST2
 *      y.re    ST1
 *      y.im    ST0
 * Output:
 *      8087 stack is cleared
 *      flags set
 */

void _Ccmp()
{
  version (D_InlineAsm_X86)
    asm
    {   naked                   ;
        fucomp  ST(2)           ; // compare x.im and y.im
        fstsw   AX              ;
        sahf                    ;
        jne     L1              ;
        jp      L1              ; // jmp if NAN
        fucomp  ST(2)           ; // compare x.re and y.re
        fstsw   AX              ;
        sahf                    ;
        fstp    ST(0)           ; // pop
        fstp    ST(0)           ; // pop
        ret                     ;

      L1:
        fstp    ST(0)           ; // pop
        fstp    ST(0)           ; // pop
        fstp    ST(0)           ; // pop
        ret                     ;
    }
  else version (D_InlineAsm_X86_64)
    asm
    {   naked                   ;
        fucomip  ST(2)          ; // compare x.im and y.im
        jne     L1              ;
        jp      L1              ; // jmp if NAN
        fucomip  ST(2)          ; // compare x.re and y.re
        fstp    ST(0)           ; // pop
        fstp    ST(0)           ; // pop
        ret                     ;

      L1:
        fstp    ST(0)           ; // pop
        fstp    ST(0)           ; // pop
        fstp    ST(0)           ; // pop
        ret                     ;
    }
  else
        static assert(0);
}
