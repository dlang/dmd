
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
#include "visitor.h"


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

class PostorderExpressionVisitor : public StoppableVisitor
{
public:
    StoppableVisitor *v;
    PostorderExpressionVisitor(StoppableVisitor *v) : v(v) {}

    bool doCond(Expression *e)
    {
        if (!stop && e)
            e->accept(this);
        return stop;
    }
    bool doCond(Expressions *e)
    {
        if (!e)
            return false;
        for (size_t i = 0; i < e->dim && !stop; i++)
            doCond((*e)[i]);
        return stop;
    }
    bool applyTo(Expression *e)
    {
        e->accept(v);
        stop = v->stop;
        return true;
    }

    void visit(Expression *e)
    {
        applyTo(e);
    }

    void visit(NewExp *e)
    {
        //printf("NewExp::apply(): %s\n", toChars());
#if DMD_OBJC
        doCond(e->thisexp) | doCond(e->newargs) | doCond(e->arguments) | applyTo(e);
#else
        doCond(e->thisexp) || doCond(e->newargs) || doCond(e->arguments) || applyTo(e);
#endif
    }

    void visit(NewAnonClassExp *e)
    {
        //printf("NewAnonClassExp::apply(): %s\n", toChars());

#if DMD_OBJC
        doCond(e->thisexp) | doCond(e->newargs) | doCond(e->arguments) | applyTo(e);
#else
        doCond(e->thisexp) || doCond(e->newargs) || doCond(e->arguments) || applyTo(e);
#endif
    }

    void visit(UnaExp *e)
    {
        doCond(e->e1) || applyTo(e);
    }

    void visit(BinExp *e)
    {
#if DMD_OBJC
        doCond(e->e1) | doCond(e->e2) | applyTo(e);
#else
        doCond(e->e1) || doCond(e->e2) || applyTo(e);
#endif
    }

    void visit(AssertExp *e)
    {
        //printf("CallExp::apply(apply_fp_t fp, void *param): %s\n", toChars());
#if DMD_OBJC
        doCond(e->e1) | doCond(e->msg) | applyTo(e);
#else
        doCond(e->e1) || doCond(e->msg) || applyTo(e);
#endif
    }

    void visit(CallExp *e)
    {
        //printf("CallExp::apply(apply_fp_t fp, void *param): %s\n", toChars());
        doCond(e->e1) || doCond(e->arguments) || applyTo(e);
    }

    void visit(ArrayExp *e)
    {
        //printf("ArrayExp::apply(apply_fp_t fp, void *param): %s\n", toChars());
        doCond(e->e1) || doCond(e->arguments) || applyTo(e);
    }

    void visit(SliceExp *e)
    {
#if DMD_OBJC
        doCond(e->e1) | doCond(e->lwr) | doCond(e->upr) | applyTo(e);
#else
        doCond(e->e1) || doCond(e->lwr) || doCond(e->upr) || applyTo(e);
#endif
    }

    void visit(ArrayLiteralExp *e)
    {
        doCond(e->elements) || applyTo(e);
    }

    void visit(AssocArrayLiteralExp *e)
    {
#if DMD_OBJC
        doCond(e->keys) | doCond(e->values) | applyTo(e);
#else
        doCond(e->keys) || doCond(e->values) || applyTo(e);
#endif
    }

    void visit(StructLiteralExp *e)
    {
        if (e->stageflags & stageApply) return;
        int old = e->stageflags;
        e->stageflags |= stageApply;
        doCond(e->elements) || applyTo(e);
        e->stageflags = old;
    }

    void visit(TupleExp *e)
    {
        doCond(e->e0) || doCond(e->exps) || applyTo(e);
    }

    void visit(CondExp *e)
    {
#if DMD_OBCJ
        doCond(e->econd) | doCond(e->e1) | doCond(e->e2) | applyTo(e);
#else
        doCond(e->econd) || doCond(e->e1) || doCond(e->e2) || applyTo(e);
#endif
    }
};

bool walkPostorder(Expression *e, StoppableVisitor *v)
{
    PostorderExpressionVisitor pv(v);
    e->accept(&pv);
    return v->stop;
}

