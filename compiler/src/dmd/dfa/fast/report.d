module dmd.dfa.fast.report;
import dmd.dfa.common;
import dmd.location;
import dmd.func;
import core.stdc.stdio;

alias Fact = ParameterDFAInfo.Fact;

void reportDereference(DFACommon* dfaCommon, DFAConsequence* on, ref Loc loc)
{
    if (!dfaCommon.debugUnknownAST && on is null)
        return;
    assert(on !is null);
    if (on.var is null)
        return;

    bool inferNonNull()
    {
        if (on.writeOnVarAtThisPoint != 0 || on.var.hasBeenAsserted)
            return false;
        else if (on.var.param is null || on.var.param.specifiedByUser)
            return false;

        if (dfaCommon.debugIt)
            printf("Infer variable as non-null `%s` at %s\n", on.var.var.ident.toChars, loc.toChars);

        on.nullable = Nullable.NonNull;
        on.var.param.notNullIn = ParameterDFAInfo.Fact.Guaranteed;
        return true;
    }

    assert(on.nullable != Nullable.NonNull);

    if (on.nullable == Nullable.Unknown)
    {
        inferNonNull;
        return;
    }
    else if (on.var is null || on.var.var is null || !on.var.isModellable)
        return;

    if (!inferNonNull)
    {
        if (DFAScope* loopyLabel = dfaCommon.lastLoopyLabel)
        {
            if (on.var.declaredAtDepth < loopyLabel.depth)
                return;
        }

        printf("Dereference on null `%s` at %s\n", on.var.var.ident.toChars, loc.toChars);
    }
}

void reportLoopyLabelLessNullThan(DFACommon* dfaCommon, DFAVar* var, ref const(Loc) loc)
{
    if (var !is null && !var.isModellable)
        return;

    printf("See less than state at %s\n", loc.toChars);
    printf("    Due to variable `%s` was non-null and becomes null\n", var.var.ident.toChars);
}

void reportLoopyLabelAssertAndAssign(DFACommon* dfaCommon,
        DFAScopeVar* varThatWasAssumed, DFAScopeVar* varThatAsserted, ref const(Loc) loc)
{
    printf("Variable `%s` was assumed due to assert of variable `%s` which gets invalidated at %s\n",
            varThatWasAssumed.var.var.toChars, varThatAsserted.var.var.toChars, loc.toChars);
}

void reportEndOfScope(DFACommon* dfaCommon, FuncDeclaration fd, ref Loc loc)
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

        if (param.specifiedByUser)
        {
            // TODO: verify attributes
        }
        else
            param.notNullOut = suggestedNotNullOut;
    });
}

void reportEndOfFunction(DFACommon* dfaCommon, FuncDeclaration fd, ref Loc loc)
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
                scv.var.isNullable, scv.var.isByRef, scv.var.writeCount, param.specifiedByUser);
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
            else
            {
                param.notNullIn = Fact.Unspecified;
                param.notNullOut = Fact.Unspecified;
            }
        }

        version (none)
        {
            printf("    notNullIn=%d, notNullOut=%d\n", cast(int) param.notNullIn, param.notNullOut);
        }
    });
}

void reportAssertIsFalse(DFACommon* dfaCommon, ref DFALatticeRef lr, ref const Loc loc)
{
    DFAConsequence* cctx;
    if (!(lr.isModellable && (lr.haveNonContext || (cctx = lr.getContext).var !is null)))
        return; // ignore literals, too false positive heavy

    if (DFAScope* loopyLabel = dfaCommon.lastLoopyLabel)
    {
        bool couldBeChanged;

        lr.walkMaybeTops((c) {
            if (c.var !is null && c.var.declaredAtDepth < loopyLabel.depth)
            {
                couldBeChanged = true;
                return false;
            }

            return true;
        });

        if (couldBeChanged)
            return;
    }

    printf("Assert is provably false at %s\n", loc.toChars);
}

void reportFunctionCallArgumentLessThan(DFACommon* dfaCommon, DFAConsequence* c,
        ParameterDFAInfo* paramInfo, FuncDeclaration calling, ref Loc loc)
{
    if (!c.var.isModellable)
        return;

    printf("See less than state at %s\n", loc.toChars);
    printf("    Due to argument expected to be non-null and was null\n");
    printf("    Calling function `%s` at %s\n", calling.ident.toChars, calling.loc.toChars);
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
