
// Copyright (c) 1999-2012 by Digital Mars
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

void obj_lzext(Symbol *s1,Symbol *s2);

/* ================================================================== */

// Put out instance of ModuleInfo for this Module

void Module::genmoduleinfo()
{
    //printf("Module::genmoduleinfo() %s\n", toChars());

    Symbol *msym = toSymbol();
#if DMDV2
    unsigned sizeof_ModuleInfo = 18 * Target::ptrsize;
#else
    unsigned sizeof_ModuleInfo = 14 * Target::ptrsize;
#endif

    //////////////////////////////////////////////

    csym->Sclass = SCglobal;
    csym->Sfl = FLdata;

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
       }
     */
    dt_t *dt = NULL;

    if (moduleinfo)
        dtxoff(&dt, moduleinfo->toVtblSymbol(), 0, TYnptr); // vtbl for ModuleInfo
    else
    {   //printf("moduleinfo is null\n");
        dtsize_t(&dt, 0);                // BUG: should be an assert()
    }
    dtsize_t(&dt, 0);                    // monitor

    // name[]
    const char *name = toPrettyChars();
    size_t namelen = strlen(name);
    dtsize_t(&dt, namelen);
    dtabytes(&dt, TYnptr, 0, namelen + 1, name);

    ClassDeclarations aclasses;

    //printf("members->dim = %d\n", members->dim);
    for (size_t i = 0; i < members->dim; i++)
    {   Dsymbol *member = (*members)[i];

        //printf("\tmember '%s'\n", member->toChars());
        member->addLocalClass(&aclasses);
    }

    // importedModules[]
    int aimports_dim = aimports.dim;
    for (size_t i = 0; i < aimports.dim; i++)
    {   Module *m = aimports[i];
        if (!m->needmoduleinfo)
            aimports_dim--;
    }
    dtsize_t(&dt, aimports_dim);
    if (aimports_dim)
        dtxoff(&dt, csym, sizeof_ModuleInfo, TYnptr);
    else
        dtsize_t(&dt, 0);

    // localClasses[]
    dtsize_t(&dt, aclasses.dim);
    if (aclasses.dim)
        dtxoff(&dt, csym, sizeof_ModuleInfo + aimports_dim * Target::ptrsize, TYnptr);
    else
        dtsize_t(&dt, 0);

    if (needmoduleinfo)
        dtsize_t(&dt, 8|0);              // flags (4 means MIstandalone)
    else
        dtsize_t(&dt, 8|4);              // flags (4 means MIstandalone)

    if (sctor)
        dtxoff(&dt, sctor, 0, TYnptr);
    else
        dtsize_t(&dt, 0);

    if (sdtor)
        dtxoff(&dt, sdtor, 0, TYnptr);
    else
        dtsize_t(&dt, 0);

    if (stest)
        dtxoff(&dt, stest, 0, TYnptr);
    else
        dtsize_t(&dt, 0);

#if DMDV2
    FuncDeclaration *sgetmembers = findGetMembers();
    if (sgetmembers)
        dtxoff(&dt, sgetmembers->toSymbol(), 0, TYnptr);
    else
#endif
        dtsize_t(&dt, 0);                        // xgetMembers

    if (sictor)
        dtxoff(&dt, sictor, 0, TYnptr);
    else
        dtsize_t(&dt, 0);

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
    {   Module *m = aimports[i];

        if (m->needmoduleinfo)
        {   Symbol *s = m->toSymbol();

            /* Weak references don't pull objects in from the library,
             * they resolve to 0 if not pulled in by something else.
             * Don't pull in a module just because it was imported.
             */
            s->Sflags |= SFLweak;
            dtxoff(&dt, s, 0, TYnptr);
        }
    }

    for (size_t i = 0; i < aclasses.dim; i++)
    {
        ClassDeclaration *cd = aclasses[i];
        dtxoff(&dt, cd->toSymbol(), 0, TYnptr);
    }

    csym->Sdt = dt;
    // Cannot be CONST because the startup code sets flag bits in it
    outdata(csym);

    //////////////////////////////////////////////

    objmod->moduleinfo(msym);
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

    if (type->ty == Terror)
    {   error("had semantic errors when compiling");
        return;
    }

    if (!members)
        return;

    if (multiobj && !hasStaticCtorOrDtor())
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
        Dsymbol *member = (*members)[i];
        /* There might be static ctors in the members, and they cannot
         * be put in separate obj files.
         */
        member->toObjFile(multiobj);
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
            sdtor = dtors[0]->toSymbol();
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
            sthis->Sclass = (config.exe == EX_WIN64) ? SCshadowreg : SCfastpar;
            sthis->Spreg = AX;
            sthis->Spreg2 = NOREG;
            sthis->Sfl = (sthis->Sclass == SCshadowreg) ? FLauto : FLfast;

            // Call each of the destructors in dtors[]
            // in reverse order
            for (size_t i = 0; i < dtors.dim; i++)
            {   DtorDeclaration *d = dtors[i];
                Symbol *s = d->toSymbol();
                elem *e = el_bin(OPcall, TYvoid, el_var(s), el_var(sthis));
                edtor = el_combine(e, edtor);
            }

            // Create type for the function
            ::type *t = type_function(TYjfunc, NULL, 0, false, tsvoid);
            t->Tmangle = mTYman_d;

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
    toDt(&sinit->Sdt);
    out_readonly(sinit);
    outdata(sinit);

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
            ClassInfo *base;            // base class
            void *destructor;
            void *invariant;            // class invariant
            uint flags;
            void *deallocator;
            OffsetTypeInfo[] offTi;
            void *defaultConstructor;
            const(MemberInfo[]) function(string) xgetMembers;   // module getMembers() function
            TypeInfo typeinfo;
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
    if (isabstract)
        flags |= 64;
    for (ClassDeclaration *cd = this; cd; cd = cd->baseClass)
    {
        if (cd->members)
        {
            for (size_t i = 0; i < cd->members->dim; i++)
            {
                Dsymbol *sm = (*cd->members)[i];
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

    dtxoff(&dt, type->vtinfo->toSymbol(), 0, TYnptr);   // typeinfo
    //dtsize_t(&dt, 0);

    //////////////////////////////////////////////

    // Put out (*vtblInterfaces)[]. Must immediately follow csym, because
    // of the fixup (*)

    offset += vtblInterfaces->dim * (4 * Target::ptrsize);
    for (size_t i = 0; i < vtblInterfaces->dim; i++)
    {   BaseClass *b = (*vtblInterfaces)[i];
        ClassDeclaration *id = b->base;

        /* The layout is:
         *  {
         *      ClassInfo *interface;
         *      void *[] vtbl;
         *      unsigned offset;
         *  }
         */

        // Fill in vtbl[]
        b->fillVtbl(this, &b->vtbl, 1);

        dtxoff(&dt, id->toSymbol(), 0, TYnptr);         // ClassInfo

        // vtbl[]
        dtsize_t(&dt, id->vtbl.dim);
        dtxoff(&dt, csym, offset, TYnptr);

        dtsize_t(&dt, b->offset);                        // this offset

        offset += id->vtbl.dim * Target::ptrsize;
    }

    // Put out the (*vtblInterfaces)[].vtbl[]
    // This must be mirrored with ClassDeclaration::baseVtblOffset()
    //printf("putting out %d interface vtbl[]s for '%s'\n", vtblInterfaces->dim, toChars());
    for (size_t i = 0; i < vtblInterfaces->dim; i++)
    {   BaseClass *b = (*vtblInterfaces)[i];
        ClassDeclaration *id = b->base;

        //printf("    interface[%d] is '%s'\n", i, id->toChars());
        size_t j = 0;
        if (id->vtblOffset())
        {
            // First entry is ClassInfo reference
            //dtxoff(&dt, id->toSymbol(), 0, TYnptr);

            // First entry is struct Interface reference
            dtxoff(&dt, csym, classinfo_size + i * (4 * Target::ptrsize), TYnptr);
            j = 1;
        }
        assert(id->vtbl.dim == b->vtbl.dim);
        for (; j < id->vtbl.dim; j++)
        {
            assert(j < b->vtbl.dim);
#if 0
            Object *o = b->vtbl[j];
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
        {   BaseClass *bs = (*cd->vtblInterfaces)[k];

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
                    dtxoff(&dt, cd->toSymbol(), classinfo_size + k * (4 * Target::ptrsize), TYnptr);
                    j = 1;
                }

                for (; j < id->vtbl.dim; j++)
                {
                    FuncDeclaration *fd;

                    assert(j < bvtbl.dim);
                    fd = bvtbl[j];
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
    {   BaseClass *b = (*vtblInterfaces)[i];
        ClassDeclaration *cd;

        for (cd = this->baseClass; cd; cd = cd->baseClass)
        {
            for (size_t k = 0; k < cd->vtblInterfaces->dim; k++)
            {   BaseClass *bs = (*cd->vtblInterfaces)[k];

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
                        dtxoff(&dt, cd->toSymbol(), classinfo_size + k * (4 * Target::ptrsize), TYnptr);
                        j = 1;
                    }

                    for (; j < id->vtbl.dim; j++)
                    {
                        assert(j < b->vtbl.dim);
                        FuncDeclaration *fd = b->vtbl[j];
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
    // ClassInfo cannot be const data, because we use the monitor on it
    outdata(csym);
    if (isExport())
        objmod->export_symbol(csym,0);

    //////////////////////////////////////////////

    // Put out the vtbl[]
    //printf("putting out %s.vtbl[]\n", toChars());
    dt = NULL;
    dtxoff(&dt, csym, 0, TYnptr);           // first entry is ClassInfo reference
    for (size_t i = 1; i < vtbl.dim; i++)
    {
        FuncDeclaration *fd = vtbl[i]->isFuncDeclaration();

        //printf("\tvtbl[%d] = %p\n", i, fd);
        if (fd && (fd->fbody || !isAbstract()))
        {   Symbol *s = fd->toSymbol();

#if DMDV2
            if (isFuncHidden(fd))
            {   /* fd is hidden from the view of this class.
                 * If fd overlaps with any function in the vtbl[], then
                 * issue 'hidden' error.
                 */
                for (size_t j = 1; j < vtbl.dim; j++)
                {   if (j == i)
                        continue;
                    FuncDeclaration *fd2 = vtbl[j]->isFuncDeclaration();
                    if (!fd2->ident->equals(fd->ident))
                        continue;
                    if (fd->leastAsSpecialized(fd2) || fd2->leastAsSpecialized(fd))
                    {
                        if (global.params.warnings)
                        {
                            TypeFunction *tf = (TypeFunction *)fd->type;
                            if (tf->ty == Tfunction)
                                warning("%s%s hidden by. Use 'alias %s.%s %s;' to introduce base class overload set.", fd->toPrettyChars(), Parameter::argsTypesToChars(tf->parameters, tf->varargs), toChars(), fd->parent->toChars(), fd->toChars(), fd->toChars());
                            else
                                warning("%s is hidden by %s\n", fd->toPrettyChars(), toChars());
                        }
                        s = getRtlsym(RTLSYM_DHIDDENFUNC);
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
    out_readonly(vtblsym);
    outdata(vtblsym);
    if (isExport())
        objmod->export_symbol(vtblsym,0);
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
    csymoffset += vtblInterfaces->dim * (4 * Target::ptrsize);

    for (size_t i = 0; i < vtblInterfaces->dim; i++)
    {
        BaseClass *b = (*vtblInterfaces)[i];

        if (b == bc)
            return csymoffset;
        csymoffset += b->base->vtbl.dim * Target::ptrsize;
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
        {   BaseClass *bs = (*cd->vtblInterfaces)[k];

            if (bs->fillVtbl(this, NULL, 0))
            {
                if (bc == bs)
                {   //printf("\tcsymoffset = x%x\n", csymoffset);
                    return csymoffset;
                }
                csymoffset += bs->base->vtbl.dim * Target::ptrsize;
            }
        }
    }
#endif
#if INTERFACE_VIRTUAL
    for (size_t i = 0; i < vtblInterfaces->dim; i++)
    {   BaseClass *b = (*vtblInterfaces)[i];
        ClassDeclaration *cd;

        for (cd = this->baseClass; cd; cd = cd->baseClass)
        {
            //printf("\tbase class %s\n", cd->toChars());
            for (size_t k = 0; k < cd->vtblInterfaces->dim; k++)
            {   BaseClass *bs = (*cd->vtblInterfaces)[k];

                if (bc == bs)
                {   //printf("\tcsymoffset = x%x\n", csymoffset);
                    return csymoffset;
                }
                if (b->base == bs->base)
                    csymoffset += bs->base->vtbl.dim * Target::ptrsize;
            }
        }
    }
#endif

    return ~0;
}

/* ================================================================== */

void InterfaceDeclaration::toObjFile(int multiobj)
{
    Symbol *sinit;
    enum_SC scclass;

    //printf("InterfaceDeclaration::toObjFile('%s')\n", toChars());

    if (type->ty == Terror)
    {   error("had semantic errors when compiling");
        return;
    }

    if (!members)
        return;

    if (global.params.symdebug)
        toDebug();

    scclass = SCglobal;
    if (inTemplateInstance())
        scclass = SCcomdat;

    // Put out the members
    for (size_t i = 0; i < members->dim; i++)
    {   Dsymbol *member = (*members)[i];
        if (!member->isFuncDeclaration())
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
            //const(MemberInfo[]) function(string) xgetMembers;   // module getMembers() function
            void* xgetRTInfo;
#endif
            TypeInfo typeinfo;
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

    // (*vtblInterfaces)[]
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
    //dtsize_t(&dt, 0);

    // xgetRTInfo
    dtsize_t(&dt, 0x12345678);
#endif

    dtxoff(&dt, type->vtinfo->toSymbol(), 0, TYnptr);   // typeinfo

    //////////////////////////////////////////////

    // Put out (*vtblInterfaces)[]. Must immediately follow csym, because
    // of the fixup (*)

    offset += vtblInterfaces->dim * (4 * Target::ptrsize);
    for (size_t i = 0; i < vtblInterfaces->dim; i++)
    {   BaseClass *b = (*vtblInterfaces)[i];
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
    out_readonly(csym);
    outdata(csym);
    if (isExport())
        objmod->export_symbol(csym,0);
}

/* ================================================================== */

void StructDeclaration::toObjFile(int multiobj)
{
    //printf("StructDeclaration::toObjFile('%s')\n", toChars());

    if (type->ty == Terror)
    {   error("had semantic errors when compiling");
        return;
    }

    if (multiobj && !hasStaticCtorOrDtor())
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
            if (inTemplateInstance())
            {
                sinit->Sclass = SCcomdat;
            }
            else
            {
                sinit->Sclass = SCglobal;
            }

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
            if (sinit->Sclass == SCcomdat &&
                sinit->Sdt &&
                dtallzeros(sinit->Sdt) &&
                !global.params.multiobj)
            {
                sinit->Sclass = SCglobal;
                dt2common(&sinit->Sdt);
            }
#endif

            out_readonly(sinit);
            outdata(sinit);
        }

        // Put out the members
        for (size_t i = 0; i < members->dim; i++)
        {
            Dsymbol *member = (*members)[i];
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

    if (type->ty == Terror)
    {   error("had semantic errors when compiling");
        return;
    }

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
            dtallzeros(s->Sdt))
        {
            s->Sclass = SCglobal;
            dt2common(&s->Sdt);
        }

        if (!sz && type->toBasetype()->ty != Tsarray)
            assert(0); // this shouldn't be possible

        if (sz || objmod->allowZeroSize())
        {
            outdata(s);
            if (isExport())
            objmod->export_symbol(s,0);
        }
    }
}

/* ================================================================== */

void TypedefDeclaration::toObjFile(int multiobj)
{
    //printf("TypedefDeclaration::toObjFile('%s')\n", toChars());

    if (type->ty == Terror)
    {   error("had semantic errors when compiling");
        return;
    }

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
        sinit->Sdt = tc->sym->init->toDt();
        out_readonly(sinit);
        outdata(sinit);
    }
}

/* ================================================================== */

void EnumDeclaration::toObjFile(int multiobj)
{
    //printf("EnumDeclaration::toObjFile('%s')\n", toChars());

    if (type->ty == Terror)
    {   error("had semantic errors when compiling");
        return;
    }

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



