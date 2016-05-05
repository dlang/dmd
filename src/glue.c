
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2016 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/dlang/dmd/blob/master/src/glue.c
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
#include "lib.h"
#include "target.h"
#include "aliasthis.h"
#include "cond.h"
#include "ctfe.h"
#include "macro.h"
#include "scope.h"
#include "version.h"
#include "hdrgen.h"
#include "staticassert.h"

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

void clearStringTab();
RET retStyle(TypeFunction *tf);

elem *addressElem(elem *e, Type *t, bool alwaysCopy = false);
void Statement_toIR(Statement *s, IRState *irs);
void insertFinallyBlockCalls(block *startblock);
elem *toEfilename(Module *m);
Symbol *toSymbol(Dsymbol *s);
void buildClosure(FuncDeclaration *fd, IRState *irs);
Symbol *toStringSymbol(const char *str, size_t len, size_t pad);

typedef Array<symbol *> symbols;
Dsymbols *Dsymbols_create();
Expressions *Expressions_create();
type *Type_toCtype(Type *t);
void toObjFile(Dsymbol *ds, bool multiobj);
void genModuleInfo(Module *m);
void genObjFile(Module *m, bool multiobj);
Symbol *toModuleAssert(Module *m);
Symbol *toModuleUnittest(Module *m);
Symbol *toModuleArray(Module *m);
Symbol *toSymbolX(Dsymbol *ds, const char *prefix, int sclass, type *t, const char *suffix);
static void genhelpers(Module *m);

elem *eictor;
symbol *ictorlocalgot;
symbols sctors;
StaticDtorDeclarations ectorgates;
symbols sdtors;
symbols stests;

symbols ssharedctors;
SharedStaticDtorDeclarations esharedctorgates;
symbols sshareddtors;

char *lastmname;

bool onlyOneMain(Loc loc);

/**************************************
 * Append s to list of object files to generate later.
 */

Dsymbols obj_symbols_towrite;

void obj_append(Dsymbol *s)
{
    //printf("deferred: %s\n", s->toChars());
    obj_symbols_towrite.push(s);
}

void obj_write_deferred(Library *library)
{
    for (size_t i = 0; i < obj_symbols_towrite.dim; i++)
    {
        Dsymbol *s = obj_symbols_towrite[i];
        Module *m = s->getModule();

        char *mname;
        if (m)
        {
            mname = (char*)m->srcfile->toChars();
            lastmname = mname;
        }
        else
        {
            //mname = s->ident->toChars();
            mname = lastmname;
            assert(mname);
        }

        obj_start(mname);

        static int count;
        count++;                // sequence for generating names

        /* Create a module that's a doppelganger of m, with just
         * enough to be able to create the moduleinfo.
         */
        OutBuffer idbuf;
        idbuf.printf("%s.%d", m ? m->ident->toChars() : mname, count);
        char *idstr = idbuf.peekString();

        if (!m)
        {
            // it doesn't make sense to make up a module if we don't know where to put the symbol
            //  so output it into it's own object file without ModuleInfo
            objmod->initfile(idstr, NULL, mname);
            toObjFile(s, false);
            objmod->termfile();
        }
        else
        {
            idbuf.data = NULL;
            Identifier *id = Identifier::create(idstr);

            Module *md = Module::create(mname, id, 0, 0);
            md->members = Dsymbols_create();
            md->members->push(s);   // its only 'member' is s
            md->doppelganger = 1;       // identify this module as doppelganger
            md->md = m->md;
            md->aimports.push(m);       // it only 'imports' m
            md->massert = m->massert;
            md->munittest = m->munittest;
            md->marray = m->marray;

            genObjFile(md, false);
        }

        /* Set object file name to be source name with sequence number,
         * as mangled symbol names get way too long.
         */
        const char *fname = FileName::removeExt(mname);
        OutBuffer namebuf;
        unsigned hash = 0;
        for (char *p = s->toChars(); *p; p++)
            hash += *p;
        namebuf.printf("%s_%x_%x.%s", fname, count, hash, global.obj_ext);
        FileName::free((char *)fname);
        fname = namebuf.extractString();

        //printf("writing '%s'\n", fname);
        File *objfile = File::create(fname);
        obj_end(library, objfile);
    }
    obj_symbols_towrite.dim = 0;
}

/***********************************************
 * Generate function that calls array of functions and gates.
 */

symbol *callFuncsAndGates(Module *m, symbols *sctors, StaticDtorDeclarations *ectorgates,
        const char *id)
{
    symbol *sctor = NULL;

    if ((sctors && sctors->dim) ||
        (ectorgates && ectorgates->dim))
    {
        static type *t;
        if (!t)
        {
            /* t will be the type of the functions generated:
             *      extern (C) void func();
             */
            t = type_function(TYnfunc, NULL, 0, false, tsvoid);
            t->Tmangle = mTYman_c;
        }

        localgot = NULL;
        sctor = toSymbolX(m, id, SCglobal, t, "FZv");
        cstate.CSpsymtab = &sctor->Sfunc->Flocsym;
        elem *ector = NULL;

        if (ectorgates)
        {
            for (size_t i = 0; i < ectorgates->dim; i++)
            {   StaticDtorDeclaration *f = (*ectorgates)[i];

                Symbol *s = toSymbol(f->vgate);
                elem *e = el_var(s);
                e = el_bin(OPaddass, TYint, e, el_long(TYint, 1));
                ector = el_combine(ector, e);
            }
        }

        if (sctors)
        {
            for (size_t i = 0; i < sctors->dim; i++)
            {   symbol *s = (*sctors)[i];
                elem *e = el_una(OPucall, TYvoid, el_var(s));
                ector = el_combine(ector, e);
            }
        }

        block *b = block_calloc();
        b->BC = BCret;
        b->Belem = ector;
        sctor->Sfunc->Fstartline.Sfilename = m->arg;
        sctor->Sfunc->Fstartblock = b;
        writefunc(sctor);
    }
    return sctor;
}

/**************************************
 * Prepare for generating obj file.
 */

Outbuffer objbuf;

void obj_start(char *srcfile)
{
    //printf("obj_start()\n");

    rtlsym_reset();
    clearStringTab();

#if TARGET_WINDOS
    // Produce Ms COFF files for 64 bit code, OMF for 32 bit code
    assert(objbuf.size() == 0);
    objmod = global.params.mscoff ? MsCoffObj::init(&objbuf, srcfile, NULL)
                                  :       Obj::init(&objbuf, srcfile, NULL);
#else
    objmod = Obj::init(&objbuf, srcfile, NULL);
#endif

    el_reset();
    cg87_reset();
    out_reset();
}

void obj_end(Library *library, File *objfile)
{
    const char *objfilename = objfile->name->toChars();
    objmod->term(objfilename);
    delete objmod;
    objmod = NULL;

    if (library)
    {
        // Transfer image to library
        library->addObject(objfilename, objbuf.buf, objbuf.p - objbuf.buf);
        objbuf.buf = NULL;
    }
    else
    {
        // Transfer image to file
        objfile->setbuffer(objbuf.buf, objbuf.p - objbuf.buf);
        objbuf.buf = NULL;

        ensurePathToNameExists(Loc(), objfilename);

        //printf("write obj %s\n", objfilename);
        writeFile(Loc(), objfile);
    }
    objbuf.pend = NULL;
    objbuf.p = NULL;
    objbuf.len = 0;
    objbuf.inc = 0;
}

bool obj_includelib(const char *name)
{
    return objmod->includelib(name);
}

void obj_startaddress(Symbol *s)
{
    return objmod->startaddress(s);
}


/**************************************
 * Generate .obj file for Module.
 */

void genObjFile(Module *m, bool multiobj)
{
    //EEcontext *ee = env->getEEcontext();

    //printf("Module::genobjfile(multiobj = %d) %s\n", multiobj, m->toChars());

    if (m->ident == Id::entrypoint)
    {
        bool v = global.params.verbose;
        global.params.verbose = false;

        for (size_t i = 0; i < m->members->dim; i++)
        {
            Dsymbol *member = (*m->members)[i];
            //printf("toObjFile %s %s\n", member->kind(), member->toChars());
            toObjFile(member, global.params.multiobj);
        }

        global.params.verbose = v;
        return;
    }

    lastmname = (char*)m->srcfile->toChars();

    objmod->initfile(lastmname, NULL, m->toPrettyChars());

    eictor = NULL;
    ictorlocalgot = NULL;
    sctors.setDim(0);
    ectorgates.setDim(0);
    sdtors.setDim(0);
    ssharedctors.setDim(0);
    esharedctorgates.setDim(0);
    sshareddtors.setDim(0);
    stests.setDim(0);

    if (m->doppelganger)
    {
        /* Generate a reference to the moduleinfo, so the module constructors
         * and destructors get linked in.
         */
        Module *mod = m->aimports[0];
        assert(mod);
        if (mod->sictor || mod->sctor || mod->sdtor || mod->ssharedctor || mod->sshareddtor)
        {
            Symbol *s = toSymbol(mod);
            //objextern(s);
            //if (!s->Sxtrnnum) objextdef(s->Sident);
            if (!s->Sxtrnnum)
            {
                //printf("%s\n", s->Sident);
#if 0 /* This should work, but causes optlink to fail in common/newlib.asm */
                objextdef(s->Sident);
#else
                Symbol *sref = symbol_generate(SCstatic, type_fake(TYnptr));
                sref->Sfl = FLdata;
                DtBuilder dtb;
                dtb.xoff(s, 0, TYnptr);
                sref->Sdt = dtb.finish();
                outdata(sref);
#endif
            }
        }
    }

    if (global.params.cov)
    {
        /* Create coverage identifier:
         *  private uint[numlines] __coverage;
         */
        m->cov = symbol_calloc("__coverage");
        m->cov->Stype = type_fake(TYint);
        m->cov->Stype->Tmangle = mTYman_c;
        m->cov->Stype->Tcount++;
        m->cov->Sclass = SCstatic;
        m->cov->Sfl = FLdata;

        DtBuilder dtb;
        dtb.nzeros(4 * m->numlines);
        m->cov->Sdt = dtb.finish();

        outdata(m->cov);

        m->covb = (unsigned *)calloc((m->numlines + 32) / 32, sizeof(*m->covb));
    }

    for (size_t i = 0; i < m->members->dim; i++)
    {
        Dsymbol *member = (*m->members)[i];
        //printf("toObjFile %s %s\n", member->kind(), member->toChars());
        toObjFile(member, multiobj);
    }

    if (global.params.cov)
    {
        /* Generate
         *  private bit[numlines] __bcoverage;
         */
        Symbol *bcov = symbol_calloc("__bcoverage");
        bcov->Stype = type_fake(TYuint);
        bcov->Stype->Tcount++;
        bcov->Sclass = SCstatic;
        bcov->Sfl = FLdata;

        DtBuilder dtb;
        dtb.nbytes((m->numlines + 32) / 32 * sizeof(*m->covb), (char *)m->covb);
        bcov->Sdt = dtb.finish();

        outdata(bcov);

        free(m->covb);
        m->covb = NULL;

        /* Generate:
         *  _d_cover_register(uint[] __coverage, BitArray __bcoverage, string filename);
         * and prepend it to the static constructor.
         */

        /* t will be the type of the functions generated:
         *      extern (C) void func();
         */
        type *t = type_function(TYnfunc, NULL, 0, false, tsvoid);
        t->Tmangle = mTYman_c;

        m->sictor = toSymbolX(m, "__modictor", SCglobal, t, "FZv");
        cstate.CSpsymtab = &m->sictor->Sfunc->Flocsym;
        localgot = ictorlocalgot;

        elem *ecov  = el_pair(TYdarray, el_long(TYsize_t, m->numlines), el_ptr(m->cov));
        elem *ebcov = el_pair(TYdarray, el_long(TYsize_t, m->numlines), el_ptr(bcov));

        if (config.exe == EX_WIN64)
        {
            ecov  = addressElem(ecov,  Type::tvoid->arrayOf(), false);
            ebcov = addressElem(ebcov, Type::tvoid->arrayOf(), false);
        }

        elem *efilename = toEfilename(m);
        if (config.exe == EX_WIN64)
            efilename = addressElem(efilename, Type::tstring, true);

        elem *e = el_params(
                      el_long(TYuchar, global.params.covPercent),
                      ecov,
                      ebcov,
                      efilename,
                      NULL);
        e = el_bin(OPcall, TYvoid, el_var(getRtlsym(RTLSYM_DCOVER2)), e);
        eictor = el_combine(e, eictor);
        ictorlocalgot = localgot;
    }

    // If coverage / static constructor / destructor / unittest calls
    if (eictor || sctors.dim || ectorgates.dim || sdtors.dim ||
        ssharedctors.dim || esharedctorgates.dim || sshareddtors.dim || stests.dim)
    {
        if (eictor)
        {
            localgot = ictorlocalgot;

            block *b = block_calloc();
            b->BC = BCret;
            b->Belem = eictor;
            m->sictor->Sfunc->Fstartline.Sfilename = m->arg;
            m->sictor->Sfunc->Fstartblock = b;
            writefunc(m->sictor);
        }

        m->sctor = callFuncsAndGates(m, &sctors, &ectorgates, "__modctor");
        m->sdtor = callFuncsAndGates(m, &sdtors, NULL, "__moddtor");

        m->ssharedctor = callFuncsAndGates(m, &ssharedctors, (StaticDtorDeclarations *)&esharedctorgates, "__modsharedctor");
        m->sshareddtor = callFuncsAndGates(m, &sshareddtors, NULL, "__modshareddtor");
        m->stest = callFuncsAndGates(m, &stests, NULL, "__modtest");

        if (m->doppelganger)
            genModuleInfo(m);
    }

    if (m->doppelganger)
    {
        objmod->termfile();
        return;
    }

    /* Always generate module info, because of templates and -cov.
     * But module info needs the runtime library, so disable it for betterC.
     */
    if (!global.params.betterC /*|| needModuleInfo()*/)
        genModuleInfo(m);

    /* Always generate helper functions b/c of later templates instantiations
     * with different -release/-debug/-boundscheck/-unittest flags.
     */
    if (!global.params.betterC)
        genhelpers(m);

    objmod->termfile();
}

static void genhelpers(Module *m)
{
    // If module assert
    for (int i = 0; i < 3; i++)
    {
        Symbol *ma;
        unsigned rt;
        unsigned bc;
        switch (i)
        {
            case 0:     ma = toModuleArray(m);    rt = RTLSYM_DARRAY;     bc = BCexit; break;
            case 1:     ma = toModuleAssert(m);   rt = RTLSYM_DASSERT;    bc = BCexit; break;
            case 2:     ma = toModuleUnittest(m); rt = RTLSYM_DUNITTEST;  bc = BCret;  break;
            default:    assert(0);
        }

        if (!ma)
            continue;


        localgot = NULL;

        // Call dassert(filename, line)
        // Get sole parameter, linnum
        Symbol *sp = symbol_calloc("linnum");
        sp->Stype = type_fake(TYint);
        sp->Stype->Tcount++;
        sp->Sclass = (config.exe == EX_WIN64) ? SCshadowreg : SCfastpar;

        FuncParamRegs fpr(TYjfunc);
        fpr.alloc(sp->Stype, sp->Stype->Tty, &sp->Spreg, &sp->Spreg2);

        sp->Sflags &= ~SFLspill;
        sp->Sfl = (sp->Sclass == SCshadowreg) ? FLpara : FLfast;
        cstate.CSpsymtab = &ma->Sfunc->Flocsym;
        symbol_add(sp);

        elem *elinnum = el_var(sp);


        elem *efilename = toEfilename(m);
        if (config.exe == EX_WIN64)
            efilename = addressElem(efilename, Type::tstring, true);

        elem *e = el_var(getRtlsym(rt));
        e = el_bin(OPcall, TYvoid, e, el_param(elinnum, efilename));

        block *b = block_calloc();
        b->BC = bc;
        b->Belem = e;
        ma->Sfunc->Fstartline.Sfilename = m->arg;
        ma->Sfunc->Fstartblock = b;
        ma->Sclass = SCglobal;
        ma->Sfl = 0;
        ma->Sflags |= getRtlsym(rt)->Sflags & SFLexit;
        writefunc(ma);
    }
}

/**************************************
 * Search for a druntime array op
 */
bool isDruntimeArrayOp(Identifier *ident)
{
    /* Some of the array op functions are written as library functions,
     * presumably to optimize them with special CPU vector instructions.
     * List those library functions here, in alpha order.
     */
    static const char *libArrayopFuncs[] =
    {
        "_arrayExpSliceAddass_a",
        "_arrayExpSliceAddass_d",
        "_arrayExpSliceAddass_f",           // T[]+=T
        "_arrayExpSliceAddass_g",
        "_arrayExpSliceAddass_h",
        "_arrayExpSliceAddass_i",
        "_arrayExpSliceAddass_k",
        "_arrayExpSliceAddass_s",
        "_arrayExpSliceAddass_t",
        "_arrayExpSliceAddass_u",
        "_arrayExpSliceAddass_w",

        "_arrayExpSliceDivass_d",           // T[]/=T
        "_arrayExpSliceDivass_f",           // T[]/=T

        "_arrayExpSliceMinSliceAssign_a",
        "_arrayExpSliceMinSliceAssign_d",   // T[]=T-T[]
        "_arrayExpSliceMinSliceAssign_f",   // T[]=T-T[]
        "_arrayExpSliceMinSliceAssign_g",
        "_arrayExpSliceMinSliceAssign_h",
        "_arrayExpSliceMinSliceAssign_i",
        "_arrayExpSliceMinSliceAssign_k",
        "_arrayExpSliceMinSliceAssign_s",
        "_arrayExpSliceMinSliceAssign_t",
        "_arrayExpSliceMinSliceAssign_u",
        "_arrayExpSliceMinSliceAssign_w",

        "_arrayExpSliceMinass_a",
        "_arrayExpSliceMinass_d",           // T[]-=T
        "_arrayExpSliceMinass_f",           // T[]-=T
        "_arrayExpSliceMinass_g",
        "_arrayExpSliceMinass_h",
        "_arrayExpSliceMinass_i",
        "_arrayExpSliceMinass_k",
        "_arrayExpSliceMinass_s",
        "_arrayExpSliceMinass_t",
        "_arrayExpSliceMinass_u",
        "_arrayExpSliceMinass_w",

        "_arrayExpSliceMulass_d",           // T[]*=T
        "_arrayExpSliceMulass_f",           // T[]*=T
        "_arrayExpSliceMulass_i",
        "_arrayExpSliceMulass_k",
        "_arrayExpSliceMulass_s",
        "_arrayExpSliceMulass_t",
        "_arrayExpSliceMulass_u",
        "_arrayExpSliceMulass_w",

        "_arraySliceExpAddSliceAssign_a",
        "_arraySliceExpAddSliceAssign_d",   // T[]=T[]+T
        "_arraySliceExpAddSliceAssign_f",   // T[]=T[]+T
        "_arraySliceExpAddSliceAssign_g",
        "_arraySliceExpAddSliceAssign_h",
        "_arraySliceExpAddSliceAssign_i",
        "_arraySliceExpAddSliceAssign_k",
        "_arraySliceExpAddSliceAssign_s",
        "_arraySliceExpAddSliceAssign_t",
        "_arraySliceExpAddSliceAssign_u",
        "_arraySliceExpAddSliceAssign_w",

        "_arraySliceExpDivSliceAssign_d",   // T[]=T[]/T
        "_arraySliceExpDivSliceAssign_f",   // T[]=T[]/T

        "_arraySliceExpMinSliceAssign_a",
        "_arraySliceExpMinSliceAssign_d",   // T[]=T[]-T
        "_arraySliceExpMinSliceAssign_f",   // T[]=T[]-T
        "_arraySliceExpMinSliceAssign_g",
        "_arraySliceExpMinSliceAssign_h",
        "_arraySliceExpMinSliceAssign_i",
        "_arraySliceExpMinSliceAssign_k",
        "_arraySliceExpMinSliceAssign_s",
        "_arraySliceExpMinSliceAssign_t",
        "_arraySliceExpMinSliceAssign_u",
        "_arraySliceExpMinSliceAssign_w",

        "_arraySliceExpMulSliceAddass_d",   // T[] += T[]*T
        "_arraySliceExpMulSliceAddass_f",
        "_arraySliceExpMulSliceAddass_r",

        "_arraySliceExpMulSliceAssign_d",   // T[]=T[]*T
        "_arraySliceExpMulSliceAssign_f",   // T[]=T[]*T
        "_arraySliceExpMulSliceAssign_i",
        "_arraySliceExpMulSliceAssign_k",
        "_arraySliceExpMulSliceAssign_s",
        "_arraySliceExpMulSliceAssign_t",
        "_arraySliceExpMulSliceAssign_u",
        "_arraySliceExpMulSliceAssign_w",

        "_arraySliceExpMulSliceMinass_d",   // T[] -= T[]*T
        "_arraySliceExpMulSliceMinass_f",
        "_arraySliceExpMulSliceMinass_r",

        "_arraySliceSliceAddSliceAssign_a",
        "_arraySliceSliceAddSliceAssign_d", // T[]=T[]+T[]
        "_arraySliceSliceAddSliceAssign_f", // T[]=T[]+T[]
        "_arraySliceSliceAddSliceAssign_g",
        "_arraySliceSliceAddSliceAssign_h",
        "_arraySliceSliceAddSliceAssign_i",
        "_arraySliceSliceAddSliceAssign_k",
        "_arraySliceSliceAddSliceAssign_r", // T[]=T[]+T[]
        "_arraySliceSliceAddSliceAssign_s",
        "_arraySliceSliceAddSliceAssign_t",
        "_arraySliceSliceAddSliceAssign_u",
        "_arraySliceSliceAddSliceAssign_w",

        "_arraySliceSliceAddass_a",
        "_arraySliceSliceAddass_d",         // T[]+=T[]
        "_arraySliceSliceAddass_f",         // T[]+=T[]
        "_arraySliceSliceAddass_g",
        "_arraySliceSliceAddass_h",
        "_arraySliceSliceAddass_i",
        "_arraySliceSliceAddass_k",
        "_arraySliceSliceAddass_s",
        "_arraySliceSliceAddass_t",
        "_arraySliceSliceAddass_u",
        "_arraySliceSliceAddass_w",

        "_arraySliceSliceMinSliceAssign_a",
        "_arraySliceSliceMinSliceAssign_d", // T[]=T[]-T[]
        "_arraySliceSliceMinSliceAssign_f", // T[]=T[]-T[]
        "_arraySliceSliceMinSliceAssign_g",
        "_arraySliceSliceMinSliceAssign_h",
        "_arraySliceSliceMinSliceAssign_i",
        "_arraySliceSliceMinSliceAssign_k",
        "_arraySliceSliceMinSliceAssign_r", // T[]=T[]-T[]
        "_arraySliceSliceMinSliceAssign_s",
        "_arraySliceSliceMinSliceAssign_t",
        "_arraySliceSliceMinSliceAssign_u",
        "_arraySliceSliceMinSliceAssign_w",

        "_arraySliceSliceMinass_a",
        "_arraySliceSliceMinass_d",         // T[]-=T[]
        "_arraySliceSliceMinass_f",         // T[]-=T[]
        "_arraySliceSliceMinass_g",
        "_arraySliceSliceMinass_h",
        "_arraySliceSliceMinass_i",
        "_arraySliceSliceMinass_k",
        "_arraySliceSliceMinass_s",
        "_arraySliceSliceMinass_t",
        "_arraySliceSliceMinass_u",
        "_arraySliceSliceMinass_w",

        "_arraySliceSliceMulSliceAssign_d", // T[]=T[]*T[]
        "_arraySliceSliceMulSliceAssign_f", // T[]=T[]*T[]
        "_arraySliceSliceMulSliceAssign_i",
        "_arraySliceSliceMulSliceAssign_k",
        "_arraySliceSliceMulSliceAssign_s",
        "_arraySliceSliceMulSliceAssign_t",
        "_arraySliceSliceMulSliceAssign_u",
        "_arraySliceSliceMulSliceAssign_w",

        "_arraySliceSliceMulass_d",         // T[]*=T[]
        "_arraySliceSliceMulass_f",         // T[]*=T[]
        "_arraySliceSliceMulass_i",
        "_arraySliceSliceMulass_k",
        "_arraySliceSliceMulass_s",
        "_arraySliceSliceMulass_t",
        "_arraySliceSliceMulass_u",
        "_arraySliceSliceMulass_w",
    };
    char *name = ident->toChars();
    int i = binary(name, libArrayopFuncs, sizeof(libArrayopFuncs) / sizeof(char *));
    if (i != -1)
        return true;

#ifdef DEBUG    // Make sure our array is alphabetized
    for (i = 0; i < sizeof(libArrayopFuncs) / sizeof(char *); i++)
    {
        if (strcmp(name, libArrayopFuncs[i]) == 0)
            assert(0);
    }
#endif
    return false;
}

/* ================================================================== */

UnitTestDeclaration *needsDeferredNested(FuncDeclaration *fd)
{
    while (fd && fd->isNested())
    {
        FuncDeclaration *fdp = fd->toParent2()->isFuncDeclaration();
        if (!fdp)
            break;
        if (UnitTestDeclaration *udp = fdp->isUnitTestDeclaration())
            return udp->semanticRun < PASSobj ? udp : NULL;
        fd = fdp;
    }
    return NULL;
}

void FuncDeclaration_toObjFile(FuncDeclaration *fd, bool multiobj)
{
    ClassDeclaration *cd = fd->parent->isClassDeclaration();
    //printf("FuncDeclaration::toObjFile(%p, %s.%s)\n", fd, fd->parent->toChars(), fd->toChars());

    //if (type) printf("type = %s\n", type->toChars());
#if 0
    //printf("line = %d\n", getWhere() / LINEINC);
    EEcontext *ee = env->getEEcontext();
    if (ee->EEcompile == 2)
    {
        if (ee->EElinnum < (getWhere() / LINEINC) ||
            ee->EElinnum > (endwhere / LINEINC)
           )
            return;             // don't compile this function
        ee->EEfunc = toSymbol(this);
    }
#endif

    if (fd->semanticRun >= PASSobj) // if toObjFile() already run
        return;

    if (fd->type && fd->type->ty == Tfunction && ((TypeFunction *)fd->type)->next == NULL)
        return;

    // If errors occurred compiling it, such as bugzilla 6118
    if (fd->type && fd->type->ty == Tfunction && ((TypeFunction *)fd->type)->next->ty == Terror)
        return;

    if (fd->semantic3Errors)
        return;

    if (global.errors)
        return;

    if (!fd->fbody)
        return;

    UnitTestDeclaration *ud = fd->isUnitTestDeclaration();
    if (ud && !global.params.useUnitTests)
        return;

    if (multiobj && !fd->isStaticDtorDeclaration() && !fd->isStaticCtorDeclaration())
    {
        obj_append(fd);
        return;
    }

    if (fd->semanticRun == PASSsemanticdone)
    {
        /* What happened is this function failed semantic3() with errors,
         * but the errors were gagged.
         * Try to reproduce those errors, and then fail.
         */
        fd->error("errors compiling the function");
        return;
    }
    assert(fd->semanticRun == PASSsemantic3done);
    assert(fd->ident != Id::empty);

    for (FuncDeclaration *fd2 = fd; fd2; )
    {
        if (fd2->inNonRoot())
            return;
        if (fd2->isNested())
            fd2 = fd2->toParent2()->isFuncDeclaration();
        else
            break;
    }

    if (UnitTestDeclaration *udp = needsDeferredNested(fd))
    {
        /* Can't do unittest's out of order, they are order dependent in that their
         * execution is done in lexical order.
         */
        udp->deferredNested.push(fd);
        //printf("%s @[%s]\n\t--> pushed to unittest @[%s]\n",
        //    fd->toPrettyChars(), fd->loc.toChars(), udp->loc.toChars());
        return;
    }

    if (fd->isArrayOp && isDruntimeArrayOp(fd->ident))
    {
        // Implementation is in druntime
        return;
    }

    // start code generation
    fd->semanticRun = PASSobj;

    if (global.params.verbose)
        fprintf(global.stdmsg, "function  %s\n", fd->toPrettyChars());

    Symbol *s = toSymbol(fd);
    func_t *f = s->Sfunc;

    // tunnel type of "this" to debug info generation
    if (AggregateDeclaration* ad = fd->parent->isAggregateDeclaration())
    {
        ::type* t = Type_toCtype(ad->getType());
        if (cd)
            t = t->Tnext; // skip reference
        f->Fclass = (Classsym *)t;
    }

    /* This is done so that the 'this' pointer on the stack is the same
     * distance away from the function parameters, so that an overriding
     * function can call the nested fdensure or fdrequire of its overridden function
     * and the stack offsets are the same.
     */
    if (fd->isVirtual() && (fd->fensure || fd->frequire))
        f->Fflags3 |= Ffakeeh;

#if TARGET_OSX
    s->Sclass = SCcomdat;
#else
    s->Sclass = SCglobal;
#endif
    for (Dsymbol *p = fd->parent; p; p = p->parent)
    {
        if (p->isTemplateInstance())
        {
            s->Sclass = SCcomdat;
            break;
        }
    }

    /* Vector operations should be comdat's
     */
    if (fd->isArrayOp)
        s->Sclass = SCcomdat;

    if (fd->inlinedNestedCallees)
    {
        /* Bugzilla 15333: If fd contains inlined expressions that come from
         * nested function bodies, the enclosing of the functions must be
         * generated first, in order to calculate correct frame pointer offset.
         */
        for (size_t i = 0; i < fd->inlinedNestedCallees->dim; i++)
        {
            FuncDeclaration *f = (*fd->inlinedNestedCallees)[i];
            FuncDeclaration *fp = f->toParent2()->isFuncDeclaration();;
            if (fp && fp->semanticRun < PASSobj)
            {
                toObjFile(fp, multiobj);
            }
        }
    }

    if (fd->isNested())
    {
        //if (!(config.flags3 & CFG3pic))
        //    s->Sclass = SCstatic;
        f->Fflags3 |= Fnested;

        /* The enclosing function must have its code generated first,
         * in order to calculate correct frame pointer offset.
         */
        FuncDeclaration *fdp = fd->toParent2()->isFuncDeclaration();
        if (fdp && fdp->semanticRun < PASSobj)
        {
            toObjFile(fdp, multiobj);
        }
    }
    else
    {
        const char *libname = (global.params.symdebug)
                                ? global.params.debuglibname
                                : global.params.defaultlibname;

        // Pull in RTL startup code (but only once)
        if (fd->isMain() && onlyOneMain(fd->loc))
        {
#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
            objmod->external_def("_main");
            objmod->ehsections();   // initialize exception handling sections
#endif
            if (global.params.mscoff)
            {
                objmod->external_def("main");
                objmod->ehsections();   // initialize exception handling sections
            }
            else if (config.exe == EX_WIN32)
            {
                objmod->external_def("_main");
                objmod->external_def("__acrtused_con");
            }
            objmod->includelib(libname);
            s->Sclass = SCglobal;
        }
        else if (strcmp(s->Sident, "main") == 0 && fd->linkage == LINKc)
        {
            if (global.params.mscoff)
            {
                objmod->includelib("LIBCMT");
                objmod->includelib("OLDNAMES");
            }
            else if (config.exe == EX_WIN32)
            {
                objmod->external_def("__acrtused_con");        // bring in C startup code
                objmod->includelib("snn.lib");          // bring in C runtime library
            }
            s->Sclass = SCglobal;
        }
#if TARGET_WINDOS
        else if (fd->isWinMain() && onlyOneMain(fd->loc))
        {
            if (global.params.mscoff)
            {
                objmod->includelib("uuid");
                objmod->includelib("LIBCMT");
                objmod->includelib("OLDNAMES");
                objmod->ehsections();   // initialize exception handling sections
            }
            else
            {
                objmod->external_def("__acrtused");
            }
            objmod->includelib(libname);
            s->Sclass = SCglobal;
        }

        // Pull in RTL startup code
        else if (fd->isDllMain() && onlyOneMain(fd->loc))
        {
            if (global.params.mscoff)
            {
                objmod->includelib("uuid");
                objmod->includelib("LIBCMT");
                objmod->includelib("OLDNAMES");
                objmod->ehsections();   // initialize exception handling sections
            }
            else
            {
                objmod->external_def("__acrtused_dll");
            }
            objmod->includelib(libname);
            s->Sclass = SCglobal;
        }
#endif
    }

    symtab_t *symtabsave = cstate.CSpsymtab;
    cstate.CSpsymtab = &f->Flocsym;

    // Find module m for this function
    Module *m = NULL;
    for (Dsymbol *p = fd->parent; p; p = p->parent)
    {
        m = p->isModule();
        if (m)
            break;
    }

    IRState irs(m, fd);
    Dsymbols deferToObj;                   // write these to OBJ file later
    irs.deferToObj = &deferToObj;
    void *labels = NULL;
    irs.labels = &labels;

    symbol *shidden = NULL;
    Symbol *sthis = NULL;
    tym_t tyf = tybasic(s->Stype->Tty);
    //printf("linkage = %d, tyf = x%x\n", linkage, tyf);
    int reverse = tyrevfunc(s->Stype->Tty);

    assert(fd->type->ty == Tfunction);
    TypeFunction *tf = (TypeFunction *)fd->type;
    RET retmethod = retStyle(tf);
    if (retmethod == RETstack)
    {
        // If function returns a struct, put a pointer to that
        // as the first argument
        ::type *thidden = Type_toCtype(tf->next->pointerTo());
        char hiddenparam[5+4+1];
        static int hiddenparami;    // how many we've generated so far

        sprintf(hiddenparam,"__HID%d",++hiddenparami);
        shidden = symbol_name(hiddenparam,SCparameter,thidden);
        shidden->Sflags |= SFLtrue | SFLfree;
        if (fd->nrvo_can && fd->nrvo_var && fd->nrvo_var->nestedrefs.dim)
            type_setcv(&shidden->Stype, shidden->Stype->Tty | mTYvolatile);
        irs.shidden = shidden;
        fd->shidden = shidden;
    }
    else
    {
        // Register return style cannot make nrvo.
        // Auto functions keep the nrvo_can flag up to here,
        // so we should eliminate it before entering backend.
        fd->nrvo_can = 0;
    }

    if (fd->vthis)
    {
        assert(!fd->vthis->csym);
        sthis = toSymbol(fd->vthis);
        irs.sthis = sthis;
        if (!(f->Fflags3 & Fnested))
            f->Fflags3 |= Fmember;
    }

    // Estimate number of parameters, pi
    size_t pi = (fd->v_arguments != NULL);
    if (fd->parameters)
        pi += fd->parameters->dim;

    // Create a temporary buffer, params[], to hold function parameters
    Symbol *paramsbuf[10];
    Symbol **params = paramsbuf;    // allocate on stack if possible
    if (pi + 2 > 10)                // allow extra 2 for sthis and shidden
    {
        params = (Symbol **)malloc((pi + 2) * sizeof(Symbol *));
        assert(params);
    }

    // Get the actual number of parameters, pi, and fill in the params[]
    pi = 0;
    if (fd->v_arguments)
    {
        params[pi] = toSymbol(fd->v_arguments);
        pi += 1;
    }
    if (fd->parameters)
    {
        for (size_t i = 0; i < fd->parameters->dim; i++)
        {
            VarDeclaration *v = (*fd->parameters)[i];
            //printf("param[%d] = %p, %s\n", i, v, v->toChars());
            assert(!v->csym);
            params[pi + i] = toSymbol(v);
        }
        pi += fd->parameters->dim;
    }

    if (reverse)
    {
        // Reverse params[] entries
        for (size_t i = 0; i < pi/2; i++)
        {
            Symbol *sptmp = params[i];
            params[i] = params[pi - 1 - i];
            params[pi - 1 - i] = sptmp;
        }
    }

    if (shidden)
    {
#if 0
        // shidden becomes last parameter
        params[pi] = shidden;
#else
        // shidden becomes first parameter
        memmove(params + 1, params, pi * sizeof(params[0]));
        params[0] = shidden;
#endif
        pi++;
    }


    if (sthis)
    {
#if 0
        // sthis becomes last parameter
        params[pi] = sthis;
#else
        // sthis becomes first parameter
        memmove(params + 1, params, pi * sizeof(params[0]));
        params[0] = sthis;
#endif
        pi++;
    }

    if ((global.params.isLinux || global.params.isOSX || global.params.isFreeBSD || global.params.isSolaris) &&
         fd->linkage != LINKd && shidden && sthis)
    {
        /* swap shidden and sthis
         */
        Symbol *sp = params[0];
        params[0] = params[1];
        params[1] = sp;
    }

    for (size_t i = 0; i < pi; i++)
    {
        Symbol *sp = params[i];
        sp->Sclass = SCparameter;
        sp->Sflags &= ~SFLspill;
        sp->Sfl = FLpara;
        symbol_add(sp);
    }

    // Determine register assignments
    if (pi)
    {
        FuncParamRegs fpr(tyf);

        for (size_t i = 0; i < pi; i++)
        {
            Symbol *sp = params[i];
            if (fpr.alloc(sp->Stype, sp->Stype->Tty, &sp->Spreg, &sp->Spreg2))
            {
                sp->Sclass = (config.exe == EX_WIN64) ? SCshadowreg : SCfastpar;
                sp->Sfl = (sp->Sclass == SCshadowreg) ? FLpara : FLfast;
            }
        }
    }

    // Done with params
    if (params != paramsbuf)
        free(params);
    params = NULL;

    if (fd->fbody)
    {
        localgot = NULL;

        Statement *sbody = fd->fbody;

        Blockx bx;
        memset(&bx,0,sizeof(bx));
        bx.startblock = block_calloc();
        bx.curblock = bx.startblock;
        bx.funcsym = s;
        bx.scope_index = -1;
        bx.classdec = cd;
        bx.member = fd;
        bx.module = fd->getModule();
        irs.blx = &bx;

        /* Doing this in semantic3() caused all kinds of problems:
         * 1. couldn't reliably get the final mangling of the function name due to fwd refs
         * 2. impact on function inlining
         * 3. what to do when writing out .di files, or other pretty printing
         */
        if (global.params.trace && !fd->isCMain())
        {
            /* The profiler requires TLS, and TLS may not be set up yet when C main()
             * gets control (i.e. OSX), leading to a crash.
             */
            /* Wrap the entire function body in:
             *   trace_pro("funcname");
             *   try
             *     body;
             *   finally
             *     _c_trace_epi();
             */
            StringExp *se = StringExp::create(Loc(), s->Sident);
            se->type = Type::tstring;
            se->type = se->type->semantic(Loc(), NULL);
            Expressions *exps = Expressions_create();
            exps->push(se);
            FuncDeclaration *fdpro = FuncDeclaration::genCfunc(NULL, Type::tvoid, "trace_pro");
            Expression *ec = VarExp::create(Loc(), fdpro);
            Expression *e = CallExp::create(Loc(), ec, exps);
            e->type = Type::tvoid;
            Statement *sp = ExpStatement::create(fd->loc, e);

            FuncDeclaration *fdepi = FuncDeclaration::genCfunc(NULL, Type::tvoid, "_c_trace_epi");
            ec = VarExp::create(Loc(), fdepi);
            e = CallExp::create(Loc(), ec);
            e->type = Type::tvoid;
            Statement *sf = ExpStatement::create(fd->loc, e);

            Statement *stf;
            if (sbody->blockExit(fd, false) == BEfallthru)
                stf = CompoundStatement::create(Loc(), sbody, sf);
            else
                stf = TryFinallyStatement::create(Loc(), sbody, sf);
            sbody = CompoundStatement::create(Loc(), sp, stf);
        }

        if (fd->interfaceVirtual)
        {
            // Adjust the 'this' pointer instead of using a thunk
            assert(irs.sthis);
            elem *ethis = el_var(irs.sthis);
            elem *e = el_bin(OPminass, TYnptr, ethis, el_long(TYsize_t, fd->interfaceVirtual->offset));
            block_appendexp(irs.blx->curblock, e);
        }

        buildClosure(fd, &irs);

        if (config.ehmethod == EH_WIN32 && fd->isSynchronized() && cd &&
            !fd->isStatic() && !sbody->usesEH() && !global.params.trace)
        {
            /* The "jmonitor" hack uses an optimized exception handling frame
             * which is a little shorter than the more general EH frame.
             */
            s->Sfunc->Fflags3 |= Fjmonitor;
        }

        Statement_toIR(sbody, &irs);
        bx.curblock->BC = BCret;

        f->Fstartblock = bx.startblock;
//      einit = el_combine(einit,bx.init);

        if (fd->isCtorDeclaration())
        {
            assert(sthis);
            for (block *b = f->Fstartblock; b; b = b->Bnext)
            {
                if (b->BC == BCret)
                {
                    b->BC = BCretexp;
                    b->Belem = el_combine(b->Belem, el_var(sthis));
                }
            }
        }
        insertFinallyBlockCalls(f->Fstartblock);
    }

    // If static constructor
    if (fd->isSharedStaticCtorDeclaration())        // must come first because it derives from StaticCtorDeclaration
    {
        ssharedctors.push(s);
    }
    else if (fd->isStaticCtorDeclaration())
    {
        sctors.push(s);
    }

    // If static destructor
    if (fd->isSharedStaticDtorDeclaration())        // must come first because it derives from StaticDtorDeclaration
    {
        SharedStaticDtorDeclaration *f = fd->isSharedStaticDtorDeclaration();
        assert(f);
        if (f->vgate)
        {
            /* Increment destructor's vgate at construction time
             */
            esharedctorgates.push(f);
        }

        sshareddtors.shift(s);
    }
    else if (fd->isStaticDtorDeclaration())
    {
        StaticDtorDeclaration *f = fd->isStaticDtorDeclaration();
        assert(f);
        if (f->vgate)
        {
            /* Increment destructor's vgate at construction time
             */
            ectorgates.push(f);
        }

        sdtors.shift(s);
    }

    // If unit test
    if (ud)
    {
        stests.push(s);
    }

    if (global.errors)
    {
        // Restore symbol table
        cstate.CSpsymtab = symtabsave;
        return;
    }

    writefunc(s);
    // Restore symbol table
    cstate.CSpsymtab = symtabsave;

    if (fd->isExport())
        objmod->export_symbol(s, Para.offset);

    for (size_t i = 0; i < irs.deferToObj->dim; i++)
    {
        Dsymbol *s = (*irs.deferToObj)[i];
        toObjFile(s, false);
    }

    if (ud)
    {
        for (size_t i = 0; i < ud->deferredNested.dim; i++)
        {
            FuncDeclaration *fd = ud->deferredNested[i];
            toObjFile(fd, false);
        }
    }

#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
    // A hack to get a pointer to this function put in the .dtors segment
    if (fd->ident && memcmp(fd->ident->toChars(), "_STD", 4) == 0)
        objmod->staticdtor(s);
#endif
    if (irs.startaddress)
    {
        //printf("Setting start address\n");
        objmod->startaddress(irs.startaddress);
    }
}

bool onlyOneMain(Loc loc)
{
    static Loc lastLoc;
    static bool hasMain = false;
    if (hasMain)
    {
        const char *msg = "";
        if (global.params.addMain)
            msg = ", -main switch added another main()";
        const char *othermain = "";
        if (config.exe == EX_WIN32 || config.exe == EX_WIN64)
            othermain = "/WinMain/DllMain";
        error(lastLoc, "only one main%s allowed%s", othermain, msg);
        return false;
    }
    lastLoc = loc;
    hasMain = true;
    return true;
}

/* ================================================================== */

/*****************************
 * Return back end type corresponding to D front end type.
 */

unsigned totym(Type *tx)
{
    unsigned t;
    switch (tx->ty)
    {
        case Tvoid:     t = TYvoid;     break;
        case Tint8:     t = TYschar;    break;
        case Tuns8:     t = TYuchar;    break;
        case Tint16:    t = TYshort;    break;
        case Tuns16:    t = TYushort;   break;
        case Tint32:    t = TYint;      break;
        case Tuns32:    t = TYuint;     break;
        case Tint64:    t = TYllong;    break;
        case Tuns64:    t = TYullong;   break;
        case Tfloat32:  t = TYfloat;    break;
        case Tfloat64:  t = TYdouble;   break;
        case Tfloat80:  t = TYldouble;  break;
        case Timaginary32: t = TYifloat; break;
        case Timaginary64: t = TYidouble; break;
        case Timaginary80: t = TYildouble; break;
        case Tcomplex32: t = TYcfloat;  break;
        case Tcomplex64: t = TYcdouble; break;
        case Tcomplex80: t = TYcldouble; break;
        case Tbool:     t = TYbool;     break;
        case Tchar:     t = TYchar;     break;
        case Twchar:    t = TYwchar_t;  break;
#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
        case Tdchar:    t = TYdchar;    break;
#else
        case Tdchar:
            t = (global.params.symdebug == 1) ? TYdchar : TYulong;
            break;
#endif

        case Taarray:   t = TYaarray;   break;
        case Tclass:
        case Treference:
        case Tpointer:  t = TYnptr;     break;
        case Tdelegate: t = TYdelegate; break;
        case Tarray:    t = TYdarray;   break;
        case Tsarray:   t = TYstruct;   break;

        case Tstruct:
            t = TYstruct;
            if (tx->toDsymbol(NULL)->ident == Id::__c_long_double)
                t = TYdouble;
            break;

        case Tenum:
            t = totym(tx->toBasetype());
            break;

        case Tident:
        case Ttypeof:
#ifdef DEBUG
            printf("ty = %d, '%s'\n", tx->ty, tx->toChars());
#endif
            error(Loc(), "forward reference of %s", tx->toChars());
            t = TYint;
            break;

        case Tnull:
            t = TYnptr;
            break;

        case Tvector:
        {
            TypeVector *tv = (TypeVector *)tx;
            TypeBasic *tb = tv->elementType();
            switch (tb->ty)
            {
                case Tvoid:
                case Tint8:     t = TYschar16;  break;
                case Tuns8:     t = TYuchar16;  break;
                case Tint16:    t = TYshort8;   break;
                case Tuns16:    t = TYushort8;  break;
                case Tint32:    t = TYlong4;    break;
                case Tuns32:    t = TYulong4;   break;
                case Tint64:    t = TYllong2;   break;
                case Tuns64:    t = TYullong2;  break;
                case Tfloat32:  t = TYfloat4;   break;
                case Tfloat64:  t = TYdouble2;  break;
                default:
                    assert(0);
                    break;
            }
            assert(global.params.is64bit || global.params.isOSX);
            break;
        }

        case Tfunction:
        {
            TypeFunction *tf = (TypeFunction *)tx;
            switch (tf->linkage)
            {
                case LINKwindows:
                    if (global.params.is64bit)
                        goto Lc;
                    t = (tf->varargs == 1) ? TYnfunc : TYnsfunc;
                    break;

                case LINKpascal:
                    t = (tf->varargs == 1) ? TYnfunc : TYnpfunc;
                    break;

                case LINKc:
                case LINKcpp:
                case LINKobjc:
                Lc:
                    t = TYnfunc;
#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
                    if (I32 && retStyle(tf) == RETstack)
                        t = TYhfunc;
#endif
                    break;

                case LINKd:
                    t = (tf->varargs == 1) ? TYnfunc : TYjfunc;
                    break;

                default:
                    printf("linkage = %d\n", tf->linkage);
                    assert(0);
            }
            if (tf->isnothrow)
                t |= mTYnothrow;
            return t;
        }
        default:
#ifdef DEBUG
            printf("ty = %d, '%s'\n", tx->ty, tx->toChars());
            halt();
#endif
            assert(0);
    }

    // Add modifiers
    switch (tx->mod)
    {
        case 0:
            break;
        case MODconst:
        case MODwild:
        case MODwildconst:
            t |= mTYconst;
            break;
        case MODshared:
            t |= mTYshared;
            break;
        case MODshared | MODconst:
        case MODshared | MODwild:
        case MODshared | MODwildconst:
            t |= mTYshared | mTYconst;
            break;
        case MODimmutable:
            t |= mTYimmutable;
            break;
        default:
            assert(0);
    }

    return t;
}

/**************************************
 */

Symbol *toSymbol(Type *t)
{
    if (t->ty == Tclass)
    {
        return toSymbol(((TypeClass *)t)->sym);
    }
    assert(0);
    return NULL;
}

/**************************************
 * Generate elem that is a dynamic array slice of the module file name.
 */

elem *toEfilename(Module *m)
{
    //printf("toEfilename(%s)\n", m->toChars());
    const char *id = m->srcfile->toChars();
    size_t len = strlen(id);

    if (!m->sfilename)
    {
        // Put out as a static array
        m->sfilename = toStringSymbol(id, len, 1);
    }

    // Turn static array into dynamic array
    return el_pair(TYdarray, el_long(TYsize_t, len), el_ptr(m->sfilename));
}

        void testOffsets()
        {
        assert(offsetof(Dsymbol, ident) == 4);
    assert(offsetof(Dsymbol, parent) == 8);
    assert(offsetof(Dsymbol, csym) == 12);
    assert(offsetof(Dsymbol, isym) == 16);
    assert(offsetof(Dsymbol, comment) == 20);
    assert(offsetof(Loc, filename) == 0);
    assert(offsetof(Loc, linnum) == 4);
    assert(offsetof(Loc, charnum) == 8);
    assert(sizeof(Loc) == 12);
    assert(offsetof(Dsymbol, loc) == 24);
    assert(offsetof(Dsymbol, _scope) == 36);
    assert(offsetof(Dsymbol, prettystring) == 40);
    assert(offsetof(Dsymbol, errors) == 44);
    assert(offsetof(Dsymbol, semanticRun) == 48);
    assert(offsetof(Dsymbol, depdecl) == 52);
    assert(offsetof(Dsymbol, userAttribDecl) == 56);
    assert(offsetof(Dsymbol, ddocUnittest) == 60);
    assert(offsetof(ScopeDsymbol, members) == 64);
    assert(offsetof(ScopeDsymbol, symtab) == 68);
    assert(offsetof(ScopeDsymbol, importedScopes) == 72);
    assert(offsetof(ScopeDsymbol, prots) == 76);
    assert(offsetof(ScopeDsymbol, accessiblePackages) == 80);
    assert(offsetof(AggregateDeclaration, type) == 88);
    assert(offsetof(AggregateDeclaration, storage_class) == 96);
    assert(offsetof(Prot, kind) == 0);
    assert(offsetof(Prot, pkg) == 4);
    assert(sizeof(Prot) == 8);
    assert(offsetof(AggregateDeclaration, protection) == 104);
    assert(offsetof(AggregateDeclaration, structsize) == 112);
    assert(offsetof(AggregateDeclaration, alignsize) == 116);
    assert(offsetof(AggregateDeclaration, fields) == 120);
    assert(offsetof(AggregateDeclaration, sizeok) == 136);
    assert(offsetof(AggregateDeclaration, deferred) == 140);
    assert(offsetof(AggregateDeclaration, isdeprecated) == 144);
    assert(offsetof(AggregateDeclaration, enclosing) == 148);
    assert(offsetof(AggregateDeclaration, vthis) == 152);
    assert(offsetof(AggregateDeclaration, invs) == 156);
    assert(offsetof(AggregateDeclaration, inv) == 172);
    assert(offsetof(AggregateDeclaration, aggNew) == 176);
    assert(offsetof(AggregateDeclaration, aggDelete) == 180);
    assert(offsetof(AggregateDeclaration, ctor) == 184);
    assert(offsetof(AggregateDeclaration, defaultCtor) == 188);
    assert(offsetof(AggregateDeclaration, aliasthis) == 192);
    assert(offsetof(AggregateDeclaration, noDefaultCtor) == 196);
    assert(offsetof(AggregateDeclaration, dtors) == 200);
    assert(offsetof(AggregateDeclaration, dtor) == 216);
    assert(offsetof(AggregateDeclaration, getRTInfo) == 220);
    assert(offsetof(AggregateDeclaration, stag) == 224);
    assert(offsetof(AggregateDeclaration, sinit) == 228);
    assert(offsetof(AliasThis, ident) == 64);
    assert(offsetof(StoppableVisitor, stop) == 4);
    // assert(offsetof(PostorderExpressionVisitor, v) == 8);
    assert(offsetof(AttribDeclaration, decl) == 64);
    assert(offsetof(StorageClassDeclaration, stc) == 72);
    assert(offsetof(DeprecatedDeclaration, msg) == 80);
    printf("%p\n", offsetof(DeprecatedDeclaration, msgstr));
    assert(offsetof(DeprecatedDeclaration, msgstr) == 84);
    assert(offsetof(LinkDeclaration, linkage) == 68);
    assert(offsetof(ProtDeclaration, protection) == 68);
    assert(offsetof(ProtDeclaration, pkg_identifiers) == 76);
    assert(offsetof(AlignDeclaration, salign) == 68);
    assert(offsetof(AnonDeclaration, isunion) == 68);
    assert(offsetof(AnonDeclaration, alignment) == 72);
    assert(offsetof(AnonDeclaration, sem) == 76);
    assert(offsetof(AnonDeclaration, anonoffset) == 80);
    assert(offsetof(AnonDeclaration, anonstructsize) == 84);
    assert(offsetof(AnonDeclaration, anonalignsize) == 88);
    assert(offsetof(PragmaDeclaration, args) == 68);
    assert(offsetof(ConditionalDeclaration, condition) == 68);
    assert(offsetof(ConditionalDeclaration, elsedecl) == 72);
    assert(offsetof(StaticIfDeclaration, scopesym) == 76);
    assert(offsetof(StaticIfDeclaration, addisdone) == 80);
    assert(offsetof(CompileDeclaration, exp) == 68);
    assert(offsetof(CompileDeclaration, scopesym) == 72);
    assert(offsetof(CompileDeclaration, compiled) == 76);
    assert(offsetof(UserAttributeDeclaration, atts) == 68);
    assert(offsetof(complex_t, re) == 0);
    assert(offsetof(complex_t, im) == 10);
    assert(sizeof(complex_t) == 20);
    assert(offsetof(Condition, loc) == 4);
    assert(offsetof(Condition, inc) == 16);
    assert(offsetof(DVCondition, level) == 20);
    assert(offsetof(DVCondition, ident) == 24);
    assert(offsetof(DVCondition, mod) == 28);
    assert(offsetof(StaticIfCondition, exp) == 20);
    assert(offsetof(StaticIfCondition, nest) == 24);
    assert(sizeof(CtfeStatus) == 1);
    assert(offsetof(Expression, loc) == 4);
    assert(offsetof(Expression, type) == 16);
    assert(offsetof(Expression, op) == 20);
    assert(offsetof(Expression, size) == 24);
    assert(offsetof(Expression, parens) == 25);
    assert(offsetof(ClassReferenceExp, value) == 28);
    assert(offsetof(VoidInitExp, var) == 28);
    assert(offsetof(ThrownExceptionExp, thrown) == 28);
    assert(offsetof(BaseClass, type) == 0);
    assert(offsetof(BaseClass, sym) == 4);
    assert(offsetof(BaseClass, offset) == 8);
    assert(offsetof(BaseClass, vtbl) == 12);
    assert(offsetof(BaseClass, baseInterfaces) == 28);
    assert(sizeof(BaseClass) == 36);
    assert(sizeof(ClassFlags) == 1);
    assert(offsetof(ClassDeclaration, baseClass) == 232);
    assert(offsetof(ClassDeclaration, staticCtor) == 236);
    assert(offsetof(ClassDeclaration, staticDtor) == 240);
    assert(offsetof(ClassDeclaration, vtbl) == 244);
    assert(offsetof(ClassDeclaration, vtblFinal) == 260);
    assert(offsetof(ClassDeclaration, baseclasses) == 276);
    assert(offsetof(ClassDeclaration, interfaces) == 280);
    assert(offsetof(ClassDeclaration, vtblInterfaces) == 288);
    assert(offsetof(ClassDeclaration, vclassinfo) == 292);
    assert(offsetof(ClassDeclaration, com) == 296);
    assert(offsetof(ClassDeclaration, cpp) == 297);
    assert(offsetof(ClassDeclaration, isscope) == 298);
    assert(offsetof(ClassDeclaration, isabstract) == 300);
    assert(offsetof(ClassDeclaration, inuse) == 304);
    assert(offsetof(ClassDeclaration, baseok) == 308);
    assert(offsetof(Objc_ClassDeclaration, objc) == 0);
    assert(sizeof(Objc_ClassDeclaration) == 1);
    assert(offsetof(ClassDeclaration, objc) == 312);
    assert(offsetof(ClassDeclaration, cpp_type_info_ptr_sym) == 316);
    assert(offsetof(ClassDeclaration, vtblsym) == 320);
    assert(offsetof(Match, count) == 0);
    assert(offsetof(Match, last) == 4);
    assert(offsetof(Match, lastf) == 8);
    assert(offsetof(Match, nextf) == 12);
    assert(offsetof(Match, anyf) == 16);
    assert(sizeof(Match) == 20);
    assert(offsetof(Declaration, type) == 64);
    assert(offsetof(Declaration, originalType) == 68);
    assert(offsetof(Declaration, storage_class) == 72);
    assert(offsetof(Declaration, protection) == 80);
    assert(offsetof(Declaration, linkage) == 88);
    assert(offsetof(Declaration, inuse) == 92);
    assert(offsetof(Declaration, mangleOverride) == 96);
    assert(offsetof(TupleDeclaration, objects) == 104);
    assert(offsetof(TupleDeclaration, isexp) == 108);
    assert(offsetof(TupleDeclaration, tupletype) == 112);
    assert(offsetof(AliasDeclaration, aliassym) == 104);
    assert(offsetof(AliasDeclaration, overnext) == 108);
    assert(offsetof(AliasDeclaration, _import) == 112);
    assert(offsetof(OverDeclaration, overnext) == 104);
    assert(offsetof(OverDeclaration, aliassym) == 108);
    assert(offsetof(OverDeclaration, hasOverloads) == 112);
    assert(offsetof(VarDeclaration, _init) == 104);
    assert(offsetof(VarDeclaration, offset) == 108);
    assert(offsetof(VarDeclaration, noscope) == 112);
    assert(offsetof(VarDeclaration, nestedrefs) == 116);
    assert(offsetof(VarDeclaration, isargptr) == 132);
    assert(offsetof(VarDeclaration, alignment) == 136);
    assert(offsetof(VarDeclaration, ctorinit) == 140);
    assert(offsetof(VarDeclaration, onstack) == 142);
    assert(offsetof(VarDeclaration, canassign) == 144);
    assert(offsetof(VarDeclaration, overlapped) == 148);
    assert(offsetof(VarDeclaration, aliassym) == 152);
    assert(offsetof(VarDeclaration, lastVar) == 156);
    assert(offsetof(VarDeclaration, ctfeAdrOnStack) == 160);
    assert(offsetof(VarDeclaration, rundtor) == 164);
    assert(offsetof(VarDeclaration, edtor) == 168);
    assert(offsetof(VarDeclaration, range) == 172);
    assert(offsetof(SymbolDeclaration, dsym) == 104);
    assert(offsetof(TypeInfoDeclaration, tinfo) == 176);
    assert(offsetof(EnumDeclaration, type) == 88);
    assert(offsetof(EnumDeclaration, memtype) == 92);
    assert(offsetof(EnumDeclaration, protection) == 96);
    assert(offsetof(EnumDeclaration, maxval) == 104);
    assert(offsetof(EnumDeclaration, minval) == 108);
    assert(offsetof(EnumDeclaration, defaultval) == 112);
    assert(offsetof(EnumDeclaration, isdeprecated) == 116);
    assert(offsetof(EnumDeclaration, added) == 117);
    assert(offsetof(EnumDeclaration, inuse) == 120);
    assert(offsetof(EnumDeclaration, sinit) == 124);
    assert(offsetof(EnumMember, origValue) == 176);
    assert(offsetof(EnumMember, origType) == 180);
    assert(offsetof(EnumMember, ed) == 184);
    assert(offsetof(Import, packages) == 64);
    assert(offsetof(Import, id) == 68);
    assert(offsetof(Import, aliasId) == 72);
    assert(offsetof(Import, isstatic) == 76);
    assert(offsetof(Import, protection) == 80);
    assert(offsetof(Import, names) == 88);
    assert(offsetof(Import, aliases) == 104);
    assert(offsetof(Import, mod) == 120);
    assert(offsetof(Import, pkg) == 124);
    assert(offsetof(Import, aliasdecls) == 128);
    // assert(offsetof(CtfeStack, values) == 0);
    // assert(offsetof(CtfeStack, vars) == 16);
    // assert(offsetof(CtfeStack, savedId) == 32);
    // assert(offsetof(CtfeStack, frames) == 48);
    // assert(offsetof(CtfeStack, savedThis) == 64);
    // assert(offsetof(CtfeStack, globalValues) == 80);
    // assert(offsetof(CtfeStack, framepointer) == 96);
    // assert(offsetof(CtfeStack, maxStackPointer) == 100);
    // assert(offsetof(CtfeStack, localThis) == 104);
    // assert(sizeof(CtfeStack) == 108);
    // assert(offsetof(InterState, caller) == 0);
    // assert(offsetof(InterState, fd) == 4);
    // assert(offsetof(InterState, start) == 8);
    // assert(offsetof(InterState, gotoTarget) == 12);
    // assert(sizeof(InterState) == 16);
    // assert(offsetof(CompiledCtfeFunction, func) == 0);
    // assert(offsetof(CompiledCtfeFunction, numVars) == 4);
    // assert(offsetof(CompiledCtfeFunction, callingloc) == 8);
    // assert(sizeof(CompiledCtfeFunction) == 20);
    // assert(offsetof(CtfeCompiler, ccf) == 4);
    // assert(offsetof(Interpreter, istate) == 4);
    // assert(offsetof(Interpreter, goal) == 8);
    // assert(offsetof(Interpreter, result) == 12);
    assert(offsetof(Macro, next) == 0);
    assert(offsetof(Macro, name) == 4);
    assert(offsetof(Macro, namelen) == 8);
    assert(offsetof(Macro, text) == 12);
    assert(offsetof(Macro, textlen) == 16);
    assert(offsetof(Macro, inuse) == 20);
    assert(sizeof(Macro) == 24);
    // assert(offsetof(Mangler, buf) == 4);
    assert(offsetof(Package, isPkgMod) == 88);
    assert(offsetof(Package, tag) == 92);
    assert(offsetof(Package, mod) == 96);
    assert(offsetof(Module, arg) == 100);
    assert(offsetof(Module, md) == 104);
    assert(offsetof(Module, srcfile) == 108);
    assert(offsetof(Module, objfile) == 112);
    assert(offsetof(Module, hdrfile) == 116);
    assert(offsetof(Module, docfile) == 120);
    // assert(offsetof(Module, cppfile) == 124);
    assert(4+offsetof(Module, errors) == 128);
    assert(4+offsetof(Module, numlines) == 132);
    assert(4+offsetof(Module, isDocFile) == 136);
    assert(4+offsetof(Module, isPackageFile) == 140);
    assert(4+offsetof(Module, needmoduleinfo) == 144);
    assert(4+offsetof(Module, selfimports) == 148);
    assert(4+offsetof(Module, rootimports) == 152);
    assert(4+offsetof(Module, insearch) == 156);
    assert(4+offsetof(Module, searchCacheIdent) == 160);
    assert(4+offsetof(Module, searchCacheSymbol) == 164);
    assert(4+offsetof(Module, searchCacheFlags) == 168);
    assert(4+offsetof(Module, importedFrom) == 172);
    assert(4+offsetof(Module, decldefs) == 176);
    assert(4+offsetof(Module, aimports) == 180);
    assert(4+offsetof(Module, debuglevel) == 196);
    assert(4+offsetof(Module, debugids) == 200);
    assert(4+offsetof(Module, debugidsNot) == 204);
    assert(4+offsetof(Module, versionlevel) == 208);
    assert(4+offsetof(Module, versionids) == 212);
    assert(4+offsetof(Module, versionidsNot) == 216);
    assert(4+offsetof(Module, macrotable) == 220);
    assert(4+offsetof(Module, escapetable) == 224);
    assert(4+offsetof(Module, nameoffset) == 228);
    assert(4+offsetof(Module, namelen) == 232);
    assert(4+offsetof(Module, doppelganger) == 236);
    assert(4+offsetof(Module, cov) == 240);
    assert(4+offsetof(Module, covb) == 244);
    assert(4+offsetof(Module, sictor) == 248);
    assert(4+offsetof(Module, sctor) == 252);
    assert(4+offsetof(Module, sdtor) == 256);
    assert(4+offsetof(Module, ssharedctor) == 260);
    assert(4+offsetof(Module, sshareddtor) == 264);
    assert(4+offsetof(Module, stest) == 268);
    assert(4+offsetof(Module, sfilename) == 272);
    assert(4+offsetof(Module, massert) == 276);
    assert(4+offsetof(Module, munittest) == 280);
    assert(4+offsetof(Module, marray) == 284);
    assert(offsetof(ModuleDeclaration, loc) == 0);
    assert(offsetof(ModuleDeclaration, id) == 12);
    assert(offsetof(ModuleDeclaration, packages) == 16);
    assert(offsetof(ModuleDeclaration, isdeprecated) == 20);
    assert(offsetof(ModuleDeclaration, msg) == 24);
    assert(sizeof(ModuleDeclaration) == 28);
    // assert(offsetof(Escape, strings) == 0);
    // assert(sizeof(Escape) == 1024);
    // assert(offsetof(Section, name) == 4);
    // assert(offsetof(Section, namelen) == 8);
    // assert(offsetof(Section, _body) == 12);
    // assert(offsetof(Section, bodylen) == 16);
    // assert(offsetof(Section, nooutput) == 20);
    // assert(offsetof(DocComment, sections) == 0);
    // assert(offsetof(DocComment, summary) == 16);
    // assert(offsetof(DocComment, copyright) == 20);
    // assert(offsetof(DocComment, macros) == 24);
    // assert(offsetof(DocComment, pmacrotable) == 28);
    // assert(offsetof(DocComment, pescapetable) == 32);
    // assert(offsetof(DocComment, a) == 36);
    // assert(sizeof(DocComment) == 52);
    assert(offsetof(Scope, enclosing) == 0);
    assert(offsetof(Scope, _module) == 4);
    assert(offsetof(Scope, scopesym) == 8);
    assert(offsetof(Scope, sds) == 12);
    assert(offsetof(Scope, func) == 16);
    assert(offsetof(Scope, parent) == 20);
    assert(offsetof(Scope, slabel) == 24);
    assert(offsetof(Scope, sw) == 28);
    assert(offsetof(Scope, tf) == 32);
    assert(offsetof(Scope, os) == 36);
    assert(offsetof(Scope, sbreak) == 40);
    assert(offsetof(Scope, scontinue) == 44);
    assert(offsetof(Scope, fes) == 48);
    assert(offsetof(Scope, callsc) == 52);
    assert(offsetof(Scope, inunion) == 56);
    assert(offsetof(Scope, nofree) == 60);
    assert(offsetof(Scope, noctor) == 64);
    assert(offsetof(Scope, intypeof) == 68);
    assert(offsetof(Scope, lastVar) == 72);
    assert(offsetof(Scope, minst) == 76);
    assert(offsetof(Scope, tinst) == 80);
    assert(offsetof(Scope, callSuper) == 84);
    assert(offsetof(Scope, fieldinit) == 88);
    assert(offsetof(Scope, fieldinit_dim) == 92);
    assert(offsetof(Scope, structalign) == 96);
    assert(offsetof(Scope, linkage) == 100);
    assert(offsetof(Scope, inlining) == 104);
    assert(offsetof(Scope, protection) == 108);
    assert(offsetof(Scope, explicitProtection) == 116);
    assert(offsetof(Scope, stc) == 120);
    assert(offsetof(Scope, depdecl) == 128);
    assert(offsetof(Scope, flags) == 132);
    assert(offsetof(Scope, userAttribDecl) == 136);
    assert(offsetof(Scope, lastdc) == 140);
    assert(offsetof(Scope, anchorCounts) == 144);
    assert(offsetof(Scope, prevAnchor) == 148);
    assert(sizeof(Scope) == 152);
    assert(sizeof(StructFlags) == 1);
    assert(offsetof(StructDeclaration, zeroInit) == 232);
    assert(offsetof(StructDeclaration, hasIdentityAssign) == 236);
    assert(offsetof(StructDeclaration, hasIdentityEquals) == 237);
    assert(offsetof(StructDeclaration, postblits) == 240);
    assert(offsetof(StructDeclaration, postblit) == 256);
    assert(offsetof(StructDeclaration, xeq) == 260);
    assert(offsetof(StructDeclaration, xcmp) == 264);
    assert(offsetof(StructDeclaration, xhash) == 268);
    assert(offsetof(StructDeclaration, alignment) == 272);
    assert(offsetof(StructDeclaration, ispod) == 276);
    assert(offsetof(StructDeclaration, arg1type) == 280);
    assert(offsetof(StructDeclaration, arg2type) == 284);
    assert(offsetof(StructDeclaration, requestTypeInfo) == 288);
    assert(offsetof(Ungag, oldgag) == 0);
    assert(sizeof(Ungag) == 4);
    assert(offsetof(WithScopeSymbol, withstate) == 88);
    assert(offsetof(ArrayScopeSymbol, exp) == 88);
    assert(offsetof(ArrayScopeSymbol, type) == 92);
    assert(offsetof(ArrayScopeSymbol, td) == 96);
    assert(offsetof(ArrayScopeSymbol, sc) == 100);
    assert(offsetof(OverloadSet, a) == 64);
    assert(offsetof(DsymbolTable, tab) == 4);
    assert(offsetof(Tuple, objects) == 4);
    assert(offsetof(TemplatePrevious, prev) == 0);
    assert(offsetof(TemplatePrevious, sc) == 4);
    assert(offsetof(TemplatePrevious, dedargs) == 8);
    assert(sizeof(TemplatePrevious) == 12);
    assert(offsetof(TemplateDeclaration, parameters) == 88);
    assert(offsetof(TemplateDeclaration, origParameters) == 92);
    assert(offsetof(TemplateDeclaration, constraint) == 96);
    assert(offsetof(TemplateDeclaration, instances) == 100);
    assert(offsetof(TemplateDeclaration, overnext) == 104);
    assert(offsetof(TemplateDeclaration, overroot) == 108);
    assert(offsetof(TemplateDeclaration, funcroot) == 112);
    assert(offsetof(TemplateDeclaration, onemember) == 116);
    assert(offsetof(TemplateDeclaration, literal) == 120);
    assert(offsetof(TemplateDeclaration, ismixin) == 121);
    assert(offsetof(TemplateDeclaration, isstatic) == 122);
    assert(offsetof(TemplateDeclaration, protection) == 124);
    assert(offsetof(TemplateDeclaration, previous) == 132);
    assert(offsetof(Type, ty) == 4);
    printf("%p\n", offsetof(Type, mod));
    assert(offsetof(Type, mod) == 8);
    assert(offsetof(Type, deco) == 12);
    assert(offsetof(Type, cto) == 16);
    assert(offsetof(Type, ito) == 20);
    assert(offsetof(Type, sto) == 24);
    assert(offsetof(Type, scto) == 28);
    assert(offsetof(Type, wto) == 32);
    assert(offsetof(Type, wcto) == 36);
    assert(offsetof(Type, swto) == 40);
    assert(offsetof(Type, swcto) == 44);
    assert(offsetof(Type, pto) == 48);
    assert(offsetof(Type, rto) == 52);
    assert(offsetof(Type, arrayof) == 56);
    assert(offsetof(Type, vtinfo) == 60);
    assert(offsetof(Type, ctype) == 64);
    // assert(offsetof(TypeDeduced, tded) == 68);
    // assert(offsetof(TypeDeduced, argexps) == 72);
    // assert(offsetof(TypeDeduced, tparams) == 88);
    // assert(offsetof(TemplateParameter, x) == 8);
    printf("%p\n", offsetof(TemplateParameter, loc));
    assert(offsetof(TemplateParameter, loc) == 4);
    printf("%p\n", offsetof(TemplateParameter, ident));
    assert(offsetof(TemplateParameter, ident) == 16);
    assert(offsetof(TemplateParameter, dependent) == 20);
    printf("%p\n", offsetof(TemplateTypeParameter, specType));
    assert(12+offsetof(TemplateTypeParameter, specType) == 40);
    assert(12+offsetof(TemplateTypeParameter, defaultType) == 44);
    assert(12+offsetof(TemplateValueParameter, valType) == 40);
    assert(12+offsetof(TemplateValueParameter, specValue) == 44);
    assert(12+offsetof(TemplateValueParameter, defaultValue) == 48);
    assert(12+offsetof(TemplateAliasParameter, specType) == 40);
    assert(12+offsetof(TemplateAliasParameter, specAlias) == 44);
    assert(12+offsetof(TemplateAliasParameter, defaultAlias) == 48);
    assert(offsetof(TemplateInstance, name) == 88);
    assert(offsetof(TemplateInstance, tiargs) == 92);
    assert(offsetof(TemplateInstance, tdtypes) == 96);
    assert(offsetof(TemplateInstance, tempdecl) == 112);
    assert(offsetof(TemplateInstance, enclosing) == 116);
    assert(offsetof(TemplateInstance, aliasdecl) == 120);
    assert(offsetof(TemplateInstance, inst) == 124);
    assert(offsetof(TemplateInstance, argsym) == 128);
    assert(offsetof(TemplateInstance, inuse) == 132);
    assert(offsetof(TemplateInstance, nest) == 136);
    assert(offsetof(TemplateInstance, semantictiargsdone) == 140);
    assert(offsetof(TemplateInstance, havetempdecl) == 141);
    assert(offsetof(TemplateInstance, gagged) == 142);
    assert(offsetof(TemplateInstance, hash) == 144);
    assert(offsetof(TemplateInstance, fargs) == 148);
    assert(offsetof(TemplateInstance, deferred) == 152);
    assert(offsetof(TemplateInstance, memberOf) == 156);
    assert(offsetof(TemplateInstance, tinst) == 160);
    assert(offsetof(TemplateInstance, tnext) == 164);
    assert(offsetof(TemplateInstance, minst) == 168);
    assert(offsetof(TemplateMixin, tqual) == 172);
    // assert(offsetof(TemplateInstanceBox, ti) == 0);
    // assert(sizeof(TemplateInstanceBox) == 4);
    assert(offsetof(DebugSymbol, level) == 64);
    assert(offsetof(VersionSymbol, level) == 64);
    // assert(offsetof(__AnonStruct__u, exp) == 0);
    // assert(offsetof(__AnonStruct__u, integerexp) == 0);
    // assert(offsetof(__AnonStruct__u, errorexp) == 0);
    // assert(offsetof(__AnonStruct__u, realexp) == 0);
    // assert(offsetof(__AnonStruct__u, complexexp) == 0);
    // assert(offsetof(__AnonStruct__u, symoffexp) == 0);
    // assert(offsetof(__AnonStruct__u, stringexp) == 0);
    // assert(offsetof(__AnonStruct__u, arrayliteralexp) == 0);
    // assert(offsetof(__AnonStruct__u, assocarrayliteralexp) == 0);
    // assert(offsetof(__AnonStruct__u, structliteralexp) == 0);
    // assert(offsetof(__AnonStruct__u, nullexp) == 0);
    // assert(offsetof(__AnonStruct__u, dotvarexp) == 0);
    // assert(offsetof(__AnonStruct__u, addrexp) == 0);
    // assert(offsetof(__AnonStruct__u, indexexp) == 0);
    // assert(offsetof(__AnonStruct__u, sliceexp) == 0);
    // assert(offsetof(__AnonStruct__u, for_alignment_only) == 0);
    // assert(sizeof(__AnonStruct__u) == 64);
    assert(offsetof(UnionExp, u) == 0);
    assert(sizeof(UnionExp) == 64);
    assert(offsetof(IntegerExp, value) == 32);
    assert(offsetof(RealExp, value) == 28);
    assert(offsetof(ComplexExp, value) == 28);
    assert(offsetof(IdentifierExp, ident) == 28);
    assert(offsetof(DsymbolExp, s) == 28);
    assert(offsetof(DsymbolExp, hasOverloads) == 32);
    assert(offsetof(ThisExp, var) == 28);
    assert(offsetof(NullExp, committed) == 28);
    assert(offsetof(StringExp, string) == 28);
    // assert(offsetof(StringExp, wstring) == 28);
    // assert(offsetof(StringExp, dstring) == 28);
    assert(offsetof(StringExp, len) == 32);
    assert(offsetof(StringExp, sz) == 36);
    assert(offsetof(StringExp, committed) == 37);
    assert(offsetof(StringExp, postfix) == 38);
    assert(offsetof(StringExp, ownedByCtfe) == 40);
    assert(offsetof(TupleExp, e0) == 28);
    assert(offsetof(TupleExp, exps) == 32);
    assert(offsetof(ArrayLiteralExp, basis) == 28);
    assert(offsetof(ArrayLiteralExp, elements) == 32);
    assert(offsetof(ArrayLiteralExp, ownedByCtfe) == 36);
    assert(offsetof(AssocArrayLiteralExp, keys) == 28);
    assert(offsetof(AssocArrayLiteralExp, values) == 32);
    assert(offsetof(AssocArrayLiteralExp, ownedByCtfe) == 36);
    assert(offsetof(StructLiteralExp, sd) == 28);
    assert(offsetof(StructLiteralExp, elements) == 32);
    assert(offsetof(StructLiteralExp, stype) == 36);
    assert(offsetof(StructLiteralExp, useStaticInit) == 40);
    assert(offsetof(StructLiteralExp, sym) == 44);
    assert(offsetof(StructLiteralExp, ownedByCtfe) == 48);
    assert(offsetof(StructLiteralExp, origin) == 52);
    assert(offsetof(StructLiteralExp, inlinecopy) == 56);
    assert(offsetof(StructLiteralExp, stageflags) == 60);
    assert(offsetof(ScopeExp, sds) == 28);
    assert(offsetof(TemplateExp, td) == 28);
    assert(offsetof(TemplateExp, fd) == 32);
    assert(offsetof(NewExp, thisexp) == 28);
    assert(offsetof(NewExp, newargs) == 32);
    assert(offsetof(NewExp, newtype) == 36);
    assert(offsetof(NewExp, arguments) == 40);
    assert(offsetof(NewExp, argprefix) == 44);
    assert(offsetof(NewExp, member) == 48);
    assert(offsetof(NewExp, allocator) == 52);
    assert(offsetof(NewExp, onstack) == 56);
    assert(offsetof(NewAnonClassExp, thisexp) == 28);
    assert(offsetof(NewAnonClassExp, newargs) == 32);
    assert(offsetof(NewAnonClassExp, cd) == 36);
    assert(offsetof(NewAnonClassExp, arguments) == 40);
    assert(offsetof(SymbolExp, var) == 28);
    assert(offsetof(SymbolExp, hasOverloads) == 32);
    assert(offsetof(SymOffExp, offset) == 40);
    assert(offsetof(OverExp, vars) == 28);
    assert(offsetof(FuncExp, fd) == 28);
    assert(offsetof(FuncExp, td) == 32);
    assert(offsetof(FuncExp, tok) == 36);
    assert(offsetof(DeclarationExp, declaration) == 28);
    assert(offsetof(TypeidExp, obj) == 28);
    assert(offsetof(TraitsExp, ident) == 28);
    assert(offsetof(TraitsExp, args) == 32);
    assert(offsetof(IsExp, targ) == 28);
    assert(offsetof(IsExp, id) == 32);
    assert(offsetof(IsExp, tok) == 36);
    assert(offsetof(IsExp, tspec) == 40);
    assert(offsetof(IsExp, tok2) == 44);
    assert(offsetof(IsExp, parameters) == 48);
    assert(offsetof(UnaExp, e1) == 28);
    assert(offsetof(UnaExp, att1) == 32);
    assert(offsetof(BinExp, e1) == 28);
    assert(offsetof(BinExp, e2) == 32);
    assert(offsetof(BinExp, att1) == 36);
    assert(offsetof(BinExp, att2) == 40);
    assert(offsetof(AssertExp, msg) == 36);
    assert(offsetof(DotIdExp, ident) == 36);
    assert(offsetof(DotTemplateExp, td) == 36);
    assert(offsetof(DotVarExp, var) == 36);
    assert(offsetof(DotVarExp, hasOverloads) == 40);
    assert(offsetof(DotTemplateInstanceExp, ti) == 36);
    assert(offsetof(DelegateExp, func) == 36);
    assert(offsetof(DelegateExp, hasOverloads) == 40);
    assert(offsetof(DotTypeExp, sym) == 36);
    assert(offsetof(CallExp, arguments) == 36);
    assert(offsetof(CallExp, f) == 40);
    assert(offsetof(CallExp, directcall) == 44);
    assert(offsetof(CastExp, to) == 36);
    assert(offsetof(CastExp, mod) == 40);
    assert(offsetof(VectorExp, to) == 36);
    assert(offsetof(VectorExp, dim) == 40);
    assert(offsetof(SliceExp, upr) == 36);
    assert(offsetof(SliceExp, lwr) == 40);
    assert(offsetof(SliceExp, lengthVar) == 44);
    assert(offsetof(SliceExp, upperIsInBounds) == 48);
    assert(offsetof(SliceExp, lowerIsLessThanUpper) == 49);
    assert(offsetof(ArrayExp, arguments) == 36);
    assert(offsetof(ArrayExp, currentDimension) == 40);
    assert(offsetof(ArrayExp, lengthVar) == 44);
    assert(offsetof(IntervalExp, lwr) == 28);
    assert(offsetof(IntervalExp, upr) == 32);
    assert(offsetof(IndexExp, lengthVar) == 44);
    assert(offsetof(IndexExp, modifiable) == 48);
    assert(offsetof(IndexExp, indexIsInBounds) == 49);
    assert(offsetof(AssignExp, memset) == 44);
    assert(offsetof(CondExp, econd) == 44);
    assert(offsetof(DefaultInitExp, subop) == 28);
    // assert(offsetof(StatementRewriteWalker, ps) == 4);
    // assert(offsetof(NrvoWalker, fd) == 8);
    // assert(offsetof(NrvoWalker, sc) == 12);
    assert(offsetof(FuncDeclaration, fthrows) == 104);
    assert(offsetof(FuncDeclaration, frequire) == 108);
    assert(offsetof(FuncDeclaration, fensure) == 112);
    assert(offsetof(FuncDeclaration, fbody) == 116);
    assert(offsetof(FuncDeclaration, foverrides) == 120);
    assert(offsetof(FuncDeclaration, fdrequire) == 136);
    assert(offsetof(FuncDeclaration, fdensure) == 140);
    assert(offsetof(FuncDeclaration, mangleString) == 144);
    assert(offsetof(FuncDeclaration, outId) == 148);
    assert(offsetof(FuncDeclaration, vresult) == 152);
    assert(offsetof(FuncDeclaration, returnLabel) == 156);
    assert(offsetof(FuncDeclaration, localsymtab) == 160);
    assert(offsetof(FuncDeclaration, vthis) == 164);
    assert(offsetof(FuncDeclaration, v_arguments) == 168);
    assert(offsetof(Objc_FuncDeclaration, fdecl) == 0);
    assert(offsetof(Objc_FuncDeclaration, selector) == 4);
    assert(sizeof(Objc_FuncDeclaration) == 8);
    assert(offsetof(FuncDeclaration, objc) == 172);
    assert(offsetof(FuncDeclaration, v_argsave) == 180);
    assert(offsetof(FuncDeclaration, parameters) == 184);
    assert(offsetof(FuncDeclaration, labtab) == 188);
    assert(offsetof(FuncDeclaration, overnext) == 192);
    assert(offsetof(FuncDeclaration, overnext0) == 196);
    assert(offsetof(FuncDeclaration, endloc) == 200);
    assert(offsetof(FuncDeclaration, vtblIndex) == 212);
    assert(offsetof(FuncDeclaration, naked) == 216);
    assert(offsetof(FuncDeclaration, generated) == 217);
    assert(offsetof(FuncDeclaration, inlineStatusStmt) == 220);
    assert(offsetof(FuncDeclaration, inlineStatusExp) == 224);
    assert(offsetof(FuncDeclaration, inlining) == 228);
    assert(offsetof(FuncDeclaration, ctfeCode) == 232);
    assert(offsetof(FuncDeclaration, inlineNest) == 236);
    assert(offsetof(FuncDeclaration, isArrayOp) == 240);
    assert(offsetof(FuncDeclaration, semantic3Errors) == 241);
    assert(offsetof(FuncDeclaration, fes) == 244);
    assert(offsetof(FuncDeclaration, interfaceVirtual) == 248);
    assert(offsetof(FuncDeclaration, introducing) == 252);
    assert(offsetof(FuncDeclaration, tintro) == 256);
    assert(offsetof(FuncDeclaration, inferRetType) == 260);
    assert(offsetof(FuncDeclaration, storage_class2) == 264);
    assert(offsetof(FuncDeclaration, hasReturnExp) == 272);
    assert(offsetof(FuncDeclaration, nrvo_can) == 276);
    assert(offsetof(FuncDeclaration, nrvo_var) == 280);
    assert(offsetof(FuncDeclaration, shidden) == 284);
    assert(offsetof(FuncDeclaration, returns) == 288);
    assert(offsetof(FuncDeclaration, gotos) == 292);
    assert(offsetof(FuncDeclaration, builtin) == 296);
    assert(offsetof(FuncDeclaration, tookAddressOf) == 300);
    assert(offsetof(FuncDeclaration, requiresClosure) == 304);
    assert(offsetof(FuncDeclaration, closureVars) == 308);
    assert(offsetof(FuncDeclaration, siblingCallers) == 324);
    assert(offsetof(FuncDeclaration, inlinedNestedCallees) == 340);
    assert(offsetof(FuncDeclaration, flags) == 344);
    assert(offsetof(FuncAliasDeclaration, funcalias) == 352);
    assert(offsetof(FuncAliasDeclaration, hasOverloads) == 356);
    assert(offsetof(FuncLiteralDeclaration, tok) == 352);
    assert(offsetof(FuncLiteralDeclaration, treq) == 356);
    assert(offsetof(FuncLiteralDeclaration, deferToObj) == 360);
    assert(offsetof(StaticDtorDeclaration, vgate) == 352);
    assert(offsetof(UnitTestDeclaration, codedoc) == 352);
    assert(offsetof(UnitTestDeclaration, deferredNested) == 356);
    assert(offsetof(NewDeclaration, parameters) == 352);
    assert(offsetof(NewDeclaration, varargs) == 356);
    assert(offsetof(DeleteDeclaration, parameters) == 352);
    assert(offsetof(Param, obj) == 0);
    assert(offsetof(Param, link) == 1);
    assert(offsetof(Param, dll) == 2);
    assert(offsetof(Param, lib) == 3);
    assert(offsetof(Param, multiobj) == 4);
    assert(offsetof(Param, oneobj) == 5);
    assert(offsetof(Param, trace) == 6);
    assert(offsetof(Param, tracegc) == 7);
    assert(offsetof(Param, verbose) == 8);
    assert(offsetof(Param, showColumns) == 9);
    assert(offsetof(Param, vtls) == 10);
    assert(offsetof(Param, vgc) == 11);
    assert(offsetof(Param, vfield) == 12);
    assert(offsetof(Param, vcomplex) == 13);
    assert(offsetof(Param, symdebug) == 14);
    assert(offsetof(Param, alwaysframe) == 15);
    assert(offsetof(Param, optimize) == 16);
    assert(offsetof(Param, map) == 17);
    assert(offsetof(Param, is64bit) == 18);
    assert(offsetof(Param, isLP64) == 19);
    assert(offsetof(Param, isLinux) == 20);
    assert(offsetof(Param, isOSX) == 21);
    assert(offsetof(Param, isWindows) == 22);
    assert(offsetof(Param, isFreeBSD) == 23);
    assert(offsetof(Param, isOpenBSD) == 24);
    assert(offsetof(Param, isSolaris) == 25);
    assert(offsetof(Param, hasObjectiveC) == 26);
    assert(offsetof(Param, mscoff) == 27);
    assert(offsetof(Param, useDeprecated) == 28);
    assert(offsetof(Param, useAssert) == 29);
    assert(offsetof(Param, useInvariants) == 30);
    assert(offsetof(Param, useIn) == 31);
    assert(offsetof(Param, useOut) == 32);
    assert(offsetof(Param, stackstomp) == 33);
    assert(offsetof(Param, useSwitchError) == 34);
    assert(offsetof(Param, useUnitTests) == 35);
    assert(offsetof(Param, useInline) == 36);
    assert(offsetof(Param, useDIP25) == 37);
    assert(offsetof(Param, release) == 38);
    assert(offsetof(Param, preservePaths) == 39);
    assert(offsetof(Param, warnings) == 40);
    assert(offsetof(Param, pic) == 41);
    assert(offsetof(Param, color) == 42);
    assert(offsetof(Param, cov) == 43);
    assert(offsetof(Param, covPercent) == 44);
    assert(offsetof(Param, nofloat) == 45);
    assert(offsetof(Param, ignoreUnsupportedPragmas) == 46);
    assert(offsetof(Param, enforcePropertySyntax) == 47);
    assert(offsetof(Param, betterC) == 48);
    assert(offsetof(Param, addMain) == 49);
    assert(offsetof(Param, allInst) == 50);
    assert(offsetof(Param, check10378) == 51);
    assert(offsetof(Param, bug10378) == 52);
    assert(offsetof(Param, useArrayBounds) == 56);
    assert(offsetof(Param, argv0) == 60);
    assert(offsetof(Param, imppath) == 64);
    assert(offsetof(Param, fileImppath) == 68);
    assert(offsetof(Param, objdir) == 72);
    assert(offsetof(Param, objname) == 76);
    assert(offsetof(Param, libname) == 80);
    assert(offsetof(Param, doDocComments) == 84);
    assert(offsetof(Param, docdir) == 88);
    assert(offsetof(Param, docname) == 92);
    assert(offsetof(Param, ddocfiles) == 96);
    // assert(offsetof(Param, doCppHeaders) == 100);
    // assert(offsetof(Param, cppfilename) == 104);
    assert(8+offsetof(Param, doHdrGeneration) == 108);
    assert(8+offsetof(Param, hdrdir) == 112);
    assert(8+offsetof(Param, hdrname) == 116);
    assert(8+offsetof(Param, doJsonGeneration) == 120);
    assert(8+offsetof(Param, jsonfilename) == 124);
    assert(8+offsetof(Param, debuglevel) == 128);
    assert(8+offsetof(Param, debugids) == 132);
    assert(8+offsetof(Param, versionlevel) == 136);
    assert(8+offsetof(Param, versionids) == 140);
    assert(8+offsetof(Param, defaultlibname) == 144);
    assert(8+offsetof(Param, debuglibname) == 148);
    assert(8+offsetof(Param, moduleDepsFile) == 152);
    assert(8+offsetof(Param, moduleDeps) == 156);
    assert(8+offsetof(Param, debugb) == 160);
    assert(8+offsetof(Param, debugc) == 161);
    assert(8+offsetof(Param, debugf) == 162);
    assert(8+offsetof(Param, debugr) == 163);
    assert(8+offsetof(Param, debugx) == 164);
    assert(8+offsetof(Param, debugy) == 165);
    assert(8+offsetof(Param, run) == 166);
    assert(8+offsetof(Param, runargs) == 168);
    assert(8+offsetof(Param, objfiles) == 184);
    assert(8+offsetof(Param, linkswitches) == 188);
    assert(8+offsetof(Param, libfiles) == 192);
    assert(8+offsetof(Param, dllfiles) == 196);
    assert(8+offsetof(Param, deffile) == 200);
    assert(8+offsetof(Param, resfile) == 204);
    assert(8+offsetof(Param, exefile) == 208);
    assert(8+offsetof(Param, mapfile) == 212);
    assert(8+sizeof(Param) == 216);
    assert(offsetof(Compiler, vendor) == 0);
    assert(sizeof(Compiler) == 4);
    assert(offsetof(Global, inifilename) == 0);
    assert(offsetof(Global, mars_ext) == 4);
    assert(offsetof(Global, obj_ext) == 8);
    assert(offsetof(Global, lib_ext) == 12);
    assert(offsetof(Global, dll_ext) == 16);
    assert(offsetof(Global, doc_ext) == 20);
    assert(offsetof(Global, ddoc_ext) == 24);
    // assert(offsetof(Global, cpp_ext) == 28);
    assert(4+offsetof(Global, hdr_ext) == 32);
    assert(4+offsetof(Global, json_ext) == 36);
    assert(4+offsetof(Global, map_ext) == 40);
    assert(4+offsetof(Global, run_noext) == 44);
    assert(4+offsetof(Global, copyright) == 48);
    assert(4+offsetof(Global, written) == 52);
    assert(4+offsetof(Global, main_d) == 56);
    assert(4+offsetof(Global, path) == 60);
    assert(4+offsetof(Global, filePath) == 64);
    assert(4+offsetof(Global, _version) == 68);
    assert(4+offsetof(Global, compiler) == 72);
    assert(4+offsetof(Global, params) == 76);
    assert(12+offsetof(Global, errors) == 292);
    assert(12+offsetof(Global, warnings) == 296);
    assert(12+offsetof(Global, stdmsg) == 300);
    assert(12+offsetof(Global, gag) == 304);
    assert(12+offsetof(Global, gaggedErrors) == 308);
    assert(12+offsetof(Global, errorLimit) == 312);
    assert(12+sizeof(Global) == 316);
    assert(offsetof(HdrGenState, hdrgen) == 0);
    assert(offsetof(HdrGenState, ddoc) == 1);
    assert(offsetof(HdrGenState, fullQual) == 2);
    assert(offsetof(HdrGenState, tpltMember) == 4);
    assert(offsetof(HdrGenState, autoMember) == 8);
    assert(offsetof(HdrGenState, forStmtInit) == 12);
    assert(sizeof(HdrGenState) == 16);
    assert(sizeof(Id) == 1);
    assert(offsetof(Identifier, value) == 4);
    assert(offsetof(Identifier, string) == 8);
    assert(offsetof(Identifier, len) == 12);
    assert(offsetof(Initializer, loc) == 4);
    assert(offsetof(VoidInitializer, type) == 16);
    assert(offsetof(StructInitializer, field) == 16);
    assert(offsetof(StructInitializer, value) == 32);
    assert(offsetof(ArrayInitializer, index) == 16);
    assert(offsetof(ArrayInitializer, value) == 32);
    assert(offsetof(ArrayInitializer, dim) == 48);
    assert(offsetof(ArrayInitializer, type) == 52);
    assert(offsetof(ArrayInitializer, sem) == 56);
    assert(offsetof(ExpInitializer, exp) == 16);
    assert(offsetof(ExpInitializer, expandTuples) == 20);
    assert(offsetof(SignExtendedNumber, value) == 0);
    assert(offsetof(SignExtendedNumber, negative) == 8);
    assert(sizeof(SignExtendedNumber) == 16);
    assert(offsetof(IntRange, imin) == 0);
    assert(offsetof(IntRange, imax) == 16);
    assert(sizeof(IntRange) == 32);
    // assert(offsetof(ToJsonVisitor, buf) == 4);
    // assert(offsetof(ToJsonVisitor, indentLevel) == 8);
    // assert(offsetof(ToJsonVisitor, filename) == 12);
    assert(offsetof(TypeNext, next) == 68);
    assert(offsetof(TypeBasic, dstring) == 68);
    assert(offsetof(TypeBasic, flags) == 72);
    assert(offsetof(TypeVector, basetype) == 68);
    assert(offsetof(TypeSArray, dim) == 72);
    assert(offsetof(TypeAArray, index) == 72);
    assert(offsetof(TypeAArray, loc) == 76);
    assert(offsetof(TypeAArray, sc) == 88);
    assert(offsetof(TypeFunction, parameters) == 72);
    assert(offsetof(TypeFunction, varargs) == 76);
    assert(offsetof(TypeFunction, isnothrow) == 80);
    assert(offsetof(TypeFunction, isnogc) == 81);
    assert(offsetof(TypeFunction, isproperty) == 82);
    assert(offsetof(TypeFunction, isref) == 83);
    assert(offsetof(TypeFunction, isreturn) == 84);
    assert(offsetof(TypeFunction, linkage) == 88);
    assert(offsetof(TypeFunction, trust) == 92);
    assert(offsetof(TypeFunction, purity) == 96);
    assert(offsetof(TypeFunction, iswild) == 100);
    assert(offsetof(TypeFunction, fargs) == 104);
    assert(offsetof(TypeFunction, inuse) == 108);
    assert(offsetof(TypeQualified, loc) == 68);
    assert(offsetof(TypeQualified, idents) == 80);
    assert(offsetof(TypeIdentifier, ident) == 96);
    assert(offsetof(TypeIdentifier, originalSymbol) == 100);
    assert(offsetof(TypeInstance, tempinst) == 96);
    assert(offsetof(TypeTypeof, exp) == 96);
    assert(offsetof(TypeTypeof, inuse) == 100);
    assert(offsetof(TypeStruct, sym) == 68);
    assert(offsetof(TypeStruct, att) == 72);
    assert(offsetof(TypeEnum, sym) == 68);
    assert(offsetof(TypeClass, sym) == 68);
    assert(offsetof(TypeClass, att) == 72);
    assert(offsetof(TypeTuple, arguments) == 68);
    assert(offsetof(TypeSlice, lwr) == 72);
    assert(offsetof(TypeSlice, upr) == 76);
    assert(offsetof(Parameter, storageClass) == 8);
    assert(offsetof(Parameter, type) == 16);
    assert(offsetof(Parameter, ident) == 20);
    assert(offsetof(Parameter, defaultArg) == 24);
    // assert(offsetof(NOGCVisitor, f) == 8);
    // assert(offsetof(NOGCVisitor, err) == 12);
    assert(offsetof(ObjcSelector, stringvalue) == 0);
    assert(offsetof(ObjcSelector, stringlen) == 4);
    assert(offsetof(ObjcSelector, paramCount) == 8);
    assert(sizeof(ObjcSelector) == 12);
    // assert(offsetof(PrefixAttributes, storageClass) == 0);
    // assert(offsetof(PrefixAttributes, depmsg) == 8);
    // assert(offsetof(PrefixAttributes, link) == 12);
    // assert(offsetof(PrefixAttributes, protection) == 16);
    // assert(offsetof(PrefixAttributes, alignment) == 24);
    // assert(offsetof(PrefixAttributes, udas) == 28);
    // assert(offsetof(PrefixAttributes, comment) == 32);
    // assert(sizeof(PrefixAttributes) == 40);
    // assert(offsetof(PostorderStatementVisitor, v) == 8);
    assert(offsetof(Statement, loc) == 4);
    assert(offsetof(PeelStatement, s) == 16);
    assert(offsetof(ExpStatement, exp) == 16);
    assert(offsetof(DtorExpStatement, var) == 20);
    assert(offsetof(CompileStatement, exp) == 16);
    assert(offsetof(CompoundStatement, statements) == 16);
    assert(offsetof(UnrolledLoopStatement, statements) == 16);
    assert(offsetof(ScopeStatement, statement) == 16);
    assert(offsetof(WhileStatement, condition) == 16);
    assert(offsetof(WhileStatement, _body) == 20);
    assert(offsetof(WhileStatement, endloc) == 24);
    assert(offsetof(DoStatement, _body) == 16);
    assert(offsetof(DoStatement, condition) == 20);
    assert(offsetof(ForStatement, _init) == 16);
    assert(offsetof(ForStatement, condition) == 20);
    assert(offsetof(ForStatement, increment) == 24);
    assert(offsetof(ForStatement, _body) == 28);
    assert(offsetof(ForStatement, endloc) == 32);
    assert(offsetof(ForStatement, relatedLabeled) == 44);
    assert(offsetof(ForeachStatement, op) == 16);
    assert(offsetof(ForeachStatement, parameters) == 20);
    assert(offsetof(ForeachStatement, aggr) == 24);
    assert(offsetof(ForeachStatement, _body) == 28);
    assert(offsetof(ForeachStatement, endloc) == 32);
    assert(offsetof(ForeachStatement, key) == 44);
    assert(offsetof(ForeachStatement, value) == 48);
    assert(offsetof(ForeachStatement, func) == 52);
    assert(offsetof(ForeachStatement, cases) == 56);
    assert(offsetof(ForeachStatement, gotos) == 60);
    assert(offsetof(ForeachRangeStatement, op) == 16);
    assert(offsetof(ForeachRangeStatement, prm) == 20);
    assert(offsetof(ForeachRangeStatement, lwr) == 24);
    assert(offsetof(ForeachRangeStatement, upr) == 28);
    assert(offsetof(ForeachRangeStatement, _body) == 32);
    assert(offsetof(ForeachRangeStatement, endloc) == 36);
    assert(offsetof(ForeachRangeStatement, key) == 48);
    assert(offsetof(IfStatement, prm) == 16);
    assert(offsetof(IfStatement, condition) == 20);
    assert(offsetof(IfStatement, ifbody) == 24);
    assert(offsetof(IfStatement, elsebody) == 28);
    assert(offsetof(IfStatement, match) == 32);
    assert(offsetof(ConditionalStatement, condition) == 16);
    assert(offsetof(ConditionalStatement, ifbody) == 20);
    assert(offsetof(ConditionalStatement, elsebody) == 24);
    assert(offsetof(PragmaStatement, ident) == 16);
    assert(offsetof(PragmaStatement, args) == 20);
    assert(offsetof(PragmaStatement, _body) == 24);
    assert(offsetof(StaticAssertStatement, sa) == 16);
    assert(offsetof(SwitchStatement, condition) == 16);
    assert(offsetof(SwitchStatement, _body) == 20);
    assert(offsetof(SwitchStatement, isFinal) == 24);
    assert(offsetof(SwitchStatement, sdefault) == 28);
    assert(offsetof(SwitchStatement, tf) == 32);
    assert(offsetof(SwitchStatement, gotoCases) == 36);
    assert(offsetof(SwitchStatement, cases) == 52);
    assert(offsetof(SwitchStatement, hasNoDefault) == 56);
    assert(offsetof(SwitchStatement, hasVars) == 60);
    assert(offsetof(CaseStatement, exp) == 16);
    assert(offsetof(CaseStatement, statement) == 20);
    assert(offsetof(CaseStatement, index) == 24);
    assert(offsetof(CaseRangeStatement, first) == 16);
    assert(offsetof(CaseRangeStatement, last) == 20);
    assert(offsetof(CaseRangeStatement, statement) == 24);
    assert(offsetof(DefaultStatement, statement) == 16);
    assert(offsetof(GotoDefaultStatement, sw) == 16);
    assert(offsetof(GotoCaseStatement, exp) == 16);
    assert(offsetof(GotoCaseStatement, cs) == 20);
    assert(offsetof(ReturnStatement, exp) == 16);
    assert(offsetof(ReturnStatement, caseDim) == 20);
    assert(offsetof(BreakStatement, ident) == 16);
    assert(offsetof(ContinueStatement, ident) == 16);
    assert(offsetof(SynchronizedStatement, exp) == 16);
    assert(offsetof(SynchronizedStatement, _body) == 20);
    assert(offsetof(WithStatement, exp) == 16);
    assert(offsetof(WithStatement, _body) == 20);
    assert(offsetof(WithStatement, wthis) == 24);
    assert(offsetof(TryCatchStatement, _body) == 16);
    assert(offsetof(TryCatchStatement, catches) == 20);
    assert(offsetof(Catch, loc) == 4);
    assert(offsetof(Catch, type) == 16);
    assert(offsetof(Catch, ident) == 20);
    assert(offsetof(Catch, var) == 24);
    assert(offsetof(Catch, handler) == 28);
    assert(offsetof(Catch, errors) == 32);
    assert(offsetof(Catch, internalCatch) == 33);
    assert(offsetof(TryFinallyStatement, _body) == 16);
    assert(offsetof(TryFinallyStatement, finalbody) == 20);
    assert(offsetof(OnScopeStatement, tok) == 16);
    assert(offsetof(OnScopeStatement, statement) == 20);
    assert(offsetof(ThrowStatement, exp) == 16);
    assert(offsetof(ThrowStatement, internalThrow) == 20);
    assert(offsetof(DebugStatement, statement) == 16);
    assert(offsetof(GotoStatement, ident) == 16);
    assert(offsetof(GotoStatement, label) == 20);
    assert(offsetof(GotoStatement, tf) == 24);
    assert(offsetof(GotoStatement, os) == 28);
    assert(offsetof(GotoStatement, lastVar) == 32);
    assert(offsetof(LabelStatement, ident) == 16);
    assert(offsetof(LabelStatement, statement) == 20);
    assert(offsetof(LabelStatement, tf) == 24);
    assert(offsetof(LabelStatement, os) == 28);
    assert(offsetof(LabelStatement, lastVar) == 32);
    assert(offsetof(LabelStatement, gotoTarget) == 36);
    assert(offsetof(LabelStatement, breaks) == 40);
    assert(offsetof(LabelDsymbol, statement) == 64);
    assert(offsetof(AsmStatement, tokens) == 16);
    assert(offsetof(AsmStatement, asmcode) == 20);
    assert(offsetof(AsmStatement, asmalign) == 24);
    assert(offsetof(AsmStatement, regs) == 28);
    assert(offsetof(AsmStatement, refparam) == 32);
    assert(offsetof(AsmStatement, naked) == 33);
    assert(offsetof(CompoundAsmStatement, stc) == 24);
    assert(offsetof(ImportStatement, imports) == 16);
    assert(offsetof(StaticAssert, exp) == 64);
    assert(offsetof(StaticAssert, msg) == 68);
    assert(sizeof(Target) == 1);
    assert(offsetof(Token, next) == 0);
    assert(offsetof(Token, loc) == 4);
    assert(offsetof(Token, ptr) == 16);
    assert(offsetof(Token, value) == 20);
    assert(offsetof(Token, blockComment) == 24);
    assert(offsetof(Token, lineComment) == 28);
    assert(offsetof(Token, int64value) == 32);
    assert(offsetof(Token, uns64value) == 32);
    assert(offsetof(Token, float80value) == 32);
    assert(offsetof(Token, ustring) == 32);
    assert(offsetof(Token, len) == 36);
    assert(offsetof(Token, postfix) == 40);
    assert(offsetof(Token, ident) == 32);
    assert(sizeof(Token) == 48);
    // assert(offsetof(Keyword, name) == 0);
    // assert(offsetof(Keyword, value) == 4);
    // assert(sizeof(Keyword) == 8);
    // assert(offsetof(PushAttributes, mods) == 0);
    // assert(sizeof(PushAttributes) == 4);
    // assert(offsetof(OmfObjSymbol, name) == 0);
    // assert(offsetof(OmfObjSymbol, om) == 4);
    // assert(sizeof(OmfObjSymbol) == 8);
    // assert(offsetof(LibOMF, libfile) == 4);
    // assert(offsetof(LibOMF, objmodules) == 8);
    // assert(offsetof(LibOMF, objsymbols) == 24);
    // assert(offsetof(LibOMF, tab) == 40);
    // assert(offsetof(LibOMF, loc) == 64);
    // assert(offsetof(OmfObjModule, base) == 0);
    // assert(offsetof(OmfObjModule, length) == 4);
    // assert(offsetof(OmfObjModule, page) == 8);
    // assert(offsetof(OmfObjModule, name) == 12);
    // assert(sizeof(OmfObjModule) == 16);
    // assert(offsetof(MSCoffObjSymbol, name) == 0);
    // assert(offsetof(MSCoffObjSymbol, om) == 4);
    // assert(sizeof(MSCoffObjSymbol) == 8);
    // assert(offsetof(LibMSCoff, libfile) == 4);
    // assert(offsetof(LibMSCoff, objmodules) == 8);
    // assert(offsetof(LibMSCoff, objsymbols) == 24);
    // assert(offsetof(LibMSCoff, tab) == 40);
    // assert(offsetof(LibMSCoff, loc) == 64);
    // assert(offsetof(MSCoffObjModule, base) == 0);
    // assert(offsetof(MSCoffObjModule, length) == 4);
    // assert(offsetof(MSCoffObjModule, offset) == 8);
    // assert(offsetof(MSCoffObjModule, index) == 12);
    // assert(offsetof(MSCoffObjModule, name) == 16);
    // assert(offsetof(MSCoffObjModule, name_offset) == 20);
    // assert(offsetof(MSCoffObjModule, file_time) == 24);
    // assert(offsetof(MSCoffObjModule, user_id) == 32);
    // assert(offsetof(MSCoffObjModule, group_id) == 36);
    // assert(offsetof(MSCoffObjModule, file_mode) == 40);
    // assert(offsetof(MSCoffObjModule, scan) == 44);
    // assert(sizeof(MSCoffObjModule) == 48);
    // assert(offsetof(MSCoffLibHeader, object_name) == 0);
    // assert(offsetof(MSCoffLibHeader, file_time) == 16);
    // assert(offsetof(MSCoffLibHeader, user_id) == 28);
    // assert(offsetof(MSCoffLibHeader, group_id) == 34);
    // assert(offsetof(MSCoffLibHeader, file_mode) == 40);
    // assert(offsetof(MSCoffLibHeader, file_size) == 48);
    // assert(offsetof(MSCoffLibHeader, trailer) == 58);
    // assert(sizeof(MSCoffLibHeader) == 60);
    // assert(offsetof(BIGOBJ_HEADER, Sig1) == 0);
    // assert(offsetof(BIGOBJ_HEADER, Sig2) == 2);
    // assert(offsetof(BIGOBJ_HEADER, Version) == 4);
    // assert(offsetof(BIGOBJ_HEADER, Machine) == 6);
    // assert(offsetof(BIGOBJ_HEADER, TimeDateStamp) == 8);
    // assert(offsetof(BIGOBJ_HEADER, UUID) == 12);
    // assert(offsetof(BIGOBJ_HEADER, unused) == 28);
    // assert(offsetof(BIGOBJ_HEADER, NumberOfSections) == 44);
    // assert(offsetof(BIGOBJ_HEADER, PointerToSymbolTable) == 48);
    // assert(offsetof(BIGOBJ_HEADER, NumberOfSymbols) == 52);
    // assert(sizeof(BIGOBJ_HEADER) == 56);
    // assert(offsetof(IMAGE_FILE_HEADER, Machine) == 0);
    // assert(offsetof(IMAGE_FILE_HEADER, NumberOfSections) == 2);
    // assert(offsetof(IMAGE_FILE_HEADER, TimeDateStamp) == 4);
    // assert(offsetof(IMAGE_FILE_HEADER, PointerToSymbolTable) == 8);
    // assert(offsetof(IMAGE_FILE_HEADER, NumberOfSymbols) == 12);
    // assert(offsetof(IMAGE_FILE_HEADER, SizeOfOptionalHeader) == 16);
    // assert(offsetof(IMAGE_FILE_HEADER, Characteristics) == 18);
    // assert(sizeof(IMAGE_FILE_HEADER) == 20);
    // assert(offsetof(SymbolTable32, Name) == 0);
    // assert(offsetof(SymbolTable32, Zeros) == 0);
    // assert(offsetof(SymbolTable32, Offset) == 4);
    // assert(offsetof(SymbolTable32, Value) == 8);
    // assert(offsetof(SymbolTable32, SectionNumber) == 12);
    // assert(offsetof(SymbolTable32, Type) == 16);
    // assert(offsetof(SymbolTable32, StorageClass) == 18);
    // assert(offsetof(SymbolTable32, NumberOfAuxSymbols) == 19);
    // assert(sizeof(SymbolTable32) == 20);
    // assert(offsetof(SymbolTable, Name) == 0);
    // assert(offsetof(SymbolTable, Value) == 8);
    // assert(offsetof(SymbolTable, SectionNumber) == 12);
    // assert(offsetof(SymbolTable, Type) == 14);
    // assert(offsetof(SymbolTable, StorageClass) == 16);
    // assert(offsetof(SymbolTable, NumberOfAuxSymbols) == 17);
    // assert(sizeof(SymbolTable) == 18);

        }
