/**
 * Semantic analysis of template parameters.
 *
 * Copyright:   Copyright (C) 1999-2024 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/templateparamsem.d, _templateparamsem.d)
 * Documentation:  https://dlang.org/phobos/dmd_templateparamsem.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/templateparamsem.d
 */

module dmd.templateparamsem;

import dmd.arraytypes;
import dmd.astenums;
import dmd.declaration : TupleDeclaration;
import dmd.dinterpret;
import dmd.dsymbol;
import dmd.dscope;
import dmd.dtemplate;
import dmd.func;
import dmd.globals;
import dmd.location;
import dmd.expression;
import dmd.expressionsem;
import dmd.optimize;
import dmd.rootobject;
import dmd.mtype;
import dmd.typesem;
import dmd.visitor;

/************************************************
 * Performs semantic on TemplateParameter AST nodes.
 *
 * Params:
 *      tp = element of `parameters` to be semantically analyzed
 *      sc = context
 *      parameters = array of `TemplateParameters` supplied to the `TemplateDeclaration`
 * Returns:
 *      `true` if no errors
 */
bool tpsemantic(TemplateParameter tp, Scope* sc, TemplateParameters* parameters)
{
    scope v = new TemplateParameterSemanticVisitor(sc, parameters);
    tp.accept(v);
    return v.result;
}


private extern (C++) final class TemplateParameterSemanticVisitor : Visitor
{
    alias visit = Visitor.visit;

    Scope* sc;
    TemplateParameters* parameters;
    bool result;

    this(Scope* sc, TemplateParameters* parameters) scope @safe
    {
        this.sc = sc;
        this.parameters = parameters;
    }

    override void visit(TemplateTypeParameter ttp)
    {
        //printf("TemplateTypeParameter.semantic('%s')\n", ident.toChars());
        if (ttp.specType && !reliesOnTident(ttp.specType, parameters))
        {
            ttp.specType = ttp.specType.typeSemantic(ttp.loc, sc);
        }
        version (none)
        {
            // Don't do semantic() until instantiation
            if (ttp.defaultType)
            {
                ttp.defaultType = ttp.defaultType.typeSemantic(ttp.loc, sc);
            }
        }
        result = !(ttp.specType && isError(ttp.specType));
    }

    override void visit(TemplateThisParameter ttp)
    {
        import dmd.errors;

        if (!sc.getStructClassScope())
            error(ttp.loc, "cannot use `this` outside an aggregate type");
        visit(cast(TemplateTypeParameter)ttp);
    }

    override void visit(TemplateValueParameter tvp)
    {
        tvp.valType = tvp.valType.typeSemantic(tvp.loc, sc);
        version (none)
        {
            // defer semantic analysis to arg match
            if (tvp.specValue)
            {
                Expression e = tvp.specValue;
                sc = sc.startCTFE();
                e = e.semantic(sc);
                sc = sc.endCTFE();
                e = e.implicitCastTo(sc, tvp.valType);
                e = e.ctfeInterpret();
                if (e.op == EXP.int64 || e.op == EXP.float64 ||
                    e.op == EXP.complex80 || e.op == EXP.null_ || e.op == EXP.string_)
                    tvp.specValue = e;
            }

            if (tvp.defaultValue)
            {
                Expression e = defaultValue;
                sc = sc.startCTFE();
                e = e.semantic(sc);
                sc = sc.endCTFE();
                e = e.implicitCastTo(sc, tvp.valType);
                e = e.ctfeInterpret();
                if (e.op == EXP.int64)
                    tvp.defaultValue = e;
            }
        }
        result = !isError(tvp.valType);
    }

    override void visit(TemplateAliasParameter tap)
    {
        if (tap.specType && !reliesOnTident(tap.specType, parameters))
        {
            tap.specType = tap.specType.typeSemantic(tap.loc, sc);
        }
        tap.specAlias = aliasParameterSemantic(tap.loc, sc, tap.specAlias, parameters);
        version (none)
        {
            // Don't do semantic() until instantiation
            if (tap.defaultAlias)
                tap.defaultAlias = tap.defaultAlias.semantic(tap.loc, sc);
        }
        result = !(tap.specType && isError(tap.specType)) && !(tap.specAlias && isError(tap.specAlias));
    }

    override void visit(TemplateTupleParameter ttp)
    {
        result = true;
    }
}

/***********************************************
 * Support function for performing semantic analysis on `TemplateAliasParameter`.
 *
 * Params:
 *      loc = location (for error messages)
 *      sc = context
 *      o = object to run semantic() on, the `TemplateAliasParameter`s `specAlias` or `defaultAlias`
 *      parameters = array of `TemplateParameters` supplied to the `TemplateDeclaration`
 * Returns:
 *      object resulting from running `semantic` on `o`
 */
RootObject aliasParameterSemantic(Loc loc, Scope* sc, RootObject o, TemplateParameters* parameters)
{
    if (!o)
        return null;

    Expression ea = isExpression(o);
    RootObject eaCTFE()
    {
        sc = sc.startCTFE();
        ea = ea.expressionSemantic(sc);
        sc = sc.endCTFE();
        return ea.ctfeInterpret();
    }
    Type ta = isType(o);
    if (ta && (!parameters || !reliesOnTident(ta, parameters)))
    {
        Dsymbol s = ta.toDsymbol(sc);
        if (s)
            return s;
        else if (TypeInstance ti = ta.isTypeInstance())
        {
            Type t;
            const errors = global.errors;
            ta.resolve(loc, sc, ea, t, s);
            // if we had an error evaluating the symbol, suppress further errors
            if (!t && errors != global.errors)
                return Type.terror;
            // We might have something that looks like a type
            // but is actually an expression or a dsymbol
            // see https://issues.dlang.org/show_bug.cgi?id=16472
            if (t)
                return t.typeSemantic(loc, sc);
            else if (ea)
            {
                return eaCTFE();
            }
            else if (s)
                return s;
            else
                assert(0);
        }
        else
            return ta.typeSemantic(loc, sc);
    }
    else if (ea)
        return eaCTFE();
    return o;
}

/**********************************
 * Run semantic of tiargs as arguments of template.
 * Input:
 *      loc
 *      sc
 *      tiargs  array of template arguments
 *      flags   1: replace const variables with their initializers
 *              2: don't devolve Parameter to Type
 *      atd     tuple being optimized. If found, it's not expanded here
 *              but in AliasAssign semantic.
 * Returns:
 *      false if one or more arguments have errors.
 */
extern (D) bool semanticTiargs(const ref Loc loc, Scope* sc, Objects* tiargs, int flags, TupleDeclaration atd = null)
{
    // Run semantic on each argument, place results in tiargs[]
    //printf("+TemplateInstance.semanticTiargs()\n");
    if (!tiargs)
        return true;
    bool err = false;

    // The arguments are not treated as part of a default argument,
    // because they are evaluated at compile time.
    sc = sc.push();
    sc.inDefaultArg = false;

    for (size_t j = 0; j < tiargs.length; j++)
    {
        RootObject o = (*tiargs)[j];
        Type ta = isType(o);
        Expression ea = isExpression(o);
        Dsymbol sa = isDsymbol(o);

        //printf("1: (*tiargs)[%d] = %p, s=%p, v=%p, ea=%p, ta=%p\n", j, o, isDsymbol(o), isTuple(o), ea, ta);
        if (ta)
        {
            //printf("type %s\n", ta.toChars());

            // It might really be an Expression or an Alias
            ta.resolve(loc, sc, ea, ta, sa, (flags & 1) != 0);
            if (ea)
                goto Lexpr;
            if (sa)
                goto Ldsym;
            if (ta is null)
            {
                assert(global.errors);
                ta = Type.terror;
            }

        Ltype:
            if (TypeTuple tt = ta.isTypeTuple())
            {
                // Expand tuple
                size_t dim = tt.arguments.length;
                tiargs.remove(j);
                if (dim)
                {
                    tiargs.reserve(dim);
                    foreach (i, arg; *tt.arguments)
                    {
                        if (flags & 2 && (arg.storageClass & STC.parameter))
                            tiargs.insert(j + i, arg);
                        else
                            tiargs.insert(j + i, arg.type);
                    }
                }
                j--;
                continue;
            }
            if (ta.ty == Terror)
            {
                err = true;
                continue;
            }
            (*tiargs)[j] = ta.merge2();
        }
        else if (ea)
        {
        Lexpr:
            //printf("+[%d] ea = %s %s\n", j, EXPtoString(ea.op).ptr, ea.toChars());
            if (flags & 1) // only used by __traits
            {
                ea = ea.expressionSemantic(sc);

                // must not interpret the args, excepting template parameters
                if (!ea.isVarExp() || (ea.isVarExp().var.storage_class & STC.templateparameter))
                {
                    ea = ea.optimize(WANTvalue);
                }
            }
            else
            {
                sc = sc.startCTFE();
                ea = ea.expressionSemantic(sc);
                sc = sc.endCTFE();

                if (auto varExp = ea.isVarExp())
                {
                    /* If the parameter is a function that is not called
                     * explicitly, i.e. `foo!func` as opposed to `foo!func()`,
                     * then it is a dsymbol, not the return value of `func()`
                     */
                    Declaration vd = varExp.var;
                    if (auto fd = vd.isFuncDeclaration())
                    {
                        sa = fd;
                        goto Ldsym;
                    }
                    /* Otherwise skip substituting a const var with
                     * its initializer. The problem is the initializer won't
                     * match with an 'alias' parameter. Instead, do the
                     * const substitution in TemplateValueParameter.matchArg().
                     */
                }
                else if (definitelyValueParameter(ea))
                {
                    if (ea.checkValue()) // check void expression
                        ea = ErrorExp.get();
                    uint olderrs = global.errors;
                    ea = ea.ctfeInterpret();
                    if (global.errors != olderrs)
                        ea = ErrorExp.get();
                }
            }
            //printf("-[%d] ea = %s %s\n", j, EXPtoString(ea.op).ptr, ea.toChars());
            if (TupleExp te = ea.isTupleExp())
            {
                // Expand tuple
                size_t dim = te.exps.length;
                tiargs.remove(j);
                if (dim)
                {
                    tiargs.reserve(dim);
                    foreach (i, exp; *te.exps)
                        tiargs.insert(j + i, exp);
                }
                j--;
                continue;
            }
            if (ea.op == EXP.error)
            {
                err = true;
                continue;
            }
            (*tiargs)[j] = ea;

            if (ea.op == EXP.type)
            {
                ta = ea.type;
                goto Ltype;
            }
            if (ea.op == EXP.scope_)
            {
                sa = ea.isScopeExp().sds;
                goto Ldsym;
            }
            if (FuncExp fe = ea.isFuncExp())
            {
                /* A function literal, that is passed to template and
                 * already semanticed as function pointer, never requires
                 * outer frame. So convert it to global function is valid.
                 */
                if (fe.fd.tok == TOK.reserved && fe.type.ty == Tpointer)
                {
                    // change to non-nested
                    fe.fd.tok = TOK.function_;
                    fe.fd.vthis = null;
                }
                else if (fe.td)
                {
                    /* If template argument is a template lambda,
                     * get template declaration itself. */
                    //sa = fe.td;
                    //goto Ldsym;
                }
            }
            if (ea.op == EXP.dotVariable && !(flags & 1))
            {
                // translate expression to dsymbol.
                sa = ea.isDotVarExp().var;
                goto Ldsym;
            }
            if (auto te = ea.isTemplateExp())
            {
                sa = te.td;
                goto Ldsym;
            }
            if (ea.op == EXP.dotTemplateDeclaration && !(flags & 1))
            {
                // translate expression to dsymbol.
                sa = ea.isDotTemplateExp().td;
                goto Ldsym;
            }
            if (auto de = ea.isDotExp())
            {
                if (auto se = de.e2.isScopeExp())
                {
                    sa = se.sds;
                    goto Ldsym;
                }
            }
        }
        else if (sa)
        {
        Ldsym:
            //printf("dsym %s %s\n", sa.kind(), sa.toChars());
            if (sa.errors)
            {
                err = true;
                continue;
            }

            TupleDeclaration d = sa.toAlias().isTupleDeclaration();
            if (d)
            {
                if (d is atd)
                {
                    (*tiargs)[j] = d;
                    continue;
                }
                // Expand tuple
                tiargs.remove(j);
                tiargs.insert(j, d.objects);
                j--;
                continue;
            }
            if (FuncAliasDeclaration fa = sa.isFuncAliasDeclaration())
            {
                FuncDeclaration f = fa.toAliasFunc();
                if (!fa.hasOverloads && f.isUnique())
                {
                    // Strip FuncAlias only when the aliased function
                    // does not have any overloads.
                    sa = f;
                }
            }
            (*tiargs)[j] = sa;

            TemplateDeclaration td = sa.isTemplateDeclaration();
            if (td && td.semanticRun == PASS.initial && td.literal)
            {
                td.dsymbolSemantic(sc);
            }
            FuncDeclaration fd = sa.isFuncDeclaration();
            if (fd)
                functionSemantic(fd);
        }
        else if (isParameter(o))
        {
        }
        else
        {
            assert(0);
        }
        //printf("1: (*tiargs)[%d] = %p\n", j, (*tiargs)[j]);
    }
    sc.pop();
    version (none)
    {
        printf("-TemplateInstance.semanticTiargs()\n");
        for (size_t j = 0; j < tiargs.length; j++)
        {
            RootObject o = (*tiargs)[j];
            Type ta = isType(o);
            Expression ea = isExpression(o);
            Dsymbol sa = isDsymbol(o);
            Tuple va = isTuple(o);
            printf("\ttiargs[%d] = ta %p, ea %p, sa %p, va %p\n", j, ta, ea, sa, va);
        }
    }
    return !err;
}

/**********************************
 * Run semantic on the elements of tiargs.
 * Input:
 *      sc
 * Returns:
 *      false if one or more arguments have errors.
 * Note:
 *      This function is reentrant against error occurrence. If returns false,
 *      all elements of tiargs won't be modified.
 */
extern (D) bool semanticTiargs(TemplateInstance ti,Scope* sc)
{
    //printf("+TemplateInstance.semanticTiargs() %s\n", toChars());
    if (ti.semantictiargsdone)
        return true;
    if (semanticTiargs(loc, sc, tiargs, 0))
    {
        // cache the result iff semantic analysis succeeded entirely
        semantictiargsdone = 1;
        return true;
    }
    return false;
}
