module dmd.dfa.fast.analysis;
import dmd.dfa.common;
import dmd.dfa.utils;
import dmd.dfa.fast.report;
import dmd.location;
import dmd.identifier;
import dmd.func;
import dmd.declaration;
import dmd.astenums;
import dmd.mtype;
import dmd.root.array;
import core.stdc.stdio;

//version = DebugJoinMeetOp;

struct DFAAnalyzer
{
    DFACommon* dfaCommon;

    void convergeExpression(DFALatticeRef lr)
    {
        if (lr.isNull)
            return;

        DFAConsequence* ctx = lr.getContext;
        assert(ctx !is null);

        DFAVar* ctxVar = ctx.var;

        if (ctx.truthiness == Truthiness.Maybe)
        {
            if (ctxVar !is null && ctxVar.base is null)
                dfaCommon.swapLattice(ctxVar, lattice => join(lattice, lr));
        }
        else
        {
            foreach (c; lr)
            {
                if (c.var !is null && c.var.base is null)
                {
                    dfaCommon.swapLattice(c.var, (lrForC) {
                        DFAConsequence* oldC = lrForC.getContext;
                        assert(oldC !is null);

                        joinConsequence(oldC, oldC, c, null, false, false, false);
                        return lrForC;
                    });
                }
            }
        }

    }

    void convergeStatementIf(DFAScopeRef scrTrue, DFAScopeRef scrFalse)
    {
        bool bothJumped, bothReturned;

        if (scrFalse.isNull)
        {
            bothJumped = scrTrue.isNull ? false : scrTrue.sc.haveJumped;
            bothReturned = scrTrue.isNull ? false : scrTrue.sc.haveReturned;
            convergeStatement(scrTrue, true, true);
        }
        else if (scrTrue.isNull)
        {
            bothJumped = scrFalse.isNull ? false : scrFalse.sc.haveJumped;
            bothReturned = scrFalse.isNull ? false : scrFalse.sc.haveReturned;
            convergeStatement(scrFalse, true, true);
        }
        else
        {
            const eitherJumped = scrTrue.sc.haveJumped || scrFalse.sc.haveJumped;
            bothJumped = scrTrue.sc.haveJumped && scrFalse.sc.haveJumped;
            bothReturned = scrTrue.sc.haveReturned && scrFalse.sc.haveReturned;

            DFAScopeRef meeted = meetScope(scrTrue, scrFalse, true);
            assert(!meeted.isNull);
            convergeStatement(meeted, !eitherJumped, true);
        }

        if (bothJumped)
            dfaCommon.currentDFAScope.haveJumped = true;
        if (bothReturned)
            dfaCommon.currentDFAScope.haveReturned = true;
    }

    void convergeStatementSwitch(DFAScopeRef inProgress)
    {
        if (inProgress.isNull)
            return;

        bool allJumped = inProgress.sc.haveJumped, allReturned = inProgress.sc.haveReturned;
        convergeStatement(inProgress);

        if (allJumped)
            dfaCommon.currentDFAScope.haveJumped = true;
        if (allReturned)
            dfaCommon.currentDFAScope.haveReturned = true;
    }

    void convergeStatementLoopyLabels(DFAScopeRef containing, ref Loc loc)
    {
        DFAScopeRef beforeScopeState = containing.sc.beforeScopeState;
        DFAScopeRef afterScopeState = containing.sc.afterScopeState;

        void checkForNull(DFAScopeVar* assertedVar, DFAConsequence* oldC, DFAConsequence* newC)
        {
            if (assertedVar.var.var is null)
                return;

            if (oldC is null || newC is null)
                return;

            if (oldC.nullable == Nullable.NonNull && newC.nullable == Nullable.Null)
            {
                if (assertedVar.derefDepth > 0)
                {
                    if (assertedVar.derefAssertedDepth > 0
                            && assertedVar.derefDepth < assertedVar.derefAssertedDepth)
                        reportLoopyLabelLessNullThan(dfaCommon, assertedVar.var, loc);
                    else if (assertedVar.derefAssertedDepth == 0)
                        reportLoopyLabelLessNullThan(dfaCommon, assertedVar.var, loc);
                }
            }
        }

        void checkForAssignAfterAssert(ref DFAScopeRef toProcessScope,
                DFAScopeVar* assertedVar, DFALattice* assertedLattice)
        {
            if (assertedVar.var is null || assertedVar.var.var is null)
                return;

            version (none)
            {
                printf("checkForAssignAfterAssert %p `%s` %d:%d\n", assertedVar.var,
                        assertedVar.var.var.toChars, assertedVar.assertDepth,
                        assertedVar.assignDepth);
            }

            if (assertedVar.assertDepth == 0)
                return;

            DFALatticeRef assertedLatticeRef;
            assertedLatticeRef.lattice = assertedLattice;
            scope (exit)
                assertedLatticeRef.lattice = null;

            foreach (c; assertedLatticeRef)
            {
                if (c.var is null || c.var.var is null)
                    continue;

                DFAScopeVar* newSCV = toProcessScope.findScopeVar(c.var);
                if (newSCV is null)
                    continue;

                DFAConsequence* newC = newSCV.lr.findConsequence(c.var);
                if (newC is null)
                    continue;

                DFAScopeVar* currentSCV = dfaCommon.acquireScopeVar(c.var);
                if (currentSCV is null)
                    continue;

                DFAConsequence* currentC = currentSCV.lr.findConsequence(c.var);
                if (currentC is null)
                    continue;

                version (none)
                {
                    printf("    %p `%s`\n", c.var, c.var.var.toChars);
                    printf("        new assert=%d, assign=%d\n",
                            newSCV.assertDepth, newSCV.assignDepth);
                    printf("          %d:%d\n", newC.truthiness, newC.nullable);
                    printf("        current assert=%d, assign=%d \n",
                            currentSCV.assertDepth, currentSCV.assignDepth);
                    printf("          %d:%d\n", currentC.truthiness, currentC.nullable);
                }

                if ((currentC.truthiness != Truthiness.Unknown && currentC.truthiness != newC.truthiness)
                        || (currentC.nullable != Nullable.Unknown
                            && currentC.nullable != newC.nullable))
                {
                    if (assertedVar.assertDepth > 0 && assertedVar.assertDepth <= newSCV
                            .assignDepth)
                        reportLoopyLabelAssertAndAssign(dfaCommon, newSCV, assertedVar, loc);
                }
            }
        }

        foreach (var, l2; beforeScopeState)
        {
            DFAScopeVar* oldState = dfaCommon.acquireScopeVar(var);
            DFAScopeVar* newState = containing.findScopeVar(var);
            if (oldState is null || newState is null)
                continue;

            checkForNull(newState, oldState.lr.lattice.context, l2.context);
            checkForAssignAfterAssert(beforeScopeState, newState, l2);
        }

        foreach (var, l2, newState; containing)
        {
            if (var.var is null)
                continue;

            DFAScopeVar* oldState = dfaCommon.acquireScopeVar(var);
            if (oldState is null || newState is null)
                continue;

            checkForNull(newState, oldState.lr.lattice.context, l2.context);
            checkForAssignAfterAssert(containing, newState, l2);
        }

        const mayScopeNotHaveRan = !containing.sc.isLoopyLabelKnownToHaveRun;
        convergeStatement(containing, false, mayScopeNotHaveRan);
        convergeStatement(afterScopeState, false);
    }

    void convergeStatement(DFAScopeRef scr, bool allBranchesTaken = true,
            bool couldScopeNotHaveRan = false)
    {
        DFAScopeRef scrCurrent;
        scrCurrent.sc = dfaCommon.currentDFAScope;

        const depth = dfaCommon.currentDFAScope.depth;

        DFALatticeRef lr;
        DFAVar* var;

        while (!(lr = scr.consumeNext(var)).isNull)
        {
            dfaCommon.swapLattice(var, (lattice) {
                assert(!lattice.isNull);
                lattice.check;

                DFALatticeRef lr = allBranchesTaken ? join(lattice, lr, depth,
                    null, couldScopeNotHaveRan) : meet(lattice, lr, depth, couldScopeNotHaveRan);

                assert(!lr.isNull);
                lr.check;
                return lr;
            });
        }

        scrCurrent.sc = null;
    }

    void convergeFunctionCallArgument(DFALatticeRef lr, ParameterDFAInfo* paramInfo,
            Parameter paramVar, FuncDeclaration calling, ref Loc loc)
    {
        DFAConsequence* cctx = lr.getContext;
        DFAVar* ctx = cctx !is null ? cctx.var : null;

        void convergeEachConsequence()
        {
            foreach (c; lr)
            {
                if (c.maybeTopSeen || c.var is null || c.var.base !is null)
                    continue;

                dfaCommon.swapLattice(c.var, (lrForC) {
                    DFAConsequence* oldC = lrForC.getContext;
                    assert(oldC !is null);

                    joinConsequence(oldC, oldC, c, null, false, false, false);
                    return lrForC;
                });
            }
        }

        if (paramInfo !is null && ctx !is null)
        {
            // ok we have a context variable, check it against paramInfo
            if (paramInfo.notNullIn == Fact.Guaranteed && cctx.nullable == Nullable.Null)
                reportFunctionCallArgumentLessThan(this.dfaCommon, cctx, paramInfo, calling, loc);
        }

        const isByRef = paramVar !is null && (paramVar.storageClass & (STC.ref_ | STC.out_)) != 0;

        DFAVar* seePointer(DFAVar* var)
        {
            // If the variable can point to something we can model (i.e. symbol offset) to its base variable
            // Or if the parameter is by-ref, then we must consider the output state of the variable.
            if (!isByRef && var.offsetFromBase == -1)
                return var;

            // Find most base variable, since we do not track indirection.
            while (var.offsetFromBase != -1)
            {
                assert(var !is var.base);
                assert(var.base !is null);
                var = var.base;
            }

            if (var.base is null)
            {
                DFALatticeRef temp = dfaCommon.makeLatticeRef;
                temp.setContext(var);
                // now its all set to unknown

                dfaCommon.currentDFAScope.assignLattice(var, temp);
            }

            return var;
        }

        if (ctx is null)
        {
            lr.walkMaybeTops((c) {
                if (c.var is null)
                    return true;

                DFAVar* saw = seePointer(c.var);

                if (saw !is c.var)
                {
                    DFAConsequence* c2 = lr.findConsequence(saw);
                    if (c2 !is null)
                        c2.maybeTopSeen = true;
                }

                return true;
            });
        }
        else
        {
            DFAVar* saw = seePointer(ctx);

            if (saw !is ctx)
            {
                DFAConsequence* c2 = lr.findConsequence(saw);
                if (c2 !is null)
                    c2.maybeTopSeen = true;
            }
            else
                cctx.maybeTopSeen = true;
        }

        convergeEachConsequence;
    }

    void transferAssert(DFALatticeRef lr, ref const Loc loc, bool ignoreWriteCount,
            bool dueToConditional = false)
    {
        if (lr.isNull)
            return;

        const currentDepth = dfaCommon.currentDFAScope.depth;
        DFAScope* lastLoopyLabel = dfaCommon.lastLoopyLabel;

        void handle(DFAConsequence* c)
        {
            if (c.var is null || c.var.base !is null)
                return;

            c.var.hasBeenAsserted = true;
            DFAScopeVar* scv = dfaCommon.acquireScopeVar(c.var);

            version (none)
            {
                printf("asserting %d %p %d:%d %d:%d\n", ignoreWriteCount, c.var, c.var.writeCount,
                        c.writeOnVarAtThisPoint, currentDepth, c.var.declaredAtDepth);
                printf("    %d && %d\n", !ignoreWriteCount,
                        c.var.writeCount > c.writeOnVarAtThisPoint);
                printf("    %d <\n", currentDepth < c.var.declaredAtDepth);
            }

            if (!ignoreWriteCount && c.var.writeCount > c.writeOnVarAtThisPoint)
                return;
            else if (currentDepth < c.var.declaredAtDepth)
                return;

            if (lastLoopyLabel !is null)
            {
                if ((scv = lastLoopyLabel.findScopeVar(c.var)) !is null)
                {
                    if (c.nullable == Nullable.NonNull && (scv.derefAssertedDepth == 0
                            || scv.derefAssertedDepth > currentDepth))
                        scv.derefAssertedDepth = currentDepth;
                }
            }

            dfaCommon.swapLattice(c.var, (lattice) {
                DFAConsequence* old = lattice.addConsequence(c.var);

                version (none)
                {
                    printf("swapping %p %d:%d and %d:%d\n", c.var,
                        old.truthiness, old.nullable, c.truthiness, c.nullable);
                }

                joinConsequence(old, old, c, null, false, ignoreWriteCount, false);

                version (none)
                {
                    printf("    %d:%d\n", old.truthiness, old.nullable);
                }
                return lattice;
            });
        }

        DFAConsequence* cctx = lr.getContext;
        if (cctx !is null)
        {
            if (cctx.truthiness == Truthiness.False && loc.isValid)
                reportAssertIsFalse(dfaCommon, lr, loc);

            if (cctx.var !is null)
            {
                if (!dueToConditional && lastLoopyLabel !is null)
                {
                    if (DFAScopeVar* cctxSCV = lastLoopyLabel.findScopeVar(cctx.var))
                    {
                        if ((cctxSCV.assignDepth == 0 || cctxSCV.assertDepth > currentDepth))
                            cctxSCV.assertDepth = currentDepth;
                    }
                }
            }
        }

        foreach (c; lr)
        {
            handle(c);
        }
    }

    DFALatticeRef transferAssign(DFALatticeRef assignTo, bool construct,
            bool isBlit, DFALatticeRef lr)
    {
        DFAConsequence* cctx = assignTo.getContext;
        DFAVar* ctx = cctx !is null ? cctx.var : null;

        const noLR = lr.isNull || lr.getContext is null;

        if (!construct)
        {
            if (noLR)
            {
                if (ctx !is null)
                    ctx.unmodellable = true;
            }
        }

        DFALatticeRef ret = join(assignTo, lr, 0, ctx);
        DFAConsequence* c = ret.addConsequence(ctx);
        ret.setContext(c);

        if (construct && isBlit)
        {
            if (noLR)
            {
                c.truthiness = Truthiness.False;

                if (ctx !is null && ctx.isAPointer)
                    c.nullable = Nullable.Null;
            }
        }
        else if (ctx !is null)
            seeWrite(ctx, ret);

        return ret;
    }

    DFALatticeRef transferNegate(DFALatticeRef lr, bool protectElseNegate = false)
    {
        bool negate(DFAConsequence* c)
        {
            if (c.invertedOnce || (protectElseNegate && c.protectElseNegate))
            {
                c.truthiness = Truthiness.Unknown;
                c.nullable = Nullable.Unknown;
            }
            else
            {
                c.invertedOnce = true;

                if (c.truthiness != Truthiness.Unknown && c.truthiness != Truthiness.Maybe)
                    c.truthiness = c.truthiness == Truthiness.True
                        ? Truthiness.False : Truthiness.True;

                if (c.nullable != Nullable.Unknown)
                    c.nullable = c.nullable == Nullable.Null ? Nullable.NonNull : Nullable.Null;
            }

            return true;
        }

        lr.walkMaybeTops(&negate);
        return lr;
    }

    DFALatticeRef transferDereference(DFALatticeRef lr, ref Loc loc)
    {
        DFAConsequence* ctx = lr.getContext;
        if (ctx !is null)
        {
            DFAVar* var = ctx.var;

            if (var !is null)
            {
                if (DFAScope* lastLoopyLabel = dfaCommon.lastLoopyLabel)
                {
                    DFAScopeVar* scv = lastLoopyLabel.findScopeVar(var);

                    if (scv !is null && (scv.derefDepth == 0
                            || scv.derefDepth > dfaCommon.currentDFAScope.depth))
                        scv.derefDepth = dfaCommon.currentDFAScope.depth;
                }

                var = dfaCommon.findDereferenceVar(var);
                lr.setContext(var);
            }

            if (ctx.nullable != Nullable.NonNull)
                reportDereference(dfaCommon, ctx, loc);
        }

        return lr;
    }

    DFALatticeRef transferEqual(DFALatticeRef lhs, DFALatticeRef rhs,
            bool equalityIsTrue, bool pointerBitEqual)
    {
        DFAConsequence* lhsCtx = lhs.getContext, rhsCtx = rhs.getContext;
        if (lhsCtx is null || rhsCtx is null)
            return DFALatticeRef.init;

        DFAVar* lhsVar = lhsCtx !is null ? lhsCtx.var : null,
            rhsVar = rhsCtx !is null ? rhsCtx.var : null;

        Truthiness expectedTruthiness = Truthiness.Maybe;
        bool expectedInvertedOnce;

        if (lhsCtx !is null && rhsCtx !is null)
        {
            expectedInvertedOnce = lhsCtx.invertedOnce || rhsCtx.invertedOnce;

            if (pointerBitEqual)
            {
                if (lhsCtx.nullable != Nullable.Unknown && rhsCtx.nullable != Nullable.Unknown
                        && (!lhs.haveNonContext || !rhs.haveNonContext))
                {
                    expectedTruthiness = lhsCtx.nullable == rhsCtx.nullable
                        ? Truthiness.True : Truthiness.False;
                }
            }
            else
            {
                if (lhsCtx.truthiness != Truthiness.Unknown
                        && rhsCtx.truthiness != Truthiness.Unknown)
                {
                    if (lhsCtx.truthiness == Truthiness.Maybe
                            || rhsCtx.truthiness == Truthiness.Maybe)
                        expectedTruthiness = Truthiness.Maybe;
                    else
                        expectedTruthiness = lhsCtx.truthiness == rhsCtx.truthiness
                            ? Truthiness.True : Truthiness.False;
                }
            }
        }

        DFALatticeRef ret = join(lhs, rhs);

        DFAConsequence* c = ret.addConsequence(cast(DFAVar*) null);
        ret.setContext(c);
        c.truthiness = expectedTruthiness;
        c.invertedOnce = expectedInvertedOnce;

        if (DFAConsequence* c2 = ret.findConsequence(rhsVar))
        {
            c.maybe = rhsVar;
            c2.maybe = lhsVar;
        }
        else
            c.maybe = lhsVar;

        if (equalityIsTrue)
        {
            ret.walkMaybeTops((c) => c.protectElseNegate = true);
        }
        else
            ret = transferNegate(ret);

        return ret;
    }

    void transferGoto(DFAScope* toSc, bool isAfter)
    {
        DFAScopeRef scr;
        scr.sc = dfaCommon.currentDFAScope;
        DFAScopeRef temp = scr.copy;
        scr.sc = null;

        if (isAfter)
        {
            if (!toSc.afterScopeState.isNull)
                temp = joinScope(toSc.afterScopeState, temp);
        }
        else
        {
            if (!toSc.beforeScopeState.isNull)
                temp = joinScope(toSc.beforeScopeState, temp);
        }

        toSc.beforeScopeState = temp;
    }

    void transferForwardsGoto(Identifier ident)
    {
        DFAScopeRef scr;
        scr.sc = dfaCommon.currentDFAScope;
        DFAScopeRef temp = scr.copy;
        scr.sc = null;

        dfaCommon.swapForwardLabelScope(ident, (old) {
            if (old.isNull)
                return temp;
            return joinScope(old, temp);
        });
    }

    DFALatticeRef transferLogicalAnd(DFALatticeRef lhs, DFALatticeRef rhs)
    {
        DFAConsequence* cctxLHS = lhs.getContext;
        DFAConsequence* cctxRHS = rhs.getContext;

        /*
        We have two trees that look like:
             constant
            /        \
           leaf      leaf

        And need to recombine them into this form, where the constants are discarded from the origin.
        */

        DFALatticeRef ret = dfaCommon.makeLatticeRef;
        DFAConsequence* cctx = ret.addConsequence(cast(DFAVar*) null);
        ret.setContext(cctx);
        ret.check;

        DFAVar* lastMaybe;

        lhs.walkMaybeTops((DFAConsequence* oldC) {
            if (oldC.var is null)
                return true;

            DFAConsequence* newC = ret.addConsequence(oldC.var, oldC);
            newC.maybe = lastMaybe;
            lastMaybe = newC.var;

            ret.check;
            return true;
        });

        rhs.walkMaybeTops((DFAConsequence* oldC) {
            if (oldC.var is null)
                return true;

            DFAConsequence* result = ret.findConsequence(oldC.var);

            if (result is null)
            {
                DFAConsequence* newC = ret.addConsequence(oldC.var, oldC);
                newC.maybe = lastMaybe;
                lastMaybe = newC.var;
            }
            else
                joinConsequence(result, result, oldC, null, false, false, true);

            ret.check;
            return true;
        });

        foreach (oldC; lhs)
        {
            if (oldC.var is null)
                continue;

            if (!oldC.maybeTopSeen)
            {
                ret.addConsequence(oldC.var, oldC);
                ret.check;
            }
        }

        foreach (oldC; rhs)
        {
            if (oldC.var is null)
                continue;

            if (!oldC.maybeTopSeen)
            {
                ret.addConsequence(oldC.var, oldC);
                ret.check;
            }
        }

        cctx.maybe = lastMaybe;

        if (cctxLHS !is null && cctxRHS !is null)
        {
            if (cctxLHS.truthiness == cctxRHS.truthiness)
                cctx.truthiness = cctxLHS.truthiness;
            else if (cctxLHS.truthiness == Truthiness.False)
                cctx.truthiness = Truthiness.False;
            else if (cctxLHS.truthiness == Truthiness.Maybe || cctxRHS.truthiness
                    == Truthiness.Maybe)
                cctx.truthiness = Truthiness.Maybe;
            else
                cctx.truthiness = Truthiness.Unknown;
        }
        else
            cctx.truthiness = Truthiness.Unknown;

        ret.check;
        return ret;
    }

    DFALatticeRef transferLogicalOr(DFALatticeRef lhs, DFALatticeRef rhs)
    {
        DFAConsequence* cctxLHS = lhs.getContext;
        DFAConsequence* cctxRHS = rhs.getContext;

        /*
        We have two trees that look like:
             constant
            /        \
           leaf      leaf

        And need to recombine them into this form, where the constants are discarded from the origin.
        */

        // (a && b) || (c && d)

        DFALatticeRef ret = dfaCommon.makeLatticeRef;
        DFAVar* lastMaybe;

        lhs.walkMaybeTops((DFAConsequence* oldC) {
            if (oldC.var is null)
                return true;

            DFAConsequence* result = ret.addConsequence(oldC.var);
            DFAConsequence* oldC2 = rhs.findConsequence(oldC.var);
            if (oldC2 is null)
            {
                return true;
            }

            meetConsequence(result, oldC, oldC2);

            result.maybe = lastMaybe;
            lastMaybe = result.var;
            return true;
        });

        rhs.walkMaybeTops((DFAConsequence* oldC) {
            if (oldC.var is null)
                return true;

            DFAConsequence* oldC2 = lhs.findConsequence(oldC.var);
            if (oldC2 !is null)
                return true;

            DFAConsequence* result = ret.addConsequence(oldC.var);

            result.maybe = lastMaybe;
            lastMaybe = result.var;
            return true;
        });

        // now add the consequences that are both in lhs and rhs
        foreach (oldC; lhs)
        {
            if (oldC.var is null || oldC.maybeTopSeen)
                continue;

            DFAConsequence* result = ret.addConsequence(oldC.var);
            DFAConsequence* oldC2 = rhs.findConsequence(oldC.var);
            if (oldC2 is null)
                continue;

            meetConsequence(result, oldC, oldC2);
        }

        // don't forget to add dummy consequences that are only in rhs
        foreach (oldC; rhs)
        {
            if (oldC.var is null || oldC.maybeTopSeen)
                continue;

            ret.addConsequence(oldC.var);
        }

        DFAConsequence* cctx = ret.addConsequence(cast(DFAVar*) null);
        ret.setContext(cctx);
        cctx.maybe = lastMaybe;

        if (cctxLHS !is null && cctxRHS !is null)
        {
            if (cctxLHS.truthiness == Truthiness.True || cctxRHS.truthiness == Truthiness.True)
                cctx.truthiness = Truthiness.True;
            else if (cctxLHS.truthiness == Truthiness.Unknown
                    || cctxRHS.truthiness == Truthiness.Unknown)
                cctx.truthiness = Truthiness.Unknown;
            else
                cctx.truthiness = Truthiness.Maybe;
        }
        else
            cctx.truthiness = Truthiness.Unknown;

        return ret;
    }

    DFALatticeRef transferConditional(DFAScopeRef scrTrue, DFALatticeRef lrTrue,
            DFAScopeRef scrFalse, DFALatticeRef lrFalse)
    {

        this.convergeStatementIf(scrTrue, scrFalse);

        DFAVar* asContext;

        {
            DFAConsequence* cctx;
            DFAVar* trueVar, falseVar;

            cctx = lrTrue.getContext;
            trueVar = cctx !is null ? cctx.var : null;

            cctx = lrFalse.getContext;
            falseVar = cctx !is null ? cctx.var : null;

            if (trueVar !is null && trueVar is falseVar)
                asContext = trueVar;
        }

        DFALatticeRef ret = meet(lrTrue, lrFalse);
        ret.setContext(asContext);
        return ret;
    }

    DFAScopeRef transferLoopyLabelAwareStage(DFAScopeRef previous, DFAScopeRef next)
    {
        if (previous.isNull)
            return next;

        assert(!next.isNull);
        const allJumped = previous.sc.haveJumped && next.sc.haveJumped,
            allReturned = previous.sc.haveReturned && next.sc.haveReturned;

        DFAScopeRef ret = meetScope(previous, next, true);
        assert(!ret.isNull);

        if (allJumped)
            ret.sc.haveJumped = true;
        if (allReturned)
            ret.sc.haveReturned = true;

        return ret;
    }

private:

    DFAScopeRef meetScope(DFAScopeRef scr1, DFAScopeRef scr2, bool copyAll)
    {
        scr1.check;
        scr2.check;

        const depth = dfaCommon.currentDFAScope.depth;

        DFAScopeRef ret;
        ret.sc = dfaCommon.allocator.makeScope(dfaCommon, dfaCommon.currentDFAScope);
        ret.sc.depth = depth;
        ret.sc.haveJumped = scr1.sc.haveJumped && scr2.sc.haveJumped;
        ret.sc.haveReturned = scr1.sc.haveReturned && scr2.sc.haveReturned;

        DFALatticeRef lr1, lr2;
        DFAVar* var;
        while (!(lr1 = scr1.consumeNext(var)).isNull)
        {
            lr2 = scr2.consumeVar(var);

            if (!copyAll && lr2.isNull)
                continue;

            lr1.check;
            lr2.check;

            DFALatticeRef meeted = meet(lr1, lr2, depth);
            assert(!meeted.isNull);
            meeted.check;

            ret.assignLattice(var, meeted);
        }

        if (copyAll)
        {
            while (!(lr2 = scr2.consumeNext(var)).isNull)
            {
                lr2.check;
                ret.assignLattice(var, lr2);
            }
        }

        ret.check;
        return ret;
    }

    DFAScopeRef joinScope(DFAScopeRef scr1, DFAScopeRef scr2)
    {
        scr1.check;
        scr2.check;

        const depth = dfaCommon.currentDFAScope.depth;

        DFAScopeRef ret;
        ret.sc = dfaCommon.allocator.makeScope(dfaCommon, dfaCommon.currentDFAScope);
        ret.sc.depth = depth;
        ret.sc.haveJumped = scr1.sc.haveJumped && scr2.sc.haveJumped;
        ret.sc.haveReturned = scr1.sc.haveReturned && scr2.sc.haveReturned;

        DFALatticeRef lr1;
        DFAVar* var;
        while (!(lr1 = scr1.consumeNext(var)).isNull)
        {
            DFALatticeRef lr2 = scr2.consumeVar(var);

            lr1.check;
            lr2.check;

            DFALatticeRef joined = join(lr1, lr2, depth);
            assert(!joined.isNull);
            joined.check;

            ret.assignLattice(var, joined);
        }

        ret.check;
        return ret;
    }

    // Converge, see Lattice (Abstract algebra) meet operation (lower bound)
    // Operates on a given lattice to converge into current scope's variable state
    DFALatticeRef meet(DFALatticeRef lhs, DFALatticeRef rhs,
            int filterDepthOfVariable = 0, bool couldScopeNotHaveRan = false)
    {
        DFALatticeRef ret = dfaCommon.makeLatticeRef;
        DFAConsequence* constantRHS = rhs.findConsequence(null);

        DFAConsequence* lhsCtx = lhs.getContext;
        DFAVar* lhsVar = lhsCtx !is null ? lhsCtx.var : null;

        version (DebugJoinMeetOp)
        {
            printf("meet %p %d %d\n", lhsVar, filterDepthOfVariable, couldScopeNotHaveRan);
            fflush(stdout);
        }

        foreach (c1; lhs)
        {
            if (c1.var is null)
                continue;

            version (DebugJoinMeetOp)
            {
                printf("meet lhs %p %d\n", c1.var, c1.var.declaredAtDepth);
                fflush(stdout);
            }

            if (filterDepthOfVariable < c1.var.declaredAtDepth && filterDepthOfVariable > 0)
                continue;

            DFAConsequence* result = ret.addConsequence(c1.var);
            DFAConsequence* c2 = rhs.findConsequence(c1.var);

            meetConsequence(result, c1, c2, couldScopeNotHaveRan);

            if (c1.var is lhsVar && constantRHS !is null)
            {
                meetConsequence(result, c1, constantRHS, couldScopeNotHaveRan);
            }
        }

        foreach (c2; rhs)
        {
            if (c2.var is null || lhs.findConsequence(c2.var) !is null)
                continue;

            version (DebugJoinMeetOp)
            {
                printf("meet rhs %p %d\n", c2.var, c2.var.declaredAtDepth);
                fflush(stdout);
            }

            if (filterDepthOfVariable < c2.var.declaredAtDepth && filterDepthOfVariable > 0)
                continue;

            DFAConsequence* result = ret.addConsequence(c2.var);
            meetConsequence(result, c2, null, couldScopeNotHaveRan);
        }

        ret.setContext(lhsVar);
        ret.check;
        return ret;
    }

    // Converge, see Lattice (Abstract algebra) meet operation (upper bound)
    // Operates on a given lattice to converge into current scope's variable state
    DFALatticeRef join(DFALatticeRef lhs, DFALatticeRef rhs, int filterDepthOfVariable = 0,
            DFAVar* ignoreLHSCtx = null, bool ignoreWriteCount = false, bool unknownAware = false)
    {
        DFALatticeRef ret = dfaCommon.makeLatticeRef;
        DFAConsequence* constantRHS = rhs.findConsequence(null);

        DFAConsequence* lhsCtx = lhs.getContext;
        DFAVar* lhsVar = lhsCtx !is null ? lhsCtx.var : null;

        DFAConsequence* rhsCtx = rhs.getContext;
        DFAVar* rhsVar = rhsCtx !is null ? rhsCtx.var : null;

        version (DebugJoinMeetOp)
        {
            printf("Running join on %p and %p, constantRHS=%p, filter=%d, ignoreLHS=%p\n",
                    lhsVar, rhsVar, constantRHS, filterDepthOfVariable, ignoreLHSCtx);
            fflush(stdout);
        }

        void processLHSVar(DFAConsequence* c1)
        {
            if (filterDepthOfVariable < c1.var.declaredAtDepth && filterDepthOfVariable > 0)
                return;

            DFAConsequence* result = ret.addConsequence(c1.var);
            DFAConsequence* c2 = rhs.findConsequence(c1.var);

            const isC1LHSCtx = lhsVar is c1.var;
            joinConsequence(result, c1, c2, null, isC1LHSCtx, ignoreWriteCount, unknownAware);

            if (isC1LHSCtx && constantRHS !is null)
                joinConsequence(result, c1, constantRHS, rhsCtx, true,
                        ignoreWriteCount, unknownAware);
        }

        version (DebugJoinMeetOp)
        {
            printf("joining lhs\n");
            fflush(stdout);
        }

        if (ignoreLHSCtx is null || lhsVar !is ignoreLHSCtx)
        {
            foreach (c1; lhs)
            {
                if (c1.var is null)
                    continue;

                processLHSVar(c1);
            }
        }
        else if (lhsVar !is null)
        {
            DFAVar* var = lhsVar;
            var = var.base;

            while (var !is null)
            {
                processLHSVar(lhs.findConsequence(var));
                var = var.base;
            }
        }

        version (DebugJoinMeetOp)
        {
            printf("joining rhs\n");
            fflush(stdout);
        }

        foreach (c2; rhs)
        {
            if (c2.var is null || ret.findConsequence(c2.var) !is null)
                continue;

            if (filterDepthOfVariable < c2.var.declaredAtDepth && filterDepthOfVariable > 0)
                continue;

            DFAConsequence* result = ret.addConsequence(c2.var);
            joinConsequence(result, c2, null, rhsCtx, false, ignoreWriteCount, unknownAware);
        }

        version (DebugJoinMeetOp)
        {
            printf("joining rhs ctx\n");
            fflush(stdout);
        }

        if (rhsCtx !is null && rhsVar is null && lhsVar !is null)
        {
            DFAConsequence* result = ret.addConsequence(lhsVar);
            joinConsequence(result, rhsCtx, null, null, false, false, unknownAware);
            if (result.writeOnVarAtThisPoint < lhsCtx.writeOnVarAtThisPoint)
                result.writeOnVarAtThisPoint = lhsCtx.writeOnVarAtThisPoint;
        }

        ret.setContext(lhsVar);
        ret.check;

        version (DebugJoinMeetOp)
        {
            printf("joining done\n");
            fflush(stdout);
        }

        return ret;
    }

    void seeWrite(ref DFAVar* assignTo, ref DFALatticeRef from)
    {
        assert(assignTo !is null);
        assignTo.writeCount++;

        const currentDepth = dfaCommon.currentDFAScope.depth;

        dfaCommon.acquireScopeVar(assignTo);
        DFAScope* lastLoopyLabel = dfaCommon.lastLoopyLabel;

        DFAConsequence* c = from.findConsequence(assignTo);
        if (c !is null)
            c.writeOnVarAtThisPoint = assignTo.writeCount;

        if (lastLoopyLabel !is null)
        {
            if (DFAScopeVar* scv = lastLoopyLabel.findScopeVar(assignTo))
            {
                if (scv.assignDepth == 0 || scv.assignDepth > currentDepth)
                    scv.assignDepth = currentDepth;
            }
        }
    }
}
