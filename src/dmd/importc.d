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
