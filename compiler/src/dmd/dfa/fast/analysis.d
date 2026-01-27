/**
 * Analysis engine for the fast Data Flow Analysis engine.
 *
 * This module implements the mathematical core of the DFA.
 * It is responsible for:
 * 1. Transfer Functions: Calculating how specific operations (Assign, Math, Equal)
 * transform the abstract state (Lattice) of variables.
 * 2. Convergence (Confluence): Merging states from different control flow paths
 * (e.g., merging the "True" and "False" branches of an if-statement).
 * 3. Loop Approximation: Handling loops in O(1) time by making conservative
 * assumptions rather than iterating to a fixed point.
 *
 * Has the convergence and transfer functions.
 *
 * Copyright: Copyright (C) 1999-2026 by The D Language Foundation, All Rights Reserved
 * Authors:   $(LINK2 https://cattermole.co.nz, Richard (Rikki) Andrew Cattermole)
 * License:   $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/dfa/fast/analysis.d, dfa/fast/analysis.d)
 * Documentation: https://dlang.org/phobos/dmd_dfa_fast_analysis.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/dfa/fast/analysis.d
 */
module dmd.dfa.fast.analysis;
import dmd.dfa.fast.structure;
import dmd.dfa.fast.report;
import dmd.dfa.utils;
import dmd.location;
import dmd.identifier;
import dmd.func;
import dmd.declaration;
import dmd.astenums;
import dmd.mtype;
import dmd.root.array;
import dmd.common.outbuffer;
import core.stdc.stdio;

//version = DebugJoinMeetOp;

/***********************************************************
 * The core analyzer that manipulates the Lattice state.
 *
 * This struct provides the overarching join/meet logic, while the specific
 * merge logic is handled in `DFAConsequence`.
 *
 * It is responsible for:
 * - Orchestrating the convergence of scopes (calculating the final state after a block exits).
 * - Managing high-level state transfers between the AST walkers and the internal lattice.
 */
struct DFAAnalyzer
{
    DFACommon* dfaCommon;
    DFAReporter* reporter;

    DFAScopeVar* convergeExpression(DFALatticeRef lr, bool isSideEffect = false)
    {
        if (lr.isNull)
            return null;

        DFAVar* ctxVar;
        DFAConsequence* ctx = lr.getContext(ctxVar);
        assert(ctx !is null);

        lr.cleanupConstant(ctxVar);

        version (DebugJoinMeetOp)
        {
            printf("converge expression for var %p isSideEffect=%d\n", ctxVar, isSideEffect);
            lr.printState("after cleanup");
            flush(stdout);
        }

        DFAScope* sc = isSideEffect ? dfaCommon.getSideEffectScope() : dfaCommon.currentDFAScope;
        DFAScopeVar* ret = sc.getScopeVar(ctxVar);

        while (sc !is null)
        {
            version (DebugJoinMeetOp)
            {
                printf("on sc %p\n", sc);
                flush(stdout);
            }

            DFAScopeVar* scv;

            if (ctx.truthiness == Truthiness.Maybe)
            {
                scv = sc.getScopeVar(ctxVar);

                if (!ctx.maybeTopSeen && ctxVar !is null && !ctxVar.haveBase)
                {
                    scv.lr = join(scv.lr, lr.copy, 0, null, false, true);
                    assert(scv.lr.getContextVar() is ctxVar);
                }
            }
            else
            {
                foreach (c; lr)
                {
                    if (!c.maybeTopSeen && c.var !is null && !c.var.haveBase)
                    {
                        scv = sc.getScopeVar(c.var);

                        DFAConsequence* oldC = scv.lr.getContext;
                        assert(oldC !is null);

                        oldC.joinConsequence(oldC, c, null, false, false, true);
                        assert(scv.lr.getContextVar() is c.var);
                    }
                }
            }

            sc = sc.child;
        }

        return ret;
    }

    /***********************************************************
     * Merges the states from the True and False branches of an If statement.
     *
     * This handles the "Diamond" control flow pattern.
     * 1. It compares the state at the end of the "True" block vs the "False" block.
     * 2. It identifies "Gates" (variables used in the condition, e.g., `if (ptr)`).
     * 3. It calculates the union (Join) of the states to determine the state
     * after the If statement completes.
     *
     * Params:
     * condition = The lattice state of the condition expression.
     * scrTrue = The final state of the True scope.
     * scrFalse = The final state of the False scope.
     * haveFalseBody = True if the if-statement has an `else` block.
     * unknownBranchTaken = True if the condition result is not statically known (Maybe).
     * predicateNegation = State of the predicate negation (0: unknown, 1: negated, 2: not negated).
     */
    void convergeStatementIf(DFALatticeRef condition, DFAScopeRef scrTrue,
            DFAScopeRef scrFalse, bool haveFalseBody, bool unknownBranchTaken,
            int predicateNegation)
    {
        const lastLoopyLabelDepth = dfaCommon.lastLoopyLabel.depth;
        bool bothJumped, bothReturned;

        // False body should never be null.
        assert(!scrFalse.isNull);

        version (none)
        {
            printf("Converging an if statement %d %d, haveFalseBody=%d, unknownBranchTaken=%d, predicateNegation=%d\n",
                    scrTrue.isNull, scrFalse.isNull, haveFalseBody,
                    unknownBranchTaken, predicateNegation);
            condition.printActual("condition");
            scrTrue.printActual("true");
            scrFalse.printActual("false");
        }

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
                if (c.pa != cParent.pa)
                    c.pa = DFAPAValue.Unknown;
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

        /*
        Given a gate, store any output state of a if statement branch into it.
        Ignoring the nature of consequences, and instead look limitedly at the maybe tops.
        */
        void storeGateState(ref DFALatticeRef onto, ref DFAScopeRef scr)
        {
            foreach (contextVar, l; scr)
            {
                l.walkMaybeTops((DFAConsequence* branchC) {
                    // Do no change the state of the gate. Causes bugs.
                    // Stuff like a null checked if statement results in a dereference on null.

                    if (gateConsequence.var !is branchC.var
                        && branchC.var !is null && !branchC.var.haveBase)
                    {
                        DFAConsequence* into = onto.findConsequence(branchC.var);

                        if (into !is null)
                        {
                            if (into.writeOnVarAtThisPoint < branchC.writeOnVarAtThisPoint)
                                into.meetConsequence(into, branchC);
                        }
                        else if ((branchC.var.isTruthy && branchC.truthiness > Truthiness.Maybe)
                            || (branchC.var.isNullable && branchC.nullable != Nullable.Unknown))
                        {
                            onto.addConsequence(branchC.var, branchC);
                        }
                    }

                    return true;
                });
            }
        }

        if (gateConsequence !is null && !gateConsequence.var.haveBase)
        {
            DFAScopeVar* gateScv = dfaCommon.lastLoopyLabel.getScopeVar(gateConsequence.var);

            if (gateScv !is null)
            {
                if (gateScv.gatePredicateWriteCount == 0
                        || gateScv.gatePredicateWriteCount != gateConsequence.writeOnVarAtThisPoint)
                {
                    gateScv.lrGatePredicate = dfaCommon.makeLatticeRef;
                    gateScv.lrGateNegatedPredicate = dfaCommon.makeLatticeRef;
                    gateScv.gatePredicateWriteCount = gateConsequence.writeOnVarAtThisPoint;
                }

                if (predicateNegation == 1)
                {
                    storeGateState(gateScv.lrGateNegatedPredicate, scrTrue);
                    if (haveFalseBody)
                        storeGateState(gateScv.lrGatePredicate, scrFalse);
                }
                else if (predicateNegation == 2)
                {
                    storeGateState(gateScv.lrGatePredicate, scrTrue);
                    if (haveFalseBody)
                        storeGateState(gateScv.lrGateNegatedPredicate, scrFalse);
                }
            }
        }

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
                    }
                }
                else
                {
                    if (cTrue.truthiness > cParent.truthiness)
                        cTrue.truthiness = Truthiness.Unknown;
                    else if (cParent.truthiness != Truthiness.Unknown
                            && cTrue.truthiness == Truthiness.Unknown)
                    {
                    }

                    if (cTrue.nullable > cParent.nullable)
                        cTrue.nullable = Nullable.Unknown;
                    else if (cParent.nullable != Nullable.Unknown
                            && cTrue.nullable == Nullable.Unknown)
                    {
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

                if (scrTrue.sc.haveJumped)
                {
                    // Both jumped, no state to converge.
                }
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

                // I spent over a month trying to get this to be convergeScope (join instead of meet). ~Rikki
                // It is a giant ball of false positives, that cannot be unraveled.
                // It may appear to be a great idea to change this, but I can assure you,
                //  without accepting a false positive or two or three you will not be changing it from this.
                // LEAVE THIS ALONE!
                convergeStatement(scrTrue, false, true);
            }
        }

        if (bothJumped)
            dfaCommon.currentDFAScope.haveJumped = true;
        if (bothReturned)
            dfaCommon.currentDFAScope.haveReturned = true;
    }

    void applyGateOnBranch(DFAVar* gateVar, int predicateNegation, bool branch)
    {
        if (gateVar is null || predicateNegation == 0)
            return;

        DFAScopeVar* scv = dfaCommon.lastLoopyLabel.findScopeVar(gateVar);
        if (scv is null || scv.gatePredicateWriteCount != gateVar.writeCount)
            return;

        void handle(ref DFALatticeRef lr)
        {
            foreach (cGate; lr)
            {
                if (cGate.writeOnVarAtThisPoint < cGate.var.writeCount)
                    continue;

                DFAScopeVar* scv2 = dfaCommon.acquireScopeVar(cGate.var);
                if (scv2 is null)
                    continue;

                DFAConsequence* cCurrent = scv2.lr.getContext;
                assert(cCurrent !is null);

                cCurrent.joinConsequence(cCurrent, cGate, null, false);
            }
        }

        if (branch)
        {
            if (predicateNegation == 1)
                handle(scv.lrGateNegatedPredicate);
            else
                handle(scv.lrGatePredicate);
        }
        else
        {
            if (predicateNegation == 1)
                handle(scv.lrGatePredicate);
            else
                handle(scv.lrGateNegatedPredicate);
        }
    }
    /***********************************************************
     * Converges a loop or labelled block.
     *
     * Fast-DFA Optimization:
     * Unlike traditional "Slow DFAs" which iterate a loop until the state settles
     * (Fixed Point Iteration), this engine visits the loop body once.
     *
     * To ensure safety without iteration:
     * 1. It checks if variables modified in the loop are used inconsistently.
     * 2. If a variable is modified in a way that creates uncertainty (e.g., incrementing),
     * it assumes the "Worst Case" (Unknown state) for that variable after the loop.
     */
    void convergeStatementLoopyLabels(DFAScopeRef containing, ref Loc loc)
    {
        const scopeHaveRun = containing.sc.isLoopyLabelKnownToHaveRun;

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
        if (scopeHaveRun)
            convergeScope(containing);
        else
        {
            if (containing.sc.haveReturned)
                dfaCommon.currentDFAScope.haveReturned = true;
            convergeStatement(containing, false, true);
        }

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
                reporter.onLoopyLabelLessNullThan(assertedVar.var, loc);
            else if (assertedVar.derefAssertedDepth == 0)
                reporter.onLoopyLabelLessNullThan(assertedVar.var, loc);
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

        void checkForDifferentObjects(DFAConsequence* oldC, DFAConsequence* newC)
        {
            if (oldC.obj !is newC.obj)
                newC.obj = null;
        }

        void checkForPA(DFAConsequence* oldC, DFAConsequence* newC)
        {
            if (oldC.pa != newC.pa)
                newC.pa = DFAPAValue.Unknown;
        }

        foreach (var, l2; beforeScopeState)
        {
            DFAScopeVar* oldState = dfaCommon.acquireScopeVar(var);
            DFAScopeVar* newState = containing.findScopeVar(var);
            if (oldState is null || newState is null)
                continue;

            checkForDifferentObjects(oldState.lr.lattice.context, l2.context);
            checkForPA(oldState.lr.lattice.context, l2.context);
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

            checkForDifferentObjects(oldState.lr.lattice.context, l2.context);
            checkForPA(oldState.lr.lattice.context, l2.context);
            checkForNull(newState, oldState.lr.lattice.context, l2.context);
            checkForAssignAfterAssert(containing, newState, l2);
        }
    }

    void convergeScope(DFAScopeRef scr)
    {
        if (scr.isNull)
            return;

        const jumped = scr.sc.haveJumped, returned = scr.sc.haveReturned;

        DFALatticeRef lr;
        DFAScopeVarMergable mergable;
        DFAVar* var;

        for (;;)
        {
            lr = scr.consumeNext(var, mergable);
            if (lr.isNull)
                break;

            lr.cleanupConstant(var);

            dfaCommon.check;
            dfaCommon.acquireScopeVar(var);

            DFAScopeVar* scv = dfaCommon.swapLattice(var, (lattice) {
                assert(!lattice.isNull);
                lattice.check;

                DFAVar* lrCtx = lr.getContextVar;
                assert(lrCtx is var);
                assert(!lr.isNull);
                lr.check;
                return lr;
            });

            if (scv !is null)
                scv.mergable.merge(mergable);
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
        DFAScopeVarMergable mergable;
        DFAVar* var;

        for (;;)
        {
            dfaCommon.check;

            lr = scr.consumeNext(var, mergable);
            if (var is null)
                break;

            lr.cleanupConstant(var);

            DFAScopeVar* scv = dfaCommon.swapLattice(var, (lattice) {
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

            if (scv !is null)
                scv.mergable.merge(mergable);
            dfaCommon.check;
        }
    }

    void convergeFunctionCallArgument(DFALatticeRef lr, ParameterDFAInfo* paramInfo,
            ulong paramStorageClass, FuncDeclaration calling, ref Loc loc)
    {

        const isByRef = (paramStorageClass & (STC.ref_ | STC.out_)) != 0;
        const couldEscape = (paramStorageClass & STC.scope_) == 0
            || (paramStorageClass & (STC.return_ | STC.returnScope | STC.returnRef)) != 0;

        // A function call argument, may initialize the parameter if its by-ref or if its the this pointer.
        this.onRead(lr, loc, paramInfo is null || paramInfo.parameterId == -1 || isByRef, isByRef);

        DFAVar* ctx;
        DFAConsequence* cctx = lr.getContext(ctx);

        if (paramInfo !is null && cctx !is null)
        {
            // ok we have a context variable, check it against paramInfo
            if (paramInfo.notNullIn == Fact.Guaranteed && cctx.nullable == Nullable.Null)
                reporter.onFunctionCallArgumentLessThan(cctx, paramInfo, calling, loc);
        }

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

                    DFAConsequence* rootCctx = lr.findConsequence(root);

                    // Put the state of the var into an unknown state,
                    //  this prevents it from infesting other variables.
                    DFALatticeRef temp = dfaCommon.makeLatticeRef;
                    DFAConsequence* newCctx = temp.setContext(root);

                    if (isByRef && root.isNullable && (cctx.nullable != Nullable.Null
                        || paramInfo is null || paramInfo.notNullOut != Fact.NotGuaranteed))
                    {
                        // Object could've changed.
                        newCctx.obj = dfaCommon.makeObject(rootCctx !is null ? rootCctx.obj : null);
                    }

                    seeWrite(root, temp);
                    this.convergeExpression(temp, true);

                    // now its all set to unknown

                    if (root !is var)
                    {
                        if (rootCctx !is null)
                            rootCctx.maybeTopSeen = true;
                    }
                    else
                        handledVar = true;
                });
            }

            return handledVar;
        }

        void seeObject(DFAObject* obj)
        {
            obj.walkRoots((DFAObject* root) {
                if (root.storageFor !is null)
                {
                    DFAScope* sideEffectScope = dfaCommon.getSideEffectScope();
                    DFAScopeVar* scv = sideEffectScope.getScopeVar(root.storageFor);
                    seeWrite(root.storageFor, scv.lr);
                }
            });
        }

        if (ctx is null)
        {
            lr.walkMaybeTops((c) {
                if (c.var is null)
                    return true;

                seePointer(c.var);
                if (c.obj !is null)
                    seeObject(c.obj);
                return true;
            });
        }
        else
        {
            if (seePointer(ctx))
                cctx.maybeTopSeen = true;
            if (cctx !is null && cctx.obj !is null)
                seeObject(cctx.obj);
        }

        this.convergeExpression(lr, true);
    }

    void transferAssert(DFALatticeRef lr, ref Loc loc, bool ignoreWriteCount,
            bool dueToConditional = false)
    {
        if (lr.isNull)
            return;
        onRead(lr, loc);

        const currentDepth = dfaCommon.currentDFAScope.depth;
        bool modellable = true;

        lr.walkMaybeTops((DFAConsequence* c) {
            if (c.var is null)
                return true;
            else if (!c.var.isModellable)
            {
                modellable = false;
                return false;
            }

            if (c.var.isLength)
            {
                DFAConsequence* bCctx = lr.addConsequence(c.var.base1);
                bCctx.pa = c.pa;

                if ((c.pa.kind == DFAPAValue.Kind.Concrete
                    || c.pa.kind == DFAPAValue.Kind.Lower) && c.pa.value > 0)
                {
                    bCctx.truthiness = Truthiness.True;
                    bCctx.nullable = Nullable.NonNull;
                }
            }

            return true;
        });

        void handle(DFAConsequence* c)
        {
            if (c.var is null || c.var.haveBase)
                return;
            DFAScopeVar* scv = dfaCommon.acquireScopeVar(c.var);
            c.var.assertedCount++;

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

                old.joinConsequence(old, c, null, false, ignoreWriteCount, false);

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
            if (modellable && !dueToConditional && cctx.truthiness == Truthiness.False
                    && loc.isValid)
            {
                bool disable;

                /*
                Supports:
                if (gate)
                    assert(!gate);
                and
                if (!gate)
                    assert(gate);
                We also have to consider if its the same value based upon write count.
                Note: we don't care what the truthiness value actually is for the gate consequence,
                    we're interested in its inversion status.
                However we don't need the actual predicate integer (see ExpressionWalker.walkCondition).
                The flag in the consequence is enough, as !!gate should set the lr to unknown not false.
                */

                if (DFAConsequence* gateCctx = lr.getGateConsequence)
                {
                    if (DFAScopeVar* gateSCV = dfaCommon.lastLoopyLabel.findScopeVar(gateCctx.var))
                    {
                        version (none)
                        {
                            printf("gate for %p, %d != %d - %d\n", gateCctx.var, gateSCV.gatePredicateWriteCount,
                                    gateCctx.writeOnVarAtThisPoint,
                                    cast(int)(gateCctx.var.param !is null));

                            printf("    %d %d %d %d\n", gateCctx.invertedOnce,
                                    gateSCV.assertTrueDepth, gateSCV.assertFalseDepth, currentDepth);
                        }

                        if (gateSCV.gatePredicateWriteCount != gateCctx.writeOnVarAtThisPoint - cast(
                                int)(gateCctx.var.param !is null))
                        {
                        }
                        else if (!gateCctx.invertedOnce)
                        {
                            disable = gateSCV.assertTrueDepth != 0
                                && gateSCV.assertTrueDepth > gateSCV.assertFalseDepth;
                        }
                        else
                            disable = gateSCV.assertFalseDepth <= currentDepth;
                    }
                }

                if (!disable)
                    reporter.onAssertIsFalse(lr, loc);
            }
        }

        // We want the gate consequence, not the constant context.
        // Not interested in an equality. It is about any variable state.
        // Update the depths, to give future asserts information needed.
        if (DFAConsequence* gateCctx = lr.getGateConsequence)
        {
            if (DFAScopeVar* gateSCV = dfaCommon.lastLoopyLabel.getScopeVar(gateCctx.var))
            {
                version (none)
                {
                    printf("gate store %p, %d %d %d\n", gateCctx.var,
                            gateSCV.assignDepth, gateSCV.assertDepth, currentDepth);
                    printf("    %d %d %d\n", gateCctx.truthiness,
                            gateSCV.assertTrueDepth, gateSCV.assertFalseDepth);
                }

                if (gateSCV.assignDepth == 0 || gateSCV.assertDepth > currentDepth)
                {
                    gateSCV.assertDepth = currentDepth;

                    /*
                        Set the depth of assert when not unknown to true/false values.
                        This should not be normalized onto the actual state of the variable,
                         but the resulting expression value.

                        Given:
                        if (gate)
                            assert(!gate);
                        Regardless of gate being known as true/maybe/false,
                         this will allow us to do a primitivate variation of VRP and effectively make the argument false.
                        */
                    if (gateCctx.truthiness == Truthiness.False
                            && (gateSCV.assertFalseDepth == 0
                                || gateSCV.assertFalseDepth > currentDepth))
                        gateSCV.assertFalseDepth = currentDepth;
                    else if (gateCctx.truthiness >= Truthiness.Maybe
                            && (gateSCV.assertTrueDepth == 0
                                || gateSCV.assertTrueDepth > currentDepth))
                    {
                        gateSCV.assertTrueDepth = currentDepth;
                        gateSCV.assertFalseDepth = 0;
                    }
                }
            }
        }

        foreach (c; lr)
        {
            handle(c);
        }
    }

    /***********************************************************
     * Updates the state of a variable after an assignment (`a = b`).
     *
     * This moves the state from the RHS (Right Hand Side) lattice to the
     * LHS (Left Hand Side) variable.
     *
     * Logic:
     * - Direct Assignment: `a = 5` (a becomes 5).
     * - Pointer Assignment: `*p = 5` (We don't change `p`, we assume memory at `p` changed).
     * - Construct: `int a = 5` (Initialization).
     */
    DFALatticeRef transferAssign(DFALatticeRef assignTo, bool construct, bool isBlit,
            DFALatticeRef lr, int alteredState, ref Loc loc,
            DFALatticeRef indexLR = DFALatticeRef.init)
    {

        DFAVar* assignToCtx = assignTo.getContextVar;
        DFAVar* lrCtx;
        DFAConsequence* lrCctx = lr.getContext(lrCtx);
        const noLR = lrCctx is null;
        const lrIsTruthy = !noLR ? lrCctx.truthiness == Truthiness.True : false;
        const unmodellable = lrCtx !is null && !lrCtx.isModellable;
        DFALatticeRef ret;

        this.onRead(assignTo, loc, true);
        // Explicitly allow returns of uninitialized variables.
        this.onRead(lr, loc, assignToCtx !is null && assignToCtx is dfaCommon.getReturnVariable);

        if (assignToCtx !is null)
        {
            // *var = expr;
            // is very different from:
            // var = expr;

            bool wasDereferenced;

            assignToCtx.visitIfReferenceToAnotherVar((contextVar) {
                wasDereferenced = true;

                // This is a dereference: *contextVar = expr;
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

                ret = dfaCommon.makeLatticeRef;
                DFAConsequence* cctx = ret.addConsequence(assignToCtx, lrCctx);
                ret.setContext(cctx);

                if (!construct && noLR)
                    assignToCtx.unmodellable = true;
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
        else if (alteredState == 5)
        {
            retCctx.truthiness = Truthiness.Unknown;
            retCctx.nullable = Nullable.Unknown;
        }

        if (lrIsTruthy && assignToCtx !is null && assignToCtx.isNullable)
            retCctx.nullable = Nullable.NonNull;

        if (retCctx.truthiness == Truthiness.Maybe)
            retCctx.truthiness = Truthiness.Unknown;

        if (assignToCtx !is null)
        {
            bool exactlyOneRoot;

            assignToCtx.visitIfReadOfReferenceToAnotherVar((root) {
                DFAConsequence* c = assignTo.findConsequence(root);

                if (c !is null && c.obj !is null)
                {
                    DFAVar* firstRoot;
                    int rootCount;

                    c.obj.walkRoots((objRoot) {
                        if (objRoot.storageFor !is null && !objRoot.storageFor.haveBase)
                        {
                            if (firstRoot !is null)
                            {
                                objRoot.storageFor.unmodellable = true;
                                DFAConsequence* cUnk = ret.addConsequence(objRoot.storageFor);
                                cUnk.truthiness = Truthiness.Unknown;
                                cUnk.nullable = Nullable.Unknown;
                            }
                            else
                                firstRoot = objRoot.storageFor;

                            rootCount++;
                        }
                    });

                    if (rootCount == 1)
                    {
                        exactlyOneRoot = true;
                        this.seeWrite(firstRoot, ret);

                        DFAConsequence* c2 = ret.addConsequence(firstRoot);
                        c2.truthiness = retCctx.truthiness;
                        c2.nullable = retCctx.nullable;
                        c2.pa = retCctx.pa;
                    }
                    else if (rootCount > 1)
                    {
                        firstRoot.unmodellable = true;
                        DFAConsequence* cUnk = ret.addConsequence(firstRoot);
                        cUnk.truthiness = Truthiness.Unknown;
                        cUnk.nullable = Nullable.Unknown;
                    }
                }
            });

            if ((!assignToCtx.haveBase && assignToCtx.var is null)
                    || (assignToCtx.haveBase && !exactlyOneRoot))
            {
                if (lrCctx !is null && lrCctx.obj !is null)
                {
                    lrCctx.obj.walkRoots((objRoot) {
                        if (objRoot.storageFor !is null && !objRoot.storageFor.haveBase)
                        {
                            objRoot.storageFor.unmodellable = true;
                            DFAConsequence* cUnk = ret.addConsequence(objRoot.storageFor);
                            cUnk.truthiness = Truthiness.Unknown;
                            cUnk.nullable = Nullable.Unknown;
                        }
                    });
                }
            }

            seeWrite(assignToCtx, ret);

            ret.setContext(assignToCtx);
            DFAScopeVar* scv = this.convergeExpression(ret.copy, true);
            assert(scv !is null);

            if (assignToCtx.isNullable && retCctx.nullable == Nullable.Null)
            {
                scv.mergable.nullAssignWriteCount = assignToCtx.writeCount;
                scv.mergable.nullAssignAssertedCount = assignToCtx.assertedCount;
            }

            if (unmodellable)
                assignToCtx.unmodellable = true;
        }

        return ret;
    }

    DFALatticeRef transferNegate(DFALatticeRef lr, Type type,
            bool protectElseNegate = false, bool limitToContext = false)
    {
        bool requireMaybeContext;

        bool negate(DFAConsequence* c)
        {
            c.pa.negate(type);

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

                if (c.var !is null && c.var.isBoolean)
                {
                    /*
                    Handle the case where:
                    assert(!condition);

                    You don't want the condition variable to effect the output lattice truthiness,
                     but you do want the variable to alter.
                    */
                    requireMaybeContext = c.truthiness <= Truthiness.Maybe;
                    c.truthiness = c.truthiness == Truthiness.False
                        ? Truthiness.True : Truthiness.False;
                }
                else if (c.truthiness > Truthiness.Maybe)
                {
                    c.truthiness = c.truthiness == Truthiness.True
                        ? Truthiness.Unknown : Truthiness.True;
                }

                if (c.nullable != Nullable.Unknown)
                    c.nullable = c.nullable == Nullable.NonNull ? Nullable.Unknown
                        : Nullable.NonNull;
            }

            return true;
        }

        if (auto cctx = lr.getContext)
        {
            // !(a && b) only negate the outer expression
            // !(a) want to negate the inner condition
            if (cctx.var is null || limitToContext)
                negate(cctx);
            else
                lr.walkMaybeTops(&negate);

            if (requireMaybeContext)
            {
                DFAConsequence* newCctx = lr.acquireConstantAsContext(Truthiness.Maybe,
                        Nullable.Unknown, null);
                // Don't forget to patch the maybe's, impacts asserts.
                newCctx.maybe = cctx.var;
            }
        }

        return lr;
    }

    DFALatticeRef transferMathOp(DFALatticeRef lhs, DFALatticeRef rhs, Type type, PAMathOp op)
    {
        DFAConsequence* lhsCctx = lhs.getContext;
        DFAConsequence* rhsCctx = rhs.getContext;

        assert(lhsCctx !is null);
        assert(rhsCctx !is null);

        if (lhsCctx.obj !is null)
            lhsCctx.obj.mayNotBeExactPointer = true;
        if (rhsCctx.obj !is null)
            rhsCctx.obj.mayNotBeExactPointer = true;

        DFAPAValue newValue = lhsCctx.pa;
        final switch (op)
        {
        case PAMathOp.add:
            newValue.addFrom(rhsCctx.pa, type);
            break;
        case PAMathOp.sub:
            newValue.subtractFrom(rhsCctx.pa, type);
            break;
        case PAMathOp.mul:
            newValue.multiplyFrom(rhsCctx.pa, type);
            break;
        case PAMathOp.div:
            newValue.divideFrom(rhsCctx.pa, type);
            break;
        case PAMathOp.mod:
            newValue.modulasFrom(rhsCctx.pa, type);
            break;
        case PAMathOp.and:
            newValue.bitwiseAndBy(rhsCctx.pa, type);
            break;
        case PAMathOp.or:
            newValue.bitwiseOrBy(rhsCctx.pa, type);
            break;
        case PAMathOp.xor:
            newValue.bitwiseXorBy(rhsCctx.pa, type);
            break;
        case PAMathOp.pow:
            newValue.powerBy(rhsCctx.pa, type);
            break;
        case PAMathOp.leftShift:
            newValue.leftShiftBy(rhsCctx.pa, type);
            break;
        case PAMathOp.rightShiftSigned:
            newValue.rightShiftSignedBy(rhsCctx.pa, type);
            break;
        case PAMathOp.rightShiftUnsigned:
            newValue.rightShiftUnsignedBy(rhsCctx.pa, type);
            break;

        case PAMathOp.postInc:
        case PAMathOp.postDec:
            assert(0);
        }

        DFALatticeRef ret = transferLogicalAnd(lhs, rhs);
        ret.check;

        if (ret.isNull)
            ret = dfaCommon.makeLatticeRef;
        DFAConsequence* cctx = ret.acquireConstantAsContext();
        cctx.pa = newValue;

        ret.check;
        return ret;
    }

    DFALatticeRef transferDereference(DFALatticeRef lr, ref Loc loc)
    {
        DFAConsequence* ctx = lr.getContext;
        bool couldBeNull;

        if (ctx !is null)
        {
            DFAVar* var = ctx.var;

            if (var !is null)
            {
                DFAScopeVar* scv;

                if ((scv = dfaCommon.lastLoopyLabel.findScopeVar(var)) !is null)
                {
                    if (scv.derefDepth == 0 || scv.derefDepth > dfaCommon.currentDFAScope.depth)
                        scv.derefDepth = dfaCommon.currentDFAScope.depth;
                }

                if ((scv = dfaCommon.currentDFAScope.findScopeVar(var)) !is null)
                {
                    if (var.writeCount > 0 && scv.mergable.nullAssignAssertedCount == var.assertedCount
                            && scv.mergable.nullAssignWriteCount == var.writeCount
                            && var.var !is null)
                        couldBeNull = true;
                }

                var = dfaCommon.findDereferenceVar(var);
                lr.setContext(var);
            }

            if (ctx.nullable == Nullable.Unknown)
            {
                // Infer input nullability

                if (couldBeNull)
                    reporter.onDereference(ctx, loc);
                else if (ctx.var !is null && ctx.var.param !is null
                        && !ctx.var.param.specifiedByUser && !dfaCommon.currentDFAScope.inConditional
                        && ctx.writeOnVarAtThisPoint == 1 && ctx.var.assertedCount == 0)
                {
                    if (dfaCommon.debugIt)
                        printf("Infer variable as non-null `%s` at %s\n",
                                ctx.var.var.ident.toChars, loc.toChars);

                    ctx.nullable = Nullable.NonNull;
                    if (!ctx.var.doNotInferNonNull)
                        ctx.var.param.notNullIn = ParameterDFAInfo.Fact.Guaranteed;
                }
            }
            else if (ctx.nullable == Nullable.Null)
                reporter.onDereference(ctx, loc);
        }

        return lr;
    }

    /// See_Also: equalityArgTypes
    DFALatticeRef transferEqual(DFALatticeRef lhs, DFALatticeRef rhs,
            bool equalityIsTrue, EqualityArgType equalityType, bool isIdentity)
    {
        // struct
        // floating point
        // lhs && rhs    static or dynamic array
        // cpu op

        DFAConsequence* lhsCctx = lhs.getContext, rhsCctx = rhs.getContext;
        if (lhsCctx is null || rhsCctx is null)
            return DFALatticeRef.init;

        DFAVar* lhsVar = lhsCctx.var, rhsVar = rhsCctx.var;
        Truthiness expectedTruthiness;

        bool couldBeUnknown;

        checkPAVar(lhsVar, couldBeUnknown);
        checkPAVar(rhsVar, couldBeUnknown);

        const treatAsInteger = equalityType == EqualityArgType.Unknown;
        const treatAsPointer = equalityType == EqualityArgType.DynamicArray
            || equalityType == EqualityArgType.AssociativeArray
            || equalityType == EqualityArgType.Nullable;

        dfaCommon.printState((ref OutBuffer ob, scope PrintPrefixType prefix) {
            ob.printf("Transfer equal treatAsInteger=%d, treatAsPointer=%d, couldBeUnknown=%d",
                treatAsInteger, treatAsPointer, couldBeUnknown);
            ob.writestring("\n");

            prefix("");
            ob.printf("lhs cctx %p, lhs var %p, rhs cctx %p, rhs var %p",
                lhsCctx, lhsVar, rhsCctx, rhsVar);
            ob.writestring("\n");
        });

        if ((lhsVar is null || lhsVar.isModellable) && (rhsVar is null || rhsVar.isModellable))
        {
            expectedTruthiness = Truthiness.Maybe;

            if (equalityIsTrue)
            {
                if (treatAsPointer)
                {
                    if (lhsCctx.nullable == Nullable.NonNull && rhsCctx.nullable == Nullable.NonNull
                            && lhsCctx.obj !is null && lhsCctx.obj is rhsCctx.obj
                            && !lhsCctx.obj.mayNotBeExactPointer)
                        expectedTruthiness = isIdentity ? Truthiness.True : Truthiness.Maybe;
                    else if (lhsCctx.nullable == Nullable.Null
                            && lhsCctx.nullable == rhsCctx.nullable)
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
                    expectedTruthiness = lhsCctx.pa.compareEqual(rhsCctx.pa);

                    if (expectedTruthiness < Truthiness.False)
                    {
                        if (lhsCctx.truthiness == Truthiness.False
                                && lhsCctx.truthiness == rhsCctx.truthiness)
                            expectedTruthiness = Truthiness.True;
                        else if (!treatAsInteger && lhsCctx.truthiness != rhsCctx.truthiness
                                && (lhsCctx.truthiness == Truthiness.False
                                    || rhsCctx.truthiness == Truthiness.False)
                                && (lhsCctx.truthiness == Truthiness.True
                                    || rhsCctx.truthiness == Truthiness.True))
                            expectedTruthiness = Truthiness.False;
                        else
                            expectedTruthiness = Truthiness.Maybe;
                    }
                    else if (couldBeUnknown || !treatAsInteger)
                        expectedTruthiness = Truthiness.Maybe;
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
                    else if (lhsCctx.nullable == Nullable.NonNull
                            && lhsCctx.nullable == rhsCctx.nullable)
                    {
                        if (lhsCctx.obj !is null && lhsCctx.obj is rhsCctx.obj
                                && !lhsCctx.obj.mayNotBeExactPointer)
                            expectedTruthiness = isIdentity ? Truthiness.False : Truthiness.Maybe;
                        else
                            expectedTruthiness = Truthiness.Maybe;
                    }
                    else if (lhsCctx.nullable == Nullable.Null
                            && lhsCctx.nullable == rhsCctx.nullable)
                        expectedTruthiness = Truthiness.False;
                }
                else
                {
                    expectedTruthiness = lhsCctx.pa.compareNotEqual(rhsCctx.pa);

                    if (expectedTruthiness >= Truthiness.False)
                    {
                        if (couldBeUnknown || !treatAsInteger)
                            expectedTruthiness = Truthiness.Maybe;
                    }
                    else
                        expectedTruthiness = Truthiness.Maybe;
                }
            }
        }

        dfaCommon.printState((ref OutBuffer ob, scope PrintPrefixType prefix) {
            ob.printf("Expected truthiness of equality %d", expectedTruthiness);
            ob.writestring("\n");
        });

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
                const copy = (toEffectCctx.var.isTruthy
                        && toEffectCctx.truthiness == Truthiness.Unknown)
                    || (toEffectCctx.var.isNullable && toEffectCctx.nullable == Nullable.Unknown);

                if (copy)
                {
                    if (equalityIsTrue)
                    {
                        if (toEffectCctx.var.isTruthy)
                            toEffectCctx.truthiness = fromEffectCctx.truthiness;
                        if (toEffectCctx.var.isNullable)
                            toEffectCctx.nullable = fromEffectCctx.nullable;
                    }
                    else
                    {
                        if (toEffectCctx.var.isTruthy)
                            toEffectCctx.truthiness = fromEffectCctx.truthiness == Truthiness.True ? Truthiness.False
                                : (fromEffectCctx.truthiness == Truthiness.False
                                        ? Truthiness.True : Truthiness.Unknown);
                        if (toEffectCctx.var.isNullable)
                            toEffectCctx.nullable = fromEffectCctx.nullable == Nullable.NonNull ? Nullable.Null
                                : (fromEffectCctx.nullable == Nullable.Null
                                        ? Nullable.NonNull : Nullable.Unknown);
                    }
                }
            }
        }

        const expectedInvertedOnce = lhsCctx.invertedOnce || rhsCctx.invertedOnce;
        DFALatticeRef ret = transferLogicalAnd(lhs, rhs);

        {
            DFAConsequence* c = ret.acquireConstantAsContext(expectedTruthiness,
                    Nullable.Unknown, null);
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

    DFALatticeRef transferGreaterThan(bool orEqualTo, DFALatticeRef lhs, DFALatticeRef rhs)
    {
        DFAVar* lhsVar, rhsVar;
        DFAConsequence* lhsCctx = lhs.getContext(lhsVar);
        DFAConsequence* rhsCctx = rhs.getContext(rhsVar);

        assert(lhsCctx !is null);
        assert(rhsCctx !is null);

        bool couldBeUnknown;
        checkPAVar(lhsCctx.var, couldBeUnknown);
        checkPAVar(rhsCctx.var, couldBeUnknown);

        Truthiness expectedTruthiness;

        if ((lhsVar is null || lhsVar.isModellable) && (rhsVar is null || rhsVar.isModellable))
        {
            expectedTruthiness = orEqualTo ? lhsCctx.pa.greaterThanOrEqual(
                    rhsCctx.pa) : lhsCctx.pa.greaterThan(rhsCctx.pa);

            if (couldBeUnknown)
                expectedTruthiness = Truthiness.Maybe;

            if (lhsVar !is null)
            {
                if (rhsCctx.pa.kind == DFAPAValue.Kind.Concrete
                        && (rhsCctx.pa.value > 0 || (!orEqualTo && rhsCctx.pa.value == 0)))
                {
                    // ok clearly non-null

                    if (lhsVar.isTruthy)
                        lhsCctx.truthiness = Truthiness.True;
                    if (lhsVar.isNullable)
                        lhsCctx.nullable = Nullable.NonNull;
                }

                lhsVar.walkRoots((var) {
                    if (var is lhsVar)
                        return;

                    DFAConsequence* cctx = lhs.findConsequence(var);
                    if (cctx is null)
                        return;

                    cctx.truthiness = lhsCctx.truthiness;
                    cctx.nullable = lhsCctx.nullable;
                    cctx.pa = lhsCctx.pa;
                });
            }

            if (rhsVar !is null)
            {
                rhsVar.walkRoots((var) { var.doNotInferNonNull = true; });
            }
        }

        DFALatticeRef ret = this.transferLogicalAnd(lhs, rhs);
        ret.acquireConstantAsContext(expectedTruthiness, Nullable.Unknown, null);
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
        const lhsCctxMaybe = cctxLHS !is null && cctxLHS.truthiness == Truthiness.Maybe;

        if (lhsCctxMaybe)
            cctxLHS.truthiness = Truthiness.True;

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

        DFAVar* firstMaybe;
        DFAVar** lastMaybe = &firstMaybe;

        lhs.walkMaybeTops((DFAConsequence* oldC) {
            if (oldC.var is null)
                return true;

            DFAConsequence* newC = ret.addConsequence(oldC.var, oldC);

            *lastMaybe = newC.var;
            lastMaybe = &newC.maybe;

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

                *lastMaybe = newC.var;
                lastMaybe = &newC.maybe;
            }
            else
                result.joinConsequence(result, oldC, null, false, false, true);

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

        cctx.maybe = firstMaybe;

        if (cctxLHS !is null && cctxRHS !is null)
        {
            if (cctxLHS.truthiness == cctxRHS.truthiness)
                cctx.truthiness = cctxLHS.truthiness;
            else if (cctxLHS.truthiness == Truthiness.False)
                cctx.truthiness = Truthiness.False;
            else if (lhsCctxMaybe || cctxRHS.truthiness == Truthiness.Maybe)
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

            result.meetConsequence(oldC, oldC2, true);

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

            result.meetConsequence(oldC, oldC2, true);
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

    DFALatticeRef transferConditional(DFALatticeRef condition, DFAScopeRef scrTrue, DFALatticeRef lrTrue,
            DFAScopeRef scrFalse, DFALatticeRef lrFalse, bool unknownBranchTaken,
            int predicateNegation)
    {

        this.convergeStatementIf(condition, scrTrue, scrFalse, false,
                unknownBranchTaken, predicateNegation);

        DFAVar* trueVar, falseVar;
        DFAConsequence* trueCctx = lrTrue.getContext(trueVar),
            falseCctx = lrFalse.getContext(falseVar);

        DFAObject* trueObj = trueCctx !is null ? trueCctx.obj : null;
        DFAObject* falseObj = falseCctx !is null ? falseCctx.obj : null;

        DFAVar* asContext = dfaCommon.findVariablePair(trueVar, falseVar);

        DFALatticeRef ret = meet(lrTrue, lrFalse, 0, true);

        DFAConsequence* cctx = ret.setContext(asContext);
        cctx.obj = dfaCommon.makeObject(trueObj, falseObj);
        return ret;
    }

    DFAScopeRef transferLoopyLabelAwareStage(DFAScopeRef previous, DFAScopeRef next)
    {
        assert(!next.isNull);

        if (next.sc.haveJumped || next.sc.haveReturned)
        {
            /*
                Handles the case where you have:

                int* ptr;
                switch(thing) {
                    case 0:
                        ptr = new int;
                        break;
                    default:
                        return;
                }
            */
            return previous;
        }

        if (previous.isNull)
            return next;

        const allJumped = previous.sc.haveJumped && next.sc.haveJumped,
            allReturned = previous.sc.haveReturned && next.sc.haveReturned;

        DFAScopeRef ret = meetScope(previous, next, true, true);
        assert(!ret.isNull);

        if (allJumped)
            ret.sc.haveJumped = true;
        if (allReturned)
            ret.sc.haveReturned = true;

        return ret;
    }

    void onRead(ref DFALatticeRef lr, ref Loc loc, bool willInit = false,
            bool isByRef = false, bool forMathOp = false)
    {
        version (none)
        {
            lr.printStructure("READ READ READ");
            printf("READ READ value %d %d\n", willInit, isByRef);
        }

        // Called by statement, expressions and analysis.
        DFAVar* contextVar;
        DFAConsequence* cctx = lr.getContext(contextVar);

        if (contextVar is null)
            return;
        assert(cctx !is null);

        DFALatticeRef toStore;

        void seeRootObject(DFAObject* root)
        {
            version (none)
            {
                printf("root object %p var %p\n", root, root.storageFor);
            }

            // Don't apply effects from a variable that isn't actually modelled i.e. indirection.

            if (root.storageFor !is null && !root.storageFor.haveBase)
            {
                DFALatticeRef lr = dfaCommon.acquireLattice(root.storageFor);
                DFAConsequence* cctx = lr.getContext;

                if (cctx !is null && cctx.writeOnVarAtThisPoint == 0)
                    reporter.onReadOfUninitialized(root.storageFor, lr, loc, forMathOp);

                if (toStore.isNull)
                    toStore = lr;
                else
                    toStore = meet(toStore, lr);
            }
        }

        if (willInit)
        {
            // We differentiate if it is some form of initialize either lhs or rhs and isByRef because initialization of a struct member
            // does not necessarily read the struct itself (offsets are fine), whereas ref parameters
            // likely imply a read or dependency that requires initialization.

            // When initializing (writing), we only care if we are reading a variable to determine the address.
            // e.g. `*ptr = 2` reads `ptr`. `struct.field = 2` does NOT read `struct`.
            // `visitIfReadOfReferenceToAnotherVar` implements this logic (dereferences read base, offsets do not).

            contextVar.visitIfReadOfReferenceToAnotherVar((DFAVar* root) {
                if (root.var is null || root is contextVar || root.unmodellable
                    || root.haveInfiniteLifetime)
                    return;

                DFAConsequence* c = lr.findConsequence(root);
                if (c is null)
                    return;

                if (c.writeOnVarAtThisPoint == 0)
                    reporter.onReadOfUninitialized(root, lr, loc, forMathOp);
            });
        }
        else if (isByRef)
        {
            // For ref params, we generally require initialization unless it's 'out', but 'out' should be handled elsewhere/differently?
            // Existing logic assumes 'ref' requires init.

            contextVar.visitIfReferenceToAnotherVar((DFAVar* root) {
                if (root.var is null || root is contextVar || root.unmodellable
                    || root.haveInfiniteLifetime)
                    return;

                DFAConsequence* c = lr.findConsequence(root);
                if (c is null)
                    return;

                if (c.writeOnVarAtThisPoint == 0)
                    reporter.onReadOfUninitialized(root, lr, loc, forMathOp);
                else if (c.obj !is null)
                    c.obj.walkRoots(&seeRootObject);
            });
        }
        else
        {
            // We don't care about the case where indirection is involved.
            // int val1 = void;
            // int* ptr = &val1;
            // int val2 = *ptr; // no error

            if (!contextVar.haveBase)
            {
                if (contextVar.var !is null && cctx.writeOnVarAtThisPoint == 0)
                    reporter.onReadOfUninitialized(contextVar, lr, loc, forMathOp);
            }

            contextVar.visitIfReadOfReferenceToAnotherVar((DFAVar* root) {
                version (none)
                {
                    printf("got a variable %p %p\n", root, root.var);
                    printf("    %d %d %d\n", root.haveBase, root.unmodellable,
                        root.haveInfiniteLifetime);
                }

                if (root.haveBase || root.unmodellable || root.haveInfiniteLifetime)
                    return;

                DFAConsequence* c = lr.findConsequence(root);
                if (c is null)
                    return;

                version (none)
                {
                    printf("    %d\n", c.writeOnVarAtThisPoint);
                }

                if (root.var !is null && c.writeOnVarAtThisPoint == 0)
                    reporter.onReadOfUninitialized(root, lr, loc, forMathOp);
                else if (c.obj !is null)
                    c.obj.walkRoots(&seeRootObject);
            });

            cctx.copyFrom(toStore.getContext);
        }
    }

private:

    DFAScopeRef meetScope(DFAScopeRef scr1, DFAScopeRef scr2, bool copyAll,
            bool couldScopeNotHaveRan = false)
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
        DFAScopeVarMergable mergable1, mergable2;
        DFAVar* var;

        for (;;)
        {
            lr1 = scr1.consumeNext(var, mergable1);
            if (lr1.isNull)
                break;

            lr2 = scr2.consumeVar(var, mergable2);

            if (!copyAll && lr2.isNull)
                continue;

            lr1.check;
            lr2.check;

            DFALatticeRef meeted = meet(lr1, lr2, depth, couldScopeNotHaveRan);
            assert(!meeted.isNull);
            meeted.check;

            DFAScopeVar* scv = ret.assignLattice(var, meeted);
            scv.mergable.merge(mergable1);
            scv.mergable.merge(mergable2);
        }

        if (copyAll)
        {
            for (;;)
            {
                lr2 = scr2.consumeNext(var, mergable2);
                if (lr2.isNull)
                    break;

                lr2.check;
                DFAScopeVar* scv = ret.assignLattice(var, lr2);
                scv.mergable.merge(mergable2);
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

        DFALatticeRef lr1, lr2;
        DFAScopeVarMergable mergable1, mergable2;
        DFAVar* var;

        for (;;)
        {
            lr1 = scr1.consumeNext(var, mergable1);
            if (lr1.isNull)
                break;

            lr2 = scr2.consumeVar(var, mergable2);

            lr1.check;
            lr2.check;

            DFALatticeRef joined = join(lr1, lr2, depth);
            assert(!joined.isNull);
            joined.check;

            DFAScopeVar* scv = ret.assignLattice(var, joined);
            scv.mergable.merge(mergable1);
            scv.mergable.merge(mergable2);
        }

        ret.check;
        return ret;
    }

    /***********************************************************
     * The Lattice 'Meet' operation (Intersection / Lower Bound).
     *
     * Used when we are combining facts that MUST be true.
     * Example: If `x` is NonNull in path A AND `x` is NonNull in path B,
     * then `x` is NonNull.
     */
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

            result.meetConsequence(c1, c2, couldScopeNotHaveRan);

            if (c1.var is lhsVar && constantRHS !is null)
            {
                result.meetConsequence(c1, constantRHS, couldScopeNotHaveRan);
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
            result.meetConsequence(c2, null, couldScopeNotHaveRan);
        }

        ret.setContext(lhsVar);
        ret.check;
        return ret;
    }

    /***********************************************************
     * The Lattice 'Join' operation (Union / Upper Bound).
     *
     * Used when merging diverging paths where EITHER could have happened.
     * Example: If `x` is 5 in path A, and `x` is 6 in path B.
     * Join(A, B) -> `x` is "Unknown Integer" (because it could be either).
     */
    DFALatticeRef join(DFALatticeRef lhs, DFALatticeRef rhs, int filterDepthOfVariable = 0,
            DFAVar* ignoreLHSCtx = null, bool ignoreWriteCount = false, bool unknownAware = false)
    {
        DFALatticeRef ret = dfaCommon.makeLatticeRef;
        DFAConsequence* constantRHS = rhs.findConsequence(null);

        DFAVar* lhsVar, rhsVar;
        DFAConsequence* lhsCtx = lhs.getContext(lhsVar), rhsCtx = rhs.getContext(rhsVar);

        version (DebugJoinMeetOp)
        {
            printf("Running join on %p and %p, constantRHS=%p, filter=%d, ignoreLHS=%p, ignoreWriteCount=%d, unknownAware=%d\n",
                    lhsVar, rhsVar, constantRHS, filterDepthOfVariable,
                    ignoreLHSCtx, ignoreWriteCount, unknownAware);
            fflush(stdout);
        }

        void processLHSVar(DFAConsequence* c1)
        {
            version (DebugJoinMeetOp)
            {
                printf("Processing LHS var %p\n", c1.var);
                fflush(stdout);
            }

            if (filterDepthOfVariable < c1.var.declaredAtDepth && filterDepthOfVariable > 0)
                return;

            DFAConsequence* result = ret.addConsequence(c1.var);
            DFAConsequence* c2 = rhs.findConsequence(c1.var);

            const isC1LHSCtx = lhsVar is c1.var;
            result.joinConsequence(c1, c2, null, isC1LHSCtx, ignoreWriteCount, unknownAware);

            if (isC1LHSCtx && constantRHS !is null)
                result.joinConsequence(c1, constantRHS, rhsCtx, true,
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
            version (DebugJoinMeetOp)
            {
                printf("Processing RHS var %p\n", c2.var);
                fflush(stdout);
            }

            if (c2.var is null || ret.findConsequence(c2.var) !is null)
                continue;

            if (filterDepthOfVariable < c2.var.declaredAtDepth && filterDepthOfVariable > 0)
                continue;

            DFAConsequence* result = ret.addConsequence(c2.var);
            result.joinConsequence(c2, null, rhsCtx, false, ignoreWriteCount, unknownAware);
        }

        version (DebugJoinMeetOp)
        {
            printf("joining rhs ctx\n");
            fflush(stdout);
        }

        if (rhsCtx !is null && rhsVar is null && lhsVar !is null)
        {
            version (DebugJoinMeetOp)
            {
                printf("Processing RHS context var %p to lhs context var %p\n", rhsCtx.var, lhsVar);
                fflush(stdout);
            }

            DFAConsequence* result = ret.addConsequence(lhsVar);
            result.joinConsequence(rhsCtx, null, null, false, false, unknownAware);
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

    void checkPAVar(DFAVar* var, ref bool couldBeUnknown)
    {
        if (var is null)
            return;

        if (var.declaredAtDepth > 0 && dfaCommon.lastLoopyLabel.depth > var.declaredAtDepth)
            couldBeUnknown = true;
    }

    void seeWrite(ref DFAVar* assignTo, ref DFALatticeRef from)
    {
        assert(assignTo !is null);
        const currentDepth = dfaCommon.currentDFAScope.depth;

        assignTo.walkRoots((root) {
            root.writeCount++;

            dfaCommon.acquireScopeVar(root);

            if (DFAScopeVar* scv = dfaCommon.lastLoopyLabel.findScopeVar(root))
            {
                if (scv.assignDepth == 0 || scv.assignDepth > currentDepth)
                    scv.assignDepth = currentDepth;
            }

            DFAConsequence* c = from.addConsequence(root);
            c.writeOnVarAtThisPoint = root.writeCount;
        });
    }
}
