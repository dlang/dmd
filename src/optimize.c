
// Copyright (c) 1999-2006 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <ctype.h>
#include <assert.h>

#include "mem.h"
#include "root.h"

#include "lexer.h"
#include "mtype.h"
#include "expression.h"
#include "declaration.h"
#include "aggregate.h"


Expression *Expression::optimize(int result)
{
    //printf("Expression::optimize(result = %d) %s\n", result, toChars());
    return this;
}

Expression *UnaExp::optimize(int result)
{   Expression *e;

    e1 = e1->optimize(result);
    if (e1->isConst() == 1)
	e = constFold();
    else
	e = this;
    return e;
}

Expression *AddrExp::optimize(int result)
{   Expression *e;

    //printf("AddrExp::optimize(result = %d) %s\n", result, toChars());
    e1 = e1->optimize(result);
    // Convert &*ex to ex
    if (e1->op == TOKstar)
    {	Expression *ex;

	ex = ((PtrExp *)e1)->e1;
	if (type->equals(ex->type))
	    e = ex;
	else
	{
	    e = ex->copy();
	    e->type = type;
	}
	return e;
    }
    if (e1->op == TOKvar)
    {	VarExp *ve = (VarExp *)e1;
	if (!ve->var->isOut() && !ve->var->isImportedSymbol())
	{
	    e = new SymOffExp(loc, ve->var, 0);
	    e->type = type;
	    return e;
	}
    }
    if (e1->op == TOKindex)
    {	// Convert &array[n] to &array+n
	IndexExp *ae = (IndexExp *)e1;

	if (ae->e2->op == TOKint64 && ae->e1->op == TOKvar)
	{
	    integer_t index = ae->e2->toInteger();
	    VarExp *ve = (VarExp *)ae->e1;
	    if (ve->type->ty == Tsarray && ve->type->next->ty != Tbit
		&& !ve->var->isImportedSymbol())
	    {
		TypeSArray *ts = (TypeSArray *)ve->type;
		integer_t dim = ts->dim->toInteger();
		if (index < 0 || index >= dim)
		    error("array index %lld is out of bounds [0..%lld]", index, dim);
		e = new SymOffExp(loc, ve->var, index * ts->next->size());
		e->type = type;
		return e;
	    }
	}
    }
    return this;
}

Expression *PtrExp::optimize(int result)
{
    e1 = e1->optimize(result);
    // Convert *&ex to ex
    if (e1->op == TOKaddress)
    {	Expression *e;
	Expression *ex;

	ex = ((AddrExp *)e1)->e1;
	if (type->equals(ex->type))
	    e = ex;
	else
	{
	    e = ex->copy();
	    e->type = type;
	}
	return e;
    }
    return this;
}

Expression *CastExp::optimize(int result)
{
    //printf("CastExp::optimize(result = %d) %s\n", result, toChars());
    if (e1->op == TOKstring &&
	(type->ty == Tpointer || type->ty == Tarray) &&
	type->next->equals(e1->type->next)
       )
    {
	e1->type = type;
	return e1;
    }
    if (e1->op == TOKnull &&
	(type->ty == Tpointer || type->ty == Tclass))
    {
	e1->type = type;
	return e1;
    }

    if (result == WANTflags && type->ty == Tclass && e1->type->ty == Tclass)
    {
	// See if we can remove an unnecessary cast
	ClassDeclaration *cdfrom;
	ClassDeclaration *cdto;
	int offset;

	cdfrom = e1->type->isClassHandle();
	cdto   = type->isClassHandle();
	if (cdto->isBaseOf(cdfrom, &offset) && offset == 0)
	{
	    e1->type = type;
	    return e1;
	}
    }

    Expression *e;

    e1 = e1->optimize(result);
    if (e1->isConst())
	e = constFold();
    else
	e = this;
    return e;
}

Expression *BinExp::optimize(int result)
{   Expression *e;

    //printf("BinExp::optimize(result = %d) %s\n", result, toChars());
    e1 = e1->optimize(result);
    e2 = e2->optimize(result);
    if (e1->isConst() == 1 && e2->isConst() == 1)
	e = constFold();
    else
	e = this;
    return e;
}

Expression *AddExp::optimize(int result)
{   Expression *e;

    e1 = e1->optimize(result);
    e2 = e2->optimize(result);
    if (e1->isConst() && e2->isConst())
	e = constFold();
    else
	e = this;
    return e;
}

Expression *MinExp::optimize(int result)
{   Expression *e;

    e1 = e1->optimize(result);
    e2 = e2->optimize(result);
    if (e1->isConst() && e2->isConst())
	e = constFold();
    else
	e = this;
    return e;
}

Expression *CommaExp::optimize(int result)
{   Expression *e;

    //printf("CommaExp::optimize(result = %d) %s\n", result, toChars());
    e1 = e1->optimize(0);
    e2 = e2->optimize(result);
    if (!e1 || e1->op == TOKint64 || e1->op == TOKfloat64)
    {
	e = e2;
	if (e)
	    e->type = type;
    }
    else
	e = this;
    return e;
}

Expression *ArrayLengthExp::optimize(int result)
{   Expression *e;

    //printf("ArrayLengthExp::optimize(result = %d) %s\n", result, toChars());
    e1 = e1->optimize(WANTvalue);
    e = this;
    if (e1->op == TOKstring)
    {	StringExp *es1 = (StringExp *)e1;

	e = new IntegerExp(loc, es1->len, type);
    }
    return e;
}

Expression *EqualExp::optimize(int result)
{   Expression *e;

    //printf("EqualExp::optimize(result = %d) %s\n", result, toChars());
    e1 = e1->optimize(WANTvalue);
    e2 = e2->optimize(WANTvalue);
    e = this;
    if (e1->op == TOKstring && e2->op == TOKstring)
    {	StringExp *es1 = (StringExp *)e1;
	StringExp *es2 = (StringExp *)e2;
	int value;

	assert(es1->sz == es2->sz);
	if (es1->len == es2->len &&
	    memcmp(es1->string, es2->string, es1->sz * es1->len) == 0)
	    value = 1;
	else
	    value = 0;
	if (op == TOKnotequal)
	    value ^= 1;
	e = new IntegerExp(loc, value, type);
    }
    else if (e1->isConst() == 1 && e2->isConst() == 1)
	e = constFold();
    return e;
}

Expression *IndexExp::optimize(int result)
{   Expression *e;

    //printf("IndexExp::optimize(result = %d) %s\n", result, toChars());
    e1 = e1->optimize(WANTvalue);
    e2 = e2->optimize(WANTvalue);
    e = this;
    if (e1->op == TOKstring && e2->op == TOKint64)
    {	StringExp *es1 = (StringExp *)e1;
	uinteger_t i = e2->toInteger();

	if (i >= es1->len)
	    error("string index %llu is out of bounds [0 .. %u]", i, es1->len);
	else
	{   integer_t value;

	    switch (es1->sz)
	    {
		case 1:
		    value = ((unsigned char *)es1->string)[i];
		    break;

		case 2:
		    value = ((unsigned short *)es1->string)[i];
		    break;

		case 4:
		    value = ((unsigned int *)es1->string)[i];
		    break;

		default:
		    assert(0);
		    break;
	    }
	    e = new IntegerExp(loc, value, type);
	}
    }
    else if (e1->type->toBasetype()->ty == Tsarray && e2->op == TOKint64)
    {	TypeSArray *tsa = (TypeSArray *)e1->type->toBasetype();
	uinteger_t length = tsa->dim->toInteger();
	uinteger_t i = e2->toInteger();

	if (i >= length)
	    error("array index %llu is out of bounds [0 .. %llu]", i, length);
    }
    return e;
}

Expression *SliceExp::optimize(int result)
{   Expression *e;

    //printf("SliceExp::optimize(result = %d) %s\n", result, toChars());
    e = this;
    e1 = e1->optimize(WANTvalue);
    if (!lwr)
	return e;
    lwr = lwr->optimize(WANTvalue);
    upr = upr->optimize(WANTvalue);
    if (e1->op == TOKstring && lwr->op == TOKint64 && upr->op == TOKint64)
    {	StringExp *es1 = (StringExp *)e1;
	uinteger_t ilwr = lwr->toInteger();
	uinteger_t iupr = upr->toInteger();

	if (iupr > es1->len || ilwr > iupr)
	    error("string slice [%llu .. %llu] is out of bounds", ilwr, iupr);
	else
	{   integer_t value;
	    void *s;
	    size_t len = iupr - ilwr;
	    int sz = es1->sz;
	    StringExp *es;

	    s = mem.malloc((len + 1) * sz);
	    memcpy((unsigned char *)s, (unsigned char *)es1->string + ilwr * sz, len * sz);
	    memset((unsigned char *)s + len * sz, 0, sz);

	    es = new StringExp(loc, s, len, es1->postfix);
	    es->sz = sz;
	    es->committed = 1;
	    es->type = type;
	    e = es;
	}
    }
    return e;
}

Expression *AndAndExp::optimize(int result)
{   Expression *e;

    //printf("AndAndExp::optimize(%d) %s\n", result, toChars());
    e1 = e1->optimize(WANTflags);
    e = this;
    if (e1->isBool(FALSE))
    {
	e = new CommaExp(loc, e1, new IntegerExp(loc, 0, type));
	e->type = type;
	e = e->optimize(result);
    }
    else
    {
	e2 = e2->optimize(WANTflags);
	if (e1->isConst())
	{
	    if (e2->isConst())
		e = constFold();
	    else if (e1->isBool(TRUE))
		e = new BoolExp(loc, e2, type);
	}
    }
    return e;
}

Expression *OrOrExp::optimize(int result)
{   Expression *e;

    e1 = e1->optimize(WANTflags);
    e = this;
    if (e1->isBool(TRUE))
    {	// Replace with (e1, 1)
	e = new CommaExp(loc, e1, new IntegerExp(loc, 1, type));
	e->type = type;
	e = e->optimize(result);
    }
    else
    {
	e2 = e2->optimize(WANTflags);
	if (e1->isConst())
	{
	    if (e2->isConst())
		e = constFold();
	    else if (e1->isBool(FALSE))
		e = new BoolExp(loc, e2, type);
	}
    }
    return e;
}

Expression *CatExp::optimize(int result)
{   Expression *e;

    //printf("CatExp::optimize(%d) %s\n", result, toChars());
    e1 = e1->optimize(result);
    e2 = e2->optimize(result);
    if (e1->op == TOKstring && e2->op == TOKstring)
    {
	// Concatenate the strings
	void *s;
	StringExp *es1 = (StringExp *)e1;
	StringExp *es2 = (StringExp *)e2;
	StringExp *es;
	Type *t;
	size_t len = es1->len + es2->len;
	int sz = es1->sz;

	assert(sz == es2->sz);
	s = mem.malloc((len + 1) * sz);
	memcpy(s, es1->string, es1->len * sz);
	memcpy((unsigned char *)s + es1->len * sz, es2->string, es2->len * sz);

	// Add terminating 0
	memset((unsigned char *)s + len * sz, 0, sz);

	es = new StringExp(loc, s, len);
	es->sz = sz;
	es->committed = es1->committed | es2->committed;
	if (es1->committed)
	    t = es1->type;
	else
	    t = es2->type;
	//es->type = new TypeSArray(t->next, new IntegerExp(0, len, Type::tindex));
	//es->type = es->type->semantic(loc, NULL);
	es->type = type;
	e = es;
    }
    else if (e1->op == TOKstring && e2->op == TOKint64)
    {
	// Concatenate the strings
	void *s;
	StringExp *es1 = (StringExp *)e1;
	StringExp *es;
	Type *t;
	size_t len = es1->len + 1;
	int sz = es1->sz;
	integer_t v = e2->toInteger();

	s = mem.malloc((len + 1) * sz);
	memcpy(s, es1->string, es1->len * sz);
	memcpy((unsigned char *)s + es1->len * sz, &v, sz);

	// Add terminating 0
	memset((unsigned char *)s + len * sz, 0, sz);

	es = new StringExp(loc, s, len);
	es->sz = sz;
	es->committed = es1->committed;
	t = es1->type;
	//es->type = new TypeSArray(t->next, new IntegerExp(0, len, Type::tindex));
	//es->type = es->type->semantic(loc, NULL);
	es->type = type;
	e = es;
    }
    else if (e1->op == TOKint64 && e2->op == TOKstring)
    {
	// Concatenate the strings
	void *s;
	StringExp *es2 = (StringExp *)e2;
	StringExp *es;
	Type *t;
	size_t len = 1 + es2->len;
	int sz = es2->sz;
	integer_t v = e1->toInteger();

	s = mem.malloc((len + 1) * sz);
	memcpy((unsigned char *)s, &v, sz);
	memcpy((unsigned char *)s + sz, es2->string, es2->len * sz);

	// Add terminating 0
	memset((unsigned char *)s + len * sz, 0, sz);

	es = new StringExp(loc, s, len);
	es->sz = sz;
	es->committed = es2->committed;
	t = es2->type;
	//es->type = new TypeSArray(t->next, new IntegerExp(0, len, Type::tindex));
	//es->type = es->type->semantic(loc, NULL);
	es->type = type;
	e = es;
    }
    else
	e = this;
    return e;
}


Expression *CondExp::optimize(int result)
{   Expression *e;

    econd = econd->optimize(WANTflags);
    if (econd->isBool(TRUE))
	e = e1->optimize(result);
    else if (econd->isBool(FALSE))
	e = e2->optimize(result);
    else
    {	e1 = e1->optimize(result);
	e2 = e2->optimize(result);
	e = this;
    }
    return e;
}


