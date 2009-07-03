
// Compiler implementation of the D programming language
// Copyright (c) 1999-2008 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <assert.h>

#include "mars.h"
#include "init.h"
#include "expression.h"
#include "statement.h"
#include "identifier.h"
#include "declaration.h"
#include "aggregate.h"
#include "scope.h"
#include "mtype.h"
#include "hdrgen.h"

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

Initializers *Initializer::arraySyntaxCopy(Initializers *ai)
{   Initializers *a = NULL;

    if (ai)
    {
	a = new Initializers();
	a->setDim(ai->dim);
	for (int i = 0; i < a->dim; i++)
	{   Initializer *e = (Initializer *)ai->data[i];

	    e = e->syntaxCopy();
	    a->data[i] = e;
	}
    }
    return a;
}

char *Initializer::toChars()
{   OutBuffer *buf;
    HdrGenState hgs;

    memset(&hgs, 0, sizeof(hgs));
    buf = new OutBuffer();
    toCBuffer(buf, &hgs);
    return buf->toChars();
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
    //printf("VoidInitializer::semantic(t = %p)\n", t);
    type = t;
    return this;
}


Expression *VoidInitializer::toExpression()
{
    error(loc, "void initializer has no value");
    return new IntegerExp(0);
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

    //printf("StructInitializer::semantic(t = %s) %s\n", t->toChars(), toChars());
    vars.setDim(field.dim);
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
		    field.remove(i);
		    i--;
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
		s = ad->search(loc, id, 0);
		if (!s)
		{
		    error(loc, "'%s' is not a member of '%s'", id->toChars(), t->toChars());
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
		vars.data[i] = (void *)v;
	    }
	    else
	    {	error(loc, "%s is not a field of %s", id ? id->toChars() : s->toChars(), ad->toChars());
		errors = 1;
	    }
	    fieldi++;
	}
    }
    else if (t->ty == Tdelegate && value.dim == 0)
    {	/* Rewrite as empty delegate literal { }
	 */
	Arguments *arguments = new Arguments;
	Type *tf = new TypeFunction(arguments, NULL, 0, LINKd);
	FuncLiteralDeclaration *fd = new FuncLiteralDeclaration(loc, 0, tf, TOKdelegate, NULL);
	fd->fbody = new CompoundStatement(loc, new Statements());
	fd->endloc = loc;
	Expression *e = new FuncExp(loc, fd);
	ExpInitializer *ie = new ExpInitializer(loc, e);
	return ie->semantic(sc, t);
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
	vars.setDim(0);
    }
    return this;
}


/***************************************
 * This works by transforming a struct initializer into
 * a struct literal. In the future, the two should be the
 * same thing.
 */
Expression *StructInitializer::toExpression()
{   Expression *e;

    //printf("StructInitializer::toExpression() %s\n", toChars());
    if (!ad)				// if fwd referenced
    {
	return NULL;
    }
    StructDeclaration *sd = ad->isStructDeclaration();
    if (!sd)
	return NULL;
    Expressions *elements = new Expressions();
    for (size_t i = 0; i < value.dim; i++)
    {
	if (field.data[i])
	    goto Lno;
	Initializer *iz = (Initializer *)value.data[i];
	if (!iz)
	    goto Lno;
	Expression *ex = iz->toExpression();
	if (!ex)
	    goto Lno;
	elements->push(ex);
    }
    e = new StructLiteralExp(loc, sd, elements);
    e->type = sd->type;
    return e;

Lno:
    delete elements;
    //error(loc, "struct initializers as expressions are not allowed");
    return NULL;
}


void StructInitializer::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    //printf("StructInitializer::toCBuffer()\n");
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
	    idx = idx->optimize(WANTvalue | WANTinterpret);
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
	error(loc, "array dimension %u exceeds max of %ju", dim, amax / t->next->size());
    return this;
}

/********************************
 * If possible, convert array initializer to array literal.
 */

Expression *ArrayInitializer::toExpression()
{   Expressions *elements;
    Expression *e;

    //printf("ArrayInitializer::toExpression()\n");
    //static int i; if (++i == 2) halt();
    elements = new Expressions();
    for (size_t i = 0; i < value.dim; i++)
    {
	if (index.data[i])
	    goto Lno;
	Initializer *iz = (Initializer *)value.data[i];
	if (!iz)
	    goto Lno;
	Expression *ex = iz->toExpression();
	if (!ex)
	    goto Lno;
	elements->push(ex);
    }
    e = new ArrayLiteralExp(loc, elements);
    e->type = type;
    return e;

Lno:
    delete elements;
    error(loc, "array initializers as expressions are not allowed");
    return NULL;
}


/********************************
 * If possible, convert array initializer to associative array initializer.
 */

Initializer *ArrayInitializer::toAssocArrayInitializer()
{   Expressions *keys;
    Expressions *values;
    Expression *e;

    //printf("ArrayInitializer::toAssocArrayInitializer()\n");
    //static int i; if (++i == 2) halt();
    keys = new Expressions();
    keys->setDim(value.dim);
    values = new Expressions();
    values->setDim(value.dim);

    for (size_t i = 0; i < value.dim; i++)
    {
	e = (Expression *)index.data[i];
	if (!e)
	    goto Lno;
	keys->data[i] = (void *)e;

	Initializer *iz = (Initializer *)value.data[i];
	if (!iz)
	    goto Lno;
	e = iz->toExpression();
	if (!e)
	    goto Lno;
	values->data[i] = (void *)e;
    }
    e = new AssocArrayLiteralExp(loc, keys, values);
    return new ExpInitializer(loc, e);

Lno:
    delete keys;
    delete values;
    error(loc, "not an associative array initializer");
    return this;
}


Type *ArrayInitializer::inferType(Scope *sc)
{
    for (size_t i = 0; i < value.dim; i++)
    {
	if (index.data[i])
	    goto Lno;
    }
    if (value.dim)
    {
	Initializer *iz = (Initializer *)value.data[0];
	if (iz)
	{   Type *t = iz->inferType(sc);
	    t = new TypeSArray(t, new IntegerExp(value.dim));
	    t = t->semantic(loc, sc);
	    return t;
	}
    }

Lno:
    error(loc, "cannot infer type from this array initializer");
    return Type::terror;
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
	    exp = se->castTo(sc, t);
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

    exp = exp->implicitCastTo(sc, t);
L1:
    exp = exp->optimize(WANTvalue | WANTinterpret);
    //printf("-ExpInitializer::semantic(): "); exp->print();
    return this;
}

Type *ExpInitializer::inferType(Scope *sc)
{
    //printf("ExpInitializer::inferType() %s\n", toChars());
    exp = exp->semantic(sc);
    exp = resolveProperties(sc, exp);
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



