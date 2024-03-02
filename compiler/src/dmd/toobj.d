/**
 * Convert an AST that went through all semantic phases into an object file.
 *
 * Copyright:   Copyright (C) 1999-2024 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/tocsym.d, _toobj.d)
 * Documentation:  https://dlang.org/phobos/dmd_toobj.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/toobj.d
 */

module dmd.toobj;

import core.stdc.stdio;
import core.stdc.stddef;
import core.stdc.string;
import core.stdc.time;

import dmd.root.array;
import dmd.common.outbuffer;
import dmd.common.smallbuffer : SmallBuffer;
import dmd.root.rmem;
import dmd.rootobject;

import dmd.aggregate;
import dmd.arraytypes;
import dmd.astenums;
import dmd.attrib;
import dmd.dcast;
import dmd.dclass;
import dmd.declaration;
import dmd.denum;
import dmd.dmdparams;
import dmd.dmodule;
import dmd.dscope;
import dmd.dstruct;
import dmd.dsymbol;
import dmd.dtemplate;
import dmd.errors;
import dmd.errorsink;
import dmd.expression;
import dmd.func;
import dmd.funcsem;
import dmd.globals;
import dmd.glue;
import dmd.hdrgen;
import dmd.id;
import dmd.init;
import dmd.location;
import dmd.mtype;
import dmd.nspace;
import dmd.objc_glue;
import dmd.statement;
import dmd.staticassert;
import dmd.target;
import dmd.tocsym;
import dmd.toctype;
import dmd.tocvdebug;
import dmd.todt;
import dmd.tokens;
import dmd.traits;
import dmd.typinf;
import dmd.visitor;

import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.cgcv;
import dmd.backend.code;
import dmd.backend.code_x86;
import dmd.backend.cv4;
import dmd.backend.dt;
import dmd.backend.el;
import dmd.backend.global;
import dmd.backend.obj;
import dmd.backend.oper;
import dmd.backend.ty;
import dmd.backend.type;

/* ================================================================== */

// Put out instance of ModuleInfo for this Module

void genModuleInfo(Module m)
{
    //printf("Module.genmoduleinfo() %s\n", m.toChars());

    if (!Module.moduleinfo)
    {
        ObjectNotFound(Id.ModuleInfo);
    }

    Symbol *msym = toSymbol(m);

    //////////////////////////////////////////////

    m.csym.Sclass = SC.global;
    m.csym.Sfl = FLdata;

    auto dtb = DtBuilder(0);

    ClassDeclarations aclasses;
    getLocalClasses(m, aclasses);

    // importedModules[]
    size_t aimports_dim = m.aimports.length;
    for (size_t i = 0; i < m.aimports.length; i++)
    {
        Module mod = m.aimports[i];
        if (!mod.needmoduleinfo)
            aimports_dim--;
    }

    FuncDeclaration sgetmembers = m.findGetMembers();

    // These must match the values in druntime/src/object_.d
    enum
    {
        MIstandalone      = 0x4,
        MItlsctor         = 0x8,
        MItlsdtor         = 0x10,
        MIctor            = 0x20,
        MIdtor            = 0x40,
        MIxgetMembers     = 0x80,
        MIictor           = 0x100,
        MIunitTest        = 0x200,
        MIimportedModules = 0x400,
        MIlocalClasses    = 0x800,
        MIname            = 0x1000,
    }

    uint flags = 0;
    if (!m.needmoduleinfo)
        flags |= MIstandalone;
    if (m.sctor)
        flags |= MItlsctor;
    if (m.sdtor)
        flags |= MItlsdtor;
    if (m.ssharedctor)
        flags |= MIctor;
    if (m.sshareddtor)
        flags |= MIdtor;
    if (sgetmembers)
        flags |= MIxgetMembers;
    if (m.sictor)
        flags |= MIictor;
    if (m.stest)
        flags |= MIunitTest;
    if (aimports_dim)
        flags |= MIimportedModules;
    if (aclasses.length)
        flags |= MIlocalClasses;
    flags |= MIname;

    dtb.dword(flags);        // _flags
    dtb.dword(0);            // _index

    if (flags & MItlsctor)
        dtb.xoff(m.sctor, 0, TYnptr);
    if (flags & MItlsdtor)
        dtb.xoff(m.sdtor, 0, TYnptr);
    if (flags & MIctor)
        dtb.xoff(m.ssharedctor, 0, TYnptr);
    if (flags & MIdtor)
        dtb.xoff(m.sshareddtor, 0, TYnptr);
    if (flags & MIxgetMembers)
        dtb.xoff(toSymbol(sgetmembers), 0, TYnptr);
    if (flags & MIictor)
        dtb.xoff(m.sictor, 0, TYnptr);
    if (flags & MIunitTest)
        dtb.xoff(m.stest, 0, TYnptr);
    if (flags & MIimportedModules)
    {
        dtb.size(aimports_dim);
        foreach (i; 0 .. m.aimports.length)
        {
            Module mod = m.aimports[i];

            if (!mod.needmoduleinfo)
                continue;

            Symbol *s = toSymbol(mod);

            /* Weak references don't pull objects in from the library,
             * they resolve to 0 if not pulled in by something else.
             * Don't pull in a module just because it was imported.
             */
            s.Sflags |= SFLweak;
            dtb.xoff(s, 0, TYnptr);
        }
    }
    if (flags & MIlocalClasses)
    {
        dtb.size(aclasses.length);
        foreach (i; 0 .. aclasses.length)
        {
            ClassDeclaration cd = aclasses[i];
            dtb.xoff(toSymbol(cd), 0, TYnptr);
        }
    }
    if (flags & MIname)
    {
        // Put out module name as a 0-terminated string, to save bytes
        m.nameoffset = dtb.length();
        const(char) *name = m.toPrettyChars();
        m.namelen = strlen(name);
        dtb.nbytes(cast(uint)m.namelen + 1, name);
        //printf("nameoffset = x%x\n", nameoffset);
    }

    objc.generateModuleInfo(m);
    m.csym.Sdt = dtb.finish();
    out_readonly(m.csym);
    outdata(m.csym);

    //////////////////////////////////////////////

    objmod.moduleinfo(msym);
    if (driverParams.exportVisibility == ExpVis.public_)
        objmod.export_symbol(msym, 0);
}

/*****************************************
 * write pointer references for typed data to the object file
 * a class type is considered to mean a reference to a class instance
 * Params:
 *      type   = type of the data to check for pointers
 *      s      = symbol that contains the data
 *      offset = offset of the data inside the Symbol's memory
 */
void write_pointers(Type type, Symbol *s, uint offset)
{
    uint ty = type.toBasetype().ty;
    if (ty == Tclass)
        return objmod.write_pointerRef(s, offset);

    write_instance_pointers(type, s, offset);
}

/*****************************************
* write pointer references for typed data to the object file
* a class type is considered to mean the instance, not a reference
* Params:
*      type   = type of the data to check for pointers
*      s      = symbol that contains the data
*      offset = offset of the data inside the Symbol's memory
*/
void write_instance_pointers(Type type, Symbol *s, uint offset)
{
    import dmd.typesem : hasPointers;
    if (!type.hasPointers())
        return;

    Array!(ulong) data;
    const ulong sz = getTypePointerBitmap(Loc.initial, type, data, global.errorSink);
    if (sz == ulong.max)
        return;

    const bytes_size_t = cast(size_t)Type.tsize_t.size(Loc.initial);
    const bits_size_t = bytes_size_t * 8;
    auto words = cast(size_t)(sz / bytes_size_t);
    foreach (i, const element; data[])
    {
        size_t bits = words < bits_size_t ? words : bits_size_t;
        foreach (size_t b; 0 .. bits)
            if (element & (1L << b))
            {
                auto off = cast(uint) ((i * bits_size_t + b) * bytes_size_t);
                objmod.write_pointerRef(s, off + offset);
            }
        words -= bits;
    }
}

/****************************************************
 * Put out instance of the `TypeInfo` object associated with `t` if it
 * hasn't already been generated
 * Params:
 *      e   = if not null, then expression for pretty-printing errors
 *      loc = the location for reporting line numbers in errors
 *      t   = the type to generate the `TypeInfo` object for
 */
void TypeInfo_toObjFile(Expression e, const ref Loc loc, Type t)
{
    // printf("TypeInfo_toObjFIle() %s\n", torig.toChars());
    if (genTypeInfo(e, loc, t, null))
    {
        // generate a COMDAT for other TypeInfos not available as builtins in druntime
        toObjFile(t.vtinfo, global.params.multiobj);
    }
}

/* ================================================================== */

void toObjFile(Dsymbol ds, bool multiobj)
{
    //printf("toObjFile(%s %s)\n", ds.kind(), ds.toChars());

    bool isCfile = ds.isCsymbol();

    extern (C++) final class ToObjFile : Visitor
    {
        alias visit = Visitor.visit;
    public:
        bool multiobj;

        this(bool multiobj) scope @safe
        {
            this.multiobj = multiobj;
        }

        void visitNoMultiObj(Dsymbol ds)
        {
            bool multiobjsave = multiobj;
            multiobj = false;
            ds.accept(this);
            multiobj = multiobjsave;
        }

        override void visit(Dsymbol ds)
        {
            //printf("Dsymbol.toObjFile('%s')\n", ds.toChars());
            // ignore
        }

        override void visit(FuncDeclaration fd)
        {
            // in glue.c
            FuncDeclaration_toObjFile(fd, multiobj);
        }

        override void visit(ClassDeclaration cd)
        {
            //printf("ClassDeclaration.toObjFile('%s')\n", cd.toChars());

            if (cd.type.ty == Terror)
            {
                .error(cd.loc, "%s `%s` had semantic errors when compiling", cd.kind, cd.toPrettyChars);
                return;
            }

            if (!cd.members)
                return;

            if (multiobj && !cd.hasStaticCtorOrDtor())
            {
                obj_append(cd);
                return;
            }

            if (driverParams.symdebugref)
                Type_toCtype(cd.type); // calls toDebug() only once
            else if (driverParams.symdebug)
                toDebug(cd);

            assert(cd.semanticRun >= PASS.semantic3done);     // semantic() should have been run to completion

            SC scclass = SC.comdat;

            // Put out the members
            /* There might be static ctors in the members, and they cannot
             * be put in separate obj files.
             */
            cd.members.foreachDsymbol( (s) { s.accept(this); } );

            if (cd.classKind == ClassKind.objc)
            {
                objc.toObjFile(cd);
                return;
            }

            // If something goes wrong during this pass don't bother with the
            // rest as we may have incomplete info
            // https://issues.dlang.org/show_bug.cgi?id=17918
            if (!finishVtbl(cd))
            {
                return;
            }

            const bool gentypeinfo = global.params.useTypeInfo && Type.dtypeinfo;
            const bool genclassinfo = gentypeinfo || !(cd.isCPPclass || cd.isCOMclass);

            // Generate C symbols
            if (genclassinfo)
                toSymbol(cd);                           // __ClassZ symbol
            toVtblSymbol(cd, genclassinfo);             // __vtblZ symbol
            Symbol *sinit = toInitializer(cd);          // __initZ symbol

            //////////////////////////////////////////////

            // Generate static initializer
            {
                sinit.Sclass = scclass;
                sinit.Sfl = FLdata;
                auto dtb = DtBuilder(0);
                ClassDeclaration_toDt(cd, dtb);
                sinit.Sdt = dtb.finish();
                out_readonly(sinit);
                outdata(sinit);
                if (cd.isExport() || driverParams.exportVisibility == ExpVis.public_)
                    objmod.export_symbol(sinit, 0);
            }

            //////////////////////////////////////////////

            // Put out the TypeInfo
            if (gentypeinfo)
                TypeInfo_toObjFile(null, cd.loc, cd.type);
            //toObjFile(cd.type.vtinfo, multiobj);

            if (genclassinfo)
            {
                genClassInfoForClass(cd, sinit);
            }

            //////////////////////////////////////////////

            // Put out the vtbl[]
            //printf("putting out %s.vtbl[]\n", toChars());
            auto dtbv = DtBuilder(0);
            if (cd.vtblOffset())
                dtbv.xoff(cd.csym, 0, TYnptr);           // first entry is ClassInfo reference
            foreach (i; cd.vtblOffset() .. cd.vtbl.length)
            {
                FuncDeclaration fd = cd.vtbl[i].isFuncDeclaration();

                //printf("\tvtbl[%d] = %p\n", i, fd);
                if (fd && (fd.fbody || !cd.isAbstract()))
                {
                    dtbv.xoff(toSymbol(fd), 0, TYnptr);
                }
                else
                    dtbv.size(0);
            }
            if (dtbv.isZeroLength())
            {
                /* Someone made an 'extern (C++) class C { }' with no virtual functions.
                 * But making an empty vtbl[] causes linking problems, so make a dummy
                 * entry.
                 */
                dtbv.size(0);
            }
            cd.vtblsym.csym.Sdt = dtbv.finish();
            cd.vtblsym.csym.Sclass = scclass;
            cd.vtblsym.csym.Sfl = FLdata;
            out_readonly(cd.vtblsym.csym);
            outdata(cd.vtblsym.csym);
            if (cd.isExport() || driverParams.exportVisibility == ExpVis.public_)
                objmod.export_symbol(cd.vtblsym.csym, 0);
        }

        override void visit(InterfaceDeclaration id)
        {
            //printf("InterfaceDeclaration.toObjFile('%s')\n", id.toChars());

            if (id.type.ty == Terror)
            {
                .error(id.loc, "had semantic errors when compiling", id.kind, id.toPrettyChars);
                return;
            }

            if (!id.members)
                return;

            if (driverParams.symdebugref)
                Type_toCtype(id.type); // calls toDebug() only once
            else if (driverParams.symdebug)
                toDebug(id);

            // Put out the members
            id.members.foreachDsymbol( (s) { visitNoMultiObj(s); } );

            // Objetive-C protocols are only output if implemented as a class.
            // If so, they're output via the class declaration.
            if (id.classKind == ClassKind.objc)
                return;

            const bool gentypeinfo = global.params.useTypeInfo && Type.dtypeinfo;
            const bool genclassinfo = gentypeinfo || !(id.isCPPclass || id.isCOMclass);


            // Generate C symbols
            if (genclassinfo)
                toSymbol(id);

            //////////////////////////////////////////////

            // Put out the TypeInfo
            if (gentypeinfo)
            {
                TypeInfo_toObjFile(null, id.loc, id.type);
                id.type.vtinfo.accept(this);
            }

            //////////////////////////////////////////////

            if (genclassinfo)
                genClassInfoForInterface(id);
        }

        override void visit(StructDeclaration sd)
        {
            //printf("StructDeclaration.toObjFile('%s')\n", sd.toChars());

            if (sd.type.ty == Terror)
            {
                .error(sd.loc, "%s `%s` had semantic errors when compiling", sd.kind, sd.toPrettyChars);
                return;
            }

            if (multiobj && !sd.hasStaticCtorOrDtor())
            {
                obj_append(sd);
                return;
            }

            // Anonymous structs/unions only exist as part of others,
            // do not output forward referenced structs's
            if (!sd.isAnonymous() && sd.members)
            {
                if (driverParams.symdebugref)
                    Type_toCtype(sd.type); // calls toDebug() only once
                else if (driverParams.symdebug)
                    toDebug(sd);

                if (global.params.useTypeInfo && Type.dtypeinfo)
                    TypeInfo_toObjFile(null, sd.loc, sd.type);

                // Generate static initializer
                auto sinit = toInitializer(sd);
                if (sinit.Sclass == SC.extern_)
                {
                    if (sinit == bzeroSymbol) assert(0);
                    sinit.Sclass = sd.isInstantiated() ? SC.comdat : SC.global;
                    sinit.Sfl = FLdata;
                    auto dtb = DtBuilder(0);
                    StructDeclaration_toDt(sd, dtb);
                    sinit.Sdt = dtb.finish();

                    /* fails to link on OBJ_MACH 64 with:
                     *  ld: in generated/osx/release/64/libphobos2.a(dwarfeh_8dc_56a.o),
                     *  in section __TEXT,__textcoal_nt reloc 6:
                     *  symbol index out of range for architecture x86_64
                     */
                    if (config.objfmt != OBJ_MACH &&
                        dtallzeros(sinit.Sdt))
                    {
                        sinit.Sclass = SC.global;
                        dt2common(&sinit.Sdt);
                    }
                    else
                        out_readonly(sinit);    // put in read-only segment
                    outdata(sinit);
                    if (sd.isExport() || driverParams.exportVisibility == ExpVis.public_)
                        objmod.export_symbol(sinit, 0);
                }

                // Put out the members
                /* There might be static ctors in the members, and they cannot
                 * be put in separate obj files.
                 */
                sd.members.foreachDsymbol( (s) { s.accept(this); } );

                if (sd.xeq && sd.xeq != StructDeclaration.xerreq)
                    sd.xeq.accept(this);
                if (sd.xcmp && sd.xcmp != StructDeclaration.xerrcmp)
                    sd.xcmp.accept(this);
                if (sd.xhash)
                    sd.xhash.accept(this);
            }
        }

        override void visit(VarDeclaration vd)
        {

            //printf("VarDeclaration.toObjFile(%p '%s' type=%s) visibility %d\n", vd, vd.toChars(), vd.type.toChars(), vd.visibility);
            //printf("\talign = %d\n", vd.alignment);

            if (vd.type.ty == Terror)
            {
                .error(vd.loc, "%s `%s` had semantic errors when compiling", vd.kind, vd.toPrettyChars);
                return;
            }

            if (vd.aliasTuple)
            {
                vd.toAlias().accept(this);
                return;
            }

            // Do not store variables we cannot take the address of
            if (!vd.canTakeAddressOf())
            {
                return;
            }

            if (!vd.isDataseg() || vd.storage_class & STC.extern_)
                return;

            Symbol *s = toSymbol(vd);
            const sz64 = vd.type.size(vd.loc);
            if (sz64 == SIZE_INVALID)
            {
                .error(vd.loc, "%s `%s` size overflow", vd.kind, vd.toPrettyChars);
                return;
            }
            if (sz64 > target.maxStaticDataSize)
            {
                .error(vd.loc, "%s `%s` size of 0x%llx exceeds max allowed size 0x%llx", vd.kind, vd.toPrettyChars, sz64, target.maxStaticDataSize);
            }
            uint sz = cast(uint)sz64;

            Dsymbol parent = vd.toParent();
            s.Sclass = SC.global;

            /* Make C static functions SCstatic
             */
            if (vd.storage_class & STC.static_ && vd.isCsymbol())
                s.Sclass = SC.static_;

            do
            {
                /* Global template data members need to be in comdat's
                 * in case multiple .obj files instantiate the same
                 * template with the same types.
                 */
                if (parent.isTemplateInstance() && !parent.isTemplateMixin())
                {
                    s.Sclass = SC.comdat;
                    break;
                }
                parent = parent.parent;
            } while (parent);
            s.Sfl = FLdata;

            // Size 0 should only be possible for T[0] and noreturn
            if (!sz)
            {
                const ty = vd.type.toBasetype().ty;
                if (ty != Tsarray && ty != Tnoreturn && !vd.isCsymbol())
                    assert(0); // this shouldn't be possible
            }

            auto dtb = DtBuilder(0);
            if (config.objfmt == OBJ_MACH && target.isX86_64 && (s.Stype.Tty & mTYLINK) == mTYthread)
            {
                tlsToDt(vd, s, sz, dtb, isCfile);
            }
            else if (!sz)
            {
                /* Give it a byte of data
                 * so we can take the 'address' of this symbol
                 * and avoid problematic behavior of object file format
                 * Note that gcc will give 0 size C objects a `comm a:byte:00h`
                 */
                dtb.nzeros(1);
            }
            else if (vd._init)
            {
                initializerToDt(vd, dtb, vd.isCsymbol());
            }
            else
            {
                Type_toDt(vd.type, dtb, vd.isCsymbol());
            }
            s.Sdt = dtb.finish();

            // See if we can convert a comdat to a comdef,
            // which saves on exe file space.
            if (s.Sclass == SC.comdat &&
                s.Sdt &&
                dtallzeros(s.Sdt) &&
                !vd.isThreadlocal())
            {
                s.Sclass = SC.global;
                dt2common(&s.Sdt);
            }

            if (s.Sclass == SC.global && s.Stype.Tty & mTYconst)
                out_readonly(s);

            outdata(s);
            if (vd.type.isMutable() || !vd._init)
                write_pointers(vd.type, s, 0);
            if (vd.isExport() || driverParams.exportVisibility == ExpVis.public_)
                objmod.export_symbol(s, 0);
        }

        override void visit(EnumDeclaration ed)
        {
            if (ed.semanticRun >= PASS.obj)  // already written
                return;
            //printf("EnumDeclaration.toObjFile('%s')\n", ed.toChars());

            if (ed.errors || ed.type.ty == Terror)
            {
                .error(ed.loc, "%s `%s` had semantic errors when compiling", ed.kind, ed.toPrettyChars);
                return;
            }

            if (ed.isAnonymous())
                return;

            if (driverParams.symdebugref)
                Type_toCtype(ed.type); // calls toDebug() only once
            else if (driverParams.symdebug)
                toDebug(ed);

            if (global.params.useTypeInfo && Type.dtypeinfo)
                TypeInfo_toObjFile(null, ed.loc, ed.type);

            TypeEnum tc = ed.type.isTypeEnum();
            if (!tc.sym.members || ed.type.isZeroInit(Loc.initial))
            {
            }
            else
            {
                SC scclass = SC.global;
                if (ed.isInstantiated())
                    scclass = SC.comdat;

                // Generate static initializer
                toInitializer(ed);
                ed.sinit.Sclass = scclass;
                ed.sinit.Sfl = FLdata;
                auto dtb = DtBuilder(0);
                Expression_toDt(tc.sym.defaultval, dtb);
                ed.sinit.Sdt = dtb.finish();
                outdata(ed.sinit);
            }
            ed.semanticRun = PASS.obj;
        }

        override void visit(TypeInfoDeclaration tid)
        {
            if (isSpeculativeType(tid.tinfo))
            {
                //printf("-speculative '%s'\n", tid.toPrettyChars());
                return;
            }
            //printf("TypeInfoDeclaration.toObjFile(%p '%s') visibility %d\n", tid, tid.toChars(), tid.visibility);

            if (multiobj)
            {
                obj_append(tid);
                return;
            }

            Symbol *s = toSymbol(tid);
            s.Sclass = SC.comdat;
            s.Sfl = FLdata;

            auto dtb = DtBuilder(0);
            TypeInfo_toDt(dtb, tid);
            s.Sdt = dtb.finish();

            // See if we can convert a comdat to a comdef,
            // which saves on exe file space.
            if (s.Sclass == SC.comdat &&
                dtallzeros(s.Sdt))
            {
                s.Sclass = SC.global;
                dt2common(&s.Sdt);
            }

            outdata(s);
            if (tid.isExport() || driverParams.exportVisibility == ExpVis.public_)
                objmod.export_symbol(s, 0);
        }

        override void visit(AttribDeclaration ad)
        {
            Dsymbols *d = ad.include(null);

            if (d)
            {
                for (size_t i = 0; i < d.length; i++)
                {
                    Dsymbol s = (*d)[i];
                    s.accept(this);
                }
            }
        }

        override void visit(PragmaDeclaration pd)
        {
            if (pd.ident == Id.lib)
            {
                assert(pd.args && pd.args.length == 1);

                Expression e = (*pd.args)[0];

                assert(e.op == EXP.string_);

                StringExp se = e.isStringExp();
                char *name = cast(char *)mem.xmalloc(se.numberOfCodeUnits() + 1);
                se.writeTo(name, true);

                /* Embed the library names into the object file.
                 * The linker will then automatically
                 * search that library, too.
                 */
                if (!obj_includelib(name[0 .. strlen(name)]))
                {
                    /* The format does not allow embedded library names,
                     * so instead append the library name to the list to be passed
                     * to the linker.
                     */
                    global.params.libfiles.push(name);
                }
            }
            else if (pd.ident == Id.startaddress)
            {
                assert(pd.args && pd.args.length == 1);
                Expression e = (*pd.args)[0];
                Dsymbol sa = getDsymbol(e);
                FuncDeclaration f = sa.isFuncDeclaration();
                assert(f);
                Symbol *s = toSymbol(f);
                obj_startaddress(s);
            }
            else if (pd.ident == Id.linkerDirective)
            {
                assert(pd.args && pd.args.length == 1);

                Expression e = (*pd.args)[0];

                assert(e.op == EXP.string_);

                StringExp se = e.isStringExp();
                size_t length = se.numberOfCodeUnits() + 1;
                debug enum LEN = 2; else enum LEN = 20;
                char[LEN] buffer = void;
                SmallBuffer!char directive = SmallBuffer!char(length, buffer);

                se.writeTo(directive.ptr, true);

                obj_linkerdirective(directive.ptr);
            }

            visit(cast(AttribDeclaration)pd);
        }

        override void visit(TemplateInstance ti)
        {
            //printf("TemplateInstance.toObjFile(%p, '%s')\n", ti, ti.toChars());
            if (!isError(ti) && ti.members)
            {
                if (!ti.needsCodegen())
                {
                    //printf("-speculative (%p, %s)\n", ti, ti.toPrettyChars());
                    return;
                }
                //printf("TemplateInstance.toObjFile(%p, '%s')\n", ti, ti.toPrettyChars());

                if (multiobj)
                {
                    // Append to list of object files to be written later
                    obj_append(ti);
                }
                else
                {
                    ti.members.foreachDsymbol( (s) { s.accept(this); } );
                }
            }
        }

        override void visit(TemplateMixin tm)
        {
            //printf("TemplateMixin.toObjFile('%s')\n", tm.toChars());
            if (!isError(tm))
            {
                tm.members.foreachDsymbol( (s) { s.accept(this); } );
            }
        }

        override void visit(StaticAssert sa)
        {
        }

        override void visit(Nspace ns)
        {
            //printf("Nspace.toObjFile('%s', this = %p)\n", ns.toChars(), ns);
            if (!isError(ns) && ns.members)
            {
                if (multiobj)
                {
                    // Append to list of object files to be written later
                    obj_append(ns);
                }
                else
                {
                    ns.members.foreachDsymbol( (s) { s.accept(this); } );
                }
            }
        }

        override void visit(TupleDeclaration tup)
        {
            tup.foreachVar((s) { s.accept(this); });
        }

    private:
        static void initializerToDt(VarDeclaration vd, ref DtBuilder dtb, bool isCfile)
        {
            Initializer_toDt(vd._init, dtb, isCfile);

            // Look for static array that is block initialized
            ExpInitializer ie = vd._init.isExpInitializer();

            Type tb = vd.type.toBasetype();
            if (auto tbsa = tb.isTypeSArray())
            {
                auto tbsaNext = tbsa.nextOf();
                if (ie &&
                    !tbsaNext.equals(ie.exp.type.toBasetype().nextOf()) &&
                    ie.exp.implicitConvTo(tbsaNext)
                    )
                {
                    auto dim = tbsa.dim.toInteger();

                    // Duplicate Sdt 'dim-1' times, as we already have the first one
                    while (--dim > 0)
                    {
                        Expression_toDt(ie.exp, dtb);
                    }
                }
            }
        }

        /**
         * Output a TLS symbol for Mach-O.
         *
         * A TLS variable in the Mach-O format consists of two symbols.
         * One symbol for the data, which contains the initializer, if any.
         * The name of this symbol is the same as the variable, but with the
         * "$tlv$init" suffix. If the variable has an initializer it's placed in
         * the __thread_data section. Otherwise it's placed in the __thread_bss
         * section.
         *
         * The other symbol is for the TLV descriptor. The symbol has the same
         * name as the variable and is placed in the __thread_vars section.
         * A TLV descriptor has the following structure, where T is the type of
         * the variable:
         *
         * struct TLVDescriptor(T)
         * {
         *     extern(C) T* function(TLVDescriptor*) thunk;
         *     size_t key;
         *     size_t offset;
         * }
         *
         * Params:
         *      vd = the variable declaration for the symbol
         *      s = the backend Symbol corresponsing to vd
         *      sz = data size of s
         *      dtb = where to put the data
         */
        static void tlsToDt(VarDeclaration vd, Symbol *s, uint sz, ref DtBuilder dtb, bool isCfile)
        {
            assert(config.objfmt == OBJ_MACH && target.isX86_64 && (s.Stype.Tty & mTYLINK) == mTYthread);

            Symbol *tlvInit = createTLVDataSymbol(vd, s);
            auto tlvInitDtb = DtBuilder(0);

            if (sz == 0)
                tlvInitDtb.nzeros(1);
            else if (vd._init)
                initializerToDt(vd, tlvInitDtb, isCfile);
            else
                Type_toDt(vd.type, tlvInitDtb);

            tlvInit.Sdt = tlvInitDtb.finish();
            outdata(tlvInit);

            if (target.isX86_64)
                tlvInit.Sclass = SC.extern_;

            Symbol* tlvBootstrap = objmod.tlv_bootstrap();
            dtb.xoff(tlvBootstrap, 0, TYnptr);
            dtb.size(0);
            dtb.xoff(tlvInit, 0, TYnptr);
        }

        /**
         * Creates the data symbol used to initialize a TLS variable for Mach-O.
         *
         * Params:
         *      vd = the variable declaration for the symbol
         *      s = the back end symbol corresponding to vd
         *
         * Returns: the newly created symbol
         */
        static Symbol *createTLVDataSymbol(VarDeclaration vd, Symbol *s)
        {
            assert(config.objfmt == OBJ_MACH && target.isX86_64 && (s.Stype.Tty & mTYLINK) == mTYthread);

            // Compute identifier for tlv symbol
            OutBuffer buffer;
            buffer.writestring(s.Sident.ptr);
            buffer.writestring("$tlv$init");
            const(char)[] tlvInitName = buffer[];

            // Compute type for tlv symbol
            type *t = type_fake(vd.type.ty);
            type_setty(&t, t.Tty | mTYthreadData);
            type_setmangle(&t, mangle(vd));

            Symbol *tlvInit = symbol_name(tlvInitName, SC.static_, t);
            tlvInit.Sdt = null;
            tlvInit.Salignment = type_alignsize(s.Stype);
            if (vd._linkage == LINK.cpp)
                tlvInit.Sflags |= SFLpublic;

            return tlvInit;
        }

        /**
         * Returns the target mangling mangle_t for the given variable.
         *
         * Params:
         *      vd = the variable declaration
         *
         * Returns:
         *      the mangling that should be used for variable
         */
        static mangle_t mangle(const VarDeclaration vd)
        {
            final switch (vd.resolvedLinkage())
            {
                case LINK.windows:
                    return target.isX86_64 ? mTYman_c : mTYman_std;

                case LINK.objc:
                case LINK.c:
                    return mTYman_c;

                case LINK.d:
                    return mTYman_d;

                case LINK.cpp:
                    return mTYman_cpp;

                case LINK.default_:
                case LINK.system:
                    printf("linkage = %d\n", vd._linkage);
                    assert(0);
            }
        }
    }

    scope v = new ToObjFile(multiobj);
    ds.accept(v);
}


/*********************************
 * Finish semantic analysis of functions in vtbl[].
 * Params:
 *    cd = class which has the vtbl[]
 * Returns:
 *    true for success (no errors)
 */
private bool finishVtbl(ClassDeclaration cd)
{
    bool hasError = false;

    foreach (i; cd.vtblOffset() .. cd.vtbl.length)
    {
        FuncDeclaration fd = cd.vtbl[i].isFuncDeclaration();

        //printf("\tvtbl[%d] = %p\n", i, fd);
        if (!fd || !fd.fbody && cd.isAbstract())
        {
            // Nothing to do
            continue;
        }
        // Ensure function has a return value
        // https://issues.dlang.org/show_bug.cgi?id=4869
        if (!functionSemantic(fd))
        {
            hasError = true;
        }

        if (!cd.isFuncHidden(fd) || fd.isFuture())
        {
            // All good, no name hiding to check for
            continue;
        }

        /* fd is hidden from the view of this class.
         * If fd overlaps with any function in the vtbl[], then
         * issue 'hidden' error.
         */
        foreach (j; 1 .. cd.vtbl.length)
        {
            if (j == i)
                continue;
            FuncDeclaration fd2 = cd.vtbl[j].isFuncDeclaration();
            if (!fd2.ident.equals(fd.ident))
                continue;
            if (fd2.isFuture())
                continue;
            if (!FuncDeclaration.leastAsSpecialized(fd, fd2, null) &&
                !FuncDeclaration.leastAsSpecialized(fd2, fd, null))
                continue;
            // Hiding detected: same name, overlapping specializations
            TypeFunction tf = fd.type.toTypeFunction();
            .error(cd.loc, "%s `%s` use of `%s%s` is hidden by `%s`; use `alias %s = %s.%s;` to introduce base class overload set", cd.kind, cd.toPrettyChars,
                fd.toPrettyChars(),
                parametersTypeToChars(tf.parameterList),
                cd.toChars(),
                fd.toChars(),
                fd.parent.toChars(),
                fd.toChars());
            hasError = true;
            break;
        }
    }

    return !hasError;
}


/******************************************
 * Get offset of base class's vtbl[] initializer from start of csym.
 * Returns ~0 if not this csym.
 */

uint baseVtblOffset(ClassDeclaration cd, BaseClass *bc)
{
    //printf("ClassDeclaration.baseVtblOffset('%s', bc = %p)\n", cd.toChars(), bc);
    uint csymoffset = target.classinfosize;    // must be ClassInfo.size
    csymoffset += cd.vtblInterfaces.length * (4 * target.ptrsize);

    for (size_t i = 0; i < cd.vtblInterfaces.length; i++)
    {
        BaseClass *b = (*cd.vtblInterfaces)[i];

        if (b == bc)
            return csymoffset;
        csymoffset += b.sym.vtbl.length * target.ptrsize;
    }

    // Put out the overriding interface vtbl[]s.
    // This must be mirrored with ClassDeclaration.baseVtblOffset()
    //printf("putting out overriding interface vtbl[]s for '%s' at offset x%x\n", toChars(), offset);
    ClassDeclaration cd2;

    for (cd2 = cd.baseClass; cd2; cd2 = cd2.baseClass)
    {
        foreach (k; 0 .. cd2.vtblInterfaces.length)
        {
            BaseClass *bs = (*cd2.vtblInterfaces)[k];
            if (bs.fillVtbl(cd, null, 0))
            {
                if (bc == bs)
                {
                    //printf("\tcsymoffset = x%x\n", csymoffset);
                    return csymoffset;
                }
                csymoffset += bs.sym.vtbl.length * target.ptrsize;
            }
        }
    }

    return ~0;
}

/*******************
 * Emit the vtbl[] to static data
 * Params:
 *    dtb = static data builder
 *    b = base class
 *    bvtbl = array of functions to put in this vtbl[]
 *    pc = classid for this vtbl[]
 *    k = offset from pc to classinfo
 * Returns:
 *    number of bytes emitted
 */
private size_t emitVtbl(ref DtBuilder dtb, BaseClass *b, ref FuncDeclarations bvtbl, ClassDeclaration pc, size_t k)
{
    //printf("\toverriding vtbl[] for %s\n", b.sym.toChars());
    ClassDeclaration id = b.sym;

    const id_vtbl_dim = id.vtbl.length;
    assert(id_vtbl_dim <= bvtbl.length);

    size_t jstart = 0;
    if (id.vtblOffset())
    {
        // First entry is struct Interface reference
        dtb.xoff(toSymbol(pc), cast(uint)(target.classinfosize + k * (4 * target.ptrsize)), TYnptr);
        jstart = 1;
    }

    foreach (j; jstart .. id_vtbl_dim)
    {
        FuncDeclaration fd = bvtbl[j];
        if (fd)
        {
            auto offset2 = b.offset;
            if (fd.interfaceVirtual)
            {
                offset2 -= fd.interfaceVirtual.offset;
            }
            dtb.xoff(toThunkSymbol(fd, offset2), 0, TYnptr);
        }
        else
            dtb.size(0);
    }
    return id_vtbl_dim * target.ptrsize;
}


/******************************************************
 * Generate the ClassInfo for a Class (__classZ) symbol.
 * Write it to the object file.
 * Similar to genClassInfoForInterface().
 * Params:
 *      cd = the class
 *      sinit = the Initializer (__initZ) symbol for the class
 */
private void genClassInfoForClass(ClassDeclaration cd, Symbol* sinit)
{
    if (Type.typeinfoclass)
    {
        if (Type.typeinfoclass.structsize != target.classinfosize)
        {
            debug printf("target.classinfosize = x%x, Type.typeinfoclass.structsize = x%x\n", target.classinfosize, Type.typeinfoclass.structsize);
            .error(cd.loc, "%s `%s` mismatch between compiler (%d bytes) and object.d or object.di (%d bytes) found. Check installation and import paths with -v compiler switch.",
                   cd.kind, cd.toPrettyChars, cast(uint)target.classinfosize, cast(uint)Type.typeinfoclass.structsize);
            fatal();
        }
    }

    // Put out the ClassInfo, which will be the __ClassZ symbol in the object file
    SC scclass = SC.comdat;
    cd.csym.Sclass = scclass;
    cd.csym.Sfl = FLdata;

    auto dtb = DtBuilder(0);

    ClassInfoToDt(dtb, cd, sinit);

    cd.csym.Sdt = dtb.finish();
    // ClassInfo cannot be const data, because we use the monitor on it
    outdata(cd.csym);
    if (cd.isExport() || driverParams.exportVisibility == ExpVis.public_)
        objmod.export_symbol(cd.csym, 0);
}

private void ClassInfoToDt(ref DtBuilder dtb, ClassDeclaration cd, Symbol* sinit)
{
    /* The layout is:
       {
            void **vptr;
            monitor_t monitor;
            byte[] m_init;              // static initialization data
            string name;                // class name
            void*[] vtbl;
            Interface[] interfaces;
            ClassInfo base;             // base class
            void* destructor;
            void function(Object) classInvariant;   // class invariant
            ClassFlags m_flags;
            ushort depth;
            void* deallocator;
            OffsetTypeInfo[] offTi;
            void function(Object) defaultConstructor;
            //const(MemberInfo[]) function(string) xgetMembers;   // module getMembers() function
            immutable(void)* m_RTInfo;
            //TypeInfo typeinfo;
            uint[4] nameSig;
       }
     */
    uint offset = target.classinfosize;    // must be ClassInfo.size

    if (auto tic = Type.typeinfoclass)
    {
        dtb.xoff(toVtblSymbol(tic), 0, TYnptr); // vtbl for TypeInfo_Class : ClassInfo
        if (tic.hasMonitor())
            dtb.size(0);                        // monitor
    }
    else
    {
        dtb.size(0);                    // BUG: should be an assert()
        dtb.size(0);                    // call hasMonitor()?
    }

    // m_init[]
    assert(cd.structsize >= 8 || (cd.classKind == ClassKind.cpp && cd.structsize >= 4));
    dtb.size(cd.structsize);           // size
    dtb.xoff(sinit, 0, TYnptr);         // initializer

    // name[]
    const(char) *name = cd.ident.toChars();
    size_t namelen = strlen(name);
    if (!(namelen > 9 && memcmp(name, "TypeInfo_".ptr, 9) == 0))
    {
        name = cd.toPrettyChars(/*QualifyTypes=*/ true);
        namelen = strlen(name);
    }
    dtb.size(namelen);
    dt_t *pdtname = dtb.xoffpatch(cd.csym, 0, TYnptr);

    // vtbl[]
    dtb.size(cd.vtbl.length);
    if (cd.vtbl.length)
        dtb.xoff(cd.vtblsym.csym, 0, TYnptr);
    else
        dtb.size(0);

    // interfaces[]
    dtb.size(cd.vtblInterfaces.length);
    if (cd.vtblInterfaces.length)
        dtb.xoff(cd.csym, offset, TYnptr);      // (*)
    else
        dtb.size(0);

    // base
    if (cd.baseClass)
        dtb.xoff(toSymbol(cd.baseClass), 0, TYnptr);
    else
        dtb.size(0);

    // destructor
    if (cd.tidtor)
        dtb.xoff(toSymbol(cd.tidtor), 0, TYnptr);
    else
        dtb.size(0);

    // classInvariant
    if (cd.inv)
        dtb.xoff(toSymbol(cd.inv), 0, TYnptr);
    else
        dtb.size(0);

    // flags
    ClassFlags flags = ClassFlags.hasOffTi;
    if (cd.isCOMclass()) flags |= ClassFlags.isCOMclass;
    if (cd.isCPPclass()) flags |= ClassFlags.isCPPclass;
    flags |= ClassFlags.hasGetMembers;
    flags |= ClassFlags.hasTypeInfo;
    flags |= ClassFlags.hasNameSig;
    if (cd.ctor)
        flags |= ClassFlags.hasCtor;
    for (ClassDeclaration pc = cd; pc; pc = pc.baseClass)
    {
        if (pc.dtor)
        {
            flags |= ClassFlags.hasDtor;
            break;
        }
    }
    if (cd.isAbstract())
        flags |= ClassFlags.isAbstract;

    flags |= ClassFlags.noPointers;     // initially assume no pointers
Louter:
    for (ClassDeclaration pc = cd; pc; pc = pc.baseClass)
    {
        if (pc.members)
        {
            for (size_t i = 0; i < pc.members.length; i++)
            {
                Dsymbol sm = (*pc.members)[i];
                //printf("sm = %s %s\n", sm.kind(), sm.toChars());
                if (sm.hasPointers())
                {
                    flags &= ~ClassFlags.noPointers;  // not no-how, not no-way
                    break Louter;
                }
            }
        }
    }

    int depth = 0;
    for (ClassDeclaration pc = cd; pc; pc = pc.baseClass)
        ++depth;  // distance to Object

    // m_flags and depth, align to size_t
    dtb.size((depth << 16) | flags);

    // deallocator
    dtb.size(0);

    // offTi[]
    dtb.size(0);
    dtb.size(0);            // null for now, fix later

    // defaultConstructor
    if (cd.defaultCtor && !(cd.defaultCtor.storage_class & STC.disable))
        dtb.xoff(toSymbol(cd.defaultCtor), 0, TYnptr);
    else
        dtb.size(0);

    // m_RTInfo
    if (cd.getRTInfo)
        Expression_toDt(cd.getRTInfo, dtb);
    else if (flags & ClassFlags.noPointers)
        dtb.size(0);
    else
        dtb.size(1);

    //dtb.xoff(toSymbol(cd.type.vtinfo), 0, TYnptr); // typeinfo

    // uint[4] nameSig
    {
        import dmd.common.md5;
        MD5_CTX mdContext = void;
        MD5Init(&mdContext);
        MD5Update(&mdContext, cast(ubyte*)name, cast(uint)namelen);
        MD5Final(&mdContext);
        assert(mdContext.digest.length == 16);
        dtb.nbytes(16, cast(char*)mdContext.digest.ptr);
    }

    //////////////////////////////////////////////

    // Put out (*vtblInterfaces)[]. Must immediately follow csym, because
    // of the fixup (*)

    offset += cd.vtblInterfaces.length * (4 * target.ptrsize);
    for (size_t i = 0; i < cd.vtblInterfaces.length; i++)
    {
        BaseClass *b = (*cd.vtblInterfaces)[i];
        ClassDeclaration id = b.sym;

        /* The layout is:
         *  struct Interface
         *  {
         *      ClassInfo classinfo;
         *      void*[] vtbl;
         *      size_t offset;
         *  }
         */

        // Fill in vtbl[]
        b.fillVtbl(cd, &b.vtbl, 1);

        // classinfo
        dtb.xoff(toSymbol(id), 0, TYnptr);

        // vtbl[]
        dtb.size(id.vtbl.length);
        dtb.xoff(cd.csym, offset, TYnptr);

        // offset
        dtb.size(b.offset);
    }

    // Put out the (*vtblInterfaces)[].vtbl[]
    // This must be mirrored with ClassDeclaration.baseVtblOffset()
    //printf("putting out %d interface vtbl[]s for '%s'\n", vtblInterfaces.length, toChars());
    foreach (i; 0 .. cd.vtblInterfaces.length)
    {
        BaseClass *b = (*cd.vtblInterfaces)[i];
        offset += emitVtbl(dtb, b, b.vtbl, cd, i);
    }

    // Put out the overriding interface vtbl[]s.
    // This must be mirrored with ClassDeclaration.baseVtblOffset()
    //printf("putting out overriding interface vtbl[]s for '%s' at offset x%x\n", toChars(), offset);
    for (ClassDeclaration pc = cd.baseClass; pc; pc = pc.baseClass)
    {
        foreach (i; 0 .. pc.vtblInterfaces.length)
        {
            BaseClass *b = (*pc.vtblInterfaces)[i];
            FuncDeclarations bvtbl;
            if (b.fillVtbl(cd, &bvtbl, 0))
            {
                offset += emitVtbl(dtb, b, bvtbl, pc, i);
            }
        }
    }

    //////////////////////////////////////////////

    dtpatchoffset(pdtname, offset);

    dtb.nbytes(cast(uint)(namelen + 1), name);
    const size_t namepad = -(namelen + 1) & (target.ptrsize - 1); // align
    dtb.nzeros(cast(uint)namepad);
}

/******************************************************
 * Generate the ClassInfo for an Interface (classZ symbol).
 * Write it to the object file.
 * Params:
 *      id = the interface
 */
private void genClassInfoForInterface(InterfaceDeclaration id)
{
    SC scclass = SC.comdat;

    // Put out the ClassInfo
    id.csym.Sclass = scclass;
    id.csym.Sfl = FLdata;

    auto dtb = DtBuilder(0);

    InterfaceInfoToDt(dtb, id);

    id.csym.Sdt = dtb.finish();
    out_readonly(id.csym);
    outdata(id.csym);
    if (id.isExport() || driverParams.exportVisibility == ExpVis.public_)
        objmod.export_symbol(id.csym, 0);
}

private void InterfaceInfoToDt(ref DtBuilder dtb, InterfaceDeclaration id)
{
    /* The layout is:
       {
            void **vptr;
            monitor_t monitor;
            byte[] m_init;              // static initialization data
            string name;                // class name
            void*[] vtbl;
            Interface[] interfaces;
            ClassInfo base;             // base class
            void* destructor;
            void function(Object) classInvariant;   // class invariant
            ClassFlags m_flags;
            ushort depth;
            void* deallocator;
            OffsetTypeInfo[] offTi;
            void function(Object) defaultConstructor;
            //const(MemberInfo[]) function(string) xgetMembers;   // module getMembers() function
            immutable(void)* m_RTInfo;
            //TypeInfo typeinfo;
            uint[4] nameSig;
       }
     */
    if (auto tic = Type.typeinfoclass)
    {
        dtb.xoff(toVtblSymbol(tic), 0, TYnptr); // vtbl for ClassInfo
        if (tic.hasMonitor())
            dtb.size(0);                        // monitor
    }
    else
    {
        dtb.size(0);                    // BUG: should be an assert()
        dtb.size(0);                    // call hasMonitor()?
    }

    // m_init[]
    dtb.size(0);                        // size
    dtb.size(0);                        // initializer

    // name[]
    const(char) *name = id.toPrettyChars(/*QualifyTypes=*/ true);
    size_t namelen = strlen(name);
    dtb.size(namelen);
    dt_t *pdtname = dtb.xoffpatch(id.csym, 0, TYnptr);

    // vtbl[]
    dtb.size(0);
    dtb.size(0);

    // interfaces[]
    uint offset = target.classinfosize;
    dtb.size(id.vtblInterfaces.length);
    if (id.vtblInterfaces.length)
    {
        if (Type.typeinfoclass)
        {
            if (Type.typeinfoclass.structsize != offset)
            {
                .error(id.loc, "%s `%s` mismatch between compiler (%d bytes) and object.d or object.di (%d bytes) found. Check installation and import paths with -v compiler switch.",
                       id.kind, id.toPrettyChars, cast(uint)offset, cast(uint)Type.typeinfoclass.structsize);
                fatal();
            }
        }
        dtb.xoff(id.csym, offset, TYnptr);      // (*)
    }
    else
    {
        dtb.size(0);
    }

    // base
    assert(!id.baseClass);
    dtb.size(0);

    // destructor
    dtb.size(0);

    // classInvariant
    dtb.size(0);

    // flags
    ClassFlags flags = ClassFlags.hasOffTi | ClassFlags.hasTypeInfo;
    if (id.isCOMinterface()) flags |= ClassFlags.isCOMclass;
    flags |= ClassFlags.hasNameSig;
    dtb.size(flags); // depth part is 0

    // deallocator
    dtb.size(0);

    // offTi[]
    dtb.size(0);
    dtb.size(0);            // null for now, fix later

    // defaultConstructor
    dtb.size(0);

    // xgetMembers
    //dtb.size(0);

    // m_RTInfo
    if (id.getRTInfo)
        Expression_toDt(id.getRTInfo, dtb);
    else
        dtb.size(0);       // no pointers

    //dtb.xoff(toSymbol(id.type.vtinfo), 0, TYnptr); // typeinfo

    // uint[4] nameSig
    {
        import dmd.common.md5;
        MD5_CTX mdContext = void;
        MD5Init(&mdContext);
        MD5Update(&mdContext, cast(ubyte*)name, cast(uint)namelen);
        MD5Final(&mdContext);
        assert(mdContext.digest.length == 16);
        dtb.nbytes(16, cast(char*)mdContext.digest.ptr);
    }

    //////////////////////////////////////////////

    // Put out (*vtblInterfaces)[]. Must immediately follow csym, because
    // of the fixup (*)

    offset += id.vtblInterfaces.length * (4 * target.ptrsize);
    for (size_t i = 0; i < id.vtblInterfaces.length; i++)
    {
        BaseClass *b = (*id.vtblInterfaces)[i];
        ClassDeclaration base = b.sym;

        // classinfo
        dtb.xoff(toSymbol(base), 0, TYnptr);

        // vtbl[]
        dtb.size(0);
        dtb.size(0);

        // offset
        dtb.size(b.offset);
    }

    //////////////////////////////////////////////

    dtpatchoffset(pdtname, offset);

    dtb.nbytes(cast(uint)(namelen + 1), name);
    const size_t namepad =  -(namelen + 1) & (target.ptrsize - 1); // align
    dtb.nzeros(cast(uint)namepad);
}
