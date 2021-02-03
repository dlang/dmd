
/* Compiler implementation of the D programming language
 * Copyright (C) 1999-2020 by The D Language Foundation, All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/builtin.c
 */

#include "root/dsystem.h"               // strcmp()

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
#include "tokens.h"
#include "mangle.h"

Expression *eval_unimp(Loc, FuncDeclaration *, Expressions *)
{
    return NULL;
}

Expression *eval_sin(Loc loc, FuncDeclaration *, Expressions *arguments)
{
    Expression *arg0 = (*arguments)[0];
    assert(arg0->op == TOKfloat64);
    return new RealExp(loc, CTFloat::sin(arg0->toReal()), arg0->type);
}

Expression *eval_cos(Loc loc, FuncDeclaration *, Expressions *arguments)
{
    Expression *arg0 = (*arguments)[0];
    assert(arg0->op == TOKfloat64);
    return new RealExp(loc, CTFloat::cos(arg0->toReal()), arg0->type);
}

Expression *eval_tan(Loc loc, FuncDeclaration *, Expressions *arguments)
{
    Expression *arg0 = (*arguments)[0];
    assert(arg0->op == TOKfloat64);
    return new RealExp(loc, CTFloat::tan(arg0->toReal()), arg0->type);
}

Expression *eval_sqrt(Loc loc, FuncDeclaration *, Expressions *arguments)
{
    Expression *arg0 = (*arguments)[0];
    assert(arg0->op == TOKfloat64);
    return new RealExp(loc, CTFloat::sqrt(arg0->toReal()), arg0->type);
}

Expression *eval_fabs(Loc loc, FuncDeclaration *, Expressions *arguments)
{
    Expression *arg0 = (*arguments)[0];
    assert(arg0->op == TOKfloat64);
    return new RealExp(loc, CTFloat::fabs(arg0->toReal()), arg0->type);
}

Expression *eval_ldexp(Loc loc, FuncDeclaration *, Expressions *arguments)
{
    Expression *arg0 = (*arguments)[0];
    assert(arg0->op == TOKfloat64);
    Expression *arg1 = (*arguments)[1];
    assert(arg1->op == TOKint64);
    return new RealExp(loc, CTFloat::ldexp(arg0->toReal(), (int)  arg1->toInteger()), arg0->type);
}

Expression *eval_log(Loc loc, FuncDeclaration *, Expressions *arguments)
{
    Expression *arg0 = (*arguments)[0];
    assert(arg0->op == TOKfloat64);
    return new RealExp(loc, CTFloat::log(arg0->toReal()), arg0->type);
}

Expression *eval_log2(Loc loc, FuncDeclaration *, Expressions *arguments)
{
    Expression *arg0 = (*arguments)[0];
    assert(arg0->op == TOKfloat64);
    return new RealExp(loc, CTFloat::log2(arg0->toReal()), arg0->type);
}

Expression *eval_log10(Loc loc, FuncDeclaration *, Expressions *arguments)
{
    Expression *arg0 = (*arguments)[0];
    assert(arg0->op == TOKfloat64);
    return new RealExp(loc, CTFloat::log10(arg0->toReal()), arg0->type);
}

Expression *eval_exp(Loc loc, FuncDeclaration *, Expressions *arguments)
{
    Expression *arg0 = (*arguments)[0];
    assert(arg0->op == TOKfloat64);
    return new RealExp(loc, CTFloat::exp(arg0->toReal()), arg0->type);
}

Expression *eval_expm1(Loc loc, FuncDeclaration *, Expressions *arguments)
{
    Expression *arg0 = (*arguments)[0];
    assert(arg0->op == TOKfloat64);
    return new RealExp(loc, CTFloat::expm1(arg0->toReal()), arg0->type);
}

Expression *eval_exp2(Loc loc, FuncDeclaration *, Expressions *arguments)
{
    Expression *arg0 = (*arguments)[0];
    assert(arg0->op == TOKfloat64);
    return new RealExp(loc, CTFloat::exp2(arg0->toReal()), arg0->type);
}

Expression *eval_round(Loc loc, FuncDeclaration *, Expressions *arguments)
{
    Expression *arg0 = (*arguments)[0];
    assert(arg0->op == TOKfloat64);
    return new RealExp(loc, CTFloat::round(arg0->toReal()), arg0->type);
}

Expression *eval_floor(Loc loc, FuncDeclaration *, Expressions *arguments)
{
    Expression *arg0 = (*arguments)[0];
    assert(arg0->op == TOKfloat64);
    return new RealExp(loc, CTFloat::floor(arg0->toReal()), arg0->type);
}

Expression *eval_ceil(Loc loc, FuncDeclaration *, Expressions *arguments)
{
    Expression *arg0 = (*arguments)[0];
    assert(arg0->op == TOKfloat64);
    return new RealExp(loc, CTFloat::ceil(arg0->toReal()), arg0->type);
}

Expression *eval_trunc(Loc loc, FuncDeclaration *, Expressions *arguments)
{
    Expression *arg0 = (*arguments)[0];
    assert(arg0->op == TOKfloat64);
    return new RealExp(loc, CTFloat::trunc(arg0->toReal()), arg0->type);
}

Expression *eval_copysign(Loc loc, FuncDeclaration *, Expressions *arguments)
{
    Expression *arg0 = (*arguments)[0];
    assert(arg0->op == TOKfloat64);
    Expression *arg1 = (*arguments)[1];
    assert(arg1->op == TOKfloat64);
    return new RealExp(loc, CTFloat::copysign(arg0->toReal(), arg1->toReal()), arg0->type);
}

Expression *eval_pow(Loc loc, FuncDeclaration *, Expressions *arguments)
{
    Expression *arg0 = (*arguments)[0];
    assert(arg0->op == TOKfloat64);
    Expression *arg1 = (*arguments)[1];
    assert(arg1->op == TOKfloat64);
    return new RealExp(loc, CTFloat::pow(arg0->toReal(), arg1->toReal()), arg0->type);
}

Expression *eval_fmin(Loc loc, FuncDeclaration *, Expressions *arguments)
{
    Expression *arg0 = (*arguments)[0];
    assert(arg0->op == TOKfloat64);
    Expression *arg1 = (*arguments)[1];
    assert(arg1->op == TOKfloat64);
    return new RealExp(loc, CTFloat::fmin(arg0->toReal(), arg1->toReal()), arg0->type);
}

Expression *eval_fmax(Loc loc, FuncDeclaration *, Expressions *arguments)
{
    Expression *arg0 = (*arguments)[0];
    assert(arg0->op == TOKfloat64);
    Expression *arg1 = (*arguments)[1];
    assert(arg1->op == TOKfloat64);
    return new RealExp(loc, CTFloat::fmax(arg0->toReal(), arg1->toReal()), arg0->type);
}

Expression *eval_fma(Loc loc, FuncDeclaration *, Expressions *arguments)
{
    Expression *arg0 = (*arguments)[0];
    assert(arg0->op == TOKfloat64);
    Expression *arg1 = (*arguments)[1];
    assert(arg1->op == TOKfloat64);
    Expression *arg2 = (*arguments)[2];
    assert(arg2->op == TOKfloat64);
    return new RealExp(loc, CTFloat::fma(arg0->toReal(), arg1->toReal(), arg2->toReal()), arg0->type);
}

Expression *eval_isnan(Loc loc, FuncDeclaration *, Expressions *arguments)
{
    Expression *arg0 = (*arguments)[0];
    assert(arg0->op == TOKfloat64);
    return new IntegerExp(loc, CTFloat::isNaN(arg0->toReal()), Type::tbool);
}

Expression *eval_isinfinity(Loc loc, FuncDeclaration *, Expressions *arguments)
{
    Expression *arg0 = (*arguments)[0];
    assert(arg0->op == TOKfloat64);
    return new IntegerExp(loc, CTFloat::isInfinity(arg0->toReal()), Type::tbool);
}

Expression *eval_isfinite(Loc loc, FuncDeclaration *, Expressions *arguments)
{
    Expression *arg0 = (*arguments)[0];
    assert(arg0->op == TOKfloat64);
    const bool value = !CTFloat::isNaN(arg0->toReal()) && !CTFloat::isInfinity(arg0->toReal());
    return new IntegerExp(loc, value, Type::tbool);
}

Expression *eval_bsf(Loc loc, FuncDeclaration *, Expressions *arguments)
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

Expression *eval_bsr(Loc loc, FuncDeclaration *, Expressions *arguments)
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

Expression *eval_bswap(Loc loc, FuncDeclaration *, Expressions *arguments)
{
    Expression *arg0 = (*arguments)[0];
    assert(arg0->op == TOKint64);
    uinteger_t n = arg0->toInteger();
    #define BYTEMASK  0x00FF00FF00FF00FFLL
    #define SHORTMASK 0x0000FFFF0000FFFFLL
    #define INTMASK 0x00000000FFFFFFFFLL
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

Expression *eval_popcnt(Loc loc, FuncDeclaration *, Expressions *arguments)
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

Expression *eval_yl2x(Loc loc, FuncDeclaration *, Expressions *arguments)
{
    Expression *arg0 = (*arguments)[0];
    assert(arg0->op == TOKfloat64);
    Expression *arg1 = (*arguments)[1];
    assert(arg1->op == TOKfloat64);
    longdouble x = arg0->toReal();
    longdouble y = arg1->toReal();
    longdouble result;
    CTFloat::yl2x(&x, &y, &result);
    return new RealExp(loc, result, arg0->type);
}

Expression *eval_yl2xp1(Loc loc, FuncDeclaration *, Expressions *arguments)
{
    Expression *arg0 = (*arguments)[0];
    assert(arg0->op == TOKfloat64);
    Expression *arg1 = (*arguments)[1];
    assert(arg1->op == TOKfloat64);
    longdouble x = arg0->toReal();
    longdouble y = arg1->toReal();
    longdouble result;
    CTFloat::yl2xp1(&x, &y, &result);
    return new RealExp(loc, result, arg0->type);
}

Expression *eval_toPrecFloat(Loc loc, FuncDeclaration *, Expressions *arguments)
{
    Expression *arg0 = (*arguments)[0];
    float f = (long double)arg0->toReal();
    return new RealExp(loc, real_t(f), Type::tfloat32);
}

Expression *eval_toPrecDouble(Loc loc, FuncDeclaration *, Expressions *arguments)
{
    Expression *arg0 = (*arguments)[0];
    double d = (long double)arg0->toReal();
    return new RealExp(loc, real_t(d), Type::tfloat64);
}

Expression *eval_toPrecReal(Loc loc, FuncDeclaration *, Expressions *arguments)
{
    Expression *arg0 = (*arguments)[0];
    return new RealExp(loc, arg0->toReal(), Type::tfloat80);
}

BUILTIN determine_builtin(FuncDeclaration *func)
{
    FuncDeclaration *fd = func->toAliasFunc();
    if (fd->isDeprecated())
        return BUILTINunimp;
    Module *m = fd->getModule();
    if (!m || !m->md)
        return BUILTINunimp;
    const ModuleDeclaration *md = m->md;
    const Identifier *id2 = md->id;

    // Look for core.math, core.bitop and std.math
    if (id2 != Id::math && id2 != Id::bitop)
        return BUILTINunimp;

    if (!md->packages)
        return BUILTINunimp;
    if (md->packages->length != 1)
        return BUILTINunimp;

    const Identifier *id1 = (*md->packages)[0];
    if (id1 != Id::core && id1 != Id::std)
        return BUILTINunimp;
    const Identifier *id3 = fd->ident;

    if (id1 == Id::core && id2 == Id::bitop)
    {
        if (id3 == Id::bsf)     return BUILTINbsf;
        if (id3 == Id::bsr)     return BUILTINbsr;
        if (id3 == Id::bswap)   return BUILTINbswap;
        if (id3 == Id::_popcnt) return BUILTINpopcnt;
        return BUILTINunimp;
    }

    // Math
    if (id3 == Id::sin)   return BUILTINsin;
    if (id3 == Id::cos)   return BUILTINcos;
    if (id3 == Id::tan)   return BUILTINtan;
    if (id3 == Id::atan2) return BUILTINunimp; // N.B unimplmeneted

    if (id3 == Id::_sqrt) return BUILTINsqrt;
    if (id3 == Id::fabs)  return BUILTINfabs;

    if (id3 == Id::exp)    return BUILTINexp;
    if (id3 == Id::expm1)  return BUILTINexpm1;
    if (id3 == Id::exp2)   return BUILTINexp2;
    if (id3 == Id::yl2x)   return CTFloat::yl2x_supported ? BUILTINyl2x : BUILTINunimp;
    if (id3 == Id::yl2xp1) return CTFloat::yl2xp1_supported ? BUILTINyl2xp1 : BUILTINunimp;

    if (id3 == Id::log)   return BUILTINlog;
    if (id3 == Id::log2)  return BUILTINlog2;
    if (id3 == Id::log10) return BUILTINlog10;

    if (id3 == Id::ldexp) return BUILTINldexp;
    if (id3 == Id::round) return BUILTINround;
    if (id3 == Id::floor) return BUILTINfloor;
    if (id3 == Id::ceil)  return BUILTINceil;
    if (id3 == Id::trunc) return BUILTINtrunc;

    if (id3 == Id::fmin)     return BUILTINfmin;
    if (id3 == Id::fmax)     return BUILTINfmax;
    if (id3 == Id::fma)      return BUILTINfma;
    if (id3 == Id::copysign) return BUILTINcopysign;

    if (id3 == Id::isnan)      return BUILTINisnan;
    if (id3 == Id::isInfinity) return BUILTINisinfinity;
    if (id3 == Id::isfinite)   return BUILTINisfinite;

    // Only match pow(fp,fp) where fp is a floating point type
    if (id3 == Id::_pow)
    {
        if ((*fd->parameters)[0]->type->isfloating() &&
            (*fd->parameters)[1]->type->isfloating())
            return BUILTINpow;
        return BUILTINunimp;
    }

    if (id3 != Id::toPrec)
        return BUILTINunimp;

    const char *me = mangleExact(fd);
    switch (me[strlen("_D4core4math__T6toPrecHT")])
    {
        case 'd': return BUILTINtoPrecDouble;
        case 'e': return BUILTINtoPrecReal;
        case 'f': return BUILTINtoPrecFloat;
        default:  assert(false);
    }
}

/**********************************
 * Determine if function is a builtin one that we can
 * evaluate at compile time.
 */
BUILTIN isBuiltin(FuncDeclaration *fd)
{
    if (fd->builtin == BUILTINunknown)
    {
        fd->builtin = determine_builtin(fd);
    }
    return fd->builtin;
}

/**************************************
 * Evaluate builtin function.
 * Return result; NULL if cannot evaluate it.
 */

Expression *eval_builtin(Loc loc, FuncDeclaration *fd, Expressions *arguments)
{
    switch (fd->builtin)
    {
        case BUILTINunknown:      assert(false);
        case BUILTINunimp:        return eval_unimp(loc, fd, arguments);
        case BUILTINgcc:          return eval_unimp(loc, fd, arguments);
        case BUILTINllvm:         return eval_unimp(loc, fd, arguments);
        case BUILTINsin:          return eval_sin(loc, fd, arguments);
        case BUILTINcos:          return eval_cos(loc, fd, arguments);
        case BUILTINtan:          return eval_tan(loc, fd, arguments);
        case BUILTINsqrt:         return eval_sqrt(loc, fd, arguments);
        case BUILTINfabs:         return eval_fabs(loc, fd, arguments);
        case BUILTINldexp:        return eval_ldexp(loc, fd, arguments);
        case BUILTINlog:          return eval_log(loc, fd, arguments);
        case BUILTINlog2:         return eval_log2(loc, fd, arguments);
        case BUILTINlog10:        return eval_log10(loc, fd, arguments);
        case BUILTINexp:          return eval_exp(loc, fd, arguments);
        case BUILTINexpm1:        return eval_expm1(loc, fd, arguments);
        case BUILTINexp2:         return eval_exp2(loc, fd, arguments);
        case BUILTINround:        return eval_round(loc, fd, arguments);
        case BUILTINfloor:        return eval_floor(loc, fd, arguments);
        case BUILTINceil:         return eval_ceil(loc, fd, arguments);
        case BUILTINtrunc:        return eval_trunc(loc, fd, arguments);
        case BUILTINcopysign:     return eval_copysign(loc, fd, arguments);
        case BUILTINpow:          return eval_pow(loc, fd, arguments);
        case BUILTINfmin:         return eval_fmin(loc, fd, arguments);
        case BUILTINfmax:         return eval_fmax(loc, fd, arguments);
        case BUILTINfma:          return eval_fma(loc, fd, arguments);
        case BUILTINisnan:        return eval_isnan(loc, fd, arguments);
        case BUILTINisinfinity:   return eval_isinfinity(loc, fd, arguments);
        case BUILTINisfinite:     return eval_isfinite(loc, fd, arguments);
        case BUILTINbsf:          return eval_bsf(loc, fd, arguments);
        case BUILTINbsr:          return eval_bsr(loc, fd, arguments);
        case BUILTINbswap:        return eval_bswap(loc, fd, arguments);
        case BUILTINpopcnt:       return eval_popcnt(loc, fd, arguments);
        case BUILTINyl2x:         return eval_yl2x(loc, fd, arguments);
        case BUILTINyl2xp1:       return eval_yl2xp1(loc, fd, arguments);
        case BUILTINtoPrecFloat:  return eval_toPrecFloat(loc, fd, arguments);
        case BUILTINtoPrecDouble: return eval_toPrecDouble(loc, fd, arguments);
        case BUILTINtoPrecReal:   return eval_toPrecReal(loc, fd, arguments);
        default:                    assert(false);
    }
}
