/**
 * Implement CTFE for intrinsic (builtin) functions.
 *
 * Currently includes functions from `std.math`, `core.math` and `core.bitop`.
 *
 * Copyright:   Copyright (C) 1999-2020 by The D Language Foundation, All Rights Reserved
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
import dmd.dmangle;
import dmd.errors;
import dmd.expression;
import dmd.func;
import dmd.globals;
import dmd.mtype;
import dmd.root.ctfloat;
import dmd.root.stringtable;
import dmd.tokens;
static import core.bitop;

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
alias builtin_fp = Expression function(Loc loc, FuncDeclaration fd, Expressions* arguments);

__gshared StringTable!builtin_fp builtins;

void add_builtin(const(char)[] mangle, builtin_fp fp)
{
    builtins.insert(mangle, fp);
}

builtin_fp builtin_lookup(const(char)* mangle)
{
    if (const sv = builtins.lookup(mangle, strlen(mangle)))
        return sv.value;
    return null;
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

public extern (C++) void builtin_init()
{
    builtins._init(113);
    // @safe @nogc pure nothrow real function(real)
    add_builtin("_D4core4math3sinFNaNbNiNfeZe", &eval_sin);
    add_builtin("_D4core4math3cosFNaNbNiNfeZe", &eval_cos);
    add_builtin("_D4core4math3tanFNaNbNiNfeZe", &eval_tan);
    add_builtin("_D4core4math4sqrtFNaNbNiNfeZe", &eval_sqrt);
    add_builtin("_D4core4math4fabsFNaNbNiNfeZe", &eval_fabs);
    add_builtin("_D4core4math5expm1FNaNbNiNfeZe", &eval_unimp);
    add_builtin("_D4core4math4exp2FNaNbNiNfeZe", &eval_unimp);
    // @trusted @nogc pure nothrow real function(real)
    add_builtin("_D4core4math3sinFNaNbNiNeeZe", &eval_sin);
    add_builtin("_D4core4math3cosFNaNbNiNeeZe", &eval_cos);
    add_builtin("_D4core4math3tanFNaNbNiNeeZe", &eval_tan);
    add_builtin("_D4core4math4sqrtFNaNbNiNeeZe", &eval_sqrt);
    add_builtin("_D4core4math4fabsFNaNbNiNeeZe", &eval_fabs);
    add_builtin("_D4core4math5expm1FNaNbNiNeeZe", &eval_unimp);
    // @safe @nogc pure nothrow double function(double)
    add_builtin("_D4core4math4sqrtFNaNbNiNfdZd", &eval_sqrt);
    // @safe @nogc pure nothrow float function(float)
    add_builtin("_D4core4math4sqrtFNaNbNiNffZf", &eval_sqrt);
    // @safe @nogc pure nothrow real function(real, real)
    add_builtin("_D4core4math5atan2FNaNbNiNfeeZe", &eval_unimp);
    if (CTFloat.yl2x_supported)
    {
        add_builtin("_D4core4math4yl2xFNaNbNiNfeeZe", &eval_yl2x);
    }
    else
    {
        add_builtin("_D4core4math4yl2xFNaNbNiNfeeZe", &eval_unimp);
    }
    if (CTFloat.yl2xp1_supported)
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
    add_builtin("_D3std4math3tanFNaNbNiNfeZe", &eval_tan);
    add_builtin("_D3std4math4trig3tanFNaNbNiNfeZe", &eval_tan);
    add_builtin("_D3std4math5expm1FNaNbNiNfeZe", &eval_unimp);
    // @trusted @nogc pure nothrow real function(real)
    add_builtin("_D3std4math3tanFNaNbNiNeeZe", &eval_tan);
    add_builtin("_D3std4math4trig3tanFNaNbNiNeeZe", &eval_tan);
    add_builtin("_D3std4math3expFNaNbNiNeeZe", &eval_exp);
    add_builtin("_D3std4math5expm1FNaNbNiNeeZe", &eval_expm1);
    add_builtin("_D3std4math4exp2FNaNbNiNeeZe", &eval_exp2);
    // @safe @nogc pure nothrow real function(real, real)
    add_builtin("_D3std4math5atan2FNaNbNiNfeeZe", &eval_unimp);
    add_builtin("_D3std4math4trig5atan2FNaNbNiNfeeZe", &eval_unimp);
    // @safe @nogc pure nothrow T function(T, int)
    add_builtin("_D4core4math5ldexpFNaNbNiNfeiZe", &eval_ldexp);

    add_builtin("_D3std4math3logFNaNbNiNfeZe", &eval_log);

    add_builtin("_D3std4math4log2FNaNbNiNfeZe", &eval_log2);

    add_builtin("_D3std4math5log10FNaNbNiNfeZe", &eval_log10);

    add_builtin("_D3std4math5roundFNbNiNeeZe", &eval_round);
    add_builtin("_D3std4math5roundFNaNbNiNeeZe", &eval_round);

    add_builtin("_D3std4math5floorFNaNbNiNefZf", &eval_floor);
    add_builtin("_D3std4math5floorFNaNbNiNedZd", &eval_floor);
    add_builtin("_D3std4math5floorFNaNbNiNeeZe", &eval_floor);

    add_builtin("_D3std4math4ceilFNaNbNiNefZf", &eval_ceil);
    add_builtin("_D3std4math4ceilFNaNbNiNedZd", &eval_ceil);
    add_builtin("_D3std4math4ceilFNaNbNiNeeZe", &eval_ceil);

    add_builtin("_D3std4math5truncFNaNbNiNeeZe", &eval_trunc);

    add_builtin("_D3std4math4fminFNaNbNiNfeeZe", &eval_fmin);

    add_builtin("_D3std4math4fmaxFNaNbNiNfeeZe", &eval_fmax);

    add_builtin("_D3std4math__T8copysignTfTfZQoFNaNbNiNeffZf", &eval_copysign);
    add_builtin("_D3std4math__T8copysignTdTdZQoFNaNbNiNeddZd", &eval_copysign);
    add_builtin("_D3std4math__T8copysignTeTeZQoFNaNbNiNeeeZe", &eval_copysign);

    add_builtin("_D3std4math__T3powTfTfZQjFNaNbNiNeffZf", &eval_pow);
    add_builtin("_D3std4math__T3powTdTdZQjFNaNbNiNeddZd", &eval_pow);
    add_builtin("_D3std4math__T3powTeTeZQjFNaNbNiNeeeZe", &eval_pow);

    add_builtin("_D3std4math3fmaFNaNbNiNfeeeZe", &eval_fma);

    // @trusted @nogc pure nothrow bool function(T)
    add_builtin("_D3std4math__T5isNaNTeZQjFNaNbNiNeeZb", &eval_isnan);
    add_builtin("_D3std4math__T5isNaNTdZQjFNaNbNiNedZb", &eval_isnan);
    add_builtin("_D3std4math__T5isNaNTfZQjFNaNbNiNefZb", &eval_isnan);
    add_builtin("_D3std4math__T10isInfinityTeZQpFNaNbNiNeeZb", &eval_isinfinity);
    add_builtin("_D3std4math__T10isInfinityTdZQpFNaNbNiNedZb", &eval_isinfinity);
    add_builtin("_D3std4math__T10isInfinityTfZQpFNaNbNiNefZb", &eval_isinfinity);
    add_builtin("_D3std4math__T8isFiniteTeZQmFNaNbNiNeeZb", &eval_isfinite);
    add_builtin("_D3std4math__T8isFiniteTdZQmFNaNbNiNedZb", &eval_isfinite);
    add_builtin("_D3std4math__T8isFiniteTfZQmFNaNbNiNefZb", &eval_isfinite);

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

    // pure nothrow @nogc @safe float core.math.toPrec!(float).toPrec(float)
    add_builtin("_D4core4math__T6toPrecHTfZQlFNaNbNiNffZf", &eval_toPrecFloat);
    // pure nothrow @nogc @safe float core.math.toPrec!(float).toPrec(double)
    add_builtin("_D4core4math__T6toPrecHTfZQlFNaNbNiNfdZf", &eval_toPrecFloat);
    // pure nothrow @nogc @safe float core.math.toPrec!(float).toPrec(real)
    add_builtin("_D4core4math__T6toPrecHTfZQlFNaNbNiNfeZf", &eval_toPrecFloat);
    // pure nothrow @nogc @safe double core.math.toPrec!(double).toPrec(float)
    add_builtin("_D4core4math__T6toPrecHTdZQlFNaNbNiNffZd", &eval_toPrecDouble);
    // pure nothrow @nogc @safe double core.math.toPrec!(double).toPrec(double)
    add_builtin("_D4core4math__T6toPrecHTdZQlFNaNbNiNfdZd", &eval_toPrecDouble);
    // pure nothrow @nogc @safe double core.math.toPrec!(double).toPrec(real)
    add_builtin("_D4core4math__T6toPrecHTdZQlFNaNbNiNfeZd", &eval_toPrecDouble);
    // pure nothrow @nogc @safe double core.math.toPrec!(real).toPrec(float)
    add_builtin("_D4core4math__T6toPrecHTeZQlFNaNbNiNffZe", &eval_toPrecReal);
    // pure nothrow @nogc @safe double core.math.toPrec!(real).toPrec(double)
    add_builtin("_D4core4math__T6toPrecHTeZQlFNaNbNiNfdZe", &eval_toPrecReal);
    // pure nothrow @nogc @safe double core.math.toPrec!(real).toPrec(real)
    add_builtin("_D4core4math__T6toPrecHTeZQlFNaNbNiNfeZe", &eval_toPrecReal);
}

/**
 * Deinitializes the global state of the compiler.
 *
 * This can be used to restore the state set by `builtin_init` to its original
 * state.
 */
public void builtinDeinitialize()
{
    builtins = builtins.init;
}

/**********************************
 * Determine if function is a builtin one that we can
 * evaluate at compile time.
 */
public extern (C++) BUILTIN isBuiltin(FuncDeclaration fd)
{
    if (fd.builtin == BUILTIN.unknown)
    {
        builtin_fp fp = builtin_lookup(mangleExact(fd));
        fd.builtin = fp ? BUILTIN.yes : BUILTIN.no;
    }
    return fd.builtin;
}

/**************************************
 * Evaluate builtin function.
 * Return result; NULL if cannot evaluate it.
 */
public extern (C++) Expression eval_builtin(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    if (fd.builtin == BUILTIN.yes)
    {
        builtin_fp fp = builtin_lookup(mangleExact(fd));
        assert(fp);
        return fp(loc, fd, arguments);
    }
    return null;
}
