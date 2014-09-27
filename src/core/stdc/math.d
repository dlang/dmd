/**
 * D header file for C99.
 *
 * $(C_HEADER_DESCRIPTION pubs.opengroup.org/onlinepubs/009695399/basedefs/_math.h.html, _math.h)
 *
 * Copyright: Copyright Sean Kelly 2005 - 2012.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Sean Kelly
 * Source:    $(DRUNTIMESRC core/stdc/_math.d)
 */

module core.stdc.math;

private import core.stdc.config;

extern (C):
@trusted: // All functions here operate on floating point and integer values only.
nothrow:
@nogc:

///
alias float  float_t;
///
alias double double_t;

///
enum double HUGE_VAL      = double.infinity;
///
enum double HUGE_VALF     = float.infinity;
///
enum double HUGE_VALL     = real.infinity;

///
enum float INFINITY       = float.infinity;
///
enum float NAN            = float.nan;

///
enum int FP_ILOGB0        = int.min;
///
enum int FP_ILOGBNAN      = int.min;

///
enum int MATH_ERRNO       = 1;
///
enum int MATH_ERREXCEPT   = 2;
///
enum int math_errhandling = MATH_ERRNO | MATH_ERREXCEPT;

version( none )
{
    //
    // these functions are all macros in C
    //

    //int fpclassify(real-floating x);
    int fpclassify(float x);
    int fpclassify(double x);
    int fpclassify(real x);

    //int isfinite(real-floating x);
    int isfinite(float x);
    int isfinite(double x);
    int isfinite(real x);

    //int isinf(real-floating x);
    int isinf(float x);
    int isinf(double x);
    int isinf(real x);

    //int isnan(real-floating x);
    int isnan(float x);
    int isnan(double x);
    int isnan(real x);

    //int isnormal(real-floating x);
    int isnormal(float x);
    int isnormal(double x);
    int isnormal(real x);

    //int signbit(real-floating x);
    int signbit(float x);
    int signbit(double x);
    int signbit(real x);

    //int isgreater(real-floating x, real-floating y);
    int isgreater(float x, float y);
    int isgreater(double x, double y);
    int isgreater(real x, real y);

    //int isgreaterequal(real-floating x, real-floating y);
    int isgreaterequal(float x, float y);
    int isgreaterequal(double x, double y);
    int isgreaterequal(real x, real y);

    //int isless(real-floating x, real-floating y);
    int isless(float x, float y);
    int isless(double x, double y);
    int isless(real x, real y);

    //int islessequal(real-floating x, real-floating y);
    int islessequal(float x, float y);
    int islessequal(double x, double y);
    int islessequal(real x, real y);

    //int islessgreater(real-floating x, real-floating y);
    int islessgreater(float x, float y);
    int islessgreater(double x, double y);
    int islessgreater(real x, real y);

    //int isunordered(real-floating x, real-floating y);
    int isunordered(float x, float y);
    int isunordered(double x, double y);
    int isunordered(real x, real y);
}

version( CRuntime_DigitalMars )
{
    enum
    {
        ///
        FP_NANS        = 0,
        ///
        FP_NANQ        = 1,
        ///
        FP_INFINITE    = 2,
        ///
        FP_NORMAL      = 3,
        ///
        FP_SUBNORMAL   = 4,
        ///
        FP_ZERO        = 5,
        ///
        FP_NAN         = FP_NANQ,
        ///
        FP_EMPTY       = 6,
        ///
        FP_UNSUPPORTED = 7,
    }

    enum
    {
        ///
        FP_FAST_FMA  = 0,
        ///
        FP_FAST_FMAF = 0,
        ///
        FP_FAST_FMAL = 0,
    }

    uint __fpclassify_f(float x);
    uint __fpclassify_d(double x);
    uint __fpclassify_ld(real x);

  extern (D)
  {
    //int fpclassify(real-floating x);
    ///
    int fpclassify(float x)     { return __fpclassify_f(x); }
    ///
    int fpclassify(double x)    { return __fpclassify_d(x); }
    ///
    int fpclassify(real x)
    {
        return (real.sizeof == double.sizeof)
            ? __fpclassify_d(x)
            : __fpclassify_ld(x);
    }

    //int isfinite(real-floating x);
    ///
    int isfinite(float x)       { return fpclassify(x) >= FP_NORMAL; }
    ///
    int isfinite(double x)      { return fpclassify(x) >= FP_NORMAL; }
    ///
    int isfinite(real x)        { return fpclassify(x) >= FP_NORMAL; }

    //int isinf(real-floating x);
    ///
    int isinf(float x)          { return fpclassify(x) == FP_INFINITE; }
    ///
    int isinf(double x)         { return fpclassify(x) == FP_INFINITE; }
    ///
    int isinf(real x)           { return fpclassify(x) == FP_INFINITE; }

    //int isnan(real-floating x);
    ///
    int isnan(float x)          { return fpclassify(x) <= FP_NANQ;   }
    ///
    int isnan(double x)         { return fpclassify(x) <= FP_NANQ;   }
    ///
    int isnan(real x)           { return fpclassify(x) <= FP_NANQ;   }

    //int isnormal(real-floating x);
    ///
    int isnormal(float x)       { return fpclassify(x) == FP_NORMAL; }
    ///
    int isnormal(double x)      { return fpclassify(x) == FP_NORMAL; }
    ///
    int isnormal(real x)        { return fpclassify(x) == FP_NORMAL; }

    //int signbit(real-floating x);
    ///
    int signbit(float x)     { return (cast(short*)&(x))[1] & 0x8000; }
    ///
    int signbit(double x)    { return (cast(short*)&(x))[3] & 0x8000; }
    ///
    int signbit(real x)
    {
        return (real.sizeof == double.sizeof)
            ? (cast(short*)&(x))[3] & 0x8000
            : (cast(short*)&(x))[4] & 0x8000;
    }
  }
}
else version( CRuntime_Microsoft ) // fully supported since MSVCRT 12 (VS 2013) only
{
  version( all ) // legacy stuff to be removed in the future
  {
    enum
    {
        _FPCLASS_SNAN = 1,
        _FPCLASS_QNAN = 2,
        _FPCLASS_NINF = 4,
        _FPCLASS_NN   = 8,
        _FPCLASS_ND   = 0x10,
        _FPCLASS_NZ   = 0x20,
        _FPCLASS_PZ   = 0x40,
        _FPCLASS_PD   = 0x80,
        _FPCLASS_PN   = 0x100,
        _FPCLASS_PINF = 0x200,
    }

    //deprecated("Please use the standard C99 function copysignf() instead.")
    float _copysignf(float x, float s);

    //deprecated("_chgsignf(x) is a non-standard MS extension. Please consider using -x instead.")
    float _chgsignf(float x);

    version( Win64 ) // not available in 32-bit runtimes
    {
        //deprecated("Please use the standard C99 function isfinite() instead.")
        int _finitef(float x);

        //deprecated("Please use the standard C99 function isnan() instead.")
        int _isnanf(float x);

        //deprecated("Please use the standard C99 function fpclassify() instead.")
        int _fpclassf(float x);
    }

    //deprecated("Please use the standard C99 function copysign() instead.")
    double _copysign(double x, double s);

    //deprecated("_chgsign(x) is a non-standard MS extension. Please consider using -x instead.")
    double _chgsign(double x);

    //deprecated("Please use the standard C99 function isfinite() instead.")
    int _finite(double x);

    //deprecated("Please use the standard C99 function isnan() instead.")
    int _isnan(double x);

    //deprecated("Please use the standard C99 function fpclassify() instead.")
    int _fpclass(double x);
  }

    enum
    {
        ///
        FP_SUBNORMAL = -2,
        ///
        FP_NORMAL    = -1,
        ///
        FP_ZERO      =  0,
        ///
        FP_INFINITE  =  1,
        ///
        FP_NAN       =  2,
    }

    private short _fdclass(float x);
    private short _dclass(double x);

    private int _fdsign(float x);
    private int _dsign(double x);

  extern(D)
  {
    //int fpclassify(real-floating x);
    ///
    int fpclassify(float x)     { return _fdclass(x); }
    ///
    int fpclassify(double x)    { return _dclass(x);  }
    ///
    int fpclassify(real x)
    {
        static if (real.sizeof == double.sizeof)
            return _dclass(cast(double) x);
        else
            static assert(false, "fpclassify(real) not supported by MS C runtime");
    }

    //int isfinite(real-floating x);
    ///
    int isfinite(float x)       { return fpclassify(x) <= 0; }
    ///
    int isfinite(double x)      { return fpclassify(x) <= 0; }
    ///
    int isfinite(real x)        { return fpclassify(x) <= 0; }

    //int isinf(real-floating x);
    ///
    int isinf(float x)          { return fpclassify(x) == FP_INFINITE; }
    ///
    int isinf(double x)         { return fpclassify(x) == FP_INFINITE; }
    ///
    int isinf(real x)           { return fpclassify(x) == FP_INFINITE; }

    //int isnan(real-floating x);
    version( none ) // requires MSVCRT 12+ (VS 2013)
    {
        ///
        int isnan(float x)      { return fpclassify(x) == FP_NAN; }
        ///
        int isnan(double x)     { return fpclassify(x) == FP_NAN; }
        ///
        int isnan(real x)       { return fpclassify(x) == FP_NAN; }
    }
    else // for backward compatibility with older runtimes
    {
        ///
        int isnan(float x)      { version(Win64) return _isnanf(x); else return _isnan(cast(double) x); }
        ///
        int isnan(double x)     { return _isnan(x); }
        ///
        int isnan(real x)       { return _isnan(cast(double) x); }
    }

    //int isnormal(real-floating x);
    ///
    int isnormal(float x)       { return fpclassify(x) == FP_NORMAL; }
    ///
    int isnormal(double x)      { return fpclassify(x) == FP_NORMAL; }
    ///
    int isnormal(real x)        { return fpclassify(x) == FP_NORMAL; }

    //int signbit(real-floating x);
    ///
    int signbit(float x)     { return _fdsign(x); }
    ///
    int signbit(double x)    { return _dsign(x);  }
    ///
    int signbit(real x)
    {
        static if (real.sizeof == double.sizeof)
            return _dsign(cast(double) x);
        else
            return (cast(short*)&(x))[4] & 0x8000;
    }
  }
}
else version( linux )
{
    enum
    {
        ///
        FP_NAN,
        ///
        FP_INFINITE,
        ///
        FP_ZERO,
        ///
        FP_SUBNORMAL,
        ///
        FP_NORMAL,
    }

    enum
    {
        ///
        FP_FAST_FMA  = 0,
        ///
        FP_FAST_FMAF = 0,
        ///
        FP_FAST_FMAL = 0,
    }

    int __fpclassifyf(float x);
    int __fpclassify(double x);
    int __fpclassifyl(real x);

    int __finitef(float x);
    int __finite(double x);
    int __finitel(real x);

    int __isinff(float x);
    int __isinf(double x);
    int __isinfl(real x);

    int __isnanf(float x);
    int __isnan(double x);
    int __isnanl(real x);

    int __signbitf(float x);
    int __signbit(double x);
    int __signbitl(real x);

  extern (D)
  {
    //int fpclassify(real-floating x);
      ///
    int fpclassify(float x)     { return __fpclassifyf(x); }
    ///
    int fpclassify(double x)    { return __fpclassify(x);  }
    ///
    int fpclassify(real x)
    {
        return (real.sizeof == double.sizeof)
            ? __fpclassify(x)
            : __fpclassifyl(x);
    }

    //int isfinite(real-floating x);
    ///
    int isfinite(float x)       { return __finitef(x); }
    ///
    int isfinite(double x)      { return __finite(x);  }
    ///
    int isfinite(real x)
    {
        return (real.sizeof == double.sizeof)
            ? __finite(x)
            : __finitel(x);
    }

    //int isinf(real-floating x);
    ///
    int isinf(float x)          { return __isinff(x);  }
    ///
    int isinf(double x)         { return __isinf(x);   }
    ///
    int isinf(real x)
    {
        return (real.sizeof == double.sizeof)
            ? __isinf(x)
            : __isinfl(x);
    }

    //int isnan(real-floating x);
    ///
    int isnan(float x)          { return __isnanf(x);  }
    ///
    int isnan(double x)         { return __isnan(x);   }
    ///
    int isnan(real x)
    {
        return (real.sizeof == double.sizeof)
            ? __isnan(x)
            : __isnanl(x);
    }

    //int isnormal(real-floating x);
    ///
    int isnormal(float x)       { return fpclassify(x) == FP_NORMAL; }
    ///
    int isnormal(double x)      { return fpclassify(x) == FP_NORMAL; }
    ///
    int isnormal(real x)        { return fpclassify(x) == FP_NORMAL; }

    //int signbit(real-floating x);
    ///
    int signbit(float x)     { return __signbitf(x); }
    ///
    int signbit(double x)    { return __signbit(x);  }
    ///
    int signbit(real x)
    {
        return (real.sizeof == double.sizeof)
            ? __signbit(x)
            : __signbitl(x);
    }
  }
}
else version( MinGW )
{
    enum
    {
        ///
        FP_NAN = 0x0100,
        ///
        FP_NORMAL = 0x0400,
        ///
        FP_INFINITE = FP_NAN | FP_NORMAL,
        ///
        FP_ZERO = 0x0400,
        ///
        FP_SUBNORMAL = FP_NORMAL | FP_ZERO
    }

    int __fpclassifyf(float x);
    int __fpclassify(double x);
    int __fpclassifyl(real x);

    int __isnanf(float x);
    int __isnan(double x);
    int __isnanl(real x);

    int __signbitf(float x);
    int __signbit(double x);
    int __signbitl(real x);

  extern (D)
  {
    //int fpclassify(real-floating x);
      ///
    int fpclassify(float x)     { return __fpclassifyf(x); }
    ///
    int fpclassify(double x)    { return __fpclassify(x);  }
    ///
    int fpclassify(real x)
    {
        return (real.sizeof == double.sizeof)
            ? __fpclassify(x)
            : __fpclassifyl(x);
    }

    //int isfinite(real-floating x);
    ///
    int isfinite(float x)       { return (fpclassify(x) & FP_NORMAL) == 0; }
    ///
    int isfinite(double x)      { return (fpclassify(x) & FP_NORMAL) == 0; }
    ///
    int isfinite(real x)        { return (fpclassify(x) & FP_NORMAL) == 0; }

    //int isinf(real-floating x);
    ///
    int isinf(float x)          { return fpclassify(x) == FP_INFINITE; }
    ///
    int isinf(double x)         { return fpclassify(x) == FP_INFINITE; }
    ///
    int isinf(real x)           { return fpclassify(x) == FP_INFINITE; }

    //int isnan(real-floating x);
    ///
    int isnan(float x)          { return __isnanf(x);  }
    ///
    int isnan(double x)         { return __isnan(x);   }
    ///
    int isnan(real x)
    {
        return (real.sizeof == double.sizeof)
            ? __isnan(x)
            : __isnanl(x);
    }

    //int isnormal(real-floating x);
    ///
    int isnormal(float x)       { return fpclassify(x) == FP_NORMAL; }
    ///
    int isnormal(double x)      { return fpclassify(x) == FP_NORMAL; }
    ///
    int isnormal(real x)        { return fpclassify(x) == FP_NORMAL; }

    //int signbit(real-floating x);
    ///
    int signbit(float x)     { return __signbitf(x); }
    ///
    int signbit(double x)    { return __signbit(x);  }
    ///
    int signbit(real x)
    {
        return (real.sizeof == double.sizeof)
            ? __signbit(x)
            : __signbitl(x);
    }
  }
}
else version( OSX )
{
    enum
    {
        ///
        FP_NAN         = 1,
        ///
        FP_INFINITE    = 2,
        ///
        FP_ZERO        = 3,
        ///
        FP_NORMAL      = 4,
        ///
        FP_SUBNORMAL   = 5,
        ///
        FP_SUPERNORMAL = 6,
    }

    enum
    {
        ///
        FP_FAST_FMA  = 0,
        ///
        FP_FAST_FMAF = 0,
        ///
        FP_FAST_FMAL = 0,
    }

    int __fpclassifyf(float x);
    int __fpclassifyd(double x);
    int __fpclassify(real x);

    int __isfinitef(float x);
    int __isfinited(double x);
    int __isfinite(real x);

    int __isinff(float x);
    int __isinfd(double x);
    int __isinf(real x);

    int __isnanf(float x);
    int __isnand(double x);
    int __isnan(real x);

    int __signbitf(float x);
    int __signbitd(double x);
    int __signbitl(real x);

  extern (D)
  {
    //int fpclassify(real-floating x);
      ///
    int fpclassify(float x)     { return __fpclassifyf(x); }
    ///
    int fpclassify(double x)    { return __fpclassifyd(x); }
    ///
    int fpclassify(real x)
    {
        return (real.sizeof == double.sizeof)
            ? __fpclassifyd(x)
            : __fpclassify(x);
    }

    //int isfinite(real-floating x);
    ///
    int isfinite(float x)       { return __isfinitef(x); }
    ///
    int isfinite(double x)      { return __isfinited(x); }
    ///
    int isfinite(real x)
    {
        return (real.sizeof == double.sizeof)
            ? __isfinited(x)
            : __isfinite(x);
    }

    //int isinf(real-floating x);
    ///
    int isinf(float x)          { return __isinff(x); }
    ///
    int isinf(double x)         { return __isinfd(x); }
    ///
    int isinf(real x)
    {
        return (real.sizeof == double.sizeof)
            ? __isinfd(x)
            : __isinf(x);
    }

    //int isnan(real-floating x);
    ///
    int isnan(float x)          { return __isnanf(x); }
    ///
    int isnan(double x)         { return __isnand(x); }
    ///
    int isnan(real x)
    {
        return (real.sizeof == double.sizeof)
            ? __isnand(x)
            : __isnan(x);
    }

    //int isnormal(real-floating x);
    ///
    int isnormal(float x)       { return fpclassify(x) == FP_NORMAL; }
    ///
    int isnormal(double x)      { return fpclassify(x) == FP_NORMAL; }
    ///
    int isnormal(real x)        { return fpclassify(x) == FP_NORMAL; }

    //int signbit(real-floating x);
    ///
    int signbit(float x)     { return __signbitf(x); }
    ///
    int signbit(double x)    { return __signbitd(x); }
    ///
    int signbit(real x)
    {
        return (real.sizeof == double.sizeof)
            ? __signbitd(x)
            : __signbitl(x);
    }
  }
}
else version( FreeBSD )
{
    enum
    {
        ///
        FP_INFINITE  = 0x01,
        ///
        FP_NAN       = 0x02,
        ///
        FP_NORMAL    = 0x04,
        ///
        FP_SUBNORMAL = 0x08,
        ///
        FP_ZERO      = 0x10,
    }

    enum
    {
        ///
        FP_FAST_FMA  = 0,
        ///
        FP_FAST_FMAF = 0,
        ///
        FP_FAST_FMAL = 0,
    }

    int __fpclassifyd(double);
    int __fpclassifyf(float);
    int __fpclassifyl(real);
    int __isfinitef(float);
    int __isfinite(double);
    int __isfinitel(real);
    int __isinff(float);
    int __isinfl(real);
    int __isnanl(real);
    int __isnormalf(float);
    int __isnormal(double);
    int __isnormall(real);
    int __signbit(double);
    int __signbitf(float);
    int __signbitl(real);

  extern (D)
  {
    //int fpclassify(real-floating x);
      ///
    int fpclassify(float x)     { return __fpclassifyf(x); }
    ///
    int fpclassify(double x)    { return __fpclassifyd(x); }
    ///
    int fpclassify(real x)      { return __fpclassifyl(x); }

    //int isfinite(real-floating x);
    ///
    int isfinite(float x)       { return __isfinitef(x); }
    ///
    int isfinite(double x)      { return __isfinite(x); }
    ///
    int isfinite(real x)        { return __isfinitel(x); }

    //int isinf(real-floating x);
    ///
    int isinf(float x)          { return __isinff(x); }
    ///
    int isinf(double x)         { return __isinfl(x); }
    ///
    int isinf(real x)           { return __isinfl(x); }

    //int isnan(real-floating x);
    ///
    int isnan(float x)          { return __isnanl(x); }
    ///
    int isnan(double x)         { return __isnanl(x); }
    ///
    int isnan(real x)           { return __isnanl(x); }

    //int isnormal(real-floating x);
    ///
    int isnormal(float x)       { return __isnormalf(x); }
    ///
    int isnormal(double x)      { return __isnormal(x); }
    ///
    int isnormal(real x)        { return __isnormall(x); }

    //int signbit(real-floating x);
    ///
    int signbit(float x)        { return __signbitf(x); }
    ///
    int signbit(double x)       { return __signbit(x); }
    ///
    int signbit(real x)         { return __signbit(x); }
  }
}
else version( Solaris )
{
    int __isnanf(float x);
    int __isnan(double x);
    int __isnanl(real x);

  extern (D)
  {
    //int isnan(real-floating x);
      ///
    int isnan(float x)          { return __isnanf(x);  }
    ///
    int isnan(double x)         { return __isnan(x);   }
    ///
    int isnan(real x)
    {
        return (real.sizeof == double.sizeof)
            ? __isnan(x)
            : __isnanl(x);
    }
  }
}
else version( Android )
{
    enum
    {
        ///
        FP_INFINITE  = 0x01,
        ///
        FP_NAN       = 0x02,
        ///
        FP_NORMAL    = 0x04,
        ///
        FP_SUBNORMAL = 0x08,
        ///
        FP_ZERO      = 0x10,
    }

    ///
    enum FP_FAST_FMAF;

    int __fpclassifyd(double);
    int __fpclassifyf(float);
    int __fpclassifyl(real);

    int __isfinitef(float);
    int __isfinite(double);
    int __isfinitel(real);

    int __isinff(float);
    int __isinf(double);
    int __isinfl(real);

    int isnanf(float);
    int isnan(double);
    int __isnanl(real);

    int __isnormalf(float);
    int __isnormal(double);
    int __isnormall(real);

    int __signbit(double);
    int __signbitf(float);
    int __signbitl(real);

  extern (D)
  {
    //int fpclassify(real-floating x);
      ///
    int fpclassify(float x)     { return __fpclassifyf(x); }
    ///
    int fpclassify(double x)    { return __fpclassifyd(x); }
    ///
    int fpclassify(real x)      { return __fpclassifyl(x); }

    //int isfinite(real-floating x);
    ///
    int isfinite(float x)       { return __isfinitef(x); }
    ///
    int isfinite(double x)      { return __isfinite(x); }
    ///
    int isfinite(real x)        { return __isfinitel(x); }

    //int isinf(real-floating x);
    ///
    int isinf(float x)          { return __isinff(x); }
    ///
    int isinf(double x)         { return __isinf(x); }
    ///
    int isinf(real x)           { return __isinfl(x); }

    //int isnan(real-floating x);
    ///
    int isnan(float x)          { return isnanf(x); }
    ///
    int isnan(real x)           { return __isnanl(x); }

    //int isnormal(real-floating x);
    ///
    int isnormal(float x)       { return __isnormalf(x); }
    ///
    int isnormal(double x)      { return __isnormal(x); }
    ///
    int isnormal(real x)        { return __isnormall(x); }

    //int signbit(real-floating x);
    ///
    int signbit(float x)        { return __signbitf(x); }
    ///
    int signbit(double x)       { return __signbit(x); }
    ///
    int signbit(real x)         { return __signbitl(x); }
  }
}

extern (D)
{
    //int isgreater(real-floating x, real-floating y);
    ///
    int isgreater(float x, float y)        { return x > y && !isunordered(x, y); }
    ///
    int isgreater(double x, double y)      { return x > y && !isunordered(x, y); }
    ///
    int isgreater(real x, real y)          { return x > y && !isunordered(x, y); }

    //int isgreaterequal(real-floating x, real-floating y);
    ///
    int isgreaterequal(float x, float y)   { return x >= y && !isunordered(x, y); }
    ///
    int isgreaterequal(double x, double y) { return x >= y && !isunordered(x, y); }
    ///
    int isgreaterequal(real x, real y)     { return x >= y && !isunordered(x, y); }

    //int isless(real-floating x, real-floating y);
    ///
    int isless(float x, float y)           { return x < y && !isunordered(x, y); }
    ///
    int isless(double x, double y)         { return x < y && !isunordered(x, y); }
    ///
    int isless(real x, real y)             { return x < y && !isunordered(x, y); }

    //int islessequal(real-floating x, real-floating y);
    ///
    int islessequal(float x, float y)      { return x <= y && !isunordered(x, y); }
    ///
    int islessequal(double x, double y)    { return x <= y && !isunordered(x, y); }
    ///
    int islessequal(real x, real y)        { return x <= y && !isunordered(x, y); }

    //int islessgreater(real-floating x, real-floating y);
    ///
    int islessgreater(float x, float y)    { return x != y && !isunordered(x, y); }
    ///
    int islessgreater(double x, double y)  { return x != y && !isunordered(x, y); }
    ///
    int islessgreater(real x, real y)      { return x != y && !isunordered(x, y); }

    //int isunordered(real-floating x, real-floating y);
    ///
    int isunordered(float x, float y)      { return isnan(x) || isnan(y); }
    ///
    int isunordered(double x, double y)    { return isnan(x) || isnan(y); }
    ///
    int isunordered(real x, real y)        { return isnan(x) || isnan(y); }
}

/* MS define some functions inline.
 * Additionally, their *l functions work with a 64-bit long double and are thus
 * useless for 80-bit D reals. So we use our own wrapper implementations working
 * internally with reduced 64-bit precision.
 * This also enables relaxing real to 64-bit double.
 */
version( CRuntime_Microsoft ) // fully supported since MSVCRT 12 (VS 2013) only
{
    ///
    double  acos(double x);
    ///
    float   acosf(float x);
    ///
    extern(D) real acosl(real x)     { return acos(cast(double) x); }

    ///
    double  asin(double x);
    ///
    float   asinf(float x);
    ///
    extern(D) real asinl(real x)     { return asin(cast(double) x); }

    ///
    double  atan(double x);
    ///
    float   atanf(float x);
    ///
    extern(D) real atanl(real x)     { return atan(cast(double) x); }

    ///
    double  atan2(double y, double x);
    ///
    float   atan2f(float y, float x);
    ///
    extern(D) real atan2l(real y, real x) { return atan2(cast(double) y, cast(double) x); }

    ///
    double  cos(double x);
    ///
    float   cosf(float x);
    ///
    extern(D) real cosl(real x)      { return cos(cast(double) x); }

    ///
    double  sin(double x);
    ///
    float   sinf(float x);
    ///
    extern(D) real sinl(real x)      { return sin(cast(double) x); }

    ///
    double  tan(double x);
    ///
    float   tanf(float x);
    ///
    extern(D) real tanl(real x)      { return tan(cast(double) x); }

    ///
    double  acosh(double x);
    ///
    float   acoshf(float x);
    ///
    extern(D) real acoshl(real x)    { return acosh(cast(double) x); }

    ///
    double  asinh(double x);
    ///
    float   asinhf(float x);
    ///
    extern(D) real asinhl(real x)    { return asinh(cast(double) x); }

    ///
    double  atanh(double x);
    ///
    float   atanhf(float x);
    ///
    extern(D) real atanhl(real x)    { return atanh(cast(double) x); }

    ///
    double  cosh(double x);
    ///
    float   coshf(float x);
    ///
    extern(D) real coshl(real x)     { return cosh(cast(double) x); }

    ///
    double  sinh(double x);
    ///
    float   sinhf(float x);
    ///
    extern(D) real sinhl(real x)     { return sinh(cast(double) x); }

    ///
    double  tanh(double x);
    ///
    float   tanhf(float x);
    ///
    extern(D) real tanhl(real x)     { return tanh(cast(double) x); }

    ///
    double  exp(double x);
    ///
    float   expf(float x);
    ///
    extern(D) real expl(real x)      { return exp(cast(double) x); }

    ///
    double  exp2(double x);
    ///
    float   exp2f(float x);
    ///
    extern(D) real exp2l(real x)     { return exp2(cast(double) x); }

    ///
    double  expm1(double x);
    ///
    float   expm1f(float x);
    ///
    extern(D) real expm1l(real x)    { return expm1(cast(double) x); }

    ///
    double  frexp(double value, int* exp);
    ///
    extern(D) float frexpf(float value, int* exp) { return cast(float) frexp(value, exp); }
    ///
    extern(D) real  frexpl(real value, int* exp)  { return frexp(cast(double) value, exp); }

    ///
    int     ilogb(double x);
    ///
    int     ilogbf(float x);
    ///
    extern(D) int ilogbl(real x)     { return ilogb(cast(double) x); }

    ///
    double  ldexp(double x, int exp);
    ///
    extern(D) float ldexpf(float x, int exp) { return cast(float) ldexp(x, exp); }
    ///
    extern(D) real  ldexpl(real x, int exp)  { return ldexp(cast(double) x, exp); }

    ///
    double  log(double x);
    ///
    float   logf(float x);
    ///
    extern(D) real logl(real x)      { return log(cast(double) x); }

    ///
    double  log10(double x);
    ///
    float   log10f(float x);
    ///
    extern(D) real log10l(real x)    { return log10(cast(double) x); }

    ///
    double  log1p(double x);
    ///
    float   log1pf(float x);
    ///
    extern(D) real log1pl(real x)    { return log1p(cast(double) x); }

    ///
    double  log2(double x);
    ///
    float   log2f(float x);
    ///
    extern(D) real log2l(real x)     { return log2(cast(double) x); }

    ///
    double  logb(double x);
    ///
    float   logbf(float x);
    ///
    extern(D) real logbl(real x)     { return logb(cast(double) x); }

    ///
    double  modf(double value, double* iptr);
    ///
    float   modff(float value, float* iptr);
    ///
    extern(D) real modfl(real value, real* iptr)
    {
        double i;
        double r = modf(cast(double) value, &i);
        *iptr = i;
        return r;
    }

    ///
    double  scalbn(double x, int n);
    ///
    float   scalbnf(float x, int n);
    ///
    extern(D) real scalbnl(real x, int n) { return scalbn(cast(double) x, n); }

    ///
    double  scalbln(double x, c_long n);
    ///
    float   scalblnf(float x, c_long n);
    ///
    extern(D) real scalblnl(real x, c_long n) { return scalbln(cast(double) x, n); }

    ///
    double  cbrt(double x);
    ///
    float   cbrtf(float x);
    ///
    extern(D) real cbrtl(real x)     { return cbrt(cast(double) x); }

    ///
    double  fabs(double x);
    ///
    extern(D) float fabsf(float x)   { return cast(float) fabs(x); }
    ///
    extern(D) real  fabsl(real x)    { return fabs(cast(double) x); }

    private double _hypot(double x, double y);
    private float  _hypotf(float x, float y);
    ///
    extern(D) double hypot(double x, double y) { return _hypot(x, y); }
    ///
    extern(D) float  hypotf(float x, float y)  { return _hypotf(x, y); }
    ///
    extern(D) real   hypotl(real x, real y)    { return _hypot(cast(double) x, cast(double) y); }

    ///
    double  pow(double x, double y);
    ///
    float   powf(float x, float y);
    ///
    extern(D) real powl(real x, real y) { return pow(cast(double) x, cast(double) y); }

    ///
    double  sqrt(double x);
    ///
    float   sqrtf(float x);
    ///
    extern(D) real sqrtl(real x)     { return sqrt(cast(double) x); }

    ///
    double  erf(double x);
    ///
    float   erff(float x);
    ///
    extern(D) real erfl(real x)      { return erf(cast(double) x); }

    ///
    double  erfc(double x);
    ///
    float   erfcf(float x);
    ///
    extern(D) real erfcl(real x)     { return erfc(cast(double) x); }

    ///
    double  lgamma(double x);
    ///
    float   lgammaf(float x);
    ///
    extern(D) real lgammal(real x)   { return lgamma(cast(double) x); }

    ///
    double  tgamma(double x);
    ///
    float   tgammaf(float x);
    ///
    extern(D) real tgammal(real x)   { return tgamma(cast(double) x); }

    ///
    double  ceil(double x);
    ///
    float   ceilf(float x);
    ///
    extern(D) real ceill(real x)     { return ceil(cast(double) x); }

    ///
    double  floor(double x);
    ///
    float   floorf(float x);
    ///
    extern(D) real floorl(real x)    { return floor(cast(double) x); }

    ///
    double  nearbyint(double x);
    ///
    float   nearbyintf(float x);
    ///
    extern(D) real nearbyintl(real x) { return nearbyint(cast(double) x); }

    ///
    double  rint(double x);
    ///
    float   rintf(float x);
    ///
    extern(D) real rintl(real x)     { return rint(cast(double) x); }

    ///
    c_long  lrint(double x);
    ///
    c_long  lrintf(float x);
    ///
    extern(D) c_long lrintl(real x)  { return lrint(cast(double) x); }

    ///
    long    llrint(double x);
    ///
    long    llrintf(float x);
    ///
    extern(D) long llrintl(real x)   { return llrint(cast(double) x); }

    ///
    double  round(double x);
    ///
    float   roundf(float x);
    ///
    extern(D) real roundl(real x)    { return round(cast(double) x); }

    ///
    c_long  lround(double x);
    ///
    c_long  lroundf(float x);
    ///
    extern(D) c_long lroundl(real x) { return lround(cast(double) x); }

    ///
    long    llround(double x);
    ///
    long    llroundf(float x);
    ///
    extern(D) long llroundl(real x)  { return llround(cast(double) x); }

    ///
    double  trunc(double x);
    ///
    float   truncf(float x);
    ///
    extern(D) real truncl(real x)    { return trunc(cast(double) x); }

    ///
    double  fmod(double x, double y);
    ///
    float   fmodf(float x, float y);
    ///
    extern(D) real fmodl(real x, real y) { return fmod(cast(double) x, cast(double) y); }

    ///
    double  remainder(double x, double y);
    ///
    float   remainderf(float x, float y);
    ///
    extern(D) real remainderl(real x, real y) { return remainder(cast(double) x, cast(double) y); }

    ///
    double  remquo(double x, double y, int* quo);
    ///
    float   remquof(float x, float y, int* quo);
    ///
    extern(D) real remquol(real x, real y, int* quo) { return remquo(cast(double) x, cast(double) y, quo); }

    ///
    double  copysign(double x, double y);
    ///
    float   copysignf(float x, float y);
    ///
    extern(D) real copysignl(real x, real y) { return copysign(cast(double) x, cast(double) y); }

    ///
    double  nan(char* tagp);
    ///
    float   nanf(char* tagp);
    ///
    extern(D) real nanl(char* tagp)  { return nan(tagp); }

    ///
    double  nextafter(double x, double y);
    ///
    float   nextafterf(float x, float y);
    ///
    extern(D) real nextafterl(real x, real y) { return nextafter(cast(double) x, cast(double) y); }

    ///
    double  nexttoward(double x, real y);
    ///
    float   nexttowardf(float x, real y);
    ///
    extern(D) real nexttowardl(real x, real y) { return nexttoward(cast(double) x, cast(double) y); }

    ///
    double  fdim(double x, double y);
    ///
    float   fdimf(float x, float y);
    ///
    extern(D) real fdiml(real x, real y) { return fdim(cast(double) x, cast(double) y); }

    ///
    double  fmax(double x, double y);
    ///
    float   fmaxf(float x, float y);
    ///
    extern(D) real fmaxl(real x, real y) { return fmax(cast(double) x, cast(double) y); }

    ///
    double  fmin(double x, double y);
    ///
    float   fminf(float x, float y);
    ///
    extern(D) real fminl(real x, real y) { return fmin(cast(double) x, cast(double) y); }

    ///
    double  fma(double x, double y, double z);
    ///
    float   fmaf(float x, float y, float z);
    ///
    extern(D) real fmal(real x, real y, real z) { return fma(cast(double) x, cast(double) y, cast(double) z); }
}
/* NOTE: freebsd < 8-CURRENT doesn't appear to support *l, but we can
 *       approximate.
 * A lot of them were added in 8.0-RELEASE, and so a lot of these workarounds
 * should then be removed.
 */
// NOTE: FreeBSD 8.0-RELEASE doesn't support log2* nor these *l functions:
//         acoshl, asinhl, atanhl, coshl, sinhl, tanhl, cbrtl, powl, expl,
//         expm1l, logl, log1pl, log10l, erfcl, erfl, lgammal, tgammal;
//       but we can approximate.
else version( FreeBSD )
{
  version (none) // < 8-CURRENT
  {
    real    acosl(real x) { return acos(x); }
    real    asinl(real x) { return asin(x); }
    real    atanl(real x) { return atan(x); }
    real    atan2l(real y, real x) { return atan2(y, x); }
    real    cosl(real x) { return cos(x); }
    real    sinl(real x) { return sin(x); }
    real    tanl(real x) { return tan(x); }
    real    exp2l(real x) { return exp2(x); }
    real    frexpl(real value, int* exp) { return frexp(value, exp); }
    int     ilogbl(real x) { return ilogb(x); }
    real    ldexpl(real x, int exp) { return ldexp(x, exp); }
    real    logbl(real x) { return logb(x); }
    //real    modfl(real value, real *iptr); // nontrivial conversion
    real    scalbnl(real x, int n) { return scalbn(x, n); }
    real    scalblnl(real x, c_long n) { return scalbln(x, n); }
    real    fabsl(real x) { return fabs(x); }
    real    hypotl(real x, real y) { return hypot(x, y); }
    real    sqrtl(real x) { return sqrt(x); }
    real    ceill(real x) { return ceil(x); }
    real    floorl(real x) { return floor(x); }
    real    nearbyintl(real x) { return nearbyint(x); }
    real    rintl(real x) { return rint(x); }
    c_long  lrintl(real x) { return lrint(x); }
    real    roundl(real x) { return round(x); }
    c_long  lroundl(real x) { return lround(x); }
    long    llroundl(real x) { return llround(x); }
    real    truncl(real x) { return trunc(x); }
    real    fmodl(real x, real y) { return fmod(x, y); }
    real    remainderl(real x, real y) { return remainder(x, y); }
    real    remquol(real x, real y, int* quo) { return remquo(x, y, quo); }
    real    copysignl(real x, real y) { return copysign(x, y); }
//  double  nan(char* tagp);
//  float   nanf(char* tagp);
//  real    nanl(char* tagp);
    real    nextafterl(real x, real y) { return nextafter(x, y); }
    real    nexttowardl(real x, real y) { return nexttoward(x, y); }
    real    fdiml(real x, real y) { return fdim(x, y); }
    real    fmaxl(real x, real y) { return fmax(x, y); }
    real    fminl(real x, real y) { return fmin(x, y); }
    real    fmal(real x, real y, real z) { return fma(x, y, z); }
  }
  else
  {
      ///
    real    acosl(real x);
    ///
    real    asinl(real x);
    ///
    real    atanl(real x);
    ///
    real    atan2l(real y, real x);
    ///
    real    cosl(real x);
    ///
    real    sinl(real x);
    ///
    real    tanl(real x);
    ///
    real    exp2l(real x);
    ///
    real    frexpl(real value, int* exp);
    ///
    int     ilogbl(real x);
    ///
    real    ldexpl(real x, int exp);
    ///
    real    logbl(real x);
    ///
    real    modfl(real value, real *iptr);
    ///
    real    scalbnl(real x, int n);
    ///
    real    scalblnl(real x, c_long n);
    ///
    real    fabsl(real x);
    ///
    real    hypotl(real x, real y);
    ///
    real    sqrtl(real x);
    ///
    real    ceill(real x);
    ///
    real    floorl(real x);
    ///
    real    nearbyintl(real x);
    ///
    real    rintl(real x);
    ///
    c_long  lrintl(real x);
    ///
    real    roundl(real x);
    ///
    c_long  lroundl(real x);
    ///
    long    llroundl(real x);
    ///
    real    truncl(real x);
    ///
    real    fmodl(real x, real y);
    ///
    real    remainderl(real x, real y);
    ///
    real    remquol(real x, real y, int* quo);
    ///
    real    copysignl(real x, real y);
    ///
    double  nan(char* tagp);
    ///
    float   nanf(char* tagp);
    ///
    real    nanl(char* tagp);
    ///
    real    nextafterl(real x, real y);
    ///
    real    nexttowardl(real x, real y);
    ///
    real    fdiml(real x, real y);
    ///
    real    fmaxl(real x, real y);
    ///
    real    fminl(real x, real y);
    ///
    real    fmal(real x, real y, real z);
  }
  ///
    double  acos(double x);
    ///
    float   acosf(float x);

    ///
    double  asin(double x);
    ///
    float   asinf(float x);

    ///
    double  atan(double x);
    ///
    float   atanf(float x);

    ///
    double  atan2(double y, double x);
    ///
    float   atan2f(float y, float x);

    ///
    double  cos(double x);
    ///
    float   cosf(float x);

    ///
    double  sin(double x);
    ///
    float   sinf(float x);

    ///
    double  tan(double x);
    ///
    float   tanf(float x);

    ///
    double  acosh(double x);
    ///
    float   acoshf(float x);
    ///
    real    acoshl(real x) { return acosh(x); }

    ///
    double  asinh(double x);
    ///
    float   asinhf(float x);
    ///
    real    asinhl(real x) { return asinh(x); }

    ///
    double  atanh(double x);
    ///
    float   atanhf(float x);
    ///
    real    atanhl(real x) { return atanh(x); }

    ///
    double  cosh(double x);
    ///
    float   coshf(float x);
    ///
    real    coshl(real x) { return cosh(x); }

    ///
    double  sinh(double x);
    ///
    float   sinhf(float x);
    ///
    real    sinhl(real x) { return sinh(x); }

    ///
    double  tanh(double x);
    ///
    float   tanhf(float x);
    ///
    real    tanhl(real x) { return tanh(x); }

    ///
    double  exp(double x);
    ///
    float   expf(float x);
    ///
    real    expl(real x) { return exp(x); }

    ///
    double  exp2(double x);
    ///
    float   exp2f(float x);

    ///
    double  expm1(double x);
    ///
    float   expm1f(float x);
    ///
    real    expm1l(real x) { return expm1(x); }

    ///
    double  frexp(double value, int* exp);
    ///
    float   frexpf(float value, int* exp);

    ///
    int     ilogb(double x);
    ///
    int     ilogbf(float x);

    ///
    double  ldexp(double x, int exp);
    ///
    float   ldexpf(float x, int exp);

    ///
    double  log(double x);
    ///
    float   logf(float x);
    ///
    real    logl(real x) { return log(x); }

    ///
    double  log10(double x);
    ///
    float   log10f(float x);
    ///
    real    log10l(real x) { return log10(x); }

    ///
    double  log1p(double x);
    ///
    float   log1pf(float x);
    ///
    real    log1pl(real x) { return log1p(x); }

    private enum real ONE_LN2 = 1 / 0x1.62e42fefa39ef358p-1L;
    ///
    double  log2(double x) { return log(x) * ONE_LN2; }
    ///
    float   log2f(float x) { return logf(x) * ONE_LN2; }
    ///
    real    log2l(real x)  { return logl(x) * ONE_LN2; }

    ///
    double  logb(double x);
    ///
    float   logbf(float x);

    ///
    double  modf(double value, double* iptr);
    ///
    float   modff(float value, float* iptr);

    ///
    double  scalbn(double x, int n);
    ///
    float   scalbnf(float x, int n);

    ///
    double  scalbln(double x, c_long n);
    ///
    float   scalblnf(float x, c_long n);

    ///
    double  cbrt(double x);
    ///
    float   cbrtf(float x);
    ///
    real    cbrtl(real x) { return cbrt(x); }

    ///
    double  fabs(double x);
    ///
    float   fabsf(float x);

    ///
    double  hypot(double x, double y);
    ///
    float   hypotf(float x, float y);

    ///
    double  pow(double x, double y);
    ///
    float   powf(float x, float y);
    ///
    real    powl(real x, real y) { return pow(x, y); }

    ///
    double  sqrt(double x);
    ///
    float   sqrtf(float x);

    ///
    double  erf(double x);
    ///
    float   erff(float x);
    ///
    real    erfl(real x) { return erf(x); }

    ///
    double  erfc(double x);
    ///
    float   erfcf(float x);
    ///
    real    erfcl(real x) { return erfc(x); }

    ///
    double  lgamma(double x);
    ///
    float   lgammaf(float x);
    ///
    real    lgammal(real x) { return lgamma(x); }

    ///
    double  tgamma(double x);
    ///
    float   tgammaf(float x);
    ///
    real    tgammal(real x) { return tgamma(x); }

    ///
    double  ceil(double x);
    ///
    float   ceilf(float x);

    ///
    double  floor(double x);
    ///
    float   floorf(float x);

    ///
    double  nearbyint(double x);
    ///
    float   nearbyintf(float x);

    ///
    double  rint(double x);
    ///
    float   rintf(float x);

    ///
    c_long  lrint(double x);
    ///
    c_long  lrintf(float x);

    ///
    long    llrint(double x);
    ///
    long    llrintf(float x);
    ///
    long    llrintl(real x) { return llrint(x); }

    ///
    double  round(double x);
    ///
    float   roundf(float x);

    ///
    c_long  lround(double x);
    ///
    c_long  lroundf(float x);

    ///
    long    llround(double x);
    ///
    long    llroundf(float x);

    ///
    double  trunc(double x);
    ///
    float   truncf(float x);

    ///
    double  fmod(double x, double y);
    ///
    float   fmodf(float x, float y);

    ///
    double  remainder(double x, double y);
    ///
    float   remainderf(float x, float y);

    ///
    double  remquo(double x, double y, int* quo);
    ///
    float   remquof(float x, float y, int* quo);

    ///
    double  copysign(double x, double y);
    ///
    float   copysignf(float x, float y);

    ///
    double  nextafter(double x, double y);
    ///
    float   nextafterf(float x, float y);

    ///
    double  nexttoward(double x, real y);
    ///
    float   nexttowardf(float x, real y);

    ///
    double  fdim(double x, double y);
    ///
    float   fdimf(float x, float y);

    ///
    double  fmax(double x, double y);
    ///
    float   fmaxf(float x, float y);

    ///
    double  fmin(double x, double y);
    ///
    float   fminf(float x, float y);

    ///
    double  fma(double x, double y, double z);
    ///
    float   fmaf(float x, float y, float z);
}
else version(Android)
{
    // Android defines long double as 64 bits, same as double, so several long
    // double functions are missing.  nexttoward was modified to reflect this.
    ///
    double  acos(double x);
    ///
    float   acosf(float x);
    //real    acosl(real x);

    ///
    double  asin(double x);
    ///
    float   asinf(float x);
    //real    asinl(real x);

    ///
    double  atan(double x);
    ///
    float   atanf(float x);
    //real    atanl(real x);

    ///
    double  atan2(double y, double x);
    ///
    float   atan2f(float y, float x);
    //real    atan2l(real y, real x);

    ///
    double  cos(double x);
    ///
    float   cosf(float x);
    //real    cosl(real x);

    ///
    double  sin(double x);
    ///
    float   sinf(float x);
    //real    sinl(real x);

    ///
    double  tan(double x);
    ///
    float   tanf(float x);
    //real    tanl(real x);

    ///
    double  acosh(double x);
    ///
    float   acoshf(float x);
    //real    acoshl(real x);

    ///
    double  asinh(double x);
    ///
    float   asinhf(float x);
    //real    asinhl(real x);

    ///
    double  atanh(double x);
    ///
    float   atanhf(float x);
    //real    atanhl(real x);

    ///
    double  cosh(double x);
    ///
    float   coshf(float x);
    //real    coshl(real x);

    ///
    double  sinh(double x);
    ///
    float   sinhf(float x);
    //real    sinhl(real x);

    ///
    double  tanh(double x);
    ///
    float   tanhf(float x);
    //real    tanhl(real x);

    ///
    double  exp(double x);
    ///
    float   expf(float x);
    //real    expl(real x);

    ///
    double  exp2(double x);
    ///
    float   exp2f(float x);
    ///
    real    exp2l(real x) { return exp2(x); }

    ///
    double  expm1(double x);
    ///
    float   expm1f(float x);
    //real    expm1l(real x);

    ///
    double  frexp(double value, int* exp);
    ///
    float   frexpf(float value, int* exp);
    // alias for double: real    frexpl(real value, int* exp);

    ///
    int     ilogb(double x);
    ///
    int     ilogbf(float x);
    ///
    int     ilogbl(real x) { return ilogb(x); }

    ///
    double  ldexp(double x, int exp);
    ///
    float   ldexpf(float x, int exp);
    // alias for double: real    ldexpl(real x, int exp);

    ///
    double  log(double x);
    ///
    float   logf(float x);
    //real    logl(real x);

    ///
    double  log10(double x);
    ///
    float   log10f(float x);
    //real    log10l(real x);

    ///
    double  log1p(double x);
    ///
    float   log1pf(float x);
    //real    log1pl(real x);

    //double  log2(double x);
    //float   log2f(float x);
    //real    log2l(real x);

    ///
    double  logb(double x);
    ///
    float   logbf(float x);
    ///
    real    logbl(real x) { return logb(x); }

    ///
    double  modf(double value, double* iptr);
    ///
    float   modff(float value, float* iptr);
    ///
    real    modfl(real value, real *iptr) { return modf(value, cast(double*)iptr); }

    ///
    double  scalbn(double x, int n);
    ///
    float   scalbnf(float x, int n);
    // alias for double: real    scalbnl(real x, int n);

    ///
    double  scalbln(double x, c_long n);
    ///
    float   scalblnf(float x, c_long n);
    // alias for double: real    scalblnl(real x, c_long n);

    ///
    double  cbrt(double x);
    ///
    float   cbrtf(float x);
    ///
    real    cbrtl(real x) { return cbrt(x); }

    ///
    double  fabs(double x);
    ///
    float   fabsf(float x);
    // alias for double: real    fabsl(real x);

    ///
    double  hypot(double x, double y);
    ///
    float   hypotf(float x, float y);
    //real    hypotl(real x, real y);

    ///
    double  pow(double x, double y);
    ///
    float   powf(float x, float y);
    //real    powl(real x, real y);

    ///
    double  sqrt(double x);
    ///
    float   sqrtf(float x);
    //real    sqrtl(real x);

    ///
    double  erf(double x);
    ///
    float   erff(float x);
    //real    erfl(real x);

    ///
    double  erfc(double x);
    ///
    float   erfcf(float x);
    //real    erfcl(real x);

    ///
    double  lgamma(double x);
    ///
    float   lgammaf(float x);
    //real    lgammal(real x);

    ///
    double  tgamma(double x);
    //float   tgammaf(float x);
    //real    tgammal(real x);

    ///
    double  ceil(double x);
    ///
    float   ceilf(float x);
    // alias for double: real    ceill(real x);

    ///
    double  floor(double x);
    ///
    float   floorf(float x);
    // alias for double: real    floorl(real x);

    ///
    double  nearbyint(double x);
    ///
    float   nearbyintf(float x);
    ///
    real    nearbyintl(real x) { return nearbyint(x); }

    ///
    double  rint(double x);
    ///
    float   rintf(float x);
    //real    rintl(real x);

    ///
    c_long  lrint(double x);
    ///
    c_long  lrintf(float x);
    //c_long  lrintl(real x);

    ///
    long    llrint(double x);
    ///
    long    llrintf(float x);
    //long    llrintl(real x);

    ///
    double  round(double x);
    ///
    float   roundf(float x);
    ///
    real    roundl(real x) { return round(x); }

    ///
    c_long  lround(double x);
    ///
    c_long  lroundf(float x);
    // alias for double: c_long  lroundl(real x);

    ///
    long    llround(double x);
    ///
    long    llroundf(float x);
    ///
    long    llroundl(real x) { return llround(x); }

    ///
    double  trunc(double x);
    ///
    float   truncf(float x);
    ///
    real    truncl(real x) { return trunc(x); }

    ///
    double  fmod(double x, double y);
    ///
    float   fmodf(float x, float y);
    ///
    real    fmodl(real x, real y) { return fmod(x,y); }

    ///
    double  remainder(double x, double y);
    ///
    float   remainderf(float x, float y);
    ///
    real    remainderl(real x, real y) { return remainder(x,y); }

    ///
    double  remquo(double x, double y, int* quo);
    ///
    float   remquof(float x, float y, int* quo);
    ///
    real    remquol(real x, real y, int* quo) { return remquo(x,y,quo); }

    ///
    double  copysign(double x, double y);
    ///
    float   copysignf(float x, float y);
    // alias for double: real    copysignl(real x, real y);

    //double  nan(char* tagp);
    //float   nanf(char* tagp);
    //real    nanl(char* tagp);

    ///
    double  nextafter(double x, double y);
    ///
    float   nextafterf(float x, float y);
    // alias for double: real    nextafterl(real x, real y);

    ///
    double  nexttoward(double x, double y);
    ///
    float   nexttowardf(float x, double y);
    // alias for double: real    nexttowardl(real x, real y);

    ///
    double  fdim(double x, double y);
    ///
    float   fdimf(float x, float y);
    // alias for double: real    fdiml(real x, real y);

    ///
    double  fmax(double x, double y);
    ///
    float   fmaxf(float x, float y);
    // alias for double: real    fmaxl(real x, real y);

    ///
    double  fmin(double x, double y);
    ///
    float   fminf(float x, float y);
    // alias for double: real    fminl(real x, real y);

    ///
    double  fma(double x, double y, double z);
    ///
    float   fmaf(float x, float y, float z);
    // alias for double: real    fmal(real x, real y, real z);
}
else
{
    ///
    double  acos(double x);
    ///
    float   acosf(float x);
    ///
    real    acosl(real x);

    ///
    double  asin(double x);
    ///
    float   asinf(float x);
    ///
    real    asinl(real x);

    ///
    double  atan(double x);
    ///
    float   atanf(float x);
    ///
    real    atanl(real x);

    ///
    double  atan2(double y, double x);
    ///
    float   atan2f(float y, float x);
    ///
    real    atan2l(real y, real x);

    ///
    double  cos(double x);
    ///
    float   cosf(float x);
    ///
    real    cosl(real x);

    ///
    double  sin(double x);
    ///
    float   sinf(float x);
    ///
    real    sinl(real x);

    ///
    double  tan(double x);
    ///
    float   tanf(float x);
    ///
    real    tanl(real x);

    ///
    double  acosh(double x);
    ///
    float   acoshf(float x);
    ///
    real    acoshl(real x);

    ///
    double  asinh(double x);
    ///
    float   asinhf(float x);
    ///
    real    asinhl(real x);

    ///
    double  atanh(double x);
    ///
    float   atanhf(float x);
    ///
    real    atanhl(real x);

    ///
    double  cosh(double x);
    ///
    float   coshf(float x);
    ///
    real    coshl(real x);

    ///
    double  sinh(double x);
    ///
    float   sinhf(float x);
    ///
    real    sinhl(real x);

    ///
    double  tanh(double x);
    ///
    float   tanhf(float x);
    ///
    real    tanhl(real x);

    ///
    double  exp(double x);
    ///
    float   expf(float x);
    ///
    real    expl(real x);

    ///
    double  exp2(double x);
    ///
    float   exp2f(float x);
    ///
    real    exp2l(real x);

    ///
    double  expm1(double x);
    ///
    float   expm1f(float x);
    ///
    real    expm1l(real x);

    ///
    double  frexp(double value, int* exp);
    ///
    float   frexpf(float value, int* exp);
    ///
    real    frexpl(real value, int* exp);

    ///
    int     ilogb(double x);
    ///
    int     ilogbf(float x);
    ///
    int     ilogbl(real x);

    ///
    double  ldexp(double x, int exp);
    ///
    float   ldexpf(float x, int exp);
    ///
    real    ldexpl(real x, int exp);

    ///
    double  log(double x);
    ///
    float   logf(float x);
    ///
    real    logl(real x);

    ///
    double  log10(double x);
    ///
    float   log10f(float x);
    ///
    real    log10l(real x);

    ///
    double  log1p(double x);
    ///
    float   log1pf(float x);
    ///
    real    log1pl(real x);

    ///
    double  log2(double x);
    ///
    float   log2f(float x);
    ///
    real    log2l(real x);

    ///
    double  logb(double x);
    ///
    float   logbf(float x);
    ///
    real    logbl(real x);

    ///
    double  modf(double value, double* iptr);
    ///
    float   modff(float value, float* iptr);
    ///
    real    modfl(real value, real *iptr);

    ///
    double  scalbn(double x, int n);
    ///
    float   scalbnf(float x, int n);
    ///
    real    scalbnl(real x, int n);

    ///
    double  scalbln(double x, c_long n);
    ///
    float   scalblnf(float x, c_long n);
    ///
    real    scalblnl(real x, c_long n);

    ///
    double  cbrt(double x);
    ///
    float   cbrtf(float x);
    ///
    real    cbrtl(real x);

    ///
    double  fabs(double x);
    version( CRuntime_Microsoft )
    {
    }
    else
    {
        ///
        float   fabsf(float x);
        ///
        real    fabsl(real x);        
    }

    ///
    double  hypot(double x, double y);
    ///
    float   hypotf(float x, float y);
    ///
    real    hypotl(real x, real y);

    ///
    double  pow(double x, double y);
    ///
    float   powf(float x, float y);
    ///
    real    powl(real x, real y);

    ///
    double  sqrt(double x);
    ///
    float   sqrtf(float x);
    ///
    real    sqrtl(real x);

    ///
    double  erf(double x);
    ///
    float   erff(float x);
    ///
    real    erfl(real x);

    ///
    double  erfc(double x);
    ///
    float   erfcf(float x);
    ///
    real    erfcl(real x);

    ///
    double  lgamma(double x);
    ///
    float   lgammaf(float x);
    ///
    real    lgammal(real x);

    ///
    double  tgamma(double x);
    ///
    float   tgammaf(float x);
    ///
    real    tgammal(real x);

    ///
    double  ceil(double x);
    ///
    float   ceilf(float x);
    ///
    real    ceill(real x);

    ///
    double  floor(double x);
    ///
    float   floorf(float x);
    ///
    real    floorl(real x);

    ///
    double  nearbyint(double x);
    ///
    float   nearbyintf(float x);
    ///
    real    nearbyintl(real x);

    ///
    double  rint(double x);
    ///
    float   rintf(float x);
    ///
    real    rintl(real x);

    ///
    c_long  lrint(double x);
    ///
    c_long  lrintf(float x);
    ///
    c_long  lrintl(real x);

    ///
    long    llrint(double x);
    ///
    long    llrintf(float x);
    ///
    long    llrintl(real x);

    ///
    double  round(double x);
    ///
    float   roundf(float x);
    ///
    real    roundl(real x);

    ///
    c_long  lround(double x);
    ///
    c_long  lroundf(float x);
    ///
    c_long  lroundl(real x);

    ///
    long    llround(double x);
    ///
    long    llroundf(float x);
    ///
    long    llroundl(real x);

    ///
    double  trunc(double x);
    ///
    float   truncf(float x);
    ///
    real    truncl(real x);

    ///
    double  fmod(double x, double y);
    ///
    float   fmodf(float x, float y);
    ///
    real    fmodl(real x, real y);

    ///
    double  remainder(double x, double y);
    ///
    float   remainderf(float x, float y);
    ///
    real    remainderl(real x, real y);

    ///
    double  remquo(double x, double y, int* quo);
    ///
    float   remquof(float x, float y, int* quo);
    ///
    real    remquol(real x, real y, int* quo);

    ///
    double  copysign(double x, double y);
    ///
    float   copysignf(float x, float y);
    ///
    real    copysignl(real x, real y);

    ///
    double  nan(char* tagp);
    ///
    float   nanf(char* tagp);
    ///
    real    nanl(char* tagp);

    ///
    double  nextafter(double x, double y);
    ///
    float   nextafterf(float x, float y);
    ///
    real    nextafterl(real x, real y);

    ///
    double  nexttoward(double x, real y);
    ///
    float   nexttowardf(float x, real y);
    ///
    real    nexttowardl(real x, real y);

    ///
    double  fdim(double x, double y);
    ///
    float   fdimf(float x, float y);
    ///
    real    fdiml(real x, real y);

    ///
    double  fmax(double x, double y);
    ///
    float   fmaxf(float x, float y);
    ///
    real    fmaxl(real x, real y);

    ///
    double  fmin(double x, double y);
    ///
    float   fminf(float x, float y);
    ///
    real    fminl(real x, real y);

    ///
    double  fma(double x, double y, double z);
    ///
    float   fmaf(float x, float y, float z);
    ///
    real    fmal(real x, real y, real z);
}
