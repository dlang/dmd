
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2015 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/expression.c
 */

#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <math.h>
#include <assert.h>

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
#include "aav.h"
#include "nspace.h"
#include "ctfe.h"

bool isArrayOpValid(Expression *e);
Expression *createTypeInfoArray(Scope *sc, Expression *args[], size_t dim);
Expression *expandVar(int result, VarDeclaration *v);
TypeTuple *toArgTypes(Type *t);
void accessCheck(AggregateDeclaration *ad, Loc loc, Scope *sc, Dsymbol *smember);
bool checkFrameAccess(Loc loc, Scope *sc, AggregateDeclaration *ad, size_t istart = 0);
Symbol *toInitializer(AggregateDeclaration *ad);
Expression *getTypeInfo(Type *t, Scope *sc);

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
        Expression *e1, Declaration *var, int flag = 0)
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
            {
                /* e1 is the 'this' pointer for an inner class: tcd.
                 * Rewrite it as the 'this' pointer for the outer class.
                 */

                e1 = new DotVarExp(loc, e1, tcd->vthis);
                e1->type = tcd->vthis->type;
                e1->type = e1->type->addMod(t->mod);
                // Do not call checkNestedRef()
                //e1 = e1->semantic(sc);

                // Skip up over nested functions, and get the enclosing
                // class type.
                int n = 0;
                Dsymbol *s;
                for (s = tcd->toParent();
                     s && s->isFuncDeclaration();
                     s = s->toParent())
                {
                    FuncDeclaration *f = s->isFuncDeclaration();
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
                {
                    e1->type = s->isClassDeclaration()->type;
                    e1->type = e1->type->addMod(t->mod);
                    if (n > 1)
                        e1 = e1->semantic(sc);
                }
                else
                    e1 = e1->semantic(sc);
                goto L1;
            }

            /* Can't find a path from e1 to ad
             */
            if (flag)
                return NULL;
            e1->error("this for %s needs to be type %s not type %s",
                var->toChars(), ad->toChars(), t->toChars());
            return new ErrorExp();
        }
    }
    return e1;
}

/*****************************************
 * Determine if 'this' is available.
 * If it is, return the FuncDeclaration that has it.
 */

FuncDeclaration *hasThis(Scope *sc)
{
    //printf("hasThis()\n");
    Dsymbol *p = sc->parent;
    while (p && p->isTemplateMixin())
        p = p->parent;
    FuncDeclaration *fdthis = p ? p->isFuncDeclaration() : NULL;
    //printf("fdthis = %p, '%s'\n", fdthis, fdthis ? fdthis->toChars() : "");

    // Go upwards until we find the enclosing member function
    FuncDeclaration *fd = fdthis;
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

bool isNeedThisScope(Scope *sc, Declaration *d)
{
    if (sc->intypeof == 1)
        return false;

    AggregateDeclaration *ad = d->isThis();
    if (!ad)
        return false;
    //printf("d = %s, ad = %s\n", d->toChars(), ad->toChars());

    for (Dsymbol *s = sc->parent; s; s = s->toParent2())
    {
        //printf("\ts = %s %s, toParent2() = %p\n", s->kind(), s->toChars(), s->toParent2());
        if (AggregateDeclaration *ad2 = s->isAggregateDeclaration())
        {
            //printf("\t    ad2 = %s\n", ad2->toChars());
            if (ad2 == ad)
                return false;
            else if (ad2->isNested())
                continue;
            else
                return true;
        }
        if (FuncDeclaration *f = s->isFuncDeclaration())
        {
            if (f->isFuncLiteralDeclaration() && f->isNested())
                continue;
            if (f->isMember2())
                break;
        }
    }
    return true;
}

Expression *checkRightThis(Scope *sc, Expression *e)
{
    if (e->op == TOKvar && e->type->ty != Terror)
    {
        VarExp *ve = (VarExp *)e;
        if (isNeedThisScope(sc, ve->var))
        {
            //printf("checkRightThis sc->intypeof = %d, ad = %p, func = %p, fdthis = %p\n",
            //        sc->intypeof, sc->getStructClassScope(), func, fdthis);
            e->error("need 'this' for '%s' of type '%s'", ve->var->toChars(), ve->var->type->toChars());
            e = new ErrorExp();
        }
    }
    return e;
}


/***************************************
 * Pull out any properties.
 */

Expression *resolvePropertiesX(Scope *sc, Expression *e1, Expression *e2 = NULL)
{
    //printf("resolvePropertiesX, e1 = %s %s, e2 = %s\n", Token::toChars(e1->op), e1->toChars(), e2 ? e2->toChars() : NULL);
    Loc loc = e1->loc;

    OverloadSet *os;
    Dsymbol *s;
    Objects *tiargs;
    Type *tthis;
    if (e1->op == TOKdotexp)
    {
        DotExp *de = (DotExp *)e1;
        if (de->e2->op == TOKoverloadset)
        {
            tiargs = NULL;
            tthis  = de->e1->type;
            os = ((OverExp *)de->e2)->vars;
            goto Los;
        }
    }
    else if (e1->op == TOKoverloadset)
    {
        tiargs = NULL;
        tthis  = NULL;
        os = ((OverExp *)e1)->vars;
    Los:
        assert(os);
        FuncDeclaration *fd = NULL;
        if (e2)
        {
            e2 = e2->semantic(sc);
            if (e2->op == TOKerror)
                return new ErrorExp();
            e2 = resolveProperties(sc, e2);

            Expressions a;
            a.push(e2);

            for (size_t i = 0; i < os->a.dim; i++)
            {
                FuncDeclaration *f = resolveFuncCall(loc, sc, os->a[i], tiargs, tthis, &a, 1);
                if (f)
                {
                    if (f->errors)
                        return new ErrorExp();
                    fd = f;
                    assert(fd->type->ty == Tfunction);
                    TypeFunction *tf = (TypeFunction *)fd->type;
                    if (!tf->isproperty && global.params.enforcePropertySyntax)
                        goto Leprop;
                }
            }
            if (fd)
            {
                Expression *e = new CallExp(loc, e1, e2);
                return e->semantic(sc);
            }
        }
        {
            for (size_t i = 0; i < os->a.dim; i++)
            {
                FuncDeclaration *f = resolveFuncCall(loc, sc, os->a[i], tiargs, tthis, NULL, 1);
                if (f)
                {
                    if (f->errors)
                        return new ErrorExp();
                    fd = f;
                    assert(fd->type->ty == Tfunction);
                    TypeFunction *tf = (TypeFunction *)fd->type;
                    if (!tf->isref && e2)
                        goto Leproplvalue;
                    if (!tf->isproperty && global.params.enforcePropertySyntax)
                        goto Leprop;
                }
            }
            if (fd)
            {
                Expression *e = new CallExp(loc, e1);
                if (e2)
                    e = new AssignExp(loc, e, e2);
                return e->semantic(sc);
            }
        }
        if (e2)
            goto Leprop;
    }
    else if (e1->op == TOKdotti)
    {
        DotTemplateInstanceExp* dti = (DotTemplateInstanceExp *)e1;
        if (!dti->findTempDecl(sc))
            goto Leprop;
        if (!dti->ti->semanticTiargs(sc))
            goto Leprop;
        tiargs = dti->ti->tiargs;
        tthis  = dti->e1->type;
        if ((os = dti->ti->tempdecl->isOverloadSet()) != NULL)
            goto Los;
        if ((s = dti->ti->tempdecl) != NULL)
            goto Lfd;
    }
    else if (e1->op == TOKdottd)
    {
        DotTemplateExp *dte = (DotTemplateExp *)e1;
        s      = dte->td;
        tiargs = NULL;
        tthis  = dte->e1->type;
        goto Lfd;
    }
    else if (e1->op == TOKimport)
    {
        s = ((ScopeExp *)e1)->sds;
        if (s->isTemplateDeclaration())
        {
            tiargs = NULL;
            tthis  = NULL;
            goto Lfd;
        }
        TemplateInstance *ti = s->isTemplateInstance();
        if (ti && !ti->semanticRun && ti->tempdecl)
        {
            //assert(ti->needsTypeInference(sc));
            if (!ti->semanticTiargs(sc))
                goto Leprop;
            tiargs = ti->tiargs;
            tthis  = NULL;
            if ((os = ti->tempdecl->isOverloadSet()) != NULL)
                goto Los;
            if ((s = ti->tempdecl) != NULL)
                goto Lfd;
        }
    }
    else if (e1->op == TOKtemplate)
    {
        s      = ((TemplateExp *)e1)->td;
        tiargs = NULL;
        tthis  = NULL;
        goto Lfd;
    }
    else if (e1->op == TOKdotvar && e1->type && e1->type->toBasetype()->ty == Tfunction)
    {
        DotVarExp *dve = (DotVarExp *)e1;
        s      = dve->var->isFuncDeclaration();
        tiargs = NULL;
        tthis  = dve->e1->type;
        goto Lfd;
    }
    else if (e1->op == TOKvar && e1->type && e1->type->toBasetype()->ty == Tfunction)
    {
        s      = ((VarExp *)e1)->var->isFuncDeclaration();
        tiargs = NULL;
        tthis  = NULL;
    Lfd:
        assert(s);
        if (e2)
        {
            e2 = e2->semantic(sc);
            if (e2->op == TOKerror)
                return new ErrorExp();
            e2 = resolveProperties(sc, e2);

            Expressions a;
            a.push(e2);

            FuncDeclaration *fd = resolveFuncCall(loc, sc, s, tiargs, tthis, &a, 1);
            if (fd && fd->type)
            {
                if (fd->errors)
                    return new ErrorExp();
                assert(fd->type->ty == Tfunction);
                TypeFunction *tf = (TypeFunction *)fd->type;
                if (!tf->isproperty && global.params.enforcePropertySyntax)
                    goto Leprop;
                Expression *e = new CallExp(loc, e1, e2);
                return e->semantic(sc);
            }
        }
        {
            FuncDeclaration *fd = resolveFuncCall(loc, sc, s, tiargs, tthis, NULL, 1);
            if (fd && fd->type)
            {
                if (fd->errors)
                    return new ErrorExp();
                assert(fd->type->ty == Tfunction);
                TypeFunction *tf = (TypeFunction *)fd->type;
                if (!e2 || tf->isref)
                {
                    if (!tf->isproperty && global.params.enforcePropertySyntax)
                        goto Leprop;
                    Expression *e = new CallExp(loc, e1);
                    if (e2)
                        e = new AssignExp(loc, e, e2);
                    return e->semantic(sc);
                }
            }
        }
        if (FuncDeclaration *fd = s->isFuncDeclaration())
        {
            // Keep better diagnostic message for invalid property usage of functions
            assert(fd->type->ty == Tfunction);
            TypeFunction *tf = (TypeFunction *)fd->type;
            if (!tf->isproperty && global.params.enforcePropertySyntax)
            {
                error(loc, "not a property %s", e1->toChars());
                return new ErrorExp();
            }
            Expression *e = new CallExp(loc, e1, e2);
            return e->semantic(sc);
        }
        if (e2)
            goto Leprop;
    }
    if (e1->op == TOKvar)
    {
        VarExp *ve = (VarExp *)e1;
        if (VarDeclaration *v = ve->var->isVarDeclaration())
            ve->checkPurity(sc, v);
    }
    if (e2)
        return NULL;

    if (e1->type &&
        e1->op != TOKtype)      // function type is not a property
    {
        /* Look for e1 being a lazy parameter; rewrite as delegate call
         */
        if (e1->op == TOKvar)
        {
            VarExp *ve = (VarExp *)e1;

            if (ve->var->storage_class & STClazy)
            {
                Expression *e = new CallExp(loc, e1);
                return e->semantic(sc);
            }
        }
        else if (e1->op == TOKdotvar)
        {
            // Check for reading overlapped pointer field in @safe code.
            VarDeclaration *v = ((DotVarExp *)e1)->var->isVarDeclaration();
            if (v && v->overlapped &&
                sc->func && !sc->intypeof)
            {
                AggregateDeclaration *ad = v->toParent2()->isAggregateDeclaration();
                if (ad && e1->type->hasPointers() &&
                    sc->func->setUnsafe())
                {
                    e1->error("field %s.%s cannot be accessed in @safe code because it overlaps with a pointer",
                        ad->toChars(), v->toChars());
                    return new ErrorExp();
                }
            }
        }
        else if (e1->op == TOKdotexp)
        {
            e1->error("expression has no value");
            return new ErrorExp();
        }
    }

    if (!e1->type)
    {
        error(loc, "cannot resolve type for %s", e1->toChars());
        e1 = new ErrorExp();
    }
    return e1;

Leprop:
    error(loc, "not a property %s", e1->toChars());
    return new ErrorExp();

Leproplvalue:
    error(loc, "%s is not an lvalue", e1->toChars());
    return new ErrorExp();
}

Expression *resolveProperties(Scope *sc, Expression *e)
{
    //printf("resolveProperties(%s)\n", e->toChars());

    e = resolvePropertiesX(sc, e);
    e = checkRightThis(sc, e);
    return e;
}

/******************************
 * Check the tail CallExp is really property function call.
 */

void checkPropertyCall(Expression *e, Expression *emsg)
{
    while (e->op == TOKcomma)
        e = ((CommaExp *)e)->e2;

    if (e->op == TOKcall)
    {   CallExp *ce = (CallExp *)e;
        TypeFunction *tf;
        if (ce->f)
        {
            tf = (TypeFunction *)ce->f->type;
            /* If a forward reference to ce->f, try to resolve it
             */
            if (!tf->deco && ce->f->scope)
            {   ce->f->semantic(ce->f->scope);
                tf = (TypeFunction *)ce->f->type;
            }
        }
        else if (ce->e1->type->ty == Tfunction)
            tf = (TypeFunction *)ce->e1->type;
        else if (ce->e1->type->ty == Tdelegate)
            tf = (TypeFunction *)ce->e1->type->nextOf();
        else if (ce->e1->type->ty == Tpointer && ce->e1->type->nextOf()->ty == Tfunction)
            tf = (TypeFunction *)ce->e1->type->nextOf();
        else
            assert(0);

        if (!tf->isproperty && global.params.enforcePropertySyntax)
            ce->e1->error("not a property %s", emsg->toChars());
    }
}

/******************************
 * If e1 is a property function (template), resolve it.
 */

Expression *resolvePropertiesOnly(Scope *sc, Expression *e1)
{
    //printf("e1 = %s %s\n", Token::toChars(e1->op), e1->toChars());
    OverloadSet *os;
    FuncDeclaration *fd;
    TemplateDeclaration *td;

    if (e1->op == TOKdotexp)
    {
        DotExp *de = (DotExp *)e1;
        if (de->e2->op == TOKoverloadset)
        {
            os = ((OverExp *)de->e2)->vars;
            goto Los;
        }
    }
    else if (e1->op == TOKoverloadset)
    {
        os = ((OverExp *)e1)->vars;
    Los:
        assert(os);
        for (size_t i = 0; i < os->a.dim; i++)
        {
            Dsymbol *s = os->a[i];
            fd = s->isFuncDeclaration();
            td = s->isTemplateDeclaration();
            if (fd)
            {
                if (((TypeFunction *)fd->type)->isproperty)
                    return resolveProperties(sc, e1);
            }
            else if (td && td->onemember &&
                     (fd = td->onemember->isFuncDeclaration()) != NULL)
            {
                if (((TypeFunction *)fd->type)->isproperty ||
                    (fd->storage_class2 & STCproperty) ||
                    (td->scope->stc & STCproperty))
                {
                    return resolveProperties(sc, e1);
                }
            }
        }
    }
    else if (e1->op == TOKdotti)
    {
        DotTemplateInstanceExp* dti = (DotTemplateInstanceExp *)e1;
        if (dti->ti->tempdecl && (td = dti->ti->tempdecl->isTemplateDeclaration()) != NULL)
            goto Ltd;
    }
    else if (e1->op == TOKdottd)
    {
        td = ((DotTemplateExp *)e1)->td;
        goto Ltd;
    }
    else if (e1->op == TOKimport)
    {
        Dsymbol *s = ((ScopeExp *)e1)->sds;
        td = s->isTemplateDeclaration();
        if (td)
            goto Ltd;
        TemplateInstance *ti = s->isTemplateInstance();
        if (ti && !ti->semanticRun && ti->tempdecl)
        {
            if ((td = ti->tempdecl->isTemplateDeclaration()) != NULL)
                goto Ltd;
        }
    }
    else if (e1->op == TOKtemplate)
    {
        td = ((TemplateExp *)e1)->td;
    Ltd:
        assert(td);
        if (td->onemember &&
            (fd = td->onemember->isFuncDeclaration()) != NULL)
        {
            if (((TypeFunction *)fd->type)->isproperty ||
                (fd->storage_class2 & STCproperty) ||
                (td->scope->stc & STCproperty))
            {
                return resolveProperties(sc, e1);
            }
        }
    }
    else if (e1->op == TOKdotvar && e1->type->ty == Tfunction)
    {
        DotVarExp *dve = (DotVarExp *)e1;
        fd = dve->var->isFuncDeclaration();
        goto Lfd;
    }
    else if (e1->op == TOKvar && e1->type->ty == Tfunction &&
        (sc->intypeof || !((VarExp *)e1)->var->needThis()))
    {
        fd = ((VarExp *)e1)->var->isFuncDeclaration();
    Lfd:
        assert(fd);
        if (((TypeFunction *)fd->type)->isproperty)
            return resolveProperties(sc, e1);
    }
    return e1;
}


/******************************
 * Find symbol in accordance with the UFCS name look up rule
 */

Expression *searchUFCS(Scope *sc, UnaExp *ue, Identifier *ident)
{
    Loc loc = ue->loc;
    Dsymbol *s = NULL;

    for (Scope *scx = sc; scx; scx = scx->enclosing)
    {
        if (!scx->scopesym)
            continue;
        s = scx->scopesym->search(loc, ident);
        if (s)
        {
            // overload set contains only module scope symbols.
            if (s->isOverloadSet())
                break;
            // selective/renamed imports also be picked up
            if (AliasDeclaration *ad = s->isAliasDeclaration())
            {
                if (ad->import)
                    break;
            }
            // See only module scope symbols for UFCS target.
            Dsymbol *p = s->toParent2();
            if (p && p->isModule())
                break;
        }
        s = NULL;
    }
    if (!s)
        return ue->e1->type->Type::getProperty(loc, ident, 0);

    FuncDeclaration *f = s->isFuncDeclaration();
    if (f)
    {
        TemplateDeclaration *td = getFuncTemplateDecl(f);
        if (td)
        {
            if (td->overroot)
                td = td->overroot;
            s = td;
        }
    }

    if (ue->op == TOKdotti)
    {
        DotTemplateInstanceExp *dti = (DotTemplateInstanceExp *)ue;
        TemplateInstance *ti = new TemplateInstance(loc, s->ident);
        ti->tiargs = dti->ti->tiargs;   // for better diagnostic message
        if (!ti->updateTempDecl(sc, s))
            return new ErrorExp();
        return new ScopeExp(loc, ti);
    }
    else
    {
        return new DsymbolExp(loc, s, 1);
    }
}

/******************************
 * check e is exp.opDispatch!(tiargs) or not
 * It's used to switch to UFCS the semantic analysis path
 */

bool isDotOpDispatch(Expression *e)
{
    return e->op == TOKdotti &&
           ((DotTemplateInstanceExp *)e)->ti->name == Id::opDispatch;
}

/******************************
 * Pull out callable entity with UFCS.
 */

Expression *resolveUFCS(Scope *sc, CallExp *ce)
{
    Loc loc = ce->loc;
    Expression *eleft;
    Expression *e;

    if (ce->e1->op == TOKdot)
    {
        DotIdExp *die = (DotIdExp *)ce->e1;
        Identifier *ident = die->ident;

        Expression *ex = die->semanticX(sc);
        if (ex != die)
        {
            ce->e1 = ex;
            return NULL;
        }
        eleft = die->e1;

        Type *t = eleft->type->toBasetype();
        if (t->ty == Tarray || t->ty == Tsarray ||
            t->ty == Tnull  || (t->isTypeBasic() && t->ty != Tvoid))
        {
            /* Built-in types and arrays have no callable properties, so do shortcut.
             * It is necessary in: e.init()
             */
        }
        else if (t->ty == Taarray)
        {
            if (ident == Id::remove)
            {
                /* Transform:
                 *  aa.remove(arg) into delete aa[arg]
                 */
                if (!ce->arguments || ce->arguments->dim != 1)
                {
                    ce->error("expected key as argument to aa.remove()");
                    return new ErrorExp();
                }
                if (!eleft->type->isMutable())
                {
                    ce->error("cannot remove key from %s associative array %s",
                            MODtoChars(t->mod), eleft->toChars());
                    return new ErrorExp();
                }
                Expression *key = (*ce->arguments)[0];
                key = key->semantic(sc);
                key = resolveProperties(sc, key);

                TypeAArray *taa = (TypeAArray *)t;
                key = key->implicitCastTo(sc, taa->index);

                if (!key->rvalue())
                    return new ErrorExp();

                return new RemoveExp(loc, eleft, key);
            }
        }
        else
        {
            if (Expression *ey = die->semanticY(sc, 1))
            {
                if (ey->op == TOKerror)
                    return ey;
                ce->e1 = ey;
                if (isDotOpDispatch(ey))
                {
                    unsigned errors = global.startGagging();
                    e = ce->syntaxCopy()->semantic(sc);
                    if (!global.endGagging(errors))
                        return e;
                    /* fall down to UFCS */
                }
                else
                    return NULL;
            }
        }
        e = searchUFCS(sc, die, ident);
    }
    else if (ce->e1->op == TOKdotti)
    {
        DotTemplateInstanceExp *dti = (DotTemplateInstanceExp *)ce->e1;
        if (Expression *ey = dti->semanticY(sc, 1))
        {
            ce->e1 = ey;
            return NULL;
        }
        eleft = dti->e1;
        e = searchUFCS(sc, dti, dti->ti->name);
    }
    else
        return NULL;

    // Rewrite
    ce->e1 = e;
    if (!ce->arguments)
        ce->arguments = new Expressions();
    ce->arguments->shift(eleft);

    return NULL;
}

/******************************
 * Pull out property with UFCS.
 */

Expression *resolveUFCSProperties(Scope *sc, Expression *e1, Expression *e2 = NULL)
{
    Loc loc = e1->loc;
    Expression *eleft;
    Expression *e;

    if (e1->op == TOKdot)
    {
        DotIdExp *die = (DotIdExp *)e1;
        eleft = die->e1;
        e = searchUFCS(sc, die, die->ident);
    }
    else if (e1->op == TOKdotti)
    {
        DotTemplateInstanceExp *dti;
        dti = (DotTemplateInstanceExp *)e1;
        eleft = dti->e1;
        e = searchUFCS(sc, dti, dti->ti->name);
    }
    else
        return NULL;

    // Rewrite
    if (e2)
    {
        // run semantic without gagging
        e2 = e2->semantic(sc);

        /* f(e1) = e2
         */
        Expression *ex = e->copy();
        Expressions *a1 = new Expressions();
        a1->setDim(1);
        (*a1)[0] = eleft;
        ex = new CallExp(loc, ex, a1);
        ex = ex->trySemantic(sc);

        /* f(e1, e2)
         */
        Expressions *a2 = new Expressions();
        a2->setDim(2);
        (*a2)[0] = eleft;
        (*a2)[1] = e2;
        e = new CallExp(loc, e, a2);
        if (ex)
        {   // if fallback setter exists, gag errors
            e = e->trySemantic(sc);
            if (!e)
            {   checkPropertyCall(ex, e1);
                ex = new AssignExp(loc, ex, e2);
                return ex->semantic(sc);
            }
        }
        else
        {   // strict setter prints errors if fails
            e = e->semantic(sc);
        }
        checkPropertyCall(e, e1);
        return e;
    }
    else
    {
        /* f(e1)
         */
        Expressions *arguments = new Expressions();
        arguments->setDim(1);
        (*arguments)[0] = eleft;
        e = new CallExp(loc, e, arguments);
        e = e->semantic(sc);
        checkPropertyCall(e, e1);
        return e->semantic(sc);
    }
}

/******************************
 * Perform semantic() on an array of Expressions.
 */

bool arrayExpressionSemantic(Expressions *exps, Scope *sc)
{
    bool err = false;
    if (exps)
    {
        for (size_t i = 0; i < exps->dim; i++)
        {
            Expression *e = (*exps)[i];
            if (e)
            {
                e = e->semantic(sc);
                if (e->op == TOKerror)
                    err = true;
                else
                    (*exps)[i] = e;
            }
        }
    }
    return err;
}

/****************************************
 * Expand tuples.
 * Input:
 *      exps    aray of Expressions
 * Output:
 *      exps    rewritten in place
 */

void expandTuples(Expressions *exps)
{
    //printf("expandTuples()\n");
    if (exps)
    {
        for (size_t i = 0; i < exps->dim; i++)
        {
            Expression *arg = (*exps)[i];
            if (!arg)
                continue;

            // Look for tuple with 0 members
            if (arg->op == TOKtype)
            {
                TypeExp *e = (TypeExp *)arg;
                if (e->type->toBasetype()->ty == Ttuple)
                {
                    TypeTuple *tt = (TypeTuple *)e->type->toBasetype();

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
            {
                TupleExp *te = (TupleExp *)arg;
                exps->remove(i);                // remove arg
                exps->insert(i, te->exps);      // replace with tuple contents
                if (i == exps->dim)
                    return;             // empty tuple, no more arguments
                (*exps)[i] = Expression::combine(te->e0, (*exps)[i]);
                arg = (*exps)[i];
            }
        }
    }
}

/****************************************
 * Expand alias this tuples.
 */

TupleDeclaration *isAliasThisTuple(Expression *e)
{
    if (!e->type)
        return NULL;

    Type *t = e->type->toBasetype();
Lagain:
    if (Dsymbol *s = t->toDsymbol(NULL))
    {
        AggregateDeclaration *ad = s->isAggregateDeclaration();
        if (ad)
        {
            s = ad->aliasthis;
            if (s && s->isVarDeclaration())
            {
                TupleDeclaration *td = s->isVarDeclaration()->toAlias()->isTupleDeclaration();
                if (td && td->isexp)
                    return td;
            }
            if (Type *att = t->aliasthisOf())
            {
                t = att;
                goto Lagain;
            }
        }
    }
    return NULL;
}

int expandAliasThisTuples(Expressions *exps, size_t starti)
{
    if (!exps || exps->dim == 0)
        return -1;

    for (size_t u = starti; u < exps->dim; u++)
    {
        Expression *exp = (*exps)[u];
        TupleDeclaration *td = isAliasThisTuple(exp);
        if (td)
        {
            exps->remove(u);
            for (size_t i = 0; i<td->objects->dim; ++i)
            {
                Expression *e = isExpression((*td->objects)[i]);
                assert(e);
                assert(e->op == TOKdsymbol);
                DsymbolExp *se = (DsymbolExp *)e;
                Declaration *d = se->s->isDeclaration();
                assert(d);
                e = new DotVarExp(exp->loc, exp, d);
                assert(d->type);
                e->type = d->type;
                exps->insert(u + i, e);
            }
    #if 0
            printf("expansion ->\n");
            for (size_t i = 0; i<exps->dim; ++i)
            {
                Expression *e = (*exps)[i];
                printf("\texps[%d] e = %s %s\n", i, Token::tochars[e->op], e->toChars());
            }
    #endif
            return (int)u;
        }
    }

    return -1;
}

/****************************************
 * The common type is determined by applying ?: to each pair.
 * Output:
 *      exps[]  properties resolved, implicitly cast to common type, rewritten in place
 *      *pt     if pt is not NULL, set to the common type
 * Returns:
 *      true    a semantic error was detected
 */

bool arrayExpressionToCommonType(Scope *sc, Expressions *exps, Type **pt)
{
    /* Still have a problem with:
     *  ubyte[][] = [ cast(ubyte[])"hello", [1]];
     * which works if the array literal is initialized top down with the ubyte[][]
     * type, but fails with this function doing bottom up typing.
     */
    //printf("arrayExpressionToCommonType()\n");
    IntegerExp integerexp(0);
    CondExp condexp(Loc(), &integerexp, NULL, NULL);

    Type *t0 = NULL;
    Expression *e0;
    size_t j0;
    for (size_t i = 0; i < exps->dim; i++)
    {
        Expression *e = (*exps)[i];
        e = resolveProperties(sc, e);
        if (!e->type)
        {
            e->error("%s has no value", e->toChars());
            t0 = Type::terror;
            continue;
        }
        if (e->op == TOKtype)
        {
            e->rvalue();
            t0 = Type::terror;
            continue;
        }
        if (checkNonAssignmentArrayOp(e))
        {
            t0 = Type::terror;
            continue;
        }

        e = e->isLvalue() ? callCpCtor(sc, e) : valueNoDtor(e);

        if (t0 && !t0->equals(e->type))
        {
            /* This applies ?: to merge the types. It's backwards;
             * ?: should call this function to merge types.
             */
            condexp.type = NULL;
            condexp.e1 = e0;
            condexp.e2 = e;
            condexp.loc = e->loc;
            Expression *ex = condexp.semantic(sc);
            if (ex->op == TOKerror)
                e = ex;
            else
            {
                (*exps)[j0] = condexp.e1;
                e = condexp.e2;
            }
        }
        j0 = i;
        e0 = e;
        t0 = e->type;
        if (e->op != TOKerror)
            (*exps)[i] = e;
    }

    if (!t0)
        t0 = Type::tvoid;               // [] is typed as void[]
    else if (t0->ty != Terror)
    {
        for (size_t i = 0; i < exps->dim; i++)
        {
            Expression *e = (*exps)[i];
            e = e->implicitCastTo(sc, t0);
            //assert(e->op != TOKerror);
            if (e->op == TOKerror)
            {
                /* Bugzilla 13024: a workaround for the bug in typeMerge -
                 * it should paint e1 and e2 by deduced common type,
                 * but doesn't in this particular case.
                 */
                t0 = Type::terror;
                break;
            }
            (*exps)[i] = e;
        }
    }
    if (pt)
        *pt = t0;

    return (t0 == Type::terror);
}

/****************************************
 * Get TemplateDeclaration enclosing FuncDeclaration.
 */

TemplateDeclaration *getFuncTemplateDecl(Dsymbol *s)
{
    FuncDeclaration *f = s->isFuncDeclaration();
    if (f && f->parent)
    {
        TemplateInstance *ti = f->parent->isTemplateInstance();
        if (ti && !ti->isTemplateMixin() &&
            ti->tempdecl && ((TemplateDeclaration *)ti->tempdecl)->onemember &&
            ti->tempdecl->ident == f->ident)
        {
            return (TemplateDeclaration *)ti->tempdecl;
        }
    }
    return NULL;
}

/****************************************
 * Preprocess arguments to function.
 * Output:
 *      exps[]  tuples expanded, properties resolved, rewritten in place
 * Returns:
 *      true    a semantic error occurred
 */

bool preFunctionParameters(Loc loc, Scope *sc, Expressions *exps)
{
    bool err = false;
    if (exps)
    {
        expandTuples(exps);

        for (size_t i = 0; i < exps->dim; i++)
        {
            Expression *arg = (*exps)[i];

            arg = resolveProperties(sc, arg);
            if (arg->op == TOKtype)
            {
                arg->error("cannot pass type %s as a function argument", arg->toChars());
                arg = new ErrorExp();
                err = true;
            }
            else if (checkNonAssignmentArrayOp(arg))
            {
                arg = new ErrorExp();
                err = true;
            }
            (*exps)[i] =  arg;
        }
    }
    return err;
}

/************************************************
 * If we want the value of this expression, but do not want to call
 * the destructor on it.
 */

Expression *valueNoDtor(Expression *e)
{
    if (e->op == TOKcall)
    {
        /* The struct value returned from the function is transferred
         * so do not call the destructor on it.
         * Recognize:
         *       ((S _ctmp = S.init), _ctmp).this(...)
         * and make sure the destructor is not called on _ctmp
         * BUG: if e is a CommaExp, we should go down the right side.
         */
        CallExp *ce = (CallExp *)e;
        if (ce->e1->op == TOKdotvar)
        {
            DotVarExp *dve = (DotVarExp *)ce->e1;
            if (dve->var->isCtorDeclaration())
            {
                // It's a constructor call
                if (dve->e1->op == TOKcomma)
                {
                    CommaExp *comma = (CommaExp *)dve->e1;
                    if (comma->e2->op == TOKvar)
                    {
                        VarExp *ve = (VarExp *)comma->e2;
                        VarDeclaration *ctmp = ve->var->isVarDeclaration();
                        if (ctmp)
                        {
                            ctmp->noscope = 1;
                            assert(!ce->isLvalue());
                        }
                    }
                }
            }
        }
    }
    return e;
}

/********************************************
 * Issue an error if default construction is disabled for type t.
 * Default construction is required for arrays and 'out' parameters.
 * Returns:
 *      true    an error was issued
 */
bool checkDefCtor(Loc loc, Type *t)
{
    t = t->baseElemOf();
    if (t->ty == Tstruct)
    {
        StructDeclaration *sd = ((TypeStruct *)t)->sym;
        if (sd->noDefaultCtor)
        {
            sd->error(loc, "default construction is disabled");
            return true;
        }
    }
    return false;
}

/********************************************
 * Determine if t is an array of structs that need a postblit.
 */
bool Expression::checkPostblit(Scope *sc, Type *t)
{
    t = t->baseElemOf();
    if (t->ty == Tstruct)
    {
        // Bugzilla 11395: Require TypeInfo generation for array concatenation
        semanticTypeInfo(sc, t);

        StructDeclaration *sd = ((TypeStruct *)t)->sym;
        if (sd->postblit)
        {
            if (sd->postblit->storage_class & STCdisable)
                sd->error(loc, "is not copyable because it is annotated with @disable");
            else
            {
                checkPurity(sc, sd->postblit);
                checkSafety(sc, sd->postblit);
                checkNogc(sc, sd->postblit);
            }
            return true;
        }
    }
    return false;
}

/*********************************************
 * If e is an instance of a struct, and that struct has a copy constructor,
 * rewrite e as:
 *    (tmp = e),tmp
 * Input:
 *      sc      just used to specify the scope of created temporary variable
 */
Expression *callCpCtor(Scope *sc, Expression *e)
{
    Type *tv = e->type->baseElemOf();
    if (tv->ty == Tstruct)
    {
        StructDeclaration *sd = ((TypeStruct *)tv)->sym;
        if (sd->postblit)
        {
            /* Create a variable tmp, and replace the argument e with:
             *      (tmp = e),tmp
             * and let AssignExp() handle the construction.
             * This is not the most efficent, ideally tmp would be constructed
             * directly onto the stack.
             */
            Identifier *idtmp = Identifier::generateId("__copytmp");
            VarDeclaration *tmp = new VarDeclaration(e->loc, e->type, idtmp, new ExpInitializer(e->loc, e));
            tmp->storage_class |= STCtemp | STCctfe;
            tmp->noscope = 1;
            tmp->semantic(sc);
            Expression *de = new DeclarationExp(e->loc, tmp);
            Expression *ve = new VarExp(e->loc, tmp);
            de->type = Type::tvoid;
            ve->type = e->type;
            e = Expression::combine(de, ve);
        }
    }
    return e;
}

/****************************************
 * Now that we know the exact type of the function we're calling,
 * the arguments[] need to be adjusted:
 *      1. implicitly convert argument to the corresponding parameter type
 *      2. add default arguments for any missing arguments
 *      3. do default promotions on arguments corresponding to ...
 *      4. add hidden _arguments[] argument
 *      5. call copy constructor for struct value arguments
 * Input:
 *      tf      type of the function
 *      fd      the function being called, NULL if called indirectly
 * Output:
 *      *prettype return type of function
 *      *peprefix expression to execute before arguments[] are evaluated, NULL if none
 * Returns:
 *      true    errors happened
 */

bool functionParameters(Loc loc, Scope *sc, TypeFunction *tf,
        Type *tthis, Expressions *arguments, FuncDeclaration *fd, Type **prettype, Expression **peprefix)
{
    //printf("functionParameters()\n");
    assert(arguments);
    assert(fd || tf->next);
    size_t nargs = arguments ? arguments->dim : 0;
    size_t nparams = Parameter::dim(tf->parameters);
    unsigned olderrors = global.errors;
    bool err = false;
    *prettype = Type::terror;
    Expression *eprefix = NULL;
    *peprefix = NULL;

    if (nargs > nparams && tf->varargs == 0)
    {
        error(loc, "expected %llu arguments, not %llu for non-variadic function type %s", (ulonglong)nparams, (ulonglong)nargs, tf->toChars());
        return true;
    }

    // If inferring return type, and semantic3() needs to be run if not already run
    if (!tf->next && fd->inferRetType)
    {
        fd->functionSemantic();
    }
    else if (fd && fd->parent)
    {
        TemplateInstance *ti = fd->parent->isTemplateInstance();
        if (ti && ti->tempdecl)
        {
            fd->functionSemantic3();
        }
    }
    bool isCtorCall = fd && fd->needThis() && fd->isCtorDeclaration();

    size_t n = (nargs > nparams) ? nargs : nparams;   // n = max(nargs, nparams)

    /* If the function return type has wildcards in it, we'll need to figure out the actual type
     * based on the actual argument types.
     */
    MOD wildmatch = 0;
    if (tthis && tf->isWild() && !isCtorCall)
    {
        Type *t = tthis;
        if (t->isImmutable())
            wildmatch = MODimmutable;
        else if (t->isWildConst())
            wildmatch = MODwildconst;
        else if (t->isWild())
            wildmatch = MODwild;
        else if (t->isConst())
            wildmatch = MODconst;
        else
            wildmatch = MODmutable;
    }

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
                    error(loc, "expected %llu function arguments, not %llu", (ulonglong)nparams, (ulonglong)nargs);
                    return true;
                }
                arg = p->defaultArg;
                arg = inlineCopy(arg, sc);
                // __FILE__, __LINE__, __MODULE__, __FUNCTION__, and __PRETTY_FUNCTION__
                arg = arg->resolveLoc(loc, sc);
                arguments->push(arg);
                nargs++;
            }

            if (tf->varargs == 2 && i + 1 == nparams)
            {
                //printf("\t\tvarargs == 2, p->type = '%s'\n", p->type->toChars());
                {
                    MATCH m;
                    if ((m = arg->implicitConvTo(p->type)) > MATCHnomatch)
                    {
                        if (p->type->nextOf() && arg->implicitConvTo(p->type->nextOf()) >= m)
                            goto L2;
                        else if (nargs != nparams)
                        {   error(loc, "expected %llu function arguments, not %llu", (ulonglong)nparams, (ulonglong)nargs);
                            return true;
                        }
                        goto L1;
                    }
                }
             L2:
                Type *tb = p->type->toBasetype();
                Type *tret = p->isLazyArray();
                switch (tb->ty)
                {
                    case Tsarray:
                    case Tarray:
                    {
                        /* Create a static array variable v of type arg->type:
                         *  T[dim] __arrayArg = [ arguments[i], ..., arguments[nargs-1] ];
                         *
                         * The array literal in the initializer of the hidden variable
                         * is now optimized. See Bugzilla 2356.
                         */
                        Type *tbn = ((TypeArray *)tb)->next;
                        Type *tsa = tbn->sarrayOf(nargs - i);

                        Expressions *elements = new Expressions();
                        elements->setDim(nargs - i);
                        for (size_t u = 0; u < elements->dim; u++)
                        {
                            Expression *a = (*arguments)[i + u];
                            if (tret && a->implicitConvTo(tret))
                            {
                                a = a->implicitCastTo(sc, tret);
                                a = a->optimize(WANTvalue);
                                a = toDelegate(a, a->type, sc);
                            }
                            else
                                a = a->implicitCastTo(sc, tbn);
                            (*elements)[u] = a;
                        }
                        ArrayLiteralExp *ale = new ArrayLiteralExp(loc, elements);
                        ale->type = tsa;

                        Identifier *id = Identifier::generateId("__arrayArg");
                        VarDeclaration *v = new VarDeclaration(loc, tsa, id, new ExpInitializer(loc, ale));
                        v->storage_class |= STCtemp | STCctfe;
                        v->semantic(sc);
                        v->parent = sc->parent;

                        Expression *de = new DeclarationExp(loc, v);
                        Expression *ve = new VarExp(loc, v);
                        arg = Expression::combine(de, ve);
                        break;
                    }
                    case Tclass:
                    {
                        /* Set arg to be:
                         *      new Tclass(arg0, arg1, ..., argn)
                         */
                        Expressions *args = new Expressions();
                        args->setDim(nargs - i);
                        for (size_t u = i; u < nargs; u++)
                            (*args)[u - i] = (*arguments)[u];
                        arg = new NewExp(loc, NULL, NULL, p->type, args);
                        break;
                    }
                    default:
                        if (!arg)
                        {
                            error(loc, "not enough arguments");
                            return true;
                        }
                        break;
                }
                arg = arg->semantic(sc);
                //printf("\targ = '%s'\n", arg->toChars());
                arguments->setDim(i + 1);
                (*arguments)[i] =  arg;
                nargs = i + 1;
                done = 1;
            }

        L1:
            if (!(p->storageClass & STClazy && p->type->ty == Tvoid))
            {
                bool isRef = (p->storageClass & (STCref | STCout)) != 0;
                if (unsigned char wm = arg->type->deduceWild(p->type, isRef))
                {
                    if (wildmatch)
                        wildmatch = MODmerge(wildmatch, wm);
                    else
                        wildmatch = wm;
                    //printf("[%d] p = %s, a = %s, wm = %d, wildmatch = %d\n", i, p->type->toChars(), arg->type->toChars(), wm, wildmatch);
                }
            }
        }
        if (done)
            break;
    }
    if ((wildmatch == MODmutable || wildmatch == MODimmutable) &&
        tf->next->hasWild() &&
        (tf->isref || !tf->next->implicitConvTo(tf->next->immutableOf())))
    {
        if (fd)
        {
            /* If the called function may return the reference to
             * outer inout data, it should be rejected.
             *
             * void foo(ref inout(int) x) {
             *   ref inout(int) bar(inout(int)) { return x; }
             *   struct S { ref inout(int) bar() inout { return x; } }
             *   bar(int.init) = 1;  // bad!
             *   S().bar() = 1;      // bad!
             * }
             */
            FuncDeclaration *f;
            if (AggregateDeclaration *ad = fd->isThis())
            {
                f = ad->toParent2()->isFuncDeclaration();
                goto Linoutnest;
            }
            else if (fd->isNested())
            {
                f = fd->toParent2()->isFuncDeclaration();
            Linoutnest:
                for (; f; f = f->toParent2()->isFuncDeclaration())
                {
                    if (((TypeFunction *)f->type)->iswild)
                        goto Linouterr;
                }
            }
        }
        else if (tf->isWild())
        {
        Linouterr:
            const char *s = wildmatch == MODmutable ? "mutable" : MODtoChars(wildmatch);
            error(loc, "modify inout to %s is not allowed inside inout function", s);
            return true;
        }
    }

    assert(nargs >= nparams);
    for (size_t i = 0; i < nargs; i++)
    {
        Expression *arg = (*arguments)[i];
        assert(arg);
        if (i < nparams)
        {
            Parameter *p = Parameter::getNth(tf->parameters, i);

            if (!(p->storageClass & STClazy && p->type->ty == Tvoid))
            {
                Type *tprm = p->type;
                if (p->type->hasWild())
                    tprm = p->type->substWildTo(wildmatch);
                if (!tprm->equals(arg->type))
                {
                    //printf("arg->type = %s, p->type = %s\n", arg->type->toChars(), p->type->toChars());
                    arg = arg->implicitCastTo(sc, tprm);
                    arg = arg->optimize(WANTvalue, (p->storageClass & (STCref | STCout)) != 0);
                }
            }
            if (p->storageClass & STCref)
            {
                arg = arg->toLvalue(sc, arg);
            }
            else if (p->storageClass & STCout)
            {
                Type *t = arg->type;
                if (!t->isMutable() || !t->isAssignable())  // check blit assignable
                {
                    arg->error("cannot modify struct %s with immutable members", arg->toChars());
                    err = true;
                }
                else
                    err |= checkDefCtor(arg->loc, t);   // t must be default constructible
                arg = arg->toLvalue(sc, arg);
            }
            else if (p->storageClass & STClazy)
            {
                // Convert lazy argument to a delegate
                if (p->type->ty == Tvoid)
                    arg = toDelegate(arg, p->type, sc);
                else
                    arg = toDelegate(arg, arg->type, sc);
            }
            else
            {
//                arg = arg->isLvalue() ? callCpCtor(sc, arg) : valueNoDtor(arg);
            }

            //printf("arg: %s\n", arg->toChars());
            //printf("type: %s\n", arg->type->toChars());
            /* Look for arguments that cannot 'escape' from the called
             * function.
             */
            if (!tf->parameterEscapes(p))
            {
                Expression *a = arg;
                if (a->op == TOKcast)
                    a = ((CastExp *)a)->e1;

                if (a->op == TOKfunction)
                {
                    /* Function literals can only appear once, so if this
                     * appearance was scoped, there cannot be any others.
                     */
                    FuncExp *fe = (FuncExp *)a;
                    fe->fd->tookAddressOf = 0;
                }
                else if (a->op == TOKdelegate)
                {
                    /* For passing a delegate to a scoped parameter,
                     * this doesn't count as taking the address of it.
                     * We only worry about 'escaping' references to the function.
                     */
                    DelegateExp *de = (DelegateExp *)a;
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
            arg = arg->optimize(WANTvalue, (p->storageClass & (STCref | STCout)) != 0);
        }
        else
        {
            // These will be the trailing ... arguments

            // If not D linkage, do promotions
            if (tf->linkage != LINKd)
            {
                // Promote bytes, words, etc., to ints
                arg = integralPromotions(arg, sc);

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

                if (tf->varargs == 1)
                {
                    const char *p = tf->linkage == LINKc ? "extern(C)" : "extern(C++)";
                    if (arg->type->ty == Tarray)
                    {
                        arg->error("cannot pass dynamic arrays to %s vararg functions", p);
                        err = true;
                    }
                    if (arg->type->ty == Tsarray)
                    {
                        arg->error("cannot pass static arrays to %s vararg functions", p);
                        err = true;
                    }
                }
            }

            // Do not allow types that need destructors
            if (arg->type->needsDestruction())
            {
                arg->error("cannot pass types that need destruction as variadic arguments");
                err = true;
            }

            // Convert static arrays to dynamic arrays
            // BUG: I don't think this is right for D2
            Type *tb = arg->type->toBasetype();
            if (tb->ty == Tsarray)
            {
                TypeSArray *ts = (TypeSArray *)tb;
                Type *ta = ts->next->arrayOf();
                if (ts->size(arg->loc) == 0)
                    arg = new NullExp(arg->loc, ta);
                else
                    arg = arg->castTo(sc, ta);
            }
            if (tb->ty == Tstruct)
            {
//                arg = callCpCtor(sc, arg);
            }

            // Give error for overloaded function addresses
            if (arg->op == TOKsymoff)
            {   SymOffExp *se = (SymOffExp *)arg;
                if (se->hasOverloads &&
                    !se->var->isFuncDeclaration()->isUnique())
                {   arg->error("function %s is overloaded", arg->toChars());
                    err = true;
                }
            }
            arg->rvalue();
            arg = arg->optimize(WANTvalue);
        }
        (*arguments)[i] =  arg;
    }

    /* Remaining problems:
     * 1. order of evaluation - some function push L-to-R, others R-to-L. Until we resolve what array assignment does (which is
     *    implemented by calling a function) we'll defer this for now.
     * 2. value structs (or static arrays of them) that need to be copy constructed
     * 3. value structs (or static arrays of them) that have destructors, and subsequent arguments that may throw before the
     *    function gets called (functions normally destroy their parameters)
     * 2 and 3 are handled by doing the argument construction in 'eprefix' so that if a later argument throws, they are cleaned
     * up properly. Pushing arguments on the stack then cannot fail.
     */
    if (1)
    {
        /* Compute indices of first and last throwing argument.
         * Used to not set up destructors unless a throw can happen in a later argument.
         */
        bool anythrow = false;
        size_t firstthrow = ~0;
        size_t lastthrow = ~0;
        for (size_t i = 0; i < arguments->dim; ++i)
        {
            Expression *arg = (*arguments)[i];
            if (canThrow(arg, sc->func, false))
            {
                if (!anythrow)
                {
                    anythrow = true;
                    firstthrow = i;
                }
                lastthrow = i;
            }
        }

        bool appendToPrefix = false;
        VarDeclaration *gate = NULL;
        for (size_t i = 0; i < arguments->dim; ++i)
        {
            Expression *arg = (*arguments)[i];

            /* Skip reference parameters
             */
            if (i < nparams)
            {
                Parameter *p = Parameter::getNth(tf->parameters, i);
                if (p->storageClass & (STClazy | STCref | STCout))
                    continue;
            }

            TypeStruct *ts = NULL;
            Type *tv = arg->type->baseElemOf();
            if (tv->ty == Tstruct)
                ts = (TypeStruct *)tv;

            if (anythrow && i < lastthrow)      // if there are throws after this arg
            {
                if (ts && ts->sym->dtor)
                {
                    appendToPrefix = true;

                    // Need the gate because throws may occur after this arg is constructed
                    if (!gate)
                    {
                        Identifier *idtmp = Identifier::generateId("__gate");
                        gate = new VarDeclaration(loc, Type::tbool, idtmp, NULL);
                        gate->storage_class |= STCtemp | STCctfe | STCvolatile;
                        gate->semantic(sc);

                        Expression *ae = new DeclarationExp(loc, gate);
                        ae = ae->semantic(sc);
                        eprefix = Expression::combine(eprefix, ae);
                    }
                }
            }
            if (anythrow && i == lastthrow)
            {
                appendToPrefix = false;
            }
            if (appendToPrefix) // don't need to add to prefix until there's something to destruct
            {
                Identifier *idtmp = Identifier::generateId("__pfx");
                VarDeclaration *tmp = new VarDeclaration(loc, arg->type, idtmp, new ExpInitializer(loc, arg));
                tmp->storage_class |= STCtemp | STCctfe;
                tmp->semantic(sc);

                /* Modify the destructor so it only runs if gate==false
                 */
                if (tmp->edtor)
                {
                    Expression *e = tmp->edtor;
                    e = new OrOrExp(e->loc, new VarExp(e->loc, gate), e);       // (gate || destructor)
                    tmp->edtor = e->semantic(sc);
                    //printf("edtor: %s\n", tmp->edtor->toChars());
                }

                // auto __pfx = arg
                Expression *ae = new DeclarationExp(loc, tmp);
                ae = ae->semantic(sc);
                eprefix = Expression::combine(eprefix, ae);

                arg = new VarExp(loc, tmp);
                arg = arg->semantic(sc);
            }
            else if (ts)
            {
                arg = arg->isLvalue() ? callCpCtor(sc, arg) : valueNoDtor(arg);
            }
            else if (anythrow && firstthrow <= i && i <= lastthrow && gate)
            {
                Identifier *id = Identifier::generateId("__pfy");
                VarDeclaration *tmp = new VarDeclaration(loc, arg->type, id, new ExpInitializer(loc, arg));
                tmp->storage_class |= STCtemp | STCctfe;
                tmp->semantic(sc);

                Expression *ae = new DeclarationExp(loc, tmp);
                ae = ae->semantic(sc);
                eprefix = Expression::combine(eprefix, ae);

                arg = new VarExp(loc, tmp);
                arg = arg->semantic(sc);
            }

            if (anythrow && i == lastthrow)
            {
                /* Set gate to true after prefix runs
                 */
                if (eprefix)
                {
                    assert(gate);
                    // (gate = true)
                    Expression *e = new AssignExp(gate->loc, new VarExp(gate->loc, gate), new IntegerExp(gate->loc, 1, Type::tbool));
                    e = e->semantic(sc);
                    eprefix = Expression::combine(eprefix, e);
                    gate = NULL;
                }
            }
            (*arguments)[i] = arg;
        }
    }
    //if (eprefix) printf("eprefix: %s\n", eprefix->toChars());

    // If D linkage and variadic, add _arguments[] as first argument
    if (tf->linkage == LINKd && tf->varargs == 1)
    {
        assert(arguments->dim >= nparams);
        Expression *e = createTypeInfoArray(sc, (Expression **)&arguments->tdata()[nparams],
                arguments->dim - nparams);
        arguments->insert(0, e);
    }

    Type *tret = tf->next;
    if (isCtorCall)
    {
        //printf("[%s] fd = %s %s, %d %d %d\n", loc.toChars(), fd->toChars(), fd->type->toChars(),
        //    wildmatch, tf->isWild(), fd->isolateReturn());
        if (!tthis)
        {   assert(sc->intypeof || global.errors);
            tthis = fd->isThis()->type->addMod(fd->type->mod);
        }
        if (tf->isWild() && !fd->isolateReturn())
        {
            if (wildmatch)
                tret = tret->substWildTo(wildmatch);
            if (!tret->implicitConvTo(tthis))
            {
                const char* s1 = tret ->isNaked() ? " mutable" : tret ->modToChars();
                const char* s2 = tthis->isNaked() ? " mutable" : tthis->modToChars();
                ::error(loc, "inout constructor %s creates%s object, not%s",
                        fd->toPrettyChars(), s1, s2);
                err = true;
            }
        }
        tret = tthis;
    }
    else if (wildmatch)
    {   /* Adjust function return type based on wildmatch
         */
        //printf("wildmatch = x%x, tret = %s\n", wildmatch, tret->toChars());
        tret = tret->substWildTo(wildmatch);
    }
    *prettype = tret;
    *peprefix = eprefix;
    return (err || olderrors != global.errors);
}

/******************************** Expression **************************/

Expression::Expression(Loc loc, TOK op, int size)
{
    //printf("Expression::Expression(op = %d) this = %p\n", op, this);
    this->loc = loc;
    this->op = op;
    this->size = (unsigned char)size;
    this->parens = 0;
    type = NULL;
}

void Expression::init()
{
    CTFEExp::cantexp = new CTFEExp(TOKcantexp);
    CTFEExp::voidexp = new CTFEExp(TOKvoidexp);
    CTFEExp::breakexp = new CTFEExp(TOKbreak);
    CTFEExp::continueexp = new CTFEExp(TOKcontinue);
    CTFEExp::gotoexp = new CTFEExp(TOKgoto);
}

Expression *Expression::syntaxCopy()
{
    //printf("Expression::syntaxCopy()\n");
    //print();
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
        fprintf(stderr, "No expression copy for: %s\n", toChars());
        printf("op = %d\n", op);
        print();
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
    fprintf(stderr, "%s\n", toChars());
    fflush(stderr);
}

char *Expression::toChars()
{
    OutBuffer buf;
    HdrGenState hgs;
    toCBuffer(this, &buf, &hgs);
    return buf.extractString();
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

bool Expression::rvalue()
{
    if (type && type->toBasetype()->ty == Tvoid)
    {
        error("expression %s is void and has no value", toChars());
#if 0
        print();
        halt();
#endif
        if (!global.gag)
            type = Type::terror;
        return false;
    }
    return true;
}

/**********************************
 * Combine e1 and e2 by CommaExp if both are not NULL.
 */
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

/**********************************
 * If 'e' is a tree of commas, returns the leftmost expression
 * by stripping off it from the tree. The remained part of the tree
 * is returned via *pe0.
 * Otherwise 'e' is directly returned and *pe0 is set to NULL.
 */
Expression *Expression::extractLast(Expression *e, Expression **pe0)
{
    if (e->op != TOKcomma)
    {
        *pe0 = NULL;
        return e;
    }

    CommaExp *ce = (CommaExp *)e;
    if (ce->e2->op != TOKcomma)
    {
        *pe0 = ce->e1;
        return ce->e2;
    }
    else
    {
        *pe0 = e;

        Expression **pce = &ce->e2;
        while (((CommaExp *)(*pce))->e2->op == TOKcomma)
        {
            pce = &((CommaExp *)(*pce))->e2;
        }
        assert((*pce)->op == TOKcomma);
        ce = (CommaExp *)(*pce);
        *pce = ce->e1;

        return ce->e2;
    }
}

dinteger_t Expression::toInteger()
{
    //printf("Expression %s\n", Token::toChars(op));
    error("integer constant expression expected instead of %s", toChars());
    return 0;
}

uinteger_t Expression::toUInteger()
{
    //printf("Expression %s\n", Token::toChars(op));
    return (uinteger_t)toInteger();
}

real_t Expression::toReal()
{
    error("floating point constant expression expected instead of %s", toChars());
    return ldouble(0);
}

real_t Expression::toImaginary()
{
    error("floating point constant expression expected instead of %s", toChars());
    return ldouble(0);
}

complex_t Expression::toComplex()
{
    error("floating point constant expression expected instead of %s", toChars());
    return (complex_t)0.0;
}

StringExp *Expression::toStringExp()
{
    return NULL;
}

/***************************************
 * Return !=0 if expression is an lvalue.
 */

bool Expression::isLvalue()
{
    return false;
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

    if (e->op == TOKtype)
        error("%s '%s' is a type, not an lvalue", e->type->kind(), e->type->toChars());
    else
        error("%s is not an lvalue", e->toChars());

    return new ErrorExp();
}

/***************************************
 * Parameters:
 *      sc:     scope
 *      flag:   1: do not issue error message for invalid modification
 * Returns:
 *      0:      is not modifiable
 *      1:      is modifiable in default == being related to type->isMutable()
 *      2:      is modifiable, because this is a part of initializing.
 */

int Expression::checkModifiable(Scope *sc, int flag)
{
    return type ? 1 : 0;    // default modifiable
}

Expression *Expression::modifiableLvalue(Scope *sc, Expression *e)
{
    //printf("Expression::modifiableLvalue() %s, type = %s\n", toChars(), type->toChars());

    // See if this expression is a modifiable lvalue (i.e. not const)
    if (checkModifiable(sc) == 1)
    {
        assert(type);
        if (!type->isMutable())
        {
            error("cannot modify %s expression %s", MODtoChars(type->mod), toChars());
            return new ErrorExp();
        }
        else if (!type->isAssignable())
        {
            error("cannot modify struct %s %s with immutable members", toChars(), type->toChars());
            return new ErrorExp();
        }
    }
    return toLvalue(sc, e);
}

/*******************************
 * Check whether the expression allows RMW operations, error with rmw operator diagnostic if not.
 * exp is the RHS expression, or NULL if ++/-- is used (for diagnostics)
 */
Expression *Expression::checkReadModifyWrite(TOK rmwOp, Expression *ex)
{
    //printf("Expression::checkReadModifyWrite() %s %s", toChars(), ex ? ex->toChars() : "");
    if (!type || !type->isShared())
        return NULL;

    // atomicOp uses opAssign (+=/-=) rather than opOp (++/--) for the CT string literal.
    switch (rmwOp)
    {
        case TOKplusplus:
        case TOKpreplusplus:
            rmwOp = TOKaddass;
            break;

        case TOKminusminus:
        case TOKpreminusminus:
            rmwOp = TOKminass;
            break;

        default:
            break;
    }

    deprecation("read-modify-write operations are not allowed for shared variables. "
                "Use core.atomic.atomicOp!\"%s\"(%s, %s) instead.",
                Token::tochars[rmwOp], toChars(), ex ? ex->toChars() : "1");
    return NULL;

    // note: enable when deprecation becomes an error.
    // return new ErrorExp();
}

void Expression::checkScalar()
{
    if (!type->isscalar() && type->toBasetype() != Type::terror)
        error("'%s' is not a scalar, it is a %s", toChars(), type->toChars());
    rvalue();
}

void Expression::checkNoBool()
{
    if (type->toBasetype()->ty == Tbool)
        error("operation not allowed on bool '%s'", toChars());
}

Expression *Expression::checkIntegral()
{
    if (!type->isintegral())
    {   if (type->toBasetype() != Type::terror)
            error("'%s' is not of integral type, it is a %s", toChars(), type->toChars());
        return new ErrorExp();
    }
    if (!rvalue())
        return new ErrorExp();
    return this;
}

Expression *Expression::checkArithmetic()
{
    if (!type->isintegral() && !type->isfloating())
    {   if (type->toBasetype() != Type::terror)
            error("'%s' is not of arithmetic type, it is a %s", toChars(), type->toChars());
        return new ErrorExp();
    }
    if (!rvalue())
        return new ErrorExp();
    return this;
}

void Expression::checkDeprecated(Scope *sc, Dsymbol *s)
{
    s->checkDeprecated(loc, sc);
}

/*********************************************
 * Calling function f.
 * Check the purity, i.e. if we're in a pure function
 * we can only call other pure functions.
 */
void Expression::checkPurity(Scope *sc, FuncDeclaration *f)
{
    if (!sc->func)
        return;
    if (sc->func == f)
        return;
    if (sc->intypeof == 1)
        return;
    if (sc->flags & (SCOPEctfe | SCOPEdebug))
        return;

    /* Given:
     * void f() {
     *   pure void g() {
     *     /+pure+/ void h() {
     *       /+pure+/ void i() { }
     *     }
     *   }
     * }
     * g() can call h() but not f()
     * i() can call h() and g() but not f()
     */

    // Find the closest pure parent of the calling function
    FuncDeclaration *outerfunc = sc->func;
    FuncDeclaration *calledparent = f;

    if (outerfunc->isInstantiated())
    {
        // The attributes of outerfunc should be inferred from the call of f.
    }
    else if (f->isFuncLiteralDeclaration())
    {
        // The attributes of f is always inferred in its declared place.
    }
    else
    {
        /* Today, static local functions are impure by default, but they cannot
         * violate purity of enclosing functions.
         *
         *  auto foo() pure {      // non instantiated funciton
         *    static auto bar() {  // static, without pure attribute
         *      impureFunc();      // impure call
         *      // Although impureFunc is called inside bar, f(= impureFunc)
         *      // is not callable inside pure outerfunc(= foo <- bar).
         *    }
         *
         *    bar();
         *    // Although bar is called inside foo, f(= bar) is callable
         *    // bacause calledparent(= foo) is same with outerfunc(= foo).
         *  }
         */

        while (outerfunc->toParent2() &&
               outerfunc->isPureBypassingInference() == PUREimpure &&
               outerfunc->toParent2()->isFuncDeclaration())
        {
            outerfunc = outerfunc->toParent2()->isFuncDeclaration();
            if (outerfunc->type->ty == Terror)
                return;
        }
        while (calledparent->toParent2() &&
               calledparent->isPureBypassingInference() == PUREimpure &&
               calledparent->toParent2()->isFuncDeclaration())
        {
            calledparent = calledparent->toParent2()->isFuncDeclaration();
            if (calledparent->type->ty == Terror)
                return;
        }
    }

    // If the caller has a pure parent, then either the called func must be pure,
    // OR, they must have the same pure parent.
    if (!f->isPure() && calledparent != outerfunc)
    {
        FuncDeclaration *ff = outerfunc;
        if (sc->flags & SCOPEcompile ? ff->isPureBypassingInference() >= PUREweak : ff->setImpure())
        {
            error("pure function '%s' cannot call impure function '%s'",
                ff->toPrettyChars(), f->toPrettyChars());
        }
    }
}

/*******************************************
 * Accessing variable v.
 * Check for purity and safety violations.
 */

void Expression::checkPurity(Scope *sc, VarDeclaration *v)
{
    /* Look for purity and safety violations when accessing variable v
     * from current function.
     */
    if (!sc->func)
        return;
    if (sc->intypeof == 1)
        return; // allow violations inside typeof(expression)
    if (sc->flags & (SCOPEctfe | SCOPEdebug))
        return; // allow violations inside compile-time evaluated expressions and debug conditionals
    if (v->ident == Id::ctfe)
        return; // magic variable never violates pure and safe
    if (v->isImmutable())
        return; // always safe and pure to access immutables...
    if (v->isConst() && !v->isRef() && (v->isDataseg() || v->isParameter()) &&
        v->type->implicitConvTo(v->type->immutableOf()))
        return; // or const global/parameter values which have no mutable indirections
    if (v->storage_class & STCmanifest)
        return; // ...or manifest constants

    if (v->isDataseg())
    {
        // Bugzilla 7533: Accessing implicit generated __gate is pure.
        if (v->ident == Id::gate)
            return;

        /* Accessing global mutable state.
         * Therefore, this function and all its immediately enclosing
         * functions must be pure.
         */
        FuncDeclaration *ff = sc->func;
        if (sc->flags & SCOPEcompile ? ff->isPureBypassingInference() >= PUREweak : ff->setImpure())
        {
            error("pure function '%s' cannot access mutable static data '%s'",
                ff->toPrettyChars(), v->toChars());
        }
    }
    else
    {
        /* Given:
         * void f() {
         *   int fx;
         *   pure void g() {
         *     int gx;
         *     /+pure+/ void h() {
         *       int hx;
         *       /+pure+/ void i() { }
         *     }
         *   }
         * }
         * i() can modify hx and gx but not fx
         */

        Dsymbol *vparent = v->toParent2();
        if (FuncDeclaration *fdp = vparent->isFuncDeclaration())
        {
            if (!sc->func->isPureBypassingInference() && fdp->setImpure())
            {
                error("impure function '%s' cannot access variable '%s' declared in enclosing pure function '%s'",
                    sc->func->toChars(), v->toChars(), fdp->toPrettyChars());
            }
        }
        for (Dsymbol *s = sc->func; s; s = s->toParent2())
        {
            if (s == vparent)
                break;

            if (AggregateDeclaration *ad = s->isAggregateDeclaration())
            {
                if (ad->isNested())
                    continue;
                break;
            }
            FuncDeclaration *ff = s->isFuncDeclaration();
            if (!ff)
                break;
            if (ff->isNested())
            {
                if (ff->type->isImmutable())
                {
                    error("pure immutable nested function '%s' cannot access mutable data '%s'",
                        ff->toPrettyChars(), v->toChars());
                    break;
                }
                continue;
            }
            if (ff->isThis())
            {
                if (ff->type->isImmutable())
                {
                    error("pure immutable member function '%s' cannot access mutable data '%s'",
                        ff->toPrettyChars(), v->toChars());
                    break;
                }
                continue;
            }
            break;
        }
    }

    /* Do not allow safe functions to access __gshared data
     */
    if (v->storage_class & STCgshared)
    {
        if (sc->func->setUnsafe())
            error("safe function '%s' cannot access __gshared data '%s'",
                sc->func->toChars(), v->toChars());
    }
}

void Expression::checkSafety(Scope *sc, FuncDeclaration *f)
{
    if (!sc->func)
        return;
    if (sc->func == f)
        return;
    if (sc->intypeof == 1)
        return;
    if (sc->flags & SCOPEctfe)
        return;

    if (!f->isSafe() && !f->isTrusted())
    {
        if (sc->flags & SCOPEcompile ? sc->func->isSafeBypassingInference() : sc->func->setUnsafe())
        {
            if (loc.linnum == 0)  // e.g. implicitly generated dtor
                loc = sc->func->loc;

            error("safe function '%s' cannot call system function '%s'",
                sc->func->toPrettyChars(), f->toPrettyChars());
        }
    }
}

void Expression::checkNogc(Scope *sc, FuncDeclaration *f)
{
    if (!sc->func)
        return;
    if (sc->func == f)
        return;
    if (sc->intypeof == 1)
        return;
    if (sc->flags & SCOPEctfe)
        return;

    if (!f->isNogc())
    {
        if (sc->flags & SCOPEcompile ? sc->func->isNogcBypassingInference() : sc->func->setGC())
        {
            if (loc.linnum == 0)  // e.g. implicitly generated dtor
                loc = sc->func->loc;

            error("@nogc function '%s' cannot call non-@nogc function '%s'",
                sc->func->toPrettyChars(), f->toPrettyChars());
        }
    }
}

/*****************************
 * Check that expression can be tested for true or false.
 */

Expression *Expression::checkToBoolean(Scope *sc)
{
    // Default is 'yes' - do nothing

#ifdef DEBUG
    if (!type)
        print();
    assert(type);
#endif

    Expression *e = this;
    Type *t = type;
    Type *tb = type->toBasetype();
    Type *att = NULL;
Lagain:
    // Structs can be converted to bool using opCast(bool)()
    if (tb->ty == Tstruct)
    {
        AggregateDeclaration *ad = ((TypeStruct *)tb)->sym;
        /* Don't really need to check for opCast first, but by doing so we
         * get better error messages if it isn't there.
         */
        Dsymbol *fd = search_function(ad, Id::cast);
        if (fd)
        {
            e = new CastExp(loc, e, Type::tbool);
            e = e->semantic(sc);
            return e;
        }

        // Forward to aliasthis.
        if (ad->aliasthis && tb != att)
        {
            if (!att && tb->checkAliasThisRec())
                att = tb;
            e = resolveAliasThis(sc, e);
            t = e->type;
            tb = e->type->toBasetype();
            goto Lagain;
        }
    }

    if (!t->checkBoolean())
    {
        if (tb != Type::terror)
            error("expression %s of type %s does not have a boolean value", toChars(), t->toChars());
        return new ErrorExp();
    }
    return e;
}

/******************************
 * Take address of expression.
 */

Expression *Expression::addressOf()
{
    //printf("Expression::addressOf()\n");
#ifdef DEBUG
    assert(op == TOKerror || isLvalue());
#endif
    Expression *e = new AddrExp(loc, this);
    e->type = type->pointerTo();
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
 * Does this expression statically evaluate to a boolean 'result' (true or false)?
 */
bool Expression::isBool(bool result)
{
    return false;
}

/****************************************
 * Resolve __FILE__, __LINE__, __MODULE__, __FUNCTION__, __PRETTY_FUNCTION__ to loc.
 */

Expression *Expression::resolveLoc(Loc loc, Scope *sc)
{
    return this;
}

Expressions *Expression::arraySyntaxCopy(Expressions *exps)
{
    Expressions *a = NULL;
    if (exps)
    {
        a = new Expressions();
        a->setDim(exps->dim);
        for (size_t i = 0; i < a->dim; i++)
        {
            Expression *e = (*exps)[i];
            (*a)[i] = e ? e->syntaxCopy() : NULL;
        }
    }
    return a;
}

/************************************************
 * Destructors are attached to VarDeclarations.
 * Hence, if expression returns a temp that needs a destructor,
 * make sure and create a VarDeclaration for that temp.
 */

Expression *Expression::addDtorHook(Scope *sc)
{
    return this;
}

/******************************** IntegerExp **************************/

IntegerExp::IntegerExp(Loc loc, dinteger_t value, Type *type)
        : Expression(loc, TOKint64, sizeof(IntegerExp))
{
    //printf("IntegerExp(value = %lld, type = '%s')\n", value, type ? type->toChars() : "");
    assert(type);
    if (!type->isscalar())
    {
        //printf("%s, loc = %d\n", toChars(), loc.linnum);
        if (type->ty != Terror)
            error("integral constant must be scalar type, not %s", type->toChars());
        type = Type::terror;
    }
    this->type = type;
    setInteger(value);
}

IntegerExp::IntegerExp(dinteger_t value)
        : Expression(Loc(), TOKint64, sizeof(IntegerExp))
{
    this->type = Type::tint32;
    this->value = (d_int32) value;
}

bool IntegerExp::equals(RootObject *o)
{
    if (this == o)
        return true;
    if (((Expression *)o)->op == TOKint64)
    {
        IntegerExp *ne = (IntegerExp *)o;
        if (type->toHeadMutable()->equals(ne->type->toHeadMutable()) &&
            value == ne->value)
        {
            return true;
        }
    }
    return false;
}

void IntegerExp::setInteger(dinteger_t value)
{
    this->value = value;
    normalize();
}

void IntegerExp::normalize()
{
    /* 'Normalize' the value of the integer to be in range of the type
     */
    switch (type->toBasetype()->ty)
    {
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
        default:
            break;
    }
}

dinteger_t IntegerExp::toInteger()
{
    normalize();   // necessary until we fix all the paints of 'type'
    return value;
}

real_t IntegerExp::toReal()
{
    normalize();   // necessary until we fix all the paints of 'type'
    Type *t = type->toBasetype();
    if (t->ty == Tuns64)
        return ldouble((d_uns64)value);
    else
        return ldouble((d_int64)value);
}

real_t IntegerExp::toImaginary()
{
    return ldouble(0);
}

complex_t IntegerExp::toComplex()
{
    return (complex_t)toReal();
}

bool IntegerExp::isBool(bool result)
{
    bool r = toInteger() != 0;
    return result ? r : !r;
}

Expression *IntegerExp::semantic(Scope *sc)
{
    assert(type);
    if (type->ty == Terror)
        return new ErrorExp();
    assert(type->deco);
    normalize();
    return this;
}

Expression *IntegerExp::toLvalue(Scope *sc, Expression *e)
{
    if (!e)
        e = this;
    else if (!loc.filename)
        loc = e->loc;
    e->error("constant %s is not an lvalue", e->toChars());
    return new ErrorExp();
}

/******************************** ErrorExp **************************/

/* Use this expression for error recovery.
 * It should behave as a 'sink' to prevent further cascaded error messages.
 */

ErrorExp::ErrorExp()
    : Expression(Loc(), TOKerror, sizeof(ErrorExp))
{
    type = Type::terror;
}

Expression *ErrorExp::toLvalue(Scope *sc, Expression *e)
{
    return this;
}

/******************************** RealExp **************************/

RealExp::RealExp(Loc loc, real_t value, Type *type)
        : Expression(loc, TOKfloat64, sizeof(RealExp))
{
    //printf("RealExp::RealExp(%Lg)\n", value);
    this->value = value;
    this->type = type;
}

dinteger_t RealExp::toInteger()
{
    return (sinteger_t) toReal();
}

uinteger_t RealExp::toUInteger()
{
    return (uinteger_t) toReal();
}

real_t RealExp::toReal()
{
    return type->isreal() ? value : ldouble(0);
}

real_t RealExp::toImaginary()
{
    return type->isreal() ? ldouble(0) : value;
}

complex_t RealExp::toComplex()
{
    return complex_t(toReal(), toImaginary());
}

/********************************
 * Test to see if two reals are the same.
 * Regard NaN's as equivalent.
 * Regard +0 and -0 as different.
 */

int RealEquals(real_t x1, real_t x2)
{
    return (Port::isNan(x1) && Port::isNan(x2)) ||
        Port::fequal(x1, x2);
}

bool RealExp::equals(RootObject *o)
{
    if (this == o)
        return true;
    if (((Expression *)o)->op == TOKfloat64)
    {
        RealExp *ne = (RealExp *)o;
        if (type->toHeadMutable()->equals(ne->type->toHeadMutable()) &&
            RealEquals(value, ne->value))
        {
            return true;
        }
    }
    return false;
}

Expression *RealExp::semantic(Scope *sc)
{
    if (!type)
        type = Type::tfloat64;
    else
        type = type->semantic(loc, sc);
    return this;
}

bool RealExp::isBool(bool result)
{
    return result ? (value != 0)
                  : (value == 0);
}

/******************************** ComplexExp **************************/

ComplexExp::ComplexExp(Loc loc, complex_t value, Type *type)
        : Expression(loc, TOKcomplex80, sizeof(ComplexExp))
{
    this->value = value;
    this->type = type;
    //printf("ComplexExp::ComplexExp(%s)\n", toChars());
}

dinteger_t ComplexExp::toInteger()
{
    return (sinteger_t) toReal();
}

uinteger_t ComplexExp::toUInteger()
{
    return (uinteger_t) toReal();
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

bool ComplexExp::equals(RootObject *o)
{
    if (this == o)
        return true;
    if (((Expression *)o)->op == TOKcomplex80)
    {
        ComplexExp *ne = (ComplexExp *)o;
        if (type->toHeadMutable()->equals(ne->type->toHeadMutable()) &&
            RealEquals(creall(value), creall(ne->value)) &&
            RealEquals(cimagl(value), cimagl(ne->value)))
        {
            return true;
        }
    }
    return false;
}

Expression *ComplexExp::semantic(Scope *sc)
{
    if (!type)
        type = Type::tcomplex80;
    else
        type = type->semantic(loc, sc);
    return this;
}

bool ComplexExp::isBool(bool result)
{
    if (result)
        return (bool)(value);
    else
        return !value;
}

/******************************** IdentifierExp **************************/

IdentifierExp::IdentifierExp(Loc loc, Identifier *ident)
        : Expression(loc, TOKidentifier, sizeof(IdentifierExp))
{
    this->ident = ident;
}

IdentifierExp *IdentifierExp::create(Loc loc, Identifier *ident)
{
    return new IdentifierExp(loc, ident);
}

Expression *IdentifierExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("IdentifierExp::semantic('%s')\n", ident->toChars());
#endif
    if (type)   // This is used as the dummy expression
        return this;

    Dsymbol *scopesym;
    Dsymbol *s = sc->search(loc, ident, &scopesym);
    if (s)
    {
        if (s->errors)
            return new ErrorExp();

        Expression *e;

        /* See if the symbol was a member of an enclosing 'with'
         */
        WithScopeSymbol *withsym = scopesym->isWithScopeSymbol();
        if (withsym && withsym->withstate->wthis)
        {
            /* Disallow shadowing
             */
            // First find the scope of the with
            Scope *scwith = sc;
            while (scwith->scopesym != scopesym)
            {
                scwith = scwith->enclosing;
                assert(scwith);
            }
            // Look at enclosing scopes for symbols with the same name,
            // in the same function
            for (Scope *scx = scwith; scx && scx->func == scwith->func; scx = scx->enclosing)
            {
                Dsymbol *s2;
                if (scx->scopesym && scx->scopesym->symtab &&
                    (s2 = scx->scopesym->symtab->lookup(s->ident)) != NULL &&
                    s != s2)
                {
                    error("with symbol %s is shadowing local symbol %s", s->toPrettyChars(), s2->toPrettyChars());
                    return new ErrorExp();
                }
            }
            s = s->toAlias();

            // Same as wthis.ident
            if (s->needThis() || s->isTemplateDeclaration())
            {
                e = new VarExp(loc, withsym->withstate->wthis);
                e = new DotIdExp(loc, e, ident);
            }
            else
            {
                Type *t = withsym->withstate->wthis->type;
                if (t->ty == Tpointer)
                    t = ((TypePointer *)t)->next;
                e = typeDotIdExp(loc, t, ident);
            }
        }
        else
        {
            if (withsym)
            {
                Declaration *d = s->isDeclaration();
                if (d)
                    accessCheck(loc, sc, NULL, d);
            }

            /* If f is really a function template,
             * then replace f with the function template declaration.
             */
            FuncDeclaration *f = s->isFuncDeclaration();
            if (f)
            {
                TemplateDeclaration *td = getFuncTemplateDecl(f);
                if (td)
                {
                    if (td->overroot)       // if not start of overloaded list of TemplateDeclaration's
                        td = td->overroot;  // then get the start
                    e = new TemplateExp(loc, td, f);
                    e = e->semantic(sc);
                    return e;
                }
            }
            // Haven't done overload resolution yet, so pass 1
            e = new DsymbolExp(loc, s, 1);
        }
        return e->semantic(sc);
    }

    if (hasThis(sc))
    {
        AggregateDeclaration *ad = sc->getStructClassScope();
        if (ad && ad->aliasthis)
        {
            Expression *e;
            e = new IdentifierExp(loc, Id::This);
            e = new DotIdExp(loc, e, ad->aliasthis->ident);
            e = new DotIdExp(loc, e, ident);
            e = e->trySemantic(sc);
            if (e)
                return e;
        }
    }

    if (ident == Id::ctfe)
    {
        if (sc->flags & SCOPEctfe)
        {
            error("variable __ctfe cannot be read at compile time");
            return new ErrorExp();
        }

        // Create the magic __ctfe bool variable
        VarDeclaration *vd = new VarDeclaration(loc, Type::tbool, Id::ctfe, NULL);
        vd->storage_class |= STCtemp;
        Expression *e = new VarExp(loc, vd);
        e = e->semantic(sc);
        return e;
    }

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

bool IdentifierExp::isLvalue()
{
    return true;
}

Expression *IdentifierExp::toLvalue(Scope *sc, Expression *e)
{
    return this;
}

/******************************** DollarExp **************************/

DollarExp::DollarExp(Loc loc)
        : IdentifierExp(loc, Id::dollar)
{
}

/******************************** DsymbolExp **************************/

DsymbolExp::DsymbolExp(Loc loc, Dsymbol *s, bool hasOverloads)
        : Expression(loc, TOKdsymbol, sizeof(DsymbolExp))
{
    this->s = s;
    this->hasOverloads = hasOverloads;
}

Expression *DsymbolExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("DsymbolExp::semantic(%s %s)\n", s->kind(), s->toChars());
#endif

Lagain:
    Expression *e;

    //printf("DsymbolExp:: %p '%s' is a symbol\n", this, toChars());
    //printf("s = '%s', s->kind = '%s'\n", s->toChars(), s->kind());
    if (!s->isFuncDeclaration())        // functions are checked after overloading
        checkDeprecated(sc, s);
    Dsymbol *olds = s;
    s = s->toAlias();
    //printf("s = '%s', s->kind = '%s', s->needThis() = %p\n", s->toChars(), s->kind(), s->needThis());
    if (s != olds && !s->isFuncDeclaration())
        checkDeprecated(sc, s);

    if (VarDeclaration *v = s->isVarDeclaration())
    {
        /* Bugzilla 12023: forward reference should be resolved
         * before 's->needThis()' is called.
         */
        if ((!v->type || !v->type->deco) && v->scope)
        {
            v->semantic(v->scope);
            s = v->toAlias();   // Need this if 'v' is a tuple variable
        }
    }
    if (s->needThis() && hasThis(sc))
    {
        // For functions, this should happen after overload resolution
        if (!s->isFuncDeclaration())
        {
            // Supply an implicit 'this', as in
            //    this.ident
            DotVarExp *de = new DotVarExp(loc, new ThisExp(loc), s->isDeclaration());
            return de->semantic(sc);
        }
    }

    if (EnumMember *em = s->isEnumMember())
    {
        return em->getVarExp(loc, sc);
    }
    if (VarDeclaration *v = s->isVarDeclaration())
    {
        //printf("Identifier '%s' is a variable, type '%s'\n", toChars(), v->type->toChars());
        if (!type)
        {
            type = v->type;
            if (!v->type)
            {
                error("forward reference of %s %s", s->kind(), s->toChars());
                return new ErrorExp();
            }
        }
        if ((v->storage_class & STCmanifest) && v->init)
        {
            if (v->scope)
            {
                v->inuse++;
                v->init = v->init->semantic(v->scope, v->type, INITinterpret);
                v->scope = NULL;
                v->inuse--;
            }
            e = v->init->toExpression(v->type);
            if (!e)
            {
                error("cannot make expression out of initializer for %s", v->toChars());
                return new ErrorExp();
            }
            e = e->copy();
            e->loc = loc;   // for better error message

            // Detect recursive initializers.
            // BUG: The check for speculative gagging is not correct
            if (v->inuse && !global.gag)
            {
                e->error("circular initialization of %s", v->toChars());
                return new ErrorExp();
            }
            e = e->semantic(sc);
            return e;
        }

        e = new VarExp(loc, v);
        e->type = type;
        e = e->semantic(sc);
        return e->deref();
    }
    if (FuncLiteralDeclaration *fld = s->isFuncLiteralDeclaration())
    {
        //printf("'%s' is a function literal\n", fld->toChars());
        e = new FuncExp(loc, fld);
        return e->semantic(sc);
    }
    if (FuncDeclaration *f = s->isFuncDeclaration())
    {
        f = f->toAliasFunc();
        if (!f->functionSemantic())
            return new ErrorExp();

        if (!f->type->deco)
        {
            const char *trailMsg = f->inferRetType ? "inferred return type of function call " : "";
            error("forward reference to %s'%s'", trailMsg, toChars());
            return new ErrorExp();
        }
        FuncDeclaration *fd = s->isFuncDeclaration();
        fd->type = f->type;
        return new VarExp(loc, fd, hasOverloads);
    }
    if (OverloadSet *o = s->isOverloadSet())
    {
        //printf("'%s' is an overload set\n", o->toChars());
        return new OverExp(loc, o);
    }

    if (Import *imp = s->isImport())
    {
        if (!imp->pkg)
        {
            error("forward reference of import %s", imp->toChars());
            return new ErrorExp();
        }
        ScopeExp *ie = new ScopeExp(loc, imp->pkg);
        return ie->semantic(sc);
    }
    if (Package *pkg = s->isPackage())
    {
        ScopeExp *ie = new ScopeExp(loc, pkg);
        return ie->semantic(sc);
    }
    if (Module *mod = s->isModule())
    {
        ScopeExp *ie = new ScopeExp(loc, mod);
        return ie->semantic(sc);
    }

    if (Nspace *ns = s->isNspace())
    {
        ScopeExp *ie = new ScopeExp(loc, ns);
        return ie->semantic(sc);
    }

    if (Type *t = s->getType())
    {
        TypeExp *te = new TypeExp(loc, t);
        return te->semantic(sc);
    }

    if (TupleDeclaration *tup = s->isTupleDeclaration())
    {
        e = new TupleExp(loc, tup);
        e = e->semantic(sc);
        return e;
    }

    if (TemplateInstance *ti = s->isTemplateInstance())
    {
        ti->semantic(sc);
        if (!ti->inst || ti->errors)
            return new ErrorExp();
        s = ti->toAlias();
        if (!s->isTemplateInstance())
            goto Lagain;
        e = new ScopeExp(loc, ti);
        e = e->semantic(sc);
        return e;
    }
    if (TemplateDeclaration *td = s->isTemplateDeclaration())
    {
        Dsymbol *p = td->toParent2();
        FuncDeclaration *fdthis = hasThis(sc);
        AggregateDeclaration *ad = p ? p->isAggregateDeclaration() : NULL;
        if (fdthis && ad && isAggregate(fdthis->vthis->type) == ad &&
            (td->scope->stc & STCstatic) == 0)
        {
            e = new DotTemplateExp(loc, new ThisExp(loc), td);
        }
        else
            e = new TemplateExp(loc, td);
        e = e->semantic(sc);
        return e;
    }

    error("%s '%s' is not a variable", s->kind(), s->toChars());
    return new ErrorExp();
}

bool DsymbolExp::isLvalue()
{
    return true;
}

Expression *DsymbolExp::toLvalue(Scope *sc, Expression *e)
{
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
        return this;

    FuncDeclaration *fd = hasThis(sc);  // fd is the uplevel function with the 'this' variable

    /* Special case for typeof(this) and typeof(super) since both
     * should work even if they are not inside a non-static member function
     */
    if (!fd && sc->intypeof == 1)
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
                type = sd->type;
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
    if (!var->isVarDeclaration()->checkNestedReference(sc, loc))
        return new ErrorExp();
    if (!sc->intypeof)
        sc->callSuper |= CSXthis;
    return this;

Lerr:
    error("'this' is only defined in non-static member functions, not %s", sc->parent->toChars());
    return new ErrorExp();
}

bool ThisExp::isBool(bool result)
{
    return result ? true : false;
}

bool ThisExp::isLvalue()
{
    // Class `this` is an rvalue; struct `this` is an lvalue.
    return (type->toBasetype()->ty != Tclass);
}

Expression *ThisExp::toLvalue(Scope *sc, Expression *e)
{
    if (type->toBasetype()->ty == Tclass)
    {
        // Class `this` is an rvalue; struct `this` is an lvalue.
        return Expression::toLvalue(sc, e);
    }
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
#if LOGSEMANTIC
    printf("SuperExp::semantic('%s')\n", toChars());
#endif
    if (type)
        return this;

    FuncDeclaration *fd = hasThis(sc);
    ClassDeclaration *cd;
    Dsymbol *s;

    /* Special case for typeof(this) and typeof(super) since both
     * should work even if they are not inside a non-static member function
     */
    if (!fd && sc->intypeof == 1)
    {
        // Find enclosing class
        for (s = sc->getStructClassScope(); 1; s = s->parent)
        {
            if (!s)
            {
                error("%s is not in a class scope", toChars());
                goto Lerr;
            }
            cd = s->isClassDeclaration();
            if (cd)
            {
                cd = cd->baseClass;
                if (!cd)
                {
                    error("class %s has no 'super'", s->toChars());
                    goto Lerr;
                }
                type = cd->type;
                return this;
            }
        }
    }
    if (!fd)
        goto Lerr;

    var = fd->vthis;
    assert(var && var->parent);

    s = fd->toParent();
    while (s && s->isTemplateInstance())
        s = s->toParent();
    if (s->isTemplateDeclaration()) // allow inside template constraint
        s = s->toParent();
    assert(s);
    cd = s->isClassDeclaration();
//printf("parent is %s %s\n", fd->toParent()->kind(), fd->toParent()->toChars());
    if (!cd)
        goto Lerr;
    if (!cd->baseClass)
    {
        error("no base class for %s", cd->toChars());
        type = var->type;
    }
    else
    {
        type = cd->baseClass->type;
        type = type->castMod(var->type->mod);
    }

    if (!var->isVarDeclaration()->checkNestedReference(sc, loc))
        return new ErrorExp();

    if (!sc->intypeof)
        sc->callSuper |= CSXsuper;
    return this;

Lerr:
    error("'super' is only allowed in non-static class member functions");
    return new ErrorExp();
}

/******************************** NullExp **************************/

NullExp::NullExp(Loc loc, Type *type)
        : Expression(loc, TOKnull, sizeof(NullExp))
{
    committed = 0;
    this->type = type;
}

bool NullExp::equals(RootObject *o)
{
    if (o && o->dyncast() == DYNCAST_EXPRESSION)
    {
        Expression *e = (Expression *)o;
        if (e->op == TOKnull &&
            type->equals(e->type))
        {
            return true;
        }
    }
    return false;
}

Expression *NullExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("NullExp::semantic('%s')\n", toChars());
#endif
    // NULL is the same as (void *)0
    if (type)
        return this;

    type = Type::tnull;
    return this;
}

bool NullExp::isBool(bool result)
{
    return result ? false : true;
}

StringExp *NullExp::toStringExp()
{
    if (implicitConvTo(Type::tstring))
    {
        StringExp *se = new StringExp(loc, (char*)mem.calloc(1, 1), 0);
        se->type = Type::tstring;
        return se;
    }
    return NULL;
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

StringExp::StringExp(Loc loc, void *string, size_t len, utf8_t postfix)
        : Expression(loc, TOKstring, sizeof(StringExp))
{
    this->string = string;
    this->len = len;
    this->sz = 1;
    this->committed = 0;
    this->postfix = postfix;
    this->ownedByCtfe = false;
}

StringExp *StringExp::create(Loc loc, char *s)
{
    return new StringExp(loc, s);
}

bool StringExp::equals(RootObject *o)
{
    //printf("StringExp::equals('%s') %s\n", o->toChars(), toChars());
    if (o && o->dyncast() == DYNCAST_EXPRESSION)
    {
        Expression *e = (Expression *)o;
        if (e->op == TOKstring)
        {
            return compare(o) == 0;
        }
    }
    return false;
}

Expression *StringExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("StringExp::semantic() %s\n", toChars());
#endif
    if (type)
        return this;

    OutBuffer buffer;
    size_t newlen = 0;
    const char *p;
    size_t u;
    unsigned c;

    switch (postfix)
    {
        case 'd':
            for (u = 0; u < len;)
            {
                p = utf_decodeChar((utf8_t *)string, len, &u, &c);
                if (p)
                {
                    error("%s", p);
                    return new ErrorExp();
                }
                else
                {
                    buffer.write4(c);
                    newlen++;
                }
            }
            buffer.write4(0);
            string = buffer.extractData();
            len = newlen;
            sz = 4;
            type = new TypeDArray(Type::tdchar->immutableOf());
            committed = 1;
            break;

        case 'w':
            for (u = 0; u < len;)
            {
                p = utf_decodeChar((utf8_t *)string, len, &u, &c);
                if (p)
                {
                    error("%s", p);
                    return new ErrorExp();
                }
                else
                {
                    buffer.writeUTF16(c);
                    newlen++;
                    if (c >= 0x10000)
                        newlen++;
                }
            }
            buffer.writeUTF16(0);
            string = buffer.extractData();
            len = newlen;
            sz = 2;
            type = new TypeDArray(Type::twchar->immutableOf());
            committed = 1;
            break;

        case 'c':
            committed = 1;
        default:
            type = new TypeDArray(Type::tchar->immutableOf());
            break;
    }
    type = type->semantic(loc, sc);
    //type = type->immutableOf();
    //printf("type = %s\n", type->toChars());

    return this;
}

/**********************************
 * Return the code unit count of string.
 * Input:
 *      encSize     code unit size of the target encoding.
 */

size_t StringExp::length(int encSize)
{
    assert(encSize == 1 || encSize == 2 || encSize == 4);
    if (sz == encSize)
        return len;

    size_t result = 0;
    dchar_t c;

    switch (sz)
    {
        case 1:
            for (size_t u = 0; u < len;)
            {
                if (const char *p = utf_decodeChar((utf8_t *)string, len, &u, &c))
                {
                    error("%s", p);
                    return 0;
                }
                result += utf_codeLength(encSize, c);
            }
            break;

        case 2:
            for (size_t u = 0; u < len;)
            {
                if (const char *p = utf_decodeWchar((utf16_t *)string, len, &u, &c))
                {
                    error("%s", p);
                    return 0;
                }
                result += utf_codeLength(encSize, c);
            }
            break;

        case 4:
            for (size_t u = 0; u < len;)
            {
                c = *((utf32_t *)((char *)string + u));
                u += 4;
                result += utf_codeLength(encSize, c);
            }
            break;

        default:
            assert(0);
    }
    return result;
}

StringExp *StringExp::toStringExp()
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

int StringExp::compare(RootObject *obj)
{
    //printf("StringExp::compare()\n");
    // Used to sort case statement expressions so we can do an efficient lookup
    StringExp *se2 = (StringExp *)(obj);

    // This is a kludge so isExpression() in template.c will return 5
    // for StringExp's.
    if (!se2)
        return 5;

    assert(se2->op == TOKstring);

    size_t len1 = len;
    size_t len2 = se2->len;

    //printf("sz = %d, len1 = %d, len2 = %d\n", sz, (int)len1, (int)len2);
    if (len1 == len2)
    {
        switch (sz)
        {
            case 1:
                return memcmp((char *)string, (char *)se2->string, len1);

            case 2:
            {
                d_wchar *s1 = (d_wchar *)string;
                d_wchar *s2 = (d_wchar *)se2->string;

                for (size_t u = 0; u < len; u++)
                {
                    if (s1[u] != s2[u])
                        return s1[u] - s2[u];
                }
            }

            case 4:
            {
                d_dchar *s1 = (d_dchar *)string;
                d_dchar *s2 = (d_dchar *)se2->string;

                for (size_t u = 0; u < len; u++)
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
    return (int)(len1 - len2);
}

bool StringExp::isBool(bool result)
{
    return result ? true : false;
}


bool StringExp::isLvalue()
{
    /* string literal is rvalue in default, but
     * conversion to reference of static array is only allowed.
     */
    return (type && type->toBasetype()->ty == Tsarray);
}

Expression *StringExp::toLvalue(Scope *sc, Expression *e)
{
    //printf("StringExp::toLvalue(%s) type = %s\n", toChars(), type ? type->toChars() : NULL);
    return (type && type->toBasetype()->ty == Tsarray)
            ? this : Expression::toLvalue(sc, e);
}

Expression *StringExp::modifiableLvalue(Scope *sc, Expression *e)
{
    error("cannot modify string literal %s", toChars());
    return new ErrorExp();
}

unsigned StringExp::charAt(uinteger_t i)
{   unsigned value;

    switch (sz)
    {
        case 1:
            value = ((utf8_t *)string)[(size_t)i];
            break;

        case 2:
            value = ((unsigned short *)string)[(size_t)i];
            break;

        case 4:
            value = ((unsigned int *)string)[(size_t)i];
            break;

        default:
            assert(0);
            break;
    }
    return value;
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

bool ArrayLiteralExp::equals(RootObject *o)
{
    if (this == o)
        return true;
    if (o && o->dyncast() == DYNCAST_EXPRESSION &&
        ((Expression *)o)->op == TOKarrayliteral)
    {
        ArrayLiteralExp *ae = (ArrayLiteralExp *)o;
        if (elements->dim != ae->elements->dim)
            return false;
        if (elements->dim == 0 &&
            !type->equals(ae->type))
        {
            return false;
        }
        for (size_t i = 0; i < elements->dim; i++)
        {
            Expression *e1 = (*elements)[i];
            Expression *e2 = (*ae->elements)[i];
            if (e1 != e2 &&
                (!e1 || !e2 || !e1->equals(e2)))
                return false;
        }
        return true;
    }
    return false;
}

Expression *ArrayLiteralExp::syntaxCopy()
{
    return new ArrayLiteralExp(loc, arraySyntaxCopy(elements));
}

Expression *ArrayLiteralExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("ArrayLiteralExp::semantic('%s')\n", toChars());
#endif
    if (type)
        return this;

    /* Perhaps an empty array literal [ ] should be rewritten as null?
     */

    if (arrayExpressionSemantic(elements, sc))  // run semantic() on each element
        return new ErrorExp();
    expandTuples(elements);

    Type *t0;
    if (arrayExpressionToCommonType(sc, elements, &t0))
        return new ErrorExp();

    type = t0->arrayOf();
    //type = new TypeSArray(t0, new IntegerExp(elements->dim));
    type = type->semantic(loc, sc);

    /* Disallow array literals of type void being used.
     */
    if (elements->dim > 0 && t0->ty == Tvoid)
    {
        error("%s of type %s has no value", toChars(), type->toChars());
        return new ErrorExp();
    }

    semanticTypeInfo(sc, t0);

    return this;
}

bool ArrayLiteralExp::isBool(bool result)
{
    size_t dim = elements ? elements->dim : 0;
    return result ? (dim != 0) : (dim == 0);
}

StringExp *ArrayLiteralExp::toStringExp()
{
    TY telem = type->nextOf()->toBasetype()->ty;

    if (telem == Tchar || telem == Twchar || telem == Tdchar ||
        (telem == Tvoid && (!elements || elements->dim == 0)))
    {
        unsigned char sz = 1;
        if (telem == Twchar) sz = 2;
        else if (telem == Tdchar) sz = 4;

        OutBuffer buf;
        if (elements)
        {
            for (size_t i = 0; i < elements->dim; ++i)
            {
                Expression *ch = (*elements)[i];
                if (ch->op != TOKint64)
                    return NULL;
                     if (sz == 1) buf.writeByte((unsigned)ch->toInteger());
                else if (sz == 2) buf.writeword((unsigned)ch->toInteger());
                else              buf.write4((unsigned)ch->toInteger());
            }
        }
        char prefix;
             if (sz == 1) { prefix = 'c'; buf.writeByte(0); }
        else if (sz == 2) { prefix = 'w'; buf.writeword(0); }
        else              { prefix = 'd'; buf.write4(0); }

        const size_t len = buf.offset / sz - 1;
        StringExp *se = new StringExp(loc, buf.extractData(), len, prefix);
        se->sz = sz;
        se->type = type;
        return se;
    }
    return NULL;
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

bool AssocArrayLiteralExp::equals(RootObject *o)
{
    if (this == o)
        return true;
    if (o && o->dyncast() == DYNCAST_EXPRESSION &&
        ((Expression *)o)->op == TOKassocarrayliteral)
    {
        AssocArrayLiteralExp *ae = (AssocArrayLiteralExp *)o;
        if (keys->dim != ae->keys->dim)
            return false;
        size_t count = 0;
        for (size_t i = 0; i < keys->dim; i++)
        {
            for (size_t j = 0; j < ae->keys->dim; j++)
            {
                if ((*keys)[i]->equals((*ae->keys)[j]))
                {
                    if (!(*values)[i]->equals((*ae->values)[j]))
                        return false;
                    ++count;
                }
            }
        }
        return count == keys->dim;
    }
    return false;
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
    bool err_keys = arrayExpressionSemantic(keys, sc);
    bool err_vals = arrayExpressionSemantic(values, sc);
    if (err_keys || err_vals)
        return new ErrorExp();
    expandTuples(keys);
    expandTuples(values);
    if (keys->dim != values->dim)
    {
        error("number of keys is %u, must match number of values %u", keys->dim, values->dim);
        return new ErrorExp();
    }

    Type *tkey = NULL;
    Type *tvalue = NULL;
    err_keys = arrayExpressionToCommonType(sc, keys, &tkey);
    err_vals = arrayExpressionToCommonType(sc, values, &tvalue);
    if (err_keys || err_vals)
        return new ErrorExp();

    if (tkey == Type::terror || tvalue == Type::terror)
        return new ErrorExp;

    type = new TypeAArray(tvalue, tkey);
    type = type->semantic(loc, sc);

    semanticTypeInfo(sc, type);

    return this;
}


bool AssocArrayLiteralExp::isBool(bool result)
{
    size_t dim = keys->dim;
    return result ? (dim != 0) : (dim == 0);
}

/************************ StructLiteralExp ************************************/

// sd( e1, e2, e3, ... )

StructLiteralExp::StructLiteralExp(Loc loc, StructDeclaration *sd, Expressions *elements, Type *stype)
    : Expression(loc, TOKstructliteral, sizeof(StructLiteralExp))
{
    this->sd = sd;
    if (!elements)
        elements = new Expressions();
    this->elements = elements;
    this->stype = stype;
    this->sinit = NULL;
    this->sym = NULL;
    this->soffset = 0;
    this->fillHoles = 1;
    this->ownedByCtfe = false;
    this->origin = this;
    this->stageflags = 0;
    this->inlinecopy = NULL;
    //printf("StructLiteralExp::StructLiteralExp(%s)\n", toChars());
}

StructLiteralExp *StructLiteralExp::create(Loc loc, StructDeclaration *sd, void *elements, Type *stype)
{
    return new StructLiteralExp(loc, sd, (Expressions *)elements, stype);
}

bool StructLiteralExp::equals(RootObject *o)
{
    if (this == o)
        return true;
    if (o && o->dyncast() == DYNCAST_EXPRESSION &&
        ((Expression *)o)->op == TOKstructliteral)
    {
        StructLiteralExp *se = (StructLiteralExp *)o;
        if (!type->equals(se->type))
            return false;
        if (elements->dim != se->elements->dim)
            return false;
        for (size_t i = 0; i < elements->dim; i++)
        {
            Expression *e1 = (*elements)[i];
            Expression *e2 = (*se->elements)[i];
            if (e1 != e2 &&
                (!e1 || !e2 || !e1->equals(e2)))
                return false;
        }
        return true;
    }
    return false;
}

Expression *StructLiteralExp::syntaxCopy()
{
    StructLiteralExp *exp = new StructLiteralExp(loc, sd, arraySyntaxCopy(elements), stype);
    exp->origin = this;
    return exp;
}

Expression *StructLiteralExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("StructLiteralExp::semantic('%s')\n", toChars());
#endif
    if (type)
        return this;

    sd->size(loc);
    if (sd->sizeok != SIZEOKdone)
        return new ErrorExp();

    if (arrayExpressionSemantic(elements, sc))  // run semantic() on each element
        return new ErrorExp();
    expandTuples(elements);

    /* Fit elements[] to the corresponding type of field[].
     */
    if (!sd->fit(loc, sc, elements, stype))
        return new ErrorExp();

    if (!checkFrameAccess(loc, sc, sd, elements->dim))
        return new ErrorExp();

    /* Fill out remainder of elements[] with default initializers for fields[]
     */
    if (!sd->fill(loc, elements, false))
    {
        /* An error in the initializer needs to be recorded as an error
         * in the enclosing function or template, since the initializer
         * will be part of the stuct declaration.
         */
        global.increaseErrorCount();
        return new ErrorExp();
    }
    type = stype ? stype : sd->type;
    return this;
}

Expression *StructLiteralExp::addDtorHook(Scope *sc)
{
    /* If struct requires a destructor, rewrite as:
     *    (S tmp = S()),tmp
     * so that the destructor can be hung on tmp.
     */
    if (sd->dtor && sc->func)
    {
        /* Make an identifier for the temporary of the form:
         *   __sl%s%d, where %s is the struct name
         */
        const size_t len = 10;
        char buf[len + 1];
        buf[len] = 0;
        strcpy(buf, "__sl");
        strncat(buf, sd->ident->toChars(), len - 4 - 1);
        assert(buf[len] == 0);
        Identifier *idtmp = Identifier::generateId(buf);

        VarDeclaration *tmp = new VarDeclaration(loc, type, idtmp, new ExpInitializer(loc, this));
        tmp->storage_class |= STCtemp | STCctfe;
        Expression *ae = new DeclarationExp(loc, tmp);
        Expression *e = new CommaExp(loc, ae, new VarExp(loc, tmp));
        e = e->semantic(sc);
        return e;
    }
    return this;
}

/**************************************
 * Gets expression at offset of type.
 * Returns NULL if not found.
 */

Expression *StructLiteralExp::getField(Type *type, unsigned offset)
{
    //printf("StructLiteralExp::getField(this = %s, type = %s, offset = %u)\n",
    //  /*toChars()*/"", type->toChars(), offset);
    Expression *e = NULL;
    int i = getFieldIndex(type, offset);

    if (i != -1)
    {
        //printf("\ti = %d\n", i);
        if (i == sd->fields.dim - 1 && sd->isNested())
            return NULL;

        assert(i < elements->dim);
        e = (*elements)[i];
        if (e)
        {
            //printf("e = %s, e->type = %s\n", e->toChars(), e->type->toChars());

            /* If type is a static array, and e is an initializer for that array,
             * then the field initializer should be an array literal of e.
             */
            if (e->type->castMod(0) != type->castMod(0) && type->ty == Tsarray)
            {   TypeSArray *tsa = (TypeSArray *)type;
                size_t length = (size_t)tsa->dim->toInteger();
                Expressions *z = new Expressions;
                z->setDim(length);
                for (size_t q = 0; q < length; ++q)
                    (*z)[q] = e->copy();
                e = new ArrayLiteralExp(loc, z);
                e->type = type;
            }
            else
            {
                e = e->copy();
                e->type = type;
            }
            if (sinit && e->op == TOKstructliteral &&
                e->type->needsNested())
            {
                StructLiteralExp *se = (StructLiteralExp *)e;
                se->sinit = toInitializer(se->sd);
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
            VarDeclaration *v = sd->fields[i];

            if (offset == v->offset &&
                type->size() == v->type->size())
            {
                /* context field might not be filled. */
                if (i == sd->fields.dim - 1 && sd->isNested())
                    return (int)i;
                Expression *e = (*elements)[i];
                if (e)
                {
                    return (int)i;
                }
                break;
            }
        }
    }
    return -1;
}

/************************ TypeDotIdExp ************************************/

/* Things like:
 *      int.size
 *      foo.size
 *      (foo).size
 *      cast(foo).size
 */

DotIdExp *typeDotIdExp(Loc loc, Type *type, Identifier *ident)
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
    return new TypeExp(loc, type->syntaxCopy());
}

Expression *TypeExp::semantic(Scope *sc)
{
    //printf("TypeExp::semantic(%s)\n", type->toChars());
    Expression *e;
    Type *t;
    Dsymbol *s;

    type->resolve(loc, sc, &e, &t, &s, true);
    if (e)
    {
        //printf("e = %s %s\n", Token::toChars(e->op), e->toChars());
        e = e->semantic(sc);
    }
    else if (t)
    {
        //printf("t = %d %s\n", t->ty, t->toChars());
        type = t->semantic(loc, sc);
        e = this;
    }
    else if (s)
    {
        //printf("s = %s %s\n", s->kind(), s->toChars());
        e = new DsymbolExp(loc, s, s->hasOverloads());
        e = e->semantic(sc);
    }
    else
        assert(0);

    return e;
}

bool TypeExp::rvalue()
{
    error("type %s has no value", toChars());
    return false;
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
    return new ScopeExp(loc, (ScopeDsymbol *)sds->syntaxCopy(NULL));
}

Expression *ScopeExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("+ScopeExp::semantic('%s')\n", toChars());
#endif
    //if (type == Type::tvoid)
    //    return this;

Lagain:
    TemplateInstance *ti = sds->isTemplateInstance();
    if (ti)
    {
        WithScopeSymbol *withsym;
        if (!ti->findTempDecl(sc, &withsym) ||
            !ti->semanticTiargs(sc))
        {
            return new ErrorExp();
        }
        if (withsym && withsym->withstate->wthis)
        {
            Expression *e = new VarExp(loc, withsym->withstate->wthis);
            e = new DotTemplateInstanceExp(loc, e, ti);
            return e->semantic(sc);
        }
        if (ti->needsTypeInference(sc))
        {
            if (TemplateDeclaration *td = ti->tempdecl->isTemplateDeclaration())
            {
                Dsymbol *p = td->toParent2();
                FuncDeclaration *fdthis = hasThis(sc);
                AggregateDeclaration *ad = p ? p->isAggregateDeclaration() : NULL;
                if (fdthis && ad && isAggregate(fdthis->vthis->type) == ad &&
                    (td->scope->stc & STCstatic) == 0)
                {
                    Expression *e = new DotTemplateInstanceExp(loc, new ThisExp(loc), ti->name, ti->tiargs);
                    return e->semantic(sc);
                }
            }
            else if (OverloadSet *os = ti->tempdecl->isOverloadSet())
            {
                FuncDeclaration *fdthis = hasThis(sc);
                AggregateDeclaration *ad = os->parent->isAggregateDeclaration();
                if (fdthis && ad && isAggregate(fdthis->vthis->type) == ad)
                {
                    Expression *e = new DotTemplateInstanceExp(loc, new ThisExp(loc), ti->name, ti->tiargs);
                    return e->semantic(sc);
                }
            }
            return this;
        }
        ti->semantic(sc);
        if (!ti->inst || ti->errors)
            return new ErrorExp();

        {
            Dsymbol *s = ti->toAlias();
            ScopeDsymbol *sds2 = s->isScopeDsymbol();
            if (!sds2)
            {
                Expression *e;

                //printf("s = %s, '%s'\n", s->kind(), s->toChars());
                if (withsym && withsym->withstate->wthis)
                {
                    // Same as wthis.s
                    e = new VarExp(loc, withsym->withstate->wthis);
                    e = new DotVarExp(loc, e, s->isDeclaration());
                }
                else
                    e = new DsymbolExp(loc, s, s->hasOverloads());
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

/********************** TemplateExp **************************************/

// Mainly just a placeholder

TemplateExp::TemplateExp(Loc loc, TemplateDeclaration *td, FuncDeclaration *fd)
    : Expression(loc, TOKtemplate, sizeof(TemplateExp))
{
    //printf("TemplateExp(): %s\n", td->toChars());
    this->td = td;
    this->fd = fd;
}

bool TemplateExp::rvalue()
{
    error("template %s has no value", toChars());
    return false;
}

bool TemplateExp::isLvalue()
{
    return fd != NULL;
}

Expression *TemplateExp::toLvalue(Scope *sc, Expression *e)
{
    if (!fd)
        return Expression::toLvalue(sc, e);

    assert(sc);
    Expression *ex = new DsymbolExp(loc, fd, 1);
    ex = ex->semantic(sc);
    return ex;
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
    argprefix = NULL;
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
#if LOGSEMANTIC
    printf("NewExp::semantic() %s\n", toChars());
    if (thisexp)
        printf("\tthisexp = %s\n", thisexp->toChars());
    printf("\tnewtype: %s\n", newtype->toChars());
#endif
    if (type)                   // if semantic() already run
        return this;

    Type *tb;
    ClassDeclaration *cdthis = NULL;
    size_t nargs;
    Expression *newprefix = NULL;

Lagain:
    if (thisexp)
    {
        thisexp = thisexp->semantic(sc);
        cdthis = thisexp->type->isClassHandle();
        if (cdthis)
        {
            sc = sc->push(cdthis);
            type = newtype->semantic(loc, sc);
            sc = sc->pop();

            if (type->ty == Terror)
                goto Lerr;
            if (!MODimplicitConv(thisexp->type->mod, newtype->mod))
            {
                error("nested type %s should have the same or weaker constancy as enclosing type %s",
                    newtype->toChars(), thisexp->type->toChars());
                goto Lerr;
            }
        }
        else
        {
            error("'this' for nested class must be a class type, not %s", thisexp->type->toChars());
            goto Lerr;
        }
    }
    else
    {
        type = newtype->semantic(loc, sc);
        if (type->ty == Terror)
            goto Lerr;
    }
    newtype = type;             // in case type gets cast to something else
    tb = type->toBasetype();
    //printf("tb: %s, deco = %s\n", tb->toChars(), tb->deco);

    if (arrayExpressionSemantic(newargs, sc) ||
        preFunctionParameters(loc, sc, newargs))
    {
        goto Lerr;
    }
    if (arrayExpressionSemantic(arguments, sc) ||
        preFunctionParameters(loc, sc, arguments))
    {
        goto Lerr;
    }

    nargs = arguments ? arguments->dim : 0;

    if (thisexp && tb->ty != Tclass)
    {
        error("e.new is only for allocating nested classes, not %s", tb->toChars());
        goto Lerr;
    }

    if (tb->ty == Tclass)
    {
        TypeClass *tc = (TypeClass *)(tb);
        ClassDeclaration *cd = tc->sym->isClassDeclaration();
        if (cd->scope)
            cd->semantic(NULL);
        if (cd->isInterfaceDeclaration())
        {
            error("cannot create instance of interface %s", cd->toChars());
            goto Lerr;
        }
        else if (cd->isAbstract())
        {
            error("cannot create instance of abstract class %s", cd->toChars());
            for (size_t i = 0; i < cd->vtbl.dim; i++)
            {
                FuncDeclaration *fd = cd->vtbl[i]->isFuncDeclaration();
                if (fd && fd->isAbstract())
                    errorSupplemental(loc, "function '%s' is not implemented", fd->toFullSignature());
            }
            goto Lerr;
        }

        if (cd->noDefaultCtor && !nargs && !cd->defaultCtor)
        {
            error("default construction is disabled for type %s", cd->type->toChars());
            goto Lerr;
        }
        checkDeprecated(sc, cd);
        if (cd->isNested())
        {
            /* We need a 'this' pointer for the nested class.
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
                    {
                        if (!sp)
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
                    {
                        error("'this' for nested class must be of type %s, not %s", cdn->toChars(), thisexp->type->toChars());
                        goto Lerr;
                    }
                }
            }
            else if (thisexp)
            {
                error("e.new is only for allocating nested classes");
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
                    else if (FuncLiteralDeclaration *fld = sp->isFuncLiteralDeclaration())
                    {
                        fld->tok = TOKdelegate;
                    }
                }
            }
            else
                assert(0);
        }
        else if (thisexp)
        {
            error("e.new is only for allocating nested classes");
            goto Lerr;
        }

        if (cd->ctor)
        {
            FuncDeclaration *f = resolveFuncCall(loc, sc, cd->ctor, NULL, tb, arguments, 0);
            if (!f || f->errors)
                goto Lerr;
            checkDeprecated(sc, f);
            checkPurity(sc, f);
            checkSafety(sc, f);
            checkNogc(sc, f);
            member = f->isCtorDeclaration();
            assert(member);

            accessCheck(cd, loc, sc, member);

            TypeFunction *tf = (TypeFunction *)f->type;

            if (!arguments)
                arguments = new Expressions();
            if (functionParameters(loc, sc, tf, type, arguments, f, &type, &argprefix))
                return new ErrorExp();
        }
        else
        {
            if (nargs)
            {
                error("no constructor for %s", cd->toChars());
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

            FuncDeclaration *f = resolveFuncCall(loc, sc, cd->aggNew, NULL, tb, newargs);
            if (!f || f->errors)
                goto Lerr;
            allocator = f->isNewDeclaration();
            assert(allocator);

            TypeFunction *tf = (TypeFunction *)f->type;
            Type *rettype;
            if (functionParameters(loc, sc, tf, NULL, newargs, f, &rettype, &newprefix))
                return new ErrorExp();
        }
        else
        {
            if (newargs && newargs->dim)
            {
                error("no allocator for %s", cd->toChars());
                goto Lerr;
            }
        }
    }
    else if (tb->ty == Tstruct)
    {
        TypeStruct *ts = (TypeStruct *)tb;
        StructDeclaration *sd = ts->sym;
        sd->size(loc);
        if (sd->sizeok != SIZEOKdone)
            return new ErrorExp();
        if (sd->noDefaultCtor && !nargs)
        {
            error("default construction is disabled for type %s", sd->type->toChars());
            goto Lerr;
        }

        if (sd->aggNew)
        {
            // Prepend the uint size argument to newargs[]
            Expression *e = new IntegerExp(loc, sd->size(loc), Type::tuns32);
            if (!newargs)
                newargs = new Expressions();
            newargs->shift(e);

            FuncDeclaration *f = resolveFuncCall(loc, sc, sd->aggNew, NULL, tb, newargs);
            if (!f || f->errors)
                goto Lerr;
            allocator = f->isNewDeclaration();
            assert(allocator);

            TypeFunction *tf = (TypeFunction *)f->type;
            Type *rettype;
            if (functionParameters(loc, sc, tf, NULL, newargs, f, &rettype, &newprefix))
                return new ErrorExp();
        }
        else
        {
            if (newargs && newargs->dim)
            {
                error("no allocator for %s", sd->toChars());
                goto Lerr;
            }
        }

        if (sd->ctor && nargs)
        {
            FuncDeclaration *f = resolveFuncCall(loc, sc, sd->ctor, NULL, tb, arguments, 0);
            if (!f || f->errors)
                goto Lerr;
            checkDeprecated(sc, f);
            checkPurity(sc, f);
            checkSafety(sc, f);
            checkNogc(sc, f);
            member = f->isCtorDeclaration();
            assert(member);

            accessCheck(sd, loc, sc, member);

            TypeFunction *tf = (TypeFunction *)f->type;

            if (!arguments)
                arguments = new Expressions();
            if (functionParameters(loc, sc, tf, type, arguments, f, &type, &argprefix))
                return new ErrorExp();
        }
        else
        {
            if (!sd->fit(loc, sc, arguments, tb))
                return new ErrorExp();

            if (!sd->fill(loc, arguments, false))
                return new ErrorExp();
        }

        type = type->pointerTo();
    }
    else if (tb->ty == Tarray && nargs)
    {
        Type *tn = tb->nextOf()->baseElemOf();
        Dsymbol *s = tn->toDsymbol(sc);
        AggregateDeclaration *ad = s ? s->isAggregateDeclaration() : NULL;
        if (ad && ad->noDefaultCtor)
        {
            error("default construction is disabled for type %s", tb->nextOf()->toChars());
            goto Lerr;
        }
        for (size_t i = 0; i < nargs; i++)
        {
            if (tb->ty != Tarray)
            {
                error("too many arguments for array");
                goto Lerr;
            }

            Expression *arg = (*arguments)[i];
            arg = resolveProperties(sc, arg);
            arg = arg->implicitCastTo(sc, Type::tsize_t);
            arg = arg->optimize(WANTvalue);
            if (arg->op == TOKint64 && (sinteger_t)arg->toInteger() < 0)
            {
                error("negative array index %s", arg->toChars());
                goto Lerr;
            }
            (*arguments)[i] =  arg;
            tb = ((TypeDArray *)tb)->next->toBasetype();
        }
    }
    else if (tb->isscalar())
    {
        if (!nargs)
        {
        }
        else if (nargs == 1)
        {
            Expression *e = (*arguments)[0];
            e = e->implicitCastTo(sc, tb);
            (*arguments)[0] = e;
        }
        else
        {
            error("more than one argument for construction of %s", type->toChars());
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
    semanticTypeInfo(sc, type);

    if (newprefix)
        return combine(newprefix, this);
    return this;

Lerr:
    return new ErrorExp();
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
    sc = sc->push();            // just create new scope
    sc->flags &= ~SCOPEctfe;    // temporary stop CTFE
    d = d->semantic(sc);
    sc = sc->pop();

    Expression *n = new NewExp(loc, thisexp, newargs, cd->type, arguments);

    Expression *c = new CommaExp(loc, d, n);
    return c->semantic(sc);
}

/********************** SymbolExp **************************************/

SymbolExp::SymbolExp(Loc loc, TOK op, int size, Declaration *var, bool hasOverloads)
    : Expression(loc, op, size)
{
    assert(var);
    this->var = var;
    this->hasOverloads = hasOverloads;
}

/********************** SymOffExp **************************************/

SymOffExp::SymOffExp(Loc loc, Declaration *var, dinteger_t offset, bool hasOverloads)
    : SymbolExp(loc, TOKsymoff, sizeof(SymOffExp), var, hasOverloads)
{
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
    if (VarDeclaration *v = var->isVarDeclaration())
    {
        if (!v->checkNestedReference(sc, loc))
            return new ErrorExp();
    }
    else if (FuncDeclaration *f = var->isFuncDeclaration())
    {
        if (!f->checkNestedReference(sc, loc))
            return new ErrorExp();
    }
    return this;
}

bool SymOffExp::isBool(bool result)
{
    return result ? true : false;
}

/******************************** VarExp **************************/

VarExp::VarExp(Loc loc, Declaration *var, bool hasOverloads)
    : SymbolExp(loc, TOKvar, sizeof(VarExp), var, hasOverloads)
{
    //printf("VarExp(this = %p, '%s', loc = %s)\n", this, var->toChars(), loc.toChars());
    //if (strcmp(var->ident->toChars(), "func") == 0) halt();
    this->type = var->type;
}

VarExp *VarExp::create(Loc loc, Declaration *var, bool hasOverloads)
{
    return new VarExp(loc, var, hasOverloads);
}

bool VarExp::equals(RootObject *o)
{
    if (this == o)
        return true;
    if (((Expression *)o)->op == TOKvar)
    {
        VarExp *ne = (VarExp *)o;
        if (type->toHeadMutable()->equals(ne->type->toHeadMutable()) &&
            var == ne->var)
        {
            return true;
        }
    }
    return false;
}

Expression *VarExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("VarExp::semantic(%s)\n", toChars());
#endif
    if (FuncDeclaration *fd = var->isFuncDeclaration())
    {
        //printf("L%d fd = %s\n", __LINE__, f->toChars());
        if (!fd->functionSemantic())
            return new ErrorExp();
    }

    if (!type)
        type = var->type;

    if (type && !type->deco)
        type = type->semantic(loc, sc);

    /* Fix for 1161 doesn't work because it causes protection
     * problems when instantiating imported templates passing private
     * variables as alias template parameters.
     */
    //accessCheck(loc, sc, NULL, var);

    if (VarDeclaration *vd = var->isVarDeclaration())
    {
        hasOverloads = 0;
        if (!vd->checkNestedReference(sc, loc))
            return new ErrorExp();
    }
    else if (FuncDeclaration *fd = var->isFuncDeclaration())
    {
        if (!fd->checkNestedReference(sc, loc))
            return new ErrorExp();
    }
    else if (OverDeclaration *od = var->isOverDeclaration())
    {
        type = Type::tvoid; // ambiguous type?
    }

    return this;
}

bool VarExp::isLvalue()
{
    if (var->storage_class & (STClazy | STCrvalue | STCmanifest))
        return false;
    return true;
}

Expression *VarExp::toLvalue(Scope *sc, Expression *e)
{
    if (var->storage_class & STCmanifest)
    {
        error("manifest constant '%s' is not lvalue", var->toChars());
        return new ErrorExp();
    }
    if (var->storage_class & STClazy)
    {
        error("lazy variables cannot be lvalues");
        return new ErrorExp();
    }
    if (var->ident == Id::ctfe)
    {
        error("compiler-generated variable __ctfe is not an lvalue");
        return new ErrorExp();
    }
    if (var->ident == Id::dollar)   // Bugzilla 13574
    {
        error("'$' is not an lvalue");
        return new ErrorExp();
    }
    return this;
}

int VarExp::checkModifiable(Scope *sc, int flag)
{
    //printf("VarExp::checkModifiable %s", toChars());
    assert(type);
    return var->checkModify(loc, sc, type, NULL, flag);
}

Expression *VarExp::modifiableLvalue(Scope *sc, Expression *e)
{
    //printf("VarExp::modifiableLvalue('%s')\n", var->toChars());
    if (var->storage_class & STCmanifest)
    {
        error("cannot modify manifest constant '%s'", toChars());
        return new ErrorExp();
    }
    // See if this expression is a modifiable lvalue (i.e. not const)
    return Expression::modifiableLvalue(sc, e);
}


/******************************** OverExp **************************/

OverExp::OverExp(Loc loc, OverloadSet *s)
        : Expression(loc, TOKoverloadset, sizeof(OverExp))
{
    //printf("OverExp(this = %p, '%s')\n", this, var->toChars());
    vars = s;
    type = Type::tvoid;
}

bool OverExp::isLvalue()
{
    return true;
}

Expression *OverExp::toLvalue(Scope *sc, Expression *e)
{
    return this;
}

/******************************** TupleExp **************************/

TupleExp::TupleExp(Loc loc, Expression *e0, Expressions *exps)
        : Expression(loc, TOKtuple, sizeof(TupleExp))
{
    //printf("TupleExp(this = %p)\n", this);
    this->e0 = e0;
    this->exps = exps;
}

TupleExp::TupleExp(Loc loc, Expressions *exps)
        : Expression(loc, TOKtuple, sizeof(TupleExp))
{
    //printf("TupleExp(this = %p)\n", this);
    this->e0 = NULL;
    this->exps = exps;
}

TupleExp::TupleExp(Loc loc, TupleDeclaration *tup)
        : Expression(loc, TOKtuple, sizeof(TupleExp))
{
    this->e0 = NULL;
    this->exps = new Expressions();

    this->exps->reserve(tup->objects->dim);
    for (size_t i = 0; i < tup->objects->dim; i++)
    {   RootObject *o = (*tup->objects)[i];
        if (Dsymbol *s = getDsymbol(o))
        {
            /* If tuple element represents a symbol, translate to DsymbolExp
             * to supply implicit 'this' if needed later.
             */
            Expression *e = new DsymbolExp(loc, s);
            this->exps->push(e);
        }
        else if (o->dyncast() == DYNCAST_EXPRESSION)
        {
            Expression *e = (Expression *)o;
            this->exps->push(e);
        }
        else if (o->dyncast() == DYNCAST_TYPE)
        {
            Type *t = (Type *)o;
            Expression *e = new TypeExp(loc, t);
            this->exps->push(e);
        }
        else
        {
            error("%s is not an expression", o->toChars());
        }
    }
}

bool TupleExp::equals(RootObject *o)
{
    if (this == o)
        return true;
    if (((Expression *)o)->op == TOKtuple)
    {
        TupleExp *te = (TupleExp *)o;
        if (exps->dim != te->exps->dim)
            return false;
        if (e0 && !e0->equals(te->e0) || !e0 && te->e0)
            return false;
        for (size_t i = 0; i < exps->dim; i++)
        {
            Expression *e1 = (*exps)[i];
            Expression *e2 = (*te->exps)[i];
            if (!e1->equals(e2))
                return false;
        }
        return true;
    }
    return false;
}

Expression *TupleExp::syntaxCopy()
{
    return new TupleExp(loc, e0 ? e0->syntaxCopy() : NULL, arraySyntaxCopy(exps));
}

Expression *TupleExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("+TupleExp::semantic(%s)\n", toChars());
#endif
    if (type)
        return this;

    if (e0)
        e0 = e0->semantic(sc);

    // Run semantic() on each argument
    bool err = false;
    for (size_t i = 0; i < exps->dim; i++)
    {
        Expression *e = (*exps)[i];
        e = e->semantic(sc);
        if (!e->type)
        {
            error("%s has no value", e->toChars());
            err = true;
        }
        else if (e->op == TOKerror)
            err = true;
        else
            (*exps)[i] = e;
    }
    if (err)
        return new ErrorExp();

    expandTuples(exps);
    type = new TypeTuple(exps);
    type = type->semantic(loc, sc);
    //printf("-TupleExp::semantic(%s)\n", toChars());
    return this;
}

/******************************** FuncExp *********************************/

FuncExp::FuncExp(Loc loc, FuncLiteralDeclaration *fd, TemplateDeclaration *td)
        : Expression(loc, TOKfunction, sizeof(FuncExp))
{
    this->fd = fd;
    this->td = td;
    tok = fd->tok;  // save original kind of function/delegate/(infer)
    assert(fd->fbody);
}

bool FuncExp::rvalue()
{
    if (td)
    {
        error("template lambda has no value");
        return false;
    }
    return true;
}

void FuncExp::genIdent(Scope *sc)
{
    if (fd->ident == Id::empty)
    {
        const char *s;
        if (fd->fes)                        s = "__foreachbody";
        else if (fd->tok == TOKreserved)    s = "__lambda";
        else if (fd->tok == TOKdelegate)    s = "__dgliteral";
        else                                s = "__funcliteral";

        DsymbolTable *symtab;
        if (FuncDeclaration *func = sc->parent->isFuncDeclaration())
        {
            if (func->localsymtab == NULL)
            {
                // Inside template constraint, symtab is not set yet.
                // Initialize it lazily.
                func->localsymtab = new DsymbolTable();
            }
            symtab = func->localsymtab;
        }
        else
        {
            ScopeDsymbol *sds = sc->parent->isScopeDsymbol();
            if (!sds->symtab)
            {
                // Inside template constraint, symtab may not be set yet.
                // Initialize it lazily.
                assert(sds->isTemplateInstance());
                sds->symtab = new DsymbolTable();
            }
            symtab = sds->symtab;
        }
        assert(symtab);
        int num = (int)dmd_aaLen(symtab->tab) + 1;
        Identifier *id = Identifier::generateId(s, num);
        fd->ident = id;
        if (td) td->ident = id;
        symtab->insert(td ? (Dsymbol *)td : (Dsymbol *)fd);
    }
}

Expression *FuncExp::syntaxCopy()
{
    TemplateDeclaration *td2;
    FuncLiteralDeclaration *fd2;
    if (td)
    {
        td2 = (TemplateDeclaration *)td->syntaxCopy(NULL);
        assert(td2->members->dim == 1);
        fd2 = (*td2->members)[0]->isFuncLiteralDeclaration();
        assert(fd2);
    }
    else if (fd->semanticRun == PASSinit)
    {
        td2 = NULL;
        fd2 = (FuncLiteralDeclaration *)fd->syntaxCopy(NULL);
    }
    else
    {
        // Bugzilla 13481: Prevent multiple semantic analysis of lambda body.
        td2 = NULL;
        fd2 = fd;
    }
    return new FuncExp(loc, fd2, td2);
}

Expression *FuncExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("FuncExp::semantic(%s)\n", toChars());
    if (fd->treq) printf("  treq = %s\n", fd->treq->toChars());
#endif
    Expression *e = this;

    sc = sc->push();            // just create new scope
    sc->flags &= ~SCOPEctfe;    // temporary stop CTFE
    sc->protection = Prot(PROTpublic);    // Bugzilla 12506

    if (!type || type == Type::tvoid)
    {
        /* fd->treq might be incomplete type,
         * so should not semantic it.
         * void foo(T)(T delegate(int) dg){}
         * foo(a=>a); // in IFTI, treq == T delegate(int)
         */
        //if (fd->treq)
        //    fd->treq = fd->treq->semantic(loc, sc);

        genIdent(sc);

        // Set target of return type inference
        if (fd->treq && !fd->type->nextOf())
        {
            TypeFunction *tfv = NULL;
            if (fd->treq->ty == Tdelegate ||
                (fd->treq->ty == Tpointer && fd->treq->nextOf()->ty == Tfunction))
                tfv = (TypeFunction *)fd->treq->nextOf();
            if (tfv)
            {
                TypeFunction *tfl = (TypeFunction *)fd->type;
                tfl->next = tfv->nextOf();
            }
        }

        //printf("td = %p, treq = %p\n", td, fd->treq);
        if (td)
        {
            assert(td->parameters && td->parameters->dim);
            td->semantic(sc);
            type = Type::tvoid; // temporary type

            if (fd->treq)       // defer type determination
            {
                FuncExp *fe;
                if (matchType(fd->treq, sc, &fe) > MATCHnomatch)
                    e = fe;
                else
                    e = new ErrorExp();
            }
            goto Ldone;
        }

        unsigned olderrors = global.errors;
        fd->semantic(sc);
        if (olderrors == global.errors)
        {
            fd->semantic2(sc);
            if (olderrors == global.errors)
                fd->semantic3(sc);
        }
        if (olderrors != global.errors)
        {
            if (fd->type && fd->type->ty == Tfunction && !fd->type->nextOf())
                ((TypeFunction *)fd->type)->next = Type::terror;
            e = new ErrorExp();
            goto Ldone;
        }

        // Type is a "delegate to" or "pointer to" the function literal
        if ((fd->isNested() && fd->tok == TOKdelegate) ||
            (tok == TOKreserved && fd->treq && fd->treq->ty == Tdelegate))
        {
            type = new TypeDelegate(fd->type);
            type = type->semantic(loc, sc);

            fd->tok = TOKdelegate;
        }
        else
        {
            type = new TypePointer(fd->type);
            type = type->semantic(loc, sc);
            //type = fd->type->pointerTo();

            /* A lambda expression deduced to function pointer might become
             * to a delegate literal implicitly.
             *
             *   auto foo(void function() fp) { return 1; }
             *   assert(foo({}) == 1);
             *
             * So, should keep fd->tok == TOKreserve if fd->treq == NULL.
             */
            if (fd->treq && fd->treq->ty == Tpointer)
            {
                // change to non-nested
                fd->tok = TOKfunction;
                fd->vthis = NULL;
            }
        }
        fd->tookAddressOf++;
    }
Ldone:
    sc = sc->pop();
    return e;
}

MATCH FuncExp::matchType(Type *to, Scope *sc, FuncExp **presult, int flag)
{
    //printf("FuncExp::matchType('%s'), to=%s\n", type ? type->toChars() : "null", to->toChars());
    if (presult)
        *presult = NULL;

    TypeFunction *tof = NULL;
    if (to->ty == Tdelegate)
    {
        if (tok == TOKfunction)
        {
            if (!flag)
                error("cannot match function literal to delegate type '%s'", to->toChars());
            return MATCHnomatch;
        }
        tof = (TypeFunction *)to->nextOf();
    }
    else if (to->ty == Tpointer && to->nextOf()->ty == Tfunction)
    {
        if (tok == TOKdelegate)
        {
            if (!flag)
                error("cannot match delegate literal to function pointer type '%s'", to->toChars());
            return MATCHnomatch;
        }
        tof = (TypeFunction *)to->nextOf();
    }

    if (td)
    {
        if (!tof)
        {
        L1:
            if (!flag)
                error("cannot infer parameter types from %s", to->toChars());
            return MATCHnomatch;
        }

        // Parameter types inference from 'tof'
        assert(td->scope);
        TypeFunction *tf = (TypeFunction *)fd->type;
        //printf("\ttof = %s\n", tof->toChars());
        //printf("\ttf  = %s\n", tf->toChars());
        size_t dim = Parameter::dim(tf->parameters);

        if (Parameter::dim(tof->parameters) != dim ||
            tof->varargs != tf->varargs)
            goto L1;

        Objects *tiargs = new Objects();
        tiargs->reserve(td->parameters->dim);

        for (size_t i = 0; i < td->parameters->dim; i++)
        {
            TemplateParameter *tp = (*td->parameters)[i];
            size_t u = 0;
            for (; u < dim; u++)
            {
                Parameter *p = Parameter::getNth(tf->parameters, u);
                if (p->type->ty == Tident &&
                    ((TypeIdentifier *)p->type)->ident == tp->ident)
                {
                    break;
                }
            }
            assert(u < dim);
            Parameter *pto = Parameter::getNth(tof->parameters, u);
            Type *t = pto->type;
            if (t->ty == Terror)
                goto L1;
            tiargs->push(t);
        }

        // Set target of return type inference
        if (!tf->next && tof->next)
            fd->treq = to;

        TemplateInstance *ti = new TemplateInstance(loc, td, tiargs);
        Expression *ex = (new ScopeExp(loc, ti))->semantic(td->scope);

        // Reset inference target for the later re-semantic
        fd->treq = NULL;

        if (ex->op == TOKerror)
            return MATCHnomatch;
        if (ex->op != TOKfunction)
            goto L1;
        return ((FuncExp *)ex)->matchType(to, sc, presult, flag);
    }

    if (!tof || !tof->next)
        return MATCHnomatch;

    assert(type && type != Type::tvoid);
    TypeFunction *tfx = (TypeFunction *)fd->type;
    bool convertMatch = (type->ty != to->ty);

    if (fd->inferRetType && tfx->next->implicitConvTo(tof->next) == MATCHconvert)
    {
        /* If return type is inferred and covariant return,
         * tweak return statements to required return type.
         *
         * interface I {}
         * class C : Object, I{}
         *
         * I delegate() dg = delegate() { return new class C(); }
         */
        convertMatch = true;

        TypeFunction *tfy = new TypeFunction(tfx->parameters, tof->next, tfx->varargs, tfx->linkage, STCundefined);
        tfy->mod = tfx->mod;
        tfy->isnothrow  = tfx->isnothrow;
        tfy->isnogc     = tfx->isnogc;
        tfy->purity     = tfx->purity;
        tfy->isproperty = tfx->isproperty;
        tfy->isref      = tfx->isref;
        tfy->iswild     = tfx->iswild;
        tfy->deco = tfy->merge()->deco;

        tfx = tfy;
    }

    Type *tx;
    if (tok == TOKdelegate ||
        tok == TOKreserved && (type->ty == Tdelegate ||
                               type->ty == Tpointer && to->ty == Tdelegate))
    {
        // Allow conversion from implicit function pointer to delegate
        tx = new TypeDelegate(tfx);
        tx->deco = tx->merge()->deco;
    }
    else
    {
        assert(tok == TOKfunction ||
               tok == TOKreserved && type->ty == Tpointer);
        tx = tfx->pointerTo();
    }
    //printf("\ttx = %s, to = %s\n", tx->toChars(), to->toChars());

    MATCH m = tx->implicitConvTo(to);
    if (m > MATCHnomatch)
    {
        // MATCHexact:      exact type match
        // MATCHconst:      covairiant type match (eg. attributes difference)
        // MATCHconvert:    context conversion
        m = convertMatch ? MATCHconvert : tx->equals(to) ? MATCHexact : MATCHconst;

        if (presult)
        {
            (*presult) = (FuncExp *)copy();
            (*presult)->type = to;

            // Bugzilla 12508: Tweak function body for covariant returns.
            (*presult)->fd->modifyReturns(sc, tof->next);
        }
    }
    else if (!flag)
    {
        error("cannot implicitly convert expression (%s) of type %s to %s",
                toChars(), tx->toChars(), to->toChars());
    }
    return m;
}

// used from CallExp::semantic()
Expression *FuncExp::semantic(Scope *sc, Expressions *arguments)
{
    if ((!type || type == Type::tvoid) && td && arguments && arguments->dim)
    {
        for (size_t k = 0; k < arguments->dim; k++)
        {   Expression *checkarg = (*arguments)[k];
            if (checkarg->op == TOKerror)
                return checkarg;
        }

        genIdent(sc);

        assert(td->parameters && td->parameters->dim);
        td->semantic(sc);

        TypeFunction *tfl = (TypeFunction *)fd->type;
        size_t dim = Parameter::dim(tfl->parameters);
        if (arguments->dim < dim)
        {   // Default arguments are always typed, so they don't need inference.
            Parameter *p = Parameter::getNth(tfl->parameters, arguments->dim);
            if (p->defaultArg)
                dim = arguments->dim;
        }

        if ((!tfl->varargs && arguments->dim == dim) ||
            ( tfl->varargs && arguments->dim >= dim))
        {
            Objects *tiargs = new Objects();
            tiargs->reserve(td->parameters->dim);

            for (size_t i = 0; i < td->parameters->dim; i++)
            {
                TemplateParameter *tp = (*td->parameters)[i];
                for (size_t u = 0; u < dim; u++)
                {   Parameter *p = Parameter::getNth(tfl->parameters, u);
                    if (p->type->ty == Tident &&
                        ((TypeIdentifier *)p->type)->ident == tp->ident)
                    {   Expression *e = (*arguments)[u];
                        tiargs->push(e->type);
                        u = dim;    // break inner loop
                    }
                }
            }

            TemplateInstance *ti = new TemplateInstance(loc, td, tiargs);
            return (new ScopeExp(loc, ti))->semantic(sc);
        }
        error("cannot infer function literal type");
        return new ErrorExp();
    }
    return semantic(sc);
}

char *FuncExp::toChars()
{
    return fd->toChars();
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

    while (1)
    {
        AttribDeclaration *ad = s->isAttribDeclaration();
        if (ad)
        {
            if (ad->decl && ad->decl->dim == 1)
            {
                s = (*ad->decl)[0];
                continue;
            }
        }
        break;
    }

    VarDeclaration *v = s->isVarDeclaration();
    if (v)
    {
        // Do semantic() on initializer first, so:
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
        {
            error("declaration %s is already defined", s->toPrettyChars());
            return new ErrorExp();
        }
        else if (sc->func)
        {
            // Bugzilla 11720 - include Dataseg variables
            if ((s->isFuncDeclaration() ||
                 s->isAggregateDeclaration() ||
                 s->isEnumDeclaration() ||
                 v && v->isDataseg()) &&
                !sc->func->localsymtab->insert(s))
            {
                error("declaration %s is already defined in another scope in %s",
                    s->toPrettyChars(), sc->func->toChars());
                return new ErrorExp();
            }
            else
            {
                // Disallow shadowing
                for (Scope *scx = sc->enclosing; scx && scx->func == sc->func; scx = scx->enclosing)
                {
                    Dsymbol *s2;
                    if (scx->scopesym && scx->scopesym->symtab &&
                        (s2 = scx->scopesym->symtab->lookup(s->ident)) != NULL &&
                        s != s2)
                    {
                        error("%s %s is shadowing %s %s", s->kind(), s->ident->toChars(), s2->kind(), s2->toPrettyChars());
                        return new ErrorExp();
                    }
                }
            }
        }
    }
    if (!s->isVarDeclaration())
    {
        Scope *sc2 = sc;
        if (sc2->stc & (STCpure | STCnothrow | STCnogc))
            sc2 = sc->push();
        sc2->stc &= ~(STCpure | STCnothrow | STCnogc);
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

/************************ TypeidExp ************************************/

/*
 *      typeid(int)
 */

TypeidExp::TypeidExp(Loc loc, RootObject *o)
    : Expression(loc, TOKtypeid, sizeof(TypeidExp))
{
    this->obj = o;
}

Expression *TypeidExp::syntaxCopy()
{
    return new TypeidExp(loc, objectSyntaxCopy(obj));
}

Expression *TypeidExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("TypeidExp::semantic() %s\n", toChars());
#endif
    Type *ta = isType(obj);
    Expression *ea = isExpression(obj);
    Dsymbol *sa = isDsymbol(obj);

    //printf("ta %p ea %p sa %p\n", ta, ea, sa);

    if (ta)
    {
        ta->resolve(loc, sc, &ea, &ta, &sa, true);
    }

    if (ea)
    {
        Dsymbol *sym = getDsymbol(ea);
        if (sym)
            ea = new DsymbolExp(loc, sym);
        ea = ea->semantic(sc);
        ea = resolveProperties(sc, ea);
        ta = ea->type;
        if (ea->op == TOKtype)
            ea = NULL;
    }

    if (!ta)
    {
        //printf("ta %p ea %p sa %p\n", ta, ea, sa);
        error("no type for typeid(%s)", ea ? ea->toChars() : (sa ? sa->toChars() : ""));
        return new ErrorExp();
    }

    Expression *e;
    if (ea && ta->toBasetype()->ty == Tclass)
    {
        /* Get the dynamic type, which is .classinfo
         */
        e = new DotIdExp(ea->loc, ea, Id::classinfo);
        e = e->semantic(sc);
    }
    else if (ta->ty == Terror)
    {
        e = new ErrorExp();
    }
    else
    {
        /* Get the static type
         */
        e = getTypeInfo(ta, sc);
        if (e->loc.linnum == 0)
            e->loc = loc;               // so there's at least some line number info
        if (ea)
        {
            e = new CommaExp(loc, ea, e);       // execute ea
            e = e->semantic(sc);
        }
    }
    return e;
}

/************************ TraitsExp ************************************/
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

Expression *TraitsExp::semantic(Scope *sc)
{
    return semanticTraits(this, sc);
}

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

/************************************************************/

IsExp::IsExp(Loc loc, Type *targ, Identifier *id, TOK tok,
        Type *tspec, TOK tok2, TemplateParameters *parameters)
        : Expression(loc, TOKis, sizeof(IsExp))
{
    this->targ = targ;
    this->id = id;
    this->tok = tok;
    this->tspec = tspec;
    this->tok2 = tok2;
    this->parameters = parameters;
}

Expression *IsExp::syntaxCopy()
{
    // This section is identical to that in TemplateDeclaration::syntaxCopy()
    TemplateParameters *p = NULL;
    if (parameters)
    {
        p = new TemplateParameters();
        p->setDim(parameters->dim);
        for (size_t i = 0; i < p->dim; i++)
            (*p)[i] = (*parameters)[i]->syntaxCopy();
    }
    return new IsExp(loc,
        targ->syntaxCopy(),
        id,
        tok,
        tspec ? tspec->syntaxCopy() : NULL,
        tok2,
        p);
}

void unSpeculative(Scope *sc, RootObject *o);

Expression *IsExp::semantic(Scope *sc)
{
    /* is(targ id tok tspec)
     * is(targ id :  tok2)
     * is(targ id == tok2)
     */

    //printf("IsExp::semantic(%s)\n", toChars());
    if (id && !(sc->flags & SCOPEcondition))
    {
        error("can only declare type aliases within static if conditionals or static asserts");
        return new ErrorExp();
    }

    Type *tded = NULL;
    Scope *sc2 = sc->copy();    // keep sc->flags
    sc2->tinst = NULL;
    sc2->minst = NULL;
    Type *t = targ->trySemantic(loc, sc2);
    sc2->pop();
    if (!t)
        goto Lno;                       // errors, so condition is false
    targ = t;
    if (tok2 != TOKreserved)
    {
        switch (tok2)
        {
            case TOKtypedef:
                goto Lno;

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
            case TOKconst:
                if (!targ->isConst())
                    goto Lno;
                tded = targ;
                break;

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

            case TOKsuper:
                // If class or interface, get the base class and interfaces
                if (targ->ty != Tclass)
                    goto Lno;
                else
                {
                    ClassDeclaration *cd = ((TypeClass *)targ)->sym;
                    Parameters *args = new Parameters;
                    args->reserve(cd->baseclasses->dim);
                    if (cd->scope && !cd->symtab)
                        cd->semantic(cd->scope);
                    for (size_t i = 0; i < cd->baseclasses->dim; i++)
                    {
                        BaseClass *b = (*cd->baseclasses)[i];
                        args->push(new Parameter(STCin, b->type, NULL, NULL));
                    }
                    tded = new TypeTuple(args);
                }
                break;

            case TOKenum:
                if (targ->ty != Tenum)
                    goto Lno;
                if (id)
                    tded = ((TypeEnum *)targ)->sym->getMemtype(loc);
                else
                    tded = targ;
                if (tded->ty == Terror)
                    return new ErrorExp();
                break;

            case TOKdelegate:
                if (targ->ty != Tdelegate)
                    goto Lno;
                tded = ((TypeDelegate *)targ)->next;    // the underlying function type
                break;

            case TOKfunction:
            case TOKparameters:
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
                {
                    Parameter *arg = Parameter::getNth(params, i);
                    assert(arg && arg->type);
                    /* If one of the default arguments was an error,
                       don't return an invalid tuple
                    */
                    if (tok2 == TOKparameters && arg->defaultArg &&
                        arg->defaultArg->op == TOKerror)
                        return new ErrorExp();
                    args->push(new Parameter(arg->storageClass, arg->type,
                        (tok2 == TOKparameters) ? arg->ident : NULL,
                        (tok2 == TOKparameters) ? arg->defaultArg : NULL));
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
                {
                    tded = ((TypeDelegate *)targ)->next;
                    tded = ((TypeFunction *)tded)->next;
                }
                else if (targ->ty == Tpointer &&
                         ((TypePointer *)targ)->next->ty == Tfunction)
                {
                    tded = ((TypePointer *)targ)->next;
                    tded = ((TypeFunction *)tded)->next;
                }
                else
                    goto Lno;
                break;

            case TOKargTypes:
                /* Generate a type tuple of the equivalent types used to determine if a
                 * function argument of this type can be passed in registers.
                 * The results of this are highly platform dependent, and intended
                 * primarly for use in implementing va_arg().
                 */
                tded = toArgTypes(targ);
                if (!tded)
                    goto Lno;           // not valid for a parameter
                break;

            default:
                assert(0);
        }
        goto Lyes;
    }
    else if (tspec && !id && !(parameters && parameters->dim))
    {
        /* Evaluate to true if targ matches tspec
         * is(targ == tspec)
         * is(targ : tspec)
         */
        tspec = tspec->semantic(loc, sc);
        //printf("targ  = %s, %s\n", targ->toChars(), targ->deco);
        //printf("tspec = %s, %s\n", tspec->toChars(), tspec->deco);
        if (tok == TOKcolon)
        {
            if (targ->implicitConvTo(tspec))
                goto Lyes;
            else
                goto Lno;
        }
        else /* == */
        {
            if (targ->equals(tspec))
                goto Lyes;
            else
                goto Lno;
        }
    }
    else if (tspec)
    {
        /* Evaluate to true if targ matches tspec.
         * If true, declare id as an alias for the specialized type.
         * is(targ == tspec, tpl)
         * is(targ : tspec, tpl)
         * is(targ id == tspec)
         * is(targ id : tspec)
         * is(targ id == tspec, tpl)
         * is(targ id : tspec, tpl)
         */

        Identifier *tid = id ? id : Identifier::generateId("__isexp_id");
        parameters->insert(0, new TemplateTypeParameter(loc, tid, NULL, NULL));

        Objects dedtypes;
        dedtypes.setDim(parameters->dim);
        dedtypes.zero();

        MATCH m = deduceType(targ, sc, tspec, parameters, &dedtypes);
        //printf("targ: %s\n", targ->toChars());
        //printf("tspec: %s\n", tspec->toChars());
        if (m <= MATCHnomatch ||
            (m != MATCHexact && tok == TOKequal))
        {
            goto Lno;
        }
        else
        {
            tded = (Type *)dedtypes[0];
            if (!tded)
                tded = targ;
            Objects tiargs;
            tiargs.setDim(1);
            tiargs[0] = targ;

            /* Declare trailing parameters
             */
            for (size_t i = 1; i < parameters->dim; i++)
            {
                TemplateParameter *tp = (*parameters)[i];
                Declaration *s = NULL;

                m = tp->matchArg(loc, sc, &tiargs, i, parameters, &dedtypes, &s);
                if (m <= MATCHnomatch)
                    goto Lno;
                s->semantic(sc);
                if (sc->sds)
                    s->addMember(sc, sc->sds, 1);
                else if (!sc->insert(s))
                    error("declaration %s is already defined", s->toChars());

                unSpeculative(sc, s);
            }
            goto Lyes;
        }
    }
    else if (id)
    {
        /* Declare id as an alias for type targ. Evaluate to true
         * is(targ id)
         */
        tded = targ;
        goto Lyes;
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
        if (sc->sds)
            s->addMember(sc, sc->sds, 1);

        unSpeculative(sc, s);
    }
    //printf("Lyes\n");
    return new IntegerExp(loc, 1, Type::tbool);

Lno:
    //printf("Lno\n");
    return new IntegerExp(loc, 0, Type::tbool);
}

/************************************************************/

UnaExp::UnaExp(Loc loc, TOK op, int size, Expression *e1)
        : Expression(loc, op, size)
{
    this->e1 = e1;
    this->att1 = NULL;
}

Expression *UnaExp::syntaxCopy()
{
    UnaExp *e = (UnaExp *)copy();
    e->type = NULL;
    e->e1 = e->e1->syntaxCopy();
    return e;
}

/**************************
 * Helper function for easy error propagation.
 * If error occurs, returns ErrorExp. Otherwise returns NULL.
 */
Expression *UnaExp::unaSemantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("UnaExp::semantic('%s')\n", toChars());
#endif
    Expression *e1x = e1->semantic(sc);
    if (e1x->op == TOKerror)
        return e1x;
    e1 = e1x;
    return NULL;
}

Expression *UnaExp::resolveLoc(Loc loc, Scope *sc)
{
    e1 = e1->resolveLoc(loc, sc);
    return this;
}

/************************************************************/

BinExp::BinExp(Loc loc, TOK op, int size, Expression *e1, Expression *e2)
        : Expression(loc, op, size)
{
    this->e1 = e1;
    this->e2 = e2;

    this->att1 = NULL;
    this->att2 = NULL;
}

Expression *BinExp::syntaxCopy()
{
    BinExp *e = (BinExp *)copy();
    e->type = NULL;
    e->e1 = e->e1->syntaxCopy();
    e->e2 = e->e2->syntaxCopy();
    return e;
}

/**************************
 * Helper function for easy error propagation.
 * If error occurs, returns ErrorExp. Otherwise returns NULL.
 */
Expression *BinExp::binSemantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("BinExp::semantic('%s')\n", toChars());
#endif
    Expression *e1x = e1->semantic(sc);
    Expression *e2x = e2->semantic(sc);
    if (e1x->op == TOKerror)
        return e1x;
    if (e2x->op == TOKerror)
        return e2x;
    e1 = e1x;
    e2 = e2x;
    return NULL;
}

Expression *BinExp::binSemanticProp(Scope *sc)
{
    if (Expression *ex = binSemantic(sc))
        return ex;
    Expression *e1x = resolveProperties(sc, e1);
    Expression *e2x = resolveProperties(sc, e2);
    if (e1x->op == TOKerror)
        return e1x;
    if (e2x->op == TOKerror)
        return e2x;
    e1 = e1x;
    e2 = e2x;
    return NULL;
}

Expression *BinExp::checkComplexOpAssign(Scope *sc)
{
    // generate an error if this is a nonsensical *=,/=, or %=, eg real *= imaginary
    if (op == TOKmulass || op == TOKdivass || op == TOKmodass)
    {
        // Any multiplication by an imaginary or complex number yields a complex result.
        // r *= c, i*=c, r*=i, i*=i are all forbidden operations.
        const char *opstr = Token::toChars(op);
        if (e1->type->isreal() && e2->type->iscomplex())
        {
            error("%s %s %s is undefined. Did you mean %s %s %s.re ?",
                e1->type->toChars(), opstr, e2->type->toChars(),
                e1->type->toChars(), opstr, e2->type->toChars());
            return new ErrorExp();
        }
        else if (e1->type->isimaginary() && e2->type->iscomplex())
        {
            error("%s %s %s is undefined. Did you mean %s %s %s.im ?",
                e1->type->toChars(), opstr, e2->type->toChars(),
                e1->type->toChars(), opstr, e2->type->toChars());
            return new ErrorExp();
        }
        else if ((e1->type->isreal() || e1->type->isimaginary()) &&
            e2->type->isimaginary())
        {
            error("%s %s %s is an undefined operation", e1->type->toChars(),
                    opstr, e2->type->toChars());
            return new ErrorExp();
        }
    }

    // generate an error if this is a nonsensical += or -=, eg real += imaginary
    if (op == TOKaddass || op == TOKminass)
    {
        // Addition or subtraction of a real and an imaginary is a complex result.
        // Thus, r+=i, r+=c, i+=r, i+=c are all forbidden operations.
        if ((e1->type->isreal() && (e2->type->isimaginary() || e2->type->iscomplex())) ||
            (e1->type->isimaginary() && (e2->type->isreal() || e2->type->iscomplex())))
        {
            error("%s %s %s is undefined (result is complex)",
                e1->type->toChars(), Token::toChars(op), e2->type->toChars());
            return new ErrorExp();
        }
        if (type->isreal() || type->isimaginary())
        {
            assert(global.errors || e2->type->isfloating());
            e2 = e2->castTo(sc, e1->type);
        }
    }

    if (op == TOKmulass)
    {
        if (e2->type->isfloating())
        {
            Type *t1 = e1->type;
            Type *t2 = e2->type;
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
    }
    else if (op == TOKdivass)
    {
        if (e2->type->isimaginary())
        {
            Type *t1 = e1->type;
            if (t1->isreal())
            {
                // x/iv = i(-x/v)
                // Therefore, the result is 0
                e2 = new CommaExp(loc, e2, new RealExp(loc, ldouble(0.0), t1));
                e2->type = t1;
                Expression *e = new AssignExp(loc, e1, e2);
                e->type = t1;
                return e;
            }
            else if (t1->isimaginary())
            {
                Type *t2;
                switch (t1->ty)
                {
                    case Timaginary32: t2 = Type::tfloat32; break;
                    case Timaginary64: t2 = Type::tfloat64; break;
                    case Timaginary80: t2 = Type::tfloat80; break;
                    default:
                        assert(0);
                }
                e2 = e2->castTo(sc, t2);
                Expression *e = new AssignExp(loc, e1, e2);
                e->type = t1;
                return e;
            }
        }
    }
    else if (op == TOKmodass)
    {
        if (e2->type->iscomplex())
        {
            error("cannot perform modulo complex arithmetic");
            return new ErrorExp();
        }
    }
    return this;
}

Expression *BinExp::incompatibleTypes()
{
    if (e1->type->toBasetype() != Type::terror &&
        e2->type->toBasetype() != Type::terror
       )
    {
        // CondExp uses 'a ? b : c' but we're comparing 'b : c'
        TOK thisOp = (op == TOKquestion) ? TOKcolon : op;
        if (e1->op == TOKtype || e2->op == TOKtype)
        {
            error("incompatible types for ((%s) %s (%s)): cannot use '%s' with types",
                e1->toChars(), Token::toChars(thisOp), e2->toChars(), Token::toChars(op));
        }
        else
        {
            error("incompatible types for ((%s) %s (%s)): '%s' and '%s'",
                e1->toChars(), Token::toChars(thisOp), e2->toChars(),
                e1->type->toChars(), e2->type->toChars());
        }
        return new ErrorExp();
    }
    return this;
}

/********************** BinAssignExp **************************************/

Expression *BinAssignExp::semantic(Scope *sc)
{
    if (type)
        return this;

    Expression *e = op_overload(sc);
    if (e)
        return e;

    e = e1->checkReadModifyWrite(op, e2);
    if (e)
        return e;

    if (e1->op == TOKarraylength)
    {
        // arr.length op= e2;
        e = ArrayLengthExp::rewriteOpAssign(this);
        e = e->semantic(sc);
        return e;
    }
    if (e1->op == TOKslice || e1->type->ty == Tarray || e1->type->ty == Tsarray)
    {
        // T[] op= ...
        if (e2->implicitConvTo(e1->type->nextOf()))
        {
            // T[] op= T
            e2 = e2->castTo(sc, e1->type->nextOf());
        }
        else if (Expression *ex = typeCombine(this, sc))
            return ex;
        type = e1->type;
        return arrayOp(this, sc);
    }

    e1 = e1->semantic(sc);
    e1 = e1->optimize(WANTvalue);
    e1 = e1->modifiableLvalue(sc, e1);
    type = e1->type;
    checkScalar();

    int arith = (op == TOKaddass || op == TOKminass || op == TOKmulass ||
                 op == TOKdivass || op == TOKmodass || op == TOKpowass);
    int bitwise = (op == TOKandass || op == TOKorass || op == TOKxorass);
    int shift = (op == TOKshlass || op == TOKshrass || op == TOKushrass);

    if (bitwise && type->toBasetype()->ty == Tbool)
         e2 = e2->implicitCastTo(sc, type);
    else
        checkNoBool();

    if ((op == TOKaddass || op == TOKminass) &&
        e1->type->toBasetype()->ty == Tpointer &&
        e2->type->toBasetype()->isintegral())
        return scaleFactor(this, sc);

    if (Expression *ex = typeCombine(this, sc))
        return ex;

    if (arith)
    {
        e1 = e1->checkArithmetic();
        e2 = e2->checkArithmetic();
    }
    if (bitwise || shift)
    {
        e1 = e1->checkIntegral();
        e2 = e2->checkIntegral();
    }
    if (shift)
    {
        e2 = e2->castTo(sc, Type::tshiftcnt);
    }

    // vectors
    if (shift && (e1->type->toBasetype()->ty == Tvector ||
                  e2->type->toBasetype()->ty == Tvector))
        return incompatibleTypes();

    int isvector = type->toBasetype()->ty == Tvector;

    if (op == TOKmulass && isvector && !e2->type->isfloating() &&
        ((TypeVector *)type->toBasetype())->elementType()->size(loc) != 2)
        return incompatibleTypes(); // Only short[8] and ushort[8] work with multiply

    if (op == TOKdivass && isvector && !e1->type->isfloating())
        return incompatibleTypes();

    if (op == TOKmodass && isvector)
        return incompatibleTypes();

    if (e1->op == TOKerror || e2->op == TOKerror)
        return new ErrorExp();

    e = checkComplexOpAssign(sc);
    if (e->op == TOKerror)
        return e;

    assert(e->op == TOKassign || e == this);
    return ((BinExp *)e)->reorderSettingAAElem(sc);
}

bool BinAssignExp::isLvalue()
{
    return true;
}

Expression *BinAssignExp::toLvalue(Scope *sc, Expression *ex)
{
    Expression *e;

    if (e1->op == TOKvar)
    {
        /* Convert (e1 op= e2) to
         *    e1 op= e2;
         *    e1
         */
        e = e1->copy();
        e = Expression::combine(this, e);
    }
    else
    {
        // toLvalue may be called from inline.c with sc == NULL,
        // but this branch should not be reached at that time.
        assert(sc);

        /* Convert (e1 op= e2) to
         *    ref v = e1;
         *    v op= e2;
         *    v
         */

        // ref v = e1;
        Identifier *id = Identifier::generateId("__assignop");
        ExpInitializer *ei = new ExpInitializer(loc, e1);
        VarDeclaration *v = new VarDeclaration(loc, e1->type, id, ei);
        v->storage_class |= STCtemp | STCref | STCforeach;
        Expression *de = new DeclarationExp(loc, v);

        // v op= e2
        e1 = new VarExp(e1->loc, v);

        e = new CommaExp(loc, de, this);
        e = new CommaExp(loc, e, new VarExp(loc, v));
        e = e->semantic(sc);
    }
    return e;
}

Expression *BinAssignExp::modifiableLvalue(Scope *sc, Expression *e)
{
    // should check e1->checkModifiable() ?
    return toLvalue(sc, this);
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
    sc = sc->startCTFE();
    e1 = e1->semantic(sc);
    e1 = resolveProperties(sc, e1);
    sc = sc->endCTFE();
    if (e1->op == TOKerror)
        return e1;
    if (!e1->type->isString())
    {
        error("argument to mixin must be a string type, not %s", e1->type->toChars());
        return new ErrorExp();
    }
    e1 = e1->ctfeInterpret();
    StringExp *se = e1->toStringExp();
    if (!se)
    {   error("argument to mixin must be a string, not (%s)", e1->toChars());
        return new ErrorExp();
    }
    se = se->toUTF8(sc);
    unsigned errors = global.errors;
    Parser p(loc, sc->module, (utf8_t *)se->string, se->len, 0);
    p.nextToken();
    //printf("p.loc.linnum = %d\n", p.loc.linnum);
    Expression *e = p.parseExpression();
    if (p.errors)
    {
        assert(global.errors != errors);        // should have caught all these cases
        return new ErrorExp();
    }
    if (p.token.value != TOKeof)
    {   error("incomplete mixin expression (%s)", se->toChars());
        return new ErrorExp();
    }
    return e->semantic(sc);
}

/************************************************************/

FileExp::FileExp(Loc loc, Expression *e)
        : UnaExp(loc, TOKmixin, sizeof(FileExp), e)
{
}

Expression *FileExp::semantic(Scope *sc)
{
    const char *name;
    StringExp *se;

#if LOGSEMANTIC
    printf("FileExp::semantic('%s')\n", toChars());
#endif
    sc = sc->startCTFE();
    e1 = e1->semantic(sc);
    e1 = resolveProperties(sc, e1);
    sc = sc->endCTFE();
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

    name = FileName::safeSearchPath(global.filePath, name);
    if (!name)
    {   error("file %s cannot be found or not in a path specified with -J", se->toChars());
        goto Lerror;
    }

    if (global.params.verbose)
        fprintf(global.stdmsg, "file      %s\t(%s)\n", (char *)se->string, name);
    if (global.params.moduleDeps != NULL)
    {
        OutBuffer *ob = global.params.moduleDeps;
        Module* imod = sc->instantiatingModule();

        if (!global.params.moduleDepsFile)
            ob->writestring("depsFile ");
        ob->writestring(imod->toPrettyChars());
        ob->writestring(" (");
        escapePath(ob, imod->srcfile->toChars());
        ob->writestring(") : ");
        if (global.params.moduleDepsFile)
            ob->writestring("string : ");
        ob->writestring((char *) se->string);
        ob->writestring(" (");
        escapePath(ob, name);
        ob->writestring(")");
        ob->writenl();
    }

    {   File f(name);
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

/************************************************************/

AssertExp::AssertExp(Loc loc, Expression *e, Expression *msg)
        : UnaExp(loc, TOKassert, sizeof(AssertExp), e)
{
    this->msg = msg;
}

Expression *AssertExp::syntaxCopy()
{
    return new AssertExp(loc, e1->syntaxCopy(), msg ? msg->syntaxCopy() : NULL);
}

Expression *AssertExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("AssertExp::semantic('%s')\n", toChars());
#endif
    if (Expression *ex = unaSemantic(sc))
        return ex;
    e1 = resolveProperties(sc, e1);
    // BUG: see if we can do compile time elimination of the Assert
    e1 = e1->optimize(WANTvalue);
    e1 = e1->checkToBoolean(sc);
    if (msg)
    {
        msg = msg->semantic(sc);
        msg = resolveProperties(sc, msg);
        msg = msg->implicitCastTo(sc, Type::tchar->constOf()->arrayOf());
        msg = msg->optimize(WANTvalue);
    }
    if (e1->op == TOKerror)
        return e1;
    if (msg && msg->op == TOKerror)
        return msg;
    if (e1->isBool(false))
    {
        FuncDeclaration *fd = sc->parent->isFuncDeclaration();
        if (fd)
            fd->hasReturnExp |= 4;

        if (!global.params.useAssert)
        {
            Expression *e = new HaltExp(loc);
            e = e->semantic(sc);
            return e;
        }
    }
    type = Type::tvoid;
    return this;
}

/************************************************************/

DotIdExp::DotIdExp(Loc loc, Expression *e, Identifier *ident)
        : UnaExp(loc, TOKdot, sizeof(DotIdExp), e)
{
    this->ident = ident;
}

DotIdExp *DotIdExp::create(Loc loc, Expression *e, Identifier *ident)
{
    return new DotIdExp(loc, e, ident);
}

Expression *DotIdExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("DotIdExp::semantic(this = %p, '%s')\n", this, toChars());
    //printf("e1->op = %d, '%s'\n", e1->op, Token::toChars(e1->op));
#endif
    Expression *e = semanticY(sc, 1);
    if (e && isDotOpDispatch(e))
    {
        unsigned errors = global.startGagging();
        e = resolvePropertiesX(sc, e);
        if (global.endGagging(errors))
            e = NULL;   /* fall down to UFCS */
        else
            return e;
    }
    if (!e)     // if failed to find the property
    {
        /* If ident is not a valid property, rewrite:
         *   e1.ident
         * as:
         *   .ident(e1)
         */
        e = resolveUFCSProperties(sc, this);
    }
    return e;
}

// Run sematnic in e1
Expression *DotIdExp::semanticX(Scope *sc)
{
    //printf("DotIdExp::semanticX(this = %p, '%s')\n", this, toChars());
    if (Expression *ex = unaSemantic(sc))
        return ex;

    if (ident == Id::mangleof)
    {
        // symbol.mangleof
        Dsymbol *ds;
        switch (e1->op)
        {
            case TOKimport:
                ds = ((ScopeExp *)e1)->sds;
                goto L1;
            case TOKvar:
                ds = ((VarExp *)e1)->var;
                goto L1;
            case TOKdotvar:
                ds = ((DotVarExp *)e1)->var;
                goto L1;
            case TOKoverloadset:
                ds = ((OverExp *)e1)->vars;
                goto L1;
            case TOKtemplate:
            {
                TemplateExp *te = (TemplateExp *)e1;
                ds = te->fd ? (Dsymbol *)te->fd : te->td;
            }
            L1:
            {
                assert(ds);
                if (FuncDeclaration *f = ds->isFuncDeclaration())
                {
                    if (!f->type->deco)
                    {
                        error("forward reference to %s", f->toChars());
                        return new ErrorExp();
                    }
                }
                const char* s = mangle(ds);
                Expression *e = new StringExp(loc, (void*)s, strlen(s));
                e = e->semantic(sc);
                return e;
            }
            default:
                break;
        }
    }

    if (e1->op == TOKvar && e1->type->toBasetype()->ty == Tsarray && ident == Id::length)
    {
        // bypass checkPurity
        return e1->type->dotExp(sc, e1, ident, 0);
    }

    if (e1->op == TOKdotexp)
    {
    }
    else
    {
        e1 = resolvePropertiesX(sc, e1);
    }
    if (e1->op == TOKtuple && ident == Id::offsetof)
    {   /* 'distribute' the .offsetof to each of the tuple elements.
         */
        TupleExp *te = (TupleExp *)e1;
        Expressions *exps = new Expressions();
        exps->setDim(te->exps->dim);
        for (size_t i = 0; i < exps->dim; i++)
        {   Expression *e = (*te->exps)[i];
            e = e->semantic(sc);
            e = new DotIdExp(e->loc, e, Id::offsetof);
            (*exps)[i] = e;
        }
        // Don't evaluate te->e0 in runtime
        Expression *e = new TupleExp(loc, NULL, exps);
        e = e->semantic(sc);
        return e;
    }

    if (e1->op == TOKtuple && ident == Id::length)
    {
        TupleExp *te = (TupleExp *)e1;
        // Don't evaluate te->e0 in runtime
        Expression *e = new IntegerExp(loc, te->exps->dim, Type::tsize_t);
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

    return this;
}

// Resolve e1.ident without seeing UFCS.
// If flag == 1, stop "not a property" error and return NULL.
Expression *DotIdExp::semanticY(Scope *sc, int flag)
{
    //printf("DotIdExp::semanticY(this = %p, '%s')\n", this, toChars());

//{ static int z; fflush(stdout); if (++z == 10) *(char*)0=0; }

    /* Special case: rewrite this.id and super.id
     * to be classtype.id and baseclasstype.id
     * if we have no this pointer.
     */
    if ((e1->op == TOKthis || e1->op == TOKsuper) && !hasThis(sc))
    {
        if (AggregateDeclaration *ad = sc->getStructClassScope())
        {
            if (e1->op == TOKthis)
            {
                e1 = new TypeExp(e1->loc, ad->type);
            }
            else
            {
                ClassDeclaration *cd = ad->isClassDeclaration();
                if (cd && cd->baseClass)
                    e1 = new TypeExp(e1->loc, cd->baseClass->type);
            }
        }
    }

    Expression *e = semanticX(sc);
    if (e != this)
        return e;

    Expression *eleft;
    Expression *eright;
    if (e1->op == TOKdotexp)
    {
        DotExp *de = (DotExp *)e1;
        eleft = de->e1;
        eright = de->e2;
    }
    else
    {
        eleft = NULL;
        eright = e1;
    }

    Type *t1b = e1->type->toBasetype();

    if (eright->op == TOKimport)        // also used for template alias's
    {
        ScopeExp *ie = (ScopeExp *)eright;

        /* Disable access to another module's private imports.
         * The check for 'is sds our current module' is because
         * the current module should have access to its own imports.
         */
        Dsymbol *s = ie->sds->search(loc, ident,
            (ie->sds->isModule() && ie->sds != sc->module) ? IgnorePrivateMembers : IgnoreNone);
        if (s)
        {
            /* Check for access before resolving aliases because public
             * aliases to private symbols are public.
             */
            if (Declaration *d = s->isDeclaration())
                accessCheck(loc, sc, NULL, d);

            s = s->toAlias();
            checkDeprecated(sc, s);

            EnumMember *em = s->isEnumMember();
            if (em)
            {
                return em->getVarExp(loc, sc);
            }

            VarDeclaration *v = s->isVarDeclaration();
            if (v)
            {
                //printf("DotIdExp:: Identifier '%s' is a variable, type '%s'\n", toChars(), v->type->toChars());
                if (v->inuse)
                {
                    error("circular reference to '%s'", v->toChars());
                    return new ErrorExp();
                }
                type = v->type;
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
                if (!f->functionSemantic())
                    return new ErrorExp();
                if (f->needThis())
                {
                    if (!eleft)
                        eleft = new ThisExp(loc);
                    e = new DotVarExp(loc, eleft, f);
                    e = e->semantic(sc);
                }
                else
                {
                    e = new VarExp(loc, f, 1);
                    if (eleft)
                    {   e = new CommaExp(loc, eleft, e);
                        e->type = f->type;
                    }
                }
                return e;
            }
            if (OverDeclaration *od = s->isOverDeclaration())
            {
                e = new VarExp(loc, od, 1);
                if (eleft)
                {
                    e = new CommaExp(loc, eleft, e);
                    e->type = Type::tvoid;  // ambiguous type?
                }
                return e;
            }
            OverloadSet *o = s->isOverloadSet();
            if (o)
            {   //printf("'%s' is an overload set\n", o->toChars());
                return new OverExp(loc, o);
            }

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
                //printf("it's a ScopeDsymbol %s\n", ident->toChars());
                e = new ScopeExp(loc, sds);
                e = e->semantic(sc);
                if (eleft)
                    e = new DotExp(loc, eleft, e);
                return e;
            }

            Import *imp = s->isImport();
            if (imp)
            {
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
        {
            char *p = ie->toChars();
            e = new StringExp(loc, p, strlen(p));
            e = e->semantic(sc);
            return e;
        }
        if (ie->sds->isPackage() ||
            ie->sds->isImport() ||
            ie->sds->isModule())
        {
            flag = 0;
        }
        if (flag)
            return NULL;
        s = ie->sds->search_correct(ident);
        if (s)
            error("undefined identifier '%s', did you mean '%s %s'?",
                  ident->toChars(), s->kind(), s->toChars());
        else
            error("undefined identifier '%s'", ident->toChars());
        return new ErrorExp();
    }
    else if (t1b->ty == Tpointer && e1->type->ty != Tenum &&
             ident != Id::init && ident != Id::__sizeof &&
             ident != Id::__xalignof && ident != Id::offsetof &&
             ident != Id::mangleof && ident != Id::stringof)
    {
        Type *t1bn = t1b->nextOf();
        if (flag)
        {
            AggregateDeclaration *ad = isAggregate(t1bn);
            if (ad && !ad->members)   // Bugzilla 11312
                return NULL;
        }

        /* Rewrite:
         *   p.ident
         * as:
         *   (*p).ident
         */
        if (flag && t1bn->ty == Tvoid)
            return NULL;
        e = new PtrExp(loc, e1);
        e = e->semantic(sc);
        return e->type->dotExp(sc, e, ident, flag);
    }
    else
    {
        if (e1->op == TOKtype || e1->op == TOKtemplate)
            flag = 0;
        e = e1->type->dotExp(sc, e1, ident, flag);
        if (!flag || e)
            e = e->semantic(sc);
        return e;
    }
}

/********************** DotTemplateExp ***********************************/

// Mainly just a placeholder

DotTemplateExp::DotTemplateExp(Loc loc, Expression *e, TemplateDeclaration *td)
        : UnaExp(loc, TOKdottd, sizeof(DotTemplateExp), e)

{
    this->td = td;
}

Expression *DotTemplateExp::semantic(Scope *sc)
{
    if (Expression *ex = unaSemantic(sc))
        return ex;
    return this;
}

/************************************************************/

DotVarExp::DotVarExp(Loc loc, Expression *e, Declaration *v, bool hasOverloads)
        : UnaExp(loc, TOKdotvar, sizeof(DotVarExp), e)
{
    //printf("DotVarExp()\n");
    this->var = v;
    this->hasOverloads = hasOverloads;
}

Expression *DotVarExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("DotVarExp::semantic('%s')\n", toChars());
#endif
    if (type)
        return this;

    var = var->toAlias()->isDeclaration();

    TupleDeclaration *tup = var->isTupleDeclaration();
    if (tup)
    {
        /* Replace:
         *  e1.tuple(a, b, c)
         * with:
         *  tuple(e1.a, e1.b, e1.c)
         */
        e1 = e1->semantic(sc);
        Expressions *exps = new Expressions;
        Expression *e0 = NULL;
        Expression *ev = e1;
        if (sc->func && !isTrivialExp(e1))
        {
            Identifier *id = Identifier::generateId("__tup");
            ExpInitializer *ei = new ExpInitializer(e1->loc, e1);
            VarDeclaration *v = new VarDeclaration(e1->loc, NULL, id, ei);
            v->storage_class |= STCtemp | STCctfe
                             | (e1->isLvalue() ? STCref | STCforeach : STCrvalue);
            e0 = new DeclarationExp(e1->loc, v);
            ev = new VarExp(e1->loc, v);
            e0 = e0->semantic(sc);
            ev = ev->semantic(sc);
        }

        exps->reserve(tup->objects->dim);
        for (size_t i = 0; i < tup->objects->dim; i++)
        {
            RootObject *o = (*tup->objects)[i];
            Expression *e;
            if (o->dyncast() == DYNCAST_EXPRESSION)
            {
                e = (Expression *)o;
                if (e->op == TOKdsymbol)
                {
                    Dsymbol *s = ((DsymbolExp *)e)->s;
                    e = new DotVarExp(loc, ev, s->isDeclaration());
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
                return new ErrorExp();
            }
            exps->push(e);
        }
        Expression *e = new TupleExp(loc, e0, exps);
        e = e->semantic(sc);
        return e;
    }

    e1 = e1->semantic(sc);
    e1 = e1->addDtorHook(sc);

    Type *t1 = e1->type;
    if (FuncDeclaration *fd = var->isFuncDeclaration())
    {
        // for functions, do checks after overload resolution
        if (!fd->functionSemantic())
            return new ErrorExp();

        /* Bugzilla 13843: If fd obviously has no overloads, we should
         * normalize AST, and it will give a chance to wrap fd with FuncExp.
         */
        if (fd->isNested() || fd->isFuncLiteralDeclaration())
        {
            // (e1, fd)
            Expression *e = new DsymbolExp(loc, fd);
            e = e->semantic(sc);
            return Expression::combine(e1, e);
        }

        type = fd->type;
        assert(type);
    }
    else if (OverDeclaration *od = var->isOverDeclaration())
    {
        type = Type::tvoid; // ambiguous type?
    }
    else
    {
        type = var->type;
        if (!type && global.errors)
        {
            // var is goofed up, just return 0
            return new ErrorExp();
        }
        assert(type);

        if (t1->ty == Tpointer)
            t1 = t1->nextOf();

        type = type->addMod(t1->mod);

        Dsymbol *vparent = var->toParent();
        AggregateDeclaration *ad = vparent ? vparent->isAggregateDeclaration() : NULL;

        if (Expression *e1x = getRightThis(loc, sc, ad, e1, var, 1))
            e1 = e1x;
        else
        {
            /* Later checkRightThis will report correct error for invalid field variable access.
             */
            Expression *e = new VarExp(loc, var);
            e = e->semantic(sc);
            return e;
        }
        accessCheck(loc, sc, e1, var);

        VarDeclaration *v = var->isVarDeclaration();
        if (v && (v->isDataseg() || (v->storage_class & STCmanifest)))
        {
            Expression *e = expandVar(WANTvalue, v);
            if (e)
                return e;
        }

        if (v && v->isDataseg())     // fix bugzilla 8238
        {
            // (e1, v)
            accessCheck(loc, sc, e1, v);
            Expression *e = new VarExp(loc, v);
            e = new CommaExp(loc, e1, e);
            e = e->semantic(sc);
            return e;
        }
    }

    //printf("-DotVarExp::semantic('%s')\n", toChars());
    return this;
}

bool DotVarExp::isLvalue()
{
    return true;
}

Expression *DotVarExp::toLvalue(Scope *sc, Expression *e)
{
    //printf("DotVarExp::toLvalue(%s)\n", toChars());
    return this;
}

/***********************************************
 * Mark variable v as modified if it is inside a constructor that var
 * is a field in.
 */
int modifyFieldVar(Loc loc, Scope *sc, VarDeclaration *var, Expression *e1)
{
    //printf("modifyFieldVar(var = %s)\n", var->toChars());
    Dsymbol *s = sc->func;
    while (1)
    {
        FuncDeclaration *fd = NULL;
        if (s)
            fd = s->isFuncDeclaration();
        if (fd &&
            ((fd->isCtorDeclaration() && var->isField()) ||
             (fd->isStaticCtorDeclaration() && !var->isField())) &&
            fd->toParent2() == var->toParent2() &&
            (!e1 || e1->op == TOKthis)
           )
        {
            var->ctorinit = 1;
            //printf("setting ctorinit\n");
            int result = true;
            if (var->isField() && sc->fieldinit && !sc->intypeof)
            {
                assert(e1);
                bool mustInit = (var->storage_class & STCnodefaultctor ||
                                 var->type->needsNested());

                size_t dim = sc->fieldinit_dim;
                AggregateDeclaration *ad = fd->isAggregateMember2();
                assert(ad);
                size_t i;
                for (i = 0; i < dim; i++)   // same as findFieldIndexByName in ctfeexp.c ?
                {
                    if (ad->fields[i] == var)
                        break;
                }
                assert(i < dim);
                unsigned fi = sc->fieldinit[i];
                if (fi & CSXthis_ctor)
                {
                    if (var->type->isMutable() && e1->type->isMutable())
                        result = false;
                    else
                    {
                        const char *modStr = !var->type->isMutable() ? MODtoChars(var->type->mod) : MODtoChars(e1->type->mod);
                        ::error(loc, "%s field '%s' initialized multiple times", modStr, var->toChars());
                    }
                }
                else if (sc->noctor || fi & CSXlabel)
                {
                    if (!mustInit && var->type->isMutable() && e1->type->isMutable())
                        result = false;
                    else
                    {
                        const char *modStr = !var->type->isMutable() ? MODtoChars(var->type->mod) : MODtoChars(e1->type->mod);
                        ::error(loc, "%s field '%s' initialization is not allowed in loops or after labels", modStr, var->toChars());
                    }
                }
                sc->fieldinit[i] |= CSXthis_ctor;
            }
            else if (fd != sc->func)
            {
                if (var->type->isMutable())
                    result = false;
                else if (sc->func->fes)
                {
                    const char *p = var->isField() ? "field" : var->kind();
                    ::error(loc, "%s %s '%s' initialization is not allowed in foreach loop",
                        MODtoChars(var->type->mod), p, var->toChars());
                }
                else
                {
                    const char *p = var->isField() ? "field" : var->kind();
                    ::error(loc, "%s %s '%s' initialization is not allowed in nested function '%s'",
                        MODtoChars(var->type->mod), p, var->toChars(), sc->func->toChars());
                }
            }
            return result;
        }
        else
        {
            if (s)
            {
                s = s->toParent2();
                continue;
            }
        }
        break;
    }
    return false;
}

int DotVarExp::checkModifiable(Scope *sc, int flag)
{
    //printf("DotVarExp::checkModifiable %s %s\n", toChars(), type->toChars());
    if (e1->op == TOKthis)
        return var->checkModify(loc, sc, type, e1, flag);

    //printf("\te1 = %s\n", e1->toChars());
    return e1->checkModifiable(sc, flag);
}

Expression *DotVarExp::modifiableLvalue(Scope *sc, Expression *e)
{
#if 0
    printf("DotVarExp::modifiableLvalue(%s)\n", toChars());
    printf("e1->type = %s\n", e1->type->toChars());
    printf("var->type = %s\n", var->type->toChars());
#endif

    return Expression::modifiableLvalue(sc, e);
}

/************************************************************/

/* Things like:
 *      foo.bar!(args)
 */

DotTemplateInstanceExp::DotTemplateInstanceExp(Loc loc, Expression *e, Identifier *name, Objects *tiargs)
        : UnaExp(loc, TOKdotti, sizeof(DotTemplateInstanceExp), e)
{
    //printf("DotTemplateInstanceExp()\n");
    this->ti = new TemplateInstance(loc, name);
    this->ti->tiargs = tiargs;
}

DotTemplateInstanceExp::DotTemplateInstanceExp(Loc loc, Expression *e, TemplateInstance *ti)
        : UnaExp(loc, TOKdotti, sizeof(DotTemplateInstanceExp), e)
{
    this->ti = ti;
}

Expression *DotTemplateInstanceExp::syntaxCopy()
{
    return new DotTemplateInstanceExp(loc,
        e1->syntaxCopy(),
        ti->name,
        TemplateInstance::arraySyntaxCopy(ti->tiargs));
}

bool DotTemplateInstanceExp::findTempDecl(Scope *sc)
{
#if LOGSEMANTIC
    printf("DotTemplateInstanceExp::findTempDecl('%s')\n", toChars());
#endif
    if (ti->tempdecl)
        return true;

    Expression *e = new DotIdExp(loc, e1, ti->name);
    e = e->semantic(sc);
    if (e->op == TOKdotexp)
        e = ((DotExp *)e)->e2;

    Dsymbol *s = NULL;
    switch (e->op)
    {
        case TOKoverloadset:    s = ((OverExp *)e)->vars;       break;
        case TOKdottd:          s = ((DotTemplateExp *)e)->td;  break;
        case TOKimport:         s = ((ScopeExp *)e)->sds;       break;
        case TOKdotvar:         s = ((DotVarExp *)e)->var;      break;
        case TOKvar:            s = ((VarExp *)e)->var;         break;
        default:                return false;
    }
    return ti->updateTempDecl(sc, s);
}

Expression *DotTemplateInstanceExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("DotTemplateInstanceExp::semantic('%s')\n", toChars());
#endif

    // Indicate we need to resolve by UFCS.
    Expression *e = semanticY(sc, 1);
    if (!e)
        e = resolveUFCSProperties(sc, this);
    return e;
}

// Resolve e1.ident!tiargs without seeing UFCS.
// If flag == 1, stop "not a property" error and return NULL.
Expression *DotTemplateInstanceExp::semanticY(Scope *sc, int flag)
{
#if LOGSEMANTIC
    printf("DotTemplateInstanceExpY::semantic('%s')\n", toChars());
#endif

    DotIdExp *die = new DotIdExp(loc, e1, ti->name);

    Expression *e = die->semanticX(sc);
    if (e == die)
    {
        e1 = die->e1;   // take back

        Type *t1b = e1->type->toBasetype();
        if (t1b->ty == Tarray || t1b->ty == Tsarray || t1b->ty == Taarray ||
            t1b->ty == Tnull  || (t1b->isTypeBasic() && t1b->ty != Tvoid))
        {
            /* No built-in type has templatized properties, so do shortcut.
             * It is necessary in: 1024.max!"a < b"
             */
            if (flag)
                return NULL;
        }
        e = die->semanticY(sc, flag);
        if (flag && e && isDotOpDispatch(e))
        {
            /* opDispatch!tiargs would be a function template that needs IFTI,
             * so it's not a template
             */
            e = NULL;   /* fall down to UFCS */
        }
        if (flag && !e)
            return NULL;
    }
    assert(e);

L1:
    if (e->op == TOKerror)
        return e;
    if (e->op == TOKdotvar)
    {
        DotVarExp *dve = (DotVarExp *)e;
        if (FuncDeclaration *fd = dve->var->isFuncDeclaration())
        {
            TemplateDeclaration *td = fd->findTemplateDeclRoot();
            if (td)
            {
                e = new DotTemplateExp(dve->loc, dve->e1, td);
                e = e->semantic(sc);
            }
        }
        else if (OverDeclaration *od = dve->var->isOverDeclaration())
        {
            e1 = dve->e1;   // pull semantic() result
            if (!findTempDecl(sc))
                goto Lerr;
            if (ti->needsTypeInference(sc))
                return this;
            ti->semantic(sc);
            if (!ti->inst || ti->errors)    // if template failed to expand
                return new ErrorExp();
            Dsymbol *s = ti->toAlias();
            Declaration *v = s->isDeclaration();
            if (v)
            {
                if (v->type && !v->type->deco)
                    v->type = v->type->semantic(v->loc, sc);
                e = new DotVarExp(loc, e1, v);
                e = e->semantic(sc);
                return e;
            }
            e = new ScopeExp(loc, ti);
            e = new DotExp(loc, e1, e);
            e = e->semantic(sc);
            return e;
        }
    }
    else if (e->op == TOKvar)
    {
        VarExp *ve = (VarExp *)e;
        if (FuncDeclaration *fd = ve->var->isFuncDeclaration())
        {
            TemplateDeclaration *td = fd->findTemplateDeclRoot();
            if (td)
            {
                e = new ScopeExp(ve->loc, td);
                e = e->semantic(sc);
            }
        }
        else if (OverDeclaration *od = ve->var->isOverDeclaration())
        {
            ti->tempdecl = od;
            e = new ScopeExp(loc, ti);
            e = e->semantic(sc);
            return e;
        }
    }
    if (e->op == TOKdottd)
    {
        DotTemplateExp *dte = (DotTemplateExp *)e;
        e1 = dte->e1;   // pull semantic() result

        ti->tempdecl = dte->td;
        if (!ti->semanticTiargs(sc))
            return new ErrorExp();
        if (ti->needsTypeInference(sc))
            return this;
        ti->semantic(sc);
        if (!ti->inst || ti->errors)    // if template failed to expand
            return new ErrorExp();
        Dsymbol *s = ti->toAlias();
        Declaration *v = s->isDeclaration();
        if (v && (v->isFuncDeclaration() || v->isVarDeclaration()))
        {
            e = new DotVarExp(loc, e1, v);
            e = e->semantic(sc);
            return e;
        }
        if (e1->op == TOKtype)
        {
            e = new DsymbolExp(loc, s);
            e = e->semantic(sc);
            return e;
        }
        e = new ScopeExp(loc, ti);
        e = new DotExp(loc, e1, e);
        e = e->semantic(sc);
        return e;
    }
    else if (e->op == TOKimport)
    {
        ScopeExp *se = (ScopeExp *)e;
        TemplateDeclaration *td = se->sds->isTemplateDeclaration();
        if (!td)
        {
            error("%s is not a template", e->toChars());
            return new ErrorExp();
        }
        ti->tempdecl = td;
        e = new ScopeExp(loc, ti);
        e = e->semantic(sc);
        return e;
    }
    else if (e->op == TOKdotexp)
    {
        DotExp *de = (DotExp *)e;
        e1 = de->e1;    // pull semantic() result

        if (de->e2->op == TOKoverloadset)
        {
            if (!findTempDecl(sc) ||
                !ti->semanticTiargs(sc))
            {
                return new ErrorExp();
            }
            if (ti->needsTypeInference(sc))
                return this;
            ti->semantic(sc);
            if (!ti->inst || ti->errors)    // if template failed to expand
                return new ErrorExp();
            Dsymbol *s = ti->toAlias();
            Declaration *v = s->isDeclaration();
            if (v)
            {
                if (v->type && !v->type->deco)
                    v->type = v->type->semantic(v->loc, sc);
                e = new DotVarExp(loc, e1, v);
                e = e->semantic(sc);
                return e;
            }
            e = new ScopeExp(loc, ti);
            e = new DotExp(loc, e1, e);
            e = e->semantic(sc);
            return e;
        }

        if (de->e2->op == TOKimport)
        {
            // This should *really* be moved to ScopeExp::semantic()
            ScopeExp *se = (ScopeExp *)de->e2;
            de->e2 = new DsymbolExp(loc, se->sds);
            de->e2 = de->e2->semantic(sc);
        }

        if (de->e2->op == TOKtemplate)
        {
            TemplateExp *te = (TemplateExp *) de->e2;
            e = new DotTemplateExp(loc,de->e1,te->td);
        }
        else
            goto Lerr;

        e = e->semantic(sc);
        if (e == de)
            goto Lerr;
        goto L1;
    }
    else if (e->op == TOKoverloadset)
    {
        OverExp *oe = (OverExp *)e;
        ti->tempdecl = oe->vars;
        e = new ScopeExp(loc, ti);
        e = e->semantic(sc);
        return e;
    }
Lerr:
    error("%s isn't a template", e->toChars());
    return new ErrorExp();
}

/************************************************************/

DelegateExp::DelegateExp(Loc loc, Expression *e, FuncDeclaration *f, bool hasOverloads)
        : UnaExp(loc, TOKdelegate, sizeof(DelegateExp), e)
{
    this->func = f;
    this->hasOverloads = hasOverloads;
}

Expression *DelegateExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("DelegateExp::semantic('%s')\n", toChars());
#endif
    if (type)
        return this;

    e1 = e1->semantic(sc);
    type = new TypeDelegate(func->type);
    type = type->semantic(loc, sc);
    AggregateDeclaration *ad = func->toParent()->isAggregateDeclaration();
    if (func->needThis())
        e1 = getRightThis(loc, sc, ad, e1, func);
    if (ad && ad->isClassDeclaration() && ad->type != e1->type)
    {
        // A downcast is required for interfaces, see Bugzilla 3706
        e1 = new CastExp(loc, e1, ad->type);
        e1 = e1->semantic(sc);
    }
    return this;
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
    if (Expression *ex = unaSemantic(sc))
        return ex;
    return this;
}

/************************************************************/

CallExp::CallExp(Loc loc, Expression *e, Expressions *exps)
        : UnaExp(loc, TOKcall, sizeof(CallExp), e)
{
    this->arguments = exps;
    this->f = NULL;
}

CallExp::CallExp(Loc loc, Expression *e)
        : UnaExp(loc, TOKcall, sizeof(CallExp), e)
{
    this->arguments = NULL;
    this->f = NULL;
}

CallExp::CallExp(Loc loc, Expression *e, Expression *earg1)
        : UnaExp(loc, TOKcall, sizeof(CallExp), e)
{
    Expressions *arguments = new Expressions();
    if (earg1)
    {
        arguments->setDim(1);
        (*arguments)[0] = earg1;
    }
    this->arguments = arguments;
    this->f = NULL;
}

CallExp::CallExp(Loc loc, Expression *e, Expression *earg1, Expression *earg2)
        : UnaExp(loc, TOKcall, sizeof(CallExp), e)
{
    Expressions *arguments = new Expressions();
    arguments->setDim(2);
    (*arguments)[0] = earg1;
    (*arguments)[1] = earg2;

    this->arguments = arguments;
    this->f = NULL;
}

CallExp *CallExp::create(Loc loc, Expression *e, Expressions *exps)
{
    return new CallExp(loc, e, exps);
}

CallExp *CallExp::create(Loc loc, Expression *e)
{
    return new CallExp(loc, e);
}

CallExp *CallExp::create(Loc loc, Expression *e, Expression *earg1)
{
    return new CallExp(loc, e, earg1);
}

Expression *CallExp::syntaxCopy()
{
    return new CallExp(loc, e1->syntaxCopy(), arraySyntaxCopy(arguments));
}

Expression *CallExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("CallExp::semantic() %s\n", toChars());
#endif
    if (type)
        return this;            // semantic() already run
#if 0
    if (arguments && arguments->dim)
    {
        Expression *earg = (*arguments)[0];
        earg->print();
        if (earg->type) earg->type->print();
    }
#endif

    Type *t1;
    Objects *tiargs = NULL;     // initial list of template arguments
    Expression *ethis = NULL;
    Type *tthis = NULL;
    Expression *e1org = e1;

    if (e1->op == TOKcomma)
    {
        /* Rewrite (a,b)(args) as (a,(b(args)))
         */
        CommaExp *ce = (CommaExp *)e1;
        e1 = ce->e2;
        e1->type = ce->type;
        ce->e2 = this;
        ce->type = NULL;
        return ce->semantic(sc);
    }

    if (e1->op == TOKdelegate)
    {
        DelegateExp *de = (DelegateExp *)e1;
        e1 = new DotVarExp(de->loc, de->e1, de->func);
        return semantic(sc);
    }

    if (e1->op == TOKfunction)
    {
        if (arrayExpressionSemantic(arguments, sc) ||
            preFunctionParameters(loc, sc, arguments))
        {
            return new ErrorExp();
        }

        // Run e1 semantic even if arguments have any errors
        FuncExp *fe = (FuncExp *)e1;
        e1 = fe->semantic(sc, arguments);
        if (e1->op == TOKerror)
            return e1;
    }

    if (Expression *ex = resolveUFCS(sc, this))
        return ex;

    /* This recognizes:
     *  foo!(tiargs)(funcargs)
     */
    if (e1->op == TOKimport && !e1->type)
    {
        ScopeExp *se = (ScopeExp *)e1;
        TemplateInstance *ti = se->sds->isTemplateInstance();
        if (ti)
        {
            /* Attempt to instantiate ti. If that works, go with it.
             * If not, go with partial explicit specialization.
             */
            WithScopeSymbol *withsym;
            if (!ti->findTempDecl(sc, &withsym) ||
                !ti->semanticTiargs(sc))
            {
                return new ErrorExp();
            }
            if (withsym && withsym->withstate->wthis)
            {
                e1 = new VarExp(e1->loc, withsym->withstate->wthis);
                e1 = new DotTemplateInstanceExp(e1->loc, e1, ti);
                goto Ldotti;
            }
            if (ti->needsTypeInference(sc, 1))
            {
                /* Go with partial explicit specialization
                 */
                tiargs = ti->tiargs;
                assert(ti->tempdecl);
                if (TemplateDeclaration *td = ti->tempdecl->isTemplateDeclaration())
                    e1 = new TemplateExp(loc, td);
                else if (OverDeclaration *od = ti->tempdecl->isOverDeclaration())
                    e1 = new VarExp(loc, od);
                else
                    e1 = new OverExp(loc, ti->tempdecl->isOverloadSet());
            }
            else
            {
                Expression *e1x = e1->semantic(sc);
                if (e1x->op == TOKerror)
                    return e1x;
                e1 = e1x;
            }
        }
    }

    /* This recognizes:
     *  expr.foo!(tiargs)(funcargs)
     */
Ldotti:
    if (e1->op == TOKdotti && !e1->type)
    {
        DotTemplateInstanceExp *se = (DotTemplateInstanceExp *)e1;
        TemplateInstance *ti = se->ti;
        {
            /* Attempt to instantiate ti. If that works, go with it.
             * If not, go with partial explicit specialization.
             */
            if (!se->findTempDecl(sc) ||
                !ti->semanticTiargs(sc))
            {
                return new ErrorExp();
            }
            if (ti->needsTypeInference(sc, 1))
            {
                /* Go with partial explicit specialization
                 */
                tiargs = ti->tiargs;
                assert(ti->tempdecl);
                if (TemplateDeclaration *td = ti->tempdecl->isTemplateDeclaration())
                    e1 = new DotTemplateExp(loc, se->e1, td);
                else if (OverDeclaration *od = ti->tempdecl->isOverDeclaration())
                {
                    e1 = new DotVarExp(loc, se->e1, od);
                }
                else
                    e1 = new DotExp(loc, se->e1, new OverExp(loc, ti->tempdecl->isOverloadSet()));
            }
            else
            {
                Expression *e1x = e1->semantic(sc);
                if (e1x->op == TOKerror)
                    return e1x;
                e1 = e1x;
            }
        }
    }

Lagain:
    //printf("Lagain: %s\n", toChars());
    f = NULL;
    if (e1->op == TOKthis || e1->op == TOKsuper)
    {
        // semantic() run later for these
    }
    else
    {
        if (e1->op == TOKdot)
        {
            DotIdExp *die = (DotIdExp *)e1;
            e1 = die->semantic(sc);
            /* Look for e1 having been rewritten to expr.opDispatch!(string)
             * We handle such earlier, so go back.
             * Note that in the rewrite, we carefully did not run semantic() on e1
             */
            if (e1->op == TOKdotti && !e1->type)
            {
                goto Ldotti;
            }
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
            Expression *ex = unaSemantic(sc);
            --nest;
            if (ex)
                return ex;
        }

        /* Look for e1 being a lazy parameter
         */
        if (e1->op == TOKvar)
        {
            VarExp *ve = (VarExp *)e1;
            if (ve->var->storage_class & STClazy)
            {
                // lazy paramaters can be called without violating purity and safety
                Type *tw = ve->var->type;
                Type *tc = ve->var->type->substWildTo(MODconst);
                TypeFunction *tf = new TypeFunction(NULL, tc, 0, LINKd, STCsafe | STCpure);
                (tf = (TypeFunction *)tf->semantic(loc, sc))->next = tw;    // hack for bug7757
                TypeDelegate *t = new TypeDelegate(tf);
                ve->type = t->semantic(loc, sc);
            }
            if (VarDeclaration *v = ve->var->isVarDeclaration())
                ve->checkPurity(sc, v);
        }

        if (e1->op == TOKimport)
        {
            // Perhaps this should be moved to ScopeExp::semantic()
            ScopeExp *se = (ScopeExp *)e1;
            e1 = new DsymbolExp(loc, se->sds);
            e1 = e1->semantic(sc);
        }
        else if (e1->op == TOKsymoff && ((SymOffExp *)e1)->hasOverloads)
        {
            SymOffExp *se = (SymOffExp *)e1;
            e1 = new VarExp(se->loc, se->var, 1);
            e1 = e1->semantic(sc);
        }
        else if (e1->op == TOKdotexp)
        {
            DotExp *de = (DotExp *) e1;

            if (de->e2->op == TOKoverloadset)
            {
                ethis = de->e1;
                tthis = de->e1->type;
                e1 = de->e2;
            }

            if (de->e2->op == TOKimport)
            {
                // This should *really* be moved to ScopeExp::semantic()
                ScopeExp *se = (ScopeExp *)de->e2;
                de->e2 = new DsymbolExp(loc, se->sds);
                de->e2 = de->e2->semantic(sc);
            }

            if (de->e2->op == TOKtemplate)
            {
                TemplateExp *te = (TemplateExp *) de->e2;
                e1 = new DotTemplateExp(loc,de->e1,te->td);
            }
        }
        else if (e1->op == TOKstar && e1->type->ty == Tfunction)
        {
            // Rewrite (*fp)(arguments) to fp(arguments)
            e1 = ((PtrExp *)e1)->e1;
        }
    }

    t1 = NULL;
    if (e1->type)
    {
        t1 = e1->type->toBasetype();

        if (t1->ty == Tstruct)
        {
            AggregateDeclaration *ad = ((TypeStruct *)t1)->sym;
            if (ad->sizeok == SIZEOKnone)
            {
                if (ad->scope)
                    ad->semantic(ad->scope);
                else if (!ad->ctor && ad->search(Loc(), Id::ctor))
                {
                    // The constructor hasn't been found yet, see bug 8741
                    // This can happen if we are inferring type from
                    // from VarDeclaration::semantic() in declaration.c
                    error("cannot create a struct until its size is determined");
                    return new ErrorExp();
                }
            }
        }
    }

    if (e1->op == TOKerror)
        return e1;
    if (arrayExpressionSemantic(arguments, sc) ||
        preFunctionParameters(loc, sc, arguments))
    {
        return new ErrorExp();
    }

    // Check for call operator overload
    if (t1)
    {
        if (t1->ty == Tstruct)
        {
            StructDeclaration *sd = ((TypeStruct *)t1)->sym;

            // First look for constructor
            if (e1->op == TOKtype && sd->ctor)
            {
                if (!sd->noDefaultCtor && !(arguments && arguments->dim))
                    goto Lx;

                StructLiteralExp *sle = new StructLiteralExp(loc, sd, NULL, e1->type);
                if (!sd->fill(loc, sle->elements, true))
                    return new ErrorExp();

                /* Copy from the initializer symbol for larger symbols,
                 * otherwise the literals expressed as code get excessively large.
                 */
                if (sd->size(loc) > Target::ptrsize * 4 && !t1->needsNested())
                    sle->sinit = toInitializer(sd);

                sle->type = type;

                Expression *e = sle;
                if (CtorDeclaration *cf = sd->ctor->isCtorDeclaration())
                {
                    e = new DotVarExp(loc, e, cf, 1);
                }
                else if (TemplateDeclaration *td = sd->ctor->isTemplateDeclaration())
                {
                    e = new DotTemplateExp(loc, e, td);
                }
                else if (OverloadSet *os = sd->ctor->isOverloadSet())
                {
                    e = new DotExp(loc, e, new OverExp(loc, os));
                }
                else
                    assert(0);
                e = new CallExp(loc, e, arguments);
                e = e->semantic(sc);
                return e;
            }
            // No constructor, look for overload of opCall
            if (search_function(sd, Id::call))
                goto L1;        // overload of opCall, therefore it's a call

            if (e1->op != TOKtype)
            {
                if (sd->aliasthis && e1->type != att1)
                {
                    if (!att1 && e1->type->checkAliasThisRec())
                        att1 = e1->type;
                    e1 = resolveAliasThis(sc, e1);
                    goto Lagain;
                }
                error("%s %s does not overload ()", sd->kind(), sd->toChars());
                return new ErrorExp();
            }

            /* It's a struct literal
             */
        Lx:
            Expression *e = new StructLiteralExp(loc, sd, arguments, e1->type);
            e = e->semantic(sc);
            return e;
        }
        else if (t1->ty == Tclass)
        {
        L1:
            // Rewrite as e1.call(arguments)
            Expression *e = new DotIdExp(loc, e1, Id::call);
            e = new CallExp(loc, e, arguments);
            e = e->semantic(sc);
            return e;
        }
        else if (e1->op == TOKtype && t1->isscalar())
        {
            Expression *e;
            if (!arguments || arguments->dim == 0)
            {
                e = t1->defaultInitLiteral(loc);
            }
            else if (arguments->dim == 1)
            {
                e = (*arguments)[0];
                e = e->implicitCastTo(sc, t1);
                e = new CastExp(loc, e, t1);
            }
            else
            {
                error("more than one argument for construction of %s", t1->toChars());
                e = new ErrorExp();
            }
            e = e->semantic(sc);
            return e;
        }
    }

    if (e1->op == TOKdotvar && t1->ty == Tfunction ||
        e1->op == TOKdottd)
    {
        UnaExp *ue = (UnaExp *)(e1);

        Expression *ue1 = ue->e1;
        Expression *ue1old = ue1;   // need for 'right this' check
        VarDeclaration *v;
        if (ue1->op == TOKvar &&
            (v = ((VarExp *)ue1)->var->isVarDeclaration()) != NULL &&
            v->needThis())
        {
            ue->e1 = new TypeExp(ue1->loc, ue1->type);
            ue1 = NULL;
        }

        DotVarExp *dve;
        DotTemplateExp *dte;
        Dsymbol *s;
        if (e1->op == TOKdotvar)
        {
            dve = (DotVarExp *)(e1);
            dte = NULL;
            s = dve->var;
            tiargs = NULL;
        }
        else
        {
            dve = NULL;
            dte = (DotTemplateExp *)(e1);
            s = dte->td;
        }

        // Do overload resolution
        f = resolveFuncCall(loc, sc, s, tiargs, ue1 ? ue1->type : NULL, arguments);
        if (!f || f->errors || f->type->ty == Terror)
            return new ErrorExp();

        if (f->needThis())
        {
            AggregateDeclaration *ad = f->toParent2()->isAggregateDeclaration();
            ue->e1 = getRightThis(loc, sc, ad, ue->e1, f);
            if (ue->e1->op == TOKerror)
                return ue->e1;
            ethis = ue->e1;
            tthis = ue->e1->type;
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
        checkPurity(sc, f);
        checkSafety(sc, f);
        checkNogc(sc, f);
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
            checkRightThis(sc, ue1old);
            if (e1->op == TOKdotvar)
            {
                dve->var = f;
                e1->type = f->type;
            }
            else
            {
                e1 = new DotVarExp(loc, dte->e1, f);
                e1 = e1->semantic(sc);
                if (e1->op == TOKerror)
                    return new ErrorExp();
                ue = (UnaExp *)e1;
            }
#if 0
            printf("ue->e1 = %s\n", ue->e1->toChars());
            printf("f = %s\n", f->toChars());
            printf("t = %s\n", t->toChars());
            printf("e1 = %s\n", e1->toChars());
            printf("e1->type = %s\n", e1->type->toChars());
#endif

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

        if (sc->func && sc->func->isThis())
            cd = sc->func->isThis()->isClassDeclaration();
        if (!cd || !cd->baseClass || !sc->func->isCtorDeclaration())
        {
            error("super class constructor call must be in a constructor");
            return new ErrorExp();
        }
        else
        {
            if (!cd->baseClass->ctor)
            {   error("no super class constructor for %s", cd->baseClass->toChars());
                return new ErrorExp();
            }
            else
            {
                if (!sc->intypeof)
                {
                    if (sc->noctor || sc->callSuper & CSXlabel)
                        error("constructor calls not allowed in loops or after labels");
                    if (sc->callSuper & (CSXsuper_ctor | CSXthis_ctor))
                        error("multiple constructor calls");
                    if ((sc->callSuper & CSXreturn) && !(sc->callSuper & CSXany_ctor))
                        error("an earlier return statement skips constructor");
                    sc->callSuper |= CSXany_ctor | CSXsuper_ctor;
                }

                tthis = cd->type->addMod(sc->func->type->mod);
                f = resolveFuncCall(loc, sc, cd->baseClass->ctor, NULL, tthis, arguments, 0);
                if (!f || f->errors)
                    return new ErrorExp();
                accessCheck(loc, sc, NULL, f);
                checkDeprecated(sc, f);
                checkPurity(sc, f);
                checkSafety(sc, f);
                checkNogc(sc, f);
                e1 = new DotVarExp(e1->loc, e1, f);
                e1 = e1->semantic(sc);
                t1 = e1->type;
            }
        }
    }
    else if (e1->op == TOKthis)
    {
        // same class constructor call
        AggregateDeclaration *cd = NULL;

        if (sc->func && sc->func->isThis())
            cd = sc->func->isThis()->isAggregateDeclaration();
        if (!cd || !sc->func->isCtorDeclaration())
        {
            error("constructor call must be in a constructor");
            return new ErrorExp();
        }
        else
        {
            if (!sc->intypeof)
            {
                if (sc->noctor || sc->callSuper & CSXlabel)
                    error("constructor calls not allowed in loops or after labels");
                if (sc->callSuper & (CSXsuper_ctor | CSXthis_ctor))
                    error("multiple constructor calls");
                if ((sc->callSuper & CSXreturn) && !(sc->callSuper & CSXany_ctor))
                    error("an earlier return statement skips constructor");
                sc->callSuper |= CSXany_ctor | CSXthis_ctor;
            }

            tthis = cd->type->addMod(sc->func->type->mod);
            f = resolveFuncCall(loc, sc, cd->ctor, NULL, tthis, arguments, 0);
            if (!f || f->errors)
                return new ErrorExp();
            checkDeprecated(sc, f);
            checkPurity(sc, f);
            checkSafety(sc, f);
            checkNogc(sc, f);
            e1 = new DotVarExp(e1->loc, e1, f);
            e1 = e1->semantic(sc);
            t1 = e1->type;

            // BUG: this should really be done by checking the static
            // call graph
            if (f == sc->func)
            {
                error("cyclic constructor call");
                return new ErrorExp();
            }
        }
    }
    else if (e1->op == TOKoverloadset)
    {
        OverExp *eo = (OverExp *)e1;
        FuncDeclaration *f = NULL;
        Dsymbol *s = NULL;
        for (size_t i = 0; i < eo->vars->a.dim; i++)
        {
            s = eo->vars->a[i];
            if (tiargs && s->isFuncDeclaration())
                continue;
            FuncDeclaration *f2 = resolveFuncCall(loc, sc, s, tiargs, tthis, arguments, 1);
            if (f2)
            {
                if (f2->errors)
                    return new ErrorExp();
                if (f)
                {
                    /* Error if match in more than one overload set,
                     * even if one is a 'better' match than the other.
                     */
                    ScopeDsymbol::multiplyDefined(loc, f, f2);
                }
                else
                    f = f2;
            }
        }
        if (!f)
        {   /* No overload matches
             */
            error("no overload matches for %s", s->toChars());
            return new ErrorExp();
        }
        if (ethis)
            e1 = new DotVarExp(loc, ethis, f);
        else
            e1 = new VarExp(loc, f);
        goto Lagain;
    }
    else if (!t1)
    {
        error("function expected before (), not '%s'", e1->toChars());
        return new ErrorExp();
    }
    else if (t1->ty == Terror)
        return new ErrorExp();
    else if (t1->ty != Tfunction)
    {
        TypeFunction *tf;
        const char *p;
        Dsymbol *s;
        f = NULL;
        if (e1->op == TOKfunction)
        {
            // function literal that direct called is always inferred.
            assert(((FuncExp *)e1)->fd);
            f = ((FuncExp *)e1)->fd;
            tf = (TypeFunction *)f->type;
            p = "function literal";
        }
        else if (t1->ty == Tdelegate)
        {
            TypeDelegate *td = (TypeDelegate *)t1;
            assert(td->next->ty == Tfunction);
            tf = (TypeFunction *)(td->next);
            p = "delegate";
        }
        else if (t1->ty == Tpointer && ((TypePointer *)t1)->next->ty == Tfunction)
        {
            tf = (TypeFunction *)(((TypePointer *)t1)->next);
            p = "function pointer";
        }
        else if (e1->op == TOKdotvar &&
                 ((DotVarExp *)e1)->var->isOverDeclaration())
        {
            DotVarExp *dve = (DotVarExp *)e1;
            f = resolveFuncCall(loc, sc, dve->var, tiargs, dve->e1->type, arguments, 2);
            if (!f)
                return new ErrorExp();
            if (f->needThis())
            {
                dve->var = f;
                dve->type = f->type;
                dve->hasOverloads = 0;
                goto Lagain;
            }
            e1 = new VarExp(dve->loc, f, 0);
            Expression *e = new CommaExp(loc, dve->e1, this);
            return e->semantic(sc);
        }
        else if (e1->op == TOKvar &&
                 ((VarExp *)e1)->var->isOverDeclaration())
        {
            s = ((VarExp *)e1)->var;
            goto L2;
        }
        else if (e1->op == TOKtemplate)
        {
            s = ((TemplateExp *)e1)->td;
        L2:
            f = resolveFuncCall(loc, sc, s, tiargs, NULL, arguments, 2);
            if (!f || f->errors)
                return new ErrorExp();
            if (f->needThis())
            {
                if (hasThis(sc))
                {
                    // Supply an implicit 'this', as in
                    //    this.ident
                    e1 = new DotVarExp(loc, (new ThisExp(loc))->semantic(sc), f);
                    goto Lagain;
                }
                else if (isNeedThisScope(sc, f))
                {
                    error("need 'this' for '%s' of type '%s'", f->toChars(), f->type->toChars());
                    return new ErrorExp();
                }
            }
            e1 = new VarExp(e1->loc, f, 0);
            goto Lagain;
        }
        else
        {
            error("function expected before (), not %s of type %s", e1->toChars(), e1->type->toChars());
            return new ErrorExp();
        }

        if (!tf->callMatch(NULL, arguments))
        {
            OutBuffer buf;

            buf.writeByte('(');
            argExpTypesToCBuffer(&buf, arguments);
            buf.writeByte(')');
            if (tthis)
                tthis->modToBuffer(&buf);

            //printf("tf = %s, args = %s\n", tf->deco, (*arguments)[0]->type->deco);
            ::error(loc, "%s %s %s is not callable using argument types %s",
                p, e1->toChars(), parametersTypeToChars(tf->parameters, tf->varargs),
                buf.peekString());

            return new ErrorExp();
        }

        // Purity and safety check should run after testing arguments matching
        if (f)
        {
            checkPurity(sc, f);
            checkSafety(sc, f);
            checkNogc(sc, f);
            if (!f->checkNestedReference(sc, loc))
                return new ErrorExp();
        }
        else if (sc->func && sc->intypeof != 1 && !(sc->flags & SCOPEctfe))
        {
            bool err = false;
            if (!tf->purity && !(sc->flags & SCOPEdebug) && sc->func->setImpure())
            {
                error("pure function '%s' cannot call impure %s '%s'", sc->func->toPrettyChars(), p, e1->toChars());
                err = true;
            }
            if (!tf->isnogc && sc->func->setGC())
            {
                error("@nogc function '%s' cannot call non-@nogc %s '%s'", sc->func->toPrettyChars(), p, e1->toChars());
                err = true;
            }
            if (tf->trust <= TRUSTsystem && sc->func->setUnsafe())
            {
                error("safe function '%s' cannot call system %s '%s'", sc->func->toPrettyChars(), p, e1->toChars());
                err = true;
            }
            if (err)
                return new ErrorExp();
        }

        if (t1->ty == Tpointer)
        {
            Expression *e = new PtrExp(loc, e1);
            e->type = tf;
            e1 = e;
        }
        t1 = tf;
    }
    else if (e1->op == TOKvar)
    {
        // Do overload resolution
        VarExp *ve = (VarExp *)e1;

        f = ve->var->isFuncDeclaration();
        assert(f);
        tiargs = NULL;

        if (ve->hasOverloads)
            f = resolveFuncCall(loc, sc, f, tiargs, NULL, arguments, 2);
        else
        {
            f = f->toAliasFunc();
            TypeFunction *tf = (TypeFunction *)f->type;
            if (!tf->callMatch(NULL, arguments))
            {
                OutBuffer buf;

                buf.writeByte('(');
                argExpTypesToCBuffer(&buf, arguments);
                buf.writeByte(')');

                //printf("tf = %s, args = %s\n", tf->deco, (*arguments)[0]->type->deco);
                ::error(loc, "%s %s is not callable using argument types %s",
                    e1->toChars(), parametersTypeToChars(tf->parameters, tf->varargs),
                    buf.peekString());

                f = NULL;
            }
        }
        if (!f || f->errors)
            return new ErrorExp();

        if (f->needThis())
        {
            if (hasThis(sc))
            {
                // Supply an implicit 'this', as in
                //    this.ident

                e1 = new DotVarExp(loc, (new ThisExp(loc))->semantic(sc), ve->var);
                goto Lagain;
            }
            else if (isNeedThisScope(sc, f))
            {
                error("need 'this' for '%s' of type '%s'", f->toChars(), f->type->toChars());
                return new ErrorExp();
            }
        }

        checkDeprecated(sc, f);
        checkPurity(sc, f);
        checkSafety(sc, f);
        checkNogc(sc, f);
        if (!f->checkNestedReference(sc, loc))
            return new ErrorExp();
        accessCheck(loc, sc, NULL, f);

        ethis = NULL;
        tthis = NULL;

        if (ve->hasOverloads)
        {
            e1 = new VarExp(ve->loc, f, 0);
            e1->type = f->type;
        }
        t1 = f->type;
    }
    assert(t1->ty == Tfunction);

    Expression *argprefix;
    if (!arguments)
        arguments = new Expressions();
    if (functionParameters(loc, sc, (TypeFunction *)(t1), tthis, arguments, f, &type, &argprefix))
        return new ErrorExp();

    if (!type)
    {
        e1 = e1org;     // Bugzilla 10922, avoid recursive expression printing
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
            return combine(argprefix, castTo(sc, t));
        }
    }

    // Handle the case of a direct lambda call
    if (f && f->isFuncLiteralDeclaration() &&
        sc->func && !sc->intypeof)
    {
        f->tookAddressOf = 0;
    }

    return combine(argprefix, this);
}



bool CallExp::isLvalue()
{
    Type *tb = e1->type->toBasetype();
    if (tb->ty == Tdelegate || tb->ty == Tpointer)
        tb = tb->nextOf();
    if (tb->ty == Tfunction && ((TypeFunction *)tb)->isref)
    {
        if (e1->op == TOKdotvar)
            if (((DotVarExp *)e1)->var->isCtorDeclaration())
                return false;
        return true;               // function returns a reference
    }
    return false;
}

Expression *CallExp::toLvalue(Scope *sc, Expression *e)
{
    if (isLvalue())
        return this;
    return Expression::toLvalue(sc, e);
}

Expression *CallExp::addDtorHook(Scope *sc)
{
    /* Only need to add dtor hook if it's a type that needs destruction.
     * Use same logic as VarDeclaration::callScopeDtor()
     */

    if (e1->type && e1->type->ty == Tfunction)
    {
        TypeFunction *tf = (TypeFunction *)e1->type;
        if (tf->isref)
            return this;
    }

    Type *tv = type->baseElemOf();
    if (tv->ty == Tstruct)
    {
        TypeStruct *ts = (TypeStruct *)tv;
        StructDeclaration *sd = ts->sym;
        if (sd->dtor)
        {
            /* Type needs destruction, so declare a tmp
             * which the back end will recognize and call dtor on
             */
            Identifier *idtmp = Identifier::generateId("__tmpfordtor");
            VarDeclaration *tmp = new VarDeclaration(loc, type, idtmp, new ExpInitializer(loc, this));
            tmp->storage_class |= STCtemp | STCctfe;
            Expression *ae = new DeclarationExp(loc, tmp);
            Expression *e = new CommaExp(loc, ae, new VarExp(loc, tmp));
            e = e->semantic(sc);
            return e;
        }
    }
    return this;
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
    if (type)
        return this;

    if (Expression *ex = unaSemantic(sc))
        return ex;
    int wasCond = e1->op == TOKquestion;
    if (e1->op == TOKdotti)
    {
        DotTemplateInstanceExp* dti = (DotTemplateInstanceExp *)e1;
        TemplateInstance *ti = dti->ti;
        {
            //assert(ti->needsTypeInference(sc));
            ti->semantic(sc);
            if (!ti->inst || ti->errors)    // if template failed to expand
                return new ErrorExp;
            Dsymbol *s = ti->toAlias();
            FuncDeclaration *f = s->isFuncDeclaration();
            if (f)
            {
                e1 = new DotVarExp(e1->loc, dti->e1, f);
                e1 = e1->semantic(sc);
            }
        }
    }
    else if (e1->op == TOKimport)
    {
        TemplateInstance *ti = ((ScopeExp *)e1)->sds->isTemplateInstance();
        if (ti)
        {
            //assert(ti->needsTypeInference(sc));
            ti->semantic(sc);
            if (!ti->inst || ti->errors)    // if template failed to expand
                return new ErrorExp;
            Dsymbol *s = ti->toAlias();
            FuncDeclaration *f = s->isFuncDeclaration();
            if (f)
            {
                e1 = new VarExp(e1->loc, f);
                e1 = e1->semantic(sc);
            }
        }
    }
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

        if (e1->op == TOKvar)
        {
            VarExp *ve = (VarExp *)e1;
            Declaration *d = ve->var;
            error("forward reference to %s %s", d->kind(), d->toChars());
        }
        else
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
            f = f->toAliasFunc();   // FIXME, should see overlods - Bugzilla 1983
            if (!dve->hasOverloads)
                f->tookAddressOf++;

            Expression *e;
            if ( f->needThis())
                e = new DelegateExp(loc, dve->e1, f, dve->hasOverloads);
            else // It is a function pointer. Convert &v.f() --> (v, &V.f())
                e = new CommaExp(loc, dve->e1, new AddrExp(loc, new VarExp(loc, f)));
            e = e->semantic(sc);
            return e;
        }
    }
    else if (e1->op == TOKvar)
    {
        VarExp *ve = (VarExp *)e1;

        VarDeclaration *v = ve->var->isVarDeclaration();
        if (v)
        {
            if (!v->canTakeAddressOf())
            {
                error("cannot take address of %s", e1->toChars());
                return new ErrorExp();
            }

            if (sc->func && !sc->intypeof && !v->isDataseg())
            {
                if (sc->func->setUnsafe())
                {
                    const char *p = v->isParameter() ? "parameter" : "local";
                    error("cannot take address of %s %s in @safe function %s",
                        p,
                        v->toChars(),
                        sc->func->toChars());
                }
            }
        }

        FuncDeclaration *f = ve->var->isFuncDeclaration();
        if (f)
        {
            /* Because nested functions cannot be overloaded,
             * mark here that we took its address because castTo()
             * may not be called with an exact match.
             */
            if (!ve->hasOverloads || f->isNested())
                f->tookAddressOf++;
            if (f->isNested())
            {
                if (f->isFuncLiteralDeclaration())
                {
                    if (!f->FuncDeclaration::isNested())
                    {
                        /* Supply a 'null' for a this pointer if no this is available
                         */
                        Expression *e = new DelegateExp(loc, new NullExp(loc, Type::tnull), f, ve->hasOverloads);
                        e = e->semantic(sc);
                        return e;
                    }
                }
                Expression *e = new DelegateExp(loc, e1, f, ve->hasOverloads);
                e = e->semantic(sc);
                return e;
            }
            if (f->needThis() && hasThis(sc))
            {
                /* Should probably supply 'this' after overload resolution,
                 * not before.
                 */
                Expression *ethis = new ThisExp(loc);
                Expression *e = new DelegateExp(loc, ethis, f, ve->hasOverloads);
                e = e->semantic(sc);
                return e;
            }
        }
    }
    else if (wasCond)
    {
        /* a ? b : c was transformed to *(a ? &b : &c), but we still
         * need to do safety checks
         */
        assert(e1->op == TOKstar);
        PtrExp *pe = (PtrExp *)e1;
        assert(pe->e1->op == TOKquestion);
        CondExp *ce = (CondExp *)pe->e1;
        assert(ce->e1->op == TOKaddress);
        assert(ce->e2->op == TOKaddress);

        // Re-run semantic on the address expressions only
        ce->e1->type = NULL;
        ce->e1 = ce->e1->semantic(sc);
        ce->e2->type = NULL;
        ce->e2 = ce->e2->semantic(sc);
    }

    return optimize(WANTvalue);
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
    if (type)
        return this;

    Expression *e = op_overload(sc);
    if (e)
        return e;

    Type *tb = e1->type->toBasetype();
    switch (tb->ty)
    {
        case Tpointer:
            type = ((TypePointer *)tb)->next;
            break;

        case Tsarray:
        case Tarray:
            error("using * on an array is no longer supported; use *(%s).ptr instead", e1->toChars());
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

    return this;
}

bool PtrExp::isLvalue()
{
    return true;
}

Expression *PtrExp::toLvalue(Scope *sc, Expression *e)
{
    return this;
}

int PtrExp::checkModifiable(Scope *sc, int flag)
{
    if (e1->op == TOKsymoff)
    {   SymOffExp *se = (SymOffExp *)e1;
        return se->var->checkModify(loc, sc, type, NULL, flag);
    }
    else if (e1->op == TOKaddress)
    {
        AddrExp *ae = (AddrExp *)e1;
        return ae->e1->checkModifiable(sc, flag);
    }
    return 1;
}

Expression *PtrExp::modifiableLvalue(Scope *sc, Expression *e)
{
    //printf("PtrExp::modifiableLvalue() %s, type %s\n", toChars(), type->toChars());
    return Expression::modifiableLvalue(sc, e);
}

/************************************************************/

NegExp::NegExp(Loc loc, Expression *e)
        : UnaExp(loc, TOKneg, sizeof(NegExp), e)
{
}

Expression *NegExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("NegExp::semantic('%s')\n", toChars());
#endif
    if (type)
        return this;

    Expression *e = op_overload(sc);
    if (e)
        return e;

    type = e1->type;
    Type *tb = type->toBasetype();
    if (tb->ty == Tarray || tb->ty == Tsarray)
    {
        if (!isArrayOpValid(e1))
        {
            error("invalid array operation %s (possible missing [])", toChars());
            return new ErrorExp();
        }
        return this;
    }

    e1->checkNoBool();
    e1 = e1->checkArithmetic();
    if (e1->op == TOKerror)
        return e1;

    return this;
}

/************************************************************/

UAddExp::UAddExp(Loc loc, Expression *e)
        : UnaExp(loc, TOKuadd, sizeof(UAddExp), e)
{
}

Expression *UAddExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("UAddExp::semantic('%s')\n", toChars());
#endif
    assert(!type);

    Expression *e = op_overload(sc);
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
{
    if (type)
        return this;

    Expression *e = op_overload(sc);
    if (e)
        return e;

    type = e1->type;
    Type *tb = type->toBasetype();
    if (tb->ty == Tarray || tb->ty == Tsarray)
    {
        if (!isArrayOpValid(e1))
        {
            error("invalid array operation %s (possible missing [])", toChars());
            return new ErrorExp();
        }
        return this;
    }

    e1->checkNoBool();
    e1 = e1->checkIntegral();
    if (e1->op == TOKerror)
        return e1;

    return this;
}

/************************************************************/

NotExp::NotExp(Loc loc, Expression *e)
        : UnaExp(loc, TOKnot, sizeof(NotExp), e)
{
}

Expression *NotExp::semantic(Scope *sc)
{
    if (type)
        return this;

    // Note there is no operator overload
    if (Expression *ex = unaSemantic(sc))
        return ex;
    e1 = resolveProperties(sc, e1);
    e1 = e1->checkToBoolean(sc);
    if (e1->type == Type::terror)
        return e1;

    // Bugzilla 13910: Today NotExp can take an array as its operand.
    if (checkNonAssignmentArrayOp(e1))
        return new ErrorExp();

    type = Type::tbool;
    return this;
}

/************************************************************/

BoolExp::BoolExp(Loc loc, Expression *e, Type *t)
        : UnaExp(loc, TOKtobool, sizeof(BoolExp), e)
{
    type = t;
}

Expression *BoolExp::semantic(Scope *sc)
{
    if (type)
        return this;

    // Note there is no operator overload
    if (Expression *ex = unaSemantic(sc))
        return ex;
    e1 = resolveProperties(sc, e1);
    e1 = e1->checkToBoolean(sc);
    if (e1->type == Type::terror)
        return e1;

    type = Type::tbool;
    return this;
}

/************************************************************/

DeleteExp::DeleteExp(Loc loc, Expression *e)
        : UnaExp(loc, TOKdelete, sizeof(DeleteExp), e)
{
}

Expression *DeleteExp::semantic(Scope *sc)
{
    if (Expression *ex = unaSemantic(sc))
        return ex;
    e1 = resolveProperties(sc, e1);
    e1 = e1->modifiableLvalue(sc, NULL);
    if (e1->op == TOKerror)
        return e1;
    type = Type::tvoid;

    Type *tb = e1->type->toBasetype();
    switch (tb->ty)
    {   case Tclass:
        {   TypeClass *tc = (TypeClass *)tb;
            ClassDeclaration *cd = tc->sym;

            if (cd->isCOMinterface())
            {   /* Because COM classes are deleted by IUnknown.Release()
                 */
                error("cannot delete instance of COM interface %s", cd->toChars());
                goto Lerr;
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
                FuncDeclaration *fd = sd->dtor;

                if (!f)
                    break;

                /* Construct:
                 *      ea = copy e1 to a tmp to do side effects only once
                 *      eb = call destructor
                 *      ec = call deallocator
                 */
                Expression *ea = NULL;
                Expression *eb = NULL;
                Expression *ec = NULL;
                VarDeclaration *v;

                if (fd && f)
                {   Identifier *id = Identifier::idPool("__tmpea");
                    v = new VarDeclaration(loc, e1->type, id, new ExpInitializer(loc, e1));
                    v->storage_class |= STCtemp;
                    v->semantic(sc);
                    v->parent = sc->parent;
                    ea = new DeclarationExp(loc, v);
                    ea->type = v->type;
                }

                if (fd)
                {   Expression *e = ea ? new VarExp(loc, v) : e1;
                    e = new DotVarExp(Loc(), e, fd, 0);
                    eb = new CallExp(loc, e);
                    eb = eb->semantic(sc);
                }

                if (f)
                {
                    Type *tpv = Type::tvoid->pointerTo();
                    Expression *e = ea ? new VarExp(loc, v) : e1->castTo(sc, tpv);
                    e = new CallExp(loc, new VarExp(loc, f), e);
                    ec = e->semantic(sc);
                }
                ea = combine(ea, eb);
                ea = combine(ea, ec);
                assert(ea);
                return ea;
            }
            break;

        case Tarray:
        {
            Type *tv = tb->nextOf()->baseElemOf();
            if (tv->ty == Tstruct)
            {
                TypeStruct *ts = (TypeStruct *)tv;
                StructDeclaration *sd = ts->sym;
                if (sd->dtor)
                    semanticTypeInfo(sc, ts);
            }
            break;
        }
        default:
            error("cannot delete type %s", e1->type->toChars());
            goto Lerr;
    }

    return this;

Lerr:
    return new ErrorExp();
}


Expression *DeleteExp::checkToBoolean(Scope *sc)
{
    error("delete does not give a boolean result");
    return new ErrorExp();
}

/************************************************************/

CastExp::CastExp(Loc loc, Expression *e, Type *t)
        : UnaExp(loc, TOKcast, sizeof(CastExp), e)
{
    this->to = t;
    this->mod = (unsigned char)~0;
}

/* For cast(const) and cast(immutable)
 */
CastExp::CastExp(Loc loc, Expression *e, unsigned char mod)
        : UnaExp(loc, TOKcast, sizeof(CastExp), e)
{
    this->to = NULL;
    this->mod = mod;
}

Expression *CastExp::syntaxCopy()
{
    return to ? new CastExp(loc, e1->syntaxCopy(), to->syntaxCopy())
              : new CastExp(loc, e1->syntaxCopy(), mod);
}

Expression *CastExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("CastExp::semantic('%s')\n", toChars());
#endif
    //static int x; assert(++x < 10);
    if (type)
        return this;

    if (Expression *ex = unaSemantic(sc))
        return ex;
    Expression *e1x = resolveProperties(sc, e1);
    if (e1x->op == TOKerror)
        return e1x;
    e1 = e1x;

    if (e1->type)               // if not a tuple
    {
        if (!to)
        {
            /* Handle cast(const) and cast(immutable), etc.
             */
            to = e1->type->castMod(mod);
        }
        else
            to = to->semantic(loc, sc);
        if (to == Type::terror)
            return new ErrorExp();
        if (to->ty == Ttuple)
        {
            error("cannot cast %s to tuple type %s", e1->toChars(), to->toChars());
            return new ErrorExp();
        }

        // cast(void) is used to mark e1 as unused, so it is safe
        if (to->ty == Tvoid)
            goto Lsafe;

        if (!to->equals(e1->type) && mod == (unsigned char)~0)
        {
            Expression *e = op_overload(sc);
            if (e)
                return e->implicitCastTo(sc, to);
        }

        if (e1->op == TOKtemplate)
        {
            error("cannot cast template %s to type %s", e1->toChars(), to->toChars());
            return new ErrorExp();
        }

        Type *t1b = e1->type->toBasetype();
        Type *tob = to->toBasetype();

        if (tob->ty == Tstruct && !tob->equals(t1b))
        {
            /* Look to replace:
             *  cast(S)t
             * with:
             *  S(t)
             */

            // Rewrite as to.call(e1)
            Expression *e = new TypeExp(loc, to);
            e = new CallExp(loc, e, e1);
            e = e->trySemantic(sc);
            if (e)
                return e;
        }

        if (!t1b->equals(tob) && (t1b->ty == Tarray || t1b->ty == Tsarray))
        {
            if (checkNonAssignmentArrayOp(e1))
                return new ErrorExp;
        }

        // Bugzlla 3133: Struct casts are possible only when the sizes match
        // Same with static array -> static array
        if ((t1b->ty == Tsarray || t1b->ty == Tstruct) &&
            (tob->ty == Tsarray || tob->ty == Tstruct))
        {
            if (t1b->size(loc) != tob->size(loc))
                goto Lfail;
        }

        // Bugzilla 9178: Tsarray <--> typeof(null)
        // Bugzilla 9904: Tstruct <--> typeof(null)
        if (t1b->ty == Tnull && (tob->ty == Tsarray || tob->ty == Tstruct) ||
            tob->ty == Tnull && (t1b->ty == Tsarray || t1b->ty == Tstruct))
        {
            goto Lfail;
        }

        // Bugzilla 13959: Tstruct <--> Tpointer
        if ((tob->ty == Tstruct && t1b->ty == Tpointer) ||
            (t1b->ty == Tstruct && tob->ty == Tpointer))
        {
            goto Lfail;
        }

        // Bugzilla 10646: Tclass <--> (T[] or T[n])
        if (tob->ty == Tclass && (t1b->ty == Tarray || t1b->ty == Tsarray) ||
            t1b->ty == Tclass && (tob->ty == Tarray || tob->ty == Tsarray))
        {
            goto Lfail;
        }

        // Look for casting to a vector type
        if (tob->ty == Tvector && t1b->ty != Tvector)
        {
            return new VectorExp(loc, e1, to);
        }

        // Bugzilla 11484: (T[] or T[n]) <--> TypeBasic
        // Bugzilla 11485, 7472: Tclass <--> TypeBasic
        if (t1b->isTypeBasic() && (tob->ty == Tarray || tob->ty == Tsarray || tob->ty == Tclass) ||
            tob->isTypeBasic() && (t1b->ty == Tarray || t1b->ty == Tsarray || t1b->ty == Tclass))
        {
            goto Lfail;
        }

        if (tob->ty == Tpointer && t1b->ty == Tdelegate)
            deprecation("casting from %s to %s is deprecated", e1->type->toChars(), to->toChars());

        if (t1b->ty == Tvoid && tob->ty != Tvoid && e1->op != TOKfunction)
            goto Lfail;
    }
    else if (!to)
    {
        error("cannot cast tuple");
        return new ErrorExp();
    }

    if (!e1->type)
    {
        error("cannot cast %s", e1->toChars());
        return new ErrorExp();
    }

    // Check for unsafe casts
    if (sc->func && !sc->intypeof)
    {
        // Disallow unsafe casts
        Type *tob = to->toBasetype();
        Type *t1b = e1->type->toBasetype();

        // Implicit conversions are always safe
        if (t1b->implicitConvTo(tob))
            goto Lsafe;

        if (!tob->hasPointers())
            goto Lsafe;

        if (tob->ty == Tclass && t1b->ty == Tclass)
        {
            ClassDeclaration *cdfrom = t1b->isClassHandle();
            ClassDeclaration *cdto   = tob->isClassHandle();

            int offset;
            if (!cdfrom->isBaseOf(cdto, &offset))
                goto Lunsafe;

            if (cdfrom->isCPPinterface() ||
                cdto->isCPPinterface())
                goto Lunsafe;

            if (!MODimplicitConv(t1b->mod, tob->mod))
                goto Lunsafe;
            goto Lsafe;
        }

        if (tob->ty == Tarray && t1b->ty == Tarray)
        {
            Type* tobn = tob->nextOf()->toBasetype();
            Type* t1bn = t1b->nextOf()->toBasetype();
            if (!tobn->hasPointers() && MODimplicitConv(t1bn->mod, tobn->mod))
                goto Lsafe;
        }
        if (tob->ty == Tpointer && t1b->ty == Tpointer)
        {
            Type* tobn = tob->nextOf()->toBasetype();
            Type* t1bn = t1b->nextOf()->toBasetype();
            // If the struct is opaque we don't know about the struct members and the cast becomes unsafe
            bool sfwrd = tobn->ty == Tstruct && !((StructDeclaration *)((TypeStruct *)tobn)->sym)->members ||
                    t1bn->ty == Tstruct && !((StructDeclaration *)((TypeStruct *)t1bn)->sym)->members;
            if (!sfwrd && !tobn->hasPointers() &&
                tobn->ty != Tfunction && t1bn->ty != Tfunction &&
                tobn->size() <= t1bn->size() &&
                MODimplicitConv(t1bn->mod, tobn->mod))
            {
                goto Lsafe;
            }
        }

    Lunsafe:
        if (sc->func->setUnsafe())
        {
            error("cast from %s to %s not allowed in safe code", e1->type->toChars(), to->toChars());
            return new ErrorExp();
        }
    }

Lsafe:
    if (to->ty == Tvoid)
    {
        type = to;
        return this;
    }
    return e1->castTo(sc, to);

Lfail:
    error("cannot cast expression %s of type %s to %s", e1->toChars(), e1->type->toChars(), to->toChars());
    return new ErrorExp();
}

/************************************************************/

VectorExp::VectorExp(Loc loc, Expression *e, Type *t)
        : UnaExp(loc, TOKvector, sizeof(VectorExp), e)
{
    assert(t->ty == Tvector);
    to = (TypeVector *)t;
    dim = ~0;
}

Expression *VectorExp::syntaxCopy()
{
    return new VectorExp(loc, e1->syntaxCopy(), to->syntaxCopy());
}

Expression *VectorExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("VectorExp::semantic('%s')\n", toChars());
#endif
    if (type)
        return this;

    e1 = e1->semantic(sc);
    type = to->semantic(loc, sc);
    if (e1->op == TOKerror || type->ty == Terror)
        return e1;

    Type *tb = type->toBasetype();
    assert(tb->ty == Tvector);
    TypeVector *tv = (TypeVector *)tb;
    Type *te = tv->elementType();
    dim = (int)(tv->size(loc) / te->size(loc));

    return this;
}

/************************************************************/

SliceExp::SliceExp(Loc loc, Expression *e1, Expression *lwr, Expression *upr)
        : UnaExp(loc, TOKslice, sizeof(SliceExp), e1)
{
    this->upr = upr;
    this->lwr = lwr;
    lengthVar = NULL;
    upperIsInBounds = false;
    lowerIsLessThanUpper = false;
}

Expression *SliceExp::syntaxCopy()
{
    SliceExp *se = new SliceExp(loc, e1->syntaxCopy(),
        lwr ? lwr->syntaxCopy() : NULL,
        upr ? upr->syntaxCopy() : NULL);
    se->lengthVar = this->lengthVar;    // bug7871
    return se;
}

Expression *SliceExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("SliceExp::semantic('%s')\n", toChars());
#endif
    if (type)
        return this;

Lagain:
    if (Expression *ex = unaSemantic(sc))
        return ex;
    e1 = resolveProperties(sc, e1);
    if (e1->op == TOKtype && e1->type->ty != Ttuple)
    {
        if (lwr || upr)
        {
            error("cannot slice type '%s'", e1->toChars());
            return new ErrorExp();
        }
        Expression *e = new TypeExp(loc, e1->type->arrayOf());
        return e->semantic(sc);
    }
    if (!lwr && !upr)
    {
        if (e1->op == TOKarrayliteral)
        {
            // Convert [a,b,c][] to [a,b,c]
            Type *t1b = e1->type->toBasetype();
            Expression *e = e1;
            if (t1b->ty == Tsarray)
            {
                e = e->copy();
                e->type = t1b->nextOf()->arrayOf();
            }
            return e;
        }
        if (e1->op == TOKslice)
        {
            // Convert e[][] to e[]
            SliceExp *se = (SliceExp *)e1;
            if (!se->lwr && !se->upr)
                return se;
        }
        if (isArrayOpOperand(e1))
        {
            // Convert (a[]+b[])[] to a[]+b[]
            return e1;
        }
    }

    Type *t1b = e1->type->toBasetype();
    AggregateDeclaration *ad = isAggregate(t1b);
    if (t1b->ty == Tpointer)
    {
        if (((TypePointer *)t1b)->next->ty == Tfunction)
        {
            error("cannot slice function pointer %s", e1->toChars());
            return new ErrorExp();
        }
        if (!lwr || !upr)
        {
            error("need upper and lower bound to slice pointer");
            return new ErrorExp();
        }
        if (sc->func && !sc->intypeof && sc->func->setUnsafe())
        {
            error("pointer slicing not allowed in safe functions");
            return new ErrorExp();
        }
    }
    else if (t1b->ty == Tarray)
    {
    }
    else if (t1b->ty == Tsarray)
    {
    }
    else if (ad)
    {
        if (search_function(ad, Id::slice))
        {
            // Rewrite as e1.slice(lwr, upr)
            Expression *e0 = NULL;
            Expression *ex = resolveOpDollar(sc, this, &e0);
            if (ex->op == TOKerror)
                return ex;
            Expressions *a = new Expressions();
            assert(!lwr || upr);
            if (lwr)
            {
                a->push(lwr);
                a->push(upr);
            }
            Expression *e = new DotIdExp(loc, e1, Id::slice);
            e = new CallExp(loc, e, a);
            e = e->semantic(sc);
            return Expression::combine(e0, e);
        }
        if (ad->aliasthis && e1->type != att1)
        {
            if (!att1 && e1->type->checkAliasThisRec())
                att1 = e1->type;
            e1 = resolveAliasThis(sc, e1);
            goto Lagain;
        }
        goto Lerror;
    }
    else if (t1b->ty == Ttuple)
    {
        if (!lwr && !upr)
            return e1;
        if (!lwr || !upr)
        {
            error("need upper and lower bound to slice tuple");
            return new ErrorExp();
        }
    }
    else if (t1b == Type::terror)
    {
        return new ErrorExp();
    }
    else
    {
    Lerror:
        if (e1->op == TOKerror)
            return e1;
        error("%s cannot be sliced with []",
            t1b->ty == Tvoid ? e1->toChars() : t1b->toChars());
        return new ErrorExp();
    }

    /* Run semantic on lwr and upr.
     */
    Scope *scx = sc;
    if (t1b->ty == Tsarray || t1b->ty == Tarray || t1b->ty == Ttuple)
    {
        // Create scope for 'length' variable
        ScopeDsymbol *sym = new ArrayScopeSymbol(sc, this);
        sym->loc = loc;
        sym->parent = sc->scopesym;
        sc = sc->push(sym);
    }
    if (lwr)
    {
        if (t1b->ty == Ttuple) sc = sc->startCTFE();
        lwr = lwr->semantic(sc);
        lwr = resolveProperties(sc, lwr);
        if (t1b->ty == Ttuple) sc = sc->endCTFE();
        lwr = lwr->implicitCastTo(sc, Type::tsize_t);
    }
    if (upr)
    {
        if (t1b->ty == Ttuple) sc = sc->startCTFE();
        upr = upr->semantic(sc);
        upr = resolveProperties(sc, upr);
        if (t1b->ty == Ttuple) sc = sc->endCTFE();
        upr = upr->implicitCastTo(sc, Type::tsize_t);
    }
    if (sc != scx)
        sc = sc->pop();
    if (lwr && lwr->type == Type::terror ||
        upr && upr->type == Type::terror)
    {
        return new ErrorExp();
    }

    if (t1b->ty == Ttuple)
    {
        lwr = lwr->ctfeInterpret();
        upr = upr->ctfeInterpret();
        uinteger_t i1 = lwr->toUInteger();
        uinteger_t i2 = upr->toUInteger();

        TupleExp *te;
        TypeTuple *tup;
        size_t length;
        if (e1->op == TOKtuple)         // slicing an expression tuple
        {
            te = (TupleExp *)e1;
            tup = NULL;
            length = te->exps->dim;
        }
        else if (e1->op == TOKtype)     // slicing a type tuple
        {
            te = NULL;
            tup = (TypeTuple *)t1b;
            length = Parameter::dim(tup->arguments);
        }
        else
            assert(0);

        if (i2 < i1 || length < i2)
        {
            error("string slice [%llu .. %llu] is out of bounds", i1, i2);
            return new ErrorExp();
        }

        size_t j1 = (size_t) i1;
        size_t j2 = (size_t) i2;
        Expression *e;
        if (e1->op == TOKtuple)
        {
            Expressions *exps = new Expressions;
            exps->setDim(j2 - j1);
            for (size_t i = 0; i < j2 - j1; i++)
            {
                (*exps)[i] = (*te->exps)[j1 + i];
            }
            e = new TupleExp(loc, te->e0, exps);
        }
        else
        {
            Parameters *args = new Parameters;
            args->reserve(j2 - j1);
            for (size_t i = j1; i < j2; i++)
            {
                Parameter *arg = Parameter::getNth(tup->arguments, i);
                args->push(arg);
            }
            e = new TypeExp(e1->loc, new TypeTuple(args));
        }
        e = e->semantic(sc);
        return e;
    }

    type = t1b->nextOf()->arrayOf();
    // Allow typedef[] -> typedef[]
    if (type->equals(t1b))
        type = e1->type;

    if (lwr && upr)
    {
        lwr = lwr->optimize(WANTvalue);
        upr = upr->optimize(WANTvalue);

        IntRange lwrRange = getIntRange(lwr);
        IntRange uprRange = getIntRange(upr);

        if (t1b->ty == Tsarray || t1b->ty == Tarray)
        {
            Expression *el = new ArrayLengthExp(loc, e1);
            el = el->semantic(sc);
            el = el->optimize(WANTvalue);
            if (el->op == TOKint64)
            {
                dinteger_t length = el->toInteger();
                IntRange bounds(SignExtendedNumber(0), SignExtendedNumber(length));
                this->upperIsInBounds = bounds.contains(uprRange);
            }
        }
        else if (t1b->ty == Tpointer)
        {
            this->upperIsInBounds = true;
        }
        else
            assert(0);

        this->lowerIsLessThanUpper = (lwrRange.imax <= uprRange.imin);

        //printf("upperIsInBounds = %d lowerIsLessThanUpper = %d\n", upperIsInBounds, lowerIsLessThanUpper);
    }

    return this;
}

int SliceExp::checkModifiable(Scope *sc, int flag)
{
    //printf("SliceExp::checkModifiable %s\n", toChars());
    if (e1->type->ty == Tsarray ||
        (e1->op == TOKindex && e1->type->ty != Tarray) ||
        e1->op == TOKslice)
    {
        return e1->checkModifiable(sc, flag);
    }
    return 1;
}

bool SliceExp::isLvalue()
{
    /* slice expression is rvalue in default, but
     * conversion to reference of static array is only allowed.
     */
    return (type && type->toBasetype()->ty == Tsarray);
}

Expression *SliceExp::toLvalue(Scope *sc, Expression *e)
{
    //printf("SliceExp::toLvalue(%s) type = %s\n", toChars(), type ? type->toChars() : NULL);
    return (type && type->toBasetype()->ty == Tsarray)
            ? this : Expression::toLvalue(sc, e);
}

Expression *SliceExp::modifiableLvalue(Scope *sc, Expression *e)
{
    error("slice expression %s is not a modifiable lvalue", toChars());
    return this;
}

bool SliceExp::isBool(bool result)
{
    return e1->isBool(result);
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
    if (type)
        return this;

    if (Expression *ex = unaSemantic(sc))
        return ex;
    e1 = resolveProperties(sc, e1);

    type = Type::tsize_t;
    return this;
}

Expression *opAssignToOp(Loc loc, TOK op, Expression *e1, Expression *e2)
{   Expression *e;

    switch (op)
    {
        case TOKaddass:   e = new AddExp(loc, e1, e2);  break;
        case TOKminass:   e = new MinExp(loc, e1, e2);  break;
        case TOKmulass:   e = new MulExp(loc, e1, e2);  break;
        case TOKdivass:   e = new DivExp(loc, e1, e2);  break;
        case TOKmodass:   e = new ModExp(loc, e1, e2);  break;
        case TOKandass:   e = new AndExp(loc, e1, e2);  break;
        case TOKorass:    e = new OrExp (loc, e1, e2);  break;
        case TOKxorass:   e = new XorExp(loc, e1, e2);  break;
        case TOKshlass:   e = new ShlExp(loc, e1, e2);  break;
        case TOKshrass:   e = new ShrExp(loc, e1, e2);  break;
        case TOKushrass:  e = new UshrExp(loc, e1, e2); break;
        default:        assert(0);
    }
    return e;
}

/*********************
 * Rewrite:
 *    array.length op= e2
 * as:
 *    array.length = array.length op e2
 * or:
 *    auto tmp = &array;
 *    (*tmp).length = (*tmp).length op e2
 */

Expression *ArrayLengthExp::rewriteOpAssign(BinExp *exp)
{   Expression *e;

    assert(exp->e1->op == TOKarraylength);
    ArrayLengthExp *ale = (ArrayLengthExp *)exp->e1;
    if (ale->e1->op == TOKvar)
    {   e = opAssignToOp(exp->loc, exp->op, ale, exp->e2);
        e = new AssignExp(exp->loc, ale->syntaxCopy(), e);
    }
    else
    {
        /*    auto tmp = &array;
         *    (*tmp).length = (*tmp).length op e2
         */
        Identifier *id = Identifier::generateId("__arraylength");
        ExpInitializer *ei = new ExpInitializer(ale->loc, new AddrExp(ale->loc, ale->e1));
        VarDeclaration *tmp = new VarDeclaration(ale->loc, ale->e1->type->pointerTo(), id, ei);
        tmp->storage_class |= STCtemp;

        Expression *e1 = new ArrayLengthExp(ale->loc, new PtrExp(ale->loc, new VarExp(ale->loc, tmp)));
        Expression *elvalue = e1->syntaxCopy();
        e = opAssignToOp(exp->loc, exp->op, e1, exp->e2);
        e = new AssignExp(exp->loc, elvalue, e);
        e = new CommaExp(exp->loc, new DeclarationExp(ale->loc, tmp), e);
    }
    return e;
}

/*********************** IntervalExp ********************************/

// Mainly just a placeholder

IntervalExp::IntervalExp(Loc loc, Expression *lwr, Expression *upr)
        : Expression(loc, TOKinterval, sizeof(IntervalExp))
{
    this->lwr = lwr;
    this->upr = upr;
}

Expression *IntervalExp::syntaxCopy()
{
    return new IntervalExp(loc, lwr->syntaxCopy(), upr->syntaxCopy());
}

Expression *IntervalExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("IntervalExp::semantic('%s')\n", toChars());
#endif
    if (type)
        return this;

    Expression *le = lwr;
    le = le->semantic(sc);
    le = resolveProperties(sc, le);

    Expression *ue = upr;
    ue = ue->semantic(sc);
    ue = resolveProperties(sc, ue);

    if (le->op == TOKerror)
        return le;
    if (ue->op == TOKerror)
        return ue;

    lwr = le;
    upr = ue;

    type = Type::tvoid;
    return this;
}

/********************** DelegatePtrExp **************************************/

DelegatePtrExp::DelegatePtrExp(Loc loc, Expression *e1)
        : UnaExp(loc, TOKdelegateptr, sizeof(DelegatePtrExp), e1)
{
}

Expression *DelegatePtrExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("DelegatePtrExp::semantic('%s')\n", toChars());
#endif
    if (!type)
    {
        unaSemantic(sc);
        e1 = resolveProperties(sc, e1);

        if (e1->op == TOKerror)
            return e1;
        type = Type::tvoidptr;
    }
    return this;
}

bool DelegatePtrExp::isLvalue()
{
    return e1->isLvalue();
}

Expression *DelegatePtrExp::toLvalue(Scope *sc, Expression *e)
{
    e1 = e1->toLvalue(sc, e);
    return this;
}

/********************** DelegateFuncptrExp **************************************/

DelegateFuncptrExp::DelegateFuncptrExp(Loc loc, Expression *e1)
        : UnaExp(loc, TOKdelegatefuncptr, sizeof(DelegateFuncptrExp), e1)
{
}

Expression *DelegateFuncptrExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("DelegateFuncptrExp::semantic('%s')\n", toChars());
#endif
    if (!type)
    {
        unaSemantic(sc);
        e1 = resolveProperties(sc, e1);

        if (e1->op == TOKerror)
            return e1;
        type = e1->type->nextOf()->pointerTo();
    }
    return this;
}

bool DelegateFuncptrExp::isLvalue()
{
    return e1->isLvalue();
}

Expression *DelegateFuncptrExp::toLvalue(Scope *sc, Expression *e)
{
    e1 = e1->toLvalue(sc, e);
    return this;
}

/*********************** ArrayExp *************************************/

// e1 [ i1, i2, i3, ... ]

ArrayExp::ArrayExp(Loc loc, Expression *e1, Expressions *args)
        : UnaExp(loc, TOKarray, sizeof(ArrayExp), e1)
{
    arguments = args;
    lengthVar = NULL;
    currentDimension = 0;
}

Expression *ArrayExp::syntaxCopy()
{
    ArrayExp *ae = new ArrayExp(loc, e1->syntaxCopy(), arraySyntaxCopy(arguments));
    ae->lengthVar = this->lengthVar;    // bug7871
    return ae;
}

Expression *ArrayExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("ArrayExp::semantic('%s')\n", toChars());
#endif
    if (Expression *ex = unaSemantic(sc))
        return ex;
    Expression *e1x = resolveProperties(sc, e1);
    if (e1x->op == TOKerror)
        return e1x;
    e1 = e1x;

    Type *t1 = e1->type->toBasetype();
    if (t1->ty != Tclass && t1->ty != Tstruct)
    {
        // Convert to IndexExp
        Expression *e;
        if (arguments->dim == 0)
        {
            e = new SliceExp(loc, e1, NULL, NULL);
        }
        else if (arguments->dim == 1 && (*arguments)[0]->op == TOKinterval)
        {
            IntervalExp *ie = (IntervalExp *)(*arguments)[0];
            e = new SliceExp(loc, e1, ie->lwr, ie->upr);
        }
        else if (arguments->dim == 1)
        {
            e = new IndexExp(loc, e1, (*arguments)[0]);
        }
        else
        {
            error("only one index allowed to index %s", t1->toChars());
            return new ErrorExp();
        }
        return e->semantic(sc);
    }

    Expression *e = op_overload(sc);
    if (e)
        return e;

    error("no [] operator overload for type %s", e1->type->toChars());
    return new ErrorExp();
}


bool ArrayExp::isLvalue()
{
    if (type && type->toBasetype()->ty == Tvoid)
        return false;
    return true;
}

Expression *ArrayExp::toLvalue(Scope *sc, Expression *e)
{
    if (type && type->toBasetype()->ty == Tvoid)
        error("voids have no value");
    return this;
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
    if (e2->op == TOKtype)
        return e2;
    if (!type)
        type = e2->type;
    return this;
}

/************************* CommaExp ***********************************/

CommaExp::CommaExp(Loc loc, Expression *e1, Expression *e2)
        : BinExp(loc, TOKcomma, sizeof(CommaExp), e1, e2)
{
}

Expression *CommaExp::semantic(Scope *sc)
{
    if (type)
        return this;

    if (Expression *ex = binSemanticProp(sc))
        return ex;
    e1 = e1->addDtorHook(sc);

    type = e2->type;
    return this;
}

bool CommaExp::isLvalue()
{
    return e2->isLvalue();
}

Expression *CommaExp::toLvalue(Scope *sc, Expression *e)
{
    e2 = e2->toLvalue(sc, NULL);
    return this;
}

int CommaExp::checkModifiable(Scope *sc, int flag)
{
    return e2->checkModifiable(sc, flag);
}

Expression *CommaExp::modifiableLvalue(Scope *sc, Expression *e)
{
    e2 = e2->modifiableLvalue(sc, e);
    return this;
}

bool CommaExp::isBool(bool result)
{
    return e2->isBool(result);
}


Expression *CommaExp::addDtorHook(Scope *sc)
{
    e2 = e2->addDtorHook(sc);
    return this;
}

/************************** IndexExp **********************************/

// e1 [ e2 ]

IndexExp::IndexExp(Loc loc, Expression *e1, Expression *e2)
        : BinExp(loc, TOKindex, sizeof(IndexExp), e1, e2)
{
    //printf("IndexExp::IndexExp('%s')\n", toChars());
    lengthVar = NULL;
    modifiable = false;     // assume it is an rvalue
    indexIsInBounds = false;
}

Expression *IndexExp::syntaxCopy()
{
    IndexExp *ie = new IndexExp(loc, e1->syntaxCopy(), e2->syntaxCopy());
    ie->lengthVar = this->lengthVar;    // bug7871
    return ie;
}

Expression *IndexExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("IndexExp::semantic('%s')\n", toChars());
#endif
    if (type)
        return this;

    if (!e1->type)
        e1 = e1->semantic(sc);
    assert(e1->type);           // semantic() should already be run on it
    if (e1->op == TOKtype && e1->type->ty != Ttuple)
    {
        e2 = e2->semantic(sc);
        e2 = resolveProperties(sc, e2);
        Type *nt;
        if (e2->op == TOKtype)
            nt = new TypeAArray(e1->type, e2->type);
        else
            nt = new TypeSArray(e1->type, e2);
        Expression *e = new TypeExp(loc, nt);
        return e->semantic(sc);
    }
    if (e1->op == TOKerror)
        return e1;
    if (e1->type->ty == Terror)
        return new ErrorExp();

    // Note that unlike C we do not implement the int[ptr]

    Type *t1b = e1->type->toBasetype();

    /* Run semantic on e2
     */
    Scope *scx = sc;
    if (t1b->ty == Tsarray || t1b->ty == Tarray || t1b->ty == Ttuple)
    {
        // Create scope for 'length' variable
        ScopeDsymbol *sym = new ArrayScopeSymbol(sc, this);
        sym->loc = loc;
        sym->parent = sc->scopesym;
        sc = sc->push(sym);
    }
    if (t1b->ty == Ttuple) sc = sc->startCTFE();
    e2 = e2->semantic(sc);
    e2 = resolveProperties(sc, e2);
    if (t1b->ty == Ttuple) sc = sc->endCTFE();
    if (e2->op == TOKtuple)
    {
        TupleExp *te = (TupleExp *)e2;
        if (te->exps && te->exps->dim == 1)
            e2 = Expression::combine(te->e0, (*te->exps)[0]);  // bug 4444 fix
    }
    if (sc != scx)
        sc = sc->pop();
    if (e2->type == Type::terror)
        return new ErrorExp();

    switch (t1b->ty)
    {
        case Tpointer:
            if (((TypePointer *)t1b)->next->ty == Tfunction)
            {
                error("cannot index function pointer %s", e1->toChars());
                return new ErrorExp();
            }
            e2 = e2->implicitCastTo(sc, Type::tsize_t);
            if (e2->type == Type::terror)
                return new ErrorExp();
            e2 = e2->optimize(WANTvalue);
            if (e2->op == TOKint64 && e2->toInteger() == 0)
                ;
            else if (sc->func && sc->func->setUnsafe())
            {
                error("safe function '%s' cannot index pointer '%s'",
                    sc->func->toPrettyChars(), e1->toChars());
                return new ErrorExp();
            }
            type = ((TypeNext *)t1b)->next;
            break;

        case Tarray:
            e2 = e2->implicitCastTo(sc, Type::tsize_t);
            if (e2->type == Type::terror)
                return new ErrorExp();
            type = ((TypeNext *)t1b)->next;
            break;

        case Tsarray:
        {
            e2 = e2->implicitCastTo(sc, Type::tsize_t);
            if (e2->type == Type::terror)
                return new ErrorExp();
            type = t1b->nextOf();
            break;
        }

        case Taarray:
        {
            TypeAArray *taa = (TypeAArray *)t1b;
            /* We can skip the implicit conversion if they differ only by
             * constness (Bugzilla 2684, see also bug 2954b)
             */
            if (!arrayTypeCompatibleWithoutCasting(e2->loc, e2->type, taa->index))
            {
                e2 = e2->implicitCastTo(sc, taa->index);        // type checking
                if (e2->type == Type::terror)
                    return new ErrorExp();
            }
            type = taa->next;
            break;
        }

        case Ttuple:
        {
            e2 = e2->implicitCastTo(sc, Type::tsize_t);
            if (e2->type == Type::terror)
                return new ErrorExp();
            e2 = e2->ctfeInterpret();
            uinteger_t index = e2->toUInteger();

            TupleExp *te;
            TypeTuple *tup;
            size_t length;
            if (e1->op == TOKtuple)
            {
                te = (TupleExp *)e1;
                tup = NULL;
                length = te->exps->dim;
            }
            else if (e1->op == TOKtype)
            {
                te = NULL;
                tup = (TypeTuple *)t1b;
                length = Parameter::dim(tup->arguments);
            }
            else
                assert(0);

            if (length <= index)
            {
                error("array index [%llu] is outside array bounds [0 .. %llu]",
                        index, (ulonglong)length);
                return new ErrorExp();
            }

            Expression *e;
            if (e1->op == TOKtuple)
            {
                e = (*te->exps)[(size_t)index];
                e = combine(te->e0, e);
            }
            else
                e = new TypeExp(e1->loc, Parameter::getNth(tup->arguments, (size_t)index)->type);
            return e;
        }

        default:
            error("%s must be an array or pointer type, not %s",
                e1->toChars(), e1->type->toChars());
            return new ErrorExp();
    }

    if (t1b->ty == Tsarray || t1b->ty == Tarray)
    {
        Expression *el = new ArrayLengthExp(loc, e1);
        el = el->semantic(sc);
        el = el->optimize(WANTvalue);
        if (el->op == TOKint64)
        {
            e2 = e2->optimize(WANTvalue);
            dinteger_t length = el->toInteger();
            if (length)
            {
                IntRange bounds(SignExtendedNumber(0), SignExtendedNumber(length - 1));
                indexIsInBounds = bounds.contains(getIntRange(e2));
            }
        }
    }

    return this;
}

bool IndexExp::isLvalue()
{
    return true;
}

Expression *IndexExp::toLvalue(Scope *sc, Expression *e)
{
    return this;
}

int IndexExp::checkModifiable(Scope *sc, int flag)
{
    if (e1->type->ty == Tsarray ||
        e1->type->ty == Taarray ||
        (e1->op == TOKindex && e1->type->ty != Tarray) ||
        e1->op == TOKslice)
    {
        return e1->checkModifiable(sc, flag);
    }
    return 1;
}

Expression *IndexExp::modifiableLvalue(Scope *sc, Expression *e)
{
    //printf("IndexExp::modifiableLvalue(%s)\n", toChars());
    Expression *ex = markSettingAAElem();
    if (ex->op == TOKerror)
        return ex;

    return Expression::modifiableLvalue(sc, e);
}

Expression *IndexExp::markSettingAAElem()
{
    if (e1->type->toBasetype()->ty == Taarray)
    {
        Type *t2b = e2->type->toBasetype();
        if (t2b->ty == Tarray && t2b->nextOf()->isMutable())
        {
            error("associative arrays can only be assigned values with immutable keys, not %s", e2->type->toChars());
            return new ErrorExp();
        }
        modifiable = true;

        if (e1->op == TOKindex)
        {
            Expression *ex = ((IndexExp *)e1)->markSettingAAElem();
            if (ex->op == TOKerror)
                return ex;
            assert(ex == e1);
        }
    }
    return this;
}

/************************* PostExp ***********************************/

PostExp::PostExp(TOK op, Loc loc, Expression *e)
        : BinExp(loc, op, sizeof(PostExp), e,
          new IntegerExp(loc, 1, Type::tint32))
{
}

Expression *PostExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("PostExp::semantic('%s')\n", toChars());
#endif
    if (type)
        return this;

    if (Expression *ex = binSemantic(sc))
        return ex;
    Expression *e1x = resolveProperties(sc, e1);
    if (e1x->op == TOKerror)
        return e1x;
    e1 = e1x;

    Expression *e = op_overload(sc);
    if (e)
        return e;

    e = e1->checkReadModifyWrite(op);
    if (e)
        return e;

    if (e1->op == TOKslice)
    {
        const char *s = op == TOKplusplus ? "increment" : "decrement";
        error("cannot post-%s array slice '%s', use pre-%s instead", s, e1->toChars(), s);
        return new ErrorExp();
    }

    e1 = e1->optimize(WANTvalue);
    if (e1->op != TOKarraylength)
        e1 = e1->modifiableLvalue(sc, e1);

    Type *t1 = e1->type->toBasetype();
    if (t1->ty == Tclass || t1->ty == Tstruct || e1->op == TOKarraylength)
    {
        /* Check for operator overloading,
         * but rewrite in terms of ++e instead of e++
         */

        /* If e1 is not trivial, take a reference to it
         */
        Expression *de = NULL;
        if (e1->op != TOKvar && e1->op != TOKarraylength)
        {
            // ref v = e1;
            Identifier *id = Identifier::generateId("__postref");
            ExpInitializer *ei = new ExpInitializer(loc, e1);
            VarDeclaration *v = new VarDeclaration(loc, e1->type, id, ei);
            v->storage_class |= STCtemp | STCref | STCforeach;
            de = new DeclarationExp(loc, v);
            e1 = new VarExp(e1->loc, v);
        }

        /* Rewrite as:
         * auto tmp = e1; ++e1; tmp
         */
        Identifier *id = Identifier::generateId("__pitmp");
        ExpInitializer *ei = new ExpInitializer(loc, e1);
        VarDeclaration *tmp = new VarDeclaration(loc, e1->type, id, ei);
        tmp->storage_class |= STCtemp;
        Expression *ea = new DeclarationExp(loc, tmp);

        Expression *eb = e1->syntaxCopy();
        eb = new PreExp(op == TOKplusplus ? TOKpreplusplus : TOKpreminusminus, loc, eb);

        Expression *ec = new VarExp(loc, tmp);

        // Combine de,ea,eb,ec
        if (de)
            ea = new CommaExp(loc, de, ea);
        e = new CommaExp(loc, ea, eb);
        e = new CommaExp(loc, e, ec);
        e = e->semantic(sc);
        return e;
    }

    e = this;
    e1->checkScalar();
    e1->checkNoBool();
    if (e1->type->ty == Tpointer)
        e = scaleFactor(this, sc);
    else
        e2 = e2->castTo(sc, e1->type);
    e->type = e1->type;
    return e;
}

/************************* PreExp ***********************************/

PreExp::PreExp(TOK op, Loc loc, Expression *e)
        : UnaExp(loc, op, sizeof(PreExp), e)
{
}

Expression *PreExp::semantic(Scope *sc)
{
    Expression *e = op_overload(sc);
    // printf("PreExp::semantic('%s')\n", toChars());

    if (e)
        return e;

    // Rewrite as e1+=1 or e1-=1
    if (op == TOKpreplusplus)
        e = new AddAssignExp(loc, e1, new IntegerExp(loc, 1, Type::tint32));
    else
        e = new MinAssignExp(loc, e1, new IntegerExp(loc, 1, Type::tint32));
    return e->semantic(sc);
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
#if LOGSEMANTIC
    printf("AssignExp::semantic('%s')\n", toChars());
#endif
    //printf("e1->op = %d, '%s'\n", e1->op, Token::toChars(e1->op));
    //printf("e2->op = %d, '%s'\n", e2->op, Token::toChars(e2->op));
    if (type)
        return this;

    Expression *e1old = e1;

    if (e2->op == TOKcomma)
    {
        /* Rewrite to get rid of the comma from rvalue
         */
        Expression *e0;
        e2 = Expression::extractLast(e2, &e0);
        Expression *e = Expression::combine(e0, this);
        return e->semantic(sc);
    }

    /* Look for operator overloading of a[i]=value.
     * Do it before semantic() otherwise the a[i] will have been
     * converted to a.opIndex() already.
     */
    if (e1->op == TOKarray)
    {
        ArrayExp *ae = (ArrayExp *)e1;
        ae->e1 = ae->e1->semantic(sc);
        ae->e1 = resolveProperties(sc, ae->e1);

        Type *t1 = ae->e1->type->toBasetype();
        AggregateDeclaration *ad = isAggregate(t1);
        if (ad)
        {
            Expression *e0 = NULL;

            // Rewrite (a[i] = value) to (a.opIndexAssign(value, i))
            if (search_function(ad, Id::indexass))
            {
                // Deal with $
                Expression *ex = resolveOpDollar(sc, ae, &e0);
                if (!ex)
                    goto Lfallback;
                if (ex->op == TOKerror)
                    return ex;

                Expression *e2x = e2->semantic(sc);
                if (e2x->op == TOKerror)
                    return e2x;
                e2 = e2x;

                Expressions *a = (Expressions *)ae->arguments->copy();
                a->insert(0, e2);

                Expression *e = new DotIdExp(loc, ae->e1, Id::indexass);
                e = new CallExp(loc, e, a);
                if (ae->arguments->dim == 0)
                    e = e->trySemantic(sc);
                else
                    e = e->semantic(sc);
                if (!e)
                    goto Lfallback;
                return Expression::combine(e0, e);
            }

            // No opIndexAssign found yet, but there might be an alias this to try.
            if (ad->aliasthis && t1 != ae->att1)
            {
                ArrayExp *aex = (ArrayExp *)ae->copy();
                if (!aex->att1 && t1->checkAliasThisRec())
                    aex->att1 = t1;
                aex->e1 = new DotIdExp(loc, ae->e1, ad->aliasthis->ident);
                this->e1 = aex;
                Expression *ex = this->trySemantic(sc);
                if (ex)
                    return ex;
                this->e1 = ae;  // restore
            }

        Lfallback:
            if (ae->arguments->dim == 0)
            {
                // a[] = e2
                SliceExp *se = new SliceExp(ae->loc, ae->e1, NULL, NULL);
                se->att1 = ae->att1;
                this->e1 = se;
                return Expression::combine(e0, this->semantic(sc));
            }
            if (ae->arguments->dim == 1 && (*ae->arguments)[0]->op == TOKinterval)
            {
                // a[lwr..upr] = e2
                IntervalExp *ie = (IntervalExp *)(*ae->arguments)[0];
                SliceExp *se = new SliceExp(ae->loc, ae->e1, ie->lwr, ie->upr);
                se->att1 = ae->att1;
                this->e1 = se;
                return Expression::combine(e0, this->semantic(sc));
            }
        }
    }
    /* Look for operator overloading of a[i..j]=value.
     * Do it before semantic() otherwise the a[i..j] will have been
     * converted to a.opSlice() already.
     */
    if (e1->op == TOKslice)
    {
        SliceExp *ae = (SliceExp *)e1;
        ae->e1 = ae->e1->semantic(sc);
        ae->e1 = resolveProperties(sc, ae->e1);

        Type *t1 = ae->e1->type->toBasetype();
        AggregateDeclaration *ad = isAggregate(t1);
        if (ad)
        {
            // Rewrite (a[i..j] = value) to (a.opSliceAssign(value, i, j))
            if (search_function(ad, Id::sliceass))
            {
                Expression *e0 = NULL;
                Expression *ex = resolveOpDollar(sc, ae, &e0);
                if (ex->op == TOKerror)
                    return ex;
                Expressions *a = new Expressions();
                a->push(e2);
                assert(!ae->lwr || ae->upr);
                if (ae->lwr)
                {
                    a->push(ae->lwr);
                    a->push(ae->upr);
                }
                Expression *e = new DotIdExp(loc, ae->e1, Id::sliceass);
                e = new CallExp(loc, e, a);
                e = e->semantic(sc);
                return Expression::combine(e0, e);
            }

            // No opSliceAssign found yet, but there might be an alias this to try.
            if (ad->aliasthis && t1 != ae->att1)
            {
                SliceExp *aex = (SliceExp *)ae->copy();
                if (!aex->att1 && t1->checkAliasThisRec())
                    aex->att1 = t1;
                aex->e1 = new DotIdExp(loc, ae->e1, ad->aliasthis->ident);
                this->e1 = aex;
                Expression *ex = this->trySemantic(sc);
                if (ex)
                    return ex;
                this->e1 = ae;  // restore
            }
        }
    }

    /* Run this->e1 semantic.
     */
    {
        Expression *e1x = e1;

        /* With UFCS, e.f = value
         * Could mean:
         *      .f(e, value)
         * or:
         *      .f(e) = value
         */
        if (e1x->op == TOKdotti)
        {
            DotTemplateInstanceExp *dti = (DotTemplateInstanceExp *)e1x;
            Expression *e = dti->semanticY(sc, 1);
            if (!e)
                return resolveUFCSProperties(sc, e1x, e2);
            e1x = e;
        }
        else if (e1x->op == TOKdot)
        {
            DotIdExp *die = (DotIdExp *)e1x;
            Expression *e = die->semanticY(sc, 1);
            if (e && isDotOpDispatch(e))
            {
                unsigned errors = global.startGagging();
                e = resolvePropertiesX(sc, e, e2);
                if (global.endGagging(errors))
                    e = NULL;   /* fall down to UFCS */
                else
                    return e;
            }
            if (!e)
                return resolveUFCSProperties(sc, e1x, e2);
            e1x = e;
        }
        else
            e1x = e1x->semantic(sc);

        /* We have f = value.
         * Could mean:
         *      f(value)
         * or:
         *      f() = value
         */
        if (Expression *e = resolvePropertiesX(sc, e1x, e2))
            return e;

        e1x = checkRightThis(sc, e1x);

        if (e1x->op == TOKerror)
            return e1x;
        e1 = e1x;
        assert(e1->type);
    }
    Type *t1 = e1->type->toBasetype();

    /* Run this->e2 semantic.
     * Different from other binary expressions, the analysis of e2
     * depends on the result of e1 in assignments.
     */
    {
        Expression *e2x = inferType(e2, t1->baseElemOf());

        e2x = e2x->semantic(sc);
        e2x = resolveProperties(sc, e2x);

        if (e2x->op == TOKerror)
            return e2x;
        if (!e2x->rvalue())
            return new ErrorExp();
        e2 = e2x;
    }

    /* Rewrite tuple assignment as a tuple of assignments.
     */
    {
        Expression *e2x = e2;

    Ltupleassign:
        if (e1->op == TOKtuple && e2x->op == TOKtuple)
        {
            TupleExp *tup1 = (TupleExp *)e1;
            TupleExp *tup2 = (TupleExp *)e2x;
            size_t dim = tup1->exps->dim;
            Expression *e = NULL;
            if (dim != tup2->exps->dim)
            {
                error("mismatched tuple lengths, %d and %d", (int)dim, (int)tup2->exps->dim);
                return new ErrorExp();
            }
            if (dim == 0)
            {
                e = new IntegerExp(loc, 0, Type::tint32);
                e = new CastExp(loc, e, Type::tvoid);   // avoid "has no effect" error
                e = combine(combine(tup1->e0, tup2->e0), e);
            }
            else
            {
                Expressions *exps = new Expressions;
                exps->setDim(dim);
                for (size_t i = 0; i < dim; i++)
                {
                    Expression *ex1 = (*tup1->exps)[i];
                    Expression *ex2 = (*tup2->exps)[i];
                    (*exps)[i] = new AssignExp(loc, ex1, ex2);
                }
                e = new TupleExp(loc, combine(tup1->e0, tup2->e0), exps);
            }
            return e->semantic(sc);
        }

        /* Look for form: e1 = e2->aliasthis.
         */
        if (e1->op == TOKtuple)
        {
            TupleDeclaration *td = isAliasThisTuple(e2x);
            if (!td)
                goto Lnomatch;

            assert(e1->type->ty == Ttuple);
            TypeTuple *tt = (TypeTuple *)e1->type;

            Identifier *id = Identifier::generateId("__tup");
            ExpInitializer *ei = new ExpInitializer(e2x->loc, e2x);
            VarDeclaration *v = new VarDeclaration(e2x->loc, NULL, id, ei);
            v->storage_class |= STCtemp | STCctfe;
            if (e2x->isLvalue())
                v->storage_class = STCref | STCforeach;
            Expression *e0 = new DeclarationExp(e2x->loc, v);
            Expression *ev = new VarExp(e2x->loc, v);
            ev->type = e2x->type;

            Expressions *iexps = new Expressions();
            iexps->push(ev);

            for (size_t u = 0; u < iexps->dim ; u++)
            {
            Lexpand:
                Expression *e = (*iexps)[u];

                Parameter *arg = Parameter::getNth(tt->arguments, u);
                //printf("[%d] iexps->dim = %d, ", u, iexps->dim);
                //printf("e = (%s %s, %s), ", Token::tochars[e->op], e->toChars(), e->type->toChars());
                //printf("arg = (%s, %s)\n", arg->toChars(), arg->type->toChars());

                if (!arg || !e->type->implicitConvTo(arg->type))
                {
                    // expand initializer to tuple
                    if (expandAliasThisTuples(iexps, u) != -1)
                    {
                        if (iexps->dim <= u)
                            break;
                        goto Lexpand;
                    }
                    goto Lnomatch;
                }
            }
            e2x = new TupleExp(e2x->loc, e0, iexps);
            e2x = e2x->semantic(sc);
            if (e2x->op == TOKerror)
                return e2x;
            // Do not need to overwrite this->e2
            goto Ltupleassign;
        }
    Lnomatch:
        ;
    }

    /* Inside constructor, if this is the first assignment of object field,
     * rewrite this to initializing the field.
     */
    if (op == TOKassign && e1->checkModifiable(sc) == 2)
    {
        //printf("[%s] change to init - %s\n", loc.toChars(), toChars());
        op = TOKconstruct;

        // Bugzilla 13515: set Index::modifiable flag for complex AA element initialization
        if (e1->op == TOKindex)
        {
            Expression *e1x = ((IndexExp *)e1)->markSettingAAElem();
            if (e1x->op == TOKerror)
                return e1x;
        }
    }

    /* If it is an assignment from a 'foreign' type,
     * check for operator overloading.
     */
    if (op == TOKconstruct && e1->op == TOKvar &&
        ((VarExp *)e1)->var->storage_class & (STCout | STCref))
    {
        // If this is an initialization of a reference,
        // do nothing
    }
    else if (t1->ty == Tstruct)
    {
        Expression *e1x = e1;
        Expression *e2x = e2;
        StructDeclaration *sd = ((TypeStruct *)t1)->sym;

        if (op == TOKconstruct)
        {
            Type *t2 = e2x->type->toBasetype();
            if (t2->ty == Tstruct && sd == ((TypeStruct *)t2)->sym)
            {
                CallExp *ce;
                DotVarExp *dve;
                if (sd->ctor &&
                    e2x->op == TOKcall &&
                    (ce = (CallExp *)e2x, ce->e1->op == TOKdotvar) &&
                    (dve = (DotVarExp *)ce->e1, dve->var->isCtorDeclaration()) &&
                    e2x->type->implicitConvTo(t1))
                {
                    /* Look for form of constructor call which is:
                     *    __ctmp.ctor(arguments...)
                     */

                    /* Before calling the constructor, initialize
                     * variable with a bit copy of the default
                     * initializer
                     */
                    AssignExp *ae = this;
                    if (sd->zeroInit == 1)
                        ae->e2 = new IntegerExp(loc, 0, Type::tint32);
                    else if (sd->isNested())
                        ae->e2 = t1->defaultInitLiteral(loc);
                    else
                        ae->e2 = t1->defaultInit(loc);
                    // Keep ae->op == TOKconstruct
                    ae->type = e1x->type;

                    /* Replace __ctmp being constructed with e1.
                     * We need to copy constructor call expression,
                     * because it may be used in other place.
                     */
                    DotVarExp *dvx = (DotVarExp *)dve->copy();
                    dvx->e1 = e1x;
                    CallExp *cx = (CallExp *)ce->copy();
                    cx->e1 = dvx;

                    Expression *e = new CommaExp(loc, ae, cx);
                    e = e->semantic(sc);
                    return e;
                }
                if (sd->postblit)
                {
                    /* We have a copy constructor for this
                     */
                    if (e2x->op == TOKquestion)
                    {
                        /* Rewrite as:
                         *  a ? e1 = b : e1 = c;
                         */
                        CondExp *econd = (CondExp *)e2x;
                        Expression *ea1 = new ConstructExp(econd->e1->loc, e1x, econd->e1);
                        Expression *ea2 = new ConstructExp(econd->e1->loc, e1x, econd->e2);
                        Expression *e = new CondExp(loc, econd->econd, ea1, ea2);
                        return e->semantic(sc);
                    }

                    if (e2x->isLvalue())
                    {
                        if (!e2x->type->implicitConvTo(e1x->type))
                        {
                            error("conversion error from %s to %s", e2x->type->toChars(), e1x->type->toChars());
                            return new ErrorExp();
                        }

                        /* Rewrite as:
                         *  (e1 = e2).postblit();
                         *
                         * Blit assignment e1 = e2 returns a reference to the original e1,
                         * then call the postblit on it.
                         */
                        Expression *e = e1x->copy();
                        e->type = e->type->mutableOf();
                        e = new BlitExp(loc, e, e2x);
                        e = new DotVarExp(loc, e, sd->postblit, 0);
                        e = new CallExp(loc, e);
                        return e->semantic(sc);
                    }
                    else
                    {
                        /* The struct value returned from the function is transferred
                         * so should not call the destructor on it.
                         */
                        e2x = valueNoDtor(e2x);
                    }
                }
            }
            else if (!e2x->implicitConvTo(t1))
            {
                if (sd->ctor)
                {
                    /* Look for implicit constructor call
                     * Rewrite as:
                     *  e1 = init, e1.ctor(e2)
                     */
                    Expression *einit;
                    einit = new BlitExp(loc, e1x, e1x->type->defaultInit(loc));
                    einit->type = e1x->type;

                    Expression *e;
                    e = new DotIdExp(loc, e1x, Id::ctor);
                    e = new CallExp(loc, e, e2x);
                    e = new CommaExp(loc, einit, e);
                    e = e->semantic(sc);
                    return e;
                }
                if (search_function(sd, Id::call))
                {
                    /* Look for static opCall
                     * (See bugzilla 2702 for more discussion)
                     * Rewrite as:
                     *  e1 = typeof(e1).opCall(arguments)
                     */
                    e2x = typeDotIdExp(e2x->loc, e1x->type, Id::call);
                    e2x = new CallExp(loc, e2x, this->e2);

                    e2x = e2x->semantic(sc);
                    e2x = resolveProperties(sc, e2x);
                    if (e2x->op == TOKerror)
                        return e2x;
                    if (!e2x->rvalue())
                        return new ErrorExp();
                }
            }
            else    // Bugzilla 11355
            {
                Expression *e = op_overload(sc);
                if (e)
                    return e;
            }
        }
        else if (op == TOKassign)
        {
            if (e1x->op == TOKindex &&
                ((IndexExp *)e1x)->e1->type->toBasetype()->ty == Taarray)
            {
                /*
                 * Rewrite:
                 *      aa[key] = e2;
                 * as:
                 *      ref __aatmp = aa;
                 *      ref __aakey = key;
                 *      ref __aaval = e2;
                 *      (__aakey in __aatmp
                 *          ? __aatmp[__aakey].opAssign(__aaval)
                 *          : ConstructExp(__aatmp[__aakey], __aaval));
                 */
                IndexExp *ie = (IndexExp *)e1x;
                Type *t2 = e2x->type->toBasetype();
                Expression *e0 = NULL;

                Expression *ea = ie->e1;
                Expression *ek = ie->e2;
                Expression *ev = e2x;
                if (!isTrivialExp(ea))
                {
                    VarDeclaration *v = new VarDeclaration(loc, ie->e1->type,
                        Identifier::generateId("__aatmp"), new ExpInitializer(loc, ie->e1));
                    v->storage_class |= STCtemp | STCctfe
                                     | (ea->isLvalue() ? STCforeach | STCref : STCrvalue);
                    v->semantic(sc);
                    e0 = combine(e0, new DeclarationExp(loc, v));
                    ea = new VarExp(loc, v);
                }
                if (!isTrivialExp(ek))
                {
                    VarDeclaration *v = new VarDeclaration(loc, ie->e2->type,
                        Identifier::generateId("__aakey"), new ExpInitializer(loc, ie->e2));
                    v->storage_class |= STCtemp | STCctfe
                                     | (ek->isLvalue() ? STCforeach | STCref : STCrvalue);
                    v->semantic(sc);
                    e0 = combine(e0, new DeclarationExp(loc, v));
                    ek = new VarExp(loc, v);
                }
                if (!isTrivialExp(ev))
                {
                    VarDeclaration *v = new VarDeclaration(loc, e2x->type,
                        Identifier::generateId("__aaval"), new ExpInitializer(loc, e2x));
                    v->storage_class |= STCtemp | STCctfe
                                     | (ev->isLvalue() ? STCforeach | STCref : STCrvalue);
                    v->semantic(sc);
                    e0 = combine(e0, new DeclarationExp(loc, v));
                    ev = new VarExp(loc, v);
                }
                if (e0)
                    e0 = e0->semantic(sc);

                AssignExp *ae = (AssignExp *)copy();
                ae->e1 = new IndexExp(loc, ea, ek);
                ae->e1 = ae->e1->semantic(sc);
                ae->e1 = ae->e1->optimize(WANTvalue);
                ae->e2 = ev;
                Expression *e = ae->op_overload(sc);
                if (e)
                {
                    Expression *ey = NULL;
                    if (t2->ty == Tstruct && sd == t2->toDsymbol(sc))
                    {
                        ey = ev;
                    }
                    else if (!ev->implicitConvTo(ie->type) && sd->ctor)
                    {
                        // Look for implicit constructor call
                        // Rewrite as S().ctor(e2)
                        ey = new StructLiteralExp(loc, sd, NULL);
                        ey = new DotIdExp(loc, ey, Id::ctor);
                        ey = new CallExp(loc, ey, ev);
                        ey = ey->trySemantic(sc);
                    }
                    if (ey)
                    {
                        Expression *ex;
                        ex = new IndexExp(loc, ea, ek);
                        ex = ex->semantic(sc);
                        ex = ex->optimize(WANTvalue);
                        ex = ex->modifiableLvalue(sc, ex);  // allocate new slot
                        ey = new ConstructExp(loc, ex, ey);

                        e = new CondExp(loc, new InExp(loc, ek, ea), e, ey);
                    }
                    e = combine(e0, e);
                    e = e->semantic(sc);
                    return e;
                }
            }
            else
            {
                Expression *e = op_overload(sc);
                if (e)
                    return e;
            }
        }
        else
            assert(op == TOKblit);

        e1 = e1x;
        e2 = e2x;
    }
    else if (t1->ty == Tclass)
    {
        // Disallow assignment operator overloads for same type
        if (op == TOKassign && !e2->implicitConvTo(e1->type))
        {
            Expression *e = op_overload(sc);
            if (e)
                return e;
        }
    }
    else if (t1->ty == Tsarray)
    {
        // SliceExp cannot have static array type without context inference.
        assert(e1->op != TOKslice);

        Expression *e1x = e1;
        Expression *e2x = e2;
        Type *t2 = e2x->type->toBasetype();

        if (e2x->implicitConvTo(e1x->type))
        {
            if (op != TOKblit &&
                (e2x->op == TOKslice && ((UnaExp *)e2x)->e1->isLvalue() ||
                 e2x->op == TOKcast  && ((UnaExp *)e2x)->e1->isLvalue() ||
                 e2x->op != TOKslice && e2x->isLvalue()))
            {
                e1x->checkPostblit(sc, t1);
            }
        }
        else
        {
            if (e2x->implicitConvTo(t1->nextOf()->arrayOf()) > MATCHnomatch)
            {
                uinteger_t dim1 = ((TypeSArray *)t1)->dim->toInteger();
                uinteger_t dim2 = dim1;
                if (e2x->op == TOKarrayliteral)
                {
                    ArrayLiteralExp *ale = (ArrayLiteralExp *)e2x;
                    dim2 = ale->elements ? ale->elements->dim : 0;
                }
                else if (e2x->op == TOKslice)
                {
                    Type *tx = toStaticArrayType((SliceExp *)e2x);
                    if (tx)
                        dim2 = ((TypeSArray *)tx)->dim->toInteger();
                }
                if (dim1 != dim2)
                {
                    error("mismatched array lengths, %d and %d", (int)dim1, (int)dim2);
                    return new ErrorExp();
                }
            }

            // May be block or element-wise assignment, so
            // convert e1 to e1[]
            if (op != TOKassign)
            {
                // If multidimensional static array, treat as one large array
                dinteger_t dim = ((TypeSArray *)t1)->dim->toInteger();
                Type *t = t1;
                while (1)
                {
                    t = t->nextOf()->toBasetype();
                    if (t->ty != Tsarray)
                        break;
                    dim *= ((TypeSArray *)t)->dim->toInteger();
                    e1x->type = t->nextOf()->sarrayOf(dim);
                }
            }
            e1x = new SliceExp(e1x->loc, e1x, NULL, NULL);
            e1x = e1x->semantic(sc);
        }
        if (e1x->op == TOKerror)
            return e1x;
        if (e2x->op == TOKerror)
            return e2x;

        e1 = e1x;
        e2 = e2x;
        t1 = e1x->type->toBasetype();
    }

    /* Check the mutability of e1.
     */
    if (e1->op == TOKarraylength)
    {
        // e1 is not an lvalue, but we let code generator handle it
        ArrayLengthExp *ale = (ArrayLengthExp *)e1;

        Expression *ale1x = ale->e1;
        ale1x = ale1x->modifiableLvalue(sc, e1);
        if (ale1x->op == TOKerror)
            return ale1x;
        ale->e1 = ale1x;

        Type *tn = ale->e1->type->toBasetype()->nextOf();
        checkDefCtor(ale->loc, tn);
        semanticTypeInfo(sc, tn);
    }
    else if (e1->op == TOKslice)
    {
        Type *tn = e1->type->nextOf();
        if (op == TOKassign && !tn->isMutable())
        {
            error("slice %s is not mutable", e1->toChars());
            return new ErrorExp();
        }
    }
    else
    {
        Expression *e1x = e1;

        // Try to do a decent error message with the expression
        // before it got constant folded
        if (e1x->op != TOKvar)
            e1x = e1x->optimize(WANTvalue);

        if (op == TOKassign)
            e1x = e1x->modifiableLvalue(sc, e1old);

        if (e1x->op == TOKerror)
            return e1x;
        e1 = e1x;
    }

    /* Tweak e2 based on the type of e1.
     */
    Expression *e2x = e2;
    Type *t2 = e2x->type->toBasetype();

    // If it is a array, get the element type. Note that it may be
    // multi-dimensional.
    Type *telem = t1;
    while (telem->ty == Tarray)
        telem = telem->nextOf();

    if (e1->op == TOKslice &&
        t1->nextOf() && (telem->ty != Tvoid || e2x->op == TOKnull) &&
        e2x->implicitConvTo(t1->nextOf())
       )
    {
        // Check for block assignment. If it is of type void[], void[][], etc,
        // '= null' is the only allowable block assignment (Bug 7493)
        // memset
        ismemset = 1;   // make it easy for back end to tell what this is
        e2x = e2x->implicitCastTo(sc, t1->nextOf());
        if (op != TOKblit && e2x->isLvalue())
            e1->checkPostblit(sc, t1->nextOf());
    }
    else if (e1->op == TOKslice &&
             (t2->ty == Tarray || t2->ty == Tsarray) &&
             t2->nextOf()->implicitConvTo(t1->nextOf()))
    {
        // Check element-wise assignment.

        /* If assigned elements number is known at compile time,
         * check the mismatch.
         */
        SliceExp *se1 = (SliceExp *)e1;
        TypeSArray *tsa1 = (TypeSArray *)toStaticArrayType(se1);
        TypeSArray *tsa2 = NULL;
        if (e2x->op == TOKarrayliteral)
            tsa2 = (TypeSArray *)t2->nextOf()->sarrayOf(((ArrayLiteralExp *)e2x)->elements->dim);
        else if (e2x->op == TOKslice)
            tsa2 = (TypeSArray *)toStaticArrayType((SliceExp *)e2x);
        else if (t2->ty == Tsarray)
            tsa2 = (TypeSArray *)t2;
        if (tsa1 && tsa2)
        {
            uinteger_t dim1 = tsa1->dim->toInteger();
            uinteger_t dim2 = tsa2->dim->toInteger();
            if (dim1 != dim2)
            {
                error("mismatched array lengths, %d and %d", (int)dim1, (int)dim2);
                return new ErrorExp();
            }
        }

        if (op != TOKblit &&
            (e2x->op == TOKslice && ((UnaExp *)e2x)->e1->isLvalue() ||
             e2x->op == TOKcast  && ((UnaExp *)e2x)->e1->isLvalue() ||
             e2x->op != TOKslice && e2x->isLvalue()))
        {
            e1->checkPostblit(sc, t1->nextOf());
        }

        if (0 && global.params.warnings && !global.gag && op == TOKassign &&
            e2x->op != TOKslice && e2x->op != TOKassign &&
            e2x->op != TOKarrayliteral && e2x->op != TOKstring &&
            !(e2x->op == TOKadd || e2x->op == TOKmin ||
              e2x->op == TOKmul || e2x->op == TOKdiv ||
              e2x->op == TOKmod || e2x->op == TOKxor ||
              e2x->op == TOKand || e2x->op == TOKor  ||
              e2x->op == TOKpow ||
              e2x->op == TOKtilde || e2x->op == TOKneg))
        {
            const char* e1str = e1->toChars();
            const char* e2str = e2x->toChars();
            warning("explicit element-wise assignment %s = (%s)[] is better than %s = %s",
                e1str, e2str, e1str, e2str);
        }

        Type *t2n = t2->nextOf();
        Type *t1n = t1->nextOf();
        int offset;
        if (t2n->equivalent(t1n) ||
            t1n->isBaseOf(t2n, &offset) && offset == 0)
        {
            /* Allow copy of distinct qualifier elements.
             * eg.
             *  char[] dst;  const(char)[] src;
             *  dst[] = src;
             *
             *  class C {}   class D : C {}
             *  C[2] ca;  D[] da;
             *  ca[] = da;
             */
            if (isArrayOpValid(e2x))
            {
                // Don't add CastExp to keep AST for array operations
                e2x = e2x->copy();
                e2x->type = e1->type->constOf();
            }
            else
                e2x = e2x->castTo(sc, e1->type->constOf());
        }
        else
            e2x = e2x->implicitCastTo(sc, e1->type);
    }
    else
    {
        if (0 && global.params.warnings && !global.gag && op == TOKassign &&
            t1->ty == Tarray && t2->ty == Tsarray &&
            e2x->op != TOKslice &&
            t2->implicitConvTo(t1))
        {   // Disallow ar[] = sa (Converted to ar[] = sa[])
            // Disallow da   = sa (Converted to da   = sa[])
            const char* e1str = e1->toChars();
            const char* e2str = e2x->toChars();
            const char* atypestr = e1->op == TOKslice ? "element-wise" : "slice";
            warning("explicit %s assignment %s = (%s)[] is better than %s = %s",
                atypestr, e1str, e2str, e1str, e2str);
        }
        if (op == TOKblit)
            e2x = e2x->castTo(sc, e1->type);
        else
            e2x = e2x->implicitCastTo(sc, e1->type);
    }
    if (e2x->op == TOKerror)
        return e2x;
    e2 = e2x;
    t2 = e2->type->toBasetype();

    /* Look for array operations
     */
    if ((t2->ty == Tarray || t2->ty == Tsarray) && isArrayOpValid(e2))
    {
        // Look for valid array operations
        if (!ismemset && e1->op == TOKslice &&
            (isUnaArrayOp(e2->op) || isBinArrayOp(e2->op)))
        {
            type = e1->type;
            return arrayOp(this, sc);
        }

        // Drop invalid array operations in e2
        //  d = a[] + b[], d = (a[] + b[])[0..2], etc
        if (checkNonAssignmentArrayOp(e2, !ismemset && op == TOKassign))
            return new ErrorExp();

        // Remains valid array assignments
        //  d = d[], d = [1,2,3], etc
    }

    if (e1->op == TOKvar &&
        (((VarExp *)e1)->var->storage_class & STCscope) &&
        op == TOKassign)
    {
        error("cannot rebind scope variables");
    }
    if (e1->op == TOKvar && ((VarExp *)e1)->var->ident == Id::ctfe)
    {
        error("cannot modify compiler-generated variable __ctfe");
    }

    type = e1->type;
    assert(type);
    return op == TOKassign ? reorderSettingAAElem(sc) : this;
}

bool AssignExp::isLvalue()
{
    // Array-op 'x[] = y[]' should make an rvalue.
    // Setting array length 'x.length = v' should make an rvalue.
    if (e1->op == TOKslice ||
        e1->op == TOKarraylength)
    {
        return false;
    }
    return true;
}

Expression *AssignExp::toLvalue(Scope *sc, Expression *ex)
{
    if (e1->op == TOKslice ||
        e1->op == TOKarraylength)
    {
        return Expression::toLvalue(sc, ex);
    }

    /* In front-end level, AssignExp should make an lvalue of e1.
     * Taking the address of e1 will be handled in low level layer,
     * so this function does nothing.
     */
    return this;
}

Expression *AssignExp::checkToBoolean(Scope *sc)
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

BlitExp::BlitExp(Loc loc, Expression *e1, Expression *e2)
    : AssignExp(loc, e1, e2)
{
    op = TOKblit;
}

/************************************************************/

AddAssignExp::AddAssignExp(Loc loc, Expression *e1, Expression *e2)
        : BinAssignExp(loc, TOKaddass, sizeof(AddAssignExp), e1, e2)
{
}

/************************************************************/

MinAssignExp::MinAssignExp(Loc loc, Expression *e1, Expression *e2)
        : BinAssignExp(loc, TOKminass, sizeof(MinAssignExp), e1, e2)
{
}

/************************************************************/

CatAssignExp::CatAssignExp(Loc loc, Expression *e1, Expression *e2)
        : BinAssignExp(loc, TOKcatass, sizeof(CatAssignExp), e1, e2)
{
}

Expression *CatAssignExp::semantic(Scope *sc)
{
    if (type)
        return this;

    //printf("CatAssignExp::semantic() %s\n", toChars());
    Expression *e = op_overload(sc);
    if (e)
        return e;

    if (e1->op == TOKslice)
    {
        SliceExp *se = (SliceExp *)e1;
        if (se->e1->type->toBasetype()->ty == Tsarray)
        {
            error("cannot append to static array %s", se->e1->type->toChars());
            return new ErrorExp();
        }
    }

    e1 = e1->modifiableLvalue(sc, e1);
    if (e1->op == TOKerror)
        return e1;
    if (e2->op == TOKerror)
        return e2;

    if (checkNonAssignmentArrayOp(e2))
        return new ErrorExp();

    Type *tb1 = e1->type->toBasetype();
    Type *tb1next = tb1->nextOf();
    Type *tb2 = e2->type->toBasetype();
    Type *tb2next = tb2->nextOf();

    if ((tb1->ty == Tarray) &&
        (tb2->ty == Tarray || tb2->ty == Tsarray) &&
        (e2->implicitConvTo(e1->type)
         || (tb2->nextOf()->implicitConvTo(tb1next) &&
             (tb2->nextOf()->size(Loc()) == tb1next->size(Loc())))
        )
       )
    {
        // Append array
        e1->checkPostblit(sc, tb1next);
        e2 = e2->castTo(sc, e1->type);
    }
    else if ((tb1->ty == Tarray) &&
        e2->implicitConvTo(tb1next)
       )
    {
        // Append element
        e2->checkPostblit(sc, tb2);
        e2 = e2->castTo(sc, tb1next);
        e2 = e2->isLvalue() ? callCpCtor(sc, e2) : valueNoDtor(e2);
    }
    else if (tb1->ty == Tarray &&
        (tb1next->ty == Tchar || tb1next->ty == Twchar) &&
        e2->type->ty != tb1next->ty &&
        e2->implicitConvTo(Type::tdchar)
       )
    {   // Append dchar to char[] or wchar[]
        e2 = e2->castTo(sc, Type::tdchar);

        /* Do not allow appending wchar to char[] because if wchar happens
         * to be a surrogate pair, nothing good can result.
         */
    }
    else
    {
        error("cannot append type %s to type %s", tb2->toChars(), tb1->toChars());
        return new ErrorExp();
    }
    if (!e2->rvalue())
        return new ErrorExp();

    type = e1->type;
    return reorderSettingAAElem(sc);
}

/************************************************************/

MulAssignExp::MulAssignExp(Loc loc, Expression *e1, Expression *e2)
        : BinAssignExp(loc, TOKmulass, sizeof(MulAssignExp), e1, e2)
{
}

/************************************************************/

DivAssignExp::DivAssignExp(Loc loc, Expression *e1, Expression *e2)
        : BinAssignExp(loc, TOKdivass, sizeof(DivAssignExp), e1, e2)
{
}

/************************************************************/

ModAssignExp::ModAssignExp(Loc loc, Expression *e1, Expression *e2)
        : BinAssignExp(loc, TOKmodass, sizeof(ModAssignExp), e1, e2)
{
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

/************************************************************/

OrAssignExp::OrAssignExp(Loc loc, Expression *e1, Expression *e2)
        : BinAssignExp(loc, TOKorass, sizeof(OrAssignExp), e1, e2)
{
}

/************************************************************/

XorAssignExp::XorAssignExp(Loc loc, Expression *e1, Expression *e2)
        : BinAssignExp(loc, TOKxorass, sizeof(XorAssignExp), e1, e2)
{
}

/***************** PowAssignExp *******************************************/

PowAssignExp::PowAssignExp(Loc loc, Expression *e1, Expression *e2)
        : BinAssignExp(loc, TOKpowass, sizeof(PowAssignExp), e1, e2)
{
}

Expression *PowAssignExp::semantic(Scope *sc)
{
    if (type)
        return this;

    Expression *e = op_overload(sc);
    if (e)
        return e;

    e = e1->checkReadModifyWrite(op, e2);
    if (e)
        return e;

    assert(e1->type && e2->type);
    if (e1->op == TOKslice || e1->type->ty == Tarray || e1->type->ty == Tsarray)
    {
        // T[] ^^= ...
        if (e2->implicitConvTo(e1->type->nextOf()))
        {
            // T[] ^^= T
            e2 = e2->castTo(sc, e1->type->nextOf());
        }
        else if (Expression *ex = typeCombine(this, sc))
            return ex;

        // Check element types are arithmetic
        Type *tb1 = e1->type->nextOf()->toBasetype();
        Type *tb2 = e2->type->toBasetype();
        if (tb2->ty == Tarray || tb2->ty == Tsarray)
            tb2 = tb2->nextOf()->toBasetype();

        if ( (tb1->isintegral() || tb1->isfloating()) &&
             (tb2->isintegral() || tb2->isfloating()))
        {
            type = e1->type;
            return arrayOp(this, sc);
        }
    }
    else
    {
        e1 = e1->modifiableLvalue(sc, e1);
    }

    if ((e1->type->isintegral() || e1->type->isfloating()) &&
        (e2->type->isintegral() || e2->type->isfloating()))
    {
        Expression *e0 = NULL;
        e = reorderSettingAAElem(sc);
        e = extractLast(e, &e0);
        assert(e == this);

        if (e1->op == TOKvar)
        {
            // Rewrite: e1 = e1 ^^ e2
            e = new PowExp(loc, e1->syntaxCopy(), e2);
            e = new AssignExp(loc, e1, e);
        }
        else
        {
            // Rewrite: ref tmp = e1; tmp = tmp ^^ e2
            Identifier *id = Identifier::generateId("__powtmp");
            VarDeclaration *v = new VarDeclaration(e1->loc, e1->type, id, new ExpInitializer(loc, e1));
            v->storage_class |= STCtemp | STCref | STCforeach;
            Expression *de = new DeclarationExp(e1->loc, v);
            VarExp *ve = new VarExp(e1->loc, v);
            e = new PowExp(loc, ve, e2);
            e = new AssignExp(loc, new VarExp(e1->loc, v), e);
            e = new CommaExp(loc, de, e);
        }
        e = Expression::combine(e0, e);
        e = e->semantic(sc);
        if (e->type->toBasetype()->ty == Tvector)
            return incompatibleTypes();
        return e;
    }
    return incompatibleTypes();
}

/************************* AddExp *****************************/

AddExp::AddExp(Loc loc, Expression *e1, Expression *e2)
        : BinExp(loc, TOKadd, sizeof(AddExp), e1, e2)
{
}

Expression *AddExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("AddExp::semantic('%s')\n", toChars());
#endif
    if (type)
        return this;

    if (Expression *ex = binSemanticProp(sc))
        return ex;
    Expression *e = op_overload(sc);
    if (e)
        return e;

    Type *tb1 = e1->type->toBasetype();
    Type *tb2 = e2->type->toBasetype();

    if (tb1->ty == Tdelegate ||
        tb1->ty == Tpointer && tb1->nextOf()->ty == Tfunction)
    {
        e = e1->checkArithmetic();
    }
    if (tb2->ty == Tdelegate ||
        tb2->ty == Tpointer && tb2->nextOf()->ty == Tfunction)
    {
        e = e2->checkArithmetic();
    }
    if (e)
        return e;

    if (tb1->ty == Tpointer && e2->type->isintegral() ||
        tb2->ty == Tpointer && e1->type->isintegral())
    {
        return scaleFactor(this, sc);
    }

    if (tb1->ty == Tpointer && tb2->ty == Tpointer)
    {
        return incompatibleTypes();
    }

    if (Expression *ex = typeCombine(this, sc))
        return ex;

    Type *tb = type->toBasetype();
    if (tb->ty == Tarray || tb->ty == Tsarray)
    {
        if (!isArrayOpValid(this))
        {
            error("invalid array operation %s (possible missing [])", toChars());
            return new ErrorExp();
        }
        return this;
    }

    tb1 = e1->type->toBasetype();
    if (tb1->ty == Tvector && !tb1->isscalar())
    {
        return incompatibleTypes();
    }
    if ((tb1->isreal() && e2->type->isimaginary()) ||
        (tb1->isimaginary() && e2->type->isreal()))
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
    return this;
}

/************************************************************/

MinExp::MinExp(Loc loc, Expression *e1, Expression *e2)
        : BinExp(loc, TOKmin, sizeof(MinExp), e1, e2)
{
}

Expression *MinExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("MinExp::semantic('%s')\n", toChars());
#endif
    if (type)
        return this;

    if (Expression *ex = binSemanticProp(sc))
        return ex;
    Expression *e = op_overload(sc);
    if (e)
        return e;

    Type *t1 = e1->type->toBasetype();
    Type *t2 = e2->type->toBasetype();

    if (t1->ty == Tdelegate ||
        t1->ty == Tpointer && t1->nextOf()->ty == Tfunction)
    {
        e = e1->checkArithmetic();
    }
    if (t2->ty == Tdelegate ||
        t2->ty == Tpointer && t2->nextOf()->ty == Tfunction)
    {
        e = e2->checkArithmetic();
    }
    if (e)
        return e;

    if (t1->ty == Tpointer)
    {
        if (t2->ty == Tpointer)
        {
            // Need to divide the result by the stride
            // Replace (ptr - ptr) with (ptr - ptr) / stride
            d_int64 stride;

            // make sure pointer types are compatible
            if (Expression *ex = typeCombine(this, sc))
                return ex;

            type = Type::tptrdiff_t;
            stride = t2->nextOf()->size();
            if (stride == 0)
            {
                e = new IntegerExp(loc, 0, Type::tptrdiff_t);
            }
            else
            {
                e = new DivExp(loc, this, new IntegerExp(Loc(), stride, Type::tptrdiff_t));
                e->type = Type::tptrdiff_t;
            }
        }
        else if (t2->isintegral())
            e = scaleFactor(this, sc);
        else
        {
            error("can't subtract %s from pointer", t2->toChars());
            e = new ErrorExp();
        }
        return e;
    }
    if (t2->ty == Tpointer)
    {
        type = e2->type;
        error("can't subtract pointer from %s", e1->type->toChars());
        return new ErrorExp();
    }

    if (Expression *ex = typeCombine(this, sc))
        return ex;

    Type *tb = type->toBasetype();
    if (tb->ty == Tarray || tb->ty == Tsarray)
    {
        if (!isArrayOpValid(this))
        {
            error("invalid array operation %s (possible missing [])", toChars());
            return new ErrorExp();
        }
        return this;
    }

    t1 = e1->type->toBasetype();
    t2 = e2->type->toBasetype();
    if (t1->ty == Tvector && !t1->isscalar())
    {
        return incompatibleTypes();
    }
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
    return this;
}

/************************* CatExp *****************************/

CatExp::CatExp(Loc loc, Expression *e1, Expression *e2)
        : BinExp(loc, TOKcat, sizeof(CatExp), e1, e2)
{
}

Expression *CatExp::semantic(Scope *sc)
{
    //printf("CatExp::semantic() %s\n", toChars());
    if (type)
        return this;

    if (Expression *ex = binSemanticProp(sc))
        return ex;
    Expression *e = op_overload(sc);
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
    Type *tb1next = tb1->nextOf();
    Type *tb2next = tb2->nextOf();

    if (tb1next && tb2next &&
        (tb1next->implicitConvTo(tb2next) >= MATCHconst ||
         tb2next->implicitConvTo(tb1next) >= MATCHconst)
       )
    {
        /* Here to avoid the case of:
         *    void*[] a = [cast(void*)1];
         *    void*[] b = [cast(void*)2];
         *    a ~ b;
         * becoming:
         *    a ~ [cast(void*)b];
         */
    }
    else if ((tb1->ty == Tsarray || tb1->ty == Tarray) &&
        e2->implicitConvTo(tb1next) >= MATCHconvert &&
        tb2->ty != Tvoid)
    {
        e2->checkPostblit(sc, tb2);
        e2 = e2->implicitCastTo(sc, tb1next);
        type = tb1next->arrayOf();
        if (tb2->ty == Tarray || tb2->ty == Tsarray)
        {
            // Make e2 into [e2]
            e2 = new ArrayLiteralExp(e2->loc, e2);
            e2->type = type;
        }
        return this;
    }
    else if ((tb2->ty == Tsarray || tb2->ty == Tarray) &&
        e1->implicitConvTo(tb2next) >= MATCHconvert &&
        tb1->ty != Tvoid)
    {
        e1->checkPostblit(sc, tb1);
        e1 = e1->implicitCastTo(sc, tb2next);
        type = tb2next->arrayOf();
        if (tb1->ty == Tarray || tb1->ty == Tsarray)
        {
            // Make e1 into [e1]
            e1 = new ArrayLiteralExp(e1->loc, e1);
            e1->type = type;
        }
        return this;
    }

    if ((tb1->ty == Tsarray || tb1->ty == Tarray) &&
        (tb2->ty == Tsarray || tb2->ty == Tarray) &&
        (tb1next->mod || tb2next->mod) &&
        (tb1next->mod != tb2next->mod)
       )
    {
        Type *t1 = tb1next->mutableOf()->constOf()->arrayOf();
        Type *t2 = tb2next->mutableOf()->constOf()->arrayOf();
        if (e1->op == TOKstring && !((StringExp *)e1)->committed)
            e1->type = t1;
        else
            e1 = e1->castTo(sc, t1);
        if (e2->op == TOKstring && !((StringExp *)e2)->committed)
            e2->type = t2;
        else
            e2 = e2->castTo(sc, t2);
    }

    if (Expression *ex = typeCombine(this, sc))
        return ex;
    type = type->toHeadMutable();

    Type *tb = type->toBasetype();
    if (tb->ty == Tsarray)
        type = tb->nextOf()->arrayOf();
    if (type->ty == Tarray && tb1next && tb2next &&
        tb1next->mod != tb2next->mod)
    {
        type = type->nextOf()->toHeadMutable()->arrayOf();
    }
    if (Type *tbn = tb->nextOf())
    {
        checkPostblit(sc, tbn);
    }
#if 0
    e1->type->print();
    e2->type->print();
    type->print();
    print();
#endif
    Type *t1 = e1->type->toBasetype();
    Type *t2 = e2->type->toBasetype();
    if (e1->op == TOKstring && e2->op == TOKstring)
    {
        e = optimize(WANTvalue);
    }
    else if ((t1->ty == Tarray || t1->ty == Tsarray) &&
             (t2->ty == Tarray || t2->ty == Tsarray))
    {
        e = this;
    }
    else
    {
        //printf("(%s) ~ (%s)\n", e1->toChars(), e2->toChars());
        return incompatibleTypes();
    }

    e->type = e->type->semantic(loc, sc);
    return e;
}

/************************************************************/

MulExp::MulExp(Loc loc, Expression *e1, Expression *e2)
        : BinExp(loc, TOKmul, sizeof(MulExp), e1, e2)
{
}

Expression *MulExp::semantic(Scope *sc)
{
#if 0
    printf("MulExp::semantic() %s\n", toChars());
#endif
    if (type)
        return this;

    if (Expression *ex = binSemanticProp(sc))
        return ex;
    Expression *e = op_overload(sc);
    if (e)
        return e;

    if (Expression *ex = typeCombine(this, sc))
        return ex;

    Type *tb = type->toBasetype();
    if (tb->ty == Tarray || tb->ty == Tsarray)
    {
        if (!isArrayOpValid(this))
        {
            error("invalid array operation %s (possible missing [])", toChars());
            return new ErrorExp();
        }
        return this;
    }

    e1 = e1->checkArithmetic();
    e2 = e2->checkArithmetic();
    if (e1->op == TOKerror)
        return e1;
    if (e2->op == TOKerror)
        return e2;

    if (type->isfloating())
    {
        Type *t1 = e1->type;
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
            {

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
    else if (tb->ty == Tvector && ((TypeVector *)tb)->elementType()->size(loc) != 2)
    {
        // Only short[8] and ushort[8] work with multiply
        return incompatibleTypes();
    }
    return this;
}

/************************************************************/

DivExp::DivExp(Loc loc, Expression *e1, Expression *e2)
        : BinExp(loc, TOKdiv, sizeof(DivExp), e1, e2)
{
}

Expression *DivExp::semantic(Scope *sc)
{
    if (type)
        return this;

    if (Expression *ex = binSemanticProp(sc))
        return ex;
    Expression *e = op_overload(sc);
    if (e)
        return e;

    if (Expression *ex = typeCombine(this, sc))
        return ex;

    Type *tb = type->toBasetype();
    if (tb->ty == Tarray || tb->ty == Tsarray)
    {
        if (!isArrayOpValid(this))
        {
            error("invalid array operation %s (possible missing [])", toChars());
            return new ErrorExp();
        }
        return this;
    }

    e1 = e1->checkArithmetic();
    e2 = e2->checkArithmetic();
    if (e1->op == TOKerror)
        return e1;
    if (e2->op == TOKerror)
        return e2;

    if (type->isfloating())
    {
        Type *t1 = e1->type;
        Type *t2 = e2->type;

        if (t1->isreal())
        {
            type = t2;
            if (t2->isimaginary())
            {
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
    else if (tb->ty == Tvector)
    {
        return incompatibleTypes();
    }
    return this;
}

/************************************************************/

ModExp::ModExp(Loc loc, Expression *e1, Expression *e2)
        : BinExp(loc, TOKmod, sizeof(ModExp), e1, e2)
{
}

Expression *ModExp::semantic(Scope *sc)
{
    if (type)
        return this;

    if (Expression *ex = binSemanticProp(sc))
        return ex;
    Expression *e = op_overload(sc);
    if (e)
        return e;

    if (Expression *ex = typeCombine(this, sc))
        return ex;

    Type *tb = type->toBasetype();
    if (tb->ty == Tarray || tb->ty == Tsarray)
    {
        if (!isArrayOpValid(this))
        {
            error("invalid array operation %s (possible missing [])", toChars());
            return new ErrorExp();
        }
        return this;
    }
    if (tb->ty == Tvector)
    {
        return incompatibleTypes();
    }

    e1 = e1->checkArithmetic();
    e2 = e2->checkArithmetic();
    if (e1->op == TOKerror)
        return e1;
    if (e2->op == TOKerror)
        return e2;

    if (type->isfloating())
    {
        type = e1->type;
        if (e2->type->iscomplex())
        {
            error("cannot perform modulo complex arithmetic");
            return new ErrorExp();
        }
    }
    return this;
}

/************************************************************/

PowExp::PowExp(Loc loc, Expression *e1, Expression *e2)
        : BinExp(loc, TOKpow, sizeof(PowExp), e1, e2)
{
}

Module *loadStdMath()
{
    static Import *impStdMath = NULL;
    if (!impStdMath)
    {
        Identifiers *a = new Identifiers();
        a->push(Id::std);
        Import *s = new Import(Loc(), a, Id::math, NULL, false);
        s->load(NULL);
        if (s->mod)
        {
            s->mod->importAll(NULL);
            s->mod->semantic();
        }
        impStdMath = s;
    }
    return impStdMath->mod;
}

Expression *PowExp::semantic(Scope *sc)
{
    if (type)
        return this;

    //printf("PowExp::semantic() %s\n", toChars());
    if (Expression *ex = binSemanticProp(sc))
        return ex;
    Expression *e = op_overload(sc);
    if (e)
        return e;

    if (Expression *ex = typeCombine(this, sc))
        return ex;

    Type *tb = type->toBasetype();
    if (tb->ty == Tarray || tb->ty == Tsarray)
    {
        if (!isArrayOpValid(this))
        {
            error("invalid array operation %s (possible missing [])", toChars());
            return new ErrorExp();
        }
        return this;
    }

    e1 = e1->checkArithmetic();
    e2 = e2->checkArithmetic();
    if (e1->op == TOKerror)
        return e1;
    if (e2->op == TOKerror)
        return e2;

    // For built-in numeric types, there are several cases.
    // TODO: backend support, especially for  e1 ^^ 2.

    // First, attempt to fold the expression.
    e = optimize(WANTvalue);
    if (e->op != TOKpow)
    {
        e = e->semantic(sc);
        return e;
    }

    // Determine if we're raising to an integer power.
    sinteger_t intpow = 0;
    if (e2->op == TOKint64 && ((sinteger_t)e2->toInteger() == 2 || (sinteger_t)e2->toInteger() == 3))
        intpow = e2->toInteger();
    else if (e2->op == TOKfloat64 && (e2->toReal() == (sinteger_t)(e2->toReal())))
        intpow = (sinteger_t)(e2->toReal());

    // Deal with x^^2, x^^3 immediately, since they are of practical importance.
    if (intpow == 2 || intpow == 3)
    {
        // Replace x^^2 with (tmp = x, tmp*tmp)
        // Replace x^^3 with (tmp = x, tmp*tmp*tmp)
        Identifier *idtmp = Identifier::generateId("__powtmp");
        VarDeclaration *tmp = new VarDeclaration(loc, e1->type->toBasetype(), idtmp, new ExpInitializer(Loc(), e1));
        tmp->storage_class |= STCtemp | STCctfe;
        Expression *ve = new VarExp(loc, tmp);
        Expression *ae = new DeclarationExp(loc, tmp);
        /* Note that we're reusing ve. This should be ok.
         */
        Expression *me = new MulExp(loc, ve, ve);
        if (intpow == 3)
            me = new MulExp(loc, me, ve);
        e = new CommaExp(loc, ae, me);
        e = e->semantic(sc);
        return e;
    }

    Module *mmath = loadStdMath();
    if (!mmath)
    {
        //error("requires std.math for ^^ operators");
        //fatal();

        // Leave handling of PowExp to the backend, or throw
        // an error gracefully if no backend support exists.
        if (Expression *ex = typeCombine(this, sc))
            return ex;
        return this;
    }
    e = new ScopeExp(loc, mmath);

    if (e2->op == TOKfloat64 && e2->toReal() == 0.5)
    {
        // Replace e1 ^^ 0.5 with .std.math.sqrt(x)
        e = new CallExp(loc, new DotIdExp(loc, e, Id::_sqrt), e1);
    }
    else
    {
        // Replace e1 ^^ e2 with .std.math.pow(e1, e2)
        e = new CallExp(loc, new DotIdExp(loc, e, Id::_pow), e1, e2);
    }
    e = e->semantic(sc);
    return e;
}

/************************************************************/

ShlExp::ShlExp(Loc loc, Expression *e1, Expression *e2)
        : BinExp(loc, TOKshl, sizeof(ShlExp), e1, e2)
{
}

Expression *ShlExp::semantic(Scope *sc)
{
    //printf("ShlExp::semantic(), type = %p\n", type);
    if (type)
        return this;

    if (Expression *ex = binSemanticProp(sc))
        return ex;
    Expression *e = op_overload(sc);
    if (e)
        return e;

    e1 = e1->checkIntegral();
    e2 = e2->checkIntegral();
    if (e1->type->toBasetype()->ty == Tvector ||
        e2->type->toBasetype()->ty == Tvector)
    {
        return incompatibleTypes();
    }
    e1 = integralPromotions(e1, sc);
    e2 = e2->castTo(sc, Type::tshiftcnt);

    type = e1->type;
    return this;
}

/************************************************************/

ShrExp::ShrExp(Loc loc, Expression *e1, Expression *e2)
        : BinExp(loc, TOKshr, sizeof(ShrExp), e1, e2)
{
}

Expression *ShrExp::semantic(Scope *sc)
{
    if (type)
        return this;

    if (Expression *ex = binSemanticProp(sc))
        return ex;
    Expression *e = op_overload(sc);
    if (e)
        return e;

    e1 = e1->checkIntegral();
    e2 = e2->checkIntegral();
    if (e1->type->toBasetype()->ty == Tvector ||
        e2->type->toBasetype()->ty == Tvector)
    {
        return incompatibleTypes();
    }
    e1 = integralPromotions(e1, sc);
    e2 = e2->castTo(sc, Type::tshiftcnt);

    type = e1->type;
    return this;
}

/************************************************************/

UshrExp::UshrExp(Loc loc, Expression *e1, Expression *e2)
        : BinExp(loc, TOKushr, sizeof(UshrExp), e1, e2)
{
}

Expression *UshrExp::semantic(Scope *sc)
{
    if (type)
        return this;

    if (Expression *ex = binSemanticProp(sc))
        return ex;
    Expression *e = op_overload(sc);
    if (e)
        return e;

    e1 = e1->checkIntegral();
    e2 = e2->checkIntegral();
    if (e1->type->toBasetype()->ty == Tvector ||
        e2->type->toBasetype()->ty == Tvector)
    {
        return incompatibleTypes();
    }

    e1 = integralPromotions(e1, sc);
    e2 = e2->castTo(sc, Type::tshiftcnt);

    type = e1->type;
    return this;
}

/************************************************************/

AndExp::AndExp(Loc loc, Expression *e1, Expression *e2)
        : BinExp(loc, TOKand, sizeof(AndExp), e1, e2)
{
}

Expression *AndExp::semantic(Scope *sc)
{
    if (type)
        return this;

    if (Expression *ex = binSemanticProp(sc))
        return ex;
    Expression *e = op_overload(sc);
    if (e)
        return e;

    if (e1->type->toBasetype()->ty == Tbool &&
        e2->type->toBasetype()->ty == Tbool)
    {
        type = e1->type;
        return this;
    }

    if (Expression *ex = typeCombine(this, sc))
        return ex;

    Type *tb = type->toBasetype();
    if (tb->ty == Tarray || tb->ty == Tsarray)
    {
        if (!isArrayOpValid(this))
        {
            error("invalid array operation %s (possible missing [])", toChars());
            return new ErrorExp();
        }
        return this;
    }

    e1 = e1->checkIntegral();
    e2 = e2->checkIntegral();
    if (e1->op == TOKerror)
        return e1;
    if (e2->op == TOKerror)
        return e2;

    return this;
}

/************************************************************/

OrExp::OrExp(Loc loc, Expression *e1, Expression *e2)
        : BinExp(loc, TOKor, sizeof(OrExp), e1, e2)
{
}

Expression *OrExp::semantic(Scope *sc)
{
    if (type)
        return this;

    if (Expression *ex = binSemanticProp(sc))
        return ex;
    Expression *e = op_overload(sc);
    if (e)
        return e;

    if (e1->type->toBasetype()->ty == Tbool &&
        e2->type->toBasetype()->ty == Tbool)
    {
        type = e1->type;
        return this;
    }

    if (Expression *ex = typeCombine(this, sc))
        return ex;

    Type *tb = type->toBasetype();
    if (tb->ty == Tarray || tb->ty == Tsarray)
    {
        if (!isArrayOpValid(this))
        {
            error("invalid array operation %s (possible missing [])", toChars());
            return new ErrorExp();
        }
        return this;
    }

    e1 = e1->checkIntegral();
    e2 = e2->checkIntegral();
    if (e1->op == TOKerror)
        return e1;
    if (e2->op == TOKerror)
        return e2;

    return this;
}

/************************************************************/

XorExp::XorExp(Loc loc, Expression *e1, Expression *e2)
        : BinExp(loc, TOKxor, sizeof(XorExp), e1, e2)
{
}

Expression *XorExp::semantic(Scope *sc)
{
    if (type)
        return this;

    if (Expression *ex = binSemanticProp(sc))
        return ex;
    Expression *e = op_overload(sc);
    if (e)
        return e;

    if (e1->type->toBasetype()->ty == Tbool &&
        e2->type->toBasetype()->ty == Tbool)
    {
        type = e1->type;
        return this;
    }

    if (Expression *ex = typeCombine(this, sc))
        return ex;

    Type *tb = type->toBasetype();
    if (tb->ty == Tarray || tb->ty == Tsarray)
    {
        if (!isArrayOpValid(this))
        {
            error("invalid array operation %s (possible missing [])", toChars());
            return new ErrorExp();
        }
        return this;
    }

    e1 = e1->checkIntegral();
    e2 = e2->checkIntegral();
    if (e1->op == TOKerror)
        return e1;
    if (e2->op == TOKerror)
        return e2;

    return this;
}


/************************************************************/

OrOrExp::OrOrExp(Loc loc, Expression *e1, Expression *e2)
        : BinExp(loc, TOKoror, sizeof(OrOrExp), e1, e2)
{
}

Expression *OrOrExp::semantic(Scope *sc)
{
    // same as for AndAnd
    e1 = e1->semantic(sc);
    e1 = resolveProperties(sc, e1);
    e1 = e1->checkToBoolean(sc);
    unsigned cs1 = sc->callSuper;

    if (sc->flags & SCOPEcondition)
    {
        /* If in static if, don't evaluate e2 if we don't have to.
         */
        e1 = e1->optimize(WANTvalue);
        if (e1->isBool(true))
        {
            return new IntegerExp(loc, 1, Type::tbool);
        }
    }

    e2 = e2->semantic(sc);
    sc->mergeCallSuper(loc, cs1);
    e2 = resolveProperties(sc, e2);

    if (e2->type->ty == Tvoid)
        type = Type::tvoid;
    else
    {
        e2 = e2->checkToBoolean(sc);
        type = Type::tbool;
    }
    if (e2->op == TOKtype || e2->op == TOKimport)
    {
        error("%s is not an expression", e2->toChars());
        return new ErrorExp();
    }
    if (e1->op == TOKerror)
        return e1;
    if (e2->op == TOKerror)
        return e2;

    return this;
}

Expression *OrOrExp::checkToBoolean(Scope *sc)
{
    e2 = e2->checkToBoolean(sc);
    return this;
}

/************************************************************/

AndAndExp::AndAndExp(Loc loc, Expression *e1, Expression *e2)
        : BinExp(loc, TOKandand, sizeof(AndAndExp), e1, e2)
{
}

Expression *AndAndExp::semantic(Scope *sc)
{
    // same as for OrOr
    e1 = e1->semantic(sc);
    e1 = resolveProperties(sc, e1);
    e1 = e1->checkToBoolean(sc);
    unsigned cs1 = sc->callSuper;

    if (sc->flags & SCOPEcondition)
    {
        /* If in static if, don't evaluate e2 if we don't have to.
         */
        e1 = e1->optimize(WANTvalue);
        if (e1->isBool(false))
        {
            return new IntegerExp(loc, 0, Type::tbool);
        }
    }

    e2 = e2->semantic(sc);
    sc->mergeCallSuper(loc, cs1);
    e2 = resolveProperties(sc, e2);

    if (e2->type->ty == Tvoid)
        type = Type::tvoid;
    else
    {
        e2 = e2->checkToBoolean(sc);
        type = Type::tbool;
    }
    if (e2->op == TOKtype || e2->op == TOKimport)
    {
        error("%s is not an expression", e2->toChars());
        return new ErrorExp();
    }
    if (e1->op == TOKerror)
        return e1;
    if (e2->op == TOKerror)
        return e2;

    return this;
}

Expression *AndAndExp::checkToBoolean(Scope *sc)
{
    e2 = e2->checkToBoolean(sc);
    return this;
}

/************************************************************/

InExp::InExp(Loc loc, Expression *e1, Expression *e2)
        : BinExp(loc, TOKin, sizeof(InExp), e1, e2)
{
}

Expression *InExp::semantic(Scope *sc)
{
    if (type)
        return this;

    if (Expression *ex = binSemanticProp(sc))
        return ex;
    Expression *e = op_overload(sc);
    if (e)
        return e;

    Type *t2b = e2->type->toBasetype();
    switch (t2b->ty)
    {
        case Taarray:
        {
            TypeAArray *ta = (TypeAArray *)t2b;

            // Special handling for array keys
            if (!arrayTypeCompatible(e1->loc, e1->type, ta->index))
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

/************************************************************/

/* This deletes the key e1 from the associative array e2
 */

RemoveExp::RemoveExp(Loc loc, Expression *e1, Expression *e2)
        : BinExp(loc, TOKremove, sizeof(RemoveExp), e1, e2)
{
    type = Type::tbool;
}

Expression *RemoveExp::semantic(Scope *sc)
{
    if (Expression *ex = binSemantic(sc))
        return ex;
    return this;
}

/************************************************************/

CmpExp::CmpExp(TOK op, Loc loc, Expression *e1, Expression *e2)
        : BinExp(loc, op, sizeof(CmpExp), e1, e2)
{
}

Expression *CmpExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("CmpExp::semantic('%s')\n", toChars());
#endif
    if (type)
        return this;

    if (Expression *ex = binSemanticProp(sc))
        return ex;
    Type *t1 = e1->type->toBasetype();
    Type *t2 = e2->type->toBasetype();
    if (t1->ty == Tclass && e2->op == TOKnull ||
        t2->ty == Tclass && e1->op == TOKnull)
    {
        error("do not use null when comparing class types");
        return new ErrorExp();
    }

    Expression *e = op_overload(sc);
    if (e)
    {
        if (!e->type->isscalar() && e->type->equals(e1->type))
        {
            error("recursive opCmp expansion");
            return new ErrorExp();
        }
        if (e->op == TOKcall)
        {
            e = new CmpExp(op, loc, e, new IntegerExp(loc, 0, Type::tint32));
            e = e->semantic(sc);
        }
        return e;
    }

    if (Expression *ex = typeCombine(this, sc))
        return ex;

    type = Type::tbool;

    // Special handling for array comparisons
    t1 = e1->type->toBasetype();
    t2 = e2->type->toBasetype();
    if ((t1->ty == Tarray || t1->ty == Tsarray || t1->ty == Tpointer) &&
        (t2->ty == Tarray || t2->ty == Tsarray || t2->ty == Tpointer))
    {
        Type *t1next = t1->nextOf();
        Type *t2next = t2->nextOf();
        if (t1next->implicitConvTo(t2next) < MATCHconst &&
            t2next->implicitConvTo(t1next) < MATCHconst &&
            (t1next->ty != Tvoid && t2next->ty != Tvoid))
        {
            error("array comparison type mismatch, %s vs %s", t1next->toChars(), t2next->toChars());
            return new ErrorExp();
        }
    }
    else if (t1->ty == Tstruct || t2->ty == Tstruct ||
             (t1->ty == Tclass && t2->ty == Tclass))
    {
        if (t2->ty == Tstruct)
            error("need member function opCmp() for %s %s to compare", t2->toDsymbol(sc)->kind(), t2->toChars());
        else
            error("need member function opCmp() for %s %s to compare", t1->toDsymbol(sc)->kind(), t1->toChars());
        return new ErrorExp();
    }
    else if (t1->iscomplex() || t2->iscomplex())
    {
        error("compare not defined for complex operands");
        return new ErrorExp();
    }
    else if (t1->ty == Taarray || t2->ty == Taarray)
    {
        error("%s is not defined for associative arrays", Token::toChars(op));
        return new ErrorExp();
    }
    else if (t1->ty == Tvector)
    {
        return incompatibleTypes();
    }
    else
    {
        if (!e1->rvalue() || !e2->rvalue())
            return new ErrorExp();
    }

    TOK altop;
    switch (op)
    {
        // Refer rel_integral[] table
        case TOKunord:  altop = TOKerror;       break;
        case TOKlg:     altop = TOKnotequal;    break;
        case TOKleg:    altop = TOKerror;       break;
        case TOKule:    altop = TOKle;          break;
        case TOKul:     altop = TOKlt;          break;
        case TOKuge:    altop = TOKge;          break;
        case TOKug:     altop = TOKgt;          break;
        case TOKue:     altop = TOKequal;       break;
        default:        altop = TOKreserved;    break;
    }
    if (altop == TOKerror &&
        (t1->ty == Tarray || t1->ty == Tsarray ||
         t2->ty == Tarray || t2->ty == Tsarray))
    {
        error("'%s' is not defined for array comparisons", Token::toChars(op));
        return new ErrorExp();
    }
    if (altop != TOKreserved)
    {
        if (!t1->isfloating())
        {
            if (altop == TOKerror)
            {
                const char *s = op == TOKunord ? "false" : "true";
                deprecation("floating point operator '%s' always returns %s for non-floating comparisons",
                    Token::toChars(op), s);
            }
            else
            {
                deprecation("use '%s' for non-floating comparisons rather than floating point operator '%s'",
                    Token::toChars(altop), Token::toChars(op));
            }
        }
        else
        {
            deprecation("use std.math.isNaN to deal with NaN operands rather than floating point operator '%s'",
                Token::toChars(op));
        }
    }

    //printf("CmpExp: %s, type = %s\n", e->toChars(), e->type->toChars());
    return this;
}

/************************************************************/

EqualExp::EqualExp(TOK op, Loc loc, Expression *e1, Expression *e2)
        : BinExp(loc, op, sizeof(EqualExp), e1, e2)
{
    assert(op == TOKequal || op == TOKnotequal);
}

bool needDirectEq(Scope *sc, Type *t1, Type *t2)
{
    assert(t1->ty == Tarray || t1->ty == Tsarray);
    assert(t2->ty == Tarray || t2->ty == Tsarray);

    Type *t1n = t1->nextOf()->toBasetype();
    Type *t2n = t2->nextOf()->toBasetype();

    if (((t1n->ty == Tchar || t1n->ty == Twchar || t1n->ty == Tdchar) &&
         (t2n->ty == Tchar || t2n->ty == Twchar || t2n->ty == Tdchar)) ||
        (t1n->ty == Tvoid || t2n->ty == Tvoid))
    {
        return false;
    }

    if (t1n->constOf() != t2n->constOf())
        return true;

    Type *t = t1n;
    while (t->toBasetype()->nextOf())
        t = t->nextOf()->toBasetype();
    if (t->ty != Tstruct)
        return false;

    semanticTypeInfo(sc, t);
    return ((TypeStruct *)t)->sym->hasIdentityEquals;
}

Expression *EqualExp::semantic(Scope *sc)
{
    //printf("EqualExp::semantic('%s')\n", toChars());
    if (type)
        return this;

    if (Expression *ex = binSemanticProp(sc))
        return ex;
    if (e1->op == TOKtype || e2->op == TOKtype)
        return incompatibleTypes();

    /* Before checking for operator overloading, check to see if we're
     * comparing the addresses of two statics. If so, we can just see
     * if they are the same symbol.
     */
    if (e1->op == TOKaddress && e2->op == TOKaddress)
    {
        AddrExp *ae1 = (AddrExp *)e1;
        AddrExp *ae2 = (AddrExp *)e2;
        if (ae1->e1->op == TOKvar && ae2->e1->op == TOKvar)
        {
            VarExp *ve1 = (VarExp *)ae1->e1;
            VarExp *ve2 = (VarExp *)ae2->e1;

            if (ve1->var == ve2->var)
            {
                // They are the same, result is 'true' for ==, 'false' for !=
                return new IntegerExp(loc, (op == TOKequal), Type::tbool);
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
        return new ErrorExp();
    }

    if ((t1->ty == Tarray || t1->ty == Tsarray) &&
        (t2->ty == Tarray || t2->ty == Tsarray))
    {
        if (needDirectEq(sc, t1, t2))
        {
            /* Rewrite as:
             * _ArrayEq(e1, e2)
             */
            Expression *eq = new IdentifierExp(loc, Id::_ArrayEq);
            Expression *e = new CallExp(loc, eq, e1, e2);
            if (op == TOKnotequal)
                e = new NotExp(loc, e);
            e = e->trySemantic(sc); // for better error message
            if (!e)
            {
                error("cannot compare %s and %s", t1->toChars(), t2->toChars());
                return new ErrorExp();
            }
            return e;
        }
    }

    Expression *e = op_overload(sc);
    if (e)
    {
        if (e->op == TOKcall && op == TOKnotequal)
        {
            e = new NotExp(e->loc, e);
            e = e->semantic(sc);
        }
        return e;
    }

    if (t1->ty == Tstruct && t2->ty == Tstruct)
    {
        StructDeclaration *sd = ((TypeStruct *)t1)->sym;
        if (sd == ((TypeStruct *)t2)->sym)
        {
            if (needOpEquals(sd))
            {
                this->e1 = new DotIdExp(loc, e1, Id::tupleof);
                this->e2 = new DotIdExp(loc, e2, Id::tupleof);
                e = this;
            }
            else
            {
                e = new IdentityExp(op == TOKequal ? TOKidentity : TOKnotidentity, loc, e1, e2);
            }
            e = e->semantic(sc);
            return e;
        }
    }

    // check tuple equality before typeCombine
    if (e1->op == TOKtuple && e2->op == TOKtuple)
    {
        TupleExp *tup1 = (TupleExp *)e1;
        TupleExp *tup2 = (TupleExp *)e2;
        size_t dim = tup1->exps->dim;
        e = NULL;
        if (dim != tup2->exps->dim)
        {
            error("mismatched tuple lengths, %d and %d", (int)dim, (int)tup2->exps->dim);
            return new ErrorExp();
        }
        if (dim == 0)
        {
            // zero-length tuple comparison should always return true or false.
            e = new IntegerExp(loc, (op == TOKequal), Type::tbool);
        }
        else
        {
            for (size_t i = 0; i < dim; i++)
            {
                Expression *ex1 = (*tup1->exps)[i];
                Expression *ex2 = (*tup2->exps)[i];
                Expression *eeq = new EqualExp(op, loc, ex1, ex2);
                if (!e)
                    e = eeq;
                else if (op == TOKequal)
                    e = new AndAndExp(loc, e, eeq);
                else
                    e = new OrOrExp(loc, e, eeq);
            }
        }
        assert(e);
        e = combine(combine(tup1->e0, tup2->e0), e);
        return e->semantic(sc);
    }

    if (Expression *ex = typeCombine(this, sc))
        return ex;

    type = Type::tbool;

    // Special handling for array comparisons
    if (!arrayTypeCompatible(loc, e1->type, e2->type))
    {
        if (e1->type != e2->type && e1->type->isfloating() && e2->type->isfloating())
        {
            // Cast both to complex
            e1 = e1->castTo(sc, Type::tcomplex80);
            e2 = e2->castTo(sc, Type::tcomplex80);
        }
    }
    if (e1->type->toBasetype()->ty == Taarray)
        semanticTypeInfo(sc, e1->type->toBasetype());

    if (e1->type->toBasetype()->ty == Tvector)
        return incompatibleTypes();

    return this;
}

/************************************************************/

IdentityExp::IdentityExp(TOK op, Loc loc, Expression *e1, Expression *e2)
        : BinExp(loc, op, sizeof(IdentityExp), e1, e2)
{
}

Expression *IdentityExp::semantic(Scope *sc)
{
    if (type)
        return this;

    if (Expression *ex = binSemanticProp(sc))
        return ex;
    type = Type::tbool;

    if (Expression *ex = typeCombine(this, sc))
        return ex;

    if (e1->type != e2->type && e1->type->isfloating() && e2->type->isfloating())
    {
        // Cast both to complex
        e1 = e1->castTo(sc, Type::tcomplex80);
        e2 = e2->castTo(sc, Type::tcomplex80);
    }

    if (e1->type->toBasetype()->ty == Tvector)
        return incompatibleTypes();

    return this;
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
{
#if LOGSEMANTIC
    printf("CondExp::semantic('%s')\n", toChars());
#endif
    if (type)
        return this;

    Expression *ec = econd->semantic(sc);
    ec = resolveProperties(sc, ec);
    ec = ec->checkToBoolean(sc);

    unsigned cs0 = sc->callSuper;
    unsigned *fi0 = sc->saveFieldInit();
    Expression *e1x = e1->semantic(sc);
    e1x = resolveProperties(sc, e1x);

    unsigned cs1 = sc->callSuper;
    unsigned *fi1 = sc->fieldinit;
    sc->callSuper = cs0;
    sc->fieldinit = fi0;
    Expression *e2x = e2->semantic(sc);
    e2x = resolveProperties(sc, e2x);

    sc->mergeCallSuper(loc, cs1);
    sc->mergeFieldInit(loc, fi1);

    if (ec->op == TOKerror) return ec;
    if (ec->type == Type::terror) return new ErrorExp();
    econd = ec;

    if (e1x->op == TOKerror) return e1x;
    if (e1x->type == Type::terror) return new ErrorExp();
    e1 = e1x;

    if (e2x->op == TOKerror) return e2x;
    if (e2x->type == Type::terror) return new ErrorExp();
    e2 = e2x;

    // If either operand is void, the result is void
    Type *t1 = e1->type;
    Type *t2 = e2->type;
    if (t1->ty == Tvoid || t2->ty == Tvoid)
        type = Type::tvoid;
    else if (t1 == t2)
        type = t1;
    else
    {
        if (Expression *ex = typeCombine(this, sc))
            return ex;
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
        if (type->toBasetype()->ty == Tarray)
        {
            e1 = e1->castTo(sc, type);
            e2 = e2->castTo(sc, type);
        }
    }
    type = type->merge2();
#if 0
    printf("res: %s\n", type->toChars());
    printf("e1 : %s\n", e1->type->toChars());
    printf("e2 : %s\n", e2->type->toChars());
#endif
    return this;
}

bool CondExp::isLvalue()
{
    return e1->isLvalue() && e2->isLvalue();
}


Expression *CondExp::toLvalue(Scope *sc, Expression *ex)
{
    // convert (econd ? e1 : e2) to *(econd ? &e1 : &e2)
    CondExp *e = (CondExp *)copy();
    e->e1 = e1->toLvalue(sc, NULL)->addressOf();
    e->e2 = e2->toLvalue(sc, NULL)->addressOf();
    return new PtrExp(loc, e, type);
}

int CondExp::checkModifiable(Scope *sc, int flag)
{
    return e1->checkModifiable(sc, flag) && e2->checkModifiable(sc, flag);
}

Expression *CondExp::modifiableLvalue(Scope *sc, Expression *e)
{
    //error("conditional expression %s is not a modifiable lvalue", toChars());
    e1 = e1->modifiableLvalue(sc, e1);
    e2 = e2->modifiableLvalue(sc, e2);
    return toLvalue(sc, this);
}

Expression *CondExp::checkToBoolean(Scope *sc)
{
    e1 = e1->checkToBoolean(sc);
    e2 = e2->checkToBoolean(sc);
    return this;
}

/****************************************************************/

DefaultInitExp::DefaultInitExp(Loc loc, TOK subop, int size)
    : Expression(loc, TOKdefault, size)
{
    this->subop = subop;
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

/****************************************************************/

ModuleInitExp::ModuleInitExp(Loc loc)
    : DefaultInitExp(loc, TOKmodulestring, sizeof(ModuleInitExp))
{
}

Expression *ModuleInitExp::semantic(Scope *sc)
{
    //printf("ModuleInitExp::semantic()\n");
    type = Type::tstring;
    return this;
}

Expression *ModuleInitExp::resolveLoc(Loc loc, Scope *sc)
{
    const char *s;
    if (sc->callsc)
        s = sc->callsc->module->toPrettyChars();
    else
        s = sc->module->toPrettyChars();
    Expression *e = new StringExp(loc, (char *)s);
    e = e->semantic(sc);
    e = e->castTo(sc, type);
    return e;
}

/****************************************************************/

FuncInitExp::FuncInitExp(Loc loc)
    : DefaultInitExp(loc, TOKfuncstring, sizeof(FuncInitExp))
{
}

Expression *FuncInitExp::semantic(Scope *sc)
{
    //printf("FuncInitExp::semantic()\n");
    type = Type::tstring;
    if (sc->func)
        return this->resolveLoc(Loc(), sc);
    return this;
}

Expression *FuncInitExp::resolveLoc(Loc loc, Scope *sc)
{
    const char *s;
    if (sc->callsc && sc->callsc->func)
        s = sc->callsc->func->Dsymbol::toPrettyChars();
    else if (sc->func)
        s = sc->func->Dsymbol::toPrettyChars();
    else
        s = "";
    Expression *e = new StringExp(loc, (char *)s);
    e = e->semantic(sc);
    e = e->castTo(sc, type);
    return e;
}

/****************************************************************/

PrettyFuncInitExp::PrettyFuncInitExp(Loc loc)
    : DefaultInitExp(loc, TOKprettyfunc, sizeof(PrettyFuncInitExp))
{
}

Expression *PrettyFuncInitExp::semantic(Scope *sc)
{
    //printf("PrettyFuncInitExp::semantic()\n");
    type = Type::tstring;
    if (sc->func)
        return this->resolveLoc(Loc(), sc);
    return this;
}

Expression *PrettyFuncInitExp::resolveLoc(Loc loc, Scope *sc)
{
    FuncDeclaration *fd;
    if (sc->callsc && sc->callsc->func)
        fd = sc->callsc->func;
    else
        fd = sc->func;

    const char *s;
    if (fd)
    {
        const char *funcStr = fd->Dsymbol::toPrettyChars();
        OutBuffer buf;
        functionToBufferWithIdent((TypeFunction *)fd->type, &buf, funcStr);
        s = buf.extractString();
    }
    else
    {
        s = "";
    }

    Expression *e = new StringExp(loc, (char *)s);
    e = e->semantic(sc);
    e = e->castTo(sc, type);
    return e;
}

/****************************************************************/

Expression *extractOpDollarSideEffect(Scope *sc, UnaExp *ue)
{
    Expression *e0;
    Expression *e1 = Expression::extractLast(ue->e1, &e0);
    // Bugzilla 12585: Extract the side effect part if ue->e1 is comma.

    if (!isTrivialExp(e1))
    {
        /* Even if opDollar is needed, 'e1' should be evaluate only once. So
         * Rewrite:
         *      e1.opIndex( ... use of $ ... )
         *      e1.opSlice( ... use of $ ... )
         * as:
         *      (ref __dop = e1, __dop).opIndex( ... __dop.opDollar ...)
         *      (ref __dop = e1, __dop).opSlice( ... __dop.opDollar ...)
         */
        Identifier *id = Identifier::generateId("__dop");
        ExpInitializer *ei = new ExpInitializer(ue->loc, e1);
        VarDeclaration *v = new VarDeclaration(ue->loc, e1->type, id, ei);
        v->storage_class |= STCtemp | STCctfe
                         | (e1->isLvalue() ? STCforeach | STCref : STCrvalue);
        Expression *de = new DeclarationExp(ue->loc, v);
        de = de->semantic(sc);
        e0 = Expression::combine(e0, de);
        e1 = new VarExp(ue->loc, v);
        e1 = e1->semantic(sc);
    }
    ue->e1 = e1;
    return e0;
}

/**************************************
 * Runs semantic on ae->arguments. Declares temporary variables
 * if '$' was used.
 */

Expression *resolveOpDollar(Scope *sc, ArrayExp *ae, Expression **pe0)
{
    assert(!ae->lengthVar);

    *pe0 = NULL;

    AggregateDeclaration *ad = isAggregate(ae->e1->type);
    Dsymbol *slice = search_function(ad, Id::slice);
    //printf("slice = %s %s\n", slice->kind(), slice->toChars());

    for (size_t i = 0; i < ae->arguments->dim; i++)
    {
        if (i == 0)
            *pe0 = extractOpDollarSideEffect(sc, ae);

        Expression *e = (*ae->arguments)[i];
        if (e->op == TOKinterval && !(slice && slice->isTemplateDeclaration()))
        {
        Lfallback:
            if (ae->arguments->dim == 1)
                return NULL;
            ae->error("multi-dimensional slicing requires template opSlice");
            return new ErrorExp();
        }
        //printf("[%d] e = %s\n", i, e->toChars());

        // Create scope for '$' variable for this dimension
        ArrayScopeSymbol *sym = new ArrayScopeSymbol(sc, ae);
        sym->loc = ae->loc;
        sym->parent = sc->scopesym;
        sc = sc->push(sym);
        ae->lengthVar = NULL;       // Create it only if required
        ae->currentDimension = i;   // Dimension for $, if required

        e = e->semantic(sc);
        e = resolveProperties(sc, e);

        if (ae->lengthVar && sc->func)
        {
            // If $ was used, declare it now
            Expression *de = new DeclarationExp(ae->loc, ae->lengthVar);
            de = de->semantic(sc);
            *pe0 = Expression::combine(*pe0, de);
        }
        sc = sc->pop();

        if (e->op == TOKinterval)
        {
            IntervalExp *ie = (IntervalExp *)e;

            Objects *tiargs = new Objects();
            Expression *edim = new IntegerExp(ae->loc, i, Type::tsize_t);
            edim = edim->semantic(sc);
            tiargs->push(edim);

            Expressions *fargs = new Expressions();
            fargs->push(ie->lwr);
            fargs->push(ie->upr);

            unsigned xerrors = global.startGagging();
            sc = sc->push();
            FuncDeclaration *fslice = resolveFuncCall(ae->loc, sc, slice, tiargs, ae->e1->type, fargs, 1);
            sc = sc->pop();
            global.endGagging(xerrors);
            if (!fslice)
                goto Lfallback;

            e = new DotTemplateInstanceExp(ae->loc, ae->e1, slice->ident, tiargs);
            e = new CallExp(ae->loc, e, fargs);
            e = e->semantic(sc);
        }

        if (!e->type)
        {
            ae->error("%s has no value", e->toChars());
            e = new ErrorExp();
        }
        if (e->op == TOKerror)
            return e;

        (*ae->arguments)[i] = e;
    }

    return ae;
}

/**************************************
 * Runs semantic on se->lwr and se->upr. Declares a temporary variable
 * if '$' was used.
 */

Expression *resolveOpDollar(Scope *sc, SliceExp *se, Expression **pe0)
{
    assert(!se->lengthVar);
    assert(!se->lwr || se->upr);

    if (!se->lwr)
        return se;

    *pe0 = extractOpDollarSideEffect(sc, se);

    // create scope for '$'
    ArrayScopeSymbol *sym = new ArrayScopeSymbol(sc, se);
    sym->loc = se->loc;
    sym->parent = sc->scopesym;
    sc = sc->push(sym);

    for (size_t i = 0; i < 2; ++i)
    {
        Expression *e = i == 0 ? se->lwr : se->upr;
        e = e->semantic(sc);
        e = resolveProperties(sc, e);
        if (!e->type)
        {
            se->error("%s has no value", e->toChars());
            return new ErrorExp();
        }
        (i == 0 ? se->lwr : se->upr) = e;
    }

    if (se->lengthVar && sc->func)
    {
        // If $ was used, declare it now
        Expression *de = new DeclarationExp(se->loc, se->lengthVar);
        de = de->semantic(sc);
        *pe0 = Expression::combine(*pe0, de);
    }
    sc = sc->pop();

    return se;
}

Expression *BinExp::reorderSettingAAElem(Scope *sc)
{
    BinExp *be = this;

    if (be->e1->op != TOKindex)
        return be;
    IndexExp *ie = (IndexExp *)be->e1;
    if (ie->e1->type->toBasetype()->ty != Taarray)
        return be;

    /* Fix evaluation order of setting AA element. (Bugzilla 3825)
     * Rewrite:
     *     aa[k1][k2][k3] op= val;
     * as:
     *     auto ref __aatmp = aa;
     *     auto ref __aakey3 = k1, __aakey2 = k2, __aakey1 = k3;
     *     auto ref __aaval = val;
     *     __aatmp[__aakey3][__aakey2][__aakey1] op= __aaval;  // assignment
     */

    Expression *de = NULL;
    while (1)
    {
        if (!isTrivialExp(ie->e2))
        {
            Identifier *id = Identifier::generateId("__aakey");
            VarDeclaration *vd = new VarDeclaration(ie->e2->loc, ie->e2->type, id, new ExpInitializer(ie->e2->loc, ie->e2));
            vd->storage_class |= STCtemp
                              | (ie->e2->isLvalue() ? STCref | STCforeach : STCrvalue);
            de = Expression::combine(new DeclarationExp(ie->e2->loc, vd), de);

            ie->e2 = new VarExp(ie->e2->loc, vd);
            ie->e2->type = vd->type;
        }

        Expression *ie1 = ie->e1;
        if (ie1->op != TOKindex ||
            ((IndexExp *)ie1)->e1->type->toBasetype()->ty != Taarray)
        {
            break;
        }
        ie = (IndexExp *)ie1;
    }
    assert(ie->e1->type->toBasetype()->ty == Taarray);

    if (!isTrivialExp(ie->e1))
    {
        Identifier *id = Identifier::generateId("__aatmp");
        VarDeclaration *vd = new VarDeclaration(ie->e1->loc, ie->e1->type, id, new ExpInitializer(ie->e1->loc, ie->e1));
        vd->storage_class |= STCtemp
                          | (ie->e1->isLvalue() ? STCref | STCforeach : STCrvalue);
        de = Expression::combine(new DeclarationExp(ie->e1->loc, vd), de);

        ie->e1 = new VarExp(ie->e1->loc, vd);
        ie->e1->type = vd->type;
    }

    {
        Identifier *id = Identifier::generateId("__aaval");
        VarDeclaration *vd = new VarDeclaration(be->loc, be->e2->type, id, new ExpInitializer(be->e2->loc, be->e2));
        vd->storage_class |= STCtemp
                          | (be->e2->isLvalue() ? STCref | STCforeach : STCrvalue);
        de = Expression::combine(de, new DeclarationExp(be->e2->loc, vd));

        be->e2 = new VarExp(be->e2->loc, vd);
        be->e2->type = vd->type;
    }

    de = de->semantic(sc);
    //printf("-de = %s, be = %s\n", de->toChars(), be->toChars());
    return Expression::combine(de, be);
}

/***************************************
 * Create a static array of TypeInfo references
 * corresponding to an array of Expression's.
 * Used to supply hidden _arguments[] value for variadic D functions.
 */

Expression *createTypeInfoArray(Scope *sc, Expression *exps[], size_t dim)
{
    /*
     * Pass a reference to the TypeInfo_Tuple corresponding to the types of the
     * arguments. Source compatibility is maintained by computing _arguments[]
     * at the start of the called function by offseting into the TypeInfo_Tuple
     * reference.
     */
    Parameters *args = new Parameters;
    args->setDim(dim);
    for (size_t i = 0; i < dim; i++)
    {
        Parameter *arg = new Parameter(STCin, exps[i]->type, NULL, NULL);
        (*args)[i] = arg;
    }
    TypeTuple *tup = new TypeTuple(args);
    Expression *e = getTypeInfo(tup, sc);
    e = e->optimize(WANTvalue);
    assert(e->op == TOKsymoff);         // should be SymOffExp

    return e;
}
