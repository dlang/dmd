module fail10227;

/*
TEST_OUTPUT:
---
fail_compilation/imports/fail10277.d(3): Error: class `TypeInfo` only one module can define this reserved class name
fail_compilation/imports/fail10277.d(4): Error: class `TypeInfo_Class` only one module can define this reserved class name
fail_compilation/imports/fail10277.d(5): Error: class `TypeInfo_Interface` only one module can define this reserved class name
fail_compilation/imports/fail10277.d(6): Error: class `TypeInfo_Struct` only one module can define this reserved class name
fail_compilation/imports/fail10277.d(8): Error: class `TypeInfo_Pointer` only one module can define this reserved class name
fail_compilation/imports/fail10277.d(9): Error: class `TypeInfo_Array` only one module can define this reserved class name
fail_compilation/imports/fail10277.d(10): Error: class `TypeInfo_AssociativeArray` only one module can define this reserved class name
fail_compilation/imports/fail10277.d(11): Error: class `TypeInfo_Enum` only one module can define this reserved class name
fail_compilation/imports/fail10277.d(12): Error: class `TypeInfo_Function` only one module can define this reserved class name
fail_compilation/imports/fail10277.d(13): Error: class `TypeInfo_Delegate` only one module can define this reserved class name
fail_compilation/imports/fail10277.d(14): Error: class `TypeInfo_Tuple` only one module can define this reserved class name
fail_compilation/imports/fail10277.d(15): Error: class `TypeInfo_Const` only one module can define this reserved class name
fail_compilation/imports/fail10277.d(16): Error: class `TypeInfo_Invariant` only one module can define this reserved class name
fail_compilation/imports/fail10277.d(17): Error: class `TypeInfo_Shared` only one module can define this reserved class name
fail_compilation/imports/fail10277.d(18): Error: class `TypeInfo_Inout` only one module can define this reserved class name
fail_compilation/imports/fail10277.d(19): Error: class `TypeInfo_Vector` only one module can define this reserved class name
fail_compilation/imports/fail10277.d(20): Error: class `Object` only one module can define this reserved class name
fail_compilation/imports/fail10277.d(21): Error: class `Throwable` only one module can define this reserved class name
fail_compilation/imports/fail10277.d(22): Error: class `Exception` only one module can define this reserved class name
fail_compilation/imports/fail10277.d(23): Error: class `Error` only one module can define this reserved class name
---
*/

import imports.fail10277;
