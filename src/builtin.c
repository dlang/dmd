
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
enum BUILTIN FuncDeclaration::isBuiltin(enum BuiltinPurpose purpose)
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

        // std.stdio.writeln
        else if (purpose == BuiltinPurposeCTFE &&
                 ident == Id::writeln && parent && parent->parent &&
                 parent->parent->isModule() && parent->parent->ident == Id::stdio &&
                 parent->parent->parent && parent->parent->parent->ident == Id::std &&
                 !parent->parent->parent->parent)
        {
            builtin = BUILTINwriteln;
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
    assert(arguments);
    Expression *e = NULL;

    if (builtin == BUILTINwriteln)
    {
        print_expressions_to_stdmsg(arguments, NULL);
        e = EXP_VOID_INTERPRET;
    }
    else
    {
        assert(arguments->dim);
        Expression *arg0 = arguments->tdata()[0];
        if (arg0->op == TOKfloat64)
        {
            real_t value = arg0->toReal();
            switch (builtin)
            {
                case BUILTINsin:  value = sinl(value); break;
                case BUILTINcos:  value = cosl(value); break;
                case BUILTINtan:  value = tanl(value); break;
                case BUILTINsqrt: value = sqrtl(value); break;
                case BUILTINfabs: value = fabsl(value); break;
                default:
                    assert(0);
            }
            e = new RealExp(0, value, arg0->type);
        }
    }
    return e;
}

#endif

void print_expressions_to_stdmsg(Expressions *args, Scope *sc)
{
    for (size_t i = 0; i < args->dim; i++)
    {
        Expression *e = args->tdata()[i];
        
        if (sc)
        {
            e = e->semantic(sc);
            e = e->optimize(WANTvalue | WANTinterpret);
        }
        if (e->op == TOKstring)
        {
            StringExp *se = (StringExp *)e;
            fprintf(stdmsg, "%.*s", (int)se->len, (char *)se->string);
        }
        else
            fprintf(stdmsg, "%s", e->toChars());
    }
    fprintf(stdmsg, "\n");
}


