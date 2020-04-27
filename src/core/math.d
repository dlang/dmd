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
 * Returns |x|
 *
 *      $(TABLE_SV
 *      $(TR $(TH x)                 $(TH fabs(x)))
 *      $(TR $(TD $(PLUSMN)0.0)      $(TD +0.0) )
 *      $(TR $(TD $(PLUSMN)$(INFIN)) $(TD +$(INFIN)) )
 *      )
 */
float fabs(float x);    /* intrinsic */
double fabs(double x);  /* intrinsic */ /// ditto
real fabs(real x);      /* intrinsic */ /// ditto

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
 * D language types specify a minimum precision, not a maximum. The
 * `toPrec()` function forces rounding of the argument `f` to the
 * precision of the specified floating point type `T`.
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

    /+ Uncomment these once compiler support has been added.
    enum real PIR = 0xc.90fdaa22168c235p-2;
    enum double PID = 0x1.921fb54442d18p+1;
    enum float PIF = 0x1.921fb6p+1;

    assert(toPrec!float(PIR) == PIF);
    assert(toPrec!double(PIR) == PID);
    assert(toPrec!real(PIR) == PIR);
    assert(toPrec!float(PID) == PIF);
    assert(toPrec!double(PID) == PID);
    assert(toPrec!real(PID) == PID);
    assert(toPrec!float(PIF) == PIF);
    assert(toPrec!double(PIF) == PIF);
    assert(toPrec!real(PIF) == PIF);
    +/
}
