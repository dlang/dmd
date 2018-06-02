/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   public domain
 * License:     public domain
 * Source:      $(DMDSRC backend/_bcomplex.d)
 */

module dmd.backend.bcomplex;

//import dmd.backend.cdef : targ_ldouble;
public import dmd.root.longdouble;
alias targ_ldouble = longdouble;

import core.stdc.math;

extern (C++):
@nogc:
nothrow:

// Roll our own for reliable bootstrapping


struct Complex_f
{
    float re, im;

    static Complex_f div(ref Complex_f x, ref Complex_f y)
    {
        Complex_f q;
        real r;
        real den;

        if (fabs(y.re) < fabs(y.im))
        {
            r = y.re / y.im;
            den = y.im + r * y.re;
            q.re = (x.re * r + x.im) / den;
            q.im = (x.im * r - x.re) / den;
        }
        else
        {
            r = y.im / y.re;
            den = y.re + r * y.im;
            q.re = (x.re + r * x.im) / den;
            q.im = (x.im - r * x.re) / den;
        }
        return q;
    }

    static Complex_f mul(ref Complex_f x, ref Complex_f y)
    {
        Complex_f p;

        p.re = x.re * y.re - x.im * y.im;
        p.im = x.im * y.re + x.re * y.im;
        return p;
    }

    static real abs(ref Complex_f z)
    {
        real x,y,ans,temp;

        x = fabs(z.re);
        y = fabs(z.im);
        if (x == 0)
            ans = y;
        else if (y == 0)
            ans = x;
        else if (x > y)
        {
            temp = y / x;
            ans = x * sqrt(1 + temp * temp);
        }
        else
        {
            temp = x / y;
            ans = y * sqrt(1 + temp * temp);
        }
        return ans;
    }

    static Complex_f sqrtc(ref Complex_f z)
    {
        Complex_f c;
        real x,y,w,r;

        if (z.re == 0 && z.im == 0)
        {
            c.re = 0;
            c.im = 0;
        }
        else
        {
            x = fabs(z.re);
            y = fabs(z.im);
            if (x >= y)
            {
                r = y / x;
                w = sqrt(x) * sqrt(0.5 * (1 + sqrt(1 + r * r)));
            }
            else
            {
                r = x / y;
                w = sqrt(y) * sqrt(0.5 * (r + sqrt(1 + r * r)));
            }
            if (z.re >= 0)
            {
                c.re = w;
                c.im = z.im / (w + w);
            }
            else
            {
                c.im = (z.im >= 0) ? w : -w;
                c.re = z.im / (c.im + c.im);
            }
        }
        return c;
    }
}

struct Complex_d
{
    double re, im;

    static Complex_d div(ref Complex_d x, ref Complex_d y)
    {
        Complex_d q;
        real r;
        real den;

        if (fabs(y.re) < fabs(y.im))
        {
            r = y.re / y.im;
            den = y.im + r * y.re;
            q.re = (x.re * r + x.im) / den;
            q.im = (x.im * r - x.re) / den;
        }
        else
        {
            r = y.im / y.re;
            den = y.re + r * y.im;
            q.re = (x.re + r * x.im) / den;
            q.im = (x.im - r * x.re) / den;
        }
        return q;
    }

    static Complex_d mul(ref Complex_d x, ref Complex_d y)
    {
        Complex_d p;
        p.re = x.re * y.re - x.im * y.im;
        p.im = x.im * y.re + x.re * y.im;
        return p;
    }

    static real abs(ref Complex_d z)
    {
        real x,y,ans,temp;
        x = fabs(z.re);
        y = fabs(z.im);
        if (x == 0)
            ans = y;
        else if (y == 0)
            ans = x;
        else if (x > y)
        {
            temp = y / x;
            ans = x * sqrt(1 + temp * temp);
        }
        else
        {
            temp = x / y;
            ans = y * sqrt(1 + temp * temp);
        }
        return ans;
    }

    static Complex_d sqrtc(ref Complex_d z)
    {
        Complex_d c;
        real x,y,w,r;

        if (z.re == 0 && z.im == 0)
        {
            c.re = 0;
            c.im = 0;
        }
        else
        {
            x = fabs(z.re);
            y = fabs(z.im);
            if (x >= y)
            {
                r = y / x;
                w = sqrt(x) * sqrt(0.5 * (1 + sqrt(1 + r * r)));
            }
            else
            {
                r = x / y;
                w = sqrt(y) * sqrt(0.5 * (r + sqrt(1 + r * r)));
            }
            if (z.re >= 0)
            {
                c.re = w;
                c.im = z.im / (w + w);
            }
            else
            {
                c.im = (z.im >= 0) ? w : -w;
                c.re = z.im / (2 * c.im);
            }
        }
        return c;
    }
}


struct Complex_ld
{
    targ_ldouble re, im;

    static Complex_ld div(ref Complex_ld x, ref Complex_ld y)
    {
        Complex_ld q = void;
        targ_ldouble r;
        targ_ldouble den;

        if (fabsl(y.re) < fabsl(y.im))
        {
            r = y.re / y.im;
            den = y.im + r * y.re;
            q.re = (x.re * r + x.im) / den;
            q.im = (x.im * r - x.re) / den;
        }
        else
        {
            r = y.im / y.re;
            den = y.re + r * y.im;
            q.re = (x.re + r * x.im) / den;
            q.im = (x.im - r * x.re) / den;
        }
        return q;
    }

    static Complex_ld mul(ref Complex_ld x, ref Complex_ld y)
    {
        Complex_ld p = void;

        p.re = x.re * y.re - x.im * y.im;
        p.im = x.im * y.re + x.re * y.im;
        return p;
    }

    static targ_ldouble abs(ref Complex_ld z)
    {
        targ_ldouble x,y,ans,temp;

        x = fabsl(z.re);
        y = fabsl(z.im);
        if (x == 0)
            ans = y;
        else if (y == 0)
            ans = x;
        else if (x > y)
        {
            temp = y / x;
            ans = x * sqrt(1 + temp * temp);
        }
        else
        {
            temp = x / y;
            ans = y * sqrt(1 + temp * temp);
        }
        return ans;
    }

    static Complex_ld sqrtc(ref Complex_ld z)
    {
        Complex_ld c = void;
        targ_ldouble x,y,w,r;

        if (z.re == 0 && z.im == 0)
        {
            c.re = 0;
            c.im = 0;
        }
        else
        {
            x = fabsl(z.re);
            y = fabsl(z.im);
            if (x >= y)
            {
                r = y / x;
                w = sqrt(x) * sqrt(0.5 * (1 + sqrt(1 + r * r)));
            }
            else
            {
                r = x / y;
                w = sqrt(y) * sqrt(0.5 * (r + sqrt(1 + r * r)));
            }
            if (z.re >= 0)
            {
                c.re = w;
                c.im = z.im / (w + w);
            }
            else
            {
                c.im = (z.im >= 0) ? w : -w;
                c.re = z.im / (c.im + c.im);
            }
        }
        return c;
    }
}
