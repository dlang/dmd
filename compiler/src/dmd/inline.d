/**
 * Performs inlining, which is an optimization pass enabled with the `-inline` flag.
 *
 * The AST is traversed, and every function call is considered for inlining using `inlinecost.d`.
 * The function call is then inlined if this cost is below a threshold.
 *
 * Copyright:   Copyright (C) 1999-2024 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/inline.d, _inline.d)
 * Documentation:  https://dlang.org/phobos/dmd_inline.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/inline.d
 */

module dmd.inline;

import core.stdc.stdio;
import core.stdc.string;

import dmd.aggregate;
import dmd.arraytypes;
import dmd.astenums;
import dmd.declaration;
import dmd.dscope;
import dmd.dstruct;
import dmd.dsymbol;
import dmd.dtemplate;
import dmd.expression;
import dmd.errors;
import dmd.func;
import dmd.id;
import dmd.init;
import dmd.initsem;
import dmd.mtype;
import dmd.statement;
import dmd.tokens;
import dmd.visitor;
import dmd.inlinecost;

/***********************************************************
 * Perform the "inline copying" of a default argument for a function parameter.
 *
 * Todo:
 *  The hack for https://issues.dlang.org/show_bug.cgi?id=4820 case is still questionable.
 *  Perhaps would have to handle a delegate expression with 'null' context properly in front-end.
 */
public Expression inlineCopy(Expression e, Scope* sc)
{
    /* See https://issues.dlang.org/show_bug.cgi?id=2935
     * for explanation of why just a copy() is broken
     */
    //return e.copy();
    if (auto de = e.isDelegateExp())
    {
        if (de.func.isNested())
        {
            /* https://issues.dlang.org/show_bug.cgi?id=4820
             * Defer checking until later if we actually need the 'this' pointer
             */
            return de.copy();
        }
    }
    int cost = inlineCostExpression(e);
    if (cost >= COST_MAX)
    {
        error(e.loc, "cannot inline default argument `%s`", e.toChars());
        return ErrorExp.get();
    }
    scope ids = new InlineDoState(sc.parent, null);
    return doInlineExpression(e, ids);
}


private:

enum LOG = false;


/***********************************************************
 * Represent a context to inline expressions.
 */
private final class InlineDoState
{
    // inline context
    VarDeclaration vthis;
    Dsymbols from;      // old Dsymbols
    Dsymbols to;        // parallel array of new Dsymbols
    Dsymbol parent;     // new parent
    FuncDeclaration fd; // function being inlined (old parent)

    this(Dsymbol parent, FuncDeclaration fd) scope
    {
        this.parent = parent;
        this.fd = fd;
    }
}

/***********************************************************
 * Perform the inlining on Expression.
 *
 * Inlining is done by:
 *  - Converting to an Expression
 *  - Copying the trees of the expression to be inlined
 *  - Renaming the variables
 */
private extern (C++) final class DoInlineExpression : Visitor
{
    alias visit = Visitor.visit;
public:
    InlineDoState ids;
    Expression result;

    extern (D) this(InlineDoState ids) scope
    {
        this.ids = ids;
    }

    /******************************
     * Perform doInlineAs() on an array of Expressions.
     */
    Expressions* arrayExpressionDoInline(Expressions* a)
    {
        if (!a)
            return null;

        auto newa = new Expressions(a.length);

        foreach (i; 0 .. a.length)
        {
            (*newa)[i] = doInlineExpression((*a)[i], ids);
        }
        return newa;
    }

    override void visit(Expression e)
    {
        //printf("Expression.doInlineAs!%s(%s): %s\n", Result.stringof.ptr, EXPtoString(e.op).ptr, e.toChars());
        result = e.copy();
    }

    override void visit(SymOffExp e)
    {
        //printf("SymOffExp.doInlineAs!%s(%s)\n", Result.stringof.ptr, e.toChars());
        foreach (i; 0 .. ids.from.length)
        {
            if (e.var != ids.from[i])
                continue;
            auto se = e.copy().isSymOffExp();
            se.var = ids.to[i].isDeclaration();
            result = se;
            return;
        }
        result = e;
    }

    override void visit(VarExp e)
    {
        //printf("VarExp.doInlineAs!%s(%s)\n", Result.stringof.ptr, e.toChars());
        foreach (i; 0 .. ids.from.length)
        {
            if (e.var != ids.from[i])
                continue;
            auto ve = e.copy().isVarExp();
            ve.var = ids.to[i].isDeclaration();
            result = ve;
            return;
        }
        if (ids.fd && e.var == ids.fd.vthis)
        {
            result = new VarExp(e.loc, ids.vthis);
            if (ids.fd.hasDualContext())
                result = new AddrExp(e.loc, result);
            result.type = e.type;
            return;
        }

        /* Inlining context pointer access for nested referenced variables.
         * For example:
         *      auto fun() {
         *        int i = 40;
         *        auto foo() {
         *          int g = 2;
         *          struct Result {
         *            auto bar() { return i + g; }
         *          }
         *          return Result();
         *        }
         *        return foo();
         *      }
         *      auto t = fun();
         * 'i' and 'g' are nested referenced variables in Result.bar(), so:
         *      auto x = t.bar();
         * should be inlined to:
         *      auto x = *(t.vthis.vthis + i.voffset) + *(t.vthis + g.voffset)
         */
        auto v = e.var.isVarDeclaration();
        if (v && v.nestedrefs.length && ids.vthis)
        {
            Dsymbol s = ids.fd;
            auto fdv = v.toParent().isFuncDeclaration();
            assert(fdv);
            result = new VarExp(e.loc, ids.vthis);
            result.type = ids.vthis.type;
            if (ids.fd.hasDualContext())
            {
                // &__this
                result = new AddrExp(e.loc, result);
                result.type = ids.vthis.type.pointerTo();
            }
            while (s != fdv)
            {
                auto f = s.isFuncDeclaration();
                AggregateDeclaration ad;
                if (f && f.hasDualContext())
                {
                    if (f.hasNestedFrameRefs())
                    {
                        result = new DotVarExp(e.loc, result, f.vthis);
                        result.type = f.vthis.type;
                    }
                    // (*__this)[i]
                    uint i = f.followInstantiationContext(fdv);
                    if (i == 1 && f == ids.fd)
                    {
                        auto ve = e.copy().isVarExp();
                        ve.originalScope = ids.fd;
                        result = ve;
                        return;
                    }
                    result = new PtrExp(e.loc, result);
                    result.type = Type.tvoidptr.sarrayOf(2);
                    auto ie = new IndexExp(e.loc, result, new IntegerExp(i));
                    ie.indexIsInBounds = true; // no runtime bounds checking
                    result = ie;
                    result.type = Type.tvoidptr;
                    s = f.toParentP(fdv);
                    ad = s.isAggregateDeclaration();
                    if (ad)
                        goto Lad;
                    continue;
                }
                else if ((ad = s.isThis()) !is null)
                {
            Lad:
                    while (ad)
                    {
                        assert(ad.vthis);
                        bool i = ad.followInstantiationContext(fdv);
                        auto vthis = i ? ad.vthis2 : ad.vthis;
                        result = new DotVarExp(e.loc, result, vthis);
                        result.type = vthis.type;
                        s = ad.toParentP(fdv);
                        ad = s.isAggregateDeclaration();
                    }
                }
                else if (f && f.isNested())
                {
                    assert(f.vthis);
                    if (f.hasNestedFrameRefs())
                    {
                        result = new DotVarExp(e.loc, result, f.vthis);
                        result.type = f.vthis.type;
                    }
                    s = f.toParent2();
                }
                else
                    assert(0);
                assert(s);
            }
            result = new DotVarExp(e.loc, result, v);
            result.type = v.type;
            //printf("\t==> result = %s, type = %s\n", result.toChars(), result.type.toChars());
            return;
        }
        else if (v && v.nestedrefs.length)
        {
            auto ve = e.copy().isVarExp();
            ve.originalScope = ids.fd;
            result = ve;
            return;
        }

        result = e;
    }

    override void visit(ThisExp e)
    {
        //if (!ids.vthis)
        //    e.error("no `this` when inlining `%s`", ids.parent.toChars());
        if (!ids.vthis)
        {
            result = e;
            return;
        }
        result = new VarExp(e.loc, ids.vthis);
        if (ids.fd.hasDualContext())
        {
            // __this[0]
            result.type = ids.vthis.type;
            auto ie = new IndexExp(e.loc, result, IntegerExp.literal!0);
            ie.indexIsInBounds = true; // no runtime bounds checking
            result = ie;
            if (e.type.ty == Tstruct)
            {
                result.type = e.type.pointerTo();
                result = new PtrExp(e.loc, result);
            }
        }
        result.type = e.type;
    }

    override void visit(SuperExp e)
    {
        assert(ids.vthis);
        result = new VarExp(e.loc, ids.vthis);
        if (ids.fd.hasDualContext())
        {
            // __this[0]
            result.type = ids.vthis.type;
            auto ie = new IndexExp(e.loc, result, IntegerExp.literal!0);
            ie.indexIsInBounds = true; // no runtime bounds checking
            result = ie;
        }
        result.type = e.type;
    }

    override void visit(DeclarationExp e)
    {
        //printf("DeclarationExp.doInlineAs!%s(%s)\n", Result.stringof.ptr, e.toChars());
        if (auto vd = e.declaration.isVarDeclaration())
        {
            version (none)
            {
                // Need to figure this out before inlining can work for tuples
                if (auto tup = vd.toAlias().isTupleDeclaration())
                {
                    tup.foreachVar((s) { s; });
                    result = st.objects.length;
                    return;
                }
            }
            if (vd.isStatic())
                return;

            if (ids.fd && vd == ids.fd.nrvo_var)
            {
                foreach (i; 0 .. ids.from.length)
                {
                    if (vd != ids.from[i])
                        continue;
                    if (vd._init && !vd._init.isVoidInitializer())
                    {
                        result = vd._init.initializerToExpression();
                        assert(result);
                        result = doInlineExpression(result, ids);
                    }
                    else
                        result = IntegerExp.literal!0;
                    return;
                }
            }

            auto vto = new VarDeclaration(vd.loc, vd.type, vd.ident, vd._init);
            memcpy(cast(void*)vto, cast(void*)vd, __traits(classInstanceSize, VarDeclaration));
            vto.parent = ids.parent;
            vto.csym = null;

            ids.from.push(vd);
            ids.to.push(vto);

            if (vd._init)
            {
                if (vd._init.isVoidInitializer())
                {
                    vto._init = new VoidInitializer(vd._init.loc);
                }
                else
                {
                    auto ei = vd._init.initializerToExpression();
                    assert(ei);
                    vto._init = new ExpInitializer(ei.loc, doInlineExpression(ei, ids));
                }
            }
            if (vd.edtor)
            {
                vto.edtor = doInlineExpression(vd.edtor, ids);
            }
            auto de = e.copy().isDeclarationExp();
            de.declaration = vto;
            result = de;
            return;
        }

        // Prevent the copy of the aggregates allowed in inlineable funcs
        if (isInlinableNestedAggregate(e))
            return;

        /* This needs work, like DeclarationExp.toElem(), if we are
         * to handle TemplateMixin's. For now, we just don't inline them.
         */
        visit(cast(Expression)e);
    }

    override void visit(TypeidExp e)
    {
        //printf("TypeidExp.doInlineAs!%s(): %s\n", Result.stringof.ptr, e.toChars());
        auto te = e.copy().isTypeidExp();
        if (auto ex = isExpression(te.obj))
        {
            te.obj = doInlineExpression(ex, ids);
        }
        else
            assert(isType(te.obj));
        result = te;
    }

    override void visit(NewExp e)
    {
        //printf("NewExp.doInlineAs!%s(): %s\n", Result.stringof.ptr, e.toChars());
        auto ne = e.copy().isNewExp();
        auto lowering = ne.lowering;
        if (lowering)
            if (auto ce = lowering.isCallExp())
                if (ce.f.ident == Id._d_newarrayT || ce.f.ident == Id._d_newarraymTX)
                {
                    ne.lowering = doInlineExpression(lowering, ids);
                    goto LhasLowering;
                }

        ne.thisexp = doInlineExpression(e.thisexp, ids);
        ne.argprefix = doInlineExpression(e.argprefix, ids);
        ne.arguments = arrayExpressionDoInline(e.arguments);

    LhasLowering:
        result = ne;

        semanticTypeInfo(null, e.type);
    }

    override void visit(UnaExp e)
    {
        auto ue = cast(UnaExp)e.copy();
        ue.e1 = doInlineExpression(e.e1, ids);
        result = ue;
    }

    override void visit(AssertExp e)
    {
        auto ae = e.copy().isAssertExp();
        ae.e1 = doInlineExpression(e.e1, ids);
        ae.msg = doInlineExpression(e.msg, ids);
        result = ae;
    }

    override void visit(CatExp e)
    {
        auto ce = e.copy().isCatExp();

        if (auto lowering = ce.lowering)
            ce.lowering = doInlineExpression(lowering, ids);
        else
        {
            ce.e1 = doInlineExpression(e.e1, ids);
            ce.e2 = doInlineExpression(e.e2, ids);
        }

        result = ce;
    }

    override void visit(CatAssignExp e)
    {
        auto cae = cast(CatAssignExp) e.copy();

        if (auto lowering = cae.lowering)
            cae.lowering = doInlineExpression(cae.lowering, ids);
        else
        {
            cae.e1 = doInlineExpression(e.e1, ids);
            cae.e2 = doInlineExpression(e.e2, ids);
        }

        result = cae;
    }

    override void visit(BinExp e)
    {
        auto be = cast(BinExp)e.copy();
        be.e1 = doInlineExpression(e.e1, ids);
        be.e2 = doInlineExpression(e.e2, ids);
        result = be;
    }

    override void visit(CallExp e)
    {
        auto ce = e.copy().isCallExp();
        ce.e1 = doInlineExpression(e.e1, ids);
        ce.arguments = arrayExpressionDoInline(e.arguments);
        result = ce;
    }

    override void visit(AssignExp e)
    {
        visit(cast(BinExp)e);
    }

    override void visit(LoweredAssignExp e)
    {
        result = doInlineExpression(e.lowering, ids);
    }

    override void visit(EqualExp e)
    {
        visit(cast(BinExp)e);

        Type t1 = e.e1.type.toBasetype();
        if (t1.ty == Tarray || t1.ty == Tsarray)
        {
            Type t = t1.nextOf().toBasetype();
            while (t.toBasetype().nextOf())
                t = t.nextOf().toBasetype();
            if (t.ty == Tstruct)
                semanticTypeInfo(null, t);
        }
        else if (t1.ty == Taarray)
        {
            semanticTypeInfo(null, t1);
        }
    }

    override void visit(IndexExp e)
    {
        auto are = e.copy().isIndexExp();
        are.e1 = doInlineExpression(e.e1, ids);
        if (e.lengthVar)
        {
            //printf("lengthVar\n");
            auto vd = e.lengthVar;
            auto vto = new VarDeclaration(vd.loc, vd.type, vd.ident, vd._init);
            memcpy(cast(void*)vto, cast(void*)vd, __traits(classInstanceSize, VarDeclaration));
            vto.parent = ids.parent;
            vto.csym = null;

            ids.from.push(vd);
            ids.to.push(vto);

            if (vd._init && !vd._init.isVoidInitializer())
            {
                auto ie = vd._init.isExpInitializer();
                assert(ie);
                vto._init = new ExpInitializer(ie.loc, doInlineExpression(ie.exp, ids));
            }
            are.lengthVar = vto;
        }
        are.e2 = doInlineExpression(e.e2, ids);
        result = are;
    }

    override void visit(SliceExp e)
    {
        auto are = e.copy().isSliceExp();
        are.e1 = doInlineExpression(e.e1, ids);
        if (e.lengthVar)
        {
            //printf("lengthVar\n");
            auto vd = e.lengthVar;
            auto vto = new VarDeclaration(vd.loc, vd.type, vd.ident, vd._init);
            memcpy(cast(void*)vto, cast(void*)vd, __traits(classInstanceSize, VarDeclaration));
            vto.parent = ids.parent;
            vto.csym = null;

            ids.from.push(vd);
            ids.to.push(vto);

            if (vd._init && !vd._init.isVoidInitializer())
            {
                auto ie = vd._init.isExpInitializer();
                assert(ie);
                vto._init = new ExpInitializer(ie.loc, doInlineExpression(ie.exp, ids));
            }

            are.lengthVar = vto;
        }
        are.lwr = doInlineExpression(e.lwr, ids);
        are.upr = doInlineExpression(e.upr, ids);
        result = are;
    }

    override void visit(TupleExp e)
    {
        auto ce = e.copy().isTupleExp();
        ce.e0 = doInlineExpression(e.e0, ids);
        ce.exps = arrayExpressionDoInline(e.exps);
        result = ce;
    }

    override void visit(ArrayLiteralExp e)
    {
        auto ce = e.copy().isArrayLiteralExp();
        ce.basis = doInlineExpression(e.basis, ids);
        ce.elements = arrayExpressionDoInline(e.elements);
        result = ce;

        semanticTypeInfo(null, e.type);
    }

    override void visit(AssocArrayLiteralExp e)
    {
        auto ce = e.copy().isAssocArrayLiteralExp();
        ce.keys = arrayExpressionDoInline(e.keys);
        ce.values = arrayExpressionDoInline(e.values);
        result = ce;

        semanticTypeInfo(null, e.type);
    }

    override void visit(StructLiteralExp e)
    {
        if (e.inlinecopy)
        {
            result = e.inlinecopy;
            return;
        }
        auto ce = e.copy().isStructLiteralExp();
        e.inlinecopy = ce;
        ce.elements = arrayExpressionDoInline(e.elements);
        e.inlinecopy = null;
        result = ce;
    }

    override void visit(ArrayExp e)
    {
        assert(0); // this should have been lowered to something else
    }

    override void visit(CondExp e)
    {
        auto ce = e.copy().isCondExp();
        ce.econd = doInlineExpression(e.econd, ids);
        ce.e1 = doInlineExpression(e.e1, ids);
        ce.e2 = doInlineExpression(e.e2, ids);
        result = ce;
    }
}

/// ditto
private Expression doInlineExpression(Expression e, InlineDoState ids)
{
    if (!e)
        return null;

    scope v = new DoInlineExpression(ids);
    e.accept(v);
    return v.result;
}
