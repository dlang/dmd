
// Copyright (c) 1999-2011 by Digital Mars
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

int Statement::inlineCost(InlineCostState *ics)
{
    return COST_MAX;            // default is we can't inline it
}

int ExpStatement::inlineCost(InlineCostState *ics)
{
    return exp ? exp->inlineCost(ics) : 0;
}

int CompoundStatement::inlineCost(InlineCostState *ics)
{   int cost = 0;

    for (size_t i = 0; i < statements->dim; i++)
    {   Statement *s =  statements->tdata()[i];
        if (s)
        {
            cost += s->inlineCost(ics);
            if (cost >= COST_MAX)
                break;
        }
    }
    return cost;
}

int UnrolledLoopStatement::inlineCost(InlineCostState *ics)
{   int cost = 0;

    for (size_t i = 0; i < statements->dim; i++)
    {   Statement *s =  statements->tdata()[i];
        if (s)
        {
            cost += s->inlineCost(ics);
            if (cost >= COST_MAX)
                break;
        }
    }
    return cost;
}

int IfStatement::inlineCost(InlineCostState *ics)
{
    int cost;

    /* Can't declare variables inside ?: expressions, so
     * we cannot inline if a variable is declared.
     */
    if (arg)
        return COST_MAX;

    cost = condition->inlineCost(ics);

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
    return cost;
}

int ReturnStatement::inlineCost(InlineCostState *ics)
{
    // Can't handle return statements nested in if's
    if (ics->nested)
        return COST_MAX;
    return exp ? exp->inlineCost(ics) : 0;
}

int ImportStatement::inlineCost(InlineCostState *ics)
{
    return 0;
}

/* -------------------------- */

int arrayInlineCost(InlineCostState *ics, Expressions *arguments)
{   int cost = 0;

    if (arguments)
    {
        for (size_t i = 0; i < arguments->dim; i++)
        {   Expression *e = arguments->tdata()[i];

            if (e)
                cost += e->inlineCost(ics);
        }
    }
    return cost;
}

int Expression::inlineCost(InlineCostState *ics)
{
    return 1;
}

int VarExp::inlineCost(InlineCostState *ics)
{
    //printf("VarExp::inlineCost() %s\n", toChars());
    return 1;
}

int ThisExp::inlineCost(InlineCostState *ics)
{
    //printf("ThisExp::inlineCost() %s\n", toChars());
    FuncDeclaration *fd = ics->fd;
    if (!fd)
        return COST_MAX;
    if (!ics->hdrscan)
        if (fd->isNested() || !ics->hasthis)
            return COST_MAX;
    return 1;
}

int SuperExp::inlineCost(InlineCostState *ics)
{
    FuncDeclaration *fd = ics->fd;
    if (!fd)
        return COST_MAX;
    if (!ics->hdrscan)
        if (fd->isNested() || !ics->hasthis)
            return COST_MAX;
    return 1;
}

int TupleExp::inlineCost(InlineCostState *ics)
{
    return 1 + arrayInlineCost(ics, exps);
}

int ArrayLiteralExp::inlineCost(InlineCostState *ics)
{
    return 1 + arrayInlineCost(ics, elements);
}

int AssocArrayLiteralExp::inlineCost(InlineCostState *ics)
{
    return 1 + arrayInlineCost(ics, keys) + arrayInlineCost(ics, values);
}

int StructLiteralExp::inlineCost(InlineCostState *ics)
{
    return 1 + arrayInlineCost(ics, elements);
}

int FuncExp::inlineCost(InlineCostState *ics)
{
    //printf("FuncExp::inlineCost()\n");
    // Right now, this makes the function be output to the .obj file twice.
    return COST_MAX;
}

int DelegateExp::inlineCost(InlineCostState *ics)
{
    return COST_MAX;
}

int DeclarationExp::inlineCost(InlineCostState *ics)
{   int cost = 0;
    VarDeclaration *vd;

    //printf("DeclarationExp::inlineCost()\n");
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
            {   Object *o = td->objects->tdata()[i];
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
                cost += ie->exp->inlineCost(ics);
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

    //printf("DeclarationExp::inlineCost('%s')\n", toChars());
    return cost;
}

int UnaExp::inlineCost(InlineCostState *ics)
{
    return 1 + e1->inlineCost(ics);
}

int AssertExp::inlineCost(InlineCostState *ics)
{
    return 1 + e1->inlineCost(ics) + (msg ? msg->inlineCost(ics) : 0);
}

int BinExp::inlineCost(InlineCostState *ics)
{
    return 1 + e1->inlineCost(ics) + e2->inlineCost(ics);
}

int CallExp::inlineCost(InlineCostState *ics)
{
    // Bugzilla 3500: super.func() calls must be devirtualized, and the inliner
    // can't handle that at present.
    if (e1->op == TOKdotvar && ((DotVarExp *)e1)->e1->op == TOKsuper)
        return COST_MAX;

    return 1 + e1->inlineCost(ics) + arrayInlineCost(ics, arguments);
}

int SliceExp::inlineCost(InlineCostState *ics)
{   int cost;

    cost = 1 + e1->inlineCost(ics);
    if (lwr)
        cost += lwr->inlineCost(ics);
    if (upr)
        cost += upr->inlineCost(ics);
    return cost;
}

int ArrayExp::inlineCost(InlineCostState *ics)
{
    return 1 + e1->inlineCost(ics) + arrayInlineCost(ics, arguments);
}


int CondExp::inlineCost(InlineCostState *ics)
{
    return 1 +
         e1->inlineCost(ics) +
         e2->inlineCost(ics) +
         econd->inlineCost(ics);
}


/* ======================== Perform the inlining ============================== */

/* Inlining is done by:
 * o    Converting to an Expression
 * o    Copying the trees of the function to be inlined
 * o    Renaming the variables
 */

struct InlineDoState
{
    VarDeclaration *vthis;
    Dsymbols from;      // old Dsymbols
    Dsymbols to;        // parallel array of new Dsymbols
    Dsymbol *parent;    // new parent
};

Expression *Statement::doInline(InlineDoState *ids)
{
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
    {   Statement *s =  statements->tdata()[i];
        if (s)
        {
            Expression *e2 = s->doInline(ids);
            e = Expression::combine(e, e2);
            if (s->isReturnStatement())
                break;

            /* Check for:
             *  if (condition)
             *      return exp1;
             *  else
             *      return exp2;
             */
            IfStatement *ifs = s->isIfStatement();
            if (ifs && ifs->elsebody && ifs->ifbody &&
                ifs->ifbody->isReturnStatement() &&
                ifs->elsebody->isReturnStatement()
               )
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
    {   Statement *s =  statements->tdata()[i];
        if (s)
        {
            Expression *e2 = s->doInline(ids);
            e = Expression::combine(e, e2);
            if (s->isReturnStatement())
                break;
        }
    }
    return e;
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
        e1 = ifbody->doInline(ids);
    else
        e1 = NULL;
    if (elsebody)
        e2 = elsebody->doInline(ids);
    else
        e2 = NULL;
    if (e1 && e2)
    {
        e = new CondExp(econd->loc, econd, e1, e2);
        e->type = e1->type;
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
    return e;
}

Expression *ReturnStatement::doInline(InlineDoState *ids)
{
    //printf("ReturnStatement::doInline() '%s'\n", exp ? exp->toChars() : "");
    return exp ? exp->doInline(ids) : 0;
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
        {   Expression *e = a->tdata()[i];

            if (e)
                e = e->doInline(ids);
            newa->tdata()[i] = e;
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
        if (var == ids->from.tdata()[i])
        {
            SymOffExp *se = (SymOffExp *)copy();

            se->var = (Declaration *)ids->to.tdata()[i];
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
        if (var == ids->from.tdata()[i])
        {
            VarExp *ve = (VarExp *)copy();

            ve->var = (Declaration *)ids->to.tdata()[i];
            return ve;
        }
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
{   DeclarationExp *de = (DeclarationExp *)copy();
    VarDeclaration *vd;

    //printf("DeclarationExp::doInline(%s)\n", toChars());
    vd = declaration->isVarDeclaration();
    if (vd)
    {
#if 0
        // Need to figure this out before inlining can work for tuples
        TupleDeclaration *td = vd->toAlias()->isTupleDeclaration();
        if (td)
        {
            for (size_t i = 0; i < td->objects->dim; i++)
            {   DsymbolExp *se = td->objects->tdata()[i];
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

            vto = new VarDeclaration(vd->loc, vd->type, vd->ident, vd->init);
            *vto = *vd;
            vto->parent = ids->parent;
            vto->csym = NULL;
            vto->isym = NULL;

            ids->from.push(vd);
            ids->to.push(vto);

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
            de->declaration = (Dsymbol *) (void *)vto;
        }
    }
    /* This needs work, like DeclarationExp::toElem(), if we are
     * to handle TemplateMixin's. For now, we just don't inline them.
     */
    return de;
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
        *vto = *vd;
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
        *vto = *vd;
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
    StructLiteralExp *ce;

    ce = (StructLiteralExp *)copy();
    ce->elements = arrayExpressiondoInline(elements, ids);
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
        exp = exp->inlineScan(iss);
    return this;
}

Statement *CompoundStatement::inlineScan(InlineScanState *iss)
{
    for (size_t i = 0; i < statements->dim; i++)
    {   Statement *s =  statements->tdata()[i];
        if (s)
            statements->tdata()[i] = s->inlineScan(iss);
    }
    return this;
}

Statement *UnrolledLoopStatement::inlineScan(InlineScanState *iss)
{
    for (size_t i = 0; i < statements->dim; i++)
    {   Statement *s =  statements->tdata()[i];
        if (s)
            statements->tdata()[i] = s->inlineScan(iss);
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


#if DMDV2
Statement *ForeachRangeStatement::inlineScan(InlineScanState *iss)
{
    lwr = lwr->inlineScan(iss);
    upr = upr->inlineScan(iss);
    if (body)
        body = body->inlineScan(iss);
    return this;
}
#endif


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

            s =  cases->tdata()[i];
            cases->tdata()[i] = (CaseStatement *)s->inlineScan(iss);
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
    {
        exp = exp->inlineScan(iss);
    }
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
        {   Catch *c = catches->tdata()[i];

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


Statement *VolatileStatement::inlineScan(InlineScanState *iss)
{
    if (statement)
        statement = statement->inlineScan(iss);
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
        {   Expression *e = arguments->tdata()[i];

            if (e)
            {
                e = e->inlineScan(iss);
                arguments->tdata()[i] = e;
            }
        }
    }
}

Expression *Expression::inlineScan(InlineScanState *iss)
{
    return this;
}

void scanVar(Dsymbol *s, InlineScanState *iss)
{
    VarDeclaration *vd = s->isVarDeclaration();
    if (vd)
    {
        TupleDeclaration *td = vd->toAlias()->isTupleDeclaration();
        if (td)
        {
            for (size_t i = 0; i < td->objects->dim; i++)
            {   DsymbolExp *se = (DsymbolExp *)td->objects->tdata()[i];
                assert(se->op == TOKdsymbol);
                scanVar(se->s, iss);
            }
        }
        else
        {
            // Scan initializer (vd->init)
            if (vd->init)
            {
                ExpInitializer *ie = vd->init->isExpInitializer();

                if (ie)
                {
#if DMDV2
                    if (vd->type)
                    {   Type *tb = vd->type->toBasetype();
                        if (tb->ty == Tstruct)
                        {   StructDeclaration *sd = ((TypeStruct *)tb)->sym;
                            if (sd->cpctor)
                            {   /* The problem here is that if the initializer is a
                                 * function call that returns a struct S with a cpctor:
                                 *   S s = foo();
                                 * the postblit is done by the return statement in foo()
                                 * in s2ir.c, the intermediate code generator.
                                 * But, if foo() is inlined and now the code looks like:
                                 *   S s = x;
                                 * the postblit is not there, because such assignments
                                 * are rewritten as s.cpctor(&x) by the front end.
                                 * So, the inlining won't get the postblit called.
                                 * Work around by not inlining these cases.
                                 * A proper fix would be to move all the postblit
                                 * additions to the front end.
                                 */
                                return;
                            }
                        }
                    }
#endif
                    ie->exp = ie->exp->inlineScan(iss);
                }
            }
        }
    }
}

Expression *DeclarationExp::inlineScan(InlineScanState *iss)
{
    //printf("DeclarationExp::inlineScan()\n");
    scanVar(declaration, iss);
    return this;
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


Expression *CallExp::inlineScan(InlineScanState *iss)
{   Expression *e = this;

    //printf("CallExp::inlineScan()\n");
    e1 = e1->inlineScan(iss);
    arrayInlineScan(iss, arguments);

    if (e1->op == TOKvar)
    {
        VarExp *ve = (VarExp *)e1;
        FuncDeclaration *fd = ve->var->isFuncDeclaration();

        if (fd && fd != iss->fd && fd->canInline(0))
        {
            e = fd->doInline(iss, NULL, arguments);
        }
    }
    else if (e1->op == TOKdotvar)
    {
        DotVarExp *dve = (DotVarExp *)e1;
        FuncDeclaration *fd = dve->var->isFuncDeclaration();

        if (fd && fd != iss->fd && fd->canInline(1))
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
                e = fd->doInline(iss, dve->e1, arguments);
        }
    }

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
    arrayInlineScan(iss, elements);

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
    printf("FuncDeclaration::inlineScan('%s')\n", toChars());
#endif
    memset(&iss, 0, sizeof(iss));
    iss.fd = this;
    if (fbody)
    {
        inlineNest++;
        fbody = fbody->inlineScan(&iss);
        inlineNest--;
    }
}

int FuncDeclaration::canInline(int hasthis, int hdrscan)
{
    InlineCostState ics;
    int cost;

#define CANINLINE_LOG 0

#if CANINLINE_LOG
    printf("FuncDeclaration::canInline(hasthis = %d, '%s')\n", hasthis, toChars());
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

    switch (inlineStatus)
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

    if (type)
    {   assert(type->ty == Tfunction);
        TypeFunction *tf = (TypeFunction *)(type);
        if (tf->varargs == 1)   // no variadic parameter lists
            goto Lno;

        /* Don't inline a function that returns non-void, but has
         * no return expression.
         */
        if (tf->next && tf->next->ty != Tvoid &&
            !(hasReturnExp & 1) &&
            !hdrscan)
            goto Lno;
    }

    if (
        !fbody ||
        !hdrscan &&
        (
#if 0
        isCtorDeclaration() ||  // cannot because need to convert:
                                //      return;
                                // to:
                                //      return this;
#endif
        isSynchronized() ||
        isImportedSymbol() ||
#if DMDV2
        closureVars.dim ||      // no nested references to this frame
#else
        nestedFrameRef ||       // no nested references to this frame
#endif
        (isVirtual() && !isFinal())
       ))
    {
        goto Lno;
    }

    /* If any parameters are Tsarray's (which are passed by reference)
     * or out parameters (also passed by reference), don't do inlining.
     */
#if 0
    if (parameters)
    {
        for (size_t i = 0; i < parameters->dim; i++)
        {
            VarDeclaration *v = parameters->tdata()[i];
            if (
#if DMDV1
                v->isOut() || v->isRef() ||
#endif
                v->type->toBasetype()->ty == Tsarray)
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
    printf("cost = %d\n", cost);
#endif
    if (cost >= COST_MAX)
        goto Lno;

    if (!hdrscan)    // Don't scan recursively for header content scan
        inlineScan();

    if (!hdrscan)    // Don't modify inlineStatus for header content scan
        inlineStatus = ILSyes;
#if CANINLINE_LOG
    printf("\t2: yes %s\n", toChars());
#endif
    return 1;

Lno:
    if (!hdrscan)    // Don't modify inlineStatus for header content scan
        inlineStatus = ILSno;
#if CANINLINE_LOG
    printf("\t2: no %s\n", toChars());
#endif
    return 0;
}

Expression *FuncDeclaration::doInline(InlineScanState *iss, Expression *ethis, Expressions *arguments)
{
    InlineDoState ids;
    DeclarationExp *de;
    Expression *e = NULL;

#if LOG
    printf("FuncDeclaration::doInline('%s')\n", toChars());
#endif

    memset(&ids, 0, sizeof(ids));
    ids.parent = iss->fd;

    // Set up vthis
    if (ethis)
    {
        VarDeclaration *vthis;
        ExpInitializer *ei;
        VarExp *ve;

#if STRUCTTHISREF
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
#else
        if (ethis->type->ty != Tclass && ethis->type->ty != Tpointer)
        {
            ethis = ethis->addressOf(NULL);
        }

        ei = new ExpInitializer(ethis->loc, ethis);

        vthis = new VarDeclaration(ethis->loc, ethis->type, Id::This, ei);
        vthis->storage_class = STCin;
#endif
        vthis->linkage = LINKd;
        vthis->parent = iss->fd;

        ve = new VarExp(vthis->loc, vthis);
        ve->type = vthis->type;

        ei->exp = new AssignExp(vthis->loc, ve, ethis);
        ei->exp->type = ve->type;
#if STRUCTTHISREF
        if (ethis->type->ty != Tclass)
        {   /* This is a reference initialization, not a simple assignment.
             */
            ei->exp->op = TOKconstruct;
        }
#endif

        ids.vthis = vthis;
    }

    // Set up parameters
    if (ethis)
    {
        e = new DeclarationExp(0, ids.vthis);
        e->type = Type::tvoid;
    }

    if (arguments && arguments->dim)
    {
        assert(parameters->dim == arguments->dim);

        for (size_t i = 0; i < arguments->dim; i++)
        {
            VarDeclaration *vfrom = parameters->tdata()[i];
            VarDeclaration *vto;
            Expression *arg = arguments->tdata()[i];
            ExpInitializer *ei;
            VarExp *ve;

            ei = new ExpInitializer(arg->loc, arg);

            vto = new VarDeclaration(vfrom->loc, vfrom->type, vfrom->ident, ei);
            vto->storage_class |= vfrom->storage_class & (STCin | STCout | STClazy | STCref);
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

            de = new DeclarationExp(0, vto);
            de->type = Type::tvoid;

            e = Expression::combine(e, de);
        }
    }

    inlineNest++;
    Expression *eb = fbody->doInline(&ids);
    inlineNest--;
//eb->type->print();
//eb->print();
//eb->dump(0);

    e = Expression::combine(e, eb);

    /* There's a problem if what the function returns is used subsequently as an
     * lvalue, as in a struct return that is then used as a 'this'.
     * If we take the address of the return value, we will be taking the address
     * of the original, not the copy. Fix this by assigning the return value to
     * a temporary, then returning the temporary. If the temporary is used as an
     * lvalue, it will work.
     * This only happens with struct returns.
     * See Bugzilla 2127 for an example.
     */
    TypeFunction *tf = (TypeFunction*)type;
    if (tf->next->ty == Tstruct)
    {
        /* Generate a new variable to hold the result and initialize it with the
         * inlined body of the function:
         *   tret __inlineretval = e;
         */
        ExpInitializer* ei = new ExpInitializer(loc, e);

        Identifier* tmp = Identifier::generateId("__inlineretval");
        VarDeclaration* vd = new VarDeclaration(loc, tf->next, tmp, ei);
        vd->storage_class = tf->isref ? STCref : 0;
        vd->linkage = tf->linkage;
        vd->parent = iss->fd;

        VarExp *ve = new VarExp(loc, vd);
        ve->type = tf->next;

        ei->exp = new ConstructExp(loc, ve, e);
        ei->exp->type = ve->type;

        DeclarationExp* de = new DeclarationExp(0, vd);
        de->type = Type::tvoid;

        // Chain the two together:
        //   ( typeof(return) __inlineretval = ( inlined body )) , __inlineretval
        e = Expression::combine(de, ve);

        //fprintf(stderr, "CallExp::inlineScan: e = "); e->print();
    }

    return e;
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
    InlineCostState ics;

    memset(&ics, 0, sizeof(ics));
    ics.hdrscan = 1;                    // so DeclarationExp:: will work on 'statics' which are not
    int cost = inlineCost(&ics);
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
