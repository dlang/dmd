
// Compiler implementation of the D programming language
// Copyright (c) 1999-2011 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

#include "root.h"
#include "rmem.h"

#include "enum.h"
#include "init.h"
#include "attrib.h"
#include "declaration.h"
#include "aggregate.h"
#include "id.h"
#include "mtype.h"
#include "scope.h"
#include "module.h"
#include "expression.h"
#include "statement.h"

/********************************* ClassDeclaration ****************************/

ClassDeclaration *ClassDeclaration::classinfo;
ClassDeclaration *ClassDeclaration::object;
ClassDeclaration *ClassDeclaration::throwable;
ClassDeclaration *ClassDeclaration::exception;

ClassDeclaration::ClassDeclaration(Loc loc, Identifier *id, BaseClasses *baseclasses)
    : AggregateDeclaration(loc, id)
{
    static char msg[] = "only object.d can define this reserved class name";

    if (baseclasses)
        // Actually, this is a transfer
        this->baseclasses = baseclasses;
    else
        this->baseclasses = new BaseClasses();
    baseClass = NULL;

    interfaces_dim = 0;
    interfaces = NULL;

    vtblInterfaces = NULL;

    //printf("ClassDeclaration(%s), dim = %d\n", id->toChars(), this->baseclasses->dim);

    // For forward references
    type = new TypeClass(this);
    handle = type;

    staticCtor = NULL;
    staticDtor = NULL;

    vtblsym = NULL;
    vclassinfo = NULL;

    if (id)
    {   // Look for special class names

        if (id == Id::__sizeof || id == Id::__xalignof || id == Id::mangleof)
            error("illegal class name");

        // BUG: What if this is the wrong TypeInfo, i.e. it is nested?
        if (id->toChars()[0] == 'T')
        {
            if (id == Id::TypeInfo)
            {   if (Type::typeinfo)
                    Type::typeinfo->error("%s", msg);
                Type::typeinfo = this;
            }

            if (id == Id::TypeInfo_Class)
            {   if (Type::typeinfoclass)
                    Type::typeinfoclass->error("%s", msg);
                Type::typeinfoclass = this;
            }

            if (id == Id::TypeInfo_Interface)
            {   if (Type::typeinfointerface)
                    Type::typeinfointerface->error("%s", msg);
                Type::typeinfointerface = this;
            }

            if (id == Id::TypeInfo_Struct)
            {   if (Type::typeinfostruct)
                    Type::typeinfostruct->error("%s", msg);
                Type::typeinfostruct = this;
            }

            if (id == Id::TypeInfo_Typedef)
            {   if (Type::typeinfotypedef)
                    Type::typeinfotypedef->error("%s", msg);
                Type::typeinfotypedef = this;
            }

            if (id == Id::TypeInfo_Pointer)
            {   if (Type::typeinfopointer)
                    Type::typeinfopointer->error("%s", msg);
                Type::typeinfopointer = this;
            }

            if (id == Id::TypeInfo_Array)
            {   if (Type::typeinfoarray)
                    Type::typeinfoarray->error("%s", msg);
                Type::typeinfoarray = this;
            }

            if (id == Id::TypeInfo_StaticArray)
            {   //if (Type::typeinfostaticarray)
                    //Type::typeinfostaticarray->error("%s", msg);
                Type::typeinfostaticarray = this;
            }

            if (id == Id::TypeInfo_AssociativeArray)
            {   if (Type::typeinfoassociativearray)
                    Type::typeinfoassociativearray->error("%s", msg);
                Type::typeinfoassociativearray = this;
            }

            if (id == Id::TypeInfo_Enum)
            {   if (Type::typeinfoenum)
                    Type::typeinfoenum->error("%s", msg);
                Type::typeinfoenum = this;
            }

            if (id == Id::TypeInfo_Function)
            {   if (Type::typeinfofunction)
                    Type::typeinfofunction->error("%s", msg);
                Type::typeinfofunction = this;
            }

            if (id == Id::TypeInfo_Delegate)
            {   if (Type::typeinfodelegate)
                    Type::typeinfodelegate->error("%s", msg);
                Type::typeinfodelegate = this;
            }

            if (id == Id::TypeInfo_Tuple)
            {   if (Type::typeinfotypelist)
                    Type::typeinfotypelist->error("%s", msg);
                Type::typeinfotypelist = this;
            }

#if DMDV2
            if (id == Id::TypeInfo_Const)
            {   if (Type::typeinfoconst)
                    Type::typeinfoconst->error("%s", msg);
                Type::typeinfoconst = this;
            }

            if (id == Id::TypeInfo_Invariant)
            {   if (Type::typeinfoinvariant)
                    Type::typeinfoinvariant->error("%s", msg);
                Type::typeinfoinvariant = this;
            }

            if (id == Id::TypeInfo_Shared)
            {   if (Type::typeinfoshared)
                    Type::typeinfoshared->error("%s", msg);
                Type::typeinfoshared = this;
            }

            if (id == Id::TypeInfo_Wild)
            {   if (Type::typeinfowild)
                    Type::typeinfowild->error("%s", msg);
                Type::typeinfowild = this;
            }
#endif
        }

        if (id == Id::Object)
        {   if (object)
                object->error("%s", msg);
            object = this;
        }

        if (id == Id::Throwable)
        {   if (throwable)
                throwable->error("%s", msg);
            throwable = this;
        }

        if (id == Id::Exception)
        {   if (exception)
                exception->error("%s", msg);
            exception = this;
        }

        //if (id == Id::ClassInfo)
        if (id == Id::TypeInfo_Class)
        {   if (classinfo)
                classinfo->error("%s", msg);
            classinfo = this;
        }

        if (id == Id::ModuleInfo)
        {   if (Module::moduleinfo)
                Module::moduleinfo->error("%s", msg);
            Module::moduleinfo = this;
        }
    }

    com = 0;
    isscope = 0;
    isabstract = 0;
    inuse = 0;
}

Dsymbol *ClassDeclaration::syntaxCopy(Dsymbol *s)
{
    ClassDeclaration *cd;

    //printf("ClassDeclaration::syntaxCopy('%s')\n", toChars());
    if (s)
        cd = (ClassDeclaration *)s;
    else
        cd = new ClassDeclaration(loc, ident, NULL);

    cd->storage_class |= storage_class;

    cd->baseclasses->setDim(this->baseclasses->dim);
    for (size_t i = 0; i < cd->baseclasses->dim; i++)
    {
        BaseClass *b = this->baseclasses->tdata()[i];
        BaseClass *b2 = new BaseClass(b->type->syntaxCopy(), b->protection);
        cd->baseclasses->tdata()[i] = b2;
    }

    ScopeDsymbol::syntaxCopy(cd);
    return cd;
}

void ClassDeclaration::semantic(Scope *sc)
{
    //printf("ClassDeclaration::semantic(%s), type = %p, sizeok = %d, this = %p\n", toChars(), type, sizeok, this);
    //printf("\tparent = %p, '%s'\n", sc->parent, sc->parent ? sc->parent->toChars() : "");
    //printf("sc->stc = %x\n", sc->stc);

    //{ static int n;  if (++n == 20) *(char*)0=0; }

    if (!ident)         // if anonymous class
    {   const char *id = "__anonclass";

        ident = Identifier::generateId(id);
    }

    if (!sc)
        sc = scope;
    if (!parent && sc->parent && !sc->parent->isModule())
        parent = sc->parent;

    type = type->semantic(loc, sc);
    handle = type;

    if (!members)                       // if forward reference
    {   //printf("\tclass '%s' is forward referenced\n", toChars());
        return;
    }
    if (symtab)
    {   if (sizeok == 1 || !scope)
        {   //printf("\tsemantic for '%s' is already completed\n", toChars());
            return;             // semantic() already completed
        }
    }
    else
        symtab = new DsymbolTable();

    Scope *scx = NULL;
    if (scope)
    {   sc = scope;
        scx = scope;            // save so we don't make redundant copies
        scope = NULL;
    }
    unsigned dprogress_save = Module::dprogress;
#ifdef IN_GCC
    methods.setDim(0);
#endif

    if (sc->stc & STCdeprecated)
    {
        isdeprecated = 1;
    }

    if (sc->linkage == LINKcpp)
        error("cannot create C++ classes");

    // Expand any tuples in baseclasses[]
    for (size_t i = 0; i < baseclasses->dim; )
    {   BaseClass *b = baseclasses->tdata()[i];
//printf("test1 %s %s\n", toChars(), b->type->toChars());
        b->type = b->type->semantic(loc, sc);
//printf("test2\n");
        Type *tb = b->type->toBasetype();

        if (tb->ty == Ttuple)
        {   TypeTuple *tup = (TypeTuple *)tb;
            enum PROT protection = b->protection;
            baseclasses->remove(i);
            size_t dim = Parameter::dim(tup->arguments);
            for (size_t j = 0; j < dim; j++)
            {   Parameter *arg = Parameter::getNth(tup->arguments, j);
                b = new BaseClass(arg->type, protection);
                baseclasses->insert(i + j, b);
            }
        }
        else
            i++;
    }

    // See if there's a base class as first in baseclasses[]
    if (baseclasses->dim)
    {   TypeClass *tc;
        BaseClass *b;
        Type *tb;

        b = baseclasses->tdata()[0];
        //b->type = b->type->semantic(loc, sc);
        tb = b->type->toBasetype();
        if (tb->ty != Tclass)
        {   error("base type must be class or interface, not %s", b->type->toChars());
            baseclasses->remove(0);
        }
        else
        {
            tc = (TypeClass *)(tb);

            if (tc->sym->isDeprecated())
            {
                if (!isDeprecated())
                {
                    // Deriving from deprecated class makes this one deprecated too
                    isdeprecated = 1;

                    tc->checkDeprecated(loc, sc);
                }
            }

            if (tc->sym->isInterfaceDeclaration())
                ;
            else
            {
                for (ClassDeclaration *cdb = tc->sym; cdb; cdb = cdb->baseClass)
                {
                    if (cdb == this)
                    {
                        error("circular inheritance");
                        baseclasses->remove(0);
                        goto L7;
                    }
                }
                if (!tc->sym->symtab || tc->sym->sizeok == 0)
                {   // Try to resolve forward reference
                    if (/*sc->mustsemantic &&*/ tc->sym->scope)
                        tc->sym->semantic(NULL);
                }
                if (!tc->sym->symtab || tc->sym->scope || tc->sym->sizeok == 0)
                {
                    //printf("%s: forward reference of base class %s\n", toChars(), tc->sym->toChars());
                    //error("forward reference of base class %s", baseClass->toChars());
                    // Forward reference of base class, try again later
                    //printf("\ttry later, forward reference of base class %s\n", tc->sym->toChars());
                    scope = scx ? scx : new Scope(*sc);
                    scope->setNoFree();
                    if (tc->sym->scope)
                        tc->sym->scope->module->addDeferredSemantic(tc->sym);
                    scope->module->addDeferredSemantic(this);
                    return;
                }
                else
                {   baseClass = tc->sym;
                    b->base = baseClass;
                }
             L7: ;
            }
        }
    }

    // Treat the remaining entries in baseclasses as interfaces
    // Check for errors, handle forward references
    for (size_t i = (baseClass ? 1 : 0); i < baseclasses->dim; )
    {   TypeClass *tc;
        BaseClass *b;
        Type *tb;

        b = baseclasses->tdata()[i];
        b->type = b->type->semantic(loc, sc);
        tb = b->type->toBasetype();
        if (tb->ty == Tclass)
            tc = (TypeClass *)tb;
        else
            tc = NULL;
        if (!tc || !tc->sym->isInterfaceDeclaration())
        {
            error("base type must be interface, not %s", b->type->toChars());
            baseclasses->remove(i);
            continue;
        }
        else
        {
            if (tc->sym->isDeprecated())
            {
                if (!isDeprecated())
                {
                    // Deriving from deprecated class makes this one deprecated too
                    isdeprecated = 1;

                    tc->checkDeprecated(loc, sc);
                }
            }

            // Check for duplicate interfaces
            for (size_t j = (baseClass ? 1 : 0); j < i; j++)
            {
                BaseClass *b2 = baseclasses->tdata()[j];
                if (b2->base == tc->sym)
                    error("inherits from duplicate interface %s", b2->base->toChars());
            }

            if (!tc->sym->symtab)
            {   // Try to resolve forward reference
                if (/*sc->mustsemantic &&*/ tc->sym->scope)
                    tc->sym->semantic(NULL);
            }

            b->base = tc->sym;
            if (!b->base->symtab || b->base->scope)
            {
                //error("forward reference of base class %s", baseClass->toChars());
                // Forward reference of base, try again later
                //printf("\ttry later, forward reference of base %s\n", baseClass->toChars());
                scope = scx ? scx : new Scope(*sc);
                scope->setNoFree();
                if (tc->sym->scope)
                    tc->sym->scope->module->addDeferredSemantic(tc->sym);
                scope->module->addDeferredSemantic(this);
                return;
            }
        }
        i++;
    }


    // If no base class, and this is not an Object, use Object as base class
    if (!baseClass && ident != Id::Object)
    {
        // BUG: what if Object is redefined in an inner scope?
        Type *tbase = new TypeIdentifier(0, Id::Object);
        BaseClass *b;
        TypeClass *tc;
        Type *bt;

        if (!object)
        {
            error("missing or corrupt object.d");
            fatal();
        }
        bt = tbase->semantic(loc, sc)->toBasetype();
        b = new BaseClass(bt, PROTpublic);
        baseclasses->shift(b);
        assert(b->type->ty == Tclass);
        tc = (TypeClass *)(b->type);
        baseClass = tc->sym;
        assert(!baseClass->isInterfaceDeclaration());
        b->base = baseClass;
    }

    interfaces_dim = baseclasses->dim;
    interfaces = baseclasses->tdata();


    if (baseClass)
    {
        if (baseClass->storage_class & STCfinal)
            error("cannot inherit from final class %s", baseClass->toChars());

        interfaces_dim--;
        interfaces++;

        // Copy vtbl[] from base class
        vtbl.setDim(baseClass->vtbl.dim);
        memcpy(vtbl.tdata(), baseClass->vtbl.tdata(), sizeof(void *) * vtbl.dim);

        // Inherit properties from base class
        com = baseClass->isCOMclass();
        isscope = baseClass->isscope;
        vthis = baseClass->vthis;
        storage_class |= baseClass->storage_class & STC_TYPECTOR;
    }
    else
    {
        // No base class, so this is the root of the class hierarchy
        vtbl.setDim(0);
        vtbl.push(this);                // leave room for classinfo as first member
    }

    protection = sc->protection;
    storage_class |= sc->stc;

    if (sizeok == 0)
    {
        interfaceSemantic(sc);

        for (size_t i = 0; i < members->dim; i++)
        {
            Dsymbol *s = members->tdata()[i];
            s->addMember(sc, this, 1);
        }

        /* If this is a nested class, add the hidden 'this'
         * member which is a pointer to the enclosing scope.
         */
        if (vthis)              // if inheriting from nested class
        {   // Use the base class's 'this' member
            isnested = 1;
            if (storage_class & STCstatic)
                error("static class cannot inherit from nested class %s", baseClass->toChars());
            if (toParent2() != baseClass->toParent2())
            {
                if (toParent2())
                {
                    error("is nested within %s, but super class %s is nested within %s",
                        toParent2()->toChars(),
                        baseClass->toChars(),
                        baseClass->toParent2()->toChars());
                }
                else
                {
                    error("is not nested, but super class %s is nested within %s",
                        baseClass->toChars(),
                        baseClass->toParent2()->toChars());
                }
                isnested = 0;
            }
        }
        else if (!(storage_class & STCstatic))
        {   Dsymbol *s = toParent2();
            if (s)
            {
                AggregateDeclaration *ad = s->isClassDeclaration();
                FuncDeclaration *fd = s->isFuncDeclaration();


                if (ad || fd)
                {   isnested = 1;
                    Type *t;
                    if (ad)
                        t = ad->handle;
                    else if (fd)
                    {   AggregateDeclaration *ad2 = fd->isMember2();
                        if (ad2)
                            t = ad2->handle;
                        else
                        {
                            t = Type::tvoidptr;
                        }
                    }
                    else
                        assert(0);
                    if (t->ty == Tstruct)       // ref to struct
                        t = Type::tvoidptr;
                    assert(!vthis);
                    vthis = new ThisDeclaration(loc, t);
                    members->push(vthis);
                }
            }
        }
    }

    if (storage_class & STCauto)
        error("storage class 'auto' is invalid when declaring a class, did you mean to use 'scope'?");
    if (storage_class & STCscope)
        isscope = 1;
    if (storage_class & STCabstract)
        isabstract = 1;

    if (storage_class & STCimmutable)
        type = type->addMod(MODimmutable);
    if (storage_class & STCconst)
        type = type->addMod(MODconst);
    if (storage_class & STCshared)
        type = type->addMod(MODshared);

    sc = sc->push(this);
    //sc->stc &= ~(STCfinal | STCauto | STCscope | STCstatic | STCabstract | STCdeprecated | STC_TYPECTOR | STCtls | STCgshared);
    //sc->stc |= storage_class & STC_TYPECTOR;
    sc->stc &= STCsafe | STCtrusted | STCsystem;
    sc->parent = this;
    sc->inunion = 0;

    if (isCOMclass())
    {
#if _WIN32
        sc->linkage = LINKwindows;
#else
        /* This enables us to use COM objects under Linux and
         * work with things like XPCOM
         */
        sc->linkage = LINKc;
#endif
    }
    sc->protection = PROTpublic;
    sc->explicitProtection = 0;
    sc->structalign = 8;
    structalign = sc->structalign;
    if (baseClass)
    {   sc->offset = baseClass->structsize;
        alignsize = baseClass->alignsize;
//      if (isnested)
//          sc->offset += PTRSIZE;      // room for uplevel context pointer
    }
    else
    {   sc->offset = PTRSIZE * 2;       // allow room for __vptr and __monitor
        alignsize = PTRSIZE;
    }
    structsize = sc->offset;
    Scope scsave = *sc;
    size_t members_dim = members->dim;
    sizeok = 0;

    /* Set scope so if there are forward references, we still might be able to
     * resolve individual members like enums.
     */
    for (size_t i = 0; i < members_dim; i++)
    {   Dsymbol *s = members->tdata()[i];
        /* There are problems doing this in the general case because
         * Scope keeps track of things like 'offset'
         */
        if (s->isEnumDeclaration() || (s->isAggregateDeclaration() && s->ident))
        {
            //printf("setScope %s %s\n", s->kind(), s->toChars());
            s->setScope(sc);
        }
    }

    for (size_t i = 0; i < members_dim; i++)
    {   Dsymbol *s = members->tdata()[i];
        s->semantic(sc);
    }

    if (sizeok == 2)
    {   // semantic() failed because of forward references.
        // Unwind what we did, and defer it for later
        fields.setDim(0);
        structsize = 0;
        alignsize = 0;
        structalign = 0;

        sc = sc->pop();

        scope = scx ? scx : new Scope(*sc);
        scope->setNoFree();
        scope->module->addDeferredSemantic(this);

        Module::dprogress = dprogress_save;

        //printf("\tsemantic('%s') failed due to forward references\n", toChars());
        return;
    }

    //printf("\tsemantic('%s') successful\n", toChars());

    structsize = sc->offset;
    //members->print();

    /* Look for special member functions.
     * They must be in this class, not in a base class.
     */
    ctor = (CtorDeclaration *)search(0, Id::ctor, 0);
    if (ctor && (ctor->toParent() != this || !ctor->isCtorDeclaration()))
        ctor = NULL;

//    dtor = (DtorDeclaration *)search(Id::dtor, 0);
//    if (dtor && dtor->toParent() != this)
//      dtor = NULL;

//    inv = (InvariantDeclaration *)search(Id::classInvariant, 0);
//    if (inv && inv->toParent() != this)
//      inv = NULL;

    // Can be in base class
    aggNew    = (NewDeclaration *)search(0, Id::classNew, 0);
    aggDelete = (DeleteDeclaration *)search(0, Id::classDelete, 0);

    // If this class has no constructor, but base class does, create
    // a constructor:
    //    this() { }
    if (!ctor && baseClass && baseClass->ctor)
    {
        //printf("Creating default this(){} for class %s\n", toChars());
                Type *tf = new TypeFunction(NULL, NULL, 0, LINKd, 0);
        CtorDeclaration *ctor = new CtorDeclaration(loc, 0, 0, tf);
        ctor->fbody = new CompoundStatement(0, new Statements());
        members->push(ctor);
        ctor->addMember(sc, this, 1);
        *sc = scsave;   // why? What about sc->nofree?
        sc->offset = structsize;
        ctor->semantic(sc);
        this->ctor = ctor;
        defaultCtor = ctor;
    }

#if 0
    if (baseClass)
    {   if (!aggDelete)
            aggDelete = baseClass->aggDelete;
        if (!aggNew)
            aggNew = baseClass->aggNew;
    }
#endif

    // Allocate instance of each new interface
    for (size_t i = 0; i < vtblInterfaces->dim; i++)
    {
        BaseClass *b = vtblInterfaces->tdata()[i];
        unsigned thissize = PTRSIZE;

        alignmember(structalign, thissize, &sc->offset);
        assert(b->offset == 0);
        b->offset = sc->offset;

        // Take care of single inheritance offsets
        while (b->baseInterfaces_dim)
        {
            b = &b->baseInterfaces[0];
            b->offset = sc->offset;
        }

        sc->offset += thissize;
        if (alignsize < thissize)
            alignsize = thissize;
    }
    structsize = sc->offset;
    sizeok = 1;
    Module::dprogress++;

    dtor = buildDtor(sc);

    sc->pop();

#if 0 // Do not call until toObjfile() because of forward references
    // Fill in base class vtbl[]s
    for (i = 0; i < vtblInterfaces->dim; i++)
    {
        BaseClass *b = vtblInterfaces->tdata()[i];

        //b->fillVtbl(this, &b->vtbl, 1);
    }
#endif
    //printf("-ClassDeclaration::semantic(%s), type = %p\n", toChars(), type);

    if (deferred)
    {
        deferred->semantic2(sc);
        deferred->semantic3(sc);
    }
}

void ClassDeclaration::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    if (!isAnonymous())
    {
        buf->printf("%s ", kind());
        buf->writestring(toChars());
        if (baseclasses->dim)
            buf->writestring(" : ");
    }
    for (size_t i = 0; i < baseclasses->dim; i++)
    {
        BaseClass *b = baseclasses->tdata()[i];

        if (i)
            buf->writeByte(',');
        //buf->writestring(b->base->ident->toChars());
        b->type->toCBuffer(buf, NULL, hgs);
    }
    if (members)
    {
        buf->writenl();
        buf->writeByte('{');
        buf->writenl();
        for (size_t i = 0; i < members->dim; i++)
        {
            Dsymbol *s = members->tdata()[i];

            buf->writestring("    ");
            s->toCBuffer(buf, hgs);
        }
        buf->writestring("}");
    }
    else
        buf->writeByte(';');
    buf->writenl();
}

#if 0
void ClassDeclaration::defineRef(Dsymbol *s)
{
    ClassDeclaration *cd;

    AggregateDeclaration::defineRef(s);
    cd = s->isClassDeclaration();
    baseType = cd->baseType;
    cd->baseType = NULL;
}
#endif

/*********************************************
 * Determine if 'this' is a base class of cd.
 * This is used to detect circular inheritance only.
 */

int ClassDeclaration::isBaseOf2(ClassDeclaration *cd)
{
    if (!cd)
        return 0;
    //printf("ClassDeclaration::isBaseOf2(this = '%s', cd = '%s')\n", toChars(), cd->toChars());
    for (size_t i = 0; i < cd->baseclasses->dim; i++)
    {   BaseClass *b = cd->baseclasses->tdata()[i];

        if (b->base == this || isBaseOf2(b->base))
            return 1;
    }
    return 0;
}

/*******************************************
 * Determine if 'this' is a base class of cd.
 */

int ClassDeclaration::isBaseOf(ClassDeclaration *cd, int *poffset)
{
    //printf("ClassDeclaration::isBaseOf(this = '%s', cd = '%s')\n", toChars(), cd->toChars());
    if (poffset)
        *poffset = 0;
    while (cd)
    {
        /* cd->baseClass might not be set if cd is forward referenced.
         */
        if (!cd->baseClass && cd->baseclasses->dim && !cd->isInterfaceDeclaration())
        {
            cd->semantic(NULL);
            if (!cd->baseClass)
                cd->error("base class is forward referenced by %s", toChars());
        }

        if (this == cd->baseClass)
            return 1;

        cd = cd->baseClass;
    }
    return 0;
}

/*********************************************
 * Determine if 'this' has complete base class information.
 * This is used to detect forward references in covariant overloads.
 */

int ClassDeclaration::isBaseInfoComplete()
{
    if (!baseClass)
        return ident == Id::Object;
    for (size_t i = 0; i < baseclasses->dim; i++)
    {   BaseClass *b = baseclasses->tdata()[i];
        if (!b->base || !b->base->isBaseInfoComplete())
            return 0;
    }
    return 1;
}

Dsymbol *ClassDeclaration::search(Loc loc, Identifier *ident, int flags)
{
    Dsymbol *s;
    //printf("%s.ClassDeclaration::search('%s')\n", toChars(), ident->toChars());

    if (scope && !symtab)
    {   Scope *sc = scope;
        sc->mustsemantic++;
        semantic(sc);
        sc->mustsemantic--;
    }

    if (!members || !symtab)
    {
        error("is forward referenced when looking for '%s'", ident->toChars());
        //*(char*)0=0;
        return NULL;
    }

    s = ScopeDsymbol::search(loc, ident, flags);
    if (!s)
    {
        // Search bases classes in depth-first, left to right order

        for (size_t i = 0; i < baseclasses->dim; i++)
        {
            BaseClass *b = baseclasses->tdata()[i];

            if (b->base)
            {
                if (!b->base->symtab)
                    error("base %s is forward referenced", b->base->ident->toChars());
                else
                {
                    s = b->base->search(loc, ident, flags);
                    if (s == this)      // happens if s is nested in this and derives from this
                        s = NULL;
                    else if (s)
                        break;
                }
            }
        }
    }
    return s;
}

/**********************************************************
 * fd is in the vtbl[] for this class.
 * Return 1 if function is hidden (not findable through search).
 */

#if DMDV2
int isf(void *param, FuncDeclaration *fd)
{
    //printf("param = %p, fd = %p %s\n", param, fd, fd->toChars());
    return param == fd;
}

int ClassDeclaration::isFuncHidden(FuncDeclaration *fd)
{
    //printf("ClassDeclaration::isFuncHidden(class = %s, fd = %s)\n", toChars(), fd->toChars());
    Dsymbol *s = search(0, fd->ident, 4|2);
    if (!s)
    {   //printf("not found\n");
        /* Because, due to a hack, if there are multiple definitions
         * of fd->ident, NULL is returned.
         */
        return 0;
    }
    s = s->toAlias();
    OverloadSet *os = s->isOverloadSet();
    if (os)
    {
        for (size_t i = 0; i < os->a.dim; i++)
        {   Dsymbol *s2 = os->a.tdata()[i];
            FuncDeclaration *f2 = s2->isFuncDeclaration();
            if (f2 && overloadApply(f2, &isf, fd))
                return 0;
        }
        return 1;
    }
    else
    {
        FuncDeclaration *fdstart = s->isFuncDeclaration();
        //printf("%s fdstart = %p\n", s->kind(), fdstart);
        return !overloadApply(fdstart, &isf, fd);
    }
}
#endif

/****************
 * Find virtual function matching identifier and type.
 * Used to build virtual function tables for interface implementations.
 */

FuncDeclaration *ClassDeclaration::findFunc(Identifier *ident, TypeFunction *tf)
{
    //printf("ClassDeclaration::findFunc(%s, %s) %s\n", ident->toChars(), tf->toChars(), toChars());

    ClassDeclaration *cd = this;
    Dsymbols *vtbl = &cd->vtbl;
    while (1)
    {
        for (size_t i = 0; i < vtbl->dim; i++)
        {
            FuncDeclaration *fd = vtbl->tdata()[i]->isFuncDeclaration();
            if (!fd)
                continue;               // the first entry might be a ClassInfo

            //printf("\t[%d] = %s\n", i, fd->toChars());
            if (ident == fd->ident &&
                //tf->equals(fd->type)
                fd->type->covariant(tf) == 1
               )
            {   //printf("\t\tfound\n");
                return fd;
            }
            //else printf("\t\t%d\n", fd->type->covariant(tf));
        }
        if (!cd)
            break;
        vtbl = &cd->vtblFinal;
        cd = cd->baseClass;
    }

    return NULL;
}

void ClassDeclaration::interfaceSemantic(Scope *sc)
{
    InterfaceDeclaration *id = isInterfaceDeclaration();

    vtblInterfaces = new BaseClasses();
    vtblInterfaces->reserve(interfaces_dim);

    for (size_t i = 0; i < interfaces_dim; i++)
    {
        BaseClass *b = interfaces[i];

        // If this is an interface, and it derives from a COM interface,
        // then this is a COM interface too.
        if (b->base->isCOMinterface())
            com = 1;

        if (b->base->isCPPinterface() && id)
            id->cpp = 1;

        vtblInterfaces->push(b);
        b->copyBaseInterfaces(vtblInterfaces);
    }
}

/****************************************
 */

int ClassDeclaration::isCOMclass()
{
    return com;
}

int ClassDeclaration::isCOMinterface()
{
    return 0;
}

#if DMDV2
int ClassDeclaration::isCPPinterface()
{
    return 0;
}
#endif


/****************************************
 */

int ClassDeclaration::isAbstract()
{
    if (isabstract)
        return TRUE;
    for (size_t i = 1; i < vtbl.dim; i++)
    {
        FuncDeclaration *fd = vtbl.tdata()[i]->isFuncDeclaration();

        //printf("\tvtbl[%d] = %p\n", i, fd);
        if (!fd || fd->isAbstract())
        {
            isabstract |= 1;
            return TRUE;
        }
    }
    return FALSE;
}


/****************************************
 * Determine if slot 0 of the vtbl[] is reserved for something else.
 * For class objects, yes, this is where the classinfo ptr goes.
 * For COM interfaces, no.
 * For non-COM interfaces, yes, this is where the Interface ptr goes.
 */

int ClassDeclaration::vtblOffset()
{
    return 1;
}

/****************************************
 */

const char *ClassDeclaration::kind()
{
    return "class";
}

/****************************************
 */

void ClassDeclaration::addLocalClass(ClassDeclarations *aclasses)
{
    aclasses->push(this);
}

/********************************* InterfaceDeclaration ****************************/

InterfaceDeclaration::InterfaceDeclaration(Loc loc, Identifier *id, BaseClasses *baseclasses)
    : ClassDeclaration(loc, id, baseclasses)
{
    com = 0;
    cpp = 0;
    if (id == Id::IUnknown)     // IUnknown is the root of all COM interfaces
    {   com = 1;
        cpp = 1;                // IUnknown is also a C++ interface
    }
}

Dsymbol *InterfaceDeclaration::syntaxCopy(Dsymbol *s)
{
    InterfaceDeclaration *id;

    if (s)
        id = (InterfaceDeclaration *)s;
    else
        id = new InterfaceDeclaration(loc, ident, NULL);

    ClassDeclaration::syntaxCopy(id);
    return id;
}

void InterfaceDeclaration::semantic(Scope *sc)
{
    //printf("InterfaceDeclaration::semantic(%s), type = %p\n", toChars(), type);
    if (inuse)
        return;

    if (!sc)
        sc = scope;
    if (!parent && sc->parent && !sc->parent->isModule())
        parent = sc->parent;

    type = type->semantic(loc, sc);
    handle = type;

    if (!members)                       // if forward reference
    {   //printf("\tinterface '%s' is forward referenced\n", toChars());
        return;
    }
    if (symtab)                 // if already done
    {   if (!scope)
            return;
    }
    else
        symtab = new DsymbolTable();

    Scope *scx = NULL;
    if (scope)
    {   sc = scope;
        scx = scope;            // save so we don't make redundant copies
        scope = NULL;
    }

    if (sc->stc & STCdeprecated)
    {
        isdeprecated = 1;
    }

    // Expand any tuples in baseclasses[]
    for (size_t i = 0; i < baseclasses->dim; )
    {   BaseClass *b = baseclasses->tdata()[0];
        b->type = b->type->semantic(loc, sc);
        Type *tb = b->type->toBasetype();

        if (tb->ty == Ttuple)
        {   TypeTuple *tup = (TypeTuple *)tb;
            enum PROT protection = b->protection;
            baseclasses->remove(i);
            size_t dim = Parameter::dim(tup->arguments);
            for (size_t j = 0; j < dim; j++)
            {   Parameter *arg = Parameter::getNth(tup->arguments, j);
                b = new BaseClass(arg->type, protection);
                baseclasses->insert(i + j, b);
            }
        }
        else
            i++;
    }

    if (!baseclasses->dim && sc->linkage == LINKcpp)
        cpp = 1;

    // Check for errors, handle forward references
    for (size_t i = 0; i < baseclasses->dim; )
    {   TypeClass *tc;
        BaseClass *b;
        Type *tb;

        b = baseclasses->tdata()[i];
        b->type = b->type->semantic(loc, sc);
        tb = b->type->toBasetype();
        if (tb->ty == Tclass)
            tc = (TypeClass *)tb;
        else
            tc = NULL;
        if (!tc || !tc->sym->isInterfaceDeclaration())
        {
            error("base type must be interface, not %s", b->type->toChars());
            baseclasses->remove(i);
            continue;
        }
        else
        {
            // Check for duplicate interfaces
            for (size_t j = 0; j < i; j++)
            {
                BaseClass *b2 = baseclasses->tdata()[j];
                if (b2->base == tc->sym)
                    error("inherits from duplicate interface %s", b2->base->toChars());
            }

            b->base = tc->sym;
            if (b->base == this || isBaseOf2(b->base))
            {
                error("circular inheritance of interface");
                baseclasses->remove(i);
                continue;
            }
            if (!b->base->symtab)
            {   // Try to resolve forward reference
                if (sc->mustsemantic && b->base->scope)
                    b->base->semantic(NULL);
            }
            if (!b->base->symtab || b->base->scope || b->base->inuse)
            {
                //error("forward reference of base class %s", baseClass->toChars());
                // Forward reference of base, try again later
                //printf("\ttry later, forward reference of base %s\n", b->base->toChars());
                scope = scx ? scx : new Scope(*sc);
                scope->setNoFree();
                scope->module->addDeferredSemantic(this);
                return;
            }
        }
#if 0
        // Inherit const/invariant from base class
        storage_class |= b->base->storage_class & STC_TYPECTOR;
#endif
        i++;
    }

    interfaces_dim = baseclasses->dim;
    interfaces = baseclasses->tdata();

    interfaceSemantic(sc);

    if (vtblOffset())
        vtbl.push(this);                // leave room at vtbl[0] for classinfo

    // Cat together the vtbl[]'s from base interfaces
    for (size_t i = 0; i < interfaces_dim; i++)
    {   BaseClass *b = interfaces[i];

        // Skip if b has already appeared
        for (int k = 0; k < i; k++)
        {
            if (b == interfaces[k])
                goto Lcontinue;
        }

        // Copy vtbl[] from base class
        if (b->base->vtblOffset())
        {   int d = b->base->vtbl.dim;
            if (d > 1)
            {
                vtbl.reserve(d - 1);
                for (int j = 1; j < d; j++)
                    vtbl.push(b->base->vtbl.tdata()[j]);
            }
        }
        else
        {
            vtbl.append(&b->base->vtbl);
        }

      Lcontinue:
        ;
    }

    protection = sc->protection;
    storage_class |= sc->stc & STC_TYPECTOR;

    for (size_t i = 0; i < members->dim; i++)
    {
        Dsymbol *s = members->tdata()[i];
        s->addMember(sc, this, 1);
    }

    sc = sc->push(this);
    sc->stc &= ~(STCfinal | STCauto | STCscope | STCstatic |
                 STCabstract | STCdeprecated | STC_TYPECTOR | STCtls | STCgshared);
    sc->stc |= storage_class & STC_TYPECTOR;
    sc->parent = this;
    if (isCOMinterface())
        sc->linkage = LINKwindows;
    else if (isCPPinterface())
        sc->linkage = LINKcpp;
    sc->structalign = 8;
    structalign = sc->structalign;
    sc->offset = PTRSIZE * 2;
    inuse++;
    for (size_t i = 0; i < members->dim; i++)
    {
        Dsymbol *s = members->tdata()[i];
        s->semantic(sc);
    }
    inuse--;
    //members->print();
    sc->pop();
    //printf("-InterfaceDeclaration::semantic(%s), type = %p\n", toChars(), type);
}


/*******************************************
 * Determine if 'this' is a base class of cd.
 * (Actually, if it is an interface supported by cd)
 * Output:
 *      *poffset        offset to start of class
 *                      OFFSET_RUNTIME  must determine offset at runtime
 * Returns:
 *      0       not a base
 *      1       is a base
 */

int InterfaceDeclaration::isBaseOf(ClassDeclaration *cd, int *poffset)
{
    unsigned j;

    //printf("%s.InterfaceDeclaration::isBaseOf(cd = '%s')\n", toChars(), cd->toChars());
    assert(!baseClass);
    for (j = 0; j < cd->interfaces_dim; j++)
    {
        BaseClass *b = cd->interfaces[j];

        //printf("\tbase %s\n", b->base->toChars());
        if (this == b->base)
        {
            //printf("\tfound at offset %d\n", b->offset);
            if (poffset)
            {   *poffset = b->offset;
                if (j && cd->isInterfaceDeclaration())
                    *poffset = OFFSET_RUNTIME;
            }
            return 1;
        }
        if (isBaseOf(b, poffset))
        {   if (j && poffset && cd->isInterfaceDeclaration())
                *poffset = OFFSET_RUNTIME;
            return 1;
        }
    }

    if (cd->baseClass && isBaseOf(cd->baseClass, poffset))
        return 1;

    if (poffset)
        *poffset = 0;
    return 0;
}


int InterfaceDeclaration::isBaseOf(BaseClass *bc, int *poffset)
{
    //printf("%s.InterfaceDeclaration::isBaseOf(bc = '%s')\n", toChars(), bc->base->toChars());
    for (unsigned j = 0; j < bc->baseInterfaces_dim; j++)
    {
        BaseClass *b = &bc->baseInterfaces[j];

        if (this == b->base)
        {
            if (poffset)
            {   *poffset = b->offset;
                if (j && bc->base->isInterfaceDeclaration())
                    *poffset = OFFSET_RUNTIME;
            }
            return 1;
        }
        if (isBaseOf(b, poffset))
        {   if (j && poffset && bc->base->isInterfaceDeclaration())
                *poffset = OFFSET_RUNTIME;
            return 1;
        }
    }
    if (poffset)
        *poffset = 0;
    return 0;
}

/*********************************************
 * Determine if 'this' has clomplete base class information.
 * This is used to detect forward references in covariant overloads.
 */

int InterfaceDeclaration::isBaseInfoComplete()
{
    assert(!baseClass);
    for (size_t i = 0; i < baseclasses->dim; i++)
    {   BaseClass *b = baseclasses->tdata()[i];
        if (!b->base || !b->base->isBaseInfoComplete ())
            return 0;
    }
    return 1;
}

/****************************************
 * Determine if slot 0 of the vtbl[] is reserved for something else.
 * For class objects, yes, this is where the ClassInfo ptr goes.
 * For COM interfaces, no.
 * For non-COM interfaces, yes, this is where the Interface ptr goes.
 */

int InterfaceDeclaration::vtblOffset()
{
    if (isCOMinterface() || isCPPinterface())
        return 0;
    return 1;
}

int InterfaceDeclaration::isCOMinterface()
{
    return com;
}

#if DMDV2
int InterfaceDeclaration::isCPPinterface()
{
    return cpp;
}
#endif

/*******************************************
 */

const char *InterfaceDeclaration::kind()
{
    return "interface";
}


/******************************** BaseClass *****************************/

BaseClass::BaseClass()
{
    memset(this, 0, sizeof(BaseClass));
}

BaseClass::BaseClass(Type *type, enum PROT protection)
{
    //printf("BaseClass(this = %p, '%s')\n", this, type->toChars());
    this->type = type;
    this->protection = protection;
    base = NULL;
    offset = 0;

    baseInterfaces_dim = 0;
    baseInterfaces = NULL;
}

/****************************************
 * Fill in vtbl[] for base class based on member functions of class cd.
 * Input:
 *      vtbl            if !=NULL, fill it in
 *      newinstance     !=0 means all entries must be filled in by members
 *                      of cd, not members of any base classes of cd.
 * Returns:
 *      !=0 if any entries were filled in by members of cd (not exclusively
 *      by base classes)
 */

int BaseClass::fillVtbl(ClassDeclaration *cd, FuncDeclarations *vtbl, int newinstance)
{
    ClassDeclaration *id = base;
    int result = 0;

    //printf("BaseClass::fillVtbl(this='%s', cd='%s')\n", base->toChars(), cd->toChars());
    if (vtbl)
        vtbl->setDim(base->vtbl.dim);

    // first entry is ClassInfo reference
    for (size_t j = base->vtblOffset(); j < base->vtbl.dim; j++)
    {
        FuncDeclaration *ifd = base->vtbl.tdata()[j]->isFuncDeclaration();
        FuncDeclaration *fd;
        TypeFunction *tf;

        //printf("        vtbl[%d] is '%s'\n", j, ifd ? ifd->toChars() : "null");

        assert(ifd);
        // Find corresponding function in this class
        tf = (ifd->type->ty == Tfunction) ? (TypeFunction *)(ifd->type) : NULL;
        fd = cd->findFunc(ifd->ident, tf);
        if (fd && !fd->isAbstract())
        {
            //printf("            found\n");
            // Check that calling conventions match
            if (fd->linkage != ifd->linkage)
                fd->error("linkage doesn't match interface function");

            // Check that it is current
            if (newinstance &&
                fd->toParent() != cd &&
                ifd->toParent() == base)
                cd->error("interface function %s.%s is not implemented",
                    id->toChars(), ifd->ident->toChars());

            if (fd->toParent() == cd)
                result = 1;
        }
        else
        {
            //printf("            not found\n");
            // BUG: should mark this class as abstract?
            if (!cd->isAbstract())
                cd->error("interface function %s.%s isn't implemented",
                    id->toChars(), ifd->ident->toChars());
            fd = NULL;
        }
        if (vtbl)
            vtbl->tdata()[j] = fd;
    }

    return result;
}

void BaseClass::copyBaseInterfaces(BaseClasses *vtblInterfaces)
{
    //printf("+copyBaseInterfaces(), %s\n", base->toChars());
//    if (baseInterfaces_dim)
//      return;

    baseInterfaces_dim = base->interfaces_dim;
    baseInterfaces = (BaseClass *)mem.calloc(baseInterfaces_dim, sizeof(BaseClass));

    //printf("%s.copyBaseInterfaces()\n", base->toChars());
    for (int i = 0; i < baseInterfaces_dim; i++)
    {
        BaseClass *b = &baseInterfaces[i];
        BaseClass *b2 = base->interfaces[i];

        assert(b2->vtbl.dim == 0);      // should not be filled yet
        memcpy(b, b2, sizeof(BaseClass));

        if (i)                          // single inheritance is i==0
            vtblInterfaces->push(b);    // only need for M.I.
        b->copyBaseInterfaces(vtblInterfaces);
    }
    //printf("-copyBaseInterfaces\n");
}
