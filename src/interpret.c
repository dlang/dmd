
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/interpret.c
 */

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <string.h>                     // mem{cpy|set}()

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
#include "attrib.h" // for AttribDeclaration

#include "template.h"
#include "port.h"
#include "ctfe.h"

/* Interpreter: what form of return value expression is required?
 */
enum CtfeGoal
{
    ctfeNeedRvalue,   // Must return an Rvalue
    ctfeNeedLvalue,   // Must return an Lvalue
    ctfeNeedAnyValue, // Can return either an Rvalue or an Lvalue
    ctfeNeedLvalueRef,// Must return a reference to an Lvalue (for ref types)
    ctfeNeedNothing   // The return value is not required
};

bool walkPostorder(Expression *e, StoppableVisitor *v);
Expression *interpret(Statement *s, InterState *istate);
Expression *interpret(Expression *e, InterState *istate, CtfeGoal goal = ctfeNeedRvalue);

#define LOG     0
#define LOGASSIGN 0
#define LOGCOMPILE 0
#define SHOWPERFORMANCE 0

// Maximum allowable recursive function calls in CTFE
#define CTFE_RECURSION_LIMIT 1000

/**
  The values of all CTFE variables
*/
struct CtfeStack
{
private:
    /* The stack. Every declaration we encounter is pushed here,
       together with the VarDeclaration, and the previous
       stack address of that variable, so that we can restore it
       when we leave the stack frame.
       Note that when a function is forward referenced, the interpreter must
       run semantic3, and that may start CTFE again with a NULL istate. Thus
       the stack might not be empty when CTFE begins.

       Ctfe Stack addresses are just 0-based integers, but we save
       them as 'void *' because Array can only do pointers.
    */
    Expressions values;   // values on the stack
    VarDeclarations vars; // corresponding variables
    Array<void *> savedId; // id of the previous state of that var

    Array<void *> frames;  // all previous frame pointers
    Expressions savedThis;   // all previous values of localThis

    /* Global constants get saved here after evaluation, so we never
     * have to redo them. This saves a lot of time and memory.
     */
    Expressions globalValues; // values of global constants

    size_t framepointer;      // current frame pointer
    size_t maxStackPointer;   // most stack we've ever used
    Expression *localThis;    // value of 'this', or NULL if none
public:
    CtfeStack();

    size_t stackPointer();

    // The current value of 'this', or NULL if none
    Expression *getThis();

    // Largest number of stack positions we've used
    size_t maxStackUsage();
    // Start a new stack frame, using the provided 'this'.
    void startFrame(Expression *thisexp);
    void endFrame();
    bool isInCurrentFrame(VarDeclaration *v);
    Expression *getValue(VarDeclaration *v);
    void setValue(VarDeclaration *v, Expression *e);
    void push(VarDeclaration *v);
    void pop(VarDeclaration *v);
    void popAll(size_t stackpointer);
    void saveGlobalConstant(VarDeclaration *v, Expression *e);
};

struct InterState
{
    InterState *caller;         // calling function's InterState
    FuncDeclaration *fd;        // function being interpreted
    Statement *start;           // if !=NULL, start execution at this statement
    /* target of CTFEExp result; also
     * target of labelled CTFEExp or
     * CTFEExp. (NULL if no label).
     */
    Statement *gotoTarget;
    // Support for ref return values:
    // Any return to this function should return an lvalue.
    bool awaitingLvalueReturn;
    InterState();
};

/************** CtfeStack ********************************************/

CtfeStack ctfeStack;

CtfeStack::CtfeStack() : framepointer(0), maxStackPointer(0)
{
}

size_t CtfeStack::stackPointer()
{
    return values.dim;
}

Expression *CtfeStack::getThis()
{
    return localThis;
}

// Largest number of stack positions we've used
size_t CtfeStack::maxStackUsage()
{
    return maxStackPointer;
}

void CtfeStack::startFrame(Expression *thisexp)
{
    frames.push((void *)(size_t)(framepointer));
    savedThis.push(localThis);
    framepointer = stackPointer();
    localThis = thisexp;
}

void CtfeStack::endFrame()
{
    size_t oldframe = (size_t)(frames[frames.dim-1]);
    localThis = savedThis[savedThis.dim-1];
    popAll(framepointer);
    framepointer = oldframe;
    frames.setDim(frames.dim - 1);
    savedThis.setDim(savedThis.dim -1);
}

bool CtfeStack::isInCurrentFrame(VarDeclaration *v)
{
    if (v->isDataseg() && !v->isCTFE())
        return false;   // It's a global
    return v->ctfeAdrOnStack >= framepointer;
}

Expression *CtfeStack::getValue(VarDeclaration *v)
{
    if ((v->isDataseg() || v->storage_class & STCmanifest) && !v->isCTFE())
    {
        assert(v->ctfeAdrOnStack >= 0 &&
        v->ctfeAdrOnStack < globalValues.dim);
        return globalValues[v->ctfeAdrOnStack];
    }
    assert(v->ctfeAdrOnStack >= 0 && v->ctfeAdrOnStack < stackPointer());
    return values[v->ctfeAdrOnStack];
}

void CtfeStack::setValue(VarDeclaration *v, Expression *e)
{
    assert(!v->isDataseg() || v->isCTFE());
    assert(v->ctfeAdrOnStack >= 0 && v->ctfeAdrOnStack < stackPointer());
    values[v->ctfeAdrOnStack] = e;
}

void CtfeStack::push(VarDeclaration *v)
{
    assert(!v->isDataseg() || v->isCTFE());
    if (v->ctfeAdrOnStack != (size_t)-1 &&
        v->ctfeAdrOnStack >= framepointer)
    {
        // Already exists in this frame, reuse it.
        values[v->ctfeAdrOnStack] = NULL;
        return;
    }
    savedId.push((void *)(size_t)(v->ctfeAdrOnStack));
    v->ctfeAdrOnStack = (int)values.dim;
    vars.push(v);
    values.push(NULL);
}

void CtfeStack::pop(VarDeclaration *v)
{
    assert(!v->isDataseg() || v->isCTFE());
    assert(!(v->storage_class & (STCref | STCout)));
    int oldid = v->ctfeAdrOnStack;
    v->ctfeAdrOnStack = (int)(size_t)(savedId[oldid]);
    if (v->ctfeAdrOnStack == values.dim - 1)
    {
        values.pop();
        vars.pop();
        savedId.pop();
    }
}

void CtfeStack::popAll(size_t stackpointer)
{
    if (stackPointer() > maxStackPointer)
        maxStackPointer = stackPointer();
    assert(values.dim >= stackpointer);
    for (size_t i = stackpointer; i < values.dim; ++i)
    {
        VarDeclaration *v = vars[i];
        v->ctfeAdrOnStack = (int)(size_t)(savedId[i]);
    }
    values.setDim(stackpointer);
    vars.setDim(stackpointer);
    savedId.setDim(stackpointer);
}

void CtfeStack::saveGlobalConstant(VarDeclaration *v, Expression *e)
{
     assert( v->init && (v->isConst() || v->isImmutable() || v->storage_class & STCmanifest) && !v->isCTFE());
     v->ctfeAdrOnStack = (int)globalValues.dim;
     globalValues.push(e);
}

/************** InterState  ********************************************/

InterState::InterState()
{
    memset(this, 0, sizeof(InterState));
}

/************** CtfeStatus ********************************************/

int CtfeStatus::callDepth = 0;
int CtfeStatus::stackTraceCallsToSuppress = 0;
int CtfeStatus::maxCallDepth = 0;
int CtfeStatus::numArrayAllocs = 0;
int CtfeStatus::numAssignments = 0;

// CTFE diagnostic information
void printCtfePerformanceStats()
{
#if SHOWPERFORMANCE
    printf("        ---- CTFE Performance ----\n");
    printf("max call depth = %d\tmax stack = %d\n", CtfeStatus::maxCallDepth, ctfeStack.maxStackUsage());
    printf("array allocs = %d\tassignments = %d\n\n", CtfeStatus::numArrayAllocs, CtfeStatus::numAssignments);
#endif
}

VarDeclaration *findParentVar(Expression *e);
Expression *evaluateIfBuiltin(InterState *istate, Loc loc,
    FuncDeclaration *fd, Expressions *arguments, Expression *pthis);
Expression *evaluatePostblits(InterState *istate, ArrayLiteralExp *ale, size_t lwr, size_t upr);
Expression *evaluatePostblit(InterState *istate, Expression *e);
Expression *evaluateDtor(InterState *istate, Expression *e);
Expression *scrubReturnValue(Loc loc, Expression *e);


/*************************************
 * CTFE-object code for a single function
 *
 * Currently only counts the number of local variables in the function
 */
struct CompiledCtfeFunction
{
    FuncDeclaration *func; // Function being compiled, NULL if global scope
    int numVars;           // Number of variables declared in this function
    Loc callingloc;

    CompiledCtfeFunction(FuncDeclaration *f)
    {
        func = f;
        numVars = 0;
    }

    void onDeclaration(VarDeclaration *v)
    {
        //printf("%s CTFE declare %s\n", v->loc.toChars(), v->toChars());
        ++numVars;
    }

    void onExpression(Expression *e)
    {
        class VarWalker : public StoppableVisitor
        {
        public:
            CompiledCtfeFunction *ccf;

            VarWalker(CompiledCtfeFunction *ccf)
                : ccf(ccf)
            {
            }

            void visit(Expression *e)
            {
            }

            void visit(ErrorExp *e)
            {
                // Currently there's a front-end bug: silent errors
                // can occur inside delegate literals inside is(typeof()).
                // Suppress the check in this case.
                if (global.gag && ccf->func)
                {
                    stop = 1;
                    return;
                }

                ::error(e->loc, "CTFE internal error: ErrorExp in %s\n", ccf->func ? ccf->func->loc.toChars() : ccf->callingloc.toChars());
                assert(0);
            }

            void visit(DeclarationExp *e)
            {
                VarDeclaration *v = e->declaration->isVarDeclaration();
                if (!v)
                    return;
                TupleDeclaration *td = v->toAlias()->isTupleDeclaration();
                if (td)
                {
                    if (!td->objects)
                        return;
                    for (size_t i= 0; i < td->objects->dim; ++i)
                    {
                        RootObject *o = td->objects->tdata()[i];
                        Expression *ex = isExpression(o);
                        DsymbolExp *s = (ex && ex->op == TOKdsymbol) ? (DsymbolExp *)ex : NULL;
                        assert(s);
                        VarDeclaration *v2 = s->s->isVarDeclaration();
                        assert(v2);
                        if (!v2->isDataseg() || v2->isCTFE())
                            ccf->onDeclaration(v2);
                    }
                }
                else if (!(v->isDataseg() || v->storage_class & STCmanifest) || v->isCTFE())
                    ccf->onDeclaration(v);
                Dsymbol *s = v->toAlias();
                if (s == v && !v->isStatic() && v->init)
                {
                    ExpInitializer *ie = v->init->isExpInitializer();
                    if (ie)
                        ccf->onExpression(ie->exp);
                }
            }

            void visit(IndexExp *e)
            {
                if (e->lengthVar)
                    ccf->onDeclaration(e->lengthVar);
            }

            void visit(SliceExp *e)
            {
                if (e->lengthVar)
                    ccf->onDeclaration(e->lengthVar);
            }
        };

        VarWalker v(this);
        walkPostorder(e, &v);
    }
};

class CtfeCompiler : public Visitor
{
public:
    CompiledCtfeFunction *ccf;

    CtfeCompiler(CompiledCtfeFunction *ccf)
        : ccf(ccf)
    {
    }

    void visit(Statement *s)
    {
    #if LOGCOMPILE
        printf("%s Statement::ctfeCompile %s\n", s->loc.toChars(), s->toChars());
    #endif
        assert(0);
    }

    void visit(ExpStatement *s)
    {
    #if LOGCOMPILE
        printf("%s ExpStatement::ctfeCompile\n", s->loc.toChars());
    #endif
        if (s->exp)
            ccf->onExpression(s->exp);
    }

    void visit(CompoundStatement *s)
    {
    #if LOGCOMPILE
        printf("%s CompoundStatement::ctfeCompile\n", s->loc.toChars());
    #endif
        for (size_t i = 0; i < s->statements->dim; i++)
        {
            Statement *sx = (*s->statements)[i];
            if (sx)
                ctfeCompile(sx);
        }
    }

    void visit(UnrolledLoopStatement *s)
    {
    #if LOGCOMPILE
        printf("%s UnrolledLoopStatement::ctfeCompile\n", s->loc.toChars());
    #endif
        for (size_t i = 0; i < s->statements->dim; i++)
        {
            Statement *sx = (*s->statements)[i];
            if (sx)
                ctfeCompile(sx);
        }
    }

    void visit(IfStatement *s)
    {
    #if LOGCOMPILE
        printf("%s IfStatement::ctfeCompile\n", s->loc.toChars());
    #endif

        ccf->onExpression(s->condition);
        if (s->ifbody)
            ctfeCompile(s->ifbody);
        if (s->elsebody)
            ctfeCompile(s->elsebody);
    }

    void visit(ScopeStatement *s)
    {
    #if LOGCOMPILE
        printf("%s ScopeStatement::ctfeCompile\n", s->loc.toChars());
    #endif
        if (s->statement)
            ctfeCompile(s->statement);
    }

    void visit(OnScopeStatement *s)
    {
    #if LOGCOMPILE
        printf("%s OnScopeStatement::ctfeCompile\n", s->loc.toChars());
    #endif
        // rewritten to try/catch/finally
        assert(0);
    }

    void visit(DoStatement *s)
    {
    #if LOGCOMPILE
        printf("%s DoStatement::ctfeCompile\n", s->loc.toChars());
    #endif
        ccf->onExpression(s->condition);
        if (s->body)
            ctfeCompile(s->body);
    }

    void visit(WhileStatement *s)
    {
    #if LOGCOMPILE
        printf("%s WhileStatement::ctfeCompile\n", s->loc.toChars());
    #endif
        // rewritten to ForStatement
        assert(0);
    }

    void visit(ForStatement *s)
    {
    #if LOGCOMPILE
        printf("%s ForStatement::ctfeCompile\n", s->loc.toChars());
    #endif

        if (s->init)
            ctfeCompile(s->init);
        if (s->condition)
            ccf->onExpression(s->condition);
        if (s->increment)
            ccf->onExpression(s->increment);
        if (s->body)
            ctfeCompile(s->body);
    }

    void visit(ForeachStatement *s)
    {
    #if LOGCOMPILE
        printf("%s ForeachStatement::ctfeCompile\n", s->loc.toChars());
    #endif
        // rewritten for ForStatement
        assert(0);
    }

    void visit(SwitchStatement *s)
    {
    #if LOGCOMPILE
        printf("%s SwitchStatement::ctfeCompile\n", s->loc.toChars());
    #endif
        ccf->onExpression(s->condition);
        // Note that the body contains the the Case and Default
        // statements, so we only need to compile the expressions
        for (size_t i = 0; i < s->cases->dim; i++)
        {
            ccf->onExpression((*s->cases)[i]->exp);
        }
        if (s->body)
            ctfeCompile(s->body);
    }

    void visit(CaseStatement *s)
    {
    #if LOGCOMPILE
        printf("%s CaseStatement::ctfeCompile\n", s->loc.toChars());
    #endif
        if (s->statement)
            ctfeCompile(s->statement);
    }

    void visit(DefaultStatement *s)
    {
    #if LOGCOMPILE
        printf("%s DefaultStatement::ctfeCompile\n", s->loc.toChars());
    #endif
        if (s->statement)
            ctfeCompile(s->statement);
    }

    void visit(GotoDefaultStatement *s)
    {
    #if LOGCOMPILE
        printf("%s GotoDefaultStatement::ctfeCompile\n", s->loc.toChars());
    #endif
    }

    void visit(GotoCaseStatement *s)
    {
    #if LOGCOMPILE
        printf("%s GotoCaseStatement::ctfeCompile\n", s->loc.toChars());
    #endif
    }

    void visit(SwitchErrorStatement *s)
    {
    #if LOGCOMPILE
        printf("%s SwitchErrorStatement::ctfeCompile\n", s->loc.toChars());
    #endif
    }

    void visit(ReturnStatement *s)
    {
    #if LOGCOMPILE
        printf("%s ReturnStatement::ctfeCompile\n", s->loc.toChars());
    #endif
        if (s->exp)
            ccf->onExpression(s->exp);
    }

    void visit(BreakStatement *s)
    {
    #if LOGCOMPILE
        printf("%s BreakStatement::ctfeCompile\n", s->loc.toChars());
    #endif
    }

    void visit(ContinueStatement *s)
    {
    #if LOGCOMPILE
        printf("%s ContinueStatement::ctfeCompile\n", s->loc.toChars());
    #endif
    }

    void visit(WithStatement *s)
    {
    #if LOGCOMPILE
        printf("%s WithStatement::ctfeCompile\n", s->loc.toChars());
    #endif
        // If it is with(Enum) {...}, just execute the body.
        if (s->exp->op == TOKimport || s->exp->op == TOKtype)
        {
        }
        else
        {
            ccf->onDeclaration(s->wthis);
            ccf->onExpression(s->exp);
        }
        if (s->body)
            ctfeCompile(s->body);
    }

    void visit(TryCatchStatement *s)
    {
    #if LOGCOMPILE
        printf("%s TryCatchStatement::ctfeCompile\n", s->loc.toChars());
    #endif
        if (s->body)
            ctfeCompile(s->body);
        for (size_t i = 0; i < s->catches->dim; i++)
        {
            Catch *ca = (*s->catches)[i];
            if (ca->var)
                ccf->onDeclaration(ca->var);
            if (ca->handler)
                ctfeCompile(ca->handler);
        }
    }

    void visit(TryFinallyStatement *s)
    {
    #if LOGCOMPILE
        printf("%s TryFinallyStatement::ctfeCompile\n", s->loc.toChars());
    #endif
        if (s->body)
            ctfeCompile(s->body);
        if (s->finalbody)
            ctfeCompile(s->finalbody);
    }

    void visit(ThrowStatement *s)
    {
    #if LOGCOMPILE
        printf("%s ThrowStatement::ctfeCompile\n", s->loc.toChars());
    #endif
        ccf->onExpression(s->exp);
    }

    void visit(GotoStatement *s)
    {
    #if LOGCOMPILE
        printf("%s GotoStatement::ctfeCompile\n", s->loc.toChars());
    #endif
    }

    void visit(LabelStatement *s)
    {
    #if LOGCOMPILE
        printf("%s LabelStatement::ctfeCompile\n", s->loc.toChars());
    #endif
        if (s->statement)
            ctfeCompile(s->statement);
    }

    void visit(ImportStatement *s)
    {
    #if LOGCOMPILE
        printf("%s ImportStatement::ctfeCompile\n", s->loc.toChars());
    #endif
        // Contains no variables or executable code
    }

    void visit(ForeachRangeStatement *s)
    {
    #if LOGCOMPILE
        printf("%s ForeachRangeStatement::ctfeCompile\n", s->loc.toChars());
    #endif
        // rewritten for ForStatement
        assert(0);
    }

    void visit(AsmStatement *s)
    {
    #if LOGCOMPILE
        printf("%s AsmStatement::ctfeCompile\n", s->loc.toChars());
    #endif
        // we can't compile asm statements
    }

    void ctfeCompile(Statement *s)
    {
        s->accept(this);
    }
};

/*************************************
 * Compile this function for CTFE.
 * At present, this merely allocates variables.
 */
void ctfeCompile(FuncDeclaration *fd)
{
#if LOGCOMPILE
    printf("\n%s FuncDeclaration::ctfeCompile %s\n", fd->loc.toChars(), fd->toChars());
#endif
    assert(!fd->ctfeCode);
    assert(!fd->semantic3Errors);
    assert(fd->semanticRun == PASSsemantic3done);

    fd->ctfeCode = new CompiledCtfeFunction(fd);
    if (fd->parameters)
    {
        Type *tb = fd->type->toBasetype();
        assert(tb->ty == Tfunction);
        for (size_t i = 0; i < fd->parameters->dim; i++)
        {
            VarDeclaration *v = (*fd->parameters)[i];
            fd->ctfeCode->onDeclaration(v);
        }
    }
    if (fd->vresult)
        fd->ctfeCode->onDeclaration(fd->vresult);
    CtfeCompiler v(fd->ctfeCode);
    v.ctfeCompile(fd->fbody);
}

/*************************************
 *
 * Entry point for CTFE.
 * A compile-time result is required. Give an error if not possible
 */
Expression *ctfeInterpret(Expression *e)
{
    if (e->op == TOKerror)
        return e;
    //assert(e->type->ty != Terror);    // FIXME
    if (e->type->ty == Terror)
        return new ErrorExp();

    unsigned olderrors = global.errors;

    // This code is outside a function, but still needs to be compiled
    // (there are compiler-generated temporary variables such as __dollar).
    // However, this will only be run once and can then be discarded.
    CompiledCtfeFunction ctfeCodeGlobal(NULL);
    ctfeCodeGlobal.callingloc = e->loc;
    ctfeCodeGlobal.onExpression(e);

    Expression *result = interpret(e, NULL);
    if (!CTFEExp::isCantExp(result))
        result = scrubReturnValue(e->loc, result);
    if (CTFEExp::isCantExp(result))
    {
        assert(global.errors != olderrors);
        result = new ErrorExp();
    }
    return result;
}

/* Run CTFE on the expression, but allow the expression to be a TypeExp
 *  or a tuple containing a TypeExp. (This is required by pragma(msg)).
 */
Expression *ctfeInterpretForPragmaMsg(Expression *e)
{
    if (e->op == TOKerror || e->op == TOKtype)
        return e;

    // It's also OK for it to be a function declaration (happens only with
    // __traits(getOverloads))
    if (e->op == TOKvar && ((VarExp *)e)->var->isFuncDeclaration())
    {
        return e;
    }

    if (e->op != TOKtuple)
        return e->ctfeInterpret();

    // Tuples need to be treated seperately, since they are
    // allowed to contain a TypeExp in this case.

    TupleExp *tup = (TupleExp *)e;
    Expressions *expsx = NULL;
    for (size_t i = 0; i < tup->exps->dim; ++i)
    {
        Expression *g = (*tup->exps)[i];
        Expression *h = g;
        h = ctfeInterpretForPragmaMsg(g);
        if (h != g)
        {
            if (!expsx)
            {
                expsx = new Expressions();
                expsx->setDim(tup->exps->dim);
                for (size_t j = 0; j < tup->exps->dim; j++)
                    (*expsx)[j] = (*tup->exps)[j];
            }
            (*expsx)[i] = h;
        }
    }
    if (expsx)
    {
        TupleExp *te = new TupleExp(e->loc, expsx);
        expandTuples(te->exps);
        te->type = new TypeTuple(te->exps);
        return te;
    }
    return e;
}


/*************************************
 * Attempt to interpret a function given the arguments.
 * Input:
 *      istate     state for calling function (NULL if none)
 *      arguments  function arguments
 *      thisarg    'this', if a needThis() function, NULL if not.
 *
 * Return result expression if successful, TOKcantexp if not,
 * or CTFEExp if function returned void.
 */

Expression *interpret(FuncDeclaration *fd, InterState *istate, Expressions *arguments, Expression *thisarg)
{
#if LOG
    printf("\n********\n%s FuncDeclaration::interpret(istate = %p) %s\n", fd->loc.toChars(), istate, fd->toChars());
#endif
    if (fd->semanticRun == PASSsemantic3)
    {
        fd->error("circular dependency. Functions cannot be interpreted while being compiled");
        return CTFEExp::cantexp;
    }
    if (!fd->functionSemantic3())
        return CTFEExp::cantexp;
    if (fd->semanticRun < PASSsemantic3done)
        return CTFEExp::cantexp;

    // CTFE-compile the function
    if (!fd->ctfeCode)
        ctfeCompile(fd);

    Type *tb = fd->type->toBasetype();
    assert(tb->ty == Tfunction);
    TypeFunction *tf = (TypeFunction *)tb;
    if (tf->varargs && arguments &&
        ((fd->parameters && arguments->dim != fd->parameters->dim) || (!fd->parameters && arguments->dim)))
    {
        fd->error("C-style variadic functions are not yet implemented in CTFE");
        return CTFEExp::cantexp;
    }

    // Nested functions always inherit the 'this' pointer from the parent,
    // except for delegates. (Note that the 'this' pointer may be null).
    // Func literals report isNested() even if they are in global scope,
    // so we need to check that the parent is a function.
    if (fd->isNested() && fd->toParent2()->isFuncDeclaration() && !thisarg && istate)
        thisarg = ctfeStack.getThis();

    if (fd->needThis() && !thisarg)
    {
        // error, no this. Prevent segfault.
        fd->error("need 'this' to access member %s", fd->toChars());
        return CTFEExp::cantexp;
    }
    if (thisarg && !istate)
    {
        // Check that 'this' aleady has a value
        if (CTFEExp::isCantExp(interpret(thisarg, istate)))
            return CTFEExp::cantexp;
    }

    // Place to hold all the arguments to the function while
    // we are evaluating them.
    Expressions eargs;
    size_t dim = arguments ? arguments->dim : 0;
    assert((fd->parameters ? fd->parameters->dim : 0) == dim);

    /* Evaluate all the arguments to the function,
     * store the results in eargs[]
     */
    eargs.setDim(dim);
    for (size_t i = 0; i < dim; i++)
    {
        Expression *earg = (*arguments)[i];
        Parameter *fparam = Parameter::getNth(tf->parameters, i);

        if (fparam->storageClass & (STCout | STCref))
        {
            if (!istate && (fparam->storageClass & STCout))
            {
                // initializing an out parameter involves writing to it.
                earg->error("global %s cannot be passed as an 'out' parameter at compile time", earg->toChars());
                return CTFEExp::cantexp;
            }
            // Convert all reference arguments into lvalue references
            earg = interpret(earg, istate, ctfeNeedLvalueRef);
            if (CTFEExp::isCantExp(earg))
                return earg;
        }
        else if (fparam->storageClass & STClazy)
        {
        }
        else
        {
            /* Value parameters
             */
            Type *ta = fparam->type->toBasetype();
            if (ta->ty == Tsarray && earg->op == TOKaddress)
            {
                /* Static arrays are passed by a simple pointer.
                 * Skip past this to get at the actual arg.
                 */
                earg = ((AddrExp *)earg)->e1;
            }
            earg = interpret(earg, istate);
            if (CTFEExp::isCantExp(earg))
                return earg;
            /* Struct literals are passed by value, but we don't need to
             * copy them if they are passed as const
             */
            if (earg->op == TOKstructliteral && !(fparam->storageClass & (STCconst | STCimmutable)))
                earg = copyLiteral(earg).copy();
        }
        if (earg->op == TOKthrownexception)
        {
            if (istate)
                return earg;
            ((ThrownExceptionExp *)earg)->generateUncaughtError();
            return CTFEExp::cantexp;
        }
        eargs[i] = earg;
    }

    // Now that we've evaluated all the arguments, we can start the frame
    // (this is the moment when the 'call' actually takes place).
    InterState istatex;
    istatex.caller = istate;
    istatex.fd = fd;
    ctfeStack.startFrame(thisarg);

    for (size_t i = 0; i < dim; i++)
    {
        Expression *earg = eargs[i];
        Parameter *fparam = Parameter::getNth(tf->parameters, i);
        VarDeclaration *v = (*fd->parameters)[i];
#if LOG
        printf("arg[%d] = %s\n", i, earg->toChars());
#endif
        if ((fparam->storageClass & (STCout | STCref)) && earg->op == TOKvar)
        {
            VarExp *ve = (VarExp *)earg;
            VarDeclaration *v2 = ve->var->isVarDeclaration();
            if (!v2)
            {
                fd->error("cannot interpret %s as a ref parameter", ve->toChars());
                return CTFEExp::cantexp;
            }
            /* The push() isn't a variable we'll use, it's just a place
             * to save the old value of v.
             * Note that v might be v2! So we need to save v2's index
             * before pushing.
             */
            int oldadr = v2->ctfeAdrOnStack;
            ctfeStack.push(v);
            v->ctfeAdrOnStack = oldadr;
            assert(hasValue(v2));
        }
        else
        {
            // Value parameters and non-trivial references
            ctfeStack.push(v);
            setValueWithoutChecking(v, earg);
        }
#if LOG || LOGASSIGN
        printf("interpreted arg[%d] = %s\n", i, earg->toChars());
        showCtfeExpr(earg);
#endif
    }

    if (fd->vresult)
        ctfeStack.push(fd->vresult);

    // Enter the function
    ++CtfeStatus::callDepth;
    if (CtfeStatus::callDepth > CtfeStatus::maxCallDepth)
        CtfeStatus::maxCallDepth = CtfeStatus::callDepth;

    Expression *e = NULL;
    while (1)
    {
        if (CtfeStatus::callDepth > CTFE_RECURSION_LIMIT)
        {
            // This is a compiler error. It must not be suppressed.
            global.gag = 0;
            fd->error("CTFE recursion limit exceeded");
            e = CTFEExp::cantexp;
            break;
        }
        e = interpret(fd->fbody, &istatex);
        if (CTFEExp::isCantExp(e))
        {
#if LOG
            printf("function body failed to interpret\n");
#endif
        }

        if (istatex.start)
        {
            fd->error("CTFE internal error: failed to resume at statement %s", istatex.start->toChars());
            return CTFEExp::cantexp;
        }

        /* This is how we deal with a recursive statement AST
         * that has arbitrary goto statements in it.
         * Bubble up a 'result' which is the target of the goto
         * statement, then go recursively down the AST looking
         * for that statement, then execute starting there.
         */
        if (e && e->op == TOKgoto)
        {
            istatex.start = istatex.gotoTarget; // set starting statement
            istatex.gotoTarget = NULL;
        }
        else
            break;
    }
    assert(!(e && e->op == TOKcontinue) && !(e && e->op == TOKbreak));

    /* Bugzilla 7887: If the returned reference is a ref parameter of fd,
     * peel off the local indirection.
     */
    if (tf->isref && e->op == TOKvar)
    {
        VarDeclaration *v = ((VarExp *)e)->var->isVarDeclaration();
        assert(v);
        if ((v->storage_class & STCref) && (v->storage_class & STCparameter) &&
            fd == v->parent)
        {
            for (size_t i = 0; i < dim; i++)
            {
                if ((*fd->parameters)[i] == v)
                {
                    e = eargs[i];
                    break;
                }
            }
        }
    }

    // Leave the function
    --CtfeStatus::callDepth;

    ctfeStack.endFrame();

    // If fell off the end of a void function, return void
    if (!e && tf->next->ty == Tvoid)
        return CTFEExp::voidexp;

    // If result is void, return void
    if (e->op == TOKvoidexp)
        return e;

    // If it generated an exception, return it
    if (exceptionOrCantInterpret(e))
    {
        if (istate || CTFEExp::isCantExp(e))
            return e;
        ((ThrownExceptionExp *)e)->generateUncaughtError();
        return CTFEExp::cantexp;
    }

    return e;
}

class Interpreter : public Visitor
{
public:
    InterState *istate;
    CtfeGoal goal;

    Expression *result;

    Interpreter(InterState *istate, CtfeGoal goal)
        : istate(istate), goal(goal)
    {
        result = NULL;
    }

    // If e is TOKthrowexception or TOKcantexp,
    // set it to 'result' and returns true.
    bool exceptionOrCant(Expression *e)
    {
        if (exceptionOrCantInterpret(e))
        {
            result = e;
            return true;
        }
        return false;
    }

    /******************************** Statement ***************************/

    void visit(Statement *s)
    {
    #if LOG
        printf("%s Statement::interpret()\n", s->loc.toChars());
    #endif
        if (istate->start)
        {
            if (istate->start != s)
                return;
            istate->start = NULL;
        }

        s->error("statement %s cannot be interpreted at compile time", s->toChars());
        result = CTFEExp::cantexp;
    }

    void visit(ExpStatement *s)
    {
    #if LOG
        printf("%s ExpStatement::interpret(%s)\n", s->loc.toChars(), s->exp ? s->exp->toChars() : "");
    #endif
        if (istate->start)
        {
            if (istate->start != s)
                return;
            istate->start = NULL;
        }

        Expression *e = interpret(s->exp, istate, ctfeNeedNothing);
        if (exceptionOrCant(e))
            return;
    }

    void visit(CompoundStatement *s)
    {
    #if LOG
        printf("%s CompoundStatement::interpret()\n", s->loc.toChars());
    #endif
        if (istate->start == s)
            istate->start = NULL;
        Expression *e = NULL;
        size_t dim = s->statements ? s->statements->dim : 0;
        for (size_t i = 0; i < dim; i++)
        {
            Statement *sx = (*s->statements)[i];
            e = interpret(sx, istate);
            if (e)
                break;
        }
    #if LOG
        printf("%s -CompoundStatement::interpret() %p\n", s->loc.toChars(), e);
    #endif
        result = e;
    }

    void visit(UnrolledLoopStatement *s)
    {
    #if LOG
        printf("%s UnrolledLoopStatement::interpret()\n", s->loc.toChars());
    #endif
        if (istate->start == s)
            istate->start = NULL;
        Expression *e = NULL;
        size_t dim = s->statements ? s->statements->dim : 0;
        for (size_t i = 0; i < dim; i++)
        {
            Statement *sx = (*s->statements)[i];

            e = interpret(sx, istate);
            if (CTFEExp::isCantExp(e))
                break;
            if (e && e->op == TOKcontinue)
            {
                if (istate->gotoTarget && istate->gotoTarget != s)
                    break; // continue at higher level
                istate->gotoTarget = NULL;
                e = NULL;
                continue;
            }
            if (e && e->op == TOKbreak)
            {
                if (!istate->gotoTarget || istate->gotoTarget == s)
                {
                    istate->gotoTarget = NULL;
                    e = NULL;
                } // else break at a higher level
                break;
            }
            if (e)
                break;
        }
        result = e;
    }

    void visit(IfStatement *s)
    {
    #if LOG
        printf("%s IfStatement::interpret(%s)\n", s->loc.toChars(), s->condition->toChars());
    #endif
        if (istate->start == s)
            istate->start = NULL;
        if (istate->start)
        {
            Expression *e = NULL;
            e = interpret(s->ifbody, istate);
            if (exceptionOrCant(e))
                return;
            if (istate->start)
                e = interpret(s->elsebody, istate);
            result = e;
            return;
        }

        Expression *e = interpret(s->condition, istate);
        assert(e);
        if (exceptionOrCantInterpret(e))
            return;

        if (isTrueBool(e))
            e = interpret(s->ifbody, istate);
        else if (e->isBool(false))
            e = interpret(s->elsebody, istate);
        else
        {
            e = CTFEExp::cantexp;
        }
        result = e;
    }

    void visit(ScopeStatement *s)
    {
    #if LOG
        printf("%s ScopeStatement::interpret()\n", s->loc.toChars());
    #endif
        if (istate->start == s)
            istate->start = NULL;

        result = interpret(s->statement, istate);
    }

    /**
      Given an expression e which is about to be returned from the current
      function, generate an error if it contains pointers to local variables.
      Return true if it is safe to return, false if an error was generated.

      Only checks expressions passed by value (pointers to local variables
      may already be stored in members of classes, arrays, or AAs which
      were passed as mutable function parameters).
    */

    static bool stopPointersEscaping(Loc loc, Expression *e)
    {
        if (!e->type->hasPointers())
            return true;
        if (isPointer(e->type))
        {
            Expression *x = e;
            if (e->op == TOKaddress)
                x = ((AddrExp *)e)->e1;
            VarDeclaration *v;
            while (x->op == TOKvar &&
                (v = ((VarExp *)x)->var->isVarDeclaration()) != NULL)
            {
                if (v->storage_class & STCref)
                {
                    x = getValue(v);
                    if (e->op == TOKaddress)
                        ((AddrExp *)e)->e1 = x;
                    continue;
                }
                if (ctfeStack.isInCurrentFrame(v))
                {
                    error(loc, "returning a pointer to a local stack variable");
                    return false;
                }
                else
                    break;
            }
            // TODO: If it is a TOKdotvar or TOKindex, we should check that it is not
            // pointing to a local struct or static array.
        }
        if (e->op == TOKstructliteral)
        {
            StructLiteralExp *se = (StructLiteralExp *)e;
            return stopPointersEscapingFromArray(loc, se->elements);
        }
        if (e->op == TOKarrayliteral)
        {
            return stopPointersEscapingFromArray(loc, ((ArrayLiteralExp *)e)->elements);
        }
        if (e->op == TOKassocarrayliteral)
        {
            AssocArrayLiteralExp *aae = (AssocArrayLiteralExp *)e;
            if (!stopPointersEscapingFromArray(loc, aae->keys))
                return false;
            return stopPointersEscapingFromArray(loc, aae->values);
        }
        return true;
    }

    // Check all members of an array for escaping local variables. Return false if error
    static bool stopPointersEscapingFromArray(Loc loc, Expressions *elems)
    {
        for (size_t i = 0; i < elems->dim; i++)
        {
            Expression *m = (*elems)[i];
            if (!m)
                continue;
            if (!stopPointersEscaping(loc, m))
                return false;
        }
        return true;
    }

    void visit(ReturnStatement *s)
    {
    #if LOG
        printf("%s ReturnStatement::interpret(%s)\n", s->loc.toChars(), s->exp ? s->exp->toChars() : "");
    #endif
        if (istate->start)
        {
            if (istate->start != s)
                return;
            istate->start = NULL;
        }

        if (!s->exp)
        {
            result = CTFEExp::voidexp;
            return;
        }

        assert(istate && istate->fd && istate->fd->type && istate->fd->type->ty == Tfunction);
        TypeFunction *tf = (TypeFunction *)istate->fd->type;

        /* If the function returns a ref AND it's been called from an assignment,
         * we need to return an lvalue. Otherwise, just do an (rvalue) interpret.
         */
        if (tf->isref && istate->caller && istate->caller->awaitingLvalueReturn)
        {
            // We need to return an lvalue
            Expression *e = interpret(s->exp, istate, ctfeNeedLvalueRef);
            if (CTFEExp::isCantExp(e))
                s->error("ref return %s is not yet supported in CTFE", s->exp->toChars());
            result = e;
            return;
        }
        if (tf->next && tf->next->ty == Tdelegate && istate->fd->closureVars.dim > 0)
        {
            // To support this, we need to copy all the closure vars
            // into the delegate literal.
            s->error("closures are not yet supported in CTFE");
            result = CTFEExp::cantexp;
            return;
        }

        // We need to treat pointers specially, because TOKsymoff can be used to
        // return a value OR a pointer
        CtfeGoal returnGoal = isPointer(s->exp->type) ? ctfeNeedLvalue : ctfeNeedRvalue;
        Expression *e = interpret(s->exp, istate, returnGoal);
        if (exceptionOrCant(e))
            return;

        // Disallow returning pointers to stack-allocated variables (bug 7876)
        if (!stopPointersEscaping(s->loc, e))
        {
            result = CTFEExp::cantexp;
            return;
        }

        if (needToCopyLiteral(e))
            e = copyLiteral(e).copy();
    #if LOGASSIGN
        printf("RETURN %s\n", s->loc.toChars());
        showCtfeExpr(e);
    #endif
        result = e;
    }

    static Statement *findGotoTarget(InterState *istate, Identifier *ident)
    {
        Statement *target = NULL;
        if (ident)
        {
            LabelDsymbol *label = istate->fd->searchLabel(ident);
            assert(label && label->statement);
            LabelStatement *ls = label->statement;
            if (ls->gotoTarget)
                target = ls->gotoTarget;
            else
            {
                target = ls->statement;
                if (target->isScopeStatement())
                    target = target->isScopeStatement()->statement;
            }
        }
        return target;
    }

    void visit(BreakStatement *s)
    {
    #if LOG
        printf("%s BreakStatement::interpret()\n", s->loc.toChars());
    #endif
        if (istate->start)
        {
            if (istate->start != s)
                return;
            istate->start = NULL;
        }

        istate->gotoTarget = findGotoTarget(istate, s->ident);
        result = CTFEExp::breakexp;
    }

    void visit(ContinueStatement *s)
    {
    #if LOG
        printf("%s ContinueStatement::interpret()\n", s->loc.toChars());
    #endif
        if (istate->start)
        {
            if (istate->start != s)
                return;
            istate->start = NULL;
        }

        istate->gotoTarget = findGotoTarget(istate, s->ident);
        result = CTFEExp::continueexp;
    }

    void visit(WhileStatement *s)
    {
    #if LOG
        printf("WhileStatement::interpret()\n");
    #endif
        assert(0);                  // rewritten to ForStatement
    }

    void visit(DoStatement *s)
    {
    #if LOG
        printf("%s DoStatement::interpret()\n", s->loc.toChars());
    #endif
        if (istate->start == s)
            istate->start = NULL;
        Expression *e;

        while (1)
        {
            bool wasGoto = !!istate->start;
            e = interpret(s->body, istate);
            if (CTFEExp::isCantExp(e))
                break;
            if (wasGoto && istate->start)
                return;
            if (e && e->op == TOKbreak)
            {
                if (!istate->gotoTarget || istate->gotoTarget == s)
                {
                    istate->gotoTarget = NULL;
                    e = NULL;
                } // else break at a higher level
                break;
            }
            if (e && e->op != TOKcontinue)
                break;
            if (istate->gotoTarget && istate->gotoTarget != s)
                break; // continue at a higher level

            istate->gotoTarget = NULL;
            e = interpret(s->condition, istate);
            if (exceptionOrCant(e))
                return;
            if (!e->isConst())
            {
                e = CTFEExp::cantexp;
                break;
            }
            if (isTrueBool(e))
            {
            }
            else if (e->isBool(false))
            {
                e = NULL;
                break;
            }
            else
                assert(0);
        }
        result = e;
    }

    void visit(ForStatement *s)
    {
    #if LOG
        printf("%s ForStatement::interpret()\n", s->loc.toChars());
    #endif
        if (istate->start == s)
            istate->start = NULL;
        Expression *e;

        e = interpret(s->init, istate);
        if (exceptionOrCant(e))
            return;
        assert(!e);

        while (1)
        {
            if (s->condition && !istate->start)
            {
                e = interpret(s->condition, istate);
                if (exceptionOrCant(e))
                    return;
                if (e->isBool(false))
                {
                    e = NULL;
                    break;
                }
                assert(isTrueBool(e));
            }

            bool wasGoto = !!istate->start;
            e = interpret(s->body, istate);
            if (CTFEExp::isCantExp(e))
                break;
            if (wasGoto && istate->start)
                return;

            if (e && e->op == TOKbreak)
            {
                if (!istate->gotoTarget || istate->gotoTarget == s)
                {
                    istate->gotoTarget = NULL;
                    e = NULL;
                } // else break at a higher level
                break;
            }
            if (e && e->op != TOKcontinue)
                break;

            if (istate->gotoTarget && istate->gotoTarget != s)
                break; // continue at a higher level
            istate->gotoTarget = NULL;

            e = interpret(s->increment, istate);
            if (CTFEExp::isCantExp(e))
                break;
        }
        result = e;
    }

    void visit(ForeachStatement *s)
    {
        assert(0);                  // rewritten to ForStatement
    }

    void visit(ForeachRangeStatement *s)
    {
        assert(0);                  // rewritten to ForStatement
    }

    void visit(SwitchStatement *s)
    {
    #if LOG
        printf("%s SwitchStatement::interpret()\n", s->loc.toChars());
    #endif
        if (istate->start == s)
            istate->start = NULL;
        Expression *e = NULL;

        if (istate->start)
        {
            e = interpret(s->body, istate);
            if (istate->start)
                return;
            if (CTFEExp::isCantExp(e))
            {
                result = e;
                return;
            }
            if (e && e->op == TOKbreak)
            {
                if (!istate->gotoTarget || istate->gotoTarget == s)
                {
                    istate->gotoTarget = NULL;
                    return;
                }
                // else break at a higher level
            }
            result = e;
            return;
        }


        Expression *econdition = interpret(s->condition, istate);
        if (exceptionOrCant(econdition))
            return;

        Statement *scase = NULL;
        if (s->cases)
        {
            for (size_t i = 0; i < s->cases->dim; i++)
            {
                CaseStatement *cs = (*s->cases)[i];
                Expression * caseExp = interpret(cs->exp, istate);
                if (exceptionOrCant(caseExp))
                    return;
                int eq = ctfeEqual(caseExp->loc, TOKequal, econdition, caseExp);
                if (eq)
                {
                    scase = cs;
                    break;
                }
            }
        }
        if (!scase)
        {
            if (s->hasNoDefault)
                s->error("no default or case for %s in switch statement", econdition->toChars());
            scase = s->sdefault;
        }

        assert(scase);
        istate->start = scase;
        e = interpret(s->body, istate);
        assert(!istate->start);
        if (e && e->op == TOKbreak)
        {
            if (!istate->gotoTarget || istate->gotoTarget == s)
            {
                istate->gotoTarget = NULL;
                e = NULL;
            }
            // else break at a higher level
        }
        result = e;
    }

    void visit(CaseStatement *s)
    {
    #if LOG
        printf("%s CaseStatement::interpret(%s) this = %p\n", s->loc.toChars(), s->exp->toChars(), s);
    #endif
        if (istate->start == s)
            istate->start = NULL;

        result = interpret(s->statement, istate);
    }

    void visit(DefaultStatement *s)
    {
    #if LOG
        printf("%s DefaultStatement::interpret()\n", s->loc.toChars());
    #endif
        if (istate->start == s)
            istate->start = NULL;

        result = interpret(s->statement, istate);
    }

    void visit(GotoStatement *s)
    {
    #if LOG
        printf("%s GotoStatement::interpret()\n", s->loc.toChars());
    #endif
        if (istate->start)
        {
            if (istate->start != s)
                return;
            istate->start = NULL;
        }

        assert(s->label && s->label->statement);
        istate->gotoTarget = s->label->statement;
        result = CTFEExp::gotoexp;
    }

    void visit(GotoCaseStatement *s)
    {
    #if LOG
        printf("%s GotoCaseStatement::interpret()\n", s->loc.toChars());
    #endif
        if (istate->start)
        {
            if (istate->start != s)
                return;
            istate->start = NULL;
        }

        assert(s->cs);
        istate->gotoTarget = s->cs;
        result = CTFEExp::gotoexp;
    }

    void visit(GotoDefaultStatement *s)
    {
    #if LOG
        printf("%s GotoDefaultStatement::interpret()\n", s->loc.toChars());
    #endif
        if (istate->start)
        {
            if (istate->start != s)
                return;
            istate->start = NULL;
        }

        assert(s->sw && s->sw->sdefault);
        istate->gotoTarget = s->sw->sdefault;
        result = CTFEExp::gotoexp;
    }

    void visit(LabelStatement *s)
    {
    #if LOG
        printf("%s LabelStatement::interpret()\n", s->loc.toChars());
    #endif
        if (istate->start == s)
            istate->start = NULL;

        result = interpret(s->statement, istate);
    }

    void visit(TryCatchStatement *s)
    {
    #if LOG
        printf("%s TryCatchStatement::interpret()\n", s->loc.toChars());
    #endif
        if (istate->start == s)
            istate->start = NULL;
        if (istate->start)
        {
            Expression *e = NULL;
            e = interpret(s->body, istate);
            for (size_t i = 0; !e && istate->start && i < s->catches->dim; i++)
            {
                Catch *ca = (*s->catches)[i];
                e = interpret(ca->handler, istate);
            }
            result = e;
            return;
        }

        Expression *e = interpret(s->body, istate);
        if (CTFEExp::isCantExp(e))
        {
            result = e;
            return;
        }
        if (!exceptionOrCant(e))
        {
            result = e;
            return;
        }
        // An exception was thrown
        ThrownExceptionExp *ex = (ThrownExceptionExp *)e;
        Type *extype = ex->thrown->originalClass()->type;
        // Search for an appropriate catch clause.
        for (size_t i = 0; i < s->catches->dim; i++)
        {
            Catch *ca = (*s->catches)[i];
            Type *catype = ca->type;

            if (catype->equals(extype) || catype->isBaseOf(extype, NULL))
            {
                // Execute the handler
                if (ca->var)
                {
                    ctfeStack.push(ca->var);
                    setValue(ca->var, ex->thrown);
                }
                e = interpret(ca->handler, istate);
                if (e && e->op == TOKgoto)
                {
                    InterState istatex = *istate;
                    istatex.start = istate->gotoTarget; // set starting statement
                    istatex.gotoTarget = NULL;
                    Expression *eh = interpret(ca->handler, &istatex);
                    if (!istatex.start)
                    {
                        istate->gotoTarget = NULL;
                        e = eh;
                    }
                }
                result = e;
                return;
            }
        }
        result = e;
    }

    static bool isAnErrorException(ClassDeclaration *cd)
    {
        return cd == ClassDeclaration::errorException || ClassDeclaration::errorException->isBaseOf(cd, NULL);
    }

    static ThrownExceptionExp *chainExceptions(ThrownExceptionExp *oldest, ThrownExceptionExp *newest)
    {
    #if LOG
        printf("Collided exceptions %s %s\n", oldest->thrown->toChars(), newest->thrown->toChars());
    #endif
        // Little sanity check to make sure it's really a Throwable
        ClassReferenceExp *boss = oldest->thrown;
        assert((*boss->value->elements)[4]->type->ty == Tclass);
        ClassReferenceExp *collateral = newest->thrown;
        if ( isAnErrorException(collateral->originalClass()) &&
            !isAnErrorException(boss->originalClass()))
        {
            // The new exception bypass the existing chain
            assert((*collateral->value->elements)[5]->type->ty == Tclass);
            (*collateral->value->elements)[5] = boss;
            return newest;
        }
        while ((*boss->value->elements)[4]->op == TOKclassreference)
        {
            boss = (ClassReferenceExp *)(*boss->value->elements)[4];
        }
        (*boss->value->elements)[4] = collateral;
        return oldest;
    }

    void visit(TryFinallyStatement *s)
    {
    #if LOG
        printf("%s TryFinallyStatement::interpret()\n", s->loc.toChars());
    #endif
        if (istate->start == s)
            istate->start = NULL;
        if (istate->start)
        {
            Expression *e = NULL;
            e = interpret(s->body, istate);
            // Jump into/out from finalbody is disabled in semantic analysis.
            // and jump inside will be handled by the ScopeStatement == finalbody.
            result = e;
            return;
        }

        Expression *e = interpret(s->body, istate);
        if (CTFEExp::isCantExp(e))
        {
            result = e;
            return;
        }
        Expression *second = interpret(s->finalbody, istate);
        if (CTFEExp::isCantExp(second))
        {
            result = second;
            return;
        }
        if (exceptionOrCantInterpret(second))
        {
            // Check for collided exceptions
            if (exceptionOrCantInterpret(e))
                e = chainExceptions((ThrownExceptionExp *)e, (ThrownExceptionExp *)second);
            else
                e = second;
        }
        result = e;
    }

    void visit(ThrowStatement *s)
    {
    #if LOG
        printf("%s ThrowStatement::interpret()\n", s->loc.toChars());
    #endif
        if (istate->start)
        {
            if (istate->start != s)
                return;
            istate->start = NULL;
        }

        Expression *e = interpret(s->exp, istate);
        if (exceptionOrCant(e))
            return;

        assert(e->op == TOKclassreference);
        result = new ThrownExceptionExp(s->loc, (ClassReferenceExp *)e);
    }

    void visit(OnScopeStatement *s)
    {
        assert(0);
    }

    void visit(WithStatement *s)
    {
    #if LOG
        printf("%s WithStatement::interpret()\n", s->loc.toChars());
    #endif

        // If it is with(Enum) {...}, just execute the body.
        if (s->exp->op == TOKimport || s->exp->op == TOKtype)
        {
            result = interpret(s->body, istate);
            return;
        }

        if (istate->start)
        {
            if (istate->start != s)
                return;
            istate->start = NULL;
        }

        Expression *e = interpret(s->exp, istate);
        if (exceptionOrCant(e))
            return;

        if (s->wthis->type->ty == Tpointer && s->exp->type->ty != Tpointer)
        {
            e = new AddrExp(s->loc, e);
            e->type = s->wthis->type;
        }
        ctfeStack.push(s->wthis);
        setValue(s->wthis, e);
        e = interpret(s->body, istate);
        if (e && e->op == TOKgoto)
        {
            InterState istatex = *istate;
            istatex.start = istate->gotoTarget; // set starting statement
            istatex.gotoTarget = NULL;
            Expression *ex = interpret(s->body, &istatex);
            if (!istatex.start)
            {
                istate->gotoTarget = NULL;
                e = ex;
            }
        }
        ctfeStack.pop(s->wthis);
        result = e;
    }

    void visit(AsmStatement *s)
    {
    #if LOG
        printf("%s AsmStatement::interpret()\n", s->loc.toChars());
    #endif
        if (istate->start)
        {
            if (istate->start != s)
                return;
            istate->start = NULL;
        }

        s->error("asm statements cannot be interpreted at compile time");
        result = CTFEExp::cantexp;
    }

    void visit(ImportStatement *s)
    {
    #if LOG
        printf("ImportStatement::interpret()\n");
    #endif
        if (istate->start)
        {
            if (istate->start != s)
                return;
            istate->start = NULL;
        }
    }

    /******************************** Expression ***************************/

    void visit(Expression *e)
    {
    #if LOG
        printf("%s Expression::interpret() %s\n", e->loc.toChars(), e->toChars());
        printf("type = %s\n", e->type->toChars());
        e->print();
    #endif
        e->error("cannot interpret %s at compile time", e->toChars());
        result = CTFEExp::cantexp;
    }

    void visit(ThisExp *e)
    {
        Expression *localThis = ctfeStack.getThis();
        if (localThis && localThis->op == TOKstructliteral)
        {
            result = localThis;
            return;
        }
        if (localThis)
        {
            result = interpret(localThis, istate, goal);
            return;
        }
        e->error("value of 'this' is not known at compile time");
        result = CTFEExp::cantexp;
    }

    void visit(NullExp *e)
    {
        result = e;
    }

    void visit(IntegerExp *e)
    {
    #if LOG
        printf("%s IntegerExp::interpret() %s\n", e->loc.toChars(), e->toChars());
    #endif
        result = e;
    }

    void visit(RealExp *e)
    {
    #if LOG
        printf("%s RealExp::interpret() %s\n", e->loc.toChars(), e->toChars());
    #endif
        result = e;
    }

    void visit(ComplexExp *e)
    {
        result = e;
    }

    void visit(StringExp *e)
    {
    #if LOG
        printf("%s StringExp::interpret() %s\n", e->loc.toChars(), e->toChars());
    #endif
        /* Attempts to modify string literals are prevented
         * in BinExp::interpretAssignCommon.
         */
        result = e;
    }

    void visit(FuncExp *e)
    {
    #if LOG
        printf("%s FuncExp::interpret() %s\n", e->loc.toChars(), e->toChars());
    #endif
        result = e;
    }

    void visit(SymOffExp *e)
    {
    #if LOG
        printf("%s SymOffExp::interpret() %s\n", e->loc.toChars(), e->toChars());
    #endif
        if (e->var->isFuncDeclaration() && e->offset == 0)
        {
            result = e;
            return;
        }
        if (isTypeInfo_Class(e->type) && e->offset == 0)
        {
            result = e;
            return;
        }
        if (e->type->ty != Tpointer)
        {
            // Probably impossible
            e->error("cannot interpret %s at compile time", e->toChars());
            result = CTFEExp::cantexp;
            return;
        }
        Type *pointee = ((TypePointer *)e->type)->next;
        if (e->var->isThreadlocal())
        {
            e->error("cannot take address of thread-local variable %s at compile time", e->var->toChars());
            result = CTFEExp::cantexp;
            return;
        }
        // Check for taking an address of a shared variable.
        // If the shared variable is an array, the offset might not be zero.
        Type *fromType = NULL;
        if (e->var->type->ty == Tarray || e->var->type->ty == Tsarray)
        {
            fromType = ((TypeArray *)(e->var->type))->next;
        }
        if (e->var->isDataseg() &&
            ((e->offset == 0 && isSafePointerCast(e->var->type, pointee)) ||
             (fromType && isSafePointerCast(fromType, pointee))))
        {
            result = e;
            return;
        }
        Expression *val = getVarExp(e->loc, istate, e->var, goal);
        if (CTFEExp::isCantExp(val))
        {
            result = val;
            return;
        }
        if (val->type->ty == Tarray || val->type->ty == Tsarray)
        {
            // Check for unsupported type painting operations
            Type *elemtype = ((TypeArray *)(val->type))->next;

            // It's OK to cast from fixed length to dynamic array, eg &int[3] to int[]*
            if (val->type->ty == Tsarray && pointee->ty == Tarray &&
                elemtype->size() == pointee->nextOf()->size())
            {
                result = new AddrExp(e->loc, val);
                result->type = e->type;
                return;
            }
            if (!isSafePointerCast(elemtype, pointee))
            {
                // It's also OK to cast from &string to string*.
                if (e->offset == 0 && isSafePointerCast(e->var->type, pointee))
                {
                    result = new VarExp(e->loc, e->var);
                    result->type = e->type;
                    return;
                }
                e->error("reinterpreting cast from %s to %s is not supported in CTFE",
                    val->type->toChars(), e->type->toChars());
                result = CTFEExp::cantexp;
                return;
            }

            dinteger_t sz = pointee->size();
            dinteger_t indx = e->offset / sz;
            assert(sz * indx == e->offset);
            Expression *aggregate = NULL;
            if (val->op == TOKarrayliteral || val->op == TOKstring)
            {
                aggregate = val;
            }
            else if (val->op == TOKslice)
            {
                aggregate = ((SliceExp *)val)->e1;
                Expression *lwr = interpret(((SliceExp *)val)->lwr, istate);
                indx += lwr->toInteger();
            }
            if (aggregate)
            {
                IntegerExp *ofs = new IntegerExp(e->loc, indx, Type::tsize_t);
                result = new IndexExp(e->loc, aggregate, ofs);
                result->type = e->type;
                return;
            }
        }
        else if (e->offset == 0 && isSafePointerCast(e->var->type, pointee))
        {
            // Create a CTFE pointer &var
            VarExp *ve = new VarExp(e->loc, e->var);
            ve->type = e->var->type;
            result = new AddrExp(e->loc, ve);
            result->type = e->type;
            return;
        }

        e->error("cannot convert &%s to %s at compile time", e->var->type->toChars(), e->type->toChars());
        result = CTFEExp::cantexp;
    }

    void visit(AddrExp *e)
    {
    #if LOG
        printf("%s AddrExp::interpret() %s\n", e->loc.toChars(), e->toChars());
    #endif
        if (e->e1->op == TOKvar && ((VarExp *)e->e1)->var->isDataseg())
        {
            // Normally this is already done by optimize()
            // Do it here in case optimize(0) wasn't run before CTFE
            result = new SymOffExp(e->loc, ((VarExp *)e->e1)->var, 0);
            result->type = e->type;
            return;
        }
        // For reference types, we need to return an lvalue ref.
        TY tb = e->e1->type->toBasetype()->ty;
        bool needRef = (tb == Tarray || tb == Taarray || tb == Tclass);
        result = interpret(e->e1, istate, needRef ? ctfeNeedLvalueRef : ctfeNeedLvalue);
        if (exceptionOrCant(result))
            return;
        // Return a simplified address expression
        result = new AddrExp(e->loc, result);
        result->type = e->type;
    }

    void visit(DelegateExp *e)
    {
    #if LOG
        printf("%s DelegateExp::interpret() %s\n", e->loc.toChars(), e->toChars());
    #endif
        // TODO: Really we should create a CTFE-only delegate expression
        // of a pointer and a funcptr.

        // If it is &nestedfunc, just return it
        // TODO: We should save the context pointer
        if (e->e1->op == TOKvar && ((VarExp *)e->e1)->var->isFuncDeclaration())
        {
            result = e;
            return;
        }

        // If it has already been CTFE'd, just return it
        if (e->e1->op == TOKstructliteral || e->e1->op == TOKclassreference)
        {
            result = e;
            return;
        }

        // Else change it into &structliteral.func or &classref.func
        result = interpret(e->e1, istate, ctfeNeedLvalue);
        if (exceptionOrCant(result))
            return;

        result = new DelegateExp(e->loc, result, e->func);
        result->type = e->type;
    }


    // -------------------------------------------------------------
    //         Remove out, ref, and this
    // -------------------------------------------------------------
    // The variable used in a dotvar, index, or slice expression,
    // after 'out', 'ref', and 'this' have been removed.
    static Expression *resolveReferences(Expression *e)
    {
        for (;;)
        {
            if (e->op == TOKthis)
            {
                Expression *thisval = ctfeStack.getThis();
                assert(thisval);
                assert(e != thisval);
                e = thisval;
                continue;
            }
            if (e->op == TOKvar)
            {
                VarExp *ve = (VarExp *)e;
                VarDeclaration *v = ve->var->isVarDeclaration();
                assert(v);
                if (v->type->ty == Tpointer)
                    break;
                if (v->ctfeAdrOnStack == (size_t)-1) // If not on the stack, can't possibly be a ref.
                    break;
                Expression *val = getValue(v);
                if (val && (val->op == TOKslice))
                {
                    SliceExp *se = (SliceExp *)val;
                    if (se->e1->op == TOKarrayliteral || se->e1->op == TOKassocarrayliteral || se->e1->op == TOKstring)
                        break;
                    e = val;
                    continue;
                }
                if (val && (val->op == TOKindex || val->op == TOKdotvar ||
                            val->op == TOKthis  || val->op == TOKvar))
                {
                    e = val;
                    continue;
                }
            }
            break;
        }
        return e;
    }

    static Expression *getVarExp(Loc loc, InterState *istate, Declaration *d, CtfeGoal goal)
    {
        Expression *e = CTFEExp::cantexp;
        VarDeclaration *v = d->isVarDeclaration();
        SymbolDeclaration *s = d->isSymbolDeclaration();
        if (v)
        {
            /* Magic variable __ctfe always returns true when interpreting
             */
            if (v->ident == Id::ctfe)
                return new IntegerExp(loc, 1, Type::tbool);

            if (!v->originalType && v->scope)   // semantic() not yet run
            {
                v->semantic (v->scope);
                if (v->type->ty == Terror)
                    return CTFEExp::cantexp;
            }

            if ((v->isConst() || v->isImmutable() || v->storage_class & STCmanifest) &&
                !hasValue(v) &&
                v->init && !v->isCTFE())
            {
                if (v->scope && !v->inuse)
                    v->init = v->init->semantic(v->scope, v->type, INITinterpret); // might not be run on aggregate members
                {
                    e = v->init->toExpression(v->type);
                }
                if (v->inuse)
                {
                    error(loc, "circular initialization of %s", v->toChars());
                    return CTFEExp::cantexp;
                }

                if (e && (e->op == TOKconstruct || e->op == TOKblit))
                {
                    AssignExp *ae = (AssignExp *)e;
                    e = ae->e2;
                    v->inuse++;
                    e = interpret(e, istate, ctfeNeedAnyValue);
                    v->inuse--;
                    if (CTFEExp::isCantExp(e) && !global.gag && !CtfeStatus::stackTraceCallsToSuppress)
                        errorSupplemental(loc, "while evaluating %s.init", v->toChars());
                    if (exceptionOrCantInterpret(e))
                        return e;
                    e->type = v->type;
                }
                else
                {
                    if (e && !e->type)
                        e->type = v->type;
                    if (e && e->op != TOKerror)
                    {
                        v->inuse++;
                        e = interpret(e, istate, ctfeNeedAnyValue);
                        v->inuse--;
                    }
                    if (CTFEExp::isCantExp(e) && !global.gag && !CtfeStatus::stackTraceCallsToSuppress)
                        errorSupplemental(loc, "while evaluating %s.init", v->toChars());
                }
                if (e && !CTFEExp::isCantExp(e) && e->op != TOKthrownexception)
                {
                    e = copyLiteral(e).copy();
                    if (v->isDataseg() || (v->storage_class & STCmanifest))
                        ctfeStack.saveGlobalConstant(v, e);
                }
            }
            else if (v->isCTFE() && !hasValue(v))
            {
                if (v->init && v->type->size() != 0)
                {
                    if (v->init->isVoidInitializer())
                    {
                        // var should have been initialized when it was created
                        error(loc, "CTFE internal error: trying to access uninitialized var");
                        assert(0);
                        e = CTFEExp::cantexp;
                    }
                    else
                    {
                        e = v->init->toExpression();
                        e = interpret(e, istate);
                    }
                }
                else
                    e = v->type->defaultInitLiteral(e->loc);
            }
            else if (!(v->isDataseg() || v->storage_class & STCmanifest) && !v->isCTFE() && !istate)
            {
                error(loc, "variable %s cannot be read at compile time", v->toChars());
                return CTFEExp::cantexp;
            }
            else
            {
                e = hasValue(v) ? getValue(v) : NULL;
                if (!e && !v->isCTFE() && v->isDataseg())
                {
                    error(loc, "static variable %s cannot be read at compile time", v->toChars());
                    return CTFEExp::cantexp;
                }
                if (!e)
                {
                    assert(!(v->init && v->init->isVoidInitializer()));
                    // CTFE initiated from inside a function
                    error(loc, "variable %s cannot be read at compile time", v->toChars());
                    return CTFEExp::cantexp;
                }
                if (exceptionOrCantInterpret(e))
                    return e;
                if (goal == ctfeNeedLvalue && v->isRef() && e->op == TOKindex)
                {
                    // If it is a foreach ref, resolve the index into a constant
                    IndexExp *ie = (IndexExp *)e;
                    Expression *w = interpret(ie->e2, istate);
                    if (w != ie->e2)
                    {
                        e = new IndexExp(ie->loc, ie->e1, w);
                        e->type = ie->type;
                    }
                    return e;
                }
                if (goal == ctfeNeedLvalue ||
                    e->op == TOKstring ||
                    e->op == TOKstructliteral ||
                    e->op == TOKarrayliteral ||
                    e->op == TOKassocarrayliteral ||
                    e->op == TOKslice ||
                    e->type->toBasetype()->ty == Tpointer)
                {
                    return e; // it's already an Lvalue
                }
                if (e->op == TOKvoid)
                {
                    VoidInitExp *ve = (VoidInitExp *)e;
                    error(loc, "cannot read uninitialized variable %s in ctfe", v->toPrettyChars());
                    errorSupplemental(ve->var->loc, "%s was uninitialized and used before set", ve->var->toChars());
                    return CTFEExp::cantexp;
                }

                e = interpret(e, istate, goal);
            }
            if (!e)
                e = CTFEExp::cantexp;
        }
        else if (s)
        {
            // Struct static initializers, for example
            e = s->dsym->type->defaultInitLiteral(loc);
            if (e->op == TOKerror)
                error(loc, "CTFE failed because of previous errors in %s.init", s->toChars());
            e = e->semantic(NULL);
            if (e->op == TOKerror)
                e = CTFEExp::cantexp;
            else // Convert NULL to CTFEExp
                e = interpret(e, istate, goal);
        }
        else
            error(loc, "cannot interpret declaration %s at compile time", d->toChars());
        return e;
    }

    void visit(VarExp *e)
    {
    #if LOG
        printf("%s VarExp::interpret() %s\n", e->loc.toChars(), e->toChars());
    #endif
        if (goal == ctfeNeedLvalueRef)
        {
            VarDeclaration *v = e->var->isVarDeclaration();
            if (v && !v->isDataseg() && !v->isCTFE() && !istate)
            {
                e->error("variable %s cannot be referenced at compile time", v->toChars());
                result = CTFEExp::cantexp;
                return;
            }
            if (v && !hasValue(v))
            {
                if (!v->isCTFE() && v->isDataseg())
                    e->error("static variable %s cannot be referenced at compile time", v->toChars());
                else     // CTFE initiated from inside a function
                    e->error("variable %s cannot be read at compile time", v->toChars());
                result = CTFEExp::cantexp;
                return;
            }
            if (v && hasValue(v) && getValue(v)->op == TOKvar)
            {
                // A ref of a reference,  is the original reference
                result = getValue(v);
                return;
            }
            result = e;
            return;
        }
        result = getVarExp(e->loc, istate, e->var, goal);
        // A VarExp may include an implicit cast. It must be done explicitly.
        if (!CTFEExp::isCantExp(result) && result->op != TOKthrownexception)
            result = paintTypeOntoLiteral(e->type, result);
    }

    void visit(DeclarationExp *e)
    {
    #if LOG
        printf("%s DeclarationExp::interpret() %s\n", e->loc.toChars(), e->toChars());
    #endif
        VarDeclaration *v = e->declaration->isVarDeclaration();
        if (v)
        {
            if (v->toAlias()->isTupleDeclaration())
            {
                result = NULL;

                // Reserve stack space for all tuple members
                TupleDeclaration *td = v->toAlias()->isTupleDeclaration();
                if (!td->objects)
                    return;
                for (size_t i= 0; i < td->objects->dim; ++i)
                {
                    RootObject * o = (*td->objects)[i];
                    Expression *ex = isExpression(o);
                    DsymbolExp *s = (ex && ex->op == TOKdsymbol) ? (DsymbolExp *)ex : NULL;
                    VarDeclaration *v2 = s ? s->s->isVarDeclaration() : NULL;
                    assert(v2);
                    if (!v2->isDataseg() || v2->isCTFE())
                    {
                        ctfeStack.push(v2);
                        if (v2->init)
                        {
                            ExpInitializer *ie = v2->init->isExpInitializer();
                            if (ie)
                            {
                                setValue(v2, interpret(ie->exp, istate, goal));
                            }
                            else if (v2->init->isVoidInitializer())
                            {
                                setValue(v2, voidInitLiteral(v2->type, v2).copy());
                            }
                            else
                            {
                                e->error("declaration %s is not yet implemented in CTFE", e->toChars());
                                result = CTFEExp::cantexp;
                            }
                        }
                    }
                }
                return;
            }
            if (!(v->isDataseg() || v->storage_class & STCmanifest) || v->isCTFE())
                ctfeStack.push(v);
            Dsymbol *s = v->toAlias();
            if (s == v && !v->isStatic() && v->init)
            {
                ExpInitializer *ie = v->init->isExpInitializer();
                if (ie)
                    result = interpret(ie->exp, istate, goal);
                else if (v->init->isVoidInitializer())
                {
                    result = voidInitLiteral(v->type, v).copy();
                    // There is no AssignExp for void initializers,
                    // so set it here.
                    setValue(v, result);
                }
                else
                {
                    e->error("declaration %s is not yet implemented in CTFE", e->toChars());
                    result = CTFEExp::cantexp;
                }
            }
            else if (s == v && !v->init && v->type->size() == 0)
            {
                // Zero-length arrays don't need an initializer
                result = v->type->defaultInitLiteral(e->loc);
            }
            else if (s == v && (v->isConst() || v->isImmutable()) && v->init)
            {
                result = v->init->toExpression();
                if (!result)
                    result = CTFEExp::cantexp;
                else if (!result->type)
                    result->type = v->type;
            }
            else if (s->isTupleDeclaration() && !v->init)
                result = NULL;
            else if (v->isStatic())
                result = NULL;   // Just ignore static variables which aren't read or written yet
            else
            {
                e->error("variable %s cannot be modified at compile time", v->toChars());
                result = CTFEExp::cantexp;
            }
        }
        else if (e->declaration->isAttribDeclaration() ||
                 e->declaration->isTemplateMixin() ||
                 e->declaration->isTupleDeclaration())
        {
            // Check for static struct declarations, which aren't executable
            AttribDeclaration *ad = e->declaration->isAttribDeclaration();
            if (ad && ad->decl && ad->decl->dim == 1)
            {
                Dsymbol *s = (*ad->decl)[0];
                if (s->isAggregateDeclaration() ||
                    s->isTemplateDeclaration() ||
                    s->isAliasDeclaration())
                {
                    result = NULL;
                    return;         // static (template) struct declaration. Nothing to do.
                }
            }

            // These can be made to work, too lazy now
            e->error("declaration %s is not yet implemented in CTFE", e->toChars());
            result = CTFEExp::cantexp;
        }
        else
        {
            // Others should not contain executable code, so are trivial to evaluate
            result = NULL;
        }
    #if LOG
        printf("-DeclarationExp::interpret(%s): %p\n", e->toChars(), result);
    #endif
    }

    void visit(TupleExp *e)
    {
    #if LOG
        printf("%s TupleExp::interpret() %s\n", e->loc.toChars(), e->toChars());
    #endif
        Expressions *expsx = NULL;

        if (CTFEExp::isCantExp(interpret(e->e0, istate)))
        {
            result = CTFEExp::cantexp;
            return;
        }

        for (size_t i = 0; i < e->exps->dim; i++)
        {
            Expression *exp = (*e->exps)[i];
            Expression *ex = interpret(exp, istate);
            if (exceptionOrCant(ex))
                return;

            // A tuple of assignments can contain void (Bug 5676).
            if (goal == ctfeNeedNothing)
                continue;
            if (ex->op == TOKvoidexp)
            {
                e->error("CTFE internal error: void element %s in tuple", exp->toChars());
                assert(0);
            }

            /* If any changes, do Copy On Write
             */
            if (ex != exp)
            {
                if (!expsx)
                {
                    expsx = new Expressions();
                    ++CtfeStatus::numArrayAllocs;
                    expsx->setDim(e->exps->dim);
                    for (size_t j = 0; j < i; j++)
                    {
                        (*expsx)[j] = (*e->exps)[j];
                    }
                }
                (*expsx)[i] = ex;
            }
        }
        if (expsx)
        {
            TupleExp *te = new TupleExp(e->loc, expsx);
            expandTuples(te->exps);
            te->type = new TypeTuple(te->exps);
            result = te;
            return;
        }
        result = e;
        return;
    }

    void visit(ArrayLiteralExp *e)
    {
    #if LOG
        printf("%s ArrayLiteralExp::interpret() %s\n", e->loc.toChars(), e->toChars());
    #endif
        if (e->ownedByCtfe) // We've already interpreted all the elements
        {
            result = e;
            return;
        }
        Expressions *expsx = NULL;
        size_t dim = e->elements ? e->elements->dim : 0;
        for (size_t i = 0; i < dim; i++)
        {
            Expression *exp = (*e->elements)[i];

            if (exp->op == TOKindex)  // segfault bug 6250
                assert(((IndexExp *)exp)->e1 != e);
            Expression *ex = interpret(exp, istate);
            if (exceptionOrCant(ex))
                return;

            /* If any changes, do Copy On Write
             */
            if (ex != exp)
            {
                if (!expsx)
                {
                    expsx = new Expressions();
                    ++CtfeStatus::numArrayAllocs;
                    expsx->setDim(dim);
                    for (size_t j = 0; j < dim; j++)
                    {
                        (*expsx)[j] = (*e->elements)[j];
                    }
                }
                (*expsx)[i] = ex;
            }
        }
        if (dim && expsx)
        {
            expandTuples(expsx);
            if (expsx->dim != dim)
            {
                e->error("CTFE internal error: invalid array literal");
                result = CTFEExp::cantexp;
                return;
            }
            ArrayLiteralExp *ae = new ArrayLiteralExp(e->loc, expsx);
            ae->type = e->type;
            result = copyLiteral(ae).copy();
            return;
        }
        if (((TypeNext *)e->type)->next->mod & (MODconst | MODimmutable))
        {
            // If it's immutable, we don't need to dup it
            result = e;
            return;
        }
        result = copyLiteral(e).copy();
    }

    void visit(AssocArrayLiteralExp *e)
    {
        Expressions *keysx = e->keys;
        Expressions *valuesx = e->values;

    #if LOG
        printf("%s AssocArrayLiteralExp::interpret() %s\n", e->loc.toChars(), e->toChars());
    #endif
        if (e->ownedByCtfe) // We've already interpreted all the elements
        {
            result = e;
            return;
        }
        for (size_t i = 0; i < e->keys->dim; i++)
        {
            Expression *ekey = (*e->keys)[i];
            Expression *evalue = (*e->values)[i];

            Expression *ex = interpret(ekey, istate);
            if (exceptionOrCant(ex))
                return;

            /* If any changes, do Copy On Write
             */
            if (ex != ekey)
            {
                if (keysx == e->keys)
                    keysx = (Expressions *)e->keys->copy();
                (*keysx)[i] = ex;
            }

            ex = interpret(evalue, istate);
            if (exceptionOrCant(ex))
                return;

            /* If any changes, do Copy On Write
             */
            if (ex != evalue)
            {
                if (valuesx == e->values)
                    valuesx = (Expressions *)e->values->copy();
                (*valuesx)[i] = ex;
            }
        }
        if (keysx != e->keys)
            expandTuples(keysx);
        if (valuesx != e->values)
            expandTuples(valuesx);
        if (keysx->dim != valuesx->dim)
        {
            e->error("CTFE internal error: invalid AA");
            result = CTFEExp::cantexp;
            return;
        }

        /* Remove duplicate keys
         */
        for (size_t i = 1; i < keysx->dim; i++)
        {
            Expression *ekey = (*keysx)[i - 1];
            for (size_t j = i; j < keysx->dim; j++)
            {
                Expression *ekey2 = (*keysx)[j];
                int eq = ctfeEqual(e->loc, TOKequal, ekey, ekey2);
                if (eq)       // if a match
                {
                    // Remove ekey
                    if (keysx == e->keys)
                        keysx = (Expressions *)e->keys->copy();
                    if (valuesx == e->values)
                        valuesx = (Expressions *)e->values->copy();
                    keysx->remove(i - 1);
                    valuesx->remove(i - 1);
                    i -= 1;         // redo the i'th iteration
                    break;
                }
            }
        }

        if (keysx != e->keys || valuesx != e->values)
        {
            AssocArrayLiteralExp *ae;
            ae = new AssocArrayLiteralExp(e->loc, keysx, valuesx);
            ae->type = e->type;
            ae->ownedByCtfe = true;
            result = ae;
            return;
        }
        result = e;
    }

    void visit(StructLiteralExp *e)
    {
    #if LOG
        printf("%s StructLiteralExp::interpret() %s\n", e->loc.toChars(), e->toChars());
    #endif
        if (e->ownedByCtfe)
        {
            result = e;
            return;
        }

        size_t elemdim = e->elements ? e->elements->dim : 0;
        Expressions *expsx = NULL;
        for (size_t i = 0; i < e->sd->fields.dim; i++)
        {
            Expression *ex = NULL;
            Expression *exp = NULL;
            if (i >= elemdim)
            {
                /* If a nested struct has no initialized hidden pointer,
                 * set it to null to match the runtime behaviour.
                 */
                if (i == e->sd->fields.dim - 1 && e->sd->isNested())
                {
                    // Context field has not been filled
                    ex = new NullExp(e->loc);
                    ex->type = e->sd->fields[i]->type;
                }
            }
            else
            {
                exp = (*e->elements)[i];
                if (!exp)
                {
                    /* Ideally, we'd convert NULL members into void expressions.
                    * The problem is that the CTFEExp will be removed when we
                    * leave CTFE, causing another memory allocation if we use this
                    * same struct literal again.
                    *
                    * ex = voidInitLiteral(sd->fields[i]->type, sd->fields[i]).copy();
                    */
                    ex = NULL;
                }
                else
                {
                    ex = interpret(exp, istate);
                    if (exceptionOrCant(ex))
                        return;
                }
            }

            /* If any changes, do Copy On Write
             */
            if (ex != exp)
            {
                if (!expsx)
                {
                    expsx = new Expressions();
                    ++CtfeStatus::numArrayAllocs;
                    expsx->setDim(e->sd->fields.dim);
                    for (size_t j = 0; j < e->elements->dim; j++)
                    {
                        (*expsx)[j] = (*e->elements)[j];
                    }
                }
                (*expsx)[i] = ex;
            }
        }

        if (e->elements && expsx)
        {
            expandTuples(expsx);
            if (expsx->dim != e->sd->fields.dim)
            {
                e->error("CTFE internal error: invalid struct literal");
                result = CTFEExp::cantexp;
                return;
            }
            StructLiteralExp *se = new StructLiteralExp(e->loc, e->sd, expsx);
            se->type = e->type;
            se->ownedByCtfe = true;
            result = se;
            return;
        }
        result = copyLiteral(e).copy();
    }

    // Create an array literal of type 'newtype' with dimensions given by
    // 'arguments'[argnum..$]
    static Expression *recursivelyCreateArrayLiteral(Loc loc, Type *newtype, InterState *istate,
        Expressions *arguments, int argnum)
    {
        Expression *lenExpr = interpret((*arguments)[argnum], istate);
        if (exceptionOrCantInterpret(lenExpr))
            return lenExpr;
        size_t len = (size_t)(lenExpr->toInteger());
        Type *elemType = ((TypeArray *)newtype)->next;
        if (elemType->ty == Tarray && argnum < arguments->dim - 1)
        {
            Expression *elem = recursivelyCreateArrayLiteral(loc, elemType, istate,
                arguments, argnum + 1);
            if (exceptionOrCantInterpret(elem))
                return elem;

            Expressions *elements = new Expressions();
            elements->setDim(len);
            for (size_t i = 0; i < len; i++)
                 (*elements)[i] = copyLiteral(elem).copy();
            ArrayLiteralExp *ae = new ArrayLiteralExp(loc, elements);
            ae->type = newtype;
            ae->ownedByCtfe = true;
            return ae;
        }
        assert(argnum == arguments->dim - 1);
        if (elemType->ty == Tchar || elemType->ty == Twchar || elemType->ty == Tdchar)
            return createBlockDuplicatedStringLiteral(loc, newtype,
                (unsigned)(elemType->defaultInitLiteral(loc)->toInteger()),
                len, (unsigned char)elemType->size());
        return createBlockDuplicatedArrayLiteral(loc, newtype,
            elemType->defaultInitLiteral(loc), len);
    }

    void visit(NewExp *e)
    {
    #if LOG
        printf("%s NewExp::interpret() %s\n", e->loc.toChars(), e->toChars());
    #endif

        if (e->allocator)
        {
            e->error("member allocators not supported by CTFE");
            result = CTFEExp::cantexp;
            return;
        }

        result = interpret(e->argprefix, istate, ctfeNeedNothing);
        if (exceptionOrCant(result))
            return;

        if (e->newtype->ty == Tarray && e->arguments)
        {
            result = recursivelyCreateArrayLiteral(e->loc, e->newtype, istate, e->arguments, 0);
            return;
        }

        if (e->newtype->toBasetype()->ty == Tstruct)
        {
            if (e->member)
            {
                Expression *se = e->newtype->defaultInitLiteral(e->loc);
                result = interpret(e->member, istate, e->arguments, se);
            }
            else
            {
                StructDeclaration *sd = ((TypeStruct *)e->newtype->toBasetype())->sym;
                Expressions *exps = new Expressions();
                exps->reserve(sd->fields.dim);
                if (e->arguments)
                {
                    exps->setDim(e->arguments->dim);
                    for (size_t i = 0; i < exps->dim; i++)
                    {
                        Expression *ex = (*e->arguments)[i];
                        ex = interpret(ex, istate);
                        if (exceptionOrCant(ex))
                            return;
                        (*exps)[i] = ex;
                    }
                }
                sd->fill(e->loc, exps, false);

                StructLiteralExp *se = new StructLiteralExp(e->loc, sd, exps, e->newtype);
                se->type = e->newtype;
                se->ownedByCtfe = true;
                result = interpret(se, istate);
            }
            if (exceptionOrCantInterpret(result))
            {
                result = CTFEExp::cantexp;
                return;
            }
            result = new AddrExp(e->loc, copyLiteral(result).copy());
            result->type = e->type;
            return;
        }
        if (e->newtype->toBasetype()->ty == Tclass)
        {
            ClassDeclaration *cd = ((TypeClass *)e->newtype->toBasetype())->sym;
            size_t totalFieldCount = 0;
            for (ClassDeclaration *c = cd; c; c = c->baseClass)
                totalFieldCount += c->fields.dim;
            Expressions *elems = new Expressions;
            elems->setDim(totalFieldCount);
            size_t fieldsSoFar = totalFieldCount;
            for (ClassDeclaration *c = cd; c; c = c->baseClass)
            {
                fieldsSoFar -= c->fields.dim;
                for (size_t i = 0; i < c->fields.dim; i++)
                {
                    VarDeclaration *v = c->fields[i];
                    if (v->inuse)
                    {
                        e->error("circular reference to '%s'", v->toPrettyChars());
                        result = CTFEExp::cantexp;
                        return;
                    }
                    Expression *m;
                    if (v->init)
                    {
                        if (v->init->isVoidInitializer())
                            m = voidInitLiteral(v->type, v).copy();
                        else
                            m = v->getConstInitializer(true);
                    }
                    else
                        m = v->type->defaultInitLiteral(e->loc);
                    if (exceptionOrCant(m))
                        return;
                    (*elems)[fieldsSoFar+i] = copyLiteral(m).copy();
                }
            }
            // Hack: we store a ClassDeclaration instead of a StructDeclaration.
            // We probably won't get away with this.
            StructLiteralExp *se = new StructLiteralExp(e->loc, (StructDeclaration *)cd, elems, e->newtype);
            se->ownedByCtfe = true;
            Expression *eref = new ClassReferenceExp(e->loc, se, e->type);
            if (e->member)
            {
                // Call constructor
                if (!e->member->fbody)
                {
                    Expression *ctorfail = evaluateIfBuiltin(istate, e->loc, e->member, e->arguments, eref);
                    if (ctorfail && exceptionOrCant(ctorfail))
                        return;
                    if (ctorfail)
                    {
                        result = eref;
                        return;
                    }
                    e->member->error("%s cannot be constructed at compile time, because the constructor has no available source code", e->newtype->toChars());
                    result = CTFEExp::cantexp;
                    return;
                }
                Expression *ctorfail = interpret(e->member, istate, e->arguments, eref);
                if (exceptionOrCant(ctorfail))
                    return;
            }
            result = eref;
            return;
        }
        if (e->newtype->toBasetype()->isscalar())
        {
            Expression *newval;
            if (e->arguments && e->arguments->dim)
                newval = interpret((*e->arguments)[0], istate);
            else
                newval = e->newtype->defaultInitLiteral(e->loc);
            if (exceptionOrCant(newval))
                return;

            /* Create &[newval][0]
             */
            Expressions *elements = new Expressions();
            elements->setDim(1);
            (*elements)[0] = copyLiteral(newval).copy();
            ArrayLiteralExp *ae = new ArrayLiteralExp(e->loc, elements);
            ae->type = e->newtype->arrayOf();
            ae->ownedByCtfe = true;

            result = new IndexExp(e->loc, ae, new IntegerExp(Loc(), 0, Type::tsize_t));
            result->type = e->newtype;

            result = new AddrExp(e->loc, result);
            result->type = e->type;
            return;
        }
        e->error("cannot interpret %s at compile time", e->toChars());
        result = CTFEExp::cantexp;
    }

    void visit(UnaExp *e)
    {
    #if LOG
        printf("%s UnaExp::interpret() %s\n", e->loc.toChars(), e->toChars());
    #endif
        if (e->op == TOKdottype)
        {
            e->error("CTFE internal error: dottype: %s", e->toChars());
            result = CTFEExp::cantexp;
            return;
        }
        Expression *e1 = interpret(e->e1, istate);
        if (exceptionOrCant(e1))
            return;
        UnionExp ue;
        switch (e->op)
        {
            case TOKneg:    ue = Neg(e->type, e1); break;
            case TOKtilde:  ue = Com(e->type, e1); break;
            case TOKnot:    ue = Not(e->type, e1); break;
            case TOKtobool: ue = Bool(e->type, e1); break;
            case TOKvector: result = e; return; // do nothing
            default: assert(0);
        }
        result = ue.copy();
    }

    void interpretCommon(BinExp *e, fp_t fp)
    {
    #if LOG
        printf("%s BinExp::interpretCommon() %s\n", e->loc.toChars(), e->toChars());
    #endif
        if (e->e1->type->ty == Tpointer && e->e2->type->ty == Tpointer && e->op == TOKmin)
        {
            Expression *e1 = interpret(e->e1, istate, ctfeNeedLvalue);
            if (exceptionOrCant(e1))
                return;
            Expression *e2 = interpret(e->e2, istate, ctfeNeedLvalue);
            if (exceptionOrCant(e2))
                return;
            result = pointerDifference(e->loc, e->type, e1, e2).copy();
            return;
        }
        if (e->e1->type->ty == Tpointer && e->e2->type->isintegral())
        {
            Expression *e1 = interpret(e->e1, istate, ctfeNeedLvalue);
            if (exceptionOrCant(e1))
                return;
            Expression *e2 = interpret(e->e2, istate);
            if (exceptionOrCant(e2))
                return;
            result = pointerArithmetic(e->loc, e->op, e->type, e1, e2).copy();
            return;
        }
        if (e->e2->type->ty == Tpointer && e->e1->type->isintegral() && e->op == TOKadd)
        {
            Expression *e1 = interpret(e->e1, istate);
            if (exceptionOrCant(e1))
                return;
            Expression *e2 = interpret(e->e2, istate, ctfeNeedLvalue);
            if (exceptionOrCant(e2))
                return;
            result = pointerArithmetic(e->loc, e->op, e->type, e2, e1).copy();
            return;
        }
        if (e->e1->type->ty == Tpointer || e->e2->type->ty == Tpointer)
        {
            e->error("pointer expression %s cannot be interpreted at compile time", e->toChars());
            result = CTFEExp::cantexp;
            return;
        }
        Expression *e1 = interpret(e->e1, istate);
        if (exceptionOrCant(e1))
            return;
        if (e1->isConst() != 1)
        {
            e->error("CTFE internal error: non-constant value %s", e->e1->toChars());
            result = CTFEExp::cantexp;
            return;
        }

        Expression *e2 = interpret(e->e2, istate);
        if (exceptionOrCant(e2))
            return;
        if (e2->isConst() != 1)
        {
            e->error("CTFE internal error: non-constant value %s", e->e2->toChars());
            result = CTFEExp::cantexp;
            return;
        }

        if (e->op == TOKshr || e->op == TOKshl || e->op == TOKushr)
        {
            sinteger_t i2 = e2->toInteger();
            d_uns64 sz = e1->type->size() * 8;
            if (i2 < 0 || i2 >= sz)
            {
                e->error("shift by %lld is outside the range 0..%llu", i2, (ulonglong)sz - 1);
                result = CTFEExp::cantexp;
                return;
            }
        }
        result = (*fp)(e->type, e1, e2).copy();
        if (CTFEExp::isCantExp(result))
            e->error("%s cannot be interpreted at compile time", e->toChars());
    }

    void interpretCompareCommon(BinExp *e, fp2_t fp)
    {
    #if LOG
        printf("%s BinExp::interpretCompareCommon() %s\n", e->loc.toChars(), e->toChars());
    #endif
        if (e->e1->type->ty == Tpointer && e->e2->type->ty == Tpointer)
        {
            Expression *e1 = interpret(e->e1, istate);
            if (exceptionOrCant(e1))
                return;
            Expression *e2 = interpret(e->e2, istate);
            if (exceptionOrCant(e2))
                return;
            dinteger_t ofs1, ofs2;
            Expression *agg1 = getAggregateFromPointer(e1, &ofs1);
            Expression *agg2 = getAggregateFromPointer(e2, &ofs2);
            int cmp = comparePointers(e->loc, e->op, e->type, agg1, ofs1, agg2, ofs2);
            if (cmp == -1)
            {
               char dir = (e->op == TOKgt || e->op == TOKge) ? '<' : '>';
               e->error("the ordering of pointers to unrelated memory blocks is indeterminate in CTFE."
                     " To check if they point to the same memory block, use both > and < inside && or ||, "
                     "eg (%s && %s %c= %s + 1)",
                     e->toChars(), e->e1->toChars(), dir, e->e2->toChars());
              result = CTFEExp::cantexp;
              return;
            }
            result = new IntegerExp(e->loc, cmp, e->type);
            return;
        }
        Expression *e1 = interpret(e->e1, istate);
        if (exceptionOrCant(e1))
            return;
        if (!isCtfeComparable(e1))
        {
            e->error("cannot compare %s at compile time", e1->toChars());
            result = CTFEExp::cantexp;
            return;
        }
        Expression *e2 = interpret(e->e2, istate);
        if (exceptionOrCant(e2))
            return;
        if (!isCtfeComparable(e2))
        {
            e->error("cannot compare %s at compile time", e2->toChars());
            result = CTFEExp::cantexp;
            return;
        }
        int cmp = (*fp)(e->loc, e->op, e1, e2);
        result = new IntegerExp(e->loc, cmp, e->type);
    }

    void visit(BinExp *e)
    {
        switch (e->op)
        {
        case TOKadd:  interpretCommon(e, &Add); return;
        case TOKmin:  interpretCommon(e, &Min); return;
        case TOKmul:  interpretCommon(e, &Mul); return;
        case TOKdiv:  interpretCommon(e, &Div); return;
        case TOKmod:  interpretCommon(e, &Mod); return;
        case TOKshl:  interpretCommon(e, &Shl); return;
        case TOKshr:  interpretCommon(e, &Shr); return;
        case TOKushr: interpretCommon(e, &Ushr); return;
        case TOKand:  interpretCommon(e, &And); return;
        case TOKor:   interpretCommon(e, &Or); return;
        case TOKxor:  interpretCommon(e, &Xor); return;
        case TOKpow:  interpretCommon(e, &Pow); return;
        case TOKequal:
        case TOKnotequal:
            interpretCompareCommon(e, &ctfeEqual);
            return;
        case TOKidentity:
        case TOKnotidentity:
            interpretCompareCommon(e, &ctfeIdentity);
            return;
        case TOKlt:
        case TOKle:
        case TOKgt:
        case TOKge:
        case TOKleg:
        case TOKlg:
        case TOKunord:
        case TOKue:
        case TOKug:
        case TOKuge:
        case TOKul:
        case TOKule:
            interpretCompareCommon(e, &ctfeCmp);
            return;
        default:
            printf("be = '%s' %s at [%s]\n", Token::toChars(e->op), e->toChars(), e->loc.toChars());
            assert(0);
            return;
        }
    }

    /* Helper functions for BinExp::interpretAssignCommon
     */

    // Returns the variable which is eventually modified, or NULL if an rvalue.
    // thisval is the current value of 'this'.
    static VarDeclaration *findParentVar(Expression *e)
    {
        for (;;)
        {
            e = resolveReferences(e);
            if (e->op == TOKvar)
                break;
            if (e->op == TOKindex)
                e = ((IndexExp *)e)->e1;
            else if (e->op == TOKdotvar)
                e = ((DotVarExp *)e)->e1;
            else if (e->op == TOKdotti)
                e = ((DotTemplateInstanceExp *)e)->e1;
            else if (e->op == TOKslice)
                e = ((SliceExp *)e)->e1;
            else
                return NULL;
        }
        VarDeclaration *v = ((VarExp *)e)->var->isVarDeclaration();
        assert(v);
        return v;
    }

    void interpretAssignCommon(BinExp *e, fp_t fp, int post = 0)
    {
    #if LOG
        printf("%s BinExp::interpretAssignCommon() %s\n", e->loc.toChars(), e->toChars());
    #endif
        result = CTFEExp::cantexp;
        Expression *e1 = e->e1;
        if (!istate)
        {
            e->error("value of %s is not known at compile time", e1->toChars());
            return;
        }
        ++CtfeStatus::numAssignments;
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
            Type *srctype = e->e2->type->toBasetype()->castMod(0);
            while (desttype->ty == Tsarray || desttype->ty == Tarray)
            {
                desttype = ((TypeArray *)desttype)->next;
                desttype = desttype->toBasetype()->castMod(0);
                if (srctype->equals(desttype))
                {
                    isBlockAssignment = true;
                    break;
                }
            }
        }
        // If it is a reference type (eg, an array), we need an lvalue.
        // If it is a reference variable (such as happens in foreach), we
        // need an lvalue reference. For example if x, y are int[], then
        // y[0..4] = x[0..4] is an rvalue assignment (all copies in the
        //   slice are duplicated)
        // y = x[0..4] is an lvalue assignment (if x[0] changes later,
        //    y[0] will also change)
        // ref int [] z = x is an lvalueref assignment (if x itself changes,
        //   z will also change)
        bool wantRef = false;
        bool wantLvalueRef = false;

        //  e = *x is never a reference, because *x is always a value
        if (!fp && e->e1->type->toBasetype()->equals(e->e2->type->toBasetype()) &&
            (e1->type->toBasetype()->ty == Tarray || isAssocArray(e1->type) ||
             e1->type->toBasetype()->ty == Tclass) &&
            e->e2->op != TOKstar)
        {
            wantRef = true;
            // If it is assignment from a ref parameter, it's not a ref assignment
            if (e->e2->op == TOKvar)
            {
                VarDeclaration *v = ((VarExp *)e->e2)->var->isVarDeclaration();
                if (v && (v->storage_class & (STCref | STCout)))
                    wantRef = false;
            }
        }
        if (isBlockAssignment && (e->e2->type->toBasetype()->ty == Tarray))
        {
            wantRef = true;
        }
        // If it is a construction of a ref variable, it is a ref assignment
        // (in fact, it is an lvalue reference assignment).
        if (e->op == TOKconstruct && e->e1->op == TOKvar &&
            ((VarExp *)e->e1)->var->storage_class & STCref)
        {
            wantRef = true;
            wantLvalueRef = true;
        }

        if (fp)
        {
            while (e1->op == TOKcast)
            {
                CastExp *ce = (CastExp *)e1;
                e1 = ce->e1;
            }
        }
        if (exceptionOrCant(e1))
            return;

        // First, deal with  this = e; and call() = e;
        if (e1->op == TOKthis)
        {
            e1 = ctfeStack.getThis();
        }
        if (e1->op == TOKcall)
        {
            bool oldWaiting = istate->awaitingLvalueReturn;
            istate->awaitingLvalueReturn = true;
            e1 = interpret(e1, istate);
            istate->awaitingLvalueReturn = oldWaiting;
            if (exceptionOrCant(e1))
                return;
            if (e1->op == TOKarrayliteral || e1->op == TOKstring)
            {
                // f() = e2, when f returns an array, is always a slice assignment.
                // Convert into arr[0..arr.length] = e2
                e1 = new SliceExp(e->loc, e1,
                    new IntegerExp(e->loc, 0, Type::tsize_t),
                    ArrayLength(Type::tsize_t, e1).copy());
                e1->type = e->type;
            }
        }
        if (e1->op == TOKstar)
        {
            e1 = interpret(e1, istate, ctfeNeedLvalue);
            if (exceptionOrCant(e1))
                return;
            if (!(e1->op == TOKvar || e1->op == TOKdotvar || e1->op == TOKindex ||
                  e1->op == TOKslice || e1->op == TOKstructliteral))
            {
                e->error("cannot dereference invalid pointer %s",
                    e->e1->toChars());
                result = CTFEExp::cantexp;
                return;
            }
        }

        if (!(e1->op == TOKarraylength || e1->op == TOKvar || e1->op == TOKdotvar ||
              e1->op == TOKindex || e1->op == TOKslice || e1->op == TOKstructliteral))
        {
            e->error("CTFE internal error: unsupported assignment %s", e->toChars());
            result = CTFEExp::cantexp;
            return;
        }

        Expression * newval = NULL;

        if (!wantRef)
        {
            // We need to treat pointers specially, because TOKsymoff can be used to
            // return a value OR a pointer
            assert(e1);
            assert(e1->type);
            if (isPointer(e1->type) && (e->e2->op == TOKsymoff || e->e2->op == TOKaddress || e->e2->op == TOKvar))
                newval = interpret(e->e2, istate, ctfeNeedLvalue);
            else
                newval = interpret(e->e2, istate);
            if (exceptionOrCant(newval))
                return;
        }
        // ----------------------------------------------------
        //  Deal with read-modify-write assignments.
        //  Set 'newval' to the final assignment value
        //  Also determine the return value (except for slice
        //  assignments, which are more complicated)
        // ----------------------------------------------------

        if (fp || e1->op == TOKarraylength)
        {
            // If it isn't a simple assignment, we need the existing value
            Expression * oldval = interpret(e1, istate);
            if (exceptionOrCant(oldval))
                return;
            while (oldval->op == TOKvar)
            {
                oldval = resolveReferences(oldval);
                oldval = interpret(oldval, istate);
                if (exceptionOrCant(oldval))
                    return;
            }

            if (fp)
            {
                // ~= can create new values (see bug 6052)
                if (e->op == TOKcatass)
                {
                    // We need to dup it. We can skip this if it's a dynamic array,
                    // because it gets copied later anyway
                    if (newval->type->ty != Tarray)
                        newval = copyLiteral(newval).copy();
                    if (newval->op == TOKslice)
                        newval = resolveSlice(newval);
                    // It becomes a reference assignment
                    wantRef = true;
                }
                if (oldval->op == TOKslice)
                    oldval = resolveSlice(oldval);
                if (e->e1->type->ty == Tpointer && e->e2->type->isintegral() &&
                    (e->op == TOKaddass || e->op == TOKminass ||
                     e->op == TOKplusplus || e->op == TOKminusminus))
                {
                    oldval = interpret(e->e1, istate, ctfeNeedLvalue);
                    if (exceptionOrCant(oldval))
                        return;
                    newval = interpret(e->e2, istate);
                    if (exceptionOrCant(newval))
                        return;
                    newval = pointerArithmetic(e->loc, e->op, e->type, oldval, newval).copy();
                }
                else if (e->e1->type->ty == Tpointer)
                {
                    e->error("pointer expression %s cannot be interpreted at compile time", e->toChars());
                    result = CTFEExp::cantexp;
                    return;
                }
                else
                {
                    newval = (*fp)(e->type, oldval, newval).copy();
                }
                if (CTFEExp::isCantExp(newval))
                {
                    e->error("cannot interpret %s at compile time", e->toChars());
                    result = CTFEExp::cantexp;
                    return;
                }
                if (exceptionOrCant(newval))
                    return;
                // Determine the return value
                result = ctfeCast(e->loc, e->type, e->type, post ? oldval : newval);
                if (exceptionOrCant(result))
                    return;
            }
            else
                result = newval;
            if (e1->op == TOKarraylength)
            {
                size_t oldlen = (size_t)oldval->toInteger();
                size_t newlen = (size_t)newval->toInteger();
                if (oldlen == newlen) // no change required -- we're done!
                    return;
                // Now change the assignment from arr.length = n into arr = newval
                e1 = ((ArrayLengthExp *)e1)->e1;
                if (oldlen != 0)
                {
                    // Get the old array literal.
                    oldval = interpret(e1, istate);
                    while (oldval->op == TOKvar)
                    {
                        oldval = resolveReferences(oldval);
                        oldval = interpret(oldval, istate);
                    }
                }
                Type *t = e1->type->toBasetype();
                if (t->ty == Tarray)
                {
                    newval = changeArrayLiteralLength(e->loc, (TypeArray *)t, oldval,
                        oldlen,  newlen).copy();
                    // We have changed it into a reference assignment
                    // Note that returnValue is still the new length.
                    wantRef = true;
                    if (e1->op == TOKstar)
                    {
                        // arr.length+=n becomes (t=&arr, *(t).length=*(t).length+n);
                        e1 = interpret(e1, istate, ctfeNeedLvalue);
                        if (exceptionOrCant(e1))
                            return;
                    }
                }
                else
                {
                    e->error("%s is not yet supported at compile time", e->toChars());
                    result = CTFEExp::cantexp;
                    return;
                }

            }
        }
        else if (!wantRef && e1->op != TOKslice)
        {
            /* Look for special case of struct being initialized with 0.
            */
            if (e->type->toBasetype()->ty == Tstruct && newval->op == TOKint64)
            {
                newval = e->type->defaultInitLiteral(e->loc);
                if (newval->op != TOKstructliteral)
                {
                    e->error("nested structs with constructors are not yet supported in CTFE (Bug 6419)");
                    result = CTFEExp::cantexp;
                    return;
                }
            }
            newval = ctfeCast(e->loc, e->type, e->type, newval);
            if (exceptionOrCant(newval))
                return;
            result = newval;
        }
        if (exceptionOrCant(newval))
            return;

        // -------------------------------------------------
        //         Make sure destination can be modified
        // -------------------------------------------------
        // Make sure we're not trying to modify a global or static variable
        // We do this by locating the ultimate parent variable which gets modified.
        VarDeclaration * ultimateVar = findParentVar(e1);
        if (ultimateVar && ultimateVar->isDataseg() && !ultimateVar->isCTFE())
        {
            // Can't modify global or static data
            e->error("%s cannot be modified at compile time", ultimateVar->toChars());
            result = CTFEExp::cantexp;
            return;
        }

        e1 = resolveReferences(e1);

        // Unless we have a simple var assignment, we're
        // only modifying part of the variable. So we need to make sure
        // that the parent variable exists.
        if (e1->op != TOKvar && ultimateVar && !getValue(ultimateVar))
            setValue(ultimateVar, copyLiteral(ultimateVar->type->defaultInitLiteral(e->loc)).copy());

        // ---------------------------------------
        //      Deal with reference assignment
        // (We already have 'newval' for arraylength operations)
        // ---------------------------------------
        if (wantRef && !fp && e->e1->op != TOKarraylength)
        {
            CtfeGoal e2goal;
            if (wantLvalueRef)
                e2goal = ctfeNeedLvalueRef; // for internal ref variable initializing
            else if (e->e2->type->ty == Tarray || e->e2->type->ty == Tclass)
                e2goal = ctfeNeedRvalue;    // for assignment of reference types
            else
                e2goal = ctfeNeedLvalue;    // other types
            newval = interpret(e->e2, istate, e2goal);
            if (exceptionOrCant(newval))
                return;

            // If it is an assignment from a array function parameter passed by
            // reference, resolve the reference. (This should NOT happen for
            // non-reference types).
            if (newval->op == TOKvar && (newval->type->ty == Tarray ||
                newval->type->ty == Tclass))
            {
                newval = interpret(newval, istate);
            }

            if (newval->op == TOKassocarrayliteral || newval->op == TOKstring ||
                newval->op == TOKarrayliteral)
            {
                if (needToCopyLiteral(newval))
                    newval = copyLiteral(newval).copy();
            }

            // Get the value to return. Note that 'newval' is an Lvalue,
            // so if we need an Rvalue, we have to interpret again.
            if (goal == ctfeNeedRvalue)
                result = interpret(newval, istate);
            else
                result = newval;
        }

        // ---------------------------------------
        //      Deal with AA index assignment
        // ---------------------------------------
        /* This needs special treatment if the AA doesn't exist yet.
         * There are two special cases:
         * (1) If the AA is itself an index of another AA, we may need to create
         * multiple nested AA literals before we can insert the new value.
         * (2) If the ultimate AA is null, no insertion happens at all. Instead, we
         * create nested AA literals, and change it into a assignment.
         */
        if (e1->op == TOKindex && ((IndexExp *)e1)->e1->type->toBasetype()->ty == Taarray)
        {
            IndexExp *ie = (IndexExp *)e1;
            int depth = 0; // how many nested AA indices are there?
            while (ie->e1->op == TOKindex && ((IndexExp *)ie->e1)->e1->type->toBasetype()->ty == Taarray)
            {
                ie = (IndexExp *)ie->e1;
                ++depth;
            }
            Expression *aggregate = resolveReferences(ie->e1);
            Expression *oldagg = aggregate;
            // Get the AA to be modified. (We do an LvalueRef interpret, unless it
            // is a simple ref parameter -- in which case, we just want the value)
            aggregate = interpret(aggregate, istate, ctfeNeedLvalue);
            if (exceptionOrCant(aggregate))
                return;
            if (aggregate->op == TOKassocarrayliteral)
            {
                // Normal case, ultimate parent AA already exists
                // We need to walk from the deepest index up, checking that an AA literal
                // already exists on each level.
                Expression *index = interpret(((IndexExp *)e1)->e2, istate);
                if (exceptionOrCant(index))
                    return;
                if (index->op == TOKslice)  // only happens with AA assignment
                    index = resolveSlice(index);
                AssocArrayLiteralExp *existingAA = (AssocArrayLiteralExp *)aggregate;
                while (depth > 0)
                {
                    // Walk the syntax tree to find the indexExp at this depth
                    IndexExp *xe = (IndexExp *)e1;
                    for (int d= 0; d < depth; ++d)
                        xe = (IndexExp *)xe->e1;

                    Expression *indx = interpret(xe->e2, istate);
                    if (exceptionOrCant(indx))
                        return;
                    if (indx->op == TOKslice)  // only happens with AA assignment
                        indx = resolveSlice(indx);

                    // Look up this index in it up in the existing AA, to get the next level of AA.
                    AssocArrayLiteralExp *newAA = (AssocArrayLiteralExp *)findKeyInAA(e->loc, existingAA, indx);
                    if (exceptionOrCant(newAA))
                        return;
                    if (!newAA)
                    {
                        // Doesn't exist yet, create an empty AA...
                        Expressions *valuesx = new Expressions();
                        Expressions *keysx = new Expressions();
                        newAA = new AssocArrayLiteralExp(e->loc, keysx, valuesx);
                        newAA->type = xe->type;
                        newAA->ownedByCtfe = true;
                        //... and insert it into the existing AA.
                        existingAA->keys->push(indx);
                        existingAA->values->push(newAA);
                    }
                    existingAA = newAA;
                    --depth;
                }
                if (CTFEExp::isCantExp(assignAssocArrayElement(e->loc, existingAA, index, newval)))
                {
                    result = CTFEExp::cantexp;
                    return;
                }
                return;
            }
            else
            {
                /* The AA is currently null. 'aggregate' is actually a reference to
                 * whatever contains it. It could be anything: var, dotvarexp, ...
                 * We rewrite the assignment from: aggregate[i][j] = newval;
                 *                           into: aggregate = [i:[j: newval]];
                 */
                while (e1->op == TOKindex && ((IndexExp *)e1)->e1->type->toBasetype()->ty == Taarray)
                {
                    Expression *index = interpret(((IndexExp *)e1)->e2, istate);
                    if (exceptionOrCant(index))
                        return;
                    if (index->op == TOKslice)  // only happens with AA assignment
                        index = resolveSlice(index);
                    Expressions *valuesx = new Expressions();
                    Expressions *keysx = new Expressions();
                    valuesx->push(newval);
                    keysx->push(index);
                    AssocArrayLiteralExp *newaae = new AssocArrayLiteralExp(e->loc, keysx, valuesx);
                    newaae->ownedByCtfe = true;
                    newaae->type = ((IndexExp *)e1)->e1->type;
                    newval = newaae;
                    e1 = ((IndexExp *)e1)->e1;
                }
                // We must return to the original aggregate, in case it was a reference
                wantRef = true;
                e1 = oldagg;
                // fall through -- let the normal assignment logic take care of it
            }
        }

        // ---------------------------------------
        //      Deal with dotvar expressions
        // ---------------------------------------
        // Because structs are not reference types, dotvar expressions can be
        // collapsed into a single assignment.
        if (!wantRef && e1->op == TOKdotvar)
        {
            // Strip of all of the leading dotvars, unless it is a CTFE dotvar
            // pointer or reference
            // (in which case, we already have the lvalue).
            DotVarExp *dve = (DotVarExp *)e1;
            bool isCtfePointer = (dve->e1->op == TOKstructliteral) &&
                                 ((StructLiteralExp *)(dve->e1))->ownedByCtfe;
            if (!isCtfePointer)
            {
                e1 = interpret(e1, istate, isPointer(e->type) ? ctfeNeedLvalueRef : ctfeNeedLvalue);
                if (exceptionOrCant(e1))
                    return;
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
            Type *t1b = e1->type->toBasetype();
            if (wantRef)
            {
                setValueNull(v);
                setValue(v, newval);
            }
            else if (t1b->ty == Tstruct)
            {
                // In-place modification
                if (newval->op != TOKstructliteral)
                {
                    e->error("CTFE internal error: assigning struct");
                    result = CTFEExp::cantexp;
                    return;
                }
                newval = copyLiteral(newval).copy();
                if (getValue(v))
                    assignInPlace(getValue(v), newval);
                else
                    setValue(v, newval);
            }
            else if (t1b->ty == Tsarray)
            {
                if (newval->op == TOKslice)
                {
                    // Newly set value is non-ref static array,
                    // so making new ArrayLiteralExp is legitimate.
                    newval = resolveSlice(newval);
                    assert(newval->op == TOKarrayliteral);
                    ((ArrayLiteralExp *)newval)->ownedByCtfe = true;
                }
                if (e->op == TOKassign)
                {
                    Expression *oldval = getValue(v);
                    assert(oldval->op == TOKarrayliteral);
                    assert(newval->op == TOKarrayliteral);

                    Expressions *oldelems = ((ArrayLiteralExp *)oldval)->elements;
                    Expressions *newelems = ((ArrayLiteralExp *)newval)->elements;
                    assert(oldelems->dim == newelems->dim);

                    Type *elemtype = oldval->type->nextOf();
                    for (size_t j = 0; j < newelems->dim; j++)
                    {
                        Expression *newelem = paintTypeOntoLiteral(elemtype, (*newelems)[j]);
                        // Bugzilla 9245
                        if (Expression *x = evaluatePostblit(istate, newelem))
                        {
                            result = x;
                            return;
                        }
                        // Bugzilla 13661
                        if (Expression *x = evaluateDtor(istate, (*oldelems)[j]))
                        {
                            result = x;
                            return;
                        }
                        (*oldelems)[j] = newelem;
                    }
                }
                else
                {
                    setValue(v, newval);

                    if (e->op == TOKconstruct && e->e2->isLvalue())
                    {
                        // Bugzilla 9245
                        if (Expression *x = evaluatePostblit(istate, newval))
                        {
                            result = x;
                            return;
                        }
                    }
                }
                return;
            }
            else
            {
                if (t1b->ty == Tarray || t1b->ty == Taarray)
                {
                    // arr op= arr
                    setValue(v, newval);
                }
                else
                {
                    setValue(v, newval);
                }
            }
        }
        else if (e1->op == TOKstructliteral && newval->op == TOKstructliteral)
        {
            /* Assignment to complete struct of the form:
             *  e1 = newval
             * (e1 was a ref parameter, or was created via TOKstar dereferencing).
             */
            assignInPlace(e1, newval);
            return;
        }
        else if (e1->op == TOKdotvar)
        {
            /* Assignment to member variable of the form:
             *  e.v = newval
             */
            Expression *exx = ((DotVarExp *)e1)->e1;
            if (wantRef && exx->op != TOKstructliteral)
            {
                exx = interpret(exx, istate);
                if (exceptionOrCant(exx))
                    return;
            }
            if (exx->op != TOKstructliteral && exx->op != TOKclassreference)
            {
                e->error("CTFE internal error: dotvar assignment");
                result = CTFEExp::cantexp;
                return;
            }
            VarDeclaration *member = ((DotVarExp *)e1)->var->isVarDeclaration();
            if (!member)
            {
                e->error("CTFE internal error: dotvar assignment");
                result = CTFEExp::cantexp;
                return;
            }
            StructLiteralExp *se = exx->op == TOKstructliteral
                ? (StructLiteralExp *)exx
                : ((ClassReferenceExp *)exx)->value;
            int fieldi =  exx->op == TOKstructliteral
                ? findFieldIndexByName(se->sd, member)
                : ((ClassReferenceExp *)exx)->findFieldIndexByName(member);
            if (fieldi == -1)
            {
                e->error("CTFE internal error: cannot find field %s in %s", member->toChars(), exx->toChars());
                result = CTFEExp::cantexp;
                return;
            }
            assert(fieldi >= 0 && fieldi < se->elements->dim);
            // If it's a union, set all other members of this union to void
            if (exx->op == TOKstructliteral)
            {
                assert(se->sd);
                int unionStart = se->sd->firstFieldInUnion(fieldi);
                int unionSize = se->sd->numFieldsInUnion(fieldi);
                for (int i = unionStart; i < unionStart + unionSize; ++i)
                {
                    if (i == fieldi)
                        continue;
                    Expression **exp = &(*se->elements)[i];
                    if ((*exp)->op != TOKvoid)
                        *exp = voidInitLiteral((*exp)->type, member).copy();
                }
            }

            if (newval->op == TOKstructliteral)
                assignInPlace((*se->elements)[fieldi], newval);
            else
                (*se->elements)[fieldi] = newval;
            return;
        }
        else if (e1->op == TOKindex)
        {
            if (!interpretAssignToIndex(e->loc, (IndexExp *)e1, newval,
                wantRef, e))
            {
                result = CTFEExp::cantexp;
            }
            return;
        }
        else if (e1->op == TOKslice)
        {
            // Note that slice assignments don't support things like ++, so
            // we don't need to remember 'returnValue'.
            result = interpretAssignToSlice(e->loc, (SliceExp *)e1,
                newval, wantRef, isBlockAssignment, e);
            return;
        }
        else if (e1->op == TOKarrayliteral && e1->type->toBasetype()->ty == Tsarray)
        {
            // Bugzilla 12212: Support direct assignment of static arrays.
            // Rewrite as: (e1[] = newval)
            SliceExp *se = new SliceExp(e1->loc, e1, NULL, NULL);
            result = interpretAssignToSlice(e->loc, se,
                newval, wantRef, isBlockAssignment, e);
            return;
        }
        else
        {
            e->error("%s cannot be evaluated at compile time", e->toChars());
        }
    }

    /*************
     *  Deal with assignments of the form
     *  aggregate[ie] = newval
     *  where aggregate and newval have already been interpreted
     *
     *  Return true if OK, false if error occured
     */
    bool interpretAssignToIndex(Loc loc,
        IndexExp *ie, Expression *newval, bool wantRef,
        BinExp *originalExp)
    {
        /* Assignment to array element of the form:
         *   aggregate[i] = newval
         *   aggregate is not AA (AAs were dealt with already).
         */
        assert(ie->e1->type->toBasetype()->ty != Taarray);
        uinteger_t destarraylen = 0;

        // Set the $ variable, and find the array literal to modify
        if (ie->e1->type->toBasetype()->ty != Tpointer)
        {
            Expression *oldval = interpret(ie->e1, istate);
            if (oldval->op == TOKnull)
            {
                originalExp->error("cannot index null array %s", ie->e1->toChars());
                return false;
            }
            if (oldval->op != TOKarrayliteral &&
                oldval->op != TOKstring &&
                oldval->op != TOKslice)
            {
                originalExp->error("cannot determine length of %s at compile time",
                    ie->e1->toChars());
                return false;
            }
            destarraylen = resolveArrayLength(oldval);
            if (ie->lengthVar)
            {
                IntegerExp *dollarExp = new IntegerExp(loc, destarraylen, Type::tsize_t);
                ctfeStack.push(ie->lengthVar);
                setValue(ie->lengthVar, dollarExp);
            }
        }
        Expression *index = interpret(ie->e2, istate);
        if (ie->lengthVar)
            ctfeStack.pop(ie->lengthVar); // $ is defined only inside []
        if (exceptionOrCantInterpret(index))
            return false;

        assert (index->op != TOKslice);  // only happens with AA assignment

        ArrayLiteralExp *existingAE = NULL;
        StringExp *existingSE = NULL;

        Expression *aggregate = resolveReferences(ie->e1);

        // Set the index to modify, and check that it is in range
        dinteger_t indexToModify = index->toInteger();
        if (ie->e1->type->toBasetype()->ty == Tpointer)
        {
            dinteger_t ofs;
            aggregate = interpret(aggregate, istate, ctfeNeedLvalue);
            if (exceptionOrCantInterpret(aggregate))
                return false;
            if (aggregate->op == TOKnull)
            {
                originalExp->error("cannot index through null pointer %s", ie->e1->toChars());
                return false;
            }
            if (aggregate->op == TOKint64)
            {
                originalExp->error("cannot index through invalid pointer %s of value %s",
                    ie->e1->toChars(), aggregate->toChars());
                return false;
            }
            aggregate = getAggregateFromPointer(aggregate, &ofs);
            indexToModify += ofs;
            if (aggregate->op != TOKslice && aggregate->op != TOKstring &&
                aggregate->op != TOKarrayliteral && aggregate->op != TOKassocarrayliteral)
            {
                if (aggregate->op == TOKsymoff)
                {
                    originalExp->error("mutable variable %s cannot be modified at compile time, even through a pointer", ((SymOffExp *)aggregate)->var->toChars());
                    return false;
                }
                if (indexToModify != 0)
                {
                    originalExp->error("pointer index [%lld] lies outside memory block [0..1]", indexToModify);
                    return false;
                }
                // It is equivalent to *aggregate = newval.
                // Aggregate could be varexp, a dotvar, ...
                // TODO: we could support this
                originalExp->error("indexed assignment of non-array pointers is not yet supported at compile time; use *%s = %s instead",
                    ie->e1->toChars(), originalExp->e2->toChars());
                return false;
            }
            destarraylen = resolveArrayLength(aggregate);
        }
        if (indexToModify >= destarraylen)
        {
            originalExp->error("array index %lld is out of bounds [0..%lld]", indexToModify,
                destarraylen);
            return false;
        }

        /* The only possible indexable LValue aggregates are array literals, and
         * slices of array literals.
         */
        if (aggregate->op == TOKindex || aggregate->op == TOKdotvar ||
            aggregate->op == TOKslice || aggregate->op == TOKcall ||
            aggregate->op == TOKstar || aggregate->op == TOKcast)
        {
            aggregate = interpret(aggregate, istate, ctfeNeedLvalue);
            if (exceptionOrCantInterpret(aggregate))
                return false;
            // The array could be an index of an AA. Resolve it if so.
            if (aggregate->op == TOKindex &&
                ((IndexExp *)aggregate)->e1->op == TOKassocarrayliteral)
            {
                IndexExp *ix = (IndexExp *)aggregate;
                aggregate = findKeyInAA(loc, (AssocArrayLiteralExp *)ix->e1, ix->e2);
                if (!aggregate)
                {
                    originalExp->error("key %s not found in associative array %s",
                        ix->e2->toChars(), ix->e1->toChars());
                    return false;
                }
                if (exceptionOrCantInterpret(aggregate))
                    return false;
            }
        }
        if (aggregate->op == TOKvar)
        {
            VarExp *ve = (VarExp *)aggregate;
            VarDeclaration *v = ve->var->isVarDeclaration();
            aggregate = getValue(v);
            if (aggregate->op == TOKnull)
            {
                // This would be a runtime segfault
                originalExp->error("cannot index null array %s", v->toChars());
                return false;
            }
        }
        if (aggregate->op == TOKslice)
        {
            SliceExp *sexp = (SliceExp *)aggregate;
            aggregate = sexp->e1;
            Expression *lwr = interpret(sexp->lwr, istate);
            indexToModify += lwr->toInteger();
        }
        if (aggregate->op == TOKarrayliteral)
            existingAE = (ArrayLiteralExp *)aggregate;
        else if (aggregate->op == TOKstring)
            existingSE = (StringExp *)aggregate;
        else
        {
            originalExp->error("CTFE internal error: %s", aggregate->toChars());
            return false;
        }
        if (!wantRef && newval->op == TOKslice)
        {
            newval = resolveSlice(newval);
            if (CTFEExp::isCantExp(newval))
            {
                originalExp->error("CTFE internal error: index assignment %s", originalExp->toChars());
                assert(0);
            }
        }
        if (wantRef && newval->op == TOKindex &&
            ((IndexExp *)newval)->e1 == aggregate)
        {
            // It's a circular reference, resolve it now
            newval = interpret(newval, istate);
        }

        if (existingAE)
        {
            if (newval->op == TOKstructliteral)
                assignInPlace((*existingAE->elements)[(size_t)indexToModify], newval);
            else
                (*existingAE->elements)[(size_t)indexToModify] = newval;
            return true;
        }
        if (existingSE)
        {
            utf8_t *s = (utf8_t *)existingSE->string;
            if (!existingSE->ownedByCtfe)
            {
                originalExp->error("cannot modify read-only string literal %s", ie->e1->toChars());
                return false;
            }
            dinteger_t value = newval->toInteger();
            switch (existingSE->sz)
            {
                case 1: s[(size_t)indexToModify] = (utf8_t)value; break;
                case 2: ((unsigned short *)s)[(size_t)indexToModify] = (unsigned short)value; break;
                case 4: ((unsigned *)s)[(size_t)indexToModify] = (unsigned)value; break;
                default:
                    assert(0);
                    break;
            }
            return true;
        }
        else
        {
            originalExp->error("index assignment %s is not yet supported in CTFE ", originalExp->toChars());
            return false;
        }
        return true;
    }

    /*************
     *  Deal with assignments of the form
     *  dest[] = newval
     *  dest[low..upp] = newval
     *  where newval has already been interpreted
     *
     * This could be a slice assignment or a block assignment, and
     * dest could be either an array literal, or a string.
     *
     * Returns TOKcantexp on failure. If there are no errors,
     * it returns aggregate[low..upp], except that as an optimisation,
     * if goal == ctfeNeedNothing, it will return NULL
     */

    Expression *interpretAssignToSlice(Loc loc,
        SliceExp *sexp, Expression *newval, bool wantRef, bool isBlockAssignment,
        BinExp *originalExp)
    {
        Expression *e2 = originalExp->e2;

        // ------------------------------
        //   aggregate[] = newval
        //   aggregate[low..upp] = newval
        // ------------------------------
        // Set the $ variable
        Expression *oldval = sexp->e1;
        bool assignmentToSlicedPointer = false;
        if (isPointer(oldval->type))
        {
            // Slicing a pointer
            oldval = interpret(oldval, istate, ctfeNeedLvalue);
            if (exceptionOrCantInterpret(oldval))
                return oldval;
            dinteger_t ofs;
            oldval = getAggregateFromPointer(oldval, &ofs);
            assignmentToSlicedPointer = true;
        }
        else
            oldval = interpret(oldval, istate);

        if (oldval->op != TOKarrayliteral &&
            oldval->op != TOKstring &&
            oldval->op != TOKslice &&
            oldval->op != TOKnull)
        {
            if (oldval->op == TOKsymoff)
            {
                originalExp->error("pointer %s cannot be sliced at compile time (it points to a static variable)", sexp->e1->toChars());
                return CTFEExp::cantexp;
            }
            if (assignmentToSlicedPointer)
            {
                originalExp->error("pointer %s cannot be sliced at compile time (it does not point to an array)",
                    sexp->e1->toChars());
            }
            else
                originalExp->error("CTFE internal error: cannot resolve array length");
            return CTFEExp::cantexp;
        }
        uinteger_t dollar = resolveArrayLength(oldval);
        if (sexp->lengthVar)
        {
            Expression *arraylen = new IntegerExp(loc, dollar, Type::tsize_t);
            ctfeStack.push(sexp->lengthVar);
            setValue(sexp->lengthVar, arraylen);
        }

        Expression *upper = NULL;
        Expression *lower = NULL;
        if (sexp->upr)
            upper = interpret(sexp->upr, istate);
        if (exceptionOrCantInterpret(upper))
        {
            if (sexp->lengthVar)
                ctfeStack.pop(sexp->lengthVar); // $ is defined only in [L..U]
            return upper;
        }
        if (sexp->lwr)
            lower = interpret(sexp->lwr, istate);
        if (sexp->lengthVar)
            ctfeStack.pop(sexp->lengthVar); // $ is defined only in [L..U]
        if (exceptionOrCantInterpret(lower))
            return lower;

        unsigned dim = (unsigned)dollar;
        size_t upperbound = (size_t)(upper ? upper->toInteger() : dim);
        int lowerbound = (int)(lower ? lower->toInteger() : 0);

        if (!assignmentToSlicedPointer && (((int)lowerbound < 0) || (upperbound > dim)))
        {
            originalExp->error("array bounds [0..%d] exceeded in slice [%d..%d]",
                dim, lowerbound, upperbound);
            return CTFEExp::cantexp;
        }
        if (upperbound == lowerbound)
            return newval;

        Expression *aggregate = resolveReferences(sexp->e1);
        sinteger_t firstIndex = lowerbound;

        ArrayLiteralExp *existingAE = NULL;
        StringExp *existingSE = NULL;

        /* The only possible slicable LValue aggregates are array literals,
         * and slices of array literals.
         */
        if (aggregate->op == TOKindex || aggregate->op == TOKdotvar ||
            aggregate->op == TOKslice || aggregate->op == TOKcast ||
            aggregate->op == TOKstar  || aggregate->op == TOKcall)
        {
            aggregate = interpret(aggregate, istate, ctfeNeedLvalue);
            if (exceptionOrCantInterpret(aggregate))
                return aggregate;
            // The array could be an index of an AA. Resolve it if so.
            if (aggregate->op == TOKindex &&
                ((IndexExp *)aggregate)->e1->op == TOKassocarrayliteral)
            {
                IndexExp *ix = (IndexExp *)aggregate;
                aggregate = findKeyInAA(loc, (AssocArrayLiteralExp *)ix->e1, ix->e2);
                if (!aggregate)
                {
                    originalExp->error("key %s not found in associative array %s",
                        ix->e2->toChars(), ix->e1->toChars());
                    return CTFEExp::cantexp;
                }
                if (exceptionOrCantInterpret(aggregate))
                    return aggregate;
            }
        }
        if (aggregate->op == TOKvar)
        {
            VarExp *ve = (VarExp *)(aggregate);
            VarDeclaration *v = ve->var->isVarDeclaration();
            aggregate = getValue(v);
        }
        if (aggregate->op == TOKslice)
        {
            // Slice of a slice --> change the bounds
            SliceExp *sexpold = (SliceExp *)aggregate;
            sinteger_t hi = upperbound + sexpold->lwr->toInteger();
            firstIndex = lowerbound + sexpold->lwr->toInteger();
            if (hi > sexpold->upr->toInteger())
            {
                originalExp->error("slice [%d..%d] exceeds array bounds [0..%lld]",
                    lowerbound, upperbound,
                    sexpold->upr->toInteger() - sexpold->lwr->toInteger());
                return CTFEExp::cantexp;
            }
            aggregate = sexpold->e1;
        }
        if (isPointer(aggregate->type))
        {
            // Slicing a pointer --> change the bounds
            aggregate = interpret(sexp->e1, istate, ctfeNeedLvalue);
            dinteger_t ofs;
            aggregate = getAggregateFromPointer(aggregate, &ofs);
            if (aggregate->op == TOKnull)
            {
                originalExp->error("cannot slice null pointer %s", sexp->e1->toChars());
                return CTFEExp::cantexp;
            }
            sinteger_t hi = upperbound + ofs;
            firstIndex = lowerbound + ofs;
            if (firstIndex < 0 || hi > dim)
            {
               originalExp->error("slice [lld..%lld] exceeds memory block bounds [0..%lld]",
                    firstIndex, hi,  dim);
                return CTFEExp::cantexp;
            }
        }
        if (aggregate->op == TOKarrayliteral)
            existingAE = (ArrayLiteralExp *)aggregate;
        else if (aggregate->op == TOKstring)
            existingSE = (StringExp *)aggregate;
        if (existingSE && !existingSE->ownedByCtfe)
        {
            originalExp->error("cannot modify read-only string literal %s", sexp->e1->toChars());
            return CTFEExp::cantexp;
        }

        if (!wantRef && newval->op == TOKslice)
        {
            Expression *orignewval = newval;
            newval = resolveSlice(newval);
            if (CTFEExp::isCantExp(newval))
            {
                originalExp->error("CTFE internal error: slice %s", orignewval->toChars());
                assert(0);
            }
        }
        if (wantRef && newval->op == TOKindex &&
            ((IndexExp *)newval)->e1 == aggregate)
        {
            // It's a circular reference, resolve it now
            newval = interpret(newval, istate);
        }

        // For slice assignment, we check that the lengths match.
        size_t srclen = 0;
        if (newval->op == TOKarrayliteral)
            srclen = ((ArrayLiteralExp *)newval)->elements->dim;
        else if (newval->op == TOKstring)
            srclen = ((StringExp *)newval)->len;
        if (!isBlockAssignment && srclen != (upperbound - lowerbound))
        {
            originalExp->error("array length mismatch assigning [0..%d] to [%d..%d]", srclen, lowerbound, upperbound);
            return CTFEExp::cantexp;
        }

        if (!isBlockAssignment && newval->op == TOKarrayliteral && existingAE)
        {
            Expressions *oldelems = existingAE->elements;
            Expressions *newelems = ((ArrayLiteralExp *)newval)->elements;
            Type *elemtype = existingAE->type->nextOf();
            for (size_t j = 0; j < newelems->dim; j++)
            {
                (*oldelems)[(size_t)(j + firstIndex)] = paintTypeOntoLiteral(elemtype, (*newelems)[j]);
            }
            if (originalExp->op != TOKblit && originalExp->e2->isLvalue())
            {
                Expression *x = evaluatePostblits(istate, existingAE, 0, oldelems->dim);
                if (exceptionOrCantInterpret(x))
                    return x;
            }
            return newval;
        }
        else if (newval->op == TOKstring && existingSE)
        {
            sliceAssignStringFromString((StringExp *)existingSE, (StringExp *)newval, (size_t)firstIndex);
            return newval;
        }
        else if (newval->op == TOKstring && existingAE &&
                 existingAE->type->nextOf()->isintegral())
        {
            /* Mixed slice: it was initialized as an array literal of chars/integers.
             * Now a slice of it is being set with a string.
             */
            sliceAssignArrayLiteralFromString(existingAE, (StringExp *)newval, (size_t)firstIndex);
            return newval;
        }
        else if (newval->op == TOKarrayliteral && existingSE)
        {
            /* Mixed slice: it was initialized as a string literal.
             * Now a slice of it is being set with an array literal.
             */
            sliceAssignStringFromArrayLiteral(existingSE, (ArrayLiteralExp *)newval, (size_t)firstIndex);
            return newval;
        }
        else if (existingSE)
        {
            // String literal block slice assign
            dinteger_t value = newval->toInteger();
            utf8_t *s = (utf8_t *)existingSE->string;
            for (size_t j = 0; j < upperbound-lowerbound; j++)
            {
                switch (existingSE->sz)
                {
                    case 1: s[(size_t)(j+firstIndex)] = (utf8_t)value; break;
                    case 2: ((unsigned short *)s)[(size_t)(j+firstIndex)] = (unsigned short)value; break;
                    case 4: ((unsigned *)s)[(size_t)(j+firstIndex)] = (unsigned)value; break;
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
            retslice->type = originalExp->type;
            return interpret(retslice, istate);
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
            Type *desttype = ((TypeArray *)existingAE->type)->next->toBasetype()->castMod(0);
            bool directblk = (e2->type->toBasetype()->castMod(0))->equals(desttype);
            bool cow = !(newval->op == TOKstructliteral ||
                         newval->op == TOKarrayliteral ||
                         newval->op == TOKstring);
            for (size_t j = 0; j < upperbound-lowerbound; j++)
            {
                if (!directblk)
                {
                    // Multidimensional array block assign
                    recursiveBlockAssign((ArrayLiteralExp *)(*w)[(size_t)(j+firstIndex)], newval, wantRef);
                }
                else
                {
                    if (wantRef || cow)
                        (*existingAE->elements)[(size_t)(j+firstIndex)] = newval;
                    else
                        assignInPlace((*existingAE->elements)[(size_t)(j+firstIndex)], newval);
                }
            }
            if (!wantRef && !cow && originalExp->op != TOKblit && originalExp->e2->isLvalue())
            {
                Expression *x = evaluatePostblits(istate, existingAE, (size_t)firstIndex, (size_t)(firstIndex+upperbound-lowerbound));
                if (exceptionOrCantInterpret(x))
                    return x;
            }
            if (goal == ctfeNeedNothing)
                return NULL; // avoid creating an unused literal
            SliceExp *retslice = new SliceExp(loc, existingAE,
                new IntegerExp(loc, firstIndex, Type::tsize_t),
                new IntegerExp(loc, firstIndex + upperbound-lowerbound, Type::tsize_t));
            retslice->type = originalExp->type;
            return interpret(retslice, istate);
        }
        else
        {
            originalExp->error("slice operation %s = %s cannot be evaluated at compile time", sexp->toChars(), newval->toChars());
            return CTFEExp::cantexp;
        }
    }

    void visit(AssignExp *e)
    {
        interpretAssignCommon(e, NULL);
    }

    void visit(BinAssignExp *e)
    {
        switch (e->op)
        {
        case TOKaddass:  interpretAssignCommon(e, &Add);        return;
        case TOKminass:  interpretAssignCommon(e, &Min);        return;
        case TOKcatass:  interpretAssignCommon(e, &ctfeCat);    return;
        case TOKmulass:  interpretAssignCommon(e, &Mul);        return;
        case TOKdivass:  interpretAssignCommon(e, &Div);        return;
        case TOKmodass:  interpretAssignCommon(e, &Mod);        return;
        case TOKshlass:  interpretAssignCommon(e, &Shl);        return;
        case TOKshrass:  interpretAssignCommon(e, &Shr);        return;
        case TOKushrass: interpretAssignCommon(e, &Ushr);       return;
        case TOKandass:  interpretAssignCommon(e, &And);        return;
        case TOKorass:   interpretAssignCommon(e, &Or);         return;
        case TOKxorass:  interpretAssignCommon(e, &Xor);        return;
        case TOKpowass:  interpretAssignCommon(e, &Pow);        return;
        default:
            assert(0);
            return;
        }
    }

    void visit(PostExp *e)
    {
    #if LOG
        printf("%s PostExp::interpret() %s\n", e->loc.toChars(), e->toChars());
    #endif
        if (e->op == TOKplusplus)
            interpretAssignCommon(e, &Add, 1);
        else
            interpretAssignCommon(e, &Min, 1);
    #if LOG
        if (CTFEExp::isCantExp(result))
            printf("PostExp::interpret() CANT\n");
    #endif
    }

    /* Return 1 if e is a p1 > p2 or p1 >= p2 pointer comparison;
     *       -1 if e is a p1 < p2 or p1 <= p2 pointer comparison;
     *        0 otherwise
     */
    static int isPointerCmpExp(Expression *e, Expression **p1, Expression **p2)
    {
        int ret = 1;
        while (e->op == TOKnot)
        {
            ret *= -1;
            e = ((NotExp *)e)->e1;
        }
        switch (e->op)
        {
        case TOKlt:
        case TOKle:
            ret *= -1;
            /* fall through */
        case TOKgt:
        case TOKge:
            *p1 = ((BinExp *)e)->e1;
            *p2 = ((BinExp *)e)->e2;
            if (!(isPointer((*p1)->type) && isPointer((*p2)->type)))
                ret = 0;
            break;
        default:
            ret = 0;
            break;
        }
        return ret;
    }

    /** Negate a relational operator, eg >= becomes <
     */
    static TOK reverseRelation(TOK op)
    {
        switch (op)
        {
            case TOKge: return TOKlt;
            case TOKgt: return TOKle;
            case TOKle: return TOKgt;
            case TOKlt: return TOKge;
            default:
                return assert(0), TOKreserved;
        }
    }

    /** If this is a four pointer relation, evaluate it, else return NULL.
     *
     *  This is an expression of the form (p1 > q1 && p2 < q2) or (p1 < q1 || p2 > q2)
     *  where p1, p2 are expressions yielding pointers to memory block p,
     *  and q1, q2 are expressions yielding pointers to memory block q.
     *  This expression is valid even if p and q are independent memory
     *  blocks and are therefore not normally comparable; the && form returns true
     *  if [p1..p2] lies inside [q1..q2], and false otherwise; the || form returns
     *  true if [p1..p2] lies outside [q1..q2], and false otherwise.
     *
     *  Within the expression, any ordering of p1, p2, q1, q2 is permissible;
     *  the comparison operators can be any of >, <, <=, >=, provided that
     *  both directions (p > q and p < q) are checked. Additionally the
     *  relational sub-expressions can be negated, eg
     *  (!(q1 < p1) && p2 <= q2) is valid.
     */
    void interpretFourPointerRelation(BinExp *e)
    {
        assert(e->op == TOKandand || e->op == TOKoror);

        /*  It can only be an isInside expression, if both e1 and e2 are
         *  directional pointer comparisons.
         *  Note that this check can be made statically; it does not depends on
         *  any runtime values. This allows a JIT implementation to compile a
         *  special AndAndPossiblyInside, keeping the normal AndAnd case efficient.
         */

        // Save the pointer expressions and the comparison directions,
        // so we can use them later.
        Expression *p1 = NULL, *p2 = NULL, *p3 = NULL, *p4 = NULL;
        int dir1 = isPointerCmpExp(e->e1, &p1, &p2);
        int dir2 = isPointerCmpExp(e->e2, &p3, &p4);
        if (dir1 == 0 || dir2 == 0)
        {
            result = NULL;
            return;
        }

        //printf("FourPointerRelation %s\n", toChars());

        // Evaluate the first two pointers
        p1 = interpret(p1, istate);
        if (exceptionOrCant(p1))
            return;
        p2 = interpret(p2, istate);
        if (exceptionOrCant(p2))
            return;
        dinteger_t ofs1, ofs2;
        Expression *agg1 = getAggregateFromPointer(p1, &ofs1);
        Expression *agg2 = getAggregateFromPointer(p2, &ofs2);

        if (!pointToSameMemoryBlock(agg1, agg2) &&
             agg1->op != TOKnull &&
             agg2->op != TOKnull)
        {
            // Here it is either CANT_INTERPRET,
            // or an IsInside comparison returning false.
            p3 = interpret(p3, istate);
            if (CTFEExp::isCantExp(p3))
                return;
            // Note that it is NOT legal for it to throw an exception!
            Expression *except = NULL;
            if (exceptionOrCantInterpret(p3))
                except = p3;
            else
            {
                p4 = interpret(p4, istate);
                if (CTFEExp::isCantExp(p4))
                {
                    result = p4;
                    return;
                }
                if (exceptionOrCantInterpret(p4))
                    except = p4;
            }
            if (except)
            {
                e->error("comparison %s of pointers to unrelated memory blocks remains "
                     "indeterminate at compile time "
                     "because exception %s was thrown while evaluating %s",
                     e->e1->toChars(), except->toChars(), e->e2->toChars());
                result = CTFEExp::cantexp;
                return;
            }
            dinteger_t ofs3,ofs4;
            Expression *agg3 = getAggregateFromPointer(p3, &ofs3);
            Expression *agg4 = getAggregateFromPointer(p4, &ofs4);
            // The valid cases are:
            // p1 > p2 && p3 > p4  (same direction, also for < && <)
            // p1 > p2 && p3 < p4  (different direction, also < && >)
            // Changing any > into >= doesnt affect the result
            if ((dir1 == dir2 && pointToSameMemoryBlock(agg1, agg4) && pointToSameMemoryBlock(agg2, agg3)) ||
                (dir1 != dir2 && pointToSameMemoryBlock(agg1, agg3) && pointToSameMemoryBlock(agg2, agg4)))
            {
                // it's a legal two-sided comparison
                result = new IntegerExp(e->loc, (e->op == TOKandand) ?  0 : 1, e->type);
                return;
            }
            // It's an invalid four-pointer comparison. Either the second
            // comparison is in the same direction as the first, or else
            // more than two memory blocks are involved (either two independent
            // invalid comparisons are present, or else agg3 == agg4).
            e->error("comparison %s of pointers to unrelated memory blocks is "
                "indeterminate at compile time, even when combined with %s.",
                e->e1->toChars(), e->e2->toChars());
            result = CTFEExp::cantexp;
            return;
        }
        // The first pointer expression didn't need special treatment, so we
        // we need to interpret the entire expression exactly as a normal && or ||.
        // This is easy because we haven't evaluated e2 at all yet, and we already
        // know it will return a bool.
        // But we mustn't evaluate the pointer expressions in e1 again, in case
        // they have side-effects.
        bool nott = false;
        Expression *ex = e->e1;
        while (ex->op == TOKnot)
        {
            nott = !nott;
            ex = ((NotExp *)ex)->e1;
        }
        TOK cmpop = ex->op;
        if (nott)
            cmpop = reverseRelation(cmpop);
        int cmp = comparePointers(e->loc, cmpop, e->e1->type, agg1, ofs1, agg2, ofs2);
        // We already know this is a valid comparison.
        assert(cmp >= 0);
        if ((e->op == TOKandand && cmp == 1) || (e->op == TOKoror && cmp == 0))
        {
            result = interpret(e->e2, istate);
            return;
        }
        result = new IntegerExp(e->loc, (e->op == TOKandand) ? 0 : 1, e->type);
    }

    void visit(AndAndExp *e)
    {
    #if LOG
        printf("%s AndAndExp::interpret() %s\n", e->loc.toChars(), e->toChars());
    #endif

        // Check for an insidePointer expression, evaluate it if so
        interpretFourPointerRelation(e);
        if (result)
            return;

        result = interpret(e->e1, istate);
        if (exceptionOrCant(result))
            return;

        int res;
        if (result->isBool(false))
            res = 0;
        else if (isTrueBool(result))
        {
            result = interpret(e->e2, istate);
            if (exceptionOrCant(result))
                return;
            if (result->op == TOKvoidexp)
            {
                assert(e->type->ty == Tvoid);
                result = NULL;
                return;
            }
            if (result->isBool(false))
                res = 0;
            else if (isTrueBool(result))
                res = 1;
            else
            {
                result->error("%s does not evaluate to a boolean", result->toChars());
                result = CTFEExp::cantexp;
            }
        }
        else
        {
            result->error("%s cannot be interpreted as a boolean", result->toChars());
            result = CTFEExp::cantexp;
        }
        if (!CTFEExp::isCantExp(result) && goal != ctfeNeedNothing)
            result = new IntegerExp(e->loc, res, e->type);
    }

    void visit(OrOrExp *e)
    {
    #if LOG
        printf("%s OrOrExp::interpret() %s\n", e->loc.toChars(), e->toChars());
    #endif

        // Check for an insidePointer expression, evaluate it if so
        interpretFourPointerRelation(e);
        if (result)
            return;

        result = interpret(e->e1, istate);
        if (exceptionOrCant(result))
            return;

        int res;
        if (isTrueBool(result))
            res = 1;
        else if (result->isBool(false))
        {
            result = interpret(e->e2, istate);
            if (exceptionOrCant(result))
                return;

            if (result->op == TOKvoidexp)
            {
                assert(e->type->ty == Tvoid);
                result = NULL;
                return;
            }
            if (!CTFEExp::isCantExp(result))
            {
                if (result->isBool(false))
                    res = 0;
                else if (isTrueBool(result))
                    res = 1;
                else
                {
                    result->error("%s cannot be interpreted as a boolean", result->toChars());
                    result = CTFEExp::cantexp;
                }
            }
        }
        else
        {
            result->error("%s cannot be interpreted as a boolean", result->toChars());
            result = CTFEExp::cantexp;
        }
        if (!CTFEExp::isCantExp(result) && goal != ctfeNeedNothing)
            result = new IntegerExp(e->loc, res, e->type);
    }

    // Print a stack trace, starting from callingExp which called fd.
    // To shorten the stack trace, try to detect recursion.
    void showCtfeBackTrace(CallExp * callingExp, FuncDeclaration *fd)
    {
        if (CtfeStatus::stackTraceCallsToSuppress > 0)
        {
            --CtfeStatus::stackTraceCallsToSuppress;
            return;
        }
        errorSupplemental(callingExp->loc, "called from here: %s", callingExp->toChars());
        // Quit if it's not worth trying to compress the stack trace
        if (CtfeStatus::callDepth < 6 || global.params.verbose)
            return;
        // Recursion happens if the current function already exists in the call stack.
        int numToSuppress = 0;
        int recurseCount = 0;
        int depthSoFar = 0;
        InterState *lastRecurse = istate;
        for (InterState * cur = istate; cur; cur = cur->caller)
        {
            if (cur->fd == fd)
            {
                ++recurseCount;
                numToSuppress = depthSoFar;
                lastRecurse = cur;
            }
            ++depthSoFar;
        }
        // We need at least three calls to the same function, to make compression worthwhile
        if (recurseCount < 2)
            return;
        // We found a useful recursion.  Print all the calls involved in the recursion
        errorSupplemental(fd->loc, "%d recursive calls to function %s", recurseCount, fd->toChars());
        for (InterState *cur = istate; cur->fd != fd; cur = cur->caller)
        {
            errorSupplemental(cur->fd->loc, "recursively called from function %s", cur->fd->toChars());
        }
        // We probably didn't enter the recursion in this function.
        // Go deeper to find the real beginning.
        InterState * cur = istate;
        while (lastRecurse->caller && cur->fd ==  lastRecurse->caller->fd)
        {
            cur = cur->caller;
            lastRecurse = lastRecurse->caller;
            ++numToSuppress;
        }
        CtfeStatus::stackTraceCallsToSuppress = numToSuppress;
    }

    void visit(CallExp *e)
    {
    #if LOG
        printf("%s CallExp::interpret() %s\n", e->loc.toChars(), e->toChars());
    #endif

        Expression * pthis = NULL;
        FuncDeclaration *fd = NULL;
        Expression *ecall = e->e1;
        if (ecall->op == TOKcall)
        {
            ecall = interpret(e->e1, istate);
            if (exceptionOrCant(ecall))
                return;
        }
        if (ecall->op == TOKstar)
        {
            // Calling a function pointer
            Expression * pe = ((PtrExp *)ecall)->e1;
            if (pe->op == TOKvar)
            {
                VarDeclaration *vd = ((VarExp *)((PtrExp *)ecall)->e1)->var->isVarDeclaration();
                if (vd && hasValue(vd) && getValue(vd)->op == TOKsymoff)
                    fd = ((SymOffExp *)getValue(vd))->var->isFuncDeclaration();
                else
                {
                    ecall = getVarExp(e->loc, istate, vd, goal);
                    if (exceptionOrCant(ecall))
                        return;

                    if (ecall->op == TOKsymoff)
                        fd = ((SymOffExp *)ecall)->var->isFuncDeclaration();
                }
            }
            else if (pe->op == TOKsymoff)
                fd = ((SymOffExp *)pe)->var->isFuncDeclaration();
            else
                ecall = interpret(((PtrExp *)ecall)->e1, istate);

        }
        if (exceptionOrCant(ecall))
            return;

        if (ecall->op == TOKindex)
        {
            ecall = interpret(e->e1, istate);
            if (exceptionOrCant(ecall))
                return;
        }

        if (ecall->op == TOKdotvar && !((DotVarExp *)ecall)->var->isFuncDeclaration())
        {
            ecall = interpret(e->e1, istate);
            if (exceptionOrCant(ecall))
                return;
        }

        if (ecall->op == TOKdotvar)
        {
            DotVarExp *dve = (DotVarExp *)e->e1;

            // Calling a member function
            pthis = dve->e1;
            fd = dve->var->isFuncDeclaration();

            // Special handling for: typeid(T[n]).destroy(cast(void*)&v)
            TypeInfoDeclaration *tid;
            if (pthis->op == TOKsymoff &&
                (tid = ((SymOffExp *)pthis)->var->isTypeInfoDeclaration()) != NULL &&
                tid->tinfo->toBasetype()->ty == Tsarray &&
                fd->ident == Id::destroy &&
                e->arguments->dim == 1 &&
                (*e->arguments)[0]->op == TOKsymoff)
            {
                Type *tb = tid->tinfo->baseElemOf();
                if (tb->ty == Tstruct && ((TypeStruct *)tb)->sym->dtor)
                {
                    Declaration *v = ((SymOffExp *)(*e->arguments)[0])->var;
                    Expression *arg = getVarExp(e->loc, istate, v, ctfeNeedRvalue);

                    result = evaluateDtor(istate, arg);
                    if (result)
                        return;
                    result = CTFEExp::voidexp;
                    return;

                }
            }
        }
        else if (ecall->op == TOKvar)
        {
            VarDeclaration *vd = ((VarExp *)ecall)->var->isVarDeclaration();
            if (vd && hasValue(vd))
                ecall = getValue(vd);
            else // Calling a function
                fd = ((VarExp *)e->e1)->var->isFuncDeclaration();
        }
        if (ecall->op == TOKdelegate)
        {
            // Calling a delegate
            fd = ((DelegateExp *)ecall)->func;
            pthis = ((DelegateExp *)ecall)->e1;
        }
        else if (ecall->op == TOKfunction)
        {
            // Calling a delegate literal
            fd = ((FuncExp *)ecall)->fd;
        }
        else if (ecall->op == TOKstar && ((PtrExp *)ecall)->e1->op == TOKfunction)
        {
            // Calling a function literal
            fd = ((FuncExp *)((PtrExp*)ecall)->e1)->fd;
        }
        else if (ecall->op == TOKdelegatefuncptr)
        {
            // delegate.funcptr()
            e->error("cannot evaulate %s at compile time", e->toChars());
            result = CTFEExp::cantexp;
            return;
        }

        TypeFunction *tf = fd ? (TypeFunction *)(fd->type) : NULL;
        if (!tf)
        {
            // This should never happen, it's an internal compiler error.
            //printf("ecall=%s %d %d\n", ecall->toChars(), ecall->op, TOKcall);
            if (ecall->op == TOKidentifier)
                e->error("cannot evaluate %s at compile time. Circular reference?", e->toChars());
            else
                e->error("CTFE internal error: cannot evaluate %s at compile time", e->toChars());
            result = CTFEExp::cantexp;
            return;
        }
        if (!fd)
        {
            e->error("cannot evaluate %s at compile time", e->toChars());
            result = CTFEExp::cantexp;
            return;
        }
        if (pthis)
        {
            // Member function call
            if (pthis->op == TOKcomma)
                pthis = interpret(pthis, istate);
            if (exceptionOrCant(pthis))
                return;
            // Evaluate 'this'
            Expression *oldpthis = pthis;
            if (pthis->op != TOKvar)
                pthis = interpret(pthis, istate, ctfeNeedLvalue);
            if (exceptionOrCant(pthis))
                return;
            if (fd->isVirtual())
            {
                // Make a virtual function call.
                Expression *thisval = pthis;
                if (pthis->op == TOKvar)
                {
                    VarDeclaration *vthis = ((VarExp*)thisval)->var->isVarDeclaration();
                    assert(vthis);
                    thisval = getVarExp(e->loc, istate, vthis, ctfeNeedLvalue);
                    if (exceptionOrCant(thisval))
                        return;
                    // If it is a reference, resolve it
                    if (thisval->op != TOKnull && thisval->op != TOKclassreference)
                        thisval = interpret(pthis, istate);
                }
                else if (pthis->op == TOKsymoff)
                {
                    VarDeclaration *vthis = ((SymOffExp*)thisval)->var->isVarDeclaration();
                    assert(vthis);
                    thisval = getVarExp(e->loc, istate, vthis, ctfeNeedLvalue);
                    if (exceptionOrCant(thisval))
                        return;
                }

                // Get the function from the vtable of the original class
                if (thisval && thisval->op == TOKnull)
                {
                    e->error("function call through null class reference %s", pthis->toChars());
                    result = CTFEExp::cantexp;
                    return;
                }
                ClassDeclaration *cd;
                if (oldpthis->op == TOKsuper)
                {
                    assert(oldpthis->type->ty == Tclass);
                    cd = ((TypeClass *)oldpthis->type)->sym;
                }
                else
                {
                    assert(thisval && thisval->op == TOKclassreference);
                    cd = ((ClassReferenceExp *)thisval)->originalClass();
                }
                // We can't just use the vtable index to look it up, because
                // vtables for interfaces don't get populated until the glue layer.
                fd = cd->findFunc(fd->ident, (TypeFunction *)fd->type);

                assert(fd);
            }
        }
        if (fd && fd->semanticRun >= PASSsemantic3done && fd->semantic3Errors)
        {
            e->error("CTFE failed because of previous errors in %s", fd->toChars());
            result = CTFEExp::cantexp;
            return;
        }
        // Check for built-in functions
        result = evaluateIfBuiltin(istate, e->loc, fd, e->arguments, pthis);
        if (result)
            return;

        if (!fd->fbody)
        {
            e->error("%s cannot be interpreted at compile time,"
                " because it has no available source code", fd->toChars());
            result = CTFEExp::cantexp;
            return;
        }
        result = interpret(fd, istate, e->arguments, pthis);
        if (CTFEExp::isCantExp(result))
        {
            // Print a stack trace.
            if (!global.gag)
                showCtfeBackTrace(e, fd);
        }
        else if (result->op == TOKvoidexp)
            ;
        else if (result->op != TOKthrownexception)
        {
            result = paintTypeOntoLiteral(e->type, result);
            result->loc = e->loc;
        }
    }

    void visit(CommaExp *e)
    {
    #if LOG
        printf("%s CommaExp::interpret() %s\n", e->loc.toChars(), e->toChars());
    #endif

        CommaExp * firstComma = e;
        while (firstComma->e1->op == TOKcomma)
            firstComma = (CommaExp *)firstComma->e1;

        // If it creates a variable, and there's no context for
        // the variable to be created in, we need to create one now.
        InterState istateComma;
        if (!istate &&  firstComma->e1->op == TOKdeclaration)
        {
            ctfeStack.startFrame(NULL);
            istate = &istateComma;
        }

        result = CTFEExp::cantexp;

        // If the comma returns a temporary variable, it needs to be an lvalue
        // (this is particularly important for struct constructors)
        if (e->e1->op == TOKdeclaration && e->e2->op == TOKvar &&
            ((DeclarationExp *)e->e1)->declaration == ((VarExp*)e->e2)->var &&
            ((VarExp*)e->e2)->var->storage_class & STCctfe)  // same as Expression::isTemp
        {
            VarExp *ve = (VarExp *)e->e2;
            VarDeclaration *v = ve->var->isVarDeclaration();
            ctfeStack.push(v);
            if (!v->init && !getValue(v))
            {
                setValue(v, copyLiteral(v->type->defaultInitLiteral(e->loc)).copy());
            }
            if (!getValue(v))
            {
                Expression *newval = v->init->toExpression();
                // Bug 4027. Copy constructors are a weird case where the
                // initializer is a void function (the variable is modified
                // through a reference parameter instead).
                newval = interpret(newval, istate);
                if (exceptionOrCant(newval))
                {
                    if (istate == &istateComma)
                        ctfeStack.endFrame();
                    return;
                }
                if (newval->op != TOKvoidexp)
                {
                    // v isn't necessarily null.
                    setValueWithoutChecking(v, copyLiteral(newval).copy());
                }
            }
            if (goal == ctfeNeedLvalue || goal == ctfeNeedLvalueRef)
                result = e->e2;
            else
                result = interpret(e->e2, istate, goal);
        }
        else
        {
            result = interpret(e->e1, istate, ctfeNeedNothing);
            if (!exceptionOrCantInterpret(result))
                result = interpret(e->e2, istate, goal);
        }
        // If we created a temporary stack frame, end it now.
        if (istate == &istateComma)
            ctfeStack.endFrame();
    }

    void visit(CondExp *e)
    {
    #if LOG
        printf("%s CondExp::interpret() %s\n", e->loc.toChars(), e->toChars());
    #endif
        if (isPointer(e->econd->type))
        {
            result = interpret(e->econd, istate);
            if (exceptionOrCant(result))
                return;
            if (result->op != TOKnull)
                result = new IntegerExp(e->loc, 1, Type::tbool);
        }
        else
            result = interpret(e->econd, istate);
        if (exceptionOrCant(result))
            return;
        if (isTrueBool(result))
            result = interpret(e->e1, istate, goal);
        else if (result->isBool(false))
            result = interpret(e->e2, istate, goal);
        else
        {
            e->error("%s does not evaluate to boolean result at compile time",
                e->econd->toChars());
            result = CTFEExp::cantexp;
        }
    }

    void visit(ArrayLengthExp *e)
    {
    #if LOG
        printf("%s ArrayLengthExp::interpret() %s\n", e->loc.toChars(), e->toChars());
    #endif
        Expression *e1 = interpret(e->e1, istate);
        assert(e1);
        if (exceptionOrCant(e1))
            return;
        if (e1->op == TOKstring || e1->op == TOKarrayliteral || e1->op == TOKslice ||
            e1->op == TOKassocarrayliteral || e1->op == TOKnull)
        {
            result = new IntegerExp(e->loc, resolveArrayLength(e1), e->type);
        }
        else
        {
            e->error("%s cannot be evaluated at compile time", e->toChars());
            result = CTFEExp::cantexp;
        }
    }

    void visit(DelegatePtrExp *e)
    {
    #if LOG
        printf("%s DelegatePtrExp::interpret() %s\n", e->loc.toChars(), e->toChars());
    #endif
        Expression *e1 = interpret(e->e1, istate);
        assert(e1);
        if (exceptionOrCant(e1))
            return;
        e->error("%s cannot be evaluated at compile time", e->toChars());
        result = CTFEExp::cantexp;
    }

    void visit(DelegateFuncptrExp *e)
    {
    #if LOG
        printf("%s DelegateFuncptrExp::interpret() %s\n", e->loc.toChars(), e->toChars());
    #endif
        Expression *e1 = interpret(e->e1, istate);
        assert(e1);
        if (exceptionOrCant(e1))
            return;
        e->error("%s cannot be evaluated at compile time", e->toChars());
        result = CTFEExp::cantexp;
    }

    void visit(IndexExp *e)
    {
    #if LOG
        printf("%s IndexExp::interpret() %s\n", e->loc.toChars(), e->toChars());
    #endif
        if (e->e1->type->toBasetype()->ty == Tpointer)
        {
            // Indexing a pointer. Note that there is no $ in this case.
            Expression *e1 = interpret(e->e1, istate);
            if (exceptionOrCant(e1))
                return;
            Expression *e2 = interpret(e->e2, istate);
            if (exceptionOrCant(e2))
                return;
            sinteger_t indx = e2->toInteger();

            dinteger_t ofs;
            Expression *agg = getAggregateFromPointer(e1, &ofs);

            if (agg->op == TOKnull)
            {
                e->error("cannot index null pointer %s", e->e1->toChars());
                result = CTFEExp::cantexp;
                return;
            }
            if (agg->op == TOKarrayliteral || agg->op == TOKstring)
            {
                dinteger_t len = ArrayLength(Type::tsize_t, agg).exp()->toInteger();
                //Type *pointee = ((TypePointer *)agg->type)->next;
                if ((sinteger_t)(indx + ofs) < 0 || (indx+ofs) > len)
                {
                    e->error("pointer index [%lld] exceeds allocated memory block [0..%lld]",
                        indx+ofs, len);
                    result = CTFEExp::cantexp;
                    return;
                }
                if (goal == ctfeNeedLvalueRef)
                {
                    // if we need a reference, IndexExp shouldn't be interpreting
                    // the expression to a value, it should stay as a reference
                    result = new IndexExp(e->loc, agg,
                        ofs ? new IntegerExp(e->loc, indx + ofs, e2->type) : e2);
                    result->type = e->type;
                    return;
                }
                result = ctfeIndex(e->loc, e->type, agg, indx+ofs);
                return;
            }
            else
            {
                // Pointer to a non-array variable
                if (agg->op == TOKsymoff)
                {
                    e->error("mutable variable %s cannot be read at compile time, even through a pointer", ((SymOffExp *)agg)->var->toChars());
                    result = CTFEExp::cantexp;
                    return;
                }
                if ((indx + ofs) != 0)
                {
                    e->error("pointer index [%lld] lies outside memory block [0..1]",
                        indx+ofs);
                    result = CTFEExp::cantexp;
                    return;
                }
                if (goal == ctfeNeedLvalueRef)
                {
                    result = paintTypeOntoLiteral(e->type, agg);
                    return;
                }
                result = interpret(agg, istate);
                return;
            }
        }
        Expression *e1 = e->e1;
        if (!(e1->op == TOKarrayliteral && ((ArrayLiteralExp *)e1)->ownedByCtfe) &&
            !(e1->op == TOKassocarrayliteral && ((AssocArrayLiteralExp *)e1)->ownedByCtfe))
            e1 = interpret(e1, istate);
        if (exceptionOrCant(e1))
            return;

        if (e1->op == TOKnull)
        {
            if (goal == ctfeNeedLvalue && e1->type->ty == Taarray && e->modifiable)
            {
                result = paintTypeOntoLiteral(e->type, e1);
                return;
            }
            e->error("cannot index null array %s", e->e1->toChars());
            result = CTFEExp::cantexp;
            return;
        }
        /* Set the $ variable.
         *  Note that foreach uses indexing but doesn't need $
         */
        if (e->lengthVar &&
            (e1->op == TOKstring || e1->op == TOKarrayliteral || e1->op == TOKslice))
        {
            uinteger_t dollar = resolveArrayLength(e1);
            Expression *dollarExp = new IntegerExp(e->loc, dollar, Type::tsize_t);
            ctfeStack.push(e->lengthVar);
            setValue(e->lengthVar, dollarExp);
        }

        Expression *e2 = interpret(e->e2, istate);
        if (e->lengthVar)
            ctfeStack.pop(e->lengthVar); // $ is defined only inside []
        if (exceptionOrCant(e2))
            return;
        if (e1->op == TOKslice && e2->op == TOKint64)
        {
            // Simplify index of slice:  agg[lwr..upr][indx] --> agg[indx']
            uinteger_t indx = e2->toInteger();
            uinteger_t ilo = ((SliceExp *)e1)->lwr->toInteger();
            uinteger_t iup = ((SliceExp *)e1)->upr->toInteger();

            if (indx > iup - ilo)
            {
                e->error("index %llu exceeds array length %llu", indx, iup - ilo);
                result = CTFEExp::cantexp;
                return;
            }
            indx += ilo;
            e1 = ((SliceExp *)e1)->e1;
            e2 = new IntegerExp(e2->loc, indx, e2->type);
        }
        if ((goal == ctfeNeedLvalue && e->type->ty != Taarray &&
             e->type->ty != Tarray  && e->type->ty != Tsarray &&
             e->type->ty != Tstruct && e->type->ty != Tclass) ||
            (goal == ctfeNeedLvalueRef &&
             e->type->ty != Tsarray && e->type->ty != Tstruct))
        {
            // Pointer or reference of a scalar type
            result = new IndexExp(e->loc, e1, e2);
            result->type = e->type;
            return;
        }
        if (e1->op == TOKassocarrayliteral)
        {
            if (e2->op == TOKslice)
                e2 = resolveSlice(e2);
            result = findKeyInAA(e->loc, (AssocArrayLiteralExp *)e1, e2);
            if (!result)
            {
                e->error("key %s not found in associative array %s",
                    e2->toChars(), e->e1->toChars());
                result = CTFEExp::cantexp;
                return;
            }
        }
        else
        {
            if (e2->op != TOKint64)
            {
                e1->error("CTFE internal error: non-integral index [%s]", e->e2->toChars());
                result = CTFEExp::cantexp;
                return;
            }
            result = ctfeIndex(e->loc, e->type, e1, e2->toInteger());
        }
        if (exceptionOrCant(result))
            return;
        if (goal == ctfeNeedRvalue && (result->op == TOKslice || e->op == TOKdotvar))
            result = interpret(result, istate);
        if (goal == ctfeNeedRvalue && result->op == TOKvoid)
        {
            e->error("%s is used before initialized", e->toChars());
            errorSupplemental(result->loc, "originally uninitialized here");
            result = CTFEExp::cantexp;
            return;
        }
        result = paintTypeOntoLiteral(e->type, result);
    }

    void visit(SliceExp *e)
    {
    #if LOG
        printf("%s SliceExp::interpret() %s\n", e->loc.toChars(), e->toChars());
    #endif

        if (e->e1->type->toBasetype()->ty == Tpointer)
        {
            // Slicing a pointer. Note that there is no $ in this case.
            Expression *e1 = interpret(e->e1, istate);
            if (exceptionOrCant(e1))
                return;
            if (e1->op == TOKint64)
            {
                e->error("cannot slice invalid pointer %s of value %s",
                    e->e1->toChars(), e1->toChars());
                result = CTFEExp::cantexp;
                return;
            }

            /* Evaluate lower and upper bounds of slice
             */
            Expression *lwr = interpret(e->lwr, istate);
            if (exceptionOrCant(lwr))
                return;
            Expression *upr = interpret(e->upr, istate);
            if (exceptionOrCant(upr))
                return;
            uinteger_t ilwr = lwr->toInteger();
            uinteger_t iupr = upr->toInteger();
            dinteger_t ofs;
            Expression *agg = getAggregateFromPointer(e1, &ofs);
            ilwr += ofs;
            iupr += ofs;
            if (agg->op == TOKnull)
            {
                if (iupr == ilwr)
                {
                    result = new NullExp(e->loc);
                    result->type = e->type;
                    return;
                }
                e->error("cannot slice null pointer %s", e->e1->toChars());
                result = CTFEExp::cantexp;
                return;
            }
            if (agg->op == TOKsymoff)
            {
                e->error("slicing pointers to static variables is not supported in CTFE");
                result = CTFEExp::cantexp;
                return;
            }
            if (agg->op != TOKarrayliteral && agg->op != TOKstring)
            {
                e->error("pointer %s cannot be sliced at compile time (it does not point to an array)",
                    e->e1->toChars());
                result = CTFEExp::cantexp;
                return;
            }
            assert(agg->op == TOKarrayliteral || agg->op == TOKstring);
            dinteger_t len = ArrayLength(Type::tsize_t, agg).exp()->toInteger();
            //Type *pointee = ((TypePointer *)agg->type)->next;
            if (iupr > (len + 1) || iupr < ilwr)
            {
                e->error("pointer slice [%lld..%lld] exceeds allocated memory block [0..%lld]",
                    ilwr, iupr, len);
                result = CTFEExp::cantexp;
                return;
            }
            if (ofs != 0)
            {
                lwr = new IntegerExp(e->loc, ilwr, lwr->type);
                upr = new IntegerExp(e->loc, iupr, upr->type);
            }
            result = new SliceExp(e->loc, agg, lwr, upr);
            result->type = e->type;
            return;
        }
        Expression *e1;
        if (goal == ctfeNeedRvalue && e->e1->op == TOKstring)
            e1 = e->e1; // Will get duplicated anyway
        else
            e1 = interpret(e->e1, istate);
        if (exceptionOrCant(e1))
            return;
        if (e1->op == TOKvar)
            e1 = interpret(e1, istate);

        if (!e->lwr)
        {
            if (goal == ctfeNeedLvalue || goal == ctfeNeedLvalueRef)
            {
                result = e1;
                return;
            }
            result = paintTypeOntoLiteral(e->type, e1);
            return;
        }

        /* Set the $ variable
         */
        if (e1->op != TOKarrayliteral && e1->op != TOKstring &&
            e1->op != TOKnull && e1->op != TOKslice)
        {
            e->error("cannot determine length of %s at compile time", e1->toChars());
            result = CTFEExp::cantexp;
            return;
        }
        uinteger_t dollar = resolveArrayLength(e1);
        if (e->lengthVar)
        {
            IntegerExp *dollarExp = new IntegerExp(e->loc, dollar, Type::tsize_t);
            ctfeStack.push(e->lengthVar);
            setValue(e->lengthVar, dollarExp);
        }

        /* Evaluate lower and upper bounds of slice
         */
        Expression *lwr = interpret(e->lwr, istate);
        if (exceptionOrCant(lwr))
        {
            if (e->lengthVar)
                ctfeStack.pop(e->lengthVar);; // $ is defined only inside [L..U]
            return;
        }
        Expression *upr = interpret(e->upr, istate);
        if (e->lengthVar)
            ctfeStack.pop(e->lengthVar); // $ is defined only inside [L..U]
        if (exceptionOrCant(upr))
            return;

        uinteger_t ilwr = lwr->toInteger();
        uinteger_t iupr = upr->toInteger();
        if (e1->op == TOKnull)
        {
            if (ilwr== 0 && iupr == 0)
            {
                result = e1;
                return;
            }
            e1->error("slice [%llu..%llu] is out of bounds", ilwr, iupr);
            result = CTFEExp::cantexp;
            return;
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
                e->error("slice[%llu..%llu] exceeds array bounds[%llu..%llu]",
                    ilwr, iupr, lo1, up1);
                result = CTFEExp::cantexp;
                return;
            }
            ilwr += lo1;
            iupr += lo1;
            result = new SliceExp(e->loc, se->e1,
                    new IntegerExp(e->loc, ilwr, lwr->type),
                    new IntegerExp(e->loc, iupr, upr->type));
            result->type = e->type;
            return;
        }
        if (e1->op == TOKarrayliteral || e1->op == TOKstring)
        {
            if (iupr < ilwr || dollar < iupr)
            {
                e->error("slice [%lld..%lld] exceeds array bounds [0..%lld]", ilwr, iupr, dollar);
                result = CTFEExp::cantexp;
                return;
            }
        }
        result = new SliceExp(e->loc, e1, lwr, upr);
        result->type = e->type;
    }

    void visit(InExp *e)
    {
    #if LOG
        printf("%s InExp::interpret() %s\n", e->loc.toChars(), e->toChars());
    #endif
        Expression *e1 = interpret(e->e1, istate);
        if (exceptionOrCant(e1))
            return;
        Expression *e2 = interpret(e->e2, istate);
        if (exceptionOrCant(e2))
            return;
        if (e2->op == TOKnull)
        {
            result = new NullExp(e->loc, e->type);
            return;
        }
        if (e2->op != TOKassocarrayliteral)
        {
            e->error("%s cannot be interpreted at compile time", e->toChars());
            result = CTFEExp::cantexp;
            return;
        }
        if (e1->op == TOKslice)
            e1 = resolveSlice(e1);
        result = findKeyInAA(e->loc, (AssocArrayLiteralExp *)e2, e1);
        if (exceptionOrCant(result))
            return;
        if (!result)
        {
            result = new NullExp(e->loc, e->type);
            return;
        }
        result = new IndexExp(e->loc, e2, e1);
        result->type = e->type;
    }

    void visit(CatExp *e)
    {
    #if LOG
        printf("%s CatExp::interpret() %s\n", e->loc.toChars(), e->toChars());
    #endif
        Expression *e1 = interpret(e->e1, istate);
        if (exceptionOrCant(e1))
            return;
        if (e1->op == TOKslice)
        {
            e1 = resolveSlice(e1);
        }
        Expression *e2 = interpret(e->e2, istate);
        if (exceptionOrCant(e2))
            return;
        if (e2->op == TOKslice)
            e2 = resolveSlice(e2);
        result = ctfeCat(e->type, e1, e2).copy();
        if (CTFEExp::isCantExp(result))
        {
            e->error("%s cannot be interpreted at compile time", e->toChars());
            return;
        }
        // We know we still own it, because we interpreted both e1 and e2
        if (result->op == TOKarrayliteral)
            ((ArrayLiteralExp *)result)->ownedByCtfe = true;
        if (result->op == TOKstring)
            ((StringExp *)result)->ownedByCtfe = true;
    }


    void visit(CastExp *e)
    {
    #if LOG
        printf("%s CastExp::interpret() %s\n", e->loc.toChars(), e->toChars());
    #endif
        Expression *e1 = interpret(e->e1, istate, goal);
        if (exceptionOrCant(e1))
            return;
        // If the expression has been cast to void, do nothing.
        if (e->to->ty == Tvoid && goal == ctfeNeedNothing)
        {
            result = e1;
            return;
        }
        if (e->to->ty == Tpointer && e1->op != TOKnull)
        {
            Type *pointee = ((TypePointer *)e->type)->next;
            // Implement special cases of normally-unsafe casts
            if (e1->op == TOKint64)
            {
                // Happens with Windows HANDLEs, for example.
                result = paintTypeOntoLiteral(e->to, e1);
                return;
            }
            bool castBackFromVoid = false;
            if (e1->type->ty == Tarray || e1->type->ty == Tsarray || e1->type->ty == Tpointer)
            {
                // Check for unsupported type painting operations
                // For slices, we need the type being sliced,
                // since it may have already been type painted
                Type *elemtype = e1->type->nextOf();
                if (e1->op == TOKslice)
                    elemtype = ((SliceExp *)e1)->e1->type->nextOf();
                // Allow casts from X* to void *, and X** to void** for any X.
                // But don't allow cast from X* to void**.
                // So, we strip all matching * from source and target to find X.
                // Allow casts to X* from void* only if the 'void' was originally an X;
                // we check this later on.
                Type *ultimatePointee = pointee;
                Type *ultimateSrc = elemtype;
                while (ultimatePointee->ty == Tpointer && ultimateSrc->ty == Tpointer)
                {
                    ultimatePointee = ultimatePointee->nextOf();
                    ultimateSrc = ultimateSrc->nextOf();
                }
                if (ultimatePointee->ty != Tvoid && ultimateSrc->ty != Tvoid &&
                    !isSafePointerCast(elemtype, pointee))
                {
                    e->error("reinterpreting cast from %s* to %s* is not supported in CTFE",
                        elemtype->toChars(), pointee->toChars());
                    result = CTFEExp::cantexp;
                    return;
                }
                if (ultimateSrc->ty == Tvoid)
                    castBackFromVoid = true;
            }

            if (e1->op == TOKslice)
            {
                if (((SliceExp *)e1)->e1->op == TOKnull)
                {
                    result = paintTypeOntoLiteral(e->type, ((SliceExp *)e1)->e1);
                    return;
                }
                result = new IndexExp(e->loc, ((SliceExp *)e1)->e1, ((SliceExp *)e1)->lwr);
                result->type = e->type;
                return;
            }
            if (e1->op == TOKarrayliteral || e1->op == TOKstring)
            {
                result = new IndexExp(e->loc, e1, new IntegerExp(e->loc, 0, Type::tsize_t));
                result->type = e->type;
                return;
            }
            if (e1->op == TOKindex && !((IndexExp *)e1)->e1->type->equals(e1->type))
            {
                // type painting operation
                IndexExp *ie = (IndexExp *)e1;
                result = new IndexExp(e1->loc, ie->e1, ie->e2);
                if (castBackFromVoid)
                {
                    // get the original type. For strings, it's just the type...
                    Type *origType = ie->e1->type->nextOf();
                    // ..but for arrays of type void*, it's the type of the element
                    Expression *xx = NULL;
                    if (ie->e1->op == TOKarrayliteral && ie->e2->op == TOKint64)
                    {
                        ArrayLiteralExp *ale = (ArrayLiteralExp *)ie->e1;
                        size_t indx = (size_t)ie->e2->toInteger();
                        if (indx < ale->elements->dim)
                            xx = (*ale->elements)[indx];
                    }
                    if (xx && xx->op == TOKindex)
                        origType = ((IndexExp *)xx)->e1->type->nextOf();
                    else if (xx && xx->op == TOKaddress)
                        origType= ((AddrExp *)xx)->e1->type;
                    else if (xx && xx->op == TOKvar)
                        origType = ((VarExp *)xx)->var->type;
                    if (!isSafePointerCast(origType, pointee))
                    {
                        e->error("using void* to reinterpret cast from %s* to %s* is not supported in CTFE",
                            origType->toChars(), pointee->toChars());
                        result = CTFEExp::cantexp;
                        return;
                    }
                }
                result->type = e->type;
                return;
            }
            if (e1->op == TOKaddress)
            {
                Type *origType = ((AddrExp *)e1)->e1->type;
                if (isSafePointerCast(origType, pointee))
                {
                    result = new AddrExp(e->loc, ((AddrExp *)e1)->e1);
                    result->type = e->type;
                    return;
                }
            }
            if (e1->op == TOKvar || e1->op == TOKsymoff)
            {
                // type painting operation
                Type *origType = (e1->op == TOKvar) ? ((VarExp *)e1)->var->type :
                        ((SymOffExp *)e1)->var->type;
                if (castBackFromVoid && !isSafePointerCast(origType, pointee))
                {
                    e->error("using void* to reinterpret cast from %s* to %s* is not supported in CTFE",
                        origType->toChars(), pointee->toChars());
                    result = CTFEExp::cantexp;
                    return;
                }
                if (e1->op == TOKvar)
                    result = new VarExp(e->loc, ((VarExp *)e1)->var);
                else
                    result = new SymOffExp(e->loc, ((SymOffExp *)e1)->var, ((SymOffExp *)e1)->offset);
                result->type = e->to;
                return;
            }

            // Check if we have a null pointer (eg, inside a struct)
            e1 = interpret(e1, istate);
            if (e1->op != TOKnull)
            {
                e->error("pointer cast from %s to %s is not supported at compile time",
                    e1->type->toChars(), e->to->toChars());
                result = CTFEExp::cantexp;
                return;
            }
        }
        if (e->to->ty == Tarray && e1->op == TOKslice)
        {
            // Note that the slice may be void[], so when checking for dangerous
            // casts, we need to use the original type, which is se->e1.
            SliceExp *se = (SliceExp *)e1;
            if (!isSafePointerCast(se->e1->type->nextOf(), e->to->nextOf()))
            {
                e->error("array cast from %s to %s is not supported at compile time",
                     se->e1->type->toChars(), e->to->toChars());
                result = CTFEExp::cantexp;
                return;
            }
            e1 = new SliceExp(e1->loc, se->e1, se->lwr, se->upr);
            e1->type = e->to;
            result = e1;
            return;
        }
        // Disallow array type painting, except for conversions between built-in
        // types of identical size.
        if ((e->to->ty == Tsarray || e->to->ty == Tarray) &&
            (e1->type->ty == Tsarray || e1->type->ty == Tarray) &&
            !isSafePointerCast(e1->type->nextOf(), e->to->nextOf()))
        {
            e->error("array cast from %s to %s is not supported at compile time", e1->type->toChars(), e->to->toChars());
            result = CTFEExp::cantexp;
            return;
        }
        if (e->to->ty == Tsarray && e1->op == TOKslice)
            e1 = resolveSlice(e1);
        if (e->to->toBasetype()->ty == Tbool && e1->type->ty == Tpointer)
        {
            result = new IntegerExp(e->loc, e1->op != TOKnull, e->to);
            return;
        }
        result = ctfeCast(e->loc, e->type, e->to, e1);
    }

    void visit(AssertExp *e)
    {
    #if LOG
        printf("%s AssertExp::interpret() %s\n", e->loc.toChars(), e->toChars());
    #endif
        Expression *e1 = interpret(e->e1, istate);
        if (exceptionOrCant(e1))
            return;
        if (isTrueBool(e1))
        {
        }
        else if (e1->isBool(false))
        {
            if (e->msg)
            {
                result = interpret(e->msg, istate);
                if (exceptionOrCant(result))
                    return;
                e->error("%s", result->toChars());
            }
            else
                e->error("%s failed", e->toChars());
            result = CTFEExp::cantexp;
            return;
        }
        else
        {
            e->error("%s is not a compile time boolean expression", e1->toChars());
            result = CTFEExp::cantexp;
            return;
        }
        result = e1;
        return;
    }

    void visit(PtrExp *e)
    {
    #if LOG
        printf("%s PtrExp::interpret() %s\n", e->loc.toChars(), e->toChars());
    #endif

        // Check for int<->float and long<->double casts.
        if (e->e1->op == TOKsymoff && ((SymOffExp *)e->e1)->offset == 0 &&
            isFloatIntPaint(e->type, ((SymOffExp *)e->e1)->var->type))
        {
            // *(cast(int*)&v, where v is a float variable
            result = paintFloatInt(getVarExp(e->loc, istate, ((SymOffExp *)e->e1)->var, ctfeNeedRvalue), e->type);
            return;
        }
        if (e->e1->op == TOKcast && ((CastExp *)e->e1)->e1->op == TOKaddress)
        {
            // *(cast(int *))&x   where x is a float expression
            Expression *x = ((AddrExp *)(((CastExp *)e->e1)->e1))->e1;
            if (isFloatIntPaint(e->type, x->type))
            {
                result = paintFloatInt(interpret(x, istate), e->type);
                return;
            }
        }

        // Constant fold *(&structliteral + offset)
        if (e->e1->op == TOKadd)
        {
            AddExp *ae = (AddExp *)e->e1;
            if (ae->e1->op == TOKaddress && ae->e2->op == TOKint64)
            {
                AddrExp *ade = (AddrExp *)ae->e1;
                Expression *ex = interpret(ade->e1, istate);
                if (exceptionOrCant(ex))
                    return;
                if (ex->op == TOKstructliteral)
                {
                    StructLiteralExp *se = (StructLiteralExp *)ex;
                    dinteger_t offset = ae->e2->toInteger();
                    result = se->getField(e->type, (unsigned)offset);
                    if (!result)
                        result = CTFEExp::cantexp;
                    return;
                }
            }
            result = Ptr(e->type, e->e1).copy();
            return;
        }

        // Check for .classinfo, which is lowered in the semantic pass into **(class).
        if (e->e1->op == TOKstar && e->e1->type->ty == Tpointer && isTypeInfo_Class(e->e1->type->nextOf()))
        {
            result = interpret(((PtrExp *)e->e1)->e1, istate, ctfeNeedLvalue);
            if (exceptionOrCant(result))
                return;
            if (result->op == TOKnull)
            {
                e->error("null pointer dereference evaluating typeid. '%s' is null", ((PtrExp *)e->e1)->e1->toChars());
                result = CTFEExp::cantexp;
                return;
            }
            if (result->op != TOKclassreference)
            {
                e->error("CTFE internal error: determining classinfo");
                result = CTFEExp::cantexp;
                return;
            }
            ClassDeclaration *cd = ((ClassReferenceExp *)result)->originalClass();
            assert(cd);

            // Create the classinfo, if it doesn't yet exist.
            // TODO: This belongs in semantic, CTFE should not have to do this.
            if (!cd->vclassinfo)
                cd->vclassinfo = new TypeInfoClassDeclaration(cd->type);
            result = new SymOffExp(e->loc, cd->vclassinfo, 0);
            result->type = e->type;
            return;
        }

        // It's possible we have an array bounds error. We need to make sure it
        // errors with this line number, not the one where the pointer was set.
        result = interpret(e->e1, istate);
        if (exceptionOrCant(result))
            return;

        if (!(result->op == TOKvar ||
              result->op == TOKdotvar ||
              result->op == TOKindex ||
              result->op == TOKslice ||
              result->op == TOKaddress))
        {
            if (result->op == TOKsymoff)
                e->error("cannot dereference pointer to static variable %s at compile time", ((SymOffExp *)result)->var->toChars());
            else
                e->error("dereference of invalid pointer '%s'", result->toChars());
            result = CTFEExp::cantexp;
            return;
        }
        if (goal != ctfeNeedLvalue && goal != ctfeNeedLvalueRef)
        {
            if (result->op == TOKindex && result->type->ty == Tpointer)
            {
                IndexExp *ie = (IndexExp *)result;
                // Is this a real index to an array of pointers, or just a CTFE pointer?
                // If the index has the same levels of indirection, it's an index
                int srcLevels = 0;
                int destLevels = 0;
                for (Type *xx = ie->e1->type; xx->ty == Tpointer; xx = xx->nextOf())
                    ++srcLevels;
                for (Type *xx = result->type->nextOf(); xx->ty == Tpointer; xx = xx->nextOf())
                    ++destLevels;
                bool isGenuineIndex = (srcLevels == destLevels);

                if ((ie->e1->op == TOKarrayliteral || ie->e1->op == TOKstring) &&
                     ie->e2->op == TOKint64)
                {
                    Expression *dollar = ArrayLength(Type::tsize_t, ie->e1).copy();
                    dinteger_t len = dollar->toInteger();
                    dinteger_t indx = ie->e2->toInteger();
                    assert(indx >=0 && indx <= len); // invalid pointer
                    if (indx == len)
                    {
                        e->error("dereference of pointer %s one past end of memory block limits [0..%lld]",
                            e->toChars(), len);
                        result = CTFEExp::cantexp;
                        return;
                    }
                    result = ctfeIndex(e->loc, e->type, ie->e1, indx);
                    if (isGenuineIndex)
                    {
                        if (result->op == TOKindex)
                            result = interpret(result, istate, goal);
                        else if (result->op == TOKaddress)
                            result = paintTypeOntoLiteral(e->type, ((AddrExp *)result)->e1);
                    }
                    return;
                }
                if (ie->e1->op == TOKassocarrayliteral)
                {
                    result = findKeyInAA(e->loc, (AssocArrayLiteralExp *)ie->e1, ie->e2);
                    assert(!CTFEExp::isCantExp(result));
                    result = paintTypeOntoLiteral(e->type, result);
                    if (isGenuineIndex)
                    {
                        if (result->op == TOKindex)
                            result = interpret(result, istate, goal);
                        else if (result->op == TOKaddress)
                            result = paintTypeOntoLiteral(e->type, ((AddrExp *)result)->e1);
                    }
                    return;
                }
            }
            if (result->op == TOKstructliteral)
                return;

            if (result->op == TOKaddress)
            {
                // We're changing *&e to e.
                result = ((AddrExp *)result)->e1;
            }
            result = interpret(result, istate, goal);
            if (exceptionOrCant(result))
                return;
        }
        else if (result->op == TOKaddress)
        {
            result = ((AddrExp *)result)->e1;  // *(&x) ==> x

            // Bugzilla 13630, convert *(&[1,2,3]) to [1,2,3][0]
            if (result->op == TOKarrayliteral &&
                result->type->toBasetype()->nextOf()->toBasetype()->equivalent(e->type))
            {
                IntegerExp *ofs = new IntegerExp(result->loc, 0, Type::tsize_t);
                result = new IndexExp(e->loc, result, ofs);
                result->type = e->type;
            }
        }
        else if (result->op == TOKnull)
        {
            e->error("dereference of null pointer '%s'", e->e1->toChars());
            result = CTFEExp::cantexp;
            return;
        }
        result = paintTypeOntoLiteral(e->type, result);

    #if LOG
        if (CTFEExp::isCantExp(result))
            printf("PtrExp::interpret() %s = CTFEExp::cantexp\n", e->toChars());
    #endif
    }

    void visit(DotVarExp *e)
    {
    #if LOG
        printf("%s DotVarExp::interpret() %s\n", e->loc.toChars(), e->toChars());
    #endif

        Expression *ex = interpret(e->e1, istate);
        if (exceptionOrCant(ex))
            return;

        if (ex->op == TOKaddress)
            ex = ((AddrExp *)ex)->e1;

        VarDeclaration *v = e->var->isVarDeclaration();
        if (!v)
        {
            e->error("CTFE internal error: %s", e->toChars());
            result = CTFEExp::cantexp;
            return;
        }
        if (ex->op == TOKnull)
        {
            if (ex->type->toBasetype()->ty == Tclass)
                e->error("class '%s' is null and cannot be dereferenced", e->e1->toChars());
            else
                e->error("dereference of null pointer '%s'", e->e1->toChars());
            result = CTFEExp::cantexp;
            return;
        }
        if (ex->op != TOKstructliteral && ex->op != TOKclassreference)
        {
            e->error("%s.%s is not yet implemented at compile time", e->e1->toChars(), e->var->toChars());
            result = CTFEExp::cantexp;
            return;
        }

        StructLiteralExp *se;
        int i;

        // We can't use getField, because it makes a copy
        if (ex->op == TOKclassreference)
        {
            se = ((ClassReferenceExp *)ex)->value;
            i  = ((ClassReferenceExp *)ex)->findFieldIndexByName(v);
        }
        else
        {
            se = (StructLiteralExp *)ex;
            i  = findFieldIndexByName(se->sd, v);
        }
        if (i == -1)
        {
            e->error("couldn't find field %s of type %s in %s", v->toChars(), e->type->toChars(), se->toChars());
            result = CTFEExp::cantexp;
            return;
        }
        result = (*se->elements)[i];
        if (!result)
        {
            e->error("Internal Compiler Error: null field %s", v->toChars());
            result = CTFEExp::cantexp;
            return;
        }

        if (goal == ctfeNeedLvalue || goal == ctfeNeedLvalueRef)
        {
            // If it is an lvalue literal, return it...
            if (result->op == TOKstructliteral)
                return;
            if ((e->type->ty == Tsarray || goal == ctfeNeedLvalue) && (
                result->op == TOKarrayliteral ||
                result->op == TOKassocarrayliteral || result->op == TOKstring ||
                result->op == TOKclassreference || result->op == TOKslice))
            {
                return;
            }
            /* Element is an allocated pointer, which was created in
             * CastExp.
             */
            if (goal == ctfeNeedLvalue && result->op == TOKindex &&
                result->type->equals(e->type) && isPointer(e->type))
            {
                return;
            }
            // ...Otherwise, just return the (simplified) dotvar expression
            result = new DotVarExp(e->loc, ex, v);
            result->type = e->type;
            return;
        }
        // If it is an rvalue literal, return it...
        if (result->op == TOKstructliteral || result->op == TOKarrayliteral ||
            result->op == TOKassocarrayliteral || result->op == TOKstring)
        {
            return;
        }
        if (result->op == TOKvoid)
        {
            VoidInitExp *ve = (VoidInitExp *)result;
            const char *s = ve->var->toChars();
            if (v->overlapped)
            {
                e->error("reinterpretation through overlapped field %s is not allowed in CTFE", s);
                result = CTFEExp::cantexp;
                return;
            }
            e->error("cannot read uninitialized variable %s in CTFE", s);
            result = CTFEExp::cantexp;
            return;
        }
        if (isPointer(e->type))
        {
            result = paintTypeOntoLiteral(e->type, result);
            return;
        }
        if (result->op == TOKvar)
        {
            // Don't typepaint twice, since that might cause an erroneous copy
            result = getVarExp(e->loc, istate, ((VarExp *)result)->var, goal);
            if (!CTFEExp::isCantExp(result) && result->op != TOKthrownexception)
                result = paintTypeOntoLiteral(e->type, result);
            return;
        }
        result = interpret(result, istate, goal);

    #if LOG
        if (CTFEExp::isCantExp(result))
            printf("DotVarExp::interpret() %s = CTFEExp::cantexp\n", e->toChars());
    #endif
    }

    void visit(RemoveExp *e)
    {
    #if LOG
        printf("%s RemoveExp::interpret() %s\n", e->loc.toChars(), e->toChars());
    #endif
        Expression *agg = interpret(e->e1, istate);
        if (exceptionOrCant(agg))
            return;
        Expression *index = interpret(e->e2, istate);
        if (exceptionOrCant(index))
            return;
        if (agg->op == TOKnull)
        {
            result = CTFEExp::voidexp;
            return;
        }
        assert(agg->op == TOKassocarrayliteral);
        AssocArrayLiteralExp *aae = (AssocArrayLiteralExp *)agg;
        Expressions *keysx = aae->keys;
        Expressions *valuesx = aae->values;
        size_t removed = 0;
        for (size_t j = 0; j < valuesx->dim; ++j)
        {
            Expression *ekey = (*keysx)[j];
            int eq = ctfeEqual(e->loc, TOKequal, ekey, index);
            if (eq)
                ++removed;
            else if (removed != 0)
            {
                (*keysx)[j - removed] = ekey;
                (*valuesx)[j - removed] = (*valuesx)[j];
            }
        }
        valuesx->dim = valuesx->dim - removed;
        keysx->dim = keysx->dim - removed;
        result = new IntegerExp(e->loc, removed ? 1 : 0, Type::tbool);
    }

    void visit(ClassReferenceExp *e)
    {
        //printf("ClassReferenceExp::interpret() %s\n", e->value->toChars());
        result = e;
    }

    void visit(VoidInitExp *e)
    {
        e->error("CTFE internal error: trying to read uninitialized variable");
        assert(0);
        result = CTFEExp::cantexp;
    }

    void visit(ThrownExceptionExp *e)
    {
        assert(0); // This should never be interpreted
        result = e;
    }

};

Expression *interpret(Expression *e, InterState *istate, CtfeGoal goal)
{
    if (!e)
        return NULL;
    Interpreter v(istate, goal);
    e->accept(&v);
    return v.result;
}

/***********************************
 * Interpret the statement.
 * Returns:
 *      NULL    continue to next statement
 *      TOKcantexp      cannot interpret statement at compile time
 *      !NULL   expression from return statement, or thrown exception
 */

Expression *interpret(Statement *s, InterState *istate)
{
    if (!s)
        return NULL;
    Interpreter v(istate, ctfeNeedNothing);
    s->accept(&v);
    return v.result;
}

bool scrubArray(Loc loc, Expressions *elems, bool structlit = false);

/* All results destined for use outside of CTFE need to have their CTFE-specific
 * features removed.
 * In particular, all slices must be resolved.
 */
Expression *scrubReturnValue(Loc loc, Expression *e)
{
    if (e->op == TOKclassreference)
    {
        StructLiteralExp *se = ((ClassReferenceExp*)e)->value;
        se->ownedByCtfe = false;
        if (!(se->stageflags & stageScrub))
        {
            int old = se->stageflags;
            se->stageflags |= stageScrub;
            if (!scrubArray(loc, se->elements, true))
                return CTFEExp::cantexp;
            se->stageflags = old;
        }
    }
    if (e->op == TOKvoid)
    {
        error(loc, "uninitialized variable '%s' cannot be returned from CTFE", ((VoidInitExp *)e)->var->toChars());
        e = new ErrorExp();
    }
    if (e->op == TOKslice)
    {
        e = resolveSlice(e);
    }
    if (e->op == TOKstructliteral)
    {
        StructLiteralExp *se = (StructLiteralExp *)e;
        se->ownedByCtfe = false;
        if (!(se->stageflags & stageScrub))
        {
            int old = se->stageflags;
            se->stageflags |= stageScrub;
            if (!scrubArray(loc, se->elements, true))
                return CTFEExp::cantexp;
            se->stageflags = old;
        }
    }
    if (e->op == TOKstring)
    {
        ((StringExp *)e)->ownedByCtfe = false;
    }
    if (e->op == TOKarrayliteral)
    {
        ((ArrayLiteralExp *)e)->ownedByCtfe = false;
        if (!scrubArray(loc, ((ArrayLiteralExp *)e)->elements))
            return CTFEExp::cantexp;
    }
    if (e->op == TOKassocarrayliteral)
    {
        AssocArrayLiteralExp *aae = (AssocArrayLiteralExp *)e;
        aae->ownedByCtfe = false;
        if (!scrubArray(loc, aae->keys))
            return CTFEExp::cantexp;
        if (!scrubArray(loc, aae->values))
            return CTFEExp::cantexp;
        aae->type = toBuiltinAAType(aae->type);
    }
    return e;
}

// Return true if every element is either void,
// or is an array literal or struct literal of void elements.
bool isEntirelyVoid(Expressions *elems)
{
    for (size_t i = 0; i < elems->dim; i++)
    {
        Expression *m = (*elems)[i];
        // It can be NULL for performance reasons,
        // see StructLiteralExp::interpret().
        if (!m)
            continue;

        if (!(m->op == TOKvoid) &&
            !(m->op == TOKarrayliteral && isEntirelyVoid(((ArrayLiteralExp *)m)->elements)) &&
            !(m->op == TOKstructliteral && isEntirelyVoid(((StructLiteralExp *)m)->elements)))
        {
            return false;
        }
    }
    return true;
}

// Scrub all members of an array. Return false if error
bool scrubArray(Loc loc, Expressions *elems, bool structlit)
{
    for (size_t i = 0; i < elems->dim; i++)
    {
        Expression *m = (*elems)[i];
        // It can be NULL for performance reasons,
        // see StructLiteralExp::interpret().
        if (!m)
            continue;

        // A struct .init may contain void members.
        // Static array members are a weird special case (bug 10994).
        if (structlit &&
            ((m->op == TOKvoid) ||
             (m->op == TOKarrayliteral && m->type->ty == Tsarray && isEntirelyVoid(((ArrayLiteralExp *)m)->elements)) ||
             (m->op == TOKstructliteral && isEntirelyVoid(((StructLiteralExp *)m)->elements))))
        {
                m = NULL;
        }
        else
        {
            m = scrubReturnValue(loc, m);
            if (CTFEExp::isCantExp(m))
                return false;
        }
        (*elems)[i] = m;
    }
    return true;
}


/******************************* Special Functions ***************************/

Expression *interpret_length(InterState *istate, Expression *earg)
{
    //printf("interpret_length()\n");
    earg = interpret(earg, istate);
    if (exceptionOrCantInterpret(earg))
        return earg;
    dinteger_t len = 0;
    if (earg->op == TOKassocarrayliteral)
        len = ((AssocArrayLiteralExp *)earg)->keys->dim;
    else
        assert(earg->op == TOKnull);
    Expression *e = new IntegerExp(earg->loc, len, Type::tsize_t);
    return e;
}

Expression *interpret_keys(InterState *istate, Expression *earg, Type *returnType)
{
#if LOG
    printf("interpret_keys()\n");
#endif
    earg = interpret(earg, istate);
    if (exceptionOrCantInterpret(earg))
        return earg;
    if (earg->op == TOKnull)
        return new NullExp(earg->loc, returnType);
    if (earg->op != TOKassocarrayliteral && earg->type->toBasetype()->ty != Taarray)
        return NULL;
    assert(earg->op == TOKassocarrayliteral);
    AssocArrayLiteralExp *aae = (AssocArrayLiteralExp *)earg;
    ArrayLiteralExp *ae = new ArrayLiteralExp(aae->loc, aae->keys);
    ae->ownedByCtfe = aae->ownedByCtfe;
    ae->type = returnType;
    return copyLiteral(ae).copy();
}

Expression *interpret_values(InterState *istate, Expression *earg, Type *returnType)
{
#if LOG
    printf("interpret_values()\n");
#endif
    earg = interpret(earg, istate);
    if (exceptionOrCantInterpret(earg))
        return earg;
    if (earg->op == TOKnull)
        return new NullExp(earg->loc, returnType);
    if (earg->op != TOKassocarrayliteral && earg->type->toBasetype()->ty != Taarray)
        return NULL;
    assert(earg->op == TOKassocarrayliteral);
    AssocArrayLiteralExp *aae = (AssocArrayLiteralExp *)earg;
    ArrayLiteralExp *ae = new ArrayLiteralExp(aae->loc, aae->values);
    ae->ownedByCtfe = aae->ownedByCtfe;
    ae->type = returnType;
    //printf("result is %s\n", e->toChars());
    return copyLiteral(ae).copy();
}

Expression *interpret_dup(InterState *istate, Expression *earg)
{
#if LOG
    printf("interpret_dup()\n");
#endif
    earg = interpret(earg, istate);
    if (exceptionOrCantInterpret(earg))
        return earg;
    if (earg->op == TOKnull)
        return new NullExp(earg->loc, earg->type);
    if (earg->op != TOKassocarrayliteral && earg->type->toBasetype()->ty != Taarray)
        return NULL;
    assert(earg->op == TOKassocarrayliteral);
    AssocArrayLiteralExp *aae = (AssocArrayLiteralExp *)copyLiteral(earg).copy();
    for (size_t i = 0; i < aae->keys->dim; i++)
    {
        if (Expression *e = evaluatePostblit(istate, (*aae->keys)[i]))
            return e;
        if (Expression *e = evaluatePostblit(istate, (*aae->values)[i]))
            return e;
    }
    //printf("result is %s\n", aae->toChars());
    return aae;
}

// signature is int delegate(ref Value) OR int delegate(ref Key, ref Value)
Expression *interpret_aaApply(InterState *istate, Expression *aa, Expression *deleg)
{
    aa = interpret(aa, istate);
    if (exceptionOrCantInterpret(aa))
        return aa;
    if (aa->op != TOKassocarrayliteral)
        return new IntegerExp(deleg->loc, 0, Type::tsize_t);

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
    size_t numParams = fd->parameters->dim;
    assert(numParams == 1 || numParams == 2);

    Parameter *fparam = Parameter::getNth(((TypeFunction *)fd->type)->parameters, numParams - 1);
    bool wantRefValue = 0 != (fparam->storageClass & (STCout | STCref));

    Expressions args;
    args.setDim(numParams);

    AssocArrayLiteralExp *ae = (AssocArrayLiteralExp *)aa;
    if (!ae->keys || ae->keys->dim == 0)
        return new IntegerExp(deleg->loc, 0, Type::tsize_t);
    Expression *eresult;

    for (size_t i = 0; i < ae->keys->dim; ++i)
    {
        Expression *ekey = (*ae->keys)[i];
        Expression *evalue = (*ae->values)[i];
        if (wantRefValue)
        {
            Type *t = evalue->type;
            evalue = new IndexExp(deleg->loc, ae, ekey);
            evalue->type = t;
        }
        args[numParams - 1] = evalue;
        if (numParams == 2) args[0] = ekey;

        eresult = interpret(fd, istate, &args, pthis);
        if (exceptionOrCantInterpret(eresult))
            return eresult;

        assert(eresult->op == TOKint64);
        if (((IntegerExp *)eresult)->getInteger() != 0)
            return eresult;
    }
    return eresult;
}

// Helper function: given a function of type A[] f(...),
// return A[].
Type *returnedArrayType(FuncDeclaration *fd)
{
    assert(fd->type->ty == Tfunction);
    assert(fd->type->nextOf()->ty == Tarray);
    return ((TypeFunction *)fd->type)->nextOf();
}

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
    size_t numParams = fd->parameters->dim;
    assert(numParams == 1 || numParams == 2);
    Type *charType = (*fd->parameters)[numParams-1]->type;
    Type *indexType = numParams == 2 ? (*fd->parameters)[0]->type
                                     : Type::tsize_t;
    size_t len = (size_t)resolveArrayLength(str);
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
    {
        str->error("CTFE internal error: cannot foreach %s", str->toChars());
        return CTFEExp::cantexp;
    }
    Expressions args;
    args.setDim(numParams);

    Expression *eresult;

    // Buffers for encoding; also used for decoding array literals
    utf8_t utf8buf[4];
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
        {
            // If it is an array literal, copy the code points into the buffer
            size_t buflen = 1; // #code points in the buffer
            size_t n = 1;   // #code points in this char
            size_t sz = (size_t)ale->type->nextOf()->size();

            switch (sz)
            {
            case 1:
                if (rvs)
                {
                    // find the start of the string
                    --indx;
                    buflen = 1;
                    while (indx > 0 && buflen < 4)
                    {
                        Expression * r = (*ale->elements)[indx];
                        assert(r->op == TOKint64);
                        utf8_t x = (utf8_t)(((IntegerExp *)r)->getInteger());
                        if ((x & 0xC0) != 0x80)
                            break;
                        ++buflen;
                    }
                }
                else
                    buflen = (indx + 4 > len) ? len - indx : 4;
                for (size_t i = 0; i < buflen; ++i)
                {
                    Expression * r = (*ale->elements)[indx + i];
                    assert(r->op == TOKint64);
                    utf8buf[i] = (utf8_t)(((IntegerExp *)r)->getInteger());
                }
                n = 0;
                errmsg = utf_decodeChar(&utf8buf[0], buflen, &n, &rawvalue);
                break;
            case 2:
                if (rvs)
                {
                    // find the start of the string
                    --indx;
                    buflen = 1;
                    Expression * r = (*ale->elements)[indx];
                    assert(r->op == TOKint64);
                    unsigned short x = (unsigned short)(((IntegerExp *)r)->getInteger());
                    if (indx > 0 && x >= 0xDC00 && x <= 0xDFFF)
                    {
                        --indx;
                        ++buflen;
                    }
                }
                else
                    buflen = (indx + 2 > len) ? len - indx : 2;
                for (size_t i=0; i < buflen; ++i)
                {
                    Expression * r = (*ale->elements)[indx + i];
                    assert(r->op == TOKint64);
                    utf16buf[i] = (unsigned short)(((IntegerExp *)r)->getInteger());
                }
                n = 0;
                errmsg = utf_decodeWchar(&utf16buf[0], buflen, &n, &rawvalue);
                break;
            case 4:
                {
                    if (rvs)
                        --indx;

                    Expression * r = (*ale->elements)[indx];
                    assert(r->op == TOKint64);
                    rawvalue = (dchar_t)((IntegerExp *)r)->getInteger();
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
        {
            // String literals
            size_t saveindx; // used for reverse iteration

            switch (se->sz)
            {
            case 1:
                if (rvs)
                {
                    // find the start of the string
                    utf8_t *s = (utf8_t *)se->string;
                    --indx;
                    while (indx > 0 && ((s[indx]&0xC0) == 0x80))
                        --indx;
                    saveindx = indx;
                }
                errmsg = utf_decodeChar((utf8_t *)se->string, se->len, &indx, &rawvalue);
                if (rvs)
                    indx = saveindx;
                break;
            case 2:
                if (rvs)
                {
                    // find the start
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
        {
            deleg->error("%s", errmsg);
            return CTFEExp::cantexp;
        }

        // Step 2: encode the dchar in the target encoding

        int charlen = 1; // How many codepoints are involved?
        switch (charType->size())
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
            args[0] = new IntegerExp(deleg->loc, currentIndex, indexType);

        Expression *val = NULL;

        for (int k= 0; k < charlen; ++k)
        {
            dchar_t codepoint;
            switch (charType->size())
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

            args[numParams - 1] = val;

            eresult = interpret(fd, istate, &args, pthis);
            if (exceptionOrCantInterpret(eresult))
                return eresult;
            assert(eresult->op == TOKint64);
            if (((IntegerExp *)eresult)->getInteger() != 0)
                return eresult;
        }
    }
    return eresult;
}

/* If this is a built-in function, return the interpreted result,
 * Otherwise, return NULL.
 */
Expression *evaluateIfBuiltin(InterState *istate, Loc loc,
    FuncDeclaration *fd, Expressions *arguments, Expression *pthis)
{
    Expression *e = NULL;
    size_t nargs = arguments ? arguments->dim : 0;
    if (!pthis)
    {
        if (isBuiltin(fd) == BUILTINyes)
        {
            Expressions args;
            args.setDim(nargs);
            for (size_t i = 0; i < args.dim; i++)
            {
                Expression *earg = (*arguments)[i];
                earg = interpret(earg, istate);
                if (exceptionOrCantInterpret(earg))
                    return earg;
                args[i] = earg;
            }
            e = eval_builtin(loc, fd, &args);
            if (!e)
            {
                error(loc, "cannot evaluate unimplemented builtin %s at compile time", fd->toChars());
                e = CTFEExp::cantexp;
            }
        }
    }
    if (!pthis)
    {
        Expression *firstarg =  nargs > 0 ? (*arguments)[0] : NULL;
        if (firstarg && firstarg->type->toBasetype()->ty == Taarray)
        {
            TypeAArray *firstAAtype = (TypeAArray *)firstarg->type;
            if (nargs == 1 && fd->ident == Id::aaLen)
                return interpret_length(istate, firstarg);
            if (nargs == 3 && !strcmp(fd->ident->string, "_aaApply"))
                return interpret_aaApply(istate, firstarg, (Expression *)(arguments->data[2]));
            if (nargs == 3 && !strcmp(fd->ident->string, "_aaApply2"))
                return interpret_aaApply(istate, firstarg, (Expression *)(arguments->data[2]));
            if (nargs == 1 && !strcmp(fd->ident->string, "keys") && !strcmp(fd->toParent2()->ident->string, "object"))
                return interpret_keys(istate, firstarg, firstAAtype->index->arrayOf());
            if (nargs == 1 && !strcmp(fd->ident->string, "values") && !strcmp(fd->toParent2()->ident->string, "object"))
                return interpret_values(istate, firstarg, firstAAtype->nextOf()->arrayOf());
            if (nargs == 1 && !strcmp(fd->ident->string, "rehash") && !strcmp(fd->toParent2()->ident->string, "object"))
                return interpret(firstarg, istate, ctfeNeedLvalue);
            if (nargs == 1 && !strcmp(fd->ident->string, "dup") && !strcmp(fd->toParent2()->ident->string, "object"))
                return interpret_dup(istate, firstarg);
        }
    }
    if (pthis && !fd->fbody && fd->isCtorDeclaration() && fd->parent && fd->parent->parent && fd->parent->parent->ident == Id::object)
    {
        if (pthis->op == TOKclassreference && fd->parent->ident == Id::Throwable)
        {
            // At present, the constructors just copy their arguments into the struct.
            // But we might need some magic if stack tracing gets added to druntime.
            StructLiteralExp *se = ((ClassReferenceExp *)pthis)->value;
            assert(arguments->dim <= se->elements->dim);
            for (size_t i = 0; i < arguments->dim; ++i)
            {
                e = interpret((*arguments)[i], istate);
                if (exceptionOrCantInterpret(e))
                    return e;
                (*se->elements)[i] = e;
            }
            return CTFEExp::voidexp;
        }
    }
    if (nargs == 1 && !pthis &&
        (fd->ident == Id::criticalenter || fd->ident == Id::criticalexit))
    {
        // Support synchronized{} as a no-op
        return CTFEExp::voidexp;
    }
    if (!pthis)
    {
        size_t idlen = strlen(fd->ident->string);
        if (nargs == 2 && (idlen == 10 || idlen == 11) &&
            !strncmp(fd->ident->string, "_aApply", 7))
        {
            // Functions from aApply.d and aApplyR.d in the runtime
            bool rvs = (idlen == 11);   // true if foreach_reverse
            char c = fd->ident->string[idlen-3]; // char width: 'c', 'w', or 'd'
            char s = fd->ident->string[idlen-2]; // string width: 'c', 'w', or 'd'
            char n = fd->ident->string[idlen-1]; // numParams: 1 or 2.
            // There are 12 combinations
            if ((n == '1' || n == '2') &&
                (c == 'c' || c == 'w' || c == 'd') &&
                (s == 'c' || s == 'w' || s == 'd') && c != s)
            {
                Expression *str = (*arguments)[0];
                str = interpret(str, istate);
                if (exceptionOrCantInterpret(str))
                    return str;
                return foreachApplyUtf(istate, str, (*arguments)[1], rvs);
            }
        }
    }
    return e;
}

Expression *evaluatePostblits(InterState *istate, ArrayLiteralExp *ale, size_t lwr, size_t upr)
{
    Type *telem = ale->type->nextOf()->baseElemOf();
    if (telem->ty != Tstruct)
        return NULL;
    StructDeclaration *sd = ((TypeStruct *)telem)->sym;
    if (sd->postblit)
    {
        for (size_t i = lwr; i < upr; i++)
        {
            Expression *e = (*ale->elements)[i];
            if (e->op == TOKarrayliteral)
            {
                ArrayLiteralExp *alex = (ArrayLiteralExp *)e;
                e = evaluatePostblits(istate, alex, 0, alex->elements->dim);
            }
            else
            {
                // e.__postblit()
                assert(e->op == TOKstructliteral);
                e = interpret(sd->postblit, istate, NULL, e);
            }
            if (exceptionOrCantInterpret(e))
                return e;
        }
    }
    return NULL;
}

Expression *evaluatePostblit(InterState *istate, Expression *e)
{
    Type *tb = e->type->baseElemOf();
    if (tb->ty != Tstruct)
        return NULL;
    StructDeclaration *sd = ((TypeStruct *)tb)->sym;
    if (!sd->postblit)
        return NULL;

    if (e->op == TOKarrayliteral)
    {
        ArrayLiteralExp *alex = (ArrayLiteralExp *)e;
        e = evaluatePostblits(istate, alex, 0, alex->elements->dim);
    }
    else if (e->op == TOKstructliteral)
    {
        // e.__postblit()
        e = interpret(sd->postblit, istate, NULL, e);
    }
    else
        assert(0);
    if (exceptionOrCantInterpret(e))
        return e;
    return NULL;
}

Expression *evaluateDtor(InterState *istate, Expression *e)
{
    Type *tb = e->type->baseElemOf();
    if (tb->ty != Tstruct)
        return NULL;
    StructDeclaration *sd = ((TypeStruct *)tb)->sym;
    if (!sd->dtor)
        return NULL;

    if (e->op == TOKarrayliteral)
    {
        ArrayLiteralExp *alex = (ArrayLiteralExp *)e;
        for (size_t i = 0; i < alex->elements->dim; i++)
            e = evaluateDtor(istate, (*alex->elements)[i]);
    }
    else if (e->op == TOKstructliteral)
    {
        // e.__dtor()
        e = interpret(sd->dtor, istate, NULL, e);
    }
    else
        assert(0);
    if (exceptionOrCantInterpret(e))
        return e;
    return NULL;
}

/*************************** CTFE Sanity Checks ***************************/

/* Setter functions for CTFE variable values.
 * These functions exist to check for compiler CTFE bugs.
 */
bool hasValue(VarDeclaration *vd)
{
    if (vd->ctfeAdrOnStack == (size_t)-1)
        return false;
    return NULL != getValue(vd);
}

Expression *getValue(VarDeclaration *vd)
{
    return ctfeStack.getValue(vd);
}

void setValueNull(VarDeclaration *vd)
{
    ctfeStack.setValue(vd, NULL);
}

// Don't check for validity
void setValueWithoutChecking(VarDeclaration *vd, Expression *newval)
{
    ctfeStack.setValue(vd, newval);
}

void setValue(VarDeclaration *vd, Expression *newval)
{
    assert(isCtfeValueValid(newval));
    ctfeStack.setValue(vd, newval);
}
