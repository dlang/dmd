/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _statement.d)
 */

module ddmd.statement;

import core.stdc.stdarg;
import core.stdc.stdio;

import ddmd.aggregate;
import ddmd.arraytypes;
import ddmd.attrib;
import ddmd.gluelayer;
import ddmd.canthrow;
import ddmd.cond;
import ddmd.dclass;
import ddmd.declaration;
import ddmd.denum;
import ddmd.dimport;
import ddmd.dscope;
import ddmd.dsymbol;
import ddmd.dtemplate;
import ddmd.errors;
import ddmd.expression;
import ddmd.func;
import ddmd.globals;
import ddmd.hdrgen;
import ddmd.id;
import ddmd.identifier;
import ddmd.mtype;
import ddmd.parse;
import ddmd.root.outbuffer;
import ddmd.root.rootobject;
import ddmd.sapply;
import ddmd.sideeffect;
import ddmd.staticassert;
import ddmd.tokens;
import ddmd.visitor;

extern (C++) Identifier fixupLabelName(Scope* sc, Identifier ident)
{
    uint flags = (sc.flags & SCOPEcontract);
    const id = ident.toChars();
    if (flags && flags != SCOPEinvariant && !(id[0] == '_' && id[1] == '_'))
    {
        /* CTFE requires FuncDeclaration::labtab for the interpretation.
         * So fixing the label name inside in/out contracts is necessary
         * for the uniqueness in labtab.
         */
        const(char)* prefix = flags == SCOPErequire ? "__in_" : "__out_";
        OutBuffer buf;
        buf.printf("%s%s", prefix, ident.toChars());

        ident = Identifier.idPool(buf.peekSlice());
    }
    return ident;
}

extern (C++) LabelStatement checkLabeledLoop(Scope* sc, Statement statement)
{
    if (sc.slabel && sc.slabel.statement == statement)
    {
        return sc.slabel;
    }
    return null;
}

/***********************************************************
 * Check an assignment is used as a condition.
 * Intended to be use before the `semantic` call on `e`.
 * Params:
 *  e = condition expression which is not yet run semantic analysis.
 * Returns:
 *  `e` or ErrorExp.
 */
Expression checkAssignmentAsCondition(Expression e)
{
    auto ec = e;
    while (ec.op == TOKcomma)
        ec = (cast(CommaExp)ec).e2;
    if (ec.op == TOKassign)
    {
        ec.error("assignment cannot be used as a condition, perhaps == was meant?");
        return new ErrorExp();
    }
    return e;
}

/// Return a type identifier reference to 'object.Throwable'
TypeIdentifier getThrowable()
{
    auto tid = new TypeIdentifier(Loc(), Id.empty);
    tid.addIdent(Id.object);
    tid.addIdent(Id.Throwable);
    return tid;
}
/**
 * BE stands for BlockExit.
 *
 * It indicates If a statement does transfer controlflow to another Block.
 * A Block is a sequence of statements enclosed in {  }
 */
enum BE : int
{
    BEnone = 0,
    BEfallthru = 1,
    BEthrow = 2,
    BEreturn = 4,
    BEgoto = 8,
    BEhalt = 0x10,
    BEbreak = 0x20,
    BEcontinue = 0x40,
    BEerrthrow = 0x80,
    BEany = (BEfallthru | BEthrow | BEreturn | BEgoto | BEhalt),
}

alias BEnone = BE.BEnone;
alias BEfallthru = BE.BEfallthru;
alias BEthrow = BE.BEthrow;
alias BEreturn = BE.BEreturn;
alias BEgoto = BE.BEgoto;
alias BEhalt = BE.BEhalt;
alias BEbreak = BE.BEbreak;
alias BEcontinue = BE.BEcontinue;
alias BEerrthrow = BE.BEerrthrow;
alias BEany = BE.BEany;

/***********************************************************
 */
extern (C++) abstract class Statement : RootObject
{
    Loc loc;

    final extern (D) this(Loc loc)
    {
        this.loc = loc;
        // If this is an in{} contract scope statement (skip for determining
        //  inlineStatus of a function body for header content)
    }

    Statement syntaxCopy()
    {
        assert(0);
    }

    override final void print()
    {
        fprintf(stderr, "%s\n", toChars());
        fflush(stderr);
    }

    override final const(char)* toChars()
    {
        HdrGenState hgs;
        OutBuffer buf;
        .toCBuffer(this, &buf, &hgs);
        return buf.extractString();
    }

    final void error(const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        .verror(loc, format, ap);
        va_end(ap);
    }

    final void warning(const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        .vwarning(loc, format, ap);
        va_end(ap);
    }

    final void deprecation(const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        .vdeprecation(loc, format, ap);
        va_end(ap);
    }

    Statement getRelatedLabeled()
    {
        return this;
    }

    bool hasBreak()
    {
        //printf("Statement::hasBreak()\n");
        return false;
    }

    bool hasContinue()
    {
        return false;
    }

    /* ============================================== */
    // true if statement uses exception handling
    final bool usesEH()
    {
        extern (C++) final class UsesEH : StoppableVisitor
        {
            alias visit = super.visit;
        public:
            override void visit(Statement s)
            {
            }

            override void visit(TryCatchStatement s)
            {
                stop = true;
            }

            override void visit(TryFinallyStatement s)
            {
                stop = true;
            }

            override void visit(OnScopeStatement s)
            {
                stop = true;
            }

            override void visit(SynchronizedStatement s)
            {
                stop = true;
            }
        }

        scope UsesEH ueh = new UsesEH();
        return walkPostorder(this, ueh);
    }

    /* ============================================== */
    /** Only valid after semantic analysis
     * If 'mustNotThrow' is true, generate an error if it throws
     */
    final int blockExit(FuncDeclaration func, bool mustNotThrow)
    {
        extern (C++) final class BlockExit : Visitor
        {
            alias visit = super.visit;
        public:
            FuncDeclaration func;
            bool mustNotThrow;
            int result;

            extern (D) this(FuncDeclaration func, bool mustNotThrow)
            {
                this.func = func;
                this.mustNotThrow = mustNotThrow;
                result = BEnone;
            }

            override void visit(Statement s)
            {
                printf("Statement::blockExit(%p)\n", s);
                printf("%s\n", s.toChars());
                assert(0);
            }

            override void visit(ErrorStatement s)
            {
                result = BEany;
            }

            override void visit(ExpStatement s)
            {
                result = BEfallthru;
                if (s.exp)
                {
                    if (s.exp.op == TOKhalt)
                    {
                        result = BEhalt;
                        return;
                    }
                    if (s.exp.op == TOKassert)
                    {
                        AssertExp a = cast(AssertExp)s.exp;
                        if (a.e1.isBool(false)) // if it's an assert(0)
                        {
                            result = BEhalt;
                            return;
                        }
                    }
                    if (canThrow(s.exp, func, mustNotThrow))
                        result |= BEthrow;
                }
            }

            override void visit(CompileStatement s)
            {
                assert(global.errors);
                result = BEfallthru;
            }

            override void visit(CompoundStatement cs)
            {
                //printf("CompoundStatement.blockExit(%p) %d result = x%X\n", cs, cs.statements.dim, result);
                result = BEfallthru;
                Statement slast = null;
                foreach (s; *cs.statements)
                {
                    if (s)
                    {
                        //printf("result = x%x\n", result);
                        //printf("s: %s\n", s.toChars());
                        if (result & BEfallthru && slast)
                        {
                            slast = slast.last();
                            if (slast && (slast.isCaseStatement() || slast.isDefaultStatement()) && (s.isCaseStatement() || s.isDefaultStatement()))
                            {
                                // Allow if last case/default was empty
                                CaseStatement sc = slast.isCaseStatement();
                                DefaultStatement sd = slast.isDefaultStatement();
                                if (sc && (!sc.statement.hasCode() || sc.statement.isCaseStatement() || sc.statement.isErrorStatement()))
                                {
                                }
                                else if (sd && (!sd.statement.hasCode() || sd.statement.isCaseStatement() || sd.statement.isErrorStatement()))
                                {
                                }
                                else
                                {
                                    const(char)* gototype = s.isCaseStatement() ? "case" : "default";
                                    s.deprecation("switch case fallthrough - use 'goto %s;' if intended", gototype);
                                }
                            }
                        }

                        if (!(result & BEfallthru) && !s.comeFrom())
                        {
                            if (s.blockExit(func, mustNotThrow) != BEhalt && s.hasCode())
                                s.warning("statement is not reachable");
                        }
                        else
                        {
                            result &= ~BEfallthru;
                            result |= s.blockExit(func, mustNotThrow);
                        }
                        slast = s;
                    }
                }
            }

            override void visit(UnrolledLoopStatement uls)
            {
                result = BEfallthru;
                foreach (s; *uls.statements)
                {
                    if (s)
                    {
                        int r = s.blockExit(func, mustNotThrow);
                        result |= r & ~(BEbreak | BEcontinue | BEfallthru);
                        if ((r & (BEfallthru | BEcontinue | BEbreak)) == 0)
                            result &= ~BEfallthru;
                    }
                }
            }

            override void visit(ScopeStatement s)
            {
                //printf("ScopeStatement::blockExit(%p)\n", s.statement);
                result = s.statement ? s.statement.blockExit(func, mustNotThrow) : BEfallthru;
            }

            override void visit(WhileStatement s)
            {
                assert(global.errors);
                result = BEfallthru;
            }

            override void visit(DoStatement s)
            {
                if (s._body)
                {
                    result = s._body.blockExit(func, mustNotThrow);
                    if (result == BEbreak)
                    {
                        result = BEfallthru;
                        return;
                    }
                    if (result & BEcontinue)
                        result |= BEfallthru;
                }
                else
                    result = BEfallthru;
                if (result & BEfallthru)
                {
                    if (canThrow(s.condition, func, mustNotThrow))
                        result |= BEthrow;
                    if (!(result & BEbreak) && s.condition.isBool(true))
                        result &= ~BEfallthru;
                }
                result &= ~(BEbreak | BEcontinue);
            }

            override void visit(ForStatement s)
            {
                result = BEfallthru;
                if (s._init)
                {
                    result = s._init.blockExit(func, mustNotThrow);
                    if (!(result & BEfallthru))
                        return;
                }
                if (s.condition)
                {
                    if (canThrow(s.condition, func, mustNotThrow))
                        result |= BEthrow;
                    if (s.condition.isBool(true))
                        result &= ~BEfallthru;
                    else if (s.condition.isBool(false))
                        return;
                }
                else
                    result &= ~BEfallthru; // the body must do the exiting
                if (s._body)
                {
                    int r = s._body.blockExit(func, mustNotThrow);
                    if (r & (BEbreak | BEgoto))
                        result |= BEfallthru;
                    result |= r & ~(BEfallthru | BEbreak | BEcontinue);
                }
                if (s.increment && canThrow(s.increment, func, mustNotThrow))
                    result |= BEthrow;
            }

            override void visit(ForeachStatement s)
            {
                result = BEfallthru;
                if (canThrow(s.aggr, func, mustNotThrow))
                    result |= BEthrow;
                if (s._body)
                    result |= s._body.blockExit(func, mustNotThrow) & ~(BEbreak | BEcontinue);
            }

            override void visit(ForeachRangeStatement s)
            {
                assert(global.errors);
                result = BEfallthru;
            }

            override void visit(IfStatement s)
            {
                //printf("IfStatement::blockExit(%p)\n", s);
                result = BEnone;
                if (canThrow(s.condition, func, mustNotThrow))
                    result |= BEthrow;
                if (s.condition.isBool(true))
                {
                    if (s.ifbody)
                        result |= s.ifbody.blockExit(func, mustNotThrow);
                    else
                        result |= BEfallthru;
                }
                else if (s.condition.isBool(false))
                {
                    if (s.elsebody)
                        result |= s.elsebody.blockExit(func, mustNotThrow);
                    else
                        result |= BEfallthru;
                }
                else
                {
                    if (s.ifbody)
                        result |= s.ifbody.blockExit(func, mustNotThrow);
                    else
                        result |= BEfallthru;
                    if (s.elsebody)
                        result |= s.elsebody.blockExit(func, mustNotThrow);
                    else
                        result |= BEfallthru;
                }
                //printf("IfStatement::blockExit(%p) = x%x\n", s, result);
            }

            override void visit(ConditionalStatement s)
            {
                result = s.ifbody.blockExit(func, mustNotThrow);
                if (s.elsebody)
                    result |= s.elsebody.blockExit(func, mustNotThrow);
            }

            override void visit(PragmaStatement s)
            {
                result = BEfallthru;
            }

            override void visit(StaticAssertStatement s)
            {
                result = BEfallthru;
            }

            override void visit(SwitchStatement s)
            {
                result = BEnone;
                if (canThrow(s.condition, func, mustNotThrow))
                    result |= BEthrow;
                if (s._body)
                {
                    result |= s._body.blockExit(func, mustNotThrow);
                    if (result & BEbreak)
                    {
                        result |= BEfallthru;
                        result &= ~BEbreak;
                    }
                }
                else
                    result |= BEfallthru;
            }

            override void visit(CaseStatement s)
            {
                result = s.statement.blockExit(func, mustNotThrow);
            }

            override void visit(DefaultStatement s)
            {
                result = s.statement.blockExit(func, mustNotThrow);
            }

            override void visit(GotoDefaultStatement s)
            {
                result = BEgoto;
            }

            override void visit(GotoCaseStatement s)
            {
                result = BEgoto;
            }

            override void visit(SwitchErrorStatement s)
            {
                // Switch errors are non-recoverable
                result = BEhalt;
            }

            override void visit(ReturnStatement s)
            {
                result = BEreturn;
                if (s.exp && canThrow(s.exp, func, mustNotThrow))
                    result |= BEthrow;
            }

            override void visit(BreakStatement s)
            {
                //printf("BreakStatement::blockExit(%p) = x%x\n", s, s.ident ? BEgoto : BEbreak);
                result = s.ident ? BEgoto : BEbreak;
            }

            override void visit(ContinueStatement s)
            {
                result = s.ident ? BEgoto : BEcontinue;
            }

            override void visit(SynchronizedStatement s)
            {
                result = s._body ? s._body.blockExit(func, mustNotThrow) : BEfallthru;
            }

            override void visit(WithStatement s)
            {
                result = BEnone;
                if (canThrow(s.exp, func, mustNotThrow))
                    result = BEthrow;
                if (s._body)
                    result |= s._body.blockExit(func, mustNotThrow);
                else
                    result |= BEfallthru;
            }

            override void visit(TryCatchStatement s)
            {
                assert(s._body);
                result = s._body.blockExit(func, false);

                int catchresult = 0;
                foreach (c; *s.catches)
                {
                    if (c.type == Type.terror)
                        continue;

                    int cresult;
                    if (c.handler)
                        cresult = c.handler.blockExit(func, mustNotThrow);
                    else
                        cresult = BEfallthru;

                    /* If we're catching Object, then there is no throwing
                     */
                    Identifier id = c.type.toBasetype().isClassHandle().ident;
                    if (c.internalCatch && (cresult & BEfallthru))
                    {
                        // Bugzilla 11542: leave blockExit flags of the body
                        cresult &= ~BEfallthru;
                    }
                    else if (id == Id.Object || id == Id.Throwable)
                    {
                        result &= ~(BEthrow | BEerrthrow);
                    }
                    else if (id == Id.Exception)
                    {
                        result &= ~BEthrow;
                    }
                    catchresult |= cresult;
                }
                if (mustNotThrow && (result & BEthrow))
                {
                    // now explain why this is nothrow
                    s._body.blockExit(func, mustNotThrow);
                }
                result |= catchresult;
            }

            override void visit(TryFinallyStatement s)
            {
                result = BEfallthru;
                if (s._body)
                    result = s._body.blockExit(func, false);

                // check finally body as well, it may throw (bug #4082)
                int finalresult = BEfallthru;
                if (s.finalbody)
                    finalresult = s.finalbody.blockExit(func, false);

                // If either body or finalbody halts
                if (result == BEhalt)
                    finalresult = BEnone;
                if (finalresult == BEhalt)
                    result = BEnone;

                if (mustNotThrow)
                {
                    // now explain why this is nothrow
                    if (s._body && (result & BEthrow))
                        s._body.blockExit(func, mustNotThrow);
                    if (s.finalbody && (finalresult & BEthrow))
                        s.finalbody.blockExit(func, mustNotThrow);
                }

                version (none)
                {
                    // Bugzilla 13201: Mask to prevent spurious warnings for
                    // destructor call, exit of synchronized statement, etc.
                    if (result == BEhalt && finalresult != BEhalt && s.finalbody && s.finalbody.hasCode())
                    {
                        s.finalbody.warning("statement is not reachable");
                    }
                }

                if (!(finalresult & BEfallthru))
                    result &= ~BEfallthru;
                result |= finalresult & ~BEfallthru;
            }

            override void visit(OnScopeStatement s)
            {
                // At this point, this statement is just an empty placeholder
                result = BEfallthru;
            }

            override void visit(ThrowStatement s)
            {
                if (s.internalThrow)
                {
                    // Bugzilla 8675: Allow throwing 'Throwable' object even if mustNotThrow.
                    result = BEfallthru;
                    return;
                }

                Type t = s.exp.type.toBasetype();
                ClassDeclaration cd = t.isClassHandle();
                assert(cd);

                if (cd == ClassDeclaration.errorException || ClassDeclaration.errorException.isBaseOf(cd, null))
                {
                    result = BEerrthrow;
                    return;
                }
                if (mustNotThrow)
                    s.error("%s is thrown but not caught", s.exp.type.toChars());

                result = BEthrow;
            }

            override void visit(GotoStatement s)
            {
                //printf("GotoStatement::blockExit(%p)\n", s);
                result = BEgoto;
            }

            override void visit(LabelStatement s)
            {
                //printf("LabelStatement::blockExit(%p)\n", s);
                result = s.statement ? s.statement.blockExit(func, mustNotThrow) : BEfallthru;
                if (s.breaks)
                    result |= BEfallthru;
            }

            override void visit(CompoundAsmStatement s)
            {
                if (mustNotThrow && !(s.stc & STCnothrow))
                    s.deprecation("asm statement is assumed to throw - mark it with 'nothrow' if it does not");

                // Assume the worst
                result = BEfallthru | BEreturn | BEgoto | BEhalt;
                if (!(s.stc & STCnothrow))
                    result |= BEthrow;
            }

            override void visit(ImportStatement s)
            {
                result = BEfallthru;
            }
        }

        scope BlockExit be = new BlockExit(func, mustNotThrow);
        accept(be);
        return be.result;
    }

    /* ============================================== */
    // true if statement 'comes from' somewhere else, like a goto
    final bool comeFrom()
    {
        extern (C++) final class ComeFrom : StoppableVisitor
        {
            alias visit = super.visit;
        public:
            override void visit(Statement s)
            {
            }

            override void visit(CaseStatement s)
            {
                stop = true;
            }

            override void visit(DefaultStatement s)
            {
                stop = true;
            }

            override void visit(LabelStatement s)
            {
                stop = true;
            }

            override void visit(AsmStatement s)
            {
                stop = true;
            }
        }

        scope ComeFrom cf = new ComeFrom();
        return walkPostorder(this, cf);
    }

    /* ============================================== */
    // Return true if statement has executable code.
    final bool hasCode()
    {
        extern (C++) final class HasCode : StoppableVisitor
        {
            alias visit = super.visit;
        public:
            override void visit(Statement s)
            {
                stop = true;
            }

            override void visit(ExpStatement s)
            {
                stop = s.exp !is null;
            }

            override void visit(CompoundStatement s)
            {
            }

            override void visit(ScopeStatement s)
            {
            }

            override void visit(ImportStatement s)
            {
            }
        }

        scope HasCode hc = new HasCode();
        return walkPostorder(this, hc);
    }

    /****************************************
     * If this statement has code that needs to run in a finally clause
     * at the end of the current scope, return that code in the form of
     * a Statement.
     * Output:
     *      *sentry         code executed upon entry to the scope
     *      *sexception     code executed upon exit from the scope via exception
     *      *sfinally       code executed in finally block
     */
    Statement scopeCode(Scope* sc, Statement* sentry, Statement* sexception, Statement* sfinally)
    {
        //printf("Statement::scopeCode()\n");
        //print();
        *sentry = null;
        *sexception = null;
        *sfinally = null;
        return this;
    }

    /*********************************
     * Flatten out the scope by presenting the statement
     * as an array of statements.
     * Returns NULL if no flattening necessary.
     */
    Statements* flatten(Scope* sc)
    {
        return null;
    }

    inout(Statement) last() inout nothrow pure
    {
        return this;
    }

    // Avoid dynamic_cast
    ErrorStatement isErrorStatement()
    {
        return null;
    }

    inout(ScopeStatement) isScopeStatement() inout nothrow pure
    {
        return null;
    }

    ExpStatement isExpStatement()
    {
        return null;
    }

    inout(CompoundStatement) isCompoundStatement() inout nothrow pure
    {
        return null;
    }

    inout(ReturnStatement) isReturnStatement() inout nothrow pure
    {
        return null;
    }

    IfStatement isIfStatement()
    {
        return null;
    }

    CaseStatement isCaseStatement()
    {
        return null;
    }

    DefaultStatement isDefaultStatement()
    {
        return null;
    }

    LabelStatement isLabelStatement()
    {
        return null;
    }

    GotoDefaultStatement isGotoDefaultStatement() pure
    {
        return null;
    }

    GotoCaseStatement isGotoCaseStatement() pure
    {
        return null;
    }

    inout(BreakStatement) isBreakStatement() inout nothrow pure
    {
        return null;
    }

    DtorExpStatement isDtorExpStatement()
    {
        return null;
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 * Any Statement that fails semantic() or has a component that is an ErrorExp or
 * a TypeError should return an ErrorStatement from semantic().
 */
extern (C++) final class ErrorStatement : Statement
{
    extern (D) this()
    {
        super(Loc());
        assert(global.gaggedErrors || global.errors);
    }

    override Statement syntaxCopy()
    {
        return this;
    }

    override ErrorStatement isErrorStatement()
    {
        return this;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class PeelStatement : Statement
{
    Statement s;

    extern (D) this(Statement s)
    {
        super(s.loc);
        this.s = s;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 * Convert TemplateMixin members (== Dsymbols) to Statements.
 */
extern (C++) Statement toStatement(Dsymbol s)
{
    extern (C++) final class ToStmt : Visitor
    {
        alias visit = super.visit;
    public:
        Statement result;

        Statement visitMembers(Loc loc, Dsymbols* a)
        {
            if (!a)
                return null;

            auto statements = new Statements();
            foreach (s; *a)
            {
                statements.push(toStatement(s));
            }
            return new CompoundStatement(loc, statements);
        }

        override void visit(Dsymbol s)
        {
            .error(Loc(), "Internal Compiler Error: cannot mixin %s %s\n", s.kind(), s.toChars());
            result = new ErrorStatement();
        }

        override void visit(TemplateMixin tm)
        {
            auto a = new Statements();
            foreach (m; *tm.members)
            {
                Statement s = toStatement(m);
                if (s)
                    a.push(s);
            }
            result = new CompoundStatement(tm.loc, a);
        }

        /* An actual declaration symbol will be converted to DeclarationExp
         * with ExpStatement.
         */
        Statement declStmt(Dsymbol s)
        {
            auto de = new DeclarationExp(s.loc, s);
            de.type = Type.tvoid; // avoid repeated semantic
            return new ExpStatement(s.loc, de);
        }

        override void visit(VarDeclaration d)
        {
            result = declStmt(d);
        }

        override void visit(AggregateDeclaration d)
        {
            result = declStmt(d);
        }

        override void visit(FuncDeclaration d)
        {
            result = declStmt(d);
        }

        override void visit(EnumDeclaration d)
        {
            result = declStmt(d);
        }

        override void visit(AliasDeclaration d)
        {
            result = declStmt(d);
        }

        override void visit(TemplateDeclaration d)
        {
            result = declStmt(d);
        }

        /* All attributes have been already picked by the semantic analysis of
         * 'bottom' declarations (function, struct, class, etc).
         * So we don't have to copy them.
         */
        override void visit(StorageClassDeclaration d)
        {
            result = visitMembers(d.loc, d.decl);
        }

        override void visit(DeprecatedDeclaration d)
        {
            result = visitMembers(d.loc, d.decl);
        }

        override void visit(LinkDeclaration d)
        {
            result = visitMembers(d.loc, d.decl);
        }

        override void visit(ProtDeclaration d)
        {
            result = visitMembers(d.loc, d.decl);
        }

        override void visit(AlignDeclaration d)
        {
            result = visitMembers(d.loc, d.decl);
        }

        override void visit(UserAttributeDeclaration d)
        {
            result = visitMembers(d.loc, d.decl);
        }

        override void visit(StaticAssert s)
        {
        }

        override void visit(Import s)
        {
        }

        override void visit(PragmaDeclaration d)
        {
        }

        override void visit(ConditionalDeclaration d)
        {
            result = visitMembers(d.loc, d.include(null, null));
        }

        override void visit(CompileDeclaration d)
        {
            result = visitMembers(d.loc, d.include(null, null));
        }
    }

    if (!s)
        return null;

    scope ToStmt v = new ToStmt();
    s.accept(v);
    return v.result;
}

/***********************************************************
 */
extern (C++) class ExpStatement : Statement
{
    Expression exp;

    final extern (D) this(Loc loc, Expression exp)
    {
        super(loc);
        this.exp = exp;
    }

    final extern (D) this(Loc loc, Dsymbol declaration)
    {
        super(loc);
        this.exp = new DeclarationExp(loc, declaration);
    }

    static ExpStatement create(Loc loc, Expression exp)
    {
        return new ExpStatement(loc, exp);
    }

    override Statement syntaxCopy()
    {
        return new ExpStatement(loc, exp ? exp.syntaxCopy() : null);
    }

    override final Statement scopeCode(Scope* sc, Statement* sentry, Statement* sexception, Statement* sfinally)
    {
        //printf("ExpStatement::scopeCode()\n");
        //print();

        *sentry = null;
        *sexception = null;
        *sfinally = null;

        if (exp && exp.op == TOKdeclaration)
        {
            auto de = cast(DeclarationExp)exp;
            auto v = de.declaration.isVarDeclaration();
            if (v && !v.isDataseg())
            {
                if (v.needsScopeDtor())
                {
                    //printf("dtor is: "); v.edtor.print();
                    *sfinally = new DtorExpStatement(loc, v.edtor, v);
                    v.storage_class |= STCnodtor; // don't add in dtor again
                }
            }
        }
        return this;
    }

    override final Statements* flatten(Scope* sc)
    {
        /* Bugzilla 14243: expand template mixin in statement scope
         * to handle variable destructors.
         */
        if (exp && exp.op == TOKdeclaration)
        {
            Dsymbol d = (cast(DeclarationExp)exp).declaration;
            if (TemplateMixin tm = d.isTemplateMixin())
            {
                Expression e = exp.semantic(sc);
                if (e.op == TOKerror || tm.errors)
                {
                    auto a = new Statements();
                    a.push(new ErrorStatement());
                    return a;
                }
                assert(tm.members);

                Statement s = toStatement(tm);
                version (none)
                {
                    OutBuffer buf;
                    buf.doindent = 1;
                    HdrGenState hgs;
                    hgs.hdrgen = true;
                    toCBuffer(s, &buf, &hgs);
                    printf("tm ==> s = %s\n", buf.peekString());
                }
                auto a = new Statements();
                a.push(s);
                return a;
            }
        }
        return null;
    }

    override final ExpStatement isExpStatement()
    {
        return this;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class DtorExpStatement : ExpStatement
{
    // Wraps an expression that is the destruction of 'var'
    VarDeclaration var;

    extern (D) this(Loc loc, Expression exp, VarDeclaration v)
    {
        super(loc, exp);
        this.var = v;
    }

    override Statement syntaxCopy()
    {
        return new DtorExpStatement(loc, exp ? exp.syntaxCopy() : null, var);
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }

    override DtorExpStatement isDtorExpStatement()
    {
        return this;
    }
}

/***********************************************************
 */
extern (C++) final class CompileStatement : Statement
{
    Expression exp;

    extern (D) this(Loc loc, Expression exp)
    {
        super(loc);
        this.exp = exp;
    }

    override Statement syntaxCopy()
    {
        return new CompileStatement(loc, exp.syntaxCopy());
    }

    override Statements* flatten(Scope* sc)
    {
        //printf("CompileStatement::flatten() %s\n", exp.toChars());

        auto errorStatements()
        {
            auto a = new Statements();
            a.push(new ErrorStatement());
            return a;
        }

        auto se = semanticString(sc, exp, "argument to mixin");
        if (!se)
            return errorStatements();
        se = se.toUTF8(sc);

        uint errors = global.errors;
        scope Parser p = new Parser(loc, sc._module, se.toStringz(), false);
        p.nextToken();

        auto a = new Statements();
        while (p.token.value != TOKeof)
        {
            Statement s = p.parseStatement(PSsemi | PScurlyscope);
            if (!s || p.errors)
            {
                assert(!p.errors || global.errors != errors); // make sure we caught all the cases
                return errorStatements();
            }
            a.push(s);
        }
        return a;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) class CompoundStatement : Statement
{
    Statements* statements;

    /**
     * Construct a `CompoundStatement` using an already existing
     * array of `Statement`s
     *
     * Params:
     *   loc = Instantiation informations
     *   s   = An array of `Statement`s, that will referenced by this class
     */
    final extern (D) this(Loc loc, Statements* s)
    {
        super(loc);
        statements = s;
    }

    /**
     * Construct a `CompoundStatement` from an array of `Statement`s
     *
     * Params:
     *   loc = Instantiation informations
     *   s   = A variadic array of `Statement`s, that will copied in this class
     *         The entries themselves will not be copied.
     */
    final extern (D) this(Loc loc, Statement[] sts...)
    {
        super(loc);
        statements = new Statements();
        statements.reserve(sts.length);
        foreach (s; sts)
            statements.push(s);
    }

    static CompoundStatement create(Loc loc, Statement s1, Statement s2)
    {
        return new CompoundStatement(loc, s1, s2);
    }

    override Statement syntaxCopy()
    {
        auto a = new Statements();
        a.setDim(statements.dim);
        foreach (i, s; *statements)
        {
            (*a)[i] = s ? s.syntaxCopy() : null;
        }
        return new CompoundStatement(loc, a);
    }

    override Statements* flatten(Scope* sc)
    {
        return statements;
    }

    override final inout(ReturnStatement) isReturnStatement() inout nothrow pure
    {
        ReturnStatement rs = null;
        foreach (s; *statements)
        {
            if (s)
            {
                rs = cast(ReturnStatement)s.isReturnStatement();
                if (rs)
                    break;
            }
        }
        return cast(inout)rs;
    }

    override final inout(Statement) last() inout nothrow pure
    {
        Statement s = null;
        for (size_t i = statements.dim; i; --i)
        {
            s = cast(Statement)(*statements)[i - 1];
            if (s)
            {
                s = cast(Statement)s.last();
                if (s)
                    break;
            }
        }
        return cast(inout)s;
    }

    override final inout(CompoundStatement) isCompoundStatement() inout nothrow pure
    {
        return this;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class CompoundDeclarationStatement : CompoundStatement
{
    extern (D) this(Loc loc, Statements* s)
    {
        super(loc, s);
        statements = s;
    }

    override Statement syntaxCopy()
    {
        auto a = new Statements();
        a.setDim(statements.dim);
        foreach (i, s; *statements)
        {
            (*a)[i] = s ? s.syntaxCopy() : null;
        }
        return new CompoundDeclarationStatement(loc, a);
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 * The purpose of this is so that continue will go to the next
 * of the statements, and break will go to the end of the statements.
 */
extern (C++) final class UnrolledLoopStatement : Statement
{
    Statements* statements;

    extern (D) this(Loc loc, Statements* s)
    {
        super(loc);
        statements = s;
    }

    override Statement syntaxCopy()
    {
        auto a = new Statements();
        a.setDim(statements.dim);
        foreach (i, s; *statements)
        {
            (*a)[i] = s ? s.syntaxCopy() : null;
        }
        return new UnrolledLoopStatement(loc, a);
    }

    override bool hasBreak()
    {
        return true;
    }

    override bool hasContinue()
    {
        return true;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class ScopeStatement : Statement
{
    Statement statement;
    Loc endloc;                 // location of closing curly bracket

    extern (D) this(Loc loc, Statement s, Loc endloc)
    {
        super(loc);
        this.statement = s;
        this.endloc = endloc;
    }

    override Statement syntaxCopy()
    {
        return new ScopeStatement(loc, statement ? statement.syntaxCopy() : null, endloc);
    }

    override inout(ScopeStatement) isScopeStatement() inout nothrow pure
    {
        return this;
    }

    override inout(ReturnStatement) isReturnStatement() inout nothrow pure
    {
        if (statement)
            return statement.isReturnStatement();
        return null;
    }

    override bool hasBreak()
    {
        //printf("ScopeStatement::hasBreak() %s\n", toChars());
        return statement ? statement.hasBreak() : false;
    }

    override bool hasContinue()
    {
        return statement ? statement.hasContinue() : false;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class WhileStatement : Statement
{
    Expression condition;
    Statement _body;
    Loc endloc;             // location of closing curly bracket

    extern (D) this(Loc loc, Expression c, Statement b, Loc endloc)
    {
        super(loc);
        condition = c;
        _body = b;
        this.endloc = endloc;
    }

    override Statement syntaxCopy()
    {
        return new WhileStatement(loc,
            condition.syntaxCopy(),
            _body ? _body.syntaxCopy() : null,
            endloc);
    }

    override bool hasBreak()
    {
        return true;
    }

    override bool hasContinue()
    {
        return true;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class DoStatement : Statement
{
    Statement _body;
    Expression condition;
    Loc endloc;                 // location of ';' after while

    extern (D) this(Loc loc, Statement b, Expression c, Loc endloc)
    {
        super(loc);
        _body = b;
        condition = c;
        this.endloc = endloc;
    }

    override Statement syntaxCopy()
    {
        return new DoStatement(loc,
            _body ? _body.syntaxCopy() : null,
            condition.syntaxCopy(),
            endloc);
    }

    override bool hasBreak()
    {
        return true;
    }

    override bool hasContinue()
    {
        return true;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class ForStatement : Statement
{
    Statement _init;
    Expression condition;
    Expression increment;
    Statement _body;
    Loc endloc;             // location of closing curly bracket

    // When wrapped in try/finally clauses, this points to the outermost one,
    // which may have an associated label. Internal break/continue statements
    // treat that label as referring to this loop.
    Statement relatedLabeled;

    extern (D) this(Loc loc, Statement _init, Expression condition, Expression increment, Statement _body, Loc endloc)
    {
        super(loc);
        this._init = _init;
        this.condition = condition;
        this.increment = increment;
        this._body = _body;
        this.endloc = endloc;
    }

    override Statement syntaxCopy()
    {
        return new ForStatement(loc,
            _init ? _init.syntaxCopy() : null,
            condition ? condition.syntaxCopy() : null,
            increment ? increment.syntaxCopy() : null,
            _body.syntaxCopy(),
            endloc);
    }

    override Statement scopeCode(Scope* sc, Statement* sentry, Statement* sexception, Statement* sfinally)
    {
        //printf("ForStatement::scopeCode()\n");
        Statement.scopeCode(sc, sentry, sexception, sfinally);
        return this;
    }

    override Statement getRelatedLabeled()
    {
        return relatedLabeled ? relatedLabeled : this;
    }

    override bool hasBreak()
    {
        //printf("ForStatement::hasBreak()\n");
        return true;
    }

    override bool hasContinue()
    {
        return true;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class ForeachStatement : Statement
{
    TOK op;                     // TOKforeach or TOKforeach_reverse
    Parameters* parameters;     // array of Parameter*'s
    Expression aggr;
    Statement _body;
    Loc endloc;                 // location of closing curly bracket

    VarDeclaration key;
    VarDeclaration value;

    FuncDeclaration func;       // function we're lexically in

    Statements* cases;          // put breaks, continues, gotos and returns here
    ScopeStatements* gotos;     // forward referenced goto's go here

    extern (D) this(Loc loc, TOK op, Parameters* parameters, Expression aggr, Statement _body, Loc endloc)
    {
        super(loc);
        this.op = op;
        this.parameters = parameters;
        this.aggr = aggr;
        this._body = _body;
        this.endloc = endloc;
    }

    override Statement syntaxCopy()
    {
        return new ForeachStatement(loc, op,
            Parameter.arraySyntaxCopy(parameters),
            aggr.syntaxCopy(),
            _body ? _body.syntaxCopy() : null,
            endloc);
    }

    bool checkForArgTypes()
    {
        bool result = false;
        foreach (p; *parameters)
        {
            if (!p.type)
            {
                error("cannot infer type for %s", p.ident.toChars());
                p.type = Type.terror;
                result = true;
            }
        }
        return result;
    }

    override bool hasBreak()
    {
        return true;
    }

    override bool hasContinue()
    {
        return true;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class ForeachRangeStatement : Statement
{
    TOK op;                 // TOKforeach or TOKforeach_reverse
    Parameter prm;          // loop index variable
    Expression lwr;
    Expression upr;
    Statement _body;
    Loc endloc;             // location of closing curly bracket

    VarDeclaration key;

    extern (D) this(Loc loc, TOK op, Parameter prm, Expression lwr, Expression upr, Statement _body, Loc endloc)
    {
        super(loc);
        this.op = op;
        this.prm = prm;
        this.lwr = lwr;
        this.upr = upr;
        this._body = _body;
        this.endloc = endloc;
    }

    override Statement syntaxCopy()
    {
        return new ForeachRangeStatement(loc, op, prm.syntaxCopy(), lwr.syntaxCopy(), upr.syntaxCopy(), _body ? _body.syntaxCopy() : null, endloc);
    }

    override bool hasBreak()
    {
        return true;
    }

    override bool hasContinue()
    {
        return true;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class IfStatement : Statement
{
    Parameter prm;
    Expression condition;
    Statement ifbody;
    Statement elsebody;
    VarDeclaration match;   // for MatchExpression results
    Loc endloc;                 // location of closing curly bracket

    extern (D) this(Loc loc, Parameter prm, Expression condition, Statement ifbody, Statement elsebody, Loc endloc)
    {
        super(loc);
        this.prm = prm;
        this.condition = condition;
        this.ifbody = ifbody;
        this.elsebody = elsebody;
        this.endloc = endloc;
    }

    override Statement syntaxCopy()
    {
        return new IfStatement(loc,
            prm ? prm.syntaxCopy() : null,
            condition.syntaxCopy(),
            ifbody ? ifbody.syntaxCopy() : null,
            elsebody ? elsebody.syntaxCopy() : null,
            endloc);
    }

    override IfStatement isIfStatement()
    {
        return this;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class ConditionalStatement : Statement
{
    Condition condition;
    Statement ifbody;
    Statement elsebody;

    extern (D) this(Loc loc, Condition condition, Statement ifbody, Statement elsebody)
    {
        super(loc);
        this.condition = condition;
        this.ifbody = ifbody;
        this.elsebody = elsebody;
    }

    override Statement syntaxCopy()
    {
        return new ConditionalStatement(loc, condition.syntaxCopy(), ifbody.syntaxCopy(), elsebody ? elsebody.syntaxCopy() : null);
    }

    override Statements* flatten(Scope* sc)
    {
        Statement s;

        //printf("ConditionalStatement::flatten()\n");
        if (condition.include(sc, null))
        {
            DebugCondition dc = condition.isDebugCondition();
            if (dc)
                s = new DebugStatement(loc, ifbody);
            else
                s = ifbody;
        }
        else
            s = elsebody;

        auto a = new Statements();
        a.push(s);
        return a;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class PragmaStatement : Statement
{
    Identifier ident;
    Expressions* args;      // array of Expression's
    Statement _body;

    extern (D) this(Loc loc, Identifier ident, Expressions* args, Statement _body)
    {
        super(loc);
        this.ident = ident;
        this.args = args;
        this._body = _body;
    }

    override Statement syntaxCopy()
    {
        return new PragmaStatement(loc, ident, Expression.arraySyntaxCopy(args), _body ? _body.syntaxCopy() : null);
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class StaticAssertStatement : Statement
{
    StaticAssert sa;

    extern (D) this(StaticAssert sa)
    {
        super(sa.loc);
        this.sa = sa;
    }

    override Statement syntaxCopy()
    {
        return new StaticAssertStatement(cast(StaticAssert)sa.syntaxCopy(null));
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class SwitchStatement : Statement
{
    Expression condition;
    Statement _body;
    bool isFinal;

    DefaultStatement sdefault;
    TryFinallyStatement tf;
    GotoCaseStatements gotoCases;   // array of unresolved GotoCaseStatement's
    CaseStatements* cases;          // array of CaseStatement's
    int hasNoDefault;               // !=0 if no default statement
    int hasVars;                    // !=0 if has variable case values
    VarDeclaration lastVar;

    extern (D) this(Loc loc, Expression c, Statement b, bool isFinal)
    {
        super(loc);
        this.condition = c;
        this._body = b;
        this.isFinal = isFinal;
    }

    override Statement syntaxCopy()
    {
        return new SwitchStatement(loc, condition.syntaxCopy(), _body.syntaxCopy(), isFinal);
    }

    override bool hasBreak()
    {
        return true;
    }

    final bool checkLabel()
    {
        bool checkVar(VarDeclaration vd)
        {
            if (!vd || vd.isDataseg() || (vd.storage_class & STCmanifest))
                return false;

            VarDeclaration last = lastVar;
            while (last && last != vd)
                last = last.lastVar;
            if (last == vd)
            {
                // All good, the label's scope has no variables
            }
            else if (vd.ident == Id.withSym)
            {
                deprecation("'switch' skips declaration of 'with' temporary at %s", vd.loc.toChars());
                return true;
            }
            else
            {
                deprecation("'switch' skips declaration of variable %s at %s", vd.toPrettyChars(), vd.loc.toChars());
                return true;
            }

            return false;
        }

        enum error = true;

        if (sdefault && checkVar(sdefault.lastVar))
            return !error; // return error once fully deprecated

        foreach (scase; *cases)
        {
            if (scase && checkVar(scase.lastVar))
                return !error; // return error once fully deprecated
        }
        return !error;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class CaseStatement : Statement
{
    Expression exp;
    Statement statement;
    int index;              // which case it is (since we sort this)
    VarDeclaration lastVar;

    extern (D) this(Loc loc, Expression exp, Statement s)
    {
        super(loc);
        this.exp = exp;
        this.statement = s;
    }

    override Statement syntaxCopy()
    {
        return new CaseStatement(loc, exp.syntaxCopy(), statement.syntaxCopy());
    }

    override int compare(RootObject obj)
    {
        // Sort cases so we can do an efficient lookup
        CaseStatement cs2 = cast(CaseStatement)obj;
        return exp.compare(cs2.exp);
    }

    override CaseStatement isCaseStatement()
    {
        return this;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class CaseRangeStatement : Statement
{
    Expression first;
    Expression last;
    Statement statement;

    extern (D) this(Loc loc, Expression first, Expression last, Statement s)
    {
        super(loc);
        this.first = first;
        this.last = last;
        this.statement = s;
    }

    override Statement syntaxCopy()
    {
        return new CaseRangeStatement(loc, first.syntaxCopy(), last.syntaxCopy(), statement.syntaxCopy());
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class DefaultStatement : Statement
{
    Statement statement;
    VarDeclaration lastVar;

    extern (D) this(Loc loc, Statement s)
    {
        super(loc);
        this.statement = s;
    }

    override Statement syntaxCopy()
    {
        return new DefaultStatement(loc, statement.syntaxCopy());
    }

    override DefaultStatement isDefaultStatement()
    {
        return this;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class GotoDefaultStatement : Statement
{
    SwitchStatement sw;

    extern (D) this(Loc loc)
    {
        super(loc);
    }

    override Statement syntaxCopy()
    {
        return new GotoDefaultStatement(loc);
    }

    override GotoDefaultStatement isGotoDefaultStatement() pure
    {
        return this;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class GotoCaseStatement : Statement
{
    Expression exp;     // null, or which case to goto
    CaseStatement cs;   // case statement it resolves to

    extern (D) this(Loc loc, Expression exp)
    {
        super(loc);
        this.exp = exp;
    }

    override Statement syntaxCopy()
    {
        return new GotoCaseStatement(loc, exp ? exp.syntaxCopy() : null);
    }

    override GotoCaseStatement isGotoCaseStatement() pure
    {
        return this;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class SwitchErrorStatement : Statement
{
    extern (D) this(Loc loc)
    {
        super(loc);
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class ReturnStatement : Statement
{
    Expression exp;
    size_t caseDim;

    extern (D) this(Loc loc, Expression exp)
    {
        super(loc);
        this.exp = exp;
    }

    override Statement syntaxCopy()
    {
        return new ReturnStatement(loc, exp ? exp.syntaxCopy() : null);
    }

    override inout(ReturnStatement) isReturnStatement() inout nothrow pure
    {
        return this;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class BreakStatement : Statement
{
    Identifier ident;

    extern (D) this(Loc loc, Identifier ident)
    {
        super(loc);
        this.ident = ident;
    }

    override Statement syntaxCopy()
    {
        return new BreakStatement(loc, ident);
    }

    override inout(BreakStatement) isBreakStatement() inout nothrow pure
    {
        return this;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class ContinueStatement : Statement
{
    Identifier ident;

    extern (D) this(Loc loc, Identifier ident)
    {
        super(loc);
        this.ident = ident;
    }

    override Statement syntaxCopy()
    {
        return new ContinueStatement(loc, ident);
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class SynchronizedStatement : Statement
{
    Expression exp;
    Statement _body;

    extern (D) this(Loc loc, Expression exp, Statement _body)
    {
        super(loc);
        this.exp = exp;
        this._body = _body;
    }

    override Statement syntaxCopy()
    {
        return new SynchronizedStatement(loc, exp ? exp.syntaxCopy() : null, _body ? _body.syntaxCopy() : null);
    }

    override bool hasBreak()
    {
        return false; //true;
    }

    override bool hasContinue()
    {
        return false; //true;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class WithStatement : Statement
{
    Expression exp;
    Statement _body;
    VarDeclaration wthis;
    Loc endloc;

    extern (D) this(Loc loc, Expression exp, Statement _body, Loc endloc)
    {
        super(loc);
        this.exp = exp;
        this._body = _body;
        this.endloc = endloc;
    }

    override Statement syntaxCopy()
    {
        return new WithStatement(loc, exp.syntaxCopy(), _body ? _body.syntaxCopy() : null, endloc);
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class TryCatchStatement : Statement
{
    Statement _body;
    Catches* catches;

    extern (D) this(Loc loc, Statement _body, Catches* catches)
    {
        super(loc);
        this._body = _body;
        this.catches = catches;
    }

    override Statement syntaxCopy()
    {
        auto a = new Catches();
        a.setDim(catches.dim);
        foreach (i, c; *catches)
        {
            (*a)[i] = c.syntaxCopy();
        }
        return new TryCatchStatement(loc, _body.syntaxCopy(), a);
    }

    override bool hasBreak()
    {
        return false;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class Catch : RootObject
{
    Loc loc;
    Type type;
    Identifier ident;
    VarDeclaration var;
    Statement handler;

    bool errors;                // set if semantic processing errors

    // was generated by the compiler, wasn't present in source code
    bool internalCatch;

    extern (D) this(Loc loc, Type t, Identifier id, Statement handler)
    {
        //printf("Catch(%s, loc = %s)\n", id.toChars(), loc.toChars());
        this.loc = loc;
        this.type = t;
        this.ident = id;
        this.handler = handler;
    }

    Catch syntaxCopy()
    {
        auto c = new Catch(loc, type ? type.syntaxCopy() : getThrowable(), ident, (handler ? handler.syntaxCopy() : null));
        c.internalCatch = internalCatch;
        return c;
    }
}

/***********************************************************
 */
extern (C++) final class TryFinallyStatement : Statement
{
    Statement _body;
    Statement finalbody;

    extern (D) this(Loc loc, Statement _body, Statement finalbody)
    {
        super(loc);
        this._body = _body;
        this.finalbody = finalbody;
    }

    static TryFinallyStatement create(Loc loc, Statement _body, Statement finalbody)
    {
        return new TryFinallyStatement(loc, _body, finalbody);
    }

    override Statement syntaxCopy()
    {
        return new TryFinallyStatement(loc, _body.syntaxCopy(), finalbody.syntaxCopy());
    }

    override bool hasBreak()
    {
        return false; //true;
    }

    override bool hasContinue()
    {
        return false; //true;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class OnScopeStatement : Statement
{
    TOK tok;
    Statement statement;

    extern (D) this(Loc loc, TOK tok, Statement statement)
    {
        super(loc);
        this.tok = tok;
        this.statement = statement;
    }

    override Statement syntaxCopy()
    {
        return new OnScopeStatement(loc, tok, statement.syntaxCopy());
    }

    override Statement scopeCode(Scope* sc, Statement* sentry, Statement* sexception, Statement* sfinally)
    {
        //printf("OnScopeStatement::scopeCode()\n");
        //print();
        *sentry = null;
        *sexception = null;
        *sfinally = null;

        Statement s = new PeelStatement(statement);

        switch (tok)
        {
        case TOKon_scope_exit:
            *sfinally = s;
            break;

        case TOKon_scope_failure:
            *sexception = s;
            break;

        case TOKon_scope_success:
            {
                /* Create:
                 *  sentry:   bool x = false;
                 *  sexception:    x = true;
                 *  sfinally: if (!x) statement;
                 */
                auto v = copyToTemp(0, "__os", new IntegerExp(Loc(), 0, Type.tbool));
                *sentry = new ExpStatement(loc, v);

                Expression e = new IntegerExp(Loc(), 1, Type.tbool);
                e = new AssignExp(Loc(), new VarExp(Loc(), v), e);
                *sexception = new ExpStatement(Loc(), e);

                e = new VarExp(Loc(), v);
                e = new NotExp(Loc(), e);
                *sfinally = new IfStatement(Loc(), null, e, s, null, Loc());

                break;
            }
        default:
            assert(0);
        }
        return null;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class ThrowStatement : Statement
{
    Expression exp;

    // was generated by the compiler, wasn't present in source code
    bool internalThrow;

    extern (D) this(Loc loc, Expression exp)
    {
        super(loc);
        this.exp = exp;
    }

    override Statement syntaxCopy()
    {
        auto s = new ThrowStatement(loc, exp.syntaxCopy());
        s.internalThrow = internalThrow;
        return s;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class DebugStatement : Statement
{
    Statement statement;

    extern (D) this(Loc loc, Statement statement)
    {
        super(loc);
        this.statement = statement;
    }

    override Statement syntaxCopy()
    {
        return new DebugStatement(loc, statement ? statement.syntaxCopy() : null);
    }

    override Statements* flatten(Scope* sc)
    {
        Statements* a = statement ? statement.flatten(sc) : null;
        if (a)
        {
            foreach (ref s; *a)
            {
                s = new DebugStatement(loc, s);
            }
        }
        return a;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class GotoStatement : Statement
{
    Identifier ident;
    LabelDsymbol label;
    TryFinallyStatement tf;
    OnScopeStatement os;
    VarDeclaration lastVar;

    extern (D) this(Loc loc, Identifier ident)
    {
        super(loc);
        this.ident = ident;
    }

    override Statement syntaxCopy()
    {
        return new GotoStatement(loc, ident);
    }

    final bool checkLabel()
    {
        if (!label.statement)
        {
            error("label '%s' is undefined", label.toChars());
            return true;
        }

        if (label.statement.os != os)
        {
            if (os && os.tok == TOKon_scope_failure && !label.statement.os)
            {
                // Jump out from scope(failure) block is allowed.
            }
            else
            {
                if (label.statement.os)
                    error("cannot goto in to %s block", Token.toChars(label.statement.os.tok));
                else
                    error("cannot goto out of %s block", Token.toChars(os.tok));
                return true;
            }
        }

        if (label.statement.tf != tf)
        {
            error("cannot goto in or out of finally block");
            return true;
        }

        VarDeclaration vd = label.statement.lastVar;
        if (!vd || vd.isDataseg() || (vd.storage_class & STCmanifest))
            return false;

        VarDeclaration last = lastVar;
        while (last && last != vd)
            last = last.lastVar;
        if (last == vd)
        {
            // All good, the label's scope has no variables
        }
        else if (vd.storage_class & STCexptemp)
        {
            // Lifetime ends at end of expression, so no issue with skipping the statement
        }
        else if (vd.ident == Id.withSym)
        {
            error("goto skips declaration of with temporary at %s", vd.loc.toChars());
            return true;
        }
        else
        {
            error("goto skips declaration of variable %s at %s", vd.toPrettyChars(), vd.loc.toChars());
            return true;
        }

        return false;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class LabelStatement : Statement
{
    Identifier ident;
    Statement statement;
    TryFinallyStatement tf;
    OnScopeStatement os;
    VarDeclaration lastVar;
    Statement gotoTarget;       // interpret
    bool breaks;                // someone did a 'break ident'

    extern (D) this(Loc loc, Identifier ident, Statement statement)
    {
        super(loc);
        this.ident = ident;
        this.statement = statement;
    }

    override Statement syntaxCopy()
    {
        return new LabelStatement(loc, ident, statement ? statement.syntaxCopy() : null);
    }

    override Statements* flatten(Scope* sc)
    {
        Statements* a = null;
        if (statement)
        {
            a = statement.flatten(sc);
            if (a)
            {
                if (!a.dim)
                {
                    a.push(new ExpStatement(loc, cast(Expression)null));
                }

                // reuse 'this' LabelStatement
                this.statement = (*a)[0];
                (*a)[0] = this;
            }
        }
        return a;
    }

    override Statement scopeCode(Scope* sc, Statement* sentry, Statement* sexit, Statement* sfinally)
    {
        //printf("LabelStatement::scopeCode()\n");
        if (statement)
            statement = statement.scopeCode(sc, sentry, sexit, sfinally);
        else
        {
            *sentry = null;
            *sexit = null;
            *sfinally = null;
        }
        return this;
    }

    override LabelStatement isLabelStatement()
    {
        return this;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class LabelDsymbol : Dsymbol
{
    LabelStatement statement;

    extern (D) this(Identifier ident)
    {
        super(ident);
    }

    static LabelDsymbol create(Identifier ident)
    {
        return new LabelDsymbol(ident);
    }

    // is this a LabelDsymbol()?
    override LabelDsymbol isLabel()
    {
        return this;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class AsmStatement : Statement
{
    Token* tokens;
    code* asmcode;
    uint asmalign;  // alignment of this statement
    uint regs;      // mask of registers modified (must match regm_t in back end)
    bool refparam;  // true if function parameter is referenced
    bool naked;     // true if function is to be naked

    extern (D) this(Loc loc, Token* tokens)
    {
        super(loc);
        this.tokens = tokens;
    }

    override Statement syntaxCopy()
    {
        return new AsmStatement(loc, tokens);
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 * a complete asm {} block
 */
extern (C++) final class CompoundAsmStatement : CompoundStatement
{
    StorageClass stc; // postfix attributes like nothrow/pure/@trusted

    extern (D) this(Loc loc, Statements* s, StorageClass stc)
    {
        super(loc, s);
        this.stc = stc;
    }

    override CompoundAsmStatement syntaxCopy()
    {
        auto a = new Statements();
        a.setDim(statements.dim);
        foreach (i, s; *statements)
        {
            (*a)[i] = s ? s.syntaxCopy() : null;
        }
        return new CompoundAsmStatement(loc, a, stc);
    }

    override Statements* flatten(Scope* sc)
    {
        return null;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class ImportStatement : Statement
{
    Dsymbols* imports;      // Array of Import's

    extern (D) this(Loc loc, Dsymbols* imports)
    {
        super(loc);
        this.imports = imports;
    }

    override Statement syntaxCopy()
    {
        auto m = new Dsymbols();
        m.setDim(imports.dim);
        foreach (i, s; *imports)
        {
            (*m)[i] = s.syntaxCopy(null);
        }
        return new ImportStatement(loc, m);
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}
