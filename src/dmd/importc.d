/**
 * Contains semantic routines specific to ImportC
 *
 * Specification: C11
 *
 * Copyright:   Copyright (C) 2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/importc.d, _importc.d)
 * Documentation:  https://dlang.org/phobos/dmd_importc.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/importc.d
 */

module dmd.importc;

import core.stdc.stdio;

import dmd.dcast;
import dmd.dscope;
import dmd.expression;
import dmd.expressionsem;
import dmd.mtype;

/**************************************
 * C11 does not allow array or function parameters.
 * Hence, adjust those types per C11 6.7.6.3 rules.
 * Params:
 *      t = parameter type to adjust
 *      sc = context
 * Returns:
 *      adjusted type
 */
Type cAdjustParamType(Type t, Scope* sc)
{
    if (!(sc.flags & SCOPE.Cfile))
        return t;

    Type tb = t.toBasetype();

    /* C11 6.7.6.3-7 array of T is converted to pointer to T
     */
    if (auto ta = tb.isTypeDArray())
    {
        t = ta.next.pointerTo();
    }
    else if (auto ts = tb.isTypeSArray())
    {
        t = ts.next.pointerTo();
    }
    /* C11 6.7.6.3-8 function is converted to pointer to function
     */
    else if (tb.isTypeFunction())
    {
        t = tb.pointerTo();
    }
    return t;
}

/***********************************************
 * C11 6.3.2.1-3 Convert expression that is an array of type to a pointer to type.
 * C11 6.3.2.1-4 Convert expression that is a function to a pointer to a function.
 * Params:
 *  e = ImportC expression to possibly convert
 *  sc = context
 * Returns:
 *  converted expression
 */
Expression arrayFuncConv(Expression e, Scope* sc)
{
    //printf("arrayFuncConv() %s\n", e.toChars());
    if (!(sc.flags & SCOPE.Cfile))
        return e;

    auto t = e.type.toBasetype();
    if (auto ta = t.isTypeDArray())
    {
        e = e.castTo(sc, ta.next.pointerTo());
    }
    else if (auto ts = t.isTypeSArray())
    {
        e = e.castTo(sc, ts.next.pointerTo());
    }
    else if (t.isTypeFunction())
    {
        e = e.addressOf();
    }
    else
        return e;
    return e.expressionSemantic(sc);
}

/****************************************
 * C11 6.5.2.1-2
 * Apply C semantics to `E[I]` expression.
 * E1[E2] is lowered to *(E1 + E2)
 * Params:
 *      ae = ArrayExp to run semantics on
 *      sc = context
 * Returns:
 *      Expression if this was a C expression with completed semantic, null if not
 */
Expression carraySemantic(ArrayExp ae, Scope* sc)
{
    if (!(sc.flags & SCOPE.Cfile))
        return null;

    auto e1 = ae.e1.expressionSemantic(sc);

    assert(ae.arguments.length == 1);
    Expression e2 = (*ae.arguments)[0];

    /* CTFE cannot do pointer arithmetic, but it can index arrays.
     * So, rewrite as an IndexExp if we can.
     */
    auto t1 = e1.type.toBasetype();
    if (t1.isTypeDArray() || t1.isTypeSArray())
    {
        e2 = e2.expressionSemantic(sc).arrayFuncConv(sc);
        return new IndexExp(ae.loc, e1, e2).expressionSemantic(sc);
    }

    e1 = e1.arrayFuncConv(sc);   // e1 might still be a function call
    e2 = e2.expressionSemantic(sc);
    auto t2 = e2.type.toBasetype();
    if (t2.isTypeDArray() || t2.isTypeSArray())
    {
        return new IndexExp(ae.loc, e2, e1).expressionSemantic(sc); // swap operands
    }

    e2 = e2.arrayFuncConv(sc);
    auto ep = new PtrExp(ae.loc, new AddExp(ae.loc, e1, e2));
    return ep.expressionSemantic(sc);
}
