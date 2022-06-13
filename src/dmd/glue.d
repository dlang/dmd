/**
 * Generate the object file for function declarations and critical sections.
 *
 * Copyright:   Copyright (C) 1999-2022 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
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
import dmd.common.outbuffer;
import dmd.root.rmem;
import dmd.root.string;

import dmd.backend.cdef;
import dmd.backend.cc;
import dmd.backend.code;
import dmd.backend.dt;
import dmd.backend.el;
import dmd.backend.global;
import dmd.backend.obj;
import dmd.backend.oper;
import dmd.backend.rtlsym;
import dmd.backend.symtab;
import dmd.backend.ty;
import dmd.backend.type;

import dmd.aggregate;
import dmd.arraytypes;
import dmd.astenums;
import dmd.blockexit;
import dmd.dclass;
import dmd.declaration;
import dmd.dmangle;
import dmd.dmdparams;
import dmd.dmodule;
import dmd.dmsc;
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

alias symbols = Array!(Symbol*);
alias toSymbol = dmd.tocsym.toSymbol;

/**
 * Generate code for `modules` and write objects/libraries
 *
 * Params:
 *  modules = array of `Module`s to generate code for
 *  libmodules = array of objects/libraries already generated (passed on command line)
 *  libname = {.lib,.a} file output name
 *  objdir = directory to write object files to
 *  lib = write library file instead of object file(s)
 *  obj = generate object files
 *  oneobj = write one object file instead of multiple ones
 *  multiobj = break one object file into multiple ones
 *  verbose = print progress message when generatig code
 */
void generateCodeAndWrite(Module[] modules, const(char)*[] libmodules,
                          const(char)[] libname, const(char)[] objdir,
                          bool lib, bool obj, bool oneobj, bool multiobj,
                          bool verbose)
{
    Library library = null;
    if (lib)
    {
        library = Library.factory();
        library.setFilename(objdir, libname);
        // Add input object and input library files to output library
        foreach (p; libmodules)
            library.addObject(p.toDString(), null);
    }

    if (!obj)
    {
    }
    else if (oneobj)
    {
        OutBuffer objbuf;
        Module firstm;    // first module we generate code for
        foreach (m; modules)
        {
            if (m.filetype == FileType.dhdr)
                continue;
            if (!firstm)
            {
                firstm = m;
                obj_start(objbuf, m.srcfile.toChars());
            }
            if (verbose)
                message("code      %s", m.toChars());
            genObjFile(m, false);
        }
        if (!global.errors && firstm)
        {
            obj_end(objbuf, library, firstm.objfile.toChars());
        }
    }
    else
    {
        OutBuffer objbuf;
        foreach (m; modules)
        {
            if (m.filetype == FileType.dhdr)
                continue;
            if (verbose)
                message("code      %s", m.toChars());
            obj_start(objbuf, m.srcfile.toChars());
            genObjFile(m, multiobj);
            obj_end(objbuf, library, m.objfile.toChars());
            obj_write_deferred(objbuf, library, glue.obj_symbols_towrite);
            if (global.errors && !lib)
                m.deleteObjFile();
        }
    }
    if (lib && !global.errors)
        library.write();
}

extern (C++):

//extern
__gshared Symbol* bzeroSymbol;        /// common location for immutable zeros

struct Glue
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

    const(char)* lastmname;
    Dsymbols obj_symbols_towrite;
}

private __gshared Glue glue;


/**************************************
 * Append s to list of object files to generate later.
 * Only happens with multiobj.
 */

void obj_append(Dsymbol s)
{
    //printf("deferred: %s\n", s.toChars());
    glue.obj_symbols_towrite.push(s);
}

/*******************************
 * Generating multiple object files, one per Dsymbol
 * in symbols_towrite[].
 * Params:
 *      library = library to write object files to
 *      symbols_towrite = array of Dsymbols
 */
extern (D)
private void obj_write_deferred(ref OutBuffer objbuf, Library library, ref Dsymbols symbols_towrite)
{
    // this array can grow during the loop; do not replace with foreach
    for (size_t i = 0; i < symbols_towrite.length; ++i)
    {
        Dsymbol s = symbols_towrite[i];
        Module m = s.getModule();

        const(char)* mname;
        if (m)
        {
            mname = m.srcfile.toChars();
            glue.lastmname = mname;
        }
        else
        {
            //mname = s.ident.toChars();
            mname = glue.lastmname;
            assert(mname);
        }

        obj_start(objbuf, mname);

        __gshared int count;
        count++;                // sequence for generating names

        /* Create a module that's a doppelganger of m, with just
         * enough to be able to create the moduleinfo.
         */
        OutBuffer idbuf;
        idbuf.printf("%s.%d", m ? m.ident.toChars() : mname, count);

        if (!m)
        {
            // it doesn't make sense to make up a module if we don't know where to put the symbol
            //  so output it into its own object file without ModuleInfo
            objmod.initfile(idbuf.peekChars(), null, mname);
            toObjFile(s, false);
            objmod.termfile();
        }
        else
        {
            Identifier id = Identifier.create(idbuf.extractChars());

            Module md = new Module(mname.toDString, id, 0, 0);
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
        namebuf.printf("%s_%x_%x.%.*s", fname, count, hash,
                       cast(int)target.obj_ext.length, target.obj_ext.ptr);
        FileName.free(cast(char *)fname);
        fname = namebuf.extractChars();

        //printf("writing '%s'\n", fname);
        obj_end(objbuf, library, fname);
    }
    glue.obj_symbols_towrite.dim = 0;
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

extern (D)
private Symbol *callFuncsAndGates(Module m, Symbol*[] sctors, StaticDtorDeclaration[] ectorgates,
        const(char)* id)
{
    if (!sctors.length && !ectorgates.length)
        return null;

    Symbol *sctor = null;

    __gshared type *t;
    if (!t)
    {
        /* t will be the type of the functions generated:
         *      extern (C) void func();
         */
        t = type_function(TYnfunc, null, false, tstypes[TYvoid]);
        t.Tmangle = mTYman_c;
    }

    localgot = null;
    sctor = toSymbolX(m, id, SCglobal, t, "FZv");
    cstate.CSpsymtab = &sctor.Sfunc.Flocsym;
    elem *ector = null;

    foreach (f; ectorgates)
    {
        Symbol *s = toSymbol(f.vgate);
        elem *e = el_var(s);
        e = el_bin(OPaddass, TYint, e, el_long(TYint, 1));
        ector = el_combine(ector, e);
    }

    foreach (s; sctors)
    {
        elem *e = el_una(OPucall, TYvoid, el_var(s));
        ector = el_combine(ector, e);
    }

    block *b = block_calloc();
    b.BC = BCret;
    b.Belem = ector;
    sctor.Sfunc.Fstartline.Sfilename = m.arg.xarraydup.ptr;
    sctor.Sfunc.Fstartblock = b;
    writefunc(sctor); // hand off to backend

    return sctor;
}

/**************************************
 * Prepare for generating obj file.
 * Params:
 *      objbuf = write object file contents to this
 *      srcfile = name of the source file
 */

private void obj_start(ref OutBuffer objbuf, const(char)* srcfile)
{
    //printf("obj_start()\n");

    bzeroSymbol = null;
    rtlsym_reset();
    clearStringTab();

    version (Windows)
    {
        // Produce Ms COFF files by default, OMF for -m32omf
        assert(objbuf.length() == 0);
        switch (target.objectFormat())
        {
            case Target.ObjectFormat.coff: objmod = MsCoffObj_init(&objbuf, srcfile, null); break;
            case Target.ObjectFormat.omf:  objmod = OmfObj_init(&objbuf, srcfile, null); break;
            default: assert(0);
        }
    }
    else
    {
        objmod = Obj.initialize(&objbuf, srcfile, null);
    }

    el_reset();
    cg87_reset();
    out_reset();
    objc.reset();
}


/****************************************
 * Finish creating the object module and writing it to objbuf[].
 * Then either write the object module to an actual file,
 * or add it to a library.
 * Params:
 *      objbuf = contains the generated contents of the object file
 *      objfilename = what to call the object module
 *      library = if non-null, add object module to this library
 */
private void obj_end(ref OutBuffer objbuf, Library library, const(char)* objfilename)
{
    objmod.term(objfilename);
    //delete objmod;
    objmod = null;

    if (library)
    {
        // Transfer ownership of image buffer to library
        library.addObject(objfilename.toDString(), cast(ubyte[]) objbuf.extractSlice[]);
    }
    else
    {
        //printf("write obj %s\n", objfilename);
        writeFile(Loc.initial, objfilename.toDString, objbuf[]);

        // For non-libraries, the object buffer should be cleared to
        // avoid repetitions.
        objbuf.destroy();
    }
}

bool obj_includelib(const(char)* name) nothrow
{
    return objmod.includelib(name);
}

extern(D) bool obj_includelib(const(char)[] name) nothrow
{
    return name.toCStringThen!(n => obj_includelib(n.ptr));
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

private void genObjFile(Module m, bool multiobj)
{
    //EEcontext *ee = env.getEEcontext();

    //printf("Module.genobjfile(multiobj = %d) %s\n", multiobj, m.toChars());

    glue.lastmname = m.srcfile.toChars();

    objmod.initfile(glue.lastmname, null, m.toPrettyChars());

    glue.eictor = null;
    glue.ictorlocalgot = null;
    glue.sctors.setDim(0);
    glue.ectorgates.setDim(0);
    glue.sdtors.setDim(0);
    glue.ssharedctors.setDim(0);
    glue.esharedctorgates.setDim(0);
    glue.sshareddtors.setDim(0);
    glue.stests.setDim(0);

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
                auto dtb = DtBuilder(0);
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

        auto dtb = DtBuilder(0);

        if (m.ctfe_cov)
        {
            // initalize the uint[] __coverage symbol with data from ctfe.
            static extern (C) int comp_uints (const scope void* a, const scope void* b)
                { return (*cast(uint*) a) - (*cast(uint*) b); }

            uint[] sorted_lines = m.ctfe_cov.keys;
            qsort(sorted_lines.ptr, sorted_lines.length, sorted_lines[0].sizeof,
                &comp_uints);

            uint lastLine = 0;
            foreach (line;sorted_lines)
            {
                // zero fill from last line to line.
                if (line)
                {
                    assert(line > lastLine);
                    dtb.nzeros((line - lastLine - 1) * 4);
                }
                dtb.dword(m.ctfe_cov[line]);
                lastLine = line;
            }
            // zero fill from last line to end
            if (m.numlines > lastLine)
                dtb.nzeros((m.numlines - lastLine) * 4);
        }
        else
        {
            dtb.nzeros(4 * m.numlines);
        }
        m.cov.Sdt = dtb.finish();

        outdata(m.cov);

        m.covb = cast(uint *)calloc((m.numlines + 32) / 32, (*m.covb).sizeof);
    }

    for (int i = 0; i < m.members.dim; i++)
    {
        auto member = (*m.members)[i];
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

        auto dtb = DtBuilder(0);
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
        type *t = type_function(TYnfunc, null, false, tstypes[TYvoid]);
        t.Tmangle = mTYman_c;

        m.sictor = toSymbolX(m, "__modictor", SCglobal, t, "FZv");
        cstate.CSpsymtab = &m.sictor.Sfunc.Flocsym;
        localgot = glue.ictorlocalgot;

        elem *ecov  = el_pair(TYdarray, el_long(TYsize_t, m.numlines), el_ptr(m.cov));
        elem *ebcov = el_pair(TYdarray, el_long(TYsize_t, m.numlines), el_ptr(bcov));

        if (target.os == Target.OS.Windows && target.is64bit)
        {
            ecov  = addressElem(ecov,  Type.tvoid.arrayOf(), false);
            ebcov = addressElem(ebcov, Type.tvoid.arrayOf(), false);
        }

        elem *efilename = toEfilename(m);
        if (target.os == Target.OS.Windows && target.is64bit)
            efilename = addressElem(efilename, Type.tstring, true);

        elem *e = el_params(
                      el_long(TYuchar, global.params.covPercent),
                      ecov,
                      ebcov,
                      efilename,
                      null);
        e = el_bin(OPcall, TYvoid, el_var(getRtlsym(RTLSYM.DCOVER2)), e);
        glue.eictor = el_combine(e, glue.eictor);
        glue.ictorlocalgot = localgot;
    }

    // If coverage / static constructor / destructor / unittest calls
    if (glue.eictor || glue.sctors.dim || glue.ectorgates.dim || glue.sdtors.dim ||
        glue.ssharedctors.dim || glue.esharedctorgates.dim || glue.sshareddtors.dim || glue.stests.dim)
    {
        if (glue.eictor)
        {
            localgot = glue.ictorlocalgot;

            block *b = block_calloc();
            b.BC = BCret;
            b.Belem = glue.eictor;
            m.sictor.Sfunc.Fstartline.Sfilename = m.arg.xarraydup.ptr;
            m.sictor.Sfunc.Fstartblock = b;
            writefunc(m.sictor);
        }

        m.sctor = callFuncsAndGates(m, glue.sctors[], glue.ectorgates[], "__modctor");
        m.sdtor = callFuncsAndGates(m, glue.sdtors[], null, "__moddtor");

        m.ssharedctor = callFuncsAndGates(m, glue.ssharedctors[], cast(StaticDtorDeclaration[])glue.esharedctorgates[], "__modsharedctor");
        m.sshareddtor = callFuncsAndGates(m, glue.sshareddtors[], null, "__modshareddtor");
        m.stest = callFuncsAndGates(m, glue.stests[], null, "__modtest");

        if (m.doppelganger)
            genModuleInfo(m);
    }

    if (m.doppelganger)
    {
        objc.generateModuleInfo(m);
        objmod.termfile();
        return;
    }

     /* Generate module info for templates and -cov.
     *  Don't generate ModuleInfo if `object.ModuleInfo` is not declared or
     *  explicitly disabled through compiler switches such as `-betterC`.
     *  Don't generate ModuleInfo for C files.
     */
    if (global.params.useModuleInfo && Module.moduleinfo && m.filetype != FileType.c/*|| needModuleInfo()*/)
        genModuleInfo(m);

    objmod.termfile();
}



/* ================================================================== */

private UnitTestDeclaration needsDeferredNested(FuncDeclaration fd)
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
    //printf("FuncDeclaration_toObjFile(%p, %s.%s)\n", fd, fd.parent.toChars(), fd.toChars());
    //printf("storage_class: %llx\n", fd.storage_class);

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

    if (fd.hasSemantic3Errors)
        return;

    if (global.errors)
        return;

    if (!fd.fbody)
        return;

    UnitTestDeclaration ud = fd.isUnitTestDeclaration();
    if (ud && !global.params.useUnitTests)
        return;

    if (multiobj && !fd.isStaticDtorDeclaration() && !fd.isStaticCtorDeclaration()
        && !(fd.flags & (FUNCFLAG.CRTCtor | FUNCFLAG.CRTDtor)))
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

    if (fd.hasNoEH())
        // Same as config.ehmethod==EH_NONE, but only for this function
        f.Fflags3 |= Feh_none;

    s.Sclass = target.os == Target.OS.OSX ? SCcomdat : SCglobal;

    /* Make C static functions SCstatic
     */
    if (fd.storage_class & STC.static_ && fd.isCsymbol())
        s.Sclass = SCstatic;

    for (Dsymbol p = fd.parent; p; p = p.parent)
    {
        if (p.isTemplateInstance())
        {
            // functions without D or C++ name mangling mixed in at global scope
            // shouldn't have multiple definitions
            const linkage = fd.resolvedLinkage();
            if (p.isTemplateMixin() && (linkage == LINK.c || linkage == LINK.windows ||
                linkage == LINK.objc))
            {
                const q = p.toParent();
                if (q && q.isModule())
                {
                    s.Sclass = SCglobal;
                    break;
                }
            }
            s.Sclass = SCcomdat;
            break;
        }
    }

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
    IRState irs = IRState(m, fd, &varsInScope, &deferToObj, &labels, &global.params, &target);

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
        char[5 + 10 + 1] hiddenparam = void;
        __gshared uint hiddenparami;    // how many we've generated so far

        const(char)* name;
        if (fd.isNRVO() && fd.nrvo_var)
            name = fd.nrvo_var.ident.toChars();
        else
        {
            sprintf(hiddenparam.ptr, "__HID%u", ++hiddenparami);
            name = hiddenparam.ptr;
        }
        shidden = symbol_name(name, SCparameter, thidden);
        shidden.Sflags |= SFLtrue | SFLfree;
        if (fd.isNRVO() && fd.nrvo_var && fd.nrvo_var.nestedrefs.dim)
            type_setcv(&shidden.Stype, shidden.Stype.Tty | mTYvolatile);
        irs.shidden = shidden;
        fd.shidden = shidden;
    }
    else
    {
        // Register return style cannot make nrvo.
        // Auto functions keep the NRVO flag up to here,
        // so we should eliminate it before entering backend.
        fd.flags &= ~FUNCFLAG.NRVO;
    }

    if (fd.vthis)
    {
        assert(!fd.vthis.csym);
        sthis = toSymbol(fd.vthis);
        sthis.Stype = getParentClosureType(sthis, fd);
        irs.sthis = sthis;
        if (!(f.Fflags3 & Fnested))
            f.Fflags3 |= Fmember;
    }

    // Estimate number of parameters, pi
    size_t pi = (fd.v_arguments !is null);
    if (fd.parameters)
        pi += fd.parameters.dim;
    if (fd.objc.selector)
        pi++; // Extra argument for Objective-C selector
    // Create a temporary buffer, params[], to hold function parameters
    Symbol*[10] paramsbuf = void;
    Symbol **params = paramsbuf.ptr;    // allocate on stack if possible
    if (pi + 2 > paramsbuf.length)      // allow extra 2 for sthis and shidden
    {
        params = cast(Symbol **)Mem.check(malloc((pi + 2) * (Symbol *).sizeof));
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

    pi = objc.addSelectorParameterSymbol(fd, params, pi);

    if (sthis)
    {
        // sthis becomes last parameter
        //params[pi] = sthis;

        // sthis becomes first parameter
        memmove(params + 1, params, pi * (params[0]).sizeof);
        params[0] = sthis;

        pi++;
    }

    if (target.isPOSIX && fd._linkage != LINK.d && shidden && sthis)
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
                sp.Sclass = (target.os == Target.OS.Windows && target.is64bit) ? SCshadowreg : SCfastpar;
                sp.Sfl = (sp.Sclass == SCshadowreg) ? FLpara : FLfast;
            }
        }
    }

    // Done with params
    if (params != paramsbuf.ptr)
        free(params);
    params = null;

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
        if (target.is64bit &&
            target.os & Target.OS.Posix)
        {
            type *t = type_struct_class("__va_argsave_t", 16, 8 * 6 + 8 * 16 + 8 * 3, null, null, false, false, true, false);
            // The backend will pick this up by name
            Symbol *sv = symbol_name("__va_argsave", SCauto, t);
            sv.Stype.Tty |= mTYvolatile;
            symbol_add(sv);
        }

        // Declare _argptr, but only for D files
        if (!irs.Cfile)
        {
            Symbol *sa = toSymbol(fd.v_argptr);
            symbol_add(sa);
            elem *e = el_una(OPva_start, TYnptr, el_ptr(sa));
            block_appendexp(irs.blx.curblock, e);
        }
    }

    /* Doing this in semantic3() caused all kinds of problems:
     * 1. couldn't reliably get the final mangling of the function name due to fwd refs
     * 2. impact on function inlining
     * 3. what to do when writing out .di files, or other pretty printing
     */
    if (global.params.trace && !fd.isCMain() && !fd.isNaked() && !(fd.hasReturnExp & 8))
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
        ethis = fixEthis2(ethis, fd);
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

    if (global.errors)
    {
        // Restore symbol table
        cstate.CSpsymtab = symtabsave;
        return;
    }

    bx.curblock.BC = BCret;

    f.Fstartblock = bx.startblock;
//  einit = el_combine(einit,bx.init);

    if (fd.isCtorDeclaration())
    {
        assert(sthis);
        foreach (b; BlockRange(f.Fstartblock))
        {
            if (b.BC == BCret)
            {
                elem *ethis = el_var(sthis);
                ethis = fixEthis2(ethis, fd);
                b.BC = BCretexp;
                b.Belem = el_combine(b.Belem, ethis);
            }
        }
    }
    if (config.ehmethod == EHmethod.EH_NONE || f.Fflags3 & Feh_none)
        insertFinallyBlockGotos(f.Fstartblock);
    else if (config.ehmethod == EHmethod.EH_DWARF)
        insertFinallyBlockCalls(f.Fstartblock);

    // If static constructor
    if (fd.isSharedStaticCtorDeclaration())        // must come first because it derives from StaticCtorDeclaration
    {
        glue.ssharedctors.push(s);
    }
    else if (fd.isStaticCtorDeclaration())
    {
        glue.sctors.push(s);
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
            glue.esharedctorgates.push(fs);
        }

        glue.sshareddtors.shift(s);
    }
    else if (fd.isStaticDtorDeclaration())
    {
        StaticDtorDeclaration fs = fd.isStaticDtorDeclaration();
        assert(fs);
        if (fs.vgate)
        {
            /* Increment destructor's vgate at construction time
             */
            glue.ectorgates.push(fs);
        }

        glue.sdtors.shift(s);
    }

    // If unit test
    if (ud)
    {
        glue.stests.push(s);
    }

    if (global.errors)
    {
        // Restore symbol table
        cstate.CSpsymtab = symtabsave;
        return;
    }

    writefunc(s); // hand off to backend

    buildCapture(fd);

    // Restore symbol table
    cstate.CSpsymtab = symtabsave;

    if (fd.isExport())
        objmod.export_symbol(s, cast(uint)Para.offset);

    if (fd.flags & FUNCFLAG.CRTCtor)
        objmod.setModuleCtorDtor(s, true);

    if (fd.flags & FUNCFLAG.CRTDtor)
    {
        //See TargetC.initialize
        if(target.c.crtDestructorsSupported)
        {
            objmod.setModuleCtorDtor(s, false);
        } else
        {
             /*
                https://issues.dlang.org/show_bug.cgi?id=22520

                Apple radar: https://openradar.appspot.com/FB9733712

                Apple deprecated the mechanism used to implement `crt_destructor`
                on MacOS Monterey. This works around that by generating a new function
                (crt_destructor_thunk_NNN, run as a constructor) which registers
                the destructor-to-be using __cxa_atexit()

                This workaround may need a further look at when it comes to
                shared library support, however there is no bridge for
                that spilt milk to flow under yet.

                This relies on the Itanium ABI so is portable to any
                platform it, if needed.
            */
            __gshared uint nthDestructor = 0;
            char* buf = cast(char*) calloc(50, 1);
            assert(buf);
            const ret = snprintf(buf, 100, "_dmd_crt_destructor_thunk.%u", nthDestructor++);
            assert(ret >= 0 && ret < 100, "snprintf either failed or overran buffer");
            //Function symbol
            auto newConstructor = symbol_calloc(buf);
            //Build type
            newConstructor.Stype = type_function(TYnfunc, [], false, type_alloc(TYvoid));
            //Tell it it's supposed to be a C function. Does it do anything? Not sure.
            type_setmangle(&newConstructor.Stype, mTYman_c);
            symbol_func(newConstructor);
            //Global SC for now.
            newConstructor.Sclass = SCstatic;
            func_t* funcState = newConstructor.Sfunc;
            //Init start block
            funcState.Fstartblock = block_calloc();
            block* startBlk = funcState.Fstartblock;
            //Make that block run __cxa_atexit(&func);
            auto atexitSym = getRtlsym(RTLSYM.CXA_ATEXIT);
            Symbol* dso_handle = symbol_calloc("__dso_handle");
            dso_handle.Stype = type_fake(TYint);
            //Try to get MacOS _ prefix-ism right.
            type_setmangle(&dso_handle.Stype, mTYman_c);
            dso_handle.Sfl = FLextern;
            dso_handle.Sclass = SCextern;
            dso_handle.Stype.Tcount++;
            auto handlePtr = el_ptr(dso_handle);
            //Build parameter pack - __cxa_atexit(&func, null, null)
            auto paramPack = el_params(handlePtr, el_long(TYnptr, 0), el_ptr(s), null);
            auto exec = el_bin(OPcall, TYvoid, el_var(atexitSym), paramPack);
            block_appendexp(startBlk, exec); //payload
            startBlk.BC = BCgoto;
            auto next = block_calloc();
            startBlk.appendSucc(next);
            startBlk.Bnext = next;
            next.BC = BCret;
            //Emit in binary
            writefunc(newConstructor);
            //Mark as a CONSTRUCTOR because our thunk implements the destructor
            objmod.setModuleCtorDtor(newConstructor, true);
        }
    }

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
    const libname = finalDefaultlibname();

    Symbol* s = fd.toSymbol();  // backend symbol corresponding to fd

    // Pull in RTL startup code (but only once)
    if (fd.isMain() && onlyOneMain(fd.loc))
    {
        final switch (target.objectFormat())
        {
            case Target.ObjectFormat.elf:
            case Target.ObjectFormat.macho:
                objmod.external_def("_main");
                break;
            case Target.ObjectFormat.coff:
                objmod.external_def("main");
                break;
            case Target.ObjectFormat.omf:
                objmod.external_def("_main");
                objmod.external_def("__acrtused_con");
                break;
        }
        if (libname)
            obj_includelib(libname);
        s.Sclass = SCglobal;
        return;
    }
    else if (fd.isRtInit())
    {
        final switch (target.objectFormat())
        {
            case Target.ObjectFormat.elf:
            case Target.ObjectFormat.macho:
            case Target.ObjectFormat.coff:
                objmod.ehsections();   // initialize exception handling sections
                break;
            case Target.ObjectFormat.omf:
                break;
        }
        return;
    }
    void includeWinLibs(bool cmain, const(char)* omflib)
    {
        if (target.objectFormat() == Target.ObjectFormat.coff)
        {
            if (!cmain)
                objmod.includelib("uuid");
            if (driverParams.mscrtlib.length && driverParams.mscrtlib[0])
                obj_includelib(driverParams.mscrtlib);
            objmod.includelib("OLDNAMES");
        }
        else if (target.objectFormat() == Target.ObjectFormat.omf)
        {
            if (cmain)
            {
                objmod.external_def("__acrtused_con"); // bring in C startup code
                objmod.includelib("snn.lib");          // bring in C runtime library
            }
            else
            {
                objmod.external_def(omflib);
            }
        }
    }
    if (fd.isCMain())
    {
        includeWinLibs(true, "");
        s.Sclass = SCglobal;
    }
    else if (target.os == Target.OS.Windows && fd.isWinMain() && onlyOneMain(fd.loc))
    {
        includeWinLibs(false, "__acrtused");
        if (libname)
            obj_includelib(libname);
        s.Sclass = SCglobal;
    }

    // Pull in RTL startup code
    else if (target.os == Target.OS.Windows && fd.isDllMain() && onlyOneMain(fd.loc))
    {
        includeWinLibs(false, "__acrtused_dll");
        if (libname)
            obj_includelib(libname);
        s.Sclass = SCglobal;
    }
}


private bool onlyOneMain(Loc loc)
{
    __gshared Loc lastLoc;
    __gshared bool hasMain = false;
    if (hasMain)
    {
        const(char)* otherMainNames = "";
        if (target.os == Target.OS.Windows)
            otherMainNames = ", `WinMain`, or `DllMain`";
        error(loc, "only one `main`%s allowed. Previously found `main` at %s",
            otherMainNames, lastLoc.toChars());
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

tym_t totym(Type tx)
{
    tym_t t;
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
            t = (driverParams.symdebug == 1 || target.os & Target.OS.Posix) ? TYdchar : TYulong;
            break;

        case Taarray:   t = TYaarray;   break;
        case Tclass:
        case Treference:
        case Tpointer:  t = TYnptr;     break;
        case Tdelegate: t = TYdelegate; break;
        case Tarray:    t = TYdarray;   break;
        case Tsarray:   t = TYstruct;   break;
        case Tnoreturn: t = TYnoreturn; break;

        case Tstruct:
            t = TYstruct;
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
            else if (id == Id.__c_complex_float)
                t = TYcfloat;
            else if (id == Id.__c_complex_double)
                t = TYcdouble;
            else if (id == Id.__c_complex_real)
                t = TYcldouble;
            else
                t = totym(tb);
            break;
        }

        case Tident:
        case Ttypeof:
        case Tmixin:
            //printf("ty = %d, '%s'\n", tx.ty, tx.toChars());
            error(Loc.initial, "forward reference of `%s`", tx.toChars());
            t = TYint;
            break;

        case Tnull:
            t = TYnptr;
            break;

        case Tvector:
        {
            auto tv = cast(TypeVector)tx;
            const tb = tv.elementType();
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
            break;
        }

        case Tfunction:
        {
            auto tf = cast(TypeFunction)tx;
            final switch (tf.linkage)
            {
                case LINK.windows:
                    if (target.is64bit)
                        goto case LINK.c;
                    t = (tf.parameterList.varargs == VarArg.variadic) ? TYnfunc : TYnsfunc;
                    break;

                case LINK.c:
                case LINK.cpp:
                case LINK.objc:
                    t = TYnfunc;
                    if (target.os == Target.OS.Windows)
                    {
                    }
                    else if (!target.is64bit && retStyle(tf, false) == RET.stack)
                        t = TYhfunc;
                    break;

                case LINK.d:
                    t = (tf.parameterList.varargs == VarArg.variadic) ? TYnfunc : TYjfunc;
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

    t |= modToTym(tx.mod);    // Add modifiers

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

/*******************************************
 * Generate readonly symbol that consists of a bunch of zeros.
 * Immutable Symbol instances can be mapped over it.
 * Only one is generated per object file.
 * Returns:
 *    bzero symbol
 */
Symbol* getBzeroSymbol()
{
    Symbol* s = bzeroSymbol;
    if (s)
        return s;

    s = symbol_calloc("__bzeroBytes");
    s.Stype = type_static_array(128, type_fake(TYuchar));
    s.Stype.Tmangle = mTYman_c;
    s.Stype.Tcount++;
    s.Sclass = SCglobal;
    s.Sfl = FLdata;
    s.Sflags |= SFLnodebug;
    s.Salignment = 16;

    auto dtb = DtBuilder(0);
    dtb.nzeros(128);
    s.Sdt = dtb.finish();
    dt2common(&s.Sdt);

    outdata(s);

    bzeroSymbol = s;
    return s;
}



/**************************************
 * Generate elem that is a dynamic array slice of the module file name.
 */

private elem *toEfilename(Module m)
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

// Used in e2ir.d
elem *toEfilenamePtr(Module m)
{
    //printf("toEfilenamePtr(%s)\n", m.toChars());
    const(char)* id = m.srcfile.toChars();
    size_t len = strlen(id);
    Symbol* s = toStringSymbol(id, len, 1);
    return el_ptr(s);
}
