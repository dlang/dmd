// PERMUTE_ARGS:

import std.stdio;
import std.c.stdio;
import std.math;
//import std.math2;

extern (C) int sprintf(char*, in char*, ...);

static if(real.sizeof > double.sizeof)
    enum uint useDigits = 16;
else
    enum uint useDigits = 15;

/******************************************
 * Compare floating point numbers to n decimal digits of precision.
 * Returns:
 *	1	match
 *	0	nomatch
 */

private int equals(real x, real y, uint ndigits)
{
    printf("equals: x = %Lg\n", x);
    printf("equals: y = %Lg\n", y);
    printf("equals: ndigits = %d\n", ndigits);
    if (signbit(x) != signbit(y))
	return 0;

    if (isinf(x) && isinf(y))
	return 1;
    if (isinf(x) || isinf(y))
	return 0;

    if (isnan(x) && isnan(y))
	return 1;
    if (isnan(x) || isnan(y))
	return 0;

    char bufx[30];
    char bufy[30];
    assert(ndigits < bufx.length);

    int ix;
    int iy;
    ix = sprintf(bufx.ptr, "%.*Lg", ndigits, x);
    assert(ix < bufx.length);
    iy = sprintf(bufy.ptr, "%.*Lg", ndigits, y);
    assert(ix < bufy.length);

    printf("bufx = '%.*s'\n", ix, bufx[0 .. ix].ptr);
    printf("bufy = '%.*s'\n", iy, bufy[0 .. iy].ptr);

    return bufx[0 .. ix] == bufy[0 .. iy];
}

/****************************************
 * Simple function to compare two floating point values
 * to a specified precision.
 * Returns:
 *	1	match
 *	0	nomatch
 */

private int mfeq(real x, real y, real precision)
{
    if (x == y)
	return 1;
    if (isnan(x))
	return isnan(y);
    if (isnan(y))
	return 0;
    return fabs(x - y) <= precision;
}


/*************************************************/

void testldexp()
{
    static real vals[][3] =	// value,exp,ldexp
    [
	[	0,	0,	0],
	[	1,	0,	1],
	[	-1,	0,	-1],
	[	1,	1,	2],
	[	123,	10,	125952],
	[	real.max,	int.max,	real.infinity],
	[	real.max,	-int.max,	0],
	[	real.min,	-int.max,	0],
    ];
    int i;

    for (i = 0; i < vals.length; i++)
    {
	real x = vals[i][0];
	int exp = cast(int)vals[i][1];
	real z = vals[i][2];
	real l = ldexp(x, exp);

	//printf("ldexp(%Lg, %d) = %Lg, should be %Lg\n", x, exp, l, z);
	assert(equals(z, l, 7));
    }
}

/*************************************************/

void testldexp2()
{
    real r;

    writefln("%f", ldexp(3.0L, 3));
    r = ldexp(3.0L, 3);
    assert(r == 24);

    writefln("%f", ldexp(cast(real) 3.0, cast(int) 3));
    r = ldexp(cast(real) 3.0, cast(int) 3);
    assert(r == 24);

    real n = 3.0;
    int exp = 3;
    writefln("%f", ldexp(n, exp));
    r = ldexp(n, exp);
    assert(r == 24);
}


/*************************************************/

void testacos()
{
    assert(equals(acos(0.5), std.math.PI / 3, useDigits));
}

/*************************************************/

void testasin()
{
    assert(equals(asin(0.5), PI / 6, useDigits));
}

/*************************************************/

void testatan()
{
    assert(equals(atan(std.math.sqrt(3.0)), PI / 3, useDigits));
}

/*************************************************/

void testatan2()
{
    assert(equals(atan2(1.0L, std.math.sqrt(3.0L)), PI / 6, useDigits));
}

/*************************************************/

void testtan()
{
    assert(equals(tan(PI / 3), std.math.sqrt(3.0), useDigits));
}

/*************************************************/

void testfrexp()
{
    int exp;
    real mantissa = frexp(123.456, exp);
    assert(equals(mantissa * pow(2.0L, cast(real)exp), 123.456, 19));

    assert(frexp(-real.nan, exp) && exp == int.min);
    assert(frexp(real.nan, exp) && exp == int.min);
    assert(frexp(-real.infinity, exp) == -real.infinity && exp == int.min);
    assert(frexp(real.infinity, exp) == real.infinity && exp == int.max);
    assert(frexp(-0.0, exp) == -0.0 && exp == 0);
    assert(frexp(0.0, exp) == 0.0 && exp == 0);
}

/*************************************************/

void testceil()
{
    assert(ceil(+123.456) == +124);
    assert(ceil(-123.456) == -123);
}

/*************************************************/

void testfloor()
{
    assert(floor(+123.456) == +123);
    assert(floor(-123.456) == -124);
}

/*************************************************/

void testlog10()
{
    assert(equals(log10(1000), 3, 19));
}

/*************************************************/

void testlog()
{
    assert(equals(log(E), 1, 19));
}

/*************************************************/

void testlog2()
{
    assert(equals(log2(1024), 10, 19));
}

/*************************************************/

void testlog1p()
{
    assert(equals(log1p(E - 1), 1, 19));
}

/*************************************************/

void testexp()
{
    printf("exp(3.0) = %Lg, %Lg\n", exp(3.0), E * E * E);
    assert(equals(exp(3.0), E * E * E, useDigits));
}

/*************************************************/

void testpow()
{
    assert(equals(pow(2.0L, 10.0L), 1024, 19));
}

/*************************************************/

void testcosh()
{
    assert(equals(cosh(1.0), (E + 1.0 / E) / 2, useDigits));
}

/*************************************************/

void testsinh()
{
    assert(equals(sinh(1.0), (E - 1.0 / E) / 2, useDigits));
}

/*************************************************/

void testtanh()
{
    assert(equals(tanh(1.0), sinh(1.0) / cosh(1.0), 15));
}

/*************************************************/

void testacosh()
{
    assert(isnan(acosh(0.5)));
    assert(equals(acosh(cosh(3.0)), 3, useDigits));
}

/*************************************************/

void testasinh()
{
    assert(asinh(0.0) == 0);
    assert(equals(asinh(sinh(3.0)), 3, useDigits));
}

/*************************************************/

void testatanh()
{
    assert(atanh(0.0) == 0);
    assert(equals(atanh(tanh(0.5L)), 0.5, useDigits));
}

/*************************************************/

void testerf()
{
}

/*************************************************/

void testerfc()
{
}

/*************************************************/

void testexp2()
{
    assert( core.stdc.math.exp2f(0.0f) == 1 );
    assert( core.stdc.math.exp2 (0.0)  == 1 );
    assert( core.stdc.math.exp2l(0.0L) == 1 );
}

/*************************************************/

void testlogb()
{
}

/*************************************************/

void testcbrt()
{
    assert(equals(cbrt(125), 5, 19));
    assert(equals(cbrt(-125), -5, 19));
}

/*************************************************/

void testilogb()
{
}

/*************************************************/

enum ZX80 = sqrt(7.0f);
enum ZX81 = sqrt(7.0);
enum ZX82 = sqrt(7.0L);

void testsqrt()
{
}

/*************************************************/

void test1()
{
    float f = sqrt(2.0f);
    printf("%g\n", f);
    assert(fabs(f * f - 2.0f) < .00001);

    double d = sqrt(2.0);
    printf("%g\n", d);
    assert(fabs(d * d - 2.0) < .00001);

    real r = sqrt(2.0L);
    printf("%Lg\n", r);
    assert(fabs(r * r - 2.0) < .00001);
}

void test2()
{
    float f = fabs(-2.0f);
    printf("%g\n", f);
    assert(f == 2);

    double d = fabs(-2.0);
    printf("%g\n", d);
    assert(d == 2);

    real r = fabs(-2.0L);
    printf("%Lg\n", r);
    assert(r == 2);
}


void test3()
{
    float f = sin(-2.0f);
    printf("%g\n", f);
    assert(fabs(f - -0.909297f) < .00001);

    double d = sin(-2.0);
    printf("%g\n", d);
    assert(fabs(d - -0.909297f) < .00001);

    real r = sin(-2.0L);
    printf("%Lg\n", r);
    assert(fabs(r - -0.909297f) < .00001);
}


void test4()
{
    float f = cos(-2.0f);
    printf("%g\n", f);
    assert(fabs(f - -0.416147f) < .00001);

    double d = cos(-2.0);
    printf("%g\n", d);
    assert(fabs(d - -0.416147f) < .00001);

    real r = cos(-2.0L);
    printf("%Lg\n", r);
    assert(fabs(r - -0.416147f) < .00001);
}


void test5()
{
    float f = tan(-2.0f);
    printf("%g\n", f);
    assert(fabs(f - 2.18504f) < .00001);

    double d = tan(-2.0);
    printf("%g\n", d);
    assert(fabs(d - 2.18504f) < .00001);

    real r = tan(-2.0L);
    printf("%Lg\n", r);
    assert(fabs(r - 2.18504f) < .00001);
}


/*************************************************/

int main()
{
    testldexp();
    testldexp2();
    testacos();
    testasin();
    testatan();
    testatan2();
    testtan();
    testfrexp();
    testceil();
    testfloor();
    testlog10();
    testlog();
    testlog2();
    testlog1p();
    testexp();
    testpow();
    testcosh();
    testsinh();
    testtanh();
    testacosh();
    testasinh();
    testatanh();
    testerf();
    testerfc();
    testexp2();
    testlogb();
    testcbrt();
    testilogb();
    testsqrt();

    test1();
    test2();
    test3();
    test4();
    test5();

    printf("Success\n");
    return 0;
}
