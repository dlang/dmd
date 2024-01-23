/**
 * Template semantics.
 *
 * Copyright:   Copyright (C) 1999-2024 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/templatesem.d, _templatesem.d)
 * Documentation:  https://dlang.org/phobos/dmd_templatesem.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/templatesem.d
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
import dmd.dmangle;
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
import dmd.tokens;
import dmd.typesem;
import dmd.visitor;

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
    int variadic = td.isVariadic() !is null;

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
            if (argumentList.hasNames)
                return nomatch();
            Expressions* fargs = argumentList.arguments;
            // TODO: Expressions* fargs = tf.resolveNamedArgs(argumentList, null);
            // if (!fargs)
            //     return nomatch();

            fd = new FuncDeclaration(fd.loc, fd.endloc, fd.ident, fd.storage_class, tf);
            fd.parent = ti;
            fd.inferRetType = true;

            // Shouldn't run semantic on default arguments and return type.
            foreach (ref param; *tf.parameterList.parameters)
                param.defaultArg = null;

            tf.next = null;
            tf.incomplete = true;

            // Resolve parameter types and 'auto ref's.
            tf.fargs = fargs;
            uint olderrors = global.startGagging();
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
    scx.flags |= SCOPE.constraint;

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
        fd.declareThis(scx);
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

/*******************************************
 * Append to buf a textual representation of template parameters with their arguments.
 * Params:
 *  parameters = the template parameters
 *  tiargs = the correspondeing template arguments
 *  variadic = if it's a variadic argument list
 *  buf = where the text output goes
 */
void formatParamsWithTiargs(ref TemplateParameters parameters, ref Objects tiargs, bool variadic, ref OutBuffer buf)
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
    paramscope.stc = 0;
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
        printf("%s.leastAsSpecialized(%s)\n", toChars(), td2.toChars());
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
