
/* Copyright (C) 1999-2022 by The D Language Foundation, All Rights Reserved
 * written by Rainer Schuetze
 * https://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * https://www.boost.org/LICENSE_1_0.txt
 * https://github.com/dlang/dmd/blob/master/src/dmd/root/longdouble.h
 */

// 80 bit floating point value implementation for Microsoft compiler

#pragma once

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
        // see https://en.cppreference.com/w/cpp/io/c/fprintf
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

struct longdouble_soft;

// implemented in longdouble.d
double ld_read(const longdouble_soft* const ld);
long long ld_readll(const longdouble_soft* const ld);
unsigned long long ld_readull(const longdouble_soft* const ld);
void ld_set(longdouble_soft* ld, double d);
void ld_setll(longdouble_soft* ld, long long d);
void ld_setull(longdouble_soft* ld, unsigned long long d);
int ld_statusfpu();
void ld_clearfpu();
int ld_initfpu(int bits, int mask);

void ld_expl(longdouble_soft* ld, int exp);
bool ld_cmpb(longdouble_soft ld1, longdouble_soft ld2);
bool ld_cmpbe(longdouble_soft ld1, longdouble_soft ld2);
bool ld_cmpa(longdouble_soft ld1, longdouble_soft ld2);
bool ld_cmpae(longdouble_soft ld1, longdouble_soft ld2);
bool ld_cmpe(longdouble_soft ld1, longdouble_soft ld2);
bool ld_cmpne(longdouble_soft ld1, longdouble_soft ld2);
int ld_cmp(longdouble_soft x, longdouble_soft y);

longdouble_soft ld_add(longdouble_soft ld1, longdouble_soft ld2);
longdouble_soft ld_sub(longdouble_soft ld1, longdouble_soft ld2);
longdouble_soft ld_mul(longdouble_soft ld1, longdouble_soft ld2);
longdouble_soft ld_div(longdouble_soft ld1, longdouble_soft ld2);
longdouble_soft ld_mod(longdouble_soft ld1, longdouble_soft ld2);
longdouble_soft ld_sqrt(longdouble_soft ld1);
longdouble_soft ld_sin(longdouble_soft ld1);
longdouble_soft ld_cos(longdouble_soft ld1);
longdouble_soft ld_tan(longdouble_soft ld1);

#pragma pack(push, 1)
struct longdouble_soft
{
    unsigned long long mantissa;
    unsigned short exponent:15;  // bias 0x3fff
    unsigned short sign:1;

    // no constructor to be able to use this class in a union
    // use ldouble() to explicitly create a longdouble_soft value

    template<typename T> longdouble_soft& operator=(T x) { set(x); return *this; }

    void set(longdouble_soft ld) { mantissa = ld.mantissa; exponent = ld.exponent; sign = ld.sign; }

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

    operator float             () const { return ld_read(this); }
    operator double            () const { return ld_read(this); }

    operator signed char       () const { return ld_read(this); }
    operator short             () const { return ld_read(this); }
    operator int               () const { return ld_read(this); }
    operator long              () const { return ld_read(this); }
    operator long long         () const { return ld_readll(this); }

    operator unsigned char     () const { return ld_read(this); }
    operator unsigned short    () const { return ld_read(this); }
    operator unsigned int      () const { return ld_read(this); }
    operator unsigned long     () const { return ld_read(this); }
    operator unsigned long long() const { return ld_readull(this); }
    operator bool              () const { return mantissa != 0 || exponent != 0; } // correct?
};

#pragma pack(pop)
// static_assert(sizeof(longdouble_soft) == 10, "bad sizeof longdouble_soft");

inline longdouble_soft ldouble(unsigned long long mantissa, int exp, int sign = 0)
{
    longdouble_soft d;
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

template<typename T> LDOUBLE_INLINE longdouble_soft ldouble(T x) { longdouble_soft d; d.set(x); return d; }

#undef LDOUBLE_INLINE

inline longdouble_soft operator+(longdouble_soft ld1, longdouble_soft ld2) { return ld_add(ld1, ld2); }
inline longdouble_soft operator-(longdouble_soft ld1, longdouble_soft ld2) { return ld_sub(ld1, ld2); }
inline longdouble_soft operator*(longdouble_soft ld1, longdouble_soft ld2) { return ld_mul(ld1, ld2); }
inline longdouble_soft operator/(longdouble_soft ld1, longdouble_soft ld2) { return ld_div(ld1, ld2); }

inline bool operator< (longdouble_soft ld1, longdouble_soft ld2) { return ld_cmpb(ld1, ld2); }
inline bool operator<=(longdouble_soft ld1, longdouble_soft ld2) { return ld_cmpbe(ld1, ld2); }
inline bool operator> (longdouble_soft ld1, longdouble_soft ld2) { return ld_cmpa(ld1, ld2); }
inline bool operator>=(longdouble_soft ld1, longdouble_soft ld2) { return ld_cmpae(ld1, ld2); }
inline bool operator==(longdouble_soft ld1, longdouble_soft ld2) { return ld_cmpe(ld1, ld2); }
inline bool operator!=(longdouble_soft ld1, longdouble_soft ld2) { return ld_cmpne(ld1, ld2); }

inline longdouble_soft operator-(longdouble_soft ld1) { ld1.sign ^= 1; return ld1; }
inline longdouble_soft operator+(longdouble_soft ld1) { return ld1; }

template<typename T> inline longdouble_soft operator+(longdouble_soft ld, T x) { return ld + ldouble(x); }
template<typename T> inline longdouble_soft operator-(longdouble_soft ld, T x) { return ld - ldouble(x); }
template<typename T> inline longdouble_soft operator*(longdouble_soft ld, T x) { return ld * ldouble(x); }
template<typename T> inline longdouble_soft operator/(longdouble_soft ld, T x) { return ld / ldouble(x); }

template<typename T> inline longdouble_soft operator+(T x, longdouble_soft ld) { return ldouble(x) + ld; }
template<typename T> inline longdouble_soft operator-(T x, longdouble_soft ld) { return ldouble(x) - ld; }
template<typename T> inline longdouble_soft operator*(T x, longdouble_soft ld) { return ldouble(x) * ld; }
template<typename T> inline longdouble_soft operator/(T x, longdouble_soft ld) { return ldouble(x) / ld; }

template<typename T> inline longdouble_soft& operator+=(longdouble_soft& ld, T x) { return ld = ld + x; }
template<typename T> inline longdouble_soft& operator-=(longdouble_soft& ld, T x) { return ld = ld - x; }
template<typename T> inline longdouble_soft& operator*=(longdouble_soft& ld, T x) { return ld = ld * x; }
template<typename T> inline longdouble_soft& operator/=(longdouble_soft& ld, T x) { return ld = ld / x; }

template<typename T> inline bool operator< (longdouble_soft ld, T x) { return ld <  ldouble(x); }
template<typename T> inline bool operator<=(longdouble_soft ld, T x) { return ld <= ldouble(x); }
template<typename T> inline bool operator> (longdouble_soft ld, T x) { return ld >  ldouble(x); }
template<typename T> inline bool operator>=(longdouble_soft ld, T x) { return ld >= ldouble(x); }
template<typename T> inline bool operator==(longdouble_soft ld, T x) { return ld == ldouble(x); }
template<typename T> inline bool operator!=(longdouble_soft ld, T x) { return ld != ldouble(x); }

template<typename T> inline bool operator< (T x, longdouble_soft ld) { return ldouble(x) <  ld; }
template<typename T> inline bool operator<=(T x, longdouble_soft ld) { return ldouble(x) <= ld; }
template<typename T> inline bool operator> (T x, longdouble_soft ld) { return ldouble(x) >  ld; }
template<typename T> inline bool operator>=(T x, longdouble_soft ld) { return ldouble(x) >= ld; }
template<typename T> inline bool operator==(T x, longdouble_soft ld) { return ldouble(x) == ld; }
template<typename T> inline bool operator!=(T x, longdouble_soft ld) { return ldouble(x) != ld; }

int _isnan(longdouble_soft ld);

longdouble_soft fabsl(longdouble_soft ld);
longdouble_soft sqrtl(longdouble_soft ld);
longdouble_soft sinl (longdouble_soft ld);
longdouble_soft cosl (longdouble_soft ld);
longdouble_soft tanl (longdouble_soft ld);

longdouble_soft fmodl(longdouble_soft x, longdouble_soft y);
longdouble_soft ldexpl(longdouble_soft ldval, int exp); // see strtold

inline longdouble_soft fabs (longdouble_soft ld) { return fabsl(ld); }
inline longdouble_soft sqrt (longdouble_soft ld) { return sqrtl(ld); }

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

extern const longdouble_soft ld_qnan;
extern const longdouble_soft ld_inf;

extern const longdouble_soft ld_zero;
extern const longdouble_soft ld_one;
extern const longdouble_soft ld_pi;
extern const longdouble_soft ld_log2t;
extern const longdouble_soft ld_log2e;
extern const longdouble_soft ld_log2;
extern const longdouble_soft ld_ln2;

extern const longdouble_soft ld_pi2;
extern const longdouble_soft ld_piOver2;
extern const longdouble_soft ld_piOver4;

size_t ld_sprint(char* str, int fmt, longdouble_soft x);

//////////////////////////////////////////////
typedef longdouble_soft longdouble;

// some optimizations are avoided by adding volatile to the longdouble_soft
// type, but this introduces bad ambiguities when using the class implementation above
// as we are going through asm these optimizations won't kick in anyway, so "volatile"
// is not required.
typedef longdouble_soft volatile_longdouble;

#endif // !_MSC_VER
