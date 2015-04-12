/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/access.c
 */

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

#include "root.h"
#include "rmem.h"

#include "aggregate.h"
#include "expression.h"
#include "module.h"
#include "scope.h"

#define LOG 0

/****************************************
 * Check that s is a member of ad (or one of its base casses if exist).
 */
bool isMember(AggregateDeclaration *ad, Dsymbol *s)
{
    if (s->toParent2() == ad)
        return true;

    if (ClassDeclaration *cd = ad->isClassDeclaration())
    {
        for (size_t i = 0; i < cd->baseclasses->dim; i++)
        {
            BaseClass *b = (*cd->baseclasses)[i];
            if (isMember(b->base, s))
                return true;
        }
    }
    return false;
}

/****************************************
 * Determine if scope sc has protection access to s.
 */
bool hasProtectedAccess(Scope *sc, Dsymbol *s)
{
    for (Scope *scx = sc; scx; scx = scx->enclosing)
    {
        if (!scx->scopesym)
            continue;

        AggregateDeclaration *ad = scx->scopesym->isClassDeclaration();
        if (ad && isMember(ad, s))
            return true;
    }
    return false;
}

/****************************************
 * Determine if scope sc has package level access to s.
 */
bool hasPackageAccess(Scope *sc, Dsymbol *s)
{
#if LOG
    printf("hasPackageAccess(s = '%s', sc = '%p', s->protection.pkg = '%s')\n",
            s->toChars(), sc,
            s->prot().pkg ? s->prot().pkg->toChars() : "NULL");
#endif

    Package *pkg = NULL;

    if (s->prot().pkg)
        pkg = s->prot().pkg;
    else
    {
        // no explicit package for protection, inferring most qualified one
        for (; s; s = s->parent)
        {
            if (Module *m = s->isModule())
            {
                DsymbolTable *dst = Package::resolve(m->md ? m->md->packages : NULL, NULL, NULL);
                assert(dst);
                Dsymbol *s2 = dst->lookup(m->ident);
                assert(s2);
                Package *p = s2->isPackage();
                if (p && p->isPackageMod())
                {
                    pkg = p;
                    break;
                }
            }
            else if ((pkg = s->isPackage()) != NULL)
                break;
        }
    }
#if LOG
    if (pkg)
        printf("\tsymbol access binds to package '%s'\n", pkg->toChars());
#endif

    if (pkg)
    {
        if (pkg == sc->module->parent)
        {
#if LOG
            printf("\tsc is in permitted package for s\n");
#endif
            return true;
        }
        if (pkg->isPackageMod() == sc->module)
        {
#if LOG
            printf("\ts is in same package.d module as sc\n");
#endif
            return true;
        }
        Dsymbol* ancestor = sc->module->parent;
        for (; ancestor; ancestor = ancestor->parent)
        {
            if (ancestor == pkg)
            {
#if LOG
                printf("\tsc is in permitted ancestor package for s\n");
#endif
                return true;
            }
        }
    }

#if LOG
    printf("\tno package access\n");
#endif
    return false;
}

/****************************************
 * Check access to d for expression e.d
 * Returns true if the declaration is not accessible.
 */
bool checkAccess(Loc loc, Scope *sc, Expression *e, Declaration *d)
{
    if (sc->flags & SCOPEnoaccesscheck)
        return false;
    if (d->isUnitTestDeclaration()) // Unittests are always accessible.
        return false;

#if LOG
    printf("[%s] checkAccess(%s)\n", loc.toChars(), d->toPrettyChars());
#endif

    // friend access
    if (d->getAccessModule() == sc->module)
        return false;

    // check access rights
    if (d->prot().kind == PROTprivate ||
        d->prot().kind == PROTpackage && !hasPackageAccess(sc, d) ||
        d->prot().kind == PROTprotected && !hasProtectedAccess(sc, d))
    {
        AggregateDeclaration *ad = d->toParent2()->isAggregateDeclaration();
        if (ad)
            ad->error(loc, "member %s is not accessible from module %s",
                d->toChars(), sc->module->toChars());
        else
            error(loc, "%s %s is not accessible from module %s",
                d->kind(), d->toPrettyChars(), sc->module->toChars());
        return true;
    }
    return false;
}
