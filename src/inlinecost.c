
/* Compiler implementation of the D programming language
 * Copyright (C) 1999-2021 by The D Language Foundation, All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/inlinecost.c
 */

#include "id.h"
#include "init.h"
#include "aggregate.h"
#include "declaration.h"
#include "statement.h"
#include "tokens.h"

bool walkPostorder(Expression *e, StoppableVisitor *v);

const int COST_MAX = 250;
const int STATEMENT_COST = 0x1000;
const int STATEMENT_COST_MAX = 250 * STATEMENT_COST;

// STATEMENT_COST be power of 2 and greater than COST_MAX
//static assert((STATEMENT_COST & (STATEMENT_COST - 1)) == 0);
//static assert(STATEMENT_COST > COST_MAX);

/*********************************
 * Determine if too expensive to inline.
 * Params:
 *      cost = cost of inlining
 * Returns:
 *      true if too costly
 */
bool tooCostly(int cost)
{
    return ((cost & (STATEMENT_COST - 1)) >= COST_MAX);
}

/* ========== Compute cost of inlining =============== */

/* Walk trees to determine if inlining can be done, and if so,
 * if it is too complex to be worth inlining or not.
 */

class InlineCostVisitor : public Visitor
{
public:
    int nested;
    int hasthis;
    int hdrscan;    // !=0 if inline scan for 'header' content
    bool allowAlloca;
    FuncDeclaration *fd;
    int cost;

    InlineCostVisitor()
    {
        nested = 0;
        hasthis = 0;
        hdrscan = 0;
        allowAlloca = false;
        fd = NULL;
        cost = 0;
    }

    InlineCostVisitor(bool hasthis, bool hdrscan, bool allowAlloca, FuncDeclaration *fd)
    {
        this->nested = 0;
        this->hasthis = hasthis;
        this->hdrscan = hdrscan;
        this->allowAlloca = allowAlloca;
        this->fd = fd;
        this->cost = 0;
    }

    InlineCostVisitor(InlineCostVisitor *icv)
    {
        nested = icv->nested;
        hasthis = icv->hasthis;
        hdrscan = icv->hdrscan;
        allowAlloca = icv->allowAlloca;
        fd = icv->fd;
        cost = 0;   // zero start for subsequent AST
    }

    void visit(Statement *)
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
        for (size_t i = 0; i < s->statements->length; i++)
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
        for (size_t i = 0; i < s->statements->length; i++)
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
        if (s->prm)
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

    void visit(ImportStatement *)
    {
    }

    void visit(ForStatement *s)
    {
        cost += STATEMENT_COST;
        if (s->_init)
            s->_init->accept(this);
        if (s->condition)
            s->condition->accept(this);
        if (s->increment)
            s->increment->accept(this);
        if (s->_body)
            s->_body->accept(this);
        //printf("ForStatement: inlineCost = %d\n", cost);
    }

    void visit(ThrowStatement *s)
    {
        cost += STATEMENT_COST;
        s->exp->accept(this);
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

    void visit(Expression *)
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

    void visit(ThisExp *)
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

    void visit(NewExp *e)
    {
        //printf("NewExp::inlineCost3() %s\n", e->toChars());
        AggregateDeclaration *ad = isAggregate(e->newtype);
        if (ad && ad->isNested())
            cost = COST_MAX;
        else
            cost++;
    }

    void visit(FuncExp *)
    {
        //printf("FuncExp::inlineCost3()\n");
        // Right now, this makes the function be output to the .obj file twice.
        cost = COST_MAX;
    }

    void visit(DelegateExp *)
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
            if (vd->_init)
            {
                ExpInitializer *ie = vd->_init->isExpInitializer();

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
        else if (e->f && e->f->ident == Id::__alloca && e->f->linkage == LINKc && !allowAlloca)
            cost = COST_MAX; // inlining alloca may cause stack overflows
        else
            cost++;
    }
};

/*********************************
 * Determine cost of inlining Expression
 * Params:
 *      e = Expression to determine cost of
 * Returns:
 *      cost of inlining e
 */
int inlineCostExpression(Expression *e)
{
    InlineCostVisitor icv = InlineCostVisitor(false, true, true, NULL);
    icv.expressionInlineCost(e);
    return icv.cost;
}

/*********************************
 * Determine cost of inlining function
 * Params:
 *      fd = function to determine cost of
 * Returns:
 *      cost of inlining fd
 */
int inlineCostFunction(FuncDeclaration *fd, bool hasthis, bool hdrscan)
{
    InlineCostVisitor icv = InlineCostVisitor(hasthis, hdrscan, false, fd);
    fd->fbody->accept(&icv);
    return icv.cost;
}
