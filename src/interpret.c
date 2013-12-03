// Compiler implementation of the D programming language
// Copyright (c) 1999-2012 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

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
    Array<void> savedId; // id of the previous state of that var

    Array<void> frames;  // all previous frame pointers
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
    Statement *gotoTarget;      /* target of EXP_GOTO_INTERPRET result; also
                                 * target of labelled EXP_BREAK_INTERPRET or
                                 * EXP_CONTINUE_INTERPRET. (NULL if no label).
                                 */
    bool awaitingLvalueReturn;  // Support for ref return values:
           // Any return to this function should return an lvalue.
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
    size_t oldframe = framepointer;
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
    if (v->ctfeAdrOnStack!= (size_t)-1
        && v->ctfeAdrOnStack >= framepointer)
    {   // Already exists in this frame, reuse it.
        values[v->ctfeAdrOnStack] = NULL;
        return;
    }
    savedId.push((void *)(size_t)(v->ctfeAdrOnStack));
    v->ctfeAdrOnStack = values.dim;
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
        v->ctfeAdrOnStack = (size_t)(savedId[i]);
    }
    values.setDim(stackpointer);
    vars.setDim(stackpointer);
    savedId.setDim(stackpointer);
}

void CtfeStack::saveGlobalConstant(VarDeclaration *v, Expression *e)
{
#if DMDV2
     assert( v->init && (v->isConst() || v->isImmutable() || v->storage_class & STCmanifest) && !v->isCTFE());
#else
     assert( v->init && v->isConst() && !v->isCTFE());
#endif
     v->ctfeAdrOnStack = globalValues.dim;
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


Expression * resolveReferences(Expression *e);
Expression *getVarExp(Loc loc, InterState *istate, Declaration *d, CtfeGoal goal);
VarDeclaration *findParentVar(Expression *e);
Expression *evaluateIfBuiltin(InterState *istate, Loc loc,
    FuncDeclaration *fd, Expressions *arguments, Expression *pthis);
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
    static int walkAllVars(Expression *e, void *_this);
    void onExpression(Expression *e)
    {
        e->apply(&walkAllVars, this);
    }
};

int CompiledCtfeFunction::walkAllVars(Expression *e, void *_this)
{
    CompiledCtfeFunction *ccf = (CompiledCtfeFunction *)_this;
    if (e->op == TOKerror)
    {
        // Currently there's a front-end bug: silent errors
        // can occur inside delegate literals inside is(typeof()).
        // Suppress the check in this case.
        if (global.gag && ccf->func)
            return 1;

        e->error("CTFE internal error: ErrorExp in %s\n", ccf->func ? ccf->func->loc.toChars() : ccf->callingloc.toChars());
        assert(0);
    }
    if (e->op == TOKdeclaration)
    {
        DeclarationExp *decl = (DeclarationExp *)e;
        VarDeclaration *v = decl->declaration->isVarDeclaration();
        if (!v)
            return 0;
        TupleDeclaration *td = v->toAlias()->isTupleDeclaration();
        if (td)
        {
            if (!td->objects)
                return 0;
            for(size_t i= 0; i < td->objects->dim; ++i)
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
    else if (e->op == TOKindex && ((IndexExp *)e)->lengthVar)
        ccf->onDeclaration( ((IndexExp *)e)->lengthVar);
    else if (e->op == TOKslice && ((SliceExp *)e)->lengthVar)
        ccf->onDeclaration( ((SliceExp *)e)->lengthVar);
    return 0;
}

void Statement::ctfeCompile(CompiledCtfeFunction *ccf)
{
#if LOGCOMPILE
    printf("%s Statement::ctfeCompile %s\n", loc.toChars(), toChars());
#endif
    assert(0);
}

void ExpStatement::ctfeCompile(CompiledCtfeFunction *ccf)
{
#if LOGCOMPILE
    printf("%s ExpStatement::ctfeCompile\n", loc.toChars());
#endif
    if (exp)
        ccf->onExpression(exp);
}

void CompoundStatement::ctfeCompile(CompiledCtfeFunction *ccf)
{
#if LOGCOMPILE
    printf("%s CompoundStatement::ctfeCompile\n", loc.toChars());
#endif
    for (size_t i = 0; i < statements->dim; i++)
    {   Statement *s = (*statements)[i];
        if (s)
            s->ctfeCompile(ccf);
    }
}

void UnrolledLoopStatement::ctfeCompile(CompiledCtfeFunction *ccf)
{
#if LOGCOMPILE
    printf("%s UnrolledLoopStatement::ctfeCompile\n", loc.toChars());
#endif
    for (size_t i = 0; i < statements->dim; i++)
    {   Statement *s = (*statements)[i];
        if (s)
            s->ctfeCompile(ccf);
    }
}

void IfStatement::ctfeCompile(CompiledCtfeFunction *ccf)
{
#if LOGCOMPILE
    printf("%s IfStatement::ctfeCompile\n", loc.toChars());
#endif

    ccf->onExpression(condition);
    if (ifbody)
        ifbody->ctfeCompile(ccf);
    if (elsebody)
        elsebody->ctfeCompile(ccf);
}

void ScopeStatement::ctfeCompile(CompiledCtfeFunction *ccf)
{
#if LOGCOMPILE
    printf("%s ScopeStatement::ctfeCompile\n", loc.toChars());
#endif
    if (statement)
        statement->ctfeCompile(ccf);
}

void OnScopeStatement::ctfeCompile(CompiledCtfeFunction *ccf)
{
#if LOGCOMPILE
    printf("%s OnScopeStatement::ctfeCompile\n", loc.toChars());
#endif
    // rewritten to try/catch/finally
    assert(0);
}

void DoStatement::ctfeCompile(CompiledCtfeFunction *ccf)
{
#if LOGCOMPILE
    printf("%s DoStatement::ctfeCompile\n", loc.toChars());
#endif
    ccf->onExpression(condition);
    if (body)
        body->ctfeCompile(ccf);
}

void WhileStatement::ctfeCompile(CompiledCtfeFunction *ccf)
{
#if LOGCOMPILE
    printf("%s WhileStatement::ctfeCompile\n", loc.toChars());
#endif
    // rewritten to ForStatement
    assert(0);
}

void ForStatement::ctfeCompile(CompiledCtfeFunction *ccf)
{
#if LOGCOMPILE
    printf("%s ForStatement::ctfeCompile\n", loc.toChars());
#endif

    if (init)
        init->ctfeCompile(ccf);
    if (condition)
        ccf->onExpression(condition);
    if (increment)
        ccf->onExpression(increment);
    if (body)
        body->ctfeCompile(ccf);
}

void ForeachStatement::ctfeCompile(CompiledCtfeFunction *ccf)
{
#if LOGCOMPILE
    printf("%s ForeachStatement::ctfeCompile\n", loc.toChars());
#endif
    // rewritten for ForStatement
    assert(0);
}


void SwitchStatement::ctfeCompile(CompiledCtfeFunction *ccf)
{
#if LOGCOMPILE
    printf("%s SwitchStatement::ctfeCompile\n", loc.toChars());
#endif
    ccf->onExpression(condition);
    // Note that the body contains the the Case and Default
    // statements, so we only need to compile the expressions
    for (size_t i = 0; i < cases->dim; i++)
    {
        ccf->onExpression((*cases)[i]->exp);
    }
    if (body)
        body->ctfeCompile(ccf);
}

void CaseStatement::ctfeCompile(CompiledCtfeFunction *ccf)
{
#if LOGCOMPILE
    printf("%s CaseStatement::ctfeCompile\n", loc.toChars());
#endif
    if (statement)
        statement->ctfeCompile(ccf);
}

void DefaultStatement::ctfeCompile(CompiledCtfeFunction *ccf)
{
#if LOGCOMPILE
    printf("%s DefaultStatement::ctfeCompile\n", loc.toChars());
#endif
    if (statement)
        statement->ctfeCompile(ccf);
}

void GotoDefaultStatement::ctfeCompile(CompiledCtfeFunction *ccf)
{
#if LOGCOMPILE
    printf("%s GotoDefaultStatement::ctfeCompile\n", loc.toChars());
#endif
}

void GotoCaseStatement::ctfeCompile(CompiledCtfeFunction *ccf)
{
#if LOGCOMPILE
    printf("%s GotoCaseStatement::ctfeCompile\n", loc.toChars());
#endif
}

void SwitchErrorStatement::ctfeCompile(CompiledCtfeFunction *ccf)
{
#if LOGCOMPILE
    printf("%s SwitchErrorStatement::ctfeCompile\n", loc.toChars());
#endif
}

void ReturnStatement::ctfeCompile(CompiledCtfeFunction *ccf)
{
#if LOGCOMPILE
    printf("%s ReturnStatement::ctfeCompile\n", loc.toChars());
#endif
    if (exp)
        ccf->onExpression(exp);
}

void BreakStatement::ctfeCompile(CompiledCtfeFunction *ccf)
{
#if LOGCOMPILE
    printf("%s BreakStatement::ctfeCompile\n", loc.toChars());
#endif
}

void ContinueStatement::ctfeCompile(CompiledCtfeFunction *ccf)
{
#if LOGCOMPILE
    printf("%s ContinueStatement::ctfeCompile\n", loc.toChars());
#endif
}

void WithStatement::ctfeCompile(CompiledCtfeFunction *ccf)
{
#if LOGCOMPILE
    printf("%s WithStatement::ctfeCompile\n", loc.toChars());
#endif
    // If it is with(Enum) {...}, just execute the body.
    if (exp->op == TOKimport || exp->op == TOKtype)
    {}
    else
    {
        ccf->onDeclaration(wthis);
        ccf->onExpression(exp);
    }
    if (body)
        body->ctfeCompile(ccf);
}

void TryCatchStatement::ctfeCompile(CompiledCtfeFunction *ccf)
{
#if LOGCOMPILE
    printf("%s TryCatchStatement::ctfeCompile\n", loc.toChars());
#endif
    if (body)
        body->ctfeCompile(ccf);
    for (size_t i = 0; i < catches->dim; i++)
    {
        Catch *ca = (*catches)[i];
        if (ca->var)
            ccf->onDeclaration(ca->var);
        if (ca->handler)
            ca->handler->ctfeCompile(ccf);
    }
}

void TryFinallyStatement::ctfeCompile(CompiledCtfeFunction *ccf)
{
#if LOGCOMPILE
    printf("%s TryFinallyStatement::ctfeCompile\n", loc.toChars());
#endif
    if (body)
        body->ctfeCompile(ccf);
    if (finalbody)
        finalbody->ctfeCompile(ccf);
}

void ThrowStatement::ctfeCompile(CompiledCtfeFunction *ccf)
{
#if LOGCOMPILE
    printf("%s ThrowStatement::ctfeCompile\n", loc.toChars());
#endif
    ccf->onExpression(exp);
}

void GotoStatement::ctfeCompile(CompiledCtfeFunction *ccf)
{
#if LOGCOMPILE
    printf("%s GotoStatement::ctfeCompile\n", loc.toChars());
#endif
}

void LabelStatement::ctfeCompile(CompiledCtfeFunction *ccf)
{
#if LOGCOMPILE
    printf("%s LabelStatement::ctfeCompile\n", loc.toChars());
#endif
    if (statement)
        statement->ctfeCompile(ccf);
}

#if DMDV2
void ImportStatement::ctfeCompile(CompiledCtfeFunction *ccf)
{
#if LOGCOMPILE
    printf("%s ImportStatement::ctfeCompile\n", loc.toChars());
#endif
    // Contains no variables or executable code
}

void ForeachRangeStatement::ctfeCompile(CompiledCtfeFunction *ccf)
{
#if LOGCOMPILE
    printf("%s ForeachRangeStatement::ctfeCompile\n", loc.toChars());
#endif
    // rewritten for ForStatement
    assert(0);
}

#endif

void AsmStatement::ctfeCompile(CompiledCtfeFunction *ccf)
{
#if LOGCOMPILE
    printf("%s AsmStatement::ctfeCompile\n", loc.toChars());
#endif
    // we can't compile asm statements
}

/*************************************
 * Compile this function for CTFE.
 * At present, this merely allocates variables.
 */
void FuncDeclaration::ctfeCompile()
{
#if LOGCOMPILE
    printf("\n%s FuncDeclaration::ctfeCompile %s\n", loc.toChars(), toChars());
#endif
    assert(!ctfeCode);
    assert(!semantic3Errors);
    assert(semanticRun == PASSsemantic3done);

    ctfeCode = new CompiledCtfeFunction(this);
    if (parameters)
    {
        Type *tb = type->toBasetype();
        assert(tb->ty == Tfunction);
        TypeFunction *tf = (TypeFunction *)tb;
        for (size_t i = 0; i < parameters->dim; i++)
        {
            Parameter *arg = Parameter::getNth(tf->parameters, i);
            VarDeclaration *v = (*parameters)[i];
            ctfeCode->onDeclaration(v);
        }
    }
    if (vresult)
        ctfeCode->onDeclaration(vresult);
    fbody->ctfeCompile(ctfeCode);
}

/*************************************
 *
 * Entry point for CTFE.
 * A compile-time result is required. Give an error if not possible
 */
Expression *Expression::ctfeInterpret()
{
    if (type == Type::terror)
        return this;

    // This code is outside a function, but still needs to be compiled
    // (there are compiler-generated temporary variables such as __dollar).
    // However, this will only be run once and can then be discarded.
    CompiledCtfeFunction ctfeCodeGlobal(NULL);
    ctfeCodeGlobal.callingloc = loc;
    ctfeCodeGlobal.onExpression(this);

    Expression *e = interpret(NULL);
    if (e != EXP_CANT_INTERPRET)
        e = scrubReturnValue(loc, e);
    if (e == EXP_CANT_INTERPRET)
        e = new ErrorExp();
    return e;
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
 * Return result expression if successful, EXP_CANT_INTERPRET if not,
 * or EXP_VOID_INTERPRET if function returned void.
 */

Expression *FuncDeclaration::interpret(InterState *istate, Expressions *arguments, Expression *thisarg)
{
#if LOG
    printf("\n********\n%s FuncDeclaration::interpret(istate = %p) %s\n", loc.toChars(), istate, toChars());
#endif
    if (semanticRun == PASSsemantic3)
    {
        error("circular dependency. Functions cannot be interpreted while being compiled");
        return EXP_CANT_INTERPRET;
    }
    if (!functionSemantic3())
        return EXP_CANT_INTERPRET;
    if (semanticRun < PASSsemantic3done)
        return EXP_CANT_INTERPRET;

    // CTFE-compile the function
    if (!ctfeCode)
        ctfeCompile();

    Type *tb = type->toBasetype();
    assert(tb->ty == Tfunction);
    TypeFunction *tf = (TypeFunction *)tb;
    if (tf->varargs && arguments &&
        ((parameters && arguments->dim != parameters->dim) || (!parameters && arguments->dim)))
    {
        error("C-style variadic functions are not yet implemented in CTFE");
        return EXP_CANT_INTERPRET;
    }

    // Nested functions always inherit the 'this' pointer from the parent,
    // except for delegates. (Note that the 'this' pointer may be null).
    // Func literals report isNested() even if they are in global scope,
    // so we need to check that the parent is a function.
    if (isNested() && toParent2()->isFuncDeclaration() && !thisarg && istate)
        thisarg = ctfeStack.getThis();

    size_t dim = 0;
    if (needThis() && !thisarg)
    {   // error, no this. Prevent segfault.
        error("need 'this' to access member %s", toChars());
        return EXP_CANT_INTERPRET;
    }
    if (thisarg && !istate)
    {   // Check that 'this' aleady has a value
        if (thisarg->interpret(istate) == EXP_CANT_INTERPRET)
            return EXP_CANT_INTERPRET;
    }
    static int evaluatingArgs = 0;

    // Place to hold all the arguments to the function while
    // we are evaluating them.
    Expressions eargs;

    if (arguments)
    {
        dim = arguments->dim;
        assert(!dim || (parameters && (parameters->dim == dim)));

        /* Evaluate all the arguments to the function,
         * store the results in eargs[]
         */
        eargs.setDim(dim);
        for (size_t i = 0; i < dim; i++)
        {   Expression *earg = (*arguments)[i];
            Parameter *arg = Parameter::getNth(tf->parameters, i);

            if (arg->storageClass & (STCout | STCref))
            {
                if (!istate && (arg->storageClass & STCout))
                {   // initializing an out parameter involves writing to it.
                    earg->error("global %s cannot be passed as an 'out' parameter at compile time", earg->toChars());
                    return EXP_CANT_INTERPRET;
                }
                // Convert all reference arguments into lvalue references
                ++evaluatingArgs;
                earg = earg->interpret(istate, ctfeNeedLvalueRef);
                --evaluatingArgs;
                if (earg == EXP_CANT_INTERPRET)
                    return earg;
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
                ++evaluatingArgs;
                earg = earg->interpret(istate);
                --evaluatingArgs;
                if (earg == EXP_CANT_INTERPRET)
                    return earg;
                /* Struct literals are passed by value, but we don't need to
                 * copy them if they are passed as const
                 */
                if (earg->op == TOKstructliteral
#if DMDV2
                    && !(arg->storageClass & (STCconst | STCimmutable))
#endif
                )
                    earg = copyLiteral(earg);
            }
            if (earg->op == TOKthrownexception)
            {
                if (istate)
                    return earg;
                ((ThrownExceptionExp *)earg)->generateUncaughtError();
                return EXP_CANT_INTERPRET;
            }
            eargs[i] = earg;
        }
    }

    // Now that we've evaluated all the arguments, we can start the frame
    // (this is the moment when the 'call' actually takes place).

    InterState istatex;
    istatex.caller = istate;
    istatex.fd = this;
    ctfeStack.startFrame(thisarg);

    if (arguments)
    {

        for (size_t i = 0; i < dim; i++)
        {   Expression *earg = eargs[i];
            Parameter *arg = Parameter::getNth(tf->parameters, i);
            VarDeclaration *v = (*parameters)[i];
#if LOG
            printf("arg[%d] = %s\n", i, earg->toChars());
#endif
            if (arg->storageClass & (STCout | STCref) && earg->op == TOKvar)
            {
                VarExp *ve = (VarExp *)earg;
                VarDeclaration *v2 = ve->var->isVarDeclaration();
                if (!v2)
                {
                    error("cannot interpret %s as a ref parameter", ve->toChars());
                    return EXP_CANT_INTERPRET;
                }
                /* The push() isn't a variable we'll use, it's just a place
                 * to save the old value of v.
                 * Note that v might be v2! So we need to save v2's index
                 * before pushing.
                 */
                size_t oldadr = v2->ctfeAdrOnStack;
                ctfeStack.push(v);
                v->ctfeAdrOnStack = oldadr;
                assert(v2->hasValue());
            }
            else
            {   // Value parameters and non-trivial references
                ctfeStack.push(v);
                v->setValueWithoutChecking(earg);
            }
#if LOG || LOGASSIGN
            printf("interpreted arg[%d] = %s\n", i, earg->toChars());
            showCtfeExpr(earg);
#endif
        }
    }

    if (vresult)
        ctfeStack.push(vresult);

    // Enter the function
    ++CtfeStatus::callDepth;
    if (CtfeStatus::callDepth > CtfeStatus::maxCallDepth)
        CtfeStatus::maxCallDepth = CtfeStatus::callDepth;

    Expression *e = NULL;
    while (1)
    {
        if (CtfeStatus::callDepth > CTFE_RECURSION_LIMIT)
        {   // This is a compiler error. It must not be suppressed.
            global.gag = 0;
            error("CTFE recursion limit exceeded");
            e = EXP_CANT_INTERPRET;
            break;
        }
        e = fbody->interpret(&istatex);
        if (e == EXP_CANT_INTERPRET)
        {
#if LOG
            printf("function body failed to interpret\n");
#endif
        }

        if (istatex.start)
        {
            error("CTFE internal error: failed to resume at statement %s", istatex.start->toChars());
            return EXP_CANT_INTERPRET;
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

    // Leave the function
    --CtfeStatus::callDepth;

    ctfeStack.endFrame();

    // If fell off the end of a void function, return void
    if (!e && type->toBasetype()->nextOf()->ty == Tvoid)
        return EXP_VOID_INTERPRET;

    // If result is void, return void
    if (e == EXP_VOID_INTERPRET)
        return e;

    // If it generated an exception, return it
    if (exceptionOrCantInterpret(e))
    {
        if (istate || e == EXP_CANT_INTERPRET)
            return e;
        ((ThrownExceptionExp *)e)->generateUncaughtError();
        return EXP_CANT_INTERPRET;
    }

    return e;
}

/******************************** Statement ***************************/

/***********************************
 * Interpret the statement.
 * Returns:
 *      NULL    continue to next statement
 *      EXP_CANT_INTERPRET      cannot interpret statement at compile time
 *      !NULL   expression from return statement, or thrown exception
 */

Expression *Statement::interpret(InterState *istate)
{
#if LOG
    printf("%s Statement::interpret()\n", loc.toChars());
#endif
    if (istate->start)
    {   if (istate->start != this)
            return NULL;
        istate->start = NULL;
    }

    error("Statement %s cannot be interpreted at compile time", this->toChars());
    return EXP_CANT_INTERPRET;
}

Expression *ExpStatement::interpret(InterState *istate)
{
#if LOG
    printf("%s ExpStatement::interpret(%s)\n", loc.toChars(), exp ? exp->toChars() : "");
#endif
    if (istate->start)
    {   if (istate->start != this)
            return NULL;
        istate->start = NULL;
    }

    if (exp)
    {
        Expression *e = exp->interpret(istate, ctfeNeedNothing);
        if (e == EXP_CANT_INTERPRET)
        {
            //printf("-ExpStatement::interpret(): %p\n", e);
            return EXP_CANT_INTERPRET;
        }
        if (e && e!= EXP_VOID_INTERPRET && e->op == TOKthrownexception)
            return e;
    }
    return NULL;
}

Expression *CompoundStatement::interpret(InterState *istate)
{   Expression *e = NULL;

#if LOG
    printf("%s CompoundStatement::interpret()\n", loc.toChars());
#endif
    if (istate->start == this)
        istate->start = NULL;
    if (statements)
    {
        for (size_t i = 0; i < statements->dim; i++)
        {   Statement *s = (*statements)[i];

            if (s)
            {
                e = s->interpret(istate);
                if (e)
                    break;
            }
        }
    }
#if LOG
    printf("%s -CompoundStatement::interpret() %p\n", loc.toChars(), e);
#endif
    return e;
}

Expression *UnrolledLoopStatement::interpret(InterState *istate)
{   Expression *e = NULL;

#if LOG
    printf("%s UnrolledLoopStatement::interpret()\n", loc.toChars());
#endif
    if (istate->start == this)
        istate->start = NULL;
    if (statements)
    {
        for (size_t i = 0; i < statements->dim; i++)
        {   Statement *s = (*statements)[i];

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

Expression *IfStatement::interpret(InterState *istate)
{
#if LOG
    printf("%s IfStatement::interpret(%s)\n", loc.toChars(), condition->toChars());
#endif

    if (istate->start == this)
        istate->start = NULL;
    if (istate->start)
    {
        Expression *e = NULL;
        if (ifbody)
            e = ifbody->interpret(istate);
        if (exceptionOrCantInterpret(e))
            return e;
        if (istate->start && elsebody)
            e = elsebody->interpret(istate);
        return e;
    }

    Expression *e = condition->interpret(istate);
    assert(e);
    //if (e == EXP_CANT_INTERPRET) printf("cannot interpret\n");
    if (e != EXP_CANT_INTERPRET && (e && e->op != TOKthrownexception))
    {
        if (isTrueBool(e))
            e = ifbody ? ifbody->interpret(istate) : NULL;
        else if (e->isBool(false))
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
    printf("%s ScopeStatement::interpret()\n", loc.toChars());
#endif
    if (istate->start == this)
        istate->start = NULL;
    return statement ? statement->interpret(istate) : NULL;
}


/**
  Given an expression e which is about to be returned from the current
  function, generate an error if it contains pointers to local variables.
  Return true if it is safe to return, false if an error was generated.

  Only checks expressions passed by value (pointers to local variables
  may already be stored in members of classes, arrays, or AAs which
  were passed as mutable function parameters).
*/
bool stopPointersEscapingFromArray(Loc loc, Expressions *elems);

bool stopPointersEscaping(Loc loc, Expression *e)
{
    if (!e->type->hasPointers())
        return true;
    if ( isPointer(e->type) )
    {
        Expression *x = e;
        if (e->op == TOKaddress)
            x = ((AddrExp *)e)->e1;
        if (x->op == TOKvar && ((VarExp *)x)->var->isVarDeclaration() &&
            ctfeStack.isInCurrentFrame( ((VarExp *)x)->var->isVarDeclaration() ) )
        {   error(loc, "returning a pointer to a local stack variable");
            return false;
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
bool stopPointersEscapingFromArray(Loc loc, Expressions *elems)
{
    for (size_t i = 0; i < elems->dim; i++)
    {
        Expression *m = (*elems)[i];
        if (!m)
            continue;
        if (m)
            if ( !stopPointersEscaping(loc, m) )
                return false;
    }
    return true;
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
                return EXP_CANT_INTERPRET;
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
                return EXP_CANT_INTERPRET;
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
            return EXP_CANT_INTERPRET;
    }
    if (e->op == TOKassocarrayliteral)
    {
        AssocArrayLiteralExp *aae = (AssocArrayLiteralExp *)e;
        aae->ownedByCtfe = false;
        if (!scrubArray(loc, aae->keys))
            return EXP_CANT_INTERPRET;
        if (!scrubArray(loc, aae->values))
            return EXP_CANT_INTERPRET;
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
             (m->op == TOKstructliteral && isEntirelyVoid(((StructLiteralExp *)m)->elements)))
           )
        {
                m = NULL;
        }
        else
        {
            m = scrubReturnValue(loc, m);
            if (m == EXP_CANT_INTERPRET)
                return false;
        }
        (*elems)[i] = m;
    }
    return true;
}


Expression *ReturnStatement::interpret(InterState *istate)
{
#if LOG
    printf("%s ReturnStatement::interpret(%s)\n", loc.toChars(), exp ? exp->toChars() : "");
#endif
    if (istate->start)
    {   if (istate->start != this)
            return NULL;
        istate->start = NULL;
    }

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
    if ( isPointer(exp->type) )
    {   e = exp->interpret(istate, ctfeNeedLvalue);
        if (exceptionOrCantInterpret(e))
            return e;
    }
    else
    {
        e = exp->interpret(istate);
        if (exceptionOrCantInterpret(e))
            return e;
    }

    // Disallow returning pointers to stack-allocated variables (bug 7876)

    if (!stopPointersEscaping(loc, e))
        return EXP_CANT_INTERPRET;

    if (needToCopyLiteral(e))
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
    printf("%s BreakStatement::interpret()\n", loc.toChars());
#endif
    if (istate->start)
    {   if (istate->start != this)
            return NULL;
        istate->start = NULL;
    }

    if (ident)
    {
        LabelDsymbol *label = istate->fd->searchLabel(ident);
        assert(label && label->statement);
        LabelStatement *ls = label->statement;
        Statement *s;
        if (ls->gotoTarget)
            s = ls->gotoTarget;
        else
        {
            s = ls->statement;
            if (s->isScopeStatement())
                s = s->isScopeStatement()->statement;
        }
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
    printf("%s ContinueStatement::interpret()\n", loc.toChars());
#endif
    if (istate->start)
    {   if (istate->start != this)
            return NULL;
        istate->start = NULL;
    }

    if (ident)
    {
        LabelDsymbol *label = istate->fd->searchLabel(ident);
        assert(label && label->statement);
        LabelStatement *ls = label->statement;
        Statement *s;
        if (ls->gotoTarget)
            s = ls->gotoTarget;
        else
        {
            s = ls->statement;
            if (s->isScopeStatement())
                s = s->isScopeStatement()->statement;
        }
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
    printf("%s DoStatement::interpret()\n", loc.toChars());
#endif
    if (istate->start == this)
        istate->start = NULL;
    Expression *e;

    while (1)
    {
        bool wasGoto = !!istate->start;
        e = body ? body->interpret(istate) : NULL;
        if (e == EXP_CANT_INTERPRET)
            break;
        if (wasGoto && istate->start)
            return NULL;
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

        istate->gotoTarget = NULL;
        e = condition->interpret(istate);
        if (exceptionOrCantInterpret(e))
            break;
        if (!e->isConst())
        {   e = EXP_CANT_INTERPRET;
            break;
        }
        if (isTrueBool(e))
        {
        }
        else if (e->isBool(false))
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
    printf("%s ForStatement::interpret()\n", loc.toChars());
#endif
    if (istate->start == this)
        istate->start = NULL;
    Expression *e;

    if (init)
    {
        e = init->interpret(istate);
        if (exceptionOrCantInterpret(e))
            return e;
        assert(!e);
    }
    while (1)
    {
        if (condition && !istate->start)
        {
            e = condition->interpret(istate);
            if (exceptionOrCantInterpret(e))
                break;
            if (!e->isConst())
            {   e = EXP_CANT_INTERPRET;
                break;
            }
            if (e->isBool(false))
            {   e = NULL;
                break;
            }
            assert( isTrueBool(e) );
        }

        bool wasGoto = !!istate->start;
        e = body ? body->interpret(istate) : NULL;
        if (e == EXP_CANT_INTERPRET)
            break;
        if (wasGoto && istate->start)
            return NULL;

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
        istate->gotoTarget = NULL;

        if (increment)
        {
            e = increment->interpret(istate);
            if (e == EXP_CANT_INTERPRET)
                break;
        }
    }
    return e;
}

Expression *ForeachStatement::interpret(InterState *istate)
{
    assert(0);                  // rewritten to ForStatement
    return NULL;
}

#if DMDV2
Expression *ForeachRangeStatement::interpret(InterState *istate)
{
    assert(0);                  // rewritten to ForStatement
    return NULL;
}
#endif

Expression *SwitchStatement::interpret(InterState *istate)
{
#if LOG
    printf("%s SwitchStatement::interpret()\n", loc.toChars());
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
    if (exceptionOrCantInterpret(econdition))
        return econdition;

    Statement *s = NULL;
    if (cases)
    {
        for (size_t i = 0; i < cases->dim; i++)
        {
            CaseStatement *cs = (*cases)[i];
            Expression * caseExp = cs->exp->interpret(istate);
            if (exceptionOrCantInterpret(caseExp))
                return caseExp;
            int eq = ctfeEqual(caseExp->loc, TOKequal, econdition, caseExp);
            if (eq)
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
    printf("%s CaseStatement::interpret(%s) this = %p\n", loc.toChars(), exp->toChars(), this);
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
    printf("%s DefaultStatement::interpret()\n", loc.toChars());
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
    printf("%s GotoStatement::interpret()\n", loc.toChars());
#endif
    if (istate->start)
    {   if (istate->start != this)
            return NULL;
        istate->start = NULL;
    }

    assert(label && label->statement);
    istate->gotoTarget = label->statement;
    return EXP_GOTO_INTERPRET;
}

Expression *GotoCaseStatement::interpret(InterState *istate)
{
#if LOG
    printf("%s GotoCaseStatement::interpret()\n", loc.toChars());
#endif
    if (istate->start)
    {   if (istate->start != this)
            return NULL;
        istate->start = NULL;
    }

    assert(cs);
    istate->gotoTarget = cs;
    return EXP_GOTO_INTERPRET;
}

Expression *GotoDefaultStatement::interpret(InterState *istate)
{
#if LOG
    printf("%s GotoDefaultStatement::interpret()\n", loc.toChars());
#endif
    if (istate->start)
    {   if (istate->start != this)
            return NULL;
        istate->start = NULL;
    }

    assert(sw && sw->sdefault);
    istate->gotoTarget = sw->sdefault;
    return EXP_GOTO_INTERPRET;
}

Expression *LabelStatement::interpret(InterState *istate)
{
#if LOG
    printf("%s LabelStatement::interpret()\n", loc.toChars());
#endif
    if (istate->start == this)
        istate->start = NULL;
    return statement ? statement->interpret(istate) : NULL;
}


Expression *TryCatchStatement::interpret(InterState *istate)
{
#if LOG
    printf("%s TryCatchStatement::interpret()\n", loc.toChars());
#endif
    if (istate->start == this)
        istate->start = NULL;
    if (istate->start)
    {
        Expression *e = NULL;
        if (body)
            e = body->interpret(istate);
        for (size_t i = 0; !e && istate->start && i < catches->dim; i++)
        {
            Catch *ca = (*catches)[i];
            if (ca->handler)
                e = ca->handler->interpret(istate);
        }
        return e;
    }

    Expression *e = body ? body->interpret(istate) : NULL;
    if (e == EXP_CANT_INTERPRET)
        return e;
    if (!exceptionOrCantInterpret(e))
        return e;
    // An exception was thrown
    ThrownExceptionExp *ex = (ThrownExceptionExp *)e;
    Type *extype = ex->thrown->originalClass()->type;
    // Search for an appropriate catch clause.
    for (size_t i = 0; i < catches->dim; i++)
    {
        Catch *ca = (*catches)[i];
        Type *catype = ca->type;

        if (catype->equals(extype) || catype->isBaseOf(extype, NULL))
        {
            // Execute the handler
            if (ca->var)
            {
                ctfeStack.push(ca->var);
                ca->var->setValue(ex->thrown);
            }
            if (ca->handler)
            {
                e = ca->handler->interpret(istate);
                if (e == EXP_GOTO_INTERPRET)
                {
                    InterState istatex = *istate;
                    istatex.start = istate->gotoTarget; // set starting statement
                    istatex.gotoTarget = NULL;
                    Expression *eh = ca->handler->interpret(&istatex);
                    if (!istatex.start)
                    {
                        istate->gotoTarget = NULL;
                        e = eh;
                    }
                }
            }
            else
                e = NULL;
            return e;
        }
    }
    return e;
}

bool isAnErrorException(ClassDeclaration *cd)
{
    return cd == ClassDeclaration::errorException || ClassDeclaration::errorException->isBaseOf(cd, NULL);
}

ThrownExceptionExp *chainExceptions(ThrownExceptionExp *oldest, ThrownExceptionExp *newest)
{
#if LOG
    printf("Collided exceptions %s %s\n", oldest->thrown->toChars(), newest->thrown->toChars());
#endif
#if DMDV2
    // Little sanity check to make sure it's really a Throwable
    ClassReferenceExp *boss = oldest->thrown;
    assert((*boss->value->elements)[4]->type->ty == Tclass);
    ClassReferenceExp *collateral = newest->thrown;
    if (isAnErrorException(collateral->originalClass())
        && !isAnErrorException(boss->originalClass()))
    {   // The new exception bypass the existing chain
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
#else
    // for D1, the newest exception just clobbers the older one
    return newest;
#endif
}


Expression *TryFinallyStatement::interpret(InterState *istate)
{
#if LOG
    printf("%s TryFinallyStatement::interpret()\n", loc.toChars());
#endif
    if (istate->start == this)
        istate->start = NULL;
    if (istate->start)
    {
        Expression *e = NULL;
        if (body)
            e = body->interpret(istate);
        // Jump into/out from finalbody is disabled in semantic analysis.
        // and jump inside will be handled by the ScopeStatement == finalbody.
        return e;
    }

    Expression *e = body ? body->interpret(istate) : NULL;
    if (e == EXP_CANT_INTERPRET)
        return e;
    Expression *second = finalbody ? finalbody->interpret(istate) : NULL;
    if (second == EXP_CANT_INTERPRET)
        return second;
    if (exceptionOrCantInterpret(second))
    {   // Check for collided exceptions
        if (exceptionOrCantInterpret(e))
            e = chainExceptions((ThrownExceptionExp *)e, (ThrownExceptionExp *)second);
        else
            e = second;
    }
    return e;
}

Expression *ThrowStatement::interpret(InterState *istate)
{
#if LOG
    printf("%s ThrowStatement::interpret()\n", loc.toChars());
#endif
    if (istate->start)
    {   if (istate->start != this)
            return NULL;
        istate->start = NULL;
    }

    Expression *e = exp->interpret(istate);
    if (exceptionOrCantInterpret(e))
        return e;
    assert(e->op == TOKclassreference);
    return new ThrownExceptionExp(loc, (ClassReferenceExp *)e);
}

Expression *OnScopeStatement::interpret(InterState *istate)
{
    assert(0);
    return EXP_CANT_INTERPRET;
}

Expression *WithStatement::interpret(InterState *istate)
{
#if LOG
    printf("%s WithStatement::interpret()\n", loc.toChars());
#endif

    // If it is with(Enum) {...}, just execute the body.
    if (exp->op == TOKimport || exp->op == TOKtype)
        return body ? body->interpret(istate) : EXP_VOID_INTERPRET;

    if (istate->start)
    {   if (istate->start != this)
            return NULL;
        istate->start = NULL;
    }

    Expression *e = exp->interpret(istate);
    if (exceptionOrCantInterpret(e))
        return e;
    if (wthis->type->ty == Tpointer && exp->type->ty != Tpointer)
    {
        e = new AddrExp(loc, e);
        e->type = wthis->type;
    }
    ctfeStack.push(wthis);
    wthis->setValue(e);
    if (body)
    {
        e = body->interpret(istate);
        if (e == EXP_GOTO_INTERPRET)
        {
            InterState istatex = *istate;
            istatex.start = istate->gotoTarget; // set starting statement
            istatex.gotoTarget = NULL;
            Expression *ex = body->interpret(&istatex);
            if (!istatex.start)
            {
                istate->gotoTarget = NULL;
                e = ex;
            }
        }
    }
    else
        e = EXP_VOID_INTERPRET;
    ctfeStack.pop(wthis);
    return e;
}

Expression *AsmStatement::interpret(InterState *istate)
{
#if LOG
    printf("%s AsmStatement::interpret()\n", loc.toChars());
#endif
    if (istate->start)
    {   if (istate->start != this)
            return NULL;
        istate->start = NULL;
    }

    error("asm statements cannot be interpreted at compile time");
    return EXP_CANT_INTERPRET;
}

#if DMDV2
Expression *ImportStatement::interpret(InterState *istate)
{
#if LOG
    printf("ImportStatement::interpret()\n");
#endif
    if (istate->start)
    {   if (istate->start != this)
            return NULL;
        istate->start = NULL;
    }
;
    return NULL;
}
#endif

/******************************** Expression ***************************/

Expression *Expression::interpret(InterState *istate, CtfeGoal goal)
{
#if LOG
    printf("%s Expression::interpret() %s\n", loc.toChars(), toChars());
    printf("type = %s\n", type->toChars());
    dump(0);
#endif
    error("Cannot interpret %s at compile time", toChars());
    return EXP_CANT_INTERPRET;
}

Expression *ThisExp::interpret(InterState *istate, CtfeGoal goal)
{
    Expression *localThis = ctfeStack.getThis();
    if (localThis && localThis->op == TOKstructliteral)
        return localThis;
    if (localThis)
        return localThis->interpret(istate, goal);
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
    printf("%s IntegerExp::interpret() %s\n", loc.toChars(), toChars());
#endif
    return this;
}

Expression *RealExp::interpret(InterState *istate, CtfeGoal goal)
{
#if LOG
    printf("%s RealExp::interpret() %s\n", loc.toChars(), toChars());
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
    printf("%s StringExp::interpret() %s\n", loc.toChars(), toChars());
#endif
    /* In both D1 and D2, attempts to modify string literals are prevented
     * in BinExp::interpretAssignCommon.
     * In D2, we also disallow casts of read-only literals to mutable,
     * though it isn't strictly necessary.
     */
#if 0 //DMDV2
    // Fixed-length char arrays always get duped later anyway.
    if (type->ty == Tsarray)
        return this;
    if (!(((TypeNext *)type)->next->toBasetype()->mod & (MODconst | MODimmutable)))
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
    printf("%s FuncExp::interpret() %s\n", loc.toChars(), toChars());
#endif
    return this;
}

Expression *SymOffExp::interpret(InterState *istate, CtfeGoal goal)
{
#if LOG
    printf("%s SymOffExp::interpret() %s\n", loc.toChars(), toChars());
#endif
    if (var->isFuncDeclaration() && offset == 0)
    {
        return this;
    }
    if (isTypeInfo_Class(type) && offset == 0)
    {
        return this;
    }
    if (type->ty != Tpointer)
    {   // Probably impossible
        error("Cannot interpret %s at compile time", toChars());
        return EXP_CANT_INTERPRET;
    }
    Type *pointee = ((TypePointer *)type)->next;
    if ( var->isThreadlocal())
    {
        error("cannot take address of thread-local variable %s at compile time", var->toChars());
        return EXP_CANT_INTERPRET;
    }
    // Check for taking an address of a shared variable.
    // If the shared variable is an array, the offset might not be zero.
    Type *fromType = NULL;
    if (var->type->ty == Tarray || var->type->ty == Tsarray)
    {
        fromType = ((TypeArray *)(var->type))->next;
    }
    if ( var->isDataseg() && (
         (offset == 0 && isSafePointerCast(var->type, pointee)) ||
         (fromType && isSafePointerCast(fromType, pointee))
        ))
    {
        return this;
    }
    Expression *val = getVarExp(loc, istate, var, goal);
    if (val == EXP_CANT_INTERPRET)
        return val;
    if (val->type->ty == Tarray || val->type->ty == Tsarray)
    {
        // Check for unsupported type painting operations
        Type *elemtype = ((TypeArray *)(val->type))->next;

        // It's OK to cast from fixed length to dynamic array, eg &int[3] to int[]*
        if (val->type->ty == Tsarray && pointee->ty == Tarray
            && elemtype->size() == pointee->nextOf()->size())
        {
            Expression *e = new AddrExp(loc, val);
            e->type = type;
            return e;
        }
        if ( !isSafePointerCast(elemtype, pointee) )
        {   // It's also OK to cast from &string to string*.
            if ( offset == 0 && isSafePointerCast(var->type, pointee) )
            {
                VarExp *ve = new VarExp(loc, var);
                ve->type = type;
                return ve;
            }
            error("reinterpreting cast from %s to %s is not supported in CTFE",
                val->type->toChars(), type->toChars());
            return EXP_CANT_INTERPRET;
        }

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
    else if ( offset == 0 && isSafePointerCast(var->type, pointee) )
    {
        // Create a CTFE pointer &var
        VarExp *ve = new VarExp(loc, var);
        ve->type = var->type;
        AddrExp *re = new AddrExp(loc, ve);
        re->type = type;
        return re;
    }

    error("Cannot convert &%s to %s at compile time", var->type->toChars(), type->toChars());
    return EXP_CANT_INTERPRET;
}

Expression *AddrExp::interpret(InterState *istate, CtfeGoal goal)
{
#if LOG
    printf("%s AddrExp::interpret() %s\n", loc.toChars(), toChars());
#endif
    if (e1->op == TOKvar && ((VarExp *)e1)->var->isDataseg())
    {   // Normally this is already done by optimize()
        // Do it here in case optimize(0) wasn't run before CTFE
        SymOffExp *se = new SymOffExp(loc, ((VarExp *)e1)->var, 0);
        se->type = type;
        return se;
    }
    // For reference types, we need to return an lvalue ref.
    TY tb = e1->type->toBasetype()->ty;
    bool needRef = (tb == Tarray || tb == Taarray || tb == Tclass);
    Expression *e = e1->interpret(istate, needRef ? ctfeNeedLvalueRef : ctfeNeedLvalue);
    if (exceptionOrCantInterpret(e))
        return e;
    // Return a simplified address expression
    e = new AddrExp(loc, e);
    e->type = type;
    return e;
}

Expression *DelegateExp::interpret(InterState *istate, CtfeGoal goal)
{
#if LOG
    printf("%s DelegateExp::interpret() %s\n", loc.toChars(), toChars());
#endif
    // TODO: Really we should create a CTFE-only delegate expression
    // of a pointer and a funcptr.

    // If it is &nestedfunc, just return it
    // TODO: We should save the context pointer
    if (e1->op == TOKvar && ((VarExp *)e1)->var->isFuncDeclaration())
        return this;

    // If it has already been CTFE'd, just return it
    if (e1->op == TOKstructliteral || e1->op == TOKclassreference)
        return this;

    // Else change it into &structliteral.func or &classref.func
    Expression *e = e1->interpret(istate, ctfeNeedLvalue);

    if (exceptionOrCantInterpret(e))
        return e;

    e = new DelegateExp(loc, e, func);
    e->type = type;
    return e;
}


// -------------------------------------------------------------
//         Remove out, ref, and this
// -------------------------------------------------------------
// The variable used in a dotvar, index, or slice expression,
// after 'out', 'ref', and 'this' have been removed.
Expression * resolveReferences(Expression *e)
{
    for(;;)
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
            Expression *val = v->getValue();
            if (val && (val->op == TOKslice))
            {
                SliceExp *se = (SliceExp *)val;
                if (se->e1->op == TOKarrayliteral || se->e1->op == TOKassocarrayliteral || se->e1->op == TOKstring)
                    break;
                e = val;
                continue;
            }
            else if (val && (val->op==TOKindex || val->op == TOKdotvar
                  || val->op == TOKthis  || val->op == TOKvar))
            {
                e = val;
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

        if (!v->originalType && v->scope)   // semantic() not yet run
        {
            v->semantic (v->scope);
            if (v->type->ty == Terror)
                return EXP_CANT_INTERPRET;
        }

        if ((v->isConst() || v->isImmutable() || v->storage_class & STCmanifest)
            && v->init && !v->hasValue() && !v->isCTFE())
#else
        if (v->isConst() && v->init && !v->isCTFE())
#endif
        {
            if(v->scope)
                v->init = v->init->semantic(v->scope, v->type, INITinterpret); // might not be run on aggregate members
            e = v->init->toExpression(v->type);
            if (v->inuse)
            {
                error(loc, "circular initialization of %s", v->toChars());
                return EXP_CANT_INTERPRET;
            }

            if (e && (e->op == TOKconstruct || e->op == TOKblit))
            {   AssignExp *ae = (AssignExp *)e;
                e = ae->e2;
                v->inuse++;
                e = e->interpret(istate, ctfeNeedAnyValue);
                v->inuse--;
                if (e == EXP_CANT_INTERPRET && !global.gag && !CtfeStatus::stackTraceCallsToSuppress)
                    errorSupplemental(loc, "while evaluating %s.init", v->toChars());
                if (exceptionOrCantInterpret(e))
                    return e;
                e->type = v->type;
            }
            else
            {
                if (e && !e->type)
                    e->type = v->type;
                if (e)
                {
                    v->inuse++;
                    e = e->interpret(istate, ctfeNeedAnyValue);
                    v->inuse--;
                }
                if (e == EXP_CANT_INTERPRET && !global.gag && !CtfeStatus::stackTraceCallsToSuppress)
                    errorSupplemental(loc, "while evaluating %s.init", v->toChars());
            }
            if (e && e != EXP_CANT_INTERPRET && e->op != TOKthrownexception)
            {
                e = copyLiteral(e);
                if (v->isDataseg() || (v->storage_class & STCmanifest ))
                    ctfeStack.saveGlobalConstant(v, e);
            }
        }
        else if (v->isCTFE() && !v->hasValue())
        {
            if (v->init && v->type->size() != 0)
            {
                if (v->init->isVoidInitializer())
                {
                    // var should have been initialized when it was created
                    error(loc, "CTFE internal error - trying to access uninitialized var");
                    assert(0);
                    e = EXP_CANT_INTERPRET;
                }
                else
                {
                    e = v->init->toExpression();
                    e = e->interpret(istate);
                }
            }
            else
                e = v->type->defaultInitLiteral(loc);
        }
        else if (!(v->isDataseg() || v->storage_class & STCmanifest) && !v->isCTFE() && !istate)
        {   error(loc, "variable %s cannot be read at compile time", v->toChars());
            return EXP_CANT_INTERPRET;
        }
        else
        {   e = v->hasValue() ? v->getValue() : NULL;
            if (!e && !v->isCTFE() && v->isDataseg())
            {   error(loc, "static variable %s cannot be read at compile time", v->toChars());
                e = EXP_CANT_INTERPRET;
            }
            else if (!e)
            {   assert(!(v->init && v->init->isVoidInitializer()));
                // CTFE initiated from inside a function
                error(loc, "variable %s cannot be read at compile time", v->toChars());
                return EXP_CANT_INTERPRET;
            }
            else if (exceptionOrCantInterpret(e))
                return e;
            else if (goal == ctfeNeedLvalue && v->isRef() && e->op == TOKindex)
            {   // If it is a foreach ref, resolve the index into a constant
                IndexExp *ie = (IndexExp *)e;
                Expression *w = ie->e2->interpret(istate);
                if (w != ie->e2)
                {
                    e = new IndexExp(ie->loc, ie->e1, w);
                    e->type = ie->type;
                }
                return e;
            }
            else if ((goal == ctfeNeedLvalue)
                    || e->op == TOKstring || e->op == TOKstructliteral || e->op == TOKarrayliteral
                    || e->op == TOKassocarrayliteral || e->op == TOKslice
                    || e->type->toBasetype()->ty == Tpointer)
                return e; // it's already an Lvalue
            else if (e->op == TOKvoid)
            {
                VoidInitExp *ve = (VoidInitExp *)e;
                error(loc, "cannot read uninitialized variable %s in ctfe", v->toPrettyChars());
                errorSupplemental(ve->var->loc, "%s was uninitialized and used before set", ve->var->toChars());
                e = EXP_CANT_INTERPRET;
            }
            else
                e = e->interpret(istate, goal);
        }
        if (!e)
            e = EXP_CANT_INTERPRET;
    }
    else if (s)
    {   // Struct static initializers, for example
        e = s->dsym->type->defaultInitLiteral(loc);
        if (e->op == TOKerror)
            error(loc, "CTFE failed because of previous errors in %s.init", s->toChars());
        e = e->semantic(NULL);
        if (e->op == TOKerror)
            e = EXP_CANT_INTERPRET;
        else // Convert NULL to VoidExp
            e = e->interpret(istate, goal);
    }
    else
        error(loc, "cannot interpret declaration %s at compile time", d->toChars());
    return e;
}

Expression *VarExp::interpret(InterState *istate, CtfeGoal goal)
{
#if LOG
    printf("%s VarExp::interpret() %s\n", loc.toChars(), toChars());
#endif
    if (goal == ctfeNeedLvalueRef)
    {
        VarDeclaration *v = var->isVarDeclaration();
        if (v && !v->isDataseg() && !v->isCTFE() && !istate)
        {   error("variable %s cannot be referenced at compile time", v->toChars());
            return EXP_CANT_INTERPRET;
        }
        else if (v && !v->hasValue())
        {
            if (!v->isCTFE() && v->isDataseg())
                error("static variable %s cannot be referenced at compile time", v->toChars());
            else     // CTFE initiated from inside a function
                error("variable %s cannot be read at compile time", v->toChars());
            return EXP_CANT_INTERPRET;
        }
        else if (v && v->hasValue() && v->getValue()->op == TOKvar)
        {   // A ref of a reference,  is the original reference
            return v->getValue();
        }
        return this;
    }
    Expression *e = getVarExp(loc, istate, var, goal);
    // A VarExp may include an implicit cast. It must be done explicitly.
    if (e != EXP_CANT_INTERPRET && e->op != TOKthrownexception)
        e = paintTypeOntoLiteral(type, e);
    return e;
}

Expression *DeclarationExp::interpret(InterState *istate, CtfeGoal goal)
{
#if LOG
    printf("%s DeclarationExp::interpret() %s\n", loc.toChars(), toChars());
#endif
    Expression *e;
    VarDeclaration *v = declaration->isVarDeclaration();
    if (v)
    {
        if (v->toAlias()->isTupleDeclaration())
        {   // Reserve stack space for all tuple members
            TupleDeclaration *td =v->toAlias()->isTupleDeclaration();
            if (!td->objects)
                return NULL;
            for(size_t i= 0; i < td->objects->dim; ++i)
            {
                RootObject * o = (*td->objects)[i];
                Expression *ex = isExpression(o);
                DsymbolExp *s = (ex && ex->op == TOKdsymbol) ? (DsymbolExp *)ex : NULL;
                VarDeclaration *v2 = s ? s->s->isVarDeclaration() : NULL;
                assert(v2);
                if (!v2->isDataseg() || v2->isCTFE())
                    ctfeStack.push(v2);
            }
            return NULL;
        }
        if (!(v->isDataseg() || v->storage_class & STCmanifest) || v->isCTFE())
            ctfeStack.push(v);
        Dsymbol *s = v->toAlias();
        if (s == v && !v->isStatic() && v->init)
        {
            ExpInitializer *ie = v->init->isExpInitializer();
            if (ie)
                e = ie->exp->interpret(istate, goal);
            else if (v->init->isVoidInitializer())
            {
                e = v->type->voidInitLiteral(v);
                // There is no AssignExp for void initializers,
                // so set it here.
                v->setValue(e);
            }
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
        else if (v->isStatic())
            e = NULL;   // Just ignore static variables which aren't read or written yet
        else
        {
            error("Variable %s cannot be modified at compile time", v->toChars());
            e = EXP_CANT_INTERPRET;
        }
    }
    else if (declaration->isAttribDeclaration() ||
             declaration->isTemplateMixin() ||
             declaration->isTupleDeclaration())
    {   // Check for static struct declarations, which aren't executable
        AttribDeclaration *ad = declaration->isAttribDeclaration();
        if (ad && ad->decl && ad->decl->dim == 1)
        {
            Dsymbol *s = (*ad->decl)[0];
            if (s->isAggregateDeclaration() ||
                s->isTemplateDeclaration())
            {
                return NULL;    // static (template) struct declaration. Nothing to do.
            }
        }

        // These can be made to work, too lazy now
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
    printf("%s TupleExp::interpret() %s\n", loc.toChars(), toChars());
#endif
    Expressions *expsx = NULL;

    if (e0)
    {
        if (e0->interpret(istate) == EXP_CANT_INTERPRET)
            return EXP_CANT_INTERPRET;
    }

    for (size_t i = 0; i < exps->dim; i++)
    {   Expression *e = (*exps)[i];
        Expression *ex;

        ex = e->interpret(istate);
        if (exceptionOrCantInterpret(ex))
            return ex;

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
                ++CtfeStatus::numArrayAllocs;
                expsx->setDim(exps->dim);
                for (size_t j = 0; j < i; j++)
                {
                    (*expsx)[j] = (*exps)[j];
                }
            }
            (*expsx)[i] = ex;
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
    printf("%s ArrayLiteralExp::interpret() %s\n", loc.toChars(), toChars());
#endif
    if (ownedByCtfe) // We've already interpreted all the elements
        return this;
    if (elements)
    {
        for (size_t i = 0; i < elements->dim; i++)
        {   Expression *e = (*elements)[i];
            Expression *ex;

            if (e->op == TOKindex)  // segfault bug 6250
                assert( ((IndexExp*)e)->e1 != this);
            ex = e->interpret(istate);
            if (exceptionOrCantInterpret(ex))
                return ex;

            /* If any changes, do Copy On Write
             */
            if (ex != e)
            {
                if (!expsx)
                {   expsx = new Expressions();
                    ++CtfeStatus::numArrayAllocs;
                    expsx->setDim(elements->dim);
                    for (size_t j = 0; j < elements->dim; j++)
                    {
                        (*expsx)[j] = (*elements)[j];
                    }
                }
                (*expsx)[i] = ex;
            }
        }
    }
    if (elements && expsx)
    {
        expandTuples(expsx);
        if (expsx->dim != elements->dim)
        {
            error("Internal Compiler Error: Invalid array literal");
            return EXP_CANT_INTERPRET;
        }
        ArrayLiteralExp *ae = new ArrayLiteralExp(loc, expsx);
        ae->type = type;
        return copyLiteral(ae);
    }
#if DMDV2
    if (((TypeNext *)type)->next->mod & (MODconst | MODimmutable))
    {   // If it's immutable, we don't need to dup it
        return this;
    }
#endif
    return copyLiteral(this);
}

Expression *AssocArrayLiteralExp::interpret(InterState *istate, CtfeGoal goal)
{   Expressions *keysx = keys;
    Expressions *valuesx = values;

#if LOG
    printf("%s AssocArrayLiteralExp::interpret() %s\n", loc.toChars(), toChars());
#endif
    if (ownedByCtfe) // We've already interpreted all the elements
        return copyLiteral(this);
    for (size_t i = 0; i < keys->dim; i++)
    {
        Expression *ekey = (*keys)[i];
        Expression *evalue = (*values)[i];
        Expression *ex;

        ex = ekey->interpret(istate);
        if (exceptionOrCantInterpret(ex))
            return ex;

        /* If any changes, do Copy On Write
         */
        if (ex != ekey)
        {
            if (keysx == keys)
                keysx = (Expressions *)keys->copy();
            (*keysx)[i] = ex;
        }

        ex = evalue->interpret(istate);
        if (exceptionOrCantInterpret(ex))
            return ex;

        /* If any changes, do Copy On Write
         */
        if (ex != evalue)
        {
            if (valuesx == values)
                valuesx = (Expressions *)values->copy();
            (*valuesx)[i] = ex;
        }
    }
    if (keysx != keys)
        expandTuples(keysx);
    if (valuesx != values)
        expandTuples(valuesx);
    if (keysx->dim != valuesx->dim)
    {
        error("Internal Compiler Error: invalid AA");
        return EXP_CANT_INTERPRET;
    }

    /* Remove duplicate keys
     */
    for (size_t i = 1; i < keysx->dim; i++)
    {
        Expression *ekey = (*keysx)[i - 1];
        for (size_t j = i; j < keysx->dim; j++)
        {
            Expression *ekey2 = (*keysx)[j];
            int eq = ctfeEqual(loc, TOKequal, ekey, ekey2);
            if (eq)       // if a match
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
        ae->ownedByCtfe = true;
        return ae;
    }
    return this;
}

Expression *StructLiteralExp::interpret(InterState *istate, CtfeGoal goal)
{   Expressions *expsx = NULL;

#if LOG
    printf("%s StructLiteralExp::interpret() %s\n", loc.toChars(), toChars());
#endif
    if (ownedByCtfe)
        return copyLiteral(this);

    size_t elemdim = elements ? elements->dim : 0;

    for (size_t i = 0; i < sd->fields.dim; i++)
    {   Expression *e = NULL;
        Expression *ex = NULL;
        if (i >= elemdim)
        {
            /* If a nested struct has no initialized hidden pointer,
             * set it to null to match the runtime behaviour.
             */
            if (i == sd->fields.dim - 1 && sd->isNested())
            {   // Context field has not been filled
                ex = new NullExp(loc);
                ex->type = sd->fields[i]->type;
            }
        }
        else
        {
            e = (*elements)[i];
            if (!e)
            {
                /* Ideally, we'd convert NULL members into void expressions.
                * The problem is that the VoidExp will be removed when we
                * leave CTFE, causing another memory allocation if we use this
                * same struct literal again.
                *
                * ex = sd->fields[i]->type->voidInitLiteral(sd->fields[i]);
                */
                ex = NULL;
            }
            else
            {
                ex = e->interpret(istate);
                if (exceptionOrCantInterpret(ex))
                    return ex;
            }
        }

        /* If any changes, do Copy On Write
         */
        if (ex != e)
        {
            if (!expsx)
            {   expsx = new Expressions();
                ++CtfeStatus::numArrayAllocs;
                expsx->setDim(sd->fields.dim);
                for (size_t j = 0; j < elements->dim; j++)
                {
                    (*expsx)[j] = (*elements)[j];
                }
            }
            (*expsx)[i] = ex;
        }
    }

    if (elements && expsx)
    {
        expandTuples(expsx);
        if (expsx->dim != sd->fields.dim)
        {
            error("Internal Compiler Error: invalid struct literal");
            return EXP_CANT_INTERPRET;
        }
        StructLiteralExp *se = new StructLiteralExp(loc, sd, expsx);
        se->type = type;
        se->ownedByCtfe = true;
        return se;
    }
    return copyLiteral(this);
}

// Create an array literal of type 'newtype' with dimensions given by
// 'arguments'[argnum..$]
Expression *recursivelyCreateArrayLiteral(Loc loc, Type *newtype, InterState *istate,
    Expressions *arguments, int argnum)
{
    Expression *lenExpr = (((*arguments)[argnum]))->interpret(istate);
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
             (*elements)[i] = copyLiteral(elem);
        ArrayLiteralExp *ae = new ArrayLiteralExp(loc, elements);
        ae->type = newtype;
        ae->ownedByCtfe = true;
        return ae;
    }
    assert(argnum == arguments->dim - 1);
    if (elemType->ty == Tchar || elemType->ty == Twchar
        || elemType->ty == Tdchar)
        return createBlockDuplicatedStringLiteral(loc, newtype,
            (unsigned)(elemType->defaultInitLiteral(loc)->toInteger()),
            len, (unsigned char)elemType->size());
    return createBlockDuplicatedArrayLiteral(loc, newtype,
        elemType->defaultInitLiteral(loc),
        len);
}

Expression *NewExp::interpret(InterState *istate, CtfeGoal goal)
{
#if LOG
    printf("%s NewExp::interpret() %s\n", loc.toChars(), toChars());
#endif
    if (newtype->ty == Tarray && arguments)
        return recursivelyCreateArrayLiteral(loc, newtype, istate, arguments, 0);

    if (newtype->toBasetype()->ty == Tstruct)
    {
        Expression *se = newtype->defaultInitLiteral(loc);
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
        Expression *e = new AddrExp(loc, copyLiteral(se));
        e->type = type;
        return e;
    }
    if (newtype->toBasetype()->ty == Tclass)
    {
        ClassDeclaration *cd = ((TypeClass *)newtype->toBasetype())->sym;
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
                Dsymbol *s = c->fields[i];
                VarDeclaration *v = s->isVarDeclaration();
                assert(v);
                Expression *m;
                if (v->init)
                {
                    if (v->init->isVoidInitializer())
                        m = v->type->voidInitLiteral(v);
                    else
                        m = v->getConstInitializer(true);
                }
                else
                    m = v->type->defaultInitLiteral(loc);
                if (exceptionOrCantInterpret(m))
                    return m;
                (*elems)[fieldsSoFar+i] = copyLiteral(m);
            }
        }
        // Hack: we store a ClassDeclaration instead of a StructDeclaration.
        // We probably won't get away with this.
        StructLiteralExp *se = new StructLiteralExp(loc, (StructDeclaration *)cd, elems,  newtype);
        se->ownedByCtfe = true;
        Expression *e = new ClassReferenceExp(loc, se, type);
        if (member)
        {   // Call constructor
            if (!member->fbody)
            {
                Expression *ctorfail = evaluateIfBuiltin(istate, loc, member, arguments, e);
                if (ctorfail && exceptionOrCantInterpret(ctorfail))
                    return ctorfail;
                if (ctorfail)
                    return e;
                member->error("%s cannot be constructed at compile time, because the constructor has no available source code", newtype->toChars());
                return EXP_CANT_INTERPRET;
            }
            Expression * ctorfail = member->interpret(istate, arguments, e);
            if (exceptionOrCantInterpret(ctorfail))
                return ctorfail;
        }
        return e;
    }
    error("Cannot interpret %s at compile time", toChars());
    return EXP_CANT_INTERPRET;
}

Expression *UnaExp::interpret(InterState *istate,  CtfeGoal goal)
{   Expression *e;
    Expression *e1;

#if LOG
    printf("%s UnaExp::interpret() %s\n", loc.toChars(), toChars());
#endif
    if (op == TOKdottype)
    {
        error("Internal Compiler Error: CTFE DotType: %s", toChars());
        return EXP_CANT_INTERPRET;
    }
    e1 = this->e1->interpret(istate);
    if (exceptionOrCantInterpret(e1))
        return e1;
    switch(op)
    {
    case TOKneg:    e = Neg(type, e1); break;
    case TOKtilde:  e = Com(type, e1); break;
    case TOKnot:    e = Not(type, e1); break;
    case TOKtobool: e = Bool(type, e1); break;
    case TOKvector: e = this; break; // do nothing
    default: assert(0);
    }
    return e;
}


Expression *BinExp::interpretCommon(InterState *istate, CtfeGoal goal, fp_t fp)
{   Expression *e;
    Expression *e1;
    Expression *e2;

#if LOG
    printf("%s BinExp::interpretCommon() %s\n", loc.toChars(), toChars());
#endif
    if (this->e1->type->ty == Tpointer && this->e2->type->ty == Tpointer && op == TOKmin)
    {
        e1 = this->e1->interpret(istate, ctfeNeedLvalue);
        if (exceptionOrCantInterpret(e1))
            return e1;
        e2 = this->e2->interpret(istate, ctfeNeedLvalue);
        if (exceptionOrCantInterpret(e2))
            return e2;
        return pointerDifference(loc, type, e1, e2);
    }
    if (this->e1->type->ty == Tpointer && this->e2->type->isintegral())
    {
        e1 = this->e1->interpret(istate, ctfeNeedLvalue);
        if (exceptionOrCantInterpret(e1))
            return e1;
        e2 = this->e2->interpret(istate);
        if (exceptionOrCantInterpret(e2))
            return e2;
        return pointerArithmetic(loc, op, type, e1, e2);
    }
    if (this->e2->type->ty == Tpointer && this->e1->type->isintegral() && op==TOKadd)
    {
        e1 = this->e1->interpret(istate);
        if (exceptionOrCantInterpret(e1))
            return e1;
        e2 = this->e2->interpret(istate, ctfeNeedLvalue);
        if (exceptionOrCantInterpret(e2))
            return e1;
        return pointerArithmetic(loc, op, type, e2, e1);
    }
    if (this->e1->type->ty == Tpointer || this->e2->type->ty == Tpointer)
    {
        error("pointer expression %s cannot be interpreted at compile time", toChars());
        return EXP_CANT_INTERPRET;
    }
    e1 = this->e1->interpret(istate);
    if (exceptionOrCantInterpret(e1))
        return e1;
    if (e1->isConst() != 1)
    {
        error("Internal Compiler Error: non-constant value %s", this->e1->toChars());
        return EXP_CANT_INTERPRET;
    }

    e2 = this->e2->interpret(istate);
    if (exceptionOrCantInterpret(e2))
        return e2;
    if (e2->isConst() != 1)
    {
        error("Internal Compiler Error: non-constant value %s", this->e2->toChars());
        return EXP_CANT_INTERPRET;
    }

    if (op == TOKshr || op == TOKshl || op == TOKushr)
    {
        sinteger_t i2 = e2->toInteger();
        d_uns64 sz = e1->type->size() * 8;
        if (i2 < 0 || i2 >= sz)
        {   error("shift by %lld is outside the range 0..%llu", i2, (ulonglong)sz - 1);
            return EXP_CANT_INTERPRET;
        }
    }
    e = (*fp)(type, e1, e2);
    if (e == EXP_CANT_INTERPRET)
        error("%s cannot be interpreted at compile time", toChars());
    return e;
}

Expression *BinExp::interpretCompareCommon(InterState *istate, CtfeGoal goal, fp2_t fp)
{
    Expression *e1;
    Expression *e2;

#if LOG
    printf("%s BinExp::interpretCompareCommon() %s\n", loc.toChars(), toChars());
#endif
    if (this->e1->type->ty == Tpointer && this->e2->type->ty == Tpointer)
    {
        e1 = this->e1->interpret(istate);
        if (exceptionOrCantInterpret(e1))
            return e1;
        e2 = this->e2->interpret(istate);
        if (exceptionOrCantInterpret(e2))
            return e2;
        dinteger_t ofs1, ofs2;
        Expression *agg1 = getAggregateFromPointer(e1, &ofs1);
        Expression *agg2 = getAggregateFromPointer(e2, &ofs2);
        int cmp = comparePointers(loc, op, type, agg1, ofs1, agg2, ofs2);
        if (cmp == -1)
        {
           char dir = (op == TOKgt || op == TOKge) ? '<' : '>';
           error("The ordering of pointers to unrelated memory blocks is indeterminate in CTFE."
                 " To check if they point to the same memory block, use both > and < inside && or ||, "
                 "eg (%s && %s %c= %s + 1)",
                 toChars(), this->e1->toChars(), dir, this->e2->toChars());
          return EXP_CANT_INTERPRET;
        }
        return new IntegerExp(loc, cmp, type);
    }
    e1 = this->e1->interpret(istate);
    if (exceptionOrCantInterpret(e1))
        return e1;
    if (!isCtfeComparable(e1))
    {
        error("cannot compare %s at compile time", e1->toChars());
        return EXP_CANT_INTERPRET;
    }
    e2 = this->e2->interpret(istate);
    if (exceptionOrCantInterpret(e2))
        return e2;
    if (!isCtfeComparable(e2))
    {
        error("cannot compare %s at compile time", e2->toChars());
        return EXP_CANT_INTERPRET;
    }
    int cmp = (*fp)(loc, op, e1, e2);
    return new IntegerExp(loc, cmp, type);
}

Expression *BinExp::interpret(InterState *istate, CtfeGoal goal)
{
    switch(op)
    {
    case TOKadd:  return interpretCommon(istate, goal, &Add);
    case TOKmin:  return interpretCommon(istate, goal, &Min);
    case TOKmul:  return interpretCommon(istate, goal, &Mul);
    case TOKdiv:  return interpretCommon(istate, goal, &Div);
    case TOKmod:  return interpretCommon(istate, goal, &Mod);
    case TOKshl:  return interpretCommon(istate, goal, &Shl);
    case TOKshr:  return interpretCommon(istate, goal, &Shr);
    case TOKushr: return interpretCommon(istate, goal, &Ushr);
    case TOKand:  return interpretCommon(istate, goal, &And);
    case TOKor:   return interpretCommon(istate, goal, &Or);
    case TOKxor:  return interpretCommon(istate, goal, &Xor);
#if DMDV2
    case TOKpow:  return interpretCommon(istate, goal, &Pow);
#endif
    case TOKequal:
    case TOKnotequal:
        return interpretCompareCommon(istate, goal, &ctfeEqual);
    case TOKidentity:
    case TOKnotidentity:
        return interpretCompareCommon(istate, goal, &ctfeIdentity);
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
        return interpretCompareCommon(istate, goal, &ctfeCmp);
    default:
        assert(0);
        return NULL;
    }
}

/* Helper functions for BinExp::interpretAssignCommon
 */

// Returns the variable which is eventually modified, or NULL if an rvalue.
// thisval is the current value of 'this'.
VarDeclaration * findParentVar(Expression *e)
{
    for (;;)
    {
        e = resolveReferences(e);
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

Expression *interpretAssignToSlice(InterState *istate, CtfeGoal goal, Loc loc,
    SliceExp *sexp, Expression *newval, bool wantRef, bool isBlockAssignment,
    BinExp *originalExpression);

bool interpretAssignToIndex(InterState *istate, Loc loc,
    IndexExp *ie, Expression *newval, bool wantRef,
    BinExp *originalExp);

Expression *BinExp::interpretAssignCommon(InterState *istate, CtfeGoal goal, fp_t fp, int post)
{
#if LOG
    printf("%s BinExp::interpretAssignCommon() %s\n", loc.toChars(), toChars());
#endif
    Expression *returnValue = EXP_CANT_INTERPRET;
    Expression *e1 = this->e1;
    if (!istate)
    {
        error("value of %s is not known at compile time", e1->toChars());
        return returnValue;
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
#if DMDV2
        Type *srctype = e2->type->toBasetype()->castMod(0);
#else
        Type *srctype = e2->type->toBasetype();
#endif
        while ( desttype->ty == Tsarray || desttype->ty == Tarray)
        {
            desttype = ((TypeArray *)desttype)->next;
#if DMDV2
            if (srctype->equals(desttype->castMod(0)))
#else
            if (srctype->equals(desttype))
#endif
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

    if (!fp && this->e1->type->toBasetype()->equals(this->e2->type->toBasetype()) &&
        (e1->type->toBasetype()->ty == Tarray || isAssocArray(e1->type)
             || e1->type->toBasetype()->ty == Tclass)
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
        VarDeclaration * targetVar = findParentVar(e2);
        if (!(targetVar && targetVar->isConst()))
            wantRef = true;
        // slice assignment of static arrays is not reference assignment
        if ((e1->op==TOKslice) && ((SliceExp *)e1)->e1->type->ty == Tsarray)
            wantRef = false;
#endif
        // If it is assignment from a ref parameter, it's not a ref assignment
        if (this->e2->op == TOKvar)
        {
            VarDeclaration *v = ((VarExp *)this->e2)->var->isVarDeclaration();
            if (v && (v->storage_class & (STCref | STCout)))
                wantRef = false;
        }
    }
    if (isBlockAssignment && (e2->type->toBasetype()->ty == Tarray || e2->type->toBasetype()->ty == Tsarray))
    {
        wantRef = true;
    }
    // If it is a construction of a ref variable, it is a ref assignment
    // (in fact, it is an lvalue reference assignment).
    if (op == TOKconstruct && this->e1->op==TOKvar
        && ((VarExp*)this->e1)->var->storage_class & STCref)
    {
        wantRef = true;
        wantLvalueRef = true;
    }

    if (fp)
    {
        while (e1->op == TOKcast)
        {   CastExp *ce = (CastExp *)e1;
            e1 = ce->e1;
        }
    }
    if (exceptionOrCantInterpret(e1))
        return e1;

    // First, deal with  this = e; and call() = e;
    if (e1->op == TOKthis)
    {
        e1 = ctfeStack.getThis();
    }
    if (e1->op == TOKcall)
    {
        bool oldWaiting = istate->awaitingLvalueReturn;
        istate->awaitingLvalueReturn = true;
        e1 = e1->interpret(istate);
        istate->awaitingLvalueReturn = oldWaiting;
        if (exceptionOrCantInterpret(e1))
            return e1;
        if (e1->op == TOKarrayliteral || e1->op == TOKstring)
        {
            // f() = e2, when f returns an array, is always a slice assignment.
            // Convert into arr[0..arr.length] = e2
            e1 = new SliceExp(loc, e1,
                new IntegerExp(Loc(), 0, Type::tsize_t),
                ArrayLength(Type::tsize_t, e1));
            e1->type = type;
        }
    }
    if (e1->op == TOKstar)
    {
        e1 = e1->interpret(istate, ctfeNeedLvalue);
        if (exceptionOrCantInterpret(e1))
            return e1;
        if (!(e1->op == TOKvar || e1->op == TOKdotvar || e1->op == TOKindex
            || e1->op == TOKslice || e1->op == TOKstructliteral))
        {
            error("cannot dereference invalid pointer %s",
                this->e1->toChars());
            return EXP_CANT_INTERPRET;
        }
    }

    if (!(e1->op == TOKarraylength || e1->op == TOKvar || e1->op == TOKdotvar
        || e1->op == TOKindex || e1->op == TOKslice || e1->op == TOKstructliteral))
    {
        error("CTFE internal error: unsupported assignment %s", toChars());
        return EXP_CANT_INTERPRET;
    }

    Expression * newval = NULL;

    if (!wantRef)
    {    // We need to treat pointers specially, because TOKsymoff can be used to
        // return a value OR a pointer
        assert(e1);
        assert(e1->type);
        if ( isPointer(e1->type) && (e2->op == TOKsymoff || e2->op==TOKaddress || e2->op==TOKvar))
            newval = this->e2->interpret(istate, ctfeNeedLvalue);
        else
            newval = this->e2->interpret(istate);
        if (exceptionOrCantInterpret(newval))
            return newval;
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
        Expression * oldval = e1->interpret(istate);
        if (exceptionOrCantInterpret(oldval))
            return oldval;
        while (oldval->op == TOKvar)
        {
            oldval = resolveReferences(oldval);
            oldval = oldval->interpret(istate);
            if (exceptionOrCantInterpret(oldval))
                return oldval;
        }

        if (fp)
        {
            // ~= can create new values (see bug 6052)
            if (op == TOKcatass)
            {
                // We need to dup it. We can skip this if it's a dynamic array,
                // because it gets copied later anyway
                if (newval->type->ty != Tarray)
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
                if (exceptionOrCantInterpret(oldval))
                    return oldval;
                newval = this->e2->interpret(istate);
                if (exceptionOrCantInterpret(newval))
                    return newval;
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
            if (exceptionOrCantInterpret(newval))
                return newval;
            // Determine the return value
            returnValue = ctfeCast(loc, type, type, post ? oldval : newval);
            if (exceptionOrCantInterpret(returnValue))
                return returnValue;
        }
        else
            returnValue = newval;
        if (e1->op == TOKarraylength)
        {
            size_t oldlen = (size_t)oldval->toInteger();
            size_t newlen = (size_t)newval->toInteger();
            if (oldlen == newlen) // no change required -- we're done!
                return returnValue;
            // Now change the assignment from arr.length = n into arr = newval
            e1 = ((ArrayLengthExp *)e1)->e1;
            if (oldlen != 0)
            {   // Get the old array literal.
                oldval = e1->interpret(istate);
                while (oldval->op == TOKvar)
                {   oldval = resolveReferences(oldval);
                    oldval = oldval->interpret(istate);
                }
            }
            Type *t = e1->type->toBasetype();
            if (t->ty == Tarray)
            {
                newval = changeArrayLiteralLength(loc, (TypeArray *)t, oldval,
                    oldlen,  newlen);
                // We have changed it into a reference assignment
                // Note that returnValue is still the new length.
                wantRef = true;
                if (e1->op == TOKstar)
                {   // arr.length+=n becomes (t=&arr, *(t).length=*(t).length+n);
                    e1 = e1->interpret(istate, ctfeNeedLvalue);
                    if (exceptionOrCantInterpret(e1))
                        return e1;
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
            if (newval->op != TOKstructliteral)
            {
                error("nested structs with constructors are not yet supported in CTFE (Bug 6419)");
                return EXP_CANT_INTERPRET;
            }
        }
        newval = ctfeCast(loc, type, type, newval);
        if (exceptionOrCantInterpret(newval))
            return newval;
        returnValue = newval;
    }
    if (exceptionOrCantInterpret(newval))
        return newval;

    // -------------------------------------------------
    //         Make sure destination can be modified
    // -------------------------------------------------
    // Make sure we're not trying to modify a global or static variable
    // We do this by locating the ultimate parent variable which gets modified.
    VarDeclaration * ultimateVar = findParentVar(e1);
    if (ultimateVar && ultimateVar->isDataseg() && !ultimateVar->isCTFE())
    {   // Can't modify global or static data
        error("%s cannot be modified at compile time", ultimateVar->toChars());
        return EXP_CANT_INTERPRET;
    }

    e1 = resolveReferences(e1);

    // Unless we have a simple var assignment, we're
    // only modifying part of the variable. So we need to make sure
    // that the parent variable exists.
    if (e1->op != TOKvar && ultimateVar && !ultimateVar->getValue())
        ultimateVar->setValue(copyLiteral(ultimateVar->type->defaultInitLiteral(loc)));

    // ---------------------------------------
    //      Deal with reference assignment
    // (We already have 'newval' for arraylength operations)
    // ---------------------------------------
    if (wantRef && !fp && this->e1->op != TOKarraylength)
    {
        newval = this->e2->interpret(istate,
            wantLvalueRef ? ctfeNeedLvalueRef : ctfeNeedLvalue);
        if (exceptionOrCantInterpret(newval))
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
            newval->op == TOKarrayliteral)
        {
            if (needToCopyLiteral(newval))
                newval = copyLiteral(newval);
        }

        // Get the value to return. Note that 'newval' is an Lvalue,
        // so if we need an Rvalue, we have to interpret again.
        if (goal == ctfeNeedRvalue)
            returnValue = newval->interpret(istate);
        else
            returnValue = newval;
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
        aggregate = aggregate->interpret(istate, ctfeNeedLvalue);
        if (exceptionOrCantInterpret(aggregate))
            return aggregate;
        if (aggregate->op == TOKassocarrayliteral)
        {   // Normal case, ultimate parent AA already exists
            // We need to walk from the deepest index up, checking that an AA literal
            // already exists on each level.
            Expression *index = ((IndexExp *)e1)->e2->interpret(istate);
            if (exceptionOrCantInterpret(index))
                return index;
            if (index->op == TOKslice)  // only happens with AA assignment
                index = resolveSlice(index);
            AssocArrayLiteralExp *existingAA = (AssocArrayLiteralExp *)aggregate;
            while (depth > 0)
            {   // Walk the syntax tree to find the indexExp at this depth
                IndexExp *xe = (IndexExp *)e1;
                for (int d= 0; d < depth; ++d)
                    xe = (IndexExp *)xe->e1;

                Expression *indx = xe->e2->interpret(istate);
                if (exceptionOrCantInterpret(indx))
                    return indx;
                if (indx->op == TOKslice)  // only happens with AA assignment
                    indx = resolveSlice(indx);

                // Look up this index in it up in the existing AA, to get the next level of AA.
                AssocArrayLiteralExp *newAA = (AssocArrayLiteralExp *)findKeyInAA(loc, existingAA, indx);
                if (exceptionOrCantInterpret(newAA))
                    return newAA;
                if (!newAA)
                {   // Doesn't exist yet, create an empty AA...
                    Expressions *valuesx = new Expressions();
                    Expressions *keysx = new Expressions();
                    newAA = new AssocArrayLiteralExp(loc, keysx, valuesx);
                    newAA->type = xe->type;
                    newAA->ownedByCtfe = true;
                    //... and insert it into the existing AA.
                    existingAA->keys->push(indx);
                    existingAA->values->push(newAA);
                }
                existingAA = newAA;
                --depth;
            }
            if (assignAssocArrayElement(loc, existingAA, index, newval) == EXP_CANT_INTERPRET)
                return EXP_CANT_INTERPRET;
            return returnValue;
        }
        else
        {   /* The AA is currently null. 'aggregate' is actually a reference to
             * whatever contains it. It could be anything: var, dotvarexp, ...
             * We rewrite the assignment from: aggregate[i][j] = newval;
             *                           into: aggregate = [i:[j: newval]];
             */
            while (e1->op == TOKindex && ((IndexExp *)e1)->e1->type->toBasetype()->ty == Taarray)
            {
                Expression *index = ((IndexExp *)e1)->e2->interpret(istate);
                if (exceptionOrCantInterpret(index))
                    return index;
                if (index->op == TOKslice)  // only happens with AA assignment
                    index = resolveSlice(index);
                Expressions *valuesx = new Expressions();
                Expressions *keysx = new Expressions();
                valuesx->push(newval);
                keysx->push(index);
                AssocArrayLiteralExp *newaae = new AssocArrayLiteralExp(loc, keysx, valuesx);
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
        bool isCtfePointer = (dve->e1->op == TOKstructliteral)
                && ((StructLiteralExp *)(dve->e1))->ownedByCtfe;
        if (!isCtfePointer)
        {
            e1 = e1->interpret(istate, isPointer(type) ? ctfeNeedLvalueRef : ctfeNeedLvalue);
            if (exceptionOrCantInterpret(e1))
                return e1;
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
        if (wantRef)
        {
            v->setValueNull();
            v->setValue(newval);
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
                v->setValue(newval);
        }
        else
        {
            TY tyE1 = e1->type->toBasetype()->ty;
            if (tyE1 == Tarray || tyE1 == Taarray)
            { // arr op= arr
                v->setValue(newval);
            }
            else
            {
                v->setValue(newval);
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
        return returnValue;
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
            if (exceptionOrCantInterpret(exx))
                return exx;
        }
        if (exx->op != TOKstructliteral && exx->op != TOKclassreference)
        {
            error("CTFE internal error: Dotvar assignment");
            return EXP_CANT_INTERPRET;
        }
        VarDeclaration *member = ((DotVarExp *)e1)->var->isVarDeclaration();
        if (!member)
        {
            error("CTFE internal error: Dotvar assignment");
            return EXP_CANT_INTERPRET;
        }
        StructLiteralExp *se = exx->op == TOKstructliteral
            ? (StructLiteralExp *)exx
            : ((ClassReferenceExp *)exx)->value;
        int fieldi =  exx->op == TOKstructliteral
            ? findFieldIndexByName(se->sd, member)
            : ((ClassReferenceExp *)exx)->findFieldIndexByName(member);
        if (fieldi == -1)
        {
            error("CTFE internal error: cannot find field %s in %s", member->toChars(), exx->toChars());
            return EXP_CANT_INTERPRET;
        }
        assert(fieldi >= 0 && fieldi < se->elements->dim);
        // If it's a union, set all other members of this union to void
        if (exx->op == TOKstructliteral)
        {
            assert(se->sd);
            int unionStart = se->sd->firstFieldInUnion(fieldi);
            int unionSize = se->sd->numFieldsInUnion(fieldi);
            for(int i = unionStart; i < unionStart + unionSize; ++i)
            {   if (i == fieldi)
                    continue;
                Expression **el = &(*se->elements)[i];
                if ((*el)->op != TOKvoid)
                    *el = (*el)->type->voidInitLiteral(member);
            }
        }

        if (newval->op == TOKstructliteral)
            assignInPlace((*se->elements)[fieldi], newval);
        else
            (*se->elements)[fieldi] = newval;
        return returnValue;
    }
    else if (e1->op == TOKindex)
    {
        if ( !interpretAssignToIndex(istate, loc, (IndexExp *)e1, newval,
            wantRef, this))
            return EXP_CANT_INTERPRET;
        return returnValue;
    }
    else if (e1->op == TOKslice)
    {
        // Note that slice assignments don't support things like ++, so
        // we don't need to remember 'returnValue'.
        return interpretAssignToSlice(istate, goal, loc, (SliceExp *)e1,
            newval, wantRef, isBlockAssignment, this);
    }
    else
    {
        error("%s cannot be evaluated at compile time", toChars());
    }
    return returnValue;
}

/*************
 *  Deal with assignments of the form
 *  aggregate[ie] = newval
 *  where aggregate and newval have already been interpreted
 *
 *  Return true if OK, false if error occured
 */
bool interpretAssignToIndex(InterState *istate, Loc loc,
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
        Expression *oldval = ie->e1->interpret(istate);
        if (oldval->op == TOKnull)
        {
            originalExp->error("cannot index null array %s", ie->e1->toChars());
            return false;
        }
        if (oldval->op != TOKarrayliteral && oldval->op != TOKstring
            && oldval->op != TOKslice)
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
            ie->lengthVar->setValue(dollarExp);
        }
    }
    Expression *index = ie->e2->interpret(istate);
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
        aggregate = aggregate->interpret(istate, ctfeNeedLvalue);
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
        aggregate->op == TOKstar)
    {
        aggregate = aggregate->interpret(istate, ctfeNeedLvalue);
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
        aggregate = v->getValue();
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
        Expression *lwr = sexp->lwr->interpret(istate);
        indexToModify += lwr->toInteger();
    }
    if (aggregate->op == TOKarrayliteral)
        existingAE = (ArrayLiteralExp *)aggregate;
    else if (aggregate->op == TOKstring)
        existingSE = (StringExp *)aggregate;
    else
    {
        originalExp->error("CTFE internal compiler error %s", aggregate->toChars());
        return false;
    }
    if (!wantRef && newval->op == TOKslice)
    {
        newval = resolveSlice(newval);
        if (newval == EXP_CANT_INTERPRET)
        {
            originalExp->error("Compiler error: CTFE index assign %s", originalExp->toChars());
            assert(0);
        }
    }
    if (wantRef && newval->op == TOKindex
        && ((IndexExp *)newval)->e1 == aggregate)
    {   // It's a circular reference, resolve it now
            newval = newval->interpret(istate);
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
        originalExp->error("Index assignment %s is not yet supported in CTFE ", originalExp->toChars());
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
 * Returns EXP_CANT_INTERPRET on failure. If there are no errors,
 * it returns aggregate[low..upp], except that as an optimisation,
 * if goal == ctfeNeedNothing, it will return NULL
 */

Expression *interpretAssignToSlice(InterState *istate, CtfeGoal goal, Loc loc,
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
    {   // Slicing a pointer
        oldval = oldval->interpret(istate, ctfeNeedLvalue);
        if (exceptionOrCantInterpret(oldval))
            return oldval;
        dinteger_t ofs;
        oldval = getAggregateFromPointer(oldval, &ofs);
        assignmentToSlicedPointer = true;
    }
    else
        oldval = oldval->interpret(istate);

    if (oldval->op != TOKarrayliteral && oldval->op != TOKstring
        && oldval->op != TOKslice && oldval->op != TOKnull)
    {
        if (oldval->op == TOKsymoff)
        {
            originalExp->error("pointer %s cannot be sliced at compile time (it points to a static variable)", sexp->e1->toChars());
            return EXP_CANT_INTERPRET;
        }
        if (assignmentToSlicedPointer)
        {
            originalExp->error("pointer %s cannot be sliced at compile time (it does not point to an array)",
                sexp->e1->toChars());
        }
        else
            originalExp->error("CTFE ICE: cannot resolve array length");
        return EXP_CANT_INTERPRET;
    }
    uinteger_t dollar = resolveArrayLength(oldval);
    if (sexp->lengthVar)
    {
        Expression *arraylen = new IntegerExp(loc, dollar, Type::tsize_t);
        ctfeStack.push(sexp->lengthVar);
        sexp->lengthVar->setValue(arraylen);
    }

    Expression *upper = NULL;
    Expression *lower = NULL;
    if (sexp->upr)
        upper = sexp->upr->interpret(istate);
    if (exceptionOrCantInterpret(upper))
    {
        if (sexp->lengthVar)
            ctfeStack.pop(sexp->lengthVar); // $ is defined only in [L..U]
        return upper;
    }
    if (sexp->lwr)
        lower = sexp->lwr->interpret(istate);
    if (sexp->lengthVar)
        ctfeStack.pop(sexp->lengthVar); // $ is defined only in [L..U]
    if (exceptionOrCantInterpret(lower))
        return lower;

    unsigned dim = (unsigned)dollar;
    size_t upperbound = (size_t)(upper ? upper->toInteger() : dim);
    int lowerbound = (int)(lower ? lower->toInteger() : 0);

    if (!assignmentToSlicedPointer && (((int)lowerbound < 0) || (upperbound > dim)))
    {
        originalExp->error("Array bounds [0..%d] exceeded in slice [%d..%d]",
            dim, lowerbound, upperbound);
        return EXP_CANT_INTERPRET;
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
        aggregate->op == TOKslice ||
        aggregate->op == TOKstar  || aggregate->op == TOKcall)
    {
        aggregate = aggregate->interpret(istate, ctfeNeedLvalue);
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
                return EXP_CANT_INTERPRET;
            }
            if (exceptionOrCantInterpret(aggregate))
                return aggregate;
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
        sinteger_t hi = upperbound + sexpold->lwr->toInteger();
        firstIndex = lowerbound + sexpold->lwr->toInteger();
        if (hi > sexpold->upr->toInteger())
        {
            originalExp->error("slice [%d..%d] exceeds array bounds [0..%lld]",
                lowerbound, upperbound,
                sexpold->upr->toInteger() - sexpold->lwr->toInteger());
            return EXP_CANT_INTERPRET;
        }
        aggregate = sexpold->e1;
    }
    if ( isPointer(aggregate->type) )
    {   // Slicing a pointer --> change the bounds
        aggregate = sexp->e1->interpret(istate, ctfeNeedLvalue);
        dinteger_t ofs;
        aggregate = getAggregateFromPointer(aggregate, &ofs);
        if (aggregate->op == TOKnull)
        {
            originalExp->error("cannot slice null pointer %s", sexp->e1->toChars());
            return EXP_CANT_INTERPRET;
        }
        sinteger_t hi = upperbound + ofs;
        firstIndex = lowerbound + ofs;
        if (firstIndex < 0 || hi > dim)
        {
           originalExp->error("slice [lld..%lld] exceeds memory block bounds [0..%lld]",
                firstIndex, hi,  dim);
            return EXP_CANT_INTERPRET;
        }
    }
    if (aggregate->op == TOKarrayliteral)
        existingAE = (ArrayLiteralExp *)aggregate;
    else if (aggregate->op == TOKstring)
        existingSE = (StringExp *)aggregate;
    if (existingSE && !existingSE->ownedByCtfe)
    {   originalExp->error("cannot modify read-only string literal %s", sexp->e1->toChars());
        return EXP_CANT_INTERPRET;
    }

    if (!wantRef && newval->op == TOKslice)
    {
        Expression *orignewval = newval;
        newval = resolveSlice(newval);
        if (newval == EXP_CANT_INTERPRET)
        {
            originalExp->error("Compiler error: CTFE slice %s", orignewval->toChars());
            assert(0);
        }
    }
    if (wantRef && newval->op == TOKindex
        && ((IndexExp *)newval)->e1 == aggregate)
    {   // It's a circular reference, resolve it now
            newval = newval->interpret(istate);
    }

    // For slice assignment, we check that the lengths match.
    size_t srclen = 0;
    if (newval->op == TOKarrayliteral)
        srclen = ((ArrayLiteralExp *)newval)->elements->dim;
    else if (newval->op == TOKstring)
        srclen = ((StringExp *)newval)->len;
    if (!isBlockAssignment && srclen != (upperbound - lowerbound))
    {
        originalExp->error("Array length mismatch assigning [0..%d] to [%d..%d]", srclen, lowerbound, upperbound);
        return EXP_CANT_INTERPRET;
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
        return newval;
    }
    else if (newval->op == TOKstring && existingSE)
    {
        sliceAssignStringFromString((StringExp *)existingSE, (StringExp *)newval, (size_t)firstIndex);
        return newval;
    }
    else if (newval->op == TOKstring && existingAE
            && existingAE->type->isString())
    {   /* Mixed slice: it was initialized as an array literal of chars.
         * Now a slice of it is being set with a string.
         */
        sliceAssignArrayLiteralFromString(existingAE, (StringExp *)newval, (size_t)firstIndex);
        return newval;
    }
    else if (newval->op == TOKarrayliteral && existingSE)
    {   /* Mixed slice: it was initialized as a string literal.
         * Now a slice of it is being set with an array literal.
         */
        sliceAssignStringFromArrayLiteral(existingSE, (ArrayLiteralExp *)newval, (size_t)firstIndex);
        return newval;
    }
    else if (existingSE)
    {   // String literal block slice assign
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
        bool directblk = (e2->type->toBasetype()->castMod(0))->equals(desttype);
#else
        Type *desttype = ((TypeArray *)existingAE->type)->next;
        bool directblk = (e2->type->toBasetype())->equals(desttype);
#endif
        bool cow = !(newval->op == TOKstructliteral || newval->op == TOKarrayliteral
            || newval->op == TOKstring);
        for (size_t j = 0; j < upperbound-lowerbound; j++)
        {
            if (!directblk)
                // Multidimensional array block assign
                recursiveBlockAssign((ArrayLiteralExp *)(*w)[(size_t)(j+firstIndex)], newval, wantRef);
            else
            {
                if (wantRef || cow)
                    (*existingAE->elements)[(size_t)(j+firstIndex)] = newval;
                else
                    assignInPlace((*existingAE->elements)[(size_t)(j+firstIndex)], newval);
            }
        }
        if (goal == ctfeNeedNothing)
            return NULL; // avoid creating an unused literal
        SliceExp *retslice = new SliceExp(loc, existingAE,
            new IntegerExp(loc, firstIndex, Type::tsize_t),
            new IntegerExp(loc, firstIndex + upperbound-lowerbound, Type::tsize_t));
        retslice->type = originalExp->type;
        return retslice->interpret(istate);
    }
    else
    {
        originalExp->error("Slice operation %s = %s cannot be evaluated at compile time", sexp->toChars(), newval->toChars());
        return EXP_CANT_INTERPRET;
    }
}

Expression *AssignExp::interpret(InterState *istate, CtfeGoal goal)
{
    return interpretAssignCommon(istate, goal, NULL);
}

Expression *BinAssignExp::interpret(InterState *istate, CtfeGoal goal)
{
    switch(op)
    {
    case TOKaddass:  return interpretAssignCommon(istate, goal, &Add);
    case TOKminass:  return interpretAssignCommon(istate, goal, &Min);
    case TOKcatass:  return interpretAssignCommon(istate, goal, &ctfeCat);
    case TOKmulass:  return interpretAssignCommon(istate, goal, &Mul);
    case TOKdivass:  return interpretAssignCommon(istate, goal, &Div);
    case TOKmodass:  return interpretAssignCommon(istate, goal, &Mod);
    case TOKshlass:  return interpretAssignCommon(istate, goal, &Shl);
    case TOKshrass:  return interpretAssignCommon(istate, goal, &Shr);
    case TOKushrass: return interpretAssignCommon(istate, goal, &Ushr);
    case TOKandass:  return interpretAssignCommon(istate, goal, &And);
    case TOKorass:   return interpretAssignCommon(istate, goal, &Or);
    case TOKxorass:  return interpretAssignCommon(istate, goal, &Xor);
#if DMDV2
    case TOKpowass:  return interpretAssignCommon(istate, goal, &Pow);
#endif
    default:
        assert(0);
        return NULL;
    }
}

Expression *PostExp::interpret(InterState *istate, CtfeGoal goal)
{
#if LOG
    printf("%s PostExp::interpret() %s\n", loc.toChars(), toChars());
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

/* Return 1 if e is a p1 > p2 or p1 >= p2 pointer comparison;
 *       -1 if e is a p1 < p2 or p1 <= p2 pointer comparison;
 *        0 otherwise
 */
int isPointerCmpExp(Expression *e, Expression **p1, Expression **p2)
{
    int ret = 1;
    while (e->op == TOKnot)
    {   ret *= -1;
        e = ((NotExp *)e)->e1;
    }
    switch(e->op)
    {
    case TOKlt:
    case TOKle:
        ret *= -1;
        /* fall through */
    case TOKgt:
    case TOKge:
        *p1 = ((BinExp *)e)->e1;
        *p2 = ((BinExp *)e)->e2;
        if ( !(isPointer((*p1)->type) && isPointer((*p2)->type)) )
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
TOK reverseRelation(TOK op)
{
    switch(op)
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
 *  ( !(q1 < p1) && p2 <= q2 ) is valid.
 */
Expression *BinExp::interpretFourPointerRelation(InterState *istate, CtfeGoal goal)
{
    assert(op == TOKandand || op == TOKoror);

    /*  It can only be an isInside expression, if both e1 and e2 are
     *  directional pointer comparisons.
     *  Note that this check can be made statically; it does not depends on
     *  any runtime values. This allows a JIT implementation to compile a
     *  special AndAndPossiblyInside, keeping the normal AndAnd case efficient.
     */

    // Save the pointer expressions and the comparison directions,
    // so we can use them later.
    Expression *p1, *p2, *p3, *p4;
    int dir1 = isPointerCmpExp(e1, &p1, &p2);
    int dir2 = isPointerCmpExp(e2, &p3, &p4);
    if ( dir1 == 0 || dir2 == 0 )
        return NULL;

    //printf("FourPointerRelation %s\n", toChars());

    // Evaluate the first two pointers
    p1 = p1->interpret(istate);
    if (exceptionOrCantInterpret(p1))
        return p1;
    p2 = p2->interpret(istate);
    if (exceptionOrCantInterpret(p1))
        return p1;
    dinteger_t ofs1, ofs2;
    Expression *agg1 = getAggregateFromPointer(p1, &ofs1);
    Expression *agg2 = getAggregateFromPointer(p2, &ofs2);

    if ( !pointToSameMemoryBlock(agg1, agg2)
         && agg1->op != TOKnull && agg2->op != TOKnull)
    {   // Here it is either CANT_INTERPRET,
        // or an IsInside comparison returning false.
        p3 = p3->interpret(istate);
        if (p3 == EXP_CANT_INTERPRET)
            return p3;
        // Note that it is NOT legal for it to throw an exception!
        Expression *except = NULL;
        if (exceptionOrCantInterpret(p3))
            except = p3;
        else
        {
            p4 = p4->interpret(istate);
            if (p4 == EXP_CANT_INTERPRET)
                return p4;
            if (exceptionOrCantInterpret(p4))
                except = p4;
        }
        if (except)
        {   error("Comparison %s of pointers to unrelated memory blocks remains "
                 "indeterminate at compile time "
                 "because exception %s was thrown while evaluating %s",
                 this->e1->toChars(), except->toChars(), this->e2->toChars());
            return EXP_CANT_INTERPRET;
        }
        dinteger_t ofs3,ofs4;
        Expression *agg3 = getAggregateFromPointer(p3, &ofs3);
        Expression *agg4 = getAggregateFromPointer(p4, &ofs4);
        // The valid cases are:
        // p1 > p2 && p3 > p4  (same direction, also for < && <)
        // p1 > p2 && p3 < p4  (different direction, also < && >)
        // Changing any > into >= doesnt affect the result
        if ( (dir1 == dir2 && pointToSameMemoryBlock(agg1, agg4)
            && pointToSameMemoryBlock(agg2, agg3))
          || (dir1 != dir2 && pointToSameMemoryBlock(agg1, agg3)
            && pointToSameMemoryBlock(agg2, agg4)) )
        {   // it's a legal two-sided comparison
            return new IntegerExp(loc, (op == TOKandand) ?  0 : 1, type);
        }
        // It's an invalid four-pointer comparison. Either the second
        // comparison is in the same direction as the first, or else
        // more than two memory blocks are involved (either two independent
        // invalid comparisons are present, or else agg3 == agg4).
        error("Comparison %s of pointers to unrelated memory blocks is "
            "indeterminate at compile time, even when combined with %s.",
            e1->toChars(), e2->toChars());
        return EXP_CANT_INTERPRET;
    }
    // The first pointer expression didn't need special treatment, so we
    // we need to interpret the entire expression exactly as a normal && or ||.
    // This is easy because we haven't evaluated e2 at all yet, and we already
    // know it will return a bool.
    // But we mustn't evaluate the pointer expressions in e1 again, in case
    // they have side-effects.
    bool nott = false;
    Expression *e = e1;
    while (e->op == TOKnot)
    {   nott= !nott;
        e = ((NotExp *)e)->e1;
    }
    TOK cmpop = e->op;
    if (nott)
        cmpop = reverseRelation(cmpop);
    int cmp = comparePointers(loc, cmpop, e1->type, agg1, ofs1, agg2, ofs2);
    // We already know this is a valid comparison.
    assert(cmp >= 0);
    if ( (op == TOKandand && cmp == 1) || (op == TOKoror && cmp == 0) )
        return e2->interpret(istate);
    return new IntegerExp(loc, (op == TOKandand) ? 0 : 1, type);
}

Expression *AndAndExp::interpret(InterState *istate, CtfeGoal goal)
{
#if LOG
    printf("%s AndAndExp::interpret() %s\n", loc.toChars(), toChars());
#endif

    // Check for an insidePointer expression, evaluate it if so
    Expression *e = interpretFourPointerRelation(istate, goal);
    if (e)
        return e;

    e = e1->interpret(istate);
    if (exceptionOrCantInterpret(e))
        return e;

    int result;
    if (e != EXP_CANT_INTERPRET)
    {
        if (e->isBool(false))
            result = 0;
        else if (isTrueBool(e))
        {
            e = e2->interpret(istate);
            if (exceptionOrCantInterpret(e))
                return e;
            if (e == EXP_VOID_INTERPRET)
            {
                assert(type->ty == Tvoid);
                return NULL;
            }
            if (e->isBool(false))
                result = 0;
            else if (isTrueBool(e))
                result = 1;
            else
            {
                e->error("%s does not evaluate to a boolean", e->toChars());
                e = EXP_CANT_INTERPRET;
            }
        }
        else
        {
            e->error("%s cannot be interpreted as a boolean", e->toChars());
            e = EXP_CANT_INTERPRET;
        }
    }
    if (e != EXP_CANT_INTERPRET && goal != ctfeNeedNothing)
        e = new IntegerExp(loc, result, type);
    return e;
}

Expression *OrOrExp::interpret(InterState *istate, CtfeGoal goal)
{
#if LOG
    printf("%s OrOrExp::interpret() %s\n", loc.toChars(), toChars());
#endif

    // Check for an insidePointer expression, evaluate it if so
    Expression *e = interpretFourPointerRelation(istate, goal);
    if (e)
        return e;

    e = e1->interpret(istate);
    if (exceptionOrCantInterpret(e))
        return e;

    int result;
    if (e != EXP_CANT_INTERPRET)
    {
        if (isTrueBool(e))
            result = 1;
        else if (e->isBool(false))
        {
            e = e2->interpret(istate);
            if (exceptionOrCantInterpret(e))
                return e;

            if (e == EXP_VOID_INTERPRET)
            {
                assert(type->ty == Tvoid);
                return NULL;
            }
            if (e != EXP_CANT_INTERPRET)
            {
                if (e->isBool(false))
                    result = 0;
                else if (isTrueBool(e))
                    result = 1;
                else
                {
                    e->error("%s cannot be interpreted as a boolean", e->toChars());
                    e = EXP_CANT_INTERPRET;
                }
            }
        }
        else
        {
            e->error("%s cannot be interpreted as a boolean", e->toChars());
            e = EXP_CANT_INTERPRET;
        }
    }
    if (e != EXP_CANT_INTERPRET && goal != ctfeNeedNothing)
        e = new IntegerExp(loc, result, type);
    return e;
}

// Print a stack trace, starting from callingExp which called fd.
// To shorten the stack trace, try to detect recursion.
void showCtfeBackTrace(InterState *istate, CallExp * callingExp, FuncDeclaration *fd)
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
        {   ++recurseCount;
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

Expression *CallExp::interpret(InterState *istate, CtfeGoal goal)
{   Expression *e = EXP_CANT_INTERPRET;

#if LOG
    printf("%s CallExp::interpret() %s\n", loc.toChars(), toChars());
#endif

    Expression * pthis = NULL;
    FuncDeclaration *fd = NULL;
    Expression *ecall = e1;
    if (ecall->op == TOKcall)
    {
        ecall = e1->interpret(istate);
        if (exceptionOrCantInterpret(ecall))
            return ecall;
    }
    if (ecall->op == TOKstar)
    {   // Calling a function pointer
        Expression * pe = ((PtrExp*)ecall)->e1;
        if (pe->op == TOKvar) {
            VarDeclaration *vd = ((VarExp *)((PtrExp*)ecall)->e1)->var->isVarDeclaration();
            if (vd && vd->hasValue() && vd->getValue()->op == TOKsymoff)
                fd = ((SymOffExp *)vd->getValue())->var->isFuncDeclaration();
            else
            {
                ecall = getVarExp(loc, istate, vd, goal);
                if (exceptionOrCantInterpret(ecall))
                    return ecall;

                if (ecall->op == TOKsymoff)
                    fd = ((SymOffExp *)ecall)->var->isFuncDeclaration();
            }
        }
        else if (pe->op == TOKsymoff)
            fd = ((SymOffExp *)pe)->var->isFuncDeclaration();
        else
            ecall = ((PtrExp*)ecall)->e1->interpret(istate);

    }
    if (exceptionOrCantInterpret(ecall))
        return ecall;

    if (ecall->op == TOKindex)
    {   ecall = e1->interpret(istate);
        if (exceptionOrCantInterpret(ecall))
            return ecall;
    }

    if (ecall->op == TOKdotvar && !((DotVarExp*)ecall)->var->isFuncDeclaration())
    {   ecall = e1->interpret(istate);
        if (exceptionOrCantInterpret(ecall))
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
        if (vd && vd->hasValue())
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
    {   // This should never happen, it's an internal compiler error.
        //printf("ecall=%s %d %d\n", ecall->toChars(), ecall->op, TOKcall);
        if (ecall->op == TOKidentifier)
            error("cannot evaluate %s at compile time. Circular reference?", toChars());
        else
            error("CTFE internal error: cannot evaluate %s at compile time", toChars());
        return EXP_CANT_INTERPRET;
    }
    if (!fd)
    {
        error("cannot evaluate %s at compile time", toChars());
        return EXP_CANT_INTERPRET;
    }
    if (pthis)
    {   // Member function call
        if (pthis->op == TOKcomma)
            pthis = pthis->interpret(istate);
        if (exceptionOrCantInterpret(pthis))
            return pthis;
        // Evaluate 'this'
        Expression *oldpthis = pthis;
        if (pthis->op != TOKvar)
            pthis = pthis->interpret(istate, ctfeNeedLvalue);
        if (exceptionOrCantInterpret(pthis))
            return pthis;
        if (fd->isVirtual())
        {   // Make a virtual function call.
            Expression *thisval = pthis;
            if (pthis->op == TOKvar)
            {
                VarDeclaration *vthis = ((VarExp*)thisval)->var->isVarDeclaration();
                assert(vthis);
                thisval = getVarExp(loc, istate, vthis, ctfeNeedLvalue);
                if (exceptionOrCantInterpret(thisval))
                    return thisval;
                // If it is a reference, resolve it
                if (thisval->op != TOKnull && thisval->op != TOKclassreference)
                    thisval = pthis->interpret(istate);
            }
            else if (pthis->op == TOKsymoff)
            {
                VarDeclaration *vthis = ((SymOffExp*)thisval)->var->isVarDeclaration();
                assert(vthis);
                thisval = getVarExp(loc, istate, vthis, ctfeNeedLvalue);
                if (exceptionOrCantInterpret(thisval))
                    return thisval;
            }

            // Get the function from the vtable of the original class
            ClassDeclaration *cd;
            if (thisval && thisval->op == TOKnull)
            {
                error("function call through null class reference %s", pthis->toChars());
                return EXP_CANT_INTERPRET;
            }
            if (oldpthis->op == TOKsuper)
            {   assert(oldpthis->type->ty == Tclass);
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
        error("CTFE failed because of previous errors in %s", fd->toChars());
        return EXP_CANT_INTERPRET;
    }
    // Check for built-in functions
    Expression *eresult = evaluateIfBuiltin(istate, loc, fd, arguments, pthis);
    if (eresult)
        return eresult;

    // Inline .dup. Special case because it needs the return type.
    if (!pthis && fd->ident == Id::adDup && arguments && arguments->dim == 2)
    {
        e = (*arguments)[1];
        e = e->interpret(istate);
        if (exceptionOrCantInterpret(e))
            return e;
        if (e != EXP_CANT_INTERPRET)
        {
            if (e->op == TOKslice)
                e= resolveSlice(e);
            e = paintTypeOntoLiteral(type, copyLiteral(e));
        }
        return e;
    }
    if (fd->dArrayOp)
        return fd->dArrayOp->interpret(istate, arguments, pthis);
    if (!fd->fbody)
    {
        error("%s cannot be interpreted at compile time,"
            " because it has no available source code", fd->toChars());
        return EXP_CANT_INTERPRET;
    }
    eresult = fd->interpret(istate, arguments, pthis);
    if (eresult == EXP_CANT_INTERPRET)
    {
        // Print a stack trace.
        if (!global.gag)
            showCtfeBackTrace(istate, this, fd);
    }
    else if (eresult == EXP_VOID_INTERPRET)
        ;
    else
    {
        eresult->type = type;
        eresult->loc = loc;
    }
    return eresult;
}

Expression *CommaExp::interpret(InterState *istate, CtfeGoal goal)
{
#if LOG
    printf("%s CommaExp::interpret() %s\n", loc.toChars(), toChars());
#endif

    CommaExp * firstComma = this;
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

    Expression *e = EXP_CANT_INTERPRET;

    // If the comma returns a temporary variable, it needs to be an lvalue
    // (this is particularly important for struct constructors)
    if (e1->op == TOKdeclaration && e2->op == TOKvar
       && ((DeclarationExp *)e1)->declaration == ((VarExp*)e2)->var
       && ((VarExp*)e2)->var->storage_class & STCctfe)  // same as Expression::isTemp
    {
        VarExp* ve = (VarExp *)e2;
        VarDeclaration *v = ve->var->isVarDeclaration();
        ctfeStack.push(v);
        if (!v->init && !v->getValue())
        {
            v->setValue(copyLiteral(v->type->defaultInitLiteral(loc)));
        }
        if (!v->getValue()) {
            Expression *newval = v->init->toExpression();
            // Bug 4027. Copy constructors are a weird case where the
            // initializer is a void function (the variable is modified
            // through a reference parameter instead).
            newval = newval->interpret(istate);
            if (exceptionOrCantInterpret(newval))
            {
                if (istate == &istateComma)
                    ctfeStack.endFrame();
                return newval;
            }
            if (newval != EXP_VOID_INTERPRET)
            {
                // v isn't necessarily null.
                v->setValueWithoutChecking(copyLiteral(newval));
            }
        }
        if (goal == ctfeNeedLvalue || goal == ctfeNeedLvalueRef)
            e = e2;
        else
            e = e2->interpret(istate, goal);
    }
    else
    {
        e = e1->interpret(istate, ctfeNeedNothing);
        if (!exceptionOrCantInterpret(e))
            e = e2->interpret(istate, goal);
    }
    // If we created a temporary stack frame, end it now.
    if (istate == &istateComma)
        ctfeStack.endFrame();
    return e;
}

Expression *CondExp::interpret(InterState *istate, CtfeGoal goal)
{
#if LOG
    printf("%s CondExp::interpret() %s\n", loc.toChars(), toChars());
#endif
    Expression *e;
    if ( isPointer(econd->type) )
    {
        e = econd->interpret(istate);
        if (exceptionOrCantInterpret(e))
            return e;
        if (e->op != TOKnull)
            e = new IntegerExp(loc, 1, Type::tbool);
    }
    else
        e = econd->interpret(istate);
    if (exceptionOrCantInterpret(e))
        return e;
    if (isTrueBool(e))
        e = e1->interpret(istate, goal);
    else if (e->isBool(false))
        e = e2->interpret(istate, goal);
    else
    {
        error("%s does not evaluate to boolean result at compile time",
            econd->toChars());
        e = EXP_CANT_INTERPRET;
    }
    return e;
}

Expression *ArrayLengthExp::interpret(InterState *istate, CtfeGoal goal)
{   Expression *e;
    Expression *e1;

#if LOG
    printf("%s ArrayLengthExp::interpret() %s\n", loc.toChars(), toChars());
#endif
    e1 = this->e1->interpret(istate);
    assert(e1);
    if (exceptionOrCantInterpret(e1))
        return e1;
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


Expression *IndexExp::interpret(InterState *istate, CtfeGoal goal)
{
    Expression *e1 = NULL;
    Expression *e2;

#if LOG
    printf("%s IndexExp::interpret() %s\n", loc.toChars(), toChars());
#endif
    if (this->e1->type->toBasetype()->ty == Tpointer)
    {
        // Indexing a pointer. Note that there is no $ in this case.
        e1 = this->e1->interpret(istate);
        if (exceptionOrCantInterpret(e1))
            return e1;
        e2 = this->e2->interpret(istate);
        if (exceptionOrCantInterpret(e2))
            return e2;
        sinteger_t indx = e2->toInteger();

        dinteger_t ofs;
        Expression *agg = getAggregateFromPointer(e1, &ofs);

        if (agg->op == TOKnull)
        {
            error("cannot index null pointer %s", this->e1->toChars());
            return EXP_CANT_INTERPRET;
        }
        if ( agg->op == TOKarrayliteral || agg->op == TOKstring)
        {
            dinteger_t len = ArrayLength(Type::tsize_t, agg)->toInteger();
            //Type *pointee = ((TypePointer *)agg->type)->next;
            if ((sinteger_t)(indx + ofs) < 0 || (indx+ofs) > len)
            {
                error("pointer index [%lld] exceeds allocated memory block [0..%lld]",
                    indx+ofs, len);
                return EXP_CANT_INTERPRET;
            }
            if (goal == ctfeNeedLvalueRef)
            {
                // if we need a reference, IndexExp shouldn't be interpreting
                // the expression to a value, it should stay as a reference
                Expression *e = new IndexExp(loc, agg,
                    ofs ? new IntegerExp(loc,indx + ofs, e2->type) : e2);
                e->type = type;
                return e;
            }
            return ctfeIndex(loc, type, agg, indx+ofs);
        }
        else
        {   // Pointer to a non-array variable
            if (agg->op == TOKsymoff)
            {
                    error("mutable variable %s cannot be read at compile time, even through a pointer", ((SymOffExp *)agg)->var->toChars());
                    return EXP_CANT_INTERPRET;
            }
            if ((indx + ofs) != 0)
            {
                error("pointer index [%lld] lies outside memory block [0..1]",
                    indx+ofs);
                return EXP_CANT_INTERPRET;
            }
            if (goal == ctfeNeedLvalueRef)
            {
                return paintTypeOntoLiteral(type, agg);
            }
            return agg->interpret(istate);
        }
    }
    e1 = this->e1;
    if (!(e1->op == TOKarrayliteral && ((ArrayLiteralExp *)e1)->ownedByCtfe) &&
        !(e1->op == TOKassocarrayliteral && ((AssocArrayLiteralExp *)e1)->ownedByCtfe))
        e1 = e1->interpret(istate);
    if (exceptionOrCantInterpret(e1))
        return e1;

    if (e1->op == TOKnull)
    {
        if (goal == ctfeNeedLvalue && e1->type->ty == Taarray && modifiable)
            return paintTypeOntoLiteral(type, e1);
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
        ctfeStack.push(lengthVar);
        lengthVar->setValue(dollarExp);
    }

    e2 = this->e2->interpret(istate);
    if (lengthVar)
        ctfeStack.pop(lengthVar); // $ is defined only inside []
    if (exceptionOrCantInterpret(e2))
        return e2;
    if (e1->op == TOKslice && e2->op == TOKint64)
    {
        // Simplify index of slice:  agg[lwr..upr][indx] --> agg[indx']
        uinteger_t indx = e2->toInteger();
        uinteger_t ilo = ((SliceExp *)e1)->lwr->toInteger();
        uinteger_t iup = ((SliceExp *)e1)->upr->toInteger();

        if (indx > iup - ilo)
        {
            error("index %llu exceeds array length %llu", indx, iup - ilo);
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
        e = findKeyInAA(loc, (AssocArrayLiteralExp *)e1, e2);
        if (!e)
        {
            error("key %s not found in associative array %s",
                e2->toChars(), this->e1->toChars());
            return EXP_CANT_INTERPRET;
        }
    }
    else
    {
        if (e2->op != TOKint64)
        {
            e1->error("CTFE internal error: non-integral index [%s]", this->e2->toChars());
            return EXP_CANT_INTERPRET;
        }
        e = ctfeIndex(loc, type, e1, e2->toInteger());
    }
    if (exceptionOrCantInterpret(e))
        return e;
    if (goal == ctfeNeedRvalue && (e->op == TOKslice || e->op == TOKdotvar))
        e = e->interpret(istate);
    if (goal == ctfeNeedRvalue && e->op == TOKvoid)
    {
        error("%s is used before initialized", toChars());
        errorSupplemental(e->loc, "originally uninitialized here");
        return EXP_CANT_INTERPRET;
    }
    e = paintTypeOntoLiteral(type, e);
    return e;
}


Expression *SliceExp::interpret(InterState *istate, CtfeGoal goal)
{
    Expression *e1;
    Expression *lwr;
    Expression *upr;

#if LOG
    printf("%s SliceExp::interpret() %s\n", loc.toChars(), toChars());
#endif

    if (this->e1->type->toBasetype()->ty == Tpointer)
    {
        // Slicing a pointer. Note that there is no $ in this case.
        e1 = this->e1->interpret(istate);
        if (exceptionOrCantInterpret(e1))
            return e1;
        if (e1->op == TOKint64)
        {
            error("cannot slice invalid pointer %s of value %s",
                this->e1->toChars(), e1->toChars());
            return EXP_CANT_INTERPRET;
        }

        /* Evaluate lower and upper bounds of slice
         */
        lwr = this->lwr->interpret(istate);
        if (exceptionOrCantInterpret(lwr))
            return lwr;
        upr = this->upr->interpret(istate);
        if (exceptionOrCantInterpret(upr))
            return upr;
        uinteger_t ilwr;
        uinteger_t iupr;
        ilwr = lwr->toInteger();
        iupr = upr->toInteger();
        Expression *e;
        dinteger_t ofs;
        Expression *agg = getAggregateFromPointer(e1, &ofs);
        ilwr += ofs;
        iupr += ofs;
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
        if (agg->op == TOKsymoff)
        {
            error("slicing pointers to static variables is not supported in CTFE");
            return EXP_CANT_INTERPRET;
        }
        if (agg->op != TOKarrayliteral && agg->op != TOKstring)
        {
            error("pointer %s cannot be sliced at compile time (it does not point to an array)",
                this->e1->toChars());
            return EXP_CANT_INTERPRET;
        }
        assert(agg->op == TOKarrayliteral || agg->op == TOKstring);
        dinteger_t len = ArrayLength(Type::tsize_t, agg)->toInteger();
        //Type *pointee = ((TypePointer *)agg->type)->next;
        if (iupr > (len + 1) || iupr < ilwr)
        {
            error("pointer slice [%lld..%lld] exceeds allocated memory block [0..%lld]",
                ilwr, iupr, len);
            return EXP_CANT_INTERPRET;
        }
        if (ofs != 0)
        {   lwr = new IntegerExp(loc, ilwr, lwr->type);
            upr = new IntegerExp(loc, iupr, upr->type);
        }
        e = new SliceExp(loc, agg, lwr, upr);
        e->type = type;
        return e;
    }
    if (goal == ctfeNeedRvalue && this->e1->op == TOKstring)
        e1 = this->e1; // Will get duplicated anyway
    else
        e1 = this->e1->interpret(istate);
    if (exceptionOrCantInterpret(e1))
        return e1;
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
        error("Cannot determine length of %s at compile time", e1->toChars());
        return EXP_CANT_INTERPRET;
    }
    uinteger_t dollar = resolveArrayLength(e1);
    if (lengthVar)
    {
        IntegerExp *dollarExp = new IntegerExp(loc, dollar, Type::tsize_t);
        ctfeStack.push(lengthVar);
        lengthVar->setValue(dollarExp);
    }

    /* Evaluate lower and upper bounds of slice
     */
    lwr = this->lwr->interpret(istate);
    if (exceptionOrCantInterpret(lwr))
    {
        if (lengthVar)
            ctfeStack.pop(lengthVar);; // $ is defined only inside [L..U]
        return lwr;
    }
    upr = this->upr->interpret(istate);
    if (lengthVar)
        ctfeStack.pop(lengthVar); // $ is defined only inside [L..U]
    if (exceptionOrCantInterpret(upr))
        return upr;

    Expression *e;
    uinteger_t ilwr;
    uinteger_t iupr;
    ilwr = lwr->toInteger();
    iupr = upr->toInteger();
    if (e1->op == TOKnull)
    {
        if (ilwr== 0 && iupr == 0)
            return e1;
        e1->error("slice [%llu..%llu] is out of bounds", ilwr, iupr);
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
            error("slice[%llu..%llu] exceeds array bounds[%llu..%llu]",
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
        if (iupr < ilwr || iupr > dollar)
        {
            error("slice [%lld..%lld] exceeds array bounds [0..%lld]",
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
    printf("%s InExp::interpret() %s\n", loc.toChars(), toChars());
#endif
    Expression *e1 = this->e1->interpret(istate);
    if (exceptionOrCantInterpret(e1))
        return e1;
    Expression *e2 = this->e2->interpret(istate);
    if (exceptionOrCantInterpret(e2))
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
    e = findKeyInAA(loc, (AssocArrayLiteralExp *)e2, e1);
    if (exceptionOrCantInterpret(e))
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
    printf("%s CatExp::interpret() %s\n", loc.toChars(), toChars());
#endif
    e1 = this->e1->interpret(istate);
    if (exceptionOrCantInterpret(e1))
        return e1;
    if (e1->op == TOKslice)
    {
        e1 = resolveSlice(e1);
    }
    e2 = this->e2->interpret(istate);
    if (exceptionOrCantInterpret(e2))
        return e2;
    if (e2->op == TOKslice)
        e2 = resolveSlice(e2);
    e = ctfeCat(type, e1, e2);
    if (e == EXP_CANT_INTERPRET)
    {   error("%s cannot be interpreted at compile time", toChars());
        return e;
    }
    // We know we still own it, because we interpreted both e1 and e2
    if (e->op == TOKarrayliteral)
        ((ArrayLiteralExp *)e)->ownedByCtfe = true;
    if (e->op == TOKstring)
        ((StringExp *)e)->ownedByCtfe = true;
    return e;
}


Expression *CastExp::interpret(InterState *istate, CtfeGoal goal)
{   Expression *e;
    Expression *e1;

#if LOG
    printf("%s CastExp::interpret() %s\n", loc.toChars(), toChars());
#endif
    e1 = this->e1->interpret(istate, goal);
    if (exceptionOrCantInterpret(e1))
        return e1;
    // If the expression has been cast to void, do nothing.
    if (to->ty == Tvoid && goal == ctfeNeedNothing)
        return e1;
    if (to->ty == Tpointer && e1->op != TOKnull)
    {
        Type *pointee = ((TypePointer *)type)->next;
        // Implement special cases of normally-unsafe casts
#if DMDV2
        if (pointee->ty == Taarray && e1->op == TOKaddress
            && isAssocArray(((AddrExp*)e1)->e1->type))
        {   // cast from template AA pointer to true AA pointer is OK.
            return paintTypeOntoLiteral(to, e1);
        }
#endif
        if (e1->op == TOKint64)
        {   // Happens with Windows HANDLEs, for example.
            return paintTypeOntoLiteral(to, e1);
        }
        bool castBackFromVoid = false;
        if (e1->type->ty == Tarray || e1->type->ty == Tsarray || e1->type->ty == Tpointer)
        {
            // Check for unsupported type painting operations
            // For slices, we need the type being sliced,
            // since it may have already been type painted
            Type *elemtype = e1->type->nextOf();
            if (e1->op == TOKslice)
                elemtype =  ((SliceExp *)e1)->e1->type->nextOf();
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
            if (ultimatePointee->ty != Tvoid && ultimateSrc->ty != Tvoid
                && !isSafePointerCast(elemtype, pointee))
            {
                error("reinterpreting cast from %s* to %s* is not supported in CTFE",
                    elemtype->toChars(), pointee->toChars());
                return EXP_CANT_INTERPRET;
            }
            if (ultimateSrc->ty == Tvoid)
                castBackFromVoid = true;
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
        if (e1->op == TOKarrayliteral || e1->op == TOKstring)
        {
            e = new IndexExp(loc, e1, new IntegerExp(loc, 0, Type::tsize_t));
            e->type = type;
            return e;
        }
        if (e1->op == TOKindex && !((IndexExp *)e1)->e1->type->equals(e1->type))
        {   // type painting operation
            IndexExp *ie = (IndexExp *)e1;
            e = new IndexExp(e1->loc, ie->e1, ie->e2);
            if (castBackFromVoid)
            {
                // get the original type. For strings, it's just the type...
                Type *origType = ie->e1->type->nextOf();
                // ..but for arrays of type void*, it's the type of the element
                Expression *xx = NULL;
                if (ie->e1->op == TOKarrayliteral && ie->e2->op == TOKint64)
                {   ArrayLiteralExp *ale = (ArrayLiteralExp *)ie->e1;
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
                    error("using void* to reinterpret cast from %s* to %s* is not supported in CTFE",
                        origType->toChars(), pointee->toChars());
                    return EXP_CANT_INTERPRET;
                }
            }
            e->type = type;
            return e;
        }
        if (e1->op == TOKaddress)
        {
            Type *origType = ((AddrExp *)e1)->e1->type;
            if (isSafePointerCast(origType, pointee))
            {
                e = new AddrExp(loc, ((AddrExp *)e1)->e1);
                e->type = type;
                return e;
            }
        }
        if (e1->op == TOKvar || e1->op == TOKsymoff)
        {   // type painting operation
            Type *origType = (e1->op == TOKvar) ? ((VarExp *)e1)->var->type :
                    ((SymOffExp *)e1)->var->type;
            if (castBackFromVoid && !isSafePointerCast(origType, pointee))
            {
                error("using void* to reinterpret cast from %s* to %s* is not supported in CTFE",
                    origType->toChars(), pointee->toChars());
                return EXP_CANT_INTERPRET;
            }
            if (e1->op == TOKvar)
                e = new VarExp(loc, ((VarExp *)e1)->var);
            else
                e = new SymOffExp(loc, ((SymOffExp *)e1)->var, ((SymOffExp *)e1)->offset);
            e->type = to;
            return e;
        }

        // Check if we have a null pointer (eg, inside a struct)
        e1 = e1->interpret(istate);
        if (e1->op != TOKnull)
        {
            error("pointer cast from %s to %s is not supported at compile time",
                e1->type->toChars(), to->toChars());
            return EXP_CANT_INTERPRET;
        }
    }
    if (to->ty == Tarray && e1->op == TOKslice)
    {   // Note that the slice may be void[], so when checking for dangerous
        // casts, we need to use the original type, which is se->e1.
        SliceExp *se = (SliceExp *)e1;
        if ( !isSafePointerCast( se->e1->type->nextOf(), to->nextOf() ) )
        {
        error("array cast from %s to %s is not supported at compile time",
             se->e1->type->toChars(), to->toChars());
        return EXP_CANT_INTERPRET;
        }
        e1 = new SliceExp(e1->loc, se->e1, se->lwr, se->upr);
        e1->type = to;
        return e1;
    }
    // Disallow array type painting, except for conversions between built-in
    // types of identical size.
    if ((to->ty == Tsarray || to->ty == Tarray) &&
        (e1->type->ty == Tsarray || e1->type->ty == Tarray) &&
        !isSafePointerCast(e1->type->nextOf(), to->nextOf()) )
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
    return ctfeCast(loc, type, to, e1);
}

Expression *AssertExp::interpret(InterState *istate, CtfeGoal goal)
{   Expression *e;
    Expression *e1;

#if LOG
    printf("%s AssertExp::interpret() %s\n", loc.toChars(), toChars());
#endif
#if DMDV2
    e1 = this->e1->interpret(istate);
#else
    // Deal with pointers (including compiler-inserted assert(&this, "null this"))
    if ( isPointer(this->e1->type) )
    {
        e1 = this->e1->interpret(istate, ctfeNeedLvalue);
        if (exceptionOrCantInterpret(e1))
            return e1;
        if (e1->op != TOKnull)
            return new IntegerExp(loc, 1, Type::tbool);
    }
    else
        e1 = this->e1->interpret(istate);
#endif
    if (exceptionOrCantInterpret(e1))
        return e1;
    if (isTrueBool(e1))
    {
    }
    else if (e1->isBool(false))
    {
        if (msg)
        {
            e = msg->interpret(istate);
            if (exceptionOrCantInterpret(e))
                return e;
            error("%s", e->toChars());
        }
        else
            error("%s failed", toChars());
        return EXP_CANT_INTERPRET;
    }
    else
    {
        error("%s is not a compile-time boolean expression", e1->toChars());
        return EXP_CANT_INTERPRET;
    }
    return e1;
}

Expression *PtrExp::interpret(InterState *istate, CtfeGoal goal)
{   Expression *e = EXP_CANT_INTERPRET;

#if LOG
    printf("%s PtrExp::interpret() %s\n", loc.toChars(), toChars());
#endif

    // Check for int<->float and long<->double casts.

    if ( e1->op == TOKsymoff && ((SymOffExp *)e1)->offset == 0
        && isFloatIntPaint(type, ((SymOffExp *)e1)->var->type) )
    {   // *(cast(int*)&v, where v is a float variable
        return paintFloatInt(getVarExp(loc, istate, ((SymOffExp *)e1)->var, ctfeNeedRvalue),
            type);
    }
    else if (e1->op == TOKcast && ((CastExp *)e1)->e1->op == TOKaddress)
    {   // *(cast(int *))&x   where x is a float expression
        Expression *x = ((AddrExp *)(((CastExp *)e1)->e1))->e1;
        if ( isFloatIntPaint(type, x->type) )
            return paintFloatInt(x->interpret(istate), type);
    }

    // Constant fold *(&structliteral + offset)
    if (e1->op == TOKadd)
    {   AddExp *ae = (AddExp *)e1;
        if (ae->e1->op == TOKaddress && ae->e2->op == TOKint64)
        {   AddrExp *ade = (AddrExp *)ae->e1;
            Expression *ex = ade->e1;
            ex = ex->interpret(istate);
            if (exceptionOrCantInterpret(ex))
                return ex;
            if (ex->op == TOKstructliteral)
            {   StructLiteralExp *se = (StructLiteralExp *)ex;
                dinteger_t offset = ae->e2->toInteger();
                e = se->getField(type, (unsigned)offset);
                if (!e)
                    e = EXP_CANT_INTERPRET;
                return e;
            }
        }
        e = Ptr(type, e1);
    }
    else
    {
#if DMDV2
#else // this is required for D1, where structs return *this instead of 'this'.
        if (e1->op == TOKthis)
        {
            if (ctfeStack.getThis())
                return ctfeStack.getThis()->interpret(istate);
            goto Ldone;
        }
#endif
        // Check for .classinfo, which is lowered in the semantic pass into **(class).
        if (e1->op == TOKstar && e1->type->ty == Tpointer && isTypeInfo_Class(e1->type->nextOf()))
        {
            e = (((PtrExp *)e1)->e1)->interpret(istate, ctfeNeedLvalue);
            if (exceptionOrCantInterpret(e))
                return e;
            if (e->op == TOKnull)
            {
                error("Null pointer dereference evaluating typeid. '%s' is null", ((PtrExp *)e1)->e1->toChars());
                return EXP_CANT_INTERPRET;
            }
            if (e->op != TOKclassreference)
            {   error("CTFE internal error determining classinfo");
                return EXP_CANT_INTERPRET;
            }
            ClassDeclaration *cd = ((ClassReferenceExp *)e)->originalClass();
            assert(cd);

            // Create the classinfo, if it doesn't yet exist.
            // TODO: This belongs in semantic, CTFE should not have to do this.
            if (!cd->vclassinfo)
                cd->vclassinfo = new TypeInfoClassDeclaration(cd->type);
            e = new SymOffExp(loc, cd->vclassinfo, 0);
            e->type = type;
            return e;
        }
       // It's possible we have an array bounds error. We need to make sure it
        // errors with this line number, not the one where the pointer was set.
        e = e1->interpret(istate, ctfeNeedLvalue);
        if (exceptionOrCantInterpret(e))
            return e;
        if (!(e->op == TOKvar || e->op == TOKdotvar || e->op == TOKindex
            || e->op == TOKslice || e->op == TOKaddress))
        {
            if (e->op == TOKsymoff)
                error("cannot dereference pointer to static variable %s at compile time", ((SymOffExp *)e)->var->toChars());
            else
                error("dereference of invalid pointer '%s'", e->toChars());
            return EXP_CANT_INTERPRET;
        }
        if (goal != ctfeNeedLvalue && goal != ctfeNeedLvalueRef)
        {
            if (e->op == TOKindex && e->type->ty == Tpointer)
            {
                IndexExp *ie = (IndexExp *)e;
                // Is this a real index to an array of pointers, or just a CTFE pointer?
                // If the index has the same levels of indirection, it's an index
                int srcLevels = 0;
                int destLevels = 0;
                for(Type *xx = ie->e1->type; xx->ty == Tpointer; xx = xx->nextOf())
                    ++srcLevels;
                for(Type *xx = e->type->nextOf(); xx->ty == Tpointer; xx = xx->nextOf())
                    ++destLevels;
                bool isGenuineIndex = (srcLevels == destLevels);

                if ((ie->e1->op == TOKarrayliteral || ie->e1->op == TOKstring)
                    && ie->e2->op == TOKint64)
                {
                    Expression *dollar = ArrayLength(Type::tsize_t, ie->e1);
                    dinteger_t len = dollar->toInteger();
                    dinteger_t indx = ie->e2->toInteger();
                    assert(indx >=0 && indx <= len); // invalid pointer
                    if (indx == len)
                    {
                        error("dereference of pointer %s one past end of memory block limits [0..%lld]",
                            toChars(), len);
                        return EXP_CANT_INTERPRET;
                    }
                    e = ctfeIndex(loc, type, ie->e1, indx);
                    if (isGenuineIndex)
                    {
                        if (e->op == TOKindex)
                            e = e->interpret(istate, goal);
                        else if (e->op == TOKaddress)
                            e = paintTypeOntoLiteral(type, ((AddrExp *)e)->e1);
                    }
                    return e;
                }
                if (ie->e1->op == TOKassocarrayliteral)
                {
                    e = findKeyInAA(loc, (AssocArrayLiteralExp *)ie->e1, ie->e2);
                    assert(e != EXP_CANT_INTERPRET);
                    e = paintTypeOntoLiteral(type, e);
                    if (isGenuineIndex)
                    {
                        if (e->op == TOKindex)
                            e = e->interpret(istate, goal);
                        else if (e->op == TOKaddress)
                            e = paintTypeOntoLiteral(type, ((AddrExp *)e)->e1);
                    }
                    return e;
                }
            }
            if (e->op == TOKstructliteral)
                return e;
            e = e1->interpret(istate, goal);
            if (e->op == TOKaddress)
            {
                e = ((AddrExp*)e)->e1;
                // We're changing *&e to e.
                // We needed the AddrExp to deal with type painting expressions
                // we couldn't otherwise express. Now that the type painting is
                // undone, we must simplify them. This applies to references
                // (which will be a DotVarExp or IndexExp) and to local structs
                // (which will be a VarExp).

                // We sometimes use DotVarExp and IndexExp to represent pointers,
                // so in that case, they shouldn't be simplified.

                bool isCtfePtr = (e->op == TOKdotvar || e->op == TOKindex)
                        && isPointer(e->type);

                // We also must not simplify if it is already a struct Literal
                // or array literal, because it has already been interpreted.
                if ( !isCtfePtr && e->op != TOKstructliteral &&
                    e->op != TOKassocarrayliteral && e->op != TOKarrayliteral)
                {
                    e = e->interpret(istate, goal);
                }
            }
            else if (e->op == TOKvar)
            {
                e = e->interpret(istate, goal);
            }
            if (exceptionOrCantInterpret(e))
                return e;
        }
        else if (e->op == TOKaddress)
            e = ((AddrExp*)e)->e1;  // *(&x) ==> x
        else if (e->op == TOKnull)
        {
            error("dereference of null pointer '%s'", e1->toChars());
            return EXP_CANT_INTERPRET;
        }
        e = paintTypeOntoLiteral(type, e);
    }

Ldone:
#if LOG
    if (e == EXP_CANT_INTERPRET)
        printf("PtrExp::interpret() %s = EXP_CANT_INTERPRET\n", toChars());
#endif
    return e;
}

Expression *DotVarExp::interpret(InterState *istate, CtfeGoal goal)
{   Expression *e = EXP_CANT_INTERPRET;

#if LOG
    printf("%s DotVarExp::interpret() %s\n", loc.toChars(), toChars());
#endif

    Expression *ex = e1->interpret(istate);
    if (exceptionOrCantInterpret(ex))
        return ex;
    if (ex != EXP_CANT_INTERPRET)
    {
        #if DMDV2
        // Special case for template AAs: AA.var returns the AA itself.
        //  ie AA.p  ----> AA. This is a hack, to get around the
        // corresponding hack in the AA druntime implementation.
        if (isAssocArray(ex->type))
            return ex;
        #endif
        if (ex->op == TOKaddress)
            ex = ((AddrExp *)ex)->e1;
        VarDeclaration *v = var->isVarDeclaration();
        if (!v)
        {
            error("CTFE internal error: %s", toChars());
            return EXP_CANT_INTERPRET;
        }
        if (ex->op == TOKnull && ex->type->toBasetype()->ty == Tclass)
        {   error("class '%s' is null and cannot be dereferenced", e1->toChars());
            return EXP_CANT_INTERPRET;
        }
        if (ex->op == TOKnull)
        {   error("dereference of null pointer '%s'", e1->toChars());
            return EXP_CANT_INTERPRET;
        }
        if (ex->op == TOKstructliteral || ex->op == TOKclassreference)
        {
            StructLiteralExp *se = ex->op == TOKclassreference ? ((ClassReferenceExp *)ex)->value : (StructLiteralExp *)ex;
            /* We don't know how to deal with overlapping fields
             */
            if (se->sd->hasUnions)
            {   error("Unions with overlapping fields are not yet supported in CTFE");
                return EXP_CANT_INTERPRET;
            }
            // We can't use getField, because it makes a copy
            int i = -1;
            if (ex->op == TOKclassreference)
                i = ((ClassReferenceExp *)ex)->findFieldIndexByName(v);
            else
                i = findFieldIndexByName(se->sd, v);
            if (i == -1)
            {
                error("couldn't find field %s of type %s in %s", v->toChars(), type->toChars(), se->toChars());
                return EXP_CANT_INTERPRET;
            }
            e = (*se->elements)[i];
            if (goal == ctfeNeedLvalue || goal == ctfeNeedLvalueRef)
            {
                // If it is an lvalue literal, return it...
                if (e->op == TOKstructliteral)
                    return e;
                if ((type->ty == Tsarray || goal == ctfeNeedLvalue) && (
                    e->op == TOKarrayliteral ||
                    e->op == TOKassocarrayliteral || e->op == TOKstring ||
                    e->op == TOKclassreference || e->op == TOKslice))
                    return e;
                /* Element is an allocated pointer, which was created in
                 * CastExp.
                 */
                if (goal == ctfeNeedLvalue && e->op == TOKindex &&
                    e->type->equals(type) &&
                    isPointer(type) )
                    return e;
                // ...Otherwise, just return the (simplified) dotvar expression
                e = new DotVarExp(loc, ex, v);
                e->type = type;
                return e;
            }
            if (!e)
            {
                error("Internal Compiler Error: Null field %s", v->toChars());
                return EXP_CANT_INTERPRET;
            }
            // If it is an rvalue literal, return it...
            if (e->op == TOKstructliteral || e->op == TOKarrayliteral ||
                e->op == TOKassocarrayliteral || e->op == TOKstring)
                    return e;
            if (e->op == TOKvoid)
            {
                VoidInitExp *ve = (VoidInitExp *)e;
                error("cannot read uninitialized variable %s in CTFE", ve->var->toChars());
                return EXP_CANT_INTERPRET;
            }
            if ( isPointer(type) )
            {
                return paintTypeOntoLiteral(type, e);
            }
            if (e->op == TOKvar)
            {   // Don't typepaint twice, since that might cause an erroneous copy
                e = getVarExp(loc, istate, ((VarExp *)e)->var, goal);
                if (e != EXP_CANT_INTERPRET && e->op != TOKthrownexception)
                    e = paintTypeOntoLiteral(type, e);
                return e;
            }
            return e->interpret(istate, goal);
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

Expression *RemoveExp::interpret(InterState *istate, CtfeGoal goal)
{
#if LOG
    printf("%s RemoveExp::interpret() %s\n", loc.toChars(), toChars());
#endif
    Expression *agg = e1->interpret(istate);
    if (exceptionOrCantInterpret(agg))
        return agg;
    Expression *index = e2->interpret(istate);
    if (exceptionOrCantInterpret(index))
        return index;
    if (agg->op == TOKnull)
        return EXP_VOID_INTERPRET;
    assert(agg->op == TOKassocarrayliteral);
    AssocArrayLiteralExp *aae = (AssocArrayLiteralExp *)agg;
    Expressions *keysx = aae->keys;
    Expressions *valuesx = aae->values;
    size_t removed = 0;
    for (size_t j = 0; j < valuesx->dim; ++j)
    {
        Expression *ekey = (*keysx)[j];
        int eq = ctfeEqual(loc, TOKequal, ekey, index);
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
    return new IntegerExp(loc, removed?1:0, Type::tbool);
}


/******************************* Special Functions ***************************/

Expression *interpret_length(InterState *istate, Expression *earg)
{
    //printf("interpret_length()\n");
    earg = earg->interpret(istate);
    if (exceptionOrCantInterpret(earg))
        return earg;
    dinteger_t len = 0;
    if (earg->op == TOKassocarrayliteral)
        len = ((AssocArrayLiteralExp *)earg)->keys->dim;
    else assert(earg->op == TOKnull);
    Expression *e = new IntegerExp(earg->loc, len, Type::tsize_t);
    return e;
}

Expression *interpret_keys(InterState *istate, Expression *earg, Type *returnType)
{
#if LOG
    printf("interpret_keys()\n");
#endif
    earg = earg->interpret(istate);
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
    return copyLiteral(ae);
}

Expression *interpret_values(InterState *istate, Expression *earg, Type *returnType)
{
#if LOG
    printf("interpret_values()\n");
#endif
    earg = earg->interpret(istate);
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
    return copyLiteral(ae);
}

// signature is int delegate(ref Value) OR int delegate(ref Key, ref Value)
Expression *interpret_aaApply(InterState *istate, Expression *aa, Expression *deleg)
{   aa = aa->interpret(istate);
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
    int numParams = fd->parameters->dim;
    assert(numParams == 1 || numParams == 2);

    Parameter *valueArg = Parameter::getNth(((TypeFunction *)fd->type)->parameters, numParams - 1);
    bool wantRefValue = 0 != (valueArg->storageClass & (STCout | STCref));

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
        {   Type *t = evalue->type;
            evalue = new IndexExp(deleg->loc, ae, ekey);
            evalue->type = t;
        }
        args[numParams - 1] = evalue;
        if (numParams == 2) args[0] = ekey;

        eresult = fd->interpret(istate, &args, pthis);
        if (exceptionOrCantInterpret(eresult))
            return eresult;

        assert(eresult->op == TOKint64);
        if (((IntegerExp *)eresult)->value != 0)
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
    int numParams = fd->parameters->dim;
    assert(numParams == 1 || numParams==2);
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
    {   str->error("CTFE internal error: cannot foreach %s", str->toChars());
        return EXP_CANT_INTERPRET;
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
        {   // If it is an array literal, copy the code points into the buffer
            size_t buflen = 1; // #code points in the buffer
            size_t n = 1;   // #code points in this char
            size_t sz = (size_t)ale->type->nextOf()->size();

            switch(sz)
            {
            case 1:
                if (rvs)
                {   // find the start of the string
                    --indx;
                    buflen = 1;
                    while (indx > 0 && buflen < 4)
                    {
                        Expression * r = (*ale->elements)[indx];
                        assert(r->op == TOKint64);
                        utf8_t x = (utf8_t)(((IntegerExp *)r)->value);
                        if ( (x & 0xC0) != 0x80)
                            break;
                        ++buflen;
                    }
                }
                else
                    buflen = (indx + 4 > len) ? len - indx : 4;
                for (int i = 0; i < buflen; ++i)
                {
                    Expression * r = (*ale->elements)[indx + i];
                    assert(r->op == TOKint64);
                    utf8buf[i] = (utf8_t)(((IntegerExp *)r)->value);
                }
                n = 0;
                errmsg = utf_decodeChar(&utf8buf[0], buflen, &n, &rawvalue);
                break;
            case 2:
                if (rvs)
                {   // find the start of the string
                    --indx;
                    buflen = 1;
                    Expression * r = (*ale->elements)[indx];
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
                    Expression * r = (*ale->elements)[indx + i];
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

                    Expression * r = (*ale->elements)[indx];
                    assert(r->op == TOKint64);
                    rawvalue = (dchar_t)((IntegerExp *)r)->value;
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
                    utf8_t *s = (utf8_t *)se->string;
                    --indx;
                    while (indx > 0 && ((s[indx]&0xC0)==0x80))
                        --indx;
                    saveindx = indx;
                }
                errmsg = utf_decodeChar((utf8_t *)se->string, se->len, &indx, &rawvalue);
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
            args[0] = new IntegerExp(deleg->loc, currentIndex, indexType);

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

            args[numParams - 1] = val;

            eresult = fd->interpret(istate, &args, pthis);
            if (exceptionOrCantInterpret(eresult))
                return eresult;
            assert(eresult->op == TOKint64);
            if (((IntegerExp *)eresult)->value != 0)
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
    int nargs = arguments ? arguments->dim : 0;
#if DMDV2
    if (pthis && isAssocArray(pthis->type))
    {
        if (fd->ident == Id::length &&  nargs==0)
            return interpret_length(istate, pthis);
        else if (fd->ident == Id::keys && nargs==0)
            return interpret_keys(istate, pthis, returnedArrayType(fd));
        else if (fd->ident == Id::values && nargs==0)
            return interpret_values(istate, pthis, returnedArrayType(fd));
        else if (fd->ident == Id::rehash && nargs==0)
            return pthis->interpret(istate, ctfeNeedLvalue);  // rehash is a no-op
    }
    if (!pthis)
    {
        BUILTIN b = fd->isBuiltin();
        if (b)
        {   Expressions args;
            args.setDim(nargs);
            for (size_t i = 0; i < args.dim; i++)
            {
                Expression *earg = (*arguments)[i];
                earg = earg->interpret(istate);
                if (exceptionOrCantInterpret(earg))
                    return earg;
                args[i] = earg;
            }
            e = eval_builtin(loc, b, &args);
            if (!e)
            {
                error(loc, "cannot evaluate unimplemented builtin %s at compile time", fd->toChars());
                e = EXP_CANT_INTERPRET;
            }
        }
    }

    if (!pthis)
    {
        Expression *firstarg =  nargs > 0 ? (Expression *)(arguments->data[0]) : NULL;
        if (nargs==3 && isAssocArray(firstarg->type) && !strcmp(fd->ident->string, "_aaApply"))
            return interpret_aaApply(istate, firstarg, (Expression *)(arguments->data[2]));
        if (nargs==3 && isAssocArray(firstarg->type) &&!strcmp(fd->ident->string, "_aaApply2"))
            return interpret_aaApply(istate, firstarg, (Expression *)(arguments->data[2]));
    }
#endif
#if DMDV1
    if (!pthis)
    {
        Expression *firstarg =  nargs > 0 ? (Expression *)(arguments->data[0]) : NULL;
        if (firstarg && firstarg->type->toBasetype()->ty == Taarray)
        {
            TypeAArray *firstAAtype = (TypeAArray *)firstarg->type;
            if (fd->ident == Id::aaLen && nargs == 1)
                return interpret_length(istate, firstarg);
            else if (fd->ident == Id::aaKeys)
                return interpret_keys(istate, firstarg, new DArray(firstAAtype->index));
            else if (fd->ident == Id::aaValues)
                return interpret_values(istate, firstarg, new DArray(firstAAtype->nextOf()));
            else if (nargs==2 && fd->ident == Id::aaRehash)
                return firstarg->interpret(istate, ctfeNeedLvalue); //no-op
            else if (nargs==3 && !strcmp(fd->ident->string, "_aaApply"))
                return interpret_aaApply(istate, firstarg, (Expression *)(arguments->data[2]));
            else if (nargs==3 && !strcmp(fd->ident->string, "_aaApply2"))
                return interpret_aaApply(istate, firstarg, (Expression *)(arguments->data[2]));
        }
    }
#endif
#if DMDV2
    if (pthis && !fd->fbody && fd->isCtorDeclaration() && fd->parent && fd->parent->parent && fd->parent->parent->ident == Id::object)
    {
        if (pthis->op == TOKclassreference && fd->parent->ident == Id::Throwable)
        {   // At present, the constructors just copy their arguments into the struct.
            // But we might need some magic if stack tracing gets added to druntime.
            StructLiteralExp *se = ((ClassReferenceExp *)pthis)->value;
            assert(arguments->dim <= se->elements->dim);
            for (int i = 0; i < arguments->dim; ++i)
            {
                e = (*arguments)[i]->interpret(istate);
                if (exceptionOrCantInterpret(e))
                    return e;
                (*se->elements)[i] = e;
            }
            return EXP_VOID_INTERPRET;
        }
    }
#endif
    if (nargs == 1 && !pthis &&
        (fd->ident == Id::criticalenter || fd->ident == Id::criticalexit))
    {   // Support synchronized{} as a no-op
        return EXP_VOID_INTERPRET;
    }
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
            {   Expression *str = (*arguments)[0];
                str = str->interpret(istate);
                if (exceptionOrCantInterpret(str))
                    return str;
                return foreachApplyUtf(istate, str, (*arguments)[1], rvs);
            }
        }
    }
    return e;
}

/*************************** CTFE Sanity Checks ***************************/

/* Setter functions for CTFE variable values.
 * These functions exist to check for compiler CTFE bugs.
 */
bool VarDeclaration::hasValue()
{
    if (ctfeAdrOnStack == (size_t)-1)
        return false;
    return NULL != getValue();
}

Expression *VarDeclaration::getValue()
{
    return ctfeStack.getValue(this);
}

void VarDeclaration::setValueNull()
{
    ctfeStack.setValue(this, NULL);
}

// Don't check for validity
void VarDeclaration::setValueWithoutChecking(Expression *newval)
{
    ctfeStack.setValue(this, newval);
}

void VarDeclaration::setValue(Expression *newval)
{
    assert(isCtfeValueValid(newval));
    ctfeStack.setValue(this, newval);
}

