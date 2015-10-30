
// Compiler implementation of the D programming language
// Copyright (c) 1999-2012 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <string.h>
#include <assert.h>

//#include "mem.h"

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

#if 0
#include "dt.h"
#else
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
#endif

extern Symbol *static_sym();

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
            if (t->next->ty != Tclass)
                break;
            goto Linternal;

        case Tfunction:
        case Tdelegate:
        case Tpointer:
        Linternal:
            tid = internalTI[t->ty];
            if (!tid)
            {   tid = new TypeInfoDeclaration(t, 1);
                internalTI[t->ty] = tid;
            }
            e = new VarExp(0, tid);
            e = e->addressOf(sc);
            e->type = tid->type;        // do this so we don't get redundant dereference
            return e;

        default:
            break;
    }
    //printf("\tcalling getTypeInfo() %s\n", t->toChars());
    return t->getTypeInfo(sc);
}


/****************************************************
 * Get the exact TypeInfo.
 */

Expression *Type::getTypeInfo(Scope *sc)
{
    //printf("Type::getTypeInfo() %p, %s\n", this, toChars());
    if (!Type::typeinfo)
    {
        error(0, "TypeInfo not found. object.d may be incorrectly installed or corrupt, compile with -v switch");
        fatal();
    }

    Type *t = merge2(); // do this since not all Type's are merge'd
    if (!t->vtinfo)
    {
#if DMDV2
        if (t->isShared())      // does both 'shared' and 'shared const'
            t->vtinfo = new TypeInfoSharedDeclaration(t);
        else if (t->isConst())
            t->vtinfo = new TypeInfoConstDeclaration(t);
        else if (t->isImmutable())
            t->vtinfo = new TypeInfoInvariantDeclaration(t);
        else if (t->isWild())
            t->vtinfo = new TypeInfoWildDeclaration(t);
        else
#endif
            t->vtinfo = t->getTypeInfoDeclaration();
        assert(t->vtinfo);
        vtinfo = t->vtinfo;

        /* If this has a custom implementation in std/typeinfo, then
         * do not generate a COMDAT for it.
         */
        if (!t->builtinTypeInfo())
        {   // Generate COMDAT
            if (sc)                     // if in semantic() pass
            {   // Find module that will go all the way to an object file
                Module *m = sc->module->importedFrom;
                m->members->push(t->vtinfo);
            }
            else                        // if in obj generation pass
            {
                t->vtinfo->toObjFile(global.params.multiobj);
            }
        }
    }
    if (!vtinfo)
        vtinfo = t->vtinfo;     // Types aren't merged, but we can share the vtinfo's
    Expression *e = new VarExp(0, t->vtinfo);
    e = e->addressOf(sc);
    e->type = t->vtinfo->type;          // do this so we don't get redundant dereference
    return e;
}

TypeInfoDeclaration *Type::getTypeInfoDeclaration()
{
    //printf("Type::getTypeInfoDeclaration() %s\n", toChars());
    return new TypeInfoDeclaration(this, 0);
}

TypeInfoDeclaration *TypeTypedef::getTypeInfoDeclaration()
{
    return new TypeInfoTypedefDeclaration(this);
}

TypeInfoDeclaration *TypePointer::getTypeInfoDeclaration()
{
    return new TypeInfoPointerDeclaration(this);
}

TypeInfoDeclaration *TypeDArray::getTypeInfoDeclaration()
{
    return new TypeInfoArrayDeclaration(this);
}

TypeInfoDeclaration *TypeSArray::getTypeInfoDeclaration()
{
    return new TypeInfoStaticArrayDeclaration(this);
}

TypeInfoDeclaration *TypeAArray::getTypeInfoDeclaration()
{
    return new TypeInfoAssociativeArrayDeclaration(this);
}

TypeInfoDeclaration *TypeStruct::getTypeInfoDeclaration()
{
    return new TypeInfoStructDeclaration(this);
}

TypeInfoDeclaration *TypeClass::getTypeInfoDeclaration()
{
    if (sym->isInterfaceDeclaration())
        return new TypeInfoInterfaceDeclaration(this);
    else
        return new TypeInfoClassDeclaration(this);
}

TypeInfoDeclaration *TypeEnum::getTypeInfoDeclaration()
{
    return new TypeInfoEnumDeclaration(this);
}

TypeInfoDeclaration *TypeFunction::getTypeInfoDeclaration()
{
    return new TypeInfoFunctionDeclaration(this);
}

TypeInfoDeclaration *TypeDelegate::getTypeInfoDeclaration()
{
    return new TypeInfoDelegateDeclaration(this);
}

TypeInfoDeclaration *TypeTuple::getTypeInfoDeclaration()
{
    return new TypeInfoTupleDeclaration(this);
}

/****************************************************
 */

#if 1

void TypeInfoDeclaration::toDt(dt_t **pdt)
{
    //printf("TypeInfoDeclaration::toDt() %s\n", toChars());
    dtxoff(pdt, Type::typeinfo->toVtblSymbol(), 0); // vtbl for TypeInfo
    dtsize_t(pdt, 0);                        // monitor
}

#if DMDV2
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
    dtxoff(pdt, Type::typeinfowild->toVtblSymbol(), 0); // vtbl for TypeInfo_Wild
    dtsize_t(pdt, 0);                        // monitor
    Type *tm = tinfo->mutableOf();
    tm = tm->merge();
    tm->getTypeInfo(NULL);
    dtxoff(pdt, tm->vtinfo->toSymbol(), 0);
}

#endif

void TypeInfoTypedefDeclaration::toDt(dt_t **pdt)
{
    //printf("TypeInfoTypedefDeclaration::toDt() %s\n", toChars());

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
    dtxoff(pdt, sd->memtype->vtinfo->toSymbol(), 0);    // TypeInfo for enum members
    }
    else
        dtsize_t(pdt, 0);

    const char *name = sd->toPrettyChars();
    size_t namelen = strlen(name);
    dtsize_t(pdt, namelen);
    dtabytes(pdt, 0, namelen + 1, name);

    // void[] init;
    if (!sd->defaultval || tinfo->isZeroInit())
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
    dtxoff(pdt, Type::typeinfostaticarray->toVtblSymbol(), 0); // vtbl for TypeInfo_StaticArray
    dtsize_t(pdt, 0);                        // monitor

    assert(tinfo->ty == Tsarray);

    TypeSArray *tc = (TypeSArray *)tinfo;

    tc->next->getTypeInfo(NULL);
    dtxoff(pdt, tc->next->vtinfo->toSymbol(), 0); // TypeInfo for array of type

    dtsize_t(pdt, tc->dim->toInteger());         // length
}

void TypeInfoAssociativeArrayDeclaration::toDt(dt_t **pdt)
{
    //printf("TypeInfoAssociativeArrayDeclaration::toDt()\n");
    dtxoff(pdt, Type::typeinfoassociativearray->toVtblSymbol(), 0); // vtbl for TypeInfo_AssociativeArray
    dtsize_t(pdt, 0);                        // monitor

    assert(tinfo->ty == Taarray);

    TypeAArray *tc = (TypeAArray *)tinfo;

    tc->next->getTypeInfo(NULL);
    dtxoff(pdt, tc->next->vtinfo->toSymbol(), 0); // TypeInfo for array of type

    tc->index->getTypeInfo(NULL);
    dtxoff(pdt, tc->index->vtinfo->toSymbol(), 0); // TypeInfo for array of type

#if DMDV2
    tc->getImpl()->type->getTypeInfo(NULL);
    dtxoff(pdt, tc->getImpl()->type->vtinfo->toSymbol(), 0);    // impl
#endif
}

void TypeInfoFunctionDeclaration::toDt(dt_t **pdt)
{
    //printf("TypeInfoFunctionDeclaration::toDt()\n");
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

void TypeInfoStructDeclaration::toDt(dt_t **pdt)
{
    //printf("TypeInfoStructDeclaration::toDt() '%s'\n", toChars());

    unsigned offset = Type::typeinfostruct->structsize;

    // If using obsolete 32 bit object.d
    if (!global.params.is64bit && !Type::typeinfostruct->search(NULL, Id::m_align, 0))
        offset += 4;                         // include space for m_align

    dtxoff(pdt, Type::typeinfostruct->toVtblSymbol(), 0); // vtbl for TypeInfo_Struct
    dtsize_t(pdt, 0);                        // monitor

    assert(tinfo->ty == Tstruct);

    TypeStruct *tc = (TypeStruct *)tinfo;
    StructDeclaration *sd = tc->sym;

    /* Put out:
     *  char[] name;
     *  void[] init;
     *  hash_t function(void*) xtoHash;
     *  int function(void*,void*) xopEquals;
     *  int function(void*,void*) xopCmp;
     *  char[] function(void*) xtoString;
     *  uint m_flags;
     *  uint m_align;
     *  version (X86_64)
     *      TypeInfo m_arg1;
     *      TypeInfo m_arg2;
     *
     *  name[]
     */

    const char *name = sd->toPrettyChars();
    size_t namelen = strlen(name);
    dtsize_t(pdt, namelen);
    //dtabytes(pdt, 0, namelen + 1, name);
    dtxoff(pdt, toSymbol(), offset);
    offset += namelen + 1;

    // void[] init;
    dtsize_t(pdt, sd->structsize);       // init.length
    if (sd->zeroInit)
        dtsize_t(pdt, 0);                // NULL for 0 initialization
    else
        dtxoff(pdt, sd->toInitializer(), 0);    // init.ptr

    FuncDeclaration *fd;
    FuncDeclaration *fdx;
    TypeFunction *tf;
    Type *ta;
    Dsymbol *s;

    static TypeFunction *tftohash;
    static TypeFunction *tftostring;

    if (!tftohash)
    {
        Scope sc;

        tftohash = new TypeFunction(NULL, Type::thash_t, 0, LINKd);
        tftohash = (TypeFunction *)tftohash->semantic(0, &sc);

        tftostring = new TypeFunction(NULL, Type::tchar->arrayOf(), 0, LINKd);
        tftostring = (TypeFunction *)tftostring->semantic(0, &sc);
    }

    TypeFunction *tfeqptr;
    {
        Scope sc;
        Parameters *arguments = new Parameters;
#if STRUCTTHISREF
        // arg type is ref const T
        Parameter *arg = new Parameter(STCref, tc->constOf(), NULL, NULL);
#else
        // arg type is const T*
        Parameter *arg = new Parameter(STCin, tc->pointerTo(), NULL, NULL);
#endif

        arguments->push(arg);
        tfeqptr = new TypeFunction(arguments, Type::tint32, 0, LINKd);
        tfeqptr = (TypeFunction *)tfeqptr->semantic(0, &sc);
    }

#if 0
    TypeFunction *tfeq;
    {
        Scope sc;
        Array *arguments = new Array;
        Parameter *arg = new Parameter(In, tc, NULL, NULL);

        arguments->push(arg);
        tfeq = new TypeFunction(arguments, Type::tint32, 0, LINKd);
        tfeq = (TypeFunction *)tfeq->semantic(0, &sc);
    }
#endif

    s = search_function(sd, Id::tohash);
    fdx = s ? s->isFuncDeclaration() : NULL;
    if (fdx)
    {   fd = fdx->overloadExactMatch(tftohash);
        if (fd)
            dtxoff(pdt, fd->toSymbol(), 0);
        else
            //fdx->error("must be declared as extern (D) uint toHash()");
            dtsize_t(pdt, 0);
    }
    else
        dtsize_t(pdt, 0);

    s = search_function(sd, Id::eq);
    fdx = s ? s->isFuncDeclaration() : NULL;
    for (int i = 0; i < 2; i++)
    {
        if (fdx)
        {
            fd = fdx->overloadExactMatch(tfeqptr);
            if (fd)
                dtxoff(pdt, fd->toSymbol(), 0);
            else
            {
                fdx->deprecation(loc, "must be declared as `extern (D) int %s(%s)` "
                    "or it will be ignored by TypeInfo",
                    fdx->toChars(), sd->toChars());
                dtsize_t(pdt, 0);
            }
        }
        else
            dtsize_t(pdt, 0);

        s = search_function(sd, Id::cmp);
        fdx = s ? s->isFuncDeclaration() : NULL;
    }

    s = search_function(sd, Id::tostring);
    fdx = s ? s->isFuncDeclaration() : NULL;
    if (fdx)
    {   fd = fdx->overloadExactMatch(tftostring);
        if (fd)
            dtxoff(pdt, fd->toSymbol(), 0);
        else
            //fdx->error("must be declared as extern (D) char[] toString()");
            dtsize_t(pdt, 0);
    }
    else
        dtsize_t(pdt, 0);

    // uint m_flags;
    dtdword(pdt, tc->hasPointers());

    // uint m_align;
    dtdword(pdt, tc->alignsize());

#if DMDV2
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
#endif
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

    // name[]
    dtnbytes(pdt, namelen + 1, name);
}

void TypeInfoClassDeclaration::toDt(dt_t **pdt)
{
    //printf("TypeInfoClassDeclaration::toDt() %s\n", tinfo->toChars());
#if DMDV1
    dtxoff(pdt, Type::typeinfoclass->toVtblSymbol(), 0); // vtbl for TypeInfoClass
    dtsize_t(pdt, 0);                        // monitor

    assert(tinfo->ty == Tclass);

    TypeClass *tc = (TypeClass *)tinfo;
    Symbol *s;

    if (!tc->sym->vclassinfo)
        tc->sym->vclassinfo = new ClassInfoDeclaration(tc->sym);
    s = tc->sym->vclassinfo->toSymbol();
    dtxoff(pdt, s, 0);          // ClassInfo for tinfo
#else
    assert(0);
#endif
}

void TypeInfoInterfaceDeclaration::toDt(dt_t **pdt)
{
    //printf("TypeInfoInterfaceDeclaration::toDt() %s\n", tinfo->toChars());
    dtxoff(pdt, Type::typeinfointerface->toVtblSymbol(), 0); // vtbl for TypeInfoInterface
    dtsize_t(pdt, 0);                        // monitor

    assert(tinfo->ty == Tclass);

    TypeClass *tc = (TypeClass *)tinfo;
    Symbol *s;

    if (!tc->sym->vclassinfo)
#if DMDV1
        tc->sym->vclassinfo = new ClassInfoDeclaration(tc->sym);
#else
        tc->sym->vclassinfo = new TypeInfoClassDeclaration(tc);
#endif
    s = tc->sym->vclassinfo->toSymbol();
    dtxoff(pdt, s, 0);          // ClassInfo for tinfo
}

void TypeInfoTupleDeclaration::toDt(dt_t **pdt)
{
    //printf("TypeInfoTupleDeclaration::toDt() %s\n", tinfo->toChars());
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

    Symbol *s = static_sym();
    s->Sdt = d;
    outdata(s);

    dtxoff(pdt, s, 0);              // elements.ptr
}

void TypeInfoDeclaration::toObjFile(int multiobj)
{
    //printf("TypeInfoDeclaration::toObjFile(%p '%s') protection %d\n", this, toChars(), protection);

    if (multiobj)
    {
        obj_append(this);
        return;
    }

    Symbol *s = toSymbol();
    s->Sclass = SCcomdat;
    s->Sfl = FLdata;

    toDt(&s->Sdt);

    dt_optimize(s->Sdt);

    // See if we can convert a comdat to a comdef,
    // which saves on exe file space.
    if (s->Sclass == SCcomdat &&
        dtallzeros(s->Sdt))
    {
        s->Sclass = SCglobal;
        dt2common(&s->Sdt);
    }

    outdata(s);
    if (isExport())
        objmod->export_symbol(s,0);
}

#endif

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
#if DMDV2
    return mod ? 0 : 1;
#else
    return 1;
#endif
}

int TypeDArray::builtinTypeInfo()
{
#if DMDV2
    return !mod && (next->isTypeBasic() != NULL && !next->mod ||
        // strings are so common, make them builtin
        next->ty == Tchar && next->mod == MODimmutable);
#else
    return next->isTypeBasic() != NULL;
#endif
}

int TypeClass::builtinTypeInfo()
{
    /* This is statically put out with the ClassInfo, so
     * claim it is built in so it isn't regenerated by each module.
     */
#if DMDV2
    return mod ? 0 : 1;
#else
    return 1;
#endif
}

/* ========================================================================= */

/***************************************
 * Create a static array of TypeInfo references
 * corresponding to an array of Expression's.
 * Used to supply hidden _arguments[] value for variadic D functions.
 */

Expression *createTypeInfoArray(Scope *sc, Expression *exps[], unsigned dim)
{
#if 1
    /*
     * Pass a reference to the TypeInfo_Tuple corresponding to the types of the
     * arguments. Source compatibility is maintained by computing _arguments[]
     * at the start of the called function by offseting into the TypeInfo_Tuple
     * reference.
     */
    Parameters *args = new Parameters;
    args->setDim(dim);
    for (size_t i = 0; i < dim; i++)
    {   Parameter *arg = new Parameter(STCin, exps[i]->type, NULL, NULL);
        (*args)[i] = arg;
    }
    TypeTuple *tup = new TypeTuple(args);
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
            ai->addInit(new IntegerExp(i), new ExpInitializer(0, e));
        }

        t = Type::typeinfo->type->arrayOf();
        ai->type = t;
        v = new VarDeclaration(0, t, id, ai);
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
    e = new VarExp(0, v);
    e = e->semantic(sc);
    return e;
#endif
}



