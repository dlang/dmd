
/* Compiler implementation of the D programming language
 * Copyright (c) 2014 by Digital Mars
 * All Rights Reserved
 * written by Michel Fortin
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/objc_parse.c
 */

#include "arraytypes.h"
#include "declaration.h"
#include "expression.h"
#include "mars.h"
#include "mtype.h"
#include "objc.h"
#include "parse.h"

void objc_Parser_parseBasicType2_selector(Type *&t, TypeFunction *tf)
{
    tf->linkage = LINKobjc; // force Objective-C linkage
    t = new TypeObjcSelector(tf);
}

void objc_Parser_parseDeclarations_Tobjcselector(Type *&t, LINK &link)
{
    if (t->ty == Tobjcselector)
        link = LINKobjc; // force Objective-C linkage
}

ControlFlow objc_Parser_parsePostExp_TOKclass(Parser *self, Expression *&e, Loc loc)
{
    e = new ObjcDotClassExp(loc, e);
    self->nextToken();
    return CFcontinue;
}
