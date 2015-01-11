
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2015 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/escape.c
 */

#include "expression.h"
#include "declaration.h"

/************************************
 * Detect cases where pointers to the stack can 'escape' the
 * lifetime of the stack frame.
 */

void checkEscape(Expression *e)
{
    //printf("[%s] checkEscape, e = %s\n", e->loc.toChars(), e->toChars());

    class EscapeVisitor : public Visitor
    {
    public:

        void visit(Expression *e)
        {
        }

        void visit(SymOffExp *e)
        {
            VarDeclaration *v = e->var->isVarDeclaration();
            if (v)
            {
                if (!v->isDataseg() && !(v->storage_class & (STCref | STCout)))
                {
                    /* BUG: This should be allowed:
                     *   void foo() {
                     *     int a;
                     *     int* bar() { return &a; }
                     *   }
                     */
                    e->error("escaping reference to local %s", v->toChars());
                }
            }
        }

        void visit(VarExp *e)
        {
            VarDeclaration *v = e->var->isVarDeclaration();
            if (v)
            {
                Type *tb = v->type->toBasetype();
                // if reference type
                if (tb->ty == Tarray || tb->ty == Tsarray || tb->ty == Tclass || tb->ty == Tdelegate)
                {
                    if (v->isScope() && (!v->noscope || tb->ty == Tclass))
                        e->error("escaping reference to scope local %s", v->toChars());
                    else if (v->storage_class & STCvariadic)
                        e->error("escaping reference to variadic parameter %s", v->toChars());
                }
            }
        }

        void visit(TupleExp *e)
        {
            for (size_t i = 0; i < e->exps->dim; i++)
            {
                checkEscape((*e->exps)[i]);
            }
        }

        void visit(AddrExp *e)
        {
            checkEscapeRef(e->e1);
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
                if (v)
                {
                    if (!v->isDataseg() && !v->isParameter())
                        e->error("escaping reference to local %s", v->toChars());
                }
            }
        }

        void visit(SliceExp *e)
        {
            checkEscape(e->e1);
        }

        void visit(CommaExp *e)
        {
            checkEscape(e->e2);
        }

        void visit(CondExp *e)
        {
            checkEscape(e->e1);
            checkEscape(e->e2);
        }
    };

    EscapeVisitor v;
    e->accept(&v);
}

void checkEscapeRef(Expression *e)
{
    //printf("[%s] checkEscapeRef, e = %s\n", e->loc.toChars(), e->toChars());

    class EscapeRefVisitor : public Visitor
    {
    public:

        void visit(Expression *e)
        {
        }

        void visit(VarExp *e)
        {
            VarDeclaration *v = e->var->isVarDeclaration();
            if (v)
            {
                if (!v->isDataseg() && !(v->storage_class & (STCref | STCout)))
                    e->error("escaping reference to local variable %s", v->toChars());
            }
        }

        void visit(PtrExp *e)
        {
            checkEscape(e->e1);
        }

        void visit(SliceExp *e)
        {
            checkEscapeRef(e->e1);
        }

        void visit(CommaExp *e)
        {
            checkEscapeRef(e->e2);
        }

        void visit(CondExp *e)
        {
            checkEscapeRef(e->e1);
            checkEscapeRef(e->e2);
        }
    };
    EscapeRefVisitor v;
    e->accept(&v);
}
