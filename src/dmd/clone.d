/**
 * Define the implicit `opEquals`, `opAssign`, post blit, copy constructor and destructor for structs.
 *
 * Copyright:   Copyright (C) 1999-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/clone.d, _clone.d)
 * Documentation:  https://dlang.org/phobos/dmd_clone.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/clone.d
 */

module dmd.clone;

import core.stdc.stdio;
import dmd.aggregate;
import dmd.arraytypes;
import dmd.dclass;
import dmd.declaration;
import dmd.dscope;
import dmd.dstruct;
import dmd.dsymbol;
import dmd.dsymbolsem;
import dmd.dtemplate;
import dmd.expression;
import dmd.expressionsem;
import dmd.func;
import dmd.globals;
import dmd.id;
import dmd.identifier;
import dmd.init;
import dmd.mtype;
import dmd.opover;
import dmd.semantic2;
import dmd.statement;
import dmd.target;
import dmd.typesem;
import dmd.tokens;

/*******************************************
 * Merge function attributes pure, nothrow, @safe, @nogc, and @disable
 * from f into s1.
 * Params:
 *      s1 = storage class to merge into
 *      f = function
 * Returns:
 *      merged storage class
 */
StorageClass mergeFuncAttrs(StorageClass s1, const FuncDeclaration f) pure
{
    if (!f)
        return s1;
    StorageClass s2 = (f.storage_class & STC.disable);

    TypeFunction tf = cast(TypeFunction)f.type;
    if (tf.trust == TRUST.safe)
        s2 |= STC.safe;
    else if (tf.trust == TRUST.system)
        s2 |= STC.system;
    else if (tf.trust == TRUST.trusted)
        s2 |= STC.trusted;

    if (tf.purity != PURE.impure)
        s2 |= STC.pure_;
    if (tf.isnothrow)
        s2 |= STC.nothrow_;
    if (tf.isnogc)
        s2 |= STC.nogc;

    const sa = s1 & s2;
    const so = s1 | s2;

    StorageClass stc = (sa & (STC.pure_ | STC.nothrow_ | STC.nogc)) | (so & STC.disable);

    if (so & STC.system)
        stc |= STC.system;
    else if (sa & STC.trusted)
        stc |= STC.trusted;
    else if ((so & (STC.trusted | STC.safe)) == (STC.trusted | STC.safe))
        stc |= STC.trusted;
    else if (sa & STC.safe)
        stc |= STC.safe;

    return stc;
}

/*******************************************
 * Check given aggregate actually has an identity opAssign or not.
 * Params:
 *      ad = struct or class
 *      sc = current scope
 * Returns:
 *      if found, returns FuncDeclaration of opAssign, otherwise null
 */
FuncDeclaration hasIdentityOpAssign(AggregateDeclaration ad, Scope* sc)
{
    Dsymbol assign = search_function(ad, Id.assign);
    if (assign)
    {
        /* check identity opAssign exists
         */
        scope er = new NullExp(ad.loc, ad.type);    // dummy rvalue
        scope el = new IdentifierExp(ad.loc, Id.p); // dummy lvalue
        el.type = ad.type;
        Expressions a;
        a.setDim(1);
        const errors = global.startGagging(); // Do not report errors, even if the template opAssign fbody makes it.
        sc = sc.push();
        sc.tinst = null;
        sc.minst = null;

        a[0] = er;
        auto f = resolveFuncCall(ad.loc, sc, assign, null, ad.type, &a, FuncResolveFlag.quiet);
        if (!f)
        {
            a[0] = el;
            f = resolveFuncCall(ad.loc, sc, assign, null, ad.type, &a, FuncResolveFlag.quiet);
        }

        sc = sc.pop();
        global.endGagging(errors);
        if (f)
        {
            if (f.errors)
                return null;
            auto fparams = f.getParameterList();
            if (fparams.length)
            {
                auto fparam0 = fparams[0];
                if (fparam0.type.toDsymbol(null) != ad)
                    f = null;
            }
        }
        // BUGS: This detection mechanism cannot find some opAssign-s like follows:
        // struct S { void opAssign(ref immutable S) const; }
        return f;
    }
    return null;
}

/*******************************************
 * We need an opAssign for the struct if
 * it has a destructor or a postblit.
 * We need to generate one if a user-specified one does not exist.
 */
private bool needOpAssign(StructDeclaration sd)
{
    //printf("StructDeclaration::needOpAssign() %s\n", sd.toChars());

    static bool isNeeded()
    {
        //printf("\tneed\n");
        return true;
    }

    if (sd.isUnionDeclaration())
        return !isNeeded();

    if (sd.hasIdentityAssign || // because has identity==elaborate opAssign
        sd.dtor ||
        sd.postblit)
        return isNeeded();

    /* If any of the fields need an opAssign, then we
     * need it too.
     */
    foreach (v; sd.fields)
    {
        if (v.storage_class & STC.ref_)
            continue;
        if (v.overlapped)               // if field of a union
            continue;                   // user must handle it themselves
        Type tv = v.type.baseElemOf();
        if (tv.ty == Tstruct)
        {
            TypeStruct ts = cast(TypeStruct)tv;
            if (ts.sym.isUnionDeclaration())
                continue;
            if (needOpAssign(ts.sym))
                return isNeeded();
        }
    }
    return !isNeeded();
}

/******************************************
 * Build opAssign for a `struct`.
 *
 * The generated `opAssign` function has the following signature:
 *---
 *ref S opAssign(S s)    // S is the name of the `struct`
 *---
 *
 * The opAssign function will be built for a struct `S` if the
 * following constraints are met:
 *
 * 1. `S` does not have an identity `opAssign` defined.
 *
 * 2. `S` has at least one of the following members: a postblit (user-defined or
 * generated for fields that have a defined postblit), a destructor
 * (user-defined or generated for fields that have a defined destructor)
 * or at least one field that has a defined `opAssign`.
 *
 * 3. `S` does not have any non-mutable fields.
 *
 * If `S` has a disabled destructor or at least one field that has a disabled
 * `opAssign`, `S.opAssign` is going to be generated, but marked with `@disable`
 *
 * If `S` defines a destructor, the generated code for `opAssign` is:
 *
 *---
 *S __swap = void;
 *__swap = this;   // bit copy
 *this = s;        // bit copy
 *__swap.dtor();
 *---
 *
 * Otherwise, if `S` defines a postblit, the generated code for `opAssign` is:
 *
 *---
 *this = s;
 *---
 *
 * Note that the parameter to the generated `opAssign` is passed by value, which means
 * that the postblit is going to be called (if it is defined) in both  of the above
 * situations before entering the body of `opAssign`. The assignments in the above generated
 * function bodies are blit expressions, so they can be regarded as `memcpy`s
 * (`opAssign` is not called as this will result in an infinite recursion; the postblit
 * is not called because it has already been called when the parameter was passed by value).
 *
 * If `S` does not have a postblit or a destructor, but contains at least one field that defines
 * an `opAssign` function (which is not disabled), then the body will make member-wise
 * assignments:
 *
 *---
 *this.field1 = s.field1;
 *this.field2 = s.field2;
 *...;
 *---
 *
 * In this situation, the assignemnts are actual assign expressions (`opAssign` is used
 * if defined).
 *
 * References:
 *      https://dlang.org/spec/struct.html#assign-overload
 * Params:
 *      sd = struct to generate opAssign for
 *      sc = context
 * Returns:
 *      generated `opAssign` function
 */
FuncDeclaration buildOpAssign(StructDeclaration sd, Scope* sc)
{
    if (FuncDeclaration f = hasIdentityOpAssign(sd, sc))
    {
        sd.hasIdentityAssign = true;
        return f;
    }
    // Even if non-identity opAssign is defined, built-in identity opAssign
    // will be defined.
    if (!needOpAssign(sd))
        return null;

    //printf("StructDeclaration::buildOpAssign() %s\n", sd.toChars());
    StorageClass stc = STC.safe | STC.nothrow_ | STC.pure_ | STC.nogc;
    Loc declLoc = sd.loc;
    Loc loc; // internal code should have no loc to prevent coverage

    // One of our sub-field might have `@disable opAssign` so we need to
    // check for it.
    // In this event, it will be reflected by having `stc` (opAssign's
    // storage class) include `STC.disabled`.
    foreach (v; sd.fields)
    {
        if (v.storage_class & STC.ref_)
            continue;
        if (v.overlapped)
            continue;
        Type tv = v.type.baseElemOf();
        if (tv.ty != Tstruct)
            continue;
        StructDeclaration sdv = (cast(TypeStruct)tv).sym;
        stc = mergeFuncAttrs(stc, hasIdentityOpAssign(sdv, sc));
    }

    if (sd.dtor || sd.postblit)
    {
        // if the type is not assignable, we cannot generate opAssign
        if (!sd.type.isAssignable()) // https://issues.dlang.org/show_bug.cgi?id=13044
            return null;
        stc = mergeFuncAttrs(stc, sd.dtor);
        if (stc & STC.safe)
            stc = (stc & ~STC.safe) | STC.trusted;
    }

    auto fparams = new Parameters();
    fparams.push(new Parameter(STC.nodtor, sd.type, Id.p, null, null));
    auto tf = new TypeFunction(ParameterList(fparams), sd.handleType(), LINK.d, stc | STC.ref_);
    auto fop = new FuncDeclaration(declLoc, Loc.initial, Id.assign, stc, tf);
    fop.storage_class |= STC.inference;
    fop.generated = true;
    Expression e;
    if (stc & STC.disable)
    {
        e = null;
    }
    /* Do swap this and rhs.
     *    __swap = this; this = s; __swap.dtor();
     */
    else if (sd.dtor)
    {
        //printf("\tswap copy\n");
        TypeFunction tdtor = cast(TypeFunction)sd.dtor.type;
        assert(tdtor.ty == Tfunction);

        auto idswap = Identifier.generateId("__swap");
        auto swap = new VarDeclaration(loc, sd.type, idswap, new VoidInitializer(loc));
        swap.storage_class |= STC.nodtor | STC.temp | STC.ctfe;
        if (tdtor.isScopeQual)
            swap.storage_class |= STC.scope_;
        auto e1 = new DeclarationExp(loc, swap);

        auto e2 = new BlitExp(loc, new VarExp(loc, swap), new ThisExp(loc));
        auto e3 = new BlitExp(loc, new ThisExp(loc), new IdentifierExp(loc, Id.p));

        /* Instead of running the destructor on s, run it
         * on swap. This avoids needing to copy swap back in to s.
         */
        auto e4 = new CallExp(loc, new DotVarExp(loc, new VarExp(loc, swap), sd.dtor, false));

        e = Expression.combine(e1, e2, e3, e4);
    }
    /* postblit was called when the value was passed to opAssign, we just need to blit the result */
    else if (sd.postblit)
    {
        e = new BlitExp(loc, new ThisExp(loc), new IdentifierExp(loc, Id.p));
        sd.hasBlitAssign = true;
    }
    else
    {
        /* Do memberwise copy.
         *
         * If sd is a nested struct, its vthis field assignment is:
         * 1. If it's nested in a class, it's a rebind of class reference.
         * 2. If it's nested in a function or struct, it's an update of void*.
         * In both cases, it will change the parent context.
         */
        //printf("\tmemberwise copy\n");
        e = null;
        foreach (v; sd.fields)
        {
            // this.v = s.v;
            auto ec = new AssignExp(loc,
                new DotVarExp(loc, new ThisExp(loc), v),
                new DotVarExp(loc, new IdentifierExp(loc, Id.p), v));
            e = Expression.combine(e, ec);
        }
    }
    if (e)
    {
        Statement s1 = new ExpStatement(loc, e);
        /* Add:
         *   return this;
         */
        auto er = new ThisExp(loc);
        Statement s2 = new ReturnStatement(loc, er);
        fop.fbody = new CompoundStatement(loc, s1, s2);
        tf.isreturn = true;
    }
    sd.members.push(fop);
    fop.addMember(sc, sd);
    sd.hasIdentityAssign = true; // temporary mark identity assignable
    const errors = global.startGagging(); // Do not report errors, even if the template opAssign fbody makes it.
    Scope* sc2 = sc.push();
    sc2.stc = 0;
    sc2.linkage = LINK.d;
    fop.dsymbolSemantic(sc2);
    fop.semantic2(sc2);
    // https://issues.dlang.org/show_bug.cgi?id=15044
    //semantic3(fop, sc2); // isn't run here for lazy forward reference resolution.

    sc2.pop();
    if (global.endGagging(errors)) // if errors happened
    {
        // Disable generated opAssign, because some members forbid identity assignment.
        fop.storage_class |= STC.disable;
        fop.fbody = null; // remove fbody which contains the error
    }

    //printf("-StructDeclaration::buildOpAssign() %s, errors = %d\n", sd.toChars(), (fop.storage_class & STC.disable) != 0);
    //printf("fop.type: %s\n", fop.type.toPrettyChars());
    return fop;
}

/*******************************************
 * We need an opEquals for the struct if
 * any fields has an opEquals.
 * Generate one if a user-specified one does not exist.
 */
bool needOpEquals(StructDeclaration sd)
{
    //printf("StructDeclaration::needOpEquals() %s\n", sd.toChars());
    if (sd.isUnionDeclaration())
        goto Ldontneed;
    if (sd.hasIdentityEquals)
        goto Lneed;
    /* If any of the fields has an opEquals, then we
     * need it too.
     */
    for (size_t i = 0; i < sd.fields.dim; i++)
    {
        VarDeclaration v = sd.fields[i];
        if (v.storage_class & STC.ref_)
            continue;
        if (v.overlapped)
            continue;
        Type tv = v.type.toBasetype();
        auto tvbase = tv.baseElemOf();
        if (tvbase.ty == Tstruct)
        {
            TypeStruct ts = cast(TypeStruct)tvbase;
            if (ts.sym.isUnionDeclaration())
                continue;
            if (needOpEquals(ts.sym))
                goto Lneed;
            if (ts.sym.aliasthis) // https://issues.dlang.org/show_bug.cgi?id=14806
                goto Lneed;
        }
        if (tvbase.isfloating())
        {
            // This is necessray for:
            //  1. comparison of +0.0 and -0.0 should be true.
            //  2. comparison of NANs should be false always.
            goto Lneed;
        }
        if (tvbase.ty == Tarray)
            goto Lneed;
        if (tvbase.ty == Taarray)
            goto Lneed;
        if (tvbase.ty == Tclass)
            goto Lneed;
    }
Ldontneed:
    //printf("\tdontneed\n");
    return false;
Lneed:
    //printf("\tneed\n");
    return true;
}

/*******************************************
 * Check given aggregate actually has an identity opEquals or not.
 */
private FuncDeclaration hasIdentityOpEquals(AggregateDeclaration ad, Scope* sc)
{
    FuncDeclaration f;
    if (Dsymbol eq = search_function(ad, Id.eq))
    {
        /* check identity opEquals exists
         */
        scope er = new NullExp(ad.loc, null); // dummy rvalue
        scope el = new IdentifierExp(ad.loc, Id.p); // dummy lvalue
        Expressions a;
        a.setDim(1);

        bool hasIt(Type tthis)
        {
            const errors = global.startGagging(); // Do not report errors, even if the template opAssign fbody makes it
            sc = sc.push();
            sc.tinst = null;
            sc.minst = null;

            FuncDeclaration rfc(Expression e)
            {
                a[0] = e;
                a[0].type = tthis;
                return resolveFuncCall(ad.loc, sc, eq, null, tthis, &a, FuncResolveFlag.quiet);
            }

            f = rfc(er);
            if (!f)
                f = rfc(el);

            sc = sc.pop();
            global.endGagging(errors);

            return f !is null;
        }

        if (hasIt(ad.type)               ||
            hasIt(ad.type.constOf())     ||
            hasIt(ad.type.immutableOf()) ||
            hasIt(ad.type.sharedOf())    ||
            hasIt(ad.type.sharedConstOf()))
        {
            if (f.errors)
                return null;
        }
    }
    return f;
}

/******************************************
 * Build opEquals for struct.
 *      const bool opEquals(const S s) { ... }
 *
 * By fixing https://issues.dlang.org/show_bug.cgi?id=3789
 * opEquals is changed to be never implicitly generated.
 * Now, struct objects comparison s1 == s2 is translated to:
 *      s1.tupleof == s2.tupleof
 * to calculate structural equality. See EqualExp.op_overload.
 */
FuncDeclaration buildOpEquals(StructDeclaration sd, Scope* sc)
{
    if (hasIdentityOpEquals(sd, sc))
    {
        sd.hasIdentityEquals = true;
    }
    return null;
}

/******************************************
 * Build __xopEquals for TypeInfo_Struct
 *      static bool __xopEquals(ref const S p, ref const S q)
 *      {
 *          return p == q;
 *      }
 *
 * This is called by TypeInfo.equals(p1, p2). If the struct does not support
 * const objects comparison, it will throw "not implemented" Error in runtime.
 */
FuncDeclaration buildXopEquals(StructDeclaration sd, Scope* sc)
{
    if (!needOpEquals(sd))
        return null; // bitwise comparison would work

    //printf("StructDeclaration::buildXopEquals() %s\n", sd.toChars());
    if (Dsymbol eq = search_function(sd, Id.eq))
    {
        if (FuncDeclaration fd = eq.isFuncDeclaration())
        {
            TypeFunction tfeqptr;
            {
                Scope scx;
                /* const bool opEquals(ref const S s);
                 */
                auto parameters = new Parameters();
                parameters.push(new Parameter(STC.ref_ | STC.const_, sd.type, null, null, null));
                tfeqptr = new TypeFunction(ParameterList(parameters), Type.tbool, LINK.d);
                tfeqptr.mod = MODFlags.const_;
                tfeqptr = cast(TypeFunction)tfeqptr.typeSemantic(Loc.initial, &scx);
            }
            fd = fd.overloadExactMatch(tfeqptr);
            if (fd)
                return fd;
        }
    }
    if (!sd.xerreq)
    {
        // object._xopEquals
        Identifier id = Identifier.idPool("_xopEquals");
        Expression e = new IdentifierExp(sd.loc, Id.empty);
        e = new DotIdExp(sd.loc, e, Id.object);
        e = new DotIdExp(sd.loc, e, id);
        e = e.expressionSemantic(sc);
        Dsymbol s = getDsymbol(e);
        assert(s);
        sd.xerreq = s.isFuncDeclaration();
    }
    Loc declLoc; // loc is unnecessary so __xopEquals is never called directly
    Loc loc; // loc is unnecessary so errors are gagged
    auto parameters = new Parameters();
    parameters.push(new Parameter(STC.ref_ | STC.const_, sd.type, Id.p, null, null))
              .push(new Parameter(STC.ref_ | STC.const_, sd.type, Id.q, null, null));
    auto tf = new TypeFunction(ParameterList(parameters), Type.tbool, LINK.d);
    Identifier id = Id.xopEquals;
    auto fop = new FuncDeclaration(declLoc, Loc.initial, id, STC.static_, tf);
    fop.generated = true;
    Expression e1 = new IdentifierExp(loc, Id.p);
    Expression e2 = new IdentifierExp(loc, Id.q);
    Expression e = new EqualExp(TOK.equal, loc, e1, e2);
    fop.fbody = new ReturnStatement(loc, e);
    uint errors = global.startGagging(); // Do not report errors
    Scope* sc2 = sc.push();
    sc2.stc = 0;
    sc2.linkage = LINK.d;
    fop.dsymbolSemantic(sc2);
    fop.semantic2(sc2);
    sc2.pop();
    if (global.endGagging(errors)) // if errors happened
        fop = sd.xerreq;
    return fop;
}

/******************************************
 * Build __xopCmp for TypeInfo_Struct
 *      static bool __xopCmp(ref const S p, ref const S q)
 *      {
 *          return p.opCmp(q);
 *      }
 *
 * This is called by TypeInfo.compare(p1, p2). If the struct does not support
 * const objects comparison, it will throw "not implemented" Error in runtime.
 */
FuncDeclaration buildXopCmp(StructDeclaration sd, Scope* sc)
{
    //printf("StructDeclaration::buildXopCmp() %s\n", toChars());
    if (Dsymbol cmp = search_function(sd, Id.cmp))
    {
        if (FuncDeclaration fd = cmp.isFuncDeclaration())
        {
            TypeFunction tfcmpptr;
            {
                Scope scx;
                /* const int opCmp(ref const S s);
                 */
                auto parameters = new Parameters();
                parameters.push(new Parameter(STC.ref_ | STC.const_, sd.type, null, null, null));
                tfcmpptr = new TypeFunction(ParameterList(parameters), Type.tint32, LINK.d);
                tfcmpptr.mod = MODFlags.const_;
                tfcmpptr = cast(TypeFunction)tfcmpptr.typeSemantic(Loc.initial, &scx);
            }
            fd = fd.overloadExactMatch(tfcmpptr);
            if (fd)
                return fd;
        }
    }
    else
    {
        version (none) // FIXME: doesn't work for recursive alias this
        {
            /* Check opCmp member exists.
             * Consider 'alias this', but except opDispatch.
             */
            Expression e = new DsymbolExp(sd.loc, sd);
            e = new DotIdExp(sd.loc, e, Id.cmp);
            Scope* sc2 = sc.push();
            e = e.trySemantic(sc2);
            sc2.pop();
            if (e)
            {
                Dsymbol s = null;
                switch (e.op)
                {
                case TOK.overloadSet:
                    s = (cast(OverExp)e).vars;
                    break;
                case TOK.scope_:
                    s = (cast(ScopeExp)e).sds;
                    break;
                case TOK.variable:
                    s = (cast(VarExp)e).var;
                    break;
                default:
                    break;
                }
                if (!s || s.ident != Id.cmp)
                    e = null; // there's no valid member 'opCmp'
            }
            if (!e)
                return null; // bitwise comparison would work
            /* Essentially, a struct which does not define opCmp is not comparable.
             * At this time, typeid(S).compare might be correct that throwing "not implement" Error.
             * But implementing it would break existing code, such as:
             *
             * struct S { int value; }  // no opCmp
             * int[S] aa;   // Currently AA key uses bitwise comparison
             *              // (It's default behavior of TypeInfo_Strust.compare).
             *
             * Not sure we should fix this inconsistency, so just keep current behavior.
             */
        }
        else
        {
            return null;
        }
    }
    if (!sd.xerrcmp)
    {
        // object._xopCmp
        Identifier id = Identifier.idPool("_xopCmp");
        Expression e = new IdentifierExp(sd.loc, Id.empty);
        e = new DotIdExp(sd.loc, e, Id.object);
        e = new DotIdExp(sd.loc, e, id);
        e = e.expressionSemantic(sc);
        Dsymbol s = getDsymbol(e);
        assert(s);
        sd.xerrcmp = s.isFuncDeclaration();
    }
    Loc declLoc; // loc is unnecessary so __xopCmp is never called directly
    Loc loc; // loc is unnecessary so errors are gagged
    auto parameters = new Parameters();
    parameters.push(new Parameter(STC.ref_ | STC.const_, sd.type, Id.p, null, null));
    parameters.push(new Parameter(STC.ref_ | STC.const_, sd.type, Id.q, null, null));
    auto tf = new TypeFunction(ParameterList(parameters), Type.tint32, LINK.d);
    Identifier id = Id.xopCmp;
    auto fop = new FuncDeclaration(declLoc, Loc.initial, id, STC.static_, tf);
    fop.generated = true;
    Expression e1 = new IdentifierExp(loc, Id.p);
    Expression e2 = new IdentifierExp(loc, Id.q);
    Expression e = new CallExp(loc, new DotIdExp(loc, e2, Id.cmp), e1);
    fop.fbody = new ReturnStatement(loc, e);
    uint errors = global.startGagging(); // Do not report errors
    Scope* sc2 = sc.push();
    sc2.stc = 0;
    sc2.linkage = LINK.d;
    fop.dsymbolSemantic(sc2);
    fop.semantic2(sc2);
    sc2.pop();
    if (global.endGagging(errors)) // if errors happened
        fop = sd.xerrcmp;
    return fop;
}

/*******************************************
 * We need a toHash for the struct if
 * any fields has a toHash.
 * Generate one if a user-specified one does not exist.
 */
private bool needToHash(StructDeclaration sd)
{
    //printf("StructDeclaration::needToHash() %s\n", sd.toChars());
    if (sd.isUnionDeclaration())
        goto Ldontneed;
    if (sd.xhash)
        goto Lneed;

    /* If any of the fields has an opEquals, then we
     * need it too.
     */
    for (size_t i = 0; i < sd.fields.dim; i++)
    {
        VarDeclaration v = sd.fields[i];
        if (v.storage_class & STC.ref_)
            continue;
        if (v.overlapped)
            continue;
        Type tv = v.type.toBasetype();
        auto tvbase = tv.baseElemOf();
        if (tvbase.ty == Tstruct)
        {
            TypeStruct ts = cast(TypeStruct)tvbase;
            if (ts.sym.isUnionDeclaration())
                continue;
            if (needToHash(ts.sym))
                goto Lneed;
            if (ts.sym.aliasthis) // https://issues.dlang.org/show_bug.cgi?id=14948
                goto Lneed;
        }
        if (tvbase.isfloating())
        {
            /* This is necessary because comparison of +0.0 and -0.0 should be true,
             * i.e. not a bit compare.
             */
            goto Lneed;
        }
        if (tvbase.ty == Tarray)
            goto Lneed;
        if (tvbase.ty == Taarray)
            goto Lneed;
        if (tvbase.ty == Tclass)
            goto Lneed;
    }
Ldontneed:
    //printf("\tdontneed\n");
    return false;
Lneed:
    //printf("\tneed\n");
    return true;
}

/******************************************
 * Build __xtoHash for non-bitwise hashing
 *      static hash_t xtoHash(ref const S p) nothrow @trusted;
 */
FuncDeclaration buildXtoHash(StructDeclaration sd, Scope* sc)
{
    if (Dsymbol s = search_function(sd, Id.tohash))
    {
        __gshared TypeFunction tftohash;
        if (!tftohash)
        {
            tftohash = new TypeFunction(ParameterList(), Type.thash_t, LINK.d);
            tftohash.mod = MODFlags.const_;
            tftohash = cast(TypeFunction)tftohash.merge();
        }
        if (FuncDeclaration fd = s.isFuncDeclaration())
        {
            fd = fd.overloadExactMatch(tftohash);
            if (fd)
                return fd;
        }
    }
    if (!needToHash(sd))
        return null;

    //printf("StructDeclaration::buildXtoHash() %s\n", sd.toPrettyChars());
    Loc declLoc; // loc is unnecessary so __xtoHash is never called directly
    Loc loc; // internal code should have no loc to prevent coverage
    auto parameters = new Parameters();
    parameters.push(new Parameter(STC.ref_ | STC.const_, sd.type, Id.p, null, null));
    auto tf = new TypeFunction(ParameterList(parameters), Type.thash_t, LINK.d, STC.nothrow_ | STC.trusted);
    Identifier id = Id.xtoHash;
    auto fop = new FuncDeclaration(declLoc, Loc.initial, id, STC.static_, tf);
    fop.generated = true;

    /* Do memberwise hashing.
     *
     * If sd is a nested struct, and if it's nested in a class, the calculated
     * hash value will also contain the result of parent class's toHash().
     */
    const(char)[] code =
        ".object.size_t h = 0;" ~
        "foreach (i, T; typeof(p.tupleof))" ~
        // workaround https://issues.dlang.org/show_bug.cgi?id=17968
        "    static if(is(T* : const(.object.Object)*)) " ~
        "        h = h * 33 + typeid(const(.object.Object)).getHash(cast(const void*)&p.tupleof[i]);" ~
        "    else " ~
        "        h = h * 33 + typeid(T).getHash(cast(const void*)&p.tupleof[i]);" ~
        "return h;";
    fop.fbody = new CompileStatement(loc, new StringExp(loc, code));
    Scope* sc2 = sc.push();
    sc2.stc = 0;
    sc2.linkage = LINK.d;
    fop.dsymbolSemantic(sc2);
    fop.semantic2(sc2);
    sc2.pop();

    //printf("%s fop = %s %s\n", sd.toChars(), fop.toChars(), fop.type.toChars());
    return fop;
}

/*****************************************
 * Create inclusive destructor for struct/class by aggregating
 * all the destructors in dtors[] with the destructors for
 * all the members.
 * Params:
 *      ad = struct or class to build destructor for
 *      sc = context
 * Returns:
 *      generated function, null if none needed
 * Note:
 * Close similarity with StructDeclaration::buildPostBlit(),
 * and the ordering changes (runs backward instead of forwards).
 */
DtorDeclaration buildDtor(AggregateDeclaration ad, Scope* sc)
{
    //printf("AggregateDeclaration::buildDtor() %s\n", ad.toChars());
    if (ad.isUnionDeclaration())
        return null;                    // unions don't have destructors

    StorageClass stc = STC.safe | STC.nothrow_ | STC.pure_ | STC.nogc;
    Loc declLoc = ad.dtors.dim ? ad.dtors[0].loc : ad.loc;
    Loc loc; // internal code should have no loc to prevent coverage
    FuncDeclaration xdtor_fwd = null;

    // if the dtor is an extern(C++) prototype, then we expect it performs a full-destruction; we don't need to build a full-dtor
    const bool dtorIsCppPrototype = ad.dtors.dim == 1 && ad.dtors[0].linkage == LINK.cpp && !ad.dtors[0].fbody;
    if (!dtorIsCppPrototype)
    {
        Expression e = null;
        for (size_t i = 0; i < ad.fields.dim; i++)
        {
            auto v = ad.fields[i];
            if (v.storage_class & STC.ref_)
                continue;
            if (v.overlapped)
                continue;
            auto tv = v.type.baseElemOf();
            if (tv.ty != Tstruct)
                continue;
            auto sdv = (cast(TypeStruct)tv).sym;
            if (!sdv.dtor)
                continue;

            // fix: https://issues.dlang.org/show_bug.cgi?id=17257
            // braces for shrink wrapping scope of a
            {
                xdtor_fwd = sdv.dtor; // this dtor is temporary it could be anything
                auto a = new AliasDeclaration(Loc.initial, Id.__xdtor, xdtor_fwd);
                a.addMember(sc, ad); // temporarily add to symbol table
            }

            sdv.dtor.functionSemantic();

            stc = mergeFuncAttrs(stc, sdv.dtor);
            if (stc & STC.disable)
            {
                e = null;
                break;
            }

            Expression ex;
            tv = v.type.toBasetype();
            if (tv.ty == Tstruct)
            {
                // this.v.__xdtor()

                ex = new ThisExp(loc);
                ex = new DotVarExp(loc, ex, v);

                // This is a hack so we can call destructors on const/immutable objects.
                // Do it as a type 'paint'.
                ex = new CastExp(loc, ex, v.type.mutableOf());
                if (stc & STC.safe)
                    stc = (stc & ~STC.safe) | STC.trusted;

                ex = new DotVarExp(loc, ex, sdv.dtor, false);
                ex = new CallExp(loc, ex);
            }
            else
            {
                // __ArrayDtor((cast(S*)this.v.ptr)[0 .. n])

                const n = tv.numberOfElems(loc);
                if (n == 0)
                    continue;

                ex = new ThisExp(loc);
                ex = new DotVarExp(loc, ex, v);

                // This is a hack so we can call destructors on const/immutable objects.
                ex = new DotIdExp(loc, ex, Id.ptr);
                ex = new CastExp(loc, ex, sdv.type.pointerTo());
                if (stc & STC.safe)
                    stc = (stc & ~STC.safe) | STC.trusted;

                ex = new SliceExp(loc, ex, new IntegerExp(loc, 0, Type.tsize_t),
                                           new IntegerExp(loc, n, Type.tsize_t));
                // Prevent redundant bounds check
                (cast(SliceExp)ex).upperIsInBounds = true;
                (cast(SliceExp)ex).lowerIsLessThanUpper = true;

                ex = new CallExp(loc, new IdentifierExp(loc, Id.__ArrayDtor), ex);
            }
            e = Expression.combine(ex, e); // combine in reverse order
        }

        /* extern(C++) destructors call into super to destruct the full hierarchy
        */
        ClassDeclaration cldec = ad.isClassDeclaration();
        if (cldec && cldec.classKind == ClassKind.cpp && cldec.baseClass && cldec.baseClass.primaryDtor)
        {
            // WAIT BUT: do I need to run `cldec.baseClass.dtor` semantic? would it have been run before?
            cldec.baseClass.dtor.functionSemantic();

            stc = mergeFuncAttrs(stc, cldec.baseClass.primaryDtor);
            if (!(stc & STC.disable))
            {
                // super.__xdtor()

                Expression ex = new SuperExp(loc);

                // This is a hack so we can call destructors on const/immutable objects.
                // Do it as a type 'paint'.
                ex = new CastExp(loc, ex, cldec.baseClass.type.mutableOf());
                if (stc & STC.safe)
                    stc = (stc & ~STC.safe) | STC.trusted;

                ex = new DotVarExp(loc, ex, cldec.baseClass.primaryDtor, false);
                ex = new CallExp(loc, ex);

                e = Expression.combine(e, ex); // super dtor last
            }
        }

        /* Build our own "destructor" which executes e
         */
        if (e || (stc & STC.disable))
        {
            //printf("Building __fieldDtor(), %s\n", e.toChars());
            auto dd = new DtorDeclaration(declLoc, Loc.initial, stc, Id.__fieldDtor);
            dd.generated = true;
            dd.storage_class |= STC.inference;
            dd.fbody = new ExpStatement(loc, e);
            ad.dtors.shift(dd);
            ad.members.push(dd);
            dd.dsymbolSemantic(sc);
            ad.fieldDtor = dd;
        }
    }

    DtorDeclaration xdtor = null;
    switch (ad.dtors.dim)
    {
    case 0:
        break;

    case 1:
        xdtor = ad.dtors[0];
        break;

    default:
        assert(!dtorIsCppPrototype);
        Expression e = null;
        e = null;
        stc = STC.safe | STC.nothrow_ | STC.pure_ | STC.nogc;
        for (size_t i = 0; i < ad.dtors.dim; i++)
        {
            FuncDeclaration fd = ad.dtors[i];
            stc = mergeFuncAttrs(stc, fd);
            if (stc & STC.disable)
            {
                e = null;
                break;
            }
            Expression ex = new ThisExp(loc);
            ex = new DotVarExp(loc, ex, fd, false);
            ex = new CallExp(loc, ex);
            e = Expression.combine(ex, e);
        }
        auto dd = new DtorDeclaration(declLoc, Loc.initial, stc, Id.__aggrDtor);
        dd.generated = true;
        dd.storage_class |= STC.inference;
        dd.fbody = new ExpStatement(loc, e);
        ad.members.push(dd);
        dd.dsymbolSemantic(sc);
        xdtor = dd;
        break;
    }

    ad.primaryDtor = xdtor;

    if (xdtor && xdtor.linkage == LINK.cpp && !target.cpp.twoDtorInVtable)
        xdtor = buildWindowsCppDtor(ad, xdtor, sc);

    // Add an __xdtor alias to make the inclusive dtor accessible
    if (xdtor)
    {
        auto _alias = new AliasDeclaration(Loc.initial, Id.__xdtor, xdtor);
        _alias.dsymbolSemantic(sc);
        ad.members.push(_alias);
        if (xdtor_fwd)
            ad.symtab.update(_alias); // update forward dtor to correct one
        else
            _alias.addMember(sc, ad); // add to symbol table
    }

    return xdtor;
}

/**
 * build a shim function around the compound dtor that accepts an argument
 *  that is used to implement the deleting C++ destructor
 *
 * Params:
 *  ad = the aggregate that contains the destructor to wrap
 *  dtor = the destructor to wrap
 *  sc = the scope in which to analyze the new function
 *
 * Returns:
 *  the shim destructor, semantically analyzed and added to the class as a member
 */
private DtorDeclaration buildWindowsCppDtor(AggregateDeclaration ad, DtorDeclaration dtor, Scope* sc)
{
    auto cldec = ad.isClassDeclaration();
    if (!cldec || cldec.cppDtorVtblIndex == -1) // scalar deleting dtor not built for non-virtual dtors
        return dtor;

    // generate deleting C++ destructor corresponding to:
    // void* C::~C(int del)
    // {
    //   this->~C();
    //   // TODO: if (del) delete (char*)this;
    //   return (void*) this;
    // }
    Parameter delparam = new Parameter(STC.undefined_, Type.tuns32, Identifier.idPool("del"), new IntegerExp(dtor.loc, 0, Type.tuns32), null);
    Parameters* params = new Parameters;
    params.push(delparam);
    auto ftype = new TypeFunction(ParameterList(params), Type.tvoidptr, LINK.cpp, dtor.storage_class);
    auto func = new DtorDeclaration(dtor.loc, dtor.loc, dtor.storage_class, Id.cppdtor);
    func.type = ftype;
    if (dtor.fbody)
    {
        const loc = dtor.loc;
        auto stmts = new Statements;
        auto call = new CallExp(loc, dtor, null);
        call.directcall = true;
        stmts.push(new ExpStatement(loc, call));
        stmts.push(new ReturnStatement(loc, new CastExp(loc, new ThisExp(loc), Type.tvoidptr)));
        func.fbody = new CompoundStatement(loc, stmts);
        func.generated = true;
    }

    auto sc2 = sc.push();
    sc2.stc &= ~STC.static_; // not a static destructor
    sc2.linkage = LINK.cpp;

    ad.members.push(func);
    func.addMember(sc2, ad);
    func.dsymbolSemantic(sc2);

    sc2.pop();
    return func;
}

/**
 * build a shim function around the compound dtor that translates
 *  a C++ destructor to a destructor with extern(D) calling convention
 *
 * Params:
 *  ad = the aggregate that contains the destructor to wrap
 *  sc = the scope in which to analyze the new function
 *
 * Returns:
 *  the shim destructor, semantically analyzed and added to the class as a member
 */
DtorDeclaration buildExternDDtor(AggregateDeclaration ad, Scope* sc)
{
    auto dtor = ad.primaryDtor;
    if (!dtor)
        return null;

    // Generate shim only when ABI incompatible on target platform
    if (ad.classKind != ClassKind.cpp || !target.cpp.wrapDtorInExternD)
        return dtor;

    // generate member function that adjusts calling convention
    // (EAX used for 'this' instead of ECX on Windows/stack on others):
    // extern(D) void __ticppdtor()
    // {
    //     Class.__dtor();
    // }
    auto ftype = new TypeFunction(ParameterList(), Type.tvoid, LINK.d, dtor.storage_class);
    auto func = new DtorDeclaration(dtor.loc, dtor.loc, dtor.storage_class, Id.ticppdtor);
    func.type = ftype;

    auto call = new CallExp(dtor.loc, dtor, null);
    call.directcall = true;                   // non-virtual call Class.__dtor();
    func.fbody = new ExpStatement(dtor.loc, call);
    func.generated = true;
    func.storage_class |= STC.inference;

    auto sc2 = sc.push();
    sc2.stc &= ~STC.static_; // not a static destructor
    sc2.linkage = LINK.d;

    ad.members.push(func);
    func.addMember(sc2, ad);
    func.dsymbolSemantic(sc2);
    func.functionSemantic(); // to infer attributes

    sc2.pop();
    return func;
}

/******************************************
 * Create inclusive invariant for struct/class by aggregating
 * all the invariants in invs[].
 * ---
 * void __invariant() const [pure nothrow @trusted]
 * {
 *     invs[0](), invs[1](), ...;
 * }
 * ---
 */
FuncDeclaration buildInv(AggregateDeclaration ad, Scope* sc)
{
    switch (ad.invs.dim)
    {
    case 0:
        return null;

    case 1:
        // Don't return invs[0] so it has uniquely generated name.
        goto default;

    default:
        Expression e = null;
        StorageClass stcx = 0;
        StorageClass stc = STC.safe | STC.nothrow_ | STC.pure_ | STC.nogc;
        foreach (i, inv; ad.invs)
        {
            stc = mergeFuncAttrs(stc, inv);
            if (stc & STC.disable)
            {
                // What should do?
            }
            const stcy = (inv.storage_class & STC.synchronized_) |
                         (inv.type.mod & MODFlags.shared_ ? STC.shared_ : 0);
            if (i == 0)
                stcx = stcy;
            else if (stcx ^ stcy)
            {
                version (all)
                {
                    // currently rejects
                    ad.error(inv.loc, "mixing invariants with different `shared`/`synchronized` qualifiers is not supported");
                    e = null;
                    break;
                }
            }
            e = Expression.combine(e, new CallExp(Loc.initial, new VarExp(Loc.initial, inv, false)));
        }
        auto inv = new InvariantDeclaration(ad.loc, Loc.initial, stc | stcx,
                Id.classInvariant, new ExpStatement(Loc.initial, e));
        ad.members.push(inv);
        inv.dsymbolSemantic(sc);
        return inv;
    }
}
