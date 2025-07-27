module dmd.dfa.fast.statement;
import dmd.dfa.fast.analysis;
import dmd.dfa.fast.report;
import dmd.dfa.fast.expression;
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

extern (C++) class StatementWalker : SemanticTimeTransitiveVisitor
{
    alias visit = SemanticTimeTransitiveVisitor.visit;

    DFACommon* dfaCommon;
    FuncDeclaration currentFunction;
    ExpressionWalker* expWalker;
    DFAAnalyzer* analyzer;
    int depth;
    int inLoopyLabel;

final:

    extern (D) void print(Args...)(const(char)* fmt, Args args)
    {
        if (!this.dfaCommon.debugStructure)
            return;
        else
        {
            printf("%.*s[%p]; ", depth, PrintPipeText.ptr, currentFunction);
            printf(fmt, args);
            fflush(stdout);
        }
    }

    void startScope()
    {
        DFAScopeRef scr;
        scr.sc = dfaCommon.currentDFAScope;
        scr.check;
        scr.sc = null;

        dfaCommon.pushScope;
        print("Start scope %p:%p\n", dfaCommon.currentDFAScope, dfaCommon.currentDFAScope.parent);
        depth++;
    }

    DFAScopeRef endScope()
    {
        Loc loc;
        return this.endScope(loc);
    }

    DFAScopeRef endScope(ref Loc endLoc)
    {
        DFAScopeRef ret = dfaCommon.popScope;
        depth--;

        if (endLoc.isValid)
            print("End scope %p:%p %s\n", ret.sc, dfaCommon.currentDFAScope, endLoc.toChars);
        else
            print("End scope %p:%p\n", ret.sc, dfaCommon.currentDFAScope);

        ret.print("*=", depth, this.currentFunction);
        ret.check;

        dfaCommon.currentDFAScope.print("parent", depth, this.currentFunction);
        dfaCommon.currentDFAScope.check;
        return ret;
    }

    DFAScopeRef endScopeAndReport(ref Loc endLoc, bool endFunction = false)
    {
        reportEndOfScope(this.dfaCommon, this.currentFunction, endLoc);
        if (endFunction)
            reportEndOfFunction(this.dfaCommon, this.currentFunction, endLoc);

        DFAScopeRef ret = dfaCommon.popScope;
        depth--;

        print("End scope %p:%p %s\n", ret.sc, dfaCommon.currentDFAScope, endLoc.toChars);
        ret.print("*=", depth, this.currentFunction);
        ret.check;

        if (dfaCommon.currentDFAScope !is null)
        {
            dfaCommon.currentDFAScope.print("parent", depth, this.currentFunction);
            dfaCommon.currentDFAScope.check;
        }
        return ret;
    }

    void seeConvergeStatement(DFAScopeRef scr)
    {
        print("Converging statement:\n");
        scr.print("input", depth, this.currentFunction);
        scr.check;

        dfaCommon.currentDFAScope.print("scope", depth, this.currentFunction);

        analyzer.convergeStatement(scr);

        dfaCommon.currentDFAScope.print("so far", depth, this.currentFunction);
        dfaCommon.currentDFAScope.check;
    }

    void seeConvergeStatementIf(DFAScopeRef scrTrue, DFAScopeRef scrFalse)
    {
        print("Converging statement if:\n");
        scrTrue.print("true", depth, this.currentFunction);
        scrFalse.print("false", depth, this.currentFunction);

        dfaCommon.currentDFAScope.print("scope", depth, this.currentFunction);
        dfaCommon.currentDFAScope.check;

        analyzer.convergeStatementIf(scrTrue, scrFalse);

        dfaCommon.currentDFAScope.print("so far", depth, this.currentFunction);
        dfaCommon.currentDFAScope.check;
    }

    void seeConvergeStatementSwitch(DFAScopeRef cases)
    {
        print("Converging statement switch:\n");
        cases.print("cases", depth, this.currentFunction);

        dfaCommon.currentDFAScope.print("scope", depth, this.currentFunction);
        analyzer.convergeStatementSwitch(cases);

        dfaCommon.currentDFAScope.print("so far", depth, this.currentFunction);
        dfaCommon.currentDFAScope.check;
    }

    void seeConvergeStatementLoopyLabels(DFAScopeRef scr)
    {
        Loc loc;
        seeConvergeStatementLoopyLabels(scr, loc);
    }

    void seeConvergeStatementLoopyLabels(DFAScopeRef scr, ref Loc loc)
    {
        print("Converging statement loopy labels:\n");
        scr.print("input", depth, this.currentFunction);
        scr.check;

        dfaCommon.currentDFAScope.print("scope", depth, this.currentFunction);
        dfaCommon.currentDFAScope.check;

        analyzer.convergeStatementLoopyLabels(scr, loc);

        dfaCommon.currentDFAScope.print("so far", depth, this.currentFunction);
        dfaCommon.currentDFAScope.check;
    }

    void seeConvergeForwardGoto(DFAScopeRef scr)
    {
        print("Converging forward goto\n");
        scr.print("input", depth, this.currentFunction);
        scr.check;

        dfaCommon.currentDFAScope.print("scope", depth, this.currentFunction);
        dfaCommon.currentDFAScope.check;

        analyzer.convergeStatement(scr, false);

        dfaCommon.currentDFAScope.print("so far", depth, this.currentFunction);
        dfaCommon.currentDFAScope.check;
    }

    DFAScopeRef seeLoopyLabelAwareStage(DFAScopeRef previous, DFAScopeRef next)
    {
        print("Loop stage\n");
        previous.print("previous", depth, this.currentFunction);
        next.print("next", depth, this.currentFunction);

        DFAScopeRef ret = analyzer.transferLoopyLabelAwareStage(previous, next);
        ret.print("result", depth, this.currentFunction);
        return ret;
    }

    void seeGoto(DFAScope* toSc, bool isAfter)
    {
        print("Going to scope adding state after=%d\n", isAfter);
        analyzer.transferGoto(toSc, isAfter);
    }

    void seeForwardsGoto(Identifier ident)
    {
        print("Going to label %s\n", ident.toChars);
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
        FuncDeclaration oldFunc = currentFunction;
        scope (exit)
            currentFunction = oldFunc;
        currentFunction = fd;

        this.print("Starting DFA walk on %s at %s\n", fd.ident.toChars, fd.loc.toChars);

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

                print("vthis is %p scv %p\n", var, scv);
                assert(scv.var is var);

                DFAScopeVar* scv2 = dfaCommon.currentDFAScope.findScopeVar(var);
                assert(scv is scv2);

                dfaCommon.check;
            }

            if (fd.parameters !is null)
            {
                if (fd.parametersDFAInfo.parameters.length != (*fd.parameters).length)
                    fd.parametersDFAInfo.parameters.setDim((*fd.parameters).length);

                foreach (i, param; *fd.parameters)
                {
                    DFAVar* var = dfaCommon.findVariable(param);
                    var.param = &fd.parametersDFAInfo.parameters[i];
                    *var.param = ParameterDFAInfo.init; // Array won't initialize it
                    scv = dfaCommon.acquireScopeVar(var);

                    print("param (%zd) is `%s` %p scv %p stc %d\n", i, param.ident !is null
                            ? param.ident.toChars : null, var, scv, param.storage_class);
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

            print("return is %p scv %p l %p\n", var, scv, scv.lr.lattice);
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
                print("closureVars %s %s\n", vd.ident.toChars, vd.loc.toChars);
            }

            foreach (vd; fd.outerVars)
            {
                DFAVar* var = dfaCommon.findVariable(vd);
                var.unmodellable = true;
                print("outerVars %s %s\n", vd.ident.toChars, vd.loc.toChars);
            }
        }

        this.visit(fd.fbody);

        // implicit return
        // endScope call automatically infers/validates scope on to function.
        dfaCommon.currentDFAScope.haveJumped = true;
        dfaCommon.currentDFAScope.haveReturned = true;
        this.endScopeAndReport(fd.endloc, true);

        if (dfaCommon.debugStructure)
        {
            print("return=%d:%d\n", fd.parametersDFAInfo.returnValue.notNullIn,
                    fd.parametersDFAInfo.returnValue.notNullOut);
            print("this=%d:%d\n", fd.parametersDFAInfo.thisPointer.notNullIn,
                    fd.parametersDFAInfo.thisPointer.notNullOut);

            foreach (i, param; fd.parametersDFAInfo.parameters)
            {
                print("%zd: %d:%d\n", i, param.notNullIn, param.notNullOut);
            }
        }
    }

    DFALatticeRef walkExpression(DFAVar* assignTo, DFAVar* constructInto, Expression exp)
    {
        return expWalker.entry(assignTo, constructInto, exp);
    }

    override void visit(Statement st)
    {
        __gshared immutable string[] AllStmtOpNames = [__traits(allMembers, STMT)];

        if (st is null)
            return;
        else if (dfaCommon.currentDFAScope.haveReturned)
        {
            print("%3d (%s): ignoring at %s\n", st.stmt,
                    AllStmtOpNames[st.stmt].ptr, st.loc.toChars);
            return;
        }

        depth++;
        dfaCommon.check;
        print("%3d (%s): at %s\n", st.stmt, AllStmtOpNames[st.stmt].ptr, st.loc.toChars);
        scope (exit)
        {
            dfaCommon.check;
            depth--;
        }

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
            reportEndOfScope(this.dfaCommon, this.currentFunction, exp.loc);
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
                this.startScope;
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
            print("If statement %p:%p %s\n", dfaCommon.currentDFAScope,
                    origScope, ifs.loc.toChars);

            print("true branch:\n");
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
                print("true ignored\n");

            ifbody = this.endScope;
            ifbody.check;

            assert(dfaCommon.currentDFAScope is origScope);

            {
                print("false branch:\n");
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
                    print("false ignored\n");

                    DFALatticeRef condition = walkExpression(null, null, ifs.condition);
                    condition = expWalker.seeNegate(condition);
                    expWalker.seeSilentAssert(condition, true, true);
                }

                elsebody = this.endScope;
                elsebody.check;
            }

            seeConvergeStatementIf(ifbody, elsebody);
            break;

        case STMT.Scope:
            auto sc = st.isScopeStatement;

            print("Starting scope body at %s\n", sc.loc.toChars);
            this.startScope;
            this.visit(sc.statement);

            print("Completed scope body at %s\n", sc.endloc.toChars);
            DFAScopeRef scbody = this.endScope;
            seeConvergeStatement(scbody);
            break;

        case STMT.Label:
            auto ls = st.isLabelStatement;
            print("label %s %p %p\n", ls.ident !is null ? ls.ident.toChars : null,
                    ls.gotoTarget, ls.gotoTarget);

            inLoopyLabel++;
            scope (exit)
                inLoopyLabel--;

            this.startScope;
            dfaCommon.currentDFAScope.label = ls.ident;
            dfaCommon.setScopeAsLoopyLabel;
            dfaCommon.currentDFAScope.isLoopyLabelKnownToHaveRun = true;

            {
                // sometimes we can by-pass needing to look up the for loop
                dfaCommon.currentDFAScope.controlStatement = ls.gotoTarget !is null
                    ? ls.gotoTarget.isForStatement : null;

                if (dfaCommon.currentDFAScope.controlStatement is null && ls.statement !is null)
                {
                    /+if (auto s1 = ls.statement.isScopeStatement)
                    {
                        if (s1.statement is null)
                            goto LabelNoGate;

                        if (auto s2 = s1.statement.isCompoundStatement)
                        {
                            if (s2.statements is null)
                                goto LabelNoGate;

                            foreach (stmt; *s2.statements)
                            {
                                if (stmt is null)
                                    continue;
                                if (dfaCommon.currentDFAScope.controlStatement is stmt
                                        .isForStatement)
                                    break;
                            }
                        }
                    }
        LabelNoGate:
                    +/

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
                print("For condition:\n");
                DFALatticeRef lrCondition = this.walkExpression(null, null, fs.condition);

                if (auto c = lrCondition.getContext)
                {
                    dfaCommon.currentDFAScope.isLoopyLabelKnownToHaveRun
                        = c.truthiness == Truthiness.True;
                }

                expWalker.seeAssert(lrCondition, fs.condition.loc, true);

                print("For body:\n");
                this.visit(fs._body);

                if (!dfaCommon.currentDFAScope.haveJumped)
                {
                    print("For increment:\n");
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
                this.startScope;

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
                this.startScope;
                dfaCommon.currentDFAScope.controlStatement = ss;
            }

            DFALatticeRef lrCondition = this.walkExpression(null, null, ss.condition);
            lrCondition.check;

            DFAScopeRef inProgress;

            if (ss.sdefault !is null)
            {
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

                inProgress = this.endScope;
            }

            if (ss.cases !is null)
            {
                foreach (cs; *ss.cases)
                {
                    this.startScope;

                    dfaCommon.currentDFAScope.controlStatement = cs;
                    dfaCommon.setScopeAsLoopyLabel;

                    DFALatticeRef equalTo = this.walkExpression(null, null, cs.exp);
                    lrCondition.check;
                    DFALatticeRef lrCondition2 = lrCondition.copy;
                    lrCondition2.check;
                    expWalker.seeConvergeExpression(expWalker.seeEqual(lrCondition2, equalTo,
                            true, ss.condition.type.toBasetype, cs.exp.type.toBasetype));
                    if (auto scs = cs.statement.isScopeStatement)
                        this.visit(scs.statement);
                    else
                        this.visit(cs.statement);
                    inProgress = this.seeLoopyLabelAwareStage(inProgress, this.endScope);
                }
            }

            if (!inProgress.isNull)
                this.seeConvergeStatementSwitch(inProgress);

            if (needScope)
            {
                DFAScopeRef scr = this.endScope(ss.endloc);
                this.seeConvergeStatement(scr);
            }
            break;

        case STMT.Continue:
            auto cs = st.isContinueStatement;
            print("continue %s\n", cs.ident !is null ? cs.ident.toChars : null);

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
            print("Break statement %s\n", bs.ident !is null ? bs.ident.toChars : null);
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
            visitGotoCase(gds.sw, targetScope, st, gds.sw.sdefault);
            break;
        case STMT.GotoCase:
            auto gcs = st.isGotoCaseStatement;

            DFAScope* targetScope;
            auto sw = dfaCommon.findSwitchGivenCase(gcs.cs, targetScope);
            assert(sw !is null);
            assert(targetScope !is null);

            this.runFinalizersUntilScope(targetScope);
            visitGotoCase(sw, targetScope, st, gcs.cs);
            break;

        case STMT.TryFinally:
            auto tfs = st.isTryFinallyStatement;
            print("try finally %p %p\n", tfs._body, tfs.finalbody);
            bool needScope = dfaCommon.currentDFAScope.tryFinallyStatement !is null;

            if (needScope)
                this.startScope;
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

            this.startScope;

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

            this.startScope;
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

    void visitGotoCase(SwitchStatement containingSwitch,
            DFAScope* containingScope, Statement theGoto, Statement target)
    {
        runFinalizersUntilScope(containingScope);

        if (auto targetScope = dfaCommon.findScopeForControlStatement(target))
        {
            seeGoto(containingScope, false);
        }
        else
        {
            if (auto cs = target.isCaseStatement)
            {
                this.startScope;
                dfaCommon.currentDFAScope.controlStatement = target;

                DFALatticeRef lrCondition = this.walkExpression(null, null,
                        containingSwitch.condition);
                DFALatticeRef equalTo = this.walkExpression(null, null, cs.exp);
                expWalker.seeConvergeExpression(expWalker.seeEqual(lrCondition, equalTo, true,
                        containingSwitch.condition.type.toBasetype, cs.exp.type.toBasetype));

                if (auto scs = cs.statement.isScopeStatement)
                    this.visit(scs.statement);
                else
                    this.visit(cs.statement);

                DFAScopeRef scr = this.endScope;
                this.seeConvergeStatement(scr);
            }
            else if (auto dcs = target.isDefaultStatement)
            {
                this.startScope;
                dfaCommon.currentDFAScope.controlStatement = target;

                if (auto scs = dcs.statement.isScopeStatement)
                    this.visit(scs.statement);
                else
                    this.visit(dcs.statement);

                DFAScopeRef scr = this.endScope;
                this.seeConvergeStatement(scr);
            }
            else
            {
                assert(0, "unknown target for goto case");
            }
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
