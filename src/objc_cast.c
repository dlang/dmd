
/* Compiler implementation of the D programming language
 * Copyright (c) 2014 by Digital Mars
 * All Rights Reserved
 * written by Michel Fortin
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/objc_cast.c
 */

#include "aggregate.h"
#include "declaration.h"
#include "expression.h"
#include "mtype.h"
#include "objc.h"
#include "scope.h"

// MARK: implicitConvTo

ControlFlow objc_implicitConvTo_visit_StringExp_Tclass(Type *t, MATCH *result)
{
    ClassDeclaration *cd = ((TypeClass *)t)->sym;
    if (cd->objc.objc && (cd->objc.takesStringLiteral))
    {
        *result = MATCHexact;
        return CFreturn;
    }
    return CFbreak;
}

MATCH objc_implicitConvTo_visit_ObjcSelectorExp(Type *&t, ObjcSelectorExp *e)
{
#if 0
    printf("ObjcSelectorExp::implicitConvTo(this=%s, type=%s, t=%s)\n",
           e->toChars(), e->type->toChars(), t->toChars());
#endif
    MATCH result = e->type->implicitConvTo(t);
    if (result != MATCHnomatch)
        return result;

    // Look for pointers to functions where the functions are overloaded.
    t = t->toBasetype();
    if (e->type->ty == Tobjcselector && e->type->nextOf()->ty == Tfunction &&
        t->ty == Tobjcselector && t->nextOf()->ty == Tfunction)
    {
        if (e->func && e->func->overloadExactMatch(t->nextOf()))
            result = MATCHexact;
    }

    return result;
}

// MARK: castTo

ControlFlow objc_castTo_visit_StringExp_Tclass(Scope *sc, Type *t, Expression *&result, StringExp *e, Type *tb)
{
    if (tb->ty == Tclass)
    {
        // convert to Objective-C NSString literal

        if (e->type->ty != Tclass) // not already converted to a string literal
        {
            if (((TypeClass *)tb)->sym->objc.objc &&
                ((TypeClass *)tb)->sym->objc.takesStringLiteral)
            {
                if (e->committed)
                {
                    e->error("cannot convert string literal to NSString because of explicit character type");
                    result = new ErrorExp();
                    return CFreturn;
                }
                e->type = t;
                e->semantic(sc);
            }
        }
        result = e;
        return CFreturn;
    }
    return CFnone;
}

ControlFlow objc_castTo_visit_StringExp_isSelector(Type *t, Expression *&result, StringExp *e, Type *tb)
{
    // Either a typed selector or a pointer to a struct designated as a
    // selector type
    if (tb->ty == Tobjcselector ||
        (tb->ty == Tpointer && tb->nextOf()->toBasetype()->ty == Tstruct &&
         ((TypeStruct *)tb->nextOf()->toBasetype())->sym->objc.isSelector))
    {
        if (e->committed)
        {
            e->error("cannot convert string literal to Objective-C selector because of explicit character type");
            result = new ErrorExp();
            return CFreturn;
        }
        Expression *ose = new ObjcSelectorExp(e->loc, (char *)e->string);
        ose->type = t;
        result = ose;
        return CFreturn;
    }
    return CFnone;
}

ControlFlow objc_castTo_visit_SymOffExp_Tobjcselector(Scope *sc, Expression *&result, SymOffExp *e, FuncDeclaration *f)
{
    if (f->objc.selector && f->linkage == LINKobjc && f->needThis())
    {
        result = new ObjcSelectorExp(e->loc, f);
        result = result->semantic(sc);
    }
    else
    {
        e->error("function %s has no selector", f->toChars());
        result = new ErrorExp();
    }

    return CFreturn;
}

ControlFlow objc_castTo_visit_DelegateExp_Tobjcselector(Type *t, Expression *&result, DelegateExp *e, Type *tb)
{
    static char msg2[] = "cannot form selector due to covariant return type";
    if (e->func)
    {
        FuncDeclaration *f = e->func->overloadExactMatch(tb->nextOf());
        if (f)
        {
            int offset;
            if (f->tintro && f->tintro->nextOf()->isBaseOf(f->type->nextOf(), &offset) && offset)
                e->error("%s", msg2);

            result = new ObjcSelectorExp(e->loc, f);
            result->type = t;
            return CFreturn;
        }
        if (e->func->tintro)
            e->error("%s", msg2);
    }

    return CFnone;
}

ControlFlow objc_castTo_visit_ObjcSelectorExp(Type *t, Expression *&result, ObjcSelectorExp *e)
{
#if 0
    printf("ObjcSelectorExp::castTo(this=%s, type=%s, t=%s)\n",
           e->toChars(), e->type->toChars(), t->toChars());
#endif
    static const char msg[] = "cannot form selector due to covariant return type";

    Type *tb = t->toBasetype();
    Type *typeb = e->type->toBasetype();
    if (tb != typeb)
    {
        // Look for delegates to functions where the functions are overloaded.
        if (typeb->ty == Tobjcselector && typeb->nextOf()->ty == Tfunction &&
            tb->ty == Tobjcselector && tb->nextOf()->ty == Tfunction)
        {
            if (e->func)
            {
                FuncDeclaration *f = e->func->overloadExactMatch(tb->nextOf());
                if (f)
                {
                    int offset;
                    if (f->tintro && f->tintro->nextOf()->isBaseOf(f->type->nextOf(), &offset) && offset)
                        e->error("%s", msg);

                    result = new ObjcSelectorExp(e->loc, f);
                    result->type = t;
                    return CFreturn;
                }
                if (e->func->tintro)
                    e->error("%s", msg);
            }
        }
        return CFvisit;
    }
    else
    {
        int offset;

        if (e->func && e->func->tintro && e->func->tintro->nextOf()->isBaseOf(e->func->type->nextOf(), &offset) && offset)
            e->error("%s", msg);
        result = e->copy();
        result->type = t;
    }

    return CFnone;
}
