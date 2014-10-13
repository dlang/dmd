
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

#if __sun
#include <alloca.h>
#endif

#include "mars.h"
#include "module.h"
#include "mtype.h"
#include "declaration.h"
#include "statement.h"
#include "enum.h"
#include "aggregate.h"
#include "init.h"
#include "attrib.h"
#include "id.h"
#include "import.h"
#include "template.h"

#include "rmem.h"
#include "cc.h"
#include "global.h"
#include "oper.h"
#include "code.h"
#include "type.h"
#include "dt.h"
#include "cgcv.h"
#include "outbuf.h"
#include "irstate.h"

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
#if SARRAYVALUE
    return toCtype();
#else
    // arrays are passed as pointers
    return next->pointerTo()->toCtype();
#endif
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
        ctype = type_assoc_array(key->toCtype(), next->toCtype());
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
            else if (arg->storageClass & STClazy)
            {   // Mangle as delegate
                type *tf = type_function(TYnfunc, NULL, 0, false, tp);
                tp = type_delegate(tf);
            }
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


type *TypeStruct::toCtype()
{
    if (ctype)
        return ctype;

    //printf("TypeStruct::toCtype() '%s'\n", sym->toChars());
    type *t = type_struct_class(sym->toPrettyChars(), sym->alignsize, sym->structsize,
            sym->arg1type ? sym->arg1type->toCtype() : NULL,
            sym->arg2type ? sym->arg2type->toCtype() : NULL,
            sym->isUnionDeclaration() != 0,
            false,
            sym->isPOD() != 0);

    ctype = t;

    /* Add in fields of the struct
     * (after setting ctype to avoid infinite recursion)
     */
    if (global.params.symdebug)
        for (size_t i = 0; i < sym->fields.dim; i++)
        {   VarDeclaration *v = sym->fields[i];

            symbol_struct_addField(t->Ttag, v->ident->toChars(), v->type->toCtype(), v->offset);
        }

    //printf("t = %p, Tflags = x%x\n", ctype, ctype->Tflags);
    return ctype;
}

type *TypeEnum::toCtype()
{
    return sym->memtype->toCtype();
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
        for (size_t i = 0; i < sym->fields.dim; i++)
        {   VarDeclaration *v = sym->fields[i];

            symbol_struct_addField(t->Ttag, v->ident->toChars(), v->type->toCtype(), v->offset);
        }

    return ctype;
}

