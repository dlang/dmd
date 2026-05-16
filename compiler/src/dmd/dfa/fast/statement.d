/**
 * Statement walker for the fast Data Flow Analysis engine.
 *
 * This module implements the AST visitor that handles Control Flow.
 * It is responsible for:
 * 1. Managing Scopes: Pushing and popping `DFAScope` as it enters/leaves blocks.
 * 2. Handling Branching: Splitting execution for `if` and `switch` statements.
 * 3. Handling Loops: Managing state for `for`, `while`, and `do` loops.
 * 4. Handling Jumps: Resolving `break`, `continue`, `goto`, and `return`.
 *
 * Copyright: Copyright (C) 1999-2026 by The D Language Foundation, All Rights Reserved
 * Authors:   $(LINK2 https://cattermole.co.nz, Richard (Rikki) Andrew Cattermole)
 * License:   $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/dfa/fast/statement.d, dfa/fast/statement.d)
 * Documentation: https://dlang.org/phobos/dmd_dfa_fast_statement.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/dfa/fast/statement.d
 */
module dmd.dfa.fast.statement;
import dmd.dfa.fast.analysis;
import dmd.dfa.fast.report;
import dmd.dfa.fast.expression;
import dmd.dfa.fast.structure;
import dmd.dfa.utils;
import dmd.common.outbuffer;
import dmd.visitor;
import dmd.visitor.foreachvar;
import dmd.location;
import dmd.func;
import dmd.identifier;
import dmd.statement;
import dmd.expression;
import dmd.typesem;
import dmd.timetrace;
import dmd.astenums;
import dmd.mtype;
import dmd.declaration;
import core.stdc.stdio;

/***********************************************************
 * Visits Statement nodes to drive the Data Flow Analysis.
 *
 * This class navigates the structure of the function. When it encounters
 * control flow (like an `if` statement), it acts as a traffic director:
 * 1. It creates a new Scope for the "True" branch.
 * 2. It analyzes that branch.
 * 3. It creates a new Scope for the "False" branch.
 * 4. It analyzes that branch.
 * 5. It calls `analyzer.converge...` to merge the results back together.
 */
extern (D) class StatementWalker : SemanticTimeTransitiveVisitor
{
    alias visit = SemanticTimeTransitiveVisitor.visit;

    DFACommon* dfaCommon;
    ExpressionWalker* expWalker;
    DFAAnalyzer* analyzer;
    int inLoopyLabel;

final:

    void startScope()
    {
        DFAScopeRef scr;
        scr.sc = dfaCommon.currentDFAScope;
        scr.check;
        scr.sc = null;

        dfaCommon.pushScope;
        dfaCommon.printStructure((ref OutBuffer ob, scope PrintPrefixType prefix) => ob.printf("Start scope %p:%p\n",
                dfaCommon.currentDFAScope, dfaCommon.currentDFAScope.parent));
        dfaCommon.sdepth++;
    }

    DFAScopeRef endScope()
    {
        Loc loc;
        return this.endScope(loc);
    }

    DFAScopeRef endScope(ref Loc endLoc, bool handleLabelPopping = true)
    {
        DFAScopeRef ret = dfaCommon.popScope;
        dfaCommon.sdepth--;

        if (handleLabelPopping)
        {
            while (ret.sc.label !is null)
            {
                Loc loc = *cast(Loc*)&ret.sc.label.loc;

                dfaCommon.printStructure((ref OutBuffer ob, scope PrintPrefixType prefix) {
                    ob.printf("End label scope %p:%p %s", ret.sc,
                        dfaCommon.currentDFAScope, ret.sc.label.ident.toChars);
                    if (loc.isValid)
                        appendLoc(ob, loc);
                    ob.writestring("\n");
                });

                ret.printStructure("*=", dfaCommon.sdepth, dfaCommon.currentFunction);
                ret.check;

                seeConvergeStatementLoopyLabels(ret, loc);
                inLoopyLabel--;

                ret = dfaCommon.popScope;
                dfaCommon.sdepth--;
            }
        }

        dfaCommon.printStructure((ref OutBuffer ob, scope PrintPrefixType prefix) {
            ob.printf("End scope %p:%p", ret.sc, dfaCommon.currentDFAScope);
            if (endLoc.isValid)
                appendLoc(ob, endLoc);
            ob.writestring("\n");
        });

        ret.printStructure("*=", dfaCommon.sdepth, dfaCommon.currentFunction);
        ret.check;

        dfaCommon.currentDFAScope.printStructure("parent", dfaCommon.sdepth,
                dfaCommon.currentFunction);
        dfaCommon.currentDFAScope.check;
        return ret;
    }

    DFAScopeRef endScopeAndReport(ref Loc endLoc, bool endFunction = false)
    {
        analyzer.reporter.onEndOfScope(dfaCommon.currentFunction, endLoc);
        if (endFunction)
            analyzer.reporter.onEndOfFunction(dfaCommon.currentFunction, endLoc);

        DFAScopeRef ret = dfaCommon.popScope;
        dfaCommon.sdepth--;

        while (ret.sc.label !is null)
        {
            Loc loc = *cast(Loc*)&ret.sc.label.loc;

            dfaCommon.printStructure((ref OutBuffer ob, scope PrintPrefixType prefix) {
                ob.printf("End label scope %p:%p %s", ret.sc,
                    dfaCommon.currentDFAScope, ret.sc.label.ident.toChars);
                if (loc.isValid)
                    appendLoc(ob, loc);
                ob.writestring("\n");
            });

            ret.printStructure("*=", dfaCommon.sdepth, dfaCommon.currentFunction);
            ret.check;

            seeConvergeStatementLoopyLabels(ret, loc);
            inLoopyLabel--;

            ret = dfaCommon.popScope;
            dfaCommon.sdepth--;
        }

        dfaCommon.printStructure((ref OutBuffer ob, scope PrintPrefixType prefix) {
            ob.printf("End scope %p:%p", ret.sc, dfaCommon.currentDFAScope);
            if (endLoc.isValid)
                appendLoc(ob, endLoc);
            ob.writestring("\n");
        });

        ret.printStructure("*=", dfaCommon.sdepth, dfaCommon.currentFunction);
        ret.check;

        if (dfaCommon.currentDFAScope !is null)
        {
            dfaCommon.currentDFAScope.printStructure("parent",
                    dfaCommon.sdepth, dfaCommon.currentFunction);
            dfaCommon.currentDFAScope.check;
        }
        return ret;
    }

    void seeConvergeStatement(DFAScopeRef scr, bool ignoreWriteCount = false,
            bool unknownAware = false)
    {
        dfaCommon.printStructure((ref OutBuffer ob,
                scope PrintPrefixType prefix) => ob.printf("Converging statement: %d\n",
                unknownAware));
        scr.printStructure("input", dfaCommon.sdepth, dfaCommon.currentFunction);
        scr.check;

        dfaCommon.check;
        dfaCommon.currentDFAScope.printStructure("scope", dfaCommon.sdepth,
                dfaCommon.currentFunction);
        dfaCommon.check;

        analyzer.convergeStatement(scr, true, false, ignoreWriteCount, unknownAware);

        dfaCommon.currentDFAScope.printStructure("so far", dfaCommon.sdepth,
                dfaCommon.currentFunction);
        dfaCommon.currentDFAScope.check;
    }

    void seeConvergeScope(DFAScopeRef scr)
    {
        dfaCommon.printStructure((ref OutBuffer ob,
                scope PrintPrefixType prefix) => ob.printf("Converging scope:\n"));
        scr.printStructure("input", dfaCommon.sdepth, dfaCommon.currentFunction);
        scr.check;

        dfaCommon.check;
        dfaCommon.currentDFAScope.printStructure("scope", dfaCommon.sdepth,
                dfaCommon.currentFunction);
        dfaCommon.check;

        analyzer.convergeScope(scr);

        dfaCommon.currentDFAScope.printStructure("so far", dfaCommon.sdepth,
                dfaCommon.currentFunction);
        dfaCommon.currentDFAScope.check;
    }

    void seeConvergeStatementIf(DFALatticeRef condition, DFAScopeRef scrTrue,
            DFAScopeRef scrFalse, bool haveFalseBody, bool unknownBranchTaken,
            int predicateNegation)
    {
        dfaCommon.printStructure((ref OutBuffer ob, scope PrintPrefixType prefix) => ob.printf(
                "Converging statement if haveFalseBody=%d, unknownBranchTaken=%d, predicateNegation=%d:\n",
                haveFalseBody, unknownBranchTaken, predicateNegation));
        condition.printState("condition", dfaCommon.sdepth, dfaCommon.currentFunction);
        scrTrue.printStructure("true", dfaCommon.sdepth, dfaCommon.currentFunction);
        scrFalse.printStructure("false", dfaCommon.sdepth, dfaCommon.currentFunction);

        dfaCommon.currentDFAScope.printStructure("scope", dfaCommon.sdepth,
                dfaCommon.currentFunction);
        dfaCommon.currentDFAScope.check;

        dfaCommon.check;
        analyzer.convergeStatementIf(condition, scrTrue, scrFalse,
                haveFalseBody, unknownBranchTaken, predicateNegation);
        dfaCommon.check;

        dfaCommon.currentDFAScope.printStructure("so far", dfaCommon.sdepth,
                dfaCommon.currentFunction);
        dfaCommon.currentDFAScope.check;
    }

    void applyGateOnBranch(DFAVar* gateVar, int predicateNegation, bool branch)
    {
        dfaCommon.printStructure((ref OutBuffer ob, scope PrintPrefixType prefix) => ob.printf(
                "Applying gate condition effect on branch %d, predicateNegation=%d for %p:\n",
                branch, predicateNegation, gateVar));

        analyzer.applyGateOnBranch(gateVar, predicateNegation, branch);
        dfaCommon.currentDFAScope.check;
    }

    void seeConvergeStatementLoopyLabels(DFAScopeRef scr)
    {
        Loc loc;
        seeConvergeStatementLoopyLabels(scr, loc);
    }

    void seeConvergeStatementLoopyLabels(DFAScopeRef scr, ref Loc loc)
    {
        dfaCommon.printStructure((ref OutBuffer ob,
                scope PrintPrefixType prefix) => ob.writestring(
                "Converging statement loopy labels:\n"));
        scr.printStructure("input", dfaCommon.sdepth, dfaCommon.currentFunction);
        scr.check;

        dfaCommon.currentDFAScope.printStructure("scope", dfaCommon.sdepth,
                dfaCommon.currentFunction);
        dfaCommon.currentDFAScope.check;

        dfaCommon.check;
        analyzer.convergeStatementLoopyLabels(scr, loc);
        dfaCommon.check;

        dfaCommon.currentDFAScope.printStructure("so far", dfaCommon.sdepth,
                dfaCommon.currentFunction);
        dfaCommon.currentDFAScope.check;
    }

    void seeCheckForCaseBefore(ref DFAScopeRef containing, DFAScopeRef jumpedTo, ref const(Loc) loc)
    {
        dfaCommon.printStructure((ref OutBuffer ob,
                scope PrintPrefixType prefix) => ob.writestring(
                "Check case before & containing state:\n"));

        containing.printStructure("containing");
        containing.check;

        jumpedTo.printStructure("jumpedTo");
        jumpedTo.check;

        dfaCommon.check;
        analyzer.loopyLabelBeforeContainingCheck(containing, jumpedTo, loc);
        dfaCommon.check;
    }

    void seeConvergeForwardGoto(DFAScopeRef scr)
    {
        dfaCommon.printStructure((ref OutBuffer ob,
                scope PrintPrefixType prefix) => ob.writestring("Converging forward goto:\n"));
        scr.printStructure("input", dfaCommon.sdepth, dfaCommon.currentFunction);
        scr.check;

        dfaCommon.currentDFAScope.printStructure("scope", dfaCommon.sdepth,
                dfaCommon.currentFunction);
        dfaCommon.currentDFAScope.check;

        dfaCommon.check;
        analyzer.convergeStatement(scr, false);
        dfaCommon.check;

        dfaCommon.currentDFAScope.printStructure("so far", dfaCommon.sdepth,
                dfaCommon.currentFunction);
        dfaCommon.currentDFAScope.check;
    }

    DFAScopeRef seeLoopyLabelAwareStage(DFAScopeRef previous, DFAScopeRef next)
    {
        dfaCommon.printStructure((ref OutBuffer ob,
                scope PrintPrefixType prefix) => ob.writestring("Loop stage:\n"));
        previous.printStructure("previous", dfaCommon.sdepth, dfaCommon.currentFunction);
        next.printStructure("next", dfaCommon.sdepth, dfaCommon.currentFunction);

        dfaCommon.check;
        DFAScopeRef ret = analyzer.transferLoopyLabelAwareStage(previous, next);
        dfaCommon.check;

        ret.printStructure("result", dfaCommon.sdepth, dfaCommon.currentFunction);
        return ret;
    }

    void seeGoto(DFAScope* toSc, bool isAfter)
    {
        dfaCommon.printStructure((ref OutBuffer ob,
                scope PrintPrefixType prefix) => ob.printf(
                "Going to scope adding state after=%d\n", isAfter));

        dfaCommon.check;
        analyzer.transferGoto(toSc, isAfter);
        dfaCommon.check;
    }

    void seeForwardsGoto(Identifier ident)
    {
        dfaCommon.printStructure((ref OutBuffer ob,
                scope PrintPrefixType prefix) => ob.printf("Going to label %s\n", ident.toChars));

        dfaCommon.check;
        analyzer.transferForwardsGoto(ident);
        dfaCommon.check;
    }

    void seeRead(ref DFALatticeRef lr, ref Loc loc)
    {
        dfaCommon.printStructureln("Seeing read of lr");
        lr.printState("read lr", dfaCommon.sdepth, dfaCommon.currentFunction, dfaCommon.edepth);

        analyzer.onRead(lr, loc);
    }

    void constructVariable(VarDeclaration vd, bool isNonNull)
    {
        DFAVar* var = dfaCommon.findVariable(vd);

        DFALatticeRef lr = dfaCommon.makeLatticeRef;
        DFAConsequence* c = lr.addConsequence(var);
        lr.setContext(c);
        c.nullable = isNonNull ? Nullable.NonNull : Nullable.Null;

        dfaCommon.check;
        expWalker.seeConvergeExpression(expWalker.seeAssign(var, true, lr, *cast(Loc*)&vd.loc));
        dfaCommon.check;
    }

    void start(FuncDeclaration fd)
    {
        dfaCommon.currentFunction = fd;

        dfaCommon.printStructure((ref OutBuffer ob, scope PrintPrefixType prefix) {
            ob.printf("Starting DFA walk on %s at ", fd.ident.toChars);
            appendLoc(ob, fd.loc);
            ob.writestring("\n");
        });

        timeTraceBeginEvent(TimeTraceEventType.dfa);
        scope (exit)
            timeTraceEndEvent(TimeTraceEventType.dfa, fd);

        this.startScope;
        dfaCommon.setScopeAsLoopyLabel;

        dfaCommon.check;
        DFAScopeVar* scv;

        {
            if (fd.parametersDFAInfo is null)
                fd.parametersDFAInfo = new ParametersDFAInfo;

            if (fd.vthis !is null)
            {
                DFAVar* var = dfaCommon.findVariable(fd.vthis);
                var.declaredAtDepth = dfaCommon.currentDFAScope.depth;
                var.writeCount = 1;
                var.param = &fd.parametersDFAInfo.thisPointer;
                var.param.parameterId = -1;
                scv = dfaCommon.acquireScopeVar(var);

                dfaCommon.printStructure((ref OutBuffer ob,
                        scope PrintPrefixType prefix) => ob.printf("vthis is %p scv %p\n",
                        var, scv));
                assert(scv.var is var);

                DFAScopeVar* scv2 = dfaCommon.currentDFAScope.findScopeVar(var);
                assert(scv is scv2);

                dfaCommon.check;
            }

            if (fd.parameters !is null)
            {
                if (fd.parametersDFAInfo.parameters.length != fd.parameters.length)
                    fd.parametersDFAInfo.parameters.length = fd.parameters.length;

                foreach (i, param; *fd.parameters)
                {
                    DFAVar* var = dfaCommon.findVariable(param);
                    var.declaredAtDepth = dfaCommon.currentDFAScope.depth;
                    var.writeCount = 1;
                    var.param = &fd.parametersDFAInfo.parameters[i];
                    *var.param = ParameterDFAInfo.init; // Array won't initialize it
                    var.param.parameterId = cast(int) i;
                    scv = dfaCommon.acquireScopeVar(var);

                    dfaCommon.printStructure((ref OutBuffer ob,
                            scope PrintPrefixType prefix) => ob.printf("param (%zd) is `%s` %p scv %p stc %lld\n",
                            i, param.ident !is null ? param.ident.toChars : null,
                            var, scv, param.storage_class));
                    assert(scv.var is var);

                    DFAScopeVar* scv2 = dfaCommon.currentDFAScope.findScopeVar(var);
                    assert(scv is scv2);

                    var.isByRef = (param.storage_class & STC.ref_) == STC.ref_;

                    if ((param.storage_class & STC.out_) == STC.out_)
                    {
                        var.isByRef = true;

                        // blit is effectively a write
                        var.writeCount = 1;
                    }

                    dfaCommon.check;
                }
            }

            if (fd.v_argptr !is null)
            {
                // C vararg _argptr
                DFAVar* var = dfaCommon.findVariable(fd.v_argptr);
                var.unmodellable = true;
            }

            if (fd.v_arguments !is null)
            {
                // D vararg _arguments
                DFAVar* var = dfaCommon.findVariable(fd.v_arguments);
                var.unmodellable = true;
            }
        }

        {
            DFAVar* var = dfaCommon.getReturnVariable();
            var.declaredAtDepth = dfaCommon.currentDFAScope.depth;
            var.writeCount = 1;
            var.param = &fd.parametersDFAInfo.returnValue;
            var.param.parameterId = -2;

            TypeFunction tf = fd.type.isTypeFunction();
            assert(tf !is null);

            var.isNullable = tf.isRef || isTypeNullable(tf.next);
            scv = dfaCommon.acquireScopeVar(var);

            dfaCommon.printStructure((ref OutBuffer ob,
                    scope PrintPrefixType prefix) => ob.printf("return is %p scv %p l %p\n",
                    var, scv, scv.lr.lattice));
            assert(scv.var is var);

            DFAScopeVar* scv2 = dfaCommon.currentDFAScope.findScopeVar(var);
            assert(scv is scv2);

            dfaCommon.check;
        }

        {
            // make any variables that cross the function boundary for nested function unmodelled

            foreach (vd; fd.closureVars)
            {
                DFAVar* var = dfaCommon.findVariable(vd);
                var.unmodellable = true;
                dfaCommon.printStructure((ref OutBuffer ob, scope PrintPrefixType prefix) {
                    ob.printf("closureVars %s ", vd.ident.toChars);
                    appendLoc(ob, vd.loc);
                    ob.writestring("\n");
                });
            }

            foreach (vd; fd.outerVars)
            {
                DFAVar* var = dfaCommon.findVariable(vd);
                var.unmodellable = true;

                dfaCommon.printStructure((ref OutBuffer ob, scope PrintPrefixType prefix) {
                    ob.printf("outerVars %s ", vd.ident.toChars);
                    appendLoc(ob, vd.loc);
                    ob.writestring("\n");
                });
            }
        }

        this.visit(fd.fbody);

        // implicit return
        // endScope call automatically infers/validates scope on to function.
        dfaCommon.currentDFAScope.haveJumped = true;
        dfaCommon.currentDFAScope.haveReturned = true;
        this.endScopeAndReport(fd.endloc, true);

        dfaCommon.printIfStructure((ref OutBuffer ob, scope void delegate(const(char)*) prefix) {
            dfaCommon.allocator.allVariables((DFAVar* var) {
                prefix("var");
                ob.printf(" %p base1=%p, base2=%p", var, var.base1, var.base2);

                if (var.var !is null)
                {
                    ob.printf(", `%s` at ", var.var.ident.toChars);
                    appendLoc(ob, var.var.loc);
                }

                ob.printf("\n");
            });
            dfaCommon.allocator.allObjects((DFAObject* obj) {
                prefix("object");
                ob.printf(" %p base1=%p, base2=%p, storageFor=%p, mayNotBeExactPointer=%d\n", obj,
                obj.base1, obj.base2, obj.storageFor, obj.mayNotBeExactPointer);
            });
        });

        if (fd.parametersDFAInfo !is null)
        {
            dfaCommon.printStructure((ref OutBuffer ob, scope PrintPrefixType prefix) {
                ob.printf("return=%d:%d", fd.parametersDFAInfo.returnValue.notNullIn,
                    fd.parametersDFAInfo.returnValue.notNullOut);
                ob.writestring("\n");

                ob.printf("this=%d:%d", fd.parametersDFAInfo.thisPointer.notNullIn,
                    fd.parametersDFAInfo.thisPointer.notNullOut);
                ob.writestring("\n");

                foreach (i, param; fd.parametersDFAInfo.parameters)
                {
                    ob.printf("%zd: %d:%d", i, param.notNullIn, param.notNullOut);
                    ob.writestring("\n");
                }
            });
        }
    }

    extern (C++) override void visit(Statement st)
    {
        __gshared immutable(string[]) AllStmtOpNames = [
            __traits(allMembers, STMT)
        ];

        if (st is null)
            return;

        dfaCommon.sdepth++;
        dfaCommon.check;

        scope (exit)
        {
            dfaCommon.check;
            dfaCommon.sdepth--;
        }

        if (dfaCommon.currentDFAScope.haveReturned)
        {
            dfaCommon.printStructure((ref OutBuffer ob, scope PrintPrefixType prefix) {
                ob.printf("%3d (%s): ignoring at ", st.stmt, AllStmtOpNames[st.stmt].ptr);
                appendLoc(ob, st.loc);
                ob.writestring("\n");
            });
            return;
        }

        dfaCommon.printStructure((ref OutBuffer ob, scope PrintPrefixType prefix) {
            ob.printf("%3d (%s): at ", st.stmt, AllStmtOpNames[st.stmt].ptr);
            appendLoc(ob, st.loc);
            ob.writestring("\n");
        });

        /*
        If you need to see the state of the engine, enable this and set the line number here.
        Also remember to set the function name in entry,
         and to enable dfaCommon.debugStructure to true with dfaCommon.debugIt set to false,
         otherwise you will get lost in the output.
        */
        version (none)
        {
            if (st.loc.linnum == 423)
            {
                DFAScope* sc = dfaCommon.currentDFAScope;
                while (sc !is null)
                {
                    sc.printStructure("----");
                    sc = sc.parent;
                }

                fflush(stdout);
                assert(0);
            }
        }

        final switch (st.stmt)
        {
        case STMT.DtorExp:
            expWalker.seeConvergeExpression(expWalker.walk(st.isDtorExpStatement.exp));
            break;

        case STMT.Exp:
            Expression exp = st.isExpStatement.exp;

            DFALatticeRef lr = expWalker.walk(exp);
            seeRead(lr, exp.loc);
            expWalker.seeConvergeExpression(lr);
            break;
        case STMT.Return:
            Expression exp = st.isReturnStatement.exp;

            if (exp !is null)
            {
                DFALatticeRef lr = expWalker.seeAssign(dfaCommon.getReturnVariable,
                        true, expWalker.walk(exp), exp.loc);
                expWalker.seeConvergeExpression(lr);
            }

            // Mark the current scope as having returned.
            // This signals that no code after this point in the current block is reachable.
            dfaCommon.currentDFAScope.haveJumped = true;
            dfaCommon.currentDFAScope.haveReturned = true;
            analyzer.reporter.onEndOfScope(dfaCommon.currentFunction, st.loc);
            break;

        case STMT.Compound:
            auto cs = st.isCompoundStatement;
            if (cs.statements is null)
                break;

            // We need to know which statement we are in and what the next ones are
            // so that we can find labels and run finally statements

            dfaCommon.printStructureln("Compound statements:");
            this.startScope;
            dfaCommon.currentDFAScope.compoundStatement = cs;

            foreach (i, st2; *cs.statements)
            {
                dfaCommon.printStructureln("Compound statement:");
                dfaCommon.currentDFAScope.inProgressCompoundStatement = i;
                this.visit(st2);

                if (dfaCommon.currentDFAScope.haveReturned)
                {
                    dfaCommon.printStructureln("Compound returned");
                    break;
                }
            }

            DFAScopeRef scr = this.endScope;

            dfaCommon.printStructureln("Compound converge:");
            this.seeConvergeScope(scr);
            break;

        case STMT.If:
            auto ifs = st.isIfStatement;
            auto origScope = dfaCommon.currentDFAScope;

            dfaCommon.printStructure((ref OutBuffer ob, scope PrintPrefixType prefix) {
                ob.printf("If statement %p:%p ", dfaCommon.currentDFAScope, origScope);
                appendLoc(ob, ifs.loc);
                ob.writestring("\n");
            });

            // CRITICAL: We split the analysis here.
            // 1. We analyze the condition to see if it implies anything about variables
            //    (e.g., `if (ptr)` implies `ptr` is NonNull in the true branch).
            // 2. We visit the `ifbody` with that knowledge.
            // 3. We visit the `elsebody` (if it exists).
            // 4. We merge the resulting states from both branches.

            bool takeTrueBranch, takeFalseBranch;
            bool unknownBranchTaken;

            dfaCommon.printStructureln("If condition:");
            int predicateNegation;
            DFALatticeRef conditionLR;
            DFALatticeRef trueCondition, falseCondition;
            DFAVar* conditionVar;

            {
                this.startScope;
                dfaCommon.currentDFAScope.sideEffectFree = true;

                conditionLR = expWalker.walkCondition(ifs.condition, predicateNegation);
                conditionVar = conditionLR.getGateConsequenceVariable;

                seeRead(conditionLR, ifs.condition.loc);
                this.endScope;
            }

            {
                trueCondition = expWalker.adaptConditionForBranch(conditionLR.copy,
                        ifs.condition.type, true);
                falseCondition = expWalker.adaptConditionForBranch(conditionLR.copy,
                        ifs.condition.type, false);

                this.isBranchTakenIf(trueCondition, falseCondition, ifs,
                        takeTrueBranch, takeFalseBranch);

                DFAConsequence* cctx = conditionLR.getContext;
                if (cctx is null || cctx.truthiness <= Truthiness.Maybe)
                    unknownBranchTaken = true;

                version (none)
                {
                    printf("if %d %d %d\n", takeTrueBranch, takeFalseBranch, unknownBranchTaken);
                    conditionLR.printStructure("condition");
                    trueCondition.printStructure("true condition");
                    falseCondition.printStructure("false condition");
                }
            }

            {
                dfaCommon.printStructureln("If true branch:");
                this.startScope;
                dfaCommon.currentDFAScope.inConditional = true;

                expWalker.seeSilentAssert(trueCondition, true, true);
                this.applyGateOnBranch(conditionVar, predicateNegation, true);
            }

            DFAScopeRef ifbody, elsebody;

            if (takeTrueBranch)
            {
                if (auto scs = ifs.ifbody.isScopeStatement)
                    this.visit(scs.statement);
                else
                    this.visit(ifs.ifbody);

                assert(dfaCommon.currentDFAScope !is origScope);

                ifbody = this.endScope;
                ifbody.check;
            }
            else
            {
                this.endScope;
                dfaCommon.printStructure((ref OutBuffer ob,
                        scope PrintPrefixType prefix) => ob.writestring("true ignored\n"));
            }

            assert(dfaCommon.currentDFAScope is origScope);

            {
                dfaCommon.printStructureln("If false branch:");

                this.startScope;
                dfaCommon.currentDFAScope.inConditional = true;

                // If the true branch can be taken, the false branch needs the condition inverted.
                // But if it won't be taken, its clearly false already no need to invert.
                if (takeTrueBranch)
                    expWalker.seeSilentAssert(falseCondition, true, true);

                this.applyGateOnBranch(conditionVar, predicateNegation, false);

                if (takeFalseBranch)
                {
                    if (auto scs = ifs.elsebody.isScopeStatement)
                        this.visit(scs.statement);
                    else
                        this.visit(ifs.elsebody);
                }

                elsebody = this.endScope;
                elsebody.check;
            }

            seeConvergeStatementIf(conditionLR, ifbody, elsebody,
                    takeFalseBranch, unknownBranchTaken, predicateNegation);
            break;

        case STMT.Scope:
            auto sc = st.isScopeStatement;

            dfaCommon.printStructure((ref OutBuffer ob, scope PrintPrefixType prefix) {
                ob.writestring("Starting scope body at ");
                appendLoc(ob, sc.loc);
                ob.writestring("\n");
            });

            this.startScope;
            this.visit(sc.statement);

            dfaCommon.printStructure((ref OutBuffer ob, scope PrintPrefixType prefix) {
                ob.writestring("Completed scope body at ");
                appendLoc(ob, sc.endloc);
                ob.writestring("\n");
            });

            DFAScopeRef scbody = this.endScope;
            this.seeConvergeScope(scbody);
            break;

        case STMT.Label:
            // Note: it is the responsibility of endScope to handle poping these scopes off
            auto ls = st.isLabelStatement;
            dfaCommon.printStructure((ref OutBuffer ob,
                    scope PrintPrefixType prefix) => ob.printf("label %s %p %p\n",
                    ls.ident !is null ? ls.ident.toChars : null, ls.gotoTarget, ls.gotoTarget));

            inLoopyLabel++;

            this.startScope;
            dfaCommon.currentDFAScope.label = ls;
            dfaCommon.setScopeAsLoopyLabel;
            dfaCommon.currentDFAScope.isLoopyLabelKnownToHaveRun = true;

            {
                // sometimes we can by-pass needing to look up the for loop
                dfaCommon.currentDFAScope.controlStatement = ls.gotoTarget !is null
                    ? ls.gotoTarget.isForStatement : null;

                if (dfaCommon.currentDFAScope.controlStatement is null && ls.statement !is null)
                {
                    if (dfaCommon.currentDFAScope.controlStatement is null)
                        dfaCommon.currentDFAScope.controlStatement = ls.statement.isForStatement;
                    if (dfaCommon.currentDFAScope.controlStatement is null)
                        dfaCommon.currentDFAScope.controlStatement = ls.statement.isDoStatement;
                    if (dfaCommon.currentDFAScope.controlStatement is null)
                        dfaCommon.currentDFAScope.controlStatement = ls.statement.isSwitchStatement;
                }
            }

            dfaCommon.swapForwardLabelScope(ls.ident, (old) {
                if (!old.isNull)
                    this.seeConvergeForwardGoto(old);
                return DFAScopeRef.init;
            });

            DFAScopeRef scr;

            // by-pass scope statement processing with a dedicated variation here.
            if (ls.statement is null)
            {
            }
            else if (auto scs = ls.statement.isScopeStatement)
            {
                this.visit(scs.statement);
                scr = this.endScope(*cast(Loc*)&ls.loc, false);
                inLoopyLabel--;
            }
            else
            {
                this.visit(ls.statement);
            }

            if (!scr.isNull)
                seeConvergeStatementLoopyLabels(scr, *cast(Loc*)&ls.loc);
            break;

        case STMT.For:
            auto fs = st.isForStatement;
            // fs._init should be handled already

            dfaCommon.printStructure((ref OutBuffer ob, scope PrintPrefixType prefix) {
                ob.writestring("starting for loop at ");
                appendLoc(ob, fs.endloc);
                ob.writestring("\n");
            });

            // Loops are handled by creating a "LoopyLabel" scope.
            // This allows `break` and `continue` statements inside the loop
            // to find this scope and update the state accordingly.
            //
            // Since this is a single-pass engine, we do not iterate until convergence.
            // Instead, we analyze the body once, and then use `convergeStatementLoopyLabels`
            // to assume the worst-case scenario for variables modified in the loop.

            inLoopyLabel++;
            scope (exit)
                inLoopyLabel--;

            Expression theCondition = fs.condition;
            Statement theBody = fs._body;

            /*
            Check to see if the for statement is a while loop.
            for(;true;) {
                if (condition) {
                    ...
                } else {
                    break;
                }
            }
            May also be:
            for(;condition;) {
                ...
            }
            */
            if (theCondition !is null)
            {
                auto ie = theCondition.isIntegerExp;

                if (ie !is null && ie.type is Type.tbool && ie.getInteger == 1)
                {
                    auto ifs = theBody.isIfStatement;

                    if (ifs !is null && ifs.elsebody !is null && ifs.elsebody.isBreakStatement)
                    {
                        // Okay this is actually a while loop

                        theCondition = ifs.condition;
                        theBody = ifs.ifbody;
                    }
                }
            }

            DFALatticeRef lrCondition;
            DFALatticeRef lrConditionTrue;

            if (theCondition !is null)
            {
                lrCondition = expWalker.walk(theCondition);
                seeRead(lrCondition, theCondition.loc);
                lrCondition.printStructure("lrCondition");

                lrConditionTrue = expWalker.adaptConditionForBranch(lrCondition.copy,
                        theCondition.type, true);
                lrConditionTrue.printStructure("lrConditionTrue");
            }

            if (theCondition is null || isBranchTaken(lrConditionTrue, theBody))
            {
                this.startScope;
                dfaCommon.currentDFAScope.controlStatement = st;
                dfaCommon.currentDFAScope.inConditional = true;
                dfaCommon.setScopeAsLoopyLabel;

                if (theCondition !is null)
                {
                    dfaCommon.printStructure((ref OutBuffer ob,
                            scope PrintPrefixType prefix) => ob.writestring("For condition:\n"));

                    if (auto c = lrConditionTrue.getContext)
                    {
                        dfaCommon.currentDFAScope.isLoopyLabelKnownToHaveRun
                            = c.truthiness == Truthiness.True;
                    }

                    expWalker.seeAssert(lrConditionTrue, theCondition.loc, true);
                }
                else
                    dfaCommon.currentDFAScope.isLoopyLabelKnownToHaveRun = true;

                dfaCommon.printStructure((ref OutBuffer ob,
                        scope PrintPrefixType prefix) => ob.writestring("For body:\n"));
                this.visit(theBody);

                if (!dfaCommon.currentDFAScope.haveJumped)
                {
                    dfaCommon.printStructure((ref OutBuffer ob,
                            scope PrintPrefixType prefix) => ob.writestring("For increment:\n"));
                    DFALatticeRef lrIncrement = expWalker.walk(fs.increment);
                    seeRead(lrIncrement, fs.increment.loc);
                    expWalker.seeConvergeExpression(lrIncrement);
                }

                DFAScopeRef scr = this.endScopeAndReport(fs.endloc);
                assert(!scr.isNull);
                this.seeConvergeStatementLoopyLabels(scr, *cast(Loc*)&fs.loc);

                dfaCommon.printStructure((ref OutBuffer ob,
                        scope PrintPrefixType prefix) => ob.writestring(
                        "For (effect) condition:\n"));

                if (theCondition !is null)
                {
                    DFALatticeRef lrConditionFalse = expWalker.adaptConditionForBranch(lrCondition,
                            theCondition.type, false);
                    expWalker.seeSilentAssert(lrConditionFalse, true, true);
                }

                dfaCommon.printStructure((ref OutBuffer ob, scope PrintPrefixType prefix) {
                    ob.writestring("finished for loop at ");
                    appendLoc(ob, fs.endloc);
                    ob.writestring("\n");
                });
            }

            break;

        case STMT.Do:
            auto ds = st.isDoStatement;

            inLoopyLabel++;
            scope (exit)
                inLoopyLabel--;

            this.startScope;
            dfaCommon.currentDFAScope.controlStatement = st;
            dfaCommon.setScopeAsLoopyLabel;
            dfaCommon.currentDFAScope.isLoopyLabelKnownToHaveRun = true;
            dfaCommon.currentDFAScope.inConditional = true;

            this.visit(ds._body);

            DFALatticeRef lrCondition = expWalker.walk(ds.condition);
            seeRead(lrCondition, ds.condition.loc);
            expWalker.seeSilentAssert(lrCondition, false, true);

            DFAScopeRef scr = this.endScope(ds.endloc);
            this.seeConvergeStatementLoopyLabels(scr, *cast(Loc*)&ds.loc);
            break;

        case STMT.UnrolledLoop:
            auto uls = st.isUnrolledLoopStatement;

            inLoopyLabel++;
            scope (exit)
                inLoopyLabel--;

            if (uls.statements !is null && uls.statements.length > 0)
            {
                this.startScope;

                dfaCommon.currentDFAScope.controlStatement = st;
                dfaCommon.setScopeAsLoopyLabel;

                foreach (stmt; *uls.statements)
                {
                    this.startScope;
                    this.visit(stmt);

                    DFAScopeRef scr = this.endScope;

                    if (scr.sc.haveReturned)
                    {
                        this.seeConvergeScope(scr);
                        break;
                    }
                    else
                        this.seeConvergeScope(scr);
                }

                DFAScopeRef scr = this.endScope();
                this.seeConvergeStatementLoopyLabels(scr);
            }

            break;

        case STMT.Switch:
            auto ss = st.isSwitchStatement;

            this.startScope;
            dfaCommon.currentDFAScope.controlStatement = ss;
            dfaCommon.currentDFAScope.inConditional = true;

            DFALatticeRef lrCondition = expWalker.walk(ss.condition);
            lrCondition.check;
            seeRead(lrCondition, ss.condition.loc);

            DFAScope* oldScope = dfaCommon.currentDFAScope;

            {
                // initial pass over the case bodies

                if (ss.sdefault !is null)
                {
                    DFACaseState* caState = dfaCommon.acquireCaseState(ss.sdefault);

                    this.startScope;
                    dfaCommon.currentDFAScope.controlStatement = ss.sdefault;
                    dfaCommon.setScopeAsLoopyLabel;

                    lrCondition.check;
                    DFALatticeRef lrCondition2 = lrCondition.copy;
                    lrCondition2.check;
                    expWalker.seeConvergeExpression(lrCondition2);

                    if (ss.sdefault.statement !is null)
                    {
                        if (auto scs = ss.sdefault.statement.isScopeStatement)
                            this.visit(scs.statement);
                        else
                            this.visit(ss.sdefault.statement);
                    }

                    caState.containing = this.endScope;
                    assert(dfaCommon.currentDFAScope is oldScope);
                }

                if (ss.cases !is null)
                {
                    foreach (cs; *ss.cases)
                    {
                        DFACaseState* caState = dfaCommon.acquireCaseState(cs);
                        this.startScope;

                        dfaCommon.currentDFAScope.controlStatement = cs;
                        dfaCommon.setScopeAsLoopyLabel;

                        DFALatticeRef equalTo = expWalker.walk(cs.exp);
                        lrCondition.check;
                        DFALatticeRef lrCondition2 = lrCondition.copy;
                        lrCondition2.check;

                        expWalker.seeConvergeExpression(expWalker.seeEqual(lrCondition2, equalTo, true,
                                ss.condition.type.toBasetype, cs.exp.type.toBasetype));

                        if (auto scs = cs.statement.isScopeStatement)
                            this.visit(scs.statement);
                        else
                            this.visit(cs.statement);

                        caState.containing = this.endScope;
                        assert(dfaCommon.currentDFAScope is oldScope);
                    }
                }
            }

            {
                DFAScopeRef inProgress;

                // now let's make sure that nobody has done something bad wrt. input state

                if (ss.sdefault !is null)
                {
                    DFACaseState* caState = dfaCommon.acquireCaseState(ss.sdefault);

                    if (!caState.jumpedTo.isNull)
                        this.seeCheckForCaseBefore(caState.containing,
                                caState.jumpedTo, ss.sdefault.loc);

                    inProgress = this.seeLoopyLabelAwareStage(inProgress, caState.containing);
                }

                if (ss.cases !is null)
                {
                    foreach (cs; *ss.cases)
                    {
                        DFACaseState* caState = dfaCommon.acquireCaseState(cs);

                        if (!caState.jumpedTo.isNull)
                            this.seeCheckForCaseBefore(caState.containing,
                                    caState.jumpedTo, cs.loc);

                        inProgress = this.seeLoopyLabelAwareStage(inProgress, caState.containing);
                    }
                }

                if (!inProgress.isNull)
                {
                    this.seeConvergeScope(inProgress);
                }
            }

            DFAScopeRef scr = this.endScope(ss.endloc);
            this.seeConvergeScope(scr);
            break;

        case STMT.Continue:
            auto cs = st.isContinueStatement;
            dfaCommon.printStructure((ref OutBuffer ob, scope PrintPrefixType prefix) => ob.printf(
                    "Continue statement %s\n", cs.ident !is null ? cs.ident.toChars : null));

            auto sc = dfaCommon.findScopeGivenLabel(cs.ident);
            assert(sc !is null);

            if (!dfaCommon.debugUnknownAST && sc.controlStatement is null)
                break;
            else
                assert(sc.controlStatement !is null);

            {
                // Look for control statements in the scope stack,
                //  specifically for a control statement that does not match the one for the continue.
                // This covers things like if statements.
                bool haveParentControlStatement;
                DFAScope* parentScope = dfaCommon.currentDFAScope;

                while (parentScope !is sc)
                {
                    if (parentScope.controlStatement !is null
                            && parentScope.controlStatement !is sc.controlStatement)
                    {
                        haveParentControlStatement = true;
                        break;
                    }

                    parentScope = parentScope.parent;
                }

                if (haveParentControlStatement)
                    dfaCommon.currentDFAScope.haveJumped = true;
            }

            if (auto forLoop = sc.controlStatement.isForStatement)
            {
                DFALatticeRef lr = expWalker.walk(forLoop.increment);
                expWalker.seeConvergeExpression(lr);
            }

            seeGoto(sc, false);
            runFinalizersUntilScope(sc);
            break;

        case STMT.Break:
            auto bs = st.isBreakStatement;
            dfaCommon.printStructure((ref OutBuffer ob,
                    scope PrintPrefixType prefix) => ob.printf("Break statement %s\n",
                    bs.ident !is null ? bs.ident.toChars : null));

            auto sc = dfaCommon.findScopeGivenLabel(bs.ident);
            assert(sc !is null);

            if (!dfaCommon.debugUnknownAST && sc.controlStatement is null)
                break;
            else
                assert(sc.controlStatement !is null);

            {
                // Look for control statements in the scope stack,
                //  specifically for a control statement that does not match the one for the break.
                // This covers things like if statements.
                bool haveParentControlStatement;
                DFAScope* parentScope = dfaCommon.currentDFAScope;

                while (parentScope !is sc)
                {
                    if (parentScope.controlStatement !is null
                            && parentScope.controlStatement !is sc.controlStatement)
                    {
                        haveParentControlStatement = true;
                        break;
                    }

                    parentScope = parentScope.parent;
                }

                if (haveParentControlStatement)
                    dfaCommon.currentDFAScope.haveJumped = true;
            }

            seeGoto(sc, true);
            runFinalizersUntilScope(sc);
            break;

        case STMT.Case:
            break; // do nothing, already handled in switch statement

        case STMT.GotoDefault:
            auto gds = st.isGotoDefaultStatement;

            auto targetScope = dfaCommon.findScopeForControlStatement(gds.sw);
            assert(targetScope !is null);

            targetScope = targetScope.child; // into the case statement
            assert(targetScope !is null);
            assert(targetScope.controlStatement.isCaseStatement !is null
                    || targetScope.controlStatement.isDefaultStatement !is null);

            this.runFinalizersUntilScope(targetScope);

            DFACaseState* caState = dfaCommon.acquireCaseState(gds.sw.sdefault);
            caState.jumpedTo = this.seeLoopyLabelAwareStage(caState.jumpedTo, targetScope.copy);
            break;

        case STMT.GotoCase:
            auto gcs = st.isGotoCaseStatement;
            dfaCommon.printStructure((ref OutBuffer ob,
                    scope PrintPrefixType prefix) => ob.printf("Goto case statement target %p\n",
                    gcs.cs));

            DFAScope* targetScope;
            auto sw = dfaCommon.findSwitchGivenCase(gcs.cs, targetScope);
            assert(sw !is null);
            assert(targetScope !is null);

            this.runFinalizersUntilScope(targetScope);

            DFACaseState* caState = dfaCommon.acquireCaseState(gcs.cs);
            caState.jumpedTo = this.seeLoopyLabelAwareStage(caState.jumpedTo, targetScope.copy);
            break;

        case STMT.TryFinally:
            auto tfs = st.isTryFinallyStatement;
            dfaCommon.printStructure((ref OutBuffer ob,
                    scope PrintPrefixType prefix) => ob.printf("try finally %p %p\n",
                    tfs._body, tfs.finalbody));

            this.startScope;
            dfaCommon.currentDFAScope.tryFinallyStatement = tfs;

            // normal path execute both
            this.visit(tfs._body);
            this.visit(tfs.finalbody);

            dfaCommon.currentDFAScope.tryFinallyStatement = null;

            DFAScopeRef scr = this.endScope;
            this.seeConvergeScope(scr);
            break;

        case STMT.Goto:
            auto gs = st.isGotoStatement;
            dfaCommon.currentDFAScope.haveJumped = true;

            auto sc = dfaCommon.findScopeGivenLabel(gs.ident);

            if (sc !is null)
            {
                // backwards goto
                seeGoto(sc, false);
            }
            else
                seeForwardsGoto(gs.ident);
            break;

        case STMT.Import:
            break; // do nothing

        case STMT.With:
            auto ws = st.isWithStatement;

            this.startScope;

            DFALatticeRef lr = expWalker.walk(ws.exp);
            seeRead(lr, ws.exp.loc);
            expWalker.seeConvergeExpression(lr);

            if (auto ss = ws._body.isScopeStatement)
                this.visit(ss.statement);
            else
                this.visit(ws._body);

            DFAScopeRef scr = this.endScope(ws.endloc);
            this.seeConvergeScope(scr);
            break;

        case STMT.TryCatch:
            // For the initial version we'll visit and then foreach var as unmodellable.
            auto tc = st.isTryCatchStatement;

            this.startScope;
            this.visit(tc._body);
            DFAScopeRef inProgress = this.endScope();

            if (tc.catches !is null)
            {
                // Mark everything as unmodellable as we have no idea how it effects anything outside the catch.
                foreach (cat; *tc.catches)
                {
                    markUnmodellable(cat.handler);
                }
            }

            this.seeConvergeScope(inProgress);
            break;

        case STMT.Throw:
            auto ts = st.isThrowStatement;
            DFALatticeRef lr = expWalker.walk(ts.exp);
            expWalker.seeConvergeExpression(lr);

            dfaCommon.currentDFAScope.haveJumped = true;
            dfaCommon.currentDFAScope.haveReturned = true;
            break;

        case STMT.Asm:
        case STMT.InlineAsm:
        case STMT.GccAsm:
        case STMT.CompoundAsm:
            // All variables that we've seen so far are now unmodellable
            // no way to know what state they actually are in :(
            dfaCommon.allocatedVariablesAllUnmodellable;
            break;

        case STMT.SwitchError:
        case STMT.Pragma:
        case STMT.Error:
            break; // ignore these

        case STMT.Default:
        case STMT.CompoundDeclaration:
        case STMT.ScopeGuard:
        case STMT.Foreach:
        case STMT.ForeachRange:
        case STMT.Debug:
        case STMT.CaseRange:
        case STMT.StaticForeach:
        case STMT.StaticAssert:
        case STMT.Conditional:
        case STMT.While:
        case STMT.Forwarding:
        case STMT.Mixin:
        case STMT.Peel:
        case STMT.Synchronized:
            if (dfaCommon.debugUnknownAST)
            {
                fprintf(stderr, "Unknown DFA walk statement %d\n", st.stmt);
                assert(0);
            }
            else
                break;
        }
    }

    void runFinalizersUntilLabel(Identifier target)
    {
        DFAScope* targetHeadScope = dfaCommon.findScopeHeadOfLabelStatement(target);

        version (none)
        {
            printf("Run finalizers up to scope %p", targetHeadScope);

            if (targetHeadScope !is null && targetHeadScope.label !is null)
                printf("%s\n", targetHeadScope.label.ident.toChars);
            else
                printf("\n");
        }

        runFinalizersUntilScope(targetHeadScope);
    }

    void runFinalizersUntilScope(DFAScope* targetScope)
    {
        DFAScope* scv = dfaCommon.currentDFAScope;

        while (scv !is null)
        {
            if (scv.tryFinallyStatement !is null && scv.tryFinallyStatement.finalbody !is null)
            {
                this.visit(scv.tryFinallyStatement.finalbody);
            }

            if (scv is targetScope)
                break;
            scv = scv.parent;
        }
    }

    void markUnmodellable(Statement s)
    {
        void perVar(VarDeclaration vd)
        {
            DFAVar* var = dfaCommon.findVariable(vd);
            if (var !is null)
                var.unmodellable = true;
        }

        foreachExpAndVar(s, &expWalker.markUnmodellable, &perVar);
    }

    /// Check if a if statement will be branched into by a goto or by the condition
    void isBranchTakenIf(ref DFALatticeRef trueLR, ref DFALatticeRef falseLR,
            IfStatement ifs, out bool forTrue, out bool forFalse)
    {
        DFAConsequence* cctx = trueLR.getContext;

        if (cctx !is null)
        {
            if (cctx.truthiness == Truthiness.True)
            {
                forTrue = ifs.ifbody !is null;
                return;
            }
            else if (cctx.truthiness == Truthiness.False)
            {
                forFalse = ifs.elsebody !is null;
                return;
            }
        }

        forTrue = isBranchTaken(trueLR, ifs.ifbody);

        {
            cctx = falseLR.getContext;

            if (ifs.elsebody is null)
                forFalse = false;
            else if (cctx is null || cctx.truthiness != Truthiness.False)
                forFalse = true;
            else
                forFalse = isBranchTaken(ifs.elsebody);
        }
    }

    /// Check if a statement will be branched into either by a goto or by the condition.
    bool isBranchTaken(ref DFALatticeRef condition, Statement stmt)
    {
        DFAConsequence* cctx = condition.getContext;

        if (stmt is null)
            return false;
        else if (cctx is null || cctx.truthiness != Truthiness.False)
            return true;
        else
            return isBranchTaken(stmt);
    }

    /// Check if a statement will be branched into either by a goto.
    bool isBranchTaken(Statement stmt)
    {
        if (stmt is null)
            return false;

        bool walkExpression(Expression e)
        {
            if (auto de = e.isDeclarationExp)
            {
                return de.declaration.isVarDeclaration !is null
                    || de.declaration.isAttribDeclaration !is null;
            }
            else if (auto be = e.isBinExp)
                return walkExpression(be.e1) || walkExpression(be.e2);
            else if (auto ue = e.isUnaExp)
                return walkExpression(ue.e1);
            else
                return false;
        }

        int check(Statement stmt)
        {
            int ret = -1;

            void attempt(Statement stmt2)
            {
                if (ret != -1 || stmt2 is null)
                    return;

                ret = check(stmt2);
            }

            switch (stmt.stmt)
            {
            case STMT.Exp:
                auto es = stmt.isExpStatement;
                if (es.exp !is null && walkExpression(es.exp))
                    return 0;
                return ret;

            case STMT.Compound:
                auto cs = stmt.isCompoundStatement;

                if (cs.statements !is null)
                {
                    foreach (s; *cs.statements)
                    {
                        attempt(s);
                    }
                }

                return ret;

            case STMT.UnrolledLoop:
                auto uls = stmt.isUnrolledLoopStatement;

                if (uls.statements !is null)
                {
                    foreach (s; *uls.statements)
                    {
                        attempt(s);
                    }
                }

                return ret;

            case STMT.Scope:
                auto ss = stmt.isScopeStatement;
                attempt(ss.statement);
                return ret;

            case STMT.Do:
                auto ds = stmt.isDoStatement;
                attempt(ds._body);
                return ret;

            case STMT.For:
                auto fs = stmt.isForStatement;
                attempt(fs._body);
                return ret;

            case STMT.If:
                auto ifs = stmt.isIfStatement;
                attempt(ifs.ifbody);
                attempt(ifs.elsebody);
                return ret;

            case STMT.Switch:
                auto ss = stmt.isSwitchStatement;

                if (ss.cases !is null)
                {
                    foreach (c; *ss.cases)
                    {
                        attempt(c.statement);

                        if (ret != -1)
                            return ret;
                    }
                }

                return ret;

            case STMT.With:
                auto ws = stmt.isWithStatement;
                attempt(ws._body);
                return ret;

            case STMT.TryCatch:
                auto tcs = stmt.isTryCatchStatement;
                attempt(tcs._body);

                if (ret == -1 && tcs.catches !is null && tcs.catches.length > 0)
                    ret = 0; // catch statements have a var declaration
                return ret;

            case STMT.TryFinally:
                auto tfs = stmt.isTryFinallyStatement;
                attempt(tfs._body);
                attempt(tfs.finalbody);
                return ret;

            case STMT.Label:
                auto ls = stmt.isLabelStatement;
                return cast(int) dfaCommon.haveForwardLabelState(ls.ident);

            default:
                return ret;
            }
        }

        int got = check(stmt);
        if (got == -1)
            return false;
        else
            return cast(bool) got;
    }
}
