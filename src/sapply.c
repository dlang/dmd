
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

typedef bool (*fp_t)(Statement *, void *);

bool Statement::apply(fp_t fp, void *param)
{
    return (*fp)(this, param);
}

/******************************
 * Perform apply() on an t if not null
 */
template<typename T>
bool condApply(T* t, fp_t fp, void* param)
{
    return t ? t->apply(fp, param) : 0;
}



bool PeelStatement::apply(fp_t fp, void *param)
{
    return s->apply(fp, param) ||
           (*fp)(this, param);
}

bool CompoundStatement::apply(fp_t fp, void *param)
{
    for (size_t i = 0; i < statements->dim; i++)
    {   Statement *s = (*statements)[i];

        bool r = condApply(s, fp, param);
        if (r)
            return r;
    }
    return (*fp)(this, param);
}

bool UnrolledLoopStatement::apply(fp_t fp, void *param)
{
    for (size_t i = 0; i < statements->dim; i++)
    {   Statement *s = (*statements)[i];

        bool r = condApply(s, fp, param);
        if (r)
            return r;
    }
    return (*fp)(this, param);
}

bool ScopeStatement::apply(fp_t fp, void *param)
{
    return condApply(statement, fp, param) ||
           (*fp)(this, param);
}

bool WhileStatement::apply(fp_t fp, void *param)
{
    return condApply(body, fp, param) ||
           (*fp)(this, param);
}

bool DoStatement::apply(fp_t fp, void *param)
{
    return condApply(body, fp, param) ||
           (*fp)(this, param);
}

bool ForStatement::apply(fp_t fp, void *param)
{
    return condApply(init, fp, param) ||
           condApply(body, fp, param) ||
           (*fp)(this, param);
}

bool ForeachStatement::apply(fp_t fp, void *param)
{
    return condApply(body, fp, param) ||
           (*fp)(this, param);
}

#if DMDV2
bool ForeachRangeStatement::apply(fp_t fp, void *param)
{
    return condApply(body, fp, param) ||
           (*fp)(this, param);
}
#endif

bool IfStatement::apply(fp_t fp, void *param)
{
    return condApply(ifbody, fp, param) ||
           condApply(elsebody, fp, param) ||
           (*fp)(this, param);
}

bool ConditionalStatement::apply(fp_t fp, void *param)
{
    return condApply(ifbody, fp, param) ||
           condApply(elsebody, fp, param) ||
           (*fp)(this, param);
}

bool PragmaStatement::apply(fp_t fp, void *param)
{
    return condApply(body, fp, param) ||
           (*fp)(this, param);
}

bool SwitchStatement::apply(fp_t fp, void *param)
{
    return condApply(body, fp, param) ||
           (*fp)(this, param);
}

bool CaseStatement::apply(fp_t fp, void *param)
{
    return condApply(statement, fp, param) ||
           (*fp)(this, param);
}

#if DMDV2
bool CaseRangeStatement::apply(fp_t fp, void *param)
{
    return condApply(statement, fp, param) ||
           (*fp)(this, param);
}
#endif

bool DefaultStatement::apply(fp_t fp, void *param)
{
    return condApply(statement, fp, param) ||
           (*fp)(this, param);
}

bool SynchronizedStatement::apply(fp_t fp, void *param)
{
    return condApply(body, fp, param) ||
           (*fp)(this, param);
}

bool WithStatement::apply(fp_t fp, void *param)
{
    return condApply(body, fp, param) ||
           (*fp)(this, param);
}

bool TryCatchStatement::apply(fp_t fp, void *param)
{
    bool r = condApply(body, fp, param);
    if (r)
        return r;

    for (size_t i = 0; i < catches->dim; i++)
    {   Catch *c = (*catches)[i];

        bool r = condApply(c->handler, fp, param);
        if (r)
            return r;
    }
    return (*fp)(this, param);
}

bool TryFinallyStatement::apply(fp_t fp, void *param)
{
    return condApply(body, fp, param) ||
           condApply(finalbody, fp, param) ||
           (*fp)(this, param);
}

bool OnScopeStatement::apply(fp_t fp, void *param)
{
    return condApply(statement, fp, param) ||
           (*fp)(this, param);
}

bool VolatileStatement::apply(fp_t fp, void *param)
{
    return condApply(statement, fp, param) ||
           (*fp)(this, param);
}

#if DMDV2
bool DebugStatement::apply(fp_t fp, void *param)
{
    return condApply(statement, fp, param) ||
           (*fp)(this, param);
}
#endif

bool LabelStatement::apply(fp_t fp, void *param)
{
    return condApply(statement, fp, param) ||
           (*fp)(this, param);
}

