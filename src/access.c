
// Copyright (c) 1999-2011 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.


#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

#include "root.h"
#include "rmem.h"

#include "enum.h"
#include "aggregate.h"
#include "init.h"
#include "attrib.h"
#include "scope.h"
#include "id.h"
#include "mtype.h"
#include "declaration.h"
#include "aggregate.h"
#include "expression.h"
#include "module.h"

#define LOG 0

/* Code to do access checks
 */

int hasPackageAccess(Scope *sc, Dsymbol *s);

/****************************************
 * Return PROT access for Dsymbol smember in this declaration.
 */

enum PROT AggregateDeclaration::getAccess(Dsymbol *smember)
{
    return PROTpublic;
}

enum PROT StructDeclaration::getAccess(Dsymbol *smember)
{
    enum PROT access_ret = PROTnone;

#if LOG
    printf("+StructDeclaration::getAccess(this = '%s', smember = '%s')\n",
        toChars(), smember->toChars());
#endif
    if (smember->toParent() == this)
    {
        access_ret = smember->prot();
    }
    else if (smember->isDeclaration()->isStatic())
    {
        access_ret = smember->prot();
    }
    return access_ret;
}

enum PROT ClassDeclaration::getAccess(Dsymbol *smember)
{
    enum PROT access_ret = PROTnone;

#if LOG
    printf("+ClassDeclaration::getAccess(this = '%s', smember = '%s')\n",
        toChars(), smember->toChars());
#endif
    if (smember->toParent() == this)
    {
        access_ret = smember->prot();
    }
    else
    {
        if (smember->isDeclaration()->isStatic())
        {
            access_ret = smember->prot();
        }

        for (size_t i = 0; i < baseclasses->dim; i++)
        {   BaseClass *b = (*baseclasses)[i];

            enum PROT access = b->base->getAccess(smember);
            switch (access)
            {
                case PROTnone:
                    break;

                case PROTprivate:
                    access = PROTnone;  // private members of base class not accessible
                    break;

                case PROTpackage:
                case PROTprotected:
                case PROTpublic:
                case PROTexport:
                    // If access is to be tightened
                    if (b->protection < access)
                        access = b->protection;

                    // Pick path with loosest access
                    if (access > access_ret)
                        access_ret = access;
                    break;

                default:
                    assert(0);
            }
        }
    }
#if LOG
    printf("-ClassDeclaration::getAccess(this = '%s', smember = '%s') = %d\n",
        toChars(), smember->toChars(), access_ret);
#endif
    return access_ret;
}

/********************************************************
 * Helper function for ClassDeclaration::accessCheck()
 * Returns:
 *      0       no access
 *      1       access
 */

static int accessCheckX(
        Dsymbol *smember,
        Dsymbol *sfunc,
        AggregateDeclaration *dthis,
        AggregateDeclaration *cdscope)
{
    assert(dthis);

#if 0
    printf("accessCheckX for %s.%s in function %s() in scope %s\n",
        dthis->toChars(), smember->toChars(),
        sfunc ? sfunc->toChars() : "NULL",
        cdscope ? cdscope->toChars() : "NULL");
#endif
    if (dthis->hasPrivateAccess(sfunc) ||
        dthis->isFriendOf(cdscope))
    {
        if (smember->toParent() == dthis)
            return 1;
        else
        {
            ClassDeclaration *cdthis = dthis->isClassDeclaration();
            if (cdthis)
            {
                for (size_t i = 0; i < cdthis->baseclasses->dim; i++)
                {   BaseClass *b = (*cdthis->baseclasses)[i];
                    enum PROT access = b->base->getAccess(smember);
                    if (access >= PROTprotected ||
                        accessCheckX(smember, sfunc, b->base, cdscope)
                       )
                        return 1;

                }
            }
        }
    }
    else
    {
        if (smember->toParent() != dthis)
        {
            ClassDeclaration *cdthis = dthis->isClassDeclaration();
            if (cdthis)
            {
                for (size_t i = 0; i < cdthis->baseclasses->dim; i++)
                {   BaseClass *b = (*cdthis->baseclasses)[i];

                    if (accessCheckX(smember, sfunc, b->base, cdscope))
                        return 1;
                }
            }
        }
    }
    return 0;
}

/*******************************
 * Do access check for member of this class, this class being the
 * type of the 'this' pointer used to access smember.
 */

void AggregateDeclaration::accessCheck(Loc loc, Scope *sc, Dsymbol *smember)
{
    int result;

    FuncDeclaration *f = sc->func;
    AggregateDeclaration *cdscope = sc->getStructClassScope();
    enum PROT access;

#if LOG
    printf("AggregateDeclaration::accessCheck() for %s.%s in function %s() in scope %s\n",
        toChars(), smember->toChars(),
        f ? f->toChars() : NULL,
        cdscope ? cdscope->toChars() : NULL);
#endif

    Dsymbol *smemberparent = smember->toParent();
    if (!smemberparent || !smemberparent->isAggregateDeclaration())
    {
#if LOG
        printf("not an aggregate member\n");
#endif
        return;                         // then it is accessible
    }

    // BUG: should enable this check
    //assert(smember->parent->isBaseOf(this, NULL));

    if (smemberparent == this)
    {   enum PROT access2 = smember->prot();

        result = access2 >= PROTpublic ||
                hasPrivateAccess(f) ||
                isFriendOf(cdscope) ||
                (access2 == PROTpackage && hasPackageAccess(sc, this));
#if LOG
        printf("result1 = %d\n", result);
#endif
    }
    else if ((access = this->getAccess(smember)) >= PROTpublic)
    {
        result = 1;
#if LOG
        printf("result2 = %d\n", result);
#endif
    }
    else if (access == PROTpackage && hasPackageAccess(sc, this))
    {
        result = 1;
#if LOG
        printf("result3 = %d\n", result);
#endif
    }
    else
    {
        result = accessCheckX(smember, f, this, cdscope);
#if LOG
        printf("result4 = %d\n", result);
#endif
    }
    if (!result)
    {
        error(loc, "member %s is not accessible", smember->toChars());
    }
}

/****************************************
 * Determine if this is the same or friend of cd.
 */

int AggregateDeclaration::isFriendOf(AggregateDeclaration *cd)
{
#if LOG
    printf("AggregateDeclaration::isFriendOf(this = '%s', cd = '%s')\n", toChars(), cd ? cd->toChars() : "null");
#endif
    if (this == cd)
        return 1;

    // Friends if both are in the same module
    //if (toParent() == cd->toParent())
    if (cd && getModule() == cd->getModule())
    {
#if LOG
        printf("\tin same module\n");
#endif
        return 1;
    }

#if LOG
    printf("\tnot friend\n");
#endif
    return 0;
}

/****************************************
 * Determine if scope sc has package level access to s.
 */

int hasPackageAccess(Scope *sc, Dsymbol *s)
{
#if LOG
    printf("hasPackageAccess(s = '%s', sc = '%p')\n", s->toChars(), sc);
#endif

    for (; s; s = s->parent)
    {
        if (s->isPackage() && !s->isModule())
            break;
    }
#if LOG
    if (s)
        printf("\tthis is in package '%s'\n", s->toChars());
#endif

    if (s && s == sc->module->parent)
    {
#if LOG
        printf("\ts is in same package as sc\n");
#endif
        return 1;
    }


#if LOG
    printf("\tno package access\n");
#endif
    return 0;
}

/**********************************
 * Determine if smember has access to private members of this declaration.
 */

int AggregateDeclaration::hasPrivateAccess(Dsymbol *smember)
{
    if (smember)
    {   AggregateDeclaration *cd = NULL;
        Dsymbol *smemberparent = smember->toParent();
        if (smemberparent)
            cd = smemberparent->isAggregateDeclaration();

#if LOG
        printf("AggregateDeclaration::hasPrivateAccess(class %s, member %s)\n",
                toChars(), smember->toChars());
#endif

        if (this == cd)         // smember is a member of this class
        {
#if LOG
            printf("\tyes 1\n");
#endif
            return 1;           // so we get private access
        }

        // If both are members of the same module, grant access
        while (1)
        {   Dsymbol *sp = smember->toParent();
            if (sp->isFuncDeclaration() && smember->isFuncDeclaration())
                smember = sp;
            else
                break;
        }
        if (!cd && toParent() == smember->toParent())
        {
#if LOG
            printf("\tyes 2\n");
#endif
            return 1;
        }
        if (!cd && getModule() == smember->getModule())
        {
#if LOG
            printf("\tyes 3\n");
#endif
            return 1;
        }
    }
#if LOG
    printf("\tno\n");
#endif
    return 0;
}

/****************************************
 * Check access to d for expression e.d
 */

void accessCheck(Loc loc, Scope *sc, Expression *e, Declaration *d)
{
#if LOG
    if (e)
    {   printf("accessCheck(%s . %s)\n", e->toChars(), d->toChars());
        printf("\te->type = %s\n", e->type->toChars());
    }
    else
    {
        //printf("accessCheck(%s)\n", d->toChars());
    }
#endif
    if (!e)
    {
        if (d->prot() == PROTprivate && d->getModule() != sc->module ||
            d->prot() == PROTpackage && !hasPackageAccess(sc, d))

            error(loc, "%s %s.%s is not accessible from %s",
                d->kind(), d->getModule()->toChars(), d->toChars(), sc->module->toChars());
    }
    else if (e->type->ty == Tclass)
    {   // Do access check
        ClassDeclaration *cd;

        cd = (ClassDeclaration *)(((TypeClass *)e->type)->sym);
#if 1
        if (e->op == TOKsuper)
        {   ClassDeclaration *cd2;

            cd2 = sc->func->toParent()->isClassDeclaration();
            if (cd2)
                cd = cd2;
        }
#endif
        cd->accessCheck(loc, sc, d);
    }
    else if (e->type->ty == Tstruct)
    {   // Do access check
        StructDeclaration *cd;

        cd = (StructDeclaration *)(((TypeStruct *)e->type)->sym);
        cd->accessCheck(loc, sc, d);
    }
}
