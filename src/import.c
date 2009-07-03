
// Compiler implementation of the D programming language
// Copyright (c) 1999-2006 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <assert.h>

#include "root.h"
#include "dsymbol.h"
#include "import.h"
#include "identifier.h"
#include "module.h"
#include "scope.h"
#include "hdrgen.h"
#include "mtype.h"
#include "declaration.h"
#include "id.h"

/********************************* Import ****************************/

Import::Import(Loc loc, Array *packages, Identifier *id, Identifier *aliasId,
	int isstatic)
    : Dsymbol(id)
{
    this->loc = loc;
    this->packages = packages;
    this->id = id;
    this->aliasId = aliasId;
    this->isstatic = isstatic;
    pkg = NULL;
    mod = NULL;

    if (aliasId)
	this->ident = aliasId;
    // Kludge to change Import identifier to first package
    else if (packages && packages->dim)
	this->ident = (Identifier *)packages->data[0];
}

void Import::addAlias(Identifier *name, Identifier *alias)
{
    if (isstatic)
	error("cannot have an import bind list");

    if (!aliasId)
	this->ident = NULL;	// make it an anonymous import

    names.push(name);
    aliases.push(alias);
}

char *Import::kind()
{
    return isstatic ? (char *)"static import" : (char *)"import";
}


Dsymbol *Import::syntaxCopy(Dsymbol *s)
{
    assert(!s);

    Import *si;

    si = new Import(loc, packages, id, aliasId, isstatic);

    for (size_t i = 0; i < names.dim; i++)
    {
	si->addAlias((Identifier *)names.data[i], (Identifier *)aliases.data[i]);
    }

    return si;
}

void Import::load(Scope *sc)
{
    DsymbolTable *dst;
    Dsymbol *s;

    //printf("Import::load('%s')\n", toChars());

    // See if existing module
    dst = Package::resolve(packages, NULL, &pkg);

    s = dst->lookup(id);
    if (s)
    {
	if (s->isModule())
	    mod = (Module *)s;
	else
	    error("package and module have the same name");
    }

    if (!mod)
    {
	// Load module
	mod = Module::load(loc, packages, id);
	dst->insert(id, mod);		// id may be different from mod->ident,
					// if so then insert alias
	if (!mod->importedFrom)
	    mod->importedFrom = sc ? sc->module->importedFrom : Module::rootModule;
    }
    if (!pkg)
	pkg = mod;
    mod->semantic();

    //printf("-Import::load('%s'), pkg = %p\n", toChars(), pkg);
}


void Import::semantic(Scope *sc)
{
    //printf("Import::semantic('%s')\n", toChars());

    load(sc);

    if (mod)
    {
#if 0
	if (mod->loc.linnum != 0)
	{   /* If the line number is not 0, then this is not
	     * a 'root' module, i.e. it was not specified on the command line.
	     */
	    mod->importedFrom = sc->module->importedFrom;
	    assert(mod->importedFrom);
	}
#endif

	if (!isstatic && !aliasId && !names.dim)
	{
	    /* Default to private importing
	     */
	    enum PROT prot = sc->protection;
	    if (!sc->explicitProtection)
		prot = PROTprivate;
	    sc->scopesym->importScope(mod, prot);
	}

	// Modules need a list of each imported module
	sc->module->aimports.push(mod);

	if (mod->needmoduleinfo)
	    sc->module->needmoduleinfo = 1;

	sc = sc->push(mod);
	for (size_t i = 0; i < aliasdecls.dim; i++)
	{   Dsymbol *s = (Dsymbol *)aliasdecls.data[i];

	    //printf("\tImport alias semantic('%s')\n", s->toChars());
	    if (!mod->search(loc, (Identifier *)names.data[i], 0))
		error("%s not found", ((Identifier *)names.data[i])->toChars());

	    s->semantic(sc);
	}
	sc = sc->pop();
    }
    //printf("-Import::semantic('%s'), pkg = %p\n", toChars(), pkg);
}

void Import::semantic2(Scope *sc)
{
    //printf("Import::semantic2('%s')\n", toChars());
    mod->semantic2();
    if (mod->needmoduleinfo)
	sc->module->needmoduleinfo = 1;
}

Dsymbol *Import::toAlias()
{
    if (aliasId)
	return mod;
    return this;
}

int Import::addMember(Scope *sc, ScopeDsymbol *sd, int memnum)
{
    int result = 0;

    if (names.dim == 0)
	return Dsymbol::addMember(sc, sd, memnum);

    if (aliasId)
	result = Dsymbol::addMember(sc, sd, memnum);

    for (size_t i = 0; i < names.dim; i++)
    {
	Identifier *name = (Identifier *)names.data[i];
	Identifier *alias = (Identifier *)aliases.data[i];

	if (!alias)
	    alias = name;

#if 1
	TypeIdentifier *tname = new TypeIdentifier(loc, name);
#else
	TypeIdentifier *tname = new TypeIdentifier(loc, NULL);
	if (packages)
	{
	    for (size_t j = 0; j < packages->dim; j++)
	    {   Identifier *pid = (Identifier *)packages->data[j];

		if (!tname->ident)
		    tname->ident = pid;
		else
		    tname->addIdent(pid);
	    }
	}
	if (!tname->ident)
	    tname->ident = id;
	else
	    tname->addIdent(id);
	tname->addIdent(name);
#endif
	AliasDeclaration *ad = new AliasDeclaration(loc, alias, tname);
	result |= ad->addMember(sc, sd, memnum);

	aliasdecls.push(ad);
    }

    return result;
}

Dsymbol *Import::search(Loc loc, Identifier *ident, int flags)
{
    //printf("%s.Import::search(ident = '%s', flags = x%x)\n", toChars(), ident->toChars(), flags);

    if (!pkg)
	load(NULL);

    // Forward it to the package/module
    return pkg->search(loc, ident, flags);
}

int Import::overloadInsert(Dsymbol *s)
{
    // Allow multiple imports of the same name
    return s->isImport() != NULL;
}

void Import::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    if (hgs->hdrgen && id == Id::object)
	return;		// object is imported by default

    if (isstatic)
	buf->writestring("static ");
    buf->writestring("import ");
    if (aliasId)
    {
	buf->printf("%s = ", aliasId->toChars());
    }
    if (packages && packages->dim)
    {
	for (size_t i = 0; i < packages->dim; i++)
	{   Identifier *pid = (Identifier *)packages->data[i];

	    buf->printf("%s.", pid->toChars());
	}
    }
    buf->printf("%s;", id->toChars());
    buf->writenl();
}

