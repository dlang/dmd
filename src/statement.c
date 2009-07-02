
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

#include "mem.h"

#include "statement.h"
#include "expression.h"
#include "debcond.h"
#include "init.h"
#include "staticassert.h"
#include "mtype.h"
#include "scope.h"
#include "declaration.h"
#include "aggregate.h"
#include "id.h"


/******************************** Statement ***************************/

Statement::Statement(Loc loc)
    : loc(loc)
{
}

Statement *Statement::syntaxCopy()
{
    assert(0);
    return NULL;
}

void Statement::print()
{
    printf("%s\n", toChars());
    fflush(stdout);
}

char *Statement::toChars()
{   OutBuffer *buf;

    buf = new OutBuffer();
    toCBuffer(buf);
    return buf->toChars();
}

void Statement::toCBuffer(OutBuffer *buf)
{
    buf->printf("Statement::toCBuffer()");
    buf->writenl();
}

Statement *Statement::semantic(Scope *sc)
{
    return this;
}

// Same as semantic(), but do create a new scope

Statement *Statement::semanticScope(Scope *sc, Statement *sbreak, Statement *scontinue)
{   Scope *scd;
    Statement *s;

    scd = sc->push();
    if (sbreak)
	scd->sbreak = sbreak;
    if (scontinue)
	scd->scontinue = scontinue;
    s = semantic(scd);
    scd->pop();
    return s;
}

void Statement::error(const char *format, ...)
{
    char *p = loc.toChars();
    if (*p)
	printf("%s: ", p);
    mem.free(p);

    va_list ap;
    va_start(ap, format);
    vprintf(format, ap);
    va_end(ap);

    printf("\n");
    fflush(stdout);

    global.errors++;
    fatal();
}

int Statement::hasBreak()
{
    return FALSE;
}

int Statement::hasContinue()
{
    return FALSE;
}

// TRUE if statement uses exception handling

int Statement::usesEH()
{
    return FALSE;
}

/****************************************
 * If this statement has code that needs to run in a finally clause
 * at the end of the current scope, return that code in the form of
 * a Statement.
 */

Statement *Statement::callAutoDtor()
{
    //printf("Statement::callAutoDtor()\n");
    //print();
    return NULL;
}

/*********************************
 * Flatten out the scope by presenting the statement
 * as an array of statements.
 * Returns NULL if no flattening necessary.
 */

Array *Statement::flatten()
{
    return NULL;
}

/******************************** ExpStatement ***************************/

ExpStatement::ExpStatement(Loc loc, Expression *exp)
    : Statement(loc)
{
    this->exp = exp;
}

Statement *ExpStatement::syntaxCopy()
{
    Expression *e = exp ? exp->syntaxCopy() : NULL;
    ExpStatement *es = new ExpStatement(loc, e);
    return es;
}

void ExpStatement::toCBuffer(OutBuffer *buf)
{
    if (exp)
	exp->toCBuffer(buf);
    buf->writeByte(';');
    buf->writenl();
}

Statement *ExpStatement::semantic(Scope *sc)
{
    if (exp)
	exp = exp->semantic(sc);
    return this;
}

/******************************** DeclarationStatement ***************************/

DeclarationStatement::DeclarationStatement(Loc loc, Dsymbol *declaration)
    : ExpStatement(loc, new DeclarationExp(loc, declaration))
{
}

DeclarationStatement::DeclarationStatement(Loc loc, Expression *exp)
    : ExpStatement(loc, exp)
{
}

Statement *DeclarationStatement::syntaxCopy()
{
    DeclarationStatement *ds = new DeclarationStatement(loc, exp->syntaxCopy());
    return ds;
}

Statement *DeclarationStatement::callAutoDtor()
{
    //printf("DeclarationStatement::callAutoDtor()\n");
    //print();

    if (exp)
    {
	if (exp->op == TOKdeclaration)
	{
	    DeclarationExp *de = (DeclarationExp *)(exp);
	    VarDeclaration *v = de->declaration->isVarDeclaration();
	    if (v)
	    {	Expression *e;

		e = v->callAutoDtor();
		if (e)
		{
		    //printf("dtor is: "); e->print();
		    return new ExpStatement(loc, e);
		}
	    }
	}
    }
    return NULL;
}

void DeclarationStatement::toCBuffer(OutBuffer *buf)
{
    buf->printf("DeclarationStatement::toCBuffer()");
    buf->writenl();
}


/******************************** CompoundStatement ***************************/

CompoundStatement::CompoundStatement(Loc loc, Array *s)
    : Statement(loc)
{
    statements = s;
}

CompoundStatement::CompoundStatement(Loc loc, Statement *s1, Statement *s2)
    : Statement(loc)
{
    statements = new Array();
    statements->reserve(2);
    statements->push(s1);
    statements->push(s2);
}

Statement *CompoundStatement::syntaxCopy()
{
    Array *a = new Array();
    a->setDim(statements->dim);
    for (int i = 0; i < statements->dim; i++)
    {	Statement *s = (Statement *)statements->data[i];
	if (s)
	    s = s->syntaxCopy();
	a->data[i] = s;
    }
    CompoundStatement *cs = new CompoundStatement(loc, a);
    return cs;
}


Statement *CompoundStatement::semantic(Scope *sc)
{   Statement *s;

    //printf("CompoundStatement::semantic(this = %p, sc = %p)\n", this, sc);
    for (int i = 0; i < statements->dim; i++)
    {
      L1:
	s = (Statement *) statements->data[i];
	if (s)
	{   Array *a = s->flatten();

	    if (a)
	    {
		statements->remove(i);
		statements->insert(i, a);
		if (i >= statements->dim)
		    break;
		goto L1;
	    }

	    s = s->semantic(sc);
	    statements->data[i] = s;
	    if (s)
	    {
		Statement *finalbody;

		finalbody = s->callAutoDtor();
		if (finalbody)
		{
		    if (i + 1 == statements->dim)
		    {
			statements->push(finalbody);
		    }
		    else
		    {
			// The rest of the statements form the body of a try-finally
			Statement *body;
			Array *a = new Array();

			for (int j = i + 1; j < statements->dim; j++)
			{
			    a->push(statements->data[j]);
			}
			body = new CompoundStatement(0, a);
			s = new TryFinallyStatement(0, body, finalbody);
			statements->data[i + 1] = s;
			statements->setDim(i + 2);
		    }
		}
	    }
	}
    }
    if (statements->dim == 1)
	return s;
    return this;
}

Array *CompoundStatement::flatten()
{
    return statements;
}

void CompoundStatement::toCBuffer(OutBuffer *buf)
{   int i;

    for (i = 0; i < statements->dim; i++)
    {	Statement *s;

	s = (Statement *) statements->data[i];
	if (s)
	    s->toCBuffer(buf);
    }
}

int CompoundStatement::usesEH()
{
    for (int i = 0; i < statements->dim; i++)
    {	Statement *s;

	s = (Statement *) statements->data[i];
	if (s && s->usesEH())
	    return TRUE;
    }
    return FALSE;
}


/******************************** ScopeStatement ***************************/

ScopeStatement::ScopeStatement(Loc loc, Statement *s)
    : Statement(loc)
{
    this->statement = s;
}

Statement *ScopeStatement::syntaxCopy()
{
    Statement *s;

    s = statement ? statement->syntaxCopy() : NULL;
    s = new ScopeStatement(loc, s);
    return s;
}


Statement *ScopeStatement::semantic(Scope *sc)
{   ScopeDsymbol *sym;

    //printf("ScopeStatement::semantic(sc = %p)\n", sc);
    if (statement)
    {	Array *a;

	sym = new ScopeDsymbol();
	sym->parent = sc->scopesym;
	sc = sc->push(sym);

	a = statement->flatten();
	if (a)
	{
	    statement = new CompoundStatement(loc, a);
	}

	statement = statement->semantic(sc);
	if (statement)
	{
	    Statement *finalbody;
	    finalbody = statement->callAutoDtor();
	    if (finalbody)
	    {
		//printf("adding finalbody\n");
		statement = new CompoundStatement(loc, statement, finalbody);
	    }
	}

	sc->pop();
    }
    return this;
}

void ScopeStatement::toCBuffer(OutBuffer *buf)
{
    buf->writeByte('{');
    buf->writenl();

    if (statement)
	statement->toCBuffer(buf);

    buf->writeByte('}');
    buf->writenl();
}

/******************************** WhileStatement ***************************/

WhileStatement::WhileStatement(Loc loc, Expression *c, Statement *b)
    : Statement(loc)
{
    condition = c;
    body = b;
}

Statement *WhileStatement::syntaxCopy()
{
    WhileStatement *s = new WhileStatement(loc, condition->syntaxCopy(), body->syntaxCopy());
    return s;
}


Statement *WhileStatement::semantic(Scope *sc)
{
    condition = condition->semantic(sc);
    condition = resolveProperties(sc, condition);
    condition = condition->checkToBoolean();

    sc->noctor++;
    body = body->semanticScope(sc, this, this);
    sc->noctor--;

    return this;
}

int WhileStatement::hasBreak()
{
    return TRUE;
}

int WhileStatement::hasContinue()
{
    return TRUE;
}

int WhileStatement::usesEH()
{
    return body->usesEH();
}

/******************************** DoStatement ***************************/

DoStatement::DoStatement(Loc loc, Statement *b, Expression *c)
    : Statement(loc)
{
    body = b;
    condition = c;
}

Statement *DoStatement::syntaxCopy()
{
    DoStatement *s = new DoStatement(loc, body->syntaxCopy(), condition->syntaxCopy());
    return s;
}


Statement *DoStatement::semantic(Scope *sc)
{
    sc->noctor++;
    body = body->semanticScope(sc, this, this);
    sc->noctor--;
    condition = condition->semantic(sc);
    condition = resolveProperties(sc, condition);
    condition = condition->checkToBoolean();
    return this;
}

int DoStatement::hasBreak()
{
    return TRUE;
}

int DoStatement::hasContinue()
{
    return TRUE;
}

int DoStatement::usesEH()
{
    return body->usesEH();
}

/******************************** ForStatement ***************************/

ForStatement::ForStatement(Loc loc, Statement *init, Expression *condition, Expression *increment, Statement *body)
    : Statement(loc)
{
    this->init = init;
    this->condition = condition;
    this->increment = increment;
    this->body = body;
}

Statement *ForStatement::syntaxCopy()
{
    Statement *i = NULL;
    if (init)
	i = init->syntaxCopy();
    Expression *c = NULL;
    if (condition)
	c = condition->syntaxCopy();
    Expression *inc = NULL;
    if (increment)
	inc = increment->syntaxCopy();
    ForStatement *s = new ForStatement(loc, i, c, inc, body->syntaxCopy());
    return s;
}

Statement *ForStatement::semantic(Scope *sc)
{   ScopeDsymbol *sym;

    sym = new ScopeDsymbol();
    sym->parent = sc->scopesym;
    sc = sc->push(sym);
    if (init)
	init = init->semantic(sc);
    if (!condition)
	// Use a default value
	condition = new IntegerExp(loc, 1, Type::tboolean);
    sc->noctor++;
    condition = condition->semantic(sc);
    condition = resolveProperties(sc, condition);
    condition = condition->checkToBoolean();
    if (increment)
	increment = increment->semantic(sc);

    sc->sbreak = this;
    sc->scontinue = this;
    body = body->semantic(sc);
    sc->noctor--;

    sc->pop();
    return this;
}

int ForStatement::hasBreak()
{
    return TRUE;
}

int ForStatement::hasContinue()
{
    return TRUE;
}

int ForStatement::usesEH()
{
    return (init && init->usesEH()) || body->usesEH();
}

/******************************** ForeachStatement ***************************/

ForeachStatement::ForeachStatement(Loc loc, Array *arguments,
	Expression *aggr, Statement *body)
    : Statement(loc)
{
    this->arguments = arguments;
    this->aggr = aggr;
    this->body = body;

    this->key = NULL;
    this->value = NULL;
}

Statement *ForeachStatement::syntaxCopy()
{
    Array *args = new Array();
    args->setDim(arguments->dim);
    for (int i = 0; i < arguments->dim; i++)
    {
	Argument *arg = (Argument *)arguments->data[i];
	Argument *a = new Argument(arg->type->syntaxCopy(), arg->ident, arg->inout);
	args->data[i] = (void *)a;
    }
    Expression *exp = aggr->syntaxCopy();
    ForeachStatement *s = new ForeachStatement(loc, args, exp, body->syntaxCopy());
    return s;
}

Statement *ForeachStatement::semantic(Scope *sc)
{
    ScopeDsymbol *sym;
    Statement *s = this;
    int dim = arguments->dim;
    int i;
    TypeAArray *taa = NULL;

    Type *tn = NULL;
    Type *tnv = NULL;

    aggr = aggr->semantic(sc);

    sym = new ScopeDsymbol();
    sym->parent = sc->scopesym;
    sc = sc->push(sym);

    sc->noctor++;

    Type *tab = aggr->type->toBasetype();
    switch (tab->ty)
    {
	case Tarray:
	case Tsarray:
	    if (dim < 1 || dim > 2)
	    {
		error("only one or two arguments for array foreach");
		break;
	    }

	    /* Look for special case of parsing char types out of char type
	     * array.
	     */
	    tn = tab->next->toBasetype();
	    if (tn->ty == Tchar || tn->ty == Twchar || tn->ty == Tdchar)
	    {	Argument *arg;

		i = (dim == 1) ? 0 : 1;	// index of value
		arg = (Argument *)arguments->data[i];
		arg->type = arg->type->semantic(loc, sc);
		tnv = arg->type->toBasetype();
		if (tnv->ty != tn->ty &&
		    (tnv->ty == Tchar || tnv->ty == Twchar || tnv->ty == Tdchar))
		{
		    if (arg->inout == InOut)
			error("foreach: value of UTF conversion cannot be inout");
		    if (dim == 2)
		    {	arg = (Argument *)arguments->data[0];
			if (arg->inout == InOut)
			    error("foreach: key cannot be inout");
		    }
		    goto Lapply;
		}
	    }

	    for (i = 0; i < dim; i++)
	    {	// Declare args
		Argument *arg = (Argument *)arguments->data[i];
		VarDeclaration *var;

		var = new VarDeclaration(0, arg->type, arg->ident, NULL);
		var->storage_class |= STCforeach;
		switch (arg->inout)
		{   case In:    var->storage_class |= STCin;          break;
		    case Out:   var->storage_class |= STCout;         break;
		    case InOut: var->storage_class |= STCin | STCout; break;
		}
		var->semantic(sc);
		if (!sc->insert(var))
		    assert(0);

		if (dim == 2 && i == 0)
		    key = var;
		else
		    value = var;
	    }

	    sc->sbreak = this;
	    sc->scontinue = this;
	    body = body->semantic(sc);

	    if (!value->type->equals(tab->next))
	    {
		if (aggr->op == TOKstring)
		    aggr = aggr->implicitCastTo(value->type->arrayOf());
		else
		    error("foreach: %s is not an array of %s", tab->toChars(), value->type->toChars());
	    }

	    if (value->storage_class & STCout && value->type->toBasetype()->ty == Tbit)
		error("foreach: value cannot be out and type bit");

	    if (key && key->type->ty != Tint32 && key->type->ty != Tuns32)
	    {
		error("foreach: key type must be int or uint, not %s", key->type->toChars());
	    }

	    if (key && key->storage_class & STCout)
		error("foreach: key cannot be out");
	    break;

	case Taarray:
	    taa = (TypeAArray *)tab;
	    if (dim < 1 || dim > 2)
	    {
		error("only one or two arguments for associative array foreach");
		break;
	    }
	case Tclass:
	case Tstruct:
	Lapply:
	{   FuncDeclaration *fdapply;
	    Array *args;
	    Expression *ec;
	    Expression *e;
	    FuncLiteralDeclaration *fld;
	    Argument *a;
	    Type *t;
	    Expression *flde;
	    Identifier *id;

	    // Need a variable to hold value from any return statements in body.
	    if (!sc->func->vresult && sc->func->type->next != Type::tvoid)
	    {	VarDeclaration *v;

		v = new VarDeclaration(loc, sc->func->type->next, Id::result, NULL);
		v->noauto = 1;
		v->semantic(sc);
		if (!sc->insert(v))
		    assert(0);
		v->parent = sc->func;
		sc->func->vresult = v;
	    }

	    /* Turn body into the function literal:
	     *	int delegate(inout T arg) { body }
	     */
	    args = new Array();
	    for (i = 0; i < dim; i++)
	    {	Argument *arg = (Argument *)arguments->data[i];

		arg->type = arg->type->semantic(loc, sc);
		if (arg->inout == InOut)
		    id = arg->ident;
		else
		{   // Make a copy of the inout argument so it isn't
		    // a reference.
		    VarDeclaration *v;
		    Initializer *ie;
		    char applyArg[10 + 4 + 1];

		    sprintf(applyArg, "__applyArg%d", i);
		    id = Lexer::idPool(applyArg);

		    ie = new ExpInitializer(0, new IdentifierExp(0, id));
		    v = new VarDeclaration(0, arg->type, arg->ident, ie);
		    s = new DeclarationStatement(0, v);
		    body = new CompoundStatement(loc, s, body);
		}
		a = new Argument(arg->type, id, InOut);
		args->push(a);
	    }
	    t = new TypeFunction(args, Type::tint32, 0, LINKd);
	    fld = new FuncLiteralDeclaration(loc, 0, t, TOKdelegate, this);
	    fld->fbody = body;
	    flde = new FuncExp(loc, fld);
	    flde = flde->semantic(sc);

	    // Resolve any forward referenced goto's
	    for (int i = 0; i < gotos.dim; i++)
	    {	CompoundStatement *cs = (CompoundStatement *)gotos.data[i];
		GotoStatement *gs = (GotoStatement *)cs->statements->data[0];

		if (!gs->label->statement)
		{   // 'Promote' it to this scope, and replace with a return
		    cases.push(gs);
		    s = new ReturnStatement(0, new IntegerExp(cases.dim + 1));
		    cs->statements->data[0] = (void *)s;
		}
	    }

	    if (tab->ty == Taarray)
	    {
		// Check types
		Argument *arg = (Argument *)arguments->data[0];
		if (dim == 2)
		{
		    if (arg->inout == InOut)
			error("foreach: index cannot be inout");
		    if (!arg->type->equals(taa->index))
			error("foreach: index must be type %s, not %s", taa->index->toChars(), arg->type->toChars());
		    arg = (Argument *)arguments->data[1];
		}
		if (!arg->type->equals(taa->next))
		    error("foreach: value must be type %s, not %s", taa->next->toChars(), arg->type->toChars());

		/* Call:
		 *	_aaApply(aggr, keysize, flde)
		 */
		if (dim == 2)
		    fdapply = FuncDeclaration::genCfunc(Type::tindex, "_aaApply2");
		else
		    fdapply = FuncDeclaration::genCfunc(Type::tindex, "_aaApply");
		ec = new VarExp(0, fdapply);
		args = new Array();
		args->push(aggr);
		args->push(new IntegerExp(0, taa->key->size(), Type::tint32));
		args->push(flde);
		e = new CallExp(loc, ec, args);
		e->type = Type::tindex;	// don't run semantic() on e
	    }
	    else if (tab->ty == Tarray || tab->ty == Tsarray)
	    {
		/* Call:
		 *	_aApply(aggr, flde)
		 */
		static char fntab[9][3] =
		{ "cc","cw","cd",
		  "wc","cc","wd",
		  "dc","dw","dd"
		};
		char fdname[10 + 1];
		int flag;

		switch (tn->ty)
		{
		    case Tchar:		flag = 0; break;
		    case Twchar:	flag = 3; break;
		    case Tdchar:	flag = 6; break;
		    default:		assert(0);
		}
		switch (tnv->ty)
		{
		    case Tchar:		flag += 0; break;
		    case Twchar:	flag += 1; break;
		    case Tdchar:	flag += 2; break;
		    default:		assert(0);
		}
		int j = sprintf(fdname, "_aApply%.*s%d", 2, fntab[flag], dim);
		assert(j < sizeof(fdname));
		fdapply = FuncDeclaration::genCfunc(Type::tindex, fdname);

		ec = new VarExp(0, fdapply);
		args = new Array();
		if (tab->ty == Tsarray)
		   aggr = aggr->castTo(tn->arrayOf());
		args->push(aggr);
		args->push(flde);
		e = new CallExp(loc, ec, args);
		e->type = Type::tindex;	// don't run semantic() on e
	    }
	    else
	    {
		/* Call:
		 *	aggr.apply(flde)
		 */
		ec = new DotIdExp(loc, aggr, Id::apply);
		args = new Array();
		args->push(flde);
		e = new CallExp(loc, ec, args);
		e = e->semantic(sc);
		if (e->type != Type::tint32)
		    error("apply() function for %s must return an int", tab->toChars());
	    }

	    if (!cases.dim)
		// Easy case, a clean exit from the loop
		s = new ExpStatement(loc, e);
	    else
	    {	// Construct a switch statement around the return value
		// of the apply function.
		Array *a = new Array();

		// default: break; takes care of cases 0 and 1
		s = new BreakStatement(0, NULL);
		s = new DefaultStatement(0, s);
		a->push(s);

		// cases 2...
		for (int i = 0; i < cases.dim; i++)
		{
		    s = (Statement *)cases.data[i];
		    s = new CaseStatement(0, new IntegerExp(i + 2), s);
		    a->push(s);
		}

		s = new CompoundStatement(loc, a);
		s = new SwitchStatement(loc, e, s);
		s = s->semantic(sc);
	    }
	    break;
	}

	default:
	    error("foreach: %s is not an aggregate type", aggr->type->toChars());
	    break;
    }
    sc->noctor--;
    sc->pop();
    return s;
}

int ForeachStatement::hasBreak()
{
    return TRUE;
}

int ForeachStatement::hasContinue()
{
    return TRUE;
}

int ForeachStatement::usesEH()
{
    return body->usesEH();
}

/******************************** IfStatement ***************************/

IfStatement::IfStatement(Loc loc, Expression *condition, Statement *ifbody, Statement *elsebody)
    : Statement(loc)
{
    this->condition = condition;
    this->ifbody = ifbody;
    this->elsebody = elsebody;
}

Statement *IfStatement::syntaxCopy()
{
    Statement *e = NULL;
    if (elsebody)
	e = elsebody->syntaxCopy();
    IfStatement *s = new IfStatement(loc, condition->syntaxCopy(), ifbody->syntaxCopy(), e);
    return s;
}

Statement *IfStatement::semantic(Scope *sc)
{
    condition = condition->semantic(sc);
    condition = resolveProperties(sc, condition);
    condition = condition->checkToBoolean();

    // If we can short-circuit evaluate the if statement, don't do the
    // semantic analysis of the skipped code.
    // This feature allows a limited form of conditional compilation.
    condition = condition->optimize(WANTflags);
    if (condition->isBool(FALSE))
    {	Statement *s;

	s = new ExpStatement(loc, condition);
	if (elsebody)
	{   elsebody = elsebody->semanticScope(sc, NULL, NULL);
	    s = new CompoundStatement(loc, s, elsebody);
	}
	return s;
    }
    else if (condition->isBool(TRUE))
    {	Statement *s;

	s = new ExpStatement(loc, condition);
	ifbody = ifbody->semanticScope(sc, NULL, NULL);
	s = new CompoundStatement(loc, s, ifbody);
	return s;
    }
    else
    {	// Evaluate at runtime
	unsigned cs0 = sc->callSuper;
	unsigned cs1;

	ifbody = ifbody->semanticScope(sc, NULL, NULL);
	cs1 = sc->callSuper;
	sc->callSuper = cs0;
	if (elsebody)
	    elsebody = elsebody->semanticScope(sc, NULL, NULL);
	sc->mergeCallSuper(loc, cs1);
    }
    return this;
}

int IfStatement::usesEH()
{
    return ifbody->usesEH() || (elsebody && elsebody->usesEH());
}

void IfStatement::toCBuffer(OutBuffer *buf)
{
    buf->printf("IfStatement::toCBuffer()");
    buf->writenl();
}

/******************************** ConditionalStatement ***************************/

ConditionalStatement::ConditionalStatement(Loc loc, Condition *condition, Statement *ifbody, Statement *elsebody)
    : Statement(loc)
{
    this->condition = condition;
    this->ifbody = ifbody;
    this->elsebody = elsebody;
}

Statement *ConditionalStatement::syntaxCopy()
{
    Statement *e = NULL;
    if (elsebody)
	e = elsebody->syntaxCopy();
    ConditionalStatement *s = new ConditionalStatement(loc,
		condition, ifbody->syntaxCopy(), e);
    return s;
}

Statement *ConditionalStatement::semantic(Scope *sc)
{
    //condition = condition->semantic(sc);

    // If we can short-circuit evaluate the if statement, don't do the
    // semantic analysis of the skipped code.
    // This feature allows a limited form of conditional compilation.
    if (condition->isBool(FALSE))
    {
	if (elsebody)
	    elsebody = elsebody->semantic(sc);
	return elsebody;
    }
    else if (condition->isBool(TRUE))
    {
	ifbody = ifbody->semantic(sc);
	return ifbody;
    }
    else
    {	Statement *s;

	// Evaluate at runtime
	s = new IfStatement(loc, condition->toExpr(), ifbody, elsebody);
	s = s->semantic(sc);
	return s;
    }
    return this;
}

int ConditionalStatement::usesEH()
{
    return ifbody->usesEH() || (elsebody && elsebody->usesEH());
}

void ConditionalStatement::toCBuffer(OutBuffer *buf)
{
    buf->printf("ConditionalStatement::toCBuffer()");
    buf->writenl();
}


/******************************** PragmaStatement ***************************/

PragmaStatement::PragmaStatement(Loc loc, Identifier *ident, Array *args, Statement *body)
    : Statement(loc)
{
    this->ident = ident;
    this->args = args;
    this->body = body;
}

Statement *PragmaStatement::syntaxCopy()
{
    Statement *b = NULL;
    if (body)
	b = body->syntaxCopy();
    PragmaStatement *s = new PragmaStatement(loc,
		ident, Expression::arraySyntaxCopy(args), b);
    return s;
}

Statement *PragmaStatement::semantic(Scope *sc)
{
    if (ident == Id::msg)
    {
        if (args)
        {
            for (size_t i = 0; i < args->dim; i++)
            {
                Expression *e = (Expression *)args->data[i];

                e = e->semantic(sc);
                if (e->op == TOKstring)
                {
                    StringExp *se = (StringExp *)e;
                    printf("%.*s", se->len, se->string);
                }
                else
                    error("string expected for pragma msg, not '%s'", e->toChars());
            }
            printf("\n");
        }
    }
    else
        error("unrecognized pragma(%s)", ident->toChars());

    if (body)
    {
	body = body->semantic(sc);
    }
    return body;
}

int PragmaStatement::usesEH()
{
    return body && body->usesEH();
}

void PragmaStatement::toCBuffer(OutBuffer *buf)
{
    buf->printf("PragmaStatement::toCBuffer()");
    buf->writenl();
}


/******************************** StaticAssertStatement ***************************/

StaticAssertStatement::StaticAssertStatement(StaticAssert *sa)
    : Statement(sa->loc)
{
    this->sa = sa;
}

Statement *StaticAssertStatement::syntaxCopy()
{
    StaticAssertStatement *s = new StaticAssertStatement((StaticAssert *)sa->syntaxCopy(NULL));
    return s;
}

Statement *StaticAssertStatement::semantic(Scope *sc)
{
    sa->semantic2(sc);
    return NULL;
}

void StaticAssertStatement::toCBuffer(OutBuffer *buf)
{
    sa->toCBuffer(buf);
}


/******************************** SwitchStatement ***************************/

SwitchStatement::SwitchStatement(Loc loc, Expression *c, Statement *b)
    : Statement(loc)
{
    condition = c;
    body = b;
    sdefault = NULL;
    cases = NULL;
}

Statement *SwitchStatement::syntaxCopy()
{
    SwitchStatement *s = new SwitchStatement(loc,
	condition->syntaxCopy(), body->syntaxCopy());
    return s;
}

Statement *SwitchStatement::semantic(Scope *sc)
{
    condition = condition->semantic(sc);
    if (condition->type->isString())
    {
	// If it's not an array, cast it to one
	if (condition->type->ty != Tarray)
	{
	    condition = condition->implicitCastTo(condition->type->next->arrayOf());
	}
    }
    else
    {	condition = condition->integralPromotions();
	condition->checkIntegral();
    }

    sc = sc->push();
    sc->sbreak = this;
    sc->sw = this;

    cases = new Array();
    sc->noctor++;	// BUG: should use Scope::mergeCallSuper() for each case instead
    body = body->semantic(sc);
    sc->noctor--;

    // Resolve any goto case's with exp
    for (int i = 0; i < gotoCases.dim; i++)
    {
	GotoCaseStatement *gcs = (GotoCaseStatement *)gotoCases.data[i];

	if (!gcs->exp)
	{
	    gcs->error("no case statement following goto case;");
	    break;
	}

	for (int j = 0; 1; j++)
	{
	    if (j == cases->dim)
	    {
		gcs->error("case %s not found", gcs->exp->toChars());
		break;
	    }
	    CaseStatement *cs = (CaseStatement *)cases->data[j];

	    if (cs->exp->equals(gcs->exp))
	    {
		gcs->cs = cs;
		break;
	    }
	}
    }

    if (!sc->sw->sdefault && global.params.useSwitchError)
    {
	Array *a = new Array();
	CompoundStatement *cs;

	a->reserve(4);
	a->push(body);
	a->push(new BreakStatement(loc, NULL));
	sc->sw->sdefault = new DefaultStatement(loc, new SwitchErrorStatement(loc));
	a->push(sc->sw->sdefault);
	cs = new CompoundStatement(loc, a);
	body = cs;
    }

    sc->pop();
    return this;
}

int SwitchStatement::hasBreak()
{
    return TRUE;
}

int SwitchStatement::usesEH()
{
    return body->usesEH();
}

/******************************** CaseStatement ***************************/

CaseStatement::CaseStatement(Loc loc, Expression *exp, Statement *s)
    : Statement(loc)
{
    this->exp = exp;
    this->statement = s;
    cblock = NULL;
}

Statement *CaseStatement::syntaxCopy()
{
    CaseStatement *s = new CaseStatement(loc, exp->syntaxCopy(), statement->syntaxCopy());
    return s;
}

Statement *CaseStatement::semantic(Scope *sc)
{   SwitchStatement *sw = sc->sw;

    exp = exp->semantic(sc);
    if (sw)
    {	int i;

	exp = exp->implicitCastTo(sw->condition->type);
	exp = exp->constFold();

	for (i = 0; i < sw->cases->dim; i++)
	{
	    CaseStatement *cs = (CaseStatement *)sw->cases->data[i];

	    if (cs->exp->equals(exp))
	    {	error("duplicate case %s in switch statement", exp->toChars());
		break;
	    }
	}

	sw->cases->push(this);

	// Resolve any goto case's with no exp to this case statement
	for (i = 0; i < sw->gotoCases.dim; i++)
	{
	    GotoCaseStatement *gcs = (GotoCaseStatement *)sw->gotoCases.data[i];

	    if (!gcs->exp)
	    {
		gcs->cs = this;
		sw->gotoCases.remove(i);	// remove from array
	    }
	}
    }
    else
	error("case not in switch statement");
    statement = statement->semantic(sc);
    return this;
}

int CaseStatement::compare(Object *obj)
{
    // Sort cases so we can do an efficient lookup
    CaseStatement *cs2 = (CaseStatement *)(obj);

    return exp->compare(cs2->exp);
}

int CaseStatement::usesEH()
{
    return statement->usesEH();
}

/******************************** DefaultStatement ***************************/

DefaultStatement::DefaultStatement(Loc loc, Statement *s)
    : Statement(loc)
{
    this->statement = s;
}

Statement *DefaultStatement::syntaxCopy()
{
    DefaultStatement *s = new DefaultStatement(loc, statement->syntaxCopy());
    return s;
}

Statement *DefaultStatement::semantic(Scope *sc)
{
    if (sc->sw)
    {
	if (sc->sw->sdefault)
	    error("switch statement already has a default");
	sc->sw->sdefault = this;
    }
    else
	error("default not in switch statement");
    statement = statement->semantic(sc);
    return this;
}

int DefaultStatement::usesEH()
{
    return statement->usesEH();
}

/******************************** GotoDefaultStatement ***************************/

GotoDefaultStatement::GotoDefaultStatement(Loc loc)
    : Statement(loc)
{
    sw = NULL;
}

Statement *GotoDefaultStatement::syntaxCopy()
{
    GotoDefaultStatement *s = new GotoDefaultStatement(loc);
    return s;
}

Statement *GotoDefaultStatement::semantic(Scope *sc)
{
    sw = sc->sw;
    if (!sw)
	error("goto default not in switch statement");
    return this;
}

/******************************** GotoCaseStatement ***************************/

GotoCaseStatement::GotoCaseStatement(Loc loc, Expression *exp)
    : Statement(loc)
{
    cs = NULL;
    this->exp = exp;
}

Statement *GotoCaseStatement::syntaxCopy()
{
    Expression *e = exp ? exp->syntaxCopy() : NULL;
    GotoCaseStatement *s = new GotoCaseStatement(loc, e);
    return s;
}

Statement *GotoCaseStatement::semantic(Scope *sc)
{
    if (exp)
	exp = exp->semantic(sc);

    if (!sc->sw)
	error("goto case not in switch statement");
    else
    {
	sc->sw->gotoCases.push(this);
	if (exp)
	{
	    exp = exp->implicitCastTo(sc->sw->condition->type);
	    exp = exp->constFold();
	}
    }
    return this;
}

/******************************** SwitchErrorStatement ***************************/

SwitchErrorStatement::SwitchErrorStatement(Loc loc)
    : Statement(loc)
{
}

/******************************** ReturnStatement ***************************/

ReturnStatement::ReturnStatement(Loc loc, Expression *exp)
    : Statement(loc)
{
    this->exp = exp;
}

Statement *ReturnStatement::syntaxCopy()
{
    Expression *e = NULL;
    if (exp)
	e = exp->syntaxCopy();
    ReturnStatement *s = new ReturnStatement(loc, e);
    return s;
}

Statement *ReturnStatement::semantic(Scope *sc)
{
    FuncDeclaration *fd = sc->parent->isFuncDeclaration();
    FuncDeclaration *fdx = fd;
    Type *tret = fd->type->next;
    Type *tbret = tret->toBasetype();

    Scope *scx = sc;
    if (sc->fes)
    {
	Statement *s;

	// Find scope of function foreach is in
	for (; 1; scx = scx->enclosing)
	{
	    assert(scx);
	    if (scx->func != fd)
	    {	fdx = scx->func;
		break;
	    }
	}

	if (exp)
	{   exp = exp->semantic(sc);
	    exp = resolveProperties(sc, exp);
	    exp = exp->implicitCastTo(fdx->type->next);
	}
	if (!exp || exp->op == TOKint64 || exp->op == TOKfloat64 ||
	    exp->op == TOKimaginary80 || exp->op == TOKcomplex80 ||
	    exp->op == TOKthis || exp->op == TOKsuper || exp->op == TOKnull ||
	    exp->op == TOKstring)
	{
	    sc->fes->cases.push(this);
	    s = new ReturnStatement(0, new IntegerExp(sc->fes->cases.dim + 1));
	}
	else
	{
	    VarExp *v;
	    Statement *s1;
	    Statement *s2;

	    // Construct: return vresult;
	    assert(fdx->vresult);
	    v = new VarExp(0, fdx->vresult);
	    s = new ReturnStatement(0, v);
	    sc->fes->cases.push(s);

	    // Construct: { vresult = exp; return cases.dim + 1; }
	    v = new VarExp(0, fdx->vresult);
	    exp = new AssignExp(loc, v, exp);
	    exp = exp->semantic(sc);
	    s1 = new ExpStatement(loc, exp);
	    s2 = new ReturnStatement(0, new IntegerExp(sc->fes->cases.dim + 1));
	    s = new CompoundStatement(loc, s1, s2);
	}
	return s;
    }

    if (sc->incontract)
	error("return statements cannot be in contracts");

    if (fd->isCtorDeclaration())
    {
	// Constructors implicitly do:
	//	return this;
	if (exp && exp->op != TOKthis)
	    error("cannot return expression from constructor");
	exp = new ThisExp(0);
    }

    if (exp)
    {
	fd->hasReturnExp = 1;

	if (fd->returnLabel && tbret->ty != Tvoid)
	{
	    assert(fd->vresult);
	    VarExp *v = new VarExp(0, fd->vresult);

	    exp = resolveProperties(sc, exp);
	    exp = new AssignExp(loc, v, exp);
	    exp = exp->semantic(sc);
	}
	else
	{
	    exp = exp->semantic(sc);
	    exp = resolveProperties(sc, exp);
	    exp = exp->implicitCastTo(tret);
	}
    }
    else if (tbret->ty != Tvoid)	// if non-void return
	error("return expression expected");

    /* BUG: need to issue an error on:
     *	this
     *	{   if (x) return;
     *	    super();
     *	}
     */

    if (sc->callSuper & CSXany_ctor &&
	!(sc->callSuper & (CSXthis_ctor | CSXsuper_ctor)))
	error("return without calling constructor");

    sc->callSuper |= CSXreturn;

    // See if all returns are instead to be replaced with a goto returnLabel;
    if (fd->returnLabel)
    {
	GotoStatement *gs = new GotoStatement(loc, Id::returnLabel);

	gs->label = fd->returnLabel;
	if (exp)
	{   Statement *s;

	    s = new ExpStatement(loc, exp);
	    return new CompoundStatement(loc, s, gs);
	}
	return gs;
    }

    return this;
}

void ReturnStatement::toCBuffer(OutBuffer *buf)
{
    buf->printf("return ");
    if (exp)
	exp->toCBuffer(buf);
    buf->writeByte(';');
    buf->writenl();
}

/******************************** BreakStatement ***************************/

BreakStatement::BreakStatement(Loc loc, Identifier *ident)
    : Statement(loc)
{
    this->ident = ident;
}

Statement *BreakStatement::syntaxCopy()
{
    BreakStatement *s = new BreakStatement(loc, ident);
    return s;
}

Statement *BreakStatement::semantic(Scope *sc)
{
    if (ident)
    {
	Scope *scx;
	FuncDeclaration *thisfunc = sc->func;

	for (scx = sc; scx; scx = scx->enclosing)
	{
	    LabelStatement *ls;

	    if (scx->func != thisfunc)	// if in enclosing function
	    {
		if (sc->fes)		// if this is the body of a foreach
		{
		    /* Post this statement to the fes, and replace
		     * it with a return value that caller will put into
		     * a switch. Caller will figure out where the break
		     * label actually is.
		     * Case numbers start with 2, not 0, as 0 is continue
		     * and 1 is break.
		     */
		    Statement *s;
		    sc->fes->cases.push(this);
		    s = new ReturnStatement(0, new IntegerExp(sc->fes->cases.dim + 1));
		    return s;
		}
		break;			// can't break to it
	    }

	    ls = scx->slabel;
	    if (ls && ls->ident == ident)
	    {
		Statement *s = ls->statement;

		if (!s->hasBreak())
		    error("label '%s' has no break", ident->toChars());
		return this;
	    }
	}
	error("enclosing label '%s' for break not found", ident->toChars());
    }
    else if (!sc->sbreak)
    {
	if (sc->fes)
	{   Statement *s;

	    // Replace break; with return 1;
	    s = new ReturnStatement(0, new IntegerExp(1));
	    return s;
	}
	error("break is not inside a loop or switch");
    }
    return this;
}

/******************************** ContinueStatement ***************************/

ContinueStatement::ContinueStatement(Loc loc, Identifier *ident)
    : Statement(loc)
{
    this->ident = ident;
}

Statement *ContinueStatement::syntaxCopy()
{
    ContinueStatement *s = new ContinueStatement(loc, ident);
    return s;
}

Statement *ContinueStatement::semantic(Scope *sc)
{
    if (ident)
    {
	Scope *scx;
	FuncDeclaration *thisfunc = sc->func;

	for (scx = sc; scx; scx = scx->enclosing)
	{
	    LabelStatement *ls;

	    if (scx->func != thisfunc)	// if in enclosing function
	    {
		if (sc->fes)		// if this is the body of a foreach
		{
		    /* Post this statement to the fes, and replace
		     * it with a return value that caller will put into
		     * a switch. Caller will figure out where the break
		     * label actually is.
		     * Case numbers start with 2, not 0, as 0 is continue
		     * and 1 is break.
		     */
		    Statement *s;
		    sc->fes->cases.push(this);
		    s = new ReturnStatement(0, new IntegerExp(sc->fes->cases.dim + 1));
		    return s;
		}
		break;			// can't continue to it
	    }

	    ls = scx->slabel;
	    if (ls && ls->ident == ident)
	    {
		Statement *s = ls->statement;

		if (!s->hasContinue())
		    error("label '%s' has no continue", ident->toChars());
		return this;
	    }
	}
	error("enclosing label '%s' for continue not found", ident->toChars());
    }
    else if (!sc->scontinue)
    {
	if (sc->fes)
	{   Statement *s;

	    // Replace continue; with return 0;
	    s = new ReturnStatement(0, new IntegerExp(0));
	    return s;
	}
	error("continue is not inside a loop");
    }
    return this;
}

/******************************** SynchronizedStatement ***************************/

SynchronizedStatement::SynchronizedStatement(Loc loc, Expression *exp, Statement *body)
    : Statement(loc)
{
    this->exp = exp;
    this->body = body;
    this->esync = NULL;
}

SynchronizedStatement::SynchronizedStatement(Loc loc, elem *esync, Statement *body)
    : Statement(loc)
{
    this->exp = NULL;
    this->body = body;
    this->esync = esync;
}

Statement *SynchronizedStatement::syntaxCopy()
{
    Expression *e = exp ? exp->syntaxCopy() : NULL;
    SynchronizedStatement *s = new SynchronizedStatement(loc, e, body->syntaxCopy());
    return s;
}

Statement *SynchronizedStatement::semantic(Scope *sc)
{
    if (exp)
    {
	exp = exp->semantic(sc);
	if (!exp->type->isClassHandle())
	    error("can only synchronize on class objects, not '%s'", exp->type->toChars());
    }
    body = body->semantic(sc);
    return this;
}

int SynchronizedStatement::hasBreak()
{
    return TRUE;
}

int SynchronizedStatement::hasContinue()
{
    return TRUE;
}

int SynchronizedStatement::usesEH()
{
    return TRUE;
}

/******************************** WithStatement ***************************/

WithStatement::WithStatement(Loc loc, Expression *exp, Statement *body)
    : Statement(loc)
{
    this->exp = exp;
    this->body = body;
    wthis = NULL;
}

Statement *WithStatement::syntaxCopy()
{
    WithStatement *s = new WithStatement(loc, exp->syntaxCopy(), body->syntaxCopy());
    return s;
}

Statement *WithStatement::semantic(Scope *sc)
{   ScopeDsymbol *sym;
    Initializer *init;

    exp = exp->semantic(sc);
    if (exp->op == TOKimport)
    {	ScopeExp *es = (ScopeExp *)exp;

	sym = es->sds;
    }
    else
    {	Type *t = exp->type;

	assert(t);
	t = t->toBasetype();
	if (t->isClassHandle())
	{
	    init = new ExpInitializer(loc, exp);
	    wthis = new VarDeclaration(loc, exp->type, Id::withSym, init);
	    wthis->semantic(sc);

	    sym = new WithScopeSymbol(this);
	    sym->parent = sc->scopesym;
	}
	else if (t->ty == Tstruct)
	{
	    Expression *e = exp->addressOf();
	    init = new ExpInitializer(loc, e);
	    wthis = new VarDeclaration(loc, e->type, Id::withSym, init);
	    wthis->semantic(sc);
	    sym = new WithScopeSymbol(this);
	    sym->parent = sc->scopesym;
	}
	else
	{   error("with expressions must be class objects, not '%s'", exp->type->toChars());
	    return NULL;
	}
    }
    sc = sc->push(sym);

    body = body->semantic(sc);

    sc->pop();

    return this;
}

void WithStatement::toCBuffer(OutBuffer *buf)
{
    buf->writestring("with (");
    exp->toCBuffer(buf);
    buf->writestring(")\n{\n");
    body->toCBuffer(buf);
    buf->writestring("\n}\n");
}

int WithStatement::usesEH()
{
    return body->usesEH();
}

/******************************** TryCatchStatement ***************************/

TryCatchStatement::TryCatchStatement(Loc loc, Statement *body, Array *catches)
    : Statement(loc)
{
    this->body = body;
    this->catches = catches;
}

Statement *TryCatchStatement::syntaxCopy()
{
    Array *a = new Array();
    a->setDim(catches->dim);
    for (int i = 0; i < a->dim; i++)
    {   Catch *c;

	c = (Catch *)catches->data[i];
	c = c->syntaxCopy();
	a->data[i] = c;
    }
    TryCatchStatement *s = new TryCatchStatement(loc, body->syntaxCopy(), a);
    return s;
}

Statement *TryCatchStatement::semantic(Scope *sc)
{
    body = body->semanticScope(sc, this, NULL);

    for (int i = 0; i < catches->dim; i++)
    {   Catch *c;

	c = (Catch *)catches->data[i];
	c->semantic(sc);
    }
    return this;
}

int TryCatchStatement::hasBreak()
{
    return TRUE;
}

int TryCatchStatement::usesEH()
{
    return TRUE;
}

/******************************** Catch ***************************/

Catch::Catch(Loc loc, Type *t, Identifier *id, Statement *handler)
{
    this->loc = loc;
    this->type = t;
    this->ident = id;
    this->handler = handler;
    var = NULL;
}

Catch *Catch::syntaxCopy()
{
    Catch *c = new Catch(loc,
	(type ? type->syntaxCopy() : NULL),
	ident, handler->syntaxCopy());
    return c;
}

void Catch::semantic(Scope *sc)
{   ScopeDsymbol *sym;

    //printf("Catch::semantic()\n");

    sym = new ScopeDsymbol();
    sym->parent = sc->scopesym;
    sc = sc->push(sym);

    if (!type)
	type = new TypeIdentifier(0, Id::Object);
    type = type->semantic(loc, sc);
    if (!type->isClassHandle())
	error("can only catch class objects, not '%s'", type->toChars());
    else if (ident)
    {
	var = new VarDeclaration(loc, type, ident, NULL);
	var->parent = sc->parent;
	sc->insert(var);
    }
    handler = handler->semantic(sc);

    sc->pop();
}

/******************************** TryFinallyStatement ***************************/

TryFinallyStatement::TryFinallyStatement(Loc loc, Statement *body, Statement *finalbody)
    : Statement(loc)
{
    this->body = body;
    this->finalbody = finalbody;
}

Statement *TryFinallyStatement::syntaxCopy()
{
    TryFinallyStatement *s = new TryFinallyStatement(loc,
	body->syntaxCopy(), finalbody->syntaxCopy());
    return s;
}

Statement *TryFinallyStatement::semantic(Scope *sc)
{
    body = body->semantic(sc);
    finalbody = finalbody->semantic(sc);
    return this;
}

void TryFinallyStatement::toCBuffer(OutBuffer *buf)
{
    buf->printf("TryFinallyStatement::toCBuffer()");
    buf->writenl();
}

int TryFinallyStatement::hasBreak()
{
    return TRUE;
}

int TryFinallyStatement::hasContinue()
{
    return TRUE;
}

int TryFinallyStatement::usesEH()
{
    return TRUE;
}

/******************************** ThrowStatement ***************************/

ThrowStatement::ThrowStatement(Loc loc, Expression *exp)
    : Statement(loc)
{
    this->exp = exp;
}

Statement *ThrowStatement::syntaxCopy()
{
    ThrowStatement *s = new ThrowStatement(loc, exp->syntaxCopy());
    return s;
}

Statement *ThrowStatement::semantic(Scope *sc)
{
    //printf("ThrowStatement::semantic()\n");
    if (sc->incontract)
	error("Throw statements cannot be in contracts");
    exp = exp->semantic(sc);
    if (!exp->type->isClassHandle())
	error("can only throw class objects, not type %s", exp->type->toChars());
    return this;
}

/******************************** VolatileStatement **************************/

VolatileStatement::VolatileStatement(Loc loc, Statement *statement)
    : Statement(loc)
{
    this->statement = statement;
}

Statement *VolatileStatement::syntaxCopy()
{
    VolatileStatement *s = new VolatileStatement(loc, statement);
    return s;
}

Statement *VolatileStatement::semantic(Scope *sc)
{
    statement = statement->semantic(sc);
    return this;
}

Array *VolatileStatement::flatten()
{
    Array *a;

    a = statement->flatten();
    if (a)
    {	for (int i = 0; i < a->dim; i++)
	{   Statement *s = (Statement *)a->data[i];

	    s = new VolatileStatement(loc, s);
	    a->data[i] = s;
	}
    }

    return a;
}



/******************************** GotoStatement ***************************/

GotoStatement::GotoStatement(Loc loc, Identifier *ident)
    : Statement(loc)
{
    this->ident = ident;
    this->label = NULL;
}

Statement *GotoStatement::syntaxCopy()
{
    GotoStatement *s = new GotoStatement(loc, ident);
    return s;
}

Statement *GotoStatement::semantic(Scope *sc)
{   FuncDeclaration *fd = sc->parent->isFuncDeclaration();

    //printf("GotoStatement::semantic()\n");
    label = fd->searchLabel(ident);
    if (!label->statement && sc->fes)
    {
	/* Either the goto label is forward referenced or it
	 * is in the function that the enclosing foreach is in.
	 * Can't know yet, so wrap the goto in a compound statement
	 * so we can patch it later, and add it to a 'look at this later'
	 * list.
	 */
	Array *a = new Array();
	Statement *s;

	a->push(this);
	s = new CompoundStatement(loc, a);
	sc->fes->gotos.push(s);		// 'look at this later' list
	return s;
    }
    return this;
}

/******************************** LabelStatement ***************************/

LabelStatement::LabelStatement(Loc loc, Identifier *ident, Statement *statement)
    : Statement(loc)
{
    this->ident = ident;
    this->statement = statement;
    this->lblock = NULL;
    this->isReturnLabel = 0;
}

Statement *LabelStatement::syntaxCopy()
{
    LabelStatement *s = new LabelStatement(loc, ident, statement->syntaxCopy());
    return s;
}

Statement *LabelStatement::semantic(Scope *sc)
{   LabelDsymbol *ls;
    FuncDeclaration *fd = sc->parent->isFuncDeclaration();

    sc = sc->push();
    sc->callSuper |= CSXlabel;
    sc->slabel = this;
    statement = statement->semantic(sc);
    ls = fd->searchLabel(ident);
    sc->pop();
    if (ls->statement)
	error("Label '%s' already defined", ls->toChars());
    else
	ls->statement = this;
    return this;
}

Array *LabelStatement::flatten()
{
    Array *a;

    a = statement->flatten();
    if (a)
    {
	Statement *s = (Statement *)a->data[0];

	s = new LabelStatement(loc, ident, s);
	a->data[0] = s;
    }

    return a;
}


int LabelStatement::usesEH()
{
    return statement->usesEH();
}

/******************************** LabelDsymbol ***************************/

LabelDsymbol::LabelDsymbol(Identifier *ident)
	: Dsymbol(ident)
{
    statement = NULL;
}

LabelDsymbol *LabelDsymbol::isLabel()		// is this a LabelDsymbol()?
{
    return this;
}


