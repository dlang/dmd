
// Copyright (c) 1999-2006 by Digital Mars
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

#if __GNUC__
extern "C" long double strtold(const char *p,char **endp);
#endif

#if _WIN32 && __DMC__
extern "C" char * __cdecl __locale_decpoint;
#endif

#if IN_GCC
// Issues with using -include total.h (defines integer_t) and then complex.h fails...
#undef integer_t
#endif

#ifdef __APPLE__
#define integer_t dmd_integer_t
#endif

#if IN_GCC
#include "mem.h"
#elif _WIN32
#include "..\root\mem.h"
#elif linux
#include "../root/mem.h"
#endif

#include "port.h"
#include "mtype.h"
#include "init.h"
#include "expression.h"
#include "template.h"
#include "utf.h"
#include "enum.h"
#include "scope.h"
#include "statement.h"
#include "declaration.h"
#include "aggregate.h"
#include "import.h"
#include "id.h"
#include "dsymbol.h"
#include "module.h"
#include "attrib.h"
#include "hdrgen.h"

Expression *createTypeInfoArray(Scope *sc, Expression *args[], int dim);

#define LOGSEMANTIC	0

/**********************************
 * Set operator precedence for each operator.
 */

// Operator precedence - greater values are higher precedence

enum PREC
{
    PREC_zero,
    PREC_expr,
    PREC_assign,
    PREC_cond,
    PREC_oror,
    PREC_andand,
    PREC_or,
    PREC_xor,
    PREC_and,
    PREC_equal,
    PREC_rel,
    PREC_shift,
    PREC_add,
    PREC_mul,
    PREC_unary,
    PREC_primary,
};

enum PREC precedence[TOKMAX];

void initPrecedence()
{
    precedence[TOKimport] = PREC_primary;
    precedence[TOKidentifier] = PREC_primary;
    precedence[TOKthis] = PREC_primary;
    precedence[TOKsuper] = PREC_primary;
    precedence[TOKint64] = PREC_primary;
    precedence[TOKfloat64] = PREC_primary;
    precedence[TOKnull] = PREC_primary;
    precedence[TOKstring] = PREC_primary;
    precedence[TOKtypedot] = PREC_primary;
    precedence[TOKtypeid] = PREC_primary;
    precedence[TOKis] = PREC_primary;
    precedence[TOKassert] = PREC_primary;
    precedence[TOKfunction] = PREC_primary;

    // post
    precedence[TOKdotti] = PREC_primary;
    precedence[TOKdot] = PREC_primary;
//  precedence[TOKarrow] = PREC_primary;
    precedence[TOKplusplus] = PREC_primary;
    precedence[TOKminusminus] = PREC_primary;
    precedence[TOKcall] = PREC_primary;
    precedence[TOKslice] = PREC_primary;
    precedence[TOKarray] = PREC_primary;

    precedence[TOKaddress] = PREC_unary;
    precedence[TOKstar] = PREC_unary;
    precedence[TOKneg] = PREC_unary;
    precedence[TOKuadd] = PREC_unary;
    precedence[TOKnot] = PREC_unary;
    precedence[TOKtobool] = PREC_add;
    precedence[TOKtilde] = PREC_unary;
    precedence[TOKdelete] = PREC_unary;
    precedence[TOKnew] = PREC_unary;
    precedence[TOKcast] = PREC_unary;

    precedence[TOKmul] = PREC_mul;
    precedence[TOKdiv] = PREC_mul;
    precedence[TOKmod] = PREC_mul;

    precedence[TOKadd] = PREC_add;
    precedence[TOKmin] = PREC_add;
    precedence[TOKcat] = PREC_add;

    precedence[TOKshl] = PREC_shift;
    precedence[TOKshr] = PREC_shift;
    precedence[TOKushr] = PREC_shift;

    precedence[TOKlt] = PREC_rel;
    precedence[TOKle] = PREC_rel;
    precedence[TOKgt] = PREC_rel;
    precedence[TOKge] = PREC_rel;
    precedence[TOKunord] = PREC_rel;
    precedence[TOKlg] = PREC_rel;
    precedence[TOKleg] = PREC_rel;
    precedence[TOKule] = PREC_rel;
    precedence[TOKul] = PREC_rel;
    precedence[TOKuge] = PREC_rel;
    precedence[TOKug] = PREC_rel;
    precedence[TOKue] = PREC_rel;
    precedence[TOKin] = PREC_rel;

    precedence[TOKequal] = PREC_equal;
    precedence[TOKnotequal] = PREC_equal;
    precedence[TOKidentity] = PREC_equal;
    precedence[TOKnotidentity] = PREC_equal;

    precedence[TOKand] = PREC_and;

    precedence[TOKxor] = PREC_xor;

    precedence[TOKor] = PREC_or;

    precedence[TOKandand] = PREC_andand;

    precedence[TOKoror] = PREC_oror;

    precedence[TOKquestion] = PREC_cond;

    precedence[TOKassign] = PREC_assign;
    precedence[TOKaddass] = PREC_assign;
    precedence[TOKminass] = PREC_assign;
    precedence[TOKcatass] = PREC_assign;
    precedence[TOKmulass] = PREC_assign;
    precedence[TOKdivass] = PREC_assign;
    precedence[TOKmodass] = PREC_assign;
    precedence[TOKshlass] = PREC_assign;
    precedence[TOKshrass] = PREC_assign;
    precedence[TOKushrass] = PREC_assign;
    precedence[TOKandass] = PREC_assign;
    precedence[TOKorass] = PREC_assign;
    precedence[TOKxorass] = PREC_assign;

    precedence[TOKcomma] = PREC_expr;
}

/*****************************************
 * Determine if 'this' is available.
 * If it is, return the FuncDeclaration that has it.
 */

FuncDeclaration *hasThis(Scope *sc)
{   FuncDeclaration *fd;
    FuncDeclaration *fdthis;

    //printf("hasThis()\n");
    fdthis = sc->parent->isFuncDeclaration();
    //printf("fdthis = %p, '%s'\n", fdthis, fdthis ? fdthis->toChars() : "");

    // Go upwards until we find the enclosing member function
    fd = fdthis;
    while (1)
    {
	if (!fd)
	{
	    goto Lno;
	}
	if (!fd->isNested())
	    break;

	Dsymbol *parent = fd->parent;
	while (parent)
	{
	    TemplateInstance *ti = parent->isTemplateInstance();
	    if (ti)
		parent = ti->parent;
	    else
		break;
	}

	fd = fd->parent->isFuncDeclaration();
    }

    if (!fd->isThis())
    {   //printf("test '%s'\n", fd->toChars());
	goto Lno;
    }

    assert(fd->vthis);
    return fd;

Lno:
    return NULL;		// don't have 'this' available
}


/***************************************
 * Pull out any properties.
 */

Expression *resolveProperties(Scope *sc, Expression *e)
{
    if (e->type)
    {
	Type *t = e->type->toBasetype();

	if (t->ty == Tfunction)
	{
	    e = new CallExp(e->loc, e);
	    e = e->semantic(sc);
	}
    }
    return e;
}

/******************************
 * Perform semantic() on an array of Expressions.
 */

void arrayExpressionSemantic(Expressions *a, Scope *sc)
{
    if (a)
    {
	for (int i = 0; i < a->dim; i++)
	{   Expression *e = (Expression *)a->data[i];

	    e = e->semantic(sc);
	    a->data[i] = (void *)e;
	}
    }
}

/****************************************
 * Preprocess arguments to function.
 */

void preFunctionArguments(Loc loc, Scope *sc, Expressions *arguments)
{
    if (arguments)
    {
	for (int i = 0; i < arguments->dim; i++)
	{   Expression *arg = (Expression *)arguments->data[i];

	    if (!arg->type)
	    {
#ifdef DEBUG
		if (!global.gag)
		    printf("1: \n");
#endif
		arg->error("%s is not an expression", arg->toChars());
		arg = new IntegerExp(arg->loc, 0, Type::tint32);
	    }

	    arg = resolveProperties(sc, arg);
	    arguments->data[i] = (void *) arg;

	    arg->rvalue();
#if 0
	    if (arg->type->ty == Tfunction)
	    {
		arg = new AddrExp(arg->loc, arg);
		arg = arg->semantic(sc);
		arguments->data[i] = (void *) arg;
	    }
#endif
	}
    }
}


/****************************************
 * Now that we know the exact type of the function we're calling,
 * the arguments[] need to be adjusted:
 *	1) implicitly convert argument to the corresponding parameter type
 *	2) add default arguments for any missing arguments
 *	3) do default promotions on arguments corresponding to ...
 *	4) add hidden _arguments[] argument
 */

void functionArguments(Loc loc, Scope *sc, TypeFunction *tf, Expressions *arguments)
{
    unsigned nargs;
    unsigned nproto;
    unsigned n;
    int done;
    Type *tb;

    //printf("functionArguments()\n");
    assert(arguments);
    nargs = arguments ? arguments->dim : 0;
    nproto = tf->arguments ? tf->arguments->dim : 0;

    if (nargs > nproto && tf->varargs == 0)
	error(loc, "expected %d arguments, not %d\n", nproto, nargs);

    n = (nargs > nproto) ? nargs : nproto;	// maximum

    done = 0;
    for (int i = 0; i < n; i++)
    {
	Expression *arg;
	Argument *p;

	if (i < nargs)
	    arg = (Expression *)arguments->data[i];
	else
	    arg = NULL;

	if (i < nproto)
	{
	    Argument *p = (Argument *)tf->arguments->data[i];

	    if (!arg)
	    {
		if (!p->defaultArg)
		{
		    if (tf->varargs == 2 && i + 1 == nproto)
			goto L2;
		    error(loc, "expected %d arguments, not %d\n", nproto, nargs);
		    break;
		}
		arg = p->defaultArg->copy();
		arguments->push(arg);
		nargs++;
	    }

	    if (tf->varargs == 2 && i + 1 == nproto)
	    {
		//printf("\t\tvarargs == 2, p->type = '%s'\n", p->type->toChars());
		if (arg->implicitConvTo(p->type))
		{
		    if (nargs != nproto)
		        error(loc, "expected %d arguments, not %d\n", nproto, nargs);
		    goto L1;
		}
	     L2:
		Type *tb = p->type->toBasetype();
		switch (tb->ty)
		{
		    case Tsarray:
		    case Tarray:
		    {	// Create a static array variable v of type arg->type
#ifdef IN_GCC
			/* GCC 4.0 does not like zero length arrays used like
			   this; pass a null array value instead. Could also
			   just make a one-element array. */
			if (nargs - i == 0)
			{
			    arg = new NullExp(loc);
			    break;
			}
#endif
			char name[10+6+1];
			static int idn;
			sprintf(name, "__arrayArg%d", ++idn);
			Identifier *id = Lexer::idPool(name);
			Type *t = new TypeSArray(tb->next, new IntegerExp(nargs - i));
			t = t->semantic(loc, sc);
			VarDeclaration *v = new VarDeclaration(loc, t, id, new VoidInitializer(loc));
			v->semantic(sc);
			v->parent = sc->parent;
			//sc->insert(v);

			Expression *c = new DeclarationExp(0, v);
			c->type = v->type;

			for (int u = i; u < nargs; u++)
			{   Expression *a = (Expression *)arguments->data[u];
			    Expression *e = new VarExp(loc, v);

			    e = new IndexExp(loc, e, new IntegerExp(u + 1 - nproto));
			    e = new AssignExp(loc, e, a);
			    if (c)
				c = new CommaExp(loc, c, e);
			    else
				c = e;
			}
			arg = new VarExp(loc, v);
			if (c)
			    arg = new CommaExp(loc, c, arg);
			break;
		    }
		    case Tclass:
		    {	/* Set arg to be:
			 *	new Tclass(arg0, arg1, ..., argn)
			 */
			Expressions *args = new Expressions();
			args->setDim(nargs - i);
			for (int u = i; u < nargs; u++)
			    args->data[u - i] = arguments->data[u];
			arg = new NewExp(loc, NULL, NULL, p->type, args);
			break;
		    }
		    default:
			if (!arg)
			{   error(loc, "not enough arguments");
			    return;
		        }
			break;
		}
		arg = arg->semantic(sc);
		//printf("\targ = '%s'\n", arg->toChars());
		arguments->setDim(i + 1);
		done = 1;
	    }

	L1:
	    arg = arg->implicitCastTo(p->type);
	    if (p->inout == Out || p->inout == InOut)
	    {
		// BUG: should check that argument to inout is type 'invariant'
		// BUG: assignments to inout should also be type 'invariant'
		arg = arg->modifiableLvalue(sc, NULL);

		//if (arg->op == TOKslice)
		    //arg->error("cannot modify slice %s", arg->toChars());

		// Don't have a way yet to do a pointer to a bit in array
		if (arg->op == TOKarray &&
		    arg->type->toBasetype()->ty == Tbit)
		    error("cannot have out or inout argument of bit in array");
	    }
	    // Convert static arrays to pointers
	    if (arg->type->toBasetype()->ty == Tsarray)
	    {
		arg = arg->checkToPointer();
	    }
	}
	else
	{

	    // If not D linkage, do promotions
	    if (tf->linkage != LINKd)
	    {
		// Promote bytes, words, etc., to ints
		arg = arg->integralPromotions();

		// Promote floats to doubles
		switch (arg->type->ty)
		{
		    case Tfloat32:
			arg = arg->castTo(Type::tfloat64);
			break;

		    case Timaginary32:
			arg = arg->castTo(Type::timaginary64);
			break;
		}
	    }

	    // Convert static arrays to dynamic arrays
	    tb = arg->type->toBasetype();
	    if (tb->ty == Tsarray)
	    {
		arg = arg->castTo(tb->next->arrayOf());
	    }
	}
	arg = arg->optimize(WANTvalue);
	arguments->data[i] = (void *) arg;
	if (done)
	    break;
    }

    // If D linkage and variadic, add _arguments[] as first argument
    if (tf->linkage == LINKd && tf->varargs == 1)
    {
	Expression *e;

	e = createTypeInfoArray(sc, (Expression **)&arguments->data[nproto],
		arguments->dim - nproto);
	arguments->insert(0, e);
    }
}

/**************************************************
 * Write expression out to buf, but wrap it
 * in ( ) if its precedence is less than pr.
 */

void expToCBuffer(OutBuffer *buf, HdrGenState *hgs, Expression *e, enum PREC pr)
{
    if (precedence[e->op] < pr)
    {
	buf->writeByte('(');
	e->toCBuffer(buf, hgs);
	buf->writeByte(')');
    }
    else
	e->toCBuffer(buf, hgs);
}

/**************************************************
 * Write out argument list to buf.
 */

void argsToCBuffer(OutBuffer *buf, Expressions *arguments, HdrGenState *hgs)
{   int i;

    if (arguments)
    {
	for (i = 0; i < arguments->dim; i++)
	{   Expression *arg = (Expression *)arguments->data[i];

	    if (i)
		buf->writeByte(',');
	    expToCBuffer(buf, hgs, arg, PREC_assign);
	}
    }
}

/**************************************************
 * Write out argument types to buf.
 */

void argExpTypesToCBuffer(OutBuffer *buf, Expressions *arguments, HdrGenState *hgs)
{
    if (arguments)
    {	OutBuffer argbuf;

	for (size_t i = 0; i < arguments->dim; i++)
	{   Expression *arg = (Expression *)arguments->data[i];

	    if (i)
		buf->writeByte(',');
	    argbuf.reset();
	    arg->type->toCBuffer2(&argbuf, NULL, hgs);
	    buf->write(&argbuf);
	}
    }
}

/******************************** Expression **************************/

Expression::Expression(Loc loc, enum TOK op, int size)
    : loc(loc)
{
    this->loc = loc;
    this->op = op;
    this->size = size;
    type = NULL;
}

Expression *Expression::syntaxCopy()
{
    //printf("Expression::syntaxCopy()\n");
    //dump(0);
    return copy();
}

/*********************************
 * Does *not* do a deep copy.
 */

Expression *Expression::copy()
{
    Expression *e;
    if (!size)
	fprintf(stdmsg, "No expression copy for: %s\n", toChars());
    e = (Expression *)mem.malloc(size);
    return (Expression *)memcpy(e, this, size);
}

/**************************
 * Semantically analyze Expression.
 * Determine types, fold constants, etc.
 */

Expression *Expression::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("Expression::semantic()\n");
#endif
    if (type)
	type = type->semantic(loc, sc);
    else
	type = Type::tvoid;
    return this;
}

void Expression::print()
{
    fprintf(stdmsg, "%s\n", toChars());
    fflush(stdmsg);
}

char *Expression::toChars()
{   OutBuffer *buf;
    HdrGenState hgs;

    memset(&hgs, 0, sizeof(hgs));
    buf = new OutBuffer();
    toCBuffer(buf, &hgs);
    return buf->toChars();
}

void Expression::error(const char *format, ...)
{
    if (!global.gag)
    {
	char *p = loc.toChars();

	if (*p)
	    fprintf(stdmsg, "%s: ", p);
	mem.free(p);

	va_list ap;
	va_start(ap, format);
	vfprintf(stdmsg, format, ap);
	va_end(ap);

	fprintf(stdmsg, "\n");
	fflush(stdmsg);
    }

    global.errors++;
    //fatal();
}

void Expression::rvalue()
{
    if (type && type->toBasetype()->ty == Tvoid)
	error("voids have no value");
}

Expression *Expression::combine(Expression *e1, Expression *e2)
{
    if (e1)
    {
	if (e2)
	{
	    e1 = new CommaExp(e1->loc, e1, e2);
	    e1->type = e2->type;
	}
    }
    else
	e1 = e2;
    return e1;
}

integer_t Expression::toInteger()
{
    //printf("Expression %s\n", Token::toChars(op));
    error("Integer constant expression expected instead of %s", toChars());
    return 0;
}

uinteger_t Expression::toUInteger()
{
    //printf("Expression %s\n", Token::toChars(op));
    return (uinteger_t)toInteger();
}

real_t Expression::toReal()
{
    error("Floating point constant expression expected instead of %s", toChars());
    return 0;
}

real_t Expression::toImaginary()
{
    error("Floating point constant expression expected instead of %s", toChars());
    return 0;
}

complex_t Expression::toComplex()
{
    error("Floating point constant expression expected instead of %s", toChars());
#ifdef IN_GCC
    return complex_t(real_t(0)); // %% nicer
#else
    return 0;
#endif
}

void Expression::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring(Token::toChars(op));
}

void Expression::toMangleBuffer(OutBuffer *buf)
{
    printf("global.errors = %d, gag = %d\n", global.errors, global.gag);
    dump(0);
    assert(0);
}

/*******************************
 * Give error if we're not an lvalue.
 * If we can, convert expression to be an lvalue.
 */

Expression *Expression::toLvalue(Expression *e)
{
    if (!e)
	e = this;
    else if (!loc.filename)
	loc = e->loc;
    error("%s is not an lvalue", e->toChars());
    return this;
}

Expression *Expression::modifiableLvalue(Scope *sc, Expression *e)
{
    // See if this expression is a modifiable lvalue (i.e. not const)
    return toLvalue(e);
}

/************************************
 * Detect cases where pointers to the stack can 'escape' the
 * lifetime of the stack frame.
 */

void Expression::checkEscape()
{
}

void Expression::checkScalar()
{
    if (!type->isscalar())
	error("'%s' is not a scalar, it is a %s", toChars(), type->toChars());
}

void Expression::checkNoBool()
{
    if (type->toBasetype()->ty == Tbool)
	error("operation not allowed on bool '%s'", toChars());
}

Expression *Expression::checkIntegral()
{
    if (!type->isintegral())
    {	error("'%s' is not of integral type, it is a %s", toChars(), type->toChars());
	return new IntegerExp(0);
    }
    return this;
}

void Expression::checkArithmetic()
{
    if (!type->isintegral() && !type->isfloating())
	error("'%s' is not an arithmetic type", toChars());
}

void Expression::checkDeprecated(Scope *sc, Dsymbol *s)
{
    s->checkDeprecated(loc, sc);
}

/********************************
 * Check for expressions that have no use.
 * Input:
 *	flag	!=0 means we want the result
 */

void Expression::checkSideEffect(int flag)
{
    if (!flag)
	error("%s has no effect in expression (%s)",
		Token::toChars(op), toChars());
}

/*****************************
 * Check that expression can be tested for true or false.
 */

Expression *Expression::checkToBoolean()
{
    // Default is 'yes' - do nothing

#ifdef DEBUG
    if (!type)
	dump(0);
#endif

    if (!type->checkBoolean())
    {
	error("expression %s of type %s does not have a boolean value", toChars(), type->toChars());
    }
    return this;
}

/****************************
 */

Expression *Expression::checkToPointer()
{
    Expression *e;
    Type *tb;

    //printf("Expression::checkToPointer()\n");
    e = this;

    // If C static array, convert to pointer
    tb = type->toBasetype();
    if (tb->ty == Tsarray)
    {
	e = new AddrExp(loc, this);
	e->type = tb->next->pointerTo();
    }
    return e;
}

/******************************
 * Take address of expression.
 */

Expression *Expression::addressOf()
{
    Expression *e;

    //printf("Expression::addressOf()\n");
    e = toLvalue(NULL);
    e = new AddrExp(loc, e);
    e->type = type->pointerTo();
    return e;
}

/******************************
 * If this is a reference, dereference it.
 */

Expression *Expression::deref()
{
    //printf("Expression::deref()\n");
    if (type->ty == Treference)
    {	Expression *e;

	e = new PtrExp(loc, this);
	e->type = type->next;
	return e;
    }
    return this;
}

/********************************
 * Does this expression statically evaluate to a boolean TRUE or FALSE?
 */

int Expression::isBool(int result)
{
    return FALSE;
}

/********************************
 * Does this expression result in either a 1 or a 0?
 */

int Expression::isBit()
{
    return FALSE;
}

Expressions *Expression::arraySyntaxCopy(Expressions *exps)
{   Expressions *a = NULL;

    if (exps)
    {
	a = new Expressions();
	a->setDim(exps->dim);
	for (int i = 0; i < a->dim; i++)
	{   Expression *e = (Expression *)exps->data[i];

	    e = e->syntaxCopy();
	    a->data[i] = e;
	}
    }
    return a;
}

/******************************** IntegerExp **************************/

IntegerExp::IntegerExp(Loc loc, integer_t value, Type *type)
	: Expression(loc, TOKint64, sizeof(IntegerExp))
{
    //printf("IntegerExp(value = %lld, type = '%s')\n", value, type ? type->toChars() : "");
    if (type && !type->isscalar())
    {
	error("integral constant must be scalar type, not %s", type->toChars());
	type = Type::terror;
    }
    this->type = type;
    this->value = value;
}

IntegerExp::IntegerExp(integer_t value)
	: Expression(0, TOKint64, sizeof(IntegerExp))
{
    this->type = Type::tint32;
    this->value = value;
}

int IntegerExp::equals(Object *o)
{   IntegerExp *ne;

    if (this == o ||
	(((Expression *)o)->op == TOKint64 &&
	 ((ne = (IntegerExp *)o), type->equals(ne->type)) &&
	 value == ne->value))
	return 1;
    return 0;
}

char *IntegerExp::toChars()
{
    static char buffer[sizeof(value) * 3 + 1];

    sprintf(buffer, "%lld", value);
    return buffer;
}

integer_t IntegerExp::toInteger()
{   Type *t;

    t = type;
    while (t)
    {
	switch (t->ty)
	{
	    case Tbit:
	    case Tbool:		value = (value != 0);		break;
	    case Tint8:		value = (d_int8)  value;	break;
	    case Tchar:
	    case Tuns8:		value = (d_uns8)  value;	break;
	    case Tint16:	value = (d_int16) value;	break;
	    case Twchar:
	    case Tuns16:	value = (d_uns16) value;	break;
	    case Tint32:	value = (d_int32) value;	break;
	    case Tpointer:
	    case Tdchar:
	    case Tuns32:	value = (d_uns32) value;	break;
	    case Tint64:	value = (d_int64) value;	break;
	    case Tuns64:	value = (d_uns64) value;	break;

	    case Tenum:
	    {
		TypeEnum *te = (TypeEnum *)t;
		t = te->sym->memtype;
		continue;
	    }

	    case Ttypedef:
	    {
		TypeTypedef *tt = (TypeTypedef *)t;
		t = tt->sym->basetype;
		continue;
	    }

	    default:
		print();
		type->print();
		assert(0);
		break;
	}
	break;
    }
    return value;
}

real_t IntegerExp::toReal()
{
    Type *t;

    toInteger();
    t = type->toBasetype();
    if (t->ty == Tuns64)
	return (real_t)(d_uns64)value;
    else
	return (real_t)(d_int64)value;
}

real_t IntegerExp::toImaginary()
{
    return (real_t) 0;
}

complex_t IntegerExp::toComplex()
{
    return toReal();
}

int IntegerExp::isBool(int result)
{
    return result ? value != 0 : value == 0;
}

Expression *IntegerExp::semantic(Scope *sc)
{
    if (!type)
    {
	// Determine what the type of this number is
	integer_t number = value;

	if (number & 0x8000000000000000LL)
	    type = Type::tuns64;
	else if (number & 0xFFFFFFFF80000000LL)
	    type = Type::tint64;
	else
	    type = Type::tint32;
    }
    else
    {	type = type->semantic(loc, sc);
    }
    return this;
}

Expression *IntegerExp::toLvalue(Expression *e)
{
    if (!e)
	e = this;
    else if (!loc.filename)
	loc = e->loc;
    e->error("constant %s is not an lvalue", e->toChars());
    return this;
}

void IntegerExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    integer_t v = toInteger();

    if (type)
    {	Type *t = type;

      L1:
	switch (t->ty)
	{
	    case Tenum:
	    {   TypeEnum *te = (TypeEnum *)t;
		buf->printf("cast(%s)", te->sym->toChars());
		t = te->sym->memtype;
		goto L1;
	    }

	    case Ttypedef:
	    {	TypeTypedef *tt = (TypeTypedef *)t;
		buf->printf("cast(%s)", tt->sym->toChars());
		t = tt->sym->basetype;
		goto L1;
	    }

	    case Twchar:	// BUG: need to cast(wchar)
	    case Tdchar:	// BUG: need to cast(dchar)
		if ((uinteger_t)v > 0xFF)
		{
		     buf->printf("'\\U%08x'", v);
		     break;
		}
	    case Tchar:
		if (isprint(v) && v != '\\')
		    buf->printf("'%c'", (int)v);
		else
		    buf->printf("'\\x%02x'", (int)v);
		break;

	    case Tint8:
		buf->writestring("cast(byte)");
		goto L2;

	    case Tint16:
		buf->writestring("cast(short)");
		goto L2;

	    case Tint32:
	    L2:
		buf->printf("%ld", (int)v);
		break;

	    case Tuns8:
		buf->writestring("cast(ubyte)");
		goto L3;

	    case Tuns16:
		buf->writestring("cast(ushort)");
		goto L3;

	    case Tuns32:
	    L3:
		buf->printf("%ldu", (unsigned)v);
		break;

	    case Tint64:
		buf->printf("%lldL", v);
		break;

	    case Tuns64:
		buf->printf("%lldLU", v);
		break;

	    case Tbit:
	    case Tbool:
		buf->writestring((char *)(v ? "true" : "false"));
		break;

	    case Tpointer:
		buf->writestring("cast(");
		buf->writestring(t->toChars());
		buf->writeByte(')');
		goto L3;

	    default:
#ifdef DEBUG
		t->print();
#endif
		assert(0);
	}
    }
    else if (v & 0x8000000000000000LL)
	buf->printf("0x%llx", v);
    else
	buf->printf("%lld", v);
}

void IntegerExp::toMangleBuffer(OutBuffer *buf)
{
    if ((sinteger_t)value < 0)
	buf->printf("N%lld", -value);
    else
	buf->printf("%lld", value);
}

/******************************** RealExp **************************/

RealExp::RealExp(Loc loc, real_t value, Type *type)
	: Expression(loc, TOKfloat64, sizeof(RealExp))
{
    //printf("RealExp::RealExp(%Lg)\n", value);
    this->value = value;
    this->type = type;
}

char *RealExp::toChars()
{
    static char buffer[sizeof(value) * 3 + 8 + 1 + 1];

#ifdef IN_GCC
    value.format(buffer, sizeof(buffer));
    if (type->isimaginary())
	strcat(buffer, "i");
#else
    sprintf(buffer, type->isimaginary() ? "%Lgi" : "%Lg", value);
#endif
    assert(strlen(buffer) < sizeof(buffer));
    return buffer;
}

integer_t RealExp::toInteger()
{
#ifdef IN_GCC
    return toReal().toInt();
#else
    return (sinteger_t) toReal();
#endif
}

uinteger_t RealExp::toUInteger()
{
#ifdef IN_GCC
    return (uinteger_t) toReal().toInt();
#else
    return (uinteger_t) toReal();
#endif
}

real_t RealExp::toReal()
{
    return type->isreal() ? value : 0;
}

real_t RealExp::toImaginary()
{
    return type->isreal() ? 0 : value;
}

complex_t RealExp::toComplex()
{
#ifdef __DMC__
    return toReal() + toImaginary() * I;
#else
    return complex_t(toReal(), toImaginary());
#endif
}

int RealExp::equals(Object *o)
{   RealExp *ne;

    if (this == o ||
	(((Expression *)o)->op == TOKfloat64 &&
	 ((ne = (RealExp *)o), type->equals(ne->type)) &&
	 memcmp(&value, &ne->value, sizeof(value)) == 0))
	return 1;
    return 0;
}

Expression *RealExp::semantic(Scope *sc)
{
    if (!type)
	type = Type::tfloat64;
    else
	type = type->semantic(loc, sc);
    return this;
}

int RealExp::isBool(int result)
{
#ifdef IN_GCC
    return result ? (! value.isZero()) : (value.isZero());
#else
    return result ? (value != 0)
		  : (value == 0);
#endif
}

void floatToBuffer(OutBuffer *buf, Type *type, real_t value)
{
    /* In order to get an exact representation, try converting it
     * to decimal then back again. If it matches, use it.
     * If it doesn't, fall back to hex, which is
     * always exact.
     */
    char buffer[25];
    sprintf(buffer, "%Lg", value);
    assert(strlen(buffer) < sizeof(buffer));
#if _WIN32 && __DMC__
    char *save = __locale_decpoint;
    __locale_decpoint = ".";
    real_t r = strtold(buffer, NULL);
    __locale_decpoint = save;
#else
    real_t r = strtold(buffer, NULL);
#endif
    if (r == value)			// if exact duplication
	buf->writestring(buffer);
    else
	buf->printf("%La", value);	// ensure exact duplication

    if (type)
    {
	Type *t = type->toBasetype();
	switch (t->ty)
	{
	    case Tfloat32:
	    case Timaginary32:
	    case Tcomplex32:
		buf->writeByte('F');
		break;

	    case Tfloat80:
	    case Timaginary80:
	    case Tcomplex80:
		buf->writeByte('L');
		break;

	    default:
		break;
	}
	if (t->isimaginary())
	    buf->writeByte('i');
    }
}

void RealExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    floatToBuffer(buf, type, value);
}

void RealExp::toMangleBuffer(OutBuffer *buf)
{
    unsigned char *p = (unsigned char *)&value;
#ifdef IN_GCC
    unsigned char buffer[32];
    value.toBytes(buffer, sizeof(buffer));
    p = buffer;
#endif
    buf->writeByte('e');
    for (int i = 0; i < REALSIZE-REALPAD; i++)
	buf->printf("%02x", p[i]);
}


/******************************** ComplexExp **************************/

ComplexExp::ComplexExp(Loc loc, complex_t value, Type *type)
	: Expression(loc, TOKcomplex80, sizeof(ComplexExp))
{
    this->value = value;
    this->type = type;
    //printf("ComplexExp::ComplexExp(%s)\n", toChars());
}

char *ComplexExp::toChars()
{
    static char buffer[sizeof(value) * 3 + 8 + 1];

#ifdef IN_GCC
    char buf1[sizeof(value) * 3 + 8 + 1];
    char buf2[sizeof(value) * 3 + 8 + 1];
    creall(value).format(buf1, sizeof(buf1));
    cimagl(value).format(buf2, sizeof(buf2));
    sprintf(buffer, "(%s+%si)", buf1, buf2);
#else
    sprintf(buffer, "(%Lg+%Lgi)", creall(value), cimagl(value));
    assert(strlen(buffer) < sizeof(buffer));
#endif
    return buffer;
}

integer_t ComplexExp::toInteger()
{
#ifdef IN_GCC
    return (sinteger_t) toReal().toInt();
#else
    return (sinteger_t) toReal();
#endif
}

uinteger_t ComplexExp::toUInteger()
{
#ifdef IN_GCC
    return (uinteger_t) toReal().toInt();
#else
    return (uinteger_t) toReal();
#endif
}

real_t ComplexExp::toReal()
{
    return creall(value);
}

real_t ComplexExp::toImaginary()
{
    return cimagl(value);
}

complex_t ComplexExp::toComplex()
{
    return value;
}

int ComplexExp::equals(Object *o)
{   ComplexExp *ne;

    if (this == o ||
	(((Expression *)o)->op == TOKcomplex80 &&
	 ((ne = (ComplexExp *)o), type->equals(ne->type)) &&
	 memcmp(&value, &ne->value, sizeof(value)) == 0))
	return 1;
    return 0;
}

Expression *ComplexExp::semantic(Scope *sc)
{
    if (!type)
	type = Type::tcomplex80;
    else
	type = type->semantic(loc, sc);
    return this;
}

int ComplexExp::isBool(int result)
{
    if (result)
	return (bool)(value);
    else
	return !value;
}

void ComplexExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    /* Print as:
     *  (re+imi)
     */
#ifdef IN_GCC
    char buf1[sizeof(value) * 3 + 8 + 1];
    char buf2[sizeof(value) * 3 + 8 + 1];
    creall(value).format(buf1, sizeof(buf1));
    cimagl(value).format(buf2, sizeof(buf2));
    buf->printf("(%s+%si)", buf1, buf2);
#else
    buf->writeByte('(');
    floatToBuffer(buf, type, creall(value));
    buf->writeByte('+');
    floatToBuffer(buf, type, cimagl(value));
    buf->writestring("i)");
#endif
}

void ComplexExp::toMangleBuffer(OutBuffer *buf)
{
    buf->writeByte('c');
    real_t r = toReal();
    for (int j = 0; j < 2; j++)
    {
	unsigned char *p = (unsigned char *)&r;
#ifdef IN_GCC
	unsigned char buffer[32];
	r.toBytes(buffer, sizeof(buffer));
	p = buffer;
#endif
	for (int i = 0; i < REALSIZE-REALPAD; i++)
	    buf->printf("%02x", p[i]);
	r = toImaginary();
    }
}

/******************************** IdentifierExp **************************/

IdentifierExp::IdentifierExp(Loc loc, Identifier *ident)
	: Expression(loc, TOKidentifier, sizeof(IdentifierExp))
{
    this->ident = ident;
}

Expression *IdentifierExp::semantic(Scope *sc)
{
    Dsymbol *s;
    Dsymbol *scopesym;

#if LOGSEMANTIC
    printf("IdentifierExp::semantic('%s')\n", ident->toChars());
#endif
    s = sc->search(ident, &scopesym);
    if (s)
    {	Expression *e;
	WithScopeSymbol *withsym;

	// See if it was a with class
	withsym = scopesym->isWithScopeSymbol();
	if (withsym)
	{
	    // Same as wthis.ident
	    if (s->needThis())
	    {
		e = new VarExp(loc, withsym->withstate->wthis);
		e = new DotIdExp(loc, e, ident);
	    }
	    else
	    {	Type *t = withsym->withstate->wthis->type;
		if (t->ty == Tpointer)
		    t = t->next;
		e = new TypeDotIdExp(loc, t, ident);
	    }
	}
	else
	{
	    if (!s->parent && scopesym->isArrayScopeSymbol())
	    {	// Kludge to run semantic() here because
		// ArrayScopeSymbol::search() doesn't have access to sc.
		s->semantic(sc);
	    }
	    e = new DsymbolExp(loc, s);
	}
	return e->semantic(sc);
    }
    error("undefined identifier %s", ident->toChars());
    type = Type::terror;
    return this;
}

char *IdentifierExp::toChars()
{
    return ident->toChars();
}

void IdentifierExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    if (hgs->hdrgen)
	buf->writestring(ident->toHChars2());
    else
	buf->writestring(ident->toChars());
}

Expression *IdentifierExp::toLvalue(Expression *e)
{
#if 0
    tym = tybasic(e1->ET->Tty);
    if (!(tyscalar(tym) ||
	  tym == TYstruct ||
	  tym == TYarray && e->Eoper == TOKaddr))
	    synerr(EM_lvalue);	// lvalue expected
#endif
    return this;
}

/******************************** DollarExp **************************/

DollarExp::DollarExp(Loc loc)
	: IdentifierExp(loc, Id::dollar)
{
}

/******************************** DsymbolExp **************************/

DsymbolExp::DsymbolExp(Loc loc, Dsymbol *s)
	: Expression(loc, TOKdsymbol, sizeof(DsymbolExp))
{
    this->s = s;
}

Expression *DsymbolExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("DsymbolExp::semantic('%s')\n", s->toChars());
#endif

Lagain:
    EnumMember *em;
    Expression *e;
    VarDeclaration *v;
    FuncDeclaration *f;
    FuncLiteralDeclaration *fld;
    Declaration *d;
    ClassDeclaration *cd;
    ClassDeclaration *thiscd = NULL;
    Import *imp;
    Package *pkg;
    Type *t;

    //printf("DsymbolExp:: %p '%s' is a symbol\n", this, toChars());
    //printf("s = '%s', s->kind = '%s'\n", s->toChars(), s->kind());
    if (type)
	return this;
    if (!s->isFuncDeclaration())	// functions are checked after overloading
	checkDeprecated(sc, s);
    s = s->toAlias();
    //printf("s = '%s', s->kind = '%s', s->needThis() = %p\n", s->toChars(), s->kind(), s->needThis());
    if (!s->isFuncDeclaration())
	checkDeprecated(sc, s);

    if (sc->func)
	thiscd = sc->func->parent->isClassDeclaration();

    // BUG: This should happen after overload resolution for functions, not before
    if (s->needThis())
    {
	if (hasThis(sc) /*&& !s->isFuncDeclaration()*/)
	{
	    // Supply an implicit 'this', as in
	    //	  this.ident

	    DotVarExp *de;

	    de = new DotVarExp(loc, new ThisExp(loc), s->isDeclaration());
	    return de->semantic(sc);
	}
    }

    em = s->isEnumMember();
    if (em)
    {
	e = em->value;
	e = e->semantic(sc);
	return e;
    }
    v = s->isVarDeclaration();
    if (v)
    {
	//printf("Identifier '%s' is a variable, type '%s'\n", toChars(), v->type->toChars());
	if (!type)
	{   type = v->type;
	    if (!v->type)
	    {	error("forward reference of %s", v->toChars());
		type = Type::terror;
	    }
	}
	if (v->isConst() && type->toBasetype()->ty != Tsarray)
	{
	    if (v->init)
	    {
		if (v->inuse)
		{
		    error("circular reference to '%s'", v->toChars());
		    type = Type::tint32;
		    return this;
		}
		ExpInitializer *ei = v->init->isExpInitializer();
		if (ei)
		{
		    e = ei->exp->copy();	// make copy so we can change loc
		    if (e->op == TOKstring || !e->type)
			e = e->semantic(sc);
		    e = e->implicitCastTo(type);
		    e->loc = loc;
		    return e;
		}
	    }
	    else
	    {
		e = type->defaultInit();
		e->loc = loc;
		return e;
	    }
	}
	e = new VarExp(loc, v);
	e->type = type;
	e = e->semantic(sc);
	return e->deref();
    }
    fld = s->isFuncLiteralDeclaration();
    if (fld)
    {	//printf("'%s' is a function literal\n", fld->toChars());
	e = new FuncExp(loc, fld);
	return e->semantic(sc);
    }
    f = s->isFuncDeclaration();
    if (f)
    {	//printf("'%s' is a function\n", f->toChars());
	return new VarExp(loc, f);
    }
    cd = s->isClassDeclaration();
    if (cd && thiscd && cd->isBaseOf(thiscd, NULL) && sc->func->needThis())
    {
	// We need to add an implicit 'this' if cd is this class or a base class.
	DotTypeExp *dte;

	dte = new DotTypeExp(loc, new ThisExp(loc), s);
	return dte->semantic(sc);
    }
    imp = s->isImport();
    if (imp)
    {
	ScopeExp *ie;

	ie = new ScopeExp(loc, imp->pkg);
	return ie->semantic(sc);
    }
    pkg = s->isPackage();
    if (pkg)
    {
	ScopeExp *ie;

	ie = new ScopeExp(loc, pkg);
	return ie->semantic(sc);
    }
    Module *mod = s->isModule();
    if (mod)
    {
	ScopeExp *ie;

	ie = new ScopeExp(loc, mod);
	return ie->semantic(sc);
    }

    t = s->getType();
    if (t)
    {
	return new TypeExp(loc, t);
    }

    TemplateInstance *ti = s->isTemplateInstance();
    if (ti && !global.errors)
    {   ti->semantic(sc);
	s = ti->inst->toAlias();
	if (!s->isTemplateInstance())
	    goto Lagain;
	e = new ScopeExp(loc, ti);
	e = e->semantic(sc);
	return e;
    }

    TemplateDeclaration *td = s->isTemplateDeclaration();
    if (td)
    {
	e = new TemplateExp(loc, td);
	e = e->semantic(sc);
	return e;
    }

    error("%s '%s' is not a variable", s->kind(), s->toChars());
    type = Type::terror;
    return this;
}

char *DsymbolExp::toChars()
{
    return s->toChars();
}

void DsymbolExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring(s->toChars());
}

Expression *DsymbolExp::toLvalue(Expression *e)
{
#if 0
    tym = tybasic(e1->ET->Tty);
    if (!(tyscalar(tym) ||
	  tym == TYstruct ||
	  tym == TYarray && e->Eoper == TOKaddr))
	    synerr(EM_lvalue);	// lvalue expected
#endif
    return this;
}

/******************************** ThisExp **************************/

ThisExp::ThisExp(Loc loc)
	: Expression(loc, TOKthis, sizeof(ThisExp))
{
    var = NULL;
}

Expression *ThisExp::semantic(Scope *sc)
{   FuncDeclaration *fd;
    FuncDeclaration *fdthis;
    int nested = 0;

#if LOGSEMANTIC
    printf("ThisExp::semantic()\n");
#endif
    if (type)
    {	assert(global.errors || var);
	return this;
    }

    fdthis = sc->parent->isFuncDeclaration();
    fd = hasThis(sc);	// fd is the uplevel function with the 'this' variable
    if (!fd)
	goto Lerr;

    assert(fd->vthis);
    var = fd->vthis;
    assert(var->parent);
    type = var->type;
    if (fd != fdthis)		// if nested
    {
	fdthis->getLevel(loc, fd);
	fd->vthis->nestedref = 1;
	fd->nestedFrameRef = 1;
    }

    sc->callSuper |= CSXthis;
    return this;

Lerr:
    error("'this' is only allowed in non-static member functions");
    type = Type::tint32;
    return this;
}

int ThisExp::isBool(int result)
{
    return result ? TRUE : FALSE;
}

void ThisExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("this");
}

Expression *ThisExp::toLvalue(Expression *e)
{
    return this;
}

/******************************** SuperExp **************************/

SuperExp::SuperExp(Loc loc)
	: ThisExp(loc)
{
    op = TOKsuper;
}

Expression *SuperExp::semantic(Scope *sc)
{   FuncDeclaration *fd;
    FuncDeclaration *fdthis;
    ClassDeclaration *cd;
    Dsymbol *s;

#if LOGSEMANTIC
    printf("SuperExp::semantic('%s')\n", toChars());
#endif
    if (type)
	return this;

    fdthis = sc->parent->isFuncDeclaration();
    fd = hasThis(sc);
    if (!fd)
	goto Lerr;
    assert(fd->vthis);
    var = fd->vthis;
    assert(var->parent);

    s = fd->toParent();
    while (s && s->isTemplateInstance())
	s = s->toParent();
    assert(s);
    cd = s->isClassDeclaration();
//printf("parent is %s %s\n", fd->toParent()->kind(), fd->toParent()->toChars());
    if (!cd)
	goto Lerr;
    if (!cd->baseClass)
    {
	error("no base class for %s", cd->toChars());
	type = fd->vthis->type;
    }
    else
    {
	type = cd->baseClass->type;
    }

    if (fd != fdthis)
    {
	fdthis->getLevel(loc, fd);
	fd->vthis->nestedref = 1;
	fd->nestedFrameRef = 1;
    }

    sc->callSuper |= CSXsuper;
    return this;


Lerr:
    error("'super' is only allowed in non-static class member functions");
    type = Type::tint32;
    return this;
}

void SuperExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("super");
}


/******************************** NullExp **************************/

NullExp::NullExp(Loc loc)
	: Expression(loc, TOKnull, sizeof(NullExp))
{
}

Expression *NullExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("NullExp::semantic('%s')\n", toChars());
#endif
    // NULL is the same as (void *)0
    if (!type)
	type = Type::tvoid->pointerTo();
    return this;
}

int NullExp::isBool(int result)
{
    return result ? FALSE : TRUE;
}

void NullExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("null");
}

void NullExp::toMangleBuffer(OutBuffer *buf)
{
    buf->writeByte('n');
}

/******************************** StringExp **************************/

StringExp::StringExp(Loc loc, char *string)
	: Expression(loc, TOKstring, sizeof(StringExp))
{
    this->string = string;
    this->len = strlen(string);
    this->sz = 1;
    this->committed = 0;
    this->postfix = 0;
}

StringExp::StringExp(Loc loc, void *string, unsigned len)
	: Expression(loc, TOKstring, sizeof(StringExp))
{
    this->string = string;
    this->len = len;
    this->sz = 1;
    this->committed = 0;
    this->postfix = 0;
}

StringExp::StringExp(Loc loc, void *string, unsigned len, unsigned char postfix)
	: Expression(loc, TOKstring, sizeof(StringExp))
{
    this->string = string;
    this->len = len;
    this->sz = 1;
    this->committed = 0;
    this->postfix = postfix;
}

int StringExp::equals(Object *o)
{
    //printf("StringExp::equals('%s')\n", o->toChars());
    if (o && o->dyncast() == DYNCAST_EXPRESSION)
    {	Expression *e = (Expression *)o;

	if (e->op == TOKstring)
	{
	    return compare(o) == 0;
	}
    }
    return FALSE;
}

char *StringExp::toChars()
{
    OutBuffer buf;
    HdrGenState hgs;
    char *p;

    memset(&hgs, 0, sizeof(hgs));
    toCBuffer(&buf, &hgs);
    buf.writeByte(0);
    p = (char *)buf.data;
    buf.data = NULL;
    return p;
}

Expression *StringExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("StringExp::semantic()\n");
#endif
    if (!type)
    {	OutBuffer buffer;
	unsigned newlen = 0;
	char *p;
	unsigned u;
	unsigned c;

	switch (postfix)
	{
	    case 'd':
		for (u = 0; u < len;)
		{
		    p = utf_decodeChar((unsigned char *)string, len, &u, &c);
		    if (p)
		    {	error(p);
			break;
		    }
		    else
		    {	buffer.write4(c);
			newlen++;
		    }
		}
		buffer.write4(0);
		string = buffer.extractData();
		len = newlen;
		sz = 4;
		type = new TypeSArray(Type::tdchar, new IntegerExp(loc, len, Type::tindex));
		committed = 1;
		break;

	    case 'w':
		for (u = 0; u < len;)
		{
		    p = utf_decodeChar((unsigned char *)string, len, &u, &c);
		    if (p)
		    {	error(p);
			break;
		    }
		    else
		    {	buffer.writeUTF16(c);
			newlen++;
			if (c >= 0x10000)
			    newlen++;
		    }
		}
		buffer.writeUTF16(0);
		string = buffer.extractData();
		len = newlen;
		sz = 2;
		type = new TypeSArray(Type::twchar, new IntegerExp(loc, len, Type::tindex));
		committed = 1;
		break;

	    case 'c':
		committed = 1;
	    default:
		type = new TypeSArray(Type::tchar, new IntegerExp(loc, len, Type::tindex));
		break;
	}
	type = type->semantic(loc, sc);
    }
    return this;
}

int StringExp::compare(Object *obj)
{
    // Used to sort case statement expressions so we can do an efficient lookup
    StringExp *se2 = (StringExp *)(obj);

    // This is a kludge so isExpression() in template.c will return 5
    // for StringExp's.
    if (!se2)
	return 5;

    assert(se2->op == TOKstring);

    int len1 = len;
    int len2 = se2->len;

    if (len1 == len2)
    {
	switch (sz)
	{
	    case 1:
		return strcmp((char *)string, (char *)se2->string);

	    case 2:
	    {	unsigned u;
		d_wchar *s1 = (d_wchar *)string;
		d_wchar *s2 = (d_wchar *)se2->string;

		for (u = 0; u < len; u++)
		{
		    if (s1[u] != s2[u])
			return s1[u] - s2[u];
		}
	    }

	    case 4:
	    {	unsigned u;
		d_dchar *s1 = (d_dchar *)string;
		d_dchar *s2 = (d_dchar *)se2->string;

		for (u = 0; u < len; u++)
		{
		    if (s1[u] != s2[u])
			return s1[u] - s2[u];
		}
	    }
	    break;

	    default:
		assert(0);
	}
    }
    return len1 - len2;
}

int StringExp::isBool(int result)
{
    return result ? TRUE : FALSE;
}

void StringExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{   unsigned i;

    buf->writeByte('"');
    for (i = 0; i < len;)
    {	unsigned c;
	char *p;

	switch (sz)
	{
	    case 1:
		p = utf_decodeChar((unsigned char *)string, len, &i, &c);
		break;
	    case 2:
		p = utf_decodeWchar((unsigned short *)string, len, &i, &c);
		break;
	    case 4:
		p = NULL;
		c = ((unsigned *)string)[i];
		i++;
		break;
	    default:
		assert(0);
	}
	switch (c)
	{
	    case 0:
		break;

	    case '"':
	    case '\\':
		buf->writeByte('\\');
	    default:
		if (isprint(c))
		    buf->writeByte(c);
		else if (c <= 0x7F)
		    buf->printf("\\x%02x", c);
		else if (c <= 0xFFFF)
		    buf->printf("\\u%04x", c);
		else
		    buf->printf("\\U%08x", c);
		continue;
	}
	break;
    }
    buf->writeByte('"');
    if (postfix)
	buf->writeByte(postfix);
}

void StringExp::toMangleBuffer(OutBuffer *buf)
{   char m;
    OutBuffer tmp;
    char *p;
    unsigned c;
    unsigned u;
    unsigned char *q;
    unsigned qlen;

    /* Write string in UTF-8 format
     */
    switch (sz)
    {	case 1:
	    m = 'a';
	    q = (unsigned char *)string;
	    qlen = len;
	    break;
	case 2:
	    m = 'w';
	    for (u = 0; u < len; )
	    {
                p = utf_decodeWchar((unsigned short *)string, len, &u, &c);
                if (p)
                    error(p);
                else
                    tmp.writeUTF8(c);
	    }
	    q = tmp.data;
	    qlen = tmp.offset;
	    break;
	case 4:
	    m = 'd';
            for (u = 0; u < len; u++)
            {
                c = ((unsigned *)string)[u];
                if (!utf_isValidDchar(c))
                    error("invalid UCS-32 char \\U%08x", c);
                else
                    tmp.writeUTF8(c);
            }
	    q = tmp.data;
	    qlen = tmp.offset;
	    break;
	default:
	    assert(0);
    }
    buf->writeByte(m);
    buf->printf("%d_", qlen);
    for (size_t i = 0; i < qlen; i++)
	buf->printf("%02x", q[i]);
}

/************************ TypeDotIdExp ************************************/

/* Things like:
 *	int.size
 *	foo.size
 *	(foo).size
 *	cast(foo).size
 */

TypeDotIdExp::TypeDotIdExp(Loc loc, Type *type, Identifier *ident)
    : Expression(loc, TOKtypedot, sizeof(TypeDotIdExp))
{
    this->type = type;
    this->ident = ident;
}

Expression *TypeDotIdExp::syntaxCopy()
{
    TypeDotIdExp *te = new TypeDotIdExp(loc, type->syntaxCopy(), ident);
    return te;
}

Expression *TypeDotIdExp::semantic(Scope *sc)
{   Expression *e;

#if LOGSEMANTIC
    printf("TypeDotIdExp::semantic()\n");
#endif
    e = new DotIdExp(loc, new TypeExp(loc, type), ident);
    e = e->semantic(sc);
    return e;
}

void TypeDotIdExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writeByte('(');
    type->toCBuffer(buf, NULL, hgs);
    buf->writeByte(')');
    buf->writeByte('.');
    buf->writestring(ident->toChars());
}

/************************************************************/

// Mainly just a placeholder

TypeExp::TypeExp(Loc loc, Type *type)
    : Expression(loc, TOKtype, sizeof(TypeExp))
{
    //printf("TypeExp(): %s\n", type->toChars());
    this->type = type;
}

void TypeExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    type->toCBuffer(buf, NULL, hgs);
}

/************************************************************/

// Mainly just a placeholder

ScopeExp::ScopeExp(Loc loc, ScopeDsymbol *pkg)
    : Expression(loc, TOKimport, sizeof(ScopeExp))
{
    this->sds = pkg;
}

Expression *ScopeExp::syntaxCopy()
{
    ScopeExp *se = new ScopeExp(loc, (ScopeDsymbol *)sds->syntaxCopy(NULL));
    return se;
}

Expression *ScopeExp::semantic(Scope *sc)
{
    TemplateInstance *ti;
    ScopeDsymbol *sds2;

#if LOGSEMANTIC
    printf("+ScopeExp::semantic('%s')\n", toChars());
#endif
Lagain:
    ti = sds->isTemplateInstance();
    if (ti && !global.errors)
    {	Dsymbol *s;
	ti->semantic(sc);
	s = ti->inst->toAlias();
	sds2 = s->isScopeDsymbol();
	if (!sds2)
	{   Expression *e;

	    //printf("s = %s, '%s'\n", s->kind(), s->toChars());
	    if (ti->withsym)
	    {
		// Same as wthis.s
		e = new VarExp(loc, ti->withsym->withstate->wthis);
		e = new DotVarExp(loc, e, s->isDeclaration());
	    }
	    else
		e = new DsymbolExp(loc, s);
	    e = e->semantic(sc);
	    //printf("-1ScopeExp::semantic()\n");
	    return e;
	}
	if (sds2 != sds)
	{
	    sds = sds2;
	    goto Lagain;
	}
	//printf("sds = %s, '%s'\n", sds->kind(), sds->toChars());
    }
    else
    {
	//printf("sds = %s, '%s'\n", sds->kind(), sds->toChars());
	//printf("\tparent = '%s'\n", sds->parent->toChars());
	sds->semantic(sc);
    }
    type = Type::tvoid;
    //printf("-2ScopeExp::semantic()\n");
    return this;
}

void ScopeExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    if (sds->isTemplateInstance())
    {
        sds->toCBuffer(buf, hgs);
    }
    else
    {
	buf->writestring(sds->kind());
	buf->writestring(" ");
	buf->writestring(sds->toChars());
    }
}

/********************** TemplateExp **************************************/

// Mainly just a placeholder

TemplateExp::TemplateExp(Loc loc, TemplateDeclaration *td)
    : Expression(loc, TOKtemplate, sizeof(TemplateExp))
{
    //printf("TemplateExp(): %s\n", td->toChars());
    this->td = td;
}

void TemplateExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring(td->toChars());
}

/********************** NewExp **************************************/

NewExp::NewExp(Loc loc, Expression *thisexp, Expressions *newargs,
	Type *newtype, Expressions *arguments)
    : Expression(loc, TOKnew, sizeof(NewExp))
{
    this->thisexp = thisexp;
    this->newargs = newargs;
    this->newtype = newtype;
    this->arguments = arguments;
    member = NULL;
    allocator = NULL;
}

Expression *NewExp::syntaxCopy()
{
    return new NewExp(loc,
	thisexp ? thisexp->syntaxCopy() : NULL,
	arraySyntaxCopy(newargs),
	newtype->syntaxCopy(), arraySyntaxCopy(arguments));
}


Expression *NewExp::semantic(Scope *sc)
{   int i;
    Type *tb;
    ClassDeclaration *cdthis = NULL;

#if LOGSEMANTIC
    printf("NewExp::semantic() %s\n", toChars());
    printf("newtype: %s\n", newtype->toChars());
#endif
    if (type)			// if semantic() already run
	return this;

    if (thisexp)
    {	thisexp = thisexp->semantic(sc);
	cdthis = thisexp->type->isClassHandle();
	if (cdthis)
	{
	    sc = sc->push(cdthis);
	    type = newtype->semantic(loc, sc);
	    sc = sc->pop();
	}
	else
	{
	    error("'this' for nested class must be a class type, not %s", thisexp->type->toChars());
	    type = newtype->semantic(loc, sc);
	}
    }
    else
	type = newtype->semantic(loc, sc);
    tb = type->toBasetype();
    //printf("tb: %s, deco = %s\n", tb->toChars(), tb->deco);

    arrayExpressionSemantic(newargs, sc);
    preFunctionArguments(loc, sc, newargs);
    arrayExpressionSemantic(arguments, sc);
    preFunctionArguments(loc, sc, arguments);

    if (thisexp && tb->ty != Tclass)
	error("e.new is only for allocating nested classes, not %s", tb->toChars());

    if (tb->ty == Tclass)
    {	ClassDeclaration *cd;
	TypeClass *tc;
	FuncDeclaration *f;
	TypeFunction *tf;

	tc = (TypeClass *)(tb);
	cd = tc->sym->isClassDeclaration();
	if (cd->isInterfaceDeclaration())
	    error("cannot create instance of interface %s", cd->toChars());
	if (cd->isAbstract())
	    error("cannot create instance of abstract class %s", cd->toChars());
	checkDeprecated(sc, cd);
	if (cd->isNested())
	{   /* We need a 'this' pointer for the nested class.
	     * Ensure we have the right one.
	     */
	    Dsymbol *s = cd->toParent();
	    ClassDeclaration *cdn = s->isClassDeclaration();

	    if (cdn)
	    {
		if (cdthis)
		{
		    if (cdthis != cdn && !cdn->isBaseOf(cdthis, NULL))
			error("'this' for nested class must be of type %s, not %s", cdn->toChars(), thisexp->type->toChars());
		}
		else
		{
		    for (Dsymbol *sf = sc->func; 1; sf= sf->toParent()->isFuncDeclaration())
		    {
			if (!sf)
			{
			    error("outer class %s 'this' needed to 'new' nested class %s", cdn->toChars(), cd->toChars());
			    break;
			}
			AggregateDeclaration *ad = sf->isThis();
			if (ad && (ad == cdn || cdn->isBaseOf(ad->isClassDeclaration(), NULL)))
			    break;
		    }
		}
	    }
	    else if (thisexp)
		error("e.new is only for allocating nested classes");
	}
	f = cd->ctor;
	if (f)
	{
	    assert(f);
	    f = f->overloadResolve(loc, arguments);
	    checkDeprecated(sc, f);
	    member = f->isCtorDeclaration();
	    assert(member);

	    cd->accessCheck(loc, sc, member);

	    tf = (TypeFunction *)f->type;
	    type = tf->next;

	    if (!arguments)
		arguments = new Expressions();
	    functionArguments(loc, sc, tf, arguments);
	}
	else
	{
	    if (arguments && arguments->dim)
		error("no constructor for %s", cd->toChars());
	}

	if (cd->aggNew)
	{   Expression *e;

	    f = cd->aggNew;

	    // Prepend the uint size argument to newargs[]
	    e = new IntegerExp(loc, cd->size(loc), Type::tuns32);
	    if (!newargs)
		newargs = new Expressions();
	    newargs->shift(e);

	    f = f->overloadResolve(loc, newargs);
	    allocator = f->isNewDeclaration();
	    assert(allocator);

	    tf = (TypeFunction *)f->type;
	    functionArguments(loc, sc, tf, newargs);
	}
	else
	{
	    if (newargs && newargs->dim)
		error("no allocator for %s", cd->toChars());
	}

    }
    else if (tb->ty == Tstruct)
    {
	TypeStruct *ts = (TypeStruct *)tb;
	StructDeclaration *sd = ts->sym;
	FuncDeclaration *f = sd->aggNew;
	TypeFunction *tf;

	if (arguments && arguments->dim)
	    error("no constructor for %s", type->toChars());

	if (f)
	{
	    Expression *e;

	    // Prepend the uint size argument to newargs[]
	    e = new IntegerExp(loc, sd->size(loc), Type::tuns32);
	    if (!newargs)
		newargs = new Expressions();
	    newargs->shift(e);

	    f = f->overloadResolve(loc, newargs);
	    allocator = f->isNewDeclaration();
	    assert(allocator);

	    tf = (TypeFunction *)f->type;
	    functionArguments(loc, sc, tf, newargs);

	    e = new VarExp(loc, f);
	    e = new CallExp(loc, e, newargs);
	    e = e->semantic(sc);
	    e->type = type->pointerTo();
	    return e;
	}

	type = type->pointerTo();
    }
    else if (tb->ty == Tarray && (arguments && arguments->dim))
    {	Expression *arg;

	arg = (Expression *)arguments->data[0];
	arg = resolveProperties(sc, arg);
	arg = arg->implicitCastTo(Type::tindex);
	if (arg->op == TOKint64 && (long long)arg->toInteger() < 0)
	    error("negative array index %s", arg->toChars());
	arguments->data[0] = (void *) arg;
    }
    else if (tb->isscalar())
    {
	if (arguments && arguments->dim)
	    error("no constructor for %s", type->toChars());

	type = type->pointerTo();
    }
    else
    {
	error("new can only create structs, dynamic arrays or class objects, not %s's", type->toChars());
	type = type->pointerTo();
    }

//printf("NewExp: '%s'\n", toChars());
//printf("NewExp:type '%s'\n", type->toChars());

    return this;
}

void NewExp::checkSideEffect(int flag)
{
}

void NewExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{   int i;

    if (thisexp)
    {	expToCBuffer(buf, hgs, thisexp, PREC_primary);
	buf->writeByte('.');
    }
    buf->writestring("new ");
    if (newargs && newargs->dim)
    {
	buf->writeByte('(');
	argsToCBuffer(buf, newargs, hgs);
	buf->writeByte(')');
    }
    newtype->toCBuffer(buf, NULL, hgs);
    if (arguments && arguments->dim)
    {
	buf->writeByte('(');
	argsToCBuffer(buf, arguments, hgs);
	buf->writeByte(')');
    }
}

/********************** NewAnonClassExp **************************************/

NewAnonClassExp::NewAnonClassExp(Loc loc, Expression *thisexp,
	Expressions *newargs, ClassDeclaration *cd, Expressions *arguments)
    : Expression(loc, TOKnewanonclass, sizeof(NewAnonClassExp))
{
    this->thisexp = thisexp;
    this->newargs = newargs;
    this->cd = cd;
    this->arguments = arguments;
}

Expression *NewAnonClassExp::syntaxCopy()
{
    return new NewAnonClassExp(loc,
	thisexp ? thisexp->syntaxCopy() : NULL,
	arraySyntaxCopy(newargs),
	(ClassDeclaration *)cd->syntaxCopy(NULL),
	arraySyntaxCopy(arguments));
}


Expression *NewAnonClassExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("NewAnonClassExp::semantic() %s\n", toChars());
    //printf("type: %s\n", type->toChars());
#endif

    Expression *d = new DeclarationExp(loc, cd);
    d = d->semantic(sc);

    Expression *n = new NewExp(loc, thisexp, newargs, cd->type, arguments);

    Expression *c = new CommaExp(loc, d, n);
    return c->semantic(sc);
}

void NewAnonClassExp::checkSideEffect(int flag)
{
}

void NewAnonClassExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{   int i;

    if (thisexp)
    {	expToCBuffer(buf, hgs, thisexp, PREC_primary);
	buf->writeByte('.');
    }
    buf->writestring("new");
    if (newargs && newargs->dim)
    {
	buf->writeByte('(');
	argsToCBuffer(buf, newargs, hgs);
	buf->writeByte(')');
    }
    buf->writestring(" class ");
    if (arguments && arguments->dim)
    {
	buf->writeByte('(');
	argsToCBuffer(buf, arguments, hgs);
	buf->writeByte(')');
    }
    //buf->writestring(" { }");
    if (cd)
    {
        cd->toCBuffer(buf, hgs);
    }
}

/********************** SymOffExp **************************************/

SymOffExp::SymOffExp(Loc loc, Declaration *var, unsigned offset)
    : Expression(loc, TOKsymoff, sizeof(SymOffExp))
{
    assert(var);
    this->var = var;
    this->offset = offset;
}

Expression *SymOffExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("SymOffExp::semantic('%s')\n", toChars());
#endif
    //var->semantic(sc);
    type = var->type->pointerTo();
    return this;
}

int SymOffExp::isBool(int result)
{
    return result ? TRUE : FALSE;
}

void SymOffExp::checkEscape()
{
    VarDeclaration *v = var->isVarDeclaration();
    if (v)
    {
	if (!v->isDataseg())
	    error("escaping reference to local %s", v->toChars());
    }
}

void SymOffExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    if (offset)
	buf->printf("(& %s+%u)", var->toChars(), offset);
    else
	buf->printf("& %s", var->toChars());
}

/******************************** VarExp **************************/

VarExp::VarExp(Loc loc, Declaration *var)
	: Expression(loc, TOKvar, sizeof(VarExp))
{
    //printf("VarExp(this = %p, '%s')\n", this, var->toChars());
    this->var = var;
    this->type = var->type;
}

int VarExp::equals(Object *o)
{   VarExp *ne;

    if (this == o ||
	(((Expression *)o)->op == TOKvar &&
	 ((ne = (VarExp *)o), type->equals(ne->type)) &&
	 var == ne->var))
	return 1;
    return 0;
}

Expression *VarExp::semantic(Scope *sc)
{   FuncLiteralDeclaration *fd;

#if LOGSEMANTIC
    printf("VarExp::semantic(%s)\n", toChars());
#endif
    if (!type)
	type = var->type;

    VarDeclaration *v = var->isVarDeclaration();
    if (v)
    {
	if (v->isConst() && type->toBasetype()->ty != Tsarray && v->init)
	{
	    ExpInitializer *ei = v->init->isExpInitializer();
	    if (ei)
	    {
		//ei->exp->implicitCastTo(type)->print();
		return ei->exp->implicitCastTo(type);
	    }
	}
	if (!v->isDataseg() && v->parent != sc->parent && v->parent)
	{
	    FuncDeclaration *fdv = v->toParent()->isFuncDeclaration();
	    FuncDeclaration *fdthis = sc->parent->isFuncDeclaration();

	    if (fdv && fdthis)
	    {
		fdthis->getLevel(loc, fdv);	// check for access
		v->nestedref = 1;
		fdv->nestedFrameRef = 1;
	    }
	}
    }
#if 0
    else if ((fd = var->isFuncLiteralDeclaration()) != NULL)
    {	Expression *e;
	e = new FuncExp(loc, fd);
	e->type = type;
	return e;
    }
#endif
    return this;
}

char *VarExp::toChars()
{
    return var->toChars();
}

void VarExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring(var->toChars());
}

void VarExp::checkEscape()
{
    VarDeclaration *v = var->isVarDeclaration();
    if (v)
    {
	if (v->isAuto() && !v->noauto)
	    error("escaping reference to auto local %s", v->toChars());
	else if (v->storage_class & STCvariadic)
	    error("escaping reference to variadic parameter %s", v->toChars());
    }
}

Expression *VarExp::toLvalue(Expression *e)
{
#if 0
    tym = tybasic(e1->ET->Tty);
    if (!(tyscalar(tym) ||
	  tym == TYstruct ||
	  tym == TYarray && e->Eoper == TOKaddr))
	    synerr(EM_lvalue);	// lvalue expected
#endif
    return this;
}

Expression *VarExp::modifiableLvalue(Scope *sc, Expression *e)
{
    //printf("VarExp::modifiableLvalue('%s')\n", var->toChars());
    if (sc->incontract && var->isParameter())
	error("cannot modify parameter '%s' in contract", var->toChars());

    if (type && type->toBasetype()->ty == Tsarray)
	error("cannot change reference to static array '%s'", var->toChars());

    if (var->isConst())
	error("cannot modify const variable '%s'", var->toChars());

    if (var->isCtorinit())
    {	// It's only modifiable if inside the right constructor
	if (sc->func &&
	    ((sc->func->isCtorDeclaration() && var->storage_class & STCfield) ||
	     (sc->func->isStaticCtorDeclaration() && !(var->storage_class & STCfield))) &&
	    sc->func->toParent() == var->toParent())
	{
	    VarDeclaration *v = var->isVarDeclaration();
	    assert(v);
	    v->ctorinit = 1;
	    //printf("setting ctorinit\n");
	}
	else
	{
	    error("can only initialize const %s inside constructor", var->toChars());
	}
    }

    // See if this expression is a modifiable lvalue (i.e. not const)
    return toLvalue(e);
}


/******************************** FuncExp *********************************/

FuncExp::FuncExp(Loc loc, FuncLiteralDeclaration *fd)
	: Expression(loc, TOKfunction, sizeof(FuncExp))
{
    this->fd = fd;
}

Expression *FuncExp::syntaxCopy()
{
    return new FuncExp(loc, (FuncLiteralDeclaration *)fd->syntaxCopy(NULL));
}

Expression *FuncExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("FuncExp::semantic(%s)\n", toChars());
#endif
    if (!type)
    {
	fd->semantic(sc);
	fd->parent = sc->parent;
	if (!global.errors)
	{
	    fd->semantic2(sc);
	    if (!global.errors)
	    {
		fd->semantic3(sc);

		if (!global.errors && global.params.useInline)
		    fd->inlineScan();
	    }
	}

	// Type is a "delegate to" or "pointer to" the function literal
	if (fd->isNested())
	{
	    type = new TypeDelegate(fd->type);
	    type = type->semantic(loc, sc);
	}
	else
	{
	    type = fd->type->pointerTo();
	}
    }
    return this;
}

char *FuncExp::toChars()
{
    return fd->toChars();
}

void FuncExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring(fd->toChars());
}


/******************************** DeclarationExp **************************/

DeclarationExp::DeclarationExp(Loc loc, Dsymbol *declaration)
	: Expression(loc, TOKdeclaration, sizeof(DeclarationExp))
{
    this->declaration = declaration;
}

Expression *DeclarationExp::syntaxCopy()
{
    return new DeclarationExp(loc, declaration->syntaxCopy(NULL));
}

Expression *DeclarationExp::semantic(Scope *sc)
{
    if (type)
	return this;

#if LOGSEMANTIC
    printf("DeclarationExp::semantic() %s\n", toChars());
#endif

    /* This is here to support extern(linkage) declaration,
     * where the extern(linkage) winds up being an AttribDeclaration
     * wrapper.
     */
    Dsymbol *s = declaration;

    AttribDeclaration *ad = declaration->isAttribDeclaration();
    if (ad)
    {
	if (ad->decl && ad->decl->dim == 1)
	    s = (Dsymbol *)ad->decl->data[0];
    }

    if (s->isVarDeclaration())
    {	// Do semantic() on initializer first, so:
	//	int a = a;
	// will be illegal.
	declaration->semantic(sc);
	s->parent = sc->parent;
    }

    //printf("inserting '%s' %p into sc = %p\n", s->toChars(), s, sc);
    // Insert into both local scope and function scope.
    // Must be unique in both.
    if (s->ident)
    {
	if (!sc->insert(s))
	    error("declaration %s is already defined", s->toPrettyChars());
	else if (sc->func)
	{   VarDeclaration *v = s->isVarDeclaration();
	    if ((s->isFuncDeclaration() /*|| v && v->storage_class & STCstatic*/) &&
		!sc->func->localsymtab->insert(s))
		error("declaration %s is already defined in another scope in %s", s->toPrettyChars(), sc->func->toChars());
	    else if (!global.params.useDeprecated)
	    {	// Disallow shadowing

		for (Scope *scx = sc->enclosing; scx && scx->func == sc->func; scx = scx->enclosing)
		{   Dsymbol *s2;

		    if (scx->scopesym && scx->scopesym->symtab &&
			(s2 = scx->scopesym->symtab->lookup(s->ident)) != NULL &&
			s != s2)
		    {
			error("shadowing declaration %s is deprecated", s->toPrettyChars());
		    }
		}
	    }
	}
    }
    if (!s->isVarDeclaration())
    {
	declaration->semantic(sc);
	s->parent = sc->parent;
    }
    if (!global.errors)
    {
	declaration->semantic2(sc);
	if (!global.errors)
	{
	    declaration->semantic3(sc);

	    if (!global.errors && global.params.useInline)
		declaration->inlineScan();
	}
    }

    type = Type::tvoid;
    return this;
}

void DeclarationExp::checkSideEffect(int flag)
{
}

void DeclarationExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    declaration->toCBuffer(buf, hgs);
}


/************************ TypeidExp ************************************/

/*
 *	typeid(int)
 */

TypeidExp::TypeidExp(Loc loc, Type *typeidType)
    : Expression(loc, TOKtypeid, sizeof(TypeidExp))
{
    this->typeidType = typeidType;
}


Expression *TypeidExp::syntaxCopy()
{
    return new TypeidExp(loc, typeidType->syntaxCopy());
}


Expression *TypeidExp::semantic(Scope *sc)
{   Expression *e;

#if LOGSEMANTIC
    printf("TypeidExp::semantic()\n");
#endif
    typeidType = typeidType->semantic(loc, sc);
    e = typeidType->getTypeInfo(sc);
    return e;
}

void TypeidExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("typeid(");
    typeidType->toCBuffer(buf, NULL, hgs);
    buf->writeByte(')');
}

/************************************************************/

HaltExp::HaltExp(Loc loc)
	: Expression(loc, TOKhalt, sizeof(HaltExp))
{
}

Expression *HaltExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("HaltExp::semantic()\n");
#endif
    type = Type::tvoid;
    return this;
}

void HaltExp::checkSideEffect(int flag)
{
}

void HaltExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("halt");
}

/************************************************************/

IftypeExp::IftypeExp(Loc loc, Type *targ, Identifier *id, enum TOK tok,
	Type *tspec, enum TOK tok2)
	: Expression(loc, TOKis, sizeof(IftypeExp))
{
    this->targ = targ;
    this->id = id;
    this->tok = tok;
    this->tspec = tspec;
    this->tok2 = tok2;
}

Expression *IftypeExp::syntaxCopy()
{
    return new IftypeExp(loc,
	targ->syntaxCopy(),
	id,
	tok,
	tspec ? tspec->syntaxCopy() : NULL,
	tok2);
}

Expression *IftypeExp::semantic(Scope *sc)
{   Type *tded;

    //printf("IftypeExp::semantic()\n");
    if (id && !(sc->flags & SCOPEstaticif))
	error("can only declare type aliases within static if conditionals");

    unsigned errors = global.errors;
    global.gag++;			// suppress printing of error messages
    targ = targ->semantic(loc, sc);
    global.gag--;
    if (errors != global.errors)	// if any errors happened
    {					// then condition is false
	global.errors = errors;
	goto Lno;
    }
    else if (tok2 != TOKreserved)
    {
	switch (tok2)
	{
	    case TOKtypedef:
		if (targ->ty != Ttypedef)
		    goto Lno;
		tded = ((TypeTypedef *)targ)->sym->basetype;
		break;

	    case TOKstruct:
		if (targ->ty != Tstruct)
		    goto Lno;
		if (((TypeStruct *)targ)->sym->isUnionDeclaration())
		    goto Lno;
		tded = targ;
		break;

	    case TOKunion:
		if (targ->ty != Tstruct)
		    goto Lno;
		if (!((TypeStruct *)targ)->sym->isUnionDeclaration())
		    goto Lno;
		tded = targ;
		break;

	    case TOKclass:
		if (targ->ty != Tclass)
		    goto Lno;
		if (((TypeClass *)targ)->sym->isInterfaceDeclaration())
		    goto Lno;
		tded = targ;
		break;

	    case TOKinterface:
		if (targ->ty != Tclass)
		    goto Lno;
		if (!((TypeClass *)targ)->sym->isInterfaceDeclaration())
		    goto Lno;
		tded = targ;
		break;

	    case TOKenum:
		if (targ->ty != Tenum)
		    goto Lno;
		tded = ((TypeEnum *)targ)->sym->memtype;
		break;

	    case TOKfunction:
		if (targ->ty != Tfunction)
		    goto Lno;
		tded = targ->next;
		break;

	    case TOKdelegate:
		if (targ->ty != Tdelegate)
		    goto Lno;
		tded = targ->next;
		break;

	    default:
		assert(0);
	}
	goto Lyes;
    }
    else if (id && tspec)
    {
	/* Evaluate to TRUE if targ matches tspec.
	 * If TRUE, declare id as an alias for the specialized type.
	 */

	MATCH m;
	TemplateTypeParameter tp(loc, id, NULL, NULL);

	TemplateParameters parameters;
	parameters.setDim(1);
	parameters.data[0] = (void *)&tp;

	Array dedtypes;
	dedtypes.setDim(1);
	dedtypes.data[0] = NULL;

	m = targ->deduceType(NULL, tspec, &parameters, &dedtypes);
	if (m == MATCHnomatch ||
	    (m != MATCHexact && tok == TOKequal))
	    goto Lno;
	else
	{
	    assert(dedtypes.dim == 1);
	    tded = (Type *)dedtypes.data[0];
	    if (!tded)
		tded = targ;
	    goto Lyes;
	}
    }
    else if (id)
    {
	/* Declare id as an alias for type targ. Evaluate to TRUE
	 */
	tded = targ;
	goto Lyes;
    }
    else if (tspec)
    {
	/* Evaluate to TRUE if targ matches tspec
	 */
	tspec = tspec->semantic(loc, sc);
	//printf("targ  = %s\n", targ->toChars());
	//printf("tspec = %s\n", tspec->toChars());
	if (tok == TOKcolon)
	{   if (targ->implicitConvTo(tspec))
		goto Lyes;
	    else
		goto Lno;
	}
	else /* == */
	{   if (targ->equals(tspec))
		goto Lyes;
	    else
		goto Lno;
	}
    }

Lyes:
    if (id)
    {
	Dsymbol *s = new AliasDeclaration(loc, id, tded);
	s->semantic(sc);
	sc->insert(s);
	if (sc->sd)
	    s->addMember(sc, sc->sd, 1);
    }
    return new IntegerExp(1);

Lno:
    return new IntegerExp(0);
}

void IftypeExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("is(");
    targ->toCBuffer(buf, id, hgs);
    if (tspec)
    {
	if (tok == TOKcolon)
	    buf->writestring(" : ");
	else
	    buf->writestring(" == ");
	tspec->toCBuffer(buf, NULL, hgs);
    }
    buf->writeByte(')');
}


/************************************************************/

UnaExp::UnaExp(Loc loc, enum TOK op, int size, Expression *e1)
	: Expression(loc, op, size)
{
    this->e1 = e1;
}

Expression *UnaExp::syntaxCopy()
{   UnaExp *e;

    e = (UnaExp *)copy();
    e->e1 = e->e1->syntaxCopy();
    return e;
}

Expression *UnaExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("UnaExp::semantic('%s')\n", toChars());
#endif
    e1 = e1->semantic(sc);
//    if (!e1->type)
//	error("%s has no value", e1->toChars());
    return this;
}

void UnaExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring(Token::toChars(op));
    expToCBuffer(buf, hgs, e1, precedence[op]);
}

/************************************************************/

BinExp::BinExp(Loc loc, enum TOK op, int size, Expression *e1, Expression *e2)
	: Expression(loc, op, size)
{
    this->e1 = e1;
    this->e2 = e2;
}

Expression *BinExp::syntaxCopy()
{   BinExp *e;

    e = (BinExp *)copy();
    e->e1 = e->e1->syntaxCopy();
    e->e2 = e->e2->syntaxCopy();
    return e;
}

Expression *BinExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("BinExp::semantic('%s')\n", toChars());
#endif
    e1 = e1->semantic(sc);
    if (!e1->type)
    {
	error("%s has no value", e1->toChars());
	e1->type = Type::terror;
    }
    e2 = e2->semantic(sc);
    if (!e2->type)
    {
	error("%s has no value", e2->toChars());
	e2->type = Type::terror;
    }
    assert(e1->type);
    return this;
}

Expression *BinExp::semanticp(Scope *sc)
{
    BinExp::semantic(sc);
    e1 = resolveProperties(sc, e1);
    e2 = resolveProperties(sc, e2);
    return this;
}

/***************************
 * Common semantic routine for some xxxAssignExp's.
 */

Expression *BinExp::commonSemanticAssign(Scope *sc)
{   Expression *e;

    if (!type)
    {
	BinExp::semantic(sc);
	e2 = resolveProperties(sc, e2);

	e = op_overload(sc);
	if (e)
	    return e;

	e1 = e1->modifiableLvalue(sc, NULL);
	e1->checkScalar();
	type = e1->type;
	if (type->toBasetype()->ty == Tbool)
	{
	    error("operator not allowed on bool expression %s", toChars());
	}
	typeCombine();
	e1->checkArithmetic();
	e2->checkArithmetic();

	if (op == TOKmodass && e2->type->iscomplex())
	{   error("cannot perform modulo complex arithmetic");
	    return new IntegerExp(0);
	}
    }
    return this;
}

Expression *BinExp::commonSemanticAssignIntegral(Scope *sc)
{   Expression *e;

    if (!type)
    {
	BinExp::semantic(sc);
	e2 = resolveProperties(sc, e2);

	e = op_overload(sc);
	if (e)
	    return e;

	e1 = e1->modifiableLvalue(sc, NULL);
	e1->checkScalar();
	type = e1->type;
	if (type->toBasetype()->ty == Tbool)
	{
	    e2 = e2->implicitCastTo(type);
	}

	typeCombine();
	e1->checkIntegral();
	e2->checkIntegral();
    }
    return this;
}

void BinExp::checkSideEffect(int flag)
{
    if (op == TOKplusplus ||
	   op == TOKminusminus ||
	   op == TOKassign ||
	   op == TOKaddass ||
	   op == TOKminass ||
	   op == TOKcatass ||
	   op == TOKmulass ||
	   op == TOKdivass ||
	   op == TOKmodass ||
	   op == TOKshlass ||
	   op == TOKshrass ||
	   op == TOKushrass ||
	   op == TOKandass ||
	   op == TOKorass ||
	   op == TOKxorass ||
	   op == TOKoror ||
	   op == TOKandand ||
	   op == TOKin ||
	   op == TOKremove)
	return;
    Expression::checkSideEffect(flag);
}

void BinExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    expToCBuffer(buf, hgs, e1, precedence[op]);
    buf->writeByte(' ');
    buf->writestring(Token::toChars(op));
    buf->writeByte(' ');
    expToCBuffer(buf, hgs, e2, (enum PREC)(precedence[op] + 1));
}

int BinExp::isunsigned()
{
    return e1->type->isunsigned() || e2->type->isunsigned();
}

void BinExp::incompatibleTypes()
{
    error("incompatible types for ((%s) %s (%s)): '%s' and '%s'",
         e1->toChars(), Token::toChars(op), e2->toChars(),
         e1->type->toChars(), e2->type->toChars());
}

/************************************************************/

AssertExp::AssertExp(Loc loc, Expression *e, Expression *msg)
	: UnaExp(loc, TOKassert, sizeof(AssertExp), e)
{
    this->msg = msg;
}

Expression *AssertExp::syntaxCopy()
{
    AssertExp *ae = new AssertExp(loc, e1->syntaxCopy(),
				       msg ? msg->syntaxCopy() : NULL);
    return ae;
}

Expression *AssertExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("AssertExp::semantic('%s')\n", toChars());
#endif
    UnaExp::semantic(sc);
    e1 = resolveProperties(sc, e1);
    // BUG: see if we can do compile time elimination of the Assert
    e1 = e1->optimize(WANTvalue);
    e1 = e1->checkToBoolean();
    if (msg)
    {
	msg = msg->semantic(sc);
	msg = resolveProperties(sc, msg);
	msg = msg->implicitCastTo(Type::tchar->arrayOf());
	msg = msg->optimize(WANTvalue);
    }
    if (e1->isBool(FALSE))
    {
	FuncDeclaration *fd = sc->parent->isFuncDeclaration();
	fd->hasReturnExp |= 4;

	if (!global.params.useAssert)
	{   Expression *e = new HaltExp(loc);
	    e = e->semantic(sc);
	    return e;
	}
    }
    type = Type::tvoid;
    return this;
}

void AssertExp::checkSideEffect(int flag)
{
}

void AssertExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("assert(");
    expToCBuffer(buf, hgs, e1, PREC_assign);
    if (msg)
    {
	buf->writeByte(',');
	expToCBuffer(buf, hgs, msg, PREC_assign);
    }
    buf->writeByte(')');
}

/************************************************************/

DotIdExp::DotIdExp(Loc loc, Expression *e, Identifier *ident)
	: UnaExp(loc, TOKdot, sizeof(DotIdExp), e)
{
    this->ident = ident;
}

Expression *DotIdExp::semantic(Scope *sc)
{   Expression *e;
    Expression *eleft;
    Expression *eright;

#if LOGSEMANTIC
    printf("DotIdExp::semantic(this = %p, '%s')\n", this, toChars());
    //printf("e1->op = %d, '%s'\n", e1->op, Token::toChars(e1->op));
#endif

//{ static int z; fflush(stdout); if (++z == 10) *(char*)0=0; }

    /* Special case: rewrite this.id and super.id
     * to be classtype.id and baseclasstype.id
     * if we have no this pointer.
     */
    if ((e1->op == TOKthis || e1->op == TOKsuper) && !hasThis(sc))
    {	ClassDeclaration *cd;
	StructDeclaration *sd;
	AggregateDeclaration *ad;

	ad = sc->getStructClassScope();
	if (ad)
	{
	    cd = ad->isClassDeclaration();
	    if (cd)
	    {
		if (e1->op == TOKthis)
		{
		    e = new TypeDotIdExp(loc, cd->type, ident);
		    return e->semantic(sc);
		}
		else if (cd->baseClass && e1->op == TOKsuper)
		{
		    e = new TypeDotIdExp(loc, cd->baseClass->type, ident);
		    return e->semantic(sc);
		}
	    }
	    else
	    {
		sd = ad->isStructDeclaration();
		if (sd)
		{
		    if (e1->op == TOKthis)
		    {
			e = new TypeDotIdExp(loc, sd->type, ident);
			return e->semantic(sc);
		    }
		}
	    }
	}
    }

    UnaExp::semantic(sc);

    e1 = resolveProperties(sc, e1);

    if (e1->op == TOKdotexp)
    {
	DotExp *de = (DotExp *)e1;
	eleft = de->e1;
	eright = de->e2;
    }
    else
    {
	eleft = NULL;
	eright = e1;
    }
    if (eright->op == TOKimport)	// also used for template alias's
    {
	Dsymbol *s;
	ScopeExp *ie = (ScopeExp *)eright;

	s = ie->sds->search(ident, 0);
	if (s)
	{
	    s = s->toAlias();
	    checkDeprecated(sc, s);

	    EnumMember *em = s->isEnumMember();
	    if (em)
	    {
		e = em->value;
		e = e->semantic(sc);
		return e;
	    }

	    VarDeclaration *v = s->isVarDeclaration();
	    if (v)
	    {
		//printf("DotIdExp:: Identifier '%s' is a variable, type '%s'\n", toChars(), v->type->toChars());
		if (v->inuse)
		{
		    error("circular reference to '%s'", v->toChars());
		    type = Type::tint32;
		    return this;
		}
		type = v->type;
		if (v->isConst())
		{
		    if (v->init)
		    {
			ExpInitializer *ei = v->init->isExpInitializer();
			if (ei)
			{
    //printf("\tei: %p (%s)\n", ei->exp, ei->exp->toChars());
    //ei->exp = ei->exp->semantic(sc);
			    if (ei->exp->type == type)
			    {
				e = ei->exp->copy();	// make copy so we can change loc
				e->loc = loc;
				return e;
			    }
			}
		    }
		    else if (type->isscalar())
		    {
			e = type->defaultInit();
			e->loc = loc;
			return e;
		    }
		}
		if (v->needThis())
		{
		    if (!eleft)
			eleft = new ThisExp(loc);
		    e = new DotVarExp(loc, eleft, v);
		    e = e->semantic(sc);
		}
		else
		{
		    e = new VarExp(loc, v);
		    if (eleft)
		    {	e = new CommaExp(loc, eleft, e);
			e->type = v->type;
		    }
		}
		return e->deref();
	    }

	    FuncDeclaration *f = s->isFuncDeclaration();
	    if (f)
	    {
		//printf("it's a function\n");
		if (f->needThis())
		{
		    if (!eleft)
			eleft = new ThisExp(loc);
		    e = new DotVarExp(loc, eleft, f);
		    e = e->semantic(sc);
		}
		else
		{
		    e = new VarExp(loc, f);
		    if (eleft)
		    {	e = new CommaExp(loc, eleft, e);
			e->type = f->type;
		    }
		}
		return e;
	    }

	    ScopeDsymbol *sds = s->isScopeDsymbol();
	    if (sds)
	    {
		//printf("it's a ScopeDsymbol\n");
		e = new ScopeExp(loc, sds);
		e = e->semantic(sc);
		if (eleft)
		    e = new DotExp(loc, eleft, e);
		return e;
	    }

	    Import *imp = s->isImport();
	    if (imp)
	    {
		ScopeExp *ie;

		ie = new ScopeExp(loc, imp->pkg);
		return ie->semantic(sc);
	    }

	    Type *t = s->getType();
	    if (t)
	    {
		return new TypeExp(loc, t);
	    }

	    // BUG: handle other cases like in IdentifierExp::semantic()
#ifdef DEBUG
	    printf("s = '%s', kind = '%s'\n", s->toChars(), s->kind());
#endif
	    assert(0);
	}
	error("undefined identifier %s", toChars());
	type = Type::tvoid;
	return this;
    }
    else if (e1->type->ty == Tpointer &&
	     ident != Id::init && ident != Id::__sizeof &&
	     ident != Id::alignof && ident != Id::offsetof &&
	     ident != Id::mangleof)
    {
	e = new PtrExp(loc, e1);
	e->type = e1->type->next;
	return e->type->dotExp(sc, e, ident);
    }
    else
    {
	e = e1->type->dotExp(sc, e1, ident);
	e = e->semantic(sc);
	return e;
    }
}

void DotIdExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    //printf("DotIdExp::toCBuffer()\n");
    expToCBuffer(buf, hgs, e1, PREC_primary);
    buf->writeByte('.');
    buf->writestring(ident->toChars());
}

/************************************************************/

DotVarExp::DotVarExp(Loc loc, Expression *e, Declaration *v)
	: UnaExp(loc, TOKdotvar, sizeof(DotVarExp), e)
{
    //printf("DotVarExp()\n");
    this->var = v;
}

Expression *DotVarExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("DotVarExp::semantic('%s')\n", toChars());
#endif
    if (!type)
    {
	e1 = e1->semantic(sc);
	var = var->toAlias()->isDeclaration();
	type = var->type;
	if (!type && global.errors)
	{   // var is goofed up, just return 0
	    return new IntegerExp(0);
	}
	assert(type);

	if (!var->isFuncDeclaration())	// for functions, do checks after overload resolution
	{
	    AggregateDeclaration *ad = var->toParent()->isAggregateDeclaration();
	L1:
	    Type *t = e1->type;

	    if (ad &&
		!(t->ty == Tpointer && t->next->ty == Tstruct &&
		  ((TypeStruct *)t->next)->sym == ad)
		&&
		!(t->ty == Tstruct &&
		  ((TypeStruct *)t)->sym == ad)
	       )
	    {
		ClassDeclaration *cd = ad->isClassDeclaration();
		ClassDeclaration *tcd = t->isClassHandle();

		if (!cd || !tcd ||
		    !(tcd == cd || cd->isBaseOf(tcd, NULL))
		   )
		{
		    if (tcd && tcd->isNested())
		    {	// Try again with outer scope

			e1 = new DotVarExp(loc, e1, tcd->vthis);
			e1 = e1->semantic(sc);

			// Skip over nested functions, and get the enclosing
			// class type.
			Dsymbol *s = tcd->toParent();
			while (s && s->isFuncDeclaration())
			    s = s->toParent();
			if (s && s->isClassDeclaration())
			    e1->type = s->isClassDeclaration()->type;

			goto L1;
		    }
		    error("this for %s needs to be type %s not type %s",
			var->toChars(), ad->toChars(), t->toChars());
		}
	    }
	    accessCheck(loc, sc, e1, var);
	}
    }
    //printf("-DotVarExp::semantic('%s')\n", toChars());
    return this;
}

Expression *DotVarExp::toLvalue(Expression *e)
{
    //printf("DotVarExp::toLvalue(%s)\n", toChars());
    return this;
}

Expression *DotVarExp::modifiableLvalue(Scope *sc, Expression *e)
{
    //printf("DotVarExp::modifiableLvalue(%s)\n", toChars());

    if (var->isCtorinit())
    {	// It's only modifiable if inside the right constructor
	if (sc->func &&
	    ((sc->func->isCtorDeclaration() && var->storage_class & STCfield) ||
	     (sc->func->isStaticCtorDeclaration() && !(var->storage_class & STCfield))) &&
	    sc->func->toParent() == var->toParent() &&
	    e1->op == TOKthis
	   )
	{
	    VarDeclaration *v = var->isVarDeclaration();
	    assert(v);
	    v->ctorinit = 1;
	    //printf("setting ctorinit\n");
	}
	else
	{
	    error("can only initialize const %s inside constructor", var->toChars());
	}
    }
    return this;
}

void DotVarExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    expToCBuffer(buf, hgs, e1, PREC_primary);
    buf->writeByte('.');
    buf->writestring(var->toChars());
}

/************************************************************/

/* Things like:
 *	foo.bar!(args)
 */

DotTemplateInstanceExp::DotTemplateInstanceExp(Loc loc, Expression *e, TemplateInstance *ti)
	: UnaExp(loc, TOKdotti, sizeof(DotTemplateInstanceExp), e)
{
    //printf("DotTemplateInstanceExp()\n");
    this->ti = ti;
}

Expression *DotTemplateInstanceExp::syntaxCopy()
{
    DotTemplateInstanceExp *de = new DotTemplateInstanceExp(loc,
	e1->syntaxCopy(),
	(TemplateInstance *)ti->syntaxCopy(NULL));
    return de;
}

Expression *DotTemplateInstanceExp::semantic(Scope *sc)
{   Dsymbol *s;
    Dsymbol *s2;
    TemplateDeclaration *td;
    Expression *e;
    Identifier *id;
    Type *t1;
    Expression *eleft = NULL;
    Expression *eright;

#if LOGSEMANTIC
    printf("DotTemplateInstanceExp::semantic('%s')\n", toChars());
#endif
    //e1->print();
    //print();
    e1 = e1->semantic(sc);
    t1 = e1->type;
    if (t1)
	t1 = t1->toBasetype();
    //t1->print();
    if (e1->op == TOKdotexp)
    {	DotExp *de = (DotExp *)e1;
	eleft = de->e1;
	eright = de->e2;
    }
    else
    {	eleft = NULL;
	eright = e1;
    }
    if (eright->op == TOKimport)
    {
	s = ((ScopeExp *)eright)->sds;
    }
    else if (e1->op == TOKtype)
    {
	s = t1->isClassHandle();
	if (!s)
	    goto L1;
    }
    else if (t1 && (t1->ty == Tstruct || t1->ty == Tclass))
    {
	s = t1->toDsymbol(sc);
	eleft = e1;
    }
    else if (t1 && t1->ty == Tpointer)
    {
	t1 = t1->next->toBasetype();
	if (t1->ty != Tstruct)
	    goto L1;
	s = t1->toDsymbol(sc);
	eleft = e1;
    }
    else
    {
      L1:
	error("template %s is not a member of %s", ti->toChars(), e1->toChars());
	goto Lerr;
    }

    assert(s);
    id = (Identifier *)ti->idents.data[0];
    s2 = s->search(id, 0);
    if (!s2)
    {	error("template identifier %s is not a member of %s", id->toChars(), s->ident->toChars());
	goto Lerr;
    }
    s = s2;
    s->semantic(sc);
    s = s->toAlias();
    td = s->isTemplateDeclaration();
    if (!td)
    {
	error("%s is not a template", id->toChars());
	goto Lerr;
    }
    if (global.errors)
	goto Lerr;

    ti->tempdecl = td;

    if (eleft)
    {	Declaration *v;

	ti->semantic(sc);
	s = ti->inst->toAlias();
	v = s->isDeclaration();
	if (v)
	{   e = new DotVarExp(loc, eleft, v);
	    e = e->semantic(sc);
	    return e;
	}
    }

    e = new ScopeExp(loc, ti);
    if (eleft)
    {
	e = new DotExp(loc, eleft, e);
    }
    e = e->semantic(sc);
    return e;

Lerr:
    return new IntegerExp(0);
}

void DotTemplateInstanceExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    expToCBuffer(buf, hgs, e1, PREC_primary);
    buf->writeByte('.');
    ti->toCBuffer(buf, hgs);
}

/************************************************************/

DelegateExp::DelegateExp(Loc loc, Expression *e, FuncDeclaration *f)
	: UnaExp(loc, TOKdelegate, sizeof(DelegateExp), e)
{
    this->func = f;
}

Expression *DelegateExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("DelegateExp::semantic('%s')\n", toChars());
#endif
    if (!type)
    {
	e1 = e1->semantic(sc);
	type = new TypeDelegate(func->type);
	type = type->semantic(loc, sc);
//-----------------
	/* For func, we need to get the
	 * right 'this' pointer if func is in an outer class, but our
	 * existing 'this' pointer is in an inner class.
	 * This code is analogous to that used for variables
	 * in DotVarExp::semantic().
	 */
	AggregateDeclaration *ad = func->toParent()->isAggregateDeclaration();
    L10:
	Type *t = e1->type;
	if (func->needThis() && ad &&
	    !(t->ty == Tpointer && t->next->ty == Tstruct &&
	      ((TypeStruct *)t->next)->sym == ad) &&
	    !(t->ty == Tstruct && ((TypeStruct *)t)->sym == ad)
	   )
	{
	    ClassDeclaration *cd = ad->isClassDeclaration();
	    ClassDeclaration *tcd = t->isClassHandle();

	    if (!cd || !tcd ||
		!(tcd == cd || cd->isBaseOf(tcd, NULL))
	       )
	    {
		if (tcd && tcd->isNested())
		{   // Try again with outer scope

		    e1 = new DotVarExp(loc, e1, tcd->vthis);
		    e1 = e1->semantic(sc);
		    goto L10;
		}
		error("this for %s needs to be type %s not type %s",
		    func->toChars(), ad->toChars(), t->toChars());
	    }
	}
//-----------------
    }
    return this;
}

void DelegateExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writeByte('&');
    if (!func->isNested())
    {
	expToCBuffer(buf, hgs, e1, PREC_primary);
	buf->writeByte('.');
    }
    buf->writestring(func->toChars());
}

/************************************************************/

DotTypeExp::DotTypeExp(Loc loc, Expression *e, Dsymbol *s)
	: UnaExp(loc, TOKdottype, sizeof(DotTypeExp), e)
{
    this->sym = s;
    this->type = s->getType();
}

Expression *DotTypeExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("DotTypeExp::semantic('%s')\n", toChars());
#endif
    UnaExp::semantic(sc);
    return this;
}

void DotTypeExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    expToCBuffer(buf, hgs, e1, PREC_primary);
    buf->writeByte('.');
    buf->writestring(sym->toChars());
}

/************************************************************/

CallExp::CallExp(Loc loc, Expression *e, Expressions *arguments)
	: UnaExp(loc, TOKcall, sizeof(CallExp), e)
{
    this->arguments = arguments;
}

CallExp::CallExp(Loc loc, Expression *e)
	: UnaExp(loc, TOKcall, sizeof(CallExp), e)
{
    this->arguments = NULL;
}

CallExp::CallExp(Loc loc, Expression *e, Expression *earg1)
	: UnaExp(loc, TOKcall, sizeof(CallExp), e)
{
    Expressions *arguments = new Expressions();
    arguments->setDim(1);
    arguments->data[0] = (void *)earg1;

    this->arguments = arguments;
}

CallExp::CallExp(Loc loc, Expression *e, Expression *earg1, Expression *earg2)
	: UnaExp(loc, TOKcall, sizeof(CallExp), e)
{
    Expressions *arguments = new Expressions();
    arguments->setDim(2);
    arguments->data[0] = (void *)earg1;
    arguments->data[1] = (void *)earg2;

    this->arguments = arguments;
}

Expression *CallExp::syntaxCopy()
{
    return new CallExp(loc, e1->syntaxCopy(), arraySyntaxCopy(arguments));
}


Expression *CallExp::semantic(Scope *sc)
{
    TypeFunction *tf;
    FuncDeclaration *f;
    int i;
    Type *t1;

#if LOGSEMANTIC
    printf("CallExp::semantic('%s')\n", toChars());
#endif
    if (type)
	return this;		// semantic() already run
#if 0
    if (arguments && arguments->dim)
    {
	Expression *earg = (Expression *)arguments->data[0];
	earg->print();
	if (earg->type) earg->type->print();
    }
#endif

    /* Transform:
     *	array.id(args) into id(array,args)
     *	aa.remove(arg) into delete aa[arg]
     */
    if (e1->op == TOKdot)
    {
	// BUG: we should handle array.a.b.c.e(args) too

	DotIdExp *dotid = (DotIdExp *)(e1);
	dotid->e1 = dotid->e1->semantic(sc);
	assert(dotid->e1);
	if (dotid->e1->type)
	{
	    TY e1ty = dotid->e1->type->toBasetype()->ty;
	    if (e1ty == Taarray && dotid->ident == Id::remove)
	    {
		if (!arguments || arguments->dim != 1)
		{   error("expected key as argument to aa.remove()");
		    goto Lagain;
		}
		Expression *key = (Expression *)arguments->data[0];
		key = key->semantic(sc);
		key = resolveProperties(sc, key);
		key->rvalue();

		TypeAArray *taa = (TypeAArray *)dotid->e1->type->toBasetype();
		key = key->implicitCastTo(taa->index);
		key = key->implicitCastTo(taa->key);

		return new RemoveExp(loc, dotid->e1, key);
	    }
	    else if (e1ty == Tarray || e1ty == Tsarray || e1ty == Taarray)
	    {
		if (!arguments)
		    arguments = new Expressions();
		arguments->shift(dotid->e1);
		e1 = new IdentifierExp(dotid->loc, dotid->ident);
	    }
	}
    }

Lagain:
    f = NULL;
    if (e1->op == TOKthis || e1->op == TOKsuper)
    {
	// semantic() run later for these
    }
    else
    {
	UnaExp::semantic(sc);
	if (e1->op == TOKimport)
	{   // Perhaps this should be moved to ScopeExp::semantic()
	    ScopeExp *se = (ScopeExp *)e1;
	    e1 = new DsymbolExp(loc, se->sds);
	    e1 = e1->semantic(sc);
	}
    }

    if (e1->op == TOKcomma)
    {
	CommaExp *ce = (CommaExp *)e1;

	e1 = ce->e2;
	e1->type = ce->type;
	ce->e2 = this;
	ce->type = NULL;
	return ce->semantic(sc);
    }

    t1 = NULL;
    if (e1->type)
	t1 = e1->type->toBasetype();

    // Check for call operator overload
    if (t1)
    {	AggregateDeclaration *ad;
	FuncDeclaration *fd;

	if (t1->ty == Tclass)
	{
	    ad = ((TypeClass *)t1)->sym;
	    goto L1;
	}
	else if (t1->ty == Tstruct)
	{
	    ad = ((TypeStruct *)t1)->sym;
	L1:
//	    fd = search_function(ad, Id::call);
//	    if (fd)
	    {
		// Rewrite as e1.call(arguments)
		Expression *e = new DotIdExp(loc, e1, Id::call);
		e = new CallExp(loc, e, arguments);
		e = e->semantic(sc);
		return e;
	    }
	}
    }

    arrayExpressionSemantic(arguments, sc);
    preFunctionArguments(loc, sc, arguments);

    if (e1->op == TOKdotvar && t1->ty == Tfunction)
    {
	// Do overload resolution
	DotVarExp *dve = (DotVarExp *)(e1);

	f = dve->var->isFuncDeclaration();
	assert(f);
	f = f->overloadResolve(loc, arguments);

	/* Now that we have the right function f, we need to get the
	 * right 'this' pointer if f is in an outer class, but our
	 * existing 'this' pointer is in an inner class.
	 * This code is analogous to that used for variables
	 * in DotVarExp::semantic().
	 */
	AggregateDeclaration *ad = f->toParent()->isAggregateDeclaration();
    L10:
	Type *t = dve->e1->type;
	if (f->needThis() && ad &&
	    !(t->ty == Tpointer && t->next->ty == Tstruct &&
	      ((TypeStruct *)t->next)->sym == ad) &&
	    !(t->ty == Tstruct && ((TypeStruct *)t)->sym == ad)
	   )
	{
	    ClassDeclaration *cd = ad->isClassDeclaration();
	    ClassDeclaration *tcd = t->isClassHandle();

	    if (!cd || !tcd ||
		!(tcd == cd || cd->isBaseOf(tcd, NULL))
	       )
	    {
		if (tcd && tcd->isNested())
		{   // Try again with outer scope

		    dve->e1 = new DotVarExp(loc, dve->e1, tcd->vthis);
		    dve->e1 = dve->e1->semantic(sc);
		    goto L10;
		}
		error("this for %s needs to be type %s not type %s",
		    f->toChars(), ad->toChars(), t->toChars());
	    }
	}

	checkDeprecated(sc, f);
	accessCheck(loc, sc, dve->e1, f);
	if (!f->needThis())
	{
	    VarExp *ve = new VarExp(loc, f);
	    e1 = new CommaExp(loc, dve->e1, ve);
	    e1->type = f->type;
	}
	else
	{
	    dve->var = f;
	    e1->type = f->type;

	    // See if we need to adjust the 'this' pointer
	    AggregateDeclaration *ad = f->isThis();
	    ClassDeclaration *cd = dve->e1->type->isClassHandle();
	    if (ad && cd && ad->isClassDeclaration() && ad != cd &&
		dve->e1->op != TOKsuper)
	    {
		dve->e1 = dve->e1->castTo(ad->type); //new CastExp(loc, dve->e1, ad->type);
		dve->e1 = dve->e1->semantic(sc);
	    }
	}
	t1 = e1->type;
    }
    else if (e1->op == TOKsuper)
    {
	// Base class constructor call
	ClassDeclaration *cd = NULL;

	if (sc->func)
	    cd = sc->func->toParent()->isClassDeclaration();
	if (!cd || !cd->baseClass || !sc->func->isCtorDeclaration())
	{
	    error("super class constructor call must be in a constructor");
	    type = Type::terror;
	    return this;
	}
	else
	{
	    f = cd->baseClass->ctor;
	    if (!f)
	    {	error("no super class constructor for %s", cd->baseClass->toChars());
		type = Type::terror;
		return this;
	    }
	    else
	    {
#if 0
		if (sc->callSuper & (CSXthis | CSXsuper))
		    error("reference to this before super()");
#endif
		if (sc->noctor || sc->callSuper & CSXlabel)
		    error("constructor calls not allowed in loops or after labels");
		if (sc->callSuper & (CSXsuper_ctor | CSXthis_ctor))
		    error("multiple constructor calls");
		sc->callSuper |= CSXany_ctor | CSXsuper_ctor;

		f = f->overloadResolve(loc, arguments);
		checkDeprecated(sc, f);
		e1 = new DotVarExp(e1->loc, e1, f);
		e1 = e1->semantic(sc);
		t1 = e1->type;
	    }
	}
    }
    else if (e1->op == TOKthis)
    {
	// same class constructor call
	ClassDeclaration *cd = NULL;

	if (sc->func)
	    cd = sc->func->toParent()->isClassDeclaration();
	if (!cd || !sc->func->isCtorDeclaration())
	{
	    error("class constructor call must be in a constructor");
	    type = Type::terror;
	    return this;
	}
	else
	{
#if 0
	    if (sc->callSuper & (CSXthis | CSXsuper))
		error("reference to this before super()");
#endif
	    if (sc->noctor || sc->callSuper & CSXlabel)
		error("constructor calls not allowed in loops or after labels");
	    if (sc->callSuper & (CSXsuper_ctor | CSXthis_ctor))
		error("multiple constructor calls");
	    sc->callSuper |= CSXany_ctor | CSXthis_ctor;

	    f = cd->ctor;
	    f = f->overloadResolve(loc, arguments);
	    checkDeprecated(sc, f);
	    e1 = new DotVarExp(e1->loc, e1, f);
	    e1 = e1->semantic(sc);
	    t1 = e1->type;

	    // BUG: this should really be done by checking the static
	    // call graph
	    if (f == sc->func)
		error("cyclic constructor call");
	}
    }
    else if (!t1)
    {
	error("function expected before (), not '%s'", e1->toChars());
	type = Type::terror;
	return this;
    }
    else if (t1->ty != Tfunction)
    {
	if (t1->ty == Tdelegate)
	{
	    assert(t1->next->ty == Tfunction);
	    tf = (TypeFunction *)(t1->next);
	    goto Lcheckargs;
	}
	else if (t1->ty == Tpointer && t1->next->ty == Tfunction)
	{   Expression *e;

	    e = new PtrExp(loc, e1);
	    t1 = t1->next;
	    e->type = t1;
	    e1 = e;
	}
	else if (e1->op == TOKtemplate)
	{
	    TemplateExp *te = (TemplateExp *)e1;
	    f = te->td->deduce(sc, loc, NULL, arguments);
	    if (!f)
	    {	type = Type::terror;
		return this;
	    }
	    e1 = new VarExp(loc, f);
	    goto Lagain;
	}
	else
	{   error("function expected before (), not %s of type %s", e1->toChars(), e1->type->toChars());
	    type = Type::terror;
	    return this;
	}
    }
    else if (e1->op == TOKvar)
    {
	// Do overload resolution
	VarExp *ve = (VarExp *)e1;

	f = ve->var->isFuncDeclaration();
	assert(f);
	f = f->overloadResolve(loc, arguments);
	checkDeprecated(sc, f);

	if (f->needThis() && hasThis(sc))
	{
	    // Supply an implicit 'this', as in
	    //	  this.ident

	    e1 = new DotVarExp(loc, new ThisExp(loc), f);
	    goto Lagain;
	}

	ve->var = f;
	ve->type = f->type;
	t1 = f->type;
    }
    assert(t1->ty == Tfunction);
    tf = (TypeFunction *)(t1);

Lcheckargs:
    assert(tf->ty == Tfunction);
    type = tf->next;

    if (!arguments)
	arguments = new Expressions();
    functionArguments(loc, sc, tf, arguments);

    assert(type);

    if (f && f->tintro)
    {
	Type *t = type;
	int offset = 0;

	if (f->tintro->next->isBaseOf(t, &offset) && offset)
	{
	    type = f->tintro->next;
	    return castTo(t);
	}
    }

    return this;
}

void CallExp::checkSideEffect(int flag)
{
}

void CallExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{   int i;

    expToCBuffer(buf, hgs, e1, precedence[op]);
    buf->writeByte('(');
    argsToCBuffer(buf, arguments, hgs);
    buf->writeByte(')');
}


/************************************************************/

AddrExp::AddrExp(Loc loc, Expression *e)
	: UnaExp(loc, TOKaddress, sizeof(AddrExp), e)
{
}

Expression *AddrExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("AddrExp::semantic('%s')\n", toChars());
#endif
    if (!type)
    {
	UnaExp::semantic(sc);
	e1 = e1->toLvalue(NULL);
	if (!e1->type)
	{
	    error("cannot take address of %s", e1->toChars());
	    type = Type::tint32;
	    return this;
	}
	type = e1->type->pointerTo();

	// See if this should really be a delegate
	if (e1->op == TOKdotvar)
	{
	    DotVarExp *dve = (DotVarExp *)e1;
	    FuncDeclaration *f = dve->var->isFuncDeclaration();

	    if (f)
	    {	Expression *e;

		e = new DelegateExp(loc, dve->e1, f);
		e = e->semantic(sc);
		return e;
	    }
	}
	else if (e1->op == TOKvar)
	{
	    VarExp *dve = (VarExp *)e1;
	    FuncDeclaration *f = dve->var->isFuncDeclaration();

	    if (f && f->isNested())
	    {	Expression *e;

		e = new DelegateExp(loc, e1, f);
		e = e->semantic(sc);
		return e;
	    }
	}
	else if (e1->op == TOKarray)
	{
	    if (e1->type->toBasetype()->ty == Tbit)
		error("cannot take address of bit in array");
	}
	return optimize(WANTvalue);
    }
    return this;
}

/************************************************************/

PtrExp::PtrExp(Loc loc, Expression *e)
	: UnaExp(loc, TOKstar, sizeof(PtrExp), e)
{
    if (e->type)
	type = e->type->next;
}

PtrExp::PtrExp(Loc loc, Expression *e, Type *t)
	: UnaExp(loc, TOKstar, sizeof(PtrExp), e)
{
    type = t;
}

Expression *PtrExp::semantic(Scope *sc)
{   Type *tb;

#if LOGSEMANTIC
    printf("PtrExp::semantic('%s')\n", toChars());
#endif
    UnaExp::semantic(sc);
    e1 = resolveProperties(sc, e1);
    if (type)
	return this;
    if (!e1->type)
	printf("PtrExp::semantic('%s')\n", toChars());
    tb = e1->type->toBasetype();
    switch (tb->ty)
    {
	case Tpointer:
	    type = tb->next;
	    if (type->isbit())
	    {	Expression *e;

		// Rewrite *p as p[0]
		e = new IndexExp(loc, e1, new IntegerExp(0));
		return e->semantic(sc);
	    }
	    break;

	case Tsarray:
	case Tarray:
	    type = tb->next;
	    e1 = e1->castTo(type->pointerTo());
	    break;

	default:
	    error("can only * a pointer, not a '%s'", e1->type->toChars());
	    type = Type::tint32;
	    break;
    }
    rvalue();
    return this;
}

Expression *PtrExp::toLvalue(Expression *e)
{
#if 0
    tym = tybasic(e1->ET->Tty);
    if (!(tyscalar(tym) ||
	  tym == TYstruct ||
	  tym == TYarray && e->Eoper == TOKaddr))
	    synerr(EM_lvalue);	// lvalue expected
#endif
    return this;
}

void PtrExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writeByte('*');
    expToCBuffer(buf, hgs, e1, precedence[op]);
}

/************************************************************/

NegExp::NegExp(Loc loc, Expression *e)
	: UnaExp(loc, TOKneg, sizeof(NegExp), e)
{
}

Expression *NegExp::semantic(Scope *sc)
{   Expression *e;

#if LOGSEMANTIC
    printf("NegExp::semantic('%s')\n", toChars());
#endif
    if (!type)
    {
	UnaExp::semantic(sc);
	e1 = resolveProperties(sc, e1);
	e = op_overload(sc);
	if (e)
	    return e;

	e1->checkNoBool();
	e1->checkArithmetic();
	type = e1->type;
    }
    return this;
}

/************************************************************/

UAddExp::UAddExp(Loc loc, Expression *e)
	: UnaExp(loc, TOKuadd, sizeof(UAddExp), e)
{
}

Expression *UAddExp::semantic(Scope *sc)
{   Expression *e;

#if LOGSEMANTIC
    printf("UAddExp::semantic('%s')\n", toChars());
#endif
    assert(!type);
    UnaExp::semantic(sc);
    e1 = resolveProperties(sc, e1);
    e = op_overload(sc);
    if (e)
	return e;
    e1->checkNoBool();
    e1->checkArithmetic();
    return e1;
}

/************************************************************/

ComExp::ComExp(Loc loc, Expression *e)
	: UnaExp(loc, TOKtilde, sizeof(ComExp), e)
{
}

Expression *ComExp::semantic(Scope *sc)
{   Expression *e;

    if (!type)
    {
	UnaExp::semantic(sc);
	e1 = resolveProperties(sc, e1);
	e = op_overload(sc);
	if (e)
	    return e;

	e1->checkNoBool();
	e1 = e1->checkIntegral();
	type = e1->type;
    }
    return this;
}

/************************************************************/

NotExp::NotExp(Loc loc, Expression *e)
	: UnaExp(loc, TOKnot, sizeof(NotExp), e)
{
}

Expression *NotExp::semantic(Scope *sc)
{
    UnaExp::semantic(sc);
    e1 = resolveProperties(sc, e1);
    e1 = e1->checkToBoolean();
    type = Type::tboolean;
    return this;
}

int NotExp::isBit()
{
    return TRUE;
}



/************************************************************/

BoolExp::BoolExp(Loc loc, Expression *e, Type *t)
	: UnaExp(loc, TOKtobool, sizeof(BoolExp), e)
{
    type = t;
}

Expression *BoolExp::semantic(Scope *sc)
{
    UnaExp::semantic(sc);
    e1 = resolveProperties(sc, e1);
    e1 = e1->checkToBoolean();
    type = Type::tboolean;
    return this;
}

int BoolExp::isBit()
{
    return TRUE;
}

/************************************************************/

DeleteExp::DeleteExp(Loc loc, Expression *e)
	: UnaExp(loc, TOKdelete, sizeof(DeleteExp), e)
{
}

Expression *DeleteExp::semantic(Scope *sc)
{
    Type *tb;

    UnaExp::semantic(sc);
    e1 = resolveProperties(sc, e1);
    e1 = e1->toLvalue(NULL);
    type = Type::tvoid;

    tb = e1->type->toBasetype();
    switch (tb->ty)
    {	case Tclass:
	{   TypeClass *tc = (TypeClass *)tb;
	    ClassDeclaration *cd = tc->sym;

	    if (cd->isInterfaceDeclaration() && cd->isCOMclass())
		error("cannot delete instance of COM interface %s", cd->toChars());
	    break;
	}
	case Tpointer:
	    tb = tb->next->toBasetype();
	    if (tb->ty == Tstruct)
	    {
		TypeStruct *ts = (TypeStruct *)tb;
		StructDeclaration *sd = ts->sym;
		FuncDeclaration *f = sd->aggDelete;

		if (f)
		{
		    Expression *e;
		    Expression *ec;
		    Type *tpv = Type::tvoid->pointerTo();

		    e = e1;
		    e->type = tpv;
		    ec = new VarExp(loc, f);
		    e = new CallExp(loc, ec, e);
		    return e->semantic(sc);
		}
	    }
	    break;

	case Tarray:
	    break;

	default:
	    if (e1->op == TOKindex)
	    {
		IndexExp *ae = (IndexExp *)(e1);
		Type *tb1 = ae->e1->type->toBasetype();
		if (tb1->ty == Taarray)
		    break;
	    }
	    error("cannot delete type %s", e1->type->toChars());
	    break;
    }

    if (e1->op == TOKindex)
    {
	IndexExp *ae = (IndexExp *)(e1);
	Type *tb1 = ae->e1->type->toBasetype();
	if (tb1->ty == Taarray)
	{   if (!global.params.useDeprecated)
		error("delete aa[key] deprecated, use aa.remove(key)");
	}
    }

    return this;
}

void DeleteExp::checkSideEffect(int flag)
{
}

Expression *DeleteExp::checkToBoolean()
{
    error("delete does not give a boolean result");
    return this;
}

void DeleteExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("delete ");
    expToCBuffer(buf, hgs, e1, precedence[op]);
}

/************************************************************/

CastExp::CastExp(Loc loc, Expression *e, Type *t)
	: UnaExp(loc, TOKcast, sizeof(CastExp), e)
{
    to = t;
}

Expression *CastExp::syntaxCopy()
{
    return new CastExp(loc, e1->syntaxCopy(), to->syntaxCopy());
}


Expression *CastExp::semantic(Scope *sc)
{   Expression *e;
    BinExp *b;
    UnaExp *u;

#if LOGSEMANTIC
    printf("CastExp::semantic('%s')\n", toChars());
#endif

//static int x; assert(++x < 10);

    if (type)
	return this;
    UnaExp::semantic(sc);
    e1 = resolveProperties(sc, e1);
    to = to->semantic(loc, sc);

    e = op_overload(sc);
    if (e)
    {
	return e->implicitCastTo(to);
    }
    return e1->castTo(to);
}

void CastExp::checkSideEffect(int flag)
{
    if (!to->equals(Type::tvoid) &&
	!(to->ty == Tclass && e1->op == TOKcall && e1->type->ty == Tclass))
	Expression::checkSideEffect(flag);
}

void CastExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("cast(");
    to->toCBuffer(buf, NULL, hgs);
    buf->writeByte(')');
    expToCBuffer(buf, hgs, e1, precedence[op]);
}


/************************************************************/

SliceExp::SliceExp(Loc loc, Expression *e1, Expression *lwr, Expression *upr)
	: UnaExp(loc, TOKslice, sizeof(SliceExp), e1)
{
    this->upr = upr;
    this->lwr = lwr;
    lengthVar = NULL;
}

Expression *SliceExp::syntaxCopy()
{
    Expression *lwr = NULL;
    if (this->lwr)
	lwr = this->lwr->syntaxCopy();

    Expression *upr = NULL;
    if (this->upr)
	upr = this->upr->syntaxCopy();

    return new SliceExp(loc, e1->syntaxCopy(), lwr, upr);
}

Expression *SliceExp::semantic(Scope *sc)
{   Expression *e;
    AggregateDeclaration *ad;
    FuncDeclaration *fd;
    ScopeDsymbol *sym;

#if LOGSEMANTIC
    printf("SliceExp::semantic('%s')\n", toChars());
#endif
    if (type)
	return this;

    UnaExp::semantic(sc);
    e1 = resolveProperties(sc, e1);

    e = this;

    Type *t = e1->type->toBasetype();
    if (t->ty == Tpointer)
    {
	if (!lwr || !upr)
	    error("need upper and lower bound to slice pointer");
    }
    else if (t->ty == Tarray)
    {
    }
    else if (t->ty == Tsarray)
    {
    }
    else if (t->ty == Tclass)
    {
        ad = ((TypeClass *)t)->sym;
        goto L1;
    }
    else if (t->ty == Tstruct)
    {
        ad = ((TypeStruct *)t)->sym;

    L1:
        fd = search_function(ad, Id::slice);
        if (fd)
        {
            // Rewrite as e1.slice(lwr, upr)
	    e = new DotIdExp(loc, e1, Id::slice);

	    if (lwr)
	    {
		assert(upr);
		e = new CallExp(loc, e, lwr, upr);
	    }
	    else
	    {	assert(!upr);
		e = new CallExp(loc, e);
	    }
	    e = e->semantic(sc);
	    return e;
        }
	goto Lerror;
    }
    else
	goto Lerror;

    if (t->ty == Tsarray || t->ty == Tarray)
    {
	sym = new ArrayScopeSymbol(this);
	sym->parent = sc->scopesym;
	sc = sc->push(sym);
    }

    if (lwr)
    {	lwr = lwr->semantic(sc);
	lwr = resolveProperties(sc, lwr);
	lwr = lwr->implicitCastTo(Type::tindex);
    }
    if (upr)
    {	upr = upr->semantic(sc);
	upr = resolveProperties(sc, upr);
	upr = upr->implicitCastTo(Type::tindex);
    }

    if (t->ty == Tsarray || t->ty == Tarray)
	sc->pop();

    type = t->next->arrayOf();
    return e;

Lerror:
    char *s;
    if (t->ty == Tvoid)
	s = e1->toChars();
    else
	s = t->toChars();
    error("%s cannot be sliced with []", s);
    type = Type::terror;
    return e;
}

void SliceExp::checkEscape()
{
    e1->checkEscape();
}

Expression *SliceExp::toLvalue(Expression *e)
{
    return this;
}

Expression *SliceExp::modifiableLvalue(Scope *sc, Expression *e)
{
    error("slice expression %s is not a modifiable lvalue", toChars());
    return this;
}

void SliceExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    expToCBuffer(buf, hgs, e1, precedence[op]);
    buf->writeByte('[');
    if (upr || lwr)
    {
	if (lwr)
	    expToCBuffer(buf, hgs, lwr, PREC_assign);
	else
	    buf->writeByte('0');
	buf->writestring("..");
	if (upr)
	    expToCBuffer(buf, hgs, upr, PREC_assign);
	else
	    buf->writestring("length");		// BUG: should be array.length
    }
    buf->writeByte(']');
}

/********************** ArrayLength **************************************/

ArrayLengthExp::ArrayLengthExp(Loc loc, Expression *e1)
	: UnaExp(loc, TOKarraylength, sizeof(ArrayLengthExp), e1)
{
}

Expression *ArrayLengthExp::semantic(Scope *sc)
{   Expression *e;

#if LOGSEMANTIC
    printf("ArrayLengthExp::semantic('%s')\n", toChars());
#endif
    if (!type)
    {
	UnaExp::semantic(sc);
	e1 = resolveProperties(sc, e1);

	type = Type::tindex;
    }
    return this;
}

void ArrayLengthExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    expToCBuffer(buf, hgs, e1, PREC_primary);
    buf->writestring(".length");
}

/*********************** ArrayExp *************************************/

// e1 [ i1, i2, i3, ... ]

ArrayExp::ArrayExp(Loc loc, Expression *e1, Expressions *args)
	: UnaExp(loc, TOKarray, sizeof(ArrayExp), e1)
{
    arguments = args;
}

Expression *ArrayExp::syntaxCopy()
{
    return new ArrayExp(loc, e1->syntaxCopy(), arraySyntaxCopy(arguments));
}

Expression *ArrayExp::semantic(Scope *sc)
{   Expression *e;
    Type *t1;

#if LOGSEMANTIC
    printf("ArrayExp::semantic('%s')\n", toChars());
#endif
    UnaExp::semantic(sc);
    e1 = resolveProperties(sc, e1);
    assert(arguments && arguments->dim);

    t1 = e1->type->toBasetype();
    if (t1->ty != Tclass && t1->ty != Tstruct)
    {	// Convert to IndexExp
	if (arguments->dim != 1)
	    error("only one index allowed to index %s", t1->toChars());
	e = new IndexExp(loc, e1, (Expression *)arguments->data[0]);
	return e->semantic(sc);
    }

    // Run semantic() on each argument
    for (int i = 0; i < arguments->dim; i++)
    {	e = (Expression *)arguments->data[i];

	e = e->semantic(sc);
	if (!e->type)
	    error("%s has no value", e->toChars());
	arguments->data[i] = (void *)e;
    }

    e = op_overload(sc);
    if (!e)
    {	error("no [] operator overload for type %s", e1->type->toChars());
	e = e1;
    }
    return e;
}


Expression *ArrayExp::toLvalue(Expression *e)
{
    if (type && type->toBasetype()->ty == Tvoid)
	error("voids have no value");
    return this;
}


void ArrayExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{   int i;

    expToCBuffer(buf, hgs, e1, PREC_primary);
    buf->writeByte('[');
    argsToCBuffer(buf, arguments, hgs);
    buf->writeByte(']');
}

/************************* DotExp ***********************************/

DotExp::DotExp(Loc loc, Expression *e1, Expression *e2)
	: BinExp(loc, TOKdotexp, sizeof(DotExp), e1, e2)
{
}

Expression *DotExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("DotExp::semantic('%s')\n", toChars());
#endif
    e1 = e1->semantic(sc);
    e2 = e2->semantic(sc);
    return this;
}


/************************* CommaExp ***********************************/

CommaExp::CommaExp(Loc loc, Expression *e1, Expression *e2)
	: BinExp(loc, TOKcomma, sizeof(CommaExp), e1, e2)
{
}

Expression *CommaExp::semantic(Scope *sc)
{
    if (!type)
    {	BinExp::semanticp(sc);
	type = e2->type;
    }
    return this;
}

void CommaExp::checkEscape()
{
    e2->checkEscape();
}

Expression *CommaExp::toLvalue(Expression *e)
{
    e2 = e2->toLvalue(NULL);
    return this;
}

Expression *CommaExp::modifiableLvalue(Scope *sc, Expression *e)
{
    e2 = e2->modifiableLvalue(sc, e);
    return this;
}

int CommaExp::isBool(int result)
{
    return e2->isBool(result);
}

void CommaExp::checkSideEffect(int flag)
{
    /* Don't check e1 until we cast(void) the a,b code generation */
    e2->checkSideEffect(flag);
}

/************************** IndexExp **********************************/

// e1 [ e2 ]

IndexExp::IndexExp(Loc loc, Expression *e1, Expression *e2)
	: BinExp(loc, TOKindex, sizeof(IndexExp), e1, e2)
{
    lengthVar = NULL;
    modifiable = 0;	// assume it is an rvalue
}

Expression *IndexExp::semantic(Scope *sc)
{   Expression *e;
    BinExp *b;
    UnaExp *u;
    Type *t1;
    ScopeDsymbol *sym;

#if LOGSEMANTIC
    printf("IndexExp::semantic('%s')\n", toChars());
#endif
    if (type)
	return this;
    assert(e1->type);		// semantic() should already be run on it
    e = this;

    // Note that unlike C we do not implement the int[ptr]

    t1 = e1->type->toBasetype();

    if (t1->ty == Tsarray || t1->ty == Tarray)
    {	// Create scope for 'length' variable
	sym = new ArrayScopeSymbol(this);
	sym->parent = sc->scopesym;
	sc = sc->push(sym);
    }

    e2 = e2->semantic(sc);
    if (!e2->type)
    {
	error("%s has no value", e2->toChars());
	e2->type = Type::terror;
    }
    e2 = resolveProperties(sc, e2);

    if (t1->ty == Tsarray || t1->ty == Tarray)
	sc = sc->pop();

    switch (t1->ty)
    {
	case Tpointer:
	case Tarray:
	    e2 = e2->implicitCastTo(Type::tindex);
	    e->type = t1->next;
	    break;

	case Tsarray:
	{
	    e2 = e2->implicitCastTo(Type::tindex);
	    if (t1->next->toBasetype()->ty == Tbit)
	    {
		e->type = t1->next;
		break;
	    }

	    TypeSArray *tsa = (TypeSArray *)t1;

#if 0 	// Don't do now, because it might be short-circuit evaluated
	    // Do compile time array bounds checking if possible
	    e2 = e2->optimize(WANTvalue);
	    if (e2->op == TOKint64)
	    {
		integer_t index = e2->toInteger();
		integer_t length = tsa->dim->toInteger();
		if (index < 0 || index >= length)
		    error("array index [%lld] is outside array bounds [0 .. %lld]",
			    index, length);
	    }
#endif
	    e->type = t1->next;
	    break;
	}

	case Taarray:
	{   TypeAArray *taa = (TypeAArray *)t1;

	    e2 = e2->implicitCastTo(taa->index);	// type checking
	    e2 = e2->implicitCastTo(taa->key);		// actual argument type
	    type = taa->next;
	    break;
	}

	default:
	    error("%s must be an array or pointer type, not %s",
		e1->toChars(), e1->type->toChars());
	    type = Type::tint32;
	    break;
    }
    return e;
}

Expression *IndexExp::toLvalue(Expression *e)
{
//    if (type && type->toBasetype()->ty == Tvoid)
//	error("voids have no value");
    return this;
}

Expression *IndexExp::modifiableLvalue(Scope *sc, Expression *e)
{
    modifiable = 1;
    if (e1->type->toBasetype()->ty == Taarray)
	e1 = e1->modifiableLvalue(sc, e1);
    return toLvalue(e);
}

void IndexExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    expToCBuffer(buf, hgs, e1, PREC_primary);
    buf->writeByte('[');
    expToCBuffer(buf, hgs, e2, PREC_assign);
    buf->writeByte(']');
}


/************************* PostIncExp ***********************************/

PostIncExp::PostIncExp(Loc loc, Expression *e)
	: BinExp(loc, TOKplusplus, sizeof(PostIncExp), e, new IntegerExp(loc, 1, Type::tint32))
{
}

Expression *PostIncExp::semantic(Scope *sc)
{   Expression *e = this;

    if (!type)
    {
	BinExp::semantic(sc);
	e2 = resolveProperties(sc, e2);

	e = op_overload(sc);
	if (e)
	    return e;

	e = this;
	e1 = e1->modifiableLvalue(sc, NULL);
	e1->checkScalar();
	e1->checkNoBool();
	if (e1->type->ty == Tpointer)
	    e = scaleFactor();
	else
	    e2 = e2->castTo(e1->type);
	e->type = e1->type;
    }
    return e;
}

void PostIncExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    expToCBuffer(buf, hgs, e1, precedence[op]);
    buf->writestring("++");
}

/************************************************************/

PostDecExp::PostDecExp(Loc loc, Expression *e)
	: BinExp(loc, TOKminusminus, sizeof(PostDecExp), e, new IntegerExp(loc, 1, Type::tint32))
{
}

Expression *PostDecExp::semantic(Scope *sc)
{   Expression *e = this;

    if (!type)
    {
	BinExp::semantic(sc);
	e2 = resolveProperties(sc, e2);
	e = op_overload(sc);
	if (e)
	    return e;

	e = this;
	e1 = e1->modifiableLvalue(sc, NULL);
	e1->checkScalar();
	e1->checkNoBool();
	if (e1->type->ty == Tpointer)
	    e = scaleFactor();
	else
	    e2 = e2->castTo(e1->type);
	e->type = e1->type;
    }
    return e;
}

void PostDecExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    expToCBuffer(buf, hgs, e1, precedence[op]);
    buf->writestring("--");
}

/************************************************************/

AssignExp::AssignExp(Loc loc, Expression *e1, Expression *e2)
	: BinExp(loc, TOKassign, sizeof(AssignExp), e1, e2)
{
}

Expression *AssignExp::semantic(Scope *sc)
{   Type *t1;
    Expression *e1old = e1;

#if LOGSEMANTIC
    printf("AssignExp::semantic('%s')\n", toChars());
#endif
    //printf("e1->op = %d, '%s'\n", e1->op, Token::toChars(e1->op));

    /* Look for operator overloading of a[i]=value.
     * Do it before semantic() otherwise the a[i] will have been
     * converted to a.opIndex() already.
     */
    if (e1->op == TOKarray)
    {	Type *t1;
	ArrayExp *ae = (ArrayExp *)e1;
	AggregateDeclaration *ad;
	Identifier *id = Id::index;
	FuncDeclaration *fd;

	ae->e1 = ae->e1->semantic(sc);
	t1 = ae->e1->type->toBasetype();
	if (t1->ty == Tstruct)
	{
	    ad = ((TypeStruct *)t1)->sym;
	    goto L1;
	}
	else if (t1->ty == Tclass)
	{
	    ad = ((TypeClass *)t1)->sym;
	  L1:
	    // Rewrite (a[i] = value) to (a.opIndexAssign(value, i))
	    fd = search_function(ad, Id::indexass);
	    if (fd)
	    {	Expression *e = new DotIdExp(loc, ae->e1, Id::indexass);
		Expressions *a = (Expressions *)ae->arguments->copy();

		a->insert(0, e2);
		e = new CallExp(loc, e, a);
		e = e->semantic(sc);
		return e;
	    }
	    else
	    {
		// Rewrite (a[i] = value) to (a.opIndex(i, value))
		fd = search_function(ad, id);
		if (fd)
		{   Expression *e = new DotIdExp(loc, ae->e1, id);

		    if (!global.params.useDeprecated)
			error("operator [] assignment overload with opIndex(i, value) deprecated, use opIndexAssign(value, i)");

		    e = new CallExp(loc, e, (Expression *)ae->arguments->data[0], e2);
		    e = e->semantic(sc);
		    return e;
		}
	    }
	}
    }
    /* Look for operator overloading of a[i..j]=value.
     * Do it before semantic() otherwise the a[i..j] will have been
     * converted to a.opSlice() already.
     */
    if (e1->op == TOKslice)
    {	Type *t1;
	SliceExp *ae = (SliceExp *)e1;
	AggregateDeclaration *ad;
	Identifier *id = Id::index;
	FuncDeclaration *fd;

	ae->e1 = ae->e1->semantic(sc);
	t1 = ae->e1->type->toBasetype();
	if (t1->ty == Tstruct)
	{
	    ad = ((TypeStruct *)t1)->sym;
	    goto L2;
	}
	else if (t1->ty == Tclass)
	{
	    ad = ((TypeClass *)t1)->sym;
	  L2:
	    // Rewrite (a[i..j] = value) to (a.opIndexAssign(value, i, j))
	    fd = search_function(ad, Id::sliceass);
	    if (fd)
	    {	Expression *e = new DotIdExp(loc, ae->e1, Id::sliceass);
		Expressions *a = new Expressions();

		a->push(e2);
		if (ae->lwr)
		{   a->push(ae->lwr);
		    assert(ae->upr);
		    a->push(ae->upr);
		}
		else
		    assert(!ae->upr);
		e = new CallExp(loc, e, a);
		e = e->semantic(sc);
		return e;
	    }
	}
    }

    BinExp::semantic(sc);
    e2 = resolveProperties(sc, e2);

    assert(e1->type);
    t1 = e1->type->toBasetype();
    if (t1->ty == Tfunction)
    {	// Rewrite f=value to f(value)
	Expression *e;

	e = new CallExp(loc, e1, e2);
	e = e->semantic(sc);
	return e;
    }

    e2->rvalue();

    if (e1->op == TOKarraylength)
    {
	// e1 is not an lvalue, but we let code generator handle it
	ArrayLengthExp *ale = (ArrayLengthExp *)e1;

	ale->e1 = ale->e1->modifiableLvalue(sc, NULL);
    }
    else if (e1->op == TOKslice)
	;
    else
	// Try to do a decent error message with the expression
	// before it got constant folded
	e1 = e1->modifiableLvalue(sc, e1old);

    if (e1->op == TOKslice &&
	t1->next &&
	!(t1->next->equals(e2->type->next) /*||
	  (t1->next->ty == Tchar && e2->op == TOKstring)*/)
       )
    {	// memset
	e2 = e2->implicitCastTo(t1->next);
    }
#if 0
    else if (e1->op == TOKslice &&
	     e2->op == TOKstring &&
	     ((StringExp *)e2)->len == 1)
    {	// memset
	e2 = e2->implicitCastTo(e1->type->next);
    }
#endif
    else if (t1->ty == Tsarray)
    {
	error("cannot assign to static array %s", e1->toChars());
    }
    else
    {
	e2 = e2->implicitCastTo(e1->type);
    }
    type = e1->type;
    assert(type);
    return this;
}

Expression *AssignExp::checkToBoolean()
{
    // Things like:
    //	if (a = b) ...
    // are usually mistakes.

    error("'=' does not give a boolean result");
    return this;
}

/************************************************************/

AddAssignExp::AddAssignExp(Loc loc, Expression *e1, Expression *e2)
	: BinExp(loc, TOKaddass, sizeof(AddAssignExp), e1, e2)
{
}

Expression *AddAssignExp::semantic(Scope *sc)
{   Expression *e;

    if (type)
	return this;

    BinExp::semantic(sc);
    e2 = resolveProperties(sc, e2);

    e = op_overload(sc);
    if (e)
	return e;

    e1 = e1->modifiableLvalue(sc, NULL);

    Type *tb1 = e1->type->toBasetype();
    Type *tb2 = e2->type->toBasetype();

    if ((tb1->ty == Tarray || tb1->ty == Tsarray) &&
	(tb2->ty == Tarray || tb2->ty == Tsarray) &&
	tb1->next->equals(tb2->next)
       )
    {
	type = e1->type;
	e = this;
    }
    else
    {
	e1->checkScalar();
	e1->checkNoBool();
	if (tb1->ty == Tpointer && tb2->isintegral())
	    e = scaleFactor();
	else if (tb1->ty == Tbit || tb1->ty == Tbool)
	{
#if 0
	    // Need to rethink this
	    if (e1->op != TOKvar)
	    {   // Rewrite e1+=e2 to (v=&e1),*v=*v+e2
		VarDeclaration *v;
		Expression *ea;
		Expression *ex;

		char name[6+6+1];
		Identifier *id;
		static int idn;
		sprintf(name, "__name%d", ++idn);
		id = Lexer::idPool(name);

		v = new VarDeclaration(loc, tb1->pointerTo(), id, NULL);
		v->semantic(sc);
		if (!sc->insert(v))
		    assert(0);
		v->parent = sc->func;

		ea = new AddrExp(loc, e1);
		ea = new AssignExp(loc, new VarExp(loc, v), ea);

		ex = new VarExp(loc, v);
		ex = new PtrExp(loc, ex);
		e = new AddExp(loc, ex, e2);
		e = new CastExp(loc, e, e1->type);
		e = new AssignExp(loc, ex->syntaxCopy(), e);

		e = new CommaExp(loc, ea, e);
	    }
	    else
#endif
	    {   // Rewrite e1+=e2 to e1=e1+e2
		// BUG: doesn't account for side effects in e1
		// BUG: other assignment operators for bits aren't handled at all
		e = new AddExp(loc, e1, e2);
		e = new CastExp(loc, e, e1->type);
		e = new AssignExp(loc, e1->syntaxCopy(), e);
	    }
	    e = e->semantic(sc);
	}
	else
	{
	    type = e1->type;
	    typeCombine();
	    e1->checkArithmetic();
	    e2->checkArithmetic();
	    if (type->isreal() || type->isimaginary())
	    {
		assert(global.errors || e2->type->isfloating());
		e2 = e2->castTo(e1->type);
	    }
	    e = this;
	}
    }
    return e;
}

/************************************************************/

MinAssignExp::MinAssignExp(Loc loc, Expression *e1, Expression *e2)
	: BinExp(loc, TOKminass, sizeof(MinAssignExp), e1, e2)
{
}

Expression *MinAssignExp::semantic(Scope *sc)
{   Expression *e;

    if (type)
	return this;

    BinExp::semantic(sc);
    e2 = resolveProperties(sc, e2);

    e = op_overload(sc);
    if (e)
	return e;

    e1 = e1->modifiableLvalue(sc, NULL);
    e1->checkScalar();
    e1->checkNoBool();
    if (e1->type->ty == Tpointer && e2->type->isintegral())
	e = scaleFactor();
    else
    {
	type = e1->type;
	typeCombine();
	e1->checkArithmetic();
	e2->checkArithmetic();
	if (type->isreal() || type->isimaginary())
	{
	    assert(e2->type->isfloating());
	    e2 = e2->castTo(e1->type);
	}
	e = this;
    }
    return e;
}

/************************************************************/

CatAssignExp::CatAssignExp(Loc loc, Expression *e1, Expression *e2)
	: BinExp(loc, TOKcatass, sizeof(CatAssignExp), e1, e2)
{
}

Expression *CatAssignExp::semantic(Scope *sc)
{   Expression *e;

    BinExp::semantic(sc);
    e2 = resolveProperties(sc, e2);

    e = op_overload(sc);
    if (e)
	return e;

    if (e1->op == TOKslice)
    {	SliceExp *se = (SliceExp *)e1;

	if (se->e1->type->toBasetype()->ty == Tsarray)
	    error("cannot append to static array %s", se->e1->type->toChars());
    }

    e1 = e1->modifiableLvalue(sc, NULL);

    Type *tb1 = e1->type->toBasetype();
    Type *tb2 = e2->type->toBasetype();

    if ((tb1->ty == Tarray) &&
	(tb2->ty == Tarray || tb2->ty == Tsarray) &&
	e2->implicitConvTo(e1->type)
	//e1->type->next->equals(e2->type->next)
       )
    {	// Append array
	e2 = e2->castTo(e1->type);
	type = e1->type;
	e = this;
    }
    else if ((tb1->ty == Tarray) &&
	e2->implicitConvTo(tb1->next)
       )
    {	// Append element
	e2 = e2->castTo(tb1->next);
	type = e1->type;
	e = this;
    }
    else
    {
	error("Can only append to dynamic arrays, not %s ~= %s", tb1->toChars(), tb2->toChars());
	type = Type::tint32;
	e = this;
    }
    return e;
}

/************************************************************/

MulAssignExp::MulAssignExp(Loc loc, Expression *e1, Expression *e2)
	: BinExp(loc, TOKmulass, sizeof(MulAssignExp), e1, e2)
{
}

Expression *MulAssignExp::semantic(Scope *sc)
{   Expression *e;

    BinExp::semantic(sc);
    e2 = resolveProperties(sc, e2);

    e = op_overload(sc);
    if (e)
	return e;

    e1 = e1->modifiableLvalue(sc, NULL);
    e1->checkScalar();
    e1->checkNoBool();
    type = e1->type;
    typeCombine();
    e1->checkArithmetic();
    e2->checkArithmetic();
    if (e2->type->isfloating())
    {	Type *t1;
	Type *t2;

	t1 = e1->type;
	t2 = e2->type;
	if (t1->isreal())
	{
	    if (t2->isimaginary() || t2->iscomplex())
	    {
		e2 = e2->castTo(t1);
	    }
	}
	else if (t1->isimaginary())
	{
	    if (t2->isimaginary() || t2->iscomplex())
	    {
		switch (t1->ty)
		{
		    case Timaginary32: t2 = Type::tfloat32; break;
		    case Timaginary64: t2 = Type::tfloat64; break;
		    case Timaginary80: t2 = Type::tfloat80; break;
		    default:
			assert(0);
		}
		e2 = e2->castTo(t2);
	    }
	}
    }
    return this;
}

/************************************************************/

DivAssignExp::DivAssignExp(Loc loc, Expression *e1, Expression *e2)
	: BinExp(loc, TOKdivass, sizeof(DivAssignExp), e1, e2)
{
}

Expression *DivAssignExp::semantic(Scope *sc)
{   Expression *e;

    BinExp::semantic(sc);
    e2 = resolveProperties(sc, e2);

    e = op_overload(sc);
    if (e)
	return e;

    e1 = e1->modifiableLvalue(sc, NULL);
    e1->checkScalar();
    e1->checkNoBool();
    type = e1->type;
    typeCombine();
    e1->checkArithmetic();
    e2->checkArithmetic();
    if (e2->type->isimaginary())
    {	Type *t1;
	Type *t2;

	t1 = e1->type;
	if (t1->isreal())
	{   // x/iv = i(-x/v)
	    // Therefore, the result is 0
	    e2 = new CommaExp(loc, e2, new RealExp(loc, 0, t1));
	    e2->type = t1;
	    e = new AssignExp(loc, e1, e2);
	    e->type = t1;
	    return e;
	}
	else if (t1->isimaginary())
	{   Expression *e;

	    switch (t1->ty)
	    {
		case Timaginary32: t2 = Type::tfloat32; break;
		case Timaginary64: t2 = Type::tfloat64; break;
		case Timaginary80: t2 = Type::tfloat80; break;
		default:
		    assert(0);
	    }
	    e2 = e2->castTo(t2);
	    e = new AssignExp(loc, e1, e2);
	    e->type = t1;
	    return e;
	}
    }
    return this;
}

/************************************************************/

ModAssignExp::ModAssignExp(Loc loc, Expression *e1, Expression *e2)
	: BinExp(loc, TOKmodass, sizeof(ModAssignExp), e1, e2)
{
}

Expression *ModAssignExp::semantic(Scope *sc)
{
    return commonSemanticAssign(sc);
}

/************************************************************/

ShlAssignExp::ShlAssignExp(Loc loc, Expression *e1, Expression *e2)
	: BinExp(loc, TOKshlass, sizeof(ShlAssignExp), e1, e2)
{
}

Expression *ShlAssignExp::semantic(Scope *sc)
{   Expression *e;

    //printf("ShlAssignExp::semantic()\n");
    BinExp::semantic(sc);
    e2 = resolveProperties(sc, e2);

    e = op_overload(sc);
    if (e)
	return e;

    e1 = e1->modifiableLvalue(sc, NULL);
    e1->checkScalar();
    e1->checkNoBool();
    type = e1->type;
    typeCombine();
    e1->checkIntegral();
    e2 = e2->checkIntegral();
    e2 = e2->castTo(Type::tshiftcnt);
    return this;
}

/************************************************************/

ShrAssignExp::ShrAssignExp(Loc loc, Expression *e1, Expression *e2)
	: BinExp(loc, TOKshrass, sizeof(ShrAssignExp), e1, e2)
{
}

Expression *ShrAssignExp::semantic(Scope *sc)
{   Expression *e;

    BinExp::semantic(sc);
    e2 = resolveProperties(sc, e2);

    e = op_overload(sc);
    if (e)
	return e;

    e1 = e1->modifiableLvalue(sc, NULL);
    e1->checkScalar();
    e1->checkNoBool();
    type = e1->type;
    typeCombine();
    e1->checkIntegral();
    e2 = e2->checkIntegral();
    e2 = e2->castTo(Type::tshiftcnt);
    return this;
}

/************************************************************/

UshrAssignExp::UshrAssignExp(Loc loc, Expression *e1, Expression *e2)
	: BinExp(loc, TOKushrass, sizeof(UshrAssignExp), e1, e2)
{
}

Expression *UshrAssignExp::semantic(Scope *sc)
{   Expression *e;

    BinExp::semantic(sc);
    e2 = resolveProperties(sc, e2);

    e = op_overload(sc);
    if (e)
	return e;

    e1 = e1->modifiableLvalue(sc, NULL);
    e1->checkScalar();
    e1->checkNoBool();
    type = e1->type;
    typeCombine();
    e1->checkIntegral();
    e2 = e2->checkIntegral();
    e2 = e2->castTo(Type::tshiftcnt);
    return this;
}

/************************************************************/

AndAssignExp::AndAssignExp(Loc loc, Expression *e1, Expression *e2)
	: BinExp(loc, TOKandass, sizeof(AndAssignExp), e1, e2)
{
}

Expression *AndAssignExp::semantic(Scope *sc)
{
    return commonSemanticAssignIntegral(sc);
}

/************************************************************/

OrAssignExp::OrAssignExp(Loc loc, Expression *e1, Expression *e2)
	: BinExp(loc, TOKorass, sizeof(OrAssignExp), e1, e2)
{
}

Expression *OrAssignExp::semantic(Scope *sc)
{
    return commonSemanticAssignIntegral(sc);
}

/************************************************************/

XorAssignExp::XorAssignExp(Loc loc, Expression *e1, Expression *e2)
	: BinExp(loc, TOKxorass, sizeof(XorAssignExp), e1, e2)
{
}

Expression *XorAssignExp::semantic(Scope *sc)
{
    return commonSemanticAssignIntegral(sc);
}

/************************* AddExp *****************************/

AddExp::AddExp(Loc loc, Expression *e1, Expression *e2)
	: BinExp(loc, TOKadd, sizeof(AddExp), e1, e2)
{
}

Expression *AddExp::semantic(Scope *sc)
{   Expression *e;

#if LOGSEMANTIC
    printf("AddExp::semantic('%s')\n", toChars());
#endif
    if (!type)
    {
	BinExp::semanticp(sc);

	e = op_overload(sc);
	if (e)
	    return e;

	Type *tb1 = e1->type->toBasetype();
	Type *tb2 = e2->type->toBasetype();

        if ((tb1->ty == Tarray || tb1->ty == Tsarray) &&
            (tb2->ty == Tarray || tb2->ty == Tsarray) &&
            tb1->next->equals(tb2->next)
           )
        {
            type = e1->type;
            e = this;
        }
	else if (tb1->ty == Tpointer && e2->type->isintegral() ||
	    tb2->ty == Tpointer && e1->type->isintegral())
	    e = scaleFactor();
	else if (tb1->ty == Tpointer && tb2->ty == Tpointer)
	{
	    incompatibleTypes();
	    type = e1->type;
	    e = this;
	}
	else
	{
	    typeCombine();
	    if ((e1->type->isreal() && e2->type->isimaginary()) ||
		(e1->type->isimaginary() && e2->type->isreal()))
	    {
		switch (type->toBasetype()->ty)
		{
		    case Tfloat32:
		    case Timaginary32:
			type = Type::tcomplex32;
			break;

		    case Tfloat64:
		    case Timaginary64:
			type = Type::tcomplex64;
			break;

		    case Tfloat80:
		    case Timaginary80:
			type = Type::tcomplex80;
			break;

		    default:
			assert(0);
		}
	    }
	    e = this;
	}
	return e;
    }
    return this;
}

/************************************************************/

MinExp::MinExp(Loc loc, Expression *e1, Expression *e2)
	: BinExp(loc, TOKmin, sizeof(MinExp), e1, e2)
{
}

Expression *MinExp::semantic(Scope *sc)
{   Expression *e;
    Type *t1;
    Type *t2;

#if LOGSEMANTIC
    printf("MinExp::semantic('%s')\n", toChars());
#endif
    if (type)
	return this;

    BinExp::semanticp(sc);

    e = op_overload(sc);
    if (e)
	return e;

    e = this;
    t1 = e1->type->toBasetype();
    t2 = e2->type->toBasetype();
    if (t1->ty == Tpointer)
    {
	if (t2->ty == Tpointer)
	{   // Need to divide the result by the stride
	    // Replace (ptr - ptr) with (ptr - ptr) / stride
	    d_int64 stride;
	    Expression *e;

	    typeCombine();		// make sure pointer types are compatible
	    type = Type::tptrdiff_t;
	    stride = t2->next->size();
	    e = new DivExp(loc, this, new IntegerExp(0, stride, Type::tptrdiff_t));
	    e->type = Type::tptrdiff_t;
	    return e;
	}
	else if (t2->isintegral())
	    e = scaleFactor();
	else
	{   error("incompatible types for -");
	    return new IntegerExp(0);
	}
    }
    else if (t2->ty == Tpointer)
    {
	type = e2->type;
	error("can't subtract pointer from %s", e1->type->toChars());
	return new IntegerExp(0);
    }
    else
    {
	typeCombine();
	t1 = e1->type->toBasetype();
	t2 = e2->type->toBasetype();
	if ((t1->isreal() && t2->isimaginary()) ||
	    (t1->isimaginary() && t2->isreal()))
	{
	    switch (type->ty)
	    {
		case Tfloat32:
		case Timaginary32:
		    type = Type::tcomplex32;
		    break;

		case Tfloat64:
		case Timaginary64:
		    type = Type::tcomplex64;
		    break;

		case Tfloat80:
		case Timaginary80:
		    type = Type::tcomplex80;
		    break;

		default:
		    assert(0);
	    }
	}
    }
    return e;
}

/************************* CatExp *****************************/

CatExp::CatExp(Loc loc, Expression *e1, Expression *e2)
	: BinExp(loc, TOKcat, sizeof(CatExp), e1, e2)
{
}

Expression *CatExp::semantic(Scope *sc)
{   Expression *e;

    //printf("CatExp::semantic()\n");
    if (!type)
    {
	BinExp::semanticp(sc);
	e = op_overload(sc);
	if (e)
	    return e;

	Type *tb1 = e1->type->toBasetype();
	Type *tb2 = e2->type->toBasetype();


	/* BUG: Should handle things like:
	 *	char c;
	 *	c ~ ' '
	 *	' ' ~ c;
	 */

#if 0
	e1->type->print();
	e2->type->print();
#endif
	if ((tb1->ty == Tsarray || tb1->ty == Tarray) &&
	    e2->type->equals(tb1->next))
	{
	    type = tb1->next->arrayOf();
	    return this;
	}
	else if ((tb2->ty == Tsarray || tb2->ty == Tarray) &&
	    e1->type->equals(tb2->next))
	{
	    type = tb2->next->arrayOf();
	    return this;
	}

	typeCombine();

	if (type->toBasetype()->ty == Tsarray)
	    type = type->toBasetype()->next->arrayOf();
#if 0
	e1->type->print();
	e2->type->print();
	type->print();
	print();
#endif
	if (e1->op == TOKstring && e2->op == TOKstring)
	    e = optimize(WANTvalue);
	else if (e1->type->equals(e2->type) &&
		(e1->type->toBasetype()->ty == Tarray ||
		 e1->type->toBasetype()->ty == Tsarray))
	{
	    e = this;
	}
	else
	{
	    error("Can only concatenate arrays, not (%s ~ %s)",
		e1->type->toChars(), e2->type->toChars());
	    type = Type::tint32;
	    e = this;
	}
	e->type = e->type->semantic(loc, sc);
	return e;
    }
    return this;
}

/************************************************************/

MulExp::MulExp(Loc loc, Expression *e1, Expression *e2)
	: BinExp(loc, TOKmul, sizeof(MulExp), e1, e2)
{
}

Expression *MulExp::semantic(Scope *sc)
{   Expression *e;

    if (type)
	return this;

    BinExp::semanticp(sc);
    e = op_overload(sc);
    if (e)
	return e;

    typeCombine();
    e1->checkArithmetic();
    e2->checkArithmetic();
    if (type->isfloating())
    {	Type *t1 = e1->type;
	Type *t2 = e2->type;

	if (t1->isreal())
	{
	    type = t2;
	}
	else if (t2->isreal())
	{
	    type = t1;
	}
	else if (t1->isimaginary())
	{
	    if (t2->isimaginary())
	    {	Expression *e;

		switch (t1->ty)
		{
		    case Timaginary32:	type = Type::tfloat32;	break;
		    case Timaginary64:	type = Type::tfloat64;	break;
		    case Timaginary80:	type = Type::tfloat80;	break;
		    default:		assert(0);
		}

		// iy * iv = -yv
		e1->type = type;
		e2->type = type;
		e = new NegExp(loc, this);
		e = e->semantic(sc);
		return e;
	    }
	    else
		type = t2;	// t2 is complex
	}
	else if (t2->isimaginary())
	{
	    type = t1;	// t1 is complex
	}
    }
    return this;
}

/************************************************************/

DivExp::DivExp(Loc loc, Expression *e1, Expression *e2)
	: BinExp(loc, TOKdiv, sizeof(DivExp), e1, e2)
{
}

Expression *DivExp::semantic(Scope *sc)
{   Expression *e;

    if (type)
	return this;

    BinExp::semanticp(sc);
    e = op_overload(sc);
    if (e)
	return e;

    typeCombine();
    e1->checkArithmetic();
    e2->checkArithmetic();
    if (type->isfloating())
    {	Type *t1 = e1->type;
	Type *t2 = e2->type;

	if (t1->isreal())
	{
	    type = t2;
	    if (t2->isimaginary())
	    {	Expression *e;

		// x/iv = i(-x/v)
		e2->type = t1;
		e = new NegExp(loc, this);
		e = e->semantic(sc);
		return e;
	    }
	}
	else if (t2->isreal())
	{
	    type = t1;
	}
	else if (t1->isimaginary())
	{
	    if (t2->isimaginary())
	    {
		switch (t1->ty)
		{
		    case Timaginary32:	type = Type::tfloat32;	break;
		    case Timaginary64:	type = Type::tfloat64;	break;
		    case Timaginary80:	type = Type::tfloat80;	break;
		    default:		assert(0);
		}
	    }
	    else
		type = t2;	// t2 is complex
	}
	else if (t2->isimaginary())
	{
	    type = t1;	// t1 is complex
	}
    }
    return this;
}

/************************************************************/

ModExp::ModExp(Loc loc, Expression *e1, Expression *e2)
	: BinExp(loc, TOKmod, sizeof(ModExp), e1, e2)
{
}

Expression *ModExp::semantic(Scope *sc)
{   Expression *e;

    if (type)
	return this;

    BinExp::semanticp(sc);
    e = op_overload(sc);
    if (e)
	return e;

    typeCombine();
    e1->checkArithmetic();
    e2->checkArithmetic();
    if (type->isfloating())
    {	type = e1->type;
	if (e2->type->iscomplex())
	{   error("cannot perform modulo complex arithmetic");
	    return new IntegerExp(0);
	}
    }
    return this;
}

/************************************************************/

ShlExp::ShlExp(Loc loc, Expression *e1, Expression *e2)
	: BinExp(loc, TOKshl, sizeof(ShlExp), e1, e2)
{
}

Expression *ShlExp::semantic(Scope *sc)
{   Expression *e;

    //printf("ShlExp::semantic(), type = %p\n", type);
    if (!type)
    {	BinExp::semanticp(sc);
	e = op_overload(sc);
	if (e)
	    return e;
	e1 = e1->checkIntegral();
	e2 = e2->checkIntegral();
	e1 = e1->integralPromotions();
	e2 = e2->castTo(Type::tshiftcnt);
	type = e1->type;
    }
    return this;
}

/************************************************************/

ShrExp::ShrExp(Loc loc, Expression *e1, Expression *e2)
	: BinExp(loc, TOKshr, sizeof(ShrExp), e1, e2)
{
}

Expression *ShrExp::semantic(Scope *sc)
{   Expression *e;

    if (!type)
    {	BinExp::semanticp(sc);
	e = op_overload(sc);
	if (e)
	    return e;
	e1 = e1->checkIntegral();
	e2 = e2->checkIntegral();
	e1 = e1->integralPromotions();
	e2 = e2->castTo(Type::tshiftcnt);
	type = e1->type;
    }
    return this;
}

/************************************************************/

UshrExp::UshrExp(Loc loc, Expression *e1, Expression *e2)
	: BinExp(loc, TOKushr, sizeof(UshrExp), e1, e2)
{
}

Expression *UshrExp::semantic(Scope *sc)
{   Expression *e;

    if (!type)
    {	BinExp::semanticp(sc);
	e = op_overload(sc);
	if (e)
	    return e;
	e1 = e1->checkIntegral();
	e2 = e2->checkIntegral();
	e1 = e1->integralPromotions();
	e2 = e2->castTo(Type::tshiftcnt);
	type = e1->type;
    }
    return this;
}

/************************************************************/

AndExp::AndExp(Loc loc, Expression *e1, Expression *e2)
	: BinExp(loc, TOKand, sizeof(AndExp), e1, e2)
{
}

Expression *AndExp::semantic(Scope *sc)
{   Expression *e;

    if (!type)
    {	BinExp::semanticp(sc);
	e = op_overload(sc);
	if (e)
	    return e;
	if (e1->type->toBasetype()->ty == Tbool &&
	    e2->type->toBasetype()->ty == Tbool)
	{
	    type = e1->type;
	    e = this;
	}
	else
	{
	    typeCombine();
	    e1->checkIntegral();
	    e2->checkIntegral();
	}
    }
    return this;
}

/************************************************************/

OrExp::OrExp(Loc loc, Expression *e1, Expression *e2)
	: BinExp(loc, TOKor, sizeof(OrExp), e1, e2)
{
}

Expression *OrExp::semantic(Scope *sc)
{   Expression *e;

    if (!type)
    {	BinExp::semanticp(sc);
	e = op_overload(sc);
	if (e)
	    return e;
	if (e1->type->toBasetype()->ty == Tbool &&
	    e2->type->toBasetype()->ty == Tbool)
	{
	    type = e1->type;
	    e = this;
	}
	else
	{
	    typeCombine();
	    e1->checkIntegral();
	    e2->checkIntegral();
	}
    }
    return this;
}

/************************************************************/

XorExp::XorExp(Loc loc, Expression *e1, Expression *e2)
	: BinExp(loc, TOKxor, sizeof(XorExp), e1, e2)
{
}

Expression *XorExp::semantic(Scope *sc)
{   Expression *e;

    if (!type)
    {	BinExp::semanticp(sc);
	e = op_overload(sc);
	if (e)
	    return e;
	if (e1->type->toBasetype()->ty == Tbool &&
	    e2->type->toBasetype()->ty == Tbool)
	{
	    type = e1->type;
	    e = this;
	}
	else
	{
	    typeCombine();
	    e1->checkIntegral();
	    e2->checkIntegral();
	}
    }
    return this;
}


/************************************************************/

OrOrExp::OrOrExp(Loc loc, Expression *e1, Expression *e2)
	: BinExp(loc, TOKoror, sizeof(OrOrExp), e1, e2)
{
}

Expression *OrOrExp::semantic(Scope *sc)
{
    unsigned cs1;

    // same as for AndAnd
    e1 = e1->semantic(sc);
    e1 = resolveProperties(sc, e1);
    e1 = e1->checkToPointer();
    e1 = e1->checkToBoolean();
    cs1 = sc->callSuper;

    if (sc->flags & SCOPEstaticif)
    {
	/* If in static if, don't evaluate e2 if we don't have to.
	 */
	e1 = e1->optimize(WANTflags);
	if (e1->isBool(TRUE))
	{
	    return new IntegerExp(loc, 1, Type::tboolean);
	}
    }

    e2 = e2->semantic(sc);
    sc->mergeCallSuper(loc, cs1);
    e2 = resolveProperties(sc, e2);
    e2 = e2->checkToPointer();

    type = Type::tboolean;
    if (e1->type->ty == Tvoid)
	type = Type::tvoid;
    if (e2->op == TOKtype || e2->op == TOKimport)
	error("%s is not an expression", e2->toChars());
    return this;
}

Expression *OrOrExp::checkToBoolean()
{
    e2 = e2->checkToBoolean();
    return this;
}

int OrOrExp::isBit()
{
    return TRUE;
}

void OrOrExp::checkSideEffect(int flag)
{
    e2->checkSideEffect(flag);
}

/************************************************************/

AndAndExp::AndAndExp(Loc loc, Expression *e1, Expression *e2)
	: BinExp(loc, TOKandand, sizeof(AndAndExp), e1, e2)
{
}

Expression *AndAndExp::semantic(Scope *sc)
{
    unsigned cs1;

    // same as for OrOr
    e1 = e1->semantic(sc);
    e1 = resolveProperties(sc, e1);
    e1 = e1->checkToPointer();
    e1 = e1->checkToBoolean();
    cs1 = sc->callSuper;

    if (sc->flags & SCOPEstaticif)
    {
	/* If in static if, don't evaluate e2 if we don't have to.
	 */
	e1 = e1->optimize(WANTflags);
	if (e1->isBool(FALSE))
	{
	    return new IntegerExp(loc, 0, Type::tboolean);
	}
    }

    e2 = e2->semantic(sc);
    sc->mergeCallSuper(loc, cs1);
    e2 = resolveProperties(sc, e2);
    e2 = e2->checkToPointer();

    type = Type::tboolean;
    if (e1->type->ty == Tvoid)
	type = Type::tvoid;
    if (e2->op == TOKtype || e2->op == TOKimport)
	error("%s is not an expression", e2->toChars());
    return this;
}

Expression *AndAndExp::checkToBoolean()
{
    e2 = e2->checkToBoolean();
    return this;
}

int AndAndExp::isBit()
{
    return TRUE;
}

void AndAndExp::checkSideEffect(int flag)
{
    e2->checkSideEffect(flag);
}

/************************************************************/

InExp::InExp(Loc loc, Expression *e1, Expression *e2)
	: BinExp(loc, TOKin, sizeof(InExp), e1, e2)
{
}

Expression *InExp::semantic(Scope *sc)
{   Expression *e;

    if (type)
	return this;

    BinExp::semanticp(sc);
    e = op_overload(sc);
    if (e)
	return e;

    //type = Type::tboolean;
    Type *t2b = e2->type->toBasetype();
    if (t2b->ty != Taarray)
    {
	error("rvalue of in expression must be an associative array, not %s", e2->type->toChars());
	type = Type::terror;
    }
    else
    {
	TypeAArray *ta = (TypeAArray *)t2b;

	// Convert key to type of key
	e1 = e1->implicitCastTo(ta->index);

	// Return type is pointer to value
	type = ta->next->pointerTo();
    }
    return this;
}

int InExp::isBit()
{
    return FALSE;
}


/************************************************************/

/* This deletes the key e1 from the associative array e2
 */

RemoveExp::RemoveExp(Loc loc, Expression *e1, Expression *e2)
	: BinExp(loc, TOKremove, sizeof(RemoveExp), e1, e2)
{
    type = Type::tvoid;
}

/************************************************************/

CmpExp::CmpExp(enum TOK op, Loc loc, Expression *e1, Expression *e2)
	: BinExp(loc, op, sizeof(CmpExp), e1, e2)
{
}

Expression *CmpExp::semantic(Scope *sc)
{   Expression *e;
    Type *t1;
    Type *t2;

#if LOGSEMANTIC
    printf("CmpExp::semantic('%s')\n", toChars());
#endif
    if (type)
	return this;

    BinExp::semanticp(sc);
    e = op_overload(sc);
    if (e)
    {
	e = new CmpExp(op, loc, e, new IntegerExp(loc, 0, Type::tint32));
	e = e->semantic(sc);
	return e;
    }

    typeCombine();
    type = Type::tboolean;

    // Special handling for array comparisons
    t1 = e1->type->toBasetype();
    t2 = e2->type->toBasetype();
    if ((t1->ty == Tarray || t1->ty == Tsarray) &&
	(t2->ty == Tarray || t2->ty == Tsarray))
    {
	if (!t1->next->equals(t2->next))
	    error("array comparison type mismatch, %s vs %s", t1->next->toChars(), t2->next->toChars());
	e = this;
    }
    else if (t1->ty == Tstruct || t2->ty == Tstruct ||
	     (t1->ty == Tclass && t2->ty == Tclass))
    {
	if (t2->ty == Tstruct)
	    error("need member function opCmp() for %s %s to compare", t2->toDsymbol(sc)->kind(), t2->toChars());
	else
	    error("need member function opCmp() for %s %s to compare", t1->toDsymbol(sc)->kind(), t1->toChars());
	e = this;
    }
#if 1
    else if (t1->iscomplex() || t2->iscomplex())
    {
	error("compare not defined for complex operands");
	e = new IntegerExp(0);
    }
#endif
    else
	e = this;
    return e;
}

int CmpExp::isBit()
{
    return TRUE;
}


/************************************************************/

EqualExp::EqualExp(enum TOK op, Loc loc, Expression *e1, Expression *e2)
	: BinExp(loc, op, sizeof(EqualExp), e1, e2)
{
}

Expression *EqualExp::semantic(Scope *sc)
{   Expression *e;
    Type *t1;
    Type *t2;

    if (type)
	return this;

    BinExp::semanticp(sc);

    /* Before checking for operator overloading, check to see if we're
     * comparing the addresses of two statics. If so, we can just see
     * if they are the same symbol.
     */
    if (e1->op == TOKaddress && e2->op == TOKaddress)
    {	AddrExp *ae1 = (AddrExp *)e1;
	AddrExp *ae2 = (AddrExp *)e2;

	if (ae1->e1->op == TOKvar && ae2->e1->op == TOKvar)
	{   VarExp *ve1 = (VarExp *)ae1->e1;
	    VarExp *ve2 = (VarExp *)ae2->e1;

	    if (ve1->var == ve2->var /*|| ve1->var->toSymbol() == ve2->var->toSymbol()*/)
	    {
		// They are the same, result is 'true'
		e = new IntegerExp(loc, 1, Type::tboolean);
		return e;
	    }
	}
    }

    //if (e2->op != TOKnull)
    {
	e = op_overload(sc);
	if (e)
	{
	    if (op == TOKnotequal)
	    {
		e = new NotExp(e->loc, e);
		e = e->semantic(sc);
	    }
	    return e;
	}
    }

    e = typeCombine();
    type = Type::tboolean;

    // Special handling for array comparisons
    t1 = e1->type->toBasetype();
    t2 = e2->type->toBasetype();
    if ((t1->ty == Tarray || t1->ty == Tsarray) &&
	(t2->ty == Tarray || t2->ty == Tsarray))
    {
	if (!t1->next->equals(t2->next))
	    error("array comparison type mismatch, %s vs %s", t1->next->toChars(), t2->next->toChars());
    }
    else
    {
	if (e1->type != e2->type && e1->type->isfloating() && e2->type->isfloating())
	{
	    // Cast both to complex
	    e1 = e1->castTo(Type::tcomplex80);
	    e2 = e2->castTo(Type::tcomplex80);
	}
    }
    return e;
}

int EqualExp::isBit()
{
    return TRUE;
}



/************************************************************/

IdentityExp::IdentityExp(enum TOK op, Loc loc, Expression *e1, Expression *e2)
	: BinExp(loc, op, sizeof(IdentityExp), e1, e2)
{
}

Expression *IdentityExp::semantic(Scope *sc)
{
    if (type)
	return this;

    BinExp::semanticp(sc);
    type = Type::tboolean;
    typeCombine();
    if (e1->type != e2->type && e1->type->isfloating() && e2->type->isfloating())
    {
	// Cast both to complex
	e1 = e1->castTo(Type::tcomplex80);
	e2 = e2->castTo(Type::tcomplex80);
    }
    return this;
}

int IdentityExp::isBit()
{
    return TRUE;
}


/****************************************************************/

CondExp::CondExp(Loc loc, Expression *econd, Expression *e1, Expression *e2)
	: BinExp(loc, TOKquestion, sizeof(CondExp), e1, e2)
{
    this->econd = econd;
}

Expression *CondExp::syntaxCopy()
{
    return new CondExp(loc, econd->syntaxCopy(), e1->syntaxCopy(), e2->syntaxCopy());
}


Expression *CondExp::semantic(Scope *sc)
{   Type *t1;
    Type *t2;
    unsigned cs0;
    unsigned cs1;

    if (type)
	return this;

    econd = econd->semantic(sc);
    econd = resolveProperties(sc, econd);
    econd = econd->checkToPointer();
    econd = econd->checkToBoolean();

#if 0	/* this cannot work right because the types of e1 and e2
 	 * both contribute to the type of the result.
	 */
    if (sc->flags & SCOPEstaticif)
    {
	/* If in static if, don't evaluate what we don't have to.
	 */
	econd = econd->optimize(WANTflags);
	if (econd->isBool(TRUE))
	{
	    e1 = e1->semantic(sc);
	    e1 = resolveProperties(sc, e1);
	    return e1;
	}
	else if (econd->isBool(FALSE))
	{
	    e2 = e2->semantic(sc);
	    e2 = resolveProperties(sc, e2);
	    return e2;
	}
    }
#endif


    cs0 = sc->callSuper;
    e1 = e1->semantic(sc);
    e1 = resolveProperties(sc, e1);
    cs1 = sc->callSuper;
    sc->callSuper = cs0;
    e2 = e2->semantic(sc);
    e2 = resolveProperties(sc, e2);
    sc->mergeCallSuper(loc, cs1);


    // If either operand is void, the result is void
    t1 = e1->type;
    t2 = e2->type;
    if (t1->ty == Tvoid || t2->ty == Tvoid)
	type = Type::tvoid;
    else if (t1 == t2)
	type = t1;
    else
    {
	typeCombine();
    }
    return this;
}

Expression *CondExp::toLvalue(Expression *ex)
{
    PtrExp *e;

    // convert (econd ? e1 : e2) to *(econd ? &e1 : &e2)
    e = new PtrExp(loc, this, type);

    e1 = e1->addressOf();
    e1 = e1->toLvalue(NULL);

    e2 = e2->addressOf();
    e2 = e2->toLvalue(NULL);

    typeCombine();

    type = e2->type;
    return e;
}

Expression *CondExp::modifiableLvalue(Scope *sc, Expression *e)
{
    error("conditional expression %s is not a modifiable lvalue", toChars());
    return this;
}

void CondExp::checkEscape()
{
    e1->checkEscape();
    e2->checkEscape();
}


Expression *CondExp::checkToBoolean()
{
    e1 = e1->checkToBoolean();
    e2 = e2->checkToBoolean();
    return this;
}

void CondExp::checkSideEffect(int flag)
{
    econd->checkSideEffect(TRUE);
    e1->checkSideEffect(flag);
    e2->checkSideEffect(flag);
}

void CondExp::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    expToCBuffer(buf, hgs, econd, PREC_oror);
    buf->writestring(" ? ");
    expToCBuffer(buf, hgs, e1, PREC_expr);
    buf->writestring(" : ");
    expToCBuffer(buf, hgs, e2, PREC_cond);
}


