// public domain

#include <math.h>

#include "bcomplex.h"

/*********************************************************/

Complex_ld Complex_ld::div(Complex_ld &x, Complex_ld &y)
{
    Complex_ld q;
    longdouble r;
    longdouble den;

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

Complex_ld Complex_ld::mul(Complex_ld &x, Complex_ld &y)
{
    Complex_ld p;

    p.re = x.re * y.re - x.im * y.im;
    p.im = x.im * y.re + x.re * y.im;
    return p;
}

longdouble Complex_ld::abs(Complex_ld &z)
{
    longdouble x,y,ans,temp;

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

Complex_ld Complex_ld::sqrtc(Complex_ld &z)
{
    Complex_ld c;
    longdouble x,y,w,r;

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

/*********************************************************/

Complex_d Complex_d::div(Complex_d &x, Complex_d &y)
{
    Complex_d q;
    longdouble r;
    longdouble den;

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

Complex_d Complex_d::mul(Complex_d &x, Complex_d &y)
{
    Complex_d p;

    p.re = x.re * y.re - x.im * y.im;
    p.im = x.im * y.re + x.re * y.im;
    return p;
}

longdouble Complex_d::abs(Complex_d &z)
{
    longdouble x,y,ans,temp;

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

Complex_d Complex_d::sqrtc(Complex_d &z)
{
    Complex_d c;
    longdouble x,y,w,r;

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

/*********************************************************/

Complex_f Complex_f::div(Complex_f &x, Complex_f &y)
{
    Complex_f q;
    longdouble r;
    longdouble den;

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

Complex_f Complex_f::mul(Complex_f &x, Complex_f &y)
{
    Complex_f p;

    p.re = x.re * y.re - x.im * y.im;
    p.im = x.im * y.re + x.re * y.im;
    return p;
}

longdouble Complex_f::abs(Complex_f &z)
{
    longdouble x,y,ans,temp;

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

Complex_f Complex_f::sqrtc(Complex_f &z)
{
    Complex_f c;
    longdouble x,y,w,r;

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


