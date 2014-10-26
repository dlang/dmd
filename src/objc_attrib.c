
/* Compiler implementation of the D programming language
 * Copyright (c) 2014 by Digital Mars
 * All Rights Reserved
 * written by Michel Fortin
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/objc_attrib.c
 */

#include "aggregate.h"
#include "arraytypes.h"
#include "attrib.h"

void Objc_ClassDeclaration::addObjcSymbols(ClassDeclarations *classes, ClassDeclarations *categories)
{
    if (objc && !extern_ && !meta)
        classes->push(cdecl);
}

void objc_AttribDeclaration_addObjcSymbols(AttribDeclaration* self, ClassDeclarations *classes, ClassDeclarations *categories)
{
    Dsymbols *d = self->include(NULL, NULL);

    if (d)
    {
        for (unsigned i = 0; i < d->dim; i++)
        {
            Dsymbol *s = (Dsymbol *)d->data[i];
            s->addObjcSymbols(classes, categories);
        }
    }
}
