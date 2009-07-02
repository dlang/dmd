

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

/********************************* ClassDeclaration ****************************/

ClassDeclaration *ClassDeclaration::classinfo;

ClassDeclaration::ClassDeclaration(Identifier *id, Array *baseclasses)
    : AggregateDeclaration(id)
{
    if (baseclasses)
	this->baseclasses = *baseclasses;
    baseClass = NULL;

    interfaces_dim = 0;
    interfaces = NULL;

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

    // BUG: What if this is the wrong ClassInfo, i.e. it is nested?
    if (!classinfo && id == Id::ClassInfo)
	classinfo = this;

    // BUG: What if this is the wrong ModuleInfo, i.e. it is nested?
    if (!Module::moduleinfo && id == Id::ModuleInfo)
	Module::moduleinfo = this;

    // BUG: What if this is the wrong TypeInfo, i.e. it is nested?
    if (!Type::typeinfo && id == Id::TypeInfo)
	Type::typeinfo = this;

    com = 0;
#if 0
    if (id == Id::IUnknown)		// IUnknown is the root of all COM objects
	com = 1;
#endif
    isauto = 0;
}

Dsymbol *ClassDeclaration::syntaxCopy(Dsymbol *s)
{
    ClassDeclaration *cd;

    //printf("ClassDeclaration::syntaxCopy('%s')\n", toChars());
    if (s)
	cd = (ClassDeclaration *)s;
    else
	cd = new ClassDeclaration(ident, NULL);

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

    //printf("ClassDeclaration::semantic(%s), type = %p\n", toChars(), type);
    type = type->semantic(loc, sc);
    handle = handle->semantic(loc, sc);
    if (!members)			// if forward reference
    {	//printf("\tclass '%s' is forward referenced\n", toChars());
	return;
    }
    if (symtab)			// if already done
	return;

    symtab = new DsymbolTable();

    // See if base class is in baseclasses[]
    if (baseclasses.dim)
    {	TypeClass *tc;
	BaseClass *b;

	b = (BaseClass *)baseclasses.data[0];
	b->type = b->type->semantic(loc, sc);
	tc = dynamic_cast<TypeClass *>(b->type->toBasetype());
	if (!tc)
	    error("base type must be class or interface, not %s", b->type->toChars());
	else if (tc->sym->isInterface())
	     ;
	else
	{   baseClass = tc->sym;
	    b->base = baseClass;
	    if (!baseClass->symtab)
		error("forward reference of base class %s", baseClass->toChars());
	}
    }

    // If no base class, and this is not an Object, use Object as base class
    if (!baseClass && ident != Id::Object)
    {
	// BUG: what if Object is redefined in an inner scope?
	Type *tbase = new TypeIdentifier(0, Id::Object);
	BaseClass *b;
	TypeClass *tc;
	Type *bt;

	bt = tbase->semantic(loc, sc)->toBasetype();
	b = new BaseClass(bt, PROTpublic);
	baseclasses.shift(b);
	tc = dynamic_cast<TypeClass *>(b->type);
	assert(tc);
	baseClass = tc->sym;
	assert(!baseClass->isInterface());
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
    }
    else
    {
	// No base class, so this is the root of the class heirarchy
	vtbl.push(this);		// leave room for classinfo as first member
    }

    if (sc->stc & STCauto)
	isauto = 1;

    interfaceSemantic(sc);

    sc = sc->push(this);
    sc->stc &= ~(STCauto | STCstatic);

    for (i = 0; i < members->dim; i++)
    {
	Dsymbol *s = (Dsymbol *)members->data[i];
	s->addMember(this);
    }

    if (isCOMclass())
	sc->linkage = LINKwindows;
    sc->protection = PROTpublic;
    sc->structalign = 8;
    structalign = sc->structalign;
    if (baseClass)
    {	sc->offset = baseClass->structsize;
	alignsize = baseClass->alignsize;
    }
    else
    {	sc->offset = 8;		// allow room for vptr[] and monitor
	alignsize = 4;
    }
    structsize = sc->offset;
    for (i = 0; i < members->dim; i++)
    {
	Dsymbol *s = (Dsymbol *)members->data[i];
	s->semantic(sc);
    }
    //members->print();

    // If this class has no constructor, but base class does, create
    // a constructor:
    //    this() { }
    if (!ctor && baseClass && baseClass->ctor)
    {
	//printf("Creating default this(){} for class %s\n", toChars());
	ctor = new CtorDeclaration(0, 0, NULL, 0);
	ctor->fbody = new CompoundStatement(0, new Array());
	members->push(ctor);
	ctor->addMember(this);
	ctor->semantic(sc);
    }

    if (baseClass)
    {	if (!aggDelete)
	    aggDelete = baseClass->aggDelete;
	if (!aggNew)
	    aggNew = baseClass->aggNew;
    }

    // Allocate instance of each new interface
    for (i = 0; i < interfaces_dim; i++)
    {
	unsigned thissize = 4;
	BaseClass *b = interfaces[i];

	alignmember(structalign, thissize, &sc->offset);
	b->offset = sc->offset;
	sc->offset += thissize;
	if (alignsize < thissize)
	    alignsize = thissize;
    }
    structsize = sc->offset;
    sizeok = 1;

    sc->pop();

    // Fill in base class vtbl[]s
    for (i = 0; i < interfaces_dim; i++)
    {
	BaseClass *b = interfaces[i];

	b->fillVtbl(this, &b->vtbl, 1);
    }
}

void ClassDeclaration::toCBuffer(OutBuffer *buf)
{   int i;
    int needcomma;

    buf->printf("%s %s", kind(), toChars());
    needcomma = 0;
    if (baseClass)
    {	buf->printf(" : %s", baseClass->toChars());
	needcomma = 1;
    }
    for (i = 0; i < baseclasses.dim; i++)
    {
	BaseClass *b = (BaseClass *)baseclasses.data[i];

	if (needcomma)
	    buf->writeByte(',');
	needcomma = 1;
	buf->writestring(b->base->ident->toChars());
    }
    buf->writenl();
    buf->writeByte('{');
    buf->writenl();
    for (i = 0; i < members->dim; i++)
    {
	Dsymbol *s = (Dsymbol *)members->data[i];

	buf->writestring("    ");
	s->toCBuffer(buf);
    }
    buf->writestring("}");
    buf->writenl();
}

#if 0
void ClassDeclaration::defineRef(Dsymbol *s)
{
    ClassDeclaration *cd;

    AggregateDeclaration::defineRef(s);
    cd = dynamic_cast<ClassDeclaration *>(s);
    baseType = cd->baseType;
    cd->baseType = NULL;
}
#endif

/*******************************************
 * Determine if 'this' is a base class of cd.
 */

int ClassDeclaration::isBaseOf(ClassDeclaration *cd, int *poffset)
{
    if (poffset)
	*poffset = 0;
    while (cd)
    {
	if (this == cd->baseClass)
	    return 1;
	cd = cd->baseClass;
    }
    return 0;
}

Dsymbol *ClassDeclaration::search(Identifier *ident)
{
    Dsymbol *s;

    //printf("%s.ClassDeclaration::search('%s')\n", toChars(), ident->toChars());
    if (!members || !symtab)
    {	error("is forward referenced");
	return NULL;
    }

    s = symtab->lookup(ident);
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
		    s = b->base->search(ident);
		    if (s)
			break;
		}
	    }
	}

	if (!s && imports)
	{
	    // Look in imports
	    s = ScopeDsymbol::search(ident);
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
    unsigned i;

    for (i = 0; i < vtbl.dim; i++)
    {
	FuncDeclaration *fd = (FuncDeclaration *)vtbl.data[i];

	if (ident == fd->ident &&
	    tf->equals(fd->type))
	    return fd;
    }

    return NULL;
}

void ClassDeclaration::interfaceSemantic(Scope *sc)
{   int i;

    for (i = 0; i < interfaces_dim; i++)
    {
	BaseClass *b = interfaces[i];
	Type *t;
	TypeClass *tc;
	InterfaceDeclaration *id;

	t = b->type->semantic(loc, sc)->toBasetype();
	tc = dynamic_cast<TypeClass *>(t);
	if (!tc || !tc->sym->isInterface())
	    error("'%s' must be an interface", t->toChars());
	else
	{
	    b->base = tc->sym;

	    // If this is an interface, and it derives from a COM interface,
	    // then this is a COM interface too.
	    if (b->base->isCOMclass())
		com = 1;
	}
    }
}

/****************************************
 */

int ClassDeclaration::isCOMclass()
{
    return com;
}


char *ClassDeclaration::kind()
{
    return "class";
}

/********************************* InterfaceDeclaration ****************************/

InterfaceDeclaration::InterfaceDeclaration(Identifier *id, Array *baseclasses)
    : ClassDeclaration(id, baseclasses)
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
	id = new InterfaceDeclaration(ident, NULL);

    ClassDeclaration::syntaxCopy(id);
    return id;
}

void InterfaceDeclaration::semantic(Scope *sc)
{   int i;

    //printf("InterfaceDeclaration::semantic(%s), type = %p\n", toChars(), type);
    type = type->semantic(loc, sc);
    handle = handle->semantic(loc, sc);
    if (!members)			// if forward reference
    {	//printf("\tinterface '%s' is forward referenced\n", toChars());
	return;
    }
    if (symtab)			// if already done
	return;
    symtab = new DsymbolTable();

#if INTERFACE_OFFSET
    vtbl.push(this);		// leave room at vtbl[0] for classinfo
#endif

    interfaces_dim = baseclasses.dim;
    interfaces = (BaseClass **)baseclasses.data;

    interfaceSemantic(sc);

    // Cat together the vtbl[]'s from base interfaces
    for (i = 0; i < interfaces_dim; i++)
    {	BaseClass *b = interfaces[i];

	// Copy vtbl[] from base class
	vtbl.append(&b->base->vtbl);
	assert(!INTERFACE_OFFSET);
    }

    for (i = 0; i < members->dim; i++)
    {
	Dsymbol *s = (Dsymbol *)members->data[i];
	s->addMember(this);
    }

    sc = sc->push(this);
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
}


/*******************************************
 * Determine if 'this' is a base class of cd.
 * (Actually, if it is an interface supported by cd)
 */

int InterfaceDeclaration::isBaseOf(ClassDeclaration *cd, int *poffset)
{
    unsigned j;

    assert(!baseClass);
    for (j = 0; j < cd->interfaces_dim; j++)
    {
	BaseClass *b = cd->interfaces[j];

	if (this == b->base)
	{
	    if (poffset)
		*poffset = b->offset;
	    return 1;
	}
    }

    for (j = 0; j < cd->interfaces_dim; j++)
    {
	BaseClass *b = cd->interfaces[j];

	if (isBaseOf(b->base, poffset))
	    return 1;
    }

    if (cd->baseClass && isBaseOf(cd->baseClass, poffset))
	return 1;

    if (poffset)
	*poffset = 0;
    return 0;
}


/*******************************************
 */

int InterfaceDeclaration::isInterface()
{
    return 1;
}

char *InterfaceDeclaration::kind()
{
    return "interface";
}


/******************************** BaseClass *****************************/

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

    //printf("BaseClass::fillVtbl('%s')\n", base->toChars());
    if (vtbl)
	vtbl->setDim(base->vtbl.dim);
#if INTERFACE_OFFSET
    // first entry is ClassInfo reference
    for (j = 1; j < base->vtbl.dim; j++)
#else
    for (j = 0; j < base->vtbl.dim; j++)
#endif
    {
	FuncDeclaration *ifd = dynamic_cast<FuncDeclaration *>((Object *)base->vtbl.data[j]);
	FuncDeclaration *fd;

	//printf("        vtbl[%d] is '%s'\n", j, ifd ? ifd->toChars() : "null");

	assert(ifd);
	// Find corresponding function in this class
	fd = cd->findFunc(ifd->ident, dynamic_cast<TypeFunction *>(ifd->type));
	if (fd && !fd->isAbstract())
	{
	    //printf("            found\n");
	    // Check that calling conventions match
	    if (fd->linkage != ifd->linkage)
		fd->error("linkage doesn't match interface function");

	    // Check that it is current
	    if (newinstance &&
		fd->parent != cd &&
		ifd->parent == base)
		cd->error("interface function %s.%s is not implemented",
		    id->toChars(), ifd->ident->toChars());

	    if (fd->parent == cd)
		result = 1;
	}
	else
	{
	    //printf("            not found\n");
	    // BUG: should mark this class as abstract?
	    cd->error("interface function %s.%s is not implemented",
		id->toChars(), ifd->ident->toChars());
	    fd = NULL;
	}
	if (vtbl)
	    vtbl->data[j] = fd;
    }

    return result;
}
