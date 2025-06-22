/**
 * Put initializers and objects created from CTFE into a `dt_t` data structure
 * so the backend puts them into the data segment.
 *
 * Copyright:   Copyright (C) 1999-2025 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/todt.d, _todt.d)
 * Documentation:  https://dlang.org/phobos/dmd_todt.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/todt.d
 */

module dmd.todt;

import core.stdc.stdio;
import core.stdc.string;

import dmd.root.array;
import dmd.root.complex;
import dmd.root.rmem;

import dmd.aggregate;
import dmd.arraytypes;
import dmd.astenums;
import dmd.backend.type;
import dmd.ctfeexpr;
import dmd.declaration;
import dmd.dcast : implicitConvTo;
import dmd.dclass;
import dmd.denum;
import dmd.dstruct;
import dmd.dsymbol;
import dmd.dtemplate;
import dmd.errors;
import dmd.expression;
import dmd.func;
import dmd.globals;
import dmd.glue;
import dmd.init;
import dmd.location;
import dmd.mtype;
import dmd.optimize;
import dmd.semantic3 : search_toString;
import dmd.target;
import dmd.templatesem;
import dmd.tokens;
import dmd.tocsym;
import dmd.toobj;
import dmd.typesem;
import dmd.visitor;

import dmd.backend.cc;
import dmd.backend.dt;

/* A dt_t is a simple structure representing data to be added
 * to the data segment of the output object file. As such,
 * it is a list of initialized bytes, 0 data, and offsets from
 * other symbols.
 * Each D symbol and type can be converted into a dt_t so it can
 * be written to the data segment.
 */

alias Dts = Array!(dt_t*);

/* ================================================================ */

void Initializer_toDt(Initializer init, ref DtBuilder dtb, bool isCfile)
{
    void visitError(ErrorInitializer)
    {
        assert(0);
    }

    void visitVoid(VoidInitializer vi)
    {
        /* Void initializers are set to 0, just because we need something
         * to set them to in the static data segment.
         */
        dtb.nzeros(cast(uint)vi.type.size());
    }

    void visitStruct(StructInitializer si)
    {
        /* The StructInitializer was converted to a StructLiteralExp,
         * which is converted to dtb by membersToDt()
         */
        //printf("StructInitializer.toDt('%s')\n", si.toChars());
        assert(0);
    }

    void visitArray(ArrayInitializer ai)
    {
        //printf("ArrayInitializer.toDt('%s')\n", ai.toChars());
        Type tb = ai.type.toBasetype();
        if (tb.ty == Tvector)
            tb = (cast(TypeVector)tb).basetype;

        if (ai.dim == 0 && tb.isZeroInit(ai.loc))
        {
            dtb.nzeros(cast(uint)ai.type.size());
            return;
        }
        Type tn = tb.nextOf().toBasetype();

        //printf("\tdim = %d\n", ai.dim);
        Dts dts = Dts(ai.dim);
        dts.zero();

        uint size = cast(uint)tn.size();

        uint length = 0;
        foreach (i, idx; ai.index)
        {
            if (idx)
                length = cast(uint)idx.toInteger();
            //printf("\tindex[%d] = %p, length = %u, dim = %u\n", i, idx, length, ai.dim);

            assert(length < ai.dim);
            auto dtb = DtBuilder(0);
            Initializer_toDt(ai.value[i], dtb, isCfile);
            if (dts[length] && !ai.isCarray)
                error(ai.loc, "duplicate initializations for index `%d`", length);
            dts[length] = dtb.finish();
            length++;
        }

        Expression edefault = tb.nextOf().defaultInit(Loc.initial, isCfile);

        const n = tn.numberOfElems(ai.loc);

        dt_t* dtdefault = null;

        auto dtbarray = DtBuilder(0);
        foreach (dt; dts)
        {
            if (dt)
                dtbarray.cat(dt);
            else
            {
                if (!dtdefault)
                {
                    auto dtb = DtBuilder(0);
                    Expression_toDt(edefault, dtb);
                    dtdefault = dtb.finish();
                }
                dtbarray.repeat(dtdefault, n);
            }
        }
        switch (tb.ty)
        {
            case Tsarray:
            {
                TypeSArray ta = cast(TypeSArray)tb;
                size_t tadim = cast(size_t)ta.dim.toInteger();
                if (ai.dim < tadim)
                {
                    if (edefault.toBool().hasValue(false))
                    {
                        // pad out end of array
                        dtbarray.nzeros(cast(uint)(size * (tadim - ai.dim)));
                    }
                    else
                    {
                        if (!dtdefault)
                        {
                            auto dtb = DtBuilder(0);
                            Expression_toDt(edefault, dtb);
                            dtdefault = dtb.finish();
                        }

                        const m = n * (tadim - ai.dim);
                        assert(m <= uint.max);
                        dtbarray.repeat(dtdefault, cast(uint)m);
                    }
                }
                else if (ai.dim > tadim)
                {
                    error(ai.loc, "too many initializers, %u, for array[%llu]", ai.dim, cast(ulong) tadim);
                }
                dtb.cat(dtbarray);
                break;
            }

            case Tpointer:
            case Tarray:
            {
                if (tb.ty == Tarray)
                    dtb.size(ai.dim);
                Symbol* s = dtb.dtoff(dtbarray.finish(), 0);
                if (tn.isMutable())
                    foreach (i; 0 .. ai.dim)
                        write_pointers(tn, s, size * cast(int)i);
                break;
            }

            default:
                assert(0);
        }
        dt_free(dtdefault);
    }

    void visitExp(ExpInitializer ei)
    {
        //printf("ExpInitializer.toDt() %s\n", ei.exp.toChars());
        ei.exp = ei.exp.optimize(WANTvalue);
        Expression_toDt(ei.exp, dtb);
    }

    void visitC(CInitializer ci)
    {
        /* Should have been rewritten to Exp/Struct/ArrayInitializer by semantic()
         */
        assert(0);
    }

    void visitDefault(DefaultInitializer di)
    {
        /* Default initializers are set to 0, because C23 says so
         */
        dtb.nzeros(cast(uint)di.type.size());
    }

    mixin VisitInitializer!void visit;
    visit.VisitInitializer(init);
}

/* ================================================================ */

void Expression_toDt(Expression e, ref DtBuilder dtb)
{
    dtb.checkInitialized();

    void nonConstExpError(Expression e)
    {
        version (none)
        {
            printf("Expression.toDt() op = %d e = %s \n", e.op, e.toChars());
        }
        error(e.loc, "non-constant expression `%s`", e.toChars());
        dtb.nzeros(1);
    }

    void visitSlice(SliceExp e)
    {
        version (none)
        {
            printf("SliceExp.toDt() %d from %s to %s\n", e.op, e.e1.type.toChars(), e.type.toChars());
        }
        if (!e.lwr && !e.upr)
            return Expression_toDt(e.e1, dtb);

        size_t len;
        if (auto strExp = e.e1.isStringExp())
            len = strExp.len;
        else if (auto arrExp = e.e1.isArrayLiteralExp())
            len = arrExp.elements.length;
        else
            return nonConstExpError(e);

        auto lwr = e.lwr.isIntegerExp();
        auto upr = e.upr.isIntegerExp();
        if (lwr && upr && lwr.toInteger() == 0 && upr.toInteger() == len)
            return Expression_toDt(e.e1, dtb);

        nonConstExpError(e);
    }

    void visitCast(CastExp e)
    {
        version (none)
        {
            printf("CastExp.toDt() %d from %s to %s\n", e.op, e.e1.type.toChars(), e.type.toChars());
        }
        if (e.e1.type.ty == Tclass)
        {
            if (auto toc = e.type.isTypeClass())
            {
                if (auto toi = toc.sym.isInterfaceDeclaration()) // casting from class to interface
                {
                    auto cre1 = e.e1.isClassReferenceExp();
                    ClassDeclaration from = cre1.originalClass();
                    int off = 0;
                    const isbase = toi.isBaseOf(from, &off);
                    assert(isbase);
                    ClassReferenceExp_toDt(cre1, dtb, off);
                }
                else //casting from class to class
                {
                    Expression_toDt(e.e1, dtb);
                }
                return;
            }
        }
        nonConstExpError(e);
    }

    void visitAddr(AddrExp e)
    {
        version (none)
        {
            printf("AddrExp.toDt() %d\n", e.op);
        }
        if (auto sl = e.e1.isStructLiteralExp())
        {
            Symbol* s = toSymbol(sl);
            dtb.xoff(s, 0);
            if (sl.type.isMutable())
                write_pointers(sl.type, s, 0);
            return;
        }
        nonConstExpError(e);
    }

    void visitInteger(IntegerExp e)
    {
        //printf("IntegerExp.toDt() %d\n", e.op);
        auto value = e.getInteger();
        dtb.nbytes((cast(ubyte*) &value)[0 .. cast(size_t) e.type.size()]);
    }

    void visitReal(RealExp e)
    {
        //printf("RealExp.toDt(%Lg)\n", e.value);
        switch (e.type.toBasetype().ty)
        {
            case Tfloat32:
            case Timaginary32:
            {
                auto fvalue = cast(float)e.value;
                dtb.nbytes((cast(ubyte*)&fvalue)[0 .. 4]);
                break;
            }

            case Tfloat64:
            case Timaginary64:
            {
                auto dvalue = cast(double)e.value;
                dtb.nbytes((cast(ubyte*)&dvalue)[0 .. 8]);
                break;
            }

            case Tfloat80:
            case Timaginary80:
            {
                auto evalue = e.value;
                dtb.nbytes((cast(ubyte*)&evalue)[0 .. target.realsize - target.realpad]);
                dtb.nzeros(target.realpad);
                break;
            }

            default:
                printf("%s, e.type=%s\n", e.toChars(), e.type.toChars());
                assert(0);
        }
    }

    void visitComplex(ComplexExp e)
    {
        //printf("ComplexExp.toDt() '%s'\n", e.toChars());
        switch (e.type.toBasetype().ty)
        {
            case Tcomplex32:
            {
                auto fvalue = cast(float)creall(e.value);
                dtb.nbytes((cast(ubyte*)&fvalue)[0 .. 4]);
                fvalue = cast(float)cimagl(e.value);
                dtb.nbytes((cast(ubyte*)&fvalue)[0 .. 4]);
                break;
            }

            case Tcomplex64:
            {
                auto dvalue = cast(double)creall(e.value);
                dtb.nbytes((cast(ubyte*)&dvalue)[0 .. 8]);
                dvalue = cast(double)cimagl(e.value);
                dtb.nbytes((cast(ubyte*)&dvalue)[0 .. 8]);
                break;
            }

            case Tcomplex80:
            {
                auto evalue = creall(e.value);
                dtb.nbytes((cast(ubyte*)&evalue)[0 .. target.realsize - target.realpad]);
                dtb.nzeros(target.realpad);
                evalue = cimagl(e.value);
                dtb.nbytes((cast(ubyte*)&evalue)[0 .. target.realsize - target.realpad]);
                dtb.nzeros(target.realpad);
                break;
            }

            default:
                assert(0);
        }
    }

    void visitNull(NullExp e)
    {
        assert(e.type);
        dtb.nzeros(cast(uint)e.type.size());
    }

    void visitString(StringExp e)
    {
        //printf("StringExp.toDt() '%s', type = %s\n", e.toChars(), e.type.toChars());
        Type t = e.type.toBasetype();

        // BUG: should implement some form of static string pooling
        const n = cast(int)e.numberOfCodeUnits();
        const(char)* p;
        char* q;
        if (e.sz == 1)
            p = e.peekString().ptr;
        else
        {
            q = cast(char*)mem.xmalloc(n * e.sz);
            e.writeTo(q, false);
            p = q;
        }

        switch (t.ty)
        {
            case Tarray:
                dtb.size(n);
                goto case Tpointer;

            case Tpointer:
                if (e.sz == 1)
                {
                    import dmd.e2ir : toStringSymbol;
                    import dmd.glue : totym;
                    Symbol* s = toStringSymbol(p, n, e.sz);
                    dtb.xoff(s, 0);
                }
                else
                {
                    import core.bitop : bsr;
                    const pow2 = cast(ubyte) bsr(e.sz);
                    dtb.abytes(0, p[0 .. n * e.sz], cast(uint) e.sz, pow2);
                }
                break;

            case Tsarray:
            {
                auto tsa = t.isTypeSArray();

                dtb.nbytes((cast(ubyte*) p)[0 .. n * e.sz]);
                if (tsa.dim)
                {
                    dinteger_t dim = tsa.dim.toInteger();
                    if (n < dim)
                    {
                        // Pad remainder with 0
                        dtb.nzeros(cast(uint)((dim - n) * tsa.next.size()));
                    }
                }
                break;
            }

            default:
                printf("StringExp.toDt(type = %s)\n", e.type.toChars());
                assert(0);
        }
        mem.xfree(q);
    }

    void visitArrayLiteral(ArrayLiteralExp e)
    {
        //printf("ArrayLiteralExp.toDt() '%s', type = %s\n", e.toChars(), e.type.toChars());

        auto dtbarray = DtBuilder(0);
        foreach (i; 0 .. e.elements.length)
        {
            Expression_toDt(e[i], dtbarray);
        }

        Type t = e.type.toBasetype();
        switch (t.ty)
        {
            case Tsarray:
                dtb.cat(dtbarray);
                break;

            case Tarray:
                dtb.size(e.elements.length);
                goto case Tpointer;

            case Tpointer:
                if (auto d = dtbarray.finish())
                    dtb.dtoff(d, 0);
                else
                    dtb.size(0);

                break;

            default:
                assert(0);
        }
    }

    /* https://issues.dlang.org/show_bug.cgi?id=12652
       Non-constant hash initializers should have a special-case diagnostic
     */
    void visitAssocArrayLiteral(AssocArrayLiteralExp e)
    {
        if (!e.lowering)
        {
            error(e.loc, "internal compiler error: failed to detect static initialization of associative array");
            assert(0);
        }
        Expression_toDt(e.lowering, dtb);
        return;
    }

    void visitStructLiteral(StructLiteralExp sle)
    {
        //printf("StructLiteralExp.toDt() %s, ctfe = %d\n", sle.toChars(), sle.ownedByCtfe);
        assert(sle.sd.nonHiddenFields() <= sle.elements.length);
        membersToDt(sle.sd, dtb, sle.elements, 0, null, null);
    }

    void visitSymOff(SymOffExp e)
    {
        //printf("SymOffExp.toDt('%s')\n", e.var.toChars());
        assert(e.var);
        if (!(e.var.isDataseg() || e.var.isCodeseg()) ||
            e.var.isThreadlocal())
        {
            return nonConstExpError(e);
        }
        dtb.xoff(toSymbol(e.var), cast(uint)e.offset);
    }

    void visitVar(VarExp e)
    {
        //printf("VarExp.toDt() %d\n", e.op);

        if (auto v = e.var.isVarDeclaration())
        {
            if ((v.isConst() || v.isImmutable()) &&
                e.type.toBasetype().ty != Tsarray && v._init)
            {
                error(e.loc, "recursive reference `%s`", e.toChars());
                return;
            }
            v.inuse++;
            Initializer_toDt(v._init, dtb, v.isCsymbol());
            v.inuse--;
            return;
        }

        if (auto sd = e.var.isSymbolDeclaration())
        {
            if (sd.dsym)
            {

                if (auto s = sd.dsym.isStructDeclaration())
                    StructDeclaration_toDt(s, dtb);
                else if (auto c = sd.dsym.isClassDeclaration())
                    // Should be unreachable ATM, but just to be sure
                    ClassDeclaration_toDt(c, dtb);
                else
                    assert(false);
                return;
            }
        }

        return nonConstExpError(e);
    }

    void visitFunc(FuncExp e)
    {
        //printf("FuncExp.toDt() %d\n", e.op);
        if (e.fd.tok == TOK.reserved && e.type.ty == Tpointer)
        {
            // change to non-nested
            e.fd.tok = TOK.function_;
            e.fd.vthis = null;
        }
        Symbol* s = toSymbol(e.fd);
        toObjFile(e.fd, false);
        if (e.fd.tok == TOK.delegate_)
            dtb.size(0);
        dtb.xoff(s, 0);
    }

    void visitVector(VectorExp e)
    {
        //printf("VectorExp.toDt() %s\n", e.toChars());
        foreach (i; 0 .. e.dim)
        {
            Expression elem;
            if (auto ale = e.e1.isArrayLiteralExp())
                elem = ale[i];
            else
                elem = e.e1;
            Expression_toDt(elem, dtb);
        }
    }

    void visitClassReference(ClassReferenceExp e)
    {
        auto to = e.type.toBasetype().isTypeClass().sym.isInterfaceDeclaration();

        if (to) //Static typeof this literal is an interface. We must add offset to symbol
        {
            ClassDeclaration from = e.originalClass();
            int off = 0;
            const isbase = to.isBaseOf(from, &off);
            assert(isbase);
            ClassReferenceExp_toDt(e, dtb, off);
        }
        else
            ClassReferenceExp_toDt(e, dtb, 0);
    }

    void visitTypeid(TypeidExp e)
    {
        if (Type t = isType(e.obj))
        {
            TypeInfo_toObjFile(e, e.loc, t);
            Symbol* s = toSymbol(t.vtinfo);
            dtb.xoff(s, 0);
            return;
        }
        assert(0);
    }

    void visitNoreturn(Expression e)
    {
        // Noreturn field with default initializer
        assert(e);
    }

    switch (e.op)
    {
        default:                 return nonConstExpError(e);
        case EXP.cast_:          return visitCast          (e.isCastExp());
        case EXP.address:        return visitAddr          (e.isAddrExp());
        case EXP.int64:          return visitInteger       (e.isIntegerExp());
        case EXP.float64:        return visitReal          (e.isRealExp());
        case EXP.complex80:      return visitComplex       (e.isComplexExp());
        case EXP.null_:          return visitNull          (e.isNullExp());
        case EXP.string_:        return visitString        (e.isStringExp());
        case EXP.arrayLiteral:   return visitArrayLiteral  (e.isArrayLiteralExp());
        case EXP.structLiteral:  return visitStructLiteral (e.isStructLiteralExp());
        case EXP.symbolOffset:   return visitSymOff        (e.isSymOffExp());
        case EXP.variable:       return visitVar           (e.isVarExp());
        case EXP.function_:      return visitFunc          (e.isFuncExp());
        case EXP.vector:         return visitVector        (e.isVectorExp());
        case EXP.classReference: return visitClassReference(e.isClassReferenceExp());
        case EXP.typeid_:        return visitTypeid        (e.isTypeidExp());
        case EXP.assert_:        return visitNoreturn      (e);
        case EXP.slice:          return visitSlice         (e.isSliceExp());
        case EXP.assocArrayLiteral:   return visitAssocArrayLiteral(e.isAssocArrayLiteralExp());
    }
}

/* ================================================================= */

// Generate the data for the static initializer.

void ClassDeclaration_toDt(ClassDeclaration cd, ref DtBuilder dtb)
{
    //printf("ClassDeclaration.toDt(this = '%s')\n", cd.toChars());

    membersToDt(cd, dtb, null, 0, cd, null);

    //printf("-ClassDeclaration.toDt(this = '%s')\n", cd.toChars());
}

void StructDeclaration_toDt(StructDeclaration sd, ref DtBuilder dtb)
{
    //printf("+StructDeclaration.toDt(), this='%s'\n", sd.toChars());
    membersToDt(sd, dtb, null, 0, null, null);

    //printf("-StructDeclaration.toDt(), this='%s'\n", sd.toChars());
}

/******************************
 * Generate data for instance of __cpp_type_info_ptr that refers
 * to the C++ RTTI symbol for cd.
 * Params:
 *      cd = C++ class
 *      dtb = data table builder
 */
void cpp_type_info_ptr_toDt(ClassDeclaration cd, ref DtBuilder dtb)
{
    //printf("cpp_type_info_ptr_toDt(this = '%s')\n", cd.toChars());
    assert(cd.isCPPclass());

    // Put in first two members, the vtbl[] and the monitor
    dtb.xoff(toVtblSymbol(ClassDeclaration.cpp_type_info_ptr), 0);
    if (ClassDeclaration.cpp_type_info_ptr.hasMonitor())
        dtb.size(0);             // monitor

    // Create symbol for C++ type info
    Symbol* s = toSymbolCppTypeInfo(cd);

    // Put in address of cd's C++ type info
    dtb.xoff(s, 0);

    //printf("-cpp_type_info_ptr_toDt(this = '%s')\n", cd.toChars());
}

/****************************************************
 * Put out initializers of ad.fields[].
 * Although this is consistent with the elements[] version, we
 * have to use this optimized version to reduce memory footprint.
 * Params:
 *      ad = aggregate with members
 *      dtb = initializer list to append initialized data to
 *      elements = values to use as initializers, null means use default initializers
 *      firstFieldIndex = starting place in elements[firstFieldIndex]; always 0 for structs
 *      concreteType = structs: null, classes: most derived class
 *      ppb = pointer that moves through BaseClass[] from most derived class
 * Returns:
 *      updated tail of dt_t list
 */

private void membersToDt(AggregateDeclaration ad, ref DtBuilder dtb,
        Expressions* elements, size_t firstFieldIndex,
        ClassDeclaration concreteType,
        BaseClass*** ppb)
{
    ClassDeclaration cd = ad.isClassDeclaration();
    const bool isCtype = ad.isCsymbol();
    version (none)
    {
        printf("membersToDt(ad = '%s', concrete = '%s', ppb = %p)\n", ad.toChars(), concreteType ? concreteType.toChars() : "null", ppb);
        version (none)
        {
            printf(" interfaces.length = %d\n", cast(int)cd.interfaces.length);
            foreach (i, b; cd.vtblInterfaces[])
            {
                printf("  vbtblInterfaces[%d] b = %p, b.sym = %s\n", cast(int)i, b, b.sym.toChars());
            }
        }
        version (all)
        {
            foreach (i, field; ad.fields)
            {
                if (auto bf = field.isBitFieldDeclaration())
                    printf("  fields[%d]: %s %2d bitoffset %2d width %2d\n", cast(int)i, bf.toChars(), bf.offset, bf.bitOffset, bf.fieldWidth);
                else
                    printf("  fields[%d]: %s %2d\n", cast(int)i, field.toChars(), field.offset);
            }
        }
        version (none)
        {
            printf("  firstFieldIndex: %d\n", cast(int)firstFieldIndex);
            foreach (i; 0 .. elements.length)
            {
                auto e = (*elements)[i];
                printf("  elements[%d]: %s\n", cast(int)i, e ? e.toChars() : "null");
            }
        }
    }
    dtb.checkInitialized();
    //printf("+dtb.length: %d\n", dtb.length);

    /* Order:
     *  { base class } or { __vptr, __monitor }
     *  interfaces
     *  fields
     */

    uint offset;
    if (cd)
    {
        const bool gentypeinfo = global.params.useTypeInfo && Type.dtypeinfo;
        const bool genclassinfo = gentypeinfo || !(cd.isCPPclass || cd.isCOMclass);

        if (ClassDeclaration cdb = cd.baseClass)
        {
            // Insert { base class }
            size_t index = 0;
            for (ClassDeclaration c = cdb.baseClass; c; c = c.baseClass)
                index += c.fields.length;
            membersToDt(cdb, dtb, elements, index, concreteType, null);
            offset = cdb.structsize;
        }
        else if (InterfaceDeclaration id = cd.isInterfaceDeclaration())
        {
            offset = (**ppb).offset;
            if (id.vtblInterfaces.length == 0 && genclassinfo)
            {
                BaseClass* b = **ppb;
                //printf("  Interface %s, b = %p\n", id.toChars(), b);
                ++(*ppb);
                for (ClassDeclaration cd2 = concreteType; 1; cd2 = cd2.baseClass)
                {
                    assert(cd2);
                    uint csymoffset = baseVtblOffset(cd2, b);
                    //printf("    cd2 %s csymoffset = x%x\n", cd2 ? cd2.toChars() : "null", csymoffset);
                    if (csymoffset != ~0)
                    {
                        dtb.xoff(toSymbol(cd2), csymoffset);
                        offset += target.ptrsize;
                        break;
                    }
                }
            }
        }
        else
        {
            // Insert { __vptr, __monitor }
            dtb.xoff(toVtblSymbol(concreteType), 0);  // __vptr
            offset = target.ptrsize;
            if (cd.hasMonitor())
            {
                dtb.size(0);              // __monitor
                offset += target.ptrsize;
            }
        }

        // Interface vptr initializations
        if (genclassinfo)
        {
            toSymbol(cd);                                         // define csym
        }

        BaseClass** pb;
        if (!ppb)
        {
            pb = (*cd.vtblInterfaces)[].ptr;
            ppb = &pb;
        }

        foreach (si; cd.interfaces[])
        {
            BaseClass* b = **ppb;
            if (offset < b.offset)
                dtb.nzeros(b.offset - offset);
            membersToDt(si.sym, dtb, elements, firstFieldIndex, concreteType, ppb);
            //printf("b.offset = %d, b.sym.structsize = %d\n", cast(int)b.offset, cast(int)b.sym.structsize);
            offset = b.offset + b.sym.structsize;
        }
    }
    else
        offset = 0;
    // `offset` now is where the fields start

    assert(!elements ||
           firstFieldIndex <= elements.length &&
           firstFieldIndex + ad.fields.length <= elements.length);

    uint bitByteOffset = 0;     // byte offset of bit field
    uint bitOffset = 0;         // starting bit number
    ulong bitFieldValue = 0;    // in-flight bit field value
    uint bitFieldSize;          // in-flight size in bytes of bit field

    void finishInFlightBitField()
    {
        if (bitOffset)
        {
            //printf("finishInFlightBitField() offset %d bitOffset %d bitFieldSize %d bitFieldValue x%llx\n", offset, bitOffset, bitFieldSize, bitFieldValue);
            assert(bitFieldSize);

            // advance to start of bit field
            if (offset < bitByteOffset)
            {
                dtb.nzeros(bitByteOffset - offset);
                offset = bitByteOffset;
            }

            dtb.nbytes((cast(ubyte*) &bitFieldValue)[0 .. bitFieldSize]);
            offset += bitFieldSize;
            bitOffset = 0;
            bitFieldValue = 0;
            bitFieldSize = 0;
        }
    }

    static if (0)
    {
        foreach (i, field; ad.fields)
        {
            if (elements && !(*elements)[firstFieldIndex + i])
                continue;       // no element for this field

            if (!elements || !(*elements)[firstFieldIndex + i])
            {
                if (field._init && field._init.isVoidInitializer())
                    continue;   // void initializer for this field
            }

            VarDeclaration vd = field;
            auto bf = vd.isBitFieldDeclaration();
            if (bf)
                printf("%s\t offset: %d width: %u bit: %u\n", bf.toChars(), bf.offset, bf.fieldWidth, bf.bitOffset);
            else
                printf("%s\t offset: %d\n", vd.toChars(), vd.offset);
        }
    }

    foreach (i, field; ad.fields)
    {
        // skip if no element for this field
        if (elements && !(*elements)[firstFieldIndex + i])
            continue;

        // If void initializer
        if (!elements || !(*elements)[firstFieldIndex + i])
        {
            if (field._init && field._init.isVoidInitializer())
                continue;
        }

        /* This loop finds vd, the closest field that starts at `offset + bitOffset` or later
         */
        VarDeclaration vd;
        // Cache some extra information about vd
        BitFieldDeclaration bf; // bit field version of vd
        size_t k;               // field index of vd
        uint vdBitOffset;       // starting bit number of vd; 0 if not a bit field
        foreach (j; i .. ad.fields.length)
        {
            VarDeclaration v2 = ad.fields[j];
            if (v2.offset < offset)
                continue;

            if (elements && !(*elements)[firstFieldIndex + j])
                continue;

            if (!elements || !(*elements)[firstFieldIndex + j])
            {
                if (v2._init && v2._init.isVoidInitializer())
                    continue;
            }
            //printf(" checking v2 %s %d\n", v2.toChars(), v2.offset);

            auto bf2 = v2.isBitFieldDeclaration();
            uint v2BitOffset = bf2 ? bf2.bitOffset : 0;

            if (v2.offset * 8 + v2BitOffset < offset * 8 + vdBitOffset)
                continue;

            // find the nearest field
            if (!vd ||
                v2.offset * 8 + v2BitOffset < vd.offset * 8 + vdBitOffset)
            {
                // v2 is nearer, so remember the details
                //printf(" v2 %s is nearer\n", v2.toChars());
                vd = v2;
                bf = bf2;
                vdBitOffset = v2BitOffset;
                k = j;
            }
        }
        if (!vd)
        {
            continue;
        }

        if (!bf || bf.offset != offset)
        {
            finishInFlightBitField();
        }
        if (bf)
        {
            switch (target.c.bitFieldStyle)
            {
                case TargetC.BitFieldStyle.Gcc_Clang:
                    bitFieldSize = (bf.bitOffset + bf.fieldWidth + 7) / 8;
                    break;

                case TargetC.BitFieldStyle.MS:
                    // This relies on all bit fields in the same storage location have the same type
                    bitFieldSize = cast(uint)vd.type.size();
                    break;

                default:
                    assert(0);
            }
        }

        //printf("offset: %u, vd: %s vd.offset: %u\n", offset, vd.toChars(), vd.offset);
        if (vd.offset < offset)
            continue;           // a union field
        if (offset < vd.offset)
        {
            dtb.nzeros(vd.offset - offset);
            offset = vd.offset;
        }

        auto dtbx = DtBuilder(0);
        if (elements)
        {
            Expression e = (*elements)[firstFieldIndex + k];
            //printf("elements initializer %s\n", e.toChars());
            if (auto tsa = vd.type.toBasetype().isTypeSArray())
                toDtElem(tsa, dtbx, e, isCtype);
            else if (bf)
            {
                auto ie = e.isIntegerExp();
                assert(ie);
                auto value = ie.getInteger();
                const width = bf.fieldWidth;
                const mask = (1L << width) - 1;
                bitFieldValue = (bitFieldValue & ~(mask << bitOffset)) | ((value & mask) << bitOffset);
                //printf("bitFieldValue x%llx\n", bitFieldValue);
            }
            else
                Expression_toDt(e, dtbx);    // convert e to an initializer dt
        }
        else if (!bf)
        {
            if (Initializer init = vd._init)
            {
                //printf("\t\t%s has initializer %s\n", vd.toChars(), init.toChars());
                if (init.isVoidInitializer())
                    continue;

                assert(vd.semanticRun >= PASS.semantic2done);

                auto ei = init.isExpInitializer();
                auto tsa = vd.type.toBasetype().isTypeSArray();
                if (ei && tsa)
                    toDtElem(tsa, dtbx, ei.exp, isCtype);
                else
                    Initializer_toDt(init, dtbx, isCtype);
            }
            else if (offset <= vd.offset)
            {
                //printf("\t\tdefault initializer\n");
                Type_toDt(vd.type, dtbx);
            }
            if (dtbx.isZeroLength())
                continue;
        }

        if (!dtbx.isZeroLength())
            dtb.cat(dtbx);
        if (bf)
        {
            bitByteOffset = bf.offset;
            bitOffset = bf.bitOffset + bf.fieldWidth;
        }
        else
        {
            offset = cast(uint)(vd.offset + vd.type.size());
        }
    }

    finishInFlightBitField();

    if (offset < ad.structsize)
        dtb.nzeros(ad.structsize - offset);
    //printf("-dtb.length: %d\n", dtb.length);
}


/* ================================================================= */

void Type_toDt(Type t, ref DtBuilder dtb, bool isCtype = false)
{
    switch (t.ty)
    {
        case Tvector:
            toDtElem(t.isTypeVector().basetype.isTypeSArray(), dtb, null, isCtype);
            break;

        case Tsarray:
            toDtElem(t.isTypeSArray(), dtb, null, isCtype);
            break;

        case Tstruct:
            StructDeclaration_toDt(t.isTypeStruct().sym, dtb);
            break;

        default:
            Expression_toDt(t.defaultInit(Loc.initial, isCtype), dtb);
            break;
    }
}

private void toDtElem(TypeSArray tsa, ref DtBuilder dtb, Expression e, bool isCtype)
{
    //printf("TypeSArray.toDtElem() tsa = %s\n", tsa.toChars());
    if (tsa.size(Loc.initial) == 0)
    {
        dtb.nzeros(0);
    }
    else
    {
        size_t len = cast(size_t)tsa.dim.toInteger();
        assert(len);
        Type tnext = tsa.next;
        Type tbn = tnext.toBasetype();
        Type ten = e ? e.type : null;
        if (ten && ten.isStaticOrDynamicArray())
            ten = ten.nextOf();
        while (tbn.ty == Tsarray && (!e || !tbn.equivalent(ten)))
        {
            len *= tbn.isTypeSArray().dim.toInteger();
            tnext = tbn.nextOf();
            tbn = tnext.toBasetype();
        }
        if (!e)                             // if not already supplied
            e = tsa.defaultInit(Loc.initial, isCtype);    // use default initializer

        if (!e.type.implicitConvTo(tnext))    // https://issues.dlang.org/show_bug.cgi?id=14996
        {
            // https://issues.dlang.org/show_bug.cgi?id=1914
            // https://issues.dlang.org/show_bug.cgi?id=3198
            if (auto se = e.isStringExp())
                len /= se.numberOfCodeUnits();
            else if (auto ae = e.isArrayLiteralExp())
                len /= ae.elements.length;
        }

        auto dtb2 = DtBuilder(0);
        Expression_toDt(e, dtb2);
        dt_t* dt2 = dtb2.finish();
        assert(len <= uint.max);
        dtb.repeat(dt2, cast(uint)len);
    }
}

/*****************************************************/
/*                   CTFE stuff                      */
/*****************************************************/

private void ClassReferenceExp_toDt(ClassReferenceExp e, ref DtBuilder dtb, int off)
{
    //printf("ClassReferenceExp.toDt() %d\n", e.op);
    Symbol* s = toSymbol(e);
    dtb.xoff(s, off);
    if (e.type.isMutable())
        write_instance_pointers(e.type, s, 0);
}

void ClassReferenceExp_toInstanceDt(ClassReferenceExp ce, ref DtBuilder dtb)
{
    //printf("ClassReferenceExp.toInstanceDt() %d\n", ce.op);
    ClassDeclaration cd = ce.originalClass();

    // Put in the rest
    size_t firstFieldIndex = 0;
    for (ClassDeclaration c = cd.baseClass; c; c = c.baseClass)
        firstFieldIndex += c.fields.length;
    membersToDt(cd, dtb, ce.value.elements, firstFieldIndex, cd, null);
}

/****************************************************
 */
private extern (C++) class TypeInfoDtVisitor : Visitor
{
    DtBuilder* dtb;

    /*
     * Used in TypeInfo*.toDt to verify the runtime TypeInfo sizes
     */
    static void verifyStructSize(ClassDeclaration typeclass, size_t expected)
    {
        if (typeclass.structsize != expected)
        {
            debug
            {
                printf("expected = x%x, %s.structsize = x%x\n", cast(uint)expected,
                    typeclass.toChars(), cast(uint)typeclass.structsize);
            }
            error(typeclass.loc, "`%s`: mismatch between compiler (%d bytes) and object.d or object.di (%d bytes) found",
                typeclass.toChars(), cast(uint)expected, cast(uint)typeclass.structsize);
            errorSupplemental(typeclass.loc, "check installation and import paths with `-v` compiler switch");
            fatal();
        }
    }

    this(ref DtBuilder dtb) scope
    {
        this.dtb = &dtb;
    }

    alias visit = Visitor.visit;

    override void visit(TypeInfoDeclaration d)
    {
        //printf("TypeInfoDeclaration.toDt() %s\n", toChars());
        verifyStructSize(Type.dtypeinfo, 2 * target.ptrsize);

        dtb.xoff(toVtblSymbol(Type.dtypeinfo), 0);        // vtbl for TypeInfo
        if (Type.dtypeinfo.hasMonitor())
            dtb.size(0);                                  // monitor
    }

    override void visit(TypeInfoConstDeclaration d)
    {
        //printf("TypeInfoConstDeclaration.toDt() %s\n", toChars());
        verifyStructSize(Type.typeinfoconst, 3 * target.ptrsize);

        dtb.xoff(toVtblSymbol(Type.typeinfoconst), 0);    // vtbl for TypeInfo_Const
        if (Type.typeinfoconst.hasMonitor())
            dtb.size(0);                                  // monitor
        Type tm = d.tinfo.mutableOf();
        tm = tm.merge();
        TypeInfo_toObjFile(null, d.loc, tm);
        dtb.xoff(toSymbol(tm.vtinfo), 0);
    }

    override void visit(TypeInfoInvariantDeclaration d)
    {
        //printf("TypeInfoInvariantDeclaration.toDt() %s\n", toChars());
        verifyStructSize(Type.typeinfoinvariant, 3 * target.ptrsize);

        dtb.xoff(toVtblSymbol(Type.typeinfoinvariant), 0);    // vtbl for TypeInfo_Invariant
        if (Type.typeinfoinvariant.hasMonitor())
            dtb.size(0);                                      // monitor
        Type tm = d.tinfo.mutableOf();
        tm = tm.merge();
        TypeInfo_toObjFile(null, d.loc, tm);
        dtb.xoff(toSymbol(tm.vtinfo), 0);
    }

    override void visit(TypeInfoSharedDeclaration d)
    {
        //printf("TypeInfoSharedDeclaration.toDt() %s\n", toChars());
        verifyStructSize(Type.typeinfoshared, 3 * target.ptrsize);

        dtb.xoff(toVtblSymbol(Type.typeinfoshared), 0);   // vtbl for TypeInfo_Shared
        if (Type.typeinfoshared.hasMonitor())
            dtb.size(0);                                 // monitor
        Type tm = d.tinfo.unSharedOf();
        tm = tm.merge();
        TypeInfo_toObjFile(null, d.loc, tm);
        dtb.xoff(toSymbol(tm.vtinfo), 0);
    }

    override void visit(TypeInfoWildDeclaration d)
    {
        //printf("TypeInfoWildDeclaration.toDt() %s\n", toChars());
        verifyStructSize(Type.typeinfowild, 3 * target.ptrsize);

        dtb.xoff(toVtblSymbol(Type.typeinfowild), 0); // vtbl for TypeInfo_Wild
        if (Type.typeinfowild.hasMonitor())
            dtb.size(0);                              // monitor
        Type tm = d.tinfo.mutableOf();
        tm = tm.merge();
        TypeInfo_toObjFile(null, d.loc, tm);
        dtb.xoff(toSymbol(tm.vtinfo), 0);
    }

    override void visit(TypeInfoEnumDeclaration d)
    {
        //printf("TypeInfoEnumDeclaration.toDt()\n");
        verifyStructSize(Type.typeinfoenum, 7 * target.ptrsize);

        dtb.xoff(toVtblSymbol(Type.typeinfoenum), 0); // vtbl for TypeInfo_Enum
        if (Type.typeinfoenum.hasMonitor())
            dtb.size(0);                              // monitor

        assert(d.tinfo.ty == Tenum);

        TypeEnum tc = cast(TypeEnum)d.tinfo;
        EnumDeclaration sd = tc.sym;

        /* Put out:
         *  TypeInfo base;
         *  string name;
         *  void[] m_init;
         */

        // TypeInfo for enum members
        if (sd.memtype)
        {
            TypeInfo_toObjFile(null, d.loc, sd.memtype);
            dtb.xoff(toSymbol(sd.memtype.vtinfo), 0);
        }
        else
            dtb.size(0);

        // string name;
        const(char)* name = sd.toPrettyChars();
        size_t namelen = strlen(name);
        dtb.size(namelen);
        dtb.xoff(cast(Symbol*)d.csym, Type.typeinfoenum.structsize);

        // void[] init;
        if (!sd.members || d.tinfo.isZeroInit(Loc.initial))
        {
            // 0 initializer, or the same as the base type
            dtb.size(0);                     // init.length
            dtb.size(0);                     // init.ptr
        }
        else
        {
            dtb.size(sd.type.size());      // init.length
            dtb.xoff(toInitializer(sd), 0);    // init.ptr
        }

        // Put out name[] immediately following TypeInfo_Enum
        dtb.nbytes(name[0 .. namelen + 1]);
    }

    override void visit(TypeInfoPointerDeclaration d)
    {
        //printf("TypeInfoPointerDeclaration.toDt()\n");
        verifyStructSize(Type.typeinfopointer, 3 * target.ptrsize);

        dtb.xoff(toVtblSymbol(Type.typeinfopointer), 0);  // vtbl for TypeInfo_Pointer
        if (Type.typeinfopointer.hasMonitor())
            dtb.size(0);                                  // monitor

        auto tc = d.tinfo.isTypePointer();

        TypeInfo_toObjFile(null, d.loc, tc.next);
        dtb.xoff(toSymbol(tc.next.vtinfo), 0); // TypeInfo for type being pointed to
    }

    override void visit(TypeInfoArrayDeclaration d)
    {
        //printf("TypeInfoArrayDeclaration.toDt()\n");
        verifyStructSize(Type.typeinfoarray, 3 * target.ptrsize);

        dtb.xoff(toVtblSymbol(Type.typeinfoarray), 0);    // vtbl for TypeInfo_Array
        if (Type.typeinfoarray.hasMonitor())
            dtb.size(0);                                  // monitor

        auto tc = d.tinfo.isTypeDArray();

        TypeInfo_toObjFile(null, d.loc, tc.next);
        dtb.xoff(toSymbol(tc.next.vtinfo), 0); // TypeInfo for array of type
    }

    override void visit(TypeInfoStaticArrayDeclaration d)
    {
        //printf("TypeInfoStaticArrayDeclaration.toDt()\n");
        verifyStructSize(Type.typeinfostaticarray, 4 * target.ptrsize);

        dtb.xoff(toVtblSymbol(Type.typeinfostaticarray), 0);  // vtbl for TypeInfo_StaticArray
        if (Type.typeinfostaticarray.hasMonitor())
            dtb.size(0);                                      // monitor

        auto tc = d.tinfo.isTypeSArray();

        TypeInfo_toObjFile(null, d.loc, tc.next);
        dtb.xoff(toSymbol(tc.next.vtinfo), 0);   // TypeInfo for array of type

        dtb.size(tc.dim.toInteger());          // length
    }

    override void visit(TypeInfoVectorDeclaration d)
    {
        //printf("TypeInfoVectorDeclaration.toDt()\n");
        verifyStructSize(Type.typeinfovector, 3 * target.ptrsize);

        dtb.xoff(toVtblSymbol(Type.typeinfovector), 0);   // vtbl for TypeInfo_Vector
        if (Type.typeinfovector.hasMonitor())
            dtb.size(0);                                  // monitor

        auto tc = d.tinfo.isTypeVector();

        TypeInfo_toObjFile(null, d.loc, tc.basetype);
        dtb.xoff(toSymbol(tc.basetype.vtinfo), 0); // TypeInfo for equivalent static array
    }

    override void visit(TypeInfoAssociativeArrayDeclaration d)
    {
        //printf("TypeInfoAssociativeArrayDeclaration.toDt()\n");
        verifyStructSize(Type.typeinfoassociativearray, 7 * target.ptrsize);

        dtb.xoff(toVtblSymbol(Type.typeinfoassociativearray), 0); // vtbl for TypeInfo_AssociativeArray
        if (Type.typeinfoassociativearray.hasMonitor())
            dtb.size(0);                    // monitor

        auto tc = d.tinfo.isTypeAArray();

        TypeInfo_toObjFile(null, d.loc, tc.next);
        dtb.xoff(toSymbol(tc.next.vtinfo), 0);   // TypeInfo for array of type

        TypeInfo_toObjFile(null, d.loc, tc.index);
        dtb.xoff(toSymbol(tc.index.vtinfo), 0);  // TypeInfo for array of type

        TypeInfo_toObjFile(null, d.loc, d.entry);
        dtb.xoff(toSymbol(d.entry.vtinfo), 0);  // TypeInfo for key,value-pair

        dtb.xoff(toSymbol(d.xopEqual), 0);
        dtb.xoff(toSymbol(d.xtoHash), 0);
    }

    override void visit(TypeInfoFunctionDeclaration d)
    {
        //printf("TypeInfoFunctionDeclaration.toDt()\n");
        verifyStructSize(Type.typeinfofunction, 5 * target.ptrsize);

        dtb.xoff(toVtblSymbol(Type.typeinfofunction), 0); // vtbl for TypeInfo_Function
        if (Type.typeinfofunction.hasMonitor())
            dtb.size(0);                                  // monitor

        auto tc = d.tinfo.isTypeFunction();

        TypeInfo_toObjFile(null, d.loc, tc.next);
        dtb.xoff(toSymbol(tc.next.vtinfo), 0); // TypeInfo for function return value

        const name = d.tinfo.deco;
        assert(name);
        const namelen = strlen(name);
        dtb.size(namelen);
        dtb.xoff(cast(Symbol*)d.csym, Type.typeinfofunction.structsize);

        // Put out name[] immediately following TypeInfo_Function
        dtb.nbytes(name[0 .. namelen + 1]);
    }

    override void visit(TypeInfoDelegateDeclaration d)
    {
        //printf("TypeInfoDelegateDeclaration.toDt()\n");
        verifyStructSize(Type.typeinfodelegate, 5 * target.ptrsize);

        dtb.xoff(toVtblSymbol(Type.typeinfodelegate), 0); // vtbl for TypeInfo_Delegate
        if (Type.typeinfodelegate.hasMonitor())
            dtb.size(0);                                  // monitor

        auto tc = d.tinfo.isTypeDelegate();

        TypeInfo_toObjFile(null, d.loc, tc.next.nextOf());
        dtb.xoff(toSymbol(tc.next.nextOf().vtinfo), 0); // TypeInfo for delegate return value

        const name = d.tinfo.deco;
        assert(name);
        const namelen = strlen(name);
        dtb.size(namelen);
        dtb.xoff(cast(Symbol*)d.csym, Type.typeinfodelegate.structsize);

        // Put out name[] immediately following TypeInfo_Delegate
        dtb.nbytes(name[0 .. namelen + 1]);
    }

    override void visit(TypeInfoStructDeclaration d)
    {
        //printf("TypeInfoStructDeclaration.toDt() '%s'\n", d.toChars());
        if (target.isX86_64 || target.isAArch64)
            verifyStructSize(Type.typeinfostruct, 17 * target.ptrsize);
        else
            verifyStructSize(Type.typeinfostruct, 15 * target.ptrsize);

        dtb.xoff(toVtblSymbol(Type.typeinfostruct), 0); // vtbl for TypeInfo_Struct
        if (Type.typeinfostruct.hasMonitor())
            dtb.size(0);                                // monitor

        auto tc = d.tinfo.isTypeStruct();
        StructDeclaration sd = tc.sym;

        if (!sd.members)
            return;

        if (TemplateInstance ti = sd.isInstantiated())
        {
            if (!ti.needsCodegen())
            {
                assert(ti.minst || sd.requestTypeInfo);

                /* ti.toObjFile() won't get called. So, store these
                 * member functions into object file in here.
                 */

                if (sd.semanticRun < PASS.semantic3done)
                {
                    import dmd.semantic3 : semanticTypeInfoMembers;
                    semanticTypeInfoMembers(sd);
                }

                if (sd.xeq && sd.xeq != StructDeclaration.xerreq)
                    toObjFile(sd.xeq, global.params.multiobj);
                if (sd.xcmp && sd.xcmp != StructDeclaration.xerrcmp)
                    toObjFile(sd.xcmp, global.params.multiobj);
                if (FuncDeclaration ftostr = search_toString(sd))
                    toObjFile(ftostr, global.params.multiobj);
                if (sd.xhash)
                    toObjFile(sd.xhash, global.params.multiobj);
                if (sd.postblit)
                    toObjFile(sd.postblit, global.params.multiobj);
                if (sd.dtor)
                    toObjFile(sd.dtor, global.params.multiobj);
            }
        }

        /* Put out:
         *  char[] mangledName;
         *  void[] init;
         *  hash_t function(in void*) xtoHash;
         *  bool function(in void*, in void*) xopEquals;
         *  int function(in void*, in void*) xopCmp;
         *  string function(const(void)*) xtoString;
         *  StructFlags m_flags;
         *  //xgetMembers;
         *  xdtor;
         *  xpostblit;
         *  uint m_align;
         *  version (X86_64)
         *      TypeInfo m_arg1;
         *      TypeInfo m_arg2;
         *  xgetRTInfo
         */

        const mangledName = tc.deco;
        const mangledNameLen = strlen(mangledName);
        dtb.size(mangledNameLen);
        dtb.xoff(cast(Symbol*)d.csym, Type.typeinfostruct.structsize);

        // void[] init;
        dtb.size(sd.structsize);            // init.length
        if (sd.zeroInit)
            dtb.size(0);                     // null for 0 initialization
        else
            dtb.xoff(toInitializer(sd), 0);    // init.ptr

        if (FuncDeclaration fd = sd.xhash)
        {
            dtb.xoff(toSymbol(fd), 0);
            TypeFunction tf = cast(TypeFunction)fd.type;
            assert(tf.ty == Tfunction);
        }
        else
            dtb.size(0);

        if (sd.xeq)
            dtb.xoff(toSymbol(sd.xeq), 0);
        else
            dtb.size(0);

        if (sd.xcmp)
            dtb.xoff(toSymbol(sd.xcmp), 0);
        else
            dtb.size(0);

        if (FuncDeclaration fd = search_toString(sd))
        {
            dtb.xoff(toSymbol(fd), 0);
        }
        else
            dtb.size(0);

        // StructFlags m_flags;
        StructFlags m_flags = StructFlags.none;
        if (tc.hasPointers()) m_flags |= StructFlags.hasPointers;
        dtb.size(m_flags);

        version (none)
        {
            // xgetMembers
            if (auto sgetmembers = sd.findGetMembers())
                dtb.xoff(toSymbol(sgetmembers), 0);
            else
                dtb.size(0);                     // xgetMembers
        }

        // xdtor
        if (auto sdtor = sd.tidtor)
            dtb.xoff(toSymbol(sdtor), 0);
        else
            dtb.size(0);                     // xdtor

        // xpostblit
        FuncDeclaration spostblit = sd.postblit;
        if (spostblit && !(spostblit.storage_class & STC.disable))
            dtb.xoff(toSymbol(spostblit), 0);
        else
            dtb.size(0);                     // xpostblit

        // uint m_align;
        dtb.size(tc.alignsize());

        if (target.isX86_64 || target.isAArch64)
        {
            foreach (i; 0 .. 2)
            {
                // m_argi
                if (auto t = sd.argType(i))
                {
                    TypeInfo_toObjFile(null, d.loc, t);
                    dtb.xoff(toSymbol(t.vtinfo), 0);
                }
                else
                    dtb.size(0);
            }
        }

        // xgetRTInfo
        if (sd.getRTInfo)
        {
            Expression_toDt(sd.getRTInfo, *dtb);
        }
        else if (m_flags & StructFlags.hasPointers)
            dtb.size(1);
        else
            dtb.size(0);

        // Put out mangledName[] immediately following TypeInfo_Struct
        dtb.nbytes(mangledName[0 .. mangledNameLen + 1]);
    }

    override void visit(TypeInfoClassDeclaration d)
    {
        //printf("TypeInfoClassDeclaration.toDt() %s\n", tinfo.toChars());
        assert(0);
    }

    override void visit(TypeInfoInterfaceDeclaration d)
    {
        //printf("TypeInfoInterfaceDeclaration.toDt() %s\n", tinfo.toChars());
        verifyStructSize(Type.typeinfointerface, 3 * target.ptrsize);

        dtb.xoff(toVtblSymbol(Type.typeinfointerface), 0);    // vtbl for TypeInfoInterface
        if (Type.typeinfointerface.hasMonitor())
            dtb.size(0);                                  // monitor

        auto tc = d.tinfo.isTypeClass();

        if (!tc.sym.vclassinfo)
            tc.sym.vclassinfo = TypeInfoClassDeclaration.create(tc);
        auto s = toSymbol(tc.sym.vclassinfo);
        dtb.xoff(s, 0);    // ClassInfo for tinfo
    }

    override void visit(TypeInfoTupleDeclaration d)
    {
        //printf("TypeInfoTupleDeclaration.toDt() %s\n", tinfo.toChars());
        verifyStructSize(Type.typeinfotypelist, 4 * target.ptrsize);

        dtb.xoff(toVtblSymbol(Type.typeinfotypelist), 0); // vtbl for TypeInfoInterface
        if (Type.typeinfotypelist.hasMonitor())
            dtb.size(0);                                  // monitor

        auto tu = d.tinfo.isTypeTuple();

        const dim = tu.arguments.length;
        dtb.size(dim);                       // elements.length

        auto dtbargs = DtBuilder(0);
        foreach (arg; *tu.arguments)
        {
            TypeInfo_toObjFile(null, d.loc, arg.type);
            Symbol* s = toSymbol(arg.type.vtinfo);
            dtbargs.xoff(s, 0);
        }

        dtb.dtoff(dtbargs.finish(), 0);                  // elements.ptr
    }
}

void TypeInfo_toDt(ref DtBuilder dtb, TypeInfoDeclaration d)
{
    scope v = new TypeInfoDtVisitor(dtb);
    d.accept(v);
}
