/**
 * Provides a depth-first statement visitor.
 *
 * Copyright:   Copyright (C) 1999-2022 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/sparse.d, _sparse.d)
 * Documentation:  https://dlang.org/phobos/dmd_sapply.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/sapply.d
 */

module dmd.sapply;

import dmd.statement;
import dmd.visitor;

bool walkPostorder(Statement s, StoppableVisitor v)
{
    scope PostorderStatementVisitor pv = new PostorderStatementVisitor(v);
    s.accept(pv);
    return v.stop;
}

bool walkPreorder(Statement s, StoppableVisitor v)
{
    scope PreorderStatementVisitor pv = new PreorderStatementVisitor(v);
    s.accept(pv);
    return v.stop;
}

/**************************************
 * A Statement tree walker that will visit each Statement s in the tree,
 * in depth-first evaluation order using post-order traversal, and call
 * fp(s,param) on it. fp() signals whether the walking continues with its
 * return value:
 * Returns:
 *      0       continue
 *      1       done
 * It's a bit slower than using virtual functions, but more encapsulated and less brittle.
 * Creating an iterator for this would be much more complex.
 */
private extern (C++) final class PostorderStatementVisitor : StoppableVisitor
{
    alias visit = typeof(super).visit;
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

    override void visit(Statement s)
    {
        applyTo(s);
    }

    override void visit(PeelStatement s)
    {
        doCond(s.s) || applyTo(s);
    }

    override void visit(CompoundStatement s)
    {
        for (size_t i = 0; i < s.statements.length; i++)
            if (doCond((*s.statements)[i]))
                return;
        applyTo(s);
    }

    override void visit(UnrolledLoopStatement s)
    {
        for (size_t i = 0; i < s.statements.length; i++)
            if (doCond((*s.statements)[i]))
                return;
        applyTo(s);
    }

    override void visit(ScopeStatement s)
    {
        doCond(s.statement) || applyTo(s);
    }

    override void visit(WhileStatement s)
    {
        doCond(s._body) || applyTo(s);
    }

    override void visit(DoStatement s)
    {
        doCond(s._body) || applyTo(s);
    }

    override void visit(ForStatement s)
    {
        doCond(s._init) || doCond(s._body) || applyTo(s);
    }

    override void visit(ForeachStatement s)
    {
        doCond(s._body) || applyTo(s);
    }

    override void visit(ForeachRangeStatement s)
    {
        doCond(s._body) || applyTo(s);
    }

    override void visit(IfStatement s)
    {
        doCond(s.ifbody) || doCond(s.elsebody) || applyTo(s);
    }

    override void visit(PragmaStatement s)
    {
        doCond(s._body) || applyTo(s);
    }

    override void visit(SwitchStatement s)
    {
        doCond(s._body) || applyTo(s);
    }

    override void visit(CaseStatement s)
    {
        doCond(s.statement) || applyTo(s);
    }

    override void visit(DefaultStatement s)
    {
        doCond(s.statement) || applyTo(s);
    }

    override void visit(SynchronizedStatement s)
    {
        doCond(s._body) || applyTo(s);
    }

    override void visit(WithStatement s)
    {
        doCond(s._body) || applyTo(s);
    }

    override void visit(TryCatchStatement s)
    {
        if (doCond(s._body))
            return;
        for (size_t i = 0; i < s.catches.length; i++)
            if (doCond((*s.catches)[i].handler))
                return;
        applyTo(s);
    }

    override void visit(TryFinallyStatement s)
    {
        doCond(s._body) || doCond(s.finalbody) || applyTo(s);
    }

    override void visit(ScopeGuardStatement s)
    {
        doCond(s.statement) || applyTo(s);
    }

    override void visit(DebugStatement s)
    {
        doCond(s.statement) || applyTo(s);
    }

    override void visit(LabelStatement s)
    {
        doCond(s.statement) || applyTo(s);
    }
}

/**************************************
 * A Statement tree walker that will visit each Statement s in the tree,
 * in depth-first evaluation order using pre-order traversal, and call
 * fp(s,param) on it. fp() signals whether the walking continues with its
 * return value:
 * Returns:
 *      0       continue
 *      1       done
 * It's a bit slower than using virtual functions, but more encapsulated and less brittle.
 * Creating an iterator for this would be much more complex.
 */
private extern (C++) final class PreorderStatementVisitor : StoppableVisitor
{
    alias visit = typeof(super).visit;
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
        return stop;
    }

    override void visit(Statement s)
    {
        applyTo(s);
    }

    override void visit(PeelStatement s)
    {
        applyTo(s) || doCond(s.s);
    }

    override void visit(CompoundStatement s)
    {
        if (applyTo(s))
            return;
        for (size_t i = 0; i < s.statements.length; i++)
            if (doCond((*s.statements)[i]))
                return;
    }

    override void visit(UnrolledLoopStatement s)
    {
        if (applyTo(s))
            return;
        for (size_t i = 0; i < s.statements.length; i++)
            if (doCond((*s.statements)[i]))
                return;
    }

    override void visit(ScopeStatement s)
    {
        applyTo(s) || doCond(s.statement);
    }

    override void visit(WhileStatement s)
    {
        applyTo(s) || doCond(s._body);
    }

    override void visit(DoStatement s)
    {
        applyTo(s) || doCond(s._body);
    }

    override void visit(ForStatement s)
    {
        applyTo(s) || doCond(s._init) || doCond(s._body);
    }

    override void visit(ForeachStatement s)
    {
        applyTo(s) || doCond(s._body);
    }

    override void visit(ForeachRangeStatement s)
    {
        applyTo(s) || doCond(s._body);
    }

    override void visit(IfStatement s)
    {
        applyTo(s) || doCond(s.ifbody) || doCond(s.elsebody);
    }

    override void visit(PragmaStatement s)
    {
        applyTo(s) || doCond(s._body);
    }

    override void visit(SwitchStatement s)
    {
        applyTo(s) || doCond(s._body);
    }

    override void visit(CaseStatement s)
    {
        applyTo(s) || doCond(s.statement);
    }

    override void visit(DefaultStatement s)
    {
        applyTo(s) || doCond(s.statement);
    }

    override void visit(SynchronizedStatement s)
    {
        applyTo(s) || doCond(s._body);
    }

    override void visit(WithStatement s)
    {
        applyTo(s) || doCond(s._body);
    }

    override void visit(TryCatchStatement s)
    {
        if (applyTo(s))
            return;
        if (doCond(s._body))
            return;
        for (size_t i = 0; i < s.catches.length; i++)
            if (doCond((*s.catches)[i].handler))
                return;
    }

    override void visit(TryFinallyStatement s)
    {
        applyTo(s) || doCond(s._body) || doCond(s.finalbody);
    }

    override void visit(ScopeGuardStatement s)
    {
        applyTo(s) || doCond(s.statement);
    }

    override void visit(DebugStatement s)
    {
        applyTo(s) || doCond(s.statement);
    }

    override void visit(LabelStatement s)
    {
        applyTo(s) || doCond(s.statement);
    }
}
