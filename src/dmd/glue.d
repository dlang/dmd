/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2018 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/glue.d, _glue.d)
 * Documentation: $(LINK https://dlang.org/phobos/dmd_glue.html)
 * Coverage:    $(LINK https://codecov.io/gh/dlang/dmd/src/master/src/dmd/glue.d)
 */

module dmd.glue;

import core.stdc.stdio;
import core.stdc.string;
import core.stdc.stdlib;

import dmd.root.array;
import dmd.root.file;
import dmd.root.filename;
import dmd.root.outbuffer;
import dmd.root.rmem;

import dmd.backend.cdef;
import dmd.backend.cc;
import dmd.backend.code;
import dmd.backend.dt;
import dmd.backend.el;
import dmd.backend.global;
import dmd.backend.obj;
import dmd.backend.oper;
import dmd.backend.outbuf;
import dmd.backend.rtlsym;
import dmd.backend.ty;
import dmd.backend.type;

import dmd.aggregate;
import dmd.arraytypes;
import dmd.blockexit;
import dmd.dclass;
import dmd.declaration;
import dmd.dmangle;
import dmd.dmodule;
import dmd.dstruct;
import dmd.dsymbol;
import dmd.dtemplate;
import dmd.e2ir;
import dmd.errors;
import dmd.expression;
import dmd.func;
import dmd.globals;
import dmd.identifier;
import dmd.id;
import dmd.irstate;
import dmd.lib;
import dmd.mtype;
import dmd.objc_glue;
import dmd.s2ir;
import dmd.statement;
import dmd.target;
import dmd.tocsym;
import dmd.toctype;
import dmd.toir;
import dmd.toobj;
import dmd.typesem;
import dmd.utils;

extern (C++):

alias symbols = Array!(Symbol*);
alias toSymbol = dmd.tocsym.toSymbol;

//extern
__gshared
{
    elem *eictor;
    Symbol *ictorlocalgot;
    symbols sctors;
    StaticDtorDeclarations ectorgates;
    symbols sdtors;
    symbols stests;

    symbols ssharedctors;
    SharedStaticDtorDeclarations esharedctorgates;
    symbols sshareddtors;

    char *lastmname;
}


/**************************************
 * Append s to list of object files to generate later.
 */

__gshared Dsymbols obj_symbols_towrite;

void obj_append(Dsymbol s)
{
    //printf("deferred: %s\n", s.toChars());
    obj_symbols_towrite.push(s);
}

void obj_write_deferred(Library library)
{
    for (size_t i = 0; i < obj_symbols_towrite.dim; i++)
    {
        Dsymbol s = obj_symbols_towrite[i];
        Module m = s.getModule();

        char *mname;
        if (m)
        {
            mname = cast(char*)m.srcfile.toChars();
            lastmname = mname;
        }
        else
        {
            //mname = s.ident.toChars();
            mname = lastmname;
            assert(mname);
        }

        obj_start(mname);

        __gshared int count;
        count++;                // sequence for generating names

        /* Create a module that's a doppelganger of m, with just
         * enough to be able to create the moduleinfo.
         */
        OutBuffer idbuf;
        idbuf.printf("%s.%d", m ? m.ident.toChars() : mname, count);
        char *idstr = idbuf.peekString();

        if (!m)
        {
            // it doesn't make sense to make up a module if we don't know where to put the symbol
            //  so output it into it's own object file without ModuleInfo
            objmod.initfile(idstr, null, mname);
            toObjFile(s, false);
            objmod.termfile();
        }
        else
        {
            idbuf.data = null;
            Identifier id = Identifier.create(idstr);

            Module md = Module.create(mname, id, 0, 0);
            md.members = new Dsymbols();
            md.members.push(s);   // its only 'member' is s
            md.doppelganger = 1;       // identify this module as doppelganger
            md.md = m.md;
            md.aimports.push(m);       // it only 'imports' m

            genObjFile(md, false);
        }

        /* Set object file name to be source name with sequence number,
         * as mangled symbol names get way too long.
         */
        const(char)* fname = FileName.removeExt(mname);
        OutBuffer namebuf;
        uint hash = 0;
        for (const(char)* p = s.toChars(); *p; p++)
            hash += *p;
        namebuf.printf("%s_%x_%x.%s", fname, count, hash, global.obj_ext);
        FileName.free(cast(char *)fname);
        fname = namebuf.extractString();

        //printf("writing '%s'\n", fname);
        File *objfile = File.create(fname);
        obj_end(library, objfile);
    }
    obj_symbols_towrite.dim = 0;
}


/***********************************************
 * Generate function that calls array of functions and gates.
 * Params:
 *      m = module symbol (for name mangling purposes)
 *      sctors = array of functions
 *      ectorgates = array of gates
 *      id = identifier string for generator function
 * Returns:
 *      function Symbol generated
 */

private Symbol *callFuncsAndGates(Module m, symbols *sctors, StaticDtorDeclarations *ectorgates,
        const(char)* id)
{
    Symbol *sctor = null;

    if ((sctors && sctors.dim) ||
        (ectorgates && ectorgates.dim))
    {
        __gshared type *t;
        if (!t)
        {
            /* t will be the type of the functions generated:
             *      extern (C) void func();
             */
            t = type_function(TYnfunc, null, 0, false, tstypes[TYvoid]);
            t.Tmangle = mTYman_c;
        }

        localgot = null;
        sctor = toSymbolX(m, id, SCglobal, t, "FZv");
        cstate.CSpsymtab = &sctor.Sfunc.Flocsym;
        elem *ector = null;

        if (ectorgates)
        {
            foreach (f; *ectorgates)
            {
                Symbol *s = toSymbol(f.vgate);
                elem *e = el_var(s);
                e = el_bin(OPaddass, TYint, e, el_long(TYint, 1));
                ector = el_combine(ector, e);
            }
        }

        if (sctors)
        {
            foreach (s; *sctors)
            {
                elem *e = el_una(OPucall, TYvoid, el_var(s));
                ector = el_combine(ector, e);
            }
        }

        block *b = block_calloc();
        b.BC = BCret;
        b.Belem = ector;
        sctor.Sfunc.Fstartline.Sfilename = m.arg;
        sctor.Sfunc.Fstartblock = b;
        writefunc(sctor);
    }
    return sctor;
}

/**************************************
 * Prepare for generating obj file.
 */

__gshared Outbuffer objbuf;

void obj_start(char *srcfile)
{
    //printf("obj_start()\n");

    rtlsym_reset();
    clearStringTab();

    version (Windows)
    {
        // Produce Ms COFF files for 64 bit code, OMF for 32 bit code
        assert(objbuf.size() == 0);
        objmod = global.params.mscoff ? MsCoffObj.init(&objbuf, srcfile, null)
                                      :       Obj.init(&objbuf, srcfile, null);
    }
    else
    {
        objmod = Obj.init(&objbuf, srcfile, null);
    }

    el_reset();
    cg87_reset();
    out_reset();
}


void obj_end(Library library, File *objfile)
{
    const(char)* objfilename = objfile.name.toChars();
    objmod.term(objfilename);
    //delete objmod;
    objmod = null;

    if (library)
    {
        // Transfer image to library
        library.addObject(objfilename, objbuf.buf[0 .. objbuf.p - objbuf.buf]);
        objbuf.buf = null;
    }
    else
    {
        // Transfer image to file
        objfile.setbuffer(objbuf.buf, objbuf.p - objbuf.buf);
        objbuf.buf = null;

        ensurePathToNameExists(Loc.initial, objfilename);

        //printf("write obj %s\n", objfilename);
        writeFile(Loc.initial, objfile);
    }
    objbuf.pend = null;
    objbuf.p = null;
}

bool obj_includelib(const(char)* name)
{
    return objmod.includelib(name);
}

void obj_startaddress(Symbol *s)
{
    return objmod.startaddress(s);
}

bool obj_linkerdirective(const(char)* directive)
{
    return objmod.linkerdirective(directive);
}


/**************************************
 * Generate .obj file for Module.
 */

void genObjFile(Module m, bool multiobj)
{
    //EEcontext *ee = env.getEEcontext();

    //printf("Module.genobjfile(multiobj = %d) %s\n", multiobj, m.toChars());

    if (m.ident == Id.entrypoint)
    {
        bool v = global.params.verbose;
        global.params.verbose = false;

        foreach (member; *m.members)
        {
            //printf("toObjFile %s %s\n", member.kind(), member.toChars());
            toObjFile(member, global.params.multiobj);
        }

        global.params.verbose = v;
        return;
    }

    lastmname = cast(char*)m.srcfile.toChars();

    objmod.initfile(lastmname, null, m.toPrettyChars());

    eictor = null;
    ictorlocalgot = null;
    sctors.setDim(0);
    ectorgates.setDim(0);
    sdtors.setDim(0);
    ssharedctors.setDim(0);
    esharedctorgates.setDim(0);
    sshareddtors.setDim(0);
    stests.setDim(0);

    if (m.doppelganger)
    {
        /* Generate a reference to the moduleinfo, so the module constructors
         * and destructors get linked in.
         */
        Module mod = m.aimports[0];
        assert(mod);
        if (mod.sictor || mod.sctor || mod.sdtor || mod.ssharedctor || mod.sshareddtor)
        {
            Symbol *s = toSymbol(mod);
            //objextern(s);
            //if (!s.Sxtrnnum) objextdef(s.Sident);
            if (!s.Sxtrnnum)
            {
                //printf("%s\n", s.Sident);
//#if 0 /* This should work, but causes optlink to fail in common/newlib.asm */
//                objextdef(s.Sident);
//#else
                Symbol *sref = symbol_generate(SCstatic, type_fake(TYnptr));
                sref.Sfl = FLdata;
                scope dtb = new DtBuilder();
                dtb.xoff(s, 0, TYnptr);
                sref.Sdt = dtb.finish();
                outdata(sref);
//#endif
            }
        }
    }

    if (global.params.cov)
    {
        /* Create coverage identifier:
         *  uint[numlines] __coverage;
         */
        m.cov = toSymbolX(m, "__coverage", SCstatic, type_fake(TYint), "Z");
        m.cov.Sflags |= SFLhidden;
        m.cov.Stype.Tmangle = mTYman_d;
        m.cov.Sfl = FLdata;

        scope dtb = new DtBuilder();
        dtb.nzeros(4 * m.numlines);
        m.cov.Sdt = dtb.finish();

        outdata(m.cov);

        m.covb = cast(uint *)calloc((m.numlines + 32) / 32, (*m.covb).sizeof);
    }

    foreach (member; *m.members)
    {
        //printf("toObjFile %s %s\n", member.kind(), member.toChars());
        toObjFile(member, multiobj);
    }

    if (global.params.cov)
    {
        /* Generate
         *  private bit[numlines] __bcoverage;
         */
        Symbol *bcov = symbol_calloc("__bcoverage");
        bcov.Stype = type_fake(TYuint);
        bcov.Stype.Tcount++;
        bcov.Sclass = SCstatic;
        bcov.Sfl = FLdata;

        scope dtb = new DtBuilder();
        dtb.nbytes((m.numlines + 32) / 32 * (*m.covb).sizeof, cast(char *)m.covb);
        bcov.Sdt = dtb.finish();

        outdata(bcov);

        free(m.covb);
        m.covb = null;

        /* Generate:
         *  _d_cover_register(uint[] __coverage, BitArray __bcoverage, string filename);
         * and prepend it to the static constructor.
         */

        /* t will be the type of the functions generated:
         *      extern (C) void func();
         */
        type *t = type_function(TYnfunc, null, 0, false, tstypes[TYvoid]);
        t.Tmangle = mTYman_c;

        m.sictor = toSymbolX(m, "__modictor", SCglobal, t, "FZv");
        cstate.CSpsymtab = &m.sictor.Sfunc.Flocsym;
        localgot = ictorlocalgot;

        elem *ecov  = el_pair(TYdarray, el_long(TYsize_t, m.numlines), el_ptr(m.cov));
        elem *ebcov = el_pair(TYdarray, el_long(TYsize_t, m.numlines), el_ptr(bcov));

        if (config.exe == EX_WIN64)
        {
            ecov  = addressElem(ecov,  Type.tvoid.arrayOf(), false);
            ebcov = addressElem(ebcov, Type.tvoid.arrayOf(), false);
        }

        elem *efilename = toEfilename(m);
        if (config.exe == EX_WIN64)
            efilename = addressElem(efilename, Type.tstring, true);

        elem *e = el_params(
                      el_long(TYuchar, global.params.covPercent),
                      ecov,
                      ebcov,
                      efilename,
                      null);
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
            b.BC = BCret;
            b.Belem = eictor;
            m.sictor.Sfunc.Fstartline.Sfilename = m.arg;
            m.sictor.Sfunc.Fstartblock = b;
            writefunc(m.sictor);
        }

        m.sctor = callFuncsAndGates(m, &sctors, &ectorgates, "__modctor");
        m.sdtor = callFuncsAndGates(m, &sdtors, null, "__moddtor");

        m.ssharedctor = callFuncsAndGates(m, &ssharedctors, cast(StaticDtorDeclarations *)&esharedctorgates, "__modsharedctor");
        m.sshareddtor = callFuncsAndGates(m, &sshareddtors, null, "__modshareddtor");
        m.stest = callFuncsAndGates(m, &stests, null, "__modtest");

        if (m.doppelganger)
            genModuleInfo(m);
    }

    if (m.doppelganger)
    {
        objc.generateModuleInfo();
        objmod.termfile();
        return;
    }

     /* Generate module info for templates and -cov.
     *  Don't generate ModuleInfo if `object.ModuleInfo` is not declared or
     *  explicitly disabled through compiler switches such as `-betterC`.
     */
    if (global.params.useModuleInfo && Module.moduleinfo /*|| needModuleInfo()*/)
        genModuleInfo(m);

    objmod.termfile();
}



/**************************************
 * Search for a druntime array op
 */
bool isDruntimeArrayOp(Identifier ident)
{
    /* Some of the array op functions are written as library functions,
     * presumably to optimize them with special CPU vector instructions.
     * List those library functions here, in alpha order.
     */
    __gshared const(char)*[143] libArrayopFuncs =
    [
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
    ];
    const(char)* name = ident.toChars();
    int i = binary(name, libArrayopFuncs.ptr, libArrayopFuncs.length);
    if (i != -1)
        return true;

    debug    // Make sure our array is alphabetized
    {
        foreach (s; libArrayopFuncs)
        {
            if (strcmp(name, s) == 0)
                assert(0);
        }
    }
    return false;
}


/* ================================================================== */

UnitTestDeclaration needsDeferredNested(FuncDeclaration fd)
{
    while (fd && fd.isNested())
    {
        FuncDeclaration fdp = fd.toParent2().isFuncDeclaration();
        if (!fdp)
            break;
        if (UnitTestDeclaration udp = fdp.isUnitTestDeclaration())
            return udp.semanticRun < PASS.obj ? udp : null;
        fd = fdp;
    }
    return null;
}


void FuncDeclaration_toObjFile(FuncDeclaration fd, bool multiobj)
{
    ClassDeclaration cd = fd.parent.isClassDeclaration();
    //printf("FuncDeclaration.toObjFile(%p, %s.%s)\n", fd, fd.parent.toChars(), fd.toChars());

    //if (type) printf("type = %s\n", type.toChars());
    version (none)
    {
        //printf("line = %d\n", getWhere() / LINEINC);
        EEcontext *ee = env.getEEcontext();
        if (ee.EEcompile == 2)
        {
            if (ee.EElinnum < (getWhere() / LINEINC) ||
                ee.EElinnum > (endwhere / LINEINC)
               )
                return;             // don't compile this function
            ee.EEfunc = toSymbol(this);
        }
    }

    if (fd.semanticRun >= PASS.obj) // if toObjFile() already run
        return;

    if (fd.type && fd.type.ty == Tfunction && (cast(TypeFunction)fd.type).next is null)
        return;

    // If errors occurred compiling it, such as https://issues.dlang.org/show_bug.cgi?id=6118
    if (fd.type && fd.type.ty == Tfunction && (cast(TypeFunction)fd.type).next.ty == Terror)
        return;

    if (fd.semantic3Errors)
        return;

    if (global.errors)
        return;

    if (!fd.fbody)
        return;

    UnitTestDeclaration ud = fd.isUnitTestDeclaration();
    if (ud && !global.params.useUnitTests)
        return;

    if (multiobj && !fd.isStaticDtorDeclaration() && !fd.isStaticCtorDeclaration())
    {
        obj_append(fd);
        return;
    }

    if (fd.semanticRun == PASS.semanticdone)
    {
        /* What happened is this function failed semantic3() with errors,
         * but the errors were gagged.
         * Try to reproduce those errors, and then fail.
         */
        fd.error("errors compiling the function");
        return;
    }
    assert(fd.semanticRun == PASS.semantic3done);
    assert(fd.ident != Id.empty);

    for (FuncDeclaration fd2 = fd; fd2; )
    {
        if (fd2.inNonRoot())
            return;
        if (fd2.isNested())
            fd2 = fd2.toParent2().isFuncDeclaration();
        else
            break;
    }

    if (UnitTestDeclaration udp = needsDeferredNested(fd))
    {
        /* Can't do unittest's out of order, they are order dependent in that their
         * execution is done in lexical order.
         */
        udp.deferredNested.push(fd);
        //printf("%s @[%s]\n\t-. pushed to unittest @[%s]\n",
        //    fd.toPrettyChars(), fd.loc.toChars(), udp.loc.toChars());
        return;
    }

    if (fd.isArrayOp && isDruntimeArrayOp(fd.ident))
    {
        // Implementation is in druntime
        return;
    }

    // start code generation
    fd.semanticRun = PASS.obj;

    if (global.params.verbose)
        message("function  %s", fd.toPrettyChars());

    Symbol *s = toSymbol(fd);
    func_t *f = s.Sfunc;

    // tunnel type of "this" to debug info generation
    if (AggregateDeclaration ad = fd.parent.isAggregateDeclaration())
    {
        .type* t = Type_toCtype(ad.getType());
        if (cd)
            t = t.Tnext; // skip reference
        f.Fclass = cast(Classsym *)t;
    }

    /* This is done so that the 'this' pointer on the stack is the same
     * distance away from the function parameters, so that an overriding
     * function can call the nested fdensure or fdrequire of its overridden function
     * and the stack offsets are the same.
     */
    if (fd.isVirtual() && (fd.fensure || fd.frequire))
        f.Fflags3 |= Ffakeeh;

    if (fd.eh_none)
        // Same as config.ehmethod==EH_NONE, but only for this function
        f.Fflags3 |= Feh_none;

    s.Sclass = global.params.isOSX ? SCcomdat : SCglobal;
    for (Dsymbol p = fd.parent; p; p = p.parent)
    {
        if (p.isTemplateInstance())
        {
            s.Sclass = SCcomdat;
            break;
        }
    }

    /* Vector operations should be comdat's
     */
    if (fd.isArrayOp)
        s.Sclass = SCcomdat;

    if (fd.inlinedNestedCallees)
    {
        /* https://issues.dlang.org/show_bug.cgi?id=15333
         * If fd contains inlined expressions that come from
         * nested function bodies, the enclosing of the functions must be
         * generated first, in order to calculate correct frame pointer offset.
         */
        foreach (fdc; *fd.inlinedNestedCallees)
        {
            FuncDeclaration fp = fdc.toParent2().isFuncDeclaration();
            if (fp && fp.semanticRun < PASS.obj)
            {
                toObjFile(fp, multiobj);
            }
        }
    }

    if (fd.isNested())
    {
        //if (!(config.flags3 & CFG3pic))
        //    s.Sclass = SCstatic;
        f.Fflags3 |= Fnested;

        /* The enclosing function must have its code generated first,
         * in order to calculate correct frame pointer offset.
         */
        FuncDeclaration fdp = fd.toParent2().isFuncDeclaration();
        if (fdp && fdp.semanticRun < PASS.obj)
        {
            toObjFile(fdp, multiobj);
        }
    }
    else
    {
        specialFunctions(objmod, fd);
    }

    symtab_t *symtabsave = cstate.CSpsymtab;
    cstate.CSpsymtab = &f.Flocsym;

    // Find module m for this function
    Module m = null;
    for (Dsymbol p = fd.parent; p; p = p.parent)
    {
        m = p.isModule();
        if (m)
            break;
    }

    Dsymbols deferToObj;                   // write these to OBJ file later
    Array!(elem*) varsInScope;
    Label*[void*] labels = null;
    IRState irs = IRState(m, fd, &varsInScope, &deferToObj, &labels, &global.params);

    Symbol *shidden = null;
    Symbol *sthis = null;
    tym_t tyf = tybasic(s.Stype.Tty);
    //printf("linkage = %d, tyf = x%x\n", linkage, tyf);
    int reverse = tyrevfunc(s.Stype.Tty);

    assert(fd.type.ty == Tfunction);
    TypeFunction tf = cast(TypeFunction)fd.type;
    RET retmethod = retStyle(tf, fd.needThis());
    if (retmethod == RET.stack)
    {
        // If function returns a struct, put a pointer to that
        // as the first argument
        .type *thidden = Type_toCtype(tf.next.pointerTo());
        char[5+4+1] hiddenparam = void;
        __gshared int hiddenparami;    // how many we've generated so far

        const(char)* name;
        if (fd.nrvo_can && fd.nrvo_var)
            name = fd.nrvo_var.ident.toChars();
        else
        {
            sprintf(hiddenparam.ptr, "__HID%d", ++hiddenparami);
            name = hiddenparam.ptr;
        }
        shidden = symbol_name(name, SCparameter, thidden);
        shidden.Sflags |= SFLtrue | SFLfree;
        if (fd.nrvo_can && fd.nrvo_var && fd.nrvo_var.nestedrefs.dim)
            type_setcv(&shidden.Stype, shidden.Stype.Tty | mTYvolatile);
        irs.shidden = shidden;
        fd.shidden = shidden;
    }
    else
    {
        // Register return style cannot make nrvo.
        // Auto functions keep the nrvo_can flag up to here,
        // so we should eliminate it before entering backend.
        fd.nrvo_can = 0;
    }

    if (fd.vthis)
    {
        assert(!fd.vthis.csym);
        sthis = toSymbol(fd.vthis);
        irs.sthis = sthis;
        if (!(f.Fflags3 & Fnested))
            f.Fflags3 |= Fmember;
    }

    // Estimate number of parameters, pi
    size_t pi = (fd.v_arguments !is null);
    if (fd.parameters)
        pi += fd.parameters.dim;

    // Create a temporary buffer, params[], to hold function parameters
    Symbol*[10] paramsbuf = void;
    Symbol **params = paramsbuf.ptr;    // allocate on stack if possible
    if (pi + 2 > paramsbuf.length)      // allow extra 2 for sthis and shidden
    {
        params = cast(Symbol **)malloc((pi + 2) * (Symbol *).sizeof);
        assert(params);
    }

    // Get the actual number of parameters, pi, and fill in the params[]
    pi = 0;
    if (fd.v_arguments)
    {
        params[pi] = toSymbol(fd.v_arguments);
        pi += 1;
    }
    if (fd.parameters)
    {
        foreach (i, v; *fd.parameters)
        {
            //printf("param[%d] = %p, %s\n", i, v, v.toChars());
            assert(!v.csym);
            params[pi + i] = toSymbol(v);
        }
        pi += fd.parameters.dim;
    }

    if (reverse)
    {
        // Reverse params[] entries
        foreach (i, sptmp; params[0 .. pi/2])
        {
            params[i] = params[pi - 1 - i];
            params[pi - 1 - i] = sptmp;
        }
    }

    if (shidden)
    {
        // shidden becomes last parameter
        //params[pi] = shidden;

        // shidden becomes first parameter
        memmove(params + 1, params, pi * (params[0]).sizeof);
        params[0] = shidden;

        pi++;
    }


    if (sthis)
    {
        // sthis becomes last parameter
        //params[pi] = sthis;

        // sthis becomes first parameter
        memmove(params + 1, params, pi * (params[0]).sizeof);
        params[0] = sthis;

        pi++;
    }

    if ((global.params.isLinux || global.params.isOSX || global.params.isFreeBSD || global.params.isDragonFlyBSD || global.params.isSolaris) &&
         fd.linkage != LINK.d && shidden && sthis)
    {
        /* swap shidden and sthis
         */
        Symbol *sp = params[0];
        params[0] = params[1];
        params[1] = sp;
    }

    foreach (sp; params[0 .. pi])
    {
        sp.Sclass = SCparameter;
        sp.Sflags &= ~SFLspill;
        sp.Sfl = FLpara;
        symbol_add(sp);
    }

    // Determine register assignments
    if (pi)
    {
        FuncParamRegs fpr = FuncParamRegs.create(tyf);

        foreach (sp; params[0 .. pi])
        {
            if (fpr.alloc(sp.Stype, sp.Stype.Tty, &sp.Spreg, &sp.Spreg2))
            {
                sp.Sclass = (config.exe == EX_WIN64) ? SCshadowreg : SCfastpar;
                sp.Sfl = (sp.Sclass == SCshadowreg) ? FLpara : FLfast;
            }
        }
    }

    // Done with params
    if (params != paramsbuf.ptr)
        free(params);
    params = null;

    if (fd.fbody)
    {
        localgot = null;

        Statement sbody = fd.fbody;

        Blockx bx;
        bx.startblock = block_calloc();
        bx.curblock = bx.startblock;
        bx.funcsym = s;
        bx.scope_index = -1;
        bx.classdec = cast(void*)cd;
        bx.member = cast(void*)fd;
        bx._module = cast(void*)fd.getModule();
        irs.blx = &bx;

        // Initialize argptr
        if (fd.v_argptr)
        {
            // Declare va_argsave
            if (global.params.is64bit &&
                !global.params.isWindows)
            {
                type *t = type_struct_class("__va_argsave_t", 16, 8 * 6 + 8 * 16 + 8 * 3, null, null, false, false, true, false);
                // The backend will pick this up by name
                Symbol *sv = symbol_name("__va_argsave", SCauto, t);
                sv.Stype.Tty |= mTYvolatile;
                symbol_add(sv);
            }

            Symbol *sa = toSymbol(fd.v_argptr);
            symbol_add(sa);
            elem *e = el_una(OPva_start, TYnptr, el_ptr(sa));
            block_appendexp(irs.blx.curblock, e);
        }

        /* Doing this in semantic3() caused all kinds of problems:
         * 1. couldn't reliably get the final mangling of the function name due to fwd refs
         * 2. impact on function inlining
         * 3. what to do when writing out .di files, or other pretty printing
         */
        if (global.params.trace && !fd.isCMain() && !fd.naked)
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
            StringExp se = StringExp.create(Loc.initial, s.Sident.ptr);
            se.type = Type.tstring;
            se.type = se.type.typeSemantic(Loc.initial, null);
            Expressions *exps = new Expressions();
            exps.push(se);
            FuncDeclaration fdpro = FuncDeclaration.genCfunc(null, Type.tvoid, "trace_pro");
            Expression ec = VarExp.create(Loc.initial, fdpro);
            Expression e = CallExp.create(Loc.initial, ec, exps);
            e.type = Type.tvoid;
            Statement sp = ExpStatement.create(fd.loc, e);

            FuncDeclaration fdepi = FuncDeclaration.genCfunc(null, Type.tvoid, "_c_trace_epi");
            ec = VarExp.create(Loc.initial, fdepi);
            e = CallExp.create(Loc.initial, ec);
            e.type = Type.tvoid;
            Statement sf = ExpStatement.create(fd.loc, e);

            Statement stf;
            if (sbody.blockExit(fd, false) == BE.fallthru)
                stf = CompoundStatement.create(Loc.initial, sbody, sf);
            else
                stf = TryFinallyStatement.create(Loc.initial, sbody, sf);
            sbody = CompoundStatement.create(Loc.initial, sp, stf);
        }

        if (fd.interfaceVirtual)
        {
            // Adjust the 'this' pointer instead of using a thunk
            assert(irs.sthis);
            elem *ethis = el_var(irs.sthis);
            elem *e = el_bin(OPminass, TYnptr, ethis, el_long(TYsize_t, fd.interfaceVirtual.offset));
            block_appendexp(irs.blx.curblock, e);
        }

        buildClosure(fd, &irs);

        if (config.ehmethod == EHmethod.EH_WIN32 && fd.isSynchronized() && cd &&
            !fd.isStatic() && !sbody.usesEH() && !global.params.trace)
        {
            /* The "jmonitor" hack uses an optimized exception handling frame
             * which is a little shorter than the more general EH frame.
             */
            s.Sfunc.Fflags3 |= Fjmonitor;
        }

        Statement_toIR(sbody, &irs);
        bx.curblock.BC = BCret;

        f.Fstartblock = bx.startblock;
//      einit = el_combine(einit,bx.init);

        if (fd.isCtorDeclaration())
        {
            assert(sthis);
            foreach (b; BlockRange(f.Fstartblock))
            {
                if (b.BC == BCret)
                {
                    b.BC = BCretexp;
                    b.Belem = el_combine(b.Belem, el_var(sthis));
                }
            }
        }
        if (config.ehmethod == EHmethod.EH_NONE || f.Fflags3 & Feh_none)
            insertFinallyBlockGotos(f.Fstartblock);
        else if (config.ehmethod == EHmethod.EH_DWARF)
            insertFinallyBlockCalls(f.Fstartblock);
    }

    // If static constructor
    if (fd.isSharedStaticCtorDeclaration())        // must come first because it derives from StaticCtorDeclaration
    {
        ssharedctors.push(s);
    }
    else if (fd.isStaticCtorDeclaration())
    {
        sctors.push(s);
    }

    // If static destructor
    if (fd.isSharedStaticDtorDeclaration())        // must come first because it derives from StaticDtorDeclaration
    {
        SharedStaticDtorDeclaration fs = fd.isSharedStaticDtorDeclaration();
        assert(fs);
        if (fs.vgate)
        {
            /* Increment destructor's vgate at construction time
             */
            esharedctorgates.push(fs);
        }

        sshareddtors.shift(s);
    }
    else if (fd.isStaticDtorDeclaration())
    {
        StaticDtorDeclaration fs = fd.isStaticDtorDeclaration();
        assert(fs);
        if (fs.vgate)
        {
            /* Increment destructor's vgate at construction time
             */
            ectorgates.push(fs);
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

    if (fd.isExport())
        objmod.export_symbol(s, cast(uint)Para.offset);

    foreach (sd; *irs.deferToObj)
    {
        toObjFile(sd, false);
    }

    if (ud)
    {
        foreach (fdn; ud.deferredNested)
        {
            toObjFile(fdn, false);
        }
    }

    if (global.params.isLinux || global.params.isOSX || global.params.isFreeBSD ||
        global.params.isDragonFlyBSD || global.params.isSolaris)
    {
        // A hack to get a pointer to this function put in the .dtors segment
        if (fd.ident && memcmp(fd.ident.toChars(), "_STD".ptr, 4) == 0)
            objmod.staticdtor(s);
    }

    if (irs.startaddress)
    {
        //printf("Setting start address\n");
        objmod.startaddress(irs.startaddress);
    }
}


/*******************************************
 * Detect special functions like `main()` and do special handling for them,
 * like special mangling, including libraries, setting the storage class, etc.
 * `objmod` and `fd` are updated.
 *
 * Params:
 *      objmod = object module
 *      fd = function symbol
 */
private void specialFunctions(Obj objmod, FuncDeclaration fd)
{
    const(char)* libname = (global.params.symdebug)
                            ? global.params.debuglibname
                            : global.params.defaultlibname;

    Symbol* s = fd.toSymbol();  // backend symbol corresponding to fd

    // Pull in RTL startup code (but only once)
    if (fd.isMain() && onlyOneMain(fd.loc))
    {
        if (global.params.isLinux || global.params.isOSX || global.params.isFreeBSD ||
            global.params.isOpenBSD || global.params.isDragonFlyBSD || global.params.isSolaris)
        {
            objmod.external_def("_main");
        }
        else if (global.params.mscoff)
        {
            objmod.external_def("main");
        }
        else if (config.exe == EX_WIN32)
        {
            objmod.external_def("_main");
            objmod.external_def("__acrtused_con");
        }
        if (libname)
            objmod.includelib(libname);
        s.Sclass = SCglobal;
    }
    else if (fd.isRtInit())
    {
        if (global.params.isLinux || global.params.isOSX || global.params.isFreeBSD ||
            global.params.isOpenBSD || global.params.isDragonFlyBSD || global.params.isSolaris ||
            global.params.mscoff)
        {
            objmod.ehsections();   // initialize exception handling sections
        }
    }
    else if (fd.isCMain())
    {
        if (global.params.mscoff)
        {
            if (global.params.mscrtlib && global.params.mscrtlib[0])
                objmod.includelib(global.params.mscrtlib);
            objmod.includelib("OLDNAMES");
        }
        else if (config.exe == EX_WIN32)
        {
            objmod.external_def("__acrtused_con");        // bring in C startup code
            objmod.includelib("snn.lib");          // bring in C runtime library
        }
        s.Sclass = SCglobal;
    }
    else if (global.params.isWindows && fd.isWinMain() && onlyOneMain(fd.loc))
    {
        if (global.params.mscoff)
        {
            objmod.includelib("uuid");
            if (global.params.mscrtlib && global.params.mscrtlib[0])
                objmod.includelib(global.params.mscrtlib);
            objmod.includelib("OLDNAMES");
        }
        else
        {
            objmod.external_def("__acrtused");
        }
        if (libname)
            objmod.includelib(libname);
        s.Sclass = SCglobal;
    }

    // Pull in RTL startup code
    else if (global.params.isWindows && fd.isDllMain() && onlyOneMain(fd.loc))
    {
        if (global.params.mscoff)
        {
            objmod.includelib("uuid");
            if (global.params.mscrtlib && global.params.mscrtlib[0])
                objmod.includelib(global.params.mscrtlib);
            objmod.includelib("OLDNAMES");
        }
        else
        {
            objmod.external_def("__acrtused_dll");
        }
        if (libname)
            objmod.includelib(libname);
        s.Sclass = SCglobal;
    }
    else if (fd.ident == Id.tls_get_addr && fd.linkage == LINK.d)
    {
        // TODO: Change linkage in druntime to extern(C).
        s.Sfunc.Fredirect = cast(char*)Id.tls_get_addr.toChars();
    }
}


bool onlyOneMain(Loc loc)
{
    __gshared Loc lastLoc;
    __gshared bool hasMain = false;
    if (hasMain)
    {
        const(char)* msg = "";
        if (global.params.addMain)
            msg = ", -main switch added another `main()`";
        const(char)* otherMainNames = "";
        if (config.exe == EX_WIN32 || config.exe == EX_WIN64)
            otherMainNames = ", `WinMain`, or `DllMain`";
        error(loc, "only one `main`%s allowed%s. Previously found `main` at %s",
            otherMainNames, msg, lastLoc.toChars());
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

uint totym(Type tx)
{
    uint t;
    switch (tx.ty)
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
        case Tdchar:
            t = (global.params.symdebug == 1 || !global.params.isWindows) ? TYdchar : TYulong;
            break;

        case Taarray:   t = TYaarray;   break;
        case Tclass:
        case Treference:
        case Tpointer:  t = TYnptr;     break;
        case Tdelegate: t = TYdelegate; break;
        case Tarray:    t = TYdarray;   break;
        case Tsarray:   t = TYstruct;   break;

        case Tstruct:
            t = TYstruct;
            if (tx.toDsymbol(null).ident == Id.__c_long_double)
                t = TYdouble;
            break;

        case Tenum:
        {
            Type tb = tx.toBasetype();
            const id = tx.toDsymbol(null).ident;
            if (id == Id.__c_long)
                t = tb.ty == Tint32 ? TYlong : TYllong;
            else if (id == Id.__c_ulong)
                t = tb.ty == Tuns32 ? TYulong : TYullong;
            else if (id == Id.__c_long_double)
                t = TYdouble;
            else
                t = totym(tb);
            break;
        }

        case Tident:
        case Ttypeof:
            //printf("ty = %d, '%s'\n", tx.ty, tx.toChars());
            error(Loc.initial, "forward reference of `%s`", tx.toChars());
            t = TYint;
            break;

        case Tnull:
            t = TYnptr;
            break;

        case Tvector:
        {
            TypeVector tv = cast(TypeVector)tx;
            TypeBasic tb = tv.elementType();
            const s32 = tv.alignsize() == 32;   // if 32 byte, 256 bit vector
            switch (tb.ty)
            {
                case Tvoid:
                case Tint8:     t = s32 ? TYschar32  : TYschar16;  break;
                case Tuns8:     t = s32 ? TYuchar32  : TYuchar16;  break;
                case Tint16:    t = s32 ? TYshort16  : TYshort8;   break;
                case Tuns16:    t = s32 ? TYushort16 : TYushort8;  break;
                case Tint32:    t = s32 ? TYlong8    : TYlong4;    break;
                case Tuns32:    t = s32 ? TYulong8   : TYulong4;   break;
                case Tint64:    t = s32 ? TYllong4   : TYllong2;   break;
                case Tuns64:    t = s32 ? TYullong4  : TYullong2;  break;
                case Tfloat32:  t = s32 ? TYfloat8   : TYfloat4;   break;
                case Tfloat64:  t = s32 ? TYdouble4  : TYdouble2;  break;
                default:
                    assert(0);
            }
            assert(global.params.is64bit || global.params.isOSX);
            break;
        }

        case Tfunction:
        {
            TypeFunction tf = cast(TypeFunction)tx;
            final switch (tf.linkage)
            {
                case LINK.windows:
                    if (global.params.is64bit)
                        goto Lc;
                    t = (tf.varargs == 1) ? TYnfunc : TYnsfunc;
                    break;

                case LINK.pascal:
                    t = (tf.varargs == 1) ? TYnfunc : TYnpfunc;
                    break;

                case LINK.c:
                case LINK.cpp:
                case LINK.objc:
                Lc:
                    t = TYnfunc;
                    if (global.params.isWindows)
                    {
                    }
                    else if (!global.params.is64bit && retStyle(tf, false) == RET.stack)
                        t = TYhfunc;
                    break;

                case LINK.d:
                    t = (tf.varargs == 1) ? TYnfunc : TYjfunc;
                    break;

                case LINK.default_:
                case LINK.system:
                    printf("linkage = %d\n", tf.linkage);
                    assert(0);
            }
            if (tf.isnothrow)
                t |= mTYnothrow;
            return t;
        }
        default:
            //printf("ty = %d, '%s'\n", tx.ty, tx.toChars());
            assert(0);
    }

    // Add modifiers
    switch (tx.mod)
    {
        case 0:
            break;
        case MODFlags.const_:
        case MODFlags.wild:
        case MODFlags.wildconst:
            t |= mTYconst;
            break;
        case MODFlags.shared_:
            t |= mTYshared;
            break;
        case MODFlags.shared_ | MODFlags.const_:
        case MODFlags.shared_ | MODFlags.wild:
        case MODFlags.shared_ | MODFlags.wildconst:
            t |= mTYshared | mTYconst;
            break;
        case MODFlags.immutable_:
            t |= mTYimmutable;
            break;
        default:
            assert(0);
    }

    return t;
}

/**************************************
 */

Symbol *toSymbol(Type t)
{
    if (t.ty == Tclass)
    {
        return toSymbol((cast(TypeClass)t).sym);
    }
    assert(0);
}


/**************************************
 * Generate elem that is a dynamic array slice of the module file name.
 */

elem *toEfilename(Module m)
{
    //printf("toEfilename(%s)\n", m.toChars());
    const(char)* id = m.srcfile.toChars();
    size_t len = strlen(id);

    if (!m.sfilename)
    {
        // Put out as a static array
        m.sfilename = toStringSymbol(id, len, 1);
    }

    // Turn static array into dynamic array
    return el_pair(TYdarray, el_long(TYsize_t, len), el_ptr(m.sfilename));
}

elem *toEfilenamePtr(Module m)
{
    //printf("toEfilenamePtr(%s)\n", m.toChars());
    const(char)* id = m.srcfile.toChars();
    size_t len = strlen(id);
    Symbol* s = toStringSymbol(id, len, 1);
    return el_ptr(s);
}
