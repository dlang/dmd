
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

int lambdaHasSideEffect(Expression *e, void *param);

/********************************************
 * Determine if Expression has any side effects.
 */

bool Expression::hasSideEffect()
{
    bool has = false;
    apply(&lambdaHasSideEffect, &has);
    return has;
}

int lambdaHasSideEffect(Expression *e, void *param)
{
    bool *phas = (bool *)param;
    switch (e->op)
    {
        // Sort the cases by most frequently used first
        case TOKassign:
        case TOKplusplus:
        case TOKminusminus:
        case TOKdeclaration:
        case TOKconstruct:
        case TOKblit:
        case TOKaddass:
        case TOKminass:
        case TOKcatass:
        case TOKmulass:
        case TOKdivass:
        case TOKmodass:
        case TOKshlass:
        case TOKshrass:
        case TOKushrass:
        case TOKandass:
        case TOKorass:
        case TOKxorass:
        case TOKpowass:
        case TOKin:
        case TOKremove:
        case TOKassert:
        case TOKhalt:
        case TOKdelete:
        case TOKnew:
        case TOKnewanonclass:
            *phas = true;
            break;

        case TOKcall:
        {   CallExp *ce = (CallExp *)e;

            /* Calling a function or delegate that is pure nothrow
             * has no side effects.
             */
            if (ce->e1->type)
            {
                Type *t = ce->e1->type->toBasetype();
                if ((t->ty == Tfunction && ((TypeFunction *)t)->purity > PUREweak &&
                                           ((TypeFunction *)t)->isnothrow)
                    ||
                    (t->ty == Tdelegate && ((TypeFunction *)((TypeDelegate *)t)->next)->purity > PUREweak &&
                                           ((TypeFunction *)((TypeDelegate *)t)->next)->isnothrow)
                   )
                {
                }
                else
                    *phas = true;
            }
            break;
        }

        case TOKcast:
        {   CastExp *ce = (CastExp *)e;

            /* if:
             *  cast(classtype)func()  // because it may throw
             */
            if (ce->to->ty == Tclass && ce->e1->op == TOKcall && ce->e1->type->ty == Tclass)
                *phas = true;
            break;
        }

        default:
            break;
    }
    return *phas; // stop walking if we determine this expression has side effects
}


/***********************************
 * The result of this expression will be discarded.
 * Complain if the operation has no side effects (and hence is meaningless).
 */
void Expression::discardValue()
{
    bool has = false;
    lambdaHasSideEffect(this, &has);
    if (!has)
    {
        switch (op)
        {
            case TOKcast:
            {   CastExp *ce = (CastExp *)this;
                if (ce->to->equals(Type::tvoid))
                {   /*
                     * Don't complain about an expression with no effect if it was cast to void
                     */
                    ce->e1->useValue();
                    break;
                }
                goto Ldefault;          // complain
            }

            case TOKerror:
                break;

            case TOKcall:
                /* Don't complain about calling functions with no effect,
                 * because purity and nothrow are inferred, and because some of the
                 * runtime library depends on it. Needs more investigation.
                 */
                break;

            case TOKimport:
                error("%s has no effect", toChars());
                break;

            case TOKandand:
            {   AndAndExp *aae = (AndAndExp *)this;
                aae->e1->useValue();
                aae->e2->discardValue();
                break;
            }

            case TOKoror:
            {   OrOrExp *ooe = (OrOrExp *)this;
                ooe->e1->useValue();
                ooe->e2->discardValue();
                break;
            }

            case TOKquestion:
            {   CondExp *ce = (CondExp *)this;
                ce->econd->useValue();
                ce->e1->discardValue();
                ce->e2->discardValue();
                break;
            }

            case TOKcomma:
            {   CommaExp *ce = (CommaExp *)this;

                /* Check for compiler-generated code of the form  auto __tmp, e, __tmp;
                 * In such cases, only check e for side effect (it's OK for __tmp to have
                 * no side effect).
                 * See Bugzilla 4231 for discussion
                 */
                CommaExp* firstComma = ce;
                while (firstComma->e1->op == TOKcomma)
                    firstComma = (CommaExp *)firstComma->e1;
                if (firstComma->e1->op == TOKdeclaration &&
                    ce->e2->op == TOKvar &&
                    ((DeclarationExp *)firstComma->e1)->declaration == ((VarExp*)ce->e2)->var)
                {
                    ce->e1->useValue();
                    break;
                }
                // Don't check e1 until we cast(void) the a,b code generation
                //ce->e1->discardValue();
                ce->e2->discardValue();
                break;
            }

            case TOKtuple:
                /* Pass without complaint if any of the tuple elements have side effects.
                 * Ideally any tuple elements with no side effects should raise an error,
                 * this needs more investigation as to what is the right thing to do.
                 */
                if (!hasSideEffect())
                    goto Ldefault;
                break;

            default:
            Ldefault:
                error("%s has no effect in expression (%s)",
                    Token::toChars(op), toChars());
                break;
        }
    }
    else
    {
        useValue();
    }
}

/* This isn't used yet because the only way an expression has an unused sub-expression
 * is with the CommaExp, and that currently generates messages from rewrites into comma
 * expressions. Needs more investigation.
 */
void Expression::useValue()
{
#if 0
    // Disabled because need to cast(void) the a,b code generation
    void *p;
    apply(&lambdaUseValue, &p);
#endif
}

#if 0
int lambdaUseValue(Expression *e, void *param)
{
    switch (e->op)
    {
        case TOKcomma:
        {   CommaExp *ce = (CommaExp *)e;
            discardValue(ce->E1);
            break;
        }

        default:
            break;
    }
    return 0;
}
#endif
