
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/delegatize.c
 */

#include "aggregate.h"
#include "declaration.h"
#include "mtype.h"

// MARK: TypeInfoObjcSelectorDeclaration

TypeInfoObjcSelectorDeclaration::TypeInfoObjcSelectorDeclaration(Type *tinfo)
: TypeInfoDeclaration(tinfo, 0)
{
    type = Type::typeinfodelegate->type;
}

TypeInfoObjcSelectorDeclaration *TypeInfoObjcSelectorDeclaration::create(Type *tinfo)
{
    return new TypeInfoObjcSelectorDeclaration(tinfo);
}
