/**
 * Find out in what ways control flow can exit a statement block.
 *
 * Copyright:   Copyright (C) 1999-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/blockexit.d, _blockexit.d)
 * Documentation:  https://dlang.org/phobos/dmd_blockexit.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/blockexit.d
 */

module dmd.blockexit;

import core.stdc.stdio;

import dmd.arraytypes;
import dmd.canthrow;
import dmd.dclass;
import dmd.declaration;
import dmd.expression;
import dmd.func;
import dmd.globals;
import dmd.id;
import dmd.identifier;
import dmd.mtype;
import dmd.statement;
import dmd.tokens;
import dmd.visitor;

/**
 * BE stands for BlockExit.
 *
 * It indicates if a statement does transfer control to another block.
 * A block is a sequence of statements enclosed in { }
 */
enum BE : int
{
    none      = 0,
    fallthru  = 1,
    throw_    = 2,
    return_   = 4,
    goto_     = 8,
    halt      = 0x10,
    break_    = 0x20,
    continue_ = 0x40,
    errthrow  = 0x80,

    /// Found `throw t` inside of a generated `catch(Throwable t)`,
    /// to be resolved to any of `throw_` or `errthrow`
    rethrow   = 0x100,

    any       = (fallthru | throw_ | return_ | goto_ | halt),
}


/*********************************************
 * Determine mask of ways that a statement can exit.
 *
 * Only valid after semantic analysis.
 * Params:
 *   s = statement to check for block exit status
 *   func = function that statement s is in
 *   mustNotThrow = generate an error if it throws
 * Returns:
 *   BE.xxxx
 */
int blockExit(Statement s, FuncDeclaration func, bool mustNotThrow)
{
    extern (C++) final class BlockExit : Visitor
    {
        alias visit = Visitor.visit;
    public:
        FuncDeclaration func;
        bool mustNotThrow;
        bool skippedTry;
        int result;
        TryCatchStatement enclosingTry;
        BlockExit parent; // enclosing visitor for recursive blockExit calls

        extern (D) this(FuncDeclaration func, bool mustNotThrow)
        {
            this.func = func;
            this.mustNotThrow = mustNotThrow;
            result = BE.none;
        }

        override void visit(Statement s)
        {
            printf("Statement::blockExit(%p)\n", s);
            printf("%s\n", s.toChars());
            assert(0);
        }

        override void visit(ErrorStatement s)
        {
            result = BE.none;
        }

        override void visit(ExpStatement s)
        {
            result = BE.fallthru;
            if (s.exp)
            {
                if (s.exp.op == TOK.halt)
                {
                    result = BE.halt;
                    return;
                }
                if (s.exp.op == TOK.assert_)
                {
                    AssertExp a = cast(AssertExp)s.exp;
                    if (a.e1.isBool(false)) // if it's an assert(0)
                    {
                        result = BE.halt;
                        return;
                    }
                }
                if (s.exp.type.toBasetype().isTypeNoreturn())
                    result = BE.halt;
                if (canThrow(s.exp, func, mustNotThrow))
                    result |= BE.throw_;
            }
        }

        override void visit(CompileStatement s)
        {
            assert(global.errors);
            result = BE.fallthru;
        }

        override void visit(CompoundStatement cs)
        {
            //printf("CompoundStatement.blockExit(%p) %d result = x%X\n", cs, cs.statements.dim, result);
            result = BE.fallthru;
            Statement slast = null;
            foreach (s; *cs.statements)
            {
                if (s)
                {
                    //printf("result = x%x\n", result);
                    //printf("s: %s\n", s.toChars());
                    if (result & BE.fallthru && slast)
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

                    if (!(result & BE.fallthru) && !s.comeFrom())
                    {
                        if (blockExit(s, func, mustNotThrow) != BE.halt && s.hasCode())
                            s.warning("statement is not reachable");
                    }
                    else
                    {
                        result &= ~BE.fallthru;
                        result |= blockExit(s, func, mustNotThrow);
                    }
                    slast = s;
                }
            }
        }

        override void visit(UnrolledLoopStatement uls)
        {
            result = BE.fallthru;
            foreach (s; *uls.statements)
            {
                if (s)
                {
                    int r = blockExit(s, func, mustNotThrow);
                    result |= r & ~(BE.break_ | BE.continue_ | BE.fallthru);
                    if ((r & (BE.fallthru | BE.continue_ | BE.break_)) == 0)
                        result &= ~BE.fallthru;
                }
            }
        }

        override void visit(ScopeStatement s)
        {
            //printf("ScopeStatement::blockExit(%p)\n", s.statement);
            result = blockExit(s.statement, func, mustNotThrow);
        }

        override void visit(WhileStatement s)
        {
            assert(global.errors);
            result = BE.fallthru;
        }

        override void visit(DoStatement s)
        {
            if (s._body)
            {
                result = blockExit(s._body, func, mustNotThrow);
                if (result == BE.break_)
                {
                    result = BE.fallthru;
                    return;
                }
                if (result & BE.continue_)
                    result |= BE.fallthru;
            }
            else
                result = BE.fallthru;
            if (result & BE.fallthru)
            {
                if (canThrow(s.condition, func, mustNotThrow))
                    result |= BE.throw_;
                if (!(result & BE.break_) && s.condition.isBool(true))
                    result &= ~BE.fallthru;
            }
            result &= ~(BE.break_ | BE.continue_);
        }

        override void visit(ForStatement s)
        {
            result = BE.fallthru;
            if (s._init)
            {
                result = blockExit(s._init, func, mustNotThrow);
                if (!(result & BE.fallthru))
                    return;
            }
            if (s.condition)
            {
                if (canThrow(s.condition, func, mustNotThrow))
                    result |= BE.throw_;
                if (s.condition.isBool(true))
                    result &= ~BE.fallthru;
                else if (s.condition.isBool(false))
                    return;
            }
            else
                result &= ~BE.fallthru; // the body must do the exiting
            if (s._body)
            {
                int r = blockExit(s._body, func, mustNotThrow);
                if (r & (BE.break_ | BE.goto_))
                    result |= BE.fallthru;
                result |= r & ~(BE.fallthru | BE.break_ | BE.continue_);
            }
            if (s.increment && canThrow(s.increment, func, mustNotThrow))
                result |= BE.throw_;
        }

        override void visit(ForeachStatement s)
        {
            result = BE.fallthru;
            if (canThrow(s.aggr, func, mustNotThrow))
                result |= BE.throw_;
            if (s._body)
                result |= blockExit(s._body, func, mustNotThrow) & ~(BE.break_ | BE.continue_);
        }

        override void visit(ForeachRangeStatement s)
        {
            assert(global.errors);
            result = BE.fallthru;
        }

        override void visit(IfStatement s)
        {
            //printf("IfStatement::blockExit(%p)\n", s);
            result = BE.none;
            if (canThrow(s.condition, func, mustNotThrow))
                result |= BE.throw_;
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
            result = BE.fallthru;
        }

        override void visit(StaticAssertStatement s)
        {
            result = BE.fallthru;
        }

        override void visit(SwitchStatement s)
        {
            result = BE.none;
            if (canThrow(s.condition, func, mustNotThrow))
                result |= BE.throw_;
            if (s._body)
            {
                result |= blockExit(s._body, func, mustNotThrow);
                if (result & BE.break_)
                {
                    result |= BE.fallthru;
                    result &= ~BE.break_;
                }
            }
            else
                result |= BE.fallthru;
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
            result = BE.goto_;
        }

        override void visit(GotoCaseStatement s)
        {
            result = BE.goto_;
        }

        override void visit(SwitchErrorStatement s)
        {
            // Switch errors are non-recoverable
            result = BE.halt;
        }

        override void visit(ReturnStatement s)
        {
            result = BE.return_;
            if (s.exp && canThrow(s.exp, func, mustNotThrow))
                result |= BE.throw_;
        }

        override void visit(BreakStatement s)
        {
            //printf("BreakStatement::blockExit(%p) = x%x\n", s, s.ident ? BE.goto_ : BE.break_);
            result = s.ident ? BE.goto_ : BE.break_;
        }

        override void visit(ContinueStatement s)
        {
            result = s.ident ? BE.continue_ | BE.goto_ : BE.continue_;
        }

        override void visit(SynchronizedStatement s)
        {
            result = blockExit(s._body, func, mustNotThrow);
        }

        override void visit(WithStatement s)
        {
            result = BE.none;
            if (canThrow(s.exp, func, mustNotThrow))
                result = BE.throw_;
            result |= blockExit(s._body, func, mustNotThrow);
        }

        override void visit(TryCatchStatement s)
        {
            assert(s._body);
            assert(!this.enclosingTry);
            this.enclosingTry = s;
            const tryRes = result = blockExit(s._body, func, mustNotThrow);
            this.enclosingTry = null;

            // Possible exceptions were caught by this or enclosing TryCatchStatements
            if (!skippedTry && !(result & BE.rethrow))
                result &= ~BE.throw_;

            foreach (c; *s.catches)
            {
                if (c.type == Type.terror)
                    continue;

                result |= blockExit(c.handler, func, mustNotThrow);
            }

            // Propagate exceptions that were rethrown from an internal handler,
            // `catch(Throwable t) { { <user code> } throw t; }`
            if (result & BE.rethrow)
            {
                result &= ~BE.rethrow;
                result |= tryRes & (BE.throw_ | BE.errthrow);
            }
        }

        override void visit(TryFinallyStatement s)
        {
            result = BE.fallthru;
            if (s._body)
                result = blockExit(s._body, func, false);

            // check finally body as well, it may throw (bug #4082)
            int finalresult = BE.fallthru;
            if (s.finalbody)
                finalresult = blockExit(s.finalbody, func, false);

            // If either body or finalbody halts
            if (result == BE.halt)
                finalresult = BE.none;
            if (finalresult == BE.halt)
                result = BE.none;

            if (mustNotThrow)
            {
                // now explain why this is nothrow
                if (s._body && (result & BE.throw_))
                    blockExit(s._body, func, mustNotThrow);
                if (s.finalbody && (finalresult & BE.throw_))
                    blockExit(s.finalbody, func, mustNotThrow);
            }

            version (none)
            {
                // https://issues.dlang.org/show_bug.cgi?id=13201
                // Mask to prevent spurious warnings for
                // destructor call, exit of synchronized statement, etc.
                if (result == BE.halt && finalresult != BE.halt && s.finalbody && s.finalbody.hasCode())
                {
                    s.finalbody.warning("statement is not reachable");
                }
            }

            if (!(finalresult & BE.fallthru))
                result &= ~BE.fallthru;
            result |= finalresult & ~BE.fallthru;
        }

        override void visit(ScopeGuardStatement s)
        {
            // At this point, this statement is just an empty placeholder
            result = BE.fallthru;
        }

        override void visit(ThrowStatement s)
        {
            if (s.internalThrow)
            {
                // https://issues.dlang.org/show_bug.cgi?id=8675
                // Allow throwing 'Throwable' object even if mustNotThrow.
                result = BE.rethrow;
                return;
            }

            Type t = s.exp.type.toBasetype();
            ClassDeclaration cd = t.isClassHandle();
            assert(cd);

            if (cd == ClassDeclaration.errorException || ClassDeclaration.errorException.isBaseOf(cd, null))
            {
                result = BE.errthrow;
                return;
            }
            const caught = isCaught(s.exp.type);
            if (mustNotThrow && !caught)
            {
                s.error("`%s` is thrown but not caught", s.exp.type.toChars());
            }

            result = BE.throw_;
        }

        override void visit(GotoStatement s)
        {
            //printf("GotoStatement::blockExit(%p)\n", s);
            result = BE.goto_;
        }

        override void visit(LabelStatement s)
        {
            //printf("LabelStatement::blockExit(%p)\n", s);
            result = blockExit(s.statement, func, mustNotThrow);
            if (s.breaks)
                result |= BE.fallthru;
        }

        override void visit(CompoundAsmStatement s)
        {
            // Assume the worst
            result = BE.fallthru | BE.return_ | BE.goto_ | BE.halt;
            if (!(s.stc & STC.nothrow_))
            {
                if (mustNotThrow && !(s.stc & STC.nothrow_))
                    s.deprecation("`asm` statement is assumed to throw - mark it with `nothrow` if it does not");
                else
                    result |= BE.throw_;
            }
        }

        override void visit(ImportStatement s)
        {
            result = BE.fallthru;
        }

        /**
         * Checks whether a thrown exception escapes the current function.
         *
         * Params:
         *   - ex = type of the thrown exception
         *
         * Returns: true if there is an enclosing TryCatchStatement handling `ex`
         */
        extern (D) private bool isCaught(Type ex)
        {
            /// Returns: true if `tc` contains a `catch` matching `ex`
            bool hasHandler(TryCatchStatement tc)
            {
                foreach (catch_; *tc.catches)
                {
                    // Matches exception type?
                    if (!ex.immutableOf().implicitConvTo(catch_.type.immutableOf()))
                        continue;

                    // Only consider user-defined catch-clauses
                    // (internal catches will rethrow the exception in some way)
                    if (catch_.internalCatch && (.blockExit(catch_.handler, func, false) & (BE.throw_ | BE.errthrow | BE.rethrow)))
                        continue;

                    return true;
                }
                return false;
            }

            TryCatchStatement tc;
            for (BlockExit cur = this; cur; cur = cur.parent)
            {
                if (!cur.enclosingTry)
                    continue;

                tc = cur.enclosingTry.isTryCatchStatement();
                assert(tc);
                if (hasHandler(tc))
                    return true;

                cur.skippedTry = true;
            }

            // Went past the blockExit entrypoint, check if other enclosing
            // TryCatchStatements exists and handle `ex`
            for (auto cur = tc ? tc.tryBody : null; cur; )
            {
                if (auto etc = cur.isTryCatchStatement())
                {
                    if (hasHandler(etc))
                        return true;

                    cur = etc.tryBody;
                }
                else
                {
                    auto tf = cur.isTryFinallyStatement();
                    assert(tf);
                    cur = tf.tryBody;
                }
            }
            return false;
        }

        /// `blockExit` wrapper that forwards `skippedTry` from the nested visitor
        extern (D) private int blockExit(Statement s, FuncDeclaration func, bool mustNotThrow)
        {
            if (!s)
                return BE.fallthru;
            scope BlockExit be = new BlockExit(func, mustNotThrow);
            be.parent = this;
            s.accept(be);
            return be.result;
        }

        /// `canThrow` wrapper that updates `mustNotThrow` if a possible exception
        /// cannot escape from the current scope
        extern (D) private bool canThrow(Expression e, FuncDeclaration func, bool mustNotThrow)
        {
            // Future work could update .isCaught to check the concrete type
            if (mustNotThrow)
                mustNotThrow = !isCaught(ClassDeclaration.exception.type);

            return .canThrow(e, func, mustNotThrow);
        }
    }

    if (!s)
        return BE.fallthru;
    scope BlockExit be = new BlockExit(func, mustNotThrow);
    s.accept(be);
    return be.result;
}
