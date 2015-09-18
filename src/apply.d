// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.apply;

import ddmd.arraytypes;
import ddmd.expression;
import ddmd.visitor;

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
extern (C++) final class PostorderExpressionVisitor : StoppableVisitor
{
    alias visit = super.visit;
public:
    StoppableVisitor v;

    extern (D) this(StoppableVisitor v)
    {
        this.v = v;
    }

    bool doCond(Expression e)
    {
        if (!stop && e)
            e.accept(this);
        return stop;
    }

    bool doCond(Expressions* e)
    {
        if (!e)
            return false;
        for (size_t i = 0; i < e.dim && !stop; i++)
            doCond((*e)[i]);
        return stop;
    }

    bool applyTo(Expression e)
    {
        e.accept(v);
        stop = v.stop;
        return true;
    }

    override void visit(Expression e)
    {
        applyTo(e);
    }

    override void visit(NewExp e)
    {
        //printf("NewExp::apply(): %s\n", toChars());
        doCond(e.thisexp) || doCond(e.newargs) || doCond(e.arguments) || applyTo(e);
    }

    override void visit(NewAnonClassExp e)
    {
        //printf("NewAnonClassExp::apply(): %s\n", toChars());
        doCond(e.thisexp) || doCond(e.newargs) || doCond(e.arguments) || applyTo(e);
    }

    override void visit(UnaExp e)
    {
        doCond(e.e1) || applyTo(e);
    }

    override void visit(BinExp e)
    {
        doCond(e.e1) || doCond(e.e2) || applyTo(e);
    }

    override void visit(AssertExp e)
    {
        //printf("CallExp::apply(apply_fp_t fp, void *param): %s\n", toChars());
        doCond(e.e1) || doCond(e.msg) || applyTo(e);
    }

    override void visit(CallExp e)
    {
        //printf("CallExp::apply(apply_fp_t fp, void *param): %s\n", toChars());
        doCond(e.e1) || doCond(e.arguments) || applyTo(e);
    }

    override void visit(ArrayExp e)
    {
        //printf("ArrayExp::apply(apply_fp_t fp, void *param): %s\n", toChars());
        doCond(e.e1) || doCond(e.arguments) || applyTo(e);
    }

    override void visit(SliceExp e)
    {
        doCond(e.e1) || doCond(e.lwr) || doCond(e.upr) || applyTo(e);
    }

    override void visit(ArrayLiteralExp e)
    {
        doCond(e.elements) || applyTo(e);
    }

    override void visit(AssocArrayLiteralExp e)
    {
        doCond(e.keys) || doCond(e.values) || applyTo(e);
    }

    override void visit(StructLiteralExp e)
    {
        if (e.stageflags & stageApply)
            return;
        int old = e.stageflags;
        e.stageflags |= stageApply;
        doCond(e.elements) || applyTo(e);
        e.stageflags = old;
    }

    override void visit(TupleExp e)
    {
        doCond(e.e0) || doCond(e.exps) || applyTo(e);
    }

    override void visit(CondExp e)
    {
        doCond(e.econd) || doCond(e.e1) || doCond(e.e2) || applyTo(e);
    }
}

extern (C++) bool walkPostorder(Expression e, StoppableVisitor v)
{
    scope PostorderExpressionVisitor pv = new PostorderExpressionVisitor(v);
    e.accept(pv);
    return v.stop;
}
