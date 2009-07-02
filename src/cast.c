
// Copyright (c) 1999-2002 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include "mem.h"

#include "expression.h"
#include "mtype.h"

/* ==================== implicitCast ====================== */

/**************************************
 * Do an implicit cast.
 * Issue error if it can't be done.
 */

Expression *Expression::implicitCastTo(Type *t)
{
    //printf("implicitCastTo()\n");
    if (implicitConvTo(t))
	return castTo(t);
//type->print();
//type->next->print();
//t->print();
//t->next->print();

//*(char*)0=0;
    error("cannot implicitly convert %s to %s", type->toChars(), t->toChars());
    return castTo(t);
}

/*******************************************
 * Return !=0 if we can implicitly convert this to type t.
 * Don't do the actual cast.
 */

int Expression::implicitConvTo(Type *t)
{
#if 0
    printf("Expression::implicitConvTo(this=%s, type=%s, t=%s)\n",
	toChars(), type->toChars(), t->toChars());
#endif
    if (!type)
	error("%s is not an expression", toChars());
    if (t->ty == Tbit && isBit())
	return MATCHconvert;
    return type->implicitConvTo(t);
}

int IntegerExp::implicitConvTo(Type *t)
{
    if (type->equals(t))
	return MATCHexact;

    // Only allow conversion if no change in value
    switch(t->ty)
    {
	case Tbit:
	    if (value & ~1)
		goto Lno;
	    goto Lyes;

	case Tint8:
	    if ((signed char)value != value)
		goto Lno;
	    goto Lyes;

	case Tascii:
	case Tuns8:
	    if ((unsigned char)value != value)
		goto Lno;
	    goto Lyes;

	case Tint16:
	    if ((short)value != value)
		goto Lno;
	    goto Lyes;

	case Tuns16:
	    if ((unsigned short)value != value)
		goto Lno;
	    goto Lyes;

	case Tint32:
	    if ((int)value != value)
		goto Lno;
	    goto Lyes;

	case Tuns32:
	    if ((unsigned)value != value)
		goto Lno;
	    goto Lyes;

	case Twchar:
	    if ((wchar_t)value != value)
		goto Lno;
	    goto Lyes;

	case Tfloat32:
	case Tcomplex32:
	    volatile float f = (float)value;
	    if (f != value)
		goto Lno;
	    goto Lyes;

	case Tfloat64:
	case Tcomplex64:
	    volatile double d = (double)value;
	    if (d != value)
		goto Lno;
	    goto Lyes;

	case Tfloat80:
	case Tcomplex80:
	    volatile long double ld = (long double)value;
	    if (ld != value)
		goto Lno;
	    goto Lyes;
    }
    return Expression::implicitConvTo(t);

Lyes:
    return MATCHconvert;

Lno:
    return MATCHnomatch;
}

int NullExp::implicitConvTo(Type *t)
{
#if 0
    printf("NullExp::implicitConvTo(this=%s, type=%s, t=%s)\n",
	toChars(), type->toChars(), t->toChars());
#endif
    if (this->type->equals(t))
	return 2;
    // NULL implicitly converts to any pointer type or dynamic array
    if (type->ty == Tpointer && type->next->ty == Tvoid)
    {
	if (t->ty == Ttypedef)
	    t = ((TypeTypedef *)t)->sym->basetype;
	if (t->ty == Tpointer || t->ty == Tarray ||
	    t->ty == Taarray  || t->ty == Tclass)
	    return 1;
    }
    return type->implicitConvTo(t);
}

int StringExp::implicitConvTo(Type *t)
{   MATCH m;
    int u;

    //printf("StringExp::implicitConvTo()\n");
    if (!committed && t->ty == Tpointer && t->next->ty == Tvoid)
    {
	return MATCHnomatch;
    }
    m = (MATCH)type->implicitConvTo(t);
    if (m)
	return m;
    u = wcharIsAscii(string, len);
    if ((type->ty == Tsarray || type->ty == Tarray) && type->next->ty == Twchar)
    {
	switch (t->ty)
	{
	    case Tsarray:
	    case Tarray:
	    case Tpointer:
		if (t->next->ty == Tascii)
		{
		    if (u)
			return MATCHexact;
		}
		else if (t->next->ty == Twchar)
		    return MATCHexact;
		break;

	    case Tascii:
		if (len == 1 && u)
		    return MATCHexact;
		break;

	    case Twchar:
		if (len == 1)
		    return MATCHexact;
		break;

	    case Tint8:
	    case Tuns8:
		if (len == 1 && u)
		    return MATCHconvert;
		break;

	    case Tint16:
	    case Tuns16:
	    case Tint32:
	    case Tuns32:
		if (len == 1)
		    return MATCHconvert;
		break;
	}
    }

    return MATCHnomatch;
}

int AddrExp::implicitConvTo(Type *t)
{
#if 0
    printf("AddrExp::implicitConvTo(this=%s, type=%s, t=%s)\n",
	toChars(), type->toChars(), t->toChars());
#endif
    int result;

    result = type->implicitConvTo(t);
    //printf("\tresult = %d\n", result);

    if (result == MATCHnomatch)
    {
	// Look for pointers to functions where the functions are overloaded.
	VarExp *ve;
	FuncDeclaration *f;

	t = t->toBasetype();
	if (type->ty == Tpointer && type->next->ty == Tfunction &&
	    t->ty == Tpointer && t->next->ty == Tfunction &&
	    e1->op == TOKvar)
	{
	    ve = (VarExp *)e1;
	    f = dynamic_cast<FuncDeclaration *>(ve->var);
	    for (; f; f = f->overnext)
	    {
		if (t->next->equals(f->type))
		{
		    result = MATCHexact;
		    break;
		}
	    }
	}
    }
    //printf("\tresult = %d\n", result);
    return result;
}

int DelegateExp::implicitConvTo(Type *t)
{
#if 0
    printf("DelegateExp::implicitConvTo(this=%s, type=%s, t=%s)\n",
	toChars(), type->toChars(), t->toChars());
#endif
    int result;

    result = type->implicitConvTo(t);

    if (result == 0)
    {
	// Look for pointers to functions where the functions are overloaded.
	FuncDeclaration *f;

	t = t->toBasetype();
	if (type->ty == Tdelegate && type->next->ty == Tfunction &&
	    t->ty == Tdelegate && t->next->ty == Tfunction)
	{   FuncDeclaration *f;

	    for (f = func; f; f = f->overnext)
	    {
		if (t->next->equals(f->type))
		{
		    result = 2;
		    break;
		}
	    }
	}
    }
    return result;
}

int CondExp::implicitConvTo(Type *t)
{
    int m1;
    int m2;

    m1 = e1->implicitConvTo(t);
    m2 = e2->implicitConvTo(t);

    // Pick the worst match
    return (m1 < m2) ? m1 : m2;
}


/* ==================== castTo ====================== */

/**************************************
 * Do an explicit cast.
 */

Expression *Expression::castTo(Type *t)
{   Expression *e;
    Type *tb;

    e = this;
    tb = t->toBasetype();
    type = type->toBasetype();
    if (tb != type)
    {
	if (tb->ty == Tbit && isBit())
	    ;

	// Do (type *) cast of (type [dim])
	else if (tb->ty == Tpointer &&
	    type->ty == Tsarray
	   )
	{
	    //printf("Converting [dim] to *\n");

	    e = new AddrExp(loc, e);
	}
	else
	    e = new CastExp(loc, e, tb);
    }
    e->type = t;
    return e;
}

Expression *NullExp::castTo(Type *t)
{   Expression *e;
    Type *tb;

    //printf("NullExp::castTo(t = %p)\n", t);
    e = this;
    tb = t->toBasetype();
    type = type->toBasetype();
    if (tb != type)
    {
	// NULL implicitly converts to any pointer type or dynamic array
	if (type->ty == Tpointer && type->next->ty == Tvoid &&
	    (tb->ty == Tpointer || tb->ty == Tarray || tb->ty == Taarray))
	{
	}
	else
	{
	    e = new CastExp(loc, e, tb);
	}
    }
    e->type = t;
    return e;
}

Expression *StringExp::castTo(Type *t)
{
    StringExp *se;
    Type *tb;
    int unique;

    //printf("StringExp::castTo()\n");
    if (!committed && t->ty == Tpointer && t->next->ty == Tvoid)
    {
	error("cannot convert string literal to void*");
    }

    se = this;
    unique = 0;
    if (!committed)
    {
	// Copy when committing the type
	wchar_t *s;

	s = (wchar_t *)mem.malloc((len + 1) * sizeof(s[0]));
	memcpy(s, string, len * sizeof(s[0]));
	s[len] = 0;
	se = new StringExp(loc, s, len);
	se->type = type;
	se->committed = 1;	// it now has a firm type
	unique = 1;		// this is the only instance
    }
    tb = t->toBasetype();
    se->type = type->toBasetype();
    if (tb != se->type)
    {
	if (se->type->ty == Tsarray && tb->ty == Tsarray)
	{
	    int dim1 = ((TypeSArray *)se->type)->dim->toInteger();
	    int dim2 = ((TypeSArray *)tb)->dim->toInteger();

	    assert(dim1 == se->len);

	    //printf("dim from = %d, to = %d\n", dim1, dim2);

	    if (dim2 != se->len)
	    {
		if (unique && dim2 < se->len)
		{   se->len = dim2;
		    se->string[dim2] = 0;
		}
		else
		{
		    // Copy when changing the string literal
		    wchar_t *s;
		    int d;

		    d = (dim2 < se->len) ? dim2 : se->len;
		    s = (wchar_t *)mem.malloc((dim2 + 1) * sizeof(s[0]));
		    memcpy(s, se->string, d * sizeof(s[0]));
		    memset(s + d, 0, dim2 + 1 - d);
		    se = new StringExp(loc, s, dim2);
		    se->committed = 1;	// it now has a firm type
		    se->type = type->toBasetype();
		}
	    }
	}
	if (se->type->ty == Tarray && se->type->next->ty == Twchar)
	{
	    switch (tb->ty)
	    {
		case Tsarray:
		    if (se->len != ((TypeSArray *)tb)->dim->toInteger())
			break;
		case Tarray:
		case Tpointer:
		    if (tb->next->ty == Tchar || tb->next->ty == Twchar)
		    {
			se->type = t;
			return se;
		    }
		    break;
	    }
	}
	if (se->type->ty == Tsarray && se->type->next->ty == Twchar)
	{
	    switch (tb->ty)
	    {
		case Tsarray:
		case Tarray:
		case Tpointer:
		    if (tb->next->ty == Tchar || tb->next->ty == Twchar)
		    {
			se->type = t;
			return se;
		    }
		    break;

		case Tascii:
		case Twchar:
		case Tint8:
		case Tuns8:
		case Tint16:
		case Tuns16:
		case Tint32:
		case Tuns32:
		case Tint64:
		case Tuns64:
		    return new IntegerExp(loc, se->string[0], t);
	    }
	}
	Expression *e = new CastExp(loc, se, t);
	e->type = t;
	return e;
    }
    se->type = t;
    return se;
}

Expression *AddrExp::castTo(Type *t)
{
    Type *tb;

#if 0
    printf("AddrExp::castTo(this=%s, type=%s, t=%s)\n",
	toChars(), type->toChars(), t->toChars());
#endif
    Expression *e = this;

    tb = t->toBasetype();
    type = type->toBasetype();
    if (tb != type)
    {
	// Look for pointers to functions where the functions are overloaded.
	VarExp *ve;
	FuncDeclaration *f;

	if (type->ty == Tpointer && type->next->ty == Tfunction &&
	    tb->ty == Tpointer && tb->next->ty == Tfunction &&
	    e1->op == TOKvar)
	{
	    ve = (VarExp *)e1;
	    f = dynamic_cast<FuncDeclaration *>(ve->var);
	    for (; f; f = f->overnext)
	    {
		if (tb->next->equals(f->type))
		{
		    e = new VarExp(loc, f);
		    e->type = f->type;
		    e = new AddrExp(loc, e);
		    e->type = t;
		    return e;
		}
	    }
	}
	e = Expression::castTo(t);
    }

    e->type = t;
    return e;
}

Expression *DelegateExp::castTo(Type *t)
{
    Type *tb;
#if 0
    printf("DelegateExp::castTo(this=%s, type=%s, t=%s)\n",
	toChars(), type->toChars(), t->toChars());
#endif
    Expression *e = this;

    tb = t->toBasetype();
    type = type->toBasetype();
    if (tb != type)
    {
	// Look for delegates to functions where the functions are overloaded.
	FuncDeclaration *f;

	if (type->ty == Tdelegate && type->next->ty == Tfunction &&
	    tb->ty == Tdelegate && tb->next->ty == Tfunction)
	{
	    for (f = func; f; f = f->overnext)
	    {
		if (tb->next->equals(f->type))
		{
		    e = new DelegateExp(loc, e1, f);
		    e->type = t;
		    return e;
		}
	    }
	}
	e = Expression::castTo(t);
    }
    e->type = t;
    return e;
}

Expression *CondExp::castTo(Type *t)
{
    Expression *e = this;

    if (type != t)
    {
	if (1 || e1->op == TOKstring || e2->op == TOKstring)
	{   e = new CondExp(loc, econd, e1->castTo(t), e2->castTo(t));
	    e->type = t;
	}
	else
	    e = Expression::castTo(t);
    }
    return e;
}

/* ==================== ====================== */

/****************************************
 * Scale addition/subtraction to/from pointer.
 */

Expression *BinExp::scaleFactor()
{   unsigned stride;
    Type *t1b = e1->type->toBasetype();
    Type *t2b = e2->type->toBasetype();

    if (t1b->ty == Tpointer && t2b->isintegral())
    {   // Need to adjust operator by the stride
	// Replace (ptr + int) with (ptr + (int * stride))
	Type *t = Type::tint32;

	stride = t1b->next->size();
	if (!t->equals(t2b))
	    e2 = e2->castTo(t);
	e2 = new MulExp(loc, e2, new IntegerExp(0, stride, t));
	e2->type = t;
	type = e1->type;
    }
    else if (t2b->ty && t1b->isintegral())
    {   // Need to adjust operator by the stride
	// Replace (int + ptr) with (ptr + (int * stride))
	Type *t = Type::tint32;
	Expression *e;

	stride = t2b->next->size();
	if (!t->equals(t1b))
	    e = e1->castTo(t);
	else
	    e = e1;
	e = new MulExp(loc, e, new IntegerExp(0, stride, t));
	e->type = t;
	type = e2->type;
	e1 = e2;
	e2 = e;
    }
    return this;
}

/************************************
 * Bring leaves to common type.
 */

Expression *BinExp::typeCombine()
{
    Type *t1;
    Type *t2;
    Type *t;
    TY ty;

    //printf("BinExp::typeCombine()\n");
    //dump(0);

    e1 = e1->integralPromotions();
    e2 = e2->integralPromotions();

    // BUG: do toBasetype()
    t1 = e1->type;
    t2 = e2->type;
    assert(t1);
#ifdef DEBUG
    if (!t2) printf("\te2 = '%s'\n", e2->toChars());
#endif
    assert(t2);

    ty = (TY)Type::impcnvResult[t1->ty][t2->ty];
    if (ty != Terror)
    {	TY ty1;
	TY ty2;

	if (!type)
	    type = Type::basic[ty];
	ty1 = (TY)Type::impcnvType1[t1->ty][t2->ty];
	ty2 = (TY)Type::impcnvType2[t1->ty][t2->ty];
	t1 = Type::basic[ty1];
	t2 = Type::basic[ty2];
	e1 = e1->castTo(t1);
	e2 = e2->castTo(t2);
	//printf("after typeCombine():\n");
	//dump(0);
	//printf("ty = %d, ty1 = %d, ty2 = %d\n", ty, ty1, ty2);
	return this;
    }

    t = t1;
    if (t1 == t2)
	;
    else if (t1->isintegral() && t2->isintegral())
    {
	if (t1->ty > t2->ty)
	{
	    if (t1->ty >= Tuns32)
		e2 = e2->castTo(t1);
	}
	else
	{
	    if (t2->ty >= Tuns32)
	    {	e1 = e1->castTo(t2);
		t = t2;
	    }
	}
    }
    else if (t1->ty == Tpointer && t2->ty == Tpointer)
    {
	// Bring pointers to compatible type
	Type *t1n = t1->next;
	Type *t2n = t2->next;

//t1->print();
//t2->print();
//if (t1n == t2n) *(char *)0 = 0;
	assert(t1n != t2n);
	if (t1n->ty == Tvoid)		// pointers to void are always compatible
	    t = t2;
	else if (t2n->ty == Tvoid)
	    ;
	else if (t1n->ty == Tclass && t2n->ty == Tclass)
	{   ClassDeclaration *cd1 = t1n->isClassHandle();
	    ClassDeclaration *cd2 = t2n->isClassHandle();
	    int offset;

	    if (cd1->isBaseOf(cd2, &offset))
	    {
		if (offset)
		    e2 = e2->castTo(t);
	    }
	    else if (cd2->isBaseOf(cd1, &offset))
	    {
		t = t2;
		if (offset)
		    e1 = e1->castTo(t);
	    }
	    else
		goto Lincompatible;
	}
	else
	    goto Lincompatible;
    }
    else if ((t1->ty == Tsarray || t1->ty == Tarray) && t1->implicitConvTo(t2))
    {
	e1 = e1->castTo(t2);
	t = t2;
    }
    else if ((t2->ty == Tsarray || t2->ty == Tarray) && t2->implicitConvTo(t1))
    {
	e2 = e2->castTo(t1);
	t = t1;
    }
    else if (t1->ty == Tclass && t1->implicitConvTo(t2))
    {
	e1 = e1->castTo(t2);
	t = t2;
    }
    else if (t2->ty == Tclass && t2->implicitConvTo(t1))
    {
	e2 = e2->castTo(t1);
	t = t1;
    }
    else if ((e1->op == TOKstring || e1->op == TOKnull) && e1->implicitConvTo(t2))
    {
	e1 = e1->castTo(t2);
	t = t2;
    }
    else if ((e2->op == TOKstring || e2->op == TOKnull) && e2->implicitConvTo(t1))
    {
	e2 = e2->castTo(t1);
	t = t1;
    }
    else
    {
     Lincompatible:
	error("incompatible types for ((%s) %s (%s)): '%s' and '%s'",
	 e1->toChars(), Token::toChars(op), e2->toChars(),
	 t1->toChars(), t2->toChars());
    }
    if (!type)
	type = t;
    return this;
}

/***********************************
 * Do integral promotions (convertchk).
 * Don't convert <array of> to <pointer to>
 */

Expression *Expression::integralPromotions()
{   Expression *e;

    e = this;
    switch (type->toBasetype()->ty)
    {
	case Tvoid:
	    error("void has no value");
	    break;

	case Tint8:
	case Tuns8:
	case Tint16:
	case Tuns16:
	case Tbit:
	case Tascii:
	case Twchar:
	    e = e->castTo(Type::tint32);
	    break;
    }
    return e;
}

