/**
 * 80-bit floating point value implementation if the C/D compiler does not support them natively.
 *
 * Copyright (C) 1999-2023 by The D Language Foundation, All Rights Reserved
 * All Rights Reserved, written by Rainer Schuetze
 * https://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * (See accompanying file LICENSE or copy at https://www.boost.org/LICENSE_1_0.txt)
 * https://github.com/dlang/dmd/blob/master/src/root/longdouble.d
 */

module dmd.root.longdouble;

version (CRuntime_Microsoft)
{
    static if (real.sizeof > 8)
        alias longdouble = real;
    else
        alias longdouble = longdouble_soft;
}
else
    alias longdouble = real;

// longdouble_soft needed when building the backend with
// Visual C or the frontend with LDC on Windows
version (CRuntime_Microsoft):
extern (C++):
nothrow:
@nogc:

version(D_InlineAsm_X86_64)
    version = AsmX86;
else version(D_InlineAsm_X86)
    version = AsmX86;
else
    static assert(false, "longdouble_soft not supported on this platform");

bool initFPU()
{
    version(D_InlineAsm_X86_64)
    {
        // set precision to 64-bit mantissa and rounding control to nearest
        asm nothrow @nogc @trusted
        {
            push    RAX;                 // add space on stack
            fstcw   word ptr [RSP];
            movzx   EAX,word ptr [RSP];  // also return old CW in EAX
            and     EAX, ~0xF00;         // mask for PC and RC
            or      EAX, 0x300;
            mov     dword ptr [RSP],EAX;
            fldcw   word ptr [RSP];
            pop     RAX;
        }
    }
    else version(D_InlineAsm_X86)
    {
        // set precision to 64-bit mantissa and rounding control to nearest
        asm nothrow @nogc @trusted
        {
            push    EAX;                 // add space on stack
            fstcw   word ptr [ESP];
            movzx   EAX,word ptr [ESP];  // also return old CW in EAX
            and     EAX, ~0xF00;         // mask for PC and RC
            or      EAX, 0x300;
            mov     dword ptr [ESP],EAX;
            fldcw   word ptr [ESP];
            pop     EAX;
        }
    }

    return true;
}

version(unittest) version(CRuntime_Microsoft)
extern(D) shared static this()
{
    initFPU(); // otherwise not guaranteed to be run before pure unittest below
}

void ld_clearfpu()
{
    version(AsmX86)
    {
        asm nothrow @nogc @trusted
        {
            fclex;
        }
    }
}

pure:
@trusted: // LDC: LLVM __asm is @system AND requires taking the address of variables

struct longdouble_soft
{
nothrow @nogc pure:
    // DMD's x87 `real` on Windows is packed (alignof = 2 -> sizeof = 10).
    align(2) ulong mantissa = 0xC000000000000000UL; // default to qnan
    ushort exp_sign = 0x7fff; // sign is highest bit

    this(ulong m, ushort es) { mantissa = m; exp_sign = es; }
    this(longdouble_soft ld) { mantissa = ld.mantissa; exp_sign = ld.exp_sign; }
    this(int i) { ld_set(&this, i); }
    this(uint i) { ld_set(&this, i); }
    this(long i) { ld_setll(&this, i); }
    this(ulong i) { ld_setull(&this, i); }
    this(float f) { ld_set(&this, f); }
    this(double d)
    {
        // allow zero initialization at compile time
        if (__ctfe && d == 0)
        {
            mantissa = 0;
            exp_sign = 0;
        }
        else
            ld_set(&this, d);
    }
    this(real r)
    {
        static if (real.sizeof > 8)
            *cast(real*)&this = r;
        else
            this(cast(double)r);
    }

    ushort exponent() const { return exp_sign & 0x7fff; }
    bool sign() const { return (exp_sign & 0x8000) != 0; }

    extern(D)
    {
        ref longdouble_soft opAssign(longdouble_soft ld) return { mantissa = ld.mantissa; exp_sign = ld.exp_sign; return this; }
        ref longdouble_soft opAssign(T)(T rhs) { this = longdouble_soft(rhs); return this; }

        longdouble_soft opUnary(string op)() const
        {
            static if (op == "-") return longdouble_soft(mantissa, exp_sign ^ 0x8000);
            else static assert(false, "Operator `"~op~"` is not implemented");
        }

        bool opEquals(T)(T rhs) const { return this.ld_cmpe(longdouble_soft(rhs)); }
        int  opCmp(T)(T rhs) const { return this.ld_cmp(longdouble_soft(rhs)); }

        longdouble_soft opBinary(string op, T)(T rhs) const
        {
            static if      (op == "+") return this.ld_add(longdouble_soft(rhs));
            else static if (op == "-") return this.ld_sub(longdouble_soft(rhs));
            else static if (op == "*") return this.ld_mul(longdouble_soft(rhs));
            else static if (op == "/") return this.ld_div(longdouble_soft(rhs));
            else static if (op == "%") return this.ld_mod(longdouble_soft(rhs));
            else static assert(false, "Operator `"~op~"` is not implemented");
        }

        longdouble_soft opBinaryRight(string op, T)(T rhs) const
        {
            static if      (op == "+") return longdouble_soft(rhs).ld_add(this);
            else static if (op == "-") return longdouble_soft(rhs).ld_sub(this);
            else static if (op == "*") return longdouble_soft(rhs).ld_mul(this);
            else static if (op == "/") return longdouble_soft(rhs).ld_div(this);
            else static if (op == "%") return longdouble_soft(rhs).ld_mod(this);
            else static assert(false, "Operator `"~op~"` is not implemented");
        }

        ref longdouble_soft opOpAssign(string op)(longdouble_soft rhs)
        {
            mixin("this = this " ~ op ~ " rhs;");
            return this;
        }

        T opCast(T)() const @trusted
        {
            static      if (is(T == bool))   return mantissa != 0 || (exp_sign & 0x7fff) != 0;
            else static if (is(T == byte))   return cast(T)ld_read(&this);
            else static if (is(T == ubyte))  return cast(T)ld_read(&this);
            else static if (is(T == short))  return cast(T)ld_read(&this);
            else static if (is(T == ushort)) return cast(T)ld_read(&this);
            else static if (is(T == int))    return cast(T)ld_read(&this);
            else static if (is(T == uint))   return cast(T)ld_read(&this);
            else static if (is(T == float))  return cast(T)ld_read(&this);
            else static if (is(T == double)) return cast(T)ld_read(&this);
            else static if (is(T == long))   return ld_readll(&this);
            else static if (is(T == ulong))  return ld_readull(&this);
            else static if (is(T == real))
            {
                // convert to front end real if built with dmd
                if (real.sizeof > 8)
                    return *cast(real*)&this;
                else
                    return ld_read(&this);
            }
            else static assert(false, "usupported type");
        }
    }

    // a qnan
    static longdouble_soft nan() { return longdouble_soft(0xC000000000000000UL, 0x7fff); }
    static longdouble_soft infinity() { return longdouble_soft(0x8000000000000000UL, 0x7fff); }
    static longdouble_soft zero() { return longdouble_soft(0, 0); }
    static longdouble_soft max() { return longdouble_soft(0xffffffffffffffffUL, 0x7ffe); }
    static longdouble_soft min_normal() { return longdouble_soft(0x8000000000000000UL, 1); }
    static longdouble_soft epsilon() { return longdouble_soft(0x8000000000000000UL, 0x3fff - 63); }

    static uint dig() { return 18; }
    static uint mant_dig() { return 64; }
    static uint max_exp() { return 16_384; }
    static uint min_exp() { return -16_381; }
    static uint max_10_exp() { return 4932; }
    static uint min_10_exp() { return -4932; }
}

static assert(longdouble_soft.alignof == longdouble.alignof);
static assert(longdouble_soft.sizeof == longdouble.sizeof);

version(LDC)
{
    import ldc.llvmasm;

    extern(D):
    private:
    string fld_arg  (string arg)() { return `__asm("fldt $0",  "*m,~{st}",  &` ~ arg ~ `);`; }
    string fstp_arg (string arg)() { return `__asm("fstpt $0", "=*m,~{st}", &` ~ arg ~ `);`; }
    string fld_parg (string arg)() { return `__asm("fldt $0",  "*m,~{st}",   ` ~ arg ~ `);`; }
    string fstp_parg(string arg)() { return `__asm("fstpt $0", "=*m,~{st}",  ` ~ arg ~ `);`; }
}
else version(D_InlineAsm_X86_64)
{
    // longdouble_soft passed by reference
    extern(D):
    private:
    string fld_arg(string arg)()
    {
        return "asm nothrow @nogc pure @trusted { mov RAX, " ~ arg ~ "; fld real ptr [RAX]; }";
    }
    string fstp_arg(string arg)()
    {
        return "asm nothrow @nogc pure @trusted { mov RAX, " ~ arg ~ "; fstp real ptr [RAX]; }";
    }
    alias fld_parg = fld_arg;
    alias fstp_parg = fstp_arg;
}
else version(D_InlineAsm_X86)
{
    // longdouble_soft passed by value
    extern(D):
    private:
    string fld_arg(string arg)()
    {
        return "asm nothrow @nogc pure @trusted { lea EAX, " ~ arg ~ "; fld real ptr [EAX]; }";
    }
    string fstp_arg(string arg)()
    {
        return "asm nothrow @nogc pure @trusted { lea EAX, " ~ arg ~ "; fstp real ptr [EAX]; }";
    }
    string fld_parg(string arg)()
    {
        return "asm nothrow @nogc pure @trusted { mov EAX, " ~ arg ~ "; fld real ptr [EAX]; }";
    }
    string fstp_parg(string arg)()
    {
        return "asm nothrow @nogc pure @trusted { mov EAX, " ~ arg ~ "; fstp real ptr [EAX]; }";
    }
}

double ld_read(const longdouble_soft* pthis)
{
    double res;
    version(AsmX86)
    {
        mixin(fld_parg!("pthis"));
        asm nothrow @nogc pure @trusted
        {
            fstp res;
        }
    }
    return res;
}

long ld_readll(const longdouble_soft* pthis)
{
    return ld_readull(pthis);
}

ulong ld_readull(const longdouble_soft* pthis)
{
    // somehow the FPU does not respect the CHOP mode of the rounding control
    // in 64-bit mode
    // so we roll our own conversion (it also allows the usual C wrap-around
    // instead of the "invalid value" created by the FPU)
    int expo = pthis.exponent - 0x3fff;
    ulong u;
    if(expo < 0 || expo > 127)
        return 0;
    if(expo < 64)
        u = pthis.mantissa >> (63 - expo);
    else
        u = pthis.mantissa << (expo - 63);
    if(pthis.sign)
        u = ~u + 1;
    return u;
}

int ld_statusfpu()
{
    int res = 0;
    version(AsmX86)
    {
        asm nothrow @nogc pure @trusted
        {
            fstsw word ptr [res];
        }
    }
    return res;
}

void ld_set(longdouble_soft* pthis, double d)
{
    version(AsmX86)
    {
        asm nothrow @nogc pure @trusted
        {
            fld d;
        }
        mixin(fstp_parg!("pthis"));
    }
}

void ld_setll(longdouble_soft* pthis, long d)
{
    version(AsmX86)
    {
        asm nothrow @nogc pure @trusted
        {
            fild qword ptr d;
        }
        mixin(fstp_parg!("pthis"));
    }
}

void ld_setull(longdouble_soft* pthis, ulong d)
{
    d ^= (1L << 63);
    version(AsmX86)
    {
        auto pTwoPow63 = &twoPow63;
        mixin(fld_parg!("pTwoPow63"));
        asm nothrow @nogc pure @trusted
        {
            fild qword ptr d;
            faddp;
        }
        mixin(fstp_parg!("pthis"));
    }
}

// using an argument as result to avoid RVO, see https://issues.dlang.org/show_bug.cgi?id=18758
longdouble_soft ldexpl(longdouble_soft ld, int exp)
{
    version(AsmX86)
    {
        asm nothrow @nogc pure @trusted
        {
            fild    dword ptr exp;
        }
        mixin(fld_arg!("ld"));
        asm nothrow @nogc pure @trusted
        {
            fscale;                 // ST(0) = ST(0) * (2**ST(1))
            fstp    ST(1);
        }
        mixin(fstp_arg!("ld"));
    }
    return ld;
}

///////////////////////////////////////////////////////////////////////
longdouble_soft ld_add(longdouble_soft ld1, longdouble_soft ld2)
{
    version(AsmX86)
    {
        mixin(fld_arg!("ld1"));
        mixin(fld_arg!("ld2"));
        asm nothrow @nogc pure @trusted
        {
            fadd;
        }
        mixin(fstp_arg!("ld1"));
    }
    return ld1;
}

longdouble_soft ld_sub(longdouble_soft ld1, longdouble_soft ld2)
{
    version(AsmX86)
    {
        mixin(fld_arg!("ld1"));
        mixin(fld_arg!("ld2"));
        asm nothrow @nogc pure @trusted
        {
            fsub;
        }
        mixin(fstp_arg!("ld1"));
    }
    return ld1;
}

longdouble_soft ld_mul(longdouble_soft ld1, longdouble_soft ld2)
{
    version(AsmX86)
    {
        mixin(fld_arg!("ld1"));
        mixin(fld_arg!("ld2"));
        asm nothrow @nogc pure @trusted
        {
            fmul;
        }
        mixin(fstp_arg!("ld1"));
    }
    return ld1;
}

longdouble_soft ld_div(longdouble_soft ld1, longdouble_soft ld2)
{
    version(AsmX86)
    {
        mixin(fld_arg!("ld1"));
        mixin(fld_arg!("ld2"));
        asm nothrow @nogc pure @trusted
        {
            fdiv;
        }
        mixin(fstp_arg!("ld1"));
    }
    return ld1;
}

bool ld_cmpb(longdouble_soft x, longdouble_soft y)
{
    short sw;
    bool res;
    version(AsmX86)
    {
        mixin(fld_arg!("y"));
        mixin(fld_arg!("x"));
        asm nothrow @nogc pure @trusted
        {
            fucomip ST(1);
            setb    AL;
            setnp   AH;
            and     AL,AH;
            mov     res,AL;
            fstp    ST(0);
        }
    }
    return res;
}

bool ld_cmpbe(longdouble_soft x, longdouble_soft y)
{
    short sw;
    bool res;
    version(AsmX86)
    {
        mixin(fld_arg!("y"));
        mixin(fld_arg!("x"));
        asm nothrow @nogc pure @trusted
        {
            fucomip ST(1);
            setbe   AL;
            setnp   AH;
            and     AL,AH;
            mov     res,AL;
            fstp    ST(0);
        }
    }
    return res;
}

bool ld_cmpa(longdouble_soft x, longdouble_soft y)
{
    short sw;
    bool res;
    version(AsmX86)
    {
        mixin(fld_arg!("y"));
        mixin(fld_arg!("x"));
        asm nothrow @nogc pure @trusted
        {
            fucomip ST(1);
            seta    AL;
            setnp   AH;
            and     AL,AH;
            mov     res,AL;
            fstp    ST(0);
        }
    }
    return res;
}

bool ld_cmpae(longdouble_soft x, longdouble_soft y)
{
    short sw;
    bool res;
    version(AsmX86)
    {
        mixin(fld_arg!("y"));
        mixin(fld_arg!("x"));
        asm nothrow @nogc pure @trusted
        {
            fucomip ST(1);
            setae   AL;
            setnp   AH;
            and     AL,AH;
            mov     res,AL;
            fstp    ST(0);
        }
    }
    return res;
}

bool ld_cmpe(longdouble_soft x, longdouble_soft y)
{
    short sw;
    bool res;
    version(AsmX86)
    {
        mixin(fld_arg!("y"));
        mixin(fld_arg!("x"));
        asm nothrow @nogc pure @trusted
        {
            fucomip ST(1);
            sete    AL;
            setnp   AH;
            and     AL,AH;
            mov     res,AL;
            fstp    ST(0);
        }
    }
    return res;
}

bool ld_cmpne(longdouble_soft x, longdouble_soft y)
{
    short sw;
    bool res;
    version(AsmX86)
    {
        mixin(fld_arg!("y"));
        mixin(fld_arg!("x"));
        asm nothrow @nogc pure @trusted
        {
            fucomip ST(1);
            setne   AL;
            setp    AH;
            or      AL,AH;
            mov     res,AL;
            fstp    ST(0);
        }
    }
    return res;
}

int ld_cmp(longdouble_soft x, longdouble_soft y)
{
    // return -1 if x < y, 0 if x == y or unordered, 1 if x > y
    short sw;
    int res;
    version(AsmX86)
    {
        mixin(fld_arg!("y"));
        mixin(fld_arg!("x"));
        asm nothrow @nogc pure @trusted
        {
            fucomip ST(1);
            seta    AL;
            setb    AH;
            setp    DL;
            or      AL, DL;
            or      AH, DL;
            sub     AL, AH;
            movsx   EAX, AL;
            fstp    ST(0);
            mov     res, EAX;
        }
    }
}


int _isnan(longdouble_soft ld)
{
    return (ld.exponent == 0x7fff && ld.mantissa != 0 && ld.mantissa != (1L << 63)); // exclude pseudo-infinity and infinity, but not FP Indefinite
}

longdouble_soft fabsl(longdouble_soft ld)
{
    ld.exp_sign = ld.exponent;
    return ld;
}

longdouble_soft sqrtl(longdouble_soft ld)
{
    version(AsmX86)
    {
        mixin(fld_arg!("ld"));
        asm nothrow @nogc pure @trusted
        {
            fsqrt;
        }
        mixin(fstp_arg!("ld"));
    }
    return ld;
}

longdouble_soft sqrt(longdouble_soft ld) { return sqrtl(ld); }

longdouble_soft sinl (longdouble_soft ld)
{
    version(AsmX86)
    {
        mixin(fld_arg!("ld"));
        asm nothrow @nogc pure @trusted
        {
            fsin; // exact for |x|<=PI/4
        }
        mixin(fstp_arg!("ld"));
    }
    return ld;
}
longdouble_soft cosl (longdouble_soft ld)
{
    version(AsmX86)
    {
        mixin(fld_arg!("ld"));
        asm nothrow @nogc pure @trusted
        {
            fcos; // exact for |x|<=PI/4
        }
        mixin(fstp_arg!("ld"));
    }
    return ld;
}
longdouble_soft tanl (longdouble_soft ld)
{
    version(AsmX86)
    {
        mixin(fld_arg!("ld"));
        asm nothrow @nogc pure @trusted
        {
            fptan;
            fstp ST(0); // always 1
        }
        mixin(fstp_arg!("ld"));
    }
    return ld;
}

longdouble_soft fmodl(longdouble_soft x, longdouble_soft y)
{
    return ld_mod(x, y);
}

longdouble_soft ld_mod(longdouble_soft x, longdouble_soft y)
{
    short sw;
    version(AsmX86)
    {
        mixin(fld_arg!("y"));
        mixin(fld_arg!("x"));
        asm nothrow @nogc pure @trusted
        {
        FM1:    // We don't use fprem1 because for some inexplicable
                // reason we get -5 when we do _modulo(15, 10)
            fprem;                          // ST = ST % ST1
            fstsw   word ptr sw;
            fwait;
            mov     AH,byte ptr sw+1;       // get msb of status word in AH
            sahf;                           // transfer to flags
            jp      FM1;                    // continue till ST < ST1
            fstp    ST(1);                  // leave remainder on stack
        }
        mixin(fstp_arg!("x"));
    }
    return x;
}

//////////////////////////////////////////////////////////////

@safe:

__gshared const
{
    longdouble_soft ld_qnan = longdouble_soft(0xC000000000000000UL, 0x7fff);
    longdouble_soft ld_inf  = longdouble_soft(0x8000000000000000UL, 0x7fff);

    longdouble_soft ld_zero  = longdouble_soft(0, 0);
    longdouble_soft ld_one   = longdouble_soft(0x8000000000000000UL, 0x3fff);
    longdouble_soft ld_pi    = longdouble_soft(0xc90fdaa22168c235UL, 0x4000);
    longdouble_soft ld_log2t = longdouble_soft(0xd49a784bcd1b8afeUL, 0x4000);
    longdouble_soft ld_log2e = longdouble_soft(0xb8aa3b295c17f0bcUL, 0x3fff);
    longdouble_soft ld_log2  = longdouble_soft(0x9a209a84fbcff799UL, 0x3ffd);
    longdouble_soft ld_ln2   = longdouble_soft(0xb17217f7d1cf79acUL, 0x3ffe);

    longdouble_soft ld_pi2     = longdouble_soft(0xc90fdaa22168c235UL, 0x4001);
    longdouble_soft ld_piOver2 = longdouble_soft(0xc90fdaa22168c235UL, 0x3fff);
    longdouble_soft ld_piOver4 = longdouble_soft(0xc90fdaa22168c235UL, 0x3ffe);

    longdouble_soft twoPow63 = longdouble_soft(1UL << 63, 0x3fff + 63);
}

//////////////////////////////////////////////////////////////

enum LD_TYPE_OTHER    = 0;
enum LD_TYPE_ZERO     = 1;
enum LD_TYPE_INFINITE = 2;
enum LD_TYPE_SNAN     = 3;
enum LD_TYPE_QNAN     = 4;

int ld_type(longdouble_soft x)
{
    // see https://en.wikipedia.org/wiki/Extended_precision
    if(x.exponent == 0)
        return x.mantissa == 0 ? LD_TYPE_ZERO : LD_TYPE_OTHER; // dnormal if not zero
    if(x.exponent != 0x7fff)
        return LD_TYPE_OTHER;    // normal or denormal
    uint  upper2  = x.mantissa >> 62;
    ulong lower62 = x.mantissa & ((1L << 62) - 1);
    if(upper2 == 0 && lower62 == 0)
        return LD_TYPE_INFINITE; // pseudo-infinity
    if(upper2 == 2 && lower62 == 0)
        return LD_TYPE_INFINITE; // infinity
    if(upper2 == 2 && lower62 != 0)
        return LD_TYPE_SNAN;
    return LD_TYPE_QNAN;         // qnan, indefinite, pseudo-nan
}

// consider snprintf pure
private extern(C) int snprintf(scope char* s, size_t size, scope const char* format, ...) pure @nogc nothrow;

size_t ld_sprint(char* str, size_t size, int fmt, longdouble_soft x) @system
{
    // ensure dmc compatible strings for nan and inf
    switch(ld_type(x))
    {
        case LD_TYPE_QNAN:
        case LD_TYPE_SNAN:
            return snprintf(str, size, "nan");
        case LD_TYPE_INFINITE:
            return snprintf(str, size, x.sign ? "-inf" : "inf");
        default:
            break;
    }

    // fmt is 'a','A','f' or 'g'
    if(fmt != 'a' && fmt != 'A')
    {
        char[3] format = ['%', cast(char)fmt, 0];
        return snprintf(str, size, format.ptr, ld_read(&x));
    }

    ushort exp = x.exponent;
    ulong mantissa = x.mantissa;

    if(ld_type(x) == LD_TYPE_ZERO)
        return snprintf(str, size, fmt == 'a' ? "0x0.0L" : "0X0.0L");

    size_t len = 0;
    if(x.sign)
        str[len++] = '-';
    str[len++] = '0';
    str[len++] = cast(char)('X' + fmt - 'A');
    str[len++] = mantissa & (1L << 63) ? '1' : '0';
    str[len++] = '.';
    mantissa = mantissa << 1;
    while(mantissa)
    {
        int dig = (mantissa >> 60) & 0xf;
        dig += dig < 10 ? '0' : fmt - 10;
        str[len++] = cast(char)dig;
        mantissa = mantissa << 4;
    }
    str[len++] = cast(char)('P' + fmt - 'A');
    if(exp < 0x3fff)
    {
        str[len++] = '-';
        exp = cast(ushort)(0x3fff - exp);
    }
    else
    {
        str[len++] = '+';
        exp = cast(ushort)(exp - 0x3fff);
    }
    size_t exppos = len;
    for(int i = 12; i >= 0; i -= 4)
    {
        int dig = (exp >> i) & 0xf;
        if(dig != 0 || len > exppos || i == 0)
            str[len++] = cast(char)(dig + (dig < 10 ? '0' : fmt - 10));
    }
    str[len] = 0;
    return len;
}

//////////////////////////////////////////////////////////////

@system unittest
{
    import core.stdc.string;
    import core.stdc.stdio;

    const bufflen = 32;
    char[bufflen] buffer;
    ld_sprint(buffer.ptr, bufflen, 'a', ld_pi);
    assert(strcmp(buffer.ptr, "0x1.921fb54442d1846ap+1") == 0);

    auto len = ld_sprint(buffer.ptr, bufflen, 'g', longdouble_soft(2.0));
    assert(buffer[0 .. len] == "2.00000" || buffer[0 .. len] == "2"); // Win10 - 64bit

    ld_sprint(buffer.ptr, bufflen, 'g', longdouble_soft(1_234_567.89));
    assert(strcmp(buffer.ptr, "1.23457e+06") == 0);

    ld_sprint(buffer.ptr, bufflen, 'g', ld_inf);
    assert(strcmp(buffer.ptr, "inf") == 0);

    ld_sprint(buffer.ptr, bufflen, 'g', ld_qnan);
    assert(strcmp(buffer.ptr, "nan") == 0);

    longdouble_soft ldb = longdouble_soft(0.4);
    long b = cast(long)ldb;
    assert(b == 0);

    b = cast(long)longdouble_soft(0.9);
    assert(b == 0);

    long x = 0x12345678abcdef78L;
    longdouble_soft ldx = longdouble_soft(x);
    assert(ldx > ld_zero);
    long y = cast(long)ldx;
    assert(x == y);

    x = -0x12345678abcdef78L;
    ldx = longdouble_soft(x);
    assert(ldx < ld_zero);
    y = cast(long)ldx;
    assert(x == y);

    ulong u = 0x12345678abcdef78L;
    longdouble_soft ldu = longdouble_soft(u);
    assert(ldu > ld_zero);
    ulong v = cast(ulong)ldu;
    assert(u == v);

    u = 0xf234567812345678UL;
    ldu = longdouble_soft(u);
    assert(ldu > ld_zero);
    v = cast(ulong)ldu;
    assert(u == v);

    u = 0xf2345678;
    ldu = longdouble_soft(u);
    ldu = ldu * ldu;
    ldu = sqrt(ldu);
    v = cast(ulong)ldu;
    assert(u == v);

    u = 0x123456789A;
    ldu = longdouble_soft(u);
    ldu = ldu * longdouble_soft(1L << 23);
    v = cast(ulong)ldu;
    u = u * (1L << 23);
    assert(u == v);
}
