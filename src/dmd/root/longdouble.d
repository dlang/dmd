/* Copyright (c) 1999-2017 by Digital Mars
 * All Rights Reserved, written by Rainer Schuetze
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * (See accompanying file LICENSE or copy at http://www.boost.org/LICENSE_1_0.txt)
 * https://github.com/dlang/dmd/blob/master/src/root/longdouble.d
 */

// 80 bit floating point value implementation for LDC compiler targetting MSVC

module dmd.root.longdouble;

enum hasNativeFloat80 = real.sizeof > 8;

static if (hasNativeFloat80)
{
    alias longdouble = real;
}

static if (!hasNativeFloat80):
extern(C++):
nothrow:

align(2) struct longdouble
{
nothrow:
    ulong mantissa = 0xC000000000000001UL; // default to snan
    ushort exp_sign = 0x7fff; // sign is highest bit

    this(ulong m, ushort es) { mantissa = m; exp_sign = es; }
    this(longdouble ld) { mantissa = ld.mantissa; exp_sign = ld.exp_sign; }
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

    void opAssign(float f) { ld_set(&this, f); }
    void opAssign(double f) { ld_set(&this, f); }
    longdouble opNeg() const { return longdouble(mantissa, exp_sign ^ 0x8000); }

    bool opEquals(const longdouble rhs) const { return this.ld_cmpe(rhs); }
    int  opCmp(longdouble rhs) const { return this.ld_cmp(rhs); }
    longdouble opAdd(longdouble rhs) const { return this.ld_add(rhs); }
    longdouble opSub(longdouble rhs) const { return this.ld_sub(rhs); }
    longdouble opMul(longdouble rhs) const { return this.ld_mul(rhs); }
    longdouble opDiv(longdouble rhs) const { return this.ld_div(rhs); }
    longdouble opMod(longdouble rhs) const { return this.ld_mod(rhs); }

    T opCast(T)() const
    {
        static      if(is(T == bool))   return mantissa != 0 || (exp_sign & 0x7fff) != 0;
        else static if(is(T == byte))   return cast(T)ld_read(&this);
        else static if(is(T == ubyte))  return cast(T)ld_read(&this);
        else static if(is(T == short))  return cast(T)ld_read(&this);
        else static if(is(T == ushort)) return cast(T)ld_read(&this);
        else static if(is(T == int))    return cast(T)ld_read(&this);
        else static if(is(T == uint))   return cast(T)ld_read(&this);
        else static if(is(T == float))  return cast(T)ld_read(&this);
        else static if(is(T == double)) return cast(T)ld_read(&this);
        else static if(is(T == long))   return ld_readll(&this);
        else static if(is(T == ulong))  return ld_readull(&this);
        else static assert(false, "usupported type");
    }

    static longdouble nan() { return longdouble(0xC000000000000000UL, 0x7fff); }
    static longdouble infinity() { return longdouble(0x8000000000000000UL, 0x7fff); }
    static longdouble zero() { return longdouble(0, 0); }
    static longdouble max() { return longdouble(0xffffffffffffffffUL, 0x7ffe); }
    static longdouble min_normal() { return longdouble(0x8000000000000000UL, 1); }
    static longdouble epsilon() { return longdouble(0x8000000000000000UL, 0x3fff - 63); }

    static uint dig() { return 18; }
    static uint mant_dig() { return 64; }
    static uint max_exp() { return 16384; }
    static uint min_exp() { return -16381; }
    static uint max_10_exp() { return 4932; }
    static uint min_10_exp() { return -4932; }
};

extern(C)
{
    longdouble ld_add(longdouble ld1, longdouble ld2);
    longdouble ld_sub(longdouble ld1, longdouble ld2);
    longdouble ld_mul(longdouble ld1, longdouble ld2);
    longdouble ld_div(longdouble ld1, longdouble ld2);
    longdouble ld_mod(longdouble ld1, longdouble ld2);

    int ld_cmp(longdouble ld1, longdouble ld2);
    bool ld_cmpe(longdouble ld1, longdouble ld2);

    double ld_read(const longdouble* ld);
    long ld_readll(const longdouble* ld);
    ulong ld_readull(const longdouble* ld);

    void ld_set(longdouble* ld, double d);
    void ld_setll(longdouble* ld, long d);
    void ld_setull(longdouble* ld, ulong d);
}


extern longdouble ld_qnan;
extern longdouble ld_inf;

longdouble fabsl(longdouble ld);
longdouble sqrtl(longdouble ld);
longdouble sinl (longdouble ld);
longdouble cosl (longdouble ld);
longdouble tanl (longdouble ld);
longdouble ldexpl(longdouble ldval, int exp);

longdouble sqrt (longdouble ld) { return sqrtl(ld); }
