
#ifndef __LONG_DOUBLE_H__
#define __LONG_DOUBLE_H__

#if !_MSC_VER // has native 10 byte doubles
typedef long double long_double;

template<typename T> long_double to_real(T x) { return (long_double) x; }

#define ld_volatile volatile
#else

#include <float.h>
#include <limits>

#define ld_volatile /* going through asm, so no volatile required */

struct ld_data
{
    unsigned long long mantissa;
    unsigned short exponent:15;  // bias 0x3fff
    unsigned short sign:1;
    unsigned short fill:16;

    double __thiscall read();
    void __thiscall set(double d);
    void __thiscall setll(long long d);
    void __thiscall setull(unsigned long long d);
};

struct long_double
{
    ld_data tdbl;

    //long_double() {}
    //long_double(const long_double& ld) { dbl = ld.dbl; }
    //explicit long_double(double d) { dbl = d; }
    //long_double& operator=(long_double ld) { dbl = ld.dbl; return *this; }

    void set(long_double ld) { tdbl = ld.tdbl; }
    template<typename T> void assign(T x) { tdbl.set(x); }

    template<typename T> long_double& operator=(T x) { set(x); return *this; }
    //template<typename T> void operator=(T x) { /*assign(x); return *this;*/ }

    double read() { return tdbl.read(); }

    // we need to list all basic types to avoid ambiguities
    void set(float              d) { tdbl.set(d); }
    void set(double             d) { tdbl.set(d); }
    void set(long double        d) { tdbl.set(d); }

    void set(signed char        d) { tdbl.set(d); }
    void set(short              d) { tdbl.set(d); }
    void set(int                d) { tdbl.set(d); }
    void set(long               d) { tdbl.set(d); }
    void set(long long          d) { tdbl.setll(d); }

    void set(unsigned char      d) { tdbl.set(d); }
    void set(unsigned short     d) { tdbl.set(d); }
    void set(unsigned int       d) { tdbl.set(d); }
    void set(unsigned long      d) { tdbl.set(d); }
    void set(unsigned long long d) { tdbl.setull(d); }
    void set(bool               d) { tdbl.set(d); }
    
    operator float             () { return tdbl.read(); }
    operator double            () { return tdbl.read(); }

    operator signed char       () { return tdbl.read(); }
    operator short             () { return tdbl.read(); }
    operator int               () { return tdbl.read(); }
    operator long              () { return tdbl.read(); }
    operator long long         () { return tdbl.read(); }

    operator unsigned char     () { return tdbl.read(); }
    operator unsigned short    () { return tdbl.read(); }
    operator unsigned int      () { return tdbl.read(); }
    operator unsigned long     () { return tdbl.read(); }
    operator unsigned long long() { return tdbl.read(); }
    operator bool              () { return tdbl.mantissa != 0; }
};

inline long_double ldouble(unsigned long long mantissa, int exp, int sign = 0)
{
    long_double d; 
    d.tdbl.mantissa = mantissa;
    d.tdbl.exponent = exp;
    d.tdbl.sign = sign;
    return d;
}
template<typename T> inline long_double ldouble(T x) { long_double d; d.set(x); return d; }
//template<typename T> inline long_double ldouble(volatile T x) { long_double d; d.set(x); return d; }

template<typename T> inline long_double to_real(T x) { return ldouble(x); }


long_double operator+(long_double ld1, long_double ld2);
long_double operator-(long_double ld1, long_double ld2);
long_double operator*(long_double ld1, long_double ld2);
long_double operator/(long_double ld1, long_double ld2);

bool operator< (long_double ld1, long_double ld2);
bool operator<=(long_double ld1, long_double ld2);
bool operator> (long_double ld1, long_double ld2);
bool operator>=(long_double ld1, long_double ld2);
bool operator==(long_double ld1, long_double ld2);
bool operator!=(long_double ld1, long_double ld2);

inline long_double operator-(long_double ld1) { ld1.tdbl.sign ^= 1; return ld1; }
inline long_double operator+(long_double ld1) { return ld1; }

#if 1
template<typename T> inline long_double operator+(long_double ld, T x) { return ld + ldouble(x); }
template<typename T> inline long_double operator-(long_double ld, T x) { return ld - ldouble(x); }
template<typename T> inline long_double operator*(long_double ld, T x) { return ld * ldouble(x); }
template<typename T> inline long_double operator/(long_double ld, T x) { return ld / ldouble(x); }

template<typename T> inline long_double operator+(T x, long_double ld) { return ldouble(x) + ld; }
template<typename T> inline long_double operator-(T x, long_double ld) { return ldouble(x) - ld; }
template<typename T> inline long_double operator*(T x, long_double ld) { return ldouble(x) * ld; }
template<typename T> inline long_double operator/(T x, long_double ld) { return ldouble(x) / ld; }

template<typename T> inline long_double& operator+=(long_double& ld, T x) { return ld = ld + x; }
template<typename T> inline long_double& operator-=(long_double& ld, T x) { return ld = ld - x; }
template<typename T> inline long_double& operator*=(long_double& ld, T x) { return ld = ld * x; }
template<typename T> inline long_double& operator/=(long_double& ld, T x) { return ld = ld / x; }

template<typename T> inline bool operator< (long_double ld, T x) { return ld <  ldouble(x); }
template<typename T> inline bool operator<=(long_double ld, T x) { return ld <= ldouble(x); }
template<typename T> inline bool operator> (long_double ld, T x) { return ld >  ldouble(x); }
template<typename T> inline bool operator>=(long_double ld, T x) { return ld >= ldouble(x); }
template<typename T> inline bool operator==(long_double ld, T x) { return ld == ldouble(x); }
template<typename T> inline bool operator!=(long_double ld, T x) { return ld != ldouble(x); }

//inline bool operator==(volatile long_double& ld, double x) { return ld.read() == x; }
//inline bool operator!=(volatile long_double& ld, long long x) { return ld.read() != x; }
//inline bool operator!=(volatile long_double& ld, unsigned long long x) { return ld.read() != x; }

template<typename T> inline bool operator< (T x, long_double ld) { return ldouble(x) <  ld; }
template<typename T> inline bool operator<=(T x, long_double ld) { return ldouble(x) <= ld; }
template<typename T> inline bool operator> (T x, long_double ld) { return ldouble(x) >  ld; }
template<typename T> inline bool operator>=(T x, long_double ld) { return ldouble(x) >= ld; }
template<typename T> inline bool operator==(T x, long_double ld) { return ldouble(x) == ld; }
template<typename T> inline bool operator!=(T x, long_double ld) { return ldouble(x) != ld; }
#endif

int _isnan(long_double ld);

long_double fabsl(long_double ld);
long_double sqrtl(long_double ld);
long_double sinl (long_double ld);
long_double cosl (long_double ld);
long_double tanl (long_double ld);

long_double fmodl(long_double x, long_double y);
long_double ldexpl(long_double ldval, int exp); // see strtold

inline long_double fabs (long_double ld) { return fabsl(ld); }
inline long_double sqrt (long_double ld) { return sqrtl(ld); }

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

extern long_double ld_zero;
extern long_double ld_one;
extern long_double ld_pi;
extern long_double ld_log2t;
extern long_double ld_log2e;
extern long_double ld_log2;
extern long_double ld_ln2;

///////////////////////////////////////////////////////////////////////
		// CLASS numeric_limits<long double>
template<> class _CRTIMP2_PURE std::numeric_limits<long_double>
	: public _Num_float_base
	{	// limits for type long double
public:
	typedef long_double _Ty;

	static _Ty (__CRTDECL min)() _THROW0()
		{	// return minimum value
		return LDBL_MIN;
		}

	static _Ty (__CRTDECL max)() _THROW0()
		{	// return maximum value
		return LDBL_MAX;
		}

	static _Ty __CRTDECL epsilon() _THROW0()
		{	// return smallest effective increment from 1.0
		return LDBL_EPSILON;
		}

	static _Ty __CRTDECL round_error() _THROW0()
		{	// return largest rounding error
		return ldouble(0.5);
		}

	static _Ty __CRTDECL denorm_min() _THROW0()
		{	// return minimum denormalized value
		return ldouble(0x0000000000000001ULL, 1);
		}

	static _Ty __CRTDECL infinity() _THROW0()
		{	// return positive infinity
		return ldouble(::_LInf._Long_double);
		}

	static _Ty __CRTDECL quiet_NaN() _THROW0()
		{	// return non-signaling NaN
		return ldouble(::_LNan._Long_double);
		}

	static _Ty __CRTDECL signaling_NaN() _THROW0()
		{	// return signaling NaN
		return ldouble(::_LSnan._Long_double);
		}

	_STCONS(int, digits, LDBL_MANT_DIG);
	_STCONS(int, digits10, LDBL_DIG);
	_STCONS(int, max_exponent, (int)LDBL_MAX_EXP);
	_STCONS(int, max_exponent10, (int)LDBL_MAX_10_EXP);
	_STCONS(int, min_exponent, (int)LDBL_MIN_EXP);
	_STCONS(int, min_exponent10, (int)LDBL_MIN_10_EXP);
	};

_STCONSDEF(numeric_limits<long_double>, int, digits)
_STCONSDEF(numeric_limits<long_double>, int, digits10)
_STCONSDEF(numeric_limits<long_double>, int, max_exponent)
_STCONSDEF(numeric_limits<long_double>, int, max_exponent10)
_STCONSDEF(numeric_limits<long_double>, int, min_exponent)
_STCONSDEF(numeric_limits<long_double>, int, min_exponent10)

#endif // !_MSC_VER

#endif // __LONG_DOUBLE_H__
