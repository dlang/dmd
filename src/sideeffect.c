
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

int lambdaHasSideEffect(Expression *e, void *param);

/********************************************
 * Determine if Expression has any side effects.
 */

bool Expression::hasSideEffect()
{
    bool has = FALSE;
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
            *phas = TRUE;
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
                    *phas = TRUE;
            }
            break;
        }

        case TOKcast:
        {   CastExp *ce = (CastExp *)e;

            /* if:
             *  cast(classtype)func()  // because it may throw
             */
            if (ce->to->ty == Tclass && ce->e1->op == TOKcall && ce->e1->type->ty == Tclass)
                *phas = TRUE;
            break;
        }

        default:
            break;
    }
    return *phas; // stop walking if we determine this expression has side effects
}
