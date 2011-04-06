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

#define LOG     0

struct InterState
{
    InterState *caller;         // calling function's InterState
    FuncDeclaration *fd;        // function being interpreted
    Dsymbols vars;              // variables used in this function
    Statement *start;           // if !=NULL, start execution at this statement
    Statement *gotoTarget;      // target of EXP_GOTO_INTERPRET result
    Expression *localThis;      // value of 'this', or NULL if none
    bool awaitingLvalueReturn;  // Support for ref return values:
           // Any return to this function should return an lvalue.
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

Expression * resolveReferences(Expression *e, Expression *thisval, bool *isReference = NULL);
Expression *getVarExp(Loc loc, InterState *istate, Declaration *d, bool wantLvalue);
VarDeclaration *findParentVar(Expression *e, Expression *thisval);

/*************************************
 * Attempt to interpret a function given the arguments.
 * Input:
 *      istate     state for calling function (NULL if none)
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
    {   cantInterpret = 1;
        error("cannot be interpreted at compile time,"
            " because it has no available source code");
        return NULL;
    }

    if (semanticRun < PASSsemantic3 && scope)
    {
        semantic3(scope);
        if (global.errors)      // if errors compiling this function
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
    {   cantInterpret = 1;
        error("C-style variadic functions are not yet implemented in CTFE");
        return NULL;
    }

    InterState istatex;
    istatex.caller = istate;
    istatex.fd = this;
    istatex.localThis = thisarg;

    Expressions vsave;          // place to save previous parameter values
    size_t dim = 0;
    if (needThis() && !thisarg)
    {   cantInterpret = 1;
        // error, no this. Prevent segfault.
        error("need 'this' to access member %s", toChars());
        return NULL;
    }
    if (thisarg && !istate)
    {   // Check that 'this' aleady has a value
        if (thisarg->interpret(istate) == EXP_CANT_INTERPRET)
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

            if (arg->storageClass & (STCout | STCref))
            {
                if (!istate)
                {
                    earg->error("%s cannot be passed by reference at compile time", earg->toChars());
                    return NULL;
                }
            }
            else if (arg->storageClass & STClazy)
            {
            }
            else
            {   /* Value parameters
                 */
                Type *ta = arg->type->toBasetype();
                if (ta->ty == Tsarray && earg->op == TOKaddress)
                {
                    /* Static arrays are passed by a simple pointer.
                     * Skip past this to get at the actual arg.
                     */
                    earg = ((AddrExp *)earg)->e1;
                }
                earg = earg->interpret(istate); // ? istate : &istatex);
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
            vsave.data[i] = v->getValue();
#if LOG
            printf("arg[%d] = %s\n", i, earg->toChars());
#endif
            if (arg->storageClass & (STCout | STCref) && earg->op==TOKvar)
            {
                VarExp *ve = (VarExp *)earg;
                VarDeclaration *v2 = ve->var->isVarDeclaration();
                if (!v2)
                {   cantInterpret = 1;
                        return NULL;
                }
                v->restoreValue(earg);
                /* Don't restore the value of v2 upon function return
                 */
                assert(istate);
                for (size_t i = 0; i < istate->vars.dim; i++)
                {   VarDeclaration *vx = (VarDeclaration *)istate->vars.data[i];
                    if (vx == v2)
                    {   istate->vars.data[i] = NULL;
                        break;
                    }
                }
            }
            else
            {   // Value parameters and non-trivial references
                v->restoreValue(earg);
            }
#if LOG
            printf("interpreted arg[%d] = %s\n", i, earg->toChars());
#endif
        }
    }
    // Don't restore the value of 'this' upon function return
    if (needThis() && istate)
    {
        VarDeclaration *thisvar = findParentVar(thisarg, istate->localThis);
        if (!thisvar) // it's a reference. Find which variable it refers to.
            thisvar = findParentVar(thisarg->interpret(istate), istate->localThis);
        for (size_t i = 0; i < istate->vars.dim; i++)
        {   VarDeclaration *v = (VarDeclaration *)istate->vars.data[i];
            if (v == thisvar)
            {   istate->vars.data[i] = NULL;
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
                valueSaves.data[i] = v->getValue();
                v->setValueNull();
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
            istatex.start = istatex.gotoTarget; // set starting statement
            istatex.gotoTarget = NULL;
        }
        else
            break;
    }

    // Delete the values of all local variables.
    // Only delete those which are owned by this function. (Eg, if it is a
    // nested function, must retain variables from the enclosing function).
    for (size_t i = 0; i < istatex.vars.dim; i++)
    {   VarDeclaration *v = (VarDeclaration *)istatex.vars.data[i];
        if (v && v->parent == this)
        {   v->setValueNull();
        }
    }

    /* Restore the parameter values
     */
    for (size_t i = 0; i < dim; i++)
    {
        VarDeclaration *v = (VarDeclaration *)parameters->data[i];
        v->restoreValue((Expression *)vsave.data[i]);
    }

    if (istate && !isNested())
    {
        /* Restore the variable values
         */
        //printf("restoring local variables...\n");
        for (size_t i = 0; i < istate->vars.dim; i++)
        {   VarDeclaration *v = (VarDeclaration *)istate->vars.data[i];
            if (v)
            {   v->restoreValue((Expression *)valueSaves.data[i]);
                //printf("\trestoring [%d] %s = %s\n", i, v->toChars(), v->getValue() ? v->getValue()->toChars() : "");
            }
        }
    }
    return e;
}

/******************************** Statement ***************************/

#define START()                         \
    if (istate->start)                  \
    {   if (istate->start != this)      \
            return NULL;                \
        istate->start = NULL;           \
    }

/***********************************
 * Interpret the statement.
 * Returns:
 *      NULL    continue to next statement
 *      EXP_CANT_INTERPRET      cannot interpret statement at compile time
 *      !NULL   expression from return statement
 */

Expression *Statement::interpret(InterState *istate, bool wantLvalue)
{
#if LOG
    printf("Statement::interpret()\n");
#endif
    START()
    error("Statement %s cannot be interpreted at compile time", this->toChars());
    return EXP_CANT_INTERPRET;
}

Expression *ExpStatement::interpret(InterState *istate, bool wantLvalue)
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

Expression *CompoundStatement::interpret(InterState *istate, bool wantLvalue)
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

Expression *UnrolledLoopStatement::interpret(InterState *istate, bool wantLvalue)
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
            {   e = NULL;
                continue;
            }
            if (e == EXP_BREAK_INTERPRET)
            {   e = NULL;
                break;
            }
            if (e)
                break;
        }
    }
    return e;
}

Expression *IfStatement::interpret(InterState *istate, bool wantLvalue)
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

Expression *ScopeStatement::interpret(InterState *istate, bool wantLvalue)
{
#if LOG
    printf("ScopeStatement::interpret()\n");
#endif
    if (istate->start == this)
        istate->start = NULL;
    return statement ? statement->interpret(istate) : NULL;
}

#if 0
void evaluateSliceBounds(SliceExp *sexp, Expression **upper, Expression **lower, InterState *istate)
{
    Expression *e1 = sexp->interpret(istate);
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
        lengthVar->createStackValue(e);

    /* Evaluate lower and upper bounds of slice
     */
    *lower = this->lwr->interpret(istate);
    if (*lower == EXP_CANT_INTERPRET)
        goto Lcant;
    upr = this->upr->interpret(istate);
    if (upr == EXP_CANT_INTERPRET)
        goto Lcant;
    if (lengthVar)
        lengthVar->setValueNull(); // $ is defined only inside [L..U]
    e = Slice(type, e1, lwr, upr);
    if (e == EXP_CANT_INTERPRET)
        error("%s cannot be interpreted at compile time", toChars());
    return e;

Lcant:
    if (lengthVar)
        lengthVar->setValueNull();
    return EXP_CANT_INTERPRET;
}
#endif

// Helper for ReturnStatement::interpret() for returning references.
// Given an original expression, which is known to be a reference to a reference,
// turn it into a reference.
Expression * replaceReturnReference(Expression *original, InterState *istate)
{
    Expression *e = original;
    if (e->op == TOKcall)
    {   // If it's a function call, interpret it now.
        // It also needs to return an lvalue.
        istate->awaitingLvalueReturn = true;
        e  = e->interpret(istate);
        if (e == EXP_CANT_INTERPRET)
            return e;
    }
    // If it is a reference to a reference, convert it to a reference
    if (e->op == TOKvar)
    {
        VarExp *ve = (VarExp *)e;
        VarDeclaration *v = ve->var->isVarDeclaration();
        assert (v && v->getValue());
        return v->getValue();
    }

    if (e->op == TOKthis)
    {
        return istate->localThis;
    }

    Expression *r = e->copy();
    e = r;
    Expression *next;
    for (;;)
    {
        if (e->op == TOKindex)
            next = ((IndexExp*)e)->e1;
        else if (e->op == TOKdotvar)
            next = ((DotVarExp *)e)->e1;
        else if (e->op == TOKdotti)
            next = ((DotTemplateInstanceExp *)e)->e1;
        else if (e->op == TOKslice)
            next = ((SliceExp*)e)->e1;
        else
            return EXP_CANT_INTERPRET;

        Expression *old = next;

        if (next->op == TOKcall)
        {
            bool oldWaiting = istate->awaitingLvalueReturn;
            istate->awaitingLvalueReturn = true;
            next = next->interpret(istate);
            istate->awaitingLvalueReturn = oldWaiting;
            if (next == EXP_CANT_INTERPRET)
                return next;
        }
        if (next->op == TOKvar)
        {
            VarDeclaration * v = ((VarExp*)next)->var->isVarDeclaration();
            if (v)
                next = v->getValue();
        }
        else if (next->op == TOKthis)
            next = istate->localThis;

        if (old == next)
        {   // Haven't found the reference yet. Need to keep copying.
            next = next->copy();
            old = next;
        }
        if (e->op == TOKindex)
        {   // The index needs to be evaluated now (it isn't part of the ref)
            ((IndexExp*)e)->e1 = next;
            ((IndexExp*)e)->e2 = ((IndexExp*)e)->e2->interpret(istate);
            if (((IndexExp*)e)->e2 == EXP_CANT_INTERPRET)
                return EXP_CANT_INTERPRET;
        }
        else if (e->op == TOKdotvar)
            ((DotVarExp *)e)->e1 = next;
        else if (e->op == TOKdotti)
            ((DotTemplateInstanceExp *)e)->e1 = next;
        else if (e->op == TOKslice)
        {   /*  Interpret the slice bounds immediately (they are
             *  not part of the reference).
             */
            ((SliceExp*)e)->e1 = next;
            Expression *x = ((SliceExp*)e)->upr;
            if (x)
                x = x->interpret(istate);
            if (x == EXP_CANT_INTERPRET)
                return EXP_CANT_INTERPRET;
            ((SliceExp*)e)->upr = x;
            x = ((SliceExp*)e)->lwr;
            if (x)
                x = x->interpret(istate);
            if (x == EXP_CANT_INTERPRET)
                return EXP_CANT_INTERPRET;
            ((SliceExp*)e)->lwr = x;
        }
        if (old != next)
            break;
        e = next;
    }

     return r;
}

Expression *ReturnStatement::interpret(InterState *istate, bool wantLvalue)
{
#if LOG
    printf("ReturnStatement::interpret(%s)\n", exp ? exp->toChars() : "");
#endif
    START()
    if (!exp)
        return EXP_VOID_INTERPRET;
    assert(istate && istate->fd && istate->fd->type);
#if DMDV2
    /* If the function returns a ref AND it's been called from an assignment,
     * we need to return an lvalue. Otherwise, just do an (rvalue) interpret.
     */
    if (istate->fd->type && istate->fd->type->ty==Tfunction)
    {
        TypeFunction *tf = (TypeFunction *)istate->fd->type;
        if (tf->isref && istate->caller && istate->caller->awaitingLvalueReturn)
        {   // We need to return an lvalue. Can't do a normal interpret.
            Expression *e = replaceReturnReference(exp, istate);
            if (e == EXP_CANT_INTERPRET)
                error("ref return %s is not yet supported in CTFE", exp->toChars());
            return e;
        }
        if (tf->next && (tf->next->ty == Tdelegate) && istate->fd->closureVars.dim > 0)
        {
            // To support this, we need to copy all the closure vars
            // into the delegate literal.
            error("closures are not yet supported in CTFE");
            return EXP_CANT_INTERPRET;
        }
    }
#endif

    Expression *e = exp->interpret(istate);
    if (e == EXP_CANT_INTERPRET)
        return e;
    // Convert lvalues into rvalues (See Bugzilla 4825 for rationale)
    if (e->op == TOKvar)
        e = e->interpret(istate);
    return e;
}

Expression *BreakStatement::interpret(InterState *istate, bool wantLvalue)
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

Expression *ContinueStatement::interpret(InterState *istate, bool wantLvalue)
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

Expression *WhileStatement::interpret(InterState *istate, bool wantLvalue)
{
#if LOG
    printf("WhileStatement::interpret()\n");
#endif
    assert(0);                  // rewritten to ForStatement
    return NULL;
}

Expression *DoStatement::interpret(InterState *istate, bool wantLvalue)
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

Expression *ForStatement::interpret(InterState *istate, bool wantLvalue)
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

Expression *ForeachStatement::interpret(InterState *istate, bool wantLvalue)
{
#if 1
    assert(0);                  // rewritten to ForStatement
    return NULL;
#else
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
#endif
}

#if DMDV2
Expression *ForeachRangeStatement::interpret(InterState *istate, bool wantLvalue)
{
#if 1
    assert(0);                  // rewritten to ForStatement
    return NULL;
#else
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
            {   e = NULL;
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
            {   e = Add(key->value->type, key->value, new IntegerExp(loc, 1, key->value->type));
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
            {   e = NULL;
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
#endif
}
#endif

Expression *SwitchStatement::interpret(InterState *istate, bool wantLvalue)
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
            {   s = cs;
                break;
            }
        }
    }
    if (!s)
    {   if (hasNoDefault)
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

Expression *CaseStatement::interpret(InterState *istate, bool wantLvalue)
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

Expression *DefaultStatement::interpret(InterState *istate, bool wantLvalue)
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

Expression *GotoStatement::interpret(InterState *istate, bool wantLvalue)
{
#if LOG
    printf("GotoStatement::interpret()\n");
#endif
    START()
    assert(label && label->statement);
    istate->gotoTarget = label->statement;
    return EXP_GOTO_INTERPRET;
}

Expression *GotoCaseStatement::interpret(InterState *istate, bool wantLvalue)
{
#if LOG
    printf("GotoCaseStatement::interpret()\n");
#endif
    START()
    assert(cs);
    istate->gotoTarget = cs;
    return EXP_GOTO_INTERPRET;
}

Expression *GotoDefaultStatement::interpret(InterState *istate, bool wantLvalue)
{
#if LOG
    printf("GotoDefaultStatement::interpret()\n");
#endif
    START()
    assert(sw && sw->sdefault);
    istate->gotoTarget = sw->sdefault;
    return EXP_GOTO_INTERPRET;
}

Expression *LabelStatement::interpret(InterState *istate, bool wantLvalue)
{
#if LOG
    printf("LabelStatement::interpret()\n");
#endif
    if (istate->start == this)
        istate->start = NULL;
    return statement ? statement->interpret(istate) : NULL;
}


Expression *TryCatchStatement::interpret(InterState *istate, bool wantLvalue)
{
#if LOG
    printf("TryCatchStatement::interpret()\n");
#endif
    START()
    error("try-catch statements are not yet supported in CTFE");
    return EXP_CANT_INTERPRET;
}


Expression *TryFinallyStatement::interpret(InterState *istate, bool wantLvalue)
{
#if LOG
    printf("TryFinallyStatement::interpret()\n");
#endif
    START()
    error("try-finally statements are not yet supported in CTFE");
    return EXP_CANT_INTERPRET;
}

Expression *ThrowStatement::interpret(InterState *istate, bool wantLvalue)
{
#if LOG
    printf("ThrowStatement::interpret()\n");
#endif
    START()
    error("throw statements are not yet supported in CTFE");
    return EXP_CANT_INTERPRET;
}

Expression *OnScopeStatement::interpret(InterState *istate, bool wantLvalue)
{
#if LOG
    printf("OnScopeStatement::interpret()\n");
#endif
    START()
    error("scope guard statements are not yet supported in CTFE");
    return EXP_CANT_INTERPRET;
}

Expression *WithStatement::interpret(InterState *istate, bool wantLvalue)
{
#if LOG
    printf("WithStatement::interpret()\n");
#endif
    START()
    error("with statements are not yet supported in CTFE");
    return EXP_CANT_INTERPRET;
}

Expression *AsmStatement::interpret(InterState *istate, bool wantLvalue)
{
#if LOG
    printf("AsmStatement::interpret()\n");
#endif
    START()
    error("asm statements cannot be interpreted at compile time");
    return EXP_CANT_INTERPRET;
}

/******************************** Expression ***************************/

Expression *Expression::interpret(InterState *istate, bool wantLvalue)
{
#if LOG
    printf("Expression::interpret() %s\n", toChars());
    printf("type = %s\n", type->toChars());
    dump(0);
#endif
    error("Cannot interpret %s at compile time", toChars());
    return EXP_CANT_INTERPRET;
}

Expression *ThisExp::interpret(InterState *istate, bool wantLvalue)
{
    if (istate && istate->localThis)
        return istate->localThis->interpret(istate);
    error("value of 'this' is not known at compile time");
    return EXP_CANT_INTERPRET;
}

Expression *NullExp::interpret(InterState *istate, bool wantLvalue)
{
    return this;
}

Expression *IntegerExp::interpret(InterState *istate, bool wantLvalue)
{
#if LOG
    printf("IntegerExp::interpret() %s\n", toChars());
#endif
    return this;
}

Expression *RealExp::interpret(InterState *istate, bool wantLvalue)
{
#if LOG
    printf("RealExp::interpret() %s\n", toChars());
#endif
    return this;
}

Expression *ComplexExp::interpret(InterState *istate, bool wantLvalue)
{
    return this;
}

Expression *StringExp::interpret(InterState *istate, bool wantLvalue)
{
#if LOG
    printf("StringExp::interpret() %s\n", toChars());
#endif
    return this;
}

Expression *FuncExp::interpret(InterState *istate, bool wantLvalue)
{
#if LOG
    printf("FuncExp::interpret() %s\n", toChars());
#endif
    return this;
}

Expression *SymOffExp::interpret(InterState *istate, bool wantLvalue)
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

Expression *DelegateExp::interpret(InterState *istate, bool wantLvalue)
{
#if LOG
    printf("DelegateExp::interpret() %s\n", toChars());
#endif
    return this;
}


// -------------------------------------------------------------
//         Remove out, ref, and this
// -------------------------------------------------------------
// The variable used in a dotvar, index, or slice expression,
// after 'out', 'ref', and 'this' have been removed.
// *isReference will be set to true if a reference was removed.
Expression * resolveReferences(Expression *e, Expression *thisval, bool *isReference /*=NULL */)
{
    if (isReference)
        *isReference = false;
    for(;;)
    {
        if (e->op == TOKthis)
        {
            assert(thisval);
            assert(e != thisval);
            e = thisval;
            continue;
        }
        if (e->op == TOKvar) {
            // Chase down rebinding of out and ref.
            VarExp *ve = (VarExp *)e;
            VarDeclaration *v = ve->var->isVarDeclaration();
            if (v && v->getValue() && v->getValue()->op == TOKvar) // it's probably a reference
            {
                // Make sure it's a real reference.
                // It's not a reference if v is a struct initialized to
                // 0 using an __initZ SymbolDeclaration from
                // TypeStruct::defaultInit()
                VarExp *ve2 = (VarExp *)v->getValue();
                if (!ve2->var->isSymbolDeclaration())
                {
                    if (isReference)
                        *isReference = true;
                    e = v->getValue();
                    continue;
                }
            }
            else if (v && v->getValue() && (v->getValue()->op == TOKslice))
            {
                SliceExp *se = (SliceExp *)v->getValue();
                if (se->e1->op == TOKarrayliteral || se->e1->op == TOKassocarrayliteral || se->e1->op == TOKstring)
                    break;
                e = v->getValue();
                continue;
            }
            else if (v && v->getValue() && (v->getValue()->op==TOKindex || v->getValue()->op == TOKdotvar
                  || v->getValue()->op == TOKthis ))
            {
                e = v->getValue();
                continue;
            }
        }
        break;
    }
    return e;
}

Expression *getVarExp(Loc loc, InterState *istate, Declaration *d, bool wantLvalue)
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

        if ((v->isConst() || v->isImmutable() || v->storage_class & STCmanifest) && v->init && !v->getValue())
#else
        if (v->isConst() && v->init)
#endif
        {   e = v->init->toExpression();
            if (e && !e->type)
                e->type = v->type;
        }
        else if ((v->isCTFE() || (!v->isDataseg() && istate)) && !v->getValue())
        {
            if (v->init && v->type->size() != 0)
            {
                if (v->init->isVoidInitializer())
                {
                        error(loc, "variable %s is used before initialization", v->toChars());
                        return EXP_CANT_INTERPRET;
                }
                e = v->init->toExpression();
                e = e->interpret(istate);
            }
            else
                e = v->type->defaultInitLiteral(loc);
        }
        else if (!v->isDataseg() && !istate) {
            error(loc, "variable %s cannot be read at compile time", v->toChars());
            return EXP_CANT_INTERPRET;
        }
        else
        {   e = v->getValue();
            if (!v->isCTFE() && v->isDataseg())
            {   error(loc, "static variable %s cannot be read at compile time", v->toChars());
                e = EXP_CANT_INTERPRET;
            }
            else if (!e)
                error(loc, "variable %s is used before initialization", v->toChars());
            else if (e == EXP_CANT_INTERPRET)
                return e;
            else if (wantLvalue && (e->op == TOKstring || e->op == TOKslice ||
                    e->op == TOKstructliteral || e->op == TOKarrayliteral ||
                    e->op == TOKassocarrayliteral))
                return e; // it's already an Lvalue
            else
                e = e->interpret(istate, wantLvalue);
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

Expression *VarExp::interpret(InterState *istate, bool wantLvalue)
{
#if LOG
    printf("VarExp::interpret() %s\n", toChars());
#endif
    return getVarExp(loc, istate, var, wantLvalue);
}

Expression *DeclarationExp::interpret(InterState *istate, bool wantLvalue)
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
            else
            {
                error("Declaration %s is not yet implemented in CTFE", toChars());
                e = EXP_CANT_INTERPRET;
            }
        }
        else if (s == v && !v->init && v->type->size()==0)
        {   // Zero-length arrays don't need an initializer
            e = v->type->defaultInitLiteral(loc);
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
        else if (s->isTupleDeclaration() && !v->init)
            e = NULL;
        else
        {
            error("Declaration %s is not yet implemented in CTFE", toChars());
            e = EXP_CANT_INTERPRET;
        }
    }
    else if (declaration->isAttribDeclaration() ||
             declaration->isTemplateMixin() ||
             declaration->isTupleDeclaration())
    {   // These can be made to work, too lazy now
        error("Declaration %s is not yet implemented in CTFE", toChars());
        e = EXP_CANT_INTERPRET;
    }
    else
    {   // Others should not contain executable code, so are trivial to evaluate
        e = NULL;
    }
#if LOG
    printf("-DeclarationExp::interpret(%s): %p\n", toChars(), e);
#endif
    return e;
}

Expression *TupleExp::interpret(InterState *istate, bool wantLvalue)
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
            {   expsx = new Expressions();
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
    {   TupleExp *te = new TupleExp(loc, expsx);
        expandTuples(te->exps);
        te->type = new TypeTuple(te->exps);
        return te;
    }
    return this;
}

Expression *ArrayLiteralExp::interpret(InterState *istate, bool wantLvalue)
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

Expression *AssocArrayLiteralExp::interpret(InterState *istate, bool wantLvalue)
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
            if (ex->isBool(TRUE))       // if a match
            {
                // Remove ekey
                if (keysx == keys)
                    keysx = (Expressions *)keys->copy();
                if (valuesx == values)
                    valuesx = (Expressions *)values->copy();
                keysx->remove(i - 1);
                valuesx->remove(i - 1);
                i -= 1;         // redo the i'th iteration
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

Expression *StructLiteralExp::interpret(InterState *istate, bool wantLvalue)
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

/******************************
 * Helper for NewExp
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
 * Helper for NewExp
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
            case 1:     s[elemi] = value; break;
            case 2:     ((unsigned short *)s)[elemi] = value; break;
            case 4:     ((unsigned *)s)[elemi] = value; break;
            default:    assert(0);
        }
    }
    StringExp *se = new StringExp(0, s, dim);
    se->type = type;
    return se;
}

Expression *NewExp::interpret(InterState *istate, bool wantLvalue)
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
            ((TypeArray *)newtype)->next->defaultInitLiteral(),
            lenExpr->toInteger());
    }
    error("Cannot interpret %s at compile time", toChars());
    return EXP_CANT_INTERPRET;
}

Expression *UnaExp::interpretCommon(InterState *istate,  bool wantLvalue, Expression *(*fp)(Type *, Expression *))
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
Expression *op##Exp::interpret(InterState *istate, bool wantLvalue)      \
{                                                       \
    return interpretCommon(istate, wantLvalue, &op);    \
}

UNA_INTERPRET(Neg)
UNA_INTERPRET(Com)
UNA_INTERPRET(Not)
UNA_INTERPRET(Bool)


typedef Expression *(*fp_t)(Type *, Expression *, Expression *);

Expression *BinExp::interpretCommon(InterState *istate, bool wantLvalue, fp_t fp)
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
Expression *op##Exp::interpret(InterState *istate, bool wantLvalue) \
{                                                                   \
    return interpretCommon(istate, wantLvalue, &op);                \
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

Expression *BinExp::interpretCommon2(InterState *istate, bool wantLvalue, fp2_t fp)
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
Expression *op##Exp::interpret(InterState *istate, bool wantLvalue)  \
{                                                                    \
    return interpretCommon2(istate, wantLvalue, &op);                \
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

// Create a new struct literal, which is the same as se except that se.field[offset] = elem
Expression * modifyStructField(Type *type, StructLiteralExp *se, size_t offset, Expression *newval)
{
    int fieldi = se->getFieldIndex(newval->type, offset);
    if (fieldi == -1)
        return EXP_CANT_INTERPRET;
    /* Create new struct literal reflecting updated fieldi
    */
    Expressions *expsx = changeOneElement(se->elements, fieldi, newval);
    Expression * ee = new StructLiteralExp(se->loc, se->sd, expsx);
    ee->type = se->type;
    return ee;
}

/********************************
 * Given an array literal arr (either arrayliteral, stringliteral, or assocArrayLiteral),
 * set arr[index] = newval and return the new array.
 *
 */
Expression *assignAssocArrayElement(Loc loc, AssocArrayLiteralExp *aae, Expression *index, Expression *newval)
{
    /* Create new associative array literal reflecting updated key/value
     */
    Expressions *keysx = aae->keys;
    Expressions *valuesx = aae->values;
    int updated = 0;
    for (size_t j = valuesx->dim; j; )
    {   j--;
        Expression *ekey = (Expression *)aae->keys->data[j];
        Expression *ex = Equal(TOKequal, Type::tbool, ekey, index);
        if (ex == EXP_CANT_INTERPRET)
            return EXP_CANT_INTERPRET;
        if (ex->isBool(TRUE))
        {   valuesx->data[j] = (void *)newval;
            updated = 1;
        }
    }
    if (!updated)
    {   // Append index/newval to keysx[]/valuesx[]
        valuesx->push(newval);
        keysx->push(index);
    }
    return newval;
}

// Return true if e is derived from UnaryExp.
// Consider moving this function into Expression.
UnaExp *isUnaExp(Expression *e)
{
   switch (e->op)
   {
        case TOKdotvar:
        case TOKindex:
        case TOKslice:
        case TOKcall:
        case TOKdot:
        case TOKdotti:
        case TOKdottype:
        case TOKcast:
            return (UnaExp *)e;
        default:
            break;
    }
        return NULL;
}

// To resolve an assignment expression, we need to walk to the end of the
// expression to find the ultimate variable which is modified. But, in building
// up the expression, we need to walk the tree *backwards*. There isn't a
// standard way to do this, but if we know we're at depth d, iterating from
// the root up to depth d-1 will give us the parent node. Inefficient, but
// depth is almost always < 3.
struct ExpressionReverseIterator
{
    Expression *totalExpr; // The root expression
    Expression *thisval;  // The value to be used for TOKthis
    int totalDepth;

    ExpressionReverseIterator(Expression *root, Expression *thisexpr)
    {
       totalExpr = root;
       thisval = thisexpr;
       totalDepth = findExpressionDepth(totalExpr);
    }

    int findExpressionDepth(Expression *e);
    Expression *getExpressionAtDepth(int depth);
};

// Determines the depth in unary expressions.
int ExpressionReverseIterator::findExpressionDepth(Expression *e)
{
   int depth = 0;
   for (;;)
   {
        e = resolveReferences(e, thisval);
        if (e->op == TOKvar)
            return depth;
        if (e->op == TOKcall)
            return depth;
        ++depth;
        UnaExp *u = isUnaExp(e);
        if (u)
            e = u->e1;
        else
            return depth;
    }
}

Expression *ExpressionReverseIterator::getExpressionAtDepth(int depth)
{
   Expression *e = totalExpr;
   int d = 0;
   for (;;)
   {
        e = resolveReferences(e, thisval);
        if (d == depth) return e;
        ++d;
        assert(e->op != TOKvar);
        UnaExp *u = isUnaExp(e);
        if (u)
            e = u->e1;
        else
            return e;
    }
}

// Returns the variable which is eventually modified, or NULL if an rvalue.
// thisval is the current value of 'this'.
VarDeclaration * findParentVar(Expression *e, Expression *thisval)
{
    for (;;)
    {
        e = resolveReferences(e, thisval);
        if (e->op == TOKvar)
            break;
        if (e->op == TOKindex)
            e = ((IndexExp*)e)->e1;
        else if (e->op == TOKdotvar)
            e = ((DotVarExp *)e)->e1;
        else if (e->op == TOKdotti)
            e = ((DotTemplateInstanceExp *)e)->e1;
        else if (e->op == TOKslice)
            e = ((SliceExp*)e)->e1;
        else
            return NULL;
    }
    VarDeclaration *v = ((VarExp *)e)->var->isVarDeclaration();
    assert(v);
    return v;
}

// Returns the value to be assigned to the last dotVar, given the existing value at this depth.
Expression *assignDotVar(ExpressionReverseIterator rvs, int depth, Expression *existing, Expression *newval)
{
    if (depth == 0)
        return newval;
    assert(existing && existing != EXP_CANT_INTERPRET);
    Expression *e = rvs.getExpressionAtDepth(depth - 1);
    if (e->op == TOKdotvar)
    {
        VarDeclaration *member = ((DotVarExp *)e)->var->isVarDeclaration();
        assert(member);
        assert(existing);
        assert(existing != EXP_CANT_INTERPRET);
        assert(existing->op == TOKstructliteral);
        if (existing->op != TOKstructliteral)
            return EXP_CANT_INTERPRET;

        StructLiteralExp *se = (StructLiteralExp *)existing;
        int fieldi = se->getFieldIndex(member->type, member->offset);
        if (fieldi == -1)
            return EXP_CANT_INTERPRET;
        assert(fieldi>=0 && fieldi < se->elements->dim);
        Expression *ex =  (Expression *)(se->elements->data[fieldi]);

        newval = assignDotVar(rvs, depth - 1, ex, newval);
        Expressions *expsx = changeOneElement(se->elements, fieldi, newval);
        Expression * ee = new StructLiteralExp(se->loc, se->sd, expsx);
        ee->type = se->type;
        return ee;
    }
    assert(0);
    return NULL;
}

// Given expr, which evaluates to an array/AA/string literal,
// return true if it needs to be copied
bool needToCopyLiteral(Expression *expr)
{
    for (;;)
    {
       switch (expr->op)
       {
            case TOKarrayliteral:
            case TOKassocarrayliteral:
            case TOKstring:
            case TOKstructliteral:
                return true;
            case TOKthis:
            case TOKvar:
                return false;
            case TOKassign:
                return false;
            case TOKindex:
            case TOKdotvar:
            case TOKslice:
            case TOKcast:
                expr = ((UnaExp *)expr)->e1;
                continue;
            case TOKcat:
            case TOKcatass:
                return false;
            case TOKcall:
                // TODO: Return statement should
                // guarantee we never return a naked literal, but
                // currently it doesn't.
                return true;

            // There are probably other cases which don't need
            // a copy. But for now, we conservatively copy all
            // other cases.
            default:
                return true;
        }
    }
}


// Make a copy of the ArrayLiteral, AALiteral, String, or StructLiteral.
// This value will be used for in-place modification.
Expression *copyLiteral(Expression *e)
{
    if (e->op == TOKstring) // syntaxCopy doesn't make a copy for StringExp!
    {
        StringExp *se = (StringExp *)e;
        unsigned char *s;
        s = (unsigned char *)mem.calloc(se->len + 1, se->sz);
        memcpy(s, se->string, se->len * se->sz);
        StringExp *se2 = new StringExp(se->loc, s, se->len);
        se2->committed = se->committed;
        se2->postfix = se->postfix;
        se2->type = se->type;
        return se2;
    }
    else if (e->op == TOKarrayliteral)
    {
        ArrayLiteralExp *ae = (ArrayLiteralExp *)e;
        Expressions *oldelems = ae->elements;
        Expressions *newelems = new Expressions();
        newelems->setDim(oldelems->dim);
        for (size_t i = 0; i < oldelems->dim; i++)
            newelems->data[i] = copyLiteral((Expression *)(oldelems->data[i]));
        ArrayLiteralExp *r = new ArrayLiteralExp(ae->loc, newelems);
        r->type = e->type;
        return r;
    }
    /* syntaxCopy doesn't work for struct literals, because of a nasty special
     * case: block assignment is permitted inside struct literals, eg,
     * an int[4] array can be initialized with a single int.
     */
    else if (e->op == TOKstructliteral)
    {
        StructLiteralExp *se = (StructLiteralExp *)e;
        Expressions *oldelems = se->elements;
        Expressions * newelems = new Expressions();
        newelems->setDim(oldelems->dim);
        for (size_t i = 0; i < newelems->dim; i++)
        {
            Expression *m = (Expression *)oldelems->data[i];
            // We need the struct definition to detect block assignment
            StructDeclaration *sd = se->sd;
            Dsymbol *s = (Dsymbol *)sd->fields.data[i];
            VarDeclaration *v = s->isVarDeclaration();
            assert(v);
            if ((v->type->ty != m->type->ty) && v->type->ty == Tsarray)
            {
                // Block assignment from inside struct literals
                TypeSArray *tsa = (TypeSArray *)v->type;
                uinteger_t length = tsa->dim->toInteger();

                m = createBlockDuplicatedArrayLiteral(v->type, m, length);
            } else m = copyLiteral(m);
            newelems->data[i] = m;
        }
        StructLiteralExp *r = new StructLiteralExp(e->loc, se->sd, newelems, se->stype);
        r->type = e->type;
        return r;
    }

    Expression *r = e->syntaxCopy();
    r->type = e->type;
    return r;
}

void recursiveBlockAssign(ArrayLiteralExp *ae, Expression *val)
{
    for (size_t k = 0; k < ae->elements->dim; k++)
    {
        if (((Expression *)(ae->elements->data[k]))->op == TOKarrayliteral)
            recursiveBlockAssign((ArrayLiteralExp *)(ae->elements->data[k]), val);
        else ae->elements->data[k] = val;
    }
}


Expression *BinExp::interpretAssignCommon(InterState *istate, bool wantLvalue, fp_t fp, int post)
{
#if LOG
    printf("BinExp::interpretAssignCommon() %s\n", toChars());
#endif
    Expression *e = EXP_CANT_INTERPRET;
    Expression *e1 = this->e1;
    if (!istate)
    {
        error("value of %s is not known at compile time", e1->toChars());
        return e;
    }

    if (fp)
    {
        if (e1->op == TOKcast)
        {   CastExp *ce = (CastExp *)e1;
            e1 = ce->e1;
        }
    }
    if (e1 == EXP_CANT_INTERPRET)
        return e1;

    // First, deal with  this = e; and call() = e;
    if (e1->op == TOKthis)
    {
        e1 = istate->localThis;
    }
    if (e1->op == TOKcall)
    {
        bool oldWaiting = istate->awaitingLvalueReturn;
        istate->awaitingLvalueReturn = true;
        e1 = e1->interpret(istate);
        istate->awaitingLvalueReturn = oldWaiting;
        if (e1 == EXP_CANT_INTERPRET)
            return e1;
    }

    if (!(e1->op == TOKarraylength || e1->op == TOKvar || e1->op == TOKdotvar
        || e1->op == TOKindex || e1->op == TOKslice))
        printf("CTFE internal error: unsupported assignment %s\n", toChars());
    assert(e1->op == TOKarraylength || e1->op == TOKvar || e1->op == TOKdotvar
        || e1->op == TOKindex || e1->op == TOKslice);

    bool wantRef = false;
    Expression * newval = NULL;
    if (!fp && this->e1->type->toBasetype() == this->e2->type->toBasetype()
        && (e1->type->toBasetype()->ty == Tarray || e1->type->toBasetype()->ty == Taarray)
        )
    {
        wantRef = true;
    }
    else
        newval = this->e2->interpret(istate);
    if (newval == EXP_CANT_INTERPRET)
        return newval;
    // ----------------------------------------------------
    //  Deal with read-modify-write assignments.
    //  Set 'newval' to the final assignment value
    //  Also determine the return value (except for slice
    //  assignments, which are more complicated)
    // ----------------------------------------------------

    if (fp || e1->op == TOKarraylength)
    {
        // If it isn't a simple assignment, we need the existing value
        Expression * oldval = e1->interpret(istate);
        if (oldval == EXP_CANT_INTERPRET)
            return EXP_CANT_INTERPRET;
        while (oldval->op == TOKvar)
        {
            oldval = resolveReferences(oldval, istate->localThis);
            oldval = oldval->interpret(istate);
            if (oldval == EXP_CANT_INTERPRET)
                return oldval;
        }

        if (fp)
        {
            newval = (*fp)(type, oldval, newval);
            if (newval == EXP_CANT_INTERPRET)
            {
                error("Cannot interpret %s at compile time", toChars());
                return EXP_CANT_INTERPRET;
            }
            // Determine the return value
            e = Cast(type, type, post ? oldval : newval);
            if (e == EXP_CANT_INTERPRET)
                return e;
        }
        else
            e = newval;

        if (e1->op == TOKarraylength)
        {
            size_t oldlen = oldval->toInteger();
            size_t newlen = newval->toInteger();
            if (oldlen == newlen) // no change required -- we're done!
                return e;
            // Now change the assignment from arr.length = n into arr = newval
            e1 = ((ArrayLengthExp *)e1)->e1;
            if (oldlen != 0)
            {   // Get the old array literal.
                oldval = e1->interpret(istate);
                while (oldval->op == TOKvar)
                {   oldval = resolveReferences(oldval, istate->localThis);
                    oldval = oldval->interpret(istate);
                }
            }
            Type *t = e1->type->toBasetype();
            if (t->ty == Tarray)
            {
                Type *elemType= NULL;
                elemType = ((TypeArray *)t)->next;
                assert(elemType);
                Expression *defaultElem = elemType->defaultInitLiteral();

                Expressions *elements = new Expressions();
                elements->setDim(newlen);
                size_t copylen = oldlen < newlen ? oldlen : newlen;
                ArrayLiteralExp *ae = (ArrayLiteralExp *)oldval;
                for (size_t i = 0; i < copylen; i++)
                     elements->data[i] = ae->elements->data[i];

                for (size_t i = copylen; i < newlen; i++)
                    elements->data[i] = defaultElem;
                ArrayLiteralExp *aae = new ArrayLiteralExp(0, elements);
                aae->type = t;
                newval = aae;
            }
            else
            {
                error("%s is not yet supported at compile time", toChars());
                return EXP_CANT_INTERPRET;
            }

        }
    }
    else if (!wantRef && e1->op != TOKslice)
    {   /* Look for special case of struct being initialized with 0.
        */
        if (type->toBasetype()->ty == Tstruct && newval->op == TOKint64)
        {
            newval = type->defaultInitLiteral(loc);
        }
        newval = Cast(type, type, newval);
        e = newval;
    }
    if (newval == EXP_CANT_INTERPRET)
        return newval;

    // -------------------------------------------------
    //         Make sure destination can be modified
    // -------------------------------------------------
    // Make sure we're not trying to modify a global or static variable
    // We do this by locating the ultimate parent variable which gets modified.
    VarDeclaration * ultimateVar = findParentVar(e1, istate->localThis);
    if (ultimateVar && ultimateVar->isDataseg() && !ultimateVar->isCTFE())
    {   // Can't modify global or static data
        error("%s cannot be modified at compile time", ultimateVar->toChars());
        return EXP_CANT_INTERPRET;
    }

    // This happens inside compiler-generated foreach statements.
    if (op==TOKconstruct && this->e1->op==TOKvar
        && ((VarExp*)this->e1)->var->storage_class & STCref)
    {
        //error("assignment to ref variable %s is not yet supported in CTFE", this->toChars());
        VarDeclaration *v = ((VarExp *)e1)->var->isVarDeclaration();
        v->setValue(e2);
        return e2;
    }
    bool destinationIsReference = false;
    e1 = resolveReferences(e1, istate->localThis, &destinationIsReference);

    // Unless we have a simple var assignment, we're
    // only modifying part of the variable. So we need to make sure
    // that the parent variable exists.
    if (e1->op != TOKvar && ultimateVar && !ultimateVar->getValue())
        ultimateVar->createValue(copyLiteral(ultimateVar->type->defaultInitLiteral()));    

    // ----------------------------------------------------------
    //      Deal with dotvar expressions - non-reference types
    // ----------------------------------------------------------
    // Because structs are not reference types, dotvar expressions can be
    // collapsed into a single assignment.
    bool startedWithCall = false;
    if (e1->op == TOKcall)
        startedWithCall = true;
    while (!wantRef && (e1->op == TOKdotvar || e1->op == TOKcall))
    {
        ExpressionReverseIterator rvs(e1, istate->localThis);
        Expression *lastNonDotVar = e1;
        // Strip of all of the leading dotvars.
        if (e1->op == TOKdotvar)
        {
            int numDotVars = 0;
            while(lastNonDotVar->op == TOKdotvar)
            {
                ++numDotVars;
                if (lastNonDotVar->op == TOKdotvar)
                    lastNonDotVar = ((DotVarExp *)lastNonDotVar)->e1;
                lastNonDotVar = resolveReferences(lastNonDotVar, istate->localThis);
                assert(lastNonDotVar);
            }
            // We need the value of this first nonvar, since only part of it will be
            // modified.
            Expression * existing = lastNonDotVar->interpret(istate);
            if (existing == EXP_CANT_INTERPRET)
                return existing;
            assert(newval !=EXP_CANT_INTERPRET);
            newval = assignDotVar(rvs, numDotVars, existing, newval);
            e1 = lastNonDotVar;
            if (e1->op == TOKvar)
            {
                VarExp *ve = (VarExp *)e1;
                VarDeclaration *v = ve->var->isVarDeclaration();
                v->setValue(newval);
                return e;
            }
            assert(newval !=EXP_CANT_INTERPRET);

        } // end tokdotvar
        else
        {
            Expression * existing = lastNonDotVar->interpret(istate);
            if (existing == EXP_CANT_INTERPRET)
                return existing;
            // It might be a reference. Turn it into an rvalue, by interpreting again.
            existing = existing->interpret(istate);
            if (existing == EXP_CANT_INTERPRET)
                return existing;
            assert(newval !=EXP_CANT_INTERPRET);
            newval = assignDotVar(rvs, 0, existing, newval);
            assert(newval !=EXP_CANT_INTERPRET);
        }
        if (e1->op == TOKcall)
        {
            bool oldWaiting = istate->awaitingLvalueReturn;
            istate->awaitingLvalueReturn = true;
            e1 = e1->interpret(istate);
            istate->awaitingLvalueReturn = oldWaiting;

            if (e1 == EXP_CANT_INTERPRET)
                return e1;
            assert(newval);
            assert(newval != EXP_CANT_INTERPRET);
        }
    }
    // ---------------------------------------
    //      Deal with reference assignment
    // ---------------------------------------
    // If the destination is an array literal or string literal, it is non-null here.
    ArrayLiteralExp *dest_ae = NULL;
//    AssocArrayLiteralExp *dest_aae = NULL;
    StringExp *dest_se = NULL;
    if (wantRef)
    {
        if (this->e2->op == TOKvar)
            newval = this->e2;
        else if (this->e2->op==TOKslice)
        {
            SliceExp * sexp = (SliceExp *)this->e2;

            /* Set the $ variable
             */
            Expression *dollar = ArrayLength(Type::tsize_t, sexp->e1->interpret(istate));
            if (dollar != EXP_CANT_INTERPRET && sexp->lengthVar)
            {
                sexp->lengthVar->createStackValue(dollar);
            }
            Expression *upper = NULL;
            Expression *lower = NULL;
            if (sexp->upr)
                upper = sexp->upr->interpret(istate);
            else upper = dollar;
            if (sexp->lwr)
                lower = sexp->lwr->interpret(istate);
            else
                lower = new IntegerExp(loc, 0, Type::tsize_t);
            if (sexp->lengthVar)
                sexp->lengthVar->setValueNull(); // $ is defined only in [L..U]
            if (upper == EXP_CANT_INTERPRET || lower == EXP_CANT_INTERPRET)
                return EXP_CANT_INTERPRET;
            newval = new SliceExp(sexp->loc, sexp->e1, lower, upper);
            newval->type = sexp->type;
        }
        else
            newval = this->e2->interpret(istate);
        if (newval == EXP_CANT_INTERPRET)
            return newval;
        if (e1->op == TOKvar)
        {
            VarExp *ve = (VarExp *)e1;
            VarDeclaration *v = ve->var->isVarDeclaration();
            if (!destinationIsReference)
                addVarToInterstate(istate, v);
            // It's a reference type. The old value gets lost.
            if (newval->op == TOKarrayliteral || (newval->op == TOKassocarrayliteral)
                || newval->op == TOKstring)
            {
                if (needToCopyLiteral(this->e2))
                    newval = copyLiteral(newval);
                v->setValueNull();
                v->createValue(newval);
            }
            else if (newval->op == TOKnull)
            {
                v->setValueNull();
                v->createValue(newval);
            }
            else if (newval->op == TOKvar)
            {
                VarExp *vv = (VarExp *)newval;

                VarDeclaration *v2 = vv->var->isVarDeclaration();
                assert(v2);
                assert((v2->getValue()->op == TOKarrayliteral || v2->getValue()->op == TOKstring
                    || v2->getValue()->op == TOKassocarrayliteral || v2->getValue()->op == TOKnull));
                v->setValueNull();
                v->createValue(v2->getValue());
            }
            else if (newval->op == TOKslice)
            {
                // This one is interesting because it could be a slice of itself
                SliceExp * sexp = (SliceExp *)newval;
                Expression *agg = sexp->e1;
                dinteger_t newlo = sexp->lwr->toInteger();
                dinteger_t newup = sexp->upr->toInteger();
                if (agg->op == TOKvar)
                {
                    VarExp *vv = (VarExp *)agg;
                    VarDeclaration *v2 = vv->var->isVarDeclaration();
                    assert(v2);
                    if (v2->getValue()->op == TOKarrayliteral || v2->getValue()->op == TOKstring)
                    {
                        Expression *dollar = ArrayLength(Type::tsize_t, v2->getValue());
                        if ((newup < newlo) || (newup > dollar->toInteger()))
                        {
                            error("slice [%jd..%jd] exceeds array bounds [0..%jd]",
                                newlo, newup, dollar->toInteger());
                            return EXP_CANT_INTERPRET;
                        }
                        sexp->e1 = v2->getValue();
                        v->setValueNull();
                        v->createValue(sexp);
                    }
                    else if (v2->getValue()->op == TOKslice)
                    {
                        SliceExp *sexpold = (SliceExp *)v2->getValue();
                        sexp->e1 = sexpold->e1;
                        dinteger_t hi = newup + sexpold->lwr->toInteger();
                        dinteger_t lo = newlo + sexpold->lwr->toInteger();
                        if ((newup < newlo) || (hi > sexpold->upr->toInteger()))
                        {
                            error("slice [%jd..%jd] exceeds array bounds [0..%jd]",
                                newlo, newup, sexpold->upr->toInteger()-sexpold->lwr->toInteger());
                            return EXP_CANT_INTERPRET;
                        }
                        sexp->lwr = new IntegerExp(loc, lo, Type::tsize_t);
                        sexp->upr = new IntegerExp(loc, hi, Type::tsize_t);
                        v->setValueNull();
                        v->createValue(sexp);
                    }
                    else
                    {
                        if (!v->getValue())
                            v->createValue(newval->interpret(istate));
                        else v->setValue(newval->interpret(istate));
                    }
                }
                else
                {
                    if (!v->getValue())
                        v->createValue(newval->interpret(istate));
                    else v->setValue(newval->interpret(istate));
                }
            }
            else
            {
                v->setValueNull();
                v->createStackValue(newval);
            }
            return newval;
        }
        e = newval;
    }

    /* Assignment to variable of the form:
     *  v = newval
     */
    if (e1->op == TOKvar)
    {
        VarExp *ve = (VarExp *)e1;
        VarDeclaration *v = ve->var->isVarDeclaration();
        if (!destinationIsReference)
            addVarToInterstate(istate, v);
        if (e1->type->toBasetype()->ty == Tstruct)
        {
            // This should be an in-place modification
            if (newval->op == TOKstructliteral)
            {
                v->setValueNull();
                v->createValue(copyLiteral(newval));
            }
            else v->setValue(newval);
        }
        else
        {
            if (e1->type->toBasetype()->ty == Tarray || e1->type->toBasetype()->ty == Taarray)
            { // arr op= arr
                if (!v->getValue())
                    v->createValue(newval->interpret(istate));
                else v->setValue(newval->interpret(istate));
            }
            else
            {
                if (!v->getValue()) // creating a new value
                    v->createStackValue(newval);
                else
                    v->setStackValue(newval);
            }
        }
    }
    else if (e1->op == TOKindex)
    {
        Expression *aggregate = resolveReferences(((IndexExp *)e1)->e1, istate->localThis);
        /* Assignment to array element of the form:
         *   aggregate[i] = newval
         */
        if (aggregate->op == TOKvar)
        {   IndexExp *ie = (IndexExp *)e1;
            VarExp *ve = (VarExp *)aggregate;
            VarDeclaration *v = ve->var->isVarDeclaration();
            if (v->getValue()->op == TOKnull)
            {
                if (v->type->ty == Taarray)
                {   // Assign to empty associative array
                    Expressions *valuesx = new Expressions();
                    Expressions *keysx = new Expressions();
                    Expression *index = ie->e2->interpret(istate);
                    if (index == EXP_CANT_INTERPRET)
                        return EXP_CANT_INTERPRET;
                    valuesx->push(newval);
                    keysx->push(index);
                    Expression *aae2 = new AssocArrayLiteralExp(loc, keysx, valuesx);
                    aae2->type = v->type;
                    newval = aae2;
                    v->setValue(newval);
                    return e;
                }
                // This would be a runtime segfault
                error("Cannot index null array %s", v->toChars());
                return EXP_CANT_INTERPRET;
            }
            // Set the $ variable, and find the array literal to modify
            Expression *dollar = NULL;
            ArrayLiteralExp *ae = NULL;
            StringExp *se = NULL;
            if (v->getValue()->op == TOKslice)
            {
                SliceExp *sexp = (SliceExp *)v->getValue();
                dollar = new IntegerExp(loc, sexp->upr->toInteger()-sexp->lwr->toInteger(), Type::tsize_t);
                if (sexp->e1->op == TOKarrayliteral)
                    ae = (ArrayLiteralExp *)sexp->e1;
                if (sexp->e1->op == TOKstring)
                    se = (StringExp *)sexp->e1;
            }
            else if (v->getValue()->op == TOKarrayliteral
                || v->getValue()->op == TOKassocarrayliteral
                || v->getValue()->op == TOKstring)
            {
                dollar = ArrayLength(Type::tsize_t, v->getValue());
                if (v->getValue()->op == TOKarrayliteral)
                    ae = (ArrayLiteralExp *)v->getValue();
                if (v->getValue()->op == TOKstring)
                    se = (StringExp *)v->getValue();
            }
            else
            {
                error("CTFE internal compiler error %s", v->getValue()->toChars());
                return EXP_CANT_INTERPRET;
            }
            if (dollar != EXP_CANT_INTERPRET && ie->lengthVar)
                ie->lengthVar->createStackValue(dollar);
            // Determine the index, and check that it's OK.
            Expression *index = ie->e2->interpret(istate);
            if (ie->lengthVar)
                ie->lengthVar->setValueNull(); // $ is defined only inside []
            if (index == EXP_CANT_INTERPRET)
                return EXP_CANT_INTERPRET;

            if (ae)
            {
                int elemi = index->toInteger();
                if (elemi >= ae->elements->dim)
                {
                    error("array index %d is out of bounds %s[0..%d]", elemi,
                        v->getValue()->toChars(), ae->elements->dim);
                    return EXP_CANT_INTERPRET;
                }
                ae->elements->data[elemi] = newval;
                return e;
            }
            if (se)
            {
                    int elemi = index->toInteger();
                    if (elemi >= se->len)
                    {
                        error("array index %d is out of bounds %s[0..%d]", elemi,
                            se->toChars(), se->len);
                        return EXP_CANT_INTERPRET;
                    }
                    unsigned char *s = (unsigned char *)se->string;
                    unsigned value = newval->toInteger();
                    switch (se->sz)
                    {
                        case 1: s[elemi] = value; break;
                        case 2: ((unsigned short *)s)[elemi] = value; break;
                        case 4: ((unsigned *)s)[elemi] = value; break;
                        default:
                            assert(0);
                            break;
                    }
                    return e;
            }
            assert(v->getValue()->op == TOKassocarrayliteral);
            if (assignAssocArrayElement(loc, (AssocArrayLiteralExp *)v->getValue(), index, newval) == EXP_CANT_INTERPRET)
                return EXP_CANT_INTERPRET;
            return e;
        }
        else if (aggregate->op == TOKslice)
        {   IndexExp *ie = (IndexExp *)e1;
            SliceExp * sexp = (SliceExp *)aggregate;
            assert(sexp && sexp->upr && sexp->lwr);
            Expression *dollar = new IntegerExp(loc,
            sexp->upr->toInteger() - sexp->lwr->toInteger(), Type::tsize_t);
            if (dollar != EXP_CANT_INTERPRET && ie->lengthVar)
                ie->lengthVar->createStackValue(dollar);
            // Determine the index, and check that it's OK.
            Expression *index = ie->e2->interpret(istate);
            if (ie->lengthVar)
                ie->lengthVar->setValueNull(); // $ is defined only inside []
            if (index == EXP_CANT_INTERPRET)
                return EXP_CANT_INTERPRET;

            ArrayLiteralExp *ae = NULL;
            StringExp *se = NULL;
            VarDeclaration *v = NULL;
            if (sexp->e1->op == TOKarrayliteral)
                ae = (ArrayLiteralExp *)(sexp->e1);
            else if (sexp->e1->op == TOKstring)
                se = (StringExp *)(sexp->e1);
            else if (sexp->e1->op == TOKvar)
            {
                VarExp *ve = (VarExp *)(sexp->e1);
                v = ve->var->isVarDeclaration();
                assert(v);
                assert(v->getValue());
                if (v->getValue()->op == TOKarrayliteral)
                    ae = (ArrayLiteralExp *)v->getValue();
                else if (v->getValue()->op == TOKstring)
                    se = (StringExp *)v->getValue();
            }

            if (ae)
            {
                int elemi = index->toInteger() + sexp->lwr->toInteger();
                if (elemi >= ae->elements->dim)
                {
                    error("array index %d is out of bounds %s[0..%d]", elemi,
                        ae->toChars(), ae->elements->dim);
                    return EXP_CANT_INTERPRET;
                }
                ae->elements->data[elemi] = newval;
                return e;
            }
            else if (se)
            {
                int elemi = index->toInteger() + sexp->lwr->toInteger();
                if (elemi >= se->len)
                {
                    error("array index %d is out of bounds %s[0..%d]", elemi,
                        se->toChars(), se->len);
                    return EXP_CANT_INTERPRET;
                }
                unsigned char *s = (unsigned char *)se->string;
                unsigned value = newval->toInteger();
                switch (se->sz)
                {
                    case 1: s[elemi] = value; break;
                    case 2: ((unsigned short *)s)[elemi] = value; break;
                    case 4: ((unsigned *)s)[elemi] = value; break;
                    default:
                        assert(0);
                        break;
                }
                return e;
            }
            error("CTFE Internal Compiler Error: malformed slice assignment %s", toChars());
            return EXP_CANT_INTERPRET;
        }
        else
            error("Index assignment %s is not yet supported in CTFE ", toChars());

    }
    else if (e1->op == TOKslice)
    {
        // ------------------------------
        //   aggregate[] = newval
        //   aggregate[low..upp] = newval
        // ------------------------------
        SliceExp * sexp = (SliceExp *)e1;
        // Set the $ variable
        Expression *oldval = sexp->e1->interpret(istate);
        Expression *arraylen = ArrayLength(Type::tsize_t, oldval);
        if (arraylen == EXP_CANT_INTERPRET)
            return EXP_CANT_INTERPRET;
        if (sexp->lengthVar)
        {
            sexp->lengthVar->createStackValue(arraylen);
        }
        Expression *upper = NULL;
        Expression *lower = NULL;
        if (sexp->upr)
            upper = sexp->upr->interpret(istate);
        if (sexp->lwr)
            lower = sexp->lwr->interpret(istate);
        if (sexp->lengthVar)
            sexp->lengthVar->setValueNull(); // $ is defined only in [L..U]
        if (upper == EXP_CANT_INTERPRET || lower == EXP_CANT_INTERPRET)
            return EXP_CANT_INTERPRET;

        int dim = arraylen->toInteger();
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

        // This next line isn't quite right: what if it is block assignment of a string?
        bool isSliceAssignment = (newval->op == TOKarrayliteral)
            || (newval->op == TOKstring);
        size_t srclen = 0;
        if (newval->op == TOKarrayliteral)
            srclen = ((ArrayLiteralExp *)newval)->elements->dim;
        else if (newval->op == TOKstring)
            srclen = ((StringExp *)newval)->len;
        if (isSliceAssignment && srclen != (upperbound - lowerbound))
        {
            error("Array length mismatch assigning [0..%d] to [%d..%d]", srclen, lowerbound, upperbound);
            return EXP_CANT_INTERPRET;
        }

        Expression *aggregate = resolveReferences(((SliceExp *)e1)->e1, istate->localThis);
        int firstIndex = lowerbound;

        ArrayLiteralExp *existingAE = NULL;
        StringExp *existingSE = NULL;

        if (aggregate->op == TOKdotvar)
        {
            DotVarExp *dve = (DotVarExp *)aggregate;
            aggregate = dve->e1->interpret(istate);
            if (aggregate->op == TOKstructliteral)
            {
                StructLiteralExp *se = (StructLiteralExp *)aggregate;
                VarDeclaration *v = dve->var->isVarDeclaration();
                if (v)
                {
                    int i = se->getFieldIndex(dve->type, v->offset);
                    aggregate = (Expression *)se->elements->data[i];
                }
            }
        }
        if (aggregate->op == TOKindex)
        {
            IndexExp *ie = (IndexExp *)aggregate;
            // If it returns an array, it might be a slice.
            // We want to preserve the slice.
            if (ie->type->ty != Tarray)
                aggregate = aggregate->interpret(istate);
        }

        if (aggregate->op == TOKvar)
        {
            VarExp *ve = (VarExp *)(aggregate);
            VarDeclaration *v = ve->var->isVarDeclaration();
            aggregate = v->getValue();
        }
        if (aggregate->op == TOKslice)
        {   // Slice of a slice --> change the bounds
            SliceExp *sexpold = (SliceExp *)aggregate;
            dinteger_t hi = upperbound + sexpold->lwr->toInteger();
            firstIndex = lowerbound + sexpold->lwr->toInteger();
            if (hi > sexpold->upr->toInteger())
            {
                error("slice [%d..%d] exceeds array bounds [0..%jd]",
                    lowerbound, upperbound,
                    sexpold->upr->toInteger() - sexpold->lwr->toInteger());
                return EXP_CANT_INTERPRET;
            }
            aggregate = sexpold->e1;
        }
        if (aggregate->op==TOKarrayliteral)
            existingAE = (ArrayLiteralExp *)aggregate;
        else if (aggregate->op==TOKstring)
            existingSE = (StringExp *)aggregate;

        if (newval->op == TOKarrayliteral && existingAE)
        {
            Expressions *oldelems = existingAE->elements;
            Expressions *newelems = ((ArrayLiteralExp *)newval)->elements;
            for (size_t j = 0; j < newelems->dim; j++)
            {
                oldelems->data[j + firstIndex] = newelems->data[j];
            }
            return newval;
        }
        else if (newval->op == TOKstring && existingSE)
        {
            StringExp * newstr = (StringExp *)newval;
            unsigned char *s = (unsigned char *)existingSE->string;
            size_t sz = existingSE->sz;
            assert(sz == ((StringExp *)newval)->sz);
            memcpy(s + firstIndex * sz, newstr->string, sz * newstr->len);
            return newval;
        }
        else if (newval->op == TOKstring && existingAE)
        {   /* Mixed slice: it was initialized as an array literal of chars.
             * Now a slice of it is being set with a string.
             */
            size_t newlen =  ((StringExp *)newval)->len;
            size_t sz = ((StringExp *)newval)->sz;
            unsigned char *s = (unsigned char *)((StringExp *)newval)->string;
            Type *elemType = existingAE->type->nextOf();
            for (size_t j = 0; j < newlen; j++)
            {
                dinteger_t val;
                switch (sz)
                {
                    case 1: val = s[j]; break;
                    case 2: val = ((unsigned short *)s)[j]; break;
                    case 4: val = ((unsigned *)s)[j]; break;
                    default:
                        assert(0);
                        break;
                }
                existingAE->elements->data[j+firstIndex]
                    = new IntegerExp(newval->loc, val, elemType);
            }
            return newval;
        }
        else if (newval->op == TOKarrayliteral && existingSE)
        {   /* Mixed slice: it was initialized as a string literal.
             * Now a slice of it is being set with an array literal.
             */
            unsigned char *s = (unsigned char *)existingSE->string;
            ArrayLiteralExp *newae = (ArrayLiteralExp *)newval;
            for (size_t j = 0; j < newae->elements->dim; j++)
            {
                unsigned value = ((Expression *)(newae->elements->data[j]))->toInteger();
                switch (existingSE->sz)
                {
                    case 1: s[j+firstIndex] = value; break;
                    case 2: ((unsigned short *)s)[j+firstIndex] = value; break;
                    case 4: ((unsigned *)s)[j+firstIndex] = value; break;
                    default:
                        assert(0);
                        break;
                }
            }
            return newval;
        }
        else if (existingSE)
        {   // String literal block slice assign
            unsigned value = newval->toInteger();
            unsigned char *s = (unsigned char *)existingSE->string;
            for (size_t j = 0; j < upperbound-lowerbound; j++)
            {
                switch (existingSE->sz)
                {
                    case 1: s[j+firstIndex] = value; break;
                    case 2: ((unsigned short *)s)[j+firstIndex] = value; break;
                    case 4: ((unsigned *)s)[j+firstIndex] = value; break;
                    default:
                        assert(0);
                        break;
                }
            }
            return newval;
        }
        else if (existingAE)
        {
                /* Block assignment, initialization of static arrays
                 *   x[] = e
                 *  x may be a multidimensional static array. (Note that this
                 *  only happens with array literals, never with strings).
                 */
                Expressions * w = existingAE->elements;
                for (size_t j = 0; j < upperbound-lowerbound; j++)
                {
                    if (((Expression *)w->data[j+firstIndex])->op == TOKarrayliteral)
                        // Multidimensional array block assign
                        recursiveBlockAssign((ArrayLiteralExp *)w->data[j+firstIndex], newval);
                    else // Single dimension block assign
                        existingAE->elements->data[j+firstIndex] = newval;
                }
                return newval;
        }
        else
            error("Slice operation %s cannot be evaluated at compile time", toChars());
    }
    else if (e1->op == TOKstar)
    {
        /* Assignment to struct member of the form:
         *   *(symoffexp) = newval
         */
        if (((PtrExp *)e1)->e1->op == TOKsymoff)
        {   SymOffExp *soe = (SymOffExp *)((PtrExp *)e1)->e1;
            VarDeclaration *v = soe->var->isVarDeclaration();
            if (v->isDataseg() && !v->isCTFE())
            {
                error("%s cannot be modified at compile time", v->toChars());
                return EXP_CANT_INTERPRET;
            }
            if (fp && !v->getValue())
            {   error("variable %s is used before initialization", v->toChars());
                return e;
            }
            Expression *vie = v->getValue();
            if (vie->op == TOKvar)
            {
                Declaration *d = ((VarExp *)vie)->var;
                vie = getVarExp(e1->loc, istate, d, true);
            }
            if (vie->op != TOKstructliteral)
                return EXP_CANT_INTERPRET;

            StructLiteralExp *se = (StructLiteralExp *)vie;

            newval = modifyStructField(type, se, soe->offset, newval);

            addVarToInterstate(istate, v);
            v->setValue(newval);
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

Expression *AssignExp::interpret(InterState *istate, bool wantLvalue)
{
    return interpretAssignCommon(istate, wantLvalue, NULL);
}

#define BIN_ASSIGN_INTERPRET(op) \
Expression *op##AssignExp::interpret(InterState *istate, bool wantLvalue) \
{                                                                         \
    return interpretAssignCommon(istate, wantLvalue, &op);                \
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

Expression *PostExp::interpret(InterState *istate, bool wantLvalue)
{
#if LOG
    printf("PostExp::interpret() %s\n", toChars());
#endif
    Expression *e;
    if (op == TOKplusplus)
        e = interpretAssignCommon(istate, wantLvalue, &Add, 1);
    else
        e = interpretAssignCommon(istate, wantLvalue, &Min, 1);
#if LOG
    if (e == EXP_CANT_INTERPRET)
        printf("PostExp::interpret() CANT\n");
#endif
    return e;
}

Expression *AndAndExp::interpret(InterState *istate, bool wantLvalue)
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

Expression *OrOrExp::interpret(InterState *istate, bool wantLvalue)
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


Expression *CallExp::interpret(InterState *istate, bool wantLvalue)
{   Expression *e = EXP_CANT_INTERPRET;

#if LOG
    printf("CallExp::interpret() %s\n", toChars());
#endif

    Expression * pthis = NULL;
    FuncDeclaration *fd = NULL;
    Expression *ecall = e1;
    if (ecall->op == TOKcall)
    {
        ecall = e1->interpret(istate);
        if (ecall == EXP_CANT_INTERPRET)
            return ecall;
    }
    if (ecall->op == TOKstar)
    {   // Calling a function pointer
        Expression * pe = ((PtrExp*)ecall)->e1;
        if (pe->op == TOKvar) {
            VarDeclaration *vd = ((VarExp *)((PtrExp*)ecall)->e1)->var->isVarDeclaration();
            if (vd && vd->getValue() && vd->getValue()->op == TOKsymoff)
                fd = ((SymOffExp *)vd->getValue())->var->isFuncDeclaration();
            else
            {
                ecall = getVarExp(loc, istate, vd, wantLvalue);
                if (ecall == EXP_CANT_INTERPRET)
                    return ecall;

                if (ecall->op == TOKsymoff)
                    fd = ((SymOffExp *)ecall)->var->isFuncDeclaration();
            }
        }
        else
            ecall = ((PtrExp*)ecall)->e1->interpret(istate);

    }
    if (ecall == EXP_CANT_INTERPRET)
        return ecall;

    if (ecall->op == TOKindex)
    {   ecall = e1->interpret(istate);
        if (ecall == EXP_CANT_INTERPRET)
            return ecall;
    }

    if (ecall->op == TOKdotvar && !((DotVarExp*)ecall)->var->isFuncDeclaration())
    {   ecall = e1->interpret(istate);
        if (ecall == EXP_CANT_INTERPRET)
            return ecall;
    }

    if (ecall->op == TOKdotvar)
    {   // Calling a member function
        pthis = ((DotVarExp*)e1)->e1;
        fd = ((DotVarExp*)e1)->var->isFuncDeclaration();
    }
    else if (ecall->op == TOKvar)
    {
        VarDeclaration *vd = ((VarExp *)ecall)->var->isVarDeclaration();
        if (vd && vd->getValue())
            ecall = vd->getValue();
        else // Calling a function
            fd = ((VarExp *)e1)->var->isFuncDeclaration();
    }
    if (ecall->op == TOKdelegate)
    {   // Calling a delegate
        fd = ((DelegateExp *)ecall)->func;
        pthis = ((DelegateExp *)ecall)->e1;
    }
    else if (ecall->op == TOKfunction)
    {   // Calling a delegate literal
        fd = ((FuncExp*)ecall)->fd;
    }
    else if (ecall->op == TOKstar && ((PtrExp*)ecall)->e1->op==TOKfunction)
    {   // Calling a function literal
        fd = ((FuncExp*)((PtrExp*)ecall)->e1)->fd;
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
            pthis = istate ? istate->localThis : NULL;
        else if (pthis->op == TOKcomma)
            pthis = pthis->interpret(istate);
        if (!fd->fbody)
        {
            error("%s cannot be interpreted at compile time,"
                " because it has no available source code", fd->toChars());
            return EXP_CANT_INTERPRET;
        }
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

#if DMDV1
        if (fd->ident == Id::aaLen)
            return interpret_aaLen(istate, arguments);
        else if (fd->ident == Id::aaKeys)
            return interpret_aaKeys(istate, arguments);
        else if (fd->ident == Id::aaValues)
            return interpret_aaValues(istate, arguments);
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
            if (!fd->fbody)
            {
                error("%s cannot be interpreted at compile time,"
                    " because it has no available source code", fd->toChars());
                return EXP_CANT_INTERPRET;
            }
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

Expression *CommaExp::interpret(InterState *istate, bool wantLvalue)
{
#if LOG
    printf("CommaExp::interpret() %s\n", toChars());
#endif

    CommaExp * firstComma = this;
    while (firstComma->e1->op == TOKcomma)
        firstComma = (CommaExp *)firstComma->e1;

    // If it creates a variable, and there's no context for
    // the variable to be created in, we need to create one now.
    InterState istateComma;
    if (!istate &&  firstComma->e1->op == TOKdeclaration)
        istate = &istateComma;

    // If the comma returns a temporary variable, it needs to be an lvalue
    // (this is particularly important for struct constructors)
    if (e1->op == TOKdeclaration && e2->op == TOKvar
       && ((DeclarationExp *)e1)->declaration == ((VarExp*)e2)->var)
    {
        VarExp* ve = (VarExp *)e2;
        VarDeclaration *v = ve->var->isVarDeclaration();
        if (!v->init && !v->getValue())
        {
            v->createValue(copyLiteral(v->type->defaultInitLiteral()));
        }
        if (!v->getValue()) {
            Expression *newval = v->init->toExpression();
//            v->setValue(v->init->toExpression());
            // Bug 4027. Copy constructors are a weird case where the
            // initializer is a void function (the variable is modified
            // through a reference parameter instead).
            newval = newval->interpret(istate);
            if (newval != EXP_VOID_INTERPRET)
            {
                // v isn't necessarily null.
                v->restoreValue(copyLiteral(newval));
            }
        }
        return e2;
    }
    Expression *e = e1->interpret(istate);
    if (e != EXP_CANT_INTERPRET)
        e = e2->interpret(istate);
    return e;
}

Expression *CondExp::interpret(InterState *istate, bool wantLvalue)
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

Expression *ArrayLengthExp::interpret(InterState *istate, bool wantLvalue)
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

Expression *IndexExp::interpret(InterState *istate, bool wantLvalue)
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
        {
            lengthVar->createStackValue(e);
        }
    }

    e2 = this->e2->interpret(istate);
    if (lengthVar)
        lengthVar->setValueNull(); // $ is defined only inside []
    if (e2 == EXP_CANT_INTERPRET)
        goto Lcant;
    e = Index(type, e1, e2);
    if (e == EXP_CANT_INTERPRET)
        error("%s cannot be interpreted at compile time", toChars());
    return e;

Lcant:
    return EXP_CANT_INTERPRET;
}


Expression *SliceExp::interpret(InterState *istate, bool wantLvalue)
{   Expression *e;
    Expression *e1;
    Expression *lwr;
    Expression *upr;

#if LOG
    printf("SliceExp::interpret() %s\n", toChars());
#endif
    e1 = this->e1->interpret(istate, wantLvalue);
    if (e1 == EXP_CANT_INTERPRET)
        goto Lcant;
    if (!this->lwr)
    {
        if (wantLvalue)
            return e1;
        e = e1->castTo(NULL, type);
        return e->interpret(istate);
    }

    /* Set the $ variable
     */
    e = ArrayLength(Type::tsize_t, e1);
    if (e == EXP_CANT_INTERPRET)
    {
        error("Cannot determine length of %s at compile time\n", e1->toChars());
        goto Lcant;
    }
    if (lengthVar)
        lengthVar->createStackValue(e);

    /* Evaluate lower and upper bounds of slice
     */
    lwr = this->lwr->interpret(istate);
    if (lwr == EXP_CANT_INTERPRET)
        goto Lcant;
    upr = this->upr->interpret(istate);
    if (upr == EXP_CANT_INTERPRET)
        goto Lcant;
    if (lengthVar)
        lengthVar->setValueNull(); // $ is defined only inside [L..U]
    if (wantLvalue)
    {
        assert(e1->op != TOKslice);
        e = new SliceExp(loc, e1, lwr, upr);
        e->type = type;
        return e;
    }
    e = Slice(type, e1, lwr, upr);
    if (e == EXP_CANT_INTERPRET)
        error("%s cannot be interpreted at compile time", toChars());
    return e;

Lcant:
    if (lengthVar)
        lengthVar->setValueNull();
    return EXP_CANT_INTERPRET;
}


Expression *CatExp::interpret(InterState *istate, bool wantLvalue)
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
    e = Cat(type, e1, e2);
    if (e == EXP_CANT_INTERPRET)
        error("%s cannot be interpreted at compile time", toChars());
    return e;

Lcant:
#if LOG
    printf("CatExp::interpret() %s CANT\n", toChars());
#endif
    return EXP_CANT_INTERPRET;
}


Expression *CastExp::interpret(InterState *istate, bool wantLvalue)
{   Expression *e;
    Expression *e1;

#if LOG
    printf("CastExp::interpret() %s\n", toChars());
#endif
    e1 = this->e1->interpret(istate);
    if (e1 == EXP_CANT_INTERPRET)
        goto Lcant;
    e = Cast(type, to, e1);
    if (e == EXP_CANT_INTERPRET)
        error("%s cannot be interpreted at compile time", toChars());
    return e;

Lcant:
#if LOG
    printf("CastExp::interpret() %s CANT\n", toChars());
#endif
    return EXP_CANT_INTERPRET;
}


Expression *AssertExp::interpret(InterState *istate, bool wantLvalue)
{   Expression *e;
    Expression *e1;

#if LOG
    printf("AssertExp::interpret() %s\n", toChars());
#endif
    if( this->e1->op == TOKaddress)
    {   // Special case: deal with compiler-inserted assert(&this, "null this")
        AddrExp *ade = (AddrExp *)this->e1;
        if (ade->e1->op == TOKthis && istate->localThis)
            if (istate->localThis->op == TOKdotvar
                && ((DotVarExp *)(istate->localThis))->e1->op == TOKthis)
                return getVarExp(loc, istate, ((DotVarExp*)(istate->localThis))->var, false);
            else
                return istate->localThis->interpret(istate);
    }
    if (this->e1->op == TOKthis)
    {
        if (istate->localThis)
        {
            if (istate->localThis->op == TOKdotvar
                && ((DotVarExp *)(istate->localThis))->e1->op == TOKthis)
                return getVarExp(loc, istate, ((DotVarExp*)(istate->localThis))->var, false);
            else
                return istate->localThis->interpret(istate);
        }
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

Expression *PtrExp::interpret(InterState *istate, bool wantLvalue)
{   Expression *e = EXP_CANT_INTERPRET;

#if LOG
    printf("PtrExp::interpret() %s\n", toChars());
#endif

    // Constant fold *(&structliteral + offset)
    if (e1->op == TOKadd)
    {   AddExp *ae = (AddExp *)e1;
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
    {   SymOffExp *soe = (SymOffExp *)e1;
        VarDeclaration *v = soe->var->isVarDeclaration();
        if (v)
        {   Expression *ev = getVarExp(loc, istate, v, wantLvalue);
            if (ev != EXP_CANT_INTERPRET && ev->op == TOKstructliteral)
            {   StructLiteralExp *se = (StructLiteralExp *)ev;
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
    else
        error("Cannot interpret %s at compile time", toChars());

#if LOG
    if (e == EXP_CANT_INTERPRET)
        printf("PtrExp::interpret() %s = EXP_CANT_INTERPRET\n", toChars());
#endif
    return e;
}

Expression *DotVarExp::interpret(InterState *istate, bool wantLvalue)
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
            {   e = se->getField(type, v->offset);
                if (!e)
                {
                    error("couldn't find field %s in %s", v->toChars(), type->toChars());
                    e = EXP_CANT_INTERPRET;
                }
                return e;
            }
        }
        else
            error("%s.%s is not yet implemented at compile time", e1->toChars(), var->toChars());
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
    if (earg->op != TOKassocarrayliteral && earg->type->toBasetype()->ty != Taarray)
        return NULL;
    if (earg->op == TOKnull)
        return new NullExp(earg->loc);
    assert(earg->op == TOKassocarrayliteral);
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
    if (earg->op != TOKassocarrayliteral && earg->type->toBasetype()->ty != Taarray)
        return NULL;
    if (earg->op == TOKnull)
        return new NullExp(earg->loc);
    assert(earg->op == TOKassocarrayliteral);
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
