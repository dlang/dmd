
// Copyright (c) 1999-2004 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <assert.h>

#include "mars.h"
#include "init.h"
#include "expression.h"
#include "identifier.h"
#include "declaration.h"
#include "aggregate.h"
#include "scope.h"
#include "mtype.h"


/********************************** Initializer *******************************/

Initializer::Initializer(Loc loc)
{
    this->loc = loc;
}

Initializer *Initializer::syntaxCopy()
{
    return this;
}

Initializer *Initializer::semantic(Scope *sc, Type *t)
{
    return this;
}

Type *Initializer::inferType(Scope *sc)
{
    error(loc, "cannot infer type from initializer");
    return Type::terror;
}

Array *Initializer::arraySyntaxCopy(Array *ai)
{   Array *a = NULL;

    if (ai)
    {
	a = new Array();
	a->setDim(ai->dim);
	for (int i = 0; i < a->dim; i++)
	{   Initializer *e = (Initializer *)ai->data[i];

	    e = e->syntaxCopy();
	    a->data[i] = e;
	}
    }
    return a;
}

/********************************** VoidInitializer ***************************/

VoidInitializer::VoidInitializer(Loc loc)
    : Initializer(loc)
{
    type = NULL;
}


Initializer *VoidInitializer::syntaxCopy()
{
    return new VoidInitializer(loc);
}


Initializer *VoidInitializer::semantic(Scope *sc, Type *t)
{
    type = t;
    return this;
}


Expression *VoidInitializer::toExpression()
{
    assert(0);
    return NULL;
}


void VoidInitializer::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("void");
}


/********************************** StructInitializer *************************/

StructInitializer::StructInitializer(Loc loc)
    : Initializer(loc)
{
    ad = NULL;
}

Initializer *StructInitializer::syntaxCopy()
{
    StructInitializer *ai = new StructInitializer(loc);

    assert(field.dim == value.dim);
    ai->field.setDim(field.dim);
    ai->value.setDim(value.dim);
    for (int i = 0; i < field.dim; i++)
    {    
	ai->field.data[i] = field.data[i];

	Initializer *init = (Initializer *)value.data[i];
	init = init->syntaxCopy();
	ai->value.data[i] = init;
    }
    return ai;
}

void StructInitializer::addInit(Identifier *field, Initializer *value)
{
    //printf("StructInitializer::addInit(field = %p, value = %p)\n", field, value);
    this->field.push(field);
    this->value.push(value);
}

Initializer *StructInitializer::semantic(Scope *sc, Type *t)
{
    TypeStruct *ts;
    int errors = 0;

    t = t->toBasetype();
    if (t->ty == Tstruct)
    {	unsigned i;
	unsigned fieldi = 0;

	ts = (TypeStruct *)t;
	ad = ts->sym;
	for (i = 0; i < field.dim; i++)
	{
	    Identifier *id = (Identifier *)field.data[i];
	    Initializer *val = (Initializer *)value.data[i];
	    Dsymbol *s;
	    VarDeclaration *v;

	    if (id == NULL)
	    {
		if (fieldi >= ad->fields.dim)
		{   error(loc, "too many initializers for %s", ad->toChars());
		    continue;
		}
		else
		{
		    s = (Dsymbol *)ad->fields.data[fieldi];
		}
	    }
	    else
	    {
		//s = ad->symtab->lookup(id);
		s = ad->search(id, 0);
		if (!s)
		{
		    error("'%s' is not a member of '%s'", id->toChars(), t->toChars());
		    continue;
		}

		// Find out which field index it is
		for (fieldi = 0; 1; fieldi++)
		{
		    if (fieldi >= ad->fields.dim)
		    {
			s->error("is not a per-instance initializable field");
			break;
		    }
		    if (s == (Dsymbol *)ad->fields.data[fieldi])
			break;
		}
	    }
	    if (s && (v = s->isVarDeclaration()) != NULL)
	    {
		val = val->semantic(sc, v->type);
		value.data[i] = (void *)val;
		field.data[i] = (void *)v;
	    }
	    else
	    {	error(loc, "%s is not a field of %s", id ? id->toChars() : s->toChars(), ad->toChars());
		errors = 1;
	    }
	    fieldi++;
	}
    }
    else
    {
	error(loc, "a struct is not a valid initializer for a %s", t->toChars());
	errors = 1;
    }
    if (errors)
    {
	field.setDim(0);
	value.setDim(0);
    }
    return this;
}


Expression *StructInitializer::toExpression()
{
    assert(0);
    return NULL;
}


void StructInitializer::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writebyte('{');
    for (int i = 0; i < field.dim; i++)
    {
        if (i > 0)
	    buf->writebyte(',');
        Identifier *id = (Identifier *)field.data[i];
        if (id)
        {
            buf->writestring(id->toChars());
            buf->writebyte(':');
        }
        Initializer *iz = (Initializer *)value.data[i];
        if (iz)
            iz->toCBuffer(buf, hgs);
    }
    buf->writebyte('}');
}

/********************************** ArrayInitializer ************************************/

ArrayInitializer::ArrayInitializer(Loc loc)
    : Initializer(loc)
{
    dim = 0;
    type = NULL;
    sem = 0;
}

Initializer *ArrayInitializer::syntaxCopy()
{
    //printf("ArrayInitializer::syntaxCopy()\n");

    ArrayInitializer *ai = new ArrayInitializer(loc);

    assert(index.dim == value.dim);
    ai->index.setDim(index.dim);
    ai->value.setDim(value.dim);
    for (int i = 0; i < ai->value.dim; i++)
    {	Expression *e = (Expression *)index.data[i];
	if (e)
	    e = e->syntaxCopy();
	ai->index.data[i] = e;

	Initializer *init = (Initializer *)value.data[i];
	init = init->syntaxCopy();
	ai->value.data[i] = init;
    }
    return ai;
}

void ArrayInitializer::addInit(Expression *index, Initializer *value)
{
    this->index.push(index);
    this->value.push(value);
    dim = 0;
    type = NULL;
}

Initializer *ArrayInitializer::semantic(Scope *sc, Type *t)
{   unsigned i;
    unsigned length;

    //printf("ArrayInitializer::semantic(%s)\n", t->toChars());
    if (sem)				// if semantic() already run
	return this;
    sem = 1;
    type = t;
    t = t->toBasetype();
    switch (t->ty)
    {
	case Tpointer:
	case Tsarray:
	case Tarray:
	    break;

	default:
	    error(loc, "cannot use array to initialize %s", type->toChars());
	    return this;
    }

    length = 0;
    for (i = 0; i < index.dim; i++)
    {	Expression *idx;
	Initializer *val;

	idx = (Expression *)index.data[i];
	if (idx)
	{   idx = idx->semantic(sc);
	    idx = idx->optimize(WANTvalue);
	    index.data[i] = (void *)idx;
	    length = idx->toInteger();
	}

	val = (Initializer *)value.data[i];
	val = val->semantic(sc, t->next);
	value.data[i] = (void *)val;
	length++;
	if (length == 0)
	    error("array dimension overflow");
	if (length > dim)
	    dim = length;
    }
    unsigned long amax = 0x80000000;
    if ((unsigned long) dim * t->next->size() >= amax)
	error(loc, "array dimension %u exceeds max of %lu", dim, amax / t->next->size());
    return this;
}


Expression *ArrayInitializer::toExpression()
{
    error("array initializers as expressions are not allowed");
    return new IntegerExp(0);
}


void ArrayInitializer::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writebyte('[');
    for (int i = 0; i < index.dim; i++)
    {
        if (i > 0)
	    buf->writebyte(',');
        Expression *ex = (Expression *)index.data[i];
        if (ex)
        {
            ex->toCBuffer(buf, hgs);
            buf->writebyte(':');
        }
        Initializer *iz = (Initializer *)value.data[i];
        if (iz)
            iz->toCBuffer(buf, hgs);
    }
    buf->writebyte(']');
}


/********************************** ExpInitializer ************************************/

ExpInitializer::ExpInitializer(Loc loc, Expression *exp)
    : Initializer(loc)
{
    this->exp = exp;
}

Initializer *ExpInitializer::syntaxCopy()
{
    return new ExpInitializer(loc, exp->syntaxCopy());
}

Initializer *ExpInitializer::semantic(Scope *sc, Type *t)
{
    //printf("ExpInitializer::semantic(%s), type = %s\n", exp->toChars(), t->toChars());
    exp = exp->semantic(sc);
    Type *tb = t->toBasetype();

    /* Look for case of initializing a static array with a too-short
     * string literal, such as:
     *	char[5] foo = "abc";
     * Allow this by doing an explicit cast, which will lengthen the string
     * literal.
     */
    if (exp->op == TOKstring && tb->ty == Tsarray && exp->type->ty == Tsarray)
    {	StringExp *se = (StringExp *)exp;

	if (!se->committed && se->type->ty == Tsarray &&
	    ((TypeSArray *)se->type)->dim->toInteger() <
	    ((TypeSArray *)t)->dim->toInteger())
	{
	    exp = se->castTo(t);
	    goto L1;
	}
    }

    // Look for the case of statically initializing an array
    // with a single member.
    if (tb->ty == Tsarray &&
	!tb->next->equals(exp->type->toBasetype()->next) &&
	exp->implicitConvTo(tb->next)
       )
    {
	t = tb->next;
    }

    exp = exp->implicitCastTo(t);
L1:
    exp = exp->optimize(WANTvalue);
    //printf("-ExpInitializer::semantic(): "); exp->print();
    return this;
}

Type *ExpInitializer::inferType(Scope *sc)
{
    exp = exp->semantic(sc);
    return exp->type;
}

Expression *ExpInitializer::toExpression()
{
    return exp;
}


void ExpInitializer::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    exp->toCBuffer(buf, hgs);
}



