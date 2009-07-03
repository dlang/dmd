
// Compiler implementation of the D programming language
// Copyright (c) 1999-2006 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <string.h>
#include <assert.h>

#include "mem.h"

#include "mars.h"
#include "dsymbol.h"
#include "aggregate.h"
#include "identifier.h"
#include "module.h"
#include "mtype.h"
#include "expression.h"
#include "statement.h"
#include "declaration.h"
#include "id.h"
#include "scope.h"
#include "init.h"
#include "import.h"

/****************************** Dsymbol ******************************/

Dsymbol::Dsymbol()
{
    //printf("Dsymbol::Dsymbol(%p)\n", this);
    this->ident = NULL;
    this->c_ident = NULL;
    this->parent = NULL;
    this->csym = NULL;
    this->isym = NULL;
    this->loc = 0;
    this->comment = NULL;
}

Dsymbol::Dsymbol(Identifier *ident)
{
    //printf("Dsymbol::Dsymbol(%p, ident)\n", this);
    this->ident = ident;
    this->c_ident = NULL;
    this->parent = NULL;
    this->csym = NULL;
    this->isym = NULL;
    this->loc = 0;
    this->comment = NULL;
}

int Dsymbol::equals(Object *o)
{   Dsymbol *s;

    if (this == o)
	return TRUE;
    s = (Dsymbol *)(o);
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

/**************************************
 * Determine if this symbol is only one.
 * Returns:
 *	FALSE, *ps = NULL: There are 2 or more symbols
 *	TRUE,  *ps = NULL: There are zero symbols
 *	TRUE,  *ps = symbol: The one and only one symbol
 */

int Dsymbol::oneMember(Dsymbol **ps)
{
    //printf("Dsymbol::oneMember()\n");
    *ps = this;
    return TRUE;
}

/*****************************************
 * Same as Dsymbol::oneMember(), but look at an array of Dsymbols.
 */

int Dsymbol::oneMembers(Array *members, Dsymbol **ps)
{
    //printf("Dsymbol::oneMembers() %d\n", members ? members->dim : 0);
    Dsymbol *s = NULL;

    if (members)
    {
	for (int i = 0; i < members->dim; i++)
	{   Dsymbol *sx = (Dsymbol *)members->data[i];

	    int x = sx->oneMember(ps);
	    //printf("\t[%d] kind %s = %d, s = %p\n", i, sx->kind(), x, *ps);
	    if (!x)
	    {
		//printf("\tfalse 1\n");
		assert(*ps == NULL);
		return FALSE;
	    }
	    if (*ps)
	    {
		if (s)			// more than one symbol
		{   *ps = NULL;
		    //printf("\tfalse 2\n");
		    return FALSE;
		}
		s = *ps;
	    }
	}
    }
    *ps = s;		// s is the one symbol, NULL if none
    //printf("\ttrue\n");
    return TRUE;
}

/*****************************************
 * Is Dsymbol a variable that contains pointers?
 */

int Dsymbol::hasPointers()
{
    //printf("Dsymbol::hasPointers() %s\n", toChars());
    return 0;
}

char *Dsymbol::toChars()
{
    return ident ? ident->toChars() : (char *)"__anonymous";
}

char *Dsymbol::toPrettyChars()
{   Dsymbol *p;
    char *s;
    char *q;
    size_t len;

    //printf("Dsymbol::toPrettyChars() '%s'\n", toChars());
    if (!parent)
	return toChars();

    len = 0;
    for (p = this; p; p = p->parent)
	len += strlen(p->toChars()) + 1;

    s = (char *)mem.malloc(len);
    q = s + len - 1;
    *q = 0;
    for (p = this; p; p = p->parent)
    {
	char *t = p->toChars();
	len = strlen(t);
	q -= len;
	memcpy(q, t, len);
	if (q == s)
	    break;
	q--;
	*q = '.';
    }
    return s;
}

char *Dsymbol::locToChars()
{
    OutBuffer buf;
    char *p;

    Module *m = getModule();

    if (m && m->srcfile)
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

Dsymbol *Dsymbol::toParent()
{
    return parent ? parent->pastMixin() : NULL;
}

Dsymbol *Dsymbol::pastMixin()
{
    Dsymbol *s = this;

    //printf("Dsymbol::pastMixin() %s\n", toChars());
    while (s && s->isTemplateMixin())
	s = s->parent;
    return s;
}

/**********************************
 * Use this instead of toParent() when looking for the
 * 'this' pointer of the enclosing function/class.
 */

Dsymbol *Dsymbol::toParent2()
{
    Dsymbol *s = parent;
    while (s && s->isTemplateInstance())
	s = s->parent;
    return s;
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

Dsymbol *Dsymbol::search(Loc loc, Identifier *ident, int flags)
{
    //printf("Dsymbol::search(this=%p,%s, ident='%s')\n", this, toChars(), ident->toChars());
    return NULL;
//    error("%s.%s is undefined",toChars(), ident->toChars());
//    return this;
}

int Dsymbol::overloadInsert(Dsymbol *s)
{
    //printf("Dsymbol::overloadInsert('%s')\n", s->toChars());
    return FALSE;
}

void Dsymbol::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring(toChars());
}

unsigned Dsymbol::size(Loc loc)
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
    Dsymbol *parent = toParent();
    if (parent && parent->isClassDeclaration())
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

int Dsymbol::isImportedSymbol()
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

AggregateDeclaration *Dsymbol::isMember()	// is this a member of an AggregateDeclaration?
{
    Dsymbol *parent = toParent();
    return parent ? parent->isAggregateDeclaration() : NULL;
}

Type *Dsymbol::getType()
{
    return NULL;
}

int Dsymbol::needThis()
{
    return FALSE;
}

int Dsymbol::addMember(Scope *sc, ScopeDsymbol *sd, int memnum)
{
    //printf("Dsymbol::addMember('%s')\n", toChars());
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
		sd->multiplyDefined(0, this, s2);
	    }
	}
	if (sd->isAggregateDeclaration() || sd->isEnumDeclaration())
	{
	    if (ident == Id::__sizeof || ident == Id::alignof || ident == Id::mangleof)
		error(".%s property cannot be redefined", ident->toChars());
	}
	return 1;
    }
    return 0;
}

void Dsymbol::error(const char *format, ...)
{
    //printf("Dsymbol::error()\n");
    if (!global.gag)
    {
	char *p = locToChars();

	if (*p)
	    fprintf(stdmsg, "%s: ", p);
	mem.free(p);

	if (isAnonymous())
	    fprintf(stdmsg, "%s ", kind());
	else
	    fprintf(stdmsg, "%s %s ", kind(), toPrettyChars());

	va_list ap;
	va_start(ap, format);
	vfprintf(stdmsg, format, ap);
	va_end(ap);

	fprintf(stdmsg, "\n");
	fflush(stdmsg);
    }
    global.errors++;

    //fatal();
}

void Dsymbol::error(Loc loc, const char *format, ...)
{
    if (!global.gag)
    {
	char *p = loc.toChars();
	if (!*p)
	    p = locToChars();

	if (*p)
	    fprintf(stdmsg, "%s: ", p);
	mem.free(p);

	fprintf(stdmsg, "%s %s ", kind(), toPrettyChars());

	va_list ap;
	va_start(ap, format);
	vfprintf(stdmsg, format, ap);
	va_end(ap);

	fprintf(stdmsg, "\n");
	fflush(stdmsg);
    }

    global.errors++;

    //fatal();
}

void Dsymbol::checkDeprecated(Loc loc, Scope *sc)
{
    if (!global.params.useDeprecated && isDeprecated())
    {
	// Don't complain if we're inside a deprecated symbol's scope
	for (Dsymbol *sp = sc->parent; sp; sp = sp->parent)
	{   if (sp->isDeprecated())
		return;
	}

	for (; sc; sc = sc->enclosing)
	{
	    if (sc->scopesym && sc->scopesym->isDeprecated())
		return;
	}

	error(loc, "is deprecated");
    }
}

/**********************************
 * Determine which Module a Dsymbol is in.
 */

Module *Dsymbol::getModule()
{
    Module *m;
    Dsymbol *s;

    //printf("Dsymbol::getModule()\n");
    s = this;
    while (s)
    {
	//printf("\ts = '%s'\n", s->toChars());
	m = s->isModule();
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


/****************************************
 * Add documentation comment to Dsymbol.
 * Ignore NULL comments.
 */

void Dsymbol::addComment(unsigned char *comment)
{
//    if (comment)
//	printf("adding comment '%s' to symbol %p '%s'\n", comment, this, toChars());

    if (!this->comment)
	this->comment = comment;
#if 1
    else if (comment && strcmp((char *)comment, (char *)this->comment))
    {	// Concatenate the two
	this->comment = Lexer::combineComments(this->comment, comment);
    }
#endif
}


/********************************* ScopeDsymbol ****************************/

ScopeDsymbol::ScopeDsymbol()
    : Dsymbol()
{
    members = NULL;
    symtab = NULL;
    imports = NULL;
    prots = NULL;
}

ScopeDsymbol::ScopeDsymbol(Identifier *id)
    : Dsymbol(id)
{
    members = NULL;
    symtab = NULL;
    imports = NULL;
    prots = NULL;
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

Dsymbol *ScopeDsymbol::search(Loc loc, Identifier *ident, int flags)
{   Dsymbol *s;
    int i;

    //printf("%s->ScopeDsymbol::search(ident='%s', flags=x%x)\n", toChars(), ident->toChars(), flags);
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

	    // If private import, don't search it
	    if (flags & 1 && prots[i] == PROTprivate)
		continue;

	    //printf("\tscanning import '%s', prots = %d, isModule = %p, isImport = %p\n", ss->toChars(), prots[i], ss->isModule(), ss->isImport());
	    s2 = ss->search(loc, ident, ss->isModule() ? 1 : 0);
	    if (!s)
		s = s2;
	    else if (s2 && s != s2)
	    {
		if (s->toAlias() == s2->toAlias())
		{
		    if (s->isDeprecated())
			s = s2;
		}
		else
		{
		    /* Two imports of the same module should be regarded as
		     * the same.
		     */
		    Import *i1 = s->isImport();
		    Import *i2 = s2->isImport();
		    if (!(i1 && i2 &&
			  (i1->mod == i2->mod ||
			   (!i1->parent->isImport() && !i2->parent->isImport() &&
			    i1->ident->equals(i2->ident))
			  )
			 )
		       )
		    {
			ss->multiplyDefined(loc, s, s2);
			break;
		    }
		}
	    }
	}
	if (s)
	{
	    Declaration *d = s->isDeclaration();
	    if (d && d->protection == PROTprivate && !d->parent->isTemplateMixin())
		error("%s is private", d->toPrettyChars());
	}
    }
    return s;
}

void ScopeDsymbol::importScope(ScopeDsymbol *s, enum PROT protection)
{
    //printf("%s->ScopeDsymbol::importScope(%s, %d)\n", toChars(), s->toChars(), protection);

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
		{
		    if (protection > prots[i])
			prots[i] = protection;	// upgrade access
		    return;
		}
	    }
	}
	imports->push(s);
	prots = (unsigned char *)mem.realloc(prots, imports->dim * sizeof(prots[0]));
	prots[imports->dim - 1] = protection;
    }
}

int ScopeDsymbol::isforwardRef()
{
    return (members == NULL);
}

void ScopeDsymbol::defineRef(Dsymbol *s)
{
    ScopeDsymbol *ss;

    ss = s->isScopeDsymbol();
    members = ss->members;
    ss->members = NULL;
}

void ScopeDsymbol::multiplyDefined(Loc loc, Dsymbol *s1, Dsymbol *s2)
{
#if 0
    printf("ScopeDsymbol::multiplyDefined()\n");
    printf("s1 = %p, '%s' kind = '%s', parent = %s\n", s1, s1->toChars(), s1->kind(), s1->parent ? s1->parent->toChars() : "");
    printf("s2 = %p, '%s' kind = '%s', parent = %s\n", s2, s2->toChars(), s2->kind(), s2->parent ? s2->parent->toChars() : "");
#endif
    if (loc.filename)
    {	::error(loc, "%s at %s conflicts with %s at %s",
	    s1->toPrettyChars(),
	    s1->locToChars(),
	    s2->toPrettyChars(),
	    s2->locToChars());
    }
    else
    {
	s1->error(loc, "conflicts with %s at %s",
	    s2->toPrettyChars(),
	    s2->locToChars());
    }
//*(char*)0=0;
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
    multiplyDefined(0, s, sprev);
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

Dsymbol *WithScopeSymbol::search(Loc loc, Identifier *ident, int flags)
{
    // Acts as proxy to the with class declaration
    return withstate->exp->type->toDsymbol(NULL)->search(loc, ident, 0);
}

/****************************** ArrayScopeSymbol ******************************/

ArrayScopeSymbol::ArrayScopeSymbol(Expression *e)
    : ScopeDsymbol()
{
    assert(e->op == TOKindex || e->op == TOKslice);
    exp = e;
    type = NULL;
}

ArrayScopeSymbol::ArrayScopeSymbol(TypeTuple *t)
    : ScopeDsymbol()
{
    exp = NULL;
    type = t;
}

Dsymbol *ArrayScopeSymbol::search(Loc loc, Identifier *ident, int flags)
{
    //printf("ArrayScopeSymbol::search('%s', flags = %d)\n", ident->toChars(), flags);
    if (ident == Id::length || ident == Id::dollar)
    {	VarDeclaration **pvar;
	Expression *ce;

    L1:
	if (type)
 	{
	    VarDeclaration *v = new VarDeclaration(0, Type::tsize_t, Id::dollar, NULL);
	    Expression *e = new IntegerExp(0, type->arguments->dim, Type::tsize_t);
	    v->init = new ExpInitializer(0, e);
	    v->storage_class |= STCconst;
	    return v;
	}

	if (exp->op == TOKindex)
	{
	    IndexExp *ie = (IndexExp *)exp;

	    pvar = &ie->lengthVar;
	    ce = ie->e1;
	}
	else if (exp->op == TOKslice)
	{
	    SliceExp *se = (SliceExp *)exp;

	    pvar = &se->lengthVar;
	    ce = se->e1;
	}
	else
	    return NULL;

	if (ce->op == TOKtype)
	{
	    Type *t = ((TypeExp *)ce)->type;
	    if (t->ty == Ttuple)
	    {	type = (TypeTuple *)t;
		goto L1;
	    }
	}

	if (!*pvar)
	{
	    VarDeclaration *v = new VarDeclaration(0, Type::tsize_t, Id::dollar, NULL);

	    if (ce->op == TOKstring)
	    {	/* It is for a string literal, so the
		 * length will be a const.
		 */
		Expression *e = new IntegerExp(0, ((StringExp *)ce)->len, Type::tsize_t);
		v->init = new ExpInitializer(0, e);
		v->storage_class |= STCconst;
	    }
	    else if (ce->op == TOKtuple)
	    {	/* It is for an expression tuple, so the
		 * length will be a const.
		 */
		Expression *e = new IntegerExp(0, ((TupleExp *)ce)->exps->dim, Type::tsize_t);
		v->init = new ExpInitializer(0, e);
		v->storage_class |= STCconst;
	    }
	    *pvar = v;
	}
	return (*pvar);
    }
    return NULL;
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

#ifdef DEBUG
    assert(ident);
    assert(tab);
#endif
    sv = tab->lookup((char*)ident->string, ident->len);
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
    sv = tab->insert(ident->toChars(), ident->len);
    if (!sv)
	return NULL;		// already in table
    sv->ptrvalue = s;
    return s;
}

Dsymbol *DsymbolTable::insert(Identifier *ident, Dsymbol *s)
{   StringValue *sv;

    //printf("DsymbolTable::insert()\n");
    sv = tab->insert(ident->toChars(), ident->len);
    if (!sv)
	return NULL;		// already in table
    sv->ptrvalue = s;
    return s;
}

Dsymbol *DsymbolTable::update(Dsymbol *s)
{   StringValue *sv;
    Identifier *ident;

    ident = s->ident;
    sv = tab->update(ident->toChars(), ident->len);
    sv->ptrvalue = s;
    return s;
}




