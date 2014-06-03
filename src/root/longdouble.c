
/* Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved, written by Rainer Schuetze
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * (See accompanying file LICENSE or copy at http://www.boost.org/LICENSE_1_0.txt)
 * https://github.com/D-Programming-Language/dmd/blob/master/src/root/longdouble.c
 */

// 80 bit floating point value implementation for Microsoft compiler

#if _MSC_VER
#include "longdouble.h"

#include "assert.h"

#include <float.h>
#include <stdio.h>
#include <string.h>

extern "C"
{
    // implemented in ldfpu.asm for _WIN64
    int ld_initfpu(int bits, int mask);
    void ld_expl(longdouble* ld, int exp);
    longdouble ld_add(longdouble ld1, longdouble ld2);
    longdouble ld_sub(longdouble ld1, longdouble ld2);
    longdouble ld_mul(longdouble ld1, longdouble ld2);
    longdouble ld_div(longdouble ld1, longdouble ld2);
    longdouble ld_mod(longdouble ld1, longdouble ld2);
    bool ld_cmpb(longdouble ld1, longdouble ld2);
    bool ld_cmpbe(longdouble ld1, longdouble ld2);
    bool ld_cmpa(longdouble ld1, longdouble ld2);
    bool ld_cmpae(longdouble ld1, longdouble ld2);
    bool ld_cmpe(longdouble ld1, longdouble ld2);
    bool ld_cmpne(longdouble ld1, longdouble ld2);
    longdouble ld_sqrt(longdouble ld1);
    longdouble ld_sin(longdouble ld1);
    longdouble ld_cos(longdouble ld1);
    longdouble ld_tan(longdouble ld1);
}

bool initFPU()
{
#ifdef _WIN64
//    int old_cw = ld_initfpu(_RC_NEAR);
    int old_cw = ld_initfpu(0x300 /*_PC_64  | _RC_NEAR*/, // #defines NOT identical to CPU FPU control word!
                            0xF00 /*_MCW_PC | _MCW_RC*/);
#else
    int old_cw = _control87(_MCW_EM | _PC_64  | _RC_NEAR,
                            _MCW_EM | _MCW_PC | _MCW_RC);
#endif
    _set_output_format(_TWO_DIGIT_EXPONENT);
    return true;
}
static bool doInitFPU = initFPU();

extern "C"
{

#ifndef _WIN64
double ld_read(const longdouble* pthis)
{
    double res;
    __asm
    {
        mov eax, pthis
        fld tbyte ptr [eax]
        fstp res
    }
    return res;
}
#endif // !_WIN64

long long ld_readll(const longdouble* pthis)
{
#if 1
    return ld_readull(pthis);
#elif defined _WIN64
    return ld_readll(this);
#else
    longdouble* pthis = this;
    long long res;
    __asm
    {
        mov eax, pthis
        fld tbyte ptr [eax]
        fistp qword ptr res
    }
    return res;
#endif
}

unsigned long long ld_readull(const longdouble* pthis)
{
#if 1
    // somehow the FPU does not respect the CHOP mode of the rounding control
    // in 64-bit mode
    // so we roll our own conversion (it also allows the usual C wrap-around
    // instead of the "invalid value" created by the FPU)
    int expo = pthis->exponent - 0x3fff;
    unsigned long long u;
    if(expo < 0 || expo > 127)
        return 0;
    if(expo < 64)
        u = pthis->mantissa >> (63 - expo);
    else
        u = pthis->mantissa << (expo - 63);
    if(pthis->sign)
        u = ~u + 1;
    return u;
#else
    longdouble* pthis = this;
    long long res; // cannot use unsigned, VC will not generate "fistp qword"
    longdouble twoPow63 = { 1ULL << 63, 0x3fff + 63, 0 };
    __asm
    {
        mov eax, pthis
        fld tbyte ptr [eax]
        fld tbyte ptr twoPow63
        fsubp ST(1),ST(0)  // move it into signed range

        lea eax, res
        fistp qword ptr [eax]
    }
    res ^= (1LL << 63);
    return res;
#endif
}

#ifndef _WIN64
void ld_set(longdouble* pthis, double d)
{
    __asm
    {
        mov eax, pthis
        fld d
        fstp tbyte ptr [eax]
    }
}
void ld_setll(longdouble* pthis, long long d)
{
    __asm
    {
        fild qword ptr d
        mov eax, pthis
        fstp tbyte ptr [eax]
    }
}
void ld_setull(longdouble* pthis, unsigned long long d)
{
    d ^= (1LL << 63);
    longdouble twoPow63 = { 1ULL << 63, 0x3fff + 63, 0 };
    __asm
    {
        fild qword ptr d
        fld tbyte ptr twoPow63
        faddp ST(1),ST(0)
        mov eax, pthis
        fstp tbyte ptr [eax]
    }
}
#endif // !_WIN64

} // extern "C"

longdouble ldexpl(longdouble ld, int exp)
{
#ifdef _WIN64
    ld_expl(&ld, exp);
#else
    __asm
    {
        fild    dword ptr exp
        fld     tbyte ptr ld
        fscale                  // ST(0) = ST(0) * (2**ST(1))
        fstp    ST(1)
        fstp    tbyte ptr ld
    }
#endif
    return ld;
}

///////////////////////////////////////////////////////////////////////
longdouble operator+(longdouble ld1, longdouble ld2)
{
#ifdef _WIN64
    return ld_add(ld1, ld2);
#else
    longdouble res;
    __asm
    {
        fld tbyte ptr ld1
        fld tbyte ptr ld2
        fadd
        fstp tbyte ptr res;
    }
    return res;
#endif
}

longdouble operator-(longdouble ld1, longdouble ld2)
{
#ifdef _WIN64
    return ld_sub(ld1, ld2);
#else
    longdouble res;
    __asm
    {
        fld tbyte ptr ld1
        fld tbyte ptr ld2
        fsub
        fstp tbyte ptr res;
    }
    return res;
#endif
}

longdouble operator*(longdouble ld1, longdouble ld2)
{
#ifdef _WIN64
    return ld_mul(ld1, ld2);
#else
    longdouble res;
    __asm
    {
        fld tbyte ptr ld1
        fld tbyte ptr ld2
        fmul
        fstp tbyte ptr res;
    }
    return res;
#endif
}

longdouble operator/(longdouble ld1, longdouble ld2)
{
#ifdef _WIN64
    return ld_div(ld1, ld2);
#else
    longdouble res;
    __asm
    {
        fld tbyte ptr ld1
        fld tbyte ptr ld2
        fdiv
        fstp tbyte ptr res;
    }
    return res;
#endif
}

bool operator< (longdouble x, longdouble y)
{
#ifdef _WIN64
    return ld_cmpb(x, y);
#else
    short sw;
    bool res;
    __asm
    {
        fld     tbyte ptr y
        fld     tbyte ptr x             // ST = x, ST1 = y
        fucomip ST(0),ST(1)
        setb    AL
        setnp   AH
        and     AL,AH
        mov     res,AL
        fstp    ST(0)
    }
    return res;
#endif
}
bool operator<=(longdouble x, longdouble y)
{
#ifdef _WIN64
    return ld_cmpbe(x, y);
#else
    short sw;
    bool res;
    __asm
    {
        fld     tbyte ptr y
        fld     tbyte ptr x             // ST = x, ST1 = y
        fucomip ST(0),ST(1)
        setbe   AL
        setnp   AH
        and     AL,AH
        mov     res,AL
        fstp    ST(0)
    }
    return res;
#endif
}
bool operator> (longdouble x, longdouble y)
{
#ifdef _WIN64
    return ld_cmpa(x, y);
#else
    short sw;
    bool res;
    __asm
    {
        fld     tbyte ptr y
        fld     tbyte ptr x             // ST = x, ST1 = y
        fucomip ST(0),ST(1)
        seta    AL
        setnp   AH
        and     AL,AH
        mov     res,AL
        fstp    ST(0)
    }
    return res;
#endif
}
bool operator>=(longdouble x, longdouble y)
{
#ifdef _WIN64
    return ld_cmpae(x, y);
#else
    short sw;
    bool res;
    __asm
    {
        fld     tbyte ptr y
        fld     tbyte ptr x             // ST = x, ST1 = y
        fucomip ST(0),ST(1)
        setae   AL
        setnp   AH
        and     AL,AH
        mov     res,AL
        fstp    ST(0)
    }
    return res;
#endif
}
bool operator==(longdouble x, longdouble y)
{
#ifdef _WIN64
    return ld_cmpe(x, y);
#else
    short sw;
    bool res;
    __asm
    {
        fld     tbyte ptr y
        fld     tbyte ptr x             // ST = x, ST1 = y
        fucomip ST(0),ST(1)
        sete    AL
        setnp   AH
        and     AL,AH
        mov     res,AL
        fstp    ST(0)
    }
    return res;
#endif
}
bool operator!=(longdouble x, longdouble y)
{
#ifdef _WIN64
    return ld_cmpne(x, y);
#else
    short sw;
    bool res;
    __asm
    {
        fld     tbyte ptr y
        fld     tbyte ptr x             // ST = x, ST1 = y
        fucomip ST(0),ST(1)
        setne   AL
        setp    AH
        or      AL,AH
        mov     res,AL
        fstp    ST(0)
    }
    return res;
#endif
}


int _isnan(longdouble ld)
{
    return (ld.exponent == 0x7fff && ld.mantissa != 0 && ld.mantissa != (1LL << 63)); // exclude pseudo-infinity and infinity, but not FP Indefinite
}

longdouble fabsl(longdouble ld)
{
    ld.sign = 0;
    return ld;
}

longdouble sqrtl(longdouble ld)
{
#ifdef _WIN64
    return ld_sqrt(ld);
#else
    longdouble res;
    __asm
    {
        fld tbyte ptr ld;
        fsqrt;
        fstp tbyte ptr res;
    }
    return res;
#endif
}

longdouble sinl (longdouble ld)
{
#ifdef _WIN64
    return ld_sin(ld);
#else
    longdouble res;
    __asm
    {
        fld tbyte ptr ld;
        fsin; // exact for |x|<=PI/4
        fstp tbyte ptr res
    }
    return res;
#endif
}
longdouble cosl (longdouble ld)
{
#ifdef _WIN64
    return ld_cos(ld);
#else
    longdouble res;
    __asm
    {
        fld tbyte ptr ld;
        fcos; // exact for |x|<=PI/4
        fstp tbyte ptr res;
    }
    return res;
#endif
}
longdouble tanl (longdouble ld)
{
#ifdef _WIN64
    return ld_tan(ld);
#else
    longdouble res;
    __asm
    {
        fld tbyte ptr ld;
        fptan;
        fstp ST(0); // always 1
        fstp tbyte ptr res;
    }
    return res;
#endif
}

longdouble fmodl(longdouble x, longdouble y)
{
#ifdef _WIN64
    return ld_mod(x, y);
#else
    short sw;
    longdouble res;
    __asm
    {
        fld     tbyte ptr y
        fld     tbyte ptr x             // ST = x, ST1 = y
FM1:    // We don't use fprem1 because for some inexplicable
        // reason we get -5 when we do _modulo(15, 10)
        fprem                           // ST = ST % ST1
        fstsw   word ptr sw
        fwait
        mov     AH,byte ptr sw+1        // get msb of status word in AH
        sahf                            // transfer to flags
        jp      FM1                     // continue till ST < ST1
        fstp    ST(1)                   // leave remainder on stack
        fstp    tbyte ptr res;
    }
    return res;
#endif
}

//////////////////////////////////////////////////////////////

longdouble ld_qnan = { 0xC000000000000000ULL, 0x7fff, 0 };
longdouble ld_snan = { 0xC000000000000001ULL, 0x7fff, 0 };
longdouble ld_inf  = { 0x8000000000000000ULL, 0x7fff, 0 };

longdouble ld_zero  = { 0, 0, 0 };
longdouble ld_one   = { 0x8000000000000000ULL, 0x3fff, 0 };
longdouble ld_pi    = { 0xc90fdaa22168c235ULL, 0x4000, 0 };
longdouble ld_log2t = { 0xd49a784bcd1b8afeULL, 0x4000, 0 };
longdouble ld_log2e = { 0xb8aa3b295c17f0bcULL, 0x3fff, 0 };
longdouble ld_log2  = { 0x9a209a84fbcff799ULL, 0x3ffd, 0 };
longdouble ld_ln2   = { 0xb17217f7d1cf79acULL, 0x3ffe, 0 };

longdouble ld_pi2     = ld_pi*2;
longdouble ld_piOver2 = ld_pi*0.5;
longdouble ld_piOver4 = ld_pi*0.25;

//////////////////////////////////////////////////////////////

#define LD_TYPE_OTHER    0
#define LD_TYPE_ZERO     1
#define LD_TYPE_INFINITE 2
#define LD_TYPE_SNAN     3
#define LD_TYPE_QNAN     4

int ld_type(longdouble x)
{
    if(x.exponent == 0)
        return x.mantissa == 0 ? LD_TYPE_ZERO : LD_TYPE_OTHER; // dnormal if not zero
    if(x.exponent != 0x7fff)
        return LD_TYPE_OTHER;
    if(x.mantissa == 0)
        return LD_TYPE_INFINITE;
    if(x.mantissa & (1LL << 63))
        return LD_TYPE_QNAN;
    return LD_TYPE_SNAN;
}

size_t ld_sprint(char* str, int fmt, longdouble x)
{
    // ensure dmc compatible strings for nan and inf
    switch(ld_type(x))
    {
    case LD_TYPE_QNAN:
    case LD_TYPE_SNAN:
        return sprintf(str, "nan");
    case LD_TYPE_INFINITE:
        return sprintf(str, x.sign ? "-inf" : "inf");
    }

    // fmt is 'a','A','f' or 'g'
    if(fmt != 'a' && fmt != 'A')
    {
        if (ldouble((unsigned long long)x) == x)
        {   // ((1.5 -> 1 -> 1.0) == 1.5) is false
            // ((1.0 -> 1 -> 1.0) == 1.0) is true
            // see http://en.cppreference.com/w/cpp/io/c/fprintf
            char format[] = {'%', '#', 'L', fmt, 0};
            return sprintf(str, format, ld_read(&x));
        }
        char format[] = { '%', fmt, 0 };
        return sprintf(str, format, ld_read(&x));
    }

    unsigned short exp = x.exponent;
    unsigned long long mantissa = x.mantissa;

    if(ld_type(x) == LD_TYPE_ZERO)
        return sprintf(str, "0x0.0L");

    size_t len = 0;
    if(x.sign)
        str[len++] = '-';
    len += sprintf(str + len, mantissa & (1LL << 63) ? "0x1." : "0x0.");
    mantissa = mantissa << 1;
    while(mantissa)
    {
        int dig = (mantissa >> 60) & 0xf;
        dig += dig < 10 ? '0' : fmt - 10;
        str[len++] = dig;
        mantissa = mantissa << 4;
    }
    str[len++] = 'p';
    if(exp < 0x3fff)
    {
        str[len++] = '-';
        exp = 0x3fff - exp;
    }
    else
    {
        str[len++] = '+';
        exp = exp - 0x3fff;
    }
    int exppos = len;
    for(int i = 12; i >= 0; i -= 4)
    {
        int dig = (exp >> i) & 0xf;
        if(dig != 0 || len > exppos || i == 0)
            str[len++] = dig + (dig < 10 ? '0' : fmt - 10);
    }
    str[len] = 0;
    return len;
}

//////////////////////////////////////////////////////////////

#if UNITTEST
static bool unittest()
{
    char buffer[32];
    ld_sprint(buffer, 'a', ld_pi);
    assert(strcmp(buffer, "0x1.921fb54442d1846ap+1") == 0);

    ld_sprint(buffer, 'g', ldouble(2.0));
    assert(strcmp(buffer, "2.00000") == 0);

    ld_sprint(buffer, 'g', ldouble(1234567.89));
    assert(strcmp(buffer, "1.23457e+06") == 0);

    longdouble ldb = ldouble(0.4);
    long long b = ldb;
    assert(b == 0);

    b = ldouble(0.9);
    assert(b == 0);

    long long x = 0x12345678abcdef78LL;
    longdouble ldx = ldouble(x);
    assert(ldx > 0);
    long long y = ldx;
    assert(x == y);

    x = -0x12345678abcdef78LL;
    ldx = ldouble(x);
    assert(ldx < 0);
    y = ldx;
    assert(x == y);

    unsigned long long u = 0x12345678abcdef78LL;
    longdouble ldu = ldouble(u);
    assert(ldu > 0);
    unsigned long long v = ldu;
    assert(u == v);

    u = 0xf234567812345678ULL;
    ldu = ldouble(u);
    assert(ldu > 0);
    v = ldu;
    assert(u == v);

    u = 0xf2345678;
    ldu = ldouble(u);
    ldu = ldu * ldu;
    ldu = sqrt(ldu);
    v = ldu;
    assert(u == v);

    u = 0x123456789A;
    ldu = ldouble(u);
    ldu = ldu * (1LL << 23);
    v = ldu;
    u = u * (1LL << 23);
    assert(u == v);

    return true;
}

static bool runUnittest = unittest();

#endif // UNITTEST

#endif // _MSC_VER

