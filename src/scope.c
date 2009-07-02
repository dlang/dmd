
// Copyright (c) 1999-2002 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include "root.h"
#include "identifier.h"
#include "scope.h"
#include "attrib.h"

Scope *Scope::freelist = NULL;

void *Scope::operator new(size_t size)
{   Scope *s;

    if (freelist)
    {
	s = freelist;
	freelist = s->enclosing;
	return s;
    }

    return ::operator new(size);
}

Scope::Scope()
{   // Create root scope

    this->module = NULL;
    this->scopesym = NULL;
    this->enclosing = NULL;
    this->parent = NULL;
    this->sw = NULL;
    this->sbreak = NULL;
    this->scontinue = NULL;
    this->structalign = global.structalign;
    this->func = NULL;
    this->slabel = NULL;
    this->linkage = LINKd;
    this->protection = PROTpublic;
    this->stc = 0;
    this->offset = 0;
    this->inunion = 0;
    this->incontract = 0;
    this->nofree = 0;
    this->noctor = 0;
    this->callSuper = 0;
    this->flags = 0;
}

Scope::Scope(Scope *enclosing)
{
    this->module = enclosing->module;
    this->func   = enclosing->func;
    this->parent = enclosing->parent;
    this->scopesym = NULL;
    this->sw = enclosing->sw;
    this->sbreak = enclosing->sbreak;
    this->scontinue = enclosing->scontinue;
    this->structalign = enclosing->structalign;
    this->enclosing = enclosing;
    this->slabel = NULL;
    this->linkage = enclosing->linkage;
    this->protection = enclosing->protection;
    this->stc = enclosing->stc;
    this->offset = 0;
    this->inunion = enclosing->inunion;
    this->incontract = enclosing->incontract;
    this->nofree = 0;
    this->noctor = enclosing->noctor;
    this->callSuper = enclosing->callSuper;
    this->flags = 0;
    assert(this != enclosing);
}

#if 0
Scope::Scope(Module *module)
{   // Create root scope

    this->module = module;
    this->scopesym = module;
    this->enclosing = NULL;
    this->parent = NULL;
    this->sw = NULL;
    this->sbreak = NULL;
    this->scontinue = NULL;
    this->structalign = global.structalign;
    this->func = NULL;
    this->slabel = NULL;
    this->linkage = LINKd;
    this->protection = PROTpublic;
    this->stc = 0;
    this->offset = 0;
    this->inunion = 0;
    this->incontract = 0;
    this->nofree = 0;
    this->noctor = 0;
    this->callSuper = 0;
    this->flags = 0;
}
#endif

Scope *Scope::createGlobal(Module *module)
{
    Scope *sc;

    sc = new Scope();
    sc->module = module;
    sc->scopesym = new ScopeDsymbol();
    sc->scopesym->symtab = new DsymbolTable();
    module->addMember(sc->scopesym);
    module->parent = NULL;

    sc = sc->push(module);
    sc->parent = module;
    return sc;
}

Scope *Scope::push()
{   Scope *s;

    s = new Scope(this);
    assert(this != s);
    return s;
}

Scope *Scope::push(ScopeDsymbol *ss)
{   Scope *s;

    s = push();
    s->scopesym = ss;
    return s;
}

Scope *Scope::pop()
{
    Scope *enc = enclosing;

    if (enclosing)
	enclosing->callSuper |= callSuper;

    if (!nofree)
    {	enclosing = freelist;
	freelist = this;
    }

    return enc;
}

void Scope::mergeCallSuper(Loc loc, unsigned cs)
{
    // This does a primitive flow analysis to support the restrictions
    // regarding when and how constructors can appear.
    // It merges the results of two paths.
    // The two paths are callSuper and cs; the result is merged into callSuper.

    if (cs != callSuper)
    {	int a;
	int b;

	callSuper |= cs & (CSXany_ctor | CSXlabel);
	if (cs & CSXreturn)
	{
	}
	else if (callSuper & CSXreturn)
	{
	    callSuper = cs | (callSuper & (CSXany_ctor | CSXlabel));
	}
	else
	{
	    a = (cs        & (CSXthis_ctor | CSXsuper_ctor)) != 0;
	    b = (callSuper & (CSXthis_ctor | CSXsuper_ctor)) != 0;
	    if (a != b)
		error(loc, "one path skips constructor");
	    callSuper |= cs;
	}
    }
}

Dsymbol *Scope::search(Identifier *ident, Dsymbol **pscopesym)
{   Dsymbol *s;
    Scope *sc;

    //printf("Scope::search(%p, '%s')\n", this, ident->toChars());
    if (ident == Id::empty)
    {
	// Look for module scope
	for (sc = this; sc; sc = sc->enclosing)
	{
	    assert(sc != sc->enclosing);
	    if (sc->scopesym)
	    {
		s = sc->scopesym->isModule();
		if (s)
		{
		    //printf("\tfound %s.%s\n", s->parent ? s->parent->toChars() : "", s->toChars());
		    if (pscopesym)
			*pscopesym = sc->scopesym;
		    return s;
		}
	    }
	}
	return NULL;
    }

    for (sc = this; sc; sc = sc->enclosing)
    {
	assert(sc != sc->enclosing);
	if (sc->scopesym)
	{
	    //printf("\tlooking in scopesym '%s'\n", sc->scopesym->toChars());
	    s = sc->scopesym->search(ident, 0);
	    if (s)
	    {
		//printf("\tfound %s.%s\n", s->parent ? s->parent->toChars() : "", s->toChars());
		if (pscopesym)
		    *pscopesym = sc->scopesym;
		return s;
	    }
	}
    }

    return NULL;
}

Dsymbol *Scope::insert(Dsymbol *s)
{   Scope *sc;

    for (sc = this; sc; sc = sc->enclosing)
    {
	//printf("\tsc = %p\n", sc);
	if (sc->scopesym)
	{
	    //printf("\t\tsc->scopesym = %p\n", sc->scopesym);
	    if (!sc->scopesym->symtab)
		sc->scopesym->symtab = new DsymbolTable();
	    return sc->scopesym->symtab->insert(s);
	}
    }
    assert(0);
    return NULL;
}

/********************************************
 * Search enclosing scopes for ClassDeclaration.
 */

ClassDeclaration *Scope::getClassScope()
{   Scope *sc;

    for (sc = this; sc; sc = sc->enclosing)
    {
	ClassDeclaration *cd;
	
	if (sc->scopesym)
	{
	    cd = sc->scopesym->isClassDeclaration();
	    if (cd)
		return cd;
	}
    }
    return NULL;
}

/*******************************************
 * For TemplateDeclarations, we need to remember the Scope
 * where it was declared. So mark the Scope as not
 * to be free'd.
 */

void Scope::setNoFree()
{   Scope *sc;

    for (sc = this; sc; sc = sc->enclosing)
    {
	sc->nofree = 1;
    }
}
