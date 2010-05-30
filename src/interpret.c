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

ArrayLiteralExp *createBlockDuplicatedArrayLiteral(Type *type, Expression *elem, size_t dim);
Expression * resolveReferences(Expression *e, Expression *thisval, bool *isReference = NULL);

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
                VarExp *ve = (VarExp *)earg;
                VarDeclaration *v2 = ve->var->isVarDeclaration();
                if (!v2)
                {   cantInterpret = 1;
                        return NULL;
                }
                v->value = earg;
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
            istatex.start = istatex.gotoTarget; // set starting statement
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
            {   v->value = (Expression *)valueSaves.data[i];
                //printf("\trestoring [%d] %s = %s\n", i, v->toChars(), v->value ? v->value->toChars() : "");
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

Expression *Statement::interpret(InterState *istate)
{
#if LOG
    printf("Statement::interpret()\n");
#endif
    START()
    error("Statement %s cannot be interpreted at compile time", this->toChars());
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
        assert (v && v->value);
        return v->value;
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
            istate->awaitingLvalueReturn = true;
            next = next->interpret(istate);
            if (next == EXP_CANT_INTERPRET) return next;
        }
        if (next->op == TOKvar)
        {
            VarDeclaration * v = ((VarExp*)next)->var->isVarDeclaration();
            if (v)
                next = v->value;
        }
        else if (next->op == TOKthis)
            next = istate->localThis;

        if (old == next)
        {   // Haven't found the reference yet. Need to keep copying.
            next = next->copy();
            old = next;
        }
        if (e->op == TOKindex)
            ((IndexExp*)e)->e1 = next;
        else if (e->op == TOKdotvar)
            ((DotVarExp *)e)->e1 = next;
        else if (e->op == TOKdotti)
            ((DotTemplateInstanceExp *)e)->e1 = next;
        else if (e->op == TOKslice)
            ((SliceExp*)e)->e1 = next;

        if (old != next)
            break;
        e = next;
    }

     return r;
}

Expression *ReturnStatement::interpret(InterState *istate)
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
    assert(0);                  // rewritten to ForStatement
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


Expression *TryCatchStatement::interpret(InterState *istate)
{
#if LOG
    printf("TryCatchStatement::interpret()\n");
#endif
    START()
    error("try-catch statements are not yet supported in CTFE");
    return EXP_CANT_INTERPRET;
}


Expression *TryFinallyStatement::interpret(InterState *istate)
{
#if LOG
    printf("TryFinallyStatement::interpret()\n");
#endif
    START()
    error("try-finally statements are not yet supported in CTFE");
    return EXP_CANT_INTERPRET;
}

Expression *ThrowStatement::interpret(InterState *istate)
{
#if LOG
    printf("ThrowStatement::interpret()\n");
#endif
    START()
    error("throw statements are not yet supported in CTFE");
    return EXP_CANT_INTERPRET;
}

Expression *OnScopeStatement::interpret(InterState *istate)
{
#if LOG
    printf("OnScopeStatement::interpret()\n");
#endif
    START()
    error("scope guard statements are not yet supported in CTFE");
    return EXP_CANT_INTERPRET;
}

Expression *WithStatement::interpret(InterState *istate)
{
#if LOG
    printf("WithStatement::interpret()\n");
#endif
    START()
    error("with statements are not yet supported in CTFE");
    return EXP_CANT_INTERPRET;
}

Expression *AsmStatement::interpret(InterState *istate)
{
#if LOG
    printf("AsmStatement::interpret()\n");
#endif
    START()
    error("asm statements cannot be interpreted at compile time");
    return EXP_CANT_INTERPRET;
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
            if (v && v->value && v->value->op == TOKvar) // it's probably a reference
            {
                // Make sure it's a real reference.
                // It's not a reference if v is a struct initialized to
                // 0 using an __initZ SymbolDeclaration from
                // TypeStruct::defaultInit()
                VarExp *ve2 = (VarExp *)v->value;
                if (!ve2->var->isSymbolDeclaration())
                {
                    if (isReference)
                        *isReference = true;
                    e = v->value;
                    continue;
                }
            }
            else if (v && v->value && (v->value->op==TOKindex || v->value->op == TOKdotvar
                  || v->value->op == TOKthis || v->value->op == TOKslice ))
            {
                e = v->value;
                continue;
            }
        }
        break;
    }
    return e;
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
        else
        {   e = v->value;
            if (!v->isCTFE())
            {   error(loc, "static variable %s cannot be read at compile time", v->toChars());
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
            ((TypeArray *)newtype)->next->defaultInitLiteral(),
            lenExpr->toInteger());
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
Expression *op##Exp::interpret(InterState *istate)      \
{                                                       \
    return interpretCommon(istate, &op);                \
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
Expression *op##Exp::interpret(InterState *istate)      \
{                                                       \
    return interpretCommon(istate, &op);                \
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
Expression *op##Exp::interpret(InterState *istate)      \
{                                                       \
    return interpretCommon2(istate, &op);               \
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
Expression * assignArrayElement(Loc loc, Expression *arr, Expression *index, Expression *newval)
{
        ArrayLiteralExp *ae = NULL;
        AssocArrayLiteralExp *aae = NULL;
        StringExp *se = NULL;
        if (arr->op == TOKarrayliteral)
            ae = (ArrayLiteralExp *)arr;
        else if (arr->op == TOKassocarrayliteral)
            aae = (AssocArrayLiteralExp *)arr;
        else if (arr->op == TOKstring)
            se = (StringExp *)arr;
        else assert(0);

        if (ae)
        {
            int elemi = index->toInteger();
            if (elemi >= ae->elements->dim)
            {
                error(loc, "array index %d is out of bounds %s[0..%d]", elemi,
                    arr->toChars(), ae->elements->dim);
                return EXP_CANT_INTERPRET;
            }
            // Create new array literal reflecting updated elem
            Expressions *expsx = changeOneElement(ae->elements, elemi, newval);
            Expression *ee = new ArrayLiteralExp(ae->loc, expsx);
            ee->type = ae->type;
            newval = ee;
        }
        else if (se)
        {
            /* Create new string literal reflecting updated elem
             */
            int elemi = index->toInteger();
            if (elemi >= se->len)
            {
                error(loc, "array index %d is out of bounds %s[0..%d]", elemi,
                    arr->toChars(), se->len);
                return EXP_CANT_INTERPRET;
            }
            unsigned char *s;
            s = (unsigned char *)mem.calloc(se->len + 1, se->sz);
            memcpy(s, se->string, se->len * se->sz);
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
            StringExp *se2 = new StringExp(se->loc, s, se->len);
            se2->committed = se->committed;
            se2->postfix = se->postfix;
            se2->type = se->type;
            newval = se2;
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
            {   j--;
                Expression *ekey = (Expression *)aae->keys->data[j];
                Expression *ex = Equal(TOKequal, Type::tbool, ekey, index);
                if (ex == EXP_CANT_INTERPRET)
                    return EXP_CANT_INTERPRET;
                if (ex->isBool(TRUE))
                {   valuesx->data[j] = (void *)newval;
                    updated = 1;
                }
                else
                    valuesx->data[j] = aae->values->data[j];
            }
            if (!updated)
            {   // Append index/newval to keysx[]/valuesx[]
                valuesx->push(newval);
                keysx = (Expressions *)keysx->copy();
                keysx->push(index);
            }
            Expression *aae2 = new AssocArrayLiteralExp(aae->loc, keysx, valuesx);
            aae2->type = aae->type;
            return aae2;
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

    // ----------------------------------------------------
    //  Deal with read-modify-write assignments.
    //  Set 'newval' to the final assignment value
    //  Also determine the return value (except for slice
    //  assignments, which are more complicated)
    // ----------------------------------------------------
    Expression * newval = this->e2->interpret(istate);
    if (newval == EXP_CANT_INTERPRET)
        return newval;

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
    else if (e1->op != TOKslice)
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
    if (ultimateVar && !ultimateVar->isCTFE())
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
        v->value = e2;
        return e2;
    }
    bool destinationIsReference = false;
    e1 = resolveReferences(e1, istate->localThis, &destinationIsReference);

    // Unless we have a simple var assignment, we're
    // only modifying part of the variable. So we need to make sure
    // that the parent variable exists.
    if (e1->op != TOKvar && ultimateVar && !ultimateVar->value)
        ultimateVar->value = ultimateVar->type->defaultInitLiteral();

    // ----------------------------------------
    //      Deal with dotvar expressions
    // ----------------------------------------
    // Because structs are not reference types, dotvar expressions can be
    // collapsed into a single assignment.
    bool startedWithCall = false;
    if (e1->op == TOKcall) startedWithCall = true;
    while (e1->op == TOKdotvar || e1->op == TOKcall)
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
                v->value = newval;
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
                istate->awaitingLvalueReturn = true;
                e1 = e1->interpret(istate);
                istate->awaitingLvalueReturn = false;

                if (e1==EXP_CANT_INTERPRET) return e1;
                assert(newval);
                assert(newval !=EXP_CANT_INTERPRET);
        }
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
        v->value = newval;
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
            if (v->value->op == TOKnull)
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
                    v->value = newval;
                    return e;
                }
                // This would be a runtime segfault
                error("Cannot index null array %s", v->toChars());
                return EXP_CANT_INTERPRET;
            }
            else if (v->value->op != TOKarrayliteral
                && v->value->op != TOKassocarrayliteral
                && v->value->op != TOKstring)
            {
                error("CTFE internal compiler error");
                return EXP_CANT_INTERPRET;
            }
            // Set the $ variable
            Expression *dollar = ArrayLength(Type::tsize_t, v->value);
            if (dollar != EXP_CANT_INTERPRET && ie->lengthVar)
                ie->lengthVar->value = dollar;
            // Determine the index, and check that it's OK.
            Expression *index = ie->e2->interpret(istate);
            if (index == EXP_CANT_INTERPRET)
                return EXP_CANT_INTERPRET;
            newval = assignArrayElement(loc, v->value, index, newval);
            if (newval == EXP_CANT_INTERPRET)
                return EXP_CANT_INTERPRET;
            v->value = newval;
            return e;
        }
        else
            error("Index assignment %s is not yet supported in CTFE ", toChars());

    }
    else if (e1->op == TOKslice)
    {
        Expression *aggregate = resolveReferences(((SliceExp *)e1)->e1, istate->localThis);
        // ------------------------------
        //   aggregate[] = newval
        //   aggregate[low..upp] = newval
        // ------------------------------
        /* Slice assignment, initialization of static arrays
        *   a[] = e
        */
        if (aggregate->op==TOKvar)
        {
            SliceExp * sexp = (SliceExp *)e1;
            VarExp *ve = (VarExp *)(aggregate);
            VarDeclaration *v = ve->var->isVarDeclaration();
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
                return e;
            }
        if (newval->op == TOKarrayliteral)
        {
            // Static array assignment from literal
            if (upperbound - lowerbound != dim)
            {
                ArrayLiteralExp *ae = (ArrayLiteralExp *)newval;
                ArrayLiteralExp *existing = (ArrayLiteralExp *)v->value;
                // value[] = value[0..lower] ~ ae ~ value[upper..$]
                existing->elements = spliceElements(existing->elements, ae->elements, lowerbound);
                newval = existing;
            }
            v->value = newval;
            return newval;
        }
        else if (newval->op == TOKstring)
        {
            StringExp *se = (StringExp *)newval;
            if (upperbound-lowerbound == dim)
                v->value = newval;
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
            return newval;
        }
        else if (t->nextOf()->ty == newval->type->ty)
        {
            // Static array block assignment
            e = createBlockDuplicatedArrayLiteral(v->type, newval, upperbound-lowerbound);

            if (upperbound - lowerbound == dim)
                newval = e;
            else
            {
                ArrayLiteralExp * newarrayval;
                // Only modifying part of the array. Must create a new array literal.
                // If the existing array is uninitialized (this can only happen
                // with static arrays), create it.
                if (v->value && v->value->op == TOKarrayliteral)
                    newarrayval = (ArrayLiteralExp *)v->value;
                else // this can only happen with static arrays
                    newarrayval = createBlockDuplicatedArrayLiteral(v->type, v->type->defaultInit(), dim);
                // value[] = value[0..lower] ~ e ~ value[upper..$]
                newarrayval->elements = spliceElements(newarrayval->elements,
                        ((ArrayLiteralExp *)e)->elements, lowerbound);
                newval = newarrayval;
                }
                v->value = newval;
                return e;
            }
            else
            {
                error("Slice operation %s cannot be evaluated at compile time", toChars());
                return e;
            }
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

            newval = modifyStructField(type, se, soe->offset, newval);

            addVarToInterstate(istate, v);
            v->value = newval;
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
Expression *op##AssignExp::interpret(InterState *istate)        \
{                                                               \
    return interpretAssignCommon(istate, &op);                  \
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
            if (vd && vd->value && vd->value->op==TOKsymoff)
                fd = ((SymOffExp *)vd->value)->var->isFuncDeclaration();
            else {
                ecall = vd->value->interpret(istate);
                if (ecall->op==TOKsymoff)
                        fd = ((SymOffExp *)ecall)->var->isFuncDeclaration();
                }
        }
        else
            ecall = ((PtrExp*)ecall)->e1->interpret(istate);
    }
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
        // If there's no context for the variable to be created in,
        // we need to create one now.
        InterState istateComma;
        if (!istate)
            istate = &istateComma;

        VarExp* ve = (VarExp *)e2;
        VarDeclaration *v = ve->var->isVarDeclaration();
        if (!v->init && !v->value)
            v->value = v->type->defaultInitLiteral();
        if (!v->value)
            v->value = v->init->toExpression();
        // Bug 4027. Copy constructors are a weird case where the
        // initializer is a void function (the variable is modified
        // through a reference parameter instead).
        Expression *newval = v->value->interpret(istate);
        if (newval != EXP_VOID_INTERPRET)
            v->value = newval;
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
    e = Index(type, e1, e2);
    if (e == EXP_CANT_INTERPRET)
        error("%s cannot be interpreted at compile time", toChars());
    return e;

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

    e = Slice(type, e1, lwr, upr);
    if (e == EXP_CANT_INTERPRET)
        error("%s cannot be interpreted at compile time", toChars());
    return e;

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


Expression *CastExp::interpret(InterState *istate)
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
        {   Expression *ev = getVarExp(loc, istate, v);
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
