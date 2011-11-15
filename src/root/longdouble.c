#include "longdouble.h"

#include <float.h>
#include <stdio.h>

static long_double _sincos(long_double,int);

extern "C"
{
    int ld_initfpu(int rc);
    double ld_read(volatile ld_data* ld);
    void ld_set(ld_data* ld, double d);
    void ld_setll(ld_data* ld, long long d);
    void ld_setull(ld_data* ld, unsigned long long d);
    void ld_expl(ld_data* ld, int exp);
    long_double ld_add(long_double ld1, long_double ld2);
    long_double ld_sub(long_double ld1, long_double ld2);
    long_double ld_mul(long_double ld1, long_double ld2);
    long_double ld_div(long_double ld1, long_double ld2);
    long_double ld_mod(long_double ld1, long_double ld2);
    bool ld_cmpb(long_double ld1, long_double ld2);
    bool ld_cmpbe(long_double ld1, long_double ld2);
    bool ld_cmpa(long_double ld1, long_double ld2);
    bool ld_cmpae(long_double ld1, long_double ld2);
    bool ld_cmpe(long_double ld1, long_double ld2);
    bool ld_cmpne(long_double ld1, long_double ld2);
    long_double ld_sin(long_double ld1);
    long_double ld_cos(long_double ld1);
    long_double ld_tan(long_double ld1);
}

bool initFPU()
{
#ifdef _WIN64
    int old_cw = ld_initfpu(_RC_NEAR);
#else
    int old_cw = _control87(_MCW_EM | _PC_64  | _RC_NEAR,
                            _MCW_EM | _MCW_PC | _MCW_RC);
#endif
    return true;
}
static bool doInitFPU = initFPU();

double ld_data::read()
{ 
#ifdef _WIN64
    return ld_read(this);
#else
    volatile ld_data* pthis = this;
    __asm 
    {
        mov eax, pthis
        fld tbyte ptr [eax]
    }
    // return double in FP register
#endif
}
void ld_data::set(double d) 
{ 
#ifdef _WIN64
    return ld_set(this, d);
#else
    ld_data* pthis = this;
    __asm 
    { 
        mov eax, pthis
        fld d
        fstp tbyte ptr [eax]
    }
#endif
}
void ld_data::setll(long long d) 
{
#ifdef _WIN64
    return ld_setll(this, d);
#else
    ld_data* pthis = this;
    __asm 
    { 
        fild qword ptr d
        mov eax, pthis
        fstp tbyte ptr [eax]
    }
#endif
}
void ld_data::setull(unsigned long long d) 
{
#ifdef _WIN64
    return ld_setull(this, d);
#else
    ld_data* pthis = this;
    if(d & (1LL << 63))
    {
        ld_data twoPow64 = { 1ULL << 63, 0x3fff + 64, 0 };
        __asm
        {
            fild qword ptr d
            fld tbyte ptr twoPow64;
            fadd ST(1),ST(0)
            fstp ST(0)
        }
    }
    else
        __asm fild qword ptr d

    __asm
    {
        mov eax, pthis
        fstp tbyte ptr [eax]
    }
#endif
}

long_double ldexpl(long_double ld, int exp)
{
#ifdef _WIN64
    ld_expl(&ld.tdbl, exp);
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
long_double operator+(long_double ld1, long_double ld2) 
{
#ifdef _WIN64
    return ld_add(ld1, ld2);
#else
    long_double res;
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

long_double operator-(long_double ld1, long_double ld2)
{
#ifdef _WIN64
    return ld_sub(ld1, ld2);
#else
    long_double res;
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

long_double operator*(long_double ld1, long_double ld2)
{
#ifdef _WIN64
    return ld_mul(ld1, ld2);
#else
    long_double res;
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

long_double operator/(long_double ld1, long_double ld2)
{
#ifdef _WIN64
    return ld_div(ld1, ld2);
#else
    long_double res;
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

bool operator< (long_double x, long_double y)
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
bool operator<=(long_double x, long_double y)
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
bool operator> (long_double x, long_double y)
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
bool operator>=(long_double x, long_double y)
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
bool operator==(long_double x, long_double y)
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
bool operator!=(long_double x, long_double y)
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


int _isnan(long_double ld) { return _isnan(ld.read()); }

long_double fabsl(long_double ld)
{
    ld.tdbl.sign = 0;
    return ld;
}

long_double sqrtl(long_double ld) { return ldouble(sqrt(ld.read())); }

long_double sinl (long_double ld)
{
#ifdef _WIN64
    return ld_sin(ld);
#else
    return _sincos(ld, 0);
#endif
}
long_double cosl (long_double ld)
{ 
#ifdef _WIN64
    return ld_cos(ld);
#else
    return _sincos(ld, 1);
#endif
}
long_double tanl (long_double ld)
{
#ifdef _WIN64
    return ld_tan(ld);
#else
    return _sincos(ld, 2);
#endif
}

long_double fmodl(long_double x, long_double y)
{
#ifdef _WIN64
    return ld_mod(x, y);
#else
    short sw;
    long_double res;
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

#define DTYPE_OTHER	0
#define DTYPE_ZERO	1
#define DTYPE_INFINITE	2
#define DTYPE_SNAN	3
#define DTYPE_QNAN	4

long_double ld_qnan = { 0x8000000000000000ULL, 0x7fff, 0 };
long_double ld_snan = { 0x0000000000000000ULL, 0x7fff, 0 };

long_double ld_zero  = { 0, 0, 0 };
long_double ld_one   = { 0x8000000000000000ULL, 0x3fff, 0 };
long_double ld_pi    = { 0xc90fdaa22168c235ULL, 0x4000, 0 };
long_double ld_log2t = { 0xd49a784bcd1b8afeULL, 0x4000, 0 };
long_double ld_log2e = { 0xb8aa3b295c17f0bcULL, 0x3fff, 0 };
long_double ld_log2  = { 0x9a209a84fbcff799ULL, 0x3ffd, 0 };
long_double ld_ln2   = { 0xb17217f7d1cf79acULL, 0x3ffe, 0 };

long_double ld_pi2     = ld_pi*2;
long_double ld_piOver2 = ld_pi*0.5;
long_double ld_piOver4 = ld_pi*0.25;

int __dtype(long_double x)
{
    if(x.tdbl.exponent == 0)
        return x.tdbl.mantissa == 0 ? DTYPE_ZERO : DTYPE_OTHER; // dnormal if not zero
    if(x.tdbl.exponent != 0x7fff)
        return DTYPE_OTHER;
    if(x.tdbl.mantissa == 0)
        return DTYPE_INFINITE;
    if(x.tdbl.mantissa & (1LL << 63))
        return DTYPE_QNAN;
    return DTYPE_SNAN;
}

static long_double _sincos(long_double x,int flag)
{
    switch(__dtype(x))
    {
    case DTYPE_ZERO:
        if (flag == 1)
            return ldouble(1.0);
    case DTYPE_QNAN:
        return x;
    case DTYPE_INFINITE:
        return ld_qnan;
    case DTYPE_SNAN:
        return ld_qnan;
    }

    long_double y;

#if 0 // DMC uses intrinsics without reduction!
    if(flag == 1)
    {
        x = x + piOver2;
        flag = 0;
    }
    bool inv = false;
    bool neg = x.tdbl.sign;
    x.tdbl.sign = 0;
    if(x > piOver4)
    {
        //while(x >= pi2)
        //    x = x - pi2;
        __asm
        {
            fldpi
            fstp tbyte ptr pi
        }
        x = fmodl(x, pi);
        if(flag != 2)
        {
            if(x > pi)
            {
                x = x - pi;
                neg = !neg;
            }
            if(x > piOver2)
                x = pi - x;
            if(x > piOver4)
            {
                x = piOver2 - x;
                flag = 1;
            }
        }
    }
#else
    bool neg = false;
#endif
#ifdef _WIN64
    return x;
#else
    switch(flag)
    {
    case 0:
        __asm fld tbyte ptr x;
        __asm fsin; // exact for |x|<=PI/4
        __asm fstp tbyte ptr y;
        break;
    case 1:
        __asm fld tbyte ptr x;
        __asm fcos; // exact for |x|<=PI/4
        __asm fstp tbyte ptr y;
        break;
    case 2:
        __asm fld tbyte ptr x;
        __asm fptan;
        __asm fstp ST(0);
        __asm fstp tbyte ptr y;
        break;
    }
    if(neg)
        y.tdbl.sign = y.tdbl.sign ^ 1;
    return y;
#endif
}

int ld_sprint(char* str, int fmt, long_double x)
{
    // fmt is 'a','A','f' or 'g'
    if(fmt != 'a' && fmt != 'A')
    {
        char format[] = { '%', fmt, 0 };
        return sprintf(str, format, x.read());
    }

    unsigned short exp = x.tdbl.exponent;
    unsigned long long mantissa = x.tdbl.mantissa;

    switch(__dtype(x))
    {
    case DTYPE_ZERO:
        return sprintf(str, "0x0.0L");
    case DTYPE_QNAN:
    case DTYPE_SNAN:
        return sprintf(str, "NAN");
    case DTYPE_INFINITE:
        return sprintf(str, x.tdbl.sign ? "-INF" : "INF");
    }

    int len = 0;
    if(x.tdbl.sign)
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
