
// Copyright (c) 1999-2002 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include "declaration.h"
#include "init.h"
#include "attrib.h"
#include "template.h"

/********************************* Declaration ****************************/

Declaration::Declaration(Identifier *id)
    : Dsymbol(id)
{
    type = NULL;
    storage_class = STCundefined;
    protection = PROTundefined;
    linkage = LINKdefault;
}

void Declaration::semantic(Scope *sc)
{
}

char *Declaration::kind()
{
    return "declaration";
}

unsigned Declaration::size()
{
    assert(type);
    return type->size();
}

int Declaration::isStaticConstructor()
{
    return FALSE;
}

int Declaration::isStaticDestructor()
{
    return FALSE;
}

int Declaration::isDelete()
{
    return FALSE;
}

int Declaration::isDataseg()
{
    return FALSE;
}

int Declaration::isCodeseg()
{
    return FALSE;
}

enum PROT Declaration::prot()
{
    return protection;
}

/********************************* TypedefDeclaration ****************************/

TypedefDeclaration::TypedefDeclaration(Identifier *id, Type *basetype, Initializer *init)
    : Declaration(id)
{
    this->type = new TypeTypedef(this);
    this->basetype = basetype->toBasetype();
    this->init = init;
    this->sem = 0;
}

Dsymbol *TypedefDeclaration::syntaxCopy(Dsymbol *s)
{
    Type *basetype = this->basetype->syntaxCopy();

    Initializer *init = NULL;
    if (this->init)
	init = this->init->syntaxCopy();

    assert(!s);
    TypedefDeclaration *st;
    st = new TypedefDeclaration(ident, basetype, init);
    return st;
}

void TypedefDeclaration::semantic(Scope *sc)
{
    //printf("TypedefDeclaration::semantic()\n");
    if (!sem)
    {	sem = 1;
	basetype = basetype->semantic(loc, sc);
	if (sc->parent->isFuncDeclaration() && init)
	    semantic2(sc);
    }
}

void TypedefDeclaration::semantic2(Scope *sc)
{
    //printf("TypedefDeclaration::semantic2()\n");
    if (sem == 1)
    {	sem = 2;
	if (init)
	{
	    init = init->semantic(sc, basetype);

	    ExpInitializer *ie = init->isExpInitializer();
	    if (ie)
	    {
		if (ie->exp->type == basetype)
		    ie->exp->type = type;
	    }
	}
    }
}

char *TypedefDeclaration::kind()
{
    return "typedef";
}

Type *TypedefDeclaration::getType()
{
    return type;
}

void TypedefDeclaration::toCBuffer(OutBuffer *buf)
{
    buf->writestring("typedef ");
    basetype->toCBuffer(buf, ident);
    buf->writeByte(';');
    buf->writenl();
}

/********************************* AliasDeclaration ****************************/

AliasDeclaration::AliasDeclaration(Loc loc, Identifier *id, Type *type)
    : Declaration(id)
{
    //printf("AliasDeclaration(id = '%s')\n", id->toChars());
    this->loc = loc;
    this->type = type;
    this->aliassym = NULL;
    this->overnext = NULL;
}

AliasDeclaration::AliasDeclaration(Loc loc, Identifier *id, Dsymbol *s)
    : Declaration(id)
{
    this->loc = loc;
    this->type = NULL;
    this->aliassym = s;
    this->overnext = NULL;
}

Dsymbol *AliasDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(!s);
    AliasDeclaration *sa;
    if (type)
	sa = new AliasDeclaration(loc, ident, type->syntaxCopy());
    else
	sa = new AliasDeclaration(loc, ident, aliassym->syntaxCopy(NULL));
    return sa;
}

void AliasDeclaration::semantic(Scope *sc)
{
    //printf("AliasDeclaration::semantic() %s\n", toChars());
    if (aliassym)
    {
	aliassym->semantic(sc);
	return;
    }

    // Given:
    //	alias foo.bar.abc def;
    // it is not knownable from the syntax whether this is an alias
    // for a type or an alias for a symbol. It is up to the semantic()
    // pass to distinguish.
    // If it is a type, then type is set and getType() will return that
    // type. If it is a symbol, then aliassym is set and type is NULL -
    // toAlias() will return aliasssym.

    Dsymbol *s;

    if (type->ty == Tident)
    {
	TypeIdentifier *ti = (TypeIdentifier *)type;
	Dsymbol *scopesym;
	Identifier *id = (Identifier *)ti->idents.data[0];

	s = sc->search(id, &scopesym);
	if (s)
	{
	    s = s->toAlias();
	    for (int i = 1; i < ti->idents.dim; i++)
	    {
		id = (Identifier *)ti->idents.data[i];
		s = s->search(id, 0);
		if (!s)			// failed to find a symbol
		    goto L1;		// it must be a type
		s = s->toAlias();
	    }
	    goto L2;
	}
    }
    else if (type->ty == Tinstance)
    {
	// Handle forms like:
	//	alias instance TFoo(int).bar.abc def;

	TypeInstance *ti = (TypeInstance *)type;
	Dsymbol *scopesym;

	s = ti->tempinst;
	if (s)
	{
	    s->semantic(sc);
	    s = s->toAlias();
	    if (sc->parent->isFuncDeclaration())
		s->semantic2(sc);

	    for (int i = 0; i < ti->idents.dim; i++)
	    {	Identifier *id;

		id = (Identifier *)ti->idents.data[i];
		s = s->search(id, 0);
		if (!s)			// failed to find a symbol
		    goto L1;		// it must be a type
		s = s->toAlias();
	    }
	    goto L2;
	}
    }
  L1:
    type = type->semantic(loc, sc);
    return;

  L2:
    type = NULL;
    FuncDeclaration *f = s->isFuncDeclaration();
    if (f)
    {
	if (overnext)
	{
	    FuncAliasDeclaration *fa = new FuncAliasDeclaration(f);
	    if (!fa->overloadInsert(overnext))
		ScopeDsymbol::multiplyDefined(f, overnext);
	    overnext = NULL;
	    s = fa;
	}
    }
    if (overnext)
	ScopeDsymbol::multiplyDefined(s, overnext);
    aliassym = s;
}

int AliasDeclaration::overloadInsert(Dsymbol *s)
{
    /* Don't know yet what the aliased symbol is, so assume it can
     * be overloaded and check later for correctness.
     */

    if (overnext == NULL)
    {	overnext = s;
	return TRUE;
    }
    else
    {
	return overnext->overloadInsert(s);
    }
}

char *AliasDeclaration::kind()
{
    return "alias";
}

Type *AliasDeclaration::getType()
{
    return type;
}

Dsymbol *AliasDeclaration::toAlias()
{
    return aliassym ? aliassym->toAlias() : this;
}

void AliasDeclaration::toCBuffer(OutBuffer *buf)
{
    buf->writestring("alias ");
    if (aliassym)
    {
	aliassym->toCBuffer(buf);
	buf->writeByte(' ');
	buf->writestring(ident->toChars());
    }
    else
	type->toCBuffer(buf, ident);
    buf->writeByte(';');
    buf->writenl();
}

/********************************* VarDeclaration ****************************/

VarDeclaration::VarDeclaration(Loc loc, Type *type, Identifier *id, Initializer *init)
    : Declaration(id)
{
    assert(type);
    this->type = type;
    this->init = init;
    this->loc = loc;
    offset = 0;
    noauto = 0;
    nestedref = 0;
}

Dsymbol *VarDeclaration::syntaxCopy(Dsymbol *s)
{
    VarDeclaration *sv;
    if (s)
    {	sv = (VarDeclaration *)s;
    }
    else
    {
	Initializer *init = NULL;
	if (this->init)
	    init = this->init->syntaxCopy();

	sv = new VarDeclaration(loc, type->syntaxCopy(), ident, init);
    }
    return sv;
}

void VarDeclaration::semantic(Scope *sc)
{
    //printf("VarDeclaration::semantic('%s')\n", toChars());
    type = type->semantic(loc, sc);
    linkage = sc->linkage;
    parent = sc->parent;
    //printf("this = %p, parent = %p, '%s'\n", this, parent, parent->toChars());
    protection = sc->protection;
    storage_class |= sc->stc;

    FuncDeclaration *fd = parent->isFuncDeclaration();

    if (type->ty == Tvoid)
	error("voids have no value");

    if (isConst())
    {
    }
    else if (isStatic())
    {
    }
    else if (isSynchronized())
    {
	error("variable %s cannot be synchronized", toChars());
    }
    else
    {
	StructDeclaration *sd = parent->isStructDeclaration();
	if (sd)
	{
	    unsigned memsize;		// size of member
	    unsigned memalignsize;	// size of member for alignment purposes
	    unsigned xalign;		// alignment boundaries

	    memsize = type->size();
	    memalignsize = type->alignsize();
	    xalign = type->memalign(sc->structalign);
	    sd->alignmember(xalign, memalignsize, &sc->offset);
	    offset = sc->offset;
	    sc->offset += memsize;
	    if (sc->offset > sd->structsize)
		sd->structsize = sc->offset;
	    if (sd->alignsize < memalignsize)
		sd->alignsize = memalignsize;

	    storage_class |= STCfield;
	    //printf("1 Adding '%s' to '%s'\n", this->toChars(), sd->toChars());
	    sd->fields.push(this);
	}

	ClassDeclaration *cd = parent->isClassDeclaration();
	if (cd)
	{
	    unsigned memsize;
	    unsigned memalignsize;
	    unsigned xalign;

	    memsize = type->size();
	    memalignsize = type->alignsize();
	    xalign = type->memalign(sc->structalign);
	    cd->alignmember(xalign, memalignsize, &sc->offset);
	    offset = sc->offset;
//printf("offset of '%s' is x%x\n", toChars(), offset);
	    sc->offset += memsize;
	    if (sc->offset > cd->structsize)
		cd->structsize = sc->offset;
	    if (cd->alignsize < memalignsize)
		cd->alignsize = memalignsize;

	    storage_class |= STCfield;
	    //printf("2 Adding '%s' to '%s'\n", this->toChars(), cd->toChars());
	    cd->fields.push(this);
	}

	InterfaceDeclaration *id = parent->isInterfaceDeclaration();
	if (id)
	{
	    error("field not allowed in interface");
	}
    }

    if (type->isauto() && !noauto)
    {
	if (storage_class & (STCfield | STCout | STCstatic) || !fd)
	{
	    error("globals, statics, fields, inout and out parameters cannot be auto");
	}

	if (!(storage_class & STCauto))
	{
	    if (!(storage_class & STCparameter))
		error("reference to auto class must be auto");
	}
    }

    if (!init && !sc->inunion && !isStatic() && !isConst() && fd &&
	!(storage_class & (STCfield | STCparameter | STCforeach)))
    {
	// Provide a default initializer
	//printf("Providing default initializer for '%s'\n", toChars());
	if (type->ty == Tstruct &&
	    ((TypeStruct *)type)->sym->zeroInit == 1)
	{
	    Expression *e = new IntegerExp(loc, 0, Type::tint32);
	    Expression *e1 = new VarExp(loc, this);
	    e = new AssignExp(loc, e1, e);
	    e->type = e1->type;
	    init = new ExpInitializer(loc, e);
	    return;
	}
	else
	{
	    Expression *e = type->defaultInit();
	    if (e)
		init = new ExpInitializer(loc, e);
	}
    }

    // If inside function, there is no semantic3() call
    if (fd && init)
    {
	// If local variable, use AssignExp to handle all the various
	// possibilities.
	if (!isStatic() && !isConst())
	{
	    ExpInitializer *ie;
	    Expression *e1;
	    Type *t;
	    int dim;

	    //printf("fd = '%s', var = '%s'\n", fd->toChars(), toChars());
	    ie = init->isExpInitializer();
	    if (!ie)
	    {
		error("is not a static and cannot have static initializer");
		return;
	    }

	    e1 = new VarExp(loc, this);

	    t = type->toBasetype();
	    if (t->ty == Tsarray)
	    {
		dim = ((TypeSArray *)t)->dim->toInteger();
		// If multidimensional static array, treat as one large array
		while (1)
		{
		    t = t->next->toBasetype();
		    if (t->ty != Tsarray)
			break;
		    dim *= ((TypeSArray *)t)->dim->toInteger();
		    e1->type = new TypeSArray(t->next, new IntegerExp(0, dim, Type::tindex));
		}
		e1 = new ArrayRangeExp(loc, e1, NULL, NULL);
	    }
	    ie->exp = new AssignExp(loc, e1, ie->exp);
	    ie->exp = ie->exp->semantic(sc);
	}
	else
	{
	    init = init->semantic(sc, type);
	}
    }
}

void VarDeclaration::semantic2(Scope *sc)
{
    //printf("VarDeclaration::semantic2('%s')\n", toChars());
    if (init && !sc->parent->isFuncDeclaration())
    {	init = init->semantic(sc, type);
    }
}

char *VarDeclaration::kind()
{
    return "variable";
}

void VarDeclaration::toCBuffer(OutBuffer *buf)
{
    type->toCBuffer(buf, ident);
    if (init)
    {	buf->writestring(" = ");
	init->toCBuffer(buf);
    }
    buf->writeByte(';');
    buf->writenl();
}

int VarDeclaration::needThis()
{
    return storage_class & STCfield;
}

int VarDeclaration::isImportedSymbol()
{
    if (protection == PROTexport && !init && (isStatic() || isConst() || parent->isModule()))
	return TRUE;
    return FALSE;
}

/*******************************
 * Does symbol go into data segment?
 */

int VarDeclaration::isDataseg()
{
    return (storage_class & (STCstatic | STCconst) ||
	   parent->isModule() ||
	   parent->isTemplateInstance());
}

/******************************************
 * If a variable has an auto destructor call, return call for it.
 * Otherwise, return NULL.
 */

Expression *VarDeclaration::callAutoDtor()
{   Expression *e = NULL;

    if (storage_class & STCauto && !noauto)
    {
	ClassDeclaration *cd = type->isClassHandle();
	if (cd && cd->dtor)
	{   FuncDeclaration *fd;
	    Expression *efd;
	    Expression *ec;
	    Array *arguments;

	    fd = FuncDeclaration::genCfunc(Type::tvoid, "_d_callfinalizer");
	    efd = new VarExp(loc, fd);
	    ec = new VarExp(loc, this);
	    arguments = new Array();
	    arguments->push(ec);
	    e = new CallExp(loc, efd, arguments);
	    e->type = fd->type->next;
	}
    }
    return e;
}

/********************************* ClassInfoDeclaration ****************************/

ClassInfoDeclaration::ClassInfoDeclaration(ClassDeclaration *cd)
    : VarDeclaration(0, ClassDeclaration::classinfo->type, cd->ident, NULL)
{
    this->cd = cd;
    storage_class = STCstatic;
}

Dsymbol *ClassInfoDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(0);		// should never be produced by syntax
    return NULL;
}

void ClassInfoDeclaration::semantic(Scope *sc)
{
}

/********************************* ModuleInfoDeclaration ****************************/

ModuleInfoDeclaration::ModuleInfoDeclaration(Module *mod)
    : VarDeclaration(0, Module::moduleinfo->type, mod->ident, NULL)
{
    this->mod = mod;
    storage_class = STCstatic;
}

Dsymbol *ModuleInfoDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(0);		// should never be produced by syntax
    return NULL;
}

void ModuleInfoDeclaration::semantic(Scope *sc)
{
}

/********************************* TypeInfoDeclaration ****************************/

TypeInfoDeclaration::TypeInfoDeclaration(Type *tinfo)
    : VarDeclaration(0, Type::typeinfo->type, tinfo->getTypeInfoIdent(), NULL)
{
    this->tinfo = tinfo;
    storage_class = STCstatic;
    protection = PROTpublic;
    linkage = LINKc;
}

Dsymbol *TypeInfoDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(0);		// should never be produced by syntax
    return NULL;
}

void TypeInfoDeclaration::semantic(Scope *sc)
{
}

/********************************* ThisDeclaration ****************************/

// For the "this" parameter to member functions

ThisDeclaration::ThisDeclaration(Type *t)
   : VarDeclaration(0, t, Id::This, NULL)
{
    noauto = 1;
}

Dsymbol *ThisDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(0);		// should never be produced by syntax
    return NULL;
}


