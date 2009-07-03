
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

#include "mem.h"

#include "statement.h"
#include "expression.h"
#include "cond.h"
#include "init.h"
#include "staticassert.h"
#include "mtype.h"
#include "scope.h"
#include "declaration.h"
#include "aggregate.h"
#include "id.h"
#include "hdrgen.h"

/******************************** Statement ***************************/

Statement::Statement(Loc loc)
    : loc(loc)
{
#ifdef _DH
    // If this is an in{} contract scope statement (skip for determining
    //  inlineStatus of a function body for header content)
    incontract = 0;
#endif
}

Statement *Statement::syntaxCopy()
{
    assert(0);
    return NULL;
}

void Statement::print()
{
    fprintf(stdmsg, "%s\n", toChars());
    fflush(stdmsg);
}

char *Statement::toChars()
{   OutBuffer *buf;
    HdrGenState hgs;

    buf = new OutBuffer();
    toCBuffer(buf, &hgs);
    return buf->toChars();
}

void Statement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
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

// TRUE if statement may fall off the end without a throw or return

int Statement::fallOffEnd()
{
    return TRUE;
}

// TRUE if statement 'comes from' somewhere else, like a goto

int Statement::comeFrom()
{
    return FALSE;
}

/****************************************
 * If this statement has code that needs to run in a finally clause
 * at the end of the current scope, return that code in the form of
 * a Statement.
 * Output:
 *	*sentry		code executed upon entry to the scope
 *	*sexception	code executed upon exit from the scope via exception
 *	*sfinally	code executed in finally block
 */

void Statement::scopeCode(Statement **sentry, Statement **sexception, Statement **sfinally)
{
    //printf("Statement::scopeCode()\n");
    //print();
    *sentry = NULL;
    *sexception = NULL;
    *sfinally = NULL;
}

/*********************************
 * Flatten out the scope by presenting the statement
 * as an array of statements.
 * Returns NULL if no flattening necessary.
 */

Statements *Statement::flatten()
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

void ExpStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    if (exp)
	exp->toCBuffer(buf, hgs);
    buf->writeByte(';');
    if (!hgs->FLinit.init)
        buf->writenl();
}

Statement *ExpStatement::semantic(Scope *sc)
{
    if (exp)
    {
	//printf("ExpStatement::semantic() %s\n", exp->toChars());
	exp = exp->semantic(sc);
	exp = resolveProperties(sc, exp);
	exp->checkSideEffect(0);
	exp = exp->optimize(WANTvalue);
    }
    return this;
}

int ExpStatement::fallOffEnd()
{
    if (exp)
    {
	if (exp->op == TOKassert)
	{   AssertExp *a = (AssertExp *)exp;

	    if (a->e1->isBool(FALSE))	// if it's an assert(0)
		return FALSE;
	}
	else if (exp->op == TOKhalt)
	    return FALSE;
    }
    return TRUE;
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

void DeclarationStatement::scopeCode(Statement **sentry, Statement **sexception, Statement **sfinally)
{
    //printf("DeclarationStatement::scopeCode()\n");
    //print();

    *sentry = NULL;
    *sexception = NULL;
    *sfinally = NULL;

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
		    *sfinally = new ExpStatement(loc, e);
		}
	    }
	}
    }
}

void DeclarationStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    exp->toCBuffer(buf, hgs);
}


/******************************** CompoundStatement ***************************/

CompoundStatement::CompoundStatement(Loc loc, Statements *s)
    : Statement(loc)
{
    statements = s;
}

CompoundStatement::CompoundStatement(Loc loc, Statement *s1, Statement *s2)
    : Statement(loc)
{
    statements = new Statements();
    statements->reserve(2);
    statements->push(s1);
    statements->push(s2);
}

Statement *CompoundStatement::syntaxCopy()
{
    Statements *a = new Statements();
    a->setDim(statements->dim);
    for (size_t i = 0; i < statements->dim; i++)
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

    /* Start by flattening it
     */

    for (size_t i = 0; i < statements->dim; i++)
    {
      L1:
	s = (Statement *) statements->data[i];
	if (s)
	{   Statements *a = s->flatten();

	    if (a)
	    {
		statements->remove(i);
		statements->insert(i, a);
		if (i >= statements->dim)
		    break;
		goto L1;
	    }
	}
    }

    for (size_t i = 0; i < statements->dim; i++)
    {
	s = (Statement *) statements->data[i];
	if (s)
	{
	    s = s->semantic(sc);
	    statements->data[i] = s;
	    if (s)
	    {
		Statement *sentry;
		Statement *sexception;
		Statement *sfinally;

		s->scopeCode(&sentry, &sexception, &sfinally);
		if (sentry)
		{
		    sentry = sentry->semantic(sc);
		    statements->data[i] = sentry;
		}
		if (sexception)
		{
		    if (i + 1 == statements->dim && !sfinally)
		    {
#if 1
			sexception = sexception->semantic(sc);
#else
			statements->push(sexception);
			if (sfinally)
			    // Assume sexception does not throw
			    statements->push(sfinally);
#endif
		    }
		    else
		    {
			/* Rewrite:
			 *	s; s1; s2;
			 * As:
			 *	s;
			 *	try { s1; s2; }
			 *	catch (Object __o)
			 *	{ sexception; throw __o; }
			 */
			Statement *body;
			Statements *a = new Statements();

			for (int j = i + 1; j < statements->dim; j++)
			{
			    a->push(statements->data[j]);
			}
			body = new CompoundStatement(0, a);
			body = new ScopeStatement(0, body);

			char name[3 + sizeof(int) * 3 + 1];
			static int num;
			sprintf(name, "__o%d", ++num);
			Identifier *id = Lexer::idPool(name);

			Statement *handler = new ThrowStatement(0, new IdentifierExp(0, id));
			handler = new CompoundStatement(0, sexception, handler);

			Array *catches = new Array();
			Catch *ctch = new Catch(0, NULL, id, handler);
			catches->push(ctch);
			s = new TryCatchStatement(0, body, catches);

			if (sfinally)
			    s = new TryFinallyStatement(0, s, sfinally);
			s = s->semantic(sc);
			statements->setDim(i + 1);
			statements->push(s);
			break;
		    }
		}
		else if (sfinally)
		{
		    if (0 && i + 1 == statements->dim)
		    {
			statements->push(sfinally);
		    }
		    else
		    {
			/* Rewrite:
			 *	s; s1; s2;
			 * As:
			 *	s; try { s1; s2; } finally { sfinally; }
			 */
			Statement *body;
			Statements *a = new Statements();

			for (int j = i + 1; j < statements->dim; j++)
			{
			    a->push(statements->data[j]);
			}
			body = new CompoundStatement(0, a);
			s = new TryFinallyStatement(0, body, sfinally);
			s = s->semantic(sc);
			statements->setDim(i + 1);
			statements->push(s);
			break;
		    }
		}
	    }
	}
    }
    if (statements->dim == 1)
	return s;
    return this;
}

Statements *CompoundStatement::flatten()
{
    return statements;
}

ReturnStatement *CompoundStatement::isReturnStatement()
{   int i;
    ReturnStatement *rs = NULL;

    for (i = 0; i < statements->dim; i++)
    {	Statement *s;

	s = (Statement *) statements->data[i];
	if (s)
	{
	    rs = s->isReturnStatement();
	    if (rs)
		break;
	}
    }
    return rs;
}

void CompoundStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{   int i;

    for (i = 0; i < statements->dim; i++)
    {	Statement *s;

	s = (Statement *) statements->data[i];
	if (s)
	    s->toCBuffer(buf, hgs);
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

int CompoundStatement::fallOffEnd()
{   int falloff = TRUE;

    //printf("CompoundStatement::fallOffEnd()\n");
    for (int i = 0; i < statements->dim; i++)
    {	Statement *s = (Statement *)statements->data[i];

	if (!s)
	    continue;

	if (!falloff && global.params.warnings && !s->comeFrom())
	{
	    fprintf(stdmsg, "warning - ");
	    s->error("statement is not reachable");
	}
	falloff = s->fallOffEnd();
    }
    return falloff;
}

int CompoundStatement::comeFrom()
{   int comefrom = FALSE;

    //printf("CompoundStatement::comeFrom()\n");
    for (int i = 0; i < statements->dim; i++)
    {	Statement *s = (Statement *)statements->data[i];

	if (!s)
	    continue;

	comefrom |= s->comeFrom();
    }
    return comefrom;
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
    {	Statements *a;

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
	    Statement *sentry;
	    Statement *sexception;
	    Statement *sfinally;

	    statement->scopeCode(&sentry, &sexception, &sfinally);
	    if (sfinally)
	    {
		//printf("adding sfinally\n");
		statement = new CompoundStatement(loc, statement, sfinally);
	    }
	}

	sc->pop();
    }
    return this;
}

int ScopeStatement::fallOffEnd()
{
    return statement ? statement->fallOffEnd() : TRUE;
}

void ScopeStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writeByte('{');
    buf->writenl();

    if (statement)
	statement->toCBuffer(buf, hgs);

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
#if 0
    if (condition->op == TOKmatch)
    {
	/* Rewrite while (condition) body as:
	 *   if (condition)
	 *     do
	 *       body
	 *     while ((_match = _match.opNext), _match);
	 */

	Expression *ew = new IdentifierExp(0, Id::_match);
	ew = new DotIdExp(0, ew, Id::next);
	ew = new AssignExp(0, new IdentifierExp(0, Id::_match), ew);
	////ew = new EqualExp(TOKnotequal, 0, ew, new NullExp(0));
	Expression *ev = new IdentifierExp(0, Id::_match);
	//ev = new CastExp(0, ev, Type::tvoidptr);
	ew = new CommaExp(0, ew, ev);
	Statement *sw = new DoStatement(loc, body, ew);
	Statement *si = new IfStatement(loc, condition, sw, NULL);
	return si->semantic(sc);
    }
#endif

    condition = condition->semantic(sc);
    condition = resolveProperties(sc, condition);
    condition = condition->checkToBoolean();

    sc->noctor++;

    Scope *scd = sc->push();
    scd->sbreak = this;
    scd->scontinue = this;
    body = body->semantic(scd);
    scd->pop();

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

int WhileStatement::fallOffEnd()
{
    body->fallOffEnd();
    return TRUE;
}

int WhileStatement::comeFrom()
{
    if (body)
	return body->comeFrom();
    return FALSE;
}

void WhileStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("while (");
    condition->toCBuffer(buf, hgs);
    buf->writebyte(')');
    buf->writenl();
    body->toCBuffer(buf, hgs);
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

int DoStatement::fallOffEnd()
{
    body->fallOffEnd();
    return TRUE;
}

int DoStatement::comeFrom()
{
    if (body)
	return body->comeFrom();
    return FALSE;
}

void DoStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("do");
    buf->writenl();
    body->toCBuffer(buf, hgs);
    buf->writestring("while (");
    condition->toCBuffer(buf, hgs);
    buf->writebyte(')');
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

int ForStatement::fallOffEnd()
{
    if (body)
	body->fallOffEnd();
    return TRUE;
}

int ForStatement::comeFrom()
{
    if (body)
	return body->comeFrom();
    return FALSE;
}

void ForStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("for (");
    if (init)
    {
        hgs->FLinit.init++;
        hgs->FLinit.decl = 0;
        init->toCBuffer(buf, hgs);
        if (hgs->FLinit.decl > 0)
            buf->writebyte(';');
        hgs->FLinit.decl = 0;
        hgs->FLinit.init--;
    }
    else
        buf->writebyte(';');
    if (condition)
    {   buf->writebyte(' ');
        condition->toCBuffer(buf, hgs);
    }
    buf->writebyte(';');
    if (increment)
    {   buf->writebyte(' ');
        increment->toCBuffer(buf, hgs);
    }
    buf->writebyte(')');
    buf->writenl();
    buf->writebyte('{');
    buf->writenl();
    body->toCBuffer(buf, hgs);
    buf->writebyte('}');
    buf->writenl();
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

    this->func = NULL;
}

Statement *ForeachStatement::syntaxCopy()
{
    Array *args = Argument::arraySyntaxCopy(arguments);
    Expression *exp = aggr->syntaxCopy();
    ForeachStatement *s = new ForeachStatement(loc, args, exp, body->syntaxCopy());
    return s;
}

Statement *ForeachStatement::semantic(Scope *sc)
{
    //printf("ForeachStatement::semantic() %p\n", this);
    ScopeDsymbol *sym;
    Statement *s = this;
    int dim = arguments->dim;
    int i;
    TypeAArray *taa = NULL;

    Type *tn = NULL;
    Type *tnv = NULL;

    func = sc->func;
    if (func->fes)
	func = func->fes->func;

    aggr = aggr->semantic(sc);
    aggr = resolveProperties(sc, aggr);

    inferApplyArgTypes(arguments, aggr->type);

    /* Check for inference errors
     */
    if (dim != arguments->dim)
    {
	//printf("dim = %d, arguments->dim = %d\n", dim, arguments->dim);
	error("cannot uniquely infer foreach argument types");
	return this;
    }
    for (i = 0; i < dim; i++)
    {	Argument *arg = (Argument *)arguments->data[i];
	if (!arg->type)
	{
	    error("cannot infer type for %s", arg->ident->toChars());
	    return this;
	}
    }

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
		    default: assert(0);
		}
		var->semantic(sc);
		if (!sc->insert(var))
		    error("%s already defined", var->ident->toChars());

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
	    Expressions *args;
	    Expression *ec;
	    Expression *e;
	    FuncLiteralDeclaration *fld;
	    Argument *a;
	    Type *t;
	    Expression *flde;
	    Identifier *id;
	    Type *tret;

	    tret = func->type->next;

	    // Need a variable to hold value from any return statements in body.
	    if (!sc->func->vresult && tret != Type::tvoid)
	    {	VarDeclaration *v;

		v = new VarDeclaration(loc, tret, Id::result, NULL);
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
	    args = new Expressions();
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
		a = new Argument(InOut, arg->type, id, NULL);
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
		args = new Expressions();
		args->push(aggr);
		size_t keysize = taa->key->size();
		keysize = (keysize + 3) & ~3;
		args->push(new IntegerExp(0, keysize, Type::tint32));
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
		args = new Expressions();
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
		args = new Expressions();
		args->push(flde);
		e = new CallExp(loc, ec, args);
		e = e->semantic(sc);
		if (e->type != Type::tint32)
		    error("opApply() function for %s must return an int", tab->toChars());
	    }

	    if (!cases.dim)
		// Easy case, a clean exit from the loop
		s = new ExpStatement(loc, e);
	    else
	    {	// Construct a switch statement around the return value
		// of the apply function.
		Statements *a = new Statements();

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

int ForeachStatement::fallOffEnd()
{
    if (body)
	body->fallOffEnd();
    return TRUE;
}

int ForeachStatement::comeFrom()
{
    if (body)
	return body->comeFrom();
    return FALSE;
}

void ForeachStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("foreach (");
    int i;
    for (int i = 0; i < arguments->dim; i++)
    {
	Argument *a = (Argument *)arguments->data[i];
	if (i)
	    buf->writestring(", ");
	if (a->inout == InOut)
	    buf->writestring("inout ");
	if (a->type)
	    a->type->toCBuffer(buf, a->ident, hgs);
	else
	    buf->writestring(a->ident->toChars());
    }
    buf->writestring("; ");
    aggr->toCBuffer(buf, hgs);
    buf->writebyte(')');
    buf->writenl();
    buf->writebyte('{');
    buf->writenl();
    if (body)
	body->toCBuffer(buf, hgs);
    buf->writebyte('}');
    buf->writenl();
}

/******************************** IfStatement ***************************/

IfStatement::IfStatement(Loc loc, Argument *arg, Expression *condition, Statement *ifbody, Statement *elsebody)
    : Statement(loc)
{
    this->arg = arg;
    this->condition = condition;
    this->ifbody = ifbody;
    this->elsebody = elsebody;
    this->match = NULL;
}

Statement *IfStatement::syntaxCopy()
{
    Statement *i = NULL;
    if (ifbody)
        i = ifbody->syntaxCopy();

    Statement *e = NULL;
    if (elsebody)
	e = elsebody->syntaxCopy();

    Argument *a = arg ? arg->syntaxCopy() : NULL;
    IfStatement *s = new IfStatement(loc, a, condition->syntaxCopy(), i, e);
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

    // Evaluate at runtime
    unsigned cs0 = sc->callSuper;
    unsigned cs1;

    Scope *scd;
    if (arg)
    {	/* Declare arg, which we will set to be the
	 * result of condition.
	 */
	ScopeDsymbol *sym = new ScopeDsymbol();
	sym->parent = sc->scopesym;
	scd = sc->push(sym);

	Type *t = arg->type ? arg->type : condition->type;
	match = new VarDeclaration(loc, t, arg->ident, NULL);
	match->noauto = 1;
	match->semantic(scd);
	if (!scd->insert(match))
	    assert(0);
	match->parent = sc->func;

	/* Generate:
	 *  (arg = condition)
	 */
	VarExp *v = new VarExp(0, match);
	condition = new AssignExp(loc, v, condition);
	condition = condition->semantic(scd);
    }
    else
	scd = sc->push();
    ifbody = ifbody->semantic(scd);
    scd->pop();

    cs1 = sc->callSuper;
    sc->callSuper = cs0;
    if (elsebody)
	elsebody = elsebody->semanticScope(sc, NULL, NULL);
    sc->mergeCallSuper(loc, cs1);

    return this;
}

int IfStatement::usesEH()
{
    return (ifbody && ifbody->usesEH()) || (elsebody && elsebody->usesEH());
}

int IfStatement::fallOffEnd()
{
    if (!ifbody || ifbody->fallOffEnd() ||
	!elsebody || elsebody->fallOffEnd())
	return TRUE;
    return FALSE;
}


void IfStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("if (");
    if (arg)
    {
	if (arg->type)
	    arg->type->toCBuffer(buf, arg->ident, hgs);
	else
	    buf->writestring(arg->ident->toChars());
	buf->writebyte(';');
    }
    condition->toCBuffer(buf, hgs);
    buf->writebyte(')');
    buf->writenl();
    ifbody->toCBuffer(buf, hgs);
    if (elsebody)
    {   buf->writestring("else");
        buf->writenl();
        elsebody->toCBuffer(buf, hgs);
    }
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
		condition->syntaxCopy(), ifbody->syntaxCopy(), e);
    return s;
}

Statement *ConditionalStatement::semantic(Scope *sc)
{
    //condition = condition->semantic(sc);

    // If we can short-circuit evaluate the if statement, don't do the
    // semantic analysis of the skipped code.
    // This feature allows a limited form of conditional compilation.
    if (condition->include(sc, NULL))
    {
	ifbody = ifbody->semantic(sc);
	return ifbody;
    }
    else
    {
	if (elsebody)
	    elsebody = elsebody->semantic(sc);
	return elsebody;
    }
}

int ConditionalStatement::usesEH()
{
    return (ifbody && ifbody->usesEH()) || (elsebody && elsebody->usesEH());
}

void ConditionalStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    condition->toCBuffer(buf, hgs);
    buf->writenl();
    if (ifbody)
	ifbody->toCBuffer(buf, hgs);
    if (elsebody)
    {
	buf->writestring("else");
	buf->writenl();
	elsebody->toCBuffer(buf, hgs);
    }
    buf->writenl();
}


/******************************** PragmaStatement ***************************/

PragmaStatement::PragmaStatement(Loc loc, Identifier *ident, Expressions *args, Statement *body)
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
{   // Should be merged with PragmaDeclaration
    //printf("PragmaStatement::semantic() %s\n", toChars());
    //printf("body = %p\n", body);
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
                    fprintf(stdmsg, "%.*s", se->len, se->string);
                }
                else
		    error("string expected for message, not '%s'", e->toChars());
            }
            fprintf(stdmsg, "\n");
        }
    }
    else if (ident == Id::lib)
    {
	if (!args || args->dim != 1)
	    error("string expected for library name");
	else
	{
	    Expression *e = (Expression *)args->data[0];

	    e = e->semantic(sc);
	    args->data[0] = (void *)e;
	    if (e->op != TOKstring)
		error("string expected for library name, not '%s'", e->toChars());
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

int PragmaStatement::fallOffEnd()
{
    if (body)
	return body->fallOffEnd();
    return TRUE;
}

void PragmaStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("pragma (");
    buf->writestring(ident->toChars());
    if (args && args->dim)
    {
	buf->writestring(", ");
	argsToCBuffer(buf, args, hgs);
    }
    buf->writeByte(')');
    if (body)
    {
	buf->writenl();
	buf->writeByte('{');
	buf->writenl();

	body->toCBuffer(buf, hgs);

	buf->writeByte('}');
	buf->writenl();
    }
    else
    {
	buf->writeByte(';');
	buf->writenl();
    }
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

void StaticAssertStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    sa->toCBuffer(buf, hgs);
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
    //printf("SwitchStatement::semantic(%p)\n", this);
    assert(!cases);		// ensure semantic() is only run once
    condition = condition->semantic(sc);
    condition = resolveProperties(sc, condition);
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

	for (Scope *scx = sc; scx; scx = scx->enclosing)
	{
	    if (!scx->sw)
		continue;
	    for (int j = 0; j < scx->sw->cases->dim; j++)
	    {
		CaseStatement *cs = (CaseStatement *)scx->sw->cases->data[j];

		if (cs->exp->equals(gcs->exp))
		{
		    gcs->cs = cs;
		    goto Lfoundcase;
		}
	    }
	}
	gcs->error("case %s not found", gcs->exp->toChars());

     Lfoundcase:
	;
    }

    if (!sc->sw->sdefault)
    {
	if (global.params.warnings)
	{   fprintf(stdmsg, "warning - ");
	    error("switch statement has no default");
	}

	// Generate runtime error if the default is hit
	Statements *a = new Statements();
	CompoundStatement *cs;
	Statement *s;

	if (global.params.useSwitchError)
	    s = new SwitchErrorStatement(loc);
	else
	{   Expression *e = new HaltExp(loc);
	    s = new ExpStatement(loc, e);
	}

	a->reserve(4);
	a->push(body);
	a->push(new BreakStatement(loc, NULL));
	sc->sw->sdefault = new DefaultStatement(loc, s);
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

int SwitchStatement::fallOffEnd()
{
    body->fallOffEnd();
    return TRUE;
}

void SwitchStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("switch (");
    condition->toCBuffer(buf, hgs);
    buf->writebyte(')');
    buf->writenl();
    if (body)
    {
	if (!body->isScopeStatement())
        {   buf->writebyte('{');
            buf->writenl();
            body->toCBuffer(buf, hgs);
            buf->writebyte('}');
            buf->writenl();
        }
        else
        {
            body->toCBuffer(buf, hgs);
        }
    }
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
	if (exp->op != TOKstring && exp->op != TOKint64)
	{
	    error("case must be a string or an integral constant, not %s", exp->toChars());
	    exp = new IntegerExp(0);
	}

	for (i = 0; i < sw->cases->dim; i++)
	{
	    CaseStatement *cs = (CaseStatement *)sw->cases->data[i];

	    //printf("comparing '%s' with '%s'\n", exp->toChars(), cs->exp->toChars());
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

int CaseStatement::fallOffEnd()
{
    return statement->fallOffEnd();
}

int CaseStatement::comeFrom()
{
    return TRUE;
}

void CaseStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("case ");
    exp->toCBuffer(buf, hgs);
    buf->writebyte(':');
    buf->writenl();
    statement->toCBuffer(buf, hgs);
}

/******************************** DefaultStatement ***************************/

DefaultStatement::DefaultStatement(Loc loc, Statement *s)
    : Statement(loc)
{
    this->statement = s;
#if IN_GCC
+    cblock = NULL;
#endif
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
	{
	    error("switch statement already has a default");
	}
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

int DefaultStatement::fallOffEnd()
{
    return statement->fallOffEnd();
}

int DefaultStatement::comeFrom()
{
    return TRUE;
}

void DefaultStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("default:\n");
    statement->toCBuffer(buf, hgs);
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

int GotoDefaultStatement::fallOffEnd()
{
    return FALSE;
}

void GotoDefaultStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("goto default;\n");
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

int GotoCaseStatement::fallOffEnd()
{
    return FALSE;
}

void GotoCaseStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("goto case");
    if (exp)
    {   buf->writebyte(' ');
        exp->toCBuffer(buf, hgs);
    }
    buf->writebyte(';');
    buf->writenl();
}

/******************************** SwitchErrorStatement ***************************/

SwitchErrorStatement::SwitchErrorStatement(Loc loc)
    : Statement(loc)
{
}

int SwitchErrorStatement::fallOffEnd()
{
    return FALSE;
}

void SwitchErrorStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("SwitchErrorStatement::toCBuffer()");
    buf->writenl();
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
    //printf("ReturnStatement::semantic() %s\n", toChars());

    FuncDeclaration *fd = sc->parent->isFuncDeclaration();
    FuncDeclaration *fdx = fd;
    Type *tret = fd->type->next;
    if (fd->tintro)
	tret = fd->tintro->next;
    Type *tbret = NULL;

    if (tret)
	tbret = tret->toBasetype();
    if (!exp && (!tbret || tbret->ty == Tvoid) && fd->isMain())
	exp = new IntegerExp(0);

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

	tret = fdx->type->next;

	if (exp)
	{   exp = exp->semantic(sc);
	    exp = resolveProperties(sc, exp);
	    exp = exp->implicitCastTo(tret);
	}
	if (!exp || exp->op == TOKint64 || exp->op == TOKfloat64 ||
	    exp->op == TOKimaginary80 || exp->op == TOKcomplex80 ||
	    exp->op == TOKthis || exp->op == TOKsuper || exp->op == TOKnull ||
	    exp->op == TOKstring)
	{
	    sc->fes->cases.push(this);
	    s = new ReturnStatement(0, new IntegerExp(sc->fes->cases.dim + 1));
	}
	else if (fdx->type->next->toBasetype() == Type::tvoid)
	{
	    Statement *s1;
	    Statement *s2;

	    s = new ReturnStatement(0, NULL);
	    sc->fes->cases.push(s);

	    // Construct: { exp; return cases.dim + 1; }
	    s1 = new ExpStatement(loc, exp);
	    s2 = new ReturnStatement(0, new IntegerExp(sc->fes->cases.dim + 1));
	    s = new CompoundStatement(loc, s1, s2);
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
    if (sc->tf)
	error("return statements cannot be in finally, scope(exit) or scope(success) bodies");

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
	fd->hasReturnExp |= 1;

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
	    if (fd->inferRetType)
	    {
		if (fd->type->next)
		{
		    if (!exp->type->equals(fd->type->next))
			error("mismatched function return type inference of %s and %s",
			    exp->type->toChars(), fd->type->next->toChars());
		}
		else
		{
		    fd->type->next = exp->type;
		    fd->type = fd->type->semantic(loc, sc);
		    if (!fd->tintro)
		    {	tret = fd->type->next;
			tbret = tret->toBasetype();
		    }
		}
	    }
	    else if (tbret->ty != Tvoid)
	    {
		exp = exp->implicitCastTo(tret);
	    }
	}
	//exp->dump(0);
	//exp->print();
	exp->checkEscape();
    }
    else if (fd->inferRetType)
    {
	if (fd->type->next)
	{
	    if (fd->type->next->ty != Tvoid)
		error("mismatched function return type inference of void and %s",
		    fd->type->next->toChars());
	}
	else
	{
	    fd->type->next = Type::tvoid;
	    fd->type = fd->type->semantic(loc, sc);
	    if (!fd->tintro)
	    {   tret = Type::tvoid;
		tbret = tret;
	    }
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

	    s = new ExpStatement(0, exp);
	    return new CompoundStatement(loc, s, gs);
	}
	return gs;
    }

    if (exp && tbret->ty == Tvoid && !fd->isMain())
    {   Statement *s;

	s = new ExpStatement(loc, exp);
	loc = 0;
	exp = NULL;
	return new CompoundStatement(loc, s, this);
    }

    return this;
}

int ReturnStatement::fallOffEnd()
{
    return FALSE;
}

void ReturnStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->printf("return ");
    if (exp)
	exp->toCBuffer(buf, hgs);
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
		if (ls->tf != sc->tf)
		    error("cannot break out of finally block");
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

int BreakStatement::fallOffEnd()
{
    return FALSE;
}

void BreakStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("break");
    if (ident)
    {   buf->writebyte(' ');
        buf->writestring(ident->toChars());
    }
    buf->writebyte(';');
    buf->writenl();
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
    //printf("ContinueStatement::semantic() %p\n", this);
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
		    for (; scx; scx = scx->enclosing)
		    {
			ls = scx->slabel;
			if (ls && ls->ident == ident && ls->statement == sc->fes)
			{
			    // Replace continue ident; with return 0;
			    return new ReturnStatement(0, new IntegerExp(0));
			}
		    }

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
		if (ls->tf != sc->tf)
		    error("cannot continue out of finally block");
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

int ContinueStatement::fallOffEnd()
{
    return FALSE;
}

void ContinueStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("continue");
    if (ident)
    {   buf->writebyte(' ');
        buf->writestring(ident->toChars());
    }
    buf->writebyte(';');
    buf->writenl();
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
    {	ClassDeclaration *cd;

	exp = exp->semantic(sc);
	exp = resolveProperties(sc, exp);
	cd = exp->type->isClassHandle();
	if (!cd)
	    error("can only synchronize on class objects, not '%s'", exp->type->toChars());
	else if (cd->isInterfaceDeclaration())
	{   Type *t = new TypeIdentifier(0, Id::Object);

	    t = t->semantic(0, sc);
	    exp = new CastExp(loc, exp, t);
	    exp = exp->semantic(sc);
	}
    }
    body = body->semantic(sc);
    return this;
}

int SynchronizedStatement::hasBreak()
{
    return FALSE; //TRUE;
}

int SynchronizedStatement::hasContinue()
{
    return FALSE; //TRUE;
}

int SynchronizedStatement::usesEH()
{
    return TRUE;
}

int SynchronizedStatement::fallOffEnd()
{
    return body->fallOffEnd();
}

void SynchronizedStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("synchronized");
    if (exp)
    {   buf->writebyte('(');
	exp->toCBuffer(buf, hgs);
	buf->writebyte(')');
    }
    if (body)
    {
	buf->writebyte(' ');
	body->toCBuffer(buf, hgs);
    }
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

    //printf("WithStatement::semantic()\n");
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

void WithStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("with (");
    exp->toCBuffer(buf, hgs);
    buf->writestring(")\n");
    body->toCBuffer(buf, hgs);
}

int WithStatement::usesEH()
{
    return body->usesEH();
}

int WithStatement::fallOffEnd()
{
    return body->fallOffEnd();
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
    body = body->semanticScope(sc, NULL /*this*/, NULL);

    for (int i = 0; i < catches->dim; i++)
    {   Catch *c;

	c = (Catch *)catches->data[i];
	c->semantic(sc);

	// Determine if current catch 'hides' any previous catches
	for (int j = 0; j < i; j++)
	{   Catch *cj = (Catch *)catches->data[j];
	    char *si = c->loc.toChars();
	    char *sj = cj->loc.toChars();

	    if (c->type->implicitConvTo(cj->type))
		error("catch at %s hides catch at %s", sj, si);
	}
    }
    return this;
}

int TryCatchStatement::hasBreak()
{
    return FALSE; //TRUE;
}

int TryCatchStatement::usesEH()
{
    return TRUE;
}

int TryCatchStatement::fallOffEnd()
{
    int result = FALSE;

    if (body)
	result = body->fallOffEnd();
    for (int i = 0; i < catches->dim; i++)
    {   Catch *c;

	c = (Catch *)catches->data[i];
	if (c->handler)
	    result |= c->handler->fallOffEnd();
    }
    return result;
}

void TryCatchStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("try");
    buf->writenl();
    if (body)
        body->toCBuffer(buf, hgs);
    int i;
    for (i = 0; i < catches->dim; i++)
    {
        Catch *c = (Catch *)catches->data[i];
        c->toCBuffer(buf, hgs);
    }
}

/******************************** Catch ***************************/

Catch::Catch(Loc loc, Type *t, Identifier *id, Statement *handler)
{
    //printf("Catch(loc = %s)\n", loc.toChars());
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
	ident,
	(handler ? handler->syntaxCopy() : NULL));
    return c;
}

void Catch::semantic(Scope *sc)
{   ScopeDsymbol *sym;

    //printf("Catch::semantic()\n");

#ifndef IN_GCC
    if (sc->tf)
    {
	/* This is because the _d_local_unwind() gets the stack munged
	 * up on this. The workaround is to place any try-catches into
	 * a separate function, and call that.
	 * To fix, have the compiler automatically convert the finally
	 * body into a nested function.
	 */
	error(loc, "cannot put catch statement inside finally block");
    }
#endif

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

void Catch::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("catch");
    if (type)
    {   buf->writebyte('(');
	type->toCBuffer(buf, ident, hgs);
        buf->writebyte(')');
    }
    buf->writenl();
    buf->writebyte('{');
    buf->writenl();
    handler->toCBuffer(buf, hgs);
    buf->writebyte('}');
    buf->writenl();
}

/****************************** TryFinallyStatement ***************************/

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
    //printf("TryFinallyStatement::semantic()\n");
    body = body->semantic(sc);
    sc = sc->push();
    sc->tf = this;
    sc->sbreak = NULL;
    sc->scontinue = NULL;	// no break or continue out of finally block
    finalbody = finalbody->semantic(sc);
    sc->pop();
    return this;
}

void TryFinallyStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->printf("try\n{\n");
    body->toCBuffer(buf, hgs);
    buf->printf("}\nfinally\n{\n");
    finalbody->toCBuffer(buf, hgs);
    buf->writeByte('}');
    buf->writenl();
}

int TryFinallyStatement::hasBreak()
{
    return FALSE; //TRUE;
}

int TryFinallyStatement::hasContinue()
{
    return FALSE; //TRUE;
}

int TryFinallyStatement::usesEH()
{
    return TRUE;
}

int TryFinallyStatement::fallOffEnd()
{   int result;

    result = body->fallOffEnd();
//    if (finalbody)
//	result = finalbody->fallOffEnd();
    return result;
}

/****************************** OnScopeStatement ***************************/

OnScopeStatement::OnScopeStatement(Loc loc, TOK tok, Statement *statement)
    : Statement(loc)
{
    this->tok = tok;
    this->statement = statement;
}

Statement *OnScopeStatement::syntaxCopy()
{
    OnScopeStatement *s = new OnScopeStatement(loc,
	tok, statement->syntaxCopy());
    return s;
}

Statement *OnScopeStatement::semantic(Scope *sc)
{
    /* semantic is called on results of scopeCode() */
    return this;
}

void OnScopeStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring(Token::toChars(tok));
    buf->writebyte(' ');
    statement->toCBuffer(buf, hgs);
}

int OnScopeStatement::usesEH()
{
    return (tok != TOKon_scope_success);
}

void OnScopeStatement::scopeCode(Statement **sentry, Statement **sexception, Statement **sfinally)
{
    //printf("OnScopeStatement::scopeCode()\n");
    //print();
    *sentry = NULL;
    *sexception = NULL;
    *sfinally = NULL;
    switch (tok)
    {
	case TOKon_scope_exit:
	    *sfinally = statement;
	    break;

	case TOKon_scope_failure:
	    *sexception = statement;
	    break;

	case TOKon_scope_success:
	{
	    /* Create:
	     *	sentry:   int x = 0;
	     *	sexception:    x = 1;
	     *	sfinally: if (!x) statement;
	     */
	    char name[5 + sizeof(int) * 3 + 1];
	    static int num;
	    sprintf(name, "__osf%d", ++num);
	    Identifier *id = Lexer::idPool(name);

	    ExpInitializer *ie = new ExpInitializer(loc, new IntegerExp(0));
	    VarDeclaration *v = new VarDeclaration(loc, Type::tint32, id, ie);
	    *sentry = new DeclarationStatement(loc, v);

	    Expression *e = new IntegerExp(1);
	    e = new AssignExp(0, new VarExp(0, v), e);
	    *sexception = new ExpStatement(0, e);

	    e = new VarExp(0, v);
	    e = new NotExp(0, e);
	    *sfinally = new IfStatement(0, NULL, e, statement, NULL);

	    break;
	}

	default:
	    assert(0);
    }
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

    FuncDeclaration *fd = sc->parent->isFuncDeclaration();
    fd->hasReturnExp |= 2;

    if (sc->incontract)
	error("Throw statements cannot be in contracts");
    exp = exp->semantic(sc);
    exp = resolveProperties(sc, exp);
    if (!exp->type->toBasetype()->isClassHandle())
	error("can only throw class objects, not type %s", exp->type->toChars());
    return this;
}

int ThrowStatement::fallOffEnd()
{
    return FALSE;
}

void ThrowStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->printf("throw ");
    exp->toCBuffer(buf, hgs);
    buf->writeByte(';');
    buf->writenl();
}

/******************************** VolatileStatement **************************/

VolatileStatement::VolatileStatement(Loc loc, Statement *statement)
    : Statement(loc)
{
    this->statement = statement;
}

Statement *VolatileStatement::syntaxCopy()
{
    VolatileStatement *s = new VolatileStatement(loc,
		statement ? statement->syntaxCopy() : NULL);
    return s;
}

Statement *VolatileStatement::semantic(Scope *sc)
{
    statement = statement->semantic(sc);
    return this;
}

Statements *VolatileStatement::flatten()
{
    Statements *a;

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

int VolatileStatement::fallOffEnd()
{
    return statement->fallOffEnd();
}

void VolatileStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("volatile");
    if (statement)
    {   if (statement->isScopeStatement())
            buf->writenl();
        else
            buf->writebyte(' ');
        statement->toCBuffer(buf, hgs);
    }
}


/******************************** GotoStatement ***************************/

GotoStatement::GotoStatement(Loc loc, Identifier *ident)
    : Statement(loc)
{
    this->ident = ident;
    this->label = NULL;
    this->tf = NULL;
}

Statement *GotoStatement::syntaxCopy()
{
    GotoStatement *s = new GotoStatement(loc, ident);
    return s;
}

Statement *GotoStatement::semantic(Scope *sc)
{   FuncDeclaration *fd = sc->parent->isFuncDeclaration();

    //printf("GotoStatement::semantic()\n");
    tf = sc->tf;
    label = fd->searchLabel(ident);
    if (!label->statement && sc->fes)
    {
	/* Either the goto label is forward referenced or it
	 * is in the function that the enclosing foreach is in.
	 * Can't know yet, so wrap the goto in a compound statement
	 * so we can patch it later, and add it to a 'look at this later'
	 * list.
	 */
	Statements *a = new Statements();
	Statement *s;

	a->push(this);
	s = new CompoundStatement(loc, a);
	sc->fes->gotos.push(s);		// 'look at this later' list
	return s;
    }
    if (label->statement && label->statement->tf != sc->tf)
	error("cannot goto in or out of finally block");
    return this;
}

int GotoStatement::fallOffEnd()
{
    return FALSE;
}

void GotoStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("goto ");
    buf->writestring(ident->toChars());
    buf->writebyte(';');
    buf->writenl();
}

/******************************** LabelStatement ***************************/

LabelStatement::LabelStatement(Loc loc, Identifier *ident, Statement *statement)
    : Statement(loc)
{
    this->ident = ident;
    this->statement = statement;
    this->tf = NULL;
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

    //printf("LabelStatement::semantic()\n");
    ls = fd->searchLabel(ident);
    if (ls->statement)
	error("Label '%s' already defined", ls->toChars());
    else
	ls->statement = this;
    tf = sc->tf;
    sc = sc->push();
    sc->scopesym = sc->enclosing->scopesym;
    sc->callSuper |= CSXlabel;
    sc->slabel = this;
    statement = statement->semantic(sc);
    sc->pop();
    return this;
}

Statements *LabelStatement::flatten()
{
    Statements *a;

    a = statement->flatten();
    if (a)
    {
	if (!a->dim)
	{
	    a->push(new ExpStatement(loc, NULL));
	}
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

int LabelStatement::fallOffEnd()
{
    return statement ? statement->fallOffEnd() : TRUE;
}

int LabelStatement::comeFrom()
{
    return TRUE;
}

void LabelStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring(ident->toChars());
    buf->writebyte(':');
    buf->writenl();
    if (statement)
        statement->toCBuffer(buf, hgs);
}


/******************************** LabelDsymbol ***************************/

LabelDsymbol::LabelDsymbol(Identifier *ident)
	: Dsymbol(ident)
{
    statement = NULL;
#if IN_GCC
    asmLabelNum = 0;
#endif
}

LabelDsymbol *LabelDsymbol::isLabel()		// is this a LabelDsymbol()?
{
    return this;
}


