/* Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved, written by Rainer Schuetze
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * (See accompanying file LICENSE or copy at http://www.boost.org/LICENSE_1_0.txt)
 * https://github.com/D-Programming-Language/dmd/blob/master/src/root/longdouble.h
 */

// 80 bit floating point value implementation for Microsoft compiler

#ifndef __LONG_DOUBLE_H__
#define __LONG_DOUBLE_H__

#if !_MSC_VER // has native 10 byte doubles
#include <stdio.h>
typedef long double longdouble;
typedef volatile long double volatile_longdouble;

// also used from within C code, so use a #define rather than a template
// template<typename T> longdouble ldouble(T x) { return (longdouble) x; }
#define ldouble(x) ((longdouble)(x))

#if __MINGW32__
// MinGW supports 80 bit reals, but the formatting functions map to versions
// from the MSVC runtime by default which don't.
#define sprintf __mingw_sprintf
#endif

inline size_t ld_sprint(char* str, int fmt, longdouble x)
{
    if (((longdouble)(unsigned long long)x) == x)
    {   // ((1.5 -> 1 -> 1.0) == 1.5) is false
        // ((1.0 -> 1 -> 1.0) == 1.0) is true
        // see http://en.cppreference.com/w/cpp/io/c/fprintf
        char sfmt[5] = "%#Lg";
        sfmt[3] = fmt;
        return sprintf(str, sfmt, x);
    }
    else
    {
        char sfmt[4] = "%Lg";
        sfmt[2] = fmt;
        return sprintf(str, sfmt, x);
    }
}

#if __MINGW32__
#undef sprintf
#endif

#else

#include <float.h>
#include <limits>

struct longdouble;

extern "C"
{
    // implemented in ldfpu.asm for _WIN64
    double ld_read(const longdouble* ld);
    long long ld_readll(const longdouble* ld);
    unsigned long long ld_readull(const longdouble* ld);
    void ld_set(longdouble* ld, double d);
    void ld_setll(longdouble* ld, long long d);
    void ld_setull(longdouble* ld, unsigned long long d);
}

#pragma pack(push, 1)
struct longdouble
{
    unsigned long long mantissa;
    unsigned short exponent:15;  // bias 0x3fff
    unsigned short sign:1;

    // no constructor to be able to use this class in a union
    // use ldouble() to explicitely create a longdouble value

    template<typename T> longdouble& operator=(T x) { set(x); return *this; }

    void set(longdouble ld) { mantissa = ld.mantissa; exponent = ld.exponent; sign = ld.sign; }

    // we need to list all basic types to avoid ambiguities
    void set(float              d) { ld_set(this, d); }
    void set(double             d) { ld_set(this, d); }
    void set(long double        d) { ld_set(this, d); }

    void set(signed char        d) { ld_set(this, d); }
    void set(short              d) { ld_set(this, d); }
    void set(int                d) { ld_set(this, d); }
    void set(long               d) { ld_set(this, d); }
    void set(long long          d) { ld_setll(this, d); }

    void set(unsigned char      d) { ld_set(this, d); }
    void set(unsigned short     d) { ld_set(this, d); }
    void set(unsigned int       d) { ld_set(this, d); }
    void set(unsigned long      d) { ld_set(this, d); }
    void set(unsigned long long d) { ld_setull(this, d); }
    void set(bool               d) { ld_set(this, d); }

    operator float             () { return ld_read(this); }
    operator double            () { return ld_read(this); }

    operator signed char       () { return ld_read(this); }
    operator short             () { return ld_read(this); }
    operator int               () { return ld_read(this); }
    operator long              () { return ld_read(this); }
    operator long long         () { return ld_readll(this); }

    operator unsigned char     () { return ld_read(this); }
    operator unsigned short    () { return ld_read(this); }
    operator unsigned int      () { return ld_read(this); }
    operator unsigned long     () { return ld_read(this); }
    operator unsigned long long() { return ld_readull(this); }
    operator bool              () { return mantissa != 0 || exponent != 0; } // correct?
};

#pragma pack(pop)
// static_assert(sizeof(longdouble) == 10, "bad sizeof longdouble");

// some optimizations are avoided by adding volatile to the longdouble
// type, but this introduces bad ambiguities when using the class implementation above
// as we are going through asm these optimizations won't kick in anyway, so "volatile"
// is not required.
typedef longdouble volatile_longdouble;

inline longdouble ldouble(unsigned long long mantissa, int exp, int sign = 0)
{
    longdouble d;
    d.mantissa = mantissa;
    d.exponent = exp;
    d.sign = sign;
    return d;
}

// codegen bug in VS2010/VS2012, if the set() function not inlined
//  (this passed on stack, but expected in ECX; RVO?)
#if _MSC_VER >= 1600
#define LDOUBLE_INLINE __declspec(noinline)
#else
#define LDOUBLE_INLINE inline
#endif

template<typename T> LDOUBLE_INLINE longdouble ldouble(T x) { longdouble d; d.set(x); return d; }

#undef LDOUBLE_INLINE

longdouble operator+(longdouble ld1, longdouble ld2);
longdouble operator-(longdouble ld1, longdouble ld2);
longdouble operator*(longdouble ld1, longdouble ld2);
longdouble operator/(longdouble ld1, longdouble ld2);

bool operator< (longdouble ld1, longdouble ld2);
bool operator<=(longdouble ld1, longdouble ld2);
bool operator> (longdouble ld1, longdouble ld2);
bool operator>=(longdouble ld1, longdouble ld2);
bool operator==(longdouble ld1, longdouble ld2);
bool operator!=(longdouble ld1, longdouble ld2);

inline longdouble operator-(longdouble ld1) { ld1.sign ^= 1; return ld1; }
inline longdouble operator+(longdouble ld1) { return ld1; }

template<typename T> inline longdouble operator+(longdouble ld, T x) { return ld + ldouble(x); }
template<typename T> inline longdouble operator-(longdouble ld, T x) { return ld - ldouble(x); }
template<typename T> inline longdouble operator*(longdouble ld, T x) { return ld * ldouble(x); }
template<typename T> inline longdouble operator/(longdouble ld, T x) { return ld / ldouble(x); }

template<typename T> inline longdouble operator+(T x, longdouble ld) { return ldouble(x) + ld; }
template<typename T> inline longdouble operator-(T x, longdouble ld) { return ldouble(x) - ld; }
template<typename T> inline longdouble operator*(T x, longdouble ld) { return ldouble(x) * ld; }
template<typename T> inline longdouble operator/(T x, longdouble ld) { return ldouble(x) / ld; }

template<typename T> inline longdouble& operator+=(longdouble& ld, T x) { return ld = ld + x; }
template<typename T> inline longdouble& operator-=(longdouble& ld, T x) { return ld = ld - x; }
template<typename T> inline longdouble& operator*=(longdouble& ld, T x) { return ld = ld * x; }
template<typename T> inline longdouble& operator/=(longdouble& ld, T x) { return ld = ld / x; }

template<typename T> inline bool operator< (longdouble ld, T x) { return ld <  ldouble(x); }
template<typename T> inline bool operator<=(longdouble ld, T x) { return ld <= ldouble(x); }
template<typename T> inline bool operator> (longdouble ld, T x) { return ld >  ldouble(x); }
template<typename T> inline bool operator>=(longdouble ld, T x) { return ld >= ldouble(x); }
template<typename T> inline bool operator==(longdouble ld, T x) { return ld == ldouble(x); }
template<typename T> inline bool operator!=(longdouble ld, T x) { return ld != ldouble(x); }

template<typename T> inline bool operator< (T x, longdouble ld) { return ldouble(x) <  ld; }
template<typename T> inline bool operator<=(T x, longdouble ld) { return ldouble(x) <= ld; }
template<typename T> inline bool operator> (T x, longdouble ld) { return ldouble(x) >  ld; }
template<typename T> inline bool operator>=(T x, longdouble ld) { return ldouble(x) >= ld; }
template<typename T> inline bool operator==(T x, longdouble ld) { return ldouble(x) == ld; }
template<typename T> inline bool operator!=(T x, longdouble ld) { return ldouble(x) != ld; }

int _isnan(longdouble ld);

longdouble fabsl(longdouble ld);
longdouble sqrtl(longdouble ld);
longdouble sinl (longdouble ld);
longdouble cosl (longdouble ld);
longdouble tanl (longdouble ld);

longdouble fmodl(longdouble x, longdouble y);
longdouble ldexpl(longdouble ldval, int exp); // see strtold

inline longdouble fabs (longdouble ld) { return fabsl(ld); }
inline longdouble sqrt (longdouble ld) { return sqrtl(ld); }

#undef LDBL_DIG
#undef LDBL_MAX
#undef LDBL_MIN
#undef LDBL_EPSILON
#undef LDBL_MANT_DIG
#undef LDBL_MAX_EXP
#undef LDBL_MIN_EXP
#undef LDBL_MAX_10_EXP
#undef LDBL_MIN_10_EXP

#define LDBL_DIG        18
#define LDBL_MAX        ldouble(0xffffffffffffffffULL, 0x7ffe)
#define LDBL_MIN        ldouble(0x8000000000000000ULL, 1)
#define LDBL_EPSILON    ldouble(0x8000000000000000ULL, 0x3fff - 63) // allow denormal?
#define LDBL_MANT_DIG   64
#define LDBL_MAX_EXP    16384
#define LDBL_MIN_EXP    (-16381)
#define LDBL_MAX_10_EXP 4932
#define LDBL_MIN_10_EXP (-4932)

extern longdouble ld_zero;
extern longdouble ld_one;
extern longdouble ld_pi;
extern longdouble ld_log2t;
extern longdouble ld_log2e;
extern longdouble ld_log2;
extern longdouble ld_ln2;

extern longdouble ld_inf;
extern longdouble ld_qnan;
extern longdouble ld_snan;

size_t ld_sprint(char* str, int fmt, longdouble x);

#endif // !_MSC_VER

#endif // __LONG_DOUBLE_H__
