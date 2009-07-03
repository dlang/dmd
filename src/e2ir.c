
// Compiler implementation of the D programming language
// Copyright (c) 1999-2008 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include	<stdio.h>
#include	<string.h>
#include	<time.h>
#include	<complex.h>

#include	"lexer.h"
#include	"expression.h"
#include	"mtype.h"
#include	"dsymbol.h"
#include	"declaration.h"
#include	"enum.h"
#include	"aggregate.h"
#include	"attrib.h"
#include	"module.h"
#include	"init.h"
#include	"template.h"

#if _WIN32
#include	"..\tk\mem.h"	// for mem_malloc
#elif linux
#include	"../tk/mem.h"	// for mem_malloc
#endif

#include	"cc.h"
#include	"el.h"
#include	"oper.h"
#include	"global.h"
#include	"code.h"
#include	"type.h"
#include	"dt.h"
#include	"irstate.h"
#include	"id.h"
#include	"type.h"
#include	"toir.h"

static char __file__[] = __FILE__;	/* for tassert.h		*/
#include	"tassert.h"


elem *addressElem(elem *e, Type *t);
elem *array_toPtr(Type *t, elem *e);
elem *bit_assign(enum OPER op, elem *eb, elem *ei, elem *ev, int result);
elem *bit_read(elem *eb, elem *ei, int result);
elem *exp2_copytotemp(elem *e);

#define el_setLoc(e,loc)	((e)->Esrcpos.Sfilename = (loc).filename, \
				 (e)->Esrcpos.Slinnum = (loc).linnum)

/************************************
 * Call a function.
 */

elem *callfunc(Loc loc,
	IRState *irs,
	int directcall,		// 1: don't do virtual call
	Type *tret,		// return type
	elem *ec,		// evaluates to function address
	Type *ectype,		// original type of ec
	FuncDeclaration *fd,	// if !=NULL, this is the function being called
	Type *t,		// TypeDelegate or TypeFunction for this function
	elem *ehidden,		// if !=NULL, this is the 'hidden' argument
	Array *arguments)
{
    elem *ep;
    elem *e;
    elem *ethis = NULL;
    elem *eside = NULL;
    int i;
    tym_t ty;
    tym_t tyret;
    enum RET retmethod;
    int reverse;
    TypeFunction *tf;
    int op;

#if 0
    printf("callfunc(directcall = %d, tret = '%s', ec = %p, fd = %p)\n",
	directcall, tret->toChars(), ec, fd);
    printf("ec: "); elem_print(ec);
    if (fd)
	printf("fd = '%s'\n", fd->toChars());
#endif

    t = t->toBasetype();
    if (t->ty == Tdelegate)
    {
	// A delegate consists of:
	//	{ Object *this; Function *funcptr; }
	assert(!fd);
	assert(t->nextOf()->ty == Tfunction);
	tf = (TypeFunction *)(t->nextOf());
	ethis = ec;
	ec = el_same(&ethis);
	ethis = el_una(OP64_32, TYnptr, ethis);	// get this
	ec = array_toPtr(t, ec);		// get funcptr
	ec = el_una(OPind, tf->totym(), ec);
    }
    else
    {	assert(t->ty == Tfunction);
	tf = (TypeFunction *)(t);
    }
    retmethod = tf->retStyle();
    ty = ec->Ety;
    if (fd)
	ty = fd->toSymbol()->Stype->Tty;
    reverse = tyrevfunc(ty);
    ep = NULL;
    if (arguments)
    {
	// j=1 if _arguments[] is first argument
	int j = (tf->linkage == LINKd && tf->varargs == 1);

	for (i = 0; i < arguments->dim ; i++)
	{   Expression *arg;
	    elem *ea;

	    arg = (Expression *)arguments->data[i];
	    //printf("\targ[%d]: %s\n", i, arg->toChars());

	    size_t nparams = Argument::dim(tf->parameters);
	    if (i - j < nparams && i >= j)
	    {
		Argument *p = Argument::getNth(tf->parameters, i - j);

		if (p->storageClass & (STCout | STCref))
		{
		    // Convert argument to a pointer,
		    // use AddrExp::toElem()
		    Expression *ae = arg->addressOf(NULL);
		    ea = ae->toElem(irs);
		    goto L1;
		}
	    }
	    ea = arg->toElem(irs);
	L1:
	    if (ea->Ety == TYstruct)
	    {
		ea = el_una(OPstrpar, TYstruct, ea);
		ea->Enumbytes = ea->E1->Enumbytes;
		assert(ea->Enumbytes);
	    }
	    if (reverse)
		ep = el_param(ep,ea);
	    else
		ep = el_param(ea,ep);
	}
    }

    if (retmethod == RETstack)
    {
	if (!ehidden)
	{   // Don't have one, so create one
	    type *t;

	    if (tf->next->toBasetype()->ty == Tstruct)
		t = tf->next->toCtype();
	    else
		t = type_fake(tf->next->totym());
	    Symbol *stmp = symbol_genauto(t);
	    ehidden = el_ptr(stmp);
	}
	if (ep)
	{
#if 0 // BUG: implement
	    if (reverse && type_mangle(tfunc) == mTYman_cpp)
		ep = el_param(ehidden,ep);
	    else
#endif
		ep = el_param(ep,ehidden);
	}
	else
	    ep = ehidden;
	ehidden = NULL;
    }
    assert(ehidden == NULL);

    if (fd && fd->isMember2())
    {
	InterfaceDeclaration *intd;
	Symbol *sfunc;
	AggregateDeclaration *ad;

	ad = fd->isThis();
	if (ad)
	{
	    ethis = ec;
	    if (ad->handle->ty == Tpointer && tybasic(ec->Ety) != TYnptr)
	    {
		ethis = addressElem(ec, ectype);
	    }
	}
	else
	{
	    // Evaluate ec for side effects
	    eside = ec;
	}
	sfunc = fd->toSymbol();

	if (!fd->isVirtual() ||
	    directcall ||		// BUG: fix
	    fd->isFinal()
	   )
	{
	    // make static call
	    ec = el_var(sfunc);
	}
	else
	{
	    // make virtual call
	    elem *ev;
	    unsigned vindex;

	    assert(ethis);
	    ev = el_same(&ethis);
	    ev = el_una(OPind, TYnptr, ev);
	    vindex = fd->vtblIndex;

	    // Build *(ev + vindex * 4)
	    ec = el_bin(OPadd,TYnptr,ev,el_long(TYint, vindex * 4));
	    ec = el_una(OPind,TYnptr,ec);
	    ec = el_una(OPind,tybasic(sfunc->Stype->Tty),ec);
	}
    }
    else if (fd && fd->isNested())
    {
	assert(!ethis);
	ethis = getEthis(0, irs, fd);

    }

    ep = el_param(ep, ethis);

    tyret = tret->totym();

    // Look for intrinsic functions
    if (ec->Eoper == OPvar && (op = intrinsic_op(ec->EV.sp.Vsym->Sident)) != -1)
    {
	el_free(ec);
	if (OTbinary(op))
	{
	    ep->Eoper = op;
	    ep->Ety = tyret;
	    e = ep;
	    if (op == OPscale)
	    {	elem *et;

		et = e->E1;
		e->E1 = el_una(OPs32_d, TYdouble, e->E2);
		e->E1 = el_una(OPd_ld, TYldouble, e->E1);
		e->E2 = et;
		e->Ety = tyret;
	    }
	}
	else
	    e = el_una(op,tyret,ep);
    }
    else if (ep)
	e = el_bin(OPcall,tyret,ec,ep);
    else
	e = el_una(OPucall,tyret,ec);

    if (retmethod == RETstack)
    {
	e->Ety = TYnptr;
	e = el_una(OPind, tyret, e);
    }
    if (tybasic(tyret) == TYstruct)
    {
	e->Enumbytes = tret->size();
    }
    e = el_combine(eside, e);
    return e;
}

/*******************************************
 * Take address of an elem.
 */

elem *addressElem(elem *e, Type *t)
{
    elem **pe;

    //printf("addressElem()\n");

    for (pe = &e; (*pe)->Eoper == OPcomma; pe = &(*pe)->E2)
	;
    if ((*pe)->Eoper != OPvar && (*pe)->Eoper != OPind)
    {	Symbol *stmp;
	elem *eeq;
	elem *e = *pe;
	type *tx;

	// Convert to ((tmp=e),tmp)
	TY ty;
	if (t && ((ty = t->toBasetype()->ty) == Tstruct || ty == Tsarray))
	    tx = t->toCtype();
	else
	    tx = type_fake(e->Ety);
	stmp = symbol_genauto(tx);
	eeq = el_bin(OPeq,e->Ety,el_var(stmp),e);
	if (e->Ety == TYstruct)
	{
	    eeq->Eoper = OPstreq;
	    eeq->Enumbytes = e->Enumbytes;
	}
	else if (e->Ety == TYarray)
	{
	    eeq->Eoper = OPstreq;
	    eeq->Ejty = eeq->Ety = TYstruct;
	    eeq->Enumbytes = t->size();
	}
	*pe = el_bin(OPcomma,e->Ety,eeq,el_var(stmp));
    }
    e = el_una(OPaddr,TYnptr,e);
    return e;
}

/*****************************************
 * Convert array to a pointer to the data.
 */

elem *array_toPtr(Type *t, elem *e)
{
    //printf("array_toPtr()\n");
    //elem_print(e);
    t = t->toBasetype();
    switch (t->ty)
    {
	case Tpointer:
	    break;

	case Tarray:
	case Tdelegate:
	    if (e->Eoper == OPcomma)
	    {
		e->Ety = TYnptr;
		e->E2 = array_toPtr(t, e->E2);
	    }
	    else if (e->Eoper == OPpair)
	    {
		e->Eoper = OPcomma;
		e->Ety = TYnptr;
	    }
	    else
	    {
#if 1
		e = el_una(OPmsw, TYnptr, e);
#else
		e = el_una(OPaddr, TYnptr, e);
		e = el_bin(OPadd, TYnptr, e, el_long(TYint, 4));
		e = el_una(OPind, TYnptr, e);
#endif
	    }
	    break;

	case Tsarray:
	    e = el_una(OPaddr, TYnptr, e);
	    break;

	default:
	    t->print();
	    assert(0);
    }
    return e;
}

/*****************************************
 * Convert array to a dynamic array.
 */

elem *array_toDarray(Type *t, elem *e)
{
    unsigned dim;
    elem *ef = NULL;
    elem *ex;

    //printf("array_toDarray(t = %s)\n", t->toChars());
    //elem_print(e);
    t = t->toBasetype();
    switch (t->ty)
    {
	case Tarray:
	    break;

	case Tsarray:
	    e = el_una(OPaddr, TYnptr, e);
	    dim = ((TypeSArray *)t)->dim->toInteger();
	    e = el_pair(TYullong, el_long(TYint, dim), e);
	    break;

	default:
	L1:
	    switch (e->Eoper)
	    {
		case OPconst:
		{
		    size_t len = tysize[tybasic(e->Ety)];
		    elem *es = el_calloc();
		    es->Eoper = OPstring;

		    // Match MEM_PH_FREE for OPstring in ztc\el.c
		    es->EV.ss.Vstring = (char *)mem_malloc(len);
		    memcpy(es->EV.ss.Vstring, &e->EV, len);

		    es->EV.ss.Vstrlen = len;
		    es->Ety = TYnptr;
		    e = es;
		    break;
		}

		case OPvar:
		    e = el_una(OPaddr, TYnptr, e);
		    break;

		case OPcomma:
		    ef = el_combine(ef, e->E1);
		    ex = e;
		    e = e->E2;
		    ex->E1 = NULL;
		    ex->E2 = NULL;
		    el_free(ex);
		    goto L1;

		case OPind:
		    ex = e;
		    e = e->E1;
		    ex->E1 = NULL;
		    ex->E2 = NULL;
		    el_free(ex);
		    break;

		default:
		{
		    // Copy expression to a variable and take the
		    // address of that variable.
		    Symbol *stmp;
		    tym_t ty = tybasic(e->Ety);

		    if (ty == TYstruct)
		    {
			if (e->Enumbytes == 4)
			    ty = TYint;
			else if (e->Enumbytes == 8)
			    ty = TYllong;
		    }
		    e->Ety = ty;
		    stmp = symbol_genauto(type_fake(ty));
		    e = el_bin(OPeq, e->Ety, el_var(stmp), e);
		    e = el_bin(OPcomma, TYnptr, e, el_una(OPaddr, TYnptr, el_var(stmp)));
		    break;
		}
	    }
	    dim = 1;
	    e = el_pair(TYullong, el_long(TYint, dim), e);
	    break;
    }
    return el_combine(ef, e);
}

/*****************************************
 * Evaluate elem and convert to dynamic array.
 */

elem *eval_Darray(IRState *irs, Expression *e)
{
    elem *ex;

    ex = e->toElem(irs);
    return array_toDarray(e->type, ex);
}

/************************************
 */

elem *sarray_toDarray(Type *tfrom, Type *tto, elem *e)
{
    //printf("sarray_toDarray()\n");
    //elem_print(e);

    elem *elen;
    unsigned dim = ((TypeSArray *)tfrom)->dim->toInteger();

    if (tto)
    {
	unsigned fsize = tfrom->nextOf()->size();
	unsigned tsize = tto->nextOf()->size();

	if ((dim * fsize) % tsize != 0)
	{
	  Lerr:
	    error((Loc)0, "cannot cast %s to %s since sizes don't line up", tfrom->toChars(), tto->toChars());
	}
	dim = (dim * fsize) / tsize;
    }
  L1:
    elen = el_long(TYint, dim);
    e = el_una(OPaddr, TYnptr, e);
    e = el_pair(TYullong, elen, e);
    return e;
}

/*******************************************
 * Set an array pointed to by eptr to evalue:
 *	eptr[0..edim] = evalue;
 * Input:
 *	eptr	where to write the data to
 *	evalue	value to write
 *	edim	number of times to write evalue to eptr[]
 *	tb	type of evalue
 */

elem *setArray(elem *eptr, elem *edim, Type *tb, elem *evalue)
{   int r;
    elem *e;
    int sz = tb->size();

    if (tb->ty == Tfloat80 || tb->ty == Timaginary80)
	r = RTLSYM_MEMSET80;
    else if (tb->ty == Tcomplex80)
	r = RTLSYM_MEMSET160;
    else if (tb->ty == Tcomplex64)
	r = RTLSYM_MEMSET128;
    else
    {
	switch (sz)
	{
	    case 1:	 r = RTLSYM_MEMSET8;	break;
	    case 2:	 r = RTLSYM_MEMSET16;	break;
	    case 4:	 r = RTLSYM_MEMSET32;	break;
	    case 8:	 r = RTLSYM_MEMSET64;	break;

	    default:
		r = RTLSYM_MEMSETN;
		evalue = el_una(OPaddr, TYnptr, evalue);
		elem *esz = el_long(TYint, sz);
		e = el_params(esz, edim, evalue, eptr, NULL);
		e = el_bin(OPcall,TYnptr,el_var(rtlsym[r]),e);
		return e;
	}
    }
    if (sz > 1 && sz <= 8 &&
	evalue->Eoper == OPconst && el_allbits(evalue, 0))
    {
	r = RTLSYM_MEMSET8;
	edim = el_bin(OPmul, TYuint, edim, el_long(TYuint, sz));
    }

    if (evalue->Ety == TYstruct)
    {
	evalue = el_una(OPstrpar, TYstruct, evalue);
	evalue->Enumbytes = evalue->E1->Enumbytes;
	assert(evalue->Enumbytes);
    }

    // Be careful about parameter side effect ordering
    if (r == RTLSYM_MEMSET8)
    {
	e = el_param(edim, evalue);
	e = el_bin(OPmemset,TYnptr,eptr,e);
    }
    else
    {
	e = el_params(edim, evalue, eptr, NULL);
	e = el_bin(OPcall,TYnptr,el_var(rtlsym[r]),e);
    }
    return e;
}

/***************************************
 */

elem *Expression::toElem(IRState *irs)
{
    print();
    assert(0);
    return NULL;
}

/***************************************
 */

elem *VarExp::toElem(IRState *irs)
{   Symbol *s;
    elem *e;
    tym_t tym;
    Type *tb = type->toBasetype();
    FuncDeclaration *fd;

    //printf("VarExp::toElem('%s') %p\n", toChars(), this);
    //printf("\tparent = '%s'\n", var->parent ? var->parent->toChars() : "null");
    if (var->needThis())
    {
	error("need 'this' to access member %s", toChars());
	return el_long(TYint, 0);
    }
    s = var->toSymbol();
    fd = NULL;
    if (var->toParent2())
	fd = var->toParent2()->isFuncDeclaration();

    int nrvo = 0;
    if (fd && fd->nrvo_can && fd->nrvo_var == var)
    {
	s = fd->shidden;
	nrvo = 1;
    }

    if (s->Sclass == SCauto || s->Sclass == SCparameter)
    {
	if (fd && fd != irs->getFunc())
	{   // 'var' is a variable in an enclosing function.
	    elem *ethis;
	    int offset;

	    ethis = getEthis(loc, irs, fd);
	    ethis = el_una(OPaddr, TYnptr, ethis);

	    offset = s->Soffset;

	    /* If fd is a non-static member function of a class or struct,
	     * then ethis isn't the frame pointer.
	     * ethis is the 'this' pointer to the class/struct instance.
	     * We must offset it.
	     */
	    if (fd->vthis)
	    {
		offset -= fd->vthis->toSymbol()->Soffset;
	    }
	    //printf("\tSoffset = x%x, sthis->Soffset = x%x\n", s->Soffset, irs->sthis->Soffset);

	    ethis = el_bin(OPadd, TYnptr, ethis, el_long(TYnptr, offset));
	    e = el_una(OPind, 0, ethis);
	    if ((var->isParameter() && tb->ty == Tsarray) || var->isOut() || var->isRef())
		goto L2;
	    goto L1;
	}
    }

    if (s->Sclass == SCauto && s->Ssymnum == -1)
    {
	//printf("\tadding symbol\n");
	symbol_add(s);
    }
    if (var->isImportedSymbol())
    {
	e = el_var(var->toImport());
	e = el_una(OPind,s->ty(),e);
    }
    else if ((var->isParameter() && tb->ty == Tsarray) || var->isOut() || var->isRef())
    {	// Static arrays are really passed as pointers to the array
	// Out parameters are really references
	e = el_var(s);
L2:
	e->Ety = TYnptr;
	e = el_una(OPind, s->ty(), e);
    }
    else
	e = el_var(s);
L1:
    if (nrvo)
    {
	e->Ety = TYnptr;
	e = el_una(OPind, 0, e);
    }
    if (tb->ty == Tfunction)
    {
	tym = s->Stype->Tty;
    }
    else
	tym = type->totym();
    e->Ejty = e->Ety = tym;
    if (tybasic(tym) == TYstruct)
    {
	e->Enumbytes = type->size();
    }
    else if (tybasic(tym) == TYarray)
    {
	e->Ejty = e->Ety = TYstruct;
	e->Enumbytes = type->size();
    }
    el_setLoc(e,loc);
    return e;
}

/*****************************************
 */

elem *FuncExp::toElem(IRState *irs)
{
    elem *e;
    Symbol *s;

    //printf("FuncExp::toElem() %s\n", toChars());
    s = fd->toSymbol();
    e = el_ptr(s);
    if (fd->isNested())
    {
	elem *ethis = getEthis(loc, irs, fd);
	e = el_pair(TYullong, ethis, e);
    }

    irs->deferToObj->push(fd);
    el_setLoc(e,loc);
    return e;
}

/**************************************
 */

elem *Dsymbol_toElem(Dsymbol *s, IRState *irs)
{
    elem *e = NULL;
    Symbol *sp;
    AttribDeclaration *ad;
    VarDeclaration *vd;
    ClassDeclaration *cd;
    StructDeclaration *sd;
    FuncDeclaration *fd;
    TemplateMixin *tm;
    TupleDeclaration *td;
    TypedefDeclaration *tyd;

    //printf("Dsymbol_toElem() %s\n", s->toChars());
    ad = s->isAttribDeclaration();
    if (ad)
    {
	Array *decl = ad->include(NULL, NULL);
	if (decl && decl->dim)
	{
	    for (size_t i = 0; i < decl->dim; i++)
	    {
		s = (Dsymbol *)decl->data[i];
		e = el_combine(e, Dsymbol_toElem(s, irs));
	    }
	}
    }
    else if ((vd = s->isVarDeclaration()) != NULL)
    {
	s = s->toAlias();
	if (s != vd)
	    return Dsymbol_toElem(s, irs);
	if (vd->isStatic() || vd->isConst() || vd->storage_class & STCextern)
	    vd->toObjFile(0);
	else
	{
	    sp = s->toSymbol();
	    symbol_add(sp);
	    //printf("\tadding symbol '%s'\n", sp->Sident);
	    if (vd->init)
	    {
		ExpInitializer *ie;

		ie = vd->init->isExpInitializer();
		if (ie)
		    e = ie->exp->toElem(irs);
	    }
	}
    }
    else if ((cd = s->isClassDeclaration()) != NULL)
    {
	irs->deferToObj->push(s);
	//sd->toObjFile();
    }
    else if ((sd = s->isStructDeclaration()) != NULL)
    {
	irs->deferToObj->push(sd);
	//sd->toObjFile();
    }
    else if ((fd = s->isFuncDeclaration()) != NULL)
    {
	//printf("function %s\n", fd->toChars());
	irs->deferToObj->push(fd);
	//fd->toObjFile();
    }
    else if ((tm = s->isTemplateMixin()) != NULL)
    {
	//printf("%s\n", tm->toChars());
	if (tm->members)
	{
	    for (size_t i = 0; i < tm->members->dim; i++)
	    {
		Dsymbol *sm = (Dsymbol *)tm->members->data[i];
		e = el_combine(e, Dsymbol_toElem(sm, irs));
	    }
	}
    }
    else if ((td = s->isTupleDeclaration()) != NULL)
    {
	for (size_t i = 0; i < td->objects->dim; i++)
	{   Object *o = (Object *)td->objects->data[i];
	    if (o->dyncast() == DYNCAST_EXPRESSION)
	    {	Expression *eo = (Expression *)o;
		if (eo->op == TOKdsymbol)
		{   DsymbolExp *se = (DsymbolExp *)eo;
		    e = el_combine(e, Dsymbol_toElem(se->s, irs));
		}
	    }
	}
    }
    else if ((tyd = s->isTypedefDeclaration()) != NULL)
    {
	irs->deferToObj->push(tyd);
    }
    return e;
}

elem *DeclarationExp::toElem(IRState *irs)
{   elem *e;

    //printf("DeclarationExp::toElem() %s\n", toChars());
    e = Dsymbol_toElem(declaration, irs);
    return e;
}

/***************************************
 */

elem *ThisExp::toElem(IRState *irs)
{   elem *ethis;
    FuncDeclaration *fd;

    //printf("ThisExp::toElem()\n");
    assert(irs->sthis);

    if (var)
    {
	assert(var->parent);
	fd = var->toParent2()->isFuncDeclaration();
	assert(fd);
	ethis = getEthis(loc, irs, fd);
    }
    else
	ethis = el_var(irs->sthis);

    el_setLoc(ethis,loc);
    return ethis;
}

/***************************************
 */

elem *IntegerExp::toElem(IRState *irs)
{   elem *e;

    e = el_long(type->totym(), value);
    el_setLoc(e,loc);
    return e;
}

/***************************************
 */

elem *RealExp::toElem(IRState *irs)
{   union eve c;
    tym_t ty;

    //printf("RealExp::toElem(%p)\n", this);
    memset(&c, 0, sizeof(c));
    ty = type->toBasetype()->totym();
    switch (ty)
    {
	case TYfloat:
	case TYifloat:
	    c.Vfloat = value;
	    break;

	case TYdouble:
	case TYidouble:
	    c.Vdouble = value;
	    break;

	case TYldouble:
	case TYildouble:
	    c.Vldouble = value;
	    break;

	default:
	    print();
	    type->print();
	    type->toBasetype()->print();
	    printf("ty = %d, tym = %x\n", type->ty, ty);
	    assert(0);
    }
    return el_const(ty, &c);
}


/***************************************
 */

elem *ComplexExp::toElem(IRState *irs)
{   union eve c;
    tym_t ty;
    real_t re;
    real_t im;

    re = creall(value);
    im = cimagl(value);

    memset(&c, 0, sizeof(c));
    ty = type->totym();
    switch (ty)
    {
	case TYcfloat:
	    c.Vcfloat.re = (float) re;
	    c.Vcfloat.im = (float) im;
	    break;

	case TYcdouble:
	    c.Vcdouble.re = (double) re;
	    c.Vcdouble.im = (double) im;
	    break;

	case TYcldouble:
	    c.Vcldouble.re = re;
	    c.Vcldouble.im = im;
	    break;

	default:
	    assert(0);
    }
    return el_const(ty, &c);
}

/***************************************
 */

elem *NullExp::toElem(IRState *irs)
{
    return el_long(type->totym(), 0);
}

/***************************************
 */

struct StringTab
{
    Module *m;		// module we're generating code for
    Symbol *si;
    void *string;
    size_t sz;
    size_t len;
};

#define STSIZE 16
StringTab stringTab[STSIZE];
size_t stidx;

static Symbol *assertexp_sfilename = NULL;
static char *assertexp_name = NULL;
static Module *assertexp_mn = NULL;

void clearStringTab()
{
    //printf("clearStringTab()\n");
    memset(stringTab, 0, sizeof(stringTab));
    stidx = 0;

    assertexp_sfilename = NULL;
    assertexp_name = NULL;
    assertexp_mn = NULL;
}

elem *StringExp::toElem(IRState *irs)
{
    elem *e;
    Type *tb= type->toBasetype();


#if 0
    printf("StringExp::toElem() %s, type = %s\n", toChars(), type->toChars());
#endif

    if (tb->ty == Tarray)
    {
	Symbol *si;
	dt_t *dt;
	StringTab *st;

#if 0
	printf("irs->m = %p\n", irs->m);
	printf(" m   = %s\n", irs->m->toChars());
	printf(" len = %d\n", len);
	printf(" sz  = %d\n", sz);
#endif
	for (size_t i = 0; i < STSIZE; i++)
	{
	    st = &stringTab[(stidx + i) % STSIZE];
	    //if (!st->m) continue;
	    //printf(" st.m   = %s\n", st->m->toChars());
	    //printf(" st.len = %d\n", st->len);
	    //printf(" st.sz  = %d\n", st->sz);
	    if (st->m == irs->m &&
		st->si &&
		st->len == len &&
		st->sz == sz &&
		memcmp(st->string, string, sz * len) == 0)
	    {
		//printf("use cached value\n");
		si = st->si;	// use cached value
		goto L1;
	    }
	}

	stidx = (stidx + 1) % STSIZE;
	st = &stringTab[stidx];

	dt = NULL;
	toDt(&dt);

	si = symbol_generate(SCstatic,type_fake(TYdarray));
	si->Sdt = dt;
	si->Sfl = FLdata;
#if ELFOBJ // Burton
	si->Sseg = CDATA;
#endif
	outdata(si);

	st->m = irs->m;
	st->si = si;
	st->string = string;
	st->len = len;
	st->sz = sz;
    L1:
	e = el_var(si);
    }
    else if (tb->ty == Tsarray)
    {
	Symbol *si;
	dt_t *dt = NULL;

	toDt(&dt);
	dtnzeros(&dt, sz);		// leave terminating 0

	si = symbol_generate(SCstatic,type_allocn(TYarray, tschar));
	si->Sdt = dt;
	si->Sfl = FLdata;

#if ELFOBJ // Burton
	si->Sseg = CDATA;
#endif
	outdata(si);

	e = el_var(si);
    }
    else if (tb->ty == Tpointer)
    {
	e = el_calloc();
	e->Eoper = OPstring;
#if 1
	// Match MEM_PH_FREE for OPstring in ztc\el.c
	e->EV.ss.Vstring = (char *)mem_malloc((len + 1) * sz);
	memcpy(e->EV.ss.Vstring, string, (len + 1) * sz);
#else
	e->EV.ss.Vstring = (char *)string;
#endif
	e->EV.ss.Vstrlen = (len + 1) * sz;
	e->Ety = TYnptr;
    }
    else
    {
	printf("type is %s\n", type->toChars());
	assert(0);
    }
    el_setLoc(e,loc);
    return e;
}

elem *NewExp::toElem(IRState *irs)
{   elem *e;
    Type *t;
    Type *ectype;

    //printf("NewExp::toElem() %s\n", toChars());
    t = type->toBasetype();
    //printf("\ttype = %s\n", t->toChars());
    if (t->ty == Tclass)
    {
	Symbol *csym;

	t = newtype->toBasetype();
	assert(t->ty == Tclass);
	TypeClass *tclass = (TypeClass *)(t);
	ClassDeclaration *cd = tclass->sym;

	/* Things to do:
	 * 1) ex: call allocator
	 * 2) ey: set vthis for nested classes
	 * 3) ez: call constructor
	 */

	elem *ex = NULL;
	elem *ey = NULL;
	elem *ez = NULL;

	if (allocator || onstack)
	{   elem *ei;
	    Symbol *si;

	    if (onstack)
	    {
		/* Create an instance of the class on the stack,
		 * and call it stmp.
		 * Set ex to be the &stmp.
		 */
		Symbol *s = symbol_calloc(tclass->sym->toChars());
		s->Sclass = SCstruct;
		s->Sstruct = struct_calloc();
		s->Sstruct->Sflags |= 0;
		s->Sstruct->Salignsize = tclass->sym->alignsize;
		s->Sstruct->Sstructalign = tclass->sym->structalign;
		s->Sstruct->Sstructsize = tclass->sym->structsize;

		::type *tc = type_alloc(TYstruct);
		tc->Ttag = (Classsym *)s;                // structure tag name
		tc->Tcount++;
		s->Stype = tc;

		Symbol *stmp = symbol_genauto(tc);
		ex = el_ptr(stmp);
	    }
	    else
	    {
		ex = el_var(allocator->toSymbol());
		ex = callfunc(loc, irs, 1, type, ex, allocator->type,
			allocator, allocator->type, NULL, newargs);
	    }

	    si = tclass->sym->toInitializer();
	    ei = el_var(si);

	    if (cd->isNested())
	    {
		ey = el_same(&ex);
		ez = el_copytree(ey);
	    }
	    else if (member)
		ez = el_same(&ex);

	    ex = el_una(OPind, TYstruct, ex);
	    ex = el_bin(OPstreq, TYnptr, ex, ei);
	    ex->Enumbytes = cd->size(loc);
	    ex = el_una(OPaddr, TYnptr, ex);
	    ectype = tclass;
	}
	else
	{
	    csym = cd->toSymbol();
	    ex = el_bin(OPcall,TYnptr,el_var(rtlsym[RTLSYM_NEWCLASS]),el_ptr(csym));
	    ectype = NULL;

	    if (cd->isNested())
	    {
		ey = el_same(&ex);
		ez = el_copytree(ey);
	    }
	    else if (member)
		ez = el_same(&ex);
//elem_print(ex);
//elem_print(ey);
//elem_print(ez);
	}

	if (thisexp)
	{   ClassDeclaration *cdthis = thisexp->type->isClassHandle();
	    assert(cdthis);
	    //printf("cd = %s\n", cd->toChars());
	    //printf("cdthis = %s\n", cdthis->toChars());
	    assert(cd->isNested());
	    int offset = 0;
	    Dsymbol *cdp = cd->toParent2();	// class we're nested in
	    elem *ethis;

//printf("member = %p\n", member);
//printf("cdp = %s\n", cdp->toChars());
//printf("cdthis = %s\n", cdthis->toChars());
	    if (cdp != cdthis)
	    {	int i = cdp->isClassDeclaration()->isBaseOf(cdthis, &offset);
		assert(i);
	    }
	    ethis = thisexp->toElem(irs);
	    if (offset)
		ethis = el_bin(OPadd, TYnptr, ethis, el_long(TYint, offset));

	    ey = el_bin(OPadd, TYnptr, ey, el_long(TYint, cd->vthis->offset));
	    ey = el_una(OPind, TYnptr, ey);
	    ey = el_bin(OPeq, TYnptr, ey, ethis);

//printf("ex: "); elem_print(ex);
//printf("ey: "); elem_print(ey);
//printf("ez: "); elem_print(ez);
	}
	else if (cd->isNested())
	{   /* Initialize cd->vthis:
	     *	*(ey + cd.vthis.offset) = this;
	     */
	    elem *ethis;
	    FuncDeclaration *thisfd = irs->getFunc();
	    int offset = 0;
	    Dsymbol *cdp = cd->toParent2();	// class/func we're nested in

	    if (cdp == thisfd)
	    {	/* Class we're new'ing is a local class in this function:
		 *	void thisfd() { class cd { } }
		 */
		if (irs->sthis)
		{
#if V2
		    if (thisfd->closureVars.dim)
#else
		    if (thisfd->nestedFrameRef)
#endif
		    {
			ethis = el_ptr(irs->sthis);
		    }
		    else
			ethis = el_var(irs->sthis);
		}
		else
		{
		    ethis = el_long(TYnptr, 0);
#if V2
		    if (thisfd->closureVars.dim)
#else
		    if (thisfd->nestedFrameRef)
#endif
		    {
			ethis->Eoper = OPframeptr;
		    }
		}
	    }
	    else if (thisfd->vthis &&
		  (cdp == thisfd->toParent2() ||
		   (cdp->isClassDeclaration() &&
		    cdp->isClassDeclaration()->isBaseOf(thisfd->toParent2()->isClassDeclaration(), &offset)
		   )
		  )
		)
	    {	/* Class we're new'ing is at the same level as thisfd
		 */
		assert(offset == 0);	// BUG: should handle this case
		ethis = el_var(irs->sthis);
	    }
	    else
	    {
		ethis = getEthis(loc, irs, cd->toParent2());
		ethis = el_una(OPaddr, TYnptr, ethis);
	    }

	    ey = el_bin(OPadd, TYnptr, ey, el_long(TYint, cd->vthis->offset));
	    ey = el_una(OPind, TYnptr, ey);
	    ey = el_bin(OPeq, TYnptr, ey, ethis);

	}

	if (member)
	    // Call constructor
	    ez = callfunc(loc, irs, 1, type, ez, ectype, member, member->type, NULL, arguments);

	e = el_combine(ex, ey);
	e = el_combine(e, ez);
    }
    else if (t->ty == Tarray)
    {
	TypeDArray *tda = (TypeDArray *)(t);

	assert(arguments && arguments->dim >= 1);
	if (arguments->dim == 1)
	{   // Single dimension array allocations
	    Expression *arg = (Expression *)arguments->data[0];	// gives array length
	    e = arg->toElem(irs);
	    d_uns64 elemsize = tda->next->size();

	    // call _d_newT(ti, arg)
	    e = el_param(e, type->getTypeInfo(NULL)->toElem(irs));
	    int rtl = t->next->isZeroInit() ? RTLSYM_NEWARRAYT : RTLSYM_NEWARRAYIT;
	    e = el_bin(OPcall,TYdarray,el_var(rtlsym[rtl]),e);
	}
	else
	{   // Multidimensional array allocations
	    e = el_long(TYint, arguments->dim);
	    for (size_t i = 0; i < arguments->dim; i++)
	    {
		Expression *arg = (Expression *)arguments->data[i];	// gives array length
		e = el_param(arg->toElem(irs), e);
		assert(t->ty == Tarray);
		t = t->nextOf();
		assert(t);
	    }

	    e = el_param(e, type->getTypeInfo(NULL)->toElem(irs));

	    int rtl = t->isZeroInit() ? RTLSYM_NEWARRAYMT : RTLSYM_NEWARRAYMIT;
	    e = el_bin(OPcall,TYdarray,el_var(rtlsym[rtl]),e);
	}
    }
    else if (t->ty == Tpointer)
    {
	d_uns64 elemsize = t->next->size();
	Expression *di = t->next->defaultInit();
	d_uns64 disize = di->type->size();

	// call _d_newarrayT(ti, 1)
	e = el_long(TYsize_t, 1);
	e = el_param(e, type->getTypeInfo(NULL)->toElem(irs));

	int rtl = t->next->isZeroInit() ? RTLSYM_NEWARRAYT : RTLSYM_NEWARRAYIT;
	e = el_bin(OPcall,TYdarray,el_var(rtlsym[rtl]),e);

	// The new functions return an array, so convert to a pointer
	// e -> (unsigned)(e >> 32)
	e = el_bin(OPshr, TYdarray, e, el_long(TYint, 32));
	e = el_una(OP64_32, t->totym(), e);
    }
    else
    {
	assert(0);
    }

    el_setLoc(e,loc);
    return e;
}

elem *SymOffExp::toElem(IRState *irs)
{   Symbol *s;
    elem *e;
    Type *tb = var->type->toBasetype();
    FuncDeclaration *fd = NULL;
    if (var->toParent2())
	fd = var->toParent2()->isFuncDeclaration();

    //printf("SymOffExp::toElem(): %s\n", toChars());
    s = var->toSymbol();

    int nrvo = 0;
    if (fd && fd->nrvo_can && fd->nrvo_var == var)
    { 	s = fd->shidden;
	nrvo = 1;
    }

    if (s->Sclass == SCauto && s->Ssymnum == -1)
	symbol_add(s);
    assert(!var->isImportedSymbol());

    // This code closely parallels that in VarExp::toElem()
    if (s->Sclass == SCauto || s->Sclass == SCparameter)
    {
	if (fd && fd != irs->getFunc())
	{   // 'var' is a variable in an enclosing function.
	    elem *ethis;
	    int soffset;

	    ethis = getEthis(loc, irs, fd);
	    ethis = el_una(OPaddr, TYnptr, ethis);

	    soffset = s->Soffset;

	    // If fd is a non-static member function, then ethis isn't the
	    // frame pointer. We must offset it.
	    if (fd->vthis)
	    {
		soffset -= fd->vthis->toSymbol()->Soffset;
	    }

	    if (!nrvo)
		soffset += offset;
	    e = el_bin(OPadd, TYnptr, ethis, el_long(TYnptr, soffset));
	    if ((var->isParameter() && tb->ty == Tsarray) || var->isOut() || var->isRef())
		e = el_una(OPind, s->ty(), e);
	    else if (nrvo)
	    {	e = el_una(OPind, TYnptr, e);
		e = el_bin(OPadd, e->Ety, e, el_long(TYint, offset));
	    }
	    goto L1;
	}
    }
    if ((var->isParameter() && tb->ty == Tsarray) || var->isOut() || var->isRef())
    {   // Static arrays are really passed as pointers to the array
        // Out parameters are really references
        e = el_var(s);
        e->Ety = TYnptr;
	if (offset)
	    e = el_bin(OPadd, TYnptr, e, el_long(TYint, offset));
    }
    else
    {	e = nrvo ? el_var(s) : el_ptr(s);
	e = el_bin(OPadd, e->Ety, e, el_long(TYint, offset));
    }

L1:
    el_setLoc(e,loc);
    return e;
}

//////////////////////////// Unary ///////////////////////////////

/***************************************
 */

elem *NegExp::toElem(IRState *irs)
{
    elem *e = el_una(OPneg, type->totym(), e1->toElem(irs));
    el_setLoc(e,loc);
    return e;
}

/***************************************
 */

elem *ComExp::toElem(IRState *irs)
{   elem *e;

    elem *e1 = this->e1->toElem(irs);
    tym_t ty = type->totym();
    if (this->e1->type->toBasetype()->ty == Tbool)
	e = el_bin(OPxor, ty, e1, el_long(ty, 1));
    else
	e = el_una(OPcom,ty,e1);
    el_setLoc(e,loc);
    return e;
}

/***************************************
 */

elem *NotExp::toElem(IRState *irs)
{
    elem *e = el_una(OPnot, type->totym(), e1->toElem(irs));
    el_setLoc(e,loc);
    return e;
}


/***************************************
 */

elem *HaltExp::toElem(IRState *irs)
{   elem *e;

    e = el_calloc();
    e->Ety = TYvoid;
    e->Eoper = OPhalt;
    el_setLoc(e,loc);
    return e;
}

/********************************************
 */

elem *AssertExp::toElem(IRState *irs)
{   elem *e;
    elem *ea;
    Type *t1 = e1->type->toBasetype();

    //printf("AssertExp::toElem() %s\n", toChars());
    if (global.params.useAssert)
    {
	e = e1->toElem(irs);

	InvariantDeclaration *inv = (InvariantDeclaration *)(void *)1;

	// If e1 is a class object, call the class invariant on it
	if (global.params.useInvariants && t1->ty == Tclass &&
	    !((TypeClass *)t1)->sym->isInterfaceDeclaration())
	{
#if TARGET_LINUX
	    e = el_bin(OPcall, TYvoid, el_var(rtlsym[RTLSYM__DINVARIANT]), e);
#else
	    e = el_bin(OPcall, TYvoid, el_var(rtlsym[RTLSYM_DINVARIANT]), e);
#endif
	}
	// If e1 is a struct object, call the struct invariant on it
	else if (global.params.useInvariants &&
	    t1->ty == Tpointer &&
	    t1->nextOf()->ty == Tstruct &&
	    (inv = ((TypeStruct *)t1->nextOf())->sym->inv) != NULL)
	{
	    e = callfunc(loc, irs, 1, inv->type->nextOf(), e, e1->type, inv, inv->type, NULL, NULL);
	}
	else
	{
	    // Construct: (e1 || ModuleAssert(line))
	    Symbol *sassert;
	    Module *m = irs->blx->module;
	    char *mname = m->srcfile->toChars();

	    //printf("filename = '%s'\n", loc.filename);
	    //printf("module = '%s'\n", m->srcfile->toChars());

	    /* If the source file name has changed, probably due
	     * to a #line directive.
	     */
	    if (loc.filename && (msg || strcmp(loc.filename, mname) != 0))
	    {	elem *efilename;

		/* Cache values.
		 */
		//static Symbol *assertexp_sfilename = NULL;
		//static char *assertexp_name = NULL;
		//static Module *assertexp_mn = NULL;

		if (!assertexp_sfilename || strcmp(loc.filename, assertexp_name) != 0 || assertexp_mn != m)
		{
		    dt_t *dt = NULL;
		    char *id;
		    int len;

		    id = loc.filename;
		    len = strlen(id);
		    dtdword(&dt, len);
		    dtabytes(&dt,TYnptr, 0, len + 1, id);

		    assertexp_sfilename = symbol_generate(SCstatic,type_fake(TYdarray));
		    assertexp_sfilename->Sdt = dt;
		    assertexp_sfilename->Sfl = FLdata;
#if ELFOBJ
		    assertexp_sfilename->Sseg = CDATA;
#endif
		    outdata(assertexp_sfilename);

		    assertexp_mn = m;
		    assertexp_name = id;
		}

		efilename = el_var(assertexp_sfilename);

		if (msg)
		{   elem *emsg = msg->toElem(irs);
		    ea = el_var(rtlsym[RTLSYM_DASSERT_MSG]);
		    ea = el_bin(OPcall, TYvoid, ea, el_params(el_long(TYint, loc.linnum), efilename, emsg, NULL));
		}
		else
		{
		    ea = el_var(rtlsym[RTLSYM_DASSERT]);
		    ea = el_bin(OPcall, TYvoid, ea, el_param(el_long(TYint, loc.linnum), efilename));
		}
	    }
	    else
	    {
		sassert = m->toModuleAssert();
		ea = el_bin(OPcall,TYvoid,el_var(sassert),
		    el_long(TYint, loc.linnum));
	    }
	    e = el_bin(OPoror,TYvoid,e,ea);
	}
    }
    else
    {	// BUG: should replace assert(0); with a HLT instruction
	e = el_long(TYint, 0);
    }
    el_setLoc(e,loc);
    return e;
}

elem *PostExp::toElem(IRState *irs)
{   elem *e;
    elem *einc;

    e = e1->toElem(irs);
    einc = e2->toElem(irs);
    e = el_bin((op == TOKplusplus) ? OPpostinc : OPpostdec,
		e->Ety,e,einc);
    el_setLoc(e,loc);
    return e;
}

//////////////////////////// Binary ///////////////////////////////

/********************************************
 */

elem *BinExp::toElemBin(IRState *irs,int op)
{
    //printf("toElemBin() '%s'\n", toChars());

    tym_t tym = type->totym();

    elem *el = e1->toElem(irs);
    elem *er = e2->toElem(irs);
    elem *e = el_bin(op,tym,el,er);
    el_setLoc(e,loc);
    return e;
}

/****************************************
 */

elem *CommaExp::toElem(IRState *irs)
{
    assert(e1 && e2);
    elem *eleft  = e1->toElem(irs);
    elem *eright = e2->toElem(irs);
    elem *e = el_combine(eleft, eright);
    if (e)
	el_setLoc(e, loc);
    return e;
}


/***************************************
 */

elem *CondExp::toElem(IRState *irs)
{   elem *eleft;
    elem *eright;

    elem *ec = econd->toElem(irs);

    eleft = e1->toElem(irs);
    tym_t ty = eleft->Ety;
    if (global.params.cov && e1->loc.linnum)
	eleft = el_combine(incUsageElem(irs, e1->loc), eleft);

    eright = e2->toElem(irs);
    if (global.params.cov && e2->loc.linnum)
	eright = el_combine(incUsageElem(irs, e2->loc), eright);

    elem *e = el_bin(OPcond, ty, ec, el_bin(OPcolon, ty, eleft, eright));
    if (tybasic(ty) == TYstruct)
	e->Enumbytes = e1->type->size();
    el_setLoc(e, loc);
    return e;
}

/***************************************
 */

elem *AddExp::toElem(IRState *irs)
{   elem *e;
    Type *tb1 = e1->type->toBasetype();
    Type *tb2 = e2->type->toBasetype();

    if ((tb1->ty == Tarray || tb1->ty == Tsarray) &&
	(tb2->ty == Tarray || tb2->ty == Tsarray)
       )
    {
	error("Array operations not implemented");
    }
    else
	e = toElemBin(irs,OPadd);
    return e;
}

/***************************************
 */

elem *MinExp::toElem(IRState *irs)
{
    return toElemBin(irs,OPmin);
}

/***************************************
 */

elem *CatExp::toElem(IRState *irs)
{   elem *e;

#if 0
    printf("CatExp::toElem()\n");
    print();
#endif

    Type *tb1 = e1->type->toBasetype();
    Type *tb2 = e2->type->toBasetype();
    Type *tn;

#if 0
    if ((tb1->ty == Tarray || tb1->ty == Tsarray) &&
	(tb2->ty == Tarray || tb2->ty == Tsarray)
       )
#endif

    Type *ta = tb1->nextOf() ? e1->type : e2->type;
    tn = tb1->nextOf() ? tb1->nextOf() : tb2->nextOf();
    {
	if (e1->op == TOKcat)
	{
	    elem *ep;
	    CatExp *ce = this;
	    int n = 2;

	    ep = eval_Darray(irs, ce->e2);
	    do
	    {
		n++;
		ce = (CatExp *)ce->e1;
		ep = el_param(ep, eval_Darray(irs, ce->e2));
	    } while (ce->e1->op == TOKcat);
	    ep = el_param(ep, eval_Darray(irs, ce->e1));
#if 1
	    ep = el_params(
			   ep,
			   el_long(TYint, n),
			   ta->getTypeInfo(NULL)->toElem(irs),
			   NULL);
	    e = el_bin(OPcall, TYdarray, el_var(rtlsym[RTLSYM_ARRAYCATNT]), ep);
#else
	    ep = el_params(
			   ep,
			   el_long(TYint, n),
			   el_long(TYint, tn->size()),
			   NULL);
	    e = el_bin(OPcall, TYdarray, el_var(rtlsym[RTLSYM_ARRAYCATN]), ep);
#endif
	}
	else
	{
	    elem *e1;
	    elem *e2;
	    elem *ep;

	    e1 = eval_Darray(irs, this->e1);
	    e2 = eval_Darray(irs, this->e2);
#if 1
	    ep = el_params(e2, e1, ta->getTypeInfo(NULL)->toElem(irs), NULL);
	    e = el_bin(OPcall, TYdarray, el_var(rtlsym[RTLSYM_ARRAYCATT]), ep);
#else
	    ep = el_params(el_long(TYint, tn->size()), e2, e1, NULL);
	    e = el_bin(OPcall, TYdarray, el_var(rtlsym[RTLSYM_ARRAYCAT]), ep);
#endif
	}
	el_setLoc(e,loc);
    }
#if 0
    else if ((tb1->ty == Tarray || tb1->ty == Tsarray) &&
	     e2->type->equals(tb1->next))
    {
	error("array cat with element not implemented");
	e = el_long(TYint, 0);
    }
    else
	assert(0);
#endif
    return e;
}

/***************************************
 */

elem *MulExp::toElem(IRState *irs)
{
    return toElemBin(irs,OPmul);
}

/************************************
 */

elem *DivExp::toElem(IRState *irs)
{
    return toElemBin(irs,OPdiv);
}

/***************************************
 */

elem *ModExp::toElem(IRState *irs)
{
    elem *e;
    elem *e1;
    elem *e2;
    tym_t tym;

    tym = type->totym();

    e1 = this->e1->toElem(irs);
    e2 = this->e2->toElem(irs);

#if 0 // Now inlined
    if (this->e1->type->isfloating())
    {	elem *ep;

	switch (this->e1->type->ty)
	{
	    case Tfloat32:
	    case Timaginary32:
		e1 = el_una(OPf_d, TYdouble, e1);
		e2 = el_una(OPf_d, TYdouble, e2);
	    case Tfloat64:
	    case Timaginary64:
		e1 = el_una(OPd_ld, TYldouble, e1);
		e2 = el_una(OPd_ld, TYldouble, e2);
		break;
	    case Tfloat80:
	    case Timaginary80:
		break;
	    default:
		assert(0);
		break;
	}
	ep = el_param(e2,e1);
	e = el_bin(OPcall,tym,el_var(rtlsym[RTLSYM_MODULO]),ep);
    }
    else
#endif
	e = el_bin(OPmod,tym,e1,e2);
    el_setLoc(e,loc);
    return e;
}

/***************************************
 */

elem *CmpExp::toElem(IRState *irs)
{
    elem *e;
    enum OPER eop;
    Type *t1 = e1->type->toBasetype();
    Type *t2 = e2->type->toBasetype();

    switch (op)
    {
	case TOKlt:	eop = OPlt;	break;
	case TOKgt:	eop = OPgt;	break;
	case TOKle:	eop = OPle;	break;
	case TOKge:	eop = OPge;	break;
	case TOKequal:	eop = OPeqeq;	break;
	case TOKnotequal: eop = OPne;	break;

	// NCEG floating point compares
	case TOKunord:	eop = OPunord;	break;
	case TOKlg:	eop = OPlg;	break;
	case TOKleg:	eop = OPleg;	break;
	case TOKule:	eop = OPule;	break;
	case TOKul:	eop = OPul;	break;
	case TOKuge:	eop = OPuge;	break;
	case TOKug:	eop = OPug;	break;
	case TOKue:	eop = OPue;	break;
	default:
	    dump(0);
	    assert(0);
    }
    if (!t1->isfloating())
    {
	// Convert from floating point compare to equivalent
	// integral compare
	eop = (enum OPER)rel_integral(eop);
    }
    if ((int)eop > 1 && t1->ty == Tclass && t2->ty == Tclass)
    {
#if 1
	assert(0);
#else
	elem *ec1;
	elem *ec2;

	ec1 = e1->toElem(irs);
	ec2 = e2->toElem(irs);
	e = el_bin(OPcall,TYint,el_var(rtlsym[RTLSYM_OBJ_CMP]),el_param(ec1, ec2));
	e = el_bin(eop, TYint, e, el_long(TYint, 0));
#endif
    }
    else if ((int)eop > 1 &&
	     (t1->ty == Tarray || t1->ty == Tsarray) &&
	     (t2->ty == Tarray || t2->ty == Tsarray))
    {
	elem *ea1;
	elem *ea2;
	elem *ep;
	Type *telement = t1->nextOf()->toBasetype();
	int rtlfunc;

	ea1 = e1->toElem(irs);
	ea1 = array_toDarray(t1, ea1);
	ea2 = e2->toElem(irs);
	ea2 = array_toDarray(t2, ea2);

	ep = el_params(telement->getInternalTypeInfo(NULL)->toElem(irs), ea2, ea1, NULL);
	rtlfunc = RTLSYM_ARRAYCMP;
	e = el_bin(OPcall, TYint, el_var(rtlsym[rtlfunc]), ep);
	e = el_bin(eop, TYint, e, el_long(TYint, 0));
	el_setLoc(e,loc);
    }
    else
    {
	if ((int)eop <= 1)
	{
	    /* The result is determinate, create:
	     *   (e1 , e2) , eop
	     */
	    e = toElemBin(irs,OPcomma);
	    e = el_bin(OPcomma,e->Ety,e,el_long(e->Ety,(int)eop));
	}
	else
	    e = toElemBin(irs,eop);
    }
    return e;
}

elem *EqualExp::toElem(IRState *irs)
{
    //printf("EqualExp::toElem() %s\n", toChars());

    elem *e;
    enum OPER eop;
    Type *t1 = e1->type->toBasetype();
    Type *t2 = e2->type->toBasetype();

    switch (op)
    {
	case TOKequal:		eop = OPeqeq;	break;
	case TOKnotequal:	eop = OPne;	break;
	default:
	    dump(0);
	    assert(0);
    }

    //printf("EqualExp::toElem()\n");
    if (t1->ty == Tstruct)
    {	// Do bit compare of struct's
	elem *es1;
	elem *es2;
	elem *ecount;

	es1 = e1->toElem(irs);
	es2 = e2->toElem(irs);
#if 1
	es1 = addressElem(es1, t1);
	es2 = addressElem(es2, t2);
#else
	es1 = el_una(OPaddr, TYnptr, es1);
	es2 = el_una(OPaddr, TYnptr, es2);
#endif
	e = el_param(es1, es2);
	ecount = el_long(TYint, t1->size());
	e = el_bin(OPmemcmp, TYint, e, ecount);
	e = el_bin(eop, TYint, e, el_long(TYint, 0));
	el_setLoc(e,loc);
    }
#if 0
    else if (t1->ty == Tclass && t2->ty == Tclass)
    {
	elem *ec1;
	elem *ec2;

	ec1 = e1->toElem(irs);
	ec2 = e2->toElem(irs);
	e = el_bin(OPcall,TYint,el_var(rtlsym[RTLSYM_OBJ_EQ]),el_param(ec1, ec2));
    }
#endif
    else if ((t1->ty == Tarray || t1->ty == Tsarray) &&
	     (t2->ty == Tarray || t2->ty == Tsarray))
    {
	elem *ea1;
	elem *ea2;
	elem *ep;
	Type *telement = t1->nextOf()->toBasetype();
	int rtlfunc;

	ea1 = e1->toElem(irs);
	ea1 = array_toDarray(t1, ea1);
	ea2 = e2->toElem(irs);
	ea2 = array_toDarray(t2, ea2);

	ep = el_params(telement->getInternalTypeInfo(NULL)->toElem(irs), ea2, ea1, NULL);
	rtlfunc = RTLSYM_ARRAYEQ;
	e = el_bin(OPcall, TYint, el_var(rtlsym[rtlfunc]), ep);
	if (op == TOKnotequal)
	    e = el_bin(OPxor, TYint, e, el_long(TYint, 1));
	el_setLoc(e,loc);
    }
    else
	e = toElemBin(irs, eop);
    return e;
}

elem *IdentityExp::toElem(IRState *irs)
{
    elem *e;
    enum OPER eop;
    Type *t1 = e1->type->toBasetype();
    Type *t2 = e2->type->toBasetype();

    switch (op)
    {
	case TOKidentity:	eop = OPeqeq;	break;
	case TOKnotidentity:	eop = OPne;	break;
	default:
	    dump(0);
	    assert(0);
    }

    //printf("IdentityExp::toElem() %s\n", toChars());

    if (t1->ty == Tstruct)
    {	// Do bit compare of struct's
	elem *es1;
	elem *es2;
	elem *ecount;

	es1 = e1->toElem(irs);
	es1 = addressElem(es1, e1->type);
	//es1 = el_una(OPaddr, TYnptr, es1);
	es2 = e2->toElem(irs);
	es2 = addressElem(es2, e2->type);
	//es2 = el_una(OPaddr, TYnptr, es2);
	e = el_param(es1, es2);
	ecount = el_long(TYint, t1->size());
	e = el_bin(OPmemcmp, TYint, e, ecount);
	e = el_bin(eop, TYint, e, el_long(TYint, 0));
	el_setLoc(e,loc);
    }
    else if ((t1->ty == Tarray || t1->ty == Tsarray) &&
	     (t2->ty == Tarray || t2->ty == Tsarray))
    {
	elem *ea1;
	elem *ea2;

	ea1 = e1->toElem(irs);
	ea1 = array_toDarray(t1, ea1);
	ea2 = e2->toElem(irs);
	ea2 = array_toDarray(t2, ea2);

	e = el_bin(eop, type->totym(), ea1, ea2);
	el_setLoc(e,loc);
    }
    else
	e = toElemBin(irs, eop);

    return e;
}


/***************************************
 */

elem *InExp::toElem(IRState *irs)
{   elem *e;
    elem *key = e1->toElem(irs);
    elem *aa = e2->toElem(irs);
    elem *ep;
    elem *keyti;
    TypeAArray *taa = (TypeAArray *)e2->type->toBasetype();
    

    // set to:
    //	aaIn(aa, keyti, key);

    if (key->Ety == TYstruct)
    {
	key = el_una(OPstrpar, TYstruct, key);
	key->Enumbytes = key->E1->Enumbytes;
	assert(key->Enumbytes);
    }

    Symbol *s = taa->aaGetSymbol("In", 0);
    keyti = taa->key->getInternalTypeInfo(NULL)->toElem(irs);
    ep = el_params(key, keyti, aa, NULL);
    e = el_bin(OPcall, type->totym(), el_var(s), ep);

    el_setLoc(e,loc);
    return e;
}

/***************************************
 */

elem *RemoveExp::toElem(IRState *irs)
{   elem *e;
    Type *tb = e1->type->toBasetype();
    assert(tb->ty == Taarray);
    TypeAArray *taa = (TypeAArray *)tb;
    elem *ea = e1->toElem(irs);
    elem *ekey = e2->toElem(irs);
    elem *ep;
    elem *keyti;

    if (ekey->Ety == TYstruct)
    {
	ekey = el_una(OPstrpar, TYstruct, ekey);
	ekey->Enumbytes = ekey->E1->Enumbytes;
	assert(ekey->Enumbytes);
    }

    Symbol *s = taa->aaGetSymbol("Del", 0);
    keyti = taa->key->getInternalTypeInfo(NULL)->toElem(irs);
    ep = el_params(ekey, keyti, ea, NULL);
    e = el_bin(OPcall, TYnptr, el_var(s), ep);

    el_setLoc(e,loc);
    return e;
}

/***************************************
 */

elem *AssignExp::toElem(IRState *irs)
{   elem *e;
    IndexExp *ae;
    int r;
    Type *t1b;

    //printf("AssignExp::toElem('%s')\n", toChars());
    t1b = e1->type->toBasetype();

    // Look for array.length = n
    if (e1->op == TOKarraylength)
    {
	// Generate:
	//	_d_arraysetlength(e2, sizeelem, &ale->e1);

	ArrayLengthExp *ale = (ArrayLengthExp *)e1;
	elem *p1;
	elem *p2;
	elem *p3;
	elem *ep;
	Type *t1;

	p1 = e2->toElem(irs);
	p3 = ale->e1->toElem(irs);
	p3 = addressElem(p3, NULL);
	t1 = ale->e1->type->toBasetype();

#if 1
	// call _d_arraysetlengthT(ti, e2, &ale->e1);
	p2 = t1->getTypeInfo(NULL)->toElem(irs);
	ep = el_params(p3, p1, p2, NULL);	// c function
	r = t1->nextOf()->isZeroInit() ? RTLSYM_ARRAYSETLENGTHT : RTLSYM_ARRAYSETLENGTHIT;
#else
	if (t1->next->isZeroInit())
	{   p2 = t1->getTypeInfo(NULL)->toElem(irs);
	    ep = el_params(p3, p1, p2, NULL);	// c function
	    r = RTLSYM_ARRAYSETLENGTHT;
	}
	else
	{
	    p2 = el_long(TYint, t1->next->size());
	    ep = el_params(p3, p2, p1, NULL);	// c function
	    Expression *init = t1->next->defaultInit();
	    ep = el_param(el_long(TYint, init->type->size()), ep);
	    elem *ei = init->toElem(irs);
	    ep = el_param(ei, ep);
	    r = RTLSYM_ARRAYSETLENGTH3;
	}
#endif

	e = el_bin(OPcall, type->totym(), el_var(rtlsym[r]), ep);
	el_setLoc(e, loc);
	return e;
    }

    // Look for array[]=n
    if (e1->op == TOKslice)
    {
	SliceExp *are = (SliceExp *)(e1);
	Type *t1 = t1b;
	Type *t2 = e2->type->toBasetype();

	// which we do if the 'next' types match
	if (ismemset)
	{   // Do a memset for array[]=n
//printf("Lpair %s\n", toChars());
	    SliceExp *are = (SliceExp *)e1;
	    elem *elwr;
	    elem *eupr;
	    elem *n1;
	    elem *evalue;
	    elem *enbytes;
	    elem *elength;
	    elem *einit;
	    integer_t value;
	    Type *ta = are->e1->type->toBasetype();
	    Type *tb = ta->nextOf()->toBasetype();
	    int sz = tb->size();
	    tym_t tym = type->totym();

	    n1 = are->e1->toElem(irs);
	    elwr = are->lwr ? are->lwr->toElem(irs) : NULL;
	    eupr = are->upr ? are->upr->toElem(irs) : NULL;

	    elem *n1x = n1;

	    // Look for array[]=n
	    if (ta->ty == Tsarray)
	    {
		TypeSArray *ts;

		ts = (TypeSArray *) ta;
		n1 = array_toPtr(ta, n1);
		enbytes = ts->dim->toElem(irs);
		n1x = n1;
		n1 = el_same(&n1x);
		einit = resolveLengthVar(are->lengthVar, &n1, ta);
	    }
	    else if (ta->ty == Tarray)
	    {
		n1 = el_same(&n1x);
		einit = resolveLengthVar(are->lengthVar, &n1, ta);
		enbytes = el_copytree(n1);
		n1 = array_toPtr(ta, n1);
		enbytes = el_una(OP64_32, TYint, enbytes);
	    }
	    else if (ta->ty == Tpointer)
	    {
		n1 = el_same(&n1x);
		enbytes = el_long(TYint, -1);	// largest possible index
		einit = NULL;
	    }

	    // Enforce order of evaluation of n1[elwr..eupr] as n1,elwr,eupr
	    elem *elwrx = elwr;
	    if (elwr) elwr = el_same(&elwrx);
	    elem *euprx = eupr;
	    if (eupr) eupr = el_same(&euprx);

#if 0
	    printf("sz = %d\n", sz);
	    printf("n1x\n");
	    elem_print(n1x);
	    printf("einit\n");
	    elem_print(einit);
	    printf("elwrx\n");
	    elem_print(elwrx);
	    printf("euprx\n");
	    elem_print(euprx);
	    printf("n1\n");
	    elem_print(n1);
	    printf("elwr\n");
	    elem_print(elwr);
	    printf("eupr\n");
	    elem_print(eupr);
	    printf("enbytes\n");
	    elem_print(enbytes);
#endif
	    einit = el_combine(n1x, einit);
	    einit = el_combine(einit, elwrx);
	    einit = el_combine(einit, euprx);

	    evalue = this->e2->toElem(irs);

#if 0
	    printf("n1\n");
	    elem_print(n1);
	    printf("enbytes\n");
	    elem_print(enbytes);
#endif

	    if (global.params.useArrayBounds && eupr && ta->ty != Tpointer)
	    {
		elem *c1;
		elem *c2;
		elem *ea;
		elem *eb;
		elem *enbytesx;

		assert(elwr);
		enbytesx = enbytes;
		enbytes = el_same(&enbytesx);
		c1 = el_bin(OPle, TYint, el_copytree(eupr), enbytesx);
		c2 = el_bin(OPle, TYint, el_copytree(elwr), el_copytree(eupr));
		c1 = el_bin(OPandand, TYint, c1, c2);

		// Construct: (c1 || ModuleArray(line))
		Symbol *sassert;

		sassert = irs->blx->module->toModuleArray();
		ea = el_bin(OPcall,TYvoid,el_var(sassert), el_long(TYint, loc.linnum));
		eb = el_bin(OPoror,TYvoid,c1,ea);
		einit = el_combine(einit, eb);
	    }

	    if (elwr)
	    {   elem *elwr2;

		el_free(enbytes);
		elwr2 = el_copytree(elwr);
		elwr2 = el_bin(OPmul, TYint, elwr2, el_long(TYint, sz));
		n1 = el_bin(OPadd, TYnptr, n1, elwr2);
		enbytes = el_bin(OPmin, TYint, eupr, elwr);
		elength = el_copytree(enbytes);
	    }
	    else
		elength = el_copytree(enbytes);
	    e = setArray(n1, enbytes, tb, evalue);
	Lpair:
	    e = el_pair(TYullong, elength, e);
	Lret2:
	    e = el_combine(einit, e);
	    //elem_print(e);
	    goto Lret;
	}
	else
	{
	    /* It's array1[]=array2[]
	     * which is a memcpy
	     */
	    elem *eto;
	    elem *efrom;
	    elem *esize;
	    elem *ep;

	    eto = e1->toElem(irs);
	    efrom = e2->toElem(irs);

	    unsigned size;

	    size = t1->nextOf()->size();
	    esize = el_long(TYint, size);

	    if (e2->type->ty == Tpointer || !global.params.useArrayBounds)
	    {	elem *epto;
		elem *epfr;
		elem *elen;
		elem *ex;

		ex = el_same(&eto);

		// Determine if elen is a constant
		if (eto->Eoper == OPpair &&
		    eto->E1->Eoper == OPconst)
		{
		    elen = el_copytree(eto->E1);
		}
		else
		{
		    // It's not a constant, so pull it from the dynamic array
		    elen = el_una(OP64_32, TYint, el_copytree(ex));
		}

		esize = el_bin(OPmul, TYint, elen, esize);
		epto = array_toPtr(e1->type, ex);
		epfr = array_toPtr(e2->type, efrom);
		e = el_bin(OPmemcpy, TYnptr, epto, el_param(epfr, esize));
		e = el_pair(eto->Ety, el_copytree(elen), e);
		e = el_combine(eto, e);
	    }
	    else
	    {
		// Generate:
		//	_d_arraycopy(eto, efrom, esize)

		// If eto is a static array, need to convert it to
		// a dynamic array.
		//if (are->e1->type->ty == Tsarray)
		//    eto = sarray_toDarray(are->e1->type, eto);

		ep = el_params(eto, efrom, esize, NULL);
		e = el_bin(OPcall, type->totym(), el_var(rtlsym[RTLSYM_ARRAYCOPY]), ep);
	    }
	    el_setLoc(e, loc);
	    return e;
	}
    }

    if (e1->op == TOKindex)
    {
	elem *eb;
	elem *ei;
	elem *ev;
	TY ty;
	Type *ta;

	ae = (IndexExp *)(e1);
	ta = ae->e1->type->toBasetype();
	ty = ta->ty;
    }
#if 1
    /* This will work if we can distinguish an assignment from
     * an initialization of the lvalue. It'll work if the latter.
     * If the former, because of aliasing of the return value with
     * function arguments, it'll fail.
     */
    if (op == TOKconstruct && e2->op == TOKcall)
    {	CallExp *ce = (CallExp *)e2;

	TypeFunction *tf = (TypeFunction *)ce->e1->type->toBasetype();
	if (tf->ty == Tfunction && tf->retStyle() == RETstack)
	{
	    elem *ehidden = e1->toElem(irs);
	    ehidden = el_una(OPaddr, TYnptr, ehidden);
	    assert(!irs->ehidden);
	    irs->ehidden = ehidden;
	    e = e2->toElem(irs);
	    goto Lret;
	}
    }
#endif
    if (t1b->ty == Tstruct)
    {
	if (e2->op == TOKint64)
	{   /* Implement:
	     *	(struct = 0)
	     * with:
	     *	memset(&struct, 0, struct.sizeof)
	     */
	    elem *el = e1->toElem(irs);
	    elem *enbytes = el_long(TYint, e1->type->size());
	    elem *evalue = el_long(TYint, 0);

	    el = el_una(OPaddr, TYnptr, el);
	    e = el_param(enbytes, evalue);
	    e = el_bin(OPmemset,TYnptr,el,e);
	    el_setLoc(e, loc);
	    //e = el_una(OPind, TYstruct, e);
	}
	else
	{
	    elem *e1;
	    elem *e2;
	    tym_t tym;

	    //printf("toElemBin() '%s'\n", toChars());

	    tym = type->totym();

	    e1 = this->e1->toElem(irs);
	    elem *ex = e1;
	    if (e1->Eoper == OPind)
		ex = e1->E1;
	    if (this->e2->op == TOKstructliteral &&
		ex->Eoper == OPvar && ex->EV.sp.Voffset == 0)
	    {	StructLiteralExp *se = (StructLiteralExp *)this->e2;

		Symbol *symSave = se->sym;
		size_t soffsetSave = se->soffset;
		int fillHolesSave = se->fillHoles;

		se->sym = ex->EV.sp.Vsym;
		se->soffset = 0;
		se->fillHoles = (op == TOKconstruct) ? 1 : 0;

		el_free(e1);
		e = this->e2->toElem(irs);

		se->sym = symSave;
		se->soffset = soffsetSave;
		se->fillHoles = fillHolesSave;
	    }
	    else
	    {
		e2 = this->e2->toElem(irs);
		e = el_bin(OPstreq,tym,e1,e2);
		e->Enumbytes = this->e1->type->size();
	    }
	    goto Lret;
	}
    }
    else
	e = toElemBin(irs,OPeq);
    return e;

  Lret:
    el_setLoc(e,loc);
    return e;
}

/***************************************
 */

elem *AddAssignExp::toElem(IRState *irs)
{
    //printf("AddAssignExp::toElem() %s\n", toChars());
    elem *e;
    Type *tb1 = e1->type->toBasetype();
    Type *tb2 = e2->type->toBasetype();

    if ((tb1->ty == Tarray || tb1->ty == Tsarray) &&
	(tb2->ty == Tarray || tb2->ty == Tsarray)
       )
    {
	error("Array operations not implemented");
    }
    else
	e = toElemBin(irs,OPaddass);
    return e;
}


/***************************************
 */

elem *MinAssignExp::toElem(IRState *irs)
{
    return toElemBin(irs,OPminass);
}

/***************************************
 */

elem *CatAssignExp::toElem(IRState *irs)
{
    //printf("CatAssignExp::toElem('%s')\n", toChars());
    elem *e;
    Type *tb1 = e1->type->toBasetype();
    Type *tb2 = e2->type->toBasetype();

    if (tb1->ty == Tarray || tb2->ty == Tsarray)
    {   elem *e1;
	elem *e2;
	elem *ep;

	e1 = this->e1->toElem(irs);
	e1 = el_una(OPaddr, TYnptr, e1);

	e2 = this->e2->toElem(irs);
	if (e2->Ety == TYstruct)
	{
	    e2 = el_una(OPstrpar, TYstruct, e2);
	    e2->Enumbytes = e2->E1->Enumbytes;
	    assert(e2->Enumbytes);
	}

	Type *tb1n = tb1->nextOf()->toBasetype();
	if ((tb2->ty == Tarray || tb2->ty == Tsarray) &&
	    tb1n->equals(tb2->nextOf()->toBasetype()))
	{   // Append array
#if 1
	    ep = el_params(e2, e1, this->e1->type->getTypeInfo(NULL)->toElem(irs), NULL);
	    e = el_bin(OPcall, TYdarray, el_var(rtlsym[RTLSYM_ARRAYAPPENDT]), ep);
#else
	    ep = el_params(el_long(TYint, tb1n->size()), e2, e1, NULL);
	    e = el_bin(OPcall, TYdarray, el_var(rtlsym[RTLSYM_ARRAYAPPEND]), ep);
#endif
	}
	else
	{   // Append element
#if 1
	    ep = el_params(e2, e1, this->e1->type->getTypeInfo(NULL)->toElem(irs), NULL);
	    e = el_bin(OPcall, TYdarray, el_var(rtlsym[RTLSYM_ARRAYAPPENDCT]), ep);
#else
	    ep = el_params(e2, el_long(TYint, tb1n->size()), e1, NULL);
	    e = el_bin(OPcall, TYdarray, el_var(rtlsym[RTLSYM_ARRAYAPPENDC]), ep);
#endif
	}
	el_setLoc(e,loc);
    }
    else
	assert(0);
    return e;
}


/***************************************
 */

elem *DivAssignExp::toElem(IRState *irs)
{
    return toElemBin(irs,OPdivass);
}


/***************************************
 */

elem *ModAssignExp::toElem(IRState *irs)
{
    return toElemBin(irs,OPmodass);
}


/***************************************
 */

elem *MulAssignExp::toElem(IRState *irs)
{
    return toElemBin(irs,OPmulass);
}


/***************************************
 */

elem *ShlAssignExp::toElem(IRState *irs)
{   elem *e;

    e = toElemBin(irs,OPshlass);
    return e;
}


/***************************************
 */

elem *ShrAssignExp::toElem(IRState *irs)
{
    return toElemBin(irs,OPshrass);
}


/***************************************
 */

elem *UshrAssignExp::toElem(IRState *irs)
{
    elem *eleft  = e1->toElem(irs);
    eleft->Ety = touns(eleft->Ety);
    elem *eright = e2->toElem(irs);
    elem *e = el_bin(OPshrass, type->totym(), eleft, eright);
    el_setLoc(e, loc);
    return e;
}


/***************************************
 */

elem *AndAssignExp::toElem(IRState *irs)
{
    return toElemBin(irs,OPandass);
}


/***************************************
 */

elem *OrAssignExp::toElem(IRState *irs)
{
    return toElemBin(irs,OPorass);
}


/***************************************
 */

elem *XorAssignExp::toElem(IRState *irs)
{
    return toElemBin(irs,OPxorass);
}


/***************************************
 */

elem *AndAndExp::toElem(IRState *irs)
{
    elem *e = toElemBin(irs,OPandand);
    if (global.params.cov && e2->loc.linnum)
	e->E2 = el_combine(incUsageElem(irs, e2->loc), e->E2);
    return e;
}


/***************************************
 */

elem *OrOrExp::toElem(IRState *irs)
{
    elem *e = toElemBin(irs,OPoror);
    if (global.params.cov && e2->loc.linnum)
	e->E2 = el_combine(incUsageElem(irs, e2->loc), e->E2);
    return e;
}


/***************************************
 */

elem *XorExp::toElem(IRState *irs)
{
    return toElemBin(irs,OPxor);
}


/***************************************
 */

elem *AndExp::toElem(IRState *irs)
{
    return toElemBin(irs,OPand);
}


/***************************************
 */

elem *OrExp::toElem(IRState *irs)
{
    return toElemBin(irs,OPor);
}


/***************************************
 */

elem *ShlExp::toElem(IRState *irs)
{
    return toElemBin(irs, OPshl);
}


/***************************************
 */

elem *ShrExp::toElem(IRState *irs)
{
    return toElemBin(irs,OPshr);
}


/***************************************
 */

elem *UshrExp::toElem(IRState *irs)
{
    elem *eleft  = e1->toElem(irs);
    eleft->Ety = touns(eleft->Ety);
    elem *eright = e2->toElem(irs);
    elem *e = el_bin(OPshr, type->totym(), eleft, eright);
    el_setLoc(e, loc);
    return e;
}

elem *TypeDotIdExp::toElem(IRState *irs)
{
    print();
    assert(0);
    return NULL;
}

elem *TypeExp::toElem(IRState *irs)
{
#ifdef DEBUG
    printf("TypeExp::toElem()\n");
#endif
    error("type %s is not an expression", toChars());
    return el_long(TYint, 0);
}

elem *ScopeExp::toElem(IRState *irs)
{
    error("%s is not an expression", sds->toChars());
    return el_long(TYint, 0);
}

elem *DotVarExp::toElem(IRState *irs)
{
    // *(&e + offset)

    //printf("DotVarExp::toElem('%s')\n", toChars());

    VarDeclaration *v = var->isVarDeclaration();
    if (!v)
    {
	error("%s is not a field", var->toChars());
    }

    elem *e = e1->toElem(irs);
    Type *tb1 = e1->type->toBasetype();
    if (tb1->ty != Tclass && tb1->ty != Tpointer)
	e = el_una(OPaddr, TYnptr, e);
    e = el_bin(OPadd, TYnptr, e, el_long(TYint, v ? v->offset : 0));
    e = el_una(OPind, type->totym(), e);
    if (tybasic(e->Ety) == TYstruct)
    {
	e->Enumbytes = type->size();
    }
    el_setLoc(e,loc);
    return e;
}

elem *DelegateExp::toElem(IRState *irs)
{
    elem *e;
    elem *ethis;
    elem *ep;
    Symbol *sfunc;
    int directcall = 0;

    //printf("DelegateExp::toElem() '%s'\n", toChars());
    sfunc = func->toSymbol();
    if (func->isNested())
    {
	ep = el_ptr(sfunc);
	ethis = getEthis(loc, irs, func);
    }
    else
    {
	ethis = e1->toElem(irs);
	if (e1->type->ty != Tclass && e1->type->ty != Tpointer)
	    ethis = el_una(OPaddr, TYnptr, ethis);

	if (e1->op == TOKsuper)
	    directcall = 1;

	if (!func->isThis())
	    error("delegates are only for non-static functions");

	if (!func->isVirtual() ||
	    directcall ||
	    func->isFinal())
	{
	    ep = el_ptr(sfunc);
	}
	else
	{
	    // Get pointer to function out of virtual table
	    unsigned vindex;

	    assert(ethis);
	    ep = el_same(&ethis);
	    ep = el_una(OPind, TYnptr, ep);
	    vindex = func->vtblIndex;

	    // Build *(ep + vindex * 4)
	    ep = el_bin(OPadd,TYnptr,ep,el_long(TYint, vindex * 4));
	    ep = el_una(OPind,TYnptr,ep);
	}

//	if (func->tintro)
//	    func->error(loc, "cannot form delegate due to covariant return type");
    }
    if (ethis->Eoper == OPcomma)
    {
	ethis->E2 = el_pair(TYullong, ethis->E2, ep);
	ethis->Ety = TYullong;
	e = ethis;
    }
    else
	e = el_pair(TYullong, ethis, ep);
    el_setLoc(e,loc);
    return e;
}

elem *DotTypeExp::toElem(IRState *irs)
{
    // Just a pass-thru to e1
    elem *e;

    //printf("DotTypeExp::toElem() %s\n", toChars());
    e = e1->toElem(irs);
    el_setLoc(e,loc);
    return e;
}

elem *CallExp::toElem(IRState *irs)
{
    //printf("CallExp::toElem('%s')\n", toChars());
    assert(e1->type);
    elem *ec;
    int directcall;
    FuncDeclaration *fd;
    Type *t1 = e1->type->toBasetype();
    Type *ectype = t1;

    elem *ehidden = irs->ehidden;
    irs->ehidden = NULL;

    directcall = 0;
    fd = NULL;
    if (e1->op == TOKdotvar && t1->ty != Tdelegate)
    {	DotVarExp *dve = (DotVarExp *)e1;

	fd = dve->var->isFuncDeclaration();
	Expression *ex = dve->e1;
	while (1)
	{
	    switch (ex->op)
	    {
		case TOKsuper:		// super.member() calls directly
		case TOKdottype:	// type.member() calls directly
		    directcall = 1;
		    break;

		case TOKcast:
		    ex = ((CastExp *)ex)->e1;
		    continue;

		default:
		    //ex->dump(0);
		    break;
	    }
	    break;
	}
	ec = dve->e1->toElem(irs);
	ectype = dve->e1->type->toBasetype();
    }
    else if (e1->op == TOKvar)
    {
	fd = ((VarExp *)e1)->var->isFuncDeclaration();

	if (fd && fd->ident == Id::alloca &&
	    !fd->fbody && fd->linkage == LINKc &&
	    arguments && arguments->dim == 1)
	{   Expression *arg = (Expression *)arguments->data[0];
	    arg = arg->optimize(WANTvalue);
	    if (arg->isConst() && arg->type->isintegral())
	    {	integer_t sz = arg->toInteger();
		if (sz > 0 && sz < 0x40000)
		{
		    // It's an alloca(sz) of a fixed amount.
		    // Replace with an array allocated on the stack
		    // of the same size: char[sz] tmp;

		    Symbol *stmp;
		    ::type *t;

		    assert(!ehidden);
		    t = type_allocn(TYarray, tschar);
		    t->Tdim = sz;
		    stmp = symbol_genauto(t);
		    ec = el_ptr(stmp);
		    el_setLoc(ec,loc);
		    return ec;
		}
	    }
	}

	ec = e1->toElem(irs);
    }
    else
    {
	ec = e1->toElem(irs);
    }
    ec = callfunc(loc, irs, directcall, type, ec, ectype, fd, t1, ehidden, arguments);
    el_setLoc(ec,loc);
    return ec;
}

elem *AddrExp::toElem(IRState *irs)
{   elem *e;
    elem **pe;

    //printf("AddrExp::toElem('%s')\n", toChars());

    e = e1->toElem(irs);
    e = addressElem(e, e1->type);
L2:
    e->Ety = type->totym();
    el_setLoc(e,loc);
    return e;
}

elem *PtrExp::toElem(IRState *irs)
{   elem *e;

    //printf("PtrExp::toElem() %s\n", toChars());
    e = e1->toElem(irs);
    e = el_una(OPind,type->totym(),e);
    if (tybasic(e->Ety) == TYstruct)
    {
	e->Enumbytes = type->size();
    }
    el_setLoc(e,loc);
    return e;
}

elem *BoolExp::toElem(IRState *irs)
{   elem *e1;

    e1 = this->e1->toElem(irs);
    return el_una(OPbool,type->totym(),e1);
}

elem *DeleteExp::toElem(IRState *irs)
{   elem *e;
    int rtl;
    Type *tb;

    //printf("DeleteExp::toElem()\n");
    if (e1->op == TOKindex)
    {
	IndexExp *ae = (IndexExp *)(e1);
	tb = ae->e1->type->toBasetype();
	if (tb->ty == Taarray)
	{
	    TypeAArray *taa = (TypeAArray *)tb;
	    elem *ea = ae->e1->toElem(irs);
	    elem *ekey = ae->e2->toElem(irs);
	    elem *ep;
	    elem *keyti;

	    if (ekey->Ety == TYstruct)
	    {
		ekey = el_una(OPstrpar, TYstruct, ekey);
		ekey->Enumbytes = ekey->E1->Enumbytes;
		assert(ekey->Enumbytes);
	    }

	    Symbol *s = taa->aaGetSymbol("Del", 0);
	    keyti = taa->key->getInternalTypeInfo(NULL)->toElem(irs);
	    ep = el_params(ekey, keyti, ea, NULL);
	    e = el_bin(OPcall, TYnptr, el_var(s), ep);
	    goto Lret;
	}
    }
    //e1->type->print();
    e = e1->toElem(irs);
    rtl = RTLSYM_DELCLASS;
    tb = e1->type->toBasetype();
    switch (tb->ty)
    {
	case Tarray:
	    e = addressElem(e, e1->type);
	    rtl = RTLSYM_DELARRAY;
	    break;

	case Tclass:
	    if (e1->op == TOKvar)
	    {	VarExp *ve = (VarExp *)e1;
		if (ve->var->isVarDeclaration() &&
		    ve->var->isVarDeclaration()->onstack)
		{
		    rtl = RTLSYM_CALLFINALIZER;
		    if (tb->isClassHandle()->isInterfaceDeclaration())
			rtl = RTLSYM_CALLINTERFACEFINALIZER;
		    break;
		}
	    }
	    e = addressElem(e, e1->type);
	    rtl = RTLSYM_DELCLASS;
	    if (tb->isClassHandle()->isInterfaceDeclaration())
		rtl = RTLSYM_DELINTERFACE;
	    break;

	case Tpointer:
	    e = addressElem(e, e1->type);
	    rtl = RTLSYM_DELMEMORY;
	    break;

	default:
	    assert(0);
	    break;
    }
    e = el_bin(OPcall, TYvoid, el_var(rtlsym[rtl]), e);

  Lret:
    el_setLoc(e,loc);
    return e;
}

elem *CastExp::toElem(IRState *irs)
{   elem *e;
    TY fty;
    TY tty;
    tym_t ftym;
    tym_t ttym;
    enum OPER eop;
    Type *t;
    Type *tfrom;

#if 0
    printf("CastExp::toElem()\n");
    print();
    printf("\tfrom: %s\n", e1->type->toChars());
    printf("\tto  : %s\n", to->toChars());
#endif

    e = e1->toElem(irs);
    tfrom = e1->type->toBasetype();
    t = to->toBasetype();		// skip over typedef's
    if (t->equals(tfrom))
	goto Lret;

    fty = tfrom->ty;
    //printf("fty = %d\n", fty);
    tty = t->ty;

    if (tty == Tpointer && fty == Tarray
#if 0
	&& (t->next->ty == Tvoid || t->next->equals(e1->type->next))
#endif
       )
    {
	if (e->Eoper == OPvar)
	{
	    // e1 -> *(&e1 + 4)
	    e = el_una(OPaddr, TYnptr, e);
	    e = el_bin(OPadd, TYnptr, e, el_long(TYint, 4));
	    e = el_una(OPind,t->totym(),e);
	}
	else
	{
	    // e1 -> (unsigned)(e1 >> 32)
	    e = el_bin(OPshr, TYullong, e, el_long(TYint, 32));
	    e = el_una(OP64_32, t->totym(), e);
	}
	goto Lret;
    }

    if (tty == Tpointer && fty == Tsarray
#if 0
	&& (t->next->ty == Tvoid || t->next->equals(e1->type->next))
#endif
	)
    {
	// e1 -> &e1
	e = el_una(OPaddr, TYnptr, e);
	goto Lret;
    }

    // Convert from static array to dynamic array
    if (tty == Tarray && fty == Tsarray)
    {
	e = sarray_toDarray(tfrom, t, e);
	goto Lret;
    }

    // Convert from dynamic array to dynamic array
    if (tty == Tarray && fty == Tarray)
    {
	unsigned fsize = tfrom->nextOf()->size();
	unsigned tsize = t->nextOf()->size();

	if (fsize != tsize)
	{
	    elem *ep;

	    ep = el_params(e, el_long(TYint, fsize), el_long(TYint, tsize), NULL);
	    e = el_bin(OPcall, type->totym(), el_var(rtlsym[RTLSYM_ARRAYCAST]), ep);
	}
	goto Lret;
    }

    // Casting from base class to derived class requires a runtime check
    if (fty == Tclass && tty == Tclass)
    {
	// Casting from derived class to base class is a no-op
	ClassDeclaration *cdfrom;
	ClassDeclaration *cdto;
	int offset;
	int rtl = RTLSYM_DYNAMIC_CAST;

	cdfrom = e1->type->isClassHandle();
	cdto   = t->isClassHandle();
	if (cdfrom->isInterfaceDeclaration())
	{
	    rtl = RTLSYM_INTERFACE_CAST;
	    if (cdfrom->isCOMinterface())
	    {
		if (cdto->isCOMinterface())
		{
		    /* Casting from a com interface to a com interface
		     * is always a 'paint' operation
		     */
		    goto Lret;			// no-op
		}

		/* Casting from a COM interface to a class
		 * always results in null because there is no runtime
		 * information available to do it.
		 *
		 * Casting from a COM interface to a non-COM interface
		 * always results in null because there's no way one
		 * can be derived from the other.
		 */
		e = el_bin(OPcomma, TYnptr, e, el_long(TYnptr, 0));
		goto Lret;
	    }
	}
	if (cdto->isBaseOf(cdfrom, &offset) && offset != OFFSET_RUNTIME)
	{
	    /* The offset from cdfrom=>cdto is known at compile time.
	     */
	
	    //printf("offset = %d\n", offset);
	    if (offset)
	    {	/* Rewrite cast as (e ? e + offset : null)
		 */
		elem *etmp;
		elem *ex;

		if (e1->op == TOKthis)
		{   // Assume 'this' is never null, so skip null check
		    e = el_bin(OPadd, TYnptr, e, el_long(TYint, offset));
		}
		else
		{
		    etmp = el_same(&e);
		    ex = el_bin(OPadd, TYnptr, etmp, el_long(TYint, offset));
		    ex = el_bin(OPcolon, TYnptr, ex, el_long(TYnptr, 0));
		    e = el_bin(OPcond, TYnptr, e, ex);
		}
	    }
	    goto Lret;			// no-op
	}

	/* The offset from cdfrom=>cdto can only be determined at runtime.
	 */
	elem *ep;

	ep = el_param(el_ptr(cdto->toSymbol()), e);
	e = el_bin(OPcall, TYnptr, el_var(rtlsym[rtl]), ep);
	goto Lret;
    }

    ftym = e->Ety;
    ttym = t->totym();
    if (ftym == ttym)
	goto Lret;

    switch (tty)
    {
	case Tpointer:
	    if (fty == Tdelegate)
		goto Lpaint;
	    tty = Tuns32;
	    break;

	case Tchar:	tty = Tuns8;	break;
	case Twchar:	tty = Tuns16;	break;
	case Tdchar:	tty = Tuns32;	break;
	case Tvoid:	goto Lpaint;

	case Tbool:
	{
	    // Construct e?true:false
	    elem *eq;

	    e = el_una(OPbool, ttym, e);
	    goto Lret;
	}
    }

    switch (fty)
    {
	case Tpointer:	fty = Tuns32;	break;
	case Tchar:	fty = Tuns8;	break;
	case Twchar:	fty = Tuns16;	break;
	case Tdchar:	fty = Tuns32;	break;
    }

    #define X(fty, tty) ((fty) * TMAX + (tty))
Lagain:
    switch (X(fty,tty))
    {
#if 0
	case X(Tbit,Tint8):
	case X(Tbit,Tuns8):
				goto Lpaint;
	case X(Tbit,Tint16):
	case X(Tbit,Tuns16):
	case X(Tbit,Tint32):
	case X(Tbit,Tuns32):	eop = OPu8_16;	goto Leop;
	case X(Tbit,Tint64):
	case X(Tbit,Tuns64):
	case X(Tbit,Tfloat32):
	case X(Tbit,Tfloat64):
	case X(Tbit,Tfloat80):
	case X(Tbit,Tcomplex32):
	case X(Tbit,Tcomplex64):
	case X(Tbit,Tcomplex80):
				e = el_una(OPu8_16, TYuint, e);
				fty = Tuns32;
				goto Lagain;
	case X(Tbit,Timaginary32):
	case X(Tbit,Timaginary64):
	case X(Tbit,Timaginary80): goto Lzero;
#endif
	/* ============================= */

	case X(Tbool,Tint8):
	case X(Tbool,Tuns8):
				goto Lpaint;
	case X(Tbool,Tint16):
	case X(Tbool,Tuns16):
	case X(Tbool,Tint32):
	case X(Tbool,Tuns32):	eop = OPu8_16;	goto Leop;
	case X(Tbool,Tint64):
	case X(Tbool,Tuns64):
	case X(Tbool,Tfloat32):
	case X(Tbool,Tfloat64):
	case X(Tbool,Tfloat80):
	case X(Tbool,Tcomplex32):
	case X(Tbool,Tcomplex64):
	case X(Tbool,Tcomplex80):
				e = el_una(OPu8_16, TYuint, e);
				fty = Tuns32;
				goto Lagain;
	case X(Tbool,Timaginary32):
	case X(Tbool,Timaginary64):
	case X(Tbool,Timaginary80): goto Lzero;

	/* ============================= */

	case X(Tint8,Tuns8):	goto Lpaint;
	case X(Tint8,Tint16):
	case X(Tint8,Tuns16):
	case X(Tint8,Tint32):
	case X(Tint8,Tuns32):	eop = OPs8_16;	goto Leop;
	case X(Tint8,Tint64):
	case X(Tint8,Tuns64):
	case X(Tint8,Tfloat32):
	case X(Tint8,Tfloat64):
	case X(Tint8,Tfloat80):
	case X(Tint8,Tcomplex32):
	case X(Tint8,Tcomplex64):
	case X(Tint8,Tcomplex80):
				e = el_una(OPs8_16, TYint, e);
				fty = Tint32;
				goto Lagain;
	case X(Tint8,Timaginary32):
	case X(Tint8,Timaginary64):
	case X(Tint8,Timaginary80): goto Lzero;

	/* ============================= */

	case X(Tuns8,Tint8):	goto Lpaint;
	case X(Tuns8,Tint16):
	case X(Tuns8,Tuns16):
	case X(Tuns8,Tint32):
	case X(Tuns8,Tuns32):	eop = OPu8_16;	goto Leop;
	case X(Tuns8,Tint64):
	case X(Tuns8,Tuns64):
	case X(Tuns8,Tfloat32):
	case X(Tuns8,Tfloat64):
	case X(Tuns8,Tfloat80):
	case X(Tuns8,Tcomplex32):
	case X(Tuns8,Tcomplex64):
	case X(Tuns8,Tcomplex80):
				e = el_una(OPu8_16, TYuint, e);
				fty = Tuns32;
				goto Lagain;
	case X(Tuns8,Timaginary32):
	case X(Tuns8,Timaginary64):
	case X(Tuns8,Timaginary80): goto Lzero;

	/* ============================= */

	case X(Tint16,Tint8):
	case X(Tint16,Tuns8):	eop = OP16_8;	goto Leop;
	case X(Tint16,Tuns16):	goto Lpaint;
	case X(Tint16,Tint32):
	case X(Tint16,Tuns32):	eop = OPs16_32;	goto Leop;
	case X(Tint16,Tint64):
	case X(Tint16,Tuns64):	e = el_una(OPs16_32, TYint, e);
				fty = Tint32;
				goto Lagain;
	case X(Tint16,Tfloat32):
	case X(Tint16,Tfloat64):
	case X(Tint16,Tfloat80):
	case X(Tint16,Tcomplex32):
	case X(Tint16,Tcomplex64):
	case X(Tint16,Tcomplex80):
				e = el_una(OPs16_d, TYdouble, e);
				fty = Tfloat64;
				goto Lagain;
	case X(Tint16,Timaginary32):
	case X(Tint16,Timaginary64):
	case X(Tint16,Timaginary80): goto Lzero;

	/* ============================= */

	case X(Tuns16,Tint8):
	case X(Tuns16,Tuns8):	eop = OP16_8;	goto Leop;
	case X(Tuns16,Tint16):	goto Lpaint;
	case X(Tuns16,Tint32):
	case X(Tuns16,Tuns32):	eop = OPu16_32;	goto Leop;
	case X(Tuns16,Tint64):
	case X(Tuns16,Tuns64):
	case X(Tuns16,Tfloat64):
	case X(Tuns16,Tfloat32):
	case X(Tuns16,Tfloat80):
	case X(Tuns16,Tcomplex32):
	case X(Tuns16,Tcomplex64):
	case X(Tuns16,Tcomplex80):
				e = el_una(OPu16_32, TYuint, e);
				fty = Tuns32;
				goto Lagain;
	case X(Tuns16,Timaginary32):
	case X(Tuns16,Timaginary64):
	case X(Tuns16,Timaginary80): goto Lzero;

	/* ============================= */

	case X(Tint32,Tint8):
	case X(Tint32,Tuns8):	e = el_una(OP32_16, TYshort, e);
				fty = Tint16;
				goto Lagain;
	case X(Tint32,Tint16):
	case X(Tint32,Tuns16):	eop = OP32_16;	goto Leop;
	case X(Tint32,Tuns32):	goto Lpaint;
	case X(Tint32,Tint64):
	case X(Tint32,Tuns64):	eop = OPs32_64;	goto Leop;
	case X(Tint32,Tfloat32):
	case X(Tint32,Tfloat64):
	case X(Tint32,Tfloat80):
	case X(Tint32,Tcomplex32):
	case X(Tint32,Tcomplex64):
	case X(Tint32,Tcomplex80):
				e = el_una(OPs32_d, TYdouble, e);
				fty = Tfloat64;
				goto Lagain;
	case X(Tint32,Timaginary32):
	case X(Tint32,Timaginary64):
	case X(Tint32,Timaginary80): goto Lzero;

	/* ============================= */

	case X(Tuns32,Tint8):
	case X(Tuns32,Tuns8):	e = el_una(OP32_16, TYshort, e);
				fty = Tuns16;
				goto Lagain;
	case X(Tuns32,Tint16):
	case X(Tuns32,Tuns16):	eop = OP32_16;	goto Leop;
	case X(Tuns32,Tint32):	goto Lpaint;
	case X(Tuns32,Tint64):
	case X(Tuns32,Tuns64):	eop = OPu32_64;	goto Leop;
	case X(Tuns32,Tfloat32):
	case X(Tuns32,Tfloat64):
	case X(Tuns32,Tfloat80):
	case X(Tuns32,Tcomplex32):
	case X(Tuns32,Tcomplex64):
	case X(Tuns32,Tcomplex80):
				e = el_una(OPu32_d, TYdouble, e);
				fty = Tfloat64;
				goto Lagain;
	case X(Tuns32,Timaginary32):
	case X(Tuns32,Timaginary64):
	case X(Tuns32,Timaginary80): goto Lzero;

	/* ============================= */

	case X(Tint64,Tint8):
	case X(Tint64,Tuns8):
	case X(Tint64,Tint16):
	case X(Tint64,Tuns16):	e = el_una(OP64_32, TYint, e);
				fty = Tint32;
				goto Lagain;
	case X(Tint64,Tint32):
	case X(Tint64,Tuns32):	eop = OP64_32; goto Leop;
	case X(Tint64,Tuns64):	goto Lpaint;
	case X(Tint64,Tfloat32):
	case X(Tint64,Tfloat64):
	case X(Tint64,Tfloat80):
	case X(Tint64,Tcomplex32):
	case X(Tint64,Tcomplex64):
	case X(Tint64,Tcomplex80):
				e = el_una(OPs64_d, TYdouble, e);
				fty = Tfloat64;
				goto Lagain;
	case X(Tint64,Timaginary32):
	case X(Tint64,Timaginary64):
	case X(Tint64,Timaginary80): goto Lzero;

	/* ============================= */

	case X(Tuns64,Tint8):
	case X(Tuns64,Tuns8):
	case X(Tuns64,Tint16):
	case X(Tuns64,Tuns16):	e = el_una(OP64_32, TYint, e);
				fty = Tint32;
				goto Lagain;
	case X(Tuns64,Tint32):
	case X(Tuns64,Tuns32):	eop = OP64_32;	goto Leop;
	case X(Tuns64,Tint64):	goto Lpaint;
	case X(Tuns64,Tfloat32):
	case X(Tuns64,Tfloat64):
	case X(Tuns64,Tfloat80):
	case X(Tuns64,Tcomplex32):
	case X(Tuns64,Tcomplex64):
	case X(Tuns64,Tcomplex80):
				 e = el_una(OPu64_d, TYdouble, e);
				 fty = Tfloat64;
				 goto Lagain;
	case X(Tuns64,Timaginary32):
	case X(Tuns64,Timaginary64):
	case X(Tuns64,Timaginary80): goto Lzero;

	/* ============================= */

	case X(Tfloat32,Tint8):
	case X(Tfloat32,Tuns8):
	case X(Tfloat32,Tint16):
	case X(Tfloat32,Tuns16):
	case X(Tfloat32,Tint32):
	case X(Tfloat32,Tuns32):
	case X(Tfloat32,Tint64):
	case X(Tfloat32,Tuns64):
	case X(Tfloat32,Tfloat80): e = el_una(OPf_d, TYdouble, e);
				   fty = Tfloat64;
				   goto Lagain;
	case X(Tfloat32,Tfloat64): eop = OPf_d;	goto Leop;
	case X(Tfloat32,Timaginary32): goto Lzero;
	case X(Tfloat32,Timaginary64): goto Lzero;
	case X(Tfloat32,Timaginary80): goto Lzero;
	case X(Tfloat32,Tcomplex32):
	case X(Tfloat32,Tcomplex64):
	case X(Tfloat32,Tcomplex80):
	    e = el_bin(OPadd,TYcfloat,el_long(TYifloat,0),e);
	    fty = Tcomplex32;
	    goto Lagain;

	/* ============================= */

	case X(Tfloat64,Tint8):
	case X(Tfloat64,Tuns8):    e = el_una(OPd_s16, TYshort, e);
				   fty = Tint16;
				   goto Lagain;
	case X(Tfloat64,Tint16):   eop = OPd_s16; goto Leop;
	case X(Tfloat64,Tuns16):   eop = OPd_u16; goto Leop;
	case X(Tfloat64,Tint32):   eop = OPd_s32; goto Leop;
	case X(Tfloat64,Tuns32):   eop = OPd_u32; goto Leop;
	case X(Tfloat64,Tint64):   eop = OPd_s64; goto Leop;
	case X(Tfloat64,Tuns64):   eop = OPd_u64; goto Leop;
	case X(Tfloat64,Tfloat32): eop = OPd_f;   goto Leop;
	case X(Tfloat64,Tfloat80): eop = OPd_ld;  goto Leop;
	case X(Tfloat64,Timaginary32):	goto Lzero;
	case X(Tfloat64,Timaginary64):	goto Lzero;
	case X(Tfloat64,Timaginary80):	goto Lzero;
	case X(Tfloat64,Tcomplex32):
	case X(Tfloat64,Tcomplex64):
	case X(Tfloat64,Tcomplex80):
	    e = el_bin(OPadd,TYcfloat,el_long(TYidouble,0),e);
	    fty = Tcomplex64;
	    goto Lagain;

	/* ============================= */

	case X(Tfloat80,Tint8):
	case X(Tfloat80,Tuns8):
	case X(Tfloat80,Tint16):
	case X(Tfloat80,Tuns16):
	case X(Tfloat80,Tint32):
	case X(Tfloat80,Tuns32):
	case X(Tfloat80,Tint64):
	case X(Tfloat80,Tuns64):
	case X(Tfloat80,Tfloat32): e = el_una(OPld_d, TYdouble, e);
				   fty = Tfloat64;
				   goto Lagain;
	case X(Tfloat80,Tfloat64): eop = OPld_d; goto Leop;
	case X(Tfloat80,Timaginary32): goto Lzero;
	case X(Tfloat80,Timaginary64): goto Lzero;
	case X(Tfloat80,Timaginary80): goto Lzero;
	case X(Tfloat80,Tcomplex32):
	case X(Tfloat80,Tcomplex64):
	case X(Tfloat80,Tcomplex80):
	    e = el_bin(OPadd,TYcldouble,e,el_long(TYildouble,0));
	    fty = Tcomplex80;
	    goto Lagain;

	/* ============================= */

	case X(Timaginary32,Tint8):
	case X(Timaginary32,Tuns8):
	case X(Timaginary32,Tint16):
	case X(Timaginary32,Tuns16):
	case X(Timaginary32,Tint32):
	case X(Timaginary32,Tuns32):
	case X(Timaginary32,Tint64):
	case X(Timaginary32,Tuns64):
	case X(Timaginary32,Tfloat32):
	case X(Timaginary32,Tfloat64):
	case X(Timaginary32,Tfloat80):	goto Lzero;
	case X(Timaginary32,Timaginary64): eop = OPf_d;	goto Leop;
	case X(Timaginary32,Timaginary80):
				   e = el_una(OPf_d, TYidouble, e);
				   fty = Timaginary64;
				   goto Lagain;
	case X(Timaginary32,Tcomplex32):
	case X(Timaginary32,Tcomplex64):
	case X(Timaginary32,Tcomplex80):
	    e = el_bin(OPadd,TYcfloat,el_long(TYfloat,0),e);
	    fty = Tcomplex32;
	    goto Lagain;

	/* ============================= */

	case X(Timaginary64,Tint8):
	case X(Timaginary64,Tuns8):
	case X(Timaginary64,Tint16):
	case X(Timaginary64,Tuns16):
	case X(Timaginary64,Tint32):
	case X(Timaginary64,Tuns32):
	case X(Timaginary64,Tint64):
	case X(Timaginary64,Tuns64):
	case X(Timaginary64,Tfloat32):
	case X(Timaginary64,Tfloat64):
	case X(Timaginary64,Tfloat80):	goto Lzero;
	case X(Timaginary64,Timaginary32): eop = OPd_f;   goto Leop;
	case X(Timaginary64,Timaginary80): eop = OPd_ld;  goto Leop;
	case X(Timaginary64,Tcomplex32):
	case X(Timaginary64,Tcomplex64):
	case X(Timaginary64,Tcomplex80):
	    e = el_bin(OPadd,TYcdouble,el_long(TYdouble,0),e);
	    fty = Tcomplex64;
	    goto Lagain;

	/* ============================= */

	case X(Timaginary80,Tint8):
	case X(Timaginary80,Tuns8):
	case X(Timaginary80,Tint16):
	case X(Timaginary80,Tuns16):
	case X(Timaginary80,Tint32):
	case X(Timaginary80,Tuns32):
	case X(Timaginary80,Tint64):
	case X(Timaginary80,Tuns64):
	case X(Timaginary80,Tfloat32):
	case X(Timaginary80,Tfloat64):
	case X(Timaginary80,Tfloat80):	goto Lzero;
	case X(Timaginary80,Timaginary32): e = el_una(OPf_d, TYidouble, e);
				   fty = Timaginary64;
				   goto Lagain;
	case X(Timaginary80,Timaginary64): eop = OPld_d; goto Leop;
	case X(Timaginary80,Tcomplex32):
	case X(Timaginary80,Tcomplex64):
	case X(Timaginary80,Tcomplex80):
	    e = el_bin(OPadd,TYcldouble,el_long(TYldouble,0),e);
	    fty = Tcomplex80;
	    goto Lagain;

	/* ============================= */

	case X(Tcomplex32,Tint8):
	case X(Tcomplex32,Tuns8):
	case X(Tcomplex32,Tint16):
	case X(Tcomplex32,Tuns16):
	case X(Tcomplex32,Tint32):
	case X(Tcomplex32,Tuns32):
	case X(Tcomplex32,Tint64):
	case X(Tcomplex32,Tuns64):
	case X(Tcomplex32,Tfloat32):
	case X(Tcomplex32,Tfloat64):
	case X(Tcomplex32,Tfloat80):
		e = el_una(OPc_r, TYfloat, e);
		fty = Tfloat32;
		goto Lagain;
	case X(Tcomplex32,Timaginary32):
	case X(Tcomplex32,Timaginary64):
	case X(Tcomplex32,Timaginary80):
		e = el_una(OPc_i, TYifloat, e);
		fty = Timaginary32;
		goto Lagain;
	case X(Tcomplex32,Tcomplex64):
	case X(Tcomplex32,Tcomplex80):
		e = el_una(OPf_d, TYcdouble, e);
		fty = Tcomplex64;
		goto Lagain;

	/* ============================= */

	case X(Tcomplex64,Tint8):
	case X(Tcomplex64,Tuns8):
	case X(Tcomplex64,Tint16):
	case X(Tcomplex64,Tuns16):
	case X(Tcomplex64,Tint32):
	case X(Tcomplex64,Tuns32):
	case X(Tcomplex64,Tint64):
	case X(Tcomplex64,Tuns64):
	case X(Tcomplex64,Tfloat32):
	case X(Tcomplex64,Tfloat64):
	case X(Tcomplex64,Tfloat80):
		e = el_una(OPc_r, TYdouble, e);
		fty = Tfloat64;
		goto Lagain;
	case X(Tcomplex64,Timaginary32):
	case X(Tcomplex64,Timaginary64):
	case X(Tcomplex64,Timaginary80):
		e = el_una(OPc_i, TYidouble, e);
		fty = Timaginary64;
		goto Lagain;
	case X(Tcomplex64,Tcomplex32):	 eop = OPd_f;	goto Leop;
	case X(Tcomplex64,Tcomplex80):	 eop = OPd_ld;	goto Leop;

	/* ============================= */

	case X(Tcomplex80,Tint8):
	case X(Tcomplex80,Tuns8):
	case X(Tcomplex80,Tint16):
	case X(Tcomplex80,Tuns16):
	case X(Tcomplex80,Tint32):
	case X(Tcomplex80,Tuns32):
	case X(Tcomplex80,Tint64):
	case X(Tcomplex80,Tuns64):
	case X(Tcomplex80,Tfloat32):
	case X(Tcomplex80,Tfloat64):
	case X(Tcomplex80,Tfloat80):
		e = el_una(OPc_r, TYldouble, e);
		fty = Tfloat80;
		goto Lagain;
	case X(Tcomplex80,Timaginary32):
	case X(Tcomplex80,Timaginary64):
	case X(Tcomplex80,Timaginary80):
		e = el_una(OPc_i, TYildouble, e);
		fty = Timaginary80;
		goto Lagain;
	case X(Tcomplex80,Tcomplex32):
	case X(Tcomplex80,Tcomplex64):
		e = el_una(OPld_d, TYcdouble, e);
		fty = Tcomplex64;
		goto Lagain;

	/* ============================= */

	default:
	    if (fty == tty)
		goto Lpaint;
	    //dump(0);
	    //printf("fty = %d, tty = %d\n", fty, tty);
	    error("e2ir: cannot cast from %s to %s", e1->type->toChars(), t->toChars());
	    goto Lzero;

	Lzero:
	    e = el_long(ttym, 0);
	    break;

	Lpaint:
	    e->Ety = ttym;
	    break;

	Leop:
	    e = el_una(eop, ttym, e);
	    break;
    }
Lret:
    // Adjust for any type paints
    t = type->toBasetype();
    e->Ety = t->totym();

    el_setLoc(e,loc);
    return e;
}

elem *ArrayLengthExp::toElem(IRState *irs)
{
    elem *e = e1->toElem(irs);
    e = el_una(OP64_32, type->totym(), e);
    el_setLoc(e,loc);
    return e;
}

elem *SliceExp::toElem(IRState *irs)
{   elem *e;
    Type *t1;

    //printf("SliceExp::toElem()\n");
    t1 = e1->type->toBasetype();
    e = e1->toElem(irs);
    if (lwr)
    {	elem *elwr;
	elem *elwr2;
	elem *eupr;
	elem *eptr;
	elem *einit;
	int sz;

	einit = resolveLengthVar(lengthVar, &e, t1);

	sz = t1->nextOf()->size();

	elwr = lwr->toElem(irs);
	eupr = upr->toElem(irs);

	elwr2 = el_same(&elwr);

	// Create an array reference where:
	// length is (upr - lwr)
	// pointer is (ptr + lwr*sz)
	// Combine as (length pair ptr)

	if (global.params.useArrayBounds)
	{
	    // Checks (unsigned compares):
	    //	upr <= array.length
	    //	lwr <= upr

	    elem *c1;
	    elem *c2;
	    elem *ea;
	    elem *eb;
	    elem *eupr2;
	    elem *elength;

	    if (t1->ty == Tpointer)
	    {
		// Just do lwr <= upr check

		eupr2 = el_same(&eupr);
		eupr2->Ety = TYuint;			// make sure unsigned comparison
		c1 = el_bin(OPle, TYint, elwr2, eupr2);
		c1 = el_combine(eupr, c1);
		goto L2;
	    }
	    else if (t1->ty == Tsarray)
	    {	TypeSArray *tsa = (TypeSArray *)t1;
		integer_t length = tsa->dim->toInteger();

		elength = el_long(TYuint, length);
		goto L1;
	    }
	    else if (t1->ty == Tarray)
	    {
		if (lengthVar)
		    elength = el_var(lengthVar->toSymbol());
		else
		{
		    elength = e;
		    e = el_same(&elength);
		    elength = el_una(OP64_32, TYuint, elength);
		}
	    L1:
		eupr2 = el_same(&eupr);
		c1 = el_bin(OPle, TYint, eupr, elength);
		eupr2->Ety = TYuint;			// make sure unsigned comparison
		c2 = el_bin(OPle, TYint, elwr2, eupr2);
		c1 = el_bin(OPandand, TYint, c1, c2);	// (c1 && c2)

	    L2:
		// Construct: (c1 || ModuleArray(line))
		Symbol *sassert;

		sassert = irs->blx->module->toModuleArray();
		ea = el_bin(OPcall,TYvoid,el_var(sassert), el_long(TYint, loc.linnum));
		eb = el_bin(OPoror,TYvoid,c1,ea);
		elwr = el_combine(elwr, eb);

		elwr2 = el_copytree(elwr2);
		eupr = el_copytree(eupr2);
	    }
	}

	eptr = array_toPtr(e1->type, e);

	elem *elength = el_bin(OPmin, TYint, eupr, elwr2);
	eptr = el_bin(OPadd, TYnptr, eptr, el_bin(OPmul, TYint, el_copytree(elwr2), el_long(TYint, sz)));

	e = el_pair(TYullong, elength, eptr);
	e = el_combine(elwr, e);
	e = el_combine(einit, e);
    }
    else if (t1->ty == Tsarray)
    {
	e = sarray_toDarray(t1, NULL, e);
    }
    el_setLoc(e,loc);
    return e;
}

elem *IndexExp::toElem(IRState *irs)
{   elem *e;
    elem *n1 = e1->toElem(irs);
    elem *n2;
    elem *eb = NULL;
    Type *t1;

    //printf("IndexExp::toElem() %s\n", toChars());
    t1 = e1->type->toBasetype();
    if (t1->ty == Taarray)
    {
	// set to:
	//	*aaGet(aa, keyti, valuesize, index);

	TypeAArray *taa = (TypeAArray *)t1;
	elem *keyti;
	elem *ep;
	int vsize = taa->next->size();
	elem *valuesize;
	Symbol *s;

	// n2 becomes the index, also known as the key
	n2 = e2->toElem(irs);
	if (n2->Ety == TYstruct || n2->Ety == TYarray)
	{
	    n2 = el_una(OPstrpar, TYstruct, n2);
	    n2->Enumbytes = n2->E1->Enumbytes;
	    //printf("numbytes = %d\n", n2->Enumbytes);
	    assert(n2->Enumbytes);
	}
	valuesize = el_long(TYuint, vsize);	// BUG: should be TYsize_t
	//printf("valuesize: "); elem_print(valuesize);
	if (modifiable)
	{
	    n1 = el_una(OPaddr, TYnptr, n1);
	    s = taa->aaGetSymbol("Get", 1);
	}
	else
	{
	    s = taa->aaGetSymbol("GetRvalue", 1);
	}
	//printf("taa->key = %s\n", taa->key->toChars());
	keyti = taa->key->getInternalTypeInfo(NULL)->toElem(irs);
	//keyti = taa->key->getTypeInfo(NULL)->toElem(irs);
	//printf("keyti:\n");
	//elem_print(keyti);
	ep = el_params(n2, valuesize, keyti, n1, NULL);
	e = el_bin(OPcall, TYnptr, el_var(s), ep);
	if (global.params.useArrayBounds)
	{
	    elem *n;
	    elem *ea;

	    n = el_same(&e);

	    // Construct: ((e || ModuleAssert(line)),n)
	    Symbol *sassert;

	    sassert = irs->blx->module->toModuleArray();
	    ea = el_bin(OPcall,TYvoid,el_var(sassert),
		el_long(TYint, loc.linnum));
	    e = el_bin(OPoror,TYvoid,e,ea);
	    e = el_bin(OPcomma, TYnptr, e, n);
	}
	e = el_una(OPind, type->totym(), e);
	if (tybasic(e->Ety) == TYstruct)
	    e->Enumbytes = type->size();
    }
    else
    {	elem *einit;

	einit = resolveLengthVar(lengthVar, &n1, t1);
	n2 = e2->toElem(irs);

	if (global.params.useArrayBounds)
	{
	    elem *elength;
	    elem *n2x;
	    elem *ea;

	    if (t1->ty == Tsarray)
	    {	TypeSArray *tsa = (TypeSArray *)t1;
		integer_t length = tsa->dim->toInteger();

		elength = el_long(TYuint, length);
		goto L1;
	    }
	    else if (t1->ty == Tarray)
	    {
		elength = n1;
		n1 = el_same(&elength);
		elength = el_una(OP64_32, TYuint, elength);
	    L1:
		n2x = n2;
		n2 = el_same(&n2x);
		n2x = el_bin(OPlt, TYint, n2x, elength);

		// Construct: (n2x || ModuleAssert(line))
		Symbol *sassert;

		sassert = irs->blx->module->toModuleArray();
		ea = el_bin(OPcall,TYvoid,el_var(sassert),
		    el_long(TYint, loc.linnum));
		eb = el_bin(OPoror,TYvoid,n2x,ea);
	    }
	}

	n1 = array_toPtr(t1, n1);

	{   elem *escale;

	    escale = el_long(TYint, t1->nextOf()->size());
	    n2 = el_bin(OPmul, TYint, n2, escale);
	    e = el_bin(OPadd, TYnptr, n1, n2);
	    e = el_una(OPind, type->totym(), e);
	    if (tybasic(e->Ety) == TYstruct || tybasic(e->Ety) == TYarray)
	    {	e->Ety = TYstruct;
		e->Enumbytes = type->size();
	    }
	}

	eb = el_combine(einit, eb);
	e = el_combine(eb, e);
    }
    el_setLoc(e,loc);
    return e;
}


elem *TupleExp::toElem(IRState *irs)
{   elem *e = NULL;

    //printf("TupleExp::toElem() %s\n", toChars());
    for (size_t i = 0; i < exps->dim; i++)
    {	Expression *el = (Expression *)exps->data[i];
	elem *ep = el->toElem(irs);

	e = el_combine(e, ep);
    }
    return e;
}


elem *ArrayLiteralExp::toElem(IRState *irs)
{   elem *e;
    size_t dim;

    //printf("ArrayLiteralExp::toElem() %s\n", toChars());
    if (elements)
    {
	dim = elements->dim;
	e = el_long(TYint, dim);
	for (size_t i = 0; i < dim; i++)
	{   Expression *el = (Expression *)elements->data[i];
	    elem *ep = el->toElem(irs);

	    if (tybasic(ep->Ety) == TYstruct || tybasic(ep->Ety) == TYarray)
	    {
		ep = el_una(OPstrpar, TYstruct, ep);
		ep->Enumbytes = el->type->size();
	    }
	    e = el_param(ep, e);
	}
    }
    else
    {	dim = 0;
	e = el_long(TYint, 0);
    }
    Type *tb = type->toBasetype();
#if 1
    e = el_param(e, type->getTypeInfo(NULL)->toElem(irs));

    // call _d_arrayliteralT(ti, dim, ...)
    e = el_bin(OPcall,TYnptr,el_var(rtlsym[RTLSYM_ARRAYLITERALT]),e);
#else
    e = el_param(e, el_long(TYint, tb->next->size()));

    // call _d_arrayliteral(size, dim, ...)
    e = el_bin(OPcall,TYnptr,el_var(rtlsym[RTLSYM_ARRAYLITERAL]),e);
#endif
    if (tb->ty == Tarray)
    {
	e = el_pair(TYullong, el_long(TYint, dim), e);
    }
    else if (tb->ty == Tpointer)
    {
    }
    else
    {
	e = el_una(OPind,TYstruct,e);
	e->Enumbytes = type->size();
    }

    el_setLoc(e,loc);
    return e;
}


elem *AssocArrayLiteralExp::toElem(IRState *irs)
{   elem *e;
    size_t dim;

    //printf("AssocArrayLiteralExp::toElem() %s\n", toChars());
    dim = keys->dim;
    e = el_long(TYint, dim);
    for (size_t i = 0; i < dim; i++)
    {   Expression *el = (Expression *)keys->data[i];

	for (int j = 0; j < 2; j++)
	{
	    elem *ep = el->toElem(irs);

	    if (tybasic(ep->Ety) == TYstruct || tybasic(ep->Ety) == TYarray)
	    {
		ep = el_una(OPstrpar, TYstruct, ep);
		ep->Enumbytes = el->type->size();
	    }
//printf("[%d] %s\n", i, el->toChars());
//elem_print(ep);
	    e = el_param(ep, e);
	    el = (Expression *)values->data[i];
	}
    }
    e = el_param(e, type->getTypeInfo(NULL)->toElem(irs));

    // call _d_assocarrayliteralT(ti, dim, ...)
    e = el_bin(OPcall,TYnptr,el_var(rtlsym[RTLSYM_ASSOCARRAYLITERALT]),e);

    el_setLoc(e,loc);
    return e;
}


/*******************************************
 * Generate elem to zero fill contents of Symbol stmp
 * from *poffset..offset2.
 * May store anywhere from 0..maxoff, as this function
 * tries to use aligned int stores whereever possible.
 * Update *poffset to end of initialized hole; *poffset will be >= offset2.
 */

elem *fillHole(Symbol *stmp, size_t *poffset, size_t offset2, size_t maxoff)
{   elem *e = NULL;
    int basealign = 1;

    while (*poffset < offset2)
    {   tym_t ty;
	elem *e1;

	if (tybasic(stmp->Stype->Tty) == TYnptr)
	    e1 = el_var(stmp);
	else
	    e1 = el_ptr(stmp);
	if (basealign)
	    *poffset &= ~3;
	basealign = 1;
	size_t sz = maxoff - *poffset;
	switch (sz)
	{   case 1: ty = TYchar;	break;
	    case 2: ty = TYshort;	break;
	    case 3:
		ty = TYshort;
		basealign = 0;
		break;
	    default:
		ty = TYlong;
		break;
	}
	e1 = el_bin(OPadd, TYnptr, e1, el_long(TYsize_t, *poffset));
	e1 = el_una(OPind, ty, e1);
	e1 = el_bin(OPeq, ty, e1, el_long(ty, 0));
	e = el_combine(e, e1);
	*poffset += tysize[ty];
    }
    return e;
}

elem *StructLiteralExp::toElem(IRState *irs)
{   elem *e;
    size_t dim;

    //printf("StructLiteralExp::toElem() %s\n", toChars());

    // struct symbol to initialize with the literal
    Symbol *stmp = sym ? sym : symbol_genauto(sd->type->toCtype());

    e = NULL;

    if (fillHoles)
    {
	/* Initialize all alignment 'holes' to zero.
	 * Do before initializing fields, as the hole filling process
	 * can spill over into the fields.
	 */
	size_t offset = 0;
	for (size_t i = 0; i < sd->fields.dim; i++)
	{
	    Dsymbol *s = (Dsymbol *)sd->fields.data[i];
	    VarDeclaration *v = s->isVarDeclaration();
	    assert(v);

	    e = el_combine(e, fillHole(stmp, &offset, v->offset, sd->structsize));
	    size_t vend = v->offset + v->type->size();
	    if (offset < vend)
		offset = vend;
	}
	e = el_combine(e, fillHole(stmp, &offset, sd->structsize, sd->structsize));
    }

    if (elements)
    {
	dim = elements->dim;
	assert(dim <= sd->fields.dim);
	for (size_t i = 0; i < dim; i++)
	{   Expression *el = (Expression *)elements->data[i];
	    if (!el)
		continue;

	    Dsymbol *s = (Dsymbol *)sd->fields.data[i];
	    VarDeclaration *v = s->isVarDeclaration();
	    assert(v);

	    elem *e1;
	    if (tybasic(stmp->Stype->Tty) == TYnptr)
	    {	e1 = el_var(stmp);
		e1->EV.sp.Voffset = soffset;
	    }
	    else
	    {	e1 = el_ptr(stmp);
		if (soffset)
		    e1 = el_bin(OPadd, TYnptr, e1, el_long(TYsize_t, soffset));
	    }
	    e1 = el_bin(OPadd, TYnptr, e1, el_long(TYsize_t, v->offset));

	    elem *ep = el->toElem(irs);

	    Type *t1b = v->type->toBasetype();
	    Type *t2b = el->type->toBasetype();
	    if (t1b->ty == Tsarray)
	    {
		if (t2b->implicitConvTo(t1b))
		{   elem *esize = el_long(TYsize_t, t1b->size());
		    ep = array_toPtr(el->type, ep);
		    e1 = el_bin(OPmemcpy, TYnptr, e1, el_param(ep, esize));
		}
		else
		{
		    elem *edim = el_long(TYsize_t, t1b->size() / t2b->size());
		    e1 = setArray(e1, edim, t2b, ep);
		}
	    }
	    else
	    {
		tym_t ty = v->type->totym();
		e1 = el_una(OPind, ty, e1);
		if (ty == TYstruct)
		    e1->Enumbytes = v->type->size();
		e1 = el_bin(OPeq, ty, e1, ep);
		if (ty == TYstruct)
		{   e1->Eoper = OPstreq;
		    e1->Enumbytes = v->type->size();
		}
	    }
	    e = el_combine(e, e1);
	}
    }

    elem *ev = el_var(stmp);
    ev->Enumbytes = sd->structsize;
    e = el_combine(e, ev);
    el_setLoc(e,loc);
    return e;
}
