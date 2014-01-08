
// Copyright (c) 1999-2013 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <stddef.h>
#include <stdlib.h>
#include <time.h>
#include <assert.h>

#include "mars.h"
#include "module.h"
#include "mtype.h"
#include "declaration.h"
#include "enum.h"
#include "aggregate.h"

#include "cc.h"
#include "global.h"
#include "type.h"

void slist_add(Symbol *s);
void slist_reset();


/***************************************
 * Convert from D type to C type.
 * This is done so C debug info can be generated.
 */

type *Type::toCtype()
{
    if (!ctype)
    {   ctype = type_fake(totym());
        ctype->Tcount++;
    }
    return ctype;
}

type *Type::toCParamtype()
{
    return toCtype();
}

type *TypeSArray::toCParamtype()
{
    return toCtype();
}

type *TypeVector::toCtype()
{
    return Type::toCtype();
}

type *TypeSArray::toCtype()
{
    if (!ctype)
        ctype = type_static_array(dim->toInteger(), next->toCtype());
    return ctype;
}

type *TypeDArray::toCtype()
{
    if (!ctype)
    {
        ctype = type_dyn_array(next->toCtype());
        ctype->Tident = toChars(); // needed to generate sensible debug info for cv8
    }
    return ctype;
}


type *TypeAArray::toCtype()
{
    if (!ctype)
        ctype = type_assoc_array(index->toCtype(), next->toCtype());
    return ctype;
}


type *TypePointer::toCtype()
{
    //printf("TypePointer::toCtype() %s\n", toChars());
    if (!ctype)
        ctype = type_pointer(next->toCtype());
    return ctype;
}

type *TypeFunction::toCtype()
{
    if (!ctype)
    {
        size_t nparams = Parameter::dim(parameters);

        type *tmp[10];
        type **ptypes = tmp;
        if (nparams > 10)
            ptypes = (type **)malloc(sizeof(type*) * nparams);

        for (size_t i = 0; i < nparams; i++)
        {   Parameter *arg = Parameter::getNth(parameters, i);
            type *tp = arg->type->toCtype();
            if (arg->storageClass & (STCout | STCref))
                tp = type_allocn(TYref, tp);
            ptypes[i] = tp;
        }

        ctype = type_function(totym(), ptypes, nparams, varargs == 1, next->toCtype());

        if (nparams > 10)
            free(ptypes);
    }
    return ctype;
}

type *TypeDelegate::toCtype()
{
    if (!ctype)
        ctype = type_delegate(next->toCtype());
    return ctype;
}

#if DMD_OBJC
type *TypeObjcSelector::toCtype()
{   type *tn;
    type *t;

    //printf("TypePointer::toCtype() %s\n", toChars());
    if (ctype)
        return ctype;

    if (1 || global.params.symdebug)
    {   /* Need to always do this, otherwise C++ name mangling
         * goes awry.
         */
        t = type_alloc(TYnptr);
        ctype = t;
        tn = tschar; // expose selector as a char*
        t->Tnext = tn;
        tn->Tcount++;
    }
    else
        t = type_fake(totym());
    t->Tcount++;
    ctype = t;
    return t;
}
#endif

type *TypeStruct::toCtype()
{
    if (ctype)
        return ctype;

    //printf("TypeStruct::toCtype() '%s'\n", sym->toChars());
    Type *tm = mutableOf();
    if (tm->ctype)
    {
        Symbol *s = tm->ctype->Ttag;
        type *t = type_alloc(TYstruct);
        t->Ttag = (Classsym *)s;            // structure tag name
        t->Tcount++;
        // Add modifiers
        switch (mod)
        {
            case 0:
                assert(0);
                break;
            case MODconst:
            case MODwild:
            case MODwildconst:
                t->Tty |= mTYconst;
                break;
            case MODshared:
                t->Tty |= mTYshared;
                break;
            case MODshared | MODconst:
            case MODshared | MODwild:
            case MODshared | MODwildconst:
                t->Tty |= mTYshared | mTYconst;
                break;
            case MODimmutable:
                t->Tty |= mTYimmutable;
                break;
            default:
                assert(0);
        }
        ctype = t;
    }
    else
    {
        type *t = type_struct_class(sym->toPrettyChars(), sym->alignsize, sym->structsize,
                sym->arg1type ? sym->arg1type->toCtype() : NULL,
                sym->arg2type ? sym->arg2type->toCtype() : NULL,
                sym->isUnionDeclaration() != 0,
                false,
                sym->isPOD() != 0);

        tm->ctype = t;
        ctype = t;

        /* Add in fields of the struct
         * (after setting ctype to avoid infinite recursion)
         */
        if (global.params.symdebug)
            for (size_t i = 0; i < sym->fields.dim; i++)
            {   VarDeclaration *v = sym->fields[i];

                symbol_struct_addField(t->Ttag, v->ident->toChars(), v->type->toCtype(), v->offset);
            }
    }

    //printf("t = %p, Tflags = x%x\n", ctype, ctype->Tflags);
    return ctype;
}

type *TypeEnum::toCtype()
{
    if (ctype)
        return ctype;

    //printf("TypeEnum::toCtype() '%s'\n", sym->toChars());
    type *t;
    Type *tm = mutableOf();
    if (tm->ctype && tybasic(tm->ctype->Tty) == TYenum)
    {
        Symbol *s = tm->ctype->Ttag;
        assert(s);
        t = type_alloc(TYenum);
        t->Ttag = (Classsym *)s;            // enum tag name
        t->Tcount++;
        t->Tnext = tm->ctype->Tnext;
        t->Tnext->Tcount++;
        // Add modifiers
        switch (mod)
        {
            case 0:
                assert(0);
                break;
            case MODconst:
            case MODwild:
            case MODwildconst:
                t->Tty |= mTYconst;
                break;
            case MODshared:
                t->Tty |= mTYshared;
                break;
            case MODshared | MODconst:
            case MODshared | MODwild:
            case MODshared | MODwildconst:
                t->Tty |= mTYshared | mTYconst;
                break;
            case MODimmutable:
                t->Tty |= mTYimmutable;
                break;
            default:
                assert(0);
        }
        ctype = t;
    }
    else if (sym->memtype->toBasetype()->ty == Tint32)
    {
        t = type_enum(sym->toPrettyChars(), sym->memtype->toCtype());
        tm->ctype = t;
        ctype = t;
    }
    else
    {
        t = ctype = sym->memtype->toCtype();
    }

    //printf("t = %p, Tflags = x%x\n", t, t->Tflags);
    return t;
}

type *TypeTypedef::toCtype()
{
    return sym->basetype->toCtype();
}

type *TypeTypedef::toCParamtype()
{
    return sym->basetype->toCParamtype();
}

type *TypeClass::toCtype()
{
    //printf("TypeClass::toCtype() %s\n", toChars());
    if (ctype)
        return ctype;

    type *t = type_struct_class(sym->toPrettyChars(), sym->alignsize, sym->structsize,
            NULL,
            NULL,
            false,
            true,
            true);

    ctype = type_pointer(t);

    /* Add in fields of the class
     * (after setting ctype to avoid infinite recursion)
     */
    if (global.params.symdebug)
    {
        for (size_t i = 0; i < sym->fields.dim; i++)
        {
            VarDeclaration *v = sym->fields[i];
            symbol_struct_addField(t->Ttag, v->ident->toChars(), v->type->toCtype(), v->offset);
        }
    }

    return ctype;
}

