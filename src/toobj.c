
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/toobj.c
 */

#include <stdio.h>
#include <stddef.h>
#include <time.h>
#include <assert.h>

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
#include "nspace.h"
#include "hdrgen.h"

#include "rmem.h"
#include "target.h"
#include "cc.h"
#include "global.h"
#include "oper.h"
#include "code.h"
#include "type.h"
#include "dt.h"
#include "cgcv.h"
#include "outbuf.h"
#include "irstate.h"

extern bool obj_includelib(const char *name);
void obj_startaddress(Symbol *s);
void obj_lzext(Symbol *s1,Symbol *s2);

void TypeInfo_toDt(dt_t **pdt, TypeInfoDeclaration *d);
dt_t *Initializer_toDt(Initializer *init);
dt_t **Type_toDt(Type *t, dt_t **pdt);
void ClassDeclaration_toDt(ClassDeclaration *cd, dt_t **pdt);
void StructDeclaration_toDt(StructDeclaration *sd, dt_t **pdt);
Symbol *toSymbol(Dsymbol *s);
dt_t **Expression_toDt(Expression *e, dt_t **pdt);
void FuncDeclaration_toObjFile(FuncDeclaration *fd, bool multiobj);
Symbol *toThunkSymbol(FuncDeclaration *fd, int offset);
Symbol *toVtblSymbol(ClassDeclaration *cd);
Symbol *toInitializer(AggregateDeclaration *ad);
Symbol *toInitializer(EnumDeclaration *ed);

void toDebug(EnumDeclaration *ed);
void toDebug(StructDeclaration *sd);
void toDebug(ClassDeclaration *cd);

/* ================================================================== */

// Put out instance of ModuleInfo for this Module

void genModuleInfo(Module *m)
{
    //printf("Module::genmoduleinfo() %s\n", m->toChars());

    if (!Module::moduleinfo)
    {
        ObjectNotFound(Id::ModuleInfo);
    }

    Symbol *msym = toSymbol(m);

    //////////////////////////////////////////////

    m->csym->Sclass = SCglobal;
    m->csym->Sfl = FLdata;

    dt_t *dt = NULL;
    ClassDeclarations aclasses;

    //printf("members->dim = %d\n", members->dim);
    for (size_t i = 0; i < m->members->dim; i++)
    {
        Dsymbol *member = (*m->members)[i];

        //printf("\tmember '%s'\n", member->toChars());
        member->addLocalClass(&aclasses);
    }

    // importedModules[]
    size_t aimports_dim = m->aimports.dim;
    for (size_t i = 0; i < m->aimports.dim; i++)
    {
        Module *mod = m->aimports[i];
        if (!mod->needmoduleinfo)
            aimports_dim--;
    }

    FuncDeclaration *sgetmembers = m->findGetMembers();

    // These must match the values in druntime/src/object_.d
    #define MIstandalone      0x4
    #define MItlsctor         0x8
    #define MItlsdtor         0x10
    #define MIctor            0x20
    #define MIdtor            0x40
    #define MIxgetMembers     0x80
    #define MIictor           0x100
    #define MIunitTest        0x200
    #define MIimportedModules 0x400
    #define MIlocalClasses    0x800
    #define MIname            0x1000

    unsigned flags = 0;
    if (!m->needmoduleinfo)
        flags |= MIstandalone;
    if (m->sctor)
        flags |= MItlsctor;
    if (m->sdtor)
        flags |= MItlsdtor;
    if (m->ssharedctor)
        flags |= MIctor;
    if (m->sshareddtor)
        flags |= MIdtor;
    if (sgetmembers)
        flags |= MIxgetMembers;
    if (m->sictor)
        flags |= MIictor;
    if (m->stest)
        flags |= MIunitTest;
    if (aimports_dim)
        flags |= MIimportedModules;
    if (aclasses.dim)
        flags |= MIlocalClasses;
    flags |= MIname;

    dtdword(&dt, flags);        // _flags
    dtdword(&dt, 0);            // _index

    if (flags & MItlsctor)
        dtxoff(&dt, m->sctor, 0, TYnptr);
    if (flags & MItlsdtor)
        dtxoff(&dt, m->sdtor, 0, TYnptr);
    if (flags & MIctor)
        dtxoff(&dt, m->ssharedctor, 0, TYnptr);
    if (flags & MIdtor)
        dtxoff(&dt, m->sshareddtor, 0, TYnptr);
    if (flags & MIxgetMembers)
        dtxoff(&dt, toSymbol(sgetmembers), 0, TYnptr);
    if (flags & MIictor)
        dtxoff(&dt, m->sictor, 0, TYnptr);
    if (flags & MIunitTest)
        dtxoff(&dt, m->stest, 0, TYnptr);
    if (flags & MIimportedModules)
    {
        dtsize_t(&dt, aimports_dim);
        for (size_t i = 0; i < m->aimports.dim; i++)
        {
            Module *mod = m->aimports[i];

            if (!mod->needmoduleinfo)
                continue;

            Symbol *s = toSymbol(mod);

            /* Weak references don't pull objects in from the library,
             * they resolve to 0 if not pulled in by something else.
             * Don't pull in a module just because it was imported.
             */
            s->Sflags |= SFLweak;
            dtxoff(&dt, s, 0, TYnptr);
        }
    }
    if (flags & MIlocalClasses)
    {
        dtsize_t(&dt, aclasses.dim);
        for (size_t i = 0; i < aclasses.dim; i++)
        {
            ClassDeclaration *cd = aclasses[i];
            dtxoff(&dt, toSymbol(cd), 0, TYnptr);
        }
    }
    if (flags & MIname)
    {
        // Put out module name as a 0-terminated string, to save bytes
        m->nameoffset = dt_size(dt);
        const char *name = m->toPrettyChars();
        m->namelen = strlen(name);
        dtnbytes(&dt, m->namelen + 1, name);
        //printf("nameoffset = x%x\n", nameoffset);
    }

    m->csym->Sdt = dt;
    out_readonly(m->csym);
    outdata(m->csym);

    //////////////////////////////////////////////

    objmod->moduleinfo(msym);
}

/* ================================================================== */

void toObjFile(Dsymbol *ds, bool multiobj)
{
    class ToObjFile : public Visitor
    {
    public:
        bool multiobj;

        ToObjFile(bool multiobj)
            : multiobj(multiobj)
        {
        }

        void visitNoMultiObj(Dsymbol *ds)
        {
            bool multiobjsave = multiobj;
            multiobj = false;
            ds->accept(this);
            multiobj = multiobjsave;
        }

        void visit(Dsymbol *ds)
        {
            //printf("Dsymbol::toObjFile('%s')\n", ds->toChars());
            // ignore
        }

        void visit(FuncDeclaration *fd)
        {
            // in glue.c
            FuncDeclaration_toObjFile(fd, multiobj);
        }

        void visit(ClassDeclaration *cd)
        {
            //printf("ClassDeclaration::toObjFile('%s')\n", toChars());

            if (cd->type->ty == Terror)
            {
                cd->error("had semantic errors when compiling");
                return;
            }

            if (!cd->members)
                return;

            if (multiobj && !cd->hasStaticCtorOrDtor())
            {
                obj_append(cd);
                return;
            }

            if (global.params.symdebug)
                toDebug(cd);

            assert(!cd->scope);     // semantic() should have been run to completion

            enum_SC scclass = SCglobal;
            if (cd->isInstantiated())
                scclass = SCcomdat;

            // Put out the members
            for (size_t i = 0; i < cd->members->dim; i++)
            {
                Dsymbol *member = (*cd->members)[i];
                /* There might be static ctors in the members, and they cannot
                 * be put in separate obj files.
                 */
                member->accept(this);
            }

            // Generate C symbols
            toSymbol(cd);
            toVtblSymbol(cd);
            Symbol *sinit = toInitializer(cd);

            //////////////////////////////////////////////

            // Generate static initializer
            sinit->Sclass = scclass;
            sinit->Sfl = FLdata;
            ClassDeclaration_toDt(cd, &sinit->Sdt);
            out_readonly(sinit);
            outdata(sinit);

            //////////////////////////////////////////////

            // Put out the TypeInfo
            cd->type->genTypeInfo(NULL);
            //toObjFile(cd->type->vtinfo, multiobj);

            //////////////////////////////////////////////

            // Put out the ClassInfo
            cd->csym->Sclass = scclass;
            cd->csym->Sfl = FLdata;

            /* The layout is:
               {
                    void **vptr;
                    monitor_t monitor;
                    byte[] initializer;         // static initialization data
                    char[] name;                // class name
                    void *[] vtbl;
                    Interface[] interfaces;
                    ClassInfo *base;            // base class
                    void *destructor;
                    void *invariant;            // class invariant
                    ClassFlags flags;
                    void *deallocator;
                    OffsetTypeInfo[] offTi;
                    void *defaultConstructor;
                    //const(MemberInfo[]) function(string) xgetMembers;   // module getMembers() function
                    void *xgetRTInfo;
                    //TypeInfo typeinfo;
               }
             */
            dt_t *dt = NULL;
            unsigned classinfo_size = global.params.isLP64 ? CLASSINFO_SIZE_64 : CLASSINFO_SIZE;    // must be ClassInfo.size
            unsigned offset = classinfo_size;
            if (Type::typeinfoclass)
            {
                if (Type::typeinfoclass->structsize != classinfo_size)
                {
        #ifdef DEBUG
                    printf("CLASSINFO_SIZE = x%x, Type::typeinfoclass->structsize = x%x\n", offset, Type::typeinfoclass->structsize);
        #endif
                    cd->error("mismatch between dmd and object.d or object.di found. Check installation and import paths with -v compiler switch.");
                    fatal();
                }
            }

            if (Type::typeinfoclass)
                dtxoff(&dt, toVtblSymbol(Type::typeinfoclass), 0, TYnptr); // vtbl for ClassInfo
            else
                dtsize_t(&dt, 0);                // BUG: should be an assert()
            dtsize_t(&dt, 0);                    // monitor

            // initializer[]
            assert(cd->structsize >= 8 || (cd->cpp && cd->structsize >= 4));
            dtsize_t(&dt, cd->structsize);           // size
            dtxoff(&dt, sinit, 0, TYnptr);      // initializer

            // name[]
            const char *name = cd->ident->toChars();
            size_t namelen = strlen(name);
            if (!(namelen > 9 && memcmp(name, "TypeInfo_", 9) == 0))
            {
                name = cd->toPrettyChars();
                namelen = strlen(name);
            }
            dtsize_t(&dt, namelen);
            dtabytes(&dt, TYnptr, 0, namelen + 1, name);

            // vtbl[]
            dtsize_t(&dt, cd->vtbl.dim);
            dtxoff(&dt, cd->vtblsym, 0, TYnptr);

            // interfaces[]
            dtsize_t(&dt, cd->vtblInterfaces->dim);
            if (cd->vtblInterfaces->dim)
                dtxoff(&dt, cd->csym, offset, TYnptr);      // (*)
            else
                dtsize_t(&dt, 0);

            // base
            if (cd->baseClass)
                dtxoff(&dt, toSymbol(cd->baseClass), 0, TYnptr);
            else
                dtsize_t(&dt, 0);

            // destructor
            if (cd->dtor)
                dtxoff(&dt, toSymbol(cd->dtor), 0, TYnptr);
            else
                dtsize_t(&dt, 0);

            // invariant
            if (cd->inv)
                dtxoff(&dt, toSymbol(cd->inv), 0, TYnptr);
            else
                dtsize_t(&dt, 0);

            // flags
            ClassFlags::Type flags = ClassFlags::hasOffTi;
            if (cd->isCOMclass()) flags |= ClassFlags::isCOMclass;
            if (cd->isCPPclass()) flags |= ClassFlags::isCPPclass;
            flags |= ClassFlags::hasGetMembers;
            flags |= ClassFlags::hasTypeInfo;
            if (cd->ctor)
                flags |= ClassFlags::hasCtor;
            for (ClassDeclaration *pc = cd; pc; pc = pc->baseClass)
            {
                if (pc->dtor)
                {
                    flags |= ClassFlags::hasDtor;
                    break;
                }
            }
            if (cd->isabstract)
                flags |= ClassFlags::isAbstract;
            for (ClassDeclaration *pc = cd; pc; pc = pc->baseClass)
            {
                if (pc->members)
                {
                    for (size_t i = 0; i < pc->members->dim; i++)
                    {
                        Dsymbol *sm = (*pc->members)[i];
                        //printf("sm = %s %s\n", sm->kind(), sm->toChars());
                        if (sm->hasPointers())
                            goto L2;
                    }
                }
            }
            flags |= ClassFlags::noPointers;
          L2:
            dtsize_t(&dt, flags);


            // deallocator
            if (cd->aggDelete)
                dtxoff(&dt, toSymbol(cd->aggDelete), 0, TYnptr);
            else
                dtsize_t(&dt, 0);

            // offTi[]
            dtsize_t(&dt, 0);
            dtsize_t(&dt, 0);            // null for now, fix later

            // defaultConstructor
            if (cd->defaultCtor)
                dtxoff(&dt, toSymbol(cd->defaultCtor), 0, TYnptr);
            else
                dtsize_t(&dt, 0);

            // xgetRTInfo
            if (cd->getRTInfo)
                Expression_toDt(cd->getRTInfo, &dt);
            else if (flags & ClassFlags::noPointers)
                dtsize_t(&dt, 0);
            else
                dtsize_t(&dt, 1);

            //dtxoff(&dt, toSymbol(type->vtinfo), 0, TYnptr); // typeinfo

            //////////////////////////////////////////////

            // Put out (*vtblInterfaces)[]. Must immediately follow csym, because
            // of the fixup (*)

            offset += cd->vtblInterfaces->dim * (4 * Target::ptrsize);
            for (size_t i = 0; i < cd->vtblInterfaces->dim; i++)
            {
                BaseClass *b = (*cd->vtblInterfaces)[i];
                ClassDeclaration *id = b->base;

                /* The layout is:
                 *  struct Interface
                 *  {
                 *      ClassInfo *interface;
                 *      void *[] vtbl;
                 *      size_t offset;
                 *  }
                 */

                // Fill in vtbl[]
                b->fillVtbl(cd, &b->vtbl, 1);

                dtxoff(&dt, toSymbol(id), 0, TYnptr);         // ClassInfo

                // vtbl[]
                dtsize_t(&dt, id->vtbl.dim);
                dtxoff(&dt, cd->csym, offset, TYnptr);

                dtsize_t(&dt, b->offset);                        // this offset

                offset += id->vtbl.dim * Target::ptrsize;
            }

            // Put out the (*vtblInterfaces)[].vtbl[]
            // This must be mirrored with ClassDeclaration::baseVtblOffset()
            //printf("putting out %d interface vtbl[]s for '%s'\n", vtblInterfaces->dim, toChars());
            for (size_t i = 0; i < cd->vtblInterfaces->dim; i++)
            {
                BaseClass *b = (*cd->vtblInterfaces)[i];
                ClassDeclaration *id = b->base;

                //printf("    interface[%d] is '%s'\n", i, id->toChars());
                size_t j = 0;
                if (id->vtblOffset())
                {
                    // First entry is ClassInfo reference
                    //dtxoff(&dt, toSymbol(id), 0, TYnptr);

                    // First entry is struct Interface reference
                    dtxoff(&dt, cd->csym, classinfo_size + i * (4 * Target::ptrsize), TYnptr);
                    j = 1;
                }
                assert(id->vtbl.dim == b->vtbl.dim);
                for (; j < id->vtbl.dim; j++)
                {
                    assert(j < b->vtbl.dim);
        #if 0
                    RootObject *o = b->vtbl[j];
                    if (o)
                    {
                        printf("o = %p\n", o);
                        assert(o->dyncast() == DYNCAST_DSYMBOL);
                        Dsymbol *s = (Dsymbol *)o;
                        printf("s->kind() = '%s'\n", s->kind());
                    }
        #endif
                    FuncDeclaration *fd = b->vtbl[j];
                    if (fd)
                        dtxoff(&dt, toThunkSymbol(fd, b->offset), 0, TYnptr);
                    else
                        dtsize_t(&dt, 0);
                }
            }

            // Put out the overriding interface vtbl[]s.
            // This must be mirrored with ClassDeclaration::baseVtblOffset()
            //printf("putting out overriding interface vtbl[]s for '%s' at offset x%x\n", toChars(), offset);
            ClassDeclaration *pc;
            for (pc = cd->baseClass; pc; pc = pc->baseClass)
            {
                for (size_t k = 0; k < pc->vtblInterfaces->dim; k++)
                {
                    BaseClass *bs = (*pc->vtblInterfaces)[k];
                    FuncDeclarations bvtbl;
                    if (bs->fillVtbl(cd, &bvtbl, 0))
                    {
                        //printf("\toverriding vtbl[] for %s\n", bs->base->toChars());
                        ClassDeclaration *id = bs->base;

                        size_t j = 0;
                        if (id->vtblOffset())
                        {
                            // First entry is ClassInfo reference
                            //dtxoff(&dt, toSymbol(id), 0, TYnptr);

                            // First entry is struct Interface reference
                            dtxoff(&dt, toSymbol(pc), classinfo_size + k * (4 * Target::ptrsize), TYnptr);
                            j = 1;
                        }

                        for (; j < id->vtbl.dim; j++)
                        {
                            assert(j < bvtbl.dim);
                            FuncDeclaration *fd = bvtbl[j];
                            if (fd)
                                dtxoff(&dt, toThunkSymbol(fd, bs->offset), 0, TYnptr);
                            else
                                dtsize_t(&dt, 0);
                        }
                    }
                }
            }

            cd->csym->Sdt = dt;
            // ClassInfo cannot be const data, because we use the monitor on it
            outdata(cd->csym);
            if (cd->isExport())
                objmod->export_symbol(cd->csym, 0);

            //////////////////////////////////////////////

            // Put out the vtbl[]
            //printf("putting out %s.vtbl[]\n", toChars());
            dt = NULL;
            if (cd->vtblOffset())
                dtxoff(&dt, cd->csym, 0, TYnptr);           // first entry is ClassInfo reference
            for (size_t i = cd->vtblOffset(); i < cd->vtbl.dim; i++)
            {
                FuncDeclaration *fd = cd->vtbl[i]->isFuncDeclaration();

                //printf("\tvtbl[%d] = %p\n", i, fd);
                if (fd && (fd->fbody || !cd->isAbstract()))
                {
                    // Ensure function has a return value (Bugzilla 4869)
                    fd->functionSemantic();

                    Symbol *s = toSymbol(fd);

                    if (cd->isFuncHidden(fd))
                    {
                        /* fd is hidden from the view of this class.
                         * If fd overlaps with any function in the vtbl[], then
                         * issue 'hidden' error.
                         */
                        for (size_t j = 1; j < cd->vtbl.dim; j++)
                        {
                            if (j == i)
                                continue;
                            FuncDeclaration *fd2 = cd->vtbl[j]->isFuncDeclaration();
                            if (!fd2->ident->equals(fd->ident))
                                continue;
                            if (fd->leastAsSpecialized(fd2) || fd2->leastAsSpecialized(fd))
                            {
                                TypeFunction *tf = (TypeFunction *)fd->type;
                                if (tf->ty == Tfunction)
                                    cd->deprecation("use of %s%s hidden by %s is deprecated; use 'alias %s = %s.%s;' to introduce base class overload set",
                                        fd->toPrettyChars(),
                                        parametersTypeToChars(tf->parameters, tf->varargs),
                                        cd->toChars(),

                                        fd->toChars(),
                                        fd->parent->toChars(),
                                        fd->toChars());
                                else
                                    cd->deprecation("use of %s hidden by %s is deprecated", fd->toPrettyChars(), cd->toChars());
                                s = rtlsym[RTLSYM_DHIDDENFUNC];
                                break;
                            }
                        }
                    }

                    dtxoff(&dt, s, 0, TYnptr);
                }
                else
                    dtsize_t(&dt, 0);
            }
            cd->vtblsym->Sdt = dt;
            cd->vtblsym->Sclass = scclass;
            cd->vtblsym->Sfl = FLdata;
            out_readonly(cd->vtblsym);
            outdata(cd->vtblsym);
            if (cd->isExport())
                objmod->export_symbol(cd->vtblsym,0);
        }

        void visit(InterfaceDeclaration *id)
        {
            //printf("InterfaceDeclaration::toObjFile('%s')\n", id->toChars());

            if (id->type->ty == Terror)
            {
                id->error("had semantic errors when compiling");
                return;
            }

            if (!id->members)
                return;

            if (global.params.symdebug)
                toDebug(id);

            enum_SC scclass = SCglobal;
            if (id->isInstantiated())
                scclass = SCcomdat;

            // Put out the members
            for (size_t i = 0; i < id->members->dim; i++)
            {
                Dsymbol *member = (*id->members)[i];
                visitNoMultiObj(member);
            }

            // Generate C symbols
            toSymbol(id);

            //////////////////////////////////////////////

            // Put out the TypeInfo
            id->type->genTypeInfo(NULL);
            id->type->vtinfo->accept(this);

            //////////////////////////////////////////////

            // Put out the ClassInfo
            id->csym->Sclass = scclass;
            id->csym->Sfl = FLdata;

            /* The layout is:
               {
                    void **vptr;
                    monitor_t monitor;
                    byte[] initializer;         // static initialization data
                    char[] name;                // class name
                    void *[] vtbl;
                    Interface[] interfaces;
                    Object *base;               // base class
                    void *destructor;
                    void *invariant;            // class invariant
                    uint flags;
                    void *deallocator;
                    OffsetTypeInfo[] offTi;
                    void *defaultConstructor;
                    //const(MemberInfo[]) function(string) xgetMembers;   // module getMembers() function
                    void* xgetRTInfo;
                    //TypeInfo typeinfo;
               }
             */
            dt_t *dt = NULL;

            if (Type::typeinfoclass)
                dtxoff(&dt, toVtblSymbol(Type::typeinfoclass), 0, TYnptr); // vtbl for ClassInfo
            else
                dtsize_t(&dt, 0);                // BUG: should be an assert()
            dtsize_t(&dt, 0);                    // monitor

            // initializer[]
            dtsize_t(&dt, 0);                    // size
            dtsize_t(&dt, 0);                    // initializer

            // name[]
            const char *name = id->toPrettyChars();
            size_t namelen = strlen(name);
            dtsize_t(&dt, namelen);
            dtabytes(&dt, TYnptr, 0, namelen + 1, name);

            // vtbl[]
            dtsize_t(&dt, 0);
            dtsize_t(&dt, 0);

            // (*vtblInterfaces)[]
            unsigned offset;
            dtsize_t(&dt, id->vtblInterfaces->dim);
            if (id->vtblInterfaces->dim)
            {
                offset = global.params.isLP64 ? CLASSINFO_SIZE_64 : CLASSINFO_SIZE;    // must be ClassInfo.size
                if (Type::typeinfoclass)
                {
                    if (Type::typeinfoclass->structsize != offset)
                    {
                        id->error("mismatch between dmd and object.d or object.di found. Check installation and import paths with -v compiler switch.");
                        fatal();
                    }
                }
                dtxoff(&dt, id->csym, offset, TYnptr);      // (*)
            }
            else
            {
                offset = 0;
                dtsize_t(&dt, 0);
            }

            // base
            assert(!id->baseClass);
            dtsize_t(&dt, 0);

            // dtor
            dtsize_t(&dt, 0);

            // invariant
            dtsize_t(&dt, 0);

            // flags
            ClassFlags::Type flags = ClassFlags::hasOffTi | ClassFlags::hasTypeInfo;
            if (id->isCOMinterface()) flags |= ClassFlags::isCOMclass;
            dtsize_t(&dt, flags);

            // deallocator
            dtsize_t(&dt, 0);

            // offTi[]
            dtsize_t(&dt, 0);
            dtsize_t(&dt, 0);            // null for now, fix later

            // defaultConstructor
            dtsize_t(&dt, 0);

            // xgetMembers
            //dtsize_t(&dt, 0);

            // xgetRTInfo
            // xgetRTInfo
            if (id->getRTInfo)
                Expression_toDt(id->getRTInfo, &dt);
            else
                dtsize_t(&dt, 0);       // no pointers

            //dtxoff(&dt, toSymbol(id->type->vtinfo), 0, TYnptr); // typeinfo

            //////////////////////////////////////////////

            // Put out (*vtblInterfaces)[]. Must immediately follow csym, because
            // of the fixup (*)

            offset += id->vtblInterfaces->dim * (4 * Target::ptrsize);
            for (size_t i = 0; i < id->vtblInterfaces->dim; i++)
            {
                BaseClass *b = (*id->vtblInterfaces)[i];
                ClassDeclaration *base = b->base;

                // ClassInfo
                dtxoff(&dt, toSymbol(base), 0, TYnptr);

                // vtbl[]
                dtsize_t(&dt, 0);
                dtsize_t(&dt, 0);

                // this offset
                dtsize_t(&dt, b->offset);
            }

            id->csym->Sdt = dt;
            out_readonly(id->csym);
            outdata(id->csym);
            if (id->isExport())
                objmod->export_symbol(id->csym, 0);
        }

        void visit(StructDeclaration *sd)
        {
            //printf("StructDeclaration::toObjFile('%s')\n", sd->toChars());

            if (sd->type->ty == Terror)
            {
                sd->error("had semantic errors when compiling");
                return;
            }

            if (multiobj && !sd->hasStaticCtorOrDtor())
            {
                obj_append(sd);
                return;
            }

            // Anonymous structs/unions only exist as part of others,
            // do not output forward referenced structs's
            if (!sd->isAnonymous() && sd->members)
            {
                if (global.params.symdebug)
                    toDebug(sd);

                sd->type->genTypeInfo(NULL);

                // Generate static initializer
                toInitializer(sd);
                if (sd->isInstantiated())
                {
                    sd->sinit->Sclass = SCcomdat;
                }
                else
                {
                    sd->sinit->Sclass = SCglobal;
                }

                sd->sinit->Sfl = FLdata;
                StructDeclaration_toDt(sd, &sd->sinit->Sdt);
                dt_optimize(sd->sinit->Sdt);
                out_readonly(sd->sinit);    // put in read-only segment
                outdata(sd->sinit);

                // Put out the members
                for (size_t i = 0; i < sd->members->dim; i++)
                {
                    Dsymbol *member = (*sd->members)[i];
                    /* There might be static ctors in the members, and they cannot
                     * be put in separate obj files.
                     */
                    member->accept(this);
                }

                if (sd->xeq && sd->xeq != StructDeclaration::xerreq)
                    sd->xeq->accept(this);
                if (sd->xcmp && sd->xcmp != StructDeclaration::xerrcmp)
                    sd->xcmp->accept(this);
                if (sd->xhash)
                    sd->xhash->accept(this);
            }
        }

        void visit(VarDeclaration *vd)
        {

            //printf("VarDeclaration::toObjFile(%p '%s' type=%s) protection %d\n", vd, vd->toChars(), vd->type->toChars(), vd->protection);
            //printf("\talign = %d\n", vd->alignment);

            if (vd->type->ty == Terror)
            {
                vd->error("had semantic errors when compiling");
                return;
            }

            if (vd->aliassym)
            {
                visitNoMultiObj(vd->toAlias());
                return;
            }

            // Do not store variables we cannot take the address of
            if (!vd->canTakeAddressOf())
            {
                return;
            }

            if (!vd->isDataseg() || vd->storage_class & STCextern)
                return;

            Symbol *s = toSymbol(vd);
            unsigned sz = vd->type->size();

            Dsymbol *parent = vd->toParent();
            s->Sclass = SCglobal;

            do
            {
                /* Global template data members need to be in comdat's
                 * in case multiple .obj files instantiate the same
                 * template with the same types.
                 */
                if (parent->isTemplateInstance() && !parent->isTemplateMixin())
                {
                    s->Sclass = SCcomdat;
                    break;
                }
                parent = parent->parent;
            } while (parent);
            s->Sfl = FLdata;

            if (vd->init)
            {
                s->Sdt = Initializer_toDt(vd->init);

                // Look for static array that is block initialized
                ExpInitializer *ie = vd->init->isExpInitializer();

                Type *tb = vd->type->toBasetype();
                if (tb->ty == Tsarray && ie &&
                    !tb->nextOf()->equals(ie->exp->type->toBasetype()->nextOf()) &&
                    ie->exp->implicitConvTo(tb->nextOf())
                    )
                {
                    size_t dim = ((TypeSArray *)tb)->dim->toInteger();

                    // Duplicate Sdt 'dim-1' times, as we already have the first one
                    dt_t **pdt = &s->Sdt;
                    while (--dim > 0)
                    {
                        pdt = Expression_toDt(ie->exp, pdt);
                    }
                }
            }
            else
            {
                Type_toDt(vd->type, &s->Sdt);
            }
            dt_optimize(s->Sdt);

            // See if we can convert a comdat to a comdef,
            // which saves on exe file space.
            if (s->Sclass == SCcomdat &&
                s->Sdt &&
                dtallzeros(s->Sdt) &&
                !vd->isThreadlocal())
            {
                s->Sclass = SCglobal;
                dt2common(&s->Sdt);
            }

            if (!sz && vd->type->toBasetype()->ty != Tsarray)
                assert(0); // this shouldn't be possible

            if (sz || objmod->allowZeroSize())
            {
                outdata(s);
                if (vd->isExport())
                    objmod->export_symbol(s, 0);
            }
        }

        void visit(EnumDeclaration *ed)
        {
            if (ed->semanticRun >= PASSobj)  // already written
                return;
            //printf("EnumDeclaration::toObjFile('%s')\n", ed->toChars());

            if (ed->errors || ed->type->ty == Terror)
            {
                ed->error("had semantic errors when compiling");
                return;
            }

            if (ed->isAnonymous())
                return;

            if (global.params.symdebug)
                toDebug(ed);

            ed->type->genTypeInfo(NULL);

            TypeEnum *tc = (TypeEnum *)ed->type;
            if (!tc->sym->members || ed->type->isZeroInit())
                ;
            else
            {
                enum_SC scclass = SCglobal;
                if (ed->isInstantiated())
                    scclass = SCcomdat;

                // Generate static initializer
                toInitializer(ed);
                ed->sinit->Sclass = scclass;
                ed->sinit->Sfl = FLdata;
                Expression_toDt(tc->sym->defaultval, &ed->sinit->Sdt);
                outdata(ed->sinit);
            }
            ed->semanticRun = PASSobj;
        }

        void visit(TypeInfoDeclaration *tid)
        {
            //printf("TypeInfoDeclaration::toObjFile(%p '%s') protection %d\n", tid, tid->toChars(), tid->protection);

            if (multiobj)
            {
                obj_append(tid);
                return;
            }

            Symbol *s = toSymbol(tid);
            s->Sclass = SCcomdat;
            s->Sfl = FLdata;

            TypeInfo_toDt(&s->Sdt, tid);

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
            if (tid->isExport())
                objmod->export_symbol(s, 0);
        }

        void visit(AttribDeclaration *ad)
        {
            Dsymbols *d = ad->include(NULL, NULL);

            if (d)
            {
                for (size_t i = 0; i < d->dim; i++)
                {
                    Dsymbol *s = (*d)[i];
                    s->accept(this);
                }
            }
        }

        void visit(PragmaDeclaration *pd)
        {
            if (pd->ident == Id::lib)
            {
                assert(pd->args && pd->args->dim == 1);

                Expression *e = (*pd->args)[0];

                assert(e->op == TOKstring);

                StringExp *se = (StringExp *)e;
                char *name = (char *)mem.malloc(se->len + 1);
                memcpy(name, se->string, se->len);
                name[se->len] = 0;

                /* Embed the library names into the object file.
                 * The linker will then automatically
                 * search that library, too.
                 */
                if (!obj_includelib(name))
                {
                    /* The format does not allow embedded library names,
                     * so instead append the library name to the list to be passed
                     * to the linker.
                     */
                    global.params.libfiles->push(name);
                }
            }
            else if (pd->ident == Id::startaddress)
            {
                assert(pd->args && pd->args->dim == 1);
                Expression *e = (*pd->args)[0];
                Dsymbol *sa = getDsymbol(e);
                FuncDeclaration *f = sa->isFuncDeclaration();
                assert(f);
                Symbol *s = toSymbol(f);
                obj_startaddress(s);
            }
            visit((AttribDeclaration *)pd);
        }

        void visit(TemplateInstance *td)
        {
        #if LOG
            printf("TemplateInstance::toObjFile('%s', this = %p)\n", td->toChars(), td);
        #endif
            if (!isError(td) && td->members)
            {
                if (!td->needsCodegen())
                {
                    //printf("-speculative (%p, %s)\n", this, toPrettyChars());
                    return;
                }
                //printf("TemplateInstance::toObjFile('%s', this = %p)\n", toChars(), this);

                if (multiobj)
                {
                    // Append to list of object files to be written later
                    obj_append(td);
                }
                else
                {
                    for (size_t i = 0; i < td->members->dim; i++)
                    {
                        Dsymbol *s = (*td->members)[i];
                        s->accept(this);
                    }
                }
            }
        }

        void visit(TemplateMixin *tm)
        {
            //printf("TemplateMixin::toObjFile('%s')\n", tm->toChars());
            if (!isError(tm) && tm->members)
            {
                for (size_t i = 0; i < tm->members->dim; i++)
                {
                    Dsymbol *s = (*tm->members)[i];
                    s->accept(this);
                }
            }
        }

        void visit(StaticAssert *sa)
        {
        }

        void visit(Nspace *ns)
        {
        #if LOG
            printf("Nspace::toObjFile('%s', this = %p)\n", ns->toChars(), ns);
        #endif
            if (!isError(ns) && ns->members)
            {
                if (multiobj)
                {
                    // Append to list of object files to be written later
                    obj_append(ns);
                }
                else
                {
                    for (size_t i = 0; i < ns->members->dim; i++)
                    {
                        Dsymbol *s = (*ns->members)[i];
                        s->accept(this);
                    }
                }
            }
        }
    };

    ToObjFile v(multiobj);
    ds->accept(&v);
}

/******************************************
 * Get offset of base class's vtbl[] initializer from start of csym.
 * Returns ~0 if not this csym.
 */

unsigned baseVtblOffset(ClassDeclaration *cd, BaseClass *bc)
{
    //printf("ClassDeclaration::baseVtblOffset('%s', bc = %p)\n", cd->toChars(), bc);
    unsigned csymoffset = global.params.isLP64 ? CLASSINFO_SIZE_64 : CLASSINFO_SIZE;    // must be ClassInfo.size
    csymoffset += cd->vtblInterfaces->dim * (4 * Target::ptrsize);

    for (size_t i = 0; i < cd->vtblInterfaces->dim; i++)
    {
        BaseClass *b = (*cd->vtblInterfaces)[i];

        if (b == bc)
            return csymoffset;
        csymoffset += b->base->vtbl.dim * Target::ptrsize;
    }

    // Put out the overriding interface vtbl[]s.
    // This must be mirrored with ClassDeclaration::baseVtblOffset()
    //printf("putting out overriding interface vtbl[]s for '%s' at offset x%x\n", toChars(), offset);
    ClassDeclaration *cd2;

    for (cd2 = cd->baseClass; cd2; cd2 = cd2->baseClass)
    {
        for (size_t k = 0; k < cd2->vtblInterfaces->dim; k++)
        {
            BaseClass *bs = (*cd2->vtblInterfaces)[k];
            if (bs->fillVtbl(cd, NULL, 0))
            {
                if (bc == bs)
                {
                    //printf("\tcsymoffset = x%x\n", csymoffset);
                    return csymoffset;
                }
                csymoffset += bs->base->vtbl.dim * Target::ptrsize;
            }
        }
    }

    return ~0;
}
