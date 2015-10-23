// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.traits;

import core.stdc.string;
import ddmd.aggregate;
import ddmd.arraytypes;
import ddmd.attrib;
import ddmd.canthrow;
import ddmd.dclass;
import ddmd.declaration;
import ddmd.denum;
import ddmd.dimport;
import ddmd.dscope;
import ddmd.dstruct;
import ddmd.dsymbol;
import ddmd.dtemplate;
import ddmd.errors;
import ddmd.expression;
import ddmd.func;
import ddmd.globals;
import ddmd.hdrgen;
import ddmd.id;
import ddmd.identifier;
import ddmd.mtype;
import ddmd.nogc;
import ddmd.root.aav;
import ddmd.root.array;
import ddmd.root.rootobject;
import ddmd.root.speller;
import ddmd.root.stringtable;
import ddmd.tokens;
import ddmd.visitor;

enum LOGSEMANTIC = false;

/**
 * Collects all unit test functions from the given array of symbols.
 *
 * This is a helper function used by the implementation of __traits(getUnitTests).
 *
 * Input:
 *      symbols             array of symbols to collect the functions from
 *      uniqueUnitTests     an associative array (should actually be a set) to
 *                          keep track of already collected functions. We're
 *                          using an AA here to avoid doing a linear search of unitTests
 *
 * Output:
 *      unitTests           array of DsymbolExp's of the collected unit test functions
 *      uniqueUnitTests     updated with symbols from unitTests[ ]
 */
extern (C++) static void collectUnitTests(Dsymbols* symbols, AA* uniqueUnitTests, Expressions* unitTests)
{
    if (!symbols)
        return;
    for (size_t i = 0; i < symbols.dim; i++)
    {
        Dsymbol symbol = (*symbols)[i];
        UnitTestDeclaration unitTest = symbol.isUnitTestDeclaration();
        if (unitTest)
        {
            if (!dmd_aaGetRvalue(uniqueUnitTests, cast(void*)unitTest))
            {
                auto ad = new FuncAliasDeclaration(unitTest.ident, unitTest, 0);
                ad.protection = unitTest.protection;
                Expression e = new DsymbolExp(Loc(), ad);
                unitTests.push(e);
                bool* value = cast(bool*)dmd_aaGet(&uniqueUnitTests, cast(void*)unitTest);
                *value = true;
            }
        }
        else
        {
            AttribDeclaration attrDecl = symbol.isAttribDeclaration();
            if (attrDecl)
            {
                Dsymbols* decl = attrDecl.include(null, null);
                collectUnitTests(decl, uniqueUnitTests, unitTests);
            }
        }
    }
}

/************************ TraitsExp ************************************/

extern (C++) bool isTypeArithmetic(Type t)
{
    return t.isintegral() || t.isfloating();
}

extern (C++) bool isTypeFloating(Type t)
{
    return t.isfloating();
}

extern (C++) bool isTypeIntegral(Type t)
{
    return t.isintegral();
}

extern (C++) bool isTypeScalar(Type t)
{
    return t.isscalar();
}

extern (C++) bool isTypeUnsigned(Type t)
{
    return t.isunsigned();
}

extern (C++) bool isTypeAssociativeArray(Type t)
{
    return t.toBasetype().ty == Taarray;
}

extern (C++) bool isTypeStaticArray(Type t)
{
    return t.toBasetype().ty == Tsarray;
}

extern (C++) bool isTypeAbstractClass(Type t)
{
    return t.toBasetype().ty == Tclass && (cast(TypeClass)t.toBasetype()).sym.isAbstract();
}

extern (C++) bool isTypeFinalClass(Type t)
{
    return t.toBasetype().ty == Tclass && ((cast(TypeClass)t.toBasetype()).sym.storage_class & STCfinal) != 0;
}

extern (C++) Expression isTypeX(TraitsExp e, bool function(Type t) fp)
{
    int result = 0;
    if (!e.args || !e.args.dim)
        goto Lfalse;
    for (size_t i = 0; i < e.args.dim; i++)
    {
        Type t = getType((*e.args)[i]);
        if (!t || !fp(t))
            goto Lfalse;
    }
    result = 1;
Lfalse:
    return new IntegerExp(e.loc, result, Type.tbool);
}

extern (C++) bool isFuncAbstractFunction(FuncDeclaration f)
{
    return f.isAbstract();
}

extern (C++) bool isFuncVirtualFunction(FuncDeclaration f)
{
    return f.isVirtual();
}

extern (C++) bool isFuncVirtualMethod(FuncDeclaration f)
{
    return f.isVirtualMethod();
}

extern (C++) bool isFuncFinalFunction(FuncDeclaration f)
{
    return f.isFinalFunc();
}

extern (C++) bool isFuncStaticFunction(FuncDeclaration f)
{
    return !f.needThis() && !f.isNested();
}

extern (C++) bool isFuncOverrideFunction(FuncDeclaration f)
{
    return f.isOverride();
}

extern (C++) Expression isFuncX(TraitsExp e, bool function(FuncDeclaration f) fp)
{
    int result = 0;
    if (!e.args || !e.args.dim)
        goto Lfalse;
    for (size_t i = 0; i < e.args.dim; i++)
    {
        Dsymbol s = getDsymbol((*e.args)[i]);
        if (!s)
            goto Lfalse;
        FuncDeclaration f = s.isFuncDeclaration();
        if (!f || !fp(f))
            goto Lfalse;
    }
    result = 1;
Lfalse:
    return new IntegerExp(e.loc, result, Type.tbool);
}

extern (C++) bool isDeclRef(Declaration d)
{
    return d.isRef();
}

extern (C++) bool isDeclOut(Declaration d)
{
    return d.isOut();
}

extern (C++) bool isDeclLazy(Declaration d)
{
    return (d.storage_class & STClazy) != 0;
}

extern (C++) Expression isDeclX(TraitsExp e, bool function(Declaration d) fp)
{
    int result = 0;
    if (!e.args || !e.args.dim)
        goto Lfalse;
    for (size_t i = 0; i < e.args.dim; i++)
    {
        Dsymbol s = getDsymbol((*e.args)[i]);
        if (!s)
            goto Lfalse;
        Declaration d = s.isDeclaration();
        if (!d || !fp(d))
            goto Lfalse;
    }
    result = 1;
Lfalse:
    return new IntegerExp(e.loc, result, Type.tbool);
}

// callback for TypeFunction::attributesApply
struct PushAttributes
{
    Expressions* mods;

    extern (C++) static int fp(void* param, const(char)* str)
    {
        PushAttributes* p = cast(PushAttributes*)param;
        p.mods.push(new StringExp(Loc(), cast(char*)str));
        return 0;
    }
}

extern (C++) __gshared const(char)** traits =
[
    "isAbstractClass",
    "isArithmetic",
    "isAssociativeArray",
    "isFinalClass",
    "isPOD",
    "isNested",
    "isFloating",
    "isIntegral",
    "isScalar",
    "isStaticArray",
    "isUnsigned",
    "isVirtualFunction",
    "isVirtualMethod",
    "isAbstractFunction",
    "isFinalFunction",
    "isOverrideFunction",
    "isStaticFunction",
    "isRef",
    "isOut",
    "isLazy",
    "hasMember",
    "identifier",
    "getProtection",
    "parent",
    "getMember",
    "getOverloads",
    "getVirtualFunctions",
    "getVirtualMethods",
    "classInstanceSize",
    "allMembers",
    "derivedMembers",
    "isSame",
    "compiles",
    "parameters",
    "getAliasThis",
    "getAttributes",
    "getFunctionAttributes",
    "getUnitTests",
    "getVirtualIndex",
    "getPointerBitmap",
    null
];
extern (C++) __gshared StringTable traitsStringTable;

extern (C++) void initTraitsStringTable()
{
    traitsStringTable._init(40);
    for (size_t idx = 0;; idx++)
    {
        const(char)* s = traits[idx];
        if (!s)
            break;
        StringValue* sv = traitsStringTable.insert(s, strlen(s));
        sv.ptrvalue = cast(void*)traits[idx];
    }
}

extern (C++) bool isTemplate(Dsymbol s)
{
    if (!s.toAlias().isOverloadable())
        return false;
    return overloadApply(s, sm => sm.isTemplateDeclaration() !is null) != 0;
}

extern (C++) Expression isSymbolX(TraitsExp e, bool function(Dsymbol s) fp)
{
    int result = 0;
    if (!e.args || !e.args.dim)
        goto Lfalse;
    for (size_t i = 0; i < e.args.dim; i++)
    {
        Dsymbol s = getDsymbol((*e.args)[i]);
        if (!s || !fp(s))
            goto Lfalse;
    }
    result = 1;
Lfalse:
    return new IntegerExp(e.loc, result, Type.tbool);
}

/**
 * get an array of size_t values that indicate possible pointer words in memory
 *  if interpreted as the type given as argument
 * the first array element is the size of the type for independent interpretation
 *  of the array
 * following elements bits represent one word (4/8 bytes depending on the target
 *  architecture). If set the corresponding memory might contain a pointer/reference.
 *
 *  [T.sizeof, pointerbit0-31/63, pointerbit32/64-63/128, ...]
 */
extern (C++) Expression pointerBitmap(TraitsExp e)
{
    if (!e.args || e.args.dim != 1)
    {
        error(e.loc, "a single type expected for trait pointerBitmap");
        return new ErrorExp();
    }
    Type t = getType((*e.args)[0]);
    if (!t)
    {
        error(e.loc, "%s is not a type", (*e.args)[0].toChars());
        return new ErrorExp();
    }
    d_uns64 sz = t.size(e.loc);
    if (t.ty == Tclass && !(cast(TypeClass)t).sym.isInterfaceDeclaration())
        sz = (cast(TypeClass)t).sym.AggregateDeclaration.size(e.loc);
    d_uns64 sz_size_t = Type.tsize_t.size(e.loc);
    d_uns64 bitsPerWord = sz_size_t * 8;
    d_uns64 cntptr = (sz + sz_size_t - 1) / sz_size_t;
    d_uns64 cntdata = (cntptr + bitsPerWord - 1) / bitsPerWord;
    Array!(d_uns64) data;
    data.setDim(cast(size_t)cntdata);
    data.zero();

    extern (C++) final class PointerBitmapVisitor : Visitor
    {
        alias visit = super.visit;
    public:
        extern (D) this(Array!(d_uns64)* _data, d_uns64 _sz_size_t)
        {
            this.data = _data;
            this.sz_size_t = _sz_size_t;
        }

        void setpointer(d_uns64 off)
        {
            d_uns64 ptroff = off / sz_size_t;
            (*data)[cast(size_t)(ptroff / (8 * sz_size_t))] |= 1L << (ptroff % (8 * sz_size_t));
        }

        override void visit(Type t)
        {
            Type tb = t.toBasetype();
            if (tb != t)
                tb.accept(this);
        }

        override void visit(TypeError t)
        {
            visit(cast(Type)t);
        }

        override void visit(TypeNext t)
        {
            assert(0);
        }

        override void visit(TypeBasic t)
        {
            if (t.ty == Tvoid)
                setpointer(offset);
        }

        override void visit(TypeVector t)
        {
        }

        override void visit(TypeArray t)
        {
            assert(0);
        }

        override void visit(TypeSArray t)
        {
            d_uns64 arrayoff = offset;
            d_uns64 nextsize = t.next.size();
            d_uns64 dim = t.dim.toInteger();
            for (d_uns64 i = 0; i < dim; i++)
            {
                offset = arrayoff + i * nextsize;
                t.next.accept(this);
            }
            offset = arrayoff;
        }

        override void visit(TypeDArray t)
        {
            setpointer(offset + sz_size_t);
        }

        // dynamic array is {length,ptr}
        override void visit(TypeAArray t)
        {
            setpointer(offset);
        }

        override void visit(TypePointer t)
        {
            if (t.nextOf().ty != Tfunction) // don't mark function pointers
                setpointer(offset);
        }

        override void visit(TypeReference t)
        {
            setpointer(offset);
        }

        override void visit(TypeClass t)
        {
            setpointer(offset);
        }

        override void visit(TypeFunction t)
        {
        }

        override void visit(TypeDelegate t)
        {
            setpointer(offset);
        }

        // delegate is {context, function}
        override void visit(TypeQualified t)
        {
            assert(0);
        }

        // assume resolved
        override void visit(TypeIdentifier t)
        {
            assert(0);
        }

        override void visit(TypeInstance t)
        {
            assert(0);
        }

        override void visit(TypeTypeof t)
        {
            assert(0);
        }

        override void visit(TypeReturn t)
        {
            assert(0);
        }

        override void visit(TypeEnum t)
        {
            visit(cast(Type)t);
        }

        override void visit(TypeTuple t)
        {
            visit(cast(Type)t);
        }

        override void visit(TypeSlice t)
        {
            assert(0);
        }

        override void visit(TypeNull t)
        {
            assert(0);
        }

        override void visit(TypeStruct t)
        {
            d_uns64 structoff = offset;
            for (size_t i = 0; i < t.sym.fields.dim; i++)
            {
                VarDeclaration v = t.sym.fields[i];
                offset = structoff + v.offset;
                if (v.type.ty == Tclass)
                    setpointer(offset);
                else
                    v.type.accept(this);
            }
            offset = structoff;
        }

        // a "toplevel" class is treated as an instance, while TypeClass fields are treated as references
        void visitClass(TypeClass t)
        {
            d_uns64 classoff = offset;
            // skip vtable-ptr and monitor
            if (t.sym.baseClass)
                visitClass(cast(TypeClass)t.sym.baseClass.type);
            for (size_t i = 0; i < t.sym.fields.dim; i++)
            {
                VarDeclaration v = t.sym.fields[i];
                offset = classoff + v.offset;
                v.type.accept(this);
            }
            offset = classoff;
        }

        Array!(d_uns64)* data;
        d_uns64 offset;
        d_uns64 sz_size_t;
    }

    scope PointerBitmapVisitor pbv = new PointerBitmapVisitor(&data, sz_size_t);
    if (t.ty == Tclass)
        pbv.visitClass(cast(TypeClass)t);
    else
        t.accept(pbv);
    auto exps = new Expressions();
    exps.push(new IntegerExp(e.loc, sz, Type.tsize_t));
    for (d_uns64 i = 0; i < cntdata; i++)
        exps.push(new IntegerExp(e.loc, data[cast(size_t)i], Type.tsize_t));
    auto ale = new ArrayLiteralExp(e.loc, exps);
    ale.type = Type.tsize_t.sarrayOf(cntdata + 1);
    return ale;
}

extern (C++) Expression semanticTraits(TraitsExp e, Scope* sc)
{
    static if (LOGSEMANTIC)
    {
        printf("TraitsExp::semantic() %s\n", e.toChars());
    }
    if (e.ident != Id.compiles && e.ident != Id.isSame && e.ident != Id.identifier && e.ident != Id.getProtection)
    {
        if (!TemplateInstance.semanticTiargs(e.loc, sc, e.args, 1))
            return new ErrorExp();
    }
    size_t dim = e.args ? e.args.dim : 0;
    if (e.ident == Id.isArithmetic)
    {
        return isTypeX(e, &isTypeArithmetic);
    }
    else if (e.ident == Id.isFloating)
    {
        return isTypeX(e, &isTypeFloating);
    }
    else if (e.ident == Id.isIntegral)
    {
        return isTypeX(e, &isTypeIntegral);
    }
    else if (e.ident == Id.isScalar)
    {
        return isTypeX(e, &isTypeScalar);
    }
    else if (e.ident == Id.isUnsigned)
    {
        return isTypeX(e, &isTypeUnsigned);
    }
    else if (e.ident == Id.isAssociativeArray)
    {
        return isTypeX(e, &isTypeAssociativeArray);
    }
    else if (e.ident == Id.isStaticArray)
    {
        return isTypeX(e, &isTypeStaticArray);
    }
    else if (e.ident == Id.isAbstractClass)
    {
        return isTypeX(e, &isTypeAbstractClass);
    }
    else if (e.ident == Id.isFinalClass)
    {
        return isTypeX(e, &isTypeFinalClass);
    }
    else if (e.ident == Id.isTemplate)
    {
        return isSymbolX(e, &isTemplate);
    }
    else if (e.ident == Id.isPOD)
    {
        if (dim != 1)
            goto Ldimerror;
        RootObject o = (*e.args)[0];
        Type t = isType(o);
        StructDeclaration sd;
        if (!t)
        {
            e.error("type expected as second argument of __traits %s instead of %s", e.ident.toChars(), o.toChars());
            return new ErrorExp();
        }
        Type tb = t.baseElemOf();
        if (tb.ty == Tstruct && ((sd = cast(StructDeclaration)(cast(TypeStruct)tb).sym) !is null))
        {
            if (sd.isPOD())
                goto Ltrue;
            else
                goto Lfalse;
        }
        goto Ltrue;
    }
    else if (e.ident == Id.isNested)
    {
        if (dim != 1)
            goto Ldimerror;
        RootObject o = (*e.args)[0];
        Dsymbol s = getDsymbol(o);
        AggregateDeclaration a;
        FuncDeclaration f;
        if (!s)
        {
        }
        else if ((a = s.isAggregateDeclaration()) !is null)
        {
            if (a.isNested())
                goto Ltrue;
            else
                goto Lfalse;
        }
        else if ((f = s.isFuncDeclaration()) !is null)
        {
            if (f.isNested())
                goto Ltrue;
            else
                goto Lfalse;
        }
        e.error("aggregate or function expected instead of '%s'", o.toChars());
        return new ErrorExp();
    }
    else if (e.ident == Id.isAbstractFunction)
    {
        return isFuncX(e, &isFuncAbstractFunction);
    }
    else if (e.ident == Id.isVirtualFunction)
    {
        return isFuncX(e, &isFuncVirtualFunction);
    }
    else if (e.ident == Id.isVirtualMethod)
    {
        return isFuncX(e, &isFuncVirtualMethod);
    }
    else if (e.ident == Id.isFinalFunction)
    {
        return isFuncX(e, &isFuncFinalFunction);
    }
    else if (e.ident == Id.isOverrideFunction)
    {
        return isFuncX(e, &isFuncOverrideFunction);
    }
    else if (e.ident == Id.isStaticFunction)
    {
        return isFuncX(e, &isFuncStaticFunction);
    }
    else if (e.ident == Id.isRef)
    {
        return isDeclX(e, &isDeclRef);
    }
    else if (e.ident == Id.isOut)
    {
        return isDeclX(e, &isDeclOut);
    }
    else if (e.ident == Id.isLazy)
    {
        return isDeclX(e, &isDeclLazy);
    }
    else if (e.ident == Id.identifier)
    {
        // Get identifier for symbol as a string literal
        /* Specify 0 for bit 0 of the flags argument to semanticTiargs() so that
         * a symbol should not be folded to a constant.
         * Bit 1 means don't convert Parameter to Type if Parameter has an identifier
         */
        if (!TemplateInstance.semanticTiargs(e.loc, sc, e.args, 2))
            return new ErrorExp();
        if (dim != 1)
            goto Ldimerror;
        RootObject o = (*e.args)[0];
        Parameter po = isParameter(o);
        Identifier id;
        if (po)
        {
            id = po.ident;
            assert(id);
        }
        else
        {
            Dsymbol s = getDsymbol(o);
            if (!s || !s.ident)
            {
                e.error("argument %s has no identifier", o.toChars());
                return new ErrorExp();
            }
            id = s.ident;
        }
        auto se = new StringExp(e.loc, id.toChars());
        return se.semantic(sc);
    }
    else if (e.ident == Id.getProtection)
    {
        if (dim != 1)
            goto Ldimerror;
        Scope* sc2 = sc.push();
        sc2.flags = sc.flags | SCOPEnoaccesscheck;
        bool ok = TemplateInstance.semanticTiargs(e.loc, sc2, e.args, 1);
        sc2.pop();
        if (!ok)
            return new ErrorExp();
        RootObject o = (*e.args)[0];
        Dsymbol s = getDsymbol(o);
        if (!s)
        {
            if (!isError(o))
                e.error("argument %s has no protection", o.toChars());
            return new ErrorExp();
        }
        if (s._scope)
            s.semantic(s._scope);
        const(char)* protName = protectionToChars(s.prot().kind); // TODO: How about package(names)
        assert(protName);
        auto se = new StringExp(e.loc, cast(char*)protName);
        return se.semantic(sc);
    }
    else if (e.ident == Id.parent)
    {
        if (dim != 1)
            goto Ldimerror;
        RootObject o = (*e.args)[0];
        Dsymbol s = getDsymbol(o);
        if (s)
        {
            if (FuncDeclaration fd = s.isFuncDeclaration()) // Bugzilla 8943
                s = fd.toAliasFunc();
            if (!s.isImport()) // Bugzilla 8922
                s = s.toParent();
        }
        if (!s || s.isImport())
        {
            e.error("argument %s has no parent", o.toChars());
            return new ErrorExp();
        }
        if (FuncDeclaration f = s.isFuncDeclaration())
        {
            if (TemplateDeclaration td = getFuncTemplateDecl(f))
            {
                if (td.overroot) // if not start of overloaded list of TemplateDeclaration's
                    td = td.overroot; // then get the start
                Expression ex = new TemplateExp(e.loc, td, f);
                ex = ex.semantic(sc);
                return ex;
            }
            if (FuncLiteralDeclaration fld = f.isFuncLiteralDeclaration())
            {
                // Directly translate to VarExp instead of FuncExp
                Expression ex = new VarExp(e.loc, fld, 1);
                return ex.semantic(sc);
            }
        }
        return DsymbolExp.resolve(e.loc, sc, s, false);
    }
    else if (e.ident == Id.hasMember || e.ident == Id.getMember || e.ident == Id.getOverloads || e.ident == Id.getVirtualMethods || e.ident == Id.getVirtualFunctions)
    {
        if (dim != 2)
            goto Ldimerror;
        RootObject o = (*e.args)[0];
        Expression ex = isExpression((*e.args)[1]);
        if (!ex)
        {
            e.error("expression expected as second argument of __traits %s", e.ident.toChars());
            return new ErrorExp();
        }
        ex = ex.ctfeInterpret();
        StringExp se = ex.toStringExp();
        if (!se || se.len == 0)
        {
            e.error("string expected as second argument of __traits %s instead of %s", e.ident.toChars(), ex.toChars());
            return new ErrorExp();
        }
        se = se.toUTF8(sc);
        if (se.sz != 1)
        {
            e.error("string must be chars");
            return new ErrorExp();
        }
        Identifier id = Identifier.idPool(cast(char*)se.string);
        /* Prefer dsymbol, because it might need some runtime contexts.
         */
        Dsymbol sym = getDsymbol(o);
        if (sym)
        {
            ex = new DsymbolExp(e.loc, sym);
            ex = new DotIdExp(e.loc, ex, id);
        }
        else if (Type t = isType(o))
            ex = typeDotIdExp(e.loc, t, id);
        else if (Expression ex2 = isExpression(o))
            ex = new DotIdExp(e.loc, ex2, id);
        else
        {
            e.error("invalid first argument");
            return new ErrorExp();
        }
        if (e.ident == Id.hasMember)
        {
            if (sym)
            {
                Dsymbol sm = sym.search(e.loc, id);
                if (sm)
                    goto Ltrue;
            }
            /* Take any errors as meaning it wasn't found
             */
            Scope* sc2 = sc.push();
            ex = ex.trySemantic(sc2);
            sc2.pop();
            if (!ex)
                goto Lfalse;
            else
                goto Ltrue;
        }
        else if (e.ident == Id.getMember)
        {
            ex = ex.semantic(sc);
            return ex;
        }
        else if (e.ident == Id.getVirtualFunctions ||
                 e.ident == Id.getVirtualMethods ||
                 e.ident == Id.getOverloads)
        {
            uint errors = global.errors;
            Expression eorig = ex;
            ex = ex.semantic(sc);
            if (errors < global.errors)
                e.error("%s cannot be resolved", eorig.toChars());
            //ex->print();

            /* Create tuple of functions of ex
             */
            auto exps = new Expressions();
            FuncDeclaration f;
            if (ex.op == TOKvar)
            {
                VarExp ve = cast(VarExp)ex;
                f = ve.var.isFuncDeclaration();
                ex = null;
            }
            else if (ex.op == TOKdotvar)
            {
                DotVarExp dve = cast(DotVarExp)ex;
                f = dve.var.isFuncDeclaration();
                if (dve.e1.op == TOKdottype || dve.e1.op == TOKthis)
                    ex = null;
                else
                    ex = dve.e1;
            }

            overloadApply(f, (Dsymbol s)
            {
                auto fd = s.isFuncDeclaration();
                if (!fd)
                    return 0;
                if (e.ident == Id.getVirtualFunctions && !fd.isVirtual())
                    return 0;
                if (e.ident == Id.getVirtualMethods && !fd.isVirtualMethod())
                    return 0;
                auto fa = new FuncAliasDeclaration(fd.ident, fd, 0);
                fa.protection = fd.protection;
                Expression e = ex ? new DotVarExp(Loc(), ex, fa)
                                  : new DsymbolExp(Loc(), fa);
                exps.push(e);
                return 0;
            });

            auto tup = new TupleExp(e.loc, exps);
            return tup.semantic(sc);
        }
        else
            assert(0);
    }
    else if (e.ident == Id.classInstanceSize)
    {
        if (dim != 1)
            goto Ldimerror;
        RootObject o = (*e.args)[0];
        Dsymbol s = getDsymbol(o);
        ClassDeclaration cd;
        if (!s || (cd = s.isClassDeclaration()) is null)
        {
            e.error("first argument is not a class");
            return new ErrorExp();
        }
        if (cd.sizeok == SIZEOKnone)
        {
            if (cd._scope)
                cd.semantic(cd._scope);
        }
        if (cd.sizeok != SIZEOKdone)
        {
            e.error("%s %s is forward referenced", cd.kind(), cd.toChars());
            return new ErrorExp();
        }
        return new IntegerExp(e.loc, cd.structsize, Type.tsize_t);
    }
    else if (e.ident == Id.getAliasThis)
    {
        if (dim != 1)
            goto Ldimerror;
        RootObject o = (*e.args)[0];
        Dsymbol s = getDsymbol(o);
        AggregateDeclaration ad;
        if (!s || (ad = s.isAggregateDeclaration()) is null)
        {
            e.error("argument is not an aggregate type");
            return new ErrorExp();
        }
        auto exps = new Expressions();
        if (ad.aliasthis)
            exps.push(new StringExp(e.loc, ad.aliasthis.ident.toChars()));
        Expression ex = new TupleExp(e.loc, exps);
        ex = ex.semantic(sc);
        return ex;
    }
    else if (e.ident == Id.getAttributes)
    {
        if (dim != 1)
            goto Ldimerror;
        RootObject o = (*e.args)[0];
        Dsymbol s = getDsymbol(o);
        if (!s)
        {
            version (none)
            {
                Expression x = isExpression(o);
                Type t = isType(o);
                if (x)
                    printf("e = %s %s\n", Token.toChars(x.op), x.toChars());
                if (t)
                    printf("t = %d %s\n", t.ty, t.toChars());
            }
            e.error("first argument is not a symbol");
            return new ErrorExp();
        }
        if (s.isImport())
        {
            s = s.isImport().mod;
        }
        //printf("getAttributes %s, attrs = %p, scope = %p\n", s->toChars(), s->userAttribDecl, s->scope);
        UserAttributeDeclaration udad = s.userAttribDecl;
        auto tup = new TupleExp(e.loc, udad ? udad.getAttributes() : new Expressions());
        return tup.semantic(sc);
    }
    else if (e.ident == Id.getFunctionAttributes)
    {
        /// extract all function attributes as a tuple (const/shared/inout/pure/nothrow/etc) except UDAs.
        if (dim != 1)
            goto Ldimerror;
        RootObject o = (*e.args)[0];
        Dsymbol s = getDsymbol(o);
        Type t = isType(o);
        TypeFunction tf = null;
        if (s)
        {
            if (FuncDeclaration f = s.isFuncDeclaration())
                t = f.type;
            else if (VarDeclaration v = s.isVarDeclaration())
                t = v.type;
        }
        if (t)
        {
            if (t.ty == Tfunction)
                tf = cast(TypeFunction)t;
            else if (t.ty == Tdelegate)
                tf = cast(TypeFunction)t.nextOf();
            else if (t.ty == Tpointer && t.nextOf().ty == Tfunction)
                tf = cast(TypeFunction)t.nextOf();
        }
        if (!tf)
        {
            e.error("first argument is not a function");
            return new ErrorExp();
        }
        auto mods = new Expressions();
        PushAttributes pa;
        pa.mods = mods;
        tf.modifiersApply(&pa, &PushAttributes.fp);
        tf.attributesApply(&pa, &PushAttributes.fp, TRUSTformatSystem);
        auto tup = new TupleExp(e.loc, mods);
        return tup.semantic(sc);
    }
    else if (e.ident == Id.allMembers || e.ident == Id.derivedMembers)
    {
        if (dim != 1)
            goto Ldimerror;
        RootObject o = (*e.args)[0];
        Dsymbol s = getDsymbol(o);
        if (!s)
        {
            e.error("argument has no members");
            return new ErrorExp();
        }
        if (Import imp = s.isImport())
        {
            // Bugzilla 9692
            s = imp.mod;
        }
        ScopeDsymbol sds = s.isScopeDsymbol();
        if (!sds || sds.isTemplateDeclaration())
        {
            e.error("%s %s has no members", s.kind(), s.toChars());
            return new ErrorExp();
        }

        auto idents = new Identifiers();

        int pushIdentsDg(size_t n, Dsymbol sm)
        {
            if (!sm)
                return 1;
            //printf("\t[%i] %s %s\n", i, sm->kind(), sm->toChars());
            if (sm.ident)
            {
                if (sm.ident.string[0] == '_' &&
                    sm.ident.string[1] == '_' &&
                    sm.ident != Id.ctor &&
                    sm.ident != Id.dtor &&
                    sm.ident != Id.__xdtor &&
                    sm.ident != Id.postblit &&
                    sm.ident != Id.__xpostblit)
                {
                    return 0;
                }
                if (sm.ident == Id.empty)
                {
                    return 0;
                }
                if (sm.isTypeInfoDeclaration()) // Bugzilla 15177
                    return 0;

                //printf("\t%s\n", sm->ident->toChars());
                /* Skip if already present in idents[]
                 */
                for (size_t j = 0; j < idents.dim; j++)
                {
                    Identifier id = (*idents)[j];
                    if (id == sm.ident)
                        return 0;

                    // Avoid using strcmp in the first place due to the performance impact in an O(N^2) loop.
                    debug assert(strcmp(id.toChars(), sm.ident.toChars()) != 0);
                }
                idents.push(sm.ident);
            }
            else
            {
                EnumDeclaration ed = sm.isEnumDeclaration();
                if (ed)
                {
                    ScopeDsymbol._foreach(null, ed.members, &pushIdentsDg);
                }
            }
            return 0;
        }

        ScopeDsymbol._foreach(sc, sds.members, &pushIdentsDg);
        ClassDeclaration cd = sds.isClassDeclaration();
        if (cd && e.ident == Id.allMembers)
        {
            if (cd._scope)
                cd.semantic(null); // Bugzilla 13668: Try to resolve forward reference

            void pushBaseMembersDg(ClassDeclaration cd)
            {
                for (size_t i = 0; i < cd.baseclasses.dim; i++)
                {
                    ClassDeclaration cb = (*cd.baseclasses)[i].sym;
                    assert(cb);
                    ScopeDsymbol._foreach(null, cb.members, &pushIdentsDg);
                    if (cb.baseclasses.dim)
                        pushBaseMembersDg(cb);
                }
            }

            pushBaseMembersDg(cd);
        }
        // Turn Identifiers into StringExps reusing the allocated array
        assert(Expressions.sizeof == Identifiers.sizeof);
        Expressions* exps = cast(Expressions*)idents;
        for (size_t i = 0; i < idents.dim; i++)
        {
            Identifier id = (*idents)[i];
            auto se = new StringExp(e.loc, id.toChars());
            (*exps)[i] = se;
        }
        /* Making this a tuple is more flexible, as it can be statically unrolled.
         * To make an array literal, enclose __traits in [ ]:
         *   [ __traits(allMembers, ...) ]
         */
        Expression ex = new TupleExp(e.loc, exps);
        ex = ex.semantic(sc);
        return ex;
    }
    else if (e.ident == Id.compiles)
    {
        /* Determine if all the objects - types, expressions, or symbols -
         * compile without error
         */
        if (!dim)
            goto Lfalse;
        for (size_t i = 0; i < dim; i++)
        {
            uint errors = global.startGagging();
            Scope* sc2 = sc.push();
            sc2.tinst = null;
            sc2.minst = null;
            sc2.flags = (sc.flags & ~(SCOPEctfe | SCOPEcondition)) | SCOPEcompile;
            bool err = false;
            RootObject o = (*e.args)[i];
            Type t = isType(o);
            Expression ex = t ? t.toExpression() : isExpression(o);
            if (!ex && t)
            {
                Dsymbol s;
                t.resolve(e.loc, sc2, &ex, &t, &s);
                if (t)
                {
                    t.semantic(e.loc, sc2);
                    if (t.ty == Terror)
                        err = true;
                }
                else if (s && s.errors)
                    err = true;
            }
            if (ex)
            {
                ex = ex.semantic(sc2);
                ex = resolvePropertiesOnly(sc2, ex);
                ex = ex.optimize(WANTvalue);
                if (sc2.func && sc2.func.type.ty == Tfunction)
                {
                    TypeFunction tf = cast(TypeFunction)sc2.func.type;
                    canThrow(ex, sc2.func, tf.isnothrow);
                }
                ex = checkGC(sc2, ex);
                if (ex.op == TOKerror)
                    err = true;
            }
            sc2.pop();
            if (global.endGagging(errors) || err)
            {
                goto Lfalse;
            }
        }
        goto Ltrue;
    }
    else if (e.ident == Id.isSame)
    {
        /* Determine if two symbols are the same
         */
        if (dim != 2)
            goto Ldimerror;
        if (!TemplateInstance.semanticTiargs(e.loc, sc, e.args, 0))
            return new ErrorExp();
        RootObject o1 = (*e.args)[0];
        RootObject o2 = (*e.args)[1];
        Dsymbol s1 = getDsymbol(o1);
        Dsymbol s2 = getDsymbol(o2);
        //printf("isSame: %s, %s\n", o1->toChars(), o2->toChars());
        version (none)
        {
            printf("o1: %p\n", o1);
            printf("o2: %p\n", o2);
            if (!s1)
            {
                Expression ea = isExpression(o1);
                if (ea)
                    printf("%s\n", ea.toChars());
                Type ta = isType(o1);
                if (ta)
                    printf("%s\n", ta.toChars());
                goto Lfalse;
            }
            else
                printf("%s %s\n", s1.kind(), s1.toChars());
        }
        if (!s1 && !s2)
        {
            Expression ea1 = isExpression(o1);
            Expression ea2 = isExpression(o2);
            if (ea1 && ea2)
            {
                if (ea1.equals(ea2))
                    goto Ltrue;
            }
        }
        if (!s1 || !s2)
            goto Lfalse;
        s1 = s1.toAlias();
        s2 = s2.toAlias();
        if (s1.isFuncAliasDeclaration())
            s1 = (cast(FuncAliasDeclaration)s1).toAliasFunc();
        if (s2.isFuncAliasDeclaration())
            s2 = (cast(FuncAliasDeclaration)s2).toAliasFunc();
        if (s1 == s2)
            goto Ltrue;
        else
            goto Lfalse;
    }
    else if (e.ident == Id.getUnitTests)
    {
        if (dim != 1)
            goto Ldimerror;
        RootObject o = (*e.args)[0];
        Dsymbol s = getDsymbol(o);
        if (!s)
        {
            e.error("argument %s to __traits(getUnitTests) must be a module or aggregate", o.toChars());
            return new ErrorExp();
        }
        Import imp = s.isImport();
        if (imp) // Bugzilla 10990
            s = imp.mod;
        ScopeDsymbol _scope = s.isScopeDsymbol();
        if (!_scope)
        {
            e.error("argument %s to __traits(getUnitTests) must be a module or aggregate, not a %s", s.toChars(), s.kind());
            return new ErrorExp();
        }
        auto unitTests = new Expressions();
        Dsymbols* symbols = _scope.members;
        if (global.params.useUnitTests && symbols)
        {
            // Should actually be a set
            AA* uniqueUnitTests = null;
            collectUnitTests(symbols, uniqueUnitTests, unitTests);
        }
        auto tup = new TupleExp(e.loc, unitTests);
        return tup.semantic(sc);
    }
    else if (e.ident == Id.getVirtualIndex)
    {
        if (dim != 1)
            goto Ldimerror;
        RootObject o = (*e.args)[0];
        Dsymbol s = getDsymbol(o);
        FuncDeclaration fd;
        if (!s || (fd = s.isFuncDeclaration()) is null)
        {
            e.error("first argument to __traits(getVirtualIndex) must be a function");
            return new ErrorExp();
        }
        fd = fd.toAliasFunc(); // Neccessary to support multiple overloads.
        return new IntegerExp(e.loc, fd.vtblIndex, Type.tptrdiff_t);
    }
    else if (e.ident == Id.getPointerBitmap)
    {
        return pointerBitmap(e);
    }
    else
    {
        extern (D) void* trait_search_fp(const(char)* seed, ref int cost)
        {
            //printf("trait_search_fp('%s')\n", seed);
            size_t len = strlen(seed);
            if (!len)
                return null;
            cost = 0;
            StringValue* sv = traitsStringTable.lookup(seed, len);
            return sv ? cast(void*)sv.ptrvalue : null;
        }

        if (auto sub = cast(const(char)*)speller(e.ident.toChars(), &trait_search_fp, idchars))
            e.error("unrecognized trait '%s', did you mean '%s'?", e.ident.toChars(), sub);
        else
            e.error("unrecognized trait '%s'", e.ident.toChars());
        return new ErrorExp();
    }
    assert(0);
Ldimerror:
    e.error("wrong number of arguments %d", cast(int)dim);
    return new ErrorExp();
Lfalse:
    return new IntegerExp(e.loc, 0, Type.tbool);
Ltrue:
    return new IntegerExp(e.loc, 1, Type.tbool);
}
