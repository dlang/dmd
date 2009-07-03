
// Compiler implementation of the D programming language
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
#include <math.h>

#if __DMC__
#include <complex.h>
#endif

#include "mtype.h"
#include "expression.h"

#ifdef IN_GCC
#include "d-gcc-real.h"

/* %% fix? */
extern "C" bool real_isnan (const real_t *);
#endif

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
    {	RealExp *e;

	e = new RealExp(loc, -e1->toImaginary(), type);
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
    //printf("from %s to %s\n", type->toChars(), to->toChars());
    //printf("type = %p\n", type);
    assert(type);

    e1 = e1->constFold();
    if (e1->op == TOKsymoff)
    {
	if (type->size() == e1->type->size() &&
	    type->toBasetype()->ty != Tsarray)
	{
	    e1->type = type;
	    return e1;
	}
	return this;
    }

    Type *tb = to->toBasetype();
    if (tb->ty == Tbit || tb->ty == Tbool)
	return new IntegerExp(loc, e1->toInteger() != 0, type);
    if (type->isintegral())
    {
	if (e1->type->isfloating())
	{   integer_t result;
	    real_t r = e1->toReal();

	    switch (type->toBasetype()->ty)
	    {
		case Tint8:	result = (d_int8)r;	break;
		case Tchar:
		case Tuns8:	result = (d_uns8)r;	break;
		case Tint16:	result = (d_int16)r;	break;
		case Twchar:
		case Tuns16:	result = (d_uns16)r;	break;
		case Tint32:	result = (d_int32)r;	break;
		case Tdchar:
		case Tuns32:	result = (d_uns32)r;	break;
		case Tint64:	result = (d_int64)r;	break;
		case Tuns64:	result = (d_uns64)r;	break;
		default:
		    assert(0);
	    }

	    return new IntegerExp(loc, result, type);
	}
	if (type->isunsigned())
	    return new IntegerExp(loc, e1->toUInteger(), type);
	else
	    return new IntegerExp(loc, e1->toInteger(), type);
    }
    if (tb->isreal())
    {	real_t value = e1->toReal();

	return new RealExp(loc, value, type);
    }
    if (tb->isimaginary())
    {	real_t value = e1->toImaginary();

	return new RealExp(loc, value, type);
    }
    if (tb->iscomplex())
    {	complex_t value = e1->toComplex();

	return new ComplexExp(loc, value, type);
    }
    if (tb->isscalar())
	return new IntegerExp(loc, e1->toInteger(), type);
    if (tb->ty != Tvoid)
	error("cannot cast %s to %s", e1->type->toChars(), to->toChars());
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
	e = new RealExp(loc, e1->toImaginary() + e2->toImaginary(), type);
    }
    else if (type->iscomplex())
    {
	// This rigamarole is necessary so that -0.0 doesn't get
	// converted to +0.0 by doing an extraneous add with +0.0
	complex_t c1;
	real_t r1;
	real_t i1;

	complex_t c2;
	real_t r2;
	real_t i2;

	complex_t v;
	int x;

	if (e1->type->isreal())
	{   r1 = e1->toReal();
	    x = 0;
	}
	else if (e1->type->isimaginary())
	{   i1 = e1->toImaginary();
	    x = 3;
	}
	else
	{   c1 = e1->toComplex();
	    x = 6;
	}

	if (e2->type->isreal())
	{   r2 = e2->toReal();
	}
	else if (e2->type->isimaginary())
	{   i2 = e2->toImaginary();
	    x += 1;
	}
	else
	{   c2 = e2->toComplex();
	    x += 2;
	}

	switch (x)
	{
#if __DMC__
	    case 0+0:	v = (complex_t) (r1 + r2);	break;
	    case 0+1:	v = r1 + i2 * I;		break;
	    case 0+2:	v = r1 + c2;			break;
	    case 3+0:	v = i1 * I + r2;		break;
	    case 3+1:	v = (complex_t) ((i1 + i2) * I); break;
	    case 3+2:	v = i1 * I + c2;		break;
	    case 6+0:	v = c1 + r2;			break;
	    case 6+1:	v = c1 + i2 * I;		break;
	    case 6+2:	v = c1 + c2;			break;
#else
	    case 0+0:	v = complex_t(r1 + r2, 0);	break;
	    case 0+1:	v = complex_t(r1, i2);		break;
	    case 0+2:	v = complex_t(r1 + creall(c2), cimagl(c2));	break;
	    case 3+0:	v = complex_t(r2, i1);		break;
	    case 3+1:	v = complex_t(0, i1 + i2);	break;
	    case 3+2:	v = complex_t(creall(c2), i1 + cimagl(c2));	break;
	    case 6+0:	v = complex_t(creall(c1) + r2, cimagl(c2));	break;
	    case 6+1:	v = complex_t(creall(c1), cimagl(c1) + i2);	break;
	    case 6+2:	v = c1 + c2;			break;
#endif
	    default: assert(0);
	}
	e = new ComplexExp(loc, v, type);
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
	e = new RealExp(loc, e1->toImaginary() - e2->toImaginary(), type);
    }
    else if (type->iscomplex())
    {
	// This rigamarole is necessary so that -0.0 doesn't get
	// converted to +0.0 by doing an extraneous add with +0.0
	complex_t c1;
	real_t r1;
	real_t i1;

	complex_t c2;
	real_t r2;
	real_t i2;

	complex_t v;
	int x;

	if (e1->type->isreal())
	{   r1 = e1->toReal();
	    x = 0;
	}
	else if (e1->type->isimaginary())
	{   i1 = e1->toImaginary();
	    x = 3;
	}
	else
	{   c1 = e1->toComplex();
	    x = 6;
	}

	if (e2->type->isreal())
	{   r2 = e2->toReal();
	}
	else if (e2->type->isimaginary())
	{   i2 = e2->toImaginary();
	    x += 1;
	}
	else
	{   c2 = e2->toComplex();
	    x += 2;
	}

	switch (x)
	{
#if __DMC__
	    case 0+0:	v = (complex_t) (r1 - r2);	break;
	    case 0+1:	v = r1 - i2 * I;		break;
	    case 0+2:	v = r1 - c2;			break;
	    case 3+0:	v = i1 * I - r2;		break;
	    case 3+1:	v = (complex_t) ((i1 - i2) * I); break;
	    case 3+2:	v = i1 * I - c2;		break;
	    case 6+0:	v = c1 - r2;			break;
	    case 6+1:	v = c1 - i2 * I;		break;
	    case 6+2:	v = c1 - c2;			break;
#else
	    case 0+0:	v = complex_t(r1 - r2, 0);	break;
	    case 0+1:	v = complex_t(r1, -i2);		break;
	    case 0+2:	v = complex_t(r1 - creall(c2), -cimagl(c2));	break;
	    case 3+0:	v = complex_t(-r2, i1);		break;
	    case 3+1:	v = complex_t(0, i1 - i2);	break;
	    case 3+2:	v = complex_t(-creall(c2), i1 - cimagl(c2));	break;
	    case 6+0:	v = complex_t(creall(c1) - r2, cimagl(c1));	break;
	    case 6+1:	v = complex_t(creall(c1), cimagl(c1) - i2);	break;
	    case 6+2:	v = c1 - c2;			break;
#endif
	    default: assert(0);
	}
	e = new ComplexExp(loc, v, type);
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

    //printf("MulExp::constFold(%s)\n", toChars());
    e1 = e1->constFold();
    e2 = e2->constFold();
    if (type->isfloating())
    {	complex_t c;
#ifdef IN_GCC
	real_t r;
#else
 	d_float80 r;
#endif

	if (e1->type->isreal())
	{
#if __DMC__
	    c = e1->toReal() * e2->toComplex();
#else
	    r = e1->toReal();
	    c = e2->toComplex();
	    c = complex_t(r * creall(c), r * cimagl(c));
#endif
	}
	else if (e1->type->isimaginary())
	{
#if __DMC__
	    c = e1->toImaginary() * I * e2->toComplex();
#else
	    r = e1->toImaginary();
	    c = e2->toComplex();
	    c = complex_t(-r * cimagl(c), r * creall(c));
#endif
	}
	else if (e2->type->isreal())
	{
#if __DMC__
	    c = e2->toReal() * e1->toComplex();
#else
	    r = e2->toReal();
	    c = e1->toComplex();
	    c = complex_t(r * creall(c), r * cimagl(c));
#endif
	}
	else if (e2->type->isimaginary())
	{
#if __DMC__
	    c = e1->toComplex() * e2->toImaginary() * I;
#else
	    r = e2->toImaginary();
	    c = e1->toComplex();
	    c = complex_t(-r * cimagl(c), r * creall(c));
#endif
	}
	else
	    c = e1->toComplex() * e2->toComplex();

	if (type->isreal())
	    e = new RealExp(loc, creall(c), type);
	else if (type->isimaginary())
	    e = new RealExp(loc, cimagl(c), type);
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

    //printf("DivExp::constFold(%s)\n", toChars());
    e1 = e1->constFold();
    e2 = e2->constFold();
    if (type->isfloating())
    {	complex_t c;
#ifdef IN_GCC
	real_t r;
#else
 	d_float80 r;
#endif

	//e1->type->print();
	//e2->type->print();
	if (e2->type->isreal())
	{
	    if (e1->type->isreal())
	    {
		e = new RealExp(loc, e1->toReal() / e2->toReal(), type);
		return e;
	    }
#if __DMC__
	    //r = e2->toReal();
	    //c = e1->toComplex();
	    //printf("(%Lg + %Lgi) / %Lg\n", creall(c), cimagl(c), r);

	    c = e1->toComplex() / e2->toReal();
#else
	    r = e2->toReal();
	    c = e1->toComplex();
	    c = complex_t(creall(c) / r, cimagl(c) / r);
#endif
	}
	else if (e2->type->isimaginary())
	{
#if __DMC__
	    //r = e2->toImaginary();
	    //c = e1->toComplex();
	    //printf("(%Lg + %Lgi) / %Lgi\n", creall(c), cimagl(c), r);

	    c = e1->toComplex() / (e2->toImaginary() * I);
#else
	    r = e2->toImaginary();
	    c = e1->toComplex();
	    c = complex_t(cimagl(c) / r, -creall(c) / r);
#endif
	}
	else
	{
	    c = e1->toComplex() / e2->toComplex();
	}

	if (type->isreal())
	    e = new RealExp(loc, creall(c), type);
	else if (type->isimaginary())
	    e = new RealExp(loc, cimagl(c), type);
	else if (type->iscomplex())
	    e = new ComplexExp(loc, c, type);
	else
	    assert(0);
    }
    else
    {	sinteger_t n1;
	sinteger_t n2;
	sinteger_t n;

	n1 = e1->toInteger();
	n2 = e2->toInteger();
	if (n2 == 0)
	{   error("divide by 0");
	    e2 = new IntegerExp(0, 1, e2->type);
	    n2 = 1;
	}
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
    if (type->isfloating())
    {
	complex_t c;

	if (e2->type->isreal())
	{   real_t r2 = e2->toReal();

#ifdef __DMC__
	    c = fmodl(e1->toReal(), r2) + fmodl(e1->toImaginary(), r2) * I;
#elif defined(IN_GCC)
	    c = complex_t(e1->toReal() % r2, e1->toImaginary() % r2);
#else
	    c = complex_t(fmodl(e1->toReal(), r2), fmodl(e1->toImaginary(), r2));
#endif
	}
	else if (e2->type->isimaginary())
	{   real_t i2 = e2->toImaginary();

#ifdef __DMC__
	    c = fmodl(e1->toReal(), i2) + fmodl(e1->toImaginary(), i2) * I;
#elif defined(IN_GCC)
	    c = complex_t(e1->toReal() % i2, e1->toImaginary() % i2);
#else
	    c = complex_t(fmodl(e1->toReal(), i2), fmodl(e1->toImaginary(), i2));
#endif
	}
	else
	    assert(0);

	if (type->isreal())
	    e = new RealExp(loc, creall(c), type);
	else if (type->isimaginary())
	    e = new RealExp(loc, cimagl(c), type);
	else if (type->iscomplex())
	    e = new ComplexExp(loc, c, type);
	else
	    assert(0);
    }
    else
    {	sinteger_t n1;
	sinteger_t n2;
	sinteger_t n;

	n1 = e1->toInteger();
	n2 = e2->toInteger();
	if (n2 == 0)
	{   error("divide by 0");
	    e2 = new IntegerExp(0, 1, e2->type);
	    n2 = 1;
	}
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
    switch (e1->type->toBasetype()->ty)
    {
	case Tint8:
		value = (d_int8)(value) >> count;
		break;

	case Tuns8:
		value = (d_uns8)(value) >> count;
		break;

	case Tint16:
		value = (d_int16)(value) >> count;
		break;

	case Tuns16:
		value = (d_uns16)(value) >> count;
		break;

	case Tint32:
		value = (d_int32)(value) >> count;
		break;

	case Tuns32:
		value = (d_uns32)(value) >> count;
		break;

	case Tint64:
		value = (d_int64)(value) >> count;
		break;

	case Tuns64:
		value = (d_uns64)(value) >> count;
		break;

	default:
		assert(0);
    }
    return new IntegerExp(loc, value, type);
}

Expression *UshrExp::constFold()
{
    //printf("UshrExp::constFold() %s\n", toChars());
    unsigned count;
    integer_t value;

    e1 = e1->constFold();
    e2 = e2->constFold();
    value = e1->toInteger();
    count = e2->toInteger();
    switch (e1->type->toBasetype()->ty)
    {
	case Tint8:
	case Tuns8:
		assert(0);		// no way to trigger this
		value = (value & 0xFF) >> count;
		break;

	case Tint16:
	case Tuns16:
		assert(0);		// no way to trigger this
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

	default:
		assert(0);
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
{   int n1, n2;

    e1 = e1->constFold();
    e2 = e2->constFold();

    n1 = e1->isBool(1);
    if (n1)
    {	n2 = e2->isBool(1);
	assert(n2 || e2->isBool(0));
    }
    else
	assert(e1->isBool(0));
    return new IntegerExp(loc, n1 && n2, type);
}

Expression *OrOrExp::constFold()
{   int n1, n2;

    e1 = e1->constFold();
    e2 = e2->constFold();

    n1 = e1->isBool(1);
    if (!n1)
    {
	assert(e1->isBool(0));
	n2 = e2->isBool(1);
	assert(n2 || e2->isBool(0));
    }
    return new IntegerExp(loc, n1 || n2, type);
}

Expression *CmpExp::constFold()
{   integer_t n;
    real_t r1;
    real_t r2;

    //printf("CmpExp::constFold() %s\n", toChars());
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
#if IN_GCC
	if (real_isnan(&r1) || real_isnan(&r2))	// if unordered
#else
	if (isnan(r1) || isnan(r2))	// if unordered
#endif
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
    {	sinteger_t n1;
	sinteger_t n2;

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

    //printf("IdentityExp::constFold() %s\n", toChars());
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
    n = econd->isBool(1);
    assert(n || econd->isBool(0));
    return n ? e1->constFold() : e2->constFold();
}

