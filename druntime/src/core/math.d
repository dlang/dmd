// Written in the D programming language.

/**
 * Builtin mathematical intrinsics
 *
 * Source: $(DRUNTIMESRC core/_math.d)
 * Macros:
 *      TABLE_SV = <table border="1" cellpadding="4" cellspacing="0">
 *              <caption>Special Values</caption>
 *              $0</table>
 *
 *      NAN = $(RED NAN)
 *      SUP = <span style="vertical-align:super;font-size:smaller">$0</span>
 *      POWER = $1<sup>$2</sup>
 *      PLUSMN = &plusmn;
 *      INFIN = &infin;
 *      PLUSMNINF = &plusmn;&infin;
 *      LT = &lt;
 *      GT = &gt;
 *
 * Copyright: Copyright Digital Mars 2000 - 2011.
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   $(HTTP digitalmars.com, Walter Bright),
 *                        Don Clugston
 */
module core.math;

import core.internal.traits;

public:
@nogc:
nothrow:
@safe:

/*****************************************
 * Returns x rounded to a long value using the FE_TONEAREST rounding mode.
 * If the integer value of x is
 * greater than long.max, the result is
 * indeterminate.
 */
deprecated("rndtonl is to be removed by 2.100. Please use round instead")
extern (C) real rndtonl(real x);

pure:
/***********************************
 * Returns cosine of x. x is in radians.
 *
 *      $(TABLE_SV
 *      $(TR $(TH x)                 $(TH cos(x)) $(TH invalid?))
 *      $(TR $(TD $(NAN))            $(TD $(NAN)) $(TD yes)     )
 *      $(TR $(TD $(PLUSMN)$(INFIN)) $(TD $(NAN)) $(TD yes)     )
 *      )
 * Bugs:
 *      Results are undefined if |x| >= $(POWER 2,64).
 */

float cos(float x);     /* intrinsic */
double cos(double x);   /* intrinsic */ /// ditto
real cos(real x);       /* intrinsic */ /// ditto

/***********************************
 * Returns sine of x. x is in radians.
 *
 *      $(TABLE_SV
 *      $(TR $(TH x)               $(TH sin(x))      $(TH invalid?))
 *      $(TR $(TD $(NAN))          $(TD $(NAN))      $(TD yes))
 *      $(TR $(TD $(PLUSMN)0.0)    $(TD $(PLUSMN)0.0) $(TD no))
 *      $(TR $(TD $(PLUSMNINF))    $(TD $(NAN))      $(TD yes))
 *      )
 * Bugs:
 *      Results are undefined if |x| >= $(POWER 2,64).
 */

float sin(float x);     /* intrinsic */
double sin(double x);   /* intrinsic */ /// ditto
real sin(real x);       /* intrinsic */ /// ditto

/*****************************************
 * Returns x rounded to a long value using the current rounding mode.
 * If the integer value of x is
 * greater than long.max, the result is
 * indeterminate.
 */

long rndtol(float x);   /* intrinsic */
long rndtol(double x);  /* intrinsic */ /// ditto
long rndtol(real x);    /* intrinsic */ /// ditto

/***************************************
 * Compute square root of x.
 *
 *      $(TABLE_SV
 *      $(TR $(TH x)         $(TH sqrt(x))   $(TH invalid?))
 *      $(TR $(TD -0.0)      $(TD -0.0)      $(TD no))
 *      $(TR $(TD $(LT)0.0)  $(TD $(NAN))    $(TD yes))
 *      $(TR $(TD +$(INFIN)) $(TD +$(INFIN)) $(TD no))
 *      )
 */

float sqrt(float x);    /* intrinsic */
double sqrt(double x);  /* intrinsic */ /// ditto
real sqrt(real x);      /* intrinsic */ /// ditto

/*******************************************
 * Compute n * 2$(SUPERSCRIPT exp)
 * References: frexp
 */

float ldexp(float n, int exp);   /* intrinsic */
double ldexp(double n, int exp); /* intrinsic */ /// ditto
real ldexp(real n, int exp);     /* intrinsic */ /// ditto

unittest {
    static if (real.mant_dig == 113)
    {
        assert(ldexp(1.0L, -16384) == 0x1p-16384L);
        assert(ldexp(1.0L, -16382) == 0x1p-16382L);
    }
    else static if (real.mant_dig == 106)
    {
        assert(ldexp(1.0L,  1023) == 0x1p1023L);
        assert(ldexp(1.0L, -1022) == 0x1p-1022L);
        assert(ldexp(1.0L, -1021) == 0x1p-1021L);
    }
    else static if (real.mant_dig == 64)
    {
        assert(ldexp(1.0L, -16384) == 0x1p-16384L);
        assert(ldexp(1.0L, -16382) == 0x1p-16382L);
    }
    else static if (real.mant_dig == 53)
    {
        assert(ldexp(1.0L,  1023) == 0x1p1023L);
        assert(ldexp(1.0L, -1022) == 0x1p-1022L);
        assert(ldexp(1.0L, -1021) == 0x1p-1021L);
    }
    else
        assert(false, "Only 128bit, 80bit and 64bit reals expected here");
}

/*******************************
 * Compute the absolute value.
 *      $(TABLE_SV
 *      $(TR $(TH x)                 $(TH fabs(x)))
 *      $(TR $(TD $(PLUSMN)0.0)      $(TD +0.0) )
 *      $(TR $(TD $(PLUSMN)$(INFIN)) $(TD +$(INFIN)) )
 *      )
 * It is implemented as a compiler intrinsic.
 * Params:
 *      x = floating point value
 * Returns: |x|
 * References: equivalent to `std.math.fabs`
 */
@safe pure nothrow @nogc
{
    float  fabs(float  x);
    double fabs(double x); /// ditto
    real   fabs(real   x); /// ditto
}

/**********************************
 * Rounds x to the nearest integer value, using the current rounding
 * mode.
 * If the return value is not equal to x, the FE_INEXACT
 * exception is raised.
 * $(B nearbyint) performs
 * the same operation, but does not set the FE_INEXACT exception.
 */
float rint(float x);    /* intrinsic */
double rint(double x);  /* intrinsic */ /// ditto
real rint(real x);      /* intrinsic */ /// ditto

/***********************************
 * Building block functions, they
 * translate to a single x87 instruction.
 */
// y * log2(x)
float yl2x(float x, float y);    /* intrinsic */
double yl2x(double x, double y);  /* intrinsic */ /// ditto
real yl2x(real x, real y);      /* intrinsic */ /// ditto
// y * log2(x +1)
float yl2xp1(float x, float y);    /* intrinsic */
double yl2xp1(double x, double y);  /* intrinsic */ /// ditto
real yl2xp1(real x, real y);      /* intrinsic */ /// ditto

unittest
{
    version (INLINE_YL2X)
    {
        assert(yl2x(1024.0L, 1) == 10);
        assert(yl2xp1(1023.0L, 1) == 10);
    }
}

/*************************************
 * Round argument to a specific precision.
 *
 * D language types specify only a minimum precision, not a maximum. The
 * `toPrec()` function forces rounding of the argument `f` to the precision
 * of the specified floating point type `T`.
 * The rounding mode used is inevitably target-dependent, but will be done in
 * a way to maximize accuracy. In most cases, the default is round-to-nearest.
 *
 * Params:
 *      T = precision type to round to
 *      f = value to convert
 * Returns:
 *      f in precision of type `T`
 */
T toPrec(T:float)(float f) { pragma(inline, false); return f; }
/// ditto
T toPrec(T:float)(double f) { pragma(inline, false); return cast(T) f; }
/// ditto
T toPrec(T:float)(real f)  { pragma(inline, false); return cast(T) f; }
/// ditto
T toPrec(T:double)(float f) { pragma(inline, false); return f; }
/// ditto
T toPrec(T:double)(double f) { pragma(inline, false); return f; }
/// ditto
T toPrec(T:double)(real f)  { pragma(inline, false); return cast(T) f; }
/// ditto
T toPrec(T:real)(float f) { pragma(inline, false); return f; }
/// ditto
T toPrec(T:real)(double f) { pragma(inline, false); return f; }
/// ditto
T toPrec(T:real)(real f)  { pragma(inline, false); return f; }

@safe unittest
{
    // Test all instantiations work with all combinations of float.
    float f = 1.1f;
    double d = 1.1;
    real r = 1.1L;
    f = toPrec!float(f + f);
    f = toPrec!float(d + d);
    f = toPrec!float(r + r);
    d = toPrec!double(f + f);
    d = toPrec!double(d + d);
    d = toPrec!double(r + r);
    r = toPrec!real(f + f);
    r = toPrec!real(d + d);
    r = toPrec!real(r + r);

    // Comparison tests.
    bool approxEqual(T)(T lhs, T rhs)
    {
        return fabs((lhs - rhs) / rhs) <= 1e-2 || fabs(lhs - rhs) <= 1e-5;
    }

    enum real PIR = 0xc.90fdaa22168c235p-2;
    enum double PID = 0x1.921fb54442d18p+1;
    enum float PIF = 0x1.921fb6p+1;
    static assert(approxEqual(toPrec!float(PIR), PIF));
    static assert(approxEqual(toPrec!double(PIR), PID));
    static assert(approxEqual(toPrec!real(PIR), PIR));
    static assert(approxEqual(toPrec!float(PID), PIF));
    static assert(approxEqual(toPrec!double(PID), PID));
    static assert(approxEqual(toPrec!real(PID), PID));
    static assert(approxEqual(toPrec!float(PIF), PIF));
    static assert(approxEqual(toPrec!double(PIF), PIF));
    static assert(approxEqual(toPrec!real(PIF), PIF));

    assert(approxEqual(toPrec!float(PIR), PIF));
    assert(approxEqual(toPrec!double(PIR), PID));
    assert(approxEqual(toPrec!real(PIR), PIR));
    assert(approxEqual(toPrec!float(PID), PIF));
    assert(approxEqual(toPrec!double(PID), PID));
    assert(approxEqual(toPrec!real(PID), PID));
    assert(approxEqual(toPrec!float(PIF), PIF));
    assert(approxEqual(toPrec!double(PIF), PIF));
    assert(approxEqual(toPrec!real(PIF), PIF));
}

/*******************************
 * Calculates x$(SUPERSCRIPT n) raised to integer power.
 *
 * Params:
 *     x = base
 *     n = exponent
 *
 * Returns:
 *     x raised to the power of n. If n is negative the result is 1 / pow(x, -n),
 *     which is calculated as integer division with remainder. This may result in
 *     a division by zero error.
 *
 *     If both x and n are 0, the result is 1.
 *
 * Throws:
 *     If x is 0 and n is negative, the result is the same as the result of a
 *     division by zero.
 */
typeof(Unqual!(F).init * Unqual!(G).init) pow(F, G)(F x, G n) @nogc @trusted pure nothrow
if ((isFloatingPoint!F || isIntegral!F) && isIntegral!G)
{
    static if (isFloatingPoint!F && !is(Unqual!F == real))
    {
        double p = 1;
        double v = x;
    }
    else
    {
        typeof(return) p = 1;
        typeof(return) v = x;
    }
    Unsigned!(Unqual!G) m = n;
    if (n < 0)
    {
        if (n == -1)
            return 1 / v;

        m = cast(Unqual!G)(0 - n);
        v = p / x;
    }
    while (1)
    {
        if (m & 1)
            p *= v;
        m >>= 1;
        if (!m)
            break;
        v *= v;
    }
    return p;
}

/*******************************
 * Calculates x$(SUPERSCRIPT y).
 *
 * $(TABLE_SV
 * $(TR $(TH x) $(TH y) $(TH pow(x, y))
 *      $(TH div 0) $(TH invalid?))
 * $(TR $(TD anything)      $(TD $(PLUSMN)0.0)                $(TD 1.0)
 *      $(TD no)        $(TD no) )
 * $(TR $(TD |x| $(GT) 1)    $(TD +$(INFIN))                  $(TD +$(INFIN))
 *      $(TD no)        $(TD no) )
 * $(TR $(TD |x| $(LT) 1)    $(TD +$(INFIN))                  $(TD +0.0)
 *      $(TD no)        $(TD no) )
 * $(TR $(TD |x| $(GT) 1)    $(TD -$(INFIN))                  $(TD +0.0)
 *      $(TD no)        $(TD no) )
 * $(TR $(TD |x| $(LT) 1)    $(TD -$(INFIN))                  $(TD +$(INFIN))
 *      $(TD no)        $(TD no) )
 * $(TR $(TD +$(INFIN))      $(TD $(GT) 0.0)                  $(TD +$(INFIN))
 *      $(TD no)        $(TD no) )
 * $(TR $(TD +$(INFIN))      $(TD $(LT) 0.0)                  $(TD +0.0)
 *      $(TD no)        $(TD no) )
 * $(TR $(TD -$(INFIN))      $(TD odd integer $(GT) 0.0)      $(TD -$(INFIN))
 *      $(TD no)        $(TD no) )
 * $(TR $(TD -$(INFIN))      $(TD $(GT) 0.0, not odd integer) $(TD +$(INFIN))
 *      $(TD no)        $(TD no))
 * $(TR $(TD -$(INFIN))      $(TD odd integer $(LT) 0.0)      $(TD -0.0)
 *      $(TD no)        $(TD no) )
 * $(TR $(TD -$(INFIN))      $(TD $(LT) 0.0, not odd integer) $(TD +0.0)
 *      $(TD no)        $(TD no) )
 * $(TR $(TD $(PLUSMN)1.0)   $(TD $(PLUSMN)$(INFIN))          $(TD -$(NAN))
 *      $(TD no)        $(TD yes) )
 * $(TR $(TD $(LT) 0.0)      $(TD finite, nonintegral)        $(TD $(NAN))
 *      $(TD no)        $(TD yes))
 * $(TR $(TD $(PLUSMN)0.0)   $(TD odd integer $(LT) 0.0)      $(TD $(PLUSMNINF))
 *      $(TD yes)       $(TD no) )
 * $(TR $(TD $(PLUSMN)0.0)   $(TD $(LT) 0.0, not odd integer) $(TD +$(INFIN))
 *      $(TD yes)       $(TD no))
 * $(TR $(TD $(PLUSMN)0.0)   $(TD odd integer $(GT) 0.0)      $(TD $(PLUSMN)0.0)
 *      $(TD no)        $(TD no) )
 * $(TR $(TD $(PLUSMN)0.0)   $(TD $(GT) 0.0, not odd integer) $(TD +0.0)
 *      $(TD no)        $(TD no) )
 * )
 */
typeof(Unqual!(F).init * Unqual!(G).init) pow(F, G)(F x, G y) @nogc @trusted pure nothrow
if ((isFloatingPoint!F || isIntegral!F) && isFloatingPoint!G)
{
    // Force computation at double or real precision.
    static if (is(typeof(return) == real) && real.sizeof != double.sizeof)
    {
        real dx = x;
        real dy = y;

        // Take care not to trigger library calls from the compiler,
        // while ensuring that we don't get defeated by some optimizers.
        union floatBits
        {
            real rv;
            ushort[real.sizeof/2] vus;

            static if (real.mant_dig == 53 || real.mant_dig == 64)
                long vl;
            static if (real.mant_dig == 106)
            {
                double[2] vd;
                ulong[2] vul;
            }
            static if (real.mant_dig == 113)
                long[2] vl;
        }
    }
    else
    {
        double dx = x;
        double dy = y;
    }

    static if (is(typeof(return) == real) && real.sizeof != double.sizeof)
    {
        // Helpers to force a computation to occur at runtime.
        pragma(inline, false)
        static real force_mul(real x, real y) { return x * y; }
        pragma(inline, false)
        static real force_underflow() { return force_mul(0x1p-10000L, 0x1p-10000L); }
        pragma(inline, false)
        static real force_overflow() { return force_mul(0x1p10000L, 0x1p10000L); }

        // Round the value of x downward to the next integer
        // Params:
        //      x = input value
        pragma(inline, true)
        static real floor_inline(real x)
        {
            if (x == 0.0)
                return x;

            floatBits y = void;
            y.rv = x;

            static if (real.mant_dig == 106)
            {
                // The real format is made up of two IEEE doubles.
                // Compute floor() on each part separately.
                static foreach (i; 0 .. 2)
                {
                    // Find the exponent (power of 2)
                    // Do this by shifting the raw value so that the exponent lies in the low bits,
                    // then mask out the sign bit, and subtract the bias.
                    ulong vuli = y.vul[i];
                    long exp = ((vuli >> (double.mant_dig - 1)) & 0x7ff) - 0x3ff;
                    if (i == 0 && exp < 0)
                    {
                        if (x < 0.0)
                            return -1.0;
                        else
                            return 0.0;
                    }
                    if (exp < (double.mant_dig - 1))
                    {
                        // Clear all bits representing the fraction part.
                        immutable fraction_mask = 0x000f_ffff_ffff_ffff >> exp;
                        if ((vuli & fraction_mask) != 0)
                        {
                            // If 'x' is negative, then first substract 1.0 from the value.
                            if (vuli >> 63)
                                vuli += fraction_mask;
                            vuli &= ~fraction_mask;
                        }
                    }
                    if (i == 0 && vuli != y.vul[0])
                    {
                        // High part is not an integer, the low part doesn't affect the result
                        y.vul[0] = vuli;
                        y.vul[1] = 0;
                        break;
                    }
                    else
                        y.vul[i] = vuli;
                }
                if (y.vul[1] != 0)
                {
                    // Canonicalize the result
                    immutable expdiff = ((y.vul[0] >> 52) & 0x7ff) - ((y.vul[1] >> 52) & 0x7ff);
                    if (expdiff < 53)
                    {
                        // The sum can be represented in a single double
                        y.vd[0] += y.vd[1];
                        y.vd[1] = 0;
                    }
                    else if (expdiff == 53)
                    {
                        // Half way between two double values.
                        // Non-canonical if the low bit of the high part's mantissa is 1.
                        if ((y.vul[0] & 1) != 0)
                        {
                            y.vd[0] += 2 * y.vd[1];
                            y.vd[1] = -y.vd[1];
                        }
                    }
                }
            }
            else
            {
                static if (real.mant_dig == 64 || real.mant_dig == 53)
                {
                    version (LittleEndian)
                    {
                        int exp = (y.vus[4] & 0x7fff) - 0x3fff;
                        int pos = 0;
                    }
                    else
                    {
                        int exp = (y.vus[0] & 0x7fff) - 0x3fff;
                        int pos = 4;
                    }
                }
                else static if (real.mant_dig == 113)
                {
                    version (LittleEndian)
                    {
                        int exp = (y.vus[7] & 0x7fff) - 0x3fff;
                        int pos = 0;
                    }
                    else
                    {
                        int exp = (y.vus[0] & 0x7fff) - 0x3fff;
                        int pos = 7;
                    }
                }
                else
                    static assert(false, "floor() not implemented");
                if (exp < 0)
                {
                    if (x < 0.0)
                        return -1.0;
                    else
                        return 0.0;
                }
                static if (real.mant_dig == 53)
                    exp = (real.mant_dig + 11 - 1) - exp; // mant_dig is really 64
                else
                    exp = (real.mant_dig - 1) - exp;
                // Zero 16 bits at a time.
                while (exp >= 16)
                {
                    version (LittleEndian)
                        y.vus[pos++] = 0;
                    else
                        y.vus[pos--] = 0;
                    exp -= 16;
                }
                // Clear the remaining bits.
                if (exp > 0)
                    y.vus[pos] &= 0xffff ^ ((1 << exp) - 1);

                if ((x < 0.0) && (x != y.rv))
                    y.rv -= 1.0;
            }
            return y.rv;
        }

        // Separate floating point value into significand and exponent
        // Params:
        //      x = input value
        //      exp = returned exponent
        pragma(inline, true)
        static real frexp_inline(real x, out long exp)
        {
            floatBits y = void;
            y.rv = x;
            static if (real.mant_dig == 64 || real.mant_dig == 53 || real.mant_dig == 113)
            {
                version (LittleEndian)
                {
                    static if (real.mant_dig == 113)
                        enum exppos = 7;
                    else
                        enum exppos = 4;
                    enum lsb = 0;
                    enum msb = 1;
                }
                else
                {
                    enum exppos = 0;
                    enum lsb = 1;
                    enum msb = 0;
                }
                int ex = y.vus[exppos] & 0x7fff;

                // If exponent is non-zero
                if (ex)
                {
                    exp = ex - 0x3ffe;
                    y.vus[exppos] = (0x8000 & y.vus[exppos]) | 0x3ffe;
                    return y.rv;
                }
                // x is +-0.0
                static if (real.mant_dig == 113)
                {
                    if ((y.vl[lsb] | (y.vl[msb] & 0x0000_ffff_ffff_ffff)) == 0)
                    {
                        // x is +-0.0
                        exp = 0;
                        return y.rv;
                    }
                }
                else
                {
                    if (!y.vl)
                    {
                        exp = 0;
                        return y.rv;
                    }
                }
                // subnormal
                y.rv *= 1.0L / real.epsilon;
                ex = y.vus[exppos] & 0x7fff;
                exp = ex - 0x3ffe - real.mant_dig + 1;
                y.vus[exppos] = (0x8000 & y.vus[exppos]) | 0x3ffe;
                return y.rv;
            }
            else static if (real.mant_dig == 106)
            {
                import core.bitop : bsr;
                ulong ix = 0x7fff_ffff_ffff_ffffUL & y.vul[0];
                if (ix == 0)
                {
                    // x is +-0.0
                    exp = 0;
                    return y.rv;
                }
                ulong ex = ix >> 52;
                if (ex == 0)
                {
                    // Denormal high double, the low double must be 0.0.
                    // Normalize.
                    immutable cnt = 7 - bsr(ix) - 12;
                    ex -= cnt;
                    ix <<= cnt + 1;
                }
                ex -= 1022;
                ix &= 0x000f_ffff_ffff_ffffUL;
                y.vul[0] &= 0x8000_0000_0000_0000UL;
                y.vul[0] |= (1022L << 52) | ix;

                ulong ixl = 0x7fff_ffff_ffff_ffffUL & y.vul[1];
                if (ixl != 0)
                {
                    // If the high double is an exact power of two and the low
                    // double has the opposite sign, then the exponent calculated
                    // from the high double is one too big.
                    if (ix == 0 && cast(long)(y.vul[0] ^ y.vul[1]) < 0)
                    {
                        y.vul[0] += 1L << 52;
                        ex -= 1;
                    }
                    long explo = ixl >> 52;
                    if (explo == 0)
                    {
                        // The low double started out as a denormal. Normalize its
                        // mantissa and adjust the exponent.
                        immutable cnt = 7 - bsr(ixl) - 12;
                        explo -= cnt;
                        ixl <<= cnt + 1;
                    }
                    // With variable precision we can't assume much about the
                    // magnitude of the returned low double. It may even be a
                    // denormal.
                    explo -= ex;
                    ixl &= 0x000f_ffff_ffff_ffffUL;
                    y.vul[1] &= 0x8000_0000_0000_0000UL;
                    if (explo <= 0)
                    {
                        // Handle denormal low double.
                        if (explo > -52)
                        {
                            ixl |= 1L << 52;
                            ixl >>= 1 - explo;
                        }
                        else
                        {
                            ixl = 0;
                            y.vul[1] = 0;
                            if ((y.vul[0] & 0x7ff0_0000_0000_0000UL) == (1023L << 52))
                            {
                                // This can happen if the input was something
                                // like 0x1p1000 - 0x1p-1000.
                                y.vul[0] -= 1L << 52;
                                ex += 1;
                            }
                        }
                        explo = 0;
                    }
                    y.vul[1] |= (explo << 52) | ixl;
                }
                exp = ex;
                return y.rv;
            }
            else
                static assert(false, "frexp() not implemented");
        }

        // Params:
        //      x = input value
        // Returns:
        //      1 if sign bit of x is set, 0 if not
        pragma(inline, true)
        static int signbit_inline(real x)
        {
            if (__ctfe)
            {
                // Precision can change, but sign won't change at CTFE.
                double dx = cast(double)x;
                return 0 > *cast(long*)&dx;
            }
            // Get the index of the sign when represented as a ubyte array.
            version (LittleEndian)
            {
                static if (real.mant_dig == 64 || real.mant_dig == 53)
                    enum pos = 9;
                else static if (real.mant_dig == 113)
                    enum pos = 15;
                else static if (real.mant_dig == 106)
                    enum pos = 7;
                else
                    static assert(false, "signbit() not implemented");
            }
            else
                enum pos = 0;
            return ((cast(ubyte *)&x)[pos] & 0x80) != 0;
        }

        // Params:
        //      x = input value
        // Returns:
        //      a multiple of 1/32 that is within 1/32 of x
        pragma(inline, true)
        static real reduc_inline(real x)
        {
            return floor_inline(x * 32) / 32;
        }

        // Evaluate polynomial
        // Params:
        //      x = the value to evaluate
        //      A = array of coefficients
        pragma(inline, true)
        static real poly_inline(alias A)(real x)
        {
            enum N = A.length;
            real r = A[N - 1];
            static foreach (i; 1 .. N)
            {
                r *= x;
                r += A[N - 1 - i];
            }
            return r;
        }

        // log(1+x) =  x - .5x^^2 + x^^3 *  P(z)/Q(z)
        // on the domain  2^^(-1/32) - 1  <=  x  <=  2^^(1/32) - 1
        enum real[4] pow_polyP = [
            1.4000100839971580279335E0L,
            1.7500123722550302671919E0L,
            4.9000050881978028599627E-1L,
            8.3319510773868690346226E-4L,
        ];
        enum real[4] pow_polyQ = [
            4.2000302519914740834728E0L,
            8.4000598057587009834666E0L,
            5.2500282295834889175431E0L,
            1.0000000000000000000000E0L,
        ];
        // A[i] = 2^(-i/32), rounded to IEEE long double precision.
        // If i is even, A[i] + B[i/2] gives additional accuracy.
        __gshared immutable real[33] pow_tabA = [
            1.0000000000000000000000E0L, 9.7857206208770013448287E-1L,
            9.5760328069857364691013E-1L, 9.3708381705514995065011E-1L,
            9.1700404320467123175367E-1L, 8.9735453750155359320742E-1L,
            8.7812608018664974155474E-1L, 8.5930964906123895780165E-1L,
            8.4089641525371454301892E-1L, 8.2287773907698242225554E-1L,
            8.0524516597462715409607E-1L, 7.8799042255394324325455E-1L,
            7.7110541270397041179298E-1L, 7.5458221379671136985669E-1L,
            7.3841307296974965571198E-1L, 7.2259040348852331001267E-1L,
            7.0710678118654752438189E-1L, 6.9195494098191597746178E-1L,
            6.7712777346844636413344E-1L, 6.6261832157987064729696E-1L,
            6.4841977732550483296079E-1L, 6.3452547859586661129850E-1L,
            6.2092890603674202431705E-1L, 6.0762367999023443907803E-1L,
            5.9460355750136053334378E-1L, 5.8186242938878875689693E-1L,
            5.6939431737834582684856E-1L, 5.5719337129794626814472E-1L,
            5.4525386633262882960438E-1L, 5.3357020033841180906486E-1L,
            5.2213689121370692017331E-1L, 5.1094857432705833910408E-1L,
            5.0000000000000000000000E-1L,
        ];
        __gshared immutable real[17] pow_tabB = [
            0.0000000000000000000000E0L, 2.6176170809902549338711E-20L,
            1.0126791927256478897086E-20L, 1.3438228172316276937655E-21L,
            1.2207982955417546912101E-20L, -6.3084814358060867200133E-21L,
            1.3164426894366316434230E-20L, -1.8527916071632873716786E-20L,
            1.8950325588932570796551E-20L, 1.5564775779538780478155E-20L,
            6.0859793637556860974380E-21L, -2.0208749253662532228949E-20L,
            1.4966292219224761844552E-20L, 3.3540909728056476875639E-21L,
            8.6987564101742849540743E-22L, -1.2327176863327626135542E-20L,
            0.0000000000000000000000E0L,
        ];
        // 2^x = 1 + x P(x),
        // on the interval -1/32 <= x <= 0
        enum real[7] pow_polyR = [
            6.9314718055994530931447E-1L,
            2.4022650695910062854352E-1L,
            5.5504108664798463044015E-2L,
            9.6181291046036762031786E-3L,
            1.3333556028915671091390E-3L,
            1.5402715328927013076125E-4L,
            1.5089970579127659901157E-5L,
        ];
        // log2(e) - 1
        enum real log2ea = 0.44269504088896340735992L;
        // Constants for checking overflow/underflow.
        enum real maxexp = 32 * 16384.0L;
        enum real minexp = -32 * (16384.0L + 64.0L);

        // Handle special cases.
        if (dx != dx)
        {
            if (!(dy != dy) && dy == 0.0)
                return 1.0;
            return dx;
        }
        if (dy != dy)
        {
            if (dx == 1.0)
                return 1.0;
            return dy;
        }
        // 1 ^^ y == 1, even if y is nan
        if (dx == 1.0)
            return 1.0;
        // -1 ^^ real.infinity == 1
        if (dx == -1.0 && (dy == real.infinity || dy == -real.infinity))
            return 1.0;
        // x ^^ 0 == 1, even if x is nan
        if (dy == 0.0)
            return 1.0;
        if (dy == 1.0)
            return dx;
        if (dy >= real.max)
        {
            if (dx > 1.0 || dx < -1.0)
                return real.infinity;
            if (dx != 0.0)
                return 0.0;
        }
        if (dy <= -real.max)
        {
            if (dx > 1.0 || dx < -1.0)
                return 0.0;
            if (dx != 0.0 || dy == -real.infinity)
                return real.infinity;
        }
        if (dx >= real.max)
        {
            if (dy > 0.0)
                return real.infinity;
            return 0.0;
        }

        real w = floor_inline(dy);
        // Set iyflg to 1 if y is an integer.
        int iyflg = 0;
        if (w == dy)
            iyflg = 1;
        // Test for odd integer y.
        int yoddint = 0;
        if (iyflg)
        {
            real ya = fabs(dy);
            ya = floor_inline(0.5 * ya);
            real yb = 0.5 * fabs(w);
            if (ya != yb)
                yoddint = 1;
        }

        if (dx <= -real.max)
        {
            if (dy > 0.0)
            {
                if (yoddint)
                    return -real.infinity;
                return real.infinity;
            }
            if (dy < 0.0)
            {
                if (yoddint)
                    return -0.0;
                return 0.0;
            }
        }
        // (x < 0)^^(odd int)
        int nflg = 0;
        if (dx <= 0.0)
        {
            if (dx == 0.0)
            {
                if (dy < 0.0)
                {
                    // (-0.0)^^(-odd int) = -inf, divbyzero
                    if (signbit_inline(dx) && yoddint)
                        return -1.0/0.0;
                    // (+-0.0)^^(negative) = inf, divbyzero
                    return 1.0/0.0;
                }
                if (signbit_inline(dx) && yoddint)
                    return -0.0;
                return 0.0;
            }
            // (x<0)^^(non-int) is NaN
            if (iyflg == 0)
                return (dx - dx) / (dx - dx);
            // (x<0)^^(integer)
            if (yoddint)
                nflg = 1;
            // Negate result
            dx = -dx;
        }
        // (+integer)^^(integer)
        if (iyflg && floor_inline(dx) == dx && fabs(dy) < 32768.0)
        {
            immutable r = pow(dx, cast(int)dy);
            return nflg ? -r : r;
        }

        // Separate significand from exponent
        long e;
        dx = frexp_inline(dx, e);

        // Find significand in antilog table A[]
        int i = 1;
        if (dx <= pow_tabA[17])
            i = 17;
        if (dx <= pow_tabA[i+8])
            i += 8;
        if (dx <= pow_tabA[i+4])
            i += 4;
        if (dx <= pow_tabA[i+2])
            i += 2;
        if (dx >= pow_tabA[1])
            i = -1;
        i += 1;

        // Find (x - A[i])/A[i]
        // in order to compute log(x/A[i]):
        // log(x) = log( a x/a ) = log(a) + log(x/a)
        // log(x/a) = log(1+v),  v = x/a - 1 = (x-a)/a
        dx -= pow_tabA[i];
        dx -= pow_tabB[i / 2];
        dx /= pow_tabA[i];
        // rational approximation for log(1+v):
        // log(1+v)  =  v  -  v^^2/2  +  v^^3 P(v) / Q(v
        real z = dx * dx;
        w  = dx * (z * poly_inline!pow_polyP(dx) / poly_inline!pow_polyQ(dx));
        w = w - 0.5 * z;
        // Convert to base 2 logarithm:
        // multiply by log2(e) = 1 + log2ea
        z = log2ea * w;
        z += w;
        z += log2ea * dx;
        z += dx;
        // Compute exponent term of the base 2 logarithm.
        w = -i;
        w /= 32;
        w += e;
        // Now base 2 log of x is w + z.
        // Multiply base 2 log by y, in extended precision.
        // separate y into large part ya and small part yb less than 1/32
        real ya = reduc_inline(dy);
        real yb = dy - ya;
        // (w + z)(ya + yb) = w * ya + w * yb + z * y
        real f = z * dy + w * yb;
        real fa = reduc_inline(f);
        real fb = f - fa;

        real g = fa + w * ya;
        real ga = reduc_inline(g);
        real gb = g - ga;

        real h = fb + gb;
        real ha = reduc_inline(h);
        w = (ga + ha) * 32;

        // Test the power of 2 for overflow
        if (w > maxexp)
            return force_overflow();
        if (w < minexp)
            return force_underflow();

        e = cast(long)w;
        real hb = h - ha;
        if (hb > 0.0)
        {
            e += 1;
            hb -= 0.0625L;
        }

        // Now the product y * log2(x)  =  hb + e/32.
        // Compute base 2 exponential of hb,
        // where -0.0625 <= hb <= 0.
        z = hb * poly_inline!pow_polyR(hb);

        // Express e/32 as an integer plus a negative number of 1/32ths.
        // Find lookup table entry for the fractional power of 2.
        if (e < 0)
            i = 0;
        else
            i = 1;
        i = cast(int)(e / 32 + i);
        e = 32 * i - e;
        w = pow_tabA[e];
        // 2^^-e * ( 1 + (2^^hb-1) )
        z = w * z;
        z = z + w;
        z = ldexp(z, i);
        if (nflg)
            z = -z;
        return z;
    }
    else
    {
        // Helpers to force a computation to occur at runtime.
        pragma(inline, false)
        static double force_div(double x, double y) { return x / y; }
        pragma(inline, false)
        static double force_mul(double x, double y) { return x * y; }
        pragma(inline, false)
        static double force_underflow(uint sign)
        {
            return force_mul(sign ? -0x1p-767 : 0x1p-767, 0x1p-767);
        }
        pragma(inline, false)
        static double force_overflow(uint sign)
        {
            return force_mul(sign ? -0x1p769 : 0x1p769, 0x1p769);
        }
        pragma(inline, false)
        static double force_invalid(double x)
        {
            return force_div(x - x, x - x);
        }

        // Compute y+TAIL = log(x) where the rounded result is y and TAIL has about
        // additional 15 bits precision.
        // Params:
        //      ix = the bit representation of x, but normalized in the subnormal
        //           range using the sign bit for the exponent
        //      tail = where to store additional precision
        pragma(inline, true)
        static double log_inline(ulong ix, out double tail)
        {
            // log(2) split into two parts
            enum double ln2hi = 0x1.62e42fefa3800p-1;
            enum double ln2lo = 0x1.ef35793c76730p-45;
            // pow coefficients:
            // relative error: 0x1.11922ap-70 in range [-0x1.6bp-8 .. 0x1.6bp-8]
            enum double[7] log_poly = [
                -0x1p-1,
                0x1.555555555556p-2 * -2,
                -0x1.0000000000006p-2 * -2,
                0x1.999999959554ep-3 * 4,
                -0x1.555555529a47ap-3 * 4,
                0x1.2495b9b4845e9p-3 * -8,
                -0x1.0002b8b263fc3p-3 * -8,
            ];
            // Algorithm:
            //      x = 2^^k z
            //      log(x) = k log(2) + log(c) + log(z/c)
            //      log(z/c) = poly(z/c - 1)
            // where z is in [0x1.69555p-1; 0x1.69555p0] which is split into N subintervals
            // and z falls into the ith one, then table entries are computed as
            //      log_tab[i][0] = 1/c
            //      log_tab[i][2] = round(0x1p43 * log(c)) / 0x1p43
            //      log_tab[i][3] = (double)(log(c) - log_tab[i][2])
            // where c is chosen near the center of the subinterval such that 1/c has only a
            // few precision bits so z/c - 1 is exactly representible as double:
            //      1/c = center < 1 ? round(N/center)/N : round(2*N/center)/N/2
            //
            // NOTE: the 2nd index is unused, but allows slightly faster indexing.
            __gshared immutable double[4][128] log_tab = [
                [0x1.6a00000000000p+0, 0, -0x1.62c82f2b9c800p-2, 0x1.ab42428375680p-48],
                [0x1.6800000000000p+0, 0, -0x1.5d1bdbf580800p-2, -0x1.ca508d8e0f720p-46],
                [0x1.6600000000000p+0, 0, -0x1.5767717455800p-2, -0x1.362a4d5b6506dp-45],
                [0x1.6400000000000p+0, 0, -0x1.51aad872df800p-2, -0x1.684e49eb067d5p-49],
                [0x1.6200000000000p+0, 0, -0x1.4be5f95777800p-2, -0x1.41b6993293ee0p-47],
                [0x1.6000000000000p+0, 0, -0x1.4618bc21c6000p-2, 0x1.3d82f484c84ccp-46],
                [0x1.5e00000000000p+0, 0, -0x1.404308686a800p-2, 0x1.c42f3ed820b3ap-50],
                [0x1.5c00000000000p+0, 0, -0x1.3a64c55694800p-2, 0x1.0b1c686519460p-45],
                [0x1.5a00000000000p+0, 0, -0x1.347dd9a988000p-2, 0x1.5594dd4c58092p-45],
                [0x1.5800000000000p+0, 0, -0x1.2e8e2bae12000p-2, 0x1.67b1e99b72bd8p-45],
                [0x1.5600000000000p+0, 0, -0x1.2895a13de8800p-2, 0x1.5ca14b6cfb03fp-46],
                [0x1.5600000000000p+0, 0, -0x1.2895a13de8800p-2, 0x1.5ca14b6cfb03fp-46],
                [0x1.5400000000000p+0, 0, -0x1.22941fbcf7800p-2, -0x1.65a242853da76p-46],
                [0x1.5200000000000p+0, 0, -0x1.1c898c1699800p-2, -0x1.fafbc68e75404p-46],
                [0x1.5000000000000p+0, 0, -0x1.1675cababa800p-2, 0x1.f1fc63382a8f0p-46],
                [0x1.4e00000000000p+0, 0, -0x1.1058bf9ae4800p-2, -0x1.6a8c4fd055a66p-45],
                [0x1.4c00000000000p+0, 0, -0x1.0a324e2739000p-2, -0x1.c6bee7ef4030ep-47],
                [0x1.4a00000000000p+0, 0, -0x1.0402594b4d000p-2, -0x1.036b89ef42d7fp-48],
                [0x1.4a00000000000p+0, 0, -0x1.0402594b4d000p-2, -0x1.036b89ef42d7fp-48],
                [0x1.4800000000000p+0, 0, -0x1.fb9186d5e4000p-3, 0x1.d572aab993c87p-47],
                [0x1.4600000000000p+0, 0, -0x1.ef0adcbdc6000p-3, 0x1.b26b79c86af24p-45],
                [0x1.4400000000000p+0, 0, -0x1.e27076e2af000p-3, -0x1.72f4f543fff10p-46],
                [0x1.4200000000000p+0, 0, -0x1.d5c216b4fc000p-3, 0x1.1ba91bbca681bp-45],
                [0x1.4000000000000p+0, 0, -0x1.c8ff7c79aa000p-3, 0x1.7794f689f8434p-45],
                [0x1.4000000000000p+0, 0, -0x1.c8ff7c79aa000p-3, 0x1.7794f689f8434p-45],
                [0x1.3e00000000000p+0, 0, -0x1.bc286742d9000p-3, 0x1.94eb0318bb78fp-46],
                [0x1.3c00000000000p+0, 0, -0x1.af3c94e80c000p-3, 0x1.a4e633fcd9066p-52],
                [0x1.3a00000000000p+0, 0, -0x1.a23bc1fe2b000p-3, -0x1.58c64dc46c1eap-45],
                [0x1.3a00000000000p+0, 0, -0x1.a23bc1fe2b000p-3, -0x1.58c64dc46c1eap-45],
                [0x1.3800000000000p+0, 0, -0x1.9525a9cf45000p-3, -0x1.ad1d904c1d4e3p-45],
                [0x1.3600000000000p+0, 0, -0x1.87fa06520d000p-3, 0x1.bbdbf7fdbfa09p-45],
                [0x1.3400000000000p+0, 0, -0x1.7ab890210e000p-3, 0x1.bdb9072534a58p-45],
                [0x1.3400000000000p+0, 0, -0x1.7ab890210e000p-3, 0x1.bdb9072534a58p-45],
                [0x1.3200000000000p+0, 0, -0x1.6d60fe719d000p-3, -0x1.0e46aa3b2e266p-46],
                [0x1.3000000000000p+0, 0, -0x1.5ff3070a79000p-3, -0x1.e9e439f105039p-46],
                [0x1.3000000000000p+0, 0, -0x1.5ff3070a79000p-3, -0x1.e9e439f105039p-46],
                [0x1.2e00000000000p+0, 0, -0x1.526e5e3a1b000p-3, -0x1.0de8b90075b8fp-45],
                [0x1.2c00000000000p+0, 0, -0x1.44d2b6ccb8000p-3, 0x1.70cc16135783cp-46],
                [0x1.2c00000000000p+0, 0, -0x1.44d2b6ccb8000p-3, 0x1.70cc16135783cp-46],
                [0x1.2a00000000000p+0, 0, -0x1.371fc201e9000p-3, 0x1.178864d27543ap-48],
                [0x1.2800000000000p+0, 0, -0x1.29552f81ff000p-3, -0x1.48d301771c408p-45],
                [0x1.2600000000000p+0, 0, -0x1.1b72ad52f6000p-3, -0x1.e80a41811a396p-45],
                [0x1.2600000000000p+0, 0, -0x1.1b72ad52f6000p-3, -0x1.e80a41811a396p-45],
                [0x1.2400000000000p+0, 0, -0x1.0d77e7cd09000p-3, 0x1.a699688e85bf4p-47],
                [0x1.2400000000000p+0, 0, -0x1.0d77e7cd09000p-3, 0x1.a699688e85bf4p-47],
                [0x1.2200000000000p+0, 0, -0x1.fec9131dbe000p-4, -0x1.575545ca333f2p-45],
                [0x1.2000000000000p+0, 0, -0x1.e27076e2b0000p-4, 0x1.a342c2af0003cp-45],
                [0x1.2000000000000p+0, 0, -0x1.e27076e2b0000p-4, 0x1.a342c2af0003cp-45],
                [0x1.1e00000000000p+0, 0, -0x1.c5e548f5bc000p-4, -0x1.d0c57585fbe06p-46],
                [0x1.1c00000000000p+0, 0, -0x1.a926d3a4ae000p-4, 0x1.53935e85baac8p-45],
                [0x1.1c00000000000p+0, 0, -0x1.a926d3a4ae000p-4, 0x1.53935e85baac8p-45],
                [0x1.1a00000000000p+0, 0, -0x1.8c345d631a000p-4, 0x1.37c294d2f5668p-46],
                [0x1.1a00000000000p+0, 0, -0x1.8c345d631a000p-4, 0x1.37c294d2f5668p-46],
                [0x1.1800000000000p+0, 0, -0x1.6f0d28ae56000p-4, -0x1.69737c93373dap-45],
                [0x1.1600000000000p+0, 0, -0x1.51b073f062000p-4, 0x1.f025b61c65e57p-46],
                [0x1.1600000000000p+0, 0, -0x1.51b073f062000p-4, 0x1.f025b61c65e57p-46],
                [0x1.1400000000000p+0, 0, -0x1.341d7961be000p-4, 0x1.c5edaccf913dfp-45],
                [0x1.1400000000000p+0, 0, -0x1.341d7961be000p-4, 0x1.c5edaccf913dfp-45],
                [0x1.1200000000000p+0, 0, -0x1.16536eea38000p-4, 0x1.47c5e768fa309p-46],
                [0x1.1000000000000p+0, 0, -0x1.f0a30c0118000p-5, 0x1.d599e83368e91p-45],
                [0x1.1000000000000p+0, 0, -0x1.f0a30c0118000p-5, 0x1.d599e83368e91p-45],
                [0x1.0e00000000000p+0, 0, -0x1.b42dd71198000p-5, 0x1.c827ae5d6704cp-46],
                [0x1.0e00000000000p+0, 0, -0x1.b42dd71198000p-5, 0x1.c827ae5d6704cp-46],
                [0x1.0c00000000000p+0, 0, -0x1.77458f632c000p-5, -0x1.cfc4634f2a1eep-45],
                [0x1.0c00000000000p+0, 0, -0x1.77458f632c000p-5, -0x1.cfc4634f2a1eep-45],
                [0x1.0a00000000000p+0, 0, -0x1.39e87b9fec000p-5, 0x1.502b7f526feaap-48],
                [0x1.0a00000000000p+0, 0, -0x1.39e87b9fec000p-5, 0x1.502b7f526feaap-48],
                [0x1.0800000000000p+0, 0, -0x1.f829b0e780000p-6, -0x1.980267c7e09e4p-45],
                [0x1.0800000000000p+0, 0, -0x1.f829b0e780000p-6, -0x1.980267c7e09e4p-45],
                [0x1.0600000000000p+0, 0, -0x1.7b91b07d58000p-6, -0x1.88d5493faa639p-45],
                [0x1.0400000000000p+0, 0, -0x1.fc0a8b0fc0000p-7, -0x1.f1e7cf6d3a69cp-50],
                [0x1.0400000000000p+0, 0, -0x1.fc0a8b0fc0000p-7, -0x1.f1e7cf6d3a69cp-50],
                [0x1.0200000000000p+0, 0, -0x1.fe02a6b100000p-8, -0x1.9e23f0dda40e4p-46],
                [0x1.0200000000000p+0, 0, -0x1.fe02a6b100000p-8, -0x1.9e23f0dda40e4p-46],
                [0x1.0000000000000p+0, 0, 0x0.0000000000000p+0, 0x0.0000000000000p+0],
                [0x1.0000000000000p+0, 0, 0x0.0000000000000p+0, 0x0.0000000000000p+0],
                [0x1.fc00000000000p-1, 0, 0x1.0101575890000p-7, -0x1.0c76b999d2be8p-46],
                [0x1.f800000000000p-1, 0, 0x1.0205658938000p-6, -0x1.3dc5b06e2f7d2p-45],
                [0x1.f400000000000p-1, 0, 0x1.8492528c90000p-6, -0x1.aa0ba325a0c34p-45],
                [0x1.f000000000000p-1, 0, 0x1.0415d89e74000p-5, 0x1.111c05cf1d753p-47],
                [0x1.ec00000000000p-1, 0, 0x1.466aed42e0000p-5, -0x1.c167375bdfd28p-45],
                [0x1.e800000000000p-1, 0, 0x1.894aa149fc000p-5, -0x1.97995d05a267dp-46],
                [0x1.e400000000000p-1, 0, 0x1.ccb73cdddc000p-5, -0x1.a68f247d82807p-46],
                [0x1.e200000000000p-1, 0, 0x1.eea31c006c000p-5, -0x1.e113e4fc93b7bp-47],
                [0x1.de00000000000p-1, 0, 0x1.1973bd1466000p-4, -0x1.5325d560d9e9bp-45],
                [0x1.da00000000000p-1, 0, 0x1.3bdf5a7d1e000p-4, 0x1.cc85ea5db4ed7p-45],
                [0x1.d600000000000p-1, 0, 0x1.5e95a4d97a000p-4, -0x1.c69063c5d1d1ep-45],
                [0x1.d400000000000p-1, 0, 0x1.700d30aeac000p-4, 0x1.c1e8da99ded32p-49],
                [0x1.d000000000000p-1, 0, 0x1.9335e5d594000p-4, 0x1.3115c3abd47dap-45],
                [0x1.cc00000000000p-1, 0, 0x1.b6ac88dad6000p-4, -0x1.390802bf768e5p-46],
                [0x1.ca00000000000p-1, 0, 0x1.c885801bc4000p-4, 0x1.646d1c65aacd3p-45],
                [0x1.c600000000000p-1, 0, 0x1.ec739830a2000p-4, -0x1.dc068afe645e0p-45],
                [0x1.c400000000000p-1, 0, 0x1.fe89139dbe000p-4, -0x1.534d64fa10afdp-45],
                [0x1.c000000000000p-1, 0, 0x1.1178e8227e000p-3, 0x1.1ef78ce2d07f2p-45],
                [0x1.be00000000000p-1, 0, 0x1.1aa2b7e23f000p-3, 0x1.ca78e44389934p-45],
                [0x1.ba00000000000p-1, 0, 0x1.2d1610c868000p-3, 0x1.39d6ccb81b4a1p-47],
                [0x1.b800000000000p-1, 0, 0x1.365fcb0159000p-3, 0x1.62fa8234b7289p-51],
                [0x1.b400000000000p-1, 0, 0x1.4913d8333b000p-3, 0x1.5837954fdb678p-45],
                [0x1.b200000000000p-1, 0, 0x1.527e5e4a1b000p-3, 0x1.633e8e5697dc7p-45],
                [0x1.ae00000000000p-1, 0, 0x1.6574ebe8c1000p-3, 0x1.9cf8b2c3c2e78p-46],
                [0x1.ac00000000000p-1, 0, 0x1.6f0128b757000p-3, -0x1.5118de59c21e1p-45],
                [0x1.aa00000000000p-1, 0, 0x1.7898d85445000p-3, -0x1.c661070914305p-46],
                [0x1.a600000000000p-1, 0, 0x1.8beafeb390000p-3, -0x1.73d54aae92cd1p-47],
                [0x1.a400000000000p-1, 0, 0x1.95a5adcf70000p-3, 0x1.7f22858a0ff6fp-47],
                [0x1.a000000000000p-1, 0, 0x1.a93ed3c8ae000p-3, -0x1.8724350562169p-45],
                [0x1.9e00000000000p-1, 0, 0x1.b31d8575bd000p-3, -0x1.c358d4eace1aap-47],
                [0x1.9c00000000000p-1, 0, 0x1.bd087383be000p-3, -0x1.d4bc4595412b6p-45],
                [0x1.9a00000000000p-1, 0, 0x1.c6ffbc6f01000p-3, -0x1.1ec72c5962bd2p-48],
                [0x1.9600000000000p-1, 0, 0x1.db13db0d49000p-3, -0x1.aff2af715b035p-45],
                [0x1.9400000000000p-1, 0, 0x1.e530effe71000p-3, 0x1.212276041f430p-51],
                [0x1.9200000000000p-1, 0, 0x1.ef5ade4dd0000p-3, -0x1.a211565bb8e11p-51],
                [0x1.9000000000000p-1, 0, 0x1.f991c6cb3b000p-3, 0x1.bcbecca0cdf30p-46],
                [0x1.8c00000000000p-1, 0, 0x1.07138604d5800p-2, 0x1.89cdb16ed4e91p-48],
                [0x1.8a00000000000p-1, 0, 0x1.0c42d67616000p-2, 0x1.7188b163ceae9p-45],
                [0x1.8800000000000p-1, 0, 0x1.1178e8227e800p-2, -0x1.c210e63a5f01cp-45],
                [0x1.8600000000000p-1, 0, 0x1.16b5ccbacf800p-2, 0x1.b9acdf7a51681p-45],
                [0x1.8400000000000p-1, 0, 0x1.1bf99635a6800p-2, 0x1.ca6ed5147bdb7p-45],
                [0x1.8200000000000p-1, 0, 0x1.214456d0eb800p-2, 0x1.a87deba46baeap-47],
                [0x1.7e00000000000p-1, 0, 0x1.2bef07cdc9000p-2, 0x1.a9cfa4a5004f4p-45],
                [0x1.7c00000000000p-1, 0, 0x1.314f1e1d36000p-2, -0x1.8e27ad3213cb8p-45],
                [0x1.7a00000000000p-1, 0, 0x1.36b6776be1000p-2, 0x1.16ecdb0f177c8p-46],
                [0x1.7800000000000p-1, 0, 0x1.3c25277333000p-2, 0x1.83b54b606bd5cp-46],
                [0x1.7600000000000p-1, 0, 0x1.419b423d5e800p-2, 0x1.8e436ec90e09dp-47],
                [0x1.7400000000000p-1, 0, 0x1.4718dc271c800p-2, -0x1.f27ce0967d675p-45],
                [0x1.7200000000000p-1, 0, 0x1.4c9e09e173000p-2, -0x1.e20891b0ad8a4p-45],
                [0x1.7000000000000p-1, 0, 0x1.522ae0738a000p-2, 0x1.ebe708164c759p-45],
                [0x1.6e00000000000p-1, 0, 0x1.57bf753c8d000p-2, 0x1.fadedee5d40efp-46],
                [0x1.6c00000000000p-1, 0, 0x1.5d5bddf596000p-2, -0x1.a0b2a08a465dcp-47],
            ];

            // x = 2^^k z; where z is in range [OFF,2*OFF) and exact.
            // The range is split into N subintervals.
            // The ith subinterval contains z and c is near its center.
            immutable tmp = ix - 0x3FE6955500000000UL;
            immutable i = (tmp >> 45) % log_tab.length;
            immutable iz = ix - (tmp & 0xFFFUL << 52);
            immutable dz = *cast(double*)&iz;
            immutable k = cast(double)(cast(long)tmp >> 52);
            // log(x) = k*Ln2 + log(c) + log1p(z/c-1).
            immutable invc = log_tab[i][0];
            immutable logc = log_tab[i][2];
            immutable logctail = log_tab[i][3];
            // Split z such that rhi, rlo and rhi*rhi are exact and |rlo| <= |r|.
            immutable izhi = (iz + (1UL << 31)) & (-1UL << 32);
            immutable zhi = *cast(double*)&izhi;
            immutable zlo = dz - zhi;
            immutable rhi = zhi * invc - 1.0;
            immutable rlo = zlo * invc;
            immutable r = rhi + rlo;
            // k*Ln2 + log(c) + r.
            immutable t1 = k * ln2hi + logc;
            immutable t2 = t1 + r;
            immutable lo1 = k * ln2lo + logctail;
            immutable lo2 = t1 - t2 + r;
            // Evaluation is optimized assuming superscalar pipelined execution.
            immutable ar = log_poly[0] * r;
            immutable ar2 = r * ar;
            immutable ar3 = r * ar2;
            // k*Ln2 + log(c) + r + A[0]*r*r.
            immutable arhi = log_poly[0] * rhi;
            immutable arhi2 = rhi * arhi;
            immutable hi = t2 + arhi2;
            immutable lo3 = rlo * (ar + arhi);
            immutable lo4 = t2 - hi + arhi2;
            // p = log1p(r) - r - A[0]*r*r.
            immutable p = ar3 * (log_poly[1] + r * log_poly[2] +
                                 ar2 * (log_poly[3] + r * log_poly[4] +
                                        ar2 * (log_poly[5] + r * log_poly[6])));
            immutable lo = lo1 + lo2 + lo3 + lo4 + p;
            immutable y = hi + lo;
            tail = hi - y + lo;
            return y;
        }

        // Computes sign*exp(x+xtail) where |xtail| < 2^^-8/N and |xtail| <= |x|.
        // Params:
        //      x = double input value
        //      xtail = additional precision of x
        //      sign_bias = (0x800 << 7) or 0, sets the sign to -1 or 1
        pragma(inline, true)
        static double exp_inline(double x, double xtail, uint sign_bias)
        {
            // Returns the top 12 bits of a double (sign and exponent).
            pragma(inline, true)
            uint top12(double x)
            {
                return *cast(ulong*)&x >> 52;
            }

            // Handle special cases that may overflow or underflow when computing
            // the result that is `scale * (1 + tmp)` without intermediate rounding.
            // Params:
            //     tmp = double value
            //     sbits = the bit representable of `scale`, it has a computed
            //             exponent that may have overflown into the sign bit so
            //             needs to be adjusted before using it as a double.
            //     ki = the argument reduction and exponent adjustment of `scale`,
            //          a positive value mean the result may overflow and negative
            //          means the result may underflow.
            pragma(inline, true)
            static double specialcase(double tmp, ulong sbits, ulong ki)
            {
                if ((ki & 0x80000000) == 0)
                {
                    // k > 0, the exponent of scale might have overflowed by <= 460.
                    sbits -= 1009UL << 52;
                    immutable scale = *cast(double*)&sbits;
                    return 0x1p1009 * (scale + scale * tmp);
                }
                // k < 0, need special care in the subnormal range.
                sbits += 1022UL << 52;
                immutable scale = *cast(double*)&sbits;
                double y = scale + scale * tmp;

                if (fabs(y) < 1.0)
                {
                    // Round y to the right precision before scaling it into the subnormal
                    // range to avoid double rounding that can cause 0.5+E/2 ulp error where
                    // E is the worst-case ulp error outside the subnormal range.
                    immutable one = (y < 0.0) ? -1.0 : 1.0;
                    double lo = scale - y + scale * tmp;
                    double hi = one + y;
                    lo = one - hi + y + lo;
                    y = cast(double)(hi + lo) - one;
                    // Fix the sign of 0.
                    if (y == 0.0)
                    {
                        sbits &= 0x8000000000000000;
                        y = *cast(double*)&sbits;
                    }
                    // The underflow exception needs to be signaled explicitly.
                    cast(void)force_mul(0x1p-1022, 0x1p-1022);
                }
                return 0x1p-1022 * y;
            }

            // N/log(2)
            enum double invln2N = 0x1.71547652b82fep0 * 128;
            // -log(2)/N split into two parts
            enum double negln2hiN = -0x1.62e42fefa0000p-8;
            enum double negln2loN = -0x1.cf79abc9e3b3ap-47;
            // exp polynomial coefficients.
            // abs error: 1.555*2^^-66
            // ulp error: 0.511
            // if |x| < log(2)/256+eps
            // abs error if |x| < log(2)/256+0x1p-15: 1.09*2^^-65
            // abs error if |x| < log(2)/128: 1.7145*2^^-56
            enum double exp_shift = 0x1.8p52;
            enum double[4] exp_poly = [
                0x1.ffffffffffdbdp-2,
                0x1.555555555543cp-3,
                0x1.55555cf172b91p-5,
                0x1.1111167a4d017p-7,
            ];
            // exp2 polynomial coefficients.
            // abs error: 1.2195*2^^-65
            // ulp error: 0.511
            // if |x| < 1/256
            // abs error if |x| < 1/128: 1.9941*2^^-56
            enum double exp2_shift = 0x1.8p52 / 128;
            enum double[5] exp2_poly = [
                0x1.62e42fefa39efp-1,
                0x1.ebfbdff82c424p-3,
                0x1.c6b08d70cf4b5p-5,
                0x1.3b2abd24650ccp-7,
                0x1.5d7e09b4e3a84p-10,
            ];
            // Algorithm:
            //      2^^(k/N) ~= H[k]*(1 + T[k]) for int k in [0,N)
            //      exp_tab[2*k] = *cast(ulong)&T[k]
            //      exp_tab[2*k+1] = *cast(ulong*)&H[k] - (k << 52)/N
            __gshared immutable ulong[256] exp_tab = [
                0x0, 0x3ff0000000000000, 0x3c9b3b4f1a88bf6e, 0x3feff63da9fb3335,
                0xbc7160139cd8dc5d, 0x3fefec9a3e778061, 0xbc905e7a108766d1, 0x3fefe315e86e7f85,
                0x3c8cd2523567f613, 0x3fefd9b0d3158574, 0xbc8bce8023f98efa, 0x3fefd06b29ddf6de,
                0x3c60f74e61e6c861, 0x3fefc74518759bc8, 0x3c90a3e45b33d399, 0x3fefbe3ecac6f383,
                0x3c979aa65d837b6d, 0x3fefb5586cf9890f, 0x3c8eb51a92fdeffc, 0x3fefac922b7247f7,
                0x3c3ebe3d702f9cd1, 0x3fefa3ec32d3d1a2, 0xbc6a033489906e0b, 0x3fef9b66affed31b,
                0xbc9556522a2fbd0e, 0x3fef9301d0125b51, 0xbc5080ef8c4eea55, 0x3fef8abdc06c31cc,
                0xbc91c923b9d5f416, 0x3fef829aaea92de0, 0x3c80d3e3e95c55af, 0x3fef7a98c8a58e51,
                0xbc801b15eaa59348, 0x3fef72b83c7d517b, 0xbc8f1ff055de323d, 0x3fef6af9388c8dea,
                0x3c8b898c3f1353bf, 0x3fef635beb6fcb75, 0xbc96d99c7611eb26, 0x3fef5be084045cd4,
                0x3c9aecf73e3a2f60, 0x3fef54873168b9aa, 0xbc8fe782cb86389d, 0x3fef4d5022fcd91d,
                0x3c8a6f4144a6c38d, 0x3fef463b88628cd6, 0x3c807a05b0e4047d, 0x3fef3f49917ddc96,
                0x3c968efde3a8a894, 0x3fef387a6e756238, 0x3c875e18f274487d, 0x3fef31ce4fb2a63f,
                0x3c80472b981fe7f2, 0x3fef2b4565e27cdd, 0xbc96b87b3f71085e, 0x3fef24dfe1f56381,
                0x3c82f7e16d09ab31, 0x3fef1e9df51fdee1, 0xbc3d219b1a6fbffa, 0x3fef187fd0dad990,
                0x3c8b3782720c0ab4, 0x3fef1285a6e4030b, 0x3c6e149289cecb8f, 0x3fef0cafa93e2f56,
                0x3c834d754db0abb6, 0x3fef06fe0a31b715, 0x3c864201e2ac744c, 0x3fef0170fc4cd831,
                0x3c8fdd395dd3f84a, 0x3feefc08b26416ff, 0xbc86a3803b8e5b04, 0x3feef6c55f929ff1,
                0xbc924aedcc4b5068, 0x3feef1a7373aa9cb, 0xbc9907f81b512d8e, 0x3feeecae6d05d866,
                0xbc71d1e83e9436d2, 0x3feee7db34e59ff7, 0xbc991919b3ce1b15, 0x3feee32dc313a8e5,
                0x3c859f48a72a4c6d, 0x3feedea64c123422, 0xbc9312607a28698a, 0x3feeda4504ac801c,
                0xbc58a78f4817895b, 0x3feed60a21f72e2a, 0xbc7c2c9b67499a1b, 0x3feed1f5d950a897,
                0x3c4363ed60c2ac11, 0x3feece086061892d, 0x3c9666093b0664ef, 0x3feeca41ed1d0057,
                0x3c6ecce1daa10379, 0x3feec6a2b5c13cd0, 0x3c93ff8e3f0f1230, 0x3feec32af0d7d3de,
                0x3c7690cebb7aafb0, 0x3feebfdad5362a27, 0x3c931dbdeb54e077, 0x3feebcb299fddd0d,
                0xbc8f94340071a38e, 0x3feeb9b2769d2ca7, 0xbc87deccdc93a349, 0x3feeb6daa2cf6642,
                0xbc78dec6bd0f385f, 0x3feeb42b569d4f82, 0xbc861246ec7b5cf6, 0x3feeb1a4ca5d920f,
                0x3c93350518fdd78e, 0x3feeaf4736b527da, 0x3c7b98b72f8a9b05, 0x3feead12d497c7fd,
                0x3c9063e1e21c5409, 0x3feeab07dd485429, 0x3c34c7855019c6ea, 0x3feea9268a5946b7,
                0x3c9432e62b64c035, 0x3feea76f15ad2148, 0xbc8ce44a6199769f, 0x3feea5e1b976dc09,
                0xbc8c33c53bef4da8, 0x3feea47eb03a5585, 0xbc845378892be9ae, 0x3feea34634ccc320,
                0xbc93cedd78565858, 0x3feea23882552225, 0x3c5710aa807e1964, 0x3feea155d44ca973,
                0xbc93b3efbf5e2228, 0x3feea09e667f3bcd, 0xbc6a12ad8734b982, 0x3feea012750bdabf,
                0xbc6367efb86da9ee, 0x3fee9fb23c651a2f, 0xbc80dc3d54e08851, 0x3fee9f7df9519484,
                0xbc781f647e5a3ecf, 0x3fee9f75e8ec5f74, 0xbc86ee4ac08b7db0, 0x3fee9f9a48a58174,
                0xbc8619321e55e68a, 0x3fee9feb564267c9, 0x3c909ccb5e09d4d3, 0x3feea0694fde5d3f,
                0xbc7b32dcb94da51d, 0x3feea11473eb0187, 0x3c94ecfd5467c06b, 0x3feea1ed0130c132,
                0x3c65ebe1abd66c55, 0x3feea2f336cf4e62, 0xbc88a1c52fb3cf42, 0x3feea427543e1a12,
                0xbc9369b6f13b3734, 0x3feea589994cce13, 0xbc805e843a19ff1e, 0x3feea71a4623c7ad,
                0xbc94d450d872576e, 0x3feea8d99b4492ed, 0x3c90ad675b0e8a00, 0x3feeaac7d98a6699,
                0x3c8db72fc1f0eab4, 0x3feeace5422aa0db, 0xbc65b6609cc5e7ff, 0x3feeaf3216b5448c,
                0x3c7bf68359f35f44, 0x3feeb1ae99157736, 0xbc93091fa71e3d83, 0x3feeb45b0b91ffc6,
                0xbc5da9b88b6c1e29, 0x3feeb737b0cdc5e5, 0xbc6c23f97c90b959, 0x3feeba44cbc8520f,
                0xbc92434322f4f9aa, 0x3feebd829fde4e50, 0xbc85ca6cd7668e4b, 0x3feec0f170ca07ba,
                0x3c71affc2b91ce27, 0x3feec49182a3f090, 0x3c6dd235e10a73bb, 0x3feec86319e32323,
                0xbc87c50422622263, 0x3feecc667b5de565, 0x3c8b1c86e3e231d5, 0x3feed09bec4a2d33,
                0xbc91bbd1d3bcbb15, 0x3feed503b23e255d, 0x3c90cc319cee31d2, 0x3feed99e1330b358,
                0x3c8469846e735ab3, 0x3feede6b5579fdbf, 0xbc82dfcd978e9db4, 0x3feee36bbfd3f37a,
                0x3c8c1a7792cb3387, 0x3feee89f995ad3ad, 0xbc907b8f4ad1d9fa, 0x3feeee07298db666,
                0xbc55c3d956dcaeba, 0x3feef3a2b84f15fb, 0xbc90a40e3da6f640, 0x3feef9728de5593a,
                0xbc68d6f438ad9334, 0x3feeff76f2fb5e47, 0xbc91eee26b588a35, 0x3fef05b030a1064a,
                0x3c74ffd70a5fddcd, 0x3fef0c1e904bc1d2, 0xbc91bdfbfa9298ac, 0x3fef12c25bd71e09,
                0x3c736eae30af0cb3, 0x3fef199bdd85529c, 0x3c8ee3325c9ffd94, 0x3fef20ab5fffd07a,
                0x3c84e08fd10959ac, 0x3fef27f12e57d14b, 0x3c63cdaf384e1a67, 0x3fef2f6d9406e7b5,
                0x3c676b2c6c921968, 0x3fef3720dcef9069, 0xbc808a1883ccb5d2, 0x3fef3f0b555dc3fa,
                0xbc8fad5d3ffffa6f, 0x3fef472d4a07897c, 0xbc900dae3875a949, 0x3fef4f87080d89f2,
                0x3c74a385a63d07a7, 0x3fef5818dcfba487, 0xbc82919e2040220f, 0x3fef60e316c98398,
                0x3c8e5a50d5c192ac, 0x3fef69e603db3285, 0x3c843a59ac016b4b, 0x3fef7321f301b460,
                0xbc82d52107b43e1f, 0x3fef7c97337b9b5f, 0xbc892ab93b470dc9, 0x3fef864614f5a129,
                0x3c74b604603a88d3, 0x3fef902ee78b3ff6, 0x3c83c5ec519d7271, 0x3fef9a51fbc74c83,
                0xbc8ff7128fd391f0, 0x3fefa4afa2a490da, 0xbc8dae98e223747d, 0x3fefaf482d8e67f1,
                0x3c8ec3bc41aa2008, 0x3fefba1bee615a27, 0x3c842b94c3a9eb32, 0x3fefc52b376bba97,
                0x3c8a64a931d185ee, 0x3fefd0765b6e4540, 0xbc8e37bae43be3ed, 0x3fefdbfdad9cbe14,
                0x3c77893b4d91cd9d, 0x3fefe7c1819e90d8, 0x3c5305c14160cc89, 0x3feff3c22b8f71f1,
            ];

            uint abstop = top12(x) & 0x7FF;
            // abstop - top12(0x1p-54) >= top12(512.0) - top12(0x1p-54)
            if (abstop - 969 >= 63)
            {
                if (abstop - 969 >= 0x80000000)
                {
                    // Avoid spurious underflow for tiny x.
                    immutable one = 1.0 + x;
                    return sign_bias ? -one : one;
                }
                // abstop >= top12(1024.0))
                if (abstop >= 1033)
                {
                    // Note: inf and nan are already handled.
                    if (*cast(ulong*)&x >> 63)
                        return force_underflow(sign_bias);
                    else
                        return force_overflow(sign_bias);
                }
                // Large x is special cased below.
                abstop = 0;
            }

            // exp(x) = 2^^(k/N) * exp(r), with exp(r) in [2^^(-1/2N),2^^(1/2N)].
            // x = log(2)/N*k + r, with int k and r in [-log(2)/2N, log(2)/2N].
            immutable z = invln2N * x;
            // z - kd is in [-1, 1] in non-nearest rounding modes.
            double kd = z + exp_shift;
            immutable ki = *cast(ulong*)&kd;
            kd -= exp_shift;

            double r = x + kd * negln2hiN + kd * negln2loN;
            // The code assumes 2^^-200 < |xtail| < 2^^-8/N.
            r += xtail;
            // 2^^(k/N) ~= scale * (1 + tail).
            immutable idx = 2 * (ki % 128);
            immutable top = (ki + sign_bias) << 45;
            immutable tail = *cast(double*)&exp_tab[idx];
            // This is only a valid scale when -1023*N < k < 1024*N.
            immutable sbits = exp_tab[idx + 1] + top;
            // exp(x) = 2^(k/N) * exp(r) ~= scale + scale * (tail + exp(r) - 1).
            // Evaluation is optimized assuming superscalar pipelined execution.
            immutable r2 = r * r;
            // Worst case error is less than 0.5+1.11/N+(abs poly error * 2^53) ulp.
            immutable tmp = tail + r + r2 * (exp_poly[0] + r * exp_poly[1]) +
                r2 * r2 * (exp_poly[2] + r * exp_poly[3]);
            if (abstop == 0)
                return specialcase(tmp, sbits, ki);
            immutable scale = *cast(double*)&sbits;
            // Note: tmp == 0 or |tmp| > 2^-200 and scale > 2^-739, so there
            // is no spurious underflow here even without fma.
            return scale + scale * tmp;
        }

        // Params:
        //      i = the bit representation of a non-zero finite floating-point value
        // Returns:
        //      0 if input value is not an integer, 1 if odd, 2 if even.
        pragma(inline, true)
        static int checkint(ulong i)
        {
            int e = i >> 52 & 0x7FF;
            if (e < 0x3FF)
                return 0;
            if (e > 0x3FF + 52)
                return 2;
            if (i & ((1UL << (0x3FF + 52 - e)) - 1))
                return 0;
            if (i & (1UL << (0x3FF + 52 - e)))
                return 1;
            return 2;
        }

        // Params:
        //      i = the bit representation of a floating-point value
        // Returns:
        //      true if input is the bit representation of 0, infinity, or nan
        pragma(inline, true)
        static bool zeroinfnan(ulong i)
        {
            return (2 * i - 1) >= (2 * 0x7FF0000000000000UL - 1);
        }

        ulong ix = *cast(ulong*)&dx;
        ulong iy = *cast(ulong*)&dy;
        uint topx = *cast(ulong*)&dx >> 52;
        uint topy = *cast(ulong*)&dy >> 52;

        uint sign_bias = 0;

        // Handle special cases.
        if (topx - 0x001 >= 0x7FE || (topy & 0x7FF) - 0x3BE >= 0x80)
        {
            // y is zero or infinite
            if (zeroinfnan(iy))
            {
                if (2 * iy == 0)
                    return 0 ? dx + dy : 1.0;
                if (ix == 0x3FF0000000000000UL)
                    return 0 ? dx + dy : 1.0;
                if (2 * ix > 2 * 0x7FF0000000000000UL || 2 * iy > 2 * 0x7FF0000000000000UL)
                    return dx + dy;
                if (2 * ix == 2 * 0x3FF0000000000000UL)
                    return 1.0;
                if ((2 * ix < 2 * 0x3FF0000000000000UL) == !(iy >> 63))
                    return 0.0;
                return dy * dy;
            }
            // x is zero or infinite
            if (zeroinfnan(ix))
            {
                double x2 = dx * dx;
                if (ix >> 63 && checkint(iy) == 1)
                    x2 = -x2;
                // Without the barrier some versions of clang hoist the 1/x2 and
                // thus division by zero exception can be signaled spuriously.
                return iy >> 63 ? force_div(1, x2) : x2;
            }
            // Here x and y are non-zero finite.
            if (ix >> 63)
            {
                // Finite x < 0.
                int yint = checkint(iy);
                if (yint == 0)
                    return force_invalid(dx);
                if (yint == 1)
                    sign_bias = (0x800 << 7);
                ix &= 0x7FFFFFFFFFFFFFFFUL;
                topx &= 0x7FF;
            }
            if ((topy & 0x7FF) - 0x3BE >= 0x80)
            {
                // Note: sign_bias == 0 here because y is not odd.
                if (ix == 0x3FF0000000000000UL)
                    return 1.0;
                if ((topy & 0x7FF) < 0x3BE)
                {
                    // |y| < 2^-65, x^y ~= 1 + y*log(x).
                    return ix > 0x3FF0000000000000UL ? 1.0 + dy : 1.0 - dy;
                }
                return (ix > 0x3FF0000000000000UL) == (topy < 0x800) ?
                    force_overflow(0) : force_underflow(0);
            }
            if (topx == 0)
            {
                // Normalize subnormal x so exponent becomes negative.
                immutable norm = dx * 0x1p52;
                ix = *cast(ulong*)&norm;
                ix &= 0x7FFFFFFFFFFFFFFFUL;
                ix -= 52UL << 52;
            }
        }

        double lo;
        immutable hi = log_inline(ix, lo);

        immutable iyhi = iy & -1UL << 27;
        immutable yhi = *cast(double*)&iyhi;
        immutable ylo = dy - yhi;
        immutable ilhi = *cast(ulong*)&hi & -1UL << 27;
        immutable lhi = *cast(double*)&ilhi;
        immutable llo = hi - lhi + lo;
        immutable ehi = yhi * lhi;
        immutable elo = ylo * lhi + dy * llo; // |elo| < |ehi| * 2^-25.

        return exp_inline(ehi, elo, sign_bias);
    }
}
