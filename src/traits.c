
// Compiler implementation of the D programming language
// Copyright (c) 1999-2011 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <assert.h>
#include <math.h>

#include "rmem.h"

//#include "port.h"
#include "mtype.h"
#include "init.h"
#include "expression.h"
#include "template.h"
#include "utf.h"
#include "enum.h"
#include "scope.h"
#include "statement.h"
#include "declaration.h"
#include "aggregate.h"
#include "import.h"
#include "id.h"
#include "dsymbol.h"
#include "module.h"
#include "attrib.h"
#include "hdrgen.h"
#include "parse.h"

#define LOGSEMANTIC     0

#if DMDV2

/************************************************
 * Delegate to be passed to overloadApply() that looks
 * for functions matching a trait.
 */

struct Ptrait
{
    Expression *e1;
    Expressions *exps;          // collected results
    Identifier *ident;          // which trait we're looking for
};

static int fptraits(void *param, FuncDeclaration *f)
{   Ptrait *p = (Ptrait *)param;

    if (p->ident == Id::getVirtualFunctions && !f->isVirtual())
        return 0;

    Expression *e;

    if (p->e1->op == TOKdotvar)
    {   DotVarExp *dve = (DotVarExp *)p->e1;
        e = new DotVarExp(0, dve->e1, f);
    }
    else
        e = new DsymbolExp(0, f);
    p->exps->push(e);
    return 0;
}

/************************ TraitsExp ************************************/

Expression *TraitsExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("TraitsExp::semantic() %s\n", toChars());
#endif
    if (ident != Id::compiles && ident != Id::isSame &&
        ident != Id::identifier)
    {
        TemplateInstance::semanticTiargs(loc, sc, args, 1);
    }
    size_t dim = args ? args->dim : 0;
    Declaration *d;

#define ISTYPE(cond) \
        for (size_t i = 0; i < dim; i++)        \
        {   Type *t = getType(args->tdata()[i]); \
            if (!t)                             \
                goto Lfalse;                    \
            if (!(cond))                        \
                goto Lfalse;                    \
        }                                       \
        if (!dim)                               \
            goto Lfalse;                        \
        goto Ltrue;

#define ISDSYMBOL(cond) \
        for (size_t i = 0; i < dim; i++)        \
        {   Dsymbol *s = getDsymbol(args->tdata()[i]);   \
            if (!s)                             \
                goto Lfalse;                    \
            if (!(cond))                        \
                goto Lfalse;                    \
        }                                       \
        if (!dim)                               \
            goto Lfalse;                        \
        goto Ltrue;



    if (ident == Id::isArithmetic)
    {
        ISTYPE(t->isintegral() || t->isfloating())
    }
    else if (ident == Id::isFloating)
    {
        ISTYPE(t->isfloating())
    }
    else if (ident == Id::isIntegral)
    {
        ISTYPE(t->isintegral())
    }
    else if (ident == Id::isScalar)
    {
        ISTYPE(t->isscalar())
    }
    else if (ident == Id::isUnsigned)
    {
        ISTYPE(t->isunsigned())
    }
    else if (ident == Id::isAssociativeArray)
    {
        ISTYPE(t->toBasetype()->ty == Taarray)
    }
    else if (ident == Id::isStaticArray)
    {
        ISTYPE(t->toBasetype()->ty == Tsarray)
    }
    else if (ident == Id::isAbstractClass)
    {
        ISTYPE(t->toBasetype()->ty == Tclass && ((TypeClass *)t->toBasetype())->sym->isAbstract())
    }
    else if (ident == Id::isFinalClass)
    {
        ISTYPE(t->toBasetype()->ty == Tclass && ((TypeClass *)t->toBasetype())->sym->storage_class & STCfinal)
    }
    else if (ident == Id::isAbstractFunction)
    {
        FuncDeclaration *f;
        ISDSYMBOL((f = s->isFuncDeclaration()) != NULL && f->isAbstract())
    }
    else if (ident == Id::isVirtualFunction)
    {
        FuncDeclaration *f;
        ISDSYMBOL((f = s->isFuncDeclaration()) != NULL && f->isVirtual())
    }
    else if (ident == Id::isFinalFunction)
    {
        FuncDeclaration *f;
        ISDSYMBOL((f = s->isFuncDeclaration()) != NULL && f->isFinal())
    }
#if DMDV2
    else if (ident == Id::isStaticFunction)
    {
        FuncDeclaration *f;
        ISDSYMBOL((f = s->isFuncDeclaration()) != NULL && !f->needThis() && !f->isNested())
    }
    else if (ident == Id::isRef)
    {
        ISDSYMBOL((d = s->isDeclaration()) != NULL && d->isRef())
    }
    else if (ident == Id::isOut)
    {
        ISDSYMBOL((d = s->isDeclaration()) != NULL && d->isOut())
    }
    else if (ident == Id::isLazy)
    {
        ISDSYMBOL((d = s->isDeclaration()) != NULL && d->storage_class & STClazy)
    }
    else if (ident == Id::identifier)
    {   // Get identifier for symbol as a string literal

        // Specify 0 for the flags argument to semanticTiargs() so that
        // a symbol should not be folded to a constant.
        TemplateInstance::semanticTiargs(loc, sc, args, 0);

        if (dim != 1)
            goto Ldimerror;
        Object *o = args->tdata()[0];
        Dsymbol *s = getDsymbol(o);
        if (!s || !s->ident)
        {
            error("argument %s has no identifier", o->toChars());
            goto Lfalse;
        }
        StringExp *se = new StringExp(loc, s->ident->toChars());
        return se->semantic(sc);
    }
    else if (ident == Id::parent)
    {
        if (dim != 1)
            goto Ldimerror;
        Object *o = args->tdata()[0];
        Dsymbol *s = getDsymbol(o);
        if (s)
            s = s->toParent();
        if (!s)
        {
            error("argument %s has no parent", o->toChars());
            goto Lfalse;
        }
        return (new DsymbolExp(loc, s))->semantic(sc);
    }

#endif
    else if (ident == Id::hasMember ||
             ident == Id::getMember ||
             ident == Id::getOverloads ||
             ident == Id::getVirtualFunctions)
    {
        if (dim != 2)
            goto Ldimerror;
        Object *o = args->tdata()[0];
        Expression *e = isExpression(args->tdata()[1]);
        if (!e)
        {   error("expression expected as second argument of __traits %s", ident->toChars());
            goto Lfalse;
        }
        e = e->optimize(WANTvalue | WANTinterpret);
        StringExp *se = e->toString();
        if (!se || se->length() == 0)
        {   error("string expected as second argument of __traits %s instead of %s", ident->toChars(), e->toChars());
            goto Lfalse;
        }
        se = se->toUTF8(sc);
        if (se->sz != 1)
        {   error("string must be chars");
            goto Lfalse;
        }
        Identifier *id = Lexer::idPool((char *)se->string);

        Type *t = isType(o);
        e = isExpression(o);
        Dsymbol *s = isDsymbol(o);
        if (t)
            e = typeDotIdExp(loc, t, id);
        else if (e)
            e = new DotIdExp(loc, e, id);
        else if (s)
        {   e = new DsymbolExp(loc, s);
            e = new DotIdExp(loc, e, id);
        }
        else
        {   error("invalid first argument");
            goto Lfalse;
        }

        if (ident == Id::hasMember)
        {   /* Take any errors as meaning it wasn't found
             */
            e = e->trySemantic(sc);
            if (!e)
            {   if (global.gag)
                    global.errors++;
                goto Lfalse;
            }
            else
                goto Ltrue;
        }
        else if (ident == Id::getMember)
        {
            e = e->semantic(sc);
            return e;
        }
        else if (ident == Id::getVirtualFunctions ||
                 ident == Id::getOverloads)
        {
            unsigned errors = global.errors;
            Expression *ex = e;
            e = e->semantic(sc);
            if (errors < global.errors)
                error("%s cannot be resolved", ex->toChars());

            /* Create tuple of functions of e
             */
            //e->dump(0);
            Expressions *exps = new Expressions();
            FuncDeclaration *f;
            if (e->op == TOKvar)
            {   VarExp *ve = (VarExp *)e;
                f = ve->var->isFuncDeclaration();
            }
            else if (e->op == TOKdotvar)
            {   DotVarExp *dve = (DotVarExp *)e;
                f = dve->var->isFuncDeclaration();
            }
            else
                f = NULL;
            Ptrait p;
            p.exps = exps;
            p.e1 = e;
            p.ident = ident;
            overloadApply(f, fptraits, &p);

            TupleExp *tup = new TupleExp(loc, exps);
            return tup->semantic(sc);
        }
        else
            assert(0);
    }
    else if (ident == Id::classInstanceSize)
    {
        if (dim != 1)
            goto Ldimerror;
        Object *o = args->tdata()[0];
        Dsymbol *s = getDsymbol(o);
        ClassDeclaration *cd;
        if (!s || (cd = s->isClassDeclaration()) == NULL)
        {
            error("first argument is not a class");
            goto Lfalse;
        }
        return new IntegerExp(loc, cd->structsize, Type::tsize_t);
    }
    else if (ident == Id::allMembers || ident == Id::derivedMembers)
    {
        if (dim != 1)
            goto Ldimerror;
        Object *o = args->tdata()[0];
        Dsymbol *s = getDsymbol(o);
        ScopeDsymbol *sd;
        if (!s)
        {
            error("argument has no members");
            goto Lfalse;
        }
        if ((sd = s->isScopeDsymbol()) == NULL)
        {
            error("%s %s has no members", s->kind(), s->toChars());
            goto Lfalse;
        }
        Expressions *exps = new Expressions;
        while (1)
        {   size_t sddim = ScopeDsymbol::dim(sd->members);
            for (size_t i = 0; i < sddim; i++)
            {
                Dsymbol *sm = ScopeDsymbol::getNth(sd->members, i);
                if (!sm)
                    break;
                //printf("\t[%i] %s %s\n", i, sm->kind(), sm->toChars());
                if (sm->ident)
                {
                    //printf("\t%s\n", sm->ident->toChars());
                    char *str = sm->ident->toChars();

                    /* Skip if already present in exps[]
                     */
                    for (size_t j = 0; j < exps->dim; j++)
                    {   StringExp *se2 = (StringExp *)exps->tdata()[j];
                        if (strcmp(str, (char *)se2->string) == 0)
                            goto Lnext;
                    }

                    StringExp *se = new StringExp(loc, str);
                    exps->push(se);
                }
            Lnext:
                ;
            }
            ClassDeclaration *cd = sd->isClassDeclaration();
            if (cd && cd->baseClass && ident == Id::allMembers)
                sd = cd->baseClass;     // do again with base class
            else
                break;
        }
#if DMDV1
        Expression *e = new ArrayLiteralExp(loc, exps);
#endif
#if DMDV2
        /* Making this a tuple is more flexible, as it can be statically unrolled.
         * To make an array literal, enclose __traits in [ ]:
         *   [ __traits(allMembers, ...) ]
         */
        Expression *e = new TupleExp(loc, exps);
#endif
        e = e->semantic(sc);
        return e;
    }
    else if (ident == Id::compiles)
    {
        /* Determine if all the objects - types, expressions, or symbols -
         * compile without error
         */
        if (!dim)
            goto Lfalse;

        for (size_t i = 0; i < dim; i++)
        {   Object *o = args->tdata()[i];
            Expression *e;

            unsigned errors = global.errors;
            global.gag++;

            Type *t = isType(o);
            if (t)
            {   Dsymbol *s;
                t->resolve(loc, sc, &e, &t, &s);
                if (t)
                    t->semantic(loc, sc);
                else if (e)
                {   e = e->semantic(sc);
                    e = e->optimize(WANTvalue);
                }
            }
            else
            {   e = isExpression(o);
                if (e)
                {   e = e->semantic(sc);
                    e = e->optimize(WANTvalue);
                }
            }

            global.gag--;
            if (errors != global.errors)
            {
                global.errors = errors;
                goto Lfalse;
            }
        }
        goto Ltrue;
    }
    else if (ident == Id::isSame)
    {   /* Determine if two symbols are the same
         */
        if (dim != 2)
            goto Ldimerror;
        TemplateInstance::semanticTiargs(loc, sc, args, 0);
        Object *o1 = args->tdata()[0];
        Object *o2 = args->tdata()[1];
        Dsymbol *s1 = getDsymbol(o1);
        Dsymbol *s2 = getDsymbol(o2);

        //printf("isSame: %s, %s\n", o1->toChars(), o2->toChars());
#if 0
        printf("o1: %p\n", o1);
        printf("o2: %p\n", o2);
        if (!s1)
        {   Expression *ea = isExpression(o1);
            if (ea)
                printf("%s\n", ea->toChars());
            Type *ta = isType(o1);
            if (ta)
                printf("%s\n", ta->toChars());
            goto Lfalse;
        }
        else
            printf("%s %s\n", s1->kind(), s1->toChars());
#endif
        if (!s1 && !s2)
        {   Expression *ea1 = isExpression(o1);
            Expression *ea2 = isExpression(o2);
            if (ea1 && ea2)
            {
                if (ea1->equals(ea2))
                    goto Ltrue;
            }
        }

        if (!s1 || !s2)
            goto Lfalse;

        s1 = s1->toAlias();
        s2 = s2->toAlias();

        if (s1 == s2)
            goto Ltrue;
        else
            goto Lfalse;
    }
    else
    {   error("unrecognized trait %s", ident->toChars());
        goto Lfalse;
    }

    return NULL;

Ldimerror:
    error("wrong number of arguments %d", dim);
    goto Lfalse;


Lfalse:
    return new IntegerExp(loc, 0, Type::tbool);

Ltrue:
    return new IntegerExp(loc, 1, Type::tbool);
}


#endif
