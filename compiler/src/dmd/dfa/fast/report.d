/**
 * Reporting mechanism for the fast Data Flow Analysis engine.
 *
 * This module translates the abstract state of the DFA into concrete compiler errors.
 * It is responsible for:
 * 1. Null Checks: Reporting errors when null pointers are dereferenced.
 * 2. Contract Validation: Ensuring functions fulfill their `out` contracts (e.g., returning non-null).
 * 3. Logic Errors: Detecting assertions that are provably false at compile time.
 *
 * Copyright: Copyright (C) 1999-2026 by The D Language Foundation, All Rights Reserved
 * Authors:   $(LINK2 https://cattermole.co.nz, Richard (Rikki) Andrew Cattermole)
 * License:   $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/dfa/fast/report.d, dfa/fast/report.d)
 * Documentation: https://dlang.org/phobos/dmd_dfa_fast_report.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/dfa/fast/report.d
 */
module dmd.dfa.fast.report;
import dmd.dfa.fast.structure;
import dmd.location;
import dmd.func;
import dmd.errorsink;
import dmd.declaration;
import dmd.astenums;
import core.stdc.stdio;

///
alias Fact = ParameterDFAInfo.Fact;
///
alias EscapedRelationship = ParameterDFAInfo.EscapedRelationship;

/***********************************************************
 * The interface for reporting DFA errors and warnings.
 *
 * This struct acts as the sink for all findings. It checks if a specific
 * violation (like a null dereference) should be reported based on the
 * variable's modellability and depth, then sends it to the global `ErrorSink`.
 */
struct DFAReporter
{
    DFACommon* dfaCommon;
    ErrorSink errorSink;

    /***********************************************************
     * Reports an error if a variable is dereferenced while known to be null.
     *
     * This is triggered by expressions like `*ptr` or `ptr.field` when the DFA
     * determines `ptr` has a `Nullable.Null` state.
     *
     * Params:
     *      on = The consequence containing the variable state (must be Nullable).
     *      loc = The source location of the dereference.
     */
    void onDereference(DFAConsequence* on, ref Loc loc)
    {
        if (!dfaCommon.debugUnknownAST && on is null)
            return;
        assert(on !is null);
        if (on.var is null)
            return;

        int fail;
        assert(on.nullable != Nullable.NonNull);

        if (on.var is null || on.var.var is null)
            fail = __LINE__;
        else if (!on.var.isModellable)
            fail = __LINE__;
        else
        {
            if (on.var.oldestLifeTimeAllowedDepth >= dfaCommon.lastLoopyLabel.depth)
                errorSink.error(loc, "Dereference on null variable `%s`",
                        on.var.var.ident.toChars);
            else
                fail = __LINE__;
        }
    }

    void onLoopyLabelLessNullThan(DFAVar* var, ref const Loc loc)
    {
        if (var !is null && !var.isModellable)
            return;

        errorSink.error(loc, "Variable `%s` was required to be non-null and has become null",
                var.var.ident.toChars);
    }

    /***********************************************************
     * Validates constraints at the end of a scope.
     *
     * This checks if output parameters (like `out` or `ref` parameters) meet their
     * guaranteed post-conditions. For example, if a function parameter is marked
     * to guarantee a non-null output, this ensures the variable is actually non-null
     * when the scope exits.
     */
    void onEndOfScope(FuncDeclaration fd, ref const Loc loc)
    {
        // this is where we validate escapes, for a specific location

        // Step 1. for escape analysis reporting, see deltas
        // If we've jumped via continue, throw, or goto, disable delta's check.
        // Step 2. for escape analysis inferrence promote to stack

        DFAVar* returnVar = dfaCommon.getReturnVariable();

        {
            // 1.

            foreach (DFAVar* intoVar, DFALattice* intoLR; *dfaCommon.currentDFAScope)
            {
                version (none)
                {
                    printf("intoVar %p\n", intoVar);
                    intoLR.printStructure("lr");
                }

                // We skip the return variable specifically as it may have junk values in it
                if (!dfaCommon.currentDFAScope.controlFlowReturned && intoVar is returnVar)
                    continue;
                else if (!intoVar.isNullable)
                    continue;

                // intoVar is a known location, so it won't be a global.
                // If we have returned, then we also consider the return value.

                if (intoVar is returnVar || (intoVar.var !is null && intoVar.oldestLifeTimeAllowedDepth > 0))
                {
                    // We're going into a stack variable, lets make sure any object we're putting into it as <= for other stack variables.

                    DFAConsequence* cctx = intoLR.context;

                    if (cctx.obj !is null)
                    {
                        bool silenceFutureErrors = true;

                        checkForEscapes(intoVar, returnVar, cctx.obj, silenceFutureErrors, loc);

                        if (silenceFutureErrors)
                            cctx.obj = null; // silence future errors
                    }
                }
            }
        }

        {
            // 2.

            // DO NOT MERGE THIS TURNED ON
            // TURN THIS OFF
            // TURN THIS OFF
            // TURN THIS OFF
            // TURN THIS OFF

            dfaCommon.allocator.allStackVariables((DFAVar* var) {
                if (var.unmodellable || var.param !is null)
                    return;
                else if (var.var is null || !var.var.type.isTypeClass)
                    return; // only applies to classes on stack

                if (!var.mayEscapeWithoutIndirection)
                {
                    version (none)
                    {
                        printf("infer as on stack %s at %s\n",
                            var.var.ident.toChars, var.var.loc.toChars);
                    }

                    var.var.onstack = true;
                }
            });
        }

        if (!dfaCommon.currentDFAScope.controlFlowReturned)
            return;

        // validate/infer on to function
        foreachFunctionVariable(dfaCommon, fd, (scv) {
            ParameterDFAInfo* param = scv.var.param;

            if (scv.var.unmodellable || param is null)
                return;

            DFAConsequence* cctx = scv.lr.getContext;

            assert(cctx !is null);
            assert(cctx.var is scv.var);

            Fact suggestedNotNullOut = param.notNullOut;

            if (suggestedNotNullOut == Fact.Guaranteed && cctx.nullable != Nullable.NonNull)
                suggestedNotNullOut = Fact.NotGuaranteed;
            else if (suggestedNotNullOut == Fact.Unspecified && cctx.nullable == Nullable.NonNull)
                suggestedNotNullOut = Fact.Guaranteed;

            param.inferred.notNullOut = suggestedNotNullOut;
        });
    }

    void onEndOfFunction(FuncDeclaration fd, ref Loc loc)
    {
        version (none)
        {
            printf("End of function attributes for `%s` at %s\n", fd.ident.toChars, loc.toChars);
        }

        auto tf = fd.type.isTypeFunction;

        // validate/infer on to function
        foreachFunctionVariable(dfaCommon, fd, (DFAScopeVar* scv) {
            DFAVar* var = scv.var;
            ParameterDFAInfo* param = var.param;

            if (param is null)
                return;

            version (none)
            {
                if (scv.var.var !is null)
                    printf("Variable %p `%s` ", scv.var, scv.var.var.ident.toChars);
                else
                    printf("Variable %p ", scv.var);

                printf("unmodellable=%d, isTruthy=%d, isNullable=%d, isByRef=%d, writeCount=%d\n", scv.var.unmodellable, scv.var.isTruthy,
                    scv.var.isNullable, scv.var.isByRef, scv.var.writeCount);
                printf("    notNullIn=%d/%d, notNullOut=%d/%d\n", param.userSupplied.notNullIn,
                    param.inferred.notNullIn, param.userSupplied.notNullOut,
                    param.inferred.notNullOut);
            }

            if (var.isNullable)
            {
                if (var.unmodellable)
                {
                    param.inferred.notNullIn = Fact.Unspecified;
                    param.inferred.notNullOut = Fact.Unspecified;
                }
                else
                {
                    if (param.inferred.notNullIn == Fact.Unspecified)
                        param.inferred.notNullIn = Fact.NotGuaranteed;

                    if (var.isByRef)
                    {
                        if (var.writeCount > 1)
                        {
                            if (param.inferred.notNullOut == Fact.Unspecified)
                                param.inferred.notNullOut = Fact.NotGuaranteed;
                        }
                        else
                            param.inferred.notNullOut = param.inferred.notNullIn;
                    }
                    else
                        param.inferred.notNullOut = Fact.Unspecified;
                }
            }

            if (!var.unmodellable)
            {
                if (param.inferred.willEscape(-1) != ParameterDFAInfo.EscapedRelationship.Unknown)
                {
                    // escapes into an unknown location, don't infer
                }
                else
                {
                    if (!var.mayEscapeWithoutIndirection)
                        param.inferred.escapeIntoNothing = true;
                }
            }

            if (tf.trust == TRUST.safe && param.userSupplied.escapeIntoNothing
                && !param.inferred.escapeIntoNothing && param.inferred.escapesInto != 0)
            {
                errorSink.error(var.var.loc, "Parameter is required to be scope but escapes");

                if (param.inferred.willEscape(-1) != ParameterDFAInfo.EscapedRelationship.Unknown)
                    errorSink.errorSupplemental(var.var.loc, "Escapes into an unknown location");
                else if (var.mayEscapeWithoutIndirection)
                    errorSink.errorSupplemental(var.var.loc, "Escapes directly");
            }

            version (none)
            {
                printf("    notNullIn=%d/%d, notNullOut=%d/%d\n", param.userSupplied.notNullIn,
                    param.inferred.notNullIn, param.userSupplied.notNullOut,
                    param.inferred.notNullOut);
            }
        });
    }

    /***********************************************************
     * Reports an error if an assertion is statically provable to be false.
     *
     * If the DFA determines that the condition `x` in `assert(x)` is definitively false
     * (e.g., `assert(null)` or `assert(0)` after analysis), it reports this logic error.
     */
    void onAssertIsFalse(ref DFALatticeRef lr, ref Loc loc)
    {
        DFAConsequence* cctx;
        if (!(lr.isModellable && (lr.haveNonContext || (cctx = lr.getContext).var !is null)))
            return; // ignore literals, too false positive heavy

        errorSink.error(loc, "Assert can be proven to be false");
    }

    /***********************************************************
     * Reports an error if a function argument violates the callee's expectations.
     *
     * Example: Passing `null` to a function parameter marked as requiring non-null.
     */
    void onFunctionCallArgumentLessThan(DFAConsequence* c,
            ParameterDFAInfo* paramInfo, FuncDeclaration calling, ref Loc loc)
    {
        if (c.var !is null && !c.var.isModellable)
            return;

        errorSink.error(loc, "Argument is expected to be non-null but was null");

        if (paramInfo.parameterId >= 0)
        {
            VarDeclaration param = (*calling.parameters)[paramInfo.parameterId];
            int argId = paramInfo.parameterId + calling.needThis;
            errorSink.errorSupplemental(param.loc,
                    "For parameter `%s` in argument %d", param.ident.toChars, argId);
        }
        else
            errorSink.errorSupplemental(calling.loc, "For parameter `this` in called function");
    }

    void onReadOfUninitialized(DFAVar* var, ref DFALatticeRef lr, ref Loc loc, bool forMathOp)
    {
        if (!var.isModellable || var.oldestLifeTimeAllowedDepth == 0 || (!forMathOp
                && var.isFloatingPoint) || var.var is null)
            return;
        else if ((var.var.storage_class & STC.temp) != 0)
            return; // Compiler generated, likely to be "fine"
        else if (var.oldestLifeTimeAllowedDepth < dfaCommon.lastLoopyLabel.depth)
            return; // Can we really know what state the variable is in? I don't think so.

        // The reason floating point is special cased here, is to allow catching of mathematical operations,
        //  on a floating point typed variable, that was default initialized.
        // The NaN will propagate on that operation, which is basically never wanted.
        // It is essentially a special case of uninitialized variables,
        //  where the default could never be what someone wants, even if it was zero.
        const floatingPointDefaultInit = var.isFloatingPoint && var.wasDefaultInitialized;

        if (floatingPointDefaultInit)
        {
            errorSink.error(loc,
                    "Expression reads a default initialized variable that is a floating point type");
            errorSink.errorSupplemental(loc,
                    "It will have the value of Not Any Number(nan), it will be propagated with mathematical operations");

            errorSink.errorSupplemental(var.var.loc, "For variable `%s`", var.var.ident.toChars);
            errorSink.errorSupplemental(var.var.loc,
                    "Initialize to %s.nan or 0 explicitly to disable this error", var.var.type.kind);
        }
        else
        {
            errorSink.error(loc,
                    "Expression reads from an uninitialized variable, it must be written to at least once before reading");
            errorSink.errorSupplemental(var.var.loc, "For variable `%s`", var.var.ident.toChars);
        }

        version (none)
        {
            lr.printActual("uninit report");

            dfaCommon.allocator.allVariables((DFAVar* var) {
                printf("var %p base1=%p, base2=%p, writeCount=%d, isStaticArray=%d",
                    var, var.base1, var.base2, var.writeCount, var.isStaticArray);

                if (var.var !is null)
                {
                    printf(", `%s` at %s", var.var.ident.toChars, var.var.loc.toChars);
                }

                printf("\n");
            });
        }
    }

    void onThrowEscape(DFAObject* obj, ref const Loc loc)
    {
        if (obj is null)
            return;
        checkForUnknownEscape("throw", obj, loc, true);
    }

    void onGlobalEscape(DFAVar* intoVar, DFAObject* obj, ref const Loc loc)
    {
        if (obj is null)
            return;
        checkForUnknownEscape("global", obj, loc, false);
    }

    void onDelayEscapeOfObject(DFAVar* intoVar, DFAObject* obj, ref Loc loc)
    {
        version (none)
        {
            printf("On delay of obj %p for var %p at %s\n", obj, intoVar, loc.toChars);
        }

        DFAVar* returnVar = dfaCommon.getReturnVariable;
        bool silenceFutureErrors;

        obj.walk((DFAObject* root) {
            version (none)
            {
                printf("    root %p\n", root);
            }

            if (root.delayOnReadErrorOfEscape)
            {
                checkForEscapes(intoVar, returnVar, root, silenceFutureErrors, loc, true);
                return false;
            }

            return true;
        });
    }

private:

    void checkForEscapes(DFAVar* intoVar, DFAVar* returnVar, DFAObject* parentObject,
            ref bool silenceFutureErrors, ref const Loc loc, bool noDelay = false)
    {
        version (none)
        {
            printf("checkForEscapes intoVar=%p, returnVar=%p, parentObject=%p\n",
                    intoVar, returnVar, parentObject);
        }

        if (intoVar !is returnVar)
        {
            if (intoVar.param is null || parentObject.minimumDeclaredAtDepth
                    >= intoVar.oldestLifeTimeAllowedDepth)
            {
                silenceFutureErrors = false;

                if (parentObject.minimumDeclaredAtDepth == intoVar.oldestLifeTimeAllowedDepth)
                    return;
            }
        }

        bool emittedEscapeError, lookAtConstraintOnly;

        void onDemandEscapeError()
        {
            if (emittedEscapeError)
                return;

            emittedEscapeError = true;

            // ugh oh! the memory has too long of a lifetime!
            if (intoVar.var !is null)
            {
                errorSink.error(loc, "Stack variable stores a lifetime that exceeds its own");
                errorSink.errorSupplemental(intoVar.var.loc,
                        "For variable `%s`", intoVar.var.ident.toChars);
            }
            else
                errorSink.error(loc, "Stack variable exceeds its lifetime by being returned");
        }

        void inferParameter(DFAVar* from, bool hadAnIndirection,
                bool haveConstraintOnLifeTime, bool inCell)
        {
            EscapedRelationship currentRel = from.param.inferred.willEscape(
                    intoVar.param.parameterId);

            EscapedRelationship toInferRel;

            // T var = rhs;
            // T* var = rhs;
            // This can be by-value based upon rhs;

            // ref T var = x;
            // This can be by-value only if it has had an indirection that isn't constrained.

            if (from.isByRef && (inCell || (!hadAnIndirection && intoVar.isByRef)))
                toInferRel = EscapedRelationship.PointerTo;
            else if (from.isByRef && !inCell)
                toInferRel = EscapedRelationship.ByValue;
            else if (hadAnIndirection && !haveConstraintOnLifeTime)
                toInferRel = EscapedRelationship.ByValue;
            else
                toInferRel = EscapedRelationship.PointerTo;

            if (currentRel < toInferRel)
                from.param.inferred.willEscape(intoVar.param.parameterId, toInferRel);

            if (hadAnIndirection && toInferRel == EscapedRelationship.ByValue)
                from.mayEscapeWithIndirection = true;
            else
                from.mayEscapeWithoutIndirection = true;
        }

        parentObject.walkIndirection((DFAObject* obj, bool hadAnIndirection,
                bool haveConstraintOnLifeTime, bool inCell) {
            if (obj.constrainedBy is intoVar)
                return;

            version (none)
            {
                printf("potential escape 1 obj %p, hadAnIndirection=%d, haveConstraintOnLifeTime=%d, inCell=%d\n",
                    obj, hadAnIndirection, haveConstraintOnLifeTime, inCell);
            }

            if (obj.lifeTimeUnderstood && !noDelay)
            {
                // S* ptr;
                // {
                //   S buf;
                //   ptr = &buf;
                //   buf.__dtor;
                // }
                // S temp = *ptr; // error: ptr contains an escaped object that has had cleanup run on it

                parentObject.delayOnReadErrorOfEscape = true;
                silenceFutureErrors = false;
                return;
            }

            // Cannot outlive this variable.
            DFAVar* constrainedTo = (obj.constrainedBy !is null && obj.constrainedBy.var !is null) ? obj.constrainedBy
                : null;
            // The cell of a variable.
            DFAVar* cellOf = (obj.storageFor !is null && obj.storageFor.var !is null) ? obj.storageFor
                : null;

            version (none)
            {
                printf("derivedFrom=%p, constrainedTo %p, cellOf %p\n",
                    obj.derivedFrom, constrainedTo, cellOf);
            }

            // Both constrainedTo and cellOf cannot be escape from.
            // The benefit of differentiating them allows us to tell the user that it was the cell that was escaped,
            //  versus an object that was stored in it, that was later escaped.

            // Have multiple layers of pointers, which we can't model.
            if (obj.derivedFrom !is null)
                cellOf = null;

            DFAVar* either = constrainedTo !is null ? constrainedTo : cellOf;

            if (either is null && haveConstraintOnLifeTime)
                lookAtConstraintOnly = true;

            if (intoVar.param !is null && either !is null && either.param !is null)
            {
                either.mayEscapeInitialValue = true;
                inferParameter(either, hadAnIndirection, haveConstraintOnLifeTime, inCell);
                return;
            }

            if (hadAnIndirection)
            {
            }
            else if (cellOf !is null && !cellOf.unmodellable
                && intoVar.youngestLifeTimeAllowedDepth < cellOf.oldestLifeTimeAllowedDepth)
            {
                cellOf.mayEscapeInitialValue = true;

                onDemandEscapeError();
                errorSink.errorSupplemental(cellOf.var.loc,
                    "A pointer to the cell of the variable `%s` has potentially escaped",
                    cellOf.var.ident.toChars);
            }
            else if (constrainedTo !is null && !constrainedTo.unmodellable
                && obj.onTheStack && intoVar.youngestLifeTimeAllowedDepth < constrainedTo.oldestLifeTimeAllowedDepth)
            {
                constrainedTo.mayEscapeInitialValue = true;

                onDemandEscapeError();
                errorSink.errorSupplemental(constrainedTo.var.loc,
                    "Pointer stored in variable `%s` has potentially escaped",
                    constrainedTo.var.ident.toChars);
            }
        }, null);

        if (lookAtConstraintOnly)
        {
            parentObject.walkIndirection(null, (DFAObject* constrained,
                    bool hadAnIndirection, bool haveConstraintOnLifeTime) {
                if (constrained.constrainedBy is intoVar)
                    return;

                version (none)
                {
                    printf("potential escape 2 obj %p, hadAnIndirection=%d, haveConstraintOnLifeTime=%d\n",
                        constrained, hadAnIndirection, haveConstraintOnLifeTime);
                }

                DFAVar* constrainedTo = constrained.constrainedBy;

                if (intoVar.param !is null && constrainedTo.param !is null)
                {
                    constrainedTo.mayEscapeInitialValue = true;
                    inferParameter(constrainedTo, hadAnIndirection,
                        haveConstraintOnLifeTime, false);
                    return;
                }

                if (hadAnIndirection)
                {
                }
                else if (!constrainedTo.unmodellable && constrained.onTheStack
                    && (intoVar.youngestLifeTimeAllowedDepth < constrainedTo.oldestLifeTimeAllowedDepth || intoVar is returnVar))
                {
                    constrainedTo.mayEscapeInitialValue = true;

                    onDemandEscapeError();
                    errorSink.errorSupplemental(constrainedTo.var.loc,
                        "Pointer stored in variable `%s` has potentially escaped",
                        constrainedTo.var.ident.toChars);
                }
            });
        }
    }

    void checkForUnknownEscape(const(char)* escapeMethod,
            DFAObject* parentObject, ref const Loc loc, bool errorOnStackEscape)
    {
        version (none)
        {
            printf("checkForUnknownEscape %s, parentObject=%p\n", escapeMethod, parentObject);
        }

        bool emittedEscapeError, lookAtConstraintOnly;

        void onDemandEscapeError()
        {
            if (emittedEscapeError)
                return;

            emittedEscapeError = true;

            errorSink.error(loc, "Escape of unknown lifetime via %s", escapeMethod);
        }

        void inferParameter(DFAVar* from, bool hadAnIndirection,
                bool haveConstraintOnLifeTime, bool inCell)
        {
            EscapedRelationship currentRel = from.param.inferred.willEscape(-1);

            EscapedRelationship toInferRel;

            // T var = rhs;
            // T* var = rhs;
            // This can be by-value based upon rhs;

            // ref T var = x;
            // This can be by-value only if it has had an indirection that isn't constrained.

            if (from.isByRef && inCell)
                toInferRel = EscapedRelationship.PointerTo;
            else if (from.isByRef && !inCell)
                toInferRel = EscapedRelationship.ByValue;
            else if (hadAnIndirection && !haveConstraintOnLifeTime)
                toInferRel = EscapedRelationship.ByValue;
            else
                toInferRel = EscapedRelationship.PointerTo;

            if (currentRel < toInferRel)
                from.param.inferred.willEscape(-1, toInferRel);

            if (hadAnIndirection)
                from.mayEscapeWithIndirection = true;
            else
                from.mayEscapeWithoutIndirection = true;
        }

        parentObject.walkIndirection((DFAObject* obj, bool hadAnIndirection,
                bool haveConstraintOnLifeTime, bool inCell) {

            version (none)
            {
                printf("potential escape 1 obj %p, hadAnIndirection=%d, haveConstraintOnLifeTime=%d\n",
                    obj, hadAnIndirection, haveConstraintOnLifeTime);
            }

            if (obj.lifeTimeUnderstood)
            {
                // S* ptr;
                // {
                //   S buf;
                //   ptr = &buf;
                //   buf.__dtor;
                // }
                // S temp = *ptr; // error: ptr contains an escaped object that has had cleanup run on it

                parentObject.delayOnReadErrorOfEscape = true;
                return;
            }

            // Cannot outlive this variable.
            DFAVar* constrainedTo = (obj.constrainedBy !is null && obj.constrainedBy.var !is null) ? obj.constrainedBy
                : null;
            // The cell of a variable.
            DFAVar* cellOf = (obj.storageFor !is null && obj.storageFor.var !is null) ? obj.storageFor
                : null;

            version (none)
            {
                printf("derivedFrom=%p, constrainedTo %p, cellOf %p\n",
                    obj.derivedFrom, constrainedTo, cellOf);
            }

            // Both constrainedTo and cellOf cannot be escape from.
            // The benefit of differentiating them allows us to tell the user that it was the cell that was escaped,
            //  versus an object that was stored in it, that was later escaped.

            // Have multiple layers of pointers, which we can't model.
            if (obj.derivedFrom !is null)
                cellOf = null;

            DFAVar* either = constrainedTo !is null ? constrainedTo : cellOf;

            if (either is null && haveConstraintOnLifeTime)
                lookAtConstraintOnly = true;

            if (!errorOnStackEscape && either !is null && either.param !is null)
            {
                either.mayEscapeInitialValue = true;
                inferParameter(either, hadAnIndirection, haveConstraintOnLifeTime, inCell);
                return;
            }

            if (hadAnIndirection || !errorOnStackEscape)
            {
            }
            else if (cellOf !is null
                && !cellOf.unmodellable && cellOf.oldestLifeTimeAllowedDepth >= 0)
            {
                cellOf.mayEscapeInitialValue = true;

                onDemandEscapeError();
                errorSink.errorSupplemental(cellOf.var.loc,
                    "A pointer to the cell of the variable `%s` has potentially escaped",
                    cellOf.var.ident.toChars);
            }
            else if (constrainedTo !is null && !constrainedTo.unmodellable
                && obj.onTheStack && constrainedTo.oldestLifeTimeAllowedDepth >= 0)
            {
                constrainedTo.mayEscapeInitialValue = true;

                onDemandEscapeError();
                errorSink.errorSupplemental(constrainedTo.var.loc,
                    "Pointer stored in variable `%s` has potentially escaped",
                    constrainedTo.var.ident.toChars);
            }
        }, null);

        if (lookAtConstraintOnly)
        {
            parentObject.walkIndirection(null, (DFAObject* constrained,
                    bool hadAnIndirection, bool haveConstraintOnLifeTime) {

                version (none)
                {
                    printf("potential escape 2 obj %p, hadAnIndirection=%d, haveConstraintOnLifeTime=%d\n",
                        constrained, hadAnIndirection, haveConstraintOnLifeTime);
                }

                DFAVar* constrainedTo = constrained.constrainedBy;

                if (!errorOnStackEscape && constrainedTo.param !is null)
                {
                    constrainedTo.mayEscapeInitialValue = true;
                    inferParameter(constrainedTo, hadAnIndirection,
                        haveConstraintOnLifeTime, false);
                    return;
                }

                if (hadAnIndirection || !errorOnStackEscape)
                {
                }
                else if (!constrainedTo.unmodellable
                    && constrained.onTheStack && constrainedTo.oldestLifeTimeAllowedDepth >= 0)
                {
                    constrainedTo.mayEscapeInitialValue = true;

                    onDemandEscapeError();
                    errorSink.errorSupplemental(constrainedTo.var.loc,
                        "Pointer stored in variable `%s` has potentially escaped",
                        constrainedTo.var.ident.toChars);
                }
            });
        }
    }
}

private:

void foreachFunctionVariable(DFACommon* dfaCommon, FuncDeclaration fd,
        scope void delegate(DFAScopeVar* scv) del)
{
    DFAVar* var;
    DFAScopeVar* scv;

    if (fd.vthis !is null)
    {
        var = dfaCommon.findVariable(fd.vthis);
        scv = dfaCommon.acquireScopeVar(var);
        del(scv);
    }

    var = dfaCommon.getReturnVariable();
    scv = dfaCommon.acquireScopeVar(var);
    del(scv);

    if (fd.parameters !is null)
    {
        foreach (i, param; *fd.parameters)
        {
            var = dfaCommon.findVariable(param);
            scv = dfaCommon.acquireScopeVar(var);
            del(scv);
        }
    }
}
