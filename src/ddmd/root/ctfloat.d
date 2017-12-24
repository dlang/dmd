/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/ddmd/root/ctfloat.d, root/_ctfloat.d)
 */

module ddmd.root.ctfloat;

// Online documentation: https://dlang.org/phobos/ddmd_root_ctfloat.html

static import core.math, core.stdc.math;
import core.stdc.errno;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

// Type used by the front-end for compile-time reals
version(IN_LLVM_MSVC)
    alias real_t = double;
else
    alias real_t = real;

version(IN_LLVM)
    private enum LDC_host_has_yl2x = is(real_t == real) && __traits(compiles, core.math.yl2x(1.0L, 2.0L));
else
    private enum LDC_host_has_yl2x = false;

private
{
    version(CRuntime_DigitalMars) __gshared extern (C) extern const(char)* __locale_decpoint;

    // IN_LLVM replaced: version(CRuntime_Microsoft) extern (C++)
    version(none) extern (C++)
    {
        struct longdouble { real_t r; }
        size_t ld_sprint(char* str, int fmt, longdouble x);
        longdouble strtold_dm(const(char)* p, char** endp);
    }
}

// Compile-time floating-point helper
extern (C++) struct CTFloat
{
    // IN_LLVM replaced: version(DigitalMars)
    static if (LDC_host_has_yl2x)
    {
        static __gshared bool yl2x_supported = true;
        static __gshared bool yl2xp1_supported = true;
    }
    else
    {
        static __gshared bool yl2x_supported = false;
        static __gshared bool yl2xp1_supported = false;
    }

    static void yl2x(const real_t* x, const real_t* y, real_t* res)
    {
        // IN_LLVM replaced: version(DigitalMars)
        static if (LDC_host_has_yl2x)
            *res = core.math.yl2x(*x, *y);
        else
            assert(0);
    }

    static void yl2xp1(const real_t* x, const real_t* y, real_t* res)
    {
        // IN_LLVM replaced: version(DigitalMars)
        static if (LDC_host_has_yl2x)
            *res = core.math.yl2xp1(*x, *y);
        else
            assert(0);
    }

    static real_t sin(real_t x) { return core.math.sin(x); }
    static real_t cos(real_t x) { return core.math.cos(x); }
    static real_t tan(real_t x) { return core.stdc.math.tanl(x); }
    static real_t sqrt(real_t x) { return core.math.sqrt(x); }
    static real_t fabs(real_t x) { return core.math.fabs(x); }
    static real_t ldexp(real_t n, int exp) { return core.math.ldexp(n, exp); }

  version(IN_LLVM)
  {
    static import std.math;

    static real_t log(real_t x) { return std.math.log(x); }
    static real_t log2(real_t x) { return std.math.log2(x); }
    static real_t log10(real_t x) { return std.math.log10(x); }
    static real_t fmin(real_t l, real_t r) { return std.math.fmin(l, r); }
    static real_t fmax(real_t l, real_t r) { return std.math.fmax(l, r); }
    static real_t floor(real_t x) { return std.math.floor(x); }
    static real_t ceil(real_t x) { return std.math.ceil(x); }
    static real_t trunc(real_t x) { return std.math.trunc(x); }
    static real_t rint(real_t x) { return std.math.rint(x); }
    static real_t nearbyint(real_t x) { return std.math.nearbyint(x); }
    static real_t round(real_t x) { return std.math.round(x); }
    static real_t fma(real_t x, real_t y, real_t z) { return std.math.fma(x, y, z); }
    static real_t copysign(real_t to, real_t from) { return std.math.copysign(to, from); }

    static void _init();

    static bool isFloat32LiteralOutOfRange(const(char)* literal);
    static bool isFloat64LiteralOutOfRange(const(char)* literal);
  }

    static bool isIdentical(real_t a, real_t b)
    {
        // don't compare pad bytes in extended precision
        enum sz = (real_t.mant_dig == 64) ? 10 : real_t.sizeof;
        return memcmp(&a, &b, sz) == 0;
    }

    static size_t hash(real_t a)
    {
        import ddmd.root.hash : calcHash;

        if (isNaN(a))
            a = real_t.nan;
        enum sz = (real_t.mant_dig == 64) ? 10 : real_t.sizeof;
        return calcHash(cast(ubyte*) &a, sz);
    }

    static bool isNaN(real_t r)
    {
        return !(r == r);
    }

  version(IN_LLVM)
  {
    // LDC doesn't need isSNaN(). The upstream implementation is tailored for
    // DMD/x86 and only supports double-precision and x87 real_t types.
  }
  else
  {
    static bool isSNaN(real_t r)
    {
        static if (real_t.sizeof == 8)
            return isNaN(r) && !(((cast(ubyte*)&r)[6]) & 8);
        else
            return isNaN(r) && !(((cast(ubyte*)&r)[7]) & 0x40);
    }

    // the implementation of longdouble for MSVC is a struct, so mangling
    //  doesn't match with the C++ header.
    // add a wrapper just for isSNaN as this is the only function called from C++
    version(CRuntime_Microsoft)
        static bool isSNaN(longdouble ld)
        {
            return isSNaN(ld.r);
        }
  }

    static bool isInfinity(real_t r)
    {
        return isIdentical(fabs(r), real_t.infinity);
    }

version (IN_LLVM)
{
    // implemented in gen/ctfloat.cpp
    static real_t parse(const(char)* literal, bool* isOutOfRange = null);
}
else
{
    static real_t parse(const(char)* literal, bool* isOutOfRange = null)
    {
        errno = 0;
        version(CRuntime_DigitalMars)
        {
            auto save = __locale_decpoint;
            __locale_decpoint = ".";
        }
        // IN_LLVM replaced: version(CRuntime_Microsoft)
        version(none)
            auto r = strtold_dm(literal, null).r;
        else
            auto r = strtold(literal, null);
        version(CRuntime_DigitalMars) __locale_decpoint = save;
        if (isOutOfRange)
            *isOutOfRange = (errno == ERANGE);
        return r;
    }
}

    static int sprint(char* str, char fmt, real_t x)
    {
        // IN_LLVM replaced: version(CRuntime_Microsoft)
        version(none)
        {
            return cast(int)ld_sprint(str, fmt, longdouble(x));
        }
        else
        {
            if (real_t(cast(ulong)x) == x)
            {
                // ((1.5 -> 1 -> 1.0) == 1.5) is false
                // ((1.0 -> 1 -> 1.0) == 1.0) is true
                // see http://en.cppreference.com/w/cpp/io/c/fprintf
                char[5] sfmt = "%#Lg\0";
                sfmt[3] = fmt;
                return sprintf(str, sfmt.ptr, x);
            }
            else
            {
                char[4] sfmt = "%Lg\0";
                sfmt[2] = fmt;
                return sprintf(str, sfmt.ptr, x);
            }
        }
    }

    // Constant real values 0, 1, -1 and 0.5.
    static __gshared real_t zero = real_t(0);
    static __gshared real_t one = real_t(1);
    static __gshared real_t minusone = real_t(-1);
    static __gshared real_t half = real_t(0.5);
  version(IN_LLVM)
  {
    // Initialized via LLVM in C++.
    static __gshared real_t initVal;
    static __gshared real_t nan;
    static __gshared real_t infinity;
  }
}

version (IN_LLVM)
{
    shared static this()
    {
        CTFloat._init();
    }
}
