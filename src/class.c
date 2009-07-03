
// Copyright (c) 1999-2006 by Digital Mars
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
#include "init.h"
#include "attrib.h"
#include "declaration.h"
#include "aggregate.h"
#include "id.h"
#include "mtype.h"
#include "scope.h"
#include "module.h"
#include "expression.h"
#include "statement.h"

/********************************* ClassDeclaration ****************************/

ClassDeclaration *ClassDeclaration::classinfo;
ClassDeclaration *ClassDeclaration::object;

ClassDeclaration::ClassDeclaration(Loc loc, Identifier *id, BaseClasses *baseclasses)
    : AggregateDeclaration(loc, id)
{
    static char msg[] = "only object.d can define this reserved class name";

    if (baseclasses)
	this->baseclasses = *baseclasses;
    baseClass = NULL;

    interfaces_dim = 0;
    interfaces = NULL;

    vtblInterfaces = NULL;

    //printf("ClassDeclaration(%s), dim = %d\n", id->toChars(), this->baseclasses.dim);

    // For forward references
    type = new TypeClass(this);
    handle = type;

    ctor = NULL;
    dtor = NULL;
    staticCtor = NULL;
    staticDtor = NULL;

    vtblsym = NULL;
    vclassinfo = NULL;

    if (id)
    {	// Look for special class names

	if (id == Id::__sizeof || id == Id::alignof || id == Id::mangleof)
	    error("illegal class name");

	// BUG: What if this is the wrong TypeInfo, i.e. it is nested?
	if (id->toChars()[0] == 'T')
	{
	    if (id == Id::TypeInfo)
	    {	if (Type::typeinfo)
		    Type::typeinfo->error(msg);
		Type::typeinfo = this;
	    }

	    if (id == Id::TypeInfo_Class)
	    {	if (Type::typeinfoclass)
		    Type::typeinfoclass->error(msg);
		Type::typeinfoclass = this;
	    }

	    if (id == Id::TypeInfo_Struct)
	    {	if (Type::typeinfostruct)
		    Type::typeinfostruct->error(msg);
		Type::typeinfostruct = this;
	    }

	    if (id == Id::TypeInfo_Typedef)
	    {	if (Type::typeinfotypedef)
		    Type::typeinfotypedef->error(msg);
		Type::typeinfotypedef = this;
	    }

	    if (id == Id::TypeInfo_Pointer)
	    {	if (Type::typeinfopointer)
		    Type::typeinfopointer->error(msg);
		Type::typeinfopointer = this;
	    }

	    if (id == Id::TypeInfo_Array)
	    {	if (Type::typeinfoarray)
		    Type::typeinfoarray->error(msg);
		Type::typeinfoarray = this;
	    }

	    if (id == Id::TypeInfo_StaticArray)
	    {	//if (Type::typeinfostaticarray)
		    //Type::typeinfostaticarray->error(msg);
		Type::typeinfostaticarray = this;
	    }

	    if (id == Id::TypeInfo_AssociativeArray)
	    {	if (Type::typeinfoassociativearray)
		    Type::typeinfoassociativearray->error(msg);
		Type::typeinfoassociativearray = this;
	    }

	    if (id == Id::TypeInfo_Enum)
	    {	if (Type::typeinfoenum)
		    Type::typeinfoenum->error(msg);
		Type::typeinfoenum = this;
	    }

	    if (id == Id::TypeInfo_Function)
	    {	if (Type::typeinfofunction)
		    Type::typeinfofunction->error(msg);
		Type::typeinfofunction = this;
	    }

	    if (id == Id::TypeInfo_Delegate)
	    {	if (Type::typeinfodelegate)
		    Type::typeinfodelegate->error(msg);
		Type::typeinfodelegate = this;
	    }
	}

	if (id == Id::Object)
	{   if (object)
		object->error(msg);
	    object = this;
	}

	if (id == Id::ClassInfo)
	{   if (classinfo)
		classinfo->error(msg);
	    classinfo = this;
	}

	if (id == Id::ModuleInfo)
	{   if (Module::moduleinfo)
		Module::moduleinfo->error(msg);
	    Module::moduleinfo = this;
	}
    }

    com = 0;
#if 0
    if (id == Id::IUnknown)		// IUnknown is the root of all COM objects
	com = 1;
#endif
    isauto = 0;
    isabstract = 0;
    isnested = 0;
    vthis = NULL;
}

Dsymbol *ClassDeclaration::syntaxCopy(Dsymbol *s)
{
    ClassDeclaration *cd;

    //printf("ClassDeclaration::syntaxCopy('%s')\n", toChars());
    if (s)
	cd = (ClassDeclaration *)s;
    else
	cd = new ClassDeclaration(loc, ident, NULL);

    cd->storage_class |= storage_class;

    cd->baseclasses.setDim(this->baseclasses.dim);
    for (int i = 0; i < cd->baseclasses.dim; i++)
    {
	BaseClass *b = (BaseClass *)this->baseclasses.data[i];
	BaseClass *b2 = new BaseClass(b->type->syntaxCopy(), b->protection);
	cd->baseclasses.data[i] = b2;
    }

    ScopeDsymbol::syntaxCopy(cd);
    return cd;
}

void ClassDeclaration::semantic(Scope *sc)
{   int i;
    unsigned offset;

    //printf("ClassDeclaration::semantic(%s), type = %p, sizeok = %d, this = %p\n", toChars(), type, sizeok, this);
    //printf("\tparent = %p, '%s'\n", sc->parent, sc->parent ? sc->parent->toChars() : "");
    //printf("sc->stc = %x\n", sc->stc);

    //{ static int n;  if (++n == 20) *(char*)0=0; }

    if (!ident)		// if anonymous class
    {	char *id = "__anonclass";

	ident = Identifier::generateId(id);
    }

    if (!scope)
    {
	if (!parent && sc->parent && !sc->parent->isModule())
	    parent = sc->parent;

	type = type->semantic(loc, sc);
	handle = handle->semantic(loc, sc);
    }
    if (!members)			// if forward reference
    {	//printf("\tclass '%s' is forward referenced\n", toChars());
	return;
    }
    if (symtab)
    {	if (!scope)
	{   //printf("\tsemantic for '%s' is already completed\n", toChars());
	    return;		// semantic() already completed
	}
    }
    else
	symtab = new DsymbolTable();

    Scope *scx = NULL;
    if (scope)
    {	sc = scope;
	scx = scope;		// save so we don't make redundant copies
	scope = NULL;
    }
#ifdef IN_GCC
    methods.setDim(0);
#endif

    // See if there's a base class as first in baseclasses[]
    if (baseclasses.dim)
    {	TypeClass *tc;
	BaseClass *b;
	Type *tb;

	b = (BaseClass *)baseclasses.data[0];
	b->type = b->type->semantic(loc, sc);
	tb = b->type->toBasetype();
	if (tb->ty != Tclass)
	{   error("base type must be class or interface, not %s", b->type->toChars());
	    baseclasses.remove(0);
	}
	else
	{
	    tc = (TypeClass *)(tb);
	    if (tc->sym->isInterfaceDeclaration())
		;
	    else
	    {
		for (ClassDeclaration *cdb = tc->sym; cdb; cdb = cdb->baseClass)
		{
		    if (cdb == this)
		    {
			error("circular inheritance");
			baseclasses.remove(0);
			goto L7;
		    }
		}
		if (!tc->sym->symtab || tc->sym->scope || tc->sym->sizeok == 0)
		{
		    //error("forward reference of base class %s", baseClass->toChars());
		    // Forward reference of base class, try again later
		    //printf("\ttry later, forward reference of base class %s\n", tc->sym->toChars());
		    scope = scx ? scx : new Scope(*sc);
		    scope->setNoFree();
		    scope->module->addDeferredSemantic(this);
		    return;
		}
		else
		{   baseClass = tc->sym;
		    b->base = baseClass;
		}
	     L7: ;
	    }
	}
    }

    // Treat the remaining entries in baseclasses as interfaces
    // Check for errors, handle forward references
    for (i = (baseClass ? 1 : 0); i < baseclasses.dim; )
    {	TypeClass *tc;
	BaseClass *b;
	Type *tb;

	b = (BaseClass *)baseclasses.data[i];
	b->type = b->type->semantic(loc, sc);
	tb = b->type->toBasetype();
	if (tb->ty == Tclass)
	    tc = (TypeClass *)tb;
	else
	    tc = NULL;
	if (!tc || !tc->sym->isInterfaceDeclaration())
	{
	    error("base type must be interface, not %s", b->type->toChars());
	    baseclasses.remove(i);
	    continue;
	}
	else
	{
	    b->base = tc->sym;
	    if (!b->base->symtab || b->base->scope)
	    {
		//error("forward reference of base class %s", baseClass->toChars());
		// Forward reference of base, try again later
		//printf("\ttry later, forward reference of base %s\n", baseClass->toChars());
		scope = scx ? scx : new Scope(*sc);
		scope->setNoFree();
		scope->module->addDeferredSemantic(this);
		return;
	    }
	}
	i++;
    }


    // If no base class, and this is not an Object, use Object as base class
    if (!baseClass && ident != Id::Object)
    {
	// BUG: what if Object is redefined in an inner scope?
	Type *tbase = new TypeIdentifier(0, Id::Object);
	BaseClass *b;
	TypeClass *tc;
	Type *bt;

	if (!object)
	{
	    error("missing or corrupt object.d");
	    fatal();
	}
	bt = tbase->semantic(loc, sc)->toBasetype();
	b = new BaseClass(bt, PROTpublic);
	baseclasses.shift(b);
	assert(b->type->ty == Tclass);
	tc = (TypeClass *)(b->type);
	baseClass = tc->sym;
	assert(!baseClass->isInterfaceDeclaration());
	b->base = baseClass;
    }

    interfaces_dim = baseclasses.dim;
    interfaces = (BaseClass **)baseclasses.data;


    if (baseClass)
    {
	interfaces_dim--;
	interfaces++;

	// Copy vtbl[] from base class
	vtbl.setDim(baseClass->vtbl.dim);
	memcpy(vtbl.data, baseClass->vtbl.data, sizeof(void *) * vtbl.dim);

	// Inherit properties from base class
	com = baseClass->isCOMclass();
	isauto = baseClass->isauto;
	vthis = baseClass->vthis;
    }
    else
    {
	// No base class, so this is the root of the class heirarchy
	vtbl.setDim(0);
	vtbl.push(this);		// leave room for classinfo as first member
    }

    protection = sc->protection;
    storage_class |= sc->stc;

    if (sizeok == 0)
    {
	interfaceSemantic(sc);

	for (i = 0; i < members->dim; i++)
	{
	    Dsymbol *s = (Dsymbol *)members->data[i];
	    s->addMember(sc, this, 1);
	}

	/* If this is a nested class, add the hidden 'this'
	 * member which is a pointer to the enclosing scope.
	 */
	if (vthis)		// if inheriting from nested class
	{   // Use the base class's 'this' member
	    isnested = 1;
	    if (storage_class & STCstatic)
		error("static class cannot inherit from nested class %s", baseClass->toChars());
	    if (toParent() != baseClass->toParent())
		error("super class %s is nested within %s, not %s",
			baseClass->toChars(),
			baseClass->toParent()->toChars(),
			toParent()->toChars());
	}
	else if (!(storage_class & STCstatic))
	{   Dsymbol *s = toParent();
	    if (s)
	    {
		ClassDeclaration *cd = s->isClassDeclaration();
		FuncDeclaration *fd = s->isFuncDeclaration();


		if (cd || fd)
		{   isnested = 1;
		    Type *t;
		    if (cd)
			t = cd->type;
		    else if (fd)
		    {   t = new TypePointer(Type::tvoid);
			t = t->semantic(0, sc);
		    }
		    else
			assert(0);
		    assert(!vthis);
		    vthis = new ThisDeclaration(t);
		    members->push(vthis);
		}
	    }
	}
    }

    if (storage_class & STCauto)
	isauto = 1;
    if (storage_class & STCabstract)
	isabstract = 1;
    if (storage_class & STCdeprecated)
	isdeprecated = 1;

    sc = sc->push(this);
    sc->stc &= ~(STCauto | STCstatic | STCabstract | STCdeprecated);
    sc->parent = this;
    sc->inunion = 0;

    if (isCOMclass())
	sc->linkage = LINKwindows;
    sc->protection = PROTpublic;
    sc->structalign = 8;
    structalign = sc->structalign;
    if (baseClass)
    {	sc->offset = baseClass->structsize;
	alignsize = baseClass->alignsize;
//	if (isnested)
//	    sc->offset += PTRSIZE;	// room for uplevel context pointer
    }
    else
    {	sc->offset = 8;		// allow room for vptr[] and monitor
	alignsize = 4;
    }
    structsize = sc->offset;
    Scope scsave = *sc;
    int members_dim = members->dim;
    sizeok = 0;
    for (i = 0; i < members_dim; i++)
    {
	Dsymbol *s = (Dsymbol *)members->data[i];
	s->semantic(sc);
    }

    if (sizeok == 2)
    {	// semantic() failed because of forward references.
	// Unwind what we did, and defer it for later
	fields.setDim(0);
	structsize = 0;
	alignsize = 0;
	structalign = 0;

	sc->pop();

	scope = scx ? scx : new Scope(*sc);
	scope->setNoFree();
	scope->module->addDeferredSemantic(this);

	//printf("\tsemantic('%s') failed\n", toChars());
	return;
    }

    //printf("\tsemantic('%s') successful\n", toChars());

    structsize = sc->offset;
    //members->print();

    /* Look for special member functions.
     * They must be in this class, not in a base class.
     */
    ctor = (CtorDeclaration *)search(Id::ctor, 0);
    if (ctor && ctor->toParent() != this)
	ctor = NULL;

    dtor = (DtorDeclaration *)search(Id::dtor, 0);
    if (dtor && dtor->toParent() != this)
	dtor = NULL;

//    inv = (InvariantDeclaration *)search(Id::classInvariant, 0);
//    if (inv && inv->toParent() != this)
//	inv = NULL;

    // Can be in base class
    aggNew    = (NewDeclaration *)search(Id::classNew, 0);
    aggDelete = (DeleteDeclaration *)search(Id::classDelete, 0);

    // If this class has no constructor, but base class does, create
    // a constructor:
    //    this() { }
    if (!ctor && baseClass && baseClass->ctor)
    {
	//printf("Creating default this(){} for class %s\n", toChars());
	ctor = new CtorDeclaration(0, 0, NULL, 0);
	ctor->fbody = new CompoundStatement(0, new Statements());
	members->push(ctor);
	ctor->addMember(sc, this, 1);
	*sc = scsave;
	sc->offset = structsize;
	ctor->semantic(sc);
    }

#if 0
    if (baseClass)
    {	if (!aggDelete)
	    aggDelete = baseClass->aggDelete;
	if (!aggNew)
	    aggNew = baseClass->aggNew;
    }
#endif

    // Allocate instance of each new interface
    for (i = 0; i < vtblInterfaces->dim; i++)
    {
	BaseClass *b = (BaseClass *)vtblInterfaces->data[i];
	unsigned thissize = PTRSIZE;

	alignmember(structalign, thissize, &sc->offset);
	assert(b->offset == 0);
	b->offset = sc->offset;

	// Take care of single inheritance offsets
	while (b->baseInterfaces_dim)
	{
	    b = &b->baseInterfaces[0];
	    b->offset = sc->offset;
	}

	sc->offset += thissize;
	if (alignsize < thissize)
	    alignsize = thissize;
    }
    structsize = sc->offset;
    sizeok = 1;
    Module::dprogress++;


    sc->pop();

#if 0 // Do not call until toObjfile() because of forward references
    // Fill in base class vtbl[]s
    for (i = 0; i < vtblInterfaces->dim; i++)
    {
	BaseClass *b = (BaseClass *)vtblInterfaces->data[i];

	//b->fillVtbl(this, &b->vtbl, 1);
    }
#endif
    //printf("-ClassDeclaration::semantic(%s), type = %p\n", toChars(), type);
}

void ClassDeclaration::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    if (!isAnonymous())
    {
	buf->printf("%s ", kind());
	buf->writestring(toChars());
	if (baseclasses.dim)
	    buf->writestring(" : ");
    }
    for (int i = 0; i < baseclasses.dim; i++)
    {
	BaseClass *b = (BaseClass *)baseclasses.data[i];

	if (i)
	    buf->writeByte(',');
	//buf->writestring(b->base->ident->toChars());
	b->type->toCBuffer(buf, NULL, hgs);
    }
    buf->writenl();
    buf->writeByte('{');
    buf->writenl();
    for (int i = 0; i < members->dim; i++)
    {
	Dsymbol *s = (Dsymbol *)members->data[i];

	buf->writestring("    ");
	s->toCBuffer(buf, hgs);
    }
    buf->writestring("}");
    buf->writenl();
}

#if 0
void ClassDeclaration::defineRef(Dsymbol *s)
{
    ClassDeclaration *cd;

    AggregateDeclaration::defineRef(s);
    cd = s->isClassDeclaration();
    baseType = cd->baseType;
    cd->baseType = NULL;
}
#endif

/*********************************************
 * Determine if 'this' is a base class of cd.
 * This is used to detect circular inheritance only.
 */

int ClassDeclaration::isBaseOf2(ClassDeclaration *cd)
{
    if (!cd)
	return 0;
    //printf("ClassDeclaration::isBaseOf2(this = '%s', cd = '%s')\n", toChars(), cd->toChars());
    for (int i = 0; i < cd->baseclasses.dim; i++)
    {	BaseClass *b = (BaseClass *)cd->baseclasses.data[i];

	if (b->base == this || isBaseOf2(b->base))
	    return 1;
    }
    return 0;
}

/*******************************************
 * Determine if 'this' is a base class of cd.
 */

int ClassDeclaration::isBaseOf(ClassDeclaration *cd, int *poffset)
{
    //printf("ClassDeclaration::isBaseOf(this = '%s', cd = '%s')\n", toChars(), cd->toChars());
    if (poffset)
	*poffset = 0;
    while (cd)
    {
	if (this == cd->baseClass)
	    return 1;

	/* cd->baseClass might not be set if cd is forward referenced.
	 */
	if (!cd->baseClass && cd->baseclasses.dim && !cd->isInterfaceDeclaration())
	{
	    cd->error("base class is forward referenced by %s", toChars());
	}

	cd = cd->baseClass;
    }
    return 0;
}

Dsymbol *ClassDeclaration::search(Identifier *ident, int flags)
{
    Dsymbol *s;

    //printf("%s.ClassDeclaration::search('%s')\n", toChars(), ident->toChars());
    if (scope)
	semantic(scope);

    if (!members || !symtab || scope)
    {	error("is forward referenced when looking for '%s'", ident->toChars());
	//*(char*)0=0;
	return NULL;
    }

    s = ScopeDsymbol::search(ident, flags);
    if (!s)
    {
	// Search bases classes in depth-first, left to right order

	int i;

	for (i = 0; i < baseclasses.dim; i++)
	{
	    BaseClass *b = (BaseClass *)baseclasses.data[i];

	    if (b->base)
	    {
		if (!b->base->symtab)
		    error("base %s is forward referenced", b->base->ident->toChars());
		else
		{
		    s = b->base->search(ident, flags);
		    if (s == this)	// happens if s is nested in this and derives from this
			s = NULL;
		    else if (s)
			break;
		}
	    }
	}
    }
    return s;
}

/****************
 * Find virtual function matching identifier and type.
 * Used to build virtual function tables for interface implementations.
 */

FuncDeclaration *ClassDeclaration::findFunc(Identifier *ident, TypeFunction *tf)
{
    //printf("ClassDeclaration::findFunc(%s, %s) %s\n", ident->toChars(), tf->toChars(), toChars());

    for (size_t i = 0; i < vtbl.dim; i++)
    {
	FuncDeclaration *fd = (FuncDeclaration *)vtbl.data[i];

	//printf("\t[%d] = %s\n", i, fd->toChars());
	if (ident == fd->ident &&
	    //tf->equals(fd->type)
	    fd->type->covariant(tf) == 1
	   )
	{   //printf("\t\tfound\n");
	    return fd;
	}
	//else printf("\t\t%d\n", fd->type->covariant(tf));
    }

    return NULL;
}

void ClassDeclaration::interfaceSemantic(Scope *sc)
{   int i;

    vtblInterfaces = new BaseClasses();
    vtblInterfaces->reserve(interfaces_dim);

    for (i = 0; i < interfaces_dim; i++)
    {
	BaseClass *b = interfaces[i];

	// If this is an interface, and it derives from a COM interface,
	// then this is a COM interface too.
	if (b->base->isCOMclass())
	    com = 1;

	vtblInterfaces->push(b);
	b->copyBaseInterfaces(vtblInterfaces);
    }
}

/****************************************
 */

int ClassDeclaration::isCOMclass()
{
    return com;
}


/****************************************
 */

int ClassDeclaration::isAbstract()
{
    if (isabstract)
	return TRUE;
    for (int i = 1; i < vtbl.dim; i++)
    {
	FuncDeclaration *fd = ((Dsymbol *)vtbl.data[i])->isFuncDeclaration();

	//printf("\tvtbl[%d] = %p\n", i, fd);
	if (!fd || fd->isAbstract())
	{
	    isabstract |= 1;
	    return TRUE;
	}
    }
    return FALSE;
}

/****************************************
 * Returns !=0 if there's an extra member which is the 'this'
 * pointer to the enclosing context (enclosing class or function)
 */

int ClassDeclaration::isNested()
{
    return isnested;
}

/****************************************
 * Determine if slot 0 of the vtbl[] is reserved for something else.
 * For class objects, yes, this is where the classinfo ptr goes.
 * For COM interfaces, no.
 * For non-COM interfaces, yes, this is where the Interface ptr goes.
 */

int ClassDeclaration::vtblOffset()
{
    return 1;
}

/****************************************
 */

char *ClassDeclaration::kind()
{
    return "class";
}

/****************************************
 */

void ClassDeclaration::addLocalClass(ClassDeclarations *aclasses)
{
    aclasses->push(this);
}

/********************************* InterfaceDeclaration ****************************/

InterfaceDeclaration::InterfaceDeclaration(Loc loc, Identifier *id, BaseClasses *baseclasses)
    : ClassDeclaration(loc, id, baseclasses)
{
    com = 0;
    if (id == Id::IUnknown)		// IUnknown is the root of all COM objects
	com = 1;
}

Dsymbol *InterfaceDeclaration::syntaxCopy(Dsymbol *s)
{
    InterfaceDeclaration *id;

    if (s)
	id = (InterfaceDeclaration *)s;
    else
	id = new InterfaceDeclaration(loc, ident, NULL);

    ClassDeclaration::syntaxCopy(id);
    return id;
}

void InterfaceDeclaration::semantic(Scope *sc)
{   int i;

    //printf("InterfaceDeclaration::semantic(%s), type = %p\n", toChars(), type);
    if (!scope)
    {	type = type->semantic(loc, sc);
	handle = handle->semantic(loc, sc);
    }
    if (!members)			// if forward reference
    {	//printf("\tinterface '%s' is forward referenced\n", toChars());
	return;
    }
    if (symtab)			// if already done
    {	if (!scope)
	    return;
    }
    else
	symtab = new DsymbolTable();

    Scope *scx = NULL;
    if (scope)
    {	sc = scope;
	scx = scope;		// save so we don't make redundant copies
	scope = NULL;
    }

    // Check for errors, handle forward references
    for (i = 0; i < baseclasses.dim; )
    {	TypeClass *tc;
	BaseClass *b;
	Type *tb;

	b = (BaseClass *)baseclasses.data[i];
	b->type = b->type->semantic(loc, sc);
	tb = b->type->toBasetype();
	if (tb->ty == Tclass)
	    tc = (TypeClass *)tb;
	else
	    tc = NULL;
	if (!tc || !tc->sym->isInterfaceDeclaration())
	{
	    //error("base type must be interface, not %s", b->type->toChars());
	    baseclasses.remove(i);
	    continue;
	}
	else
	{
	    b->base = tc->sym;
	    if (b->base == this || isBaseOf2(b->base))
	    {
		error("circular inheritance of interface");
		baseclasses.remove(i);
		continue;
	    }
	    if (!b->base->symtab || b->base->scope)
	    {
		//error("forward reference of base class %s", baseClass->toChars());
		// Forward reference of base, try again later
		//printf("\ttry later, forward reference of base %s\n", b->base->toChars());
		scope = scx ? scx : new Scope(*sc);
		scope->setNoFree();
		scope->module->addDeferredSemantic(this);
		return;
	    }
	}
	i++;
    }

    interfaces_dim = baseclasses.dim;
    interfaces = (BaseClass **)baseclasses.data;

    interfaceSemantic(sc);

    if (vtblOffset())
	vtbl.push(this);		// leave room at vtbl[0] for classinfo

    // Cat together the vtbl[]'s from base interfaces
    for (i = 0; i < interfaces_dim; i++)
    {	BaseClass *b = interfaces[i];

	// Skip if b has already appeared
	for (int k = 0; k < i; k++)
	{
	    if (b == interfaces[i])
		goto Lcontinue;
	}

	// Copy vtbl[] from base class
	if (b->base->vtblOffset())
	{   int d = b->base->vtbl.dim;
	    if (d > 1)
	    {
		vtbl.reserve(d - 1);
		for (int j = 1; j < d; j++)
		    vtbl.push(b->base->vtbl.data[j]);
	    }
	}
	else
	{
	    vtbl.append(&b->base->vtbl);
	}

      Lcontinue:
	;
    }

    for (i = 0; i < members->dim; i++)
    {
	Dsymbol *s = (Dsymbol *)members->data[i];
	s->addMember(sc, this, 1);
    }

    sc = sc->push(this);
    sc->parent = this;
    if (isCOMclass())
	sc->linkage = LINKwindows;
    sc->structalign = 8;
    structalign = sc->structalign;
    sc->offset = 8;
    for (i = 0; i < members->dim; i++)
    {
	Dsymbol *s = (Dsymbol *)members->data[i];
	s->semantic(sc);
    }
    //members->print();
    sc->pop();
    //printf("-InterfaceDeclaration::semantic(%s), type = %p\n", toChars(), type);
}


/*******************************************
 * Determine if 'this' is a base class of cd.
 * (Actually, if it is an interface supported by cd)
 * Output:
 *	*poffset	offset to start of class
 *			OFFSET_RUNTIME	must determine offset at runtime
 * Returns:
 *	0	not a base
 *	1	is a base
 */

int InterfaceDeclaration::isBaseOf(ClassDeclaration *cd, int *poffset)
{
    unsigned j;

    //printf("%s.InterfaceDeclaration::isBaseOf(cd = '%s')\n", toChars(), cd->toChars());
    assert(!baseClass);
    for (j = 0; j < cd->interfaces_dim; j++)
    {
	BaseClass *b = cd->interfaces[j];

	//printf("\tbase %s\n", b->base->toChars());
	if (this == b->base)
	{
	    //printf("\tfound at offset %d\n", b->offset);
	    if (poffset)
	    {	*poffset = b->offset;
		if (j && cd->isInterfaceDeclaration())
		    *poffset = OFFSET_RUNTIME;
	    }
	    return 1;
	}
	if (isBaseOf(b, poffset))
	{   if (j && poffset && cd->isInterfaceDeclaration())
		*poffset = OFFSET_RUNTIME;
	    return 1;
	}
    }

    if (cd->baseClass && isBaseOf(cd->baseClass, poffset))
	return 1;

    if (poffset)
	*poffset = 0;
    return 0;
}


int InterfaceDeclaration::isBaseOf(BaseClass *bc, int *poffset)
{
    //printf("%s.InterfaceDeclaration::isBaseOf(bc = '%s')\n", toChars(), bc->base->toChars());
    for (unsigned j = 0; j < bc->baseInterfaces_dim; j++)
    {
	BaseClass *b = &bc->baseInterfaces[j];

	if (this == b->base)
	{
	    if (poffset)
	    {	*poffset = b->offset;
	    }
	    return 1;
	}
	if (isBaseOf(b, poffset))
	{
	    return 1;
	}
    }
    if (poffset)
	*poffset = 0;
    return 0;
}

/****************************************
 * Determine if slot 0 of the vtbl[] is reserved for something else.
 * For class objects, yes, this is where the classinfo ptr goes.
 * For COM interfaces, no.
 * For non-COM interfaces, yes, this is where the Interface ptr goes.
 */

int InterfaceDeclaration::vtblOffset()
{
    if (isCOMclass())
	return 0;
    return 1;
}

/*******************************************
 */

char *InterfaceDeclaration::kind()
{
    return "interface";
}


/******************************** BaseClass *****************************/

BaseClass::BaseClass()
{
    memset(this, 0, sizeof(BaseClass));
}

BaseClass::BaseClass(Type *type, enum PROT protection)
{
    //printf("BaseClass(this = %p, '%s')\n", this, type->toChars());
    this->type = type;
    this->protection = protection;
    base = NULL;
    offset = 0;

    baseInterfaces_dim = 0;
    baseInterfaces = NULL;
}

/****************************************
 * Fill in vtbl[] for base class based on member functions of class cd.
 * Input:
 *	vtbl		if !=NULL, fill it in
 *	newinstance	!=0 means all entries must be filled in by members
 *			of cd, not members of any base classes of cd.
 * Returns:
 *	!=0 if any entries were filled in by members of cd (not exclusively
 *	by base classes)
 */

int BaseClass::fillVtbl(ClassDeclaration *cd, Array *vtbl, int newinstance)
{
    ClassDeclaration *id = base;
    int j;
    int result = 0;

    //printf("BaseClass::fillVtbl(this='%s', cd='%s')\n", base->toChars(), cd->toChars());
    if (vtbl)
	vtbl->setDim(base->vtbl.dim);

    // first entry is ClassInfo reference
    for (j = base->vtblOffset(); j < base->vtbl.dim; j++)
    {
	FuncDeclaration *ifd = ((Dsymbol *)base->vtbl.data[j])->isFuncDeclaration();
	FuncDeclaration *fd;
	TypeFunction *tf;

	//printf("        vtbl[%d] is '%s'\n", j, ifd ? ifd->toChars() : "null");

	assert(ifd);
	// Find corresponding function in this class
	tf = (ifd->type->ty == Tfunction) ? (TypeFunction *)(ifd->type) : NULL;
	fd = cd->findFunc(ifd->ident, tf);
	if (fd && !fd->isAbstract())
	{
	    //printf("            found\n");
	    // Check that calling conventions match
	    if (fd->linkage != ifd->linkage)
		fd->error("linkage doesn't match interface function");

	    // Check that it is current
	    if (newinstance &&
		fd->toParent() != cd &&
		ifd->toParent() == base)
		cd->error("interface function %s.%s is not implemented",
		    id->toChars(), ifd->ident->toChars());

	    if (fd->toParent() == cd)
		result = 1;
	}
	else
	{
	    //printf("            not found\n");
	    // BUG: should mark this class as abstract?
	    if (!cd->isAbstract())
		cd->error("interface function %s.%s isn't implemented",
		    id->toChars(), ifd->ident->toChars());
	    fd = NULL;
	}
	if (vtbl)
	    vtbl->data[j] = fd;
    }

    return result;
}

void BaseClass::copyBaseInterfaces(BaseClasses *vtblInterfaces)
{
    //printf("+copyBaseInterfaces(), %s\n", base->toChars());
//    if (baseInterfaces_dim)
//	return;

    baseInterfaces_dim = base->interfaces_dim;
    baseInterfaces = (BaseClass *)mem.calloc(baseInterfaces_dim, sizeof(BaseClass));

    //printf("%s.copyBaseInterfaces()\n", base->toChars());
    for (int i = 0; i < baseInterfaces_dim; i++)
    {
	BaseClass *b = &baseInterfaces[i];
	BaseClass *b2 = base->interfaces[i];

	assert(b2->vtbl.dim == 0);	// should not be filled yet
	memcpy(b, b2, sizeof(BaseClass));

	if (i)				// single inheritance is i==0
	    vtblInterfaces->push(b);	// only need for M.I.
	b->copyBaseInterfaces(vtblInterfaces);
    }
    //printf("-copyBaseInterfaces\n");
}
