/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _blockexit.d)
 */

module ddmd.blockexit;

import core.stdc.stdio;

import ddmd.arraytypes;
import ddmd.canthrow;
import ddmd.dclass;
import ddmd.declaration;
import ddmd.expression;
import ddmd.func;
import ddmd.globals;
import ddmd.id;
import ddmd.identifier;
import ddmd.mtype;
import ddmd.statement;
import ddmd.tokens;
import ddmd.visitor;

/**
 * BE stands for BlockExit.
 *
 * It indicates if a statement does transfer control to another block.
 * A block is a sequence of statements enclosed in { }
 */
enum BE : int
{
    BEnone = 0,
    BEfallthru = 1,
    BEthrow    = 2,
    BEreturn   = 4,
    BEgoto     = 8,
    BEhalt     = 0x10,
    BEbreak    = 0x20,
    BEcontinue = 0x40,
    BEerrthrow = 0x80,
    BEany      = (BEfallthru | BEthrow | BEreturn | BEgoto | BEhalt),
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



/*********************************************
 * Only valid after semantic analysis
 * Params:
 *   mustNotThrow = generate an error if it throws
 * Returns:
 *   BExxxx
 */
int blockExit(Statement s, FuncDeclaration func, bool mustNotThrow)
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
                        if (blockExit(s, func, mustNotThrow) != BEhalt && s.hasCode())
                            s.warning("statement is not reachable");
                    }
                    else
                    {
                        result &= ~BEfallthru;
                        result |= blockExit(s, func, mustNotThrow);
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
                    int r = blockExit(s, func, mustNotThrow);
                    result |= r & ~(BEbreak | BEcontinue | BEfallthru);
                    if ((r & (BEfallthru | BEcontinue | BEbreak)) == 0)
                        result &= ~BEfallthru;
                }
            }
        }

        override void visit(ScopeStatement s)
        {
            //printf("ScopeStatement::blockExit(%p)\n", s.statement);
            result = blockExit(s.statement, func, mustNotThrow);
        }

        override void visit(ForwardingStatement s)
        {
            if (s.statement)
            {
                s.statement.accept(this);
            }
            else
            {
                result = BEfallthru;
            }
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
                result = blockExit(s._body, func, mustNotThrow);
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
                result = blockExit(s._init, func, mustNotThrow);
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
                int r = blockExit(s._body, func, mustNotThrow);
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
                result |= blockExit(s._body, func, mustNotThrow) & ~(BEbreak | BEcontinue);
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
                result |= blockExit(s.ifbody, func, mustNotThrow);
            }
            else if (s.condition.isBool(false))
            {
                result |= blockExit(s.elsebody, func, mustNotThrow);
            }
            else
            {
                result |= blockExit(s.ifbody, func, mustNotThrow);
                result |= blockExit(s.elsebody, func, mustNotThrow);
            }
            //printf("IfStatement::blockExit(%p) = x%x\n", s, result);
        }

        override void visit(ConditionalStatement s)
        {
            result = blockExit(s.ifbody, func, mustNotThrow);
            if (s.elsebody)
                result |= blockExit(s.elsebody, func, mustNotThrow);
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
                result |= blockExit(s._body, func, mustNotThrow);
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
            result = blockExit(s.statement, func, mustNotThrow);
        }

        override void visit(DefaultStatement s)
        {
            result = blockExit(s.statement, func, mustNotThrow);
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
            result = blockExit(s._body, func, mustNotThrow);
        }

        override void visit(WithStatement s)
        {
            result = BEnone;
            if (canThrow(s.exp, func, mustNotThrow))
                result = BEthrow;
            result |= blockExit(s._body, func, mustNotThrow);
        }

        override void visit(TryCatchStatement s)
        {
            assert(s._body);
            result = blockExit(s._body, func, false);

            int catchresult = 0;
            foreach (c; *s.catches)
            {
                if (c.type == Type.terror)
                    continue;

                int cresult = blockExit(c.handler, func, mustNotThrow);

                /* If we're catching Object, then there is no throwing
                 */
                Identifier id = c.type.toBasetype().isClassHandle().ident;
                if (c.internalCatch && (cresult & BEfallthru))
                {
                    // https://issues.dlang.org/show_bug.cgi?id=11542
                    // leave blockExit flags of the body
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
                blockExit(s._body, func, mustNotThrow);
            }
            result |= catchresult;
        }

        override void visit(TryFinallyStatement s)
        {
            result = BEfallthru;
            if (s._body)
                result = blockExit(s._body, func, false);

            // check finally body as well, it may throw (bug #4082)
            int finalresult = BEfallthru;
            if (s.finalbody)
                finalresult = blockExit(s.finalbody, func, false);

            // If either body or finalbody halts
            if (result == BEhalt)
                finalresult = BEnone;
            if (finalresult == BEhalt)
                result = BEnone;

            if (mustNotThrow)
            {
                // now explain why this is nothrow
                if (s._body && (result & BEthrow))
                    blockExit(s._body, func, mustNotThrow);
                if (s.finalbody && (finalresult & BEthrow))
                    blockExit(s.finalbody, func, mustNotThrow);
            }

            version (none)
            {
                // https://issues.dlang.org/show_bug.cgi?id=13201
                // Mask to prevent spurious warnings for
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
                // https://issues.dlang.org/show_bug.cgi?id=8675
                // Allow throwing 'Throwable' object even if mustNotThrow.
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
                s.error("`%s` is thrown but not caught", s.exp.type.toChars());

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
            result = blockExit(s.statement, func, mustNotThrow);
            if (s.breaks)
                result |= BEfallthru;
        }

        override void visit(CompoundAsmStatement s)
        {
            if (mustNotThrow && !(s.stc & STCnothrow))
                s.deprecation("asm statement is assumed to throw - mark it with `nothrow` if it does not");

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

    if (!s)
        return BEfallthru;
    scope BlockExit be = new BlockExit(func, mustNotThrow);
    s.accept(be);
    return be.result;
}

