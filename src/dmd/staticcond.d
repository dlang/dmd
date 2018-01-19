/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2018 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/staticcond.d, _staticcond.d)
 * Documentation:  https://dlang.org/phobos/dmd_staticcond.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/staticcond.d
 */

module dmd.staticcond;

import dmd.arraytypes;
import dmd.dmodule;
import dmd.dscope;
import dmd.dsymbol;
import dmd.errors;
import dmd.expression;
import dmd.expressionsem;
import dmd.globals;
import dmd.identifier;
import dmd.mtype;
import dmd.tokens;
import dmd.utils;



/********************************************
 * Semantically analyze and then evaluate a static condition at compile time.
 * This is special because short circuit operators &&, || and ?: at the top
 * level are not semantically analyzed if the result of the expression is not
 * necessary.
 * Params:
 *      sc  = instantiating scope
 *      exp = original expression, for error messages
 *      e =  resulting expression
 *      errors = set to `true` if errors occurred
 * Returns:
 *      true if evaluates to true
 */

bool evalStaticCondition(Scope* sc, Expression exp, Expression e, ref bool errors)
{
    if (e.op == TOK.andAnd || e.op == TOK.orOr)
    {
        LogicalExp aae = cast(LogicalExp)e;
        bool result = evalStaticCondition(sc, exp, aae.e1, errors);
        if (errors)
            return false;
        if (e.op == TOK.andAnd)
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

    if (e.op == TOK.question)
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
    sc.flags |= SCOPE.condition;

    e = e.expressionSemantic(sc);
    e = resolveProperties(sc, e);

    sc = sc.endCTFE();
    e = e.optimize(WANTvalue);

    if (nerrors != global.errors ||
        e.op == TOK.error ||
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
