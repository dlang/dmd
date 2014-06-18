
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/expression.c
 */

#include "conditionvisitor.h"

static TOK invertOp(TOK op)
{
    switch (op)
    {
    case TOKlt:
        return TOKge;
    case TOKle:
        return TOKgt;
    case TOKgt:
        return TOKle;
    case TOKge:
        return TOKlt;
    case TOKequal:
        return TOKnotequal;
    case TOKnotequal:
        return TOKequal;
    default:
        assert(0);
    }
}

static void fixupRanges(IntRange& v1, TOK op, IntRange& v2)
{
    switch (op)
    {
    case TOKle:
        v1 = IntRange(v1.imin, v2.imax <= v1.imax ? v2.imax : v1.imax);
        v2 = IntRange(v1.imin >= v2.imin ? v1.imin : v2.imin, v2.imax);
        break;
    case TOKlt:
        v1 = IntRange(v1.imin, v2.imax <= v1.imax ? v2.imax - 1 : v1.imax);
        v2 = IntRange(v1.imin >= v2.imin ? v1.imin + 1 : v2.imin, v2.imax);
        break;
    case TOKge:
        v1 = IntRange(v2.imin >= v1.imin ? v2.imin : v1.imin, v1.imax);
        v2 = IntRange(v2.imin, v1.imax <= v2.imax ? v1.imax : v2.imax);
        break;
    case TOKgt:
        v1 = IntRange(v2.imin >= v1.imin ? v2.imin + 1 : v1.imin, v1.imax);
        v2 = IntRange(v2.imin, v1.imax <= v2.imax ? v1.imax - 1: v2.imax);
        break;
    case TOKequal:
        v2 = v1 = v1.intersectWith(v2);
        break;
    case TOKnotequal:
        if (v1.imin == v1.imax)
            v2 = IntRange(v2.imin + (v1.imin == v2.imin), v2.imax - (v1.imax == v2.imax));
        else if (v2.imin == v2.imax)
            v1 = IntRange(v1.imin + (v1.imin == v2.imin), v1.imax - (v1.imax == v2.imax));
        break;
    default:
        assert(0);
    }
}

VarDeclaration *ConditionVisitor::getVarDecl(Expression *e)
{
    if (e->op == TOKcast)
        e = ((CastExp *)e)->e1;//FIXME unsafe
    VarDeclaration *vd = e->op == TOKvar && e->type->isscalar() ? ((VarExp *)e)->var->isVarDeclaration() : NULL;
    return vd && !vd->type->isMutable() ? vd : NULL;
}

void ConditionVisitor::push(Expression *e1, TOK op, Expression *e2)
{
    VarDeclaration *vd1 = getVarDecl(e1);
    VarDeclaration *vd2 = e2 ? getVarDecl(e2) : NULL;
    if (vd1 || vd2)
    {
        IntRange r1 = getIntRange(e1);
        IntRange r2 = e2 ? getIntRange(e2) : IntRange(0, 0);
        fixupRanges(r1, invert ? invertOp(op) : op, r2);
        pushRange(vd1, r1);
        pushRange(vd2, r2);
    }
}

void ConditionVisitor::pushRange(VarDeclaration *vd, IntRange ir)
{
    if (ir.imin > ir.imax)
    {
        deadcode = true;
    }
    else if (vd)
    {
        vd->rangeStack = new IntRangeList(ir.imin, ir.imax, vd->rangeStack);
        toPop.push(vd);
    }
}
