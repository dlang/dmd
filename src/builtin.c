
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


/**********************************
 * Determine if function is a builtin one that we can
 * evaluate at compile time.
 */
BUILTIN FuncDeclaration::isBuiltin()
{
    static const char FeZe [] = "FNaNbNfeZe";      // @safe pure nothrow real function(real)
    static const char FeZe2[] = "FNaNbNeeZe";      // @trusted pure nothrow real function(real)
    static const char FuintZint[] = "FNaNbNfkZi";  // @safe pure nothrow int function(uint)
    static const char FuintZuint[] = "FNaNbNfkZk"; // @safe pure nothrow uint function(uint)
    //static const char FulongZulong[] = "FNaNbkZk"; // pure nothrow int function(ulong)
    static const char FulongZint[] = "FNaNbNfmZi"; // @safe pure nothrow int function(uint)
    static const char FrealrealZreal [] = "FNaNbNfeeZe";  // @safe pure nothrow real function(real, real)
    static const char FrealZlong [] = "FNaNbNfeZl";  // @safe pure nothrow long function(real)

    //printf("FuncDeclaration::isBuiltin() %s, %d\n", toChars(), builtin);
    if (builtin == BUILTINunknown)
    {
        builtin = BUILTINnot;
        if (parent && parent->isModule())
        {
            // If it's in the std.math package
            if (parent->ident == Id::math &&
                parent->parent && (parent->parent->ident == Id::std || parent->parent->ident == Id::core) &&
                !parent->parent->parent)
            {
                //printf("deco = %s\n", type->deco);
                if (strcmp(type->deco, FeZe) == 0 || strcmp(type->deco, FeZe2) == 0)
                {
                    if (ident == Id::sin)
                        builtin = BUILTINsin;
                    else if (ident == Id::cos)
                        builtin = BUILTINcos;
                    else if (ident == Id::tan)
                        builtin = BUILTINtan;
                    else if (ident == Id::_sqrt)
                        builtin = BUILTINsqrt;
                    else if (ident == Id::fabs)
                        builtin = BUILTINfabs;
                    else if (ident == Id::expm1)
                        builtin = BUILTINexpm1;
                    else if (ident == Id::exp2)
                        builtin = BUILTINexp2;
                    //printf("builtin = %d\n", builtin);
                }
                // if float or double versions
                else if (strcmp(type->deco, "FNaNbNfdZd") == 0 ||
                         strcmp(type->deco, "FNaNbNffZf") == 0)
                {
                    if (ident == Id::_sqrt)
                        builtin = BUILTINsqrt;
                }
                else if (strcmp(type->deco, FrealrealZreal) == 0)
                {
                    if (ident == Id::atan2)
                        builtin = BUILTINatan2;
                    else if (ident == Id::yl2x)
                        builtin = BUILTINyl2x;
                    else if (ident == Id::yl2xp1)
                        builtin = BUILTINyl2xp1;
                }
                else if (strcmp(type->deco, FrealZlong) == 0 && ident == Id::rndtol)
                    builtin = BUILTINrndtol;
            }
            if (parent->ident == Id::bitop &&
                parent->parent && parent->parent->ident == Id::core &&
                !parent->parent->parent)
            {
                //printf("deco = %s\n", type->deco);
                if (strcmp(type->deco, FuintZint) == 0 || strcmp(type->deco, FulongZint) == 0)
                {
                    if (ident == Id::bsf)
                        builtin = BUILTINbsf;
                    else if (ident == Id::bsr)
                        builtin = BUILTINbsr;
                }
                else if (strcmp(type->deco, FuintZuint) == 0)
                {
                    if (ident == Id::bswap)
                        builtin = BUILTINbswap;
                }
            }
        }
    }
    return builtin;
}

int eval_bsf(uinteger_t n)
{
    n = (n ^ (n - 1)) >> 1;  // convert trailing 0s to 1, and zero rest
    int k = 0;
    while( n )
    {   ++k;
        n >>=1;
    }
    return k;
}

int eval_bsr(uinteger_t n)
{   int k= 0;
    while(n>>=1)
    {
        ++k;
    }
    return k;
}

uinteger_t eval_bswap(Expression *arg0)
{   uinteger_t n = arg0->toInteger();
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
    return n;
}

/**************************************
 * Evaluate builtin function.
 * Return result; NULL if cannot evaluate it.
 */

Expression *eval_builtin(Loc loc, BUILTIN builtin, Expressions *arguments)
{
    assert(arguments && arguments->dim);
    Expression *arg0 = (*arguments)[0];
    Expression *e = NULL;
    switch (builtin)
    {
        case BUILTINsin:
            if (arg0->op == TOKfloat64)
                e = new RealExp(Loc(), sinl(arg0->toReal()), arg0->type);
            break;

        case BUILTINcos:
            if (arg0->op == TOKfloat64)
                e = new RealExp(Loc(), cosl(arg0->toReal()), arg0->type);
            break;

        case BUILTINtan:
            if (arg0->op == TOKfloat64)
                e = new RealExp(Loc(), tanl(arg0->toReal()), arg0->type);
            break;

        case BUILTINsqrt:
            if (arg0->op == TOKfloat64)
                e = new RealExp(Loc(), sqrtl(arg0->toReal()), arg0->type);
            break;

        case BUILTINfabs:
            if (arg0->op == TOKfloat64)
                e = new RealExp(Loc(), fabsl(arg0->toReal()), arg0->type);
            break;
        // These math intrinsics are not yet implemented
        case BUILTINatan2:
            break;
        case BUILTINrndtol:
            break;
        case BUILTINexpm1:
            break;
        case BUILTINexp2:
            break;
        case BUILTINyl2x:
            break;
        case BUILTINyl2xp1:
            break;
        case BUILTINbsf:
            if (arg0->op == TOKint64)
            {   if (arg0->toInteger()==0)
                    error(loc, "bsf(0) is undefined");
                else
                    e = new IntegerExp(loc, eval_bsf(arg0->toInteger()), Type::tint32);
            }
            break;
        case BUILTINbsr:
            if (arg0->op == TOKint64)
            {   if (arg0->toInteger()==0)
                    error(loc, "bsr(0) is undefined");
                else
                    e = new IntegerExp(loc, eval_bsr(arg0->toInteger()), Type::tint32);
            }
            break;
        case BUILTINbswap:
            if (arg0->op == TOKint64)
                e = new IntegerExp(loc, eval_bswap(arg0), arg0->type);
            break;
        default: break;
    }
    return e;
}
