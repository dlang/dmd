/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _expression.d)
 */

module ddmd.expressionsem;

import core.stdc.stdio;
import core.stdc.string;

import ddmd.access;
import ddmd.aggregate;
import ddmd.aliasthis;
import ddmd.argtypes;
import ddmd.arrayop;
import ddmd.arraytypes;
import ddmd.attrib;
import ddmd.astcodegen;
import ddmd.dscope;
import ddmd.dsymbol;
import ddmd.declaration;
import ddmd.dclass;
import ddmd.dcast;
import ddmd.delegatize;
import ddmd.denum;
import ddmd.dimport;
import ddmd.dmangle;
import ddmd.dmodule;
import ddmd.dstruct;
import ddmd.dtemplate;
import ddmd.errors;
import ddmd.escape;
import ddmd.expression;
import ddmd.func;
import ddmd.globals;
import ddmd.hdrgen;
import ddmd.id;
import ddmd.identifier;
import ddmd.imphint;
import ddmd.intrange;
import ddmd.mtype;
import ddmd.nspace;
import ddmd.opover;
import ddmd.optimize;
import ddmd.parse;
import ddmd.root.ctfloat;
import ddmd.root.file;
import ddmd.root.filename;
import ddmd.root.outbuffer;
import ddmd.root.rootobject;
import ddmd.sideeffect;
import ddmd.safe;
import ddmd.target;
import ddmd.tokens;
import ddmd.traits;
import ddmd.typinf;
import ddmd.utf;
import ddmd.utils;
import ddmd.visitor;

enum LOGSEMANTIC = false;

private extern (C++) final class ExpressionSemanticVisitor : Visitor
{
    alias visit = super.visit;

    Scope* sc;
    Expression result;

    this(Scope* sc)
    {
        this.sc = sc;
    }

    /**************************
     * Semantically analyze Expression.
     * Determine types, fold constants, etc.
     */
    override void visit(Expression e)
    {
        static if (LOGSEMANTIC)
        {
            printf("Expression::semantic() %s\n", e.toChars());
        }
        if (e.type)
            e.type = e.type.semantic(e.loc, sc);
        else
            e.type = Type.tvoid;
        result = e;
    }

    override void visit(IntegerExp e)
    {
        assert(e.type);
        if (e.type.ty == Terror)
        {
            result = new ErrorExp();
            return;
        }
        assert(e.type.deco);
        e.normalize();
        result = e;
    }

    override void visit(RealExp e)
    {
        if (!e.type)
            e.type = Type.tfloat64;
        else
            e.type = e.type.semantic(e.loc, sc);
        result = e;
    }

    override void visit(ComplexExp e)
    {
        if (!e.type)
            e.type = Type.tcomplex80;
        else
            e.type = e.type.semantic(e.loc, sc);
        result = e;
    }

    override void visit(IdentifierExp exp)
    {
        static if (LOGSEMANTIC)
        {
            printf("IdentifierExp::semantic('%s')\n", exp.ident.toChars());
        }
        if (exp.type) // This is used as the dummy expression
        {
            result = exp;
            return;
        }

        Dsymbol scopesym;
        Dsymbol s = sc.search(exp.loc, exp.ident, &scopesym);
        if (s)
        {
            if (s.errors)
            {
                result = new ErrorExp();
                return;
            }

            Expression e;

            /* See if the symbol was a member of an enclosing 'with'
             */
            WithScopeSymbol withsym = scopesym.isWithScopeSymbol();
            if (withsym && withsym.withstate.wthis)
            {
                /* Disallow shadowing
                 */
                // First find the scope of the with
                Scope* scwith = sc;
                while (scwith.scopesym != scopesym)
                {
                    scwith = scwith.enclosing;
                    assert(scwith);
                }
                // Look at enclosing scopes for symbols with the same name,
                // in the same function
                for (Scope* scx = scwith; scx && scx.func == scwith.func; scx = scx.enclosing)
                {
                    Dsymbol s2;
                    if (scx.scopesym && scx.scopesym.symtab && (s2 = scx.scopesym.symtab.lookup(s.ident)) !is null && s != s2)
                    {
                        exp.error("with symbol `%s` is shadowing local symbol `%s`", s.toPrettyChars(), s2.toPrettyChars());
                        result = new ErrorExp();
                        return;
                    }
                }
                s = s.toAlias();

                // Same as wthis.ident
                //  TODO: DotIdExp.semantic will find 'ident' from 'wthis' again.
                //  The redudancy should be removed.
                e = new VarExp(exp.loc, withsym.withstate.wthis);
                e = new DotIdExp(exp.loc, e, exp.ident);
                e = e.semantic(sc);
            }
            else
            {
                if (withsym)
                {
                    Declaration d = s.isDeclaration();
                    if (d)
                        checkAccess(exp.loc, sc, null, d);
                }

                /* If f is really a function template,
                 * then replace f with the function template declaration.
                 */
                FuncDeclaration f = s.isFuncDeclaration();
                if (f)
                {
                    TemplateDeclaration td = getFuncTemplateDecl(f);
                    if (td)
                    {
                        if (td.overroot) // if not start of overloaded list of TemplateDeclaration's
                            td = td.overroot; // then get the start
                        e = new TemplateExp(exp.loc, td, f);
                        e = e.semantic(sc);
                        result = e;
                        return;
                    }
                }
                // Haven't done overload resolution yet, so pass 1
                e = resolve(exp.loc, sc, s, true);
            }
            result = e;
            return;
        }

        if (hasThis(sc))
        {
            AggregateDeclaration ad = sc.getStructClassScope();
            if (ad && ad.aliasthis)
            {
                Expression e;
                e = new IdentifierExp(exp.loc, Id.This);
                e = new DotIdExp(exp.loc, e, ad.aliasthis.ident);
                e = new DotIdExp(exp.loc, e, exp.ident);
                e = e.trySemantic(sc);
                if (e)
                {
                    result = e;
                    return;
                }
            }
        }

        if (exp.ident == Id.ctfe)
        {
            if (sc.flags & SCOPEctfe)
            {
                exp.error("variable `__ctfe` cannot be read at compile time");
                result = new ErrorExp();
                return;
            }

            // Create the magic __ctfe bool variable
            auto vd = new VarDeclaration(exp.loc, Type.tbool, Id.ctfe, null);
            vd.storage_class |= STCtemp;
            vd.semanticRun = PASSsemanticdone;
            Expression e = new VarExp(exp.loc, vd);
            e = e.semantic(sc);
            result = e;
            return;
        }

        // If we've reached this point and are inside a with() scope then we may
        // try one last attempt by checking whether the 'wthis' object supports
        // dynamic dispatching via opDispatch.
        // This is done by rewriting this expression as wthis.ident.
        for (Scope* sc2 = sc; sc2; sc2 = sc2.enclosing)
        {
            if (!sc2.scopesym)
                continue;

            if (auto ss = sc2.scopesym.isWithScopeSymbol())
            {
                if (ss.withstate.wthis)
                {
                    Expression e;
                    e = new VarExp(exp.loc, ss.withstate.wthis);
                    e = new DotIdExp(exp.loc, e, exp.ident);
                    e = e.trySemantic(sc);
                    if (e)
                    {
                        result = e;
                        return;
                    }
                }
                break;
            }
        }

        /* Look for what user might have meant
         */
        if (const n = importHint(exp.ident.toChars()))
            exp.error("`%s` is not defined, perhaps `import %s;` is needed?", exp.ident.toChars(), n);
        else if (auto s2 = sc.search_correct(exp.ident))
            exp.error("undefined identifier `%s`, did you mean %s `%s`?", exp.ident.toChars(), s2.kind(), s2.toChars());
        else if (const p = Scope.search_correct_C(exp.ident))
            exp.error("undefined identifier `%s`, did you mean `%s`?", exp.ident.toChars(), p);
        else
            exp.error("undefined identifier `%s`", exp.ident.toChars());

        result = new ErrorExp();
    }

    override void visit(DsymbolExp e)
    {
        result = resolve(e.loc, sc, e.s, e.hasOverloads);
    }

    override void visit(ThisExp e)
    {
        static if (LOGSEMANTIC)
        {
            printf("ThisExp::semantic()\n");
        }
        if (e.type)
        {
            result = e;
            return;
        }

        FuncDeclaration fd = hasThis(sc); // fd is the uplevel function with the 'this' variable

        /* Special case for typeof(this) and typeof(super) since both
         * should work even if they are not inside a non-static member function
         */
        if (!fd && sc.intypeof == 1)
        {
            // Find enclosing struct or class
            for (Dsymbol s = sc.getStructClassScope(); 1; s = s.parent)
            {
                if (!s)
                {
                    e.error("%s is not in a class or struct scope", e.toChars());
                    goto Lerr;
                }
                ClassDeclaration cd = s.isClassDeclaration();
                if (cd)
                {
                    e.type = cd.type;
                    result = e;
                    return;
                }
                StructDeclaration sd = s.isStructDeclaration();
                if (sd)
                {
                    e.type = sd.type;
                    result = e;
                    return;
                }
            }
        }
        if (!fd)
            goto Lerr;

        assert(fd.vthis);
        e.var = fd.vthis;
        assert(e.var.parent);
        e.type = e.var.type;
        if (e.var.checkNestedReference(sc, e.loc))
        {
            result = new ErrorExp();
            return;
        }
        if (!sc.intypeof)
            sc.callSuper |= CSXthis;
        result = e;
        return;

    Lerr:
        e.error("'this' is only defined in non-static member functions, not %s", sc.parent.toChars());
        result = new ErrorExp();
    }

    override void visit(SuperExp e)
    {
        static if (LOGSEMANTIC)
        {
            printf("SuperExp::semantic('%s')\n", e.toChars());
        }
        if (e.type)
        {
            result = e;
            return;
        }

        FuncDeclaration fd = hasThis(sc);
        ClassDeclaration cd;
        Dsymbol s;

        /* Special case for typeof(this) and typeof(super) since both
         * should work even if they are not inside a non-static member function
         */
        if (!fd && sc.intypeof == 1)
        {
            // Find enclosing class
            for (s = sc.getStructClassScope(); 1; s = s.parent)
            {
                if (!s)
                {
                    e.error("%s is not in a class scope", e.toChars());
                    goto Lerr;
                }
                cd = s.isClassDeclaration();
                if (cd)
                {
                    cd = cd.baseClass;
                    if (!cd)
                    {
                        e.error("class %s has no 'super'", s.toChars());
                        goto Lerr;
                    }
                    e.type = cd.type;
                    result = e;
                    return;
                }
            }
        }
        if (!fd)
            goto Lerr;

        e.var = fd.vthis;
        assert(e.var && e.var.parent);

        s = fd.toParent();
        while (s && s.isTemplateInstance())
            s = s.toParent();
        if (s.isTemplateDeclaration()) // allow inside template constraint
            s = s.toParent();
        assert(s);
        cd = s.isClassDeclaration();
        //printf("parent is %s %s\n", fd.toParent().kind(), fd.toParent().toChars());
        if (!cd)
            goto Lerr;
        if (!cd.baseClass)
        {
            e.error("no base class for %s", cd.toChars());
            e.type = e.var.type;
        }
        else
        {
            e.type = cd.baseClass.type;
            e.type = e.type.castMod(e.var.type.mod);
        }

        if (e.var.checkNestedReference(sc, e.loc))
        {
            result = new ErrorExp();
            return;
        }

        if (!sc.intypeof)
            sc.callSuper |= CSXsuper;
        result = e;
        return;

    Lerr:
        e.error("'super' is only allowed in non-static class member functions");
        result = new ErrorExp();
    }

    override void visit(NullExp e)
    {
        static if (LOGSEMANTIC)
        {
            printf("NullExp::semantic('%s')\n", e.toChars());
        }
        // NULL is the same as (void *)0
        if (e.type)
        {
            result = e;
            return;
        }
        e.type = Type.tnull;
        result = e;
    }

    override void visit(StringExp e)
    {
        static if (LOGSEMANTIC)
        {
            printf("StringExp::semantic() %s\n", e.toChars());
        }
        if (e.type)
        {
            result = e;
            return;
        }

        OutBuffer buffer;
        size_t newlen = 0;
        const(char)* p;
        size_t u;
        dchar c;

        switch (e.postfix)
        {
        case 'd':
            for (u = 0; u < e.len;)
            {
                p = utf_decodeChar(e.string, e.len, u, c);
                if (p)
                {
                    e.error("%s", p);
                    result = new ErrorExp();
                    return;
                }
                else
                {
                    buffer.write4(c);
                    newlen++;
                }
            }
            buffer.write4(0);
            e.dstring = cast(dchar*)buffer.extractData();
            e.len = newlen;
            e.sz = 4;
            e.type = new TypeDArray(Type.tdchar.immutableOf());
            e.committed = 1;
            break;

        case 'w':
            for (u = 0; u < e.len;)
            {
                p = utf_decodeChar(e.string, e.len, u, c);
                if (p)
                {
                    e.error("%s", p);
                    result = new ErrorExp();
                    return;
                }
                else
                {
                    buffer.writeUTF16(c);
                    newlen++;
                    if (c >= 0x10000)
                        newlen++;
                }
            }
            buffer.writeUTF16(0);
            e.wstring = cast(wchar*)buffer.extractData();
            e.len = newlen;
            e.sz = 2;
            e.type = new TypeDArray(Type.twchar.immutableOf());
            e.committed = 1;
            break;

        case 'c':
            e.committed = 1;
            goto default;

        default:
            e.type = new TypeDArray(Type.tchar.immutableOf());
            break;
        }
        e.type = e.type.semantic(e.loc, sc);
        //type = type.immutableOf();
        //printf("type = %s\n", type.toChars());

        result = e;
    }

    override void visit(TupleExp exp)
    {
        static if (LOGSEMANTIC)
        {
            printf("+TupleExp::semantic(%s)\n", exp.toChars());
        }
        if (exp.type)
        {
            result = exp;
            return;
        }

        if (exp.e0)
            exp.e0 = exp.e0.semantic(sc);

        // Run semantic() on each argument
        bool err = false;
        for (size_t i = 0; i < exp.exps.dim; i++)
        {
            Expression e = (*exp.exps)[i];
            e = e.semantic(sc);
            if (!e.type)
            {
                exp.error("%s has no value", e.toChars());
                err = true;
            }
            else if (e.op == TOKerror)
                err = true;
            else
                (*exp.exps)[i] = e;
        }
        if (err)
        {
            result = new ErrorExp();
            return;
        }

        expandTuples(exp.exps);

        exp.type = new TypeTuple(exp.exps);
        exp.type = exp.type.semantic(exp.loc, sc);
        //printf("-TupleExp::semantic(%s)\n", toChars());
        result = exp;
    }

    override void visit(ArrayLiteralExp e)
    {
        static if (LOGSEMANTIC)
        {
            printf("ArrayLiteralExp::semantic('%s')\n", e.toChars());
        }
        if (e.type)
        {
            result = e;
            return;
        }

        /* Perhaps an empty array literal [ ] should be rewritten as null?
         */

        if (e.basis)
            e.basis = e.basis.semantic(sc);
        if (arrayExpressionSemantic(e.elements, sc) || (e.basis && e.basis.op == TOKerror))
        {
            result = new ErrorExp();
            return;
        }

        expandTuples(e.elements);

        Type t0;
        if (e.basis)
            e.elements.push(e.basis);
        bool err = arrayExpressionToCommonType(sc, e.elements, &t0);
        if (e.basis)
            e.basis = e.elements.pop();
        if (err)
        {
            result = new ErrorExp();
            return;
        }

        e.type = t0.arrayOf();
        e.type = e.type.semantic(e.loc, sc);

        /* Disallow array literals of type void being used.
         */
        if (e.elements.dim > 0 && t0.ty == Tvoid)
        {
            e.error("%s of type %s has no value", e.toChars(), e.type.toChars());
            result = new ErrorExp();
            return;
        }

        semanticTypeInfo(sc, e.type);

        result = e;
    }

    override void visit(AssocArrayLiteralExp e)
    {
        static if (LOGSEMANTIC)
        {
            printf("AssocArrayLiteralExp::semantic('%s')\n", e.toChars());
        }
        if (e.type)
        {
            result = e;
            return;
        }

        // Run semantic() on each element
        bool err_keys = arrayExpressionSemantic(e.keys, sc);
        bool err_vals = arrayExpressionSemantic(e.values, sc);
        if (err_keys || err_vals)
        {
            result = new ErrorExp();
            return;
        }

        expandTuples(e.keys);
        expandTuples(e.values);
        if (e.keys.dim != e.values.dim)
        {
            e.error("number of keys is %u, must match number of values %u", e.keys.dim, e.values.dim);
            result = new ErrorExp();
            return;
        }

        Type tkey = null;
        Type tvalue = null;
        err_keys = arrayExpressionToCommonType(sc, e.keys, &tkey);
        err_vals = arrayExpressionToCommonType(sc, e.values, &tvalue);
        if (err_keys || err_vals)
        {
            result = new ErrorExp();
            return;
        }

        if (tkey == Type.terror || tvalue == Type.terror)
        {
            result = new ErrorExp();
            return;
        }

        e.type = new TypeAArray(tvalue, tkey);
        e.type = e.type.semantic(e.loc, sc);

        semanticTypeInfo(sc, e.type);

        result = e;
    }

    override void visit(StructLiteralExp e)
    {
        static if (LOGSEMANTIC)
        {
            printf("StructLiteralExp::semantic('%s')\n", e.toChars());
        }
        if (e.type)
        {
            result = e;
            return;
        }

        e.sd.size(e.loc);
        if (e.sd.sizeok != SIZEOKdone)
        {
            result = new ErrorExp();
            return;
        }

        // run semantic() on each element
        if (arrayExpressionSemantic(e.elements, sc))
        {
            result = new ErrorExp();
            return;
        }

        expandTuples(e.elements);

        /* Fit elements[] to the corresponding type of field[].
         */
        if (!e.sd.fit(e.loc, sc, e.elements, e.stype))
        {
            result = new ErrorExp();
            return;
        }

        /* Fill out remainder of elements[] with default initializers for fields[]
         */
        if (!e.sd.fill(e.loc, e.elements, false))
        {
            /* An error in the initializer needs to be recorded as an error
             * in the enclosing function or template, since the initializer
             * will be part of the stuct declaration.
             */
            global.increaseErrorCount();
            result = new ErrorExp();
            return;
        }

        if (checkFrameAccess(e.loc, sc, e.sd, e.elements.dim))
        {
            result = new ErrorExp();
            return;
        }

        e.type = e.stype ? e.stype : e.sd.type;
        result = e;
    }

    override void visit(TypeExp exp)
    {
        if (exp.type.ty == Terror)
        {
            result = new ErrorExp();
            return;
        }

        //printf("TypeExp::semantic(%s)\n", type.toChars());
        Expression e;
        Type t;
        Dsymbol s;

        exp.type.resolve(exp.loc, sc, &e, &t, &s, true);
        if (e)
        {
            //printf("e = %s %s\n", Token::toChars(e.op), e.toChars());
            e = e.semantic(sc);
        }
        else if (t)
        {
            //printf("t = %d %s\n", t.ty, t.toChars());
            exp.type = t.semantic(exp.loc, sc);
            e = exp;
        }
        else if (s)
        {
            //printf("s = %s %s\n", s.kind(), s.toChars());
            e = resolve(exp.loc, sc, s, true);
        }
        else
            assert(0);

        if (global.params.vcomplex)
            exp.type.checkComplexTransition(exp.loc);

        result = e;
    }

    override void visit(ScopeExp exp)
    {
        static if (LOGSEMANTIC)
        {
            printf("+ScopeExp::semantic(%p '%s')\n", exp, exp.toChars());
        }
        if (exp.type)
        {
            result = exp;
            return;
        }

        ScopeDsymbol sds2 = exp.sds;
        TemplateInstance ti = sds2.isTemplateInstance();
        while (ti)
        {
            WithScopeSymbol withsym;
            if (!ti.findTempDecl(sc, &withsym) || !ti.semanticTiargs(sc))
            {
                result = new ErrorExp();
                return;
            }
            if (withsym && withsym.withstate.wthis)
            {
                Expression e = new VarExp(exp.loc, withsym.withstate.wthis);
                e = new DotTemplateInstanceExp(exp.loc, e, ti);
                result = e.semantic(sc);
                return;
            }
            if (ti.needsTypeInference(sc))
            {
                if (TemplateDeclaration td = ti.tempdecl.isTemplateDeclaration())
                {
                    Dsymbol p = td.toParent2();
                    FuncDeclaration fdthis = hasThis(sc);
                    AggregateDeclaration ad = p ? p.isAggregateDeclaration() : null;
                    if (fdthis && ad && isAggregate(fdthis.vthis.type) == ad && (td._scope.stc & STCstatic) == 0)
                    {
                        Expression e = new DotTemplateInstanceExp(exp.loc, new ThisExp(exp.loc), ti.name, ti.tiargs);
                        result = e.semantic(sc);
                        return;
                    }
                }
                else if (OverloadSet os = ti.tempdecl.isOverloadSet())
                {
                    FuncDeclaration fdthis = hasThis(sc);
                    AggregateDeclaration ad = os.parent.isAggregateDeclaration();
                    if (fdthis && ad && isAggregate(fdthis.vthis.type) == ad)
                    {
                        Expression e = new DotTemplateInstanceExp(exp.loc, new ThisExp(exp.loc), ti.name, ti.tiargs);
                        result = e.semantic(sc);
                        return;
                    }
                }
                // ti is an instance which requires IFTI.
                exp.sds = ti;
                exp.type = Type.tvoid;
                result = exp;
                return;
            }
            ti.semantic(sc);
            if (!ti.inst || ti.errors)
            {
                result = new ErrorExp();
                return;
            }

            Dsymbol s = ti.toAlias();
            if (s == ti)
            {
                exp.sds = ti;
                exp.type = Type.tvoid;
                result = exp;
                return;
            }
            sds2 = s.isScopeDsymbol();
            if (sds2)
            {
                ti = sds2.isTemplateInstance();
                //printf("+ sds2 = %s, '%s'\n", sds2.kind(), sds2.toChars());
                continue;
            }

            if (auto v = s.isVarDeclaration())
            {
                if (!v.type)
                {
                    exp.error("forward reference of %s %s", v.kind(), v.toChars());
                    result = new ErrorExp();
                    return;
                }
                if ((v.storage_class & STCmanifest) && v._init)
                {
                    /* When an instance that will be converted to a constant exists,
                     * the instance representation "foo!tiargs" is treated like a
                     * variable name, and its recursive appearance check (note that
                     * it's equivalent with a recursive instantiation of foo) is done
                     * separately from the circular initialization check for the
                     * eponymous enum variable declaration.
                     *
                     *  template foo(T) {
                     *    enum bool foo = foo;    // recursive definition check (v.inuse)
                     *  }
                     *  template bar(T) {
                     *    enum bool bar = bar!T;  // recursive instantiation check (ti.inuse)
                     *  }
                     */
                    if (ti.inuse)
                    {
                        exp.error("recursive expansion of %s '%s'", ti.kind(), ti.toPrettyChars());
                        result = new ErrorExp();
                        return;
                    }
                    auto e = v.expandInitializer(exp.loc);
                    ti.inuse++;
                    e = e.semantic(sc);
                    ti.inuse--;
                    result = e;
                    return;
                }
            }

            //printf("s = %s, '%s'\n", s.kind(), s.toChars());
            auto e = resolve(exp.loc, sc, s, true);
            //printf("-1ScopeExp::semantic()\n");
            result = e;
            return;
        }

        //printf("sds2 = %s, '%s'\n", sds2.kind(), sds2.toChars());
        //printf("\tparent = '%s'\n", sds2.parent.toChars());
        sds2.semantic(sc);

        // (Aggregate|Enum)Declaration
        if (auto t = sds2.getType())
        {
            result = (new TypeExp(exp.loc, t)).semantic(sc);
            return;
        }

        if (auto td = sds2.isTemplateDeclaration())
        {
            result = (new TemplateExp(exp.loc, td)).semantic(sc);
            return;
        }

        exp.sds = sds2;
        exp.type = Type.tvoid;
        //printf("-2ScopeExp::semantic() %s\n", toChars());
        result = exp;
    }

    override void visit(NewExp exp)
    {
        static if (LOGSEMANTIC)
        {
            printf("NewExp::semantic() %s\n", exp.toChars());
            if (exp.thisexp)
                printf("\tthisexp = %s\n", exp.thisexp.toChars());
            printf("\tnewtype: %s\n", exp.newtype.toChars());
        }
        if (exp.type) // if semantic() already run
        {
            result = exp;
            return;
        }

        // https://issues.dlang.org/show_bug.cgi?id=11581
        // With the syntax `new T[edim]` or `thisexp.new T[edim]`,
        // T should be analyzed first and edim should go into arguments iff it's
        // not a tuple.
        Expression edim = null;
        if (!exp.arguments && exp.newtype.ty == Tsarray)
        {
            edim = (cast(TypeSArray)exp.newtype).dim;
            exp.newtype = (cast(TypeNext)exp.newtype).next;
        }

        ClassDeclaration cdthis = null;
        if (exp.thisexp)
        {
            exp.thisexp = exp.thisexp.semantic(sc);
            if (exp.thisexp.op == TOKerror)
            {
                result = new ErrorExp();
                return;
            }
            cdthis = exp.thisexp.type.isClassHandle();
            if (!cdthis)
            {
                exp.error("'this' for nested class must be a class type, not %s", exp.thisexp.type.toChars());
                result = new ErrorExp();
                return;
            }

            sc = sc.push(cdthis);
            exp.type = exp.newtype.semantic(exp.loc, sc);
            sc = sc.pop();
        }
        else
        {
            exp.type = exp.newtype.semantic(exp.loc, sc);
        }
        if (exp.type.ty == Terror)
        {
            result = new ErrorExp();
            return;
        }

        if (edim)
        {
            if (exp.type.toBasetype().ty == Ttuple)
            {
                // --> new T[edim]
                exp.type = new TypeSArray(exp.type, edim);
                exp.type = exp.type.semantic(exp.loc, sc);
                if (exp.type.ty == Terror)
                {
                    result = new ErrorExp();
                    return;
                }
            }
            else
            {
                // --> new T[](edim)
                exp.arguments = new Expressions();
                exp.arguments.push(edim);
                exp.type = exp.type.arrayOf();
            }
        }

        exp.newtype = exp.type; // in case type gets cast to something else
        Type tb = exp.type.toBasetype();
        //printf("tb: %s, deco = %s\n", tb.toChars(), tb.deco);

        if (arrayExpressionSemantic(exp.newargs, sc) ||
            preFunctionParameters(exp.loc, sc, exp.newargs))
        {
            result = new ErrorExp();
            return;
        }
        if (arrayExpressionSemantic(exp.arguments, sc) ||
            preFunctionParameters(exp.loc, sc, exp.arguments))
        {
            result = new ErrorExp();
            return;
        }

        if (exp.thisexp && tb.ty != Tclass)
        {
            exp.error("e.new is only for allocating nested classes, not %s", tb.toChars());
            result = new ErrorExp();
            return;
        }

        size_t nargs = exp.arguments ? exp.arguments.dim : 0;
        Expression newprefix = null;

        if (tb.ty == Tclass)
        {
            auto cd = (cast(TypeClass)tb).sym;
            cd.size(exp.loc);
            if (cd.sizeok != SIZEOKdone)
            {
                result = new ErrorExp();
                return;
            }
            if (!cd.ctor)
                cd.ctor = cd.searchCtor();
            if (cd.noDefaultCtor && !nargs && !cd.defaultCtor)
            {
                exp.error("default construction is disabled for type %s", cd.type.toChars());
                result = new ErrorExp();
                return;
            }

            if (cd.isInterfaceDeclaration())
            {
                exp.error("cannot create instance of interface %s", cd.toChars());
                result = new ErrorExp();
                return;
            }
            if (cd.isAbstract())
            {
                exp.error("cannot create instance of abstract class %s", cd.toChars());
                for (size_t i = 0; i < cd.vtbl.dim; i++)
                {
                    FuncDeclaration fd = cd.vtbl[i].isFuncDeclaration();
                    if (fd && fd.isAbstract())
                    {
                        errorSupplemental(exp.loc, "function '%s' is not implemented",
                            fd.toFullSignature());
                    }
                }
                result = new ErrorExp();
                return;
            }
            // checkDeprecated() is already done in newtype.semantic().

            if (cd.isNested())
            {
                /* We need a 'this' pointer for the nested class.
                 * Ensure we have the right one.
                 */
                Dsymbol s = cd.toParent2();

                //printf("cd isNested, parent = %s '%s'\n", s.kind(), s.toPrettyChars());
                if (auto cdn = s.isClassDeclaration())
                {
                    if (!cdthis)
                    {
                        // Supply an implicit 'this' and try again
                        exp.thisexp = new ThisExp(exp.loc);
                        for (Dsymbol sp = sc.parent; 1; sp = sp.parent)
                        {
                            if (!sp)
                            {
                                exp.error("outer class %s 'this' needed to 'new' nested class %s",
                                    cdn.toChars(), cd.toChars());
                                result = new ErrorExp();
                                return;
                            }
                            ClassDeclaration cdp = sp.isClassDeclaration();
                            if (!cdp)
                                continue;
                            if (cdp == cdn || cdn.isBaseOf(cdp, null))
                                break;
                            // Add a '.outer' and try again
                            exp.thisexp = new DotIdExp(exp.loc, exp.thisexp, Id.outer);
                        }

                        exp.thisexp = exp.thisexp.semantic(sc);
                        if (exp.thisexp.op == TOKerror)
                        {
                            result = new ErrorExp();
                            return;
                        }
                        cdthis = exp.thisexp.type.isClassHandle();
                    }
                    if (cdthis != cdn && !cdn.isBaseOf(cdthis, null))
                    {
                        //printf("cdthis = %s\n", cdthis.toChars());
                        exp.error("'this' for nested class must be of type %s, not %s",
                            cdn.toChars(), exp.thisexp.type.toChars());
                        result = new ErrorExp();
                        return;
                    }
                    if (!MODimplicitConv(exp.thisexp.type.mod, exp.newtype.mod))
                    {
                        exp.error("nested type %s should have the same or weaker constancy as enclosing type %s",
                            exp.newtype.toChars(), exp.thisexp.type.toChars());
                        result = new ErrorExp();
                        return;
                    }
                }
                else if (exp.thisexp)
                {
                    exp.error("e.new is only for allocating nested classes");
                    result = new ErrorExp();
                    return;
                }
                else if (auto fdn = s.isFuncDeclaration())
                {
                    // make sure the parent context fdn of cd is reachable from sc
                    if (!ensureStaticLinkTo(sc.parent, fdn))
                    {
                        exp.error("outer function context of %s is needed to 'new' nested class %s",
                            fdn.toPrettyChars(), cd.toPrettyChars());
                        result = new ErrorExp();
                        return;
                    }
                }
                else
                    assert(0);
            }
            else if (exp.thisexp)
            {
                exp.error("e.new is only for allocating nested classes");
                result = new ErrorExp();
                return;
            }

            if (cd.aggNew)
            {
                // Prepend the size argument to newargs[]
                Expression e = new IntegerExp(exp.loc, cd.size(exp.loc), Type.tsize_t);
                if (!exp.newargs)
                    exp.newargs = new Expressions();
                exp.newargs.shift(e);

                FuncDeclaration f = resolveFuncCall(exp.loc, sc, cd.aggNew, null, tb, exp.newargs);
                if (!f || f.errors)
                {
                    result = new ErrorExp();
                    return;
                }
                exp.checkDeprecated(sc, f);
                exp.checkPurity(sc, f);
                exp.checkSafety(sc, f);
                exp.checkNogc(sc, f);
                checkAccess(cd, exp.loc, sc, f);

                TypeFunction tf = cast(TypeFunction)f.type;
                Type rettype;
                if (functionParameters(exp.loc, sc, tf, null, exp.newargs, f, &rettype, &newprefix))
                {
                    result = new ErrorExp();
                    return;
                }

                exp.allocator = f.isNewDeclaration();
                assert(exp.allocator);
            }
            else
            {
                if (exp.newargs && exp.newargs.dim)
                {
                    exp.error("no allocator for %s", cd.toChars());
                    result = new ErrorExp();
                    return;
                }
            }

            if (cd.ctor)
            {
                FuncDeclaration f = resolveFuncCall(exp.loc, sc, cd.ctor, null, tb, exp.arguments, 0);
                if (!f || f.errors)
                {
                    result = new ErrorExp();
                    return;
                }
                exp.checkDeprecated(sc, f);
                exp.checkPurity(sc, f);
                exp.checkSafety(sc, f);
                exp.checkNogc(sc, f);
                checkAccess(cd, exp.loc, sc, f);

                TypeFunction tf = cast(TypeFunction)f.type;
                if (!exp.arguments)
                    exp.arguments = new Expressions();
                if (functionParameters(exp.loc, sc, tf, exp.type, exp.arguments, f, &exp.type, &exp.argprefix))
                {
                    result = new ErrorExp();
                    return;
                }

                exp.member = f.isCtorDeclaration();
                assert(exp.member);
            }
            else
            {
                if (nargs)
                {
                    exp.error("no constructor for %s", cd.toChars());
                    result = new ErrorExp();
                    return;
                }
            }
        }
        else if (tb.ty == Tstruct)
        {
            auto sd = (cast(TypeStruct)tb).sym;
            sd.size(exp.loc);
            if (sd.sizeok != SIZEOKdone)
            {
                result = new ErrorExp();
                return;
            }
            if (!sd.ctor)
                sd.ctor = sd.searchCtor();
            if (sd.noDefaultCtor && !nargs)
            {
                exp.error("default construction is disabled for type %s", sd.type.toChars());
                result = new ErrorExp();
                return;
            }
            // checkDeprecated() is already done in newtype.semantic().

            if (sd.aggNew)
            {
                // Prepend the uint size argument to newargs[]
                Expression e = new IntegerExp(exp.loc, sd.size(exp.loc), Type.tsize_t);
                if (!exp.newargs)
                    exp.newargs = new Expressions();
                exp.newargs.shift(e);

                FuncDeclaration f = resolveFuncCall(exp.loc, sc, sd.aggNew, null, tb, exp.newargs);
                if (!f || f.errors)
                {
                    result = new ErrorExp();
                    return;
                }
                exp.checkDeprecated(sc, f);
                exp.checkPurity(sc, f);
                exp.checkSafety(sc, f);
                exp.checkNogc(sc, f);
                checkAccess(sd, exp.loc, sc, f);

                TypeFunction tf = cast(TypeFunction)f.type;
                Type rettype;
                if (functionParameters(exp.loc, sc, tf, null, exp.newargs, f, &rettype, &newprefix))
                {
                    result = new ErrorExp();
                    return;
                }

                exp.allocator = f.isNewDeclaration();
                assert(exp.allocator);
            }
            else
            {
                if (exp.newargs && exp.newargs.dim)
                {
                    exp.error("no allocator for %s", sd.toChars());
                    result = new ErrorExp();
                    return;
                }
            }

            if (sd.ctor && nargs)
            {
                FuncDeclaration f = resolveFuncCall(exp.loc, sc, sd.ctor, null, tb, exp.arguments, 0);
                if (!f || f.errors)
                {
                    result = new ErrorExp();
                    return;
                }
                exp.checkDeprecated(sc, f);
                exp.checkPurity(sc, f);
                exp.checkSafety(sc, f);
                exp.checkNogc(sc, f);
                checkAccess(sd, exp.loc, sc, f);

                TypeFunction tf = cast(TypeFunction)f.type;
                if (!exp.arguments)
                    exp.arguments = new Expressions();
                if (functionParameters(exp.loc, sc, tf, exp.type, exp.arguments, f, &exp.type, &exp.argprefix))
                {
                    result = new ErrorExp();
                    return;
                }

                exp.member = f.isCtorDeclaration();
                assert(exp.member);

                if (checkFrameAccess(exp.loc, sc, sd, sd.fields.dim))
                {
                    result = new ErrorExp();
                    return;
                }
            }
            else
            {
                if (!exp.arguments)
                    exp.arguments = new Expressions();

                if (!sd.fit(exp.loc, sc, exp.arguments, tb))
                {
                    result = new ErrorExp();
                    return;
                }

                if (!sd.fill(exp.loc, exp.arguments, false))
                {
                    result = new ErrorExp();
                    return;
                }

                if (checkFrameAccess(exp.loc, sc, sd, exp.arguments ? exp.arguments.dim : 0))
                {
                    result = new ErrorExp();
                    return;
                }
            }

            exp.type = exp.type.pointerTo();
        }
        else if (tb.ty == Tarray && nargs)
        {
            Type tn = tb.nextOf().baseElemOf();
            Dsymbol s = tn.toDsymbol(sc);
            AggregateDeclaration ad = s ? s.isAggregateDeclaration() : null;
            if (ad && ad.noDefaultCtor)
            {
                exp.error("default construction is disabled for type %s", tb.nextOf().toChars());
                result = new ErrorExp();
                return;
            }
            for (size_t i = 0; i < nargs; i++)
            {
                if (tb.ty != Tarray)
                {
                    exp.error("too many arguments for array");
                    result = new ErrorExp();
                    return;
                }

                Expression arg = (*exp.arguments)[i];
                arg = resolveProperties(sc, arg);
                arg = arg.implicitCastTo(sc, Type.tsize_t);
                arg = arg.optimize(WANTvalue);
                if (arg.op == TOKint64 && cast(sinteger_t)arg.toInteger() < 0)
                {
                    exp.error("negative array index %s", arg.toChars());
                    result = new ErrorExp();
                    return;
                }
                (*exp.arguments)[i] = arg;
                tb = (cast(TypeDArray)tb).next.toBasetype();
            }
        }
        else if (tb.isscalar())
        {
            if (!nargs)
            {
            }
            else if (nargs == 1)
            {
                Expression e = (*exp.arguments)[0];
                e = e.implicitCastTo(sc, tb);
                (*exp.arguments)[0] = e;
            }
            else
            {
                exp.error("more than one argument for construction of %s", exp.type.toChars());
                result = new ErrorExp();
                return;
            }

            exp.type = exp.type.pointerTo();
        }
        else
        {
            exp.error("new can only create structs, dynamic arrays or class objects, not %s's", exp.type.toChars());
            result = new ErrorExp();
            return;
        }

        //printf("NewExp: '%s'\n", toChars());
        //printf("NewExp:type '%s'\n", type.toChars());
        semanticTypeInfo(sc, exp.type);

        if (newprefix)
        {
            result = Expression.combine(newprefix, exp);
            return;
        }
        result = exp;
    }

    override void visit(NewAnonClassExp e)
    {
        static if (LOGSEMANTIC)
        {
            printf("NewAnonClassExp::semantic() %s\n", e.toChars());
            //printf("thisexp = %p\n", thisexp);
            //printf("type: %s\n", type.toChars());
        }

        Expression d = new DeclarationExp(e.loc, e.cd);
        sc = sc.push(); // just create new scope
        sc.flags &= ~SCOPEctfe; // temporary stop CTFE
        d = d.semantic(sc);
        sc = sc.pop();

        if (!e.cd.errors && sc.intypeof && !sc.parent.inNonRoot())
        {
            ScopeDsymbol sds = sc.tinst ? cast(ScopeDsymbol)sc.tinst : sc._module;
            sds.members.push(e.cd);
        }

        Expression n = new NewExp(e.loc, e.thisexp, e.newargs, e.cd.type, e.arguments);

        Expression c = new CommaExp(e.loc, d, n);
        result = c.semantic(sc);
    }

    override void visit(SymOffExp e)
    {
        static if (LOGSEMANTIC)
        {
            printf("SymOffExp::semantic('%s')\n", e.toChars());
        }
        //var.semantic(sc);
        if (!e.type)
            e.type = e.var.type.pointerTo();

        if (auto v = e.var.isVarDeclaration())
        {
            if (v.checkNestedReference(sc, e.loc))
            {
                result = new ErrorExp();
                return;
            }
        }
        else if (auto f = e.var.isFuncDeclaration())
        {
            if (f.checkNestedReference(sc, e.loc))
            {
                result = new ErrorExp();
                return;
            }
        }

        result = e;
    }

    override void visit(VarExp e)
    {
        static if (LOGSEMANTIC)
        {
            printf("VarExp::semantic(%s)\n", e.toChars());
        }
        if (auto fd = e.var.isFuncDeclaration())
        {
            //printf("L%d fd = %s\n", __LINE__, f.toChars());
            if (!fd.functionSemantic())
            {
                result = new ErrorExp();
                return;
            }
        }

        if (!e.type)
            e.type = e.var.type;
        if (e.type && !e.type.deco)
            e.type = e.type.semantic(e.loc, sc);

        /* Fix for 1161 doesn't work because it causes protection
         * problems when instantiating imported templates passing private
         * variables as alias template parameters.
         */
        //checkAccess(loc, sc, NULL, var);

        if (auto vd = e.var.isVarDeclaration())
        {
            if (vd.checkNestedReference(sc, e.loc))
            {
                result = new ErrorExp();
                return;
            }

            // https://issues.dlang.org/show_bug.cgi?id=12025
            // If the variable is not actually used in runtime code,
            // the purity violation error is redundant.
            //checkPurity(sc, vd);
        }
        else if (auto fd = e.var.isFuncDeclaration())
        {
            // TODO: If fd isn't yet resolved its overload, the checkNestedReference
            // call would cause incorrect validation.
            // Maybe here should be moved in CallExp, or AddrExp for functions.
            if (fd.checkNestedReference(sc, e.loc))
            {
                result = new ErrorExp();
                return;
            }
        }
        else if (auto od = e.var.isOverDeclaration())
        {
            e.type = Type.tvoid; // ambiguous type?
        }

        result = e;
    }

    override void visit(FuncExp exp)
    {
        static if (LOGSEMANTIC)
        {
            printf("FuncExp::semantic(%s)\n", exp.toChars());
            if (exp.fd.treq)
                printf("  treq = %s\n", exp.fd.treq.toChars());
        }
        Expression e = exp;

        sc = sc.push(); // just create new scope
        sc.flags &= ~SCOPEctfe; // temporary stop CTFE
        sc.protection = Prot(PROTpublic); // https://issues.dlang.org/show_bug.cgi?id=12506

        if (!exp.type || exp.type == Type.tvoid)
        {
            /* fd.treq might be incomplete type,
             * so should not semantic it.
             * void foo(T)(T delegate(int) dg){}
             * foo(a=>a); // in IFTI, treq == T delegate(int)
             */
            //if (fd.treq)
            //    fd.treq = fd.treq.semantic(loc, sc);

            exp.genIdent(sc);

            // Set target of return type inference
            if (exp.fd.treq && !exp.fd.type.nextOf())
            {
                TypeFunction tfv = null;
                if (exp.fd.treq.ty == Tdelegate || (exp.fd.treq.ty == Tpointer && exp.fd.treq.nextOf().ty == Tfunction))
                    tfv = cast(TypeFunction)exp.fd.treq.nextOf();
                if (tfv)
                {
                    TypeFunction tfl = cast(TypeFunction)exp.fd.type;
                    tfl.next = tfv.nextOf();
                }
            }

            //printf("td = %p, treq = %p\n", td, fd.treq);
            if (exp.td)
            {
                assert(exp.td.parameters && exp.td.parameters.dim);
                exp.td.semantic(sc);
                exp.type = Type.tvoid; // temporary type

                if (exp.fd.treq) // defer type determination
                {
                    FuncExp fe;
                    if (exp.matchType(exp.fd.treq, sc, &fe) > MATCHnomatch)
                        e = fe;
                    else
                        e = new ErrorExp();
                }
                goto Ldone;
            }

            uint olderrors = global.errors;
            exp.fd.semantic(sc);
            if (olderrors == global.errors)
            {
                exp.fd.semantic2(sc);
                if (olderrors == global.errors)
                    exp.fd.semantic3(sc);
            }
            if (olderrors != global.errors)
            {
                if (exp.fd.type && exp.fd.type.ty == Tfunction && !exp.fd.type.nextOf())
                    (cast(TypeFunction)exp.fd.type).next = Type.terror;
                e = new ErrorExp();
                goto Ldone;
            }

            // Type is a "delegate to" or "pointer to" the function literal
            if ((exp.fd.isNested() && exp.fd.tok == TOKdelegate) || (exp.tok == TOKreserved && exp.fd.treq && exp.fd.treq.ty == Tdelegate))
            {
                exp.type = new TypeDelegate(exp.fd.type);
                exp.type = exp.type.semantic(exp.loc, sc);

                exp.fd.tok = TOKdelegate;
            }
            else
            {
                exp.type = new TypePointer(exp.fd.type);
                exp.type = exp.type.semantic(exp.loc, sc);
                //type = fd.type.pointerTo();

                /* A lambda expression deduced to function pointer might become
                 * to a delegate literal implicitly.
                 *
                 *   auto foo(void function() fp) { return 1; }
                 *   assert(foo({}) == 1);
                 *
                 * So, should keep fd.tok == TOKreserve if fd.treq == NULL.
                 */
                if (exp.fd.treq && exp.fd.treq.ty == Tpointer)
                {
                    // change to non-nested
                    exp.fd.tok = TOKfunction;
                    exp.fd.vthis = null;
                }
            }
            exp.fd.tookAddressOf++;
        }

    Ldone:
        sc = sc.pop();
        result = e;
    }

    // used from CallExp::semantic()
    Expression callExpSemantic(FuncExp exp, Scope* sc, Expressions* arguments)
    {
        if ((!exp.type || exp.type == Type.tvoid) && exp.td && arguments && arguments.dim)
        {
            for (size_t k = 0; k < arguments.dim; k++)
            {
                Expression checkarg = (*arguments)[k];
                if (checkarg.op == TOKerror)
                    return checkarg;
            }

            exp.genIdent(sc);

            assert(exp.td.parameters && exp.td.parameters.dim);
            exp.td.semantic(sc);

            TypeFunction tfl = cast(TypeFunction)exp.fd.type;
            size_t dim = Parameter.dim(tfl.parameters);
            if (arguments.dim < dim)
            {
                // Default arguments are always typed, so they don't need inference.
                Parameter p = Parameter.getNth(tfl.parameters, arguments.dim);
                if (p.defaultArg)
                    dim = arguments.dim;
            }

            if ((!tfl.varargs && arguments.dim == dim) || (tfl.varargs && arguments.dim >= dim))
            {
                auto tiargs = new Objects();
                tiargs.reserve(exp.td.parameters.dim);

                for (size_t i = 0; i < exp.td.parameters.dim; i++)
                {
                    TemplateParameter tp = (*exp.td.parameters)[i];
                    for (size_t u = 0; u < dim; u++)
                    {
                        Parameter p = Parameter.getNth(tfl.parameters, u);
                        if (p.type.ty == Tident && (cast(TypeIdentifier)p.type).ident == tp.ident)
                        {
                            Expression e = (*arguments)[u];
                            tiargs.push(e.type);
                            u = dim; // break inner loop
                        }
                    }
                }

                auto ti = new TemplateInstance(exp.loc, exp.td, tiargs);
                return (new ScopeExp(exp.loc, ti)).semantic(sc);
            }
            exp.error("cannot infer function literal type");
            return new ErrorExp();
        }
        return exp.semantic(sc);
    }

    override void visit(CallExp exp)
    {
        static if (LOGSEMANTIC)
        {
            printf("CallExp::semantic() %s\n", exp.toChars());
        }
        if (exp.type)
        {
            result = exp;
            return; // semantic() already run
        }
        version (none)
        {
            if (exp.arguments && exp.arguments.dim)
            {
                Expression earg = (*exp.arguments)[0];
                earg.print();
                if (earg.type)
                    earg.type.print();
            }
        }

        Type t1;
        Objects* tiargs = null; // initial list of template arguments
        Expression ethis = null;
        Type tthis = null;
        Expression e1org = exp.e1;

        if (exp.e1.op == TOKcomma)
        {
            /* Rewrite (a,b)(args) as (a,(b(args)))
             */
            auto ce = cast(CommaExp)exp.e1;
            exp.e1 = ce.e2;
            ce.e2 = exp;
            result = ce.semantic(sc);
            return;
        }
        if (exp.e1.op == TOKdelegate)
        {
            DelegateExp de = cast(DelegateExp)exp.e1;
            exp.e1 = new DotVarExp(de.loc, de.e1, de.func, de.hasOverloads);
            visit(exp);
            return;
        }
        if (exp.e1.op == TOKfunction)
        {
            if (arrayExpressionSemantic(exp.arguments, sc) || preFunctionParameters(exp.loc, sc, exp.arguments))
            {
                result = new ErrorExp();
                return;
            }

            // Run e1 semantic even if arguments have any errors
            FuncExp fe = cast(FuncExp)exp.e1;
            exp.e1 = callExpSemantic(fe, sc, exp.arguments);
            if (exp.e1.op == TOKerror)
            {
                result = exp.e1;
                return;
            }
        }

        if (Expression ex = resolveUFCS(sc, exp))
        {
            result = ex;
            return;
        }

        /* This recognizes:
         *  foo!(tiargs)(funcargs)
         */
        if (exp.e1.op == TOKscope)
        {
            ScopeExp se = cast(ScopeExp)exp.e1;
            TemplateInstance ti = se.sds.isTemplateInstance();
            if (ti)
            {
                /* Attempt to instantiate ti. If that works, go with it.
                 * If not, go with partial explicit specialization.
                 */
                WithScopeSymbol withsym;
                if (!ti.findTempDecl(sc, &withsym) || !ti.semanticTiargs(sc))
                {
                    result = new ErrorExp();
                    return;
                }
                if (withsym && withsym.withstate.wthis)
                {
                    exp.e1 = new VarExp(exp.e1.loc, withsym.withstate.wthis);
                    exp.e1 = new DotTemplateInstanceExp(exp.e1.loc, exp.e1, ti);
                    goto Ldotti;
                }
                if (ti.needsTypeInference(sc, 1))
                {
                    /* Go with partial explicit specialization
                     */
                    tiargs = ti.tiargs;
                    assert(ti.tempdecl);
                    if (TemplateDeclaration td = ti.tempdecl.isTemplateDeclaration())
                        exp.e1 = new TemplateExp(exp.loc, td);
                    else if (OverDeclaration od = ti.tempdecl.isOverDeclaration())
                        exp.e1 = new VarExp(exp.loc, od);
                    else
                        exp.e1 = new OverExp(exp.loc, ti.tempdecl.isOverloadSet());
                }
                else
                {
                    Expression e1x = exp.e1.semantic(sc);
                    if (e1x.op == TOKerror)
                    {
                        result = e1x;
                        return;
                    }
                    exp.e1 = e1x;
                }
            }
        }

        /* This recognizes:
         *  expr.foo!(tiargs)(funcargs)
         */
    Ldotti:
        if (exp.e1.op == TOKdotti && !exp.e1.type)
        {
            DotTemplateInstanceExp se = cast(DotTemplateInstanceExp)exp.e1;
            TemplateInstance ti = se.ti;
            {
                /* Attempt to instantiate ti. If that works, go with it.
                 * If not, go with partial explicit specialization.
                 */
                if (!se.findTempDecl(sc) || !ti.semanticTiargs(sc))
                {
                    result = new ErrorExp();
                    return;
                }
                if (ti.needsTypeInference(sc, 1))
                {
                    /* Go with partial explicit specialization
                     */
                    tiargs = ti.tiargs;
                    assert(ti.tempdecl);
                    if (TemplateDeclaration td = ti.tempdecl.isTemplateDeclaration())
                        exp.e1 = new DotTemplateExp(exp.loc, se.e1, td);
                    else if (OverDeclaration od = ti.tempdecl.isOverDeclaration())
                    {
                        exp.e1 = new DotVarExp(exp.loc, se.e1, od, true);
                    }
                    else
                        exp.e1 = new DotExp(exp.loc, se.e1, new OverExp(exp.loc, ti.tempdecl.isOverloadSet()));
                }
                else
                {
                    Expression e1x = exp.e1.semantic(sc);
                    if (e1x.op == TOKerror)
                    {
                        result = e1x;
                        return;
                    }
                    exp.e1 = e1x;
                }
            }
        }

    Lagain:
        //printf("Lagain: %s\n", toChars());
        exp.f = null;
        if (exp.e1.op == TOKthis || exp.e1.op == TOKsuper)
        {
            // semantic() run later for these
        }
        else
        {
            if (exp.e1.op == TOKdotid)
            {
                DotIdExp die = cast(DotIdExp)exp.e1;
                exp.e1 = die.semantic(sc);
                /* Look for e1 having been rewritten to expr.opDispatch!(string)
                 * We handle such earlier, so go back.
                 * Note that in the rewrite, we carefully did not run semantic() on e1
                 */
                if (exp.e1.op == TOKdotti && !exp.e1.type)
                {
                    goto Ldotti;
                }
            }
            else
            {
                static __gshared int nest;
                if (++nest > 500)
                {
                    exp.error("recursive evaluation of %s", exp.toChars());
                    --nest;
                    result = new ErrorExp();
                    return;
                }
                Expression ex = unaSemantic(exp, sc);
                --nest;
                if (ex)
                {
                    result = ex;
                    return;
                }
            }

            /* Look for e1 being a lazy parameter
             */
            if (exp.e1.op == TOKvar)
            {
                VarExp ve = cast(VarExp)exp.e1;
                if (ve.var.storage_class & STClazy)
                {
                    // lazy parameters can be called without violating purity and safety
                    Type tw = ve.var.type;
                    Type tc = ve.var.type.substWildTo(MODconst);
                    auto tf = new TypeFunction(null, tc, 0, LINKd, STCsafe | STCpure);
                    (tf = cast(TypeFunction)tf.semantic(exp.loc, sc)).next = tw; // hack for bug7757
                    auto t = new TypeDelegate(tf);
                    ve.type = t.semantic(exp.loc, sc);
                }
                VarDeclaration v = ve.var.isVarDeclaration();
                if (v && ve.checkPurity(sc, v))
                {
                    result = new ErrorExp();
                    return;
                }
            }

            if (exp.e1.op == TOKsymoff && (cast(SymOffExp)exp.e1).hasOverloads)
            {
                SymOffExp se = cast(SymOffExp)exp.e1;
                exp.e1 = new VarExp(se.loc, se.var, true);
                exp.e1 = exp.e1.semantic(sc);
            }
            else if (exp.e1.op == TOKdot)
            {
                DotExp de = cast(DotExp)exp.e1;

                if (de.e2.op == TOKoverloadset)
                {
                    ethis = de.e1;
                    tthis = de.e1.type;
                    exp.e1 = de.e2;
                }
            }
            else if (exp.e1.op == TOKstar && exp.e1.type.ty == Tfunction)
            {
                // Rewrite (*fp)(arguments) to fp(arguments)
                exp.e1 = (cast(PtrExp)exp.e1).e1;
            }
        }

        t1 = exp.e1.type ? exp.e1.type.toBasetype() : null;

        if (exp.e1.op == TOKerror)
        {
            result = exp.e1;
            return;
        }
        if (arrayExpressionSemantic(exp.arguments, sc) || preFunctionParameters(exp.loc, sc, exp.arguments))
        {
            result = new ErrorExp();
            return;
        }

        // Check for call operator overload
        if (t1)
        {
            if (t1.ty == Tstruct)
            {
                auto sd = (cast(TypeStruct)t1).sym;
                sd.size(exp.loc); // Resolve forward references to construct object
                if (sd.sizeok != SIZEOKdone)
                {
                    result = new ErrorExp();
                    return;
                }
                if (!sd.ctor)
                    sd.ctor = sd.searchCtor();

                // First look for constructor
                if (exp.e1.op == TOKtype && sd.ctor)
                {
                    if (!sd.noDefaultCtor && !(exp.arguments && exp.arguments.dim))
                        goto Lx;

                    auto sle = new StructLiteralExp(exp.loc, sd, null, exp.e1.type);
                    if (!sd.fill(exp.loc, sle.elements, true))
                    {
                        result = new ErrorExp();
                        return;
                    }
                    if (checkFrameAccess(exp.loc, sc, sd, sle.elements.dim))
                    {
                        result = new ErrorExp();
                        return;
                    }

                    // https://issues.dlang.org/show_bug.cgi?id=14556
                    // Set concrete type to avoid further redundant semantic().
                    sle.type = exp.e1.type;

                    /* Constructor takes a mutable object, so don't use
                     * the immutable initializer symbol.
                     */
                    sle.useStaticInit = false;

                    Expression e = sle;
                    if (auto cf = sd.ctor.isCtorDeclaration())
                    {
                        e = new DotVarExp(exp.loc, e, cf, true);
                    }
                    else if (auto td = sd.ctor.isTemplateDeclaration())
                    {
                        e = new DotTemplateExp(exp.loc, e, td);
                    }
                    else if (auto os = sd.ctor.isOverloadSet())
                    {
                        e = new DotExp(exp.loc, e, new OverExp(exp.loc, os));
                    }
                    else
                        assert(0);
                    e = new CallExp(exp.loc, e, exp.arguments);
                    e = e.semantic(sc);
                    result = e;
                    return;
                }
                // No constructor, look for overload of opCall
                if (search_function(sd, Id.call))
                    goto L1;
                // overload of opCall, therefore it's a call
                if (exp.e1.op != TOKtype)
                {
                    if (sd.aliasthis && exp.e1.type != exp.att1)
                    {
                        if (!exp.att1 && exp.e1.type.checkAliasThisRec())
                            exp.att1 = exp.e1.type;
                        exp.e1 = resolveAliasThis(sc, exp.e1);
                        goto Lagain;
                    }
                    exp.error("%s %s does not overload ()", sd.kind(), sd.toChars());
                    result = new ErrorExp();
                    return;
                }

                /* It's a struct literal
                 */
            Lx:
                Expression e = new StructLiteralExp(exp.loc, sd, exp.arguments, exp.e1.type);
                e = e.semantic(sc);
                result = e;
                return;
            }
            else if (t1.ty == Tclass)
            {
            L1:
                // Rewrite as e1.call(arguments)
                Expression e = new DotIdExp(exp.loc, exp.e1, Id.call);
                e = new CallExp(exp.loc, e, exp.arguments);
                e = e.semantic(sc);
                result = e;
                return;
            }
            else if (exp.e1.op == TOKtype && t1.isscalar())
            {
                Expression e;

                // Make sure to use the the enum type itself rather than its
                // base type
                // https://issues.dlang.org/show_bug.cgi?id=16346
                if (exp.e1.type.ty == Tenum)
                {
                    t1 = exp.e1.type;
                }

                if (!exp.arguments || exp.arguments.dim == 0)
                {
                    e = t1.defaultInitLiteral(exp.loc);
                }
                else if (exp.arguments.dim == 1)
                {
                    e = (*exp.arguments)[0];
                    e = e.implicitCastTo(sc, t1);
                    e = new CastExp(exp.loc, e, t1);
                }
                else
                {
                    exp.error("more than one argument for construction of %s", t1.toChars());
                    e = new ErrorExp();
                }
                e = e.semantic(sc);
                result = e;
                return;
            }
        }

        static FuncDeclaration resolveOverloadSet(Loc loc, Scope* sc,
            OverloadSet os, Objects* tiargs, Type tthis, Expressions* arguments)
        {
            FuncDeclaration f = null;
            foreach (s; os.a)
            {
                if (tiargs && s.isFuncDeclaration())
                    continue;
                if (auto f2 = resolveFuncCall(loc, sc, s, tiargs, tthis, arguments, 1))
                {
                    if (f2.errors)
                        return null;
                    if (f)
                    {
                        /* Error if match in more than one overload set,
                         * even if one is a 'better' match than the other.
                         */
                        ScopeDsymbol.multiplyDefined(loc, f, f2);
                    }
                    else
                        f = f2;
                }
            }
            if (!f)
                .error(loc, "no overload matches for %s", os.toChars());
            else if (f.errors)
                f = null;
            return f;
        }

        if (exp.e1.op == TOKdotvar && t1.ty == Tfunction || exp.e1.op == TOKdottd)
        {
            UnaExp ue = cast(UnaExp)exp.e1;

            Expression ue1 = ue.e1;
            Expression ue1old = ue1; // need for 'right this' check
            VarDeclaration v;
            if (ue1.op == TOKvar && (v = (cast(VarExp)ue1).var.isVarDeclaration()) !is null && v.needThis())
            {
                ue.e1 = new TypeExp(ue1.loc, ue1.type);
                ue1 = null;
            }

            DotVarExp dve;
            DotTemplateExp dte;
            Dsymbol s;
            if (exp.e1.op == TOKdotvar)
            {
                dve = cast(DotVarExp)exp.e1;
                dte = null;
                s = dve.var;
                tiargs = null;
            }
            else
            {
                dve = null;
                dte = cast(DotTemplateExp)exp.e1;
                s = dte.td;
            }

            // Do overload resolution
            exp.f = resolveFuncCall(exp.loc, sc, s, tiargs, ue1 ? ue1.type : null, exp.arguments);
            if (!exp.f || exp.f.errors || exp.f.type.ty == Terror)
            {
                result = new ErrorExp();
                return;
            }

            if (exp.f.interfaceVirtual)
            {
                /* Cast 'this' to the type of the interface, and replace f with the interface's equivalent
                 */
                auto b = exp.f.interfaceVirtual;
                auto ad2 = b.sym;
                ue.e1 = ue.e1.castTo(sc, ad2.type.addMod(ue.e1.type.mod));
                ue.e1 = ue.e1.semantic(sc);
                ue1 = ue.e1;
                auto vi = exp.f.findVtblIndex(&ad2.vtbl, cast(int)ad2.vtbl.dim);
                assert(vi >= 0);
                exp.f = ad2.vtbl[vi].isFuncDeclaration();
                assert(exp.f);
            }
            if (exp.f.needThis())
            {
                AggregateDeclaration ad = exp.f.toParent2().isAggregateDeclaration();
                ue.e1 = getRightThis(exp.loc, sc, ad, ue.e1, exp.f);
                if (ue.e1.op == TOKerror)
                {
                    result = ue.e1;
                    return;
                }
                ethis = ue.e1;
                tthis = ue.e1.type;
                if (!(exp.f.type.ty == Tfunction && (cast(TypeFunction)exp.f.type).isscope))
                {
                    if (global.params.vsafe && checkParamArgumentEscape(sc, exp.f, Id.This, ethis, false))
                    {
                        result = new ErrorExp();
                        return;
                    }
                }
            }

            /* Cannot call public functions from inside invariant
             * (because then the invariant would have infinite recursion)
             */
            if (sc.func && sc.func.isInvariantDeclaration() && ue.e1.op == TOKthis && exp.f.addPostInvariant())
            {
                exp.error("cannot call public/export function %s from invariant", exp.f.toChars());
                result = new ErrorExp();
                return;
            }

            exp.checkDeprecated(sc, exp.f);
            exp.checkPurity(sc, exp.f);
            exp.checkSafety(sc, exp.f);
            exp.checkNogc(sc, exp.f);
            checkAccess(exp.loc, sc, ue.e1, exp.f);
            if (!exp.f.needThis())
            {
                exp.e1 = Expression.combine(ue.e1, new VarExp(exp.loc, exp.f, false));
            }
            else
            {
                if (ue1old.checkRightThis(sc))
                {
                    result = new ErrorExp();
                    return;
                }
                if (exp.e1.op == TOKdotvar)
                {
                    dve.var = exp.f;
                    exp.e1.type = exp.f.type;
                }
                else
                {
                    exp.e1 = new DotVarExp(exp.loc, dte.e1, exp.f, false);
                    exp.e1 = exp.e1.semantic(sc);
                    if (exp.e1.op == TOKerror)
                    {
                        result = new ErrorExp();
                        return;
                    }
                    ue = cast(UnaExp)exp.e1;
                }
                version (none)
                {
                    printf("ue.e1 = %s\n", ue.e1.toChars());
                    printf("f = %s\n", exp.f.toChars());
                    printf("t = %s\n", t.toChars());
                    printf("e1 = %s\n", exp.e1.toChars());
                    printf("e1.type = %s\n", exp.e1.type.toChars());
                }

                // See if we need to adjust the 'this' pointer
                AggregateDeclaration ad = exp.f.isThis();
                ClassDeclaration cd = ue.e1.type.isClassHandle();
                if (ad && cd && ad.isClassDeclaration())
                {
                    if (ue.e1.op == TOKdottype)
                    {
                        ue.e1 = (cast(DotTypeExp)ue.e1).e1;
                        exp.directcall = true;
                    }
                    else if (ue.e1.op == TOKsuper)
                        exp.directcall = true;
                    else if ((cd.storage_class & STCfinal) != 0) // https://issues.dlang.org/show_bug.cgi?id=14211
                        exp.directcall = true;

                    if (ad != cd)
                    {
                        ue.e1 = ue.e1.castTo(sc, ad.type.addMod(ue.e1.type.mod));
                        ue.e1 = ue.e1.semantic(sc);
                    }
                }
            }
            // If we've got a pointer to a function then deference it
            // https://issues.dlang.org/show_bug.cgi?id=16483
            if (exp.e1.type.ty == Tpointer && exp.e1.type.nextOf().ty == Tfunction)
            {
                Expression e = new PtrExp(exp.loc, exp.e1);
                e.type = exp.e1.type.nextOf();
                exp.e1 = e;
            }
            t1 = exp.e1.type;
        }
        else if (exp.e1.op == TOKsuper)
        {
            // Base class constructor call
            auto ad = sc.func ? sc.func.isThis() : null;
            auto cd = ad ? ad.isClassDeclaration() : null;
            if (!cd || !cd.baseClass || !sc.func.isCtorDeclaration())
            {
                exp.error("super class constructor call must be in a constructor");
                result = new ErrorExp();
                return;
            }
            if (!cd.baseClass.ctor)
            {
                exp.error("no super class constructor for %s", cd.baseClass.toChars());
                result = new ErrorExp();
                return;
            }

            if (!sc.intypeof && !(sc.callSuper & CSXhalt))
            {
                if (sc.noctor || sc.callSuper & CSXlabel)
                    exp.error("constructor calls not allowed in loops or after labels");
                if (sc.callSuper & (CSXsuper_ctor | CSXthis_ctor))
                    exp.error("multiple constructor calls");
                if ((sc.callSuper & CSXreturn) && !(sc.callSuper & CSXany_ctor))
                    exp.error("an earlier return statement skips constructor");
                sc.callSuper |= CSXany_ctor | CSXsuper_ctor;
            }

            tthis = cd.type.addMod(sc.func.type.mod);
            if (auto os = cd.baseClass.ctor.isOverloadSet())
                exp.f = resolveOverloadSet(exp.loc, sc, os, null, tthis, exp.arguments);
            else
                exp.f = resolveFuncCall(exp.loc, sc, cd.baseClass.ctor, null, tthis, exp.arguments, 0);
            if (!exp.f || exp.f.errors)
            {
                result = new ErrorExp();
                return;
            }
            exp.checkDeprecated(sc, exp.f);
            exp.checkPurity(sc, exp.f);
            exp.checkSafety(sc, exp.f);
            exp.checkNogc(sc, exp.f);
            checkAccess(exp.loc, sc, null, exp.f);

            exp.e1 = new DotVarExp(exp.e1.loc, exp.e1, exp.f, false);
            exp.e1 = exp.e1.semantic(sc);
            t1 = exp.e1.type;
        }
        else if (exp.e1.op == TOKthis)
        {
            // same class constructor call
            auto ad = sc.func ? sc.func.isThis() : null;
            if (!ad || !sc.func.isCtorDeclaration())
            {
                exp.error("constructor call must be in a constructor");
                result = new ErrorExp();
                return;
            }

            if (!sc.intypeof && !(sc.callSuper & CSXhalt))
            {
                if (sc.noctor || sc.callSuper & CSXlabel)
                    exp.error("constructor calls not allowed in loops or after labels");
                if (sc.callSuper & (CSXsuper_ctor | CSXthis_ctor))
                    exp.error("multiple constructor calls");
                if ((sc.callSuper & CSXreturn) && !(sc.callSuper & CSXany_ctor))
                    exp.error("an earlier return statement skips constructor");
                sc.callSuper |= CSXany_ctor | CSXthis_ctor;
            }

            tthis = ad.type.addMod(sc.func.type.mod);
            if (auto os = ad.ctor.isOverloadSet())
                exp.f = resolveOverloadSet(exp.loc, sc, os, null, tthis, exp.arguments);
            else
                exp.f = resolveFuncCall(exp.loc, sc, ad.ctor, null, tthis, exp.arguments, 0);
            if (!exp.f || exp.f.errors)
            {
                result = new ErrorExp();
                return;
            }
            exp.checkDeprecated(sc, exp.f);
            exp.checkPurity(sc, exp.f);
            exp.checkSafety(sc, exp.f);
            exp.checkNogc(sc, exp.f);
            //checkAccess(loc, sc, NULL, f);    // necessary?

            exp.e1 = new DotVarExp(exp.e1.loc, exp.e1, exp.f, false);
            exp.e1 = exp.e1.semantic(sc);
            t1 = exp.e1.type;

            // BUG: this should really be done by checking the static
            // call graph
            if (exp.f == sc.func)
            {
                exp.error("cyclic constructor call");
                result = new ErrorExp();
                return;
            }
        }
        else if (exp.e1.op == TOKoverloadset)
        {
            auto os = (cast(OverExp)exp.e1).vars;
            exp.f = resolveOverloadSet(exp.loc, sc, os, tiargs, tthis, exp.arguments);
            if (!exp.f)
            {
                result = new ErrorExp();
                return;
            }
            if (ethis)
                exp.e1 = new DotVarExp(exp.loc, ethis, exp.f, false);
            else
                exp.e1 = new VarExp(exp.loc, exp.f, false);
            goto Lagain;
        }
        else if (!t1)
        {
            exp.error("function expected before (), not '%s'", exp.e1.toChars());
            result = new ErrorExp();
            return;
        }
        else if (t1.ty == Terror)
        {
            result = new ErrorExp();
            return;
        }
        else if (t1.ty != Tfunction)
        {
            TypeFunction tf;
            const(char)* p;
            Dsymbol s;
            exp.f = null;
            if (exp.e1.op == TOKfunction)
            {
                // function literal that direct called is always inferred.
                assert((cast(FuncExp)exp.e1).fd);
                exp.f = (cast(FuncExp)exp.e1).fd;
                tf = cast(TypeFunction)exp.f.type;
                p = "function literal";
            }
            else if (t1.ty == Tdelegate)
            {
                TypeDelegate td = cast(TypeDelegate)t1;
                assert(td.next.ty == Tfunction);
                tf = cast(TypeFunction)td.next;
                p = "delegate";
            }
            else if (t1.ty == Tpointer && (cast(TypePointer)t1).next.ty == Tfunction)
            {
                tf = cast(TypeFunction)(cast(TypePointer)t1).next;
                p = "function pointer";
            }
            else if (exp.e1.op == TOKdotvar && (cast(DotVarExp)exp.e1).var.isOverDeclaration())
            {
                DotVarExp dve = cast(DotVarExp)exp.e1;
                exp.f = resolveFuncCall(exp.loc, sc, dve.var, tiargs, dve.e1.type, exp.arguments, 2);
                if (!exp.f)
                {
                    result = new ErrorExp();
                    return;
                }
                if (exp.f.needThis())
                {
                    dve.var = exp.f;
                    dve.type = exp.f.type;
                    dve.hasOverloads = false;
                    goto Lagain;
                }
                exp.e1 = new VarExp(dve.loc, exp.f, false);
                Expression e = new CommaExp(exp.loc, dve.e1, exp);
                result = e.semantic(sc);
                return;
            }
            else if (exp.e1.op == TOKvar && (cast(VarExp)exp.e1).var.isOverDeclaration())
            {
                s = (cast(VarExp)exp.e1).var;
                goto L2;
            }
            else if (exp.e1.op == TOKtemplate)
            {
                s = (cast(TemplateExp)exp.e1).td;
            L2:
                exp.f = resolveFuncCall(exp.loc, sc, s, tiargs, null, exp.arguments);
                if (!exp.f || exp.f.errors)
                {
                    result = new ErrorExp();
                    return;
                }
                if (exp.f.needThis())
                {
                    if (hasThis(sc))
                    {
                        // Supply an implicit 'this', as in
                        //    this.ident
                        exp.e1 = new DotVarExp(exp.loc, (new ThisExp(exp.loc)).semantic(sc), exp.f, false);
                        goto Lagain;
                    }
                    else if (isNeedThisScope(sc, exp.f))
                    {
                        exp.error("need 'this' for '%s' of type '%s'", exp.f.toChars(), exp.f.type.toChars());
                        result = new ErrorExp();
                        return;
                    }
                }
                exp.e1 = new VarExp(exp.e1.loc, exp.f, false);
                goto Lagain;
            }
            else
            {
                exp.error("function expected before (), not %s of type %s", exp.e1.toChars(), exp.e1.type.toChars());
                result = new ErrorExp();
                return;
            }

            if (!tf.callMatch(null, exp.arguments))
            {
                OutBuffer buf;
                buf.writeByte('(');
                argExpTypesToCBuffer(&buf, exp.arguments);
                buf.writeByte(')');
                if (tthis)
                    tthis.modToBuffer(&buf);

                //printf("tf = %s, args = %s\n", tf.deco, (*arguments)[0].type.deco);
                .error(exp.loc, "%s %s %s is not callable using argument types %s", p, exp.e1.toChars(), parametersTypeToChars(tf.parameters, tf.varargs), buf.peekString());

                result = new ErrorExp();
                return;
            }
            // Purity and safety check should run after testing arguments matching
            if (exp.f)
            {
                exp.checkPurity(sc, exp.f);
                exp.checkSafety(sc, exp.f);
                exp.checkNogc(sc, exp.f);
                if (exp.f.checkNestedReference(sc, exp.loc))
                {
                    result = new ErrorExp();
                    return;
                }
            }
            else if (sc.func && sc.intypeof != 1 && !(sc.flags & SCOPEctfe))
            {
                bool err = false;
                if (!tf.purity && !(sc.flags & SCOPEdebug) && sc.func.setImpure())
                {
                    exp.error("pure %s '%s' cannot call impure %s '%s'",
                        sc.func.kind(), sc.func.toPrettyChars(), p, exp.e1.toChars());
                    err = true;
                }
                if (!tf.isnogc && sc.func.setGC())
                {
                    exp.error("@nogc %s '%s' cannot call non-@nogc %s '%s'",
                        sc.func.kind(), sc.func.toPrettyChars(), p, exp.e1.toChars());
                    err = true;
                }
                if (tf.trust <= TRUSTsystem && sc.func.setUnsafe())
                {
                    exp.error("@safe %s '%s' cannot call @system %s '%s'",
                        sc.func.kind(), sc.func.toPrettyChars(), p, exp.e1.toChars());
                    err = true;
                }
                if (err)
                {
                    result = new ErrorExp();
                    return;
                }
            }

            if (t1.ty == Tpointer)
            {
                Expression e = new PtrExp(exp.loc, exp.e1);
                e.type = tf;
                exp.e1 = e;
            }
            t1 = tf;
        }
        else if (exp.e1.op == TOKvar)
        {
            // Do overload resolution
            VarExp ve = cast(VarExp)exp.e1;

            exp.f = ve.var.isFuncDeclaration();
            assert(exp.f);
            tiargs = null;

            if (ve.hasOverloads)
                exp.f = resolveFuncCall(exp.loc, sc, exp.f, tiargs, null, exp.arguments, 2);
            else
            {
                exp.f = exp.f.toAliasFunc();
                TypeFunction tf = cast(TypeFunction)exp.f.type;
                if (!tf.callMatch(null, exp.arguments))
                {
                    OutBuffer buf;
                    buf.writeByte('(');
                    argExpTypesToCBuffer(&buf, exp.arguments);
                    buf.writeByte(')');

                    //printf("tf = %s, args = %s\n", tf.deco, (*arguments)[0].type.deco);
                    .error(exp.loc, "%s %s is not callable using argument types %s", exp.e1.toChars(), parametersTypeToChars(tf.parameters, tf.varargs), buf.peekString());

                    exp.f = null;
                }
            }
            if (!exp.f || exp.f.errors)
            {
                result = new ErrorExp();
                return;
            }

            if (exp.f.needThis())
            {
                // Change the ancestor lambdas to delegate before hasThis(sc) call.
                if (exp.f.checkNestedReference(sc, exp.loc))
                {
                    result = new ErrorExp();
                    return;
                }

                if (hasThis(sc))
                {
                    // Supply an implicit 'this', as in
                    //    this.ident
                    exp.e1 = new DotVarExp(exp.loc, (new ThisExp(exp.loc)).semantic(sc), ve.var);
                    // Note: we cannot use f directly, because further overload resolution
                    // through the supplied 'this' may cause different result.
                    goto Lagain;
                }
                else if (isNeedThisScope(sc, exp.f))
                {
                    exp.error("need 'this' for '%s' of type '%s'", exp.f.toChars(), exp.f.type.toChars());
                    result = new ErrorExp();
                    return;
                }
            }

            exp.checkDeprecated(sc, exp.f);
            exp.checkPurity(sc, exp.f);
            exp.checkSafety(sc, exp.f);
            exp.checkNogc(sc, exp.f);
            checkAccess(exp.loc, sc, null, exp.f);
            if (exp.f.checkNestedReference(sc, exp.loc))
            {
                result = new ErrorExp();
                return;
            }

            ethis = null;
            tthis = null;

            if (ve.hasOverloads)
            {
                exp.e1 = new VarExp(ve.loc, exp.f, false);
                exp.e1.type = exp.f.type;
            }
            t1 = exp.f.type;
        }
        assert(t1.ty == Tfunction);

        Expression argprefix;
        if (!exp.arguments)
            exp.arguments = new Expressions();
        if (functionParameters(exp.loc, sc, cast(TypeFunction)t1, tthis, exp.arguments, exp.f, &exp.type, &argprefix))
        {
            result = new ErrorExp();
            return;
        }

        if (!exp.type)
        {
            exp.e1 = e1org; // https://issues.dlang.org/show_bug.cgi?id=10922
                        // avoid recursive expression printing
            exp.error("forward reference to inferred return type of function call '%s'", exp.toChars());
            result = new ErrorExp();
            return;
        }

        if (exp.f && exp.f.tintro)
        {
            Type t = exp.type;
            int offset = 0;
            TypeFunction tf = cast(TypeFunction)exp.f.tintro;
            if (tf.next.isBaseOf(t, &offset) && offset)
            {
                exp.type = tf.next;
                result = Expression.combine(argprefix, exp.castTo(sc, t));
                return;
            }
        }

        // Handle the case of a direct lambda call
        if (exp.f && exp.f.isFuncLiteralDeclaration() && sc.func && !sc.intypeof)
        {
            exp.f.tookAddressOf = 0;
        }

        result = Expression.combine(argprefix, exp);
    }

    override void visit(DeclarationExp e)
    {
        if (e.type)
        {
            result = e;
            return;
        }
        static if (LOGSEMANTIC)
        {
            printf("DeclarationExp::semantic() %s\n", e.toChars());
        }

        uint olderrors = global.errors;

        /* This is here to support extern(linkage) declaration,
         * where the extern(linkage) winds up being an AttribDeclaration
         * wrapper.
         */
        Dsymbol s = e.declaration;

        while (1)
        {
            AttribDeclaration ad = s.isAttribDeclaration();
            if (ad)
            {
                if (ad.decl && ad.decl.dim == 1)
                {
                    s = (*ad.decl)[0];
                    continue;
                }
            }
            break;
        }

        VarDeclaration v = s.isVarDeclaration();
        if (v)
        {
            // Do semantic() on initializer first, so:
            //      int a = a;
            // will be illegal.
            e.declaration.semantic(sc);
            s.parent = sc.parent;
        }

        //printf("inserting '%s' %p into sc = %p\n", s.toChars(), s, sc);
        // Insert into both local scope and function scope.
        // Must be unique in both.
        if (s.ident)
        {
            if (!sc.insert(s))
            {
                e.error("declaration %s is already defined", s.toPrettyChars());
                result = new ErrorExp();
                return;
            }
            else if (sc.func)
            {
                // https://issues.dlang.org/show_bug.cgi?id=11720
                // include Dataseg variables
                if ((s.isFuncDeclaration() ||
                     s.isAggregateDeclaration() ||
                     s.isEnumDeclaration() ||
                     v && v.isDataseg()) && !sc.func.localsymtab.insert(s))
                {
                    e.error("declaration %s is already defined in another scope in %s", s.toPrettyChars(), sc.func.toChars());
                    result = new ErrorExp();
                    return;
                }
                else
                {
                    // Disallow shadowing
                    for (Scope* scx = sc.enclosing; scx && scx.func == sc.func; scx = scx.enclosing)
                    {
                        Dsymbol s2;
                        if (scx.scopesym && scx.scopesym.symtab && (s2 = scx.scopesym.symtab.lookup(s.ident)) !is null && s != s2)
                        {
                            // allow STClocal symbols to be shadowed
                            // TODO: not really an optimal design
                            auto decl = s2.isDeclaration();
                            if (!decl || !(decl.storage_class & STClocal))
                            {
                                e.error("%s %s is shadowing %s %s", s.kind(), s.ident.toChars(), s2.kind(), s2.toPrettyChars());
                                result = new ErrorExp();
                                return;
                            }
                        }
                    }
                }
            }
        }
        if (!s.isVarDeclaration())
        {
            Scope* sc2 = sc;
            if (sc2.stc & (STCpure | STCnothrow | STCnogc))
                sc2 = sc.push();
            sc2.stc &= ~(STCpure | STCnothrow | STCnogc);
            e.declaration.semantic(sc2);
            if (sc2 != sc)
                sc2.pop();
            s.parent = sc.parent;
        }
        if (global.errors == olderrors)
        {
            e.declaration.semantic2(sc);
            if (global.errors == olderrors)
            {
                e.declaration.semantic3(sc);
            }
        }
        // todo: error in declaration should be propagated.

        e.type = Type.tvoid;
        result = e;
    }

    override void visit(TypeidExp exp)
    {
        static if (LOGSEMANTIC)
        {
            printf("TypeidExp::semantic() %s\n", exp.toChars());
        }
        Type ta = isType(exp.obj);
        Expression ea = isExpression(exp.obj);
        Dsymbol sa = isDsymbol(exp.obj);
        //printf("ta %p ea %p sa %p\n", ta, ea, sa);

        if (ta)
        {
            ta.resolve(exp.loc, sc, &ea, &ta, &sa, true);
        }

        if (ea)
        {
            if (auto sym = getDsymbol(ea))
                ea = resolve(exp.loc, sc, sym, false);
            else
                ea = ea.semantic(sc);
            ea = resolveProperties(sc, ea);
            ta = ea.type;
            if (ea.op == TOKtype)
                ea = null;
        }

        if (!ta)
        {
            //printf("ta %p ea %p sa %p\n", ta, ea, sa);
            exp.error("no type for typeid(%s)", ea ? ea.toChars() : (sa ? sa.toChars() : ""));
            result = new ErrorExp();
            return;
        }

        if (global.params.vcomplex)
            ta.checkComplexTransition(exp.loc);

        Expression e;
        if (ea && ta.toBasetype().ty == Tclass)
        {
            /* Get the dynamic type, which is .classinfo
             */
            ea = ea.semantic(sc);
            e = new TypeidExp(ea.loc, ea);
            e.type = Type.typeinfoclass.type;
        }
        else if (ta.ty == Terror)
        {
            e = new ErrorExp();
        }
        else
        {
            // Handle this in the glue layer
            e = new TypeidExp(exp.loc, ta);
            e.type = getTypeInfoType(ta, sc);

            semanticTypeInfo(sc, ta);

            if (ea)
            {
                e = new CommaExp(exp.loc, ea, e); // execute ea
                e = e.semantic(sc);
            }
        }
        result = e;
    }

    override void visit(TraitsExp e)
    {
        result = semanticTraits(e, sc);
    }

    override void visit(HaltExp e)
    {
        static if (LOGSEMANTIC)
        {
            printf("HaltExp::semantic()\n");
        }
        e.type = Type.tvoid;
        result = e;
    }

    override void visit(IsExp e)
    {
        /* is(targ id tok tspec)
         * is(targ id :  tok2)
         * is(targ id == tok2)
         */

        //printf("IsExp::semantic(%s)\n", toChars());
        if (e.id && !(sc.flags & SCOPEcondition))
        {
            e.error("can only declare type aliases within static if conditionals or static asserts");
            result = new ErrorExp();
            return;
        }

        Type tded = null;
        Scope* sc2 = sc.copy(); // keep sc.flags
        sc2.tinst = null;
        sc2.minst = null;
        sc2.flags |= SCOPEfullinst;
        Type t = e.targ.trySemantic(e.loc, sc2);
        sc2.pop();
        if (!t)
            goto Lno;
        // errors, so condition is false
        e.targ = t;
        if (e.tok2 != TOKreserved)
        {
            switch (e.tok2)
            {
            case TOKstruct:
                if (e.targ.ty != Tstruct)
                    goto Lno;
                if ((cast(TypeStruct)e.targ).sym.isUnionDeclaration())
                    goto Lno;
                tded = e.targ;
                break;

            case TOKunion:
                if (e.targ.ty != Tstruct)
                    goto Lno;
                if (!(cast(TypeStruct)e.targ).sym.isUnionDeclaration())
                    goto Lno;
                tded = e.targ;
                break;

            case TOKclass:
                if (e.targ.ty != Tclass)
                    goto Lno;
                if ((cast(TypeClass)e.targ).sym.isInterfaceDeclaration())
                    goto Lno;
                tded = e.targ;
                break;

            case TOKinterface:
                if (e.targ.ty != Tclass)
                    goto Lno;
                if (!(cast(TypeClass)e.targ).sym.isInterfaceDeclaration())
                    goto Lno;
                tded = e.targ;
                break;

            case TOKconst:
                if (!e.targ.isConst())
                    goto Lno;
                tded = e.targ;
                break;

            case TOKimmutable:
                if (!e.targ.isImmutable())
                    goto Lno;
                tded = e.targ;
                break;

            case TOKshared:
                if (!e.targ.isShared())
                    goto Lno;
                tded = e.targ;
                break;

            case TOKwild:
                if (!e.targ.isWild())
                    goto Lno;
                tded = e.targ;
                break;

            case TOKsuper:
                // If class or interface, get the base class and interfaces
                if (e.targ.ty != Tclass)
                    goto Lno;
                else
                {
                    ClassDeclaration cd = (cast(TypeClass)e.targ).sym;
                    auto args = new Parameters();
                    args.reserve(cd.baseclasses.dim);
                    if (cd.semanticRun < PASSsemanticdone)
                        cd.semantic(null);
                    for (size_t i = 0; i < cd.baseclasses.dim; i++)
                    {
                        BaseClass* b = (*cd.baseclasses)[i];
                        args.push(new Parameter(STCin, b.type, null, null));
                    }
                    tded = new TypeTuple(args);
                }
                break;

            case TOKenum:
                if (e.targ.ty != Tenum)
                    goto Lno;
                if (e.id)
                    tded = (cast(TypeEnum)e.targ).sym.getMemtype(e.loc);
                else
                    tded = e.targ;
                if (tded.ty == Terror)
                {
                    result = new ErrorExp();
                    return;
                }
                break;

            case TOKdelegate:
                if (e.targ.ty != Tdelegate)
                    goto Lno;
                tded = (cast(TypeDelegate)e.targ).next; // the underlying function type
                break;

            case TOKfunction:
            case TOKparameters:
                {
                    if (e.targ.ty != Tfunction)
                        goto Lno;
                    tded = e.targ;

                    /* Generate tuple from function parameter types.
                     */
                    assert(tded.ty == Tfunction);
                    Parameters* params = (cast(TypeFunction)tded).parameters;
                    size_t dim = Parameter.dim(params);
                    auto args = new Parameters();
                    args.reserve(dim);
                    for (size_t i = 0; i < dim; i++)
                    {
                        Parameter arg = Parameter.getNth(params, i);
                        assert(arg && arg.type);
                        /* If one of the default arguments was an error,
                           don't return an invalid tuple
                         */
                        if (e.tok2 == TOKparameters && arg.defaultArg && arg.defaultArg.op == TOKerror)
                        {
                            result = new ErrorExp();
                            return;
                        }
                        args.push(new Parameter(arg.storageClass, arg.type, (e.tok2 == TOKparameters) ? arg.ident : null, (e.tok2 == TOKparameters) ? arg.defaultArg : null));
                    }
                    tded = new TypeTuple(args);
                    break;
                }
            case TOKreturn:
                /* Get the 'return type' for the function,
                 * delegate, or pointer to function.
                 */
                if (e.targ.ty == Tfunction)
                    tded = (cast(TypeFunction)e.targ).next;
                else if (e.targ.ty == Tdelegate)
                {
                    tded = (cast(TypeDelegate)e.targ).next;
                    tded = (cast(TypeFunction)tded).next;
                }
                else if (e.targ.ty == Tpointer && (cast(TypePointer)e.targ).next.ty == Tfunction)
                {
                    tded = (cast(TypePointer)e.targ).next;
                    tded = (cast(TypeFunction)tded).next;
                }
                else
                    goto Lno;
                break;

            case TOKargTypes:
                /* Generate a type tuple of the equivalent types used to determine if a
                 * function argument of this type can be passed in registers.
                 * The results of this are highly platform dependent, and intended
                 * primarly for use in implementing va_arg().
                 */
                tded = toArgTypes(e.targ);
                if (!tded)
                    goto Lno;
                // not valid for a parameter
                break;

            case TOKvector:
                if (e.targ.ty != Tvector)
                    goto Lno;
                tded = (cast(TypeVector)e.targ).basetype;
                break;

            default:
                assert(0);
            }
            goto Lyes;
        }
        else if (e.tspec && !e.id && !(e.parameters && e.parameters.dim))
        {
            /* Evaluate to true if targ matches tspec
             * is(targ == tspec)
             * is(targ : tspec)
             */
            e.tspec = e.tspec.semantic(e.loc, sc);
            //printf("targ  = %s, %s\n", targ.toChars(), targ.deco);
            //printf("tspec = %s, %s\n", tspec.toChars(), tspec.deco);

            if (e.tok == TOKcolon)
            {
                if (e.targ.implicitConvTo(e.tspec))
                    goto Lyes;
                else
                    goto Lno;
            }
            else /* == */
            {
                if (e.targ.equals(e.tspec))
                    goto Lyes;
                else
                    goto Lno;
            }
        }
        else if (e.tspec)
        {
            /* Evaluate to true if targ matches tspec.
             * If true, declare id as an alias for the specialized type.
             * is(targ == tspec, tpl)
             * is(targ : tspec, tpl)
             * is(targ id == tspec)
             * is(targ id : tspec)
             * is(targ id == tspec, tpl)
             * is(targ id : tspec, tpl)
             */
            Identifier tid = e.id ? e.id : Identifier.generateId("__isexp_id");
            e.parameters.insert(0, new TemplateTypeParameter(e.loc, tid, null, null));

            Objects dedtypes;
            dedtypes.setDim(e.parameters.dim);
            dedtypes.zero();

            MATCH m = deduceType(e.targ, sc, e.tspec, e.parameters, &dedtypes);
            //printf("targ: %s\n", targ.toChars());
            //printf("tspec: %s\n", tspec.toChars());
            if (m <= MATCHnomatch || (m != MATCHexact && e.tok == TOKequal))
            {
                goto Lno;
            }
            else
            {
                tded = cast(Type)dedtypes[0];
                if (!tded)
                    tded = e.targ;
                Objects tiargs;
                tiargs.setDim(1);
                tiargs[0] = e.targ;

                /* Declare trailing parameters
                 */
                for (size_t i = 1; i < e.parameters.dim; i++)
                {
                    TemplateParameter tp = (*e.parameters)[i];
                    Declaration s = null;

                    m = tp.matchArg(e.loc, sc, &tiargs, i, e.parameters, &dedtypes, &s);
                    if (m <= MATCHnomatch)
                        goto Lno;
                    s.semantic(sc);
                    if (sc.sds)
                        s.addMember(sc, sc.sds);
                    else if (!sc.insert(s))
                        e.error("declaration %s is already defined", s.toChars());

                    unSpeculative(sc, s);
                }
                goto Lyes;
            }
        }
        else if (e.id)
        {
            /* Declare id as an alias for type targ. Evaluate to true
             * is(targ id)
             */
            tded = e.targ;
            goto Lyes;
        }

    Lyes:
        if (e.id)
        {
            Dsymbol s;
            Tuple tup = isTuple(tded);
            if (tup)
                s = new TupleDeclaration(e.loc, e.id, &tup.objects);
            else
                s = new AliasDeclaration(e.loc, e.id, tded);
            s.semantic(sc);

            /* The reason for the !tup is unclear. It fails Phobos unittests if it is not there.
             * More investigation is needed.
             */
            if (!tup && !sc.insert(s))
                e.error("declaration %s is already defined", s.toChars());
            if (sc.sds)
                s.addMember(sc, sc.sds);

            unSpeculative(sc, s);
        }
        //printf("Lyes\n");
        result = new IntegerExp(e.loc, 1, Type.tbool);
        return;

    Lno:
        //printf("Lno\n");
        result = new IntegerExp(e.loc, 0, Type.tbool);
    }

    override void visit(BinAssignExp exp)
    {
        if (exp.type)
        {
            result = exp;
            return;
        }

        Expression e = exp.op_overload(sc);
        if (e)
        {
            result = e;
            return;
        }

        if (exp.e1.checkReadModifyWrite(exp.op, exp.e2))
        {
            result = new ErrorExp();
            return;
        }

        if (exp.e1.op == TOKarraylength)
        {
            // arr.length op= e2;
            e = ArrayLengthExp.rewriteOpAssign(exp);
            e = e.semantic(sc);
            result = e;
            return;
        }
        if (exp.e1.op == TOKslice || exp.e1.type.ty == Tarray || exp.e1.type.ty == Tsarray)
        {
            // T[] op= ...
            if (exp.e2.implicitConvTo(exp.e1.type.nextOf()))
            {
                // T[] op= T
                exp.e2 = exp.e2.castTo(sc, exp.e1.type.nextOf());
            }
            else if (Expression ex = typeCombine(exp, sc))
            {
                result = ex;
                return;
            }
            exp.type = exp.e1.type;
            result = arrayOp(exp, sc);
            return;
        }

        exp.e1 = exp.e1.semantic(sc);
        exp.e1 = exp.e1.optimize(WANTvalue);
        exp.e1 = exp.e1.modifiableLvalue(sc, exp.e1);
        exp.type = exp.e1.type;
        if (exp.checkScalar())
        {
            result = new ErrorExp();
            return;
        }

        int arith = (exp.op == TOKaddass || exp.op == TOKminass || exp.op == TOKmulass || exp.op == TOKdivass || exp.op == TOKmodass || exp.op == TOKpowass);
        int bitwise = (exp.op == TOKandass || exp.op == TOKorass || exp.op == TOKxorass);
        int shift = (exp.op == TOKshlass || exp.op == TOKshrass || exp.op == TOKushrass);

        if (bitwise && exp.type.toBasetype().ty == Tbool)
            exp.e2 = exp.e2.implicitCastTo(sc, exp.type);
        else if (exp.checkNoBool())
        {
            result = new ErrorExp();
            return;
        }

        if ((exp.op == TOKaddass || exp.op == TOKminass) && exp.e1.type.toBasetype().ty == Tpointer && exp.e2.type.toBasetype().isintegral())
        {
            result = scaleFactor(exp, sc);
            return;
        }

        if (Expression ex = typeCombine(exp, sc))
        {
            result = ex;
            return;
        }

        if (arith && exp.checkArithmeticBin())
        {
            result = new ErrorExp();
            return;
        }
        if ((bitwise || shift) && exp.checkIntegralBin())
        {
            result = new ErrorExp();
            return;
        }
        if (shift)
        {
            exp.e2 = exp.e2.castTo(sc, Type.tshiftcnt);
        }

        if (!Target.isVectorOpSupported(exp.type.toBasetype(), exp.op, exp.e2.type.toBasetype()))
        {
            result = exp.incompatibleTypes();
            return;
        }

        if (exp.e1.op == TOKerror || exp.e2.op == TOKerror)
        {
            result = new ErrorExp();
            return;
        }

        e = exp.checkOpAssignTypes(sc);
        if (e.op == TOKerror)
        {
            result = e;
            return;
        }

        assert(e.op == TOKassign || e == exp);
        result = (cast(BinExp)e).reorderSettingAAElem(sc);
    }

    override void visit(CompileExp exp)
    {
        static if (LOGSEMANTIC)
        {
            printf("CompileExp::semantic('%s')\n", exp.toChars());
        }

        auto se = semanticString(sc, exp.e1, "argument to mixin");
        if (!se)
        {
            result = new ErrorExp();
            return;
        }
        se = se.toUTF8(sc);

        uint errors = global.errors;
        scope p = new Parser!ASTCodegen(exp.loc, sc._module, se.toStringz(), false);
        p.nextToken();
        //printf("p.loc.linnum = %d\n", p.loc.linnum);

        Expression e = p.parseExpression();
        if (p.errors)
        {
            assert(global.errors != errors); // should have caught all these cases
            result = new ErrorExp();
            return;
        }
        if (p.token.value != TOKeof)
        {
            exp.error("incomplete mixin expression (%s)", se.toChars());
            result = new ErrorExp();
            return;
        }

        result = e.semantic(sc);
    }

    override void visit(ImportExp e)
    {
        static if (LOGSEMANTIC)
        {
            printf("ImportExp::semantic('%s')\n", e.toChars());
        }

        auto se = semanticString(sc, e.e1, "file name argument");
        if (!se)
        {
            result = new ErrorExp();
            return;
        }
        se = se.toUTF8(sc);

        auto namez = se.toStringz().ptr;
        if (!global.params.fileImppath)
        {
            e.error("need -Jpath switch to import text file %s", namez);
            result = new ErrorExp();
            return;
        }

        /* Be wary of CWE-22: Improper Limitation of a Pathname to a Restricted Directory
         * ('Path Traversal') attacks.
         * http://cwe.mitre.org/data/definitions/22.html
         */

        auto name = FileName.safeSearchPath(global.filePath, namez);
        if (!name)
        {
            e.error("file %s cannot be found or not in a path specified with -J", se.toChars());
            result = new ErrorExp();
            return;
        }

        if (global.params.verbose)
            fprintf(global.stdmsg, "file      %.*s\t(%s)\n", cast(int)se.len, se.string, name);
        if (global.params.moduleDeps !is null)
        {
            OutBuffer* ob = global.params.moduleDeps;
            Module imod = sc.instantiatingModule();

            if (!global.params.moduleDepsFile)
                ob.writestring("depsFile ");
            ob.writestring(imod.toPrettyChars());
            ob.writestring(" (");
            escapePath(ob, imod.srcfile.toChars());
            ob.writestring(") : ");
            if (global.params.moduleDepsFile)
                ob.writestring("string : ");
            ob.write(se.string, se.len);
            ob.writestring(" (");
            escapePath(ob, name);
            ob.writestring(")");
            ob.writenl();
        }

        {
            auto f = File(name);
            if (f.read())
            {
                e.error("cannot read file %s", f.toChars());
                result = new ErrorExp();
                return;
            }
            else
            {
                f._ref = 1;
                se = new StringExp(e.loc, f.buffer, f.len);
            }
        }
        result = se.semantic(sc);
    }

    override void visit(AssertExp exp)
    {
        static if (LOGSEMANTIC)
        {
            printf("AssertExp::semantic('%s')\n", exp.toChars());
        }

        if (Expression ex = unaSemantic(exp, sc))
        {
            result = ex;
            return;
        }
        exp.e1 = resolveProperties(sc, exp.e1);
        // BUG: see if we can do compile time elimination of the Assert
        exp.e1 = exp.e1.optimize(WANTvalue);
        exp.e1 = exp.e1.toBoolean(sc);

        if (exp.msg)
        {
            exp.msg = exp.msg.semantic(sc);
            exp.msg = resolveProperties(sc, exp.msg);
            exp.msg = exp.msg.implicitCastTo(sc, Type.tchar.constOf().arrayOf());
            exp.msg = exp.msg.optimize(WANTvalue);
        }

        if (exp.e1.op == TOKerror)
        {
            result = exp.e1;
            return;
        }
        if (exp.msg && exp.msg.op == TOKerror)
        {
            result = exp.msg;
            return;
        }

        auto f1 = checkNonAssignmentArrayOp(exp.e1);
        auto f2 = exp.msg && checkNonAssignmentArrayOp(exp.msg);
        if (f1 || f2)
        {
            result = new ErrorExp();
            return;
        }

        if (exp.e1.isBool(false))
        {
            FuncDeclaration fd = sc.parent.isFuncDeclaration();
            if (fd)
                fd.hasReturnExp |= 4;
            sc.callSuper |= CSXhalt;
            if (sc.fieldinit)
            {
                for (size_t i = 0; i < sc.fieldinit_dim; i++)
                    sc.fieldinit[i] |= CSXhalt;
            }

            if (!global.params.useAssert)
            {
                Expression e = new HaltExp(exp.loc);
                e = e.semantic(sc);
                result = e;
                return;
            }
        }
        exp.type = Type.tvoid;
        result = exp;
    }

    override void visit(DotIdExp exp)
    {
        static if (LOGSEMANTIC)
        {
            printf("DotIdExp::semantic(this = %p, '%s')\n", exp, exp.toChars());
            //printf("e1.op = %d, '%s'\n", e1.op, Token::toChars(e1.op));
        }
        Expression e = exp.semanticY(sc, 1);
        if (e && isDotOpDispatch(e))
        {
            uint errors = global.startGagging();
            e = resolvePropertiesX(sc, e);
            if (global.endGagging(errors))
                e = null; /* fall down to UFCS */
            else
            {
                result = e;
                return;
            }
        }
        if (!e) // if failed to find the property
        {
            /* If ident is not a valid property, rewrite:
             *   e1.ident
             * as:
             *   .ident(e1)
             */
            e = resolveUFCSProperties(sc, exp);
        }
        result = e;
    }

    override void visit(DotTemplateExp e)
    {
        if (Expression ex = unaSemantic(e, sc))
        {
            result = ex;
            return;
        }
        result = e;
    }

    override void visit(DotVarExp exp)
    {
        static if (LOGSEMANTIC)
        {
            printf("DotVarExp::semantic('%s')\n", exp.toChars());
        }
        if (exp.type)
        {
            result = exp;
            return;
        }

        exp.var = exp.var.toAlias().isDeclaration();

        exp.e1 = exp.e1.semantic(sc);

        if (auto tup = exp.var.isTupleDeclaration())
        {
            /* Replace:
             *  e1.tuple(a, b, c)
             * with:
             *  tuple(e1.a, e1.b, e1.c)
             */
            Expression e0;
            Expression ev = sc.func ? extractSideEffect(sc, "__tup", e0, exp.e1) : exp.e1;

            auto exps = new Expressions();
            exps.reserve(tup.objects.dim);
            for (size_t i = 0; i < tup.objects.dim; i++)
            {
                RootObject o = (*tup.objects)[i];
                Expression e;
                if (o.dyncast() == DYNCAST.expression)
                {
                    e = cast(Expression)o;
                    if (e.op == TOKdsymbol)
                    {
                        Dsymbol s = (cast(DsymbolExp)e).s;
                        e = new DotVarExp(exp.loc, ev, s.isDeclaration());
                    }
                }
                else if (o.dyncast() == DYNCAST.dsymbol)
                {
                    e = new DsymbolExp(exp.loc, cast(Dsymbol)o);
                }
                else if (o.dyncast() == DYNCAST.type)
                {
                    e = new TypeExp(exp.loc, cast(Type)o);
                }
                else
                {
                    exp.error("%s is not an expression", o.toChars());
                    result = new ErrorExp();
                    return;
                }
                exps.push(e);
            }

            Expression e = new TupleExp(exp.loc, e0, exps);
            e = e.semantic(sc);
            result = e;
            return;
        }

        exp.e1 = exp.e1.addDtorHook(sc);

        Type t1 = exp.e1.type;

        if (FuncDeclaration fd = exp.var.isFuncDeclaration())
        {
            // for functions, do checks after overload resolution
            if (!fd.functionSemantic())
            {
                result = new ErrorExp();
                return;
            }

            /* https://issues.dlang.org/show_bug.cgi?id=13843
             * If fd obviously has no overloads, we should
             * normalize AST, and it will give a chance to wrap fd with FuncExp.
             */
            if (fd.isNested() || fd.isFuncLiteralDeclaration())
            {
                // (e1, fd)
                auto e = resolve(exp.loc, sc, fd, false);
                result = Expression.combine(exp.e1, e);
                return;
            }

            exp.type = fd.type;
            assert(exp.type);
        }
        else if (OverDeclaration od = exp.var.isOverDeclaration())
        {
            exp.type = Type.tvoid; // ambiguous type?
        }
        else
        {
            exp.type = exp.var.type;
            if (!exp.type && global.errors)
            {
                // var is goofed up, just return 0
                result = new ErrorExp();
                return;
            }
            assert(exp.type);

            if (t1.ty == Tpointer)
                t1 = t1.nextOf();

            exp.type = exp.type.addMod(t1.mod);

            Dsymbol vparent = exp.var.toParent();
            AggregateDeclaration ad = vparent ? vparent.isAggregateDeclaration() : null;
            if (Expression e1x = getRightThis(exp.loc, sc, ad, exp.e1, exp.var, 1))
                exp.e1 = e1x;
            else
            {
                /* Later checkRightThis will report correct error for invalid field variable access.
                 */
                Expression e = new VarExp(exp.loc, exp.var);
                e = e.semantic(sc);
                result = e;
                return;
            }
            checkAccess(exp.loc, sc, exp.e1, exp.var);

            VarDeclaration v = exp.var.isVarDeclaration();
            if (v && (v.isDataseg() || (v.storage_class & STCmanifest)))
            {
                Expression e = expandVar(WANTvalue, v);
                if (e)
                {
                    result = e;
                    return;
                }
            }

            if (v && v.isDataseg()) // fix https://issues.dlang.org/show_bug.cgi?id=8238
            {
                // (e1, v)
                checkAccess(exp.loc, sc, exp.e1, v);
                Expression e = new VarExp(exp.loc, v);
                e = new CommaExp(exp.loc, exp.e1, e);
                e = e.semantic(sc);
                result = e;
                return;
            }
        }
        //printf("-DotVarExp::semantic('%s')\n", toChars());
        result = exp;
    }

    override void visit(DotTemplateInstanceExp exp)
    {
        static if (LOGSEMANTIC)
        {
            printf("DotTemplateInstanceExp::semantic('%s')\n", exp.toChars());
        }
        // Indicate we need to resolve by UFCS.
        Expression e = exp.semanticY(sc, 1);
        if (!e)
            e = resolveUFCSProperties(sc, exp);
        result = e;
    }

    override void visit(DelegateExp e)
    {
        static if (LOGSEMANTIC)
        {
            printf("DelegateExp::semantic('%s')\n", e.toChars());
        }
        if (e.type)
        {
            result = e;
            return;
        }

        e.e1 = e.e1.semantic(sc);

        e.type = new TypeDelegate(e.func.type);
        e.type = e.type.semantic(e.loc, sc);

        FuncDeclaration f = e.func.toAliasFunc();
        AggregateDeclaration ad = f.toParent().isAggregateDeclaration();
        if (f.needThis())
            e.e1 = getRightThis(e.loc, sc, ad, e.e1, f);
        if (f.type.ty == Tfunction)
        {
            TypeFunction tf = cast(TypeFunction)f.type;
            if (!MODmethodConv(e.e1.type.mod, f.type.mod))
            {
                OutBuffer thisBuf, funcBuf;
                MODMatchToBuffer(&thisBuf, e.e1.type.mod, tf.mod);
                MODMatchToBuffer(&funcBuf, tf.mod, e.e1.type.mod);
                e.error("%smethod %s is not callable using a %s%s",
                    funcBuf.peekString(), f.toPrettyChars(), thisBuf.peekString(), e.e1.toChars());
                result = new ErrorExp();
                return;
            }
        }
        if (ad && ad.isClassDeclaration() && ad.type != e.e1.type)
        {
            // A downcast is required for interfaces
            // https://issues.dlang.org/show_bug.cgi?id=3706
            e.e1 = new CastExp(e.loc, e.e1, ad.type);
            e.e1 = e.e1.semantic(sc);
        }
        result = e;
    }

    override void visit(DotTypeExp exp)
    {
        static if (LOGSEMANTIC)
        {
            printf("DotTypeExp::semantic('%s')\n", exp.toChars());
        }
        if (exp.type)
        {
            result = exp;
            return;
        }

        if (auto e = unaSemantic(exp, sc))
        {
            result = e;
            return;
        }

        exp.type = exp.sym.getType().addMod(exp.e1.type.mod);
        result = exp;
    }

    override void visit(AddrExp exp)
    {
        static if (LOGSEMANTIC)
        {
            printf("AddrExp::semantic('%s')\n", exp.toChars());
        }
        if (exp.type)
        {
            result = exp;
            return;
        }

        if (Expression ex = unaSemantic(exp, sc))
        {
            result = ex;
            return;
        }

        int wasCond = exp.e1.op == TOKquestion;

        if (exp.e1.op == TOKdotti)
        {
            DotTemplateInstanceExp dti = cast(DotTemplateInstanceExp)exp.e1;
            TemplateInstance ti = dti.ti;
            {
                //assert(ti.needsTypeInference(sc));
                ti.semantic(sc);
                if (!ti.inst || ti.errors) // if template failed to expand
                {
                    result = new ErrorExp();
                    return;
                }
                Dsymbol s = ti.toAlias();
                FuncDeclaration f = s.isFuncDeclaration();
                if (f)
                {
                    exp.e1 = new DotVarExp(exp.e1.loc, dti.e1, f);
                    exp.e1 = exp.e1.semantic(sc);
                }
            }
        }
        else if (exp.e1.op == TOKscope)
        {
            TemplateInstance ti = (cast(ScopeExp)exp.e1).sds.isTemplateInstance();
            if (ti)
            {
                //assert(ti.needsTypeInference(sc));
                ti.semantic(sc);
                if (!ti.inst || ti.errors) // if template failed to expand
                {
                    result = new ErrorExp();
                    return;
                }
                Dsymbol s = ti.toAlias();
                FuncDeclaration f = s.isFuncDeclaration();
                if (f)
                {
                    exp.e1 = new VarExp(exp.e1.loc, f);
                    exp.e1 = exp.e1.semantic(sc);
                }
            }
        }
        exp.e1 = exp.e1.toLvalue(sc, null);
        if (exp.e1.op == TOKerror)
        {
            result = exp.e1;
            return;
        }
        if (checkNonAssignmentArrayOp(exp.e1))
        {
            result = new ErrorExp();
            return;
        }

        if (!exp.e1.type)
        {
            exp.error("cannot take address of %s", exp.e1.toChars());
            result = new ErrorExp();
            return;
        }

        bool hasOverloads;
        if (auto f = isFuncAddress(exp, &hasOverloads))
        {
            if (!hasOverloads && f.checkForwardRef(exp.loc))
            {
                result = new ErrorExp();
                return;
            }
        }
        else if (!exp.e1.type.deco)
        {
            if (exp.e1.op == TOKvar)
            {
                VarExp ve = cast(VarExp)exp.e1;
                Declaration d = ve.var;
                exp.error("forward reference to %s %s", d.kind(), d.toChars());
            }
            else
                exp.error("forward reference to %s", exp.e1.toChars());
            result = new ErrorExp();
            return;
        }

        exp.type = exp.e1.type.pointerTo();

        bool checkAddressVar(VarDeclaration v)
        {
            if (v)
            {
                if (!v.canTakeAddressOf())
                {
                    exp.error("cannot take address of %s", exp.e1.toChars());
                    return false;
                }
                if (sc.func && !sc.intypeof && !v.isDataseg())
                {
                    const(char)* p = v.isParameter() ? "parameter" : "local";
                    if (global.params.vsafe)
                    {
                        // Taking the address of v means it cannot be set to 'scope' later
                        v.storage_class &= ~STCmaybescope;
                        v.doNotInferScope = true;
                        if (v.storage_class & STCscope && sc.func.setUnsafe())
                        {
                            exp.error("cannot take address of scope %s %s in @safe function %s", p, v.toChars(), sc.func.toChars());
                            return false;
                        }
                    }
                    else if (sc.func.setUnsafe())
                    {
                        exp.error("cannot take address of %s %s in @safe function %s", p, v.toChars(), sc.func.toChars());
                        return false;
                    }
                }
            }
            return true;
        }

        // See if this should really be a delegate
        if (exp.e1.op == TOKdotvar)
        {
            DotVarExp dve = cast(DotVarExp)exp.e1;
            FuncDeclaration f = dve.var.isFuncDeclaration();
            if (f)
            {
                f = f.toAliasFunc(); // FIXME, should see overloads
                                     // https://issues.dlang.org/show_bug.cgi?id=1983
                if (!dve.hasOverloads)
                    f.tookAddressOf++;

                Expression e;
                if (f.needThis())
                    e = new DelegateExp(exp.loc, dve.e1, f, dve.hasOverloads);
                else // It is a function pointer. Convert &v.f() --> (v, &V.f())
                    e = new CommaExp(exp.loc, dve.e1, new AddrExp(exp.loc, new VarExp(exp.loc, f, dve.hasOverloads)));
                e = e.semantic(sc);
                result = e;
                return;
            }

            // Look for misaligned pointer in @safe mode
            if (checkUnsafeAccess(sc, dve, !exp.type.isMutable(), true))
            {
                result = new ErrorExp();
                return;
            }

            if (dve.e1.op == TOKvar && global.params.vsafe)
            {
                VarExp ve = cast(VarExp)dve.e1;
                VarDeclaration v = ve.var.isVarDeclaration();
                if (v)
                {
                    if (!checkAddressVar(v))
                    {
                        result = new ErrorExp();
                        return;
                    }
                }
            }
            else if ((dve.e1.op == TOKthis || dve.e1.op == TOKsuper) && global.params.vsafe)
            {
                ThisExp ve = cast(ThisExp)dve.e1;
                VarDeclaration v = ve.var.isVarDeclaration();
                if (v && v.storage_class & STCref)
                {
                    if (!checkAddressVar(v))
                    {
                        result = new ErrorExp();
                        return;
                    }
                }
            }
        }
        else if (exp.e1.op == TOKvar)
        {
            VarExp ve = cast(VarExp)exp.e1;
            VarDeclaration v = ve.var.isVarDeclaration();
            if (v)
            {
                if (!checkAddressVar(v))
                {
                    result = new ErrorExp();
                    return;
                }

                ve.checkPurity(sc, v);
            }
            FuncDeclaration f = ve.var.isFuncDeclaration();
            if (f)
            {
                /* Because nested functions cannot be overloaded,
                 * mark here that we took its address because castTo()
                 * may not be called with an exact match.
                 */
                if (!ve.hasOverloads || f.isNested())
                    f.tookAddressOf++;
                if (f.isNested())
                {
                    if (f.isFuncLiteralDeclaration())
                    {
                        if (!f.FuncDeclaration.isNested())
                        {
                            /* Supply a 'null' for a this pointer if no this is available
                             */
                            Expression e = new DelegateExp(exp.loc, new NullExp(exp.loc, Type.tnull), f, ve.hasOverloads);
                            e = e.semantic(sc);
                            result = e;
                            return;
                        }
                    }
                    Expression e = new DelegateExp(exp.loc, exp.e1, f, ve.hasOverloads);
                    e = e.semantic(sc);
                    result = e;
                    return;
                }
                if (f.needThis())
                {
                    if (hasThis(sc))
                    {
                        /* Should probably supply 'this' after overload resolution,
                         * not before.
                         */
                        Expression ethis = new ThisExp(exp.loc);
                        Expression e = new DelegateExp(exp.loc, ethis, f, ve.hasOverloads);
                        e = e.semantic(sc);
                        result = e;
                        return;
                    }
                    if (sc.func && !sc.intypeof)
                    {
                        if (sc.func.setUnsafe())
                        {
                            exp.error("'this' reference necessary to take address of member %s in @safe function %s", f.toChars(), sc.func.toChars());
                        }
                    }
                }
            }
        }
        else if ((exp.e1.op == TOKthis || exp.e1.op == TOKsuper) && global.params.vsafe)
        {
            ThisExp ve = cast(ThisExp)exp.e1;
            VarDeclaration v = ve.var.isVarDeclaration();
            if (v)
            {
                if (!checkAddressVar(v))
                {
                    result = new ErrorExp();
                    return;
                }
            }
        }
        else if (exp.e1.op == TOKcall)
        {
            CallExp ce = cast(CallExp)exp.e1;
            if (ce.e1.type.ty == Tfunction)
            {
                TypeFunction tf = cast(TypeFunction)ce.e1.type;
                if (tf.isref && sc.func && !sc.intypeof && sc.func.setUnsafe())
                {
                    exp.error("cannot take address of ref return of %s() in @safe function %s",
                        ce.e1.toChars(), sc.func.toChars());
                }
            }
        }
        else if (exp.e1.op == TOKindex)
        {
            /* For:
             *   int[3] a;
             *   &a[i]
             * check 'a' the same as for a regular variable
             */
            IndexExp ei = cast(IndexExp)exp.e1;
            Type tyi = ei.e1.type.toBasetype();
            if (tyi.ty == Tsarray && ei.e1.op == TOKvar)
            {
                VarExp ve = cast(VarExp)ei.e1;
                VarDeclaration v = ve.var.isVarDeclaration();
                if (v)
                {
                    if (!checkAddressVar(v))
                    {
                        result = new ErrorExp();
                        return;
                    }

                    ve.checkPurity(sc, v);
                }
            }
        }
        else if (wasCond)
        {
            /* a ? b : c was transformed to *(a ? &b : &c), but we still
             * need to do safety checks
             */
            assert(exp.e1.op == TOKstar);
            PtrExp pe = cast(PtrExp)exp.e1;
            assert(pe.e1.op == TOKquestion);
            CondExp ce = cast(CondExp)pe.e1;
            assert(ce.e1.op == TOKaddress);
            assert(ce.e2.op == TOKaddress);

            // Re-run semantic on the address expressions only
            ce.e1.type = null;
            ce.e1 = ce.e1.semantic(sc);
            ce.e2.type = null;
            ce.e2 = ce.e2.semantic(sc);
        }
        result = exp.optimize(WANTvalue);
    }

    override void visit(PtrExp exp)
    {
        static if (LOGSEMANTIC)
        {
            printf("PtrExp::semantic('%s')\n", exp.toChars());
        }
        if (exp.type)
        {
            result = exp;
            return;
        }

        Expression e = exp.op_overload(sc);
        if (e)
        {
            result = e;
            return;
        }

        Type tb = exp.e1.type.toBasetype();
        switch (tb.ty)
        {
        case Tpointer:
            exp.type = (cast(TypePointer)tb).next;
            break;

        case Tsarray:
        case Tarray:
            if (isNonAssignmentArrayOp(exp.e1))
                goto default;
            exp.error("using * on an array is no longer supported; use *(%s).ptr instead", exp.e1.toChars());
            exp.type = (cast(TypeArray)tb).next;
            exp.e1 = exp.e1.castTo(sc, exp.type.pointerTo());
            break;

        default:
            exp.error("can only * a pointer, not a '%s'", exp.e1.type.toChars());
            goto case Terror;
        case Terror:
            {
                result = new ErrorExp();
                return;
            }
        }
        if (exp.checkValue())
        {
            result = new ErrorExp();
            return;
        }

        result = exp;
    }

    override void visit(NegExp exp)
    {
        static if (LOGSEMANTIC)
        {
            printf("NegExp::semantic('%s')\n", exp.toChars());
        }
        if (exp.type)
        {
            result = exp;
            return;
        }

        Expression e = exp.op_overload(sc);
        if (e)
        {
            result = e;
            return;
        }

        exp.type = exp.e1.type;
        Type tb = exp.type.toBasetype();
        if (tb.ty == Tarray || tb.ty == Tsarray)
        {
            if (!isArrayOpValid(exp.e1))
            {
                result = arrayOpInvalidError(exp);
                return;
            }
            result = exp;
            return;
        }
        if (!Target.isVectorOpSupported(tb, exp.op))
        {
            result = exp.incompatibleTypes();
            return;
        }
        if (exp.e1.checkNoBool())
        {
            result = new ErrorExp();
            return;
        }
        if (exp.e1.checkArithmetic())
        {
            result = new ErrorExp();
            return;
        }

        result = exp;
    }

    override void visit(UAddExp exp)
    {
        static if (LOGSEMANTIC)
        {
            printf("UAddExp::semantic('%s')\n", exp.toChars());
        }
        assert(!exp.type);

        Expression e = exp.op_overload(sc);
        if (e)
        {
            result = e;
            return;
        }

        if (!Target.isVectorOpSupported(exp.e1.type.toBasetype(), exp.op))
        {
            result = exp.incompatibleTypes();
            return;
        }
        if (exp.e1.checkNoBool())
        {
            result = new ErrorExp();
            return;
        }
        if (exp.e1.checkArithmetic())
        {
            result = new ErrorExp();
            return;
        }

        result = exp.e1;
    }

    override void visit(ComExp exp)
    {
        if (exp.type)
        {
            result = exp;
            return;
        }

        Expression e = exp.op_overload(sc);
        if (e)
        {
            result = e;
            return;
        }

        exp.type = exp.e1.type;
        Type tb = exp.type.toBasetype();
        if (tb.ty == Tarray || tb.ty == Tsarray)
        {
            if (!isArrayOpValid(exp.e1))
            {
                result = arrayOpInvalidError(exp);
                return;
            }
            result = exp;
            return;
        }
        if (!Target.isVectorOpSupported(tb, exp.op))
        {
            result = exp.incompatibleTypes();
            return;
        }
        if (exp.e1.checkNoBool())
        {
            result = new ErrorExp();
            return;
        }
        if (exp.e1.checkIntegral())
        {
            result = new ErrorExp();
            return;
        }

        result = exp;
    }

    override void visit(NotExp e)
    {
        if (e.type)
        {
            result = e;
            return;
        }

        e.setNoderefOperand();

        // Note there is no operator overload
        if (Expression ex = unaSemantic(e, sc))
        {
            result = ex;
            return;
        }
        e.e1 = resolveProperties(sc, e.e1);
        e.e1 = e.e1.toBoolean(sc);
        if (e.e1.type == Type.terror)
        {
            result = e.e1;
            return;
        }

        if (!Target.isVectorOpSupported(e.e1.type.toBasetype(), e.op))
        {
            result = e.incompatibleTypes();
        }
        // https://issues.dlang.org/show_bug.cgi?id=13910
        // Today NotExp can take an array as its operand.
        if (checkNonAssignmentArrayOp(e.e1))
        {
            result = new ErrorExp();
            return;
        }

        e.type = Type.tbool;
        result = e;
    }

    override void visit(DeleteExp exp)
    {
        if (Expression ex = unaSemantic(exp, sc))
        {
            result = ex;
            return;
        }
        exp.e1 = resolveProperties(sc, exp.e1);
        exp.e1 = exp.e1.modifiableLvalue(sc, null);
        if (exp.e1.op == TOKerror)
        {
            result = exp.e1;
            return;
        }
        exp.type = Type.tvoid;

        AggregateDeclaration ad = null;
        Type tb = exp.e1.type.toBasetype();
        switch (tb.ty)
        {
        case Tclass:
            {
                auto cd = (cast(TypeClass)tb).sym;
                if (cd.isCOMinterface())
                {
                    /* Because COM classes are deleted by IUnknown.Release()
                     */
                    exp.error("cannot delete instance of COM interface %s", cd.toChars());
                    result = new ErrorExp();
                    return;
                }
                ad = cd;
                break;
            }
        case Tpointer:
            tb = (cast(TypePointer)tb).next.toBasetype();
            if (tb.ty == Tstruct)
            {
                ad = (cast(TypeStruct)tb).sym;
                auto f = ad.aggDelete;
                auto fd = ad.dtor;
                if (!f)
                {
                    semanticTypeInfo(sc, tb);
                    break;
                }

                /* Construct:
                 *      ea = copy e1 to a tmp to do side effects only once
                 *      eb = call destructor
                 *      ec = call deallocator
                 */
                Expression ea = null;
                Expression eb = null;
                Expression ec = null;
                VarDeclaration v = null;
                if (fd && f)
                {
                    v = copyToTemp(0, "__tmpea", exp.e1);
                    v.semantic(sc);
                    ea = new DeclarationExp(exp.loc, v);
                    ea.type = v.type;
                }
                if (fd)
                {
                    Expression e = ea ? new VarExp(exp.loc, v) : exp.e1;
                    e = new DotVarExp(Loc(), e, fd, false);
                    eb = new CallExp(exp.loc, e);
                    eb = eb.semantic(sc);
                }
                if (f)
                {
                    Type tpv = Type.tvoid.pointerTo();
                    Expression e = ea ? new VarExp(exp.loc, v) : exp.e1.castTo(sc, tpv);
                    e = new CallExp(exp.loc, new VarExp(exp.loc, f, false), e);
                    ec = e.semantic(sc);
                }
                ea = Expression.combine(ea, eb);
                ea = Expression.combine(ea, ec);
                assert(ea);
                result = ea;
                return;
            }
            break;

        case Tarray:
            {
                Type tv = tb.nextOf().baseElemOf();
                if (tv.ty == Tstruct)
                {
                    ad = (cast(TypeStruct)tv).sym;
                    if (ad.dtor)
                        semanticTypeInfo(sc, ad.type);
                }
                break;
            }
        default:
            exp.error("cannot delete type %s", exp.e1.type.toChars());
            result = new ErrorExp();
            return;
        }

        bool err = false;
        if (ad)
        {
            if (ad.dtor)
            {
                err |= exp.checkPurity(sc, ad.dtor);
                err |= exp.checkSafety(sc, ad.dtor);
                err |= exp.checkNogc(sc, ad.dtor);
            }
            if (ad.aggDelete && tb.ty != Tarray)
            {
                err |= exp.checkPurity(sc, ad.aggDelete);
                err |= exp.checkSafety(sc, ad.aggDelete);
                err |= exp.checkNogc(sc, ad.aggDelete);
            }
            if (err)
            {
                result = new ErrorExp();
                return;
            }
        }

        if (!sc.intypeof && sc.func &&
            !exp.isRAII &&
            sc.func.setUnsafe())
        {
            exp.error("%s is not @safe but is used in @safe function %s", exp.toChars(), sc.func.toChars());
            err = true;
        }
        if (err)
        {
            result = new ErrorExp();
            return;
        }

        result = exp;
    }

    override void visit(CastExp exp)
    {
        static if (LOGSEMANTIC)
        {
            printf("CastExp::semantic('%s')\n", exp.toChars());
        }
        //static int x; assert(++x < 10);
        if (exp.type)
        {
            result = exp;
            return;
        }

        if (exp.to)
        {
            exp.to = exp.to.semantic(exp.loc, sc);
            if (exp.to == Type.terror)
            {
                result = new ErrorExp();
                return;
            }

            if (!exp.to.hasPointers())
                exp.setNoderefOperand();

            // When e1 is a template lambda, this cast may instantiate it with
            // the type 'to'.
            exp.e1 = inferType(exp.e1, exp.to);
        }

        if (auto e = unaSemantic(exp, sc))
        {
            result = e;
            return;
        }
        auto e1x = resolveProperties(sc, exp.e1);
        if (e1x.op == TOKerror)
        {
            result = e1x;
            return;
        }
        if (e1x.checkType())
        {
            result = new ErrorExp();
            return;
        }
        exp.e1 = e1x;

        if (!exp.e1.type)
        {
            exp.error("cannot cast %s", exp.e1.toChars());
            result = new ErrorExp();
            return;
        }

        if (!exp.to) // Handle cast(const) and cast(immutable), etc.
        {
            exp.to = exp.e1.type.castMod(exp.mod);
            exp.to = exp.to.semantic(exp.loc, sc);
            if (exp.to == Type.terror)
            {
                result = new ErrorExp();
                return;
            }
        }

        if (exp.to.ty == Ttuple)
        {
            exp.error("cannot cast %s to tuple type %s", exp.e1.toChars(), exp.to.toChars());
            result = new ErrorExp();
            return;
        }

        // cast(void) is used to mark e1 as unused, so it is safe
        if (exp.to.ty == Tvoid)
        {
            exp.type = exp.to;
            result = exp;
            return;
        }

        if (!exp.to.equals(exp.e1.type) && exp.mod == cast(ubyte)~0)
        {
            if (Expression e = exp.op_overload(sc))
            {
                result = e.implicitCastTo(sc, exp.to);
                return;
            }
        }

        Type t1b = exp.e1.type.toBasetype();
        Type tob = exp.to.toBasetype();

        if (tob.ty == Tstruct && !tob.equals(t1b))
        {
            /* Look to replace:
             *  cast(S)t
             * with:
             *  S(t)
             */

            // Rewrite as to.call(e1)
            Expression e = new TypeExp(exp.loc, exp.to);
            e = new CallExp(exp.loc, e, exp.e1);
            e = e.trySemantic(sc);
            if (e)
            {
                result = e;
                return;
            }
        }

        if (!t1b.equals(tob) && (t1b.ty == Tarray || t1b.ty == Tsarray))
        {
            if (checkNonAssignmentArrayOp(exp.e1))
            {
                result = new ErrorExp();
                return;
            }
        }

        // Look for casting to a vector type
        if (tob.ty == Tvector && t1b.ty != Tvector)
        {
            result = new VectorExp(exp.loc, exp.e1, exp.to);
            return;
        }

        Expression ex = exp.e1.castTo(sc, exp.to);
        if (ex.op == TOKerror)
        {
            result = ex;
            return;
        }

        // Check for unsafe casts
        if (sc.func && !sc.intypeof &&
            !isSafeCast(ex, t1b, tob) &&
            sc.func.setUnsafe())
        {
            exp.error("cast from %s to %s not allowed in safe code", exp.e1.type.toChars(), exp.to.toChars());
            result = new ErrorExp();
            return;
        }

        result = ex;
    }

    override void visit(VectorExp exp)
    {
        static if (LOGSEMANTIC)
        {
            printf("VectorExp::semantic('%s')\n", exp.toChars());
        }
        if (exp.type)
        {
            result = exp;
            return;
        }

        exp.e1 = exp.e1.semantic(sc);
        exp.type = exp.to.semantic(exp.loc, sc);
        if (exp.e1.op == TOKerror || exp.type.ty == Terror)
        {
            result = exp.e1;
            return;
        }

        Type tb = exp.type.toBasetype();
        assert(tb.ty == Tvector);
        TypeVector tv = cast(TypeVector)tb;
        Type te = tv.elementType();
        exp.dim = cast(int)(tv.size(exp.loc) / te.size(exp.loc));

        bool checkElem(Expression elem)
        {
            if (elem.isConst() == 1)
                return false;

             exp.error("constant expression expected, not %s", elem.toChars());
             return true;
        }

        exp.e1 = exp.e1.optimize(WANTvalue);
        bool res;
        if (exp.e1.op == TOKarrayliteral)
        {
            foreach (i; 0 .. exp.dim)
            {
                // Do not stop on first error - check all AST nodes even if error found
                res |= checkElem((cast(ArrayLiteralExp)exp.e1).getElement(i));
            }
        }
        else if (exp.e1.type.ty == Tvoid)
            checkElem(exp.e1);

        result = res ? new ErrorExp() : exp;
    }

    override void visit(SliceExp exp)
    {
        static if (LOGSEMANTIC)
        {
            printf("SliceExp::semantic('%s')\n", exp.toChars());
        }
        if (exp.type)
        {
            result = exp;
            return;
        }

        // operator overloading should be handled in ArrayExp already.
        if (Expression ex = unaSemantic(exp, sc))
        {
            result = ex;
            return;
        }
        exp.e1 = resolveProperties(sc, exp.e1);
        if (exp.e1.op == TOKtype && exp.e1.type.ty != Ttuple)
        {
            if (exp.lwr || exp.upr)
            {
                exp.error("cannot slice type '%s'", exp.e1.toChars());
                result = new ErrorExp();
                return;
            }
            Expression e = new TypeExp(exp.loc, exp.e1.type.arrayOf());
            result = e.semantic(sc);
            return;
        }
        if (!exp.lwr && !exp.upr)
        {
            if (exp.e1.op == TOKarrayliteral)
            {
                // Convert [a,b,c][] to [a,b,c]
                Type t1b = exp.e1.type.toBasetype();
                Expression e = exp.e1;
                if (t1b.ty == Tsarray)
                {
                    e = e.copy();
                    e.type = t1b.nextOf().arrayOf();
                }
                result = e;
                return;
            }
            if (exp.e1.op == TOKslice)
            {
                // Convert e[][] to e[]
                SliceExp se = cast(SliceExp)exp.e1;
                if (!se.lwr && !se.upr)
                {
                    result = se;
                    return;
                }
            }
            if (isArrayOpOperand(exp.e1))
            {
                // Convert (a[]+b[])[] to a[]+b[]
                result = exp.e1;
                return;
            }
        }
        if (exp.e1.op == TOKerror)
        {
            result = exp.e1;
            return;
        }
        if (exp.e1.type.ty == Terror)
        {
            result = new ErrorExp();
            return;
        }

        Type t1b = exp.e1.type.toBasetype();
        if (t1b.ty == Tpointer)
        {
            if ((cast(TypePointer)t1b).next.ty == Tfunction)
            {
                exp.error("cannot slice function pointer %s", exp.e1.toChars());
                result = new ErrorExp();
            }
            if (!exp.lwr || !exp.upr)
            {
                exp.error("need upper and lower bound to slice pointer");
                result = new ErrorExp();
                return;
            }
            if (sc.func && !sc.intypeof && sc.func.setUnsafe())
            {
                exp.error("pointer slicing not allowed in safe functions");
                result = new ErrorExp();
                return;
            }
        }
        else if (t1b.ty == Tarray)
        {
        }
        else if (t1b.ty == Tsarray)
        {
        }
        else if (t1b.ty == Ttuple)
        {
            if (!exp.lwr && !exp.upr)
            {
                result = exp.e1;
                return;
            }
            if (!exp.lwr || !exp.upr)
            {
                exp.error("need upper and lower bound to slice tuple");
                result = new ErrorExp();
                return;
            }
        }
        else if (t1b.ty == Tvector)
        {
            // Convert e1 to corresponding static array
            TypeVector tv1 = cast(TypeVector)t1b;
            t1b = tv1.basetype;
            t1b = t1b.castMod(tv1.mod);
            exp.e1.type = t1b;
        }
        else
        {
            exp.error("%s cannot be sliced with []", t1b.ty == Tvoid ? exp.e1.toChars() : t1b.toChars());
            result = new ErrorExp();
            return;
        }

        /* Run semantic on lwr and upr.
         */
        Scope* scx = sc;
        if (t1b.ty == Tsarray || t1b.ty == Tarray || t1b.ty == Ttuple)
        {
            // Create scope for 'length' variable
            ScopeDsymbol sym = new ArrayScopeSymbol(sc, exp);
            sym.loc = exp.loc;
            sym.parent = sc.scopesym;
            sc = sc.push(sym);
        }
        if (exp.lwr)
        {
            if (t1b.ty == Ttuple)
                sc = sc.startCTFE();
            exp.lwr = exp.lwr.semantic(sc);
            exp.lwr = resolveProperties(sc, exp.lwr);
            if (t1b.ty == Ttuple)
                sc = sc.endCTFE();
            exp.lwr = exp.lwr.implicitCastTo(sc, Type.tsize_t);
        }
        if (exp.upr)
        {
            if (t1b.ty == Ttuple)
                sc = sc.startCTFE();
            exp.upr = exp.upr.semantic(sc);
            exp.upr = resolveProperties(sc, exp.upr);
            if (t1b.ty == Ttuple)
                sc = sc.endCTFE();
            exp.upr = exp.upr.implicitCastTo(sc, Type.tsize_t);
        }
        if (sc != scx)
            sc = sc.pop();
        if (exp.lwr && exp.lwr.type == Type.terror || exp.upr && exp.upr.type == Type.terror)
        {
            result = new ErrorExp();
            return;
        }

        if (t1b.ty == Ttuple)
        {
            exp.lwr = exp.lwr.ctfeInterpret();
            exp.upr = exp.upr.ctfeInterpret();
            uinteger_t i1 = exp.lwr.toUInteger();
            uinteger_t i2 = exp.upr.toUInteger();

            TupleExp te;
            TypeTuple tup;
            size_t length;
            if (exp.e1.op == TOKtuple) // slicing an expression tuple
            {
                te = cast(TupleExp)exp.e1;
                tup = null;
                length = te.exps.dim;
            }
            else if (exp.e1.op == TOKtype) // slicing a type tuple
            {
                te = null;
                tup = cast(TypeTuple)t1b;
                length = Parameter.dim(tup.arguments);
            }
            else
                assert(0);

            if (i2 < i1 || length < i2)
            {
                exp.error("string slice `[%llu .. %llu]` is out of bounds", i1, i2);
                result = new ErrorExp();
                return;
            }

            size_t j1 = cast(size_t)i1;
            size_t j2 = cast(size_t)i2;
            Expression e;
            if (exp.e1.op == TOKtuple)
            {
                auto exps = new Expressions();
                exps.setDim(j2 - j1);
                for (size_t i = 0; i < j2 - j1; i++)
                {
                    (*exps)[i] = (*te.exps)[j1 + i];
                }
                e = new TupleExp(exp.loc, te.e0, exps);
            }
            else
            {
                auto args = new Parameters();
                args.reserve(j2 - j1);
                for (size_t i = j1; i < j2; i++)
                {
                    Parameter arg = Parameter.getNth(tup.arguments, i);
                    args.push(arg);
                }
                e = new TypeExp(exp.e1.loc, new TypeTuple(args));
            }
            e = e.semantic(sc);
            result = e;
            return;
        }

        exp.type = t1b.nextOf().arrayOf();
        // Allow typedef[] -> typedef[]
        if (exp.type.equals(t1b))
            exp.type = exp.e1.type;

        if (exp.lwr && exp.upr)
        {
            exp.lwr = exp.lwr.optimize(WANTvalue);
            exp.upr = exp.upr.optimize(WANTvalue);

            IntRange lwrRange = getIntRange(exp.lwr);
            IntRange uprRange = getIntRange(exp.upr);

            if (t1b.ty == Tsarray || t1b.ty == Tarray)
            {
                Expression el = new ArrayLengthExp(exp.loc, exp.e1);
                el = el.semantic(sc);
                el = el.optimize(WANTvalue);
                if (el.op == TOKint64)
                {
                    dinteger_t length = el.toInteger();
                    auto bounds = IntRange(SignExtendedNumber(0), SignExtendedNumber(length));
                    exp.upperIsInBounds = bounds.contains(uprRange);
                }
            }
            else if (t1b.ty == Tpointer)
            {
                exp.upperIsInBounds = true;
            }
            else
                assert(0);

            exp.lowerIsLessThanUpper = (lwrRange.imax <= uprRange.imin);

            //printf("upperIsInBounds = %d lowerIsLessThanUpper = %d\n", upperIsInBounds, lowerIsLessThanUpper);
        }

        result = exp;
    }

    override void visit(ArrayLengthExp e)
    {
        static if (LOGSEMANTIC)
        {
            printf("ArrayLengthExp::semantic('%s')\n", e.toChars());
        }
        if (e.type)
        {
            result = e;
            return;
        }

        if (Expression ex = unaSemantic(e, sc))
        {
            result = ex;
            return;
        }
        e.e1 = resolveProperties(sc, e.e1);

        e.type = Type.tsize_t;
        result = e;
    }

    override void visit(ArrayExp exp)
    {
        static if (LOGSEMANTIC)
        {
            printf("ArrayExp::semantic('%s')\n", exp.toChars());
        }
        assert(!exp.type);
        Expression e = exp.op_overload(sc);
        if (e)
        {
            result = e;
            return;
        }

        if (isAggregate(exp.e1.type))
            exp.error("no [] operator overload for type %s", exp.e1.type.toChars());
        else
            exp.error("only one index allowed to index %s", exp.e1.type.toChars());
        result = new ErrorExp();
    }

    override void visit(DotExp exp)
    {
        static if (LOGSEMANTIC)
        {
            printf("DotExp::semantic('%s')\n", exp.toChars());
            if (exp.type)
                printf("\ttype = %s\n", exp.type.toChars());
        }
        exp.e1 = exp.e1.semantic(sc);
        exp.e2 = exp.e2.semantic(sc);

        if (exp.e1.op == TOKtype)
        {
            result = exp.e2;
            return;
        }
        if (exp.e2.op == TOKtype)
        {
            result = exp.e2;
            return;
        }
        if (exp.e2.op == TOKtemplate)
        {
            auto td = (cast(TemplateExp)exp.e2).td;
            Expression e = new DotTemplateExp(exp.loc, exp.e1, td);
            result = e.semantic(sc);
            return;
        }
        if (!exp.type)
            exp.type = exp.e2.type;
        result = exp;
    }

    override void visit(CommaExp e)
    {
        if (e.type)
        {
            result = e;
            return;
        }

        // Allow `((a,b),(x,y))`
        if (e.allowCommaExp)
        {
            CommaExp.allow(e.e1);
            CommaExp.allow(e.e2);
        }

        if (Expression ex = binSemanticProp(e, sc))
        {
            result = ex;
            return;
        }
        e.e1 = e.e1.addDtorHook(sc);

        if (checkNonAssignmentArrayOp(e.e1))
        {
            result = new ErrorExp();
            return;
        }

        e.type = e.e2.type;
        if (e.type !is Type.tvoid && !e.allowCommaExp && !e.isGenerated)
            e.deprecation("Using the result of a comma expression is deprecated");
        result = e;
    }

    override void visit(IntervalExp e)
    {
        static if (LOGSEMANTIC)
        {
            printf("IntervalExp::semantic('%s')\n", e.toChars());
        }
        if (e.type)
        {
            result = e;
            return;
        }

        Expression le = e.lwr;
        le = le.semantic(sc);
        le = resolveProperties(sc, le);

        Expression ue = e.upr;
        ue = ue.semantic(sc);
        ue = resolveProperties(sc, ue);

        if (le.op == TOKerror)
        {
            result = le;
            return;
        }
        if (ue.op == TOKerror)
        {
            result = ue;
            return;
        }

        e.lwr = le;
        e.upr = ue;

        e.type = Type.tvoid;
        result = e;
    }

    override void visit(DelegatePtrExp e)
    {
        static if (LOGSEMANTIC)
        {
            printf("DelegatePtrExp::semantic('%s')\n", e.toChars());
        }
        if (!e.type)
        {
            unaSemantic(e, sc);
            e.e1 = resolveProperties(sc, e.e1);

            if (e.e1.op == TOKerror)
            {
                result = e.e1;
                return;
            }
            e.type = Type.tvoidptr;
        }
        result = e;
    }

    override void visit(DelegateFuncptrExp e)
    {
        static if (LOGSEMANTIC)
        {
            printf("DelegateFuncptrExp::semantic('%s')\n", e.toChars());
        }
        if (!e.type)
        {
            unaSemantic(e, sc);
            e.e1 = resolveProperties(sc, e.e1);
            if (e.e1.op == TOKerror)
            {
                result = e.e1;
                return;
            }
            e.type = e.e1.type.nextOf().pointerTo();
        }
        result = e;
    }

    override void visit(IndexExp exp)
    {
        static if (LOGSEMANTIC)
        {
            printf("IndexExp::semantic('%s')\n", exp.toChars());
        }
        if (exp.type)
        {
            result = exp;
            return;
        }

        // operator overloading should be handled in ArrayExp already.
        if (!exp.e1.type)
            exp.e1 = exp.e1.semantic(sc);
        assert(exp.e1.type); // semantic() should already be run on it
        if (exp.e1.op == TOKtype && exp.e1.type.ty != Ttuple)
        {
            exp.e2 = exp.e2.semantic(sc);
            exp.e2 = resolveProperties(sc, exp.e2);
            Type nt;
            if (exp.e2.op == TOKtype)
                nt = new TypeAArray(exp.e1.type, exp.e2.type);
            else
                nt = new TypeSArray(exp.e1.type, exp.e2);
            Expression e = new TypeExp(exp.loc, nt);
            result = e.semantic(sc);
            return;
        }
        if (exp.e1.op == TOKerror)
        {
            result = exp.e1;
            return;
        }
        if (exp.e1.type.ty == Terror)
        {
            result = new ErrorExp();
            return;
        }

        // Note that unlike C we do not implement the int[ptr]

        Type t1b = exp.e1.type.toBasetype();

        if (t1b.ty == Tvector)
        {
            // Convert e1 to corresponding static array
            TypeVector tv1 = cast(TypeVector)t1b;
            t1b = tv1.basetype;
            t1b = t1b.castMod(tv1.mod);
            exp.e1.type = t1b;
        }

        /* Run semantic on e2
         */
        Scope* scx = sc;
        if (t1b.ty == Tsarray || t1b.ty == Tarray || t1b.ty == Ttuple)
        {
            // Create scope for 'length' variable
            ScopeDsymbol sym = new ArrayScopeSymbol(sc, exp);
            sym.loc = exp.loc;
            sym.parent = sc.scopesym;
            sc = sc.push(sym);
        }
        if (t1b.ty == Ttuple)
            sc = sc.startCTFE();
        exp.e2 = exp.e2.semantic(sc);
        exp.e2 = resolveProperties(sc, exp.e2);
        if (t1b.ty == Ttuple)
            sc = sc.endCTFE();
        if (exp.e2.op == TOKtuple)
        {
            TupleExp te = cast(TupleExp)exp.e2;
            if (te.exps && te.exps.dim == 1)
                exp.e2 = Expression.combine(te.e0, (*te.exps)[0]); // bug 4444 fix
        }
        if (sc != scx)
            sc = sc.pop();
        if (exp.e2.type == Type.terror)
        {
            result = new ErrorExp();
            return;
        }

        if (checkNonAssignmentArrayOp(exp.e1))
        {
            result = new ErrorExp();
            return;
        }

        switch (t1b.ty)
        {
        case Tpointer:
            if ((cast(TypePointer)t1b).next.ty == Tfunction)
            {
                exp.error("cannot index function pointer %s", exp.e1.toChars());
                result = new ErrorExp();
                return;
            }
            exp.e2 = exp.e2.implicitCastTo(sc, Type.tsize_t);
            if (exp.e2.type == Type.terror)
            {
                result = new ErrorExp();
                return;
            }
            exp.e2 = exp.e2.optimize(WANTvalue);
            if (exp.e2.op == TOKint64 && exp.e2.toInteger() == 0)
            {
            }
            else if (sc.func && sc.func.setUnsafe())
            {
                exp.error("safe function '%s' cannot index pointer '%s'", sc.func.toPrettyChars(), exp.e1.toChars());
                result = new ErrorExp();
                return;
            }
            exp.type = (cast(TypeNext)t1b).next;
            break;

        case Tarray:
            exp.e2 = exp.e2.implicitCastTo(sc, Type.tsize_t);
            if (exp.e2.type == Type.terror)
            {
                result = new ErrorExp();
                return;
            }
            exp.type = (cast(TypeNext)t1b).next;
            break;

        case Tsarray:
            {
                exp.e2 = exp.e2.implicitCastTo(sc, Type.tsize_t);
                if (exp.e2.type == Type.terror)
                {
                    result = new ErrorExp();
                    return;
                }
                exp.type = t1b.nextOf();
                break;
            }
        case Taarray:
            {
                TypeAArray taa = cast(TypeAArray)t1b;
                /* We can skip the implicit conversion if they differ only by
                 * constness
                 * https://issues.dlang.org/show_bug.cgi?id=2684
                 * see also bug https://issues.dlang.org/show_bug.cgi?id=2954 b
                 */
                if (!arrayTypeCompatibleWithoutCasting(exp.e2.loc, exp.e2.type, taa.index))
                {
                    exp.e2 = exp.e2.implicitCastTo(sc, taa.index); // type checking
                    if (exp.e2.type == Type.terror)
                    {
                        result = new ErrorExp();
                        return;
                    }
                }

                semanticTypeInfo(sc, taa);

                exp.type = taa.next;
                break;
            }
        case Ttuple:
            {
                exp.e2 = exp.e2.implicitCastTo(sc, Type.tsize_t);
                if (exp.e2.type == Type.terror)
                {
                    result = new ErrorExp();
                    return;
                }
                exp.e2 = exp.e2.ctfeInterpret();
                uinteger_t index = exp.e2.toUInteger();

                TupleExp te;
                TypeTuple tup;
                size_t length;
                if (exp.e1.op == TOKtuple)
                {
                    te = cast(TupleExp)exp.e1;
                    tup = null;
                    length = te.exps.dim;
                }
                else if (exp.e1.op == TOKtype)
                {
                    te = null;
                    tup = cast(TypeTuple)t1b;
                    length = Parameter.dim(tup.arguments);
                }
                else
                    assert(0);

                if (length <= index)
                {
                    exp.error("array index [%llu] is outside array bounds [0 .. %llu]", index, cast(ulong)length);
                    result = new ErrorExp();
                    return;
                }
                Expression e;
                if (exp.e1.op == TOKtuple)
                {
                    e = (*te.exps)[cast(size_t)index];
                    e = Expression.combine(te.e0, e);
                }
                else
                    e = new TypeExp(exp.e1.loc, Parameter.getNth(tup.arguments, cast(size_t)index).type);
                result = e;
                return;
            }
        default:
            exp.error("%s must be an array or pointer type, not %s", exp.e1.toChars(), exp.e1.type.toChars());
            result = new ErrorExp();
            return;
        }

        if (t1b.ty == Tsarray || t1b.ty == Tarray)
        {
            Expression el = new ArrayLengthExp(exp.loc, exp.e1);
            el = el.semantic(sc);
            el = el.optimize(WANTvalue);
            if (el.op == TOKint64)
            {
                exp.e2 = exp.e2.optimize(WANTvalue);
                dinteger_t length = el.toInteger();
                if (length)
                {
                    auto bounds = IntRange(SignExtendedNumber(0), SignExtendedNumber(length - 1));
                    exp.indexIsInBounds = bounds.contains(getIntRange(exp.e2));
                }
            }
        }

        result = exp;
    }

    override void visit(PostExp exp)
    {
        static if (LOGSEMANTIC)
        {
            printf("PostExp::semantic('%s')\n", exp.toChars());
        }
        if (exp.type)
        {
            result = exp;
            return;
        }

        if (Expression ex = binSemantic(exp, sc))
        {
            result = ex;
            return;
        }
        Expression e1x = resolveProperties(sc, exp.e1);
        if (e1x.op == TOKerror)
        {
            result = e1x;
            return;
        }
        exp.e1 = e1x;

        Expression e = exp.op_overload(sc);
        if (e)
        {
            result = e;
            return;
        }

        if (exp.e1.checkReadModifyWrite(exp.op))
        {
            result = new ErrorExp();
            return;
        }
        if (exp.e1.op == TOKslice)
        {
            const(char)* s = exp.op == TOKplusplus ? "increment" : "decrement";
            exp.error("cannot post-%s array slice '%s', use pre-%s instead", s, exp.e1.toChars(), s);
            result = new ErrorExp();
            return;
        }

        exp.e1 = exp.e1.optimize(WANTvalue);

        Type t1 = exp.e1.type.toBasetype();
        if (t1.ty == Tclass || t1.ty == Tstruct || exp.e1.op == TOKarraylength)
        {
            /* Check for operator overloading,
             * but rewrite in terms of ++e instead of e++
             */

            /* If e1 is not trivial, take a reference to it
             */
            Expression de = null;
            if (exp.e1.op != TOKvar && exp.e1.op != TOKarraylength)
            {
                // ref v = e1;
                auto v = copyToTemp(STCref, "__postref", exp.e1);
                de = new DeclarationExp(exp.loc, v);
                exp.e1 = new VarExp(exp.e1.loc, v);
            }

            /* Rewrite as:
             * auto tmp = e1; ++e1; tmp
             */
            auto tmp = copyToTemp(0, "__pitmp", exp.e1);
            Expression ea = new DeclarationExp(exp.loc, tmp);

            Expression eb = exp.e1.syntaxCopy();
            eb = new PreExp(exp.op == TOKplusplus ? TOKpreplusplus : TOKpreminusminus, exp.loc, eb);

            Expression ec = new VarExp(exp.loc, tmp);

            // Combine de,ea,eb,ec
            if (de)
                ea = new CommaExp(exp.loc, de, ea);
            e = new CommaExp(exp.loc, ea, eb);
            e = new CommaExp(exp.loc, e, ec);
            e = e.semantic(sc);
            result = e;
            return;
        }

        exp.e1 = exp.e1.modifiableLvalue(sc, exp.e1);

        e = exp;
        if (exp.e1.checkScalar())
        {
            result = new ErrorExp();
            return;
        }
        if (exp.e1.checkNoBool())
        {
            result = new ErrorExp();
            return;
        }

        if (exp.e1.type.ty == Tpointer)
            e = scaleFactor(exp, sc);
        else
            exp.e2 = exp.e2.castTo(sc, exp.e1.type);
        e.type = exp.e1.type;
        result = e;
    }

    override void visit(PreExp exp)
    {
        Expression e = exp.op_overload(sc);
        // printf("PreExp::semantic('%s')\n", toChars());
        if (e)
        {
            result = e;
            return;
        }

        // Rewrite as e1+=1 or e1-=1
        if (exp.op == TOKpreplusplus)
            e = new AddAssignExp(exp.loc, exp.e1, new IntegerExp(exp.loc, 1, Type.tint32));
        else
            e = new MinAssignExp(exp.loc, exp.e1, new IntegerExp(exp.loc, 1, Type.tint32));
        result = e.semantic(sc);
    }

    override void visit(AssignExp exp)
    {
        static if (LOGSEMANTIC)
        {
            printf("AssignExp::semantic('%s')\n", exp.toChars());
        }
        //printf("exp.e1.op = %d, '%s'\n", exp.e1.op, Token.toChars(exp.e1.op));
        //printf("exp.e2.op = %d, '%s'\n", exp.e2.op, Token.toChars(exp.e2.op));
        if (exp.type)
        {
            result = exp;
            return;
        }

        Expression e1old = exp.e1;

        if (exp.e2.op == TOKcomma)
        {
            /* Rewrite to get rid of the comma from rvalue
             */
            if (!(cast(CommaExp)exp.e2).isGenerated)
                exp.deprecation("Using the result of a comma expression is deprecated");
            Expression e0;
            exp.e2 = Expression.extractLast(exp.e2, &e0);
            Expression e = Expression.combine(e0, exp);
            result = e.semantic(sc);
            return;
        }

        /* Look for operator overloading of a[arguments] = e2.
         * Do it before e1.semantic() otherwise the ArrayExp will have been
         * converted to unary operator overloading already.
         */
        if (exp.e1.op == TOKarray)
        {
            Expression res;

            ArrayExp ae = cast(ArrayExp)exp.e1;
            ae.e1 = ae.e1.semantic(sc);
            ae.e1 = resolveProperties(sc, ae.e1);
            Expression ae1old = ae.e1;

            const(bool) maybeSlice =
                (ae.arguments.dim == 0 ||
                 ae.arguments.dim == 1 && (*ae.arguments)[0].op == TOKinterval);

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
                if (search_function(ad, Id.indexass))
                {
                    // Deal with $
                    res = resolveOpDollar(sc, ae, &e0);
                    if (!res) // a[i..j] = e2 might be: a.opSliceAssign(e2, i, j)
                        goto Lfallback;
                    if (res.op == TOKerror)
                    {
                        result = res;
                        return;
                    }

                    res = exp.e2.semantic(sc);
                    if (res.op == TOKerror)
                    {
                        result = res;
                        return;
                    }
                    exp.e2 = res;

                    /* Rewrite (a[arguments] = e2) as:
                     *      a.opIndexAssign(e2, arguments)
                     */
                    Expressions* a = ae.arguments.copy();
                    a.insert(0, exp.e2);
                    res = new DotIdExp(exp.loc, ae.e1, Id.indexass);
                    res = new CallExp(exp.loc, res, a);
                    if (maybeSlice) // a[] = e2 might be: a.opSliceAssign(e2)
                        res = res.trySemantic(sc);
                    else
                        res = res.semantic(sc);
                    if (res)
                    {
                        res = Expression.combine(e0, res);
                        result = res;
                        return;
                    }
                }

            Lfallback:
                if (maybeSlice && search_function(ad, Id.sliceass))
                {
                    // Deal with $
                    res = resolveOpDollar(sc, ae, ie, &e0);
                    if (res.op == TOKerror)
                    {
                        result = res;
                        return;
                    }

                    res = exp.e2.semantic(sc);
                    if (res.op == TOKerror)
                    {
                        result = res;
                        return;
                    }
                    exp.e2 = res;

                    /* Rewrite (a[i..j] = e2) as:
                     *      a.opSliceAssign(e2, i, j)
                     */
                    auto a = new Expressions();
                    a.push(exp.e2);
                    if (ie)
                    {
                        a.push(ie.lwr);
                        a.push(ie.upr);
                    }
                    res = new DotIdExp(exp.loc, ae.e1, Id.sliceass);
                    res = new CallExp(exp.loc, res, a);
                    res = res.semantic(sc);
                    res = Expression.combine(e0, res);
                    result = res;
                    return;
                }

                // No operator overloading member function found yet, but
                // there might be an alias this to try.
                if (ad.aliasthis && t1b != ae.att1)
                {
                    if (!ae.att1 && t1b.checkAliasThisRec())
                        ae.att1 = t1b;

                    /* Rewrite (a[arguments] op e2) as:
                     *      a.aliasthis[arguments] op e2
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

        /* Run this.e1 semantic.
         */
        {
            Expression e1x = exp.e1;

            /* With UFCS, e.f = value
             * Could mean:
             *      .f(e, value)
             * or:
             *      .f(e) = value
             */
            if (e1x.op == TOKdotti)
            {
                DotTemplateInstanceExp dti = cast(DotTemplateInstanceExp)e1x;
                Expression e = dti.semanticY(sc, 1);
                if (!e)
                {
                    result = resolveUFCSProperties(sc, e1x, exp.e2);
                    return;
                }
                e1x = e;
            }
            else if (e1x.op == TOKdotid)
            {
                DotIdExp die = cast(DotIdExp)e1x;
                Expression e = die.semanticY(sc, 1);
                if (e && isDotOpDispatch(e))
                {
                    uint errors = global.startGagging();
                    e = resolvePropertiesX(sc, e, exp.e2);
                    if (global.endGagging(errors))
                        e = null; /* fall down to UFCS */
                    else
                    {
                        result = e;
                        return;
                    }
                }
                if (!e)
                {
                    result = resolveUFCSProperties(sc, e1x, exp.e2);
                    return;
                }
                e1x = e;
            }
            else
                e1x = e1x.semantic(sc);

            /* We have f = value.
             * Could mean:
             *      f(value)
             * or:
             *      f() = value
             */
            if (Expression e = resolvePropertiesX(sc, e1x, exp.e2))
            {
                result = e;
                return;
            }
            if (e1x.checkRightThis(sc))
            {
                result = new ErrorExp();
                return;
            }
            exp.e1 = e1x;
            assert(exp.e1.type);
        }
        Type t1 = exp.e1.type.toBasetype();

        /* Run this.e2 semantic.
         * Different from other binary expressions, the analysis of e2
         * depends on the result of e1 in assignments.
         */
        {
            Expression e2x = inferType(exp.e2, t1.baseElemOf());
            e2x = e2x.semantic(sc);
            e2x = resolveProperties(sc, e2x);
            if (e2x.op == TOKerror)
            {
                result = e2x;
                return;
            }
            if (e2x.checkValue())
            {
                result = new ErrorExp();
                return;
            }
            exp.e2 = e2x;
        }

        /* Rewrite tuple assignment as a tuple of assignments.
         */
        {
            Expression e2x = exp.e2;

        Ltupleassign:
            if (exp.e1.op == TOKtuple && e2x.op == TOKtuple)
            {
                TupleExp tup1 = cast(TupleExp)exp.e1;
                TupleExp tup2 = cast(TupleExp)e2x;
                size_t dim = tup1.exps.dim;
                Expression e = null;
                if (dim != tup2.exps.dim)
                {
                    exp.error("mismatched tuple lengths, %d and %d", cast(int)dim, cast(int)tup2.exps.dim);
                    result = new ErrorExp();
                    return;
                }
                if (dim == 0)
                {
                    e = new IntegerExp(exp.loc, 0, Type.tint32);
                    e = new CastExp(exp.loc, e, Type.tvoid); // avoid "has no effect" error
                    e = Expression.combine(Expression.combine(tup1.e0, tup2.e0), e);
                }
                else
                {
                    auto exps = new Expressions();
                    exps.setDim(dim);
                    for (size_t i = 0; i < dim; i++)
                    {
                        Expression ex1 = (*tup1.exps)[i];
                        Expression ex2 = (*tup2.exps)[i];
                        (*exps)[i] = new AssignExp(exp.loc, ex1, ex2);
                    }
                    e = new TupleExp(exp.loc, Expression.combine(tup1.e0, tup2.e0), exps);
                }
                result = e.semantic(sc);
                return;
            }

            /* Look for form: e1 = e2.aliasthis.
             */
            if (exp.e1.op == TOKtuple)
            {
                TupleDeclaration td = isAliasThisTuple(e2x);
                if (!td)
                    goto Lnomatch;

                assert(exp.e1.type.ty == Ttuple);
                TypeTuple tt = cast(TypeTuple)exp.e1.type;

                Expression e0;
                Expression ev = extractSideEffect(sc, "__tup", e0, e2x);

                auto iexps = new Expressions();
                iexps.push(ev);
                for (size_t u = 0; u < iexps.dim; u++)
                {
                Lexpand:
                    Expression e = (*iexps)[u];

                    Parameter arg = Parameter.getNth(tt.arguments, u);
                    //printf("[%d] iexps.dim = %d, ", u, iexps.dim);
                    //printf("e = (%s %s, %s), ", Token::tochars[e.op], e.toChars(), e.type.toChars());
                    //printf("arg = (%s, %s)\n", arg.toChars(), arg.type.toChars());

                    if (!arg || !e.type.implicitConvTo(arg.type))
                    {
                        // expand initializer to tuple
                        if (expandAliasThisTuples(iexps, u) != -1)
                        {
                            if (iexps.dim <= u)
                                break;
                            goto Lexpand;
                        }
                        goto Lnomatch;
                    }
                }
                e2x = new TupleExp(e2x.loc, e0, iexps);
                e2x = e2x.semantic(sc);
                if (e2x.op == TOKerror)
                {
                    result = e2x;
                    return;
                }
                // Do not need to overwrite this.e2
                goto Ltupleassign;
            }
        Lnomatch:
        }

        /* Inside constructor, if this is the first assignment of object field,
         * rewrite this to initializing the field.
         */
        if (exp.op == TOKassign && exp.e1.checkModifiable(sc) == 2)
        {
            //printf("[%s] change to init - %s\n", loc.toChars(), toChars());
            exp.op = TOKconstruct;

            // https://issues.dlang.org/show_bug.cgi?id=13515
            // set Index::modifiable flag for complex AA element initialization
            if (exp.e1.op == TOKindex)
            {
                Expression e1x = (cast(IndexExp)exp.e1).markSettingAAElem();
                if (e1x.op == TOKerror)
                {
                    result = e1x;
                    return;
                }
            }
        }
        else if (exp.op == TOKconstruct && exp.e1.op == TOKvar &&
                 (cast(VarExp)exp.e1).var.storage_class & (STCout | STCref))
        {
            exp.memset |= MemorySet.referenceInit;
        }

        /* If it is an assignment from a 'foreign' type,
         * check for operator overloading.
         */
        if (exp.memset & MemorySet.referenceInit)
        {
            // If this is an initialization of a reference,
            // do nothing
        }
        else if (t1.ty == Tstruct)
        {
            auto e1x = exp.e1;
            auto e2x = exp.e2;
            auto sd = (cast(TypeStruct)t1).sym;

            if (exp.op == TOKconstruct)
            {
                Type t2 = e2x.type.toBasetype();
                if (t2.ty == Tstruct && sd == (cast(TypeStruct)t2).sym)
                {
                    sd.size(exp.loc);
                    if (sd.sizeok != SIZEOKdone)
                    {
                        result = new ErrorExp();
                        return;
                    }
                    if (!sd.ctor)
                        sd.ctor = sd.searchCtor();

                    // https://issues.dlang.org/show_bug.cgi?id=15661
                    // Look for the form from last of comma chain.
                    auto e2y = e2x;
                    while (e2y.op == TOKcomma)
                        e2y = (cast(CommaExp)e2y).e2;

                    CallExp ce = (e2y.op == TOKcall) ? cast(CallExp)e2y : null;
                    DotVarExp dve = (ce && ce.e1.op == TOKdotvar)
                        ? cast(DotVarExp)ce.e1 : null;
                    if (sd.ctor && ce && dve && dve.var.isCtorDeclaration() &&
                        e2y.type.implicitConvTo(t1))
                    {
                        /* Look for form of constructor call which is:
                         *    __ctmp.ctor(arguments...)
                         */

                        /* Before calling the constructor, initialize
                         * variable with a bit copy of the default
                         * initializer
                         */
                        Expression einit;
                        if (sd.zeroInit == 1 && !sd.isNested())
                        {
                            // https://issues.dlang.org/show_bug.cgi?id=14606
                            // Always use BlitExp for the special expression: (struct = 0)
                            einit = new IntegerExp(exp.loc, 0, Type.tint32);
                        }
                        else if (sd.isNested())
                        {
                            auto sle = new StructLiteralExp(exp.loc, sd, null, t1);
                            if (!sd.fill(exp.loc, sle.elements, true))
                            {
                                result = new ErrorExp();
                                return;
                            }
                            if (checkFrameAccess(exp.loc, sc, sd, sle.elements.dim))
                            {
                                result = new ErrorExp();
                                return;
                            }
                            sle.type = t1;

                            einit = sle;
                        }
                        else
                        {
                            einit = t1.defaultInit(exp.loc);
                        }
                        auto ae = new BlitExp(exp.loc, exp.e1, einit);
                        ae.type = e1x.type;

                        /* Replace __ctmp being constructed with e1.
                         * We need to copy constructor call expression,
                         * because it may be used in other place.
                         */
                        auto dvx = cast(DotVarExp)dve.copy();
                        dvx.e1 = e1x;
                        auto cx = cast(CallExp)ce.copy();
                        cx.e1 = dvx;

                        Expression e0;
                        Expression.extractLast(e2x, &e0);

                        auto e = Expression.combine(ae, cx);
                        e = Expression.combine(e0, e);
                        e = e.semantic(sc);
                        result = e;
                        return;
                    }
                    if (sd.postblit)
                    {
                        /* We have a copy constructor for this
                         */
                        if (e2x.op == TOKquestion)
                        {
                            /* Rewrite as:
                             *  a ? e1 = b : e1 = c;
                             */
                            CondExp econd = cast(CondExp)e2x;
                            Expression ea1 = new ConstructExp(econd.e1.loc, e1x, econd.e1);
                            Expression ea2 = new ConstructExp(econd.e1.loc, e1x, econd.e2);
                            Expression e = new CondExp(exp.loc, econd.econd, ea1, ea2);
                            result = e.semantic(sc);
                            return;
                        }

                        if (e2x.isLvalue())
                        {
                            if (!e2x.type.implicitConvTo(e1x.type))
                            {
                                exp.error("conversion error from %s to %s",
                                    e2x.type.toChars(), e1x.type.toChars());
                                result = new ErrorExp();
                                return;
                            }

                            /* Rewrite as:
                             *  (e1 = e2).postblit();
                             *
                             * Blit assignment e1 = e2 returns a reference to the original e1,
                             * then call the postblit on it.
                             */
                            Expression e = e1x.copy();
                            e.type = e.type.mutableOf();
                            e = new BlitExp(exp.loc, e, e2x);
                            e = new DotVarExp(exp.loc, e, sd.postblit, false);
                            e = new CallExp(exp.loc, e);
                            result = e.semantic(sc);
                            return;
                        }
                        else
                        {
                            /* The struct value returned from the function is transferred
                             * so should not call the destructor on it.
                             */
                            e2x = valueNoDtor(e2x);
                        }
                    }
                }
                else if (!e2x.implicitConvTo(t1))
                {
                    sd.size(exp.loc);
                    if (sd.sizeok != SIZEOKdone)
                    {
                        result = new ErrorExp();
                        return;
                    }
                    if (!sd.ctor)
                        sd.ctor = sd.searchCtor();

                    if (sd.ctor)
                    {
                        /* Look for implicit constructor call
                         * Rewrite as:
                         *  e1 = init, e1.ctor(e2)
                         */
                        Expression einit;
                        einit = new BlitExp(exp.loc, e1x, e1x.type.defaultInit(exp.loc));
                        einit.type = e1x.type;

                        Expression e;
                        e = new DotIdExp(exp.loc, e1x, Id.ctor);
                        e = new CallExp(exp.loc, e, e2x);
                        e = new CommaExp(exp.loc, einit, e);
                        e = e.semantic(sc);
                        result = e;
                        return;
                    }
                    if (search_function(sd, Id.call))
                    {
                        /* Look for static opCall
                         * https://issues.dlang.org/show_bug.cgi?id=2702
                         * Rewrite as:
                         *  e1 = typeof(e1).opCall(arguments)
                         */
                        e2x = typeDotIdExp(e2x.loc, e1x.type, Id.call);
                        e2x = new CallExp(exp.loc, e2x, exp.e2);

                        e2x = e2x.semantic(sc);
                        e2x = resolveProperties(sc, e2x);
                        if (e2x.op == TOKerror)
                        {
                            result = e2x;
                            return;
                        }
                        if (e2x.checkValue())
                        {
                            result = new ErrorExp();
                            return;
                        }
                    }
                }
                else // https://issues.dlang.org/show_bug.cgi?id=11355
                {
                    AggregateDeclaration ad2 = isAggregate(e2x.type);
                    if (ad2 && ad2.aliasthis && !(exp.att2 && e2x.type == exp.att2))
                    {
                        if (!exp.att2 && exp.e2.type.checkAliasThisRec())
                            exp.att2 = exp.e2.type;
                        /* Rewrite (e1 op e2) as:
                         *      (e1 op e2.aliasthis)
                         */
                        exp.e2 = new DotIdExp(exp.e2.loc, exp.e2, ad2.aliasthis.ident);
                        result = exp.semantic(sc);
                        return;
                    }
                }
            }
            else if (exp.op == TOKassign)
            {
                if (e1x.op == TOKindex && (cast(IndexExp)e1x).e1.type.toBasetype().ty == Taarray)
                {
                    /*
                     * Rewrite:
                     *      aa[key] = e2;
                     * as:
                     *      ref __aatmp = aa;
                     *      ref __aakey = key;
                     *      ref __aaval = e2;
                     *      (__aakey in __aatmp
                     *          ? __aatmp[__aakey].opAssign(__aaval)
                     *          : ConstructExp(__aatmp[__aakey], __aaval));
                     */
                    IndexExp ie = cast(IndexExp)e1x;
                    Type t2 = e2x.type.toBasetype();

                    Expression e0 = null;
                    Expression ea = extractSideEffect(sc, "__aatmp", e0, ie.e1);
                    Expression ek = extractSideEffect(sc, "__aakey", e0, ie.e2);
                    Expression ev = extractSideEffect(sc, "__aaval", e0, e2x);

                    AssignExp ae = cast(AssignExp)exp.copy();
                    ae.e1 = new IndexExp(exp.loc, ea, ek);
                    ae.e1 = ae.e1.semantic(sc);
                    ae.e1 = ae.e1.optimize(WANTvalue);
                    ae.e2 = ev;
                    Expression e = ae.op_overload(sc);
                    if (e)
                    {
                        Expression ey = null;
                        if (t2.ty == Tstruct && sd == t2.toDsymbol(sc))
                        {
                            ey = ev;
                        }
                        else if (!ev.implicitConvTo(ie.type) && sd.ctor)
                        {
                            // Look for implicit constructor call
                            // Rewrite as S().ctor(e2)
                            ey = new StructLiteralExp(exp.loc, sd, null);
                            ey = new DotIdExp(exp.loc, ey, Id.ctor);
                            ey = new CallExp(exp.loc, ey, ev);
                            ey = ey.trySemantic(sc);
                        }
                        if (ey)
                        {
                            Expression ex;
                            ex = new IndexExp(exp.loc, ea, ek);
                            ex = ex.semantic(sc);
                            ex = ex.optimize(WANTvalue);
                            ex = ex.modifiableLvalue(sc, ex); // allocate new slot

                            ey = new ConstructExp(exp.loc, ex, ey);
                            ey = ey.semantic(sc);
                            if (ey.op == TOKerror)
                            {
                                result = ey;
                                return;
                            }
                            ex = e;

                            // https://issues.dlang.org/show_bug.cgi?id=14144
                            // The whole expression should have the common type
                            // of opAssign() return and assigned AA entry.
                            // Even if there's no common type, expression should be typed as void.
                            Type t = null;
                            if (!typeMerge(sc, TOKquestion, &t, &ex, &ey))
                            {
                                ex = new CastExp(ex.loc, ex, Type.tvoid);
                                ey = new CastExp(ey.loc, ey, Type.tvoid);
                            }
                            e = new CondExp(exp.loc, new InExp(exp.loc, ek, ea), ex, ey);
                        }
                        e = Expression.combine(e0, e);
                        e = e.semantic(sc);
                        result = e;
                        return;
                    }
                }
                else
                {
                    Expression e = exp.op_overload(sc);
                    if (e)
                    {
                        result = e;
                        return;
                    }
                }
            }
            else
                assert(exp.op == TOKblit);

            exp.e1 = e1x;
            exp.e2 = e2x;
        }
        else if (t1.ty == Tclass)
        {
            // Disallow assignment operator overloads for same type
            if (exp.op == TOKassign && !exp.e2.implicitConvTo(exp.e1.type))
            {
                Expression e = exp.op_overload(sc);
                if (e)
                {
                    result = e;
                    return;
                }
            }
        }
        else if (t1.ty == Tsarray)
        {
            // SliceExp cannot have static array type without context inference.
            assert(exp.e1.op != TOKslice);
            Expression e1x = exp.e1;
            Expression e2x = exp.e2;

            if (e2x.implicitConvTo(e1x.type))
            {
                if (exp.op != TOKblit && (e2x.op == TOKslice && (cast(UnaExp)e2x).e1.isLvalue() || e2x.op == TOKcast && (cast(UnaExp)e2x).e1.isLvalue() || e2x.op != TOKslice && e2x.isLvalue()))
                {
                    if (e1x.checkPostblit(sc, t1))
                    {
                        result = new ErrorExp();
                        return;
                    }
                }

                // e2 matches to t1 because of the implicit length match, so
                if (isUnaArrayOp(e2x.op) || isBinArrayOp(e2x.op))
                {
                    // convert e1 to e1[]
                    // e.g. e1[] = a[] + b[];
                    e1x = new SliceExp(e1x.loc, e1x, null, null);
                    e1x = e1x.semantic(sc);
                }
                else
                {
                    // convert e2 to t1 later
                    // e.g. e1 = [1, 2, 3];
                }
            }
            else
            {
                if (e2x.implicitConvTo(t1.nextOf().arrayOf()) > MATCHnomatch)
                {
                    uinteger_t dim1 = (cast(TypeSArray)t1).dim.toInteger();
                    uinteger_t dim2 = dim1;
                    if (e2x.op == TOKarrayliteral)
                    {
                        ArrayLiteralExp ale = cast(ArrayLiteralExp)e2x;
                        dim2 = ale.elements ? ale.elements.dim : 0;
                    }
                    else if (e2x.op == TOKslice)
                    {
                        Type tx = toStaticArrayType(cast(SliceExp)e2x);
                        if (tx)
                            dim2 = (cast(TypeSArray)tx).dim.toInteger();
                    }
                    if (dim1 != dim2)
                    {
                        exp.error("mismatched array lengths, %d and %d", cast(int)dim1, cast(int)dim2);
                        result = new ErrorExp();
                        return;
                    }
                }

                // May be block or element-wise assignment, so
                // convert e1 to e1[]
                if (exp.op != TOKassign)
                {
                    // If multidimensional static array, treat as one large array
                    dinteger_t dim = (cast(TypeSArray)t1).dim.toInteger();
                    Type t = t1;
                    while (1)
                    {
                        t = t.nextOf().toBasetype();
                        if (t.ty != Tsarray)
                            break;
                        dim *= (cast(TypeSArray)t).dim.toInteger();
                        e1x.type = t.nextOf().sarrayOf(dim);
                    }
                }
                e1x = new SliceExp(e1x.loc, e1x, null, null);
                e1x = e1x.semantic(sc);
            }
            if (e1x.op == TOKerror)
            {
                result = e1x;
                return;
            }
            if (e2x.op == TOKerror)
            {
                result = e2x;
                return;
            }

            exp.e1 = e1x;
            exp.e2 = e2x;
            t1 = e1x.type.toBasetype();
        }
        /* Check the mutability of e1.
         */
        if (exp.e1.op == TOKarraylength)
        {
            // e1 is not an lvalue, but we let code generator handle it
            ArrayLengthExp ale = cast(ArrayLengthExp)exp.e1;

            Expression ale1x = ale.e1;
            ale1x = ale1x.modifiableLvalue(sc, exp.e1);
            if (ale1x.op == TOKerror)
            {
                result = ale1x;
                return;
            }
            ale.e1 = ale1x;

            Type tn = ale.e1.type.toBasetype().nextOf();
            checkDefCtor(ale.loc, tn);
            semanticTypeInfo(sc, tn);
        }
        else if (exp.e1.op == TOKslice)
        {
            Type tn = exp.e1.type.nextOf();
            if (exp.op == TOKassign && !tn.isMutable())
            {
                exp.error("slice %s is not mutable", exp.e1.toChars());
                result = new ErrorExp();
                return;
            }

            // For conditional operator, both branches need conversion.
            SliceExp se = cast(SliceExp)exp.e1;
            while (se.e1.op == TOKslice)
                se = cast(SliceExp)se.e1;
            if (se.e1.op == TOKquestion && se.e1.type.toBasetype().ty == Tsarray)
            {
                se.e1 = se.e1.modifiableLvalue(sc, exp.e1);
                if (se.e1.op == TOKerror)
                {
                    result = se.e1;
                    return;
                }
            }
        }
        else
        {
            Expression e1x = exp.e1;

            // Try to do a decent error message with the expression
            // before it got constant folded

            if (e1x.op != TOKvar)
                e1x = e1x.optimize(WANTvalue);

            if (exp.op == TOKassign)
                e1x = e1x.modifiableLvalue(sc, e1old);

            if (e1x.op == TOKerror)
            {
                result = e1x;
                return;
            }
            exp.e1 = e1x;
        }

        /* Tweak e2 based on the type of e1.
         */
        Expression e2x = exp.e2;
        Type t2 = e2x.type.toBasetype();

        // If it is a array, get the element type. Note that it may be
        // multi-dimensional.
        Type telem = t1;
        while (telem.ty == Tarray)
            telem = telem.nextOf();

        if (exp.e1.op == TOKslice && t1.nextOf() &&
            (telem.ty != Tvoid || e2x.op == TOKnull) &&
            e2x.implicitConvTo(t1.nextOf()))
        {
            // Check for block assignment. If it is of type void[], void[][], etc,
            // '= null' is the only allowable block assignment (Bug 7493)
            exp.memset |= MemorySet.blockAssign;    // make it easy for back end to tell what this is
            e2x = e2x.implicitCastTo(sc, t1.nextOf());
            if (exp.op != TOKblit && e2x.isLvalue() && exp.e1.checkPostblit(sc, t1.nextOf()))
            {
                result = new ErrorExp();
                return;
            }
        }
        else if (exp.e1.op == TOKslice &&
                 (t2.ty == Tarray || t2.ty == Tsarray) &&
                 t2.nextOf().implicitConvTo(t1.nextOf()))
        {
            // Check element-wise assignment.

            /* If assigned elements number is known at compile time,
             * check the mismatch.
             */
            SliceExp se1 = cast(SliceExp)exp.e1;
            TypeSArray tsa1 = cast(TypeSArray)toStaticArrayType(se1);
            TypeSArray tsa2 = null;
            if (e2x.op == TOKarrayliteral)
                tsa2 = cast(TypeSArray)t2.nextOf().sarrayOf((cast(ArrayLiteralExp)e2x).elements.dim);
            else if (e2x.op == TOKslice)
                tsa2 = cast(TypeSArray)toStaticArrayType(cast(SliceExp)e2x);
            else if (t2.ty == Tsarray)
                tsa2 = cast(TypeSArray)t2;
            if (tsa1 && tsa2)
            {
                uinteger_t dim1 = tsa1.dim.toInteger();
                uinteger_t dim2 = tsa2.dim.toInteger();
                if (dim1 != dim2)
                {
                    exp.error("mismatched array lengths, %d and %d", cast(int)dim1, cast(int)dim2);
                    result = new ErrorExp();
                    return;
                }
            }

            if (exp.op != TOKblit &&
                (e2x.op == TOKslice && (cast(UnaExp)e2x).e1.isLvalue() ||
                 e2x.op == TOKcast && (cast(UnaExp)e2x).e1.isLvalue() ||
                 e2x.op != TOKslice && e2x.isLvalue()))
            {
                if (exp.e1.checkPostblit(sc, t1.nextOf()))
                {
                    result = new ErrorExp();
                    return;
                }
            }

            if (0 && global.params.warnings && !global.gag && exp.op == TOKassign &&
                e2x.op != TOKslice && e2x.op != TOKassign &&
                e2x.op != TOKarrayliteral && e2x.op != TOKstring &&
                !(e2x.op == TOKadd || e2x.op == TOKmin ||
                  e2x.op == TOKmul || e2x.op == TOKdiv ||
                  e2x.op == TOKmod || e2x.op == TOKxor ||
                  e2x.op == TOKand || e2x.op == TOKor ||
                  e2x.op == TOKpow ||
                  e2x.op == TOKtilde || e2x.op == TOKneg))
            {
                const(char)* e1str = exp.e1.toChars();
                const(char)* e2str = e2x.toChars();
                exp.warning("explicit element-wise assignment %s = (%s)[] is better than %s = %s", e1str, e2str, e1str, e2str);
            }

            Type t2n = t2.nextOf();
            Type t1n = t1.nextOf();
            int offset;
            if (t2n.equivalent(t1n) ||
                t1n.isBaseOf(t2n, &offset) && offset == 0)
            {
                /* Allow copy of distinct qualifier elements.
                 * eg.
                 *  char[] dst;  const(char)[] src;
                 *  dst[] = src;
                 *
                 *  class C {}   class D : C {}
                 *  C[2] ca;  D[] da;
                 *  ca[] = da;
                 */
                if (isArrayOpValid(e2x))
                {
                    // Don't add CastExp to keep AST for array operations
                    e2x = e2x.copy();
                    e2x.type = exp.e1.type.constOf();
                }
                else
                    e2x = e2x.castTo(sc, exp.e1.type.constOf());
            }
            else
            {
                /* https://issues.dlang.org/show_bug.cgi?id=15778
                 * A string literal has an array type of immutable
                 * elements by default, and normally it cannot be convertible to
                 * array type of mutable elements. But for element-wise assignment,
                 * elements need to be const at best. So we should give a chance
                 * to change code unit size for polysemous string literal.
                 */
                if (e2x.op == TOKstring)
                    e2x = e2x.implicitCastTo(sc, exp.e1.type.constOf());
                else
                    e2x = e2x.implicitCastTo(sc, exp.e1.type);
            }
            if (t1n.toBasetype.ty == Tvoid && t2n.toBasetype.ty == Tvoid)
            {
                if (!sc.intypeof && sc.func && sc.func.setUnsafe())
                {
                    exp.error("cannot copy void[] to void[] in @safe code");
                    result = new ErrorExp();
                    return;
                }
            }
        }
        else
        {
            if (0 && global.params.warnings && !global.gag && exp.op == TOKassign &&
                t1.ty == Tarray && t2.ty == Tsarray &&
                e2x.op != TOKslice &&
                t2.implicitConvTo(t1))
            {
                // Disallow ar[] = sa (Converted to ar[] = sa[])
                // Disallow da   = sa (Converted to da   = sa[])
                const(char)* e1str = exp.e1.toChars();
                const(char)* e2str = e2x.toChars();
                const(char)* atypestr = exp.e1.op == TOKslice ? "element-wise" : "slice";
                exp.warning("explicit %s assignment %s = (%s)[] is better than %s = %s", atypestr, e1str, e2str, e1str, e2str);
            }
            if (exp.op == TOKblit)
                e2x = e2x.castTo(sc, exp.e1.type);
            else
                e2x = e2x.implicitCastTo(sc, exp.e1.type);
        }
        if (e2x.op == TOKerror)
        {
            result = e2x;
            return;
        }
        exp.e2 = e2x;
        t2 = exp.e2.type.toBasetype();

        /* Look for array operations
         */
        if ((t2.ty == Tarray || t2.ty == Tsarray) && isArrayOpValid(exp.e2))
        {
            // Look for valid array operations
            if (!(exp.memset & MemorySet.blockAssign) &&
                exp.e1.op == TOKslice &&
                (isUnaArrayOp(exp.e2.op) || isBinArrayOp(exp.e2.op)))
            {
                exp.type = exp.e1.type;
                if (exp.op == TOKconstruct) // https://issues.dlang.org/show_bug.cgi?id=10282
                                        // tweak mutability of e1 element
                    exp.e1.type = exp.e1.type.nextOf().mutableOf().arrayOf();
                result = arrayOp(exp, sc);
                return;
            }

            // Drop invalid array operations in e2
            //  d = a[] + b[], d = (a[] + b[])[0..2], etc
            if (checkNonAssignmentArrayOp(exp.e2, !(exp.memset & MemorySet.blockAssign) && exp.op == TOKassign))
            {
                result = new ErrorExp();
                return;
            }

            // Remains valid array assignments
            //  d = d[], d = [1,2,3], etc
        }

        /* Don't allow assignment to classes that were allocated on the stack with:
         *      scope Class c = new Class();
         */
        if (exp.e1.op == TOKvar && exp.op == TOKassign)
        {
            VarExp ve = cast(VarExp)exp.e1;
            VarDeclaration vd = ve.var.isVarDeclaration();
            if (vd && (vd.onstack || vd.mynew))
            {
                assert(t1.ty == Tclass);
                exp.error("cannot rebind scope variables");
            }
        }

        if (exp.e1.op == TOKvar && (cast(VarExp)exp.e1).var.ident == Id.ctfe)
        {
            exp.error("cannot modify compiler-generated variable __ctfe");
        }

        exp.type = exp.e1.type;
        assert(exp.type);
        auto res = exp.op == TOKassign ? exp.reorderSettingAAElem(sc) : exp;
        checkAssignEscape(sc, res, false);
        result = res;
    }

    override void visit(PowAssignExp exp)
    {
        if (exp.type)
        {
            result = exp;
            return;
        }

        Expression e = exp.op_overload(sc);
        if (e)
        {
            result = e;
            return;
        }

        if (exp.e1.checkReadModifyWrite(exp.op, exp.e2))
        {
            result = new ErrorExp();
            return;
        }

        assert(exp.e1.type && exp.e2.type);
        if (exp.e1.op == TOKslice || exp.e1.type.ty == Tarray || exp.e1.type.ty == Tsarray)
        {
            // T[] ^^= ...
            if (exp.e2.implicitConvTo(exp.e1.type.nextOf()))
            {
                // T[] ^^= T
                exp.e2 = exp.e2.castTo(sc, exp.e1.type.nextOf());
            }
            else if (Expression ex = typeCombine(exp, sc))
            {
                result = ex;
                return;
            }

            // Check element types are arithmetic
            Type tb1 = exp.e1.type.nextOf().toBasetype();
            Type tb2 = exp.e2.type.toBasetype();
            if (tb2.ty == Tarray || tb2.ty == Tsarray)
                tb2 = tb2.nextOf().toBasetype();
            if ((tb1.isintegral() || tb1.isfloating()) && (tb2.isintegral() || tb2.isfloating()))
            {
                exp.type = exp.e1.type;
                result = arrayOp(exp, sc);
                return;
            }
        }
        else
        {
            exp.e1 = exp.e1.modifiableLvalue(sc, exp.e1);
        }

        if ((exp.e1.type.isintegral() || exp.e1.type.isfloating()) && (exp.e2.type.isintegral() || exp.e2.type.isfloating()))
        {
            Expression e0 = null;
            e = exp.reorderSettingAAElem(sc);
            e = Expression.extractLast(e, &e0);
            assert(e == exp);

            if (exp.e1.op == TOKvar)
            {
                // Rewrite: e1 = e1 ^^ e2
                e = new PowExp(exp.loc, exp.e1.syntaxCopy(), exp.e2);
                e = new AssignExp(exp.loc, exp.e1, e);
            }
            else
            {
                // Rewrite: ref tmp = e1; tmp = tmp ^^ e2
                auto v = copyToTemp(STCref, "__powtmp", exp.e1);
                auto de = new DeclarationExp(exp.e1.loc, v);
                auto ve = new VarExp(exp.e1.loc, v);
                e = new PowExp(exp.loc, ve, exp.e2);
                e = new AssignExp(exp.loc, new VarExp(exp.e1.loc, v), e);
                e = new CommaExp(exp.loc, de, e);
            }
            e = Expression.combine(e0, e);
            e = e.semantic(sc);
            result = e;
            return;
        }
        result = exp.incompatibleTypes();
    }

    override void visit(CatAssignExp exp)
    {
        if (exp.type)
        {
            result = exp;
            return;
        }

        //printf("CatAssignExp::semantic() %s\n", toChars());
        Expression e = exp.op_overload(sc);
        if (e)
        {
            result = e;
            return;
        }

        if (exp.e1.op == TOKslice)
        {
            SliceExp se = cast(SliceExp)exp.e1;
            if (se.e1.type.toBasetype().ty == Tsarray)
            {
                exp.error("cannot append to static array %s", se.e1.type.toChars());
                result = new ErrorExp();
                return;
            }
        }

        exp.e1 = exp.e1.modifiableLvalue(sc, exp.e1);
        if (exp.e1.op == TOKerror)
        {
            result = exp.e1;
            return;
        }
        if (exp.e2.op == TOKerror)
        {
            result = exp.e2;
            return;
        }

        if (checkNonAssignmentArrayOp(exp.e2))
        {
            result = new ErrorExp();
            return;
        }

        Type tb1 = exp.e1.type.toBasetype();
        Type tb1next = tb1.nextOf();
        Type tb2 = exp.e2.type.toBasetype();

        if ((tb1.ty == Tarray) &&
            (tb2.ty == Tarray || tb2.ty == Tsarray) &&
            (exp.e2.implicitConvTo(exp.e1.type) ||
             (tb2.nextOf().implicitConvTo(tb1next) &&
              (tb2.nextOf().size(Loc()) == tb1next.size(Loc())))))
        {
            // Append array
            if (exp.e1.checkPostblit(sc, tb1next))
            {
                result = new ErrorExp();
                return;
            }
            exp.e2 = exp.e2.castTo(sc, exp.e1.type);
        }
        else if ((tb1.ty == Tarray) && exp.e2.implicitConvTo(tb1next))
        {
            // Append element
            if (exp.e2.checkPostblit(sc, tb2))
            {
                result = new ErrorExp();
                return;
            }
            exp.e2 = exp.e2.castTo(sc, tb1next);
            exp.e2 = doCopyOrMove(sc, exp.e2);
        }
        else if (tb1.ty == Tarray &&
                 (tb1next.ty == Tchar || tb1next.ty == Twchar) &&
                 exp.e2.type.ty != tb1next.ty &&
                 exp.e2.implicitConvTo(Type.tdchar))
        {
            // Append dchar to char[] or wchar[]
            exp.e2 = exp.e2.castTo(sc, Type.tdchar);

            /* Do not allow appending wchar to char[] because if wchar happens
             * to be a surrogate pair, nothing good can result.
             */
        }
        else
        {
            exp.error("cannot append type %s to type %s", tb2.toChars(), tb1.toChars());
            result = new ErrorExp();
            return;
        }
        if (exp.e2.checkValue())
        {
            result = new ErrorExp();
            return;
        }

        exp.type = exp.e1.type;
        result = exp.reorderSettingAAElem(sc);
    }

    override void visit(AddExp exp)
    {
        static if (LOGSEMANTIC)
        {
            printf("AddExp::semantic('%s')\n", exp.toChars());
        }
        if (exp.type)
        {
            result = exp;
            return;
        }

        if (Expression ex = binSemanticProp(exp, sc))
        {
            result = ex;
            return;
        }
        Expression e = exp.op_overload(sc);
        if (e)
        {
            result = e;
            return;
        }

        Type tb1 = exp.e1.type.toBasetype();
        Type tb2 = exp.e2.type.toBasetype();

        bool err = false;
        if (tb1.ty == Tdelegate || tb1.ty == Tpointer && tb1.nextOf().ty == Tfunction)
        {
            err |= exp.e1.checkArithmetic();
        }
        if (tb2.ty == Tdelegate || tb2.ty == Tpointer && tb2.nextOf().ty == Tfunction)
        {
            err |= exp.e2.checkArithmetic();
        }
        if (err)
        {
            result = new ErrorExp();
            return;
        }

        if (tb1.ty == Tpointer && exp.e2.type.isintegral() || tb2.ty == Tpointer && exp.e1.type.isintegral())
        {
            result = scaleFactor(exp, sc);
            return;
        }

        if (tb1.ty == Tpointer && tb2.ty == Tpointer)
        {
            result = exp.incompatibleTypes();
            return;
        }

        if (Expression ex = typeCombine(exp, sc))
        {
            result = ex;
            return;
        }

        Type tb = exp.type.toBasetype();
        if (tb.ty == Tarray || tb.ty == Tsarray)
        {
            if (!isArrayOpValid(exp))
            {
                result = arrayOpInvalidError(exp);
                return;
            }
            result = exp;
            return;
        }

        tb1 = exp.e1.type.toBasetype();
        if (!Target.isVectorOpSupported(tb1, exp.op, tb2))
        {
            result = exp.incompatibleTypes();
            return;
        }
        if ((tb1.isreal() && exp.e2.type.isimaginary()) || (tb1.isimaginary() && exp.e2.type.isreal()))
        {
            switch (exp.type.toBasetype().ty)
            {
            case Tfloat32:
            case Timaginary32:
                exp.type = Type.tcomplex32;
                break;

            case Tfloat64:
            case Timaginary64:
                exp.type = Type.tcomplex64;
                break;

            case Tfloat80:
            case Timaginary80:
                exp.type = Type.tcomplex80;
                break;

            default:
                assert(0);
            }
        }
        result = exp;
    }

    override void visit(MinExp exp)
    {
        static if (LOGSEMANTIC)
        {
            printf("MinExp::semantic('%s')\n", exp.toChars());
        }
        if (exp.type)
        {
            result = exp;
            return;
        }

        if (Expression ex = binSemanticProp(exp, sc))
        {
            result = ex;
            return;
        }
        Expression e = exp.op_overload(sc);
        if (e)
        {
            result = e;
            return;
        }

        Type t1 = exp.e1.type.toBasetype();
        Type t2 = exp.e2.type.toBasetype();

        bool err = false;
        if (t1.ty == Tdelegate || t1.ty == Tpointer && t1.nextOf().ty == Tfunction)
        {
            err |= exp.e1.checkArithmetic();
        }
        if (t2.ty == Tdelegate || t2.ty == Tpointer && t2.nextOf().ty == Tfunction)
        {
            err |= exp.e2.checkArithmetic();
        }
        if (err)
        {
            result = new ErrorExp();
            return;
        }

        if (t1.ty == Tpointer)
        {
            if (t2.ty == Tpointer)
            {
                // Need to divide the result by the stride
                // Replace (ptr - ptr) with (ptr - ptr) / stride
                d_int64 stride;

                // make sure pointer types are compatible
                if (Expression ex = typeCombine(exp, sc))
                {
                    result = ex;
                    return;
                }

                exp.type = Type.tptrdiff_t;
                stride = t2.nextOf().size();
                if (stride == 0)
                {
                    e = new IntegerExp(exp.loc, 0, Type.tptrdiff_t);
                }
                else
                {
                    e = new DivExp(exp.loc, exp, new IntegerExp(Loc(), stride, Type.tptrdiff_t));
                    e.type = Type.tptrdiff_t;
                }
            }
            else if (t2.isintegral())
                e = scaleFactor(exp, sc);
            else
            {
                exp.error("can't subtract %s from pointer", t2.toChars());
                e = new ErrorExp();
            }
            result = e;
            return;
        }
        if (t2.ty == Tpointer)
        {
            exp.type = exp.e2.type;
            exp.error("can't subtract pointer from %s", exp.e1.type.toChars());
            result = new ErrorExp();
            return;
        }

        if (Expression ex = typeCombine(exp, sc))
        {
            result = ex;
            return;
        }

        Type tb = exp.type.toBasetype();
        if (tb.ty == Tarray || tb.ty == Tsarray)
        {
            if (!isArrayOpValid(exp))
            {
                result = arrayOpInvalidError(exp);
                return;
            }
            result = exp;
            return;
        }

        t1 = exp.e1.type.toBasetype();
        t2 = exp.e2.type.toBasetype();
        if (!Target.isVectorOpSupported(t1, exp.op, t2))
        {
            result = exp.incompatibleTypes();
            return;
        }
        if ((t1.isreal() && t2.isimaginary()) || (t1.isimaginary() && t2.isreal()))
        {
            switch (exp.type.ty)
            {
            case Tfloat32:
            case Timaginary32:
                exp.type = Type.tcomplex32;
                break;

            case Tfloat64:
            case Timaginary64:
                exp.type = Type.tcomplex64;
                break;

            case Tfloat80:
            case Timaginary80:
                exp.type = Type.tcomplex80;
                break;

            default:
                assert(0);
            }
        }
        result = exp;
        return;
    }

    override void visit(CatExp exp)
    {
        //printf("CatExp::semantic() %s\n", toChars());
        if (exp.type)
        {
            result = exp;
            return;
        }

        if (Expression ex = binSemanticProp(exp, sc))
        {
            result = ex;
            return;
        }
        Expression e = exp.op_overload(sc);
        if (e)
        {
            result = e;
            return;
        }

        Type tb1 = exp.e1.type.toBasetype();
        Type tb2 = exp.e2.type.toBasetype();

        auto f1 = checkNonAssignmentArrayOp(exp.e1);
        auto f2 = checkNonAssignmentArrayOp(exp.e2);
        if (f1 || f2)
        {
            result = new ErrorExp();
            return;
        }

        /* BUG: Should handle things like:
         *      char c;
         *      c ~ ' '
         *      ' ' ~ c;
         */

        version (none)
        {
            exp.e1.type.print();
            exp.e2.type.print();
        }
        Type tb1next = tb1.nextOf();
        Type tb2next = tb2.nextOf();

        // Check for: array ~ array
        if (tb1next && tb2next && (tb1next.implicitConvTo(tb2next) >= MATCHconst || tb2next.implicitConvTo(tb1next) >= MATCHconst || exp.e1.op == TOKarrayliteral && exp.e1.implicitConvTo(tb2) || exp.e2.op == TOKarrayliteral && exp.e2.implicitConvTo(tb1)))
        {
            /* https://issues.dlang.org/show_bug.cgi?id=9248
             * Here to avoid the case of:
             *    void*[] a = [cast(void*)1];
             *    void*[] b = [cast(void*)2];
             *    a ~ b;
             * becoming:
             *    a ~ [cast(void*)b];
             */

            /* https://issues.dlang.org/show_bug.cgi?id=14682
             * Also to avoid the case of:
             *    int[][] a;
             *    a ~ [];
             * becoming:
             *    a ~ cast(int[])[];
             */
            goto Lpeer;
        }

        // Check for: array ~ element
        if ((tb1.ty == Tsarray || tb1.ty == Tarray) && tb2.ty != Tvoid)
        {
            if (exp.e1.op == TOKarrayliteral)
            {
                exp.e2 = doCopyOrMove(sc, exp.e2);
                // https://issues.dlang.org/show_bug.cgi?id=14686
                // Postblit call appears in AST, and this is
                // finally translated  to an ArrayLiteralExp in below optimize().
            }
            else if (exp.e1.op == TOKstring)
            {
                // No postblit call exists on character (integer) value.
            }
            else
            {
                if (exp.e2.checkPostblit(sc, tb2))
                {
                    result = new ErrorExp();
                    return;
                }
                // Postblit call will be done in runtime helper function
            }

            if (exp.e1.op == TOKarrayliteral && exp.e1.implicitConvTo(tb2.arrayOf()))
            {
                exp.e1 = exp.e1.implicitCastTo(sc, tb2.arrayOf());
                exp.type = tb2.arrayOf();
                goto L2elem;
            }
            if (exp.e2.implicitConvTo(tb1next) >= MATCHconvert)
            {
                exp.e2 = exp.e2.implicitCastTo(sc, tb1next);
                exp.type = tb1next.arrayOf();
            L2elem:
                if (tb2.ty == Tarray || tb2.ty == Tsarray)
                {
                    // Make e2 into [e2]
                    exp.e2 = new ArrayLiteralExp(exp.e2.loc, exp.e2);
                    exp.e2.type = exp.type;
                }
                result = exp.optimize(WANTvalue);
                return;
            }
        }
        // Check for: element ~ array
        if ((tb2.ty == Tsarray || tb2.ty == Tarray) && tb1.ty != Tvoid)
        {
            if (exp.e2.op == TOKarrayliteral)
            {
                exp.e1 = doCopyOrMove(sc, exp.e1);
            }
            else if (exp.e2.op == TOKstring)
            {
            }
            else
            {
                if (exp.e1.checkPostblit(sc, tb1))
                {
                    result = new ErrorExp();
                    return;
                }
            }

            if (exp.e2.op == TOKarrayliteral && exp.e2.implicitConvTo(tb1.arrayOf()))
            {
                exp.e2 = exp.e2.implicitCastTo(sc, tb1.arrayOf());
                exp.type = tb1.arrayOf();
                goto L1elem;
            }
            if (exp.e1.implicitConvTo(tb2next) >= MATCHconvert)
            {
                exp.e1 = exp.e1.implicitCastTo(sc, tb2next);
                exp.type = tb2next.arrayOf();
            L1elem:
                if (tb1.ty == Tarray || tb1.ty == Tsarray)
                {
                    // Make e1 into [e1]
                    exp.e1 = new ArrayLiteralExp(exp.e1.loc, exp.e1);
                    exp.e1.type = exp.type;
                }
                result = exp.optimize(WANTvalue);
                return;
            }
        }

    Lpeer:
        if ((tb1.ty == Tsarray || tb1.ty == Tarray) && (tb2.ty == Tsarray || tb2.ty == Tarray) && (tb1next.mod || tb2next.mod) && (tb1next.mod != tb2next.mod))
        {
            Type t1 = tb1next.mutableOf().constOf().arrayOf();
            Type t2 = tb2next.mutableOf().constOf().arrayOf();
            if (exp.e1.op == TOKstring && !(cast(StringExp)exp.e1).committed)
                exp.e1.type = t1;
            else
                exp.e1 = exp.e1.castTo(sc, t1);
            if (exp.e2.op == TOKstring && !(cast(StringExp)exp.e2).committed)
                exp.e2.type = t2;
            else
                exp.e2 = exp.e2.castTo(sc, t2);
        }

        if (Expression ex = typeCombine(exp, sc))
        {
            result = ex;
            return;
        }
        exp.type = exp.type.toHeadMutable();

        Type tb = exp.type.toBasetype();
        if (tb.ty == Tsarray)
            exp.type = tb.nextOf().arrayOf();
        if (exp.type.ty == Tarray && tb1next && tb2next && tb1next.mod != tb2next.mod)
        {
            exp.type = exp.type.nextOf().toHeadMutable().arrayOf();
        }
        if (Type tbn = tb.nextOf())
        {
            if (exp.checkPostblit(sc, tbn))
            {
                result = new ErrorExp();
                return;
            }
        }
        version (none)
        {
            exp.e1.type.print();
            exp.e2.type.print();
            exp.type.print();
            exp.print();
        }
        Type t1 = exp.e1.type.toBasetype();
        Type t2 = exp.e2.type.toBasetype();
        if ((t1.ty == Tarray || t1.ty == Tsarray) &&
            (t2.ty == Tarray || t2.ty == Tsarray))
        {
            // Normalize to ArrayLiteralExp or StringExp as far as possible
            e = exp.optimize(WANTvalue);
        }
        else
        {
            //printf("(%s) ~ (%s)\n", e1.toChars(), e2.toChars());
            result = exp.incompatibleTypes();
            return;
        }

        result = e;
    }

    override void visit(MulExp exp)
    {
        version (none)
        {
            printf("MulExp::semantic() %s\n", exp.toChars());
        }
        if (exp.type)
        {
            result = exp;
            return;
        }

        if (Expression ex = binSemanticProp(exp, sc))
        {
            result = ex;
            return;
        }
        Expression e = exp.op_overload(sc);
        if (e)
        {
            result = e;
            return;
        }

        if (Expression ex = typeCombine(exp, sc))
        {
            result = ex;
            return;
        }

        Type tb = exp.type.toBasetype();
        if (tb.ty == Tarray || tb.ty == Tsarray)
        {
            if (!isArrayOpValid(exp))
            {
                result = arrayOpInvalidError(exp);
                return;
            }
            result = exp;
            return;
        }

        if (exp.checkArithmeticBin())
        {
            result = new ErrorExp();
            return;
        }

        if (exp.type.isfloating())
        {
            Type t1 = exp.e1.type;
            Type t2 = exp.e2.type;

            if (t1.isreal())
            {
                exp.type = t2;
            }
            else if (t2.isreal())
            {
                exp.type = t1;
            }
            else if (t1.isimaginary())
            {
                if (t2.isimaginary())
                {
                    switch (t1.toBasetype().ty)
                    {
                    case Timaginary32:
                        exp.type = Type.tfloat32;
                        break;

                    case Timaginary64:
                        exp.type = Type.tfloat64;
                        break;

                    case Timaginary80:
                        exp.type = Type.tfloat80;
                        break;

                    default:
                        assert(0);
                    }

                    // iy * iv = -yv
                    exp.e1.type = exp.type;
                    exp.e2.type = exp.type;
                    e = new NegExp(exp.loc, exp);
                    e = e.semantic(sc);
                    result = e;
                    return;
                }
                else
                    exp.type = t2; // t2 is complex
            }
            else if (t2.isimaginary())
            {
                exp.type = t1; // t1 is complex
            }
        }
        else if (!Target.isVectorOpSupported(tb, exp.op, exp.e2.type.toBasetype()))
        {
            result = exp.incompatibleTypes();
            return;
        }
        result = exp;
    }

    override void visit(DivExp exp)
    {
        if (exp.type)
        {
            result = exp;
            return;
        }

        if (Expression ex = binSemanticProp(exp, sc))
        {
            result = ex;
            return;
        }
        Expression e = exp.op_overload(sc);
        if (e)
        {
            result = e;
            return;
        }

        if (Expression ex = typeCombine(exp, sc))
        {
            result = ex;
            return;
        }

        Type tb = exp.type.toBasetype();
        if (tb.ty == Tarray || tb.ty == Tsarray)
        {
            if (!isArrayOpValid(exp))
            {
                result = arrayOpInvalidError(exp);
                return;
            }
            result = exp;
            return;
        }

        if (exp.checkArithmeticBin())
        {
            result = new ErrorExp();
            return;
        }

        if (exp.type.isfloating())
        {
            Type t1 = exp.e1.type;
            Type t2 = exp.e2.type;

            if (t1.isreal())
            {
                exp.type = t2;
                if (t2.isimaginary())
                {
                    // x/iv = i(-x/v)
                    exp.e2.type = t1;
                    e = new NegExp(exp.loc, exp);
                    e = e.semantic(sc);
                    result = e;
                    return;
                }
            }
            else if (t2.isreal())
            {
                exp.type = t1;
            }
            else if (t1.isimaginary())
            {
                if (t2.isimaginary())
                {
                    switch (t1.toBasetype().ty)
                    {
                    case Timaginary32:
                        exp.type = Type.tfloat32;
                        break;

                    case Timaginary64:
                        exp.type = Type.tfloat64;
                        break;

                    case Timaginary80:
                        exp.type = Type.tfloat80;
                        break;

                    default:
                        assert(0);
                    }
                }
                else
                    exp.type = t2; // t2 is complex
            }
            else if (t2.isimaginary())
            {
                exp.type = t1; // t1 is complex
            }
        }
        else if (!Target.isVectorOpSupported(tb, exp.op, exp.e2.type.toBasetype()))
        {
            result = exp.incompatibleTypes();
            return;
        }
        result = exp;
    }

    override void visit(ModExp exp)
    {
        if (exp.type)
        {
            result = exp;
            return;
        }

        if (Expression ex = binSemanticProp(exp, sc))
        {
            result = ex;
            return;
        }
        Expression e = exp.op_overload(sc);
        if (e)
        {
            result = e;
            return;
        }

        if (Expression ex = typeCombine(exp, sc))
        {
            result = ex;
            return;
        }

        Type tb = exp.type.toBasetype();
        if (tb.ty == Tarray || tb.ty == Tsarray)
        {
            if (!isArrayOpValid(exp))
            {
                result = arrayOpInvalidError(exp);
                return;
            }
            result = exp;
            return;
        }
        if (!Target.isVectorOpSupported(tb, exp.op, exp.e2.type.toBasetype()))
        {
            result = exp.incompatibleTypes();
            return;
        }

        if (exp.checkArithmeticBin())
        {
            result = new ErrorExp();
            return;
        }

        if (exp.type.isfloating())
        {
            exp.type = exp.e1.type;
            if (exp.e2.type.iscomplex())
            {
                exp.error("cannot perform modulo complex arithmetic");
                result = new ErrorExp();
                return;
            }
        }
        result = exp;
    }

    override void visit(PowExp exp)
    {
        if (exp.type)
        {
            result = exp;
            return;
        }

        //printf("PowExp::semantic() %s\n", toChars());
        if (Expression ex = binSemanticProp(exp, sc))
        {
            result = ex;
            return;
        }
        Expression e = exp.op_overload(sc);
        if (e)
        {
            result = e;
            return;
        }

        if (Expression ex = typeCombine(exp, sc))
        {
            result = ex;
            return;
        }

        Type tb = exp.type.toBasetype();
        if (tb.ty == Tarray || tb.ty == Tsarray)
        {
            if (!isArrayOpValid(exp))
            {
                result = arrayOpInvalidError(exp);
                return;
            }
            result = exp;
            return;
        }

        if (exp.checkArithmeticBin())
        {
            result = new ErrorExp();
            return;
        }

        if (!Target.isVectorOpSupported(tb, exp.op, exp.e2.type.toBasetype()))
        {
            result = exp.incompatibleTypes();
            return;
        }

        // For built-in numeric types, there are several cases.
        // TODO: backend support, especially for  e1 ^^ 2.

        // First, attempt to fold the expression.
        e = exp.optimize(WANTvalue);
        if (e.op != TOKpow)
        {
            e = e.semantic(sc);
            result = e;
            return;
        }

        // Determine if we're raising to an integer power.
        sinteger_t intpow = 0;
        if (exp.e2.op == TOKint64 && (cast(sinteger_t)exp.e2.toInteger() == 2 || cast(sinteger_t)exp.e2.toInteger() == 3))
            intpow = exp.e2.toInteger();
        else if (exp.e2.op == TOKfloat64 && (exp.e2.toReal() == real_t(cast(sinteger_t)exp.e2.toReal())))
            intpow = cast(sinteger_t)exp.e2.toReal();

        // Deal with x^^2, x^^3 immediately, since they are of practical importance.
        if (intpow == 2 || intpow == 3)
        {
            // Replace x^^2 with (tmp = x, tmp*tmp)
            // Replace x^^3 with (tmp = x, tmp*tmp*tmp)
            auto tmp = copyToTemp(0, "__powtmp", exp.e1);
            Expression de = new DeclarationExp(exp.loc, tmp);
            Expression ve = new VarExp(exp.loc, tmp);

            /* Note that we're reusing ve. This should be ok.
             */
            Expression me = new MulExp(exp.loc, ve, ve);
            if (intpow == 3)
                me = new MulExp(exp.loc, me, ve);
            e = new CommaExp(exp.loc, de, me);
            e = e.semantic(sc);
            result = e;
            return;
        }

        Module mmath = loadStdMath();
        if (!mmath)
        {
            //error("requires std.math for ^^ operators");
            //fatal();
            // Leave handling of PowExp to the backend, or throw
            // an error gracefully if no backend support exists.
            if (Expression ex = typeCombine(exp, sc))
            {
                result = ex;
                return;
            }
            result = exp;
            return;
        }
        e = new ScopeExp(exp.loc, mmath);

        if (exp.e2.op == TOKfloat64 && exp.e2.toReal() == CTFloat.half)
        {
            // Replace e1 ^^ 0.5 with .std.math.sqrt(x)
            e = new CallExp(exp.loc, new DotIdExp(exp.loc, e, Id._sqrt), exp.e1);
        }
        else
        {
            // Replace e1 ^^ e2 with .std.math.pow(e1, e2)
            e = new CallExp(exp.loc, new DotIdExp(exp.loc, e, Id._pow), exp.e1, exp.e2);
        }
        e = e.semantic(sc);
        result = e;
        return;
    }

    override void visit(ShlExp exp)
    {
        //printf("ShlExp::semantic(), type = %p\n", type);
        if (exp.type)
        {
            result = exp;
            return;
        }

        if (Expression ex = binSemanticProp(exp, sc))
        {
            result = ex;
            return;
        }
        Expression e = exp.op_overload(sc);
        if (e)
        {
            result = e;
            return;
        }

        if (exp.checkIntegralBin())
        {
            result = new ErrorExp();
            return;
        }
        if (!Target.isVectorOpSupported(exp.e1.type.toBasetype(), exp.op, exp.e2.type.toBasetype()))
        {
            result = exp.incompatibleTypes();
            return;
        }
        exp.e1 = integralPromotions(exp.e1, sc);
        exp.e2 = exp.e2.castTo(sc, Type.tshiftcnt);

        exp.type = exp.e1.type;
        result = exp;
    }

    override void visit(ShrExp exp)
    {
        if (exp.type)
        {
            result = exp;
            return;
        }

        if (Expression ex = binSemanticProp(exp, sc))
        {
            result = ex;
            return;
        }
        Expression e = exp.op_overload(sc);
        if (e)
        {
            result = e;
            return;
        }

        if (exp.checkIntegralBin())
        {
            result = new ErrorExp();
            return;
        }
        if (!Target.isVectorOpSupported(exp.e1.type.toBasetype(), exp.op, exp.e2.type.toBasetype()))
        {
            result = exp.incompatibleTypes();
            return;
        }
        exp.e1 = integralPromotions(exp.e1, sc);
        exp.e2 = exp.e2.castTo(sc, Type.tshiftcnt);

        exp.type = exp.e1.type;
        result = exp;
    }

    override void visit(UshrExp exp)
    {
        if (exp.type)
        {
            result = exp;
            return;
        }

        if (Expression ex = binSemanticProp(exp, sc))
        {
            result = ex;
            return;
        }
        Expression e = exp.op_overload(sc);
        if (e)
        {
            result = e;
            return;
        }

        if (exp.checkIntegralBin())
        {
            result = new ErrorExp();
            return;
        }
        if (!Target.isVectorOpSupported(exp.e1.type.toBasetype(), exp.op, exp.e2.type.toBasetype()))
        {
            result = exp.incompatibleTypes();
            return;
        }
        exp.e1 = integralPromotions(exp.e1, sc);
        exp.e2 = exp.e2.castTo(sc, Type.tshiftcnt);

        exp.type = exp.e1.type;
        result = exp;
    }

    override void visit(AndExp exp)
    {
        if (exp.type)
        {
            result = exp;
            return;
        }

        if (Expression ex = binSemanticProp(exp, sc))
        {
            result = ex;
            return;
        }
        Expression e = exp.op_overload(sc);
        if (e)
        {
            result = e;
            return;
        }

        if (exp.e1.type.toBasetype().ty == Tbool && exp.e2.type.toBasetype().ty == Tbool)
        {
            exp.type = exp.e1.type;
            result = exp;
            return;
        }

        if (Expression ex = typeCombine(exp, sc))
        {
            result = ex;
            return;
        }

        Type tb = exp.type.toBasetype();
        if (tb.ty == Tarray || tb.ty == Tsarray)
        {
            if (!isArrayOpValid(exp))
            {
                result = arrayOpInvalidError(exp);
                return;
            }
            result = exp;
            return;
        }
        if (!Target.isVectorOpSupported(tb, exp.op, exp.e2.type.toBasetype()))
        {
            result = exp.incompatibleTypes();
            return;
        }
        if (exp.checkIntegralBin())
        {
            result = new ErrorExp();
            return;
        }

        result = exp;
    }

    override void visit(OrExp exp)
    {
        if (exp.type)
        {
            result = exp;
            return;
        }

        if (Expression ex = binSemanticProp(exp, sc))
        {
            result = ex;
            return;
        }
        Expression e = exp.op_overload(sc);
        if (e)
        {
            result = e;
            return;
        }

        if (exp.e1.type.toBasetype().ty == Tbool && exp.e2.type.toBasetype().ty == Tbool)
        {
            exp.type = exp.e1.type;
            result = exp;
            return;
        }

        if (Expression ex = typeCombine(exp, sc))
        {
            result = ex;
            return;
        }

        Type tb = exp.type.toBasetype();
        if (tb.ty == Tarray || tb.ty == Tsarray)
        {
            if (!isArrayOpValid(exp))
            {
                result = arrayOpInvalidError(exp);
                return;
            }
            result = exp;
            return;
        }
        if (!Target.isVectorOpSupported(tb, exp.op, exp.e2.type.toBasetype()))
        {
            result = exp.incompatibleTypes();
            return;
        }
        if (exp.checkIntegralBin())
        {
            result = new ErrorExp();
            return;
        }

        result = exp;
    }

    override void visit(XorExp exp)
    {
        if (exp.type)
        {
            result = exp;
            return;
        }

        if (Expression ex = binSemanticProp(exp, sc))
        {
            result = ex;
            return;
        }
        Expression e = exp.op_overload(sc);
        if (e)
        {
            result = e;
            return;
        }

        if (exp.e1.type.toBasetype().ty == Tbool && exp.e2.type.toBasetype().ty == Tbool)
        {
            exp.type = exp.e1.type;
            result = exp;
            return;
        }

        if (Expression ex = typeCombine(exp, sc))
        {
            result = ex;
            return;
        }

        Type tb = exp.type.toBasetype();
        if (tb.ty == Tarray || tb.ty == Tsarray)
        {
            if (!isArrayOpValid(exp))
            {
                result = arrayOpInvalidError(exp);
                return;
            }
            result = exp;
            return;
        }
        if (!Target.isVectorOpSupported(tb, exp.op, exp.e2.type.toBasetype()))
        {
            result = exp.incompatibleTypes();
            return;
        }
        if (exp.checkIntegralBin())
        {
            result = new ErrorExp();
            return;
        }

        result = exp;
    }

    override void visit(OrOrExp exp)
    {
        if (exp.type)
        {
            result = exp;
            return;
        }

        exp.setNoderefOperands();

        // same as for AndAnd
        exp.e1 = exp.e1.semantic(sc);
        exp.e1 = resolveProperties(sc, exp.e1);
        exp.e1 = exp.e1.toBoolean(sc);
        uint cs1 = sc.callSuper;

        if (sc.flags & SCOPEcondition)
        {
            /* If in static if, don't evaluate e2 if we don't have to.
             */
            exp.e1 = exp.e1.optimize(WANTvalue);
            if (exp.e1.isBool(true))
            {
                result = new IntegerExp(exp.loc, 1, Type.tbool);
                return;
            }
        }

        exp.e2 = exp.e2.semantic(sc);
        sc.mergeCallSuper(exp.loc, cs1);
        exp.e2 = resolveProperties(sc, exp.e2);

        auto f1 = checkNonAssignmentArrayOp(exp.e1);
        auto f2 = checkNonAssignmentArrayOp(exp.e2);
        if (f1 || f2)
        {
            result = new ErrorExp();
            return;
        }

        if (exp.e2.type.ty == Tvoid)
            exp.type = Type.tvoid;
        else
        {
            exp.e2 = exp.e2.toBoolean(sc);
            exp.type = Type.tbool;
        }
        if (exp.e2.op == TOKtype || exp.e2.op == TOKscope)
        {
            exp.error("%s is not an expression", exp.e2.toChars());
            result = new ErrorExp();
            return;
        }
        if (exp.e1.op == TOKerror)
        {
            result = exp.e1;
            return;
        }
        if (exp.e2.op == TOKerror)
        {
            result = exp.e2;
            return;
        }

        result = exp;
    }

    override void visit(AndAndExp exp)
    {
        if (exp.type)
        {
            result = exp;
            return;
        }

        exp.setNoderefOperands();

        // same as for OrOr
        exp.e1 = exp.e1.semantic(sc);
        exp.e1 = resolveProperties(sc, exp.e1);
        exp.e1 = exp.e1.toBoolean(sc);
        uint cs1 = sc.callSuper;

        if (sc.flags & SCOPEcondition)
        {
            /* If in static if, don't evaluate e2 if we don't have to.
             */
            exp.e1 = exp.e1.optimize(WANTvalue);
            if (exp.e1.isBool(false))
            {
                result = new IntegerExp(exp.loc, 0, Type.tbool);
                return;
            }
        }

        exp.e2 = exp.e2.semantic(sc);
        sc.mergeCallSuper(exp.loc, cs1);
        exp.e2 = resolveProperties(sc, exp.e2);

        auto f1 = checkNonAssignmentArrayOp(exp.e1);
        auto f2 = checkNonAssignmentArrayOp(exp.e2);
        if (f1 || f2)
        {
            result = new ErrorExp();
            return;
        }

        if (exp.e2.type.ty == Tvoid)
            exp.type = Type.tvoid;
        else
        {
            exp.e2 = exp.e2.toBoolean(sc);
            exp.type = Type.tbool;
        }
        if (exp.e2.op == TOKtype || exp.e2.op == TOKscope)
        {
            exp.error("%s is not an expression", exp.e2.toChars());
            result = new ErrorExp();
            return;
        }
        if (exp.e1.op == TOKerror)
        {
            result = exp.e1;
            return;
        }
        if (exp.e2.op == TOKerror)
        {
            result = exp.e2;
            return;
        }

        result = exp;
    }

    override void visit(CmpExp exp)
    {
        static if (LOGSEMANTIC)
        {
            printf("CmpExp::semantic('%s')\n", exp.toChars());
        }
        if (exp.type)
        {
            result = exp;
            return;
        }

        exp.setNoderefOperands();

        if (Expression ex = binSemanticProp(exp, sc))
        {
            result = ex;
            return;
        }
        Type t1 = exp.e1.type.toBasetype();
        Type t2 = exp.e2.type.toBasetype();
        if (t1.ty == Tclass && exp.e2.op == TOKnull || t2.ty == Tclass && exp.e1.op == TOKnull)
        {
            exp.error("do not use null when comparing class types");
            result = new ErrorExp();
            return;
        }

        Expression e = exp.op_overload(sc);
        if (e)
        {
            if (!e.type.isscalar() && e.type.equals(exp.e1.type))
            {
                exp.error("recursive opCmp expansion");
                result = new ErrorExp();
                return;
            }
            if (e.op == TOKcall)
            {
                e = new CmpExp(exp.op, exp.loc, e, new IntegerExp(exp.loc, 0, Type.tint32));
                e = e.semantic(sc);
            }
            result = e;
            return;
        }

        if (Expression ex = typeCombine(exp, sc))
        {
            result = ex;
            return;
        }

        auto f1 = checkNonAssignmentArrayOp(exp.e1);
        auto f2 = checkNonAssignmentArrayOp(exp.e2);
        if (f1 || f2)
        {
            result = new ErrorExp();
            return;
        }

        exp.type = Type.tbool;

        // Special handling for array comparisons
        Expression arrayLowering = null;
        t1 = exp.e1.type.toBasetype();
        t2 = exp.e2.type.toBasetype();
        if ((t1.ty == Tarray || t1.ty == Tsarray || t1.ty == Tpointer) && (t2.ty == Tarray || t2.ty == Tsarray || t2.ty == Tpointer))
        {
            Type t1next = t1.nextOf();
            Type t2next = t2.nextOf();
            if (t1next.implicitConvTo(t2next) < MATCHconst && t2next.implicitConvTo(t1next) < MATCHconst && (t1next.ty != Tvoid && t2next.ty != Tvoid))
            {
                exp.error("array comparison type mismatch, %s vs %s", t1next.toChars(), t2next.toChars());
                result = new ErrorExp();
                return;
            }
            if ((t1.ty == Tarray || t1.ty == Tsarray) && (t2.ty == Tarray || t2.ty == Tsarray))
            {
                // Lower to object.__cmp(e1, e2)
                Expression al = new IdentifierExp(exp.loc, Id.empty);
                al = new DotIdExp(exp.loc, al, Id.object);
                al = new DotIdExp(exp.loc, al, Id.__cmp);
                al = al.semantic(sc);

                auto arguments = new Expressions();
                arguments.push(exp.e1);
                arguments.push(exp.e2);

                al = new CallExp(exp.loc, al, arguments);
                al = new CmpExp(exp.op, exp.loc, al, new IntegerExp(0));

                arrayLowering = al;
            }
        }
        else if (t1.ty == Tstruct || t2.ty == Tstruct || (t1.ty == Tclass && t2.ty == Tclass))
        {
            if (t2.ty == Tstruct)
                exp.error("need member function opCmp() for %s %s to compare", t2.toDsymbol(sc).kind(), t2.toChars());
            else
                exp.error("need member function opCmp() for %s %s to compare", t1.toDsymbol(sc).kind(), t1.toChars());
            result = new ErrorExp();
            return;
        }
        else if (t1.iscomplex() || t2.iscomplex())
        {
            exp.error("compare not defined for complex operands");
            result = new ErrorExp();
            return;
        }
        else if (t1.ty == Taarray || t2.ty == Taarray)
        {
            exp.error("%s is not defined for associative arrays", Token.toChars(exp.op));
            result = new ErrorExp();
            return;
        }
        else if (!Target.isVectorOpSupported(t1, exp.op, t2))
        {
            result = exp.incompatibleTypes();
            return;
        }
        else
        {
            bool r1 = exp.e1.checkValue();
            bool r2 = exp.e2.checkValue();
            if (r1 || r2)
            {
                result = new ErrorExp();
                return;
            }
        }

        TOK altop;
        switch (exp.op)
        {
            // Refer rel_integral[] table
        case TOKunord:
            altop = TOKerror;
            break;

        case TOKlg:
            altop = TOKnotequal;
            break;

        case TOKleg:
            altop = TOKerror;
            break;

        case TOKule:
            altop = TOKle;
            break;

        case TOKul:
            altop = TOKlt;
            break;

        case TOKuge:
            altop = TOKge;
            break;

        case TOKug:
            altop = TOKgt;
            break;

        case TOKue:
            altop = TOKequal;
            break;

        default:
            altop = TOKreserved;
            break;
        }
        if (altop == TOKerror && (t1.ty == Tarray || t1.ty == Tsarray || t2.ty == Tarray || t2.ty == Tsarray))
        {
            exp.error("'%s' is not defined for array comparisons", Token.toChars(exp.op));
            result = new ErrorExp();
            return;
        }
        if (altop != TOKreserved)
        {
            if (!t1.isfloating())
            {
                if (altop == TOKerror)
                {
                    const(char)* s = exp.op == TOKunord ? "false" : "true";
                    exp.error("floating point operator '%s' always returns %s for non-floating comparisons", Token.toChars(exp.op), s);
                }
                else
                {
                    exp.error("use '%s' for non-floating comparisons rather than floating point operator '%s'", Token.toChars(altop), Token.toChars(exp.op));
                }
            }
            else
            {
                exp.error("use std.math.isNaN to deal with NaN operands rather than floating point operator '%s'", Token.toChars(exp.op));
            }
            result = new ErrorExp();
            return;
        }

        //printf("CmpExp: %s, type = %s\n", e.toChars(), e.type.toChars());
        if (arrayLowering)
        {
            arrayLowering = arrayLowering.semantic(sc);
            result = arrayLowering;
            return;
        }
        result = exp;
        return;
    }

    override void visit(InExp exp)
    {
        if (exp.type)
        {
            result = exp;
            return;
        }

        if (Expression ex = binSemanticProp(exp, sc))
        {
            result = ex;
            return;
        }
        Expression e = exp.op_overload(sc);
        if (e)
        {
            result = e;
            return;
        }

        Type t2b = exp.e2.type.toBasetype();
        switch (t2b.ty)
        {
        case Taarray:
            {
                TypeAArray ta = cast(TypeAArray)t2b;

                // Special handling for array keys
                if (!arrayTypeCompatible(exp.e1.loc, exp.e1.type, ta.index))
                {
                    // Convert key to type of key
                    exp.e1 = exp.e1.implicitCastTo(sc, ta.index);
                }

                semanticTypeInfo(sc, ta.index);

                // Return type is pointer to value
                exp.type = ta.nextOf().pointerTo();
                break;
            }
        default:
            result = exp.incompatibleTypes();
            return;
        case Terror:
            result = new ErrorExp();
            return;
        }
        result = exp;
    }

    override void visit(RemoveExp e)
    {
        if (Expression ex = binSemantic(e, sc))
        {
            result = ex;
            return;
        }
        result = e;
    }

    override void visit(EqualExp exp)
    {
        //printf("EqualExp::semantic('%s')\n", toChars());
        if (exp.type)
        {
            result = exp;
            return;
        }

        exp.setNoderefOperands();

        if (auto e = binSemanticProp(exp, sc))
        {
            result = e;
            return;
        }
        if (exp.e1.op == TOKtype || exp.e2.op == TOKtype)
        {
            result = exp.incompatibleTypes();
            return;
        }

        {
            auto t1 = exp.e1.type;
            auto t2 = exp.e2.type;
            if (t1.ty == Tenum && t2.ty == Tenum && !t1.equivalent(t2))
                exp.deprecation("Comparison between different enumeration types `%s` and `%s`; If this behavior is intended consider using `std.conv.asOriginalType`",
                    t1.toChars(), t2.toChars());
        }

        /* Before checking for operator overloading, check to see if we're
         * comparing the addresses of two statics. If so, we can just see
         * if they are the same symbol.
         */
        if (exp.e1.op == TOKaddress && exp.e2.op == TOKaddress)
        {
            AddrExp ae1 = cast(AddrExp)exp.e1;
            AddrExp ae2 = cast(AddrExp)exp.e2;
            if (ae1.e1.op == TOKvar && ae2.e1.op == TOKvar)
            {
                VarExp ve1 = cast(VarExp)ae1.e1;
                VarExp ve2 = cast(VarExp)ae2.e1;
                if (ve1.var == ve2.var)
                {
                    // They are the same, result is 'true' for ==, 'false' for !=
                    result = new IntegerExp(exp.loc, (exp.op == TOKequal), Type.tbool);
                    return;
                }
            }
        }

        if (auto e = exp.op_overload(sc))
        {
            result = e;
            return;
        }

        if (auto e = typeCombine(exp, sc))
        {
            result = e;
            return;
        }

        auto f1 = checkNonAssignmentArrayOp(exp.e1);
        auto f2 = checkNonAssignmentArrayOp(exp.e2);
        if (f1 || f2)
        {
            result = new ErrorExp();
            return;
        }

        exp.type = Type.tbool;

        // Special handling for array comparisons
        if (!arrayTypeCompatible(exp.loc, exp.e1.type, exp.e2.type))
        {
            if (exp.e1.type != exp.e2.type && exp.e1.type.isfloating() && exp.e2.type.isfloating())
            {
                // Cast both to complex
                exp.e1 = exp.e1.castTo(sc, Type.tcomplex80);
                exp.e2 = exp.e2.castTo(sc, Type.tcomplex80);
            }
        }
        if (exp.e1.type.toBasetype().ty == Taarray)
            semanticTypeInfo(sc, exp.e1.type.toBasetype());

        Type t1 = exp.e1.type.toBasetype();
        Type t2 = exp.e2.type.toBasetype();

        if (!Target.isVectorOpSupported(t1, exp.op, t2))
        {
            result = exp.incompatibleTypes();
            return;
        }

        result = exp;
    }

    override void visit(IdentityExp exp)
    {
        if (exp.type)
        {
            result = exp;
            return;
        }

        exp.setNoderefOperands();

        if (auto e = binSemanticProp(exp, sc))
        {
            result = e;
            return;
        }

        if (auto e = typeCombine(exp, sc))
        {
            result = e;
            return;
        }

        auto f1 = checkNonAssignmentArrayOp(exp.e1);
        auto f2 = checkNonAssignmentArrayOp(exp.e2);
        if (f1 || f2)
        {
            result = new ErrorExp();
            return;
        }

        exp.type = Type.tbool;

        if (exp.e1.type != exp.e2.type && exp.e1.type.isfloating() && exp.e2.type.isfloating())
        {
            // Cast both to complex
            exp.e1 = exp.e1.castTo(sc, Type.tcomplex80);
            exp.e2 = exp.e2.castTo(sc, Type.tcomplex80);
        }

        auto tb1 = exp.e1.type.toBasetype();
        auto tb2 = exp.e2.type.toBasetype();
        if (!Target.isVectorOpSupported(tb1, exp.op, tb2))
        {
            result = exp.incompatibleTypes();
            return;
        }

        if (exp.e1.type.toBasetype().ty == Tsarray ||
            exp.e2.type.toBasetype().ty == Tsarray)
            exp.deprecation("identity comparison of static arrays "
                ~ "implicitly coerces them to slices, "
                ~ "which are compared by reference");

        result = exp;
    }

    override void visit(CondExp exp)
    {
        static if (LOGSEMANTIC)
        {
            printf("CondExp::semantic('%s')\n", exp.toChars());
        }
        if (exp.type)
        {
            result = exp;
            return;
        }

        if (exp.econd.op == TOKdotid)
            (cast(DotIdExp)exp.econd).noderef = true;

        Expression ec = exp.econd.semantic(sc);
        ec = resolveProperties(sc, ec);
        ec = ec.toBoolean(sc);

        uint cs0 = sc.callSuper;
        uint* fi0 = sc.saveFieldInit();
        Expression e1x = exp.e1.semantic(sc);
        e1x = resolveProperties(sc, e1x);

        uint cs1 = sc.callSuper;
        uint* fi1 = sc.fieldinit;
        sc.callSuper = cs0;
        sc.fieldinit = fi0;
        Expression e2x = exp.e2.semantic(sc);
        e2x = resolveProperties(sc, e2x);

        sc.mergeCallSuper(exp.loc, cs1);
        sc.mergeFieldInit(exp.loc, fi1);

        if (ec.op == TOKerror)
        {
            result = ec;
            return;
        }
        if (ec.type == Type.terror)
        {
            result = new ErrorExp();
            return;
        }
        exp.econd = ec;

        if (e1x.op == TOKerror)
        {
            result = e1x;
            return;
        }
        if (e1x.type == Type.terror)
        {
            result = new ErrorExp();
            return;
        }
        exp.e1 = e1x;

        if (e2x.op == TOKerror)
        {
            result = e2x;
            return;
        }
        if (e2x.type == Type.terror)
        {
            result = new ErrorExp();
            return;
        }
        exp.e2 = e2x;

        auto f0 = checkNonAssignmentArrayOp(exp.econd);
        auto f1 = checkNonAssignmentArrayOp(exp.e1);
        auto f2 = checkNonAssignmentArrayOp(exp.e2);
        if (f0 || f1 || f2)
        {
            result = new ErrorExp();
            return;
        }

        Type t1 = exp.e1.type;
        Type t2 = exp.e2.type;
        // If either operand is void the result is void, we have to cast both
        // the expression to void so that we explicitly discard the expression
        // value if any
        // https://issues.dlang.org/show_bug.cgi?id=16598
        if (t1.ty == Tvoid || t2.ty == Tvoid)
        {
            exp.type = Type.tvoid;
            exp.e1 = exp.e1.castTo(sc, exp.type);
            exp.e2 = exp.e2.castTo(sc, exp.type);
        }
        else if (t1 == t2)
            exp.type = t1;
        else
        {
            if (Expression ex = typeCombine(exp, sc))
            {
                result = ex;
                return;
            }

            switch (exp.e1.type.toBasetype().ty)
            {
            case Tcomplex32:
            case Tcomplex64:
            case Tcomplex80:
                exp.e2 = exp.e2.castTo(sc, exp.e1.type);
                break;
            default:
                break;
            }
            switch (exp.e2.type.toBasetype().ty)
            {
            case Tcomplex32:
            case Tcomplex64:
            case Tcomplex80:
                exp.e1 = exp.e1.castTo(sc, exp.e2.type);
                break;
            default:
                break;
            }
            if (exp.type.toBasetype().ty == Tarray)
            {
                exp.e1 = exp.e1.castTo(sc, exp.type);
                exp.e2 = exp.e2.castTo(sc, exp.type);
            }
        }
        exp.type = exp.type.merge2();
        version (none)
        {
            printf("res: %s\n", exp.type.toChars());
            printf("e1 : %s\n", exp.e1.type.toChars());
            printf("e2 : %s\n", exp.e2.type.toChars());
        }

        /* https://issues.dlang.org/show_bug.cgi?id=14696
         * If either e1 or e2 contain temporaries which need dtor,
         * make them conditional.
         * Rewrite:
         *      cond ? (__tmp1 = ..., __tmp1) : (__tmp2 = ..., __tmp2)
         * to:
         *      (auto __cond = cond) ? (... __tmp1) : (... __tmp2)
         * and replace edtors of __tmp1 and __tmp2 with:
         *      __tmp1.edtor --> __cond && __tmp1.dtor()
         *      __tmp2.edtor --> __cond || __tmp2.dtor()
         */
        exp.hookDtors(sc);

        result = exp;
    }

    override void visit(FileInitExp e)
    {
        //printf("FileInitExp::semantic()\n");
        e.type = Type.tstring;
        result = e;
    }

    override void visit(LineInitExp e)
    {
        e.type = Type.tint32;
        result = e;
    }

    override void visit(ModuleInitExp e)
    {
        //printf("ModuleInitExp::semantic()\n");
        e.type = Type.tstring;
        result = e;
    }

    override void visit(FuncInitExp e)
    {
        //printf("FuncInitExp::semantic()\n");
        e.type = Type.tstring;
        if (sc.func)
        {
            result = e.resolveLoc(Loc(), sc);
            return;
        }
        result = e;
    }

    override void visit(PrettyFuncInitExp e)
    {
        //printf("PrettyFuncInitExp::semantic()\n");
        e.type = Type.tstring;
        if (sc.func)
        {
            result = e.resolveLoc(Loc(), sc);
            return;
        }

        result = e;
    }
}

/**********************************
 * Try to run semantic routines.
 * If they fail, return NULL.
 */
Expression trySemantic(Expression exp, Scope* sc)
{
    //printf("+trySemantic(%s)\n", toChars());
    uint errors = global.startGagging();
    Expression e = semantic(exp, sc);
    if (global.endGagging(errors))
    {
        e = null;
    }
    //printf("-trySemantic(%s)\n", toChars());
    return e;
}

/**************************
 * Helper function for easy error propagation.
 * If error occurs, returns ErrorExp. Otherwise returns NULL.
 */
Expression unaSemantic(UnaExp e, Scope* sc)
{
    static if (LOGSEMANTIC)
    {
        printf("UnaExp::semantic('%s')\n", e.toChars());
    }
    Expression e1x = e.e1.semantic(sc);
    if (e1x.op == TOKerror)
        return e1x;
    e.e1 = e1x;
    return null;
}

/**************************
 * Helper function for easy error propagation.
 * If error occurs, returns ErrorExp. Otherwise returns NULL.
 */
Expression binSemantic(BinExp e, Scope* sc)
{
    static if (LOGSEMANTIC)
    {
        printf("BinExp::semantic('%s')\n", e.toChars());
    }
    Expression e1x = e.e1.semantic(sc);
    Expression e2x = e.e2.semantic(sc);
    if (e1x.op == TOKerror)
        return e1x;
    if (e2x.op == TOKerror)
        return e2x;
    e.e1 = e1x;
    e.e2 = e2x;
    return null;
}

Expression binSemanticProp(BinExp e, Scope* sc)
{
    if (Expression ex = binSemantic(e, sc))
        return ex;
    Expression e1x = resolveProperties(sc, e.e1);
    Expression e2x = resolveProperties(sc, e.e2);
    if (e1x.op == TOKerror)
        return e1x;
    if (e2x.op == TOKerror)
        return e2x;
    e.e1 = e1x;
    e.e2 = e2x;
    return null;
}

// entrypoint for semantic ExpressionSemanticVisitor
extern (C++) Expression semantic(Expression e, Scope* sc)
{
    scope v = new ExpressionSemanticVisitor(sc);
    e.accept(v);
    return v.result;
}

Expression semanticX(DotIdExp exp, Scope* sc)
{
    //printf("DotIdExp::semanticX(this = %p, '%s')\n", this, toChars());
    if (Expression ex = unaSemantic(exp, sc))
        return ex;

    if (exp.ident == Id._mangleof)
    {
        // symbol.mangleof
        Dsymbol ds;
        switch (exp.e1.op)
        {
        case TOKscope:
            ds = (cast(ScopeExp)exp.e1).sds;
            goto L1;
        case TOKvar:
            ds = (cast(VarExp)exp.e1).var;
            goto L1;
        case TOKdotvar:
            ds = (cast(DotVarExp)exp.e1).var;
            goto L1;
        case TOKoverloadset:
            ds = (cast(OverExp)exp.e1).vars;
            goto L1;
        case TOKtemplate:
            {
                TemplateExp te = cast(TemplateExp)exp.e1;
                ds = te.fd ? cast(Dsymbol)te.fd : te.td;
            }
        L1:
            {
                assert(ds);
                if (auto f = ds.isFuncDeclaration())
                {
                    if (f.checkForwardRef(exp.loc))
                    {
                        return new ErrorExp();
                    }
                }
                OutBuffer buf;
                mangleToBuffer(ds, &buf);
                const s = buf.peekSlice();
                Expression e = new StringExp(exp.loc, buf.extractString(), s.length);
                e = e.semantic(sc);
                return e;
            }
        default:
            break;
        }
    }

    if (exp.e1.op == TOKvar && exp.e1.type.toBasetype().ty == Tsarray && exp.ident == Id.length)
    {
        // bypass checkPurity
        return exp.e1.type.dotExp(sc, exp.e1, exp.ident, exp.noderef ? Type.DotExpFlag.noDeref : 0);
    }

    if (exp.e1.op == TOKdot)
    {
    }
    else
    {
        exp.e1 = resolvePropertiesX(sc, exp.e1);
    }
    if (exp.e1.op == TOKtuple && exp.ident == Id.offsetof)
    {
        /* 'distribute' the .offsetof to each of the tuple elements.
         */
        TupleExp te = cast(TupleExp)exp.e1;
        auto exps = new Expressions();
        exps.setDim(te.exps.dim);
        for (size_t i = 0; i < exps.dim; i++)
        {
            Expression e = (*te.exps)[i];
            e = e.semantic(sc);
            e = new DotIdExp(e.loc, e, Id.offsetof);
            (*exps)[i] = e;
        }
        // Don't evaluate te.e0 in runtime
        Expression e = new TupleExp(exp.loc, null, exps);
        e = e.semantic(sc);
        return e;
    }
    if (exp.e1.op == TOKtuple && exp.ident == Id.length)
    {
        TupleExp te = cast(TupleExp)exp.e1;
        // Don't evaluate te.e0 in runtime
        Expression e = new IntegerExp(exp.loc, te.exps.dim, Type.tsize_t);
        return e;
    }

    // https://issues.dlang.org/show_bug.cgi?id=14416
    // Template has no built-in properties except for 'stringof'.
    if ((exp.e1.op == TOKdottd || exp.e1.op == TOKtemplate) && exp.ident != Id.stringof)
    {
        exp.error("template %s does not have property '%s'", exp.e1.toChars(), exp.ident.toChars());
        return new ErrorExp();
    }
    if (!exp.e1.type)
    {
        exp.error("expression %s does not have property '%s'", exp.e1.toChars(), exp.ident.toChars());
        return new ErrorExp();
    }

    return exp;
}

// Resolve e1.ident without seeing UFCS.
// If flag == 1, stop "not a property" error and return NULL.
Expression semanticY(DotIdExp exp, Scope* sc, int flag)
{
    //printf("DotIdExp::semanticY(this = %p, '%s')\n", this, toChars());

    //{ static int z; fflush(stdout); if (++z == 10) *(char*)0=0; }

    /* Special case: rewrite this.id and super.id
     * to be classtype.id and baseclasstype.id
     * if we have no this pointer.
     */
    if ((exp.e1.op == TOKthis || exp.e1.op == TOKsuper) && !hasThis(sc))
    {
        if (AggregateDeclaration ad = sc.getStructClassScope())
        {
            if (exp.e1.op == TOKthis)
            {
                exp.e1 = new TypeExp(exp.e1.loc, ad.type);
            }
            else
            {
                ClassDeclaration cd = ad.isClassDeclaration();
                if (cd && cd.baseClass)
                    exp.e1 = new TypeExp(exp.e1.loc, cd.baseClass.type);
            }
        }
    }

    Expression e = semanticX(exp, sc);
    if (e != exp)
        return e;

    Expression eleft;
    Expression eright;
    if (exp.e1.op == TOKdot)
    {
        DotExp de = cast(DotExp)exp.e1;
        eleft = de.e1;
        eright = de.e2;
    }
    else
    {
        eleft = null;
        eright = exp.e1;
    }

    Type t1b = exp.e1.type.toBasetype();

    if (eright.op == TOKscope) // also used for template alias's
    {
        ScopeExp ie = cast(ScopeExp)eright;

        int flags = SearchLocalsOnly;
        /* Disable access to another module's private imports.
         * The check for 'is sds our current module' is because
         * the current module should have access to its own imports.
         */
        if (ie.sds.isModule() && ie.sds != sc._module)
            flags |= IgnorePrivateImports;
        if (sc.flags & SCOPEignoresymbolvisibility)
            flags |= IgnoreSymbolVisibility;
        Dsymbol s = ie.sds.search(exp.loc, exp.ident, flags);
        /* Check for visibility before resolving aliases because public
         * aliases to private symbols are public.
         */
        if (s && !(sc.flags & SCOPEignoresymbolvisibility) && !symbolIsVisible(sc._module, s))
        {
            if (s.isDeclaration())
                error(exp.loc, "%s is not visible from module %s", s.toPrettyChars(), sc._module.toChars());
            else
                deprecation(exp.loc, "%s is not visible from module %s", s.toPrettyChars(), sc._module.toChars());
            // s = null;
        }
        if (s)
        {
            if (auto p = s.isPackage())
                checkAccess(exp.loc, sc, p);

            // if 's' is a tuple variable, the tuple is returned.
            s = s.toAlias();

            exp.checkDeprecated(sc, s);

            EnumMember em = s.isEnumMember();
            if (em)
            {
                return em.getVarExp(exp.loc, sc);
            }
            VarDeclaration v = s.isVarDeclaration();
            if (v)
            {
                //printf("DotIdExp:: Identifier '%s' is a variable, type '%s'\n", toChars(), v.type.toChars());
                if (!v.type ||
                    !v.type.deco && v.inuse)
                {
                    if (v.inuse)
                        exp.error("circular reference to %s '%s'", v.kind(), v.toPrettyChars());
                    else
                        exp.error("forward reference to %s '%s'", v.kind(), v.toPrettyChars());
                    return new ErrorExp();
                }
                if (v.type.ty == Terror)
                    return new ErrorExp();

                if ((v.storage_class & STCmanifest) && v._init && !exp.wantsym)
                {
                    /* Normally, the replacement of a symbol with its initializer is supposed to be in semantic2().
                     * Introduced by https://github.com/dlang/dmd/pull/5588 which should probably
                     * be reverted. `wantsym` is the hack to work around the problem.
                     */
                    if (v.inuse)
                    {
                        error(exp.loc, "circular initialization of %s '%s'", v.kind(), v.toPrettyChars());
                        return new ErrorExp();
                    }
                    e = v.expandInitializer(exp.loc);
                    v.inuse++;
                    e = e.semantic(sc);
                    v.inuse--;
                    return e;
                }

                if (v.needThis())
                {
                    if (!eleft)
                        eleft = new ThisExp(exp.loc);
                    e = new DotVarExp(exp.loc, eleft, v);
                    e = e.semantic(sc);
                }
                else
                {
                    e = new VarExp(exp.loc, v);
                    if (eleft)
                    {
                        e = new CommaExp(exp.loc, eleft, e);
                        e.type = v.type;
                    }
                }
                e = e.deref();
                return e.semantic(sc);
            }

            FuncDeclaration f = s.isFuncDeclaration();
            if (f)
            {
                //printf("it's a function\n");
                if (!f.functionSemantic())
                    return new ErrorExp();
                if (f.needThis())
                {
                    if (!eleft)
                        eleft = new ThisExp(exp.loc);
                    e = new DotVarExp(exp.loc, eleft, f, true);
                    e = e.semantic(sc);
                }
                else
                {
                    e = new VarExp(exp.loc, f, true);
                    if (eleft)
                    {
                        e = new CommaExp(exp.loc, eleft, e);
                        e.type = f.type;
                    }
                }
                return e;
            }
            if (auto td = s.isTemplateDeclaration())
            {
                if (eleft)
                    e = new DotTemplateExp(exp.loc, eleft, td);
                else
                    e = new TemplateExp(exp.loc, td);
                e = e.semantic(sc);
                return e;
            }
            if (OverDeclaration od = s.isOverDeclaration())
            {
                e = new VarExp(exp.loc, od, true);
                if (eleft)
                {
                    e = new CommaExp(exp.loc, eleft, e);
                    e.type = Type.tvoid; // ambiguous type?
                }
                return e;
            }
            OverloadSet o = s.isOverloadSet();
            if (o)
            {
                //printf("'%s' is an overload set\n", o.toChars());
                return new OverExp(exp.loc, o);
            }

            if (auto t = s.getType())
            {
                return (new TypeExp(exp.loc, t)).semantic(sc);
            }

            TupleDeclaration tup = s.isTupleDeclaration();
            if (tup)
            {
                if (eleft)
                {
                    e = new DotVarExp(exp.loc, eleft, tup);
                    e = e.semantic(sc);
                    return e;
                }
                e = new TupleExp(exp.loc, tup);
                e = e.semantic(sc);
                return e;
            }

            ScopeDsymbol sds = s.isScopeDsymbol();
            if (sds)
            {
                //printf("it's a ScopeDsymbol %s\n", ident.toChars());
                e = new ScopeExp(exp.loc, sds);
                e = e.semantic(sc);
                if (eleft)
                    e = new DotExp(exp.loc, eleft, e);
                return e;
            }

            Import imp = s.isImport();
            if (imp)
            {
                ie = new ScopeExp(exp.loc, imp.pkg);
                return ie.semantic(sc);
            }
            // BUG: handle other cases like in IdentifierExp::semantic()
            debug
            {
                printf("s = '%s', kind = '%s'\n", s.toChars(), s.kind());
            }
            assert(0);
        }
        else if (exp.ident == Id.stringof)
        {
            const p = ie.toChars();
            e = new StringExp(exp.loc, cast(char*)p, strlen(p));
            e = e.semantic(sc);
            return e;
        }
        if (ie.sds.isPackage() || ie.sds.isImport() || ie.sds.isModule())
        {
            flag = 0;
        }
        if (flag)
            return null;
        s = ie.sds.search_correct(exp.ident);
        if (s)
            exp.error("undefined identifier `%s` in %s `%s`, did you mean %s `%s`?", exp.ident.toChars(), ie.sds.kind(), ie.sds.toPrettyChars(), s.kind(), s.toChars());
        else
            exp.error("undefined identifier `%s` in %s `%s`", exp.ident.toChars(), ie.sds.kind(), ie.sds.toPrettyChars());
        return new ErrorExp();
    }
    else if (t1b.ty == Tpointer && exp.e1.type.ty != Tenum && exp.ident != Id._init && exp.ident != Id.__sizeof && exp.ident != Id.__xalignof && exp.ident != Id.offsetof && exp.ident != Id._mangleof && exp.ident != Id.stringof)
    {
        Type t1bn = t1b.nextOf();
        if (flag)
        {
            AggregateDeclaration ad = isAggregate(t1bn);
            if (ad && !ad.members) // https://issues.dlang.org/show_bug.cgi?id=11312
                return null;
        }

        /* Rewrite:
         *   p.ident
         * as:
         *   (*p).ident
         */
        if (flag && t1bn.ty == Tvoid)
            return null;
        e = new PtrExp(exp.loc, exp.e1);
        e = e.semantic(sc);
        return e.type.dotExp(sc, e, exp.ident, flag | (exp.noderef ? Type.DotExpFlag.noDeref : 0));
    }
    else
    {
        if (exp.e1.op == TOKtype || exp.e1.op == TOKtemplate)
            flag = 0;
        e = exp.e1.type.dotExp(sc, exp.e1, exp.ident, flag | (exp.noderef ? Type.DotExpFlag.noDeref : 0));
        if (e)
            e = e.semantic(sc);
        return e;
    }
}

// Resolve e1.ident!tiargs without seeing UFCS.
// If flag == 1, stop "not a property" error and return NULL.
Expression semanticY(DotTemplateInstanceExp exp, Scope* sc, int flag)
{
    static if (LOGSEMANTIC)
    {
        printf("DotTemplateInstanceExpY::semantic('%s')\n", exp.toChars());
    }

    auto die = new DotIdExp(exp.loc, exp.e1, exp.ti.name);

    Expression e = die.semanticX(sc);
    if (e == die)
    {
        exp.e1 = die.e1; // take back
        Type t1b = exp.e1.type.toBasetype();
        if (t1b.ty == Tarray || t1b.ty == Tsarray || t1b.ty == Taarray || t1b.ty == Tnull || (t1b.isTypeBasic() && t1b.ty != Tvoid))
        {
            /* No built-in type has templatized properties, so do shortcut.
             * It is necessary in: 1024.max!"a < b"
             */
            if (flag)
                return null;
        }
        e = die.semanticY(sc, flag);
        if (flag && e && isDotOpDispatch(e))
        {
            /* opDispatch!tiargs would be a function template that needs IFTI,
             * so it's not a template
             */
            e = null; /* fall down to UFCS */
        }
        if (flag && !e)
            return null;
    }
    assert(e);

L1:
    if (e.op == TOKerror)
        return e;
    if (e.op == TOKdotvar)
    {
        DotVarExp dve = cast(DotVarExp)e;
        if (FuncDeclaration fd = dve.var.isFuncDeclaration())
        {
            TemplateDeclaration td = fd.findTemplateDeclRoot();
            if (td)
            {
                e = new DotTemplateExp(dve.loc, dve.e1, td);
                e = e.semantic(sc);
            }
        }
        else if (OverDeclaration od = dve.var.isOverDeclaration())
        {
            exp.e1 = dve.e1; // pull semantic() result

            if (!exp.findTempDecl(sc))
                goto Lerr;
            if (exp.ti.needsTypeInference(sc))
                return exp;
            exp.ti.semantic(sc);
            if (!exp.ti.inst || exp.ti.errors) // if template failed to expand
                return new ErrorExp();

            Dsymbol s = exp.ti.toAlias();
            Declaration v = s.isDeclaration();
            if (v)
            {
                if (v.type && !v.type.deco)
                    v.type = v.type.semantic(v.loc, sc);
                e = new DotVarExp(exp.loc, exp.e1, v);
                e = e.semantic(sc);
                return e;
            }
            e = new ScopeExp(exp.loc, exp.ti);
            e = new DotExp(exp.loc, exp.e1, e);
            e = e.semantic(sc);
            return e;
        }
    }
    else if (e.op == TOKvar)
    {
        VarExp ve = cast(VarExp)e;
        if (FuncDeclaration fd = ve.var.isFuncDeclaration())
        {
            TemplateDeclaration td = fd.findTemplateDeclRoot();
            if (td)
            {
                e = new TemplateExp(ve.loc, td);
                e = e.semantic(sc);
            }
        }
        else if (OverDeclaration od = ve.var.isOverDeclaration())
        {
            exp.ti.tempdecl = od;
            e = new ScopeExp(exp.loc, exp.ti);
            e = e.semantic(sc);
            return e;
        }
    }
    if (e.op == TOKdottd)
    {
        DotTemplateExp dte = cast(DotTemplateExp)e;
        exp.e1 = dte.e1; // pull semantic() result

        exp.ti.tempdecl = dte.td;
        if (!exp.ti.semanticTiargs(sc))
            return new ErrorExp();
        if (exp.ti.needsTypeInference(sc))
            return exp;
        exp.ti.semantic(sc);
        if (!exp.ti.inst || exp.ti.errors) // if template failed to expand
            return new ErrorExp();

        Dsymbol s = exp.ti.toAlias();
        Declaration v = s.isDeclaration();
        if (v && (v.isFuncDeclaration() || v.isVarDeclaration()))
        {
            e = new DotVarExp(exp.loc, exp.e1, v);
            e = e.semantic(sc);
            return e;
        }
        e = new ScopeExp(exp.loc, exp.ti);
        e = new DotExp(exp.loc, exp.e1, e);
        e = e.semantic(sc);
        return e;
    }
    else if (e.op == TOKtemplate)
    {
        exp.ti.tempdecl = (cast(TemplateExp)e).td;
        e = new ScopeExp(exp.loc, exp.ti);
        e = e.semantic(sc);
        return e;
    }
    else if (e.op == TOKdot)
    {
        DotExp de = cast(DotExp)e;

        if (de.e2.op == TOKoverloadset)
        {
            if (!exp.findTempDecl(sc) || !exp.ti.semanticTiargs(sc))
            {
                return new ErrorExp();
            }
            if (exp.ti.needsTypeInference(sc))
                return exp;
            exp.ti.semantic(sc);
            if (!exp.ti.inst || exp.ti.errors) // if template failed to expand
                return new ErrorExp();

            Dsymbol s = exp.ti.toAlias();
            Declaration v = s.isDeclaration();
            if (v)
            {
                if (v.type && !v.type.deco)
                    v.type = v.type.semantic(v.loc, sc);
                e = new DotVarExp(exp.loc, exp.e1, v);
                e = e.semantic(sc);
                return e;
            }
            e = new ScopeExp(exp.loc, exp.ti);
            e = new DotExp(exp.loc, exp.e1, e);
            e = e.semantic(sc);
            return e;
        }
    }
    else if (e.op == TOKoverloadset)
    {
        OverExp oe = cast(OverExp)e;
        exp.ti.tempdecl = oe.vars;
        e = new ScopeExp(exp.loc, exp.ti);
        e = e.semantic(sc);
        return e;
    }

Lerr:
    exp.error("%s isn't a template", e.toChars());
    return new ErrorExp();
}
