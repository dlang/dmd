/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _traits.d)
 */

module ddmd.traits;

import core.stdc.stdio;
import core.stdc.string;
import ddmd.aggregate;
import ddmd.arraytypes;
import ddmd.canthrow;
import ddmd.dclass;
import ddmd.declaration;
import ddmd.dscope;
import ddmd.dsymbol;
import ddmd.dtemplate;
import ddmd.errors;
import ddmd.expression;
import ddmd.expressionsem;
import ddmd.func;
import ddmd.globals;
import ddmd.hdrgen;
import ddmd.id;
import ddmd.identifier;
import ddmd.mtype;
import ddmd.nogc;
import ddmd.root.array;
import ddmd.root.speller;
import ddmd.root.stringtable;
import ddmd.tokens;
import ddmd.typesem;
import ddmd.visitor;

enum LOGSEMANTIC = false;

/************************ TraitsExp ************************************/

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

extern (C++) __gshared StringTable traitsStringTable;

static this()
{
    static immutable string[] names =
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
        "getLinkage",
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
        "getFunctionVariadicStyle",
        "getParameterStorageClasses",
        "getUnitTests",
        "getVirtualIndex",
        "getPointerBitmap",
    ];

    traitsStringTable._init(40);

    foreach (s; names)
    {
        auto sv = traitsStringTable.insert(s.ptr, s.length, cast(void*)s.ptr);
        assert(sv);
    }
}

/**
 * get an array of size_t values that indicate possible pointer words in memory
 *  if interpreted as the type given as argument
 * Returns: the size of the type in bytes, d_uns64.max on error
 */
extern (C++) d_uns64 getTypePointerBitmap(Loc loc, Type t, Array!(d_uns64)* data)
{
    d_uns64 sz;
    if (t.ty == Tclass && !(cast(TypeClass)t).sym.isInterfaceDeclaration())
        sz = (cast(TypeClass)t).sym.AggregateDeclaration.size(loc);
    else
        sz = t.size(loc);
    if (sz == SIZE_INVALID)
        return d_uns64.max;

    const sz_size_t = Type.tsize_t.size(loc);
    if (sz > sz.max - sz_size_t)
    {
        error(loc, "size overflow for type `%s`", t.toChars());
        return d_uns64.max;
    }

    d_uns64 bitsPerWord = sz_size_t * 8;
    d_uns64 cntptr = (sz + sz_size_t - 1) / sz_size_t;
    d_uns64 cntdata = (cntptr + bitsPerWord - 1) / bitsPerWord;

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
            if (nextsize == SIZE_INVALID)
                error = true;
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
            // always a null pointer
        }

        override void visit(TypeStruct t)
        {
            d_uns64 structoff = offset;
            foreach (v; t.sym.fields)
            {
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
            foreach (v; t.sym.fields)
            {
                offset = classoff + v.offset;
                v.type.accept(this);
            }
            offset = classoff;
        }

        Array!(d_uns64)* data;
        d_uns64 offset;
        d_uns64 sz_size_t;
        bool error;
    }

    scope PointerBitmapVisitor pbv = new PointerBitmapVisitor(data, sz_size_t);
    if (t.ty == Tclass)
        pbv.visitClass(cast(TypeClass)t);
    else
        t.accept(pbv);
    return pbv.error ? d_uns64.max : sz;
}

/**
 * get an array of size_t values that indicate possible pointer words in memory
 *  if interpreted as the type given as argument
 * the first array element is the size of the type for independent interpretation
 *  of the array
 * following elements bits represent one word (4/8 bytes depending on the target
 *  architecture). If set the corresponding memory might contain a pointer/reference.
 *
 *  Returns: [T.sizeof, pointerbit0-31/63, pointerbit32/64-63/128, ...]
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
        error(e.loc, "`%s` is not a type", (*e.args)[0].toChars());
        return new ErrorExp();
    }

    Array!(d_uns64) data;
    d_uns64 sz = getTypePointerBitmap(e.loc, t, &data);
    if (sz == d_uns64.max)
        return new ErrorExp();

    auto exps = new Expressions();
    exps.push(new IntegerExp(e.loc, sz, Type.tsize_t));
    foreach (d_uns64 i; 0 .. data.dim)
        exps.push(new IntegerExp(e.loc, data[cast(size_t)i], Type.tsize_t));

    auto ale = new ArrayLiteralExp(e.loc, exps);
    ale.type = Type.tsize_t.sarrayOf(data.dim + 1);
    return ale;
}

extern (C++) Expression semanticTraits(TraitsExp e, Scope* sc)
{
    static if (LOGSEMANTIC)
    {
        printf("TraitsExp::semantic() %s\n", e.toChars());
    }

    if (e.ident != Id.compiles &&
        e.ident != Id.isSame &&
        e.ident != Id.identifier &&
        e.ident != Id.getProtection)
    {
        if (!TemplateInstance.semanticTiargs(e.loc, sc, e.args, 1))
            return new ErrorExp();
    }
    size_t dim = e.args ? e.args.dim : 0;

    Expression dimError(int expected)
    {
        e.error("expected %d arguments for `%s` but had %d", expected, e.ident.toChars(), cast(int)dim);
        return new ErrorExp();
    }

    Expression True()
    {
        return new IntegerExp(e.loc, true, Type.tbool);
    }

    Expression False()
    {
        return new IntegerExp(e.loc, false, Type.tbool);
    }

    Expression isX(T)(bool function(T) fp)
    {
        if (!dim)
            return False();
        foreach (o; *e.args)
        {
            static if (is(T == Type))
                auto y = getType(o);

            static if (is(T : Dsymbol))
            {
                auto s = getDsymbol(o);
                if (!s)
                    return False();
            }
            static if (is(T == Dsymbol))
                alias y = s;
            static if (is(T == Declaration))
                auto y = s.isDeclaration();
            static if (is(T == FuncDeclaration))
                auto y = s.isFuncDeclaration();

            if (!y || !fp(y))
                return False();
        }
        return True();
    }

    alias isTypeX = isX!Type;
    alias isDsymX = isX!Dsymbol;
    alias isDeclX = isX!Declaration;
    alias isFuncX = isX!FuncDeclaration;

    if (e.ident == Id.isArithmetic)
    {
        return isTypeX(t => t.isintegral() || t.isfloating());
    }
    if (e.ident == Id.isFloating)
    {
        return isTypeX(t => t.isfloating());
    }
    if (e.ident == Id.isIntegral)
    {
        return isTypeX(t => t.isintegral());
    }
    if (e.ident == Id.isScalar)
    {
        return isTypeX(t => t.isscalar());
    }
    if (e.ident == Id.isUnsigned)
    {
        return isTypeX(t => t.isunsigned());
    }
    if (e.ident == Id.isAssociativeArray)
    {
        return isTypeX(t => t.toBasetype().ty == Taarray);
    }
    if (e.ident == Id.isStaticArray)
    {
        return isTypeX(t => t.toBasetype().ty == Tsarray);
    }
    if (e.ident == Id.isAbstractClass)
    {
        return isTypeX(t => t.toBasetype().ty == Tclass &&
                            (cast(TypeClass)t.toBasetype()).sym.isAbstract());
    }
    if (e.ident == Id.isFinalClass)
    {
        return isTypeX(t => t.toBasetype().ty == Tclass &&
                            ((cast(TypeClass)t.toBasetype()).sym.storage_class & STCfinal) != 0);
    }
    if (e.ident == Id.isTemplate)
    {
        return isDsymX((s)
        {
            if (!s.toAlias().isOverloadable())
                return false;
            return overloadApply(s,
                sm => sm.isTemplateDeclaration() !is null) != 0;
        });
    }
    if (e.ident == Id.isPOD)
    {
        if (dim != 1)
            return dimError(1);

        auto o = (*e.args)[0];
        auto t = isType(o);
        if (!t)
        {
            e.error("type expected as second argument of __traits `%s` instead of `%s`",
                e.ident.toChars(), o.toChars());
            return new ErrorExp();
        }

        Type tb = t.baseElemOf();
        if (auto sd = tb.ty == Tstruct ? (cast(TypeStruct)tb).sym : null)
        {
            return sd.isPOD() ? True() : False();
        }
        return True();
    }
    if (e.ident == Id.isNested)
    {
        if (dim != 1)
            return dimError(1);

        auto o = (*e.args)[0];
        auto s = getDsymbol(o);
        if (!s)
        {
        }
        else if (auto ad = s.isAggregateDeclaration())
        {
            return ad.isNested() ? True() : False();
        }
        else if (auto fd = s.isFuncDeclaration())
        {
            return fd.isNested() ? True() : False();
        }

        e.error("aggregate or function expected instead of `%s`", o.toChars());
        return new ErrorExp();
    }
    if (e.ident == Id.isAbstractFunction)
    {
        return isFuncX(f => f.isAbstract());
    }
    if (e.ident == Id.isVirtualFunction)
    {
        return isFuncX(f => f.isVirtual());
    }
    if (e.ident == Id.isVirtualMethod)
    {
        return isFuncX(f => f.isVirtualMethod());
    }
    if (e.ident == Id.isFinalFunction)
    {
        return isFuncX(f => f.isFinalFunc());
    }
    if (e.ident == Id.isOverrideFunction)
    {
        return isFuncX(f => f.isOverride());
    }
    if (e.ident == Id.isStaticFunction)
    {
        return isFuncX(f => !f.needThis() && !f.isNested());
    }
    if (e.ident == Id.isRef)
    {
        return isDeclX(d => d.isRef());
    }
    if (e.ident == Id.isOut)
    {
        return isDeclX(d => d.isOut());
    }
    if (e.ident == Id.isLazy)
    {
        return isDeclX(d => (d.storage_class & STClazy) != 0);
    }
    if (e.ident == Id.identifier)
    {
        // Get identifier for symbol as a string literal
        /* Specify 0 for bit 0 of the flags argument to semanticTiargs() so that
         * a symbol should not be folded to a constant.
         * Bit 1 means don't convert Parameter to Type if Parameter has an identifier
         */
        if (!TemplateInstance.semanticTiargs(e.loc, sc, e.args, 2))
            return new ErrorExp();
        if (dim != 1)
            return dimError(1);

        auto o = (*e.args)[0];
        Identifier id;
        if (auto po = isParameter(o))
        {
            id = po.ident;
            assert(id);
        }
        else
        {
            Dsymbol s = getDsymbol(o);
            if (!s || !s.ident)
            {
                e.error("argument `%s` has no identifier", o.toChars());
                return new ErrorExp();
            }
            id = s.ident;
        }

        auto se = new StringExp(e.loc, cast(char*)id.toChars());
        return se.semantic(sc);
    }
    if (e.ident == Id.getProtection)
    {
        if (dim != 1)
            return dimError(1);

        Scope* sc2 = sc.push();
        sc2.flags = sc.flags | SCOPEnoaccesscheck;
        bool ok = TemplateInstance.semanticTiargs(e.loc, sc2, e.args, 1);
        sc2.pop();
        if (!ok)
            return new ErrorExp();

        auto o = (*e.args)[0];
        auto s = getDsymbol(o);
        if (!s)
        {
            if (!isError(o))
                e.error("argument `%s` has no protection", o.toChars());
            return new ErrorExp();
        }
        if (s.semanticRun == PASSinit)
            s.semantic(null);

        auto protName = protectionToChars(s.prot().kind); // TODO: How about package(names)
        assert(protName);
        auto se = new StringExp(e.loc, cast(char*)protName);
        return se.semantic(sc);
    }
    if (e.ident == Id.parent)
    {
        if (dim != 1)
            return dimError(1);

        auto o = (*e.args)[0];
        auto s = getDsymbol(o);
        if (s)
        {
            if (auto fd = s.isFuncDeclaration()) // https://issues.dlang.org/show_bug.cgi?id=8943
                s = fd.toAliasFunc();
            if (!s.isImport()) // https://issues.dlang.org/show_bug.cgi?id=8922
                s = s.toParent();
        }
        if (!s || s.isImport())
        {
            e.error("argument `%s` has no parent", o.toChars());
            return new ErrorExp();
        }

        if (auto f = s.isFuncDeclaration())
        {
            if (auto td = getFuncTemplateDecl(f))
            {
                if (td.overroot) // if not start of overloaded list of TemplateDeclaration's
                    td = td.overroot; // then get the start
                Expression ex = new TemplateExp(e.loc, td, f);
                ex = ex.semantic(sc);
                return ex;
            }
            if (auto fld = f.isFuncLiteralDeclaration())
            {
                // Directly translate to VarExp instead of FuncExp
                Expression ex = new VarExp(e.loc, fld, true);
                return ex.semantic(sc);
            }
        }
        return resolve(e.loc, sc, s, false);
    }
    if (e.ident == Id.hasMember ||
        e.ident == Id.getMember ||
        e.ident == Id.getOverloads ||
        e.ident == Id.getVirtualMethods ||
        e.ident == Id.getVirtualFunctions)
    {
        if (dim != 2)
            return dimError(2);

        auto o = (*e.args)[0];
        auto ex = isExpression((*e.args)[1]);
        if (!ex)
        {
            e.error("expression expected as second argument of __traits `%s`", e.ident.toChars());
            return new ErrorExp();
        }
        ex = ex.ctfeInterpret();

        StringExp se = ex.toStringExp();
        if (!se || se.len == 0)
        {
            e.error("string expected as second argument of __traits `%s` instead of `%s`", e.ident.toChars(), ex.toChars());
            return new ErrorExp();
        }
        se = se.toUTF8(sc);

        if (se.sz != 1)
        {
            e.error("string must be chars");
            return new ErrorExp();
        }
        auto id = Identifier.idPool(se.peekSlice());

        /* Prefer dsymbol, because it might need some runtime contexts.
         */
        Dsymbol sym = getDsymbol(o);
        if (sym)
        {
            ex = new DsymbolExp(e.loc, sym);
            ex = new DotIdExp(e.loc, ex, id);
        }
        else if (auto t = isType(o))
            ex = typeDotIdExp(e.loc, t, id);
        else if (auto ex2 = isExpression(o))
            ex = new DotIdExp(e.loc, ex2, id);
        else
        {
            e.error("invalid first argument");
            return new ErrorExp();
        }

        // ignore symbol visibility for these traits, should disable access checks as well
        Scope* scx = sc.push();
        scx.flags |= SCOPEignoresymbolvisibility;
        scope (exit) scx.pop();

        if (e.ident == Id.hasMember)
        {
            if (sym)
            {
                if (auto sm = sym.search(e.loc, id))
                    return True();
            }

            /* Take any errors as meaning it wasn't found
             */
            ex = ex.trySemantic(scx);
            return ex ? True() : False();
        }
        else if (e.ident == Id.getMember)
        {
            if (ex.op == TOKdotid)
                // Prevent semantic() from replacing Symbol with its initializer
                (cast(DotIdExp)ex).wantsym = true;
            ex = ex.semantic(scx);
            return ex;
        }
        else if (e.ident == Id.getVirtualFunctions ||
                 e.ident == Id.getVirtualMethods ||
                 e.ident == Id.getOverloads)
        {
            uint errors = global.errors;
            Expression eorig = ex;
            ex = ex.semantic(scx);
            if (errors < global.errors)
                e.error("`%s` cannot be resolved", eorig.toChars());
            //ex.print();

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

                auto fa = new FuncAliasDeclaration(fd.ident, fd, false);
                fa.protection = fd.protection;

                auto e = ex ? new DotVarExp(Loc(), ex, fa, false)
                            : new DsymbolExp(Loc(), fa, false);

                exps.push(e);
                return 0;
            });

            auto tup = new TupleExp(e.loc, exps);
            return tup.semantic(scx);
        }
        else
            assert(0);
    }
    if (e.ident == Id.classInstanceSize)
    {
        if (dim != 1)
            return dimError(1);

        auto o = (*e.args)[0];
        auto s = getDsymbol(o);
        auto cd = s ? s.isClassDeclaration() : null;
        if (!cd)
        {
            e.error("first argument is not a class");
            return new ErrorExp();
        }
        if (cd.sizeok != SIZEOKdone)
        {
            cd.size(e.loc);
        }
        if (cd.sizeok != SIZEOKdone)
        {
            e.error("%s `%s` is forward referenced", cd.kind(), cd.toChars());
            return new ErrorExp();
        }

        return new IntegerExp(e.loc, cd.structsize, Type.tsize_t);
    }
    if (e.ident == Id.getAliasThis)
    {
        if (dim != 1)
            return dimError(1);

        auto o = (*e.args)[0];
        auto s = getDsymbol(o);
        auto ad = s ? s.isAggregateDeclaration() : null;
        if (!ad)
        {
            e.error("argument is not an aggregate type");
            return new ErrorExp();
        }

        auto exps = new Expressions();
        if (ad.aliasthis)
            exps.push(new StringExp(e.loc, cast(char*)ad.aliasthis.ident.toChars()));
        Expression ex = new TupleExp(e.loc, exps);
        ex = ex.semantic(sc);
        return ex;
    }
    if (e.ident == Id.getAttributes)
    {
        if (dim != 1)
            return dimError(1);

        auto o = (*e.args)[0];
        auto s = getDsymbol(o);
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
        if (auto imp = s.isImport())
        {
            s = imp.mod;
        }

        //printf("getAttributes %s, attrs = %p, scope = %p\n", s.toChars(), s.userAttribDecl, s.scope);
        auto udad = s.userAttribDecl;
        auto exps = udad ? udad.getAttributes() : new Expressions();
        auto tup = new TupleExp(e.loc, exps);
        return tup.semantic(sc);
    }
    if (e.ident == Id.getFunctionAttributes)
    {
        // extract all function attributes as a tuple (const/shared/inout/pure/nothrow/etc) except UDAs.
        if (dim != 1)
            return dimError(1);

        auto o = (*e.args)[0];
        auto s = getDsymbol(o);
        auto t = isType(o);
        TypeFunction tf = null;
        if (s)
        {
            if (auto fd = s.isFuncDeclaration())
                t = fd.type;
            else if (auto vd = s.isVarDeclaration())
                t = vd.type;
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
    if (e.ident == Id.getFunctionVariadicStyle)
    {
        /* Accept a symbol or a type. Returns one of the following:
         *  "none"      not a variadic function
         *  "argptr"    extern(D) void dstyle(...), use `__argptr` and `__arguments`
         *  "stdarg"    extern(C) void cstyle(int, ...), use core.stdc.stdarg
         *  "typesafe"  void typesafe(T[] ...)
         */
        // get symbol linkage as a string
        if (dim != 1)
            return dimError(1);

        LINK link;
        int varargs;
        auto o = (*e.args)[0];
        auto t = isType(o);
        TypeFunction tf = null;
        if (t)
        {
            if (t.ty == Tfunction)
                tf = cast(TypeFunction)t;
            else if (t.ty == Tdelegate)
                tf = cast(TypeFunction)t.nextOf();
            else if (t.ty == Tpointer && t.nextOf().ty == Tfunction)
                tf = cast(TypeFunction)t.nextOf();
        }
        if (tf)
        {
            link = tf.linkage;
            varargs = tf.varargs;
        }
        else
        {
            auto s = getDsymbol(o);
            FuncDeclaration fd;
            if (!s || (fd = s.isFuncDeclaration()) is null)
            {
                e.error("argument to `__traits(getFunctionVariadicStyle, %s)` is not a function", o.toChars());
                return new ErrorExp();
            }
            link = fd.linkage;
            fd.getParameters(&varargs);
        }
        string style;
        switch (varargs)
        {
            case 0: style = "none";                       break;
            case 1: style = (link == LINK.d) ? "argptr"
                                             : "stdarg";  break;
            case 2:     style = "typesafe";               break;
            default:
                assert(0);
        }
        auto se = new StringExp(e.loc, cast(char*)style);
        return se.semantic(sc);
    }
    if (e.ident == Id.getParameterStorageClasses)
    {
        /* Accept a function symbol or a type, followed by a parameter index.
         * Returns a tuple of strings of the parameter's storage classes.
         */
        // get symbol linkage as a string
        if (dim != 2)
            return dimError(2);

        auto o1 = (*e.args)[1];
        auto o = (*e.args)[0];
        auto t = isType(o);
        TypeFunction tf = null;
        if (t)
        {
            if (t.ty == Tfunction)
                tf = cast(TypeFunction)t;
            else if (t.ty == Tdelegate)
                tf = cast(TypeFunction)t.nextOf();
            else if (t.ty == Tpointer && t.nextOf().ty == Tfunction)
                tf = cast(TypeFunction)t.nextOf();
        }
        Parameters* fparams;
        if (tf)
        {
            fparams = tf.parameters;
        }
        else
        {
            auto s = getDsymbol(o);
            FuncDeclaration fd;
            if (!s || (fd = s.isFuncDeclaration()) is null)
            {
                e.error("first argument to `__traits(getParameterStorageClasses, %s, %s)` is not a function",
                    o.toChars(), o1.toChars());
                return new ErrorExp();
            }
            fparams = fd.getParameters(null);
        }

        StorageClass stc;

        // Set stc to storage class of the ith parameter
        auto ex = isExpression((*e.args)[1]);
        if (!ex)
        {
            e.error("expression expected as second argument of `__traits(getParameterStorageClasses, %s, %s)`",
                o.toChars(), o1.toChars());
            return new ErrorExp();
        }
        ex = ex.ctfeInterpret();
        auto ii = ex.toUInteger();
        if (ii >= Parameter.dim(fparams))
        {
            e.error("parameter index must be in range 0..%u not %s", cast(uint)Parameter.dim(fparams), ex.toChars());
            return new ErrorExp();
        }

        uint n = cast(uint)ii;
        Parameter p = Parameter.getNth(fparams, n);
        stc = p.storageClass;

        // This mirrors hdrgen.visit(Parameter p)
        if (p.type && p.type.mod & MODshared)
            stc &= ~STCshared;

        auto exps = new Expressions;

        void push(string s)
        {
            exps.push(new StringExp(e.loc, cast(char*)s.ptr, cast(uint)s.length));
        }

        if (stc & STCauto)
            push("auto");
        if (stc & STCreturn)
            push("return");

        if (stc & STCout)
            push("out");
        else if (stc & STCref)
            push("ref");
        else if (stc & STCin)
            push("in");
        else if (stc & STClazy)
            push("lazy");
        else if (stc & STCalias)
            push("alias");

        if (stc & STCconst)
            push("const");
        if (stc & STCimmutable)
            push("immutable");
        if (stc & STCwild)
            push("inout");
        if (stc & STCshared)
            push("shared");
        if (stc & STCscope && !(stc & STCscopeinferred))
            push("scope");

        auto tup = new TupleExp(e.loc, exps);
        return tup.semantic(sc);
    }
    if (e.ident == Id.getLinkage)
    {
        // get symbol linkage as a string
        if (dim != 1)
            return dimError(1);

        LINK link;
        auto o = (*e.args)[0];
        auto t = isType(o);
        TypeFunction tf = null;
        if (t)
        {
            if (t.ty == Tfunction)
                tf = cast(TypeFunction)t;
            else if (t.ty == Tdelegate)
                tf = cast(TypeFunction)t.nextOf();
            else if (t.ty == Tpointer && t.nextOf().ty == Tfunction)
                tf = cast(TypeFunction)t.nextOf();
        }
        if (tf)
            link = tf.linkage;
        else
        {
            auto s = getDsymbol(o);
            Declaration d;
            if (!s || (d = s.isDeclaration()) is null)
            {
                e.error("argument to `__traits(getLinkage, %s)` is not a declaration", o.toChars());
                return new ErrorExp();
            }
            link = d.linkage;
        }
        auto linkage = linkageToChars(link);
        auto se = new StringExp(e.loc, cast(char*)linkage);
        return se.semantic(sc);
    }
    if (e.ident == Id.allMembers ||
        e.ident == Id.derivedMembers)
    {
        if (dim != 1)
            return dimError(1);

        auto o = (*e.args)[0];
        auto s = getDsymbol(o);
        if (!s)
        {
            e.error("argument has no members");
            return new ErrorExp();
        }
        if (auto imp = s.isImport())
        {
            // https://issues.dlang.org/show_bug.cgi?id=9692
            s = imp.mod;
        }

        auto sds = s.isScopeDsymbol();
        if (!sds || sds.isTemplateDeclaration())
        {
            e.error("%s `%s` has no members", s.kind(), s.toChars());
            return new ErrorExp();
        }

        auto idents = new Identifiers();

        int pushIdentsDg(size_t n, Dsymbol sm)
        {
            if (!sm)
                return 1;

            // skip local symbols, such as static foreach loop variables
            if (auto decl = sm.isDeclaration())
            {
                if (decl.storage_class & STClocal)
                {
                    return 0;
                }
            }

            //printf("\t[%i] %s %s\n", i, sm.kind(), sm.toChars());
            if (sm.ident)
            {
                const idx = sm.ident.toChars();
                if (idx[0] == '_' &&
                    idx[1] == '_' &&
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
                if (sm.isTypeInfoDeclaration()) // https://issues.dlang.org/show_bug.cgi?id=15177
                    return 0;
                if (!sds.isModule() && sm.isImport()) // https://issues.dlang.org/show_bug.cgi?id=17057
                    return 0;

                //printf("\t%s\n", sm.ident.toChars());

                /* Skip if already present in idents[]
                 */
                foreach (id; *idents)
                {
                    if (id == sm.ident)
                        return 0;

                    // Avoid using strcmp in the first place due to the performance impact in an O(N^2) loop.
                    debug assert(strcmp(id.toChars(), sm.ident.toChars()) != 0);
                }
                idents.push(sm.ident);
            }
            else if (auto ed = sm.isEnumDeclaration())
            {
                ScopeDsymbol._foreach(null, ed.members, &pushIdentsDg);
            }
            return 0;
        }

        ScopeDsymbol._foreach(sc, sds.members, &pushIdentsDg);
        auto cd = sds.isClassDeclaration();
        if (cd && e.ident == Id.allMembers)
        {
            if (cd.semanticRun < PASSsemanticdone)
                cd.semantic(null); // https://issues.dlang.org/show_bug.cgi?id=13668
                                   // Try to resolve forward reference

            void pushBaseMembersDg(ClassDeclaration cd)
            {
                for (size_t i = 0; i < cd.baseclasses.dim; i++)
                {
                    auto cb = (*cd.baseclasses)[i].sym;
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
        auto exps = cast(Expressions*)idents;
        foreach (i, id; *idents)
        {
            auto se = new StringExp(e.loc, cast(char*)id.toChars());
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
    if (e.ident == Id.compiles)
    {
        /* Determine if all the objects - types, expressions, or symbols -
         * compile without error
         */
        if (!dim)
            return False();

        foreach (o; *e.args)
        {
            uint errors = global.startGagging();
            Scope* sc2 = sc.push();
            sc2.tinst = null;
            sc2.minst = null;
            sc2.flags = (sc.flags & ~(SCOPEctfe | SCOPEcondition)) | SCOPEcompile | SCOPEfullinst;

            bool err = false;

            auto t = isType(o);
            auto ex = t ? t.typeToExpression() : isExpression(o);
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
                    auto tf = cast(TypeFunction)sc2.func.type;
                    canThrow(ex, sc2.func, tf.isnothrow);
                }
                ex = checkGC(sc2, ex);
                if (ex.op == TOKerror)
                    err = true;
            }

            // Carefully detach the scope from the parent and throw it away as
            // we only need it to evaluate the expression
            // https://issues.dlang.org/show_bug.cgi?id=15428
            sc2.freeFieldinit();
            sc2.enclosing = null;
            sc2.pop();

            if (global.endGagging(errors) || err)
            {
                return False();
            }
        }
        return True();
    }
    if (e.ident == Id.isSame)
    {
        /* Determine if two symbols are the same
         */
        if (dim != 2)
            return dimError(2);

        if (!TemplateInstance.semanticTiargs(e.loc, sc, e.args, 0))
            return new ErrorExp();

        auto o1 = (*e.args)[0];
        auto o2 = (*e.args)[1];
        auto s1 = getDsymbol(o1);
        auto s2 = getDsymbol(o2);
        //printf("isSame: %s, %s\n", o1.toChars(), o2.toChars());
        version (none)
        {
            printf("o1: %p\n", o1);
            printf("o2: %p\n", o2);
            if (!s1)
            {
                if (auto ea = isExpression(o1))
                    printf("%s\n", ea.toChars());
                if (auto ta = isType(o1))
                    printf("%s\n", ta.toChars());
                return False();
            }
            else
                printf("%s %s\n", s1.kind(), s1.toChars());
        }
        if (!s1 && !s2)
        {
            auto ea1 = isExpression(o1);
            auto ea2 = isExpression(o2);
            if (ea1 && ea2)
            {
                if (ea1.equals(ea2))
                    return True();
            }
        }
        if (!s1 || !s2)
            return False();
        s1 = s1.toAlias();
        s2 = s2.toAlias();

        if (auto fa1 = s1.isFuncAliasDeclaration())
            s1 = fa1.toAliasFunc();
        if (auto fa2 = s2.isFuncAliasDeclaration())
            s2 = fa2.toAliasFunc();

        return (s1 == s2) ? True() : False();
    }
    if (e.ident == Id.getUnitTests)
    {
        if (dim != 1)
            return dimError(1);

        auto o = (*e.args)[0];
        auto s = getDsymbol(o);
        if (!s)
        {
            e.error("argument `%s` to __traits(getUnitTests) must be a module or aggregate",
                o.toChars());
            return new ErrorExp();
        }
        if (auto imp = s.isImport()) // https://issues.dlang.org/show_bug.cgi?id=10990
            s = imp.mod;

        auto sds = s.isScopeDsymbol();
        if (!sds)
        {
            e.error("argument `%s` to __traits(getUnitTests) must be a module or aggregate, not a %s",
                s.toChars(), s.kind());
            return new ErrorExp();
        }

        auto exps = new Expressions();
        if (global.params.useUnitTests)
        {
            bool[void*] uniqueUnitTests;

            void collectUnitTests(Dsymbols* a)
            {
                if (!a)
                    return;
                foreach (s; *a)
                {
                    if (auto atd = s.isAttribDeclaration())
                    {
                        collectUnitTests(atd.include(null, null));
                        continue;
                    }
                    if (auto ud = s.isUnitTestDeclaration())
                    {
                        if (cast(void*)ud in uniqueUnitTests)
                            continue;

                        auto ad = new FuncAliasDeclaration(ud.ident, ud, false);
                        ad.protection = ud.protection;

                        auto e = new DsymbolExp(Loc(), ad, false);
                        exps.push(e);

                        uniqueUnitTests[cast(void*)ud] = true;
                    }
                }
            }

            collectUnitTests(sds.members);
        }
        auto te = new TupleExp(e.loc, exps);
        return te.semantic(sc);
    }
    if (e.ident == Id.getVirtualIndex)
    {
        if (dim != 1)
            return dimError(1);

        auto o = (*e.args)[0];
        auto s = getDsymbol(o);

        auto fd = s ? s.isFuncDeclaration() : null;
        if (!fd)
        {
            e.error("first argument to __traits(getVirtualIndex) must be a function");
            return new ErrorExp();
        }

        fd = fd.toAliasFunc(); // Necessary to support multiple overloads.
        return new IntegerExp(e.loc, fd.vtblIndex, Type.tptrdiff_t);
    }
    if (e.ident == Id.getPointerBitmap)
    {
        return pointerBitmap(e);
    }
    if (e.ident == Id.newCTFEGaveUp)
    {
        return global.newCTFEGaveUp ? True() : False();
    }

    extern (D) void* trait_search_fp(const(char)* seed, ref int cost)
    {
        //printf("trait_search_fp('%s')\n", seed);
        size_t len = strlen(seed);
        if (!len)
            return null;
        cost = 0;
        StringValue* sv = traitsStringTable.lookup(seed, len);
        return sv ? sv.ptrvalue : null;
    }

    if (auto sub = cast(const(char)*)speller(e.ident.toChars(), &trait_search_fp, idchars))
        e.error("unrecognized trait `%s`, did you mean `%s`?", e.ident.toChars(), sub);
    else
        e.error("unrecognized trait `%s`", e.ident.toChars());
    return new ErrorExp();
}
