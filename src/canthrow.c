
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

bool Dsymbol_canThrow(Dsymbol *s, bool mustNotThrow);
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
    bool can;
    bool mustnot;
};

bool Expression::canThrow(bool mustNotThrow)
{
    //printf("Expression::canThrow(%d) %s\n", mustNotThrow, toChars());
    CanThrow ct;
    ct.can = false;
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
        {
            DeclarationExp *de = (DeclarationExp *)e;
            pct->can = Dsymbol_canThrow(de->declaration, pct->mustnot);
            break;
        }

        case TOKcall:
        {
            CallExp *ce = (CallExp *)e;
            if (global.errors && !ce->e1->type)
                break;                       // error recovery

            /* If calling a function or delegate that is typed as nothrow,
             * then this expression cannot throw.
             * Note that pure functions can throw.
             */
            Type *t = ce->e1->type->toBasetype();
            if (t->ty == Tfunction && ((TypeFunction *)t)->isnothrow)
                ;
            else if (t->ty == Tdelegate && ((TypeFunction *)((TypeDelegate *)t)->next)->isnothrow)
                ;
            else
            {
                if (pct->mustnot)
                    e->error("'%s' is not nothrow", ce->f ? ce->f->toPrettyChars() : ce->e1->toChars());
                pct->can = true;
            }
            break;
        }

        case TOKnew:
        {
            NewExp *ne = (NewExp *)e;
            if (ne->member)
            {
                // See if constructor call can throw
                Type *t = ne->member->type->toBasetype();
                if (t->ty == Tfunction && !((TypeFunction *)t)->isnothrow)
                {
                    if (pct->mustnot)
                        e->error("constructor %s is not nothrow", ne->member->toChars());
                    pct->can = true;
                }
            }
            // regard storage allocation failures as not recoverable
            break;
        }

        case TOKassign:
        case TOKconstruct:
        {
            /* Element-wise assignment could invoke postblits.
             */
            AssignExp *ae = (AssignExp *)e;
            if (ae->e1->op != TOKslice)
                break;

            Type *tv = ae->e1->type->toBasetype()->nextOf()->baseElemOf();
            if (tv->ty != Tstruct)
                break;
            StructDeclaration *sd = ((TypeStruct *)tv)->sym;
            if (!sd->postblit || sd->postblit->type->ty != Tfunction)
                break;

            if (((TypeFunction *)sd->postblit->type)->isnothrow)
                ;
            else
            {
                if (pct->mustnot)
                    e->error("'%s' is not nothrow", sd->postblit->toPrettyChars());
                pct->can = true;
            }
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

bool Dsymbol_canThrow(Dsymbol *s, bool mustNotThrow)
{
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
                if (Dsymbol_canThrow(s, mustNotThrow))
                    return true;
            }
        }
    }
    else if ((vd = s->isVarDeclaration()) != NULL)
    {
        s = s->toAlias();
        if (s != vd)
            return Dsymbol_canThrow(s, mustNotThrow);
        if (vd->storage_class & STCmanifest)
            ;
        else if (vd->isStatic() || vd->storage_class & (STCextern | STCtls | STCgshared))
            ;
        else
        {
            if (vd->init)
            {   ExpInitializer *ie = vd->init->isExpInitializer();
                if (ie && ie->exp->canThrow(mustNotThrow))
                    return true;
            }
            if (vd->edtor && !vd->noscope)
                return vd->edtor->canThrow(mustNotThrow);
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
                if (Dsymbol_canThrow(sm, mustNotThrow))
                    return true;
            }
        }
    }
    else if ((td = s->isTupleDeclaration()) != NULL)
    {
        for (size_t i = 0; i < td->objects->dim; i++)
        {   RootObject *o = (*td->objects)[i];
            if (o->dyncast() == DYNCAST_EXPRESSION)
            {   Expression *eo = (Expression *)o;
                if (eo->op == TOKdsymbol)
                {   DsymbolExp *se = (DsymbolExp *)eo;
                    if (Dsymbol_canThrow(se->s, mustNotThrow))
                        return true;
                }
            }
        }
    }
    return false;
}
