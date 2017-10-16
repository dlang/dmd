/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/ddmd/staticcond.d, _staticcond.d)
 */

module ddmd.staticcond;

// Online documentation: https://dlang.org/phobos/ddmd_staticcond.html

import ddmd.arraytypes;
import ddmd.dmodule;
import ddmd.dscope;
import ddmd.dsymbol;
import ddmd.errors;
import ddmd.expression;
import ddmd.expressionsem;
import ddmd.globals;
import ddmd.identifier;
import ddmd.mtype;
import ddmd.semantic;
import ddmd.tokens;
import ddmd.utils;



/********************************************
 * Semantically analyze and then evaluate a static condition at compile time.
 * This is special because short circuit operators &&, || and ?: at the top
 * level are not semantically analyzed if the result of the expression is not
 * necessary.
 * Params:
 *      exp = original expression, for error messages
 * Returns:
 *      true if evaluates to true
 */

bool evalStaticCondition(Scope* sc, Expression exp, Expression e, ref bool errors)
{
    if (e.op == TOKandand || e.op == TOKoror)
    {
        LogicalExp aae = cast(LogicalExp)e;
        bool result = evalStaticCondition(sc, exp, aae.e1, errors);
        if (errors)
            return false;
        if (e.op == TOKandand)
        {
            if (!result)
                return false;
        }
        else
        {
            if (result)
                return true;
        }
        result = evalStaticCondition(sc, exp, aae.e2, errors);
        return !errors && result;
    }

    if (e.op == TOKquestion)
    {
        CondExp ce = cast(CondExp)e;
        bool result = evalStaticCondition(sc, exp, ce.econd, errors);
        if (errors)
            return false;
        Expression leg = result ? ce.e1 : ce.e2;
        result = evalStaticCondition(sc, exp, leg, errors);
        return !errors && result;
    }

    uint nerrors = global.errors;

    sc = sc.startCTFE();
    sc.flags |= SCOPEcondition;

    e = e.expressionSemantic(sc);
    e = resolveProperties(sc, e);

    sc = sc.endCTFE();
    e = e.optimize(WANTvalue);

    if (nerrors != global.errors ||
        e.op == TOKerror ||
        e.type.toBasetype() == Type.terror)
    {
        errors = true;
        return false;
    }

    if (!e.type.isBoolean())
    {
        exp.error("expression `%s` of type `%s` does not have a boolean value", exp.toChars(), e.type.toChars());
        errors = true;
        return false;
    }

    e = e.ctfeInterpret();

    if (e.isBool(true))
        return true;
    else if (e.isBool(false))
        return false;

    e.error("expression `%s` is not constant", e.toChars());
    errors = true;
    return false;
}
