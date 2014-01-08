
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

int Expression::apply(apply_fp_t fp, void *param)
{
    return (*fp)(this, param);
}

/******************************
 * Perform apply() on an t if not null
 */
#define condApply(t, fp, param) (t ? t->apply(fp, param) : 0)

int NewExp::apply(apply_fp_t fp, void *param)
{
    //printf("NewExp::apply(): %s\n", toChars());
#if DMD_OBJC
    return condApply(thisexp, fp, param) |
           condApply(newargs, fp, param) |
           condApply(arguments, fp, param) |
           (*fp)(this, param);
#else
       return condApply(thisexp, fp, param) ||
              condApply(newargs, fp, param) ||
              condApply(arguments, fp, param) ||
              (*fp)(this, param);

#endif
}

int NewAnonClassExp::apply(apply_fp_t fp, void *param)
{
    //printf("NewAnonClassExp::apply(): %s\n", toChars());
#if DMD_OBJC
    return condApply(thisexp, fp, param) |
           condApply(newargs, fp, param) |
           condApply(arguments, fp, param) |
           (*fp)(this, param);
#else
       return condApply(thisexp, fp, param) ||
              condApply(newargs, fp, param) ||
              condApply(arguments, fp, param) ||
              (*fp)(this, param);

#endif
}

int UnaExp::apply(apply_fp_t fp, void *param)
{
    return e1->apply(fp, param) ||
           (*fp)(this, param);
}

int BinExp::apply(apply_fp_t fp, void *param)
{
#if DMD_OBJC
    return e1->apply(fp, param) |
           e2->apply(fp, param) |
           (*fp)(this, param);
#else
       return e1->apply(fp, param) ||
              e2->apply(fp, param) ||
              (*fp)(this, param);

#endif
}

int AssertExp::apply(apply_fp_t fp, void *param)
{
    //printf("CallExp::apply(apply_fp_t fp, void *param): %s\n", toChars());
    return e1->apply(fp, param) ||
           condApply(msg, fp, param) ||
           (*fp)(this, param);
}


int CallExp::apply(apply_fp_t fp, void *param)
{
    //printf("CallExp::apply(apply_fp_t fp, void *param): %s\n", toChars());
    return e1->apply(fp, param) ||
           condApply(arguments, fp, param) ||
           (*fp)(this, param);
}


int ArrayExp::apply(apply_fp_t fp, void *param)
{
    //printf("ArrayExp::apply(apply_fp_t fp, void *param): %s\n", toChars());
    return e1->apply(fp, param) ||
           condApply(arguments, fp, param) ||
           (*fp)(this, param);
}


int SliceExp::apply(apply_fp_t fp, void *param)
{
#if DMD_OBJC
    return e1->apply(fp, param) |
           condApply(lwr, fp, param) |
           condApply(upr, fp, param) |
           (*fp)(this, param);
#else
       return e1->apply(fp, param) ||
              condApply(lwr, fp, param) ||
              condApply(upr, fp, param) ||
              (*fp)(this, param);

#endif
}


int ArrayLiteralExp::apply(apply_fp_t fp, void *param)
{
    return condApply(elements, fp, param) ||
           (*fp)(this, param);
}


int AssocArrayLiteralExp::apply(apply_fp_t fp, void *param)
{
#if DMD_OBJC
    return condApply(keys, fp, param) |
           condApply(values, fp, param) |
           (*fp)(this, param);
#else
       return condApply(keys, fp, param) ||
              condApply(values, fp, param) ||
              (*fp)(this, param);

#endif
}


int StructLiteralExp::apply(apply_fp_t fp, void *param)
{
    if(stageflags & stageApply) return 0;
    int old = stageflags;
    stageflags |= stageApply;
    int ret = condApply(elements, fp, param) ||
           (*fp)(this, param);
    stageflags = old;
    return ret;
}


int TupleExp::apply(apply_fp_t fp, void *param)
{
    return (e0 ? (*fp)(e0, param) : 0) ||
           condApply(exps, fp, param) ||
           (*fp)(this, param);
}


int CondExp::apply(apply_fp_t fp, void *param)
{
#if DMD_OBJC
    return econd->apply(fp, param) |
           e1->apply(fp, param) |
           e2->apply(fp, param) |
           (*fp)(this, param);
#else
       return econd->apply(fp, param) ||
              e1->apply(fp, param) ||
              e2->apply(fp, param) ||
              (*fp)(this, param);
#endif
}



