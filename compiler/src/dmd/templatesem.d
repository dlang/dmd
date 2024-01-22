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
    Scope* paramscope = td.scopeForTemplateParameters(ti,sc);

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
        if (!TemplateDeclaration.evaluateConstraint(td, ti, sc, paramscope, &dedtypes, fd))
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
