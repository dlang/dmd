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
                Id.udaMustUse.toChars(), e.type.toChars());
            return true;
        }
    }
    return false;
}

/**
 * Returns true if the given expression is an assignment, either simple (a = b)
 * or compound (a += b, etc).
 */
private bool isAssignment(Expression e)
{
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
 * Returns true if `s` starts with `prefix`, false otherwise.
 */
private bool startsWith(const(char)[] s, const(char)[] prefix)
{
    if (s.length < prefix.length)
        return false;
    return s[0 .. prefix.length] == prefix;
}

/**
 * Returns true if `s` ends with `suffix`, false otherwise.
 */
private bool endsWith(const(char)[] s, const(char)[] suffix)
{
    if (s.length < suffix.length)
        return false;
    return s[$ - suffix.length .. $] == suffix;
}

/**
 * Returns true if the given expression is an increment (++) or decrement (--).
 */
private bool isIncrementOrDecrement(Expression e)
{
    import dmd.tokens : EXP;

    return e.op == EXP.plusPlus
        || e.op == EXP.minusMinus
        || e.op == EXP.prePlusPlus
        || e.op == EXP.preMinusMinus;
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

