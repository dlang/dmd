
// Compiler implementation of the D programming language
// Copyright (c) 2010-2011 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// http://www.dsource.org/projects/dmd/browser/branches/dmd-1.x/src/argtypes.c
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <assert.h>

#include "mars.h"
#include "dsymbol.h"
#include "mtype.h"
#include "scope.h"
#include "init.h"
#include "expression.h"
#include "attrib.h"
#include "declaration.h"
#include "template.h"
#include "id.h"
#include "enum.h"
#include "import.h"
#include "aggregate.h"
#include "hdrgen.h"

/****************************************************
 * This breaks a type down into 'simpler' types that can be passed to a function
 * in registers, and returned in registers.
 * It's highly platform dependent.
 * Returning a tuple of zero length means the type cannot be passed/returned in registers.
 */


TypeTuple *Type::toArgTypes()
{
    return NULL;        // not valid for a parameter
}


TypeTuple *TypeBasic::toArgTypes()
{   Type *t1 = NULL;
    Type *t2 = NULL;
    switch (ty)
    {
        case Tvoid:
             return NULL;

        case Tbool:
        case Tint8:
        case Tuns8:
        case Tint16:
        case Tuns16:
        case Tint32:
        case Tuns32:
        case Tfloat32:
        case Tint64:
        case Tuns64:
        case Tfloat64:
        case Tfloat80:
            t1 = this;
            break;

        case Timaginary32:
            t1 = Type::tfloat32;
            break;

        case Timaginary64:
            t1 = Type::tfloat64;
            break;

        case Timaginary80:
            t1 = Type::tfloat80;
            break;

        case Tcomplex32:
            if (global.params.is64bit)
                t1 = Type::tfloat64;            // weird, eh?
            else
            {
                t1 = Type::tfloat64;
                t2 = Type::tfloat64;
            }
            break;

        case Tcomplex64:
            t1 = Type::tfloat64;
            t2 = Type::tfloat64;
            break;

        case Tcomplex80:
            t1 = Type::tfloat80;
            t2 = Type::tfloat80;
            break;

        case Tascii:
            t1 = Type::tuns8;
            break;

        case Twchar:
            t1 = Type::tuns16;
            break;

        case Tdchar:
            t1 = Type::tuns32;
            break;

        default:        assert(0);
    }

    TypeTuple *t;
    if (t1)
    {
        if (t2)
            t = new TypeTuple(t1, t2);
        else
            t = new TypeTuple(t1);
    }
    else
        t = new TypeTuple();
    return t;
}

TypeTuple *TypeSArray::toArgTypes()
{
#if DMDV2
    return new TypeTuple();     // pass on the stack for efficiency
#else
    return new TypeTuple(Type::tvoidptr);
#endif
}

TypeTuple *TypeDArray::toArgTypes()
{
    return new TypeTuple();     // pass on the stack for efficiency
}

TypeTuple *TypeAArray::toArgTypes()
{
    return new TypeTuple(Type::tvoidptr);
}

TypeTuple *TypePointer::toArgTypes()
{
    return new TypeTuple(this);
}

TypeTuple *TypeDelegate::toArgTypes()
{
    return new TypeTuple();     // pass on the stack for efficiency
}

TypeTuple *TypeStruct::toArgTypes()
{
    d_uns64 sz = size(0);
    assert(sz < 0xFFFFFFFF);
    switch ((unsigned)sz)
    {
        case 1:
            return new TypeTuple(Type::tint8);
        case 2:
            return new TypeTuple(Type::tint16);
        case 4:
            return new TypeTuple(Type::tint32);
        case 8:
            return new TypeTuple(Type::tint64);
    }
    return new TypeTuple();     // pass on the stack
}

TypeTuple *TypeEnum::toArgTypes()
{
    return toBasetype()->toArgTypes();
}

TypeTuple *TypeTypedef::toArgTypes()
{
    return sym->basetype->toArgTypes();
}

TypeTuple *TypeClass::toArgTypes()
{
    return new TypeTuple(Type::tvoidptr);
}

