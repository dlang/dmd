
// Copyright (c) 1999-2011 by Digital Mars
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

void obj_lzext(Symbol *s1,Symbol *s2);

/* ================================================================== */

// Put out instance of ModuleInfo for this Module

void Module::genmoduleinfo()
{
    //printf("Module::genmoduleinfo() %s\n", toChars());

    Symbol *msym = toSymbol();
#if DMDV2
    unsigned sizeof_ModuleInfo = 16 * PTRSIZE;
#else
    unsigned sizeof_ModuleInfo = 14 * PTRSIZE;
#endif
#if !MODULEINFO_IS_STRUCT
    sizeof_ModuleInfo -= 2 * PTRSIZE;
#endif
    //printf("moduleinfo size = x%x\n", sizeof_ModuleInfo);

    //////////////////////////////////////////////

    csym->Sclass = SCglobal;
    csym->Sfl = FLdata;

#if 1
    dt_t *dt = NULL;
    ClassDeclarations aclasses;

    //printf("members->dim = %d\n", members->dim);
    for (size_t i = 0; i < members->dim; i++)
    {   Dsymbol *member = members->tdata()[i];

        //printf("\tmember '%s'\n", member->toChars());
        member->addLocalClass(&aclasses);
    }

    // importedModules[]
    size_t aimports_dim = aimports.dim;
    for (size_t i = 0; i < aimports.dim; i++)
    {   Module *m = aimports.tdata()[i];
        if (!m->needmoduleinfo)
            aimports_dim--;
    }

    FuncDeclaration *sgetmembers = findGetMembers();

    // These must match the values in druntime/src/object_.d
    #define MIstandalone      4
    #define MItlsctor         8
    #define MItlsdtor         0x10
    #define MIctor            0x20
    #define MIdtor            0x40
    #define MIxgetMembers     0x80
    #define MIictor           0x100
    #define MIunitTest        0x200
    #define MIimportedModules 0x400
    #define MIlocalClasses    0x800
    #define MInew             0x80000000   // it's the "new" layout

    unsigned flags = MInew;
    if (sctor)
        flags |= MItlsctor;
    if (sdtor)
        flags |= MItlsdtor;
    if (ssharedctor)
        flags |= MIctor;
    if (sshareddtor)
        flags |= MIdtor;
    if (sgetmembers)
        flags |= MIxgetMembers;
    if (sictor)
        flags |= MIictor;
    if (stest)
        flags |= MIunitTest;
    if (aimports_dim)
        flags |= MIimportedModules;
    if (aclasses.dim)
        flags |= MIlocalClasses;

    if (!needmoduleinfo)
        flags |= MIstandalone;

    dtdword(&dt, flags);        // n.flags
    dtdword(&dt, 0);            // n.index

    if (flags & MItlsctor)
        dtxoff(&dt, sctor, 0, TYnptr);
    if (flags & MItlsdtor)
        dtxoff(&dt, sdtor, 0, TYnptr);
    if (flags & MIctor)
        dtxoff(&dt, ssharedctor, 0, TYnptr);
    if (flags & MIdtor)
        dtxoff(&dt, sshareddtor, 0, TYnptr);
    if (flags & MIxgetMembers)
        dtxoff(&dt, sgetmembers->toSymbol(), 0, TYnptr);
    if (flags & MIictor)
        dtxoff(&dt, sictor, 0, TYnptr);
    if (flags & MIunitTest)
        dtxoff(&dt, stest, 0, TYnptr);
    if (flags & MIimportedModules)
    {
        dtsize_t(&dt, aimports_dim);
        for (size_t i = 0; i < aimports.dim; i++)
        {   Module *m = aimports[i];

            if (m->needmoduleinfo)
            {   Symbol *s = m->toSymbol();

                /* Weak references don't pull objects in from the library,
                 * they resolve to 0 if not pulled in by something else.
                 * Don't pull in a module just because it was imported.
                 */
#if !OMFOBJ // Optlink crashes with weak symbols at EIP 41AFE7, 402000
                s->Sflags |= SFLweak;
#endif
                dtxoff(&dt, s, 0, TYnptr);
            }
        }
    }
    if (flags & MIlocalClasses)
    {
        dtsize_t(&dt, aclasses.dim);
        for (size_t i = 0; i < aclasses.dim; i++)
        {
            ClassDeclaration *cd = aclasses.tdata()[i];
            dtxoff(&dt, cd->toSymbol(), 0, TYnptr);
        }
    }

    // Put out module name as a 0-terminated string, to save bytes
    nameoffset = dt_size(dt);
    const char *name = toPrettyChars();
    namelen = strlen(name);
    dtnbytes(&dt, namelen + 1, name);
    //printf("nameoffset = x%x\n", nameoffset);
#else
    /* The layout is:
       {
            void **vptr;
            monitor_t monitor;
            char[] name;                // class name
            ModuleInfo importedModules[];
            ClassInfo localClasses[];
            uint flags;                 // initialization state
            void *ctor;
            void *dtor;
            void *unitTest;
            const(MemberInfo[]) function(string) xgetMembers;   // module getMembers() function
            void *ictor;
            void *sharedctor;
            void *shareddtor;
            uint index;
            void*[1] reserved;
       }
     */
    dt_t *dt = NULL;

#if !MODULEINFO_IS_STRUCT
    if (moduleinfo)
        dtxoff(&dt, moduleinfo->toVtblSymbol(), 0, TYnptr); // vtbl for ModuleInfo
    else
    {   //printf("moduleinfo is null\n");
        dtdword(&dt, 0);                // BUG: should be an assert()
    }
    dtdword(&dt, 0);                    // monitor
#endif

    // name[]
    const char *name = toPrettyChars();
    size_t namelen = strlen(name);
    dtdword(&dt, namelen);
    dtabytes(&dt, TYnptr, 0, namelen + 1, name);

    ClassDeclarations aclasses;

    //printf("members->dim = %d\n", members->dim);
    for (size_t i = 0; i < members->dim; i++)
    {   Dsymbol *member = members->tdata()[i];

        //printf("\tmember '%s'\n", member->toChars());
        member->addLocalClass(&aclasses);
    }

    // importedModules[]
    int aimports_dim = aimports.dim;
    for (size_t i = 0; i < aimports.dim; i++)
    {   Module *m = aimports.tdata()[i];
        if (!m->needModuleInfo())
            aimports_dim--;
    }
    dtdword(&dt, aimports_dim);
    if (aimports_dim)
        dtxoff(&dt, csym, sizeof_ModuleInfo, TYnptr);
    else
        dtdword(&dt, 0);

    // localClasses[]
    dtdword(&dt, aclasses.dim);
    if (aclasses.dim)
        dtxoff(&dt, csym, sizeof_ModuleInfo + aimports_dim * PTRSIZE, TYnptr);
    else
        dtdword(&dt, 0);

    if (needmoduleinfo)
        dtdword(&dt, 8);                        // flags
    else
        dtdword(&dt, 8 | MIstandalone);         // flags

    if (ssharedctor)
        dtxoff(&dt, ssharedctor, 0, TYnptr);
    else
        dtdword(&dt, 0);

    if (sshareddtor)
        dtxoff(&dt, sshareddtor, 0, TYnptr);
    else
        dtdword(&dt, 0);

    if (stest)
        dtxoff(&dt, stest, 0, TYnptr);
    else
        dtdword(&dt, 0);

#if DMDV2
    FuncDeclaration *sgetmembers = findGetMembers();
    if (sgetmembers)
        dtxoff(&dt, sgetmembers->toSymbol(), 0, TYnptr);
    else
#endif
        dtdword(&dt, 0);                        // xgetMembers

    if (sictor)
        dtxoff(&dt, sictor, 0, TYnptr);
    else
        dtdword(&dt, 0);

#if DMDV2
    if (sctor)
        dtxoff(&dt, sctor, 0, TYnptr);
    else
        dtdword(&dt, 0);

    if (sdtor)
        dtxoff(&dt, sdtor, 0, TYnptr);
    else
        dtdword(&dt, 0);

    dtdword(&dt, 0);                            // index

    // void*[1] reserved;
    dtdword(&dt, 0);
#endif
    //////////////////////////////////////////////

    for (size_t i = 0; i < aimports.dim; i++)
    {   Module *m = aimports.tdata()[i];

        if (m->needModuleInfo())
        {   Symbol *s = m->toSymbol();

            /* Weak references don't pull objects in from the library,
             * they resolve to 0 if not pulled in by something else.
             * Don't pull in a module just because it was imported.
             */
#if !OMFOBJ // Optlink crashes with weak symbols at EIP 41AFE7, 402000
            s->Sflags |= SFLweak;
#endif
            dtxoff(&dt, s, 0, TYnptr);
        }
    }

    for (size_t i = 0; i < aclasses.dim; i++)
    {
        ClassDeclaration *cd = aclasses.data()[i];
        dtxoff(&dt, cd->toSymbol(), 0, TYnptr);
    }
#endif

    csym->Sdt = dt;
#if ELFOBJ || MACHOBJ
    // Cannot be CONST because the startup code sets flag bits in it
    csym->Sseg = DATA;
#endif
    outdata(csym);

    //////////////////////////////////////////////

    obj_moduleinfo(msym);
}

/* ================================================================== */

void Dsymbol::toObjFile(int multiobj)
{
    //printf("Dsymbol::toObjFile('%s')\n", toChars());
    // ignore
}

/* ================================================================== */

void ClassDeclaration::toObjFile(int multiobj)
{
    unsigned offset;
    Symbol *sinit;
    enum_SC scclass;

    //printf("ClassDeclaration::toObjFile('%s')\n", toChars());

    if (!members)
        return;

    if (multiobj)
    {   obj_append(this);
        return;
    }

    if (global.params.symdebug)
        toDebug();

    assert(!scope);     // semantic() should have been run to completion

    scclass = SCglobal;
    if (inTemplateInstance())
        scclass = SCcomdat;

    // Put out the members
    for (size_t i = 0; i < members->dim; i++)
    {
        Dsymbol *member;

        member = members->tdata()[i];
        member->toObjFile(0);
    }

#if 0
    // Build destructor by aggregating dtors[]
    Symbol *sdtor;
    switch (dtors.dim)
    {   case 0:
            // No destructors for this class
            sdtor = NULL;
            break;

        case 1:
            // One destructor, just use it directly
            sdtor = dtors.tdata()[0]->toSymbol();
            break;

        default:
        {   /* Build a destructor that calls all the
             * other destructors in dtors[].
             */

            elem *edtor = NULL;

            // Declare 'this' pointer for our new destructor
            Symbol *sthis = symbol_calloc("this");
            sthis->Stype = type_fake(TYnptr);
            sthis->Stype->Tcount++;
            sthis->Sclass = SCfastpar;
            sthis->Spreg = AX;
            sthis->Sfl = FLauto;

            // Call each of the destructors in dtors[]
            // in reverse order
            for (size_t i = 0; i < dtors.dim; i++)
            {   DtorDeclaration *d = dtors.tdata()[i];
                Symbol *s = d->toSymbol();
                elem *e = el_bin(OPcall, TYvoid, el_var(s), el_var(sthis));
                edtor = el_combine(e, edtor);
            }

            // Create type for the function
            ::type *t = type_alloc(TYjfunc);
            t->Tflags |= TFprototype | TFfixed;
            t->Tmangle = mTYman_d;
            t->Tnext = tsvoid;
            tsvoid->Tcount++;

            // Create the function, sdtor, and write it out
            localgot = NULL;
            sdtor = toSymbolX("__dtor", SCglobal, t, "FZv");
            block *b = block_calloc();
            b->BC = BCret;
            b->Belem = edtor;
            sdtor->Sfunc->Fstartblock = b;
            cstate.CSpsymtab = &sdtor->Sfunc->Flocsym;
            symbol_add(sthis);
            writefunc(sdtor);
        }
    }
#endif

    // Generate C symbols
    toSymbol();
    toVtblSymbol();
    sinit = toInitializer();

    //////////////////////////////////////////////

    // Generate static initializer
    sinit->Sclass = scclass;
    sinit->Sfl = FLdata;
#if ELFOBJ // Burton
    sinit->Sseg = CDATA;
#endif
#if MACHOBJ
    sinit->Sseg = DATA;
#endif
    toDt(&sinit->Sdt);
    outdata(sinit);

    //////////////////////////////////////////////

    // Put out the TypeInfo
    type->getTypeInfo(NULL);
    //type->vtinfo->toObjFile(multiobj);

    //////////////////////////////////////////////

    // Put out the ClassInfo
    csym->Sclass = scclass;
    csym->Sfl = FLdata;

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
            uint flags;
            void *deallocator;
            OffsetTypeInfo[] offTi;
            void *defaultConstructor;
            const(MemberInfo[]) function(string) xgetMembers;   // module getMembers() function
            //TypeInfo typeinfo;
       }
     */
    dt_t *dt = NULL;
    unsigned classinfo_size = global.params.is64bit ? CLASSINFO_SIZE_64 : CLASSINFO_SIZE;    // must be ClassInfo.size
    offset = classinfo_size;
    if (classinfo)
    {
        if (classinfo->structsize != classinfo_size)
        {
#ifdef DEBUG
            printf("CLASSINFO_SIZE = x%x, classinfo->structsize = x%x\n", offset, classinfo->structsize);
#endif
            error("mismatch between dmd and object.d or object.di found. Check installation and import paths with -v compiler switch.");
            fatal();
        }
    }

    if (classinfo)
        dtxoff(&dt, classinfo->toVtblSymbol(), 0, TYnptr); // vtbl for ClassInfo
    else
        dtsize_t(&dt, 0);                // BUG: should be an assert()
    dtsize_t(&dt, 0);                    // monitor

    // initializer[]
    assert(structsize >= 8);
    dtsize_t(&dt, structsize);           // size
    dtxoff(&dt, sinit, 0, TYnptr);      // initializer

    // name[]
    const char *name = ident->toChars();
    size_t namelen = strlen(name);
    if (!(namelen > 9 && memcmp(name, "TypeInfo_", 9) == 0))
    {   name = toPrettyChars();
        namelen = strlen(name);
    }
    dtsize_t(&dt, namelen);
    dtabytes(&dt, TYnptr, 0, namelen + 1, name);

    // vtbl[]
    dtsize_t(&dt, vtbl.dim);
    dtxoff(&dt, vtblsym, 0, TYnptr);

    // interfaces[]
    dtsize_t(&dt, vtblInterfaces->dim);
    if (vtblInterfaces->dim)
        dtxoff(&dt, csym, offset, TYnptr);      // (*)
    else
        dtsize_t(&dt, 0);

    // base
    if (baseClass)
        dtxoff(&dt, baseClass->toSymbol(), 0, TYnptr);
    else
        dtsize_t(&dt, 0);

    // destructor
    if (dtor)
        dtxoff(&dt, dtor->toSymbol(), 0, TYnptr);
    else
        dtsize_t(&dt, 0);

    // invariant
    if (inv)
        dtxoff(&dt, inv->toSymbol(), 0, TYnptr);
    else
        dtsize_t(&dt, 0);

    // flags
    int flags = 4 | isCOMclass();
#if DMDV2
    flags |= 16;
#endif
    flags |= 32;
    if (ctor)
        flags |= 8;
    for (ClassDeclaration *cd = this; cd; cd = cd->baseClass)
    {
        if (cd->members)
        {
            for (size_t i = 0; i < cd->members->dim; i++)
            {
                Dsymbol *sm = cd->members->tdata()[i];
                //printf("sm = %s %s\n", sm->kind(), sm->toChars());
                if (sm->hasPointers())
                    goto L2;
            }
        }
    }
    flags |= 2;                 // no pointers
  L2:
    dtsize_t(&dt, flags);


    // deallocator
    if (aggDelete)
        dtxoff(&dt, aggDelete->toSymbol(), 0, TYnptr);
    else
        dtsize_t(&dt, 0);

    // offTi[]
    dtsize_t(&dt, 0);
    dtsize_t(&dt, 0);            // null for now, fix later

    // defaultConstructor
    if (defaultCtor)
        dtxoff(&dt, defaultCtor->toSymbol(), 0, TYnptr);
    else
        dtsize_t(&dt, 0);

#if DMDV2
    FuncDeclaration *sgetmembers = findGetMembers();
    if (sgetmembers)
        dtxoff(&dt, sgetmembers->toSymbol(), 0, TYnptr);
    else
        dtsize_t(&dt, 0);        // module getMembers() function
#endif

    //dtxoff(&dt, type->vtinfo->toSymbol(), 0, TYnptr); // typeinfo

    //////////////////////////////////////////////

    // Put out vtblInterfaces->tdata()[]. Must immediately follow csym, because
    // of the fixup (*)

    offset += vtblInterfaces->dim * (4 * PTRSIZE);
    for (size_t i = 0; i < vtblInterfaces->dim; i++)
    {   BaseClass *b = vtblInterfaces->tdata()[i];
        ClassDeclaration *id = b->base;

        /* The layout is:
         *  struct Interface
         *  {
         *      ClassInfo *interface;
         *      void *[] vtbl;
         *      ptrdiff_t offset;
         *  }
         */

        // Fill in vtbl[]
        b->fillVtbl(this, &b->vtbl, 1);

        dtxoff(&dt, id->toSymbol(), 0, TYnptr);         // ClassInfo

        // vtbl[]
        dtsize_t(&dt, id->vtbl.dim);
        dtxoff(&dt, csym, offset, TYnptr);

        dtsize_t(&dt, b->offset);                        // this offset

        offset += id->vtbl.dim * PTRSIZE;
    }

    // Put out the vtblInterfaces->tdata()[].vtbl[]
    // This must be mirrored with ClassDeclaration::baseVtblOffset()
    //printf("putting out %d interface vtbl[]s for '%s'\n", vtblInterfaces->dim, toChars());
    for (size_t i = 0; i < vtblInterfaces->dim; i++)
    {   BaseClass *b = vtblInterfaces->tdata()[i];
        ClassDeclaration *id = b->base;

        //printf("    interface[%d] is '%s'\n", i, id->toChars());
        size_t j = 0;
        if (id->vtblOffset())
        {
            // First entry is ClassInfo reference
            //dtxoff(&dt, id->toSymbol(), 0, TYnptr);

            // First entry is struct Interface reference
            dtxoff(&dt, csym, classinfo_size + i * (4 * PTRSIZE), TYnptr);
            j = 1;
        }
        assert(id->vtbl.dim == b->vtbl.dim);
        for (; j < id->vtbl.dim; j++)
        {
            assert(j < b->vtbl.dim);
#if 0
            Object *o = b->vtbl.tdata()[j];
            if (o)
            {
                printf("o = %p\n", o);
                assert(o->dyncast() == DYNCAST_DSYMBOL);
                Dsymbol *s = (Dsymbol *)o;
                printf("s->kind() = '%s'\n", s->kind());
            }
#endif
            FuncDeclaration *fd = b->vtbl.tdata()[j];
            if (fd)
                dtxoff(&dt, fd->toThunkSymbol(b->offset), 0, TYnptr);
            else
                dtsize_t(&dt, 0);
        }
    }

#if 1
    // Put out the overriding interface vtbl[]s.
    // This must be mirrored with ClassDeclaration::baseVtblOffset()
    //printf("putting out overriding interface vtbl[]s for '%s' at offset x%x\n", toChars(), offset);
    ClassDeclaration *cd;
    FuncDeclarations bvtbl;

    for (cd = this->baseClass; cd; cd = cd->baseClass)
    {
        for (size_t k = 0; k < cd->vtblInterfaces->dim; k++)
        {   BaseClass *bs = cd->vtblInterfaces->tdata()[k];

            if (bs->fillVtbl(this, &bvtbl, 0))
            {
                //printf("\toverriding vtbl[] for %s\n", bs->base->toChars());
                ClassDeclaration *id = bs->base;

                size_t j = 0;
                if (id->vtblOffset())
                {
                    // First entry is ClassInfo reference
                    //dtxoff(&dt, id->toSymbol(), 0, TYnptr);

                    // First entry is struct Interface reference
                    dtxoff(&dt, cd->toSymbol(), classinfo_size + k * (4 * PTRSIZE), TYnptr);
                    j = 1;
                }

                for (; j < id->vtbl.dim; j++)
                {
                    FuncDeclaration *fd;

                    assert(j < bvtbl.dim);
                    fd = bvtbl.tdata()[j];
                    if (fd)
                        dtxoff(&dt, fd->toThunkSymbol(bs->offset), 0, TYnptr);
                    else
                        dtsize_t(&dt, 0);
                }
            }
        }
    }
#endif
#if INTERFACE_VIRTUAL
    // Put out the overriding interface vtbl[]s.
    // This must be mirrored with ClassDeclaration::baseVtblOffset()
    //printf("putting out overriding interface vtbl[]s for '%s' at offset x%x\n", toChars(), offset);
    for (size_t i = 0; i < vtblInterfaces->dim; i++)
    {   BaseClass *b = vtblInterfaces->tdata()[i];
        ClassDeclaration *cd;

        for (cd = this->baseClass; cd; cd = cd->baseClass)
        {
            for (size_t k = 0; k < cd->vtblInterfaces->dim; k++)
            {   BaseClass *bs = cd->vtblInterfaces->tdata()[k];

                if (b->base == bs->base)
                {
                    //printf("\toverriding vtbl[] for %s\n", b->base->toChars());
                    ClassDeclaration *id = b->base;

                    size_t j = 0;
                    if (id->vtblOffset())
                    {
                        // First entry is ClassInfo reference
                        //dtxoff(&dt, id->toSymbol(), 0, TYnptr);

                        // First entry is struct Interface reference
                        dtxoff(&dt, cd->toSymbol(), classinfo_size + k * (4 * PTRSIZE), TYnptr);
                        j = 1;
                    }

                    for (; j < id->vtbl.dim; j++)
                    {
                        assert(j < b->vtbl.dim);
                        FuncDeclaration *fd = b->vtbl.tdata()[j];
                        if (fd)
                            dtxoff(&dt, fd->toThunkSymbol(bs->offset), 0, TYnptr);
                        else
                            dtsize_t(&dt, 0);
                    }
                }
            }
        }
    }
#endif


    csym->Sdt = dt;
#if ELFOBJ || MACHOBJ // Burton
    // ClassInfo cannot be const data, because we use the monitor on it
    csym->Sseg = DATA;
#endif
    outdata(csym);
    if (isExport())
        obj_export(csym,0);

    //////////////////////////////////////////////

    // Put out the vtbl[]
    //printf("putting out %s.vtbl[]\n", toChars());
    dt = NULL;
    dtxoff(&dt, csym, 0, TYnptr);           // first entry is ClassInfo reference
    for (size_t i = 1; i < vtbl.dim; i++)
    {
        FuncDeclaration *fd = vtbl.tdata()[i]->isFuncDeclaration();

        //printf("\tvtbl[%d] = %p\n", i, fd);
        if (fd && (fd->fbody || !isAbstract()))
        {
            // Ensure function has a return value (Bugzilla 4869)
            if (fd->type->ty == Tfunction && !((TypeFunction *)fd->type)->next)
            {
                assert(fd->scope);
                fd->semantic3(fd->scope);
            }

            Symbol *s = fd->toSymbol();

#if DMDV2
            if (isFuncHidden(fd))
            {   /* fd is hidden from the view of this class.
                 * If fd overlaps with any function in the vtbl[], then
                 * issue 'hidden' error.
                 */
                for (size_t j = 1; j < vtbl.dim; j++)
                {   if (j == i)
                        continue;
                    FuncDeclaration *fd2 = vtbl.tdata()[j]->isFuncDeclaration();
                    if (!fd2->ident->equals(fd->ident))
                        continue;
                    if (fd->leastAsSpecialized(fd2) || fd2->leastAsSpecialized(fd))
                    {
                        if (!global.params.useDeprecated)
                        {
                            TypeFunction *tf = (TypeFunction *)fd->type;
                            if (tf->ty == Tfunction)
                                error("use of %s%s hidden by %s is deprecated\n", fd->toPrettyChars(), Parameter::argsTypesToChars(tf->parameters, tf->varargs), toChars());
                            else
                                error("use of %s hidden by %s is deprecated\n", fd->toPrettyChars(), toChars());
                        }
                        s = rtlsym[RTLSYM_DHIDDENFUNC];
                        break;
                    }
                }
            }
#endif
            dtxoff(&dt, s, 0, TYnptr);
        }
        else
            dtsize_t(&dt, 0);
    }
    vtblsym->Sdt = dt;
    vtblsym->Sclass = scclass;
    vtblsym->Sfl = FLdata;
#if ELFOBJ
    vtblsym->Sseg = CDATA;
#endif
#if MACHOBJ
    vtblsym->Sseg = DATA;
#endif
    outdata(vtblsym);
    if (isExport())
        obj_export(vtblsym,0);
}

/******************************************
 * Get offset of base class's vtbl[] initializer from start of csym.
 * Returns ~0 if not this csym.
 */

unsigned ClassDeclaration::baseVtblOffset(BaseClass *bc)
{
    unsigned csymoffset;

    //printf("ClassDeclaration::baseVtblOffset('%s', bc = %p)\n", toChars(), bc);
    csymoffset = global.params.is64bit ? CLASSINFO_SIZE_64 : CLASSINFO_SIZE;    // must be ClassInfo.size
    csymoffset += vtblInterfaces->dim * (4 * PTRSIZE);

    for (size_t i = 0; i < vtblInterfaces->dim; i++)
    {
        BaseClass *b = vtblInterfaces->tdata()[i];

        if (b == bc)
            return csymoffset;
        csymoffset += b->base->vtbl.dim * PTRSIZE;
    }

#if 1
    // Put out the overriding interface vtbl[]s.
    // This must be mirrored with ClassDeclaration::baseVtblOffset()
    //printf("putting out overriding interface vtbl[]s for '%s' at offset x%x\n", toChars(), offset);
    ClassDeclaration *cd;
    FuncDeclarations bvtbl;

    for (cd = this->baseClass; cd; cd = cd->baseClass)
    {
        for (size_t k = 0; k < cd->vtblInterfaces->dim; k++)
        {   BaseClass *bs = cd->vtblInterfaces->tdata()[k];

            if (bs->fillVtbl(this, NULL, 0))
            {
                if (bc == bs)
                {   //printf("\tcsymoffset = x%x\n", csymoffset);
                    return csymoffset;
                }
                csymoffset += bs->base->vtbl.dim * PTRSIZE;
            }
        }
    }
#endif
#if INTERFACE_VIRTUAL
    for (size_t i = 0; i < vtblInterfaces->dim; i++)
    {   BaseClass *b = vtblInterfaces->tdata()[i];
        ClassDeclaration *cd;

        for (cd = this->baseClass; cd; cd = cd->baseClass)
        {
            //printf("\tbase class %s\n", cd->toChars());
            for (size_t k = 0; k < cd->vtblInterfaces->dim; k++)
            {   BaseClass *bs = cd->vtblInterfaces->tdata()[k];

                if (bc == bs)
                {   //printf("\tcsymoffset = x%x\n", csymoffset);
                    return csymoffset;
                }
                if (b->base == bs->base)
                    csymoffset += bs->base->vtbl.dim * PTRSIZE;
            }
        }
    }
#endif

    return ~0;
}

/* ================================================================== */

void InterfaceDeclaration::toObjFile(int multiobj)
{
    enum_SC scclass;

    //printf("InterfaceDeclaration::toObjFile('%s')\n", toChars());

    if (!members)
        return;

    if (global.params.symdebug)
        toDebug();

    scclass = SCglobal;
    if (inTemplateInstance())
        scclass = SCcomdat;

    // Put out the members
    for (size_t i = 0; i < members->dim; i++)
    {   Dsymbol *member = members->tdata()[i];

        member->toObjFile(0);
    }

    // Generate C symbols
    toSymbol();

    //////////////////////////////////////////////

    // Put out the TypeInfo
    type->getTypeInfo(NULL);
    type->vtinfo->toObjFile(multiobj);

    //////////////////////////////////////////////

    // Put out the ClassInfo
    csym->Sclass = scclass;
    csym->Sfl = FLdata;

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
#if DMDV2
            const(MemberInfo[]) function(string) xgetMembers;   // module getMembers() function
#endif
            //TypeInfo typeinfo;
       }
     */
    dt_t *dt = NULL;

    if (classinfo)
        dtxoff(&dt, classinfo->toVtblSymbol(), 0, TYnptr); // vtbl for ClassInfo
    else
        dtsize_t(&dt, 0);                // BUG: should be an assert()
    dtsize_t(&dt, 0);                    // monitor

    // initializer[]
    dtsize_t(&dt, 0);                    // size
    dtsize_t(&dt, 0);                    // initializer

    // name[]
    const char *name = toPrettyChars();
    size_t namelen = strlen(name);
    dtsize_t(&dt, namelen);
    dtabytes(&dt, TYnptr, 0, namelen + 1, name);

    // vtbl[]
    dtsize_t(&dt, 0);
    dtsize_t(&dt, 0);

    // vtblInterfaces->tdata()[]
    unsigned offset;
    dtsize_t(&dt, vtblInterfaces->dim);
    if (vtblInterfaces->dim)
    {
        offset = global.params.is64bit ? CLASSINFO_SIZE_64 : CLASSINFO_SIZE;    // must be ClassInfo.size
        if (classinfo)
        {
            if (classinfo->structsize != offset)
            {
                error("mismatch between dmd and object.d or object.di found. Check installation and import paths with -v compiler switch.");
                fatal();
            }
        }
        dtxoff(&dt, csym, offset, TYnptr);      // (*)
    }
    else
    {   offset = 0;
        dtsize_t(&dt, 0);
    }

    // base
    assert(!baseClass);
    dtsize_t(&dt, 0);

    // dtor
    dtsize_t(&dt, 0);

    // invariant
    dtsize_t(&dt, 0);

    // flags
    dtsize_t(&dt, 4 | isCOMinterface() | 32);

    // deallocator
    dtsize_t(&dt, 0);

    // offTi[]
    dtsize_t(&dt, 0);
    dtsize_t(&dt, 0);            // null for now, fix later

    // defaultConstructor
    dtsize_t(&dt, 0);

#if DMDV2
    // xgetMembers
    dtsize_t(&dt, 0);
#endif

    //dtxoff(&dt, type->vtinfo->toSymbol(), 0, TYnptr); // typeinfo

    //////////////////////////////////////////////

    // Put out vtblInterfaces->tdata()[]. Must immediately follow csym, because
    // of the fixup (*)

    offset += vtblInterfaces->dim * (4 * PTRSIZE);
    for (size_t i = 0; i < vtblInterfaces->dim; i++)
    {   BaseClass *b = vtblInterfaces->tdata()[i];
        ClassDeclaration *id = b->base;

        // ClassInfo
        dtxoff(&dt, id->toSymbol(), 0, TYnptr);

        // vtbl[]
        dtsize_t(&dt, 0);
        dtsize_t(&dt, 0);

        // this offset
        dtsize_t(&dt, b->offset);
    }

    csym->Sdt = dt;
#if ELFOBJ
    csym->Sseg = CDATA;
#endif
#if MACHOBJ
    csym->Sseg = DATA;
#endif
    outdata(csym);
    if (isExport())
        obj_export(csym,0);
}

/* ================================================================== */

void StructDeclaration::toObjFile(int multiobj)
{
    //printf("StructDeclaration::toObjFile('%s')\n", toChars());

    if (multiobj)
    {   obj_append(this);
        return;
    }

    // Anonymous structs/unions only exist as part of others,
    // do not output forward referenced structs's
    if (!isAnonymous() && members)
    {
        if (global.params.symdebug)
            toDebug();

        type->getTypeInfo(NULL);        // generate TypeInfo

        if (1)
        {
            // Generate static initializer
            toInitializer();
#if 0
            sinit->Sclass = SCcomdat;
#else
            if (inTemplateInstance())
            {
                sinit->Sclass = SCcomdat;
            }
            else
            {
                sinit->Sclass = SCglobal;
            }
#endif
            sinit->Sfl = FLdata;
            toDt(&sinit->Sdt);

#if OMFOBJ
            /* For OMF, common blocks aren't pulled in from the library.
             */
            /* ELF comdef's generate multiple
             * definition errors for them from the gnu linker.
             * Need to figure out how to generate proper comdef's for ELF.
             */
            // See if we can convert a comdat to a comdef,
            // which saves on exe file space.
            if (0 &&  // causes multiple def problems with COMMON in one file and COMDAT in library
                sinit->Sclass == SCcomdat &&
                sinit->Sdt &&
                sinit->Sdt->dt == DT_azeros &&
                sinit->Sdt->DTnext == NULL &&
                !global.params.multiobj)
            {
                sinit->Sclass = SCglobal;
                sinit->Sdt->dt = DT_common;
            }
#endif

#if ELFOBJ
            sinit->Sseg = CDATA;
#endif
#if MACHOBJ
            sinit->Sseg = DATA;
#endif
            outdata(sinit);
        }

        // Put out the members
        for (unsigned i = 0; i < members->dim; i++)
        {
            Dsymbol *member;

            member = members->tdata()[i];
            member->toObjFile(0);
        }
    }
}

/* ================================================================== */

void VarDeclaration::toObjFile(int multiobj)
{
    Symbol *s;
    unsigned sz;
    Dsymbol *parent;

    //printf("VarDeclaration::toObjFile(%p '%s' type=%s) protection %d\n", this, toChars(), type->toChars(), protection);
    //printf("\talign = %d\n", type->alignsize());

    if (aliassym)
    {   toAlias()->toObjFile(0);
        return;
    }

#if DMDV2
    // Do not store variables we cannot take the address of
    if (!canTakeAddressOf())
    {
        return;
    }
#endif

    if (isDataseg() && !(storage_class & STCextern))
    {
        s = toSymbol();
        sz = type->size();

        parent = this->toParent();
#if DMDV1       /* private statics should still get a global symbol, in case
         * another module inlines a function that references it.
         */
        if (/*protection == PROTprivate ||*/
            !parent || parent->ident == NULL || parent->isFuncDeclaration())
        {
            s->Sclass = SCstatic;
        }
        else
#endif
        {
            if (storage_class & STCcomdat)
                s->Sclass = SCcomdat;
            else
                s->Sclass = SCglobal;

            do
            {
                /* Global template data members need to be in comdat's
                 * in case multiple .obj files instantiate the same
                 * template with the same types.
                 */
                if (parent->isTemplateInstance() && !parent->isTemplateMixin())
                {
#if DMDV1
                    /* These symbol constants have already been copied,
                     * so no reason to output them.
                     * Note that currently there is no way to take
                     * the address of such a const.
                     */
                    if (isConst() && type->toBasetype()->ty != Tsarray &&
                        init && init->isExpInitializer())
                        return;
#endif
                    s->Sclass = SCcomdat;
                    break;
                }
                parent = parent->parent;
            } while (parent);
        }
        s->Sfl = FLdata;

        if (init)
        {   s->Sdt = init->toDt();

            // Look for static array that is block initialized
            Type *tb;
            ExpInitializer *ie = init->isExpInitializer();

            tb = type->toBasetype();
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
                    pdt = ie->exp->toDt(pdt);
                }
            }
        }
        else if (storage_class & STCextern)
        {
            s->Sclass = SCextern;
            s->Sfl = FLextern;
            s->Sdt = NULL;
            // BUG: if isExport(), shouldn't we make it dllimport?
            return;
        }
        else
        {
            type->toDt(&s->Sdt);
        }
        dt_optimize(s->Sdt);

        // See if we can convert a comdat to a comdef,
        // which saves on exe file space.
        if (s->Sclass == SCcomdat &&
            s->Sdt &&
            s->Sdt->dt == DT_azeros &&
            s->Sdt->DTnext == NULL &&
            !isThreadlocal())
        {
            s->Sclass = SCglobal;
            s->Sdt->dt = DT_common;
        }

#if ELFOBJ || MACHOBJ // Burton
        if (s->Sdt && s->Sdt->dt == DT_azeros && s->Sdt->DTnext == NULL)
            s->Sseg = UDATA;
        else
            s->Sseg = DATA;
#endif
        if (sz)
        {   outdata(s);
            if (isExport())
                obj_export(s,0);
        }
    }
}

/* ================================================================== */

void TypedefDeclaration::toObjFile(int multiobj)
{
    //printf("TypedefDeclaration::toObjFile('%s')\n", toChars());

    if (global.params.symdebug)
        toDebug();

    type->getTypeInfo(NULL);    // generate TypeInfo

    TypeTypedef *tc = (TypeTypedef *)type;
    if (type->isZeroInit() || !tc->sym->init)
        ;
    else
    {
        enum_SC scclass = SCglobal;
        if (inTemplateInstance())
            scclass = SCcomdat;

        // Generate static initializer
        toInitializer();
        sinit->Sclass = scclass;
        sinit->Sfl = FLdata;
#if ELFOBJ // Burton
        sinit->Sseg = CDATA;
#endif
#if MACHOBJ
        sinit->Sseg = DATA;
#endif
        sinit->Sdt = tc->sym->init->toDt();
        outdata(sinit);
    }
}

/* ================================================================== */

void EnumDeclaration::toObjFile(int multiobj)
{
    //printf("EnumDeclaration::toObjFile('%s')\n", toChars());

#if DMDV2
    if (isAnonymous())
        return;
#endif

    if (global.params.symdebug)
        toDebug();

    type->getTypeInfo(NULL);    // generate TypeInfo

    TypeEnum *tc = (TypeEnum *)type;
    if (!tc->sym->defaultval || type->isZeroInit())
        ;
    else
    {
        enum_SC scclass = SCglobal;
        if (inTemplateInstance())
            scclass = SCcomdat;

        // Generate static initializer
        toInitializer();
        sinit->Sclass = scclass;
        sinit->Sfl = FLdata;
#if ELFOBJ // Burton
        sinit->Sseg = CDATA;
#endif
#if MACHOBJ
        sinit->Sseg = DATA;
#endif
#if DMDV1
        dtnbytes(&sinit->Sdt, tc->size(0), (char *)&tc->sym->defaultval);
        //sinit->Sdt = tc->sym->init->toDt();
#endif
#if DMDV2
        tc->sym->defaultval->toDt(&sinit->Sdt);
#endif
        outdata(sinit);
    }
}



