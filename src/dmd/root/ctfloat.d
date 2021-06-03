/**
 * Collects functions for compile-time floating-point calculations.
 *
 * Copyright:   Copyright (C) 1999-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/root/ctfloat.d, root/_ctfloat.d)
 * Documentation: https://dlang.org/phobos/dmd_root_ctfloat.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/root/ctfloat.d
 */

module dmd.root.ctfloat;

static import core.math, core.stdc.math;
import core.stdc.errno;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

nothrow:

// Type used by the front-end for compile-time reals
public import dmd.root.longdouble : real_t = longdouble;

private
{
    version(CRuntime_DigitalMars) __gshared extern (C) extern const(char)* __locale_decpoint;

    version(CRuntime_Microsoft) extern (C++)
    {
        public import dmd.root.longdouble : longdouble_soft, ld_sprint;
        import dmd.root.strtold;
    }
}

// Compile-time floating-point helper
extern (C++) struct CTFloat
{
  nothrow:
  @nogc:
  @safe:

    version (GNU)
        enum yl2x_supported = false;
    else
        enum yl2x_supported = __traits(compiles, core.math.yl2x(1.0L, 2.0L));
    enum yl2xp1_supported = yl2x_supported;

    static void yl2x(const real_t* x, const real_t* y, real_t* res) pure
    {
        static if (yl2x_supported)
            *res = core.math.yl2x(*x, *y);
        else
            assert(0);
    }

    static void yl2xp1(const real_t* x, const real_t* y, real_t* res) pure
    {
        static if (yl2xp1_supported)
            *res = core.math.yl2xp1(*x, *y);
        else
            assert(0);
    }

    static if (!is(real_t == real))
    {
        static import dmd.root.longdouble;
        alias sin = dmd.root.longdouble.sinl;
        alias cos = dmd.root.longdouble.cosl;
        alias tan = dmd.root.longdouble.tanl;
        alias sqrt = dmd.root.longdouble.sqrtl;
        alias fabs = dmd.root.longdouble.fabsl;
        alias ldexp = dmd.root.longdouble.ldexpl;
    }
    else
    {
        pure static real_t sin(real_t x) { return core.math.sin(x); }
        pure static real_t cos(real_t x) { return core.math.cos(x); }
        static real_t tan(real_t x) { return core.stdc.math.tanl(x); }
        pure static real_t sqrt(real_t x) { return core.math.sqrt(x); }
        pure static real_t fabs(real_t x) { return core.math.fabs(x); }
        pure static real_t ldexp(real_t n, int exp) { return core.math.ldexp(n, exp); }
    }

    static if (!is(real_t == real))
    {
        static real_t round(real_t x) { return real_t(cast(double)core.stdc.math.roundl(cast(double)x)); }
        static real_t floor(real_t x) { return real_t(cast(double)core.stdc.math.floor(cast(double)x)); }
        static real_t ceil(real_t x) { return real_t(cast(double)core.stdc.math.ceil(cast(double)x)); }
        static real_t trunc(real_t x) { return real_t(cast(double)core.stdc.math.trunc(cast(double)x)); }
        static real_t log(real_t x) { return real_t(cast(double)core.stdc.math.logl(cast(double)x)); }
        static real_t log2(real_t x) { return real_t(cast(double)core.stdc.math.log2l(cast(double)x)); }
        static real_t log10(real_t x) { return real_t(cast(double)core.stdc.math.log10l(cast(double)x)); }
        static real_t pow(real_t x, real_t y) { return real_t(cast(double)core.stdc.math.powl(cast(double)x, cast(double)y)); }
        static real_t exp(real_t x) { return real_t(cast(double)core.stdc.math.expl(cast(double)x)); }
        static real_t expm1(real_t x) { return real_t(cast(double)core.stdc.math.expm1l(cast(double)x)); }
        static real_t exp2(real_t x) { return real_t(cast(double)core.stdc.math.exp2l(cast(double)x)); }
        static real_t copysign(real_t x, real_t s) { return real_t(cast(double)core.stdc.math.copysignl(cast(double)x, cast(double)s)); }
    }
    else
    {
        static real_t round(real_t x) { return core.stdc.math.roundl(x); }
        static real_t floor(real_t x) { return core.stdc.math.floor(x); }
        static real_t ceil(real_t x) { return core.stdc.math.ceil(x); }
        static real_t trunc(real_t x) { return core.stdc.math.trunc(x); }
        static real_t log(real_t x) { return core.stdc.math.logl(x); }
        static real_t log2(real_t x) { return core.stdc.math.log2l(x); }
        static real_t log10(real_t x) { return core.stdc.math.log10l(x); }
        static real_t pow(real_t x, real_t y) { return core.stdc.math.powl(x, y); }
        static real_t exp(real_t x) { return core.stdc.math.expl(x); }
        static real_t expm1(real_t x) { return core.stdc.math.expm1l(x); }
        static real_t exp2(real_t x) { return core.stdc.math.exp2l(x); }
        static real_t copysign(real_t x, real_t s) { return core.stdc.math.copysignl(x, s); }
    }

    pure
    static real_t fmin(real_t x, real_t y) { return x < y ? x : y; }
    pure
    static real_t fmax(real_t x, real_t y) { return x > y ? x : y; }

    pure
    static real_t fma(real_t x, real_t y, real_t z) { return (x * y) + z; }

    pure @trusted
    static bool isIdentical(real_t a, real_t b)
    {
        // don't compare pad bytes in extended precision
        enum sz = (real_t.mant_dig == 64) ? 10 : real_t.sizeof;
        return memcmp(&a, &b, sz) == 0;
    }

    pure @trusted
    static size_t hash(real_t a)
    {
        import dmd.root.hash : calcHash;

        if (isNaN(a))
            a = real_t.nan;
        enum sz = (real_t.mant_dig == 64) ? 10 : real_t.sizeof;
        return calcHash((cast(ubyte*) &a)[0 .. sz]);
    }

    pure
    static bool isNaN(real_t r)
    {
        return !(r == r);
    }

    pure @trusted
    static bool isSNaN(real_t r)
    {
        return isNaN(r) && !(((cast(ubyte*)&r)[7]) & 0x40);
    }

    // the implementation of longdouble for MSVC is a struct, so mangling
    //  doesn't match with the C++ header.
    // add a wrapper just for isSNaN as this is the only function called from C++
    version(CRuntime_Microsoft) static if (is(real_t == real))
        pure @trusted
        static bool isSNaN(longdouble_soft ld)
        {
            return isSNaN(cast(real)ld);
        }

    static bool isInfinity(real_t r) pure
    {
        return isIdentical(fabs(r), real_t.infinity);
    }

    @system
    static real_t parse(const(char)* literal, bool* isOutOfRange = null)
    {
        errno = 0;
        version(CRuntime_DigitalMars)
        {
            auto save = __locale_decpoint;
            __locale_decpoint = ".";
        }
        version(CRuntime_Microsoft)
        {
            auto r = cast(real_t) strtold_dm(literal, null);
        }
        else
            auto r = strtold(literal, null);
        version(CRuntime_DigitalMars) __locale_decpoint = save;
        if (isOutOfRange)
            *isOutOfRange = (errno == ERANGE);
        return r;
    }

    @system
    static int sprint(char* str, char fmt, real_t x)
    {
        version(CRuntime_Microsoft)
        {
            auto len = cast(int) ld_sprint(str, fmt, longdouble_soft(x));
        }
        else
        {
            char[4] sfmt = "%Lg\0";
            sfmt[2] = fmt;
            auto len = sprintf(str, sfmt.ptr, x);
        }

        if (fmt != 'a' && fmt != 'A')
        {
            assert(fmt == 'g');

            // 1 => 1.0 to distinguish from integers
            bool needsFPSuffix = true;
            foreach (char c; str[0 .. len])
            {
                // str might be `nan` or `inf`...
                if (c != '-' && !(c >= '0' && c <= '9'))
                {
                    needsFPSuffix = false;
                    break;
                }
            }

            if (needsFPSuffix)
            {
                str[len .. len+3] = ".0\0";
                len += 2;
            }
        }

        return len;
    }

    // Constant real values 0, 1, -1 and 0.5.
    __gshared real_t zero;
    __gshared real_t one;
    __gshared real_t minusone;
    __gshared real_t half;

    @trusted
    static void initialize()
    {
        zero = real_t(0);
        one = real_t(1);
        minusone = real_t(-1);
        half = real_t(0.5);
    }
}
