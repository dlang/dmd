
// Compiler implementation of the D programming language
// Copyright (c) 1999-2010 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

#include "rmem.h"

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
    Expression *localThis;	// value of 'this', or NULL if none

    InterState();
};

InterState::InterState()
{
    memset(this, 0, sizeof(InterState));
}

Expression *interpret_aaLen(InterState *istate, Expressions *arguments);
Expression *interpret_aaKeys(InterState *istate, Expressions *arguments);
Expression *interpret_aaValues(InterState *istate, Expressions *arguments);

Expression *interpret_length(InterState *istate, Expression *earg);
Expression *interpret_keys(InterState *istate, Expression *earg, FuncDeclaration *fd);
Expression *interpret_values(InterState *istate, Expression *earg, FuncDeclaration *fd);

ArrayLiteralExp *createBlockDuplicatedArrayLiteral(Type *type, Expression *elem, size_t dim);

/*************************************
 * Attempt to interpret a function given the arguments.
 * Input:
 *	istate     state for calling function (NULL if none)
 *      arguments  function arguments
 *      thisarg    'this', if a needThis() function, NULL if not.	
 *
 * Return result expression if successful, NULL if not.
 */

Expression *FuncDeclaration::interpret(InterState *istate, Expressions *arguments, Expression *thisarg)
{
#if LOG
    printf("\n********\nFuncDeclaration::interpret(istate = %p) %s\n", istate, toChars());
    printf("cantInterpret = %d, semanticRun = %d\n", cantInterpret, semanticRun);
#endif
    if (global.errors)
	return NULL;

#if DMDV1
    if (ident == Id::aaLen)
	return interpret_aaLen(istate, arguments);
    else if (ident == Id::aaKeys)
	return interpret_aaKeys(istate, arguments);
    else if (ident == Id::aaValues)
	return interpret_aaValues(istate, arguments);
#endif
#if DMDV2
    if (thisarg &&
	(!arguments || arguments->dim == 0))
    {
	if (ident == Id::length)
	    return interpret_length(istate, thisarg);
	else if (ident == Id::keys)
	    return interpret_keys(istate, thisarg, this);
	else if (ident == Id::values)
	    return interpret_values(istate, thisarg, this);
    }
#endif

    if (cantInterpret || semanticRun == PASSsemantic3)
	return NULL;

    if (!fbody)
    {	cantInterpret = 1;
	return NULL;
    }

    if (semanticRun < PASSsemantic3 && scope)
    {
	semantic3(scope);
	if (global.errors)	// if errors compiling this function
	    return NULL;
    }
    if (semanticRun < PASSsemantic3done)
	return NULL;

    Type *tb = type->toBasetype();
    assert(tb->ty == Tfunction);
    TypeFunction *tf = (TypeFunction *)tb;
    Type *tret = tf->next->toBasetype();
    if (tf->varargs && arguments &&
	((parameters && arguments->dim != parameters->dim) || (!parameters && arguments->dim)))
    {	cantInterpret = 1;
	error("C-style variadic functions are not yet implemented in CTFE");
	return NULL;
    }

    InterState istatex;
    istatex.caller = istate;
    istatex.fd = this;
    istatex.localThis = thisarg;

    Expressions vsave;		// place to save previous parameter values
    size_t dim = 0;
    if (needThis() && !thisarg)
    {	cantInterpret = 1;
	// error, no this. Prevent segfault.
	error("need 'this' to access member %s", toChars());
	return NULL;
    }
    if (arguments)
    {
	dim = arguments->dim;
	assert(!dim || (parameters && (parameters->dim == dim)));
	vsave.setDim(dim);

	/* Evaluate all the arguments to the function,
	 * store the results in eargs[]
	 */
	Expressions eargs;
	eargs.setDim(dim);

	for (size_t i = 0; i < dim; i++)
	{   Expression *earg = (Expression *)arguments->data[i];
	    Parameter *arg = Parameter::getNth(tf->parameters, i);

	    if (arg->storageClass & (STCout | STCref | STClazy))
	    {
	    }
	    else
	    {	/* Value parameters
		 */
		Type *ta = arg->type->toBasetype();
		if (ta->ty == Tsarray && earg->op == TOKaddress)
		{
		    /* Static arrays are passed by a simple pointer.
		     * Skip past this to get at the actual arg.
		     */
		    earg = ((AddrExp *)earg)->e1;
		}
		earg = earg->interpret(istate ? istate : &istatex);
		if (earg == EXP_CANT_INTERPRET)
		{   cantInterpret = 1;
		    return NULL;
		}
	    }
	    eargs.data[i] = earg;
	}

	for (size_t i = 0; i < dim; i++)
	{   Expression *earg = (Expression *)eargs.data[i];
	    Parameter *arg = Parameter::getNth(tf->parameters, i);
	    VarDeclaration *v = (VarDeclaration *)parameters->data[i];
	    vsave.data[i] = v->value;
#if LOG
	    printf("arg[%d] = %s\n", i, earg->toChars());
#endif
	    if (arg->storageClass & (STCout | STCref) && earg->op==TOKvar)
	    {
		/* Bind out or ref parameter to the corresponding
		 * variable v2
		 */
		if (!istate)
		{   cantInterpret = 1;
		    error("%s cannot be by passed by reference at compile time", earg->toChars());
		    return NULL;	// can't bind to non-interpreted vars
		}		
		// We need to chase down all of the the passed parameters until
		// we find something that isn't a TOKvar, then create a variable
		// containg that expression.
		VarDeclaration *v2;
		while (1)
		{
		    VarExp *ve = (VarExp *)earg;
		    v2 = ve->var->isVarDeclaration();
		    if (!v2)
		    {   cantInterpret = 1;
			return NULL;
		    }
		    if (!v2->value || v2->value->op != TOKvar)
			break;
		    if (((VarExp *)v2->value)->var->isSymbolDeclaration())		   
		    {	// This can happen if v is a struct initialized to
			// 0 using an __initZ SymbolDeclaration from
			// TypeStruct::defaultInit()
			break; // eg default-initialized variable
		    }
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
	    {	// Value parameters and non-trivial references
		v->value = earg;
	    }
#if LOG
	    printf("interpreted arg[%d] = %s\n", i, earg->toChars());
#endif
	}
    }
    // Don't restore the value of 'this' upon function return
    if (needThis() && thisarg->op == TOKvar && istate)
    {
	VarDeclaration *thisvar = ((VarExp *)(thisarg))->var->isVarDeclaration();
    	for (size_t i = 0; i < istate->vars.dim; i++)
	{   VarDeclaration *v = (VarDeclaration *)istate->vars.data[i];
	    if (v == thisvar)
	    {	istate->vars.data[i] = NULL;
		break;
	    }
	}
    }

    /* Save the values of the local variables used
     */
    Expressions valueSaves;
    if (istate && !isNested())
    {
	//printf("saving local variables...\n");
	valueSaves.setDim(istate->vars.dim);
	for (size_t i = 0; i < istate->vars.dim; i++)
	{   VarDeclaration *v = (VarDeclaration *)istate->vars.data[i];
	    if (v)
	    {
		//printf("\tsaving [%d] %s = %s\n", i, v->toChars(), v->value ? v->value->toChars() : "");
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

    if (istate && !isNested())
    {
	/* Restore the variable values
	 */
	//printf("restoring local variables...\n");
	for (size_t i = 0; i < istate->vars.dim; i++)
	{   VarDeclaration *v = (VarDeclaration *)istate->vars.data[i];
	    if (v)
	    {	v->value = (Expression *)valueSaves.data[i];
		//printf("\trestoring [%d] %s = %s\n", i, v->toChars(), v->value ? v->value->toChars() : "");
	    }
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
	    //printf("-ExpStatement::interpret(): %p\n", e);
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
	if (e->isBool(TRUE))
	    e = ifbody ? ifbody->interpret(istate) : NULL;
	else if (e->isBool(FALSE))
	    e = elsebody ? elsebody->interpret(istate) : NULL;
	else
	{
	    e = EXP_CANT_INTERPRET;
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
    assert(0);			// rewritten to ForStatement
    return NULL;
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
	if (!condition)
	    goto Lhead;
	e = condition->interpret(istate);
	if (e == EXP_CANT_INTERPRET)
	    break;
	if (!e->isConst())
	{   e = EXP_CANT_INTERPRET;
	    break;
	}
	if (e->isBool(TRUE))
	{
	Lhead:
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
	    if (increment)
	    {
		e = increment->interpret(istate);
		if (e == EXP_CANT_INTERPRET)
		    break;
	    }
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

    Expression *keysave = key ? key->value : NULL;
    Expression *valuesave = value->value;

    uinteger_t d = dim->toUInteger();
    uinteger_t index;

    if (op == TOKforeach)
    {
	for (index = 0; index < d; index++)
	{
	    Expression *ekey = new IntegerExp(loc, index, Type::tsize_t);
	    if (key)
		key->value = ekey;
	    e = Index(value->type, eaggr, ekey);
	    if (e == EXP_CANT_INTERPRET)
		break;
	    value->value = e;

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
	    e = Index(value->type, eaggr, ekey);
	    if (e == EXP_CANT_INTERPRET)
		break;
	    value->value = e;

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
    value->value = valuesave;
    if (key)
	key->value = keysave;
    return e;
}

#if DMDV2
Expression *ForeachRangeStatement::interpret(InterState *istate)
{
#if LOG
    printf("ForeachRangeStatement::interpret()\n");
#endif
    if (istate->start == this)
	istate->start = NULL;
    if (istate->start)
	return NULL;

    Expression *e = NULL;
    Expression *elwr = lwr->interpret(istate);
    if (elwr == EXP_CANT_INTERPRET)
	return EXP_CANT_INTERPRET;

    Expression *eupr = upr->interpret(istate);
    if (eupr == EXP_CANT_INTERPRET)
	return EXP_CANT_INTERPRET;

    Expression *keysave = key->value;

    if (op == TOKforeach)
    {
	key->value = elwr;

	while (1)
	{
	    e = Cmp(TOKlt, key->value->type, key->value, eupr);
	    if (e == EXP_CANT_INTERPRET)
		break;
	    if (e->isBool(TRUE) == FALSE)
	    {	e = NULL;
		break;
	    }

	    e = body ? body->interpret(istate) : NULL;
	    if (e == EXP_CANT_INTERPRET)
		break;
	    if (e == EXP_BREAK_INTERPRET)
	    {   e = NULL;
		break;
	    }
	    if (e == NULL || e == EXP_CONTINUE_INTERPRET)
	    {	e = Add(key->value->type, key->value, new IntegerExp(loc, 1, key->value->type));
		if (e == EXP_CANT_INTERPRET)
		    break;
		key->value = e;
	    }
	    else
		break;
	}
    }
    else // TOKforeach_reverse
    {
	key->value = eupr;

	do
	{
	    e = Cmp(TOKgt, key->value->type, key->value, elwr);
	    if (e == EXP_CANT_INTERPRET)
		break;
	    if (e->isBool(TRUE) == FALSE)
	    {	e = NULL;
		break;
	    }

	    e = Min(key->value->type, key->value, new IntegerExp(loc, 1, key->value->type));
	    if (e == EXP_CANT_INTERPRET)
		break;
	    key->value = e;

	    e = body ? body->interpret(istate) : NULL;
	    if (e == EXP_CANT_INTERPRET)
		break;
	    if (e == EXP_BREAK_INTERPRET)
	    {   e = NULL;
		break;
	    }
	} while (e == NULL || e == EXP_CONTINUE_INTERPRET);
    }
    key->value = keysave;
    return e;
}
#endif

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
    printf("type = %s\n", type->toChars());
    dump(0);
#endif
    error("Cannot interpret %s at compile time", toChars());
    return EXP_CANT_INTERPRET;
}

Expression *ThisExp::interpret(InterState *istate)
{
    if (istate->localThis)
        return istate->localThis->interpret(istate);
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

Expression *FuncExp::interpret(InterState *istate)
{
#if LOG
    printf("FuncExp::interpret() %s\n", toChars());
#endif
    return this;
}

Expression *SymOffExp::interpret(InterState *istate)
{
#if LOG
    printf("SymOffExp::interpret() %s\n", toChars());
#endif
    if (var->isFuncDeclaration() && offset == 0)
    {
	return this;
    }
    error("Cannot interpret %s at compile time", toChars());
    return EXP_CANT_INTERPRET;
}

Expression *DelegateExp::interpret(InterState *istate)
{
#if LOG
    printf("DelegateExp::interpret() %s\n", toChars());
#endif
    return this;
}

Expression *getVarExp(Loc loc, InterState *istate, Declaration *d)
{
    Expression *e = EXP_CANT_INTERPRET;
    VarDeclaration *v = d->isVarDeclaration();
    SymbolDeclaration *s = d->isSymbolDeclaration();
    if (v)
    {
#if DMDV2
	/* Magic variable __ctfe always returns true when interpreting
	 */
	if (v->ident == Id::ctfe)
	    return new IntegerExp(loc, 1, Type::tbool);

	if ((v->isConst() || v->isImmutable() || v->storage_class & STCmanifest) && v->init && !v->value)
#else
	if (v->isConst() && v->init)
#endif
	{   e = v->init->toExpression();
	    if (e && !e->type)
		e->type = v->type;
	}
	else if (v->isCTFE() && !v->value)
	{
	    if (v->init)
	    {
		e = v->init->toExpression();
		e = e->interpret(istate);
	    }
	    else // This should never happen
		e = v->type->defaultInitLiteral();
	}
	else
	{   e = v->value;
	    if (!v->isCTFE())
	    {	error(loc, "static variable %s cannot be read at compile time", v->toChars());
		e = EXP_CANT_INTERPRET;
	    }
	    else if (!e)
		error(loc, "variable %s is used before initialization", v->toChars());
	    else if (e != EXP_CANT_INTERPRET)
		e = e->interpret(istate);
	}
	if (!e)
	    e = EXP_CANT_INTERPRET;
    }
    else if (s)
    {
	if (s->dsym->toInitializer() == s->sym)
	{   Expressions *exps = new Expressions();
	    e = new StructLiteralExp(0, s->dsym, exps);
	    e = e->semantic(NULL);
	}
    }
    return e;
}

Expression *VarExp::interpret(InterState *istate)
{
#if LOG
    printf("VarExp::interpret() %s\n", toChars());
#endif
    return getVarExp(loc, istate, var);
}

Expression *DeclarationExp::interpret(InterState *istate)
{
#if LOG
    printf("DeclarationExp::interpret() %s\n", toChars());
#endif
    Expression *e;
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
#if DMDV2
	else if (s == v && (v->isConst() || v->isImmutable()) && v->init)
#else
	else if (s == v && v->isConst() && v->init)
#endif
	{   e = v->init->toExpression();
	    if (!e)
		e = EXP_CANT_INTERPRET;
	    else if (!e->type)
		e->type = v->type;
	}
    }
    else if (declaration->isAttribDeclaration() ||
	     declaration->isTemplateMixin() ||
	     declaration->isTupleDeclaration())
    {	// These can be made to work, too lazy now
    error("Declaration %s is not yet implemented in CTFE", toChars());

	e = EXP_CANT_INTERPRET;
    }
    else
    {	// Others should not contain executable code, so are trivial to evaluate
	e = NULL;
    }
#if LOG
    printf("-DeclarationExp::interpret(%s): %p\n", toChars(), e);
#endif
    return e;
}

Expression *TupleExp::interpret(InterState *istate)
{
#if LOG
    printf("TupleExp::interpret() %s\n", toChars());
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
		goto Lerror;

	    /* If any changes, do Copy On Write
	     */
	    if (ex != e)
	    {
		if (!expsx)
		{   expsx = new Expressions();
		    expsx->setDim(elements->dim);
		    for (size_t j = 0; j < elements->dim; j++)
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
	    goto Lerror;
	ArrayLiteralExp *ae = new ArrayLiteralExp(loc, expsx);
	ae->type = type;
	return ae;
    }
    return this;

Lerror:
    if (expsx)
	delete expsx;
    error("cannot interpret array literal");
    return EXP_CANT_INTERPRET;
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
	{   error("Unions with overlapping fields are not yet supported in CTFE");
		return EXP_CANT_INTERPRET;
    }

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
		    for (size_t j = 0; j < elements->dim; j++)
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

Expression *NewExp::interpret(InterState *istate)
{
#if LOG
    printf("NewExp::interpret() %s\n", toChars());
#endif
    if (newtype->ty == Tarray && arguments && arguments->dim == 1)
    {
	Expression *lenExpr = ((Expression *)(arguments->data[0]))->interpret(istate);
	if (lenExpr == EXP_CANT_INTERPRET)
	    return EXP_CANT_INTERPRET;
	return createBlockDuplicatedArrayLiteral(newtype,
	    newtype->defaultInitLiteral(), lenExpr->toInteger());
    }
    error("Cannot interpret %s at compile time", toChars());
    return EXP_CANT_INTERPRET;
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
	e1->op != TOKnull &&
	e1->op != TOKstring &&
	e1->op != TOKarrayliteral &&
	e1->op != TOKstructliteral)
	goto Lcant;

    e2 = this->e2->interpret(istate);
    if (e2 == EXP_CANT_INTERPRET)
	goto Lcant;
    if (e2->isConst() != 1 &&
	e2->op != TOKnull &&
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

/* Helper functions for BinExp::interpretAssignCommon
 */

/***************************************
 * Duplicate the elements array, then set field 'indexToChange' = newelem.
 */
Expressions *changeOneElement(Expressions *oldelems, size_t indexToChange, void *newelem)
{
    Expressions *expsx = new Expressions();
    expsx->setDim(oldelems->dim);
    for (size_t j = 0; j < expsx->dim; j++)
    {
	if (j == indexToChange)
	    expsx->data[j] = newelem;
	else
	    expsx->data[j] = oldelems->data[j];
    }
    return expsx;
}

/***************************************
 * Returns oldelems[0..insertpoint] ~ newelems ~ oldelems[insertpoint+newelems.length..$]
 */
Expressions *spliceElements(Expressions *oldelems,
	Expressions *newelems, size_t insertpoint)
{
    Expressions *expsx = new Expressions();
    expsx->setDim(oldelems->dim);
    for (size_t j = 0; j < expsx->dim; j++)
    {
	if (j >= insertpoint && j < insertpoint + newelems->dim)
	    expsx->data[j] = newelems->data[j - insertpoint];
	else
	    expsx->data[j] = oldelems->data[j];
    }
    return expsx;
}

/***************************************
 * Returns oldstr[0..insertpoint] ~ newstr ~ oldstr[insertpoint+newlen..$]
 */
StringExp *spliceStringExp(StringExp *oldstr, StringExp *newstr, size_t insertpoint)
{
    assert(oldstr->sz==newstr->sz);
    unsigned char *s;
    size_t oldlen = oldstr->len;
    size_t newlen = newstr->len;
    size_t sz = oldstr->sz;
    s = (unsigned char *)mem.calloc(oldlen + 1, sz);
    memcpy(s, oldstr->string, oldlen * sz);
    memcpy(s + insertpoint * sz, newstr->string, newlen * sz);
    StringExp *se2 = new StringExp(oldstr->loc, s, oldlen);
    se2->committed = oldstr->committed;
    se2->postfix = oldstr->postfix;
    se2->type = oldstr->type;
    return se2;
}

/******************************
 * Create an array literal consisting of 'elem' duplicated 'dim' times.
 */
ArrayLiteralExp *createBlockDuplicatedArrayLiteral(Type *type,
	Expression *elem, size_t dim)
{
    Expressions *elements = new Expressions();
    elements->setDim(dim);
    for (size_t i = 0; i < dim; i++)
	 elements->data[i] = elem;	
    ArrayLiteralExp *ae = new ArrayLiteralExp(0, elements);
    ae->type = type;
    return ae;
}

/******************************
 * Create a string literal consisting of 'value' duplicated 'dim' times.
 */
StringExp *createBlockDuplicatedStringLiteral(Type *type,
	unsigned value, size_t dim, int sz)
{
    unsigned char *s;
    s = (unsigned char *)mem.calloc(dim + 1, sz);
    for (int elemi=0; elemi<dim; ++elemi)
    {
    	switch (sz)
	{
	    case 1:	s[elemi] = value; break;
	    case 2:	((unsigned short *)s)[elemi] = value; break;
	    case 4:	((unsigned *)s)[elemi] = value; break;
	    default:    assert(0);
	}
    }
    StringExp *se = new StringExp(0, s, dim);
    se->type = type;
    return se;
}

/********************************
 *  Add v to the istate list, unless it already exists there.
 */
void addVarToInterstate(InterState *istate, VarDeclaration *v)
{
    if (!v->isParameter())
    {
	for (size_t i = 0; 1; i++)
	{
	    if (i == istate->vars.dim)
	    {   istate->vars.push(v);
		//printf("\tadding %s to istate\n", v->toChars());
		break;
	    }
	    if (v == (VarDeclaration *)istate->vars.data[i])
		break;
	}
    }
}

Expression *BinExp::interpretAssignCommon(InterState *istate, fp_t fp, int post)
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
	
    // Chase down rebinding of out and ref.
    if (e1->op == TOKvar)
    {
	VarExp *ve = (VarExp *)e1;
	VarDeclaration *v = ve->var->isVarDeclaration();
	if (v && v->value && v->value->op == TOKvar)
	{
	    VarExp *ve2 = (VarExp *)v->value;
	    if (ve2->var->isSymbolDeclaration())
	    {	// This can happen if v is a struct initialized to
		// 0 using an __initZ SymbolDeclaration from
		// TypeStruct::defaultInit()
	    }
	    else
		e1 = v->value;
	}
	else if (v && v->value && (v->value->op==TOKindex || v->value->op == TOKdotvar))
	{
            // It is no longer a TOKvar, eg when a[4] is passed by ref.
	    e1 = v->value;	    
	}
    }

    // To reduce code complexity of handling dotvar expressions,
    // extract the aggregate now.
    Expression *aggregate;
    if (e1->op == TOKdotvar)
    {
        aggregate = ((DotVarExp *)e1)->e1;
	// Get rid of 'this'.
        if (aggregate->op == TOKthis && istate->localThis)
            aggregate = istate->localThis;
    }
    if (e1->op == TOKthis && istate->localThis)
	e1 = istate->localThis;

    /* Assignment to variable of the form:
     *	v = e2
     */
    if (e1->op == TOKvar)
    {
	VarExp *ve = (VarExp *)e1;
	VarDeclaration *v = ve->var->isVarDeclaration();
	assert(v);
   	if (v && !v->isCTFE())
	{   // Can't modify global or static data
	    error("%s cannot be modified at compile time", v->toChars());
	    return EXP_CANT_INTERPRET;
	}
	if (v && v->isCTFE())
	{
	    Expression *ev = v->value;
	    if (fp && !ev)
	    {	error("variable %s is used before initialization", v->toChars());
		return e;
	    }
	    if (fp)
		e2 = (*fp)(v->type, ev, e2);
	    else
	    {	/* Look for special case of struct being initialized with 0.
		 */
		if (v->type->toBasetype()->ty == Tstruct && e2->op == TOKint64)
		{
		    e2 = v->type->defaultInitLiteral();
		}
		e2 = Cast(v->type, v->type, e2);
	    }
	    if (e2 == EXP_CANT_INTERPRET)
		return e2;

	    if (istate)
		addVarToInterstate(istate, v);
	    v->value = e2;
	    e = Cast(type, type, post ? ev : e2);
	}
    }
    else if (e1->op == TOKdotvar && aggregate->op == TOKdotvar)
    {	// eg  v.u.var = e2,  v[3].u.var = e2, etc.
	error("Nested struct assignment %s is not yet supported in CTFE", toChars());
    }
    /* Assignment to struct member of the form:
     *   v.var = e2
     */
    else if (e1->op == TOKdotvar && aggregate->op == TOKvar)
    {	VarDeclaration *v = ((VarExp *)aggregate)->var->isVarDeclaration();

	if (!v->isCTFE())
	{   // Can't modify global or static data
	    error("%s cannot be modified at compile time", v->toChars());
	    return EXP_CANT_INTERPRET;
	} else {
	    // Chase down rebinding of out and ref
	    if (v->value && v->value->op == TOKvar)
	    {
		VarExp *ve2 = (VarExp *)v->value;
		if (ve2->var->isSymbolDeclaration())
		{	// This can happen if v is a struct initialized to
			// 0 using an __initZ SymbolDeclaration from
			// TypeStruct::defaultInit()
		}
		else
		    v = ve2->var->isVarDeclaration();
		assert(v);
	    }
	}
	if (fp && !v->value)
	{   error("variable %s is used before initialization", v->toChars());
	    return e;
	}
	if (v->value == NULL && v->init->isVoidInitializer())
	{   /* Since a void initializer initializes to undefined
	     * values, it is valid here to use the default initializer.
	     * No attempt is made to determine if someone actually relies
	     * on the void value - to do that we'd need a VoidExp.
	     * That's probably a good enhancement idea.
	     */
	    v->value = v->type->defaultInitLiteral();
	}
	Expression *vie = v->value;
	assert(vie != EXP_CANT_INTERPRET);

	if (vie->op == TOKvar)
	{
	    Declaration *d = ((VarExp *)vie)->var;
	    vie = getVarExp(e1->loc, istate, d);
	}
	if (vie->op != TOKstructliteral)
	{
	    error("Cannot assign %s=%s in CTFE", v->toChars(), vie->toChars());
	    return EXP_CANT_INTERPRET;
	}
	StructLiteralExp *se = (StructLiteralExp *)vie;
	VarDeclaration *vf = ((DotVarExp *)e1)->var->isVarDeclaration();
	if (!vf)
	    return EXP_CANT_INTERPRET;
	int fieldi = se->getFieldIndex(type, vf->offset);
	if (fieldi == -1)
	    return EXP_CANT_INTERPRET;
	Expression *ev = se->getField(type, vf->offset);
	if (fp)
	    e2 = (*fp)(type, ev, e2);
	else
	    e2 = Cast(type, type, e2);
	if (e2 == EXP_CANT_INTERPRET)
	    return e2;

	addVarToInterstate(istate, v);

	/* Create new struct literal reflecting updated fieldi
	 */
	Expressions *expsx = changeOneElement(se->elements, fieldi, e2);
	v->value = new StructLiteralExp(se->loc, se->sd, expsx);
	v->value->type = se->type;

	e = Cast(type, type, post ? ev : e2);
    }
    /* Assignment to struct member of the form:
     *   *(symoffexp) = e2
     */
    else if (e1->op == TOKstar && ((PtrExp *)e1)->e1->op == TOKsymoff)
    {	SymOffExp *soe = (SymOffExp *)((PtrExp *)e1)->e1;
	VarDeclaration *v = soe->var->isVarDeclaration();

	if (!v->isCTFE())
	{
	    error("%s cannot be modified at compile time", v->toChars());
	    return EXP_CANT_INTERPRET;
	}
	if (fp && !v->value)
	{   error("variable %s is used before initialization", v->toChars());
	    return e;
	}
	Expression *vie = v->value;
	if (vie->op == TOKvar)
	{
	    Declaration *d = ((VarExp *)vie)->var;
	    vie = getVarExp(e1->loc, istate, d);
	}
	if (vie->op != TOKstructliteral)
	    return EXP_CANT_INTERPRET;
	StructLiteralExp *se = (StructLiteralExp *)vie;
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

   	addVarToInterstate(istate, v);

	/* Create new struct literal reflecting updated fieldi
	 */
	Expressions *expsx = changeOneElement(se->elements, fieldi, e2);
	v->value = new StructLiteralExp(se->loc, se->sd, expsx);
	v->value->type = se->type;

	e = Cast(type, type, post ? ev : e2);
    }
    /* Assignment to array element of the form:
     *   a[i] = e2
     */
    else if (e1->op == TOKindex && ((IndexExp *)e1)->e1->op == TOKvar)
    {	IndexExp *ie = (IndexExp *)e1;
	VarExp *ve = (VarExp *)ie->e1;
	VarDeclaration *v = ve->var->isVarDeclaration();
	if (!v || !v->isCTFE())
	{
	    error("%s cannot be modified at compile time", v ? v->toChars(): "void");
	    return EXP_CANT_INTERPRET;
	}
	    if (v->value && v->value->op == TOKvar)
	    {
		VarExp *ve2 = (VarExp *)v->value;
		if (ve2->var->isSymbolDeclaration())
		{	// This can happen if v is a struct initialized to
			// 0 using an __initZ SymbolDeclaration from
			// TypeStruct::defaultInit()
		}
		else
		    v = ve2->var->isVarDeclaration();
		assert(v);
	    }
	if (!v->value)
	{
	    if (fp)
	    {   error("variable %s is used before initialization", v->toChars());
		return e;
	    }

	    Type *t = v->type->toBasetype();
	    if (t->ty == Tsarray)
	    {
		/* This array was void initialized. Create a
		 * default initializer for it.
		 * What we should do is fill the array literal with
		 * NULL data, so use-before-initialized can be detected.
		 * But we're too lazy at the moment to do it, as that
		 * involves redoing Index() and whoever calls it.
		 */

		size_t dim = ((TypeSArray *)t)->dim->toInteger();
	        v->value = createBlockDuplicatedArrayLiteral(v->type,
			v->type->defaultInit(), dim);
	    }
	    else
		return EXP_CANT_INTERPRET;
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
	else if (v->value->op == TOKnull)
	{
	    // This would be a runtime segfault
	    error("Cannot index null array %s", v->toChars());
	    return EXP_CANT_INTERPRET;
	}
	else
	    return EXP_CANT_INTERPRET;

	/* Set the $ variable
	 */
	Expression *ee = ArrayLength(Type::tsize_t, v->value);
	if (ee != EXP_CANT_INTERPRET && ie->lengthVar)
	    ie->lengthVar->value = ee;
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
	
	addVarToInterstate(istate, v);
	if (ae)
	{
	    /* Create new array literal reflecting updated elem
	     */
	    int elemi = index->toInteger();
	    Expressions *expsx = changeOneElement(ae->elements, elemi, e2);
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

	e = Cast(type, type, post ? ev : e2);
    }
    
    /* Assignment to struct element in array, of the form:
     *  a[i].var = e2
     */
    else if (e1->op == TOKdotvar && aggregate->op == TOKindex &&
	     ((IndexExp *)aggregate)->e1->op == TOKvar)
    {
        IndexExp * ie = (IndexExp *)aggregate;
	VarExp *ve = (VarExp *)(ie->e1);
	VarDeclaration *v = ve->var->isVarDeclaration();
	if (!v || !v->isCTFE())
	{
	    error("%s cannot be modified at compile time", v ? v->toChars(): "void");
	    return EXP_CANT_INTERPRET;
	}
	Type *t = ve->type->toBasetype();
	ArrayLiteralExp *ae = (ArrayLiteralExp *)v->value;
	if (!ae)
	{
	    // assignment to one element in an uninitialized (static) array.
	    // This is quite difficult, because defaultInit() for a struct is a VarExp,
	    // not a StructLiteralExp.
	    Type *t = v->type->toBasetype();
	    if (t->ty != Tsarray)
	    {
		error("Cannot index an uninitialized variable");
		return EXP_CANT_INTERPRET;
	    }

	    Type *telem = ((TypeSArray *)t)->nextOf()->toBasetype();
	    if (telem->ty != Tstruct) { return EXP_CANT_INTERPRET; }

	    // Create a default struct literal...
	    Expression *structinit = telem->defaultInitLiteral(v->loc);

	    // ... and use to create a blank array literal
	    size_t dim = ((TypeSArray *)t)->dim->toInteger();
	    ae = createBlockDuplicatedArrayLiteral(v->type, structinit, dim);
	    v->value = ae;
	}
	if ((Expression *)(ae->elements) == EXP_CANT_INTERPRET)
	{
	    // Note that this would be a runtime segfault
	    error("Cannot index null array %s", v->toChars());
	    return EXP_CANT_INTERPRET;
	}
	// Set the $ variable
	Expression *ee = ArrayLength(Type::tsize_t, v->value);
	if (ee != EXP_CANT_INTERPRET && ie->lengthVar)
	    ie->lengthVar->value = ee;
	// Determine the index, and check that it's OK.
	Expression *index = ie->e2->interpret(istate);
	if (index == EXP_CANT_INTERPRET)
	    return EXP_CANT_INTERPRET;

	int elemi = index->toInteger();
	if (elemi >= ae->elements->dim)
	{
	    error("array index %d is out of bounds %s[0..%d]", elemi,
		v->toChars(), ae->elements->dim);
	    return EXP_CANT_INTERPRET;
	}
	// Get old element
	Expression *vie = (Expression *)(ae->elements->data[elemi]);
	if (vie->op != TOKstructliteral)
	    return EXP_CANT_INTERPRET;

	// Work out which field needs to be changed
	StructLiteralExp *se = (StructLiteralExp *)vie;
	VarDeclaration *vf = ((DotVarExp *)e1)->var->isVarDeclaration();
	if (!vf)
	    return EXP_CANT_INTERPRET;

	int fieldi = se->getFieldIndex(type, vf->offset);
	if (fieldi == -1)
	    return EXP_CANT_INTERPRET;
		
	Expression *ev = se->getField(type, vf->offset);
	if (fp)
	    e2 = (*fp)(type, ev, e2);
	else
	    e2 = Cast(type, type, e2);
	if (e2 == EXP_CANT_INTERPRET)
	    return e2;

	// Create new struct literal reflecting updated field
	Expressions *expsx = changeOneElement(se->elements, fieldi, e2);
	Expression * newstruct = new StructLiteralExp(se->loc, se->sd, expsx);

	// Create new array literal reflecting updated struct elem
	ae->elements = changeOneElement(ae->elements, elemi, newstruct);
	return ae;
    }
    /* Slice assignment, initialization of static arrays
     *   a[] = e
     */
    else if (e1->op == TOKslice && ((SliceExp *)e1)->e1->op==TOKvar)
    {
        SliceExp * sexp = (SliceExp *)e1;
	VarExp *ve = (VarExp *)(sexp->e1);
	VarDeclaration *v = ve->var->isVarDeclaration();
	if (!v || !v->isCTFE())
	{
	    error("%s cannot be modified at compile time", v->toChars());
	    return EXP_CANT_INTERPRET;
	}
        // Chase down rebinding of out and ref
        if (v->value && v->value->op == TOKvar)
        {
	    VarExp *ve2 = (VarExp *)v->value;
	    if (ve2->var->isSymbolDeclaration())
	    {	// This can happen if v is a struct initialized to
		// 0 using an __initZ SymbolDeclaration from
		// TypeStruct::defaultInit()
	    }
	    else
		v = ve2->var->isVarDeclaration();
	    assert(v);
	}
	/* Set the $ variable
	 */
	Expression *ee = v->value ? ArrayLength(Type::tsize_t, v->value)
				  : EXP_CANT_INTERPRET;
	if (ee != EXP_CANT_INTERPRET && sexp->lengthVar)
	    sexp->lengthVar->value = ee;
	Expression *upper = NULL;
	Expression *lower = NULL;
	if (sexp->upr)
	{
	    upper = sexp->upr->interpret(istate);
	    if (upper == EXP_CANT_INTERPRET)
		return EXP_CANT_INTERPRET;
	}
	if (sexp->lwr)
	{
	    lower = sexp->lwr->interpret(istate);
	    if (lower == EXP_CANT_INTERPRET)
		return EXP_CANT_INTERPRET;
	}
	Type *t = v->type->toBasetype();
	size_t dim;
	if (t->ty == Tsarray)			
	    dim = ((TypeSArray *)t)->dim->toInteger();
	else if (t->ty == Tarray)
	{
	    if (!v->value || v->value->op == TOKnull)
	    {
		error("cannot assign to null array %s", v->toChars());
		return EXP_CANT_INTERPRET;
	    }
	    if (v->value->op == TOKarrayliteral)
		dim = ((ArrayLiteralExp *)v->value)->elements->dim;
	    else if (v->value->op ==TOKstring)
	       dim = ((StringExp *)v->value)->len;
	}
	else
	{
	    error("%s cannot be evaluated at compile time", toChars());
	    return EXP_CANT_INTERPRET;
	}
	int upperbound = upper ? upper->toInteger() : dim;
	int lowerbound = lower ? lower->toInteger() : 0;

	if (((int)lowerbound < 0) || (upperbound > dim))
	{
	    error("Array bounds [0..%d] exceeded in slice [%d..%d]",
		dim, lowerbound, upperbound);
	    return EXP_CANT_INTERPRET;
	}
	// Could either be slice assignment (v[] = e[]), 
	// or block assignment (v[] = val). 
	// For the former, we check that the lengths match.
	bool isSliceAssignment = (e2->op == TOKarrayliteral)
	    || (e2->op == TOKstring);
	size_t srclen = 0;
	if (e2->op == TOKarrayliteral)
	    srclen = ((ArrayLiteralExp *)e2)->elements->dim;
	else if (e2->op == TOKstring)
	    srclen = ((StringExp *)e2)->len;
	if (isSliceAssignment && srclen != (upperbound - lowerbound))
	{
	    error("Array length mismatch assigning [0..%d] to [%d..%d]", srclen, lowerbound, upperbound);
	    return e;
	}
	if (e2->op == TOKarrayliteral)
	{
	    // Static array assignment from literal
	    ArrayLiteralExp *ae = (ArrayLiteralExp *)e2;				
	    if (upperbound - lowerbound == dim)
		v->value = ae;
	    else
	    {
		ArrayLiteralExp *existing;
		// Only modifying part of the array. Must create a new array literal.
		// If the existing array is uninitialized (this can only happen
		// with static arrays), create it.
		if (v->value && v->value->op == TOKarrayliteral)
		    existing = (ArrayLiteralExp *)v->value;
		else // this can only happen with static arrays
		    existing = createBlockDuplicatedArrayLiteral(v->type, v->type->defaultInit(), dim);
		// value[] = value[0..lower] ~ ae ~ value[upper..$]
		existing->elements = spliceElements(existing->elements, ae->elements, lowerbound);
		v->value = existing;
	    }
	    return e2;
	}
	else if (e2->op == TOKstring)
	{
	    StringExp *se = (StringExp *)e2;
	    if (upperbound-lowerbound == dim)
	        v->value = e2;		
	    else
	    {
		if (!v->value)
		    v->value = createBlockDuplicatedStringLiteral(se->type,
			se->type->defaultInit()->toInteger(), dim, se->sz);
		if (v->value->op==TOKstring)
	            v->value = spliceStringExp((StringExp *)v->value, se, lowerbound);
		else
	            error("String slice assignment is not yet supported in CTFE");
	    }
	    return e2;
	}
	else if (t->nextOf()->ty == e2->type->ty)
	{
	    // Static array block assignment
	    if (upperbound - lowerbound == dim)
		v->value = createBlockDuplicatedArrayLiteral(v->type, e2, dim);
	    else
	    {
		ArrayLiteralExp *existing;
		// Only modifying part of the array. Must create a new array literal.
		// If the existing array is uninitialized (this can only happen
		// with static arrays), create it.
		if (v->value && v->value->op == TOKarrayliteral)
		    existing = (ArrayLiteralExp *)v->value;
		else // this can only happen with static arrays
		    existing = createBlockDuplicatedArrayLiteral(v->type, v->type->defaultInit(), dim);
		// value[] = value[0..lower] ~ ae ~ value[upper..$]
		existing->elements = spliceElements(existing->elements,
			createBlockDuplicatedArrayLiteral(v->type, e2, upperbound-lowerbound)->elements,
			lowerbound);
		v->value = existing;
	    }				
	    return e2;
	}
	else
	{
	    error("Slice operation %s cannot be evaluated at compile time", toChars());
	    return e;
	}
    }
    else
    {
	error("%s cannot be evaluated at compile time", toChars());
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
    Expression *e;
    if (op == TOKplusplus)
	e = interpretAssignCommon(istate, &Add, 1);
    else
	e = interpretAssignCommon(istate, &Min, 1);
#if LOG
    if (e == EXP_CANT_INTERPRET)
	printf("PostExp::interpret() CANT\n");
#endif
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

    Expression * pthis = NULL; 
    FuncDeclaration *fd = NULL;
    Expression *ecall = e1;
    if (ecall->op == TOKindex)
        ecall = e1->interpret(istate);
    if (ecall->op == TOKdotvar && !((DotVarExp*)ecall)->var->isFuncDeclaration())
        ecall = e1->interpret(istate);
   
    if (ecall->op == TOKdotvar)
    {   // Calling a member function    
        pthis = ((DotVarExp*)e1)->e1;
	fd = ((DotVarExp*)e1)->var->isFuncDeclaration();
    }
    else if (ecall->op == TOKvar)
    {
        VarDeclaration *vd = ((VarExp *)ecall)->var->isVarDeclaration();
	if (vd && vd->value) 
	    ecall = vd->value;
	else // Calling a function
	    fd = ((VarExp *)e1)->var->isFuncDeclaration();
    }    
    if (ecall->op == TOKdelegate)
    {   // Calling a delegate
	fd = ((DelegateExp *)ecall)->func;
	pthis = ((DelegateExp *)ecall)->e1;
    }
    else if (ecall->op == TOKfunction)
    {	// Calling a delegate literal
        fd = ((FuncExp*)ecall)->fd;
    }
    else if (ecall->op == TOKstar && ((PtrExp*)ecall)->e1->op==TOKfunction)
    {	// Calling a function literal
        fd = ((FuncExp*)((PtrExp*)ecall)->e1)->fd;
    }	
    else if (ecall->op == TOKstar && ((PtrExp*)ecall)->e1->op==TOKvar)
    {	// Calling a function pointer
        VarDeclaration *vd = ((VarExp *)((PtrExp*)ecall)->e1)->var->isVarDeclaration();
	if (vd && vd->value && vd->value->op==TOKsymoff) 
	    fd = ((SymOffExp *)vd->value)->var->isFuncDeclaration();
    }
    
    TypeFunction *tf = fd ? (TypeFunction *)(fd->type) : NULL;
    if (!tf)
    {   // DAC: I'm not sure if this ever happens
	//printf("ecall=%s %d %d\n", ecall->toChars(), ecall->op, TOKcall);
	error("cannot evaluate %s at compile time", toChars());
	return EXP_CANT_INTERPRET;
    }
    if (pthis && fd)
    {   // Member function call
	if (pthis->op == TOKthis)
	    pthis = istate->localThis;
	else if (pthis->op == TOKcomma)
	    pthis = pthis->interpret(istate);
	Expression *eresult = fd->interpret(istate, arguments, pthis);
	if (eresult)
	    e = eresult;
	else if (fd->type->toBasetype()->nextOf()->ty == Tvoid && !global.errors)
	    e = EXP_VOID_INTERPRET;
	else
	    error("cannot evaluate %s at compile time", toChars());
	return e;
    }
    else if (fd)
    {    // function call
#if DMDV2
	enum BUILTIN b = fd->isBuiltin();
	if (b)
	{   Expressions args;
	    args.setDim(arguments->dim);
	    for (size_t i = 0; i < args.dim; i++)
	    {
		Expression *earg = (Expression *)arguments->data[i];
		earg = earg->interpret(istate);
		if (earg == EXP_CANT_INTERPRET)
		    return earg;
		args.data[i] = (void *)earg;
	    }
	    e = eval_builtin(b, &args);
	    if (!e)
		e = EXP_CANT_INTERPRET;
	}
	else
#endif
	// Inline .dup
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
	    else if (fd->type->toBasetype()->nextOf()->ty == Tvoid && !global.errors)
		e = EXP_VOID_INTERPRET;
	    else
		error("cannot evaluate %s at compile time", toChars());
	}
    }
    else
    {
	error("cannot evaluate %s at compile time", toChars());
        return EXP_CANT_INTERPRET;
    }
    return e; 
}

Expression *CommaExp::interpret(InterState *istate)
{
#if LOG
    printf("CommaExp::interpret() %s\n", toChars());
#endif
    // If the comma returns a temporary variable, it needs to be an lvalue
    // (this is particularly important for struct constructors)
    if (e1->op == TOKdeclaration && e2->op == TOKvar 
       && ((DeclarationExp *)e1)->declaration == ((VarExp*)e2)->var)
    {
	VarExp* ve = (VarExp *)e2;
	VarDeclaration *v = ve->var->isVarDeclaration();
	if (!v->init && !v->value)
	    v->value = v->type->defaultInitLiteral();
	if (!v->value)
	    v->value = v->init->toExpression();
	v->value = v->value->interpret(istate);	
	return e2;
    }

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
    else if (e1->op == TOKnull)
    {
	e = new IntegerExp(loc, 0, type);
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
    {
	goto Lcant;
    }
    e2 = this->e2->interpret(istate);
    if (e2 == EXP_CANT_INTERPRET)
	goto Lcant;
    return Cat(type, e1, e2);

Lcant:
#if LOG
    printf("CatExp::interpret() %s CANT\n", toChars());
#endif
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
#if LOG
    printf("CastExp::interpret() %s CANT\n", toChars());
#endif
    return EXP_CANT_INTERPRET;
}


Expression *AssertExp::interpret(InterState *istate)
{   Expression *e;
    Expression *e1;

#if LOG
    printf("AssertExp::interpret() %s\n", toChars());
#endif
    if( this->e1->op == TOKaddress)
    {   // Special case: deal with compiler-inserted assert(&this, "null this") 
	AddrExp *ade = (AddrExp *)this->e1;
	if (ade->e1->op == TOKthis && istate->localThis)
	    if (ade->e1->op == TOKdotvar
	        && ((DotVarExp *)(istate->localThis))->e1->op == TOKthis)
	        return getVarExp(loc, istate, ((DotVarExp*)(istate->localThis))->var);
	    else
	        return istate->localThis->interpret(istate);
    }
    if (this->e1->op == TOKthis)
    {
	if (istate->localThis)
	    return istate->localThis->interpret(istate);
    }
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
	goto Lcant;
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
    {	AddExp *ae = (AddExp *)e1;
	if (ae->e1->op == TOKaddress && ae->e2->op == TOKint64)
	{   AddrExp *ade = (AddrExp *)ae->e1;
	    Expression *ex = ade->e1;
	    ex = ex->interpret(istate);
	    if (ex != EXP_CANT_INTERPRET)
	    {
		if (ex->op == TOKstructliteral)
		{   StructLiteralExp *se = (StructLiteralExp *)ex;
		    unsigned offset = ae->e2->toInteger();
		    e = se->getField(type, offset);
		    if (!e)
			e = EXP_CANT_INTERPRET;
		    return e;
		}
	    }
	}
	e = Ptr(type, e1);
    }
    else if (e1->op == TOKsymoff)
    {	SymOffExp *soe = (SymOffExp *)e1;
	VarDeclaration *v = soe->var->isVarDeclaration();
	if (v)
	{   Expression *ev = getVarExp(loc, istate, v);
	    if (ev != EXP_CANT_INTERPRET && ev->op == TOKstructliteral)
	    {	StructLiteralExp *se = (StructLiteralExp *)ev;
		e = se->getField(type, soe->offset);
		if (!e)
		    e = EXP_CANT_INTERPRET;
	    }
	}
    }
#if DMDV2
#else // this is required for D1, where structs return *this instead of 'this'.    
    else if (e1->op == TOKthis)
    {
    	if(istate->localThis)   	
	    return istate->localThis->interpret(istate);
    }
#endif    
#if LOG
    if (e == EXP_CANT_INTERPRET)
	printf("PtrExp::interpret() %s = EXP_CANT_INTERPRET\n", toChars());
#endif
    return e;
}

Expression *DotVarExp::interpret(InterState *istate)
{   Expression *e = EXP_CANT_INTERPRET;

#if LOG
    printf("DotVarExp::interpret() %s\n", toChars());
#endif

    Expression *ex = e1->interpret(istate);
    if (ex != EXP_CANT_INTERPRET)
    {
	if (ex->op == TOKstructliteral)
	{   StructLiteralExp *se = (StructLiteralExp *)ex;
	    VarDeclaration *v = var->isVarDeclaration();
	    if (v)
	    {	e = se->getField(type, v->offset);
		if (!e)
		{
		    error("couldn't find field %s in %s", v->toChars(), type->toChars());
		    e = EXP_CANT_INTERPRET;
		}
		return e;
	    }
	}
	else
	    error("%s.%s is not yet implemented at compile time", ex->toChars(), var->toChars());
    }

#if LOG
    if (e == EXP_CANT_INTERPRET)
	printf("DotVarExp::interpret() %s = EXP_CANT_INTERPRET\n", toChars());
#endif
    return e;
}

/******************************* Special Functions ***************************/

#if DMDV1

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
#if LOG
    printf("interpret_aaKeys()\n");
#endif
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
    Type *elemType = ((TypeAArray *)aae->type)->index;
    e->type = new TypeSArray(elemType, new IntegerExp(arguments ? arguments->dim : 0));
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
    Type *elemType = ((TypeAArray *)aae->type)->next;
    e->type = new TypeSArray(elemType, new IntegerExp(arguments ? arguments->dim : 0));
    //printf("result is %s\n", e->toChars());
    return e;
}

#endif

#if DMDV2

Expression *interpret_length(InterState *istate, Expression *earg)
{
    //printf("interpret_length()\n");
    earg = earg->interpret(istate);
    if (earg == EXP_CANT_INTERPRET)
	return NULL;
    if (earg->op != TOKassocarrayliteral)
	return NULL;
    AssocArrayLiteralExp *aae = (AssocArrayLiteralExp *)earg;
    Expression *e = new IntegerExp(aae->loc, aae->keys->dim, Type::tsize_t);
    return e;
}

Expression *interpret_keys(InterState *istate, Expression *earg, FuncDeclaration *fd)
{
#if LOG
    printf("interpret_keys()\n");
#endif
    earg = earg->interpret(istate);
    if (earg == EXP_CANT_INTERPRET)
	return NULL;
    if (earg->op != TOKassocarrayliteral)
	return NULL;
    AssocArrayLiteralExp *aae = (AssocArrayLiteralExp *)earg;
    Expression *e = new ArrayLiteralExp(aae->loc, aae->keys);
    assert(fd->type->ty == Tfunction);
    assert(fd->type->nextOf()->ty == Tarray);
    Type *elemType = ((TypeFunction *)fd->type)->nextOf()->nextOf();
    e->type = new TypeSArray(elemType, new IntegerExp(aae->keys->dim));
    return e;
}

Expression *interpret_values(InterState *istate, Expression *earg, FuncDeclaration *fd)
{
    //printf("interpret_values()\n");
    earg = earg->interpret(istate);
    if (earg == EXP_CANT_INTERPRET)
	return NULL;
    if (earg->op != TOKassocarrayliteral)
	return NULL;
    AssocArrayLiteralExp *aae = (AssocArrayLiteralExp *)earg;
    Expression *e = new ArrayLiteralExp(aae->loc, aae->values);
    assert(fd->type->ty == Tfunction);
    assert(fd->type->nextOf()->ty == Tarray);
    Type *elemType = ((TypeFunction *)fd->type)->nextOf()->nextOf();
    e->type = new TypeSArray(elemType, new IntegerExp(aae->values->dim));
    //printf("result is %s\n", e->toChars());
    return e;
}

#endif

