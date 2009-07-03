
// Copyright (c) 1999-2005 by Digital Mars
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
#include "lexer.h"
#include "dsymbol.h"

#include <mem.h>

// Back end
#include "cc.h"
#include "global.h"
#include "oper.h"
#include "code.h"
#include "type.h"
#include "dt.h"
#include "cgcv.h"
#include "outbuf.h"
#include "irstate.h"

void slist_add(Symbol *s);
void slist_reset();

/********************************* SymbolDeclaration ****************************/

SymbolDeclaration::SymbolDeclaration(Loc loc, Symbol *s, StructDeclaration *dsym)
    : Declaration(new Identifier(s->Sident, TOKidentifier))
{
    this->loc = loc;
    sym = s;
    this->dsym = dsym;
    storage_class |= STCconst;
}

Symbol *SymbolDeclaration::toSymbol()
{
    return sym;
}

/*************************************
 * Helper
 */

Symbol *Dsymbol::toSymbolX(const char *prefix, int sclass, type *t)
{
    Symbol *s;
    char *id;
    char *n;

    n = mangle(); //ident->toChars();
    assert(n);
    id = (char *) alloca(strlen(prefix) + strlen(n) + 1);
    sprintf(id,"%s%s", prefix, n);
    s = symbol_name(id, sclass, t);
    return s;
}

/*************************************
 */

Symbol *Dsymbol::toSymbol()
{
    printf("Dsymbol::toSymbol() '%s', kind = '%s'\n", toChars(), kind());
    assert(0);		// BUG: implement
    return NULL;
}

/*********************************
 * Generate import symbol from symbol.
 */

Symbol *Dsymbol::toImport()
{
    if (!isym)
    {
	if (!csym)
	    csym = toSymbol();
	isym = toImport(csym);
    }
    return isym;
}

/*************************************
 */

Symbol *Dsymbol::toImport(Symbol *sym)
{
    char *id;
    char *n;
    Symbol *s;
    type *t;

    //printf("Dsymbol::toImport('%s')\n", sym->Sident);
    n = sym->Sident;
    id = (char *) alloca(6 + strlen(n) + 5 + 1);
    if (sym->Stype->Tmangle == mTYman_std)
    {
	sprintf(id,"_imp__%s@%d",n,type_paramsize(sym->Stype));
    }
    else if (sym->Stype->Tmangle == mTYman_d)
	sprintf(id,"_imp_%s",n);
    else
	sprintf(id,"_imp__%s",n);
    t = type_alloc(TYnptr | mTYconst);
    t->Tnext = sym->Stype;
    t->Tnext->Tcount++;
    t->Tmangle = mTYman_c;
    t->Tcount++;
    s = symbol_calloc(id);
    s->Stype = t;
    s->Sclass = SCextern;
    s->Sfl = FLextern;
    slist_add(s);
    return s;
}

/*************************************
 */

Symbol *VarDeclaration::toSymbol()
{
    //printf("VarDeclaration::toSymbol(%s)\n", toChars());
    //if (needThis()) *(char*)0=0;
    assert(!needThis());
    if (!csym)
    {	Symbol *s;
	TYPE *t;
	const char *id;
	mangle_t m = 0;

	if (isDataseg())
	    id = mangle();
	else
	    id = ident->toChars();
	s = symbol_calloc(id);

	if (storage_class & STCout)
	    t = type_fake(TYnptr);
	else if (isParameter())
	    t = type->toCParamtype();
	else
	    t = type->toCtype();
	t->Tcount++;

	if (isDataseg())
	{
	    s->Sclass = SCextern;
	    s->Sfl = FLextern;
	    slist_add(s);
	}
	else
	{
	    s->Sclass = SCauto;
	    s->Sfl = FLauto;

	    if (nestedref)
	    {
		/* Symbol is accessed by a nested function. Make sure
		 * it is not put in a register, and that the optimizer
		 * assumes it is modified across function calls and pointer
		 * dereferences.
		 */
		//printf("\tnested ref, not register\n");
		type_setcv(&t, t->Tty | mTYvolatile);
	    }
	}
	if (storage_class & STCconst)
	{
	    // Insert const modifiers
	    tym_t tym = 0;

	    if (storage_class & STCconst)
		tym |= mTYconst;
	    type_setcv(&t, tym);
	}
	switch (linkage)
	{
	    case LINKwindows:
		m = mTYman_std;
		break;

	    case LINKpascal:
		m = mTYman_pas;
		break;

	    case LINKc:
		m = mTYman_c;
		break;

	    case LINKd:
		m = mTYman_d;
		break;

	    case LINKcpp:
		m = mTYman_cpp;
		break;

	    default:
		printf("linkage = %d\n", linkage);
		assert(0);
	}
	type_setmangle(&t, m);
	s->Stype = t;

	csym = s;
    }
    return csym;
}

/*************************************
 */

Symbol *ClassInfoDeclaration::toSymbol()
{
    return cd->toSymbol();
}

/*************************************
 */

Symbol *ModuleInfoDeclaration::toSymbol()
{
    return mod->toSymbol();
}

/*************************************
 */

Symbol *TypeInfoDeclaration::toSymbol()
{
    //printf("TypeInfoDeclaration::toSymbol(%s), linkage = %d\n", toChars(), linkage);
    return VarDeclaration::toSymbol();
}

/*************************************
 */

Symbol *FuncDeclaration::toSymbol()
{
    if (!csym)
    {	Symbol *s;
	TYPE *t;
	const char *id;

#if 0
	id = ident->toChars();
#else
	id = mangle();
#endif
	//printf("FuncDeclaration::toSymbol(%s)\n", toChars());
	//printf("\tid = '%s'\n", id);
	//printf("\ttype = %s\n", type->toChars());
	s = symbol_calloc(id);
	slist_add(s);

	{   func_t *f;

	    s->Sclass = SCglobal;
	    symbol_func(s);
	    f = s->Sfunc;
	    f->Fstartline.Slinnum = loc.linnum;
	    if (endloc.linnum)
		f->Fendline.Slinnum = endloc.linnum;
	    else
		f->Fendline.Slinnum = loc.linnum;
	    t = type->toCtype();
	}

	mangle_t msave = t->Tmangle;
	if (isMain())
	{
	    t->Tty = TYnfunc;
	    t->Tmangle = mTYman_c;
	}
	else
	{
	    switch (linkage)
	    {
		case LINKwindows:
		    t->Tmangle = mTYman_std;
		    break;

		case LINKpascal:
		    t->Tty = TYnpfunc;
		    t->Tmangle = mTYman_pas;
		    break;

		case LINKc:
		    t->Tmangle = mTYman_c;
		    break;

		case LINKd:
		    t->Tmangle = mTYman_d;
		    break;

		case LINKcpp:
		    t->Tmangle = mTYman_cpp;
		    break;

		default:
		    printf("linkage = %d\n", linkage);
		    assert(0);
	    }
	}
	if (msave)
	    assert(msave == t->Tmangle);
	//printf("Tty = %d, mangle = x%x\n", t->Tty, t->Tmangle);
	t->Tcount++;
	s->Stype = t;
        //s->Sfielddef = this;

	csym = s;
    }
    return csym;
}

/*************************************
 */

Symbol *FuncDeclaration::toThunkSymbol(int offset)
{
    Symbol *sthunk;

    toSymbol();

#if 0
    char *id;
    char *n;
    type *t;

    n = sym->Sident;
    id = (char *) alloca(8 + 5 + strlen(n) + 1);
    sprintf(id,"_thunk%d__%s", offset, n);
    s = symbol_calloc(id);
    slist_add(s);
    s->Stype = csym->Stype;
    s->Stype->Tcount++;
#endif
    sthunk = symbol_generate(SCstatic, csym->Stype);
    sthunk->Sflags |= SFLimplem;
    cod3_thunk(sthunk, csym, 0, TYnptr, -offset, -1, 0);
    return sthunk;
}


/****************************************
 * Create a static symbol we can hang DT initializers onto.
 */

Symbol *static_sym()
{
    Symbol *s;
    type *t;

    t = type_alloc(TYint);
    t->Tcount++;
    s = symbol_calloc("internal");
    s->Sclass = SCstatic;
    s->Sfl = FLextern;
    s->Sflags |= SFLnodebug;
    s->Stype = t;
#if ELFOBJ // Burton
    s->Sseg = DATA;
#endif /* ELFOBJ */
    slist_add(s);
    return s;
}

/**************************************
 * Fake a struct symbol.
 */

Classsym *fake_classsym(char *name)
{   TYPE *t;
    Classsym *scc;

    scc = (Classsym *)symbol_calloc("ClassInfo");
    scc->Sclass = SCstruct;
    scc->Sstruct = struct_calloc();
    scc->Sstruct->Sstructalign = 8;
    //scc->Sstruct->ptrtype = TYnptr;
    scc->Sstruct->Sflags = STRglobal;

    t = type_alloc(TYstruct);
    t->Tflags |= TFsizeunknown | TFforward;
    t->Ttag = scc;		// structure tag name
    assert(t->Tmangle == 0);
    t->Tmangle = mTYman_c;
    t->Tcount++;
    scc->Stype = t;
    slist_add(scc);
    return scc;
}

/*************************************
 * Create the "ClassInfo" symbol
 */

static Classsym *scc;

Symbol *ClassDeclaration::toSymbol()
{
    if (!csym)
    {
	Symbol *s;

	if (!scc)
	    scc = fake_classsym("ClassInfo");

	s = toSymbolX("_Class_", SCextern, scc->Stype);
	s->Sfl = FLextern;
	s->Sflags |= SFLnodebug;
	csym = s;
	slist_add(s);
    }
    return csym;
}

/*************************************
 * Create the "InterfaceInfo" symbol
 */

Symbol *InterfaceDeclaration::toSymbol()
{
    if (!csym)
    {
	Symbol *s;

	if (!scc)
	    scc = fake_classsym("ClassInfo");

	s = toSymbolX("_Interface_", SCextern, scc->Stype);
	s->Sfl = FLextern;
	s->Sflags |= SFLnodebug;
	csym = s;
	slist_add(s);
    }
    return csym;
}

/*************************************
 * Create the "ModuleInfo" symbol
 */

Symbol *Module::toSymbol()
{
    if (!csym)
    {
	Symbol *s;
	static Classsym *scc;

	if (!scc)
	    scc = fake_classsym("ModuleInfo");

	s = toSymbolX("_ModuleInfo_", SCextern, scc->Stype);
	s->Sfl = FLextern;
	s->Sflags |= SFLnodebug;
	csym = s;
	slist_add(s);
    }
    return csym;
}

/*************************************
 * This is accessible via the ClassData, but since it is frequently
 * needed directly (like for rtti comparisons), make it directly accessible.
 */

Symbol *ClassDeclaration::toVtblSymbol()
{
    if (!vtblsym)
    {
	Symbol *s;
	TYPE *t;

	if (!csym)
	    toSymbol();

	t = type_alloc(TYnptr | mTYconst);
	t->Tnext = tsvoid;
	t->Tnext->Tcount++;
	t->Tmangle = mTYman_c;
	s = toSymbolX("_vtbl_", SCextern, t);
	s->Sflags |= SFLnodebug;
	s->Sfl = FLextern;
	vtblsym = s;
	slist_add(s);
    }
    return vtblsym;
}

/**********************************
 * Create the static initializer for the struct/class.
 */

Symbol *AggregateDeclaration::toInitializer()
{
    char *id;
    char *n;
    Symbol *s;
    Classsym *stag;

    if (!sinit)
    {
	n = mangle();
	stag = fake_classsym(n);

	id = (char *) alloca(6 + strlen(n) + 1);
	sprintf(id,"_init_%s",n);
	s = symbol_calloc(id);
	s->Stype = stag->Stype;
	s->Sclass = SCextern;
	s->Sfl = FLextern;
	s->Sflags |= SFLnodebug;
	slist_add(s);
	sinit = s;
    }
    return sinit;
}


/******************************************
 */

Symbol *Module::toModuleAssert()
{
    if (!massert)
    {
	type *t;

	t = type_alloc(TYjfunc);
	t->Tflags |= TFprototype | TFfixed;
	t->Tmangle = mTYman_d;
	t->Tnext = tsvoid;
	tsvoid->Tcount++;

	massert = toSymbolX("_assert_", SCextern, t);
	massert->Sfl = FLextern;
	massert->Sflags |= SFLnodebug;
	slist_add(massert);
    }
    return massert;
}

/******************************************
 */

Symbol *Module::toModuleArray()
{
    if (!marray)
    {
	type *t;

	t = type_alloc(TYjfunc);
	t->Tflags |= TFprototype | TFfixed;
	t->Tmangle = mTYman_d;
	t->Tnext = tsvoid;
	tsvoid->Tcount++;

	marray = toSymbolX("_array_", SCextern, t);
	marray->Sfl = FLextern;
	marray->Sflags |= SFLnodebug;
	slist_add(marray);
    }
    return marray;
}

/********************************************
 * Determine the right symbol to look up
 * an associative array element.
 * Input:
 *	flags	0	don't add value signature
 *		1	add value signature
 */

Symbol *TypeAArray::aaGetSymbol(char *func, int flags)
#if __DMC__
    __in
    {
	assert(func);
	assert((flags & ~1) == 0);
    }
    __out (result)
    {
	assert(result);
    }
    __body
#endif
    {
	int sz;
	char *id;
	type *t;
	Symbol *s;
	int i;

	// Dumb linear symbol table - should use associative array!
	static Array *sarray = NULL;

	//printf("aaGetSymbol(func = '%s', flags = %d, key = %p)\n", func, flags, key);
#if 0
	OutBuffer buf;
	key->toKeyBuffer(&buf);

	sz = next->size();		// it's just data, so we only care about the size
	sz = (sz + 3) & ~3;		// reduce proliferation of library routines
	id = (char *)alloca(3 + strlen(func) + buf.offset + sizeof(sz) * 3 + 1);
	buf.writeByte(0);
	if (flags & 1)
	    sprintf(id, "_aa%s%s%d", func, buf.data, sz);
	else
	    sprintf(id, "_aa%s%s", func, buf.data);
#else
	id = (char *)alloca(3 + strlen(func) + 1);
	sprintf(id, "_aa%s", func);
#endif
	if (!sarray)
	    sarray = new Array();

	// See if symbol is already in sarray
	for (i = 0; i < sarray->dim; i++)
	{   s = (Symbol *)sarray->data[i];
	    if (strcmp(id, s->Sident) == 0)
		return s;			// use existing Symbol
	}

	// Create new Symbol

	s = symbol_calloc(id);
	slist_add(s);
	s->Sclass = SCextern;
	s->Ssymnum = -1;
	symbol_func(s);

	t = type_alloc(TYnfunc);
	t->Tflags = TFprototype | TFfixed;
	t->Tmangle = mTYman_c;
	t->Tparamtypes = NULL;
	t->Tnext = next->toCtype();
	t->Tnext->Tcount++;
	t->Tcount++;
	s->Stype = t;

	sarray->push(s);			// remember it
	return s;
    }

