/*
 *  Placed into the public domain.
 *  Written by Walter Bright
 *  www.digitalmars.com
 */


#include <math.h>

typedef struct Complex
{
    long double re;
    long double im;
} Complex;

Complex _complex_div(Complex x, Complex y)
{
    Complex q;
    long double r;
    long double den;

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

Complex _complex_mul(Complex x, Complex y)
{
    Complex p;

    p.re = x.re * y.re - x.im * y.im;
    p.im = x.im * y.re + x.re * y.im;
    return p;
}

long double _complex_abs(Complex z)
{
    long double x,y,ans,temp;

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

Complex _complex_sqrt(Complex z)
{
    Complex c;
    long double x,y,w,r;

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
