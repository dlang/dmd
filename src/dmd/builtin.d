/**
 * Implement CTFE for intrinsic (builtin) functions.
 *
 * Currently includes functions from `std.math`, `core.math` and `core.bitop`.
 *
 * Copyright:   Copyright (C) 1999-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/builtin.d, _builtin.d)
 * Documentation:  https://dlang.org/phobos/dmd_builtin.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/builtin.d
 */

module dmd.builtin;

import core.stdc.math;
import core.stdc.string;

import dmd.arraytypes;
import dmd.astenums;
import dmd.dmangle;
import dmd.errors;
import dmd.expression;
import dmd.func;
import dmd.globals;
import dmd.mtype;
import dmd.root.ctfloat;
import dmd.root.stringtable;
import dmd.tokens;
import dmd.id;
static import core.bitop;

/**********************************
 * Determine if function is a builtin one that we can
 * evaluate at compile time.
 */
public extern (C++) BUILTIN isBuiltin(FuncDeclaration fd)
{
    if (fd.builtin == BUILTIN.unknown)
    {
        fd.builtin = determine_builtin(fd);
    }
    return fd.builtin;
}

/**************************************
 * Evaluate builtin function.
 * Return result; NULL if cannot evaluate it.
 */
public extern (C++) Expression eval_builtin(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    if (fd.builtin == BUILTIN.unimp)
        return null;

    switch (fd.builtin)
    {
        foreach(e; __traits(allMembers, BUILTIN))
        {
            static if (e == "unknown")
                case BUILTIN.unknown: assert(false);
            else
                mixin("case BUILTIN."~e~": return eval_"~e~"(loc, fd, arguments);");
        }
        default: assert(0);
    }
}

private:

/**
 * Handler for evaluating builtins during CTFE.
 *
 * Params:
 *  loc = The call location, for error reporting.
 *  fd = The callee declaration, e.g. to disambiguate between different overloads
 *       in a single handler (LDC).
 *  arguments = The function call arguments.
 * Returns:
 *  An Expression containing the return value of the call.
 */

BUILTIN determine_builtin(FuncDeclaration func)
{
    auto fd = func.toAliasFunc();
    if (fd.isDeprecated())
        return BUILTIN.unimp;
    auto m = fd.getModule();
    if (!m || !m.md)
        return BUILTIN.unimp;
    const md = m.md;

    // Look for core.math, core.bitop, std.math, and std.math.<package>
    const id2 = (md.packages.length == 2) ? md.packages[1] : md.id;
    if (id2 != Id.math && id2 != Id.bitop)
        return BUILTIN.unimp;

    if (md.packages.length != 1 && !(md.packages.length == 2 && id2 == Id.math))
        return BUILTIN.unimp;

    const id1 = md.packages[0];
    if (id1 != Id.core && id1 != Id.std)
        return BUILTIN.unimp;
    const id3 = fd.ident;

    if (id1 == Id.core && id2 == Id.bitop)
    {
        if (id3 == Id.bsf)     return BUILTIN.bsf;
        if (id3 == Id.bsr)     return BUILTIN.bsr;
        if (id3 == Id.bswap)   return BUILTIN.bswap;
        if (id3 == Id._popcnt) return BUILTIN.popcnt;
        return BUILTIN.unimp;
    }

    // Math
    if (id3 == Id.sin)   return BUILTIN.sin;
    if (id3 == Id.cos)   return BUILTIN.cos;
    if (id3 == Id.tan)   return BUILTIN.tan;
    if (id3 == Id.atan2) return BUILTIN.unimp; // N.B unimplmeneted

    if (id3 == Id._sqrt) return BUILTIN.sqrt;
    if (id3 == Id.fabs)  return BUILTIN.fabs;

    if (id3 == Id.exp)    return BUILTIN.exp;
    if (id3 == Id.expm1)  return BUILTIN.expm1;
    if (id3 == Id.exp2)   return BUILTIN.exp2;
    if (id3 == Id.yl2x)   return CTFloat.yl2x_supported ? BUILTIN.yl2x : BUILTIN.unimp;
    if (id3 == Id.yl2xp1) return CTFloat.yl2xp1_supported ? BUILTIN.yl2xp1 : BUILTIN.unimp;

    if (id3 == Id.log)   return BUILTIN.log;
    if (id3 == Id.log2)  return BUILTIN.log2;
    if (id3 == Id.log10) return BUILTIN.log10;

    if (id3 == Id.ldexp) return BUILTIN.ldexp;
    if (id3 == Id.round) return BUILTIN.round;
    if (id3 == Id.floor) return BUILTIN.floor;
    if (id3 == Id.ceil)  return BUILTIN.ceil;
    if (id3 == Id.trunc) return BUILTIN.trunc;

    if (id3 == Id.fmin)     return BUILTIN.fmin;
    if (id3 == Id.fmax)     return BUILTIN.fmax;
    if (id3 == Id.fma)      return BUILTIN.fma;
    if (id3 == Id.copysign) return BUILTIN.copysign;

    if (id3 == Id.isnan)      return BUILTIN.isnan;
    if (id3 == Id.isInfinity) return BUILTIN.isinfinity;
    if (id3 == Id.isfinite)   return BUILTIN.isfinite;

    // Only match pow(fp,fp) where fp is a floating point type
    if (id3 == Id._pow)
    {
        if ((*fd.parameters)[0].type.isfloating() &&
            (*fd.parameters)[1].type.isfloating())
            return BUILTIN.pow;
        return BUILTIN.unimp;
    }

    if (id3 != Id.toPrec)
        return BUILTIN.unimp;
    const(char)* me = mangleExact(fd);
    final switch (me["_D4core4math__T6toPrecHT".length])
    {
        case 'd': return BUILTIN.toPrecDouble;
        case 'e': return BUILTIN.toPrecReal;
        case 'f': return BUILTIN.toPrecFloat;
    }
}

Expression eval_unimp(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    return null;
}

Expression eval_sin(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOK.float64);
    return new RealExp(loc, CTFloat.sin(arg0.toReal()), arg0.type);
}

Expression eval_cos(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOK.float64);
    return new RealExp(loc, CTFloat.cos(arg0.toReal()), arg0.type);
}

Expression eval_tan(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOK.float64);
    return new RealExp(loc, CTFloat.tan(arg0.toReal()), arg0.type);
}

Expression eval_sqrt(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOK.float64);
    return new RealExp(loc, CTFloat.sqrt(arg0.toReal()), arg0.type);
}

Expression eval_fabs(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOK.float64);
    return new RealExp(loc, CTFloat.fabs(arg0.toReal()), arg0.type);
}

Expression eval_ldexp(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOK.float64);
    Expression arg1 = (*arguments)[1];
    assert(arg1.op == TOK.int64);
    return new RealExp(loc, CTFloat.ldexp(arg0.toReal(), cast(int) arg1.toInteger()), arg0.type);
}

Expression eval_log(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOK.float64);
    return new RealExp(loc, CTFloat.log(arg0.toReal()), arg0.type);
}

Expression eval_log2(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOK.float64);
    return new RealExp(loc, CTFloat.log2(arg0.toReal()), arg0.type);
}

Expression eval_log10(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOK.float64);
    return new RealExp(loc, CTFloat.log10(arg0.toReal()), arg0.type);
}

Expression eval_exp(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOK.float64);
    return new RealExp(loc, CTFloat.exp(arg0.toReal()), arg0.type);
}

Expression eval_expm1(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOK.float64);
    return new RealExp(loc, CTFloat.expm1(arg0.toReal()), arg0.type);
}

Expression eval_exp2(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOK.float64);
    return new RealExp(loc, CTFloat.exp2(arg0.toReal()), arg0.type);
}

Expression eval_round(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOK.float64);
    return new RealExp(loc, CTFloat.round(arg0.toReal()), arg0.type);
}

Expression eval_floor(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOK.float64);
    return new RealExp(loc, CTFloat.floor(arg0.toReal()), arg0.type);
}

Expression eval_ceil(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOK.float64);
    return new RealExp(loc, CTFloat.ceil(arg0.toReal()), arg0.type);
}

Expression eval_trunc(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOK.float64);
    return new RealExp(loc, CTFloat.trunc(arg0.toReal()), arg0.type);
}

Expression eval_copysign(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOK.float64);
    Expression arg1 = (*arguments)[1];
    assert(arg1.op == TOK.float64);
    return new RealExp(loc, CTFloat.copysign(arg0.toReal(), arg1.toReal()), arg0.type);
}

Expression eval_pow(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOK.float64);
    Expression arg1 = (*arguments)[1];
    assert(arg1.op == TOK.float64);
    return new RealExp(loc, CTFloat.pow(arg0.toReal(), arg1.toReal()), arg0.type);
}

Expression eval_fmin(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOK.float64);
    Expression arg1 = (*arguments)[1];
    assert(arg1.op == TOK.float64);
    return new RealExp(loc, CTFloat.fmin(arg0.toReal(), arg1.toReal()), arg0.type);
}

Expression eval_fmax(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOK.float64);
    Expression arg1 = (*arguments)[1];
    assert(arg1.op == TOK.float64);
    return new RealExp(loc, CTFloat.fmax(arg0.toReal(), arg1.toReal()), arg0.type);
}

Expression eval_fma(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOK.float64);
    Expression arg1 = (*arguments)[1];
    assert(arg1.op == TOK.float64);
    Expression arg2 = (*arguments)[2];
    assert(arg2.op == TOK.float64);
    return new RealExp(loc, CTFloat.fma(arg0.toReal(), arg1.toReal(), arg2.toReal()), arg0.type);
}

Expression eval_isnan(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOK.float64);
    return IntegerExp.createBool(CTFloat.isNaN(arg0.toReal()));
}

Expression eval_isinfinity(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOK.float64);
    return IntegerExp.createBool(CTFloat.isInfinity(arg0.toReal()));
}

Expression eval_isfinite(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOK.float64);
    const value = !CTFloat.isNaN(arg0.toReal()) && !CTFloat.isInfinity(arg0.toReal());
    return IntegerExp.createBool(value);
}

Expression eval_bsf(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOK.int64);
    uinteger_t n = arg0.toInteger();
    if (n == 0)
        error(loc, "`bsf(0)` is undefined");
    return new IntegerExp(loc, core.bitop.bsf(n), Type.tint32);
}

Expression eval_bsr(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOK.int64);
    uinteger_t n = arg0.toInteger();
    if (n == 0)
        error(loc, "`bsr(0)` is undefined");
    return new IntegerExp(loc, core.bitop.bsr(n), Type.tint32);
}

Expression eval_bswap(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOK.int64);
    uinteger_t n = arg0.toInteger();
    TY ty = arg0.type.toBasetype().ty;
    if (ty == Tint64 || ty == Tuns64)
        return new IntegerExp(loc, core.bitop.bswap(cast(ulong) n), arg0.type);
    else
        return new IntegerExp(loc, core.bitop.bswap(cast(uint) n), arg0.type);
}

Expression eval_popcnt(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOK.int64);
    uinteger_t n = arg0.toInteger();
    return new IntegerExp(loc, core.bitop.popcnt(n), Type.tint32);
}

Expression eval_yl2x(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOK.float64);
    Expression arg1 = (*arguments)[1];
    assert(arg1.op == TOK.float64);
    const x = arg0.toReal();
    const y = arg1.toReal();
    real_t result = CTFloat.zero;
    CTFloat.yl2x(&x, &y, &result);
    return new RealExp(loc, result, arg0.type);
}

Expression eval_yl2xp1(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOK.float64);
    Expression arg1 = (*arguments)[1];
    assert(arg1.op == TOK.float64);
    const x = arg0.toReal();
    const y = arg1.toReal();
    real_t result = CTFloat.zero;
    CTFloat.yl2xp1(&x, &y, &result);
    return new RealExp(loc, result, arg0.type);
}

Expression eval_toPrecFloat(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    float f = cast(real)arg0.toReal();
    return new RealExp(loc, real_t(f), Type.tfloat32);
}

Expression eval_toPrecDouble(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    double d = cast(real)arg0.toReal();
    return new RealExp(loc, real_t(d), Type.tfloat64);
}

Expression eval_toPrecReal(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    return new RealExp(loc, arg0.toReal(), Type.tfloat80);
}

// These built-ins are reserved for GDC and LDC.
Expression eval_gcc(Loc, FuncDeclaration, Expressions*)
{
    assert(0);
}

Expression eval_llvm(Loc, FuncDeclaration, Expressions*)
{
    assert(0);
}
