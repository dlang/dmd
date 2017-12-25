
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2017 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/safe.c
 */

#include "expression.h"
#include "scope.h"
#include "aggregate.h"
#include "target.h"

/*************************************************************
 * Check for unsafe access in @safe code:
 * 1. read overlapped pointers
 * 2. write misaligned pointers
 * 3. write overlapped storage classes
 * Print error if unsafe.
 * Params:
 *      sc = scope
 *      e = expression to check
 *      readonly = if access is read-only
 *      printmsg = print error message if true
 * Returns:
 *      true if error
 */

bool checkUnsafeAccess(Scope *sc, Expression *e, bool readonly, bool printmsg)
{
    if (e->op != TOKdotvar)
        return false;
    DotVarExp *dve = (DotVarExp *)e;
    if (VarDeclaration *v = dve->var->isVarDeclaration())
    {
        if (sc->intypeof || !sc->func || !sc->func->isSafeBypassingInference())
            return false;

        AggregateDeclaration *ad = v->toParent2()->isAggregateDeclaration();
        if (!ad)
            return false;

        if (v->overlapped && v->type->hasPointers() && sc->func->setUnsafe())
        {
            if (printmsg)
                e->error("field %s.%s cannot access pointers in @safe code that overlap other fields",
                    ad->toChars(), v->toChars());
            return true;
        }

        if (readonly || !e->type->isMutable())
            return false;

        if (v->type->hasPointers() && v->type->toBasetype()->ty != Tstruct)
        {
            if ((ad->type->alignment() < Target::ptrsize ||
                 (v->offset & (Target::ptrsize - 1))) &&
                sc->func->setUnsafe())
            {
                if (printmsg)
                    e->error("field %s.%s cannot modify misaligned pointers in @safe code",
                        ad->toChars(), v->toChars());
                return true;
            }
        }

        if (v->overlapUnsafe && sc->func->setUnsafe())
        {
            if (printmsg)
                e->error("field %s.%s cannot modify fields in @safe code that overlap fields with other storage classes",
                    ad->toChars(), v->toChars());
            return true;
        }
    }
    return false;
}

