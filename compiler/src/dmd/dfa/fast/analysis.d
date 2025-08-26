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
        lr.cleanupConstant(ctxVar);

        if (ctx.truthiness == Truthiness.Maybe)
        {
            if (ctxVar !is null && !ctxVar.haveBase)
                dfaCommon.swapLattice(ctxVar, lattice => join(lattice, lr));
        }
        else
        {
            foreach (c; lr)
            {
                if (c.var !is null && !c.var.haveBase)
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

    void convergeStatementIf(DFALatticeRef condition, DFAScopeRef scrTrue,
            DFAScopeRef scrFalse, bool haveFalseBody, bool unknownBranchTaken)
    {
        const lastLoopyLabelDepth = dfaCommon.lastLoopyLabel.depth;
        bool bothJumped, bothReturned;

        // False body should never be null.
        assert(!scrFalse.isNull);

        void protectLoopAgainst(ref DFAScopeRef scr)
        {
            if (dfaCommon.lastLoopyLabel is null)
                return;

            /*
                We have whats looks like:

                for(;condition1;) {
                    if (condition2) {
                        ???
                    } else {
                        ???
                    }
                }

                Where either true or false branch could alter a variable outside of itself.
            */

            foreach (contextVar, l, scv; scr)
            {
                // Ignore any variables declared within the loop
                if (contextVar.declaredAtDepth >= lastLoopyLabelDepth)
                    continue;

                DFAScopeVar* scvParent = dfaCommon.acquireScopeVar(contextVar);
                if (scvParent is null)
                    continue;

                DFAConsequence* c = l.context;
                assert(c !is null);

                DFAConsequence* cParent = scvParent.lr.getContext;
                assert(cParent !is null);

                if (c.truthiness != cParent.truthiness)
                    c.truthiness = Truthiness.Unknown;
                if (c.nullable != cParent.nullable)
                    c.nullable = Nullable.Unknown;
            }
        }

        /*
        Gates look like:

        bool gate;
        if(gate) {
            ???
        } else {
            ???
        }

        Not:

        bool gate1, gate2;
        if (gate1 && gate2) {
            ???
        } else {
            ???
        }
        */
        DFAConsequence* gateConsequence = condition.getGateConsequence;

        void protectGate()
        {
            if (gateConsequence is null)
                return;

            foreach (contextVar, lTrue, scvTrue; scrTrue)
            {
                DFAScopeVar* scvParent = dfaCommon.acquireScopeVar(contextVar);
                if (scvParent is null)
                    continue;

                DFAConsequence* cTrue = lTrue.context;
                assert(cTrue !is null);

                DFAConsequence* cParent = scvParent.lr.getContext;
                assert(cParent !is null);

                DFAScopeVar* scvFalse = scrFalse.findScopeVar(contextVar);
                DFAConsequence* cFalse = scvFalse !is null ? scvFalse.lr.getContext : null;

                if (cFalse !is null)
                {
                    // If true and false branches disagree on state, and if either of them are above parent, set as unknown.

                    if ((cTrue.truthiness != cFalse.truthiness
                            && (cTrue.truthiness > cParent.truthiness
                            || cFalse.truthiness > cParent.truthiness)))
                    {
                        cTrue.truthiness = Truthiness.Unknown;
                        cFalse.truthiness = Truthiness.Unknown;
                    }
                    else if (haveFalseBody && cParent.truthiness != Truthiness.Unknown
                            && (cTrue.truthiness == Truthiness.Unknown
                                || cFalse.truthiness == Truthiness.Unknown))
                    {
                        contextVar.unmodellable = true;
                    }
                    else if (cTrue.nullable != cFalse.nullable
                            && (cTrue.nullable > cParent.nullable
                                || cFalse.nullable > cParent.nullable))
                    {
                        cTrue.nullable = Nullable.Unknown;
                        cFalse.nullable = Nullable.Unknown;
                    }
                    else if (haveFalseBody && cParent.nullable != Nullable.Unknown
                            && (cTrue.nullable == Nullable.Unknown
                                || cFalse.nullable == Nullable.Unknown))
                    {
                        contextVar.unmodellable = true;
                    }
                }
                else
                {
                    if (cTrue.truthiness > cParent.truthiness)
                        cTrue.truthiness = Truthiness.Unknown;
                    else if (cParent.truthiness != Truthiness.Unknown
                            && cTrue.truthiness == Truthiness.Unknown)
                    {
                        contextVar.unmodellable = true;
                    }

                    if (cTrue.nullable > cParent.nullable)
                        cTrue.nullable = Nullable.Unknown;
                    else if (cParent.nullable != Nullable.Unknown
                            && cTrue.nullable == Nullable.Unknown)
                    {
                        contextVar.unmodellable = true;
                    }
                }
            }

            foreach (contextVar, lFalse, scvFalse; scrFalse)
            {
                DFAScopeVar* scvParent = dfaCommon.acquireScopeVar(contextVar);
                if (scvParent is null)
                    continue;

                DFAConsequence* cFalse = lFalse.context;
                assert(cFalse !is null);

                DFAConsequence* cParent = scvParent.lr.getContext;
                assert(cParent !is null);

                if (!scrTrue.isNull && scrTrue.findScopeVar(contextVar) !is null)
                    continue; // handled already

                if (cFalse.truthiness > cParent.truthiness
                        || (cParent.truthiness != Truthiness.Unknown
                            && cFalse.truthiness == Truthiness.Unknown))
                {
                    contextVar.unmodellable = true;
                    cFalse.truthiness = Truthiness.Unknown;
                }

                if (cFalse.nullable > cParent.nullable
                        || (cParent.nullable != Nullable.Unknown
                            && cFalse.nullable == Nullable.Unknown))
                {
                    contextVar.unmodellable = true;
                    cFalse.nullable = Nullable.Unknown;
                }
            }
        }

        protectGate;

        /*
        We have a true body which means we could be in one of the following cases:
        Where ... means user code.
        1.
            if (condition)
            else {
                ???
            }
        2.
            if (condition) {
                ...
            } else {
                ...
            }
        3.
            if (condition) {
                ...
            } else {
            }
        */

        if (scrTrue.isNull)
        {
            // If the true body is missing, that means it could not have executed.
            // Converge the false branch assuming that it will always have executed.
            // This covers scenario 1.

            bothJumped = scrFalse.isNull ? false : scrFalse.sc.haveJumped;
            bothReturned = scrFalse.isNull ? false : scrFalse.sc.haveReturned;

            protectLoopAgainst(scrFalse);
            convergeScope(scrFalse);
        }
        else if (haveFalseBody)
        {
            // We have both a true branch and a false branch with user code.
            // This is scenario 2, except it isn't the full scenario.
            // One of these branches or both may jump.

            /*
            a.
                if (condition) {
                    condition
                    ...
                } else {
                    !condition
                    ...
                }
            b.
                if (condition) {
                    condition
                    ...
                    jump;
                } else {
                    !condition
                    ...
                }
            c.
                if (condition) {
                    condition
                    ...
                } else {
                    !condition
                    ...
                    jump;
                }
            d.
                if (condition) {
                    condition
                    ...
                    jump;
                } else {
                    !condition
                    ...
                    jump;
                }
            */

            bothJumped = scrTrue.sc.haveJumped && scrFalse.sc.haveJumped;
            bothReturned = scrTrue.sc.haveReturned && scrFalse.sc.haveReturned;

            if (scrTrue.sc.haveJumped == scrFalse.sc.haveJumped)
            {
                // In scenario d we've both jumped, any effects at that time were already copied to the jump point.
                // Nothing for us to do in that scenario.

                if (!scrTrue.sc.haveJumped)
                {
                    // In scenario a, neither has jumped, any effects at the end of their bodies should be meet'd.
                    // Then we can converge that into parent scope.

                    protectGate;
                    DFAScopeRef meeted = meetScope(scrTrue, scrFalse, true);
                    assert(!meeted.isNull);
                    protectLoopAgainst(meeted);
                    convergeScope(meeted);
                }
            }
            else if (scrTrue.sc.haveJumped)
            {
                // In scenario b the true branch has jumped, but not the false.
                // Any effects seen at the true branch have been already copied to the jump point.
                protectLoopAgainst(scrFalse);
                convergeScope(scrFalse);
            }
            else if (scrFalse.sc.haveJumped)
            {
                // In scenario c, the false branch has jumped, but not the true.
                // Any effects seen at the false branch have been already copied to the jump point.
                protectLoopAgainst(scrTrue);
                convergeScope(scrTrue);
            }
            else
                assert(0);
        }
        else
        {
            // In scenario 3.
            // We have a true branch with user code, but not a false branch.
            // The false branch contains the effects of the negated condition.

            if (scrTrue.sc.haveJumped)
            {
                /*
                The true branch jumped, which means only the false branch matters.
                if (condition) {
                    condition
                    ...
                    jumped;
                } else {
                    !condition
                }
                */
                protectLoopAgainst(scrFalse);
                convergeScope(scrFalse);
            }
            else
            {
                /*
                The false branch will modify the condition by negating it from within it.
                We really are not interested in it.

                if (condition) {
                    condition
                    ...
                } else {
                    !condition
                }

                Consider:
                if (var !is null) {
                    assert(var !is null);
                } else {
                    assert(var is null);
                }
                Which behavior is correct? That would be the parent.
                */

                protectLoopAgainst(scrTrue);
                convergeStatement(scrTrue, false, true);
            }
        }

        if (bothJumped)
            dfaCommon.currentDFAScope.haveJumped = true;
        if (bothReturned)
            dfaCommon.currentDFAScope.haveReturned = true;
    }

    void convergeStatementLoopyLabels(DFAScopeRef containing, ref Loc loc)
    {
        const scopeMayNotHaveRun = !containing.sc.isLoopyLabelKnownToHaveRun;

        /*
        A loopy label when scope is known to have ran (once):

        Label: {
            ...
            if (condition) {
                increment;
                goto Label;
            }
        }

        When it isn't known to ran once:

        if (condition) {
            Label: {
                ...
                if (condition) {
                    increment;
                    goto Label;
                }
            }
        }

        */

        DFAScopeRef afterScopeState = containing.sc.afterScopeState;
        loopyLabelBeforeContainingCheck(containing, containing.sc.beforeScopeState, loc);

        convergeStatement(containing, false, scopeMayNotHaveRun);
        convergeStatement(afterScopeState, false);
    }

    void loopyLabelBeforeContainingCheck(ref DFAScopeRef containing,
            DFAScopeRef beforeScopeState, ref const(Loc) loc)
    {
        void checkForNull(DFAScopeVar* assertedVar, DFAConsequence* oldC, DFAConsequence* newC)
        {
            version (none)
            {
                printf("check for null on %p\n", assertedVar.var);
                printf("  %p %p %d %d %d\n", oldC, newC, assertedVar.derefDepth,
                        oldC !is null ? oldC.nullable : -1, newC !is null ? newC.nullable : -1);
            }

            if (assertedVar.var.var is null || oldC is null || newC is null
                    || oldC.nullable != Nullable.NonNull
                    || newC.nullable != Nullable.Null || assertedVar.derefDepth == 0)
                return;

            version (none)
            {
                printf("  next %d %d\n", assertedVar.derefAssertedDepth, assertedVar.derefDepth);
            }

            if (assertedVar.derefAssertedDepth > 0
                    && assertedVar.derefDepth < assertedVar.derefAssertedDepth)
                reportLoopyLabelLessNullThan(dfaCommon, assertedVar.var, loc);
            else if (assertedVar.derefAssertedDepth == 0)
                reportLoopyLabelLessNullThan(dfaCommon, assertedVar.var, loc);
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

            DFALatticeRef assertedLatticeRef;
            assertedLatticeRef.lattice = assertedLattice;
            scope (exit)
                assertedLatticeRef.lattice = null;

            foreach (c; assertedLatticeRef)
            {
                if (c.var is null || c.var.var is null)
                    continue;

                DFAScopeVar* newSCV = toProcessScope.findScopeVar(c.var);
                DFAConsequence* newC;
                if (newSCV is null || (newC = newSCV.lr.findConsequence(c.var)) is null)
                    continue;

                DFAScopeVar* currentSCV = dfaCommon.acquireScopeVar(c.var);
                DFAConsequence* currentC;
                if (currentSCV is null || (currentC = currentSCV.lr.findConsequence(c.var)) is null)
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

                const truthinessNotEqual = currentC.truthiness != Truthiness.Unknown
                    && currentC.truthiness != newC.truthiness;
                const nullableNotEqual = currentC.nullable != Nullable.Unknown
                    && currentC.nullable != newC.nullable;
                const assertLessThanAssign = assertedVar.assertDepth <= newSCV.assignDepth;

                if (!assertLessThanAssign || !(truthinessNotEqual || nullableNotEqual))
                    continue;
                else if (assertedVar.assertDepth > 0)
                {
                    // If we relied on the truthiness or nullability of a variable,
                    //  and an assign happened, thats a report.
                    reportLoopyLabelAssertAndAssign(dfaCommon, newSCV, assertedVar, loc);
                }
                else if (nullableNotEqual)
                {
                    // If the nullability is changing, that means its not predictable
                    newC.nullable = Nullable.Unknown;
                    newC.truthiness = Truthiness.Unknown;
                }
                else if (truthinessNotEqual)
                {
                    // If the truthiness is changing, that means its not predictable
                    newC.truthiness = Truthiness.Unknown;
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
    }

    void convergeScope(DFAScopeRef scr)
    {
        const jumped = scr.sc.haveJumped, returned = scr.sc.haveReturned;

        DFALatticeRef lr;
        DFAVar* var;

        for (;;)
        {
            lr = scr.consumeNext(var);
            if (lr.isNull)
                break;

            lr.cleanupConstant(var);

            dfaCommon.check;
            dfaCommon.acquireScopeVar(var);

            dfaCommon.swapLattice(var, (lattice) {
                assert(!lattice.isNull);
                lattice.check;

                DFAVar* lrCtx = lr.getContextVar;
                assert(lrCtx is var);
                assert(!lr.isNull);
                lr.check;
                return lr;
            });

            dfaCommon.check;
        }

        if (jumped)
            dfaCommon.currentDFAScope.haveJumped = true;
        if (returned)
            dfaCommon.currentDFAScope.haveReturned = true;
    }

    void convergeStatement(DFAScopeRef scr, bool allBranchesTaken = true,
            bool couldScopeNotHaveRan = false, bool ignoreWriteCount = false,
            bool unknownAware = false)
    {
        const depth = dfaCommon.currentDFAScope.depth;

        DFALatticeRef lr;
        DFAVar* var;

        for (;;)
        {
            lr = scr.consumeNext(var);
            if (lr.isNull)
                break;

            lr.cleanupConstant(var);

            dfaCommon.check;
            dfaCommon.acquireScopeVar(var);

            dfaCommon.swapLattice(var, (lattice) {
                assert(!lattice.isNull);
                lattice.check;

                DFAVar* lrCtx = lr.getContextVar;
                assert(lrCtx is var);

                // make sure it exists in parent
                DFALatticeRef lr = allBranchesTaken ? join(lattice, lr, depth,
                    null, couldScopeNotHaveRan || ignoreWriteCount, unknownAware) : meet(lattice,
                    lr, depth, couldScopeNotHaveRan);

                assert(!lr.isNull);
                lr.check;
                return lr;
            });

            dfaCommon.check;
        }
    }

    void convergeFunctionCallArgument(DFALatticeRef lr, ParameterDFAInfo* paramInfo,
            ulong paramStorageClass, FuncDeclaration calling, ref Loc loc)
    {
        DFAConsequence* cctx = lr.getContext;
        DFAVar* ctx = cctx !is null ? cctx.var : null;

        void convergeEachConsequence()
        {
            foreach (c; lr)
            {
                if (c.maybeTopSeen || c.var is null || c.var.haveBase)
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

        const isByRef = (paramStorageClass & (STC.ref_ | STC.out_)) != 0;
        const couldEscape = (paramStorageClass & STC.scope_) == 0;

        bool seePointer(DFAVar* var)
        {
            bool handledVar;

            // If the variable can point to something we can model (i.e. symbol offset) to its base variable
            // Or if the parameter is by-ref, then we must consider the output state of the parameter.
            if (isByRef || var.haveBase)
            {
                var.walkRoots((root) {
                    // If the var could be escaped out, forget about reporting on it ever again
                    // If we had escape analysis we could temporarily disable it, but that isn't implemented.
                    if (couldEscape)
                        root.unmodellable = true;

                    // Put the state of the var into an unknown state,
                    //  this prevents it from infesting other variables.
                    DFALatticeRef temp = dfaCommon.makeLatticeRef;
                    temp.setContext(root);
                    dfaCommon.currentDFAScope.assignLattice(root, temp);
                    // now its all set to unknown

                    if (root !is var)
                    {
                        DFAConsequence* c = lr.findConsequence(root);
                        if (c !is null)
                            c.maybeTopSeen = true;
                    }
                    else
                        handledVar = true;
                });
            }

            return handledVar;
        }

        if (ctx is null)
        {
            lr.walkMaybeTops((c) {
                if (c.var is null)
                    return true;

                seePointer(c.var);
                return true;
            });
        }
        else
        {
            if (seePointer(ctx))
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

        void handle(DFAConsequence* c)
        {
            if (c.var is null || c.var.haveBase)
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
                printf("    write on var %d vs %d\n", c.var.writeCount, c.writeOnVarAtThisPoint);
            }

            if (currentDepth < c.var.declaredAtDepth || (!ignoreWriteCount
                    && c.var.writeCount > c.writeOnVarAtThisPoint))
                return;

            if ((scv = dfaCommon.lastLoopyLabel.findScopeVar(c.var)) !is null)
            {
                if (c.nullable == Nullable.NonNull && (scv.derefAssertedDepth == 0
                        || scv.derefAssertedDepth > currentDepth))
                {
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

        // We want the constant context if it exists, to handle equality.
        if (DFAConsequence* cctx = lr.getContext)
        {
            if (!dueToConditional && cctx.truthiness == Truthiness.False && loc.isValid)
                reportAssertIsFalse(dfaCommon, lr, loc);
        }

        // We want the gate consequence, not the constant context.
        // Not interested in an equality. It is about any variable state.
        if (DFAConsequence* cctx = lr.getGateConsequence)
        {
            if (cctx.var !is null)
            {
                if (DFAScopeVar* cctxSCV = dfaCommon.lastLoopyLabel.findScopeVar(cctx.var))
                {
                    if (cctxSCV.assignDepth == 0 || cctxSCV.assertDepth > currentDepth)
                    {
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

    DFALatticeRef transferAssign(DFALatticeRef assignTo, bool construct, bool isBlit,
            DFALatticeRef lr, int alteredState, DFALatticeRef indexLR = DFALatticeRef.init)
    {
        DFAVar* assignToCtx = assignTo.getContextVar;
        DFAVar* lrCtx;
        DFAConsequence* lrCctx = lr.getContext(lrCtx);

        const noLR = lrCctx is null;
        const lrIsTruthy = !noLR ? lrCctx.truthiness == Truthiness.True : false;
        const unmodellable = lrCtx !is null && !lrCtx.isModellable;
        DFALatticeRef ret;

        if (assignToCtx !is null)
        {
            // *var = expr;
            // is very different from:
            // var = expr;

            bool wasDereferenced;

            assignToCtx.visitIfReferenceToAnotherVar((contextVar) {
                wasDereferenced = true;

                // This is a dereference: *var = expr;
                // Which means the effects of lr don't really apply to the lhs.

                if (contextVar.isTruthy || contextVar.isNullable)
                {
                    // The only thing we know for 100% certainty is that contextVar at this point is going to be non-null.

                    DFALatticeRef temp = dfaCommon.makeLatticeRef;
                    DFAConsequence* cctx = temp.addConsequence(contextVar);
                    temp.setContext(cctx);

                    if (contextVar.isTruthy)
                        cctx.truthiness = Truthiness.True;
                    if (contextVar.isNullable)
                        cctx.nullable = Nullable.NonNull;

                    ret = join(ret, temp, 0, null);
                }
            });

            if (!wasDereferenced)
            {
                // We're in a direct assignment
                // Any effects from the lr directly apply to our lhs variable.

                if (!construct && noLR)
                    assignToCtx.unmodellable = true;

                DFALatticeRef assignTo2 = assignTo.copy;
                assignTo2.setContext(assignToCtx);

                DFALatticeRef joined = join(assignTo2,
                        lr.copyWithoutInfiniteLifetime, 0, assignToCtx);
                DFAConsequence* c = joined.addConsequence(assignToCtx);
                joined.setContext(c);

                if (lrCtx !is null && lrCtx.haveInfiniteLifetime)
                {
                    c.truthiness = Truthiness.True;
                    c.nullable = Nullable.NonNull;
                }

                ret = join(ret, joined, 0, null);
            }
        }
        else
        {
            ret = join(assignTo, lr.copyWithoutInfiniteLifetime, 0, null);

            DFAConsequence* c = ret.addConsequence(null);
            ret.setContext(c);

            if (lrCtx !is null && lrCtx.haveInfiniteLifetime)
            {
                c.truthiness = Truthiness.True;
                c.nullable = Nullable.NonNull;
            }

            if (construct && isBlit)
            {
                if (noLR)
                {
                    c.truthiness = Truthiness.False;
                    c.nullable = Nullable.Unknown;
                }
            }
        }

        if (ret.isNull)
            ret = dfaCommon.makeLatticeRef;

        if (!indexLR.isNull)
            ret = this.transferLogicalAnd(ret, indexLR);

        DFAConsequence* retCctx = ret.addConsequence(assignToCtx);
        ret.setContext(retCctx);

        if (alteredState == 1)
        {
            // True
            retCctx.truthiness = Truthiness.True;
        }
        else if (alteredState == 2)
        {
            // NonNull
            retCctx.nullable = Nullable.NonNull;
        }
        else if (alteredState == 3)
        {
            // True & NonNull
            retCctx.truthiness = Truthiness.True;
            retCctx.nullable = Nullable.NonNull;
        }
        else if (alteredState == 4)
        {
            // False & Null
            retCctx.truthiness = Truthiness.False;
            retCctx.nullable = Nullable.Null;
        }

        if (lrIsTruthy && assignToCtx !is null && assignToCtx.isNullable)
            retCctx.nullable = Nullable.NonNull;

        if (lrCtx !is null)
        {
            lrCtx.visitReferenceToAnotherVar((var) {
                // escapes, who knows what its gonna look like after this
                var.unmodellable = true;

                DFAConsequence* c = ret.addConsequence(var);
                c.truthiness = Truthiness.Unknown;
                c.nullable = Nullable.Unknown;
            });
        }

        if (assignToCtx !is null)
        {
            if (!construct)
                seeWrite(assignToCtx, ret);

            dfaCommon.swapLattice(assignToCtx, old => ret.copy);

            if (unmodellable)
                assignToCtx.unmodellable = true;
        }
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
            else if (c.var !is null && c.var.haveInfiniteLifetime)
            {
                // nothing can invert this
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

        if (auto cctx = lr.getContext)
        {
            // !(a && b) only negate the outer expression
            // !(a) want to negate the inner condition
            if (cctx.var is null)
                negate(cctx);
            else
                lr.walkMaybeTops(&negate);
        }

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
                DFAScopeVar* scv = dfaCommon.lastLoopyLabel.findScopeVar(var);

                if (scv !is null && (scv.derefDepth == 0
                        || scv.derefDepth > dfaCommon.currentDFAScope.depth))
                    scv.derefDepth = dfaCommon.currentDFAScope.depth;

                var = dfaCommon.findDereferenceVar(var);
                lr.setContext(var);
            }

            if (ctx.nullable != Nullable.NonNull)
                reportDereference(dfaCommon, ctx, loc);
        }

        return lr;
    }

    /// See_Also: equalityArgTypes
    DFALatticeRef transferEqual(DFALatticeRef lhs, DFALatticeRef rhs,
            bool equalityIsTrue, int equalityType)
    {
        // struct
        // floating point
        // lhs && rhs    static or dynamic array
        // cpu op

        DFAConsequence* lhsCctx = lhs.getContext, rhsCctx = rhs.getContext;
        if (lhsCctx is null || rhsCctx is null)
            return DFALatticeRef.init;
        DFAVar* lhsVar = lhsCctx.var, rhsVar = rhsCctx.var;

        const treatAsPointer = equalityType == 6 || equalityType == 7 || equalityType == 8;
        Truthiness expectedTruthiness = Truthiness.Maybe;

        if (equalityIsTrue)
        {
            if (treatAsPointer)
            {
                if (lhsCctx.nullable == Nullable.Null && lhsCctx.nullable == rhsCctx.nullable)
                    expectedTruthiness = Truthiness.True;
                else if (lhsCctx.truthiness == Truthiness.False
                        && lhsCctx.truthiness == rhsCctx.truthiness)
                    expectedTruthiness = Truthiness.True;
                else if (lhsCctx.truthiness != rhsCctx.truthiness && (lhsCctx.truthiness == Truthiness.False
                        || rhsCctx.truthiness == Truthiness.False)
                        && (lhsCctx.truthiness == Truthiness.True
                            || rhsCctx.truthiness == Truthiness.True))
                    expectedTruthiness = Truthiness.False;
            }
            else
            {
                if (lhsCctx.truthiness == Truthiness.False
                        && lhsCctx.truthiness == rhsCctx.truthiness)
                    expectedTruthiness = Truthiness.True;
                else if (lhsCctx.truthiness != rhsCctx.truthiness && (lhsCctx.truthiness == Truthiness.False
                        || rhsCctx.truthiness == Truthiness.False)
                        && (lhsCctx.truthiness == Truthiness.True
                            || rhsCctx.truthiness == Truthiness.True))
                    expectedTruthiness = Truthiness.False;
            }
        }
        else
        {
            if (treatAsPointer)
            {
                if ((lhsCctx.nullable == Nullable.NonNull
                        || rhsCctx.nullable == Nullable.NonNull)
                        && lhsCctx.nullable != rhsCctx.nullable)
                    expectedTruthiness = Truthiness.True;
                else if (lhsCctx.nullable == Nullable.NonNull && lhsCctx.nullable
                        == rhsCctx.nullable)
                    expectedTruthiness = Truthiness.Maybe;
                else if (lhsCctx.nullable == Nullable.Null && lhsCctx.nullable == rhsCctx.nullable)
                    expectedTruthiness = Truthiness.False;
                else if (lhsCctx.truthiness < Truthiness.False
                        || rhsCctx.truthiness < Truthiness.False)
                    expectedTruthiness = Truthiness.Unknown;
                else if (lhsCctx.truthiness != rhsCctx.truthiness)
                    expectedTruthiness = Truthiness.Maybe;
                else if (lhsCctx.truthiness == rhsCctx.truthiness)
                    expectedTruthiness = Truthiness.False;
            }
            else
            {
                if (lhsCctx.truthiness < Truthiness.False || rhsCctx.truthiness < Truthiness.False)
                    expectedTruthiness = Truthiness.Unknown;
                else if (lhsCctx.truthiness != rhsCctx.truthiness)
                    expectedTruthiness = Truthiness.Maybe;
                else if (lhsCctx.truthiness == rhsCctx.truthiness)
                    expectedTruthiness = Truthiness.False;
            }
        }

        if (expectedTruthiness == Truthiness.Maybe)
        {
            // Copy over the effects from a constant to non-constant with variable.
            // Allows for a == non-null to make a non-null.
            DFAConsequence* toEffectCctx, fromEffectCctx;

            if (lhsVar is null)
            {
                fromEffectCctx = lhsCctx;
                toEffectCctx = rhsCctx;
            }
            else if (rhsVar is null)
            {
                toEffectCctx = lhsCctx;
                fromEffectCctx = rhsCctx;
            }

            if (toEffectCctx !is null && toEffectCctx.var !is null)
            {
                if (toEffectCctx.var.isTruthy && toEffectCctx.truthiness == Truthiness.Unknown)
                    toEffectCctx.truthiness = fromEffectCctx.truthiness;

                if (toEffectCctx.var.isNullable && toEffectCctx.nullable == Nullable.Unknown)
                    toEffectCctx.nullable = fromEffectCctx.nullable;
            }
        }

        const expectedInvertedOnce = lhsCctx.invertedOnce || rhsCctx.invertedOnce;
        DFALatticeRef ret = transferLogicalAnd(lhs, rhs);

        {
            DFAConsequence* c = ret.acquireConstantAsContext(expectedTruthiness, Nullable.Unknown);
            c.invertedOnce = expectedInvertedOnce;

            if (DFAConsequence* c2 = ret.findConsequence(rhsVar))
            {
                c.maybe = rhsVar;
                c2.maybe = lhsVar;
            }
            else
                c.maybe = lhsVar;
        }

        if (treatAsPointer)
        {
            if (equalityIsTrue)
            {
                // var is !null -> var non-null
                // !null is var -> var non-null

                // if lhs or rhs is constant
                //     if lhs or rhs is non-constant && lhs or rhs !is null
                //         upgrade the non-constant to !is null

                if (lhsVar is null && rhsVar !is null && lhsCctx.nullable == Nullable.Null)
                {
                    if (rhsCctx.nullable == Nullable.NonNull)
                        rhsCctx.nullable = Nullable.NonNull;
                }
                else if (lhsVar !is null && rhsVar is null && rhsCctx.nullable == Nullable.Null)
                {
                    if (lhsCctx.nullable == Nullable.NonNull)
                        lhsCctx.nullable = Nullable.NonNull;
                }

                ret.walkMaybeTops((c) => c.protectElseNegate = true);
            }
            else
            {
                // var !is null -> var non-null
                // null !is var -> var non-null

                // if lhs or rhs is constant
                //     if lhs or rhs is non-constant && lhs or rhs is null
                //         upgrade the non-constant to !is null

                if (lhsVar is null && rhsVar !is null && lhsCctx.nullable == Nullable.Null)
                {
                    if (rhsCctx.nullable == Nullable.Null)
                        rhsCctx.nullable = Nullable.NonNull;
                }
                else if (lhsVar !is null && rhsVar is null && rhsCctx.nullable == Nullable.Null)
                {
                    if (lhsCctx.nullable == Nullable.Null)
                        lhsCctx.nullable = Nullable.NonNull;
                }
            }
        }

        if (equalityIsTrue)
            ret.walkMaybeTops((c) => c.protectElseNegate = true);
        else
            ret.walkMaybeTops((c) => c.invertedOnce = true);

        return ret;
    }

    void transferGoto(DFAScope* toSc, bool isAfter)
    {
        DFAScopeRef temp = dfaCommon.currentDFAScope.copy;

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
        DFAScopeRef temp = dfaCommon.currentDFAScope.copy;

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
        DFAConsequence* cctx = ret.acquireConstantAsContext;
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
        DFAConsequence* lhsCctx = lhs.getContext;
        DFAConsequence* rhsCctx = rhs.getContext;
        DFAVar* lhsCtx = lhsCctx !is null ? lhsCctx.var : null,
            rhsCtx = rhsCctx !is null ? rhsCctx.var : null;

        /*
        We have two trees that look like:
             constant
            /        \
           leaf      leaf

        And need to recombine them into this form, where the constants are discarded from the origin.

        (a && b && e) || (c && d && e) -> (e) || (e) -> e

        We are not interested in a, b, c, or d.
        This is due to us having no knowledge if the effect is in effect.
        */

        DFALatticeRef ret = dfaCommon.makeLatticeRef;
        DFAVar* lastMaybe;

        // Add maybe tops, that are in both
        lhs.walkMaybeTops((DFAConsequence* oldC) {
            if (oldC.var is null)
                return true;

            DFAConsequence* result = ret.addConsequence(oldC.var);
            DFAConsequence* oldC2 = rhs.findConsequence(oldC.var);

            if (oldC2 is null)
                return true;

            meetConsequence(result, oldC, oldC2, true);

            result.maybe = lastMaybe;
            lastMaybe = result.var;
            return true;
        });

        // Now add the consequences that are both in lhs and rhs,
        //  that are not maybe tops.
        foreach (oldC; lhs)
        {
            if (oldC.var is null || oldC.maybeTopSeen)
                continue;

            DFAConsequence* result = ret.addConsequence(oldC.var);
            DFAConsequence* oldC2 = rhs.findConsequence(oldC.var);
            if (oldC2 is null)
                continue;

            meetConsequence(result, oldC, oldC2, true);
        }

        DFAVar* newCtx = dfaCommon.findVariablePair(lhsCtx, rhsCtx);
        DFAConsequence* cctx = ret.addConsequence(newCtx);
        ret.setContext(cctx);
        cctx.maybe = lastMaybe;

        if (lhsCctx !is null && rhsCctx !is null)
        {
            if (lhsCctx.truthiness == Truthiness.True || rhsCctx.truthiness == Truthiness.True)
                cctx.truthiness = Truthiness.True;
            else if (lhsCctx.truthiness != Truthiness.Unknown
                    && rhsCctx.truthiness != Truthiness.Unknown)
                cctx.truthiness = Truthiness.Maybe;
        }

        return ret;
    }

    DFALatticeRef transferConditional(DFALatticeRef condition, DFAScopeRef scrTrue,
            DFALatticeRef lrTrue, DFAScopeRef scrFalse, DFALatticeRef lrFalse,
            bool unknownBranchTaken)
    {

        this.convergeStatementIf(condition, scrTrue, scrFalse, false, unknownBranchTaken);
        DFAVar* asContext = dfaCommon.findVariablePair(lrTrue.getContextVar, lrFalse.getContextVar);

        DFALatticeRef ret = meet(lrTrue, lrFalse, 0, true);
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

        for (;;)
        {
            lr1 = scr1.consumeNext(var);
            if (lr1.isNull)
                break;

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
            for (;;)
            {
                lr2 = scr2.consumeNext(var);
                if (lr2.isNull)
                    break;

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
        for (;;)
        {
            lr1 = scr1.consumeNext(var);
            if (lr1.isNull)
                break;

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
        DFAVar* lhsVar = lhs.getContextVar;

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

        DFAVar* lhsVar, rhsVar;
        DFAConsequence* lhsCtx = lhs.getContext(lhsVar), rhsCtx = rhs.getContext(rhsVar);

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
        else if (lhsVar !is null && lhsVar.haveBase)
        {
            lhsVar.visitFirstBase((firstBase) {
                firstBase.walkToRoot((var) {
                    processLHSVar(lhs.findConsequence(var));
                });
            });
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
        DFAConsequence* c = from.findConsequence(assignTo);
        if (c !is null)
            c.writeOnVarAtThisPoint = assignTo.writeCount;

        if (DFAScopeVar* scv = dfaCommon.lastLoopyLabel.findScopeVar(assignTo))
        {
            if (scv.assignDepth == 0 || scv.assignDepth > currentDepth)
                scv.assignDepth = currentDepth;
        }
    }
}
