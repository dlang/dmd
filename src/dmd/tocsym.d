/**
 * Convert a D symbol to a symbol the linker understands (with mangled name).
 *
 * Copyright:   Copyright (C) 1999-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/tocsym.d, _tocsym.d)
 * Documentation:  https://dlang.org/phobos/dmd_tocsym.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/tocsym.d
 */

module dmd.tocsym;

import core.stdc.stdio;
import core.stdc.string;

import dmd.root.array;
import dmd.root.rmem;

import dmd.aggregate;
import dmd.arraytypes;
import dmd.astenums;
import dmd.complex;
import dmd.ctfeexpr;
import dmd.declaration;
import dmd.dclass;
import dmd.denum;
import dmd.dmodule;
import dmd.dstruct;
import dmd.dsymbol;
import dmd.dtemplate;
import dmd.e2ir;
import dmd.errors;
import dmd.expression;
import dmd.func;
import dmd.globals;
import dmd.glue;
import dmd.identifier;
import dmd.id;
import dmd.init;
import dmd.mtype;
import dmd.target;
import dmd.toctype;
import dmd.todt;
import dmd.toir;
import dmd.tokens;
import dmd.typinf;
import dmd.visitor;
import dmd.dmangle;

import dmd.backend.cdef;
import dmd.backend.cc;
import dmd.backend.dt;
import dmd.backend.type;
import dmd.backend.global;
import dmd.backend.oper;
import dmd.backend.cgcv;
import dmd.backend.symtab;
import dmd.backend.ty;

extern (C++):


/*************************************
 * Helper
 */

Symbol *toSymbolX(Dsymbol ds, const(char)* prefix, int sclass, type *t, const(char)* suffix)
{
    //printf("Dsymbol::toSymbolX('%s')\n", prefix);
    import core.stdc.stdlib : malloc, free;
    import dmd.root.outbuffer : OutBuffer;

    OutBuffer buf;
    mangleToBuffer(ds, &buf);
    size_t nlen = buf.length;
    const(char)* n = buf.peekChars();
    assert(n);

    import core.stdc.string : strlen;
    size_t prefixlen = strlen(prefix);
    size_t suffixlen = strlen(suffix);
    size_t idlen = 2 + nlen + size_t.sizeof * 3 + prefixlen + suffixlen + 1;

    char[64] idbuf = void;
    char *id = &idbuf[0];
    if (idlen > idbuf.sizeof)
    {
        id = cast(char *)Mem.check(malloc(idlen));
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

private __gshared Symbol *scc;

/*************************************
 */

Symbol *toSymbol(Dsymbol s)
{
    extern (C++) static final class ToSymbol : Visitor
    {
        alias visit = Visitor.visit;

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

            const(char)[] id;
            import dmd.root.outbuffer : OutBuffer;
            OutBuffer buf;
            bool isNRVO = false;
            if (vd.isDataseg())
            {
                mangleToBuffer(vd, &buf);
                id = buf.peekChars()[0..buf.length]; // symbol_calloc needs zero termination
            }
            else
            {
                id = vd.ident.toString();
                if (FuncDeclaration fd = vd.toParent2().isFuncDeclaration())
                {
                    if (fd.nrvo_can && fd.nrvo_var == vd)
                    {
                        buf.writestring("__nrvo_");
                        buf.writestring(id);
                        id = buf.peekChars()[0..buf.length]; // symbol_calloc needs zero termination
                        isNRVO = true;
                    }
                }
            }
            Symbol *s = symbol_calloc(id.ptr, cast(uint)id.length);
            s.Salignment = vd.alignment;
            if (vd.storage_class & STC.temp)
                s.Sflags |= SFLartifical;
            if (isNRVO)
                s.Sflags |= SFLnodebug;

            TYPE *t;
            if (vd.storage_class & (STC.out_ | STC.ref_))
            {
                t = type_allocn(TYnref, Type_toCtype(vd.type));
                t.Tcount++;
            }
            else if (vd.storage_class & STC.lazy_)
            {
                if (target.os == Target.OS.Windows && target.is64bit && vd.isParameter())
                    t = type_fake(TYnptr);
                else
                    t = type_fake(TYdelegate);          // Tdelegate as C type
                t.Tcount++;
            }
            else if (vd.isParameter())
            {
                if (ISX64REF(vd))
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

            /* Even if a symbol is immutable, if it has a constructor then
             * the constructor mutates it. Remember that constructors can
             * be inlined into other code.
             * Just can't rely on it being immutable.
             */
            if (t.Tty & (mTYimmutable | mTYconst))
            {
                if (vd.ctorinit)
                {
                    /* It was initialized in a constructor, so not really immutable
                     * as far as the optimizer is concerned, as in this case:
                     *   immutable int x;
                     *   shared static this() { x += 3; }
                     */
                    t = type_setty(&t, t.Tty & ~(mTYimmutable | mTYconst));
                }
                else if (auto ts = vd.type.isTypeStruct())
                {
                    if (!ts.isMutable() && ts.sym.ctor)
                    {
                        t = type_setty(&t, t.Tty & ~(mTYimmutable | mTYconst));
                    }
                }
                else if (auto tc = vd.type.isTypeClass())
                {
                    if (!tc.isMutable() && tc.sym.ctor)
                    {
                        t = type_setty(&t, t.Tty & ~(mTYimmutable | mTYconst));
                    }
                }
            }

            if (vd.isDataseg())
            {
                if (vd.isThreadlocal() && !(vd.storage_class & STC.temp))
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
                        message(vd.loc, "`%s` is thread local", vd.toChars());
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

            if (vd.storage_class & STC.volatile_)
            {
                type_setcv(&t, t.Tty | mTYvolatile);
            }

            mangle_t m = 0;
            final switch (vd.linkage)
            {
                case LINK.windows:
                    m = target.is64bit ? mTYman_c : mTYman_std;
                    break;

                case LINK.objc:
                case LINK.c:
                    m = mTYman_c;
                    break;

                case LINK.d:
                    m = mTYman_d;
                    break;

                case LINK.cpp:
                    s.Sflags |= SFLpublic;
                    m = mTYman_cpp;
                    break;

                case LINK.default_:
                case LINK.system:
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
            visit(tid.isVarDeclaration());
        }

        override void visit(TypeInfoClassDeclaration ticd)
        {
            //printf("TypeInfoClassDeclaration.toSymbol(%s), linkage = %d\n", ticd.toChars(), ticd.linkage);
            ticd.tinfo.isTypeClass().sym.accept(this);
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

            if (fd.type.toBasetype().isTypeFunction().nextOf().isTypeNoreturn())
                s.Sflags |= SFLexit;    // the function never returns

            f.Fstartline.set(fd.loc.filename, fd.loc.linnum, fd.loc.charnum);
            if (fd.endloc.linnum)
            {
                f.Fendline.set(fd.endloc.filename, fd.endloc.linnum, fd.endloc.charnum);
            }
            else
            {
                f.Fendline = f.Fstartline;
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
                final switch (fd.linkage)
                {
                    case LINK.windows:
                        t.Tmangle = target.is64bit ? mTYman_c : mTYman_std;
                        break;

                    case LINK.c:
                    case LINK.objc:
                        t.Tmangle = mTYman_c;
                        break;

                    case LINK.d:
                        t.Tmangle = mTYman_d;
                        break;
                    case LINK.cpp:
                        s.Sflags |= SFLpublic;
                        if (fd.isThis() && !target.is64bit && target.os == Target.OS.Windows)
                        {
                            if ((cast(TypeFunction)fd.type).parameterList.varargs == VarArg.variadic)
                            {
                                t.Tty = TYnfunc;
                            }
                            else
                            {
                                t.Tty = TYmfunc;
                            }
                        }
                        t.Tmangle = mTYman_cpp;
                        break;
                    case LINK.default_:
                    case LINK.system:
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

        static type* getClassInfoCType()
        {
            if (!scc)
                scc = fake_classsym(Id.ClassInfo);
            return scc.Stype;
        }

        /*************************************
         * Create the "ClassInfo" symbol
         */

        override void visit(ClassDeclaration cd)
        {
            auto s = toSymbolX(cd, "__Class", SCextern, getClassInfoCType(), "Z");
            s.Sfl = FLextern;
            s.Sflags |= SFLnodebug;
            result = s;
        }

        /*************************************
         * Create the "InterfaceInfo" symbol
         */

        override void visit(InterfaceDeclaration id)
        {
            auto s = toSymbolX(id, "__Interface", SCextern, getClassInfoCType(), "Z");
            s.Sfl = FLextern;
            s.Sflags |= SFLnodebug;
            result = s;
        }

        /*************************************
         * Create the "ModuleInfo" symbol
         */

        override void visit(Module m)
        {
            auto s = toSymbolX(m, "__ModuleInfo", SCextern, getClassInfoCType(), "Z");
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
    if (target.os & Target.OS.Posix)
    {
        id = n;
        idlen = cast(int)strlen(n);
    }
    else if (sym.Stype.Tmangle == mTYman_std && tyfunc(sym.Stype.Tty))
    {
        if (target.os == Target.OS.Windows && target.is64bit)
            idlen = sprintf(id,"__imp_%s",n);
        else
            idlen = sprintf(id,"_imp__%s@%u",n,cast(uint)type_paramsize(sym.Stype));
    }
    else
    {
        idlen = sprintf(id,(target.os == Target.OS.Windows && target.is64bit) ? "__imp_%s" : "_imp__%s",n);
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

    if (retStyle(fd.type.isTypeFunction(), fd.needThis()) == RET.stack)
        s.Sfunc.Fflags3 |= F3hiddenPtr;

    __gshared int tmpnum;
    char[6 + tmpnum.sizeof * 3 + 1] name = void;

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
        false, false, true, false);

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
    if (!cd.vtblsym || !cd.vtblsym.csym)
    {
        if (!cd.csym)
            toSymbol(cd);

        auto t = type_allocn(TYnptr | mTYconst, tstypes[TYvoid]);
        t.Tmangle = mTYman_d;
        auto s = toSymbolX(cd, "__vtbl", SCextern, t, "Z");
        s.Sflags |= SFLnodebug;
        s.Sfl = FLextern;

        auto vtbl = cd.vtblSymbol();
        vtbl.csym = s;
    }
    return cd.vtblsym.csym;
}

/**********************************
 * Create the static initializer for the struct/class.
 */

Symbol *toInitializer(AggregateDeclaration ad)
{
    //printf("toInitializer() %s\n", ad.toChars());
    if (!ad.sinit)
    {
        static structalign_t alignOf(Type t)
        {
            const explicitAlignment = t.alignment();
            return explicitAlignment == STRUCTALIGN_DEFAULT ? t.alignsize() : explicitAlignment;
        }

        auto sd = ad.isStructDeclaration();
        if (sd &&
            alignOf(sd.type) <= 16 &&
            sd.type.size() <= 128 &&
            sd.zeroInit &&
            config.objfmt != OBJ_MACH && // same reason as in toobj.d toObjFile()
            !(config.objfmt == OBJ_MSCOFF && !target.is64bit)) // -m32mscoff relocations are wrong
        {
            auto bzsave = bzeroSymbol;
            ad.sinit = getBzeroSymbol();

            // Ensure emitted only once per object file
            if (bzsave && bzeroSymbol != bzsave)
                assert(0);
        }
        else
        {
            auto stag = fake_classsym(Id.ClassInfo);
            auto s = toSymbolX(ad, "__init", SCextern, stag.Stype, "Z");
            s.Sfl = FLextern;
            s.Sflags |= SFLnodebug;
            if (sd)
                s.Salignment = sd.alignment;
            ad.sinit = s;
        }
    }
    return cast(Symbol*)ad.sinit;
}

Symbol *toInitializer(EnumDeclaration ed)
{
    if (!ed.sinit)
    {
        auto stag = fake_classsym(Id.ClassInfo);
        assert(ed.ident);
        auto s = toSymbolX(ed, "__init", SCextern, stag.Stype, "Z");
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
    foreach (s; sarray)
    {
        if (strcmp(id, s.Sident.ptr) == 0)
        {
            return s;                       // use existing Symbol
        }
    }

    // Create new Symbol

    auto s = symbol_calloc(id, idlen);
    s.Sclass = SCextern;
    s.Ssymnum = SYMIDX.max;
    symbol_func(s);

    auto t = type_function(TYnfunc, null, false, Type_toCtype(taa.next));
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
    //printf("toSymbol() %p.sym: %p\n", sle, sle.sym);
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
    auto dtb = DtBuilder(0);
    Expression_toDt(sle, dtb);
    s.Sdt = dtb.finish();
    outdata(s);
    return sle.sym;
}

Symbol* toSymbol(ClassReferenceExp cre)
{
    //printf("toSymbol() %p.value.sym: %p\n", cre, cre.value.sym);
    if (cre.value.origin.sym)
        return cre.value.origin.sym;
    auto t = type_alloc(TYint);
    t.Tcount++;
    auto s = symbol_calloc("internal", 8);
    s.Sclass = SCstatic;
    s.Sfl = FLextern;
    s.Sflags |= SFLnodebug;
    s.Stype = t;
    cre.value.sym = s;
    cre.value.origin.sym = s;
    auto dtb = DtBuilder(0);
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
        auto dtb = DtBuilder(0);
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
    const id = target.cpp.typeInfoMangle(cd);
    auto s = symbol_calloc(id, cast(uint)strlen(id));
    s.Sclass = SCextern;
    s.Sfl = FLextern;          // C++ code will provide the definition
    s.Sflags |= SFLnodebug;
    auto t = type_fake(TYnptr);
    t.Tcount++;
    s.Stype = t;
    return s;
}
