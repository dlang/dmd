
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/builtin.c
 */

#include <stdio.h>
#include <assert.h>
#include <string.h>                     // strcmp()
#include <math.h>

#include "mars.h"
#include "declaration.h"
#include "attrib.h"
#include "expression.h"
#include "scope.h"
#include "mtype.h"
#include "aggregate.h"
#include "identifier.h"
#include "id.h"
#include "module.h"
#include "root/port.h"

StringTable builtins;

void add_builtin(const char *mangle, builtin_fp fp)
{
    builtins.insert(mangle, strlen(mangle))->ptrvalue = (void *)fp;
}

builtin_fp builtin_lookup(const char *mangle)
{
    if (StringValue *sv = builtins.lookup(mangle, strlen(mangle)))
        return (builtin_fp)sv->ptrvalue;
    return NULL;
}

Expression *eval_unimp(Loc loc, FuncDeclaration *fd, Expressions *arguments)
{
    return NULL;
}

Expression *eval_sin(Loc loc, FuncDeclaration *fd, Expressions *arguments)
{
    Expression *arg0 = (*arguments)[0];
    assert(arg0->op == TOKfloat64);
    return new RealExp(loc, sinl(arg0->toReal()), arg0->type);
}

Expression *eval_cos(Loc loc, FuncDeclaration *fd, Expressions *arguments)
{
    Expression *arg0 = (*arguments)[0];
    assert(arg0->op == TOKfloat64);
    return new RealExp(loc, cosl(arg0->toReal()), arg0->type);
}

Expression *eval_tan(Loc loc, FuncDeclaration *fd, Expressions *arguments)
{
    Expression *arg0 = (*arguments)[0];
    assert(arg0->op == TOKfloat64);
    return new RealExp(loc, tanl(arg0->toReal()), arg0->type);
}

Expression *eval_sqrt(Loc loc, FuncDeclaration *fd, Expressions *arguments)
{
    Expression *arg0 = (*arguments)[0];
    assert(arg0->op == TOKfloat64);
    return new RealExp(loc, Port::sqrt(arg0->toReal()), arg0->type);
}

Expression *eval_fabs(Loc loc, FuncDeclaration *fd, Expressions *arguments)
{
    Expression *arg0 = (*arguments)[0];
    assert(arg0->op == TOKfloat64);
    return new RealExp(loc, fabsl(arg0->toReal()), arg0->type);
}

Expression *eval_bsf(Loc loc, FuncDeclaration *fd, Expressions *arguments)
{
    Expression *arg0 = (*arguments)[0];
    assert(arg0->op == TOKint64);
    uinteger_t n = arg0->toInteger();
    if (n == 0)
        error(loc, "bsf(0) is undefined");
    n = (n ^ (n - 1)) >> 1;  // convert trailing 0s to 1, and zero rest
    int k = 0;
    while( n )
    {   ++k;
        n >>=1;
    }
    return new IntegerExp(loc, k, Type::tint32);
}

Expression *eval_bsr(Loc loc, FuncDeclaration *fd, Expressions *arguments)
{
    Expression *arg0 = (*arguments)[0];
    assert(arg0->op == TOKint64);
    uinteger_t n = arg0->toInteger();
    if (n == 0)
        error(loc, "bsr(0) is undefined");
    int k = 0;
    while(n >>= 1)
    {
        ++k;
    }
    return new IntegerExp(loc, k, Type::tint32);
}

Expression *eval_bswap(Loc loc, FuncDeclaration *fd, Expressions *arguments)
{
    Expression *arg0 = (*arguments)[0];
    assert(arg0->op == TOKint64);
    uinteger_t n = arg0->toInteger();
    #define BYTEMASK  0x00FF00FF00FF00FFLL
    #define SHORTMASK 0x0000FFFF0000FFFFLL
    #define INTMASK 0x0000FFFF0000FFFFLL
    // swap adjacent ubytes
    n = ((n >> 8 ) & BYTEMASK)  | ((n & BYTEMASK) << 8 );
    // swap adjacent ushorts
    n = ((n >> 16) & SHORTMASK) | ((n & SHORTMASK) << 16);
    TY ty = arg0->type->toBasetype()->ty;
    // If 64 bits, we need to swap high and low uints
    if (ty == Tint64 || ty == Tuns64)
        n = ((n >> 32) & INTMASK) | ((n & INTMASK) << 32);
    return new IntegerExp(loc, n, arg0->type);
}

Expression *eval_popcnt(Loc loc, FuncDeclaration *fd, Expressions *arguments)
{
    Expression *arg0 = (*arguments)[0];
    assert(arg0->op == TOKint64);
    uinteger_t n = arg0->toInteger();
    int cnt = 0;
    while (n)
    {
        cnt += (n & 1);
        n >>= 1;
    }
    return new IntegerExp(loc, cnt, arg0->type);
}

Expression *eval_yl2x(Loc loc, FuncDeclaration *fd, Expressions *arguments)
{
    Expression *arg0 = (*arguments)[0];
    assert(arg0->op == TOKfloat64);
    Expression *arg1 = (*arguments)[1];
    assert(arg1->op == TOKfloat64);
    longdouble x = arg0->toReal();
    longdouble y = arg1->toReal();
    longdouble result;
    Port::yl2x_impl(&x, &y, &result);
    return new RealExp(loc, result, arg0->type);
}

Expression *eval_yl2xp1(Loc loc, FuncDeclaration *fd, Expressions *arguments)
{
    Expression *arg0 = (*arguments)[0];
    assert(arg0->op == TOKfloat64);
    Expression *arg1 = (*arguments)[1];
    assert(arg1->op == TOKfloat64);
    longdouble x = arg0->toReal();
    longdouble y = arg1->toReal();
    longdouble result;
    Port::yl2xp1_impl(&x, &y, &result);
    return new RealExp(loc, result, arg0->type);
}

void builtin_init()
{
    builtins._init(47);

    // @safe @nogc pure nothrow real function(real)
    add_builtin("_D4core4math3sinFNaNbNiNfeZe", &eval_sin);
    add_builtin("_D4core4math3cosFNaNbNiNfeZe", &eval_cos);
    add_builtin("_D4core4math3tanFNaNbNiNfeZe", &eval_tan);
    add_builtin("_D4core4math4sqrtFNaNbNiNfeZe", &eval_sqrt);
    add_builtin("_D4core4math4fabsFNaNbNiNfeZe", &eval_fabs);
    add_builtin("_D4core4math5expm1FNaNbNiNfeZe", &eval_unimp);
    add_builtin("_D4core4math4exp21FNaNbNiNfeZe", &eval_unimp);

    // @trusted @nogc pure nothrow real function(real)
    add_builtin("_D4core4math3sinFNaNbNiNeeZe", &eval_sin);
    add_builtin("_D4core4math3cosFNaNbNiNeeZe", &eval_cos);
    add_builtin("_D4core4math3tanFNaNbNiNeeZe", &eval_tan);
    add_builtin("_D4core4math4sqrtFNaNbNiNeeZe", &eval_sqrt);
    add_builtin("_D4core4math4fabsFNaNbNiNeeZe", &eval_fabs);
    add_builtin("_D4core4math5expm1FNaNbNiNeeZe", &eval_unimp);
    add_builtin("_D4core4math4exp21FNaNbNiNeeZe", &eval_unimp);

    // @safe @nogc pure nothrow double function(double)
    add_builtin("_D4core4math4sqrtFNaNbNiNfdZd", &eval_sqrt);
    // @safe @nogc pure nothrow float function(float)
    add_builtin("_D4core4math4sqrtFNaNbNiNffZf", &eval_sqrt);

    // @safe @nogc pure nothrow real function(real, real)
    add_builtin("_D4core4math5atan2FNaNbNiNfeeZe", &eval_unimp);

    if (Port::yl2x_supported)
    {
        add_builtin("_D4core4math4yl2xFNaNbNiNfeeZe", &eval_yl2x);
    }
    else
    {
        add_builtin("_D4core4math4yl2xFNaNbNiNfeeZe", &eval_unimp);
    }

    if (Port::yl2xp1_supported)
    {
        add_builtin("_D4core4math6yl2xp1FNaNbNiNfeeZe", &eval_yl2xp1);
    }
    else
    {
        add_builtin("_D4core4math6yl2xp1FNaNbNiNfeeZe", &eval_unimp);
    }

    // @safe @nogc pure nothrow long function(real)
    add_builtin("_D4core4math6rndtolFNaNbNiNfeZl", &eval_unimp);

    // @safe @nogc pure nothrow real function(real)
    add_builtin("_D3std4math3sinFNaNbNiNfeZe", &eval_sin);
    add_builtin("_D3std4math3cosFNaNbNiNfeZe", &eval_cos);
    add_builtin("_D3std4math3tanFNaNbNiNfeZe", &eval_tan);
    add_builtin("_D3std4math4sqrtFNaNbNiNfeZe", &eval_sqrt);
    add_builtin("_D3std4math4fabsFNaNbNiNfeZe", &eval_fabs);
    add_builtin("_D3std4math5expm1FNaNbNiNfeZe", &eval_unimp);
    add_builtin("_D3std4math4exp21FNaNbNiNfeZe", &eval_unimp);

    // @trusted @nogc pure nothrow real function(real)
    add_builtin("_D3std4math3sinFNaNbNiNeeZe", &eval_sin);
    add_builtin("_D3std4math3cosFNaNbNiNeeZe", &eval_cos);
    add_builtin("_D3std4math3tanFNaNbNiNeeZe", &eval_tan);
    add_builtin("_D3std4math4sqrtFNaNbNiNeeZe", &eval_sqrt);
    add_builtin("_D3std4math4fabsFNaNbNiNeeZe", &eval_fabs);
    add_builtin("_D3std4math5expm1FNaNbNiNeeZe", &eval_unimp);
    add_builtin("_D3std4math4exp21FNaNbNiNeeZe", &eval_unimp);

    // @safe @nogc pure nothrow double function(double)
    add_builtin("_D3std4math4sqrtFNaNbNiNfdZd", &eval_sqrt);
    // @safe @nogc pure nothrow float function(float)
    add_builtin("_D3std4math4sqrtFNaNbNiNffZf", &eval_sqrt);

    // @safe @nogc pure nothrow real function(real, real)
    add_builtin("_D3std4math5atan2FNaNbNiNfeeZe", &eval_unimp);

    if (Port::yl2x_supported)
    {
        add_builtin("_D3std4math4yl2xFNaNbNiNfeeZe", &eval_yl2x);
    }
    else
    {
        add_builtin("_D3std4math4yl2xFNaNbNiNfeeZe", &eval_unimp);
    }

    if (Port::yl2xp1_supported)
    {
        add_builtin("_D3std4math6yl2xp1FNaNbNiNfeeZe", &eval_yl2xp1);
    }
    else
    {
        add_builtin("_D3std4math6yl2xp1FNaNbNiNfeeZe", &eval_unimp);
    }

    // @safe @nogc pure nothrow long function(real)
    add_builtin("_D3std4math6rndtolFNaNbNiNfeZl", &eval_unimp);

    // @safe @nogc pure nothrow int function(uint)
    add_builtin("_D4core5bitop3bsfFNaNbNiNfkZi", &eval_bsf);
    add_builtin("_D4core5bitop3bsrFNaNbNiNfkZi", &eval_bsr);

    // @safe @nogc pure nothrow int function(ulong)
    add_builtin("_D4core5bitop3bsfFNaNbNiNfmZi", &eval_bsf);
    add_builtin("_D4core5bitop3bsrFNaNbNiNfmZi", &eval_bsr);

    // @safe @nogc pure nothrow uint function(uint)
    add_builtin("_D4core5bitop5bswapFNaNbNiNfkZk", &eval_bswap);

    // @safe @nogc pure nothrow int function(uint)
    add_builtin("_D4core5bitop7_popcntFNaNbNiNfkZi", &eval_popcnt);

    // @safe @nogc pure nothrow ushort function(ushort)
    add_builtin("_D4core5bitop7_popcntFNaNbNiNftZt", &eval_popcnt);

    // @safe @nogc pure nothrow int function(ulong)
    if (global.params.is64bit)
        add_builtin("_D4core5bitop7_popcntFNaNbNiNfmZi", &eval_popcnt);
}

/**********************************
 * Determine if function is a builtin one that we can
 * evaluate at compile time.
 */
BUILTIN isBuiltin(FuncDeclaration *fd)
{
    if (fd->builtin == BUILTINunknown)
    {
        builtin_fp fp = builtin_lookup(mangleExact(fd));
        fd->builtin = fp ? BUILTINyes : BUILTINno;
    }
    return fd->builtin;
}

/**************************************
 * Evaluate builtin function.
 * Return result; NULL if cannot evaluate it.
 */

Expression *eval_builtin(Loc loc, FuncDeclaration *fd, Expressions *arguments)
{
    if (fd->builtin == BUILTINyes)
    {
        builtin_fp fp = builtin_lookup(mangleExact(fd));
        assert(fp);
        return fp(loc, fd, arguments);
    }
    return NULL;
}
