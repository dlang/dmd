/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _statement_rewrite_walker.d)
 */

module ddmd.statement_rewrite_walker;

import core.stdc.stdio;

import ddmd.statement;
import ddmd.visitor;


/** A visitor to walk entire statements and provides ability to replace any sub-statements.
 */
extern (C++) class StatementRewriteWalker : Visitor
{
    alias visit = super.visit;

    /* Point the currently visited statement.
     * By using replaceCurrent() method, you can replace AST during walking.
     */
    Statement* ps;

public:
    final void visitStmt(ref Statement s)
    {
        ps = &s;
        s.accept(this);
    }

    final void replaceCurrent(Statement s)
    {
        *ps = s;
    }

    override void visit(ErrorStatement s)
    {
    }

    override void visit(PeelStatement s)
    {
        if (s.s)
            visitStmt(s.s);
    }

    override void visit(ExpStatement s)
    {
    }

    override void visit(DtorExpStatement s)
    {
    }

    override void visit(CompileStatement s)
    {
    }

    override void visit(CompoundStatement s)
    {
        if (s.statements && s.statements.dim)
        {
            for (size_t i = 0; i < s.statements.dim; i++)
            {
                if ((*s.statements)[i])
                    visitStmt((*s.statements)[i]);
            }
        }
    }

    override void visit(CompoundDeclarationStatement s)
    {
        visit(cast(CompoundStatement)s);
    }

    override void visit(UnrolledLoopStatement s)
    {
        if (s.statements && s.statements.dim)
        {
            for (size_t i = 0; i < s.statements.dim; i++)
            {
                if ((*s.statements)[i])
                    visitStmt((*s.statements)[i]);
            }
        }
    }

    override void visit(ScopeStatement s)
    {
        if (s.statement)
            visitStmt(s.statement);
    }

    override void visit(WhileStatement s)
    {
        if (s._body)
            visitStmt(s._body);
    }

    override void visit(DoStatement s)
    {
        if (s._body)
            visitStmt(s._body);
    }

    override void visit(ForStatement s)
    {
        if (s._init)
            visitStmt(s._init);
        if (s._body)
            visitStmt(s._body);
    }

    override void visit(ForeachStatement s)
    {
        if (s._body)
            visitStmt(s._body);
    }

    override void visit(ForeachRangeStatement s)
    {
        if (s._body)
            visitStmt(s._body);
    }

    override void visit(IfStatement s)
    {
        if (s.ifbody)
            visitStmt(s.ifbody);
        if (s.elsebody)
            visitStmt(s.elsebody);
    }

    override void visit(ConditionalStatement s)
    {
    }

    override void visit(PragmaStatement s)
    {
    }

    override void visit(StaticAssertStatement s)
    {
    }

    override void visit(SwitchStatement s)
    {
        if (s._body)
            visitStmt(s._body);
    }

    override void visit(CaseStatement s)
    {
        if (s.statement)
            visitStmt(s.statement);
    }

    override void visit(CaseRangeStatement s)
    {
        if (s.statement)
            visitStmt(s.statement);
    }

    override void visit(DefaultStatement s)
    {
        if (s.statement)
            visitStmt(s.statement);
    }

    override void visit(GotoDefaultStatement s)
    {
    }

    override void visit(GotoCaseStatement s)
    {
    }

    override void visit(SwitchErrorStatement s)
    {
    }

    override void visit(ReturnStatement s)
    {
    }

    override void visit(BreakStatement s)
    {
    }

    override void visit(ContinueStatement s)
    {
    }

    override void visit(SynchronizedStatement s)
    {
        if (s._body)
            visitStmt(s._body);
    }

    override void visit(WithStatement s)
    {
        if (s._body)
            visitStmt(s._body);
    }

    override void visit(TryCatchStatement s)
    {
        if (s._body)
            visitStmt(s._body);
        if (s.catches && s.catches.dim)
        {
            for (size_t i = 0; i < s.catches.dim; i++)
            {
                Catch c = (*s.catches)[i];
                if (c && c.handler)
                    visitStmt(c.handler);
            }
        }
    }

    override void visit(TryFinallyStatement s)
    {
        if (s._body)
            visitStmt(s._body);
        if (s.finalbody)
            visitStmt(s.finalbody);
    }

    override void visit(OnScopeStatement s)
    {
    }

    override void visit(ThrowStatement s)
    {
    }

    override void visit(DebugStatement s)
    {
        if (s.statement)
            visitStmt(s.statement);
    }

    override void visit(GotoStatement s)
    {
    }

    override void visit(LabelStatement s)
    {
        if (s.statement)
            visitStmt(s.statement);
    }

    override void visit(AsmStatement s)
    {
    }

    override void visit(ImportStatement s)
    {
    }
}
