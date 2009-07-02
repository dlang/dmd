
// Copyright (c) 1999-2004 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.


#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

#include "root.h"
#include "mem.h"

#include "enum.h"
#include "aggregate.h"
#include "init.h"
#include "attrib.h"
#include "scope.h"
#include "id.h"
#include "declaration.h"
#include "aggregate.h"
#include "expression.h"
#include "mtype.h"

#define LOG 0

/* Code to do access checks
 */

/****************************************
 * Return PROT access for Dsymbol smember in this class.
 */

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
	enum PROT access;
	int i;

	for (i = 0; i < baseclasses.dim; i++)
	{   BaseClass *b = (BaseClass *)baseclasses.data[i];

	    access = b->base->getAccess(smember);
	    switch (access)
	    {
		case PROTnone:
		    break;

		case PROTprivate:
		    access = PROTnone;	// private members of base class not accessible
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
 *	0	no access
 * 	1	access
 */

static int accessCheckX(
	Dsymbol *smember,
	Dsymbol *sfunc,
	ClassDeclaration *cdthis,
	ClassDeclaration *cdscope)
{
    assert(cdthis);

#if 0
    printf("accessCheckX for %s.%s in function %s() in scope %s\n",
	cdthis->toChars(), smember->toChars(),
	sfunc ? sfunc->toChars() : "NULL",
	cdscope ? cdscope->toChars() : "NULL");
#endif
    if (cdthis->hasPrivateAccess(sfunc) ||
	cdthis->isFriendOf(cdscope))
    {
	if (smember->toParent() == cdthis)
	    return 1;
	else
	{
	    int i;

	    for (i = 0; i < cdthis->baseclasses.dim; i++)
	    {	BaseClass *b = (BaseClass *)cdthis->baseclasses.data[i];
		enum PROT access;

		access = b->base->getAccess(smember);
		if (access >= PROTprotected ||
		    accessCheckX(smember, sfunc, b->base, cdscope)
		   )
		    return 1;

	    }
	}
    }
    else
    {
	if (smember->toParent() != cdthis)
	{
	    int i;

	    for (i = 0; i < cdthis->baseclasses.dim; i++)
	    {	BaseClass *b = (BaseClass *)cdthis->baseclasses.data[i];

		if (accessCheckX(smember, sfunc, b->base, cdscope))
		    return 1;
	    }
	}
    }
    return 0;
}

/*******************************
 * Do access check for member of this class, this class being the
 * type of the 'this' pointer used to access smember.
 */

void ClassDeclaration::accessCheck(Loc loc, Scope *sc, Dsymbol *smember)
{
    int result;

    FuncDeclaration *f = sc->func;
    ClassDeclaration *cdscope = sc->getClassScope();
    enum PROT access;

#if LOG
    printf("ClassDeclaration::accessCheck() for %s.%s in function %s() in scope %s\n",
	toChars(), smember->toChars(),
	f ? f->toChars() : NULL,
	cdscope ? cdscope->toChars() : NULL);
#endif

    if (!smember->isClassMember())	// if not a member of a class
    {
#if LOG
	printf("not a class member\n");
#endif
	return;				// then it is accessible
    }

    // BUG: should enable this check
    //assert(smember->parent->isBaseOf(this, NULL));

    if (smember->toParent() == this)
    {	enum PROT access = smember->prot();

	result = access >= PROTpublic ||
		hasPrivateAccess(f) ||
		isFriendOf(cdscope) ||
		(access == PROTpackage && hasPackageAccess(sc));
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
    else if (access == PROTpackage && hasPackageAccess(sc))
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

int ClassDeclaration::isFriendOf(ClassDeclaration *cd)
{
#if LOG
    printf("ClassDeclaration::isFriendOf(this = '%s', cd = '%s')\n", toChars(), cd ? cd->toChars() : "null");
#endif
    if (this == cd)
	return 1;

    // Friends if both are in the same module
    if (cd && toParent() == cd->toParent())
    {
#if LOG
	printf("\tin same module\n");
#endif
	return 1;
    }

    if (cd && cd->toParent() == this)
    {
#if LOG
	printf("\tcd is nested in this\n");
#endif
	return 1;
    }


#if LOG
    printf("\tnot friend\n");
#endif
    return 0;
}

/****************************************
 * Determine if scope sc has package level access to 'this'.
 */

int ClassDeclaration::hasPackageAccess(Scope *sc)
{
#if LOG
    printf("ClassDeclaration::hasPackageAccess(this = '%s', sc = '%p')\n", toChars(), sc);
#endif
    Dsymbol *mthis;

    for (mthis = this; mthis; mthis = mthis->parent)
    {
	if (mthis->isPackage() && !mthis->isModule())
	    break;
    }
#if LOG
    if (mthis)
	printf("\tthis is in package '%s'\n", mthis->toChars());
#endif

    if (mthis && mthis == sc->module->parent)
    {
#if LOG
	printf("\t'this' is in same package as cd\n");
#endif
	return 1;
    }


#if LOG
    printf("\tno package access\n");
#endif
    return 0;
}

/**********************************
 * Determine if smember has access to private members of this class.
 */

int ClassDeclaration::hasPrivateAccess(Dsymbol *smember)
{
    if (smember)
    {	ClassDeclaration *cd = smember->isClassMember();

#if LOG
	printf("ClassDeclaration::hasPrivateAccess(class %s, member %s)\n",
		toChars(), smember->toChars());
#endif

	if (this == cd)		// smember is a member of this class
	{
#if LOG
	    printf("\tyes 1\n");
#endif
	    return 1;		// so we get private access
	}

	// If both are members of the same module, grant access
	if (!cd && toParent() == smember->toParent())
	{
#if LOG
	    printf("\tyes 2\n");
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
    if (e->type->ty == Tclass)
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
}
