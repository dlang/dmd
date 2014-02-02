
// Compiler implementation of the D programming language
// Copyright (c) 1999-2011 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

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

/********************************************
 * Convert from expression to delegate that returns the expression,
 * i.e. convert:
 *      expr
 * to:
 *      t delegate() { return expr; }
 */

bool walkPostorder(Expression *e, StoppableVisitor *v);
void lambdaSetParent(Expression *e, Scope *sc);
void lambdaCheckForNestedRef(Expression *e, Scope *sc);

Expression *Expression::toDelegate(Scope *sc, Type *t)
{
    //printf("Expression::toDelegate(t = %s) %s\n", t->toChars(), toChars());
    Type *tw = t->semantic(loc, sc);
    Type *tc = t->substWildTo(MODconst)->semantic(loc, sc);
    TypeFunction *tf = new TypeFunction(NULL, tc, 0, LINKd);
    if (tw != tc) tf->mod = MODwild;                            // hack for bug7757
    (tf = (TypeFunction *)tf->semantic(loc, sc))->next = tw;    // hack for bug7757
    FuncLiteralDeclaration *fld =
        new FuncLiteralDeclaration(loc, loc, tf, TOKdelegate, NULL);
    Expression *e;
    sc = sc->push();
    sc->parent = fld;           // set current function to be the delegate
    e = this;
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

