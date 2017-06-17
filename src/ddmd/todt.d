/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _todt.d)
 */

module ddmd.todt;

import core.stdc.stdio;
import core.stdc.string;

import ddmd.root.array;
import ddmd.root.rmem;

import ddmd.aggregate;
import ddmd.arraytypes;
import ddmd.backend.type;
import ddmd.complex;
import ddmd.ctfeexpr;
import ddmd.declaration;
import ddmd.dclass;
import ddmd.denum;
import ddmd.dstruct;
import ddmd.dsymbol;
import ddmd.dtemplate;
import ddmd.errors;
import ddmd.expression;
import ddmd.func;
import ddmd.globals;
import ddmd.init;
import ddmd.mtype;
import ddmd.target;
import ddmd.tokens;
import ddmd.tocsym;
import ddmd.toobj;
import ddmd.typinf;
import ddmd.visitor;

import ddmd.backend.cc;
import ddmd.backend.dt;

alias toSymbol = ddmd.tocsym.toSymbol;
alias toSymbol = ddmd.glue.toSymbol;

/* A dt_t is a simple structure representing data to be added
 * to the data segment of the output object file. As such,
 * it is a list of initialized bytes, 0 data, and offsets from
 * other symbols.
 * Each D symbol and type can be converted into a dt_t so it can
 * be written to the data segment.
 */

alias Dts = Array!(dt_t*);

/* ================================================================ */

extern (C++) void Initializer_toDt(Initializer init, DtBuilder dtb)
{
    extern (C++) class InitToDt : Visitor
    {
        DtBuilder dtb;

        this(DtBuilder dtb)
        {
            this.dtb = dtb;
        }

        alias visit = super.visit;

        override void visit(Initializer)
        {
            assert(0);
        }

        override void visit(VoidInitializer vi)
        {
            /* Void initializers are set to 0, just because we need something
             * to set them to in the static data segment.
             */
            dtb.nzeros(cast(uint)vi.type.size());
        }

        override void visit(StructInitializer si)
        {
            //printf("StructInitializer.toDt('%s')\n", si.toChars());
            assert(0);
        }

        override void visit(ArrayInitializer ai)
        {
            //printf("ArrayInitializer.toDt('%s')\n", ai.toChars());
            Type tb = ai.type.toBasetype();
            if (tb.ty == Tvector)
                tb = (cast(TypeVector)tb).basetype;

            Type tn = tb.nextOf().toBasetype();

            //printf("\tdim = %d\n", ai.dim);
            Dts dts;
            dts.setDim(ai.dim);
            dts.zero();

            uint size = cast(uint)tn.size();

            uint length = 0;
            for (size_t i = 0; i < ai.index.dim; i++)
            {
                Expression idx = ai.index[i];
                if (idx)
                    length = cast(uint)idx.toInteger();
                //printf("\tindex[%d] = %p, length = %u, dim = %u\n", i, idx, length, ai.dim);

                assert(length < ai.dim);
                scope dtb = new DtBuilder();
                Initializer_toDt(ai.value[i], dtb);
                if (dts[length])
                    error(ai.loc, "duplicate initializations for index `%d`", length);
                dts[length] = dtb.finish();
                length++;
            }

            Expression edefault = tb.nextOf().defaultInit();

            size_t n = 1;
            for (Type tbn = tn; tbn.ty == Tsarray; tbn = tbn.nextOf().toBasetype())
            {
                TypeSArray tsa = cast(TypeSArray)tbn;
                n *= tsa.dim.toInteger();
            }

            dt_t* dtdefault = null;

            scope dtbarray = new DtBuilder();
            for (size_t i = 0; i < ai.dim; i++)
            {
                if (dts[i])
                    dtbarray.cat(dts[i]);
                else
                {
                    if (!dtdefault)
                    {
                        scope dtb = new DtBuilder();
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
                        if (edefault.isBool(false))
                        {
                            // pad out end of array
                            dtbarray.nzeros(cast(uint)(size * (tadim - ai.dim)));
                        }
                        else
                        {
                            if (!dtdefault)
                            {
                                scope dtb = new DtBuilder();
                                Expression_toDt(edefault, dtb);
                                dtdefault = dtb.finish();
                            }

                            dtbarray.repeat(dtdefault, n * (tadim - ai.dim));
                        }
                    }
                    else if (ai.dim > tadim)
                    {
                        error(ai.loc, "too many initializers, %d, for array[%d]", ai.dim, tadim);
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
                        for (int i = 0; i < ai.dim; i++)
                            write_pointers(tn, s, size * i);
                    break;
                }

                default:
                    assert(0);
            }
            dt_free(dtdefault);
        }

        override void visit(ExpInitializer ei)
        {
            //printf("ExpInitializer.toDt() %s\n", ei.exp.toChars());
            ei.exp = ei.exp.optimize(WANTvalue);
            Expression_toDt(ei.exp, dtb);
        }
    }

    scope v = new InitToDt(dtb);
    init.accept(v);
}

/* ================================================================ */

extern (C++) void Expression_toDt(Expression e, DtBuilder dtb)
{
    extern (C++) class ExpToDt : Visitor
    {
        DtBuilder dtb;

        this(DtBuilder dtb)
        {
            this.dtb = dtb;
        }

        alias visit = super.visit;

        override void visit(Expression e)
        {
            version (none)
            {
                printf("Expression.toDt() %d\n", e.op);
                print();
            }
            e.error("non-constant expression `%s`", e.toChars());
            dtb.nzeros(1);
        }

        override void visit(CastExp e)
        {
            version (none)
            {
                printf("CastExp.toDt() %d from %s to %s\n", e.op, e.e1.type.toChars(), e.type.toChars());
            }
            if (e.e1.type.ty == Tclass && e.type.ty == Tclass)
            {
                if ((cast(TypeClass)e.type).sym.isInterfaceDeclaration()) // casting from class to interface
                {
                    assert(e.e1.op == TOKclassreference);
                    ClassDeclaration from = (cast(ClassReferenceExp)e.e1).originalClass();
                    InterfaceDeclaration to = (cast(TypeClass)e.type).sym.isInterfaceDeclaration();
                    int off = 0;
                    int isbase = to.isBaseOf(from, &off);
                    assert(isbase);
                    ClassReferenceExp_toDt(cast(ClassReferenceExp)e.e1, dtb, off);
                }
                else //casting from class to class
                {
                    Expression_toDt(e.e1, dtb);
                }
                return;
            }
            visit(cast(UnaExp)e);
        }

        override void visit(AddrExp e)
        {
            version (none)
            {
                printf("AddrExp.toDt() %d\n", e.op);
            }
            if (e.e1.op == TOKstructliteral)
            {
                StructLiteralExp sl = cast(StructLiteralExp)e.e1;
                Symbol* s = toSymbol(sl);
                dtb.xoff(s, 0);
                if (sl.type.isMutable())
                    write_pointers(sl.type, s, 0);
                return;
            }
            visit(cast(UnaExp)e);
        }

        override void visit(IntegerExp e)
        {
            //printf("IntegerExp.toDt() %d\n", e.op);
            uint sz = cast(uint)e.type.size();
            dinteger_t value = e.getInteger();
            if (value == 0)
                dtb.nzeros(sz);
            else
                dtb.nbytes(sz, cast(char*)&value);
        }

        override void visit(RealExp e)
        {
            //printf("RealExp.toDt(%Lg)\n", e.value);
            switch (e.type.toBasetype().ty)
            {
                case Tfloat32:
                case Timaginary32:
                {
                    auto fvalue = cast(float)e.value;
                    dtb.nbytes(4, cast(char*)&fvalue);
                    break;
                }

                case Tfloat64:
                case Timaginary64:
                {
                    auto dvalue = cast(double)e.value;
                    dtb.nbytes(8, cast(char*)&dvalue);
                    break;
                }

                case Tfloat80:
                case Timaginary80:
                {
                    auto evalue = e.value;
                    dtb.nbytes(Target.realsize - Target.realpad, cast(char*)&evalue);
                    dtb.nzeros(Target.realpad);
                    break;
                }

                default:
                    printf("%s\n", e.toChars());
                    e.type.print();
                    assert(0);
            }
        }

        override void visit(ComplexExp e)
        {
            //printf("ComplexExp.toDt() '%s'\n", e.toChars());
            switch (e.type.toBasetype().ty)
            {
                case Tcomplex32:
                {
                    auto fvalue = cast(float)creall(e.value);
                    dtb.nbytes(4, cast(char*)&fvalue);
                    fvalue = cast(float)cimagl(e.value);
                    dtb.nbytes(4, cast(char*)&fvalue);
                    break;
                }

                case Tcomplex64:
                {
                    auto dvalue = cast(double)creall(e.value);
                    dtb.nbytes(8, cast(char*)&dvalue);
                    dvalue = cast(double)cimagl(e.value);
                    dtb.nbytes(8, cast(char*)&dvalue);
                    break;
                }

                case Tcomplex80:
                {
                    auto evalue = creall(e.value);
                    dtb.nbytes(Target.realsize - Target.realpad, cast(char*)&evalue);
                    dtb.nzeros(Target.realpad);
                    evalue = cimagl(e.value);
                    dtb.nbytes(Target.realsize - Target.realpad, cast(char*)&evalue);
                    dtb.nzeros(Target.realpad);
                    break;
                }

                default:
                    assert(0);
            }
        }

        override void visit(NullExp e)
        {
            assert(e.type);
            dtb.nzeros(cast(uint)e.type.size());
        }

        override void visit(StringExp e)
        {
            //printf("StringExp.toDt() '%s', type = %s\n", e.toChars(), e.type.toChars());
            Type t = e.type.toBasetype();

            // BUG: should implement some form of static string pooling
            int n = cast(int)e.numberOfCodeUnits();
            char* p = e.toPtr();
            if (!p)
            {
                p = cast(char*)mem.xmalloc(n * e.sz);
                e.writeTo(p, false);
            }

            switch (t.ty)
            {
                case Tarray:
                    dtb.size(n);
                    goto case Tpointer;

                case Tpointer:
                    if (e.sz == 1)
                    {
                        import ddmd.e2ir : toStringSymbol;
                        import ddmd.glue : totym;
                        Symbol* s = toStringSymbol(p, n, e.sz);
                        dtb.xoff(s, 0);
                    }
                    else
                        dtb.abytes(0, n * e.sz, p, cast(uint)e.sz);
                    break;

                case Tsarray:
                {
                    TypeSArray tsa = cast(TypeSArray)t;

                    dtb.nbytes(n * e.sz, p);
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
            if (p != e.toPtr())
                mem.xfree(p);
        }

        override void visit(ArrayLiteralExp e)
        {
            //printf("ArrayLiteralExp.toDt() '%s', type = %s\n", e.toChars(), e.type.toChars());

            scope dtbarray = new DtBuilder();
            for (size_t i = 0; i < e.elements.dim; i++)
            {
                Expression_toDt(e.getElement(i), dtbarray);
            }

            Type t = e.type.toBasetype();
            switch (t.ty)
            {
                case Tsarray:
                    dtb.cat(dtbarray);
                    break;

                case Tpointer:
                case Tarray:
                {
                    if (t.ty == Tarray)
                        dtb.size(e.elements.dim);
                    dt_t* d = dtbarray.finish();
                    if (d)
                        dtb.dtoff(d, 0);
                    else
                        dtb.size(0);

                    break;
                }

                default:
                    assert(0);
            }
        }

        override void visit(StructLiteralExp sle)
        {
            //printf("StructLiteralExp.toDt() %s, ctfe = %d\n", sle.toChars(), sle.ownedByCtfe);
            assert(sle.sd.fields.dim - sle.sd.isNested() <= sle.elements.dim);
            membersToDt(sle.sd, dtb, sle.elements, 0, null);
        }

        override void visit(SymOffExp e)
        {
            //printf("SymOffExp.toDt('%s')\n", e.var.toChars());
            assert(e.var);
            if (!(e.var.isDataseg() || e.var.isCodeseg()) ||
                e.var.needThis() ||
                e.var.isThreadlocal())
            {
                version (none)
                {
                    printf("SymOffExp.toDt()\n");
                }
                e.error("non-constant expression `%s`", e.toChars());
                return;
            }
            dtb.xoff(toSymbol(e.var), cast(uint)e.offset);
        }

        override void visit(VarExp e)
        {
            //printf("VarExp.toDt() %d\n", e.op);

            VarDeclaration v = e.var.isVarDeclaration();
            if (v && (v.isConst() || v.isImmutable()) &&
                e.type.toBasetype().ty != Tsarray && v._init)
            {
                if (v.inuse)
                {
                    e.error("recursive reference `%s`", e.toChars());
                    return;
                }
                v.inuse++;
                Initializer_toDt(v._init, dtb);
                v.inuse--;
                return;
            }
            SymbolDeclaration sd = e.var.isSymbolDeclaration();
            if (sd && sd.dsym)
            {
                StructDeclaration_toDt(sd.dsym, dtb);
                return;
            }
            version (none)
            {
                printf("VarExp.toDt(), kind = %s\n", e.var.kind());
            }
            e.error("non-constant expression `%s`", e.toChars());
            dtb.nzeros(1);
        }

        override void visit(FuncExp e)
        {
            //printf("FuncExp.toDt() %d\n", e.op);
            if (e.fd.tok == TOKreserved && e.type.ty == Tpointer)
            {
                // change to non-nested
                e.fd.tok = TOKfunction;
                e.fd.vthis = null;
            }
            Symbol *s = toSymbol(e.fd);
            if (e.fd.isNested())
            {
                e.error("non-constant nested delegate literal expression `%s`", e.toChars());
                return;
            }
            toObjFile(e.fd, false);
            dtb.xoff(s, 0);
        }

        override void visit(VectorExp e)
        {
            //printf("VectorExp.toDt() %s\n", e.toChars());
            for (size_t i = 0; i < e.dim; i++)
            {
                Expression elem;
                if (e.e1.op == TOKarrayliteral)
                {
                    ArrayLiteralExp ale = cast(ArrayLiteralExp)e.e1;
                    elem = ale.getElement(i);
                }
                else
                    elem = e.e1;
                Expression_toDt(elem, dtb);
            }
        }

        override void visit(ClassReferenceExp e)
        {
            InterfaceDeclaration to = (cast(TypeClass)e.type).sym.isInterfaceDeclaration();

            if (to) //Static typeof this literal is an interface. We must add offset to symbol
            {
                ClassDeclaration from = e.originalClass();
                int off = 0;
                int isbase = to.isBaseOf(from, &off);
                assert(isbase);
                ClassReferenceExp_toDt(e, dtb, off);
            }
            else
                ClassReferenceExp_toDt(e, dtb, 0);
        }

        override void visit(TypeidExp e)
        {
            if (Type t = isType(e.obj))
            {
                genTypeInfo(t, null);
                Symbol *s = toSymbol(t.vtinfo);
                dtb.xoff(s, 0);
                return;
            }
            assert(0);
        }
    }

    scope v = new ExpToDt(dtb);
    e.accept(v);
}

/* ================================================================= */

// Generate the data for the static initializer.

extern (C++) void ClassDeclaration_toDt(ClassDeclaration cd, DtBuilder dtb)
{
    //printf("ClassDeclaration.toDt(this = '%s')\n", cd.toChars());

    membersToDt(cd, dtb, null, 0, cd);

    //printf("-ClassDeclaration.toDt(this = '%s')\n", cd.toChars());
}

extern (C++) void StructDeclaration_toDt(StructDeclaration sd, DtBuilder dtb)
{
    //printf("+StructDeclaration.toDt(), this='%s'\n", sd.toChars());
    membersToDt(sd, dtb, null, 0, null);

    //printf("-StructDeclaration.toDt(), this='%s'\n", sd.toChars());
}

/******************************
 * Generate data for instance of __cpp_type_info_ptr that refers
 * to the C++ RTTI symbol for cd.
 * Params:
 *      cd = C++ class
 */
extern (C++) void cpp_type_info_ptr_toDt(ClassDeclaration cd, DtBuilder dtb)
{
    //printf("cpp_type_info_ptr_toDt(this = '%s')\n", cd.toChars());
    assert(cd.isCPPclass());

    // Put in first two members, the vtbl[] and the monitor
    dtb.xoff(toVtblSymbol(ClassDeclaration.cpp_type_info_ptr), 0);
    dtb.size(0);             // monitor

    // Create symbol for C++ type info
    Symbol *s = toSymbolCppTypeInfo(cd);

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
 *      pdt = tail of initializer list to start appending initialized data to
 *      elements = values to use as initializers, null means use default initializers
 *      firstFieldIndex = starting place is elements[firstFieldIndex]
 *      concreteType = structs: null, classes: most derived class
 *      ppb = pointer that moves through BaseClass[] from most derived class
 * Returns:
 *      updated tail of dt_t list
 */

private void membersToDt(AggregateDeclaration ad, DtBuilder dtb,
        Expressions* elements, size_t firstFieldIndex,
        ClassDeclaration concreteType,
        BaseClass*** ppb = null)
{
    //printf("membersToDt(ad = '%s', concrete = '%s', ppb = %p)\n", ad.toChars(), concreteType ? concreteType.toChars() : "null", ppb);
    ClassDeclaration cd = ad.isClassDeclaration();
    version (none)
    {
        printf(" interfaces.length = %d\n", cast(int)cd.interfaces.length);
        for (size_t i = 0; i < cd.vtblInterfaces.dim; i++)
        {
            BaseClass* b = (*cd.vtblInterfaces)[i];
            printf("  vbtblInterfaces[%d] b = %p, b.sym = %s\n", cast(int)i, b, b.sym.toChars());
        }
    }

    /* Order:
     *  { base class } or { __vptr, __monitor }
     *  interfaces
     *  fields
     */

    uint offset;
    if (cd)
    {
        if (ClassDeclaration cdb = cd.baseClass)
        {
            size_t index = 0;
            for (ClassDeclaration c = cdb.baseClass; c; c = c.baseClass)
                index += c.fields.dim;
            membersToDt(cdb, dtb, elements, index, concreteType);
            offset = cdb.structsize;
        }
        else if (InterfaceDeclaration id = cd.isInterfaceDeclaration())
        {
            offset = (**ppb).offset;
            if (id.vtblInterfaces.dim == 0)
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
                        offset += Target.ptrsize;
                        break;
                    }
                }
            }
        }
        else
        {
            dtb.xoff(toVtblSymbol(concreteType), 0);  // __vptr
            offset = Target.ptrsize;
            if (!cd.cpp)
            {
                dtb.size(0);              // __monitor
                offset += Target.ptrsize;
            }
        }

        // Interface vptr initializations
        toSymbol(cd);                                         // define csym

        BaseClass** pb;
        if (!ppb)
        {
            pb = cd.vtblInterfaces.data;
            ppb = &pb;
        }

        for (size_t i = 0; i < cd.interfaces.length; ++i)
        {
            BaseClass* b = **ppb;
            if (offset < b.offset)
                dtb.nzeros(b.offset - offset);
            membersToDt(cd.interfaces.ptr[i].sym, dtb, elements, firstFieldIndex, concreteType, ppb);
            //printf("b.offset = %d, b.sym.structsize = %d\n", (int)b.offset, (int)b.sym.structsize);
            offset = b.offset + b.sym.structsize;
        }
    }
    else
        offset = 0;

    assert(!elements ||
           firstFieldIndex <= elements.dim &&
           firstFieldIndex + ad.fields.dim <= elements.dim);

    for (size_t i = 0; i < ad.fields.dim; i++)
    {
        if (elements && !(*elements)[firstFieldIndex + i])
            continue;

        if (!elements || !(*elements)[firstFieldIndex + i])
        {
            if (ad.fields[i]._init && ad.fields[i]._init.isVoidInitializer())
                continue;
        }

        VarDeclaration vd;
        size_t k;
        for (size_t j = i; j < ad.fields.dim; j++)
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

            // find the nearest field
            if (!vd || v2.offset < vd.offset)
            {
                vd = v2;
                k = j;
                assert(vd == v2 || !vd.isOverlappedWith(v2));
            }
        }
        if (!vd)
            continue;

        assert(offset <= vd.offset);
        if (offset < vd.offset)
            dtb.nzeros(vd.offset - offset);

        scope dtbx = new DtBuilder();
        if (elements)
        {
            Expression e = (*elements)[firstFieldIndex + k];
            Type tb = vd.type.toBasetype();
            if (tb.ty == Tsarray)
                toDtElem((cast(TypeSArray)tb), dtbx, e);
            else
                Expression_toDt(e, dtbx);    // convert e to an initializer dt
        }
        else
        {
            if (Initializer init = vd._init)
            {
                //printf("\t\t%s has initializer %s\n", vd.toChars(), init.toChars());
                if (init.isVoidInitializer())
                    continue;

                assert(vd.semanticRun >= PASSsemantic2done);

                ExpInitializer ei = init.isExpInitializer();
                Type tb = vd.type.toBasetype();
                if (ei && tb.ty == Tsarray)
                    toDtElem((cast(TypeSArray)tb), dtbx, ei.exp);
                else
                    Initializer_toDt(init, dtbx);
            }
            else if (offset <= vd.offset)
            {
                //printf("\t\tdefault initializer\n");
                Type_toDt(vd.type, dtbx);
            }
            if (dtbx.isZeroLength())
                continue;
        }

        dtb.cat(dtbx);
        offset = cast(uint)(vd.offset + vd.type.size());
    }

    if (offset < ad.structsize)
        dtb.nzeros(ad.structsize - offset);
}


/* ================================================================= */

extern (C++) void Type_toDt(Type t, DtBuilder dtb)
{
    extern (C++) class TypeToDt : Visitor
    {
    public:
        DtBuilder dtb;

        this(DtBuilder dtb)
        {
            this.dtb = dtb;
        }

        alias visit = super.visit;

        override void visit(Type t)
        {
            //printf("Type.toDt()\n");
            Expression e = t.defaultInit();
            Expression_toDt(e, dtb);
        }

        override void visit(TypeVector t)
        {
            assert(t.basetype.ty == Tsarray);
            toDtElem(cast(TypeSArray)t.basetype, dtb, null);
        }

        override void visit(TypeSArray t)
        {
            toDtElem(t, dtb, null);
        }

        override void visit(TypeStruct t)
        {
            StructDeclaration_toDt(t.sym, dtb);
        }
    }

    scope v = new TypeToDt(dtb);
    t.accept(v);
}

private void toDtElem(TypeSArray tsa, DtBuilder dtb, Expression e)
{
    //printf("TypeSArray.toDtElem() tsa = %s\n", tsa.toChars());
    if (tsa.size(Loc()) == 0)
    {
        dtb.nzeros(0);
    }
    else
    {
        size_t len = cast(size_t)tsa.dim.toInteger();
        assert(len);
        Type tnext = tsa.next;
        Type tbn = tnext.toBasetype();
        while (tbn.ty == Tsarray && (!e || !tbn.equivalent(e.type.nextOf())))
        {
            len *= (cast(TypeSArray)tbn).dim.toInteger();
            tnext = tbn.nextOf();
            tbn = tnext.toBasetype();
        }
        if (!e)                             // if not already supplied
            e = tsa.defaultInit(Loc());    // use default initializer

        if (!e.type.implicitConvTo(tnext))    // https://issues.dlang.org/show_bug.cgi?id=14996
        {
            // https://issues.dlang.org/show_bug.cgi?id=1914
            // https://issues.dlang.org/show_bug.cgi?id=3198
            if (e.op == TOKstring)
                len /= (cast(StringExp)e).numberOfCodeUnits();
            else if (e.op == TOKarrayliteral)
                len /= (cast(ArrayLiteralExp)e).elements.dim;
        }

        scope dtb2 = new DtBuilder();
        Expression_toDt(e, dtb2);
        dt_t* dt2 = dtb2.finish();
        dtb.repeat(dt2, len);
    }
}

/*****************************************************/
/*                   CTFE stuff                      */
/*****************************************************/

private void ClassReferenceExp_toDt(ClassReferenceExp e, DtBuilder dtb, int off)
{
    //printf("ClassReferenceExp.toDt() %d\n", e.op);
    Symbol* s = toSymbol(e);
    dtb.xoff(s, off);
    if (e.type.isMutable())
        write_instance_pointers(e.type, s, 0);
}

extern (C++) void ClassReferenceExp_toInstanceDt(ClassReferenceExp ce, DtBuilder dtb)
{
    //printf("ClassReferenceExp.toInstanceDt() %d\n", ce.op);
    ClassDeclaration cd = ce.originalClass();

    // Put in the rest
    size_t firstFieldIndex = 0;
    for (ClassDeclaration c = cd.baseClass; c; c = c.baseClass)
        firstFieldIndex += c.fields.dim;
    membersToDt(cd, dtb, ce.value.elements, firstFieldIndex, cd);
}

/****************************************************
 */
extern (C++) class TypeInfoDtVisitor : Visitor
{
    DtBuilder dtb;

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
            error(typeclass.loc, "mismatch between compiler and object.d or object.di found. Check installation and import paths with -v compiler switch.");
            fatal();
        }
    }

    this(DtBuilder dtb)
    {
        this.dtb = dtb;
    }

    alias visit = super.visit;

    override void visit(TypeInfoDeclaration d)
    {
        //printf("TypeInfoDeclaration.toDt() %s\n", toChars());
        verifyStructSize(Type.dtypeinfo, 2 * Target.ptrsize);

        dtb.xoff(toVtblSymbol(Type.dtypeinfo), 0);        // vtbl for TypeInfo
        dtb.size(0);                                     // monitor
    }

    override void visit(TypeInfoConstDeclaration d)
    {
        //printf("TypeInfoConstDeclaration.toDt() %s\n", toChars());
        verifyStructSize(Type.typeinfoconst, 3 * Target.ptrsize);

        dtb.xoff(toVtblSymbol(Type.typeinfoconst), 0);    // vtbl for TypeInfo_Const
        dtb.size(0);                                     // monitor
        Type tm = d.tinfo.mutableOf();
        tm = tm.merge();
        genTypeInfo(tm, null);
        dtb.xoff(toSymbol(tm.vtinfo), 0);
    }

    override void visit(TypeInfoInvariantDeclaration d)
    {
        //printf("TypeInfoInvariantDeclaration.toDt() %s\n", toChars());
        verifyStructSize(Type.typeinfoinvariant, 3 * Target.ptrsize);

        dtb.xoff(toVtblSymbol(Type.typeinfoinvariant), 0);    // vtbl for TypeInfo_Invariant
        dtb.size(0);                                         // monitor
        Type tm = d.tinfo.mutableOf();
        tm = tm.merge();
        genTypeInfo(tm, null);
        dtb.xoff(toSymbol(tm.vtinfo), 0);
    }

    override void visit(TypeInfoSharedDeclaration d)
    {
        //printf("TypeInfoSharedDeclaration.toDt() %s\n", toChars());
        verifyStructSize(Type.typeinfoshared, 3 * Target.ptrsize);

        dtb.xoff(toVtblSymbol(Type.typeinfoshared), 0);   // vtbl for TypeInfo_Shared
        dtb.size(0);                                     // monitor
        Type tm = d.tinfo.unSharedOf();
        tm = tm.merge();
        genTypeInfo(tm, null);
        dtb.xoff(toSymbol(tm.vtinfo), 0);
    }

    override void visit(TypeInfoWildDeclaration d)
    {
        //printf("TypeInfoWildDeclaration.toDt() %s\n", toChars());
        verifyStructSize(Type.typeinfowild, 3 * Target.ptrsize);

        dtb.xoff(toVtblSymbol(Type.typeinfowild), 0); // vtbl for TypeInfo_Wild
        dtb.size(0);                                 // monitor
        Type tm = d.tinfo.mutableOf();
        tm = tm.merge();
        genTypeInfo(tm, null);
        dtb.xoff(toSymbol(tm.vtinfo), 0);
    }

    override void visit(TypeInfoEnumDeclaration d)
    {
        //printf("TypeInfoEnumDeclaration.toDt()\n");
        verifyStructSize(Type.typeinfoenum, 7 * Target.ptrsize);

        dtb.xoff(toVtblSymbol(Type.typeinfoenum), 0); // vtbl for TypeInfo_Enum
        dtb.size(0);                        // monitor

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
            genTypeInfo(sd.memtype, null);
            dtb.xoff(toSymbol(sd.memtype.vtinfo), 0);
        }
        else
            dtb.size(0);

        // string name;
        const(char)* name = sd.toPrettyChars();
        size_t namelen = strlen(name);
        dtb.size(namelen);
        dtb.xoff(d.csym, Type.typeinfoenum.structsize);

        // void[] init;
        if (!sd.members || d.tinfo.isZeroInit())
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
        dtb.nbytes(cast(uint)(namelen + 1), name);
    }

    override void visit(TypeInfoPointerDeclaration d)
    {
        //printf("TypeInfoPointerDeclaration.toDt()\n");
        verifyStructSize(Type.typeinfopointer, 3 * Target.ptrsize);

        dtb.xoff(toVtblSymbol(Type.typeinfopointer), 0);  // vtbl for TypeInfo_Pointer
        dtb.size(0);                                     // monitor

        assert(d.tinfo.ty == Tpointer);

        TypePointer tc = cast(TypePointer)d.tinfo;

        genTypeInfo(tc.next, null);
        dtb.xoff(toSymbol(tc.next.vtinfo), 0); // TypeInfo for type being pointed to
    }

    override void visit(TypeInfoArrayDeclaration d)
    {
        //printf("TypeInfoArrayDeclaration.toDt()\n");
        verifyStructSize(Type.typeinfoarray, 3 * Target.ptrsize);

        dtb.xoff(toVtblSymbol(Type.typeinfoarray), 0);    // vtbl for TypeInfo_Array
        dtb.size(0);                                     // monitor

        assert(d.tinfo.ty == Tarray);

        TypeDArray tc = cast(TypeDArray)d.tinfo;

        genTypeInfo(tc.next, null);
        dtb.xoff(toSymbol(tc.next.vtinfo), 0); // TypeInfo for array of type
    }

    override void visit(TypeInfoStaticArrayDeclaration d)
    {
        //printf("TypeInfoStaticArrayDeclaration.toDt()\n");
        verifyStructSize(Type.typeinfostaticarray, 4 * Target.ptrsize);

        dtb.xoff(toVtblSymbol(Type.typeinfostaticarray), 0);  // vtbl for TypeInfo_StaticArray
        dtb.size(0);                                         // monitor

        assert(d.tinfo.ty == Tsarray);

        TypeSArray tc = cast(TypeSArray)d.tinfo;

        genTypeInfo(tc.next, null);
        dtb.xoff(toSymbol(tc.next.vtinfo), 0);   // TypeInfo for array of type

        dtb.size(tc.dim.toInteger());          // length
    }

    override void visit(TypeInfoVectorDeclaration d)
    {
        //printf("TypeInfoVectorDeclaration.toDt()\n");
        verifyStructSize(Type.typeinfovector, 3 * Target.ptrsize);

        dtb.xoff(toVtblSymbol(Type.typeinfovector), 0);   // vtbl for TypeInfo_Vector
        dtb.size(0);                                     // monitor

        assert(d.tinfo.ty == Tvector);

        TypeVector tc = cast(TypeVector)d.tinfo;

        genTypeInfo(tc.basetype, null);
        dtb.xoff(toSymbol(tc.basetype.vtinfo), 0); // TypeInfo for equivalent static array
    }

    override void visit(TypeInfoAssociativeArrayDeclaration d)
    {
        //printf("TypeInfoAssociativeArrayDeclaration.toDt()\n");
        verifyStructSize(Type.typeinfoassociativearray, 4 * Target.ptrsize);

        dtb.xoff(toVtblSymbol(Type.typeinfoassociativearray), 0); // vtbl for TypeInfo_AssociativeArray
        dtb.size(0);                        // monitor

        assert(d.tinfo.ty == Taarray);

        TypeAArray tc = cast(TypeAArray)d.tinfo;

        genTypeInfo(tc.next, null);
        dtb.xoff(toSymbol(tc.next.vtinfo), 0);   // TypeInfo for array of type

        genTypeInfo(tc.index, null);
        dtb.xoff(toSymbol(tc.index.vtinfo), 0);  // TypeInfo for array of type
    }

    override void visit(TypeInfoFunctionDeclaration d)
    {
        //printf("TypeInfoFunctionDeclaration.toDt()\n");
        verifyStructSize(Type.typeinfofunction, 5 * Target.ptrsize);

        dtb.xoff(toVtblSymbol(Type.typeinfofunction), 0); // vtbl for TypeInfo_Function
        dtb.size(0);                                     // monitor

        assert(d.tinfo.ty == Tfunction);

        TypeFunction tc = cast(TypeFunction)d.tinfo;

        genTypeInfo(tc.next, null);
        dtb.xoff(toSymbol(tc.next.vtinfo), 0); // TypeInfo for function return value

        const(char)* name = d.tinfo.deco;
        assert(name);
        size_t namelen = strlen(name);
        dtb.size(namelen);
        dtb.xoff(d.csym, Type.typeinfofunction.structsize);

        // Put out name[] immediately following TypeInfo_Function
        dtb.nbytes(cast(uint)(namelen + 1), name);
    }

    override void visit(TypeInfoDelegateDeclaration d)
    {
        //printf("TypeInfoDelegateDeclaration.toDt()\n");
        verifyStructSize(Type.typeinfodelegate, 5 * Target.ptrsize);

        dtb.xoff(toVtblSymbol(Type.typeinfodelegate), 0); // vtbl for TypeInfo_Delegate
        dtb.size(0);                                     // monitor

        assert(d.tinfo.ty == Tdelegate);

        TypeDelegate tc = cast(TypeDelegate)d.tinfo;

        genTypeInfo(tc.next.nextOf(), null);
        dtb.xoff(toSymbol(tc.next.nextOf().vtinfo), 0); // TypeInfo for delegate return value

        const(char)* name = d.tinfo.deco;
        assert(name);
        size_t namelen = strlen(name);
        dtb.size(namelen);
        dtb.xoff(d.csym, Type.typeinfodelegate.structsize);

        // Put out name[] immediately following TypeInfo_Delegate
        dtb.nbytes(cast(uint)(namelen + 1), name);
    }

    override void visit(TypeInfoStructDeclaration d)
    {
        //printf("TypeInfoStructDeclaration.toDt() '%s'\n", d.toChars());
        if (global.params.is64bit)
            verifyStructSize(Type.typeinfostruct, 17 * Target.ptrsize);
        else
            verifyStructSize(Type.typeinfostruct, 15 * Target.ptrsize);

        dtb.xoff(toVtblSymbol(Type.typeinfostruct), 0); // vtbl for TypeInfo_Struct
        dtb.size(0);                        // monitor

        assert(d.tinfo.ty == Tstruct);

        TypeStruct tc = cast(TypeStruct)d.tinfo;
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
         *  char[] name;
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

        const(char)* name = sd.toPrettyChars();
        size_t namelen = strlen(name);
        dtb.size(namelen);
        dtb.xoff(d.csym, Type.typeinfostruct.structsize);

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
            /* I'm a little unsure this is the right way to do it. Perhaps a better
             * way would to automatically add these attributes to any struct member
             * function with the name "toHash".
             * So I'm leaving this here as an experiment for the moment.
             */
            if (!tf.isnothrow || tf.trust == TRUSTsystem /*|| tf.purity == PUREimpure*/)
                warning(fd.loc, "toHash() must be declared as extern (D) size_t toHash() const nothrow @safe, not %s", tf.toChars());
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
        StructFlags.Type m_flags = 0;
        if (tc.hasPointers()) m_flags |= StructFlags.hasPointers;
        dtb.size(m_flags);

        version (none)
        {
            // xgetMembers
            FuncDeclaration sgetmembers = sd.findGetMembers();
            if (sgetmembers)
                dtb.xoff(toSymbol(sgetmembers), 0);
            else
                dtb.size(0);                     // xgetMembers
        }

        // xdtor
        FuncDeclaration sdtor = sd.dtor;
        if (sdtor)
            dtb.xoff(toSymbol(sdtor), 0);
        else
            dtb.size(0);                     // xdtor

        // xpostblit
        FuncDeclaration spostblit = sd.postblit;
        if (spostblit && !(spostblit.storage_class & STCdisable))
            dtb.xoff(toSymbol(spostblit), 0);
        else
            dtb.size(0);                     // xpostblit

        // uint m_align;
        dtb.size(tc.alignsize());

        if (global.params.is64bit)
        {
            Type t = sd.arg1type;
            for (int i = 0; i < 2; i++)
            {
                // m_argi
                if (t)
                {
                    genTypeInfo(t, null);
                    dtb.xoff(toSymbol(t.vtinfo), 0);
                }
                else
                    dtb.size(0);

                t = sd.arg2type;
            }
        }

        // xgetRTInfo
        if (sd.getRTInfo)
        {
            Expression_toDt(sd.getRTInfo, dtb);
        }
        else if (m_flags & StructFlags.hasPointers)
            dtb.size(1);
        else
            dtb.size(0);

        // Put out name[] immediately following TypeInfo_Struct
        dtb.nbytes(cast(uint)(namelen + 1), name);
    }

    override void visit(TypeInfoClassDeclaration d)
    {
        //printf("TypeInfoClassDeclaration.toDt() %s\n", tinfo.toChars());
        assert(0);
    }

    override void visit(TypeInfoInterfaceDeclaration d)
    {
        //printf("TypeInfoInterfaceDeclaration.toDt() %s\n", tinfo.toChars());
        verifyStructSize(Type.typeinfointerface, 3 * Target.ptrsize);

        dtb.xoff(toVtblSymbol(Type.typeinfointerface), 0);    // vtbl for TypeInfoInterface
        dtb.size(0);                                           // monitor

        assert(d.tinfo.ty == Tclass);

        TypeClass tc = cast(TypeClass)d.tinfo;
        Symbol *s;

        if (!tc.sym.vclassinfo)
            tc.sym.vclassinfo = TypeInfoClassDeclaration.create(tc);
        s = toSymbol(tc.sym.vclassinfo);
        dtb.xoff(s, 0);    // ClassInfo for tinfo
    }

    override void visit(TypeInfoTupleDeclaration d)
    {
        //printf("TypeInfoTupleDeclaration.toDt() %s\n", tinfo.toChars());
        verifyStructSize(Type.typeinfotypelist, 4 * Target.ptrsize);

        dtb.xoff(toVtblSymbol(Type.typeinfotypelist), 0); // vtbl for TypeInfoInterface
        dtb.size(0);                                       // monitor

        assert(d.tinfo.ty == Ttuple);

        TypeTuple tu = cast(TypeTuple)d.tinfo;

        size_t dim = tu.arguments.dim;
        dtb.size(dim);                       // elements.length

        scope dtbargs = new DtBuilder();
        for (size_t i = 0; i < dim; i++)
        {
            Parameter arg = (*tu.arguments)[i];

            genTypeInfo(arg.type, null);
            Symbol* s = toSymbol(arg.type.vtinfo);
            dtbargs.xoff(s, 0);
        }

        dtb.dtoff(dtbargs.finish(), 0);                  // elements.ptr
    }
}

extern (C++) void TypeInfo_toDt(DtBuilder dtb, TypeInfoDeclaration d)
{
    scope v = new TypeInfoDtVisitor(dtb);
    d.accept(v);
}
