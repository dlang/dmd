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
import dmd.root.array;
import dmd.root.outbuffer;
import dmd.tokens;
import dmd.utils;



/********************************************
 * Semantically analyze and then evaluate a static condition at compile time.
 * This is special because short circuit operators &&, || and ?: at the top
 * level are not semantically analyzed if the result of the expression is not
 * necessary.
 * Params:
 *      sc  = instantiating scope
 *      original = original expression, for error messages
 *      e =  resulting expression
 *      errors = set to `true` if errors occurred
 *      negatives = array to store negative clauses
 * Returns:
 *      true if evaluates to true
 */
bool evalStaticCondition(Scope* sc, Expression original, Expression e, out bool errors, Array!Expression* negatives = null)
{
    if (negatives)
        negatives.setDim(0);

    bool impl(Expression e)
    {
        if (e.op == TOK.not)
        {
            NotExp ne = cast(NotExp)e;
            return !impl(ne.e1);
        }

        if (e.op == TOK.andAnd || e.op == TOK.orOr)
        {
            LogicalExp aae = cast(LogicalExp)e;
            bool result = impl(aae.e1);
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
            result = impl(aae.e2);
            return !errors && result;
        }

        if (e.op == TOK.question)
        {
            CondExp ce = cast(CondExp)e;
            bool result = impl(ce.econd);
            if (errors)
                return false;
            Expression leg = result ? ce.e1 : ce.e2;
            result = impl(leg);
            return !errors && result;
        }

        Expression before = e;
        const uint nerrors = global.errors;

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

        e = resolveAliasThis(sc, e);

        if (!e.type.isBoolean())
        {
            original.error("expression `%s` of type `%s` does not have a boolean value",
                original.toChars(), e.type.toChars());
            errors = true;
            return false;
        }

        e = e.ctfeInterpret();

        if (e.isBool(true))
            return true;
        else if (e.isBool(false))
        {
            if (negatives)
                negatives.push(before);
            return false;
        }

        e.error("expression `%s` is not constant", e.toChars());
        errors = true;
        return false;
    }
    return impl(e);
}

/********************************************
 * Format a static condition as a tree-like structure, marking failed and
 * bypassed expressions.
 * Params:
 *      original = original expression
 *      instantiated = instantiated expression
 *      negatives = array with negative clauses from `instantiated` expression
 * Returns:
 *      formatted string or `null` if the expressions were `null`
 */
const(char)* visualizeStaticCondition(Expression original, Expression instantiated, const Expression[] negatives)
{
    if (!original || !instantiated)
        return null;

    OutBuffer buf;
    uint indent;
    bool unreached; // indicates that we are printing unreached 'and' clauses
    bool marked;    // `unreached` mate

    static void printOr(uint indent, ref OutBuffer buf)
    {
        buf.reserve(indent * 4 + 8);
        foreach (i; 0 .. indent)
            buf.writestring("    ");
        buf.writestring("    or:\n");
    }

    void impl(Expression orig, Expression e, bool inverted, bool orOperand)
    {
        TOK op = orig.op;

        // !(A && B) -> !A || !B
        // !(A || B) -> !A && !B
        if (inverted)
        {
            if (op == TOK.andAnd)
                op = TOK.orOr;
            else if (op == TOK.orOr)
                op = TOK.andAnd;
        }

        if (op == TOK.not)
        {
            NotExp no = cast(NotExp)orig;
            NotExp ne = cast(NotExp)e;
            impl(no.e1, ne.e1, !inverted, orOperand);
        }
        else if (op == TOK.andAnd)
        {
            BinExp bo = cast(BinExp)orig;
            BinExp be = cast(BinExp)e;
            impl(bo.e1, be.e1, inverted, false);
            if (marked)
                unreached = true;
            impl(bo.e2, be.e2, inverted, false);
            if (orOperand)
                unreached = false;
        }
        else if (op == TOK.orOr)
        {
            if (!orOperand) // do not indent A || B || C twice
                indent++;
            BinExp bo = cast(BinExp)orig;
            BinExp be = cast(BinExp)e;
            impl(bo.e1, be.e1, inverted, true);
            printOr(indent, buf);
            impl(bo.e2, be.e2, inverted, true);
            if (!orOperand)
                indent--;
        }
        else if (op == TOK.question)
        {
            // rewrite (A ? B : C) as (A && B || !A && C)
            if (!orOperand)
                indent++;
            CondExp co = cast(CondExp)orig;
            CondExp ce = cast(CondExp)e;
            impl(co.econd, ce.econd, inverted, false);
            if (marked)
                unreached = true;
            impl(co.e1, ce.e1, inverted, false);
            unreached = false;
            printOr(indent, buf);
            impl(co.econd, ce.econd, !inverted, false);
            if (marked)
                unreached = true;
            impl(co.e2, ce.e2, inverted, false);
            unreached = false;
            if (!orOperand)
                indent--;
        }
        else // 'primitive' expression
        {
            buf.reserve(indent * 4 + 4);
            foreach (i; 0 .. indent)
                buf.writestring("    ");

            // find its value; it may be not computed, if there was a short circuit,
            // but we handle this case with `unreached` flag
            bool value = true;
            if (!unreached)
            {
                foreach (fe; negatives)
                {
                    if (fe is e)
                    {
                        value = false;
                        break;
                    }
                }
            }
            // print marks first
            const unsatisfied = inverted ? value : !value;
            marked = false;
            if (unsatisfied && !unreached)
            {
                buf.writestring("  > ");
                marked = true;
            }
            else if (unreached)
                buf.writestring("  - ");
            else
                buf.writestring("    ");
            // then the expression itself
            if (inverted)
                buf.writeByte('!');
            buf.writestring(orig.toChars);
            buf.writenl();
        }
    }

    impl(original, instantiated, false, true);
    return buf.extractString();
}
