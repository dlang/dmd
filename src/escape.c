
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2015 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/escape.c
 */

#include "init.h"
#include "expression.h"
#include "scope.h"
#include "declaration.h"

/************************************
 * Detect cases where pointers to the stack can 'escape' the
 * lifetime of the stack frame.
 */

void checkEscape(Scope *sc, Expression *e)
{
    //printf("[%s] checkEscape, e = %s\n", e->loc.toChars(), e->toChars());

    class EscapeVisitor : public Visitor
    {
    public:
        Scope *sc;

        EscapeVisitor(Scope *sc)
            : sc(sc)
        {
        }

        void check(Loc loc, Declaration *d)
        {
            VarDeclaration *v = d->isVarDeclaration();
            if (v && v->toParent2() == sc->func)
            {
                if (v->isDataseg())
                    return;
                if ((v->storage_class & (STCref | STCout)) == 0)
                    error(loc, "escaping reference to local %s", v->toChars());
            }
        }

        void visit(Expression *e)
        {
        }

        void visit(AddrExp *e)
        {
            checkEscapeRef(sc, e->e1);
        }

        void visit(SymOffExp *e)
        {
            check(e->loc, e->var);
        }

        void visit(VarExp *e)
        {
            VarDeclaration *v = e->var->isVarDeclaration();
            if (v)
            {
                Type *tb = v->type->toBasetype();
                if (v->isScope())
                {
                    /* Today, scope attribute almost doesn't work for escape analysis.
                     * Until the semantics will be completed, it should be left as-is.
                     * See also: fail_compilation/fail_scope.d
                     */
                    if (tb->ty == Tarray || tb->ty == Tsarray || tb->ty == Tclass || tb->ty == Tdelegate)
                    {
                        if ((!v->noscope || tb->ty == Tclass))
                        {
                            e->error("escaping reference to scope local %s", v->toChars());
                            return;
                        }
                    }
                }
                if (v->storage_class & STCvariadic)
                {
                    if (tb->ty == Tarray || tb->ty == Tsarray)
                        e->error("escaping reference to variadic parameter %s", v->toChars());
                }
            }
        }

        void visit(TupleExp *e)
        {
            for (size_t i = 0; i < e->exps->dim; i++)
            {
                checkEscape(sc, (*e->exps)[i]);
            }
        }

        void visit(ArrayLiteralExp *e)
        {
            Type *tb = e->type->toBasetype();
            if (tb->ty == Tsarray || tb->ty == Tarray)
            {
                for (size_t i = 0; i < e->elements->dim; i++)
                {
                    checkEscape(sc, (*e->elements)[i]);
                }
            }
        }

        void visit(StructLiteralExp *e)
        {
            for (size_t i = 0; i < e->elements->dim; i++)
            {
                checkEscape(sc, (*e->elements)[i]);
            }
        }

        void visit(NewExp *e)
        {
            Type *tb = e->newtype->toBasetype();
            if (tb->ty == Tstruct && !e->member && e->arguments)
            {
                for (size_t i = 0; i < e->arguments->dim; i++)
                {
                    checkEscape(sc, (*e->arguments)[i]);
                }
            }
        }

        void visit(CastExp *e)
        {
            Type *tb = e->type->toBasetype();
            if (tb->ty == Tarray &&
                e->e1->op == TOKvar &&
                e->e1->type->toBasetype()->ty == Tsarray)
            {
                VarExp *ve = (VarExp *)e->e1;
                VarDeclaration *v = ve->var->isVarDeclaration();
                if (v && v->toParent2() == sc->func)
                {
                    if (!v->isDataseg() && !v->isParameter())
                        e->error("escaping reference to local %s", v->toChars());
                }
            }
        }

        void visit(SliceExp *e)
        {
            if (e->e1->op == TOKvar)
            {
                VarDeclaration *v = ((VarExp *)e->e1)->var->isVarDeclaration();
                Type *tb = e->type->toBasetype();
                if (v)
                {
                    if (tb->ty == Tsarray)
                        return;
                    if (v->storage_class & STCvariadic)
                    {
                        e->error("escaping reference to the payload of variadic parameter %s", v->toChars());
                        return;
                    }
                }
            }
            Type *t1b = e->e1->type->toBasetype();
            if (t1b->ty == Tsarray)
                checkEscapeRef(sc, e->e1);
            else
                checkEscape(sc, e->e1);
        }

        void visit(BinExp *e)
        {
            Type *tb = e->type->toBasetype();
            if (tb->ty == Tpointer)
            {
                checkEscape(sc, e->e1);
                checkEscape(sc, e->e2);
            }
        }

        void visit(BinAssignExp *e)
        {
            checkEscape(sc, e->e2);
        }

        void visit(AssignExp *e)
        {
            checkEscape(sc, e->e2);
        }

        void visit(CommaExp *e)
        {
            checkEscape(sc, e->e2);
        }

        void visit(CondExp *e)
        {
            checkEscape(sc, e->e1);
            checkEscape(sc, e->e2);
        }
    };

    EscapeVisitor v(sc);
    e->accept(&v);
}

void checkEscapeRef(Scope *sc, Expression *e)
{
    //printf("[%s] checkEscapeRef, e = %s\n", e->loc.toChars(), e->toChars());

    class EscapeRefVisitor : public Visitor
    {
    public:
        Scope *sc;

        EscapeRefVisitor(Scope *sc)
            : sc(sc)
        {
        }

        void check(Loc loc, Declaration *d)
        {
            VarDeclaration *v = d->isVarDeclaration();
            if (v && v->toParent2() == sc->func)
            {
                if (v->isDataseg())
                    return;
                if ((v->storage_class & (STCref | STCout)) == 0)
                {
                    error(loc, "escaping reference to local variable %s", v->toChars());
                    return;
                }
                if ((v->storage_class & (STCref | STCtemp)) == (STCref | STCtemp) &&
                    v->init)
                {
                    // (ref v = ex; ex)
                    if (ExpInitializer *ez = v->init->isExpInitializer())
                    {
                        assert(ez->exp && ez->exp->op == TOKconstruct);
                        Expression *ex = ((ConstructExp *)ez->exp)->e2;
                        checkEscapeRef(sc, ex);
                        return;
                    }
                }
            }
        }

        void visit(Expression *e)
        {
        }

        void visit(VarExp *e)
        {
            check(e->loc, e->var);
        }

        void visit(PtrExp *e)
        {
            checkEscape(sc, e->e1);
        }

        void visit(IndexExp *e)
        {
            if (e->e1->op == TOKvar)
            {
                VarDeclaration *v = ((VarExp *)e->e1)->var->isVarDeclaration();
                if (v && v->toParent2() == sc->func)
                {
                    Type *tb = v->type->toBasetype();
                    if (tb->ty == Tarray || tb->ty == Tsarray)
                    {
                        if (v->storage_class & STCvariadic)
                        {
                            e->error("escaping reference to the payload of variadic parameter %s", v->toChars());
                            return;
                        }
                    }
                }
            }

            Type *tb = e->e1->type->toBasetype();
            if (tb->ty == Tsarray)
            {
                checkEscapeRef(sc, e->e1);
            }
        }

        void visit(DotVarExp *e)
        {
            Type *t1b = e->e1->type->toBasetype();
            if (t1b->ty == Tclass)
                checkEscape(sc, e->e1);
            else
                checkEscapeRef(sc, e->e1);
        }

        void visit(BinAssignExp *e)
        {
            checkEscapeRef(sc, e->e1);
        }

        void visit(AssignExp *e)
        {
            checkEscapeRef(sc, e->e1);
        }

        void visit(CommaExp *e)
        {
            checkEscapeRef(sc, e->e2);
        }

        void visit(CondExp *e)
        {
            checkEscapeRef(sc, e->e1);
            checkEscapeRef(sc, e->e2);
        }
    };
    EscapeRefVisitor v(sc);
    e->accept(&v);
}
