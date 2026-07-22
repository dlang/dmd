/**
 * Utilities for Data Flow Analysis.
 *
 * Copyright: Copyright (C) 1999-2026 by The D Language Foundation, All Rights Reserved
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
import dmd.func;
import core.stdc.stdio;

/// Ensure that a function declaration is properly attributed for the fast DFA engine.
ParametersDFAInfo* ensureDFAParameters(FuncDeclaration fd)
{
    if (fd is null || fd.parametersDFAInfo !is null)
        return null;

    TypeFunction tf = fd.type.toTypeFunction;
    fd.parametersDFAInfo = new ParametersDFAInfo;

    const listLength = tf.parameterList.length;

    if (tf.next !is null && tf.next.ty != Tvoid)
        fd.parametersDFAInfo.returnValue.parameterId = -3;

    if (tf.isRef)
        fd.parametersDFAInfo.returnValue.isByRef = true;

    if (fd.vthis !is null)
    {
        fd.parametersDFAInfo.thisPointer.parameterId = -2;

        // This pointer is always by-ref if its a struct
        if (fd.vthis.type.isTypeStruct)
        {
            fd.parametersDFAInfo.thisPointer.isByRef = true;
            fd.parametersDFAInfo.thisPointer.userSupplied.willEscape(-3, tf.isRef
                    ? ParameterDFAInfo.EscapedRelationship.PointerTo
                    : ParameterDFAInfo.EscapedRelationship.ByValue);
        }
        else if (tf.isReturn)
            fd.parametersDFAInfo.thisPointer.userSupplied.willEscape(-3,
                    ParameterDFAInfo.EscapedRelationship.ByValue);
        else if (tf.isScopeQual)
            fd.parametersDFAInfo.thisPointer.userSupplied.escapeIntoNothing = true;
    }

    {
        // Getting the actual number of parameters is all over the place, depending on the stage of compilation.

        const countParams = listLength > 0 ? listLength : (fd.parameters !is null
                ? fd.parameters.length : 0);
        fd.parametersDFAInfo.parameters.length = countParams;
    }

    foreach (i, ref paramDFAInfo; fd.parametersDFAInfo.parameters)
        paramDFAInfo.parameterId = cast(int) i;

    {
        const toModelCount = listLength <= 29 ? listLength : 29;

        foreach (i, param; tf.parameterList)
        {
            if (i > toModelCount)
                break;

            ParameterDFAInfo* paramDFAInfo = &fd.parametersDFAInfo.parameters[i];
            const vd = fd.parameters !is null && fd.parameters.length > i
                ? (*fd.parameters)[i] : null;
            const stc = param.storageClass | (vd !is null ? vd.storage_class : 0);

            if (stc & (STC.ref_ | STC.out_ | STC.autoref))
                paramDFAInfo.isByRef = true;

            if (stc & (STC.return_ | STC.returnScope | STC.returnRef) && (stc & STC.returninferred) == 0)
                paramDFAInfo.userSupplied.willEscape(-3, tf.isRef && paramDFAInfo.isByRef
                        ? ParameterDFAInfo.EscapedRelationship.PointerTo
                        : ParameterDFAInfo.EscapedRelationship.ByValue);
            if ((stc & STC.scope_) && (stc & (STC.scopeinferred | STC.returnScope | STC.returnRef)) == 0)
                paramDFAInfo.userSupplied.escapeIntoNothing = true;
        }
    }

    return fd.parametersDFAInfo;
}

/// Ensure we have access to a description of a given function call, regardless of having a function declaration.
/// paramDFAInfo should have a buffer in init state passed in
void ensureDFAParameter(int id, FuncDeclaration fd, TypeFunction tf,
        ref ParameterDFAInfo* paramDFAInfo)
{
    if (fd !is null)
    {
        assert(fd.parametersDFAInfo !is null);
        if (id == -3)
            paramDFAInfo = &fd.parametersDFAInfo.returnValue;
        else if (id == -2)
            paramDFAInfo = &fd.parametersDFAInfo.thisPointer;
        else if (id == -1)
            return;
        else if (fd.parametersDFAInfo.parameters.length > id)
            paramDFAInfo = &fd.parametersDFAInfo.parameters[id];
        return;
    }

    if (tf !is null && tf.parameterList.parameters !is null
            && tf.parameterList.parameters.length > id)
    {
        const stc = (*tf.parameterList.parameters)[id].storageClass;

        if (stc & (STC.ref_ | STC.out_ | STC.autoref))
            paramDFAInfo.isByRef = true;

        if (stc & (STC.return_ | STC.returnScope | STC.returnRef) && (stc & STC.returninferred) == 0)
            paramDFAInfo.userSupplied.willEscape(-3, tf.isRef && paramDFAInfo.isByRef
                    ? ParameterDFAInfo.EscapedRelationship.PointerTo
                    : ParameterDFAInfo.EscapedRelationship.ByValue);
        if ((stc & STC.scope_) && (stc & (STC.scopeinferred | STC.returnScope | STC.returnRef)) == 0)
            paramDFAInfo.userSupplied.escapeIntoNothing = true;
    }
}

void printDFAParameters(ParametersDFAInfo* params)
{
    if (params is null)
    {
        printf("Params (null)\n");
        return;
    }

    printf("Params:\n");
    if (params.returnValue.parameterId == -3)
        printDFAParameter(&params.returnValue);
    if (params.thisPointer.parameterId == -2)
        printDFAParameter(&params.thisPointer);

    foreach (ref param; params.parameters)
        printDFAParameter(&param);
}

void printDFAParameter(ParameterDFAInfo* param)
{
    if (param is null)
    {
        printf("Param (null)\n");
        return;
    }

    printf("- Param %d, null=%d/%d:%d/%d, by-ref=%d, escapeIntoNothing=%d/%d, escapes=(%lld/%lld ",
            param.parameterId, param.userSupplied.notNullIn,
            param.inferred.notNullIn, param.userSupplied.notNullOut, param.inferred.notNullOut, param.isByRef,
            param.userSupplied.escapeIntoNothing, param.inferred.escapeIntoNothing,
            param.userSupplied.escapesInto, param.inferred.escapesInto);

    ulong escapesIntoUser = param.userSupplied.escapesInto,
        escapeIntoInferred = param.inferred.escapesInto;

    foreach (i; 0 .. 4)
    {
        foreach (j; 0 .. 8)
        {
            printf("%01d", cast(int)(escapesIntoUser & 0x3));
            escapesIntoUser >>= 2;
        }

        printf("/");

        foreach (j; 0 .. 8)
        {
            printf("%01d", cast(int)(escapeIntoInferred & 0x3));
            escapeIntoInferred >>= 2;
        }

        if (i < 3)
            printf(" ");
    }

    printf(")\n");
}

/***********************************************************
 * Checks if a type is capable of being null at runtime.
 *
 * The DFA uses this to determine if a null-check is required
 * for a specific variable.
 *
 * Returns:
 *      true if the type is a pointer, array, class, delegate, etc.
 */
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

/***********************************************************
 * Checks if a type can be evaluated as a boolean (truthy/falsey).
 *
 * Used by the DFA to determine if control flow (like `if` statements)
 * depends on this variable.
 *
 * Returns:
 *      false for types like `void` (noreturn) or `struct` (unless they define opCast),
 *      true for integers, pointers, bools, etc.
 */
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
    case TY.Tvector:
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

enum EqualityArgType
{
    Unknown,
    Struct,
    FloatingPoint,
    StaticArray,
    StaticArrayLHS,
    StaticArrayRHS,
    DynamicArray,
    AssociativeArray,
    Nullable
}

/***********************************************************
 * Classifies how two types are compared for equality at runtime.
 *
 * This mirrors the logic in the compiler backend/glue layer.
 * The DFA needs this to accurately predict if an equality check (`==`)
 * involves simple integer comparison, array comparison, or struct comparison.
 */
/// See_Also: EqualityArgType
EqualityArgType equalityArgTypes(Type lhs, Type rhs)
{
    // This logic originally came from dmd's glue layer.
    // It was copied over and modified so that the DFA is accruate to runtime actions.

    // struct
    // floating point
    // lhs && rhs    static, dyamic array
    // lhs && rhs    associative array
    // otherwise integral

    if (lhs.ty == Tstruct)
        return EqualityArgType.Struct;
    else if (lhs.isFloating)
        return EqualityArgType.FloatingPoint;

    if (rhs is null)
        rhs = lhs; // Assume rhs is similar to lhs

    const lhsSArray = lhs.isTypeSArray !is null, rhsSArray = rhs.isTypeSArray !is null;
    if (lhsSArray && rhsSArray)
        return EqualityArgType.StaticArray;
    else if (lhsSArray)
        return EqualityArgType.StaticArrayLHS;
    else if (rhsSArray)
        return EqualityArgType.StaticArrayRHS;

    if (lhs.isTypeDArray || rhs.isTypeDArray)
        return EqualityArgType.DynamicArray;
    else if (lhs.ty == Taarray && rhs.ty == Taarray)
        return EqualityArgType.AssociativeArray;
    else if (isTypeNullable(lhs))
        return EqualityArgType.Nullable;
    else
        return EqualityArgType.Unknown;
}
