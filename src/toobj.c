
// Copyright (c) 1999-2004 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <stddef.h>
#include <time.h>
#include <assert.h>

#include "mars.h"
#include "module.h"
#include "mtype.h"
#include "declaration.h"
#include "statement.h"
#include "enum.h"
#include "aggregate.h"
#include "init.h"
#include "attrib.h"
#include "id.h"
#include "import.h"
#include "template.h"

#include <mem.h>
#include "cc.h"
#include "global.h"
#include "oper.h"
#include "code.h"
#include "type.h"
#include "dt.h"
#include "cgcv.h"
#include "outbuf.h"
#include "irstate.h"

void obj_lzext(Symbol *s1,Symbol *s2);

/* ================================================================== */

// Put out instance of ModuleInfo for this Module

void Module::genmoduleinfo()
{
    Symbol *msym = toSymbol();
    unsigned offset;
    unsigned sizeof_ModuleInfo = 12 * 4;

    //////////////////////////////////////////////

    csym->Sclass = SCglobal;
    csym->Sfl = FLdata;

    /* The layout is:
       {
	    void **vptr;
	    monitor_t monitor;
	    char[] name;		// class name
	    ModuleInfo importedModules[];
	    ClassInfo localClasses[];
	    uint flags;			// initialization state
	    void *ctor;
	    void *dtor;
	    void *unitTest;
       }
     */
    dt_t *dt = NULL;

    if (moduleinfo)
	dtxoff(&dt, moduleinfo->toVtblSymbol(), 0, TYnptr); // vtbl for ModuleInfo
    else
	dtdword(&dt, 0);		// BUG: should be an assert()
    dtdword(&dt, 0);			// monitor

    // name[]
    char *name = ident->toChars();
    size_t namelen = strlen(name);
    dtdword(&dt, namelen);
    dtabytes(&dt, TYnptr, 0, namelen + 1, name);

    ClassDeclarations aclasses;
    int i;

    //printf("members->dim = %d\n", members->dim);
    for (i = 0; i < members->dim; i++)
    {
	Dsymbol *member;

	member = (Dsymbol *)members->data[i];
	//printf("\tmember '%s'\n", member->toChars());
	member->addLocalClass(&aclasses);
    }

    // importedModules[]
    int aimports_dim = aimports.dim;
    for (i = 0; i < aimports.dim; i++)
    {	Module *m = (Module *)aimports.data[i];
	if (!m->needModuleInfo())
	    aimports_dim--;
    }
    dtdword(&dt, aimports_dim);
    if (aimports.dim)
	dtxoff(&dt, csym, sizeof_ModuleInfo, TYnptr);
    else
	dtdword(&dt, 0);

    // localClasses[]
    dtdword(&dt, aclasses.dim);
    if (aclasses.dim)
	dtxoff(&dt, csym, sizeof_ModuleInfo + aimports.dim * 4, TYnptr);
    else
	dtdword(&dt, 0);

    if (needmoduleinfo)
	dtdword(&dt, 0);		// flags (4 means MIstandalone)
    else
	dtdword(&dt, 4);		// flags (4 means MIstandalone)

    if (sctor)
	dtxoff(&dt, sctor, 0, TYnptr);
    else
	dtdword(&dt, 0);

    if (sdtor)
	dtxoff(&dt, sdtor, 0, TYnptr);
    else
	dtdword(&dt, 0);

    if (stest)
	dtxoff(&dt, stest, 0, TYnptr);
    else
	dtdword(&dt, 0);

    //////////////////////////////////////////////

    for (i = 0; i < aimports.dim; i++)
    {
	Module *m;

	m = (Module *)aimports.data[i];
	if (m->needModuleInfo())
	{   Symbol *s = m->toSymbol();
	    s->Sflags |= SFLweak;
	    dtxoff(&dt, s, 0, TYnptr);
	}
    }

    for (i = 0; i < aclasses.dim; i++)
    {
	ClassDeclaration *cd;

	cd = (ClassDeclaration *)aclasses.data[i];
	dtxoff(&dt, cd->toSymbol(), 0, TYnptr);
    }

    csym->Sdt = dt;
#if ELFOBJ
    // Cannot be CONST because the startup code sets flag bits in it
    csym->Sseg = DATA;
#endif
    outdata(csym);

    //////////////////////////////////////////////

    obj_moduleinfo(msym);
}

/* ================================================================== */

void Dsymbol::toObjFile()
{
    //printf("Dsymbol::toObjFile('%s')\n", toChars());
    // ignore
}

/* ================================================================== */

void ClassDeclaration::toObjFile()
{   unsigned i;
    unsigned offset;
    Symbol *sinit;
    enum_SC scclass;

    //printf("ClassDeclaration::toObjFile('%s')\n", toChars());

    if (!members)
	return;

    if (global.params.symdebug)
	toDebug();

    assert(!scope);	// semantic() should have been run to completion

    if (parent && parent->isTemplateInstance())
	scclass = SCcomdat;
    else
	scclass = SCglobal;

    // Put out the members
    for (i = 0; i < members->dim; i++)
    {
	Dsymbol *member;

	member = (Dsymbol *)members->data[i];
	member->toObjFile();
    }

    // Generate C symbols
    toSymbol();
    toVtblSymbol();
    sinit = toInitializer();

    //////////////////////////////////////////////

    // Generate static initializer
    sinit->Sclass = scclass;
    sinit->Sfl = FLdata;
#if ELFOBJ // Burton
    sinit->Sseg = CDATA;
#endif /* ELFOBJ */
    toDt(&sinit->Sdt);
    outdata(sinit);

    //////////////////////////////////////////////

    // Put out the ClassInfo
    csym->Sclass = scclass;
    csym->Sfl = FLdata;

    /* The layout is:
       {
	    void **vptr;
	    monitor_t monitor;
	    byte[] initializer;		// static initialization data
	    char[] name;		// class name
	    void *[] vtbl;
	    Interface[] interfaces;
	    ClassInfo *base;		// base class
	    void *destructor;
	    void *invariant;		// class invariant
	    uint flags;
	    void *deallocator;
       }
     */
    dt_t *dt = NULL;
    offset = CLASSINFO_SIZE;			// must be ClassInfo.size
    if (classinfo)
    {
	assert(classinfo->structsize == CLASSINFO_SIZE);
    }

    if (classinfo)
	dtxoff(&dt, classinfo->toVtblSymbol(), 0, TYnptr); // vtbl for ClassInfo
    else
	dtdword(&dt, 0);		// BUG: should be an assert()
    dtdword(&dt, 0);			// monitor

    // initializer[]
    assert(structsize >= 8);
    dtdword(&dt, structsize);		// size
    dtxoff(&dt, sinit, 0, TYnptr);	// initializer

    // name[]
    char *name = ident->toChars();
    size_t namelen = strlen(name);
    dtdword(&dt, namelen);
    dtabytes(&dt, TYnptr, 0, namelen + 1, name);

    // vtbl[]
    dtdword(&dt, vtbl.dim);
    dtxoff(&dt, vtblsym, 0, TYnptr);

    // interfaces[]
    dtdword(&dt, vtblInterfaces->dim);
    if (vtblInterfaces->dim)
	dtxoff(&dt, csym, offset, TYnptr);	// (*)
    else
	dtdword(&dt, 0);

    // base
    if (baseClass)
	dtxoff(&dt, baseClass->toSymbol(), 0, TYnptr);
    else
	dtdword(&dt, 0);

    // destructor
    if (dtor)
	dtxoff(&dt, dtor->toSymbol(), 0, TYnptr);
    else
	dtdword(&dt, 0);

    // invariant
    if (inv)
	dtxoff(&dt, inv->toSymbol(), 0, TYnptr);
    else
	dtdword(&dt, 0);

    // flags
    dtdword(&dt, com);


    // deallocator
    if (aggDelete)
	dtxoff(&dt, aggDelete->toSymbol(), 0, TYnptr);
    else
	dtdword(&dt, 0);

    //////////////////////////////////////////////

    // Put out vtblInterfaces->data[]. Must immediately follow csym, because
    // of the fixup (*)

    offset += vtblInterfaces->dim * (4 * 4);
    for (i = 0; i < vtblInterfaces->dim; i++)
    {	BaseClass *b = (BaseClass *)vtblInterfaces->data[i];
	ClassDeclaration *id = b->base;

	/* The layout is:
	 *  {
	 *	ClassInfo *interface;
	 *	void *[] vtbl;
	 *	unsigned offset;
	 *  }
	 */

	// Fill in vtbl[]
	b->fillVtbl(this, &b->vtbl, 1);

	dtxoff(&dt, id->toSymbol(), 0, TYnptr);		// ClassInfo

	// vtbl[]
	dtdword(&dt, id->vtbl.dim);
	dtxoff(&dt, csym, offset, TYnptr);

	dtdword(&dt, b->offset);			// this offset

	offset += id->vtbl.dim * 4;
    }

    // Put out the vtblInterfaces->data[].vtbl[]
    // This must be mirrored with ClassDeclaration::baseVtblOffset()
    //printf("putting out %d interface vtbl[]s for '%s'\n", vtblInterfaces->dim, toChars());
    for (i = 0; i < vtblInterfaces->dim; i++)
    {	BaseClass *b = (BaseClass *)vtblInterfaces->data[i];
	ClassDeclaration *id = b->base;
	int j;

	//printf("    interface[%d] is '%s'\n", i, id->toChars());
	j = 0;
	if (id->vtblOffset())
	{
	    // First entry is ClassInfo reference
	    //dtxoff(&dt, id->toSymbol(), 0, TYnptr);

	    // First entry is struct Interface reference
	    dtxoff(&dt, csym, CLASSINFO_SIZE + i * (4 * 4), TYnptr);
	    j = 1;
	}
	assert(id->vtbl.dim == b->vtbl.dim);
	for (; j < id->vtbl.dim; j++)
	{
	    FuncDeclaration *fd;

	    assert(j < b->vtbl.dim);
#if 0
	    Object *o = (Object *)b->vtbl.data[j];
	    if (o)
	    {
		printf("o = %p\n", o);
		assert(o->dyncast() == DYNCAST_DSYMBOL);
		Dsymbol *s = (Dsymbol *)o;
		printf("s->kind() = '%s'\n", s->kind());
	    }
#endif
	    fd = (FuncDeclaration *)b->vtbl.data[j];
	    if (fd)
		dtxoff(&dt, fd->toThunkSymbol(b->offset), 0, TYnptr);
	    else
		dtdword(&dt, 0);
	}
    }

#if 1
    // Put out the overriding interface vtbl[]s.
    // This must be mirrored with ClassDeclaration::baseVtblOffset()
    //printf("putting out overriding interface vtbl[]s for '%s' at offset x%x\n", toChars(), offset);
    ClassDeclaration *cd;
    Array bvtbl;

    for (cd = this->baseClass; cd; cd = cd->baseClass)
    {
	for (int k = 0; k < cd->vtblInterfaces->dim; k++)
	{   BaseClass *bs = (BaseClass *)cd->vtblInterfaces->data[k];

	    if (bs->fillVtbl(this, &bvtbl, 0))
	    {
		//printf("\toverriding vtbl[] for %s\n", bs->base->toChars());
		ClassDeclaration *id = bs->base;
		int j;

		j = 0;
		if (id->vtblOffset())
		{
		    // First entry is ClassInfo reference
		    //dtxoff(&dt, id->toSymbol(), 0, TYnptr);

		    // First entry is struct Interface reference
		    dtxoff(&dt, cd->toSymbol(), CLASSINFO_SIZE + k * (4 * 4), TYnptr);
		    j = 1;
		}

		for (; j < id->vtbl.dim; j++)
		{
		    FuncDeclaration *fd;

		    assert(j < bvtbl.dim);
		    fd = (FuncDeclaration *)bvtbl.data[j];
		    if (fd)
			dtxoff(&dt, fd->toThunkSymbol(bs->offset), 0, TYnptr);
		    else
			dtdword(&dt, 0);
		}
	    }
	}
    }
#endif
#if INTERFACE_VIRTUAL
    // Put out the overriding interface vtbl[]s.
    // This must be mirrored with ClassDeclaration::baseVtblOffset()
    //printf("putting out overriding interface vtbl[]s for '%s' at offset x%x\n", toChars(), offset);
    for (i = 0; i < vtblInterfaces->dim; i++)
    {	BaseClass *b = (BaseClass *)vtblInterfaces->data[i];
	ClassDeclaration *cd;

	for (cd = this->baseClass; cd; cd = cd->baseClass)
	{
	    for (int k = 0; k < cd->vtblInterfaces->dim; k++)
	    {	BaseClass *bs = (BaseClass *)cd->vtblInterfaces->data[k];

		if (b->base == bs->base)
		{
		    //printf("\toverriding vtbl[] for %s\n", b->base->toChars());
		    ClassDeclaration *id = b->base;
		    int j;

		    j = 0;
		    if (id->vtblOffset())
		    {
			// First entry is ClassInfo reference
			//dtxoff(&dt, id->toSymbol(), 0, TYnptr);

			// First entry is struct Interface reference
			dtxoff(&dt, cd->toSymbol(), CLASSINFO_SIZE + k * (4 * 4), TYnptr);
			j = 1;
		    }

		    for (; j < id->vtbl.dim; j++)
		    {
			FuncDeclaration *fd;

			assert(j < b->vtbl.dim);
			fd = (FuncDeclaration *)b->vtbl.data[j];
			if (fd)
			    dtxoff(&dt, fd->toThunkSymbol(bs->offset), 0, TYnptr);
			else
			    dtdword(&dt, 0);
		    }
		}
	    }
	}
    }
#endif


    csym->Sdt = dt;
#if ELFOBJ // Burton
    // ClassInfo cannot be const data, because we use the monitor on it
    csym->Sseg = DATA;
#endif /* ELFOBJ */
    outdata(csym);
    if (isExport())
	obj_export(csym,0);

    //////////////////////////////////////////////

    // Put out the vtbl[]
    //printf("putting out %s.vtbl[]\n", toChars());
    dt = NULL;
    if (0)
	i = 0;
    else
    {	dtxoff(&dt, csym, 0, TYnptr);		// first entry is ClassInfo reference
	i = 1;
    }
    for (; i < vtbl.dim; i++)
    {
	FuncDeclaration *fd = ((Dsymbol *)vtbl.data[i])->isFuncDeclaration();

	//printf("\tvtbl[%d] = %p\n", i, fd);
	if (fd && (fd->fbody || !isAbstract()))
	{
	    dtxoff(&dt, fd->toSymbol(), 0, TYnptr);
	}
	else
	    dtdword(&dt, 0);
    }
    vtblsym->Sdt = dt;
    vtblsym->Sclass = scclass;
    vtblsym->Sfl = FLdata;
#if ELFOBJ // Burton
    vtblsym->Sseg = CDATA;
#endif /* ELFOBJ */
    outdata(vtblsym);
    if (isExport())
	obj_export(vtblsym,0);
}

/******************************************
 * Get offset of base class's vtbl[] initializer from start of csym.
 * Returns ~0 if not this csym.
 */

unsigned ClassDeclaration::baseVtblOffset(BaseClass *bc)
{
    unsigned csymoffset;
    int i;

    //printf("ClassDeclaration::baseVtblOffset('%s', bc = %p)\n", toChars(), bc);
    csymoffset = CLASSINFO_SIZE;
    csymoffset += vtblInterfaces->dim * (4 * 4);

    for (i = 0; i < vtblInterfaces->dim; i++)
    {
	BaseClass *b = (BaseClass *)vtblInterfaces->data[i];

	if (b == bc)
	    return csymoffset;
	csymoffset += b->base->vtbl.dim * 4;
    }

#if 1
    // Put out the overriding interface vtbl[]s.
    // This must be mirrored with ClassDeclaration::baseVtblOffset()
    //printf("putting out overriding interface vtbl[]s for '%s' at offset x%x\n", toChars(), offset);
    ClassDeclaration *cd;
    Array bvtbl;

    for (cd = this->baseClass; cd; cd = cd->baseClass)
    {
	for (int k = 0; k < cd->vtblInterfaces->dim; k++)
	{   BaseClass *bs = (BaseClass *)cd->vtblInterfaces->data[k];

	    if (bs->fillVtbl(this, NULL, 0))
	    {
		if (bc == bs)
		{   //printf("\tcsymoffset = x%x\n", csymoffset);
		    return csymoffset;
		}
		csymoffset += bs->base->vtbl.dim * 4;
	    }
	}
    }
#endif
#if INTERFACE_VIRTUAL
    for (i = 0; i < vtblInterfaces->dim; i++)
    {	BaseClass *b = (BaseClass *)vtblInterfaces->data[i];
	ClassDeclaration *cd;

	for (cd = this->baseClass; cd; cd = cd->baseClass)
	{
	    //printf("\tbase class %s\n", cd->toChars());
	    for (int k = 0; k < cd->vtblInterfaces->dim; k++)
	    {	BaseClass *bs = (BaseClass *)cd->vtblInterfaces->data[k];

		if (bc == bs)
		{   //printf("\tcsymoffset = x%x\n", csymoffset);
		    return csymoffset;
		}
		if (b->base == bs->base)
		    csymoffset += bs->base->vtbl.dim * 4;
	    }
	}
    }
#endif

    return ~0;
}

/* ================================================================== */

void InterfaceDeclaration::toObjFile()
{   unsigned i;
    unsigned offset;
    Symbol *sinit;
    enum_SC scclass;

    //printf("InterfaceDeclaration::toObjFile('%s')\n", toChars());

    if (!members)
	return;

    if (global.params.symdebug)
	toDebug();

    if (parent && parent->isTemplateInstance())
	scclass = SCcomdat;
    else
	scclass = SCglobal;

    // Put out the members
    for (i = 0; i < members->dim; i++)
    {
	Dsymbol *member;

	member = (Dsymbol *)members->data[i];
	if (!member->isFuncDeclaration())
	    member->toObjFile();
    }

    // Generate C symbols
    toSymbol();

    //////////////////////////////////////////////

    // Put out the ClassInfo
    csym->Sclass = scclass;
    csym->Sfl = FLdata;

    /* The layout is:
       {
	    void **vptr;
	    monitor_t monitor;
	    byte[] initializer;		// static initialization data
	    char[] name;		// class name
	    void *[] vtbl;
	    Interface[] interfaces;
	    Object *base;		// base class
	    void *destructor;
	    void *invariant;		// class invariant
	    uint flags;
	    void *deallocator;
       }
     */
    dt_t *dt = NULL;

    if (classinfo)
	dtxoff(&dt, classinfo->toVtblSymbol(), 0, TYnptr); // vtbl for ClassInfo
    else
	dtdword(&dt, 0);		// BUG: should be an assert()
    dtdword(&dt, 0);			// monitor

    // initializer[]
    dtdword(&dt, 0);			// size
    dtdword(&dt, 0);			// initializer

    // name[]
    char *name = ident->toChars();
    size_t namelen = strlen(name);
    dtdword(&dt, namelen);
    dtabytes(&dt, TYnptr, 0, namelen + 1, name);

    // vtbl[]
    dtdword(&dt, 0);
    dtdword(&dt, 0);

    // vtblInterfaces->data[]
    dtdword(&dt, vtblInterfaces->dim);
    if (vtblInterfaces->dim)
    {
	if (classinfo)
	    assert(classinfo->structsize == CLASSINFO_SIZE);
	offset = CLASSINFO_SIZE;
	dtxoff(&dt, csym, offset, TYnptr);	// (*)
    }
    else
	dtdword(&dt, 0);

    // base
    assert(!baseClass);
    dtdword(&dt, 0);

    // dtor
    dtdword(&dt, 0);

    // invariant
    dtdword(&dt, 0);

    // flags
    dtdword(&dt, com);

    // deallocator
    dtdword(&dt, 0);

    //////////////////////////////////////////////

    // Put out vtblInterfaces->data[]. Must immediately follow csym, because
    // of the fixup (*)

    offset += vtblInterfaces->dim * (4 * 4);
    for (i = 0; i < vtblInterfaces->dim; i++)
    {	BaseClass *b = (BaseClass *)vtblInterfaces->data[i];
	ClassDeclaration *id = b->base;

	// ClassInfo
	dtxoff(&dt, id->toSymbol(), 0, TYnptr);

	// vtbl[]
	dtdword(&dt, 0);
	dtdword(&dt, 0);

	// this offset
	dtdword(&dt, b->offset);
    }

    csym->Sdt = dt;
#if ELFOBJ // Burton
    csym->Sseg = CDATA;
#endif /* ELFOBJ */
    outdata(csym);
    if (isExport())
	obj_export(csym,0);
}

/* ================================================================== */

void StructDeclaration::toObjFile()
{   unsigned i;

    //printf("StructDeclaration::toObjFile('%s')\n", toChars());

    // Anonymous structs/unions only exist as part of others,
    // do not output forward referenced structs's
    if (!isAnonymous() && members)
    {
	if (global.params.symdebug)
	    toDebug();

	// Generate static initializer
	toInitializer();
	if (parent && parent->isTemplateInstance())
	    sinit->Sclass = SCcomdat;
	else
	    sinit->Sclass = SCglobal;
	sinit->Sfl = FLdata;
	toDt(&sinit->Sdt);

#if !ELFOBJ
	/* ELF comdef's generate multiple
	 * definition errors for them from the gnu linker.
	 * Need to figure out how to generate proper comdef's for ELF.
	 */
	// See if we can convert a comdat to a comdef,
	// which saves on exe file space.
	if (sinit->Sclass == SCcomdat &&
	    sinit->Sdt &&
	    sinit->Sdt->dt == DT_azeros &&
	    sinit->Sdt->DTnext == NULL)
	{
	    sinit->Sclass = SCglobal;
	    sinit->Sdt->dt = DT_common;
	}
#endif

#if ELFOBJ // Burton
	sinit->Sseg = CDATA;
#endif /* ELFOBJ */
	outdata(sinit);

	// Put out the members
	for (i = 0; i < members->dim; i++)
	{
	    Dsymbol *member;

	    member = (Dsymbol *)members->data[i];
	    member->toObjFile();
	}
    }
}

/* ================================================================== */

void VarDeclaration::toObjFile()
{
    Symbol *s;
    unsigned sz;
    Dsymbol *parent;

    //printf("VarDeclaration::toObjFile(%p '%s') protection %d\n", this, toChars(), protection);

    if (isDataseg() && !(storage_class & STCextern))
    {
	s = toSymbol();
	sz = type->size();

	parent = this->toParent();
#if 1	/* private statics should still get a global symbol, in case
	 * another module inlines a function that references it.
	 */
	if (/*protection == PROTprivate ||*/
	    !parent || parent->ident == NULL || parent->isFuncDeclaration())
	    s->Sclass = SCstatic;
	else
#endif
	{
	    if (storage_class & STCcomdat)
		s->Sclass = SCcomdat;
	    else
		s->Sclass = SCglobal;

	    do
	    {
		/* Global template data members need to be in comdat's
		 * in case multiple .obj files instantiate the same
		 * template with the same types.
		 */
		if (parent->isTemplateInstance())
		{
		    s->Sclass = SCcomdat;
		    break;
		}
		parent = parent->toParent();
	    } while (parent);
	}
	s->Sfl = FLdata;

	if (init)
	{   s->Sdt = init->toDt();

	    // Look for static array that is block initialized
	    Type *tb;
	    ExpInitializer *ie = init->isExpInitializer();

	    tb = type->toBasetype();
	    if (tb->ty == Tsarray && ie &&
		!tb->next->equals(ie->exp->type->toBasetype()->next) &&
		ie->exp->implicitConvTo(tb->next)
		)
	    {
		int dim;

		dim = ((TypeSArray *)tb)->dim->toInteger();

		if (tb->next->toBasetype()->ty == Tbit)
		{   integer_t value;

		    value = ie->exp->toInteger();
		    value = (value & 1) ? ~(integer_t)0 : (integer_t)0;
		    if (value == 0)
		    {
			dtnzeros(&s->Sdt, ((unsigned)dim + 31) / 32 * 4);
		    }
		    else
		    {
			while (dim >= 32)
			{
			    dtnbytes(&s->Sdt, 4, (char *)&value);
			    dim -= 32;
			}
			if (dim)
			{
			    value = (1 << dim) - 1;
			    dtnbytes(&s->Sdt, 4, (char *)&value);
			}
		    }
		}
		else
		{
		    // Duplicate Sdt 'dim-1' times, as we already have the first one
		    while (--dim > 0)
		    {
			ie->exp->toDt(&s->Sdt);
		    }
		}
	    }
	}
	else if (storage_class & STCextern)
	{
	    s->Sclass = SCextern;
	    s->Sfl = FLextern;
	    s->Sdt = NULL;
	    // BUG: if isExport(), shouldn't we make it dllimport?
	    return;
	}
	else
	{
	    type->toDt(&s->Sdt);
	}
	dt_optimize(s->Sdt);

	// See if we can convert a comdat to a comdef,
	// which saves on exe file space.
	if (s->Sclass == SCcomdat &&
	    s->Sdt &&
	    s->Sdt->dt == DT_azeros &&
	    s->Sdt->DTnext == NULL)
	{
	    s->Sclass = SCglobal;
	    s->Sdt->dt = DT_common;
	}

#if ELFOBJ // Burton
	if (s->Sdt && s->Sdt->dt == DT_azeros && s->Sdt->DTnext == NULL)
	    s->Sseg = UDATA;
	else
	    s->Sseg = DATA;
#endif /* ELFOBJ */
	if (sz)
	{   outdata(s);
	    if (isExport())
		obj_export(s,0);
	}
    }
}

/* ================================================================== */

void TypedefDeclaration::toObjFile()
{
    //printf("TypedefDeclaration::toObjFile('%s')\n", toChars());

    if (global.params.symdebug)
	toDebug();
}

/* ================================================================== */

void EnumDeclaration::toObjFile()
{
    //printf("EnumDeclaration::toObjFile('%s')\n", toChars());

    if (global.params.symdebug)
	toDebug();
}


