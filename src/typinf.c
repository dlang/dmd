

// Copyright (c) 1999-2004 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <assert.h>

//#include "mem.h"

#include "mars.h"
#include "module.h"
#include "mtype.h"
#include "scope.h"
#include "init.h"
#include "expression.h"
#include "attrib.h"
#include "declaration.h"
#include "template.h"
#include "id.h"
#include "enum.h"
#include "import.h"
#include "aggregate.h"

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

/*******************************************
 * Get a canonicalized form of the TypeInfo for use with the internal
 * runtime library routines. Canonicalized in that static arrays are
 * represented as dynamic arrays, enums are represented by their
 * underlying type, etc. This reduces the number of TypeInfo's needed,
 * so we can use the custom internal ones more.
 */

Expression *Type::getInternalTypeInfo()
{   TypeInfoDeclaration *tid;
    Expression *e;
    Type *t;
    static TypeInfoDeclaration *internalTI[TMAX];

    t = toBasetype();
    switch (t->ty)
    {
	case Tsarray:
	    t = t->next->arrayOf();	// convert to corresponding dynamic array type
	    break;

	case Tarray:
	    if (t->next->ty != Tclass)
		break;
	case Tfunction:
	case Tdelegate:
	case Tclass:
	case Tpointer:
	    tid = internalTI[t->ty];
	    if (!tid)
	    {	tid = new TypeInfoDeclaration(t, 1);
		internalTI[t->ty] = tid;
	    }
	    e = new VarExp(0, tid);
	    e = e->addressOf();
	    e->type = tid->type;	// do this so we don't get redundant dereference
	    return e;

	default:
	    break;
    }
    return t->getTypeInfo(NULL);
}


/****************************************************
 * Get the exact TypeInfo.
 */

Expression *Type::getTypeInfo(Scope *sc)
{
    Expression *e;

    //printf("Type::getTypeInfo()\n");
    if (!vtinfo)
    {	vtinfo = getTypeInfoDeclaration();

	/* If this has a custom implementation in std/typeinfo, then
	 * do not generate a COMDAT for it.
	 */
	if (!builtinTypeInfo())
	{   // Generate COMDAT
	    if (sc)			// if in semantic() pass
		sc->module->members->push(vtinfo);
	    else			// if in obj generation pass
		vtinfo->toObjFile();
	}
    }
    e = new VarExp(0, vtinfo);
    e = e->addressOf();
    e->type = vtinfo->type;		// do this so we don't get redundant dereference
    return e;
}

TypeInfoDeclaration *Type::getTypeInfoDeclaration()
{
    return new TypeInfoDeclaration(this, 0);
}

TypeInfoDeclaration *TypeTypedef::getTypeInfoDeclaration()
{
    return new TypeInfoTypedefDeclaration(this);
}

TypeInfoDeclaration *TypeClass::getTypeInfoDeclaration()
{
    return new TypeInfoClassDeclaration(this);
}


/****************************************************
 */

#if 1

void TypeInfoDeclaration::toDt(dt_t **pdt)
{
    //printf("TypeInfoDeclaration::toDt()\n");
    dtxoff(pdt, Type::typeinfo->toVtblSymbol(), 0, TYnptr); // vtbl for TypeInfo
    dtdword(pdt, 0);			    // monitor
}

void TypeInfoTypedefDeclaration::toDt(dt_t **pdt)
{
    //printf("TypeInfoTypedefDeclaration::toDt()\n");
    dtxoff(pdt, Type::typeinfotypedef->toVtblSymbol(), 0, TYnptr); // vtbl for TypeInfoTypedef
    dtdword(pdt, 0);			    // monitor

    assert(tinfo->ty == Ttypedef);

    TypeTypedef *tc = (TypeTypedef *)tinfo;

    tc->sym->basetype->getTypeInfo(NULL);
    dtxoff(pdt, tc->sym->basetype->vtinfo->toSymbol(), 0, TYnptr);	// TypeInfo for basetype
}

void TypeInfoClassDeclaration::toDt(dt_t **pdt)
{
    //printf("TypeInfoClassDeclaration::toDt()\n");
    dtxoff(pdt, Type::typeinfoclass->toVtblSymbol(), 0, TYnptr); // vtbl for TypeInfoClass
    dtdword(pdt, 0);			    // monitor

    assert(tinfo->ty == Tclass);

    TypeClass *tc = (TypeClass *)tinfo;
    Symbol *s;

    if (!tc->sym->vclassinfo)
	tc->sym->vclassinfo = new ClassInfoDeclaration(tc->sym);
    s = tc->sym->vclassinfo->toSymbol();
    dtxoff(pdt, s, 0, TYnptr);		// ClassInfo for tinfo
}

void TypeInfoDeclaration::toObjFile()
{
    Symbol *s;
    unsigned sz;
    Dsymbol *parent;

    //printf("TypeInfoDeclaration::toObjFile(%p '%s') protection %d\n", this, toChars(), protection);

    s = toSymbol();
    sz = type->size();

    parent = this->toParent();
    s->Sclass = SCcomdat;
    s->Sfl = FLdata;

    toDt(&s->Sdt);

    dt_optimize(s->Sdt);

    // See if we can convert a comdat to a comdef,
    // which saves on exe file space.
    if (s->Sclass == SCcomdat &&
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
    outdata(s);
    if (isExport())
	obj_export(s,0);
}

#endif

/* ========================================================================= */

/* These decide if there's an instance for them already in std.typeinfo,
 * because then the compiler doesn't need to build one.
 */

int Type::builtinTypeInfo()
{
    return 0;
}

int TypeBasic::builtinTypeInfo()
{
    return 1;
}

int TypeDArray::builtinTypeInfo()
{
    return next->isTypeBasic() != NULL;
}

/* ========================================================================= */

/***************************************
 * Create a static array of TypeInfo references
 * corresponding to an array of Expression's.
 * Used to supply hidden _arguments[] value for variadic D functions.
 */

Expression *createTypeInfoArray(Scope *sc, Expression *args[], int dim)
{
    /* Improvements:
     * 1) create an array literal instead,
     * as it would eliminate the extra dereference of loading the
     * static variable.
     */

    ArrayInitializer *ai = new ArrayInitializer(0);
    VarDeclaration *v;
    Type *t;
    Expression *e;
    OutBuffer buf;
    Identifier *id;
    char *name;

    // Generate identifier for _arguments[]
    buf.writestring("_arguments_");
    for (int i = 0; i < dim; i++)
    {	t = args[i]->type;
	t->toDecoBuffer(&buf);
    }
    buf.writeByte(0);
    id = Lexer::idPool((char *)buf.data);

    Module *m = sc->module;
    Dsymbol *s = m->symtab->lookup(id);

    if (s && s->parent == m)
    {	// Use existing one
	v = s->isVarDeclaration();
	assert(v);
    }
    else
    {	// Generate new one

	for (int i = 0; i < dim; i++)
	{   t = args[i]->type;
	    e = t->getTypeInfo(sc);
	    ai->addInit(new IntegerExp(i), new ExpInitializer(0, e));
	}

	t = Type::typeinfo->type->arrayOf();
	v = new VarDeclaration(0, t, id, ai);
	m->members->push(v);
	m->symtab->insert(v);
	sc = sc->push();
	sc->linkage = LINKc;
	sc->stc = STCstatic | STCcomdat;
	v->semantic(sc);
	v->parent = m;
	sc = sc->pop();
    }
    e = new VarExp(0, v);
    e = e->semantic(sc);
    return e;
}

