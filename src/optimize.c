
// Copyright (c) 1999-2005 by Digital Mars
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
    {	// Convert &array[n] to #array+n
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

    e1 = e1->optimize(0);
    e2 = e2->optimize(result);
    if (!e1)
    {
	e = e2;
	if (e)
	    e->type = type;
    }
    else
	e = this;
    return e;
}

Expression *AndAndExp::optimize(int result)
{   Expression *e;

    e1 = e1->optimize(WANTflags);
    e2 = e2->optimize(WANTflags);
    e = this;
    if (e1->isBool(FALSE))
	e = new IntegerExp(loc, 0, type);
    else if (e1->isConst())
    {
	if (e2->isConst())
	    e = constFold();
	else if (e1->isBool(TRUE))
	    e = new BoolExp(loc, e2, type);
    }
    return e;
}

Expression *OrOrExp::optimize(int result)
{   Expression *e;

    e1 = e1->optimize(WANTflags);
    e2 = e2->optimize(WANTflags);
    e = this;
    if (e1->isBool(TRUE))
	e = new IntegerExp(loc, 1, type);
    else if (e1->isConst())
    {
	if (e2->isConst())
	    e = constFold();
	else if (e1->isBool(FALSE))
	    e = new BoolExp(loc, e2, type);
    }
    return e;
}

Expression *CatExp::optimize(int result)
{   Expression *e;

    //printf("CatExp::optimize(%d)\n", result);
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

	assert(es1->sz == es2->sz);
	s = mem.malloc((es1->len + es2->len + 1) * es1->sz);
	memcpy(s, es1->string, es1->len * es1->sz);
	memcpy((unsigned char *)s + es1->len, es2->string, es2->len * es1->sz);

	// Add terminating 0
	memset((unsigned char *)s + es1->len + es2->len, 0, es1->sz);

	es = new StringExp(loc, s, es1->len + es2->len);
	es->sz = es1->sz;
	es->committed = es1->committed | es2->committed;
	if (es1->committed)
	    t = es1->type;
	else
	    t = es2->type;
	es->type = new TypeSArray(t->next, new IntegerExp(0, es1->len + es2->len, Type::tindex));
	e = es;
    }
    else
	e = this;
    return e;
}


Expression *CondExp::optimize(int result)
{   Expression *e;

    econd = econd->optimize(WANTflags);
    e1 = e1->optimize(result);
    e2 = e2->optimize(result);
    if (econd->isBool(TRUE))
	e = e1;
    else if (econd->isBool(FALSE))
	e = e2;
    else
	e = this;
    return e;
}


