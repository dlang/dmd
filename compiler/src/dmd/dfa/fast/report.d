/**
 * Reporting mechanism for the fast Data Flow Analysis engine.
 *
 * This module translates the abstract state of the DFA into concrete compiler errors.
 * It is responsible for:
 * 1. Null Checks: Reporting errors when null pointers are dereferenced.
 * 2. Contract Validation: Ensuring functions fulfill their `out` contracts (e.g., returning non-null).
 * 3. Logic Errors: Detecting assertions that are provably false at compile time.
 *
 * Copyright: Copyright (C) 1999-2025 by The D Language Foundation, All Rights Reserved
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
import core.stdc.stdio;

alias Fact = ParameterDFAInfo.Fact;

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
            if (on.var.declaredAtDepth >= dfaCommon.lastLoopyLabel.depth)
                errorSink.error(loc, "Dereference on null variable `%s`",
                        on.var.var.ident.toChars);
            else
                fail = __LINE__;
        }
    }

    void onLoopyLabelLessNullThan(DFAVar* var, ref const(Loc) loc)
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
    void onEndOfScope(FuncDeclaration fd, ref Loc loc)
    {
        // this is where we validate escapes, for a specific location

        if (!dfaCommon.currentDFAScope.haveReturned)
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

            assert(!param.specifiedByUser);
            param.notNullOut = suggestedNotNullOut;
        });
    }

    void onEndOfFunction(FuncDeclaration fd, ref Loc loc)
    {
        version (none)
        {
            printf("End of function attributes for `%s` at %s\n", fd.ident.toChars, loc.toChars);
        }

        // validate/infer on to function
        foreachFunctionVariable(dfaCommon, fd, (scv) {
            ParameterDFAInfo* param = scv.var.param;
            if (param is null)
                return;

            version (none)
            {
                if (scv.var.var !is null)
                    printf("Variable %p `%s` ", scv.var, scv.var.var.ident.toChars);
                else
                    printf("Variable %p ", scv.var);

                printf("%d %d:%d %d:%d %d\n", scv.var.unmodellable, scv.var.isTruthy,
                    scv.var.isNullable, scv.var.isByRef, scv.var.writeCount,
                    param.specifiedByUser);
                printf("    notNullIn=%d, notNullOut=%d\n", param.notNullIn, param.notNullOut);
            }

            if (scv.var.unmodellable)
            {
                if (!param.specifiedByUser)
                {
                    param.specifiedByUser = false;

                    if (scv.var.isNullable)
                    {
                        param.notNullIn = Fact.Unspecified;
                        param.notNullOut = Fact.Unspecified;
                    }
                }
            }
            else if (!param.specifiedByUser)
            {
                if (scv.var.isNullable)
                {
                    if (param.notNullIn == Fact.Unspecified)
                        param.notNullIn = Fact.NotGuaranteed;

                    if (scv.var.isByRef)
                    {
                        if (scv.var.writeCount > 0)
                        {
                            if (param.notNullOut == Fact.Unspecified)
                                param.notNullOut = Fact.NotGuaranteed;
                        }
                        else
                            param.notNullOut = param.notNullIn;
                    }
                    else
                    {
                        param.notNullOut = Fact.Unspecified;
                    }
                }
            }

            version (none)
            {
                printf("    notNullIn=%d, notNullOut=%d\n",
                    cast(int) param.notNullIn, param.notNullOut);
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
