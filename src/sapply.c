
// Compiler implementation of the D programming language
// Copyright (c) 1999-2013 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <assert.h>

#include "mars.h"
#include "statement.h"


/**************************************
 * A Statement tree walker that will visit each Statement s in the tree,
 * in depth-first evaluation order, and call fp(s,param) on it.
 * fp() signals whether the walking continues with its return value:
 * Returns:
 *      0       continue
 *      1       done
 * It's a bit slower than using virtual functions, but more encapsulated and less brittle.
 * Creating an iterator for this would be much more complex.
 */

typedef bool (*sapply_fp_t)(Statement *, void *);

bool Statement::apply(sapply_fp_t fp, void *param)
{
    return (*fp)(this, param);
}

/******************************
 * Perform apply() on an t if not null
 */
#define scondApply(t, fp, param) (t ? t->apply(fp, param) : false)



bool PeelStatement::apply(sapply_fp_t fp, void *param)
{
    return s->apply(fp, param) ||
           (*fp)(this, param);
}

bool CompoundStatement::apply(sapply_fp_t fp, void *param)
{
    for (size_t i = 0; i < statements->dim; i++)
    {   Statement *s = (*statements)[i];

        bool r = scondApply(s, fp, param);
        if (r)
            return r;
    }
    return (*fp)(this, param);
}

bool UnrolledLoopStatement::apply(sapply_fp_t fp, void *param)
{
    for (size_t i = 0; i < statements->dim; i++)
    {   Statement *s = (*statements)[i];

        bool r = scondApply(s, fp, param);
        if (r)
            return r;
    }
    return (*fp)(this, param);
}

bool ScopeStatement::apply(sapply_fp_t fp, void *param)
{
    return scondApply(statement, fp, param) ||
           (*fp)(this, param);
}

bool WhileStatement::apply(sapply_fp_t fp, void *param)
{
    return scondApply(body, fp, param) ||
           (*fp)(this, param);
}

bool DoStatement::apply(sapply_fp_t fp, void *param)
{
    return scondApply(body, fp, param) ||
           (*fp)(this, param);
}

bool ForStatement::apply(sapply_fp_t fp, void *param)
{
    return scondApply(init, fp, param) ||
           scondApply(body, fp, param) ||
           (*fp)(this, param);
}

bool ForeachStatement::apply(sapply_fp_t fp, void *param)
{
    return scondApply(body, fp, param) ||
           (*fp)(this, param);
}

bool ForeachRangeStatement::apply(sapply_fp_t fp, void *param)
{
    return scondApply(body, fp, param) ||
           (*fp)(this, param);
}

bool IfStatement::apply(sapply_fp_t fp, void *param)
{
    return scondApply(ifbody, fp, param) ||
           scondApply(elsebody, fp, param) ||
           (*fp)(this, param);
}

bool ConditionalStatement::apply(sapply_fp_t fp, void *param)
{
    return scondApply(ifbody, fp, param) ||
           scondApply(elsebody, fp, param) ||
           (*fp)(this, param);
}

bool PragmaStatement::apply(sapply_fp_t fp, void *param)
{
    return scondApply(body, fp, param) ||
           (*fp)(this, param);
}

bool SwitchStatement::apply(sapply_fp_t fp, void *param)
{
    return scondApply(body, fp, param) ||
           (*fp)(this, param);
}

bool CaseStatement::apply(sapply_fp_t fp, void *param)
{
    return scondApply(statement, fp, param) ||
           (*fp)(this, param);
}

bool CaseRangeStatement::apply(sapply_fp_t fp, void *param)
{
    return scondApply(statement, fp, param) ||
           (*fp)(this, param);
}

bool DefaultStatement::apply(sapply_fp_t fp, void *param)
{
    return scondApply(statement, fp, param) ||
           (*fp)(this, param);
}

bool SynchronizedStatement::apply(sapply_fp_t fp, void *param)
{
    return scondApply(body, fp, param) ||
           (*fp)(this, param);
}

bool WithStatement::apply(sapply_fp_t fp, void *param)
{
    return scondApply(body, fp, param) ||
           (*fp)(this, param);
}

bool TryCatchStatement::apply(sapply_fp_t fp, void *param)
{
    bool r = scondApply(body, fp, param);
    if (r)
        return r;

    for (size_t i = 0; i < catches->dim; i++)
    {   Catch *c = (*catches)[i];

        r = scondApply(c->handler, fp, param);
        if (r)
            return r;
    }
    return (*fp)(this, param);
}

bool TryFinallyStatement::apply(sapply_fp_t fp, void *param)
{
    return scondApply(body, fp, param) ||
           scondApply(finalbody, fp, param) ||
           (*fp)(this, param);
}

bool OnScopeStatement::apply(sapply_fp_t fp, void *param)
{
    return scondApply(statement, fp, param) ||
           (*fp)(this, param);
}

bool DebugStatement::apply(sapply_fp_t fp, void *param)
{
    return scondApply(statement, fp, param) ||
           (*fp)(this, param);
}

bool LabelStatement::apply(sapply_fp_t fp, void *param)
{
    return scondApply(statement, fp, param) ||
           (*fp)(this, param);
}

