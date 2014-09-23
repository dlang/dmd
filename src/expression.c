// Compiler implementation of the D programming language
// Copyright (c) 1999-2013 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <math.h>
#include <assert.h>
#if _MSC_VER
#include <complex>
#else
#include <complex.h>
#endif

#if _WIN32 && __DMC__
extern "C" const char * __cdecl __locale_decpoint;
#endif

#include "rmem.h"
#include "port.h"
#include "root.h"
#include "target.h"

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
#include "doc.h"


Expression *createTypeInfoArray(Scope *sc, Expression *args[], unsigned dim);
Expression *expandVar(int result, VarDeclaration *v);

#define LOGSEMANTIC     0

/*************************************************************
 * Given var, we need to get the
 * right 'this' pointer if var is in an outer class, but our
 * existing 'this' pointer is in an inner class.
 * Input:
 *      e1      existing 'this'
 *      ad      struct or class we need the correct 'this' for
 *      var     the specific member of ad we're accessing
 */

Expression *getRightThis(Loc loc, Scope *sc, AggregateDeclaration *ad,
        Expression *e1, Declaration *var)
{
    //printf("\ngetRightThis(e1 = %s, ad = %s, var = %s)\n", e1->toChars(), ad->toChars(), var->toChars());
 L1:
    Type *t = e1->type->toBasetype();
    //printf("e1->type = %s, var->type = %s\n", e1->type->toChars(), var->type->toChars());

    /* If e1 is not the 'this' pointer for ad
     */
    if (ad &&
        !(t->ty == Tpointer && t->nextOf()->ty == Tstruct &&
          ((TypeStruct *)t->nextOf())->sym == ad)
        &&
        !(t->ty == Tstruct &&
          ((TypeStruct *)t)->sym == ad)
       )
    {
        ClassDeclaration *cd = ad->isClassDeclaration();
        ClassDeclaration *tcd = t->isClassHandle();

        /* e1 is the right this if ad is a base class of e1
         */
        if (!cd || !tcd ||
            !(tcd == cd || cd->isBaseOf(tcd, NULL))
           )
        {
            /* Only classes can be inner classes with an 'outer'
             * member pointing to the enclosing class instance
             */
            if (tcd && tcd->isNested())
            {   /* e1 is the 'this' pointer for an inner class: tcd.
                 * Rewrite it as the 'this' pointer for the outer class.
                 */

                e1 = new DotVarExp(loc, e1, tcd->vthis);
                e1->type = tcd->vthis->type;
                // Do not call checkNestedRef()
                //e1 = e1->semantic(sc);

                // Skip up over nested functions, and get the enclosing
                // class type.
                int n = 0;
                Dsymbol *s;
                for (s = tcd->toParent();
                     s && s->isFuncDeclaration();
                     s = s->toParent())
                {   FuncDeclaration *f = s->isFuncDeclaration();
                    if (f->vthis)
                    {
                        //printf("rewriting e1 to %s's this\n", f->toChars());
                        n++;
                        e1 = new VarExp(loc, f->vthis);
                    }
                    else
                    {
                        e1->error("need 'this' of type %s to access member %s"
                                  " from static function %s",
                            ad->toChars(), var->toChars(), f->toChars());
                        e1 = new ErrorExp();
                        return e1;
                    }
                }
                if (s && s->isClassDeclaration())
                {   e1->type = s->isClassDeclaration()->type;
                    if (n > 1)
                        e1 = e1->semantic(sc);
                }
                else
                    e1 = e1->semantic(sc);
                goto L1;
            }
            /* Can't find a path from e1 to ad
             */
            e1->error("this for %s needs to be type %s not type %s",
                var->toChars(), ad->toChars(), t->toChars());
            e1 = new ErrorExp();
        }
    }
    return e1;
}

/*****************************************
 * Determine if 'this' is available.
 * If it is, return the FuncDeclaration that has it.
 */

FuncDeclaration *hasThis(Scope *sc)
{   FuncDeclaration *fd;
    FuncDeclaration *fdthis;

    //printf("hasThis()\n");
    fdthis = sc->parent->isFuncDeclaration();
    //printf("fdthis = %p, '%s'\n", fdthis, fdthis ? fdthis->toChars() : "");

    // Go upwards until we find the enclosing member function
    fd = fdthis;
    while (1)
    {
        if (!fd)
        {
            goto Lno;
        }
        if (!fd->isNested())
            break;

        Dsymbol *parent = fd->parent;
        while (1)
        {
            if (!parent)
                goto Lno;
            TemplateInstance *ti = parent->isTemplateInstance();
            if (ti)
                parent = ti->parent;
            else
                break;
        }
        fd = parent->isFuncDeclaration();
    }

    if (!fd->isThis())
    {   //printf("test '%s'\n", fd->toChars());
        goto Lno;
    }

    assert(fd->vthis);
    return fd;

Lno:
    return NULL;                // don't have 'this' available
}


/***************************************
 * Pull out any properties.
 */

Expression *resolveProperties(Scope *sc, Expression *e)
{
    //printf("resolveProperties(%s)\n", e->toChars());
    if (e->type)
    {
        Type *t = e->type->toBasetype();

        if (t->ty == Tfunction /*|| e->op == TOKoverloadset*/)
        {
            e = new CallExp(e->loc, e);
            e = e->semantic(sc);
        }

        /* Look for e being a lazy parameter; rewrite as delegate call
         */
        else if (e->op == TOKvar)
        {   VarExp *ve = (VarExp *)e;

            if (ve->var->storage_class & STClazy)
            {
                e = new CallExp(e->loc, e);
                e = e->semantic(sc);
            }
        }

        else if (e->op == TOKdotexp)
        {
            e->error("expression has no value");
            return new ErrorExp();
        }

    }
    else if (e->op == TOKdottd)
    {
        e = new CallExp(e->loc, e);
        e = e->semantic(sc);
    }
    return e;
}

/******************************
 * Perform semantic() on an array of Expressions.
 */

Expressions *arrayExpressionSemantic(Expressions *exps, Scope *sc)
{
    if (exps)
    {
        for (size_t i = 0; i < exps->dim; i++)
        {   Expression *e = (Expression *)exps->data[i];
            if (e)
            {   e = e->semantic(sc);
                exps->data[i] = (void *)e;
            }
        }
    }
    return exps;
}


/******************************
 * Perform canThrow() on an array of Expressions.
 */

#if DMDV2
int arrayExpressionCanThrow(Expressions *exps)
{
    if (exps)
    {
        for (size_t i = 0; i < exps->dim; i++)
        {   Expression *e = (Expression *)exps->data[i];
            if (e && e->canThrow())
                return 1;
        }
    }
    return 0;
}
#endif

/****************************************
 * Expand tuples.
 */

void expandTuples(Expressions *exps)
{
    //printf("expandTuples()\n");
    if (exps)
    {
        for (size_t i = 0; i < exps->dim; i++)
        {   Expression *arg = (Expression *)exps->data[i];
            if (!arg)
                continue;

            // Look for tuple with 0 members
            if (arg->op == TOKtype)
            {   TypeExp *e = (TypeExp *)arg;
                if (e->type->toBasetype()->ty == Ttuple)
                {   TypeTuple *tt = (TypeTuple *)e->type->toBasetype();

                    if (!tt->arguments || tt->arguments->dim == 0)
                    {
                        exps->remove(i);
                        if (i == exps->dim)
                            return;
                        i--;
                        continue;
                    }
                }
            }

            // Inline expand all the tuples
            while (arg->op == TOKtuple)
            {   TupleExp *te = (TupleExp *)arg;

                exps->remove(i);                // remove arg
                exps->insert(i, te->exps);      // replace with tuple contents
                if (i == exps->dim)
                    return;             // empty tuple, no more arguments
                arg = (Expression *)exps->data[i];
            }
        }
    }
}

Expressions *arrayExpressionToCommonType(Scope *sc, Expressions *exps, Type **pt)
{
#if DMDV1
    /* The first element sets the type
     */
    Type *t0 = NULL;
    for (size_t i = 0; i < exps->dim; i++)
    {   Expression *e = (*exps)[i];

        if (!e->type)
        {   error(e->loc, "%s has no value", e->toChars());
            e = new ErrorExp();
        }
        e = resolveProperties(sc, e);

        if (!t0)
            t0 = e->type;
        else
            e = e->implicitCastTo(sc, t0);
        (*exps)[i] = e;
    }

    if (!t0)
        t0 = Type::tvoid;
    if (pt)
        *pt = t0;

    // Eventually, we want to make this copy-on-write
    return exps;
#endif
#if DMDV2
    /* The type is determined by applying ?: to each pair.
     */
    /* Still have a problem with:
     *  ubyte[][] = [ cast(ubyte[])"hello", [1]];
     * which works if the array literal is initialized top down with the ubyte[][]
     * type, but fails with this function doing bottom up typing.
     */
    //printf("arrayExpressionToCommonType()\n");
    IntegerExp integerexp(0);
    CondExp condexp(0, &integerexp, NULL, NULL);

    Type *t0 = NULL;
    Expression *e0;
    int j0;
    for (size_t i = 0; i < exps->dim; i++)
    {   Expression *e = (*exps)[i];

        e = resolveProperties(sc, e);
        if (!e->type)
        {   e->error("%s has no value", e->toChars());
            e = new ErrorExp();
        }

        if (t0)
        {   if (t0 != e->type)
            {
                /* This applies ?: to merge the types. It's backwards;
                 * ?: should call this function to merge types.
                 */
                condexp.type = NULL;
                condexp.e1 = e0;
                condexp.e2 = e;
                condexp.loc = e->loc;
                condexp.semantic(sc);
                (*exps)[j0] = condexp.e1;
                e = condexp.e2;
                j0 = i;
                e0 = e;
                t0 = e0->type;
            }
        }
        else
        {   j0 = i;
            e0 = e;
            t0 = e->type;
        }
        (*exps)[i] = e;
    }

    if (t0)
    {
        for (size_t i = 0; i < exps->dim; i++)
        {   Expression *e = (*exps)[i];
            e = e->implicitCastTo(sc, t0);
            (*exps)[i] = e;
        }
    }
    else
        t0 = Type::tvoid;               // [] is typed as void[]
    if (pt)
        *pt = t0;

    // Eventually, we want to make this copy-on-write
    return exps;
#endif
}

/****************************************
 * Get TemplateDeclaration enclosing FuncDeclaration.
 */

TemplateDeclaration *getFuncTemplateDecl(Dsymbol *s)
{
    FuncDeclaration *f = s->isFuncDeclaration();
    if (f && f->parent)
    {   TemplateInstance *ti = f->parent->isTemplateInstance();

        if (ti &&
            !ti->isTemplateMixin() &&
            (ti->name == f->ident ||
             ti->toAlias()->ident == f->ident)
            &&
            ti->tempdecl && ti->tempdecl->onemember)
        {
            return ti->tempdecl;
        }
    }
    return NULL;
}

/****************************************
 * Preprocess arguments to function.
 */

void preFunctionParameters(Loc loc, Scope *sc, Expressions *exps)
{
    if (exps)
    {
        expandTuples(exps);

        for (size_t i = 0; i < exps->dim; i++)
        {   Expression *arg = (*exps)[i];

            if (!arg->type)
            {
#ifdef DEBUG
                if (!global.gag)
                    printf("1: \n");
#endif
                arg->error("%s is not an expression", arg->toChars());
                arg = new ErrorExp();
            }

            arg = resolveProperties(sc, arg);
            (*exps)[i] =  arg;

            //arg->rvalue();
#if 0
            if (arg->type->ty == Tfunction)
            {
                arg = new AddrExp(arg->loc, arg);
                arg = arg->semantic(sc);
                (*exps)[i] =  arg;
            }
#endif
        }
    }
}

/*********************************************
 * Call copy constructor for struct value argument.
 */
#if DMDV2
Expression *callCpCtor(Loc loc, Scope *sc, Expression *e)
{
    Type *tb = e->type->toBasetype();
    assert(tb->ty == Tstruct);
    StructDeclaration *sd = ((TypeStruct *)tb)->sym;
    if (sd->cpctor)
    {
        /* Create a variable tmp, and replace the argument e with:
         *      (tmp = e),tmp
         * and let AssignExp() handle the construction.
         * This is not the most efficent, ideally tmp would be constructed
         * directly onto the stack.
         */
        Identifier *idtmp = Lexer::uniqueId("__tmp");
        VarDeclaration *tmp = new VarDeclaration(loc, tb, idtmp, new ExpInitializer(0, e));
        tmp->storage_class |= STCctfe;
        Expression *ae = new DeclarationExp(loc, tmp);
        e = new CommaExp(loc, ae, new VarExp(loc, tmp));
        e = e->semantic(sc);
    }
    return e;
}
#endif

/****************************************
 * Now that we know the exact type of the function we're calling,
 * the arguments[] need to be adjusted:
 *      1. implicitly convert argument to the corresponding parameter type
 *      2. add default arguments for any missing arguments
 *      3. do default promotions on arguments corresponding to ...
 *      4. add hidden _arguments[] argument
 */

void functionParameters(Loc loc, Scope *sc, TypeFunction *tf, Expressions *arguments)
{
    //printf("functionParameters()\n");
    assert(arguments);
    size_t nargs = arguments ? arguments->dim : 0;
    size_t nparams = Parameter::dim(tf->parameters);

    if (nargs > nparams && tf->varargs == 0)
        error(loc, "expected %zu arguments, not %zu for non-variadic function type %s", nparams, nargs, tf->toChars());

#if DMDV2
    // If inferring return type, and semantic3() needs to be run if not already run
    if (!tf->next && fd->inferRetType)
    {
        TemplateInstance *spec = fd->isSpeculative();
        int olderrs = global.errors;
        fd->semantic3(fd->scope);
        // Update the template instantiation with the number
        // of errors which occured.
        if (spec && global.errors != olderrs)
            spec->errors = global.errors - olderrs;
    }
#endif

    unsigned n = (nargs > nparams) ? nargs : nparams;   // n = max(nargs, nparams)

    int done = 0;
    for (size_t i = 0; i < n; i++)
    {
        Expression *arg;

        if (i < nargs)
            arg = (*arguments)[i];
        else
            arg = NULL;

        if (i < nparams)
        {
            Parameter *p = Parameter::getNth(tf->parameters, i);

            if (!arg)
            {
                if (!p->defaultArg)
                {
                    if (tf->varargs == 2 && i + 1 == nparams)
                        goto L2;
                    error(loc, "expected %zu function arguments, not %zu", nparams, nargs);
                    return;
                }
                arg = p->defaultArg;
                arg = arg->inlineCopy(sc);
                // __FILE__, __LINE__
                arg = arg->resolveLoc(loc, sc);
                arguments->push(arg);
                nargs++;
            }

            if (tf->varargs == 2 && i + 1 == nparams)
            {
                //printf("\t\tvarargs == 2, p->type = '%s'\n", p->type->toChars());
                MATCH m;
                if ((m = arg->implicitConvTo(p->type)) != MATCHnomatch)
                {
                    if (p->type->nextOf() && arg->implicitConvTo(p->type->nextOf()) >= m)
                        goto L2;
                    else if (nargs != nparams)
                    {   error(loc, "expected %llu function arguments, not %llu", (ulonglong)nparams, (ulonglong)nargs);
                        return;
                    }
                    goto L1;
                }
             L2:
                Type *tb = p->type->toBasetype();
                Type *tret = p->isLazyArray();
                switch (tb->ty)
                {
                    case Tsarray:
                    case Tarray:
                    {   // Create a static array variable v of type arg->type
#ifdef IN_GCC
                        /* GCC 4.0 does not like zero length arrays used like
                           this; pass a null array value instead. Could also
                           just make a one-element array. */
                        if (nargs - i == 0)
                        {
                            arg = new NullExp(loc);
                            break;
                        }
#endif
                        Identifier *id = Lexer::uniqueId("__arrayArg");
                        Type *t = new TypeSArray(((TypeArray *)tb)->next, new IntegerExp(nargs - i));
                        t = t->semantic(loc, sc);
                        VarDeclaration *v = new VarDeclaration(loc, t, id, new VoidInitializer(loc));
                        v->storage_class |= STCctfe;
                        v->semantic(sc);
                        v->parent = sc->parent;
                        //sc->insert(v);

                        Expression *c = new DeclarationExp(0, v);
                        c->type = v->type;

                        for (size_t u = i; u < nargs; u++)
                        {   Expression *a = (*arguments)[u];
                            if (tret && !((TypeArray *)tb)->next->equals(a->type))
                                a = a->toDelegate(sc, tret);

                            Expression *e = new VarExp(loc, v);
                            e = new IndexExp(loc, e, new IntegerExp(u + 1 - nparams));
                            AssignExp *ae = new AssignExp(loc, e, a);
                            if (c)
                                c = new CommaExp(loc, c, ae);
                            else
                                c = ae;
                        }
                        arg = new VarExp(loc, v);
                        if (c)
                            arg = new CommaExp(loc, c, arg);
                        break;
                    }
                    case Tclass:
                    {   /* Set arg to be:
                         *      new Tclass(arg0, arg1, ..., argn)
                         */
                        Expressions *args = new Expressions();
                        args->setDim(nargs - i);
                        for (size_t u = i; u < nargs; u++)
                            args->data[u - i] = arguments->data[u];
                        arg = new NewExp(loc, NULL, NULL, p->type, args);
                        break;
                    }
                    default:
                        if (!arg)
                        {   error(loc, "not enough arguments");
                            return;
                        }
                        break;
                }
                arg = arg->semantic(sc);
                //printf("\targ = '%s'\n", arg->toChars());
                arguments->setDim(i + 1);
                done = 1;
            }

        L1:
            if (!(p->storageClass & STClazy && p->type->ty == Tvoid))
            {
                if (p->type != arg->type)
                {
                    //printf("arg->type = %s, p->type = %s\n", arg->type->toChars(), p->type->toChars());
                    if (arg->op == TOKtype)
                        arg->error("cannot pass type %s as function argument", arg->toChars());
                    arg = arg->implicitCastTo(sc, p->type);
                    arg = arg->optimize(WANTvalue);
                }
            }
            if (p->storageClass & (STCout | STCref))
            {
                // BUG: should check that argument to ref is type 'invariant'
                // BUG: assignments to ref should also be type 'invariant'
                arg = arg->modifiableLvalue(sc, arg);

                //if (arg->op == TOKslice)
                    //arg->error("cannot modify slice %s", arg->toChars());
            }

            // Convert static arrays to pointers
            Type *tb = arg->type->toBasetype();
            if (tb->ty == Tsarray)
            {
                arg = arg->checkToPointer();
            }
#if DMDV2
            if (tb->ty == Tstruct && !(p->storageClass & (STCref | STCout)))
            {
                if (arg->op == TOKcall)
                {
                    /* The struct value returned from the function is transferred
                     * to the function, so the callee should not call the destructor
                     * on it.
                     */
                    valueNoDtor(arg);
                }
                else
                {   /* Not transferring it, so call the copy constructor
                     */
                    arg = callCpCtor(loc, sc, arg, 1);
                }
            }
#endif

            // Convert lazy argument to a delegate
            if (p->storageClass & STClazy)
            {
                arg = arg->toDelegate(sc, p->type);
            }
#if DMDV2
            /* Look for arguments that cannot 'escape' from the called
             * function.
             */
            if (!tf->parameterEscapes(p))
            {
                Expression *a = arg;
                if (a->op == TOKcast)
                    a = ((CastExp *)a)->e1;

                /* Function literals can only appear once, so if this
                 * appearance was scoped, there cannot be any others.
                 */
                if (a->op == TOKfunction)
                {   FuncExp *fe = (FuncExp *)a;
                    fe->fd->tookAddressOf = 0;
                }

                /* For passing a delegate to a scoped parameter,
                 * this doesn't count as taking the address of it.
                 * We only worry about 'escaping' references to the function.
                 */
                else if (a->op == TOKdelegate)
                {   DelegateExp *de = (DelegateExp *)a;
                    if (de->e1->op == TOKvar)
                    {   VarExp *ve = (VarExp *)de->e1;
                        FuncDeclaration *f = ve->var->isFuncDeclaration();
                        if (f)
                        {   f->tookAddressOf--;
                            //printf("tookAddressOf = %d\n", f->tookAddressOf);
                        }
                    }
                }
            }
#endif
        }
        else
        {

            // If not D linkage, do promotions
            if (tf->linkage != LINKd)
            {
                // Promote bytes, words, etc., to ints
                arg = arg->integralPromotions(sc);

                // Promote floats to doubles
                switch (arg->type->ty)
                {
                    case Tfloat32:
                        arg = arg->castTo(sc, Type::tfloat64);
                        break;

                    case Timaginary32:
                        arg = arg->castTo(sc, Type::timaginary64);
                        break;
                }
            }

            // Convert static arrays to dynamic arrays
            // BUG: I don't think this is right for D2
            Type *tb = arg->type->toBasetype();
            if (tb->ty == Tsarray)
            {   TypeSArray *ts = (TypeSArray *)tb;
                Type *ta = ts->next->arrayOf();
                if (ts->size(arg->loc) == 0)
                    arg = new NullExp(arg->loc, ta);
                else
                    arg = arg->castTo(sc, ta);
            }
#if DMDV2
            if (tb->ty == Tstruct)
            {
                arg = callCpCtor(loc, sc, arg);
            }
#endif

            // Give error for overloaded function addresses
#if DMDV2
            if (arg->op == TOKsymoff)
            {   SymOffExp *se = (SymOffExp *)arg;
                if (
                    se->hasOverloads &&
                    !se->var->isFuncDeclaration()->isUnique())
                    arg->error("function %s is overloaded", arg->toChars());
            }
#endif
            arg->rvalue();
        }
        arg = arg->optimize(WANTvalue);
        arguments->data[i] = (void *) arg;
        if (done)
            break;
    }

    // If D linkage and variadic, add _arguments[] as first argument
    if (tf->linkage == LINKd && tf->varargs == 1)
    {
        assert(arguments->dim >= nparams);
        Expression *e = createTypeInfoArray(sc, (Expression **)&arguments->data[nparams],
                arguments->dim - nparams);
        arguments->insert(0, e);
    }
}

/**************************************************
 * Write expression out to buf, but wrap it
 * in ( ) if its precedence is less than pr.
 */

void expToCBuffer(OutBuffer *buf, HdrGenState *hgs, Expression *e, enum PREC pr)
{
#ifdef DEBUG
    if (precedence[e->op] == PREC_zero)
        printf("precedence not defined for token '%s'\n",Token::tochars[e->op]);
#endif
    assert(precedence[e->op] != PREC_zero);
    assert(pr != PREC_zero);

    //if (precedence[e->op] == 0) e->dump(0);
    if (precedence[e->op] < pr ||
        /* Despite precedence, we don't allow a<b<c expressions.
         * They must be parenthesized.
         */
        (pr == PREC_rel && precedence[e->op] == pr))
    {
        buf->writeByte('(');
        e->toCBuffer(buf, hgs);
        buf->writeByte(')');
    }
    else
        e->toCBuffer(buf, hgs);
}

/**************************************************
 * Write out argument list to buf.
 */

void argsToCBuffer(OutBuffer *buf, Expressions *arguments, HdrGenState *hgs)
{
    if (arguments)
    {
        for (size_t i = 0; i < arguments->dim; i++)
        {   Expression *arg = (Expression *)arguments->data[i];

            if (arg)
            {   if (i)
                    buf->writestring(", ");
                expToCBuffer(buf, hgs, arg, PREC_assign);
            }
        }
    }
}

/**************************************************
 * Write out argument types to buf.
 */

void argExpTypesToCBuffer(OutBuffer *buf, Expressions *arguments, HdrGenState *hgs)
{
    if (arguments)
    {   OutBuffer argbuf;

        for (size_t i = 0; i < arguments->dim; i++)
        {   Expression *e = (*arguments)[i];

            if (i)
                buf->writeByte(',');
            argbuf.reset();
            e->type->toCBuffer2(&argbuf, hgs, 0);
            buf->write(&argbuf);
        }
    }
}

/******************************** Expression **************************/

Expression::Expression(Loc loc, enum TOK op, int size)
    : loc(loc)
{
    //printf("Expression::Expression(op = %d) this = %p\n", op, this);
    this->loc = loc;
    this->op = op;
    this->size = size;
    type = NULL;
}

Expression *EXP_CANT_INTERPRET;
Expression *EXP_CONTINUE_INTERPRET;
Expression *EXP_BREAK_INTERPRET;
Expression *EXP_GOTO_INTERPRET;
Expression *EXP_VOID_INTERPRET;

void Expression::init()
{
    EXP_CANT_INTERPRET = new ErrorExp();
    EXP_CONTINUE_INTERPRET = new ErrorExp();
    EXP_BREAK_INTERPRET = new ErrorExp();
    EXP_GOTO_INTERPRET = new ErrorExp();
    EXP_VOID_INTERPRET = new ErrorExp();
}

Expression *Expression::syntaxCopy()
{
    //printf("Expression::syntaxCopy()\n");
    //dump(0);
    return copy();
}

/*********************************
 * Does *not* do a deep copy.
 */

Expression *Expression::copy()
{
    Expression *e;
    if (!size)
    {
#ifdef DEBUG
        fprintf(stdmsg, "No expression copy for: %s\n", toChars());
        printf("op = %d\n", op);
        dump(0);
#endif
        assert(0);
    }
    e = (Expression *)mem.malloc(size);
    //printf("Expression::copy(op = %d) e = %p\n", op, e);
    return (Expression *)memcpy((void*)e, (void*)this, size);
}

/**************************
 * Semantically analyze Expression.
 * Determine types, fold constants, etc.
 */

Expression *Expression::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("Expression::semantic() %s\n", toChars());
#endif
    if (type)
        type = type->semantic(loc, sc);
    else
        type = Type::tvoid;
    return this;
}

/**********************************
 * Try to run semantic routines.
 * If they fail, return NULL.
 */

Expression *Expression::trySemantic(Scope *sc)
{
    //printf("+trySemantic(%s)\n", toChars());
    unsigned errors = global.startGagging();
    Expression *e = semantic(sc);
    if (global.endGagging(errors))
    {
        e = NULL;
    }
    //printf("-trySemantic(%s)\n", toChars());
    return e;
}

void Expression::print()
{
    fprintf(stdmsg, "%s\n", toChars());
    fflush(stdmsg);
}

char *Expression::toChars()
{   OutBuffer *buf;
    HdrGenState hgs;

    memset(&hgs, 0, sizeof(hgs));
    buf = new OutBuffer();
    toCBuffer(buf, &hgs);
    return buf->toChars();
}

void Expression::error(const char *format, ...)
{
    if (type != Type::terror)
    {
        va_list ap;
        va_start(ap, format);
        ::verror(loc, format, ap);
        va_end( ap );
    }
}

void Expression::warning(const char *format, ...)
{
    if (type != Type::terror)
    {
        va_list ap;
        va_start(ap, format);
        ::vwarning(loc, format, ap);
        va_end( ap );
    }
}

void Expression::deprecation(const char *format, ...)
{
    if (type != Type::terror)
    {
        va_list ap;
        va_start(ap, format);
        ::vdeprecation(loc, format, ap);
        va_end( ap );
    }
}

int Expression::rvalue()
{
    if (type && type->toBasetype()->ty == Tvoid)
    {   error("expression %s is void and has no value", toChars());
#if 0
        dump(0);
        halt();
#endif
        if (!global.gag)
            type = Type::terror;
        return 0;
    }
    return 1;
}

Expression *Expression::combine(Expression *e1, Expression *e2)
{
    if (e1)
    {
        if (e2)
        {
            e1 = new CommaExp(e1->loc, e1, e2);
            e1->type = e2->type;
        }
    }
    else
        e1 = e2;
    return e1;
}

dinteger_t Expression::toInteger()
{
    //printf("Expression %s\n", Token::toChars(op));
    error("Integer constant expression expected instead of %s", toChars());
    return 0;
}

uinteger_t Expression::toUInteger()
{
    //printf("Expression %s\n", Token::toChars(op));
    return (uinteger_t)toInteger();
}

real_t Expression::toReal()
{
    error("Floating point constant expression expected instead of %s", toChars());
    return 0;
}

real_t Expression::toImaginary()
{
    error("Floating point constant expression expected instead of %s", toChars());
    return 0;
}

complex_t Expression::toComplex()
{
    error("Floating point constant expression expected instead of %s", toChars());
#ifdef IN_GCC
    return complex_t(real_t(0)); // %% nicer
#else
    return 0;
#endif
}

StringExp *Expression::toString()
{
    return NULL;
}

void Expression::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring(Token::toChars(op));
}

void Expression::toMangleBuffer(OutBuffer *buf)
{
    error("expression %s is not a valid template value argument", toChars());
#ifdef DEBUG
dump(0);
#endif
}

/***************************************
 * Return !=0 if expression is an lvalue.
 */

int Expression::isLvalue()
{
    return 0;
}


/*******************************
 * Give error if we're not an lvalue.
 * If we can, convert expression to be an lvalue.
 */

Expression *Expression::toLvalue(Scope *sc, Expression *e)
{
    if (!e)
        e = this;
    else if (!loc.filename)
        loc = e->loc;
    error("%s is not an lvalue", e->toChars());
    return new ErrorExp();
}

Expression *Expression::modifiableLvalue(Scope *sc, Expression *e)
{
    //printf("Expression::modifiableLvalue() %s, type = %s\n", toChars(), type->toChars());

    // See if this expression is a modifiable lvalue (i.e. not const)
#if DMDV2
    if (type && (!type->isMutable() || !type->isAssignable()))
    {   error("%s is not mutable", e->toChars());
        return new ErrorExp();
    }
#endif
    return toLvalue(sc, e);
}


/************************************
 * Detect cases where pointers to the stack can 'escape' the
 * lifetime of the stack frame.
 */

void Expression::checkEscape()
{
}

void Expression::checkEscapeRef()
{
}

void Expression::checkScalar()
{
    if (!type->isscalar())
        error("'%s' is not a scalar, it is a %s", toChars(), type->toChars());
}

void Expression::checkNoBool()
{
    if (type->toBasetype()->ty == Tbool)
        error("operation not allowed on bool '%s'", toChars());
}

Expression *Expression::checkIntegral()
{
    if (!type->isintegral())
    {   error("'%s' is not of integral type, it is a %s", toChars(), type->toChars());
        return new ErrorExp();
    }
    return this;
}

Expression *Expression::checkArithmetic()
{
    if (!type->isintegral() && !type->isfloating())
    {   if (type->toBasetype() != Type::terror)
            error("'%s' is not of arithmetic type, it is a %s", toChars(), type->toChars());
        return new ErrorExp();
    }
    return this;
}

void Expression::checkDeprecated(Scope *sc, Dsymbol *s)
{
    s->checkDeprecated(loc, sc);
}

#if DMDV2
void Expression::checkPurity(Scope *sc, FuncDeclaration *f)
{
    if (sc->func && sc->func->isPure() && !sc->intypeof && !f->isPure())
        error("pure function '%s' cannot call impure function '%s'\n",
            sc->func->toChars(), f->toChars());
}
#endif

/********************************
 * Check for expressions that have no use.
 * Input:
 *      flag    0 not going to use the result, so issue error message if no
 *                side effects
 *              1 the result of the expression is used, but still check
 *                for useless subexpressions
 *              2 do not issue error messages, just return !=0 if expression
 *                has side effects
 */

int Expression::checkSideEffect(int flag)
{
    if (flag == 0)
    {   if (op == TOKimport)
        {
            error("%s has no effect", toChars());
        }
        else
            error("%s has no effect in expression (%s)",
                Token::toChars(op), toChars());
    }
    return 0;
}

/*****************************
 * Check that expression can be tested for true or false.
 */

Expression *Expression::checkToBoolean()
{
    // Default is 'yes' - do nothing

#ifdef DEBUG
    if (!type)
        dump(0);
#endif

    if (!type->checkBoolean())
    {
        error("expression %s of type %s does not have a boolean value", toChars(), type->toChars());
    }
    return this;
}

/****************************
 */

Expression *Expression::checkToPointer()
{
    Expression *e;
    Type *tb;

    //printf("Expression::checkToPointer()\n");
    e = this;

    // If C static array, convert to pointer
    tb = type->toBasetype();
    if (tb->ty == Tsarray)
    {   TypeSArray *ts = (TypeSArray *)tb;
        if (ts->size(loc) == 0)
            e = new NullExp(loc);
        else
            e = new AddrExp(loc, this);
        e->type = ts->next->pointerTo();
    }
    return e;
}

/******************************
 * Take address of expression.
 */

Expression *Expression::addressOf(Scope *sc)
{
    Expression *e;
    Type *t = type;

    //printf("Expression::addressOf()\n");
    e = toLvalue(sc, NULL);
    e = new AddrExp(loc, e);
    e->type = t->pointerTo();
    return e;
}

/******************************
 * If this is a reference, dereference it.
 */

Expression *Expression::deref()
{
    //printf("Expression::deref()\n");
    // type could be null if forward referencing an 'auto' variable
    if (type && type->ty == Treference)
    {
        Expression *e = new PtrExp(loc, this);
        e->type = ((TypeReference *)type)->next;
        return e;
    }
    return this;
}

/********************************
 * Does this expression statically evaluate to a boolean TRUE or FALSE?
 */

int Expression::isBool(int result)
{
    return FALSE;
}

/********************************
 * Does this expression result in either a 1 or a 0?
 */

int Expression::isBit()
{
    return FALSE;
}

/********************************
 * Can this expression throw an exception?
 * Valid only after semantic() pass.
 */

int Expression::canThrow()
{
#if DMDV2
    return FALSE;
#else
    return TRUE;
#endif
}


/****************************************
 * Resolve __FILE__, __LINE__ to loc.
 */

Expression *Expression::resolveLoc(Loc loc, Scope *sc)
{
    return this;
}


Expressions *Expression::arraySyntaxCopy(Expressions *exps)
{   Expressions *a = NULL;

    if (exps)
    {
        a = new Expressions();
        a->setDim(exps->dim);
        for (size_t i = 0; i < a->dim; i++)
        {   Expression *e = (Expression *)exps->data[i];

            if (e)
                e = e->syntaxCopy();
            a->data[i] = e;
        }
    }
    return a;
}

/******************************** IntegerExp **************************/

IntegerExp::IntegerExp(Loc loc, dinteger_t value, Type *type)
        : Expression(loc, TOKint64, sizeof(IntegerExp))
{
    //printf("IntegerExp(value = %lld, type = '%s')\n", value, type ? type->toChars() : "");
    if (type && !type->isscalar())
    {
        //printf("%s, loc = %d\n", toChars(), loc.linnum);
        if (type->ty != Terror)
            error("integral constant must be scalar type, not %s", type->toChars());
        type = Type::terror;
    }
    this->type = type;
    this->value = value;
}

IntegerExp::IntegerExp(dinteger_t value)
        : Expression(0, TOKint64, sizeof(IntegerExp))
{
    this->type = Type::tint32;
    this->value = value;
}

int IntegerExp::equals(Object *o)
{   IntegerExp *ne;

    if (this == o ||
        (((Expression *)o)->op == TOKint64 &&
         ((ne = (IntegerExp *)o), type->equals(ne->type)) &&
         value == ne->value))
        return 1;
    return 0;
}

char *IntegerExp::toChars()
{
#if 1
    return Expression::toChars();
#else
    static char buffer[sizeof(value) * 3 + 1];

    sprintf(buffer, "%jd", value);
    return buffer;
#endif
}

dinteger_t IntegerExp::toInteger()
{   Type *t;

    t = type;
    while (t)
    {
        switch (t->ty)
        {
            case Tbit:
            case Tbool:         value = (value != 0);           break;
            case Tint8:         value = (d_int8)  value;        break;
            case Tchar:
            case Tuns8:         value = (d_uns8)  value;        break;
            case Tint16:        value = (d_int16) value;        break;
            case Twchar:
            case Tuns16:        value = (d_uns16) value;        break;
            case Tint32:        value = (d_int32) value;        break;
            case Tdchar:
            case Tuns32:        value = (d_uns32) value;        break;
            case Tint64:        value = (d_int64) value;        break;
            case Tuns64:        value = (d_uns64) value;        break;
            case Tpointer:
                if (Target::ptrsize == 4)
                    value = (d_uns32) value;
                else if (Target::ptrsize == 8)
                    value = (d_uns64) value;
                else
                    assert(0);
                break;

            case Tenum:
            {
                TypeEnum *te = (TypeEnum *)t;
                t = te->sym->memtype;
                continue;
            }

            case Ttypedef:
            {
                TypeTypedef *tt = (TypeTypedef *)t;
                t = tt->sym->basetype;
                continue;
            }

            default:
                /* This can happen if errors, such as
                 * the type is painted on like in fromConstInitializer().
                 */
                if (!global.errors)
                {   type->print();
                    assert(0);
                }
                break;
        }
        break;
    }
    return value;
}

real_t IntegerExp::toReal()
{
    Type *t;

    toInteger();
    t = type->toBasetype();
    if (t->ty == Tuns64)
        return (real_t)(d_uns64)value;
    else
        return (real_t)(d_int64)value;
}

real_t IntegerExp::toImaginary()
{
    return (real_t) 0;
}

complex_t IntegerExp::toComplex()
{
    return toReal();
}

int IntegerExp::isBool(int result)
{
    int r = toInteger() != 0;
    return result ? r : !r;
}

Expression *IntegerExp::semantic(Scope *sc)
{
    if (!type)
    {
        // Determine what the type of this number is
        dinteger_t number = value;

        if (number & 0x8000000000000000LL)
            type = Type::tuns64;
        else if (number & 0xFFFFFFFF80000000LL)
            type = Type::tint64;
        else
            type = Type::tint32;
    }
    else
    {   if (!type->deco)
            type = type->semantic(loc, sc);
    }
    return this;
}

Expression *IntegerExp::toLvalue(Scope *sc, Expression *e)
{
    if (!e)
        e = this;
    else if (!loc.filename)
        loc = e->loc;
    e->error("constant %s is not an lvalue", e->toChars());
    return this;
}

void IntegerExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    dinteger_t v = toInteger();

    if (type)
    {   Type *t = type;

      L1:
        switch (t->ty)
        {
            case Tenum:
            {   TypeEnum *te = (TypeEnum *)t;
                buf->printf("cast(%s)", te->sym->toChars());
                t = te->sym->memtype;
                goto L1;
            }

            case Ttypedef:
            {   TypeTypedef *tt = (TypeTypedef *)t;
                buf->printf("cast(%s)", tt->sym->toChars());
                t = tt->sym->basetype;
                goto L1;
            }

            case Twchar:        // BUG: need to cast(wchar)
            case Tdchar:        // BUG: need to cast(dchar)
                if ((uinteger_t)v > 0xFF)
                {
                     buf->printf("'\\U%08x'", v);
                     break;
                }
            case Tchar:
            {
                unsigned o = buf->offset;
                if (v == '\'')
                    buf->writestring("'\\''");
                else if (isprint(v) && v != '\\')
                    buf->printf("'%c'", (int)v);
                else
                    buf->printf("'\\x%02x'", (int)v);
                if (hgs->ddoc)
                    escapeDdocString(buf, o);
                break;
            }

            case Tint8:
                buf->writestring("cast(byte)");
                goto L2;

            case Tint16:
                buf->writestring("cast(short)");
                goto L2;

            case Tint32:
            L2:
                buf->printf("%d", (int)v);
                break;

            case Tuns8:
                buf->writestring("cast(ubyte)");
                goto L3;

            case Tuns16:
                buf->writestring("cast(ushort)");
                goto L3;

            case Tuns32:
            L3:
                buf->printf("%du", (unsigned)v);
                break;

            case Tint64:
                buf->printf("%jdL", v);
                break;

            case Tuns64:
            L4:
                buf->printf("%juLU", v);
                break;

            case Tbit:
            case Tbool:
                buf->writestring((char *)(v ? "true" : "false"));
                break;

            case Tpointer:
                buf->writestring("cast(");
                buf->writestring(t->toChars());
                buf->writeByte(')');
                if (Target::ptrsize == 4)
                    goto L3;
                else if (Target::ptrsize == 8)
                    goto L4;
                else
                    assert(0);

            default:
                /* This can happen if errors, such as
                 * the type is painted on like in fromConstInitializer().
                 */
                if (!global.errors)
                {
#ifdef DEBUG
                    t->print();
#endif
                    assert(0);
                }
                break;
        }
    }
    else if (v & 0x8000000000000000LL)
        buf->printf("0x%jx", v);
    else
        buf->printf("%jd", v);
}

void IntegerExp::toMangleBuffer(OutBuffer *buf)
{
    if ((sinteger_t)value < 0)
        buf->printf("N%jd", -value);
    else
    {
        /* This is an awful hack to maintain backwards compatibility.
         * There really always should be an 'i' before a number, but
         * there wasn't in earlier implementations, so to maintain
         * backwards compatibility it is only done if necessary to disambiguate.
         * See bugzilla 3029
         */
        if (buf->offset > 0 && isdigit(buf->data[buf->offset - 1]))
            buf->writeByte('i');

        buf->printf("%jd", value);
    }
}

/******************************** ErrorExp **************************/

/* Use this expression for error recovery.
 * It should behave as a 'sink' to prevent further cascaded error messages.
 */

ErrorExp::ErrorExp()
    : IntegerExp(0, 0, Type::terror)
{
    op = TOKerror;
}

void ErrorExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("__error");
}

/******************************** RealExp **************************/

RealExp::RealExp(Loc loc, real_t value, Type *type)
        : Expression(loc, TOKfloat64, sizeof(RealExp))
{
    //printf("RealExp::RealExp(%Lg)\n", value);
    this->value = value;
    this->type = type;
}

char *RealExp::toChars()
{
    char buffer[sizeof(value) * 3 + 8 + 1 + 1];

#ifdef IN_GCC
    value.format(buffer, sizeof(buffer));
    if (type->isimaginary())
        strcat(buffer, "i");
#else
    sprintf(buffer, type->isimaginary() ? "%Lgi" : "%Lg", value);
#endif
    assert(strlen(buffer) < sizeof(buffer));
    return mem.strdup(buffer);
}

dinteger_t RealExp::toInteger()
{
#ifdef IN_GCC
    return toReal().toInt();
#else
    return (sinteger_t) toReal();
#endif
}

uinteger_t RealExp::toUInteger()
{
#ifdef IN_GCC
    return (uinteger_t) toReal().toInt();
#else
    return (uinteger_t) toReal();
#endif
}

real_t RealExp::toReal()
{
    return type->isreal() ? value : 0;
}

real_t RealExp::toImaginary()
{
    return type->isreal() ? 0 : value;
}

complex_t RealExp::toComplex()
{
#ifdef __DMC__
    return toReal() + toImaginary() * I;
#else
    return complex_t(toReal(), toImaginary());
#endif
}

/********************************
 * Test to see if two reals are the same.
 * Regard NaN's as equivalent.
 * Regard +0 and -0 as different.
 */

int RealEquals(real_t x1, real_t x2)
{
    return (Port::isNan(x1) && Port::isNan(x2)) ||
        /* In some cases, the REALPAD bytes get garbage in them,
         * so be sure and ignore them.
         */
        memcmp(&x1, &x2, Target::realsize - Target::realpad) == 0;
}

int RealExp::equals(Object *o)
{   RealExp *ne;

    if (this == o ||
        (((Expression *)o)->op == TOKfloat64 &&
         ((ne = (RealExp *)o), type->equals(ne->type)) &&
         RealEquals(value, ne->value)
        )
       )
        return 1;
    return 0;
}

Expression *RealExp::semantic(Scope *sc)
{
    if (!type)
        type = Type::tfloat64;
    else
        type = type->semantic(loc, sc);
    return this;
}

int RealExp::isBool(int result)
{
#ifdef IN_GCC
    return result ? (! value.isZero()) : (value.isZero());
#else
    return result ? (value != 0)
                  : (value == 0);
#endif
}

void floatToBuffer(OutBuffer *buf, Type *type, real_t value)
{
    /* In order to get an exact representation, try converting it
     * to decimal then back again. If it matches, use it.
     * If it doesn't, fall back to hex, which is
     * always exact.
     */
    char buffer[25];
    sprintf(buffer, "%Lg", value);
    assert(strlen(buffer) < sizeof(buffer));
#if _WIN32 && __DMC__
    const char *save = __locale_decpoint;
    __locale_decpoint = ".";
    real_t r = strtold(buffer, NULL);
    __locale_decpoint = save;
#else
    real_t r = strtold(buffer, NULL);
#endif
    if (r == value)                     // if exact duplication
        buf->writestring(buffer);
    else
        buf->printf("%La", value);      // ensure exact duplication

    if (type)
    {
        Type *t = type->toBasetype();
        switch (t->ty)
        {
            case Tfloat32:
            case Timaginary32:
            case Tcomplex32:
                buf->writeByte('F');
                break;

            case Tfloat80:
            case Timaginary80:
            case Tcomplex80:
                buf->writeByte('L');
                break;

            default:
                break;
        }
        if (t->isimaginary())
            buf->writeByte('i');
    }
}

void RealExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    floatToBuffer(buf, type, value);
}

void realToMangleBuffer(OutBuffer *buf, real_t value)
{
    /* Rely on %A to get portable mangling.
     * Must munge result to get only identifier characters.
     *
     * Possible values from %A  => mangled result
     * NAN                      => NAN
     * -INF                     => NINF
     * INF                      => INF
     * -0X1.1BC18BA997B95P+79   => N11BC18BA997B95P79
     * 0X1.9P+2                 => 19P2
     */

    if (Port::isNan(value))
        buf->writestring("NAN");        // no -NAN bugs
    else
    {
        char buffer[36];
        int n = sprintf(buffer, "%LA", value);
        assert(n > 0 && n < sizeof(buffer));
        for (int i = 0; i < n; i++)
        {   char c = buffer[i];

            switch (c)
            {
                case '-':
                    buf->writeByte('N');
                    break;

                case '+':
                case 'X':
                case '.':
                    break;

                case '0':
                    if (i < 2)
                        break;          // skip leading 0X
                default:
                    buf->writeByte(c);
                    break;
            }
        }
    }
}

void RealExp::toMangleBuffer(OutBuffer *buf)
{
    buf->writeByte('e');
    realToMangleBuffer(buf, value);
}


/******************************** ComplexExp **************************/

ComplexExp::ComplexExp(Loc loc, complex_t value, Type *type)
        : Expression(loc, TOKcomplex80, sizeof(ComplexExp))
{
    this->value = value;
    this->type = type;
    //printf("ComplexExp::ComplexExp(%s)\n", toChars());
}

char *ComplexExp::toChars()
{
    char buffer[sizeof(value) * 3 + 8 + 1];

    char buf1[sizeof(value) * 3 + 8 + 1];
    char buf2[sizeof(value) * 3 + 8 + 1];
#ifdef IN_GCC
    creall(value).format(buf1, sizeof(buf1));
    cimagl(value).format(buf2, sizeof(buf2));
#else
    ld_sprint(buf1, 'g', creall(value));
    ld_sprint(buf2, 'g', cimagl(value));
#endif
    sprintf(buffer, "(%s+%si)", buf1, buf2);
    assert(strlen(buffer) < sizeof(buffer));
    return mem.strdup(buffer);
}

dinteger_t ComplexExp::toInteger()
{
#ifdef IN_GCC
    return (sinteger_t) toReal().toInt();
#else
    return (sinteger_t) toReal();
#endif
}

uinteger_t ComplexExp::toUInteger()
{
#ifdef IN_GCC
    return (uinteger_t) toReal().toInt();
#else
    return (uinteger_t) toReal();
#endif
}

real_t ComplexExp::toReal()
{
    return creall(value);
}

real_t ComplexExp::toImaginary()
{
    return cimagl(value);
}

complex_t ComplexExp::toComplex()
{
    return value;
}

int ComplexExp::equals(Object *o)
{   ComplexExp *ne;

    if (this == o ||
        (((Expression *)o)->op == TOKcomplex80 &&
         ((ne = (ComplexExp *)o), type->equals(ne->type)) &&
         RealEquals(creall(value), creall(ne->value)) &&
         RealEquals(cimagl(value), cimagl(ne->value))
        )
       )
        return 1;
    return 0;
}

Expression *ComplexExp::semantic(Scope *sc)
{
    if (!type)
        type = Type::tcomplex80;
    else
        type = type->semantic(loc, sc);
    return this;
}

int ComplexExp::isBool(int result)
{
    if (result)
        return (bool)(value);
    else
        return !value;
}

void ComplexExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    /* Print as:
     *  (re+imi)
     */
#ifdef IN_GCC
    char buf1[sizeof(value) * 3 + 8 + 1];
    char buf2[sizeof(value) * 3 + 8 + 1];
    creall(value).format(buf1, sizeof(buf1));
    cimagl(value).format(buf2, sizeof(buf2));
    buf->printf("(%s+%si)", buf1, buf2);
#else
    buf->writeByte('(');
    floatToBuffer(buf, type, creall(value));
    buf->writeByte('+');
    floatToBuffer(buf, type, cimagl(value));
    buf->writestring("i)");
#endif
}

void ComplexExp::toMangleBuffer(OutBuffer *buf)
{
    buf->writeByte('c');
    real_t r = toReal();
    realToMangleBuffer(buf, r);
    buf->writeByte('c');        // separate the two
    r = toImaginary();
    realToMangleBuffer(buf, r);
}

/******************************** IdentifierExp **************************/

IdentifierExp::IdentifierExp(Loc loc, Identifier *ident)
        : Expression(loc, TOKidentifier, sizeof(IdentifierExp))
{
    this->ident = ident;
}

Expression *IdentifierExp::semantic(Scope *sc)
{
    Dsymbol *s;
    Dsymbol *scopesym;

#if LOGSEMANTIC
    printf("IdentifierExp::semantic('%s')\n", ident->toChars());
#endif
    s = sc->search(loc, ident, &scopesym);
    if (s)
    {   Expression *e;
        WithScopeSymbol *withsym;

        /* See if the symbol was a member of an enclosing 'with'
         */
        withsym = scopesym->isWithScopeSymbol();
        if (withsym)
        {
            s = s->toAlias();

            // Same as wthis.ident
            if (s->needThis() || s->isTemplateDeclaration())
            {
                e = new VarExp(loc, withsym->withstate->wthis);
                e = new DotIdExp(loc, e, ident);
            }
            else
            {   Type *t = withsym->withstate->wthis->type;
                if (t->ty == Tpointer)
                    t = ((TypePointer *)t)->next;
                e = typeDotIdExp(loc, t, ident);
            }
        }
        else
        {
            if (!s->parent && scopesym->isArrayScopeSymbol())
            {   // Kludge to run semantic() here because
                // ArrayScopeSymbol::search() doesn't have access to sc.
                s->semantic(sc);
            }
            /* If f is really a function template,
             * then replace f with the function template declaration.
             */
            FuncDeclaration *f = s->isFuncDeclaration();
            if (f)
            {   TemplateDeclaration *tempdecl = getFuncTemplateDecl(f);
                if (tempdecl)
                {
                    if (tempdecl->overroot)         // if not start of overloaded list of TemplateDeclaration's
                        tempdecl = tempdecl->overroot; // then get the start
                    e = new TemplateExp(loc, tempdecl);
                    e = e->semantic(sc);
                    return e;
                }
            }
            e = new DsymbolExp(loc, s);
        }
        return e->semantic(sc);
    }
#if DMDV2
    if (ident == Id::ctfe)
    {  // Create the magic __ctfe bool variable
       VarDeclaration *vd = new VarDeclaration(loc, Type::tbool, Id::ctfe, NULL);
       Expression *e = new VarExp(loc, vd);
       e = e->semantic(sc);
       return e;
    }
#endif
    const char *n = importHint(ident->toChars());
    if (n)
        error("'%s' is not defined, perhaps you need to import %s; ?", ident->toChars(), n);
    else
    {
        s = sc->search_correct(ident);
        if (s)
            error("undefined identifier %s, did you mean %s %s?", ident->toChars(), s->kind(), s->toChars());
        else
            error("undefined identifier %s", ident->toChars());
    }
    return new ErrorExp();
}

char *IdentifierExp::toChars()
{
    return ident->toChars();
}

void IdentifierExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    if (hgs->hdrgen)
        buf->writestring(ident->toHChars2());
    else
        buf->writestring(ident->toChars());
}


int IdentifierExp::isLvalue()
{
    return 1;
}


Expression *IdentifierExp::toLvalue(Scope *sc, Expression *e)
{
#if 0
    tym = tybasic(e1->ET->Tty);
    if (!(tyscalar(tym) ||
          tym == TYstruct ||
          tym == TYarray && e->Eoper == TOKaddr))
            synerr(EM_lvalue);  // lvalue expected
#endif
    return this;
}

/******************************** DollarExp **************************/

DollarExp::DollarExp(Loc loc)
        : IdentifierExp(loc, Id::dollar)
{
}

/******************************** DsymbolExp **************************/

DsymbolExp::DsymbolExp(Loc loc, Dsymbol *s)
        : Expression(loc, TOKdsymbol, sizeof(DsymbolExp))
{
    this->s = s;
}

Expression *DsymbolExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("DsymbolExp::semantic('%s')\n", s->toChars());
#endif

Lagain:
    EnumMember *em;
    Expression *e;
    VarDeclaration *v;
    FuncDeclaration *f;
    FuncLiteralDeclaration *fld;
    ClassDeclaration *cd;
    ClassDeclaration *thiscd = NULL;
    Import *imp;
    Package *pkg;
    Type *t;

    //printf("DsymbolExp:: %p '%s' is a symbol\n", this, toChars());
    //printf("s = '%s', s->kind = '%s'\n", s->toChars(), s->kind());
    if (type && !s->needThis())
        return this;
    if (!s->isFuncDeclaration())        // functions are checked after overloading
        checkDeprecated(sc, s);
    Dsymbol *olds = s;
    s = s->toAlias();
    //printf("s = '%s', s->kind = '%s', s->needThis() = %p\n", s->toChars(), s->kind(), s->needThis());
    if (s != olds && !s->isFuncDeclaration())
        checkDeprecated(sc, s);

    if (sc->func)
        thiscd = sc->func->parent->isClassDeclaration();

    // BUG: This should happen after overload resolution for functions, not before
    if (s->needThis())
    {
        if (hasThis(sc)
#if DMDV2
                && !s->isFuncDeclaration()
#endif
            )
        {
            // Supply an implicit 'this', as in
            //    this.ident

            DotVarExp *de;

            de = new DotVarExp(loc, new ThisExp(loc), s->isDeclaration());
            return de->semantic(sc);
        }
    }

    em = s->isEnumMember();
    if (em)
    {
        e = em->value->copy();
        e->loc = loc;
        e = e->semantic(sc);
        return e;
    }
    v = s->isVarDeclaration();
    if (v)
    {
        //printf("Identifier '%s' is a variable, type '%s'\n", toChars(), v->type->toChars());
        if (!type)
        {   if ((!v->type || !v->type->deco) && v->scope)
                v->semantic(v->scope);
            type = v->type;
            if (!v->type)
            {   error("forward reference of %s %s", v->kind(), v->toChars());
                return new ErrorExp();
            }
        }
        if (v->isConst() && type->toBasetype()->ty != Tsarray)
        {
            if (v->init)
            {
                if (v->inuse)
                {
                    error("circular reference to '%s'", v->toChars());
                    return new ErrorExp();
                }
                ExpInitializer *ei = v->init->isExpInitializer();
                if (ei)
                {
                    e = ei->exp->copy();        // make copy so we can change loc
                    if (e->op == TOKstring || !e->type)
                        e = e->semantic(sc);
                    e = e->implicitCastTo(sc, type);
                    e->loc = loc;
                    return e;
                }
            }
            else
            {
                e = type->defaultInit();
                e->loc = loc;
                return e;
            }
        }
        e = new VarExp(loc, v);
        e->type = type;
        e = e->semantic(sc);
        return e->deref();
    }
    fld = s->isFuncLiteralDeclaration();
    if (fld)
    {   //printf("'%s' is a function literal\n", fld->toChars());
        e = new FuncExp(loc, fld);
        return e->semantic(sc);
    }
    f = s->isFuncDeclaration();
    if (f)
    {   //printf("'%s' is a function\n", f->toChars());

        if (!f->originalType && f->scope)       // semantic not yet run
        {
            unsigned oldgag = global.gag;
            if (global.isSpeculativeGagging() && !f->isSpeculative())
                global.gag = 0;
            f->semantic(f->scope);
            global.gag = oldgag;
        }

#if DMDV2
        // if inferring return type, sematic3 needs to be run
        if (f->inferRetType && f->scope && f->type && !f->type->nextOf())
        {
            TemplateInstance *spec = f->isSpeculative();
            int olderrs = global.errors;
            f->semantic3(f->scope);
            // Update the template instantiation with the number
            // of errors which occured.
            if (spec && global.errors != olderrs)
                spec->errors = global.errors - olderrs;
        }
#endif

        if (f->isUnitTestDeclaration())
        {
            error("cannot call unittest function %s", toChars());
            return new ErrorExp();
        }
        if (!f->type->deco)
        {
            error("forward reference to %s", toChars());
            return new ErrorExp();
        }
        return new VarExp(loc, f);
    }
    cd = s->isClassDeclaration();
    if (cd && thiscd && cd->isBaseOf(thiscd, NULL) && sc->func->needThis())
    {
        // We need to add an implicit 'this' if cd is this class or a base class.
        DotTypeExp *dte;

        dte = new DotTypeExp(loc, new ThisExp(loc), s);
        return dte->semantic(sc);
    }
    imp = s->isImport();
    if (imp)
    {
        if (!imp->pkg)
        {   error("forward reference of import %s", imp->toChars());
            return new ErrorExp();
        }
        ScopeExp *ie = new ScopeExp(loc, imp->pkg);
        return ie->semantic(sc);
    }
    pkg = s->isPackage();
    if (pkg)
    {
        ScopeExp *ie;

        ie = new ScopeExp(loc, pkg);
        return ie->semantic(sc);
    }
    Module *mod = s->isModule();
    if (mod)
    {
        ScopeExp *ie;

        ie = new ScopeExp(loc, mod);
        return ie->semantic(sc);
    }

    t = s->getType();
    if (t)
    {
        TypeExp *te = new TypeExp(loc, t);
        return te->semantic(sc);
    }

    TupleDeclaration *tup = s->isTupleDeclaration();
    if (tup)
    {
        for (size_t i = 0; i < tup->objects->dim; i++)
        {
            Dsymbol *sa = getDsymbol((*tup->objects)[i]);
            if (sa && sa->needThis())
            {
                if (hasThis(sc)
#if DMDV2
                        && !sa->isFuncDeclaration()
#endif
                    )
                {
                    // Supply an implicit 'this', as in
                    //    this.ident
                    (*tup->objects)[i] = new DotVarExp(loc, new ThisExp(loc), sa->isDeclaration());
                }
            }
        }

        e = new TupleExp(loc, tup);
        e = e->semantic(sc);
        return e;
    }

    TemplateInstance *ti = s->isTemplateInstance();
    if (ti)
    {   if (!ti->semanticRun)
            ti->semantic(sc);
        s = ti->toAlias();
        if (!s->isTemplateInstance())
            goto Lagain;
        if (ti->errors)
            return new ErrorExp();
        e = new ScopeExp(loc, ti);
        e = e->semantic(sc);
        return e;
    }

    TemplateDeclaration *td = s->isTemplateDeclaration();
    if (td)
    {
        e = new TemplateExp(loc, td);
        e = e->semantic(sc);
        return e;
    }

    error("%s '%s' is not a variable", s->kind(), s->toChars());
    return new ErrorExp();
}

char *DsymbolExp::toChars()
{
    return s->toChars();
}

void DsymbolExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring(s->toChars());
}


int DsymbolExp::isLvalue()
{
    return 1;
}


Expression *DsymbolExp::toLvalue(Scope *sc, Expression *e)
{
#if 0
    tym = tybasic(e1->ET->Tty);
    if (!(tyscalar(tym) ||
          tym == TYstruct ||
          tym == TYarray && e->Eoper == TOKaddr))
            synerr(EM_lvalue);  // lvalue expected
#endif
    return this;
}

/******************************** ThisExp **************************/

ThisExp::ThisExp(Loc loc)
        : Expression(loc, TOKthis, sizeof(ThisExp))
{
    //printf("ThisExp::ThisExp() loc = %d\n", loc.linnum);
    var = NULL;
}

Expression *ThisExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("ThisExp::semantic()\n");
#endif
    if (type)
    {   //assert(global.errors || var);
        return this;
    }

    FuncDeclaration *fd = hasThis(sc);  // fd is the uplevel function with the 'this' variable

    /* Special case for typeof(this) and typeof(super) since both
     * should work even if they are not inside a non-static member function
     */
    if (!fd && sc->intypeof)
    {
        // Find enclosing struct or class
        for (Dsymbol *s = sc->getStructClassScope(); 1; s = s->parent)
        {
            if (!s)
            {
                error("%s is not in a class or struct scope", toChars());
                goto Lerr;
            }
            ClassDeclaration *cd = s->isClassDeclaration();
            if (cd)
            {
                type = cd->type;
                return this;
            }
            StructDeclaration *sd = s->isStructDeclaration();
            if (sd)
            {
#if STRUCTTHISREF
                type = sd->type;
#else
                type = sd->type->pointerTo();
#endif
                return this;
            }
        }
    }
    if (!fd)
        goto Lerr;

    assert(fd->vthis);
    var = fd->vthis;
    assert(var->parent);
    type = var->type;
    var->isVarDeclaration()->checkNestedReference(sc, loc);
    if (!sc->intypeof)
        sc->callSuper |= CSXthis;
    return this;

Lerr:
    error("'this' is only defined in non-static member functions, not %s", sc->parent->toChars());
    return new ErrorExp();
}

int ThisExp::isBool(int result)
{
    return result ? TRUE : FALSE;
}

void ThisExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("this");
}


int ThisExp::isLvalue()
{
    return 1;
}


Expression *ThisExp::toLvalue(Scope *sc, Expression *e)
{
    return this;
}

/******************************** SuperExp **************************/

SuperExp::SuperExp(Loc loc)
        : ThisExp(loc)
{
    op = TOKsuper;
}

Expression *SuperExp::semantic(Scope *sc)
{
    ClassDeclaration *cd;
    Dsymbol *s;

#if LOGSEMANTIC
    printf("SuperExp::semantic('%s')\n", toChars());
#endif
    if (type)
        return this;

    FuncDeclaration *fd = hasThis(sc);

    /* Special case for typeof(this) and typeof(super) since both
     * should work even if they are not inside a non-static member function
     */
    if (!fd && sc->intypeof)
    {
        // Find enclosing class
        for (Dsymbol *s = sc->getStructClassScope(); 1; s = s->parent)
        {
            if (!s)
            {
                error("%s is not in a class scope", toChars());
                goto Lerr;
            }
            ClassDeclaration *cd = s->isClassDeclaration();
            if (cd)
            {
                cd = cd->baseClass;
                if (!cd)
                {   error("class %s has no 'super'", s->toChars());
                    goto Lerr;
                }
                type = cd->type;
                return this;
            }
        }
    }
    if (!fd)
        goto Lerr;

    assert(fd->vthis);
    var = fd->vthis;
    assert(var->parent);

    s = fd->toParent();
    while (s && s->isTemplateInstance())
        s = s->toParent();
    assert(s);
    cd = s->isClassDeclaration();
//printf("parent is %s %s\n", fd->toParent()->kind(), fd->toParent()->toChars());
    if (!cd)
        goto Lerr;
    if (!cd->baseClass)
    {
        error("no base class for %s", cd->toChars());
        type = fd->vthis->type;
    }
    else
    {
        type = cd->baseClass->type;
#if DMDV2
        type = type->castMod(var->type->mod);
#endif
    }

    var->isVarDeclaration()->checkNestedReference(sc, loc);

    if (!sc->intypeof)
        sc->callSuper |= CSXsuper;
    return this;


Lerr:
    error("'super' is only allowed in non-static class member functions");
    return new ErrorExp();
}

void SuperExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("super");
}


/******************************** NullExp **************************/

NullExp::NullExp(Loc loc, Type *type)
        : Expression(loc, TOKnull, sizeof(NullExp))
{
    committed = 0;
    this->type = type;
}

Expression *NullExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("NullExp::semantic('%s')\n", toChars());
#endif
    // NULL is the same as (void *)0
    if (!type)
        type = Type::tvoid->pointerTo();
    return this;
}

int NullExp::isBool(int result)
{
    return result ? FALSE : TRUE;
}

StringExp *NullExp::toString()
{
    if (implicitConvTo(Type::tstring))
    {
        StringExp *se = new StringExp(loc, (char*)mem.calloc(1, 1), 0);
        se->type = Type::tstring;
        return se;
    }
    return NULL;
}

void NullExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("null");
}

void NullExp::toMangleBuffer(OutBuffer *buf)
{
    buf->writeByte('n');
}

/******************************** StringExp **************************/

StringExp::StringExp(Loc loc, char *string)
        : Expression(loc, TOKstring, sizeof(StringExp))
{
    this->string = string;
    this->len = strlen(string);
    this->sz = 1;
    this->committed = 0;
    this->postfix = 0;
    this->ownedByCtfe = false;
}

StringExp::StringExp(Loc loc, void *string, size_t len)
        : Expression(loc, TOKstring, sizeof(StringExp))
{
    this->string = string;
    this->len = len;
    this->sz = 1;
    this->committed = 0;
    this->postfix = 0;
    this->ownedByCtfe = false;
}

StringExp::StringExp(Loc loc, void *string, size_t len, unsigned char postfix)
        : Expression(loc, TOKstring, sizeof(StringExp))
{
    this->string = string;
    this->len = len;
    this->sz = 1;
    this->committed = 0;
    this->postfix = postfix;
    this->ownedByCtfe = false;
}

#if 0
Expression *StringExp::syntaxCopy()
{
    printf("StringExp::syntaxCopy() %s\n", toChars());
    return copy();
}
#endif

int StringExp::equals(Object *o)
{
    //printf("StringExp::equals('%s') %s\n", o->toChars(), toChars());
    if (o && o->dyncast() == DYNCAST_EXPRESSION)
    {   Expression *e = (Expression *)o;

        if (e->op == TOKstring)
        {
            return compare(o) == 0;
        }
    }
    return FALSE;
}

char *StringExp::toChars()
{
    OutBuffer buf;
    HdrGenState hgs;
    char *p;

    memset(&hgs, 0, sizeof(hgs));
    toCBuffer(&buf, &hgs);
    buf.writeByte(0);
    p = (char *)buf.data;
    buf.data = NULL;
    return p;
}

Expression *StringExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("StringExp::semantic() %s\n", toChars());
#endif
    if (!type)
    {   OutBuffer buffer;
        size_t newlen = 0;
        const char *p;
        size_t u;
        unsigned c;

        switch (postfix)
        {
            case 'd':
                for (u = 0; u < len;)
                {
                    p = utf_decodeChar((unsigned char *)string, len, &u, &c);
                    if (p)
                    {   error("%s", p);
                        return new ErrorExp();
                    }
                    else
                    {   buffer.write4(c);
                        newlen++;
                    }
                }
                buffer.write4(0);
                string = buffer.extractData();
                len = newlen;
                sz = 4;
                type = new TypeSArray(Type::tdchar, new IntegerExp(loc, len, Type::tindex));
                committed = 1;
                break;

            case 'w':
                for (u = 0; u < len;)
                {
                    p = utf_decodeChar((unsigned char *)string, len, &u, &c);
                    if (p)
                    {   error("%s", p);
                        return new ErrorExp();
                    }
                    else
                    {   buffer.writeUTF16(c);
                        newlen++;
                        if (c >= 0x10000)
                            newlen++;
                    }
                }
                buffer.writeUTF16(0);
                string = buffer.extractData();
                len = newlen;
                sz = 2;
                type = new TypeSArray(Type::twchar, new IntegerExp(loc, len, Type::tindex));
                committed = 1;
                break;

            case 'c':
                committed = 1;
            default:
                type = new TypeSArray(Type::tchar, new IntegerExp(loc, len, Type::tindex));
                break;
        }
        type = type->semantic(loc, sc);
    }
    return this;
}

/**********************************
 * Return length of string.
 */

size_t StringExp::length()
{
    size_t result = 0;
    dchar_t c;
    const char *p;

    switch (sz)
    {
        case 1:
            for (size_t u = 0; u < len;)
            {
                p = utf_decodeChar((unsigned char *)string, len, &u, &c);
                if (p)
                {   error("%s", p);
                    return 0;
                }
                else
                    result++;
            }
            break;

        case 2:
            for (size_t u = 0; u < len;)
            {
                p = utf_decodeWchar((unsigned short *)string, len, &u, &c);
                if (p)
                {   error("%s", p);
                    return 0;
                }
                else
                    result++;
            }
            break;

        case 4:
            result = len;
            break;

        default:
            assert(0);
    }
    return result;
}

StringExp *StringExp::toString()
{
    return this;
}

/****************************************
 * Convert string to char[].
 */

StringExp *StringExp::toUTF8(Scope *sc)
{
    if (sz != 1)
    {   // Convert to UTF-8 string
        committed = 0;
        Expression *e = castTo(sc, Type::tchar->arrayOf());
        e = e->optimize(WANTvalue);
        assert(e->op == TOKstring);
        StringExp *se = (StringExp *)e;
        assert(se->sz == 1);
        return se;
    }
    return this;
}

int StringExp::compare(Object *obj)
{
    //printf("StringExp::compare()\n");
    // Used to sort case statement expressions so we can do an efficient lookup
    StringExp *se2 = (StringExp *)(obj);

    // This is a kludge so isExpression() in template.c will return 5
    // for StringExp's.
    if (!se2)
        return 5;

    assert(se2->op == TOKstring);

    int len1 = len;
    int len2 = se2->len;

    //printf("sz = %d, len1 = %d, len2 = %d\n", sz, len1, len2);
    if (len1 == len2)
    {
        switch (sz)
        {
            case 1:
                return memcmp((char *)string, (char *)se2->string, len1);

            case 2:
            {   unsigned u;
                d_wchar *s1 = (d_wchar *)string;
                d_wchar *s2 = (d_wchar *)se2->string;

                for (u = 0; u < len; u++)
                {
                    if (s1[u] != s2[u])
                        return s1[u] - s2[u];
                }
            }

            case 4:
            {   unsigned u;
                d_dchar *s1 = (d_dchar *)string;
                d_dchar *s2 = (d_dchar *)se2->string;

                for (u = 0; u < len; u++)
                {
                    if (s1[u] != s2[u])
                        return s1[u] - s2[u];
                }
            }
            break;

            default:
                assert(0);
        }
    }
    return len1 - len2;
}

int StringExp::isBool(int result)
{
    return result ? TRUE : FALSE;
}


int StringExp::isLvalue()
{
    /* string literal is rvalue in default, but
     * conversion to reference of static array is only allowed.
     */
    return 0;
}

unsigned StringExp::charAt(size_t i)
{   unsigned value;

    switch (sz)
    {
        case 1:
            value = ((unsigned char *)string)[i];
            break;

        case 2:
            value = ((unsigned short *)string)[i];
            break;

        case 4:
            value = ((unsigned int *)string)[i];
            break;

        default:
            assert(0);
            break;
    }
    return value;
}

void StringExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writeByte('"');
    unsigned o = buf->offset;
    for (size_t i = 0; i < len; i++)
    {   unsigned c = charAt(i);

        switch (c)
        {
            case '"':
            case '\\':
                if (!hgs->console)
                    buf->writeByte('\\');
            default:
                if (c <= 0xFF)
                {   if (c <= 0x7F && (isprint(c) || hgs->console))
                        buf->writeByte(c);
                    else
                        buf->printf("\\x%02x", c);
                }
                else if (c <= 0xFFFF)
                    buf->printf("\\x%02x\\x%02x", c & 0xFF, c >> 8);
                else
                    buf->printf("\\x%02x\\x%02x\\x%02x\\x%02x",
                        c & 0xFF, (c >> 8) & 0xFF, (c >> 16) & 0xFF, c >> 24);
                break;
        }
    }
    if (hgs->ddoc)
        escapeDdocString(buf, o);
    buf->writeByte('"');
    if (postfix)
        buf->writeByte(postfix);
}

void StringExp::toMangleBuffer(OutBuffer *buf)
{   char m;
    OutBuffer tmp;
    const char *p;
    unsigned c;
    size_t u;
    unsigned char *q;
    unsigned qlen;

    /* Write string in UTF-8 format
     */
    switch (sz)
    {   case 1:
            m = 'a';
            q = (unsigned char *)string;
            qlen = len;
            break;
        case 2:
            m = 'w';
            for (u = 0; u < len; )
            {
                p = utf_decodeWchar((unsigned short *)string, len, &u, &c);
                if (p)
                    error("%s", p);
                else
                    tmp.writeUTF8(c);
            }
            q = tmp.data;
            qlen = tmp.offset;
            break;
        case 4:
            m = 'd';
            for (u = 0; u < len; u++)
            {
                c = ((unsigned *)string)[u];
                if (!utf_isValidDchar(c))
                    error("invalid UCS-32 char \\U%08x", c);
                else
                    tmp.writeUTF8(c);
            }
            q = tmp.data;
            qlen = tmp.offset;
            break;
        default:
            assert(0);
    }
    buf->reserve(1 + 11 + 2 * qlen);
    buf->writeByte(m);
    buf->printf("%d_", qlen); // nbytes <= 11

    for (unsigned char *p = buf->data + buf->offset, *pend = p + 2 * qlen;
         p < pend; p += 2, ++q)
    {
        unsigned char hi = *q >> 4 & 0xF;
        p[0] = (hi < 10 ? hi + '0' : hi - 10 + 'a');
        unsigned char lo = *q & 0xF;
        p[1] = (lo < 10 ? lo + '0' : lo - 10 + 'a');
    }
    buf->offset += 2 * qlen;
}

/************************ ArrayLiteralExp ************************************/

// [ e1, e2, e3, ... ]

ArrayLiteralExp::ArrayLiteralExp(Loc loc, Expressions *elements)
    : Expression(loc, TOKarrayliteral, sizeof(ArrayLiteralExp))
{
    this->elements = elements;
    this->ownedByCtfe = false;
}

ArrayLiteralExp::ArrayLiteralExp(Loc loc, Expression *e)
    : Expression(loc, TOKarrayliteral, sizeof(ArrayLiteralExp))
{
    elements = new Expressions;
    elements->push(e);
    this->ownedByCtfe = false;
}

Expression *ArrayLiteralExp::syntaxCopy()
{
    return new ArrayLiteralExp(loc, arraySyntaxCopy(elements));
}

Expression *ArrayLiteralExp::semantic(Scope *sc)
{   Expression *e;
    Type *t0 = NULL;

#if LOGSEMANTIC
    printf("ArrayLiteralExp::semantic('%s')\n", toChars());
#endif
    if (type)
        return this;

    // Run semantic() on each element
    for (size_t i = 0; i < elements->dim; i++)
    {   e = (Expression *)elements->data[i];
        e = e->semantic(sc);
        elements->data[i] = (void *)e;
    }
    expandTuples(elements);
    for (size_t i = 0; i < elements->dim; i++)
    {   e = (Expression *)elements->data[i];

        if (!e->type)
            error("%s has no value", e->toChars());
        e = resolveProperties(sc, e);

        unsigned char committed = 1;
        if (e->op == TOKstring)
            committed = ((StringExp *)e)->committed;

        if (!t0)
        {   t0 = e->type;
            // Convert any static arrays to dynamic arrays
            if (t0->ty == Tsarray)
            {
                t0 = ((TypeSArray *)t0)->next->arrayOf();
                e = e->implicitCastTo(sc, t0);
            }
        }
        else
            e = e->implicitCastTo(sc, t0);
        if (!committed && e->op == TOKstring)
        {   StringExp *se = (StringExp *)e;
            se->committed = 0;
        }
        elements->data[i] = (void *)e;
    }

    if (!t0)
        t0 = Type::tvoid;

    type = new TypeSArray(t0, new IntegerExp(elements->dim));
    type = type->semantic(loc, sc);

    /* Disallow array literals of type void being used.
     */
    if (elements->dim > 0 && t0->ty == Tvoid)
    {   error("%s of type %s has no value", toChars(), type->toChars());
        return new ErrorExp();
    }

    return this;
}

int ArrayLiteralExp::checkSideEffect(int flag)
{   int f = 0;

    for (size_t i = 0; i < elements->dim; i++)
    {   Expression *e = elements->tdata()[i];

        f |= e->hasSideEffect();
    }
    if (flag == 0 && f == 0)
        Expression::checkSideEffect(0);
    return f;
}

int ArrayLiteralExp::isBool(int result)
{
    size_t dim = elements ? elements->dim : 0;
    return result ? (dim != 0) : (dim == 0);
}

StringExp *ArrayLiteralExp::toString()
{
    TY telem = type->nextOf()->toBasetype()->ty;

    if (telem == Tchar || telem == Twchar || telem == Tdchar ||
        (telem == Tvoid && (!elements || elements->dim == 0)))
    {
        OutBuffer buf;
        if (elements)
            for (int i = 0; i < elements->dim; ++i)
            {
                Expression *ch = (*elements)[i];
                if (ch->op != TOKint64)
                    return NULL;
                buf.writeUTF8(ch->toInteger());
            }
        buf.writebyte(0);

        char prefix = 'c';
        if (telem == Twchar) prefix = 'w';
        else if (telem == Tdchar) prefix = 'd';

        const size_t len = buf.offset - 1;
        StringExp *se = new StringExp(loc, buf.extractData(), len, prefix);
        se->type = type;
        return se;
    }
    return NULL;
}

void ArrayLiteralExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writeByte('[');
    argsToCBuffer(buf, elements, hgs);
    buf->writeByte(']');
}

void ArrayLiteralExp::toMangleBuffer(OutBuffer *buf)
{
    size_t dim = elements ? elements->dim : 0;
    buf->printf("A%u", dim);
    for (size_t i = 0; i < dim; i++)
    {   Expression *e = (*elements)[i];
        e->toMangleBuffer(buf);
    }
}

/************************ AssocArrayLiteralExp ************************************/

// [ key0 : value0, key1 : value1, ... ]

AssocArrayLiteralExp::AssocArrayLiteralExp(Loc loc,
                Expressions *keys, Expressions *values)
    : Expression(loc, TOKassocarrayliteral, sizeof(AssocArrayLiteralExp))
{
    assert(keys->dim == values->dim);
    this->keys = keys;
    this->values = values;
    this->ownedByCtfe = false;
}

Expression *AssocArrayLiteralExp::syntaxCopy()
{
    return new AssocArrayLiteralExp(loc,
        arraySyntaxCopy(keys), arraySyntaxCopy(values));
}

Expression *AssocArrayLiteralExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("AssocArrayLiteralExp::semantic('%s')\n", toChars());
#endif

    if (type)
        return this;

    // Run semantic() on each element
    arrayExpressionSemantic(keys, sc);
    arrayExpressionSemantic(values, sc);
    expandTuples(keys);
    expandTuples(values);
    if (keys->dim != values->dim)
    {
        error("number of keys is %u, must match number of values %u", keys->dim, values->dim);
        return new ErrorExp();
    }

    Type *tkey = NULL;
    Type *tvalue = NULL;
    keys = arrayExpressionToCommonType(sc, keys, &tkey);
    values = arrayExpressionToCommonType(sc, values, &tvalue);

    if (tkey == Type::terror || tvalue == Type::terror)
        return new ErrorExp;

    type = new TypeAArray(tvalue, tkey);
    type = type->semantic(loc, sc);
    return this;
}

int AssocArrayLiteralExp::checkSideEffect(int flag)
{   int f = 0;

    for (size_t i = 0; i < keys->dim; i++)
    {   Expression *key = (Expression *)keys->data[i];
        Expression *value = (Expression *)values->data[i];

        f |= key->hasSideEffect();
        f |= value->hasSideEffect();
    }
    if (flag == 0 && f == 0)
        Expression::checkSideEffect(0);
    return f;
}

int AssocArrayLiteralExp::isBool(int result)
{
    size_t dim = keys->dim;
    return result ? (dim != 0) : (dim == 0);
}

#if DMDV2
int AssocArrayLiteralExp::canThrow()
{
    return 1;
}
#endif

void AssocArrayLiteralExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writeByte('[');
    for (size_t i = 0; i < keys->dim; i++)
    {   Expression *key = (*keys)[i];
        Expression *value = (*values)[i];

        if (i)
            buf->writeByte(',');
        expToCBuffer(buf, hgs, key, PREC_assign);
        buf->writeByte(':');
        expToCBuffer(buf, hgs, value, PREC_assign);
    }
    buf->writeByte(']');
}

void AssocArrayLiteralExp::toMangleBuffer(OutBuffer *buf)
{
    size_t dim = keys->dim;
    buf->printf("A%u", dim);
    for (size_t i = 0; i < dim; i++)
    {   Expression *key = (*keys)[i];
        Expression *value = (*values)[i];

        key->toMangleBuffer(buf);
        value->toMangleBuffer(buf);
    }
}

/************************ StructLiteralExp ************************************/

// sd( e1, e2, e3, ... )

StructLiteralExp::StructLiteralExp(Loc loc, StructDeclaration *sd, Expressions *elements, Type *stype)
    : Expression(loc, TOKstructliteral, sizeof(StructLiteralExp))
{
    this->sd = sd;
    this->elements = elements;
    this->stype = stype;
    this->sym = NULL;
    this->soffset = 0;
    this->fillHoles = 1;
    this->ownedByCtfe = false;
}

Expression *StructLiteralExp::syntaxCopy()
{
    return new StructLiteralExp(loc, sd, arraySyntaxCopy(elements), stype);
}

Expression *StructLiteralExp::semantic(Scope *sc)
{   Expression *e;

#if LOGSEMANTIC
    printf("StructLiteralExp::semantic('%s')\n", toChars());
#endif
    if (type)
        return this;

    sd->size(loc);
    elements = arrayExpressionSemantic(elements, sc);    // Run semantic() on each element
    expandTuples(elements);
    size_t offset = 0;
    for (size_t i = 0; i < elements->dim; i++)
    {   e = (*elements)[i];
        if (!e)
            continue;

        if (!e->type)
        {   error("%s has no value", e->toChars());
            return new ErrorExp();
        }
        e = resolveProperties(sc, e);
        if (i >= sd->fields.dim)
        {   error("more initializers than fields (%d) of %s", sd->fields.dim, sd->toChars());
            break;
        }
        Dsymbol *s = sd->fields[i];
        VarDeclaration *v = s->isVarDeclaration();
        assert(v);
        if (v->offset < offset)
            error("overlapping initialization for %s", v->toChars());
        offset = v->offset + v->type->size();

        Type *telem = v->type;
        while (!e->implicitConvTo(telem) && telem->toBasetype()->ty == Tsarray)
        {   /* Static array initialization, as in:
             *  T[3][5] = e;
             */
            telem = telem->toBasetype()->nextOf();
        }

        e = e->implicitCastTo(sc, telem);
        if (e->op == TOKerror)
            return e;

        elements->data[i] = (void *)e;
    }

    /* Fill out remainder of elements[] with default initializers for fields[]
     */
    for (size_t i = elements->dim; i < sd->fields.dim; i++)
    {   Dsymbol *s = (Dsymbol *)sd->fields.data[i];
        VarDeclaration *v = s->isVarDeclaration();
        assert(v);

        if (v->offset < offset)
        {   e = NULL;
            sd->hasUnions = 1;
        }
        else
        {
            if (v->init)
            {   if (v->init->isVoidInitializer())
                    e = NULL;
                else
                {   e = v->init->toExpression();
                    if (!e)
                    {   error("cannot make expression out of initializer for %s", v->toChars());
                        return new ErrorExp();
                    }
                    else if (v->scope)
                    {   // Do deferred semantic analysis
                        Initializer *i2 = v->init->syntaxCopy();
                        i2 = i2->semantic(v->scope, v->type, INITinterpret);
                        e = i2->toExpression();
                        // remove v->scope (see bug 3426)
                        // but not if gagged, for we might be called again.
                        if (!global.gag)
                            v->scope = NULL;
                    }
                }
            }
            else
                e = v->type->defaultInitLiteral(loc);
            offset = v->offset + v->type->size();
        }
        elements->push(e);
    }

    type = stype ? stype : sd->type;
    return this;
}

/**************************************
 * Gets expression at offset of type.
 * Returns NULL if not found.
 */

Expression *StructLiteralExp::getField(Type *type, unsigned offset)
{
    //printf("StructLiteralExp::getField(this = %s, type = %s, offset = %u)\n",
//      /*toChars()*/"", type->toChars(), offset);
    Expression *e = NULL;
    int i = getFieldIndex(type, offset);

    if (i != -1)
    {
        //printf("\ti = %d\n", i);
        assert(i < elements->dim);
        e = (Expression *)elements->data[i];
        if (e)
        {
            //printf("e = %s, e->type = %s\n", e->toChars(), e->type->toChars());

            /* If type is a static array, and e is an initializer for that array,
             * then the field initializer should be an array literal of e.
             */
            if (e->type != type && type->ty == Tsarray)
            {   TypeSArray *tsa = (TypeSArray *)type;
                uinteger_t length = tsa->dim->toInteger();
                Expressions *z = new Expressions;
                z->setDim(length);
                for (int q = 0; q < length; ++q)
                    z->data[q] = e->copy();
                e = new ArrayLiteralExp(loc, z);
                e->type = type;
            }
            else
            {
                e = e->copy();
                e->type = type;
            }
        }
    }
    return e;
}

/************************************
 * Get index of field.
 * Returns -1 if not found.
 */

int StructLiteralExp::getFieldIndex(Type *type, unsigned offset)
{
    /* Find which field offset is by looking at the field offsets
     */
    if (elements->dim)
    {
        for (size_t i = 0; i < sd->fields.dim; i++)
        {
            Dsymbol *s = (Dsymbol *)sd->fields.data[i];
            VarDeclaration *v = s->isVarDeclaration();
            assert(v);

            if (offset == v->offset &&
                type->size() == v->type->size())
            {   Expression *e = (Expression *)elements->data[i];
                if (e)
                {
                    return i;
                }
                break;
            }
        }
    }
    return -1;
}

#if DMDV2
int StructLiteralExp::isLvalue()
{
    return 1;
}
#endif

Expression *StructLiteralExp::toLvalue(Scope *sc, Expression *e)
{
    return this;
}


int StructLiteralExp::checkSideEffect(int flag)
{   int f = 0;

    for (size_t i = 0; i < elements->dim; i++)
    {   Expression *e = (Expression *)elements->data[i];
        if (!e)
            continue;

        f |= e->hasSideEffect();
    }
    if (flag == 0 && f == 0)
        Expression::checkSideEffect(0);
    return f;
}

#if DMDV2
int StructLiteralExp::canThrow()
{
    return arrayExpressionCanThrow(elements);
}
#endif

void StructLiteralExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring(sd->toChars());
    buf->writeByte('(');
    argsToCBuffer(buf, elements, hgs);
    buf->writeByte(')');
}

void StructLiteralExp::toMangleBuffer(OutBuffer *buf)
{
    size_t dim = elements ? elements->dim : 0;
    buf->printf("S%u", dim);
    for (size_t i = 0; i < dim; i++)
    {   Expression *e = (*elements)[i];
        if (e)
            e->toMangleBuffer(buf);
        else
            buf->writeByte('v');        // 'v' for void
    }
}

/************************ TypeDotIdExp ************************************/

/* Things like:
 *      int.size
 *      foo.size
 *      (foo).size
 *      cast(foo).size
 */

Expression *typeDotIdExp(Loc loc, Type *type, Identifier *ident)
{
    return new DotIdExp(loc, new TypeExp(loc, type), ident);
}


/************************************************************/

// Mainly just a placeholder

TypeExp::TypeExp(Loc loc, Type *type)
    : Expression(loc, TOKtype, sizeof(TypeExp))
{
    //printf("TypeExp::TypeExp(%s)\n", type->toChars());
    this->type = type;
}

Expression *TypeExp::syntaxCopy()
{
    //printf("TypeExp::syntaxCopy()\n");
    return new TypeExp(loc, type->syntaxCopy());
}

Expression *TypeExp::semantic(Scope *sc)
{
    //printf("TypeExp::semantic(%s)\n", type->toChars());
    type = type->semantic(loc, sc);
    return this;
}

void TypeExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    type->toCBuffer(buf, NULL, hgs);
}

/************************************************************/

// Mainly just a placeholder

ScopeExp::ScopeExp(Loc loc, ScopeDsymbol *pkg)
    : Expression(loc, TOKimport, sizeof(ScopeExp))
{
    //printf("ScopeExp::ScopeExp(pkg = '%s')\n", pkg->toChars());
    //static int count; if (++count == 38) *(char*)0=0;
    this->sds = pkg;
}

Expression *ScopeExp::syntaxCopy()
{
    ScopeExp *se = new ScopeExp(loc, (ScopeDsymbol *)sds->syntaxCopy(NULL));
    return se;
}

Expression *ScopeExp::semantic(Scope *sc)
{
    TemplateInstance *ti;
    ScopeDsymbol *sds2;

#if LOGSEMANTIC
    printf("+ScopeExp::semantic('%s')\n", toChars());
#endif
Lagain:
    ti = sds->isTemplateInstance();
    if (ti && !ti->errors)
    {
        unsigned olderrs = global.errors;
        if (!ti->semanticRun)
            ti->semantic(sc);
        if (ti->inst)
        {
            if (ti->inst->errors)
                return new ErrorExp();
            Dsymbol *s = ti->inst->toAlias();
            sds2 = s->isScopeDsymbol();
            if (!sds2)
            {   Expression *e;

                //printf("s = %s, '%s'\n", s->kind(), s->toChars());
                if (ti->withsym)
                {
                    // Same as wthis.s
                    e = new VarExp(loc, ti->withsym->withstate->wthis);
                    e = new DotVarExp(loc, e, s->isDeclaration());
                }
                else
                    e = new DsymbolExp(loc, s);
                e = e->semantic(sc);
                //printf("-1ScopeExp::semantic()\n");
                return e;
            }
            if (sds2 != sds)
            {
                sds = sds2;
                goto Lagain;
            }
            //printf("sds = %s, '%s'\n", sds->kind(), sds->toChars());
        }
        if (olderrs != global.errors)
            return new ErrorExp();
    }
    else
    {
        //printf("sds = %s, '%s'\n", sds->kind(), sds->toChars());
        //printf("\tparent = '%s'\n", sds->parent->toChars());
        sds->semantic(sc);

        AggregateDeclaration *ad = sds->isAggregateDeclaration();
        if (ad)
            return (new TypeExp(loc, ad->type))->semantic(sc);
    }
    type = Type::tvoid;
    //printf("-2ScopeExp::semantic() %s\n", toChars());
    return this;
}

void ScopeExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    if (sds->isTemplateInstance())
    {
        sds->toCBuffer(buf, hgs);
    }
    else if (hgs != NULL && hgs->ddoc)
    {   // fixes bug 6491
        Module *module = sds->isModule();
        if (module)
            buf->writestring(module->md->toChars());
        else
            buf->writestring(sds->toChars());
    }
    else
    {
        buf->writestring(sds->kind());
        buf->writestring(" ");
        buf->writestring(sds->toChars());
    }
}

/********************** TemplateExp **************************************/

// Mainly just a placeholder

TemplateExp::TemplateExp(Loc loc, TemplateDeclaration *td)
    : Expression(loc, TOKtemplate, sizeof(TemplateExp))
{
    //printf("TemplateExp(): %s\n", td->toChars());
    this->td = td;
}

void TemplateExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring(td->toChars());
}

int TemplateExp::rvalue()
{
    error("template %s has no value", toChars());
    return 0;
}

/********************** NewExp **************************************/

/* thisexp.new(newargs) newtype(arguments) */

NewExp::NewExp(Loc loc, Expression *thisexp, Expressions *newargs,
        Type *newtype, Expressions *arguments)
    : Expression(loc, TOKnew, sizeof(NewExp))
{
    this->thisexp = thisexp;
    this->newargs = newargs;
    this->newtype = newtype;
    this->arguments = arguments;
    member = NULL;
    allocator = NULL;
    onstack = 0;
}

Expression *NewExp::syntaxCopy()
{
    return new NewExp(loc,
        thisexp ? thisexp->syntaxCopy() : NULL,
        arraySyntaxCopy(newargs),
        newtype->syntaxCopy(), arraySyntaxCopy(arguments));
}


Expression *NewExp::semantic(Scope *sc)
{
    Type *tb;
    ClassDeclaration *cdthis = NULL;

#if LOGSEMANTIC
    printf("NewExp::semantic() %s\n", toChars());
    if (thisexp)
        printf("\tthisexp = %s\n", thisexp->toChars());
    printf("\tnewtype: %s\n", newtype->toChars());
#endif
    if (type)                   // if semantic() already run
        return this;

Lagain:
    if (thisexp)
    {   thisexp = thisexp->semantic(sc);
        cdthis = thisexp->type->isClassHandle();
        if (cdthis)
        {
            sc = sc->push(cdthis);
            type = newtype->semantic(loc, sc);
            sc = sc->pop();
        }
        else
        {
            error("'this' for nested class must be a class type, not %s", thisexp->type->toChars());
            goto Lerr;
        }
    }
    else
        type = newtype->semantic(loc, sc);
    newtype = type;             // in case type gets cast to something else
    tb = type->toBasetype();
    //printf("tb: %s, deco = %s\n", tb->toChars(), tb->deco);

    arrayExpressionSemantic(newargs, sc);
    preFunctionParameters(loc, sc, newargs);
    arrayExpressionSemantic(arguments, sc);
    preFunctionParameters(loc, sc, arguments);

    if (thisexp && tb->ty != Tclass)
    {   error("e.new is only for allocating nested classes, not %s", tb->toChars());
        goto Lerr;
    }

    if (tb->ty == Tclass)
    {   TypeFunction *tf;

        TypeClass *tc = (TypeClass *)(tb);
        ClassDeclaration *cd = tc->sym->isClassDeclaration();
        if (cd->isInterfaceDeclaration())
        {   error("cannot create instance of interface %s", cd->toChars());
            goto Lerr;
        }
        else if (cd->isAbstract())
        {   error("cannot create instance of abstract class %s", cd->toChars());
            for (size_t i = 0; i < cd->vtbl.dim; i++)
            {   FuncDeclaration *fd = cd->vtbl.tdata()[i]->isFuncDeclaration();
                if (fd && fd->isAbstract())
                    error("function %s is abstract", fd->toChars());
            }
            goto Lerr;
        }
        checkDeprecated(sc, cd);
        if (cd->isNested())
        {   /* We need a 'this' pointer for the nested class.
             * Ensure we have the right one.
             */
            Dsymbol *s = cd->toParent2();
            ClassDeclaration *cdn = s->isClassDeclaration();
            FuncDeclaration *fdn = s->isFuncDeclaration();

            //printf("cd isNested, cdn = %s\n", cdn ? cdn->toChars() : "null");
            if (cdn)
            {
                if (!cdthis)
                {
                    // Supply an implicit 'this' and try again
                    thisexp = new ThisExp(loc);
                    for (Dsymbol *sp = sc->parent; 1; sp = sp->parent)
                    {   if (!sp)
                        {
                            error("outer class %s 'this' needed to 'new' nested class %s", cdn->toChars(), cd->toChars());
                            goto Lerr;
                        }
                        ClassDeclaration *cdp = sp->isClassDeclaration();
                        if (!cdp)
                            continue;
                        if (cdp == cdn || cdn->isBaseOf(cdp, NULL))
                            break;
                        // Add a '.outer' and try again
                        thisexp = new DotIdExp(loc, thisexp, Id::outer);
                    }
                    if (!global.errors)
                        goto Lagain;
                }
                if (cdthis)
                {
                    //printf("cdthis = %s\n", cdthis->toChars());
                    if (cdthis != cdn && !cdn->isBaseOf(cdthis, NULL))
                    {   error("'this' for nested class must be of type %s, not %s", cdn->toChars(), thisexp->type->toChars());
                        goto Lerr;
                    }
                }
#if 0
                else
                {
                    for (Dsymbol *sf = sc->func; 1; sf= sf->toParent2()->isFuncDeclaration())
                    {
                        if (!sf)
                        {
                            error("outer class %s 'this' needed to 'new' nested class %s", cdn->toChars(), cd->toChars());
                            goto Lerr;
                        }
                        printf("sf = %s\n", sf->toChars());
                        AggregateDeclaration *ad = sf->isThis();
                        if (ad && (ad == cdn || cdn->isBaseOf(ad->isClassDeclaration(), NULL)))
                            break;
                    }
                }
#endif
            }
            else if (thisexp)
            {   error("e.new is only for allocating nested classes");
                goto Lerr;
            }
            else if (fdn)
            {
                // make sure the parent context fdn of cd is reachable from sc
                for (Dsymbol *sp = sc->parent; 1; sp = sp->parent)
                {
                    if (fdn == sp)
                        break;
                    FuncDeclaration *fsp = sp ? sp->isFuncDeclaration() : NULL;
                    if (!sp || (fsp && fsp->isStatic()))
                    {
                        error("outer function context of %s is needed to 'new' nested class %s", fdn->toPrettyChars(), cd->toPrettyChars());
                        goto Lerr;
                    }
                }
            }
        }
        else if (thisexp)
        {   error("e.new is only for allocating nested classes");
            goto Lerr;
        }

        FuncDeclaration *f = cd->ctor;
        if (f)
        {
            assert(f);
            f = f->overloadResolve(loc, NULL, arguments);
            checkDeprecated(sc, f);
            member = f->isCtorDeclaration();
            assert(member);

            cd->accessCheck(loc, sc, member);

            tf = (TypeFunction *)f->type;
            type = tf->next;

            if (!arguments)
                arguments = new Expressions();
            unsigned olderrors = global.errors;
            functionParameters(loc, sc, tf, arguments);
            if (olderrors != global.errors)
                return new ErrorExp();

        }
        else
        {
            if (arguments && arguments->dim)
            {   error("no constructor for %s", cd->toChars());
                goto Lerr;
            }
        }

        if (cd->aggNew)
        {
            // Prepend the size argument to newargs[]
            Expression *e = new IntegerExp(loc, cd->size(loc), Type::tsize_t);
            if (!newargs)
                newargs = new Expressions();
            newargs->shift(e);

            f = cd->aggNew->overloadResolve(loc, NULL, newargs);
            allocator = f->isNewDeclaration();
            assert(allocator);

            tf = (TypeFunction *)f->type;
            unsigned olderrors = global.errors;
            functionParameters(loc, sc, tf, newargs);
            if (olderrors != global.errors)
                return new ErrorExp();

        }
        else
        {
            if (newargs && newargs->dim)
            {   error("no allocator for %s", cd->toChars());
                goto Lerr;
            }
        }
    }
    else if (tb->ty == Tstruct)
    {
        TypeStruct *ts = (TypeStruct *)tb;
        StructDeclaration *sd = ts->sym;
        FuncDeclaration *f = sd->aggNew;
        TypeFunction *tf;

        if (arguments && arguments->dim)
            error("no constructor for %s", type->toChars());

        if (f)
        {
            Expression *e;

            // Prepend the uint size argument to newargs[]
            e = new IntegerExp(loc, sd->size(loc), Type::tuns32);
            if (!newargs)
                newargs = new Expressions();
            newargs->shift(e);

            f = f->overloadResolve(loc, NULL, newargs);
            allocator = f->isNewDeclaration();
            assert(allocator);

            tf = (TypeFunction *)f->type;
            unsigned olderrors = global.errors;
            functionParameters(loc, sc, tf, newargs);
            if (olderrors != global.errors)
                return new ErrorExp();

            e = new VarExp(loc, f);
            e = new CallExp(loc, e, newargs);
            e = e->semantic(sc);
            e->type = type->pointerTo();
            return e;
        }

        type = type->pointerTo();
    }
    else if (tb->ty == Tarray && (arguments && arguments->dim))
    {
        for (size_t i = 0; i < arguments->dim; i++)
        {
            if (tb->ty != Tarray)
            {   error("too many arguments for array");
                goto Lerr;
            }

            Expression *arg = arguments->tdata()[i];
            arg = resolveProperties(sc, arg);
            arg = arg->implicitCastTo(sc, Type::tsize_t);
            if (arg->op == TOKint64 && (long long)arg->toInteger() < 0)
            {   error("negative array index %s", arg->toChars());
                goto Lerr;
            }
            arguments->tdata()[i] =  arg;
            tb = ((TypeDArray *)tb)->next->toBasetype();
        }
    }
    else if (tb->isscalar())
    {
        if (arguments && arguments->dim)
        {   error("no constructor for %s", type->toChars());
            goto Lerr;
        }

        type = type->pointerTo();
    }
    else
    {
        error("new can only create structs, dynamic arrays or class objects, not %s's", type->toChars());
        goto Lerr;
    }

//printf("NewExp: '%s'\n", toChars());
//printf("NewExp:type '%s'\n", type->toChars());

    return this;

Lerr:
    return new ErrorExp();
}

int NewExp::checkSideEffect(int flag)
{
    return 1;
}

#if DMDV2
int NewExp::canThrow(bool mustNotThrow)
{
    if (arrayExpressionCanThrow(newargs, mustNotThrow) ||
        arrayExpressionCanThrow(arguments, mustNotThrow))
        return 1;
    if (member)
    {
        // See if constructor call can throw
        Type *t = member->type->toBasetype();
        if (t->ty == Tfunction && !((TypeFunction *)t)->isnothrow)
        {
            if (mustNotThrow)
                error("constructor %s is not nothrow", member->toChars());
            return 1;
        }
    }
    // regard storage allocation failures as not recoverable
    return 0;
}
#endif

void NewExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    if (thisexp)
    {   expToCBuffer(buf, hgs, thisexp, PREC_primary);
        buf->writeByte('.');
    }
    buf->writestring("new ");
    if (newargs && newargs->dim)
    {
        buf->writeByte('(');
        argsToCBuffer(buf, newargs, hgs);
        buf->writeByte(')');
    }
    newtype->toCBuffer(buf, NULL, hgs);
    if (arguments && arguments->dim)
    {
        buf->writeByte('(');
        argsToCBuffer(buf, arguments, hgs);
        buf->writeByte(')');
    }
}

/********************** NewAnonClassExp **************************************/

NewAnonClassExp::NewAnonClassExp(Loc loc, Expression *thisexp,
        Expressions *newargs, ClassDeclaration *cd, Expressions *arguments)
    : Expression(loc, TOKnewanonclass, sizeof(NewAnonClassExp))
{
    this->thisexp = thisexp;
    this->newargs = newargs;
    this->cd = cd;
    this->arguments = arguments;
}

Expression *NewAnonClassExp::syntaxCopy()
{
    return new NewAnonClassExp(loc,
        thisexp ? thisexp->syntaxCopy() : NULL,
        arraySyntaxCopy(newargs),
        (ClassDeclaration *)cd->syntaxCopy(NULL),
        arraySyntaxCopy(arguments));
}


Expression *NewAnonClassExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("NewAnonClassExp::semantic() %s\n", toChars());
    //printf("thisexp = %p\n", thisexp);
    //printf("type: %s\n", type->toChars());
#endif

    Expression *d = new DeclarationExp(loc, cd);
    d = d->semantic(sc);

    Expression *n = new NewExp(loc, thisexp, newargs, cd->type, arguments);

    Expression *c = new CommaExp(loc, d, n);
    return c->semantic(sc);
}

int NewAnonClassExp::checkSideEffect(int flag)
{
    return 1;
}

#if DMDV2
int NewAnonClassExp::canThrow()
{
    return 1;
}
#endif

void NewAnonClassExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    if (thisexp)
    {   expToCBuffer(buf, hgs, thisexp, PREC_primary);
        buf->writeByte('.');
    }
    buf->writestring("new");
    if (newargs && newargs->dim)
    {
        buf->writeByte('(');
        argsToCBuffer(buf, newargs, hgs);
        buf->writeByte(')');
    }
    buf->writestring(" class ");
    if (arguments && arguments->dim)
    {
        buf->writeByte('(');
        argsToCBuffer(buf, arguments, hgs);
        buf->writeByte(')');
    }
    //buf->writestring(" { }");
    if (cd)
    {
        cd->toCBuffer(buf, hgs);
    }
}

/********************** SymbolExp **************************************/

#if DMDV2
SymbolExp::SymbolExp(Loc loc, enum TOK op, int size, Declaration *var, int hasOverloads)
    : Expression(loc, op, size)
{
    assert(var);
    this->var = var;
    this->hasOverloads = hasOverloads;
}
#endif

/********************** SymOffExp **************************************/

SymOffExp::SymOffExp(Loc loc, Declaration *var, unsigned offset)
    : Expression(loc, TOKsymoff, sizeof(SymOffExp))
{
    assert(var);
    this->var = var;
    this->offset = offset;
    VarDeclaration *v = var->isVarDeclaration();
    if (v && v->needThis())
        error("need 'this' for address of %s", v->toChars());
}

Expression *SymOffExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("SymOffExp::semantic('%s')\n", toChars());
#endif
    //var->semantic(sc);
    if (!type)
        type = var->type->pointerTo();
    VarDeclaration *v = var->isVarDeclaration();
    if (v)
        v->checkNestedReference(sc, loc);
    return this;
}

int SymOffExp::isBool(int result)
{
    return result ? TRUE : FALSE;
}

void SymOffExp::checkEscape()
{
    VarDeclaration *v = var->isVarDeclaration();
    if (v)
    {
        if (!v->isDataseg() && !(v->storage_class & (STCref | STCout)))
        {   /* BUG: This should be allowed:
             *   void foo()
             *   { int a;
             *     int* bar() { return &a; }
             *   }
             */
            error("escaping reference to local %s", v->toChars());
        }
    }
}

void SymOffExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    if (offset)
        buf->printf("(& %s+%u)", var->toChars(), offset);
    else
        buf->printf("& %s", var->toChars());
}

/******************************** VarExp **************************/

VarExp::VarExp(Loc loc, Declaration *var)
        : Expression(loc, TOKvar, sizeof(VarExp))
{
    //printf("VarExp(this = %p, '%s')\n", this, var->toChars());
    this->var = var;
    this->type = var->type;
}

int VarExp::equals(Object *o)
{   VarExp *ne;

    if (this == o ||
        (((Expression *)o)->op == TOKvar &&
         ((ne = (VarExp *)o), type->equals(ne->type)) &&
         var == ne->var))
        return 1;
    return 0;
}

Expression *VarExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("VarExp::semantic(%s)\n", toChars());
#endif
    if (!type)
    {   type = var->type;
#if 0
        if (var->storage_class & STClazy)
        {
            TypeFunction *tf = new TypeFunction(NULL, type, 0, LINKd);
            type = new TypeDelegate(tf);
            type = type->semantic(loc, sc);
        }
#endif
    }

    if (type && !type->deco)
        type = type->semantic(loc, sc);

    /* Fix for 1161 doesn't work because it causes protection
     * problems when instantiating imported templates passing private
     * variables as alias template parameters.
     */
    //accessCheck(loc, sc, NULL, var);

    VarDeclaration *v = var->isVarDeclaration();
    if (v)
    {
        if (v->isConst() && v->type && type->toBasetype()->ty != Tsarray && v->init)
        {
            ExpInitializer *ei = v->init->isExpInitializer();
            if (ei && ei->exp->type)
            {
                //ei->exp->implicitCastTo(sc, type)->print();
                return ei->exp->implicitCastTo(sc, type);
            }
        }
        v->checkNestedReference(sc, loc);
#if DMDV2
        if (sc->func && sc->func->isPure() && !sc->intypeof)
        {
            if (v->isDataseg() && !v->isImmutable())
                error("pure function '%s' cannot access mutable static data '%s'", sc->func->toChars(), v->toChars());
        }
#endif
    }
#if 0
    else if ((fd = var->isFuncLiteralDeclaration()) != NULL)
    {   Expression *e;
        e = new FuncExp(loc, fd);
        e->type = type;
        return e;
    }
#endif

    return this;
}

char *VarExp::toChars()
{
    return var->toChars();
}

void VarExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring(var->toChars());
}

void VarExp::checkEscape()
{
    VarDeclaration *v = var->isVarDeclaration();
    if (v)
    {   Type *tb = v->type->toBasetype();
        // if reference type
        if (tb->ty == Tarray || tb->ty == Tsarray || tb->ty == Tclass)
        {
            if (v->isScope() && !v->noscope)
                error("escaping reference to auto local %s", v->toChars());
            else if (v->storage_class & STCvariadic)
                error("escaping reference to variadic parameter %s", v->toChars());
        }
    }
}

void VarExp::checkEscapeRef()
{
    VarDeclaration *v = var->isVarDeclaration();
    if (v)
    {
        if (!v->isDataseg() && !(v->storage_class & (STCref | STCout)))
            error("escaping reference to local variable %s", v->toChars());
    }
}


int VarExp::isLvalue()
{
    if (var->storage_class & STClazy)
        return 0;
    return 1;
}


Expression *VarExp::toLvalue(Scope *sc, Expression *e)
{
#if 0
    tym = tybasic(e1->ET->Tty);
    if (!(tyscalar(tym) ||
          tym == TYstruct ||
          tym == TYarray && e->Eoper == TOKaddr))
            synerr(EM_lvalue);  // lvalue expected
#endif
    if (var->storage_class & STClazy)
        error("lazy variables cannot be lvalues");
    return this;
}

Expression *VarExp::modifiableLvalue(Scope *sc, Expression *e)
{
    //printf("VarExp::modifiableLvalue('%s')\n", var->toChars());
    if (sc->incontract && var->isParameter())
        error("cannot modify parameter '%s' in contract", var->toChars());

    if (type && type->toBasetype()->ty == Tsarray)
        error("cannot change reference to static array '%s'", var->toChars());

    VarDeclaration *v = var->isVarDeclaration();
    if (v && v->canassign == 0 &&
        (var->isConst() || (global.params.Dversion > 1 && var->isFinal())))
        error("cannot modify final variable '%s'", var->toChars());

    if (var->isCtorinit())
    {   // It's only modifiable if inside the right constructor
        Dsymbol *s = sc->func;
        while (1)
        {
            FuncDeclaration *fd = NULL;
            if (s)
                fd = s->isFuncDeclaration();
            if (fd &&
                ((fd->isCtorDeclaration() && var->storage_class & STCfield) ||
                 (fd->isStaticCtorDeclaration() && !(var->storage_class & STCfield))) &&
                fd->toParent() == var->toParent()
               )
            {
                VarDeclaration *v = var->isVarDeclaration();
                assert(v);
                v->ctorinit = 1;
                //printf("setting ctorinit\n");
            }
            else
            {
                if (s)
                {   s = s->toParent2();
                    continue;
                }
                else
                {
                    const char *p = var->isStatic() ? "static " : "";
                    error("can only initialize %sconst %s inside %sconstructor",
                        p, var->toChars(), p);
                }
            }
            break;
        }
    }

    // See if this expression is a modifiable lvalue (i.e. not const)
    return toLvalue(sc, e);
}


/******************************** OverExp **************************/

#if DMDV2
OverExp::OverExp(OverloadSet *s)
        : Expression(loc, TOKoverloadset, sizeof(OverExp))
{
    //printf("OverExp(this = %p, '%s')\n", this, var->toChars());
    vars = s;
    type = Type::tvoid;
}

int OverExp::isLvalue()
{
    return 1;
}

Expression *OverExp::toLvalue(Scope *sc, Expression *e)
{
    return this;
}
#endif


/******************************** TupleExp **************************/

TupleExp::TupleExp(Loc loc, Expressions *exps)
        : Expression(loc, TOKtuple, sizeof(TupleExp))
{
    //printf("TupleExp(this = %p)\n", this);
    this->exps = exps;
    this->type = NULL;
}


TupleExp::TupleExp(Loc loc, TupleDeclaration *tup)
        : Expression(loc, TOKtuple, sizeof(TupleExp))
{
    exps = new Expressions();
    type = NULL;

    exps->reserve(tup->objects->dim);
    for (size_t i = 0; i < tup->objects->dim; i++)
    {   Object *o = tup->objects->tdata()[i];
        if (o->dyncast() == DYNCAST_EXPRESSION)
        {
            Expression *e = (Expression *)o;
            e = e->syntaxCopy();
            exps->push(e);
        }
        else if (o->dyncast() == DYNCAST_DSYMBOL)
        {
            Dsymbol *s = (Dsymbol *)o;
            Expression *e = new DsymbolExp(loc, s);
            exps->push(e);
        }
        else if (o->dyncast() == DYNCAST_TYPE)
        {
            Type *t = (Type *)o;
            Expression *e = new TypeExp(loc, t);
            exps->push(e);
        }
        else
        {
            error("%s is not an expression", o->toChars());
        }
    }
}

int TupleExp::equals(Object *o)
{
    if (this == o)
        return 1;
    if (((Expression *)o)->op == TOKtuple)
    {
        TupleExp *te = (TupleExp *)o;
        if (exps->dim != te->exps->dim)
            return 0;
        for (size_t i = 0; i < exps->dim; i++)
        {   Expression *e1 = (*exps)[i];
            Expression *e2 = (*te->exps)[i];

            if (!e1->equals(e2))
                return 0;
        }
        return 1;
    }
    return 0;
}

Expression *TupleExp::syntaxCopy()
{
    return new TupleExp(loc, arraySyntaxCopy(exps));
}

Expression *TupleExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("+TupleExp::semantic(%s)\n", toChars());
#endif
    if (type)
        return this;

    // Run semantic() on each argument
    for (size_t i = 0; i < exps->dim; i++)
    {   Expression *e = (*exps)[i];

        e = e->semantic(sc);
        if (!e->type)
        {   error("%s has no value", e->toChars());
            e = new ErrorExp();
        }
        (*exps)[i] = e;
    }

    expandTuples(exps);
    type = new TypeTuple(exps);
    type = type->semantic(loc, sc);
    //printf("-TupleExp::semantic(%s)\n", toChars());
    return this;
}

void TupleExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("tuple(");
    argsToCBuffer(buf, exps, hgs);
    buf->writeByte(')');
}

int TupleExp::checkSideEffect(int flag)
{   int f = 0;

    for (size_t i = 0; i < exps->dim; i++)
    {   Expression *e = (*exps)[i];

        f |= e->hasSideEffect();
    }
    if (flag == 0 && f == 0)
        Expression::checkSideEffect(0);
    return f;
}

#if DMDV2
int TupleExp::canThrow(bool mustNotThrow)
{
    return arrayExpressionCanThrow(exps, mustNotThrow);
}
#endif

void TupleExp::checkEscape()
{
    for (size_t i = 0; i < exps->dim; i++)
    {   Expression *e = (*exps)[i];
        e->checkEscape();
    }
}

/******************************** FuncExp *********************************/

FuncExp::FuncExp(Loc loc, FuncLiteralDeclaration *fd)
        : Expression(loc, TOKfunction, sizeof(FuncExp))
{
    this->fd = fd;
}

Expression *FuncExp::syntaxCopy()
{
    return new FuncExp(loc, (FuncLiteralDeclaration *)fd->syntaxCopy(NULL));
}

Expression *FuncExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("FuncExp::semantic(%s)\n", toChars());
#endif
    if (!type)
    {
        unsigned olderrors = global.errors;
        fd->semantic(sc);
        fd->parent = sc->parent;
        if (olderrors != global.errors)
        {
        }
        else
        {
            fd->semantic2(sc);
            if ( (olderrors == global.errors) ||
                // need to infer return type
                (fd->type && fd->type->ty == Tfunction && !fd->type->nextOf()))
            {
                fd->semantic3(sc);
            }
        }

        // need to infer return type
        if ((olderrors != global.errors) && fd->type && fd->type->ty == Tfunction && !fd->type->nextOf())
            ((TypeFunction *)fd->type)->next = Type::terror;

        // Type is a "delegate to" or "pointer to" the function literal
        if (fd->isNested())
        {
            type = new TypeDelegate(fd->type);
            type = type->semantic(loc, sc);
        }
        else
        {
            type = fd->type->pointerTo();
        }
    }
    return this;
}

char *FuncExp::toChars()
{
    return fd->toChars();
}

void FuncExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    fd->toCBuffer(buf, hgs);
    //buf->writestring(fd->toChars());
}


/******************************** DeclarationExp **************************/

DeclarationExp::DeclarationExp(Loc loc, Dsymbol *declaration)
        : Expression(loc, TOKdeclaration, sizeof(DeclarationExp))
{
    this->declaration = declaration;
}

Expression *DeclarationExp::syntaxCopy()
{
    return new DeclarationExp(loc, declaration->syntaxCopy(NULL));
}

Expression *DeclarationExp::semantic(Scope *sc)
{
    if (type)
        return this;

#if LOGSEMANTIC
    printf("DeclarationExp::semantic() %s\n", toChars());
#endif

    unsigned olderrors = global.errors;

    /* This is here to support extern(linkage) declaration,
     * where the extern(linkage) winds up being an AttribDeclaration
     * wrapper.
     */
    Dsymbol *s = declaration;

    AttribDeclaration *ad = declaration->isAttribDeclaration();
    if (ad)
    {
        if (ad->decl && ad->decl->dim == 1)
            s = ad->decl->tdata()[0];
    }

    if (s->isVarDeclaration())
    {   // Do semantic() on initializer first, so:
        //      int a = a;
        // will be illegal.
        declaration->semantic(sc);
        s->parent = sc->parent;
    }

    //printf("inserting '%s' %p into sc = %p\n", s->toChars(), s, sc);
    // Insert into both local scope and function scope.
    // Must be unique in both.
    if (s->ident)
    {
        if (!sc->insert(s))
            error("declaration %s is already defined", s->toPrettyChars());
        else if (sc->func)
        {   VarDeclaration *v = s->isVarDeclaration();
            if ( (s->isFuncDeclaration() || s->isTypedefDeclaration() ||
                s->isAggregateDeclaration() || s->isEnumDeclaration() ||
                s->isInterfaceDeclaration()) &&
                !sc->func->localsymtab->insert(s))
            {
                error("declaration %s is already defined in another scope in %s",
                    s->toPrettyChars(), sc->func->toChars());
            }
            else if (global.params.useDeprecated != 1)
            {   // Disallow shadowing

                for (Scope *scx = sc->enclosing; scx && scx->func == sc->func; scx = scx->enclosing)
                {   Dsymbol *s2;

                    if (scx->scopesym && scx->scopesym->symtab &&
                        (s2 = scx->scopesym->symtab->lookup(s->ident)) != NULL &&
                        s != s2)
                    {
                        deprecation("shadowing declaration %s is deprecated", s->toPrettyChars());
                    }
                }
            }
        }
    }
    if (!s->isVarDeclaration())
    {
        Scope *sc2 = sc;
        if (sc2->stc & (STCpure | STCnothrow))
            sc2 = sc->push();
        sc2->stc &= ~(STCpure | STCnothrow);
        declaration->semantic(sc2);
        if (sc2 != sc)
            sc2->pop();
        s->parent = sc->parent;
    }
    if (global.errors == olderrors)
    {
        declaration->semantic2(sc);
        if (global.errors == olderrors)
        {
            declaration->semantic3(sc);
        }
    }

    type = Type::tvoid;
    return this;
}

int DeclarationExp::checkSideEffect(int flag)
{
    return 1;
}

#if DMDV2
int DeclarationExp::canThrow()
{
    VarDeclaration *v = declaration->isVarDeclaration();
    if (v && v->init)
    {   ExpInitializer *ie = v->init->isExpInitializer();
        return ie && ie->exp->canThrow();
    }
    return 0;
}
#endif

void DeclarationExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    declaration->toCBuffer(buf, hgs);
}


/************************ TypeidExp ************************************/

/*
 *      typeid(int)
 */

TypeidExp::TypeidExp(Loc loc, Type *typeidType)
    : Expression(loc, TOKtypeid, sizeof(TypeidExp))
{
    this->typeidType = typeidType;
}


Expression *TypeidExp::syntaxCopy()
{
    return new TypeidExp(loc, typeidType->syntaxCopy());
}


Expression *TypeidExp::semantic(Scope *sc)
{   Expression *e;

#if LOGSEMANTIC
    printf("TypeidExp::semantic()\n");
#endif
    typeidType = typeidType->semantic(loc, sc);
    e = typeidType->getTypeInfo(sc);
    if (e->loc.linnum == 0)
        e->loc = loc;           // so there's at least some line number info
    return e;
}

void TypeidExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("typeid(");
    typeidType->toCBuffer(buf, NULL, hgs);
    buf->writeByte(')');
}

/************************ TraitsExp ************************************/
#if DMDV2
/*
 *      __traits(identifier, args...)
 */

TraitsExp::TraitsExp(Loc loc, Identifier *ident, Objects *args)
    : Expression(loc, TOKtraits, sizeof(TraitsExp))
{
    this->ident = ident;
    this->args = args;
}


Expression *TraitsExp::syntaxCopy()
{
    return new TraitsExp(loc, ident, TemplateInstance::arraySyntaxCopy(args));
}


void TraitsExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("__traits(");
    buf->writestring(ident->toChars());
    if (args)
    {
        for (size_t i = 0; i < args->dim; i++)
        {
            buf->writeByte(',');
            Object *oarg = (Object *)args->data[i];
            ObjectToCBuffer(buf, hgs, oarg);
        }
    }
    buf->writeByte(')');
}
#endif

/************************************************************/

HaltExp::HaltExp(Loc loc)
        : Expression(loc, TOKhalt, sizeof(HaltExp))
{
}

Expression *HaltExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("HaltExp::semantic()\n");
#endif
    type = Type::tvoid;
    return this;
}

int HaltExp::checkSideEffect(int flag)
{
    return 1;
}

void HaltExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("halt");
}

/************************************************************/

IsExp::IsExp(Loc loc, Type *targ, Identifier *id, enum TOK tok,
        Type *tspec, enum TOK tok2)
        : Expression(loc, TOKis, sizeof(IsExp))
{
    this->targ = targ;
    this->id = id;
    this->tok = tok;
    this->tspec = tspec;
    this->tok2 = tok2;
}

Expression *IsExp::syntaxCopy()
{
    return new IsExp(loc,
        targ->syntaxCopy(),
        id,
        tok,
        tspec ? tspec->syntaxCopy() : NULL,
        tok2);
}

Expression *IsExp::semantic(Scope *sc)
{   Type *tded;

    /* is(targ id tok tspec)
     * is(targ id == tok2)
     */

    //printf("IsExp::semantic(%s)\n", toChars());
    if (id && !(sc->flags & SCOPEstaticif))
        error("can only declare type aliases within static if conditionals");

    unsigned errors_save = global.startGagging();
    targ = targ->semantic(loc, sc);
    if (global.endGagging(errors_save)) // if any errors happened
    {                                   // then condition is false
        goto Lno;
    }
    else if (tok2 != TOKreserved)
    {
        switch (tok2)
        {
            case TOKtypedef:
                if (targ->ty != Ttypedef)
                    goto Lno;
                tded = ((TypeTypedef *)targ)->sym->basetype;
                break;

            case TOKstruct:
                if (targ->ty != Tstruct)
                    goto Lno;
                if (((TypeStruct *)targ)->sym->isUnionDeclaration())
                    goto Lno;
                tded = targ;
                break;

            case TOKunion:
                if (targ->ty != Tstruct)
                    goto Lno;
                if (!((TypeStruct *)targ)->sym->isUnionDeclaration())
                    goto Lno;
                tded = targ;
                break;

            case TOKclass:
                if (targ->ty != Tclass)
                    goto Lno;
                if (((TypeClass *)targ)->sym->isInterfaceDeclaration())
                    goto Lno;
                tded = targ;
                break;

            case TOKinterface:
                if (targ->ty != Tclass)
                    goto Lno;
                if (!((TypeClass *)targ)->sym->isInterfaceDeclaration())
                    goto Lno;
                tded = targ;
                break;
#if DMDV2
            case TOKconst:
                if (!targ->isConst())
                    goto Lno;
                tded = targ;
                break;

            case TOKinvariant:
                deprecation("use of 'invariant' rather than 'immutable' is deprecated");
            case TOKimmutable:
                if (!targ->isImmutable())
                    goto Lno;
                tded = targ;
                break;

            case TOKshared:
                if (!targ->isShared())
                    goto Lno;
                tded = targ;
                break;

            case TOKwild:
                if (!targ->isWild())
                    goto Lno;
                tded = targ;
                break;
#endif

            case TOKsuper:
                // If class or interface, get the base class and interfaces
                if (targ->ty != Tclass)
                    goto Lno;
                else
                {   ClassDeclaration *cd = ((TypeClass *)targ)->sym;
                    Parameters *args = new Parameters;
                    args->reserve(cd->baseclasses->dim);
                    if (cd->scope && !cd->symtab)
                        cd->semantic(cd->scope);
                    for (size_t i = 0; i < cd->baseclasses->dim; i++)
                    {   BaseClass *b = (*cd->baseclasses)[i];
                        args->push(new Parameter(STCin, b->type, NULL, NULL));
                    }
                    tded = new TypeTuple(args);
                }
                break;

            case TOKenum:
                if (targ->ty != Tenum)
                    goto Lno;
                tded = ((TypeEnum *)targ)->sym->memtype;
                break;

            case TOKdelegate:
                if (targ->ty != Tdelegate)
                    goto Lno;
                tded = ((TypeDelegate *)targ)->next;    // the underlying function type
                break;

            case TOKfunction:
            {
                if (targ->ty != Tfunction)
                    goto Lno;
                tded = targ;

                /* Generate tuple from function parameter types.
                 */
                assert(tded->ty == Tfunction);
                Parameters *params = ((TypeFunction *)tded)->parameters;
                size_t dim = Parameter::dim(params);
                Parameters *args = new Parameters;
                args->reserve(dim);
                for (size_t i = 0; i < dim; i++)
                {   Parameter *arg = Parameter::getNth(params, i);
                    assert(arg && arg->type);
                    args->push(new Parameter(arg->storageClass, arg->type, NULL, NULL));
                }
                tded = new TypeTuple(args);
                break;
            }
            case TOKreturn:
                /* Get the 'return type' for the function,
                 * delegate, or pointer to function.
                 */
                if (targ->ty == Tfunction)
                    tded = ((TypeFunction *)targ)->next;
                else if (targ->ty == Tdelegate)
                    tded = targ->next->next;
                else if (targ->ty == Tpointer && targ->next->ty == Tfunction)
                    tded = targ->next->next;
                else
                    goto Lno;
                break;

            case TOKargTypes:
                /* Generate a type tuple of the equivalent types used to determine if a
                 * function argument of this type can be passed in registers.
                 * The results of this are highly platform dependent, and intended
                 * primarly for use in implementing va_arg().
                 */
                tded = targ->toArgTypes();
                if (!tded)
                    goto Lno;           // not valid for a parameter
                break;

            default:
                assert(0);
        }
        goto Lyes;
    }
    else if (id && tspec)
    {
        /* Evaluate to TRUE if targ matches tspec.
         * If TRUE, declare id as an alias for the specialized type.
         */

        TemplateTypeParameter tp(loc, id, NULL, NULL);

        TemplateParameters parameters;
        parameters.setDim(1);
        parameters.data[0] = (void *)&tp;

        Objects dedtypes;
        dedtypes.setDim(parameters.dim);
        dedtypes.zero();

        MATCH m = targ->deduceType(sc, tspec, &parameters, &dedtypes);
        if (m == MATCHnomatch ||
            (m != MATCHexact && tok == TOKequal))
        {
            goto Lno;
        }
        else
        {
            assert(dedtypes.dim == 1);
            tded = (Type *)dedtypes.data[0];
            if (!tded)
                tded = targ;
#if DMDV2
            Objects tiargs;
            tiargs.setDim(1);
            tiargs.data[0] = (void *)targ;

            /* Declare trailing parameters
             */
            for (size_t i = 1; i < parameters->dim; i++)
            {   TemplateParameter *tp = (*parameters)[i];
                Declaration *s = NULL;

                m = tp->matchArg(sc, &tiargs, i, parameters, &dedtypes, &s);
                if (m == MATCHnomatch)
                    goto Lno;
                s->semantic(sc);
                if (sc->sd)
                    s->addMember(sc, sc->sd, 1);
                else if (!sc->insert(s))
                    error("declaration %s is already defined", s->toChars());
            }
#endif
            goto Lyes;
        }
    }
    else if (id)
    {
        /* Declare id as an alias for type targ. Evaluate to TRUE
         */
        tded = targ;
        goto Lyes;
    }
    else if (tspec)
    {
        /* Evaluate to TRUE if targ matches tspec
         * is(targ == tspec)
         * is(targ : tspec)
         */
        tspec = tspec->semantic(loc, sc);
        //printf("targ  = %s, %s\n", targ->toChars(), targ->deco);
        //printf("tspec = %s, %s\n", tspec->toChars(), tspec->deco);
        if (tok == TOKcolon)
        {   if (targ->implicitConvTo(tspec))
                goto Lyes;
            else
                goto Lno;
        }
        else /* == */
        {   if (targ->equals(tspec))
                goto Lyes;
            else
                goto Lno;
        }
    }

Lyes:
    if (id)
    {
        Dsymbol *s;
        Tuple *tup = isTuple(tded);
        if (tup)
            s = new TupleDeclaration(loc, id, &(tup->objects));
        else
            s = new AliasDeclaration(loc, id, tded);
        s->semantic(sc);
        /* The reason for the !tup is unclear. It fails Phobos unittests if it is not there.
         * More investigation is needed.
         */
        if (!tup && !sc->insert(s))
            error("declaration %s is already defined", s->toChars());
        if (sc->sd)
            s->addMember(sc, sc->sd, 1);
    }
    return new IntegerExp(1);

Lno:
    return new IntegerExp(0);
}

void IsExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("is(");
    targ->toCBuffer(buf, id, hgs);
    if (tok2 != TOKreserved)
    {
        buf->printf(" %s %s", Token::toChars(tok), Token::toChars(tok2));
    }
    else if (tspec)
    {
        if (tok == TOKcolon)
            buf->writestring(" : ");
        else
            buf->writestring(" == ");
        tspec->toCBuffer(buf, NULL, hgs);
    }
#if DMDV2
    if (parameters)
    {   // First parameter is already output, so start with second
        for (size_t i = 1; i < parameters->dim; i++)
        {
            buf->writeByte(',');
            TemplateParameter *tp = (TemplateParameter *)parameters->data[i];
            tp->toCBuffer(buf, hgs);
        }
    }
#endif
    buf->writeByte(')');
}


/************************************************************/

UnaExp::UnaExp(Loc loc, enum TOK op, int size, Expression *e1)
        : Expression(loc, op, size)
{
    this->e1 = e1;
}

Expression *UnaExp::syntaxCopy()
{   UnaExp *e;

    e = (UnaExp *)copy();
    e->type = NULL;
    e->e1 = e->e1->syntaxCopy();
    return e;
}

Expression *UnaExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("UnaExp::semantic('%s')\n", toChars());
#endif
    e1 = e1->semantic(sc);
//    if (!e1->type)
//      error("%s has no value", e1->toChars());
    return this;
}

#if DMDV2
int UnaExp::canThrow()
{
    return e1->canThrow();
}
#endif

Expression *UnaExp::resolveLoc(Loc loc, Scope *sc)
{
    e1 = e1->resolveLoc(loc, sc);
    return this;
}

void UnaExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring(Token::toChars(op));
    expToCBuffer(buf, hgs, e1, precedence[op]);
}

/************************************************************/

BinExp::BinExp(Loc loc, enum TOK op, int size, Expression *e1, Expression *e2)
        : Expression(loc, op, size)
{
    this->e1 = e1;
    this->e2 = e2;
}

Expression *BinExp::syntaxCopy()
{   BinExp *e;

    e = (BinExp *)copy();
    e->type = NULL;
    e->e1 = e->e1->syntaxCopy();
    e->e2 = e->e2->syntaxCopy();
    return e;
}

Expression *BinExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("BinExp::semantic('%s')\n", toChars());
#endif
    e1 = e1->semantic(sc);
    if (!e1->type &&
        !(op == TOKassign && e1->op == TOKdottd))       // a.template = e2
    {
        error("%s has no value", e1->toChars());
        e1 = new ErrorExp();
    }
    e2 = e2->semantic(sc);
    if (!e2->type)
    {
        error("%s has no value", e2->toChars());
        e2 = new ErrorExp();
    }
    if (e1->op == TOKerror || e2->op == TOKerror)
        return new ErrorExp();
    return this;
}

Expression *BinExp::semanticp(Scope *sc)
{
    BinExp::semantic(sc);
    e1 = resolveProperties(sc, e1);
    e2 = resolveProperties(sc, e2);
    return this;
}

/***************************
 * Common semantic routine for some xxxAssignExp's.
 */

Expression *BinExp::commonSemanticAssign(Scope *sc)
{   Expression *e;

    if (!type)
    {
        BinExp::semantic(sc);
        e2 = resolveProperties(sc, e2);

        e = op_overload(sc);
        if (e)
            return e;

        if (e1->op == TOKslice)
        {   // T[] op= ...
            e = typeCombine(sc);
            if (e->op == TOKerror)
                return e;
            type = e1->type;
            return arrayOp(sc);
        }

        e1 = e1->modifiableLvalue(sc, e1);
        e1->checkScalar();
        type = e1->type;
        if (type->toBasetype()->ty == Tbool)
        {
            error("operator not allowed on bool expression %s", toChars());
        }
        typeCombine(sc);
        e1->checkArithmetic();
        e2->checkArithmetic();

        if (op == TOKmodass && e2->type->iscomplex())
        {   error("cannot perform modulo complex arithmetic");
            return new ErrorExp();
        }
    }
    return this;
}

Expression *BinExp::commonSemanticAssignIntegral(Scope *sc)
{   Expression *e;

    if (!type)
    {
        BinExp::semantic(sc);
        e2 = resolveProperties(sc, e2);

        e = op_overload(sc);
        if (e)
            return e;

        if (e1->op == TOKslice)
        {   // T[] op= ...
            e = typeCombine(sc);
            if (e->op == TOKerror)
                return e;
            type = e1->type;
            return arrayOp(sc);
        }

        e1 = e1->modifiableLvalue(sc, e1);
        e1->checkScalar();
        type = e1->type;
        if (type->toBasetype()->ty == Tbool)
        {
            e2 = e2->implicitCastTo(sc, type);
        }

        typeCombine(sc);
        e1->checkIntegral();
        e2->checkIntegral();
    }
    return this;
}

int BinExp::checkSideEffect(int flag)
{
    if (op == TOKplusplus ||
           op == TOKminusminus ||
           op == TOKassign ||
           op == TOKconstruct ||
           op == TOKblit ||
           op == TOKaddass ||
           op == TOKminass ||
           op == TOKcatass ||
           op == TOKmulass ||
           op == TOKdivass ||
           op == TOKmodass ||
           op == TOKshlass ||
           op == TOKshrass ||
           op == TOKushrass ||
           op == TOKandass ||
           op == TOKorass ||
           op == TOKxorass ||
           op == TOKin ||
           op == TOKremove)
        return 1;
    return Expression::checkSideEffect(flag);
}

// generate an error if this is a nonsensical *=,/=, or %=, eg real *= imaginary
void BinExp::checkComplexMulAssign()
{
    // Any multiplication by an imaginary or complex number yields a complex result.
    // r *= c, i*=c, r*=i, i*=i are all forbidden operations.
    const char *opstr = Token::toChars(op);
    if ( e1->type->isreal() && e2->type->iscomplex())
    {
        error("%s %s %s is undefined. Did you mean %s %s %s.re ?",
            e1->type->toChars(), opstr, e2->type->toChars(),
            e1->type->toChars(), opstr, e2->type->toChars());
    }
    else if (e1->type->isimaginary() && e2->type->iscomplex())
    {
        error("%s %s %s is undefined. Did you mean %s %s %s.im ?",
            e1->type->toChars(), opstr, e2->type->toChars(),
            e1->type->toChars(), opstr, e2->type->toChars());
    }
    else if ((e1->type->isreal() || e1->type->isimaginary()) &&
        e2->type->isimaginary())
    {
        error("%s %s %s is an undefined operation", e1->type->toChars(),
                opstr, e2->type->toChars());
    }
}

// generate an error if this is a nonsensical += or -=, eg real += imaginary
void BinExp::checkComplexAddAssign()
{
    // Addition or subtraction of a real and an imaginary is a complex result.
    // Thus, r+=i, r+=c, i+=r, i+=c are all forbidden operations.
    if ( (e1->type->isreal() && (e2->type->isimaginary() || e2->type->iscomplex())) ||
         (e1->type->isimaginary() && (e2->type->isreal() || e2->type->iscomplex()))
        )
    {
        error("%s %s %s is undefined (result is complex)",
            e1->type->toChars(), Token::toChars(op), e2->type->toChars());
    }
}

void BinExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    expToCBuffer(buf, hgs, e1, precedence[op]);
    buf->writeByte(' ');
    buf->writestring(Token::toChars(op));
    buf->writeByte(' ');
    expToCBuffer(buf, hgs, e2, (enum PREC)(precedence[op] + 1));
}

int BinExp::isunsigned()
{
    return e1->type->isunsigned() || e2->type->isunsigned();
}

#if DMDV2
int BinExp::canThrow()
{
    return e1->canThrow() || e2->canThrow();
}
#endif

void BinExp::incompatibleTypes()
{
    if (e1->type->toBasetype() != Type::terror &&
        e2->type->toBasetype() != Type::terror
       )
        error("incompatible types for ((%s) %s (%s)): '%s' and '%s'",
             e1->toChars(), Token::toChars(op), e2->toChars(),
             e1->type->toChars(), e2->type->toChars());
}

/************************************************************/

Expression *BinAssignExp::semantic(Scope *sc)
{   Expression *e;

    //printf("BinAssignExp::semantic()\n");
    if (type)
        return this;
    BinExp::semantic(sc);
    e2 = resolveProperties(sc, e2);

    e = op_overload(sc);
    if (e)
        return e;

    e1 = e1->modifiableLvalue(sc, e1);
    e1->checkScalar();
    e1->checkNoBool();
    type = e1->type;
    typeCombine(sc);
    e1->checkIntegral();
    e2 = e2->checkIntegral();
    e2 = e2->castTo(sc, Type::tshiftcnt);
    return this;
}

int BinAssignExp::isLvalue()
{
    return 1;
}

/************************************************************/

CompileExp::CompileExp(Loc loc, Expression *e)
        : UnaExp(loc, TOKmixin, sizeof(CompileExp), e)
{
}

Expression *CompileExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("CompileExp::semantic('%s')\n", toChars());
#endif
    UnaExp::semantic(sc);
    e1 = resolveProperties(sc, e1);
    if (e1->op == TOKerror)
        return e1;
    if (!e1->type->isString())
    {
        error("argument to mixin must be a string type, not %s\n", e1->type->toChars());
        return new ErrorExp();
    }
    e1 = e1->ctfeInterpret();
    StringExp *se = e1->toString();
    if (!se)
    {   error("argument to mixin must be a string, not (%s)", e1->toChars());
        return new ErrorExp();
    }
    se = se->toUTF8(sc);
    Parser p(sc->module, (unsigned char *)se->string, se->len, 0);
    p.loc = loc;
    p.nextToken();
    //printf("p.loc.linnum = %d\n", p.loc.linnum);
    unsigned errors = global.errors;
    Expression *e = p.parseExpression();
    if (global.errors != errors)
        return new ErrorExp();
    if (p.token.value != TOKeof)
        error("incomplete mixin expression (%s)", se->toChars());
    return e->semantic(sc);
}

void CompileExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("mixin(");
    expToCBuffer(buf, hgs, e1, PREC_assign);
    buf->writeByte(')');
}

/************************************************************/

FileExp::FileExp(Loc loc, Expression *e)
        : UnaExp(loc, TOKmixin, sizeof(FileExp), e)
{
}

Expression *FileExp::semantic(Scope *sc)
{   const char *name;
    StringExp *se;

#if LOGSEMANTIC
    printf("FileExp::semantic('%s')\n", toChars());
#endif
    UnaExp::semantic(sc);
    e1 = resolveProperties(sc, e1);
    e1 = e1->ctfeInterpret();
    if (e1->op != TOKstring)
    {   error("file name argument must be a string, not (%s)", e1->toChars());
        goto Lerror;
    }
    se = (StringExp *)e1;
    se = se->toUTF8(sc);
    name = (char *)se->string;

    if (!global.params.fileImppath)
    {   error("need -Jpath switch to import text file %s", name);
        goto Lerror;
    }

    /* Be wary of CWE-22: Improper Limitation of a Pathname to a Restricted Directory
     * ('Path Traversal') attacks.
     * http://cwe.mitre.org/data/definitions/22.html
     */

    name = FileName::safeSearchPath((Strings *)global.filePath, name);
    if (!name)
    {   error("file %s cannot be found or not in a path specified with -J", se->toChars());
        goto Lerror;
    }

    if (global.params.verbose)
        printf("file      %s\t(%s)\n", (char *)se->string, name);

    {   File f((char *)name);
        if (f.read())
        {   error("cannot read file %s", f.toChars());
            goto Lerror;
        }
        else
        {
            f.ref = 1;
            se = new StringExp(loc, f.buffer, f.len);
        }
    }
    return se->semantic(sc);

  Lerror:
    return new ErrorExp();
}

void FileExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("import(");
    expToCBuffer(buf, hgs, e1, PREC_assign);
    buf->writeByte(')');
}

/************************************************************/

AssertExp::AssertExp(Loc loc, Expression *e, Expression *msg)
        : UnaExp(loc, TOKassert, sizeof(AssertExp), e)
{
    this->msg = msg;
}

Expression *AssertExp::syntaxCopy()
{
    AssertExp *ae = new AssertExp(loc, e1->syntaxCopy(),
                                       msg ? msg->syntaxCopy() : NULL);
    return ae;
}

Expression *AssertExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("AssertExp::semantic('%s')\n", toChars());
#endif
    UnaExp::semantic(sc);
    e1 = resolveProperties(sc, e1);
    // BUG: see if we can do compile time elimination of the Assert
    e1 = e1->optimize(WANTvalue);
    e1 = e1->checkToBoolean();
    if (msg)
    {
        msg = msg->semantic(sc);
        msg = resolveProperties(sc, msg);
        msg = msg->implicitCastTo(sc, Type::tchar->arrayOf());
        msg = msg->optimize(WANTvalue);
    }
    if (e1->isBool(FALSE))
    {
        FuncDeclaration *fd = sc->parent->isFuncDeclaration();
        if (fd)
            fd->hasReturnExp |= 4;

        if (!global.params.useAssert)
        {   Expression *e = new HaltExp(loc);
            e = e->semantic(sc);
            return e;
        }
    }
    type = Type::tvoid;
    return this;
}

int AssertExp::checkSideEffect(int flag)
{
    return 1;
}

#if DMDV2
int AssertExp::canThrow()
{
    /* assert()s are non-recoverable errors, so functions that
     * use them can be considered "nothrow"
     */
    return 0; //(global.params.useAssert != 0);
}
#endif

void AssertExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("assert(");
    expToCBuffer(buf, hgs, e1, PREC_assign);
    if (msg)
    {
        buf->writeByte(',');
        expToCBuffer(buf, hgs, msg, PREC_assign);
    }
    buf->writeByte(')');
}

/************************************************************/

DotIdExp::DotIdExp(Loc loc, Expression *e, Identifier *ident)
        : UnaExp(loc, TOKdot, sizeof(DotIdExp), e)
{
    this->ident = ident;
}

Expression *DotIdExp::semantic(Scope *sc)
{   Expression *e;
    Expression *eleft;
    Expression *eright;

#if LOGSEMANTIC
    printf("DotIdExp::semantic(this = %p, '%s')\n", this, toChars());
    //printf("e1->op = %d, '%s'\n", e1->op, Token::toChars(e1->op));
#endif

//{ static int z; fflush(stdout); if (++z == 10) *(char*)0=0; }

#if 0
    /* Don't do semantic analysis if we'll be converting
     * it to a string.
     */
    if (ident == Id::stringof)
    {   char *s = e1->toChars();
        e = new StringExp(loc, s, strlen(s), 'c');
        e = e->semantic(sc);
        return e;
    }
#endif

    /* Special case: rewrite this.id and super.id
     * to be classtype.id and baseclasstype.id
     * if we have no this pointer.
     */
    if ((e1->op == TOKthis || e1->op == TOKsuper) && !hasThis(sc))
    {   ClassDeclaration *cd;
        StructDeclaration *sd;
        AggregateDeclaration *ad;

        ad = sc->getStructClassScope();
        if (ad)
        {
            cd = ad->isClassDeclaration();
            if (cd)
            {
                if (e1->op == TOKthis)
                {
                    e = typeDotIdExp(loc, cd->type, ident);
                    return e->semantic(sc);
                }
                else if (cd->baseClass && e1->op == TOKsuper)
                {
                    e = typeDotIdExp(loc, cd->baseClass->type, ident);
                    return e->semantic(sc);
                }
            }
            else
            {
                sd = ad->isStructDeclaration();
                if (sd)
                {
                    if (e1->op == TOKthis)
                    {
                        e = typeDotIdExp(loc, sd->type, ident);
                        return e->semantic(sc);
                    }
                }
            }
        }
    }

    UnaExp::semantic(sc);

    if (ident == Id::mangleof)
    {   // symbol.mangleof
        Dsymbol *ds;
        switch (e1->op)
        {
            case TOKimport: ds = ((ScopeExp *)e1)->sds;     goto L1;
            case TOKvar:    ds = ((VarExp *)e1)->var;       goto L1;
            case TOKdotvar: ds = ((DotVarExp *)e1)->var;    goto L1;
        L1:
                char* s = ds->mangle();
                e = new StringExp(loc, s, strlen(s), 'c');
                e = e->semantic(sc);
                return e;
        }
    }

    if (e1->op == TOKdotexp)
    {
        DotExp *de = (DotExp *)e1;
        eleft = de->e1;
        eright = de->e2;
    }
    else
    {
        if (e1->op != TOKtype)
            e1 = resolveProperties(sc, e1);
        eleft = NULL;
        eright = e1;
    }
#if DMDV2
    if (e1->op == TOKtuple && ident == Id::offsetof)
    {   /* 'distribute' the .offsetof to each of the tuple elements.
         */
        TupleExp *te = (TupleExp *)e1;
        Expressions *exps = new Expressions();
        exps->setDim(te->exps->dim);
        for (size_t i = 0; i < exps->dim; i++)
        {   Expression *e = (Expression *)te->exps->data[i];
            e = e->semantic(sc);
            e = new DotIdExp(e->loc, e, Id::offsetof);
            exps->data[i] = (void *)e;
        }
        e = new TupleExp(loc, exps);
        e = e->semantic(sc);
        return e;
    }
#endif

    if (e1->op == TOKtuple && ident == Id::length)
    {
        TupleExp *te = (TupleExp *)e1;
        e = new IntegerExp(loc, te->exps->dim, Type::tsize_t);
        return e;
    }

    if (e1->op == TOKdottd)
    {
        error("template %s does not have property %s", e1->toChars(), ident->toChars());
        return new ErrorExp();
    }

    if (!e1->type)
    {
        error("expression %s does not have property %s", e1->toChars(), ident->toChars());
        return new ErrorExp();
    }

    if (eright->op == TOKimport)        // also used for template alias's
    {
        ScopeExp *ie = (ScopeExp *)eright;

        /* Disable access to another module's private imports.
         * The check for 'is sds our current module' is because
         * the current module should have access to its own imports.
         */
        Dsymbol *s = ie->sds->search(loc, ident,
            (ie->sds->isModule() && ie->sds != sc->module) ? 1 : 0);
        if (s)
        {
            /* Check for access before resolving aliases because public
             * aliases to private symbols are public.
             */
            if (Declaration *d = s->isDeclaration())
                accessCheck(loc, sc, 0, d);

            s = s->toAlias();
            checkDeprecated(sc, s);

            EnumMember *em = s->isEnumMember();
            if (em)
            {
                e = em->value;
                e = e->semantic(sc);
                return e;
            }

            VarDeclaration *v = s->isVarDeclaration();
            if (v)
            {
                //printf("DotIdExp:: Identifier '%s' is a variable, type '%s'\n", toChars(), v->type->toChars());
                if (v->inuse)
                {
                    error("circular reference to '%s'", v->toChars());
                    type = Type::tint32;
                    return this;
                }
                type = v->type;
                if (v->isConst())
                {
                    if (v->init)
                    {
                        ExpInitializer *ei = v->init->isExpInitializer();
                        if (ei)
                        {
    //printf("\tei: %p (%s)\n", ei->exp, ei->exp->toChars());
    //ei->exp = ei->exp->semantic(sc);
                            if (ei->exp->type == type)
                            {
                                e = ei->exp->copy();    // make copy so we can change loc
                                e->loc = loc;
                                return e;
                            }
                        }
                    }
                    else if (type->isscalar())
                    {
                        e = type->defaultInit();
                        e->loc = loc;
                        return e;
                    }
                }
                if (v->needThis())
                {
                    if (!eleft)
                        eleft = new ThisExp(loc);
                    e = new DotVarExp(loc, eleft, v);
                    e = e->semantic(sc);
                }
                else
                {
                    e = new VarExp(loc, v);
                    if (eleft)
                    {   e = new CommaExp(loc, eleft, e);
                        e->type = v->type;
                    }
                }
                e = e->deref();
                return e->semantic(sc);
            }

            FuncDeclaration *f = s->isFuncDeclaration();
            if (f)
            {
                //printf("it's a function\n");
                if (f->needThis())
                {
                    if (!eleft)
                        eleft = new ThisExp(loc);
                    e = new DotVarExp(loc, eleft, f);
                    e = e->semantic(sc);
                }
                else
                {
                    e = new VarExp(loc, f);
                    if (eleft)
                    {   e = new CommaExp(loc, eleft, e);
                        e->type = f->type;
                    }
                }
                return e;
            }
#if DMDV2
            OverloadSet *o = s->isOverloadSet();
            if (o)
            {   //printf("'%s' is an overload set\n", o->toChars());
                return new OverExp(o);
            }
#endif

            Type *t = s->getType();
            if (t)
            {
                return new TypeExp(loc, t);
            }

            TupleDeclaration *tup = s->isTupleDeclaration();
            if (tup)
            {
                if (eleft)
                {   error("cannot have e.tuple");
                    return new ErrorExp();
                }
                e = new TupleExp(loc, tup);
                e = e->semantic(sc);
                return e;
            }

            ScopeDsymbol *sds = s->isScopeDsymbol();
            if (sds)
            {
                //printf("it's a ScopeDsymbol\n");
                e = new ScopeExp(loc, sds);
                e = e->semantic(sc);
                if (eleft)
                    e = new DotExp(loc, eleft, e);
                return e;
            }

            Import *imp = s->isImport();
            if (imp)
            {
                ScopeExp *ie;

                ie = new ScopeExp(loc, imp->pkg);
                return ie->semantic(sc);
            }

            // BUG: handle other cases like in IdentifierExp::semantic()
#ifdef DEBUG
            printf("s = '%s', kind = '%s'\n", s->toChars(), s->kind());
#endif
            assert(0);
        }
        else if (ident == Id::stringof)
        {   char *s = ie->toChars();
            e = new StringExp(loc, s, strlen(s), 'c');
            e = e->semantic(sc);
            return e;
        }
        s = ie->sds->search_correct(ident);
        if (s)
            error("undefined identifier '%s', did you mean '%s %s'?",
                  ident->toChars(), s->kind(), s->toChars());
        else
            error("undefined identifier '%s'", ident->toChars());
        return new ErrorExp();
    }
    else if (e1->type->ty == Tpointer &&
             ident != Id::init && ident != Id::__sizeof &&
             ident != Id::__xalignof && ident != Id::offsetof &&
             ident != Id::mangleof && ident != Id::stringof)
    {   /* Rewrite:
         *   p.ident
         * as:
         *   (*p).ident
         */
        e = new PtrExp(loc, e1);
        e->type = ((TypePointer *)e1->type)->next;
        return e->type->dotExp(sc, e, ident);
    }
#if DMDV2
    else if (t1b->ty == Tarray ||
             t1b->ty == Tsarray ||
             t1b->ty == Taarray)
    {   /* If ident is not a valid property, rewrite:
         *   e1.ident
         * as:
         *   .ident(e1)
         */
        unsigned errors = global.startGagging();
        Type *t1 = e1->type;
        e = e1->type->dotExp(sc, e1, ident);
        if (global.endGagging(errors))    // if failed to find the property
        {
            e1->type = t1;              // kludge to restore type
            e = new DotIdExp(loc, new IdentifierExp(loc, Id::empty), ident);
            e = new CallExp(loc, e, e1);
        }
        e = e->semantic(sc);
        return e;
    }
#endif
    else
    {
        e = e1->type->dotExp(sc, e1, ident);
        e = e->semantic(sc);
        return e;
    }
}

void DotIdExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    //printf("DotIdExp::toCBuffer()\n");
    expToCBuffer(buf, hgs, e1, PREC_primary);
    buf->writeByte('.');
    buf->writestring(ident->toChars());
}

/********************** DotTemplateExp ***********************************/

// Mainly just a placeholder

DotTemplateExp::DotTemplateExp(Loc loc, Expression *e, TemplateDeclaration *td)
        : UnaExp(loc, TOKdottd, sizeof(DotTemplateExp), e)

{
    this->td = td;
}

void DotTemplateExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    expToCBuffer(buf, hgs, e1, PREC_primary);
    buf->writeByte('.');
    buf->writestring(td->toChars());
}


/************************************************************/

DotVarExp::DotVarExp(Loc loc, Expression *e, Declaration *v)
        : UnaExp(loc, TOKdotvar, sizeof(DotVarExp), e)
{
    //printf("DotVarExp()\n");
    this->var = v;
}

Expression *DotVarExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("DotVarExp::semantic('%s')\n", toChars());
#endif
    if (!type)
    {
        var = var->toAlias()->isDeclaration();

        TupleDeclaration *tup = var->isTupleDeclaration();
        if (tup)
        {   /* Replace:
             *  e1.tuple(a, b, c)
             * with:
             *  tuple(e1.a, e1.b, e1.c)
             */
            Expressions *exps = new Expressions;

            exps->reserve(tup->objects->dim);
            for (size_t i = 0; i < tup->objects->dim; i++)
            {   Object *o = (*tup->objects)[i];
                Expression *e;
                if (o->dyncast() == DYNCAST_EXPRESSION)
                {
                    e = (Expression *)o;
                    if (e->op == TOKdsymbol)
                    {
                        DsymbolExp *ve = (DsymbolExp *)e;

                        e = new DotVarExp(loc, e1, ve->s->isDeclaration());
                    }
                }
                else if (o->dyncast() == DYNCAST_DSYMBOL)
                {
                    e = new DsymbolExp(loc, (Dsymbol *)o);
                }
                else if (o->dyncast() == DYNCAST_TYPE)
                {
                    e = new TypeExp(loc, (Type *)o);
                }
                else
                {
                    error("%s is not an expression", o->toChars());
                    goto Lerr;
                }
                exps->push(e);
            }
            Expression *e = new TupleExp(loc, exps);
            e = e->semantic(sc);
            return e;
        }

        e1 = e1->semantic(sc);
        type = var->type;
        if (!type && global.errors)
        {   // var is goofed up, just return 0
            return new ErrorExp();
        }
        assert(type);

        if (!var->isFuncDeclaration())  // for functions, do checks after overload resolution
        {
            Dsymbol *vparent = var->toParent();
            AggregateDeclaration *ad = vparent ? vparent->isAggregateDeclaration() : NULL;
            e1 = getRightThis(loc, sc, ad, e1, var);
            if (!sc->noaccesscheck)
                accessCheck(loc, sc, e1, var);

            VarDeclaration *v = var->isVarDeclaration();
            if (v && v->isConst())
            {   ExpInitializer *ei = v->getExpInitializer();
                if (ei)
                {   Expression *e = ei->exp->copy();
                    e = e->semantic(sc);
                    return e;
                }
                if (v->init)
                {   Expression *e = v->init->toExpression();
                    if (e)
                    {   e = e->copy();
                        e = e->semantic(sc);
                        return e;
                    }
                }
            }
        }
    }
    //printf("-DotVarExp::semantic('%s')\n", toChars());
    return this;

Lerr:
    return new ErrorExp();
}


int DotVarExp::isLvalue()
{
    return 1;
}


Expression *DotVarExp::toLvalue(Scope *sc, Expression *e)
{
    //printf("DotVarExp::toLvalue(%s)\n", toChars());
    return this;
}

Expression *DotVarExp::modifiableLvalue(Scope *sc, Expression *e)
{
#if 0
    printf("DotVarExp::modifiableLvalue(%s)\n", toChars());
    printf("e1->type = %s\n", e1->type->toChars());
    printf("var->type = %s\n", var->type->toChars());
#endif

    if (var->isCtorinit())
    {   // It's only modifiable if inside the right constructor
        Dsymbol *s = sc->func;
        while (1)
        {
            FuncDeclaration *fd = NULL;
            if (s)
                fd = s->isFuncDeclaration();
            if (fd &&
                ((fd->isCtorDeclaration() && var->storage_class & STCfield) ||
                 (fd->isStaticCtorDeclaration() && !(var->storage_class & STCfield))) &&
                fd->toParent2() == var->toParent() &&
                e1->op == TOKthis
               )
            {
                VarDeclaration *v = var->isVarDeclaration();
                assert(v);
                v->ctorinit = 1;
                //printf("setting ctorinit\n");
            }
            else
            {
                if (s)
                {   s = s->toParent2();
                    continue;
                }
                else
                {
                    const char *p = var->isStatic() ? "static " : "";
                    error("can only initialize %sconst member %s inside %sconstructor",
                        p, var->toChars(), p);
                }
            }
            break;
        }
    }
#if DMDV2
    else
    {
        Type *t1 = e1->type->toBasetype();

        if (!t1->isMutable() ||
            (t1->ty == Tpointer && !t1->nextOf()->isMutable()) ||
            !var->type->isMutable() ||
            !var->type->isAssignable() ||
            var->storage_class & STCmanifest
           )
            error("cannot modify const/immutable expression %s", toChars());
    }
#endif
    return this;
}

void DotVarExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    expToCBuffer(buf, hgs, e1, PREC_primary);
    buf->writeByte('.');
    buf->writestring(var->toChars());
}

/************************************************************/

/* Things like:
 *      foo.bar!(args)
 */

DotTemplateInstanceExp::DotTemplateInstanceExp(Loc loc, Expression *e, TemplateInstance *ti)
        : UnaExp(loc, TOKdotti, sizeof(DotTemplateInstanceExp), e)
{
    //printf("DotTemplateInstanceExp()\n");
    this->ti = ti;
}

Expression *DotTemplateInstanceExp::syntaxCopy()
{
    DotTemplateInstanceExp *de = new DotTemplateInstanceExp(loc,
        e1->syntaxCopy(),
        (TemplateInstance *)ti->syntaxCopy(NULL));
    return de;
}

Expression *DotTemplateInstanceExp::semantic(Scope *sc)
{
#if 1
#if LOGSEMANTIC
    printf("DotTemplateInstanceExp::semantic('%s')\n", toChars());
#endif
    Expression *eleft;
    Expression *e = new DotIdExp(loc, e1, ti->name);
L1:
    e = e->semantic(sc);
    if (e->op == TOKerror)
        return e;
    if (e->op == TOKdottd)
    {
        if (ti->errors)
            return new ErrorExp();
        DotTemplateExp *dte = (DotTemplateExp *)e;
        TemplateDeclaration *td = dte->td;
        eleft = dte->e1;
        ti->tempdecl = td;
#if DMDV2
        if (ti->needsTypeInference(sc))
        {
            e1 = eleft;                 // save result of semantic()
            return this;
        }
        else
#endif
            ti->semantic(sc);
        if (!ti->inst)                  // if template failed to expand
            return new ErrorExp();
        Dsymbol *s = ti->inst->toAlias();
        Declaration *v = s->isDeclaration();
        if (v)
        {
            /* Fix for Bugzilla 4003
             * The problem is a class template member function v returning a reference to the same
             * type as the enclosing template instantiation. This results in a nested instantiation,
             * which of course gets short circuited. The return type then gets set to
             * the template instance type before instantiation, rather than after.
             * We can detect this by the deco not being set. If so, go ahead and retry
             * the return type semantic.
             * The offending code is the return type from std.typecons.Tuple.slice:
             *    ref Tuple!(Types[from .. to]) slice(uint from, uint to)()
             *    {
             *        return *cast(typeof(return) *) &(field[from]);
             *    }
             * and this line from the following unittest:
             *    auto s = a.slice!(1, 3);
             * where s's type wound up not having semantic() run on it.
             */
            if (v->type && !v->type->deco)
                v->type = v->type->semantic(v->loc, sc);

            e = new DotVarExp(loc, eleft, v);
            e = e->semantic(sc);
            return e;
        }
        e = new ScopeExp(loc, ti);
        e = new DotExp(loc, eleft, e);
        e = e->semantic(sc);
        return e;
    }
    else if (e->op == TOKimport)
    {   ScopeExp *se = (ScopeExp *)e;
        TemplateDeclaration *td = se->sds->isTemplateDeclaration();
        if (!td)
        {   error("%s is not a template", e->toChars());
            return new ErrorExp();
        }
        ti->tempdecl = td;
        e = new ScopeExp(loc, ti);
        e = e->semantic(sc);
        return e;
    }
    else if (e->op == TOKdotexp)
    {   DotExp *de = (DotExp *)e;

        if (de->e2->op == TOKimport)
        {   // This should *really* be moved to ScopeExp::semantic()
            ScopeExp *se = (ScopeExp *)de->e2;
            de->e2 = new DsymbolExp(loc, se->sds);
            de->e2 = de->e2->semantic(sc);
        }

        if (de->e2->op == TOKtemplate)
        {   TemplateExp *te = (TemplateExp *) de->e2;
            e = new DotTemplateExp(loc,de->e1,te->td);
        }
        goto L1;
    }
    error("%s isn't a template", e->toChars());
    return new ErrorExp();
#else
    Dsymbol *s;
    Dsymbol *s2;
    TemplateDeclaration *td;
    Expression *e;
    Identifier *id;
    Type *t1;
    Expression *eleft = NULL;
    Expression *eright;

#if LOGSEMANTIC
    printf("DotTemplateInstanceExp::semantic('%s')\n", toChars());
#endif
    //e1->print();
    //print();
    e1 = e1->semantic(sc);
    t1 = e1->type;
    if (t1)
        t1 = t1->toBasetype();
    //t1->print();

    /* Extract the following from e1:
     *  s: the symbol which ti should be a member of
     *  eleft: if not NULL, it is the 'this' pointer for ti
     */

    if (e1->op == TOKdotexp)
    {   DotExp *de = (DotExp *)e1;
        eleft = de->e1;
        eright = de->e2;
    }
    else
    {   eleft = NULL;
        eright = e1;
    }
    if (eright->op == TOKimport)
    {
        s = ((ScopeExp *)eright)->sds;
    }
    else if (e1->op == TOKtype)
    {
        s = t1->isClassHandle();
        if (!s)
        {   if (t1->ty == Tstruct)
                s = ((TypeStruct *)t1)->sym;
            else
                goto L1;
        }
    }
    else if (t1 && (t1->ty == Tstruct || t1->ty == Tclass))
    {
        s = t1->toDsymbol(sc);
        eleft = e1;
    }
    else if (t1 && t1->ty == Tpointer)
    {
        t1 = ((TypePointer *)t1)->next->toBasetype();
        if (t1->ty != Tstruct)
            goto L1;
        s = t1->toDsymbol(sc);
        eleft = e1;
    }
    else
    {
      L1:
        error("template %s is not a member of %s", ti->toChars(), e1->toChars());
        goto Lerr;
    }

    assert(s);
    id = ti->name;
    s2 = s->search(loc, id, 0);
    if (!s2)
    {
        if (!s->ident)
            error("template identifier %s is not a member of undefined %s", id->toChars(), s->kind());
        else
            error("template identifier %s is not a member of %s %s", id->toChars(), s->kind(), s->ident->toChars());
        goto Lerr;
    }
    s = s2;
    s->semantic(sc);
    s = s->toAlias();
    td = s->isTemplateDeclaration();
    if (!td)
    {
        error("%s is not a template", id->toChars());
        goto Lerr;
    }
    if (global.errors)
        goto Lerr;

    ti->tempdecl = td;

    if (eleft)
    {   Declaration *v;

        ti->semantic(sc);
        s = ti->inst->toAlias();
        v = s->isDeclaration();
        if (v)
        {   e = new DotVarExp(loc, eleft, v);
            e = e->semantic(sc);
            return e;
        }
    }

    e = new ScopeExp(loc, ti);
    if (eleft)
    {
        e = new DotExp(loc, eleft, e);
    }
    e = e->semantic(sc);
    return e;

Lerr:
    return new IntegerExp(loc, 0, Type::tint32);
#endif
}

void DotTemplateInstanceExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    expToCBuffer(buf, hgs, e1, PREC_primary);
    buf->writeByte('.');
    ti->toCBuffer(buf, hgs);
}

/************************************************************/

DelegateExp::DelegateExp(Loc loc, Expression *e, FuncDeclaration *f)
        : UnaExp(loc, TOKdelegate, sizeof(DelegateExp), e)
{
    this->func = f;
    this->hasOverloads = 0;
}

Expression *DelegateExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("DelegateExp::semantic('%s')\n", toChars());
#endif
    if (!type)
    {
        e1 = e1->semantic(sc);
        type = new TypeDelegate(func->type);
        type = type->semantic(loc, sc);
        AggregateDeclaration *ad = func->toParent()->isAggregateDeclaration();
        if (func->needThis())
            e1 = getRightThis(loc, sc, ad, e1, func);
        if (ad && ad->isClassDeclaration() && ad->type != e1->type)
        {   // A downcast is required for interfaces, see Bugzilla 3706
            e1 = new CastExp(loc, e1, ad->type);
            e1 = e1->semantic(sc);
        }
    }
    return this;
}

void DelegateExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writeByte('&');
    if (!func->isNested())
    {
        expToCBuffer(buf, hgs, e1, PREC_primary);
        buf->writeByte('.');
    }
    buf->writestring(func->toChars());
}

/************************************************************/

DotTypeExp::DotTypeExp(Loc loc, Expression *e, Dsymbol *s)
        : UnaExp(loc, TOKdottype, sizeof(DotTypeExp), e)
{
    this->sym = s;
    this->type = s->getType();
}

Expression *DotTypeExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("DotTypeExp::semantic('%s')\n", toChars());
#endif
    UnaExp::semantic(sc);
    return this;
}

void DotTypeExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    expToCBuffer(buf, hgs, e1, PREC_primary);
    buf->writeByte('.');
    buf->writestring(sym->toChars());
}

/************************************************************/

CallExp::CallExp(Loc loc, Expression *e, Expressions *exps)
        : UnaExp(loc, TOKcall, sizeof(CallExp), e)
{
    this->arguments = exps;
}

CallExp::CallExp(Loc loc, Expression *e)
        : UnaExp(loc, TOKcall, sizeof(CallExp), e)
{
    this->arguments = NULL;
}

CallExp::CallExp(Loc loc, Expression *e, Expression *earg1)
        : UnaExp(loc, TOKcall, sizeof(CallExp), e)
{
    Expressions *arguments = new Expressions();
    if (earg1)
    {   arguments->setDim(1);
        arguments->data[0] = (void *)earg1;
    }
    this->arguments = arguments;
}

CallExp::CallExp(Loc loc, Expression *e, Expression *earg1, Expression *earg2)
        : UnaExp(loc, TOKcall, sizeof(CallExp), e)
{
    Expressions *arguments = new Expressions();
    arguments->setDim(2);
    arguments->data[0] = (void *)earg1;
    arguments->data[1] = (void *)earg2;

    this->arguments = arguments;
}

Expression *CallExp::syntaxCopy()
{
    return new CallExp(loc, e1->syntaxCopy(), arraySyntaxCopy(arguments));
}


Expression *CallExp::semantic(Scope *sc)
{
    TypeFunction *tf;
    FuncDeclaration *f;
    Type *t1;
    int istemp;
    Objects *targsi = NULL;     // initial list of template arguments

#if LOGSEMANTIC
    printf("CallExp::semantic() %s\n", toChars());
#endif
    if (type)
        return this;            // semantic() already run
#if 0
    if (arguments && arguments->dim)
    {
        Expression *earg = (Expression *)arguments->data[0];
        earg->print();
        if (earg->type) earg->type->print();
    }
#endif

    if (e1->op == TOKdelegate)
    {   DelegateExp *de = (DelegateExp *)e1;

        e1 = new DotVarExp(de->loc, de->e1, de->func);
        return semantic(sc);
    }

    /* Transform:
     *  array.id(args) into id(array,args)
     *  aa.remove(arg) into delete aa[arg]
     */
    if (e1->op == TOKdot)
    {
        // BUG: we should handle array.a.b.c.e(args) too

        DotIdExp *dotid = (DotIdExp *)(e1);
        dotid->e1 = dotid->e1->semantic(sc);
        assert(dotid->e1);
        if (dotid->e1->type)
        {
            TY e1ty = dotid->e1->type->toBasetype()->ty;
            if (e1ty == Taarray && dotid->ident == Id::remove)
            {
                if (!arguments || arguments->dim != 1)
                {   error("expected key as argument to aa.remove()");
                    goto Lagain;
                }
                Expression *key = (Expression *)arguments->data[0];
                key = key->semantic(sc);
                key = resolveProperties(sc, key);
                key->rvalue();

                TypeAArray *taa = (TypeAArray *)dotid->e1->type->toBasetype();
                key = key->implicitCastTo(sc, taa->index);
                key = key->implicitCastTo(sc, taa->key);

                return new RemoveExp(loc, dotid->e1, key);
            }
            else if (e1ty == Tarray || e1ty == Tsarray || e1ty == Taarray)
            {
                if (!arguments)
                    arguments = new Expressions();
                arguments->shift(dotid->e1);
#if DMDV2
                e1 = new DotIdExp(dotid->loc, new IdentifierExp(dotid->loc, Id::empty), dotid->ident);
#else
                e1 = new IdentifierExp(dotid->loc, dotid->ident);
#endif
            }
        }
    }

#if 1
    /* This recognizes:
     *  foo!(tiargs)(funcargs)
     */
    if (e1->op == TOKimport && !e1->type)
    {   ScopeExp *se = (ScopeExp *)e1;
        TemplateInstance *ti = se->sds->isTemplateInstance();
        if (ti && !ti->semanticRun)
        {
            /* Attempt to instantiate ti. If that works, go with it.
             * If not, go with partial explicit specialization.
             */
            ti->semanticTiargs(sc);
            unsigned errors = global.startGagging();
            ti->semantic(sc);
            if (global.endGagging(errors))
            {
                /* Didn't work, go with partial explicit specialization
                 */
                targsi = ti->tiargs;
                e1 = new IdentifierExp(loc, ti->name);
            }
        }
    }

    /* This recognizes:
     *  expr.foo!(tiargs)(funcargs)
     */
    if (e1->op == TOKdotti && !e1->type)
    {   DotTemplateInstanceExp *se = (DotTemplateInstanceExp *)e1;
        TemplateInstance *ti = se->ti;
        if (!ti->semanticRun)
        {
            /* Attempt to instantiate ti. If that works, go with it.
             * If not, go with partial explicit specialization.
             */
            ti->semanticTiargs(sc);
            Expression *etmp;
            unsigned errors = global.startGagging();
            etmp = e1->semantic(sc);
            if (global.endGagging(errors))
            {
                targsi = ti->tiargs;
                e1 = new DotIdExp(loc, se->e1, ti->name);
            }
            else
                e1 = etmp;
        }
    }
#endif

    istemp = 0;
Lagain:
    //printf("Lagain: %s\n", toChars());
    f = NULL;
    if (e1->op == TOKthis || e1->op == TOKsuper)
    {
        // semantic() run later for these
    }
    else
    {
            static int nest;
            if (++nest > 500)
            {
                error("recursive evaluation of %s", toChars());
                --nest;
                return new ErrorExp();
            }
        UnaExp::semantic(sc);
        --nest;

        /* Look for e1 being a lazy parameter
         */
        if (e1->op == TOKvar)
        {   VarExp *ve = (VarExp *)e1;

            if (ve->var->storage_class & STClazy)
            {
                TypeFunction *tf = new TypeFunction(NULL, ve->var->type, 0, LINKd);
                TypeDelegate *t = new TypeDelegate(tf);
                ve->type = t->semantic(loc, sc);
            }
        }

        if (e1->op == TOKimport)
        {   // Perhaps this should be moved to ScopeExp::semantic()
            ScopeExp *se = (ScopeExp *)e1;
            e1 = new DsymbolExp(loc, se->sds);
            e1 = e1->semantic(sc);
        }
#if DMDV2
        else if (e1->op == TOKsymoff && ((SymOffExp *)e1)->hasOverloads)
        {
            SymOffExp *se = (SymOffExp *)e1;
            e1 = new VarExp(se->loc, se->var, 1);
            e1 = e1->semantic(sc);
        }
#endif
#if 1   // patch for #540 by Oskar Linde
        else if (e1->op == TOKdotexp)
        {
            DotExp *de = (DotExp *) e1;

            if (de->e2->op == TOKimport)
            {   // This should *really* be moved to ScopeExp::semantic()
                ScopeExp *se = (ScopeExp *)de->e2;
                de->e2 = new DsymbolExp(loc, se->sds);
                de->e2 = de->e2->semantic(sc);
            }

            if (de->e2->op == TOKtemplate)
            {   TemplateExp *te = (TemplateExp *) de->e2;
                e1 = new DotTemplateExp(loc,de->e1,te->td);
            }
        }
#endif
    }

    if (e1->op == TOKcomma)
    {
        CommaExp *ce = (CommaExp *)e1;

        e1 = ce->e2;
        e1->type = ce->type;
        ce->e2 = this;
        ce->type = NULL;
        return ce->semantic(sc);
    }

    t1 = NULL;
    if (e1->type)
        t1 = e1->type->toBasetype();

    // Check for call operator overload
    if (t1)
    {   AggregateDeclaration *ad;

        if (t1->ty == Tstruct)
        {
            ad = ((TypeStruct *)t1)->sym;
#if DMDV2
            // First look for constructor
            if (ad->ctor && arguments && arguments->dim)
            {
                // Create variable that will get constructed
                Identifier *idtmp = Lexer::uniqueId("__ctmp");
                VarDeclaration *tmp = new VarDeclaration(loc, t1, idtmp, NULL);
                Expression *av = new DeclarationExp(loc, tmp);
                av = new CommaExp(loc, av, new VarExp(loc, tmp));

                Expression *e;
                CtorDeclaration *cf = ad->ctor->isCtorDeclaration();
                if (cf)
                    e = new DotVarExp(loc, av, cf, 1);
                else
                {   TemplateDeclaration *td = ad->ctor->isTemplateDeclaration();
                    assert(td);
                    e = new DotTemplateExp(loc, av, td);
                }
                e = new CallExp(loc, e, arguments);
#if !STRUCTTHISREF
                /* Constructors return a pointer to the instance
                 */
                e = new PtrExp(loc, e);
#endif
                e = e->semantic(sc);
                return e;
            }
#endif
            // No constructor, look for overload of opCall
            if (search_function(ad, Id::call))
                goto L1;        // overload of opCall, therefore it's a call

            if (e1->op != TOKtype)
                error("%s %s does not overload ()", ad->kind(), ad->toChars());
            /* It's a struct literal
             */
            Expression *e = new StructLiteralExp(loc, (StructDeclaration *)ad, arguments);
            e = e->semantic(sc);
            e->type = e1->type;         // in case e1->type was a typedef
            return e;
        }
        else if (t1->ty == Tclass)
        {
            ad = ((TypeClass *)t1)->sym;
            goto L1;
        L1:
            // Rewrite as e1.call(arguments)
            Expression *e = new DotIdExp(loc, e1, Id::call);
            e = new CallExp(loc, e, arguments);
            e = e->semantic(sc);
            return e;
        }
    }

    arrayExpressionSemantic(arguments, sc);
    preFunctionParameters(loc, sc, arguments);

    // If there was an error processing any template argument,
    // return an error without trying to resolve the template.
    if (targsi && targsi->dim)
    {
        for (size_t k = 0; k < targsi->dim; k++)
        {   Object *o = targsi->tdata()[k];
            if (isError(o))
                return new ErrorExp();
        }
    }

    if (e1->op == TOKdotvar && t1->ty == Tfunction ||
        e1->op == TOKdottd)
    {
        DotVarExp *dve;
        DotTemplateExp *dte;
        AggregateDeclaration *ad;
        UnaExp *ue = (UnaExp *)(e1);

        if (e1->op == TOKdotvar)
        {   // Do overload resolution
            dve = (DotVarExp *)(e1);

            f = dve->var->isFuncDeclaration();
            assert(f);
            f = f->overloadResolve(loc, NULL, arguments);

            ad = f->toParent()->isAggregateDeclaration();
        }
        else
        {   dte = (DotTemplateExp *)(e1);
            TemplateDeclaration *td = dte->td;
            assert(td);
            if (!arguments)
                // Should fix deduceFunctionTemplate() so it works on NULL argument
                arguments = new Expressions();
            f = td->deduceFunctionTemplate(sc, loc, targsi, NULL, arguments);
            if (!f)
                return new ErrorExp();
            ad = td->toParent()->isAggregateDeclaration();
        }
        if (f->needThis())
        {
            ue->e1 = getRightThis(loc, sc, ad, ue->e1, f);
        }

        /* Cannot call public functions from inside invariant
         * (because then the invariant would have infinite recursion)
         */
        if (sc->func && sc->func->isInvariantDeclaration() &&
            ue->e1->op == TOKthis &&
            f->addPostInvariant()
           )
        {
            error("cannot call public/export function %s from invariant", f->toChars());
            return new ErrorExp();
        }

        checkDeprecated(sc, f);
#if DMDV2
        checkPurity(sc, f);
        checkSafety(sc, f);
#endif
        accessCheck(loc, sc, ue->e1, f);
        if (!f->needThis())
        {
            VarExp *ve = new VarExp(loc, f);
            if ((ue->e1)->op == TOKtype) // just a FQN
                e1 = ve;
            else // things like (new Foo).bar()
                e1 = new CommaExp(loc, ue->e1, ve);
            e1->type = f->type;
        }
        else
        {
            if (e1->op == TOKdotvar)
            {
                dve->var = f;
                e1->type = f->type;
            }
            else
            {
                e1 = new DotVarExp(loc, dte->e1, f);
                e1 = e1->semantic(sc);
            }

            // See if we need to adjust the 'this' pointer
            AggregateDeclaration *ad = f->isThis();
            ClassDeclaration *cd = ue->e1->type->isClassHandle();
            if (ad && cd && ad->isClassDeclaration() && ad != cd &&
                ue->e1->op != TOKsuper)
            {
                ue->e1 = ue->e1->castTo(sc, ad->type); //new CastExp(loc, ue->e1, ad->type);
                ue->e1 = ue->e1->semantic(sc);
            }
        }
        t1 = e1->type;
    }
    else if (e1->op == TOKsuper)
    {
        // Base class constructor call
        ClassDeclaration *cd = NULL;

        if (sc->func)
            cd = sc->func->toParent()->isClassDeclaration();
        if (!cd || !cd->baseClass || !sc->func->isCtorDeclaration())
        {
            error("super class constructor call must be in a constructor");
            return new ErrorExp();
        }
        else
        {
            f = cd->baseClass->ctor;
            if (!f)
            {   error("no super class constructor for %s", cd->baseClass->toChars());
                return new ErrorExp();
            }
            else
            {
                if (!sc->intypeof)
                {
#if 0
                    if (sc->callSuper & (CSXthis | CSXsuper))
                        error("reference to this before super()");
#endif
                    if (sc->noctor || sc->callSuper & CSXlabel)
                        error("constructor calls not allowed in loops or after labels");
                    if (sc->callSuper & (CSXsuper_ctor | CSXthis_ctor))
                        error("multiple constructor calls");
                    if ((sc->callSuper & CSXreturn) && !(sc->callSuper & CSXany_ctor))
                        error("an earlier return statement skips constructor");
                    sc->callSuper |= CSXany_ctor | CSXsuper_ctor;
                }

                f = f->overloadResolve(loc, NULL, arguments);
                accessCheck(loc, sc, NULL, f);
                checkDeprecated(sc, f);
#if DMDV2
                checkPurity(sc, f);
                checkSafety(sc, f);
#endif
                e1 = new DotVarExp(e1->loc, e1, f);
                e1 = e1->semantic(sc);
                t1 = e1->type;
            }
        }
    }
    else if (e1->op == TOKthis)
    {
        // same class constructor call
        ClassDeclaration *cd = NULL;

        if (sc->func)
            cd = sc->func->toParent()->isClassDeclaration();
        if (!cd || !sc->func->isCtorDeclaration())
        {
            error("class constructor call must be in a constructor");
            return new ErrorExp();
        }
        else
        {
            if (!sc->intypeof)
            {
#if 0
                if (sc->callSuper & (CSXthis | CSXsuper))
                    error("reference to this before super()");
#endif
                if (sc->noctor || sc->callSuper & CSXlabel)
                    error("constructor calls not allowed in loops or after labels");
                if (sc->callSuper & (CSXsuper_ctor | CSXthis_ctor))
                    error("multiple constructor calls");
                if ((sc->callSuper & CSXreturn) && !(sc->callSuper & CSXany_ctor))
                    error("an earlier return statement skips constructor");
                sc->callSuper |= CSXany_ctor | CSXthis_ctor;
            }

            f = cd->ctor;
            f = f->overloadResolve(loc, NULL, arguments);
            checkDeprecated(sc, f);
#if DMDV2
            checkPurity(sc, f);
            checkSafety(sc, f);
#endif
            e1 = new DotVarExp(e1->loc, e1, f);
            e1 = e1->semantic(sc);
            t1 = e1->type;

            // BUG: this should really be done by checking the static
            // call graph
            if (f == sc->func)
            {   error("cyclic constructor call");
                return new ErrorExp();
            }
        }
    }
    else if (!t1)
    {
        error("function expected before (), not '%s'", e1->toChars());
        return new ErrorExp();
    }
    else if (t1->ty != Tfunction)
    {
        if (t1->ty == Tdelegate)
        {   TypeDelegate *td = (TypeDelegate *)t1;
            assert(td->next->ty == Tfunction);
            tf = (TypeFunction *)(td->next);
            goto Lcheckargs;
        }
        else if (t1->ty == Tpointer && ((TypePointer *)t1)->next->ty == Tfunction)
        {
            Expression *e = new PtrExp(loc, e1);
            t1 = ((TypePointer *)t1)->next;
            e->type = t1;
            e1 = e;
        }
        else if (e1->op == TOKtemplate)
        {
            TemplateExp *te = (TemplateExp *)e1;
            f = te->td->deduceFunctionTemplate(sc, loc, targsi, NULL, arguments);
            if (!f)
            {
                return new ErrorExp();
            }
            if (f->needThis() && hasThis(sc))
            {
                // Supply an implicit 'this', as in
                //        this.ident

                e1 = new DotTemplateExp(loc, (new ThisExp(loc))->semantic(sc), te->td);
                goto Lagain;
            }

            e1 = new VarExp(loc, f);
            goto Lagain;
        }
        else
        {   error("function expected before (), not %s of type %s", e1->toChars(), e1->type->toChars());
            return new ErrorExp();
        }
    }
    else if (e1->op == TOKvar)
    {
        // Do overload resolution
        VarExp *ve = (VarExp *)e1;

        f = ve->var->isFuncDeclaration();
        assert(f);

        // Look to see if f is really a function template
        if (0 && !istemp && f->parent)
        {   TemplateInstance *ti = f->parent->isTemplateInstance();

            if (ti &&
                (ti->name == f->ident ||
                 ti->toAlias()->ident == f->ident)
                &&
                ti->tempdecl)
            {
                /* This is so that one can refer to the enclosing
                 * template, even if it has the same name as a member
                 * of the template, if it has a !(arguments)
                 */
                TemplateDeclaration *tempdecl = ti->tempdecl;
                if (tempdecl->overroot)         // if not start of overloaded list of TemplateDeclaration's
                    tempdecl = tempdecl->overroot; // then get the start
                e1 = new TemplateExp(loc, tempdecl);
                istemp = 1;
                goto Lagain;
            }
        }

        f = f->overloadResolve(loc, NULL, arguments);
        checkDeprecated(sc, f);
#if DMDV2
        checkPurity(sc, f);
        checkSafety(sc, f);
#endif

        if (f->needThis() && hasThis(sc))
        {
            // Supply an implicit 'this', as in
            //    this.ident

            e1 = new DotVarExp(loc, new ThisExp(loc), f);
            goto Lagain;
        }

        accessCheck(loc, sc, NULL, f);

        ve->var = f;
        ve->type = f->type;
        t1 = f->type;
    }
    assert(t1->ty == Tfunction);
    tf = (TypeFunction *)(t1);

Lcheckargs:
    assert(tf->ty == Tfunction);
    type = tf->next;

    if (!arguments)
        arguments = new Expressions();
    int olderrors = global.errors;
    functionParameters(loc, sc, tf, arguments);
    if (olderrors != global.errors)
        return new ErrorExp();

    if (!type)
    {
        error("forward reference to inferred return type of function call %s", toChars());
        return new ErrorExp();
    }

    if (f && f->tintro)
    {
        Type *t = type;
        int offset = 0;
        TypeFunction *tf = (TypeFunction *)f->tintro;

        if (tf->next->isBaseOf(t, &offset) && offset)
        {
            type = tf->next;
            return castTo(sc, t);
        }
    }

    return this;
}

int CallExp::checkSideEffect(int flag)
{
#if DMDV2
    int result = 1;

    /* Calling a function or delegate that is pure nothrow
     * has no side effects.
     */
    if (e1->type)
    {
        Type *t = e1->type->toBasetype();
        if ((t->ty == Tfunction && ((TypeFunction *)t)->purity > PUREweak &&
                                   ((TypeFunction *)t)->isnothrow)
            ||
            (t->ty == Tdelegate && ((TypeFunction *)((TypeDelegate *)t)->next)->purity > PUREweak &&
                                   ((TypeFunction *)((TypeDelegate *)t)->next)->isnothrow)
           )
        {
            result = 0;
            //if (flag == 0)
                //warning("pure nothrow function %s has no effect", e1->toChars());
        }
        else
            result = 1;
    }

    result |= e1->checkSideEffect(1);

    /* If any of the arguments have side effects, this expression does
     */
    for (size_t i = 0; i < arguments->dim; i++)
    {   Expression *e = arguments->tdata()[i];

        result |= e->checkSideEffect(1);
    }

    return result;
#else
    return 1;
#endif
}

#if DMDV2
int CallExp::canThrow()
{
    //printf("CallExp::canThrow() %s\n", toChars());
    if (e1->canThrow())
        return 1;

    /* If any of the arguments can throw, then this expression can throw
     */
    for (size_t i = 0; i < arguments->dim; i++)
    {   Expression *e = (Expression *)arguments->data[i];

        if (e && e->canThrow())
            return 1;
    }

    if (global.errors && !e1->type)
        return 0;                       // error recovery

    /* If calling a function or delegate that is typed as nothrow,
     * then this expression cannot throw.
     * Note that pure functions can throw.
     */
    Type *t = e1->type->toBasetype();
    if (t->ty == Tfunction && ((TypeFunction *)t)->isnothrow)
        return 0;
    if (t->ty == Tdelegate && ((TypeFunction *)((TypeDelegate *)t)->next)->isnothrow)
        return 0;

    return 1;
}
#endif

int CallExp::isLvalue()
{
    Type *tb = e1->type->toBasetype();
    if (tb->ty == Tdelegate || tb->ty == Tpointer)
        tb = tb->nextOf();
#if DMDV2
    if (tb->ty == Tfunction && ((TypeFunction *)tb)->isref)
    {
        if (e1->op == TOKdotvar)
            if (((DotVarExp *)e1)->var->isCtorDeclaration())
                return 0;
        return 1;               // function returns a reference
    }
#endif
    return 0;
}


Expression *CallExp::toLvalue(Scope *sc, Expression *e)
{
#if 1
    if (type->toBasetype()->ty == Tstruct)
        return this;
    else
#endif
        return Expression::toLvalue(sc, e);
}

Expression *CallExp::modifiableLvalue(Scope *sc, Expression *e)
{
#if 1
    return Expression::modifiableLvalue(sc, e);
#else
    /* Although function return values being usable as "ref" parameters is
     * unsound, disabling it breaks existing code.
     * Bugzilla 3167
     */
    error("cannot assign to function call");
    return toLvalue(sc, e);
#endif
}

void CallExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    if (e1->op == TOKtype)
        /* Avoid parens around type to prevent forbidden cast syntax:
         *   (sometype)(arg1)
         * This is ok since types in constructor calls
         * can never depend on parens anyway
         */
        e1->toCBuffer(buf, hgs);
    else
        expToCBuffer(buf, hgs, e1, precedence[op]);
    buf->writeByte('(');
    argsToCBuffer(buf, arguments, hgs);
    buf->writeByte(')');
}


/************************************************************/

AddrExp::AddrExp(Loc loc, Expression *e)
        : UnaExp(loc, TOKaddress, sizeof(AddrExp), e)
{
}

Expression *AddrExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("AddrExp::semantic('%s')\n", toChars());
#endif
    if (!type)
    {
        UnaExp::semantic(sc);
        if (e1->type == Type::terror)
            return new ErrorExp();
        e1 = e1->toLvalue(sc, NULL);
        if (e1->op == TOKerror)
            return e1;
        if (!e1->type)
        {
            error("cannot take address of %s", e1->toChars());
            return new ErrorExp();
        }
        if (!e1->type->deco)
        {
            /* No deco means semantic() was not run on the type.
             * We have to run semantic() on the symbol to get the right type:
             *  auto x = &bar;
             *  pure: int bar() { return 1;}
             * otherwise the 'pure' is missing from the type assigned to x.
             */

            error("forward reference to %s", e1->toChars());
            return new ErrorExp();
        }
        type = e1->type->pointerTo();

        // See if this should really be a delegate
        if (e1->op == TOKdotvar)
        {
            DotVarExp *dve = (DotVarExp *)e1;
            FuncDeclaration *f = dve->var->isFuncDeclaration();

            if (f)
            {
                Expression *e;
                if ( f->needThis())
                    e = new DelegateExp(loc, dve->e1, f);
                else // It is a function pointer. Convert &v.f() --> (v, &V.f())
                    e = new CommaExp(loc, dve->e1, new AddrExp(loc, new VarExp(loc, f)));
                e = e->semantic(sc);
                return e;
            }
        }
        else if (e1->op == TOKvar)
        {
            VarExp *dve = (VarExp *)e1;
            FuncDeclaration *f = dve->var->isFuncDeclaration();

            if (f)
            {
                if (f->isNested())
                {
                    if (f->isFuncLiteralDeclaration())
                    {
                        if (!f->FuncDeclaration::isNested())
                        {   /* Supply a 'null' for a this pointer if no this is available
                             */
                            Expression *e = new DelegateExp(loc, new NullExp(loc, Type::tvoidptr), f);
                            e = e->semantic(sc);
                            return e;
                        }
                    }
                    Expression *e = new DelegateExp(loc, e1, f);
                    e = e->semantic(sc);
                    return e;
                }
            }
        }
        else if (e1->op == TOKarray)
        {
            if (e1->type->toBasetype()->ty == Tbit)
                error("cannot take address of bit in array");
        }
        return optimize(WANTvalue);
    }
    return this;
}

void AddrExp::checkEscape()
{
    e1->checkEscapeRef();
}

/************************************************************/

PtrExp::PtrExp(Loc loc, Expression *e)
        : UnaExp(loc, TOKstar, sizeof(PtrExp), e)
{
//    if (e->type)
//      type = ((TypePointer *)e->type)->next;
}

PtrExp::PtrExp(Loc loc, Expression *e, Type *t)
        : UnaExp(loc, TOKstar, sizeof(PtrExp), e)
{
    type = t;
}

Expression *PtrExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("PtrExp::semantic('%s')\n", toChars());
#endif
    if (!type)
    {
        UnaExp::semantic(sc);
        e1 = resolveProperties(sc, e1);
        if (!e1->type)
            printf("PtrExp::semantic('%s')\n", toChars());
        Type *tb = e1->type->toBasetype();
        switch (tb->ty)
        {
            case Tpointer:
                type = ((TypePointer *)tb)->next;
                break;

            case Tsarray:
            case Tarray:
                deprecation("using * on an array is deprecated; use *(%s).ptr instead", e1->toChars());
                type = ((TypeArray *)tb)->next;
                e1 = e1->castTo(sc, type->pointerTo());
                break;

            default:
                error("can only * a pointer, not a '%s'", e1->type->toChars());
            case Terror:
                return new ErrorExp();
        }
        if (!rvalue())
            return new ErrorExp();
    }
    return this;
}


int PtrExp::isLvalue()
{
    return 1;
}


void PtrExp::checkEscapeRef()
{
    e1->checkEscape();
}

Expression *PtrExp::toLvalue(Scope *sc, Expression *e)
{
#if 0
    tym = tybasic(e1->ET->Tty);
    if (!(tyscalar(tym) ||
          tym == TYstruct ||
          tym == TYarray && e->Eoper == TOKaddr))
            synerr(EM_lvalue);  // lvalue expected
#endif
    return this;
}

#if DMDV2
Expression *PtrExp::modifiableLvalue(Scope *sc, Expression *e)
{
    //printf("PtrExp::modifiableLvalue() %s, type %s\n", toChars(), type->toChars());

    if (e1->op == TOKsymoff)
    {   SymOffExp *se = (SymOffExp *)e1;
        se->var->checkModify(loc, sc, type);
        //return toLvalue(sc, e);
    }

    return Expression::modifiableLvalue(sc, e);
}
#endif

void PtrExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writeByte('*');
    expToCBuffer(buf, hgs, e1, precedence[op]);
}

/************************************************************/

NegExp::NegExp(Loc loc, Expression *e)
        : UnaExp(loc, TOKneg, sizeof(NegExp), e)
{
}

Expression *NegExp::semantic(Scope *sc)
{   Expression *e;

#if LOGSEMANTIC
    printf("NegExp::semantic('%s')\n", toChars());
#endif
    if (!type)
    {
        UnaExp::semantic(sc);
        e1 = resolveProperties(sc, e1);
        e = op_overload(sc);
        if (e)
            return e;

        e1->checkNoBool();
        if (!e1->isArrayOperand())
            e1->checkArithmetic();
        type = e1->type;
    }
    return this;
}

/************************************************************/

UAddExp::UAddExp(Loc loc, Expression *e)
        : UnaExp(loc, TOKuadd, sizeof(UAddExp), e)
{
}

Expression *UAddExp::semantic(Scope *sc)
{   Expression *e;

#if LOGSEMANTIC
    printf("UAddExp::semantic('%s')\n", toChars());
#endif
    assert(!type);
    UnaExp::semantic(sc);
    e1 = resolveProperties(sc, e1);
    e = op_overload(sc);
    if (e)
        return e;
    e1->checkNoBool();
    e1->checkArithmetic();
    return e1;
}

/************************************************************/

ComExp::ComExp(Loc loc, Expression *e)
        : UnaExp(loc, TOKtilde, sizeof(ComExp), e)
{
}

Expression *ComExp::semantic(Scope *sc)
{   Expression *e;

    if (!type)
    {
        UnaExp::semantic(sc);
        e1 = resolveProperties(sc, e1);
        e = op_overload(sc);
        if (e)
            return e;

        e1->checkNoBool();
        if (!e1->isArrayOperand())
            e1 = e1->checkIntegral();
        type = e1->type;
    }
    return this;
}

/************************************************************/

NotExp::NotExp(Loc loc, Expression *e)
        : UnaExp(loc, TOKnot, sizeof(NotExp), e)
{
}

Expression *NotExp::semantic(Scope *sc)
{
    UnaExp::semantic(sc);
    e1 = resolveProperties(sc, e1);
    e1 = e1->checkToBoolean();
    type = Type::tboolean;
    return this;
}

int NotExp::isBit()
{
    return TRUE;
}



/************************************************************/

BoolExp::BoolExp(Loc loc, Expression *e, Type *t)
        : UnaExp(loc, TOKtobool, sizeof(BoolExp), e)
{
    type = t;
}

Expression *BoolExp::semantic(Scope *sc)
{
    UnaExp::semantic(sc);
    e1 = resolveProperties(sc, e1);
    e1 = e1->checkToBoolean();
    type = Type::tboolean;
    return this;
}

int BoolExp::isBit()
{
    return TRUE;
}

/************************************************************/

DeleteExp::DeleteExp(Loc loc, Expression *e)
        : UnaExp(loc, TOKdelete, sizeof(DeleteExp), e)
{
}

Expression *DeleteExp::semantic(Scope *sc)
{
    Type *tb;

    UnaExp::semantic(sc);
    e1 = resolveProperties(sc, e1);
    e1 = e1->toLvalue(sc, NULL);
    if (e1->op == TOKerror)
        return e1;
    type = Type::tvoid;

    tb = e1->type->toBasetype();
    switch (tb->ty)
    {   case Tclass:
        {   TypeClass *tc = (TypeClass *)tb;
            ClassDeclaration *cd = tc->sym;

            if (cd->isCOMinterface())
            {   /* Because COM classes are deleted by IUnknown.Release()
                 */
                error("cannot delete instance of COM interface %s", cd->toChars());
            }
            break;
        }
        case Tpointer:
            tb = ((TypePointer *)tb)->next->toBasetype();
            if (tb->ty == Tstruct)
            {
                TypeStruct *ts = (TypeStruct *)tb;
                StructDeclaration *sd = ts->sym;
                FuncDeclaration *f = sd->aggDelete;

                if (f)
                {
                    Type *tpv = Type::tvoid->pointerTo();

                    Expression *e = e1->castTo(sc, tpv);
                    Expression *ec = new VarExp(loc, f);
                    e = new CallExp(loc, ec, e);
                    return e->semantic(sc);
                }
            }
            break;

        case Tarray:
            break;

        default:
            if (e1->op == TOKindex)
            {
                IndexExp *ae = (IndexExp *)(e1);
                Type *tb1 = ae->e1->type->toBasetype();
                if (tb1->ty == Taarray)
                    break;
            }
            error("cannot delete type %s", e1->type->toChars());
            return new ErrorExp();
    }

    if (e1->op == TOKindex)
    {
        IndexExp *ae = (IndexExp *)(e1);
        Type *tb1 = ae->e1->type->toBasetype();
        if (tb1->ty == Taarray)
            deprecation("delete aa[key] deprecated, use aa.remove(key)");
    }

    return this;
}

int DeleteExp::checkSideEffect(int flag)
{
    return 1;
}

Expression *DeleteExp::checkToBoolean()
{
    error("delete does not give a boolean result");
    return new ErrorExp();
}

void DeleteExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("delete ");
    expToCBuffer(buf, hgs, e1, precedence[op]);
}

/************************************************************/

CastExp::CastExp(Loc loc, Expression *e, Type *t)
        : UnaExp(loc, TOKcast, sizeof(CastExp), e)
{
    to = t;
}

#if DMDV2
/* For cast(const) and cast(immutable)
 */
CastExp::CastExp(Loc loc, Expression *e, unsigned mod)
        : UnaExp(loc, TOKcast, sizeof(CastExp), e)
{
    to = NULL;
    this->mod = mod;
}
#endif

Expression *CastExp::syntaxCopy()
{
    return new CastExp(loc, e1->syntaxCopy(), to->syntaxCopy());
}


Expression *CastExp::semantic(Scope *sc)
{   Expression *e;

#if LOGSEMANTIC
    printf("CastExp::semantic('%s')\n", toChars());
#endif

//static int x; assert(++x < 10);

    if (type)
        return this;
    UnaExp::semantic(sc);
    if (e1->type)               // if not a tuple
    {
        e1 = resolveProperties(sc, e1);
        to = to->semantic(loc, sc);

        e = op_overload(sc);
        if (e)
        {
            return e->implicitCastTo(sc, to);
        }

        if (e1->op == TOKtemplate)
        {
            error("cannot cast template %s to type %s", e1->toChars(), to->toChars());
            return new ErrorExp();
        }

        Type *t1b = e1->type->toBasetype();
        Type *tob = to->toBasetype();
        if (tob->ty == Tstruct &&
            !tob->equals(t1b) &&
            ((TypeStruct *)to)->sym->search(0, Id::call, 0)
           )
        {
            /* Look to replace:
             *  cast(S)t
             * with:
             *  S(t)
             */

            // Rewrite as to.call(e1)
            e = new TypeExp(loc, to);
            e = new DotIdExp(loc, e, Id::call);
            e = new CallExp(loc, e, e1);
            e = e->semantic(sc);
            return e;
        }

        // Struct casts are possible only when the sizes match
        // Same with static array -> static array
        if (tob->ty == Tstruct || t1b->ty == Tstruct ||
            (tob->ty == Tsarray && t1b->ty == Tsarray))
        {
            size_t fromsize = t1b->size(loc);
            size_t tosize = tob->size(loc);
            if (fromsize != tosize)
            {
                error("cannot cast from %s to %s", e1->type->toChars(), to->toChars());
                return new ErrorExp();
            }
        }

        if (t1b->ty == Tvoid && tob->ty != Tvoid && e1->op != TOKfunction)
        {
            error("cannot cast %s of type %s to %s", e1->toChars(), e1->type->toChars(), to->toChars());
            return new ErrorExp();
        }
    }

    if (!e1->type)
    {   error("cannot cast %s", e1->toChars());
        return new ErrorExp();
    }

    e = e1->castTo(sc, to);
    return e;
}

int CastExp::checkSideEffect(int flag)
{
    /* if not:
     *  cast(void)
     *  cast(classtype)func()
     */
    if (!to->equals(Type::tvoid) &&
        !(to->ty == Tclass && e1->op == TOKcall && e1->type->ty == Tclass))
        return Expression::checkSideEffect(flag);
    return 1;
}

void CastExp::checkEscape()
{   Type *tb = type->toBasetype();
    if (tb->ty == Tarray && e1->op == TOKvar &&
        e1->type->toBasetype()->ty == Tsarray)
    {   VarExp *ve = (VarExp *)e1;
        VarDeclaration *v = ve->var->isVarDeclaration();
        if (v)
        {
            if (!v->isDataseg() && !v->isParameter())
                error("escaping reference to local %s", v->toChars());
        }
    }
}

void CastExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("cast(");
#if DMDV1
    to->toCBuffer(buf, NULL, hgs);
#else
    if (to)
        to->toCBuffer(buf, NULL, hgs);
    else
    {
        MODtoBuffer(buf, mod);
    }
#endif
    buf->writeByte(')');
    expToCBuffer(buf, hgs, e1, precedence[op]);
}


/************************************************************/

SliceExp::SliceExp(Loc loc, Expression *e1, Expression *lwr, Expression *upr)
        : UnaExp(loc, TOKslice, sizeof(SliceExp), e1)
{
    this->upr = upr;
    this->lwr = lwr;
    lengthVar = NULL;
}

Expression *SliceExp::syntaxCopy()
{
    Expression *lwr = NULL;
    if (this->lwr)
        lwr = this->lwr->syntaxCopy();

    Expression *upr = NULL;
    if (this->upr)
        upr = this->upr->syntaxCopy();

    return new SliceExp(loc, e1->syntaxCopy(), lwr, upr);
}

Expression *SliceExp::semantic(Scope *sc)
{   Expression *e;
    AggregateDeclaration *ad;
    //FuncDeclaration *fd;
    ScopeDsymbol *sym;

#if LOGSEMANTIC
    printf("SliceExp::semantic('%s')\n", toChars());
#endif
    if (type)
        return this;

    UnaExp::semantic(sc);
    e1 = resolveProperties(sc, e1);

    e = this;

    Type *t = e1->type->toBasetype();
    if (t->ty == Tpointer)
    {
        if (!lwr || !upr)
        {   error("need upper and lower bound to slice pointer");
            return new ErrorExp();
        }
    }
    else if (t->ty == Tarray)
    {
    }
    else if (t->ty == Tsarray)
    {
    }
    else if (t->ty == Tclass)
    {
        ad = ((TypeClass *)t)->sym;
        goto L1;
    }
    else if (t->ty == Tstruct)
    {
        ad = ((TypeStruct *)t)->sym;

    L1:
        if (search_function(ad, Id::slice))
        {
            // Rewrite as e1.slice(lwr, upr)
            e = new DotIdExp(loc, e1, Id::slice);

            if (lwr)
            {
                assert(upr);
                e = new CallExp(loc, e, lwr, upr);
            }
            else
            {   assert(!upr);
                e = new CallExp(loc, e);
            }
            e = e->semantic(sc);
            return e;
        }
        goto Lerror;
    }
    else if (t->ty == Ttuple)
    {
        if (!lwr && !upr)
            return e1;
        if (!lwr || !upr)
        {   error("need upper and lower bound to slice tuple");
            goto Lerror;
        }
    }
    else if (t == Type::terror)
        goto Lerr;
    else
        goto Lerror;

    {
    Scope *sc2 = sc;
    if (t->ty == Tsarray || t->ty == Tarray || t->ty == Ttuple)
    {
        sym = new ArrayScopeSymbol(this);
        sym->loc = loc;
        sym->parent = sc->scopesym;
        sc2 = sc->push(sym);
    }

    if (lwr)
    {   lwr = lwr->semantic(sc2);
        lwr = resolveProperties(sc2, lwr);
        lwr = lwr->implicitCastTo(sc2, Type::tsize_t);
        if (lwr->type == Type::terror)
            goto Lerr;
    }
    if (upr)
    {   upr = upr->semantic(sc2);
        upr = resolveProperties(sc2, upr);
        upr = upr->implicitCastTo(sc2, Type::tsize_t);
        if (upr->type == Type::terror)
            goto Lerr;
    }

    if (sc2 != sc)
        sc2->pop();
    }

    if (t->ty == Ttuple)
    {
        lwr = lwr->ctfeInterpret();
        upr = upr->ctfeInterpret();
        uinteger_t i1 = lwr->toUInteger();
        uinteger_t i2 = upr->toUInteger();

        size_t length;
        TupleExp *te;
        TypeTuple *tup;

        if (e1->op == TOKtuple)         // slicing an expression tuple
        {   te = (TupleExp *)e1;
            length = te->exps->dim;
        }
        else if (e1->op == TOKtype)     // slicing a type tuple
        {   tup = (TypeTuple *)t;
            length = Parameter::dim(tup->arguments);
        }
        else
            assert(0);

        if (i1 <= i2 && i2 <= length)
        {   size_t j1 = (size_t) i1;
            size_t j2 = (size_t) i2;

            if (e1->op == TOKtuple)
            {   Expressions *exps = new Expressions;
                exps->setDim(j2 - j1);
                for (size_t i = 0; i < j2 - j1; i++)
                {   Expression *e = (Expression *)te->exps->data[j1 + i];
                    exps->data[i] = (void *)e;
                }
                e = new TupleExp(loc, exps);
            }
            else
            {   Parameters *args = new Parameters;
                args->reserve(j2 - j1);
                for (size_t i = j1; i < j2; i++)
                {   Parameter *arg = Parameter::getNth(tup->arguments, i);
                    args->push(arg);
                }
                e = new TypeExp(e1->loc, new TypeTuple(args));
            }
            e = e->semantic(sc);
        }
        else
        {
            error("string slice [%ju .. %ju] is out of bounds", i1, i2);
            goto Lerr;
        }
        return e;
    }

    if (t->ty == Tarray)
    {
        type = e1->type;
    }
    else
        type = t->nextOf()->arrayOf();
    return e;

Lerror:
    if (e1->op == TOKerror)
        return e1;
    char *s;
    if (t->ty == Tvoid)
        s = e1->toChars();
    else
        s = t->toChars();
    error("%s cannot be sliced with []", s);
Lerr:
    e = new ErrorExp();
    return e;
}

void SliceExp::checkEscape()
{
    e1->checkEscape();
}

void SliceExp::checkEscapeRef()
{
    e1->checkEscapeRef();
}


int SliceExp::isLvalue()
{
    return 1;
}


Expression *SliceExp::toLvalue(Scope *sc, Expression *e)
{
    return this;
}

Expression *SliceExp::modifiableLvalue(Scope *sc, Expression *e)
{
    error("slice expression %s is not a modifiable lvalue", toChars());
    return this;
}

int SliceExp::isBool(int result)
{
    return e1->isBool(result);
}

void SliceExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    expToCBuffer(buf, hgs, e1, precedence[op]);
    buf->writeByte('[');
    if (upr || lwr)
    {
        if (lwr)
            expToCBuffer(buf, hgs, lwr, PREC_assign);
        else
            buf->writeByte('0');
        buf->writestring("..");
        if (upr)
            expToCBuffer(buf, hgs, upr, PREC_assign);
        else
            buf->writestring("length");         // BUG: should be array.length
    }
    buf->writeByte(']');
}

int SliceExp::canThrow()
{
    return UnaExp::canThrow()
        || (lwr != NULL && lwr->canThrow())
        || (upr != NULL && upr->canThrow());
}

/********************** ArrayLength **************************************/

ArrayLengthExp::ArrayLengthExp(Loc loc, Expression *e1)
        : UnaExp(loc, TOKarraylength, sizeof(ArrayLengthExp), e1)
{
}

Expression *ArrayLengthExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("ArrayLengthExp::semantic('%s')\n", toChars());
#endif
    if (!type)
    {
        UnaExp::semantic(sc);
        e1 = resolveProperties(sc, e1);

        type = Type::tsize_t;
    }
    return this;
}

void ArrayLengthExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    expToCBuffer(buf, hgs, e1, PREC_primary);
    buf->writestring(".length");
}

/*********************** ArrayExp *************************************/

// e1 [ i1, i2, i3, ... ]

ArrayExp::ArrayExp(Loc loc, Expression *e1, Expressions *args)
        : UnaExp(loc, TOKarray, sizeof(ArrayExp), e1)
{
    arguments = args;
}

Expression *ArrayExp::syntaxCopy()
{
    return new ArrayExp(loc, e1->syntaxCopy(), arraySyntaxCopy(arguments));
}

Expression *ArrayExp::semantic(Scope *sc)
{   Expression *e;
    Type *t1;

#if LOGSEMANTIC
    printf("ArrayExp::semantic('%s')\n", toChars());
#endif
    UnaExp::semantic(sc);
    e1 = resolveProperties(sc, e1);
    if (e1->op == TOKerror)
        return e1;

    t1 = e1->type->toBasetype();
    if (t1->ty != Tclass && t1->ty != Tstruct)
    {   // Convert to IndexExp
        if (arguments->dim != 1)
        {   error("only one index allowed to index %s", t1->toChars());
            goto Lerr;
        }
        e = new IndexExp(loc, e1, (*arguments)[0]);
        return e->semantic(sc);
    }

    // Run semantic() on each argument
    for (size_t i = 0; i < arguments->dim; i++)
    {   e = (*arguments)[i];

        e = e->semantic(sc);
        if (!e->type)
        {   error("%s has no value", e->toChars());
            goto Lerr;
        }
        else if (e->type == Type::terror)
            goto Lerr;
        (*arguments)[i] = e;
    }

    expandTuples(arguments);
    assert(arguments && arguments->dim);

    e = op_overload(sc);
    if (!e)
    {   error("no [] operator overload for type %s", e1->type->toChars());
        goto Lerr;
    }
    return e;

Lerr:
    return new ErrorExp();
}


int ArrayExp::isLvalue()
{
    if (type && type->toBasetype()->ty == Tvoid)
        return 0;
    return 1;
}


Expression *ArrayExp::toLvalue(Scope *sc, Expression *e)
{
    if (type && type->toBasetype()->ty == Tvoid)
        error("voids have no value");
    return this;
}


void ArrayExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{   int i;

    expToCBuffer(buf, hgs, e1, PREC_primary);
    buf->writeByte('[');
    argsToCBuffer(buf, arguments, hgs);
    buf->writeByte(']');
}

/************************* DotExp ***********************************/

DotExp::DotExp(Loc loc, Expression *e1, Expression *e2)
        : BinExp(loc, TOKdotexp, sizeof(DotExp), e1, e2)
{
}

Expression *DotExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("DotExp::semantic('%s')\n", toChars());
    if (type) printf("\ttype = %s\n", type->toChars());
#endif
    e1 = e1->semantic(sc);
    e2 = e2->semantic(sc);
    if (e2->op == TOKimport)
    {
        ScopeExp *se = (ScopeExp *)e2;
        TemplateDeclaration *td = se->sds->isTemplateDeclaration();
        if (td)
        {   Expression *e = new DotTemplateExp(loc, e1, td);
            e = e->semantic(sc);
            return e;
        }
    }
    if (!type)
        type = e2->type;
    return this;
}

void DotExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    expToCBuffer(buf, hgs, e1, PREC_primary);
    buf->writeByte('.');
    expToCBuffer(buf, hgs, e2, PREC_primary);
}

/************************* CommaExp ***********************************/

CommaExp::CommaExp(Loc loc, Expression *e1, Expression *e2)
        : BinExp(loc, TOKcomma, sizeof(CommaExp), e1, e2)
{
}

Expression *CommaExp::semantic(Scope *sc)
{
    if (!type)
    {   BinExp::semanticp(sc);
        type = e2->type;
    }
    return this;
}

void CommaExp::checkEscape()
{
    e2->checkEscape();
}

void CommaExp::checkEscapeRef()
{
    e2->checkEscapeRef();
}


int CommaExp::isLvalue()
{
    return e2->isLvalue();
}


Expression *CommaExp::toLvalue(Scope *sc, Expression *e)
{
    e2 = e2->toLvalue(sc, NULL);
    return this;
}

Expression *CommaExp::modifiableLvalue(Scope *sc, Expression *e)
{
    e2 = e2->modifiableLvalue(sc, e);
    return this;
}

int CommaExp::isBool(int result)
{
    return e2->isBool(result);
}

int CommaExp::checkSideEffect(int flag)
{
    if (flag == 2)
        return e1->hasSideEffect() || e2->hasSideEffect();
    else
    {
        // Don't check e1 until we cast(void) the a,b code generation
        return e2->checkSideEffect(flag);
    }
}

/************************** IndexExp **********************************/

// e1 [ e2 ]

IndexExp::IndexExp(Loc loc, Expression *e1, Expression *e2)
        : BinExp(loc, TOKindex, sizeof(IndexExp), e1, e2)
{
    //printf("IndexExp::IndexExp('%s')\n", toChars());
    lengthVar = NULL;
    modifiable = 0;     // assume it is an rvalue
}

Expression *IndexExp::semantic(Scope *sc)
{   Expression *e;
    Type *t1;
    ScopeDsymbol *sym;

#if LOGSEMANTIC
    printf("IndexExp::semantic('%s')\n", toChars());
#endif
    if (type)
        return this;
    if (!e1->type)
        e1 = e1->semantic(sc);
    assert(e1->type);           // semantic() should already be run on it
    if (e1->op == TOKerror)
        goto Lerr;
    e = this;

    // Note that unlike C we do not implement the int[ptr]

    t1 = e1->type->toBasetype();

    if (t1->ty == Tsarray || t1->ty == Tarray || t1->ty == Ttuple)
    {   // Create scope for 'length' variable
        sym = new ArrayScopeSymbol(this);
        sym->loc = loc;
        sym->parent = sc->scopesym;
        sc = sc->push(sym);
    }

    e2 = e2->semantic(sc);
    if (!e2->type)
    {
        error("%s has no value", e2->toChars());
        goto Lerr;
    }
    if (e2->type->ty == Ttuple && ((TupleExp *)e2)->exps->dim == 1) // bug 4444 fix
        e2 = (*((TupleExp *)e2)->exps)[0];
    e2 = resolveProperties(sc, e2);
    if (e2->type == Type::terror)
        goto Lerr;

    if (t1->ty == Tsarray || t1->ty == Tarray || t1->ty == Ttuple)
        sc = sc->pop();

    switch (t1->ty)
    {
        case Tpointer:
        case Tarray:
            e2 = e2->implicitCastTo(sc, Type::tsize_t);
            e->type = t1->next;
            break;

        case Tsarray:
        {
            e2 = e2->implicitCastTo(sc, Type::tsize_t);

            TypeSArray *tsa = (TypeSArray *)t1;

#if 0   // Don't do now, because it might be short-circuit evaluated
            // Do compile time array bounds checking if possible
            e2 = e2->optimize(WANTvalue);
            if (e2->op == TOKint64)
            {
                dinteger_t index = e2->toInteger();
                dinteger_t length = tsa->dim->toInteger();
                if (index < 0 || index >= length)
                    error("array index [%lld] is outside array bounds [0 .. %lld]",
                            index, length);
            }
#endif
            e->type = t1->nextOf();
            break;
        }

        case Taarray:
        {   TypeAArray *taa = (TypeAArray *)t1;

            e2 = e2->implicitCastTo(sc, taa->index);    // type checking
            e2 = e2->implicitCastTo(sc, taa->key);      // actual argument type
            type = taa->next;
            break;
        }

        case Ttuple:
        {
            e2 = e2->implicitCastTo(sc, Type::tsize_t);
            e2 = e2->optimize(WANTvalue);
            uinteger_t index = e2->toUInteger();
            size_t length;
            TupleExp *te;
            TypeTuple *tup;

            if (e1->op == TOKtuple)
            {   te = (TupleExp *)e1;
                length = te->exps->dim;
            }
            else if (e1->op == TOKtype)
            {
                tup = (TypeTuple *)t1;
                length = Parameter::dim(tup->arguments);
            }
            else
                assert(0);

            if (index < length)
            {

                if (e1->op == TOKtuple)
                    e = (Expression *)te->exps->data[(size_t)index];
                else
                    e = new TypeExp(e1->loc, Parameter::getNth(tup->arguments, (size_t)index)->type);
            }
            else
            {
                error("array index [%ju] is outside array bounds [0 .. %zu]",
                        index, length);
                e = e1;
            }
            break;
        }

        default:
            if (e1->op == TOKerror)
                goto Lerr;
            error("%s must be an array or pointer type, not %s",
                e1->toChars(), e1->type->toChars());
        case Terror:
            goto Lerr;
    }
    return e;

Lerr:
    return new ErrorExp();
}


int IndexExp::isLvalue()
{
    return 1;
}


Expression *IndexExp::toLvalue(Scope *sc, Expression *e)
{
//    if (type && type->toBasetype()->ty == Tvoid)
//      error("voids have no value");
    return this;
}

Expression *IndexExp::modifiableLvalue(Scope *sc, Expression *e)
{
    //printf("IndexExp::modifiableLvalue(%s)\n", toChars());
    modifiable = 1;
    if (e1->op == TOKstring)
        error("string literals are immutable");
    if (e1->type->toBasetype()->ty == Taarray)
        e1 = e1->modifiableLvalue(sc, e1);
    return toLvalue(sc, e);
}

void IndexExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    expToCBuffer(buf, hgs, e1, PREC_primary);
    buf->writeByte('[');
    expToCBuffer(buf, hgs, e2, PREC_assign);
    buf->writeByte(']');
}


/************************* PostExp ***********************************/

PostExp::PostExp(enum TOK op, Loc loc, Expression *e)
        : BinExp(loc, op, sizeof(PostExp), e,
          new IntegerExp(loc, 1, Type::tint32))
{
}

Expression *PostExp::semantic(Scope *sc)
{   Expression *e = this;

    if (!type)
    {
        BinExp::semantic(sc);
        e2 = resolveProperties(sc, e2);

        e = op_overload(sc);
        if (e)
            return e;

        e = this;
        e1 = e1->modifiableLvalue(sc, e1);
        e1->checkScalar();
        e1->checkNoBool();
        if (e1->type->ty == Tpointer)
            e = scaleFactor(sc);
        else
            e2 = e2->castTo(sc, e1->type);
        e->type = e1->type;
    }
    return e;
}

void PostExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    expToCBuffer(buf, hgs, e1, precedence[op]);
    buf->writestring((op == TOKplusplus) ? (char *)"++" : (char *)"--");
}

/************************************************************/

/* op can be TOKassign, TOKconstruct, or TOKblit */

AssignExp::AssignExp(Loc loc, Expression *e1, Expression *e2)
        : BinExp(loc, TOKassign, sizeof(AssignExp), e1, e2)
{
    ismemset = 0;
}

Expression *AssignExp::semantic(Scope *sc)
{
    Expression *e1old = e1;

#if LOGSEMANTIC
    printf("AssignExp::semantic('%s')\n", toChars());
#endif
    //printf("e1->op = %d, '%s'\n", e1->op, Token::toChars(e1->op));
    //printf("e2->op = %d, '%s'\n", e2->op, Token::toChars(e2->op));

    if (type)
        return this;

    if (e2->op == TOKcomma)
    {   /* Rewrite to get rid of the comma from rvalue
         */
        AssignExp *ea = new AssignExp(loc, e1, ((CommaExp *)e2)->e2);
        ea->op = op;
        Expression *e = new CommaExp(loc, ((CommaExp *)e2)->e1, ea);
        return e->semantic(sc);
    }

    /* Look for operator overloading of a[i]=value.
     * Do it before semantic() otherwise the a[i] will have been
     * converted to a.opIndex() already.
     */
    if (e1->op == TOKarray)
    {
        ArrayExp *ae = (ArrayExp *)e1;
        AggregateDeclaration *ad = NULL;
        Identifier *id = Id::index;

        ae->e1 = ae->e1->semantic(sc);
        ae->e1 = resolveProperties(sc, ae->e1);
        Type *t1 = ae->e1->type->toBasetype();
        if (t1->ty == Tstruct)
        {
            ad = ((TypeStruct *)t1)->sym;
            goto L1;
        }
        else if (t1->ty == Tclass)
        {
            ad = ((TypeClass *)t1)->sym;
          L1:
            // Rewrite (a[i] = value) to (a.opIndexAssign(value, i))
            if (search_function(ad, Id::indexass))
            {   Expression *e = new DotIdExp(loc, ae->e1, Id::indexass);
                Expressions *a = (Expressions *)ae->arguments->copy();

                a->insert(0, e2);
                e = new CallExp(loc, e, a);
                e = e->semantic(sc);
                return e;
            }
            else
            {
                // Rewrite (a[i] = value) to (a.opIndex(i, value))
                if (search_function(ad, id))
                {   Expression *e = new DotIdExp(loc, ae->e1, id);

                    error("operator [] assignment overload with opIndex(i, value) illegal, use opIndexAssign(value, i)");
                    return new ErrorExp();
                }
            }
        }
    }
    /* Look for operator overloading of a[i..j]=value.
     * Do it before semantic() otherwise the a[i..j] will have been
     * converted to a.opSlice() already.
     */
    if (e1->op == TOKslice)
    {   Type *t1;
        SliceExp *ae = (SliceExp *)e1;
        AggregateDeclaration *ad = NULL;
        Identifier *id = Id::index;

        ae->e1 = ae->e1->semantic(sc);
        ae->e1 = resolveProperties(sc, ae->e1);
        t1 = ae->e1->type->toBasetype();
        if (t1->ty == Tstruct)
        {
            ad = ((TypeStruct *)t1)->sym;
            goto L2;
        }
        else if (t1->ty == Tclass)
        {
            ad = ((TypeClass *)t1)->sym;
          L2:
            // Rewrite (a[i..j] = value) to (a.opIndexAssign(value, i, j))
            if (search_function(ad, Id::sliceass))
            {   Expression *e = new DotIdExp(loc, ae->e1, Id::sliceass);
                Expressions *a = new Expressions();

                a->push(e2);
                if (ae->lwr)
                {   a->push(ae->lwr);
                    assert(ae->upr);
                    a->push(ae->upr);
                }
                else
                    assert(!ae->upr);
                e = new CallExp(loc, e, a);
                e = e->semantic(sc);
                return e;
            }
        }
    }

    Expression *e = BinExp::semantic(sc);
    if (e->op == TOKerror)
        return e;

    if (e1->op == TOKdottd)
    {   // Rewrite a.b=e2, when b is a template, as a.b(e2)
        Expression *e = new CallExp(loc, e1, e2);
        e = e->semantic(sc);
        return e;
    }

    if (e1->op == TOKvar)
    {
        VarDeclaration *vd = ((VarExp *)e1)->var->isVarDeclaration();
        if (vd && vd->needThis())
        {
            error("need 'this' to access member %s", e1->toChars());
            return new ErrorExp();
        }
    }

    e2 = resolveProperties(sc, e2);
    assert(e1->type);

    /* Rewrite tuple assignment as a tuple of assignments.
     */
    if (e1->op == TOKtuple && e2->op == TOKtuple)
    {   TupleExp *tup1 = (TupleExp *)e1;
        TupleExp *tup2 = (TupleExp *)e2;
        size_t dim = tup1->exps->dim;
        if (dim != tup2->exps->dim)
        {
            error("mismatched tuple lengths, %d and %d", (int)dim, (int)tup2->exps->dim);
        }
        else
        {   Expressions *exps = new Expressions;
            exps->setDim(dim);

            for (size_t i = 0; i < dim; i++)
            {   Expression *ex1 = (Expression *)tup1->exps->data[i];
                Expression *ex2 = (Expression *)tup2->exps->data[i];
                exps->data[i] = (void *) new AssignExp(loc, ex1, ex2);
            }
            Expression *e = new TupleExp(loc, exps);
            e = e->semantic(sc);
            return e;
        }
    }

    // Determine if this is an initialization of a reference
    int refinit = 0;
    if (op == TOKconstruct && e1->op == TOKvar)
    {   VarExp *ve = (VarExp *)e1;
        VarDeclaration *v = ve->var->isVarDeclaration();
        if (v->storage_class & (STCout | STCref))
            refinit = 1;
    }

    Type *t1 = e1->type->toBasetype();

    if (t1->ty == Tfunction)
    {   // Rewrite f=value to f(value)
        Expression *e = new CallExp(loc, e1, e2);
        e = e->semantic(sc);
        return e;
    }

    /* If it is an assignment from a 'foreign' type,
     * check for operator overloading.
     */
    if (t1->ty == Tclass || t1->ty == Tstruct)
    {   // Disallow assignment operator overloads for same type
        if (/*op == TOKassign &&*/      // construction shouldn't be allowed, but OK to avoid breaking existing code
            !e2->implicitConvTo(e1->type))
        {
            Expression *e = op_overload(sc);
            if (e)
                return e;
        }
    }

    if (!e2->rvalue())
        return new ErrorExp();

    if (e1->op == TOKarraylength)
    {
        // e1 is not an lvalue, but we let code generator handle it
        ArrayLengthExp *ale = (ArrayLengthExp *)e1;

        ale->e1 = ale->e1->modifiableLvalue(sc, e1);
    }
    else if (e1->op == TOKslice)
        ;
    else
    {   // Try to do a decent error message with the expression
        // before it got constant folded
        if (op != TOKconstruct)
            e1 = e1->modifiableLvalue(sc, e1old);
    }

    // If it is a array, get the element type. Note that it may be
    // multi-dimensional.
    Type *telem = t1;
    while (telem->ty == Tarray)
        telem = telem->nextOf();

    // Check for block assignment. If it is of type void[], void[][], etc,
    // '= null' is the only allowable block assignment (Bug 7493)
    if (e1->op == TOKslice &&
        t1->nextOf() && (telem->ty != Tvoid || e2->op == TOKnull) &&
        e2->implicitConvTo(t1->nextOf())
//      !(t1->nextOf()->equals(e2->type->nextOf()))
       )
    {   // memset
        ismemset = 1;   // make it easy for back end to tell what this is
        e2 = e2->implicitCastTo(sc, t1->next);
    }
    else if (t1->ty == Tsarray && !refinit)
    {
        error("cannot assign to static array %s", e1->toChars());
    }
    else
    {
        e2 = e2->implicitCastTo(sc, e1->type);
    }

    /* Look for array operations
     */
    if (e1->op == TOKslice && !ismemset &&
        (e2->op == TOKadd || e2->op == TOKmin ||
         e2->op == TOKmul || e2->op == TOKdiv ||
         e2->op == TOKmod || e2->op == TOKxor ||
         e2->op == TOKand || e2->op == TOKor  ||
#if DMDV2
         e2->op == TOKpow ||
#endif
         e2->op == TOKtilde || e2->op == TOKneg))
    {
        type = e1->type;
        return arrayOp(sc);
    }

    if (e1->op == TOKvar &&
        (((VarExp *)e1)->var->storage_class & STCscope) &&
        op == TOKassign)
    {
        error("cannot rebind scope variables");
    }

    type = e1->type;
    assert(type);
    return this;
}

Expression *AssignExp::checkToBoolean()
{
    // Things like:
    //  if (a = b) ...
    // are usually mistakes.

    error("assignment cannot be used as a condition, perhaps == was meant?");
    return new ErrorExp();
}

/************************************************************/

ConstructExp::ConstructExp(Loc loc, Expression *e1, Expression *e2)
    : AssignExp(loc, e1, e2)
{
    op = TOKconstruct;
}

/************************************************************/

AddAssignExp::AddAssignExp(Loc loc, Expression *e1, Expression *e2)
        : BinAssignExp(loc, TOKaddass, sizeof(AddAssignExp), e1, e2)
{
}

Expression *AddAssignExp::semantic(Scope *sc)
{   Expression *e;

    if (type)
        return this;

    BinExp::semantic(sc);
    e2 = resolveProperties(sc, e2);

    e = op_overload(sc);
    if (e)
        return e;

    Type *tb1 = e1->type->toBasetype();
    Type *tb2 = e2->type->toBasetype();

    if (e1->op == TOKslice)
    {
        e = typeCombine(sc);
        if (e->op == TOKerror)
            return e;
        type = e1->type;
        return arrayOp(sc);
    }
    else
    {
        e1 = e1->modifiableLvalue(sc, e1);
    }

    if ((tb1->ty == Tarray || tb1->ty == Tsarray) &&
        (tb2->ty == Tarray || tb2->ty == Tsarray) &&
        tb1->nextOf()->equals(tb2->nextOf())
       )
    {
        type = e1->type;
        e = this;
    }
    else
    {
        e1->checkScalar();
        e1->checkNoBool();
        if (tb1->ty == Tpointer && tb2->isintegral())
            e = scaleFactor(sc);
        else if (tb1->ty == Tbit || tb1->ty == Tbool)
        {
#if 0
            // Need to rethink this
            if (e1->op != TOKvar)
            {   // Rewrite e1+=e2 to (v=&e1),*v=*v+e2
                VarDeclaration *v;
                Expression *ea;
                Expression *ex;

                Identifier *id = Lexer::uniqueId("__name");

                v = new VarDeclaration(loc, tb1->pointerTo(), id, NULL);
                v->semantic(sc);
                if (!sc->insert(v))
                    assert(0);
                v->parent = sc->func;

                ea = new AddrExp(loc, e1);
                ea = new AssignExp(loc, new VarExp(loc, v), ea);

                ex = new VarExp(loc, v);
                ex = new PtrExp(loc, ex);
                e = new AddExp(loc, ex, e2);
                e = new CastExp(loc, e, e1->type);
                e = new AssignExp(loc, ex->syntaxCopy(), e);

                e = new CommaExp(loc, ea, e);
            }
            else
#endif
            {   // Rewrite e1+=e2 to e1=e1+e2
                // BUG: doesn't account for side effects in e1
                // BUG: other assignment operators for bits aren't handled at all
                e = new AddExp(loc, e1, e2);
                e = new CastExp(loc, e, e1->type);
                e = new AssignExp(loc, e1->syntaxCopy(), e);
            }
            e = e->semantic(sc);
        }
        else
        {
            type = e1->type;
            typeCombine(sc);
            e1->checkArithmetic();
            e2->checkArithmetic();
            checkComplexAddAssign();
            if (type->isreal() || type->isimaginary())
            {
                assert(global.errors || e2->type->isfloating());
                e2 = e2->castTo(sc, e1->type);
            }
            e = this;
        }
    }
    return e;
}

/************************************************************/

MinAssignExp::MinAssignExp(Loc loc, Expression *e1, Expression *e2)
        : BinAssignExp(loc, TOKminass, sizeof(MinAssignExp), e1, e2)
{
}

Expression *MinAssignExp::semantic(Scope *sc)
{   Expression *e;

    if (type)
        return this;

    BinExp::semantic(sc);
    e2 = resolveProperties(sc, e2);

    e = op_overload(sc);
    if (e)
        return e;

    if (e1->op == TOKslice)
    {   // T[] -= ...
        e = typeCombine(sc);
        if (e->op == TOKerror)
            return e;
        type = e1->type;
        return arrayOp(sc);
    }

    e1 = e1->modifiableLvalue(sc, e1);
    e1->checkScalar();
    e1->checkNoBool();
    if (e1->type->ty == Tpointer && e2->type->isintegral())
        e = scaleFactor(sc);
    else
    {
        e1 = e1->checkArithmetic();
        e2 = e2->checkArithmetic();
        checkComplexAddAssign();
        type = e1->type;
        typeCombine(sc);
        if (type->isreal() || type->isimaginary())
        {
            assert(e2->type->isfloating());
            e2 = e2->castTo(sc, e1->type);
        }
        e = this;
    }
    return e;
}

/************************************************************/

CatAssignExp::CatAssignExp(Loc loc, Expression *e1, Expression *e2)
        : BinAssignExp(loc, TOKcatass, sizeof(CatAssignExp), e1, e2)
{
}

Expression *CatAssignExp::semantic(Scope *sc)
{   Expression *e;

    BinExp::semantic(sc);
    e2 = resolveProperties(sc, e2);

    e = op_overload(sc);
    if (e)
        return e;

    if (e1->op == TOKslice)
    {   SliceExp *se = (SliceExp *)e1;

        if (se->e1->type->toBasetype()->ty == Tsarray)
        {   error("cannot append to static array %s", se->e1->type->toChars());
            return new ErrorExp();
        }
    }

    e1 = e1->modifiableLvalue(sc, e1);
    if (e1->op == TOKerror)
        return e1;

    Type *tb1 = e1->type->toBasetype();
    Type *tb2 = e2->type->toBasetype();

    if (!e2->rvalue())
        return new ErrorExp();

    Type *tb1next = tb1->nextOf();

    if ((tb1->ty == Tarray) &&
        (tb2->ty == Tarray || tb2->ty == Tsarray) &&
        (e2->implicitConvTo(e1->type)
#if DMDV2
         || tb2->nextOf()->implicitConvTo(tb1next)
#endif
        )
       )
    {   // Append array
        e2 = e2->castTo(sc, e1->type);
        type = e1->type;
        e = this;
    }
    else if (tb1->ty == Tarray &&
        (tb1next->ty == Tchar || tb1next->ty == Twchar) &&
        e2->type->ty != tb1next->ty &&
        e2->implicitConvTo(Type::tdchar)
       )
    {   // Append dchar to char[] or wchar[]
        e2 = e2->castTo(sc, Type::tdchar);
        type = e1->type;
        e = this;

        /* Do not allow appending wchar to char[] because if wchar happens
         * to be a surrogate pair, nothing good can result.
         */
    }
    else if ((tb1->ty == Tarray) &&
        e2->implicitConvTo(tb1next)
       )
    {   // Append element
        e2 = e2->castTo(sc, tb1next);
        type = e1->type;
        e = this;
    }
    else
    {
        if (tb1 != Type::terror && tb2 != Type::terror)
            error("cannot append type %s to type %s", tb2->toChars(), tb1->toChars());
        e = new ErrorExp();
    }
    return e;
}

/************************************************************/

MulAssignExp::MulAssignExp(Loc loc, Expression *e1, Expression *e2)
        : BinAssignExp(loc, TOKmulass, sizeof(MulAssignExp), e1, e2)
{
}

Expression *MulAssignExp::semantic(Scope *sc)
{   Expression *e;

    if (type)
        return this;
    BinExp::semantic(sc);
    e2 = resolveProperties(sc, e2);

    e = op_overload(sc);
    if (e)
        return e;

#if DMDV2
    if (e1->op == TOKarraylength)
    {
        e = ArrayLengthExp::rewriteOpAssign(this);
        e = e->semantic(sc);
        return e;
    }
#endif

    if (e1->op == TOKslice)
    {   // T[] -= ...
        e = typeCombine(sc);
        if (e->op == TOKerror)
            return e;
        type = e1->type;
        return arrayOp(sc);
    }

    e1 = e1->modifiableLvalue(sc, e1);
    e1->checkScalar();
    e1->checkNoBool();
    type = e1->type;
    typeCombine(sc);
    e1->checkArithmetic();
    e2->checkArithmetic();
    checkComplexMulAssign();
    if (e2->type->isfloating())
    {   Type *t1;
        Type *t2;

        t1 = e1->type;
        t2 = e2->type;
        if (t1->isreal())
        {
            if (t2->isimaginary() || t2->iscomplex())
            {
                e2 = e2->castTo(sc, t1);
            }
        }
        else if (t1->isimaginary())
        {
            if (t2->isimaginary() || t2->iscomplex())
            {
                switch (t1->ty)
                {
                    case Timaginary32: t2 = Type::tfloat32; break;
                    case Timaginary64: t2 = Type::tfloat64; break;
                    case Timaginary80: t2 = Type::tfloat80; break;
                    default:
                        assert(0);
                }
                e2 = e2->castTo(sc, t2);
            }
        }
    }
    return this;
}

/************************************************************/

DivAssignExp::DivAssignExp(Loc loc, Expression *e1, Expression *e2)
        : BinAssignExp(loc, TOKdivass, sizeof(DivAssignExp), e1, e2)
{
}

Expression *DivAssignExp::semantic(Scope *sc)
{   Expression *e;

    if (type)
        return this;
    BinExp::semantic(sc);
    e2 = resolveProperties(sc, e2);

    e = op_overload(sc);
    if (e)
        return e;

#if DMDV2
    if (e1->op == TOKarraylength)
    {
        e = ArrayLengthExp::rewriteOpAssign(this);
        e = e->semantic(sc);
        return e;
    }
#endif

    if (e1->op == TOKslice)
    {   // T[] -= ...
        e = typeCombine(sc);
        if (e->op == TOKerror)
            return e;
        type = e1->type;
        return arrayOp(sc);
    }

    e1 = e1->modifiableLvalue(sc, e1);
    e1->checkScalar();
    e1->checkNoBool();
    type = e1->type;
    typeCombine(sc);
    e1->checkArithmetic();
    e2->checkArithmetic();
    checkComplexMulAssign();
    if (e2->type->isimaginary())
    {   Type *t1;
        Type *t2;

        t1 = e1->type;
        if (t1->isreal())
        {   // x/iv = i(-x/v)
            // Therefore, the result is 0
            e2 = new CommaExp(loc, e2, new RealExp(loc, 0, t1));
            e2->type = t1;
            e = new AssignExp(loc, e1, e2);
            e->type = t1;
            return e;
        }
        else if (t1->isimaginary())
        {   Expression *e;

            switch (t1->ty)
            {
                case Timaginary32: t2 = Type::tfloat32; break;
                case Timaginary64: t2 = Type::tfloat64; break;
                case Timaginary80: t2 = Type::tfloat80; break;
                default:
                    assert(0);
            }
            e2 = e2->castTo(sc, t2);
            e = new AssignExp(loc, e1, e2);
            e->type = t1;
            return e;
        }
    }
    return this;
}

/************************************************************/

ModAssignExp::ModAssignExp(Loc loc, Expression *e1, Expression *e2)
        : BinAssignExp(loc, TOKmodass, sizeof(ModAssignExp), e1, e2)
{
}

Expression *ModAssignExp::semantic(Scope *sc)
{
    if (type)
        return this;
    BinExp::semantic(sc);
    checkComplexMulAssign();
    return commonSemanticAssign(sc);
}

/************************************************************/

ShlAssignExp::ShlAssignExp(Loc loc, Expression *e1, Expression *e2)
        : BinAssignExp(loc, TOKshlass, sizeof(ShlAssignExp), e1, e2)
{
}

/************************************************************/

ShrAssignExp::ShrAssignExp(Loc loc, Expression *e1, Expression *e2)
        : BinAssignExp(loc, TOKshrass, sizeof(ShrAssignExp), e1, e2)
{
}

/************************************************************/

UshrAssignExp::UshrAssignExp(Loc loc, Expression *e1, Expression *e2)
        : BinAssignExp(loc, TOKushrass, sizeof(UshrAssignExp), e1, e2)
{
}

/************************************************************/

AndAssignExp::AndAssignExp(Loc loc, Expression *e1, Expression *e2)
        : BinAssignExp(loc, TOKandass, sizeof(AndAssignExp), e1, e2)
{
}

Expression *AndAssignExp::semantic(Scope *sc)
{
    return commonSemanticAssignIntegral(sc);
}

/************************************************************/

OrAssignExp::OrAssignExp(Loc loc, Expression *e1, Expression *e2)
        : BinAssignExp(loc, TOKorass, sizeof(OrAssignExp), e1, e2)
{
}

Expression *OrAssignExp::semantic(Scope *sc)
{
    return commonSemanticAssignIntegral(sc);
}

/************************************************************/

XorAssignExp::XorAssignExp(Loc loc, Expression *e1, Expression *e2)
        : BinAssignExp(loc, TOKxorass, sizeof(XorAssignExp), e1, e2)
{
}

Expression *XorAssignExp::semantic(Scope *sc)
{
    return commonSemanticAssignIntegral(sc);
}

/************************* AddExp *****************************/

AddExp::AddExp(Loc loc, Expression *e1, Expression *e2)
        : BinExp(loc, TOKadd, sizeof(AddExp), e1, e2)
{
}

Expression *AddExp::semantic(Scope *sc)
{   Expression *e;

#if LOGSEMANTIC
    printf("AddExp::semantic('%s')\n", toChars());
#endif
    if (!type)
    {
        BinExp::semanticp(sc);

        e = op_overload(sc);
        if (e)
            return e;

        Type *tb1 = e1->type->toBasetype();
        Type *tb2 = e2->type->toBasetype();

        if ((tb1->ty == Tarray || tb1->ty == Tsarray) &&
            (tb2->ty == Tarray || tb2->ty == Tsarray) &&
            tb1->nextOf()->equals(tb2->nextOf())
           )
        {
            type = e1->type;
            e = this;
        }
        else if (tb1->ty == Tpointer && e2->type->isintegral() ||
            tb2->ty == Tpointer && e1->type->isintegral())
            e = scaleFactor(sc);
        else if (tb1->ty == Tpointer && tb2->ty == Tpointer)
        {
            incompatibleTypes();
            type = e1->type;
            e = this;
        }
        else
        {
            typeCombine(sc);
            if ((e1->type->isreal() && e2->type->isimaginary()) ||
                (e1->type->isimaginary() && e2->type->isreal()))
            {
                switch (type->toBasetype()->ty)
                {
                    case Tfloat32:
                    case Timaginary32:
                        type = Type::tcomplex32;
                        break;

                    case Tfloat64:
                    case Timaginary64:
                        type = Type::tcomplex64;
                        break;

                    case Tfloat80:
                    case Timaginary80:
                        type = Type::tcomplex80;
                        break;

                    default:
                        assert(0);
                }
            }
            e = this;
        }
        return e;
    }
    return this;
}

/************************************************************/

MinExp::MinExp(Loc loc, Expression *e1, Expression *e2)
        : BinExp(loc, TOKmin, sizeof(MinExp), e1, e2)
{
}

Expression *MinExp::semantic(Scope *sc)
{   Expression *e;
    Type *t1;
    Type *t2;

#if LOGSEMANTIC
    printf("MinExp::semantic('%s')\n", toChars());
#endif
    if (type)
        return this;

    BinExp::semanticp(sc);

    e = op_overload(sc);
    if (e)
        return e;

    e = this;
    t1 = e1->type->toBasetype();
    t2 = e2->type->toBasetype();
    if (t1->ty == Tpointer)
    {
        if (t2->ty == Tpointer)
        {   // Need to divide the result by the stride
            // Replace (ptr - ptr) with (ptr - ptr) / stride
            d_int64 stride;
            Expression *e;

            typeCombine(sc);            // make sure pointer types are compatible
            type = Type::tptrdiff_t;
            stride = t2->nextOf()->size();
            if (stride == 0)
            {
                e = new IntegerExp(loc, 0, Type::tptrdiff_t);
            }
            else
            {
                e = new DivExp(loc, this, new IntegerExp(0, stride, Type::tptrdiff_t));
                e->type = Type::tptrdiff_t;
            }
            return e;
        }
        else if (t2->isintegral())
            e = scaleFactor(sc);
        else
        {   error("can't subtract %s from pointer", t2->toChars());
            return new ErrorExp();
        }
    }
    else if (t2->ty == Tpointer)
    {
        type = e2->type;
        error("can't subtract pointer from %s", e1->type->toChars());
        return new ErrorExp();
    }
    else
    {
        typeCombine(sc);
        t1 = e1->type->toBasetype();
        t2 = e2->type->toBasetype();
        if ((t1->isreal() && t2->isimaginary()) ||
            (t1->isimaginary() && t2->isreal()))
        {
            switch (type->ty)
            {
                case Tfloat32:
                case Timaginary32:
                    type = Type::tcomplex32;
                    break;

                case Tfloat64:
                case Timaginary64:
                    type = Type::tcomplex64;
                    break;

                case Tfloat80:
                case Timaginary80:
                    type = Type::tcomplex80;
                    break;

                default:
                    assert(0);
            }
        }
    }
    return e;
}

/************************* CatExp *****************************/

CatExp::CatExp(Loc loc, Expression *e1, Expression *e2)
        : BinExp(loc, TOKcat, sizeof(CatExp), e1, e2)
{
}

Expression *CatExp::semantic(Scope *sc)
{   Expression *e;

    //printf("CatExp::semantic() %s\n", toChars());
    if (!type)
    {
        BinExp::semanticp(sc);
        e = op_overload(sc);
        if (e)
            return e;

        Type *tb1 = e1->type->toBasetype();
        Type *tb2 = e2->type->toBasetype();


        /* BUG: Should handle things like:
         *      char c;
         *      c ~ ' '
         *      ' ' ~ c;
         */

#if 0
        e1->type->print();
        e2->type->print();
#endif
        if ((tb1->ty == Tsarray || tb1->ty == Tarray) &&
            e2->type->equals(tb1->next))
        {
            type = tb1->nextOf()->arrayOf();
            if (tb2->ty == Tarray)
            {   // Make e2 into [e2]
                e2 = new ArrayLiteralExp(e2->loc, e2);
                e2->type = type;
            }
            return this;
        }
        else if ((tb2->ty == Tsarray || tb2->ty == Tarray) &&
            e1->type->equals(tb2->next))
        {
            type = tb2->nextOf()->arrayOf();
            if (tb1->ty == Tarray)
            {   // Make e1 into [e1]
                e1 = new ArrayLiteralExp(e1->loc, e1);
                e1->type = type;
            }
            return this;
        }

        typeCombine(sc);

        if (type->toBasetype()->ty == Tsarray)
            type = type->toBasetype()->next->arrayOf();
#if 0
        e1->type->print();
        e2->type->print();
        type->print();
        print();
#endif
        if (e1->op == TOKstring && e2->op == TOKstring)
            e = optimize(WANTvalue);
        else if (e1->type->equals(e2->type) &&
                (e1->type->toBasetype()->ty == Tarray ||
                 e1->type->toBasetype()->ty == Tsarray))
        {
            e = this;
        }
        else
        {
            //printf("(%s) ~ (%s)\n", e1->toChars(), e2->toChars());
            error("Can only concatenate arrays, not (%s ~ %s)",
                e1->type->toChars(), e2->type->toChars());
            type = Type::tint32;
            e = this;
        }
        e->type = e->type->semantic(loc, sc);
        return e;
    }
    return this;
}

/************************************************************/

MulExp::MulExp(Loc loc, Expression *e1, Expression *e2)
        : BinExp(loc, TOKmul, sizeof(MulExp), e1, e2)
{
}

Expression *MulExp::semantic(Scope *sc)
{   Expression *e;

#if 0
    printf("MulExp::semantic() %s\n", toChars());
#endif
    if (type)
    {
        return this;
    }

    BinExp::semanticp(sc);
    e = op_overload(sc);
    if (e)
        return e;

    typeCombine(sc);
    if (!e1->isArrayOperand())
        e1->checkArithmetic();
    if (!e2->isArrayOperand())
        e2->checkArithmetic();
    if (type->isfloating())
    {   Type *t1 = e1->type;
        Type *t2 = e2->type;

        if (t1->isreal())
        {
            type = t2;
        }
        else if (t2->isreal())
        {
            type = t1;
        }
        else if (t1->isimaginary())
        {
            if (t2->isimaginary())
            {   Expression *e;

                switch (t1->toBasetype()->ty)
                {
                    case Timaginary32:  type = Type::tfloat32;  break;
                    case Timaginary64:  type = Type::tfloat64;  break;
                    case Timaginary80:  type = Type::tfloat80;  break;
                    default:            assert(0);
                }

                // iy * iv = -yv
                e1->type = type;
                e2->type = type;
                e = new NegExp(loc, this);
                e = e->semantic(sc);
                return e;
            }
            else
                type = t2;      // t2 is complex
        }
        else if (t2->isimaginary())
        {
            type = t1;  // t1 is complex
        }
    }
    return this;
}

/************************************************************/

DivExp::DivExp(Loc loc, Expression *e1, Expression *e2)
        : BinExp(loc, TOKdiv, sizeof(DivExp), e1, e2)
{
}

Expression *DivExp::semantic(Scope *sc)
{   Expression *e;

    if (type)
        return this;

    BinExp::semanticp(sc);
    e = op_overload(sc);
    if (e)
        return e;

    typeCombine(sc);
    if (!e1->isArrayOperand())
        e1->checkArithmetic();
    if (!e2->isArrayOperand())
        e2->checkArithmetic();
    if (type->isfloating())
    {   Type *t1 = e1->type;
        Type *t2 = e2->type;

        if (t1->isreal())
        {
            type = t2;
            if (t2->isimaginary())
            {   Expression *e;

                // x/iv = i(-x/v)
                e2->type = t1;
                e = new NegExp(loc, this);
                e = e->semantic(sc);
                return e;
            }
        }
        else if (t2->isreal())
        {
            type = t1;
        }
        else if (t1->isimaginary())
        {
            if (t2->isimaginary())
            {
                switch (t1->toBasetype()->ty)
                {
                    case Timaginary32:  type = Type::tfloat32;  break;
                    case Timaginary64:  type = Type::tfloat64;  break;
                    case Timaginary80:  type = Type::tfloat80;  break;
                    default:            assert(0);
                }
            }
            else
                type = t2;      // t2 is complex
        }
        else if (t2->isimaginary())
        {
            type = t1;  // t1 is complex
        }
    }
    return this;
}

/************************************************************/

ModExp::ModExp(Loc loc, Expression *e1, Expression *e2)
        : BinExp(loc, TOKmod, sizeof(ModExp), e1, e2)
{
}

Expression *ModExp::semantic(Scope *sc)
{   Expression *e;

    if (type)
        return this;

    BinExp::semanticp(sc);
    e = op_overload(sc);
    if (e)
        return e;

    typeCombine(sc);
    if (!e1->isArrayOperand())
        e1->checkArithmetic();
    if (!e2->isArrayOperand())
        e2->checkArithmetic();
    if (type->isfloating())
    {   type = e1->type;
        if (e2->type->iscomplex())
        {   error("cannot perform modulo complex arithmetic");
            return new IntegerExp(0);
        }
    }
    return this;
}

/************************************************************/

ShlExp::ShlExp(Loc loc, Expression *e1, Expression *e2)
        : BinExp(loc, TOKshl, sizeof(ShlExp), e1, e2)
{
}

Expression *ShlExp::semantic(Scope *sc)
{   Expression *e;

    //printf("ShlExp::semantic(), type = %p\n", type);
    if (!type)
    {   BinExp::semanticp(sc);
        e = op_overload(sc);
        if (e)
            return e;
        e1 = e1->checkIntegral();
        e2 = e2->checkIntegral();
        e1 = e1->integralPromotions(sc);
        e2 = e2->castTo(sc, Type::tshiftcnt);
        type = e1->type;
    }
    return this;
}

/************************************************************/

ShrExp::ShrExp(Loc loc, Expression *e1, Expression *e2)
        : BinExp(loc, TOKshr, sizeof(ShrExp), e1, e2)
{
}

Expression *ShrExp::semantic(Scope *sc)
{   Expression *e;

    if (!type)
    {   BinExp::semanticp(sc);
        e = op_overload(sc);
        if (e)
            return e;
        e1 = e1->checkIntegral();
        e2 = e2->checkIntegral();
        e1 = e1->integralPromotions(sc);
        e2 = e2->castTo(sc, Type::tshiftcnt);
        type = e1->type;
    }
    return this;
}

/************************************************************/

UshrExp::UshrExp(Loc loc, Expression *e1, Expression *e2)
        : BinExp(loc, TOKushr, sizeof(UshrExp), e1, e2)
{
}

Expression *UshrExp::semantic(Scope *sc)
{   Expression *e;

    if (!type)
    {   BinExp::semanticp(sc);
        e = op_overload(sc);
        if (e)
            return e;
        e1 = e1->checkIntegral();
        e2 = e2->checkIntegral();
        e1 = e1->integralPromotions(sc);
        e2 = e2->castTo(sc, Type::tshiftcnt);
        type = e1->type;
    }
    return this;
}

/************************************************************/

AndExp::AndExp(Loc loc, Expression *e1, Expression *e2)
        : BinExp(loc, TOKand, sizeof(AndExp), e1, e2)
{
}

Expression *AndExp::semantic(Scope *sc)
{   Expression *e;

    if (!type)
    {   BinExp::semanticp(sc);
        e = op_overload(sc);
        if (e)
            return e;
        if (e1->type->toBasetype()->ty == Tbool &&
            e2->type->toBasetype()->ty == Tbool)
        {
            type = e1->type;
            e = this;
        }
        else
        {
            typeCombine(sc);
            if (!e1->isArrayOperand())
                e1->checkIntegral();
            if (!e2->isArrayOperand())
                e2->checkIntegral();
        }
    }
    return this;
}

/************************************************************/

OrExp::OrExp(Loc loc, Expression *e1, Expression *e2)
        : BinExp(loc, TOKor, sizeof(OrExp), e1, e2)
{
}

Expression *OrExp::semantic(Scope *sc)
{   Expression *e;

    if (!type)
    {   BinExp::semanticp(sc);
        e = op_overload(sc);
        if (e)
            return e;
        if (e1->type->toBasetype()->ty == Tbool &&
            e2->type->toBasetype()->ty == Tbool)
        {
            type = e1->type;
            e = this;
        }
        else
        {
            typeCombine(sc);
            if (!e1->isArrayOperand())
                e1->checkIntegral();
            if (!e2->isArrayOperand())
                e2->checkIntegral();
        }
    }
    return this;
}

/************************************************************/

XorExp::XorExp(Loc loc, Expression *e1, Expression *e2)
        : BinExp(loc, TOKxor, sizeof(XorExp), e1, e2)
{
}

Expression *XorExp::semantic(Scope *sc)
{   Expression *e;

    if (!type)
    {   BinExp::semanticp(sc);
        e = op_overload(sc);
        if (e)
            return e;
        if (e1->type->toBasetype()->ty == Tbool &&
            e2->type->toBasetype()->ty == Tbool)
        {
            type = e1->type;
            e = this;
        }
        else
        {
            typeCombine(sc);
            if (!e1->isArrayOperand())
                e1->checkIntegral();
            if (!e2->isArrayOperand())
                e2->checkIntegral();
        }
    }
    return this;
}


/************************************************************/

OrOrExp::OrOrExp(Loc loc, Expression *e1, Expression *e2)
        : BinExp(loc, TOKoror, sizeof(OrOrExp), e1, e2)
{
}

Expression *OrOrExp::semantic(Scope *sc)
{
    unsigned cs1;

    // same as for AndAnd
    e1 = e1->semantic(sc);
    e1 = resolveProperties(sc, e1);
    e1 = e1->checkToPointer();
    e1 = e1->checkToBoolean();
    cs1 = sc->callSuper;

    if (sc->flags & SCOPEstaticif)
    {
        /* If in static if, don't evaluate e2 if we don't have to.
         */
        e1 = e1->optimize(WANTflags);
        if (e1->isBool(TRUE))
        {
            return new IntegerExp(loc, 1, Type::tboolean);
        }
    }

    e2 = e2->semantic(sc);
    sc->mergeCallSuper(loc, cs1);
    e2 = resolveProperties(sc, e2);
    e2 = e2->checkToPointer();

    if (e2->type->ty == Tvoid)
        type = Type::tvoid;
    else
    {
        e2 = e2->checkToBoolean();
        type = Type::tboolean;
    }
    if (e2->op == TOKtype || e2->op == TOKimport)
    {   error("%s is not an expression", e2->toChars());
        return new ErrorExp();
    }
    if (e1->op == TOKerror)
        return e1;
    if (e2->op == TOKerror)
        return e2;
    return this;
}

Expression *OrOrExp::checkToBoolean()
{
    e2 = e2->checkToBoolean();
    return this;
}

int OrOrExp::isBit()
{
    return TRUE;
}

int OrOrExp::checkSideEffect(int flag)
{
    if (flag == 2)
    {
        return e1->hasSideEffect() || e2->hasSideEffect();
    }
    else
    {   e1->checkSideEffect(1);
        return e2->checkSideEffect(flag);
    }
}

/************************************************************/

AndAndExp::AndAndExp(Loc loc, Expression *e1, Expression *e2)
        : BinExp(loc, TOKandand, sizeof(AndAndExp), e1, e2)
{
}

Expression *AndAndExp::semantic(Scope *sc)
{
    unsigned cs1;

    // same as for OrOr
    e1 = e1->semantic(sc);
    e1 = resolveProperties(sc, e1);
    e1 = e1->checkToPointer();
    e1 = e1->checkToBoolean();
    cs1 = sc->callSuper;

    if (sc->flags & SCOPEstaticif)
    {
        /* If in static if, don't evaluate e2 if we don't have to.
         */
        e1 = e1->optimize(WANTflags);
        if (e1->isBool(FALSE))
        {
            return new IntegerExp(loc, 0, Type::tboolean);
        }
    }

    e2 = e2->semantic(sc);
    sc->mergeCallSuper(loc, cs1);
    e2 = resolveProperties(sc, e2);
    e2 = e2->checkToPointer();

    if (e2->type->ty == Tvoid)
        type = Type::tvoid;
    else
    {
        e2 = e2->checkToBoolean();
        type = Type::tboolean;
    }
    if (e2->op == TOKtype || e2->op == TOKimport)
    {   error("%s is not an expression", e2->toChars());
        return new ErrorExp();
    }
    if (e1->op == TOKerror)
        return e1;
    if (e2->op == TOKerror)
        return e2;
    return this;
}

Expression *AndAndExp::checkToBoolean()
{
    e2 = e2->checkToBoolean();
    return this;
}

int AndAndExp::isBit()
{
    return TRUE;
}

int AndAndExp::checkSideEffect(int flag)
{
    if (flag == 2)
    {
        return e1->hasSideEffect() || e2->hasSideEffect();
    }
    else
    {
        e1->checkSideEffect(1);
        return e2->checkSideEffect(flag);
    }
}

/************************************************************/

InExp::InExp(Loc loc, Expression *e1, Expression *e2)
        : BinExp(loc, TOKin, sizeof(InExp), e1, e2)
{
}

Expression *InExp::semantic(Scope *sc)
{   Expression *e;

    if (type)
        return this;

    BinExp::semanticp(sc);
    e = op_overload(sc);
    if (e)
        return e;

    //type = Type::tboolean;
    Type *t2b = e2->type->toBasetype();
    switch (t2b->ty)
    {
        case Taarray:
        {
            TypeAArray *ta = (TypeAArray *)t2b;

#if DMDV2
            // Special handling for array keys
            if (!arrayTypeCompatible(e1->loc, e1->type, ta->index))
#endif
            {
                // Convert key to type of key
                e1 = e1->implicitCastTo(sc, ta->index);
            }

            // Return type is pointer to value
            type = ta->nextOf()->pointerTo();
            break;
        }

        default:
            error("rvalue of in expression must be an associative array, not %s", e2->type->toChars());
        case Terror:
            return new ErrorExp();
    }
    return this;
}

int InExp::isBit()
{
    return FALSE;
}


/************************************************************/

/* This deletes the key e1 from the associative array e2
 */

RemoveExp::RemoveExp(Loc loc, Expression *e1, Expression *e2)
        : BinExp(loc, TOKremove, sizeof(RemoveExp), e1, e2)
{
    type = Type::tvoid;
}

void RemoveExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    expToCBuffer(buf, hgs, e1, PREC_primary);
    buf->writestring(".remove(");
    expToCBuffer(buf, hgs, e2, PREC_assign);
    buf->writestring(")");
}

/************************************************************/

CmpExp::CmpExp(enum TOK op, Loc loc, Expression *e1, Expression *e2)
        : BinExp(loc, op, sizeof(CmpExp), e1, e2)
{
}

Expression *CmpExp::semantic(Scope *sc)
{   Expression *e;

#if LOGSEMANTIC
    printf("CmpExp::semantic('%s')\n", toChars());
#endif
    if (type)
        return this;

    BinExp::semanticp(sc);

    Type *t1 = e1->type->toBasetype();
    Type *t2 = e2->type->toBasetype();
    if (t1->ty == Tclass && e2->op == TOKnull ||
        t2->ty == Tclass && e1->op == TOKnull)
    {
        error("do not use null when comparing class types");
    }

    e = op_overload(sc);
    if (e)
    {
        if (!e->type->isscalar() && e->type->equals(e1->type))
        {
            error("recursive opCmp expansion");
            e = new ErrorExp();
        }
        else
        {   e = new CmpExp(op, loc, e, new IntegerExp(loc, 0, Type::tint32));
            e = e->semantic(sc);
        }
        return e;
    }

    /* Disallow comparing T[]==T and T==T[]
     */
    if (e1->op == TOKslice && t1->ty == Tarray && e2->implicitConvTo(t1->nextOf()) ||
        e2->op == TOKslice && t2->ty == Tarray && e1->implicitConvTo(t2->nextOf()))
    {
        incompatibleTypes();
        return new ErrorExp();
    }

    typeCombine(sc);
    type = Type::tboolean;

    // Special handling for array comparisons
    t1 = e1->type->toBasetype();
    t2 = e2->type->toBasetype();
    if ((t1->ty == Tarray || t1->ty == Tsarray) &&
        (t2->ty == Tarray || t2->ty == Tsarray))
    {
        if (!t1->next->equals(t2->next))
            error("array comparison type mismatch, %s vs %s", t1->next->toChars(), t2->next->toChars());
        e = this;
    }
    else if (t1->ty == Tstruct || t2->ty == Tstruct ||
             (t1->ty == Tclass && t2->ty == Tclass))
    {
        if (t2->ty == Tstruct)
            error("need member function opCmp() for %s %s to compare", t2->toDsymbol(sc)->kind(), t2->toChars());
        else
            error("need member function opCmp() for %s %s to compare", t1->toDsymbol(sc)->kind(), t1->toChars());
        e = this;
    }
#if 1
    else if (t1->iscomplex() || t2->iscomplex())
    {
        error("compare not defined for complex operands");
        e = new IntegerExp(0);
    }
#endif
    else
        e = this;
    //printf("CmpExp: %s\n", e->toChars());
    return e;
}

int CmpExp::isBit()
{
    return TRUE;
}


/************************************************************/

EqualExp::EqualExp(enum TOK op, Loc loc, Expression *e1, Expression *e2)
        : BinExp(loc, op, sizeof(EqualExp), e1, e2)
{
    assert(op == TOKequal || op == TOKnotequal);
}

Expression *EqualExp::semantic(Scope *sc)
{   Expression *e;

    //printf("EqualExp::semantic('%s')\n", toChars());
    if (type)
        return this;

    BinExp::semanticp(sc);

    /* Before checking for operator overloading, check to see if we're
     * comparing the addresses of two statics. If so, we can just see
     * if they are the same symbol.
     */
    if (e1->op == TOKaddress && e2->op == TOKaddress)
    {   AddrExp *ae1 = (AddrExp *)e1;
        AddrExp *ae2 = (AddrExp *)e2;

        if (ae1->e1->op == TOKvar && ae2->e1->op == TOKvar)
        {   VarExp *ve1 = (VarExp *)ae1->e1;
            VarExp *ve2 = (VarExp *)ae2->e1;

            if (ve1->var == ve2->var /*|| ve1->var->toSymbol() == ve2->var->toSymbol()*/)
            {
                // They are the same, result is 'true' for ==, 'false' for !=
                e = new IntegerExp(loc, (op == TOKequal), Type::tboolean);
                return e;
            }
        }
    }

    Type *t1 = e1->type->toBasetype();
    Type *t2 = e2->type->toBasetype();
    if (t1->ty == Tclass && e2->op == TOKnull ||
        t2->ty == Tclass && e1->op == TOKnull)
    {
        error("use '%s' instead of '%s' when comparing with null",
                Token::toChars(op == TOKequal ? TOKidentity : TOKnotidentity),
                Token::toChars(op));
    }

    //if (e2->op != TOKnull)
    {
        e = op_overload(sc);
        if (e)
        {
            if (op == TOKnotequal)
            {
                e = new NotExp(e->loc, e);
                e = e->semantic(sc);
            }
            return e;
        }
    }

    /* Disallow comparing T[]==T and T==T[]
     */
    if (e1->op == TOKslice && t1->ty == Tarray && e2->implicitConvTo(t1->nextOf()) ||
        e2->op == TOKslice && t2->ty == Tarray && e1->implicitConvTo(t2->nextOf()))
    {
        incompatibleTypes();
        return new ErrorExp();
    }

    e = typeCombine(sc);
    type = Type::tboolean;

    // Special handling for array comparisons
    t1 = e1->type->toBasetype();
    t2 = e2->type->toBasetype();
    if ((t1->ty == Tarray || t1->ty == Tsarray) &&
        (t2->ty == Tarray || t2->ty == Tsarray))
    {
        if (!t1->next->equals(t2->next))
            error("array comparison type mismatch, %s vs %s", t1->next->toChars(), t2->next->toChars());
    }
    else
    {
        if (e1->type != e2->type && e1->type->isfloating() && e2->type->isfloating())
        {
            // Cast both to complex
            e1 = e1->castTo(sc, Type::tcomplex80);
            e2 = e2->castTo(sc, Type::tcomplex80);
        }
    }
    return e;
}

int EqualExp::isBit()
{
    return TRUE;
}



/************************************************************/

IdentityExp::IdentityExp(enum TOK op, Loc loc, Expression *e1, Expression *e2)
        : BinExp(loc, op, sizeof(IdentityExp), e1, e2)
{
}

Expression *IdentityExp::semantic(Scope *sc)
{
    if (type)
        return this;

    BinExp::semanticp(sc);
    type = Type::tboolean;
    typeCombine(sc);
    if (e1->type != e2->type && e1->type->isfloating() && e2->type->isfloating())
    {
        // Cast both to complex
        e1 = e1->castTo(sc, Type::tcomplex80);
        e2 = e2->castTo(sc, Type::tcomplex80);
    }
    return this;
}

int IdentityExp::isBit()
{
    return TRUE;
}


/****************************************************************/

CondExp::CondExp(Loc loc, Expression *econd, Expression *e1, Expression *e2)
        : BinExp(loc, TOKquestion, sizeof(CondExp), e1, e2)
{
    this->econd = econd;
}

Expression *CondExp::syntaxCopy()
{
    return new CondExp(loc, econd->syntaxCopy(), e1->syntaxCopy(), e2->syntaxCopy());
}


Expression *CondExp::semantic(Scope *sc)
{   Type *t1;
    Type *t2;
    unsigned cs0;
    unsigned cs1;

#if LOGSEMANTIC
    printf("CondExp::semantic('%s')\n", toChars());
#endif
    if (type)
        return this;

    econd = econd->semantic(sc);
    econd = resolveProperties(sc, econd);
    econd = econd->checkToPointer();
    econd = econd->checkToBoolean();

#if 0   /* this cannot work right because the types of e1 and e2
         * both contribute to the type of the result.
         */
    if (sc->flags & SCOPEstaticif)
    {
        /* If in static if, don't evaluate what we don't have to.
         */
        econd = econd->optimize(WANTflags);
        if (econd->isBool(TRUE))
        {
            e1 = e1->semantic(sc);
            e1 = resolveProperties(sc, e1);
            return e1;
        }
        else if (econd->isBool(FALSE))
        {
            e2 = e2->semantic(sc);
            e2 = resolveProperties(sc, e2);
            return e2;
        }
    }
#endif


    cs0 = sc->callSuper;
    e1 = e1->semantic(sc);
    e1 = resolveProperties(sc, e1);
    cs1 = sc->callSuper;
    sc->callSuper = cs0;
    e2 = e2->semantic(sc);
    e2 = resolveProperties(sc, e2);
    sc->mergeCallSuper(loc, cs1);


    // If either operand is void, the result is void
    t1 = e1->type;
    t2 = e2->type;
    if (t1->ty == Tvoid || t2->ty == Tvoid)
        type = Type::tvoid;
    else if (t1 == t2)
        type = t1;
    else
    {
        typeCombine(sc);
        switch (e1->type->toBasetype()->ty)
        {
            case Tcomplex32:
            case Tcomplex64:
            case Tcomplex80:
                e2 = e2->castTo(sc, e1->type);
                break;
        }
        switch (e2->type->toBasetype()->ty)
        {
            case Tcomplex32:
            case Tcomplex64:
            case Tcomplex80:
                e1 = e1->castTo(sc, e2->type);
                break;
        }
    }
#if 0
    printf("res: %s\n", type->toChars());
    printf("e1 : %s\n", e1->type->toChars());
    printf("e2 : %s\n", e2->type->toChars());
#endif
    return this;
}


int CondExp::isLvalue()
{
    return e1->isLvalue() && e2->isLvalue();
}


Expression *CondExp::toLvalue(Scope *sc, Expression *ex)
{
    PtrExp *e;

    // convert (econd ? e1 : e2) to *(econd ? &e1 : &e2)
    e = new PtrExp(loc, this, type);

    e1 = e1->addressOf(sc);
    e2 = e2->addressOf(sc);

    typeCombine(sc);

    type = e2->type;
    return e;
}

Expression *CondExp::modifiableLvalue(Scope *sc, Expression *e)
{
    error("conditional expression %s is not a modifiable lvalue", toChars());
    return this;
}

void CondExp::checkEscape()
{
    e1->checkEscape();
    e2->checkEscape();
}

void CondExp::checkEscapeRef()
{
    e1->checkEscapeRef();
    e2->checkEscapeRef();
}


Expression *CondExp::checkToBoolean()
{
    e1 = e1->checkToBoolean();
    e2 = e2->checkToBoolean();
    return this;
}

int CondExp::checkSideEffect(int flag)
{
    if (flag == 2)
    {
        return econd->hasSideEffect() ||
                e1->hasSideEffect() ||
                e2->hasSideEffect();
    }
    else
    {
        econd->checkSideEffect(1);
        e1->checkSideEffect(flag);
        return e2->checkSideEffect(flag);
    }
}

#if DMDV2
int CondExp::canThrow()
{
    return econd->canThrow() || e1->canThrow() || e2->canThrow();
}
#endif

void CondExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    expToCBuffer(buf, hgs, econd, PREC_oror);
    buf->writestring(" ? ");
    expToCBuffer(buf, hgs, e1, PREC_expr);
    buf->writestring(" : ");
    expToCBuffer(buf, hgs, e2, PREC_cond);
}


/****************************************************************/

DefaultInitExp::DefaultInitExp(Loc loc, TOK subop, int size)
    : Expression(loc, TOKdefault, size)
{
    this->subop = subop;
}

void DefaultInitExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring(Token::toChars(subop));
}

/****************************************************************/

FileInitExp::FileInitExp(Loc loc)
    : DefaultInitExp(loc, TOKfile, sizeof(FileInitExp))
{
}

Expression *FileInitExp::semantic(Scope *sc)
{
    //printf("FileInitExp::semantic()\n");
    type = Type::tstring;
    return this;
}

Expression *FileInitExp::resolveLoc(Loc loc, Scope *sc)
{
    //printf("FileInitExp::resolve() %s\n", toChars());
    const char *s = loc.filename ? loc.filename : sc->module->ident->toChars();
    Expression *e = new StringExp(loc, (char *)s);
    e = e->semantic(sc);
    e = e->castTo(sc, type);
    return e;
}

/****************************************************************/

LineInitExp::LineInitExp(Loc loc)
    : DefaultInitExp(loc, TOKline, sizeof(LineInitExp))
{
}

Expression *LineInitExp::semantic(Scope *sc)
{
    type = Type::tint32;
    return this;
}

Expression *LineInitExp::resolveLoc(Loc loc, Scope *sc)
{
    Expression *e = new IntegerExp(loc, loc.linnum, Type::tint32);
    e = e->castTo(sc, type);
    return e;
}


