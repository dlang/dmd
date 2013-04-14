
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
#include "expression.h"


/**************************************
 * An Expression tree walker that will visit each Expression e in the tree,
 * in depth-first evaluation order, and call fp(e,param) on it.
 * fp() signals whether the walking continues with its return value:
 * Returns:
 *      0       continue
 *      1       done
 * It's a bit slower than using virtual functions, but more encapsulated and less brittle.
 * Creating an iterator for this would be much more complex.
 */

typedef int (*fp_t)(Expression *, void *);

int Expression::apply(fp_t fp, void *param)
{
    return (*fp)(this, param);
}

/******************************
 * Perform apply() on an t if not null
 */
template<typename T>
int condApply(T* t, fp_t fp, void* param)
{
    return t ? t->apply(fp, param) : 0;
}


int NewExp::apply(int (*fp)(Expression *, void *), void *param)
{
    //printf("NewExp::apply(): %s\n", toChars());

    return condApply(thisexp, fp, param) ||
           condApply(newargs, fp, param) ||
           condApply(arguments, fp, param) ||
           (*fp)(this, param);
}

int NewAnonClassExp::apply(int (*fp)(Expression *, void *), void *param)
{
    //printf("NewAnonClassExp::apply(): %s\n", toChars());

    return condApply(thisexp, fp, param) ||
           condApply(newargs, fp, param) ||
           condApply(arguments, fp, param) ||
           (*fp)(this, param);
}

int UnaExp::apply(fp_t fp, void *param)
{
    return e1->apply(fp, param) ||
           (*fp)(this, param);
}

int BinExp::apply(fp_t fp, void *param)
{
    return e1->apply(fp, param) ||
           e2->apply(fp, param) ||
           (*fp)(this, param);
}

int AssertExp::apply(fp_t fp, void *param)
{
    //printf("CallExp::apply(fp_t fp, void *param): %s\n", toChars());
    return e1->apply(fp, param) ||
           condApply(msg, fp, param) ||
           (*fp)(this, param);
}


int CallExp::apply(fp_t fp, void *param)
{
    //printf("CallExp::apply(fp_t fp, void *param): %s\n", toChars());
    return e1->apply(fp, param) ||
           condApply(arguments, fp, param) ||
           (*fp)(this, param);
}


int ArrayExp::apply(fp_t fp, void *param)
{
    //printf("ArrayExp::apply(fp_t fp, void *param): %s\n", toChars());
    return e1->apply(fp, param) ||
           condApply(arguments, fp, param) ||
           (*fp)(this, param);
}


int SliceExp::apply(fp_t fp, void *param)
{
    return e1->apply(fp, param) ||
           condApply(lwr, fp, param) ||
           condApply(upr, fp, param) ||
           (*fp)(this, param);
}


int ArrayLiteralExp::apply(fp_t fp, void *param)
{
    return condApply(elements, fp, param) ||
           (*fp)(this, param);
}


int AssocArrayLiteralExp::apply(fp_t fp, void *param)
{
    return condApply(keys, fp, param) ||
           condApply(values, fp, param) ||
           (*fp)(this, param);
}


int StructLiteralExp::apply(fp_t fp, void *param)
{
    if(stageflags & stageApply) return 0;
    int old = stageflags;
    stageflags |= stageApply;
    int ret = condApply(elements, fp, param) ||
           (*fp)(this, param);
    stageflags = old;      
    return ret;
}


int TupleExp::apply(fp_t fp, void *param)
{
    return (e0 ? (*fp)(e0, param) : 0) ||
           condApply(exps, fp, param) ||
           (*fp)(this, param);
}


int CondExp::apply(fp_t fp, void *param)
{
    return econd->apply(fp, param) ||
           e1->apply(fp, param) ||
           e2->apply(fp, param) ||
           (*fp)(this, param);
}



