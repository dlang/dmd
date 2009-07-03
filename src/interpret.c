
// Compiler implementation of the D programming language
// Copyright (c) 1999-2007 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
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

#define LOG	0

struct InterState
{
    InterState *caller;		// calling function's InterState
    FuncDeclaration *fd;	// function being interpreted
    Dsymbols vars;		// variables used in this function
    Statement *start;		// if !=NULL, start execution at this statement
    Statement *gotoTarget;	// target of EXP_GOTO_INTERPRET result

    InterState();
};

InterState::InterState()
{
    memset(this, 0, sizeof(InterState));
}

Expression *interpret_aaLen(InterState *istate, Expressions *arguments);
Expression *interpret_aaKeys(InterState *istate, Expressions *arguments);
Expression *interpret_aaValues(InterState *istate, Expressions *arguments);

/*************************************
 * Attempt to interpret a function given the arguments.
 * Input:
 *	istate	state for calling function (NULL if none)
 * Return result expression if successful, NULL if not.
 */

Expression *FuncDeclaration::interpret(InterState *istate, Expressions *arguments)
{
#if LOG
    printf("FuncDeclaration::interpret() %s\n", toChars());
    printf("cantInterpret = %d, semanticRun = %d\n", cantInterpret, semanticRun);
#endif
    if (global.errors)
	return NULL;
    if (ident == Id::aaLen)
	return interpret_aaLen(istate, arguments);
    else if (ident == Id::aaKeys)
	return interpret_aaKeys(istate, arguments);
    else if (ident == Id::aaValues)
	return interpret_aaValues(istate, arguments);

    if (cantInterpret || semanticRun == 1)
	return NULL;

    if (needThis() || isNested() || !fbody)
    {	cantInterpret = 1;
	return NULL;
    }

    if (semanticRun == 0 && scope)
    {
	semantic3(scope);
    }
    if (semanticRun < 2)
	return NULL;

    Type *tb = type->toBasetype();
    assert(tb->ty == Tfunction);
    TypeFunction *tf = (TypeFunction *)tb;
    Type *tret = tf->next->toBasetype();
    if (tf->varargs /*|| tret->ty == Tvoid*/)
    {	cantInterpret = 1;
	return NULL;
    }

    if (tf->parameters)
    {	size_t dim = Argument::dim(tf->parameters);
	for (size_t i = 0; i < dim; i++)
	{   Argument *arg = Argument::getNth(tf->parameters, i);
	    if (arg->storageClass & STClazy)
	    {   cantInterpret = 1;
		return NULL;
	    }
	}
    }

    InterState istatex;
    istatex.caller = istate;
    istatex.fd = this;

    Expressions vsave;
    size_t dim = 0;
    if (arguments)
    {
	dim = arguments->dim;
	assert(!dim || parameters->dim == dim);
	vsave.setDim(dim);

	for (size_t i = 0; i < dim; i++)
	{   Expression *earg = (Expression *)arguments->data[i];
	    Argument *arg = Argument::getNth(tf->parameters, i);
	    VarDeclaration *v = (VarDeclaration *)parameters->data[i];
	    vsave.data[i] = v->value;
#if LOG
	    printf("arg[%d] = %s\n", i, earg->toChars());
#endif
	    if (arg->storageClass & (STCout | STCref))
	    {
		/* Bind out or ref parameter to the corresponding
		 * variable v2
		 */
		if (!istate || earg->op != TOKvar)
		    return NULL;	// can't bind to non-interpreted vars

		VarDeclaration *v2;
		while (1)
		{
		    VarExp *ve = (VarExp *)earg;
		    v2 = ve->var->isVarDeclaration();
		    if (!v2)
			return NULL;
		    if (!v2->value || v2->value->op != TOKvar)
			break;
		    earg = v2->value;
		}

		v->value = new VarExp(earg->loc, v2);

		/* Don't restore the value of v2 upon function return
		 */
		assert(istate);
		for (size_t i = 0; i < istate->vars.dim; i++)
		{   VarDeclaration *v = (VarDeclaration *)istate->vars.data[i];
		    if (v == v2)
		    {	istate->vars.data[i] = NULL;
			break;
		    }
		}
	    }
	    else
	    {	/* Value parameters
		 */
		earg = earg->interpret(&istatex);
		if (earg == EXP_CANT_INTERPRET)
		    return NULL;
		v->value = earg;
	    }
#if LOG
	    printf("interpreted arg[%d] = %s\n", i, earg->toChars());
#endif
	}
    }

    /* Save the values of the local variables used
     */
    Expressions valueSaves;
    if (istate)
    {
	//printf("saving state...\n");
	valueSaves.setDim(istate->vars.dim);
	for (size_t i = 0; i < istate->vars.dim; i++)
	{   VarDeclaration *v = (VarDeclaration *)istate->vars.data[i];
	    if (v)
	    {
		//printf("\tsaving [%d] %s = %s\n", i, v->toChars(), v->value->toChars());
		valueSaves.data[i] = v->value;
		v->value = NULL;
	    }
	}
    }

    Expression *e = NULL;

    while (1)
    {
	e = fbody->interpret(&istatex);
	if (e == EXP_CANT_INTERPRET)
	{
#if LOG
	    printf("function body failed to interpret\n");
#endif
	    e = NULL;
	}

	/* This is how we deal with a recursive statement AST
	 * that has arbitrary goto statements in it.
	 * Bubble up a 'result' which is the target of the goto
	 * statement, then go recursively down the AST looking
	 * for that statement, then execute starting there.
	 */
	if (e == EXP_GOTO_INTERPRET)
	{
	    istatex.start = istatex.gotoTarget;	// set starting statement
	    istatex.gotoTarget = NULL;
	}
	else
	    break;
    }

    /* Restore the parameter values
     */
    for (size_t i = 0; i < dim; i++)
    {
	VarDeclaration *v = (VarDeclaration *)parameters->data[i];
	v->value = (Expression *)vsave.data[i];
    }

    if (istate)
    {
	/* Restore the variable values
	 */
	for (size_t i = 0; i < istate->vars.dim; i++)
	{   VarDeclaration *v = (VarDeclaration *)istate->vars.data[i];
	    if (v)
		v->value = (Expression *)valueSaves.data[i];
	}
    }

    return e;
}

/******************************** Statement ***************************/

#define START()				\
    if (istate->start)			\
    {	if (istate->start != this)	\
	    return NULL;		\
	istate->start = NULL;		\
    }

/***********************************
 * Interpret the statement.
 * Returns:
 *	NULL	continue to next statement
 *	EXP_CANT_INTERPRET	cannot interpret statement at compile time
 *	!NULL	expression from return statement
 */

Expression *Statement::interpret(InterState *istate)
{
#if LOG
    printf("Statement::interpret()\n");
#endif
    START()
    return EXP_CANT_INTERPRET;
}

Expression *ExpStatement::interpret(InterState *istate)
{
#if LOG
    printf("ExpStatement::interpret(%s)\n", exp ? exp->toChars() : "");
#endif
    START()
    if (exp)
    {
	Expression *e = exp->interpret(istate);
	if (e == EXP_CANT_INTERPRET)
	{
	    //printf("cannot interpret %s\n", exp->toChars());
	    return EXP_CANT_INTERPRET;
	}
    }
    return NULL;
}

Expression *CompoundStatement::interpret(InterState *istate)
{   Expression *e = NULL;

#if LOG
    printf("CompoundStatement::interpret()\n");
#endif
    if (istate->start == this)
	istate->start = NULL;
    if (statements)
    {
	for (size_t i = 0; i < statements->dim; i++)
	{   Statement *s = (Statement *)statements->data[i];

	    if (s)
	    {
		e = s->interpret(istate);
		if (e)
		    break;
	    }
	}
    }
#if LOG
    printf("-CompoundStatement::interpret() %p\n", e);
#endif
    return e;
}

Expression *UnrolledLoopStatement::interpret(InterState *istate)
{   Expression *e = NULL;

#if LOG
    printf("UnrolledLoopStatement::interpret()\n");
#endif
    if (istate->start == this)
	istate->start = NULL;
    if (statements)
    {
	for (size_t i = 0; i < statements->dim; i++)
	{   Statement *s = (Statement *)statements->data[i];

	    e = s->interpret(istate);
	    if (e == EXP_CANT_INTERPRET)
		break;
	    if (e == EXP_CONTINUE_INTERPRET)
	    {	e = NULL;
		continue;
	    }
	    if (e == EXP_BREAK_INTERPRET)
	    {	e = NULL;
		break;
	    }
	    if (e)
		break;
	}
    }
    return e;
}

Expression *IfStatement::interpret(InterState *istate)
{
#if LOG
    printf("IfStatement::interpret(%s)\n", condition->toChars());
#endif

    if (istate->start == this)
	istate->start = NULL;
    if (istate->start)
    {
	Expression *e = NULL;
	if (ifbody)
	    e = ifbody->interpret(istate);
	if (istate->start && elsebody)
	    e = elsebody->interpret(istate);
	return e;
    }

    Expression *e = condition->interpret(istate);
    assert(e);
    //if (e == EXP_CANT_INTERPRET) printf("cannot interpret\n");
    if (e != EXP_CANT_INTERPRET)
    {
	if (!e->isConst())
	{
	    e = EXP_CANT_INTERPRET;
	}
	else
	{
	    if (e->isBool(TRUE))
		e = ifbody ? ifbody->interpret(istate) : NULL;
	    else if (e->isBool(FALSE))
		e = elsebody ? elsebody->interpret(istate) : NULL;
	    else
	    {
		e = EXP_CANT_INTERPRET;
	    }
	}
    }
    return e;
}

Expression *ScopeStatement::interpret(InterState *istate)
{
#if LOG
    printf("ScopeStatement::interpret()\n");
#endif
    if (istate->start == this)
	istate->start = NULL;
    return statement ? statement->interpret(istate) : NULL;
}

Expression *ReturnStatement::interpret(InterState *istate)
{
#if LOG
    printf("ReturnStatement::interpret(%s)\n", exp ? exp->toChars() : "");
#endif
    START()
    if (!exp)
	return EXP_VOID_INTERPRET;
#if LOG
    Expression *e = exp->interpret(istate);
    printf("e = %p\n", e);
    return e;
#else
    return exp->interpret(istate);
#endif
}

Expression *BreakStatement::interpret(InterState *istate)
{
#if LOG
    printf("BreakStatement::interpret()\n");
#endif
    START()
    if (ident)
	return EXP_CANT_INTERPRET;
    else
	return EXP_BREAK_INTERPRET;
}

Expression *ContinueStatement::interpret(InterState *istate)
{
#if LOG
    printf("ContinueStatement::interpret()\n");
#endif
    START()
    if (ident)
	return EXP_CANT_INTERPRET;
    else
	return EXP_CONTINUE_INTERPRET;
}

Expression *WhileStatement::interpret(InterState *istate)
{
#if LOG
    printf("WhileStatement::interpret()\n");
#endif
    if (istate->start == this)
	istate->start = NULL;
    Expression *e;

    if (istate->start)
    {
	e = body ? body->interpret(istate) : NULL;
	if (istate->start)
	    return NULL;
	if (e == EXP_CANT_INTERPRET)
	    return e;
	if (e == EXP_BREAK_INTERPRET)
	    return NULL;
	if (e != EXP_CONTINUE_INTERPRET)
	    return e;
    }

    while (1)
    {
	e = condition->interpret(istate);
	if (e == EXP_CANT_INTERPRET)
	    break;
	if (!e->isConst())
	{   e = EXP_CANT_INTERPRET;
	    break;
	}
	if (e->isBool(TRUE))
	{   e = body ? body->interpret(istate) : NULL;
	    if (e == EXP_CANT_INTERPRET)
		break;
	    if (e == EXP_CONTINUE_INTERPRET)
		continue;
	    if (e == EXP_BREAK_INTERPRET)
	    {	e = NULL;
		break;
	    }
	    if (e)
		break;
	}
	else if (e->isBool(FALSE))
	{   e = NULL;
	    break;
	}
	else
	    assert(0);
    }
    return e;
}

Expression *DoStatement::interpret(InterState *istate)
{
#if LOG
    printf("DoStatement::interpret()\n");
#endif
    if (istate->start == this)
	istate->start = NULL;
    Expression *e;

    if (istate->start)
    {
	e = body ? body->interpret(istate) : NULL;
	if (istate->start)
	    return NULL;
	if (e == EXP_CANT_INTERPRET)
	    return e;
	if (e == EXP_BREAK_INTERPRET)
	    return NULL;
	if (e == EXP_CONTINUE_INTERPRET)
	    goto Lcontinue;
	if (e)
	    return e;
    }

    while (1)
    {
	e = body ? body->interpret(istate) : NULL;
	if (e == EXP_CANT_INTERPRET)
	    break;
	if (e == EXP_BREAK_INTERPRET)
	{   e = NULL;
	    break;
	}
	if (e && e != EXP_CONTINUE_INTERPRET)
	    break;

    Lcontinue:
	e = condition->interpret(istate);
	if (e == EXP_CANT_INTERPRET)
	    break;
	if (!e->isConst())
	{   e = EXP_CANT_INTERPRET;
	    break;
	}
	if (e->isBool(TRUE))
	{
	}
	else if (e->isBool(FALSE))
	{   e = NULL;
	    break;
	}
	else
	    assert(0);
    }
    return e;
}

Expression *ForStatement::interpret(InterState *istate)
{
#if LOG
    printf("ForStatement::interpret()\n");
#endif
    if (istate->start == this)
	istate->start = NULL;
    Expression *e;

    if (init)
    {
	e = init->interpret(istate);
	if (e == EXP_CANT_INTERPRET)
	    return e;
	assert(!e);
    }

    if (istate->start)
    {
	e = body ? body->interpret(istate) : NULL;
	if (istate->start)
	    return NULL;
	if (e == EXP_CANT_INTERPRET)
	    return e;
	if (e == EXP_BREAK_INTERPRET)
	    return NULL;
	if (e == EXP_CONTINUE_INTERPRET)
	    goto Lcontinue;
	if (e)
	    return e;
    }

    while (1)
    {
	e = condition->interpret(istate);
	if (e == EXP_CANT_INTERPRET)
	    break;
	if (!e->isConst())
	{   e = EXP_CANT_INTERPRET;
	    break;
	}
	if (e->isBool(TRUE))
	{   e = body ? body->interpret(istate) : NULL;
	    if (e == EXP_CANT_INTERPRET)
		break;
	    if (e == EXP_BREAK_INTERPRET)
	    {   e = NULL;
		break;
	    }
	    if (e && e != EXP_CONTINUE_INTERPRET)
		break;
	Lcontinue:
	    e = increment->interpret(istate);
	    if (e == EXP_CANT_INTERPRET)
		break;
	}
	else if (e->isBool(FALSE))
	{   e = NULL;
	    break;
	}
	else
	    assert(0);
    }
    return e;
}

Expression *ForeachStatement::interpret(InterState *istate)
{
#if LOG
    printf("ForeachStatement::interpret()\n");
#endif
    if (istate->start == this)
	istate->start = NULL;
    if (istate->start)
	return NULL;

    Expression *e = NULL;
    Expression *eaggr;

    if (value->isOut() || value->isRef())
	return EXP_CANT_INTERPRET;

    eaggr = aggr->interpret(istate);
    if (eaggr == EXP_CANT_INTERPRET)
	return EXP_CANT_INTERPRET;

    Expression *dim = ArrayLength(Type::tsize_t, eaggr);
    if (dim == EXP_CANT_INTERPRET)
	return EXP_CANT_INTERPRET;

    uinteger_t d = dim->toUInteger();
    uinteger_t index;

    if (op == TOKforeach)
    {
	for (index = 0; index < d; index++)
	{
	    Expression *ekey = new IntegerExp(loc, index, Type::tsize_t);
	    if (key)
		key->value = ekey;
	    value->value = Index(value->type, eaggr, ekey);
	    if (value->value == EXP_CANT_INTERPRET)
		return EXP_CANT_INTERPRET;

	    e = body ? body->interpret(istate) : NULL;
	    if (e == EXP_CANT_INTERPRET)
		break;
	    if (e == EXP_BREAK_INTERPRET)
	    {   e = NULL;
		break;
	    }
	    if (e == EXP_CONTINUE_INTERPRET)
		e = NULL;
	    else if (e)
		break;
	}
    }
    else // TOKforeach_reverse
    {
	for (index = d; index-- != 0;)
	{
	    Expression *ekey = new IntegerExp(loc, index, Type::tsize_t);
	    if (key)
		key->value = ekey;
	    value->value = Index(value->type, eaggr, ekey);
	    if (value->value == EXP_CANT_INTERPRET)
		return EXP_CANT_INTERPRET;

	    e = body ? body->interpret(istate) : NULL;
	    if (e == EXP_CANT_INTERPRET)
		break;
	    if (e == EXP_BREAK_INTERPRET)
	    {   e = NULL;
		break;
	    }
	    if (e == EXP_CONTINUE_INTERPRET)
		e = NULL;
	    else if (e)
		break;
	}
    }
    return e;
}

Expression *SwitchStatement::interpret(InterState *istate)
{
#if LOG
    printf("SwitchStatement::interpret()\n");
#endif
    if (istate->start == this)
	istate->start = NULL;
    Expression *e = NULL;

    if (istate->start)
    {
	e = body ? body->interpret(istate) : NULL;
	if (istate->start)
	    return NULL;
	if (e == EXP_CANT_INTERPRET)
	    return e;
	if (e == EXP_BREAK_INTERPRET)
	    return NULL;
	return e;
    }


    Expression *econdition = condition->interpret(istate);
    if (econdition == EXP_CANT_INTERPRET)
	return EXP_CANT_INTERPRET;

    Statement *s = NULL;
    if (cases)
    {
	for (size_t i = 0; i < cases->dim; i++)
	{
	    CaseStatement *cs = (CaseStatement *)cases->data[i];
	    e = Equal(TOKequal, Type::tint32, econdition, cs->exp);
	    if (e == EXP_CANT_INTERPRET)
		return EXP_CANT_INTERPRET;
	    if (e->isBool(TRUE))
	    {	s = cs;
		break;
	    }
	}
    }
    if (!s)
    {	if (hasNoDefault)
	    error("no default or case for %s in switch statement", econdition->toChars());
	s = sdefault;
    }

    assert(s);
    istate->start = s;
    e = body ? body->interpret(istate) : NULL;
    assert(!istate->start);
    if (e == EXP_BREAK_INTERPRET)
	return NULL;
    return e;
}

Expression *CaseStatement::interpret(InterState *istate)
{
#if LOG
    printf("CaseStatement::interpret(%s) this = %p\n", exp->toChars(), this);
#endif
    if (istate->start == this)
	istate->start = NULL;
    if (statement)
	return statement->interpret(istate);
    else
	return NULL;
}

Expression *DefaultStatement::interpret(InterState *istate)
{
#if LOG
    printf("DefaultStatement::interpret()\n");
#endif
    if (istate->start == this)
	istate->start = NULL;
    if (statement)
	return statement->interpret(istate);
    else
	return NULL;
}

Expression *GotoStatement::interpret(InterState *istate)
{
#if LOG
    printf("GotoStatement::interpret()\n");
#endif
    START()
    assert(label && label->statement);
    istate->gotoTarget = label->statement;
    return EXP_GOTO_INTERPRET;
}

Expression *GotoCaseStatement::interpret(InterState *istate)
{
#if LOG
    printf("GotoCaseStatement::interpret()\n");
#endif
    START()
    assert(cs);
    istate->gotoTarget = cs;
    return EXP_GOTO_INTERPRET;
}

Expression *GotoDefaultStatement::interpret(InterState *istate)
{
#if LOG
    printf("GotoDefaultStatement::interpret()\n");
#endif
    START()
    assert(sw && sw->sdefault);
    istate->gotoTarget = sw->sdefault;
    return EXP_GOTO_INTERPRET;
}

Expression *LabelStatement::interpret(InterState *istate)
{
#if LOG
    printf("LabelStatement::interpret()\n");
#endif
    if (istate->start == this)
	istate->start = NULL;
    return statement ? statement->interpret(istate) : NULL;
}

/******************************** Expression ***************************/

Expression *Expression::interpret(InterState *istate)
{
#if LOG
    printf("Expression::interpret() %s\n", toChars());
#endif
    return EXP_CANT_INTERPRET;
}

Expression *NullExp::interpret(InterState *istate)
{
    return this;
}

Expression *IntegerExp::interpret(InterState *istate)
{
#if LOG
    printf("IntegerExp::interpret() %s\n", toChars());
#endif
    return this;
}

Expression *RealExp::interpret(InterState *istate)
{
#if LOG
    printf("RealExp::interpret() %s\n", toChars());
#endif
    return this;
}

Expression *ComplexExp::interpret(InterState *istate)
{
    return this;
}

Expression *StringExp::interpret(InterState *istate)
{
#if LOG
    printf("StringExp::interpret() %s\n", toChars());
#endif
    return this;
}

Expression *getVarExp(InterState *istate, VarDeclaration *v)
{
    Expression *e = EXP_CANT_INTERPRET;
    if (v)
    {
	if (v->isConst() && v->init)
	{   e = v->init->toExpression();
	    if (!e->type)
		e->type = v->type;
	}
	else
	{   e = v->value;
	    if (!e)
		error("variable %s is used before initialization", v->toChars());
	    else if (e != EXP_CANT_INTERPRET)
		e = e->interpret(istate);
	}
	if (!e)
	    e = EXP_CANT_INTERPRET;
    }
    return e;
}

Expression *VarExp::interpret(InterState *istate)
{
#if LOG
    printf("VarExp::interpret() %s\n", toChars());
#endif
    return getVarExp(istate, var->isVarDeclaration());
}

Expression *DeclarationExp::interpret(InterState *istate)
{
#if LOG
    printf("DeclarationExp::interpret() %s\n", toChars());
#endif
    Expression *e = EXP_CANT_INTERPRET;
    VarDeclaration *v = declaration->isVarDeclaration();
    if (v)
    {
	Dsymbol *s = v->toAlias();
	if (s == v && !v->isStatic() && v->init)
	{
	    ExpInitializer *ie = v->init->isExpInitializer();
	    if (ie)
		e = ie->exp->interpret(istate);
	    else if (v->init->isVoidInitializer())
		e = NULL;
	}
	else if (s == v && v->isConst() && v->init)
	{   e = v->init->toExpression();
	    if (!e)
		e = EXP_CANT_INTERPRET;
	    else if (!e->type)
		e->type = v->type;
	}
    }
    return e;
}

Expression *TupleExp::interpret(InterState *istate)
{
#if LOG
    printf("VarExp::interpret() %s\n", toChars());
#endif
    Expressions *expsx = NULL;

    for (size_t i = 0; i < exps->dim; i++)
    {   Expression *e = (Expression *)exps->data[i];
	Expression *ex;

	ex = e->interpret(istate);
	if (ex == EXP_CANT_INTERPRET)
	{   delete expsx;
	    return ex;
	}

	/* If any changes, do Copy On Write
	 */
	if (ex != e)
	{
	    if (!expsx)
	    {	expsx = new Expressions();
		expsx->setDim(exps->dim);
		for (size_t j = 0; j < i; j++)
		{
		    expsx->data[j] = exps->data[j];
		}
	    }
	    expsx->data[i] = (void *)ex;
	}
    }
    if (expsx)
    {	TupleExp *te = new TupleExp(loc, expsx);
	expandTuples(te->exps);
	te->type = new TypeTuple(te->exps);
	return te;
    }
    return this;
}

Expression *ArrayLiteralExp::interpret(InterState *istate)
{   Expressions *expsx = NULL;

#if LOG
    printf("ArrayLiteralExp::interpret() %s\n", toChars());
#endif
    if (elements)
    {
	for (size_t i = 0; i < elements->dim; i++)
	{   Expression *e = (Expression *)elements->data[i];
	    Expression *ex;

	    ex = e->interpret(istate);
	    if (ex == EXP_CANT_INTERPRET)
	    {   delete expsx;
		return EXP_CANT_INTERPRET;
	    }

	    /* If any changes, do Copy On Write
	     */
	    if (ex != e)
	    {
		if (!expsx)
		{   expsx = new Expressions();
		    expsx->setDim(elements->dim);
		    for (size_t j = 0; j < i; j++)
		    {
			expsx->data[j] = elements->data[j];
		    }
		}
		expsx->data[i] = (void *)ex;
	    }
	}
    }
    if (elements && expsx)
    {
	expandTuples(expsx);
	if (expsx->dim != elements->dim)
	{   delete expsx;
	    return EXP_CANT_INTERPRET;
	}
	ArrayLiteralExp *ae = new ArrayLiteralExp(loc, expsx);
	ae->type = type;
	return ae;
    }
    return this;
}

Expression *AssocArrayLiteralExp::interpret(InterState *istate)
{   Expressions *keysx = keys;
    Expressions *valuesx = values;

#if LOG
    printf("AssocArrayLiteralExp::interpret() %s\n", toChars());
#endif
    for (size_t i = 0; i < keys->dim; i++)
    {   Expression *ekey = (Expression *)keys->data[i];
	Expression *evalue = (Expression *)values->data[i];
	Expression *ex;

	ex = ekey->interpret(istate);
	if (ex == EXP_CANT_INTERPRET)
	    goto Lerr;

	/* If any changes, do Copy On Write
	 */
	if (ex != ekey)
	{
	    if (keysx == keys)
		keysx = (Expressions *)keys->copy();
	    keysx->data[i] = (void *)ex;
	}

	ex = evalue->interpret(istate);
	if (ex == EXP_CANT_INTERPRET)
	    goto Lerr;

	/* If any changes, do Copy On Write
	 */
	if (ex != evalue)
	{
	    if (valuesx == values)
		valuesx = (Expressions *)values->copy();
	    valuesx->data[i] = (void *)ex;
	}
    }
    if (keysx != keys)
	expandTuples(keysx);
    if (valuesx != values)
	expandTuples(valuesx);
    if (keysx->dim != valuesx->dim)
	goto Lerr;

    /* Remove duplicate keys
     */
    for (size_t i = 1; i < keysx->dim; i++)
    {   Expression *ekey = (Expression *)keysx->data[i - 1];

	for (size_t j = i; j < keysx->dim; j++)
	{   Expression *ekey2 = (Expression *)keysx->data[j];
	    Expression *ex = Equal(TOKequal, Type::tbool, ekey, ekey2);
	    if (ex == EXP_CANT_INTERPRET)
		goto Lerr;
	    if (ex->isBool(TRUE))	// if a match
	    {
		// Remove ekey
		if (keysx == keys)
		    keysx = (Expressions *)keys->copy();
		if (valuesx == values)
		    valuesx = (Expressions *)values->copy();
		keysx->remove(i - 1);
		valuesx->remove(i - 1);
		i -= 1;		// redo the i'th iteration
		break;
	    }
	}
    }

    if (keysx != keys || valuesx != values)
    {
	AssocArrayLiteralExp *ae;
	ae = new AssocArrayLiteralExp(loc, keysx, valuesx);
	ae->type = type;
	return ae;
    }
    return this;

Lerr:
    if (keysx != keys)
	delete keysx;
    if (valuesx != values)
	delete values;
    return EXP_CANT_INTERPRET;
}

Expression *StructLiteralExp::interpret(InterState *istate)
{   Expressions *expsx = NULL;

#if LOG
    printf("StructLiteralExp::interpret() %s\n", toChars());
#endif
    /* We don't know how to deal with overlapping fields
     */
    if (sd->hasUnions)
	return EXP_CANT_INTERPRET;

    if (elements)
    {
	for (size_t i = 0; i < elements->dim; i++)
	{   Expression *e = (Expression *)elements->data[i];
	    if (!e)
		continue;

	    Expression *ex = e->interpret(istate);
	    if (ex == EXP_CANT_INTERPRET)
	    {   delete expsx;
		return EXP_CANT_INTERPRET;
	    }

	    /* If any changes, do Copy On Write
	     */
	    if (ex != e)
	    {
		if (!expsx)
		{   expsx = new Expressions();
		    expsx->setDim(elements->dim);
		    for (size_t j = 0; j < i; j++)
		    {
			expsx->data[j] = elements->data[j];
		    }
		}
		expsx->data[i] = (void *)ex;
	    }
	}
    }
    if (elements && expsx)
    {
	expandTuples(expsx);
	if (expsx->dim != elements->dim)
	{   delete expsx;
	    return EXP_CANT_INTERPRET;
	}
	StructLiteralExp *se = new StructLiteralExp(loc, sd, expsx);
	se->type = type;
	return se;
    }
    return this;
}

Expression *UnaExp::interpretCommon(InterState *istate, Expression *(*fp)(Type *, Expression *))
{   Expression *e;
    Expression *e1;

#if LOG
    printf("UnaExp::interpretCommon() %s\n", toChars());
#endif
    e1 = this->e1->interpret(istate);
    if (e1 == EXP_CANT_INTERPRET)
	goto Lcant;
    if (e1->isConst() != 1)
	goto Lcant;

    e = (*fp)(type, e1);
    return e;

Lcant:
    return EXP_CANT_INTERPRET;
}

#define UNA_INTERPRET(op) \
Expression *op##Exp::interpret(InterState *istate)	\
{							\
    return interpretCommon(istate, &op);		\
}

UNA_INTERPRET(Neg)
UNA_INTERPRET(Com)
UNA_INTERPRET(Not)
UNA_INTERPRET(Bool)


typedef Expression *(*fp_t)(Type *, Expression *, Expression *);

Expression *BinExp::interpretCommon(InterState *istate, fp_t fp)
{   Expression *e;
    Expression *e1;
    Expression *e2;

#if LOG
    printf("BinExp::interpretCommon() %s\n", toChars());
#endif
    e1 = this->e1->interpret(istate);
    if (e1 == EXP_CANT_INTERPRET)
	goto Lcant;
    if (e1->isConst() != 1)
	goto Lcant;

    e2 = this->e2->interpret(istate);
    if (e2 == EXP_CANT_INTERPRET)
	goto Lcant;
    if (e2->isConst() != 1)
	goto Lcant;

    e = (*fp)(type, e1, e2);
    return e;

Lcant:
    return EXP_CANT_INTERPRET;
}

#define BIN_INTERPRET(op) \
Expression *op##Exp::interpret(InterState *istate)	\
{							\
    return interpretCommon(istate, &op);		\
}

BIN_INTERPRET(Add)
BIN_INTERPRET(Min)
BIN_INTERPRET(Mul)
BIN_INTERPRET(Div)
BIN_INTERPRET(Mod)
BIN_INTERPRET(Shl)
BIN_INTERPRET(Shr)
BIN_INTERPRET(Ushr)
BIN_INTERPRET(And)
BIN_INTERPRET(Or)
BIN_INTERPRET(Xor)


typedef Expression *(*fp2_t)(enum TOK, Type *, Expression *, Expression *);

Expression *BinExp::interpretCommon2(InterState *istate, fp2_t fp)
{   Expression *e;
    Expression *e1;
    Expression *e2;

#if LOG
    printf("BinExp::interpretCommon2() %s\n", toChars());
#endif
    e1 = this->e1->interpret(istate);
    if (e1 == EXP_CANT_INTERPRET)
	goto Lcant;
    if (e1->isConst() != 1 &&
	e1->op != TOKstring &&
	e1->op != TOKarrayliteral &&
	e1->op != TOKstructliteral)
	goto Lcant;

    e2 = this->e2->interpret(istate);
    if (e2 == EXP_CANT_INTERPRET)
	goto Lcant;
    if (e2->isConst() != 1 &&
	e2->op != TOKstring &&
	e2->op != TOKarrayliteral &&
	e2->op != TOKstructliteral)
	goto Lcant;

    e = (*fp)(op, type, e1, e2);
    return e;

Lcant:
    return EXP_CANT_INTERPRET;
}

#define BIN_INTERPRET2(op) \
Expression *op##Exp::interpret(InterState *istate)	\
{							\
    return interpretCommon2(istate, &op);		\
}

BIN_INTERPRET2(Equal)
BIN_INTERPRET2(Identity)
BIN_INTERPRET2(Cmp)

Expression *BinExp::interpretAssignCommon(InterState *istate, fp_t fp)
{
#if LOG
    printf("BinExp::interpretAssignCommon() %s\n", toChars());
#endif
    Expression *e = EXP_CANT_INTERPRET;
    Expression *e1 = this->e1;

    if (fp)
    {
	if (e1->op == TOKcast)
	{   CastExp *ce = (CastExp *)e1;
	    e1 = ce->e1;
	}
    }
    if (e1 == EXP_CANT_INTERPRET)
	return e1;
    Expression *e2 = this->e2->interpret(istate);
    if (e2 == EXP_CANT_INTERPRET)
	return e2;

    /* Assignment to variable of the form:
     *	v = e2
     */
    if (e1->op == TOKvar)
    {
	VarExp *ve = (VarExp *)e1;
	VarDeclaration *v = ve->var->isVarDeclaration();
	if (v && !v->isDataseg())
	{
	    /* Chase down rebinding of out and ref
	     */
	    if (v->value && v->value->op == TOKvar)
	    {
		ve = (VarExp *)v->value;
		v = ve->var->isVarDeclaration();
		assert(v);
	    }

	    if (fp && !v->value)
	    {	error("variable %s is used before initialization", v->toChars());
		return e;
	    }
	    if (fp)
		e2 = (*fp)(v->type, v->value, e2);
	    else
		e2 = Cast(v->type, v->type, e2);
	    if (e2 != EXP_CANT_INTERPRET)
	    {
		if (!v->isParameter())
		{
		    for (size_t i = 0; 1; i++)
		    {
			if (i == istate->vars.dim)
			{   istate->vars.push(v);
			    break;
			}
			if (v == (VarDeclaration *)istate->vars.data[i])
			    break;
		    }
		}
		v->value = e2;
		e = Cast(type, type, e2);
	    }
	}
    }
    /* Assignment to struct member of the form:
     *   *(symoffexp) = e2
     */
    else if (e1->op == TOKstar && ((PtrExp *)e1)->e1->op == TOKsymoff)
    {	SymOffExp *soe = (SymOffExp *)((PtrExp *)e1)->e1;
	VarDeclaration *v = soe->var->isVarDeclaration();

	if (v->isDataseg())
	    return EXP_CANT_INTERPRET;
	if (fp && !v->value)
	{   error("variable %s is used before initialization", v->toChars());
	    return e;
	}
	if (v->value->op != TOKstructliteral)
	    return EXP_CANT_INTERPRET;
	StructLiteralExp *se = (StructLiteralExp *)v->value;
	int fieldi = se->getFieldIndex(type, soe->offset);
	if (fieldi == -1)
	    return EXP_CANT_INTERPRET;
	Expression *ev = se->getField(type, soe->offset);
	if (fp)
	    e2 = (*fp)(type, ev, e2);
	else
	    e2 = Cast(type, type, e2);
	if (e2 == EXP_CANT_INTERPRET)
	    return e2;

	if (!v->isParameter())
	{
	    for (size_t i = 0; 1; i++)
	    {
		if (i == istate->vars.dim)
		{   istate->vars.push(v);
		    break;
		}
		if (v == (VarDeclaration *)istate->vars.data[i])
		    break;
	    }
	}

	/* Create new struct literal reflecting updated fieldi
	 */
	Expressions *expsx = new Expressions();
	expsx->setDim(se->elements->dim);
	for (size_t j = 0; j < expsx->dim; j++)
	{
	    if (j == fieldi)
		expsx->data[j] = (void *)e2;
	    else
		expsx->data[j] = se->elements->data[j];
	}
	v->value = new StructLiteralExp(se->loc, se->sd, expsx);

	e = Cast(type, type, e2);
    }
    /* Assignment to array element of the form:
     *   a[i] = e2
     */
    else if (e1->op == TOKindex && ((IndexExp *)e1)->e1->op == TOKvar)
    {	IndexExp *ie = (IndexExp *)e1;
	VarExp *ve = (VarExp *)ie->e1;
	VarDeclaration *v = ve->var->isVarDeclaration();

	if (!v || v->isDataseg())
	    return EXP_CANT_INTERPRET;
	if (fp && !v->value)
	{   error("variable %s is used before initialization", v->toChars());
	    return e;
	}

	ArrayLiteralExp *ae = NULL;
	AssocArrayLiteralExp *aae = NULL;
	StringExp *se = NULL;
	if (v->value->op == TOKarrayliteral)
	    ae = (ArrayLiteralExp *)v->value;
	else if (v->value->op == TOKassocarrayliteral)
	    aae = (AssocArrayLiteralExp *)v->value;
	else if (v->value->op == TOKstring)
	    se = (StringExp *)v->value;
	else
	    return EXP_CANT_INTERPRET;

	Expression *index = ie->e2->interpret(istate);
	if (index == EXP_CANT_INTERPRET)
	    return EXP_CANT_INTERPRET;
	Expression *ev;
	if (fp || ae || se)	// not for aae, because key might not be there
	{
	    ev = Index(type, v->value, index);
	    if (ev == EXP_CANT_INTERPRET)
		return EXP_CANT_INTERPRET;
	}

	if (fp)
	    e2 = (*fp)(type, ev, e2);
	else
	    e2 = Cast(type, type, e2);
	if (e2 == EXP_CANT_INTERPRET)
	    return e2;

	if (!v->isParameter())
	{
	    for (size_t i = 0; 1; i++)
	    {
		if (i == istate->vars.dim)
		{   istate->vars.push(v);
		    break;
		}
		if (v == (VarDeclaration *)istate->vars.data[i])
		    break;
	    }
	}

	if (ae)
	{
	    /* Create new array literal reflecting updated elem
	     */
	    int elemi = index->toInteger();
	    Expressions *expsx = new Expressions();
	    expsx->setDim(ae->elements->dim);
	    for (size_t j = 0; j < expsx->dim; j++)
	    {
		if (j == elemi)
		    expsx->data[j] = (void *)e2;
		else
		    expsx->data[j] = ae->elements->data[j];
	    }
	    v->value = new ArrayLiteralExp(ae->loc, expsx);
	    v->value->type = ae->type;
	}
	else if (aae)
	{
	    /* Create new associative array literal reflecting updated key/value
	     */
	    Expressions *keysx = aae->keys;
	    Expressions *valuesx = new Expressions();
	    valuesx->setDim(aae->values->dim);
	    int updated = 0;
	    for (size_t j = valuesx->dim; j; )
	    {	j--;
		Expression *ekey = (Expression *)aae->keys->data[j];
		Expression *ex = Equal(TOKequal, Type::tbool, ekey, index);
		if (ex == EXP_CANT_INTERPRET)
		    return EXP_CANT_INTERPRET;
		if (ex->isBool(TRUE))
		{   valuesx->data[j] = (void *)e2;
		    updated = 1;
		}
		else
		    valuesx->data[j] = aae->values->data[j];
	    }
	    if (!updated)
	    {	// Append index/e2 to keysx[]/valuesx[]
		valuesx->push(e2);
		keysx = (Expressions *)keysx->copy();
		keysx->push(index);
	    }
	    v->value = new AssocArrayLiteralExp(aae->loc, keysx, valuesx);
	    v->value->type = aae->type;
	}
	else if (se)
	{
	    /* Create new string literal reflecting updated elem
	     */
	    int elemi = index->toInteger();
	    unsigned char *s;
	    s = (unsigned char *)mem.calloc(se->len + 1, se->sz);
	    memcpy(s, se->string, se->len * se->sz);
	    unsigned value = e2->toInteger();
	    switch (se->sz)
	    {
		case 1:	s[elemi] = value; break;
		case 2:	((unsigned short *)s)[elemi] = value; break;
		case 4:	((unsigned *)s)[elemi] = value; break;
		default:
		    assert(0);
		    break;
	    }
	    StringExp *se2 = new StringExp(se->loc, s, se->len);
	    se2->committed = se->committed;
	    se2->postfix = se->postfix;
	    se2->type = se->type;
	    v->value = se2;
	}
	else
	    assert(0);

	e = Cast(type, type, e2);
    }
    else
    {
#ifdef DEBUG
	dump(0);
#endif
    }
    return e;
}

Expression *AssignExp::interpret(InterState *istate)
{
    return interpretAssignCommon(istate, NULL);
}

#define BIN_ASSIGN_INTERPRET(op) \
Expression *op##AssignExp::interpret(InterState *istate)	\
{								\
    return interpretAssignCommon(istate, &op);			\
}

BIN_ASSIGN_INTERPRET(Add)
BIN_ASSIGN_INTERPRET(Min)
BIN_ASSIGN_INTERPRET(Cat)
BIN_ASSIGN_INTERPRET(Mul)
BIN_ASSIGN_INTERPRET(Div)
BIN_ASSIGN_INTERPRET(Mod)
BIN_ASSIGN_INTERPRET(Shl)
BIN_ASSIGN_INTERPRET(Shr)
BIN_ASSIGN_INTERPRET(Ushr)
BIN_ASSIGN_INTERPRET(And)
BIN_ASSIGN_INTERPRET(Or)
BIN_ASSIGN_INTERPRET(Xor)

Expression *PostExp::interpret(InterState *istate)
{
#if LOG
    printf("PostExp::interpret() %s\n", toChars());
#endif
    Expression *e = EXP_CANT_INTERPRET;

    if (e1->op == TOKvar)
    {
	VarExp *ve = (VarExp *)e1;
	VarDeclaration *v = ve->var->isVarDeclaration();
	if (v && !v->isDataseg())
	{
	    /* Chase down rebinding of out and ref
	     */
	    if (v->value && v->value->op == TOKvar)
	    {
		ve = (VarExp *)v->value;
		v = ve->var->isVarDeclaration();
		assert(v);
	    }

	    if (!v->value)
	    {	error("variable %s is used before initialization", v->toChars());
		return e;
	    }
	    Expression *e2 = this->e2->interpret(istate);
	    if (e2 != EXP_CANT_INTERPRET)
	    {
		e = ((op == TOKplusplus) ? &Add : &Min)(v->type, v->value, e2);
		if (e != EXP_CANT_INTERPRET)
		{
		    if (v->isAuto())
		    {
			for (size_t i = 0; 1; i++)
			{
			    if (i == istate->vars.dim)
			    {   istate->vars.push(v);
				break;
			    }
			    if (v == (VarDeclaration *)istate->vars.data[i])
				break;
			}
		    }
		    v->value = e;
		    e = Cast(type, type, e2);
		}
	    }
	}
    }
    return e;
}

Expression *AndAndExp::interpret(InterState *istate)
{
#if LOG
    printf("AndAndExp::interpret() %s\n", toChars());
#endif
    Expression *e = e1->interpret(istate);
    if (e != EXP_CANT_INTERPRET)
    {
	if (e->isBool(FALSE))
	    e = new IntegerExp(e1->loc, 0, type);
	else if (e->isBool(TRUE))
	{
	    e = e2->interpret(istate);
	    if (e != EXP_CANT_INTERPRET)
	    {
		if (e->isBool(FALSE))
		    e = new IntegerExp(e1->loc, 0, type);
		else if (e->isBool(TRUE))
		    e = new IntegerExp(e1->loc, 1, type);
		else
		    e = EXP_CANT_INTERPRET;
	    }
	}
	else
	    e = EXP_CANT_INTERPRET;
    }
    return e;
}

Expression *OrOrExp::interpret(InterState *istate)
{
#if LOG
    printf("OrOrExp::interpret() %s\n", toChars());
#endif
    Expression *e = e1->interpret(istate);
    if (e != EXP_CANT_INTERPRET)
    {
	if (e->isBool(TRUE))
	    e = new IntegerExp(e1->loc, 1, type);
	else if (e->isBool(FALSE))
	{
	    e = e2->interpret(istate);
	    if (e != EXP_CANT_INTERPRET)
	    {
		if (e->isBool(FALSE))
		    e = new IntegerExp(e1->loc, 0, type);
		else if (e->isBool(TRUE))
		    e = new IntegerExp(e1->loc, 1, type);
		else
		    e = EXP_CANT_INTERPRET;
	    }
	}
	else
	    e = EXP_CANT_INTERPRET;
    }
    return e;
}


Expression *CallExp::interpret(InterState *istate)
{   Expression *e = EXP_CANT_INTERPRET;

#if LOG
    printf("CallExp::interpret() %s\n", toChars());
#endif
    if (e1->op == TOKvar)
    {
	FuncDeclaration *fd = ((VarExp *)e1)->var->isFuncDeclaration();
	if (fd)
	{   // Inline .dup
	    if (fd->ident == Id::adDup && arguments && arguments->dim == 2)
	    {
		e = (Expression *)arguments->data[1];
		e = e->interpret(istate);
		if (e != EXP_CANT_INTERPRET)
		{
		    e = expType(type, e);
		}
	    }
	    else
	    {
		Expression *eresult = fd->interpret(istate, arguments);
		if (eresult)
		    e = eresult;
		else if (fd->type->toBasetype()->next->ty == Tvoid)
		    e = EXP_VOID_INTERPRET;
		else
		    error("cannot evaluate %s at compile time", toChars());
	    }
	}
    }
    return e;
}

Expression *CommaExp::interpret(InterState *istate)
{
#if LOG
    printf("CommaExp::interpret() %s\n", toChars());
#endif
    Expression *e = e1->interpret(istate);
    if (e != EXP_CANT_INTERPRET)
	e = e2->interpret(istate);
    return e;
}

Expression *CondExp::interpret(InterState *istate)
{
#if LOG
    printf("CondExp::interpret() %s\n", toChars());
#endif
    Expression *e = econd->interpret(istate);
    if (e != EXP_CANT_INTERPRET)
    {
	if (e->isBool(TRUE))
	    e = e1->interpret(istate);
	else if (e->isBool(FALSE))
	    e = e2->interpret(istate);
	else
	    e = EXP_CANT_INTERPRET;
    }
    return e;
}

Expression *ArrayLengthExp::interpret(InterState *istate)
{   Expression *e;
    Expression *e1;

#if LOG
    printf("ArrayLengthExp::interpret() %s\n", toChars());
#endif
    e1 = this->e1->interpret(istate);
    if (e1 == EXP_CANT_INTERPRET)
	goto Lcant;
    if (e1->op == TOKstring || e1->op == TOKarrayliteral || e1->op == TOKassocarrayliteral)
    {
	e = ArrayLength(type, e1);
    }
    else
	goto Lcant;
    return e;

Lcant:
    return EXP_CANT_INTERPRET;
}

Expression *IndexExp::interpret(InterState *istate)
{   Expression *e;
    Expression *e1;
    Expression *e2;

#if LOG
    printf("IndexExp::interpret() %s\n", toChars());
#endif
    e1 = this->e1->interpret(istate);
    if (e1 == EXP_CANT_INTERPRET)
	goto Lcant;

    if (e1->op == TOKstring || e1->op == TOKarrayliteral)
    {
	/* Set the $ variable
	 */
	e = ArrayLength(Type::tsize_t, e1);
	if (e == EXP_CANT_INTERPRET)
	    goto Lcant;
	if (lengthVar)
	    lengthVar->value = e;
    }

    e2 = this->e2->interpret(istate);
    if (e2 == EXP_CANT_INTERPRET)
	goto Lcant;
    return Index(type, e1, e2);

Lcant:
    return EXP_CANT_INTERPRET;
}


Expression *SliceExp::interpret(InterState *istate)
{   Expression *e;
    Expression *e1;
    Expression *lwr;
    Expression *upr;

#if LOG
    printf("SliceExp::interpret() %s\n", toChars());
#endif
    e1 = this->e1->interpret(istate);
    if (e1 == EXP_CANT_INTERPRET)
	goto Lcant;
    if (!this->lwr)
    {
	e = e1->castTo(NULL, type);
	return e->interpret(istate);
    }

    /* Set the $ variable
     */
    e = ArrayLength(Type::tsize_t, e1);
    if (e == EXP_CANT_INTERPRET)
	goto Lcant;
    if (lengthVar)
	lengthVar->value = e;

    /* Evaluate lower and upper bounds of slice
     */
    lwr = this->lwr->interpret(istate);
    if (lwr == EXP_CANT_INTERPRET)
	goto Lcant;
    upr = this->upr->interpret(istate);
    if (upr == EXP_CANT_INTERPRET)
	goto Lcant;

    return Slice(type, e1, lwr, upr);

Lcant:
    return EXP_CANT_INTERPRET;
}


Expression *CatExp::interpret(InterState *istate)
{   Expression *e;
    Expression *e1;
    Expression *e2;

#if LOG
    printf("CatExp::interpret() %s\n", toChars());
#endif
    e1 = this->e1->interpret(istate);
    if (e1 == EXP_CANT_INTERPRET)
	goto Lcant;
    e2 = this->e2->interpret(istate);
    if (e2 == EXP_CANT_INTERPRET)
	goto Lcant;
    return Cat(type, e1, e2);

Lcant:
    return EXP_CANT_INTERPRET;
}


Expression *CastExp::interpret(InterState *istate)
{   Expression *e;
    Expression *e1;

#if LOG
    printf("CastExp::interpret() %s\n", toChars());
#endif
    e1 = this->e1->interpret(istate);
    if (e1 == EXP_CANT_INTERPRET)
	goto Lcant;
    return Cast(type, to, e1);

Lcant:
    return EXP_CANT_INTERPRET;
}


Expression *AssertExp::interpret(InterState *istate)
{   Expression *e;
    Expression *e1;

#if LOG
    printf("AssertExp::interpret() %s\n", toChars());
#endif
    e1 = this->e1->interpret(istate);
    if (e1 == EXP_CANT_INTERPRET)
	goto Lcant;
    if (e1->isBool(TRUE))
    {
    }
    else if (e1->isBool(FALSE))
    {
	if (msg)
	{
	    e = msg->interpret(istate);
	    if (e == EXP_CANT_INTERPRET)
		goto Lcant;
	    error("%s", e->toChars());
	}
	else
	    error("%s failed", toChars());
    }
    else
	goto Lcant;
    return e1;

Lcant:
    return EXP_CANT_INTERPRET;
}

Expression *PtrExp::interpret(InterState *istate)
{   Expression *e = EXP_CANT_INTERPRET;

#if LOG
    printf("PtrExp::interpret() %s\n", toChars());
#endif

    // Constant fold *(&structliteral + offset)
    if (e1->op == TOKadd)
    {
	e = Ptr(type, e1);
    }
    else if (e1->op == TOKsymoff)
    {	SymOffExp *soe = (SymOffExp *)e1;
	VarDeclaration *v = soe->var->isVarDeclaration();
	if (v)
	{   Expression *ev = getVarExp(istate, v);
	    if (ev != EXP_CANT_INTERPRET && ev->op == TOKstructliteral)
	    {	StructLiteralExp *se = (StructLiteralExp *)ev;
		e = se->getField(type, soe->offset);
		if (!e)
		    e = EXP_CANT_INTERPRET;
	    }
	}
    }
    return e;
}

/******************************* Special Functions ***************************/

Expression *interpret_aaLen(InterState *istate, Expressions *arguments)
{
    if (!arguments || arguments->dim != 1)
	return NULL;
    Expression *earg = (Expression *)arguments->data[0];
    earg = earg->interpret(istate);
    if (earg == EXP_CANT_INTERPRET)
	return NULL;
    if (earg->op != TOKassocarrayliteral)
	return NULL;
    AssocArrayLiteralExp *aae = (AssocArrayLiteralExp *)earg;
    Expression *e = new IntegerExp(aae->loc, aae->keys->dim, Type::tsize_t);
    return e;
}

Expression *interpret_aaKeys(InterState *istate, Expressions *arguments)
{
    printf("interpret_aaKeys()\n");
    if (!arguments || arguments->dim != 2)
	return NULL;
    Expression *earg = (Expression *)arguments->data[0];
    earg = earg->interpret(istate);
    if (earg == EXP_CANT_INTERPRET)
	return NULL;
    if (earg->op != TOKassocarrayliteral)
	return NULL;
    AssocArrayLiteralExp *aae = (AssocArrayLiteralExp *)earg;
    Expression *e = new ArrayLiteralExp(aae->loc, aae->keys);
    return e;
}

Expression *interpret_aaValues(InterState *istate, Expressions *arguments)
{
    //printf("interpret_aaValues()\n");
    if (!arguments || arguments->dim != 3)
	return NULL;
    Expression *earg = (Expression *)arguments->data[0];
    earg = earg->interpret(istate);
    if (earg == EXP_CANT_INTERPRET)
	return NULL;
    if (earg->op != TOKassocarrayliteral)
	return NULL;
    AssocArrayLiteralExp *aae = (AssocArrayLiteralExp *)earg;
    Expression *e = new ArrayLiteralExp(aae->loc, aae->values);
    //printf("result is %s\n", e->toChars());
    return e;
}

