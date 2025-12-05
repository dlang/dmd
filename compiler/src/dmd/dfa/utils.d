/**
 * Utilities for Data Flow Analysis.
 *
 * Copyright: Copyright (C) 1999-2025 by The D Language Foundation, All Rights Reserved
 * Authors:   $(LINK2 https://cattermole.co.nz, Richard (Rikki) Andrew Cattermole)
 * License:   $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/dfa/utils.d, dfa/utils.d)
 * Documentation: https://dlang.org/phobos/dmd_dfa_utils.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/dfa/utils.d
 */
module dmd.dfa.utils;
import dmd.tokens;
import dmd.astenums;
import dmd.mtype;
import dmd.visitor;
import dmd.identifier;
import dmd.expression;
import dmd.typesem : isFloating;

bool isTypeNullable(Type type)
{
    if (type is null)
        return false;

    switch (type.ty)
    {
    case TY.Tarray, TY.Taarray, TY.Tpointer, TY.Treference, TY.Tfunction,
            TY.Tclass, TY.Tdelegate:
            return true;

    default:
        return false;
    }
}

bool isTypeTruthy(Type type)
{
    if (type is null)
        return false;

    switch (type.ty)
    {
    case TY.Tident:
    case TY.Terror:
    case TY.Ttypeof:
    case TY.Ttuple:
    case TY.Treturn:
    case TY.Ttraits:
    case TY.Tmixin:
    case TY.Tnoreturn:
    case TY.Ttag:
    case TY.Tsarray:
    case TY.Tstruct:
        return false;

    default:
        return true;
    }
}

bool isIndexContextAA(IndexExp ie)
{
    if (ie is null || ie.e1 is null || ie.e1.type is null)
        return false;
    return ie.e1.type.isTypeAArray !is null;
}

int concatNullableResult(Type lhs, Type rhs)
{
    // T[] ~ T[]
    // T[] ~ T
    // T ~ T[]
    // T ~ T

    if (lhs.isStaticOrDynamicArray)
    {
        if (rhs.isStaticOrDynamicArray)
            return 1; // Depends on lhs and rhs
        return 2; // non-null
    }
    else if (rhs.isStaticOrDynamicArray)
        return 2;

    return 0; // Unknown
}

int equalityArgTypes(Type lhs, Type rhs)
{
    // struct
    // floating point
    // lhs && rhs    static, dyamic array
    // lhs && rhs    associative array
    // otherwise integral

    if (lhs.ty == Tstruct)
        return 1;
    else if (lhs.isFloating)
        return 2;

    if (rhs is null)
        rhs = lhs; // Assume rhs is similar to lhs

    const lhsSArray = lhs.isTypeSArray !is null, rhsSArray = rhs.isTypeSArray !is null;
    if (lhsSArray && rhsSArray)
        return 3;
    else if (lhsSArray)
        return 4;
    else if (rhsSArray)
        return 5;

    if (lhs.isTypeDArray || rhs.isTypeDArray)
        return 6;
    else if (lhs.ty == Taarray && rhs.ty == Taarray)
        return 7;
    else if (isTypeNullable(lhs))
        return 8;
    else
        return 0;
}
