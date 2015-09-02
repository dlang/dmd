// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.opover;

import core.stdc.stdio, core.stdc.string;
import ddmd.aggregate, ddmd.aliasthis, ddmd.arraytypes, ddmd.dclass, ddmd.declaration, ddmd.dscope, ddmd.dstruct, ddmd.dsymbol, ddmd.dtemplate, ddmd.errors, ddmd.expression, ddmd.func, ddmd.globals, ddmd.id, ddmd.identifier, ddmd.mtype, ddmd.statement, ddmd.tokens, ddmd.visitor;

/******************************** Expression **************************/
/***********************************
 * Determine if operands of binary op can be reversed
 * to fit operator overload.
 */
extern (C++) bool isCommutative(TOK op)
{
    switch (op)
    {
    case TOKadd:
    case TOKmul:
    case TOKand:
    case TOKor:
    case TOKxor:
        // EqualExp
    case TOKequal:
    case TOKnotequal:
        // CmpExp
    case TOKlt:
    case TOKle:
    case TOKgt:
    case TOKge:
    case TOKunord:
    case TOKlg:
    case TOKleg:
    case TOKule:
    case TOKul:
    case TOKuge:
    case TOKug:
    case TOKue:
        return true;
    default:
        break;
    }
    return false;
}

/***********************************
 * Get Identifier for operator overload.
 */
extern (C++) static Identifier opId(Expression e)
{
    extern (C++) final class OpIdVisitor : Visitor
    {
        alias visit = super.visit;
    public:
        Identifier id;

        void visit(Expression e)
        {
            assert(0);
        }

        void visit(UAddExp e)
        {
            id = Id.uadd;
        }

        void visit(NegExp e)
        {
            id = Id.neg;
        }

        void visit(ComExp e)
        {
            id = Id.com;
        }

        void visit(CastExp e)
        {
            id = Id._cast;
        }

        void visit(InExp e)
        {
            id = Id.opIn;
        }

        void visit(PostExp e)
        {
            id = (e.op == TOKplusplus) ? Id.postinc : Id.postdec;
        }

        void visit(AddExp e)
        {
            id = Id.add;
        }

        void visit(MinExp e)
        {
            id = Id.sub;
        }

        void visit(MulExp e)
        {
            id = Id.mul;
        }

        void visit(DivExp e)
        {
            id = Id.div;
        }

        void visit(ModExp e)
        {
            id = Id.mod;
        }

        void visit(PowExp e)
        {
            id = Id.pow;
        }

        void visit(ShlExp e)
        {
            id = Id.shl;
        }

        void visit(ShrExp e)
        {
            id = Id.shr;
        }

        void visit(UshrExp e)
        {
            id = Id.ushr;
        }

        void visit(AndExp e)
        {
            id = Id.iand;
        }

        void visit(OrExp e)
        {
            id = Id.ior;
        }

        void visit(XorExp e)
        {
            id = Id.ixor;
        }

        void visit(CatExp e)
        {
            id = Id.cat;
        }

        void visit(AssignExp e)
        {
            id = Id.assign;
        }

        void visit(AddAssignExp e)
        {
            id = Id.addass;
        }

        void visit(MinAssignExp e)
        {
            id = Id.subass;
        }

        void visit(MulAssignExp e)
        {
            id = Id.mulass;
        }

        void visit(DivAssignExp e)
        {
            id = Id.divass;
        }

        void visit(ModAssignExp e)
        {
            id = Id.modass;
        }

        void visit(AndAssignExp e)
        {
            id = Id.andass;
        }

        void visit(OrAssignExp e)
        {
            id = Id.orass;
        }

        void visit(XorAssignExp e)
        {
            id = Id.xorass;
        }

        void visit(ShlAssignExp e)
        {
            id = Id.shlass;
        }

        void visit(ShrAssignExp e)
        {
            id = Id.shrass;
        }

        void visit(UshrAssignExp e)
        {
            id = Id.ushrass;
        }

        void visit(CatAssignExp e)
        {
            id = Id.catass;
        }

        void visit(PowAssignExp e)
        {
            id = Id.powass;
        }

        void visit(EqualExp e)
        {
            id = Id.eq;
        }

        void visit(CmpExp e)
        {
            id = Id.cmp;
        }

        void visit(ArrayExp e)
        {
            id = Id.index;
        }

        void visit(PtrExp e)
        {
            id = Id.opStar;
        }
    }

    scope OpIdVisitor v = new OpIdVisitor();
    e.accept(v);
    return v.id;
}

/***********************************
 * Get Identifier for reverse operator overload,
 * NULL if not supported for this operator.
 */
extern (C++) static Identifier opId_r(Expression e)
{
    extern (C++) final class OpIdRVisitor : Visitor
    {
        alias visit = super.visit;
    public:
        Identifier id;

        void visit(Expression e)
        {
            id = null;
        }

        void visit(InExp e)
        {
            id = Id.opIn_r;
        }

        void visit(AddExp e)
        {
            id = Id.add_r;
        }

        void visit(MinExp e)
        {
            id = Id.sub_r;
        }

        void visit(MulExp e)
        {
            id = Id.mul_r;
        }

        void visit(DivExp e)
        {
            id = Id.div_r;
        }

        void visit(ModExp e)
        {
            id = Id.mod_r;
        }

        void visit(PowExp e)
        {
            id = Id.pow_r;
        }

        void visit(ShlExp e)
        {
            id = Id.shl_r;
        }

        void visit(ShrExp e)
        {
            id = Id.shr_r;
        }

        void visit(UshrExp e)
        {
            id = Id.ushr_r;
        }

        void visit(AndExp e)
        {
            id = Id.iand_r;
        }

        void visit(OrExp e)
        {
            id = Id.ior_r;
        }

        void visit(XorExp e)
        {
            id = Id.ixor_r;
        }

        void visit(CatExp e)
        {
            id = Id.cat_r;
        }
    }

    scope OpIdRVisitor v = new OpIdRVisitor();
    e.accept(v);
    return v.id;
}

/************************************
 * If type is a class or struct, return the symbol for it,
 * else NULL
 */
extern (C++) AggregateDeclaration isAggregate(Type t)
{
    t = t.toBasetype();
    if (t.ty == Tclass)
    {
        return (cast(TypeClass)t).sym;
    }
    else if (t.ty == Tstruct)
    {
        return (cast(TypeStruct)t).sym;
    }
    return null;
}

/*******************************************
 * Helper function to turn operator into template argument list
 */
extern (C++) Objects* opToArg(Scope* sc, TOK op)
{
    /* Remove the = from op=
     */
    switch (op)
    {
    case TOKaddass:
        op = TOKadd;
        break;
    case TOKminass:
        op = TOKmin;
        break;
    case TOKmulass:
        op = TOKmul;
        break;
    case TOKdivass:
        op = TOKdiv;
        break;
    case TOKmodass:
        op = TOKmod;
        break;
    case TOKandass:
        op = TOKand;
        break;
    case TOKorass:
        op = TOKor;
        break;
    case TOKxorass:
        op = TOKxor;
        break;
    case TOKshlass:
        op = TOKshl;
        break;
    case TOKshrass:
        op = TOKshr;
        break;
    case TOKushrass:
        op = TOKushr;
        break;
    case TOKcatass:
        op = TOKcat;
        break;
    case TOKpowass:
        op = TOKpow;
        break;
    default:
        break;
    }
    Expression e = new StringExp(Loc(), cast(char*)Token.toChars(op));
    e = e.semantic(sc);
    auto tiargs = new Objects();
    tiargs.push(e);
    return tiargs;
}

/************************************
 * Operator overload.
 * Check for operator overload, if so, replace
 * with function call.
 * Return NULL if not an operator overload.
 */
extern (C++) Expression op_overload(Expression e, Scope* sc)
{
    extern (C++) final class OpOverload : Visitor
    {
        alias visit = super.visit;
    public:
        Scope* sc;
        Expression result;

        extern (D) this(Scope* sc)
        {
            this.sc = sc;
            result = null;
        }

        void visit(Expression e)
        {
            assert(0);
        }

        void visit(UnaExp e)
        {
            //printf("UnaExp::op_overload() (%s)\n", e->toChars());
            if (e.e1.op == TOKarray)
            {
                ArrayExp ae = cast(ArrayExp)e.e1;
                ae.e1 = ae.e1.semantic(sc);
                ae.e1 = resolveProperties(sc, ae.e1);
                Expression ae1old = ae.e1;
                const(bool) maybeSlice = (ae.arguments.dim == 0 || ae.arguments.dim == 1 && (*ae.arguments)[0].op == TOKinterval);
                IntervalExp ie = null;
                if (maybeSlice && ae.arguments.dim)
                {
                    assert((*ae.arguments)[0].op == TOKinterval);
                    ie = cast(IntervalExp)(*ae.arguments)[0];
                }
                while (true)
                {
                    if (ae.e1.op == TOKerror)
                    {
                        result = ae.e1;
                        return;
                    }
                    Expression e0 = null;
                    Expression ae1save = ae.e1;
                    ae.lengthVar = null;
                    Type t1b = ae.e1.type.toBasetype();
                    AggregateDeclaration ad = isAggregate(t1b);
                    if (!ad)
                        break;
                    if (search_function(ad, Id.opIndexUnary))
                    {
                        // Deal with $
                        result = resolveOpDollar(sc, ae, &e0);
                        if (!result) // op(a[i..j]) might be: a.opSliceUnary!(op)(i, j)
                            goto Lfallback;
                        if (result.op == TOKerror)
                            return;
                        /* Rewrite op(a[arguments]) as:
                         *      a.opIndexUnary!(op)(arguments)
                         */
                        Expressions* a = cast(Expressions*)ae.arguments.copy();
                        Objects* tiargs = opToArg(sc, e.op);
                        result = new DotTemplateInstanceExp(e.loc, ae.e1, Id.opIndexUnary, tiargs);
                        result = new CallExp(e.loc, result, a);
                        if (maybeSlice) // op(a[]) might be: a.opSliceUnary!(op)()
                            result = result.trySemantic(sc);
                        else
                            result = result.semantic(sc);
                        if (result)
                        {
                            result = Expression.combine(e0, result);
                            return;
                        }
                    }
                Lfallback:
                    if (maybeSlice && search_function(ad, Id.opSliceUnary))
                    {
                        // Deal with $
                        result = resolveOpDollar(sc, ae, ie, &e0);
                        if (result.op == TOKerror)
                            return;
                        /* Rewrite op(a[i..j]) as:
                         *      a.opSliceUnary!(op)(i, j)
                         */
                        auto a = new Expressions();
                        if (ie)
                        {
                            a.push(ie.lwr);
                            a.push(ie.upr);
                        }
                        Objects* tiargs = opToArg(sc, e.op);
                        result = new DotTemplateInstanceExp(e.loc, ae.e1, Id.opSliceUnary, tiargs);
                        result = new CallExp(e.loc, result, a);
                        result = result.semantic(sc);
                        result = Expression.combine(e0, result);
                        return;
                    }
                    // Didn't find it. Forward to aliasthis
                    if (ad.aliasthis && t1b != ae.att1)
                    {
                        if (!ae.att1 && t1b.checkAliasThisRec())
                            ae.att1 = t1b;
                        /* Rewrite op(a[arguments]) as:
                         *      op(a.aliasthis[arguments])
                         */
                        ae.e1 = resolveAliasThis(sc, ae1save, true);
                        if (ae.e1)
                            continue;
                    }
                    break;
                }
                ae.e1 = ae1old; // recovery
                ae.lengthVar = null;
            }
            e.e1 = e.e1.semantic(sc);
            e.e1 = resolveProperties(sc, e.e1);
            if (e.e1.op == TOKerror)
            {
                result = e.e1;
                return;
            }
            AggregateDeclaration ad = isAggregate(e.e1.type);
            if (ad)
            {
                Dsymbol fd = null;
                version (all)
                {
                    // Old way, kept for compatibility with D1
                    if (e.op != TOKpreplusplus && e.op != TOKpreminusminus)
                    {
                        fd = search_function(ad, opId(e));
                        if (fd)
                        {
                            // Rewrite +e1 as e1.add()
                            result = build_overload(e.loc, sc, e.e1, null, fd);
                            return;
                        }
                    }
                }
                /* Rewrite as:
                 *      e1.opUnary!(op)()
                 */
                fd = search_function(ad, Id.opUnary);
                if (fd)
                {
                    Objects* tiargs = opToArg(sc, e.op);
                    result = new DotTemplateInstanceExp(e.loc, e.e1, fd.ident, tiargs);
                    result = new CallExp(e.loc, result);
                    result = result.semantic(sc);
                    return;
                }
                // Didn't find it. Forward to aliasthis
                if (ad.aliasthis && e.e1.type != e.att1)
                {
                    /* Rewrite op(e1) as:
                     *      op(e1.aliasthis)
                     */
                    //printf("att una %s e1 = %s\n", Token::toChars(op), this->e1->type->toChars());
                    Expression e1 = new DotIdExp(e.loc, e.e1, ad.aliasthis.ident);
                    UnaExp ue = cast(UnaExp)e.copy();
                    if (!ue.att1 && e.e1.type.checkAliasThisRec())
                        ue.att1 = e.e1.type;
                    ue.e1 = e1;
                    result = ue.trySemantic(sc);
                    return;
                }
            }
        }

        void visit(ArrayExp ae)
        {
            //printf("ArrayExp::op_overload() (%s)\n", ae->toChars());
            ae.e1 = ae.e1.semantic(sc);
            ae.e1 = resolveProperties(sc, ae.e1);
            Expression ae1old = ae.e1;
            const(bool) maybeSlice = (ae.arguments.dim == 0 || ae.arguments.dim == 1 && (*ae.arguments)[0].op == TOKinterval);
            IntervalExp ie = null;
            if (maybeSlice && ae.arguments.dim)
            {
                assert((*ae.arguments)[0].op == TOKinterval);
                ie = cast(IntervalExp)(*ae.arguments)[0];
            }
            while (true)
            {
                if (ae.e1.op == TOKerror)
                {
                    result = ae.e1;
                    return;
                }
                Expression e0 = null;
                Expression ae1save = ae.e1;
                ae.lengthVar = null;
                Type t1b = ae.e1.type.toBasetype();
                AggregateDeclaration ad = isAggregate(t1b);
                if (!ad)
                {
                    // If the non-aggregate expression ae->e1 is indexable or sliceable,
                    // convert it to the corresponding concrete expression.
                    if (t1b.ty == Tpointer || t1b.ty == Tsarray || t1b.ty == Tarray || t1b.ty == Taarray || t1b.ty == Ttuple || ae.e1.op == TOKtype)
                    {
                        // Convert to SliceExp
                        if (maybeSlice)
                        {
                            result = new SliceExp(ae.loc, ae.e1, ie);
                            result = result.semantic(sc);
                            return;
                        }
                        // Convert to IndexExp
                        if (ae.arguments.dim == 1)
                        {
                            result = new IndexExp(ae.loc, ae.e1, (*ae.arguments)[0]);
                            result = result.semantic(sc);
                            return;
                        }
                    }
                    break;
                }
                if (search_function(ad, Id.index))
                {
                    // Deal with $
                    result = resolveOpDollar(sc, ae, &e0);
                    if (!result) // a[i..j] might be: a.opSlice(i, j)
                        goto Lfallback;
                    if (result.op == TOKerror)
                        return;
                    /* Rewrite e1[arguments] as:
                     *      e1.opIndex(arguments)
                     */
                    Expressions* a = cast(Expressions*)ae.arguments.copy();
                    result = new DotIdExp(ae.loc, ae.e1, Id.index);
                    result = new CallExp(ae.loc, result, a);
                    if (maybeSlice) // a[] might be: a.opSlice()
                        result = result.trySemantic(sc);
                    else
                        result = result.semantic(sc);
                    if (result)
                    {
                        result = Expression.combine(e0, result);
                        return;
                    }
                }
            Lfallback:
                if (maybeSlice && ae.e1.op == TOKtype)
                {
                    result = new SliceExp(ae.loc, ae.e1, ie);
                    result = result.semantic(sc);
                    result = Expression.combine(e0, result);
                    return;
                }
                if (maybeSlice && search_function(ad, Id.slice))
                {
                    // Deal with $
                    result = resolveOpDollar(sc, ae, ie, &e0);
                    if (result.op == TOKerror)
                        return;
                    /* Rewrite a[i..j] as:
                     *      a.opSlice(i, j)
                     */
                    auto a = new Expressions();
                    if (ie)
                    {
                        a.push(ie.lwr);
                        a.push(ie.upr);
                    }
                    result = new DotIdExp(ae.loc, ae.e1, Id.slice);
                    result = new CallExp(ae.loc, result, a);
                    result = result.semantic(sc);
                    result = Expression.combine(e0, result);
                    return;
                }
                // Didn't find it. Forward to aliasthis
                if (ad.aliasthis && t1b != ae.att1)
                {
                    if (!ae.att1 && t1b.checkAliasThisRec())
                        ae.att1 = t1b;
                    //printf("att arr e1 = %s\n", this->e1->type->toChars());
                    /* Rewrite op(a[arguments]) as:
                     *      op(a.aliasthis[arguments])
                     */
                    ae.e1 = resolveAliasThis(sc, ae1save, true);
                    if (ae.e1)
                        continue;
                }
                break;
            }
            ae.e1 = ae1old; // recovery
            ae.lengthVar = null;
        }

        /***********************************************
         * This is mostly the same as UnaryExp::op_overload(), but has
         * a different rewrite.
         */
        void visit(CastExp e)
        {
            //printf("CastExp::op_overload() (%s)\n", e->toChars());
            AggregateDeclaration ad = isAggregate(e.e1.type);
            if (ad)
            {
                Dsymbol fd = null;
                /* Rewrite as:
                 *      e1.opCast!(T)()
                 */
                fd = search_function(ad, Id._cast);
                if (fd)
                {
                    version (all)
                    {
                        // Backwards compatibility with D1 if opCast is a function, not a template
                        if (fd.isFuncDeclaration())
                        {
                            // Rewrite as:  e1.opCast()
                            result = build_overload(e.loc, sc, e.e1, null, fd);
                            return;
                        }
                    }
                    auto tiargs = new Objects();
                    tiargs.push(e.to);
                    result = new DotTemplateInstanceExp(e.loc, e.e1, fd.ident, tiargs);
                    result = new CallExp(e.loc, result);
                    result = result.semantic(sc);
                    return;
                }
                // Didn't find it. Forward to aliasthis
                if (ad.aliasthis)
                {
                    /* Rewrite op(e1) as:
                     *      op(e1.aliasthis)
                     */
                    Expression e1 = new DotIdExp(e.loc, e.e1, ad.aliasthis.ident);
                    result = e.copy();
                    (cast(UnaExp)result).e1 = e1;
                    result = result.trySemantic(sc);
                    return;
                }
            }
        }

        void visit(BinExp e)
        {
            //printf("BinExp::op_overload() (%s)\n", e->toChars());
            Identifier id = opId(e);
            Identifier id_r = opId_r(e);
            Expressions args1;
            Expressions args2;
            int argsset = 0;
            AggregateDeclaration ad1 = isAggregate(e.e1.type);
            AggregateDeclaration ad2 = isAggregate(e.e2.type);
            if (e.op == TOKassign && ad1 == ad2)
            {
                StructDeclaration sd = ad1.isStructDeclaration();
                if (sd && !sd.hasIdentityAssign)
                {
                    /* This is bitwise struct assignment. */
                    return;
                }
            }
            Dsymbol s = null;
            Dsymbol s_r = null;
            version (all)
            {
                // the old D1 scheme
                if (ad1 && id)
                {
                    s = search_function(ad1, id);
                }
                if (ad2 && id_r)
                {
                    s_r = search_function(ad2, id_r);
                    // Bugzilla 12778: If both x.opBinary(y) and y.opBinaryRight(x) found,
                    // and they are exactly same symbol, x.opBinary(y) should be preferred.
                    if (s_r && s_r == s)
                        s_r = null;
                }
            }
            Objects* tiargs = null;
            if (e.op == TOKplusplus || e.op == TOKminusminus)
            {
                // Bug4099 fix
                if (ad1 && search_function(ad1, Id.opUnary))
                    return;
            }
            if (!s && !s_r && e.op != TOKequal && e.op != TOKnotequal && e.op != TOKassign && e.op != TOKplusplus && e.op != TOKminusminus)
            {
                /* Try the new D2 scheme, opBinary and opBinaryRight
                 */
                if (ad1)
                {
                    s = search_function(ad1, Id.opBinary);
                    if (s && !s.isTemplateDeclaration())
                    {
                        e.e1.error("%s.opBinary isn't a template", e.e1.toChars());
                        result = new ErrorExp();
                        return;
                    }
                }
                if (ad2)
                {
                    s_r = search_function(ad2, Id.opBinaryRight);
                    if (s_r && !s_r.isTemplateDeclaration())
                    {
                        e.e2.error("%s.opBinaryRight isn't a template", e.e2.toChars());
                        result = new ErrorExp();
                        return;
                    }
                    if (s_r && s_r == s) // Bugzilla 12778
                        s_r = null;
                }
                // Set tiargs, the template argument list, which will be the operator string
                if (s || s_r)
                {
                    id = Id.opBinary;
                    id_r = Id.opBinaryRight;
                    tiargs = opToArg(sc, e.op);
                }
            }
            if (s || s_r)
            {
                /* Try:
                 *      a.opfunc(b)
                 *      b.opfunc_r(a)
                 * and see which is better.
                 */
                args1.setDim(1);
                args1[0] = e.e1;
                expandTuples(&args1);
                args2.setDim(1);
                args2[0] = e.e2;
                expandTuples(&args2);
                argsset = 1;
                Match m;
                memset(&m, 0, m.sizeof);
                m.last = MATCHnomatch;
                if (s)
                {
                    functionResolve(&m, s, e.loc, sc, tiargs, e.e1.type, &args2);
                    if (m.lastf && (m.lastf.errors || m.lastf.semantic3Errors))
                    {
                        result = new ErrorExp();
                        return;
                    }
                }
                FuncDeclaration lastf = m.lastf;
                if (s_r)
                {
                    functionResolve(&m, s_r, e.loc, sc, tiargs, e.e2.type, &args1);
                    if (m.lastf && (m.lastf.errors || m.lastf.semantic3Errors))
                    {
                        result = new ErrorExp();
                        return;
                    }
                }
                if (m.count > 1)
                {
                    // Error, ambiguous
                    e.error("overloads %s and %s both match argument list for %s", m.lastf.type.toChars(), m.nextf.type.toChars(), m.lastf.toChars());
                }
                else if (m.last <= MATCHnomatch)
                {
                    m.lastf = m.anyf;
                    if (tiargs)
                        goto L1;
                }
                if (e.op == TOKplusplus || e.op == TOKminusminus)
                {
                    // Kludge because operator overloading regards e++ and e--
                    // as unary, but it's implemented as a binary.
                    // Rewrite (e1 ++ e2) as e1.postinc()
                    // Rewrite (e1 -- e2) as e1.postdec()
                    result = build_overload(e.loc, sc, e.e1, null, m.lastf ? m.lastf : s);
                }
                else if (lastf && m.lastf == lastf || !s_r && m.last <= MATCHnomatch)
                {
                    // Rewrite (e1 op e2) as e1.opfunc(e2)
                    result = build_overload(e.loc, sc, e.e1, e.e2, m.lastf ? m.lastf : s);
                }
                else
                {
                    // Rewrite (e1 op e2) as e2.opfunc_r(e1)
                    result = build_overload(e.loc, sc, e.e2, e.e1, m.lastf ? m.lastf : s_r);
                }
                return;
            }
        L1:
            version (all)
            {
                // Retained for D1 compatibility
                if (isCommutative(e.op) && !tiargs)
                {
                    s = null;
                    s_r = null;
                    if (ad1 && id_r)
                    {
                        s_r = search_function(ad1, id_r);
                    }
                    if (ad2 && id)
                    {
                        s = search_function(ad2, id);
                        if (s && s == s_r) // Bugzilla 12778
                            s = null;
                    }
                    if (s || s_r)
                    {
                        /* Try:
                         *  a.opfunc_r(b)
                         *  b.opfunc(a)
                         * and see which is better.
                         */
                        if (!argsset)
                        {
                            args1.setDim(1);
                            args1[0] = e.e1;
                            expandTuples(&args1);
                            args2.setDim(1);
                            args2[0] = e.e2;
                            expandTuples(&args2);
                        }
                        Match m;
                        memset(&m, 0, m.sizeof);
                        m.last = MATCHnomatch;
                        if (s_r)
                        {
                            functionResolve(&m, s_r, e.loc, sc, tiargs, e.e1.type, &args2);
                            if (m.lastf && (m.lastf.errors || m.lastf.semantic3Errors))
                            {
                                result = new ErrorExp();
                                return;
                            }
                        }
                        FuncDeclaration lastf = m.lastf;
                        if (s)
                        {
                            functionResolve(&m, s, e.loc, sc, tiargs, e.e2.type, &args1);
                            if (m.lastf && (m.lastf.errors || m.lastf.semantic3Errors))
                            {
                                result = new ErrorExp();
                                return;
                            }
                        }
                        if (m.count > 1)
                        {
                            // Error, ambiguous
                            e.error("overloads %s and %s both match argument list for %s", m.lastf.type.toChars(), m.nextf.type.toChars(), m.lastf.toChars());
                        }
                        else if (m.last <= MATCHnomatch)
                        {
                            m.lastf = m.anyf;
                        }
                        if (lastf && m.lastf == lastf || !s && m.last <= MATCHnomatch)
                        {
                            // Rewrite (e1 op e2) as e1.opfunc_r(e2)
                            result = build_overload(e.loc, sc, e.e1, e.e2, m.lastf ? m.lastf : s_r);
                        }
                        else
                        {
                            // Rewrite (e1 op e2) as e2.opfunc(e1)
                            result = build_overload(e.loc, sc, e.e2, e.e1, m.lastf ? m.lastf : s);
                        }
                        // When reversing operands of comparison operators,
                        // need to reverse the sense of the op
                        switch (e.op)
                        {
                        case TOKlt:
                            e.op = TOKgt;
                            break;
                        case TOKgt:
                            e.op = TOKlt;
                            break;
                        case TOKle:
                            e.op = TOKge;
                            break;
                        case TOKge:
                            e.op = TOKle;
                            break;
                            // Floating point compares
                        case TOKule:
                            e.op = TOKuge;
                            break;
                        case TOKul:
                            e.op = TOKug;
                            break;
                        case TOKuge:
                            e.op = TOKule;
                            break;
                        case TOKug:
                            e.op = TOKul;
                            break;
                            // These are symmetric
                        case TOKunord:
                        case TOKlg:
                        case TOKleg:
                        case TOKue:
                            break;
                        default:
                            break;
                        }
                        return;
                    }
                }
            }
            // Try alias this on first operand
            if (ad1 && ad1.aliasthis && !(e.op == TOKassign && ad2 && ad1 == ad2)) // See Bugzilla 2943
            {
                /* Rewrite (e1 op e2) as:
                 *      (e1.aliasthis op e2)
                 */
                if (e.att1 && e.e1.type == e.att1)
                    return;
                //printf("att bin e1 = %s\n", this->e1->type->toChars());
                Expression e1 = new DotIdExp(e.loc, e.e1, ad1.aliasthis.ident);
                BinExp be = cast(BinExp)e.copy();
                if (!be.att1 && e.e1.type.checkAliasThisRec())
                    be.att1 = e.e1.type;
                be.e1 = e1;
                result = be.trySemantic(sc);
                return;
            }
            // Try alias this on second operand
            /* Bugzilla 2943: make sure that when we're copying the struct, we don't
             * just copy the alias this member
             */
            if (ad2 && ad2.aliasthis && !(e.op == TOKassign && ad1 && ad1 == ad2))
            {
                /* Rewrite (e1 op e2) as:
                 *      (e1 op e2.aliasthis)
                 */
                if (e.att2 && e.e2.type == e.att2)
                    return;
                //printf("att bin e2 = %s\n", e->e2->type->toChars());
                Expression e2 = new DotIdExp(e.loc, e.e2, ad2.aliasthis.ident);
                BinExp be = cast(BinExp)e.copy();
                if (!be.att2 && e.e2.type.checkAliasThisRec())
                    be.att2 = e.e2.type;
                be.e2 = e2;
                result = be.trySemantic(sc);
                return;
            }
            return;
        }

        void visit(EqualExp e)
        {
            //printf("EqualExp::op_overload() (%s)\n", e->toChars());
            Type t1 = e.e1.type.toBasetype();
            Type t2 = e.e2.type.toBasetype();
            if (t1.ty == Tclass && t2.ty == Tclass)
            {
                ClassDeclaration cd1 = t1.isClassHandle();
                ClassDeclaration cd2 = t2.isClassHandle();
                if (!(cd1.cpp || cd2.cpp))
                {
                    /* Rewrite as:
                     *      .object.opEquals(e1, e2)
                     */
                    Expression e1x = e.e1;
                    Expression e2x = e.e2;
                    /*
                     * The explicit cast is necessary for interfaces,
                     * see http://d.puremagic.com/issues/show_bug.cgi?id=4088
                     */
                    Type to = ClassDeclaration.object.getType();
                    if (cd1.isInterfaceDeclaration())
                        e1x = new CastExp(e.loc, e.e1, t1.isMutable() ? to : to.constOf());
                    if (cd2.isInterfaceDeclaration())
                        e2x = new CastExp(e.loc, e.e2, t2.isMutable() ? to : to.constOf());
                    result = new IdentifierExp(e.loc, Id.empty);
                    result = new DotIdExp(e.loc, result, Id.object);
                    result = new DotIdExp(e.loc, result, Id.eq);
                    result = new CallExp(e.loc, result, e1x, e2x);
                    result = result.semantic(sc);
                    return;
                }
            }
            // Comparing a class with typeof(null) should not call opEquals
            if (t1.ty == Tclass && t2.ty == Tnull || t1.ty == Tnull && t2.ty == Tclass)
            {
            }
            else
            {
                result = compare_overload(e, sc, Id.eq);
            }
        }

        void visit(CmpExp e)
        {
            //printf("CmpExp::op_overload() (%s)\n", e->toChars());
            result = compare_overload(e, sc, Id.cmp);
        }

        /*********************************
         * Operator overloading for op=
         */
        void visit(BinAssignExp e)
        {
            //printf("BinAssignExp::op_overload() (%s)\n", e->toChars());
            if (e.e1.op == TOKarray)
            {
                ArrayExp ae = cast(ArrayExp)e.e1;
                ae.e1 = ae.e1.semantic(sc);
                ae.e1 = resolveProperties(sc, ae.e1);
                Expression ae1old = ae.e1;
                const(bool) maybeSlice = (ae.arguments.dim == 0 || ae.arguments.dim == 1 && (*ae.arguments)[0].op == TOKinterval);
                IntervalExp ie = null;
                if (maybeSlice && ae.arguments.dim)
                {
                    assert((*ae.arguments)[0].op == TOKinterval);
                    ie = cast(IntervalExp)(*ae.arguments)[0];
                }
                while (true)
                {
                    if (ae.e1.op == TOKerror)
                    {
                        result = ae.e1;
                        return;
                    }
                    Expression e0 = null;
                    Expression ae1save = ae.e1;
                    ae.lengthVar = null;
                    Type t1b = ae.e1.type.toBasetype();
                    AggregateDeclaration ad = isAggregate(t1b);
                    if (!ad)
                        break;
                    if (search_function(ad, Id.opIndexOpAssign))
                    {
                        // Deal with $
                        result = resolveOpDollar(sc, ae, &e0);
                        if (!result) // (a[i..j] op= e2) might be: a.opSliceOpAssign!(op)(e2, i, j)
                            goto Lfallback;
                        if (result.op == TOKerror)
                            return;
                        result = e.e2.semantic(sc);
                        if (result.op == TOKerror)
                            return;
                        e.e2 = result;
                        /* Rewrite a[arguments] op= e2 as:
                         *      a.opIndexOpAssign!(op)(e2, arguments)
                         */
                        Expressions* a = cast(Expressions*)ae.arguments.copy();
                        a.insert(0, e.e2);
                        Objects* tiargs = opToArg(sc, e.op);
                        result = new DotTemplateInstanceExp(e.loc, ae.e1, Id.opIndexOpAssign, tiargs);
                        result = new CallExp(e.loc, result, a);
                        if (maybeSlice) // (a[] op= e2) might be: a.opSliceOpAssign!(op)(e2)
                            result = result.trySemantic(sc);
                        else
                            result = result.semantic(sc);
                        if (result)
                        {
                            result = Expression.combine(e0, result);
                            return;
                        }
                    }
                Lfallback:
                    if (maybeSlice && search_function(ad, Id.opSliceOpAssign))
                    {
                        // Deal with $
                        result = resolveOpDollar(sc, ae, ie, &e0);
                        if (result.op == TOKerror)
                            return;
                        result = e.e2.semantic(sc);
                        if (result.op == TOKerror)
                            return;
                        e.e2 = result;
                        /* Rewrite (a[i..j] op= e2) as:
                         *      a.opSliceOpAssign!(op)(e2, i, j)
                         */
                        auto a = new Expressions();
                        a.push(e.e2);
                        if (ie)
                        {
                            a.push(ie.lwr);
                            a.push(ie.upr);
                        }
                        Objects* tiargs = opToArg(sc, e.op);
                        result = new DotTemplateInstanceExp(e.loc, ae.e1, Id.opSliceOpAssign, tiargs);
                        result = new CallExp(e.loc, result, a);
                        result = result.semantic(sc);
                        result = Expression.combine(e0, result);
                        return;
                    }
                    // Didn't find it. Forward to aliasthis
                    if (ad.aliasthis && t1b != ae.att1)
                    {
                        if (!ae.att1 && t1b.checkAliasThisRec())
                            ae.att1 = t1b;
                        /* Rewrite (a[arguments] op= e2) as:
                         *      a.aliasthis[arguments] op= e2
                         */
                        ae.e1 = resolveAliasThis(sc, ae1save, true);
                        if (ae.e1)
                            continue;
                    }
                    break;
                }
                ae.e1 = ae1old; // recovery
                ae.lengthVar = null;
            }
            result = e.binSemanticProp(sc);
            if (result)
                return;
            // Don't attempt 'alias this' if an error occured
            if (e.e1.type.ty == Terror || e.e2.type.ty == Terror)
            {
                result = new ErrorExp();
                return;
            }
            Identifier id = opId(e);
            Expressions args2;
            AggregateDeclaration ad1 = isAggregate(e.e1.type);
            Dsymbol s = null;
            version (all)
            {
                // the old D1 scheme
                if (ad1 && id)
                {
                    s = search_function(ad1, id);
                }
            }
            Objects* tiargs = null;
            if (!s)
            {
                /* Try the new D2 scheme, opOpAssign
                 */
                if (ad1)
                {
                    s = search_function(ad1, Id.opOpAssign);
                    if (s && !s.isTemplateDeclaration())
                    {
                        e.error("%s.opOpAssign isn't a template", e.e1.toChars());
                        result = new ErrorExp();
                        return;
                    }
                }
                // Set tiargs, the template argument list, which will be the operator string
                if (s)
                {
                    id = Id.opOpAssign;
                    tiargs = opToArg(sc, e.op);
                }
            }
            if (s)
            {
                /* Try:
                 *      a.opOpAssign(b)
                 */
                args2.setDim(1);
                args2[0] = e.e2;
                expandTuples(&args2);
                Match m;
                memset(&m, 0, m.sizeof);
                m.last = MATCHnomatch;
                if (s)
                {
                    functionResolve(&m, s, e.loc, sc, tiargs, e.e1.type, &args2);
                    if (m.lastf && (m.lastf.errors || m.lastf.semantic3Errors))
                    {
                        result = new ErrorExp();
                        return;
                    }
                }
                if (m.count > 1)
                {
                    // Error, ambiguous
                    e.error("overloads %s and %s both match argument list for %s", m.lastf.type.toChars(), m.nextf.type.toChars(), m.lastf.toChars());
                }
                else if (m.last <= MATCHnomatch)
                {
                    m.lastf = m.anyf;
                    if (tiargs)
                        goto L1;
                }
                // Rewrite (e1 op e2) as e1.opOpAssign(e2)
                result = build_overload(e.loc, sc, e.e1, e.e2, m.lastf ? m.lastf : s);
                return;
            }
        L1:
            // Try alias this on first operand
            if (ad1 && ad1.aliasthis)
            {
                /* Rewrite (e1 op e2) as:
                 *      (e1.aliasthis op e2)
                 */
                if (e.att1 && e.e1.type == e.att1)
                    return;
                //printf("att %s e1 = %s\n", Token::toChars(e->op), e->e1->type->toChars());
                Expression e1 = new DotIdExp(e.loc, e.e1, ad1.aliasthis.ident);
                BinExp be = cast(BinExp)e.copy();
                if (!be.att1 && e.e1.type.checkAliasThisRec())
                    be.att1 = e.e1.type;
                be.e1 = e1;
                result = be.trySemantic(sc);
                return;
            }
            // Try alias this on second operand
            AggregateDeclaration ad2 = isAggregate(e.e2.type);
            if (ad2 && ad2.aliasthis)
            {
                /* Rewrite (e1 op e2) as:
                 *      (e1 op e2.aliasthis)
                 */
                if (e.att2 && e.e2.type == e.att2)
                    return;
                //printf("att %s e2 = %s\n", Token::toChars(e->op), e->e2->type->toChars());
                Expression e2 = new DotIdExp(e.loc, e.e2, ad2.aliasthis.ident);
                BinExp be = cast(BinExp)e.copy();
                if (!be.att2 && e.e2.type.checkAliasThisRec())
                    be.att2 = e.e2.type;
                be.e2 = e2;
                result = be.trySemantic(sc);
                return;
            }
        }
    }

    scope OpOverload v = new OpOverload(sc);
    e.accept(v);
    return v.result;
}

/******************************************
 * Common code for overloading of EqualExp and CmpExp
 */
extern (C++) Expression compare_overload(BinExp e, Scope* sc, Identifier id)
{
    //printf("BinExp::compare_overload(id = %s) %s\n", id->toChars(), e->toChars());
    AggregateDeclaration ad1 = isAggregate(e.e1.type);
    AggregateDeclaration ad2 = isAggregate(e.e2.type);
    Dsymbol s = null;
    Dsymbol s_r = null;
    if (ad1)
    {
        s = search_function(ad1, id);
    }
    if (ad2)
    {
        s_r = search_function(ad2, id);
        if (s == s_r)
            s_r = null;
    }
    Objects* tiargs = null;
    if (s || s_r)
    {
        /* Try:
         *      a.opEquals(b)
         *      b.opEquals(a)
         * and see which is better.
         */
        Expressions args1;
        Expressions args2;
        args1.setDim(1);
        args1[0] = e.e1;
        expandTuples(&args1);
        args2.setDim(1);
        args2[0] = e.e2;
        expandTuples(&args2);
        Match m;
        memset(&m, 0, m.sizeof);
        m.last = MATCHnomatch;
        if (0 && s && s_r)
        {
            printf("s  : %s\n", s.toPrettyChars());
            printf("s_r: %s\n", s_r.toPrettyChars());
        }
        if (s)
        {
            functionResolve(&m, s, e.loc, sc, tiargs, e.e1.type, &args2);
            if (m.lastf && (m.lastf.errors || m.lastf.semantic3Errors))
                return new ErrorExp();
        }
        FuncDeclaration lastf = m.lastf;
        int count = m.count;
        if (s_r)
        {
            functionResolve(&m, s_r, e.loc, sc, tiargs, e.e2.type, &args1);
            if (m.lastf && (m.lastf.errors || m.lastf.semantic3Errors))
                return new ErrorExp();
        }
        if (m.count > 1)
        {
            /* The following if says "not ambiguous" if there's one match
             * from s and one from s_r, in which case we pick s.
             * This doesn't follow the spec, but is a workaround for the case
             * where opEquals was generated from templates and we cannot figure
             * out if both s and s_r came from the same declaration or not.
             * The test case is:
             *   import std.typecons;
             *   void main() {
             *    assert(tuple("has a", 2u) == tuple("has a", 1));
             *   }
             */
            if (!(m.lastf == lastf && m.count == 2 && count == 1))
            {
                // Error, ambiguous
                e.error("overloads %s and %s both match argument list for %s", m.lastf.type.toChars(), m.nextf.type.toChars(), m.lastf.toChars());
            }
        }
        else if (m.last <= MATCHnomatch)
        {
            m.lastf = m.anyf;
        }
        Expression result;
        if (lastf && m.lastf == lastf || !s_r && m.last <= MATCHnomatch)
        {
            // Rewrite (e1 op e2) as e1.opfunc(e2)
            result = build_overload(e.loc, sc, e.e1, e.e2, m.lastf ? m.lastf : s);
        }
        else
        {
            // Rewrite (e1 op e2) as e2.opfunc_r(e1)
            result = build_overload(e.loc, sc, e.e2, e.e1, m.lastf ? m.lastf : s_r);
            // When reversing operands of comparison operators,
            // need to reverse the sense of the op
            switch (e.op)
            {
            case TOKlt:
                e.op = TOKgt;
                break;
            case TOKgt:
                e.op = TOKlt;
                break;
            case TOKle:
                e.op = TOKge;
                break;
            case TOKge:
                e.op = TOKle;
                break;
                // Floating point compares
            case TOKule:
                e.op = TOKuge;
                break;
            case TOKul:
                e.op = TOKug;
                break;
            case TOKuge:
                e.op = TOKule;
                break;
            case TOKug:
                e.op = TOKul;
                break;
                // The rest are symmetric
            default:
                break;
            }
        }
        return result;
    }
    // Try alias this on first operand
    if (ad1 && ad1.aliasthis)
    {
        /* Rewrite (e1 op e2) as:
         *      (e1.aliasthis op e2)
         */
        if (e.att1 && e.e1.type == e.att1)
            return null;
        //printf("att cmp_bin e1 = %s\n", e->e1->type->toChars());
        Expression e1 = new DotIdExp(e.loc, e.e1, ad1.aliasthis.ident);
        BinExp be = cast(BinExp)e.copy();
        if (!be.att1 && e.e1.type.checkAliasThisRec())
            be.att1 = e.e1.type;
        be.e1 = e1;
        return be.trySemantic(sc);
    }
    // Try alias this on second operand
    if (ad2 && ad2.aliasthis)
    {
        /* Rewrite (e1 op e2) as:
         *      (e1 op e2.aliasthis)
         */
        if (e.att2 && e.e2.type == e.att2)
            return null;
        //printf("att cmp_bin e2 = %s\n", e->e2->type->toChars());
        Expression e2 = new DotIdExp(e.loc, e.e2, ad2.aliasthis.ident);
        BinExp be = cast(BinExp)e.copy();
        if (!be.att2 && e.e2.type.checkAliasThisRec())
            be.att2 = e.e2.type;
        be.e2 = e2;
        return be.trySemantic(sc);
    }
    return null;
}

/***********************************
 * Utility to build a function call out of this reference and argument.
 */
extern (C++) Expression build_overload(Loc loc, Scope* sc, Expression ethis, Expression earg, Dsymbol d)
{
    assert(d);
    Expression e;
    //printf("build_overload(id = '%s')\n", id->toChars());
    //earg->print();
    //earg->type->print();
    Declaration decl = d.isDeclaration();
    if (decl)
        e = new DotVarExp(loc, ethis, decl, 0);
    else
        e = new DotIdExp(loc, ethis, d.ident);
    e = new CallExp(loc, e, earg);
    e = e.semantic(sc);
    return e;
}

/***************************************
 * Search for function funcid in aggregate ad.
 */
extern (C++) Dsymbol search_function(ScopeDsymbol ad, Identifier funcid)
{
    Dsymbol s = ad.search(Loc(), funcid);
    if (s)
    {
        //printf("search_function: s = '%s'\n", s->kind());
        Dsymbol s2 = s.toAlias();
        //printf("search_function: s2 = '%s'\n", s2->kind());
        FuncDeclaration fd = s2.isFuncDeclaration();
        if (fd && fd.type.ty == Tfunction)
            return fd;
        TemplateDeclaration td = s2.isTemplateDeclaration();
        if (td)
            return td;
    }
    return null;
}

extern (C++) bool inferAggregate(ForeachStatement fes, Scope* sc, ref Dsymbol sapply)
{
    Identifier idapply = (fes.op == TOKforeach) ? Id.apply : Id.applyReverse;
    Identifier idfront = (fes.op == TOKforeach) ? Id.Ffront : Id.Fback;
    int sliced = 0;
    Type tab;
    Type att = null;
    Expression aggr = fes.aggr;
    AggregateDeclaration ad;
    while (1)
    {
        if (!aggr.type)
            goto Lerr;
        tab = aggr.type.toBasetype();
        switch (tab.ty)
        {
        case Tarray:
        case Tsarray:
        case Ttuple:
        case Taarray:
            break;
        case Tclass:
            ad = (cast(TypeClass)tab).sym;
            goto Laggr;
        case Tstruct:
            ad = (cast(TypeStruct)tab).sym;
            goto Laggr;
        Laggr:
            if (!sliced)
            {
                sapply = search_function(ad, idapply);
                if (sapply)
                {
                    // opApply aggregate
                    break;
                }
                if (fes.aggr.op != TOKtype)
                {
                    Expression rinit = new ArrayExp(fes.aggr.loc, fes.aggr);
                    rinit = rinit.trySemantic(sc);
                    if (rinit) // if application of [] succeeded
                    {
                        aggr = rinit;
                        sliced = 1;
                        continue;
                    }
                }
            }
            if (ad.search(Loc(), idfront))
            {
                // range aggregate
                break;
            }
            if (ad.aliasthis)
            {
                if (att == tab)
                    goto Lerr;
                if (!att && tab.checkAliasThisRec())
                    att = tab;
                aggr = resolveAliasThis(sc, aggr);
                continue;
            }
            goto Lerr;
        case Tdelegate:
            if (aggr.op == TOKdelegate)
            {
                sapply = (cast(DelegateExp)aggr).func;
            }
            break;
        case Terror:
            break;
        default:
            goto Lerr;
        }
        break;
    }
    fes.aggr = aggr;
    return true;
Lerr:
    return false;
}

/*****************************************
 * Given array of parameters and an aggregate type,
 * if any of the parameter types are missing, attempt to infer
 * them from the aggregate type.
 */
extern (C++) bool inferApplyArgTypes(ForeachStatement fes, Scope* sc, ref Dsymbol sapply)
{
    if (!fes.parameters || !fes.parameters.dim)
        return false;
    if (sapply) // prefer opApply
    {
        for (size_t u = 0; u < fes.parameters.dim; u++)
        {
            Parameter p = (*fes.parameters)[u];
            if (p.type)
            {
                p.type = p.type.semantic(fes.loc, sc);
                p.type = p.type.addStorageClass(p.storageClass);
            }
        }
        Expression ethis;
        Type tab = fes.aggr.type.toBasetype();
        if (tab.ty == Tclass || tab.ty == Tstruct)
            ethis = fes.aggr;
        else
        {
            assert(tab.ty == Tdelegate && fes.aggr.op == TOKdelegate);
            ethis = (cast(DelegateExp)fes.aggr).e1;
        }
        /* Look for like an
         *  int opApply(int delegate(ref Type [, ...]) dg);
         * overload
         */
        FuncDeclaration fd = sapply.isFuncDeclaration();
        if (fd)
        {
            sapply = inferApplyArgTypesX(ethis, fd, fes.parameters);
        }
        return sapply !is null;
    }
    /* Return if no parameters need types.
     */
    for (size_t u = 0; u < fes.parameters.dim; u++)
    {
        Parameter p = (*fes.parameters)[u];
        if (!p.type)
            break;
    }
    AggregateDeclaration ad;
    Parameter p = (*fes.parameters)[0];
    Type taggr = fes.aggr.type;
    assert(taggr);
    Type tab = taggr.toBasetype();
    switch (tab.ty)
    {
    case Tarray:
    case Tsarray:
    case Ttuple:
        if (fes.parameters.dim == 2)
        {
            if (!p.type)
            {
                p.type = Type.tsize_t; // key type
                p.type = p.type.addStorageClass(p.storageClass);
            }
            p = (*fes.parameters)[1];
        }
        if (!p.type && tab.ty != Ttuple)
        {
            p.type = tab.nextOf(); // value type
            p.type = p.type.addStorageClass(p.storageClass);
        }
        break;
    case Taarray:
        {
            TypeAArray taa = cast(TypeAArray)tab;
            if (fes.parameters.dim == 2)
            {
                if (!p.type)
                {
                    p.type = taa.index; // key type
                    p.type = p.type.addStorageClass(p.storageClass);
                    if (p.storageClass & STCref) // key must not be mutated via ref
                        p.type = p.type.addMod(MODconst);
                }
                p = (*fes.parameters)[1];
            }
            if (!p.type)
            {
                p.type = taa.next; // value type
                p.type = p.type.addStorageClass(p.storageClass);
            }
            break;
        }
    case Tclass:
        ad = (cast(TypeClass)tab).sym;
        goto Laggr;
    case Tstruct:
        ad = (cast(TypeStruct)tab).sym;
        goto Laggr;
    Laggr:
        if (fes.parameters.dim == 1)
        {
            if (!p.type)
            {
                /* Look for a front() or back() overload
                 */
                Identifier id = (fes.op == TOKforeach) ? Id.Ffront : Id.Fback;
                Dsymbol s = ad.search(Loc(), id);
                FuncDeclaration fd = s ? s.isFuncDeclaration() : null;
                if (fd)
                {
                    // Resolve inout qualifier of front type
                    p.type = fd.type.nextOf();
                    if (p.type)
                    {
                        p.type = p.type.substWildTo(tab.mod);
                        p.type = p.type.addStorageClass(p.storageClass);
                    }
                }
                else if (s && s.isTemplateDeclaration())
                {
                }
                else if (s && s.isDeclaration())
                    p.type = (cast(Declaration)s).type;
                else
                    break;
            }
            break;
        }
        break;
    case Tdelegate:
        {
            if (!inferApplyArgTypesY(cast(TypeFunction)tab.nextOf(), fes.parameters))
                return false;
            break;
        }
    default:
        break;
        // ignore error, caught later
    }
    return true;
}

extern (C++) static Dsymbol inferApplyArgTypesX(Expression ethis, FuncDeclaration fstart, Parameters* parameters)
{
    struct ParamOpOver
    {
        Parameters* parameters;
        MOD mod;
        MATCH match;
        FuncDeclaration fd_best;
        FuncDeclaration fd_ambig;

        extern (C++) static int fp(void* param, Dsymbol s)
        {
            FuncDeclaration f = s.isFuncDeclaration();
            if (!f)
                return 0;
            ParamOpOver* p = cast(ParamOpOver*)param;
            TypeFunction tf = cast(TypeFunction)f.type;
            MATCH m = MATCHexact;
            if (f.isThis())
            {
                if (!MODimplicitConv(p.mod, tf.mod))
                    m = MATCHnomatch;
                else if (p.mod != tf.mod)
                    m = MATCHconst;
            }
            if (!inferApplyArgTypesY(tf, p.parameters, 1))
                m = MATCHnomatch;
            if (m > p.match)
            {
                p.fd_best = f;
                p.fd_ambig = null;
                p.match = m;
            }
            else if (m == p.match)
                p.fd_ambig = f;
            return 0;
        }
    }

    ParamOpOver p;
    p.parameters = parameters;
    p.mod = ethis.type.mod;
    p.match = MATCHnomatch;
    p.fd_best = null;
    p.fd_ambig = null;
    overloadApply(fstart, &p, &ParamOpOver.fp);
    if (p.fd_best)
    {
        inferApplyArgTypesY(cast(TypeFunction)p.fd_best.type, parameters);
        if (p.fd_ambig)
        {
            .error(ethis.loc, "%s.%s matches more than one declaration:\n%s:     %s\nand:\n%s:     %s", ethis.toChars(), fstart.ident.toChars(), p.fd_best.loc.toChars(), p.fd_best.type.toChars(), p.fd_ambig.loc.toChars(), p.fd_ambig.type.toChars());
            p.fd_best = null;
        }
    }
    return p.fd_best;
}

/******************************
 * Infer parameters from type of function.
 * Returns:
 *      1 match for this function
 *      0 no match for this function
 */
extern (C++) static int inferApplyArgTypesY(TypeFunction tf, Parameters* parameters, int flags = 0)
{
    size_t nparams;
    Parameter p;
    if (Parameter.dim(tf.parameters) != 1)
        goto Lnomatch;
    p = Parameter.getNth(tf.parameters, 0);
    if (p.type.ty != Tdelegate)
        goto Lnomatch;
    tf = cast(TypeFunction)p.type.nextOf();
    assert(tf.ty == Tfunction);
    /* We now have tf, the type of the delegate. Match it against
     * the parameters, filling in missing parameter types.
     */
    nparams = Parameter.dim(tf.parameters);
    if (nparams == 0 || tf.varargs)
        goto Lnomatch;
    // not enough parameters
    if (parameters.dim != nparams)
        goto Lnomatch;
    // not enough parameters
    for (size_t u = 0; u < nparams; u++)
    {
        p = (*parameters)[u];
        Parameter param = Parameter.getNth(tf.parameters, u);
        if (p.type)
        {
            if (!p.type.equals(param.type))
                goto Lnomatch;
        }
        else if (!flags)
        {
            p.type = param.type;
            p.type = p.type.addStorageClass(p.storageClass);
        }
    }
    return 1;
Lnomatch:
    return 0;
}
