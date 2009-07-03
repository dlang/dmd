// Copyright (c) 1999-2004 by Digital Mars
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

#if linux
#include "../root/mem.h"
#endif
#if _WIN32
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

Identifier *MatchExp::opId()   { return Id::match; }

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
    Array args1;
    Array args2;
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
