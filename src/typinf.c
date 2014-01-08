
// Compiler implementation of the D programming language
// Copyright (c) 1999-2013 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <string.h>
#include <assert.h>

#include "mars.h"
#include "module.h"
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
#include "target.h"

#include "dt.h"

Parameters *Parameters_create();

/*
 * Used in TypeInfo*::toDt to verify the runtime TypeInfo sizes
 */
void verifyStructSize(ClassDeclaration *typeclass, size_t expected)
{
        if (typeclass->structsize != expected)
        {
#ifdef DEBUG
            printf("expected = x%x, %s.structsize = x%x\n", expected,
                typeclass->toChars(), typeclass->structsize);
#endif
            error(typeclass->loc, "mismatch between compiler and object.d or object.di found. Check installation and import paths with -v compiler switch.");
            fatal();
        }
}

/*******************************************
 * Get a canonicalized form of the TypeInfo for use with the internal
 * runtime library routines. Canonicalized in that static arrays are
 * represented as dynamic arrays, enums are represented by their
 * underlying type, etc. This reduces the number of TypeInfo's needed,
 * so we can use the custom internal ones more.
 */

Expression *Type::getInternalTypeInfo(Scope *sc)
{   TypeInfoDeclaration *tid;
    Expression *e;
    Type *t;
    static TypeInfoDeclaration *internalTI[TMAX];

    //printf("Type::getInternalTypeInfo() %s\n", toChars());
    t = toBasetype();
    switch (t->ty)
    {
        case Tsarray:
#if 0
            // convert to corresponding dynamic array type
            t = t->nextOf()->mutableOf()->arrayOf();
#endif
            break;

        case Tclass:
            if (((TypeClass *)t)->sym->isInterfaceDeclaration())
                break;
            goto Linternal;

        case Tarray:
            // convert to corresponding dynamic array type
            t = t->nextOf()->mutableOf()->arrayOf();
            if (t->nextOf()->ty != Tclass)
                break;
            goto Linternal;

        case Tfunction:
        case Tdelegate:
        case Tpointer:
        Linternal:
            tid = internalTI[t->ty];
            if (!tid)
            {   tid = TypeInfoDeclaration::create(t, 1);
                internalTI[t->ty] = tid;
            }
            e = VarExp::create(Loc(), tid);
            e = e->addressOf(sc);
            e->type = tid->type;        // do this so we don't get redundant dereference
            return e;

        default:
            break;
    }
    //printf("\tcalling getTypeInfo() %s\n", t->toChars());
    return t->getTypeInfo(sc);
}


bool inNonRoot(Dsymbol *s);
FuncDeclaration *search_toHash(StructDeclaration *sd);
FuncDeclaration *search_toString(StructDeclaration *sd);

/****************************************************
 * Get the exact TypeInfo.
 */

Expression *Type::getTypeInfo(Scope *sc)
{
    //printf("Type::getTypeInfo() %p, %s\n", this, toChars());
    if (!Type::dtypeinfo)
    {
        error(Loc(), "TypeInfo not found. object.d may be incorrectly installed or corrupt, compile with -v switch");
        fatal();
    }

    Type *t = merge2(); // do this since not all Type's are merge'd
    if (!t->vtinfo)
    {
        if (t->isShared())      // does both 'shared' and 'shared const'
            t->vtinfo = TypeInfoSharedDeclaration::create(t);
        else if (t->isConst())
            t->vtinfo = TypeInfoConstDeclaration::create(t);
        else if (t->isImmutable())
            t->vtinfo = TypeInfoInvariantDeclaration::create(t);
        else if (t->isWild())
            t->vtinfo = TypeInfoWildDeclaration::create(t);
        else
            t->vtinfo = t->getTypeInfoDeclaration();
        assert(t->vtinfo);
        vtinfo = t->vtinfo;

        /* If this has a custom implementation in std/typeinfo, then
         * do not generate a COMDAT for it.
         */
        if (!t->builtinTypeInfo())
        {
            // Generate COMDAT
            if (sc)                     // if in semantic() pass
            {
                // Find module that will go all the way to an object file
                Module *m = sc->module->importedFrom;
                m->members->push(t->vtinfo);

                if (ty == Tstruct)
                {
                    Dsymbol *s;
                    StructDeclaration *sd = ((TypeStruct *)this)->sym;
                    if ((sd->xeq  && sd->xeq  != sd->xerreq  ||
                         sd->xcmp && sd->xcmp != sd->xerrcmp ||
                         search_toHash(sd) ||
                         search_toString(sd)
                        ) && inNonRoot(sd))
                    {
                        //printf("deferred sem3 for TypeInfo - sd = %s, inNonRoot = %d\n", sd->toChars(), inNonRoot(sd));
                        Module::addDeferredSemantic3(sd);
                    }
                }
            }
            else                        // if in obj generation pass
            {
                t->vtinfo->toObjFile(global.params.multiobj);
            }
        }
    }
    if (!vtinfo)
        vtinfo = t->vtinfo;     // Types aren't merged, but we can share the vtinfo's
    Expression *e = VarExp::create(Loc(), t->vtinfo);
    e = e->addressOf(sc);
    e->type = t->vtinfo->type;          // do this so we don't get redundant dereference
    return e;
}

TypeInfoDeclaration *Type::getTypeInfoDeclaration()
{
    //printf("Type::getTypeInfoDeclaration() %s\n", toChars());
    return TypeInfoDeclaration::create(this, 0);
}

TypeInfoDeclaration *TypeTypedef::getTypeInfoDeclaration()
{
    return TypeInfoTypedefDeclaration::create(this);
}

TypeInfoDeclaration *TypePointer::getTypeInfoDeclaration()
{
    return TypeInfoPointerDeclaration::create(this);
}

TypeInfoDeclaration *TypeDArray::getTypeInfoDeclaration()
{
    return TypeInfoArrayDeclaration::create(this);
}

TypeInfoDeclaration *TypeSArray::getTypeInfoDeclaration()
{
    return TypeInfoStaticArrayDeclaration::create(this);
}

TypeInfoDeclaration *TypeAArray::getTypeInfoDeclaration()
{
    return TypeInfoAssociativeArrayDeclaration::create(this);
}

TypeInfoDeclaration *TypeStruct::getTypeInfoDeclaration()
{
    return TypeInfoStructDeclaration::create(this);
}

TypeInfoDeclaration *TypeClass::getTypeInfoDeclaration()
{
    if (sym->isInterfaceDeclaration())
        return TypeInfoInterfaceDeclaration::create(this);
    else
        return TypeInfoClassDeclaration::create(this);
}

TypeInfoDeclaration *TypeVector::getTypeInfoDeclaration()
{
    return TypeInfoVectorDeclaration::create(this);
}

TypeInfoDeclaration *TypeEnum::getTypeInfoDeclaration()
{
    return TypeInfoEnumDeclaration::create(this);
}

TypeInfoDeclaration *TypeFunction::getTypeInfoDeclaration()
{
    return TypeInfoFunctionDeclaration::create(this);
}

TypeInfoDeclaration *TypeDelegate::getTypeInfoDeclaration()
{
    return TypeInfoDelegateDeclaration::create(this);
}

#if DMD_OBJC
TypeInfoDeclaration *TypeObjcSelector::getTypeInfoDeclaration()
{
    return new TypeInfoObjcSelectorDeclaration(this);
}
#endif

TypeInfoDeclaration *TypeTuple::getTypeInfoDeclaration()
{
    return TypeInfoTupleDeclaration::create(this);
}

/****************************************************
 */

void TypeInfoDeclaration::toDt(dt_t **pdt)
{
    //printf("TypeInfoDeclaration::toDt() %s\n", toChars());
    verifyStructSize(Type::dtypeinfo, 2 * Target::ptrsize);

    dtxoff(pdt, Type::dtypeinfo->toVtblSymbol(), 0); // vtbl for TypeInfo
    dtsize_t(pdt, 0);                        // monitor
}

void TypeInfoConstDeclaration::toDt(dt_t **pdt)
{
    //printf("TypeInfoConstDeclaration::toDt() %s\n", toChars());
    verifyStructSize(Type::typeinfoconst, 3 * Target::ptrsize);

    dtxoff(pdt, Type::typeinfoconst->toVtblSymbol(), 0); // vtbl for TypeInfo_Const
    dtsize_t(pdt, 0);                        // monitor
    Type *tm = tinfo->mutableOf();
    tm = tm->merge();
    tm->getTypeInfo(NULL);
    dtxoff(pdt, tm->vtinfo->toSymbol(), 0);
}

void TypeInfoInvariantDeclaration::toDt(dt_t **pdt)
{
    //printf("TypeInfoInvariantDeclaration::toDt() %s\n", toChars());
    verifyStructSize(Type::typeinfoinvariant, 3 * Target::ptrsize);

    dtxoff(pdt, Type::typeinfoinvariant->toVtblSymbol(), 0); // vtbl for TypeInfo_Invariant
    dtsize_t(pdt, 0);                        // monitor
    Type *tm = tinfo->mutableOf();
    tm = tm->merge();
    tm->getTypeInfo(NULL);
    dtxoff(pdt, tm->vtinfo->toSymbol(), 0);
}

void TypeInfoSharedDeclaration::toDt(dt_t **pdt)
{
    //printf("TypeInfoSharedDeclaration::toDt() %s\n", toChars());
    verifyStructSize(Type::typeinfoshared, 3 * Target::ptrsize);

    dtxoff(pdt, Type::typeinfoshared->toVtblSymbol(), 0); // vtbl for TypeInfo_Shared
    dtsize_t(pdt, 0);                        // monitor
    Type *tm = tinfo->unSharedOf();
    tm = tm->merge();
    tm->getTypeInfo(NULL);
    dtxoff(pdt, tm->vtinfo->toSymbol(), 0);
}

void TypeInfoWildDeclaration::toDt(dt_t **pdt)
{
    //printf("TypeInfoWildDeclaration::toDt() %s\n", toChars());
    verifyStructSize(Type::typeinfowild, 3 * Target::ptrsize);

    dtxoff(pdt, Type::typeinfowild->toVtblSymbol(), 0); // vtbl for TypeInfo_Wild
    dtsize_t(pdt, 0);                        // monitor
    Type *tm = tinfo->mutableOf();
    tm = tm->merge();
    tm->getTypeInfo(NULL);
    dtxoff(pdt, tm->vtinfo->toSymbol(), 0);
}


void TypeInfoTypedefDeclaration::toDt(dt_t **pdt)
{
    //printf("TypeInfoTypedefDeclaration::toDt() %s\n", toChars());
    verifyStructSize(Type::typeinfotypedef, 7 * Target::ptrsize);

    dtxoff(pdt, Type::typeinfotypedef->toVtblSymbol(), 0); // vtbl for TypeInfo_Typedef
    dtsize_t(pdt, 0);                        // monitor

    assert(tinfo->ty == Ttypedef);

    TypeTypedef *tc = (TypeTypedef *)tinfo;
    TypedefDeclaration *sd = tc->sym;
    //printf("basetype = %s\n", sd->basetype->toChars());

    /* Put out:
     *  TypeInfo base;
     *  char[] name;
     *  void[] m_init;
     */

    sd->basetype = sd->basetype->merge();
    sd->basetype->getTypeInfo(NULL);            // generate vtinfo
    assert(sd->basetype->vtinfo);
    dtxoff(pdt, sd->basetype->vtinfo->toSymbol(), 0);   // TypeInfo for basetype

    const char *name = sd->toPrettyChars();
    size_t namelen = strlen(name);
    dtsize_t(pdt, namelen);
    dtabytes(pdt, 0, namelen + 1, name);

    // void[] init;
    if (tinfo->isZeroInit() || !sd->init)
    {   // 0 initializer, or the same as the base type
        dtsize_t(pdt, 0);        // init.length
        dtsize_t(pdt, 0);        // init.ptr
    }
    else
    {
        dtsize_t(pdt, sd->type->size()); // init.length
        dtxoff(pdt, sd->toInitializer(), 0);    // init.ptr
    }
}

void TypeInfoEnumDeclaration::toDt(dt_t **pdt)
{
    //printf("TypeInfoEnumDeclaration::toDt()\n");
    verifyStructSize(Type::typeinfoenum, 7 * Target::ptrsize);

    dtxoff(pdt, Type::typeinfoenum->toVtblSymbol(), 0); // vtbl for TypeInfo_Enum
    dtsize_t(pdt, 0);                        // monitor

    assert(tinfo->ty == Tenum);

    TypeEnum *tc = (TypeEnum *)tinfo;
    EnumDeclaration *sd = tc->sym;

    /* Put out:
     *  TypeInfo base;
     *  char[] name;
     *  void[] m_init;
     */

    if (sd->memtype)
    {   sd->memtype->getTypeInfo(NULL);
        dtxoff(pdt, sd->memtype->vtinfo->toSymbol(), 0);        // TypeInfo for enum members
    }
    else
        dtsize_t(pdt, 0);

    const char *name = sd->toPrettyChars();
    size_t namelen = strlen(name);
    dtsize_t(pdt, namelen);
    dtabytes(pdt, 0, namelen + 1, name);

    // void[] init;
    if (!sd->members || tinfo->isZeroInit())
    {   // 0 initializer, or the same as the base type
        dtsize_t(pdt, 0);        // init.length
        dtsize_t(pdt, 0);        // init.ptr
    }
    else
    {
        dtsize_t(pdt, sd->type->size()); // init.length
        dtxoff(pdt, sd->toInitializer(), 0);    // init.ptr
    }
}

void TypeInfoPointerDeclaration::toDt(dt_t **pdt)
{
    //printf("TypeInfoPointerDeclaration::toDt()\n");
    verifyStructSize(Type::typeinfopointer, 3 * Target::ptrsize);

    dtxoff(pdt, Type::typeinfopointer->toVtblSymbol(), 0); // vtbl for TypeInfo_Pointer
    dtsize_t(pdt, 0);                        // monitor

    assert(tinfo->ty == Tpointer);

    TypePointer *tc = (TypePointer *)tinfo;

    tc->next->getTypeInfo(NULL);
    dtxoff(pdt, tc->next->vtinfo->toSymbol(), 0); // TypeInfo for type being pointed to
}

void TypeInfoArrayDeclaration::toDt(dt_t **pdt)
{
    //printf("TypeInfoArrayDeclaration::toDt()\n");
    verifyStructSize(Type::typeinfoarray, 3 * Target::ptrsize);

    dtxoff(pdt, Type::typeinfoarray->toVtblSymbol(), 0); // vtbl for TypeInfo_Array
    dtsize_t(pdt, 0);                        // monitor

    assert(tinfo->ty == Tarray);

    TypeDArray *tc = (TypeDArray *)tinfo;

    tc->next->getTypeInfo(NULL);
    dtxoff(pdt, tc->next->vtinfo->toSymbol(), 0); // TypeInfo for array of type
}

void TypeInfoStaticArrayDeclaration::toDt(dt_t **pdt)
{
    //printf("TypeInfoStaticArrayDeclaration::toDt()\n");
    verifyStructSize(Type::typeinfostaticarray, 4 * Target::ptrsize);

    dtxoff(pdt, Type::typeinfostaticarray->toVtblSymbol(), 0); // vtbl for TypeInfo_StaticArray
    dtsize_t(pdt, 0);                        // monitor

    assert(tinfo->ty == Tsarray);

    TypeSArray *tc = (TypeSArray *)tinfo;

    tc->next->getTypeInfo(NULL);
    dtxoff(pdt, tc->next->vtinfo->toSymbol(), 0); // TypeInfo for array of type

    dtsize_t(pdt, tc->dim->toInteger());         // length
}

void TypeInfoVectorDeclaration::toDt(dt_t **pdt)
{
    //printf("TypeInfoVectorDeclaration::toDt()\n");
    verifyStructSize(Type::typeinfovector, 3 * Target::ptrsize);

    dtxoff(pdt, Type::typeinfovector->toVtblSymbol(), 0); // vtbl for TypeInfo_Vector
    dtsize_t(pdt, 0);                        // monitor

    assert(tinfo->ty == Tvector);

    TypeVector *tc = (TypeVector *)tinfo;

    tc->basetype->getTypeInfo(NULL);
    dtxoff(pdt, tc->basetype->vtinfo->toSymbol(), 0); // TypeInfo for equivalent static array
}

void TypeInfoAssociativeArrayDeclaration::toDt(dt_t **pdt)
{
    //printf("TypeInfoAssociativeArrayDeclaration::toDt()\n");
    verifyStructSize(Type::typeinfoassociativearray, 5 * Target::ptrsize);

    dtxoff(pdt, Type::typeinfoassociativearray->toVtblSymbol(), 0); // vtbl for TypeInfo_AssociativeArray
    dtsize_t(pdt, 0);                        // monitor

    assert(tinfo->ty == Taarray);

    TypeAArray *tc = (TypeAArray *)tinfo;

    tc->next->getTypeInfo(NULL);
    dtxoff(pdt, tc->next->vtinfo->toSymbol(), 0); // TypeInfo for array of type

    tc->index->getTypeInfo(NULL);
    dtxoff(pdt, tc->index->vtinfo->toSymbol(), 0); // TypeInfo for array of type

    tc->getImpl()->type->getTypeInfo(NULL);
    dtxoff(pdt, tc->getImpl()->type->vtinfo->toSymbol(), 0);    // impl
}

void TypeInfoFunctionDeclaration::toDt(dt_t **pdt)
{
    //printf("TypeInfoFunctionDeclaration::toDt()\n");
    verifyStructSize(Type::typeinfofunction, 5 * Target::ptrsize);

    dtxoff(pdt, Type::typeinfofunction->toVtblSymbol(), 0); // vtbl for TypeInfo_Function
    dtsize_t(pdt, 0);                        // monitor

    assert(tinfo->ty == Tfunction);

    TypeFunction *tc = (TypeFunction *)tinfo;

    tc->next->getTypeInfo(NULL);
    dtxoff(pdt, tc->next->vtinfo->toSymbol(), 0); // TypeInfo for function return value

    const char *name = tinfo->deco;
    assert(name);
    size_t namelen = strlen(name);
    dtsize_t(pdt, namelen);
    dtabytes(pdt, 0, namelen + 1, name);
}

void TypeInfoDelegateDeclaration::toDt(dt_t **pdt)
{
    //printf("TypeInfoDelegateDeclaration::toDt()\n");
    verifyStructSize(Type::typeinfodelegate, 5 * Target::ptrsize);

    dtxoff(pdt, Type::typeinfodelegate->toVtblSymbol(), 0); // vtbl for TypeInfo_Delegate
    dtsize_t(pdt, 0);                        // monitor

    assert(tinfo->ty == Tdelegate);

    TypeDelegate *tc = (TypeDelegate *)tinfo;

    tc->next->nextOf()->getTypeInfo(NULL);
    dtxoff(pdt, tc->next->nextOf()->vtinfo->toSymbol(), 0); // TypeInfo for delegate return value

    const char *name = tinfo->deco;
    assert(name);
    size_t namelen = strlen(name);
    dtsize_t(pdt, namelen);
    dtabytes(pdt, 0, namelen + 1, name);
}

#if DMD_OBJC
void TypeInfoObjcSelectorDeclaration::toDt(dt_t **pdt)
{
    //printf("TypeInfoObjcSelectorDeclaration::toDt()\n");
    dtxoff(pdt, Type::typeinfodelegate->toVtblSymbol(), 0); // vtbl for TypeInfo_ObjcSelector
    dtsize_t(pdt, 0);                        // monitor

    assert(tinfo->ty == Tobjcselector);

    TypeObjcSelector *tc = (TypeObjcSelector *)tinfo;

    tc->next->nextOf()->getTypeInfo(NULL);
    dtxoff(pdt, tc->next->nextOf()->vtinfo->toSymbol(), 0); // TypeInfo for selector return value
}
#endif

void TypeInfoStructDeclaration::toDt(dt_t **pdt)
{
    //printf("TypeInfoStructDeclaration::toDt() '%s'\n", toChars());
    if (global.params.is64bit)
        verifyStructSize(Type::typeinfostruct, 17 * Target::ptrsize);
    else
        verifyStructSize(Type::typeinfostruct, 15 * Target::ptrsize);

    dtxoff(pdt, Type::typeinfostruct->toVtblSymbol(), 0); // vtbl for TypeInfo_Struct
    dtsize_t(pdt, 0);                        // monitor

    assert(tinfo->ty == Tstruct);

    TypeStruct *tc = (TypeStruct *)tinfo;
    StructDeclaration *sd = tc->sym;

    if (!sd->members)
        return;

    /* Put out:
     *  char[] name;
     *  void[] init;
     *  hash_t function(in void*) xtoHash;
     *  bool function(in void*, in void*) xopEquals;
     *  int function(in void*, in void*) xopCmp;
     *  string function(const(void)*) xtoString;
     *  StructFlags m_flags;
     *  //xgetMembers;
     *  xdtor;
     *  xpostblit;
     *  uint m_align;
     *  version (X86_64)
     *      TypeInfo m_arg1;
     *      TypeInfo m_arg2;
     *  xgetRTInfo
     */

    const char *name = sd->toPrettyChars();
    size_t namelen = strlen(name);
    dtsize_t(pdt, namelen);
    dtabytes(pdt, 0, namelen + 1, name);

    // void[] init;
    dtsize_t(pdt, sd->structsize);       // init.length
    if (sd->zeroInit)
        dtsize_t(pdt, 0);                // NULL for 0 initialization
    else
        dtxoff(pdt, sd->toInitializer(), 0);    // init.ptr

    if (FuncDeclaration *fd = search_toHash(sd))
    {
        dtxoff(pdt, fd->toSymbol(), 0);
        TypeFunction *tf = (TypeFunction *)fd->type;
        assert(tf->ty == Tfunction);
        /* I'm a little unsure this is the right way to do it. Perhaps a better
         * way would to automatically add these attributes to any struct member
         * function with the name "toHash".
         * So I'm leaving this here as an experiment for the moment.
         */
        if (!tf->isnothrow || tf->trust == TRUSTsystem /*|| tf->purity == PUREimpure*/)
            warning(fd->loc, "toHash() must be declared as extern (D) size_t toHash() const nothrow @safe, not %s", tf->toChars());
    }
    else
        dtsize_t(pdt, 0);

    if (sd->xeq)
        dtxoff(pdt, sd->xeq->toSymbol(), 0);
    else
        dtsize_t(pdt, 0);

    if (sd->xcmp)
        dtxoff(pdt, sd->xcmp->toSymbol(), 0);
    else
        dtsize_t(pdt, 0);

    if (FuncDeclaration *fd = search_toString(sd))
    {
        dtxoff(pdt, fd->toSymbol(), 0);
    }
    else
        dtsize_t(pdt, 0);

    // StructFlags m_flags;
    StructFlags::Type m_flags = 0;
    if (tc->hasPointers()) m_flags |= StructFlags::hasPointers;
    dtsize_t(pdt, m_flags);

#if 0
    // xgetMembers
    FuncDeclaration *sgetmembers = sd->findGetMembers();
    if (sgetmembers)
        dtxoff(pdt, sgetmembers->toSymbol(), 0);
    else
        dtsize_t(pdt, 0);                        // xgetMembers
#endif

    // xdtor
    FuncDeclaration *sdtor = sd->dtor;
    if (sdtor)
        dtxoff(pdt, sdtor->toSymbol(), 0);
    else
        dtsize_t(pdt, 0);                        // xdtor

    // xpostblit
    FuncDeclaration *spostblit = sd->postblit;
    if (spostblit && !(spostblit->storage_class & STCdisable))
        dtxoff(pdt, spostblit->toSymbol(), 0);
    else
        dtsize_t(pdt, 0);                        // xpostblit

    // uint m_align;
    dtsize_t(pdt, tc->alignsize());

    if (global.params.is64bit)
    {
        Type *t = sd->arg1type;
        for (int i = 0; i < 2; i++)
        {
            // m_argi
            if (t)
            {
                t->getTypeInfo(NULL);
                dtxoff(pdt, t->vtinfo->toSymbol(), 0);
            }
            else
                dtsize_t(pdt, 0);

            t = sd->arg2type;
        }
    }

    // xgetRTInfo
    if (sd->getRTInfo)
        sd->getRTInfo->toDt(pdt);
    else if (m_flags & StructFlags::hasPointers)
        dtsize_t(pdt, 1);
    else
        dtsize_t(pdt, 0);
}

void TypeInfoClassDeclaration::toDt(dt_t **pdt)
{
    //printf("TypeInfoClassDeclaration::toDt() %s\n", tinfo->toChars());
    assert(0);
}

void TypeInfoInterfaceDeclaration::toDt(dt_t **pdt)
{
    //printf("TypeInfoInterfaceDeclaration::toDt() %s\n", tinfo->toChars());
    verifyStructSize(Type::typeinfointerface, 3 * Target::ptrsize);

    dtxoff(pdt, Type::typeinfointerface->toVtblSymbol(), 0); // vtbl for TypeInfoInterface
    dtsize_t(pdt, 0);                        // monitor

    assert(tinfo->ty == Tclass);

    TypeClass *tc = (TypeClass *)tinfo;
    Symbol *s;

    if (!tc->sym->vclassinfo)
        tc->sym->vclassinfo = TypeInfoClassDeclaration::create(tc);
    s = tc->sym->vclassinfo->toSymbol();
    dtxoff(pdt, s, 0);          // ClassInfo for tinfo
}

void TypeInfoTupleDeclaration::toDt(dt_t **pdt)
{
    //printf("TypeInfoTupleDeclaration::toDt() %s\n", tinfo->toChars());
    verifyStructSize(Type::typeinfotypelist, 4 * Target::ptrsize);

    dtxoff(pdt, Type::typeinfotypelist->toVtblSymbol(), 0); // vtbl for TypeInfoInterface
    dtsize_t(pdt, 0);                        // monitor

    assert(tinfo->ty == Ttuple);

    TypeTuple *tu = (TypeTuple *)tinfo;

    size_t dim = tu->arguments->dim;
    dtsize_t(pdt, dim);                      // elements.length

    dt_t *d = NULL;
    for (size_t i = 0; i < dim; i++)
    {   Parameter *arg = (*tu->arguments)[i];
        Expression *e = arg->type->getTypeInfo(NULL);
        e = e->optimize(WANTvalue);
        e->toDt(&d);
    }

    dtdtoff(pdt, d, 0);              // elements.ptr
}

/* ========================================================================= */

/* These decide if there's an instance for them already in std.typeinfo,
 * because then the compiler doesn't need to build one.
 */

int Type::builtinTypeInfo()
{
    return 0;
}

int TypeBasic::builtinTypeInfo()
{
    return mod ? 0 : 1;
}

int TypeDArray::builtinTypeInfo()
{
    return !mod && (next->isTypeBasic() != NULL && !next->mod ||
        // strings are so common, make them builtin
        next->ty == Tchar && next->mod == MODimmutable ||
        next->ty == Tchar && next->mod == MODconst);
}

int TypeClass::builtinTypeInfo()
{
    /* This is statically put out with the ClassInfo, so
     * claim it is built in so it isn't regenerated by each module.
     */
    return mod ? 0 : 1;
}

/* ========================================================================= */

/***************************************
 * Create a static array of TypeInfo references
 * corresponding to an array of Expression's.
 * Used to supply hidden _arguments[] value for variadic D functions.
 */

Expression *createTypeInfoArray(Scope *sc, Expression *exps[], size_t dim)
{
#if 1
    /*
     * Pass a reference to the TypeInfo_Tuple corresponding to the types of the
     * arguments. Source compatibility is maintained by computing _arguments[]
     * at the start of the called function by offseting into the TypeInfo_Tuple
     * reference.
     */
    Parameters *args = Parameters_create();
    args->setDim(dim);
    for (size_t i = 0; i < dim; i++)
    {   Parameter *arg = Parameter::create(STCin, exps[i]->type, NULL, NULL);
        (*args)[i] = arg;
    }
    TypeTuple *tup = TypeTuple::create(args);
    Expression *e = tup->getTypeInfo(sc);
    e = e->optimize(WANTvalue);
    assert(e->op == TOKsymoff);         // should be SymOffExp

    return e;
#else
    /* Improvements:
     * 1) create an array literal instead,
     * as it would eliminate the extra dereference of loading the
     * static variable.
     */

    ArrayInitializer *ai = new ArrayInitializer(0);
    VarDeclaration *v;
    Type *t;
    Expression *e;
    OutBuffer buf;
    Identifier *id;
    char *name;

    // Generate identifier for _arguments[]
    buf.writestring("_arguments_");
    for (int i = 0; i < dim; i++)
    {   t = exps[i]->type;
        t->toDecoBuffer(&buf);
    }
    buf.writeByte(0);
    id = Lexer::idPool((char *)buf.data);

    Module *m = sc->module;
    Dsymbol *s = m->symtab->lookup(id);

    if (s && s->parent == m)
    {   // Use existing one
        v = s->isVarDeclaration();
        assert(v);
    }
    else
    {   // Generate new one

        for (int i = 0; i < dim; i++)
        {   t = exps[i]->type;
            e = t->getTypeInfo(sc);
            ai->addInit(new IntegerExp(i), new ExpInitializer(Loc(), e));
        }

        t = Type::typeinfo->type->arrayOf();
        ai->type = t;
        v = new VarDeclaration(0, t, id, ai);
        v->storage_class |= STCtemp;
        m->members->push(v);
        m->symtabInsert(v);
        sc = sc->push();
        sc->linkage = LINKc;
        sc->stc = STCstatic | STCcomdat;
        ai->semantic(sc, t);
        v->semantic(sc);
        v->parent = m;
        sc = sc->pop();
    }
    e = VarExp::create(Loc(), v);
    e = e->semantic(sc);
    return e;
#endif
}



