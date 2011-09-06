// Compiler implementation of the D programming language
// Copyright (c) 1999-2011 by Digital Mars
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
#include "utf.h"

#define LOG     0
#define LOGASSIGN 0

struct InterState
{
    InterState *caller;         // calling function's InterState
    FuncDeclaration *fd;        // function being interpreted
    VarDeclarations vars;              // variables used in this function
    Statement *start;           // if !=NULL, start execution at this statement
    Statement *gotoTarget;      /* target of EXP_GOTO_INTERPRET result; also
                                 * target of labelled EXP_BREAK_INTERPRET or
                                 * EXP_CONTINUE_INTERPRET. (NULL if no label).
                                 */
    Expression *localThis;      // value of 'this', or NULL if none
    bool awaitingLvalueReturn;  // Support for ref return values:
           // Any return to this function should return an lvalue.
    InterState();
};

InterState::InterState()
{
    memset(this, 0, sizeof(InterState));
}

Expression * resolveReferences(Expression *e, Expression *thisval, bool *isReference = NULL);
Expression *getVarExp(Loc loc, InterState *istate, Declaration *d, CtfeGoal goal);
VarDeclaration *findParentVar(Expression *e, Expression *thisval);
void addVarToInterstate(InterState *istate, VarDeclaration *v);
bool needToCopyLiteral(Expression *expr);
Expression *copyLiteral(Expression *e);
Expression *paintTypeOntoLiteral(Type *type, Expression *lit);
bool evaluateIfBuiltin(Expression **result, InterState *istate,
    FuncDeclaration *fd, Expressions *arguments, Expression *pthis);


// Used for debugging only
void showCtfeExpr(Expression *e, int level = 0)
{
    for (int i = level; i>0; --i) printf(" ");
    Expressions *elements = NULL;
    // We need the struct definition to detect block assignment
    StructDeclaration *sd = NULL;
    if (e->op == TOKstructliteral) {
        elements = ((StructLiteralExp *)e)->elements;
        sd = ((StructLiteralExp *)e)->sd;
        printf("STRUCT type = %s %p :\n", e->type->toChars(), e);
    }
    else if (e->op == TOKarrayliteral)
    {
        elements = ((ArrayLiteralExp *)e)->elements;
        printf("ARRAY LITERAL type=%s %p:\n", e->type->toChars(), e);
    }
    else if (e->op == TOKassocarrayliteral)
    {
        printf("AA LITERAL type=%s %p:\n", e->type->toChars(), e);
    }
    else if (e->op == TOKstring)
    {
        printf("STRING %s %p\n", e->toChars(), ((StringExp *)e)->string);
    }
    else if (e->op == TOKslice)
    {
        printf("SLICE %p: %s\n", e, e->toChars());
        showCtfeExpr(((SliceExp *)e)->e1, level + 1);
    }
    else if (e->op == TOKvar)
    {
        printf("VAR %p %s\n", e, e->toChars());
        VarDeclaration *v = ((VarExp *)e)->var->isVarDeclaration();
        if (v && v->getValue())
            showCtfeExpr(v->getValue(), level + 1);
    }
    else printf("VALUE %p: %s\n", e, e->toChars());

    if (elements)
    {
        for (size_t i = 0; i < elements->dim; i++)
        {   Expression *z = elements->tdata()[i];
            if (sd)
            {
                Dsymbol *s = sd->fields.tdata()[i];
                VarDeclaration *v = s->isVarDeclaration();
                assert(v);
                // If it is a void assignment, use the default initializer
                if (!z) {
                    for (int j = level; j>0; --j) printf(" ");
                    printf(" field:void\n");
                    continue;
                }
                if ((v->type->ty != z->type->ty) && v->type->ty == Tsarray)
                {
                    for (int j = level; --j;) printf(" ");
                    printf(" field: block initalized static array\n");
                    continue;
                }
            }
            showCtfeExpr(z, level + 1);
        }
    }
}

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

    if (cantInterpret || semanticRun == PASSsemantic3)
        return NULL;

    if (semanticRun < PASSsemantic3 && scope)
    {
        int olderrors = global.errors;
        semantic3(scope);
        if (olderrors != global.errors)      // if errors compiling this function
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
    {   // error, no this. Prevent segfault.
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
        {   Expression *earg = arguments->tdata()[i];
            Parameter *arg = Parameter::getNth(tf->parameters, i);

            if (arg->storageClass & (STCout | STCref))
            {
                if (!istate && (arg->storageClass & STCout))
                {   // initializing an out parameter involves writing to it.
                    earg->error("global %s cannot be passed as an 'out' parameter at compile time", earg->toChars());
                    return NULL;
                }
                // Convert all reference arguments into lvalue references
                earg = earg->interpret(istate, ctfeNeedLvalueRef);
                if (earg == EXP_CANT_INTERPRET)
                    return NULL;
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
                earg = earg->interpret(istate);
                if (earg == EXP_CANT_INTERPRET)
                    return NULL;
            }
            eargs.tdata()[i] = earg;
        }

        for (size_t i = 0; i < dim; i++)
        {   Expression *earg = eargs.tdata()[i];
            Parameter *arg = Parameter::getNth(tf->parameters, i);
            VarDeclaration *v = parameters->tdata()[i];
            vsave.tdata()[i] = v->getValue();
#if LOG
            printf("arg[%d] = %s\n", i, earg->toChars());
#endif
            if (arg->storageClass & (STCout | STCref) && earg->op==TOKvar)
            {
                VarExp *ve = (VarExp *)earg;
                VarDeclaration *v2 = ve->var->isVarDeclaration();
                if (!v2)
                {
                        error("cannot interpret %s as a ref parameter", ve->toChars());
                        return NULL;
                }
                v->setValueWithoutChecking(earg);
                /* Don't restore the value of v2 upon function return
                 */
                for (size_t j = 0; j < (istate ? istate->vars.dim : 0); j++)
                {   VarDeclaration *vx = istate->vars.tdata()[j];
                    if (vx == v2)
                    {   istate->vars.tdata()[j] = NULL;
                        break;
                    }
                }
            }
            else
            {   // Value parameters and non-trivial references
                v->setValueWithoutChecking(earg);
            }
#if LOG || LOGASSIGN
            printf("interpreted arg[%d] = %s\n", i, earg->toChars());
            showCtfeExpr(earg);
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
        {   VarDeclaration *v = istate->vars.tdata()[i];
            if (v == thisvar)
            {   istate->vars.tdata()[i] = NULL;
                break;
            }
        }
    }

    /* Save the values of the local variables used
     */
    Expressions valueSaves;
    if (istate)
    {
        //printf("saving local variables...\n");
        valueSaves.setDim(istate->vars.dim);
        for (size_t i = 0; i < istate->vars.dim; i++)
        {   VarDeclaration *v = istate->vars.tdata()[i];
            bool isParentVar = false;
            /* Nested functions only restore their own local variables
             * (not variables in the parent function)
             */
            if (v && (!isNested() || v->parent == this))
            {
                //printf("\tsaving [%d] %s = %s\n", i, v->toChars(), v->getValue() ? v->getValue()->toChars() : "");
                valueSaves.tdata()[i] = v->getValue();
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
    assert(e != EXP_CONTINUE_INTERPRET && e != EXP_BREAK_INTERPRET);

    /* Restore the parameter values
     */
    for (size_t i = 0; i < dim; i++)
    {
        VarDeclaration *v = parameters->tdata()[i];
        v->setValueWithoutChecking(vsave.tdata()[i]);
    }
    /* Clear __result. (Bug 6049).
     */
    if (vresult)
        vresult->setValueNull();

    if (istate)
    {
        /* Restore the variable values
         */
        //printf("restoring local variables...\n");
        for (size_t i = 0; i < istate->vars.dim; i++)
        {   VarDeclaration *v = istate->vars.tdata()[i];
            /* Nested functions only restore their own local variables
             * (not variables in the parent function)
             */
            if (v && (!isNested() || v->parent == this))
            {   v->setValueWithoutChecking(valueSaves.tdata()[i]);
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
        Expression *e = exp->interpret(istate, ctfeNeedNothing);
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
        {   Statement *s = statements->tdata()[i];

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
        {   Statement *s = statements->tdata()[i];

            e = s->interpret(istate);
            if (e == EXP_CANT_INTERPRET)
                break;
            if (e == EXP_CONTINUE_INTERPRET)
            {
                if (istate->gotoTarget && istate->gotoTarget != this)
                    break; // continue at higher level
                istate->gotoTarget = NULL;
                e = NULL;
                continue;
            }
            if (e == EXP_BREAK_INTERPRET)
            {
                if (!istate->gotoTarget || istate->gotoTarget == this)
                {
                    istate->gotoTarget = NULL;
                    e = NULL;
                } // else break at a higher level
                break;
            }
            if (e)
                break;
        }
    }
    return e;
}

// For CTFE only. Returns true if 'e' is TRUE or a non-null pointer.
int isTrueBool(Expression *e)
{
    return e->isBool(TRUE) || (e->type->ty == Tpointer && e->op != TOKnull);
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
        if (isTrueBool(e))
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

Expression *resolveSlice(Expression *e)
{
    if ( ((SliceExp *)e)->e1->op == TOKnull)
        return ((SliceExp *)e)->e1;
    return Slice(e->type, ((SliceExp *)e)->e1,
        ((SliceExp *)e)->lwr, ((SliceExp *)e)->upr);
}

/* Determine the array length, without interpreting it.
 * e must be an array literal, or a slice
 * It's very wasteful to resolve the slice when we only
 * need the length.
 */
uinteger_t resolveArrayLength(Expression *e)
{
    if (e->op == TOKnull)
        return 0;
    if (e->op == TOKslice)
    {   uinteger_t ilo = ((SliceExp *)e)->lwr->toInteger();
        uinteger_t iup = ((SliceExp *)e)->upr->toInteger();
        return iup - ilo;
    }
    if (e->op == TOKstring)
    {   return ((StringExp *)e)->len;
    }
    if (e->op == TOKarrayliteral)
    {   ArrayLiteralExp *ale = (ArrayLiteralExp *)e;
        return ale->elements ? ale->elements->dim : 0;
    }
    if (e->op == TOKassocarrayliteral)
    {   AssocArrayLiteralExp *ale = (AssocArrayLiteralExp *)e;
        return ale->keys->dim;
    }
    assert(0);
    return 0;
}

// As Equal, but resolves slices before comparing
Expression *ctfeEqual(enum TOK op, Type *type, Expression *e1, Expression *e2)
{
    if (e1->op == TOKslice)
        e1 = resolveSlice(e1);
    if (e2->op == TOKslice)
        e2 = resolveSlice(e2);
    return Equal(op, type, e1, e2);
}


void scrubArray(Expressions *elems);

/* All results destined for use outside of CTFE need to have their CTFE-specific
 * features removed.
 * In particular, all slices must be resolved.
 */
Expression *scrubReturnValue(Expression *e)
{
    if (e->op == TOKslice)
    {
        e = resolveSlice(e);
    }
    if (e->op == TOKstructliteral)
    {
        StructLiteralExp *se = (StructLiteralExp *)e;
        scrubArray(se->elements);
    }
    if (e->op == TOKarrayliteral)
    {
        scrubArray(((ArrayLiteralExp *)e)->elements);
    }
    if (e->op == TOKassocarrayliteral)
    {
        AssocArrayLiteralExp *aae = (AssocArrayLiteralExp *)e;
        scrubArray(aae->keys);
        scrubArray(aae->values);
    }
    return e;
}

// Scrub all members of an array
void scrubArray(Expressions *elems)
{
    for (size_t i = 0; i < elems->dim; i++)
    {
        Expression *m = elems->tdata()[i];
        if (!m)
            continue;
        m = scrubReturnValue(m);
        elems->tdata()[i] = m;
    }
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
        {   // We need to return an lvalue
            Expression *e = exp->interpret(istate, ctfeNeedLvalue);
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
    // We need to treat pointers specially, because TOKsymoff can be used to
    // return a value OR a pointer
    Expression *e;
    if ((exp->type->ty == Tpointer && exp->type->nextOf()->ty != Tfunction))
        e = exp->interpret(istate, ctfeNeedLvalue);
    else
        e = exp->interpret(istate);
    if (e == EXP_CANT_INTERPRET)
        return e;
    if (!istate->caller)
    {
        e = scrubReturnValue(e);
        if (e == EXP_CANT_INTERPRET)
            return e;
    }
    else if (needToCopyLiteral(exp))
        e = copyLiteral(e);
#if LOGASSIGN
    printf("RETURN %s\n", loc.toChars());
    showCtfeExpr(e);
#endif
    return e;
}

Expression *BreakStatement::interpret(InterState *istate)
{
#if LOG
    printf("BreakStatement::interpret()\n");
#endif
    START()
    if (ident)
    {   LabelDsymbol *label = istate->fd->searchLabel(ident);
        assert(label && label->statement);
        Statement *s = label->statement;
        if (s->isLabelStatement())
            s = s->isLabelStatement()->statement;
        if (s->isScopeStatement())
            s = s->isScopeStatement()->statement;
        istate->gotoTarget = s;
        return EXP_BREAK_INTERPRET;
    }
    else
    {
        istate->gotoTarget = NULL;
        return EXP_BREAK_INTERPRET;
    }
}

Expression *ContinueStatement::interpret(InterState *istate)
{
#if LOG
    printf("ContinueStatement::interpret()\n");
#endif
    START()
    if (ident)
    {   LabelDsymbol *label = istate->fd->searchLabel(ident);
        assert(label && label->statement);
        Statement *s = label->statement;
        if (s->isLabelStatement())
            s = s->isLabelStatement()->statement;
        if (s->isScopeStatement())
            s = s->isScopeStatement()->statement;
        istate->gotoTarget = s;
        return EXP_CONTINUE_INTERPRET;
    }
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
        {
            if (!istate->gotoTarget || istate->gotoTarget == this)
            {
                istate->gotoTarget = NULL;
                e = NULL;
            } // else break at a higher level
            return e;
        }
        if (e == EXP_CONTINUE_INTERPRET)
            if (!istate->gotoTarget || istate->gotoTarget == this)
            {
                goto Lcontinue;
            }
            else // else continue at a higher level
                return e;
        if (e)
            return e;
    }

    while (1)
    {
        e = body ? body->interpret(istate) : NULL;
        if (e == EXP_CANT_INTERPRET)
            break;
        if (e == EXP_BREAK_INTERPRET)
        {
            if (!istate->gotoTarget || istate->gotoTarget == this)
            {
                istate->gotoTarget = NULL;
                e = NULL;
            } // else break at a higher level
            break;
        }
        if (e && e != EXP_CONTINUE_INTERPRET)
            break;
        if (istate->gotoTarget && istate->gotoTarget != this)
            break; // continue at a higher level

    Lcontinue:
        istate->gotoTarget = NULL;
        e = condition->interpret(istate);
        if (e == EXP_CANT_INTERPRET)
            break;
        if (!e->isConst())
        {   e = EXP_CANT_INTERPRET;
            break;
        }
        if (isTrueBool(e))
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
        {
            if (!istate->gotoTarget || istate->gotoTarget == this)
            {
                istate->gotoTarget = NULL;
                return NULL;
            } // else break at a higher level
        }
        if (e == EXP_CONTINUE_INTERPRET)
        {
            if (!istate->gotoTarget || istate->gotoTarget == this)
            {
                istate->gotoTarget = NULL;
                goto Lcontinue;
            } // else continue at a higher level
        }
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
        if (isTrueBool(e))
        {
        Lhead:
            e = body ? body->interpret(istate) : NULL;
            if (e == EXP_CANT_INTERPRET)
                break;
            if (e == EXP_BREAK_INTERPRET)
            {
                if (!istate->gotoTarget || istate->gotoTarget == this)
                {
                    istate->gotoTarget = NULL;
                    e = NULL;
                } // else break at a higher level
                break;
            }
            if (e && e != EXP_CONTINUE_INTERPRET)
                break;
            if (istate->gotoTarget && istate->gotoTarget != this)
                break; // continue at a higher level
        Lcontinue:
            istate->gotoTarget = NULL;
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
            {
                if (!istate->gotoTarget || istate->gotoTarget == this)
                {
                    istate->gotoTarget = NULL;
                    e = NULL;
                } // else break at a higher level
                break;
            }
            if (e == EXP_CONTINUE_INTERPRET)
            {
                if (istate->gotoTarget && istate->gotoTarget != this)
                    break; // continue at higher level
                istate->gotoTarget = NULL;
                e = NULL;
            }
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
            {
                if (!istate->gotoTarget || istate->gotoTarget == this)
                {
                    istate->gotoTarget = NULL;
                    e = NULL;
                } // else break at a higher level
                break;
            }
            if (e == EXP_CONTINUE_INTERPRET)
            {
                if (istate->gotoTarget && istate->gotoTarget != this)
                    break; // continue at higher level
                istate->gotoTarget = NULL;
                e = NULL;
            }
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
Expression *ForeachRangeStatement::interpret(InterState *istate)
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
            {
                if (!istate->gotoTarget || istate->gotoTarget == this)
                {
                    istate->gotoTarget = NULL;
                    e = NULL;
                } // else break at a higher level
                break;
            }
            if (e == EXP_CONTINUE_INTERPRET
                && istate->gotoTarget && istate->gotoTarget != this)
                break; // continue at higher level
            if (e == NULL || e == EXP_CONTINUE_INTERPRET)
            {   e = Add(key->value->type, key->value, new IntegerExp(loc, 1, key->value->type));
                istate->gotoTarget = NULL;
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
            {
                if (!istate->gotoTarget || istate->gotoTarget == this)
                {
                    istate->gotoTarget = NULL;
                    e = NULL;
                } // else break at a higher level
                break;
            }
            if (e == EXP_CONTINUE_INTERPRET)
            {
                if (istate->gotoTarget && istate->gotoTarget != this)
                    break; // continue at higher level
                istate->gotoTarget = NULL;
            }
        } while (e == NULL || e == EXP_CONTINUE_INTERPRET);
    }
    key->value = keysave;
    return e;
#endif
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
        {
            if (!istate->gotoTarget || istate->gotoTarget == this)
            {
                istate->gotoTarget = NULL;
                return NULL;
            } // else break at a higher level
        }
        return e;
    }


    Expression *econdition = condition->interpret(istate);
    if (econdition == EXP_CANT_INTERPRET)
        return EXP_CANT_INTERPRET;
    if (econdition->op == TOKslice)
        econdition = resolveSlice(econdition);

    Statement *s = NULL;
    if (cases)
    {
        for (size_t i = 0; i < cases->dim; i++)
        {
            CaseStatement *cs = cases->tdata()[i];
            e = ctfeEqual(TOKequal, Type::tint32, econdition, cs->exp);
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
    {
        if (!istate->gotoTarget || istate->gotoTarget == this)
        {
            istate->gotoTarget = NULL;
            e = NULL;
        } // else break at a higher level
    }
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

#if DMDV2
Expression *ImportStatement::interpret(InterState *istate)
{
#if LOG
    printf("ImportStatement::interpret()\n");
#endif
    START();
    return NULL;
}
#endif

/******************************** Expression ***************************/

Expression *Expression::interpret(InterState *istate, CtfeGoal goal)
{
#if LOG
    printf("Expression::interpret() %s\n", toChars());
    printf("type = %s\n", type->toChars());
    dump(0);
#endif
    error("Cannot interpret %s at compile time", toChars());
    return EXP_CANT_INTERPRET;
}

Expression *ThisExp::interpret(InterState *istate, CtfeGoal goal)
{
    if (istate && istate->localThis && istate->localThis->op == TOKstructliteral)
        return istate->localThis;
    if (istate && istate->localThis)
        return istate->localThis->interpret(istate, goal);
    error("value of 'this' is not known at compile time");
    return EXP_CANT_INTERPRET;
}

Expression *NullExp::interpret(InterState *istate, CtfeGoal goal)
{
    return this;
}

Expression *IntegerExp::interpret(InterState *istate, CtfeGoal goal)
{
#if LOG
    printf("IntegerExp::interpret() %s\n", toChars());
#endif
    return this;
}

Expression *RealExp::interpret(InterState *istate, CtfeGoal goal)
{
#if LOG
    printf("RealExp::interpret() %s\n", toChars());
#endif
    return this;
}

Expression *ComplexExp::interpret(InterState *istate, CtfeGoal goal)
{
    return this;
}

Expression *StringExp::interpret(InterState *istate, CtfeGoal goal)
{
#if LOG
    printf("StringExp::interpret() %s\n", toChars());
#endif
    /* Since we are using StringExps as reference types for char[] arrays,
     * we need to dup them if there's any chance they'll be modified.
     * For efficiency, we try to only dup when necessary.
     */
    // Fixed-length char arrays always get duped later anyway.
    if (type->ty == Tsarray)
        return this;
    /* String literals are normally immutable, so we don't need to dup them
     * In D2, we can detect attempts to write to read-only literals.
     * For D1, we could be pessimistic, and always dup.
     * But since it fails only when there has been an explicit cast, and any
     * such function would give different results at runtime anyway (eg, it
     * may crash), it hardly seems worth the massive performance hit.
     */
#if DMDV2
    if (!(((TypeNext *)type)->next->mod & (MODconst | MODimmutable)))
    {   // It seems this happens only when there has been an explicit cast
        error("cannot cast a read-only string literal to mutable in CTFE");
        return EXP_CANT_INTERPRET;
    }
#endif
    return this;
}

Expression *FuncExp::interpret(InterState *istate, CtfeGoal goal)
{
#if LOG
    printf("FuncExp::interpret() %s\n", toChars());
#endif
    return this;
}

Expression *SymOffExp::interpret(InterState *istate, CtfeGoal goal)
{
#if LOG
    printf("SymOffExp::interpret() %s\n", toChars());
#endif
    if (var->isFuncDeclaration() && offset == 0)
    {
        return this;
    }
    if (type->ty != Tpointer)
    {   // Probably impossible
        error("Cannot interpret %s at compile time", toChars());
        return EXP_CANT_INTERPRET;
    }
    Type *pointee = ((TypePointer *)type)->next;
    Expression *val = getVarExp(loc, istate, var, goal);
    if (val->type->ty == Tarray || val->type->ty == Tsarray)
    {
        // Check for unsupported type painting operations
        Type *elemtype = ((TypeArray *)(val->type))->next;
        if (
#if DMDV2
        elemtype->castMod(0) != pointee->castMod(0)
#else
        elemtype != pointee
#endif
        && !(elemtype->isintegral() && pointee->isintegral()
            && elemtype->size() == pointee->size()))
        {
            error("reinterpreting cast from %s to %s is not supported in CTFE",
                val->type->toChars(), type->toChars());
            return EXP_CANT_INTERPRET;
        }

        TypeArray *tar = (TypeArray *)val->type;
        dinteger_t sz = pointee->size();
        dinteger_t indx = offset/sz;
        assert(sz * indx == offset);
        Expression *aggregate = NULL;
        if (val->op == TOKarrayliteral || val->op == TOKstring)
            aggregate = val;
        else if (val->op == TOKslice)
        {
            aggregate = ((SliceExp *)val)->e1;
            Expression *lwr = ((SliceExp *)val)->lwr->interpret(istate);
            indx += lwr->toInteger();
        }
        if (aggregate)
        {
            IntegerExp *ofs = new IntegerExp(loc, indx, Type::tsize_t);
            IndexExp *ie = new IndexExp(loc, aggregate, ofs);
            ie->type = type;
            return ie;
        }
    }
    else if (offset == 0 &&
#if DMDV2
        pointee->castMod(0) == var->type->castMod(0)
#else
        pointee == var->type
#endif
        )
    {
        if (goal == ctfeNeedLvalue || goal == ctfeNeedLvalueRef)
        {
            VarExp *ve = new VarExp(loc, var);
            ve->type = type;
            return ve;
        }
        Expression *e = getVarExp(loc, istate, var, goal);
        e = new AddrExp(loc, e);
        e->type = type;
        return e;
    }

    error("Cannot convert &%s to %s at compile time", var->type->toChars(), type->toChars());
    return EXP_CANT_INTERPRET;
}

Expression *AddrExp::interpret(InterState *istate, CtfeGoal goal)
{
#if LOG
    printf("AddrExp::interpret() %s\n", toChars());
#endif
    // For reference types, we need to return an lvalue ref.
    TY tb = e1->type->toBasetype()->ty;
    bool needRef = (tb == Tarray || tb == Taarray || tb == Tclass);
    Expression *e = e1->interpret(istate, needRef ? ctfeNeedLvalueRef : ctfeNeedLvalue);
    if (e == EXP_CANT_INTERPRET)
        return e;
    // Return a simplified address expression
    e = new AddrExp(loc, e);
    e->type = type;
    return e;
}

Expression *DelegateExp::interpret(InterState *istate, CtfeGoal goal)
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
            if (v->type->ty == Tpointer)
                break;
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

Expression *getVarExp(Loc loc, InterState *istate, Declaration *d, CtfeGoal goal)
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
            if (e && (e->op == TOKconstruct || e->op == TOKblit))
            {   AssignExp *ae = (AssignExp *)e;
                e = ae->e2;
                v->inuse++;
                e = e->interpret(istate, ctfeNeedAnyValue);
                v->inuse--;
                if (e == EXP_CANT_INTERPRET)
                    return e;
                e->type = v->type;
            }
            else
            {
                if (e && !e->type)
                    e->type = v->type;
                if (e)
                    e = e->interpret(istate, ctfeNeedAnyValue);
            }
            if (e && e != EXP_CANT_INTERPRET)
                v->setValueWithoutChecking(e);
        }
        else if (v->isCTFE() && !v->getValue())
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
        else if (!v->isDataseg() && !v->isCTFE() && !istate)
        {   error(loc, "variable %s cannot be read at compile time", v->toChars());
            return EXP_CANT_INTERPRET;
        }
        else
        {   e = v->getValue();
            if (!e && !v->isCTFE() && v->isDataseg())
            {   error(loc, "static variable %s cannot be read at compile time", v->toChars());
                e = EXP_CANT_INTERPRET;
            }
            else if (!e)
                error(loc, "variable %s is used before initialization", v->toChars());
            else if (e == EXP_CANT_INTERPRET)
                return e;
            else if ((goal == ctfeNeedLvalue)
                    || e->op == TOKstring || e->op == TOKstructliteral || e->op == TOKarrayliteral
                    || e->op == TOKassocarrayliteral || e->op == TOKslice
                    || e->type->toBasetype()->ty == Tpointer)
                return e; // it's already an Lvalue
            else
                e = e->interpret(istate, goal);
        }
        if (!e)
            e = EXP_CANT_INTERPRET;
    }
    else if (s)
    {   // Struct static initializers, for example
        if (s->dsym->toInitializer() == s->sym)
        {   Expressions *exps = new Expressions();
            e = new StructLiteralExp(loc, s->dsym, exps);
            e = e->semantic(NULL);
            if (e->op == TOKerror)
                e = EXP_CANT_INTERPRET;
        }
        else
            error(loc, "cannot interpret symbol %s at compile time", v->toChars());
    }
    else
        error(loc, "cannot interpret declaration %s at compile time", d->toChars());
    return e;
}

Expression *VarExp::interpret(InterState *istate, CtfeGoal goal)
{
#if LOG
    printf("VarExp::interpret() %s\n", toChars());
#endif
    if (goal == ctfeNeedLvalueRef)
    {
        // If it is a reference, return the thing it's pointing to.
        VarDeclaration *v = var->isVarDeclaration();
        if (v && v->getValue() && (v->storage_class & (STCref | STCout)))
            return v->getValue();
        if (v && !v->isDataseg() && !v->isCTFE() && !istate)
        {   error("variable %s cannot be referenced at compile time", v->toChars());
            return EXP_CANT_INTERPRET;
        }
        else if (v && !v->getValue() && !v->isCTFE() && v->isDataseg())
        {   error("static variable %s cannot be referenced at compile time", v->toChars());
                return EXP_CANT_INTERPRET;
        }
        return this;
    }
    Expression *e = getVarExp(loc, istate, var, goal);
    // A VarExp may include an implicit cast. It must be done explicitly.
    if (e != EXP_CANT_INTERPRET)
        e = paintTypeOntoLiteral(type, e);
    return e;
}

Expression *DeclarationExp::interpret(InterState *istate, CtfeGoal goal)
{
#if LOG
    printf("DeclarationExp::interpret() %s\n", toChars());
#endif
    Expression *e;
    VarDeclaration *v = declaration->isVarDeclaration();
    if (v)
    {
        if (v->getValue())
        {
            addVarToInterstate(istate, v);
            v->setValueNull();
        }
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

Expression *TupleExp::interpret(InterState *istate, CtfeGoal goal)
{
#if LOG
    printf("TupleExp::interpret() %s\n", toChars());
#endif
    Expressions *expsx = NULL;

    for (size_t i = 0; i < exps->dim; i++)
    {   Expression *e = exps->tdata()[i];
        Expression *ex;

        ex = e->interpret(istate);
        if (ex == EXP_CANT_INTERPRET)
        {   delete expsx;
            return ex;
        }

        // A tuple of assignments can contain void (Bug 5676).
        if (goal == ctfeNeedNothing)
            continue;
        if (ex == EXP_VOID_INTERPRET)
        {
            error("ICE: void element %s in tuple", e->toChars());
            assert(0);
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
                    expsx->tdata()[j] = exps->tdata()[j];
                }
            }
            expsx->tdata()[i] = ex;
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

Expression *ArrayLiteralExp::interpret(InterState *istate, CtfeGoal goal)
{   Expressions *expsx = NULL;

#if LOG
    printf("ArrayLiteralExp::interpret() %s\n", toChars());
#endif
    if (elements)
    {
        for (size_t i = 0; i < elements->dim; i++)
        {   Expression *e = elements->tdata()[i];
            Expression *ex;

            if (e->op == TOKindex)  // segfault bug 6250
                assert( ((IndexExp*)e)->e1 != this);
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
                        expsx->tdata()[j] = elements->tdata()[j];
                    }
                }
                expsx->tdata()[i] = ex;
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
#if DMDV2
    if (((TypeNext *)type)->next->mod & (MODconst | MODimmutable))
    {   // If it's immutable, we don't need to dup it
        return this;
    }
#endif
    return copyLiteral(this);

Lerror:
    if (expsx)
        delete expsx;
    error("cannot interpret array literal");
    return EXP_CANT_INTERPRET;
}

Expression *AssocArrayLiteralExp::interpret(InterState *istate, CtfeGoal goal)
{   Expressions *keysx = keys;
    Expressions *valuesx = values;

#if LOG
    printf("AssocArrayLiteralExp::interpret() %s\n", toChars());
#endif
    for (size_t i = 0; i < keys->dim; i++)
    {   Expression *ekey = keys->tdata()[i];
        Expression *evalue = values->tdata()[i];
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
            keysx->tdata()[i] = ex;
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
            valuesx->tdata()[i] = ex;
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
    {   Expression *ekey = keysx->tdata()[i - 1];
        if (ekey->op == TOKslice)
            ekey = resolveSlice(ekey);
        for (size_t j = i; j < keysx->dim; j++)
        {   Expression *ekey2 = keysx->tdata()[j];
            Expression *ex = ctfeEqual(TOKequal, Type::tbool, ekey, ekey2);
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

Expression *StructLiteralExp::interpret(InterState *istate, CtfeGoal goal)
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
        {   Expression *e = elements->tdata()[i];
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
                        expsx->tdata()[j] = elements->tdata()[j];
                    }
                }
                expsx->tdata()[i] = ex;
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
    return copyLiteral(this);
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
         elements->tdata()[i] = elem;
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
    for (size_t elemi=0; elemi<dim; ++elemi)
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
    se->sz = sz;
    se->committed = true;
    return se;
}

// Create an array literal of type 'newtype' with dimensions given by
// 'arguments'[argnum..$]
Expression *recursivelyCreateArrayLiteral(Type *newtype, InterState *istate,
    Expressions *arguments, int argnum)
{
    Expression *lenExpr = ((arguments->tdata()[argnum]))->interpret(istate);
    if (lenExpr == EXP_CANT_INTERPRET)
        return EXP_CANT_INTERPRET;
    size_t len = (size_t)(lenExpr->toInteger());
    Type *elemType = ((TypeArray *)newtype)->next;
    if (elemType->ty == Tarray)
    {
        assert(argnum < arguments->dim - 1);
        Expression *elem = recursivelyCreateArrayLiteral(elemType, istate,
            arguments, argnum + 1);
        if (elem == EXP_CANT_INTERPRET)
            return elem;

        Expressions *elements = new Expressions();
        elements->setDim(len);
        for (size_t i = 0; i < len; i++)
             elements->tdata()[i] = copyLiteral(elem);
        ArrayLiteralExp *ae = new ArrayLiteralExp(0, elements);
        ae->type = newtype;
        return ae;
    }
    assert(argnum == arguments->dim - 1);
    if (elemType->ty == Tchar || elemType->ty == Twchar
        || elemType->ty == Tdchar)
        return createBlockDuplicatedStringLiteral(newtype,
            (unsigned)(elemType->defaultInitLiteral()->toInteger()),
            len, elemType->size());
    return createBlockDuplicatedArrayLiteral(newtype,
        elemType->defaultInitLiteral(),
        len);
}

Expression *NewExp::interpret(InterState *istate, CtfeGoal goal)
{
#if LOG
    printf("NewExp::interpret() %s\n", toChars());
#endif
    if (newtype->ty == Tarray && arguments)
        return recursivelyCreateArrayLiteral(newtype, istate, arguments, 0);

    if (newtype->toBasetype()->ty == Tstruct)
    {
        Expression *se = newtype->defaultInitLiteral();
#if DMDV2
        if (member)
        {
            int olderrors = global.errors;
            member->interpret(istate, arguments, se);
            if (olderrors != global.errors)
            {
                error("cannot evaluate %s at compile time", toChars());
                return EXP_CANT_INTERPRET;
            }
        }
#else   // The above code would fail on D1 because it doesn't use STRUCTTHISREF,
        // but that's OK because D1 doesn't have struct constructors anyway.
        assert(!member);
#endif
        Expression *e = new AddrExp(loc, se);
        e->type = type;
        return e;
    }
    if (newtype->ty == Tclass)
    {
        error("classes are not yet supported in CTFE");
        return EXP_CANT_INTERPRET;
    }
    error("Cannot interpret %s at compile time", toChars());
    return EXP_CANT_INTERPRET;
}

Expression *UnaExp::interpretCommon(InterState *istate,  CtfeGoal goal, Expression *(*fp)(Type *, Expression *))
{   Expression *e;
    Expression *e1;

#if LOG
    printf("UnaExp::interpretCommon() %s\n", toChars());
#endif
    e1 = this->e1->interpret(istate);
    if (e1 == EXP_CANT_INTERPRET)
        goto Lcant;
    e = (*fp)(type, e1);
    return e;

Lcant:
    return EXP_CANT_INTERPRET;
}

#define UNA_INTERPRET(op) \
Expression *op##Exp::interpret(InterState *istate, CtfeGoal goal)  \
{                                                                  \
    return interpretCommon(istate, goal, &op);                     \
}

UNA_INTERPRET(Neg)
UNA_INTERPRET(Com)
UNA_INTERPRET(Not)
UNA_INTERPRET(Bool)

Expression *getAggregateFromPointer(Expression *e, dinteger_t *ofs)
{
    *ofs = 0;
    if (e->op == TOKaddress)
        e = ((AddrExp *)e)->e1;
    if (e->op == TOKindex)
    {
        IndexExp *ie = (IndexExp *)e;
        // Note that each AA element is part of its own memory block
        if ((ie->e1->type->ty == Tarray || ie->e1->type->ty == Tsarray
            || ie->e1->op == TOKstring || ie->e1->op==TOKarrayliteral) &&
            ie->e2->op == TOKint64)
        {
            *ofs = ie->e2->toInteger();
            return ie->e1;
        }
    }
    return e;
}

// return e1 - e2 as an integer, or error if not possible
Expression *pointerDifference(Loc loc, Type *type, Expression *e1, Expression *e2)
{
    dinteger_t ofs1, ofs2;
    Expression *agg1 = getAggregateFromPointer(e1, &ofs1);
    Expression *agg2 = getAggregateFromPointer(e2, &ofs2);
    if (agg1 == agg2)
    {
        Type *pointee = ((TypePointer *)agg1->type)->next;
        dinteger_t sz = pointee->size();
        return new IntegerExp(loc, (ofs1-ofs2)*sz, type);
    }
    else if (agg1->op == TOKstring && agg2->op == TOKstring)
    {
        if (((StringExp *)agg1)->string == ((StringExp *)agg2)->string)
        {
        Type *pointee = ((TypePointer *)agg1->type)->next;
        dinteger_t sz = pointee->size();
        return new IntegerExp(loc, (ofs1-ofs2)*sz, type);
        }
    }
#if LOGASSIGN
    printf("FAILED POINTER DIFF\n");
    showCtfeExpr(agg1);
    showCtfeExpr(agg2);
#endif
    error(loc, "%s - %s cannot be interpreted at compile time: cannot subtract "
        "pointers to two different memory blocks",
        e1->toChars(), e2->toChars());
    return EXP_CANT_INTERPRET;
}

// Return eptr op e2, where eptr is a pointer, e2 is an integer,
// and op is TOKadd or TOKmin
Expression *pointerArithmetic(Loc loc, enum TOK op, Type *type,
    Expression *eptr, Expression *e2)
{
    dinteger_t ofs1, ofs2;
    if (eptr->op == TOKaddress)
        eptr = ((AddrExp *)eptr)->e1;
    Expression *agg1 = getAggregateFromPointer(eptr, &ofs1);
    if (agg1->op != TOKstring && agg1->op != TOKarrayliteral)
    {
        error(loc, "cannot perform pointer arithmetic on non-arrays at compile time");
        return EXP_CANT_INTERPRET;
    }
    ofs2 = e2->toInteger();
    Type *pointee = ((TypePointer *)agg1->type)->next;
    dinteger_t sz = pointee->size();
    Expression *dollar = ArrayLength(Type::tsize_t, agg1);
    assert(dollar != EXP_CANT_INTERPRET);
    dinteger_t len = dollar->toInteger();

    Expression *val = agg1;
    TypeArray *tar = (TypeArray *)val->type;
    dinteger_t indx = ofs1;
    if (op == TOKadd || op == TOKaddass || op == TOKplusplus)
        indx = indx + ofs2/sz;
    else if (op == TOKmin || op == TOKminass || op == TOKminusminus)
        indx -= ofs2/sz;
    else
    {
        error(loc, "CTFE Internal compiler error: bad pointer operation");
        return EXP_CANT_INTERPRET;
    }
    if (val->op != TOKarrayliteral && val->op != TOKstring)
    {
        error(loc, "CTFE Internal compiler error: pointer arithmetic %s", val->toChars());
        return EXP_CANT_INTERPRET;
    }
    if (indx < 0 || indx > len)
    {
        error(loc, "cannot assign pointer to index %jd inside memory block [0..%jd]", indx, len);
        return EXP_CANT_INTERPRET;
    }

    IntegerExp *ofs = new IntegerExp(loc, indx, Type::tsize_t);
    IndexExp *ie = new IndexExp(loc, val, ofs);
    ie->type = type;
    return ie;
}

typedef Expression *(*fp_t)(Type *, Expression *, Expression *);

Expression *BinExp::interpretCommon(InterState *istate, CtfeGoal goal, fp_t fp)
{   Expression *e;
    Expression *e1;
    Expression *e2;

#if LOG
    printf("BinExp::interpretCommon() %s\n", toChars());
#endif
    if (this->e1->type->ty == Tpointer && this->e2->type->ty == Tpointer && op == TOKmin)
    {
        e1 = this->e1->interpret(istate, ctfeNeedLvalue);
        e2 = this->e2->interpret(istate, ctfeNeedLvalue);
        if (e1 == EXP_CANT_INTERPRET || e2 == EXP_CANT_INTERPRET)
            return EXP_CANT_INTERPRET;
        return pointerDifference(loc, type, e1, e2);
    }
    if (this->e1->type->ty == Tpointer && this->e2->type->isintegral())
    {
        e1 = this->e1->interpret(istate, ctfeNeedLvalue);
        e2 = this->e2->interpret(istate);
        if (e1 == EXP_CANT_INTERPRET || e2 == EXP_CANT_INTERPRET)
            return EXP_CANT_INTERPRET;
        return pointerArithmetic(loc, op, type, e1, e2);
    }
    if (this->e2->type->ty == Tpointer && this->e1->type->isintegral() && op==TOKadd)
    {
        e2 = this->e2->interpret(istate, ctfeNeedLvalue);
        e1 = this->e1->interpret(istate);
        if (e1 == EXP_CANT_INTERPRET || e2 == EXP_CANT_INTERPRET)
            return EXP_CANT_INTERPRET;
        return pointerArithmetic(loc, op, type, e2, e1);
    }
    if (this->e1->type->ty == Tpointer || this->e2->type->ty == Tpointer)
    {
        error("pointer expression %s cannot be interpreted at compile time", toChars());
        return EXP_CANT_INTERPRET;
    }
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
    if (e == EXP_CANT_INTERPRET)
        error("%s cannot be interpreted at compile time", toChars());
    return e;

Lcant:
    return EXP_CANT_INTERPRET;
}

#define BIN_INTERPRET(op) \
Expression *op##Exp::interpret(InterState *istate, CtfeGoal goal) \
{                                                                 \
    return interpretCommon(istate, goal, &op);                    \
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

// Return EXP_CANT_INTERPRET if they point to independent memory blocks
Expression *comparePointers(Loc loc, enum TOK op, Type *type, Expression *e1, Expression *e2)
{
    dinteger_t ofs1, ofs2;
    Expression *agg1 = getAggregateFromPointer(e1, &ofs1);
    Expression *agg2 = getAggregateFromPointer(e2, &ofs2);
    if (agg1 == agg2 ||
        (agg1->op == TOKstring && agg2->op == TOKstring &&
        ((StringExp *)agg1)->string == ((StringExp *)agg2)->string))

    {
        dinteger_t cm = ofs1 - ofs2;
        dinteger_t n;
        dinteger_t zero = 0;
        switch(op)
        {
        case TOKlt:          n = (ofs1 <  ofs2); break;
        case TOKle:          n = (ofs1 <= ofs2); break;
        case TOKgt:          n = (ofs1 >  ofs2); break;
        case TOKge:          n = (ofs1 >= ofs2); break;
        case TOKidentity:
        case TOKequal:       n = (ofs1 == ofs2); break;
        case TOKnotidentity:
        case TOKnotequal:    n = (ofs1 != ofs2); break;
        default:
            assert(0);
        }
        return new IntegerExp(loc, n, type);
    }
    int cmp;
    if (e1->op == TOKnull)
    {
        cmp = (e2->op == TOKnull);
    }
    else if (e2->op == TOKnull)
    {
        cmp = 0;
    }
    else
    {
        switch(op)
        {
        case TOKidentity:
        case TOKequal:
        case TOKnotidentity: // 'cmp' gets inverted below
        case TOKnotequal:
            cmp = 0;
            break;
        default:
            return EXP_CANT_INTERPRET;
        }
    }
    if (op == TOKnotidentity || op == TOKnotequal)
        cmp ^= 1;
    return new IntegerExp(loc, cmp, type);
}

Expression *BinExp::interpretCommon2(InterState *istate, CtfeGoal goal, fp2_t fp)
{   Expression *e;
    Expression *e1;
    Expression *e2;

#if LOG
    printf("BinExp::interpretCommon2() %s\n", toChars());
#endif
    if (this->e1->type->ty == Tpointer && this->e2->type->ty == Tpointer)
    {
        e1 = this->e1->interpret(istate, ctfeNeedLvalue);
        e2 = this->e2->interpret(istate, ctfeNeedLvalue);
        if (e1 == EXP_CANT_INTERPRET || e2 == EXP_CANT_INTERPRET)
            return EXP_CANT_INTERPRET;
        e = comparePointers(loc, op, type, e1, e2);
        if (e == EXP_CANT_INTERPRET)
        {
            error("%s and %s point to independent memory blocks and "
                "cannot be compared at compile time", this->e1->toChars(),
                this->e2->toChars());
        }
        return e;
    }
    e1 = this->e1->interpret(istate);
    if (e1 == EXP_CANT_INTERPRET)
        goto Lcant;
    if (e1->op == TOKslice)
        e1 = resolveSlice(e1);

    if (e1->isConst() != 1 &&
        e1->op != TOKnull &&
        e1->op != TOKstring &&
        e1->op != TOKarrayliteral &&
        e1->op != TOKstructliteral)
    {
        error("cannot compare %s at compile time", e1->toChars());
        goto Lcant;
    }

    e2 = this->e2->interpret(istate);
    if (e2 == EXP_CANT_INTERPRET)
        goto Lcant;
    if (e2->op == TOKslice)
        e2 = resolveSlice(e2);
    if (e2->isConst() != 1 &&
        e2->op != TOKnull &&
        e2->op != TOKstring &&
        e2->op != TOKarrayliteral &&
        e2->op != TOKstructliteral)
    {
        error("cannot compare %s at compile time", e2->toChars());
        goto Lcant;
    }
    e = (*fp)(op, type, e1, e2);
    if (e == EXP_CANT_INTERPRET)
        error("%s cannot be interpreted at compile time", toChars());
    return e;

Lcant:
    return EXP_CANT_INTERPRET;
}

#define BIN_INTERPRET2(op) \
Expression *op##Exp::interpret(InterState *istate, CtfeGoal goal)  \
{                                                                  \
    return interpretCommon2(istate, goal, &op);                    \
}

BIN_INTERPRET2(Equal)
BIN_INTERPRET2(Identity)
BIN_INTERPRET2(Cmp)

/* Helper functions for BinExp::interpretAssignCommon
 */

/***************************************
 * Duplicate the elements array, then set field 'indexToChange' = newelem.
 */
Expressions *changeOneElement(Expressions *oldelems, size_t indexToChange, Expression *newelem)
{
    Expressions *expsx = new Expressions();
    expsx->setDim(oldelems->dim);
    for (size_t j = 0; j < expsx->dim; j++)
    {
        if (j == indexToChange)
            expsx->tdata()[j] = newelem;
        else
            expsx->tdata()[j] = oldelems->tdata()[j];
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
            if (v == istate->vars.tdata()[i])
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
        Expression *ekey = aae->keys->tdata()[j];
        Expression *ex = ctfeEqual(TOKequal, Type::tbool, ekey, index);
        if (ex == EXP_CANT_INTERPRET)
            return EXP_CANT_INTERPRET;
        if (ex->isBool(TRUE))
        {   valuesx->tdata()[j] = newval;
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
            case TOKstructliteral:
                return true;
            case TOKstring:
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
                return needToCopyLiteral(((BinExp *)expr)->e1) ||
                    needToCopyLiteral(((BinExp *)expr)->e2);
            case TOKcatass:
                expr = ((BinExp *)expr)->e2;
                continue;
            default:
                return false;
        }
    }
}

Expressions *copyLiteralArray(Expressions *oldelems)
{
    if (!oldelems)
        return oldelems;
    Expressions *newelems = new Expressions();
    newelems->setDim(oldelems->dim);
    for (size_t i = 0; i < oldelems->dim; i++)
        newelems->tdata()[i] = copyLiteral(oldelems->tdata()[i]);
    return newelems;
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
        se2->sz = se->sz;
        return se2;
    }
    else if (e->op == TOKarrayliteral)
    {
        ArrayLiteralExp *ae = (ArrayLiteralExp *)e;
        ArrayLiteralExp *r = new ArrayLiteralExp(e->loc,
            copyLiteralArray(ae->elements));
        r->type = e->type;
        return r;
    }
    else if (e->op == TOKassocarrayliteral)
    {
        AssocArrayLiteralExp *aae = (AssocArrayLiteralExp *)e;
        AssocArrayLiteralExp *r = new AssocArrayLiteralExp(e->loc,
            copyLiteralArray(aae->keys), copyLiteralArray(aae->values));
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
            Expression *m = oldelems->tdata()[i];
            // We need the struct definition to detect block assignment
            StructDeclaration *sd = se->sd;
            Dsymbol *s = sd->fields.tdata()[i];
            VarDeclaration *v = s->isVarDeclaration();
            assert(v);
            // If it is a void assignment, use the default initializer
            if (!m)
                m = v->type->defaultInitLiteral(e->loc);
            if (m->op == TOKslice)
                m = resolveSlice(m);
            if ((v->type->ty != m->type->ty) && v->type->ty == Tsarray)
            {
                // Block assignment from inside struct literals
                TypeSArray *tsa = (TypeSArray *)v->type;
                uinteger_t length = tsa->dim->toInteger();
                m = createBlockDuplicatedArrayLiteral(v->type, m, (size_t)length);
            }
            else if (v->type->ty != Tarray) // NOTE: do not copy array references
                m = copyLiteral(m);
            newelems->tdata()[i] = m;
        }
#if DMDV2
        StructLiteralExp *r = new StructLiteralExp(e->loc, se->sd, newelems, se->stype);
#else
        StructLiteralExp *r = new StructLiteralExp(e->loc, se->sd, newelems);
#endif
        r->type = e->type;
        return r;
    }
    else if (e->op == TOKfunction || e->op == TOKdelegate
            || e->op == TOKsymoff || e->op == TOKnull
            || e->op == TOKvar
            || e->op == TOKint64 || e->op == TOKfloat64
            || e->op == TOKchar || e->op == TOKcomplex80)
    {   // Simple value types
        Expression *r = e->syntaxCopy();
        r->type = e->type;
        return r;
    }
    else if (e->type->ty == Tpointer && e->type->nextOf()->ty != Tfunction)
    {   // For pointers, we only do a shallow copy.
        Expression *r;
        if (e->op == TOKaddress)
            r = new AddrExp(e->loc, ((AddrExp *)e)->e1);
        else if (e->op == TOKindex)
            r = new IndexExp(e->loc, ((IndexExp *)e)->e1, ((IndexExp *)e)->e2);
        else if (e->op == TOKdotvar)
            r = new DotVarExp(e->loc, ((DotVarExp *)e)->e1,
                ((DotVarExp *)e)->var
#if DMDV2
                , ((DotVarExp *)e)->hasOverloads
#endif
                );
        else
            assert(0);
        r->type = e->type;
        return r;
    }
    else if (e->op == TOKslice)
    {   // Array slices only do a shallow copy
        Expression *r = new SliceExp(e->loc, ((SliceExp *)e)->e1,
         ((SliceExp *)e)->lwr,  ((SliceExp *)e)->upr);
        r->type = e->type;
        return r;
    }
    else
    {
        e->error("Internal Compiler Error: CTFE literal %s", e->toChars());
        assert(0);
        return e;
    }
}

/* Deal with type painting.
 * Type painting is a major nuisance: we can't just set
 * e->type = type, because that would change the original literal.
 * But, we can't simply copy the literal either, because that would change
 * the values of any pointers.
 */
Expression *paintTypeOntoLiteral(Type *type, Expression *lit)
{
    if (lit->type == type)
        return lit;
    Expression *e;
    if (lit->op == TOKslice)
    {
        SliceExp *se = (SliceExp *)lit;
        e = new SliceExp(lit->loc, se->e1, se->lwr, se->upr);
    }
    else if (lit->op == TOKindex)
    {
        IndexExp *ie = (IndexExp *)lit;
        e = new IndexExp(lit->loc, ie->e1, ie->e2);
    }
    else if (lit->op == TOKarrayliteral)
    {
        ArrayLiteralExp *ae = (ArrayLiteralExp *)lit;
        e = new ArrayLiteralExp(lit->loc, ae->elements);
    }
    else if (lit->op == TOKstring)
    {
        // For strings, we need to introduce another level of indirection
        e = new SliceExp(lit->loc, lit,
            new IntegerExp(0, 0, Type::tsize_t), ArrayLength(Type::tsize_t, lit));
    }
    else if (lit->op == TOKassocarrayliteral)
    {
        AssocArrayLiteralExp *aae = (AssocArrayLiteralExp *)lit;
        e = new AssocArrayLiteralExp(lit->loc, aae->keys, aae->values);
    }
    else
        e = copyLiteral(lit);
    e->type = type;
    return e;
}

/* Set a slice of char array literal 'existingAE' from a string 'newval'.
 * existingAE[firstIndex..firstIndex+newval.length] = newval.
 */
void sliceAssignArrayLiteralFromString(ArrayLiteralExp *existingAE, StringExp *newval, int firstIndex)
{
    size_t newlen =  newval->len;
    size_t sz = newval->sz;
    unsigned char *s = (unsigned char *)newval->string;
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
        existingAE->elements->tdata()[j+firstIndex]
            = new IntegerExp(newval->loc, val, elemType);
    }
}

/* Set a slice of string 'existingSE' from a char array literal 'newae'.
 *   existingSE[firstIndex..firstIndex+newae.length] = newae.
 */
void sliceAssignStringFromArrayLiteral(StringExp *existingSE, ArrayLiteralExp *newae, int firstIndex)
{
    unsigned char *s = (unsigned char *)existingSE->string;
    for (size_t j = 0; j < newae->elements->dim; j++)
    {
        unsigned value = (unsigned)(newae->elements->tdata()[j]->toInteger());
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
}

/* Set a slice of string 'existingSE' from a string 'newstr'.
 *   existingSE[firstIndex..firstIndex+newstr.length] = newstr.
 */
void sliceAssignStringFromString(StringExp *existingSE, StringExp *newstr, int firstIndex)
{
    unsigned char *s = (unsigned char *)existingSE->string;
    size_t sz = existingSE->sz;
    assert(sz == newstr->sz);
    memcpy(s + firstIndex * sz, newstr->string, sz * newstr->len);
}


/* Set dest = src, where both dest and src are container value literals
 * (ie, struct literals, or static arrays (can be an array literal or a string)
 * Assignment is recursively in-place.
 * Purpose: any reference to a member of 'dest' will remain valid after the
 * assignment.
 */
void assignInPlace(Expression *dest, Expression *src)
{
    assert(dest->op == TOKstructliteral || dest->op == TOKarrayliteral ||
        dest->op == TOKstring);
    Expressions *oldelems;
    Expressions *newelems;
    if (dest->op == TOKstructliteral)
    {
        assert(dest->op == src->op);
        oldelems = ((StructLiteralExp *)dest)->elements;
        newelems = ((StructLiteralExp *)src)->elements;
    }
    else if (dest->op == TOKarrayliteral && src->op==TOKarrayliteral)
    {
        oldelems = ((ArrayLiteralExp *)dest)->elements;
        newelems = ((ArrayLiteralExp *)src)->elements;
    }
    else if (dest->op == TOKstring && src->op == TOKstring)
    {
        sliceAssignStringFromString((StringExp *)dest, (StringExp *)src, 0);
        return;
    }
    else if (dest->op == TOKarrayliteral && src->op == TOKstring)
    {
        sliceAssignArrayLiteralFromString((ArrayLiteralExp *)dest, (StringExp *)src, 0);
        return;
    }
    else if (src->op == TOKarrayliteral && dest->op == TOKstring)
    {
        sliceAssignStringFromArrayLiteral((StringExp *)dest, (ArrayLiteralExp *)src, 0);
        return;
    }
    else assert(0);

    assert(oldelems->dim == newelems->dim);

    for (size_t i= 0; i < oldelems->dim; ++i)
    {
        Expression *e = newelems->tdata()[i];
        Expression *o = oldelems->tdata()[i];
        if (e->op == TOKstructliteral)
        {
            assert(o->op == e->op);
            assignInPlace(o, e);
        }
        else if (e->type->ty == Tsarray && o->type->ty == Tsarray)
        {
            assignInPlace(o, e);
        }
        else
        {
            oldelems->tdata()[i] = newelems->tdata()[i];
        }
    }
}

void recursiveBlockAssign(ArrayLiteralExp *ae, Expression *val, bool wantRef)
{
    assert( ae->type->ty == Tsarray || ae->type->ty == Tarray);
#if DMDV2
    Type *desttype = ((TypeArray *)ae->type)->next->castMod(0);
    bool directblk = (val->type->toBasetype()->castMod(0)) == desttype;
#else
    Type *desttype = ((TypeArray *)ae->type)->next;
    bool directblk = (val->type->toBasetype()) == desttype;
#endif

    bool cow = !(val->op == TOKstructliteral || val->op == TOKarrayliteral
        || val->op == TOKstring);

    for (size_t k = 0; k < ae->elements->dim; k++)
    {
        if (!directblk && ae->elements->tdata()[k]->op == TOKarrayliteral)
        {
            recursiveBlockAssign((ArrayLiteralExp *)ae->elements->tdata()[k], val, wantRef);
        }
        else
        {
            if (wantRef || cow)
                ae->elements->tdata()[k] = val;
            else
                assignInPlace(ae->elements->tdata()[k], val);
        }
    }
}


Expression *BinExp::interpretAssignCommon(InterState *istate, CtfeGoal goal, fp_t fp, int post)
{
#if LOG
    printf("BinExp::interpretAssignCommon() %s\n", toChars());
#endif
    Expression *returnValue = EXP_CANT_INTERPRET;
    Expression *e1 = this->e1;
    if (!istate)
    {
        error("value of %s is not known at compile time", e1->toChars());
        return returnValue;
    }
    /* Before we begin, we need to know if this is a reference assignment
     * (dynamic array, AA, or class) or a value assignment.
     * Determining this for slice assignments are tricky: we need to know
     * if it is a block assignment (a[] = e) rather than a direct slice
     * assignment (a[] = b[]). Note that initializers of multi-dimensional
     * static arrays can have 2D block assignments (eg, int[7][7] x = 6;).
     * So we need to recurse to determine if it is a block assignment.
     */
    bool isBlockAssignment = false;
    if (e1->op == TOKslice)
    {
        // a[] = e can have const e. So we compare the naked types.
        Type *desttype = e1->type->toBasetype();
#if DMDV2
        Type *srctype = e2->type->toBasetype()->castMod(0);
#else
        Type *srctype = e2->type->toBasetype();
#endif
        while ( desttype->ty == Tsarray || desttype->ty == Tarray)
        {
            desttype = ((TypeArray *)desttype)->next;
#if DMDV2
            if (srctype == desttype->castMod(0))
#else
            if (srctype == desttype)
#endif
            {
                isBlockAssignment = true;
                break;
            }
        }
    }
    bool wantRef = false;
    if (!fp && this->e1->type->toBasetype() == this->e2->type->toBasetype() &&
        (e1->type->toBasetype()->ty == Tarray || e1->type->toBasetype()->ty == Taarray ||
         e1->type->toBasetype()->ty == Tclass)
         //  e = *x is never a reference, because *x is always a value
         && this->e2->op != TOKstar
        )
    {
#if DMDV2
        wantRef = true;
#else
        /* D1 doesn't have const in the type system. But there is still a
         * vestigal const in the form of static const variables.
         * Problematic code like:
         *    const int [] x = [1,2,3];
         *    int [] y = x;
         * can be dealt with by making this a non-ref assign (y = x.dup).
         * Otherwise it's a big mess.
         */
        VarDeclaration * targetVar = findParentVar(e2, istate->localThis);
        if (!(targetVar && targetVar->isConst()))
            wantRef = true;
        // slice assignment of static arrays is not reference assignment
        if ((e1->op==TOKslice) && ((SliceExp *)e1)->e1->type->ty == Tsarray)
            wantRef = false;
#endif
    }
    if (isBlockAssignment && (e2->type->toBasetype()->ty == Tarray || e2->type->toBasetype()->ty == Tsarray))
    {
        wantRef = true;
    }
    /* This happens inside compiler-generated foreach statements.
     * It's another case where we need a reference
     * Note that a similar case, where e2 = 'this', occurs in
     * construction of a struct with an invariant().
     */
    if (op==TOKconstruct && this->e1->op==TOKvar && this->e2->op != TOKthis
        && this->e2->op != TOKcomma
        && ((VarExp*)this->e1)->var->storage_class & STCref)
        wantRef = true;

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
        if (e1->op == TOKarrayliteral || e1->op == TOKstring)
        {
            // f() = e2, when f returns an array, is always a slice assignment.
            // Convert into arr[0..arr.length] = e2
            e1 = new SliceExp(loc, e1,
                new IntegerExp(0, 0, Type::tsize_t),
                ArrayLength(Type::tsize_t, e1));
            e1->type = type;
        }
    }
    if (e1->op == TOKstar)
    {
        e1 = e1->interpret(istate, ctfeNeedLvalue);
        if (e1 == EXP_CANT_INTERPRET)
            return EXP_CANT_INTERPRET;
        if (!(e1->op == TOKvar || e1->op == TOKdotvar || e1->op == TOKindex
            || e1->op == TOKslice))
        {
            error("cannot dereference invalid pointer %s",
                this->e1->toChars());
            return EXP_CANT_INTERPRET;
        }
    }

    if (!(e1->op == TOKarraylength || e1->op == TOKvar || e1->op == TOKdotvar
        || e1->op == TOKindex || e1->op == TOKslice))
        printf("CTFE internal error: unsupported assignment %s\n", toChars());
    assert(e1->op == TOKarraylength || e1->op == TOKvar || e1->op == TOKdotvar
        || e1->op == TOKindex || e1->op == TOKslice);

    Expression * newval = NULL;

    if (!wantRef)
    {    // We need to treat pointers specially, because TOKsymoff can be used to
        // return a value OR a pointer
        assert(e1);
        assert(e1->type);
        if ((e1->type->ty == Tpointer && e1->type->nextOf()->ty != Tfunction) && (e2->op == TOKsymoff || e2->op==TOKaddress || e2->op==TOKvar))
            newval = this->e2->interpret(istate, ctfeNeedLvalue);
        else
            newval = this->e2->interpret(istate);
    }
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
            // ~= can create new values (see bug 6052)
            if (op == TOKcatass)
            {
                if (needToCopyLiteral(this->e2))
                    newval = copyLiteral(newval);
                if (newval->op == TOKslice)
                    newval = resolveSlice(newval);
                // It becomes a reference assignment
                wantRef = true;
            }
            if (oldval->op == TOKslice)
                oldval = resolveSlice(oldval);
            if (this->e1->type->ty == Tpointer && this->e2->type->isintegral()
                && (op==TOKaddass || op == TOKminass ||
                    op == TOKplusplus || op == TOKminusminus))
            {
                oldval = this->e1->interpret(istate, ctfeNeedLvalue);
                newval = this->e2->interpret(istate);
                if (oldval == EXP_CANT_INTERPRET || newval == EXP_CANT_INTERPRET)
                    return EXP_CANT_INTERPRET;
                newval = pointerArithmetic(loc, op, type, oldval, newval);
            }
            else if (this->e1->type->ty == Tpointer)
            {
                error("pointer expression %s cannot be interpreted at compile time", toChars());
                return EXP_CANT_INTERPRET;
            }
            else
            {
                newval = (*fp)(type, oldval, newval);
            }
            if (newval == EXP_CANT_INTERPRET)
            {
                error("Cannot interpret %s at compile time", toChars());
                return EXP_CANT_INTERPRET;
            }
            // Determine the return value
            returnValue = Cast(type, type, post ? oldval : newval);
            if (returnValue == EXP_CANT_INTERPRET)
                return returnValue;
        }
        else
            returnValue = newval;
        if (e1->op == TOKarraylength)
        {
            size_t oldlen = oldval->toInteger();
            size_t newlen = newval->toInteger();
            if (oldlen == newlen) // no change required -- we're done!
                return returnValue;
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
            if (oldval->op == TOKslice)
                oldval = resolveSlice(oldval);
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
                if (oldlen !=0)
                    assert(oldval->op == TOKarrayliteral);
                ArrayLiteralExp *ae = (ArrayLiteralExp *)oldval;
                for (size_t i = 0; i < copylen; i++)
                    elements->tdata()[i] = ae->elements->tdata()[i];
                if (elemType->ty == Tstruct || elemType->ty == Tsarray)
                {   /* If it is an aggregate literal representing a value type,
                     * we need to create a unique copy for each element
                     */
                    for (size_t i = copylen; i < newlen; i++)
                        elements->tdata()[i] = copyLiteral(defaultElem);
                }
                else
                {
                    for (size_t i = copylen; i < newlen; i++)
                        elements->tdata()[i] = defaultElem;
                }
                ArrayLiteralExp *aae = new ArrayLiteralExp(0, elements);
                aae->type = t;
                newval = aae;
                // We have changed it into a reference assignment
                // Note that returnValue is still the new length.
                wantRef = true;
                if (e1->op == TOKstar)
                {   // arr.length+=n becomes (t=&arr, *(t).length=*(t).length+n);
                    e1 = e1->interpret(istate, ctfeNeedLvalue);
                    if (e1 == EXP_CANT_INTERPRET)
                        return EXP_CANT_INTERPRET;
                }
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
        if (newval == EXP_CANT_INTERPRET)
        {
            error("CTFE error: cannot cast %s to type %s", this->e2->toChars(), type->toChars());
            return EXP_CANT_INTERPRET;
        }
        returnValue = newval;
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
    if (op==TOKconstruct && this->e1->op==TOKvar &&
        this->e2->op == TOKindex
        && ((VarExp*)this->e1)->var->storage_class & STCref)
    {
        VarDeclaration *v = ((VarExp *)e1)->var->isVarDeclaration();
#if (LOGASSIGN)
        printf("FOREACH ASSIGN %s=%s\n", v->toChars(), e2->toChars());
#endif
        v->setValueNull();
        v->createStackValue(e2);
        return e2;
    }

    bool destinationIsReference = false;
    e1 = resolveReferences(e1, istate->localThis, &destinationIsReference);

    // Unless we have a simple var assignment, we're
    // only modifying part of the variable. So we need to make sure
    // that the parent variable exists.
    if (e1->op != TOKvar && ultimateVar && !ultimateVar->getValue())
        ultimateVar->createRefValue(copyLiteral(ultimateVar->type->defaultInitLiteral()));

    // ---------------------------------------
    //      Deal with reference assignment
    // (We already have 'newval' for arraylength operations)
    // ---------------------------------------
    if (wantRef && !fp && this->e1->op != TOKarraylength)
    {
        newval = this->e2->interpret(istate, ctfeNeedLvalue);
        if (newval == EXP_CANT_INTERPRET)
            return newval;
        // If it is an assignment from a array function parameter passed by
        // reference, resolve the reference. (This should NOT happen for
        // non-reference types).
        if (newval->op == TOKvar && (newval->type->ty == Tarray ||
            newval->type->ty == Tclass))
        {
            newval = newval->interpret(istate);
        }

        if (newval->op == TOKassocarrayliteral || newval->op == TOKstring ||
            newval->op==TOKarrayliteral)
        {
            if (needToCopyLiteral(this->e2))
                newval = copyLiteral(newval);
        }
        returnValue = newval;
    }

    // ---------------------------------------
    //      Deal with dotvar expressions
    // ---------------------------------------
    // Because structs are not reference types, dotvar expressions can be
    // collapsed into a single assignment.
    if (!wantRef && e1->op == TOKdotvar)
    {
        // Strip of all of the leading dotvars, unless we started with a call
        // (in which case, we already have the lvalue).
        if (this->e1->op != TOKcall)
            e1 = e1->interpret(istate, ctfeNeedLvalue);
        if (e1 == EXP_CANT_INTERPRET)
            return e1;
        if (e1->op == TOKstructliteral && newval->op == TOKstructliteral)
        {
            assignInPlace(e1, newval);
            return returnValue;
        }
    }
#if LOGASSIGN
    if (wantRef)
        printf("REF ASSIGN: %s=%s\n", e1->toChars(), newval->toChars());
    else
        printf("ASSIGN: %s=%s\n", e1->toChars(), newval->toChars());
    showCtfeExpr(newval);
#endif

    /* Assignment to variable of the form:
     *  v = newval
     */
    if (e1->op == TOKvar)
    {
        VarExp *ve = (VarExp *)e1;
        VarDeclaration *v = ve->var->isVarDeclaration();
        if (!destinationIsReference)
            addVarToInterstate(istate, v);
        if (wantRef)
        {
            v->setValueNull();
            v->createRefValue(newval);
        }
        else if (e1->type->toBasetype()->ty == Tstruct)
        {
            // In-place modification
            if (newval->op != TOKstructliteral)
            {
                error("CTFE internal error assigning struct");
                return EXP_CANT_INTERPRET;
            }
            newval = copyLiteral(newval);
            if (v->getValue())
                assignInPlace(v->getValue(), newval);
            else
                v->createRefValue(newval);
        }
        else
        {
            if (e1->type->toBasetype()->ty == Tarray || e1->type->toBasetype()->ty == Taarray)
            { // arr op= arr
                if (!v->getValue())
                    v->createRefValue(newval);
                else v->setRefValue(newval);
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
    else if (e1->op == TOKdotvar)
    {
        /* Assignment to member variable of the form:
         *  e.v = newval
         */
        Expression *exx = ((DotVarExp *)e1)->e1;
        if (wantRef && exx->op != TOKstructliteral)
        {
            exx = exx->interpret(istate);
            if (exx == EXP_CANT_INTERPRET)
                return exx;
        }
        if (exx->op != TOKstructliteral)
        {
            error("CTFE internal error: Dotvar assignment");
            return EXP_CANT_INTERPRET;
        }
        StructLiteralExp *se = (StructLiteralExp *)exx;
        VarDeclaration *member = ((DotVarExp *)e1)->var->isVarDeclaration();
        if (!member)
        {
            error("CTFE internal error: Dotvar assignment");
            return EXP_CANT_INTERPRET;
        }
        int fieldi = se->getFieldIndex(member->type, member->offset);
        if (fieldi == -1)
            return EXP_CANT_INTERPRET;
        assert(fieldi>=0 && fieldi < se->elements->dim);
        if (newval->op == TOKstructliteral)
            assignInPlace(se->elements->tdata()[fieldi], newval);
        else
            se->elements->tdata()[fieldi] = newval;
        if (ultimateVar && !destinationIsReference)
            addVarToInterstate(istate, ultimateVar);
        return returnValue;
    }
    else if (e1->op == TOKindex)
    {
        /* Assignment to array element of the form:
         *   aggregate[i] = newval
         */
        IndexExp *ie = (IndexExp *)e1;
        uinteger_t destarraylen = 0; // not for AAs

        // Set the $ variable, and find the array literal to modify
        if (ie->e1->type->toBasetype()->ty != Taarray && ie->e1->type->toBasetype()->ty != Tpointer)
        {
            Expression *oldval = ie->e1->interpret(istate);
            if (oldval->op == TOKnull)
            {
                error("cannot index null array %s", ie->e1->toChars());
                return EXP_CANT_INTERPRET;
            }
            if (oldval->op != TOKarrayliteral && oldval->op != TOKstring
                && oldval->op != TOKslice)
            {
                error("cannot determine length of %s at compile time",
                    ie->e1->toChars());
                return EXP_CANT_INTERPRET;
            }
            destarraylen = resolveArrayLength(oldval);
            if (ie->lengthVar)
            {
                IntegerExp *dollarExp = new IntegerExp(loc, destarraylen, Type::tsize_t);
                ie->lengthVar->createStackValue(dollarExp);
            }
        }
        Expression *index = ie->e2->interpret(istate);
        if (ie->lengthVar)
            ie->lengthVar->setValueNull(); // $ is defined only inside []
        if (index == EXP_CANT_INTERPRET)
            return EXP_CANT_INTERPRET;

        if (index->op == TOKslice)  // only happens with AA assignment
            index = resolveSlice(index);

        ArrayLiteralExp *existingAE = NULL;
        StringExp *existingSE = NULL;
        AssocArrayLiteralExp *existingAA = NULL;

        Expression *aggregate = resolveReferences(ie->e1, istate->localThis);

        // Set the index to modify (for non-AAs), and check that it is in range
        dinteger_t indexToModify = 0;
        if (ie->e1->type->toBasetype()->ty != Taarray)
        {
            indexToModify = index->toInteger();
            if (ie->e1->type->toBasetype()->ty == Tpointer)
            {
                dinteger_t ofs;
                aggregate = aggregate->interpret(istate, ctfeNeedLvalue);
                if (aggregate == EXP_CANT_INTERPRET)
                    return EXP_CANT_INTERPRET;
                if (aggregate->op == TOKnull)
                {
                    error("cannot index through null pointer %s", ie->e1->toChars());
                    return EXP_CANT_INTERPRET;
                }
                if (aggregate->op == TOKint64)
                {
                    error("cannot index through invalid pointer %s of value %s",
                        ie->e1->toChars(), aggregate->toChars());
                    return EXP_CANT_INTERPRET;
                }
                aggregate = getAggregateFromPointer(aggregate, &ofs);
                indexToModify += ofs;
                destarraylen = resolveArrayLength(aggregate);
            }
            if (indexToModify >= destarraylen)
            {
                error("array index %d is out of bounds [0..%d]", indexToModify,
                    destarraylen);
                return EXP_CANT_INTERPRET;
            }
        }

        /* The only possible indexable LValue aggregates are array literals,
         * slices of array literals, and AA literals.
         */
        if (aggregate->op == TOKindex || aggregate->op == TOKdotvar ||
            aggregate->op == TOKslice || aggregate->op == TOKcall ||
            aggregate->op == TOKstar)
        {
            aggregate = aggregate->interpret(istate, ctfeNeedLvalue);
            if (aggregate == EXP_CANT_INTERPRET)
                return EXP_CANT_INTERPRET;
            // The array could be an index of an AA. Resolve it if so.
            if (aggregate->op == TOKindex)
            {
                IndexExp *ix = (IndexExp *)aggregate;
                aggregate = Index(ix->type, ix->e1, ix->e2);
            }
        }
        if (aggregate->op == TOKvar)
        {
            VarExp *ve = (VarExp *)aggregate;
            VarDeclaration *v = ve->var->isVarDeclaration();
            aggregate = v->getValue();
            if (aggregate->op == TOKnull)
            {
                if (v->type->ty == Taarray)
                {   // Assign to empty associative array
                    Expressions *valuesx = new Expressions();
                    Expressions *keysx = new Expressions();
                    Expression *indx = ie->e2->interpret(istate);
                    if (indx == EXP_CANT_INTERPRET)
                        return EXP_CANT_INTERPRET;
                    valuesx->push(newval);
                    keysx->push(indx);
                    Expression *aae2 = new AssocArrayLiteralExp(loc, keysx, valuesx);
                    aae2->type = v->type;
                    newval = aae2;
                    v->setRefValue(newval);
                    return returnValue;
                }
                // This would be a runtime segfault
                error("cannot index null array %s", v->toChars());
                return EXP_CANT_INTERPRET;
            }
        }
        if (aggregate->op == TOKslice)
        {
            SliceExp *sexp = (SliceExp *)aggregate;
            aggregate = sexp->e1;
            Expression *lwr = sexp->lwr->interpret(istate);
            indexToModify += lwr->toInteger();
        }
        if (aggregate->op == TOKarrayliteral)
            existingAE = (ArrayLiteralExp *)aggregate;
        else if (aggregate->op == TOKstring)
            existingSE = (StringExp *)aggregate;
        else if (aggregate->op == TOKassocarrayliteral)
            existingAA = (AssocArrayLiteralExp *)aggregate;
        else
        {
            error("CTFE internal compiler error %s", aggregate->toChars());
            return EXP_CANT_INTERPRET;
        }
        if (!wantRef && newval->op == TOKslice)
        {
            newval = resolveSlice(newval);
            if (newval == EXP_CANT_INTERPRET)
            {
                error("Compiler error: CTFE index assign %s", toChars());
                assert(0);
            }
        }

        if (existingAE)
        {
            if (newval->op == TOKstructliteral)
                assignInPlace((Expression *)(existingAE->elements->tdata()[indexToModify]), newval);
            else
                existingAE->elements->tdata()[indexToModify] = newval;
            return returnValue;
        }
        if (existingSE)
        {
            unsigned char *s = (unsigned char *)existingSE->string;
            unsigned value = newval->toInteger();
            switch (existingSE->sz)
            {
                case 1: s[indexToModify] = value; break;
                case 2: ((unsigned short *)s)[indexToModify] = value; break;
                case 4: ((unsigned *)s)[indexToModify] = value; break;
                default:
                    assert(0);
                    break;
            }
            return returnValue;
        }
        else if (existingAA)
        {
            if (assignAssocArrayElement(loc, existingAA, index, newval) == EXP_CANT_INTERPRET)
                return EXP_CANT_INTERPRET;
            return returnValue;
        }
        else
        {
            error("Index assignment %s is not yet supported in CTFE ", toChars());
            return EXP_CANT_INTERPRET;
        }
        return returnValue;
    }
    else if (e1->op == TOKslice)
    {
        // ------------------------------
        //   aggregate[] = newval
        //   aggregate[low..upp] = newval
        // ------------------------------
        SliceExp * sexp = (SliceExp *)e1;
        // Set the $ variable
        Expression *oldval = sexp->e1;
        bool assignmentToSlicedPointer = false;
        if (oldval->type->toBasetype()->ty == Tpointer && oldval->type->toBasetype()->nextOf()->ty != Tfunction)
        {   // Slicing a pointer
            oldval = oldval->interpret(istate, ctfeNeedLvalue);
            dinteger_t ofs;
            oldval = getAggregateFromPointer(oldval, &ofs);
            assignmentToSlicedPointer = true;
        } else
            oldval = oldval->interpret(istate);

        if (oldval->op != TOKarrayliteral && oldval->op != TOKstring
            && oldval->op != TOKslice && oldval->op != TOKnull)
        {
            error("CTFE ICE: cannot resolve array length");
            return EXP_CANT_INTERPRET;
        }
        uinteger_t dollar = resolveArrayLength(oldval);
        if (sexp->lengthVar)
        {
            Expression *arraylen = new IntegerExp(loc, dollar, Type::tsize_t);
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

        size_t dim = dollar;
        size_t upperbound = upper ? upper->toInteger() : dim;
        int lowerbound = lower ? lower->toInteger() : 0;

        if (!assignmentToSlicedPointer && (((int)lowerbound < 0) || (upperbound > dim)))
        {
            error("Array bounds [0..%d] exceeded in slice [%d..%d]",
                dim, lowerbound, upperbound);
            return EXP_CANT_INTERPRET;
        }
        if (upperbound == lowerbound)
            return newval;

        Expression *aggregate = resolveReferences(((SliceExp *)e1)->e1, istate->localThis);
        dinteger_t firstIndex = lowerbound;

        ArrayLiteralExp *existingAE = NULL;
        StringExp *existingSE = NULL;

        /* The only possible slicable LValue aggregates are array literals,
         * and slices of array literals.
         */

        if (aggregate->op == TOKindex || aggregate->op == TOKdotvar ||
            aggregate->op == TOKslice ||
            aggregate->op == TOKstar  || aggregate->op == TOKcall)
        {
            aggregate = aggregate->interpret(istate, ctfeNeedLvalue);
            if (aggregate == EXP_CANT_INTERPRET)
                return EXP_CANT_INTERPRET;
            // The array could be an index of an AA. Resolve it if so.
            if (aggregate->op == TOKindex)
            {
                IndexExp *ie = (IndexExp *)aggregate;
                aggregate = Index(ie->type, ie->e1, ie->e2);
            }
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
        if (aggregate->type->toBasetype()->ty == Tpointer && aggregate->type->toBasetype()->nextOf()->ty != Tfunction)
        {   // Slicing a pointer --> change the bounds
            aggregate = sexp->e1->interpret(istate, ctfeNeedLvalue);
            dinteger_t ofs;
            aggregate = getAggregateFromPointer(aggregate, &ofs);
            dinteger_t hi = upperbound + ofs;
            firstIndex = lowerbound + ofs;
            if (firstIndex < 0 || hi > dim)
            {
                error("slice [%d..%jd] exceeds memory block bounds [0..%jd]",
                    firstIndex, hi,  dim);
                return EXP_CANT_INTERPRET;
            }
        }
        if (aggregate->op==TOKarrayliteral)
            existingAE = (ArrayLiteralExp *)aggregate;
        else if (aggregate->op==TOKstring)
            existingSE = (StringExp *)aggregate;

        if (!wantRef && newval->op == TOKslice)
        {
            newval = resolveSlice(newval);
            if (newval == EXP_CANT_INTERPRET)
            {
                error("Compiler error: CTFE slice %s", toChars());
                assert(0);
            }
        }

        // For slice assignment, we check that the lengths match.
        size_t srclen = 0;
        if (newval->op == TOKarrayliteral)
            srclen = ((ArrayLiteralExp *)newval)->elements->dim;
        else if (newval->op == TOKstring)
            srclen = ((StringExp *)newval)->len;
        if (!isBlockAssignment && srclen != (upperbound - lowerbound))
        {
            error("Array length mismatch assigning [0..%d] to [%d..%d]", srclen, lowerbound, upperbound);
            return EXP_CANT_INTERPRET;
        }

        if (!isBlockAssignment && newval->op == TOKarrayliteral && existingAE)
        {
            Expressions *oldelems = existingAE->elements;
            Expressions *newelems = ((ArrayLiteralExp *)newval)->elements;
            for (size_t j = 0; j < newelems->dim; j++)
            {
                oldelems->tdata()[j + firstIndex] = newelems->tdata()[j];
            }
            return newval;
        }
        else if (newval->op == TOKstring && existingSE)
        {
            sliceAssignStringFromString((StringExp *)existingSE, (StringExp *)newval, firstIndex);
            return newval;
        }
        else if (newval->op == TOKstring && existingAE)
        {   /* Mixed slice: it was initialized as an array literal of chars.
             * Now a slice of it is being set with a string.
             */
            sliceAssignArrayLiteralFromString(existingAE, (StringExp *)newval, firstIndex);
            return newval;
        }
        else if (newval->op == TOKarrayliteral && existingSE)
        {   /* Mixed slice: it was initialized as a string literal.
             * Now a slice of it is being set with an array literal.
             */
            sliceAssignStringFromArrayLiteral(existingSE, (ArrayLiteralExp *)newval, firstIndex);
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
            if (goal == ctfeNeedNothing)
                return NULL; // avoid creating an unused literal
            SliceExp *retslice = new SliceExp(loc, existingSE,
                new IntegerExp(loc, firstIndex, Type::tsize_t),
                new IntegerExp(loc, firstIndex + upperbound-lowerbound, Type::tsize_t));
            retslice->type = this->type;
            return retslice->interpret(istate);
        }
        else if (existingAE)
        {
            /* Block assignment, initialization of static arrays
             *   x[] = e
             *  x may be a multidimensional static array. (Note that this
             *  only happens with array literals, never with strings).
             */
            Expressions * w = existingAE->elements;
            assert( existingAE->type->ty == Tsarray ||
                    existingAE->type->ty == Tarray);
#if DMDV2
            Type *desttype = ((TypeArray *)existingAE->type)->next->castMod(0);
            bool directblk = (e2->type->toBasetype()->castMod(0)) == desttype;
#else
            Type *desttype = ((TypeArray *)existingAE->type)->next;
            bool directblk = (e2->type->toBasetype()) == desttype;
#endif
            bool cow = !(newval->op == TOKstructliteral || newval->op == TOKarrayliteral
                || newval->op == TOKstring);
            for (size_t j = 0; j < upperbound-lowerbound; j++)
            {
                if (!directblk)
                    // Multidimensional array block assign
                    recursiveBlockAssign((ArrayLiteralExp *)w->tdata()[j+firstIndex], newval, wantRef);
                else
                {
                    if (wantRef || cow)
                        existingAE->elements->tdata()[j+firstIndex] = newval;
                    else
                        assignInPlace(existingAE->elements->tdata()[j+firstIndex], newval);
                }
            }
            if (goal == ctfeNeedNothing)
                return NULL; // avoid creating an unused literal
            SliceExp *retslice = new SliceExp(loc, existingAE,
                new IntegerExp(loc, firstIndex, Type::tsize_t),
                new IntegerExp(loc, firstIndex + upperbound-lowerbound, Type::tsize_t));
            retslice->type = this->type;
            return retslice->interpret(istate);
        }
        else
            error("Slice operation %s cannot be evaluated at compile time", toChars());
    }
    else
    {
        error("%s cannot be evaluated at compile time", toChars());
#ifdef DEBUG
        dump(0);
#endif
    }
    return returnValue;
}

Expression *AssignExp::interpret(InterState *istate, CtfeGoal goal)
{
    return interpretAssignCommon(istate, goal, NULL);
}

#define BIN_ASSIGN_INTERPRET(op) \
Expression *op##AssignExp::interpret(InterState *istate, CtfeGoal goal) \
{                                                                       \
    return interpretAssignCommon(istate, goal, &op);                    \
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

Expression *PostExp::interpret(InterState *istate, CtfeGoal goal)
{
#if LOG
    printf("PostExp::interpret() %s\n", toChars());
#endif
    Expression *e;
    if (op == TOKplusplus)
        e = interpretAssignCommon(istate, goal, &Add, 1);
    else
        e = interpretAssignCommon(istate, goal, &Min, 1);
#if LOG
    if (e == EXP_CANT_INTERPRET)
        printf("PostExp::interpret() CANT\n");
#endif
    return e;
}

Expression *AndAndExp::interpret(InterState *istate, CtfeGoal goal)
{
#if LOG
    printf("AndAndExp::interpret() %s\n", toChars());
#endif
    Expression *e = e1->interpret(istate);
    if (e != EXP_CANT_INTERPRET)
    {
        if (e->isBool(FALSE))
            e = new IntegerExp(e1->loc, 0, type);
        else if (isTrueBool(e))
        {
            e = e2->interpret(istate);
            if (e != EXP_CANT_INTERPRET)
            {
                if (e->isBool(FALSE))
                    e = new IntegerExp(e1->loc, 0, type);
                else if (isTrueBool(e))
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

Expression *OrOrExp::interpret(InterState *istate, CtfeGoal goal)
{
#if LOG
    printf("OrOrExp::interpret() %s\n", toChars());
#endif
    Expression *e = e1->interpret(istate);
    if (e != EXP_CANT_INTERPRET)
    {
        if (isTrueBool(e))
            e = new IntegerExp(e1->loc, 1, type);
        else if (e->isBool(FALSE))
        {
            e = e2->interpret(istate);
            if (e != EXP_CANT_INTERPRET)
            {
                if (e->isBool(FALSE))
                    e = new IntegerExp(e1->loc, 0, type);
                else if (isTrueBool(e))
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

Expression *CallExp::interpret(InterState *istate, CtfeGoal goal)
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
                ecall = getVarExp(loc, istate, vd, goal);
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
    if (!fd)
    {
        error("cannot evaluate %s at compile time", toChars());
        return EXP_CANT_INTERPRET;
    }
    if (pthis)
    {   // Member function call
        if (pthis->op == TOKthis)
            pthis = istate ? istate->localThis : NULL;
        else
        {
            if (pthis->op == TOKcomma)
                pthis = pthis->interpret(istate);
            if (pthis == EXP_CANT_INTERPRET)
                return EXP_CANT_INTERPRET;
                // Evaluate 'this'
            if (pthis->op != TOKvar)
                pthis = pthis->interpret(istate, ctfeNeedLvalue);
            if (pthis == EXP_CANT_INTERPRET)
                return EXP_CANT_INTERPRET;
        }
    }
    // Check for built-in functions
    Expression *eresult;
    if (evaluateIfBuiltin(&eresult, istate, fd, arguments, pthis))
        return eresult;

    // Inline .dup. Special case because it needs the return type.
    if (!pthis && fd->ident == Id::adDup && arguments && arguments->dim == 2)
    {
        e = arguments->tdata()[1];
        e = e->interpret(istate);
        if (e != EXP_CANT_INTERPRET)
        {
            if (e->op == TOKslice)
                e= resolveSlice(e);
            e = expType(type, e);
            e = copyLiteral(e);
        }
        return e;
    }
    if (!fd->fbody)
    {
        error("%s cannot be interpreted at compile time,"
            " because it has no available source code", fd->toChars());
        return EXP_CANT_INTERPRET;
    }
    eresult = fd->interpret(istate, arguments, pthis);
    if (eresult)
        e = eresult;
    else if (fd->type->toBasetype()->nextOf()->ty == Tvoid && !global.errors)
        e = EXP_VOID_INTERPRET;
    else
        error("cannot evaluate %s at compile time", toChars());
    return e;
}

Expression *CommaExp::interpret(InterState *istate, CtfeGoal goal)
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
       && ((DeclarationExp *)e1)->declaration == ((VarExp*)e2)->var
       && ((VarExp*)e2)->var->storage_class & STCctfe)  // same as Expression::isTemp
    {
        VarExp* ve = (VarExp *)e2;
        VarDeclaration *v = ve->var->isVarDeclaration();
        if (!v->init && !v->getValue())
        {
            v->createRefValue(copyLiteral(v->type->defaultInitLiteral()));
        }
        if (!v->getValue()) {
            Expression *newval = v->init->toExpression();
//            v->setRefValue(v->init->toExpression());
            // Bug 4027. Copy constructors are a weird case where the
            // initializer is a void function (the variable is modified
            // through a reference parameter instead).
            newval = newval->interpret(istate);
            if (newval == EXP_CANT_INTERPRET)
                return EXP_CANT_INTERPRET;
            if (newval != EXP_VOID_INTERPRET)
            {
                // v isn't necessarily null.
                v->setValueWithoutChecking(copyLiteral(newval));
            }
        }
        if (goal == ctfeNeedLvalue || goal == ctfeNeedLvalueRef)
            return e2;
        return e2->interpret(istate, goal);
    }
    Expression *e = e1->interpret(istate, ctfeNeedNothing);
    if (e != EXP_CANT_INTERPRET)
        e = e2->interpret(istate, goal);
    return e;
}

Expression *CondExp::interpret(InterState *istate, CtfeGoal goal)
{
#if LOG
    printf("CondExp::interpret() %s\n", toChars());
#endif
    Expression *e;
    if (econd->type->ty == Tpointer && econd->type->nextOf()->ty != Tfunction)
    {
        e = econd->interpret(istate, ctfeNeedLvalue);
        if (e == EXP_CANT_INTERPRET)
            return e;
        if (e->op != TOKnull)
            e = new IntegerExp(loc, 1, Type::tbool);
    }
    else
        e = econd->interpret(istate);
    if (e != EXP_CANT_INTERPRET)
    {
        if (isTrueBool(e))
            e = e1->interpret(istate, goal);
        else if (e->isBool(FALSE))
            e = e2->interpret(istate, goal);
        else
        {
            error("%s does not evaluate to boolean result at compile time",
                econd->toChars());
            e = EXP_CANT_INTERPRET;
        }
    }
    return e;
}

Expression *ArrayLengthExp::interpret(InterState *istate, CtfeGoal goal)
{   Expression *e;
    Expression *e1;

#if LOG
    printf("ArrayLengthExp::interpret() %s\n", toChars());
#endif
    e1 = this->e1->interpret(istate);
    assert(e1);
    if (e1 == EXP_CANT_INTERPRET)
        return EXP_CANT_INTERPRET;
    if (e1->op == TOKstring || e1->op == TOKarrayliteral || e1->op == TOKslice
        || e1->op == TOKassocarrayliteral || e1->op == TOKnull)
    {
        e = new IntegerExp(loc, resolveArrayLength(e1), type);
    }
    else
    {
        error("%s cannot be evaluated at compile time", toChars());
        return EXP_CANT_INTERPRET;
    }
    return e;
}

/*  Given an AA literal 'ae', and a key 'e2':
 *  Return ae[e2] if present, or NULL if not found.
 *  Return EXP_CANT_INTERPRET on error.
 */
Expression *findKeyInAA(AssocArrayLiteralExp *ae, Expression *e2)
{
    /* Search the keys backwards, in case there are duplicate keys
     */
    for (size_t i = ae->keys->dim; i;)
    {
        i--;
        Expression *ekey = ae->keys->tdata()[i];
        Expression *ex = ctfeEqual(TOKequal, Type::tbool, ekey, e2);
        if (ex == EXP_CANT_INTERPRET)
        {
            error("cannot evaluate %s==%s at compile time",
                ekey->toChars(), e2->toChars());
            return ex;
        }
        if (ex->isBool(TRUE))
        {
            return ae->values->tdata()[i];
        }
    }
    return NULL;
}

Expression *IndexExp::interpret(InterState *istate, CtfeGoal goal)
{
    Expression *e1 = NULL;
    Expression *e2;

#if LOG
    printf("IndexExp::interpret() %s\n", toChars());
#endif
    if (this->e1->type->toBasetype()->ty == Tpointer)
    {
        // Indexing a pointer. Note that there is no $ in this case.
        e1 = this->e1->interpret(istate);
        if (e1 == EXP_CANT_INTERPRET)
            return EXP_CANT_INTERPRET;

        e2 = this->e2->interpret(istate);
        if (e2 == EXP_CANT_INTERPRET)
            return EXP_CANT_INTERPRET;
        dinteger_t indx = e2->toInteger();
        dinteger_t ofs;
        Expression *agg = getAggregateFromPointer(e1, &ofs);
        if (agg->op == TOKnull)
        {
            error("cannot index null pointer %s", this->e1->toChars());
            return EXP_CANT_INTERPRET;
        }
        assert(agg->op == TOKarrayliteral || agg->op == TOKstring);
        dinteger_t len = ArrayLength(Type::tsize_t, agg)->toInteger();
        Type *pointee = ((TypePointer *)agg->type)->next;
        if ((indx + ofs) < 0 || (indx+ofs) > len)
        {
            error("pointer index [%jd] exceeds allocated memory block [0..%jd]",
                indx+ofs, len);
            return EXP_CANT_INTERPRET;
        }
        return Index(type, agg, new IntegerExp(loc, indx+ofs, Type::tsize_t));
    }
    e1 = this->e1->interpret(istate);
    if (e1 == EXP_CANT_INTERPRET)
        return EXP_CANT_INTERPRET;

    if (e1->op == TOKnull)
    {
        error("cannot index null array %s", this->e1->toChars());
        return EXP_CANT_INTERPRET;
    }
    /* Set the $ variable.
     *  Note that foreach uses indexing but doesn't need $
     */
    if (lengthVar && (e1->op == TOKstring || e1->op == TOKarrayliteral
        || e1->op == TOKslice))
    {
        uinteger_t dollar = resolveArrayLength(e1);
        Expression *dollarExp = new IntegerExp(loc, dollar, Type::tsize_t);
        lengthVar->createStackValue(dollarExp);
    }

    e2 = this->e2->interpret(istate);
    if (lengthVar)
        lengthVar->setValueNull(); // $ is defined only inside []
    if (e2 == EXP_CANT_INTERPRET)
        return EXP_CANT_INTERPRET;
    if (e1->op == TOKslice && e2->op == TOKint64)
    {
        // Simplify index of slice:  agg[lwr..upr][indx] --> agg[indx']
        uinteger_t indx = e2->toInteger();
        uinteger_t ilo = ((SliceExp *)e1)->lwr->toInteger();
        uinteger_t iup = ((SliceExp *)e1)->upr->toInteger();

        if (indx > iup - ilo)
        {
            error("index %ju exceeds array length %ju", indx, iup - ilo);
            return EXP_CANT_INTERPRET;
        }
        indx += ilo;
        e1 = ((SliceExp *)e1)->e1;
        e2 = new IntegerExp(e2->loc, indx, e2->type);
    }
    Expression *e = NULL;
    if ((goal == ctfeNeedLvalue && type->ty != Taarray && type->ty != Tarray
        && type->ty != Tsarray && type->ty != Tstruct && type->ty != Tclass)
        || (goal == ctfeNeedLvalueRef && type->ty != Tsarray && type->ty != Tstruct)
        )
    {   // Pointer or reference of a scalar type
        e = new IndexExp(loc, e1, e2);
        e->type = type;
        return e;
    }
    if (e1->op == TOKassocarrayliteral)
    {
        if (e2->op == TOKslice)
            e2 = resolveSlice(e2);
        e = findKeyInAA((AssocArrayLiteralExp *)e1, e2);
        if (!e)
        {
            error("key %s not found in associative array %s",
                e2->toChars(), this->e1->toChars());
            return EXP_CANT_INTERPRET;
        }
        if (e == EXP_CANT_INTERPRET)
            return e;
        assert(!e->checkSideEffect(2));
        e = paintTypeOntoLiteral(type, e);
    }
    else
    {
        e = Index(type, e1, e2);
    }
    if (e == EXP_CANT_INTERPRET)
    {
        error("%s cannot be interpreted at compile time", toChars());
        return e;
    }
    if (goal == ctfeNeedRvalue && (e->op == TOKslice || e->op == TOKdotvar))
        e = e->interpret(istate);
    return e;
}


Expression *SliceExp::interpret(InterState *istate, CtfeGoal goal)
{
    Expression *e1;
    Expression *lwr;
    Expression *upr;

#if LOG
    printf("SliceExp::interpret() %s\n", toChars());
#endif

    if (this->e1->type->toBasetype()->ty == Tpointer)
    {
        // Slicing a pointer. Note that there is no $ in this case.
        e1 = this->e1->interpret(istate);
        if (e1 == EXP_CANT_INTERPRET)
            return EXP_CANT_INTERPRET;
        if (e1->op == TOKint64)
        {
            error("cannot slice invalid pointer %s of value %s",
                this->e1->toChars(), e1->toChars());
            return EXP_CANT_INTERPRET;
        }

        /* Evaluate lower and upper bounds of slice
         */
        lwr = this->lwr->interpret(istate);
        if (lwr == EXP_CANT_INTERPRET)
            return EXP_CANT_INTERPRET;
        upr = this->upr->interpret(istate);
        if (upr == EXP_CANT_INTERPRET)
            return EXP_CANT_INTERPRET;
        uinteger_t ilwr;
        uinteger_t iupr;
        ilwr = lwr->toInteger();
        iupr = upr->toInteger();
        Expression *e;
        dinteger_t ofs;
        Expression *agg = getAggregateFromPointer(e1, &ofs);
        if (agg->op == TOKnull)
        {
            if (iupr == ilwr)
            {
                e = new NullExp(loc);
                e->type = type;
                return e;
            }
            error("cannot slice null pointer %s", this->e1->toChars());
            return EXP_CANT_INTERPRET;
        }
        assert(agg->op == TOKarrayliteral || agg->op == TOKstring);
        dinteger_t len = ArrayLength(Type::tsize_t, agg)->toInteger();
        Type *pointee = ((TypePointer *)agg->type)->next;
        if ((ilwr + ofs) < 0 || (iupr+ofs) > (len + 1) || iupr < ilwr)
        {
            error("pointer slice [%jd..%jd] exceeds allocated memory block [0..%jd]",
                ilwr+ofs, iupr+ofs, len);
            return EXP_CANT_INTERPRET;
        }
        e = new SliceExp(loc, agg, lwr, upr);
        e->type = type;
        return e;
    }
    if (goal == ctfeNeedRvalue && this->e1->op == TOKstring)
        e1 = this->e1; // Will get duplicated anyway
    else
        e1 = this->e1->interpret(istate, goal);
    if (e1 == EXP_CANT_INTERPRET)
        return EXP_CANT_INTERPRET;
    if (e1->op == TOKvar)
        e1 = e1->interpret(istate);

    if (!this->lwr)
    {
        if (goal == ctfeNeedLvalue || goal == ctfeNeedLvalueRef)
            return e1;
        return paintTypeOntoLiteral(type, e1);
    }

    /* Set the $ variable
     */
    if (e1->op != TOKarrayliteral && e1->op != TOKstring &&
        e1->op != TOKnull && e1->op != TOKslice)
    {
        error("Cannot determine length of %s at compile time\n", e1->toChars());
        return EXP_CANT_INTERPRET;
    }
    uinteger_t dollar = resolveArrayLength(e1);
    if (lengthVar)
    {
        IntegerExp *dollarExp = new IntegerExp(loc, dollar, Type::tsize_t);
        lengthVar->createStackValue(dollarExp);
    }

    /* Evaluate lower and upper bounds of slice
     */
    lwr = this->lwr->interpret(istate);
    if (lwr != EXP_CANT_INTERPRET)
        upr = this->upr->interpret(istate);
    if (lengthVar)
        lengthVar->setValueNull(); // $ is defined only inside [L..U]
    if (lwr == EXP_CANT_INTERPRET || upr == EXP_CANT_INTERPRET)
    {
        return EXP_CANT_INTERPRET;
    }

    Expression *e;
    uinteger_t ilwr;
    uinteger_t iupr;
    ilwr = lwr->toInteger();
    iupr = upr->toInteger();
    if (e1->op == TOKnull)
    {
        if (ilwr== 0 && iupr == 0)
            return e1;
        e1->error("slice [%ju..%ju] is out of bounds", ilwr, iupr);
        return EXP_CANT_INTERPRET;
    }
    if (e1->op == TOKslice)
    {
        SliceExp *se = (SliceExp *)e1;
        // Simplify slice of slice:
        //  aggregate[lo1..up1][lwr..upr] ---> aggregate[lwr'..upr']
        uinteger_t lo1 = se->lwr->toInteger();
        uinteger_t up1 = se->upr->toInteger();
        if (ilwr > iupr || iupr > up1 - lo1)
        {
            error("slice[%ju..%ju] exceeds array bounds[%ju..%ju]",
                ilwr, iupr, lo1, up1);
            return EXP_CANT_INTERPRET;
        }
        ilwr += lo1;
        iupr += lo1;
        e = new SliceExp(loc, se->e1,
                new IntegerExp(loc, ilwr, lwr->type),
                new IntegerExp(loc, iupr, upr->type));
        e->type = type;
        return e;
    }
    if (e1->op == TOKarrayliteral
        || e1->op == TOKstring)
    {
        if (iupr < ilwr || ilwr < 0 || iupr > dollar)
        {
            error("slice [%jd..%jd] exceeds array bounds [0..%jd]",
                ilwr, iupr, dollar);
            return EXP_CANT_INTERPRET;
        }
    }
    e = new SliceExp(loc, e1, lwr, upr);
    e->type = type;
    return e;
}

Expression *InExp::interpret(InterState *istate, CtfeGoal goal)
{   Expression *e = EXP_CANT_INTERPRET;

#if LOG
    printf("InExp::interpret() %s\n", toChars());
#endif
    Expression *e1 = this->e1->interpret(istate);
    if (e1 == EXP_CANT_INTERPRET)
        return e1;
    Expression *e2 = this->e2->interpret(istate);
    if (e2 == EXP_CANT_INTERPRET)
        return e2;
    if (e2->op == TOKnull)
        return new NullExp(loc, type);
    if (e2->op != TOKassocarrayliteral)
    {
        error(" %s cannot be interpreted at compile time", toChars());
        return EXP_CANT_INTERPRET;
    }
    if (e1->op == TOKslice)
        e1 = resolveSlice(e1);
    e = findKeyInAA((AssocArrayLiteralExp *)e2, e1);
    if (e == EXP_CANT_INTERPRET)
        return e;
    if (!e)
        return new NullExp(loc, type);
    e = new IndexExp(loc, e2, e1);
    e->type = type;
    return e;
}

Expression *CatExp::interpret(InterState *istate, CtfeGoal goal)
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
    if (e1->op == TOKslice)
    {
        e1 = resolveSlice(e1);
    }
    e2 = this->e2->interpret(istate);
    if (e2 == EXP_CANT_INTERPRET)
        goto Lcant;
    if (e2->op == TOKslice)
        e2 = resolveSlice(e2);
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


Expression *CastExp::interpret(InterState *istate, CtfeGoal goal)
{   Expression *e;
    Expression *e1;

#if LOG
    printf("CastExp::interpret() %s\n", toChars());
#endif
    e1 = this->e1->interpret(istate, goal);
    if (e1 == EXP_CANT_INTERPRET)
        goto Lcant;
    if (to->ty == Tpointer && e1->op != TOKnull)
    {   // Deal with casts from char[] to char *
        if (e1->type->ty == Tarray || e1->type->ty == Tsarray)
        {
            // Check for unsupported type painting operations
            Type *elemtype = ((TypeArray *)(e1->type))->next;
            Type *pointee = ((TypePointer *)type)->next;
            if (
#if DMDV2
                e1->type->nextOf()->castMod(0) != to->nextOf()->castMod(0)
#else
                e1->type->nextOf() != to->nextOf()
#endif
                && !(elemtype->isintegral() && pointee->isintegral()
                    && elemtype->size() == pointee->size()))
            {
                error("reinterpreting cast from %s to %s is not supported in CTFE",
                    e1->type->toChars(), type->toChars());
                return EXP_CANT_INTERPRET;
            }
        }

        if (e1->op == TOKslice)
        {
            if ( ((SliceExp *)e1)->e1->op == TOKnull)
            {
                return paintTypeOntoLiteral(type, ((SliceExp *)e1)->e1);
            }
            e = new IndexExp(loc, ((SliceExp *)e1)->e1, ((SliceExp *)e1)->lwr);
            e->type = type;
            return e;
        }
        if (e1->op == TOKarrayliteral)
        {
            e = new IndexExp(loc, e1, new IntegerExp(loc, 0, Type::tsize_t));
            e->type = type;
            return e;
        }
        if (e1->op == TOKstring)
        {
            return e1;
        }
        if (e1->op == TOKindex && ((IndexExp *)e1)->e1->type != e1->type)
        {   // type painting operation
            IndexExp *ie = (IndexExp *)e1;
            e = new IndexExp(e1->loc, ie->e1, ie->e2);
            e->type = type;
            return e;
        }
        if (e1->op == TOKint64)
        {   // Happens with Windows HANDLEs, for example.
            return paintTypeOntoLiteral(to, e1);
        }
        error("pointer cast from %s to %s is not supported at compile time",
                e1->type->toChars(), to->toChars());
        return EXP_CANT_INTERPRET;
    }
    if (to->ty == Tarray && e1->op == TOKslice)
    {
        e1 = new SliceExp(e1->loc, ((SliceExp *)e1)->e1, ((SliceExp *)e1)->lwr,
            ((SliceExp *)e1)->upr);
        e1->type = to;
        return e1;
    }
    // Disallow array type painting, except for conversions between built-in
    // types of identical size.
    if ((to->ty == Tsarray || to->ty == Tarray) &&
        (e1->type->ty == Tsarray || e1->type->ty == Tarray) &&
#if DMDV2
        e1->type->nextOf()->castMod(0) != to->nextOf()->castMod(0)
#else
        e1->type->nextOf() != to->nextOf()
#endif
        && !(to->nextOf()->isTypeBasic() && e1->type->nextOf()->isTypeBasic()
            && to->nextOf()->size() == e1->type->nextOf()->size()) )
    {
        error("array cast from %s to %s is not supported at compile time", e1->type->toChars(), to->toChars());
        return EXP_CANT_INTERPRET;
    }
    if (to->ty == Tsarray && e1->op == TOKslice)
        e1 = resolveSlice(e1);
    if (to->toBasetype()->ty == Tbool && e1->type->ty==Tpointer)
    {
        return new IntegerExp(loc, e1->op != TOKnull, to);
    }
    if (e1->op == TOKnull)
        return paintTypeOntoLiteral(to, e1);

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


Expression *AssertExp::interpret(InterState *istate, CtfeGoal goal)
{   Expression *e;
    Expression *e1;

#if LOG
    printf("AssertExp::interpret() %s\n", toChars());
#endif
    if (this->e1->op == TOKthis)
    {
        if (istate->localThis)
        {
            if (istate->localThis->op == TOKdotvar
                && ((DotVarExp *)(istate->localThis))->e1->op == TOKthis)
                return getVarExp(loc, istate, ((DotVarExp*)(istate->localThis))->var, ctfeNeedRvalue);
            else
                return istate->localThis->interpret(istate);
        }
    }
    // Deal with pointers (including compiler-inserted assert(&this, "null this"))
    if (this->e1->type->ty == Tpointer && this->e1->type->nextOf()->ty != Tfunction)
    {
        e1 = this->e1->interpret(istate, ctfeNeedLvalue);
        if (e1 == EXP_CANT_INTERPRET)
            goto Lcant;
        if (e1->op != TOKnull)
            return new IntegerExp(loc, 1, Type::tbool);
    }
    else
        e1 = this->e1->interpret(istate);
    if (e1 == EXP_CANT_INTERPRET)
        goto Lcant;
    if (isTrueBool(e1))
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
    {
        error("%s is not a compile-time boolean expression", e1->toChars());
        goto Lcant;
    }
    return e1;

Lcant:
    return EXP_CANT_INTERPRET;
}

Expression *PtrExp::interpret(InterState *istate, CtfeGoal goal)
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
                    dinteger_t offset = ae->e2->toInteger();
                    e = se->getField(type, offset);
                    if (!e)
                        e = EXP_CANT_INTERPRET;
                    return e;
                }
            }
        }
        e = Ptr(type, e1);
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
    {   // It's possible we have an array bounds error. We need to make sure it
        // errors with this line number, not the one where the pointer was set.
        e = e1->interpret(istate, ctfeNeedLvalue);
        if (e == EXP_CANT_INTERPRET)
            return e;
        if (!(e->op == TOKvar || e->op == TOKdotvar || e->op == TOKindex
            || e->op == TOKslice || e->op == TOKaddress))
        {
            error("dereference of invalid pointer '%s'", e->toChars());
            return EXP_CANT_INTERPRET;
        }
        if (goal != ctfeNeedLvalue)
        {
            if (e->op == TOKindex && e->type->ty == Tpointer)
            {
                IndexExp *ie = (IndexExp *)e;
                if ((ie->e1->op == TOKarrayliteral || ie->e1->op == TOKstring)
                    && ie->e2->op == TOKint64)
                {
                    Expression *dollar = ArrayLength(Type::tsize_t, ie->e1);
                    dinteger_t len = dollar->toInteger();
                    dinteger_t indx = ie->e2->toInteger();
                    assert(indx >=0 && indx <= len); // invalid pointer
                    if (indx == len)
                    {
                        error("dereference of pointer %s one past end of memory block limits [0..%jd]",
                            toChars(), len);
                        return EXP_CANT_INTERPRET;
                    }
                    return Index(type, ie->e1, ie->e2);
                }
                if (ie->e1->op == TOKassocarrayliteral)
                    return Index(type, ie->e1, ie->e2);
            }
            if (e->op == TOKstructliteral)
                return e;
            e = e1->interpret(istate, goal);
            if (e->op == TOKaddress)
            {
                e = ((AddrExp*)e)->e1;
                if (e->op == TOKdotvar || e->op == TOKindex)
                    e = e->interpret(istate, goal);
            }
            if (e == EXP_CANT_INTERPRET)
                return e;
        }
        else if (e->op == TOKaddress)
            e = ((AddrExp*)e)->e1;  // *(&x) ==> x
        if (e->op == TOKnull)
        {
            error("dereference of null pointer '%s'", e1->toChars());
            return EXP_CANT_INTERPRET;
        }
        e->type = type;
    }

#if LOG
    if (e == EXP_CANT_INTERPRET)
        printf("PtrExp::interpret() %s = EXP_CANT_INTERPRET\n", toChars());
#endif
    return e;
}

Expression *DotVarExp::interpret(InterState *istate, CtfeGoal goal)
{   Expression *e = EXP_CANT_INTERPRET;

#if LOG
    printf("DotVarExp::interpret() %s\n", toChars());
#endif

    Expression *ex = e1->interpret(istate);
    if (ex != EXP_CANT_INTERPRET)
    {
        if (ex->op == TOKaddress)
            ex = ((AddrExp *)ex)->e1;
        if (ex->op == TOKstructliteral)
        {   StructLiteralExp *se = (StructLiteralExp *)ex;
            VarDeclaration *v = var->isVarDeclaration();
            if (v)
            {
                if (goal == ctfeNeedLvalue || goal == ctfeNeedLvalueRef)
                {
                    // We can't use getField, because it makes a copy
                    int i = se->getFieldIndex(type, v->offset);
                    if (i == -1)
                    {
                        error("couldn't find field %s in %s", v->toChars(), type->toChars());
                        return EXP_CANT_INTERPRET;
                    }
                    e = se->elements->tdata()[i];
                    // If it is an lvalue literal, return it...
                    if (e->op == TOKstructliteral)
                        return e;
                    if ((type->ty == Tsarray || goal == ctfeNeedLvalue) && (
                        e->op == TOKarrayliteral ||
                        e->op == TOKassocarrayliteral || e->op == TOKstring ||
                        e->op == TOKslice))
                        return e;
                    /* Element is an allocated pointer, which was created in
                     * CastExp.
                     */
                    if (goal == ctfeNeedLvalue && e->op == TOKindex &&
                        e->type == type &&
                        (type->ty == Tpointer && type->nextOf()->ty != Tfunction))
                        return e;
                    // ...Otherwise, just return the (simplified) dotvar expression
                    e = new DotVarExp(loc, ex, v);
                    e->type = type;
                    return e;
                }
                e = se->getField(type, v->offset);
                if (!e)
                {
                    error("couldn't find field %s in %s", v->toChars(), type->toChars());
                    e = EXP_CANT_INTERPRET;
                }
                // If it is an rvalue literal, return it...
                if (e->op == TOKstructliteral || e->op == TOKarrayliteral ||
                    e->op == TOKassocarrayliteral || e->op == TOKstring)
                        return e;
                if (type->ty == Tpointer && type->nextOf()->ty != Tfunction)
                {
                    assert(e->type == type);
                    return e;
                }
                return e->interpret(istate, goal);
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
    Expression *earg = arguments->tdata()[0];
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
    Expression *earg = arguments->tdata()[0];
    earg = earg->interpret(istate);
    if (earg == EXP_CANT_INTERPRET)
        return NULL;
    if (earg->op == TOKnull)
        return new NullExp(earg->loc);
    if (earg->op != TOKassocarrayliteral && earg->type->toBasetype()->ty != Taarray)
        return NULL;
    AssocArrayLiteralExp *aae = (AssocArrayLiteralExp *)earg;
    Expression *e = new ArrayLiteralExp(aae->loc, aae->keys);
    Type *elemType = ((TypeAArray *)aae->type)->index;
    e->type = new TypeSArray(elemType, new IntegerExp(arguments ? arguments->dim : 0));
    return copyLiteral(e);
}

Expression *interpret_aaValues(InterState *istate, Expressions *arguments)
{
#if LOG
    printf("interpret_aaValues()\n");
#endif
    if (!arguments || arguments->dim != 3)
        return NULL;
    Expression *earg = arguments->tdata()[0];
    earg = earg->interpret(istate);
    if (earg == EXP_CANT_INTERPRET)
        return NULL;
    if (earg->op == TOKnull)
        return new NullExp(earg->loc);
    if (earg->op != TOKassocarrayliteral && earg->type->toBasetype()->ty != Taarray)
        return NULL;
    AssocArrayLiteralExp *aae = (AssocArrayLiteralExp *)earg;
    Expression *e = new ArrayLiteralExp(aae->loc, aae->values);
    Type *elemType = ((TypeAArray *)aae->type)->next;
    e->type = new TypeSArray(elemType, new IntegerExp(arguments ? arguments->dim : 0));
    //printf("result is %s\n", e->toChars());
    return copyLiteral(e);
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
    if (earg->op == TOKnull)
        return new NullExp(earg->loc);
    if (earg->op != TOKassocarrayliteral && earg->type->toBasetype()->ty != Taarray)
        return NULL;
    assert(earg->op == TOKassocarrayliteral);
    AssocArrayLiteralExp *aae = (AssocArrayLiteralExp *)earg;
    Expression *e = new ArrayLiteralExp(aae->loc, aae->keys);
    assert(fd->type->ty == Tfunction);
    assert(fd->type->nextOf()->ty == Tarray);
    Type *elemType = ((TypeFunction *)fd->type)->nextOf()->nextOf();
    e->type = new TypeSArray(elemType, new IntegerExp(aae->keys->dim));
    return copyLiteral(e);
}

Expression *interpret_values(InterState *istate, Expression *earg, FuncDeclaration *fd)
{
#if LOG
    printf("interpret_values()\n");
#endif
    earg = earg->interpret(istate);
    if (earg == EXP_CANT_INTERPRET)
        return NULL;
    if (earg->op == TOKnull)
        return new NullExp(earg->loc);
    if (earg->op != TOKassocarrayliteral && earg->type->toBasetype()->ty != Taarray)
        return NULL;
    assert(earg->op == TOKassocarrayliteral);
    AssocArrayLiteralExp *aae = (AssocArrayLiteralExp *)earg;
    Expression *e = new ArrayLiteralExp(aae->loc, aae->values);
    assert(fd->type->ty == Tfunction);
    assert(fd->type->nextOf()->ty == Tarray);
    Type *elemType = ((TypeFunction *)fd->type)->nextOf()->nextOf();
    e->type = new TypeSArray(elemType, new IntegerExp(aae->values->dim));
    //printf("result is %s\n", e->toChars());
    return copyLiteral(e);
}

#endif

#if DMDV2
// Return true if t is an AA, or AssociativeArray!(key, value)
bool isAssocArray(Type *t)
{
    t = t->toBasetype();
    if (t->ty == Taarray)
        return true;
    if (t->ty != Tstruct)
        return false;
    StructDeclaration *sym = ((TypeStruct *)t)->sym;
    if (sym->ident == Id::AssociativeArray)
        return true;
    return false;
}
#endif

/* Decoding UTF strings for foreach loops. Duplicates the functionality of
 * the twelve _aApplyXXn functions in aApply.d in the runtime.
 */
Expression *foreachApplyUtf(InterState *istate, Expression *str, Expression *deleg, bool rvs)
{
#if LOG
    printf("foreachApplyUtf(%s, %s)\n", str->toChars(), deleg->toChars());
#endif
    FuncDeclaration *fd = NULL;
    Expression *pthis = NULL;
    if (deleg->op == TOKdelegate)
    {
        fd = ((DelegateExp *)deleg)->func;
        pthis = ((DelegateExp *)deleg)->e1;
    }
    else if (deleg->op == TOKfunction)
        fd = ((FuncExp*)deleg)->fd;

    assert(fd && fd->fbody);
    assert(fd->parameters);
    int numParams = fd->parameters->dim;
    assert(numParams == 1 || numParams==2);
    Type *charType = fd->parameters->tdata()[numParams-1]->type;
    Type *indexType = numParams == 2 ? fd->parameters->tdata()[0]->type
                                     : Type::tsize_t;
    uinteger_t len = resolveArrayLength(str);
    if (len == 0)
        return new IntegerExp(deleg->loc, 0, indexType);

    if (str->op == TOKslice)
        str = resolveSlice(str);

    StringExp *se = NULL;
    ArrayLiteralExp *ale = NULL;
    if (str->op == TOKstring)
        se = (StringExp *) str;
    else if (str->op == TOKarrayliteral)
        ale = (ArrayLiteralExp *)str;
    else
    {   error("CTFE internal error: cannot foreach %s", str->toChars());
        return EXP_CANT_INTERPRET;
    }
    Expressions args;
    args.setDim(numParams);

    Expression *eresult;

    // Buffers for encoding; also used for decoding array literals
    unsigned char utf8buf[4];
    unsigned short utf16buf[2];

    size_t start = rvs ? len : 0;
    size_t end = rvs ? 0: len;
    for (size_t indx = start; indx != end;)
    {
        // Step 1: Decode the next dchar from the string.

        const char *errmsg = NULL; // Used for reporting decoding errors
        dchar_t rawvalue;   // Holds the decoded dchar
        size_t currentIndex = indx; // The index of the decoded character

        if (ale)
        {   // If it is an array literal, copy the code points into the buffer
            int buflen = 1; // #code points in the buffer
            size_t n = 1;   // #code points in this char
            size_t sz = ale->type->nextOf()->size();

            switch(sz)
            {
            case 1:
                if (rvs)
                {   // find the start of the string
                    --indx;
                    buflen = 1;
                    while (indx > 0 && buflen < 4)
                    {   Expression * r = ale->elements->tdata()[indx];
                        assert(r->op == TOKint64);
                        unsigned char x = (unsigned char)(((IntegerExp *)r)->value);
                        if ( (x & 0xC0) != 0x80)
                            break;
                        ++buflen;
                    }
                }
                else
                    buflen = (indx + 4 > len) ? len - indx : 4;
                for (int i=0; i < buflen; ++i)
                {
                    Expression * r = ale->elements->tdata()[indx + i];
                    assert(r->op == TOKint64);
                    utf8buf[i] = (unsigned char)(((IntegerExp *)r)->value);
                }
                n = 0;
                errmsg = utf_decodeChar(&utf8buf[0], buflen, &n, &rawvalue);
                break;
            case 2:
                if (rvs)
                {   // find the start of the string
                    --indx;
                    buflen = 1;
                    Expression * r = ale->elements->tdata()[indx];
                    assert(r->op == TOKint64);
                    unsigned short x = (unsigned short)(((IntegerExp *)r)->value);
                    if (indx > 0 && x >= 0xDC00 && x <= 0xDFFF)
                    {
                        --indx;
                        ++buflen;
                    }
                }
                else
                    buflen = (indx + 2 > len) ? len - indx : 2;
                for (int i=0; i < buflen; ++i)
                {
                    Expression * r = ale->elements->tdata()[indx + i];
                    assert(r->op == TOKint64);
                    utf16buf[i] = (unsigned short)(((IntegerExp *)r)->value);
                }
                n = 0;
                errmsg = utf_decodeWchar(&utf16buf[0], buflen, &n, &rawvalue);
                break;
            case 4:
                {
                    if (rvs)
                        --indx;

                    Expression * r = ale->elements->tdata()[indx];
                    assert(r->op == TOKint64);
                    rawvalue = ((IntegerExp *)r)->value;
                    n = 1;
                }
                break;
            default:
                assert(0);
            }
            if (!rvs)
                indx += n;
        }
        else
        {   // String literals
            size_t saveindx; // used for reverse iteration

            switch (se->sz)
            {
            case 1:
                if (rvs)
                {   // find the start of the string
                    unsigned char *s = (unsigned char *)se->string;
                    --indx;
                    while (indx > 0 && ((s[indx]&0xC0)==0x80))
                        --indx;
                    saveindx = indx;
                }
                errmsg = utf_decodeChar((unsigned char *)se->string, se->len, &indx, &rawvalue);
                if (rvs)
                    indx = saveindx;
                break;
            case 2:
                if (rvs)
                {   // find the start
                    unsigned short *s = (unsigned short *)se->string;
                    --indx;
                    if (s[indx] >= 0xDC00 && s[indx]<= 0xDFFF)
                        --indx;
                    saveindx = indx;
                }
                errmsg = utf_decodeWchar((unsigned short *)se->string, se->len, &indx, &rawvalue);
                if (rvs)
                    indx = saveindx;
                break;
            case 4:
                if (rvs)
                    --indx;
                rawvalue = ((unsigned *)(se->string))[indx];
                if (!rvs)
                    ++indx;
                break;
            default:
                assert(0);
            }
        }
        if (errmsg)
        {   deleg->error("%s", errmsg);
            return EXP_CANT_INTERPRET;
        }

        // Step 2: encode the dchar in the target encoding

        int charlen = 1; // How many codepoints are involved?
        switch(charType->size())
        {
            case 1:
                charlen = utf_codeLengthChar(rawvalue);
                utf_encodeChar(&utf8buf[0], rawvalue);
                break;
            case 2:
                charlen = utf_codeLengthWchar(rawvalue);
                utf_encodeWchar(&utf16buf[0], rawvalue);
                break;
            case 4:
                break;
            default:
                assert(0);
        }
        if (rvs)
            currentIndex = indx;

        // Step 3: call the delegate once for each code point

        // The index only needs to be set once
        if (numParams == 2)
            args.tdata()[0] = new IntegerExp(deleg->loc, currentIndex, indexType);

        Expression *val = NULL;

        for (int k= 0; k < charlen; ++k)
        {
            dchar_t codepoint;
            switch(charType->size())
            {
                case 1:
                    codepoint = utf8buf[k];
                    break;
                case 2:
                    codepoint = utf16buf[k];
                    break;
                case 4:
                    codepoint = rawvalue;
                    break;
                default:
                    assert(0);
            }
            val = new IntegerExp(str->loc, codepoint, charType);

            args.tdata()[numParams - 1] = val;

            eresult = fd->interpret(istate, &args, pthis);
            if (eresult == EXP_CANT_INTERPRET)
                return EXP_CANT_INTERPRET;

            assert(eresult->op == TOKint64);
            if (((IntegerExp *)eresult)->value != 0)
                return eresult;
        }
    }
    return eresult;
}

/* If this is a built-in function, set 'result' to the interpreted result,
 * and return true.
 * Otherwise, return false
 */
bool evaluateIfBuiltin(Expression **result, InterState *istate,
    FuncDeclaration *fd, Expressions *arguments, Expression *pthis)
{
    Expression *e = NULL;
    int nargs = arguments ? arguments->dim : 0;
#if DMDV2
    if (pthis && isAssocArray(pthis->type) && nargs==0)
    {
        if (fd->ident == Id::length)
            e = interpret_length(istate, pthis);
        else if (fd->ident == Id::keys)
            e = interpret_keys(istate, pthis, fd);
        else if (fd->ident == Id::values)
            e = interpret_values(istate, pthis, fd);
        else if (fd->ident == Id::rehash)
            e = pthis;  // rehash is a no-op
    }
    if (!pthis)
    {
        enum BUILTIN b = fd->isBuiltin();
        if (b)
        {   Expressions args;
            args.setDim(nargs);
            for (size_t i = 0; i < args.dim; i++)
            {
                Expression *earg = arguments->tdata()[i];
                earg = earg->interpret(istate);
                if (earg == EXP_CANT_INTERPRET)
                {
                    *result = EXP_CANT_INTERPRET;
                    return true;
                }
                args.tdata()[i] = earg;
            }
            e = eval_builtin(b, &args);
            if (!e)
                e = EXP_CANT_INTERPRET;
        }
    }
#endif
#if DMDV1
    if (!pthis)
    {
        if (fd->ident == Id::aaLen)
            e = interpret_aaLen(istate, arguments);
        else if (fd->ident == Id::aaKeys)
            e = interpret_aaKeys(istate, arguments);
        else if (fd->ident == Id::aaValues)
            e = interpret_aaValues(istate, arguments);
        else if (fd->ident == Id::aaRehash && nargs == 2)
        {   // rehash is a no-op
            Expression *earg = (Expression *)(arguments->data[0]);
            return earg->interpret(istate, ctfeNeedLvalue);
        }
    }
#endif
    if (!pthis)
    {
        size_t idlen = strlen(fd->ident->string);
        if (nargs == 2 && (idlen == 10 || idlen == 11)
            && !strncmp(fd->ident->string, "_aApply", 7))
        {   // Functions from aApply.d and aApplyR.d in the runtime
            bool rvs = (idlen == 11);   // true if foreach_reverse
            char c = fd->ident->string[idlen-3]; // char width: 'c', 'w', or 'd'
            char s = fd->ident->string[idlen-2]; // string width: 'c', 'w', or 'd'
            char n = fd->ident->string[idlen-1]; // numParams: 1 or 2.
            // There are 12 combinations
            if ( (n == '1' || n == '2') &&
                 (c == 'c' || c == 'w' || c == 'd') &&
                 (s == 'c' || s == 'w' || s == 'd') && c != s)
            {   Expression *str = arguments->tdata()[0];
                str = str->interpret(istate);
                if (str == EXP_CANT_INTERPRET)
                {
                    *result = EXP_CANT_INTERPRET;
                    return true;
                }
                *result = foreachApplyUtf(istate, str, arguments->tdata()[1], rvs);
                return true;
            }
        }
    }
    if (!e)
        return false;
    *result = e;
    return true;
}

/*************************** CTFE Sanity Checks ***************************/

/* Setter functions for CTFE variable values.
 * These functions exist to check for compiler CTFE bugs.
 */

bool isStackValueValid(Expression *newval)
{
    if (newval->type->ty == Tpointer && newval->type->nextOf()->ty != Tfunction)
    {
        if (newval->op == TOKaddress || newval->op == TOKnull ||
            newval->op == TOKstring)
            return true;
        if (newval->op == TOKindex)
        {
            Expression *g = ((IndexExp *)newval)->e1;
            if (g->op == TOKarrayliteral || g->op == TOKstring ||
                g->op == TOKassocarrayliteral)
            return true;
        }
        if (newval->op == TOKvar)
            return true;
        if (newval->type->nextOf()->ty == Tarray && newval->op == TOKslice)
            return true;
        if (newval->op == TOKint64)
            return true; // Result of a cast, but cannot be dereferenced
        newval->error("CTFE internal error: illegal pointer value %s\n", newval->toChars());
        return false;
    }
    if ((newval->op ==TOKarrayliteral) || ( newval->op==TOKstructliteral) ||
        (newval->op==TOKstring) || (newval->op == TOKassocarrayliteral) ||
        (newval->op == TOKnull) || (newval->op == TOKslice))
    {   return false;
    }
    if (newval->op == TOKvar)
    {
        VarExp *ve = (VarExp *)newval;
        VarDeclaration *vv = ve->var->isVarDeclaration();
        // Must not be a reference to a reference
        if (!(vv && vv->getValue() && vv->getValue()->op == TOKvar))
            return true;
    }
    if (newval->op == TOKdotvar)
    {
        if (((DotVarExp *)newval)->e1->op == TOKstructliteral)
            return true;
    }
    if (newval->op == TOKindex)
    {
        IndexExp *ie = (IndexExp *)newval;
        if (ie->e2->op == TOKint64)
        {
            if (ie->e1->op == TOKarrayliteral || ie->e1->op == TOKstring)
                return true;
        }
        if (ie->e1->op == TOKassocarrayliteral)
            return true;
        // BUG: Happens ONLY in ref foreach. Should tighten this.
        if (ie->e2->op == TOKvar)
            return true;
    }
    if (newval->op == TOKfunction) return true; // function/delegate literal
    if (newval->op == TOKdelegate) return true;
    if (newval->op == TOKsymoff)  // function pointer
    {
        if (((SymOffExp *)newval)->var->isFuncDeclaration())
            return true;
    }
    if (newval->op == TOKint64 || newval->op == TOKfloat64 ||
        newval->op == TOKchar || newval->op == TOKcomplex80)
        return true;
    newval->error("CTFE internal error: illegal stack value %s\n", newval->toChars());
    return false;
}

bool isRefValueValid(Expression *newval)
{
    assert(newval);
    if ((newval->op ==TOKarrayliteral) || ( newval->op==TOKstructliteral) ||
        (newval->op==TOKstring) || (newval->op == TOKassocarrayliteral) ||
        (newval->op == TOKnull))
    {   return true;
    }
    // Dynamic arrays passed by ref may be null. When this happens
    // they may originate from an index or dotvar expression.
    if (newval->type->ty == Tarray || newval->type->ty == Taarray
        || newval->type->ty == Tclass)
        if (newval->op == TOKdotvar || newval->op == TOKindex)
            return isStackValueValid(newval); // actually must be null
    if (newval->op == TOKslice)
    {
        SliceExp *se = (SliceExp *)newval;
        assert(se->lwr && se->lwr != EXP_CANT_INTERPRET && se->lwr->op == TOKint64);
        assert(se->upr && se->upr != EXP_CANT_INTERPRET && se->upr->op == TOKint64);
        assert(se->e1->op == TOKarrayliteral || se->e1->op == TOKstring);
        return true;
    }
    newval->error("CTFE internal error: illegal reference value %s\n", newval->toChars());
    return false;
}

void VarDeclaration::setValueNull()
{
    literalvalue = NULL;
}

// Don't check for validity
void VarDeclaration::setValueWithoutChecking(Expression *newval)
{
    assert(!newval || isStackValueValid(newval) || isRefValueValid(newval));
    literalvalue = newval;
}
void VarDeclaration::createRefValue(Expression *newval)
{
    assert(!literalvalue);
    assert(isRefValueValid(newval));
    literalvalue = newval;
}

void VarDeclaration::setRefValue(Expression *newval)
{
    assert(literalvalue);
    assert(isRefValueValid(newval));
    literalvalue = newval;
}

void VarDeclaration::setStackValue(Expression *newval)
{
    assert(literalvalue);
    assert(isStackValueValid(newval));
    literalvalue = newval;
}
void VarDeclaration::createStackValue(Expression *newval)
{
    assert(!literalvalue);
    assert(isStackValueValid(newval));
    literalvalue = newval;
}
