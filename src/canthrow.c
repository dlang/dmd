
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/canthrow.c
 */

#include <stdio.h>
#include <assert.h>

#include "mars.h"
#include "init.h"
#include "expression.h"
#include "template.h"
#include "statement.h"
#include "mtype.h"
#include "utf.h"
#include "declaration.h"
#include "aggregate.h"
#include "scope.h"
#include "attrib.h"

int Dsymbol_canThrow(Dsymbol *s, FuncDeclaration *func, bool mustNotThrow);
int walkPostorder(Expression *e, StoppableVisitor *v);

// Changed to return flags BEthrow and/or BEthrowobjc depending on which
// throwing mechanism is used. Both flags can be present at the same time
// which means that both types of exceptions can be thrown by this expression.

/********************************************
 * Returns true if the expression may throw exceptions.
 * If 'mustNotThrow' is true, generate an error if it throws
 */
int canThrow(Expression *e, FuncDeclaration *func, bool mustNotThrow)
{
    //printf("Expression::canThrow(%d) %s\n", mustNotThrow, e->toChars());

    // stop walking if we determine this expression can throw
    class CanThrow : public StoppableVisitor
    {
        FuncDeclaration *func;
        bool mustNotThrow;

    public:
        int result;

        CanThrow(FuncDeclaration *func, bool mustNotThrow)
            : func(func), mustNotThrow(mustNotThrow), result(0)
        {
        }

        void visit(Expression *)
        {
        }

        void visit(DeclarationExp *de)
        {
            result |= Dsymbol_canThrow(de->declaration, func, mustNotThrow);
            stop = result == BEthrowany;
        }

        void visit(CallExp *ce)
        {
            if (global.errors && !ce->e1->type)
                return;                       // error recovery

            /* If calling a function or delegate that is typed as nothrow,
             * then this expression cannot throw.
             * Note that pure functions can throw.
             */
            Type *t = ce->e1->type->toBasetype();
            if (ce->f && ce->f == func)
                ;
            else if (t->ty == Tfunction && ((TypeFunction *)t)->isnothrow)
                ;
            else if (t->ty == Tdelegate && ((TypeFunction *)((TypeDelegate *)t)->next)->isnothrow)
                ;
            else if (t->ty == Tobjcselector && ((TypeFunction *)((TypeObjcSelector *)t)->next)->isnothrow)
                ;
            else
            {
                int linkage;

                if (t->ty == Tfunction)
                    linkage = ((TypeFunction *)t)->linkage;
                else if (t->ty == Tdelegate)
                    linkage = ((TypeFunction *)((TypeDelegate *)t)->next)->linkage;
                else if (t->ty == Tobjcselector)
                    linkage = ((TypeFunction *)((TypeObjcSelector *)t)->next)->linkage;

                result |= linkage == LINKobjc ? BEthrowobjc : BEthrow;

                if (mustNotThrow)
                {
                    const char *s;
                    if (ce->f)
                        s = ce->f->toPrettyChars();
                    else if (ce->e1->op == TOKstar)
                    {
                        // print 'fp' if ce->e1 is (*fp)
                        s = ((PtrExp *)ce->e1)->e1->toChars();
                    }
                    else
                        s = ce->e1->toChars();
                    ce->error("'%s' is not nothrow", s);
                }
                stop = true;
            }
        }

        void visit(NewExp *ne)
        {
            if (ne->member)
            {
                // See if constructor call can throw
                Type *t = ne->member->type->toBasetype();
                if (t->ty == Tfunction && !((TypeFunction *)t)->isnothrow)
                {
                    if (mustNotThrow)
                        ne->error("constructor %s is not nothrow", ne->member->toChars());
                    if (((TypeFunction *)t)->linkage == LINKobjc)
                        result |= BEthrowobjc;
                    else
                        result |= BEthrow;
                    stop = result == BEthrowany;
                }
            }
            // regard storage allocation failures as not recoverable
        }

        void visit(AssignExp *ae)
        {
            // blit-init cannot throw
            if (ae->op == TOKblit)
                return;

            /* Element-wise assignment could invoke postblits.
             */
            Type *t;
            if (ae->type->toBasetype()->ty == Tsarray)
            {
                if (!ae->e2->isLvalue())
                    return;
                t = ae->type;
            }
            else if (ae->e1->op == TOKslice)
                t = ((SliceExp *)ae->e1)->e1->type;
            else
                return;

            Type *tv = t->baseElemOf();
            if (tv->ty != Tstruct)
                return;
            StructDeclaration *sd = ((TypeStruct *)tv)->sym;
            if (!sd->postblit || sd->postblit->type->ty != Tfunction)
                return;

            if (((TypeFunction *)sd->postblit->type)->isnothrow)
                ;
            else
            {
                if (mustNotThrow)
                    ae->error("'%s' is not nothrow", sd->postblit->toPrettyChars());
                if (((TypeFunction *)sd)->linkage == LINKobjc)
                    result |= BEthrowobjc;
                else
                    result |= BEthrow;
                stop = result == BEthrowany;
            }
        }

        void visit(NewAnonClassExp *)
        {
            assert(0);          // should have been lowered by semantic()
        }
    };

    CanThrow ct(func, mustNotThrow);
    walkPostorder(e, &ct);
    return ct.result;
}

/**************************************
 * Does symbol, when initialized, throw?
 * Mirrors logic in Dsymbol_toElem().
 */

int Dsymbol_canThrow(Dsymbol *s, FuncDeclaration *func, bool mustNotThrow)
{
    int result = 0;
    AttribDeclaration *ad;
    VarDeclaration *vd;
    TemplateMixin *tm;
    TupleDeclaration *td;

    //printf("Dsymbol_toElem() %s\n", s->toChars());
    ad = s->isAttribDeclaration();
    if (ad)
    {
        Dsymbols *decl = ad->include(NULL, NULL);
        if (decl && decl->dim)
        {
            for (size_t i = 0; i < decl->dim; i++)
            {
                s = (*decl)[i];
                result |= Dsymbol_canThrow(s, func, mustNotThrow);
                if (result == BEthrowany)
                    return result;
            }
        }
    }
    else if ((vd = s->isVarDeclaration()) != NULL)
    {
        s = s->toAlias();
        if (s != vd)
        {
            result |= Dsymbol_canThrow(s, func, mustNotThrow);
            if (result == BEthrowany)
                return result;
        }

        if (vd->storage_class & STCmanifest)
            ;
        else if (vd->isStatic() || vd->storage_class & (STCextern | STCtls | STCgshared))
            ;
        else
        {
            if (vd->init)
            {
                ExpInitializer *ie = vd->init->isExpInitializer();
                if (ie)
                {
                    result |= canThrow(ie->exp, func, mustNotThrow);
                    if (result == BEthrowany)
                        return result;
                }
            }
            if (vd->edtor && !vd->noscope)
            {
                return result | canThrow(vd->edtor, func, mustNotThrow);
            }
        }
    }
    else if ((tm = s->isTemplateMixin()) != NULL)
    {
        //printf("%s\n", tm->toChars());
        if (tm->members)
        {
            for (size_t i = 0; i < tm->members->dim; i++)
            {
                Dsymbol *sm = (*tm->members)[i];
                result |= Dsymbol_canThrow(sm, func, mustNotThrow);
                if (result == BEthrowany)
                    return result;
            }
        }
    }
    else if ((td = s->isTupleDeclaration()) != NULL)
    {
        for (size_t i = 0; i < td->objects->dim; i++)
        {
            RootObject *o = (*td->objects)[i];
            if (o->dyncast() == DYNCAST_EXPRESSION)
            {
                Expression *eo = (Expression *)o;
                if (eo->op == TOKdsymbol)
                {
                    DsymbolExp *se = (DsymbolExp *)eo;
                    result |= Dsymbol_canThrow(se->s, func, mustNotThrow);
                    if (result == BEthrowany)
                        return result;
                }
            }
        }
    }
    return result;
}
