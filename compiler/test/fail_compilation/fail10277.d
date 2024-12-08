// EXTRA_FILES: imports/fail10277.d
module fail10227;
/*
TEST_OUTPUT:
---
fail_compilation/imports/fail10277.d(3): Error: class `TypeInfo` only object.d can define this reserved class name
class TypeInfo { }
^
fail_compilation/imports/fail10277.d(4): Error: class `TypeInfo_Class` only object.d can define this reserved class name
class TypeInfo_Class { }
^
fail_compilation/imports/fail10277.d(5): Error: class `TypeInfo_Interface` only object.d can define this reserved class name
class TypeInfo_Interface { }
^
fail_compilation/imports/fail10277.d(6): Error: class `TypeInfo_Struct` only object.d can define this reserved class name
class TypeInfo_Struct { }
^
fail_compilation/imports/fail10277.d(8): Error: class `TypeInfo_Pointer` only object.d can define this reserved class name
class TypeInfo_Pointer { }
^
fail_compilation/imports/fail10277.d(9): Error: class `TypeInfo_Array` only object.d can define this reserved class name
class TypeInfo_Array { }
^
fail_compilation/imports/fail10277.d(10): Error: class `TypeInfo_AssociativeArray` only object.d can define this reserved class name
class TypeInfo_AssociativeArray { }
^
fail_compilation/imports/fail10277.d(11): Error: class `TypeInfo_Enum` only object.d can define this reserved class name
class TypeInfo_Enum { }
^
fail_compilation/imports/fail10277.d(12): Error: class `TypeInfo_Function` only object.d can define this reserved class name
class TypeInfo_Function { }
^
fail_compilation/imports/fail10277.d(13): Error: class `TypeInfo_Delegate` only object.d can define this reserved class name
class TypeInfo_Delegate { }
^
fail_compilation/imports/fail10277.d(14): Error: class `TypeInfo_Tuple` only object.d can define this reserved class name
class TypeInfo_Tuple { }
^
fail_compilation/imports/fail10277.d(15): Error: class `TypeInfo_Const` only object.d can define this reserved class name
class TypeInfo_Const { }
^
fail_compilation/imports/fail10277.d(16): Error: class `TypeInfo_Invariant` only object.d can define this reserved class name
class TypeInfo_Invariant { }
^
fail_compilation/imports/fail10277.d(17): Error: class `TypeInfo_Shared` only object.d can define this reserved class name
class TypeInfo_Shared { }
^
fail_compilation/imports/fail10277.d(18): Error: class `TypeInfo_Inout` only object.d can define this reserved class name
class TypeInfo_Inout { }
^
fail_compilation/imports/fail10277.d(19): Error: class `TypeInfo_Vector` only object.d can define this reserved class name
class TypeInfo_Vector { }
^
fail_compilation/imports/fail10277.d(20): Error: class `Object` only object.d can define this reserved class name
class Object { }
^
fail_compilation/imports/fail10277.d(21): Error: class `Throwable` only object.d can define this reserved class name
class Throwable { }
^
fail_compilation/imports/fail10277.d(22): Error: class `Exception` only object.d can define this reserved class name
class Exception { }
^
fail_compilation/imports/fail10277.d(23): Error: class `Error` only object.d can define this reserved class name
class Error { }
^
---
*/

import imports.fail10277;
