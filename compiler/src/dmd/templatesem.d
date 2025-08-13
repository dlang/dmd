/**
 * Template semantics.
 *
 * Copyright:   Copyright (C) 1999-2025 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/templatesem.d, _templatesem.d)
 * Documentation:  https://dlang.org/phobos/dmd_templatesem.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/templatesem.d
 */

module dmd.templatesem;

import core.stdc.stdio;
import core.stdc.string;
import dmd.aggregate;
import dmd.aliasthis;
import dmd.arraytypes;
import dmd.astenums;
import dmd.ast_node;
import dmd.attrib;
import dmd.dcast;
import dmd.dclass;
import dmd.declaration;
import dmd.dinterpret;
import dmd.dmodule;
import dmd.dscope;
import dmd.dsymbol;
import dmd.dsymbolsem;
import dmd.dtemplate;
import dmd.errors;
import dmd.errorsink;
import dmd.expression;
import dmd.expressionsem;
import dmd.func;
import dmd.funcsem;
import dmd.globals;
import dmd.hdrgen;
import dmd.id;
import dmd.identifier;
import dmd.impcnvtab;
import dmd.init;
import dmd.initsem;
import dmd.location;
import dmd.mtype;
import dmd.opover;
import dmd.optimize;
import dmd.root.array;
import dmd.common.outbuffer;
import dmd.rootobject;
import dmd.semantic2;
import dmd.semantic3;
import dmd.templateparamsem;
import dmd.tokens;
import dmd.typesem;
import dmd.visitor;

alias funcLeastAsSpecialized = dmd.funcsem.leastAsSpecialized;

enum LOG = false;

/************************************
 * Perform semantic analysis on template.
 * Params:
 *      sc = context
 *      tempdecl = template declaration
 */
void templateDeclarationSemantic(Scope* sc, TemplateDeclaration tempdecl)
{
    enum log = false;
    static if (log)
    {
        printf("TemplateDeclaration.dsymbolSemantic(this = %p, id = '%s')\n", this, tempdecl.ident.toChars());
        printf("sc.stc = %llx\n", sc.stc);
        printf("sc.module = %s\n", sc._module.toChars());
    }
    if (tempdecl.semanticRun != PASS.initial)
        return; // semantic() already run

    if (tempdecl._scope)
    {
        sc = tempdecl._scope;
        tempdecl._scope = null;
    }
    if (!sc)
        return;

    // Remember templates defined in module object that we need to know about
    if (sc._module && sc._module.ident == Id.object)
    {
        if (tempdecl.ident == Id.RTInfo)
            Type.rtinfo = tempdecl;
    }

    /* Remember Scope for later instantiations, but make
     * a copy since attributes can change.
     */
    if (!tempdecl._scope)
    {
        tempdecl._scope = sc.copy();
        tempdecl._scope.setNoFree();
    }

    tempdecl.semanticRun = PASS.semantic;

    tempdecl.parent = sc.parent;
    tempdecl.visibility = sc.visibility;
    tempdecl.userAttribDecl = sc.userAttribDecl;
    tempdecl.cppnamespace = sc.namespace;
    tempdecl.isstatic = tempdecl.toParent().isModule() || (tempdecl._scope.stc & STC.static_);
    tempdecl.deprecated_ = !!(sc.stc & STC.deprecated_);

    checkGNUABITag(tempdecl, sc.linkage);

    if (!tempdecl.isstatic)
    {
        if (auto ad = tempdecl.parent.pastMixin().isAggregateDeclaration())
            ad.makeNested();
    }

    // Set up scope for parameters
    auto paramsym = new ScopeDsymbol();
    paramsym.parent = tempdecl.parent;
    Scope* paramscope = sc.push(paramsym);
    paramscope.stc = STC.none;

    if (global.params.ddoc.doOutput)
    {
        tempdecl.origParameters = new TemplateParameters(tempdecl.parameters.length);
        for (size_t i = 0; i < tempdecl.parameters.length; i++)
        {
            TemplateParameter tp = (*tempdecl.parameters)[i];
            (*tempdecl.origParameters)[i] = tp.syntaxCopy();
        }
    }

    for (size_t i = 0; i < tempdecl.parameters.length; i++)
    {
        TemplateParameter tp = (*tempdecl.parameters)[i];
        if (!tp.declareParameter(paramscope))
        {
            error(tp.loc, "parameter `%s` multiply defined", tp.ident.toChars());
            tempdecl.errors = true;
        }
        if (!tp.tpsemantic(paramscope, tempdecl.parameters))
        {
            tempdecl.errors = true;
        }
        if (i + 1 != tempdecl.parameters.length && tp.isTemplateTupleParameter())
        {
            .error(tempdecl.loc, "%s `%s` template sequence parameter must be the last one", tempdecl.kind, tempdecl.toPrettyChars);
            tempdecl.errors = true;
        }
    }

    /* Calculate TemplateParameter.dependent
     */
    auto tparams = TemplateParameters(1);
    for (size_t i = 0; i < tempdecl.parameters.length; i++)
    {
        TemplateParameter tp = (*tempdecl.parameters)[i];
        tparams[0] = tp;

        for (size_t j = 0; j < tempdecl.parameters.length; j++)
        {
            // Skip cases like: X(T : T)
            if (i == j)
                continue;

            if (TemplateTypeParameter ttp = (*tempdecl.parameters)[j].isTemplateTypeParameter())
            {
                if (reliesOnTident(ttp.specType, &tparams))
                    tp.dependent = true;
            }
            else if (TemplateAliasParameter tap = (*tempdecl.parameters)[j].isTemplateAliasParameter())
            {
                if (reliesOnTident(tap.specType, &tparams) ||
                    reliesOnTident(isType(tap.specAlias), &tparams))
                {
                    tp.dependent = true;
                }
            }
        }
    }

    paramscope.pop();

    // Compute again
    tempdecl.onemember = null;
    if (tempdecl.members)
    {
        Dsymbol s;
        if (oneMembers(tempdecl.members, s, tempdecl.ident) && s)
        {
            tempdecl.onemember = s;
            s.parent = tempdecl;
        }
    }

    /* BUG: should check:
     *  1. template functions must not introduce virtual functions, as they
     *     cannot be accomodated in the vtbl[]
     *  2. templates cannot introduce non-static data members (i.e. fields)
     *     as they would change the instance size of the aggregate.
     */

    tempdecl.semanticRun = PASS.semanticdone;
}

/*******************************************
 * Match to a particular TemplateParameter.
 * Input:
 *      instLoc         location that the template is instantiated.
 *      tiargs[]        actual arguments to template instance
 *      i               i'th argument
 *      parameters[]    template parameters
 *      dedtypes[]      deduced arguments to template instance
 *      *psparam        set to symbol declared and initialized to dedtypes[i]
 */
MATCH matchArg(TemplateParameter tp, Loc instLoc, Scope* sc, Objects* tiargs, size_t i, TemplateParameters* parameters, ref Objects dedtypes, Declaration* psparam)
{
    MATCH matchArgNoMatch()
    {
        if (psparam)
            *psparam = null;
        return MATCH.nomatch;
    }

    MATCH matchArgParameter()
    {
        RootObject oarg;

        if (i < tiargs.length)
            oarg = (*tiargs)[i];
        else
        {
            // Get default argument instead
            oarg = tp.defaultArg(instLoc, sc);
            if (!oarg)
            {
                assert(i < dedtypes.length);
                // It might have already been deduced
                oarg = dedtypes[i];
                if (!oarg)
                    return matchArgNoMatch();
            }
        }
        return tp.matchArg(sc, oarg, i, parameters, dedtypes, psparam);
    }

    MATCH matchArgTuple(TemplateTupleParameter ttp)
    {
        /* The rest of the actual arguments (tiargs[]) form the match
         * for the variadic parameter.
         */
        assert(i + 1 == dedtypes.length); // must be the last one
        Tuple ovar;

        if (Tuple u = isTuple(dedtypes[i]))
        {
            // It has already been deduced
            ovar = u;
        }
        else if (i + 1 == tiargs.length && isTuple((*tiargs)[i]))
            ovar = isTuple((*tiargs)[i]);
        else
        {
            ovar = new Tuple();
            //printf("ovar = %p\n", ovar);
            if (i < tiargs.length)
            {
                //printf("i = %d, tiargs.length = %d\n", i, tiargs.length);
                ovar.objects.setDim(tiargs.length - i);
                foreach (j, ref obj; ovar.objects)
                    obj = (*tiargs)[i + j];
            }
        }
        return ttp.matchArg(sc, ovar, i, parameters, dedtypes, psparam);
    }

    if (auto ttp = tp.isTemplateTupleParameter())
        return matchArgTuple(ttp);

    return matchArgParameter();
}

MATCH matchArg(TemplateParameter tp, Scope* sc, RootObject oarg, size_t i, TemplateParameters* parameters, ref Objects dedtypes, Declaration* psparam)
{
    MATCH matchArgNoMatch()
    {
        //printf("\tm = %d\n", MATCH.nomatch);
        if (psparam)
            *psparam = null;
        return MATCH.nomatch;
    }

    MATCH matchArgType(TemplateTypeParameter ttp)
    {
        //printf("TemplateTypeParameter.matchArg('%s')\n", ttp.ident.toChars());
        MATCH m = MATCH.exact;
        Type ta = isType(oarg);
        if (!ta)
        {
            //printf("%s %p %p %p\n", oarg.toChars(), isExpression(oarg), isDsymbol(oarg), isTuple(oarg));
            return matchArgNoMatch();
        }
        //printf("ta is %s\n", ta.toChars());

        if (ttp.specType)
        {
            if (!ta || ta == TemplateTypeParameter.tdummy)
                return matchArgNoMatch();

            //printf("\tcalling deduceType(): ta is %s, specType is %s\n", ta.toChars(), ttp.specType.toChars());
            MATCH m2 = deduceType(ta, sc, ttp.specType, *parameters, dedtypes);
            if (m2 == MATCH.nomatch)
            {
                //printf("\tfailed deduceType\n");
                return matchArgNoMatch();
            }

            if (m2 < m)
                m = m2;
            if (dedtypes[i])
            {
                Type t = cast(Type)dedtypes[i];

                if (ttp.dependent && !t.equals(ta)) // https://issues.dlang.org/show_bug.cgi?id=14357
                    return matchArgNoMatch();

                /* This is a self-dependent parameter. For example:
                 *  template X(T : T*) {}
                 *  template X(T : S!T, alias S) {}
                 */
                //printf("t = %s ta = %s\n", t.toChars(), ta.toChars());
                ta = t;
            }
        }
        else
        {
            if (dedtypes[i])
            {
                // Must match already deduced type
                Type t = cast(Type)dedtypes[i];

                if (!t.equals(ta))
                {
                    //printf("t = %s ta = %s\n", t.toChars(), ta.toChars());
                    return matchArgNoMatch();
                }
            }
            else
            {
                // So that matches with specializations are better
                m = MATCH.convert;
            }
        }
        dedtypes[i] = ta;

        if (psparam)
            *psparam = new AliasDeclaration(ttp.loc, ttp.ident, ta);
        //printf("\tm = %d\n", m);
        return ttp.dependent ? MATCH.exact : m;
    }

    MATCH matchArgValue(TemplateValueParameter tvp)
    {
        //printf("TemplateValueParameter.matchArg('%s')\n", tvp.ident.toChars());
        MATCH m = MATCH.exact;

        Expression ei = isExpression(oarg);
        Type vt;

        if (!ei && oarg)
        {
            Dsymbol si = isDsymbol(oarg);
            FuncDeclaration f = si ? si.isFuncDeclaration() : null;
            if (!f || !f.fbody || f.needThis())
                return matchArgNoMatch();

            ei = new VarExp(tvp.loc, f);
            ei = ei.expressionSemantic(sc);

            /* If a function is really property-like, and then
             * it's CTFEable, ei will be a literal expression.
             */
            const olderrors = global.startGagging();
            ei = resolveProperties(sc, ei);
            ei = ei.ctfeInterpret();
            if (global.endGagging(olderrors) || ei.op == EXP.error)
                return matchArgNoMatch();

            /* https://issues.dlang.org/show_bug.cgi?id=14520
             * A property-like function can match to both
             * TemplateAlias and ValueParameter. But for template overloads,
             * it should always prefer alias parameter to be consistent
             * template match result.
             *
             *   template X(alias f) { enum X = 1; }
             *   template X(int val) { enum X = 2; }
             *   int f1() { return 0; }  // CTFEable
             *   int f2();               // body-less function is not CTFEable
             *   enum x1 = X!f1;    // should be 1
             *   enum x2 = X!f2;    // should be 1
             *
             * e.g. The x1 value must be same even if the f1 definition will be moved
             *      into di while stripping body code.
             */
            m = MATCH.convert;
        }

        if (ei && ei.op == EXP.variable)
        {
            // Resolve const variables that we had skipped earlier
            ei = ei.ctfeInterpret();
        }

        //printf("\tvalType: %s, ty = %d\n", tvp.valType.toChars(), tvp.valType.ty);
        vt = tvp.valType.typeSemantic(tvp.loc, sc);
        //printf("ei: %s, ei.type: %s\n", ei.toChars(), ei.type.toChars());
        //printf("vt = %s\n", vt.toChars());

        if (ei.type)
        {
            MATCH m2 = ei.implicitConvTo(vt);
            //printf("m: %d\n", m);
            if (m2 < m)
                m = m2;
            if (m == MATCH.nomatch)
                return matchArgNoMatch();
            ei = ei.implicitCastTo(sc, vt);
            ei = ei.ctfeInterpret();
        }

        if (tvp.specValue)
        {
            if (ei is null || (cast(void*)ei.type in TemplateValueParameter.edummies &&
                               TemplateValueParameter.edummies[cast(void*)ei.type] == ei))
                return matchArgNoMatch();

            Expression e = tvp.specValue;

            sc = sc.startCTFE();
            e = e.expressionSemantic(sc);
            e = resolveProperties(sc, e);
            sc = sc.endCTFE();
            e = e.implicitCastTo(sc, vt);
            e = e.ctfeInterpret();

            ei = ei.syntaxCopy();
            sc = sc.startCTFE();
            ei = ei.expressionSemantic(sc);
            sc = sc.endCTFE();
            ei = ei.implicitCastTo(sc, vt);
            ei = ei.ctfeInterpret();
            //printf("\tei: %s, %s\n", ei.toChars(), ei.type.toChars());
            //printf("\te : %s, %s\n", e.toChars(), e.type.toChars());
            if (!ei.equals(e))
                return matchArgNoMatch();
        }
        else
        {
            if (dedtypes[i])
            {
                // Must match already deduced value
                Expression e = cast(Expression)dedtypes[i];
                if (!ei || !ei.equals(e))
                    return matchArgNoMatch();
            }
        }
        dedtypes[i] = ei;

        if (psparam)
        {
            Initializer _init = new ExpInitializer(tvp.loc, ei);
            Declaration sparam = new VarDeclaration(tvp.loc, vt, tvp.ident, _init);
            sparam.storage_class = STC.manifest;
            *psparam = sparam;
        }
        return tvp.dependent ? MATCH.exact : m;
    }

    MATCH matchArgAlias(TemplateAliasParameter tap)
    {
        //printf("TemplateAliasParameter.matchArg('%s')\n", tap.ident.toChars());
        MATCH m = MATCH.exact;
        Type ta = isType(oarg);
        RootObject sa = ta && !ta.deco ? null : getDsymbol(oarg);
        Expression ea = isExpression(oarg);
        if (ea)
        {
            if (auto te = ea.isThisExp())
                sa = te.var;
            else if (auto se = ea.isSuperExp())
                sa = se.var;
            else if (auto se = ea.isScopeExp())
                sa = se.sds;
        }
        if (sa)
        {
            if ((cast(Dsymbol)sa).isAggregateDeclaration())
                m = MATCH.convert;

            /* specType means the alias must be a declaration with a type
             * that matches specType.
             */
            if (tap.specType)
            {
                tap.specType = typeSemantic(tap.specType, tap.loc, sc);
                Declaration d = (cast(Dsymbol)sa).isDeclaration();
                if (!d)
                    return matchArgNoMatch();
                if (!d.type.equals(tap.specType))
                    return matchArgNoMatch();
            }
        }
        else
        {
            sa = oarg;
            if (ea)
            {
                if (tap.specType)
                {
                    if (!ea.type.equals(tap.specType))
                        return matchArgNoMatch();
                }
            }
            else if (ta && ta.ty == Tinstance && !tap.specAlias)
            {
                /* Specialized parameter should be preferred
                 * match to the template type parameter.
                 *  template X(alias a) {}                      // a == this
                 *  template X(alias a : B!A, alias B, A...) {} // B!A => ta
                 */
            }
            else if (sa && sa == TemplateTypeParameter.tdummy)
            {
                /* https://issues.dlang.org/show_bug.cgi?id=2025
                 * Aggregate Types should preferentially
                 * match to the template type parameter.
                 *  template X(alias a) {}  // a == this
                 *  template X(T) {}        // T => sa
                 */
            }
            else if (ta && ta.ty != Tident)
            {
                /* Match any type that's not a TypeIdentifier to alias parameters,
                 * but prefer type parameter.
                 * template X(alias a) { }  // a == ta
                 *
                 * TypeIdentifiers are excluded because they might be not yet resolved aliases.
                 */
                m = MATCH.convert;
            }
            else
                return matchArgNoMatch();
        }

        if (tap.specAlias)
        {
            if (sa == TemplateAliasParameter.sdummy)
                return matchArgNoMatch();
            // check specialization if template arg is a symbol
            Dsymbol sx = isDsymbol(sa);
            if (sa != tap.specAlias && sx)
            {
                Type talias = isType(tap.specAlias);
                if (!talias)
                    return matchArgNoMatch();

                TemplateInstance ti = sx.isTemplateInstance();
                if (!ti && sx.parent)
                {
                    ti = sx.parent.isTemplateInstance();
                    if (ti && ti.name != sx.ident)
                        return matchArgNoMatch();
                }
                if (!ti)
                    return matchArgNoMatch();

                Type t = new TypeInstance(Loc.initial, ti);
                MATCH m2 = deduceType(t, sc, talias, *parameters, dedtypes);
                if (m2 == MATCH.nomatch)
                    return matchArgNoMatch();
            }
            // check specialization if template arg is a type
            else if (ta)
            {
                if (Type tspec = isType(tap.specAlias))
                {
                    MATCH m2 = ta.implicitConvTo(tspec);
                    if (m2 == MATCH.nomatch)
                        return matchArgNoMatch();
                }
                else
                {
                    error(tap.loc, "template parameter specialization for a type must be a type and not `%s`",
                        tap.specAlias.toChars());
                    return matchArgNoMatch();
                }
            }
        }
        else if (dedtypes[i])
        {
            // Must match already deduced symbol
            RootObject si = dedtypes[i];
            if (!sa || si != sa)
                return matchArgNoMatch();
        }
        dedtypes[i] = sa;

        if (psparam)
        {
            if (Dsymbol s = isDsymbol(sa))
            {
                *psparam = new AliasDeclaration(tap.loc, tap.ident, s);
            }
            else if (Type t = isType(sa))
            {
                *psparam = new AliasDeclaration(tap.loc, tap.ident, t);
            }
            else
            {
                assert(ea);

                // Declare manifest constant
                Initializer _init = new ExpInitializer(tap.loc, ea);
                auto v = new VarDeclaration(tap.loc, null, tap.ident, _init);
                v.storage_class = STC.manifest;
                v.dsymbolSemantic(sc);
                *psparam = v;
            }
        }
        return tap.dependent ? MATCH.exact : m;
    }

    MATCH matchArgTuple(TemplateTupleParameter ttp)
    {
        //printf("TemplateTupleParameter.matchArg('%s')\n", ttp.ident.toChars());
        Tuple ovar = isTuple(oarg);
        if (!ovar)
            return MATCH.nomatch;
        if (dedtypes[i])
        {
            Tuple tup = isTuple(dedtypes[i]);
            if (!tup)
                return MATCH.nomatch;
            if (!match(tup, ovar))
                return MATCH.nomatch;
        }
        dedtypes[i] = ovar;

        if (psparam)
            *psparam = new TupleDeclaration(ttp.loc, ttp.ident, &ovar.objects);
        return ttp.dependent ? MATCH.exact : MATCH.convert;
    }

    if (auto ttp = tp.isTemplateTypeParameter())
        return matchArgType(ttp);
    if (auto tvp = tp.isTemplateValueParameter())
        return matchArgValue(tvp);
    if (auto tap = tp.isTemplateAliasParameter())
        return matchArgAlias(tap);
    if (auto ttp = tp.isTemplateTupleParameter())
        return matchArgTuple(ttp);
    assert(0);
}


/***************************************
 * Given that ti is an instance of this TemplateDeclaration,
 * deduce the types of the parameters to this, and store
 * those deduced types in dedtypes[].
 * Params:
 *  sc = context
 *  td = template
 *  ti = instance of td
 *  dedtypes = fill in with deduced types
 *  argumentList = arguments to template instance
 *  flag = 1 - don't do semantic() because of dummy types
 *         2 - don't change types in matchArg()
 * Returns: match level.
 */
public
MATCH matchWithInstance(Scope* sc, TemplateDeclaration td, TemplateInstance ti, ref Objects dedtypes, ArgumentList argumentList, int flag)
{
    enum LOGM = 0;
    static if (LOGM)
    {
        printf("\n+TemplateDeclaration.matchWithInstance(td = %s, ti = %s, flag = %d)\n", td.toChars(), ti.toChars(), flag);
    }
    version (none)
    {
        printf("dedtypes.length = %d, parameters.length = %d\n", dedtypes.length, parameters.length);
        if (ti.tiargs.length)
            printf("ti.tiargs.length = %d, [0] = %p\n", ti.tiargs.length, (*ti.tiargs)[0]);
    }
    MATCH nomatch()
    {
        static if (LOGM)
        {
            printf(" no match\n");
        }
        return MATCH.nomatch;
    }
    MATCH m;
    size_t dedtypes_dim = dedtypes.length;

    dedtypes.zero();

    if (td.errors)
        return MATCH.nomatch;

    size_t parameters_dim = td.parameters.length;
    const bool variadic = td.isVariadic() !is null;

    // If more arguments than parameters, no match
    if (ti.tiargs.length > parameters_dim && !variadic)
    {
        static if (LOGM)
        {
            printf(" no match: more arguments than parameters\n");
        }
        return MATCH.nomatch;
    }

    assert(dedtypes_dim == parameters_dim);
    assert(dedtypes_dim >= ti.tiargs.length || variadic);

    assert(td._scope);

    // Set up scope for template parameters
    Scope* paramscope = createScopeForTemplateParameters(td, ti, sc);

    // Attempt type deduction
    m = MATCH.exact;
    for (size_t i = 0; i < dedtypes_dim; i++)
    {
        MATCH m2;
        TemplateParameter tp = (*td.parameters)[i];
        Declaration sparam;

        //printf("\targument [%d]\n", i);
        static if (LOGM)
        {
            //printf("\targument [%d] is %s\n", i, oarg ? oarg.toChars() : "null");
            TemplateTypeParameter ttp = tp.isTemplateTypeParameter();
            if (ttp)
                printf("\tparameter[%d] is %s : %s\n", i, tp.ident.toChars(), ttp.specType ? ttp.specType.toChars() : "");
        }

        m2 = tp.matchArg(ti.loc, paramscope, ti.tiargs, i, td.parameters, dedtypes, &sparam);
        //printf("\tm2 = %d\n", m2);
        if (m2 == MATCH.nomatch)
        {
            version (none)
            {
                printf("\tmatchArg() for parameter %i failed\n", i);
            }
            return nomatch();
        }

        if (m2 < m)
            m = m2;

        if (!flag)
            sparam.dsymbolSemantic(paramscope);
        if (!paramscope.insert(sparam)) // TODO: This check can make more early
        {
            // in TemplateDeclaration.semantic, and
            // then we don't need to make sparam if flags == 0
            return nomatch();
        }
    }

    if (!flag)
    {
        /* Any parameter left without a type gets the type of
         * its corresponding arg
         */
        foreach (i, ref dedtype; dedtypes)
        {
            if (!dedtype)
            {
                assert(i < ti.tiargs.length);
                dedtype = cast(Type)(*ti.tiargs)[i];
            }
        }
    }

    if (m > MATCH.nomatch && td.constraint && !flag)
    {
        if (ti.hasNestedArgs(ti.tiargs, td.isstatic)) // TODO: should gag error
            ti.parent = ti.enclosing;
        else
            ti.parent = td.parent;

        // Similar to doHeaderInstantiation
        FuncDeclaration fd = td.onemember ? td.onemember.isFuncDeclaration() : null;
        if (fd)
        {
            TypeFunction tf = fd.type.isTypeFunction().syntaxCopy();

            fd = new FuncDeclaration(fd.loc, fd.endloc, fd.ident, fd.storage_class, tf);
            fd.parent = ti;
            fd.inferRetType = true;

            // Shouldn't run semantic on default arguments and return type.
            foreach (ref param; *tf.parameterList.parameters)
                param.defaultArg = null;

            tf.next = null;
            tf.incomplete = true;

            // Resolve parameter types and 'auto ref's.
            tf.inferenceArguments = argumentList;
            const olderrors = global.startGagging();
            fd.type = tf.typeSemantic(td.loc, paramscope);
            global.endGagging(olderrors);
            if (fd.type.ty != Tfunction)
                return nomatch();
            fd.originalType = fd.type; // for mangling
        }

        // TODO: dedtypes => ti.tiargs ?
        if (!evaluateConstraint(td, ti, sc, paramscope, &dedtypes, fd))
            return nomatch();
    }

    static if (LOGM)
    {
        // Print out the results
        printf("--------------------------\n");
        printf("template %s\n", toChars());
        printf("instance %s\n", ti.toChars());
        if (m > MATCH.nomatch)
        {
            for (size_t i = 0; i < dedtypes_dim; i++)
            {
                TemplateParameter tp = (*parameters)[i];
                RootObject oarg;
                printf(" [%d]", i);
                if (i < ti.tiargs.length)
                    oarg = (*ti.tiargs)[i];
                else
                    oarg = null;
                tp.print(oarg, (*dedtypes)[i]);
            }
        }
        else
            return nomatch();
    }
    static if (LOGM)
    {
        printf(" match = %d\n", m);
    }

    paramscope.pop();
    static if (LOGM)
    {
        printf("-TemplateDeclaration.matchWithInstance(td = %s, ti = %s) = %d\n", td.toChars(), ti.toChars(), m);
    }
    return m;
}

/**
    Returns: true if the instances' innards are discardable.

    The idea of this function is to see if the template instantiation
    can be 100% replaced with its eponymous member. All other members
    can be discarded, even in the compiler to free memory (for example,
    the template could be expanded in a region allocator, deemed trivial,
    the end result copied back out independently and the entire region freed),
    and can be elided entirely from the binary.

    The current implementation affects code that generally looks like:

    ---
    template foo(args...) {
        some_basic_type_or_string helper() { .... }
        enum foo = helper();
    }
    ---

    since it was the easiest starting point of implementation but it can and
    should be expanded more later.
*/
bool isDiscardable(TemplateInstance ti)
{
    if (ti.aliasdecl is null)
        return false;

    auto v = ti.aliasdecl.isVarDeclaration();
    if (v is null)
        return false;

    if (!(v.storage_class & STC.manifest))
        return false;

    // Currently only doing basic types here because it is the easiest proof-of-concept
    // implementation with minimal risk of side effects, but it could likely be
    // expanded to any type that already exists outside this particular instance.
    if (!(v.type.equals(Type.tstring) || (v.type.isTypeBasic() !is null)))
        return false;

    // Static ctors and dtors, even in an eponymous enum template, are still run,
    // so if any of them are in here, we'd better not assume it is trivial lest
    // we break useful code
    foreach(member; *ti.members)
    {
        if(member.hasStaticCtorOrDtor())
            return false;
        if(member.isStaticDtorDeclaration())
            return false;
        if(member.isStaticCtorDeclaration())
            return false;
    }

    // but if it passes through this gauntlet... it should be fine. D code will
    // see only the eponymous member, outside stuff can never access it, even through
    // reflection; the outside world ought to be none the wiser. Even dmd should be
    // able to simply free the memory of everything except the final result.

    return true;
}


/***********************************************
 * Returns true if this is not instantiated in non-root module, and
 * is a part of non-speculative instantiatiation.
 *
 * Note: minst does not stabilize until semantic analysis is completed,
 * so don't call this function during semantic analysis to return precise result.
 */
bool needsCodegen(TemplateInstance ti)
{
    //printf("needsCodegen() %s\n", toChars());

    // minst is finalized after the 1st invocation.
    // tnext is only needed for the 1st invocation and
    // cleared for further invocations.
    TemplateInstance tnext = ti.tnext;
    TemplateInstance tinst = ti.tinst;
    ti.tnext = null;

    // Don't do codegen if the instance has errors,
    // is a dummy instance (see evaluateConstraint),
    // or is determined to be discardable.
    if (ti.errors || ti.inst is null || ti.inst.isDiscardable())
    {
        ti.minst = null; // mark as speculative
        return false;
    }

    // This should only be called on the primary instantiation.
    assert(ti is ti.inst);

    /* Hack for suppressing linking errors against template instances
    * of `_d_arrayliteralTX` (e.g. `_d_arrayliteralTX!(int[])`).
    *
    * This happens, for example, when a lib module is compiled with `preview=dip1000` and
    * the array literal is placed on stack instead of using the lowering. In this case,
    * if the root module is compiled without `preview=dip1000`, the compiler will consider
    * the template already instantiated within the lib module, and thus skip the codegen for it
    * in the root module object file, thinking that the linker will find the instance in the lib module.
    *
    * To bypass this edge case, we always do codegen for `_d_arrayliteralTX` template instances,
    * even if an instance already exists in non-root module.
    */
    if (ti.inst && ti.inst.name == Id._d_arrayliteralTX)
    {
        return true;
    }

    if (global.params.allInst)
    {
        // Do codegen if there is an instantiation from a root module, to maximize link-ability.
        static ThreeState needsCodegenAllInst(TemplateInstance tithis, TemplateInstance tinst)
        {
            // Do codegen if `this` is instantiated from a root module.
            if (tithis.minst && tithis.minst.isRoot())
                return ThreeState.yes;

            // Do codegen if the ancestor needs it.
            if (tinst && tinst.inst && tinst.inst.needsCodegen())
            {
                tithis.minst = tinst.inst.minst; // cache result
                assert(tithis.minst);
                assert(tithis.minst.isRoot());
                return ThreeState.yes;
            }
            return ThreeState.none;
        }

        if (const needsCodegen = needsCodegenAllInst(ti, tinst))
            return needsCodegen == ThreeState.yes ? true : false;

        // Do codegen if a sibling needs it.
        for (; tnext; tnext = tnext.tnext)
        {
            const needsCodegen = needsCodegenAllInst(tnext, tnext.tinst);
            if (needsCodegen == ThreeState.yes)
            {
                ti.minst = tnext.minst; // cache result
                assert(ti.minst);
                assert(ti.minst.isRoot());
                return true;
            }
            else if (!ti.minst && tnext.minst)
            {
                ti.minst = tnext.minst; // cache result from non-speculative sibling
                // continue searching
            }
            else if (needsCodegen != ThreeState.none)
                break;
        }

        // Elide codegen because there's no instantiation from any root modules.
        return false;
    }

    // Prefer instantiations from non-root modules, to minimize object code size.

    /* If a TemplateInstance is ever instantiated from a non-root module,
     * we do not have to generate code for it,
     * because it will be generated when the non-root module is compiled.
     *
     * But, if the non-root 'minst' imports any root modules, it might still need codegen.
     *
     * The problem is if A imports B, and B imports A, and both A
     * and B instantiate the same template, does the compilation of A
     * or the compilation of B do the actual instantiation?
     *
     * See https://issues.dlang.org/show_bug.cgi?id=2500.
     *
     * => Elide codegen if there is at least one instantiation from a non-root module
     *    which doesn't import any root modules.
     */
    static ThreeState needsCodegenRootOnly(TemplateInstance tithis, TemplateInstance tinst)
    {
        // If the ancestor isn't speculative,
        // 1. do codegen if the ancestor needs it
        // 2. elide codegen if the ancestor doesn't need it (non-root instantiation of ancestor incl. subtree)
        if (tinst && tinst.inst)
        {
            tinst = tinst.inst;
            const needsCodegen = tinst.needsCodegen(); // sets tinst.minst
            if (tinst.minst) // not speculative
            {
                tithis.minst = tinst.minst; // cache result
                return needsCodegen ? ThreeState.yes : ThreeState.no;
            }
        }

        // Elide codegen if `this` doesn't need it.
        if (tithis.minst && !tithis.minst.isRoot() && !tithis.minst.rootImports())
            return ThreeState.no;

        return ThreeState.none;
    }

    if (const needsCodegen = needsCodegenRootOnly(ti, tinst))
        return needsCodegen == ThreeState.yes ? true : false;

    // Elide codegen if a (non-speculative) sibling doesn't need it.
    for (; tnext; tnext = tnext.tnext)
    {
        const needsCodegen = needsCodegenRootOnly(tnext, tnext.tinst); // sets tnext.minst
        if (tnext.minst) // not speculative
        {
            if (needsCodegen == ThreeState.no)
            {
                ti.minst = tnext.minst; // cache result
                assert(!ti.minst.isRoot() && !ti.minst.rootImports());
                return false;
            }
            else if (!ti.minst)
            {
                ti.minst = tnext.minst; // cache result from non-speculative sibling
                // continue searching
            }
            else if (needsCodegen != ThreeState.none)
                break;
        }
    }

    // Unless `this` is still speculative (=> all further siblings speculative too),
    // do codegen because we found no guaranteed-codegen'd non-root instantiation.
    return ti.minst !is null;
}

/****************************
 * Check to see if constraint is satisfied.
 */
bool evaluateConstraint(TemplateDeclaration td, TemplateInstance ti, Scope* sc, Scope* paramscope, Objects* dedargs, FuncDeclaration fd)
{
    /* Detect recursive attempts to instantiate this template declaration,
     * https://issues.dlang.org/show_bug.cgi?id=4072
     *  void foo(T)(T x) if (is(typeof(foo(x)))) { }
     *  static assert(!is(typeof(foo(7))));
     * Recursive attempts are regarded as a constraint failure.
     */
    /* There's a chicken-and-egg problem here. We don't know yet if this template
     * instantiation will be a local one (enclosing is set), and we won't know until
     * after selecting the correct template. Thus, function we're nesting inside
     * is not on the sc scope chain, and this can cause errors in FuncDeclaration.getLevel().
     * Workaround the problem by setting a flag to relax the checking on frame errors.
     */

    for (TemplatePrevious* p = td.previous; p; p = p.prev)
    {
        if (!arrayObjectMatch(*p.dedargs, *dedargs))
            continue;
        //printf("recursive, no match p.sc=%p %p %s\n", p.sc, this, this.toChars());
        /* It must be a subscope of p.sc, other scope chains are not recursive
         * instantiations.
         * the chain of enclosing scopes is broken by paramscope (its enclosing
         * scope is _scope, but paramscope.callsc is the instantiating scope). So
         * it's good enough to check the chain of callsc
         */
        for (Scope* scx = paramscope.callsc; scx; scx = scx.callsc)
        {
            // The first scx might be identical for nested eponymeous templates, e.g.
            // template foo() { void foo()() {...} }
            if (scx == p.sc && scx !is paramscope.callsc)
                return false;
        }
        /* BUG: should also check for ref param differences
         */
    }

    TemplatePrevious pr;
    pr.prev = td.previous;
    pr.sc = paramscope.callsc;
    pr.dedargs = dedargs;
    td.previous = &pr; // add this to threaded list

    Scope* scx = paramscope.push(ti);
    scx.parent = ti;
    scx.tinst = null;
    scx.minst = null;
    // Set SCOPE.constraint before declaring function parameters for the static condition
    // (previously, this was immediately before calling evalStaticCondition), so the
    // semantic pass knows not to issue deprecation warnings for these throw-away decls.
    // https://issues.dlang.org/show_bug.cgi?id=21831
    scx.inTemplateConstraint = true;

    assert(!ti.symtab);
    if (fd)
    {
        /* Declare all the function parameters as variables and add them to the scope
         * Making parameters is similar to FuncDeclaration.semantic3
         */
        auto tf = fd.type.isTypeFunction();

        scx.parent = fd;

        Parameters* fparameters = tf.parameterList.parameters;
        const nfparams = tf.parameterList.length;
        foreach (i, fparam; tf.parameterList)
        {
            fparam.storageClass &= (STC.IOR | STC.lazy_ | STC.final_ | STC.TYPECTOR | STC.nodtor);
            fparam.storageClass |= STC.parameter;
            if (tf.parameterList.varargs == VarArg.typesafe && i + 1 == nfparams)
            {
                fparam.storageClass |= STC.variadic;
                /* Don't need to set STC.scope_ because this will only
                 * be evaluated at compile time
                 */
            }
        }
        foreach (fparam; *fparameters)
        {
            if (!fparam.ident)
                continue;
            // don't add it, if it has no name
            auto v = new VarDeclaration(fparam.loc, fparam.type, fparam.ident, null);
            fparam.storageClass |= STC.parameter;
            v.storage_class = fparam.storageClass;
            v.dsymbolSemantic(scx);
            if (!ti.symtab)
                ti.symtab = new DsymbolTable();
            if (!scx.insert(v))
                .error(td.loc, "%s `%s` parameter `%s.%s` is already defined", td.kind, td.toPrettyChars, td.toChars(), v.toChars());
            else
                v.parent = fd;
        }
        if (td.isstatic)
            fd.storage_class |= STC.static_;
        declareThis(fd, scx);
    }

    td.lastConstraint = td.constraint.syntaxCopy();
    td.lastConstraintTiargs = ti.tiargs;
    td.lastConstraintNegs.setDim(0);

    import dmd.staticcond;

    assert(ti.inst is null);
    ti.inst = ti; // temporary instantiation to enable genIdent()
    bool errors;
    const bool result = evalStaticCondition(scx, td.constraint, td.lastConstraint, errors, &td.lastConstraintNegs);
    if (result || errors)
    {
        td.lastConstraint = null;
        td.lastConstraintTiargs = null;
        td.lastConstraintNegs.setDim(0);
    }
    ti.inst = null;
    ti.symtab = null;
    scx = scx.pop();
    td.previous = pr.prev; // unlink from threaded list
    if (errors)
        return false;
    return result;
}

/****************************
 * Destructively get the error message from the last constraint evaluation
 * Params:
 *      td = TemplateDeclaration
 *      tip = tip to show after printing all overloads
 */
const(char)* getConstraintEvalError(TemplateDeclaration td, ref const(char)* tip)
{
    import dmd.staticcond;

    // there will be a full tree view in verbose mode, and more compact list in the usual
    const full = global.params.v.verbose;
    uint count;
    const msg = visualizeStaticCondition(td.constraint, td.lastConstraint, td.lastConstraintNegs[], full, count);
    scope (exit)
    {
        td.lastConstraint = null;
        td.lastConstraintTiargs = null;
        td.lastConstraintNegs.setDim(0);
    }
    if (!msg)
        return null;

    OutBuffer buf;

    assert(td.parameters && td.lastConstraintTiargs);
    if (td.parameters.length > 0)
    {
        formatParamsWithTiargs(*td.parameters, *td.lastConstraintTiargs, td.isVariadic() !is null, buf);
        buf.writenl();
    }
    if (!full)
    {
        // choosing singular/plural
        const s = (count == 1) ?
            "  must satisfy the following constraint:" :
            "  must satisfy one of the following constraints:";
        buf.writestring(s);
        buf.writenl();
        // the constraints
        buf.writeByte('`');
        buf.writestring(msg);
        buf.writeByte('`');
    }
    else
    {
        buf.writestring("  whose parameters have the following constraints:");
        buf.writenl();
        const sep = "  `~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`";
        buf.writestring(sep);
        buf.writenl();
        // the constraints
        buf.writeByte('`');
        buf.writestring(msg);
        buf.writeByte('`');
        buf.writestring(sep);
        tip = "not satisfied constraints are marked with `>`";
    }
    return buf.extractChars();
}

/**********************************
 * Find the TemplateDeclaration that matches this TemplateInstance best.
 *
 * Params:
 *   ti    = TemplateInstance
 *   sc    = the scope this TemplateInstance resides in
 *   argumentList = function arguments in case of a template function
 *
 * Returns:
 *   `true` if a match was found, `false` otherwise
 */
bool findBestMatch(TemplateInstance ti, Scope* sc, ArgumentList argumentList)
{
    if (ti.havetempdecl)
    {
        TemplateDeclaration tempdecl = ti.tempdecl.isTemplateDeclaration();
        assert(tempdecl);
        assert(tempdecl._scope);
        // Deduce tdtypes
        ti.tdtypes.setDim(tempdecl.parameters.length);
        if (!matchWithInstance(sc, tempdecl, ti, ti.tdtypes, argumentList, 2))
        {
            .error(ti.loc, "%s `%s` incompatible arguments for template instantiation",
                   ti.kind, ti.toPrettyChars);
            return false;
        }
        // TODO: Normalizing tiargs for https://issues.dlang.org/show_bug.cgi?id=7469 is necessary?
        return true;
    }

    static if (LOG)
    {
        printf("TemplateInstance.findBestMatch()\n");
    }

    const errs = global.errors;
    TemplateDeclaration td_last = null;
    Objects dedtypes;

    /* Since there can be multiple TemplateDeclaration's with the same
     * name, look for the best match.
     */
    auto tovers = ti.tempdecl.isOverloadSet();
    foreach (size_t oi; 0 .. tovers ? tovers.a.length : 1)
    {
        TemplateDeclaration td_best;
        TemplateDeclaration td_ambig;
        MATCH m_best = MATCH.nomatch;

        Dsymbol dstart = tovers ? tovers.a[oi] : ti.tempdecl;
        overloadApply(dstart, (Dsymbol s)
        {
            auto td = s.isTemplateDeclaration();
            if (!td)
                return 0;
            if (td == td_best)   // skip duplicates
                return 0;

            //printf("td = %s\n", td.toPrettyChars());
            // If more arguments than parameters,
            // then this is no match.
            if (td.parameters.length < ti.tiargs.length)
            {
                if (!td.isVariadic())
                    return 0;
            }

            dedtypes.setDim(td.parameters.length);
            dedtypes.zero();
            assert(td.semanticRun != PASS.initial);

            MATCH m = matchWithInstance(sc, td, ti, dedtypes, argumentList, 0);
            //printf("matchWithInstance = %d\n", m);
            if (m == MATCH.nomatch) // no match at all
                return 0;
            if (m < m_best) goto Ltd_best;
            if (m > m_best) goto Ltd;

            // Disambiguate by picking the most specialized TemplateDeclaration
            {
            MATCH c1 = leastAsSpecialized(sc, td, td_best, argumentList);
            MATCH c2 = leastAsSpecialized(sc, td_best, td, argumentList);
            //printf("c1 = %d, c2 = %d\n", c1, c2);
            if (c1 > c2) goto Ltd;
            if (c1 < c2) goto Ltd_best;
            }

            td_ambig = td;
            return 0;

        Ltd_best:
            // td_best is the best match so far
            td_ambig = null;
            return 0;

        Ltd:
            // td is the new best match
            td_ambig = null;
            td_best = td;
            m_best = m;
            ti.tdtypes.setDim(dedtypes.length);
            memcpy(ti.tdtypes.tdata(), dedtypes.tdata(), ti.tdtypes.length * (void*).sizeof);
            return 0;
        });

        if (td_ambig)
        {
            .error(ti.loc, "%s `%s.%s` matches more than one template declaration:",
                td_best.kind(), td_best.parent.toPrettyChars(), td_best.ident.toChars());
            .errorSupplemental(td_best.loc, "`%s`\nand:", td_best.toChars());
            .errorSupplemental(td_ambig.loc, "`%s`", td_ambig.toChars());
            return false;
        }
        if (td_best)
        {
            if (!td_last)
                td_last = td_best;
            else if (td_last != td_best)
            {
                ScopeDsymbol.multiplyDefined(ti.loc, td_last, td_best);
                return false;
            }
        }
    }

    if (td_last)
    {
        /* https://issues.dlang.org/show_bug.cgi?id=7469
         * Normalize tiargs by using corresponding deduced
         * template value parameters and tuples for the correct mangling.
         *
         * By doing this before hasNestedArgs, CTFEable local variable will be
         * accepted as a value parameter. For example:
         *
         *  void foo() {
         *    struct S(int n) {}   // non-global template
         *    const int num = 1;   // CTFEable local variable
         *    S!num s;             // S!1 is instantiated, not S!num
         *  }
         */
        size_t dim = td_last.parameters.length - (td_last.isVariadic() ? 1 : 0);
        for (size_t i = 0; i < dim; i++)
        {
            if (ti.tiargs.length <= i)
                ti.tiargs.push(ti.tdtypes[i]);
            assert(i < ti.tiargs.length);

            auto tvp = (*td_last.parameters)[i].isTemplateValueParameter();
            if (!tvp)
                continue;
            assert(ti.tdtypes[i]);
            // tdtypes[i] is already normalized to the required type in matchArg

            (*ti.tiargs)[i] = ti.tdtypes[i];
        }
        if (td_last.isVariadic() && ti.tiargs.length == dim && ti.tdtypes[dim])
        {
            Tuple va = isTuple(ti.tdtypes[dim]);
            assert(va);
            ti.tiargs.pushSlice(va.objects[]);
        }
    }
    else if (ti.errors && ti.inst)
    {
        // instantiation was failed with error reporting
        assert(global.errors);
        return false;
    }
    else
    {
        auto tdecl = ti.tempdecl.isTemplateDeclaration();

        if (errs != global.errors)
            errorSupplemental(ti.loc, "while looking for match for `%s`", ti.toChars());
        else if (tdecl && !tdecl.overnext)
        {
            // Only one template, so we can give better error message
            const(char)* msg = "does not match template declaration";
            const(char)* tip;
            OutBuffer buf;
            HdrGenState hgs;
            hgs.skipConstraints = true;
            toCharsMaybeConstraints(tdecl, buf, hgs);
            const tmsg = buf.peekChars();
            const cmsg = tdecl.getConstraintEvalError(tip);
            if (cmsg)
            {
                .error(ti.loc, "%s `%s` %s `%s`\n%s", ti.kind, ti.toPrettyChars, msg, tmsg, cmsg);
                if (tip)
                    .tip(tip);
            }
            else
            {
                .error(ti.loc, "%s `%s` %s `%s`", ti.kind, ti.toPrettyChars, msg, tmsg);

                if (tdecl.parameters.length == ti.tiargs.length)
                {
                    // https://issues.dlang.org/show_bug.cgi?id=7352
                    // print additional information, e.g. `foo` is not a type
                    foreach (i, param; *tdecl.parameters)
                    {
                        MATCH match = param.matchArg(ti.loc, sc, ti.tiargs, i, tdecl.parameters, dedtypes, null);
                        auto arg = (*ti.tiargs)[i];
                        auto sym = arg.isDsymbol;
                        auto exp = arg.isExpression;

                        if (exp)
                            exp = exp.optimize(WANTvalue);

                        if (match == MATCH.nomatch &&
                            ((sym && sym.isFuncDeclaration) ||
                             (exp && exp.isVarExp)))
                        {
                            if (param.isTemplateTypeParameter)
                                errorSupplemental(ti.loc, "`%s` is not a type", arg.toChars);
                            else if (auto tvp = param.isTemplateValueParameter)
                                errorSupplemental(ti.loc, "`%s` is not of a value of type `%s`",
                                                  arg.toChars, tvp.valType.toChars);

                        }
                    }
                }
            }
        }
        else
        {
            .error(ti.loc, "%s `%s` does not match any template declaration", ti.kind(), ti.toPrettyChars());
            bool found;
            overloadApply(ti.tempdecl, (s){
                if (!found)
                    errorSupplemental(ti.loc, "Candidates are:");
                found = true;
                errorSupplemental(s.loc, "%s", s.toChars());
                return 0;
            });
        }
        return false;
    }

    /* The best match is td_last
     */
    ti.tempdecl = td_last;

    static if (LOG)
    {
        printf("\tIt's a match with template declaration '%s'\n", tempdecl.toChars());
    }
    return (errs == global.errors);
}

/*******************************************
 * Append to buf a textual representation of template parameters with their arguments.
 * Params:
 *  parameters = the template parameters
 *  tiargs = the correspondeing template arguments
 *  variadic = if it's a variadic argument list
 *  buf = where the text output goes
 */
private void formatParamsWithTiargs(ref TemplateParameters parameters, ref Objects tiargs, bool variadic, ref OutBuffer buf)
{
    buf.writestring("  with `");

    // write usual arguments line-by-line
    // skips trailing default ones - they are not present in `tiargs`
    const end = parameters.length - (variadic ? 1 : 0);
    size_t i;
    for (; i < tiargs.length && i < end; i++)
    {
        if (i)
        {
            buf.writeByte(',');
            buf.writenl();
            buf.writestring("       ");
        }
        write(buf, parameters[i]);
        buf.writestring(" = ");
        write(buf, tiargs[i]);
    }
    // write remaining variadic arguments on the last line
    if (variadic)
    {
        if (i)
        {
            buf.writeByte(',');
            buf.writenl();
            buf.writestring("       ");
        }
        write(buf, parameters[end]);
        buf.writestring(" = ");
        buf.writeByte('(');
        if (end < tiargs.length)
        {
            write(buf, tiargs[end]);
            foreach (j; parameters.length .. tiargs.length)
            {
                buf.writestring(", ");
                write(buf, tiargs[j]);
            }
        }
        buf.writeByte(')');
    }
    buf.writeByte('`');
}

/******************************
 * Create a scope for the parameters of the TemplateInstance
 * `ti` in the parent scope sc from the ScopeDsymbol paramsym.
 *
 * If paramsym is null a new ScopeDsymbol is used in place of
 * paramsym.
 * Params:
 *      td = template that ti is an instance of
 *      ti = the TemplateInstance whose parameters to generate the scope for.
 *      sc = the parent scope of ti
 * Returns:
 *      new scope for the parameters of ti
 */
Scope* createScopeForTemplateParameters(TemplateDeclaration td, TemplateInstance ti, Scope* sc)
{
    ScopeDsymbol paramsym = new ScopeDsymbol();
    paramsym.parent = td._scope.parent;
    Scope* paramscope = td._scope.push(paramsym);
    paramscope.tinst = ti;
    paramscope.minst = sc.minst;
    paramscope.callsc = sc;
    paramscope.stc = STC.none;
    return paramscope;
}

/********************************************
 * Determine partial specialization order of `td` vs `td2`.
 * Params:
 *  sc = context
 *  td = first template
 *  td2 = second template
 *  argumentList = arguments to template
 * Returns:
 *      MATCH - td is at least as specialized as td2
 *      MATCH.nomatch - td2 is more specialized than td
 */
MATCH leastAsSpecialized(Scope* sc, TemplateDeclaration td, TemplateDeclaration td2, ArgumentList argumentList)
{
    enum LOG_LEASTAS = 0;
    static if (LOG_LEASTAS)
    {
        printf("%s.leastAsSpecialized(%s)\n", td.toChars(), td2.toChars());
    }

    /* This works by taking the template parameters to this template
     * declaration and feeding them to td2 as if it were a template
     * instance.
     * If it works, then this template is at least as specialized
     * as td2.
     */

    // Set type arguments to dummy template instance to be types
    // generated from the parameters to this template declaration
    auto tiargs = new Objects();
    tiargs.reserve(td.parameters.length);
    foreach (tp; *td.parameters)
    {
        if (tp.dependent)
            break;
        RootObject p = tp.dummyArg();
        if (!p) //TemplateTupleParameter
            break;

        tiargs.push(p);
    }
    scope TemplateInstance ti = new TemplateInstance(Loc.initial, td.ident, tiargs); // create dummy template instance

    // Temporary Array to hold deduced types
    Objects dedtypes = Objects(td2.parameters.length);

    // Attempt a type deduction
    MATCH m = matchWithInstance(sc, td2, ti, dedtypes, argumentList, 1);
    if (m > MATCH.nomatch)
    {
        /* A non-variadic template is more specialized than a
         * variadic one.
         */
        TemplateTupleParameter tp = td.isVariadic();
        if (tp && !tp.dependent && !td2.isVariadic())
            goto L1;

        static if (LOG_LEASTAS)
        {
            printf("  matches %d, so is least as specialized\n", m);
        }
        return m;
    }
L1:
    static if (LOG_LEASTAS)
    {
        printf("  doesn't match, so is not as specialized\n");
    }
    return MATCH.nomatch;
}

RootObject defaultArg(TemplateParameter tp, Loc instLoc, Scope* sc)
{
    if (tp.isTemplateTupleParameter())
        return null;
    if (auto tpp = tp.isTemplateTypeParameter())
    {
        Type t = tpp.defaultType;
        if (t)
        {
            t = t.syntaxCopy();
            t = t.typeSemantic(tpp.loc, sc); // use the parameter loc
        }
        return t;
    }
    if (auto tap = tp.isTemplateAliasParameter())
    {
        RootObject da = tap.defaultAlias;
        if (auto ta = isType(tap.defaultAlias))
        {
            switch (ta.ty)
            {
            // If the default arg is a template, instantiate for each type
            case Tinstance:
            // same if the default arg is a mixin, traits, typeof
            // since the content might rely on a previous parameter
            // (https://issues.dlang.org/show_bug.cgi?id=23686)
            case Tmixin, Ttypeof, Ttraits :
                da = ta.syntaxCopy();
                break;
            default:
            }
        }

        RootObject o = aliasParameterSemantic(tap.loc, sc, da, null); // use the parameter loc
        return o;
    }
    if (auto tvp = tp.isTemplateValueParameter())
    {
        Expression e = tvp.defaultValue;
        if (!e)
            return null;

        e = e.syntaxCopy();
        Scope* sc2 = sc.push();
        sc2.inDefaultArg = true;
        e = e.expressionSemantic(sc2);
        sc2.pop();
        if (e is null)
            return null;
        if (auto te = e.isTemplateExp())
        {
            assert(sc && sc.tinst);
            if (te.td == sc.tinst.tempdecl)
            {
                // defaultValue is a reference to its template declaration
                // i.e: `template T(int arg = T)`
                // Raise error now before calling resolveProperties otherwise we'll
                // start looping on the expansion of the template instance.
                auto td = sc.tinst.tempdecl;
                .error(td.loc, "%s `%s` recursive template expansion", td.kind, td.toPrettyChars);
                return ErrorExp.get();
            }
        }
        if ((e = resolveProperties(sc, e)) is null)
            return null;
        e = e.resolveLoc(instLoc, sc); // use the instantiated loc
        e = e.optimize(WANTvalue);

        return e;
    }
    assert(0);
}

/*************************************************
 * Match function arguments against a specific template function.
 *
 * Params:
 *     td = template declaration for template instance
 *     ti = template instance. `ti.tdtypes` will be set to Expression/Type deduced template arguments
 *     sc = instantiation scope
 *     fd = Partially instantiated function declaration, which is set to an instantiated function declaration
 *     tthis = 'this' argument if !NULL
 *     argumentList = arguments to function
 *
 * Returns:
 *      match pair of initial and inferred template arguments
 */
extern (D) MATCHpair deduceFunctionTemplateMatch(TemplateDeclaration td, TemplateInstance ti, Scope* sc, ref FuncDeclaration fd, Type tthis, ArgumentList argumentList)
{
    version (none)
    {
        printf("\nTemplateDeclaration.deduceFunctionTemplateMatch() %s\n", td.toChars());
        for (size_t i = 0; i < (fargs ? fargs.length : 0); i++)
        {
            Expression e = (*fargs)[i];
            printf("\tfarg[%d] is %s, type is %s\n", cast(int) i, e.toChars(), e.type.toChars());
        }
        printf("fd = %s\n", fd.toChars());
        printf("fd.type = %s\n", fd.type.toChars());
        if (tthis)
            printf("tthis = %s\n", tthis.toChars());
    }

    assert(td._scope);

    auto dedargs = new Objects(td.parameters.length);
    dedargs.zero();

    Objects* dedtypes = &ti.tdtypes; // for T:T*, the dedargs is the T*, dedtypes is the T
    dedtypes.setDim(td.parameters.length);
    dedtypes.zero();

    if (td.errors || fd.errors)
        return MATCHpair(MATCH.nomatch, MATCH.nomatch);

    // Set up scope for parameters
    Scope* paramscope = createScopeForTemplateParameters(td, ti,sc);

    MATCHpair nomatch()
    {
        paramscope.pop();
        //printf("\tnomatch\n");
        return MATCHpair(MATCH.nomatch, MATCH.nomatch);
    }

    MATCHpair matcherror()
    {
        // todo: for the future improvement
        paramscope.pop();
        //printf("\terror\n");
        return MATCHpair(MATCH.nomatch, MATCH.nomatch);
    }
    // Mark the parameter scope as deprecated if the templated
    // function is deprecated (since paramscope.enclosing is the
    // calling scope already)
    paramscope.stc |= fd.storage_class & STC.deprecated_;

    TemplateTupleParameter tp = td.isVariadic();
    Tuple declaredTuple = null;

    version (none)
    {
        for (size_t i = 0; i < dedargs.length; i++)
        {
            printf("\tdedarg[%d] = ", i);
            RootObject oarg = (*dedargs)[i];
            if (oarg)
                printf("%s", oarg.toChars());
            printf("\n");
        }
    }

    size_t ntargs = 0; // array size of tiargs
    size_t inferStart = 0; // index of first template parameter to infer from function argument
    const Loc instLoc = ti.loc;
    MATCH matchTiargs = MATCH.exact;

    if (auto tiargs = ti.tiargs)
    {
        // Set initial template arguments
        ntargs = tiargs.length;
        size_t n = td.parameters.length;
        if (tp)
            n--;
        if (ntargs > n)
        {
            if (!tp)
                return nomatch();

            /* The extra initial template arguments
             * now form the tuple argument.
             */
            auto t = new Tuple(ntargs - n);
            assert(td.parameters.length);
            (*dedargs)[td.parameters.length - 1] = t;

            for (size_t i = 0; i < t.objects.length; i++)
            {
                t.objects[i] = (*tiargs)[n + i];
            }
            td.declareParameter(paramscope, tp, t);
            declaredTuple = t;
        }
        else
            n = ntargs;

        memcpy(dedargs.tdata(), tiargs.tdata(), n * (*dedargs.tdata()).sizeof);

        for (size_t i = 0; i < n; i++)
        {
            assert(i < td.parameters.length);
            Declaration sparam = null;
            MATCH m = (*td.parameters)[i].matchArg(instLoc, paramscope, dedargs, i, td.parameters, *dedtypes, &sparam);
            //printf("\tdeduceType m = %d\n", m);
            if (m == MATCH.nomatch)
                return nomatch();
            if (m < matchTiargs)
                matchTiargs = m;

            sparam.dsymbolSemantic(paramscope);
            if (!paramscope.insert(sparam))
                return nomatch();
        }
        if (n < td.parameters.length && !declaredTuple)
        {
            inferStart = n;
        }
        else
            inferStart = td.parameters.length;
        //printf("tiargs matchTiargs = %d\n", matchTiargs);
    }
    version (none)
    {
        for (size_t i = 0; i < dedargs.length; i++)
        {
            printf("\tdedarg[%d] = ", i);
            RootObject oarg = (*dedargs)[i];
            if (oarg)
                printf("%s", oarg.toChars());
            printf("\n");
        }
    }

    ParameterList fparameters = fd.getParameterList(); // function parameter list
    const nfparams = fparameters.length; // number of function parameters

    /* Check for match of function arguments with variadic template
     * parameter, such as:
     *
     * void foo(T, A...)(T t, A a);
     * void main() { foo(1,2,3); }
     */
    size_t fptupindex = IDX_NOTFOUND;
    if (tp) // if variadic
    {
        // TemplateTupleParameter always makes most lesser matching.
        matchTiargs = MATCH.convert;

        if (nfparams == 0 && argumentList.length != 0) // if no function parameters
        {
            if (!declaredTuple)
            {
                auto t = new Tuple();
                //printf("t = %p\n", t);
                (*dedargs)[td.parameters.length - 1] = t;
                td.declareParameter(paramscope, tp, t);
                declaredTuple = t;
            }
        }
        else
        {
            /* Figure out which of the function parameters matches
             * the tuple template parameter. Do this by matching
             * type identifiers.
             * Set the index of this function parameter to fptupindex.
             */
            for (fptupindex = 0; fptupindex < nfparams; fptupindex++)
            {
                auto fparam = (*fparameters.parameters)[fptupindex]; // fparameters[fptupindex] ?
                if (fparam.type.ty != Tident)
                    continue;
                TypeIdentifier tid = fparam.type.isTypeIdentifier();
                if (!tp.ident.equals(tid.ident) || tid.idents.length)
                    continue;

                if (fparameters.varargs != VarArg.none) // variadic function doesn't
                    return nomatch(); // go with variadic template

                goto L1;
            }
            fptupindex = IDX_NOTFOUND;
        L1:
        }
    }

    MATCH match = MATCH.exact;
    if (td.toParent().isModule())
        tthis = null;
    if (tthis)
    {
        bool hasttp = false;

        // Match 'tthis' to any TemplateThisParameter's
        foreach (param; *td.parameters)
        {
            if (auto ttp = param.isTemplateThisParameter())
            {
                hasttp = true;

                Type t = new TypeIdentifier(Loc.initial, ttp.ident);
                MATCH m = deduceType(tthis, paramscope, t, *td.parameters, *dedtypes);
                if (m == MATCH.nomatch)
                    return nomatch();
                if (m < match)
                    match = m; // pick worst match
            }
        }

        // Match attributes of tthis against attributes of fd
        if (fd.type && !fd.isCtorDeclaration() && !(td._scope.stc & STC.static_))
        {
            STC stc = td._scope.stc | fd.storage_class2;
            // Propagate parent storage class, https://issues.dlang.org/show_bug.cgi?id=5504
            Dsymbol p = td.parent;
            while (p.isTemplateDeclaration() || p.isTemplateInstance())
                p = p.parent;
            AggregateDeclaration ad = p.isAggregateDeclaration();
            if (ad)
                stc |= ad.storage_class;

            ubyte mod = fd.type.mod;
            if (stc & STC.immutable_)
                mod = MODFlags.immutable_;
            else
            {
                if (stc & (STC.shared_ | STC.synchronized_))
                    mod |= MODFlags.shared_;
                if (stc & STC.const_)
                    mod |= MODFlags.const_;
                if (stc & STC.wild)
                    mod |= MODFlags.wild;
            }

            ubyte thismod = tthis.mod;
            if (hasttp)
                mod = MODmerge(thismod, mod);
            MATCH m = MODmethodConv(thismod, mod);
            if (m == MATCH.nomatch)
                return nomatch();
            if (m < match)
                match = m;
        }
    }

    // Loop through the function parameters
    {
        //printf("%s\n\tnfargs = %d, nfparams = %d, tuple_dim = %d\n", toChars(), nfargs, nfparams, declaredTuple ? declaredTuple.objects.length : 0);
        //printf("\ttp = %p, fptupindex = %d, found = %d, declaredTuple = %s\n", tp, fptupindex, fptupindex != IDX_NOTFOUND, declaredTuple ? declaredTuple.toChars() : NULL);
        enum DEFAULT_ARGI = size_t.max - 10; // pseudo index signifying the parameter is expected to be assigned its default argument
        size_t argi = 0; // current argument index
        size_t argsConsumed = 0; // to ensure no excess arguments
        size_t nfargs2 = argumentList.length; // total number of arguments including applied defaultArgs
        uint inoutMatch = 0; // for debugging only
        Expression[] fargs = argumentList.arguments ? (*argumentList.arguments)[] : null;
        ArgumentLabel[] fnames = argumentList.names ? (*argumentList.names)[] : null;

        for (size_t parami = 0; parami < nfparams; parami++)
        {
            Parameter fparam = fparameters[parami];

            // Apply function parameter storage classes to parameter types
            Type prmtype = fparam.type.addStorageClass(fparam.storageClass);

            Expression farg;
            Identifier fname = argi < fnames.length ? fnames[argi].name : null;
            bool foundName = false;
            if (fparam.ident)
            {
                foreach (i; 0 .. fnames.length)
                {
                    if (fparam.ident == fnames[i].name)
                    {
                        argi = i;
                        foundName = true;
                        break;  //Exits the loop after a match
                    }
                }
            }
            if (fname && !foundName)
            {
                argi = DEFAULT_ARGI;
            }

            /* See function parameters which wound up
             * as part of a template tuple parameter.
             */
            if (fptupindex != IDX_NOTFOUND && parami == fptupindex && argi != DEFAULT_ARGI)
            {
                TypeIdentifier tid = prmtype.isTypeIdentifier();
                assert(tid);
                if (!declaredTuple)
                {
                    /* The types of the function arguments
                     * now form the tuple argument.
                     */
                    declaredTuple = new Tuple();
                    (*dedargs)[td.parameters.length - 1] = declaredTuple;

                    /* Count function parameters with no defaults following a tuple parameter.
                     * void foo(U, T...)(int y, T, U, double, int bar = 0) {}  // rem == 2 (U, double)
                     */
                    size_t rem = 0;
                    foreach (j; parami + 1 .. nfparams)
                    {
                        Parameter p = fparameters[j];
                        if (p.defaultArg)
                        {
                            break;
                        }
                        foreach(argLabel; fnames)
                        {
                            if (p.ident == argLabel.name)
                                break;
                        }
                        if (!reliesOnTemplateParameters(p.type, (*td.parameters)[inferStart .. td.parameters.length]))
                        {
                            Type pt = p.type.syntaxCopy().typeSemantic(fd.loc, paramscope);
                            if (auto ptt = pt.isTypeTuple())
                                rem += ptt.arguments.length;
                            else
                                rem += 1;
                        }
                        else
                        {
                            ++rem;
                        }
                    }

                    if (nfargs2 - argi < rem)
                        return nomatch();
                    declaredTuple.objects.setDim(nfargs2 - argi - rem);
                    foreach (i; 0 .. declaredTuple.objects.length)
                    {
                        farg = fargs[argi + i];

                        // Check invalid arguments to detect errors early.
                        if (farg.op == EXP.error || farg.type.ty == Terror)
                            return nomatch();

                        if (!fparam.isLazy() && farg.type.ty == Tvoid)
                            return nomatch();

                        Type tt;
                        MATCH m;
                        if (ubyte wm = deduceWildHelper(farg.type, &tt, tid))
                        {
                            inoutMatch |= wm;
                            m = MATCH.constant;
                        }
                        else
                        {
                            m = deduceTypeHelper(farg.type, tt, tid);
                        }
                        if (m == MATCH.nomatch)
                            return nomatch();
                        if (m < match)
                            match = m;

                        /* Remove top const for dynamic array types and pointer types
                         */
                        if ((tt.ty == Tarray || tt.ty == Tpointer) && !tt.isMutable() && (!(fparam.storageClass & STC.ref_) || (fparam.storageClass & STC.auto_) && !farg.isLvalue()))
                        {
                            tt = tt.mutableOf();
                        }
                        declaredTuple.objects[i] = tt;
                    }
                    td.declareParameter(paramscope, tp, declaredTuple);
                }
                else
                {
                    // https://issues.dlang.org/show_bug.cgi?id=6810
                    // If declared tuple is not a type tuple,
                    // it cannot be function parameter types.
                    for (size_t i = 0; i < declaredTuple.objects.length; i++)
                    {
                        if (!isType(declaredTuple.objects[i]))
                            return nomatch();
                    }
                }
                assert(declaredTuple);
                argi += declaredTuple.objects.length;
                argsConsumed += declaredTuple.objects.length;
                continue;
            }

            // If parameter type doesn't depend on inferred template parameters,
            // semantic it to get actual type.
            if (!reliesOnTemplateParameters(prmtype, (*td.parameters)[inferStart .. td.parameters.length]))
            {
                // should copy prmtype to avoid affecting semantic result
                prmtype = prmtype.syntaxCopy().typeSemantic(fd.loc, paramscope);

                if (TypeTuple tt = prmtype.isTypeTuple())
                {
                    const tt_dim = tt.arguments.length;
                    for (size_t j = 0; j < tt_dim; j++, ++argi, ++argsConsumed)
                    {
                        Parameter p = (*tt.arguments)[j];
                        if (j == tt_dim - 1 && fparameters.varargs == VarArg.typesafe &&
                            parami + 1 == nfparams && argi < fargs.length)
                        {
                            prmtype = p.type;
                            goto Lvarargs;
                        }
                        if (argi >= fargs.length)
                        {
                            if (p.defaultArg)
                                continue;

                            // https://issues.dlang.org/show_bug.cgi?id=19888
                            if (fparam.defaultArg)
                                break;

                            return nomatch();
                        }
                        farg = fargs[argi];
                        if (!farg.implicitConvTo(p.type))
                            return nomatch();
                    }
                    continue;
                }
            }

            if (argi >= fargs.length) // if not enough arguments
            {
                if (!fparam.defaultArg)
                    goto Lvarargs;

                /* https://issues.dlang.org/show_bug.cgi?id=2803
                 * Before the starting of type deduction from the function
                 * default arguments, set the already deduced parameters into paramscope.
                 * It's necessary to avoid breaking existing acceptable code. Cases:
                 *
                 * 1. Already deduced template parameters can appear in fparam.defaultArg:
                 *  auto foo(A, B)(A a, B b = A.stringof);
                 *  foo(1);
                 *  // at fparam == 'B b = A.string', A is equivalent with the deduced type 'int'
                 *
                 * 2. If prmtype depends on default-specified template parameter, the
                 * default type should be preferred.
                 *  auto foo(N = size_t, R)(R r, N start = 0)
                 *  foo([1,2,3]);
                 *  // at fparam `N start = 0`, N should be 'size_t' before
                 *  // the deduction result from fparam.defaultArg.
                 */
                if (argi == fargs.length)
                {
                    foreach (ref dedtype; *dedtypes)
                    {
                        Type at = isType(dedtype);
                        if (at && at.ty == Tnone)
                        {
                            TypeDeduced xt = cast(TypeDeduced)at;
                            dedtype = xt.tded; // 'unbox'
                        }
                    }
                    for (size_t i = ntargs; i < dedargs.length; i++)
                    {
                        TemplateParameter tparam = (*td.parameters)[i];

                        RootObject oarg = (*dedargs)[i];
                        RootObject oded = (*dedtypes)[i];
                        if (oarg)
                            continue;

                        if (oded)
                        {
                            if (tparam.specialization() || !tparam.isTemplateTypeParameter())
                            {
                                /* The specialization can work as long as afterwards
                                 * the oded == oarg
                                 */
                                (*dedargs)[i] = oded;
                                MATCH m2 = tparam.matchArg(instLoc, paramscope, dedargs, i, td.parameters, *dedtypes, null);
                                //printf("m2 = %d\n", m2);
                                if (m2 == MATCH.nomatch)
                                    return nomatch();
                                if (m2 < matchTiargs)
                                    matchTiargs = m2; // pick worst match
                                if (!(*dedtypes)[i].equals(oded))
                                    .error(td.loc, "%s `%s` specialization not allowed for deduced parameter `%s`",
                                        td.kind, td.toPrettyChars, td.kind, td.toPrettyChars, tparam.ident.toChars());
                            }
                            else
                            {
                                if (MATCH.convert < matchTiargs)
                                    matchTiargs = MATCH.convert;
                            }
                            (*dedargs)[i] = td.declareParameter(paramscope, tparam, oded);
                        }
                        else
                        {
                            oded = tparam.defaultArg(instLoc, paramscope);
                            if (oded)
                                (*dedargs)[i] = td.declareParameter(paramscope, tparam, oded);
                        }
                    }
                }

                if (argi != DEFAULT_ARGI)
                    nfargs2 = argi + 1;

                /* If prmtype does not depend on any template parameters:
                 *
                 *  auto foo(T)(T v, double x = 0);
                 *  foo("str");
                 *  // at fparam == 'double x = 0'
                 *
                 * or, if all template parameters in the prmtype are already deduced:
                 *
                 *  auto foo(R)(R range, ElementType!R sum = 0);
                 *  foo([1,2,3]);
                 *  // at fparam == 'ElementType!R sum = 0'
                 *
                 * Deducing prmtype from fparam.defaultArg is not necessary.
                 */
                if (prmtype.deco || prmtype.syntaxCopy().trySemantic(td.loc, paramscope))
                {
                    if (argi != DEFAULT_ARGI)
                    {
                        ++argi;
                        ++argsConsumed;
                    }
                    continue;
                }

                // Deduce prmtype from the defaultArg.
                farg = fparam.defaultArg.syntaxCopy();
                farg = farg.expressionSemantic(paramscope);
                farg = resolveProperties(paramscope, farg);
            }
            else
            {
                farg = fargs[argi];
            }
            {
                assert(farg);
                // Check invalid arguments to detect errors early.
                if (farg.op == EXP.error || farg.type.ty == Terror)
                    return nomatch();

                Type att = null;
            Lretry:
                version (none)
                {
                    printf("\tfarg.type   = %s\n", farg.type.toChars());
                    printf("\tfparam.type = %s\n", prmtype.toChars());
                }
                Type argtype = farg.type;

                if (!fparam.isLazy() && argtype.ty == Tvoid && farg.op != EXP.function_)
                    return nomatch();

                // https://issues.dlang.org/show_bug.cgi?id=12876
                // Optimize argument to allow CT-known length matching
                farg = farg.optimize(WANTvalue, fparam.isReference());
                //printf("farg = %s %s\n", farg.type.toChars(), farg.toChars());

                RootObject oarg = farg;

                if (farg.isFuncExp())
                {
                    // When assigning an untyped (void) lambda `x => y` to a `(F)(ref F)` parameter,
                    // we don't want to deduce type void creating a void parameter
                }
                else if ((fparam.storageClass & STC.ref_) && (!(fparam.storageClass & STC.auto_) || farg.isLvalue()))
                {
                    /* Allow expressions that have CT-known boundaries and type [] to match with [dim]
                     */
                    bool inferIndexType = (argtype.ty == Tarray) && (prmtype.ty == Tsarray || prmtype.ty == Taarray);
                    if (auto aaType = prmtype.isTypeAArray())
                    {
                        if (auto indexType = aaType.index.isTypeIdentifier())
                        {
                            inferIndexType = indexType.idents.length == 0;
                        }
                    }
                    if (inferIndexType)
                    {
                        if (StringExp se = farg.isStringExp())
                        {
                            argtype = se.type.nextOf().sarrayOf(se.len);
                        }
                        else if (ArrayLiteralExp ae = farg.isArrayLiteralExp())
                        {
                            argtype = ae.type.nextOf().sarrayOf(ae.elements.length);
                        }
                        else if (SliceExp se = farg.isSliceExp())
                        {
                            if (Type tsa = toStaticArrayType(se))
                                argtype = tsa;
                        }
                    }

                    oarg = argtype;
                }
                else if ((fparam.storageClass & STC.out_) == 0 &&
                         (argtype.ty == Tarray || argtype.ty == Tpointer) &&
                         templateParameterLookup(prmtype, td.parameters) != IDX_NOTFOUND &&
                         prmtype.isTypeIdentifier().idents.length == 0)
                {
                    /* The farg passing to the prmtype always make a copy. Therefore,
                     * we can shrink the set of the deduced type arguments for prmtype
                     * by adjusting top-qualifier of the argtype.
                     *
                     *  prmtype         argtype     ta
                     *  T            <- const(E)[]  const(E)[]
                     *  T            <- const(E[])  const(E)[]
                     *  qualifier(T) <- const(E)[]  const(E[])
                     *  qualifier(T) <- const(E[])  const(E[])
                     */
                    Type ta = argtype.castMod(prmtype.mod ? argtype.nextOf().mod : 0);
                    if (ta != argtype)
                    {
                        Expression ea = farg.copy();
                        ea.type = ta;
                        oarg = ea;
                    }
                }

                if (fparameters.varargs == VarArg.typesafe && parami + 1 == nfparams && argi + 1 < fargs.length)
                    goto Lvarargs;

                uint im = 0;
                MATCH m = deduceType(oarg, paramscope, prmtype, *td.parameters, *dedtypes, &im, inferStart);
                //printf("\tL%d deduceType m = %d, im = x%x, inoutMatch = x%x\n", __LINE__, m, im, inoutMatch);
                inoutMatch |= im;

                /* If no match, see if the argument can be matched by using
                 * implicit conversions.
                 */
                if (m == MATCH.nomatch && prmtype.deco)
                    m = farg.implicitConvTo(prmtype);

                if (m == MATCH.nomatch)
                {
                    AggregateDeclaration ad = isAggregate(farg.type);
                    if (ad && ad.aliasthis && !isRecursiveAliasThis(att, argtype))
                    {
                        // https://issues.dlang.org/show_bug.cgi?id=12537
                        // The isRecursiveAliasThis() call above

                        /* If a semantic error occurs while doing alias this,
                         * eg purity(https://issues.dlang.org/show_bug.cgi?id=7295),
                         * just regard it as not a match.
                         *
                         * We also save/restore sc.func.flags to avoid messing up
                         * attribute inference in the evaluation.
                        */
                        const oldflags = sc.func ? sc.func.saveFlags : 0;
                        auto e = resolveAliasThis(sc, farg, true);
                        if (sc.func)
                            sc.func.restoreFlags(oldflags);
                        if (e)
                        {
                            farg = e;
                            goto Lretry;
                        }
                    }
                }

                if (m > MATCH.nomatch && (fparam.storageClass & (STC.ref_ | STC.auto_)) == STC.ref_)
                {
                    if (!farg.isLvalue())
                    {
                        if ((farg.op == EXP.string_ || farg.op == EXP.slice) && (prmtype.ty == Tsarray || prmtype.ty == Taarray))
                        {
                            // Allow conversion from T[lwr .. upr] to ref T[upr-lwr]
                        }
                        else if (sc.previews.rvalueRefParam)
                        {
                            // Allow implicit conversion to ref
                        }
                        else
                            return nomatch();
                    }
                }
                if (m > MATCH.nomatch && (fparam.storageClass & STC.out_))
                {
                    if (!farg.isLvalue())
                        return nomatch();
                    if (!farg.type.isMutable()) // https://issues.dlang.org/show_bug.cgi?id=11916
                        return nomatch();
                }
                if (m == MATCH.nomatch && fparam.isLazy() && prmtype.ty == Tvoid && farg.type.ty != Tvoid)
                    m = MATCH.convert;
                if (m != MATCH.nomatch)
                {
                    if (m < match)
                        match = m; // pick worst match
                    if (argi != DEFAULT_ARGI)
                    {
                        argi++;
                        argsConsumed++;
                    }
                    continue;
                }
            }

        Lvarargs:
            /* The following code for variadic arguments closely
             * matches TypeFunction.callMatch()
             */
            if (!(fparameters.varargs == VarArg.typesafe && parami + 1 == nfparams))
                return nomatch();

            /* Check for match with function parameter T...
             */
            Type tb = prmtype.toBasetype();
            switch (tb.ty)
            {
                // 6764 fix - TypeAArray may be TypeSArray have not yet run semantic().
            case Tsarray:
            case Taarray:
                {
                    // Perhaps we can do better with this, see TypeFunction.callMatch()
                    if (TypeSArray tsa = tb.isTypeSArray())
                    {
                        dinteger_t sz = tsa.dim.toInteger();
                        if (sz != fargs.length - argi)
                            return nomatch();
                    }
                    else if (TypeAArray taa = tb.isTypeAArray())
                    {
                        Expression dim = new IntegerExp(instLoc, fargs.length - argi, Type.tsize_t);

                        size_t i = templateParameterLookup(taa.index, td.parameters);
                        if (i == IDX_NOTFOUND)
                        {
                            Expression e;
                            Type t;
                            Dsymbol s;
                            Scope* sco;

                            const errors = global.startGagging();
                            /* ref: https://issues.dlang.org/show_bug.cgi?id=11118
                             * The parameter isn't part of the template
                             * ones, let's try to find it in the
                             * instantiation scope 'sc' and the one
                             * belonging to the template itself. */
                            sco = sc;
                            taa.index.resolve(instLoc, sco, e, t, s);
                            if (!e)
                            {
                                sco = paramscope;
                                taa.index.resolve(instLoc, sco, e, t, s);
                            }
                            global.endGagging(errors);

                            if (!e)
                                return nomatch();

                            e = e.ctfeInterpret();
                            e = e.implicitCastTo(sco, Type.tsize_t);
                            e = e.optimize(WANTvalue);
                            if (!dim.equals(e))
                                return nomatch();
                        }
                        else
                        {
                            // This code matches code in TypeInstance.deduceType()
                            TemplateParameter tprm = (*td.parameters)[i];
                            TemplateValueParameter tvp = tprm.isTemplateValueParameter();
                            if (!tvp)
                                return nomatch();
                            Expression e = cast(Expression)(*dedtypes)[i];
                            if (e)
                            {
                                if (!dim.equals(e))
                                    return nomatch();
                            }
                            else
                            {
                                Type vt = tvp.valType.typeSemantic(Loc.initial, sc);
                                MATCH m = dim.implicitConvTo(vt);
                                if (m == MATCH.nomatch)
                                    return nomatch();
                                (*dedtypes)[i] = dim;
                            }
                        }
                    }
                    goto case Tarray;
                }
            case Tarray:
                {
                    TypeArray ta = cast(TypeArray)tb;
                    Type tret = fparam.isLazyArray();
                    for (; argi < fargs.length; argi++)
                    {
                        Expression arg = fargs[argi];
                        assert(arg);

                        MATCH m;
                        /* If lazy array of delegates,
                         * convert arg(s) to delegate(s)
                         */
                        if (tret)
                        {
                            if (ta.next.equals(arg.type))
                            {
                                m = MATCH.exact;
                            }
                            else
                            {
                                m = arg.implicitConvTo(tret);
                                if (m == MATCH.nomatch)
                                {
                                    if (tret.toBasetype().ty == Tvoid)
                                        m = MATCH.convert;
                                }
                            }
                        }
                        else
                        {
                            uint wm = 0;
                            m = deduceType(arg, paramscope, ta.next, *td.parameters, *dedtypes, &wm, inferStart);
                            inoutMatch |= wm;
                        }
                        if (m == MATCH.nomatch)
                            return nomatch();
                        if (m < match)
                            match = m;
                    }
                    goto Lmatch;
                }
            case Tclass:
            case Tident:
                goto Lmatch;

            default:
                return nomatch();
            }
            assert(0);
        }
        // printf(". argi = %d, nfargs = %d, nfargs2 = %d, argsConsumed = %d\n", cast(int) argi, cast(int) nfargs, cast(int) nfargs2, cast(int) argsConsumed);
        if (argsConsumed != nfargs2 && fparameters.varargs == VarArg.none)
            return nomatch();
    }

Lmatch:
    foreach (ref dedtype; *dedtypes)
    {
        if (Type at = isType(dedtype))
        {
            if (at.ty == Tnone)
            {
                TypeDeduced xt = cast(TypeDeduced)at;
                at = xt.tded; // 'unbox'
            }
            dedtype = at.merge2();
        }
    }
    for (size_t i = ntargs; i < dedargs.length; i++)
    {
        TemplateParameter tparam = (*td.parameters)[i];
        //printf("tparam[%d] = %s\n", i, tparam.ident.toChars());

        /* For T:T*, the dedargs is the T*, dedtypes is the T
         * But for function templates, we really need them to match
         */
        RootObject oarg = (*dedargs)[i];
        RootObject oded = (*dedtypes)[i];
        //printf("1dedargs[%d] = %p, dedtypes[%d] = %p\n", i, oarg, i, oded);
        //if (oarg) printf("oarg: %s\n", oarg.toChars());
        //if (oded) printf("oded: %s\n", oded.toChars());
        if (oarg)
            continue;

        if (oded)
        {
            if (tparam.specialization() || !tparam.isTemplateTypeParameter())
            {
                /* The specialization can work as long as afterwards
                 * the oded == oarg
                 */
                (*dedargs)[i] = oded;
                MATCH m2 = tparam.matchArg(instLoc, paramscope, dedargs, i, td.parameters, *dedtypes, null);
                //printf("m2 = %d\n", m2);
                if (m2 == MATCH.nomatch)
                    return nomatch();
                if (m2 < matchTiargs)
                    matchTiargs = m2; // pick worst match
                if (!(*dedtypes)[i].equals(oded))
                    .error(td.loc, "%s `%s` specialization not allowed for deduced parameter `%s`", td.kind, td.toPrettyChars, tparam.ident.toChars());
            }
            else
            {
                // Discussion: https://issues.dlang.org/show_bug.cgi?id=16484
                if (MATCH.convert < matchTiargs)
                    matchTiargs = MATCH.convert;
            }
        }
        else
        {
            oded = tparam.defaultArg(instLoc, paramscope);
            if (!oded)
            {
                // if tuple parameter and
                // tuple parameter was not in function parameter list and
                // we're one or more arguments short (i.e. no tuple argument)
                if (tparam == tp &&
                    fptupindex == IDX_NOTFOUND &&
                    ntargs <= dedargs.length - 1)
                {
                    // make tuple argument an empty tuple
                    oded = new Tuple();
                }
                else
                    return nomatch();
            }
            if (isError(oded))
                return matcherror();
            ntargs++;

            /* At the template parameter T, the picked default template argument
             * X!int should be matched to T in order to deduce dependent
             * template parameter A.
             *  auto foo(T : X!A = X!int, A...)() { ... }
             *  foo();  // T <-- X!int, A <-- (int)
             */
            if (tparam.specialization())
            {
                (*dedargs)[i] = oded;
                MATCH m2 = tparam.matchArg(instLoc, paramscope, dedargs, i, td.parameters, *dedtypes, null);
                //printf("m2 = %d\n", m2);
                if (m2 == MATCH.nomatch)
                    return nomatch();
                if (m2 < matchTiargs)
                    matchTiargs = m2; // pick worst match
                if (!(*dedtypes)[i].equals(oded))
                    .error(td.loc, "%s `%s` specialization not allowed for deduced parameter `%s`", td.kind, td.toPrettyChars, tparam.ident.toChars());
            }
        }
        oded = td.declareParameter(paramscope, tparam, oded);
        (*dedargs)[i] = oded;
    }

    /* https://issues.dlang.org/show_bug.cgi?id=7469
     * As same as the code for 7469 in findBestMatch,
     * expand a Tuple in dedargs to normalize template arguments.
     */
    if (auto d = dedargs.length)
    {
        if (auto va = isTuple((*dedargs)[d - 1]))
        {
            dedargs.setDim(d - 1);
            dedargs.insert(d - 1, &va.objects);
        }
    }
    ti.tiargs = dedargs; // update to the normalized template arguments.

    // Partially instantiate function for constraint and fd.leastAsSpecialized()
    {
        assert(paramscope.scopesym);
        Scope* sc2 = td._scope;
        sc2 = sc2.push(paramscope.scopesym);
        sc2 = sc2.push(ti);
        sc2.parent = ti;
        sc2.tinst = ti;
        sc2.minst = sc.minst;
        sc2.stc |= fd.storage_class & STC.deprecated_;

        fd = doHeaderInstantiation(td, ti, sc2, fd, tthis, argumentList);
        sc2 = sc2.pop();
        sc2 = sc2.pop();

        if (!fd)
            return nomatch();
    }

    if (td.constraint)
    {
        if (!evaluateConstraint(td, ti, sc, paramscope, dedargs, fd))
            return nomatch();
    }

    version (none)
    {
        for (size_t i = 0; i < dedargs.length; i++)
        {
            RootObject o = (*dedargs)[i];
            printf("\tdedargs[%d] = %d, %s\n", i, o.dyncast(), o.toChars());
        }
    }

    paramscope.pop();
    //printf("\tmatch %d\n", match);
    return MATCHpair(matchTiargs, match);
}

/*************************************************
 * Limited function template instantiation for using fd.leastAsSpecialized()
 */
private
FuncDeclaration doHeaderInstantiation(TemplateDeclaration td, TemplateInstance ti, Scope* sc2, FuncDeclaration fd, Type tthis, ArgumentList inferenceArguments)
{
    assert(fd);
    version (none)
    {
        printf("doHeaderInstantiation this = %s\n", toChars());
    }

    // function body and contracts are not need
    if (fd.isCtorDeclaration())
        fd = new CtorDeclaration(fd.loc, fd.endloc, fd.storage_class, fd.type.syntaxCopy());
    else
        fd = new FuncDeclaration(fd.loc, fd.endloc, fd.ident, fd.storage_class, fd.type.syntaxCopy());
    fd.parent = ti;

    assert(fd.type.ty == Tfunction);
    auto tf = fd.type.isTypeFunction();
    tf.inferenceArguments = inferenceArguments;

    if (tthis)
    {
        // Match 'tthis' to any TemplateThisParameter's
        bool hasttp = false;
        foreach (tp; *td.parameters)
        {
            TemplateThisParameter ttp = tp.isTemplateThisParameter();
            if (ttp)
                hasttp = true;
        }
        if (hasttp)
        {
            tf = tf.addSTC(ModToStc(tthis.mod)).isTypeFunction();
            assert(!tf.deco);
        }
    }

    Scope* scx = sc2.push();

    // Shouldn't run semantic on default arguments and return type.
    foreach (ref params; *tf.parameterList.parameters)
        params.defaultArg = null;
    tf.incomplete = true;

    if (fd.isCtorDeclaration())
    {
        // For constructors, emitting return type is necessary for
        // isReturnIsolated() in functionResolve.
        tf.isCtor = true;

        Dsymbol parent = td.toParentDecl();
        Type tret;
        AggregateDeclaration ad = parent.isAggregateDeclaration();
        if (!ad || parent.isUnionDeclaration())
        {
            tret = Type.tvoid;
        }
        else
        {
            tret = ad.handleType();
            assert(tret);
            tret = tret.addStorageClass(fd.storage_class | scx.stc);
            tret = tret.addMod(tf.mod);
        }
        tf.next = tret;
        if (ad && ad.isStructDeclaration())
            tf.isRef = 1;
        //printf("tf = %s\n", tf.toChars());
    }
    else
        tf.next = null;
    fd.type = tf;
    fd.type = fd.type.addSTC(scx.stc);
    fd.type = fd.type.typeSemantic(fd.loc, scx);
    scx = scx.pop();

    if (fd.type.ty != Tfunction)
        return null;

    fd.originalType = fd.type; // for mangling
    //printf("\t[%s] fd.type = %s, mod = %x, ", loc.toChars(), fd.type.toChars(), fd.type.mod);
    //printf("fd.needThis() = %d\n", fd.needThis());

    return fd;
}

/**************************************************
 * Declare template parameter tp with value o, and install it in the scope sc.
 */
extern (D) RootObject declareParameter(TemplateDeclaration td, Scope* sc, TemplateParameter tp, RootObject o)
{
    //printf("TemplateDeclaration.declareParameter('%s', o = %p)\n", tp.ident.toChars(), o);
    Type ta = isType(o);
    Expression ea = isExpression(o);
    Dsymbol sa = isDsymbol(o);
    Tuple va = isTuple(o);

    Declaration d;
    VarDeclaration v = null;

    if (ea)
    {
        if (ea.op == EXP.type)
            ta = ea.type;
        else if (auto se = ea.isScopeExp())
            sa = se.sds;
        else if (auto te = ea.isThisExp())
            sa = te.var;
        else if (auto se = ea.isSuperExp())
            sa = se.var;
        else if (auto fe = ea.isFuncExp())
        {
            if (fe.td)
                sa = fe.td;
            else
                sa = fe.fd;
        }
    }

    if (ta)
    {
        //printf("type %s\n", ta.toChars());
        auto ad = new AliasDeclaration(Loc.initial, tp.ident, ta);
        ad.storage_class |= STC.templateparameter;
        d = ad;
    }
    else if (sa)
    {
        //printf("Alias %s %s;\n", sa.ident.toChars(), tp.ident.toChars());
        auto ad = new AliasDeclaration(Loc.initial, tp.ident, sa);
        ad.storage_class |= STC.templateparameter;
        d = ad;
    }
    else if (ea)
    {
        // tdtypes.data[i] always matches ea here
        Initializer _init = new ExpInitializer(td.loc, ea);
        TemplateValueParameter tvp = tp.isTemplateValueParameter();
        Type t = tvp ? tvp.valType : null;
        v = new VarDeclaration(td.loc, t, tp.ident, _init);
        v.storage_class = STC.manifest | STC.templateparameter;
        d = v;
    }
    else if (va)
    {
        //printf("\ttuple\n");
        d = new TupleDeclaration(td.loc, tp.ident, &va.objects);
    }
    else
    {
        assert(0);
    }
    d.storage_class |= STC.templateparameter;

    if (ta)
    {
        Type t = ta;
        // consistent with Type.checkDeprecated()
        while (t.ty != Tenum)
        {
            if (!t.nextOf())
                break;
            t = (cast(TypeNext)t).next;
        }
        if (Dsymbol s = t.toDsymbol(sc))
        {
            if (s.isDeprecated())
                d.storage_class |= STC.deprecated_;
        }
    }
    else if (sa)
    {
        if (sa.isDeprecated())
            d.storage_class |= STC.deprecated_;
    }

    if (!sc.insert(d))
        .error(td.loc, "%s `%s` declaration `%s` is already defined", td.kind, td.toPrettyChars, tp.ident.toChars());
    d.dsymbolSemantic(sc);
    /* So the caller's o gets updated with the result of semantic() being run on o
     */
    if (v)
        o = v._init.initializerToExpression();
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
bool TemplateInstance_semanticTiargs(Loc loc, Scope* sc, Objects* tiargs, int flags, TupleDeclaration atd = null)
{
    // Run semantic on each argument, place results in tiargs[]
    //printf("+TemplateInstance.semanticTiargs()\n");
    if (!tiargs)
        return true;
    bool err = false;

    // The arguments are not treated as part of a default argument,
    // because they are evaluated at compile time.
    const inCondition = sc.condition;
    sc = sc.push();
    sc.inDefaultArg = false;

    // https://issues.dlang.org/show_bug.cgi?id=24699
    sc.condition = inCondition;

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
                    const olderrs = global.errors;
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


/*************************************************
 * Given function arguments, figure out which template function
 * to expand, and return matching result.
 * Params:
 *      m           = matching result
 *      dstart      = the root of overloaded function templates
 *      loc         = instantiation location
 *      sc          = instantiation scope
 *      tiargs      = initial list of template arguments
 *      tthis       = if !NULL, the 'this' pointer argument
 *      argumentList= arguments to function
 *      errorHelper = delegate to send error message to if not null
 */
void functionResolve(ref MatchAccumulator m, Dsymbol dstart, Loc loc, Scope* sc, Objects* tiargs,
    Type tthis, ArgumentList argumentList, void delegate(const(char)*) scope errorHelper = null)
{
    version (none)
    {
        printf("functionResolve() dstart: %s (", dstart.toChars());
        for (size_t i = 0; i < (tiargs ? (*tiargs).length : 0); i++)
        {
            if (i) printf(", ");
            RootObject arg = (*tiargs)[i];
            printf("%s", arg.toChars());
        }
        printf(")(");
        for (size_t i = 0; i < (argumentList.arguments ? (*argumentList.arguments).length : 0); i++)
        {
            if (i) printf(", ");
            Expression arg = (*argumentList.arguments)[i];
            printf("%s %s", arg.type.toChars(), arg.toChars());
            //printf("\tty = %d\n", arg.type.ty);
        }
        printf(")\n");
        //printf("stc = %llx\n", dstart._scope.stc);
        //printf("match:t/f = %d/%d\n", ta_last, m.last);
    }

    // results
    int property = 0;   // 0: uninitialized
                        // 1: seen @property
                        // 2: not @property
    size_t ov_index = 0;
    TemplateDeclaration td_best;
    TemplateInstance ti_best;
    MATCH ta_last = m.last != MATCH.nomatch ? MATCH.exact : MATCH.nomatch;
    Type tthis_best;

    int applyFunction(FuncDeclaration fd)
    {
        // skip duplicates
        if (fd == m.lastf)
            return 0;
        // explicitly specified tiargs never match to non template function
        if (tiargs && tiargs.length > 0)
            return 0;

        // constructors need a valid scope in order to detect semantic errors
        if (!fd.isCtorDeclaration &&
            fd.semanticRun < PASS.semanticdone)
        {
            fd.ungagSpeculative();
            fd.dsymbolSemantic(null);
        }
        if (fd.semanticRun < PASS.semanticdone)
        {
            .error(loc, "forward reference to template `%s`", fd.toChars());
            return 1;
        }
        //printf("fd = %s %s, fargs = %s\n", fd.toChars(), fd.type.toChars(), fargs.toChars());
        auto tf = fd.type.isTypeFunction();

        int prop = tf.isProperty ? 1 : 2;
        if (property == 0)
            property = prop;
        else if (property != prop)
            error(fd.loc, "cannot overload both property and non-property functions");

        /* For constructors, qualifier check will be opposite direction.
         * Qualified constructor always makes qualified object, then will be checked
         * that it is implicitly convertible to tthis.
         */
        Type tthis_fd = fd.needThis() ? tthis : null;
        bool isCtorCall = tthis_fd && fd.isCtorDeclaration();
        if (isCtorCall)
        {
            //printf("%s tf.mod = x%x tthis_fd.mod = x%x %d\n", tf.toChars(),
            //        tf.mod, tthis_fd.mod, fd.isReturnIsolated());
            if (MODimplicitConv(tf.mod, tthis_fd.mod) ||
                tf.isWild() && tf.isShared() == tthis_fd.isShared() ||
                fd.isReturnIsolated())
            {
                /* && tf.isShared() == tthis_fd.isShared()*/
                // Uniquely constructed object can ignore shared qualifier.
                // TODO: Is this appropriate?
                tthis_fd = null;
            }
            else
                return 0;   // MATCH.nomatch
        }
        /* Fix Issue 17970:
           If a struct is declared as shared the dtor is automatically
           considered to be shared, but when the struct is instantiated
           the instance is no longer considered to be shared when the
           function call matching is done. The fix makes it so that if a
           struct declaration is shared, when the destructor is called,
           the instantiated struct is also considered shared.
        */
        if (auto dt = fd.isDtorDeclaration())
        {
            auto dtmod = dt.type.toTypeFunction();
            auto shared_dtor = dtmod.mod & MODFlags.shared_;
            auto shared_this = tthis_fd !is null ?
                tthis_fd.mod & MODFlags.shared_ : 0;
            if (shared_dtor && !shared_this)
                tthis_fd = dtmod;
            else if (shared_this && !shared_dtor && tthis_fd !is null)
                tf.mod = tthis_fd.mod;
        }
        const(char)* failMessage;
        MATCH mfa = callMatch(fd, tf, tthis_fd, argumentList, 0, errorHelper, sc);
        //printf("test1: mfa = %d\n", mfa);
        if (failMessage)
            errorHelper(failMessage);
        if (mfa == MATCH.nomatch)
            return 0;

        int firstIsBetter()
        {
            td_best = null;
            ti_best = null;
            ta_last = MATCH.exact;
            m.last = mfa;
            m.lastf = fd;
            tthis_best = tthis_fd;
            ov_index = 0;
            m.count = 1;
            return 0;
        }

        if (mfa > m.last) return firstIsBetter();
        if (mfa < m.last) return 0;

        /* See if one of the matches overrides the other.
         */
        assert(m.lastf);
        if (m.lastf.overrides(fd)) return 0;
        if (fd.overrides(m.lastf)) return firstIsBetter();

        /* Try to disambiguate using template-style partial ordering rules.
         * In essence, if f() and g() are ambiguous, if f() can call g(),
         * but g() cannot call f(), then pick f().
         * This is because f() is "more specialized."
         */
        {
            MATCH c1 = funcLeastAsSpecialized(fd, m.lastf, argumentList.names);
            MATCH c2 = funcLeastAsSpecialized(m.lastf, fd, argumentList.names);
            //printf("c1 = %d, c2 = %d\n", c1, c2);
            if (c1 > c2) return firstIsBetter();
            if (c1 < c2) return 0;
        }

        /* The 'overrides' check above does covariant checking only
         * for virtual member functions. It should do it for all functions,
         * but in order to not risk breaking code we put it after
         * the 'leastAsSpecialized' check.
         * In the future try moving it before.
         * I.e. a not-the-same-but-covariant match is preferred,
         * as it is more restrictive.
         */
        if (!m.lastf.type.equals(fd.type))
        {
            //printf("cov: %d %d\n", m.lastf.type.covariant(fd.type), fd.type.covariant(m.lastf.type));
            const lastCovariant = m.lastf.type.covariant(fd.type);
            const firstCovariant = fd.type.covariant(m.lastf.type);

            if (lastCovariant == Covariant.yes || lastCovariant == Covariant.no)
            {
                if (firstCovariant != Covariant.yes && firstCovariant != Covariant.no)
                {
                    return 0;
                }
            }
            else if (firstCovariant == Covariant.yes || firstCovariant == Covariant.no)
            {
                return firstIsBetter();
            }
        }

        /* If the two functions are the same function, like:
         *    int foo(int);
         *    int foo(int x) { ... }
         * then pick the one with the body.
         *
         * If none has a body then don't care because the same
         * real function would be linked to the decl (e.g from object file)
         */
        if (tf.equals(m.lastf.type) &&
            fd.storage_class == m.lastf.storage_class &&
            fd.parent == m.lastf.parent &&
            fd.visibility == m.lastf.visibility &&
            fd._linkage == m.lastf._linkage)
        {
            if (fd.fbody && !m.lastf.fbody)
                return firstIsBetter();
            if (!fd.fbody)
                return 0;
        }

        // https://issues.dlang.org/show_bug.cgi?id=14450
        // Prefer exact qualified constructor for the creating object type
        if (isCtorCall && tf.mod != m.lastf.type.mod)
        {
            if (tthis.mod == tf.mod) return firstIsBetter();
            if (tthis.mod == m.lastf.type.mod) return 0;
        }

        m.nextf = fd;
        m.count++;
        return 0;
    }

    int applyTemplate(TemplateDeclaration td)
    {
        //printf("applyTemplate(): td = %s\n", td.toChars());
        if (td == td_best)   // skip duplicates
            return 0;

        if (!sc)
            sc = td._scope; // workaround for Type.aliasthisOf

        if (td.semanticRun == PASS.initial && td._scope)
        {
            // Try to fix forward reference. Ungag errors while doing so.
            td.ungagSpeculative();
            td.dsymbolSemantic(td._scope);
        }
        if (td.semanticRun == PASS.initial)
        {
            .error(loc, "forward reference to template `%s`", td.toChars());
        Lerror:
            m.lastf = null;
            m.count = 0;
            m.last = MATCH.nomatch;
            return 1;
        }
        //printf("td = %s\n", td.toChars());

        auto f = td.onemember ? td.onemember.isFuncDeclaration() : null;
        if (!f)
        {
            if (!tiargs)
                tiargs = new Objects();
            auto ti = new TemplateInstance(loc, td, tiargs);
            Objects dedtypes = Objects(td.parameters.length);
            assert(td.semanticRun != PASS.initial);
            MATCH mta = matchWithInstance(sc, td, ti, dedtypes, argumentList, 0);
            //printf("matchWithInstance = %d\n", mta);
            if (mta == MATCH.nomatch || mta < ta_last)   // no match or less match
                return 0;

            ti.templateInstanceSemantic(sc, argumentList);
            if (!ti.inst)               // if template failed to expand
                return 0;

            Dsymbol s = ti.inst.toAlias();
            FuncDeclaration fd;
            if (auto tdx = s.isTemplateDeclaration())
            {
                Objects dedtypesX;      // empty tiargs

                // https://issues.dlang.org/show_bug.cgi?id=11553
                // Check for recursive instantiation of tdx.
                for (TemplatePrevious* p = tdx.previous; p; p = p.prev)
                {
                    if (arrayObjectMatch(*p.dedargs, dedtypesX))
                    {
                        //printf("recursive, no match p.sc=%p %p %s\n", p.sc, this, this.toChars());
                        /* It must be a subscope of p.sc, other scope chains are not recursive
                         * instantiations.
                         */
                        for (Scope* scx = sc; scx; scx = scx.enclosing)
                        {
                            if (scx == p.sc)
                            {
                                error(loc, "recursive template expansion while looking for `%s.%s`", ti.toChars(), tdx.toChars());
                                goto Lerror;
                            }
                        }
                    }
                    /* BUG: should also check for ref param differences
                     */
                }

                TemplatePrevious pr;
                pr.prev = tdx.previous;
                pr.sc = sc;
                pr.dedargs = &dedtypesX;
                tdx.previous = &pr;             // add this to threaded list

                fd = resolveFuncCall(loc, sc, s, null, tthis, argumentList, FuncResolveFlag.quiet);

                tdx.previous = pr.prev;         // unlink from threaded list
            }
            else if (s.isFuncDeclaration())
            {
                fd = resolveFuncCall(loc, sc, s, null, tthis, argumentList, FuncResolveFlag.quiet);
            }
            else
                goto Lerror;

            if (!fd)
                return 0;

            if (fd.type.ty != Tfunction)
            {
                m.lastf = fd;   // to propagate "error match"
                m.count = 1;
                m.last = MATCH.nomatch;
                return 1;
            }

            Type tthis_fd = fd.needThis() && !fd.isCtorDeclaration() ? tthis : null;

            auto tf = fd.type.isTypeFunction();
            MATCH mfa = callMatch(fd, tf, tthis_fd, argumentList, 0, null, sc);
            if (mfa < m.last)
                return 0;

            if (mta < ta_last) goto Ltd_best2;
            if (mta > ta_last) goto Ltd2;

            if (mfa < m.last) goto Ltd_best2;
            if (mfa > m.last) goto Ltd2;

            // td_best and td are ambiguous
            //printf("Lambig2\n");
            m.nextf = fd;
            m.count++;
            return 0;

        Ltd_best2:
            return 0;

        Ltd2:
            // td is the new best match
            assert(td._scope);
            td_best = td;
            ti_best = null;
            property = 0;   // (backward compatibility)
            ta_last = mta;
            m.last = mfa;
            m.lastf = fd;
            tthis_best = tthis_fd;
            ov_index = 0;
            m.nextf = null;
            m.count = 1;
            return 0;
        }

        //printf("td = %s\n", td.toChars());
        for (size_t ovi = 0; f; f = f.overnext0, ovi++)
        {
            if (f.type.ty != Tfunction || f.errors)
                goto Lerror;

            /* This is a 'dummy' instance to evaluate constraint properly.
             */
            auto ti = new TemplateInstance(loc, td, tiargs);
            ti.parent = td.parent;  // Maybe calculating valid 'enclosing' is unnecessary.

            auto fd = f;
            MATCHpair x = td.deduceFunctionTemplateMatch(ti, sc, fd, tthis, argumentList);
            MATCH mta = x.mta;
            MATCH mfa = x.mfa;
            //printf("match:t/f = %d/%d\n", mta, mfa);
            if (!fd || mfa == MATCH.nomatch)
                continue;

            Type tthis_fd = fd.needThis() ? tthis : null;

            bool isCtorCall = tthis_fd && fd.isCtorDeclaration();
            if (isCtorCall)
            {
                // Constructor call requires additional check.
                auto tf = fd.type.isTypeFunction();
                assert(tf.next);
                if (MODimplicitConv(tf.mod, tthis_fd.mod) ||
                    tf.isWild() && tf.isShared() == tthis_fd.isShared() ||
                    fd.isReturnIsolated())
                {
                    tthis_fd = null;
                }
                else
                    continue;   // MATCH.nomatch

                // need to check here whether the constructor is the member of a struct
                // declaration that defines a copy constructor. This is already checked
                // in the semantic of CtorDeclaration, however, when matching functions,
                // the template instance is not expanded.
                // https://issues.dlang.org/show_bug.cgi?id=21613
                auto ad = fd.isThis();
                auto sd = ad.isStructDeclaration();
                if (checkHasBothRvalueAndCpCtor(sd, fd.isCtorDeclaration(), ti))
                    continue;
            }

            if (mta < ta_last) goto Ltd_best;
            if (mta > ta_last) goto Ltd;

            if (mfa < m.last) goto Ltd_best;
            if (mfa > m.last) goto Ltd;

            if (td_best)
            {
                // Disambiguate by picking the most specialized TemplateDeclaration
                MATCH c1 = leastAsSpecialized(sc, td, td_best, argumentList);
                MATCH c2 = leastAsSpecialized(sc, td_best, td, argumentList);
                //printf("1: c1 = %d, c2 = %d\n", c1, c2);
                if (c1 > c2) goto Ltd;
                if (c1 < c2) goto Ltd_best;
            }
            assert(fd && m.lastf);
            {
                // Disambiguate by tf.callMatch
                auto tf1 = fd.type.isTypeFunction();
                auto tf2 = m.lastf.type.isTypeFunction();
                MATCH c1 = callMatch(fd,      tf1, tthis_fd,   argumentList, 0, null, sc);
                MATCH c2 = callMatch(m.lastf, tf2, tthis_best, argumentList, 0, null, sc);
                //printf("2: c1 = %d, c2 = %d\n", c1, c2);
                if (c1 > c2) goto Ltd;
                if (c1 < c2) goto Ltd_best;
            }
            {
                // Disambiguate by picking the most specialized FunctionDeclaration
                MATCH c1 = funcLeastAsSpecialized(fd, m.lastf, argumentList.names);
                MATCH c2 = funcLeastAsSpecialized(m.lastf, fd, argumentList.names);
                //printf("3: c1 = %d, c2 = %d\n", c1, c2);
                if (c1 > c2) goto Ltd;
                if (c1 < c2) goto Ltd_best;
            }

            // https://issues.dlang.org/show_bug.cgi?id=14450
            // Prefer exact qualified constructor for the creating object type
            if (isCtorCall && fd.type.mod != m.lastf.type.mod)
            {
                if (tthis.mod == fd.type.mod) goto Ltd;
                if (tthis.mod == m.lastf.type.mod) goto Ltd_best;
            }

            m.nextf = fd;
            m.count++;
            continue;

        Ltd_best:           // td_best is the best match so far
            //printf("Ltd_best\n");
            continue;

        Ltd:                // td is the new best match
            //printf("Ltd\n");
            assert(td._scope);
            td_best = td;
            ti_best = ti;
            property = 0;   // (backward compatibility)
            ta_last = mta;
            m.last = mfa;
            m.lastf = fd;
            tthis_best = tthis_fd;
            ov_index = ovi;
            m.nextf = null;
            m.count = 1;
            continue;
        }
        return 0;
    }

    auto td = dstart.isTemplateDeclaration();
    if (td && td.funcroot)
        dstart = td.funcroot;
    overloadApply(dstart, (Dsymbol s)
    {
        if (s.errors)
            return 0;
        if (auto fd = s.isFuncDeclaration())
            return applyFunction(fd);
        if (auto td = s.isTemplateDeclaration())
            return applyTemplate(td);
        return 0;
    }, sc);

    //printf("td_best = %p, m.lastf = %p\n", td_best, m.lastf);
    if (td_best && ti_best && m.count == 1)
    {
        // Matches to template function
        assert(td_best.onemember && td_best.onemember.isFuncDeclaration());
        /* The best match is td_best with arguments tdargs.
         * Now instantiate the template.
         */
        assert(td_best._scope);
        if (!sc)
            sc = td_best._scope; // workaround for Type.aliasthisOf

        auto ti = new TemplateInstance(loc, td_best, ti_best.tiargs);
        ti.templateInstanceSemantic(sc, argumentList);

        m.lastf = ti.toAlias().isFuncDeclaration();
        if (!m.lastf)
            goto Lnomatch;
        if (ti.errors)
        {
        Lerror:
            m.count = 1;
            assert(m.lastf);
            m.last = MATCH.nomatch;
            return;
        }

        // look forward instantiated overload function
        // Dsymbol.oneMembers is alredy called in TemplateInstance.semantic.
        // it has filled overnext0d
        while (ov_index--)
        {
            m.lastf = m.lastf.overnext0;
            assert(m.lastf);
        }

        tthis_best = m.lastf.needThis() && !m.lastf.isCtorDeclaration() ? tthis : null;

        if (m.lastf.type.ty == Terror)
            goto Lerror;
        auto tf = m.lastf.type.isTypeFunction();
        if (callMatch(m.lastf, tf, tthis_best, argumentList, 0, null, sc) == MATCH.nomatch)
            goto Lnomatch;

        /* As https://issues.dlang.org/show_bug.cgi?id=3682 shows,
         * a template instance can be matched while instantiating
         * that same template. Thus, the function type can be incomplete. Complete it.
         *
         * https://issues.dlang.org/show_bug.cgi?id=9208
         * For auto function, completion should be deferred to the end of
         * its semantic3. Should not complete it in here.
         */
        if (tf.next && !m.lastf.inferRetType)
        {
            m.lastf.type = tf.typeSemantic(loc, sc);
        }
    }
    else if (m.lastf)
    {
        // Matches to non template function,
        // or found matches were ambiguous.
        assert(m.count >= 1);
    }
    else
    {
    Lnomatch:
        m.count = 0;
        m.lastf = null;
        m.last = MATCH.nomatch;
    }
}
/* Create dummy argument based on parameter.
 */
private RootObject dummyArg(TemplateParameter tp)
{
    scope v = new DummyArgVisitor();
    tp.accept(v);
    return v.result;
}
private extern(C++) class DummyArgVisitor : Visitor
{
    RootObject result;

    alias visit = typeof(super).visit;
    override void visit(TemplateTypeParameter ttp)
    {
        Type t = ttp.specType;
        if (t)
        {
            result = t;
            return;
        }
        // Use this for alias-parameter's too (?)
        if (!ttp.tdummy)
            ttp.tdummy = new TypeIdentifier(ttp.loc, ttp.ident);
        result = ttp.tdummy;
    }

    override void visit(TemplateValueParameter tvp)
    {
        Expression e = tvp.specValue;
        if (e)
        {
            result = e;
            return;
        }

        // Create a dummy value
        auto pe = cast(void*)tvp.valType in tvp.edummies;
        if (pe)
        {
            result = *pe;
            return;
        }

        e = tvp.valType.defaultInit(Loc.initial);
        tvp.edummies[cast(void*)tvp.valType] = e;
        result = e;
    }

    override void visit(TemplateAliasParameter tap)
    {
        RootObject s = tap.specAlias;
        if (s)
        {
            result = s;
            return;
        }
        if (!tap.sdummy)
            tap.sdummy = new Dsymbol(DSYM.dsymbol);
        result = tap.sdummy;
    }

    override void visit(TemplateTupleParameter tap)
    {
        result = null;
    }
}

/**
 * Returns the common type of the 2 types.
 */
private Type rawTypeMerge(Type t1, Type t2)
{
    if (t1.equals(t2))
        return t1;
    if (t1.equivalent(t2))
        return t1.castMod(MODmerge(t1.mod, t2.mod));

    auto t1b = t1.toBasetype();
    auto t2b = t2.toBasetype();
    if (t1b.equals(t2b))
        return t1b;
    if (t1b.equivalent(t2b))
        return t1b.castMod(MODmerge(t1b.mod, t2b.mod));

    auto ty = implicitConvCommonTy(t1b.ty, t2b.ty);
    if (ty != Terror)
        return Type.basic[ty];

    return null;
}

private auto X(T, U)(T m, U n)
{
    return (m << 4) | n;
}

private ubyte deduceWildHelper(Type t, Type* at, Type tparam)
{
    if ((tparam.mod & MODFlags.wild) == 0)
        return 0;

    *at = null;

    switch (X(tparam.mod, t.mod))
    {
    case X(MODFlags.wild, 0):
    case X(MODFlags.wild, MODFlags.const_):
    case X(MODFlags.wild, MODFlags.shared_):
    case X(MODFlags.wild, MODFlags.shared_ | MODFlags.const_):
    case X(MODFlags.wild, MODFlags.immutable_):
    case X(MODFlags.wildconst, 0):
    case X(MODFlags.wildconst, MODFlags.const_):
    case X(MODFlags.wildconst, MODFlags.shared_):
    case X(MODFlags.wildconst, MODFlags.shared_ | MODFlags.const_):
    case X(MODFlags.wildconst, MODFlags.immutable_):
    case X(MODFlags.shared_ | MODFlags.wild, MODFlags.shared_):
    case X(MODFlags.shared_ | MODFlags.wild, MODFlags.shared_ | MODFlags.const_):
    case X(MODFlags.shared_ | MODFlags.wild, MODFlags.immutable_):
    case X(MODFlags.shared_ | MODFlags.wildconst, MODFlags.shared_):
    case X(MODFlags.shared_ | MODFlags.wildconst, MODFlags.shared_ | MODFlags.const_):
    case X(MODFlags.shared_ | MODFlags.wildconst, MODFlags.immutable_):
        {
            ubyte wm = (t.mod & ~MODFlags.shared_);
            if (wm == 0)
                wm = MODFlags.mutable;
            ubyte m = (t.mod & (MODFlags.const_ | MODFlags.immutable_)) | (tparam.mod & t.mod & MODFlags.shared_);
            *at = t.unqualify(m);
            return wm;
        }
    case X(MODFlags.wild, MODFlags.wild):
    case X(MODFlags.wild, MODFlags.wildconst):
    case X(MODFlags.wild, MODFlags.shared_ | MODFlags.wild):
    case X(MODFlags.wild, MODFlags.shared_ | MODFlags.wildconst):
    case X(MODFlags.wildconst, MODFlags.wild):
    case X(MODFlags.wildconst, MODFlags.wildconst):
    case X(MODFlags.wildconst, MODFlags.shared_ | MODFlags.wild):
    case X(MODFlags.wildconst, MODFlags.shared_ | MODFlags.wildconst):
    case X(MODFlags.shared_ | MODFlags.wild, MODFlags.shared_ | MODFlags.wild):
    case X(MODFlags.shared_ | MODFlags.wild, MODFlags.shared_ | MODFlags.wildconst):
    case X(MODFlags.shared_ | MODFlags.wildconst, MODFlags.shared_ | MODFlags.wild):
    case X(MODFlags.shared_ | MODFlags.wildconst, MODFlags.shared_ | MODFlags.wildconst):
        {
            *at = t.unqualify(tparam.mod & t.mod);
            return MODFlags.wild;
        }
    default:
        return 0;
    }
}

private MATCH deduceTypeHelper(Type t, out Type at, Type tparam)
{
    // 9*9 == 81 cases
    switch (X(tparam.mod, t.mod))
    {
    case X(0, 0):
    case X(0, MODFlags.const_):
    case X(0, MODFlags.wild):
    case X(0, MODFlags.wildconst):
    case X(0, MODFlags.shared_):
    case X(0, MODFlags.shared_ | MODFlags.const_):
    case X(0, MODFlags.shared_ | MODFlags.wild):
    case X(0, MODFlags.shared_ | MODFlags.wildconst):
    case X(0, MODFlags.immutable_):
        // foo(U)                       T                       => T
        // foo(U)                       const(T)                => const(T)
        // foo(U)                       inout(T)                => inout(T)
        // foo(U)                       inout(const(T))         => inout(const(T))
        // foo(U)                       shared(T)               => shared(T)
        // foo(U)                       shared(const(T))        => shared(const(T))
        // foo(U)                       shared(inout(T))        => shared(inout(T))
        // foo(U)                       shared(inout(const(T))) => shared(inout(const(T)))
        // foo(U)                       immutable(T)            => immutable(T)
        {
            at = t;
            return MATCH.exact;
        }
    case X(MODFlags.const_, MODFlags.const_):
    case X(MODFlags.wild, MODFlags.wild):
    case X(MODFlags.wildconst, MODFlags.wildconst):
    case X(MODFlags.shared_, MODFlags.shared_):
    case X(MODFlags.shared_ | MODFlags.const_, MODFlags.shared_ | MODFlags.const_):
    case X(MODFlags.shared_ | MODFlags.wild, MODFlags.shared_ | MODFlags.wild):
    case X(MODFlags.shared_ | MODFlags.wildconst, MODFlags.shared_ | MODFlags.wildconst):
    case X(MODFlags.immutable_, MODFlags.immutable_):
        // foo(const(U))                const(T)                => T
        // foo(inout(U))                inout(T)                => T
        // foo(inout(const(U)))         inout(const(T))         => T
        // foo(shared(U))               shared(T)               => T
        // foo(shared(const(U)))        shared(const(T))        => T
        // foo(shared(inout(U)))        shared(inout(T))        => T
        // foo(shared(inout(const(U)))) shared(inout(const(T))) => T
        // foo(immutable(U))            immutable(T)            => T
        {
            at = t.mutableOf().unSharedOf();
            return MATCH.exact;
        }
    case X(MODFlags.const_, MODFlags.shared_ | MODFlags.const_):
    case X(MODFlags.wild, MODFlags.shared_ | MODFlags.wild):
    case X(MODFlags.wildconst, MODFlags.shared_ | MODFlags.wildconst):
        // foo(const(U))                shared(const(T))        => shared(T)
        // foo(inout(U))                shared(inout(T))        => shared(T)
        // foo(inout(const(U)))         shared(inout(const(T))) => shared(T)
        {
            at = t.mutableOf();
            return MATCH.exact;
        }
    case X(MODFlags.const_, 0):
    case X(MODFlags.const_, MODFlags.wild):
    case X(MODFlags.const_, MODFlags.wildconst):
    case X(MODFlags.const_, MODFlags.shared_ | MODFlags.wild):
    case X(MODFlags.const_, MODFlags.shared_ | MODFlags.wildconst):
    case X(MODFlags.const_, MODFlags.immutable_):
    case X(MODFlags.shared_ | MODFlags.const_, MODFlags.immutable_):
        // foo(const(U))                T                       => T
        // foo(const(U))                inout(T)                => T
        // foo(const(U))                inout(const(T))         => T
        // foo(const(U))                shared(inout(T))        => shared(T)
        // foo(const(U))                shared(inout(const(T))) => shared(T)
        // foo(const(U))                immutable(T)            => T
        // foo(shared(const(U)))        immutable(T)            => T
        {
            at = t.mutableOf();
            return MATCH.constant;
        }
    case X(MODFlags.const_, MODFlags.shared_):
        // foo(const(U))                shared(T)               => shared(T)
        {
            at = t;
            return MATCH.constant;
        }
    case X(MODFlags.shared_, MODFlags.shared_ | MODFlags.const_):
    case X(MODFlags.shared_, MODFlags.shared_ | MODFlags.wild):
    case X(MODFlags.shared_, MODFlags.shared_ | MODFlags.wildconst):
        // foo(shared(U))               shared(const(T))        => const(T)
        // foo(shared(U))               shared(inout(T))        => inout(T)
        // foo(shared(U))               shared(inout(const(T))) => inout(const(T))
        {
            at = t.unSharedOf();
            return MATCH.exact;
        }
    case X(MODFlags.shared_ | MODFlags.const_, MODFlags.shared_):
        // foo(shared(const(U)))        shared(T)               => T
        {
            at = t.unSharedOf();
            return MATCH.constant;
        }
    case X(MODFlags.wildconst, MODFlags.immutable_):
    case X(MODFlags.shared_ | MODFlags.const_, MODFlags.shared_ | MODFlags.wildconst):
    case X(MODFlags.shared_ | MODFlags.wildconst, MODFlags.immutable_):
    case X(MODFlags.shared_ | MODFlags.wildconst, MODFlags.shared_ | MODFlags.wild):
        // foo(inout(const(U)))         immutable(T)            => T
        // foo(shared(const(U)))        shared(inout(const(T))) => T
        // foo(shared(inout(const(U)))) immutable(T)            => T
        // foo(shared(inout(const(U)))) shared(inout(T))        => T
        {
            at = t.unSharedOf().mutableOf();
            return MATCH.constant;
        }
    case X(MODFlags.shared_ | MODFlags.const_, MODFlags.shared_ | MODFlags.wild):
        // foo(shared(const(U)))        shared(inout(T))        => T
        {
            at = t.unSharedOf().mutableOf();
            return MATCH.constant;
        }
    case X(MODFlags.wild, 0):
    case X(MODFlags.wild, MODFlags.const_):
    case X(MODFlags.wild, MODFlags.wildconst):
    case X(MODFlags.wild, MODFlags.immutable_):
    case X(MODFlags.wild, MODFlags.shared_):
    case X(MODFlags.wild, MODFlags.shared_ | MODFlags.const_):
    case X(MODFlags.wild, MODFlags.shared_ | MODFlags.wildconst):
    case X(MODFlags.wildconst, 0):
    case X(MODFlags.wildconst, MODFlags.const_):
    case X(MODFlags.wildconst, MODFlags.wild):
    case X(MODFlags.wildconst, MODFlags.shared_):
    case X(MODFlags.wildconst, MODFlags.shared_ | MODFlags.const_):
    case X(MODFlags.wildconst, MODFlags.shared_ | MODFlags.wild):
    case X(MODFlags.shared_, 0):
    case X(MODFlags.shared_, MODFlags.const_):
    case X(MODFlags.shared_, MODFlags.wild):
    case X(MODFlags.shared_, MODFlags.wildconst):
    case X(MODFlags.shared_, MODFlags.immutable_):
    case X(MODFlags.shared_ | MODFlags.const_, 0):
    case X(MODFlags.shared_ | MODFlags.const_, MODFlags.const_):
    case X(MODFlags.shared_ | MODFlags.const_, MODFlags.wild):
    case X(MODFlags.shared_ | MODFlags.const_, MODFlags.wildconst):
    case X(MODFlags.shared_ | MODFlags.wild, 0):
    case X(MODFlags.shared_ | MODFlags.wild, MODFlags.const_):
    case X(MODFlags.shared_ | MODFlags.wild, MODFlags.wild):
    case X(MODFlags.shared_ | MODFlags.wild, MODFlags.wildconst):
    case X(MODFlags.shared_ | MODFlags.wild, MODFlags.immutable_):
    case X(MODFlags.shared_ | MODFlags.wild, MODFlags.shared_):
    case X(MODFlags.shared_ | MODFlags.wild, MODFlags.shared_ | MODFlags.const_):
    case X(MODFlags.shared_ | MODFlags.wild, MODFlags.shared_ | MODFlags.wildconst):
    case X(MODFlags.shared_ | MODFlags.wildconst, 0):
    case X(MODFlags.shared_ | MODFlags.wildconst, MODFlags.const_):
    case X(MODFlags.shared_ | MODFlags.wildconst, MODFlags.wild):
    case X(MODFlags.shared_ | MODFlags.wildconst, MODFlags.wildconst):
    case X(MODFlags.shared_ | MODFlags.wildconst, MODFlags.shared_):
    case X(MODFlags.shared_ | MODFlags.wildconst, MODFlags.shared_ | MODFlags.const_):
    case X(MODFlags.immutable_, 0):
    case X(MODFlags.immutable_, MODFlags.const_):
    case X(MODFlags.immutable_, MODFlags.wild):
    case X(MODFlags.immutable_, MODFlags.wildconst):
    case X(MODFlags.immutable_, MODFlags.shared_):
    case X(MODFlags.immutable_, MODFlags.shared_ | MODFlags.const_):
    case X(MODFlags.immutable_, MODFlags.shared_ | MODFlags.wild):
    case X(MODFlags.immutable_, MODFlags.shared_ | MODFlags.wildconst):
        // foo(inout(U))                T                       => nomatch
        // foo(inout(U))                const(T)                => nomatch
        // foo(inout(U))                inout(const(T))         => nomatch
        // foo(inout(U))                immutable(T)            => nomatch
        // foo(inout(U))                shared(T)               => nomatch
        // foo(inout(U))                shared(const(T))        => nomatch
        // foo(inout(U))                shared(inout(const(T))) => nomatch
        // foo(inout(const(U)))         T                       => nomatch
        // foo(inout(const(U)))         const(T)                => nomatch
        // foo(inout(const(U)))         inout(T)                => nomatch
        // foo(inout(const(U)))         shared(T)               => nomatch
        // foo(inout(const(U)))         shared(const(T))        => nomatch
        // foo(inout(const(U)))         shared(inout(T))        => nomatch
        // foo(shared(U))               T                       => nomatch
        // foo(shared(U))               const(T)                => nomatch
        // foo(shared(U))               inout(T)                => nomatch
        // foo(shared(U))               inout(const(T))         => nomatch
        // foo(shared(U))               immutable(T)            => nomatch
        // foo(shared(const(U)))        T                       => nomatch
        // foo(shared(const(U)))        const(T)                => nomatch
        // foo(shared(const(U)))        inout(T)                => nomatch
        // foo(shared(const(U)))        inout(const(T))         => nomatch
        // foo(shared(inout(U)))        T                       => nomatch
        // foo(shared(inout(U)))        const(T)                => nomatch
        // foo(shared(inout(U)))        inout(T)                => nomatch
        // foo(shared(inout(U)))        inout(const(T))         => nomatch
        // foo(shared(inout(U)))        immutable(T)            => nomatch
        // foo(shared(inout(U)))        shared(T)               => nomatch
        // foo(shared(inout(U)))        shared(const(T))        => nomatch
        // foo(shared(inout(U)))        shared(inout(const(T))) => nomatch
        // foo(shared(inout(const(U)))) T                       => nomatch
        // foo(shared(inout(const(U)))) const(T)                => nomatch
        // foo(shared(inout(const(U)))) inout(T)                => nomatch
        // foo(shared(inout(const(U)))) inout(const(T))         => nomatch
        // foo(shared(inout(const(U)))) shared(T)               => nomatch
        // foo(shared(inout(const(U)))) shared(const(T))        => nomatch
        // foo(immutable(U))            T                       => nomatch
        // foo(immutable(U))            const(T)                => nomatch
        // foo(immutable(U))            inout(T)                => nomatch
        // foo(immutable(U))            inout(const(T))         => nomatch
        // foo(immutable(U))            shared(T)               => nomatch
        // foo(immutable(U))            shared(const(T))        => nomatch
        // foo(immutable(U))            shared(inout(T))        => nomatch
        // foo(immutable(U))            shared(inout(const(T))) => nomatch
        return MATCH.nomatch;

    default:
        assert(0);
    }
}

__gshared Expression emptyArrayElement = null;

/*
 * Returns `true` if `t` is a reference type, or an array of reference types.
 */
private bool isTopRef(Type t)
{
    auto tb = t.baseElemOf();
    return tb.ty == Tclass ||
           tb.ty == Taarray ||
           tb.ty == Tstruct && tb.hasPointers();
}

/*
 * Returns a valid `Loc` for semantic routines.
 * Some paths require a location derived from the first
 * template parameter when available.
 */
private Loc semanticLoc(scope ref TemplateParameters parameters)
{
    Loc loc;
    if (parameters.length)
        loc = parameters[0].loc;
    return loc;
}

private MATCH deduceAliasThis(Type t, Scope* sc, Type tparam,
    ref TemplateParameters parameters, ref Objects dedtypes, uint* wm)
{
    if (auto tc = t.isTypeClass())
    {
        if (tc.sym.aliasthis && !(tc.att & AliasThisRec.tracingDT))
        {
            if (auto ato = t.aliasthisOf())
            {
                tc.att = cast(AliasThisRec)(tc.att | AliasThisRec.tracingDT);
                auto m = deduceType(ato, sc, tparam, parameters, dedtypes, wm);
                tc.att = cast(AliasThisRec)(tc.att & ~AliasThisRec.tracingDT);
                return m;
            }
        }
    }
    else if (auto ts = t.isTypeStruct())
    {
        if (ts.sym.aliasthis && !(ts.att & AliasThisRec.tracingDT))
        {
            if (auto ato = t.aliasthisOf())
            {
                ts.att = cast(AliasThisRec)(ts.att | AliasThisRec.tracingDT);
                auto m = deduceType(ato, sc, tparam, parameters, dedtypes, wm);
                ts.att = cast(AliasThisRec)(ts.att & ~AliasThisRec.tracingDT);
                return m;
            }
        }
    }
    return MATCH.nomatch;
}

private MATCH deduceParentInstance(Scope* sc, Dsymbol sym, TypeInstance tpi,
    ref TemplateParameters parameters, ref Objects dedtypes, uint* wm)
{
    if (tpi.idents.length)
    {
        RootObject id = tpi.idents[tpi.idents.length - 1];
        if (id.dyncast() == DYNCAST.identifier && sym.ident.equals(cast(Identifier)id))
        {
            Type tparent = sym.parent.getType();
            if (tparent)
            {
                tpi.idents.length--;
                auto m = deduceType(tparent, sc, tpi, parameters, dedtypes, wm);
                tpi.idents.length++;
                return m;
            }
        }
    }
    return MATCH.nomatch;
}

private MATCH matchAll(TypeDeduced td, Type tt)
{
    MATCH match = MATCH.exact;
    foreach (j, e; td.argexps)
    {
        assert(e);
        if (e == emptyArrayElement)
            continue;

        Type t = tt.addMod(td.tparams[j].mod).substWildTo(MODFlags.const_);

        MATCH m = e.implicitConvTo(t);
        if (match > m)
            match = m;
        if (match == MATCH.nomatch)
            break;
    }
    return match;
}
/****
 * Given an identifier, figure out which TemplateParameter it is.
 * Return IDX_NOTFOUND if not found.
 */
private size_t templateIdentifierLookup(Identifier id, TemplateParameters* parameters)
{
    for (size_t i = 0; i < parameters.length; i++)
    {
        TemplateParameter tp = (*parameters)[i];
        if (tp.ident.equals(id))
            return i;
    }
    return IDX_NOTFOUND;
}

private size_t templateParameterLookup(Type tparam, TemplateParameters* parameters)
{
    if (TypeIdentifier tident = tparam.isTypeIdentifier())
    {
        //printf("\ttident = '%s'\n", tident.toChars());
        return templateIdentifierLookup(tident.ident, parameters);
    }
    return IDX_NOTFOUND;
}
/* These form the heart of template argument deduction.
 * Given 'this' being the type argument to the template instance,
 * it is matched against the template declaration parameter specialization
 * 'tparam' to determine the type to be used for the parameter.
 * Example:
 *      template Foo(T:T*)      // template declaration
 *      Foo!(int*)              // template instantiation
 * Input:
 *      this = int*
 *      tparam = T*
 *      parameters = [ T:T* ]   // Array of TemplateParameter's
 * Output:
 *      dedtypes = [ int ]      // Array of Expression/Type's
 */
MATCH deduceType(scope RootObject o, scope Scope* sc, scope Type tparam,
    scope ref TemplateParameters parameters, scope ref Objects dedtypes,
    scope uint* wm = null, size_t inferStart = 0, bool ignoreAliasThis = false)
{
    extern (C++) final class DeduceType : Visitor
    {
        alias visit = Visitor.visit;
    public:
        MATCH result;

        extern (D) this() @safe
        {
            result = MATCH.nomatch;
        }

        override void visit(Type t)
        {
            if (!tparam)
                goto Lnomatch;

            if (t == tparam)
                goto Lexact;

            if (tparam.ty == Tident)
            {
                // Determine which parameter tparam is
                size_t i = templateParameterLookup(tparam, &parameters);
                if (i == IDX_NOTFOUND)
                {
                    if (!sc)
                        goto Lnomatch;

                    /* Need a loc to go with the semantic routine. */
                    Loc loc = semanticLoc(parameters);

                    /* BUG: what if tparam is a template instance, that
                     * has as an argument another Tident?
                     */
                    tparam = tparam.typeSemantic(loc, sc);
                    assert(tparam.ty != Tident);
                    result = deduceType(t, sc, tparam, parameters, dedtypes, wm);
                    return;
                }

                TemplateParameter tp = parameters[i];

                TypeIdentifier tident = tparam.isTypeIdentifier();
                if (tident.idents.length > 0)
                {
                    //printf("matching %s to %s\n", tparam.toChars(), t.toChars());
                    Dsymbol s = t.toDsymbol(sc);
                    for (size_t j = tident.idents.length; j-- > 0;)
                    {
                        RootObject id = tident.idents[j];
                        if (id.dyncast() == DYNCAST.identifier)
                        {
                            if (!s || !s.parent)
                                goto Lnomatch;
                            Dsymbol s2 = s.parent.search(Loc.initial, cast(Identifier)id);
                            if (!s2)
                                goto Lnomatch;
                            s2 = s2.toAlias();
                            //printf("[%d] s = %s %s, s2 = %s %s\n", j, s.kind(), s.toChars(), s2.kind(), s2.toChars());
                            if (s != s2)
                            {
                                if (Type tx = s2.getType())
                                {
                                    if (s != tx.toDsymbol(sc))
                                        goto Lnomatch;
                                }
                                else
                                    goto Lnomatch;
                            }
                            s = s.parent;
                        }
                        else
                            goto Lnomatch;
                    }
                    //printf("[e] s = %s\n", s?s.toChars():"(null)");
                    if (tp.isTemplateTypeParameter())
                    {
                        Type tt = s.getType();
                        if (!tt)
                            goto Lnomatch;
                        Type at = cast(Type)dedtypes[i];
                        if (at && at.ty == Tnone)
                            at = (cast(TypeDeduced)at).tded;
                        if (!at || tt.equals(at))
                        {
                            dedtypes[i] = tt;
                            goto Lexact;
                        }
                    }
                    if (tp.isTemplateAliasParameter())
                    {
                        Dsymbol s2 = cast(Dsymbol)dedtypes[i];
                        if (!s2 || s == s2)
                        {
                            dedtypes[i] = s;
                            goto Lexact;
                        }
                    }
                    goto Lnomatch;
                }

                // Found the corresponding parameter tp
                /+
                    https://issues.dlang.org/show_bug.cgi?id=23578
                    To pattern match:
                    static if (is(S!int == S!av, alias av))

                    We eventually need to deduce `int` (Tint32 [0]) and `av` (Tident).
                    Previously this would not get pattern matched at all, but now we check if the
                    template parameter `av` came from.

                    This note has been left to serve as a hint for further explorers into
                    how IsExp matching works.
                +/
                if (auto ta = tp.isTemplateAliasParameter())
                {
                    dedtypes[i] = t;
                    goto Lexact;
                }
                // (23578) - ensure previous behaviour for non-alias template params
                if (!tp.isTemplateTypeParameter())
                {
                    goto Lnomatch;
                }

                Type at = cast(Type)dedtypes[i];
                Type tt;
                if (ubyte wx = wm ? deduceWildHelper(t, &tt, tparam) : 0)
                {
                    // type vs (none)
                    if (!at)
                    {
                        dedtypes[i] = tt;
                        *wm |= wx;
                        result = MATCH.constant;
                        return;
                    }

                    // type vs expressions
                    if (at.ty == Tnone)
                    {
                        auto xt = cast(TypeDeduced)at;
                        result = xt.matchAll(tt);
                        if (result > MATCH.nomatch)
                        {
                            dedtypes[i] = tt;
                            if (result > MATCH.constant)
                                result = MATCH.constant; // limit level for inout matches
                        }
                        return;
                    }

                    // type vs type
                    if (tt.equals(at))
                    {
                        dedtypes[i] = tt; // Prefer current type match
                        goto Lconst;
                    }
                    if (tt.implicitConvTo(at.constOf()))
                    {
                        dedtypes[i] = at.constOf().mutableOf();
                        *wm |= MODFlags.const_;
                        goto Lconst;
                    }
                    if (at.implicitConvTo(tt.constOf()))
                    {
                        dedtypes[i] = tt.constOf().mutableOf();
                        *wm |= MODFlags.const_;
                        goto Lconst;
                    }
                    goto Lnomatch;
                }
                else if (MATCH m = deduceTypeHelper(t, tt, tparam))
                {
                    // type vs (none)
                    if (!at)
                    {
                        dedtypes[i] = tt;
                        result = m;
                        return;
                    }

                    // type vs expressions
                    if (at.ty == Tnone)
                    {
                        auto xt = cast(TypeDeduced)at;
                        result = xt.matchAll(tt);
                        if (result > MATCH.nomatch)
                        {
                            dedtypes[i] = tt;
                        }
                        return;
                    }

                    // type vs type
                    if (tt.equals(at))
                    {
                        goto Lexact;
                    }
                    if (tt.ty == Tclass && at.ty == Tclass)
                    {
                        result = tt.implicitConvTo(at);
                        return;
                    }
                    if (tt.ty == Tsarray && at.ty == Tarray && tt.nextOf().implicitConvTo(at.nextOf()) >= MATCH.constant)
                    {
                        goto Lexact;
                    }
                }
                goto Lnomatch;
            }

            if (tparam.ty == Ttypeof)
            {
                    /* Need a loc to go with the semantic routine. */
                    Loc loc = semanticLoc(parameters);

                tparam = tparam.typeSemantic(loc, sc);
            }
            if (t.ty != tparam.ty)
            {
                if (Dsymbol sym = t.toDsymbol(sc))
                {
                    if (sym.isforwardRef() && !tparam.deco)
                        goto Lnomatch;
                }

                MATCH m = t.implicitConvTo(tparam);
                if (m == MATCH.nomatch && !ignoreAliasThis)
                {
                    m = deduceAliasThis(t, sc, tparam, parameters, dedtypes, wm);
                }
                result = m;
                return;
            }

            if (t.nextOf())
            {
                if (tparam.deco && !tparam.hasWild())
                {
                    result = t.implicitConvTo(tparam);
                    return;
                }

                Type tpn = tparam.nextOf();
                if (wm && t.ty == Taarray && tparam.isWild())
                {
                    // https://issues.dlang.org/show_bug.cgi?id=12403
                    // In IFTI, stop inout matching on transitive part of AA types.
                    tpn = tpn.substWildTo(MODFlags.mutable);
                }

                result = deduceType(t.nextOf(), sc, tpn, parameters, dedtypes, wm);
                return;
            }

        Lexact:
            result = MATCH.exact;
            return;

        Lnomatch:
            result = MATCH.nomatch;
            return;

        Lconst:
            result = MATCH.constant;
        }

        override void visit(TypeVector t)
        {
            if (auto tp = tparam.isTypeVector())
            {
                result = deduceType(t.basetype, sc, tp.basetype, parameters, dedtypes, wm);
                return;
            }
            visit(cast(Type)t);
        }

        override void visit(TypeDArray t)
        {
            visit(cast(Type)t);
        }

        override void visit(TypeSArray t)
        {
            // Extra check that array dimensions must match
            if (!tparam)
            {
                visit(cast(Type)t);
                return;
            }

            if (tparam.ty == Tarray)
            {
                MATCH m = deduceType(t.next, sc, tparam.nextOf(), parameters, dedtypes, wm);
                result = (m >= MATCH.constant) ? MATCH.convert : MATCH.nomatch;
                return;
            }

            TemplateParameter tp = null;
            Expression edim = null;
            size_t i;
            if (auto tsa = tparam.isTypeSArray())
            {
                if (tsa.dim.isVarExp() && tsa.dim.isVarExp().var.storage_class & STC.templateparameter)
                {
                    Identifier id = tsa.dim.isVarExp().var.ident;
                    i = templateIdentifierLookup(id, &parameters);
                    assert(i != IDX_NOTFOUND);
                    tp = parameters[i];
                }
                else
                    edim = tsa.dim;
            }
            else if (auto taa = tparam.isTypeAArray())
            {
                i = templateParameterLookup(taa.index, &parameters);
                if (i != IDX_NOTFOUND)
                    tp = parameters[i];
                else
                {
                    Loc loc;
                    // The "type" (it hasn't been resolved yet) of the function parameter
                    // does not have a location but the parameter it is related to does,
                    // so we use that for the resolution (better error message).
                    if (inferStart < parameters.length)
                    {
                        TemplateParameter loctp = parameters[inferStart];
                        loc = loctp.loc;
                    }

                    Expression e;
                    Type tx;
                    Dsymbol s;
                    taa.index.resolve(loc, sc, e, tx, s);
                    edim = s ? getValue(s) : getValue(e);
                }
            }
            if ((tp && tp.matchArg(sc, t.dim, i, &parameters, dedtypes, null)) ||
                (edim && edim.isIntegerExp() && edim.toInteger() == t.dim.toInteger())
            )
            {
                result = deduceType(t.next, sc, tparam.nextOf(), parameters, dedtypes, wm);
                return;
            }

            visit(cast(Type)t);
        }

        override void visit(TypeAArray t)
        {
            // Extra check that index type must match
            if (tparam && tparam.ty == Taarray)
            {
                TypeAArray tp = tparam.isTypeAArray();
                if (!deduceType(t.index, sc, tp.index, parameters, dedtypes))
                {
                    result = MATCH.nomatch;
                    return;
                }
            }
            visit(cast(Type)t);
        }

        override void visit(TypeFunction t)
        {
            // Extra check that function characteristics must match
            if (!tparam)
                return visit(cast(Type)t);

            auto tp = tparam.isTypeFunction();
            if (!tp)
            {
                visit(cast(Type)t);
                return;
            }

            if (t.parameterList.varargs != tp.parameterList.varargs || t.linkage != tp.linkage)
            {
                result = MATCH.nomatch;
                return;
            }

            foreach (fparam; *tp.parameterList.parameters)
            {
                // https://issues.dlang.org/show_bug.cgi?id=2579
                // Apply function parameter storage classes to parameter types
                fparam.type = fparam.type.addStorageClass(fparam.storageClass);
                fparam.storageClass &= ~STC.TYPECTOR;

                // https://issues.dlang.org/show_bug.cgi?id=15243
                // Resolve parameter type if it's not related with template parameters
                if (!reliesOnTemplateParameters(fparam.type, parameters[inferStart .. parameters.length]))
                {
                    auto tx = fparam.type.typeSemantic(Loc.initial, sc);
                    if (tx.ty == Terror)
                    {
                        result = MATCH.nomatch;
                        return;
                    }
                    fparam.type = tx;
                }
            }

            const size_t nfargs = t.parameterList.length;
            size_t nfparams = tp.parameterList.length;

            if (!deduceFunctionTuple(t, tp, parameters, dedtypes, nfargs, nfparams))
            {
                result = MATCH.nomatch;
                return;
            }

        L2:
            assert(nfparams <= tp.parameterList.length);
            foreach (i, ap; tp.parameterList)
            {
                if (i == nfparams)
                    break;

                Parameter a = t.parameterList[i];

                if (!a.isCovariant(t.isRef, ap) ||
                    !deduceType(a.type, sc, ap.type, parameters, dedtypes))
                {
                    result = MATCH.nomatch;
                    return;
                }
            }

            visit(cast(Type)t);
        }

        override void visit(TypeIdentifier t)
        {
            // Extra check
            if (tparam && tparam.ty == Tident)
            {
                TypeIdentifier tp = tparam.isTypeIdentifier();
                for (size_t i = 0; i < t.idents.length; i++)
                {
                    RootObject id1 = t.idents[i];
                    RootObject id2 = tp.idents[i];
                    if (!id1.equals(id2))
                    {
                        result = MATCH.nomatch;
                        return;
                    }
                }
            }
            visit(cast(Type)t);
        }

        override void visit(TypeInstance t)
        {
            // Extra check
            if (!tparam || tparam.ty != Tinstance || !t.tempinst.tempdecl)
            {
                visit(cast(Type)t);
                return;
            }

            TemplateDeclaration tempdecl = t.tempinst.tempdecl.isTemplateDeclaration();
            assert(tempdecl);

            TypeInstance tp = tparam.isTypeInstance();

            //printf("tempinst.tempdecl = %p\n", tempdecl);
            //printf("tp.tempinst.tempdecl = %p\n", tp.tempinst.tempdecl);
            if (!tp.tempinst.tempdecl)
            {
                //printf("tp.tempinst.name = '%s'\n", tp.tempinst.name.toChars());

                /* Handle case of:
                 *  template Foo(T : sa!(T), alias sa)
                 */
                size_t i = templateIdentifierLookup(tp.tempinst.name, &parameters);
                if (i == IDX_NOTFOUND)
                {
                    /* Didn't find it as a parameter identifier. Try looking
                     * it up and seeing if is an alias.
                     * https://issues.dlang.org/show_bug.cgi?id=1454
                     */
                    auto tid = new TypeIdentifier(tp.loc, tp.tempinst.name);
                    Type tx;
                    Expression e;
                    Dsymbol s;
                    tid.resolve(tp.loc, sc, e, tx, s);
                    if (tx)
                    {
                        s = tx.toDsymbol(sc);
                        if (TemplateInstance ti = s ? s.parent.isTemplateInstance() : null)
                        {
                            // https://issues.dlang.org/show_bug.cgi?id=14290
                            // Try to match with ti.tempecl,
                            // only when ti is an enclosing instance.
                            Dsymbol p = sc.parent;
                            while (p && p != ti)
                                p = p.parent;
                            if (p)
                                s = ti.tempdecl;
                        }
                    }
                    if (s)
                    {
                        s = s.toAlias();
                        TemplateDeclaration td = s.isTemplateDeclaration();
                        if (td)
                        {
                            if (td.overroot)
                                td = td.overroot;
                            for (; td; td = td.overnext)
                            {
                                if (td == tempdecl)
                                    goto L2;
                            }
                        }
                    }
                    goto Lnomatch;
                }

                TemplateParameter tpx = parameters[i];
                if (!tpx.matchArg(sc, tempdecl, i, &parameters, dedtypes, null))
                    goto Lnomatch;
            }
            else if (tempdecl != tp.tempinst.tempdecl)
                goto Lnomatch;

        L2:
            if (!resolveTemplateInstantiation(sc, &parameters, t.tempinst.tiargs, &t.tempinst.tdtypes, tempdecl, tp, &dedtypes))
                goto Lnomatch;

            visit(cast(Type)t);
            return;

        Lnomatch:
            //printf("no match\n");
            result = MATCH.nomatch;
        }

        override void visit(TypeStruct t)
        {
            /* If this struct is a template struct, and we're matching
             * it against a template instance, convert the struct type
             * to a template instance, too, and try again.
             */
            TemplateInstance ti = t.sym.parent.isTemplateInstance();

            if (tparam && tparam.ty == Tinstance)
            {
                if (ti && ti.toAlias() == t.sym)
                {
                    auto tx = new TypeInstance(Loc.initial, ti);
                    auto m = deduceType(tx, sc, tparam, parameters, dedtypes, wm);
                    // if we have a no match we still need to check alias this
                    if (m != MATCH.nomatch)
                    {
                        result = m;
                        return;
                    }
                }

                TypeInstance tpi = tparam.isTypeInstance();
                auto m = deduceParentInstance(sc, t.sym, tpi, parameters, dedtypes, wm);
                if (m != MATCH.nomatch)
                {
                    result = m;
                    return;
                }
            }

            // Extra check
            if (tparam && tparam.ty == Tstruct)
            {
                TypeStruct tp = tparam.isTypeStruct();

                //printf("\t%d\n", cast(MATCH) t.implicitConvTo(tp));
                if (wm && t.deduceWild(tparam, false))
                {
                    result = MATCH.constant;
                    return;
                }
                result = t.implicitConvTo(tp);
                return;
            }
            visit(cast(Type)t);
        }

        override void visit(TypeEnum t)
        {
            // Extra check
            if (tparam && tparam.ty == Tenum)
            {
                TypeEnum tp = tparam.isTypeEnum();
                if (t.sym == tp.sym)
                    visit(cast(Type)t);
                else
                    result = MATCH.nomatch;
                return;
            }
            Type tb = t.toBasetype();
            if (tb.ty == tparam.ty || tb.ty == Tsarray && tparam.ty == Taarray)
            {
                result = deduceType(tb, sc, tparam, parameters, dedtypes, wm);
                if (result == MATCH.exact)
                    result = MATCH.convert;
                return;
            }
            visit(cast(Type)t);
        }

        override void visit(TypeClass t)
        {
            //printf("TypeClass.deduceType(this = %s)\n", t.toChars());

            /* If this class is a template class, and we're matching
             * it against a template instance, convert the class type
             * to a template instance, too, and try again.
             */
            TemplateInstance ti = t.sym.parent.isTemplateInstance();

            if (tparam && tparam.ty == Tinstance)
            {
                if (ti && ti.toAlias() == t.sym)
                {
                    auto tx = new TypeInstance(Loc.initial, ti);
                    MATCH m = deduceType(tx, sc, tparam, parameters, dedtypes, wm);
                    // Even if the match fails, there is still a chance it could match
                    // a base class.
                    if (m != MATCH.nomatch)
                    {
                        result = m;
                        return;
                    }
                }

                TypeInstance tpi = tparam.isTypeInstance();
                auto m = deduceParentInstance(sc, t.sym, tpi, parameters, dedtypes, wm);
                if (m != MATCH.nomatch)
                {
                    result = m;
                    return;
                }

                // If it matches exactly or via implicit conversion, we're done
                visit(cast(Type)t);
                if (result != MATCH.nomatch)
                    return;

                /* There is still a chance to match via implicit conversion to
                 * a base class or interface. Because there could be more than one such
                 * match, we need to check them all.
                 */

                int numBaseClassMatches = 0; // Have we found an interface match?

                // Our best guess at dedtypes
                auto best = new Objects(dedtypes.length);

                ClassDeclaration s = t.sym;
                while (s && s.baseclasses.length > 0)
                {
                    // Test the base class
                    deduceBaseClassParameters(*(*s.baseclasses)[0], sc, tparam, parameters, dedtypes, *best, numBaseClassMatches);

                    // Test the interfaces inherited by the base class
                    foreach (b; s.interfaces)
                    {
                        deduceBaseClassParameters(*b, sc, tparam, parameters, dedtypes, *best, numBaseClassMatches);
                    }
                    s = (*s.baseclasses)[0].sym;
                }

                if (numBaseClassMatches == 0)
                {
                    result = MATCH.nomatch;
                    return;
                }

                // If we got at least one match, copy the known types into dedtypes
                memcpy(dedtypes.tdata(), best.tdata(), best.length * (void*).sizeof);
                result = MATCH.convert;
                return;
            }

            // Extra check
            if (tparam && tparam.ty == Tclass)
            {
                TypeClass tp = tparam.isTypeClass();

                //printf("\t%d\n", cast(MATCH) t.implicitConvTo(tp));
                if (wm && t.deduceWild(tparam, false))
                {
                    result = MATCH.constant;
                    return;
                }
                result = t.implicitConvTo(tp);
                return;
            }
            visit(cast(Type)t);
        }

        override void visit(Expression e)
        {
            //printf("Expression.deduceType(e = %s)\n", e.toChars());
            size_t i = templateParameterLookup(tparam, &parameters);
            if (i == IDX_NOTFOUND || tparam.isTypeIdentifier().idents.length > 0)
            {
                if (e == emptyArrayElement && tparam.ty == Tarray)
                {
                    Type tn = (cast(TypeNext)tparam).next;
                    result = deduceType(emptyArrayElement, sc, tn, parameters, dedtypes, wm);
                    return;
                }
                e.type.accept(this);
                return;
            }

            TemplateTypeParameter tp = parameters[i].isTemplateTypeParameter();
            if (!tp)
                return; // nomatch

            if (e == emptyArrayElement)
            {
                if (dedtypes[i])
                {
                    result = MATCH.exact;
                    return;
                }
                if (tp.defaultType)
                {
                    tp.defaultType.accept(this);
                    return;
                }
            }

            Type at = cast(Type)dedtypes[i];
            Type tt;
            if (ubyte wx = deduceWildHelper(e.type, &tt, tparam))
            {
                *wm |= wx;
                result = MATCH.constant;
            }
            else if (MATCH m = deduceTypeHelper(e.type, tt, tparam))
            {
                result = m;
            }
            else if (!isTopRef(e.type))
            {
                /* https://issues.dlang.org/show_bug.cgi?id=15653
                 * In IFTI, recognize top-qualifier conversions
                 * through the value copy, e.g.
                 *      int --> immutable(int)
                 *      immutable(string[]) --> immutable(string)[]
                 */
                tt = e.type.mutableOf();
                result = MATCH.convert;
            }
            else
                return; // nomatch

            // expression vs (none)
            if (!at)
            {
                dedtypes[i] = new TypeDeduced(tt, e, tparam);
                return;
            }

            TypeDeduced xt = null;
            if (at.ty == Tnone)
            {
                xt = cast(TypeDeduced)at;
                at = xt.tded;
            }

            // From previous matched expressions to current deduced type
            MATCH match1 = xt ? xt.matchAll(tt) : MATCH.nomatch;

            // From current expressions to previous deduced type
            Type pt = at.addMod(tparam.mod);
            if (*wm)
                pt = pt.substWildTo(*wm);
            MATCH match2 = e.implicitConvTo(pt);

            if (match1 > MATCH.nomatch && match2 > MATCH.nomatch)
            {
                if (at.implicitConvTo(tt) == MATCH.nomatch)
                    match1 = MATCH.nomatch; // Prefer at
                else if (tt.implicitConvTo(at) == MATCH.nomatch)
                    match2 = MATCH.nomatch; // Prefer tt
                else if (tt.isTypeBasic() && tt.ty == at.ty && tt.mod != at.mod)
                {
                    if (!tt.isMutable() && !at.isMutable())
                        tt = tt.mutableOf().addMod(MODmerge(tt.mod, at.mod));
                    else if (tt.isMutable())
                    {
                        if (at.mod == 0) // Prefer unshared
                            match1 = MATCH.nomatch;
                        else
                            match2 = MATCH.nomatch;
                    }
                    else if (at.isMutable())
                    {
                        if (tt.mod == 0) // Prefer unshared
                            match2 = MATCH.nomatch;
                        else
                            match1 = MATCH.nomatch;
                    }
                    //printf("tt = %s, at = %s\n", tt.toChars(), at.toChars());
                }
                else
                {
                    match1 = MATCH.nomatch;
                    match2 = MATCH.nomatch;
                }
            }
            if (match1 > MATCH.nomatch)
            {
                // Prefer current match: tt
                if (xt)
                    xt.update(tt, e, tparam);
                else
                    dedtypes[i] = tt;
                result = match1;
                return;
            }
            if (match2 > MATCH.nomatch)
            {
                // Prefer previous match: (*dedtypes)[i]
                if (xt)
                    xt.update(e, tparam);
                result = match2;
                return;
            }

            /* Deduce common type
             */
            if (Type t = rawTypeMerge(at, tt))
            {
                if (xt)
                    xt.update(t, e, tparam);
                else
                    dedtypes[i] = t;

                pt = tt.addMod(tparam.mod);
                if (*wm)
                    pt = pt.substWildTo(*wm);
                result = e.implicitConvTo(pt);
                return;
            }

            result = MATCH.nomatch;
        }

        private MATCH deduceEmptyArrayElement()
        {
            if (!emptyArrayElement)
            {
                emptyArrayElement = new IdentifierExp(Loc.initial, Id.p); // dummy
                emptyArrayElement.type = Type.tvoid;
            }
            assert(tparam.ty == Tarray);

            Type tn = (cast(TypeNext)tparam).next;
            return deduceType(emptyArrayElement, sc, tn, parameters, dedtypes, wm);
        }

        override void visit(NullExp e)
        {
            if (tparam.ty == Tarray && e.type.ty == Tnull)
            {
                // tparam:T[] <- e:null (void[])
                result = deduceEmptyArrayElement();
                return;
            }
            visit(cast(Expression)e);
        }

        override void visit(StringExp e)
        {
            Type taai;
            if (e.type.ty == Tarray && (tparam.ty == Tsarray || tparam.ty == Taarray && (taai = (cast(TypeAArray)tparam).index).ty == Tident && (cast(TypeIdentifier)taai).idents.length == 0))
            {
                // Consider compile-time known boundaries
                e.type.nextOf().sarrayOf(e.len).accept(this);
                return;
            }
            visit(cast(Expression)e);
        }

        override void visit(ArrayLiteralExp e)
        {
            // https://issues.dlang.org/show_bug.cgi?id=20092
            if (e.elements && e.elements.length && e.type.toBasetype().nextOf().ty == Tvoid)
            {
                result = deduceEmptyArrayElement();
                return;
            }
            if ((!e.elements || !e.elements.length) && e.type.toBasetype().nextOf().ty == Tvoid && tparam.ty == Tarray)
            {
                // tparam:T[] <- e:[] (void[])
                result = deduceEmptyArrayElement();
                return;
            }

            if (tparam.ty == Tarray && e.elements && e.elements.length)
            {
                Type tn = (cast(TypeDArray)tparam).next;
                result = MATCH.exact;
                if (e.basis)
                {
                    MATCH m = deduceType(e.basis, sc, tn, parameters, dedtypes, wm);
                    if (m < result)
                        result = m;
                }
                foreach (el; *e.elements)
                {
                    if (result == MATCH.nomatch)
                        break;
                    if (!el)
                        continue;
                    MATCH m = deduceType(el, sc, tn, parameters, dedtypes, wm);
                    if (m < result)
                        result = m;
                }
                return;
            }

            Type taai;
            if (e.type.ty == Tarray && (tparam.ty == Tsarray || tparam.ty == Taarray && (taai = (cast(TypeAArray)tparam).index).ty == Tident && (cast(TypeIdentifier)taai).idents.length == 0))
            {
                // Consider compile-time known boundaries
                e.type.nextOf().sarrayOf(e.elements.length).accept(this);
                return;
            }
            visit(cast(Expression)e);
        }

        override void visit(AssocArrayLiteralExp e)
        {
            if (tparam.ty == Taarray && e.keys && e.keys.length)
            {
                TypeAArray taa = cast(TypeAArray)tparam;
                result = MATCH.exact;
                foreach (i, key; *e.keys)
                {
                    MATCH m1 = deduceType(key, sc, taa.index, parameters, dedtypes, wm);
                    if (m1 < result)
                        result = m1;
                    if (result == MATCH.nomatch)
                        break;
                    MATCH m2 = deduceType((*e.values)[i], sc, taa.next, parameters, dedtypes, wm);
                    if (m2 < result)
                        result = m2;
                    if (result == MATCH.nomatch)
                        break;
                }
                return;
            }
            visit(cast(Expression)e);
        }

        override void visit(FuncExp e)
        {
            //printf("e.type = %s, tparam = %s\n", e.type.toChars(), tparam.toChars());
            if (e.td)
            {
                Type to = tparam;
                if (!to.nextOf())
                    return;
                auto tof = to.nextOf().isTypeFunction();
                if (!tof)
                    return;

                // Parameter types inference from 'tof'
                assert(e.td._scope);
                TypeFunction tf = e.fd.type.isTypeFunction();
                //printf("\ttof = %s\n", tof.toChars());
                //printf("\ttf  = %s\n", tf.toChars());
                const dim = tf.parameterList.length;

                if (tof.parameterList.length != dim || tof.parameterList.varargs != tf.parameterList.varargs)
                    return;

                auto tiargs = new Objects();
                tiargs.reserve(e.td.parameters.length);

                foreach (tp; *e.td.parameters)
                {
                    size_t u = 0;
                    foreach (i, p; tf.parameterList)
                    {
                        if (p.type.ty == Tident && (cast(TypeIdentifier)p.type).ident == tp.ident)
                            break;
                        ++u;
                    }
                    assert(u < dim);
                    Parameter pto = tof.parameterList[u];
                    if (!pto)
                        break;
                    Type t = pto.type.syntaxCopy(); // https://issues.dlang.org/show_bug.cgi?id=11774
                    if (reliesOnTemplateParameters(t, parameters[inferStart .. parameters.length]))
                        return;
                    t = t.typeSemantic(e.loc, sc);
                    if (t.ty == Terror)
                        return;
                    tiargs.push(t);
                }

                // Set target of return type inference
                if (!tf.next && tof.next)
                    e.fd.treq = tparam;

                auto ti = new TemplateInstance(e.loc, e.td, tiargs);
                Expression ex = (new ScopeExp(e.loc, ti)).expressionSemantic(e.td._scope);

                // Reset inference target for the later re-semantic
                e.fd.treq = null;

                if (ex.op == EXP.error)
                    return;
                if (ex.op != EXP.function_)
                    return;
                visit(ex.type);
                return;
            }

            Type t = e.type;

            if (t.ty == Tdelegate && tparam.ty == Tpointer)
                return;

            // Allow conversion from implicit function pointer to delegate
            if (e.tok == TOK.reserved && t.ty == Tpointer && tparam.ty == Tdelegate)
            {
                TypeFunction tf = t.nextOf().isTypeFunction();
                t = (new TypeDelegate(tf)).merge();
            }
            //printf("tparam = %s <= e.type = %s, t = %s\n", tparam.toChars(), e.type.toChars(), t.toChars());
            visit(t);
        }

        override void visit(SliceExp e)
        {
            Type taai;
            if (e.type.ty == Tarray && (tparam.ty == Tsarray || tparam.ty == Taarray && (taai = (cast(TypeAArray)tparam).index).ty == Tident && (cast(TypeIdentifier)taai).idents.length == 0))
            {
                // Consider compile-time known boundaries
                if (Type tsa = toStaticArrayType(e))
                {
                    tsa.accept(this);
                    if (result > MATCH.convert)
                        result = MATCH.convert; // match with implicit conversion at most
                    return;
                }
            }
            visit(cast(Expression)e);
        }

        override void visit(CommaExp e)
        {
            e.e2.accept(this);
        }
    }

    scope DeduceType v = new DeduceType();
    if (Type t = isType(o))
        t.accept(v);
    else if (Expression e = isExpression(o))
    {
        assert(wm);
        e.accept(v);
    }
    else
        assert(0);
    return v.result;
}


/* Helper for TypeClass.deduceType().
 * Classes can match with implicit conversion to a base class or interface.
 * This is complicated, because there may be more than one base class which
 * matches. In such cases, one or more parameters remain ambiguous.
 * For example,
 *
 *   interface I(X, Y) {}
 *   class C : I(uint, double), I(char, double) {}
 *   C x;
 *   foo(T, U)( I!(T, U) x)
 *
 *   deduces that U is double, but T remains ambiguous (could be char or uint).
 *
 * Given a baseclass b, and initial deduced types 'dedtypes', this function
 * tries to match tparam with b, and also tries all base interfaces of b.
 * If a match occurs, numBaseClassMatches is incremented, and the new deduced
 * types are ANDed with the current 'best' estimate for dedtypes.
 */
private void deduceBaseClassParameters(ref BaseClass b, Scope* sc, Type tparam, ref TemplateParameters parameters, ref Objects dedtypes, ref Objects best, ref int numBaseClassMatches)
{
    if (TemplateInstance parti = b.sym ? b.sym.parent.isTemplateInstance() : null)
    {
        // Make a temporary copy of dedtypes so we don't destroy it
        auto tmpdedtypes = new Objects(dedtypes.length);
        memcpy(tmpdedtypes.tdata(), dedtypes.tdata(), dedtypes.length * (void*).sizeof);

        auto t = new TypeInstance(Loc.initial, parti);
        MATCH m = deduceType(t, sc, tparam, parameters, *tmpdedtypes);
        if (m > MATCH.nomatch)
        {
            // If this is the first ever match, it becomes our best estimate
            if (numBaseClassMatches == 0)
                memcpy(best.tdata(), tmpdedtypes.tdata(), tmpdedtypes.length * (void*).sizeof);
            else
                for (size_t k = 0; k < tmpdedtypes.length; ++k)
                {
                    // If we've found more than one possible type for a parameter,
                    // mark it as unknown.
                    if ((*tmpdedtypes)[k] != best[k])
                        best[k] = dedtypes[k];
                }
            ++numBaseClassMatches;
        }
    }

    // Now recursively test the inherited interfaces
    foreach (ref bi; b.baseInterfaces)
    {
        deduceBaseClassParameters(bi, sc, tparam, parameters, dedtypes, best, numBaseClassMatches);
    }
}

/*
 * Handle tuple matching for function parameters.
 * If the last parameter of `tp` is a template tuple parameter,
 * collect the corresponding argument types from `t`.
 * Params:
 *     t          = actual function type
 *     tp         = template function type
 *     parameters = template parameters
 *     dedtypes   = deduced types array
 *     nfargs     = number of arguments in `t`
 *     nfparams   = number of parameters in `tp` (updated on success)
 * Returns: `true` on success, `false` on mismatch.
 */
private bool deduceFunctionTuple(TypeFunction t, TypeFunction tp,
    ref TemplateParameters parameters, ref Objects dedtypes,
    size_t nfargs, ref size_t nfparams)
{
    if (nfparams > 0 && nfargs >= nfparams - 1)
    {
        Parameter fparam = tp.parameterList[nfparams - 1];
        assert(fparam && fparam.type);
        if (fparam.type.ty == Tident)
        {
            TypeIdentifier tid = fparam.type.isTypeIdentifier();
            if (tid.idents.length == 0)
            {
                size_t tupi = 0;
                for (; tupi < parameters.length; ++tupi)
                {
                    TemplateParameter tx = parameters[tupi];
                    TemplateTupleParameter tup = tx.isTemplateTupleParameter();
                    if (tup && tup.ident.equals(tid.ident))
                        break;
                }
                if (tupi == parameters.length)
                    return nfargs == nfparams;

                size_t tuple_dim = nfargs - (nfparams - 1);

                RootObject o = dedtypes[tupi];
                if (o)
                {
                    Tuple tup = isTuple(o);
                    if (!tup || tup.objects.length != tuple_dim)
                        return false;
                    for (size_t i = 0; i < tuple_dim; ++i)
                    {
                        if (!t.parameterList[nfparams - 1 + i].type.equals(tup.objects[i]))
                            return false;
                    }
                }
                else
                {
                    auto tup = new Tuple(tuple_dim);
                    for (size_t i = 0; i < tuple_dim; ++i)
                        tup.objects[i] = t.parameterList[nfparams - 1 + i].type;
                    dedtypes[tupi] = tup;
                }
                --nfparams; // ignore tuple parameter for further deduction
                return true;
            }
        }
    }
    return nfargs == nfparams;
}

/********************
 * Match template `parameters` to the target template instance.
 * Example:
 *    struct Temp(U, int Z) {}
 *    void foo(T)(Temp!(T, 3));
 *    foo(Temp!(int, 3)());
 * Input:
 *    sc               = context
 *    parameters       = template params of foo -> [T]
 *    tiargs           = <Temp!(int, 3)>.tiargs  -> [int, 3]
 *    tdtypes          = <Temp!(int, 3)>.tdtypes -> [int, 3]
 *    tempdecl         = <struct Temp!(T, int Z)> -> [T, Z]
 *    tp               = <Temp!(T, 3)>
 * Output:
 *    dedtypes         = deduced params of `foo(Temp!(int, 3)())` -> [int]
 */
private bool resolveTemplateInstantiation(Scope* sc, TemplateParameters* parameters, Objects* tiargs, Objects* tdtypes, TemplateDeclaration tempdecl, TypeInstance tp, Objects* dedtypes)
{
    for (size_t i = 0; 1; i++)
    {
        //printf("\ttest: tempinst.tiargs[%zu]\n", i);
        RootObject o1 = null;
        if (i < tiargs.length)
            o1 = (*tiargs)[i];
        else if (i < tdtypes.length && i < tp.tempinst.tiargs.length)
        {
            // Pick up default arg
            o1 = (*tdtypes)[i];
        }
        else if (i >= tp.tempinst.tiargs.length)
            break;
        //printf("\ttest: o1 = %s\n", o1.toChars());
        if (i >= tp.tempinst.tiargs.length)
        {
            size_t dim = tempdecl.parameters.length - (tempdecl.isVariadic() ? 1 : 0);
            while (i < dim && ((*tempdecl.parameters)[i].dependent || (*tempdecl.parameters)[i].hasDefaultArg()))
            {
                i++;
            }
            if (i >= dim)
                break; // match if all remained parameters are dependent
            return false;
        }

        RootObject o2 = (*tp.tempinst.tiargs)[i];
        Type t2 = isType(o2);
        //printf("\ttest: o2 = %s\n", o2.toChars());
        size_t j = (t2 && t2.ty == Tident && i == tp.tempinst.tiargs.length - 1)
            ? templateParameterLookup(t2, parameters) : IDX_NOTFOUND;
        if (j != IDX_NOTFOUND && j == parameters.length - 1 &&
            (*parameters)[j].isTemplateTupleParameter())
        {
            /* Given:
                 *  struct A(B...) {}
                 *  alias A!(int, float) X;
                 *  static if (is(X Y == A!(Z), Z...)) {}
                 * deduce that Z is a tuple(int, float)
                 */

            /* Create tuple from remaining args
                 */
            size_t vtdim = (tempdecl.isVariadic() ? tiargs.length : tdtypes.length) - i;
            auto vt = new Tuple(vtdim);
            for (size_t k = 0; k < vtdim; k++)
            {
                RootObject o;
                if (k < tiargs.length)
                    o = (*tiargs)[i + k];
                else // Pick up default arg
                    o = (*tdtypes)[i + k];
                vt.objects[k] = o;
            }

            Tuple v = cast(Tuple)(*dedtypes)[j];
            if (v)
            {
                if (!match(v, vt))
                    return false;
            }
            else
                (*dedtypes)[j] = vt;
            break;
        }
        else if (!o1)
            break;

        Type t1 = isType(o1);
        Dsymbol s1 = isDsymbol(o1);
        Dsymbol s2 = isDsymbol(o2);
        Expression e1 = s1 ? getValue(s1) : getValue(isExpression(o1));
        Expression e2 = isExpression(o2);
        version (none)
        {
            Tuple v1 = isTuple(o1);
            Tuple v2 = isTuple(o2);
            if (t1)
                printf("t1 = %s\n", t1.toChars());
            if (t2)
                printf("t2 = %s\n", t2.toChars());
            if (e1)
                printf("e1 = %s\n", e1.toChars());
            if (e2)
                printf("e2 = %s\n", e2.toChars());
            if (s1)
                printf("s1 = %s\n", s1.toChars());
            if (s2)
                printf("s2 = %s\n", s2.toChars());
            if (v1)
                printf("v1 = %s\n", v1.toChars());
            if (v2)
                printf("v2 = %s\n", v2.toChars());
        }

        if (t1 && t2)
        {
            if (!deduceType(t1, sc, t2, *parameters, *dedtypes))
                return false;
        }
        else if (e1 && e2)
        {
        Le:
            e1 = e1.ctfeInterpret();

            /* If it is one of the template parameters for this template,
                 * we should not attempt to interpret it. It already has a value.
                 */
            if (e2.op == EXP.variable && (e2.isVarExp().var.storage_class & STC.templateparameter))
            {
                /*
                     * (T:Number!(e2), int e2)
                     */
                j = templateIdentifierLookup(e2.isVarExp().var.ident, parameters);
                if (j != IDX_NOTFOUND)
                    goto L1;
                // The template parameter was not from this template
                // (it may be from a parent template, for example)
            }

            e2 = e2.expressionSemantic(sc); // https://issues.dlang.org/show_bug.cgi?id=13417
            e2 = e2.ctfeInterpret();

            //printf("e1 = %s, type = %s %d\n", e1.toChars(), e1.type.toChars(), e1.type.ty);
            //printf("e2 = %s, type = %s %d\n", e2.toChars(), e2.type.toChars(), e2.type.ty);
            if (!e1.equals(e2))
            {
                if (!e2.implicitConvTo(e1.type))
                    return false;

                e2 = e2.implicitCastTo(sc, e1.type);
                e2 = e2.ctfeInterpret();
                if (!e1.equals(e2))
                    return false;
            }
        }
        else if (e1 && t2 && t2.ty == Tident)
        {
            j = templateParameterLookup(t2, parameters);
        L1:
            if (j == IDX_NOTFOUND)
            {
                t2.resolve((cast(TypeIdentifier)t2).loc, sc, e2, t2, s2);
                if (e2)
                    goto Le;
                return false;
            }
            if (!(*parameters)[j].matchArg(sc, e1, j, parameters, *dedtypes, null))
                return false;
        }
        else if (s1 && s2)
        {
        Ls:
            if (!s1.equals(s2))
                return false;
        }
        else if (s1 && t2 && t2.ty == Tident)
        {
            j = templateParameterLookup(t2, parameters);
            if (j == IDX_NOTFOUND)
            {
                t2.resolve((cast(TypeIdentifier)t2).loc, sc, e2, t2, s2);
                if (s2)
                    goto Ls;
                return false;
            }
            if (!(*parameters)[j].matchArg(sc, s1, j, parameters, *dedtypes, null))
                return false;
        }
        else
            return false;
    }
    return true;
}

private  Expression getValue(ref Dsymbol s)
{
    if (s)
    {
        if (VarDeclaration v = s.isVarDeclaration())
        {
            if (v.storage_class & STC.manifest)
                return v.getConstInitializer();
        }
    }
    return null;
}

/***********************
 * Try to get value from manifest constant
 */
private Expression getValue(Expression e)
{
    if (!e)
        return null;
    if (auto ve = e.isVarExp())
    {
        if (auto v = ve.var.isVarDeclaration())
        {
            if (v.storage_class & STC.manifest)
            {
                e = v.getConstInitializer();
            }
        }
    }
    return e;
}

Expression getExpression(RootObject o)
{
    auto s = isDsymbol(o);
    return s ? .getValue(s) : .getValue(isExpression(o));
}
