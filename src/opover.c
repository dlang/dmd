// Copyright (c) 1999-2006 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <assert.h>
#include <complex.h>

#ifdef __APPLE__
#define integer_t dmd_integer_t
#endif

#if IN_GCC
#include "mem.h"
#elif linux
#include "../root/mem.h"
#elif _WIN32
#include "..\root\mem.h"
#endif

#include "port.h"
#include "mtype.h"
#include "init.h"
#include "expression.h"
#include "id.h"
#include "declaration.h"
#include "aggregate.h"

static Expression *build_overload(Loc loc, Scope *sc, Expression *ethis, Expression *earg, Identifier *id);
static void inferApplyArgTypesX(FuncDeclaration *fstart, Array *arguments);

/******************************** Expression **************************/


/***********************************
 * Determine if operands of binary op can be reversed
 * to fit operator overload.
 */

int Expression::isCommutative()
{
    return FALSE;	// default is no reverse
}

/***********************************
 * Get Identifier for operator overload.
 */

Identifier *Expression::opId()
{
    assert(0);
    return NULL;
}

/***********************************
 * Get Identifier for reverse operator overload,
 * NULL if not supported for this operator.
 */

Identifier *Expression::opId_r()
{
    return NULL;
}

/************************* Operators *****************************/

Identifier *UAddExp::opId()   { return Id::uadd; }

Identifier *NegExp::opId()   { return Id::neg; }

Identifier *ComExp::opId()   { return Id::com; }

Identifier *CastExp::opId()   { return Id::cast; }

Identifier *InExp::opId()     { return Id::opIn; }
Identifier *InExp::opId_r()     { return Id::opIn_r; }

Identifier *PostIncExp::opId() { return Id::postinc; }

Identifier *PostDecExp::opId() { return Id::postdec; }

int AddExp::isCommutative()  { return TRUE; }
Identifier *AddExp::opId()   { return Id::add; }
Identifier *AddExp::opId_r() { return Id::add_r; }

Identifier *MinExp::opId()   { return Id::sub; }
Identifier *MinExp::opId_r() { return Id::sub_r; }

int MulExp::isCommutative()  { return TRUE; }
Identifier *MulExp::opId()   { return Id::mul; }
Identifier *MulExp::opId_r() { return Id::mul_r; }

Identifier *DivExp::opId()   { return Id::div; }
Identifier *DivExp::opId_r() { return Id::div_r; }

Identifier *ModExp::opId()   { return Id::mod; }
Identifier *ModExp::opId_r() { return Id::mod_r; }

Identifier *ShlExp::opId()   { return Id::shl; }
Identifier *ShlExp::opId_r() { return Id::shl_r; }

Identifier *ShrExp::opId()   { return Id::shr; }
Identifier *ShrExp::opId_r() { return Id::shr_r; }

Identifier *UshrExp::opId()   { return Id::ushr; }
Identifier *UshrExp::opId_r() { return Id::ushr_r; }

int AndExp::isCommutative()  { return TRUE; }
Identifier *AndExp::opId()   { return Id::iand; }
Identifier *AndExp::opId_r() { return Id::iand_r; }

int OrExp::isCommutative()  { return TRUE; }
Identifier *OrExp::opId()   { return Id::ior; }
Identifier *OrExp::opId_r() { return Id::ior_r; }

int XorExp::isCommutative()  { return TRUE; }
Identifier *XorExp::opId()   { return Id::ixor; }
Identifier *XorExp::opId_r() { return Id::ixor_r; }

Identifier *CatExp::opId()   { return Id::cat; }
Identifier *CatExp::opId_r() { return Id::cat_r; }

Identifier * AddAssignExp::opId()  { return Id::addass;  }
Identifier * MinAssignExp::opId()  { return Id::subass;  }
Identifier * MulAssignExp::opId()  { return Id::mulass;  }
Identifier * DivAssignExp::opId()  { return Id::divass;  }
Identifier * ModAssignExp::opId()  { return Id::modass;  }
Identifier * AndAssignExp::opId()  { return Id::andass;  }
Identifier *  OrAssignExp::opId()  { return Id::orass;   }
Identifier * XorAssignExp::opId()  { return Id::xorass;  }
Identifier * ShlAssignExp::opId()  { return Id::shlass;  }
Identifier * ShrAssignExp::opId()  { return Id::shrass;  }
Identifier *UshrAssignExp::opId()  { return Id::ushrass; }
Identifier * CatAssignExp::opId()  { return Id::catass;  }

int EqualExp::isCommutative()  { return TRUE; }
Identifier *EqualExp::opId()   { return Id::eq; }

int CmpExp::isCommutative()  { return TRUE; }
Identifier *CmpExp::opId()   { return Id::cmp; }

Identifier *ArrayExp::opId()	{ return Id::index; }


/************************************
 * Operator overload.
 * Check for operator overload, if so, replace
 * with function call.
 * Return NULL if not an operator overload.
 */

Expression *UnaExp::op_overload(Scope *sc)
{
    AggregateDeclaration *ad;
    FuncDeclaration *fd;
    Type *t1 = e1->type->toBasetype();

    if (t1->ty == Tclass)
    {
	ad = ((TypeClass *)t1)->sym;
	goto L1;
    }
    else if (t1->ty == Tstruct)
    {
	ad = ((TypeStruct *)t1)->sym;

    L1:
	fd = search_function(ad, opId());
	if (fd)
	{
	    if (op == TOKarray)
	    {
		Expression *e;
		ArrayExp *ae = (ArrayExp *)this;

		e = new DotIdExp(loc, e1, fd->ident);
		e = new CallExp(loc, e, ae->arguments);
		e = e->semantic(sc);
		return e;
	    }
	    else
	    {
		// Rewrite +e1 as e1.add()
		return build_overload(loc, sc, e1, NULL, fd->ident);
	    }
	}
    }
    return NULL;
}


Expression *BinExp::op_overload(Scope *sc)
{
    //printf("BinExp::op_overload() (%s)\n", toChars());

    AggregateDeclaration *ad;
    Type *t1 = e1->type->toBasetype();
    Type *t2 = e2->type->toBasetype();
    Identifier *id = opId();
    Identifier *id_r = opId_r();

    Match m;
    Expressions args1;
    Expressions args2;
    int argsset = 0;

    AggregateDeclaration *ad1;
    if (t1->ty == Tclass)
	ad1 = ((TypeClass *)t1)->sym;
    else if (t1->ty == Tstruct)
	ad1 = ((TypeStruct *)t1)->sym;
    else
	ad1 = NULL;

    AggregateDeclaration *ad2;
    if (t2->ty == Tclass)
	ad2 = ((TypeClass *)t2)->sym;
    else if (t2->ty == Tstruct)
	ad2 = ((TypeStruct *)t2)->sym;
    else
	ad2 = NULL;

    FuncDeclaration *fd = NULL;
    FuncDeclaration *fd_r = NULL;
    if (ad1 && id)
    {
	fd = search_function(ad1, id);
    }
    if (ad2 && id_r)
    {
	fd_r = search_function(ad2, id_r);
    }

    if (fd || fd_r)
    {
	/* Try:
	 *	a.opfunc(b)
	 *	b.opfunc_r(a)
	 * and see which is better.
	 */
	Expression *e;
	FuncDeclaration *lastf;

	args1.setDim(1);
	args1.data[0] = (void*) e1;
	args2.setDim(1);
	args2.data[0] = (void*) e2;
	argsset = 1;

	memset(&m, 0, sizeof(m));
	m.last = MATCHnomatch;
	overloadResolveX(&m, fd, &args2);
	lastf = m.lastf;
	overloadResolveX(&m, fd_r, &args1);

	if (m.count > 1)
	{
	    // Error, ambiguous
	    error("overloads %s and %s both match argument list for %s",
		    m.lastf->type->toChars(),
		    m.nextf->type->toChars(),
		    m.lastf->toChars());
	}
	else if (m.last == MATCHnomatch)
	{
	    m.lastf = m.anyf;
	}

	if (op == TOKplusplus || op == TOKminusminus)
	    // Kludge because operator overloading regards e++ and e--
	    // as unary, but it's implemented as a binary.
	    // Rewrite (e1 ++ e2) as e1.postinc()
	    // Rewrite (e1 -- e2) as e1.postdec()
	    e = build_overload(loc, sc, e1, NULL, id);
	else if (lastf && m.lastf == lastf || m.last == MATCHnomatch)
	    // Rewrite (e1 op e2) as e1.opfunc(e2)
	    e = build_overload(loc, sc, e1, e2, id);
	else
	    // Rewrite (e1 op e2) as e2.opfunc_r(e1)
	    e = build_overload(loc, sc, e2, e1, id_r);
	return e;
    }

    if (isCommutative())
    {
	fd = NULL;
	fd_r = NULL;
	if (ad1 && id_r)
	{
	    fd_r = search_function(ad1, id_r);
	}
	if (ad2 && id)
	{
	    fd = search_function(ad2, id);
	}

	if (fd || fd_r)
	{
	    /* Try:
	     *	a.opfunc_r(b)
	     *	b.opfunc(a)
	     * and see which is better.
	     */
	    Expression *e;
	    FuncDeclaration *lastf;

	    if (!argsset)
	    {	args1.setDim(1);
		args1.data[0] = (void*) e1;
		args2.setDim(1);
		args2.data[0] = (void*) e2;
	    }

	    memset(&m, 0, sizeof(m));
	    m.last = MATCHnomatch;
	    overloadResolveX(&m, fd_r, &args2);
	    lastf = m.lastf;
	    overloadResolveX(&m, fd, &args1);

	    if (m.count > 1)
	    {
		// Error, ambiguous
		error("overloads %s and %s both match argument list for %s",
			m.lastf->type->toChars(),
			m.nextf->type->toChars(),
			m.lastf->toChars());
	    }
	    else if (m.last == MATCHnomatch)
	    {
		m.lastf = m.anyf;
	    }

	    if (lastf && m.lastf == lastf ||
		id_r && m.last == MATCHnomatch)
		// Rewrite (e1 op e2) as e1.opfunc_r(e2)
		e = build_overload(loc, sc, e1, e2, id_r);
	    else
		// Rewrite (e1 op e2) as e2.opfunc(e1)
		e = build_overload(loc, sc, e2, e1, id);

	    // When reversing operands of comparison operators,
	    // need to reverse the sense of the op
	    switch (op)
	    {
		case TOKlt:	op = TOKgt;	break;
		case TOKgt:	op = TOKlt;	break;
		case TOKle:	op = TOKge;	break;
		case TOKge:	op = TOKle;	break;

		// Floating point compares
		case TOKule:	op = TOKuge;	 break;
		case TOKul:	op = TOKug;	 break;
		case TOKuge:	op = TOKule;	 break;
		case TOKug:	op = TOKul;	 break;

		// These are symmetric
		case TOKunord:
		case TOKlg:
		case TOKleg:
		case TOKue:
		    break;
	    }

	    return e;
	}
    }

    return NULL;
}

/***********************************
 * Utility to build a function call out of this reference and argument.
 */

static Expression *build_overload(Loc loc, Scope *sc, Expression *ethis, Expression *earg, Identifier *id)
{
    Expression *e;

    //printf("build_overload(id = '%s')\n", id->toChars());
    //earg->print();
    //earg->type->print();
    e = new DotIdExp(loc, ethis, id);

    if (earg)
	e = new CallExp(loc, e, earg);
    else
	e = new CallExp(loc, e);

    e = e->semantic(sc);
    return e;
}

/***************************************
 * Search for function funcid in aggregate ad.
 */

FuncDeclaration *search_function(AggregateDeclaration *ad, Identifier *funcid)
{
    Dsymbol *s;
    FuncDeclaration *fd;

    s = ad->search(funcid, 0);
    if (s)
    {	Dsymbol *s2;

	//printf("search_function: s = '%s'\n", s->kind());
	s2 = s->toAlias();
	//printf("search_function: s2 = '%s'\n", s2->kind());
	fd = s2->isFuncDeclaration();
	if (fd && fd->type->ty == Tfunction)
	    return fd;

    }
    return NULL;
}


/*****************************************
 * Given array of arguments and an aggregate type,
 * if any of the argument types are missing, attempt to infer
 * them from the aggregate type.
 */

void inferApplyArgTypes(Array *arguments, Type *taggr)
{
    if (!arguments || !arguments->dim)
	return;

    /* Return if no arguments need types.
     */
    for (size_t u = 0; 1; u++)
    {	if (u == arguments->dim)
	    return;
	Argument *arg = (Argument *)arguments->data[u];
	if (!arg->type)
	    break;
    }

    AggregateDeclaration *ad;
    FuncDeclaration *fd;

    Argument *arg = (Argument *)arguments->data[0];
    Type *tab = taggr->toBasetype();
    switch (tab->ty)
    {
	case Tarray:
	case Tsarray:
	    if (arguments->dim == 2)
	    {
		if (!arg->type)
		    arg->type = Type::tsize_t;	// key type
		arg = (Argument *)arguments->data[1];
	    }
	    if (!arg->type)
		arg->type = tab->next;		// value type
	    break;

	case Taarray:
	{   TypeAArray *taa = (TypeAArray *)tab;

	    if (arguments->dim == 2)
	    {
		if (!arg->type)
		    arg->type = taa->index;	// key type
		arg = (Argument *)arguments->data[1];
	    }
	    if (!arg->type)
		arg->type = taa->next;		// value type
	    break;
	}

	case Tclass:
	    ad = ((TypeClass *)tab)->sym;
	    goto Laggr;

	case Tstruct:
	    ad = ((TypeStruct *)tab)->sym;
	    goto Laggr;

	Laggr:
#if 0
	    if (arguments->dim == 1)
	    {
		if (!arg->type)
		{
		    /* Look for an opNext() overload
		     */
		    fd = search_function(ad, Id::next);
		    if (!fd)
			goto Lapply;
		    arg->type = fd->type->next;
		}
		break;
	    }
#endif
	Lapply:
	    /* Look for an
	     *	int opApply(int delegate(inout Type [, ...]) dg);
	     * overload
	     */
	    fd = search_function(ad, Id::apply);
	    if (!fd)
		break;
	    inferApplyArgTypesX(fd, arguments);
	    break;

	default:
	    break;		// ignore error, caught later
    }
}

/********************************
 * Recursive helper function,
 * analogous to func.overloadResolveX().
 */

static void inferApplyArgTypesX(FuncDeclaration *fstart, Array *arguments)
{
    Declaration *d;
    Declaration *next;

    for (d = fstart; d; d = next)
    {
	FuncDeclaration *f;
	FuncAliasDeclaration *fa;
	AliasDeclaration *a;

	fa = d->isFuncAliasDeclaration();
	if (fa)
	{
	    inferApplyArgTypesX(fa->funcalias, arguments);
	    next = fa->overnext;
	}
	else if ((f = d->isFuncDeclaration()) != NULL)
	{
	    next = f->overnext;

	    TypeFunction *tf = (TypeFunction *)f->type;
	    if (!tf->arguments || tf->arguments->dim != 1)
		continue;
	    Argument *p = (Argument *)tf->arguments->data[0];
	    if (p->type->ty != Tdelegate)
		continue;
	    tf = (TypeFunction *)p->type->next;
	    assert(tf->ty == Tfunction);

	    /* We now have tf, the type of the delegate. Match it against
	     * the arguments, filling in missing argument types.
	     */
	    if (!tf->arguments || tf->varargs)
		continue;		// not enough parameters
	    unsigned nparams = tf->arguments->dim;
	    if (arguments->dim != nparams)
		continue;		// not enough parameters

	    for (unsigned u = 0; u < nparams; u++)
	    {
		p = (Argument *)arguments->data[u];
		Argument *tp = (Argument *)tf->arguments->data[u];
		if (p->type)
		{   if (!p->type->equals(tp->type))
		    {
			/* Cannot resolve argument types. Indicate an
			 * error by setting the number of arguments to 0.
			 */
			arguments->dim = 0;
			return;
		    }
		    continue;
		}
		p->type = tp->type;
	    }
	}
	else if ((a = d->isAliasDeclaration()) != NULL)
	{
	    Dsymbol *s = a->toAlias();
	    next = s->isDeclaration();
	    if (next == a)
		break;
	    if (next == fstart)
		break;
	}
	else
	{   d->error("is aliased to a function");
	    break;
	}
    }
}


