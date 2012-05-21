
// Compiler implementation of the D programming language
// Copyright (c) 1999-2012 by Digital Mars
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

#if __FreeBSD__
extern "C"
{
    long double sinl(long double);
    long double cosl(long double);
    long double tanl(long double);
    long double sqrtl(long double);
}
#endif

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

#if DMDV2

/**********************************
 * Determine if function is a builtin one that we can
 * evaluate at compile time.
 */
enum BUILTIN FuncDeclaration::isBuiltin()
{
    static const char FeZe[] = "FNaNbeZe";      // pure nothrow real function(real)

    //printf("FuncDeclaration::isBuiltin() %s\n", toChars());
    if (builtin == BUILTINunknown)
    {
        builtin = BUILTINnot;
        if (parent && parent->isModule())
        {
            // If it's in the std.math package
            if (parent->ident == Id::math &&
                parent->parent && parent->parent->ident == Id::std &&
                !parent->parent->parent)
            {
                //printf("deco = %s\n", type->deco);
                if (strcmp(type->deco, FeZe) == 0)
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
                else if (strcmp(type->deco, "FNaNbdZd") == 0 ||
                         strcmp(type->deco, "FNaNbfZf") == 0)
                    if (ident == Id::_sqrt)
                        builtin = BUILTINsqrt;
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

Expression *eval_builtin(Loc loc, enum BUILTIN builtin, Expressions *arguments)
{
    assert(arguments && arguments->dim);
    Expression *arg0 = (*arguments)[0];
    Expression *e = NULL;
    switch (builtin)
    {
        case BUILTINsin:
            if (arg0->op == TOKfloat64)
                e = new RealExp(0, sinl(arg0->toReal()), arg0->type);
            break;

        case BUILTINcos:
            if (arg0->op == TOKfloat64)
                e = new RealExp(0, cosl(arg0->toReal()), arg0->type);
            break;

        case BUILTINtan:
            if (arg0->op == TOKfloat64)
                e = new RealExp(0, tanl(arg0->toReal()), arg0->type);
            break;

        case BUILTINsqrt:
            if (arg0->op == TOKfloat64)
                e = new RealExp(0, sqrtl(arg0->toReal()), arg0->type);
            break;

        case BUILTINfabs:
            if (arg0->op == TOKfloat64)
                e = new RealExp(0, fabsl(arg0->toReal()), arg0->type);
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
    }
    return e;
}

#endif
