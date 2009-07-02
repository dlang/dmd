
// Copyright (c) 1999-2004 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <math.h>

#if __DMC__
#include <complex.h>
#endif

#include "mtype.h"
#include "expression.h"

static real_t zero;	// work around DMC bug for now


/* ================================== isConst() ============================== */

int Expression::isConst()
{
    //printf("Expression::isConst(): %s\n", toChars());
    return 0;
}

int IntegerExp::isConst()
{
    return 1;
}

int RealExp::isConst()
{
    return 1;
}

int ImaginaryExp::isConst()
{
    return 1;
}

int ComplexExp::isConst()
{
    return 1;
}

int SymOffExp::isConst()
{
    return 2;
}

/* ================================== constFold() ============================== */

Expression *Expression::constFold()
{
    return this;
}

Expression *NegExp::constFold()
{
    e1 = e1->constFold();
    if (e1->type->isreal())
    {	RealExp *e;

	e = new RealExp(loc, -e1->toReal(), type);
	return e;
    }
    else if (e1->type->isimaginary())
    {	ImaginaryExp *e;

	e = new ImaginaryExp(loc, -e1->toImaginary(), type);
	return e;
    }
    else if (e1->type->iscomplex())
    {	ComplexExp *e;

	e = new ComplexExp(loc, -e1->toComplex(), type);
	return e;
    }
    else
	return new IntegerExp(loc, -e1->toInteger(), type);
}

Expression *ComExp::constFold()
{
    e1 = e1->constFold();
    return new IntegerExp(loc, ~e1->toInteger(), type);
}

Expression *NotExp::constFold()
{
    e1 = e1->constFold();
    return new IntegerExp(loc, e1->isBool(0), type);
}

Expression *BoolExp::constFold()
{
    e1 = e1->constFold();
    return new IntegerExp(loc, e1->isBool(1), type);
}

Expression *CastExp::constFold()
{
    //printf("CastExp::constFold(%s)\n", toChars());

    e1 = e1->constFold();
    if (e1->op == TOKsymoff && type->size() == e1->type->size())
    {
	e1->type = type;
	return e1;
    }

    if (type->toBasetype()->ty == Tbit)
	return new IntegerExp(loc, e1->toInteger() != 0, type);
    if (type->isintegral())
	return new IntegerExp(loc, e1->toInteger(), type);
    if (type->isreal())
	return new RealExp(loc, e1->toReal(), type);
    if (type->isimaginary())
	return new ImaginaryExp(loc, e1->toImaginary(), type);
    if (type->iscomplex())
	return new ComplexExp(loc, e1->toComplex(), type);
    if (type->isscalar())
	return new IntegerExp(loc, e1->toInteger(), type);
    if (type->toBasetype()->ty != Tvoid)
	error("cannot cast %s to %s", e1->type->toChars(), type->toChars());
    return this;
}

Expression *AddExp::constFold()
{
    Expression *e;

    //printf("AddExp::constFold(%s)\n", toChars());
    e1 = e1->constFold();
    e2 = e2->constFold();
    if (e1->op == TOKsymoff && e2->op == TOKsymoff)
	return this;
    if (type->isreal())
    {
	e = new RealExp(loc, e1->toReal() + e2->toReal(), type);
    }
    else if (type->isimaginary())
    {
	e = new ImaginaryExp(loc, e1->toImaginary() + e2->toImaginary(), type);
    }
    else if (type->iscomplex())
    {
	e = new ComplexExp(loc, e1->toComplex() + e2->toComplex(), type);
    }
    else if (e1->op == TOKsymoff)
    {
	SymOffExp *soe = (SymOffExp *)e1;
	e = new SymOffExp(loc, soe->var, soe->offset + e2->toInteger());
	e->type = type;
    }
    else if (e2->op == TOKsymoff)
    {
	SymOffExp *soe = (SymOffExp *)e2;
	e = new SymOffExp(loc, soe->var, soe->offset + e1->toInteger());
	e->type = type;
    }
    else
	e = new IntegerExp(loc, e1->toInteger() + e2->toInteger(), type);
    return e;
}

Expression *MinExp::constFold()
{
    Expression *e;

    e1 = e1->constFold();
    e2 = e2->constFold();
    if (e2->op == TOKsymoff)
	return this;
    if (type->isreal())
    {
	e = new RealExp(loc, e1->toReal() - e2->toReal(), type);
    }
    else if (type->isimaginary())
    {
	e = new ImaginaryExp(loc, e1->toImaginary() - e2->toImaginary(), type);
    }
    else if (type->iscomplex())
    {
	e = new ComplexExp(loc, e1->toComplex() - e2->toComplex(), type);
    }
    else if (e1->op == TOKsymoff)
    {
	SymOffExp *soe = (SymOffExp *)e1;
	e = new SymOffExp(loc, soe->var, soe->offset - e2->toInteger());
	e->type = type;
    }
    else
    {
	e = new IntegerExp(loc, e1->toInteger() - e2->toInteger(), type);
    }
    return e;
}

Expression *MulExp::constFold()
{   Expression *e;

    e1 = e1->constFold();
    e2 = e2->constFold();
    if (type->isfloating())
    {	complex_t c;

	if (e1->type->isreal())
	    c = e1->toReal() * e2->toComplex();
	else if (e1->type->isimaginary())
	    c = e1->toImaginary() * e2->toComplex();
	else if (e2->type->isreal())
	    c = e1->toComplex() * e2->toReal();
	else if (e2->type->isimaginary())
	    c = e1->toComplex() * e2->toImaginary();
	else
	    c = e1->toComplex() * e2->toComplex();

	if (type->isreal())
	    e = new RealExp(loc, creall(c), type);
	else if (type->isimaginary())
	    e = new ImaginaryExp(loc, cimagl(c), type);
	else if (type->iscomplex())
	    e = new ComplexExp(loc, c, type);
	else
	    assert(0);
    }
    else
    {
	e = new IntegerExp(loc, e1->toInteger() * e2->toInteger(), type);
    }
    return e;
}

Expression *DivExp::constFold()
{   Expression *e;

    e1 = e1->constFold();
    e2 = e2->constFold();
    if (type->isfloating())
    {	complex_t c;

	if (e2->type->isreal())
	    c = e1->toComplex() / e2->toReal();
	else if (e2->type->isimaginary())
	    c = e1->toComplex() / e2->toImaginary();
	else
	    c = e1->toComplex() / e2->toComplex();

	if (type->isreal())
	    e = new RealExp(loc, creall(c), type);
	else if (type->isimaginary())
	    e = new ImaginaryExp(loc, cimagl(c), type);
	else if (type->iscomplex())
	    e = new ComplexExp(loc, c, type);
	else
	    assert(0);
    }
    else
    {	integer_t n1;
	integer_t n2;
	integer_t n;

	n1 = e1->toInteger();
	n2 = e2->toInteger();
	if (isunsigned())
	    n = ((d_uns64) n1) / ((d_uns64) n2);
	else
	    n = n1 / n2;
	e = new IntegerExp(loc, n, type);
    }
    return e;
}

Expression *ModExp::constFold()
{   Expression *e;

    e1 = e1->constFold();
    e2 = e2->constFold();
    if (type->isreal())
    {	real_t c;

	c = fmodl(e1->toReal(), e2->toReal());
	e = new RealExp(loc, c, type);
    }
    else if (type->isfloating())
    {
	assert(0);
    }
    else
    {	integer_t n1;
	integer_t n2;
	integer_t n;

	n1 = e1->toInteger();
	n2 = e2->toInteger();
	if (isunsigned())
	    n = ((d_uns64) n1) % ((d_uns64) n2);
	else
	    n = n1 % n2;
	e = new IntegerExp(loc, n, type);
    }
    return e;
}

Expression *ShlExp::constFold()
{
    //printf("ShlExp::constFold(%s)\n", toChars());
    e1 = e1->constFold();
    e2 = e2->constFold();
    return new IntegerExp(loc, e1->toInteger() << e2->toInteger(), type);
}

Expression *ShrExp::constFold()
{
    unsigned count;
    integer_t value;

    e1 = e1->constFold();
    e2 = e2->constFold();
    value = e1->toInteger();
    count = e2->toInteger();
    switch (e1->type->ty)
    {
	case Tint8:
	case Tuns8:
		value = (d_int8)(value) >> count;
		break;

	case Tint16:
	case Tuns16:
		value = (d_int16)(value) >> count;
		break;

	case Tint32:
	case Tuns32:
		value = (d_int32)(value) >> count;
		break;

	case Tint64:
	case Tuns64:
		value = (d_int64)(value) >> count;
		break;
    }
    return new IntegerExp(loc, value, type);
}

Expression *UshrExp::constFold()
{
    unsigned count;
    integer_t value;

    e1 = e1->constFold();
    e2 = e2->constFold();
    value = e1->toInteger();
    count = e2->toInteger();
    switch (e1->type->ty)
    {
	case Tint8:
	case Tuns8:
		value = (value & 0xFF) >> count;
		break;

	case Tint16:
	case Tuns16:
		value = (value & 0xFFFF) >> count;
		break;

	case Tint32:
	case Tuns32:
		value = (value & 0xFFFFFFFF) >> count;
		break;

	case Tint64:
	case Tuns64:
		value = (d_uns64)(value) >> count;
		break;
    }
    return new IntegerExp(loc, value, type);
}

Expression *AndExp::constFold()
{
    e1 = e1->constFold();
    e2 = e2->constFold();
    return new IntegerExp(loc, e1->toInteger() & e2->toInteger(), type);
}

Expression *OrExp::constFold()
{
    e1 = e1->constFold();
    e2 = e2->constFold();
    return new IntegerExp(loc, e1->toInteger() | e2->toInteger(), type);
}

Expression *XorExp::constFold()
{
    e1 = e1->constFold();
    e2 = e2->constFold();
    return new IntegerExp(loc, e1->toInteger() ^ e2->toInteger(), type);
}

Expression *AndAndExp::constFold()
{   integer_t n;

    e1 = e1->constFold();
    e2 = e2->constFold();
    if (e1->type->isfloating())
	n = e1->toComplex() && e2->toComplex();
    else
	n = e1->toInteger() && e2->toInteger();
    return new IntegerExp(loc, n, type);
}

Expression *OrOrExp::constFold()
{   integer_t n;

    e1 = e1->constFold();
    e2 = e2->constFold();
    if (e1->type->isfloating())
	n = e1->toComplex() || e2->toComplex();
    else
	n = e1->toInteger() || e2->toInteger();
    return new IntegerExp(loc, n, type);
}

Expression *CmpExp::constFold()
{   integer_t n;
    real_t r1;
    real_t r2;

    e1 = e1->constFold();
    e2 = e2->constFold();
    if (e1->type->isreal())
    {
	r1 = e1->toReal();
	r2 = e2->toReal();
	goto L1;
    }
    else if (e1->type->isimaginary())
    {
	r1 = e1->toImaginary();
	r2 = e2->toImaginary();
     L1:
#if __DMC__
	// DMC is the only compiler I know of that handles NAN arguments
	// correctly in comparisons.
	switch (op)
	{
	    case TOKlt:	   n = r1 <  r2;	break;
	    case TOKle:	   n = r1 <= r2;	break;
	    case TOKgt:	   n = r1 >  r2;	break;
	    case TOKge:	   n = r1 >= r2;	break;

	    case TOKleg:   n = r1 <>=  r2;	break;
	    case TOKlg:	   n = r1 <>   r2;	break;
	    case TOKunord: n = r1 !<>= r2;	break;
	    case TOKue:	   n = r1 !<>  r2;	break;
	    case TOKug:	   n = r1 !<=  r2;	break;
	    case TOKuge:   n = r1 !<   r2;	break;
	    case TOKul:	   n = r1 !>=  r2;	break;
	    case TOKule:   n = r1 !>   r2;	break;

	    default:
		assert(0);
	}
#else
	// Don't rely on compiler, handle NAN arguments separately
	if (isnan(r1) || isnan(r2))	// if unordered
	{
	    switch (op)
	    {
		case TOKlt:	n = 0;	break;
		case TOKle:	n = 0;	break;
		case TOKgt:	n = 0;	break;
		case TOKge:	n = 0;	break;

		case TOKleg:	n = 0;	break;
		case TOKlg:	n = 0;	break;
		case TOKunord:	n = 1;	break;
		case TOKue:	n = 1;	break;
		case TOKug:	n = 1;	break;
		case TOKuge:	n = 1;	break;
		case TOKul:	n = 1;	break;
		case TOKule:	n = 1;	break;

		default:
		    assert(0);
	    }
	}
	else
	{
	    switch (op)
	    {
		case TOKlt:	n = r1 <  r2;	break;
		case TOKle:	n = r1 <= r2;	break;
		case TOKgt:	n = r1 >  r2;	break;
		case TOKge:	n = r1 >= r2;	break;

		case TOKleg:	n = 1;		break;
		case TOKlg:	n = r1 != r2;	break;
		case TOKunord:	n = 0;		break;
		case TOKue:	n = r1 == r2;	break;
		case TOKug:	n = r1 >  r2;	break;
		case TOKuge:	n = r1 >= r2;	break;
		case TOKul:	n = r1 <  r2;	break;
		case TOKule:	n = r1 <= r2;	break;

		default:
		    assert(0);
	    }
	}
#endif
    }
    else if (e1->type->iscomplex())
    {
	assert(0);
    }
    else
    {	integer_t n1;
	integer_t n2;

	n1 = e1->toInteger();
	n2 = e2->toInteger();
	if (isunsigned())
	{
	    switch (op)
	    {
		case TOKlt:	n = ((d_uns64) n1) <  ((d_uns64) n2);	break;
		case TOKle:	n = ((d_uns64) n1) <= ((d_uns64) n2);	break;
		case TOKgt:	n = ((d_uns64) n1) >  ((d_uns64) n2);	break;
		case TOKge:	n = ((d_uns64) n1) >= ((d_uns64) n2);	break;

		case TOKleg:	n = 1;					break;
		case TOKlg:	n = ((d_uns64) n1) != ((d_uns64) n2);	break;
		case TOKunord:	n = 0;					break;
		case TOKue:	n = ((d_uns64) n1) == ((d_uns64) n2);	break;
		case TOKug:	n = ((d_uns64) n1) >  ((d_uns64) n2);	break;
		case TOKuge:	n = ((d_uns64) n1) >= ((d_uns64) n2);	break;
		case TOKul:	n = ((d_uns64) n1) <  ((d_uns64) n2);	break;
		case TOKule:	n = ((d_uns64) n1) <= ((d_uns64) n2);	break;

		default:
		    assert(0);
	    }
	}
	else
	{
	    switch (op)
	    {
		case TOKlt:	n = n1 <  n2;	break;
		case TOKle:	n = n1 <= n2;	break;
		case TOKgt:	n = n1 >  n2;	break;
		case TOKge:	n = n1 >= n2;	break;

		case TOKleg:	n = 1;		break;
		case TOKlg:	n = n1 != n2;	break;
		case TOKunord:	n = 0;		break;
		case TOKue:	n = n1 == n2;	break;
		case TOKug:	n = n1 >  n2;	break;
		case TOKuge:	n = n1 >= n2;	break;
		case TOKul:	n = n1 <  n2;	break;
		case TOKule:	n = n1 <= n2;	break;

		default:
		    assert(0);
	    }
	}
    }
    return new IntegerExp(loc, n, type);
}

Expression *EqualExp::constFold()
{   int cmp;
    real_t r1;
    real_t r2;

    assert(op == TOKequal || op == TOKnotequal);
    e1 = e1->constFold();
    e2 = e2->constFold();
    if (e1->type->isreal())
    {
	r1 = e1->toReal();
	r2 = e2->toReal();
	goto L1;
    }
    else if (e1->type->isimaginary())
    {
	r1 = e1->toImaginary();
	r2 = e2->toImaginary();
     L1:
#if __DMC__
	cmp = (r1 == r2);
#else
	if (isnan(r1) || isnan(r2))	// if unordered
	{
	    cmp = 0;
	}
	else
	{
	    cmp = (r1 == r2);
	}
#endif
    }
    else if (e1->type->iscomplex())
    {
	cmp = e1->toComplex() == e2->toComplex();
    }
    else
    {
	cmp = (e1->toInteger() == e2->toInteger());
    }
    if (op == TOKnotequal)
	cmp ^= 1;
    return new IntegerExp(loc, cmp, type);
}

Expression *IdentityExp::constFold()
{   int cmp;

    e1 = e1->constFold();
    e2 = e2->constFold();
    if (e1->type->isfloating())
    {
	cmp = e1->toComplex() == e2->toComplex();
    }
    else if (e1->type->isintegral())
    {
	cmp = (e1->toInteger() == e2->toInteger());
    }
    else if (e1->op == TOKsymoff && e2->op == TOKsymoff)
    {
	SymOffExp *es1 = (SymOffExp *)e1;
	SymOffExp *es2 = (SymOffExp *)e2;

	cmp = (es1->var == es2->var && es1->offset == es2->offset);
    }
    else
    {
	return this;
    }
    if (op == TOKnotidentity)
	cmp ^= 1;
    return new IntegerExp(loc, cmp, type);
}


Expression *CondExp::constFold()
{
    int n;

    econd = econd->constFold();
    if (econd->type->isfloating())
	n = econd->toComplex() != 0;
    else
	n = econd->toInteger() != 0;
    return n ? e1->constFold() : e2->constFold();
}

