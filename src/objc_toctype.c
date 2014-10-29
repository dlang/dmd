
/* Compiler implementation of the D programming language
 * Copyright (c) 2014 by Digital Mars
 * All Rights Reserved
 * written by Michel Fortin
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/objc_toctype.c
 */

#include "aggregate.h"
#include "cc.h"
#include "declaration.h"
#include "objc.h"
#include "type.h"

unsigned totym(Type *tx);

void objc_Type_toCtype_visit_TypeObjcSelector(TypeObjcSelector *t)
{
    type *tn;

    //printf("TypePointer::toCtype() %s\n", t->toChars());
    if (t->ctype)
        return;

    if (1 || global.params.symdebug)
    {   /* Need to always do this, otherwise C++ name mangling
         * goes awry.
         */
        t->ctype = type_alloc(TYnptr);
        tn = tschar; // expose selector as a char*
        t->ctype->Tnext = tn;
        tn->Tcount++;
    }
    else
        t->ctype = type_fake(totym(t));
    t->ctype->Tcount++;
}
