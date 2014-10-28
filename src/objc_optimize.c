
/* Compiler implementation of the D programming language
 * Copyright (c) 2014 by Digital Mars, All Rights Reserved
 * written by Michel Fortin
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/objc_optimize.c
 */

#include "mtype.h"

void objc_Expression_optimize_visit_CallExp_Tobjcselector(Type *&t1)
{
    if (t1->ty == Tobjcselector)
        t1 = t1->nextOf();
}
