module dmd.dfa.fast.statement;
import dmd.dfa.fast.analysis;
import dmd.dfa.fast.report;
import dmd.dfa.fast.expression;
import dmd.common.outbuffer;
import dmd.dfa.common;
import dmd.dfa.utils;
import dmd.visitor;
import dmd.visitor.foreachvar;
import dmd.location;
import dmd.func;
import dmd.identifier;
import dmd.statement;
import dmd.expression;
import dmd.timetrace;
import dmd.astenums;
import dmd.mtype;
import dmd.declaration;
import core.stdc.stdio;

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

    void startDummyScope()
    {
        this.startScope;
        dfaCommon.currentDFAScope.isDummyScope = true;
    }

    DFAScopeRef endScope()
    {
        Loc loc;
        return this.endScope(loc);
    }

    DFAScopeRef endScope(ref Loc endLoc)
    {
        DFAScopeRef ret = dfaCommon.popScope;
        dfaCommon.sdepth--;

        dfaCommon.printStructure((ref OutBuffer ob, scope PrintPrefixType prefix) {
            ob.printf("End scope %p:%p", ret.sc, dfaCommon.currentDFAScope);
            if (endLoc.isValid)
                appendLoc(ob, endLoc);
            ob.writestring("\n");
        });

        ret.print("*=", dfaCommon.sdepth, dfaCommon.currentFunction);
        ret.check;

        dfaCommon.currentDFAScope.print("parent", dfaCommon.sdepth, dfaCommon.currentFunction);
        dfaCommon.currentDFAScope.check;
        return ret;
    }

    DFAScopeRef endScopeAndReport(ref Loc endLoc, bool endFunction = false)
    {
        reportEndOfScope(this.dfaCommon, dfaCommon.currentFunction, endLoc);
        if (endFunction)
            reportEndOfFunction(this.dfaCommon, dfaCommon.currentFunction, endLoc);

        DFAScopeRef ret = dfaCommon.popScope;
        dfaCommon.sdepth--;

        dfaCommon.printStructure((ref OutBuffer ob, scope PrintPrefixType prefix) {
            ob.printf("End scope %p:%p", ret.sc, dfaCommon.currentDFAScope);
            if (endLoc.isValid)
                appendLoc(ob, endLoc);
            ob.writestring("\n");
        });

        ret.print("*=", dfaCommon.sdepth, dfaCommon.currentFunction);
        ret.check;

        if (dfaCommon.currentDFAScope !is null)
        {
            dfaCommon.currentDFAScope.print("parent", dfaCommon.sdepth, dfaCommon.currentFunction);
            dfaCommon.currentDFAScope.check;
        }
        return ret;
    }

    void seeConvergeStatement(DFAScopeRef scr)
    {
        dfaCommon.printStructure((ref OutBuffer ob,
                scope PrintPrefixType prefix) => ob.writestring("Converging statement:\n"));
        scr.print("input", dfaCommon.sdepth, dfaCommon.currentFunction);
        scr.check;

        dfaCommon.currentDFAScope.print("scope", dfaCommon.sdepth, dfaCommon.currentFunction);

        analyzer.convergeStatement(scr);

        dfaCommon.currentDFAScope.print("so far", dfaCommon.sdepth, dfaCommon.currentFunction);
        dfaCommon.currentDFAScope.check;
    }

    void seeConvergeStatementIf(DFAScopeRef scrTrue, DFAScopeRef scrFalse, bool ignoreFalseUnknowns)
    {
        dfaCommon.printStructure((ref OutBuffer ob,
                scope PrintPrefixType prefix) => ob.printf("Converging statement if %d:\n",
                ignoreFalseUnknowns));
        scrTrue.print("true", dfaCommon.sdepth, dfaCommon.currentFunction);
        scrFalse.print("false", dfaCommon.sdepth, dfaCommon.currentFunction);

        dfaCommon.currentDFAScope.print("scope", dfaCommon.sdepth, dfaCommon.currentFunction);
        dfaCommon.currentDFAScope.check;

        analyzer.convergeStatementIf(scrTrue, scrFalse, ignoreFalseUnknowns);

        dfaCommon.currentDFAScope.print("so far", dfaCommon.sdepth, dfaCommon.currentFunction);
        dfaCommon.currentDFAScope.check;
    }

    void seeConvergeStatementSwitch(DFAScopeRef cases)
    {
        dfaCommon.printStructure((ref OutBuffer ob,
                scope PrintPrefixType prefix) => ob.writestring("Converging statement switch:\n"));
        cases.print("cases", dfaCommon.sdepth, dfaCommon.currentFunction);

        dfaCommon.currentDFAScope.print("scope", dfaCommon.sdepth, dfaCommon.currentFunction);
        analyzer.convergeStatementSwitch(cases);

        dfaCommon.currentDFAScope.print("so far", dfaCommon.sdepth, dfaCommon.currentFunction);
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
        scr.print("input", dfaCommon.sdepth, dfaCommon.currentFunction);
        scr.check;

        dfaCommon.currentDFAScope.print("scope", dfaCommon.sdepth, dfaCommon.currentFunction);
        dfaCommon.currentDFAScope.check;

        analyzer.convergeStatementLoopyLabels(scr, loc);

        dfaCommon.currentDFAScope.print("so far", dfaCommon.sdepth, dfaCommon.currentFunction);
        dfaCommon.currentDFAScope.check;
    }

    void seeCheckForCaseBefore(ref DFAScopeRef containing, DFAScopeRef jumpedTo, ref const(Loc) loc)
    {
        dfaCommon.printStructure((ref OutBuffer ob,
                scope PrintPrefixType prefix) => ob.writestring(
                "Check case before & containing state:\n"));

        containing.print("containing");
        containing.check;

        jumpedTo.print("jumpedTo");
        jumpedTo.check;

        analyzer.loopyLabelBeforeContainingCheck(containing, jumpedTo, loc);
    }

    void seeConvergeForwardGoto(DFAScopeRef scr)
    {
        dfaCommon.printStructure((ref OutBuffer ob,
                scope PrintPrefixType prefix) => ob.writestring("Converging forward goto:\n"));
        scr.print("input", dfaCommon.sdepth, dfaCommon.currentFunction);
        scr.check;

        dfaCommon.currentDFAScope.print("scope", dfaCommon.sdepth, dfaCommon.currentFunction);
        dfaCommon.currentDFAScope.check;

        analyzer.convergeStatement(scr, false);

        dfaCommon.currentDFAScope.print("so far", dfaCommon.sdepth, dfaCommon.currentFunction);
        dfaCommon.currentDFAScope.check;
    }

    DFAScopeRef seeLoopyLabelAwareStage(DFAScopeRef previous, DFAScopeRef next)
    {
        dfaCommon.printStructure((ref OutBuffer ob,
                scope PrintPrefixType prefix) => ob.writestring("Loop stage:\n"));
        previous.print("previous", dfaCommon.sdepth, dfaCommon.currentFunction);
        next.print("next", dfaCommon.sdepth, dfaCommon.currentFunction);

        DFAScopeRef ret = analyzer.transferLoopyLabelAwareStage(previous, next);
        ret.print("result", dfaCommon.sdepth, dfaCommon.currentFunction);
        return ret;
    }

    void seeGoto(DFAScope* toSc, bool isAfter)
    {
        dfaCommon.printStructure((ref OutBuffer ob,
                scope PrintPrefixType prefix) => ob.printf(
                "Going to scope adding state after=%d\n", isAfter));
        analyzer.transferGoto(toSc, isAfter);
    }

    void seeForwardsGoto(Identifier ident)
    {
        dfaCommon.printStructure((ref OutBuffer ob,
                scope PrintPrefixType prefix) => ob.printf("Going to label %s\n", ident.toChars));
        analyzer.transferForwardsGoto(ident);
    }

    void constructVariable(VarDeclaration vd, bool isNonNull)
    {
        DFAVar* var = dfaCommon.findVariable(vd);

        DFALatticeRef lr = dfaCommon.makeLatticeRef;
        DFAConsequence* c = lr.addConsequence(var);
        lr.setContext(c);
        c.nullable = isNonNull ? Nullable.NonNull : Nullable.Null;

        expWalker.seeConvergeExpression(expWalker.seeAssign(var, true, lr));
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
        dfaCommon.check;
        DFAScopeVar* scv;

        {
            if (fd.parametersDFAInfo is null)
                fd.parametersDFAInfo = new ParametersDFAInfo;

            if (fd.vthis !is null)
            {
                DFAVar* var = dfaCommon.findVariable(fd.vthis);
                var.param = &fd.parametersDFAInfo.thisPointer;
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
                    var.param = &fd.parametersDFAInfo.parameters[i];
                    *var.param = ParameterDFAInfo.init; // Array won't initialize it
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
        }

        {
            DFAVar* var = dfaCommon.getReturnVariable();
            var.param = &fd.parametersDFAInfo.returnValue;

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

    DFALatticeRef walkExpression(DFAVar* assignTo, DFAVar* constructInto, Expression exp)
    {
        return expWalker.entry(assignTo, constructInto, exp);
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

        final switch (st.stmt)
        {
        case STMT.DtorExp:
            expWalker.seeConvergeExpression(walkExpression(null,
                    null, st.isDtorExpStatement.exp));
            break;

        case STMT.Exp:
            expWalker.seeConvergeExpression(walkExpression(null,
                    null, st.isExpStatement.exp));
            break;
        case STMT.Return:
            Expression exp = st.isReturnStatement.exp;
            if (exp !is null)
                expWalker.seeConvergeExpression(walkExpression(null,
                        dfaCommon.getReturnVariable, exp));

            dfaCommon.currentDFAScope.haveJumped = true;
            dfaCommon.currentDFAScope.haveReturned = true;
            reportEndOfScope(this.dfaCommon, dfaCommon.currentFunction, exp.loc);
            break;

        case STMT.Compound:
            auto cs = st.isCompoundStatement;
            if (cs.statements is null)
                break;

            // We need to know which statement we are in and what the next ones are
            // so that we can find labels and run finally statements

            bool needScope;
            if (dfaCommon.currentDFAScope.compoundStatement !is null)
            {
                needScope = true;
                this.startDummyScope;
            }

            dfaCommon.currentDFAScope.compoundStatement = cs;

            foreach (i, st2; *cs.statements)
            {
                dfaCommon.currentDFAScope.inProgressCompoundStatement = i;
                this.visit(st2);

                if (dfaCommon.currentDFAScope.haveReturned)
                    break;
            }

            if (needScope)
            {
                DFAScopeRef scr = this.endScope;
                this.seeConvergeStatement(scr);
                dfaCommon.currentDFAScope.compoundStatement = null;
            }
            break;

        case STMT.If:
            auto ifs = st.isIfStatement;

            auto origScope = dfaCommon.currentDFAScope;

            dfaCommon.printStructure((ref OutBuffer ob, scope PrintPrefixType prefix) {
                ob.printf("If statement %p:%p ", dfaCommon.currentDFAScope, origScope);
                appendLoc(ob, ifs.loc);
                ob.writestring("\n");

                prefix("true branch:\n");
            });

            this.startScope;
            bool ignoreTrueBranch, ignoreFalseBranch;

            {
                DFALatticeRef condition = walkExpression(null, null, ifs.condition);

                DFAConsequence* c = condition.getContext;
                if (c !is null)
                {
                    if (c.truthiness == Truthiness.False)
                        ignoreTrueBranch = true;
                    else if (c.truthiness == Truthiness.True)
                        ignoreFalseBranch = true;
                }

                if (!ignoreTrueBranch)
                    expWalker.seeAssert(condition, ifs.condition.loc, true);
            }

            DFAScopeRef ifbody, elsebody;

            if (!ignoreTrueBranch)
            {
                if (auto scs = ifs.ifbody.isScopeStatement)
                    this.visit(scs.statement);
                else
                    this.visit(ifs.ifbody);

                assert(dfaCommon.currentDFAScope !is origScope);
            }
            else
                dfaCommon.printStructure((ref OutBuffer ob,
                        scope PrintPrefixType prefix) => ob.writestring("true ignored\n"));

            ifbody = this.endScope;
            ifbody.check;

            assert(dfaCommon.currentDFAScope is origScope);
            bool haveFalseBody;

            {
                dfaCommon.printStructure((ref OutBuffer ob,
                        scope PrintPrefixType prefix) => ob.writestring("false branch:\n"));
                this.startScope;

                if (!ignoreFalseBranch && ifs.elsebody !is null)
                {
                    DFALatticeRef condition = walkExpression(null, null, ifs.condition);
                    condition = expWalker.seeNegate(condition, true);
                    expWalker.seeSilentAssert(condition, false, true);

                    if (auto scs = ifs.elsebody.isScopeStatement)
                        this.visit(scs.statement);
                    else
                        this.visit(ifs.elsebody);
                }
                else
                {
                    dfaCommon.printStructure((ref OutBuffer ob,
                            scope PrintPrefixType prefix) => ob.writestring("false ignored\n"));

                    DFALatticeRef condition = walkExpression(null, null, ifs.condition);
                    condition = expWalker.seeNegate(condition);
                    expWalker.seeSilentAssert(condition, true, true);
                }

                elsebody = this.endScope;
                elsebody.check;
            }

            seeConvergeStatementIf(ifbody, elsebody, !haveFalseBody);
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
            seeConvergeStatement(scbody);
            break;

        case STMT.Label:
            auto ls = st.isLabelStatement;
            dfaCommon.printStructure((ref OutBuffer ob,
                    scope PrintPrefixType prefix) => ob.printf("label %s %p %p\n",
                    ls.ident !is null ? ls.ident.toChars : null, ls.gotoTarget, ls.gotoTarget));

            inLoopyLabel++;
            scope (exit)
                inLoopyLabel--;

            this.startDummyScope;
            dfaCommon.currentDFAScope.label = ls.ident;
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
            Loc loc;

            // by-pass scope statement processing with a dedicated variation here.
            if (ls.statement is null)
            {
                // empty block, this is ok.
                scr = this.endScope;
            }
            else if (auto scs = ls.statement.isScopeStatement)
            {
                this.visit(scs.statement);
                loc = scs.endloc;
                scr = this.endScope(loc);
            }
            else
            {
                this.visit(ls.statement);
                loc = ls.statement.loc;
                scr = this.endScope;
            }

            seeConvergeStatementLoopyLabels(scr, loc);
            break;

        case STMT.For:
            auto fs = st.isForStatement;
            // fs._init should be handled already

            inLoopyLabel++;
            scope (exit)
                inLoopyLabel--;

            {
                this.startScope;
                dfaCommon.currentDFAScope.controlStatement = st;
                dfaCommon.setScopeAsLoopyLabel;

                // fs.condition
                dfaCommon.printStructure((ref OutBuffer ob,
                        scope PrintPrefixType prefix) => ob.writestring("For condition:\n"));
                DFALatticeRef lrCondition = this.walkExpression(null, null, fs.condition);

                if (auto c = lrCondition.getContext)
                {
                    dfaCommon.currentDFAScope.isLoopyLabelKnownToHaveRun
                        = c.truthiness == Truthiness.True;
                }

                expWalker.seeAssert(lrCondition, fs.condition.loc, true);

                dfaCommon.printStructure((ref OutBuffer ob,
                        scope PrintPrefixType prefix) => ob.writestring("For body:\n"));
                this.visit(fs._body);

                if (!dfaCommon.currentDFAScope.haveJumped)
                {
                    dfaCommon.printStructure((ref OutBuffer ob,
                            scope PrintPrefixType prefix) => ob.writestring("For increment:\n"));
                    DFALatticeRef lrIncrement = this.walkExpression(null, null, fs.increment);
                    expWalker.seeConvergeExpression(lrIncrement);
                }

                dfaCommon.currentDFAScope.haveJumped = dfaCommon.currentDFAScope.haveJumped
                    || !dfaCommon.currentDFAScope.haveReturned;

                DFAScopeRef scr = this.endScopeAndReport(fs.endloc);
                assert(!scr.isNull);
                this.seeConvergeStatementLoopyLabels(scr, fs.endloc);
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

            this.visit(ds._body);

            DFALatticeRef lrCondition = this.walkExpression(null, null, ds.condition);
            expWalker.seeSilentAssert(lrCondition, false, true);

            dfaCommon.currentDFAScope.haveJumped = true;
            DFAScopeRef scr = this.endScope(ds.endloc);
            this.seeConvergeStatementLoopyLabels(scr, ds.endloc);
            break;

        case STMT.UnrolledLoop:
            auto uls = st.isUnrolledLoopStatement;

            inLoopyLabel++;
            scope (exit)
                inLoopyLabel--;

            if (uls.statements !is null && uls.statements.length > 0)
            {
                DFAScopeRef inProgress;
                this.startDummyScope;

                dfaCommon.currentDFAScope.controlStatement = st;
                dfaCommon.setScopeAsLoopyLabel;

                foreach (stmt; *uls.statements)
                {
                    this.startScope;
                    this.visit(stmt);
                    inProgress = seeLoopyLabelAwareStage(inProgress, this.endScope);
                }

                this.seeConvergeStatement(inProgress);

                DFAScopeRef scr = this.endScope();
                this.seeConvergeStatementLoopyLabels(scr);
            }

            break;

        case STMT.Switch:
            auto ss = st.isSwitchStatement;
            const needScope = dfaCommon.currentDFAScope.controlStatement !is st;

            if (needScope)
            {
                this.startDummyScope;
                dfaCommon.currentDFAScope.controlStatement = ss;
            }

            DFALatticeRef lrCondition = this.walkExpression(null, null, ss.condition);
            lrCondition.check;

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
                }

                if (ss.cases !is null)
                {
                    foreach (cs; *ss.cases)
                    {
                        DFACaseState* caState = dfaCommon.acquireCaseState(cs);
                        this.startScope;

                        dfaCommon.currentDFAScope.controlStatement = cs;
                        dfaCommon.setScopeAsLoopyLabel;

                        DFALatticeRef equalTo = this.walkExpression(null, null, cs.exp);
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
                    this.seeConvergeStatementSwitch(inProgress);
            }

            if (needScope)
            {
                DFAScopeRef scr = this.endScope(ss.endloc);
                this.seeConvergeStatement(scr);
            }
            break;

        case STMT.Continue:
            auto cs = st.isContinueStatement;
            dfaCommon.printStructure((ref OutBuffer ob, scope PrintPrefixType prefix) => ob.printf(
                    "Continue statement %s\n", cs.ident !is null ? cs.ident.toChars : null));

            dfaCommon.currentDFAScope.haveJumped = true;
            auto sc = dfaCommon.findScopeGivenLabel(cs.ident);
            assert(sc !is null);

            if (!dfaCommon.debugUnknownAST && sc.controlStatement is null)
                break;
            else
                assert(sc.controlStatement !is null);

            if (auto forLoop = sc.controlStatement.isForStatement)
            {
                DFALatticeRef lr = this.walkExpression(null, null, forLoop.increment);
                expWalker.seeConvergeExpression(lr);
            }
            else if (auto ss = sc.controlStatement.isSwitchStatement)
            {
                sc = sc.child;

                if (!dfaCommon.debugUnknownAST && (sc.controlStatement is null
                        || sc.controlStatement.isCaseStatement is null))
                    break;
                else
                {
                    assert(sc !is null);
                    assert(sc.controlStatement.isCaseStatement !is null);
                }
            }

            seeGoto(sc, false);
            runFinalizersUntilScope(sc);
            break;

        case STMT.Break:
            auto bs = st.isBreakStatement;
            dfaCommon.printStructure((ref OutBuffer ob,
                    scope PrintPrefixType prefix) => ob.printf("Break statement %s\n",
                    bs.ident !is null ? bs.ident.toChars : null));
            dfaCommon.currentDFAScope.haveJumped = true;

            auto sc = dfaCommon.findScopeGivenLabel(bs.ident);
            assert(sc !is null);

            if (!dfaCommon.debugUnknownAST && sc.controlStatement is null)
                break;
            else
                assert(sc.controlStatement !is null);

            if (auto ss = sc.controlStatement.isSwitchStatement)
            {
                sc = sc.child;

                if (!dfaCommon.debugUnknownAST && (sc.controlStatement is null
                        || sc.controlStatement.isCaseStatement is null))
                    break;
                else
                {
                    assert(sc !is null);
                    assert(sc.controlStatement is null
                            || sc.controlStatement.isCaseStatement !is null);
                }
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
            bool needScope = dfaCommon.currentDFAScope.tryFinallyStatement !is null;

            if (needScope)
                this.startDummyScope;
            dfaCommon.currentDFAScope.tryFinallyStatement = tfs;

            // normal path execute both
            this.visit(tfs._body);
            this.visit(tfs.finalbody);

            dfaCommon.currentDFAScope.tryFinallyStatement = null;

            if (needScope)
            {
                DFAScopeRef scr = this.endScope;
                this.seeConvergeStatement(scr);
            }
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

            this.startDummyScope;

            DFALatticeRef lr = this.walkExpression(null, null, ws.exp);
            expWalker.seeConvergeExpression(lr);

            if (auto ss = ws._body.isScopeStatement)
                this.visit(ss.statement);
            else
                this.visit(ws._body);

            DFAScopeRef scr = this.endScope(ws.endloc);
            this.seeConvergeStatement(scr);
            break;

        case STMT.TryCatch:
            // For the initial version we'll visit and then foreach var as unmodellable.
            auto tc = st.isTryCatchStatement;

            this.startDummyScope;
            this.visit(tc._body);
            DFAScopeRef inProgress = this.endScope();

            if (tc.catches !is null)
            {
                // Do this in two passes

                // First pass computes modellable stuff
                foreach (cat; *tc.catches)
                {
                    this.startScope;
                    dfaCommon.setScopeAsCatch;

                    this.constructVariable(cat.var, true);
                    this.visit(cat.handler);

                    inProgress = seeLoopyLabelAwareStage(inProgress, this.endScope);
                }

                // Second pass sets unmodellable
                foreach (cat; *tc.catches)
                {
                    markUnmodellable(cat.handler);
                }
            }

            this.seeConvergeStatement(inProgress);
            break;

        case STMT.Throw:
            auto ts = st.isThrowStatement;
            expWalker.seeConvergeExpression(this.walkExpression(null, null, ts.exp));

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
        DFAScope* targetHeadScope = findScopeHeadOfLabelStatement(this.dfaCommon, target);

        version (none)
        {
            printf("Run finalizers up to scope %p", targetHeadScope);

            if (targetHeadScope !is null && targetHeadScope.label !is null)
                printf("%s\n", targetHeadScope.label.toChars);
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

        foreachExpAndVar(s, (expr) => foreachVar(expr, &perVar), &perVar);
    }
}
