
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/delegatize.c
 */

#include <stdio.h>
#include <assert.h>

#include "mars.h"
#include "expression.h"
#include "statement.h"
#include "mtype.h"
#include "utf.h"
#include "declaration.h"
#include "aggregate.h"
#include "scope.h"
#include "init.h"
#include "tokens.h"

/********************************************
 * Convert from expression to delegate that returns the expression,
 * i.e. convert:
 *      expr
 * to:
 *      typeof(expr) delegate() { return expr; }
 */

bool walkPostorder(Expression *e, StoppableVisitor *v);
void lambdaSetParent(Expression *e, Scope *sc);
void lambdaCheckForNestedRef(Expression *e, Scope *sc);

Expression *toDelegate(Expression *e, Scope *sc)
{
    //printf("Expression::toDelegate(t = %s) %s\n", e->type->toChars(), e->toChars());
    Loc loc = e->loc;
    Type *t = e->type;

    TypeFunction *tf = new TypeFunction(NULL, t, 0, LINKd);
    if (t->hasWild())
        tf->mod = MODwild;
    FuncLiteralDeclaration *fld =
        new FuncLiteralDeclaration(loc, loc, tf, TOKdelegate, NULL);

    sc = sc->push();
    sc->parent = fld;           // set current function to be the delegate
    lambdaSetParent(e, sc);
    lambdaCheckForNestedRef(e, sc);
    sc = sc->pop();

    Statement *s;
    if (t->ty == Tvoid)
        s = new ExpStatement(loc, e);
    else
        s = new ReturnStatement(loc, e);
    fld->fbody = s;

    e = new FuncExp(loc, fld);
    e = e->semantic(sc);
    return e;
}

/******************************************
 * Patch the parent of declarations to be the new function literal.
 */
void lambdaSetParent(Expression *e, Scope *sc)
{
    class LambdaSetParent : public StoppableVisitor
    {
        Scope *sc;
    public:
        LambdaSetParent(Scope *sc) : sc(sc) {}

        void visit(Expression *)
        {
        }

        void visit(DeclarationExp *e)
        {
            e->declaration->parent = sc->parent;
        }

        void visit(IndexExp *e)
        {
            if (e->lengthVar)
            {
                //printf("lengthVar\n");
                e->lengthVar->parent = sc->parent;
            }
        }

        void visit(SliceExp *e)
        {
            if (e->lengthVar)
            {
                //printf("lengthVar\n");
                e->lengthVar->parent = sc->parent;
            }
        }
    };

    LambdaSetParent lsp(sc);
    walkPostorder(e, &lsp);
}

/*******************************************
 * Look for references to variables in a scope enclosing the new function literal.
 */
void lambdaCheckForNestedRef(Expression *e, Scope *sc)
{
    class LambdaCheckForNestedRef : public StoppableVisitor
    {
        Scope *sc;
    public:
        LambdaCheckForNestedRef(Scope *sc) : sc(sc) {}

        void visit(Expression *)
        {
        }

        void visit(SymOffExp *e)
        {
            VarDeclaration *v = e->var->isVarDeclaration();
            if (v)
                v->checkNestedReference(sc, Loc());
        }

        void visit(VarExp *e)
        {
            VarDeclaration *v = e->var->isVarDeclaration();
            if (v)
                v->checkNestedReference(sc, Loc());
        }

        void visit(ThisExp *e)
        {
            VarDeclaration *v = e->var->isVarDeclaration();
            if (v)
                v->checkNestedReference(sc, Loc());
        }

        void visit(DeclarationExp *e)
        {
            VarDeclaration *v = e->declaration->isVarDeclaration();
            if (v)
            {
                v->checkNestedReference(sc, Loc());

                /* Some expressions cause the frontend to create a temporary.
                 * For example, structs with cpctors replace the original
                 * expression e with:
                 *  __cpcttmp = __cpcttmp.cpctor(e);
                 *
                 * In this instance, we need to ensure that the original
                 * expression e does not have any nested references by
                 * checking the declaration initializer too.
                 */
                if (v->init && v->init->isExpInitializer())
                {
                    Expression *ie = v->init->toExpression();
                    lambdaCheckForNestedRef(ie, sc);
                }
            }
        }
    };

    LambdaCheckForNestedRef lcnr(sc);
    walkPostorder(e, &lcnr);
}

