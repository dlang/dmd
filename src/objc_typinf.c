
/* Compiler implementation of the D programming language
 * Copyright (c) 2014 by Digital Mars
 * All Rights Reserved
 * written by Michel Fortin
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/objc_typinf.c
 */

#include "aggregate.h"
#include "cc.h"
#include "dt.h"
#include "declaration.h"
#include "objc.h"

void objc_TypeInfo_toDt_visit_TypeInfoObjcSelectorDeclaration(dt_t **pdt, TypeInfoObjcSelectorDeclaration *d)
{
    //printf("TypeInfoObjcSelectorDeclaration::toDt()\n");
    dtxoff(pdt, Type::typeinfodelegate->toVtblSymbol(), 0); // vtbl for TypeInfo_ObjcSelector
    dtsize_t(pdt, 0);                        // monitor

    assert(d->tinfo->ty == Tobjcselector);

    TypeObjcSelector *tc = (TypeObjcSelector *)d->tinfo;

    tc->next->nextOf()->getTypeInfo(NULL);
    dtxoff(pdt, toSymbol(tc->next->nextOf()->vtinfo), 0); // TypeInfo for selector return value
}
