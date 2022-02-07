/**
 * Compile-time checks associated with the @mustUse attribute.
 *
 * Copyright: Copyright (C) 2022 by The D Language Foundation, All Rights Reserved
 * License:   $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/must_use.d, _must_use.d)
 * Documentation:  https://dlang.org/phobos/dmd_must_use.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/must_use.d
 */

module dmd.must_use;

import dmd.dscope;
import dmd.dsymbol;
import dmd.expression;

/**
 * Check whether discarding an expression would violate the requirements of
 * @mustUse. If so, emit an error.
 *
 * Params:
 *   e = the expression to check
 *   sc = scope in which `e` was semantically analyzed
 *
 * Returns: true on error, false on success.
 */
bool checkMustUse(Expression e, Scope* sc)
{
    import dmd.id : Id;

    if (!isAssignment(e) && !isIncrementOrDecrement(e))
    {
        assert(e.type);
        auto sym = e.type.toDsymbol(sc);
        auto sd = sym ? sym.isStructDeclaration() : null;
        // isStructDeclaration returns non-null for both structs and unions
        if (sd && hasMustUseAttribute(sd, sc))
        {
            e.error("ignored value of `@%s` type `%s`; prepend a `cast(void)` if intentional",
                Id.udaMustUse.toChars(), e.type.toPrettyChars(true));
            return true;
        }
    }
    return false;
}

/**
 * Called from a symbol's semantic to check for reserved usage of @mustUse.
 *
 * If such usage is found, emits an errror.
 *
 * Params:
 *   sym = symbol to check
 */
void checkMustUseReserved(Dsymbol sym)
{
    import dmd.errors : error;
    import dmd.id : Id;

    if (sym.userAttribDecl is null || sym.userAttribDecl.atts is null)
        return;

    // Can't use foreachUda (and by extension hasMustUseAttribute) while
    // semantic analysis of `sym` is still in progress
    // TODO: factor out common code from this function and checkGNUABITag
    foreach (exp; *sym.userAttribDecl.atts)
    {
        if (isMustUseAttribute(exp))
        {
            if (sym.isFuncDeclaration())
            {
                error(sym.loc, "`@%s` on functions is reserved for future use",
                    Id.udaMustUse.toChars());
                sym.errors = true;
            }
            else if (sym.isClassDeclaration() || sym.isEnumDeclaration())
            {
                error(sym.loc, "`@%s` on `%s` types is reserved for future use",
                    Id.udaMustUse.toChars(), sym.kind());
                sym.errors = true;
            }
        }
    }
}

/**
 * Returns true if the given expression is an assignment, either simple (a = b)
 * or compound (a += b, etc).
 */
private bool isAssignment(Expression e)
{
    import dmd.common.string : startsWith, endsWith;

    if (e.isAssignExp || e.isBinAssignExp)
        return true;
    if (auto ce = e.isCallExp())
    {
        auto fd = ce.f;
        auto id = fd ? fd.ident : null;
        // opXXX are reserved identifiers, so it's ok to match too much here
        if (id && id.toString().startsWith("op") && id.toString().endsWith("Assign"))
            return true;
    }
    return false;
}

/**
 * Returns true if the given expression is an increment (++) or decrement (--).
 */
private bool isIncrementOrDecrement(Expression e)
{
    import dmd.dtemplate : isExpression;
    import dmd.globals : Loc;
    import dmd.id : Id;
    import dmd.tokens : EXP;

    if (e.op == EXP.plusPlus
        || e.op == EXP.minusMinus
        || e.op == EXP.prePlusPlus
        || e.op == EXP.preMinusMinus)
        return true;
    if (auto call = e.isCallExp())
    {
        // Check for overloaded preincrement
        // e.g., a.opUnary!"++"
        auto fd = call.f;
        auto id = fd ? fd.ident : null;
        if (id == Id.opUnary)
        {
            auto ti = fd.parent ? fd.parent.isTemplateInstance() : null;
            auto tiargs = ti ? ti.tiargs : null;
            if (tiargs && tiargs.length >= 1)
            {
                auto argExp = (*tiargs)[0].isExpression();
                auto op = argExp ? argExp.isStringExp() : null;
                scope plusPlus = new StringExp(Loc.initial, "++");
                scope minusMinus = new StringExp(Loc.initial, "--");
                if (op && (op.compare(plusPlus) == 0 || op.compare(minusMinus) == 0))
                    return true;
            }
        }
    }
    else if (auto comma = e.isCommaExp())
    {
        // Check for overloaded postincrement
        // e.g., (auto tmp = a, ++a, tmp)
        auto left = comma.e1 ? comma.e1.isCommaExp() : null;
        auto middle = left ? left.e2 : null;
        if (middle && isIncrementOrDecrement(middle))
            return true;
    }
    return false;
}

/**
 * Returns true if the given symbol has the @mustUseAttribute.
 */
private bool hasMustUseAttribute(Dsymbol sym, Scope* sc)
{
    import dmd.attrib : foreachUda;

    bool result = false;

    foreachUda(sym, sc, (Expression uda) {
        if (isMustUseAttribute(uda))
        {
            result = true;
            return 1; // break
        }
        return 0; // continue
    });

    return result;
}

/**
 * Returns true if the given expression is core.attribute.mustUse.
 */
private bool isMustUseAttribute(Expression e)
{
    import dmd.attrib : isCoreUda;
    import dmd.id : Id;

    // Logic based on dmd.objc.Supported.declaredAsOptionalCount
    auto typeExp = e.isTypeExp;
    if (!typeExp)
        return false;

    auto typeEnum = typeExp.type.isTypeEnum();
    if (!typeEnum)
        return false;

    if (isCoreUda(typeEnum.sym, Id.udaMustUse))
        return true;

    return false;
}

