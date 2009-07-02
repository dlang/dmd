
// Copyright (c) 1999-2002 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.


#include "root.h"
#include "mem.h"

#include "enum.h"
#include "aggregate.h"
#include "init.h"
#include "attrib.h"

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
    if (smember->parent == this)
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

		case PROTprotected:
		case PROTpublic:
		case PROTexport:
		    // If access is not to be left unchanged
		    //if (!list_inlist(b->BCpublics,smember))
		    {   // Modify access based on derivation access
			switch (b->protection)
			{   case PROTprivate:
			    case PROTprotected:
				access = b->protection;
				break;
			}
		    }

		    // Pick path with loosest access
		    if (access_ret == PROTnone || access < access_ret)
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
	if (smember->parent == cdthis)
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
	if (smember->parent != cdthis)
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

    if (smember->parent == this)
    {
	result = smember->prot() >= PROTpublic ||
		hasPrivateAccess(f) ||
		isFriendOf(cdscope);
#if LOG
	printf("result1 = %d\n", result);
#endif
    }
    else if (this->getAccess(smember) >= PROTpublic)
    {
	result = 1;
#if LOG
	printf("result2 = %d\n", result);
#endif
    }
    else
    {
	result = accessCheckX(smember, f, this, cdscope);
#if LOG
	printf("result3 = %d\n", result);
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
    if (cd && parent == cd->parent)
    {
#if LOG
	printf("\tin same module\n");
#endif
	return 1;
    }

    if (cd && cd->parent == this)
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
	    return 1;		// so we get private access

	// If both are members of the same module, grant access
	if (!cd && parent == smember->parent)
	    return 1;
    }
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
	if (e->op == TOKsuper)
	{
	    cd = sc->func->parent->isClassDeclaration();
	}
	cd->accessCheck(loc, sc, d);
    }
}
