
// Copyright (c) 1999-2006 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <assert.h>

#if _WIN32 || IN_GCC
#include "mem.h"
#else
#include "../root/mem.h"
#endif

#include "expression.h"
#include "mtype.h"
#include "utf.h"
#include "declaration.h"
#include "aggregate.h"

/* ==================== implicitCast ====================== */

/**************************************
 * Do an implicit cast.
 * Issue error if it can't be done.
 */

Expression *Expression::implicitCastTo(Type *t)
{
    //printf("implicitCastTo(%s) => %s\n", type->toChars(), t->toChars());
    if (implicitConvTo(t))
    {
	if (global.params.warnings &&
	    Type::impcnvWarn[type->toBasetype()->ty][t->toBasetype()->ty] &&
	    op != TOKint64)
	{
	    Expression *e = optimize(WANTflags | WANTvalue);

	    if (e->op == TOKint64)
		return e->implicitCastTo(t);

	    fprintf(stdmsg, "warning - ");
	    error("implicit conversion of expression (%s) of type %s to %s can cause loss of data",
		toChars(), type->toChars(), t->toChars());
	}
	return castTo(t);
    }
#if 0
print();
type->print();
printf("to:\n");
t->print();
printf("%p %p type: %s to: %s\n", type->deco, t->deco, type->deco, t->deco);
//printf("%p %p %p\n", type->next->arrayOf(), type, t);
fflush(stdout);
#endif
//*(char*)0=0;
    if (!t->deco)
    {	/* Can happen with:
	 *    enum E { One }
	 *    class A
	 *    { static void fork(EDG dg) { dg(E.One); }
	 *	alias void delegate(E) EDG;
	 *    }
	 * Should eventually make it work.
	 */
	error("forward reference to type %s", t->toChars());
    }
    else
	error("cannot implicitly convert expression (%s) of type %s to %s",
	    toChars(), type->toChars(), t->toChars());
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
    {	error("%s is not an expression", toChars());
	type = Type::terror;
    }
    if (t->ty == Tbit && isBit())
	return MATCHconvert;
    Expression *e = optimize(WANTvalue | WANTflags);
    if (e != this)
    {	//printf("optimzed to %s\n", e->toChars());
	return e->implicitConvTo(t);
    }
    return type->implicitConvTo(t);
}


int IntegerExp::implicitConvTo(Type *t)
{
#if 0
    printf("IntegerExp::implicitConvTo(this=%s, type=%s, t=%s)\n",
	toChars(), type->toChars(), t->toChars());
#endif
    if (type->equals(t))
	return MATCHexact;

    enum TY ty = type->toBasetype()->ty;
    switch (ty)
    {
	case Tbit:
	case Tbool:
	    value &= 1;
	    ty = Tint32;
	    break;

	case Tint8:
	    value = (signed char)value;
	    ty = Tint32;
	    break;

	case Tchar:
	case Tuns8:
	    value &= 0xFF;
	    ty = Tint32;
	    break;

	case Tint16:
	    value = (short)value;
	    ty = Tint32;
	    break;

	case Tuns16:
	case Twchar:
	    value &= 0xFFFF;
	    ty = Tint32;
	    break;

	case Tint32:
	    value = (int)value;
	    break;

	case Tuns32:
	case Tdchar:
	    value &= 0xFFFFFFFF;
	    ty = Tuns32;
	    break;

	default:
	    break;
    }

    // Only allow conversion if no change in value
    enum TY toty = t->toBasetype()->ty;
    switch (toty)
    {
	case Tbit:
	case Tbool:
	    if ((value & 1) != value)
		goto Lno;
	    goto Lyes;

	case Tint8:
	    if ((signed char)value != value)
		goto Lno;
	    goto Lyes;

	case Tchar:
	case Tuns8:
	    //printf("value = %llu %llu\n", (integer_t)(unsigned char)value, value);
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
	    if (ty == Tuns32)
	    {
	    }
	    else if ((int)value != value)
		goto Lno;
	    goto Lyes;

	case Tuns32:
	    if (ty == Tint32)
	    {
	    }
	    else if ((unsigned)value != value)
		goto Lno;
	    goto Lyes;

	case Tdchar:
	    if (value > 0x10FFFFUL)
		goto Lno;
	    goto Lyes;

	case Twchar:
	    if ((unsigned short)value != value)
		goto Lno;
	    goto Lyes;

	case Tfloat32:
	{
	    volatile float f;
	    if (type->isunsigned())
	    {
		f = (float)value;
		if (f != value)
		    goto Lno;
	    }
	    else
	    {
		f = (float)(long long)value;
		if (f != (long long)value)
		    goto Lno;
	    }
	    goto Lyes;
	}

	case Tfloat64:
	{
	    volatile double f;
	    if (type->isunsigned())
	    {
		f = (double)value;
		if (f != value)
		    goto Lno;
	    }
	    else
	    {
		f = (double)(long long)value;
		if (f != (long long)value)
		    goto Lno;
	    }
	    goto Lyes;
	}

	case Tfloat80:
	{
	    volatile long double f;
	    if (type->isunsigned())
	    {
		f = (long double)value;
		if (f != value)
		    goto Lno;
	    }
	    else
	    {
		f = (long double)(long long)value;
		if (f != (long long)value)
		    goto Lno;
	    }
	    goto Lyes;
	}
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
	    t->ty == Taarray  || t->ty == Tclass ||
	    t->ty == Tdelegate)
	    return 1;
    }
    return type->implicitConvTo(t);
}

int StringExp::implicitConvTo(Type *t)
{   MATCH m;

    //printf("StringExp::implicitConvTo(t = %s), '%s' committed = %d\n", t->toChars(), toChars(), committed);
    if (!committed)
    {
    if (!committed && t->ty == Tpointer && t->next->ty == Tvoid)
    {
	return MATCHnomatch;
    }
    if (type->ty == Tsarray || type->ty == Tarray || type->ty == Tpointer)
    {
	if (type->next->ty == Tchar)
	{
	    switch (t->ty)
	    {
		case Tsarray:
		    if (type->ty == Tsarray &&
			((TypeSArray *)type)->dim->toInteger() !=
			((TypeSArray *)t)->dim->toInteger())
			return MATCHnomatch;
		case Tarray:
		case Tpointer:
		    if (t->next->ty == Tchar)
			return MATCHexact;
		    else if (t->next->ty == Twchar)
			return MATCHexact;
		    else if (t->next->ty == Tdchar)
			return MATCHexact;
		    break;
	    }
	}
    }
    }
    m = (MATCH)type->implicitConvTo(t);
    if (m)
    {
	return m;
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
	    f = ve->var->isFuncDeclaration();
	    if (f && f->overloadExactMatch(t->next))
		result = MATCHexact;
	}
    }
    //printf("\tresult = %d\n", result);
    return result;
}

int SymOffExp::implicitConvTo(Type *t)
{
#if 0
    printf("SymOffExp::implicitConvTo(this=%s, type=%s, t=%s)\n",
	toChars(), type->toChars(), t->toChars());
#endif
    int result;

    result = type->implicitConvTo(t);
    //printf("\tresult = %d\n", result);

    if (result == MATCHnomatch)
    {
	// Look for pointers to functions where the functions are overloaded.
	FuncDeclaration *f;

	t = t->toBasetype();
	if (type->ty == Tpointer && type->next->ty == Tfunction &&
	    t->ty == Tpointer && t->next->ty == Tfunction)
	{
	    f = var->isFuncDeclaration();
	    if (f && f->overloadExactMatch(t->next))
		result = MATCHexact;
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
	{
	    if (func && func->overloadExactMatch(t->next))
		result = 2;
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

#if 0
    printf("Expression::castTo(this=%s, type=%s, t=%s)\n",
	toChars(), type->toChars(), t->toChars());
#endif
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
	{
	    e = new CastExp(loc, e, tb);
	}
    }
    e->type = t;
    //printf("Returning: %s\n", e->toChars());
    return e;
}


Expression *RealExp::castTo(Type *t)
{
    if (type->isreal() && t->isreal())
	type = t;
    else if (type->isimaginary() && t->isimaginary())
	type = t;
    else
	return Expression::castTo(t);
    return this;
}


Expression *ComplexExp::castTo(Type *t)
{
    if (type->iscomplex() && t->iscomplex())
	type = t;
    else
	return Expression::castTo(t);
    return this;
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
	    (tb->ty == Tpointer || tb->ty == Tarray || tb->ty == Taarray ||
	     tb->ty == Tdelegate))
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

    //printf("StringExp::castTo(t = %s), '%s' committed = %d\n", t->toChars(), toChars(), committed);

    if (!committed && t->ty == Tpointer && t->next->ty == Tvoid)
    {
	error("cannot convert string literal to void*");
    }

    se = this;
    unique = 0;
    if (!committed)
    {
	// Copy when committing the type
	void *s;

	s = (unsigned char *)mem.malloc((len + 1) * sz);
	memcpy(s, string, (len + 1) * sz);
	se = new StringExp(loc, s, len);
	se->type = type;
	se->sz = sz;
	se->committed = 0;
	unique = 1;		// this is the only instance
    }
    tb = t->toBasetype();
    se->type = type->toBasetype();
    if (tb == se->type)
    {	se->type = t;
	se->committed = 1;
	return se;
    }

    if (tb->ty != Tsarray && tb->ty != Tarray && tb->ty != Tpointer)
    {	se->committed = 1;
	goto Lcast;
    }
    if (se->type->ty != Tsarray && se->type->ty != Tarray && se->type->ty != Tpointer)
    {	se->committed = 1;
	goto Lcast;
    }

    if (se->committed == 1)
    {
	if (se->type->next->size() == tb->next->size())
	{   se->type = t;
	    return se;
	}
	goto Lcast;
    }

    se->committed = 1;

    int tfty;
    int ttty;
    char *p;
    unsigned u;
    unsigned c;
    unsigned newlen;

#define X(tf,tt)	((tf) * 256 + (tt))
    {
    OutBuffer buffer;
    newlen = 0;
    tfty = se->type->next->toBasetype()->ty;
    ttty = tb->next->toBasetype()->ty;
    switch (X(tfty, ttty))
    {
	case X(Tchar, Tchar):
	case X(Twchar,Twchar):
	case X(Tdchar,Tdchar):
	    break;

	case X(Tchar, Twchar):
	    for (u = 0; u < len;)
	    {
		p = utf_decodeChar((unsigned char *)se->string, len, &u, &c);
		if (p)
		    error(p);
		else
		    buffer.writeUTF16(c);
	    }
	    newlen = buffer.offset / 2;
	    buffer.writeUTF16(0);
	    goto L1;

	case X(Tchar, Tdchar):
	    for (u = 0; u < len;)
	    {
		p = utf_decodeChar((unsigned char *)se->string, len, &u, &c);
		if (p)
		    error(p);
		buffer.write4(c);
		newlen++;
	    }
	    buffer.write4(0);
	    goto L1;

	case X(Twchar,Tchar):
	    for (u = 0; u < len;)
	    {
		p = utf_decodeWchar((unsigned short *)se->string, len, &u, &c);
		if (p)
		    error(p);
		else
		    buffer.writeUTF8(c);
	    }
	    newlen = buffer.offset;
	    buffer.writeUTF8(0);
	    goto L1;

	case X(Twchar,Tdchar):
	    for (u = 0; u < len;)
	    {
		p = utf_decodeWchar((unsigned short *)se->string, len, &u, &c);
		if (p)
		    error(p);
		buffer.write4(c);
		newlen++;
	    }
	    buffer.write4(0);
	    goto L1;

	case X(Tdchar,Tchar):
	    for (u = 0; u < len; u++)
	    {
		c = ((unsigned *)se->string)[u];
		if (!utf_isValidDchar(c))
		    error("invalid UCS-32 char \\U%08x", c);
		else
		    buffer.writeUTF8(c);
		newlen++;
	    }
	    newlen = buffer.offset;
	    buffer.writeUTF8(0);
	    goto L1;

	case X(Tdchar,Twchar):
	    for (u = 0; u < len; u++)
	    {
		c = ((unsigned *)se->string)[u];
		if (!utf_isValidDchar(c))
		    error("invalid UCS-32 char \\U%08x", c);
		else
		    buffer.writeUTF16(c);
		newlen++;
	    }
	    newlen = buffer.offset / 2;
	    buffer.writeUTF16(0);
	    goto L1;

	L1:
	    if (!unique)
		se = new StringExp(loc, NULL, 0);
	    se->string = buffer.extractData();
	    se->len = newlen;
	    se->sz = tb->next->size();
	    break;

	default:
	    if (se->type->next->size() == tb->next->size())
	    {	se->type = t;
		return se;
	    }
	    goto Lcast;
    }
    }
#undef X

    // See if need to truncate or extend the literal
    if (tb->ty == Tsarray)
    {
	int dim2 = ((TypeSArray *)tb)->dim->toInteger();

	//printf("dim from = %d, to = %d\n", se->len, dim2);

	// Changing dimensions
	if (dim2 != se->len)
	{
	    unsigned newsz = se->sz;

	    if (unique && dim2 < se->len)
	    {   se->len = dim2;
		// Add terminating 0
		memset((unsigned char *)se->string + dim2 * newsz, 0, newsz);
	    }
	    else
	    {
		// Copy when changing the string literal
		void *s;
		int d;

		d = (dim2 < se->len) ? dim2 : se->len;
		s = (unsigned char *)mem.malloc((dim2 + 1) * newsz);
		memcpy(s, se->string, d * newsz);
		// Extend with 0, add terminating 0
		memset((char *)s + d * newsz, 0, (dim2 + 1 - d) * newsz);
		se = new StringExp(loc, s, dim2);
		se->committed = 1;	// it now has a firm type
		se->sz = newsz;
	    }
	}
    }
    se->type = t;
    return se;

Lcast:
    Expression *e = new CastExp(loc, se, t);
    e->type = t;
    return e;
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
	    f = ve->var->isFuncDeclaration();
	    if (f)
	    {
		f = f->overloadExactMatch(tb->next);
		if (f)
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

Expression *SymOffExp::castTo(Type *t)
{
    Type *tb;

#if 0
    printf("SymOffExp::castTo(this=%s, type=%s, t=%s)\n",
	toChars(), type->toChars(), t->toChars());
#endif
    Expression *e = this;

    tb = t->toBasetype();
    type = type->toBasetype();
    if (tb != type)
    {
	// Look for pointers to functions where the functions are overloaded.
	FuncDeclaration *f;

	if (type->ty == Tpointer && type->next->ty == Tfunction &&
	    tb->ty == Tpointer && tb->next->ty == Tfunction)
	{
	    f = var->isFuncDeclaration();
	    if (f)
	    {
		f = f->overloadExactMatch(tb->next);
		if (f)
		{
		    e = new SymOffExp(loc, f, 0);
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
    static char msg[] = "cannot form delegate due to covariant return type";

    tb = t->toBasetype();
    type = type->toBasetype();
    if (tb != type)
    {
	// Look for delegates to functions where the functions are overloaded.
	FuncDeclaration *f;

	if (type->ty == Tdelegate && type->next->ty == Tfunction &&
	    tb->ty == Tdelegate && tb->next->ty == Tfunction)
	{
	    if (func)
	    {
		f = func->overloadExactMatch(tb->next);
		if (f)
		{   int offset;
		    if (f->tintro && f->tintro->next->isBaseOf(f->type->next, &offset) && offset)
			error(msg);
		    e = new DelegateExp(loc, e1, f);
		    e->type = t;
		    return e;
		}
		if (func->tintro)
		    error(msg);
	    }
	}
	e = Expression::castTo(t);
    }
    else
    {	int offset;

	if (func->tintro && func->tintro->next->isBaseOf(func->type->next, &offset) && offset)
	    error(msg);
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
{   d_uns64 stride;
    Type *t1b = e1->type->toBasetype();
    Type *t2b = e2->type->toBasetype();

    if (t1b->ty == Tpointer && t2b->isintegral())
    {   // Need to adjust operator by the stride
	// Replace (ptr + int) with (ptr + (int * stride))
	Type *t = Type::tptrdiff_t;

	stride = t1b->next->size();
	if (!t->equals(t2b))
	    e2 = e2->castTo(t);
	if (t1b->next->isbit())
	    // BUG: should add runtime check for misaligned offsets
	    // This perhaps should be done by rewriting as &p[i]
	    // and letting back end do it.
	    e2 = new UshrExp(loc, e2, new IntegerExp(0, 3, t));
	else
	    e2 = new MulExp(loc, e2, new IntegerExp(0, stride, t));
	e2->type = t;
	type = e1->type;
    }
    else if (t2b->ty && t1b->isintegral())
    {   // Need to adjust operator by the stride
	// Replace (int + ptr) with (ptr + (int * stride))
	Type *t = Type::tptrdiff_t;
	Expression *e;

	stride = t2b->next->size();
	if (!t->equals(t1b))
	    e = e1->castTo(t);
	else
	    e = e1;
	if (t2b->next->isbit())
	    // BUG: should add runtime check for misaligned offsets
	    e = new UshrExp(loc, e, new IntegerExp(0, 3, t));
	else
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
#if 0
	if (type != Type::basic[ty])
	{   t = type;
	    type = Type::basic[ty];
	    return castTo(t);
	}
#endif
	//printf("after typeCombine():\n");
	//dump(0);
	//printf("ty = %d, ty1 = %d, ty2 = %d\n", ty, ty1, ty2);
	return this;
    }

    t = t1;
    if (t1 == t2)
    {
	if ((t1->ty == Tstruct || t1->ty == Tclass) &&
	    (op == TOKmin || op == TOKadd))
	    goto Lincompatible;
    }
    else if (t1->isintegral() && t2->isintegral())
    {
	//printf("t1 = %s, t2 = %s\n", t1->toChars(), t2->toChars());
	int sz1 = t1->size();
	int sz2 = t2->size();
	int sign1 = t1->isunsigned() == 0;
	int sign2 = t2->isunsigned() == 0;

	if (sign1 == sign2)
	{
	    if (sz1 < sz2)
		goto Lt2;
	    else
		goto Lt1;
	}
	if (!sign1)
	{
	    if (sz1 >= sz2)
		goto Lt1;
	    else
		goto Lt2;
	}
	else
	{
	    if (sz2 >= sz1)
		goto Lt2;
	    else
		goto Lt1;
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
    else if ((t1->ty == Tsarray || t1->ty == Tarray) &&
	     e2->op == TOKnull && t2->ty == Tpointer && t2->next->ty == Tvoid)
    {
	goto Lx1;
    }
    else if ((t2->ty == Tsarray || t2->ty == Tarray) &&
	     e1->op == TOKnull && t1->ty == Tpointer && t1->next->ty == Tvoid)
    {
	goto Lx2;
    }
    else if ((t1->ty == Tsarray || t1->ty == Tarray) && t1->implicitConvTo(t2))
    {
	goto Lt2;
    }
    else if ((t2->ty == Tsarray || t2->ty == Tarray) && t2->implicitConvTo(t1))
    {
	goto Lt1;
    }
    else if (t1->ty == Tclass || t2->ty == Tclass)
    {	int i1;
	int i2;

	i1 = e2->implicitConvTo(t1);
	i2 = e1->implicitConvTo(t2);

	if (i1 && i2)
	{
	    // We have the case of class vs. void*, so pick class
	    if (t1->ty == Tpointer)
		i1 = 0;
	    else if (t2->ty == Tpointer)
		i2 = 0;
	}

	if (i2)
	{
	    goto Lt2;
	}
	else if (i1)
	{
	    goto Lt1;
	}
	else
	    goto Lincompatible;
    }
    else if ((e1->op == TOKstring || e1->op == TOKnull) && e1->implicitConvTo(t2))
    {
	goto Lt2;
    }
//else if (e2->op == TOKstring) { printf("test2\n"); }
    else if ((e2->op == TOKstring || e2->op == TOKnull) && e2->implicitConvTo(t1))
    {
	goto Lt1;
    }
    else if (t1->ty == Tsarray && t2->ty == Tsarray &&
	     e2->implicitConvTo(t1->next->arrayOf()))
    {
     Lx1:
	t = t1->next->arrayOf();
	e1 = e1->castTo(t);
	e2 = e2->castTo(t);
    }
    else if (t1->ty == Tsarray && t2->ty == Tsarray &&
	     e1->implicitConvTo(t2->next->arrayOf()))
    {
     Lx2:
	t = t2->next->arrayOf();
	e1 = e1->castTo(t);
	e2 = e2->castTo(t);
    }
    else
    {
     Lincompatible:
	incompatibleTypes();
    }
Lret:
    if (!type)
	type = t;
    //dump(0);
    return this;


Lt1:
    e2 = e2->castTo(t1);
    t = t1;
    goto Lret;

Lt2:
    e1 = e1->castTo(t2);
    t = t2;
    goto Lret;
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
	case Tbool:
	case Tchar:
	case Twchar:
	    e = e->castTo(Type::tint32);
	    break;

	case Tdchar:
	    e = e->castTo(Type::tuns32);
	    break;
    }
    return e;
}

