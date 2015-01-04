
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/inline.c
 */

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
#include "tokens.h"

static Expression *expandInline(FuncDeclaration *fd, FuncDeclaration *parent,
    Expression *eret, Expression *ethis, Expressions *arguments, Statement **ps);
bool walkPostorder(Expression *e, StoppableVisitor *v);
bool canInline(FuncDeclaration *fd, int hasthis, int hdrscan, int statementsToo);

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

    InlineCostVisitor(InlineCostVisitor *icv)
    {
        nested = icv->nested;
        hasthis = icv->hasthis;
        hdrscan = icv->hdrscan;
        allowAlloca = icv->allowAlloca;
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

Expression *doInline(Statement *s, InlineDoState *ids);
Expression *doInline(Expression *e, InlineDoState *ids);

/* -------------------------------------------------------------------- */

Statement *inlineAsStatement(Statement *s, InlineDoState *ids)
{
    class InlineAsStatement : public Visitor
    {
    public:
        InlineDoState *ids;
        Statement *result;

        InlineAsStatement(InlineDoState *ids)
            : ids(ids)
        {
            result = NULL;
        }

        void visit(Statement *s)
        {
            assert(0); // default is we can't inline it
        }

        void visit(ExpStatement *s)
        {
        #if LOG
            if (s->exp) printf("ExpStatement::inlineAsStatement() '%s'\n", s->exp->toChars());
        #endif
            result = new ExpStatement(s->loc, s->exp ? doInline(s->exp, ids) : NULL);
        }

        void visit(CompoundStatement *s)
        {
            //printf("CompoundStatement::inlineAsStatement() %d\n", s->statements->dim);
            Statements *as = new Statements();
            as->reserve(s->statements->dim);
            for (size_t i = 0; i < s->statements->dim; i++)
            {
                Statement *sx = (*s->statements)[i];
                if (sx)
                {
                    as->push(inlineAsStatement(sx, ids));
                    if (ids->foundReturn)
                        break;
                }
                else
                    as->push(NULL);
            }
            result = new CompoundStatement(s->loc, as);
        }

        void visit(UnrolledLoopStatement *s)
        {
            //printf("UnrolledLoopStatement::inlineAsStatement() %d\n", s->statements->dim);
            Statements *as = new Statements();
            as->reserve(s->statements->dim);
            for (size_t i = 0; i < s->statements->dim; i++)
            {
                Statement *sx = (*s->statements)[i];
                if (sx)
                {
                    as->push(inlineAsStatement(sx, ids));
                    if (ids->foundReturn)
                        break;
                }
                else
                    as->push(NULL);
            }
            result = new UnrolledLoopStatement(s->loc, as);
        }

        void visit(ScopeStatement *s)
        {
            //printf("ScopeStatement::inlineAsStatement() %d\n", s->statement->dim);
            result = s->statement ? new ScopeStatement(s->loc, inlineAsStatement(s->statement, ids)) : s;
        }

        void visit(IfStatement *s)
        {
            assert(!s->prm);

            Expression *condition = s->condition ? doInline(s->condition, ids) : NULL;
            Statement *ifbody = s->ifbody ? inlineAsStatement(s->ifbody, ids) : NULL;
            bool bodyReturn = ids->foundReturn;
            ids->foundReturn = false;
            Statement *elsebody = s->elsebody ? inlineAsStatement(s->elsebody, ids) : NULL;
            ids->foundReturn = ids->foundReturn && bodyReturn;

            result = new IfStatement(s->loc, s->prm, condition, ifbody, elsebody);
        }

        void visit(ReturnStatement *s)
        {
            //printf("ReturnStatement::inlineAsStatement() '%s'\n", s->exp ? s->exp->toChars() : "");
            ids->foundReturn = true;
            result = new ReturnStatement(s->loc, s->exp ? doInline(s->exp, ids) : NULL);
        }

        void visit(ImportStatement *s)
        {
            result = NULL;
        }

        void visit(ForStatement *s)
        {
            //printf("ForStatement::inlineAsStatement()\n");
            Statement *init = s->init ? inlineAsStatement(s->init, ids) : NULL;
            Expression *condition = s->condition ? doInline(s->condition, ids) : NULL;
            Expression *increment = s->increment ? doInline(s->increment, ids) : NULL;
            Statement *body = s->body ? inlineAsStatement(s->body, ids) : NULL;
            result = new ForStatement(s->loc, init, condition, increment, body, s->endloc);
        }

        void visit(ThrowStatement *s)
        {
            //printf("ThrowStatement::inlineAsStatement() '%s'\n", s->exp->toChars());
            result = new ThrowStatement(s->loc, doInline(s->exp, ids));
        }
    };

    InlineAsStatement v(ids);
    s->accept(&v);
    return v.result;
}

/* -------------------------------------------------------------------- */

Expression *doInline(Statement *s, InlineDoState *ids)
{
    class InlineStatement : public Visitor
    {
    public:
        InlineDoState *ids;
        Expression *result;

        InlineStatement(InlineDoState *ids)
            : ids(ids)
        {
            result = NULL;
        }

        void visit(Statement *s)
        {
            printf("Statement::doInline()\n%s\n", s->toChars());
            fflush(stdout);
            assert(0); // default is we can't inline it
        }

        void visit(ExpStatement *s)
        {
        #if LOG
            if (s->exp) printf("ExpStatement::doInline() '%s'\n", s->exp->toChars());
        #endif
            result = s->exp ? doInline(s->exp, ids) : NULL;
        }

        void visit(CompoundStatement *s)
        {
            //printf("CompoundStatement::doInline() %d\n", s->statements->dim);
            for (size_t i = 0; i < s->statements->dim; i++)
            {
                Statement *sx =  (*s->statements)[i];
                if (sx)
                {
                    Expression *e = doInline(sx, ids);
                    result = Expression::combine(result, e);
                    if (ids->foundReturn)
                        break;

                }
            }
        }

        void visit(UnrolledLoopStatement *s)
        {
            //printf("UnrolledLoopStatement::doInline() %d\n", s->statements->dim);
            for (size_t i = 0; i < s->statements->dim; i++)
            {
                Statement *sx =  (*s->statements)[i];
                if (sx)
                {
                    Expression *e = doInline(sx, ids);
                    result = Expression::combine(result, e);
                    if (ids->foundReturn)
                        break;

                }
            }
        }

        void visit(ScopeStatement *s)
        {
            result = s->statement ? doInline(s->statement, ids) : NULL;
        }

        void visit(IfStatement *s)
        {
            assert(!s->prm);
            Expression *econd = doInline(s->condition, ids);
            assert(econd);
            Expression *e1 = s->ifbody ? doInline(s->ifbody, ids) : NULL;
            bool bodyReturn = ids->foundReturn;
            ids->foundReturn = false;
            Expression *e2 = s->elsebody ? doInline(s->elsebody, ids) : NULL;
            if (e1 && e2)
            {
                result = new CondExp(econd->loc, econd, e1, e2);
                result->type = e1->type;
                if (result->type->ty == Ttuple)
                {
                    e1->type = Type::tvoid;
                    e2->type = Type::tvoid;
                    result->type = Type::tvoid;
                }
            }
            else if (e1)
            {
                result = new AndAndExp(econd->loc, econd, e1);
                result->type = Type::tvoid;
            }
            else if (e2)
            {
                result = new OrOrExp(econd->loc, econd, e2);
                result->type = Type::tvoid;
            }
            else
            {
                result = econd;
            }
            ids->foundReturn = ids->foundReturn && bodyReturn;
        }

        void visit(ReturnStatement *s)
        {
            //printf("ReturnStatement::doInline() '%s'\n", s->exp ? s->exp->toChars() : "");
            ids->foundReturn = true;
            result = s->exp ? doInline(s->exp, ids) : NULL;
        }

        void visit(ImportStatement *s)
        {
        }
    };

    InlineStatement v(ids);
    s->accept(&v);
    return v.result;
}

/* --------------------------------------------------------------- */

Expression *doInline(Expression *e, InlineDoState *ids)
{
    class InlineExpression : public Visitor
    {
    public:
        InlineDoState *ids;
        Expression *result;

        InlineExpression(InlineDoState *ids)
            : ids(ids)
        {
            result = NULL;
        }

        /******************************
         * Perform doInline() on an array of Expressions.
         */
        Expressions *arrayExpressiondoInline(Expressions *a)
        {
            if (!a)
                return NULL;

            Expressions *newa = new Expressions();
            newa->setDim(a->dim);

            for (size_t i = 0; i < a->dim; i++)
            {
                Expression *e = (*a)[i];
                if (e)
                    e = doInline(e, ids);
                (*newa)[i] = e;
            }
            return newa;
        }

        void visit(Expression *e)
        {
            //printf("Expression::doInline(%s): %s\n", Token::toChars(e->op), e->toChars());
            result = e->copy();
        }

        void visit(SymOffExp *e)
        {
            //printf("SymOffExp::doInline(%s)\n", e->toChars());
            for (size_t i = 0; i < ids->from.dim; i++)
            {
                if (e->var == ids->from[i])
                {
                    SymOffExp *se = (SymOffExp *)e->copy();
                    se->var = (Declaration *)ids->to[i];
                    result = se;
                    return;
                }
            }
            result = e;
        }

        void visit(VarExp *e)
        {
            //printf("VarExp::doInline(%s)\n", e->toChars());
            for (size_t i = 0; i < ids->from.dim; i++)
            {
                if (e->var == ids->from[i])
                {
                    VarExp *ve = (VarExp *)e->copy();
                    ve->var = (Declaration *)ids->to[i];
                    result = ve;
                    return;
                }
            }
            if (ids->fd && e->var == ids->fd->vthis)
            {
                result = new VarExp(e->loc, ids->vthis);
                result->type = e->type;
                return;
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
            VarDeclaration *v = e->var->isVarDeclaration();
            if (v && v->nestedrefs.dim && ids->vthis)
            {
                Dsymbol *s = ids->fd;
                FuncDeclaration *fdv = v->toParent()->isFuncDeclaration();
                assert(fdv);
                result = new VarExp(e->loc, ids->vthis);
                result->type = ids->vthis->type;
                while (s != fdv)
                {
                    FuncDeclaration *f = s->isFuncDeclaration();
                    if (AggregateDeclaration *ad = s->isThis())
                    {
                        assert(ad->vthis);
                        result = new DotVarExp(e->loc, result, ad->vthis);
                        result->type = ad->vthis->type;
                        s = ad->toParent2();
                    }
                    else if (f && f->isNested())
                    {
                        assert(f->vthis);
                        if (f->hasNestedFrameRefs())
                        {
                            result = new DotVarExp(e->loc, result, f->vthis);
                            result->type = f->vthis->type;
                        }
                        s = f->toParent2();
                    }
                    else
                        assert(0);
                    assert(s);
                }
                result = new DotVarExp(e->loc, result, v);
                result->type = v->type;
                //printf("\t==> result = %s, type = %s\n", result->toChars(), result->type->toChars());
                return;
            }

            result = e;
        }

        void visit(ThisExp *e)
        {
            //if (!ids->vthis)
                //e->error("no 'this' when inlining %s", ids->parent->toChars());
            if (!ids->vthis)
            {
                result = e;
                return;
            }

            result = new VarExp(e->loc, ids->vthis);
            result->type = e->type;
        }

        void visit(SuperExp *e)
        {
            assert(ids->vthis);

            result = new VarExp(e->loc, ids->vthis);
            result->type = e->type;
        }

        void visit(DeclarationExp *e)
        {
            //printf("DeclarationExp::doInline(%s)\n", e->toChars());
            if (VarDeclaration *vd = e->declaration->isVarDeclaration())
            {
        #if 0
                // Need to figure this out before inlining can work for tuples
                TupleDeclaration *td = vd->toAlias()->isTupleDeclaration();
                if (td)
                {
                    for (size_t i = 0; i < td->objects->dim; i++)
                    {
                        DsymbolExp *se = (*td->objects)[i];
                        assert(se->op == TOKdsymbol);
                        se->s;
                    }
                    result = st->objects->dim;
                    return;
                }
        #endif
                if (!vd->isStatic())
                {
                    if (ids->fd && vd == ids->fd->nrvo_var)
                    {
                        for (size_t i = 0; i < ids->from.dim; i++)
                        {
                            if (vd == ids->from[i])
                            {
                                if (vd->init && !vd->init->isVoidInitializer())
                                {
                                    result = vd->init->toExpression();
                                    assert(result);
                                    result = doInline(result, ids);
                                }
                                else
                                    result = new IntegerExp(vd->init->loc, 0, Type::tint32);
                                return;
                            }
                        }
                    }
                    VarDeclaration *vto = new VarDeclaration(vd->loc, vd->type, vd->ident, vd->init);
                    memcpy((void *)vto, (void *)vd, sizeof(VarDeclaration));
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
                            Expression *ei = vd->init->toExpression();
                            assert(ei);
                            vto->init = new ExpInitializer(ei->loc, doInline(ei, ids));
                        }
                    }
                    DeclarationExp *de = (DeclarationExp *)e->copy();
                    de->declaration = vto;
                    result = de;
                    return;
                }
            }
            /* This needs work, like DeclarationExp::toElem(), if we are
             * to handle TemplateMixin's. For now, we just don't inline them.
             */
            visit((Expression *)e);
        }

        void visit(NewExp *e)
        {
            //printf("NewExp::doInline(): %s\n", e->toChars());
            NewExp *ne = (NewExp *)e->copy();

            if (e->thisexp)
                ne->thisexp = doInline(e->thisexp, ids);
            ne->newargs = arrayExpressiondoInline(e->newargs);
            ne->arguments = arrayExpressiondoInline(e->arguments);
            result = ne;
        }

        void visit(UnaExp *e)
        {
            UnaExp *ue = (UnaExp *)e->copy();

            ue->e1 = doInline(e->e1, ids);
            result = ue;
        }

        void visit(AssertExp *e)
        {
            AssertExp *ae = (AssertExp *)e->copy();

            ae->e1 = doInline(e->e1, ids);
            if (e->msg)
                ae->msg = doInline(e->msg, ids);
            result = ae;
        }

        void visit(BinExp *e)
        {
            BinExp *be = (BinExp *)e->copy();

            be->e1 = doInline(e->e1, ids);
            be->e2 = doInline(e->e2, ids);
            result = be;
        }

        void visit(CallExp *e)
        {
            CallExp *ce = (CallExp *)e->copy();

            ce->e1 = doInline(e->e1, ids);
            ce->arguments = arrayExpressiondoInline(e->arguments);
            result = ce;
        }

        void visit(IndexExp *e)
        {
            IndexExp *are = (IndexExp *)e->copy();

            are->e1 = doInline(e->e1, ids);

            if (e->lengthVar)
            {
                //printf("lengthVar\n");
                VarDeclaration *vd = e->lengthVar;

                VarDeclaration *vto = new VarDeclaration(vd->loc, vd->type, vd->ident, vd->init);
                memcpy((void*)vto, (void*)vd, sizeof(VarDeclaration));
                vto->parent = ids->parent;
                vto->csym = NULL;
                vto->isym = NULL;

                ids->from.push(vd);
                ids->to.push(vto);

                if (vd->init && !vd->init->isVoidInitializer())
                {
                    ExpInitializer *ie = vd->init->isExpInitializer();
                    assert(ie);
                    vto->init = new ExpInitializer(ie->loc, doInline(ie->exp, ids));;
                }

                are->lengthVar = vto;
            }
            are->e2 = doInline(e->e2, ids);
            result = are;
        }

        void visit(SliceExp *e)
        {
            SliceExp *are = (SliceExp *)e->copy();

            are->e1 = doInline(e->e1, ids);

            if (e->lengthVar)
            {
                //printf("lengthVar\n");
                VarDeclaration *vd = e->lengthVar;

                VarDeclaration *vto = new VarDeclaration(vd->loc, vd->type, vd->ident, vd->init);
                memcpy((void*)vto, (void*)vd, sizeof(VarDeclaration));
                vto->parent = ids->parent;
                vto->csym = NULL;
                vto->isym = NULL;

                ids->from.push(vd);
                ids->to.push(vto);

                if (vd->init && !vd->init->isVoidInitializer())
                {
                    ExpInitializer *ie = vd->init->isExpInitializer();
                    assert(ie);
                    vto->init = new ExpInitializer(ie->loc, doInline(ie->exp, ids));;
                }

                are->lengthVar = vto;
            }
            if (e->lwr)
                are->lwr = doInline(e->lwr, ids);
            if (e->upr)
                are->upr = doInline(e->upr, ids);
            result = are;
        }

        void visit(TupleExp *e)
        {
            TupleExp *ce = (TupleExp *)e->copy();

            if (e->e0)
                ce->e0 = doInline(e->e0, ids);
            ce->exps = arrayExpressiondoInline(e->exps);
            result = ce;
        }

        void visit(ArrayLiteralExp *e)
        {
            ArrayLiteralExp *ce = (ArrayLiteralExp *)e->copy();

            ce->elements = arrayExpressiondoInline(e->elements);
            result = ce;
        }

        void visit(AssocArrayLiteralExp *e)
        {
            AssocArrayLiteralExp *ce = (AssocArrayLiteralExp *)e->copy();

            ce->keys = arrayExpressiondoInline(e->keys);
            ce->values = arrayExpressiondoInline(e->values);
            result = ce;
        }

        void visit(StructLiteralExp *e)
        {
            if (e->inlinecopy)
            {
                result = e->inlinecopy;
                return;
            }
            StructLiteralExp *ce = (StructLiteralExp *)e->copy();

            e->inlinecopy = ce;
            ce->elements = arrayExpressiondoInline(e->elements);
            e->inlinecopy = NULL;
            result = ce;
        }

        void visit(ArrayExp *e)
        {
            ArrayExp *ce = (ArrayExp *)e->copy();

            ce->e1 = doInline(e->e1, ids);
            ce->arguments = arrayExpressiondoInline(e->arguments);
            result = ce;
        }

        void visit(CondExp *e)
        {
            CondExp *ce = (CondExp *)e->copy();

            ce->econd = doInline(e->econd, ids);
            ce->e1 = doInline(e->e1, ids);
            ce->e2 = doInline(e->e2, ids);
            result = ce;
        }
    };

    InlineExpression v(ids);
    e->accept(&v);
    return v.result;
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

                    if (fd && fd != parent && canInline(fd, 0, 0, 1))
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
            if (ce->f && ce->f->nrvo_can && ce->f->nrvo_var)   // NRVO
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

            if (fd && fd != parent && canInline(fd, 0, 0, 0))
            {
                Expression *ex = expandInline(fd, parent, eret, NULL, e->arguments, NULL);
                if (ex)
                {
                    eresult = ex;
                    if (global.params.verbose)
                        fprintf(global.stdmsg, "inlined   %s =>\n          %s\n", fd->toPrettyChars(), parent->toPrettyChars());
                }
            }
        }
        else if (e->e1->op == TOKdotvar)
        {
            DotVarExp *dve = (DotVarExp *)e->e1;
            FuncDeclaration *fd = dve->var->isFuncDeclaration();

            if (fd && fd != parent && canInline(fd, 1, 0, 0))
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
                {
                    Expression *ex = expandInline(fd, parent, eret, dve->e1, e->arguments, NULL);
                    if (ex)
                    {
                        eresult = ex;
                        if (global.params.verbose)
                            fprintf(global.stdmsg, "inlined   %s =>\n          %s\n", fd->toPrettyChars(), parent->toPrettyChars());
                    }
                }
            }
        }

        if (eresult && e->type->ty != Tvoid)
        {
            Expression *ex = eresult;
            while (ex->op == TOKcomma)
            {
                ex->type = e->type;
                ex = ((CommaExp *)ex)->e2;
            }
            ex->type = e->type;
        }
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
        assert(eresult);
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

bool canInline(FuncDeclaration *fd, int hasthis, int hdrscan, int statementsToo)
{
    int cost;

#define CANINLINE_LOG 0

#if CANINLINE_LOG
    printf("FuncDeclaration::canInline(hasthis = %d, statementsToo = %d, '%s')\n", hasthis, statementsToo, fd->toPrettyChars());
#endif

    if (fd->needThis() && !hasthis)
        return false;

    if (fd->inlineNest || (fd->semanticRun < PASSsemantic3 && !hdrscan))
    {
#if CANINLINE_LOG
        printf("\t1: no, inlineNest = %d, semanticRun = %d\n", fd->inlineNest, fd->semanticRun);
#endif
        return false;
    }

    switch (statementsToo ? fd->inlineStatusStmt : fd->inlineStatusExp)
    {
        case ILSyes:
#if CANINLINE_LOG
            printf("\t1: yes %s\n", fd->toChars());
#endif
            return true;

        case ILSno:
#if CANINLINE_LOG
            printf("\t1: no %s\n", fd->toChars());
#endif
            return false;

        case ILSuninitialized:
            break;

        default:
            assert(0);
    }

    if (fd->type)
    {
        assert(fd->type->ty == Tfunction);
        TypeFunction *tf = (TypeFunction *)fd->type;
        if (tf->varargs == 1)   // no variadic parameter lists
            goto Lno;

        /* Don't inline a function that returns non-void, but has
         * no return expression.
         * No statement inlining for non-voids.
         */
        if (tf->next && tf->next->ty != Tvoid &&
            (!(fd->hasReturnExp & 1) || statementsToo) &&
            !hdrscan)
            goto Lno;
    }

    // cannot inline constructor calls because we need to convert:
    //      return;
    // to:
    //      return this;
    // ensure() has magic properties the inliner loses
    // require() has magic properties too
    // see bug 7699
    // no nested references to this frame
    if (!fd->fbody ||
        fd->ident == Id::ensure ||
        (fd->ident == Id::require &&
         fd->toParent()->isFuncDeclaration() &&
         fd->toParent()->isFuncDeclaration()->needThis()) ||
        !hdrscan &&
        (
        fd->isSynchronized() ||
        fd->isImportedSymbol() ||
        fd->hasNestedFrameRefs() ||
        (fd->isVirtual() && !fd->isFinalFunc())
       ))
    {
        goto Lno;
    }

    {
        InlineCostVisitor icv;
        icv.hasthis = hasthis;
        icv.fd = fd;
        icv.hdrscan = hdrscan;
        fd->fbody->accept(&icv);
        cost = icv.cost;
    }
#if CANINLINE_LOG
    printf("cost = %d for %s\n", cost, fd->toChars());
#endif
    if (tooCostly(cost))
        goto Lno;
    if (!statementsToo && cost > COST_MAX)
        goto Lno;

    if (!hdrscan)
    {
        // Don't modify inlineStatus for header content scan
        if (statementsToo)
            fd->inlineStatusStmt = ILSyes;
        else
            fd->inlineStatusExp = ILSyes;

        InlineScanVisitor v;
        fd->accept(&v);      // Don't scan recursively for header content scan

        if (fd->inlineStatusExp == ILSuninitialized)
        {
            // Need to redo cost computation, as some statements or expressions have been inlined
            InlineCostVisitor icv;
            icv.hasthis = hasthis;
            icv.fd = fd;
            icv.hdrscan = hdrscan;
            fd->fbody->accept(&icv);
            cost = icv.cost;
        #if CANINLINE_LOG
            printf("recomputed cost = %d for %s\n", cost, fd->toChars());
        #endif
            if (tooCostly(cost))
                goto Lno;
            if (!statementsToo && cost > COST_MAX)
                goto Lno;

            if (statementsToo)
                fd->inlineStatusStmt = ILSyes;
            else
                fd->inlineStatusExp = ILSyes;
        }
    }
#if CANINLINE_LOG
    printf("\t2: yes %s\n", fd->toChars());
#endif
    return true;

Lno:
    if (!hdrscan)    // Don't modify inlineStatus for header content scan
    {
        if (statementsToo)
            fd->inlineStatusStmt = ILSno;
        else
            fd->inlineStatusExp = ILSno;
    }
#if CANINLINE_LOG
    printf("\t2: no %s\n", fd->toChars());
#endif
    return false;
}

static Expression *expandInline(FuncDeclaration *fd, FuncDeclaration *parent,
        Expression *eret, Expression *ethis, Expressions *arguments, Statement **ps)
{
    InlineDoState ids;
    Expression *e = NULL;
    Statements *as = NULL;
    TypeFunction *tf = (TypeFunction*)fd->type;

#if LOG || CANINLINE_LOG
    printf("FuncDeclaration::expandInline('%s')\n", fd->toChars());
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
            vret = new VarDeclaration(fd->loc, eret->type, Identifier::generateId("_satmp"), NULL);
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

            if (vfrom->storage_class & (STCout | STCref))
                ei->exp = new ConstructExp(vto->loc, ve, arg);
            else
                ei->exp = new BlitExp(vto->loc, ve, arg);
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
        Statement *s = inlineAsStatement(fd->fbody, &ids);
        as->push(s);
        *ps = new ScopeStatement(Loc(), new CompoundStatement(Loc(), as));
        fd->inlineNest--;
    }
    else
    {
        fd->inlineNest++;
        Expression *eb = doInline(fd->fbody, &ids);
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

Expression *inlineCopy(Expression *e, Scope *sc)
{
    /* See Bugzilla 2935 for explanation of why just a copy() is broken
     */
    //return e->copy();

    if (e->op == TOKdelegate)
    {
        DelegateExp *de = (DelegateExp *)e;

        if (de->func->isNested())
        {
            /* See Bugzilla 4820
             * Defer checking until later if we actually need the 'this' pointer
             */
            return de->copy();
        }
    }

    InlineCostVisitor icv;
    icv.hdrscan = 1;
    icv.allowAlloca = true;
    icv.expressionInlineCost(e);
    int cost = icv.cost;
    if (cost >= COST_MAX)
    {
        e->error("cannot inline default argument %s", e->toChars());
        return new ErrorExp();
    }
    InlineDoState ids;
    memset(&ids, 0, sizeof(ids));
    ids.parent = sc->parent;
    return doInline(e, &ids);
}

