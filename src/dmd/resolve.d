/**
 * Resolve identifiers to either a type, symbol, or expression.
 *
 * Copyright:   Copyright (C) 1999-2022 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/resolve.d, _resolve.d)
 * Documentation:  https://dlang.org/phobos/dmd_resolve.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/resolve.d
 */

module dmd.resolve;

import core.stdc.string;
import core.stdc.stdio;

import dmd.access;
import dmd.arraytypes;
import dmd.astenums;
import dmd.declaration;
import dmd.dscope;
import dmd.dsymbol;
import dmd.dsymbolsem;
import dmd.dtemplate;
import dmd.errors;
import dmd.expression;
import dmd.expressionsem;
import dmd.func;
import dmd.globals;
import dmd.id;
import dmd.identifier;
import dmd.imphint;
import dmd.mtype;
import dmd.root.rootobject;
import dmd.target;
import dmd.tokens;
import dmd.typesem;

/***************************************
 * Prints `undefined identifier` error, and look for what the user might have intended.
 * Params:
 *      loc = location for error messages
 *      sc = context
 *      ident = name of unresolved identifier
 */
void resolveError(const ref Loc loc, Scope* sc, Identifier ident)
{
    if (const n = importHint(ident.toString()))
        error(loc, "`%s` is not defined, perhaps `import %.*s;` is needed?", ident.toChars(), cast(int)n.length, n.ptr);
    else if (auto s2 = sc.search_correct(ident))
        error(loc, "undefined identifier `%s`, did you mean %s `%s`?", ident.toChars(), s2.kind(), s2.toChars());
    else if (const q = Scope.search_correct_C(ident))
        error(loc, "undefined identifier `%s`, did you mean `%s`?", ident.toChars(), q);
    else if ((ident == Id.This   && sc.getStructClassScope()) ||
             (ident == Id._super && sc.getClassScope()))
        error(loc, "undefined identifier `%s`, did you mean `typeof(%s)`?", ident.toChars(), ident.toChars());
    else if (ident == Id.dollar)
        error(loc, "undefined identifier `$`");
    else
        error(loc, "undefined identifier `%s`", ident.toChars());
}

/***************************************
 * Resolve identifier `ident` to a symbol.
 * Params:
 *      loc = location for error messages
 *      sc = context
 *      ident = name to look up
 *      scopesym = if symbol is found, set to scope that `ident` was found in
 */
Dsymbol resolveIdentifier(const ref Loc loc, Scope* sc, Identifier ident, out Dsymbol scopesym)
{
    Dsymbol s = sc.search(loc, ident, &scopesym);
    /*
     * https://issues.dlang.org/show_bug.cgi?id=1170
     * https://issues.dlang.org/show_bug.cgi?id=10739
     *
     * If a symbol is not found, it might be declared in
     * a mixin-ed string or a mixin-ed template, so before
     * issuing an error semantically analyze all string/template
     * mixins that are members of the current ScopeDsymbol.
     */
    if (!s && sc.enclosing)
    {
        ScopeDsymbol sds = sc.enclosing.scopesym;
        if (sds && sds.members)
        {
            void semanticOnMixin(Dsymbol member)
            {
                if (auto compileDecl = member.isCompileDeclaration())
                    compileDecl.dsymbolSemantic(sc);
                else if (auto mixinTempl = member.isTemplateMixin())
                    mixinTempl.dsymbolSemantic(sc);
            }
            sds.members.foreachDsymbol( s => semanticOnMixin(s) );
            s = sc.search(loc, ident, &scopesym);
        }
    }

    if (s)
    {
        // https://issues.dlang.org/show_bug.cgi?id=16042
        // If `f` is really a function template, then replace `f`
        // with the function template declaration.
        if (auto f = s.isFuncDeclaration())
        {
            if (auto td = getFuncTemplateDecl(f))
            {
                // If not at the beginning of the overloaded list of
                // `TemplateDeclaration`s, then get the beginning
                if (td.overroot)
                    td = td.overroot;
                return td;
            }
        }
    }
    return s;
}

/************************************
 * Resolve type 'mt' to either type, symbol, or expression.
 * If errors happened, resolved to Type.terror.
 *
 * Params:
 *  mt = type to be resolved
 *  loc = the location where the type is encountered
 *  sc = the scope of the type
 *  pe = is set if t is an expression
 *  pt = is set if t is a type
 *  ps = is set if t is a symbol
 *  intypeid = true if in type id
 */
void resolve(Type mt, const ref Loc loc, Scope* sc, out Expression pe, out Type pt, out Dsymbol ps, bool intypeid = false)
{
    void returnExp(Expression e)
    {
        pe = e;
        pt = null;
        ps = null;
    }

    void returnType(Type t)
    {
        pe = null;
        pt = t;
        ps = null;
    }

    void returnSymbol(Dsymbol s)
    {
        pe = null;
        pt = null;
        ps = s;
    }

    void returnError()
    {
        returnType(Type.terror);
    }

    void visitType(Type mt)
    {
        //printf("Type::resolve() %s, %d\n", mt.toChars(), mt.ty);
        Type t = typeSemantic(mt, loc, sc);
        assert(t);
        returnType(t);
    }

    void visitSArray(TypeSArray mt)
    {
        //printf("TypeSArray::resolve() %s\n", mt.toChars());
        mt.next.resolve(loc, sc, pe, pt, ps, intypeid);
        //printf("s = %p, e = %p, t = %p\n", ps, pe, pt);
        if (pe)
        {
            // It's really an index expression
            if (Dsymbol s = getDsymbol(pe))
                pe = new DsymbolExp(loc, s);
            returnExp(new ArrayExp(loc, pe, mt.dim));
        }
        else if (ps)
        {
            Dsymbol s = ps;
            if (auto tup = s.isTupleDeclaration())
            {
                mt.dim = semanticLength(sc, tup, mt.dim);
                mt.dim = mt.dim.ctfeInterpret();
                if (mt.dim.op == EXP.error)
                    return returnError();

                const d = mt.dim.toUInteger();
                if (d >= tup.objects.dim)
                {
                    error(loc, "tuple index `%llu` exceeds length %llu", d, cast(ulong) tup.objects.dim);
                    return returnError();
                }

                RootObject o = (*tup.objects)[cast(size_t)d];
                switch (o.dyncast()) with (DYNCAST)
                {
                case dsymbol:
                    return returnSymbol(cast(Dsymbol)o);
                case expression:
                    Expression e = cast(Expression)o;
                    if (e.op == EXP.dSymbol)
                        return returnSymbol(e.isDsymbolExp().s);
                    else
                        return returnExp(e);
                case type:
                    return returnType((cast(Type)o).addMod(mt.mod));
                default:
                    break;
                }

                /* Create a new TupleDeclaration which
                 * is a slice [d..d+1] out of the old one.
                 * Do it this way because TemplateInstance::semanticTiargs()
                 * can handle unresolved Objects this way.
                 */
                auto objects = new Objects(1);
                (*objects)[0] = o;
                return returnSymbol(new TupleDeclaration(loc, tup.ident, objects));
            }
            else
                return visitType(mt);
        }
        else
        {
            if (pt.ty != Terror)
                mt.next = pt; // prevent re-running semantic() on 'next'
            visitType(mt);
        }

    }

    void visitDArray(TypeDArray mt)
    {
        //printf("TypeDArray::resolve() %s\n", mt.toChars());
        mt.next.resolve(loc, sc, pe, pt, ps, intypeid);
        //printf("s = %p, e = %p, t = %p\n", ps, pe, pt);
        if (pe)
        {
            // It's really a slice expression
            if (Dsymbol s = getDsymbol(pe))
                pe = new DsymbolExp(loc, s);
            returnExp(new ArrayExp(loc, pe));
        }
        else if (ps)
        {
            if (auto tup = ps.isTupleDeclaration())
            {
                // keep ps
            }
            else
                visitType(mt);
        }
        else
        {
            if (pt.ty != Terror)
                mt.next = pt; // prevent re-running semantic() on 'next'
            visitType(mt);
        }
    }

    void visitAArray(TypeAArray mt)
    {
        //printf("TypeAArray::resolve() %s\n", mt.toChars());
        // Deal with the case where we thought the index was a type, but
        // in reality it was an expression.
        if (mt.index.ty == Tident || mt.index.ty == Tinstance || mt.index.ty == Tsarray)
        {
            Expression e;
            Type t;
            Dsymbol s;
            mt.index.resolve(loc, sc, e, t, s, intypeid);
            if (e)
            {
                // It was an expression -
                // Rewrite as a static array
                auto tsa = new TypeSArray(mt.next, e);
                tsa.mod = mt.mod; // just copy mod field so tsa's semantic is not yet done
                return tsa.resolve(loc, sc, pe, pt, ps, intypeid);
            }
            else if (t)
                mt.index = t;
            else
                .error(loc, "index is not a type or an expression");
        }
        visitType(mt);
    }

    /*************************************
     * Takes an array of Identifiers and figures out if
     * it represents a Type or an Expression.
     * Output:
     *      if expression, pe is set
     *      if type, pt is set
     */
    void visitIdentifier(TypeIdentifier mt)
    {
        //printf("TypeIdentifier::resolve(sc = %p, idents = '%s')\n", sc, mt.toChars());
        if (mt.ident == Id.ctfe)
        {
            error(loc, "variable `__ctfe` cannot be read at compile time");
            return returnError();
        }
        if (mt.ident == Id.builtin_va_list) // gcc has __builtin_va_xxxx for stdarg.h
        {
            /* Since we don't support __builtin_va_start, -arg, -end, we don't
             * have to actually care what -list is. A void* will do.
             * If we ever do care, import core.stdc.stdarg and pull
             * the definition out of that, similarly to how std.math is handled for PowExp
             */
            pt = target.va_listType(loc, sc);
            return;
        }

        Dsymbol scopesym;
        Dsymbol s = resolveIdentifier(loc, sc, mt.ident, scopesym);

        mt.resolveHelper(loc, sc, s, scopesym, pe, pt, ps, intypeid);
        if (pt)
            pt = pt.addMod(mt.mod);
    }

    void visitInstance(TypeInstance mt)
    {
        // Note close similarity to TypeIdentifier::resolve()

        //printf("TypeInstance::resolve(sc = %p, tempinst = '%s')\n", sc, mt.tempinst.toChars());
        mt.tempinst.dsymbolSemantic(sc);
        if (!global.gag && mt.tempinst.errors)
            return returnError();

        mt.resolveHelper(loc, sc, mt.tempinst, null, pe, pt, ps, intypeid);
        if (pt)
            pt = pt.addMod(mt.mod);
        //if (pt) printf("pt = %d '%s'\n", pt.ty, pt.toChars());
    }

    void visitTypeof(TypeTypeof mt)
    {
        //printf("TypeTypeof::resolve(this = %p, sc = %p, idents = '%s')\n", mt, sc, mt.toChars());
        //static int nest; if (++nest == 50) *(char*)0=0;
        if (sc is null)
        {
            error(loc, "invalid scope");
            return returnError();
        }
        if (mt.inuse)
        {
            mt.inuse = 2;
            error(loc, "circular `typeof` definition");
        Lerr:
            mt.inuse--;
            return returnError();
        }
        mt.inuse++;

        /* Currently we cannot evaluate 'exp' in speculative context, because
         * the type implementation may leak to the final execution. Consider:
         *
         * struct S(T) {
         *   string toString() const { return "x"; }
         * }
         * void main() {
         *   alias X = typeof(S!int());
         *   assert(typeid(X).toString() == "x");
         * }
         */
        Scope* sc2 = sc.push();

        if (!mt.exp.isTypeidExp())
            /* Treat typeof(typeid(exp)) as needing
             * the full semantic analysis of the typeid.
             * https://issues.dlang.org/show_bug.cgi?id=20958
             */
            sc2.intypeof = 1;

        auto exp2 = mt.exp.expressionSemantic(sc2);
        exp2 = resolvePropertiesOnly(sc2, exp2);
        sc2.pop();

        if (exp2.op == EXP.error)
        {
            if (!global.gag)
                mt.exp = exp2;
            goto Lerr;
        }
        mt.exp = exp2;

        if (mt.exp.op == EXP.type ||
            mt.exp.op == EXP.scope_)
        {
            if (!(sc.flags & SCOPE.Cfile) && // in (extended) C typeof may be used on types as with sizeof
                mt.exp.checkType())
                goto Lerr;

            /* Today, 'typeof(func)' returns void if func is a
             * function template (TemplateExp), or
             * template lambda (FuncExp).
             * It's actually used in Phobos as an idiom, to branch code for
             * template functions.
             */
        }
        if (auto f = mt.exp.op == EXP.variable    ? mt.exp.isVarExp().var.isFuncDeclaration()
                   : mt.exp.op == EXP.dotVariable ? mt.exp.isDotVarExp().var.isFuncDeclaration() : null)
        {
            // f might be a unittest declaration which is incomplete when compiled
            // without -unittest. That causes a segfault in checkForwardRef, see
            // https://issues.dlang.org/show_bug.cgi?id=20626
            if ((!f.isUnitTestDeclaration() || global.params.useUnitTests) && f.checkForwardRef(loc))
                goto Lerr;
        }
        if (auto f = isFuncAddress(mt.exp))
        {
            if (f.checkForwardRef(loc))
                goto Lerr;
        }

        Type t = mt.exp.type;
        if (!t)
        {
            error(loc, "expression `%s` has no type", mt.exp.toChars());
            goto Lerr;
        }
        if (t.ty == Ttypeof)
        {
            error(loc, "forward reference to `%s`", mt.toChars());
            goto Lerr;
        }
        if (mt.idents.dim == 0)
        {
            returnType(t.addMod(mt.mod));
        }
        else
        {
            if (Dsymbol s = t.toDsymbol(sc))
                mt.resolveHelper(loc, sc, s, null, pe, pt, ps, intypeid);
            else
            {
                auto e = typeToExpressionHelper(mt, new TypeExp(loc, t));
                e = e.expressionSemantic(sc);
                resolveExp(e, pt, pe, ps);
            }
            if (pt)
                pt = pt.addMod(mt.mod);
        }
        mt.inuse--;
    }

    void visitReturn(TypeReturn mt)
    {
        //printf("TypeReturn::resolve(sc = %p, idents = '%s')\n", sc, mt.toChars());
        Type t;
        {
            FuncDeclaration func = sc.func;
            if (!func)
            {
                error(loc, "`typeof(return)` must be inside function");
                return returnError();
            }
            if (func.fes)
                func = func.fes.func;
            t = func.type.nextOf();
            if (!t)
            {
                error(loc, "cannot use `typeof(return)` inside function `%s` with inferred return type", sc.func.toChars());
                return returnError();
            }
        }
        if (mt.idents.dim == 0)
        {
            return returnType(t.addMod(mt.mod));
        }
        else
        {
            if (Dsymbol s = t.toDsymbol(sc))
                mt.resolveHelper(loc, sc, s, null, pe, pt, ps, intypeid);
            else
            {
                auto e = typeToExpressionHelper(mt, new TypeExp(loc, t));
                e = e.expressionSemantic(sc);
                resolveExp(e, pt, pe, ps);
            }
            if (pt)
                pt = pt.addMod(mt.mod);
        }
    }

    void visitSlice(TypeSlice mt)
    {
        mt.next.resolve(loc, sc, pe, pt, ps, intypeid);
        if (pe)
        {
            // It's really a slice expression
            if (Dsymbol s = getDsymbol(pe))
                pe = new DsymbolExp(loc, s);
            return returnExp(new ArrayExp(loc, pe, new IntervalExp(loc, mt.lwr, mt.upr)));
        }
        else if (ps)
        {
            Dsymbol s = ps;
            TupleDeclaration td = s.isTupleDeclaration();
            if (td)
            {
                /* It's a slice of a TupleDeclaration
                 */
                ScopeDsymbol sym = new ArrayScopeSymbol(sc, td);
                sym.parent = sc.scopesym;
                sc = sc.push(sym);
                sc = sc.startCTFE();
                mt.lwr = mt.lwr.expressionSemantic(sc);
                mt.upr = mt.upr.expressionSemantic(sc);
                sc = sc.endCTFE();
                sc = sc.pop();

                mt.lwr = mt.lwr.ctfeInterpret();
                mt.upr = mt.upr.ctfeInterpret();
                const i1 = mt.lwr.toUInteger();
                const i2 = mt.upr.toUInteger();
                if (!(i1 <= i2 && i2 <= td.objects.dim))
                {
                    error(loc, "slice `[%llu..%llu]` is out of range of [0..%llu]", i1, i2, cast(ulong) td.objects.dim);
                    return returnError();
                }

                if (i1 == 0 && i2 == td.objects.dim)
                {
                    return returnSymbol(td);
                }

                /* Create a new TupleDeclaration which
                 * is a slice [i1..i2] out of the old one.
                 */
                auto objects = new Objects(cast(size_t)(i2 - i1));
                for (size_t i = 0; i < objects.dim; i++)
                {
                    (*objects)[i] = (*td.objects)[cast(size_t)i1 + i];
                }

                return returnSymbol(new TupleDeclaration(loc, td.ident, objects));
            }
            else
                visitType(mt);
        }
        else
        {
            if (pt.ty != Terror)
                mt.next = pt; // prevent re-running semantic() on 'next'
            visitType(mt);
        }
    }

    void visitMixin(TypeMixin mt)
    {
        RootObject o = mt.obj;

        // if already resolved just set pe/pt/ps and return.
        if (o)
        {
            pe = o.isExpression();
            pt = o.isType();
            ps = o.isDsymbol();
            return;
        }

        o = mt.compileTypeMixin(loc, sc);
        if (auto t = o.isType())
        {
            resolve(t, loc, sc, pe, pt, ps, intypeid);
            if (pt)
                pt = pt.addMod(mt.mod);
        }
        else if (auto e = o.isExpression())
        {
            e = e.expressionSemantic(sc);
            if (auto et = e.isTypeExp())
                returnType(et.type.addMod(mt.mod));
            else
                returnExp(e);
        }
        else
            returnError();

        // save the result
        mt.obj = pe ? pe : (pt ? pt : ps);
    }

    void visitTraits(TypeTraits mt)
    {
        // if already resolved just return the cached object.
        if (mt.obj)
        {
            pt = mt.obj.isType();
            ps = mt.obj.isDsymbol();
            return;
        }

        import dmd.traits : semanticTraits;

        if (Expression e = semanticTraits(mt.exp, sc))
        {
            switch (e.op)
            {
            case EXP.dotVariable:
                mt.obj = e.isDotVarExp().var;
                break;
            case EXP.variable:
                mt.obj = e.isVarExp().var;
                break;
            case EXP.function_:
                auto fe = e.isFuncExp();
                mt.obj = fe.td ? fe.td : fe.fd;
                break;
            case EXP.dotTemplateDeclaration:
                mt.obj = e.isDotTemplateExp().td;
                break;
            case EXP.dSymbol:
                mt.obj = e.isDsymbolExp().s;
                break;
            case EXP.template_:
                mt.obj = e.isTemplateExp().td;
                break;
            case EXP.scope_:
                mt.obj = e.isScopeExp().sds;
                break;
            case EXP.tuple:
                TupleExp te = e.isTupleExp();
                Objects* elems = new Objects(te.exps.dim);
                foreach (i; 0 .. elems.dim)
                {
                    auto src = (*te.exps)[i];
                    switch (src.op)
                    {
                    case EXP.type:
                        (*elems)[i] = src.isTypeExp().type;
                        break;
                    case EXP.dotType:
                        (*elems)[i] = src.isDotTypeExp().sym.isType();
                        break;
                    case EXP.overloadSet:
                        (*elems)[i] = src.isOverExp().type;
                        break;
                    default:
                        if (auto sym = isDsymbol(src))
                            (*elems)[i] = sym;
                        else
                            (*elems)[i] = src;
                    }
                }
                TupleDeclaration td = new TupleDeclaration(e.loc, Identifier.generateId("__aliastup"), elems);
                mt.obj = td;
                break;
            case EXP.dotType:
                mt.obj = e.isDotTypeExp().sym.isType();
                break;
            case EXP.type:
                mt.obj = e.isTypeExp().type;
                break;
            case EXP.overloadSet:
                mt.obj = e.isOverExp().type;
                break;
            default:
                break;
            }
        }

        if (mt.obj)
        {
            if (auto t = mt.obj.isType())
                returnType(t.addMod(mt.mod));
            else if (auto s = mt.obj.isDsymbol())
                returnSymbol(s);
            else
                assert(0);
        }
        else
        {
            mt.obj = Type.terror;
            return returnError();
        }
    }

    switch (mt.ty)
    {
        default:        visitType      (mt);                    break;
        case Tsarray:   visitSArray    (mt.isTypeSArray());     break;
        case Tarray:    visitDArray    (mt.isTypeDArray());     break;
        case Taarray:   visitAArray    (mt.isTypeAArray());     break;
        case Tident:    visitIdentifier(mt.isTypeIdentifier()); break;
        case Tinstance: visitInstance  (mt.isTypeInstance());   break;
        case Ttypeof:   visitTypeof    (mt.isTypeTypeof());     break;
        case Treturn:   visitReturn    (mt.isTypeReturn());     break;
        case Tslice:    visitSlice     (mt.isTypeSlice());      break;
        case Tmixin:    visitMixin     (mt.isTypeMixin());      break;
        case Ttraits:   visitTraits    (mt.isTypeTraits());     break;
    }
}

/******************************* Private *****************************************/

private:

/***************************************
 * Determine if Expression `exp` should instead be a Type, a Dsymbol, or remain an Expression.
 * Params:
 *      exp = Expression to look at
 *      t = if exp should be a Type, set t to that Type else null
 *      s = if exp should be a Dsymbol, set s to that Dsymbol else null
 *      e = if exp should remain an Expression, set e to that Expression else null
 *
 */
void resolveExp(Expression exp, out Type t, out Expression e, out Dsymbol s)
{
    if (exp.isTypeExp())
        t = exp.type;
    else if (auto ve = exp.isVarExp())
    {
        if (auto v = ve.var.isVarDeclaration())
            e = exp;
        else
            s = ve.var;
    }
    else if (auto te = exp.isTemplateExp())
        s = te.td;
    else if (auto se = exp.isScopeExp())
        s = se.sds;
    else if (exp.isFuncExp())
        s = getDsymbol(exp);
    else if (auto dte = exp.isDotTemplateExp())
        s = dte.td;
    else if (exp.isErrorExp())
        t = Type.terror;
    else
        e = exp;
}

/*************************************
 * Resolve a tuple index, `s[oindex]`, by figuring out what `s[oindex]` represents.
 * Setting one of pe/pt/ps.
 * Params:
 *      loc = location for error messages
 *      sc = context
 *      s = symbol being indexed - could be a tuple, could be an expression
 *      pe = set if s[oindex] is an Expression, otherwise null
 *      pt = set if s[oindex] is a Type, otherwise null
 *      ps = set if s[oindex] is a Dsymbol, otherwise null
 *      oindex = index into s
 */
void resolveTupleIndex(const ref Loc loc, Scope* sc, Dsymbol s, out Expression pe, out Type pt, out Dsymbol ps, RootObject oindex)
{
    auto tup = s.isTupleDeclaration();

    auto eindex = isExpression(oindex);
    auto tindex = isType(oindex);
    auto sindex = isDsymbol(oindex);

    if (!tup)
    {
        // It's really an index expression
        if (tindex)
            eindex = new TypeExp(loc, tindex);
        else if (sindex)
            eindex = symbolToExp(sindex, loc, sc, false);
        Expression e = new IndexExp(loc, symbolToExp(s, loc, sc, false), eindex);
        e = e.expressionSemantic(sc);
        resolveExp(e, pt, pe, ps);
        return;
    }

    // Convert oindex to Expression, then try to resolve to constant.
    if (tindex)
        tindex.resolve(loc, sc, eindex, tindex, sindex);
    if (sindex)
        eindex = symbolToExp(sindex, loc, sc, false);
    if (!eindex)
    {
        .error(loc, "index `%s` is not an expression", oindex.toChars());
        pt = Type.terror;
        return;
    }

    eindex = semanticLength(sc, tup, eindex);
    eindex = eindex.ctfeInterpret();
    if (eindex.op == EXP.error)
    {
        pt = Type.terror;
        return;
    }
    const(uinteger_t) d = eindex.toUInteger();
    if (d >= tup.objects.dim)
    {
        .error(loc, "tuple index `%llu` exceeds length %llu", d, cast(ulong)tup.objects.dim);
        pt = Type.terror;
        return;
    }

    RootObject o = (*tup.objects)[cast(size_t)d];
    ps = isDsymbol(o);
    if (auto t = isType(o))
        pt = t.typeSemantic(loc, sc);
    if (auto e = isExpression(o))
        resolveExp(e, pt, pe, ps);
}

/*************************************
 * Takes an array of Identifiers and figures out if
 * it represents a Type, Expression, or Dsymbol.
 * Params:
 *      mt = array of identifiers
 *      loc = location for error messages
 *      sc = context
 *      s = symbol to start search at
 *      scopesym = unused
 *      pe = set if expression otherwise null
 *      pt = set if type otherwise null
 *      ps = set if symbol otherwise null
 *      typeid = set if in TypeidExpression https://dlang.org/spec/expression.html#TypeidExpression
 */
void resolveHelper(TypeQualified mt, const ref Loc loc, Scope* sc, Dsymbol s, Dsymbol scopesym,
    out Expression pe, out Type pt, out Dsymbol ps, bool intypeid = false)
{
    version (none)
    {
        printf("TypeQualified::resolveHelper(sc = %p, idents = '%s')\n", sc, mt.toChars());
        if (scopesym)
            printf("\tscopesym = '%s'\n", scopesym.toChars());
    }

    if (!s)
    {
        resolveError(loc, sc, Identifier.idPool(mt.mutableOf().unSharedOf().toString()));
        pt = Type.terror;
        return;
    }

    //printf("\t1: s = '%s' %p, kind = '%s'\n",s.toChars(), s, s.kind());
    Declaration d = s.isDeclaration();
    if (d && (d.storage_class & STC.templateparameter))
        s = s.toAlias();
    else
    {
        // check for deprecated or disabled aliases
        // functions are checked after overloading
        // templates are checked after matching constraints
        if (!s.isFuncDeclaration() && !s.isTemplateDeclaration())
            s.checkDeprecated(loc, sc);
        if (d)
            d.checkDisabled(loc, sc, true);
    }
    s = s.toAlias();
    //printf("\t2: s = '%s' %p, kind = '%s'\n",s.toChars(), s, s.kind());
    for (size_t i = 0; i < mt.idents.dim; i++)
    {
        RootObject id = mt.idents[i];
        switch (id.dyncast()) with (DYNCAST)
        {
        case expression:
        case type:
            Type tx;
            Expression ex;
            Dsymbol sx;
            resolveTupleIndex(loc, sc, s, ex, tx, sx, id);
            if (sx)
            {
                s = sx.toAlias();
                continue;
            }
            if (tx)
                ex = new TypeExp(loc, tx);
            assert(ex);

            ex = typeToExpressionHelper(mt, ex, i + 1);
            ex = ex.expressionSemantic(sc);
            resolveExp(ex, pt, pe, ps);
            return;
        default:
            break;
        }

        Type t = s.getType(); // type symbol, type alias, or type tuple?
        uint errorsave = global.errors;
        int flags = t is null ? SearchLocalsOnly : IgnorePrivateImports;

        Dsymbol sm = s.searchX(loc, sc, id, flags);
        if (sm)
        {
            if (!(sc.flags & SCOPE.ignoresymbolvisibility) && !symbolIsVisible(sc, sm))
            {
                .error(loc, "`%s` is not visible from module `%s`", sm.toPrettyChars(), sc._module.toChars());
                sm = null;
            }
            // Same check as in Expression.semanticY(DotIdExp)
            else if (sm.isPackage() && checkAccess(sc, sm.isPackage()))
            {
                // @@@DEPRECATED_2.106@@@
                // Should be an error in 2.106. Just remove the deprecation call
                // and uncomment the null assignment
                deprecation(loc, "%s %s is not accessible here, perhaps add 'static import %s;'", sm.kind(), sm.toPrettyChars(), sm.toPrettyChars());
                //sm = null;
            }
        }
        if (global.errors != errorsave)
        {
            pt = Type.terror;
            return;
        }

        void helper3()
        {
            Expression e;
            VarDeclaration v = s.isVarDeclaration();
            FuncDeclaration f = s.isFuncDeclaration();
            if (intypeid || !v && !f)
                e = symbolToExp(s, loc, sc, true);
            else
                e = new VarExp(loc, s.isDeclaration(), true);

            e = typeToExpressionHelper(mt, e, i);
            e = e.expressionSemantic(sc);
            resolveExp(e, pt, pe, ps);
        }

        //printf("\t3: s = %p %s %s, sm = %p\n", s, s.kind(), s.toChars(), sm);
        if (intypeid && !t && sm && sm.needThis())
            return helper3();

        if (VarDeclaration v = s.isVarDeclaration())
        {
            // https://issues.dlang.org/show_bug.cgi?id=19913
            // v.type would be null if it is a forward referenced member.
            if (v.type is null)
                v.dsymbolSemantic(sc);
            if (v.storage_class & (STC.const_ | STC.immutable_ | STC.manifest) ||
                v.type.isConst() || v.type.isImmutable())
            {
                // https://issues.dlang.org/show_bug.cgi?id=13087
                // this.field is not constant always
                if (!v.isThisDeclaration())
                    return helper3();
            }
        }
        if (!sm)
        {
            if (!t)
            {
                if (s.isDeclaration()) // var, func, or tuple declaration?
                {
                    t = s.isDeclaration().type;
                    if (!t && s.isTupleDeclaration()) // expression tuple?
                        return helper3();
                }
                else if (s.isTemplateInstance() ||
                         s.isImport() || s.isPackage() || s.isModule())
                {
                    return helper3();
                }
            }
            if (t)
            {
                sm = t.toDsymbol(sc);
                if (sm && id.dyncast() == DYNCAST.identifier)
                {
                    sm = sm.search(loc, cast(Identifier)id, IgnorePrivateImports);
                    if (!sm)
                        return helper3();
                }
                else
                    return helper3();
            }
            else
            {
                if (id.dyncast() == DYNCAST.dsymbol)
                {
                    // searchX already handles errors for template instances
                    assert(global.errors);
                }
                else
                {
                    assert(id.dyncast() == DYNCAST.identifier);
                    sm = s.search_correct(cast(Identifier)id);
                    if (sm)
                        error(loc, "identifier `%s` of `%s` is not defined, did you mean %s `%s`?", id.toChars(), mt.toChars(), sm.kind(), sm.toChars());
                    else
                        error(loc, "identifier `%s` of `%s` is not defined", id.toChars(), mt.toChars());
                }
                pe = ErrorExp.get();
                return;
            }
        }
        s = sm.toAlias();
    }

    if (auto em = s.isEnumMember())
    {
        // It's not a type, it's an expression
        pe = em.getVarExp(loc, sc);
        return;
    }
    if (auto v = s.isVarDeclaration())
    {
        /* This is mostly same with DsymbolExp::semantic(), but we cannot use it
         * because some variables used in type context need to prevent lowering
         * to a literal or contextful expression. For example:
         *
         *  enum a = 1; alias b = a;
         *  template X(alias e){ alias v = e; }  alias x = X!(1);
         *  struct S { int v; alias w = v; }
         *      // TypeIdentifier 'a', 'e', and 'v' should be EXP.variable,
         *      // because getDsymbol() need to work in AliasDeclaration::semantic().
         */
        if (!v.type ||
            !v.type.deco && v.inuse)
        {
            if (v.inuse) // https://issues.dlang.org/show_bug.cgi?id=9494
                error(loc, "circular reference to %s `%s`", v.kind(), v.toPrettyChars());
            else
                error(loc, "forward reference to %s `%s`", v.kind(), v.toPrettyChars());
            pt = Type.terror;
            return;
        }
        if (v.type.ty == Terror)
            pt = Type.terror;
        else
            pe = new VarExp(loc, v);
        return;
    }
    if (auto fld = s.isFuncLiteralDeclaration())
    {
        //printf("'%s' is a function literal\n", fld.toChars());
        auto e = new FuncExp(loc, fld);
        pe = e.expressionSemantic(sc);
        return;
    }
    version (none)
    {
        if (FuncDeclaration fd = s.isFuncDeclaration())
        {
            pe = new DsymbolExp(loc, fd);
            return;
        }
    }

    Type t;
    while (1)
    {
        t = s.getType();
        if (t)
            break;
        ps = s;
        return;
    }

    if (auto ti = t.isTypeInstance())
        if (ti != mt && !ti.deco)
        {
            if (!ti.tempinst.errors)
                error(loc, "forward reference to `%s`", ti.toChars());
            pt = Type.terror;
            return;
        }

    if (t.ty == Ttuple)
        pt = t;
    else
        pt = t.merge();
}
