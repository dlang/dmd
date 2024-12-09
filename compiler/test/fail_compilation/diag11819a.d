/*
TEST_OUTPUT:
---
fail_compilation/diag11819a.d(72): Error: unrecognized trait `DoesNotExist`
    if (__traits(DoesNotExist)) { }
        ^
fail_compilation/diag11819a.d(73): Error: unrecognized trait `IsAbstractClass`, did you mean `isAbstractClass`?
    if (__traits(IsAbstractClass)) { }
        ^
fail_compilation/diag11819a.d(74): Error: unrecognized trait `IsArithmetic`, did you mean `isArithmetic`?
    if (__traits(IsArithmetic)) { }
        ^
fail_compilation/diag11819a.d(75): Error: unrecognized trait `IsAssociativeArray`, did you mean `isAssociativeArray`?
    if (__traits(IsAssociativeArray)) { }
        ^
fail_compilation/diag11819a.d(76): Error: unrecognized trait `IsFinalClass`, did you mean `isFinalClass`?
    if (__traits(IsFinalClass)) { }
        ^
fail_compilation/diag11819a.d(77): Error: unrecognized trait `IsPOD`, did you mean `isPOD`?
    if (__traits(IsPOD)) { }
        ^
fail_compilation/diag11819a.d(78): Error: unrecognized trait `IsNested`, did you mean `isNested`?
    if (__traits(IsNested)) { }
        ^
fail_compilation/diag11819a.d(79): Error: unrecognized trait `IsFloating`, did you mean `isFloating`?
    if (__traits(IsFloating)) { }
        ^
fail_compilation/diag11819a.d(80): Error: unrecognized trait `IsIntegral`, did you mean `isIntegral`?
    if (__traits(IsIntegral)) { }
        ^
fail_compilation/diag11819a.d(81): Error: unrecognized trait `IsScalar`, did you mean `isScalar`?
    if (__traits(IsScalar)) { }
        ^
fail_compilation/diag11819a.d(82): Error: unrecognized trait `IsStaticArray`, did you mean `isStaticArray`?
    if (__traits(IsStaticArray)) { }
        ^
fail_compilation/diag11819a.d(83): Error: unrecognized trait `IsUnsigned`, did you mean `isUnsigned`?
    if (__traits(IsUnsigned)) { }
        ^
fail_compilation/diag11819a.d(84): Error: unrecognized trait `IsVirtualFunction`, did you mean `isVirtualFunction`?
    if (__traits(IsVirtualFunction)) { }
        ^
fail_compilation/diag11819a.d(85): Error: unrecognized trait `IsVirtualMethod`, did you mean `isVirtualMethod`?
    if (__traits(IsVirtualMethod)) { }
        ^
fail_compilation/diag11819a.d(86): Error: unrecognized trait `IsAbstractFunction`, did you mean `isAbstractFunction`?
    if (__traits(IsAbstractFunction)) { }
        ^
fail_compilation/diag11819a.d(87): Error: unrecognized trait `IsFinalFunction`, did you mean `isFinalFunction`?
    if (__traits(IsFinalFunction)) { }
        ^
fail_compilation/diag11819a.d(88): Error: unrecognized trait `IsOverrideFunction`, did you mean `isOverrideFunction`?
    if (__traits(IsOverrideFunction)) { }
        ^
fail_compilation/diag11819a.d(89): Error: unrecognized trait `IsStaticFunction`, did you mean `isStaticFunction`?
    if (__traits(IsStaticFunction)) { }
        ^
fail_compilation/diag11819a.d(90): Error: unrecognized trait `IsRef`, did you mean `isRef`?
    if (__traits(IsRef)) { }
        ^
fail_compilation/diag11819a.d(91): Error: unrecognized trait `IsOut`, did you mean `isOut`?
    if (__traits(IsOut)) { }
        ^
fail_compilation/diag11819a.d(92): Error: unrecognized trait `IsLazy`, did you mean `isLazy`?
    if (__traits(IsLazy)) { }
        ^
---
*/

void main()
{
    if (__traits(DoesNotExist)) { }
    if (__traits(IsAbstractClass)) { }
    if (__traits(IsArithmetic)) { }
    if (__traits(IsAssociativeArray)) { }
    if (__traits(IsFinalClass)) { }
    if (__traits(IsPOD)) { }
    if (__traits(IsNested)) { }
    if (__traits(IsFloating)) { }
    if (__traits(IsIntegral)) { }
    if (__traits(IsScalar)) { }
    if (__traits(IsStaticArray)) { }
    if (__traits(IsUnsigned)) { }
    if (__traits(IsVirtualFunction)) { }
    if (__traits(IsVirtualMethod)) { }
    if (__traits(IsAbstractFunction)) { }
    if (__traits(IsFinalFunction)) { }
    if (__traits(IsOverrideFunction)) { }
    if (__traits(IsStaticFunction)) { }
    if (__traits(IsRef)) { }
    if (__traits(IsOut)) { }
    if (__traits(IsLazy)) { }
}
