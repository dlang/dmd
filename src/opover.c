// Copyright (c) 1999-2002 by Digital Mars
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

Identifier *NegExp::opId()   { return Id::neg; }

Identifier *ComExp::opId()   { return Id::com; }

Identifier *PostIncExp::opId() { return Id::postinc; }

Identifier *PostDecExp::opId() { return Id::postdec; }

int AddExp::isCommutative()  { return TRUE; }
Identifier *AddExp::opId()   { return Id::add; }

Identifier *MinExp::opId()   { return Id::sub; }
Identifier *MinExp::opId_r() { return Id::sub_r; }

int MulExp::isCommutative()  { return TRUE; }
Identifier *MulExp::opId()   { return Id::mul; }

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

int OrExp::isCommutative()  { return TRUE; }
Identifier *OrExp::opId()   { return Id::ior; }

int XorExp::isCommutative()  { return TRUE; }
Identifier *XorExp::opId()   { return Id::ixor; }

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

Identifier *IndexExp::opId()	{ return Id::index; }


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
	    // Rewrite +e1 as e1.add()
	    return build_overload(loc, sc, e1, NULL, fd->ident);
	}
    }
    return NULL;
}


Expression *BinExp::op_overload(Scope *sc)
{
    AggregateDeclaration *ad;
    FuncDeclaration *fd;
    Type *t1 = e1->type->toBasetype();
    Type *t2 = e2->type->toBasetype();

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
	{   Expression *e;

	    if (op == TOKplusplus || op == TOKminusminus)
		// Kludge because operator overloading regards e++ and e--
		// as unary, but it's implemented as a binary.
		// Rewrite (e1 ++ e2) as e1.postinc()
		// Rewrite (e1 -- e2) as e1.postdec()
		e = build_overload(loc, sc, e1, NULL, fd->ident);
	    else
		// Rewrite (e1 op e2) as e1.opfunc(e2)
		e = build_overload(loc, sc, e1, e2, fd->ident);
	    return e;
	}
    }

    if (t2->ty == Tclass)
    {
	ad = ((TypeClass *)t2)->sym;
	goto L2;
    }
    else if (t2->ty == Tstruct)
    {
	ad = ((TypeStruct *)t2)->sym;

    L2:
	Identifier *id_r = opId_r();

	if (id_r)
	{
	    fd = search_function(ad, id_r);
	    if (fd)
	    {
		// Rewrite (e1 + e2) as e2.add_r(e1)
		return build_overload(loc, sc, e2, e1, fd->ident);
	    }
	}

	if (isCommutative())
	{
	    fd = search_function(ad, opId());
	    if (fd)
	    {
		// Rewrite (e1 + e2) as e2.add(e1)
		Expression *e;

		e = build_overload(loc, sc, e2, e1, fd->ident);

		// When reversing operands of comparison operators,
		// need to reverse the sense of the op
		switch (op)
		{
		    case TOKlt:	op = TOKgt;	break;
		    case TOKgt:	op = TOKlt;	break;
		    case TOKle:	op = TOKge;	break;
		    case TOKge:	op = TOKle;	break;

		    // Floating point compares
		    case TOKule:   op = TOKuge;	 break;
		    case TOKul:	   op = TOKug;	 break;
		    case TOKuge:   op = TOKule;	 break;
		    case TOKug:	   op = TOKul;	 break;

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
    {
	fd = s->isFuncDeclaration();
	if (fd && fd->type->ty == Tfunction)
	    return fd;

    }
    return NULL;
}
