
/* Compiler implementation of the D programming language
 * Copyright (C) 1999-2021 by The D Language Foundation, All Rights Reserved
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

static void expandInline(Loc callLoc, FuncDeclaration *fd, FuncDeclaration *parent,
    Expression *eret, Expression *ethis, Expressions *arguments, bool asStatements,
    Expression **eresult, Statement **sresult, bool *again);
bool walkPostorder(Expression *e, StoppableVisitor *v);
bool canInline(FuncDeclaration *fd, int hasthis, int hdrscan, bool statementsToo);
int inlineCostExpression(Expression *e);
int inlineCostFunction(FuncDeclaration *fd, bool hasthis, bool hdrscan);
bool tooCostly(int cost);
const int COST_MAX = 250;

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

        void visit(Statement *)
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
            //printf("CompoundStatement::inlineAsStatement() %d\n", s->statements->length);
            Statements *as = new Statements();
            as->reserve(s->statements->length);
            for (size_t i = 0; i < s->statements->length; i++)
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
            //printf("UnrolledLoopStatement::inlineAsStatement() %d\n", s->statements->length);
            Statements *as = new Statements();
            as->reserve(s->statements->length);
            for (size_t i = 0; i < s->statements->length; i++)
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
            //printf("ScopeStatement::inlineAsStatement() %d\n", s->statement->length);
            result = s->statement ? new ScopeStatement(s->loc, inlineAsStatement(s->statement, ids), s->endloc) : s;
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

            result = new IfStatement(s->loc, s->prm, condition, ifbody, elsebody, s->endloc);
        }

        void visit(ReturnStatement *s)
        {
            //printf("ReturnStatement::inlineAsStatement() '%s'\n", s->exp ? s->exp->toChars() : "");
            ids->foundReturn = true;
            if (s->exp) // Bugzilla 14560: 'return' must not leave in the expand result
                result = new ReturnStatement(s->loc, doInline(s->exp, ids));
        }

        void visit(ImportStatement *)
        {
            result = NULL;
        }

        void visit(ForStatement *s)
        {
            //printf("ForStatement::inlineAsStatement()\n");
            Statement *init = s->_init ? inlineAsStatement(s->_init, ids) : NULL;
            Expression *condition = s->condition ? doInline(s->condition, ids) : NULL;
            Expression *increment = s->increment ? doInline(s->increment, ids) : NULL;
            Statement *body = s->_body ? inlineAsStatement(s->_body, ids) : NULL;
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
            //printf("CompoundStatement::doInline() %d\n", s->statements->length);
            for (size_t i = 0; i < s->statements->length; i++)
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
            //printf("UnrolledLoopStatement::doInline() %d\n", s->statements->length);
            for (size_t i = 0; i < s->statements->length; i++)
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
                result = new LogicalExp(econd->loc, TOKandand, econd, e1);
                result->type = Type::tvoid;
            }
            else if (e2)
            {
                result = new LogicalExp(econd->loc, TOKoror, econd, e2);
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

        void visit(ImportStatement *)
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
            newa->setDim(a->length);

            for (size_t i = 0; i < a->length; i++)
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
            for (size_t i = 0; i < ids->from.length; i++)
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
            for (size_t i = 0; i < ids->from.length; i++)
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
            if (v && v->nestedrefs.length && ids->vthis)
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
                    for (size_t i = 0; i < td->objects->length; i++)
                    {
                        DsymbolExp *se = (*td->objects)[i];
                        assert(se->op == TOKdsymbol);
                        se->s;
                    }
                    result = st->objects->length;
                    return;
                }
        #endif
                if (!vd->isStatic())
                {
                    if (ids->fd && vd == ids->fd->nrvo_var)
                    {
                        for (size_t i = 0; i < ids->from.length; i++)
                        {
                            if (vd == ids->from[i])
                            {
                                if (vd->_init && !vd->_init->isVoidInitializer())
                                {
                                    result = initializerToExpression(vd->_init);
                                    assert(result);
                                    result = doInline(result, ids);
                                }
                                else
                                    result = new IntegerExp(vd->_init->loc, 0, Type::tint32);
                                return;
                            }
                        }
                    }
                    void *pvto = new VarDeclaration(vd->loc, vd->type, vd->ident, vd->_init);
                    VarDeclaration *vto = (VarDeclaration *)memcpy(pvto, (void*)vd, sizeof(VarDeclaration));
                    vto->parent = ids->parent;
                    vto->csym = NULL;
                    vto->isym = NULL;

                    ids->from.push(vd);
                    ids->to.push(vto);

                    if (vd->_init)
                    {
                        if (vd->_init->isVoidInitializer())
                        {
                            vto->_init = new VoidInitializer(vd->_init->loc);
                        }
                        else
                        {
                            Expression *ei = initializerToExpression(vd->_init);
                            assert(ei);
                            vto->_init = new ExpInitializer(ei->loc, doInline(ei, ids));
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

        void visit(TypeidExp *e)
        {
            //printf("TypeidExp::doInline(): %s\n", e->toChars());
            TypeidExp *te = (TypeidExp *)e->copy();
            if (Expression *ex = isExpression(te->obj))
            {
                te->obj = doInline(ex, ids);
            }
            else
                assert(isType(te->obj));
            result = te;
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

            semanticTypeInfo(NULL, e->type);
        }

        void visit(DeleteExp *e)
        {
            visit((UnaExp *)e);

            Type *tb = e->e1->type->toBasetype();
            if (tb->ty == Tarray)
            {
                Type *tv = tb->nextOf()->baseElemOf();
                if (tv->ty == Tstruct)
                {
                    TypeStruct *ts = (TypeStruct *)tv;
                    StructDeclaration *sd = ts->sym;
                    if (sd->dtor)
                        semanticTypeInfo(NULL, ts);
                }
            }
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

        void visit(AssignExp *e)
        {
            visit((BinExp *)e);

            if (e->e1->op == TOKarraylength)
            {
                ArrayLengthExp *ale = (ArrayLengthExp *)e->e1;
                Type *tn = ale->e1->type->toBasetype()->nextOf();
                semanticTypeInfo(NULL, tn);
            }
        }

        void visit(EqualExp *e)
        {
            visit((BinExp *)e);

            Type *t1 = e->e1->type->toBasetype();
            if (t1->ty == Tarray || t1->ty == Tsarray)
            {
                Type *t = t1->nextOf()->toBasetype();
                while (t->toBasetype()->nextOf())
                    t = t->nextOf()->toBasetype();
                if (t->ty == Tstruct)
                    semanticTypeInfo(NULL, t);
            }
            else if (t1->ty == Taarray)
            {
                semanticTypeInfo(NULL, t1);
            }
        }

        void visit(IndexExp *e)
        {
            IndexExp *are = (IndexExp *)e->copy();

            are->e1 = doInline(e->e1, ids);

            if (e->lengthVar)
            {
                //printf("lengthVar\n");
                VarDeclaration *vd = e->lengthVar;

                void *pvto = new VarDeclaration(vd->loc, vd->type, vd->ident, vd->_init);
                VarDeclaration *vto = (VarDeclaration *)memcpy(pvto, (void*)vd, sizeof(VarDeclaration));
                vto->parent = ids->parent;
                vto->csym = NULL;
                vto->isym = NULL;

                ids->from.push(vd);
                ids->to.push(vto);

                if (vd->_init && !vd->_init->isVoidInitializer())
                {
                    ExpInitializer *ie = vd->_init->isExpInitializer();
                    assert(ie);
                    vto->_init = new ExpInitializer(ie->loc, doInline(ie->exp, ids));
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

                void *pvto = new VarDeclaration(vd->loc, vd->type, vd->ident, vd->_init);
                VarDeclaration *vto = (VarDeclaration *)memcpy(pvto, (void*)vd, sizeof(VarDeclaration));
                vto->parent = ids->parent;
                vto->csym = NULL;
                vto->isym = NULL;

                ids->from.push(vd);
                ids->to.push(vto);

                if (vd->_init && !vd->_init->isVoidInitializer())
                {
                    ExpInitializer *ie = vd->_init->isExpInitializer();
                    assert(ie);
                    vto->_init = new ExpInitializer(ie->loc, doInline(ie->exp, ids));
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
            if (ce->basis)
                ce->basis = doInline(e->basis, ids);
            ce->elements = arrayExpressiondoInline(e->elements);
            result = ce;

            semanticTypeInfo(NULL, e->type);
        }

        void visit(AssocArrayLiteralExp *e)
        {
            AssocArrayLiteralExp *ce = (AssocArrayLiteralExp *)e->copy();

            ce->keys = arrayExpressiondoInline(e->keys);
            ce->values = arrayExpressiondoInline(e->values);
            result = ce;

            semanticTypeInfo(NULL, e->type);
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
    Statement *sresult;
    Expression *eresult;
    bool again;

    InlineScanVisitor()
    {
        this->parent = NULL;
        this->sresult = NULL;
        this->eresult = NULL;
        this->again = false;
    }

    void visit(Statement *)
    {
    }

    Statement *inlineScanExpAsStatement(Expression **exp)
    {
        /* If there's a TOKcall at the top, then it may fail to inline
         * as an Expression. Try to inline as a Statement instead.
         */
        if ((*exp)->op == TOKcall)
        {
            visitCallExp((CallExp *)(*exp), NULL, true);
            if (eresult)
                *exp = eresult;
            Statement *s = sresult;
            sresult = NULL;
            eresult = NULL;
            return s;
        }

        /* If there's a CondExp or CommaExp at the top, then its
         * sub-expressions may be inlined as statements.
         */
        if ((*exp)->op == TOKquestion)
        {
            CondExp *e = (CondExp *)(*exp);
            inlineScan(&e->econd);
            Statement *s1 = inlineScanExpAsStatement(&e->e1);
            Statement *s2 = inlineScanExpAsStatement(&e->e2);
            if (!s1 && !s2)
                return NULL;
            Statement *ifbody = !s1 ? new ExpStatement(e->e1->loc, e->e1) : s1;
            Statement *elsebody = !s2 ? new ExpStatement(e->e2->loc, e->e2) : s2;
            return new IfStatement((*exp)->loc, NULL, e->econd, ifbody, elsebody, (*exp)->loc);
        }
        if ((*exp)->op == TOKcomma)
        {
            CommaExp *e = (CommaExp *)(*exp);
            Statement *s1 = inlineScanExpAsStatement(&e->e1);
            Statement *s2 = inlineScanExpAsStatement(&e->e2);
            if (!s1 && !s2)
                return NULL;
            Statements *a = new Statements();
            a->push(!s1 ? new ExpStatement(e->e1->loc, e->e1) : s1);
            a->push(!s2 ? new ExpStatement(e->e2->loc, e->e2) : s2);
            return new CompoundStatement((*exp)->loc, a);
        }

        // inline as an expression
        inlineScan(exp);
        return NULL;
    }

    void visit(ExpStatement *s)
    {
    #if LOG
        printf("ExpStatement::inlineScan(%s)\n", s->toChars());
    #endif
        if (!s->exp)
            return;

        sresult = inlineScanExpAsStatement(&s->exp);
    }

    void visit(CompoundStatement *s)
    {
        for (size_t i = 0; i < s->statements->length; i++)
        {
            inlineScan(&(*s->statements)[i]);
        }
    }

    void visit(UnrolledLoopStatement *s)
    {
        for (size_t i = 0; i < s->statements->length; i++)
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
        inlineScan(&s->_body);
    }

    void visit(DoStatement *s)
    {
        inlineScan(&s->_body);
        inlineScan(&s->condition);
    }

    void visit(ForStatement *s)
    {
        inlineScan(&s->_init);
        inlineScan(&s->condition);
        inlineScan(&s->increment);
        inlineScan(&s->_body);
    }

    void visit(ForeachStatement *s)
    {
        inlineScan(&s->aggr);
        inlineScan(&s->_body);
    }

    void visit(ForeachRangeStatement *s)
    {
        inlineScan(&s->lwr);
        inlineScan(&s->upr);
        inlineScan(&s->_body);
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
        inlineScan(&s->_body);
        Statement *sdefault = s->sdefault;
        inlineScan(&sdefault);
        s->sdefault = (DefaultStatement *)sdefault;
        if (s->cases)
        {
            for (size_t i = 0; i < s->cases->length; i++)
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
        inlineScan(&s->_body);
    }

    void visit(WithStatement *s)
    {
        inlineScan(&s->exp);
        inlineScan(&s->_body);
    }

    void visit(TryCatchStatement *s)
    {
        inlineScan(&s->_body);
        if (s->catches)
        {
            for (size_t i = 0; i < s->catches->length; i++)
            {
                Catch *c = (*s->catches)[i];
                inlineScan(&c->handler);
            }
        }
    }

    void visit(TryFinallyStatement *s)
    {
        inlineScan(&s->_body);
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
        assert(sresult == NULL);
        (*s)->accept(this);
        if (sresult)
        {
            *s = sresult;
            sresult = NULL;
        }
    }

    /* -------------------------- */

    void arrayInlineScan(Expressions *arguments)
    {
        if (arguments)
        {
            for (size_t i = 0; i < arguments->length; i++)
            {
                inlineScan(&(*arguments)[i]);
            }
        }
    }

    void visit(Expression *)
    {
    }

    void scanVar(Dsymbol *s)
    {
        //printf("scanVar(%s %s)\n", s->kind(), s->toPrettyChars());
        VarDeclaration *vd = s->isVarDeclaration();
        if (vd)
        {
            TupleDeclaration *td = vd->toAlias()->isTupleDeclaration();
            if (td)
            {
                for (size_t i = 0; i < td->objects->length; i++)
                {
                    DsymbolExp *se = (DsymbolExp *)(*td->objects)[i];
                    assert(se->op == TOKdsymbol);
                    scanVar(se->s);    // TODO
                }
            }
            else if (vd->_init)
            {
                if (ExpInitializer *ie = vd->_init->isExpInitializer())
                {
                    inlineScan(&ie->exp);
                }
            }
        }
        else
        {
            s->accept(this);
        }
    }

    void visit(DeclarationExp *e)
    {
        //printf("DeclarationExp::inlineScan()\n");
        scanVar(e->declaration);
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
        // Look for NRVO, as inlining NRVO function returns require special handling
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

                visitCallExp(ce, e->e1, false);
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
        //printf("CallExp::inlineScan() %s\n", e->toChars())
        visitCallExp(e, NULL, false);
    }

    /**************************************
     * Check function call to see if can be inlined,
     * and then inline it if it can.
     * Params:
     *  e = the function call
     *  eret = if !null, then this is the lvalue of the nrvo function result
     *  asStatements = if inline as statements rather than as an Expression
     * Returns:
     *  this->eresult if asStatements == false
     *  this->sresult if asStatements == true
     */
    void visitCallExp(CallExp *e, Expression *eret, bool asStatements)
    {
        inlineScan(&e->e1);
        arrayInlineScan(e->arguments);

        //printf("visitCallExp() %s\n", e->toChars());
        FuncDeclaration *fd = NULL;
        if (e->e1->op == TOKvar)
        {
            VarExp *ve = (VarExp *)e->e1;
            fd = ve->var->isFuncDeclaration();
            if (fd && fd != parent && canInline(fd, 0, 0, asStatements))
            {
                expandInline(e->loc, fd, parent, eret, NULL, e->arguments, asStatements, &eresult, &sresult, &again);
            }
        }
        else if (e->e1->op == TOKdotvar)
        {
            DotVarExp *dve = (DotVarExp *)e->e1;
            fd = dve->var->isFuncDeclaration();

            if (fd && fd != parent && canInline(fd, 1, 0, asStatements))
            {
                if (dve->e1->op == TOKcall &&
                    dve->e1->type->toBasetype()->ty == Tstruct)
                {
                    /* To create ethis, we'll need to take the address
                     * of dve->e1, but this won't work if dve->e1 is
                     * a function call.
                     */
                }
                else
                {
                    expandInline(e->loc, fd, parent, eret, dve->e1, e->arguments, asStatements, &eresult, &sresult, &again);
                }
            }
        }
        else
            return;

        if (global.params.verbose && (eresult || sresult))
            fprintf(global.stdmsg, "inlined   %s =>\n          %s\n", fd->toPrettyChars(), parent->toPrettyChars());

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
        inlineScan(&e->basis);
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
        assert(eresult == NULL);
        (*e)->accept(this);
        if (eresult)
        {
            *e = eresult;
            eresult = NULL;
        }
    }

    /*************************************
     * Look for function inlining possibilities.
     */

    void visit(Dsymbol *)
    {
        // Most Dsymbols aren't functions
    }

    void visit(FuncDeclaration *fd)
    {
    #if LOG
        printf("FuncDeclaration::inlineScan('%s')\n", fd->toPrettyChars());
    #endif
        if ((fd->isUnitTestDeclaration() && !global.params.useUnitTests) ||
            fd->flags & FUNCFLAGinlineScanned)
            return;

        if (fd->fbody && !fd->naked)
        {
            bool againsave = again;
            FuncDeclaration *parentsave = parent;
            parent = fd;
            do
            {
                again = false;
                fd->inlineNest++;
                fd->flags |= FUNCFLAGinlineScanned;
                inlineScan(&fd->fbody);
                fd->inlineNest--;
            }
            while (again);
            again = againsave;
            parent = parentsave;
        }
    }

    void visit(AttribDeclaration *d)
    {
        Dsymbols *decls = d->include(NULL);

        if (decls)
        {
            for (size_t i = 0; i < decls->length; i++)
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
            for (size_t i = 0; i < ad->members->length; i++)
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
            for (size_t i = 0; i < ti->members->length; i++)
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

    for (size_t i = 0; i < m->members->length; i++)
    {
        Dsymbol *s = (*m->members)[i];
        //if (global.params.verbose)
        //    fprintf(global.stdmsg, "inline scan symbol %s\n", s->toChars());
        InlineScanVisitor v;
        s->accept(&v);
    }
    m->semanticRun = PASSinlinedone;
}

bool canInline(FuncDeclaration *fd, int hasthis, int hdrscan, bool statementsToo)
{
    int cost;

#define CANINLINE_LOG 0

#if CANINLINE_LOG
    printf("FuncDeclaration::canInline(hasthis = %d, statementsToo = %d, '%s')\n", hasthis, statementsToo, fd->toPrettyChars());
#endif

    if (fd->needThis() && !hasthis)
        return false;

    if (fd->inlineNest)
    {
#if CANINLINE_LOG
        printf("\t1: no, inlineNest = %d, semanticRun = %d\n", fd->inlineNest, fd->semanticRun);
#endif
        return false;
    }

    if (fd->semanticRun < PASSsemantic3 && !hdrscan)
    {
        if (!fd->fbody)
            return false;
        if (!fd->functionSemantic3())
            return false;
        Module::runDeferredSemantic3();
        if (global.errors)
            return false;
        assert(fd->semanticRun >= PASSsemantic3done);
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

    switch (fd->inlining)
    {
        case PINLINEdefault:
            break;

        case PINLINEalways:
            break;

        case PINLINEnever:
            return false;
        default:
            assert(0);
    }

    if (fd->type)
    {
        assert(fd->type->ty == Tfunction);
        TypeFunction *tf = (TypeFunction *)fd->type;
        if (tf->parameterList.varargs == VARARGvariadic)   // no variadic parameter lists
            goto Lno;

        /* Don't inline a function that returns non-void, but has
         * no or multiple return expression.
         * No statement inlining for non-voids.
         */
        if (tf->next && tf->next->ty != Tvoid &&
            (!(fd->hasReturnExp & 1) || statementsToo) &&
            !hdrscan)
            goto Lno;

        /* Bugzilla 14560: If fd returns void, all explicit `return;`s
         * must not appear in the expanded result.
         * See also ReturnStatement::inlineAsStatement().
         */
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
        (!hdrscan && (fd->isSynchronized() ||
                      fd->isImportedSymbol() ||
                      fd->hasNestedFrameRefs() ||
                      (fd->isVirtual() && !fd->isFinalFunc()))))
    {
        goto Lno;
    }

    // cannot inline functions as statement if they have multiple
    //  return statements
    if ((fd->hasReturnExp & 16) && statementsToo)
    {
#if CANINLINE_LOG
        printf("\t5: no %s\n", fd->toChars());
#endif
        goto Lno;
    }

    {
        cost = inlineCostFunction(fd, hasthis, hdrscan);
    }
#if CANINLINE_LOG
    printf("\tcost = %d for %s\n", cost, fd->toChars());
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
            cost = inlineCostFunction(fd, hasthis, hdrscan);
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
    if (fd->inlining == PINLINEalways)
        fd->error("cannot inline function");

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

/***********************************************************
 * Expand a function call inline,
 *      ethis.fd(arguments)
 *
 * Params:
 *      callLoc = location of CallExp
 *      fd = function to expand
 *      parent = function that the call to fd is being expanded into
 *      eret = expression describing the lvalue of where the return value goes
 *      ethis = 'this' reference
 *      arguments = arguments passed to fd
 *      asStatements = expand to Statements rather than Expressions
 *      eresult = if expanding to an expression, this is where the expression is written to
 *      sresult = if expanding to a statement, this is where the statement is written to
 *      again = if true, then fd can be inline scanned again because there may be
 *           more opportunities for inlining
 */
static void expandInline(Loc callLoc, FuncDeclaration *fd, FuncDeclaration *parent,
        Expression *eret, Expression *ethis, Expressions *arguments, bool asStatements,
        Expression **eresult, Statement **sresult, bool *again)
{
    InlineDoState ids;
    memset(&ids, 0, sizeof(ids));
    TypeFunction *tf = (TypeFunction*)fd->type;

#define EXPANDINLINE_LOG 0

#if LOG || CANINLINE_LOG || EXPANDINLINE_LOG
    printf("FuncDeclaration::expandInline('%s')\n", fd->toChars());
#endif
#if EXPANDINLINE_LOG
    if (eret) printf("\teret = %s\n", eret->toChars());
    if (ethis) printf("\tethis = %s\n", ethis->toChars());
#endif

    ids.parent = parent;
    ids.fd = fd;

    if (fd->isNested())
    {
        if (!parent->inlinedNestedCallees)
            parent->inlinedNestedCallees = new FuncDeclarations();
        parent->inlinedNestedCallees->push(fd);
    }

    VarDeclaration *vret = NULL;    // will be set the function call result
    if (eret)
    {
        if (eret->op == TOKvar)
        {
            vret = ((VarExp *)eret)->var->isVarDeclaration();
            assert(!(vret->storage_class & (STCout | STCref)));
            eret = NULL;
        }
        else
        {
            /* Inlining:
             *   this.field = foo();   // inside constructor
             */
            ExpInitializer *ei = new ExpInitializer(callLoc, NULL);
            Identifier *tmp = Identifier::generateId("__retvar");
            vret = new VarDeclaration(fd->loc, eret->type, tmp, ei);
            vret->storage_class |= STCtemp | STCref;
            vret->linkage = LINKd;
            vret->parent = parent;

            ei->exp = new ConstructExp(fd->loc, vret, eret);
            ei->exp->type = vret->type;

            Expression *de = new DeclarationExp(fd->loc, vret);
            de->type = Type::tvoid;
            eret = de;
        }

        if (!asStatements && fd->nrvo_var)
        {
            ids.from.push(fd->nrvo_var);
            ids.to.push(vret);
        }
    }
    else
    {
        if (!asStatements && fd->nrvo_var)
        {
            Identifier *tmp = Identifier::generateId("__retvar");
            vret = new VarDeclaration(fd->loc, fd->nrvo_var->type, tmp, NULL);
            assert(!tf->isref);
            vret->storage_class = STCtemp | STCrvalue;
            vret->linkage = tf->linkage;
            vret->parent = parent;

            DeclarationExp *de = new DeclarationExp(fd->loc, vret);
            de->type = Type::tvoid;
            eret = de;

            ids.from.push(fd->nrvo_var);
            ids.to.push(vret);
        }
    }

    // Set up vthis
    VarDeclaration *vthis = NULL;
    if (ethis)
    {
        Expression *e0 = NULL;
        ethis = Expression::extractLast(ethis, &e0);
        if (ethis->op == TOKvar)
        {
            vthis = ((VarExp *)ethis)->var->isVarDeclaration();
        }
        else
        {
            //assert(ethis->type->ty != Tpointer)
            if (ethis->type->ty == Tpointer)
            {
                Type *t = ethis->type->nextOf();
                ethis = new PtrExp(ethis->loc, ethis);
                ethis->type = t;
            }

            ExpInitializer *ei = new ExpInitializer(fd->loc, ethis);
            vthis = new VarDeclaration(fd->loc, ethis->type, Id::This, ei);
            if (ethis->type->ty != Tclass)
                vthis->storage_class = STCref;
            else
                vthis->storage_class = STCin;
            vthis->linkage = LINKd;
            vthis->parent = parent;

            ei->exp = new ConstructExp(fd->loc, vthis, ethis);
            ei->exp->type = vthis->type;

            Expression *de = new DeclarationExp(fd->loc, vthis);
            de->type = Type::tvoid;
            e0 = Expression::combine(e0, de);
        }
        ethis = e0;

        ids.vthis = vthis;
    }

    // Set up parameters
    Expression *eparams = NULL;
    if (arguments && arguments->length)
    {
        assert(fd->parameters->length == arguments->length);

        for (size_t i = 0; i < arguments->length; i++)
        {
            VarDeclaration *vfrom = (*fd->parameters)[i];
            Expression *arg = (*arguments)[i];

            ExpInitializer *ei = new ExpInitializer(vfrom->loc, arg);
            VarDeclaration *vto = new VarDeclaration(vfrom->loc, vfrom->type, vfrom->ident, ei);
            vto->storage_class |= vfrom->storage_class & (STCtemp | STCin | STCout | STClazy | STCref);
            vto->linkage = vfrom->linkage;
            vto->parent = parent;
            //printf("vto = '%s', vto->storage_class = x%x\n", vto->toChars(), vto->storage_class);
            //printf("vto->parent = '%s'\n", parent->toChars());

            // Even if vto is STClazy, `vto = arg` is handled correctly in glue layer.
            ei->exp = new BlitExp(vto->loc, vto, arg);
            ei->exp->type = vto->type;
            //arg->type->print();
            //ei->exp->print();

            ids.from.push(vfrom);
            ids.to.push(vto);

            DeclarationExp *de = new DeclarationExp(vto->loc, vto);
            de->type = Type::tvoid;

            eparams = Expression::combine(eparams, de);

            /* If function pointer or delegate parameters are present,
             * inline scan again because if they are initialized to a symbol,
             * any calls to the fp or dg can be inlined.
             */
            if (vfrom->type->ty == Tdelegate ||
                (vfrom->type->ty == Tpointer && vfrom->type->nextOf()->ty == Tfunction))
            {
                if (arg->op == TOKvar)
                {
                    VarExp *ve = (VarExp *)arg;
                    if (ve->var->isFuncDeclaration())
                        *again = true;
                }
                else if (arg->op == TOKsymoff)
                {
                    SymOffExp *se = (SymOffExp *)arg;
                    if (se->var->isFuncDeclaration())
                        *again = true;
                }
                else if (arg->op == TOKfunction || arg->op == TOKdelegate)
                    *again = true;
            }
        }
    }

    if (asStatements)
    {
        /* Construct:
         *  { eret; ethis; eparams; fd.fbody; }
         * or:
         *  { eret; ethis; try { eparams; fd.fbody; } finally { vthis.edtor; } }
         */

        Statements *as = new Statements();
        if (eret)
            as->push(new ExpStatement(callLoc, eret));
        if (ethis)
            as->push(new ExpStatement(callLoc, ethis));

        Statements *as2 = as;
        if (vthis && !vthis->isDataseg())
        {
            if (vthis->needsScopeDtor())
            {
                // same with ExpStatement::scopeCode()
                as2 = new Statements();
                vthis->storage_class |= STCnodtor;
            }
        }

        if (eparams)
            as2->push(new ExpStatement(callLoc, eparams));

        if (as2 != as)
        {
            as->push(new TryFinallyStatement(callLoc,
                        new CompoundStatement(callLoc, as2),
                        new DtorExpStatement(callLoc, vthis->edtor, vthis)));

        }

        fd->inlineNest++;
        Statement *s = inlineAsStatement(fd->fbody, &ids);
        fd->inlineNest--;
        as->push(s);

        *sresult = new ScopeStatement(callLoc, new CompoundStatement(Loc(), as), Loc());

#if EXPANDINLINE_LOG
        printf("\n[%s] %s expandInline sresult =\n%s\n",
            callLoc.toChars(), fd->toPrettyChars(), (*sresult)->toChars());
#endif
    }
    else
    {
        /* Construct:
         *  (eret, ethis, eparams, fd.fbody)
         */

        fd->inlineNest++;
        Expression *e = doInline(fd->fbody, &ids);
        fd->inlineNest--;
        //e->type->print();
        //e->print();
        //e->print();

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
            ExpInitializer* ei = new ExpInitializer(callLoc, e);
            Identifier* tmp = Identifier::generateId("__inlineretval");
            VarDeclaration* vd = new VarDeclaration(callLoc, tf->next, tmp, ei);
            vd->storage_class = STCtemp | (tf->isref ? STCref : STCrvalue);
            vd->linkage = tf->linkage;
            vd->parent = parent;

            ei->exp = new ConstructExp(callLoc, vd, e);
            ei->exp->type = vd->type;

            DeclarationExp* de = new DeclarationExp(callLoc, vd);
            de->type = Type::tvoid;

            // Chain the two together:
            //   ( typeof(return) __inlineretval = ( inlined body )) , __inlineretval
            e = Expression::combine(de, new VarExp(callLoc, vd));

            //fprintf(stderr, "CallExp::inlineScan: e = "); e->print();
        }

        // Bugzilla 15210
        if (tf->next->ty == Tvoid && e && e->type->ty != Tvoid)
        {
            e = new CastExp(callLoc, e, Type::tvoid);
            e->type = Type::tvoid;
        }

        *eresult = Expression::combine(*eresult, eret);
        *eresult = Expression::combine(*eresult, ethis);
        *eresult = Expression::combine(*eresult, eparams);
        *eresult = Expression::combine(*eresult, e);

#if EXPANDINLINE_LOG
        printf("\n[%s] %s expandInline eresult = %s\n",
            callLoc.toChars(), fd->toPrettyChars(), (*eresult)->toChars());
#endif
    }

    // Need to reevaluate whether parent can now be inlined
    // in expressions, as we might have inlined statements
    parent->inlineStatusExp = ILSuninitialized;
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

    int cost = inlineCostExpression(e);
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

