
// Copyright (c) 1999-2013 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <stddef.h>
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
        ctype = type_dyn_array(next->toCtype());
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
{   type *t;

    if (ctype)
        return ctype;

    param_t *paramtypes = NULL;
    size_t nparams = Parameter::dim(parameters);
    for (size_t i = 0; i < nparams; i++)
    {   Parameter *arg = Parameter::getNth(parameters, i);
        type *tp = arg->type->toCtype();
        if (arg->storageClass & (STCout | STCref))
        {   // C doesn't have reference types, so it's really a pointer
            // to the parameter type
            tp = type_allocn(TYref, tp);
        }
        param_append_type(&paramtypes,tp);
    }
    tym_t tyf = totym();
    t = type_alloc(tyf);
    t->Tflags |= TFprototype;
    if (varargs != 1)
        t->Tflags |= TFfixed;
    assert(next);           // function return type should exist
    t->Tnext = next->toCtype();
    t->Tnext->Tcount++;
    t->Tparamtypes = paramtypes;

    ctype = t;
    return t;
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
    type *t = type_alloc(TYstruct);
    Type *tm = mutableOf();
    if (tm->ctype)
    {
        Symbol *s = tm->ctype->Ttag;
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
                t->Tty |= mTYconst;
                break;
            case MODimmutable:
                t->Tty |= mTYimmutable;
                break;
            case MODshared:
                t->Tty |= mTYshared;
                break;
            case MODshared | MODwild:
            case MODshared | MODconst:
                t->Tty |= mTYshared | mTYconst;
                break;
            default:
                assert(0);
        }
        ctype = t;
    }
    else
    {
        Symbol *s = symbol_calloc(sym->toPrettyChars());
        s->Sclass = SCstruct;
        s->Sstruct = struct_calloc();
        s->Sstruct->Salignsize = sym->alignsize;
        s->Sstruct->Sstructalign = sym->alignsize;
        s->Sstruct->Sstructsize = sym->structsize;
        s->Sstruct->Sarg1type = sym->arg1type ? sym->arg1type->toCtype() : NULL;
        s->Sstruct->Sarg2type = sym->arg2type ? sym->arg2type->toCtype() : NULL;

        if (!sym->isPOD())
            s->Sstruct->Sflags |= STRnotpod;
        if (sym->isUnionDeclaration())
            s->Sstruct->Sflags |= STRunion;

        t->Ttag = (Classsym *)s;            // structure tag name
        t->Tcount++;
        s->Stype = t;
        slist_add(s);
        tm->ctype = t;
        ctype = t;

        /* Add in fields of the struct
         * (after setting ctype to avoid infinite recursion)
         */
        if (global.params.symdebug)
            for (size_t i = 0; i < sym->fields.dim; i++)
            {   VarDeclaration *v = sym->fields[i];

                symbol_struct_addField(s, v->ident->toChars(), v->type->toCtype(), v->offset);
            }
    }

    //printf("t = %p, Tflags = x%x\n", t, t->Tflags);
    return t;
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
                t->Tty |= mTYconst;
                break;
            case MODimmutable:
                t->Tty |= mTYimmutable;
                break;
            case MODshared:
                t->Tty |= mTYshared;
                break;
            case MODshared | MODwild:
            case MODshared | MODconst:
                t->Tty |= mTYshared | mTYconst;
                break;
            default:
                assert(0);
        }
        ctype = t;
    }
    else if (sym->memtype->toBasetype()->ty == Tint32)
    {
        Symbol *s = symbol_calloc(sym->toPrettyChars());
        s->Sclass = SCenum;
        s->Senum = (enum_t *) MEM_PH_CALLOC(sizeof(enum_t));
        s->Senum->SEflags |= SENforward;        // forward reference
        slist_add(s);

        t = type_alloc(TYenum);
        t->Ttag = (Classsym *)s;            // enum tag name
        t->Tcount++;
        t->Tnext = sym->memtype->toCtype();
        t->Tnext->Tcount++;
        s->Stype = t;
        slist_add(s);
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
{   type *t;
    Symbol *s;

    //printf("TypeClass::toCtype() %s\n", toChars());
    if (ctype)
        return ctype;

    /* Need this symbol to do C++ name mangling
     */
    const char *name = sym->isCPPinterface() ? sym->ident->toChars()
                                             : sym->toPrettyChars();
    s = symbol_calloc(name);
    s->Sclass = SCstruct;
    s->Sstruct = struct_calloc();
    s->Sstruct->Sflags |= STRclass;
    s->Sstruct->Salignsize = sym->alignsize;
//    s->Sstruct->Sstructalign = sym->structalign;
    s->Sstruct->Sstructsize = sym->structsize;

    t = type_alloc(TYstruct);
    t->Ttag = (Classsym *)s;            // structure tag name
    t->Tcount++;
    s->Stype = t;
    slist_add(s);

    t = type_allocn(TYnptr, t);

    t->Tcount++;
    ctype = t;

    /* Add in fields of the class
     * (after setting ctype to avoid infinite recursion)
     */
    if (global.params.symdebug)
        for (size_t i = 0; i < sym->fields.dim; i++)
        {   VarDeclaration *v = sym->fields[i];

            symbol_struct_addField(s, v->ident->toChars(), v->type->toCtype(), v->offset);
        }

    return t;
}

