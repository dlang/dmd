
// Copyright (c) 1999-2005 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
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

/********************************* Import ****************************/

Import::Import(Loc loc, Array *packages, Identifier *id)
    : Dsymbol(id)
{
    this->loc = loc;
    this->packages = packages;
    this->id = id;
    pkg = NULL;
    mod = NULL;

    // Kludge to change Import identifier to first package
    if (packages && packages->dim)
	this->ident = (Identifier *)packages->data[0];
}

char *Import::kind()
{
    return "import";
}


Dsymbol *Import::syntaxCopy(Dsymbol *s)
{
    assert(!s);

    Import *si;

    si = new Import(loc, packages, id);
    return si;
}

void Import::load()
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
    }
    if (!pkg)
	pkg = mod;
    mod->semantic();

    //printf("-Import::load('%s'), pkg = %p\n", toChars(), pkg);
}


void Import::semantic(Scope *sc)
{
    //printf("Import::semantic('%s')\n", toChars());

    load();

    if (mod)
    {
	if (mod->loc.linnum != 0)
	    /* If the line number is not 0, then this is not
	     * a 'root' module, i.e. it was not specified on the command line.
	     */
	    mod->importedFrom = sc->module->importedFrom;

	sc->scopesym->importScope(mod, sc->protection);

	// Modules need a list of each imported module
	sc->module->aimports.push(mod);

	if (mod->needmoduleinfo)
	    sc->module->needmoduleinfo = 1;
    }
    //printf("-Import::semantic('%s'), pkg = %p\n", toChars(), pkg);
}

void Import::semantic2(Scope *sc)
{
    mod->semantic2();
    if (mod->needmoduleinfo)
	sc->module->needmoduleinfo = 1;
}

Dsymbol *Import::search(Identifier *ident, int flags)
{
    //printf("%s.Import::search(ident = '%s', flags = x%x)\n", toChars(), ident->toChars(), flags);

    if (!pkg)
	load();

    // Forward it to the package/module
    return pkg->search(ident, flags);
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

    buf->writestring("import ");
    if (packages && packages->dim)
    {	int i;

	for (i = 0; i < packages->dim; i++)
	{   Identifier *pid = (Identifier *)packages->data[i];

	    buf->printf("%s.", pid->toChars());
	}
    }
    buf->printf("%s;", id->toChars());
    buf->writenl();
}

