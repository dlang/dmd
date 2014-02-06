
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
#include "attrib.h"
#include "template.h"
#include "module.h"

static Expression *expandInline(FuncDeclaration *fd, FuncDeclaration *parent,
    Expression *eret, Expression *ethis, Expressions *arguments, Statement **ps);
bool walkPostorder(Expression *e, StoppableVisitor *v);

/* ========== Compute cost of inlining =============== */

/* Walk trees to determine if inlining can be done, and if so,
 * if it is too complex to be worth inlining or not.
 */

const int COST_MAX = 250;
const int STATEMENT_COST = 0x1000;
const int STATEMENT_COST_MAX = 250 * 0x1000;

// STATEMENT_COST be power of 2 and greater than COST_MAX
//static assert((STATEMENT_COST & (STATEMENT_COST - 1)) == 0);
//static assert(STATEMENT_COST > COST_MAX);

bool tooCostly(int cost) { return ((cost & (STATEMENT_COST - 1)) >= COST_MAX); }

class InlineCostVisitor : public Visitor
{
public:
    int nested;
    int hasthis;
    int hdrscan;    // !=0 if inline scan for 'header' content
    FuncDeclaration *fd;
    int cost;

    InlineCostVisitor()
    {
        nested = 0;
        hasthis = 0;
        hdrscan = 0;
        fd = NULL;
        cost = 0;
    }

    InlineCostVisitor(InlineCostVisitor *icv)
    {
        nested = icv->nested;
        hasthis = icv->hasthis;
        hdrscan = icv->hdrscan;
        fd = icv->fd;
        cost = 0;   // zero start for subsequent AST
    }

    void visit(Statement *s)
    {
        //printf("Statement::inlineCost = %d\n", COST_MAX);
        //printf("%p\n", s->isScopeStatement());
        //printf("%s\n", s->toChars());
        cost += COST_MAX;            // default is we can't inline it
    }

    void visit(ExpStatement *s)
    {
        expressionInlineCost(s->exp);
    }

    void visit(CompoundStatement *s)
    {
        InlineCostVisitor icv(this);
        for (size_t i = 0; i < s->statements->dim; i++)
        {
            Statement *s2 = (*s->statements)[i];
            if (s2)
            {
                s2->accept(&icv);
                if (tooCostly(icv.cost))
                    break;
            }
        }
        cost += icv.cost;
    }

    void visit(UnrolledLoopStatement *s)
    {
        InlineCostVisitor icv(this);
        for (size_t i = 0; i < s->statements->dim; i++)
        {
            Statement *s2 = (*s->statements)[i];
            if (s2)
            {
                s2->accept(&icv);
                if (tooCostly(icv.cost))
                    break;
            }
        }
        cost += icv.cost;
    }

    void visit(ScopeStatement *s)
    {
        cost++;
        if (s->statement)
            s->statement->accept(this);
    }

    void visit(IfStatement *s)
    {
        /* Can't declare variables inside ?: expressions, so
         * we cannot inline if a variable is declared.
         */
        if (s->arg)
        {
            cost = COST_MAX;
            return;
        }

        expressionInlineCost(s->condition);

        /* Specifically allow:
         *  if (condition)
         *      return exp1;
         *  else
         *      return exp2;
         * Otherwise, we can't handle return statements nested in if's.
         */

        if (s->elsebody && s->ifbody &&
            s->ifbody->isReturnStatement() &&
            s->elsebody->isReturnStatement())
        {
            s->ifbody->accept(this);
            s->elsebody->accept(this);
            //printf("cost = %d\n", cost);
        }
        else
        {
            nested += 1;
            if (s->ifbody)
                s->ifbody->accept(this);
            if (s->elsebody)
                s->elsebody->accept(this);
            nested -= 1;
        }
        //printf("IfStatement::inlineCost = %d\n", cost);
    }

    void visit(ReturnStatement *s)
    {
        // Can't handle return statements nested in if's
        if (nested)
        {
            cost = COST_MAX;
        }
        else
        {
            expressionInlineCost(s->exp);
        }
    }

    void visit(ImportStatement *s)
    {
    }

    void visit(ForStatement *s)
    {
        cost += STATEMENT_COST;
        if (s->init)
            s->init->accept(this);
        if (s->condition)
            s->condition->accept(this);
        if (s->increment)
            s->increment->accept(this);
        if (s->body)
            s->body->accept(this);
        //printf("ForStatement: inlineCost = %d\n", cost);
    }

    /* -------------------------- */

    void expressionInlineCost(Expression *e)
    {
        //printf("expressionInlineCost()\n");
        //e->print();
        if (e)
        {
            class LambdaInlineCost : public StoppableVisitor
            {
                InlineCostVisitor *icv;
            public:
                LambdaInlineCost(InlineCostVisitor *icv) : icv(icv) {}

                void visit(Expression *e)
                {
                    e->accept(icv);
                    stop = icv->cost >= COST_MAX;
                }
            };

            InlineCostVisitor icv(this);
            LambdaInlineCost lic(&icv);
            walkPostorder(e, &lic);
            cost += icv.cost;
        }
    }

    void visit(Expression *e)
    {
        cost++;
    }

    void visit(VarExp *e)
    {
        //printf("VarExp::inlineCost3() %s\n", toChars());
        Type *tb = e->type->toBasetype();
        if (tb->ty == Tstruct)
        {
            StructDeclaration *sd = ((TypeStruct *)tb)->sym;
            if (sd->isNested())
            {
                /* An inner struct will be nested inside another function hierarchy than where
                 * we're inlining into, so don't inline it.
                 * At least not until we figure out how to 'move' the struct to be nested
                 * locally. Example:
                 *   struct S(alias pred) { void unused_func(); }
                 *   void abc() { int w; S!(w) m; }
                 *   void bar() { abc(); }
                 */
                cost = COST_MAX;
                return;
            }
        }
        FuncDeclaration *fd = e->var->isFuncDeclaration();
        if (fd && fd->isNested())           // see Bugzilla 7199 for test case
            cost = COST_MAX;
        else
            cost++;
    }

    void visit(ThisExp *e)
    {
        //printf("ThisExp::inlineCost3() %s\n", toChars());
        if (!fd)
        {
            cost = COST_MAX;
            return;
        }
        if (!hdrscan)
        {
            if (fd->isNested() || !hasthis)
            {
                cost = COST_MAX;
                return;
            }
        }
        cost++;
    }

    void visit(StructLiteralExp *e)
    {
        //printf("StructLiteralExp::inlineCost3() %s\n", toChars());
        if (e->sd->isNested())
            cost = COST_MAX;
        else
            cost++;
    }

    void visit(FuncExp *e)
    {
        //printf("FuncExp::inlineCost3()\n");
        // Right now, this makes the function be output to the .obj file twice.
        cost = COST_MAX;
    }

    void visit(DelegateExp *e)
    {
        //printf("DelegateExp::inlineCost3()\n");
        cost = COST_MAX;
    }

    void visit(DeclarationExp *e)
    {
        //printf("DeclarationExp::inlineCost3()\n");
        VarDeclaration *vd = e->declaration->isVarDeclaration();
        if (vd)
        {
            TupleDeclaration *td = vd->toAlias()->isTupleDeclaration();
            if (td)
            {
                cost = COST_MAX;    // finish DeclarationExp::doInline
                return;
            }
            if (!hdrscan && vd->isDataseg())
            {
                cost = COST_MAX;
                return;
            }

            if (vd->edtor)
            {
                // if destructor required
                // needs work to make this work
                cost = COST_MAX;
                return;
            }
            // Scan initializer (vd->init)
            if (vd->init)
            {
                ExpInitializer *ie = vd->init->isExpInitializer();

                if (ie)
                {
                    expressionInlineCost(ie->exp);
                }
            }
            cost += 1;
        }

        // These can contain functions, which when copied, get output twice.
        if (e->declaration->isStructDeclaration() ||
            e->declaration->isClassDeclaration() ||
            e->declaration->isFuncDeclaration() ||
            e->declaration->isTypedefDeclaration() ||
            e->declaration->isAttribDeclaration() ||
            e->declaration->isTemplateMixin())
        {
            cost = COST_MAX;
            return;
        }

        //printf("DeclarationExp::inlineCost3('%s')\n", toChars());
    }

    void visit(CallExp *e)
    {
        //printf("CallExp::inlineCost3() %s\n", toChars());
        // Bugzilla 3500: super.func() calls must be devirtualized, and the inliner
        // can't handle that at present.
        if (e->e1->op == TOKdotvar && ((DotVarExp *)e->e1)->e1->op == TOKsuper)
            cost = COST_MAX;
        else
            cost++;
    }
};

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

class InlineScanVisitor : public Visitor
{
public:
    FuncDeclaration *parent; // function being scanned
    // As the visit method cannot return a value, these variables
    // are used to pass the result from 'visit' back to 'inlineScan'
    Statement *result;
    Expression *eresult;

    InlineScanVisitor()
    {
        this->parent = NULL;
        this->result = NULL;
        this->eresult = NULL;
    }

    void visit(Statement *s)
    {
    }

    void visit(ExpStatement *s)
    {
    #if LOG
        printf("ExpStatement::inlineScan(%s)\n", s->toChars());
    #endif
        if (s->exp)
        {
            inlineScan(&s->exp);

            /* See if we can inline as a statement rather than as
             * an Expression.
             */
            if (s->exp && s->exp->op == TOKcall)
            {
                CallExp *ce = (CallExp *)s->exp;
                if (ce->e1->op == TOKvar)
                {
                    VarExp *ve = (VarExp *)ce->e1;
                    FuncDeclaration *fd = ve->var->isFuncDeclaration();

                    if (fd && fd != parent && fd->canInline(0, 0, 1))
                    {
                        expandInline(fd, parent, NULL, NULL, ce->arguments, &result);
                    }
                }
            }
        }
    }

    void visit(CompoundStatement *s)
    {
        for (size_t i = 0; i < s->statements->dim; i++)
        {
            inlineScan(&(*s->statements)[i]);
        }
    }

    void visit(UnrolledLoopStatement *s)
    {
        for (size_t i = 0; i < s->statements->dim; i++)
        {
            inlineScan(&(*s->statements)[i]);
        }
    }

    void visit(ScopeStatement *s)
    {
        inlineScan(&s->statement);
    }

    void visit(WhileStatement *s)
    {
        inlineScan(&s->condition);
        inlineScan(&s->body);
    }

    void visit(DoStatement *s)
    {
        inlineScan(&s->body);
        inlineScan(&s->condition);
    }

    void visit(ForStatement *s)
    {
        inlineScan(&s->init);
        inlineScan(&s->condition);
        inlineScan(&s->increment);
        inlineScan(&s->body);
    }

    void visit(ForeachStatement *s)
    {
        inlineScan(&s->aggr);
        inlineScan(&s->body);
    }

    void visit(ForeachRangeStatement *s)
    {
        inlineScan(&s->lwr);
        inlineScan(&s->upr);
        inlineScan(&s->body);
    }

    void visit(IfStatement *s)
    {
        inlineScan(&s->condition);
        inlineScan(&s->ifbody);
        inlineScan(&s->elsebody);
    }

    void visit(SwitchStatement *s)
    {
        //printf("SwitchStatement::inlineScan()\n");
        inlineScan(&s->condition);
        inlineScan(&s->body);
        Statement *sdefault = s->sdefault;
        inlineScan(&sdefault);
        s->sdefault = (DefaultStatement *)sdefault;
        if (s->cases)
        {
            for (size_t i = 0; i < s->cases->dim; i++)
            {
                Statement *scase = (*s->cases)[i];
                inlineScan(&scase);
                (*s->cases)[i] = (CaseStatement *)scase;
            }
        }
    }

    void visit(CaseStatement *s)
    {
        //printf("CaseStatement::inlineScan()\n");
        inlineScan(&s->exp);
        inlineScan(&s->statement);
    }

    void visit(DefaultStatement *s)
    {
        inlineScan(&s->statement);
    }

    void visit(ReturnStatement *s)
    {
        //printf("ReturnStatement::inlineScan()\n");
        inlineScan(&s->exp);
    }

    void visit(SynchronizedStatement *s)
    {
        inlineScan(&s->exp);
        inlineScan(&s->body);
    }

    void visit(WithStatement *s)
    {
        inlineScan(&s->exp);
        inlineScan(&s->body);
    }

    void visit(TryCatchStatement *s)
    {
        inlineScan(&s->body);
        if (s->catches)
        {
            for (size_t i = 0; i < s->catches->dim; i++)
            {
                Catch *c = (*s->catches)[i];
                inlineScan(&c->handler);
            }
        }
    }

    void visit(TryFinallyStatement *s)
    {
        inlineScan(&s->body);
        inlineScan(&s->finalbody);
    }

    void visit(ThrowStatement *s)
    {
        inlineScan(&s->exp);
    }

    void visit(LabelStatement *s)
    {
        inlineScan(&s->statement);
    }

    void inlineScan(Statement **s)
    {
        if (!*s) return;
        Statement *save = result;
        result = *s;
        (*s)->accept(this);
        *s = result;
        result = save;
    }

    /* -------------------------- */

    void arrayInlineScan(Expressions *arguments)
    {
        if (arguments)
        {
            for (size_t i = 0; i < arguments->dim; i++)
            {
                inlineScan(&(*arguments)[i]);
            }
        }
    }

    void visit(Expression *e)
    {
    }

    Expression *scanVar(Dsymbol *s)
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
                    scanVar(se->s);    // TODO
                }
            }
            else if (vd->init)
            {
                if (ExpInitializer *ie = vd->init->isExpInitializer())
                {
                    Expression *e = ie->exp;
                    inlineScan(&e);
                    if (vd->init != ie)     // DeclareExp with vd appears in e
                        return e;
                    ie->exp = e;
                }
            }
        }
        else
        {
            s->accept(this);
        }
        return NULL;
    }

    void visit(DeclarationExp *e)
    {
        //printf("DeclarationExp::inlineScan()\n");
        Expression *ed = scanVar(e->declaration);
        if (ed)
            eresult = ed;
    }

    void visit(UnaExp *e)
    {
        inlineScan(&e->e1);
    }

    void visit(AssertExp *e)
    {
        inlineScan(&e->e1);
        inlineScan(&e->msg);
    }

    void visit(BinExp *e)
    {
        inlineScan(&e->e1);
        inlineScan(&e->e2);
    }

    void visit(AssignExp *e)
    {
        if (e->op == TOKconstruct && e->e2->op == TOKcall)
        {
            CallExp *ce = (CallExp *)e->e2;
            if (ce->f && ce->f->nrvo_var)   // NRVO
            {
                if (e->e1->op == TOKvar)
                {
                    /* Inlining:
                     *   S s = foo();   // initializing by rvalue
                     *   S s = S(1);    // constrcutor call
                     */
                    Declaration *d = ((VarExp *)e->e1)->var;
                    if (d->storage_class & (STCout | STCref))  // refinit
                        goto L1;
                }
                else
                {
                    /* Inlining:
                     *   this.field = foo();   // inside constructor
                     */
                    inlineScan(&e->e1);
                }

                visitCallExp(ce, e->e1);
                if (eresult)
                {
                    //printf("call with nrvo: %s ==> %s\n", e->toChars(), eresult->toChars());
                    return;
                }
            }
        }
    L1:
        visit((BinExp *)e);
    }

    void visit(CallExp *e)
    {
        visitCallExp(e, NULL);
    }

    void visitCallExp(CallExp *e, Expression *eret)
    {
        //printf("CallExp::inlineScan()\n");
        inlineScan(&e->e1);
        arrayInlineScan(e->arguments);

        if (e->e1->op == TOKvar)
        {
            VarExp *ve = (VarExp *)e->e1;
            FuncDeclaration *fd = ve->var->isFuncDeclaration();

            if (fd && fd != parent && fd->canInline(0, 0, 0))
            {
                eresult = expandInline(fd, parent, eret, NULL, e->arguments, NULL);
            }
        }
        else if (e->e1->op == TOKdotvar)
        {
            DotVarExp *dve = (DotVarExp *)e->e1;
            FuncDeclaration *fd = dve->var->isFuncDeclaration();

            if (fd && fd != parent && fd->canInline(1, 0, 0))
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
                    eresult = expandInline(fd, parent, eret, dve->e1, e->arguments, NULL);
            }
        }

        if (eresult && e->type->ty != Tvoid)
            eresult->type = e->type;
    }

    void visit(SliceExp *e)
    {
        inlineScan(&e->e1);
        inlineScan(&e->lwr);
        inlineScan(&e->upr);
    }

    void visit(TupleExp *e)
    {
        //printf("TupleExp::inlineScan()\n");
        inlineScan(&e->e0);
        arrayInlineScan(e->exps);
    }

    void visit(ArrayLiteralExp *e)
    {
        //printf("ArrayLiteralExp::inlineScan()\n");
        arrayInlineScan(e->elements);
    }

    void visit(AssocArrayLiteralExp *e)
    {
        //printf("AssocArrayLiteralExp::inlineScan()\n");
        arrayInlineScan(e->keys);
        arrayInlineScan(e->values);
    }

    void visit(StructLiteralExp *e)
    {
        //printf("StructLiteralExp::inlineScan()\n");
        if (e->stageflags & stageInlineScan) return;
        int old = e->stageflags;
        e->stageflags |= stageInlineScan;
        arrayInlineScan(e->elements);
        e->stageflags = old;
    }

    void visit(ArrayExp *e)
    {
        //printf("ArrayExp::inlineScan()\n");
        inlineScan(&e->e1);
        arrayInlineScan(e->arguments);
    }

    void visit(CondExp *e)
    {
        inlineScan(&e->econd);
        inlineScan(&e->e1);
        inlineScan(&e->e2);
    }

    void inlineScan(Expression **e)
    {
        if (!*e) return;
        Expression *save = eresult;
        eresult = *e;
        (*e)->accept(this);
        *e = eresult;
        eresult = save;
    }

    /*************************************
     * Look for function inlining possibilities.
     */

    void visit(Dsymbol *d)
    {
        // Most Dsymbols aren't functions
    }

    void visit(FuncDeclaration *fd)
    {
    #if LOG
        printf("FuncDeclaration::inlineScan('%s')\n", fd->toPrettyChars());
    #endif
        if (fd->isUnitTestDeclaration() && !global.params.useUnitTests)
            return;

        FuncDeclaration *oldparent = parent;
        parent = fd;
        if (fd->fbody && !fd->naked)
        {
            fd->inlineNest++;
            inlineScan(&fd->fbody);
            fd->inlineNest--;
        }
        parent = oldparent;
    }

    void visit(AttribDeclaration *d)
    {
        Dsymbols *decls = d->include(NULL, NULL);

        if (decls)
        {
            for (size_t i = 0; i < decls->dim; i++)
            {
                Dsymbol *s = (*decls)[i];
                //printf("AttribDeclaration::inlineScan %s\n", s->toChars());
                s->accept(this);
            }
        }
    }

    void visit(AggregateDeclaration *ad)
    {
        //printf("AggregateDeclaration::inlineScan(%s)\n", toChars());
        if (ad->members)
        {
            for (size_t i = 0; i < ad->members->dim; i++)
            {
                Dsymbol *s = (*ad->members)[i];
                //printf("inline scan aggregate symbol '%s'\n", s->toChars());
                s->accept(this);
            }
        }
    }

    void visit(TemplateInstance *ti)
    {
    #if LOG
        printf("TemplateInstance::inlineScan('%s')\n", ti->toChars());
    #endif
        if (!ti->errors && ti->members)
        {
            for (size_t i = 0; i < ti->members->dim; i++)
            {
                Dsymbol *s = (*ti->members)[i];
                s->accept(this);
            }
        }
    }
};

// scan for functions to inline
void inlineScan(Module *m)
{
    if (m->semanticRun != PASSsemantic3done)
        return;
    m->semanticRun = PASSinline;

    // Note that modules get their own scope, from scratch.
    // This is so regardless of where in the syntax a module
    // gets imported, it is unaffected by context.
    //printf("Module = %p\n", m->sc.scopesym);

    for (size_t i = 0; i < m->members->dim; i++)
    {
        Dsymbol *s = (*m->members)[i];
        //if (global.params.verbose)
        //    fprintf(global.stdmsg, "inline scan symbol %s\n", s->toChars());
        InlineScanVisitor v;
        s->accept(&v);
    }
    m->semanticRun = PASSinlinedone;
}

int FuncDeclaration::canInline(int hasthis, int hdrscan, int statementsToo)
{
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

    {
        InlineCostVisitor icv;
        icv.hasthis = hasthis;
        icv.fd = this;
        icv.hdrscan = hdrscan;
        fbody->accept(&icv);
        cost = icv.cost;
    }
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

        InlineScanVisitor v;
        accept(&v);      // Don't scan recursively for header content scan

        if (inlineStatusExp == ILSuninitialized)
        {
            // Need to redo cost computation, as some statements or expressions have been inlined
            InlineCostVisitor icv;
            icv.hasthis = hasthis;
            icv.fd = this;
            icv.hdrscan = hdrscan;
            fbody->accept(&icv);
            cost = icv.cost;
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

static Expression *expandInline(FuncDeclaration *fd, FuncDeclaration *parent,
        Expression *eret, Expression *ethis, Expressions *arguments, Statement **ps)
{
    InlineDoState ids;
    Expression *e = NULL;
    Statements *as = NULL;
    TypeFunction *tf = (TypeFunction*)fd->type;

#if LOG || CANINLINE_LOG
    printf("FuncDeclaration::expandInline('%s')\n", toChars());
#endif

    memset(&ids, 0, sizeof(ids));
    ids.parent = parent;
    ids.fd = fd;

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
            vret = new VarDeclaration(fd->loc, eret->type, Lexer::uniqueId("_satmp"), NULL);
            vret->storage_class |= STCtemp | STCforeach | STCref;
            vret->linkage = LINKd;
            vret->parent = parent;

            Expression *de;
            de = new DeclarationExp(fd->loc, vret);
            de->type = Type::tvoid;
            e = Expression::combine(e, de);

            Expression *ex;
            ex = new VarExp(fd->loc, vret);
            ex->type = vret->type;
            ex = new ConstructExp(fd->loc, ex, eret);
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
        vthis->parent = parent;

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

    if (!ps && fd->nrvo_var)
    {
        if (vret)
        {
            ids.from.push(fd->nrvo_var);
            ids.to.push(vret);
        }
        else
        {
            Identifier* tmp = Identifier::generateId("__nrvoretval");
            VarDeclaration* vd = new VarDeclaration(fd->loc, fd->nrvo_var->type, tmp, NULL);
            assert(!tf->isref);
            vd->storage_class = STCtemp | STCrvalue;
            vd->linkage = tf->linkage;
            vd->parent = parent;

            ids.from.push(fd->nrvo_var);
            ids.to.push(vd);

            Expression *de = new DeclarationExp(Loc(), vd);
            de->type = Type::tvoid;
            e = Expression::combine(e, de);
        }
    }
    if (arguments && arguments->dim)
    {
        assert(fd->parameters->dim == arguments->dim);

        for (size_t i = 0; i < arguments->dim; i++)
        {
            VarDeclaration *vfrom = (*fd->parameters)[i];
            VarDeclaration *vto;
            Expression *arg = (*arguments)[i];
            ExpInitializer *ei;
            VarExp *ve;

            ei = new ExpInitializer(arg->loc, arg);

            vto = new VarDeclaration(vfrom->loc, vfrom->type, vfrom->ident, ei);
            vto->storage_class |= vfrom->storage_class & (STCtemp | STCin | STCout | STClazy | STCref);
            vto->linkage = vfrom->linkage;
            vto->parent = parent;
            //printf("vto = '%s', vto->storage_class = x%x\n", vto->toChars(), vto->storage_class);
            //printf("vto->parent = '%s'\n", parent->toChars());

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
        fd->inlineNest++;
        Statement *s = fd->fbody->doInlineStatement(&ids);
        as->push(s);
        *ps = new ScopeStatement(Loc(), new CompoundStatement(Loc(), as));
        fd->inlineNest--;
    }
    else
    {
        fd->inlineNest++;
        Expression *eb = fd->fbody->doInline(&ids);
        e = Expression::combine(e, eb);
        fd->inlineNest--;
        //eb->type->print();
        //eb->print();
        //eb->print();

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
        if (tf->next->ty == Tstruct && !fd->nrvo_var && !fd->isCtorDeclaration())
        {
            /* Generate a new variable to hold the result and initialize it with the
             * inlined body of the function:
             *   tret __inlineretval = e;
             */
            ExpInitializer* ei = new ExpInitializer(fd->loc, e);

            Identifier* tmp = Identifier::generateId("__inlineretval");
            VarDeclaration* vd = new VarDeclaration(fd->loc, tf->next, tmp, ei);
            vd->storage_class = (tf->isref ? STCref : 0) | STCtemp | STCrvalue;
            vd->linkage = tf->linkage;
            vd->parent = parent;

            VarExp *ve = new VarExp(fd->loc, vd);
            ve->type = tf->next;

            ei->exp = new ConstructExp(fd->loc, ve, e);
            ei->exp->type = ve->type;

            DeclarationExp* de = new DeclarationExp(Loc(), vd);
            de->type = Type::tvoid;

            // Chain the two together:
            //   ( typeof(return) __inlineretval = ( inlined body )) , __inlineretval
            e = Expression::combine(de, ve);

            //fprintf(stderr, "CallExp::inlineScan: e = "); e->print();
        }
    }
    //printf("%s->expandInline = { %s }\n", fd->toChars(), e->toChars());

    // Need to reevaluate whether parent can now be inlined
    // in expressions, as we might have inlined statements
    parent->inlineStatusExp = ILSuninitialized;
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

    InlineCostVisitor icv;
    icv.hdrscan = 1;
    icv.expressionInlineCost(this);
    int cost = icv.cost;
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

