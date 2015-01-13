
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
 * Params:
 *      gag     do not print error messages
 * Returns:
 *      true    errors occured
 */

bool checkEscape(Scope *sc, Expression *e, bool gag)
{
    //printf("[%s] checkEscape, e = %s\n", e->loc.toChars(), e->toChars());

    class EscapeVisitor : public Visitor
    {
    public:
        Scope *sc;
        bool gag;
        bool result;

        EscapeVisitor(Scope *sc, bool gag)
            : sc(sc), gag(gag), result(false)
        {
        }

        void error(Loc loc, const char *format, Dsymbol *s)
        {
            if (!gag)
                ::error(loc, format, s->toChars());
            result = true;
        }

        void check(Loc loc, Declaration *d)
        {
            VarDeclaration *v = d->isVarDeclaration();
            if (v && v->toParent2() == sc->func)
            {
                if (v->isDataseg())
                    return;
                if ((v->storage_class & (STCref | STCout)) == 0)
                    error(loc, "escaping reference to local %s", v);
            }
        }

        void visit(Expression *e)
        {
        }

        void visit(AddrExp *e)
        {
            result |= checkEscapeRef(sc, e->e1, gag);
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
                            error(e->loc, "escaping reference to scope local %s", v);
                            return;
                        }
                    }
                }
                if (v->storage_class & STCvariadic)
                {
                    if (tb->ty == Tarray || tb->ty == Tsarray)
                        error(e->loc, "escaping reference to variadic parameter %s", v);
                }
            }
        }

        void visit(TupleExp *e)
        {
            for (size_t i = 0; i < e->exps->dim; i++)
            {
                (*e->exps)[i]->accept(this);
            }
        }

        void visit(ArrayLiteralExp *e)
        {
            Type *tb = e->type->toBasetype();
            if (tb->ty == Tsarray || tb->ty == Tarray)
            {
                for (size_t i = 0; i < e->elements->dim; i++)
                {
                    (*e->elements)[i]->accept(this);
                }
            }
        }

        void visit(StructLiteralExp *e)
        {
            if (e->elements)
            {
                for (size_t i = 0; i < e->elements->dim; i++)
                {
                    Expression *ex = (*e->elements)[i];
                    if (ex)
                        ex->accept(this);
                }
            }
        }

        void visit(NewExp *e)
        {
            Type *tb = e->newtype->toBasetype();
            if (tb->ty == Tstruct && !e->member && e->arguments)
            {
                for (size_t i = 0; i < e->arguments->dim; i++)
                {
                    Expression *ex = (*e->arguments)[i];
                    if (ex)
                        ex->accept(this);
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
                        error(e->loc, "escaping reference to local %s", v);
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
                        error(e->loc, "escaping reference to the payload of variadic parameter %s", v);
                        return;
                    }
                }
            }
            Type *t1b = e->e1->type->toBasetype();
            if (t1b->ty == Tsarray)
                result |= checkEscapeRef(sc, e->e1, gag);
            else
                e->e1->accept(this);
        }

        void visit(BinExp *e)
        {
            Type *tb = e->type->toBasetype();
            if (tb->ty == Tpointer)
            {
                e->e1->accept(this);
                e->e2->accept(this);
            }
        }

        void visit(BinAssignExp *e)
        {
            e->e2->accept(this);
        }

        void visit(AssignExp *e)
        {
            e->e2->accept(this);
        }

        void visit(CommaExp *e)
        {
            e->e2->accept(this);
        }

        void visit(CondExp *e)
        {
            e->e1->accept(this);
            e->e2->accept(this);
        }
    };

    EscapeVisitor v(sc, gag);
    e->accept(&v);
    return v.result;
}

/************************************
 * Detect cases where returning 'e' by ref can result in a reference to the stack
 * being returned.
 * Params:
 *      gag     do not print error messages
 * Returns:
 *      true    errors occured
 */

bool checkEscapeRef(Scope *sc, Expression *e, bool gag)
{
    //printf("[%s] checkEscapeRef, e = %s\n", e->loc.toChars(), e->toChars());

    class EscapeRefVisitor : public Visitor
    {
    public:
        Scope *sc;
        bool gag;
        bool result;

        EscapeRefVisitor(Scope *sc, bool gag)
            : sc(sc), gag(gag), result(false)
        {
        }

        void error(Loc loc, const char *format, Dsymbol *s)
        {
            if (!gag)
                ::error(loc, format, s->toChars());
            result = true;
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
                    error(loc, "escaping reference to local variable %s", v);
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
                        ex->accept(this);
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
            result |= checkEscape(sc, e->e1, gag);
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
                            error(e->loc, "escaping reference to the payload of variadic parameter %s", v);
                            return;
                        }
                    }
                }
            }

            Type *tb = e->e1->type->toBasetype();
            if (tb->ty == Tsarray)
            {
                e->e1->accept(this);
            }
        }

        void visit(DotVarExp *e)
        {
            Type *t1b = e->e1->type->toBasetype();
            if (t1b->ty == Tclass)
                result |= checkEscape(sc, e->e1, gag);
            else
                e->e1->accept(this);
        }

        void visit(BinAssignExp *e)
        {
            e->e1->accept(this);
        }

        void visit(AssignExp *e)
        {
            e->e1->accept(this);
        }

        void visit(CommaExp *e)
        {
            e->e2->accept(this);
        }

        void visit(CondExp *e)
        {
            e->e1->accept(this);
            e->e2->accept(this);
        }
    };
    EscapeRefVisitor v(sc, gag);
    e->accept(&v);
    return v.result;
}
