
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
    static const char FeZe [] = "FNaNbNfeZe";      // @safe pure nothrow real function(real)
    static const char FeZe2[] = "FNaNbNeeZe";      // @trusted pure nothrow real function(real)

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
                    //printf("builtin = %d\n", builtin);
                }
                // if float or double versions
                else if (strcmp(type->deco, "FNaNbNfdZd") == 0 ||
                         strcmp(type->deco, "FNaNbNffZf") == 0)
                {
                    if (ident == Id::_sqrt)
                        builtin = BUILTINsqrt;
                }
            }
        }
    }
    return builtin;
}


/**************************************
 * Evaluate builtin function.
 * Return result; NULL if cannot evaluate it.
 */

Expression *eval_builtin(enum BUILTIN builtin, Expressions *arguments)
{
    assert(arguments && arguments->dim);
    Expression *arg0 = arguments->tdata()[0];
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
    }
    return e;
}

#endif
