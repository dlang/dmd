
/* Compiler implementation of the D programming language
 * Copyright (c) 2014 by Digital Mars
 * All Rights Reserved
 * written by Michel Fortin
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/objc_dsymbol.c
 */

#include "aggregate.h"
#include "dsymbol.h"
#include "objc.h"

ControlFlow objc_ScopeDsymbol_multiplyDefined(Dsymbol *s1, Dsymbol *s2)
{
    bool isMetaclass = s1->isClassDeclaration() && s2->isClassDeclaration() &&
    ((ClassDeclaration *)s1)->objc.meta && ((ClassDeclaration *)s2)->objc.meta;

    return isMetaclass ? CFreturn : CFnone;
}
