
// Copyright (c) 1999-2012 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

// Routines to perform function inlining

#define LOG 0

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <string.h>                     // memset()

#include "id.h"
#include "init.h"
#include "declaration.h"
#include "aggregate.h"
#include "expression.h"
#include "statement.h"
#include "mtype.h"
#include "scope.h"

/* ========== Compute cost of inlining =============== */

/* Walk trees to determine if inlining can be done, and if so,
 * if it is too complex to be worth inlining or not.
 */

struct InlineCostState
{
    int nested;
    int hasthis;
    int hdrscan;    // !=0 if inline scan for 'header' content
    FuncDeclaration *fd;
};

const int COST_MAX = 250;
const int STATEMENT_COST = 0x1000;
const int STATEMENT_COST_MAX = 250 * 0x1000;

// STATEMENT_COST be power of 2 and greater than COST_MAX
//static assert((STATEMENT_COST & (STATEMENT_COST - 1)) == 0);
//static assert(STATEMENT_COST > COST_MAX);

bool tooCostly(int cost) { return ((cost & (STATEMENT_COST - 1)) >= COST_MAX); }

int expressionInlineCost(Expression *e, InlineCostState *ics);

int Statement::inlineCost(InlineCostState *ics)
{
    //printf("Statement::inlineCost = %d\n", COST_MAX);
    //printf("%p\n", isScopeStatement());
    //printf("%s\n", toChars());
    return COST_MAX;            // default is we can't inline it
}

int ExpStatement::inlineCost(InlineCostState *ics)
{
    return expressionInlineCost(exp, ics);
    //return exp ? exp->inlineCost(ics) : 0;
}

int CompoundStatement::inlineCost(InlineCostState *ics)
{   int cost = 0;

    for (size_t i = 0; i < statements->dim; i++)
    {   Statement *s = (*statements)[i];
        if (s)
        {
            cost += s->inlineCost(ics);
            if (tooCostly(cost))
                break;
        }
    }
    //printf("CompoundStatement::inlineCost = %d\n", cost);
    return cost;
}

int UnrolledLoopStatement::inlineCost(InlineCostState *ics)
{   int cost = 0;

    for (size_t i = 0; i < statements->dim; i++)
    {   Statement *s = (*statements)[i];
        if (s)
        {
            cost += s->inlineCost(ics);
            if (tooCostly(cost))
                break;
        }
    }
    return cost;
}

int ScopeStatement::inlineCost(InlineCostState *ics)
{
    return statement ? 1 + statement->inlineCost(ics) : 1;
}

int IfStatement::inlineCost(InlineCostState *ics)
{
    int cost;

    /* Can't declare variables inside ?: expressions, so
     * we cannot inline if a variable is declared.
     */
    if (arg)
        return COST_MAX;

    cost = expressionInlineCost(condition, ics);

    /* Specifically allow:
     *  if (condition)
     *      return exp1;
     *  else
     *      return exp2;
     * Otherwise, we can't handle return statements nested in if's.
     */

    if (elsebody && ifbody &&
        ifbody->isReturnStatement() &&
        elsebody->isReturnStatement())
    {
        cost += ifbody->inlineCost(ics);
        cost += elsebody->inlineCost(ics);
        //printf("cost = %d\n", cost);
    }
    else
    {
        ics->nested += 1;
        if (ifbody)
            cost += ifbody->inlineCost(ics);
        if (elsebody)
            cost += elsebody->inlineCost(ics);
        ics->nested -= 1;
    }
    //printf("IfStatement::inlineCost = %d\n", cost);
    return cost;
}

int ReturnStatement::inlineCost(InlineCostState *ics)
{
    // Can't handle return statements nested in if's
    if (ics->nested)
        return COST_MAX;
    return expressionInlineCost(exp, ics);
}

int ImportStatement::inlineCost(InlineCostState *ics)
{
    return 0;
}

int ForStatement::inlineCost(InlineCostState *ics)
{
    //return COST_MAX;
    int cost = STATEMENT_COST;
    if (init)
        cost += init->inlineCost(ics);
    if (condition)
        cost += expressionInlineCost(condition, ics);
    if (increment)
        cost += expressionInlineCost(increment, ics);
    if (body)
        cost += body->inlineCost(ics);
    //printf("ForStatement: inlineCost = %d\n", cost);
    return cost;
}


/* -------------------------- */

struct ICS2
{
    int cost;
    InlineCostState *ics;
};

int lambdaInlineCost(Expression *e, void *param)
{
    ICS2 *ics2 = (ICS2 *)param;
    ics2->cost += e->inlineCost3(ics2->ics);
    return (ics2->cost >= COST_MAX);
}

int expressionInlineCost(Expression *e, InlineCostState *ics)
{
    //printf("expressionInlineCost()\n");
    //e->dump(0);
    ICS2 ics2;
    ics2.cost = 0;
    ics2.ics = ics;
    if (e)
        e->apply(&lambdaInlineCost, &ics2);
    return ics2.cost;
}

int Expression::inlineCost3(InlineCostState *ics)
{
    return 1;
}

int VarExp::inlineCost3(InlineCostState *ics)
{
    //printf("VarExp::inlineCost3() %s\n", toChars());
    Type *tb = type->toBasetype();
    if (tb->ty == Tstruct)
    {
        StructDeclaration *sd = ((TypeStruct *)tb)->sym;
        if (sd->isNested())
            /* An inner struct will be nested inside another function hierarchy than where
             * we're inlining into, so don't inline it.
             * At least not until we figure out how to 'move' the struct to be nested
             * locally. Example:
             *   struct S(alias pred) { void unused_func(); }
             *   void abc() { int w; S!(w) m; }
             *   void bar() { abc(); }
             */
            return COST_MAX;
    }
    FuncDeclaration *fd = var->isFuncDeclaration();
    if (fd && fd->isNested())           // see Bugzilla 7199 for test case
        return COST_MAX;
    return 1;
}

int ThisExp::inlineCost3(InlineCostState *ics)
{
    //printf("ThisExp::inlineCost3() %s\n", toChars());
    FuncDeclaration *fd = ics->fd;
    if (!fd)
        return COST_MAX;
    if (!ics->hdrscan)
        if (fd->isNested() || !ics->hasthis)
            return COST_MAX;
    return 1;
}

int StructLiteralExp::inlineCost3(InlineCostState *ics)
{
    //printf("StructLiteralExp::inlineCost3() %s\n", toChars());
    if (sd->isNested())
        return COST_MAX;
    return 1;
}

int FuncExp::inlineCost3(InlineCostState *ics)
{
    //printf("FuncExp::inlineCost3()\n");
    // Right now, this makes the function be output to the .obj file twice.
    return COST_MAX;
}

int DelegateExp::inlineCost3(InlineCostState *ics)
{
    //printf("DelegateExp::inlineCost3()\n");
    return COST_MAX;
}

#if DMD_OBJC
int ObjcSelectorExp::inlineCost3(InlineCostState *ics)
{
    return COST_MAX;
}
#endif

int DeclarationExp::inlineCost3(InlineCostState *ics)
{   int cost = 0;
    VarDeclaration *vd;

    //printf("DeclarationExp::inlineCost3()\n");
    vd = declaration->isVarDeclaration();
    if (vd)
    {
        TupleDeclaration *td = vd->toAlias()->isTupleDeclaration();
        if (td)
        {
#if 1
            return COST_MAX;    // finish DeclarationExp::doInline
#else
            for (size_t i = 0; i < td->objects->dim; i++)
            {   RootObject *o = (*td->objects)[i];
                if (o->dyncast() != DYNCAST_EXPRESSION)
                    return COST_MAX;
                Expression *eo = (Expression *)o;
                if (eo->op != TOKdsymbol)
                    return COST_MAX;
            }
            return td->objects->dim;
#endif
        }
        if (!ics->hdrscan && vd->isDataseg())
            return COST_MAX;
        cost += 1;

        if (vd->edtor)                  // if destructor required
            return COST_MAX;            // needs work to make this work
        // Scan initializer (vd->init)
        if (vd->init)
        {
            ExpInitializer *ie = vd->init->isExpInitializer();

            if (ie)
            {
                cost += expressionInlineCost(ie->exp, ics);
            }
        }
    }

    // These can contain functions, which when copied, get output twice.
    if (declaration->isStructDeclaration() ||
        declaration->isClassDeclaration() ||
        declaration->isFuncDeclaration() ||
        declaration->isTypedefDeclaration() ||
        declaration->isAttribDeclaration() ||
        declaration->isTemplateMixin())
        return COST_MAX;

    //printf("DeclarationExp::inlineCost3('%s')\n", toChars());
    return cost;
}

int CallExp::inlineCost3(InlineCostState *ics)
{
    //printf("CallExp::inlineCost3() %s\n", toChars());
    // Bugzilla 3500: super.func() calls must be devirtualized, and the inliner
    // can't handle that at present.
    if (e1->op == TOKdotvar && ((DotVarExp *)e1)->e1->op == TOKsuper)
        return COST_MAX;

    return 1;
}


/* ======================== Perform the inlining ============================== */

/* Inlining is done by:
 * o    Converting to an Expression
 * o    Copying the trees of the function to be inlined
 * o    Renaming the variables
 */

struct InlineDoState
{
    // inline context
    VarDeclaration *vthis;
    Dsymbols from;      // old Dsymbols
    Dsymbols to;        // parallel array of new Dsymbols
    Dsymbol *parent;    // new parent
    FuncDeclaration *fd; // function being inlined (old parent)
    // inline result
    bool foundReturn;
};
/* -------------------------------------------------------------------- */

Statement *Statement::doInlineStatement(InlineDoState *ids)
{
    assert(0);
    return NULL;                // default is we can't inline it
}

Statement *ExpStatement::doInlineStatement(InlineDoState *ids)
{
#if LOG
    if (exp) printf("ExpStatement::doInlineStatement() '%s'\n", exp->toChars());
#endif
    return new ExpStatement(loc, exp ? exp->doInline(ids) : NULL);
}

Statement *CompoundStatement::doInlineStatement(InlineDoState *ids)
{
    //printf("CompoundStatement::doInlineStatement() %d\n", statements->dim);
    Statements *as = new Statements();
    as->reserve(statements->dim);
    for (size_t i = 0; i < statements->dim; i++)
    {   Statement *s = (*statements)[i];
        if (s)
        {
            as->push(s->doInlineStatement(ids));
            if (ids->foundReturn)
                break;
        }
        else
            as->push(NULL);
    }
    return new CompoundStatement(loc, as);
}

Statement *UnrolledLoopStatement::doInlineStatement(InlineDoState *ids)
{
    //printf("UnrolledLoopStatement::doInlineStatement() %d\n", statements->dim);
    Statements *as = new Statements();
    as->reserve(statements->dim);
    for (size_t i = 0; i < statements->dim; i++)
    {   Statement *s = (*statements)[i];
        if (s)
        {
            as->push(s->doInlineStatement(ids));
            if (ids->foundReturn)
                break;
        }
        else
            as->push(NULL);
    }
    return new UnrolledLoopStatement(loc, as);
}

Statement *ScopeStatement::doInlineStatement(InlineDoState *ids)
{
    //printf("ScopeStatement::doInlineStatement() %d\n", statements->dim);
    return statement ? new ScopeStatement(loc, statement->doInlineStatement(ids)) : this;
}

Statement *IfStatement::doInlineStatement(InlineDoState *ids)
{
    assert(!arg);

    Expression *condition = this->condition ? this->condition->doInline(ids) : NULL;
    Statement *ifbody = this->ifbody ? this->ifbody->doInlineStatement(ids) : NULL;
    bool bodyReturn = ids->foundReturn;
    ids->foundReturn = false;
    Statement *elsebody = this->elsebody ? this->elsebody->doInlineStatement(ids) : NULL;
    ids->foundReturn = ids->foundReturn && bodyReturn;


    return new IfStatement(loc, arg, condition, ifbody, elsebody);
}

Statement *ReturnStatement::doInlineStatement(InlineDoState *ids)
{
    //printf("ReturnStatement::doInlineStatement() '%s'\n", exp ? exp->toChars() : "");
    ids->foundReturn = true;
    return new ReturnStatement(loc, exp ? exp->doInline(ids) : NULL);
}

Statement *ImportStatement::doInlineStatement(InlineDoState *ids)
{
    return NULL;
}

Statement *ForStatement::doInlineStatement(InlineDoState *ids)
{
    //printf("ForStatement::doInlineStatement()\n");
    Statement *init = this->init ? this->init->doInlineStatement(ids) : NULL;
    Expression *condition = this->condition ? this->condition->doInline(ids) : NULL;
    Expression *increment = this->increment ? this->increment->doInline(ids) : NULL;
    Statement *body = this->body ? this->body->doInlineStatement(ids) : NULL;
    return new ForStatement(loc, init, condition, increment, body);
}

/* -------------------------------------------------------------------- */

Expression *Statement::doInline(InlineDoState *ids)
{
    printf("Statement::doInline()\n%s\n", toChars());
    fflush(stdout);
    assert(0);
    return NULL;                // default is we can't inline it
}

Expression *ExpStatement::doInline(InlineDoState *ids)
{
#if LOG
    if (exp) printf("ExpStatement::doInline() '%s'\n", exp->toChars());
#endif
    return exp ? exp->doInline(ids) : NULL;
}

Expression *CompoundStatement::doInline(InlineDoState *ids)
{
    Expression *e = NULL;

    //printf("CompoundStatement::doInline() %d\n", statements->dim);
    for (size_t i = 0; i < statements->dim; i++)
    {   Statement *s =  (*statements)[i];
        if (s)
        {
            Expression *e2 = s->doInline(ids);
            e = Expression::combine(e, e2);
            if (ids->foundReturn)
                break;

        }
    }
    return e;
}

Expression *UnrolledLoopStatement::doInline(InlineDoState *ids)
{
    Expression *e = NULL;

    //printf("UnrolledLoopStatement::doInline() %d\n", statements->dim);
    for (size_t i = 0; i < statements->dim; i++)
    {   Statement *s =  (*statements)[i];
        if (s)
        {
            Expression *e2 = s->doInline(ids);
            e = Expression::combine(e, e2);
            if (ids->foundReturn)
                break;
        }
    }
    return e;
}

Expression *ScopeStatement::doInline(InlineDoState *ids)
{
    return statement ? statement->doInline(ids) : NULL;
}

Expression *IfStatement::doInline(InlineDoState *ids)
{
    Expression *econd;
    Expression *e1;
    Expression *e2;
    Expression *e;

    assert(!arg);
    econd = condition->doInline(ids);
    assert(econd);
    if (ifbody)
    {
        e1 = ifbody->doInline(ids);
    }
    else
        e1 = NULL;
    bool bodyReturn = ids->foundReturn;
    ids->foundReturn = false;
    if (elsebody)
        e2 = elsebody->doInline(ids);
    else
        e2 = NULL;
    if (e1 && e2)
    {
        e = new CondExp(econd->loc, econd, e1, e2);
        e->type = e1->type;
        if (e->type->ty == Ttuple)
        {
            e1->type = Type::tvoid;
            e2->type = Type::tvoid;
            e->type = Type::tvoid;
        }
    }
    else if (e1)
    {
        e = new AndAndExp(econd->loc, econd, e1);
        e->type = Type::tvoid;
    }
    else if (e2)
    {
        e = new OrOrExp(econd->loc, econd, e2);
        e->type = Type::tvoid;
    }
    else
    {
        e = econd;
    }
    ids->foundReturn = ids->foundReturn && bodyReturn;
    return e;
}

Expression *ReturnStatement::doInline(InlineDoState *ids)
{
    //printf("ReturnStatement::doInline() '%s'\n", exp ? exp->toChars() : "");
    ids->foundReturn = true;
    return exp ? exp->doInline(ids) : NULL;
}

Expression *ImportStatement::doInline(InlineDoState *ids)
{
    return NULL;
}

/* --------------------------------------------------------------- */

/******************************
 * Perform doInline() on an array of Expressions.
 */

Expressions *arrayExpressiondoInline(Expressions *a, InlineDoState *ids)
{   Expressions *newa = NULL;

    if (a)
    {
        newa = new Expressions();
        newa->setDim(a->dim);

        for (size_t i = 0; i < a->dim; i++)
        {   Expression *e = (*a)[i];

            if (e)
                e = e->doInline(ids);
            (*newa)[i] = e;
        }
    }
    return newa;
}

Expression *Expression::doInline(InlineDoState *ids)
{
    //printf("Expression::doInline(%s): %s\n", Token::toChars(op), toChars());
    return copy();
}

Expression *SymOffExp::doInline(InlineDoState *ids)
{
    //printf("SymOffExp::doInline(%s)\n", toChars());
    for (size_t i = 0; i < ids->from.dim; i++)
    {
        if (var == ids->from[i])
        {
            SymOffExp *se = (SymOffExp *)copy();
            se->var = (Declaration *)ids->to[i];
            return se;
        }
    }
    return this;
}

Expression *VarExp::doInline(InlineDoState *ids)
{
    //printf("VarExp::doInline(%s)\n", toChars());
    for (size_t i = 0; i < ids->from.dim; i++)
    {
        if (var == ids->from[i])
        {
            VarExp *ve = (VarExp *)copy();
            ve->var = (Declaration *)ids->to[i];
            return ve;
        }
    }
    if (ids->fd && var == ids->fd->vthis)
    {
        VarExp *ve = new VarExp(loc, ids->vthis);
        ve->type = type;
        return ve;
    }

    /* Inlining context pointer access for nested referenced variables.
     * For example:
     *      auto fun() {
     *        int i = 40;
     *        auto foo() {
     *          int g = 2;
     *          struct Result {
     *            auto bar() { return i + g; }
     *          }
     *          return Result();
     *        }
     *        return foo();
     *      }
     *      auto t = fun();
     * 'i' and 'g' are nested referenced variables in Result.bar(), so:
     *      auto x = t.bar();
     * should be inlined to:
     *      auto x = *(t.vthis.vthis + i->voffset) + *(t.vthis + g->voffset)
     */
    VarDeclaration *v = var->isVarDeclaration();
    if (v && v->nestedrefs.dim && ids->vthis)
    {
        Dsymbol *s = ids->fd;
        FuncDeclaration *fdv = v->toParent()->isFuncDeclaration();
        assert(fdv);
        Expression *ve = new VarExp(loc, ids->vthis);
        ve->type = ids->vthis->type;
        while (s != fdv)
        {
            FuncDeclaration *f = s->isFuncDeclaration();
            if (AggregateDeclaration *ad = s->isThis())
            {
                assert(ad->vthis);
                ve = new DotVarExp(loc, ve, ad->vthis);
                ve->type = ad->vthis->type;
                s = ad->toParent2();
            }
            else if (f && f->isNested())
            {
                assert(f->vthis);
                if (f->hasNestedFrameRefs())
                {
                    ve = new DotVarExp(loc, ve, f->vthis);
                    ve->type = f->vthis->type;
                }
                s = f->toParent2();
            }
            else
                assert(0);
            assert(s);
        }
        ve = new DotVarExp(loc, ve, v);
        ve->type = v->type;
        //printf("\t==> ve = %s, type = %s\n", ve->toChars(), ve->type->toChars());
        return ve;
    }

    return this;
}

Expression *ThisExp::doInline(InlineDoState *ids)
{
    //if (!ids->vthis)
        //error("no 'this' when inlining %s", ids->parent->toChars());
    if (!ids->vthis)
    {
        return this;
    }

    VarExp *ve = new VarExp(loc, ids->vthis);
    ve->type = type;
    return ve;
}

Expression *SuperExp::doInline(InlineDoState *ids)
{
    assert(ids->vthis);

    VarExp *ve = new VarExp(loc, ids->vthis);
    ve->type = type;
    return ve;
}

Expression *DeclarationExp::doInline(InlineDoState *ids)
{
    //printf("DeclarationExp::doInline(%s)\n", toChars());
    VarDeclaration *vd = declaration->isVarDeclaration();
    if (vd)
    {
#if 0
        // Need to figure this out before inlining can work for tuples
        TupleDeclaration *td = vd->toAlias()->isTupleDeclaration();
        if (td)
        {
            for (size_t i = 0; i < td->objects->dim; i++)
            {   DsymbolExp *se = (*td->objects)[i];
                assert(se->op == TOKdsymbol);
                se->s;
            }
            return st->objects->dim;
        }
#endif
        if (vd->isStatic())
            ;
        else
        {
            VarDeclaration *vto;
            if (ids->fd && vd == ids->fd->nrvo_var)
            {
                for (size_t i = 0; i < ids->from.dim; i++)
                {
                    if (vd == ids->from[i])
                    {
                        vto = (VarDeclaration *)ids->to[i];
                        if ((vd->storage_class & STCref) == 0 &&
                            (vto->storage_class & STCref))
                        {
                            Expression *e;
                            if (vd->init && !vd->init->isVoidInitializer())
                            {
                                e = vd->init->toExpression();
                                assert(e);
                                e = e->doInline(ids);
                            }
                            else
                                e = new IntegerExp(vd->init->loc, 0, Type::tint32);
                            return e;
                        }
                        goto L1;
                    }
                }
            }
            vto = new VarDeclaration(vd->loc, vd->type, vd->ident, vd->init);
            memcpy((void *)vto, (void *)vd, sizeof(VarDeclaration));
            vto->parent = ids->parent;
            vto->csym = NULL;
            vto->isym = NULL;

            ids->from.push(vd);
            ids->to.push(vto);

        L1:
            if (vd->init)
            {
                if (vd->init->isVoidInitializer())
                {
                    vto->init = new VoidInitializer(vd->init->loc);
                }
                else
                {
                    Expression *e = vd->init->toExpression();
                    assert(e);
                    vto->init = new ExpInitializer(e->loc, e->doInline(ids));
                }
            }
            DeclarationExp *de = (DeclarationExp *)copy();
            de->declaration = (Dsymbol *) (void *)vto;
            return de;
        }
    }
    /* This needs work, like DeclarationExp::toElem(), if we are
     * to handle TemplateMixin's. For now, we just don't inline them.
     */
    return Expression::doInline(ids);
}

Expression *NewExp::doInline(InlineDoState *ids)
{
    //printf("NewExp::doInline(): %s\n", toChars());
    NewExp *ne = (NewExp *)copy();

    if (thisexp)
        ne->thisexp = thisexp->doInline(ids);
    ne->newargs = arrayExpressiondoInline(ne->newargs, ids);
    ne->arguments = arrayExpressiondoInline(ne->arguments, ids);
    return ne;
}

Expression *UnaExp::doInline(InlineDoState *ids)
{
    UnaExp *ue = (UnaExp *)copy();

    ue->e1 = e1->doInline(ids);
    return ue;
}

Expression *AssertExp::doInline(InlineDoState *ids)
{
    AssertExp *ae = (AssertExp *)copy();

    ae->e1 = e1->doInline(ids);
    if (msg)
        ae->msg = msg->doInline(ids);
    return ae;
}

Expression *BinExp::doInline(InlineDoState *ids)
{
    BinExp *be = (BinExp *)copy();

    be->e1 = e1->doInline(ids);
    be->e2 = e2->doInline(ids);
    return be;
}

Expression *CallExp::doInline(InlineDoState *ids)
{
    CallExp *ce;

    ce = (CallExp *)copy();
    ce->e1 = e1->doInline(ids);
    ce->arguments = arrayExpressiondoInline(arguments, ids);
    return ce;
}


Expression *IndexExp::doInline(InlineDoState *ids)
{
    IndexExp *are = (IndexExp *)copy();

    are->e1 = e1->doInline(ids);

    if (lengthVar)
    {   //printf("lengthVar\n");
        VarDeclaration *vd = lengthVar;
        ExpInitializer *ie;
        ExpInitializer *ieto;
        VarDeclaration *vto;

        vto = new VarDeclaration(vd->loc, vd->type, vd->ident, vd->init);
        memcpy((void*)vto, (void*)vd, sizeof(VarDeclaration));
        vto->parent = ids->parent;
        vto->csym = NULL;
        vto->isym = NULL;

        ids->from.push(vd);
        ids->to.push(vto);

        if (vd->init && !vd->init->isVoidInitializer())
        {
            ie = vd->init->isExpInitializer();
            assert(ie);
            ieto = new ExpInitializer(ie->loc, ie->exp->doInline(ids));
            vto->init = ieto;
        }

        are->lengthVar = (VarDeclaration *) (void *)vto;
    }
    are->e2 = e2->doInline(ids);
    return are;
}


Expression *SliceExp::doInline(InlineDoState *ids)
{
    SliceExp *are = (SliceExp *)copy();

    are->e1 = e1->doInline(ids);

    if (lengthVar)
    {   //printf("lengthVar\n");
        VarDeclaration *vd = lengthVar;
        ExpInitializer *ie;
        ExpInitializer *ieto;
        VarDeclaration *vto;

        vto = new VarDeclaration(vd->loc, vd->type, vd->ident, vd->init);
        memcpy((void*)vto, (void*)vd, sizeof(VarDeclaration));
        vto->parent = ids->parent;
        vto->csym = NULL;
        vto->isym = NULL;

        ids->from.push(vd);
        ids->to.push(vto);

        if (vd->init && !vd->init->isVoidInitializer())
        {
            ie = vd->init->isExpInitializer();
            assert(ie);
            ieto = new ExpInitializer(ie->loc, ie->exp->doInline(ids));
            vto->init = ieto;
        }

        are->lengthVar = (VarDeclaration *) (void *)vto;
    }
    if (lwr)
        are->lwr = lwr->doInline(ids);
    if (upr)
        are->upr = upr->doInline(ids);
    return are;
}


Expression *TupleExp::doInline(InlineDoState *ids)
{
    TupleExp *ce;

    ce = (TupleExp *)copy();
    if (e0)
        ce->e0 = e0->doInline(ids);
    ce->exps = arrayExpressiondoInline(exps, ids);
    return ce;
}


Expression *ArrayLiteralExp::doInline(InlineDoState *ids)
{
    ArrayLiteralExp *ce;

    ce = (ArrayLiteralExp *)copy();
    ce->elements = arrayExpressiondoInline(elements, ids);
    return ce;
}


Expression *AssocArrayLiteralExp::doInline(InlineDoState *ids)
{
    AssocArrayLiteralExp *ce;

    ce = (AssocArrayLiteralExp *)copy();
    ce->keys = arrayExpressiondoInline(keys, ids);
    ce->values = arrayExpressiondoInline(values, ids);
    return ce;
}


Expression *StructLiteralExp::doInline(InlineDoState *ids)
{
    if(inlinecopy) return inlinecopy;
    StructLiteralExp *ce;
    ce = (StructLiteralExp *)copy();
    inlinecopy = ce;
    ce->elements = arrayExpressiondoInline(elements, ids);
    inlinecopy = NULL;
    return ce;
}


Expression *ArrayExp::doInline(InlineDoState *ids)
{
    ArrayExp *ce;

    ce = (ArrayExp *)copy();
    ce->e1 = e1->doInline(ids);
    ce->arguments = arrayExpressiondoInline(arguments, ids);
    return ce;
}


Expression *CondExp::doInline(InlineDoState *ids)
{
    CondExp *ce = (CondExp *)copy();

    ce->econd = econd->doInline(ids);
    ce->e1 = e1->doInline(ids);
    ce->e2 = e2->doInline(ids);
    return ce;
}


/* ========== Walk the parse trees, and inline expand functions ============= */

/* Walk the trees, looking for functions to inline.
 * Inline any that can be.
 */

struct InlineScanState
{
    FuncDeclaration *fd;        // function being scanned
};

Statement *Statement::inlineScan(InlineScanState *iss)
{
    return this;
}

Statement *ExpStatement::inlineScan(InlineScanState *iss)
{
#if LOG
    printf("ExpStatement::inlineScan(%s)\n", toChars());
#endif
    if (exp)
    {
        exp = exp->inlineScan(iss);

        /* See if we can inline as a statement rather than as
         * an Expression.
         */
        if (exp && exp->op == TOKcall)
        {
            CallExp *ce = (CallExp *)exp;
            if (ce->e1->op == TOKvar)
            {
                VarExp *ve = (VarExp *)ce->e1;
                FuncDeclaration *fd = ve->var->isFuncDeclaration();

                if (fd && fd != iss->fd && fd->canInline(0, 0, 1))
                {
                    Statement *s;
                    fd->expandInline(iss, NULL, NULL, ce->arguments, &s);
                    return s;
                }
            }
        }
    }
    return this;
}

Statement *CompoundStatement::inlineScan(InlineScanState *iss)
{
    for (size_t i = 0; i < statements->dim; i++)
    {   Statement *s =  (*statements)[i];
        if (s)
            (*statements)[i] = s->inlineScan(iss);
    }
    return this;
}

Statement *UnrolledLoopStatement::inlineScan(InlineScanState *iss)
{
    for (size_t i = 0; i < statements->dim; i++)
    {   Statement *s =  (*statements)[i];
        if (s)
            (*statements)[i] = s->inlineScan(iss);
    }
    return this;
}

Statement *ScopeStatement::inlineScan(InlineScanState *iss)
{
    if (statement)
        statement = statement->inlineScan(iss);
    return this;
}

Statement *WhileStatement::inlineScan(InlineScanState *iss)
{
    condition = condition->inlineScan(iss);
    body = body ? body->inlineScan(iss) : NULL;
    return this;
}


Statement *DoStatement::inlineScan(InlineScanState *iss)
{
    body = body ? body->inlineScan(iss) : NULL;
    condition = condition->inlineScan(iss);
    return this;
}


Statement *ForStatement::inlineScan(InlineScanState *iss)
{
    if (init)
        init = init->inlineScan(iss);
    if (condition)
        condition = condition->inlineScan(iss);
    if (increment)
        increment = increment->inlineScan(iss);
    if (body)
        body = body->inlineScan(iss);
    return this;
}


Statement *ForeachStatement::inlineScan(InlineScanState *iss)
{
    aggr = aggr->inlineScan(iss);
    if (body)
        body = body->inlineScan(iss);
    return this;
}


Statement *ForeachRangeStatement::inlineScan(InlineScanState *iss)
{
    lwr = lwr->inlineScan(iss);
    upr = upr->inlineScan(iss);
    if (body)
        body = body->inlineScan(iss);
    return this;
}


Statement *IfStatement::inlineScan(InlineScanState *iss)
{
    condition = condition->inlineScan(iss);
    if (ifbody)
        ifbody = ifbody->inlineScan(iss);
    if (elsebody)
        elsebody = elsebody->inlineScan(iss);
    return this;
}


Statement *SwitchStatement::inlineScan(InlineScanState *iss)
{
    //printf("SwitchStatement::inlineScan()\n");
    condition = condition->inlineScan(iss);
    body = body ? body->inlineScan(iss) : NULL;
    if (sdefault)
        sdefault = (DefaultStatement *)sdefault->inlineScan(iss);
    if (cases)
    {
        for (size_t i = 0; i < cases->dim; i++)
        {   CaseStatement *s;

            s =  (*cases)[i];
            (*cases)[i] = (CaseStatement *)s->inlineScan(iss);
        }
    }
    return this;
}


Statement *CaseStatement::inlineScan(InlineScanState *iss)
{
    //printf("CaseStatement::inlineScan()\n");
    exp = exp->inlineScan(iss);
    if (statement)
        statement = statement->inlineScan(iss);
    return this;
}


Statement *DefaultStatement::inlineScan(InlineScanState *iss)
{
    if (statement)
        statement = statement->inlineScan(iss);
    return this;
}


Statement *ReturnStatement::inlineScan(InlineScanState *iss)
{
    //printf("ReturnStatement::inlineScan()\n");
    if (exp)
        exp = exp->inlineScan(iss);
    return this;
}


Statement *SynchronizedStatement::inlineScan(InlineScanState *iss)
{
    if (exp)
        exp = exp->inlineScan(iss);
    if (body)
        body = body->inlineScan(iss);
    return this;
}


Statement *WithStatement::inlineScan(InlineScanState *iss)
{
    if (exp)
        exp = exp->inlineScan(iss);
    if (body)
        body = body->inlineScan(iss);
    return this;
}


Statement *TryCatchStatement::inlineScan(InlineScanState *iss)
{
    if (body)
        body = body->inlineScan(iss);
    if (catches)
    {
        for (size_t i = 0; i < catches->dim; i++)
        {   Catch *c = (*catches)[i];

            if (c->handler)
                c->handler = c->handler->inlineScan(iss);
        }
    }
    return this;
}


Statement *TryFinallyStatement::inlineScan(InlineScanState *iss)
{
    if (body)
        body = body->inlineScan(iss);
    if (finalbody)
        finalbody = finalbody->inlineScan(iss);
    return this;
}


Statement *ThrowStatement::inlineScan(InlineScanState *iss)
{
    if (exp)
        exp = exp->inlineScan(iss);
    return this;
}


Statement *LabelStatement::inlineScan(InlineScanState *iss)
{
    if (statement)
        statement = statement->inlineScan(iss);
    return this;
}

/* -------------------------- */

void arrayInlineScan(InlineScanState *iss, Expressions *arguments)
{
    if (arguments)
    {
        for (size_t i = 0; i < arguments->dim; i++)
        {   Expression *e = (*arguments)[i];

            if (e)
            {
                e = e->inlineScan(iss);
                (*arguments)[i] = e;
            }
        }
    }
}

Expression *Expression::inlineScan(InlineScanState *iss)
{
    return this;
}

Expression *scanVar(Dsymbol *s, InlineScanState *iss)
{
    //printf("scanVar(%s %s)\n", s->kind(), s->toPrettyChars());
    VarDeclaration *vd = s->isVarDeclaration();
    if (vd)
    {
        TupleDeclaration *td = vd->toAlias()->isTupleDeclaration();
        if (td)
        {
            for (size_t i = 0; i < td->objects->dim; i++)
            {
                DsymbolExp *se = (DsymbolExp *)(*td->objects)[i];
                assert(se->op == TOKdsymbol);
                scanVar(se->s, iss);    // TODO
            }
        }
        else if (vd->init)
        {
            if (ExpInitializer *ie = vd->init->isExpInitializer())
            {
                Expression *e = ie->exp->inlineScan(iss);
                if (vd->init != ie)     // DeclareExp with vd appears in e
                    return e;
                ie->exp = e;
            }
        }
    }
    else
    {
        s->inlineScan();
    }
    return NULL;
}

Expression *DeclarationExp::inlineScan(InlineScanState *iss)
{
    //printf("DeclarationExp::inlineScan()\n");
    Expression *e = scanVar(declaration, iss);
    return e ? e : this;
}

Expression *UnaExp::inlineScan(InlineScanState *iss)
{
    e1 = e1->inlineScan(iss);
    return this;
}

Expression *AssertExp::inlineScan(InlineScanState *iss)
{
    e1 = e1->inlineScan(iss);
    if (msg)
        msg = msg->inlineScan(iss);
    return this;
}

Expression *BinExp::inlineScan(InlineScanState *iss)
{
    e1 = e1->inlineScan(iss);
    e2 = e2->inlineScan(iss);
    return this;
}

Expression *AssignExp::inlineScan(InlineScanState *iss)
{
    if (op == TOKconstruct && e2->op == TOKcall)
    {
        CallExp *ce = (CallExp *)e2;
        if (ce->f && ce->f->nrvo_var)   // NRVO
        {
            if (e1->op == TOKvar)
            {
                /* Inlining:
                 *   S s = foo();   // initializing by rvalue
                 *   S s = S(1);    // constrcutor call
                 */
                Declaration *d = ((VarExp *)e1)->var;
                if (d->storage_class & (STCout | STCref))  // refinit
                    goto L1;
            }
            else
            {
                /* Inlining:
                 *   this.field = foo();   // inside constructor
                 */
                e1 = e1->inlineScan(iss);
            }

            Expression *e = ce->inlineScan(iss, e1);
            if (e != ce)
            {
                //printf("call with nrvo: %s ==> %s\n", toChars(), e->toChars());
                return e;
            }
        }
    }
L1:
    return BinExp::inlineScan(iss);
}

Expression *CallExp::inlineScan(InlineScanState *iss)
{
    return inlineScan(iss, NULL);
}

Expression *CallExp::inlineScan(InlineScanState *iss, Expression *eret)
{
    Expression *e = this;

    //printf("CallExp::inlineScan()\n");
    e1 = e1->inlineScan(iss);
    arrayInlineScan(iss, arguments);

    if (e1->op == TOKvar)
    {
        VarExp *ve = (VarExp *)e1;
        FuncDeclaration *fd = ve->var->isFuncDeclaration();

        if (fd && fd != iss->fd && fd->canInline(0, 0, 0))
        {
            e = fd->expandInline(iss, eret, NULL, arguments, NULL);
        }
    }
    else if (e1->op == TOKdotvar)
    {
        DotVarExp *dve = (DotVarExp *)e1;
        FuncDeclaration *fd = dve->var->isFuncDeclaration();

        if (fd && fd != iss->fd && fd->canInline(1, 0, 0))
        {
            if (dve->e1->op == TOKcall &&
                dve->e1->type->toBasetype()->ty == Tstruct)
            {
                /* To create ethis, we'll need to take the address
                 * of dve->e1, but this won't work if dve->e1 is
                 * a function call.
                 */
                ;
            }
            else
                e = fd->expandInline(iss, eret, dve->e1, arguments, NULL);
        }
    }

    if (e && type->ty != Tvoid)
        e->type = type;
    return e;
}


Expression *SliceExp::inlineScan(InlineScanState *iss)
{
    e1 = e1->inlineScan(iss);
    if (lwr)
        lwr = lwr->inlineScan(iss);
    if (upr)
        upr = upr->inlineScan(iss);
    return this;
}


Expression *TupleExp::inlineScan(InlineScanState *iss)
{   Expression *e = this;

    //printf("TupleExp::inlineScan()\n");
    if (e0)
        e0->inlineScan(iss);
    arrayInlineScan(iss, exps);

    return e;
}


Expression *ArrayLiteralExp::inlineScan(InlineScanState *iss)
{   Expression *e = this;

    //printf("ArrayLiteralExp::inlineScan()\n");
    arrayInlineScan(iss, elements);

    return e;
}


Expression *AssocArrayLiteralExp::inlineScan(InlineScanState *iss)
{   Expression *e = this;

    //printf("AssocArrayLiteralExp::inlineScan()\n");
    arrayInlineScan(iss, keys);
    arrayInlineScan(iss, values);

    return e;
}


Expression *StructLiteralExp::inlineScan(InlineScanState *iss)
{   Expression *e = this;

    //printf("StructLiteralExp::inlineScan()\n");
    if(stageflags & stageInlineScan) return e;
    int old = stageflags;
    stageflags |= stageInlineScan;
    arrayInlineScan(iss, elements);
    stageflags = old;
    return e;
}


Expression *ArrayExp::inlineScan(InlineScanState *iss)
{   Expression *e = this;

    //printf("ArrayExp::inlineScan()\n");
    e1 = e1->inlineScan(iss);
    arrayInlineScan(iss, arguments);

    return e;
}


Expression *CondExp::inlineScan(InlineScanState *iss)
{
    econd = econd->inlineScan(iss);
    e1 = e1->inlineScan(iss);
    e2 = e2->inlineScan(iss);
    return this;
}


/* ==========  =============== */

void FuncDeclaration::inlineScan()
{
    InlineScanState iss;

#if LOG
    printf("FuncDeclaration::inlineScan('%s')\n", toPrettyChars());
#endif
    memset(&iss, 0, sizeof(iss));
    iss.fd = this;
    if (fbody && !naked)
    {
        inlineNest++;
        fbody = fbody->inlineScan(&iss);
        inlineNest--;
    }
}

int FuncDeclaration::canInline(int hasthis, int hdrscan, int statementsToo)
{
    InlineCostState ics;
    int cost;

#define CANINLINE_LOG 0

#if CANINLINE_LOG
    printf("FuncDeclaration::canInline(hasthis = %d, statementsToo = %d, '%s')\n", hasthis, statementsToo, toPrettyChars());
#endif

    if (needThis() && !hasthis)
        return 0;

    if (inlineNest || (semanticRun < PASSsemantic3 && !hdrscan))
    {
#if CANINLINE_LOG
        printf("\t1: no, inlineNest = %d, semanticRun = %d\n", inlineNest, semanticRun);
#endif
        return 0;
    }

#if 1
    switch (statementsToo ? inlineStatusStmt : inlineStatusExp)
    {
        case ILSyes:
#if CANINLINE_LOG
            printf("\t1: yes %s\n", toChars());
#endif
            return 1;

        case ILSno:
#if CANINLINE_LOG
            printf("\t1: no %s\n", toChars());
#endif
            return 0;

        case ILSuninitialized:
            break;

        default:
            assert(0);
    }
#endif

    if (type)
    {   assert(type->ty == Tfunction);
        TypeFunction *tf = (TypeFunction *)type;
        if (tf->varargs == 1)   // no variadic parameter lists
            goto Lno;

        /* Don't inline a function that returns non-void, but has
         * no return expression.
         * No statement inlining for non-voids.
         */
        if (tf->next && tf->next->ty != Tvoid &&
            (!(hasReturnExp & 1) || statementsToo) &&
            !hdrscan)
            goto Lno;
    }

    // cannot inline constructor calls because we need to convert:
    //      return;
    // to:
    //      return this;
    if (
        !fbody ||
        ident == Id::ensure ||  // ensure() has magic properties the inliner loses
        (ident == Id::require &&             // require() has magic properties too
         toParent()->isFuncDeclaration() &&  // see bug 7699
         toParent()->isFuncDeclaration()->needThis()) ||
        !hdrscan &&
        (
        isSynchronized() ||
        isImportedSymbol() ||
        hasNestedFrameRefs() ||      // no nested references to this frame
        (isVirtual() && !isFinalFunc())
       ))
    {
        goto Lno;
    }

#if 0
    /* If any parameters are Tsarray's (which are passed by reference)
     * or out parameters (also passed by reference), don't do inlining.
     */
    if (parameters)
    {
        for (size_t i = 0; i < parameters->dim; i++)
        {
            VarDeclaration *v = (*parameters)[i];
            if (v->type->toBasetype()->ty == Tsarray)
                goto Lno;
        }
    }
#endif

    memset(&ics, 0, sizeof(ics));
    ics.hasthis = hasthis;
    ics.fd = this;
    ics.hdrscan = hdrscan;
    cost = fbody->inlineCost(&ics);
#if CANINLINE_LOG
    printf("cost = %d for %s\n", cost, toChars());
#endif
    if (tooCostly(cost))
        goto Lno;
    if (!statementsToo && cost > COST_MAX)
        goto Lno;

    if (!hdrscan)
    {
        // Don't modify inlineStatus for header content scan
        if (statementsToo)
            inlineStatusStmt = ILSyes;
        else
            inlineStatusExp = ILSyes;

        inlineScan();    // Don't scan recursively for header content scan

        if (inlineStatusExp == ILSuninitialized)
        {
            // Need to redo cost computation, as some statements or expressions have been inlined
            memset(&ics, 0, sizeof(ics));
            ics.hasthis = hasthis;
            ics.fd = this;
            ics.hdrscan = hdrscan;
            cost = fbody->inlineCost(&ics);
        #if CANINLINE_LOG
            printf("recomputed cost = %d for %s\n", cost, toChars());
        #endif
            if (tooCostly(cost))
                goto Lno;
            if (!statementsToo && cost > COST_MAX)
                goto Lno;

            if (statementsToo)
                inlineStatusStmt = ILSyes;
            else
                inlineStatusExp = ILSyes;
        }
    }
#if CANINLINE_LOG
    printf("\t2: yes %s\n", toChars());
#endif
    return 1;

Lno:
    if (!hdrscan)    // Don't modify inlineStatus for header content scan
    {   if (statementsToo)
            inlineStatusStmt = ILSno;
        else
            inlineStatusExp = ILSno;
    }
#if CANINLINE_LOG
    printf("\t2: no %s\n", toChars());
#endif
    return 0;
}

Expression *FuncDeclaration::expandInline(InlineScanState *iss,
        Expression *eret, Expression *ethis, Expressions *arguments, Statement **ps)
{
    InlineDoState ids;
    Expression *e = NULL;
    Statements *as = NULL;
    TypeFunction *tf = (TypeFunction*)type;

#if LOG || CANINLINE_LOG
    printf("FuncDeclaration::expandInline('%s')\n", toChars());
#endif

    memset(&ids, 0, sizeof(ids));
    ids.parent = iss->fd;
    ids.fd = this;

    if (ps)
        as = new Statements();

    VarDeclaration *vret = NULL;
    if (eret)
    {
        if (eret->op == TOKvar)
        {
            vret = ((VarExp *)eret)->var->isVarDeclaration();
            assert(!(vret->storage_class & (STCout | STCref)));
        }
        else
        {
            /* Inlining:
             *   this.field = foo();   // inside constructor
             */
            vret = new VarDeclaration(loc, eret->type, Lexer::uniqueId("_satmp"), NULL);
            vret->storage_class |= STCtemp | STCforeach | STCref;
            vret->linkage = LINKd;
            vret->parent = iss->fd;

            Expression *de;
            de = new DeclarationExp(loc, vret);
            de->type = Type::tvoid;
            e = Expression::combine(e, de);

            Expression *ex;
            ex = new VarExp(loc, vret);
            ex->type = vret->type;
            ex = new ConstructExp(loc, ex, eret);
            ex->type = vret->type;
            e = Expression::combine(e, ex);
        }
    }

    // Set up vthis
    if (ethis)
    {
        VarDeclaration *vthis;
        ExpInitializer *ei;
        VarExp *ve;

        if (ethis->type->ty == Tpointer)
        {   Type *t = ethis->type->nextOf();
            ethis = new PtrExp(ethis->loc, ethis);
            ethis->type = t;
        }
        ei = new ExpInitializer(ethis->loc, ethis);

        vthis = new VarDeclaration(ethis->loc, ethis->type, Id::This, ei);
        if (ethis->type->ty != Tclass)
            vthis->storage_class = STCref;
        else
            vthis->storage_class = STCin;
        vthis->linkage = LINKd;
        vthis->parent = iss->fd;

        ve = new VarExp(vthis->loc, vthis);
        ve->type = vthis->type;

        ei->exp = new AssignExp(vthis->loc, ve, ethis);
        ei->exp->type = ve->type;
        if (ethis->type->ty != Tclass)
        {   /* This is a reference initialization, not a simple assignment.
             */
            ei->exp->op = TOKconstruct;
        }

        ids.vthis = vthis;
    }

    // Set up parameters
    if (ethis)
    {
        Expression *de = new DeclarationExp(Loc(), ids.vthis);
        de->type = Type::tvoid;
        e = Expression::combine(e, de);
    }

    if (!ps && nrvo_var)
    {
        if (vret)
        {
            ids.from.push(nrvo_var);
            ids.to.push(vret);
        }
        else
        {
            Identifier* tmp = Identifier::generateId("__nrvoretval");
            VarDeclaration* vd = new VarDeclaration(loc, nrvo_var->type, tmp, NULL);
            assert(!tf->isref);
            vd->storage_class = STCtemp | STCrvalue;
            vd->linkage = tf->linkage;
            vd->parent = iss->fd;

            ids.from.push(nrvo_var);
            ids.to.push(vd);
        }
    }
    if (arguments && arguments->dim)
    {
        assert(parameters->dim == arguments->dim);

        for (size_t i = 0; i < arguments->dim; i++)
        {
            VarDeclaration *vfrom = (*parameters)[i];
            VarDeclaration *vto;
            Expression *arg = (*arguments)[i];
            ExpInitializer *ei;
            VarExp *ve;

            ei = new ExpInitializer(arg->loc, arg);

            vto = new VarDeclaration(vfrom->loc, vfrom->type, vfrom->ident, ei);
            vto->storage_class |= vfrom->storage_class & (STCtemp | STCin | STCout | STClazy | STCref);
            vto->linkage = vfrom->linkage;
            vto->parent = iss->fd;
            //printf("vto = '%s', vto->storage_class = x%x\n", vto->toChars(), vto->storage_class);
            //printf("vto->parent = '%s'\n", iss->fd->toChars());

            ve = new VarExp(vto->loc, vto);
            //ve->type = vto->type;
            ve->type = arg->type;

            ei->exp = new ConstructExp(vto->loc, ve, arg);
            ei->exp->type = ve->type;
            //ve->type->print();
            //arg->type->print();
            //ei->exp->print();

            ids.from.push(vfrom);
            ids.to.push(vto);

            DeclarationExp *de = new DeclarationExp(Loc(), vto);
            de->type = Type::tvoid;

            e = Expression::combine(e, de);
        }
    }

    if (ps)
    {
        if (e)
            as->push(new ExpStatement(Loc(), e));
        inlineNest++;
        Statement *s = fbody->doInlineStatement(&ids);
        as->push(s);
        *ps = new ScopeStatement(Loc(), new CompoundStatement(Loc(), as));
        inlineNest--;
    }
    else
    {
        inlineNest++;
        Expression *eb = fbody->doInline(&ids);
        e = Expression::combine(e, eb);
        inlineNest--;
        //eb->type->print();
        //eb->print();
        //eb->dump(0);

        // Bugzilla 11322:
        if (tf->isref)
            e = e->toLvalue(NULL, NULL);

        /* There's a problem if what the function returns is used subsequently as an
         * lvalue, as in a struct return that is then used as a 'this'.
         * If we take the address of the return value, we will be taking the address
         * of the original, not the copy. Fix this by assigning the return value to
         * a temporary, then returning the temporary. If the temporary is used as an
         * lvalue, it will work.
         * This only happens with struct returns.
         * See Bugzilla 2127 for an example.
         *
         * On constructor call making __inlineretval is merely redundant, because
         * the returned reference is exactly same as vthis, and the 'this' variable
         * already exists at the caller side.
         */
        if (tf->next->ty == Tstruct && !nrvo_var && !isCtorDeclaration())
        {
            /* Generate a new variable to hold the result and initialize it with the
             * inlined body of the function:
             *   tret __inlineretval = e;
             */
            ExpInitializer* ei = new ExpInitializer(loc, e);

            Identifier* tmp = Identifier::generateId("__inlineretval");
            VarDeclaration* vd = new VarDeclaration(loc, tf->next, tmp, ei);
            vd->storage_class = (tf->isref ? STCref : 0) | STCtemp | STCrvalue;
            vd->linkage = tf->linkage;
            vd->parent = iss->fd;

            VarExp *ve = new VarExp(loc, vd);
            ve->type = tf->next;

            ei->exp = new ConstructExp(loc, ve, e);
            ei->exp->type = ve->type;

            DeclarationExp* de = new DeclarationExp(Loc(), vd);
            de->type = Type::tvoid;

            // Chain the two together:
            //   ( typeof(return) __inlineretval = ( inlined body )) , __inlineretval
            e = Expression::combine(de, ve);

            //fprintf(stderr, "CallExp::inlineScan: e = "); e->print();
        }
    }
    //printf("%s->expandInline = { %s }\n", toChars(), e->toChars());

    // Need to reevaluate whether parent can now be inlined
    // in expressions, as we might have inlined statements
    iss->fd->inlineStatusExp = ILSuninitialized;
    return e;
}

void UnitTestDeclaration::inlineScan()
{
    if (global.params.useUnitTests)
    {
        FuncDeclaration::inlineScan();
    }
}

/****************************************************
 * Perform the "inline copying" of a default argument for a function parameter.
 */

Expression *Expression::inlineCopy(Scope *sc)
{
#if 0
    /* See Bugzilla 2935 for explanation of why just a copy() is broken
     */
    return copy();
#else
    if (op == TOKdelegate)
    {   DelegateExp *de = (DelegateExp *)this;

        if (de->func->isNested())
        {   /* See Bugzilla 4820
             * Defer checking until later if we actually need the 'this' pointer
             */
            Expression *e = de->copy();
            return e;
        }
    }

    InlineCostState ics;

    memset(&ics, 0, sizeof(ics));
    ics.hdrscan = 1;                    // so DeclarationExp:: will work on 'statics' which are not
    int cost = expressionInlineCost(this, &ics);
    if (cost >= COST_MAX)
    {   error("cannot inline default argument %s", toChars());
        return new ErrorExp();
    }
    InlineDoState ids;
    memset(&ids, 0, sizeof(ids));
    ids.parent = sc->parent;
    Expression *e = doInline(&ids);
    return e;
#endif
}

