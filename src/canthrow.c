
// Compiler implementation of the D programming language
// Copyright (c) 1999-2011 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

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

int Dsymbol_canThrow(Dsymbol *s, bool mustNotThrow);
int lambdaCanThrow(Expression *e, void *param);

/********************************************
 * Convert from expression to delegate that returns the expression,
 * i.e. convert:
 *      expr
 * to:
 *      t delegate() { return expr; }
 */

struct CanThrow
{
    int can;
    bool mustnot;
};

#if DMD_OBJC
// Changed to return flags BEthrow and/or BEthrowobjc depending on which
// throwing mechanism is used. Both flags can be present at the same time
// which means that both types of exceptions can be thrown by this expression.
#endif
int Expression::canThrow(bool mustNotThrow)
{
    //printf("Expression::canThrow(%d) %s\n", mustNotThrow, toChars());
    CanThrow ct;
    ct.can = FALSE;
    ct.mustnot = mustNotThrow;
    apply(&lambdaCanThrow, &ct);
    return ct.can;
}

int lambdaCanThrow(Expression *e, void *param)
{
    CanThrow *pct = (CanThrow *)param;
    switch (e->op)
    {
        case TOKdeclaration:
        {   DeclarationExp *de = (DeclarationExp *)e;
            pct->can = Dsymbol_canThrow(de->declaration, pct->mustnot);
            break;
        }

        case TOKcall:
        {   CallExp *ce = (CallExp *)e;

            if (global.errors && !ce->e1->type)
                break;                       // error recovery

            /* If calling a function or delegate that is typed as nothrow,
             * then this expression cannot throw.
             * Note that pure functions can throw.
             */
            Type *t = ce->e1->type->toBasetype();
#if DMD_OBJC
            if (t->ty == Tfunction && !((TypeFunction *)t)->isnothrow)
                pct->can |= (((TypeFunction *)t)->linkage == LINKobjc ? BEthrowobjc : BEthrow);
            else if (t->ty == Tdelegate && !((TypeFunction *)((TypeDelegate *)t)->next)->isnothrow)
                pct->can |= (((TypeFunction *)((TypeDelegate *)t)->next)->linkage == LINKobjc ? BEthrowobjc : BEthrow);
            else if (t->ty == Tobjcselector && !((TypeFunction *)((TypeObjcSelector *)t)->next)->isnothrow)
                pct->can |= (((TypeFunction *)((TypeObjcSelector *)t)->next)->linkage == LINKobjc ? BEthrowobjc : BEthrow);
#else
            if (t->ty == Tfunction && ((TypeFunction *)t)->isnothrow)
                ;
            else if (t->ty == Tdelegate && ((TypeFunction *)((TypeDelegate *)t)->next)->isnothrow)
                ;
#endif
            else
            {
                if (pct->mustnot)
#if DMD_OBJC
                    if (pct->can)
#endif
                    e->error("'%s' is not nothrow", ce->f ? ce->f->toPrettyChars() : ce->e1->toChars());
#if !DMD_OBJC
                pct->can = TRUE;
#endif
            }
            break;
        }

        case TOKnew:
        {   NewExp *ne = (NewExp *)e;
            if (ne->member)
            {
                // See if constructor call can throw
                Type *t = ne->member->type->toBasetype();
                if (t->ty == Tfunction && !((TypeFunction *)t)->isnothrow)
                {
                    if (pct->mustnot)
                        e->error("constructor %s is not nothrow", ne->member->toChars());
#if DMD_OBJC
                    if (((TypeFunction *)t)->linkage == LINKobjc)
                        pct->can |= BEthrowobjc;
                    else
                        pct->can |= BEthrow;
#else
                    pct->can = TRUE;
#endif
                }
            }
            // regard storage allocation failures as not recoverable
            break;
        }

        case TOKnewanonclass:
            assert(0);          // should have been lowered by semantic()
            break;

        default:
            break;
    }
    return pct->can; // stop walking if we determine this expression can throw
}

/**************************************
 * Does symbol, when initialized, throw?
 * Mirrors logic in Dsymbol_toElem().
 */

int Dsymbol_canThrow(Dsymbol *s, bool mustNotThrow)
{
#if DMD_OBJC
    int result = 0;
#endif
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
#if DMD_OBJC
                result |= Dsymbol_canThrow(s, mustNotThrow);
                if (result == BEthrowany)
                    return result;
#else
                if (Dsymbol_canThrow(s, mustNotThrow))
                    return 1;
#endif
            }
        }
    }
    else if ((vd = s->isVarDeclaration()) != NULL)
    {
        s = s->toAlias();
        if (s != vd)
#if DMD_OBJC
        {   result |= Dsymbol_canThrow(s, mustNotThrow);
            if (result == BEthrowany)
                return result;
        }
#else
            return Dsymbol_canThrow(s, mustNotThrow);
#endif
        if (vd->storage_class & STCmanifest)
            ;
        else if (vd->isStatic() || vd->storage_class & (STCextern | STCtls | STCgshared))
            ;
        else
        {
            if (vd->init)
            {   ExpInitializer *ie = vd->init->isExpInitializer();
#if DMD_OBJC
                if (ie)
                {   result |= ie->exp->canThrow(mustNotThrow);
                    if (result == BEthrowany)
                        return result;
                }
#else
                if (ie && ie->exp->canThrow(mustNotThrow))
                    return 1;
#endif
            }
            if (vd->edtor && !vd->noscope)
#if DMD_OBJC
                return result | vd->edtor->canThrow(mustNotThrow);
#else
                return vd->edtor->canThrow(mustNotThrow);
#endif
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
#if DMD_OBJC
                result |= Dsymbol_canThrow(sm, mustNotThrow);
                if (result == BEthrowany)
                    return result;
#else
                if (Dsymbol_canThrow(sm, mustNotThrow))
                    return 1;
#endif
            }
        }
    }
    else if ((td = s->isTupleDeclaration()) != NULL)
    {
        for (size_t i = 0; i < td->objects->dim; i++)
        {   Object *o = (*td->objects)[i];
            if (o->dyncast() == DYNCAST_EXPRESSION)
            {   Expression *eo = (Expression *)o;
                if (eo->op == TOKdsymbol)
                {   DsymbolExp *se = (DsymbolExp *)eo;
#if DMD_OBJC
                    result |= Dsymbol_canThrow(se->s, mustNotThrow);
                    if (result == BEthrowany)
                        return result;
#else
                    if (Dsymbol_canThrow(se->s, mustNotThrow))
                        return 1;
#endif
                }
            }
        }
    }
#if DMD_OBJC
    return result;
#else
    return 0;
#endif
}
