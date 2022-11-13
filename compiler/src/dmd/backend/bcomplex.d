/**
 * A complex number implementation
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   public domain
 * License:     public domain
 * Source:      $(DMDSRC backend/_bcomplex.d)
 */

module dmd.backend.bcomplex;

public import dmd.root.longdouble : targ_ldouble = longdouble;
import core.stdc.math : fabs, fabsl, sqrt;
version(CRuntime_Microsoft)
    private import dmd.root.longdouble : fabsl, sqrt; // needed if longdouble is longdouble_soft

extern (C++):
@nogc:
@safe:
nothrow:

// Roll our own for reliable bootstrapping


struct Complex_f
{
nothrow:
    float re, im;

    static Complex_f div(ref Complex_f x, ref Complex_f y)
    {
        if (fabs(y.re) < fabs(y.im))
        {
            const r = y.re / y.im;
            const den = y.im + r * y.re;
            return Complex_f(cast(float)((x.re * r + x.im) / den),
                             cast(float)((x.im * r - x.re) / den));
        }
        else
        {
            const r = y.im / y.re;
            const den = y.re + r * y.im;
            return Complex_f(cast(float)((x.re + r * x.im) / den),
                             cast(float)((x.im - r * x.re) / den));
        }
    }

    static Complex_f mul(ref Complex_f x, ref Complex_f y) pure
    {
        return Complex_f(x.re * y.re - x.im * y.im,
                         x.im * y.re + x.re * y.im);
    }

    static targ_ldouble abs(ref Complex_f z)
    {
        const targ_ldouble x = fabs(z.re);
        const targ_ldouble y = fabs(z.im);
        if (x == 0)
            return y;
        else if (y == 0)
            return x;
        else if (x > y)
        {
            const targ_ldouble temp = y / x;
            return x * sqrt(1 + temp * temp);
        }
        else
        {
            const targ_ldouble temp = x / y;
            return y * sqrt(1 + temp * temp);
        }
    }

    static Complex_f sqrtc(ref Complex_f z)
    {
        if (z.re == 0 && z.im == 0)
        {
            return Complex_f(0, 0);
        }
        else
        {
            const targ_ldouble x = fabs(z.re);
            const targ_ldouble y = fabs(z.im);
            targ_ldouble r, w;
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
                return Complex_f(cast(float)w, (z.im / cast(float)(w + w)));
            }
            else
            {
                const cim = (z.im >= 0) ? w : -w;
                return Complex_f((z.im / cast(float)(cim + cim)), cast(float)cim);
            }
        }
    }
}

struct Complex_d
{
nothrow:
    double re, im;

    static Complex_d div(ref Complex_d x, ref Complex_d y)
    {
        if (fabs(y.re) < fabs(y.im))
        {
            const targ_ldouble r = y.re / y.im;
            const targ_ldouble den = y.im + r * y.re;
            return Complex_d(cast(double)((x.re * r + x.im) / den),
                             cast(double)((x.im * r - x.re) / den));
        }
        else
        {
            const targ_ldouble r = y.im / y.re;
            const targ_ldouble den = y.re + r * y.im;
            return Complex_d(cast(double)((x.re + r * x.im) / den),
                             cast(double)((x.im - r * x.re) / den));
        }
    }

    static Complex_d mul(ref Complex_d x, ref Complex_d y) pure
    {
        return Complex_d(x.re * y.re - x.im * y.im,
                         x.im * y.re + x.re * y.im);
    }

    static targ_ldouble abs(ref Complex_d z)
    {
        const targ_ldouble x = fabs(z.re);
        const targ_ldouble y = fabs(z.im);
        if (x == 0)
            return y;
        else if (y == 0)
            return x;
        else if (x > y)
        {
            const targ_ldouble temp = y / x;
            return x * sqrt(1 + temp * temp);
        }
        else
        {
            const targ_ldouble temp = x / y;
            return y * sqrt(1 + temp * temp);
        }
    }

    static Complex_d sqrtc(ref Complex_d z)
    {
        if (z.re == 0 && z.im == 0)
        {
            return Complex_d(0, 0);
        }
        else
        {
            const targ_ldouble x = fabs(z.re);
            const targ_ldouble y = fabs(z.im);
            targ_ldouble r, w;
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
                return Complex_d(cast(double)w, (z.im / cast(double)(w + w)));
            }
            else
            {
                const cim = (z.im >= 0) ? w : -w;
                return Complex_d((z.im / cast(double)(cim + cim)), cast(double)cim);
            }
        }
    }
}


struct Complex_ld
{
nothrow:
    targ_ldouble re, im;

    static Complex_ld div(ref Complex_ld x, ref Complex_ld y)
    {
        if (fabsl(y.re) < fabsl(y.im))
        {
            const targ_ldouble r = y.re / y.im;
            const targ_ldouble den = y.im + r * y.re;
            return Complex_ld((x.re * r + x.im) / den,
                              (x.im * r - x.re) / den);
        }
        else
        {
            const targ_ldouble r = y.im / y.re;
            const targ_ldouble den = y.re + r * y.im;
            return Complex_ld((x.re + r * x.im) / den,
                              (x.im - r * x.re) / den);
        }
    }

    static Complex_ld mul(ref Complex_ld x, ref Complex_ld y) pure
    {
        return Complex_ld(x.re * y.re - x.im * y.im,
                          x.im * y.re + x.re * y.im);
    }

    static targ_ldouble abs(ref Complex_ld z)
    {
        const targ_ldouble x = fabsl(z.re);
        const targ_ldouble y = fabsl(z.im);
        if (x == 0)
            return y;
        else if (y == 0)
            return x;
        else if (x > y)
        {
            const targ_ldouble temp = y / x;
            return x * sqrt(1 + temp * temp);
        }
        else
        {
            const targ_ldouble temp = x / y;
            return y * sqrt(1 + temp * temp);
        }
    }

    static Complex_ld sqrtc(ref Complex_ld z)
    {
        if (z.re == 0 && z.im == 0)
        {
            return Complex_ld(targ_ldouble(0), targ_ldouble(0));
        }
        else
        {
            const targ_ldouble x = fabsl(z.re);
            const targ_ldouble y = fabsl(z.im);
            targ_ldouble r, w;
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
                return Complex_ld(w, z.im / (w + w));
            }
            else
            {
                const cim = (z.im >= 0) ? w : -w;
                return Complex_ld(z.im / (cim + cim), cim);
            }
        }
    }
}
