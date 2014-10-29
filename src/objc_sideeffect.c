
/* Compiler implementation of the D programming language
 * Copyright (c) 2014 by Digital Mars
 * All Rights Reserved
 * written by Michel Fortin
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/objc_sideeffect.c
 */

#include "mtype.h"
#include "objc.h"

// MARK: callSideEffectLevel

void objc_callSideEffectLevel_Tobjcselector(Type *t, TypeFunction *&tf)
{
    tf = (TypeFunction *)((TypeDelegate *)t)->next;
}

// MARK: lambdaHasSideEffect

void objc_lambdaHasSideEffect_TOKcall_Tobjcselector(Type *&t)
{
    t = ((TypeObjcSelector *)t)->next;
}
