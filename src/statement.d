// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.statement;

import core.stdc.stdarg, core.stdc.stdio;
import ddmd.aggregate, ddmd.arrayop, ddmd.arraytypes, ddmd.attrib, ddmd.backend, ddmd.canthrow, ddmd.clone, ddmd.cond, ddmd.ctfeexpr, ddmd.dcast, ddmd.dclass, ddmd.declaration, ddmd.denum, ddmd.dimport, ddmd.dinterpret, ddmd.dscope, ddmd.dsymbol, ddmd.dtemplate, ddmd.errors, ddmd.escape, ddmd.expression, ddmd.func, ddmd.globals, ddmd.hdrgen, ddmd.id, ddmd.identifier, ddmd.init, ddmd.inline, ddmd.intrange, ddmd.mtype, ddmd.mtype, ddmd.nogc, ddmd.opover, ddmd.parse, ddmd.root.outbuffer, ddmd.root.rootobject, ddmd.sapply, ddmd.sideeffect, ddmd.staticassert, ddmd.target, ddmd.tokens, ddmd.visitor;

extern extern (C++) Statement asmSemantic(AsmStatement s, Scope* sc);

extern (C++) Identifier fixupLabelName(Scope* sc, Identifier ident)
{
    uint flags = (sc.flags & SCOPEcontract);
    if (flags && flags != SCOPEinvariant && !(ident.string[0] == '_' && ident.string[1] == '_'))
    {
        /* CTFE requires FuncDeclaration::labtab for the interpretation.
         * So fixing the label name inside in/out contracts is necessary
         * for the uniqueness in labtab.
         */
        const(char)* prefix = flags == SCOPErequire ? "__in_" : "__out_";
        OutBuffer buf;
        buf.printf("%s%s", prefix, ident.toChars());
        const(char)* name = buf.extractString();
        ident = Identifier.idPool(name);
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

extern (C++) class Statement : RootObject
{
public:
    Loc loc;

    /******************************** Statement ***************************/
    final extern (D) this(Loc loc)
    {
        this.loc = loc;
        // If this is an in{} contract scope statement (skip for determining
        //  inlineStatus of a function body for header content)
    }

    Statement syntaxCopy()
    {
        assert(0);
        return null;
    }

    final void print()
    {
        fprintf(stderr, "%s\n", toChars());
        fflush(stderr);
    }

    final char* toChars()
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

    Statement semantic(Scope* sc)
    {
        return this;
    }

    // Same as semanticNoScope(), but do create a new scope
    final Statement semanticScope(Scope* sc, Statement sbreak, Statement scontinue)
    {
        Scope* scd = sc.push();
        if (sbreak)
            scd.sbreak = sbreak;
        if (scontinue)
            scd.scontinue = scontinue;
        Statement s = semanticNoScope(scd);
        scd.pop();
        return s;
    }

    final Statement semanticNoScope(Scope* sc)
    {
        //printf("Statement::semanticNoScope() %s\n", toChars());
        Statement s = this;
        if (!s.isCompoundStatement() && !s.isScopeStatement())
        {
            s = new CompoundStatement(loc, this); // so scopeCode() gets called
        }
        s = s.semantic(sc);
        return s;
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
            void visit(Statement s)
            {
            }

            void visit(TryCatchStatement s)
            {
                stop = true;
            }

            void visit(TryFinallyStatement s)
            {
                stop = true;
            }

            void visit(OnScopeStatement s)
            {
                stop = true;
            }

            void visit(SynchronizedStatement s)
            {
                stop = true;
            }
        }

        scope UsesEH ueh = new UsesEH();
        return walkPostorder(this, ueh);
    }

    /* ============================================== */
    /* Only valid after semantic analysis
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

            void visit(Statement s)
            {
                printf("Statement::blockExit(%p)\n", s);
                printf("%s\n", s.toChars());
                assert(0);
                result = BEany;
            }

            void visit(ErrorStatement s)
            {
                result = BEany;
            }

            void visit(ExpStatement s)
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

            void visit(CompileStatement s)
            {
                assert(global.errors);
                result = BEfallthru;
            }

            void visit(CompoundStatement cs)
            {
                //printf("CompoundStatement::blockExit(%p) %d\n", cs, cs->statements->dim);
                result = BEfallthru;
                Statement slast = null;
                for (size_t i = 0; i < cs.statements.dim; i++)
                {
                    Statement s = (*cs.statements)[i];
                    if (s)
                    {
                        //printf("result = x%x\n", result);
                        //printf("s: %s\n", s->toChars());
                        if (global.params.warnings && result & BEfallthru && slast)
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
                                    s.warning("switch case fallthrough - use 'goto %s;' if intended", gototype);
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

            void visit(UnrolledLoopStatement uls)
            {
                result = BEfallthru;
                for (size_t i = 0; i < uls.statements.dim; i++)
                {
                    Statement s = (*uls.statements)[i];
                    if (s)
                    {
                        int r = s.blockExit(func, mustNotThrow);
                        result |= r & ~(BEbreak | BEcontinue | BEfallthru);
                        if ((r & (BEfallthru | BEcontinue | BEbreak)) == 0)
                            result &= ~BEfallthru;
                    }
                }
            }

            void visit(ScopeStatement s)
            {
                //printf("ScopeStatement::blockExit(%p)\n", s->statement);
                result = s.statement ? s.statement.blockExit(func, mustNotThrow) : BEfallthru;
            }

            void visit(WhileStatement s)
            {
                assert(global.errors);
                result = BEfallthru;
            }

            void visit(DoStatement s)
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

            void visit(ForStatement s)
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

            void visit(ForeachStatement s)
            {
                result = BEfallthru;
                if (canThrow(s.aggr, func, mustNotThrow))
                    result |= BEthrow;
                if (s._body)
                    result |= s._body.blockExit(func, mustNotThrow) & ~(BEbreak | BEcontinue);
            }

            void visit(ForeachRangeStatement s)
            {
                assert(global.errors);
                result = BEfallthru;
            }

            void visit(IfStatement s)
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

            void visit(ConditionalStatement s)
            {
                result = s.ifbody.blockExit(func, mustNotThrow);
                if (s.elsebody)
                    result |= s.elsebody.blockExit(func, mustNotThrow);
            }

            void visit(PragmaStatement s)
            {
                result = BEfallthru;
            }

            void visit(StaticAssertStatement s)
            {
                result = BEfallthru;
            }

            void visit(SwitchStatement s)
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

            void visit(CaseStatement s)
            {
                result = s.statement.blockExit(func, mustNotThrow);
            }

            void visit(DefaultStatement s)
            {
                result = s.statement.blockExit(func, mustNotThrow);
            }

            void visit(GotoDefaultStatement s)
            {
                result = BEgoto;
            }

            void visit(GotoCaseStatement s)
            {
                result = BEgoto;
            }

            void visit(SwitchErrorStatement s)
            {
                // Switch errors are non-recoverable
                result = BEhalt;
            }

            void visit(ReturnStatement s)
            {
                result = BEreturn;
                if (s.exp && canThrow(s.exp, func, mustNotThrow))
                    result |= BEthrow;
            }

            void visit(BreakStatement s)
            {
                //printf("BreakStatement::blockExit(%p) = x%x\n", s, s->ident ? BEgoto : BEbreak);
                result = s.ident ? BEgoto : BEbreak;
            }

            void visit(ContinueStatement s)
            {
                result = s.ident ? BEgoto : BEcontinue;
            }

            void visit(SynchronizedStatement s)
            {
                result = s._body ? s._body.blockExit(func, mustNotThrow) : BEfallthru;
            }

            void visit(WithStatement s)
            {
                result = BEnone;
                if (canThrow(s.exp, func, mustNotThrow))
                    result = BEthrow;
                if (s._body)
                    result |= s._body.blockExit(func, mustNotThrow);
                else
                    result |= BEfallthru;
            }

            void visit(TryCatchStatement s)
            {
                assert(s._body);
                result = s._body.blockExit(func, false);
                int catchresult = 0;
                for (size_t i = 0; i < s.catches.dim; i++)
                {
                    Catch c = (*s.catches)[i];
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

            void visit(TryFinallyStatement s)
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

            void visit(OnScopeStatement s)
            {
                // At this point, this statement is just an empty placeholder
                result = BEfallthru;
            }

            void visit(ThrowStatement s)
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

            void visit(GotoStatement s)
            {
                //printf("GotoStatement::blockExit(%p)\n", s);
                result = BEgoto;
            }

            void visit(LabelStatement s)
            {
                //printf("LabelStatement::blockExit(%p)\n", s);
                result = s.statement ? s.statement.blockExit(func, mustNotThrow) : BEfallthru;
                if (s.breaks)
                    result |= BEfallthru;
            }

            void visit(CompoundAsmStatement s)
            {
                if (mustNotThrow && !(s.stc & STCnothrow))
                    s.deprecation("asm statement is assumed to throw - mark it with 'nothrow' if it does not");
                // Assume the worst
                result = BEfallthru | BEreturn | BEgoto | BEhalt;
                if (!(s.stc & STCnothrow))
                    result |= BEthrow;
            }

            void visit(ImportStatement s)
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
            void visit(Statement s)
            {
            }

            void visit(CaseStatement s)
            {
                stop = true;
            }

            void visit(DefaultStatement s)
            {
                stop = true;
            }

            void visit(LabelStatement s)
            {
                stop = true;
            }

            void visit(AsmStatement s)
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
            void visit(Statement s)
            {
                stop = true;
            }

            void visit(ExpStatement s)
            {
                stop = s.exp !is null;
            }

            void visit(CompoundStatement s)
            {
            }

            void visit(ScopeStatement s)
            {
            }

            void visit(ImportStatement s)
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

    Statement last()
    {
        return this;
    }

    // Avoid dynamic_cast
    ErrorStatement isErrorStatement()
    {
        return null;
    }

    ScopeStatement isScopeStatement()
    {
        return null;
    }

    ExpStatement isExpStatement()
    {
        return null;
    }

    CompoundStatement isCompoundStatement()
    {
        return null;
    }

    ReturnStatement isReturnStatement()
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

    DtorExpStatement isDtorExpStatement()
    {
        return null;
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

/** Any Statement that fails semantic() or has a component that is an ErrorExp or
 * a TypeError should return an ErrorStatement from semantic().
 */
extern (C++) final class ErrorStatement : Statement
{
public:
    /******************************** ErrorStatement ***************************/
    extern (D) this()
    {
        super(Loc());
        assert(global.gaggedErrors || global.errors);
    }

    Statement syntaxCopy()
    {
        return this;
    }

    Statement semantic(Scope* sc)
    {
        return this;
    }

    ErrorStatement isErrorStatement()
    {
        return this;
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

extern (C++) final class PeelStatement : Statement
{
public:
    Statement s;

    /******************************** PeelStatement ***************************/
    extern (D) this(Statement s)
    {
        super(s.loc);
        this.s = s;
    }

    Statement semantic(Scope* sc)
    {
        /* "peel" off this wrapper, and don't run semantic()
         * on the result.
         */
        return s;
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

/****************************************
 * Convert TemplateMixin members (== Dsymbols) to Statements.
 */
extern (C++) Statement toStatement(Dsymbol s)
{
    extern (C++) final class ToStmt : Visitor
    {
        alias visit = super.visit;
    public:
        Statement result;

        extern (D) this()
        {
            this.result = null;
        }

        Statement visitMembers(Loc loc, Dsymbols* a)
        {
            if (!a)
                return null;
            auto statements = new Statements();
            for (size_t i = 0; i < a.dim; i++)
            {
                statements.push(toStatement((*a)[i]));
            }
            return new CompoundStatement(loc, statements);
        }

        void visit(Dsymbol s)
        {
            .error(Loc(), "Internal Compiler Error: cannot mixin %s %s\n", s.kind(), s.toChars());
            result = new ErrorStatement();
        }

        void visit(TemplateMixin tm)
        {
            auto a = new Statements();
            for (size_t i = 0; i < tm.members.dim; i++)
            {
                Statement s = toStatement((*tm.members)[i]);
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

        void visit(VarDeclaration d)
        {
            result = declStmt(d);
        }

        void visit(AggregateDeclaration d)
        {
            result = declStmt(d);
        }

        void visit(FuncDeclaration d)
        {
            result = declStmt(d);
        }

        void visit(EnumDeclaration d)
        {
            result = declStmt(d);
        }

        void visit(AliasDeclaration d)
        {
            result = declStmt(d);
        }

        void visit(TemplateDeclaration d)
        {
            result = declStmt(d);
        }

        /* All attributes have been already picked by the semantic analysis of
         * 'bottom' declarations (function, struct, class, etc).
         * So we don't have to copy them.
         */
        void visit(StorageClassDeclaration d)
        {
            result = visitMembers(d.loc, d.decl);
        }

        void visit(DeprecatedDeclaration d)
        {
            result = visitMembers(d.loc, d.decl);
        }

        void visit(LinkDeclaration d)
        {
            result = visitMembers(d.loc, d.decl);
        }

        void visit(ProtDeclaration d)
        {
            result = visitMembers(d.loc, d.decl);
        }

        void visit(AlignDeclaration d)
        {
            result = visitMembers(d.loc, d.decl);
        }

        void visit(UserAttributeDeclaration d)
        {
            result = visitMembers(d.loc, d.decl);
        }

        void visit(StaticAssert s)
        {
        }

        void visit(Import s)
        {
        }

        void visit(PragmaDeclaration d)
        {
        }

        void visit(ConditionalDeclaration d)
        {
            result = visitMembers(d.loc, d.include(null, null));
        }

        void visit(CompileDeclaration d)
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

extern (C++) class ExpStatement : Statement
{
public:
    Expression exp;

    /******************************** ExpStatement ***************************/
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

    final static ExpStatement create(Loc loc, Expression exp)
    {
        return new ExpStatement(loc, exp);
    }

    Statement syntaxCopy()
    {
        return new ExpStatement(loc, exp ? exp.syntaxCopy() : null);
    }

    final Statement semantic(Scope* sc)
    {
        if (exp)
        {
            //printf("ExpStatement::semantic() %s\n", exp->toChars());
            version (none)
            {
                // Doesn't work because of difficulty dealing with things like a.b.c!(args).Foo!(args)
                // See if this should be rewritten as a TemplateMixin
                if (exp.op == TOKdeclaration)
                {
                    DeclarationExp de = cast(DeclarationExp)exp;
                    Dsymbol s = de.declaration;
                    printf("s: %s %s\n", s.kind(), s.toChars());
                    VarDeclaration v = s.isVarDeclaration();
                    if (v)
                    {
                        printf("%s, %d\n", v.type.toChars(), v.type.ty);
                    }
                }
            }
            exp = exp.semantic(sc);
            exp = resolveProperties(sc, exp);
            exp = exp.addDtorHook(sc);
            discardValue(exp);
            exp = exp.optimize(WANTvalue);
            exp = checkGC(sc, exp);
            if (exp.op == TOKerror)
                return new ErrorStatement();
        }
        return this;
    }

    final Statement scopeCode(Scope* sc, Statement* sentry, Statement* sexception, Statement* sfinally)
    {
        //printf("ExpStatement::scopeCode()\n");
        //print();
        *sentry = null;
        *sexception = null;
        *sfinally = null;
        if (exp)
        {
            if (exp.op == TOKdeclaration)
            {
                DeclarationExp de = cast(DeclarationExp)exp;
                VarDeclaration v = de.declaration.isVarDeclaration();
                if (v && !v.noscope && !v.isDataseg())
                {
                    Expression e = v.edtor;
                    if (e)
                    {
                        //printf("dtor is: "); e->print();
                        version (none)
                        {
                            if (v.type.toBasetype().ty == Tstruct)
                            {
                                /* Need a 'gate' to turn on/off destruction,
                                 * in case v gets moved elsewhere.
                                 */
                                Identifier id = Identifier.generateId("__runDtor");
                                auto ie = new ExpInitializer(loc, new IntegerExp(1));
                                auto rd = new VarDeclaration(loc, Type.tint32, id, ie);
                                rd.storage_class |= STCtemp;
                                *sentry = new ExpStatement(loc, rd);
                                v.rundtor = rd;
                                /* Rewrite e as:
                                 *  rundtor && e
                                 */
                                Expression ve = new VarExp(loc, v.rundtor);
                                e = new AndAndExp(loc, ve, e);
                                e.type = Type.tbool;
                            }
                        }
                        *sfinally = new DtorExpStatement(loc, e, v);
                    }
                    v.noscope = 1; // don't add in dtor again
                }
            }
        }
        return this;
    }

    final Statements* flatten(Scope* sc)
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

    final ExpStatement isExpStatement()
    {
        return this;
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

extern (C++) final class DtorExpStatement : ExpStatement
{
public:
    /* Wraps an expression that is the destruction of 'var'
     */
    VarDeclaration var;

    /******************************** DtorExpStatement ***************************/
    extern (D) this(Loc loc, Expression exp, VarDeclaration v)
    {
        super(loc, exp);
        this.var = v;
    }

    Statement syntaxCopy()
    {
        return new DtorExpStatement(loc, exp ? exp.syntaxCopy() : null, var);
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }

    DtorExpStatement isDtorExpStatement()
    {
        return this;
    }
}

extern (C++) final class CompileStatement : Statement
{
public:
    Expression exp;

    /******************************** CompileStatement ***************************/
    extern (D) this(Loc loc, Expression exp)
    {
        super(loc);
        this.exp = exp;
    }

    Statement syntaxCopy()
    {
        return new CompileStatement(loc, exp.syntaxCopy());
    }

    Statements* flatten(Scope* sc)
    {
        //printf("CompileStatement::flatten() %s\n", exp->toChars());
        sc = sc.startCTFE();
        exp = exp.semantic(sc);
        exp = resolveProperties(sc, exp);
        sc = sc.endCTFE();
        auto a = new Statements();
        if (exp.op != TOKerror)
        {
            Expression e = exp.ctfeInterpret();
            StringExp se = e.toStringExp();
            if (!se)
                error("argument to mixin must be a string, not (%s) of type %s", exp.toChars(), exp.type.toChars());
            else
            {
                se = se.toUTF8(sc);
                uint errors = global.errors;
                scope Parser p = new Parser(loc, sc._module, cast(char*)se.string, se.len, 0);
                p.nextToken();
                while (p.token.value != TOKeof)
                {
                    Statement s = p.parseStatement(PSsemi | PScurlyscope);
                    if (!s || p.errors)
                    {
                        assert(!p.errors || global.errors != errors); // make sure we caught all the cases
                        goto Lerror;
                    }
                    a.push(s);
                }
                return a;
            }
        }
    Lerror:
        a.push(new ErrorStatement());
        return a;
    }

    Statement semantic(Scope* sc)
    {
        //printf("CompileStatement::semantic() %s\n", exp->toChars());
        Statements* a = flatten(sc);
        if (!a)
            return null;
        Statement s = new CompoundStatement(loc, a);
        return s.semantic(sc);
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

extern (C++) class CompoundStatement : Statement
{
public:
    Statements* statements;

    /******************************** CompoundStatement ***************************/
    final extern (D) this(Loc loc, Statements* s)
    {
        super(loc);
        statements = s;
    }

    final extern (D) this(Loc loc, Statement s1)
    {
        super(loc);
        statements = new Statements();
        statements.push(s1);
    }

    final extern (D) this(Loc loc, Statement s1, Statement s2)
    {
        super(loc);
        statements = new Statements();
        statements.reserve(2);
        statements.push(s1);
        statements.push(s2);
    }

    final static CompoundStatement create(Loc loc, Statement s1, Statement s2)
    {
        return new CompoundStatement(loc, s1, s2);
    }

    Statement syntaxCopy()
    {
        auto a = new Statements();
        a.setDim(statements.dim);
        for (size_t i = 0; i < statements.dim; i++)
        {
            Statement s = (*statements)[i];
            (*a)[i] = s ? s.syntaxCopy() : null;
        }
        return new CompoundStatement(loc, a);
    }

    Statement semantic(Scope* sc)
    {
        //printf("CompoundStatement::semantic(this = %p, sc = %p)\n", this, sc);
        version (none)
        {
            for (size_t i = 0; i < statements.dim; i++)
            {
                Statement s = (*statements)[i];
                if (s)
                    printf("[%d]: %s", i, s.toChars());
            }
        }
        for (size_t i = 0; i < statements.dim;)
        {
            Statement s = (*statements)[i];
            if (s)
            {
                Statements* flt = s.flatten(sc);
                if (flt)
                {
                    statements.remove(i);
                    statements.insert(i, flt);
                    continue;
                }
                s = s.semantic(sc);
                (*statements)[i] = s;
                if (s)
                {
                    Statement sentry;
                    Statement sexception;
                    Statement sfinally;
                    (*statements)[i] = s.scopeCode(sc, &sentry, &sexception, &sfinally);
                    if (sentry)
                    {
                        sentry = sentry.semantic(sc);
                        statements.insert(i, sentry);
                        i++;
                    }
                    if (sexception)
                        sexception = sexception.semantic(sc);
                    if (sexception)
                    {
                        if (i + 1 == statements.dim && !sfinally)
                        {
                        }
                        else
                        {
                            /* Rewrite:
                             *      s; s1; s2;
                             * As:
                             *      s;
                             *      try { s1; s2; }
                             *      catch (Throwable __o)
                             *      { sexception; throw __o; }
                             */
                            auto a = new Statements();
                            for (size_t j = i + 1; j < statements.dim; j++)
                            {
                                a.push((*statements)[j]);
                            }
                            Statement _body = new CompoundStatement(Loc(), a);
                            _body = new ScopeStatement(Loc(), _body);
                            Identifier id = Identifier.generateId("__o");
                            Statement handler = new PeelStatement(sexception);
                            if (sexception.blockExit(sc.func, false) & BEfallthru)
                            {
                                auto ts = new ThrowStatement(Loc(), new IdentifierExp(Loc(), id));
                                ts.internalThrow = true;
                                handler = new CompoundStatement(Loc(), handler, ts);
                            }
                            auto catches = new Catches();
                            auto ctch = new Catch(Loc(), null, id, handler);
                            ctch.internalCatch = true;
                            catches.push(ctch);
                            s = new TryCatchStatement(Loc(), _body, catches);
                            if (sfinally)
                                s = new TryFinallyStatement(Loc(), s, sfinally);
                            s = s.semantic(sc);
                            statements.setDim(i + 1);
                            statements.push(s);
                            break;
                        }
                    }
                    else if (sfinally)
                    {
                        if (0 && i + 1 == statements.dim)
                        {
                            statements.push(sfinally);
                        }
                        else
                        {
                            /* Rewrite:
                             *      s; s1; s2;
                             * As:
                             *      s; try { s1; s2; } finally { sfinally; }
                             */
                            auto a = new Statements();
                            for (size_t j = i + 1; j < statements.dim; j++)
                            {
                                a.push((*statements)[j]);
                            }
                            Statement _body = new CompoundStatement(Loc(), a);
                            s = new TryFinallyStatement(Loc(), _body, sfinally);
                            s = s.semantic(sc);
                            statements.setDim(i + 1);
                            statements.push(s);
                            break;
                        }
                    }
                }
                else
                {
                    /* Remove NULL statements from the list.
                     */
                    statements.remove(i);
                    continue;
                }
            }
            i++;
        }
        for (size_t i = 0; i < statements.dim; ++i)
        {
        Lagain:
            Statement s = (*statements)[i];
            if (!s)
                continue;
            Statement se = s.isErrorStatement();
            if (se)
                return se;
            /* Bugzilla 11653: 'semantic' may return another CompoundStatement
             * (eg. CaseRangeStatement), so flatten it here.
             */
            Statements* flt = s.flatten(sc);
            if (flt)
            {
                statements.remove(i);
                statements.insert(i, flt);
                if (statements.dim <= i)
                    break;
                goto Lagain;
            }
        }
        if (statements.dim == 1)
        {
            return (*statements)[0];
        }
        return this;
    }

    Statements* flatten(Scope* sc)
    {
        return statements;
    }

    final ReturnStatement isReturnStatement()
    {
        ReturnStatement rs = null;
        for (size_t i = 0; i < statements.dim; i++)
        {
            Statement s = (*statements)[i];
            if (s)
            {
                rs = s.isReturnStatement();
                if (rs)
                    break;
            }
        }
        return rs;
    }

    final Statement last()
    {
        Statement s = null;
        for (size_t i = statements.dim; i; --i)
        {
            s = (*statements)[i - 1];
            if (s)
            {
                s = s.last();
                if (s)
                    break;
            }
        }
        return s;
    }

    final CompoundStatement isCompoundStatement()
    {
        return this;
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

extern (C++) final class CompoundDeclarationStatement : CompoundStatement
{
public:
    /******************************** CompoundDeclarationStatement ***************************/
    extern (D) this(Loc loc, Statements* s)
    {
        super(loc, s);
        statements = s;
    }

    Statement syntaxCopy()
    {
        auto a = new Statements();
        a.setDim(statements.dim);
        for (size_t i = 0; i < statements.dim; i++)
        {
            Statement s = (*statements)[i];
            (*a)[i] = s ? s.syntaxCopy() : null;
        }
        return new CompoundDeclarationStatement(loc, a);
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

/* The purpose of this is so that continue will go to the next
 * of the statements, and break will go to the end of the statements.
 */
extern (C++) final class UnrolledLoopStatement : Statement
{
public:
    Statements* statements;

    /**************************** UnrolledLoopStatement ***************************/
    extern (D) this(Loc loc, Statements* s)
    {
        super(loc);
        statements = s;
    }

    Statement syntaxCopy()
    {
        auto a = new Statements();
        a.setDim(statements.dim);
        for (size_t i = 0; i < statements.dim; i++)
        {
            Statement s = (*statements)[i];
            (*a)[i] = s ? s.syntaxCopy() : null;
        }
        return new UnrolledLoopStatement(loc, a);
    }

    Statement semantic(Scope* sc)
    {
        //printf("UnrolledLoopStatement::semantic(this = %p, sc = %p)\n", this, sc);
        Scope* scd = sc.push();
        scd.sbreak = this;
        scd.scontinue = this;
        Statement serror = null;
        for (size_t i = 0; i < statements.dim; i++)
        {
            Statement s = (*statements)[i];
            if (s)
            {
                //printf("[%d]: %s\n", i, s->toChars());
                s = s.semantic(scd);
                (*statements)[i] = s;
                if (s && !serror)
                    serror = s.isErrorStatement();
            }
        }
        scd.pop();
        return serror ? serror : this;
    }

    bool hasBreak()
    {
        return true;
    }

    bool hasContinue()
    {
        return true;
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

extern (C++) final class ScopeStatement : Statement
{
public:
    Statement statement;

    /******************************** ScopeStatement ***************************/
    extern (D) this(Loc loc, Statement s)
    {
        super(loc);
        this.statement = s;
    }

    Statement syntaxCopy()
    {
        return new ScopeStatement(loc, statement ? statement.syntaxCopy() : null);
    }

    ScopeStatement isScopeStatement()
    {
        return this;
    }

    ReturnStatement isReturnStatement()
    {
        if (statement)
            return statement.isReturnStatement();
        return null;
    }

    Statement semantic(Scope* sc)
    {
        ScopeDsymbol sym;
        //printf("ScopeStatement::semantic(sc = %p)\n", sc);
        if (statement)
        {
            sym = new ScopeDsymbol();
            sym.parent = sc.scopesym;
            sc = sc.push(sym);
            Statements* a = statement.flatten(sc);
            if (a)
            {
                statement = new CompoundStatement(loc, a);
            }
            statement = statement.semantic(sc);
            if (statement)
            {
                if (statement.isErrorStatement())
                {
                    sc.pop();
                    return statement;
                }
                Statement sentry;
                Statement sexception;
                Statement sfinally;
                statement = statement.scopeCode(sc, &sentry, &sexception, &sfinally);
                assert(!sentry);
                assert(!sexception);
                if (sfinally)
                {
                    //printf("adding sfinally\n");
                    sfinally = sfinally.semantic(sc);
                    statement = new CompoundStatement(loc, statement, sfinally);
                }
            }
            sc.pop();
        }
        return this;
    }

    bool hasBreak()
    {
        //printf("ScopeStatement::hasBreak() %s\n", toChars());
        return statement ? statement.hasBreak() : false;
    }

    bool hasContinue()
    {
        return statement ? statement.hasContinue() : false;
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

extern (C++) final class WhileStatement : Statement
{
public:
    Expression condition;
    Statement _body;
    Loc endloc; // location of closing curly bracket

    /******************************** WhileStatement ***************************/
    extern (D) this(Loc loc, Expression c, Statement b, Loc endloc)
    {
        super(loc);
        condition = c;
        _body = b;
        this.endloc = endloc;
    }

    Statement syntaxCopy()
    {
        return new WhileStatement(loc, condition.syntaxCopy(), _body ? _body.syntaxCopy() : null, endloc);
    }

    Statement semantic(Scope* sc)
    {
        /* Rewrite as a for(;condition;) loop
         */
        Statement s = new ForStatement(loc, null, condition, null, _body, endloc);
        s = s.semantic(sc);
        return s;
    }

    bool hasBreak()
    {
        return true;
    }

    bool hasContinue()
    {
        return true;
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

extern (C++) final class DoStatement : Statement
{
public:
    Statement _body;
    Expression condition;

    /******************************** DoStatement ***************************/
    extern (D) this(Loc loc, Statement b, Expression c)
    {
        super(loc);
        _body = b;
        condition = c;
    }

    Statement syntaxCopy()
    {
        return new DoStatement(loc, _body ? _body.syntaxCopy() : null, condition.syntaxCopy());
    }

    Statement semantic(Scope* sc)
    {
        sc.noctor++;
        if (_body)
            _body = _body.semanticScope(sc, this, this);
        sc.noctor--;
        condition = condition.semantic(sc);
        condition = resolveProperties(sc, condition);
        condition = condition.optimize(WANTvalue);
        condition = checkGC(sc, condition);
        condition = condition.toBoolean(sc);
        if (condition.op == TOKerror)
            return new ErrorStatement();
        if (_body && _body.isErrorStatement())
            return _body;
        return this;
    }

    bool hasBreak()
    {
        return true;
    }

    bool hasContinue()
    {
        return true;
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

extern (C++) final class ForStatement : Statement
{
public:
    Statement _init;
    Expression condition;
    Expression increment;
    Statement _body;
    Loc endloc; // location of closing curly bracket
    // When wrapped in try/finally clauses, this points to the outermost one,
    // which may have an associated label. Internal break/continue statements
    // treat that label as referring to this loop.
    Statement relatedLabeled;

    /******************************** ForStatement ***************************/
    extern (D) this(Loc loc, Statement _init, Expression condition, Expression increment, Statement _body, Loc endloc)
    {
        super(loc);
        this._init = _init;
        this.condition = condition;
        this.increment = increment;
        this._body = _body;
        this.endloc = endloc;
        this.relatedLabeled = null;
    }

    Statement syntaxCopy()
    {
        return new ForStatement(loc, _init ? _init.syntaxCopy() : null, condition ? condition.syntaxCopy() : null, increment ? increment.syntaxCopy() : null, _body.syntaxCopy(), endloc);
    }

    Statement semantic(Scope* sc)
    {
        //printf("ForStatement::semantic %s\n", toChars());
        if (_init)
        {
            /* Rewrite:
             *  for (auto v1 = i1, v2 = i2; condition; increment) { ... }
             * to:
             *  { auto v1 = i1, v2 = i2; for (; condition; increment) { ... } }
             * then lowered to:
             *  auto v1 = i1;
             *  try {
             *    auto v2 = i2;
             *    try {
             *      for (; condition; increment) { ... }
             *    } finally { v2.~this(); }
             *  } finally { v1.~this(); }
             */
            auto ainit = new Statements();
            ainit.push(_init), _init = null;
            ainit.push(this);
            Statement s = new CompoundStatement(loc, ainit);
            s = new ScopeStatement(loc, s);
            s = s.semantic(sc);
            if (!s.isErrorStatement())
            {
                if (LabelStatement ls = checkLabeledLoop(sc, this))
                    ls.gotoTarget = this;
                relatedLabeled = s;
            }
            return s;
        }
        assert(_init is null);
        auto sym = new ScopeDsymbol();
        sym.parent = sc.scopesym;
        sc = sc.push(sym);
        sc.noctor++;
        if (condition)
        {
            condition = condition.semantic(sc);
            condition = resolveProperties(sc, condition);
            condition = condition.optimize(WANTvalue);
            condition = checkGC(sc, condition);
            condition = condition.toBoolean(sc);
        }
        if (increment)
        {
            increment = increment.semantic(sc);
            increment = resolveProperties(sc, increment);
            increment = increment.optimize(WANTvalue);
            increment = checkGC(sc, increment);
        }
        sc.sbreak = this;
        sc.scontinue = this;
        if (_body)
            _body = _body.semanticNoScope(sc);
        sc.noctor--;
        sc.pop();
        if (condition && condition.op == TOKerror || increment && increment.op == TOKerror || _body && _body.isErrorStatement())
            return new ErrorStatement();
        return this;
    }

    Statement scopeCode(Scope* sc, Statement* sentry, Statement* sexception, Statement* sfinally)
    {
        //printf("ForStatement::scopeCode()\n");
        Statement.scopeCode(sc, sentry, sexception, sfinally);
        return this;
    }

    Statement getRelatedLabeled()
    {
        return relatedLabeled ? relatedLabeled : this;
    }

    bool hasBreak()
    {
        //printf("ForStatement::hasBreak()\n");
        return true;
    }

    bool hasContinue()
    {
        return true;
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

extern (C++) final class ForeachStatement : Statement
{
public:
    TOK op; // TOKforeach or TOKforeach_reverse
    Parameters* parameters; // array of Parameter*'s
    Expression aggr;
    Statement _body;
    Loc endloc; // location of closing curly bracket
    VarDeclaration key;
    VarDeclaration value;
    FuncDeclaration func; // function we're lexically in
    Statements* cases; // put breaks, continues, gotos and returns here
    ScopeStatements* gotos; // forward referenced goto's go here

    /******************************** ForeachStatement ***************************/
    extern (D) this(Loc loc, TOK op, Parameters* parameters, Expression aggr, Statement _body, Loc endloc)
    {
        super(loc);
        this.op = op;
        this.parameters = parameters;
        this.aggr = aggr;
        this._body = _body;
        this.endloc = endloc;
        this.key = null;
        this.value = null;
        this.func = null;
        this.cases = null;
        this.gotos = null;
    }

    Statement syntaxCopy()
    {
        return new ForeachStatement(loc, op, Parameter.arraySyntaxCopy(parameters), aggr.syntaxCopy(), _body ? _body.syntaxCopy() : null, endloc);
    }

    Statement semantic(Scope* sc)
    {
        //printf("ForeachStatement::semantic() %p\n", this);
        ScopeDsymbol sym;
        Statement s = this;
        size_t dim = parameters.dim;
        TypeAArray taa = null;
        Dsymbol sapply = null;
        Type tn = null;
        Type tnv = null;
        func = sc.func;
        if (func.fes)
            func = func.fes.func;
        VarDeclaration vinit = null;
        aggr = aggr.semantic(sc);
        aggr = resolveProperties(sc, aggr);
        aggr = aggr.optimize(WANTvalue);
        if (aggr.op == TOKerror)
            return new ErrorStatement();
        Expression oaggr = aggr;
        if (aggr.type && aggr.type.toBasetype().ty == Tstruct && aggr.op != TOKtype && !aggr.isLvalue())
        {
            // Bugzilla 14653: Extend the life of rvalue aggregate till the end of foreach.
            vinit = new VarDeclaration(loc, aggr.type, Identifier.generateId("__aggr"), new ExpInitializer(loc, aggr));
            vinit.storage_class |= STCtemp;
            vinit.semantic(sc);
            aggr = new VarExp(aggr.loc, vinit);
        }
        if (!inferAggregate(this, sc, sapply))
        {
            const(char)* msg = "";
            if (aggr.type && isAggregate(aggr.type))
            {
                msg = ", define opApply(), range primitives, or use .tupleof";
            }
            error("invalid foreach aggregate %s%s", oaggr.toChars(), msg);
            return new ErrorStatement();
        }
        Dsymbol sapplyOld = sapply; // 'sapply' will be NULL if and after 'inferApplyArgTypes' errors
        /* Check for inference errors
         */
        if (!inferApplyArgTypes(this, sc, sapply))
        {
            /**
             Try and extract the parameter count of the opApply callback function, e.g.:
             int opApply(int delegate(int, float)) => 2 args
             */
            bool foundMismatch = false;
            size_t foreachParamCount = 0;
            if (sapplyOld)
            {
                if (FuncDeclaration fd = sapplyOld.isFuncDeclaration())
                {
                    int fvarargs; // ignored (opApply shouldn't take variadics)
                    Parameters* fparameters = fd.getParameters(&fvarargs);
                    if (Parameter.dim(fparameters) == 1)
                    {
                        // first param should be the callback function
                        Parameter fparam = Parameter.getNth(fparameters, 0);
                        if ((fparam.type.ty == Tpointer || fparam.type.ty == Tdelegate) && fparam.type.nextOf().ty == Tfunction)
                        {
                            TypeFunction tf = cast(TypeFunction)fparam.type.nextOf();
                            foreachParamCount = Parameter.dim(tf.parameters);
                            foundMismatch = true;
                        }
                    }
                }
            }
            //printf("dim = %d, parameters->dim = %d\n", dim, parameters->dim);
            if (foundMismatch && dim != foreachParamCount)
            {
                const(char)* plural = foreachParamCount > 1 ? "s" : "";
                error("cannot infer argument types, expected %d argument%s, not %d", foreachParamCount, plural, dim);
            }
            else
                error("cannot uniquely infer foreach argument types");
            return new ErrorStatement();
        }
        Type tab = aggr.type.toBasetype();
        if (tab.ty == Ttuple) // don't generate new scope for tuple loops
        {
            if (dim < 1 || dim > 2)
            {
                error("only one (value) or two (key,value) arguments for tuple foreach");
                return new ErrorStatement();
            }
            Type paramtype = (*parameters)[dim - 1].type;
            if (paramtype)
            {
                paramtype = paramtype.semantic(loc, sc);
                if (paramtype.ty == Terror)
                    return new ErrorStatement();
            }
            TypeTuple tuple = cast(TypeTuple)tab;
            auto statements = new Statements();
            //printf("aggr: op = %d, %s\n", aggr->op, aggr->toChars());
            size_t n;
            TupleExp te = null;
            if (aggr.op == TOKtuple) // expression tuple
            {
                te = cast(TupleExp)aggr;
                n = te.exps.dim;
            }
            else if (aggr.op == TOKtype) // type tuple
            {
                n = Parameter.dim(tuple.arguments);
            }
            else
                assert(0);
            for (size_t j = 0; j < n; j++)
            {
                size_t k = (op == TOKforeach) ? j : n - 1 - j;
                Expression e = null;
                Type t = null;
                if (te)
                    e = (*te.exps)[k];
                else
                    t = Parameter.getNth(tuple.arguments, k).type;
                Parameter p = (*parameters)[0];
                auto st = new Statements();
                if (dim == 2)
                {
                    // Declare key
                    if (p.storageClass & (STCout | STCref | STClazy))
                    {
                        error("no storage class for key %s", p.ident.toChars());
                        return new ErrorStatement();
                    }
                    p.type = p.type.semantic(loc, sc);
                    TY keyty = p.type.ty;
                    if (keyty != Tint32 && keyty != Tuns32)
                    {
                        if (global.params.isLP64)
                        {
                            if (keyty != Tint64 && keyty != Tuns64)
                            {
                                error("foreach: key type must be int or uint, long or ulong, not %s", p.type.toChars());
                                return new ErrorStatement();
                            }
                        }
                        else
                        {
                            error("foreach: key type must be int or uint, not %s", p.type.toChars());
                            return new ErrorStatement();
                        }
                    }
                    Initializer ie = new ExpInitializer(Loc(), new IntegerExp(k));
                    auto var = new VarDeclaration(loc, p.type, p.ident, ie);
                    var.storage_class |= STCmanifest;
                    st.push(new ExpStatement(loc, var));
                    p = (*parameters)[1]; // value
                }
                // Declare value
                if (p.storageClass & (STCout | STClazy) || p.storageClass & STCref && !te)
                {
                    error("no storage class for value %s", p.ident.toChars());
                    return new ErrorStatement();
                }
                Dsymbol var;
                if (te)
                {
                    Type tb = e.type.toBasetype();
                    Dsymbol ds = null;
                    if ((tb.ty == Tfunction || tb.ty == Tsarray) && e.op == TOKvar)
                        ds = (cast(VarExp)e).var;
                    else if (e.op == TOKtemplate)
                        ds = (cast(TemplateExp)e).td;
                    else if (e.op == TOKimport)
                        ds = (cast(ScopeExp)e).sds;
                    else if (e.op == TOKfunction)
                    {
                        FuncExp fe = cast(FuncExp)e;
                        ds = fe.td ? cast(Dsymbol)fe.td : fe.fd;
                    }
                    if (ds)
                    {
                        var = new AliasDeclaration(loc, p.ident, ds);
                        if (p.storageClass & STCref)
                        {
                            error("symbol %s cannot be ref", s.toChars());
                            return new ErrorStatement();
                        }
                        if (paramtype)
                        {
                            error("cannot specify element type for symbol %s", ds.toChars());
                            return new ErrorStatement();
                        }
                    }
                    else if (e.op == TOKtype)
                    {
                        var = new AliasDeclaration(loc, p.ident, e.type);
                        if (paramtype)
                        {
                            error("cannot specify element type for type %s", e.type.toChars());
                            return new ErrorStatement();
                        }
                    }
                    else
                    {
                        p.type = e.type;
                        if (paramtype)
                            p.type = paramtype;
                        Initializer ie = new ExpInitializer(Loc(), e);
                        auto v = new VarDeclaration(loc, p.type, p.ident, ie);
                        if (p.storageClass & STCref)
                            v.storage_class |= STCref | STCforeach;
                        if (e.isConst() || e.op == TOKstring || e.op == TOKstructliteral || e.op == TOKarrayliteral)
                        {
                            if (v.storage_class & STCref)
                            {
                                error("constant value %s cannot be ref", ie.toChars());
                                return new ErrorStatement();
                            }
                            else
                                v.storage_class |= STCmanifest;
                        }
                        var = v;
                    }
                }
                else
                {
                    var = new AliasDeclaration(loc, p.ident, t);
                    if (paramtype)
                    {
                        error("cannot specify element type for symbol %s", s.toChars());
                        return new ErrorStatement();
                    }
                }
                st.push(new ExpStatement(loc, var));
                st.push(_body.syntaxCopy());
                s = new CompoundStatement(loc, st);
                s = new ScopeStatement(loc, s);
                statements.push(s);
            }
            s = new UnrolledLoopStatement(loc, statements);
            if (LabelStatement ls = checkLabeledLoop(sc, this))
                ls.gotoTarget = s;
            if (te && te.e0)
                s = new CompoundStatement(loc, new ExpStatement(te.e0.loc, te.e0), s);
            if (vinit)
                s = new CompoundStatement(loc, new ExpStatement(loc, vinit), s);
            s = s.semantic(sc);
            return s;
        }
        sym = new ScopeDsymbol();
        sym.parent = sc.scopesym;
        sc = sc.push(sym);
        sc.noctor++;
        switch (tab.ty)
        {
        case Tarray:
        case Tsarray:
            {
                if (checkForArgTypes())
                    return this;
                if (dim < 1 || dim > 2)
                {
                    error("only one or two arguments for array foreach");
                    goto Lerror2;
                }
                /* Look for special case of parsing char types out of char type
                 * array.
                 */
                tn = tab.nextOf().toBasetype();
                if (tn.ty == Tchar || tn.ty == Twchar || tn.ty == Tdchar)
                {
                    int i = (dim == 1) ? 0 : 1; // index of value
                    Parameter p = (*parameters)[i];
                    p.type = p.type.semantic(loc, sc);
                    p.type = p.type.addStorageClass(p.storageClass);
                    tnv = p.type.toBasetype();
                    if (tnv.ty != tn.ty && (tnv.ty == Tchar || tnv.ty == Twchar || tnv.ty == Tdchar))
                    {
                        if (p.storageClass & STCref)
                        {
                            error("foreach: value of UTF conversion cannot be ref");
                            goto Lerror2;
                        }
                        if (dim == 2)
                        {
                            p = (*parameters)[0];
                            if (p.storageClass & STCref)
                            {
                                error("foreach: key cannot be ref");
                                goto Lerror2;
                            }
                        }
                        goto Lapply;
                    }
                }
                for (size_t i = 0; i < dim; i++)
                {
                    // Declare parameterss
                    Parameter p = (*parameters)[i];
                    p.type = p.type.semantic(loc, sc);
                    p.type = p.type.addStorageClass(p.storageClass);
                    VarDeclaration var;
                    if (dim == 2 && i == 0)
                    {
                        var = new VarDeclaration(loc, p.type.mutableOf(), Identifier.generateId("__key"), null);
                        var.storage_class |= STCtemp | STCforeach;
                        if (var.storage_class & (STCref | STCout))
                            var.storage_class |= STCnodtor;
                        key = var;
                        if (p.storageClass & STCref)
                        {
                            if (var.type.constConv(p.type) <= MATCHnomatch)
                            {
                                error("key type mismatch, %s to ref %s", var.type.toChars(), p.type.toChars());
                                goto Lerror2;
                            }
                        }
                        if (tab.ty == Tsarray)
                        {
                            TypeSArray ta = cast(TypeSArray)tab;
                            IntRange dimrange = getIntRange(ta.dim);
                            if (!IntRange.fromType(var.type).contains(dimrange))
                            {
                                error("index type '%s' cannot cover index range 0..%llu", p.type.toChars(), ta.dim.toInteger());
                                goto Lerror2;
                            }
                            key.range = new IntRange(SignExtendedNumber(0), dimrange.imax);
                        }
                    }
                    else
                    {
                        var = new VarDeclaration(loc, p.type, p.ident, null);
                        var.storage_class |= STCforeach;
                        var.storage_class |= p.storageClass & (STCin | STCout | STCref | STC_TYPECTOR);
                        if (var.storage_class & (STCref | STCout))
                            var.storage_class |= STCnodtor;
                        value = var;
                        if (var.storage_class & STCref)
                        {
                            if (aggr.checkModifiable(sc, 1) == 2)
                                var.storage_class |= STCctorinit;
                            Type t = tab.nextOf();
                            if (t.constConv(p.type) <= MATCHnomatch)
                            {
                                error("argument type mismatch, %s to ref %s", t.toChars(), p.type.toChars());
                                goto Lerror2;
                            }
                        }
                    }
                }
                /* Convert to a ForStatement
                 *   foreach (key, value; a) body =>
                 *   for (T[] tmp = a[], size_t key; key < tmp.length; ++key)
                 *   { T value = tmp[k]; body }
                 *
                 *   foreach_reverse (key, value; a) body =>
                 *   for (T[] tmp = a[], size_t key = tmp.length; key--; )
                 *   { T value = tmp[k]; body }
                 */
                Identifier id = Identifier.generateId("__r");
                auto ie = new ExpInitializer(loc, new SliceExp(loc, aggr, null, null));
                VarDeclaration tmp;
                if (aggr.op == TOKarrayliteral && !((*parameters)[dim - 1].storageClass & STCref))
                {
                    ArrayLiteralExp ale = cast(ArrayLiteralExp)aggr;
                    size_t edim = ale.elements ? ale.elements.dim : 0;
                    aggr.type = tab.nextOf().sarrayOf(edim);
                    // for (T[edim] tmp = a, ...)
                    tmp = new VarDeclaration(loc, aggr.type, id, ie);
                }
                else
                    tmp = new VarDeclaration(loc, tab.nextOf().arrayOf(), id, ie);
                tmp.storage_class |= STCtemp;
                Expression tmp_length = new DotIdExp(loc, new VarExp(loc, tmp), Id.length);
                if (!key)
                {
                    Identifier idkey = Identifier.generateId("__key");
                    key = new VarDeclaration(loc, Type.tsize_t, idkey, null);
                    key.storage_class |= STCtemp;
                }
                if (op == TOKforeach_reverse)
                    key._init = new ExpInitializer(loc, tmp_length);
                else
                    key._init = new ExpInitializer(loc, new IntegerExp(loc, 0, key.type));
                auto cs = new Statements();
                if (vinit)
                    cs.push(new ExpStatement(loc, vinit));
                cs.push(new ExpStatement(loc, tmp));
                cs.push(new ExpStatement(loc, key));
                Statement forinit = new CompoundDeclarationStatement(loc, cs);
                Expression cond;
                if (op == TOKforeach_reverse)
                {
                    // key--
                    cond = new PostExp(TOKminusminus, loc, new VarExp(loc, key));
                }
                else
                {
                    // key < tmp.length
                    cond = new CmpExp(TOKlt, loc, new VarExp(loc, key), tmp_length);
                }
                Expression increment = null;
                if (op == TOKforeach)
                {
                    // key += 1
                    increment = new AddAssignExp(loc, new VarExp(loc, key), new IntegerExp(loc, 1, key.type));
                }
                // T value = tmp[key];
                value._init = new ExpInitializer(loc, new IndexExp(loc, new VarExp(loc, tmp), new VarExp(loc, key)));
                Statement ds = new ExpStatement(loc, value);
                if (dim == 2)
                {
                    Parameter p = (*parameters)[0];
                    if ((p.storageClass & STCref) && p.type.equals(key.type))
                    {
                        key.range = null;
                        auto v = new AliasDeclaration(loc, p.ident, key);
                        _body = new CompoundStatement(loc, new ExpStatement(loc, v), _body);
                    }
                    else
                    {
                        auto ei = new ExpInitializer(loc, new IdentifierExp(loc, key.ident));
                        auto v = new VarDeclaration(loc, p.type, p.ident, ei);
                        v.storage_class |= STCforeach | (p.storageClass & STCref);
                        _body = new CompoundStatement(loc, new ExpStatement(loc, v), _body);
                        if (key.range && !p.type.isMutable())
                        {
                            /* Limit the range of the key to the specified range
                             */
                            v.range = new IntRange(key.range.imin, key.range.imax - SignExtendedNumber(1));
                        }
                    }
                }
                _body = new CompoundStatement(loc, ds, _body);
                s = new ForStatement(loc, forinit, cond, increment, _body, endloc);
                if (LabelStatement ls = checkLabeledLoop(sc, this))
                    ls.gotoTarget = s;
                s = s.semantic(sc);
                break;
            }
        case Taarray:
            if (op == TOKforeach_reverse)
                warning("cannot use foreach_reverse with an associative array");
            if (checkForArgTypes())
                return this;
            taa = cast(TypeAArray)tab;
            if (dim < 1 || dim > 2)
            {
                error("only one or two arguments for associative array foreach");
                goto Lerror2;
            }
            goto Lapply;
        case Tclass:
        case Tstruct:
            /* Prefer using opApply, if it exists
             */
            if (sapply)
                goto Lapply;
            {
                /* Look for range iteration, i.e. the properties
                 * .empty, .popFront, .popBack, .front and .back
                 *    foreach (e; aggr) { ... }
                 * translates to:
                 *    for (auto __r = aggr[]; !__r.empty; __r.popFront()) {
                 *        auto e = __r.front;
                 *        ...
                 *    }
                 */
                AggregateDeclaration ad = (tab.ty == Tclass) ? cast(AggregateDeclaration)(cast(TypeClass)tab).sym : cast(AggregateDeclaration)(cast(TypeStruct)tab).sym;
                Identifier idfront;
                Identifier idpopFront;
                if (op == TOKforeach)
                {
                    idfront = Id.Ffront;
                    idpopFront = Id.FpopFront;
                }
                else
                {
                    idfront = Id.Fback;
                    idpopFront = Id.FpopBack;
                }
                Dsymbol sfront = ad.search(Loc(), idfront);
                if (!sfront)
                    goto Lapply;
                /* Generate a temporary __r and initialize it with the aggregate.
                 */
                VarDeclaration r;
                Statement _init;
                if (vinit && aggr.op == TOKvar && (cast(VarExp)aggr).var == vinit)
                {
                    r = vinit;
                    _init = new ExpStatement(loc, vinit);
                }
                else
                {
                    Identifier rid = Identifier.generateId("__r");
                    r = new VarDeclaration(loc, null, rid, new ExpInitializer(loc, aggr));
                    r.storage_class |= STCtemp;
                    _init = new ExpStatement(loc, r);
                    if (vinit)
                        _init = new CompoundStatement(loc, new ExpStatement(loc, vinit), _init);
                }
                // !__r.empty
                Expression e = new VarExp(loc, r);
                e = new DotIdExp(loc, e, Id.Fempty);
                Expression condition = new NotExp(loc, e);
                // __r.idpopFront()
                e = new VarExp(loc, r);
                Expression increment = new CallExp(loc, new DotIdExp(loc, e, idpopFront));
                /* Declaration statement for e:
                 *    auto e = __r.idfront;
                 */
                e = new VarExp(loc, r);
                Expression einit = new DotIdExp(loc, e, idfront);
                Statement makeargs, forbody;
                if (dim == 1)
                {
                    Parameter p = (*parameters)[0];
                    auto ve = new VarDeclaration(loc, p.type, p.ident, new ExpInitializer(loc, einit));
                    ve.storage_class |= STCforeach;
                    ve.storage_class |= p.storageClass & (STCin | STCout | STCref | STC_TYPECTOR);
                    makeargs = new ExpStatement(loc, ve);
                }
                else
                {
                    Identifier id = Identifier.generateId("__front");
                    auto ei = new ExpInitializer(loc, einit);
                    auto vd = new VarDeclaration(loc, null, id, ei);
                    vd.storage_class |= STCtemp | STCctfe | STCref | STCforeach;
                    makeargs = new ExpStatement(loc, vd);
                    Declaration d = sfront.isDeclaration();
                    if (FuncDeclaration f = d.isFuncDeclaration())
                    {
                        if (!f.functionSemantic())
                            goto Lrangeerr;
                    }
                    Expression ve = new VarExp(loc, vd);
                    ve.type = d.type;
                    if (ve.type.toBasetype().ty == Tfunction)
                        ve.type = ve.type.toBasetype().nextOf();
                    if (!ve.type || ve.type.ty == Terror)
                        goto Lrangeerr;
                    // Resolve inout qualifier of front type
                    ve.type = ve.type.substWildTo(tab.mod);
                    auto exps = new Expressions();
                    exps.push(ve);
                    int pos = 0;
                    while (exps.dim < dim)
                    {
                        pos = expandAliasThisTuples(exps, pos);
                        if (pos == -1)
                            break;
                    }
                    if (exps.dim != dim)
                    {
                        const(char)* plural = exps.dim > 1 ? "s" : "";
                        error("cannot infer argument types, expected %d argument%s, not %d", exps.dim, plural, dim);
                        goto Lerror2;
                    }
                    for (size_t i = 0; i < dim; i++)
                    {
                        Parameter p = (*parameters)[i];
                        Expression exp = (*exps)[i];
                        version (none)
                        {
                            printf("[%d] p = %s %s, exp = %s %s\n", i, p.type ? p.type.toChars() : "?", p.ident.toChars(), exp.type.toChars(), exp.toChars());
                        }
                        if (!p.type)
                            p.type = exp.type;
                        p.type = p.type.addStorageClass(p.storageClass).semantic(loc, sc);
                        if (!exp.implicitConvTo(p.type))
                            goto Lrangeerr;
                        auto var = new VarDeclaration(loc, p.type, p.ident, new ExpInitializer(loc, exp));
                        var.storage_class |= STCctfe | STCref | STCforeach;
                        makeargs = new CompoundStatement(loc, makeargs, new ExpStatement(loc, var));
                    }
                }
                forbody = new CompoundStatement(loc, makeargs, this._body);
                s = new ForStatement(loc, _init, condition, increment, forbody, endloc);
                if (LabelStatement ls = checkLabeledLoop(sc, this))
                    ls.gotoTarget = s;
                version (none)
                {
                    printf("init: %s\n", _init.toChars());
                    printf("condition: %s\n", condition.toChars());
                    printf("increment: %s\n", increment.toChars());
                    printf("body: %s\n", forbody.toChars());
                }
                s = s.semantic(sc);
                break;
            Lrangeerr:
                error("cannot infer argument types");
                goto Lerror2;
            }
        case Tdelegate:
            if (op == TOKforeach_reverse)
                deprecation("cannot use foreach_reverse with a delegate");
        Lapply:
            {
                if (checkForArgTypes())
                {
                    _body = _body.semanticNoScope(sc);
                    return this;
                }
                TypeFunction tfld = null;
                if (sapply)
                {
                    FuncDeclaration fdapply = sapply.isFuncDeclaration();
                    if (fdapply)
                    {
                        assert(fdapply.type && fdapply.type.ty == Tfunction);
                        tfld = cast(TypeFunction)fdapply.type.semantic(loc, sc);
                        goto Lget;
                    }
                    else if (tab.ty == Tdelegate)
                    {
                        tfld = cast(TypeFunction)tab.nextOf();
                    Lget:
                        //printf("tfld = %s\n", tfld->toChars());
                        if (tfld.parameters.dim == 1)
                        {
                            Parameter p = Parameter.getNth(tfld.parameters, 0);
                            if (p.type && p.type.ty == Tdelegate)
                            {
                                Type t = p.type.semantic(loc, sc);
                                assert(t.ty == Tdelegate);
                                tfld = cast(TypeFunction)t.nextOf();
                            }
                        }
                    }
                }
                /* Turn body into the function literal:
                 *  int delegate(ref T param) { body }
                 */
                auto params = new Parameters();
                for (size_t i = 0; i < dim; i++)
                {
                    Parameter p = (*parameters)[i];
                    StorageClass stc = STCref;
                    Identifier id;
                    p.type = p.type.semantic(loc, sc);
                    p.type = p.type.addStorageClass(p.storageClass);
                    if (tfld)
                    {
                        Parameter prm = Parameter.getNth(tfld.parameters, i);
                        //printf("\tprm = %s%s\n", (prm->storageClass&STCref?"ref ":""), prm->ident->toChars());
                        stc = prm.storageClass & STCref;
                        id = p.ident; // argument copy is not need.
                        if ((p.storageClass & STCref) != stc)
                        {
                            if (!stc)
                            {
                                error("foreach: cannot make %s ref", p.ident.toChars());
                                goto Lerror2;
                            }
                            goto LcopyArg;
                        }
                    }
                    else if (p.storageClass & STCref)
                    {
                        // default delegate parameters are marked as ref, then
                        // argument copy is not need.
                        id = p.ident;
                    }
                    else
                    {
                        // Make a copy of the ref argument so it isn't
                        // a reference.
                    LcopyArg:
                        id = Identifier.generateId("__applyArg", cast(int)i);
                        Initializer ie = new ExpInitializer(Loc(), new IdentifierExp(Loc(), id));
                        auto v = new VarDeclaration(Loc(), p.type, p.ident, ie);
                        v.storage_class |= STCtemp;
                        s = new ExpStatement(Loc(), v);
                        _body = new CompoundStatement(loc, s, _body);
                    }
                    params.push(new Parameter(stc, p.type, id, null));
                }
                // Bugzilla 13840: Throwable nested function inside nothrow function is acceptable.
                StorageClass stc = mergeFuncAttrs(STCsafe | STCpure | STCnogc, func);
                tfld = new TypeFunction(params, Type.tint32, 0, LINKd, stc);
                cases = new Statements();
                gotos = new ScopeStatements();
                auto fld = new FuncLiteralDeclaration(loc, Loc(), tfld, TOKdelegate, this);
                fld.fbody = _body;
                Expression flde = new FuncExp(loc, fld);
                flde = flde.semantic(sc);
                fld.tookAddressOf = 0;
                // Resolve any forward referenced goto's
                for (size_t i = 0; i < gotos.dim; i++)
                {
                    GotoStatement gs = cast(GotoStatement)(*gotos)[i].statement;
                    if (!gs.label.statement)
                    {
                        // 'Promote' it to this scope, and replace with a return
                        cases.push(gs);
                        s = new ReturnStatement(Loc(), new IntegerExp(cases.dim + 1));
                        (*gotos)[i].statement = s;
                    }
                }
                Expression e = null;
                Expression ec;
                if (vinit)
                {
                    e = new DeclarationExp(loc, vinit);
                    e = e.semantic(sc);
                    if (e.op == TOKerror)
                        goto Lerror2;
                }
                if (taa)
                {
                    // Check types
                    Parameter p = (*parameters)[0];
                    bool isRef = (p.storageClass & STCref) != 0;
                    Type ta = p.type;
                    if (dim == 2)
                    {
                        Type ti = (isRef ? taa.index.addMod(MODconst) : taa.index);
                        if (isRef ? !ti.constConv(ta) : !ti.implicitConvTo(ta))
                        {
                            error("foreach: index must be type %s, not %s", ti.toChars(), ta.toChars());
                            goto Lerror2;
                        }
                        p = (*parameters)[1];
                        isRef = (p.storageClass & STCref) != 0;
                        ta = p.type;
                    }
                    Type taav = taa.nextOf();
                    if (isRef ? !taav.constConv(ta) : !taav.implicitConvTo(ta))
                    {
                        error("foreach: value must be type %s, not %s", taav.toChars(), ta.toChars());
                        goto Lerror2;
                    }
                    /* Call:
                     *  extern(C) int _aaApply(void*, in size_t, int delegate(void*))
                     *      _aaApply(aggr, keysize, flde)
                     *
                     *  extern(C) int _aaApply2(void*, in size_t, int delegate(void*, void*))
                     *      _aaApply2(aggr, keysize, flde)
                     */
                    static __gshared const(char)** name = ["_aaApply", "_aaApply2"];
                    static __gshared FuncDeclaration* fdapply = [null, null];
                    static __gshared TypeDelegate* fldeTy = [null, null];
                    ubyte i = (dim == 2 ? 1 : 0);
                    if (!fdapply[i])
                    {
                        params = new Parameters();
                        params.push(new Parameter(0, Type.tvoid.pointerTo(), null, null));
                        params.push(new Parameter(STCin, Type.tsize_t, null, null));
                        auto dgparams = new Parameters();
                        dgparams.push(new Parameter(0, Type.tvoidptr, null, null));
                        if (dim == 2)
                            dgparams.push(new Parameter(0, Type.tvoidptr, null, null));
                        fldeTy[i] = new TypeDelegate(new TypeFunction(dgparams, Type.tint32, 0, LINKd));
                        params.push(new Parameter(0, fldeTy[i], null, null));
                        fdapply[i] = FuncDeclaration.genCfunc(params, Type.tint32, name[i]);
                    }
                    auto exps = new Expressions();
                    exps.push(aggr);
                    size_t keysize = cast(size_t)taa.index.size();
                    keysize = (keysize + (cast(size_t)Target.ptrsize - 1)) & ~(cast(size_t)Target.ptrsize - 1);
                    // paint delegate argument to the type runtime expects
                    if (!fldeTy[i].equals(flde.type))
                    {
                        flde = new CastExp(loc, flde, flde.type);
                        flde.type = fldeTy[i];
                    }
                    exps.push(new IntegerExp(Loc(), keysize, Type.tsize_t));
                    exps.push(flde);
                    ec = new VarExp(Loc(), fdapply[i]);
                    ec = new CallExp(loc, ec, exps);
                    ec.type = Type.tint32; // don't run semantic() on ec
                }
                else if (tab.ty == Tarray || tab.ty == Tsarray)
                {
                    /* Call:
                     *      _aApply(aggr, flde)
                     */
                    static __gshared const(char)** fntab = ["cc", "cw", "cd", "wc", "cc", "wd", "dc", "dw", "dd"];
                    const(size_t) BUFFER_LEN = 7 + 1 + 2 + dim.sizeof * 3 + 1;
                    char[BUFFER_LEN] fdname;
                    int flag;
                    switch (tn.ty)
                    {
                    case Tchar:
                        flag = 0;
                        break;
                    case Twchar:
                        flag = 3;
                        break;
                    case Tdchar:
                        flag = 6;
                        break;
                    default:
                        assert(0);
                    }
                    switch (tnv.ty)
                    {
                    case Tchar:
                        flag += 0;
                        break;
                    case Twchar:
                        flag += 1;
                        break;
                    case Tdchar:
                        flag += 2;
                        break;
                    default:
                        assert(0);
                    }
                    const(char)* r = (op == TOKforeach_reverse) ? "R" : "";
                    int j = sprintf(fdname.ptr, "_aApply%s%.*s%llu", r, 2, fntab[flag], cast(ulong)dim);
                    assert(j < BUFFER_LEN);
                    FuncDeclaration fdapply;
                    TypeDelegate dgty;
                    params = new Parameters();
                    params.push(new Parameter(STCin, tn.arrayOf(), null, null));
                    auto dgparams = new Parameters();
                    dgparams.push(new Parameter(0, Type.tvoidptr, null, null));
                    if (dim == 2)
                        dgparams.push(new Parameter(0, Type.tvoidptr, null, null));
                    dgty = new TypeDelegate(new TypeFunction(dgparams, Type.tint32, 0, LINKd));
                    params.push(new Parameter(0, dgty, null, null));
                    fdapply = FuncDeclaration.genCfunc(params, Type.tint32, fdname.ptr);
                    if (tab.ty == Tsarray)
                        aggr = aggr.castTo(sc, tn.arrayOf());
                    // paint delegate argument to the type runtime expects
                    if (!dgty.equals(flde.type))
                    {
                        flde = new CastExp(loc, flde, flde.type);
                        flde.type = dgty;
                    }
                    ec = new VarExp(Loc(), fdapply);
                    ec = new CallExp(loc, ec, aggr, flde);
                    ec.type = Type.tint32; // don't run semantic() on ec
                }
                else if (tab.ty == Tdelegate)
                {
                    /* Call:
                     *      aggr(flde)
                     */
                    if (aggr.op == TOKdelegate && (cast(DelegateExp)aggr).func.isNested())
                    {
                        // See Bugzilla 3560
                        aggr = (cast(DelegateExp)aggr).e1;
                    }
                    ec = new CallExp(loc, aggr, flde);
                    ec = ec.semantic(sc);
                    if (ec.op == TOKerror)
                        goto Lerror2;
                    if (ec.type != Type.tint32)
                    {
                        error("opApply() function for %s must return an int", tab.toChars());
                        goto Lerror2;
                    }
                }
                else
                {
                    assert(tab.ty == Tstruct || tab.ty == Tclass);
                    assert(sapply);
                    /* Call:
                     *  aggr.apply(flde)
                     */
                    ec = new DotIdExp(loc, aggr, sapply.ident);
                    ec = new CallExp(loc, ec, flde);
                    ec = ec.semantic(sc);
                    if (ec.op == TOKerror)
                        goto Lerror2;
                    if (ec.type != Type.tint32)
                    {
                        error("opApply() function for %s must return an int", tab.toChars());
                        goto Lerror2;
                    }
                }
                e = Expression.combine(e, ec);
                if (!cases.dim)
                {
                    // Easy case, a clean exit from the loop
                    e = new CastExp(loc, e, Type.tvoid); // Bugzilla 13899
                    s = new ExpStatement(loc, e);
                }
                else
                {
                    // Construct a switch statement around the return value
                    // of the apply function.
                    auto a = new Statements();
                    // default: break; takes care of cases 0 and 1
                    s = new BreakStatement(Loc(), null);
                    s = new DefaultStatement(Loc(), s);
                    a.push(s);
                    // cases 2...
                    for (size_t i = 0; i < cases.dim; i++)
                    {
                        s = (*cases)[i];
                        s = new CaseStatement(Loc(), new IntegerExp(i + 2), s);
                        a.push(s);
                    }
                    s = new CompoundStatement(loc, a);
                    s = new SwitchStatement(loc, e, s, false);
                }
                s = s.semantic(sc);
                break;
            }
        case Terror:
        Lerror2:
            s = new ErrorStatement();
            break;
        default:
            error("foreach: %s is not an aggregate type", aggr.type.toChars());
            goto Lerror2;
        }
        sc.noctor--;
        sc.pop();
        return s;
    }

    bool checkForArgTypes()
    {
        bool result = false;
        for (size_t i = 0; i < parameters.dim; i++)
        {
            Parameter p = (*parameters)[i];
            if (!p.type)
            {
                error("cannot infer type for %s", p.ident.toChars());
                p.type = Type.terror;
                result = true;
            }
        }
        return result;
    }

    bool hasBreak()
    {
        return true;
    }

    bool hasContinue()
    {
        return true;
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

extern (C++) final class ForeachRangeStatement : Statement
{
public:
    TOK op; // TOKforeach or TOKforeach_reverse
    Parameter prm; // loop index variable
    Expression lwr;
    Expression upr;
    Statement _body;
    Loc endloc; // location of closing curly bracket
    VarDeclaration key;

    /**************************** ForeachRangeStatement ***************************/
    extern (D) this(Loc loc, TOK op, Parameter prm, Expression lwr, Expression upr, Statement _body, Loc endloc)
    {
        super(loc);
        this.op = op;
        this.prm = prm;
        this.lwr = lwr;
        this.upr = upr;
        this._body = _body;
        this.endloc = endloc;
        this.key = null;
    }

    Statement syntaxCopy()
    {
        return new ForeachRangeStatement(loc, op, prm.syntaxCopy(), lwr.syntaxCopy(), upr.syntaxCopy(), _body ? _body.syntaxCopy() : null, endloc);
    }

    Statement semantic(Scope* sc)
    {
        //printf("ForeachRangeStatement::semantic() %p\n", this);
        lwr = lwr.semantic(sc);
        lwr = resolveProperties(sc, lwr);
        lwr = lwr.optimize(WANTvalue);
        if (!lwr.type)
        {
            error("invalid range lower bound %s", lwr.toChars());
        Lerror:
            return new ErrorStatement();
        }
        upr = upr.semantic(sc);
        upr = resolveProperties(sc, upr);
        upr = upr.optimize(WANTvalue);
        if (!upr.type)
        {
            error("invalid range upper bound %s", upr.toChars());
            goto Lerror;
        }
        if (prm.type)
        {
            prm.type = prm.type.semantic(loc, sc);
            prm.type = prm.type.addStorageClass(prm.storageClass);
            lwr = lwr.implicitCastTo(sc, prm.type);
            if (upr.implicitConvTo(prm.type) || (prm.storageClass & STCref))
            {
                upr = upr.implicitCastTo(sc, prm.type);
            }
            else
            {
                // See if upr-1 fits in prm->type
                Expression limit = new MinExp(loc, upr, new IntegerExp(1));
                limit = limit.semantic(sc);
                limit = limit.optimize(WANTvalue);
                if (!limit.implicitConvTo(prm.type))
                {
                    upr = upr.implicitCastTo(sc, prm.type);
                }
            }
        }
        else
        {
            /* Must infer types from lwr and upr
             */
            Type tlwr = lwr.type.toBasetype();
            if (tlwr.ty == Tstruct || tlwr.ty == Tclass)
            {
                /* Just picking the first really isn't good enough.
                 */
                prm.type = lwr.type;
            }
            else if (lwr.type == upr.type)
            {
                /* Same logic as CondExp ?lwr:upr
                 */
                prm.type = lwr.type;
            }
            else
            {
                scope AddExp ea = new AddExp(loc, lwr, upr);
                if (typeCombine(ea, sc))
                    return new ErrorStatement();
                prm.type = ea.type;
                lwr = ea.e1;
                upr = ea.e2;
            }
            prm.type = prm.type.addStorageClass(prm.storageClass);
        }
        if (prm.type.ty == Terror || lwr.op == TOKerror || upr.op == TOKerror)
        {
            return new ErrorStatement();
        }
        /* Convert to a for loop:
         *  foreach (key; lwr .. upr) =>
         *  for (auto key = lwr, auto tmp = upr; key < tmp; ++key)
         *
         *  foreach_reverse (key; lwr .. upr) =>
         *  for (auto tmp = lwr, auto key = upr; key-- > tmp;)
         */
        auto ie = new ExpInitializer(loc, (op == TOKforeach) ? lwr : upr);
        key = new VarDeclaration(loc, upr.type.mutableOf(), Identifier.generateId("__key"), ie);
        key.storage_class |= STCtemp;
        SignExtendedNumber lower = getIntRange(lwr).imin;
        SignExtendedNumber upper = getIntRange(upr).imax;
        if (lower <= upper)
        {
            key.range = new IntRange(lower, upper);
        }
        Identifier id = Identifier.generateId("__limit");
        ie = new ExpInitializer(loc, (op == TOKforeach) ? upr : lwr);
        auto tmp = new VarDeclaration(loc, upr.type, id, ie);
        tmp.storage_class |= STCtemp;
        auto cs = new Statements();
        // Keep order of evaluation as lwr, then upr
        if (op == TOKforeach)
        {
            cs.push(new ExpStatement(loc, key));
            cs.push(new ExpStatement(loc, tmp));
        }
        else
        {
            cs.push(new ExpStatement(loc, tmp));
            cs.push(new ExpStatement(loc, key));
        }
        Statement forinit = new CompoundDeclarationStatement(loc, cs);
        Expression cond;
        if (op == TOKforeach_reverse)
        {
            cond = new PostExp(TOKminusminus, loc, new VarExp(loc, key));
            if (prm.type.isscalar())
            {
                // key-- > tmp
                cond = new CmpExp(TOKgt, loc, cond, new VarExp(loc, tmp));
            }
            else
            {
                // key-- != tmp
                cond = new EqualExp(TOKnotequal, loc, cond, new VarExp(loc, tmp));
            }
        }
        else
        {
            if (prm.type.isscalar())
            {
                // key < tmp
                cond = new CmpExp(TOKlt, loc, new VarExp(loc, key), new VarExp(loc, tmp));
            }
            else
            {
                // key != tmp
                cond = new EqualExp(TOKnotequal, loc, new VarExp(loc, key), new VarExp(loc, tmp));
            }
        }
        Expression increment = null;
        if (op == TOKforeach)
        {
            // key += 1
            //increment = new AddAssignExp(loc, new VarExp(loc, key), new IntegerExp(1));
            increment = new PreExp(TOKpreplusplus, loc, new VarExp(loc, key));
        }
        if ((prm.storageClass & STCref) && prm.type.equals(key.type))
        {
            key.range = null;
            auto v = new AliasDeclaration(loc, prm.ident, key);
            _body = new CompoundStatement(loc, new ExpStatement(loc, v), _body);
        }
        else
        {
            ie = new ExpInitializer(loc, new CastExp(loc, new VarExp(loc, key), prm.type));
            auto v = new VarDeclaration(loc, prm.type, prm.ident, ie);
            v.storage_class |= STCtemp | STCforeach | (prm.storageClass & STCref);
            _body = new CompoundStatement(loc, new ExpStatement(loc, v), _body);
            if (key.range && !prm.type.isMutable())
            {
                /* Limit the range of the key to the specified range
                 */
                v.range = new IntRange(key.range.imin, key.range.imax - SignExtendedNumber(1));
            }
        }
        if (prm.storageClass & STCref)
        {
            if (key.type.constConv(prm.type) <= MATCHnomatch)
            {
                error("prmument type mismatch, %s to ref %s", key.type.toChars(), prm.type.toChars());
                goto Lerror;
            }
        }
        auto s = new ForStatement(loc, forinit, cond, increment, _body, endloc);
        if (LabelStatement ls = checkLabeledLoop(sc, this))
            ls.gotoTarget = s;
        return s.semantic(sc);
    }

    bool hasBreak()
    {
        return true;
    }

    bool hasContinue()
    {
        return true;
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

extern (C++) final class IfStatement : Statement
{
public:
    Parameter prm;
    Expression condition;
    Statement ifbody;
    Statement elsebody;
    VarDeclaration match; // for MatchExpression results

    /******************************** IfStatement ***************************/
    extern (D) this(Loc loc, Parameter prm, Expression condition, Statement ifbody, Statement elsebody)
    {
        super(loc);
        this.prm = prm;
        this.condition = condition;
        this.ifbody = ifbody;
        this.elsebody = elsebody;
        this.match = null;
    }

    Statement syntaxCopy()
    {
        return new IfStatement(loc, prm ? prm.syntaxCopy() : null, condition.syntaxCopy(), ifbody ? ifbody.syntaxCopy() : null, elsebody ? elsebody.syntaxCopy() : null);
    }

    Statement semantic(Scope* sc)
    {
        // Evaluate at runtime
        uint cs0 = sc.callSuper;
        uint cs1;
        uint* fi0 = sc.saveFieldInit();
        uint* fi1 = null;
        auto sym = new ScopeDsymbol();
        sym.parent = sc.scopesym;
        Scope* scd = sc.push(sym);
        if (prm)
        {
            /* Declare prm, which we will set to be the
             * result of condition.
             */
            match = new VarDeclaration(loc, prm.type, prm.ident, new ExpInitializer(loc, condition));
            match.parent = sc.func;
            match.storage_class |= prm.storageClass;
            auto de = new DeclarationExp(loc, match);
            auto ve = new VarExp(Loc(), match);
            condition = new CommaExp(loc, de, ve);
            condition = condition.semantic(scd);
            if (match.edtor)
            {
                Statement sdtor = new ExpStatement(loc, match.edtor);
                sdtor = new OnScopeStatement(loc, TOKon_scope_exit, sdtor);
                ifbody = new CompoundStatement(loc, sdtor, ifbody);
                match.noscope = 1;
            }
        }
        else
        {
            condition = condition.semantic(sc);
            condition = resolveProperties(sc, condition);
            condition = condition.addDtorHook(sc);
        }
        condition = checkGC(sc, condition);
        // Convert to boolean after declaring prm so this works:
        //  if (S prm = S()) {}
        // where S is a struct that defines opCast!bool.
        condition = condition.toBoolean(sc);
        // If we can short-circuit evaluate the if statement, don't do the
        // semantic analysis of the skipped code.
        // This feature allows a limited form of conditional compilation.
        condition = condition.optimize(WANTvalue);
        ifbody = ifbody.semanticNoScope(scd);
        scd.pop();
        cs1 = sc.callSuper;
        fi1 = sc.fieldinit;
        sc.callSuper = cs0;
        sc.fieldinit = fi0;
        if (elsebody)
            elsebody = elsebody.semanticScope(sc, null, null);
        sc.mergeCallSuper(loc, cs1);
        sc.mergeFieldInit(loc, fi1);
        if (condition.op == TOKerror || (ifbody && ifbody.isErrorStatement()) || (elsebody && elsebody.isErrorStatement()))
        {
            return new ErrorStatement();
        }
        return this;
    }

    IfStatement isIfStatement()
    {
        return this;
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

extern (C++) final class ConditionalStatement : Statement
{
public:
    Condition condition;
    Statement ifbody;
    Statement elsebody;

    /******************************** ConditionalStatement ***************************/
    extern (D) this(Loc loc, Condition condition, Statement ifbody, Statement elsebody)
    {
        super(loc);
        this.condition = condition;
        this.ifbody = ifbody;
        this.elsebody = elsebody;
    }

    Statement syntaxCopy()
    {
        return new ConditionalStatement(loc, condition.syntaxCopy(), ifbody.syntaxCopy(), elsebody ? elsebody.syntaxCopy() : null);
    }

    Statement semantic(Scope* sc)
    {
        //printf("ConditionalStatement::semantic()\n");
        // If we can short-circuit evaluate the if statement, don't do the
        // semantic analysis of the skipped code.
        // This feature allows a limited form of conditional compilation.
        if (condition.include(sc, null))
        {
            DebugCondition dc = condition.isDebugCondition();
            if (dc)
            {
                sc = sc.push();
                sc.flags |= SCOPEdebug;
                ifbody = ifbody.semantic(sc);
                sc.pop();
            }
            else
                ifbody = ifbody.semantic(sc);
            return ifbody;
        }
        else
        {
            if (elsebody)
                elsebody = elsebody.semantic(sc);
            return elsebody;
        }
    }

    Statements* flatten(Scope* sc)
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

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

extern (C++) final class PragmaStatement : Statement
{
public:
    Identifier ident;
    Expressions* args; // array of Expression's
    Statement _body;

    /******************************** PragmaStatement ***************************/
    extern (D) this(Loc loc, Identifier ident, Expressions* args, Statement _body)
    {
        super(loc);
        this.ident = ident;
        this.args = args;
        this._body = _body;
    }

    Statement syntaxCopy()
    {
        return new PragmaStatement(loc, ident, Expression.arraySyntaxCopy(args), _body ? _body.syntaxCopy() : null);
    }

    Statement semantic(Scope* sc)
    {
        // Should be merged with PragmaDeclaration
        //printf("PragmaStatement::semantic() %s\n", toChars());
        //printf("body = %p\n", body);
        if (ident == Id.msg)
        {
            if (args)
            {
                for (size_t i = 0; i < args.dim; i++)
                {
                    Expression e = (*args)[i];
                    sc = sc.startCTFE();
                    e = e.semantic(sc);
                    e = resolveProperties(sc, e);
                    sc = sc.endCTFE();
                    // pragma(msg) is allowed to contain types as well as expressions
                    e = ctfeInterpretForPragmaMsg(e);
                    if (e.op == TOKerror)
                    {
                        errorSupplemental(loc, "while evaluating pragma(msg, %s)", (*args)[i].toChars());
                        goto Lerror;
                    }
                    StringExp se = e.toStringExp();
                    if (se)
                    {
                        se = se.toUTF8(sc);
                        fprintf(stderr, "%.*s", cast(int)se.len, cast(char*)se.string);
                    }
                    else
                        fprintf(stderr, "%s", e.toChars());
                }
                fprintf(stderr, "\n");
            }
        }
        else if (ident == Id.lib)
        {
            version (all)
            {
                /* Should this be allowed?
                 */
                error("pragma(lib) not allowed as statement");
                goto Lerror;
            }
            else
            {
                if (!args || args.dim != 1)
                {
                    error("string expected for library name");
                    goto Lerror;
                }
                else
                {
                    Expression e = (*args)[0];
                    sc = sc.startCTFE();
                    e = e.semantic(sc);
                    e = resolveProperties(sc, e);
                    sc = sc.endCTFE();
                    e = e.ctfeInterpret();
                    (*args)[0] = e;
                    StringExp se = e.toStringExp();
                    if (!se)
                    {
                        error("string expected for library name, not '%s'", e.toChars());
                        goto Lerror;
                    }
                    else if (global.params.verbose)
                    {
                        char* name = cast(char*)mem.malloc(se.len + 1);
                        memcpy(name, se.string, se.len);
                        name[se.len] = 0;
                        fprintf(global.stdmsg, "library   %s\n", name);
                        mem.free(name);
                    }
                }
            }
        }
        else if (ident == Id.startaddress)
        {
            if (!args || args.dim != 1)
                error("function name expected for start address");
            else
            {
                Expression e = (*args)[0];
                sc = sc.startCTFE();
                e = e.semantic(sc);
                e = resolveProperties(sc, e);
                sc = sc.endCTFE();
                e = e.ctfeInterpret();
                (*args)[0] = e;
                Dsymbol sa = getDsymbol(e);
                if (!sa || !sa.isFuncDeclaration())
                {
                    error("function name expected for start address, not '%s'", e.toChars());
                    goto Lerror;
                }
                if (_body)
                {
                    _body = _body.semantic(sc);
                    if (_body.isErrorStatement())
                        return _body;
                }
                return this;
            }
        }
        else if (ident == Id.Pinline)
        {
            PINLINE inlining = PINLINEdefault;
            if (!args || args.dim == 0)
                inlining = PINLINEdefault;
            else if (!args || args.dim != 1)
            {
                error("boolean expression expected for pragma(inline)");
                goto Lerror;
            }
            else
            {
                Expression e = (*args)[0];
                if (e.op != TOKint64 || !e.type.equals(Type.tbool))
                {
                    error("pragma(inline, true or false) expected, not %s", e.toChars());
                    goto Lerror;
                }
                if (e.isBool(true))
                    inlining = PINLINEalways;
                else if (e.isBool(false))
                    inlining = PINLINEnever;
                FuncDeclaration fd = sc.func;
                if (!fd)
                {
                    error("pragma(inline) is not inside a function");
                    goto Lerror;
                }
                fd.inlining = inlining;
            }
        }
        else
        {
            error("unrecognized pragma(%s)", ident.toChars());
            goto Lerror;
        }
        if (_body)
        {
            _body = _body.semantic(sc);
        }
        return _body;
    Lerror:
        return new ErrorStatement();
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

extern (C++) final class StaticAssertStatement : Statement
{
public:
    StaticAssert sa;

    /******************************** StaticAssertStatement ***************************/
    extern (D) this(StaticAssert sa)
    {
        super(sa.loc);
        this.sa = sa;
    }

    Statement syntaxCopy()
    {
        return new StaticAssertStatement(cast(StaticAssert)sa.syntaxCopy(null));
    }

    Statement semantic(Scope* sc)
    {
        sa.semantic2(sc);
        return null;
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

extern (C++) final class SwitchStatement : Statement
{
public:
    Expression condition;
    Statement _body;
    bool isFinal;
    DefaultStatement sdefault;
    TryFinallyStatement tf;
    GotoCaseStatements gotoCases; // array of unresolved GotoCaseStatement's
    CaseStatements* cases; // array of CaseStatement's
    int hasNoDefault; // !=0 if no default statement
    int hasVars; // !=0 if has variable case values

    /******************************** SwitchStatement ***************************/
    extern (D) this(Loc loc, Expression c, Statement b, bool isFinal)
    {
        super(loc);
        this.condition = c;
        this._body = b;
        this.isFinal = isFinal;
        sdefault = null;
        tf = null;
        cases = null;
        hasNoDefault = 0;
        hasVars = 0;
    }

    Statement syntaxCopy()
    {
        return new SwitchStatement(loc, condition.syntaxCopy(), _body.syntaxCopy(), isFinal);
    }

    Statement semantic(Scope* sc)
    {
        //printf("SwitchStatement::semantic(%p)\n", this);
        tf = sc.tf;
        if (cases)
            return this; // already run
        bool conditionError = false;
        condition = condition.semantic(sc);
        condition = resolveProperties(sc, condition);
        TypeEnum te = null;
        // preserve enum type for final switches
        if (condition.type.ty == Tenum)
            te = cast(TypeEnum)condition.type;
        if (condition.type.isString())
        {
            // If it's not an array, cast it to one
            if (condition.type.ty != Tarray)
            {
                condition = condition.implicitCastTo(sc, condition.type.nextOf().arrayOf());
            }
            condition.type = condition.type.constOf();
        }
        else
        {
            condition = integralPromotions(condition, sc);
            if (condition.op != TOKerror && !condition.type.isintegral())
            {
                error("'%s' must be of integral or string type, it is a %s", condition.toChars(), condition.type.toChars());
                conditionError = true;
            }
        }
        condition = condition.optimize(WANTvalue);
        condition = checkGC(sc, condition);
        if (condition.op == TOKerror)
            conditionError = true;
        bool needswitcherror = false;
        sc = sc.push();
        sc.sbreak = this;
        sc.sw = this;
        cases = new CaseStatements();
        sc.noctor++; // BUG: should use Scope::mergeCallSuper() for each case instead
        _body = _body.semantic(sc);
        sc.noctor--;
        if (conditionError || _body.isErrorStatement())
            goto Lerror;
        // Resolve any goto case's with exp
        for (size_t i = 0; i < gotoCases.dim; i++)
        {
            GotoCaseStatement gcs = gotoCases[i];
            if (!gcs.exp)
            {
                gcs.error("no case statement following goto case;");
                goto Lerror;
            }
            for (Scope* scx = sc; scx; scx = scx.enclosing)
            {
                if (!scx.sw)
                    continue;
                for (size_t j = 0; j < scx.sw.cases.dim; j++)
                {
                    CaseStatement cs = (*scx.sw.cases)[j];
                    if (cs.exp.equals(gcs.exp))
                    {
                        gcs.cs = cs;
                        goto Lfoundcase;
                    }
                }
            }
            gcs.error("case %s not found", gcs.exp.toChars());
            goto Lerror;
        Lfoundcase:
        }
        if (isFinal)
        {
            Type t = condition.type;
            Dsymbol ds;
            EnumDeclaration ed = null;
            if (t && ((ds = t.toDsymbol(sc)) !is null))
                ed = ds.isEnumDeclaration(); // typedef'ed enum
            if (!ed && te && ((ds = te.toDsymbol(sc)) !is null))
                ed = ds.isEnumDeclaration();
            if (ed)
            {
                size_t dim = ed.members.dim;
                for (size_t i = 0; i < dim; i++)
                {
                    EnumMember em = (*ed.members)[i].isEnumMember();
                    if (em)
                    {
                        for (size_t j = 0; j < cases.dim; j++)
                        {
                            CaseStatement cs = (*cases)[j];
                            if (cs.exp.equals(em.value) || (!cs.exp.type.isString() && !em.value.type.isString() && cs.exp.toInteger() == em.value.toInteger()))
                                goto L1;
                        }
                        error("enum member %s not represented in final switch", em.toChars());
                        goto Lerror;
                    }
                L1:
                }
            }
            else
                needswitcherror = true;
        }
        if (!sc.sw.sdefault && (!isFinal || needswitcherror || global.params.useAssert))
        {
            hasNoDefault = 1;
            if (!isFinal && !_body.isErrorStatement())
                error("switch statement without a default; use 'final switch' or add 'default: assert(0);' or add 'default: break;'");
            // Generate runtime error if the default is hit
            auto a = new Statements();
            CompoundStatement cs;
            Statement s;
            if (global.params.useSwitchError)
                s = new SwitchErrorStatement(loc);
            else
                s = new ExpStatement(loc, new HaltExp(loc));
            a.reserve(2);
            sc.sw.sdefault = new DefaultStatement(loc, s);
            a.push(_body);
            if (_body.blockExit(sc.func, false) & BEfallthru)
                a.push(new BreakStatement(Loc(), null));
            a.push(sc.sw.sdefault);
            cs = new CompoundStatement(loc, a);
            _body = cs;
        }
        sc.pop();
        return this;
    Lerror:
        sc.pop();
        return new ErrorStatement();
    }

    bool hasBreak()
    {
        return true;
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

extern (C++) final class CaseStatement : Statement
{
public:
    Expression exp;
    Statement statement;
    int index; // which case it is (since we sort this)

    /******************************** CaseStatement ***************************/
    extern (D) this(Loc loc, Expression exp, Statement s)
    {
        super(loc);
        this.exp = exp;
        this.statement = s;
        index = 0;
    }

    Statement syntaxCopy()
    {
        return new CaseStatement(loc, exp.syntaxCopy(), statement.syntaxCopy());
    }

    Statement semantic(Scope* sc)
    {
        SwitchStatement sw = sc.sw;
        bool errors = false;
        //printf("CaseStatement::semantic() %s\n", toChars());
        sc = sc.startCTFE();
        exp = exp.semantic(sc);
        exp = resolveProperties(sc, exp);
        sc = sc.endCTFE();
        if (sw)
        {
            exp = exp.implicitCastTo(sc, sw.condition.type);
            exp = exp.optimize(WANTvalue);
            /* This is where variables are allowed as case expressions.
             */
            if (exp.op == TOKvar)
            {
                VarExp ve = cast(VarExp)exp;
                VarDeclaration v = ve.var.isVarDeclaration();
                Type t = exp.type.toBasetype();
                if (v && (t.isintegral() || t.ty == Tclass))
                {
                    /* Flag that we need to do special code generation
                     * for this, i.e. generate a sequence of if-then-else
                     */
                    sw.hasVars = 1;
                    if (sw.isFinal)
                    {
                        error("case variables not allowed in final switch statements");
                        errors = true;
                    }
                    goto L1;
                }
            }
            else
                exp = exp.ctfeInterpret();
            if (StringExp se = exp.toStringExp())
                exp = se;
            else if (exp.op != TOKint64 && exp.op != TOKerror)
            {
                error("case must be a string or an integral constant, not %s", exp.toChars());
                errors = true;
            }
        L1:
            for (size_t i = 0; i < sw.cases.dim; i++)
            {
                CaseStatement cs = (*sw.cases)[i];
                //printf("comparing '%s' with '%s'\n", exp->toChars(), cs->exp->toChars());
                if (cs.exp.equals(exp))
                {
                    error("duplicate case %s in switch statement", exp.toChars());
                    errors = true;
                    break;
                }
            }
            sw.cases.push(this);
            // Resolve any goto case's with no exp to this case statement
            for (size_t i = 0; i < sw.gotoCases.dim;)
            {
                GotoCaseStatement gcs = sw.gotoCases[i];
                if (!gcs.exp)
                {
                    gcs.cs = this;
                    sw.gotoCases.remove(i); // remove from array
                    continue;
                }
                i++;
            }
            if (sc.sw.tf != sc.tf)
            {
                error("switch and case are in different finally blocks");
                errors = true;
            }
        }
        else
        {
            error("case not in switch statement");
            errors = true;
        }
        statement = statement.semantic(sc);
        if (statement.isErrorStatement())
            return statement;
        if (errors || exp.op == TOKerror)
            return new ErrorStatement();
        return this;
    }

    int compare(RootObject obj)
    {
        // Sort cases so we can do an efficient lookup
        CaseStatement cs2 = cast(CaseStatement)obj;
        return exp.compare(cs2.exp);
    }

    CaseStatement isCaseStatement()
    {
        return this;
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

extern (C++) final class CaseRangeStatement : Statement
{
public:
    Expression first;
    Expression last;
    Statement statement;

    /******************************** CaseRangeStatement ***************************/
    extern (D) this(Loc loc, Expression first, Expression last, Statement s)
    {
        super(loc);
        this.first = first;
        this.last = last;
        this.statement = s;
    }

    Statement syntaxCopy()
    {
        return new CaseRangeStatement(loc, first.syntaxCopy(), last.syntaxCopy(), statement.syntaxCopy());
    }

    Statement semantic(Scope* sc)
    {
        SwitchStatement sw = sc.sw;
        if (sw is null)
        {
            error("case range not in switch statement");
            return new ErrorStatement();
        }
        //printf("CaseRangeStatement::semantic() %s\n", toChars());
        bool errors = false;
        if (sw.isFinal)
        {
            error("case ranges not allowed in final switch");
            errors = true;
        }
        sc = sc.startCTFE();
        first = first.semantic(sc);
        first = resolveProperties(sc, first);
        sc = sc.endCTFE();
        first = first.implicitCastTo(sc, sw.condition.type);
        first = first.ctfeInterpret();
        sc = sc.startCTFE();
        last = last.semantic(sc);
        last = resolveProperties(sc, last);
        sc = sc.endCTFE();
        last = last.implicitCastTo(sc, sw.condition.type);
        last = last.ctfeInterpret();
        if (first.op == TOKerror || last.op == TOKerror || errors)
        {
            if (statement)
                statement.semantic(sc);
            return new ErrorStatement();
        }
        uinteger_t fval = first.toInteger();
        uinteger_t lval = last.toInteger();
        if ((first.type.isunsigned() && fval > lval) || (!first.type.isunsigned() && cast(sinteger_t)fval > cast(sinteger_t)lval))
        {
            error("first case %s is greater than last case %s", first.toChars(), last.toChars());
            errors = true;
            lval = fval;
        }
        if (lval - fval > 256)
        {
            error("had %llu cases which is more than 256 cases in case range", lval - fval);
            errors = true;
            lval = fval + 256;
        }
        if (errors)
            return new ErrorStatement();
        /* This works by replacing the CaseRange with an array of Case's.
         *
         * case a: .. case b: s;
         *    =>
         * case a:
         *   [...]
         * case b:
         *   s;
         */
        auto statements = new Statements();
        for (uinteger_t i = fval; i != lval + 1; i++)
        {
            Statement s = statement;
            if (i != lval) // if not last case
                s = new ExpStatement(loc, cast(Expression)null);
            Expression e = new IntegerExp(loc, i, first.type);
            Statement cs = new CaseStatement(loc, e, s);
            statements.push(cs);
        }
        Statement s = new CompoundStatement(loc, statements);
        s = s.semantic(sc);
        return s;
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

extern (C++) final class DefaultStatement : Statement
{
public:
    Statement statement;

    /******************************** DefaultStatement ***************************/
    extern (D) this(Loc loc, Statement s)
    {
        super(loc);
        this.statement = s;
    }

    Statement syntaxCopy()
    {
        return new DefaultStatement(loc, statement.syntaxCopy());
    }

    Statement semantic(Scope* sc)
    {
        //printf("DefaultStatement::semantic()\n");
        bool errors = false;
        if (sc.sw)
        {
            if (sc.sw.sdefault)
            {
                error("switch statement already has a default");
                errors = true;
            }
            sc.sw.sdefault = this;
            if (sc.sw.tf != sc.tf)
            {
                error("switch and default are in different finally blocks");
                errors = true;
            }
            if (sc.sw.isFinal)
            {
                error("default statement not allowed in final switch statement");
                errors = true;
            }
        }
        else
        {
            error("default not in switch statement");
            errors = true;
        }
        statement = statement.semantic(sc);
        if (errors || statement.isErrorStatement())
            return new ErrorStatement();
        return this;
    }

    DefaultStatement isDefaultStatement()
    {
        return this;
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

extern (C++) final class GotoDefaultStatement : Statement
{
public:
    SwitchStatement sw;

    /******************************** GotoDefaultStatement ***************************/
    extern (D) this(Loc loc)
    {
        super(loc);
        sw = null;
    }

    Statement syntaxCopy()
    {
        return new GotoDefaultStatement(loc);
    }

    Statement semantic(Scope* sc)
    {
        sw = sc.sw;
        if (!sw)
        {
            error("goto default not in switch statement");
            return new ErrorStatement();
        }
        return this;
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

extern (C++) final class GotoCaseStatement : Statement
{
public:
    Expression exp; // NULL, or which case to goto
    CaseStatement cs; // case statement it resolves to

    /******************************** GotoCaseStatement ***************************/
    extern (D) this(Loc loc, Expression exp)
    {
        super(loc);
        cs = null;
        this.exp = exp;
    }

    Statement syntaxCopy()
    {
        return new GotoCaseStatement(loc, exp ? exp.syntaxCopy() : null);
    }

    Statement semantic(Scope* sc)
    {
        if (!sc.sw)
        {
            error("goto case not in switch statement");
            return new ErrorStatement();
        }
        if (exp)
        {
            exp = exp.semantic(sc);
            exp = exp.implicitCastTo(sc, sc.sw.condition.type);
            exp = exp.optimize(WANTvalue);
            if (exp.op == TOKerror)
                return new ErrorStatement();
        }
        sc.sw.gotoCases.push(this);
        return this;
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

extern (C++) final class SwitchErrorStatement : Statement
{
public:
    /******************************** SwitchErrorStatement ***************************/
    extern (D) this(Loc loc)
    {
        super(loc);
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

extern (C++) final class ReturnStatement : Statement
{
public:
    Expression exp;
    size_t caseDim;

    /******************************** ReturnStatement ***************************/
    extern (D) this(Loc loc, Expression exp)
    {
        super(loc);
        this.exp = exp;
        this.caseDim = 0;
    }

    Statement syntaxCopy()
    {
        return new ReturnStatement(loc, exp ? exp.syntaxCopy() : null);
    }

    Statement semantic(Scope* sc)
    {
        //printf("ReturnStatement::semantic() %s\n", toChars());
        FuncDeclaration fd = sc.parent.isFuncDeclaration();
        if (fd.fes)
            fd = fd.fes.func; // fd is now function enclosing foreach
        TypeFunction tf = cast(TypeFunction)fd.type;
        assert(tf.ty == Tfunction);
        if (exp && exp.op == TOKvar && (cast(VarExp)exp).var == fd.vresult)
        {
            // return vresult;
            if (sc.fes)
            {
                assert(caseDim == 0);
                sc.fes.cases.push(this);
                return new ReturnStatement(Loc(), new IntegerExp(sc.fes.cases.dim + 1));
            }
            if (fd.returnLabel)
            {
                auto gs = new GotoStatement(loc, Id.returnLabel);
                gs.label = fd.returnLabel;
                return gs;
            }
            if (!fd.returns)
                fd.returns = new ReturnStatements();
            fd.returns.push(this);
            return this;
        }
        Type tret = tf.next;
        Type tbret = tret ? tret.toBasetype() : null;
        bool inferRef = (tf.isref && (fd.storage_class & STCauto));
        Expression e0 = null;
        bool errors = false;
        if (sc.flags & SCOPEcontract)
        {
            error("return statements cannot be in contracts");
            errors = true;
        }
        if (sc.os && sc.os.tok != TOKon_scope_failure)
        {
            error("return statements cannot be in %s bodies", Token.toChars(sc.os.tok));
            errors = true;
        }
        if (sc.tf)
        {
            error("return statements cannot be in finally bodies");
            errors = true;
        }
        if (fd.isCtorDeclaration())
        {
            if (exp)
            {
                error("cannot return expression from constructor");
                errors = true;
            }
            // Constructors implicitly do:
            //      return this;
            exp = new ThisExp(Loc());
            exp.type = tret;
        }
        else if (exp)
        {
            fd.hasReturnExp |= 1;
            FuncLiteralDeclaration fld = fd.isFuncLiteralDeclaration();
            if (tret)
                exp = inferType(exp, tret);
            else if (fld && fld.treq)
                exp = inferType(exp, fld.treq.nextOf().nextOf());
            exp = exp.semantic(sc);
            exp = resolveProperties(sc, exp);
            if (exp.type && exp.type.ty != Tvoid || exp.op == TOKfunction || exp.op == TOKtype || exp.op == TOKtemplate)
            {
                // don't make error for void expression
                if (exp.checkValue())
                    exp = new ErrorExp();
            }
            if (checkNonAssignmentArrayOp(exp))
                exp = new ErrorExp();
            // Extract side-effect part
            exp = Expression.extractLast(exp, &e0);
            if (exp.op == TOKcall)
                exp = valueNoDtor(exp);
            /* Void-return function can have void typed expression
             * on return statement.
             */
            if (tbret && tbret.ty == Tvoid || exp.type.ty == Tvoid)
            {
                if (exp.type.ty != Tvoid)
                {
                    error("cannot return non-void from void function");
                    errors = true;
                    exp = new CastExp(loc, exp, Type.tvoid);
                    exp = exp.semantic(sc);
                }
                /* Replace:
                 *      return exp;
                 * with:
                 *      exp; return;
                 */
                e0 = Expression.combine(e0, exp);
                exp = null;
            }
            if (e0)
                e0 = checkGC(sc, e0);
        }
        if (exp)
        {
            if (fd.inferRetType) // infer return type
            {
                if (!tret)
                {
                    tf.next = exp.type;
                }
                else if (tret.ty != Terror && !exp.type.equals(tret))
                {
                    int m1 = exp.type.implicitConvTo(tret);
                    int m2 = tret.implicitConvTo(exp.type);
                    //printf("exp->type = %s m2<-->m1 tret %s\n", exp->type->toChars(), tret->toChars());
                    //printf("m1 = %d, m2 = %d\n", m1, m2);
                    if (m1 && m2)
                    {
                    }
                    else if (!m1 && m2)
                        tf.next = exp.type;
                    else if (m1 && !m2)
                    {
                    }
                    else if (exp.op != TOKerror)
                    {
                        error("mismatched function return type inference of %s and %s", exp.type.toChars(), tret.toChars());
                        errors = true;
                        tf.next = Type.terror;
                    }
                }
                tret = tf.next;
                tbret = tret.toBasetype();
            }
            if (inferRef) // deduce 'auto ref'
            {
                /* Determine "refness" of function return:
                 * if it's an lvalue, return by ref, else return by value
                 */
                if (exp.isLvalue())
                {
                    /* May return by ref
                     */
                    if (checkEscapeRef(sc, exp, true))
                        tf.isref = false; // return by value
                }
                else
                    tf.isref = false; // return by value
                /* The "refness" is determined by all of return statements.
                 * This means:
                 *    return 3; return x;  // ok, x can be a value
                 *    return x; return 3;  // ok, x can be a value
                 */
            }
            // handle NRVO
            if (fd.nrvo_can && exp.op == TOKvar)
            {
                VarExp ve = cast(VarExp)exp;
                VarDeclaration v = ve.var.isVarDeclaration();
                if (tf.isref)
                {
                    // Function returns a reference
                    if (!inferRef)
                        fd.nrvo_can = 0;
                }
                else if (!v || v.isOut() || v.isRef())
                    fd.nrvo_can = 0;
                else if (fd.nrvo_var is null)
                {
                    if (!v.isDataseg() && !v.isParameter() && v.toParent2() == fd)
                    {
                        //printf("Setting nrvo to %s\n", v->toChars());
                        fd.nrvo_var = v;
                    }
                    else
                        fd.nrvo_can = 0;
                }
                else if (fd.nrvo_var != v)
                    fd.nrvo_can = 0;
            }
            else //if (!exp->isLvalue())    // keep NRVO-ability
                fd.nrvo_can = 0;
        }
        else
        {
            // handle NRVO
            fd.nrvo_can = 0;
            // infer return type
            if (fd.inferRetType)
            {
                if (tf.next && tf.next.ty != Tvoid)
                {
                    error("mismatched function return type inference of void and %s", tf.next.toChars());
                    errors = true;
                }
                tf.next = Type.tvoid;
                tret = tf.next;
                tbret = tret.toBasetype();
            }
            if (inferRef) // deduce 'auto ref'
                tf.isref = false;
            if (tbret.ty != Tvoid) // if non-void return
            {
                error("return expression expected");
                errors = true;
            }
            else if (fd.isMain())
            {
                // main() returns 0, even if it returns void
                exp = new IntegerExp(0);
            }
        }
        // If any branches have called a ctor, but this branch hasn't, it's an error
        if (sc.callSuper & CSXany_ctor && !(sc.callSuper & (CSXthis_ctor | CSXsuper_ctor)))
        {
            error("return without calling constructor");
            errors = true;
        }
        sc.callSuper |= CSXreturn;
        if (sc.fieldinit)
        {
            AggregateDeclaration ad = fd.isAggregateMember2();
            assert(ad);
            size_t dim = sc.fieldinit_dim;
            for (size_t i = 0; i < dim; i++)
            {
                VarDeclaration v = ad.fields[i];
                bool mustInit = (v.storage_class & STCnodefaultctor || v.type.needsNested());
                if (mustInit && !(sc.fieldinit[i] & CSXthis_ctor))
                {
                    error("an earlier return statement skips field %s initialization", v.toChars());
                    errors = true;
                }
                sc.fieldinit[i] |= CSXreturn;
            }
        }
        if (errors)
            return new ErrorStatement();
        if (sc.fes)
        {
            if (!exp)
            {
                // Send out "case receiver" statement to the foreach.
                //  return exp;
                Statement s = new ReturnStatement(Loc(), exp);
                sc.fes.cases.push(s);
                // Immediately rewrite "this" return statement as:
                //  return cases->dim+1;
                this.exp = new IntegerExp(sc.fes.cases.dim + 1);
                if (e0)
                    return new CompoundStatement(loc, new ExpStatement(loc, e0), this);
                return this;
            }
            else
            {
                fd.buildResultVar(null, exp.type);
                bool r = fd.vresult.checkNestedReference(sc, Loc());
                assert(!r); // vresult should be always accessible
                // Send out "case receiver" statement to the foreach.
                //  return vresult;
                Statement s = new ReturnStatement(Loc(), new VarExp(Loc(), fd.vresult));
                sc.fes.cases.push(s);
                // Save receiver index for the later rewriting from:
                //  return exp;
                // to:
                //  vresult = exp; retrun caseDim;
                caseDim = sc.fes.cases.dim + 1;
            }
        }
        if (exp)
        {
            if (!fd.returns)
                fd.returns = new ReturnStatements();
            fd.returns.push(this);
        }
        if (e0)
            return new CompoundStatement(loc, new ExpStatement(loc, e0), this);
        return this;
    }

    ReturnStatement isReturnStatement()
    {
        return this;
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

extern (C++) final class BreakStatement : Statement
{
public:
    Identifier ident;

    /******************************** BreakStatement ***************************/
    extern (D) this(Loc loc, Identifier ident)
    {
        super(loc);
        this.ident = ident;
    }

    Statement syntaxCopy()
    {
        return new BreakStatement(loc, ident);
    }

    Statement semantic(Scope* sc)
    {
        //printf("BreakStatement::semantic()\n");
        // If:
        //  break Identifier;
        if (ident)
        {
            ident = fixupLabelName(sc, ident);
            FuncDeclaration thisfunc = sc.func;
            for (Scope* scx = sc; scx; scx = scx.enclosing)
            {
                if (scx.func != thisfunc) // if in enclosing function
                {
                    if (sc.fes) // if this is the body of a foreach
                    {
                        /* Post this statement to the fes, and replace
                         * it with a return value that caller will put into
                         * a switch. Caller will figure out where the break
                         * label actually is.
                         * Case numbers start with 2, not 0, as 0 is continue
                         * and 1 is break.
                         */
                        sc.fes.cases.push(this);
                        Statement s = new ReturnStatement(Loc(), new IntegerExp(sc.fes.cases.dim + 1));
                        return s;
                    }
                    break;
                    // can't break to it
                }
                LabelStatement ls = scx.slabel;
                if (ls && ls.ident == ident)
                {
                    Statement s = ls.statement;
                    if (!s || !s.hasBreak())
                        error("label '%s' has no break", ident.toChars());
                    else if (ls.tf != sc.tf)
                        error("cannot break out of finally block");
                    else
                    {
                        ls.breaks = true;
                        return this;
                    }
                    return new ErrorStatement();
                }
            }
            error("enclosing label '%s' for break not found", ident.toChars());
            return new ErrorStatement();
        }
        else if (!sc.sbreak)
        {
            if (sc.os && sc.os.tok != TOKon_scope_failure)
            {
                error("break is not inside %s bodies", Token.toChars(sc.os.tok));
            }
            else if (sc.fes)
            {
                // Replace break; with return 1;
                Statement s = new ReturnStatement(Loc(), new IntegerExp(1));
                return s;
            }
            else
                error("break is not inside a loop or switch");
            return new ErrorStatement();
        }
        return this;
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

extern (C++) final class ContinueStatement : Statement
{
public:
    Identifier ident;

    /******************************** ContinueStatement ***************************/
    extern (D) this(Loc loc, Identifier ident)
    {
        super(loc);
        this.ident = ident;
    }

    Statement syntaxCopy()
    {
        return new ContinueStatement(loc, ident);
    }

    Statement semantic(Scope* sc)
    {
        //printf("ContinueStatement::semantic() %p\n", this);
        if (ident)
        {
            ident = fixupLabelName(sc, ident);
            Scope* scx;
            FuncDeclaration thisfunc = sc.func;
            for (scx = sc; scx; scx = scx.enclosing)
            {
                LabelStatement ls;
                if (scx.func != thisfunc) // if in enclosing function
                {
                    if (sc.fes) // if this is the body of a foreach
                    {
                        for (; scx; scx = scx.enclosing)
                        {
                            ls = scx.slabel;
                            if (ls && ls.ident == ident && ls.statement == sc.fes)
                            {
                                // Replace continue ident; with return 0;
                                return new ReturnStatement(Loc(), new IntegerExp(0));
                            }
                        }
                        /* Post this statement to the fes, and replace
                         * it with a return value that caller will put into
                         * a switch. Caller will figure out where the break
                         * label actually is.
                         * Case numbers start with 2, not 0, as 0 is continue
                         * and 1 is break.
                         */
                        sc.fes.cases.push(this);
                        Statement s = new ReturnStatement(Loc(), new IntegerExp(sc.fes.cases.dim + 1));
                        return s;
                    }
                    break;
                    // can't continue to it
                }
                ls = scx.slabel;
                if (ls && ls.ident == ident)
                {
                    Statement s = ls.statement;
                    if (!s || !s.hasContinue())
                        error("label '%s' has no continue", ident.toChars());
                    else if (ls.tf != sc.tf)
                        error("cannot continue out of finally block");
                    else
                        return this;
                    return new ErrorStatement();
                }
            }
            error("enclosing label '%s' for continue not found", ident.toChars());
            return new ErrorStatement();
        }
        else if (!sc.scontinue)
        {
            if (sc.os && sc.os.tok != TOKon_scope_failure)
            {
                error("continue is not inside %s bodies", Token.toChars(sc.os.tok));
            }
            else if (sc.fes)
            {
                // Replace continue; with return 0;
                Statement s = new ReturnStatement(Loc(), new IntegerExp(0));
                return s;
            }
            else
                error("continue is not inside a loop");
            return new ErrorStatement();
        }
        return this;
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

extern (C++) final class SynchronizedStatement : Statement
{
public:
    Expression exp;
    Statement _body;

    /******************************** SynchronizedStatement ***************************/
    extern (D) this(Loc loc, Expression exp, Statement _body)
    {
        super(loc);
        this.exp = exp;
        this._body = _body;
    }

    Statement syntaxCopy()
    {
        return new SynchronizedStatement(loc, exp ? exp.syntaxCopy() : null, _body ? _body.syntaxCopy() : null);
    }

    Statement semantic(Scope* sc)
    {
        if (exp)
        {
            exp = exp.semantic(sc);
            exp = resolveProperties(sc, exp);
            exp = exp.optimize(WANTvalue);
            exp = checkGC(sc, exp);
            if (exp.op == TOKerror)
                goto Lbody;
            ClassDeclaration cd = exp.type.isClassHandle();
            if (!cd)
            {
                error("can only synchronize on class objects, not '%s'", exp.type.toChars());
                return new ErrorStatement();
            }
            else if (cd.isInterfaceDeclaration())
            {
                /* Cast the interface to an object, as the object has the monitor,
                 * not the interface.
                 */
                if (!ClassDeclaration.object)
                {
                    error("missing or corrupt object.d");
                    fatal();
                }
                Type t = ClassDeclaration.object.type;
                t = t.semantic(Loc(), sc).toBasetype();
                assert(t.ty == Tclass);
                exp = new CastExp(loc, exp, t);
                exp = exp.semantic(sc);
            }
            version (all)
            {
                /* Rewrite as:
                 *  auto tmp = exp;
                 *  _d_monitorenter(tmp);
                 *  try { body } finally { _d_monitorexit(tmp); }
                 */
                Identifier id = Identifier.generateId("__sync");
                auto ie = new ExpInitializer(loc, exp);
                auto tmp = new VarDeclaration(loc, exp.type, id, ie);
                tmp.storage_class |= STCtemp;
                auto cs = new Statements();
                cs.push(new ExpStatement(loc, tmp));
                auto args = new Parameters();
                args.push(new Parameter(0, ClassDeclaration.object.type, null, null));
                FuncDeclaration fdenter = FuncDeclaration.genCfunc(args, Type.tvoid, Id.monitorenter);
                Expression e = new CallExp(loc, new VarExp(loc, fdenter), new VarExp(loc, tmp));
                e.type = Type.tvoid; // do not run semantic on e
                cs.push(new ExpStatement(loc, e));
                FuncDeclaration fdexit = FuncDeclaration.genCfunc(args, Type.tvoid, Id.monitorexit);
                e = new CallExp(loc, new VarExp(loc, fdexit), new VarExp(loc, tmp));
                e.type = Type.tvoid; // do not run semantic on e
                Statement s = new ExpStatement(loc, e);
                s = new TryFinallyStatement(loc, _body, s);
                cs.push(s);
                s = new CompoundStatement(loc, cs);
                return s.semantic(sc);
            }
        }
        else
        {
            /* Generate our own critical section, then rewrite as:
             *  __gshared byte[CriticalSection.sizeof] critsec;
             *  _d_criticalenter(critsec.ptr);
             *  try { body } finally { _d_criticalexit(critsec.ptr); }
             */
            Identifier id = Identifier.generateId("__critsec");
            Type t = new TypeSArray(Type.tint8, new IntegerExp(Target.ptrsize + Target.critsecsize()));
            auto tmp = new VarDeclaration(loc, t, id, null);
            tmp.storage_class |= STCtemp | STCgshared | STCstatic;
            auto cs = new Statements();
            cs.push(new ExpStatement(loc, tmp));
            /* This is just a dummy variable for "goto skips declaration" error.
             * Backend optimizer could remove this unused variable.
             */
            auto v = new VarDeclaration(loc, Type.tvoidptr, Identifier.generateId("__sync"), null);
            v.semantic(sc);
            cs.push(new ExpStatement(loc, v));
            auto args = new Parameters();
            args.push(new Parameter(0, t.pointerTo(), null, null));
            FuncDeclaration fdenter = FuncDeclaration.genCfunc(args, Type.tvoid, Id.criticalenter, STCnothrow);
            Expression e = new DotIdExp(loc, new VarExp(loc, tmp), Id.ptr);
            e = e.semantic(sc);
            e = new CallExp(loc, new VarExp(loc, fdenter), e);
            e.type = Type.tvoid; // do not run semantic on e
            cs.push(new ExpStatement(loc, e));
            FuncDeclaration fdexit = FuncDeclaration.genCfunc(args, Type.tvoid, Id.criticalexit, STCnothrow);
            e = new DotIdExp(loc, new VarExp(loc, tmp), Id.ptr);
            e = e.semantic(sc);
            e = new CallExp(loc, new VarExp(loc, fdexit), e);
            e.type = Type.tvoid; // do not run semantic on e
            Statement s = new ExpStatement(loc, e);
            s = new TryFinallyStatement(loc, _body, s);
            cs.push(s);
            s = new CompoundStatement(loc, cs);
            return s.semantic(sc);
        }
    Lbody:
        if (_body)
            _body = _body.semantic(sc);
        if (_body && _body.isErrorStatement())
            return _body;
        return this;
    }

    bool hasBreak()
    {
        return false; //true;
    }

    bool hasContinue()
    {
        return false; //true;
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

extern (C++) final class WithStatement : Statement
{
public:
    Expression exp;
    Statement _body;
    VarDeclaration wthis;

    /******************************** WithStatement ***************************/
    extern (D) this(Loc loc, Expression exp, Statement _body)
    {
        super(loc);
        this.exp = exp;
        this._body = _body;
        wthis = null;
    }

    Statement syntaxCopy()
    {
        return new WithStatement(loc, exp.syntaxCopy(), _body ? _body.syntaxCopy() : null);
    }

    Statement semantic(Scope* sc)
    {
        ScopeDsymbol sym;
        Initializer _init;
        //printf("WithStatement::semantic()\n");
        exp = exp.semantic(sc);
        exp = resolveProperties(sc, exp);
        exp = exp.optimize(WANTvalue);
        exp = checkGC(sc, exp);
        if (exp.op == TOKerror)
            return new ErrorStatement();
        if (exp.op == TOKimport)
        {
            sym = new WithScopeSymbol(this);
            sym.parent = sc.scopesym;
        }
        else if (exp.op == TOKtype)
        {
            Dsymbol s = (cast(TypeExp)exp).type.toDsymbol(sc);
            if (!s || !s.isScopeDsymbol())
            {
                error("with type %s has no members", exp.toChars());
                return new ErrorStatement();
            }
            sym = new WithScopeSymbol(this);
            sym.parent = sc.scopesym;
        }
        else
        {
            Type t = exp.type.toBasetype();
            Expression olde = exp;
            if (t.ty == Tpointer)
            {
                exp = new PtrExp(loc, exp);
                exp = exp.semantic(sc);
                t = exp.type.toBasetype();
            }
            assert(t);
            t = t.toBasetype();
            if (t.isClassHandle())
            {
                _init = new ExpInitializer(loc, exp);
                wthis = new VarDeclaration(loc, exp.type, Id.withSym, _init);
                wthis.semantic(sc);
                sym = new WithScopeSymbol(this);
                sym.parent = sc.scopesym;
            }
            else if (t.ty == Tstruct)
            {
                if (!exp.isLvalue())
                {
                    /* Re-write to
                     * {
                     *   auto __withtmp = exp
                     *   with(__withtmp)
                     *   {
                     *     ...
                     *   }
                     * }
                     */
                    _init = new ExpInitializer(loc, exp);
                    wthis = new VarDeclaration(loc, exp.type, Identifier.generateId("__withtmp"), _init);
                    wthis.storage_class |= STCtemp;
                    auto es = new ExpStatement(loc, wthis);
                    exp = new VarExp(loc, wthis);
                    Statement ss = new ScopeStatement(loc, new CompoundStatement(loc, es, this));
                    return ss.semantic(sc);
                }
                Expression e = exp.addressOf();
                _init = new ExpInitializer(loc, e);
                wthis = new VarDeclaration(loc, e.type, Id.withSym, _init);
                wthis.semantic(sc);
                sym = new WithScopeSymbol(this);
                // Need to set the scope to make use of resolveAliasThis
                sym.setScope(sc);
                sym.parent = sc.scopesym;
            }
            else
            {
                error("with expressions must be aggregate types or pointers to them, not '%s'", olde.type.toChars());
                return new ErrorStatement();
            }
        }
        if (_body)
        {
            sym._scope = sc;
            sc = sc.push(sym);
            sc.insert(sym);
            _body = _body.semantic(sc);
            sc.pop();
            if (_body && _body.isErrorStatement())
                return _body;
        }
        return this;
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

extern (C++) final class TryCatchStatement : Statement
{
public:
    Statement _body;
    Catches* catches;

    /******************************** TryCatchStatement ***************************/
    extern (D) this(Loc loc, Statement _body, Catches* catches)
    {
        super(loc);
        this._body = _body;
        this.catches = catches;
    }

    Statement syntaxCopy()
    {
        auto a = new Catches();
        a.setDim(catches.dim);
        for (size_t i = 0; i < a.dim; i++)
        {
            Catch c = (*catches)[i];
            (*a)[i] = c.syntaxCopy();
        }
        return new TryCatchStatement(loc, _body.syntaxCopy(), a);
    }

    Statement semantic(Scope* sc)
    {
        _body = _body.semanticScope(sc, null, null);
        assert(_body);
        /* Even if body is empty, still do semantic analysis on catches
         */
        bool catchErrors = false;
        for (size_t i = 0; i < catches.dim; i++)
        {
            Catch c = (*catches)[i];
            c.semantic(sc);
            if (c.type.ty == Terror)
            {
                catchErrors = true;
                continue;
            }
            // Determine if current catch 'hides' any previous catches
            for (size_t j = 0; j < i; j++)
            {
                Catch cj = (*catches)[j];
                char* si = c.loc.toChars();
                char* sj = cj.loc.toChars();
                if (c.type.toBasetype().implicitConvTo(cj.type.toBasetype()))
                {
                    error("catch at %s hides catch at %s", sj, si);
                    catchErrors = true;
                }
            }
        }
        if (catchErrors)
            return new ErrorStatement();
        if (_body.isErrorStatement())
            return _body;
        /* If the try body never throws, we can eliminate any catches
         * of recoverable exceptions.
         */
        if (!(_body.blockExit(sc.func, false) & BEthrow) && ClassDeclaration.exception)
        {
            for (size_t i = 0; i < catches.dim; i++)
            {
                Catch c = (*catches)[i];
                /* If catch exception type is derived from Exception
                 */
                if (c.type.toBasetype().implicitConvTo(ClassDeclaration.exception.type) && (!c.handler || !c.handler.comeFrom()))
                {
                    // Remove c from the array of catches
                    catches.remove(i);
                    --i;
                }
            }
        }
        if (catches.dim == 0)
            return _body.hasCode() ? _body : null;
        return this;
    }

    bool hasBreak()
    {
        return false;
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

extern (C++) final class Catch : RootObject
{
public:
    Loc loc;
    Type type;
    Identifier ident;
    VarDeclaration var;
    Statement handler;
    // was generated by the compiler,
    // wasn't present in source code
    bool internalCatch;

    /******************************** Catch ***************************/
    extern (D) this(Loc loc, Type t, Identifier id, Statement handler)
    {
        //printf("Catch(%s, loc = %s)\n", id->toChars(), loc.toChars());
        this.loc = loc;
        this.type = t;
        this.ident = id;
        this.handler = handler;
        var = null;
        internalCatch = false;
    }

    Catch syntaxCopy()
    {
        auto c = new Catch(loc, type ? type.syntaxCopy() : null, ident, (handler ? handler.syntaxCopy() : null));
        c.internalCatch = internalCatch;
        return c;
    }

    void semantic(Scope* sc)
    {
        //printf("Catch::semantic(%s)\n", ident->toChars());
        static if (!IN_GCC)
        {
            if (sc.os && sc.os.tok != TOKon_scope_failure)
            {
                // If enclosing is scope(success) or scope(exit), this will be placed in finally block.
                error(loc, "cannot put catch statement inside %s", Token.toChars(sc.os.tok));
            }
            if (sc.tf)
            {
                /* This is because the _d_local_unwind() gets the stack munged
                 * up on this. The workaround is to place any try-catches into
                 * a separate function, and call that.
                 * To fix, have the compiler automatically convert the finally
                 * body into a nested function.
                 */
                error(loc, "cannot put catch statement inside finally block");
            }
        }
        auto sym = new ScopeDsymbol();
        sym.parent = sc.scopesym;
        sc = sc.push(sym);
        if (!type)
        {
            // reference .object.Throwable
            auto tid = new TypeIdentifier(Loc(), Id.empty);
            tid.addIdent(Id.object);
            tid.addIdent(Id.Throwable);
            type = tid;
        }
        type = type.semantic(loc, sc);
        ClassDeclaration cd = type.toBasetype().isClassHandle();
        if (!cd || ((cd != ClassDeclaration.throwable) && !ClassDeclaration.throwable.isBaseOf(cd, null)))
        {
            if (type != Type.terror)
            {
                error(loc, "can only catch class objects derived from Throwable, not '%s'", type.toChars());
                type = Type.terror;
            }
        }
        else if (sc.func && !sc.intypeof && !internalCatch && cd != ClassDeclaration.exception && !ClassDeclaration.exception.isBaseOf(cd, null) && sc.func.setUnsafe())
        {
            error(loc, "can only catch class objects derived from Exception in @safe code, not '%s'", type.toChars());
            type = Type.terror;
        }
        else if (ident)
        {
            var = new VarDeclaration(loc, type, ident, null);
            var.semantic(sc);
            sc.insert(var);
        }
        handler = handler.semantic(sc);
        sc.pop();
    }
}

extern (C++) final class TryFinallyStatement : Statement
{
public:
    Statement _body;
    Statement finalbody;

    /****************************** TryFinallyStatement ***************************/
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

    Statement syntaxCopy()
    {
        return new TryFinallyStatement(loc, _body.syntaxCopy(), finalbody.syntaxCopy());
    }

    Statement semantic(Scope* sc)
    {
        //printf("TryFinallyStatement::semantic()\n");
        _body = _body.semantic(sc);
        sc = sc.push();
        sc.tf = this;
        sc.sbreak = null;
        sc.scontinue = null; // no break or continue out of finally block
        finalbody = finalbody.semanticNoScope(sc);
        sc.pop();
        if (!_body)
            return finalbody;
        if (!finalbody)
            return _body;
        if (_body.blockExit(sc.func, false) == BEfallthru)
        {
            Statement s = new CompoundStatement(loc, _body, finalbody);
            return s;
        }
        return this;
    }

    bool hasBreak()
    {
        return false; //true;
    }

    bool hasContinue()
    {
        return false; //true;
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

extern (C++) final class OnScopeStatement : Statement
{
public:
    TOK tok;
    Statement statement;

    /****************************** OnScopeStatement ***************************/
    extern (D) this(Loc loc, TOK tok, Statement statement)
    {
        super(loc);
        this.tok = tok;
        this.statement = statement;
    }

    Statement syntaxCopy()
    {
        return new OnScopeStatement(loc, tok, statement.syntaxCopy());
    }

    Statement semantic(Scope* sc)
    {
        static if (!IN_GCC)
        {
            if (tok != TOKon_scope_exit)
            {
                // scope(success) and scope(failure) are rewritten to try-catch(-finally) statement,
                // so the generated catch block cannot be placed in finally block.
                // See also Catch::semantic.
                if (sc.os && sc.os.tok != TOKon_scope_failure)
                {
                    // If enclosing is scope(success) or scope(exit), this will be placed in finally block.
                    error("cannot put %s statement inside %s", Token.toChars(tok), Token.toChars(sc.os.tok));
                    return new ErrorStatement();
                }
                if (sc.tf)
                {
                    error("cannot put %s statement inside finally block", Token.toChars(tok));
                    return new ErrorStatement();
                }
            }
        }
        sc = sc.push();
        sc.tf = null;
        sc.os = this;
        if (tok != TOKon_scope_failure)
        {
            // Jump out from scope(failure) block is allowed.
            sc.sbreak = null;
            sc.scontinue = null;
        }
        statement = statement.semanticNoScope(sc);
        sc.pop();
        if (!statement || statement.isErrorStatement())
            return statement;
        return this;
    }

    Statement scopeCode(Scope* sc, Statement* sentry, Statement* sexception, Statement* sfinally)
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
                Identifier id = Identifier.generateId("__os");
                auto ie = new ExpInitializer(loc, new IntegerExp(Loc(), 0, Type.tbool));
                auto v = new VarDeclaration(loc, Type.tbool, id, ie);
                v.storage_class |= STCtemp;
                *sentry = new ExpStatement(loc, v);
                Expression e = new IntegerExp(Loc(), 1, Type.tbool);
                e = new AssignExp(Loc(), new VarExp(Loc(), v), e);
                *sexception = new ExpStatement(Loc(), e);
                e = new VarExp(Loc(), v);
                e = new NotExp(Loc(), e);
                *sfinally = new IfStatement(Loc(), null, e, s, null);
                break;
            }
        default:
            assert(0);
        }
        return null;
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

extern (C++) final class ThrowStatement : Statement
{
public:
    Expression exp;
    // was generated by the compiler,
    // wasn't present in source code
    bool internalThrow;

    /******************************** ThrowStatement ***************************/
    extern (D) this(Loc loc, Expression exp)
    {
        super(loc);
        this.exp = exp;
        this.internalThrow = false;
    }

    Statement syntaxCopy()
    {
        auto s = new ThrowStatement(loc, exp.syntaxCopy());
        s.internalThrow = internalThrow;
        return s;
    }

    Statement semantic(Scope* sc)
    {
        //printf("ThrowStatement::semantic()\n");
        FuncDeclaration fd = sc.parent.isFuncDeclaration();
        fd.hasReturnExp |= 2;
        exp = exp.semantic(sc);
        exp = resolveProperties(sc, exp);
        exp = checkGC(sc, exp);
        if (exp.op == TOKerror)
            return new ErrorStatement();
        ClassDeclaration cd = exp.type.toBasetype().isClassHandle();
        if (!cd || ((cd != ClassDeclaration.throwable) && !ClassDeclaration.throwable.isBaseOf(cd, null)))
        {
            error("can only throw class objects derived from Throwable, not type %s", exp.type.toChars());
            return new ErrorStatement();
        }
        return this;
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

extern (C++) final class DebugStatement : Statement
{
public:
    Statement statement;

    /******************************** DebugStatement **************************/
    extern (D) this(Loc loc, Statement statement)
    {
        super(loc);
        this.statement = statement;
    }

    Statement syntaxCopy()
    {
        return new DebugStatement(loc, statement ? statement.syntaxCopy() : null);
    }

    Statement semantic(Scope* sc)
    {
        if (statement)
        {
            sc = sc.push();
            sc.flags |= SCOPEdebug;
            statement = statement.semantic(sc);
            sc.pop();
        }
        return statement;
    }

    Statements* flatten(Scope* sc)
    {
        Statements* a = statement ? statement.flatten(sc) : null;
        if (a)
        {
            for (size_t i = 0; i < a.dim; i++)
            {
                Statement s = (*a)[i];
                s = new DebugStatement(loc, s);
                (*a)[i] = s;
            }
        }
        return a;
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

extern (C++) final class GotoStatement : Statement
{
public:
    Identifier ident;
    LabelDsymbol label;
    TryFinallyStatement tf;
    OnScopeStatement os;
    VarDeclaration lastVar;

    /******************************** GotoStatement ***************************/
    extern (D) this(Loc loc, Identifier ident)
    {
        super(loc);
        this.ident = ident;
        this.label = null;
        this.tf = null;
        this.os = null;
        this.lastVar = null;
    }

    Statement syntaxCopy()
    {
        return new GotoStatement(loc, ident);
    }

    Statement semantic(Scope* sc)
    {
        //printf("GotoStatement::semantic()\n");
        FuncDeclaration fd = sc.func;
        ident = fixupLabelName(sc, ident);
        label = fd.searchLabel(ident);
        tf = sc.tf;
        os = sc.os;
        lastVar = sc.lastVar;
        if (!label.statement && sc.fes)
        {
            /* Either the goto label is forward referenced or it
             * is in the function that the enclosing foreach is in.
             * Can't know yet, so wrap the goto in a scope statement
             * so we can patch it later, and add it to a 'look at this later'
             * list.
             */
            auto ss = new ScopeStatement(loc, this);
            sc.fes.gotos.push(ss); // 'look at this later' list
            return ss;
        }
        // Add to fwdref list to check later
        if (!label.statement)
        {
            if (!fd.gotos)
                fd.gotos = new GotoStatements();
            fd.gotos.push(this);
        }
        else if (checkLabel())
            return new ErrorStatement();
        return this;
    }

    bool checkLabel()
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

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

extern (C++) final class LabelStatement : Statement
{
public:
    Identifier ident;
    Statement statement;
    TryFinallyStatement tf;
    OnScopeStatement os;
    VarDeclaration lastVar;
    Statement gotoTarget; // interpret
    bool breaks; // someone did a 'break ident'

    /******************************** LabelStatement ***************************/
    extern (D) this(Loc loc, Identifier ident, Statement statement)
    {
        super(loc);
        this.ident = ident;
        this.statement = statement;
        this.tf = null;
        this.os = null;
        this.lastVar = null;
        this.gotoTarget = null;
        this.breaks = false;
    }

    Statement syntaxCopy()
    {
        return new LabelStatement(loc, ident, statement ? statement.syntaxCopy() : null);
    }

    Statement semantic(Scope* sc)
    {
        //printf("LabelStatement::semantic()\n");
        FuncDeclaration fd = sc.parent.isFuncDeclaration();
        ident = fixupLabelName(sc, ident);
        tf = sc.tf;
        os = sc.os;
        lastVar = sc.lastVar;
        LabelDsymbol ls = fd.searchLabel(ident);
        if (ls.statement)
        {
            error("label '%s' already defined", ls.toChars());
            return new ErrorStatement();
        }
        else
            ls.statement = this;
        sc = sc.push();
        sc.scopesym = sc.enclosing.scopesym;
        sc.callSuper |= CSXlabel;
        if (sc.fieldinit)
        {
            size_t dim = sc.fieldinit_dim;
            for (size_t i = 0; i < dim; i++)
                sc.fieldinit[i] |= CSXlabel;
        }
        sc.slabel = this;
        if (statement)
            statement = statement.semantic(sc);
        sc.pop();
        return this;
    }

    Statements* flatten(Scope* sc)
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

    Statement scopeCode(Scope* sc, Statement* sentry, Statement* sexit, Statement* sfinally)
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

    LabelStatement isLabelStatement()
    {
        return this;
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

extern (C++) final class LabelDsymbol : Dsymbol
{
public:
    LabelStatement statement;

    /******************************** LabelDsymbol ***************************/
    extern (D) this(Identifier ident)
    {
        super(ident);
        statement = null;
    }

    static LabelDsymbol create(Identifier ident)
    {
        return new LabelDsymbol(ident);
    }

    // is this a LabelDsymbol()?
    LabelDsymbol isLabel()
    {
        return this;
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

extern (C++) final class AsmStatement : Statement
{
public:
    Token* tokens;
    code* asmcode;
    uint asmalign; // alignment of this statement
    uint regs; // mask of registers modified (must match regm_t in back end)
    bool refparam; // true if function parameter is referenced
    bool naked; // true if function is to be naked

    /************************ AsmStatement ***************************************/
    extern (D) this(Loc loc, Token* tokens)
    {
        super(loc);
        this.tokens = tokens;
        asmcode = null;
        asmalign = 0;
        refparam = false;
        naked = false;
        regs = 0;
    }

    Statement syntaxCopy()
    {
        return new AsmStatement(loc, tokens);
    }

    Statement semantic(Scope* sc)
    {
        return asmSemantic(this, sc);
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

// a complete asm {} block
extern (C++) final class CompoundAsmStatement : CompoundStatement
{
public:
    StorageClass stc; // postfix attributes like nothrow/pure/@trusted

    /************************ CompoundAsmStatement ***************************************/
    extern (D) this(Loc loc, Statements* s, StorageClass stc)
    {
        super(loc, s);
        this.stc = stc;
    }

    CompoundAsmStatement syntaxCopy()
    {
        auto a = new Statements();
        a.setDim(statements.dim);
        for (size_t i = 0; i < statements.dim; i++)
        {
            Statement s = (*statements)[i];
            (*a)[i] = s ? s.syntaxCopy() : null;
        }
        return new CompoundAsmStatement(loc, a, stc);
    }

    CompoundAsmStatement semantic(Scope* sc)
    {
        for (size_t i = 0; i < statements.dim; i++)
        {
            Statement s = (*statements)[i];
            (*statements)[i] = s ? s.semantic(sc) : null;
        }
        assert(sc.func);
        // use setImpure/setGC when the deprecation cycle is over
        PURE purity;
        if (!(stc & STCpure) && (purity = sc.func.isPureBypassingInference()) != PUREimpure && purity != PUREfwdref)
            deprecation("asm statement is assumed to be impure - mark it with 'pure' if it is not");
        if (!(stc & STCnogc) && sc.func.isNogcBypassingInference())
            deprecation("asm statement is assumed to use the GC - mark it with '@nogc' if it does not");
        if (!(stc & (STCtrusted | STCsafe)) && sc.func.setUnsafe())
            error("asm statement is assumed to be @system - mark it with '@trusted' if it is not");
        return this;
    }

    Statements* flatten(Scope* sc)
    {
        return null;
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

extern (C++) final class ImportStatement : Statement
{
public:
    Dsymbols* imports; // Array of Import's

    /************************ ImportStatement ***************************************/
    extern (D) this(Loc loc, Dsymbols* imports)
    {
        super(loc);
        this.imports = imports;
    }

    Statement syntaxCopy()
    {
        auto m = new Dsymbols();
        m.setDim(imports.dim);
        for (size_t i = 0; i < imports.dim; i++)
        {
            Dsymbol s = (*imports)[i];
            (*m)[i] = s.syntaxCopy(null);
        }
        return new ImportStatement(loc, m);
    }

    Statement semantic(Scope* sc)
    {
        for (size_t i = 0; i < imports.dim; i++)
        {
            Import s = (*imports)[i].isImport();
            assert(!s.aliasdecls.dim);
            for (size_t j = 0; j < s.names.dim; j++)
            {
                Identifier name = s.names[j];
                Identifier _alias = s.aliases[j];
                if (!_alias)
                    _alias = name;
                auto tname = new TypeIdentifier(s.loc, name);
                auto ad = new AliasDeclaration(s.loc, _alias, tname);
                ad._import = s;
                s.aliasdecls.push(ad);
            }
            s.semantic(sc);
            //s->semantic2(sc);     // Bugzilla 14666
            sc.insert(s);
            for (size_t j = 0; j < s.aliasdecls.dim; j++)
            {
                sc.insert(s.aliasdecls[j]);
            }
        }
        return this;
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}
