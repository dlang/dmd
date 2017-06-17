/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/_tocsym.d, _tocsym.d)
 */

module ddmd.tocsym;

import core.stdc.stdio;
import core.stdc.string;

import ddmd.root.array;
import ddmd.root.rmem;

import ddmd.aggregate;
import ddmd.arraytypes;
import ddmd.complex;
import ddmd.cppmangle;
import ddmd.ctfeexpr;
import ddmd.declaration;
import ddmd.dclass;
import ddmd.denum;
import ddmd.dmodule;
import ddmd.dstruct;
import ddmd.dsymbol;
import ddmd.dtemplate;
import ddmd.errors;
import ddmd.expression;
import ddmd.func;
import ddmd.globals;
import ddmd.glue;
import ddmd.identifier;
import ddmd.id;
import ddmd.init;
import ddmd.mtype;
import ddmd.target;
import ddmd.toctype;
import ddmd.todt;
import ddmd.tokens;
import ddmd.typinf;
import ddmd.visitor;
import ddmd.irstate;
import ddmd.dmangle;

import ddmd.backend.cdef;
import ddmd.backend.cc;
import ddmd.backend.dt;
import ddmd.backend.type;
import ddmd.backend.global;
import ddmd.backend.oper;
import ddmd.backend.cgcv;
import ddmd.backend.ty;

extern (C++):


/*************************************
 * Helper
 */

Symbol *toSymbolX(Dsymbol ds, const(char)* prefix, int sclass, type *t, const(char)* suffix)
{
    //printf("Dsymbol::toSymbolX('%s')\n", prefix);
    import core.stdc.stdlib : malloc, free;
    import ddmd.root.outbuffer : OutBuffer;

    OutBuffer buf;
    mangleToBuffer(ds, &buf);
    size_t nlen = buf.offset;
    const(char)* n = buf.peekString();
    assert(n);

    import core.stdc.string : strlen;
    size_t prefixlen = strlen(prefix);
    size_t suffixlen = strlen(suffix);
    size_t idlen = 2 + nlen + size_t.sizeof * 3 + prefixlen + suffixlen + 1;

    char[64] idbuf;
    char *id = &idbuf[0];
    if (idlen > idbuf.sizeof)
    {
        id = cast(char *)malloc(idlen);
        assert(id);
    }

    int nwritten = sprintf(id,"_D%.*s%d%.*s%.*s",
        cast(int)nlen, n,
        cast(int)prefixlen, cast(int)prefixlen, prefix,
        cast(int)suffixlen, suffix);
    assert(cast(uint)nwritten < idlen);         // nwritten does not include the terminating 0 char

    Symbol *s = symbol_name(id, nwritten, sclass, t);

    if (id != &idbuf[0])
        free(id);

    //printf("-Dsymbol::toSymbolX() %s\n", id);
    return s;
}

__gshared Symbol *scc;

/*************************************
 */

Symbol *toSymbol(Dsymbol s)
{
    extern (C++) static final class ToSymbol : Visitor
    {
        alias visit = super.visit;

        Symbol *result;

        this()
        {
            result = null;
        }

        override void visit(Dsymbol s)
        {
            printf("Dsymbol.toSymbol() '%s', kind = '%s'\n", s.toChars(), s.kind());
            assert(0);          // BUG: implement
        }

        override void visit(SymbolDeclaration sd)
        {
            result = toInitializer(sd.dsym);
        }

        override void visit(VarDeclaration vd)
        {
            //printf("VarDeclaration.toSymbol(%s)\n", vd.toChars());
            assert(!vd.needThis());

            Symbol *s;
            if (vd.isDataseg())
            {
                import ddmd.root.outbuffer : OutBuffer;
                OutBuffer buf;
                mangleToBuffer(vd, &buf);
                const length = buf.offset;
                const id = buf.peekString();
                s = symbol_calloc(id, cast(uint)length);
            }
            else
            {
                const id = vd.ident.toChars();
                s = symbol_calloc(id, cast(uint)strlen(id));
            }
            s.Salignment = vd.alignment;
            if (vd.storage_class & STCtemp)
                s.Sflags |= SFLartifical;

            TYPE *t;
            if (vd.storage_class & (STCout | STCref))
            {
                t = type_allocn(TYnref, Type_toCtype(vd.type));
                t.Tcount++;
            }
            else if (vd.storage_class & STClazy)
            {
                if (config.exe == EX_WIN64 && vd.isParameter())
                    t = type_fake(TYnptr);
                else
                    t = type_fake(TYdelegate);          // Tdelegate as C type
                t.Tcount++;
            }
            else if (vd.isParameter())
            {
                if (config.exe == EX_WIN64 && vd.type.size(Loc()) > _tysize[TYnptr])
                {
                    t = type_allocn(TYnref, Type_toCtype(vd.type));
                    t.Tcount++;
                }
                else
                {
                    t = Type_toCtype(vd.type);
                    t.Tcount++;
                }
            }
            else
            {
                t = Type_toCtype(vd.type);
                t.Tcount++;
            }

            if (vd.isDataseg())
            {
                if (vd.isThreadlocal() && !(vd.storage_class & STCtemp))
                {
                    /* Thread local storage
                     */
                    auto ts = t;
                    ts.Tcount++;   // make sure a different t is allocated
                    type_setty(&t, t.Tty | mTYthread);
                    ts.Tcount--;

                    if (config.objfmt == OBJ_MACH && _tysize[TYnptr] == 8)
                        s.Salignment = 2;

                    if (global.params.vtls)
                    {
                        const(char)* p = vd.loc.toChars();
                        fprintf(global.stdmsg, "%s: %s is thread local\n", p ? p : "", vd.toChars());
                        if (p)
                            mem.xfree(cast(void*)p);
                    }
                }
                s.Sclass = SCextern;
                s.Sfl = FLextern;
                /* if it's global or static, then it needs to have a qualified but unmangled name.
                 * This gives some explanation of the separation in treating name mangling.
                 * It applies to PDB format, but should apply to CV as PDB derives from CV.
                 *    http://msdn.microsoft.com/en-us/library/ff553493(VS.85).aspx
                 */
                s.prettyIdent = vd.toPrettyChars(true);
            }
            else
            {
                s.Sclass = SCauto;
                s.Sfl = FLauto;

                if (vd.nestedrefs.dim)
                {
                    /* Symbol is accessed by a nested function. Make sure
                     * it is not put in a register, and that the optimizer
                     * assumes it is modified across function calls and pointer
                     * dereferences.
                     */
                    //printf("\tnested ref, not register\n");
                    type_setcv(&t, t.Tty | mTYvolatile);
                }
            }

            if (vd.storage_class & STCvolatile)
            {
                type_setcv(&t, t.Tty | mTYvolatile);
            }

            mangle_t m = 0;
            switch (vd.linkage)
            {
                case LINKwindows:
                    m = global.params.is64bit ? mTYman_c : mTYman_std;
                    break;

                case LINKpascal:
                    m = mTYman_pas;
                    break;

                case LINKobjc:
                case LINKc:
                    m = mTYman_c;
                    break;

                case LINKd:
                    m = mTYman_d;
                    break;
                case LINKcpp:
                    s.Sflags |= SFLpublic;
                    m = mTYman_d;
                    break;
                default:
                    printf("linkage = %d, vd = %s %s @ [%s]\n",
                        vd.linkage, vd.kind(), vd.toChars(), vd.loc.toChars());
                    assert(0);
            }

            type_setmangle(&t, m);
            s.Stype = t;

            s.lnoscopestart = vd.loc.linnum;
            s.lnoscopeend = vd.endlinnum;
            result = s;
        }

        override void visit(TypeInfoDeclaration tid)
        {
            //printf("TypeInfoDeclaration.toSymbol(%s), linkage = %d\n", tid.toChars(), tid.linkage);
            assert(tid.tinfo.ty != Terror);
            visit(cast(VarDeclaration)tid);
        }

        override void visit(TypeInfoClassDeclaration ticd)
        {
            //printf("TypeInfoClassDeclaration.toSymbol(%s), linkage = %d\n", ticd.toChars(), ticd.linkage);
            assert(ticd.tinfo.ty == Tclass);
            auto tc = cast(TypeClass)ticd.tinfo;
            tc.sym.accept(this);
        }

        override void visit(FuncAliasDeclaration fad)
        {
            fad.funcalias.accept(this);
        }

        override void visit(FuncDeclaration fd)
        {
            const(char)* id = mangleExact(fd);

            //printf("FuncDeclaration.toSymbol(%s %s)\n", fd.kind(), fd.toChars());
            //printf("\tid = '%s'\n", id);
            //printf("\ttype = %s\n", fd.type.toChars());
            auto s = symbol_calloc(id, cast(uint)strlen(id));

            s.prettyIdent = fd.toPrettyChars(true);
            s.Sclass = SCglobal;
            symbol_func(s);
            func_t *f = s.Sfunc;
            if (fd.isVirtual() && fd.vtblIndex != -1)
                f.Fflags |= Fvirtual;
            else if (fd.isMember2() && fd.isStatic())
                f.Fflags |= Fstatic;
            f.Fstartline.Slinnum = fd.loc.linnum;
            f.Fstartline.Scharnum = fd.loc.charnum;
            f.Fstartline.Sfilename = cast(char *)fd.loc.filename;
            if (fd.endloc.linnum)
            {
                f.Fendline.Slinnum = fd.endloc.linnum;
                f.Fendline.Scharnum = fd.endloc.charnum;
                f.Fendline.Sfilename = cast(char *)fd.endloc.filename;
            }
            else
            {
                f.Fendline.Slinnum = fd.loc.linnum;
                f.Fendline.Scharnum = fd.loc.charnum;
                f.Fendline.Sfilename = cast(char *)fd.loc.filename;
            }
            auto t = Type_toCtype(fd.type);

            const msave = t.Tmangle;
            if (fd.isMain())
            {
                t.Tty = TYnfunc;
                t.Tmangle = mTYman_c;
            }
            else
            {
                switch (fd.linkage)
                {
                    case LINKwindows:
                        t.Tmangle = global.params.is64bit ? mTYman_c : mTYman_std;
                        break;

                    case LINKpascal:
                        t.Tty = TYnpfunc;
                        t.Tmangle = mTYman_pas;
                        break;

                    case LINKc:
                    case LINKobjc:
                        t.Tmangle = mTYman_c;
                        break;

                    case LINKd:
                        t.Tmangle = mTYman_d;
                        break;
                    case LINKcpp:
                        s.Sflags |= SFLpublic;
                        if (fd.isThis() && !global.params.is64bit && global.params.isWindows)
                        {
                            if ((cast(TypeFunction)fd.type).varargs == 1)
                            {
                                t.Tty = TYnfunc;
                            }
                            else
                            {
                                t.Tty = TYmfunc;
                            }
                        }
                        t.Tmangle = mTYman_d;
                        break;
                    default:
                        printf("linkage = %d\n", fd.linkage);
                        assert(0);
                }
            }

            if (msave)
                assert(msave == t.Tmangle);
            //printf("Tty = %x, mangle = x%x\n", t.Tty, t.Tmangle);
            t.Tcount++;
            s.Stype = t;
            //s.Sfielddef = this;

            result = s;
        }

        /*************************************
         * Create the "ClassInfo" symbol
         */

        override void visit(ClassDeclaration cd)
        {
            if (!scc)
                scc = fake_classsym(Id.ClassInfo);

            auto s = toSymbolX(cd, "__Class", SCextern, scc.Stype, "Z");
            s.Sfl = FLextern;
            s.Sflags |= SFLnodebug;
            result = s;
        }

        /*************************************
         * Create the "InterfaceInfo" symbol
         */

        override void visit(InterfaceDeclaration id)
        {
            if (!scc)
                scc = fake_classsym(Id.ClassInfo);

            auto s = toSymbolX(id, "__Interface", SCextern, scc.Stype, "Z");
            s.Sfl = FLextern;
            s.Sflags |= SFLnodebug;
            result = s;
        }

        /*************************************
         * Create the "ModuleInfo" symbol
         */

        override void visit(Module m)
        {
            if (!scc)
                scc = fake_classsym(Id.ClassInfo);

            auto s = toSymbolX(m, "__ModuleInfo", SCextern, scc.Stype, "Z");
            s.Sfl = FLextern;
            s.Sflags |= SFLnodebug;
            result = s;
        }
    }

    if (s.csym)
        return s.csym;

    scope ToSymbol v = new ToSymbol();
    s.accept(v);
    s.csym = v.result;
    return v.result;
}


/*************************************
 */

Symbol *toImport(Symbol *sym)
{
    //printf("Dsymbol.toImport('%s')\n", sym.Sident);
    char *n = sym.Sident.ptr;
    import core.stdc.stdlib : alloca;
    char *id = cast(char *) alloca(6 + strlen(n) + 1 + type_paramsize(sym.Stype).sizeof*3 + 1);
    int idlen;
    if (config.exe != EX_WIN32 && config.exe != EX_WIN64)
    {
        id = n;
        idlen = cast(int)strlen(n);
    }
    else if (sym.Stype.Tmangle == mTYman_std && tyfunc(sym.Stype.Tty))
    {
        if (config.exe == EX_WIN64)
            idlen = sprintf(id,"__imp_%s",n);
        else
            idlen = sprintf(id,"_imp__%s@%u",n,cast(uint)type_paramsize(sym.Stype));
    }
    else if (sym.Stype.Tmangle == mTYman_d)
    {
        idlen = sprintf(id,(config.exe == EX_WIN64) ? "__imp_%s" : "_imp_%s",n);
    }
    else
    {
        idlen = sprintf(id,(config.exe == EX_WIN64) ? "__imp_%s" : "_imp__%s",n);
    }
    auto t = type_alloc(TYnptr | mTYconst);
    t.Tnext = sym.Stype;
    t.Tnext.Tcount++;
    t.Tmangle = mTYman_c;
    t.Tcount++;
    auto s = symbol_calloc(id, idlen);
    s.Stype = t;
    s.Sclass = SCextern;
    s.Sfl = FLextern;
    return s;
}

/*********************************
 * Generate import symbol from symbol.
 */

Symbol *toImport(Dsymbol ds)
{
    if (!ds.isym)
    {
        if (!ds.csym)
            ds.csym = toSymbol(ds);
        ds.isym = toImport(ds.csym);
    }
    return ds.isym;
}

/*************************************
 * Thunks adjust the incoming 'this' pointer by 'offset'.
 */

Symbol *toThunkSymbol(FuncDeclaration fd, int offset)
{
    Symbol *s = toSymbol(fd);
    if (!offset)
        return s;

    __gshared int tmpnum;
    char[6 + tmpnum.sizeof * 3 + 1] name;

    sprintf(name.ptr,"_THUNK%d",tmpnum++);
    auto sthunk = symbol_name(name.ptr,SCstatic,fd.csym.Stype);
    sthunk.Sflags |= SFLnodebug | SFLartifical;
    sthunk.Sflags |= SFLimplem;
    outthunk(sthunk, fd.csym, 0, TYnptr, -offset, -1, 0);
    return sthunk;
}


/**************************************
 * Fake a struct symbol.
 */

Classsym *fake_classsym(Identifier id)
{
    auto t = type_struct_class(id.toChars(),8,0,
        null,null,
        false, false, true);

    t.Ttag.Sstruct.Sflags = STRglobal;
    t.Tflags |= TFsizeunknown | TFforward;
    assert(t.Tmangle == 0);
    t.Tmangle = mTYman_d;
    return t.Ttag;
}

/*************************************
 * This is accessible via the ClassData, but since it is frequently
 * needed directly (like for rtti comparisons), make it directly accessible.
 */

Symbol *toVtblSymbol(ClassDeclaration cd)
{
    if (!cd.vtblsym)
    {
        if (!cd.csym)
            toSymbol(cd);

        auto t = type_allocn(TYnptr | mTYconst, tstypes[TYvoid]);
        t.Tmangle = mTYman_d;
        auto s = toSymbolX(cd, "__vtbl", SCextern, t, "Z");
        s.Sflags |= SFLnodebug;
        s.Sfl = FLextern;
        cd.vtblsym = s;
    }
    return cd.vtblsym;
}

/**********************************
 * Create the static initializer for the struct/class.
 */

Symbol *toInitializer(AggregateDeclaration ad)
{
    if (!ad.sinit)
    {
        auto stag = fake_classsym(Id.ClassInfo);
        auto s = toSymbolX(ad, "__init", SCextern, stag.Stype, "Z");
        s.Sfl = FLextern;
        s.Sflags |= SFLnodebug;
        auto sd = ad.isStructDeclaration();
        if (sd)
            s.Salignment = sd.alignment;
        ad.sinit = s;
    }
    return ad.sinit;
}

Symbol *toInitializer(EnumDeclaration ed)
{
    if (!ed.sinit)
    {
        auto stag = fake_classsym(Id.ClassInfo);
        auto ident_save = ed.ident;
        if (!ed.ident)
            ed.ident = Identifier.generateId("__enum");
        auto s = toSymbolX(ed, "__init", SCextern, stag.Stype, "Z");
        ed.ident = ident_save;
        s.Sfl = FLextern;
        s.Sflags |= SFLnodebug;
        ed.sinit = s;
    }
    return ed.sinit;
}


/********************************************
 * Determine the right symbol to look up
 * an associative array element.
 * Input:
 *      flags   0       don't add value signature
 *              1       add value signature
 */

Symbol *aaGetSymbol(TypeAArray taa, const(char)* func, int flags)
{
    assert((flags & ~1) == 0);

    // Dumb linear symbol table - should use associative array!
    __gshared Symbol*[] sarray;

    //printf("aaGetSymbol(func = '%s', flags = %d, key = %p)\n", func, flags, key);
    import core.stdc.stdlib : alloca;
    auto id = cast(char *)alloca(3 + strlen(func) + 1);
    const idlen = sprintf(id, "_aa%s", func);

    // See if symbol is already in sarray
    foreach (i; 0 .. sarray.length)
    {
        auto s = sarray[i];
        if (strcmp(id, s.Sident.ptr) == 0)
        {
            return s;                       // use existing Symbol
        }
    }

    // Create new Symbol

    auto s = symbol_calloc(id, idlen);
    s.Sclass = SCextern;
    s.Ssymnum = -1;
    symbol_func(s);

    auto t = type_function(TYnfunc, null, 0, false, Type_toCtype(taa.next));
    t.Tmangle = mTYman_c;
    s.Stype = t;

    sarray ~= s;                         // remember it
    return s;
}

/*****************************************************/
/*                   CTFE stuff                      */
/*****************************************************/

Symbol* toSymbol(StructLiteralExp sle)
{
    if (sle.sym)
        return sle.sym;
    auto t = type_alloc(TYint);
    t.Tcount++;
    auto s = symbol_calloc("internal", 8);
    s.Sclass = SCstatic;
    s.Sfl = FLextern;
    s.Sflags |= SFLnodebug;
    s.Stype = t;
    sle.sym = s;
    scope DtBuilder dtb = new DtBuilder();
    Expression_toDt(sle, dtb);
    s.Sdt = dtb.finish();
    outdata(s);
    return sle.sym;
}

Symbol* toSymbol(ClassReferenceExp cre)
{
    if (cre.value.sym)
        return cre.value.sym;
    auto t = type_alloc(TYint);
    t.Tcount++;
    auto s = symbol_calloc("internal", 8);
    s.Sclass = SCstatic;
    s.Sfl = FLextern;
    s.Sflags |= SFLnodebug;
    s.Stype = t;
    cre.value.sym = s;
    scope DtBuilder dtb = new DtBuilder();
    ClassReferenceExp_toInstanceDt(cre, dtb);
    s.Sdt = dtb.finish();
    outdata(s);
    return cre.value.sym;
}

/**************************************
 * For C++ class cd, generate an instance of __cpp_type_info_ptr
 * and populate it with a pointer to the C++ type info.
 * Params:
 *      cd = C++ class
 * Returns:
 *      symbol of instance of __cpp_type_info_ptr
 */
Symbol* toSymbolCpp(ClassDeclaration cd)
{
    assert(cd.isCPPclass());

    /* For the symbol std::exception, the type info is _ZTISt9exception
     */
    if (!cd.cpp_type_info_ptr_sym)
    {
        __gshared Symbol *scpp;
        if (!scpp)
            scpp = fake_classsym(Id.cpp_type_info_ptr);
        Symbol *s = toSymbolX(cd, "_cpp_type_info_ptr", SCcomdat, scpp.Stype, "");
        s.Sfl = FLdata;
        s.Sflags |= SFLnodebug;
        scope DtBuilder dtb = new DtBuilder();
        cpp_type_info_ptr_toDt(cd, dtb);
        s.Sdt = dtb.finish();
        outdata(s);
        cd.cpp_type_info_ptr_sym = s;
    }
    return cd.cpp_type_info_ptr_sym;
}

/**********************************
 * Generate Symbol of C++ type info for C++ class cd.
 * Params:
 *      cd = C++ class
 * Returns:
 *      Symbol of cd's rtti type info
 */
Symbol *toSymbolCppTypeInfo(ClassDeclaration cd)
{
    const id = Target.cppTypeInfoMangle(cd);
    auto s = symbol_calloc(id, cast(uint)strlen(id));
    s.Sclass = SCextern;
    s.Sfl = FLextern;          // C++ code will provide the definition
    s.Sflags |= SFLnodebug;
    auto t = type_fake(TYnptr);
    t.Tcount++;
    s.Stype = t;
    return s;
}

