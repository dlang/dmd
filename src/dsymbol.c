
// Copyright (c) 1999-2002 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <string.h>

#include "mem.h"

#include "mars.h"
#include "dsymbol.h"
#include "aggregate.h"

/****************************** Dsymbol ******************************/

Dsymbol::Dsymbol()
{
    //printf("Dsymbol::Dsymbol(%p)\n", this);
    this->ident = NULL;
    this->c_ident = NULL;
    this->parent = NULL;
    this->csym = NULL;
    this->isym = NULL;
}

Dsymbol::Dsymbol(Identifier *ident)
{
    //printf("Dsymbol::Dsymbol(%p, ident)\n", this);
    this->ident = ident;
    this->c_ident = NULL;
    this->parent = NULL;
    this->csym = NULL;
    this->isym = NULL;
}

int Dsymbol::equals(Object *o)
{   Dsymbol *s;

    if (this == o)
	return TRUE;
    s = dynamic_cast<Dsymbol *>(o);
    if (s && ident->equals(s->ident))
	return TRUE;
    return FALSE;
}

/**************************************
 * Copy the syntax.
 * Used for template instantiations.
 * If s is NULL, allocate the new object, otherwise fill it in.
 */

Dsymbol *Dsymbol::syntaxCopy(Dsymbol *s)
{
    print();
    printf("%s %s\n", kind(), toChars());
    assert(0);
    return NULL;
}

char *Dsymbol::toChars()
{
    return ident ? ident->toChars() : "__anonymous";
}

char *Dsymbol::locToChars()
{
    OutBuffer buf;
    char *p;

    Module *m = getModule();

    if (m)
	loc.filename = m->srcfile->toChars();
    return loc.toChars();
}

char *Dsymbol::kind()
{
    return "symbol";
}

/*********************************
 * If this symbol is really an alias for another,
 * return that other.
 */

Dsymbol *Dsymbol::toAlias()
{
    return this;
}

int Dsymbol::isAnonymous()
{
    return ident ? 0 : 1;
}

void Dsymbol::semantic(Scope *sc)
{
    error("%p has no semantic routine", this);
}

void Dsymbol::semantic2(Scope *sc)
{
    // Most Dsymbols have no further semantic analysis needed
}

void Dsymbol::semantic3(Scope *sc)
{
    // Most Dsymbols have no further semantic analysis needed
}

void Dsymbol::inlineScan()
{
    // Most Dsymbols have no further semantic analysis needed
}

Dsymbol *Dsymbol::search(Identifier *ident)
{
    //printf("Dsymbol::search(this=%p,%s, ident='%s')\n", this, toChars(), ident->toChars());
    return NULL;
//    error("%s.%s is undefined",toChars(), ident->toChars());
//    return this;
}

int Dsymbol::overloadInsert(Dsymbol *s)
{
    return FALSE;
}

void Dsymbol::toCBuffer(OutBuffer *buf)
{
    buf->printf("Dsymbol '%s' to C file", toChars());
    buf->writenl();
}

unsigned Dsymbol::size()
{
    error("Dsymbol '%s' has no size\n", toChars());
    return 0;
}

int Dsymbol::isforwardRef()
{
    return FALSE;
}

AggregateDeclaration *Dsymbol::isThis()
{
    return NULL;
}

ClassDeclaration *Dsymbol::isClassMember()	// are we a member of a class?
{
    if (parent && dynamic_cast<ClassDeclaration *>(parent))
	return (ClassDeclaration *)parent;
    return NULL;
}

void Dsymbol::defineRef(Dsymbol *s)
{
    assert(0);
}

int Dsymbol::isExport()
{
    return FALSE;
}

int Dsymbol::isImport()
{
    return FALSE;
}

int Dsymbol::isDeprecated()
{
    return FALSE;
}

LabelDsymbol *Dsymbol::isLabel()		// is this a LabelDsymbol()?
{
    return NULL;
}

Type *Dsymbol::getType()
{
    return NULL;
}

int Dsymbol::needThis()
{
    return FALSE;
}

char *Dsymbol::mangle()
{
//    return Dsymbol::toChars();
    char *id;

    //printf("Dsymbol::mangle() '%s'\n", toChars());
    if (parent)
    {
	OutBuffer buf;

	//printf("  parent = '%s', kind = '%s'\n", parent->mangle(), parent->kind());
	buf.writestring(parent->mangle());
	buf.writestring("_");
	buf.writestring(ident ? ident->toChars() : toChars());
	id = buf.toChars();
	buf.data = NULL;
    }
    else
	id = ident ? ident->toChars() : toChars();
    return id;
}

void Dsymbol::addMember(ScopeDsymbol *sd)
{
    //printf("Dsymbol::addMember(this = %p, '%s' scopesym = '%s')\n", this, toChars(), sd->toChars());
    //printf("Dsymbol::addMember(this = %p, '%s' sd = %p, sd->symtab = %p)\n", this, toChars(), sd, sd->symtab);
    parent = sd;
    if (!isAnonymous())		// no name, so can't add it to symbol table
    {
	if (!sd->symtab->insert(this))	// if name is already defined
	{
	    Dsymbol *s2;

	    s2 = sd->symtab->lookup(ident);
	    if (!s2->overloadInsert(this))
	    {
		sd->multiplyDefined(this, s2);
	    }
	}
    }
}

void Dsymbol::error(const char *format, ...)
{
    char *p = locToChars();

    if (*p)
	printf("%s: ", p);
    mem.free(p);

    printf("%s %s ", kind(), toChars());

    va_list ap;
    va_start(ap, format);
    vprintf(format, ap);
    va_end(ap);

    printf("\n");
    fflush(stdout);

    global.errors++;

    fatal();
}

void Dsymbol::error(Loc loc, const char *format, ...)
{
    char *p = loc.toChars();

    if (*p)
	printf("%s: ", p);
    mem.free(p);

    printf("%s %s ", kind(), toChars());

    va_list ap;
    va_start(ap, format);
    vprintf(format, ap);
    va_end(ap);

    printf("\n");
    fflush(stdout);

    global.errors++;

    fatal();
}

/**********************************
 * Determine which Module a Dsymbol is in.
 */

Module *Dsymbol::getModule()
{
    Module *m;
    Dsymbol *s;

    s = this;
    while (s)
    {
	m = dynamic_cast<Module *>(s);
	if (m)
	    return m;
	s = s->parent;
    }
    return NULL;
}

/*************************************
 */

enum PROT Dsymbol::prot()
{
    return PROTpublic;
}

/*************************************
 * Do syntax copy of an array of Dsymbol's.
 */


Array *Dsymbol::arraySyntaxCopy(Array *a)
{

    Array *b = NULL;
    if (a)
    {
	b = a->copy();
	for (int i = 0; i < b->dim; i++)
	{
	    Dsymbol *s = (Dsymbol *)b->data[i];

	    s = s->syntaxCopy(NULL);
	    b->data[i] = (void *)s;
	}
    }
    return b;
}

/********************************* ScopeDsymbol ****************************/

ScopeDsymbol::ScopeDsymbol()
    : Dsymbol()
{
    members = NULL;
    symtab = NULL;
    imports = NULL;
}

ScopeDsymbol::ScopeDsymbol(Identifier *id)
    : Dsymbol(id)
{
    members = NULL;
    symtab = NULL;
    imports = NULL;
}

Dsymbol *ScopeDsymbol::syntaxCopy(Dsymbol *s)
{
    //printf("ScopeDsymbol::syntaxCopy('%s')\n", toChars());

    ScopeDsymbol *sd;
    if (s)
	sd = (ScopeDsymbol *)s;
    else
	sd = new ScopeDsymbol(ident);
    sd->members = arraySyntaxCopy(members);
    return sd;
}

Dsymbol *ScopeDsymbol::search(Identifier *ident)
{   Dsymbol *s;
    int i;

    //printf("%s->ScopeDsymbol::search(ident='%s')\n", toChars(), ident->toChars());
    // Look in symbols declared in this module
    s = symtab ? symtab->lookup(ident) : NULL;
    if (s)
    {
	//printf("\ts = '%s.%s'\n",toChars(),s->toChars());
    }
    else if (imports)
    {
	// Look in imported modules
	for (i = 0; i < imports->dim; i++)
	{   ScopeDsymbol *ss = (ScopeDsymbol *)imports->data[i];
	    Dsymbol *s2;

	    //printf("\tscanning import '%s'\n", ss->toChars());
	    s2 = ss->search(ident);
	    if (!s)
		s = s2;
	    else if (s2 && s != s2)
	    {
		ss->multiplyDefined(s, s2);
		break;
	    }
	}
    }
    return s;
}

void ScopeDsymbol::importScope(ScopeDsymbol *s)
{
    //printf("%s->ScopeDsymbol::importScope(%s)\n", toChars(), s->toChars());

    // No circular or redundant import's
    if (s != this)
    {
	if (!imports)
	    imports = new Array();
	else
	{
	    for (int i = 0; i < imports->dim; i++)
	    {   ScopeDsymbol *ss;

		ss = (ScopeDsymbol *) imports->data[i];
		if (ss == s)
		    return;
	    }
	}
	imports->push(s);
    }
}

int ScopeDsymbol::isforwardRef()
{
    return (members == NULL);
}

void ScopeDsymbol::defineRef(Dsymbol *s)
{
    ScopeDsymbol *ss;

    ss = dynamic_cast<ScopeDsymbol *>(s);
    members = ss->members;
    ss->members = NULL;
}

void ScopeDsymbol::multiplyDefined(Dsymbol *s1, Dsymbol *s2)
{
    s1->error("symbol %s.%s conflicts with %s.%s at %s",
	s1->parent->toChars(), s1->toChars(),
	s2->parent->toChars(), s2->toChars(),
	s2->locToChars());
}

Dsymbol *ScopeDsymbol::nameCollision(Dsymbol *s)
{
    Dsymbol *sprev;

    // Look to see if we are defining a forward referenced symbol

    sprev = symtab->lookup(s->ident);
    assert(sprev);
    if (s->equals(sprev))		// if the same symbol
    {
	if (s->isforwardRef())		// if second declaration is a forward reference
	    return sprev;
	if (sprev->isforwardRef())
	{
	    sprev->defineRef(s);	// copy data from s into sprev
	    return sprev;
	}
    }
    multiplyDefined(s, sprev);
    return sprev;
}

char *ScopeDsymbol::kind()
{
    return "ScopeDsymbol";
}


/****************************** WithScopeSymbol ******************************/

WithScopeSymbol::WithScopeSymbol(WithStatement *withstate)
    : ScopeDsymbol()
{
    this->withstate = withstate;
}

Dsymbol *WithScopeSymbol::search(Identifier *ident)
{
    // Acts as proxy to the with class declaration
    return withstate->exp->type->isClassHandle()->search(ident);
}

/****************************** DsymbolTable ******************************/

DsymbolTable::DsymbolTable()
{
    tab = new StringTable;
}

DsymbolTable::~DsymbolTable()
{
    delete tab;
}

Dsymbol *DsymbolTable::lookup(Identifier *ident)
{   StringValue *sv;

    sv = tab->lookup(ident->toChars(),strlen(ident->toChars()));
    return (Dsymbol *)(sv ? sv->ptrvalue : NULL);
}

Dsymbol *DsymbolTable::insert(Dsymbol *s)
{   StringValue *sv;
    Identifier *ident;

    //printf("DsymbolTable::insert(this = %p, '%s')\n", this, s->ident->toChars());
    ident = s->ident;
#ifdef DEBUG
    assert(ident);
    assert(tab);
#endif
    sv = tab->insert(ident->toChars(),strlen(ident->toChars()));
    if (!sv)
	return NULL;		// already in table
    sv->ptrvalue = s;
    return s;
}

Dsymbol *DsymbolTable::insert(Identifier *ident, Dsymbol *s)
{   StringValue *sv;

    //printf("DsymbolTable::insert()\n");
    sv = tab->insert(ident->toChars(),strlen(ident->toChars()));
    if (!sv)
	return NULL;		// already in table
    sv->ptrvalue = s;
    return s;
}

Dsymbol *DsymbolTable::update(Dsymbol *s)
{   StringValue *sv;
    Identifier *ident;

    ident = s->ident;
    sv = tab->update(ident->toChars(),strlen(ident->toChars()));
    sv->ptrvalue = s;
    return s;
}




