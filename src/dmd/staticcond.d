/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2019 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/staticcond.d, _staticcond.d)
 * Documentation:  https://dlang.org/phobos/dmd_staticcond.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/staticcond.d
 */

module dmd.staticcond;

import dmd.aliasthis;
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


class StaticConditionResult
{
    this(Expression exp, bool result, bool wasEvaluated)
    {
        this.exp = exp;
        this.result = result;
        this.wasEvaluated = wasEvaluated;
    }

    Expression exp; /// original expression, for error messages
    bool result; /// final result
    bool wasEvaluated; /// if this part was evaluated at all

    StaticConditionResult e1; /// result on the one side, if done
    StaticConditionResult e2; /// result on the other side, if done

    const(char*) toChars() {
        return (toString() ~ "\0").ptr;
    }

    override string toString()
    {
        import core.stdc.string;
        string s;
        if (e1)
        {
            auto p = e1.toString();
            if (p.length)
            {
                if(s.length)
                    s ~= "\n";
                s ~= p;
            }
        }

        if (e2)
        {
            auto p = e2.toString();
            if (p.length)
            {
                if (s.length)
                    s ~= "\n";
                s ~= p;
            }
        }

        if (!e1 && !e2)
        {
            if (wasEvaluated && !result)
            {
                auto c = exp.toChars();

                s ~= "clause `";
                s ~= c[0 .. strlen(c)];
                s ~= "` was false ";
            }
        }

        return s;
    }
}

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

StaticConditionResult evalStaticCondition(Scope* sc, Expression exp, Expression e, ref bool errors)
{
//if(e.parens) printf("PARANS %s\n\n", e.toChars);
    if (e.op == TOK.andAnd || e.op == TOK.orOr)
    {
        LogicalExp aae = cast(LogicalExp)e;
        auto result = new StaticConditionResult(e, false, true);
        auto r2 = evalStaticCondition(sc, exp, aae.e1, errors);
        result.e1 = r2;
        result.result = r2.result;
        if (errors)
            return new StaticConditionResult(exp, false, false);
        if (e.op == TOK.andAnd)
        {
            if (!result.result)
                return result;
        }
        else
        {
            if (result.result)
                return result;
        }
        auto r3 = evalStaticCondition(sc, exp, aae.e2, errors);
        result.e2 = r3;
        result.result = r3.result;
        if(errors)
            result.result = false;
        return result; // !errors && result;
    }

    if (e.op == TOK.question)
    {
        CondExp ce = cast(CondExp)e;
        auto result = evalStaticCondition(sc, exp, ce.econd, errors);
        if (errors)
            return new StaticConditionResult(exp, false, false);
        Expression leg = result.result ? ce.e1 : ce.e2;
        result.e1 = evalStaticCondition(sc, exp, leg, errors);
        result.result = result.e1.result;
        if(errors)
            result.result = false;
        return result;
    }

    uint nerrors = global.errors;

    sc = sc.startCTFE();
    sc.flags |= SCOPE.condition;

    auto originalE = e;

    e = e.expressionSemantic(sc);
    e = resolveProperties(sc, e);

    sc = sc.endCTFE();
    e = e.optimize(WANTvalue);

    if (nerrors != global.errors ||
        e.op == TOK.error ||
        e.type.toBasetype() == Type.terror)
    {
        errors = true;
        return new StaticConditionResult(exp, false, false);
    }

    e = resolveAliasThis(sc, e);

    if (!e.type.isBoolean())
    {
        exp.error("expression `%s` of type `%s` does not have a boolean value", exp.toChars(), e.type.toChars());
        errors = true;
        return new StaticConditionResult(exp, false, false);
    }

    e = e.ctfeInterpret();

    if (e.isBool(true))
        return new StaticConditionResult(originalE, true, true);
    else if (e.isBool(false))
        return new StaticConditionResult(originalE, false, true);

    e.error("expression `%s` is not constant", e.toChars());
    errors = true;
    return new StaticConditionResult(exp, false, false);
}
