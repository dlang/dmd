
// Compiler implementation of the D programming language
// Copyright (c) 1999-2009 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

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
    return new RealExp(loc, sqrtl(arg0->toReal()), arg0->type);
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

void builtin_init()
{
    builtins._init(45);

    // @safe pure nothrow real function(real)
    add_builtin("_D4core4math3sinFNaNbNfeZe", &eval_sin);
    add_builtin("_D4core4math3cosFNaNbNfeZe", &eval_cos);
    add_builtin("_D4core4math3tanFNaNbNfeZe", &eval_tan);
    add_builtin("_D4core4math4sqrtFNaNbNfeZe", &eval_sqrt);
    add_builtin("_D4core4math4fabsFNaNbNfeZe", &eval_fabs);
    add_builtin("_D4core4math5expm1FNaNbNfeZe", &eval_unimp);
    add_builtin("_D4core4math4exp21FNaNbNfeZe", &eval_unimp);

    // @trusted pure nothrow real function(real)
    add_builtin("_D4core4math3sinFNaNbNeeZe", &eval_sin);
    add_builtin("_D4core4math3cosFNaNbNeeZe", &eval_cos);
    add_builtin("_D4core4math3tanFNaNbNeeZe", &eval_tan);
    add_builtin("_D4core4math4sqrtFNaNbNeeZe", &eval_sqrt);
    add_builtin("_D4core4math4fabsFNaNbNeeZe", &eval_fabs);
    add_builtin("_D4core4math5expm1FNaNbNeeZe", &eval_unimp);
    add_builtin("_D4core4math4exp21FNaNbNeeZe", &eval_unimp);

    // @safe pure nothrow double function(double)
    add_builtin("_D4core4math4sqrtFNaNbNfdZd", &eval_sqrt);
    // @safe pure nothrow float function(float)
    add_builtin("_D4core4math4sqrtFNaNbNffZf", &eval_sqrt);

    // @safe pure nothrow real function(real, real)
    add_builtin("_D4core4math5atan2FNaNbNfeeZe", &eval_unimp);
    add_builtin("_D4core4math4yl2xFNaNbNfeeZe", &eval_unimp);
    add_builtin("_D4core4math6yl2xp1FNaNbNfeeZe", &eval_unimp);

    // @safe pure nothrow long function(real)
    add_builtin("_D4core4math6rndtolFNaNbNfeZl", &eval_unimp);

    // @safe pure nothrow real function(real)
    add_builtin("_D3std4math3sinFNaNbNfeZe", &eval_sin);
    add_builtin("_D3std4math3cosFNaNbNfeZe", &eval_cos);
    add_builtin("_D3std4math3tanFNaNbNfeZe", &eval_tan);
    add_builtin("_D3std4math4sqrtFNaNbNfeZe", &eval_sqrt);
    add_builtin("_D3std4math4fabsFNaNbNfeZe", &eval_fabs);
    add_builtin("_D3std4math5expm1FNaNbNfeZe", &eval_unimp);
    add_builtin("_D3std4math4exp21FNaNbNfeZe", &eval_unimp);

    // @trusted pure nothrow real function(real)
    add_builtin("_D3std4math3sinFNaNbNeeZe", &eval_sin);
    add_builtin("_D3std4math3cosFNaNbNeeZe", &eval_cos);
    add_builtin("_D3std4math3tanFNaNbNeeZe", &eval_tan);
    add_builtin("_D3std4math4sqrtFNaNbNeeZe", &eval_sqrt);
    add_builtin("_D3std4math4fabsFNaNbNeeZe", &eval_fabs);
    add_builtin("_D3std4math5expm1FNaNbNeeZe", &eval_unimp);
    add_builtin("_D3std4math4exp21FNaNbNeeZe", &eval_unimp);

    // @safe pure nothrow double function(double)
    add_builtin("_D3std4math4sqrtFNaNbNfdZd", &eval_sqrt);
    // @safe pure nothrow float function(float)
    add_builtin("_D3std4math4sqrtFNaNbNffZf", &eval_sqrt);

    // @safe pure nothrow real function(real, real)
    add_builtin("_D3std4math5atan2FNaNbNfeeZe", &eval_unimp);
    add_builtin("_D3std4math4yl2xFNaNbNfeeZe", &eval_unimp);
    add_builtin("_D3std4math6yl2xp1FNaNbNfeeZe", &eval_unimp);

    // @safe pure nothrow long function(real)
    add_builtin("_D3std4math6rndtolFNaNbNfeZl", &eval_unimp);

    // @safe pure nothrow int function(uint)
    add_builtin("_D4core5bitop3bsfFNaNbNfkZi", &eval_bsf);
    add_builtin("_D4core5bitop3bsrFNaNbNfkZi", &eval_bsr);

    // @safe pure nothrow int function(ulong)
    add_builtin("_D4core5bitop3bsfFNaNbNfmZi", &eval_bsf);
    add_builtin("_D4core5bitop3bsrFNaNbNfmZi", &eval_bsr);

    // @safe pure nothrow uint function(uint)
    add_builtin("_D4core5bitop5bswapFNaNbNfkZk", &eval_bswap);
}

/**********************************
 * Determine if function is a builtin one that we can
 * evaluate at compile time.
 */
BUILTIN FuncDeclaration::isBuiltin()
{
    if (builtin == BUILTINunknown)
    {
        builtin_fp fp = builtin_lookup(mangleExact());
        builtin = fp ? BUILTINyes : BUILTINno;
    }
    return builtin;
}

/**************************************
 * Evaluate builtin function.
 * Return result; NULL if cannot evaluate it.
 */

Expression *eval_builtin(Loc loc, FuncDeclaration *fd, Expressions *arguments)
{
    if (fd->builtin == BUILTINyes)
    {
        builtin_fp fp = builtin_lookup(fd->mangleExact());
        assert(fp);
        return fp(loc, fd, arguments);
    }
    return NULL;
}
