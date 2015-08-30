// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.builtin;

import core.stdc.math;
import core.stdc.string;
import ddmd.arraytypes;
import ddmd.dmangle;
import ddmd.errors;
import ddmd.expression;
import ddmd.func;
import ddmd.globals;
import ddmd.mtype;
import ddmd.root.port;
import ddmd.root.stringtable;
import ddmd.tokens;

extern (C++) alias builtin_fp = Expression function(Loc loc, FuncDeclaration fd, Expressions* arguments);

extern (C++) __gshared StringTable builtins;

extern (C++) void add_builtin(const(char)* mangle, builtin_fp fp)
{
    builtins.insert(mangle, strlen(mangle)).ptrvalue = cast(void*)fp;
}

extern (C++) builtin_fp builtin_lookup(const(char)* mangle)
{
    if (StringValue* sv = builtins.lookup(mangle, strlen(mangle)))
        return cast(builtin_fp)sv.ptrvalue;
    return null;
}

extern (C++) Expression eval_sin(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOKfloat64);
    return new RealExp(loc, sinl(arg0.toReal()), arg0.type);
}

extern (C++) Expression eval_cos(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOKfloat64);
    return new RealExp(loc, cosl(arg0.toReal()), arg0.type);
}

extern (C++) Expression eval_tan(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOKfloat64);
    return new RealExp(loc, tanl(arg0.toReal()), arg0.type);
}

extern (C++) Expression eval_sqrt(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOKfloat64);
    return new RealExp(loc, Port.sqrt(arg0.toReal()), arg0.type);
}

extern (C++) Expression eval_fabs(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOKfloat64);
    return new RealExp(loc, fabsl(arg0.toReal()), arg0.type);
}

extern (C++) Expression eval_bsf(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOKint64);
    uinteger_t n = arg0.toInteger();
    if (n == 0)
        error(loc, "bsf(0) is undefined");
    n = (n ^ (n - 1)) >> 1; // convert trailing 0s to 1, and zero rest
    int k = 0;
    while (n)
    {
        ++k;
        n >>= 1;
    }
    return new IntegerExp(loc, k, Type.tint32);
}

extern (C++) Expression eval_bsr(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOKint64);
    uinteger_t n = arg0.toInteger();
    if (n == 0)
        error(loc, "bsr(0) is undefined");
    int k = 0;
    while (n >>= 1)
    {
        ++k;
    }
    return new IntegerExp(loc, k, Type.tint32);
}

extern (C++) Expression eval_bswap(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOKint64);
    uinteger_t n = arg0.toInteger();
    enum BYTEMASK = 0x00FF00FF00FF00FFL;
    enum SHORTMASK = 0x0000FFFF0000FFFFL;
    enum INTMASK = 0x0000FFFF0000FFFFL;
    // swap adjacent ubytes
    n = ((n >> 8) & BYTEMASK) | ((n & BYTEMASK) << 8);
    // swap adjacent ushorts
    n = ((n >> 16) & SHORTMASK) | ((n & SHORTMASK) << 16);
    TY ty = arg0.type.toBasetype().ty;
    // If 64 bits, we need to swap high and low uints
    if (ty == Tint64 || ty == Tuns64)
        n = ((n >> 32) & INTMASK) | ((n & INTMASK) << 32);
    return new IntegerExp(loc, n, arg0.type);
}

extern (C++) Expression eval_popcnt(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOKint64);
    uinteger_t n = arg0.toInteger();
    int cnt = 0;
    while (n)
    {
        cnt += (n & 1);
        n >>= 1;
    }
    return new IntegerExp(loc, cnt, arg0.type);
}

extern (C++) Expression eval_yl2x(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOKfloat64);
    Expression arg1 = (*arguments)[1];
    assert(arg1.op == TOKfloat64);
    real x = arg0.toReal();
    real y = arg1.toReal();
    real result;
    Port.yl2x_impl(&x, &y, &result);
    return new RealExp(loc, result, arg0.type);
}

extern (C++) Expression eval_yl2xp1(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOKfloat64);
    Expression arg1 = (*arguments)[1];
    assert(arg1.op == TOKfloat64);
    real x = arg0.toReal();
    real y = arg1.toReal();
    real result;
    Port.yl2xp1_impl(&x, &y, &result);
    return new RealExp(loc, result, arg0.type);
}

extern (C++) void builtin_init()
{
    builtins._init(47);
    add_builtin("sin", &eval_sin);
    add_builtin("cos", &eval_cos);
    add_builtin("tan", &eval_tan);
    add_builtin("sqrt", &eval_sqrt);
    add_builtin("abs", &eval_fabs);
    if (Port.yl2x_supported)
    {
        add_builtin("yl2x", &eval_yl2x);
    }
    if (Port.yl2xp1_supported)
    {
        add_builtin("yl2xp1", &eval_yl2xp1);
    }
    add_builtin("bsf", &eval_bsf);
    add_builtin("bsr", &eval_bsr);
    add_builtin("bswap", &eval_bswap);
    add_builtin("popcnt", &eval_popcnt);
}

/**************************************
 * Evaluate builtin function.
 * Return result; NULL if cannot evaluate it.
 */
extern (C++) Expression eval_builtin(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    if (fd.intrinsicName)
    {
        builtin_fp fp = builtin_lookup(fd.intrinsicName);
        if (fp)
            return fp(loc, fd, arguments);
    }
    return null;
}
