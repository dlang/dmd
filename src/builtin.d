/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2016 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _builtin.d)
 */

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
import ddmd.root.ctfloat;
import ddmd.root.stringtable;
import ddmd.tokens;
version(IN_LLVM) {
    import ddmd.dtemplate;
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
extern (C++) alias builtin_fp = Expression function(Loc loc, FuncDeclaration fd, Expressions* arguments);

__gshared StringTable builtins;

public extern (C++) void add_builtin(const(char)* mangle, builtin_fp fp)
{
    builtins.insert(mangle, strlen(mangle), cast(void*)fp);
}

builtin_fp builtin_lookup(const(char)* mangle)
{
    if (const sv = builtins.lookup(mangle, strlen(mangle)))
        return cast(builtin_fp)sv.ptrvalue;
    return null;
}

extern (C++) Expression eval_unimp(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    return null;
}

extern (C++) Expression eval_sin(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOKfloat64);
    return new RealExp(loc, CTFloat.sin(arg0.toReal()), arg0.type);
}

extern (C++) Expression eval_cos(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOKfloat64);
    return new RealExp(loc, CTFloat.cos(arg0.toReal()), arg0.type);
}

extern (C++) Expression eval_tan(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOKfloat64);
    return new RealExp(loc, CTFloat.tan(arg0.toReal()), arg0.type);
}

extern (C++) Expression eval_sqrt(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOKfloat64);
    return new RealExp(loc, CTFloat.sqrt(arg0.toReal()), arg0.type);
}

extern (C++) Expression eval_fabs(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOKfloat64);
    return new RealExp(loc, CTFloat.fabs(arg0.toReal()), arg0.type);
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

version(IN_LLVM)
{

private Type getTypeOfOverloadedIntrinsic(FuncDeclaration fd)
{
    // Depending on the state of the code generation we have to look at
    // the template instance or the function declaration.
    assert(fd.parent && "function declaration requires parent");
    TemplateInstance tinst = fd.parent.isTemplateInstance();
    if (tinst)
    {
        // See DtoOverloadedIntrinsicName
        assert(tinst.tdtypes.dim == 1);
        return cast(Type) tinst.tdtypes.data[0];
    }
    else
    {
        assert(fd.type.ty == Tfunction);
        TypeFunction tf = cast(TypeFunction) fd.type;
        assert(tf.parameters.dim >= 1);
        return tf.parameters.data[0].type;
    }
}

private int getBitsizeOfType(Loc loc, Type type)
{
    switch (type.toBasetype().ty)
    {
      case Tint64:
      case Tuns64: return 64;
      case Tint32:
      case Tuns32: return 32;
      case Tint16:
      case Tuns16: return 16;
      case Tint128:
      case Tuns128:
          error(loc, "cent/ucent not supported");
          break;
      default:
          error(loc, "unsupported type");
          break;
    }
    return 32; // in case of error
}

extern (C++) Expression eval_llvmsin(Loc loc, FuncDeclaration fd, Expressions *arguments)
{
    Type type = getTypeOfOverloadedIntrinsic(fd);
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOKfloat64);
    return new RealExp(loc, CTFloat.sin(arg0.toReal()), type);
}

extern (C++) Expression eval_llvmcos(Loc loc, FuncDeclaration fd, Expressions *arguments)
{
    Type type = getTypeOfOverloadedIntrinsic(fd);
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOKfloat64);
    return new RealExp(loc, CTFloat.cos(arg0.toReal()), type);
}

extern (C++) Expression eval_llvmsqrt(Loc loc, FuncDeclaration fd, Expressions *arguments)
{
    Type type = getTypeOfOverloadedIntrinsic(fd);
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOKfloat64);
    return new RealExp(loc, CTFloat.sqrt(arg0.toReal()), type);
}

extern (C++) Expression eval_llvmlog(Loc loc, FuncDeclaration fd, Expressions *arguments)
{
    Type type = getTypeOfOverloadedIntrinsic(fd);
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOKfloat64);
    return new RealExp(loc, CTFloat.log(arg0.toReal()), type);
}

extern (C++) Expression eval_llvmfabs(Loc loc, FuncDeclaration fd, Expressions *arguments)
{
    Type type = getTypeOfOverloadedIntrinsic(fd);
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOKfloat64);
    return new RealExp(loc, CTFloat.fabs(arg0.toReal()), type);
}

extern (C++) Expression eval_llvmminnum(Loc loc, FuncDeclaration fd, Expressions *arguments)
{
    Type type = getTypeOfOverloadedIntrinsic(fd);
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOKfloat64);
    Expression arg1 = (*arguments)[1];
    assert(arg1.op == TOKfloat64);
    return new RealExp(loc, CTFloat.fmin(arg0.toReal(), arg1.toReal()), type);
}

extern (C++) Expression eval_llvmmaxnum(Loc loc, FuncDeclaration fd, Expressions *arguments)
{
    Type type = getTypeOfOverloadedIntrinsic(fd);
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOKfloat64);
    Expression arg1 = (*arguments)[1];
    assert(arg1.op == TOKfloat64);
    return new RealExp(loc, CTFloat.fmax(arg0.toReal(), arg1.toReal()), type);
}

extern (C++) Expression eval_llvmfloor(Loc loc, FuncDeclaration fd, Expressions *arguments)
{
    Type type = getTypeOfOverloadedIntrinsic(fd);
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOKfloat64);
    return new RealExp(loc, CTFloat.floor(arg0.toReal()), type);
}

extern (C++) Expression eval_llvmceil(Loc loc, FuncDeclaration fd, Expressions *arguments)
{
    Type type = getTypeOfOverloadedIntrinsic(fd);
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOKfloat64);
    return new RealExp(loc, CTFloat.ceil(arg0.toReal()), type);
}

extern (C++) Expression eval_llvmtrunc(Loc loc, FuncDeclaration fd, Expressions *arguments)
{
    Type type = getTypeOfOverloadedIntrinsic(fd);
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOKfloat64);
    return new RealExp(loc, CTFloat.trunc(arg0.toReal()), type);
}

extern (C++) Expression eval_llvmround(Loc loc, FuncDeclaration fd, Expressions *arguments)
{
    Type type = getTypeOfOverloadedIntrinsic(fd);
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOKfloat64);
    return new RealExp(loc, CTFloat.round(arg0.toReal()), type);
}

extern (C++) Expression eval_cttz(Loc loc, FuncDeclaration fd, Expressions *arguments)
{
    Type type = getTypeOfOverloadedIntrinsic(fd);

    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOKint64);
    uinteger_t x = arg0.toInteger();

    int n = getBitsizeOfType(loc, type);

    if (x == 0)
    {
        if ((*arguments)[1].toInteger())
            error(loc, "llvm.cttz.i#(0) is undefined");
    }
    else
    {
        int c = n >> 1;
        n -= 1;
        const uinteger_t mask = (uinteger_t(1L) << n) | (uinteger_t(1L) << n)-1;
        do {
            uinteger_t y = (x << c) & mask;
            if (y != 0) { n -= c; x = y; }
            c = c >> 1;
        } while (c != 0);
    }

    return new IntegerExp(loc, n, type);
}

extern (C++) Expression eval_ctlz(Loc loc, FuncDeclaration fd, Expressions *arguments)
{
    Type type = getTypeOfOverloadedIntrinsic(fd);

    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOKint64);
    uinteger_t x = arg0.toInteger();
    if (x == 0 && (*arguments)[1].toInteger())
        error(loc, "llvm.ctlz.i#(0) is undefined");

    int n = getBitsizeOfType(loc, type);
    int c = n >> 1;
    do {
        uinteger_t y = x >> c; if (y != 0) { n -= c; x = y; }
        c = c >> 1;
    } while (c != 0);

    return new IntegerExp(loc, n - x, type);
}

extern (C++) Expression eval_bswap(Loc loc, FuncDeclaration fd, Expressions *arguments)
{
    Type type = getTypeOfOverloadedIntrinsic(fd);

    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOKint64);
    uinteger_t n = arg0.toInteger();
    enum ulong BYTEMASK = 0x00FF00FF00FF00FF;
    enum ulong SHORTMASK = 0x0000FFFF0000FFFF;
    enum ulong INTMASK = 0x00000000FFFFFFFF;
    switch (type.toBasetype().ty)
    {
      case Tint64:
      case Tuns64:
          // swap high and low uints
          n = ((n >> 32) & INTMASK) | ((n & INTMASK) << 32);
          goto case Tuns32;
      case Tint32:
      case Tuns32:
          // swap adjacent ushorts
          n = ((n >> 16) & SHORTMASK) | ((n & SHORTMASK) << 16);
          goto case Tuns16;
      case Tint16:
      case Tuns16:
          // swap adjacent ubytes
          n = ((n >> 8 ) & BYTEMASK)  | ((n & BYTEMASK) << 8 );
          break;
      case Tint128:
      case Tuns128:
          error(loc, "cent/ucent not supported");
          break;
      default:
          error(loc, "unsupported type");
          break;
    }
    return new IntegerExp(loc, n, type);
}

extern (C++) Expression eval_ctpop(Loc loc, FuncDeclaration fd, Expressions *arguments)
{
    // FIXME Does not work for cent/ucent
    Type type = getTypeOfOverloadedIntrinsic(fd);

    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOKint64);
    uinteger_t n = arg0.toInteger();
    int cnt = 0;
    while (n)
    {
        cnt += (n & 1);
        n >>= 1;
    }
    return new IntegerExp(loc, cnt, type);
}

}
else // !IN_LLVM
{

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

} // !IN_LLVM

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
    const x = arg0.toReal();
    const y = arg1.toReal();
    real_t result = 0;
    CTFloat.yl2x(&x, &y, &result);
    return new RealExp(loc, result, arg0.type);
}

extern (C++) Expression eval_yl2xp1(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    Expression arg0 = (*arguments)[0];
    assert(arg0.op == TOKfloat64);
    Expression arg1 = (*arguments)[1];
    assert(arg1.op == TOKfloat64);
    const x = arg0.toReal();
    const y = arg1.toReal();
    real_t result = 0;
    CTFloat.yl2xp1(&x, &y, &result);
    return new RealExp(loc, result, arg0.type);
}

public extern (C++) void builtin_init()
{
version(IN_LLVM)
{
    builtins._init(127); // Prime number like default value
}
else
{
    builtins._init(47);
}
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
    if (CTFloat.yl2x_supported)
    {
        add_builtin("_D3std4math4yl2xFNaNbNiNfeeZe", &eval_yl2x);
    }
    else
    {
        add_builtin("_D3std4math4yl2xFNaNbNiNfeeZe", &eval_unimp);
    }
    if (CTFloat.yl2xp1_supported)
    {
        add_builtin("_D3std4math6yl2xp1FNaNbNiNfeeZe", &eval_yl2xp1);
    }
    else
    {
        add_builtin("_D3std4math6yl2xp1FNaNbNiNfeeZe", &eval_unimp);
    }
    // @safe @nogc pure nothrow long function(real)
    add_builtin("_D3std4math6rndtolFNaNbNiNfeZl", &eval_unimp);

version(IN_LLVM)
{
    // intrinsic llvm.sin.f32/f64/f80/f128/ppcf128
    add_builtin("llvm.sin.f32", &eval_llvmsin);
    add_builtin("llvm.sin.f64", &eval_llvmsin);
    add_builtin("llvm.sin.f80", &eval_llvmsin);
    add_builtin("llvm.sin.f128", &eval_llvmsin);
    add_builtin("llvm.sin.ppcf128", &eval_llvmsin);

    // intrinsic llvm.cos.f32/f64/f80/f128/ppcf128
    add_builtin("llvm.cos.f32", &eval_llvmcos);
    add_builtin("llvm.cos.f64", &eval_llvmcos);
    add_builtin("llvm.cos.f80", &eval_llvmcos);
    add_builtin("llvm.cos.f128", &eval_llvmcos);
    add_builtin("llvm.cos.ppcf128", &eval_llvmcos);

    // intrinsic llvm.sqrt.f32/f64/f80/f128/ppcf128
    add_builtin("llvm.sqrt.f32", &eval_llvmsqrt);
    add_builtin("llvm.sqrt.f64", &eval_llvmsqrt);
    add_builtin("llvm.sqrt.f80", &eval_llvmsqrt);
    add_builtin("llvm.sqrt.f128", &eval_llvmsqrt);
    add_builtin("llvm.sqrt.ppcf128", &eval_llvmsqrt);

    // intrinsic llvm.log.f32/f64/f80/f128/ppcf128
    add_builtin("llvm.log.f32", &eval_llvmlog);
    add_builtin("llvm.log.f64", &eval_llvmlog);
    add_builtin("llvm.log.f80", &eval_llvmlog);
    add_builtin("llvm.log.f128", &eval_llvmlog);
    add_builtin("llvm.log.ppcf128", &eval_llvmlog);

    // intrinsic llvm.fabs.f32/f64/f80/f128/ppcf128
    add_builtin("llvm.fabs.f32", &eval_llvmfabs);
    add_builtin("llvm.fabs.f64", &eval_llvmfabs);
    add_builtin("llvm.fabs.f80", &eval_llvmfabs);
    add_builtin("llvm.fabs.f128", &eval_llvmfabs);
    add_builtin("llvm.fabs.ppcf128", &eval_llvmfabs);

    // intrinsic llvm.minnum.f32/f64/f80/f128/ppcf128
    add_builtin("llvm.minnum.f32", &eval_llvmminnum);
    add_builtin("llvm.minnum.f64", &eval_llvmminnum);
    add_builtin("llvm.minnum.f80", &eval_llvmminnum);
    add_builtin("llvm.minnum.f128", &eval_llvmminnum);
    add_builtin("llvm.minnum.ppcf128", &eval_llvmminnum);

    // intrinsic llvm.maxnum.f32/f64/f80/f128/ppcf128
    add_builtin("llvm.maxnum.f32", &eval_llvmmaxnum);
    add_builtin("llvm.maxnum.f64", &eval_llvmmaxnum);
    add_builtin("llvm.maxnum.f80", &eval_llvmmaxnum);
    add_builtin("llvm.maxnum.f128", &eval_llvmmaxnum);
    add_builtin("llvm.maxnum.ppcf128", &eval_llvmmaxnum);

    // intrinsic llvm.floor.f32/f64/f80/f128/ppcf128
    add_builtin("llvm.floor.f32", &eval_llvmfloor);
    add_builtin("llvm.floor.f64", &eval_llvmfloor);
    add_builtin("llvm.floor.f80", &eval_llvmfloor);
    add_builtin("llvm.floor.f128", &eval_llvmfloor);
    add_builtin("llvm.floor.ppcf128", &eval_llvmfloor);

    // intrinsic llvm.ceil.f32/f64/f80/f128/ppcf128
    add_builtin("llvm.ceil.f32", &eval_llvmceil);
    add_builtin("llvm.ceil.f64", &eval_llvmceil);
    add_builtin("llvm.ceil.f80", &eval_llvmceil);
    add_builtin("llvm.ceil.f128", &eval_llvmceil);
    add_builtin("llvm.ceil.ppcf128", &eval_llvmceil);

    // intrinsic llvm.trunc.f32/f64/f80/f128/ppcf128
    add_builtin("llvm.trunc.f32", &eval_llvmtrunc);
    add_builtin("llvm.trunc.f64", &eval_llvmtrunc);
    add_builtin("llvm.trunc.f80", &eval_llvmtrunc);
    add_builtin("llvm.trunc.f128", &eval_llvmtrunc);
    add_builtin("llvm.trunc.ppcf128", &eval_llvmtrunc);

    // intrinsic llvm.round.f32/f64/f80/f128/ppcf128
    add_builtin("llvm.round.f32", &eval_llvmround);
    add_builtin("llvm.round.f64", &eval_llvmround);
    add_builtin("llvm.round.f80", &eval_llvmround);
    add_builtin("llvm.round.f128", &eval_llvmround);
    add_builtin("llvm.round.ppcf128", &eval_llvmround);

    // intrinsic llvm.bswap.i16/i32/i64/i128
    add_builtin("llvm.bswap.i16", &eval_bswap);
    add_builtin("llvm.bswap.i32", &eval_bswap);
    add_builtin("llvm.bswap.i64", &eval_bswap);
    add_builtin("llvm.bswap.i128", &eval_bswap);

    // intrinsic llvm.cttz.i8/i16/i32/i64/i128
    add_builtin("llvm.cttz.i8", &eval_cttz);
    add_builtin("llvm.cttz.i16", &eval_cttz);
    add_builtin("llvm.cttz.i32", &eval_cttz);
    add_builtin("llvm.cttz.i64", &eval_cttz);
    add_builtin("llvm.cttz.i128", &eval_cttz);

    // intrinsic llvm.ctlz.i8/i16/i32/i64/i128
    add_builtin("llvm.ctlz.i8", &eval_ctlz);
    add_builtin("llvm.ctlz.i16", &eval_ctlz);
    add_builtin("llvm.ctlz.i32", &eval_ctlz);
    add_builtin("llvm.ctlz.i64", &eval_ctlz);
    add_builtin("llvm.ctlz.i128", &eval_ctlz);

    // intrinsic llvm.ctpop.i8/i16/i32/i64/i128
    add_builtin("llvm.ctpop.i8", &eval_ctpop);
    add_builtin("llvm.ctpop.i16", &eval_ctpop);
    add_builtin("llvm.ctpop.i32", &eval_ctpop);
    add_builtin("llvm.ctpop.i64", &eval_ctpop);
    add_builtin("llvm.ctpop.i128", &eval_ctpop);
}

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
public extern (C++) BUILTIN isBuiltin(FuncDeclaration fd)
{
    if (fd.builtin == BUILTINunknown)
    {
        builtin_fp fp = builtin_lookup(mangleExact(fd));
        fd.builtin = fp ? BUILTINyes : BUILTINno;
    }
    return fd.builtin;
}

/**************************************
 * Evaluate builtin function.
 * Return result; NULL if cannot evaluate it.
 */
public extern (C++) Expression eval_builtin(Loc loc, FuncDeclaration fd, Expressions* arguments)
{
    if (fd.builtin == BUILTINyes)
    {
        builtin_fp fp = builtin_lookup(mangleExact(fd));
        assert(fp);
        return fp(loc, fd, arguments);
    }
    return null;
}
