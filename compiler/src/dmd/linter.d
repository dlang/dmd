/**
 * Linter pass for the D compiler.
 * Performs additional static analysis to emit warnings for bad practices.
 */
module dmd.linter;

import dmd.func;
import dmd.id;
import dmd.declaration;
import dmd.aggregate;
import dmd.dscope;
import dmd.errors;
import dmd.astenums;

/*************************************
 * Entry point for function linting.
 * Called from semantic3 after the function body is fully analyzed.
 */
void lintFunction(FuncDeclaration funcdecl)
{
    if (!funcdecl || !funcdecl._scope)
        return;

    lintConstSpecial(funcdecl);
    lintUnusedParams(funcdecl);
}

/***************************************
 * Checks if a special method should be marked as `const` and emits a lint warning.
 */
void lintConstSpecial(FuncDeclaration fd, bool isKnownStructMember = false)
{
    if (!fd || !fd._scope || !(fd._scope.lintFlags & LintFlags.constSpecial))
        return;

    if (fd.isGenerated() || (fd.storage_class & STC.const_) || fd.type.isConst())
        return;

    if (!isKnownStructMember)
    {
        if (fd.ident != Id.opEquals && fd.ident != Id.opCmp &&
            fd.ident != Id.tohash && fd.ident != Id.tostring)
            return;

        if (!fd.toParent2() || !fd.toParent2().isStructDeclaration())
            return;
    }

    lint(fd.loc, "constSpecial".ptr, "special method `%s` should be marked as `const`".ptr, fd.ident ? fd.ident.toChars() : fd.toChars());
}

/***************************************
 * Checks for unused parameters in a function and emits a lint warning.
 */
private void lintUnusedParams(FuncDeclaration funcdecl)
{
    if (!funcdecl._scope || !(funcdecl._scope.lintFlags & LintFlags.unusedParams))
        return;

    if (!funcdecl.fbody || !funcdecl.parameters)
        return;

    auto ad = funcdecl.isMember2();
    bool isClassMethod = ad && ad.isClassDeclaration();
    bool isVirtual = isClassMethod && !funcdecl.isStatic() && !(funcdecl.storage_class & STC.final_);
    bool isOverride = (funcdecl.storage_class & STC.override_) || (funcdecl.foverrides.length > 0);

    if (isVirtual || isOverride)
        return;

    foreach (v; *funcdecl.parameters)
    {
        bool isIgnoredName = v.ident && v.ident.toChars()[0] == '_';

        if (v.ident && !v.wasUsed && !(v.storage_class & STC.temp) && !isIgnoredName)
        {
            lint(v.loc, "unusedParams".ptr, "function parameter `%s` is never used".ptr, v.ident.toChars());
        }
    }
}
