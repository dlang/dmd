// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.sapply;

import ddmd.statement;
import ddmd.visitor;

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
extern (C++) final class PostorderStatementVisitor : StoppableVisitor
{
    alias visit = super.visit;
public:
    StoppableVisitor v;

    extern (D) this(StoppableVisitor v)
    {
        this.v = v;
    }

    bool doCond(Statement s)
    {
        if (!stop && s)
            s.accept(this);
        return stop;
    }

    bool applyTo(Statement s)
    {
        s.accept(v);
        stop = v.stop;
        return true;
    }

    void visit(Statement s)
    {
        applyTo(s);
    }

    void visit(PeelStatement s)
    {
        doCond(s.s) || applyTo(s);
    }

    void visit(CompoundStatement s)
    {
        for (size_t i = 0; i < s.statements.dim; i++)
            if (doCond((*s.statements)[i]))
                return;
        applyTo(s);
    }

    void visit(UnrolledLoopStatement s)
    {
        for (size_t i = 0; i < s.statements.dim; i++)
            if (doCond((*s.statements)[i]))
                return;
        applyTo(s);
    }

    void visit(ScopeStatement s)
    {
        doCond(s.statement) || applyTo(s);
    }

    void visit(WhileStatement s)
    {
        doCond(s._body) || applyTo(s);
    }

    void visit(DoStatement s)
    {
        doCond(s._body) || applyTo(s);
    }

    void visit(ForStatement s)
    {
        doCond(s._init) || doCond(s._body) || applyTo(s);
    }

    void visit(ForeachStatement s)
    {
        doCond(s._body) || applyTo(s);
    }

    void visit(ForeachRangeStatement s)
    {
        doCond(s._body) || applyTo(s);
    }

    void visit(IfStatement s)
    {
        doCond(s.ifbody) || doCond(s.elsebody) || applyTo(s);
    }

    void visit(PragmaStatement s)
    {
        doCond(s._body) || applyTo(s);
    }

    void visit(SwitchStatement s)
    {
        doCond(s._body) || applyTo(s);
    }

    void visit(CaseStatement s)
    {
        doCond(s.statement) || applyTo(s);
    }

    void visit(DefaultStatement s)
    {
        doCond(s.statement) || applyTo(s);
    }

    void visit(SynchronizedStatement s)
    {
        doCond(s._body) || applyTo(s);
    }

    void visit(WithStatement s)
    {
        doCond(s._body) || applyTo(s);
    }

    void visit(TryCatchStatement s)
    {
        if (doCond(s._body))
            return;
        for (size_t i = 0; i < s.catches.dim; i++)
            if (doCond((*s.catches)[i].handler))
                return;
        applyTo(s);
    }

    void visit(TryFinallyStatement s)
    {
        doCond(s._body) || doCond(s.finalbody) || applyTo(s);
    }

    void visit(OnScopeStatement s)
    {
        doCond(s.statement) || applyTo(s);
    }

    void visit(DebugStatement s)
    {
        doCond(s.statement) || applyTo(s);
    }

    void visit(LabelStatement s)
    {
        doCond(s.statement) || applyTo(s);
    }
}

extern (C++) bool walkPostorder(Statement s, StoppableVisitor v)
{
    scope PostorderStatementVisitor pv = new PostorderStatementVisitor(v);
    s.accept(pv);
    return v.stop;
}
