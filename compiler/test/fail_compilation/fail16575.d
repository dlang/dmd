// https://issues.dlang.org/show_bug.cgi?id=16575
/*
REQUIRED_ARGS: -m64
TEST_OUTPUT:
---
fail_compilation/fail16575.d(75): Error: function `fail16575.immNull` cannot have parameter of type `immutable(typeof(null))*` because its linkage is `extern(C++)`
extern(C++) void immNull(immutable(typeof(null))* a) {}
                 ^
fail_compilation/fail16575.d(76): Error: function `fail16575.shaNull` cannot have parameter of type `shared(typeof(null))*` because its linkage is `extern(C++)`
extern(C++) void shaNull(shared(typeof(null))* a) {}
                 ^
fail_compilation/fail16575.d(78): Error: function `fail16575.immNoReturn` cannot have parameter of type `immutable(noreturn)*` because its linkage is `extern(C++)`
extern(C++) void immNoReturn(immutable(typeof(*null))* a) {}
                 ^
fail_compilation/fail16575.d(79): Error: function `fail16575.shaNoReturn` cannot have parameter of type `shared(noreturn)*` because its linkage is `extern(C++)`
extern(C++) void shaNoReturn(shared(typeof(*null))* a) {}
                 ^
fail_compilation/fail16575.d(81): Error: function `fail16575.immBasic` cannot have parameter of type `immutable(int)*` because its linkage is `extern(C++)`
extern(C++) void immBasic(immutable(int)* a) {}
                 ^
fail_compilation/fail16575.d(82): Error: function `fail16575.shaBasic` cannot have parameter of type `shared(int)*` because its linkage is `extern(C++)`
extern(C++) void shaBasic(shared(int)* a) {}
                 ^
fail_compilation/fail16575.d(84): Error: function `fail16575.immVector` cannot have parameter of type `immutable(__vector(long[2]))*` because its linkage is `extern(C++)`
extern(C++) void immVector(immutable(__vector(long[2]))* a) {}
                 ^
fail_compilation/fail16575.d(85): Error: function `fail16575.shaVector` cannot have parameter of type `shared(__vector(long[2]))*` because its linkage is `extern(C++)`
extern(C++) void shaVector(shared(__vector(long[2]))* a) {}
                 ^
fail_compilation/fail16575.d(87): Error: function `fail16575.immSArray` cannot have parameter of type `immutable(long[2])` because its linkage is `extern(C++)`
extern(C++) void immSArray(immutable(long[2]) a) {}
                 ^
fail_compilation/fail16575.d(87):        perhaps use a `long*` type instead
fail_compilation/fail16575.d(88): Error: function `fail16575.shaSArray` cannot have parameter of type `shared(long[2])` because its linkage is `extern(C++)`
extern(C++) void shaSArray(shared(long[2]) a) {}
                 ^
fail_compilation/fail16575.d(88):        perhaps use a `long*` type instead
fail_compilation/fail16575.d(90): Error: function `fail16575.immPointer` cannot have parameter of type `immutable(int*)` because its linkage is `extern(C++)`
extern(C++) void immPointer(immutable(int*) a) {}
                 ^
fail_compilation/fail16575.d(91): Error: function `fail16575.shaPointer` cannot have parameter of type `shared(int*)` because its linkage is `extern(C++)`
extern(C++) void shaPointer(shared(int*) a) {}
                 ^
fail_compilation/fail16575.d(94): Error: function `fail16575.immStruct` cannot have parameter of type `immutable(SPP)*` because its linkage is `extern(C++)`
extern(C++) void immStruct(immutable(SPP)* a) {}
                 ^
fail_compilation/fail16575.d(95): Error: function `fail16575.shaStruct` cannot have parameter of type `shared(SPP)*` because its linkage is `extern(C++)`
extern(C++) void shaStruct(shared(SPP)* a) {}
                 ^
fail_compilation/fail16575.d(98): Error: function `fail16575.immClass` cannot have parameter of type `immutable(CPP)` because its linkage is `extern(C++)`
extern(C++) void immClass(immutable CPP a) {}
                 ^
fail_compilation/fail16575.d(99): Error: function `fail16575.shaClass` cannot have parameter of type `shared(CPP)` because its linkage is `extern(C++)`
extern(C++) void shaClass(shared CPP a) {}
                 ^
fail_compilation/fail16575.d(102): Error: function `fail16575.immEnum` cannot have parameter of type `immutable(EPP)*` because its linkage is `extern(C++)`
extern(C++) void immEnum(immutable(EPP)* a) {}
                 ^
fail_compilation/fail16575.d(103): Error: function `fail16575.shaEnum` cannot have parameter of type `shared(EPP)*` because its linkage is `extern(C++)`
extern(C++) void shaEnum(shared(EPP)* a) {}
                 ^
fail_compilation/fail16575.d(105): Error: function `fail16575.typeDArray` cannot have parameter of type `int[]` because its linkage is `extern(C++)`
extern(C++) void typeDArray(int[] a) {}
                 ^
fail_compilation/fail16575.d(106): Error: function `fail16575.typeAArray` cannot have parameter of type `int[int]` because its linkage is `extern(C++)`
extern(C++) void typeAArray(int[int] a) {}
                 ^
fail_compilation/fail16575.d(107): Error: function `fail16575.typeDelegate` cannot have parameter of type `extern (C++) int delegate()` because its linkage is `extern(C++)`
extern(C++) void typeDelegate(int delegate() a) {}
                 ^
---
*/

// Line 10 starts here
extern(C++) void immNull(immutable(typeof(null))* a) {}
extern(C++) void shaNull(shared(typeof(null))* a) {}
// Line 20 starts here
extern(C++) void immNoReturn(immutable(typeof(*null))* a) {}
extern(C++) void shaNoReturn(shared(typeof(*null))* a) {}
// Line 30 starts here
extern(C++) void immBasic(immutable(int)* a) {}
extern(C++) void shaBasic(shared(int)* a) {}
// Line 40 starts here
extern(C++) void immVector(immutable(__vector(long[2]))* a) {}
extern(C++) void shaVector(shared(__vector(long[2]))* a) {}
// Line 50 starts here
extern(C++) void immSArray(immutable(long[2]) a) {}
extern(C++) void shaSArray(shared(long[2]) a) {}
// Line 60 starts here
extern(C++) void immPointer(immutable(int*) a) {}
extern(C++) void shaPointer(shared(int*) a) {}
// Line 70 starts here
extern(C++) struct SPP {}
extern(C++) void immStruct(immutable(SPP)* a) {}
extern(C++) void shaStruct(shared(SPP)* a) {}
// Line 80 starts here
extern(C++) class CPP {}
extern(C++) void immClass(immutable CPP a) {}
extern(C++) void shaClass(shared CPP a) {}
// Line 90 starts here
extern(C++) enum EPP {a}
extern(C++) void immEnum(immutable(EPP)* a) {}
extern(C++) void shaEnum(shared(EPP)* a) {}
// Line 100 starts here
extern(C++) void typeDArray(int[] a) {}
extern(C++) void typeAArray(int[int] a) {}
extern(C++) void typeDelegate(int delegate() a) {}
