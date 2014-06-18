
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/lexer.h
 */

#ifndef DMD_CONDITIONVISITOR_H
#define DMD_CONDITIONVISITOR_H

#ifdef __DMC__
#pragma once
#endif /* __DMC__ */

#include "expression.h"
#include "declaration.h"

class ConditionVisitor : public Visitor
{
public:
    bool invert;
    bool deadcode;

    ConditionVisitor() : invert(false), deadcode(false) { }

    void visit(Expression *e) { }

    void visit(CastExp *e)
    {
        push(e, TOKnotequal, NULL);
    }

    void visit(EqualExp *e)
    {
        push(e->e1, e->op, e->e2);
    }

    void visit(CmpExp *e)
    {
        push(e->e1, e->op, e->e2);
    }

    void visit(VarExp *e)
    {
        push(e, TOKnotequal, NULL);
    }

    void visit(NotExp *e)
    {
        invert = !invert;
        e->e1->accept(this);
        invert = !invert;
    }

    void visit(OrOrExp *e)
    {
        if (invert)
        {
            e->e1->accept(this);
            e->e2->accept(this);
        }
    }

    void visit(AndAndExp *e)
    {
        if (!invert)
        {
            e->e1->accept(this);
            e->e2->accept(this);
        }
    }

    void popRanges()
    {
        for (int i=0; i<toPop.dim; ++i)
        {
            toPop[i]->rangeStack = toPop[i]->rangeStack->next;
        }
    }

private:
    Array<VarDeclaration *> toPop;
    VarDeclaration *getVarDecl(Expression *e);

    void push(Expression *e1, TOK op, Expression *e2);
    void pushRange(VarDeclaration *vd, IntRange ir);
};

#endif
