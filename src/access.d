/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2016 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _access.d)
 */

module ddmd.access;

import ddmd.aggregate;
import ddmd.dclass;
import ddmd.declaration;
import ddmd.dmodule;
import ddmd.dscope;
import ddmd.dstruct;
import ddmd.dsymbol;
import ddmd.errors;
import ddmd.expression;
import ddmd.func;
import ddmd.globals;
import ddmd.mtype;
import ddmd.tokens;

private enum LOG = false;

/****************************************
 * Return Prot access for Dsymbol smember in this declaration.
 */
extern (C++) Prot getAccess(AggregateDeclaration ad, Dsymbol smember)
{
    Prot access_ret = Prot(PROTnone);
    static if (LOG)
    {
        printf("+AggregateDeclaration::getAccess(this = '%s', smember = '%s')\n", ad.toChars(), smember.toChars());
    }
    assert(ad.isStructDeclaration() || ad.isClassDeclaration());
    if (smember.toParent() == ad)
    {
        access_ret = smember.prot();
    }
    else if (smember.isDeclaration().isStatic())
    {
        access_ret = smember.prot();
    }
    if (ClassDeclaration cd = ad.isClassDeclaration())
    {
        for (size_t i = 0; i < cd.baseclasses.dim; i++)
        {
            BaseClass* b = (*cd.baseclasses)[i];
            Prot access = getAccess(b.sym, smember);
            switch (access.kind)
            {
            case PROTnone:
                break;
            case PROTprivate:
                access_ret = Prot(PROTnone); // private members of base class not accessible
                break;
            case PROTpackage:
            case PROTprotected:
            case PROTpublic:
            case PROTexport:
                // If access is to be tightened
                if (PROTpublic < access.kind)
                    access = Prot(PROTpublic);
                // Pick path with loosest access
                if (access_ret.isMoreRestrictiveThan(access))
                    access_ret = access;
                break;
            default:
                assert(0);
            }
        }
    }
    static if (LOG)
    {
        printf("-AggregateDeclaration::getAccess(this = '%s', smember = '%s') = %d\n", ad.toChars(), smember.toChars(), access_ret);
    }
    return access_ret;
}

/********************************************************
 * Helper function for checkAccess()
 * Returns:
 *      false   is not accessible
 *      true    is accessible
 */
extern (C++) static bool isAccessible(Dsymbol smember, Dsymbol sfunc, AggregateDeclaration dthis, AggregateDeclaration cdscope)
{
    assert(dthis);
    version (none)
    {
        printf("isAccessible for %s.%s in function %s() in scope %s\n", dthis.toChars(), smember.toChars(), sfunc ? sfunc.toChars() : "NULL", cdscope ? cdscope.toChars() : "NULL");
    }
    if (hasPrivateAccess(dthis, sfunc) || isFriendOf(dthis, cdscope))
    {
        if (smember.toParent() == dthis)
            return true;
        if (ClassDeclaration cdthis = dthis.isClassDeclaration())
        {
            for (size_t i = 0; i < cdthis.baseclasses.dim; i++)
            {
                BaseClass* b = (*cdthis.baseclasses)[i];
                Prot access = getAccess(b.sym, smember);
                if (access.kind >= PROTprotected || isAccessible(smember, sfunc, b.sym, cdscope))
                {
                    return true;
                }
            }
        }
    }
    else
    {
        if (smember.toParent() != dthis)
        {
            if (ClassDeclaration cdthis = dthis.isClassDeclaration())
            {
                for (size_t i = 0; i < cdthis.baseclasses.dim; i++)
                {
                    BaseClass* b = (*cdthis.baseclasses)[i];
                    if (isAccessible(smember, sfunc, b.sym, cdscope))
                        return true;
                }
            }
        }
    }
    return false;
}

/*******************************
 * Do access check for member of this class, this class being the
 * type of the 'this' pointer used to access smember.
 * Returns true if the member is not accessible.
 */
extern (C++) bool checkAccess(AggregateDeclaration ad, Loc loc, Scope* sc, Dsymbol smember)
{
    FuncDeclaration f = sc.func;
    AggregateDeclaration cdscope = sc.getStructClassScope();
    static if (LOG)
    {
        printf("AggregateDeclaration::checkAccess() for %s.%s in function %s() in scope %s\n", ad.toChars(), smember.toChars(), f ? f.toChars() : null, cdscope ? cdscope.toChars() : null);
    }
    Dsymbol smemberparent = smember.toParent();
    if (!smemberparent || !smemberparent.isAggregateDeclaration())
    {
        static if (LOG)
        {
            printf("not an aggregate member\n");
        }
        return false; // then it is accessible
    }
    // BUG: should enable this check
    //assert(smember->parent->isBaseOf(this, NULL));
    bool result;
    Prot access;
    if (smemberparent == ad)
    {
        access = smember.prot();
        result = access.kind >= PROTpublic || hasPrivateAccess(ad, f) || isFriendOf(ad, cdscope) || (access.kind == PROTpackage && hasPackageAccess(sc, smember)) || ad.getAccessModule() == sc._module;
        static if (LOG)
        {
            printf("result1 = %d\n", result);
        }
    }
    else if ((access = getAccess(ad, smember)).kind >= PROTpublic)
    {
        result = true;
        static if (LOG)
        {
            printf("result2 = %d\n", result);
        }
    }
    else if (access.kind == PROTpackage && hasPackageAccess(sc, ad))
    {
        result = true;
        static if (LOG)
        {
            printf("result3 = %d\n", result);
        }
    }
    else
    {
        result = isAccessible(smember, f, ad, cdscope);
        static if (LOG)
        {
            printf("result4 = %d\n", result);
        }
    }
    if (!result)
    {
        ad.error(loc, "member %s is not accessible", smember.toChars());
        //printf("smember = %s %s, prot = %d, semanticRun = %d\n",
        //        smember->kind(), smember->toPrettyChars(), smember->prot(), smember->semanticRun);
        return true;
    }
    return false;
}

/****************************************
 * Determine if this is the same or friend of cd.
 */
extern (C++) bool isFriendOf(AggregateDeclaration ad, AggregateDeclaration cd)
{
    static if (LOG)
    {
        printf("AggregateDeclaration::isFriendOf(this = '%s', cd = '%s')\n", ad.toChars(), cd ? cd.toChars() : "null");
    }
    if (ad == cd)
        return true;
    // Friends if both are in the same module
    //if (toParent() == cd->toParent())
    if (cd && ad.getAccessModule() == cd.getAccessModule())
    {
        static if (LOG)
        {
            printf("\tin same module\n");
        }
        return true;
    }
    static if (LOG)
    {
        printf("\tnot friend\n");
    }
    return false;
}

/****************************************
 * Determine if scope sc has package level access to s.
 */
extern (C++) bool hasPackageAccess(Scope* sc, Dsymbol s)
{
    return hasPackageAccess(sc._module, s);
}

extern (C++) bool hasPackageAccess(Module mod, Dsymbol s)
{
    static if (LOG)
    {
        printf("hasPackageAccess(s = '%s', mod = '%s', s->protection.pkg = '%s')\n", s.toChars(), mod.toChars(), s.prot().pkg ? s.prot().pkg.toChars() : "NULL");
    }
    Package pkg = null;
    if (s.prot().pkg)
        pkg = s.prot().pkg;
    else
    {
        // no explicit package for protection, inferring most qualified one
        for (; s; s = s.parent)
        {
            if (Module m = s.isModule())
            {
                DsymbolTable dst = Package.resolve(m.md ? m.md.packages : null, null, null);
                assert(dst);
                Dsymbol s2 = dst.lookup(m.ident);
                assert(s2);
                Package p = s2.isPackage();
                if (p && p.isPackageMod())
                {
                    pkg = p;
                    break;
                }
            }
            else if ((pkg = s.isPackage()) !is null)
                break;
        }
    }
    static if (LOG)
    {
        if (pkg)
            printf("\tsymbol access binds to package '%s'\n", pkg.toChars());
    }
    if (pkg)
    {
        if (pkg == mod.parent)
        {
            static if (LOG)
            {
                printf("\tsc is in permitted package for s\n");
            }
            return true;
        }
        if (pkg.isPackageMod() == mod)
        {
            static if (LOG)
            {
                printf("\ts is in same package.d module as sc\n");
            }
            return true;
        }
        Dsymbol ancestor = mod.parent;
        for (; ancestor; ancestor = ancestor.parent)
        {
            if (ancestor == pkg)
            {
                static if (LOG)
                {
                    printf("\tsc is in permitted ancestor package for s\n");
                }
                return true;
            }
        }
    }
    static if (LOG)
    {
        printf("\tno package access\n");
    }
    return false;
}

/****************************************
 * Determine if scope sc has protected level access to cd.
 */
bool hasProtectedAccess(Scope *sc, Dsymbol s)
{
    if (auto cd = s.isClassMember()) // also includes interfaces
    {
        for (auto scx = sc; scx; scx = scx.enclosing)
        {
            if (!scx.scopesym)
                continue;
            auto cd2 = scx.scopesym.isClassDeclaration();
            if (cd2 && cd.isBaseOf(cd2, null))
                return true;
        }
    }
    return sc._module == s.getAccessModule();
}

/**********************************
 * Determine if smember has access to private members of this declaration.
 */
extern (C++) bool hasPrivateAccess(AggregateDeclaration ad, Dsymbol smember)
{
    if (smember)
    {
        AggregateDeclaration cd = null;
        Dsymbol smemberparent = smember.toParent();
        if (smemberparent)
            cd = smemberparent.isAggregateDeclaration();
        static if (LOG)
        {
            printf("AggregateDeclaration::hasPrivateAccess(class %s, member %s)\n", ad.toChars(), smember.toChars());
        }
        if (ad == cd) // smember is a member of this class
        {
            static if (LOG)
            {
                printf("\tyes 1\n");
            }
            return true; // so we get private access
        }
        // If both are members of the same module, grant access
        while (1)
        {
            Dsymbol sp = smember.toParent();
            if (sp.isFuncDeclaration() && smember.isFuncDeclaration())
                smember = sp;
            else
                break;
        }
        if (!cd && ad.toParent() == smember.toParent())
        {
            static if (LOG)
            {
                printf("\tyes 2\n");
            }
            return true;
        }
        if (!cd && ad.getAccessModule() == smember.getAccessModule())
        {
            static if (LOG)
            {
                printf("\tyes 3\n");
            }
            return true;
        }
    }
    static if (LOG)
    {
        printf("\tno\n");
    }
    return false;
}

/****************************************
 * Check access to d for expression e.d
 * Returns true if the declaration is not accessible.
 */
extern (C++) bool checkAccess(Loc loc, Scope* sc, Expression e, Declaration d)
{
    if (sc.flags & SCOPEnoaccesscheck)
        return false;
    static if (LOG)
    {
        if (e)
        {
            printf("checkAccess(%s . %s)\n", e.toChars(), d.toChars());
            printf("\te->type = %s\n", e.type.toChars());
        }
        else
        {
            printf("checkAccess(%s)\n", d.toPrettyChars());
        }
    }
    if (d.isUnitTestDeclaration())
    {
        // Unittests are always accessible.
        return false;
    }
    if (!e)
    {
        if (d.prot().kind == PROTprivate && d.getAccessModule() != sc._module || d.prot().kind == PROTpackage && !hasPackageAccess(sc, d))
        {
            error(loc, "%s %s is not accessible from module %s", d.kind(), d.toPrettyChars(), sc._module.toChars());
            return true;
        }
    }
    else if (e.type.ty == Tclass)
    {
        // Do access check
        ClassDeclaration cd = (cast(TypeClass)e.type).sym;
        if (e.op == TOKsuper)
        {
            ClassDeclaration cd2 = sc.func.toParent().isClassDeclaration();
            if (cd2)
                cd = cd2;
        }
        return checkAccess(cd, loc, sc, d);
    }
    else if (e.type.ty == Tstruct)
    {
        // Do access check
        StructDeclaration cd = (cast(TypeStruct)e.type).sym;
        return checkAccess(cd, loc, sc, d);
    }
    return false;
}

/****************************************
 * Check access to package/module `p` from scope `sc`.
 *
 * Params:
 *   loc = source location for issued error message
 *   sc = scope from which to access to a fully qualified package name
 *   p = the package/module to check access for
 * Returns: true if the package is not accessible.
 *
 * Because a global symbol table tree is used for imported packages/modules,
 * access to them needs to be checked based on the imports in the scope chain
 * (see Bugzilla 313).
 *
 */
extern (C++) bool checkAccess(Loc loc, Scope* sc, Package p)
{
    if (sc._module == p)
        return false;
    for (; sc; sc = sc.enclosing)
    {
        if (sc.scopesym && sc.scopesym.isPackageAccessible(p, Prot(PROTprivate)))
            return false;
    }
    auto name = p.toPrettyChars();
    if (p.isPkgMod == PKGmodule || p.isModule())
        deprecation(loc, "%s %s is not accessible here, perhaps add 'static import %s;'", p.kind(), name, name);
    else
        deprecation(loc, "%s %s is not accessible here", p.kind(), name);
    return true;
}

/**
 * Check whether symbols `s` is visible in `mod`.
 *
 * Params:
 *  mod = lookup origin
 *  s = symbol to check for visibility
 * Returns: true if s is visible in mod
 */
extern (C++) bool symbolIsVisible(Module mod, Dsymbol s)
{
    // should sort overloads by ascending protection instead of iterating here
    s = mostVisibleOverload(s);
    final switch (s.prot().kind)
    {
    case PROTundefined: return true;
    case PROTnone: return false; // no access
    case PROTprivate: return s.getAccessModule() == mod;
    case PROTpackage: return s.getAccessModule() == mod || hasPackageAccess(mod, s);
    case PROTprotected: return s.getAccessModule() == mod;
    case PROTpublic, PROTexport: return true;
    }
}

/**
 * Same as above, but determines the lookup module from symbols `origin`.
 */
extern (C++) bool symbolIsVisible(Dsymbol origin, Dsymbol s)
{
    return symbolIsVisible(origin.getAccessModule(), s);
}

/**
 * Same as above but also checks for protected symbols visible from scope `sc`.
 * Used for qualified name lookup.
 *
 * Params:
 *  sc = lookup scope
 *  s = symbol to check for visibility
 * Returns: true if s is visible by origin
 */
extern (C++) bool symbolIsVisible(Scope *sc, Dsymbol s)
{
    s = mostVisibleOverload(s);
    final switch (s.prot().kind)
    {
    case PROTundefined: return true;
    case PROTnone: return false; // no access
    case PROTprivate: return sc._module == s.getAccessModule();
    case PROTpackage: return sc._module == s.getAccessModule() || hasPackageAccess(sc._module, s);
    case PROTprotected: return hasProtectedAccess(sc, s);
    case PROTpublic, PROTexport: return true;
    }
}

/**
 * Use the most visible overload to check visibility. Later perform an access
 * check on the resolved overload.  This function is similar to overloadApply,
 * but doesn't recurse nor resolve aliases because protection/visibility is an
 * attribute of the alias not the aliasee.
 */
private Dsymbol mostVisibleOverload(Dsymbol s)
{
    if (!s.isOverloadable())
        return s;

    Dsymbol next, fstart = s, mostVisible = s;
    for (; s; s = next)
    {
        // void func() {}
        // private void func(int) {}
        if (auto fd = s.isFuncDeclaration())
            next = fd.overnext;
        // template temp(T) {}
        // private template temp(T:int) {}
        else if (auto td = s.isTemplateDeclaration())
            next = td.overnext;
        // alias common = mod1.func1;
        // alias common = mod2.func2;
        else if (auto fa = s.isFuncAliasDeclaration())
            next = fa.overnext;
        // alias common = mod1.templ1;
        // alias common = mod2.templ2;
        else if (auto od = s.isOverDeclaration())
            next = od.overnext;
        // alias name = sym;
        // private void name(int) {}
        else if (auto ad = s.isAliasDeclaration())
        {
            assert(ad.isOverloadable, "Non overloadable Aliasee in overload list");
            // Yet unresolved aliases store overloads in overnext.
            if (ad.semanticRun < PASSsemanticdone)
                next = ad.overnext;
            else
            {
                /* This is a bit messy due to the complicated implementation of
                 * alias.  Aliases aren't overloadable themselves, but if their
                 * Aliasee is overloadable they can be converted to an overloadable
                 * alias.
                 *
                 * This is done by replacing the Aliasee w/ FuncAliasDeclaration
                 * (for functions) or OverDeclaration (for templates) which are
                 * simply overloadable aliases w/ weird names.
                 *
                 * Usually aliases should not be resolved for visibility checking
                 * b/c public aliases to private symbols are public. But for the
                 * overloadable alias situation, the Alias (_ad_) has been moved
                 * into it's own Aliasee, leaving a shell that we peel away here.
                 */
                auto aliasee = ad.toAlias();
                if (aliasee.isFuncAliasDeclaration || aliasee.isOverDeclaration)
                    next = aliasee;
                else
                {
                    /* A simple alias can be at the end of a function or template overload chain.
                     * It can't have further overloads b/c it would have been
                     * converted to an overloadable alias.
                     */
                    assert(ad.overnext is null, "Unresolved overload of alias");
                    break;
                }
            }
            // handled by ddmd.func.overloadApply for unknown reason
            assert(next !is ad); // should not alias itself
            assert(next !is fstart); // should not alias the overload list itself
        }
        else
            break;

        if (next && mostVisible.prot().isMoreRestrictiveThan(next.prot()))
            mostVisible = next;
    }
    return mostVisible;
}
