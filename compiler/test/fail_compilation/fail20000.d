/*
TEST_OUTPUT:
---
fail_compilation/fail20000.d(61): Error: cast from `fail20000.DClass` to `fail20000.CppClass` not allowed in safe code
bool isCppClass(DClass a) @safe { return cast(CppClass) a !is null; }
                                         ^
fail_compilation/fail20000.d(61):        Source object type is incompatible with target type
fail_compilation/fail20000.d(62): Error: cast from `fail20000.DInterface` to `fail20000.CppClass` not allowed in safe code
bool isCppClass(DInterface a) @safe { return cast(CppClass) a !is null; }
                                             ^
fail_compilation/fail20000.d(62):        Source object type is incompatible with target type
fail_compilation/fail20000.d(63): Error: cast from `fail20000.CppClass2` to `fail20000.CppClass` not allowed in safe code
bool isCppClass(CppClass2 a) @safe { return cast(CppClass) a !is null; }
                                            ^
fail_compilation/fail20000.d(63):        Source object type is incompatible with target type
fail_compilation/fail20000.d(64): Error: cast from `fail20000.CppInterface2` to `fail20000.CppClass` not allowed in safe code
bool isCppClass(CppInterface2 a) @safe { return cast(CppClass) a !is null; }
                                                ^
fail_compilation/fail20000.d(64):        Source object type is incompatible with target type
fail_compilation/fail20000.d(66): Error: cast from `fail20000.DClass` to `fail20000.CppInterface` not allowed in safe code
bool isCppInterface(DClass a) @safe { return cast(CppInterface) a !is null; }
                                             ^
fail_compilation/fail20000.d(66):        Source object type is incompatible with target type
fail_compilation/fail20000.d(67): Error: cast from `fail20000.DInterface` to `fail20000.CppInterface` not allowed in safe code
bool isCppInterface(DInterface a) @safe { return cast(CppInterface) a !is null; }
                                                 ^
fail_compilation/fail20000.d(67):        Source object type is incompatible with target type
fail_compilation/fail20000.d(68): Error: cast from `fail20000.CppClass2` to `fail20000.CppInterface` not allowed in safe code
bool isCppInterface(CppClass2 a) @safe { return cast(CppInterface) a !is null; }
                                                ^
fail_compilation/fail20000.d(68):        Source object type is incompatible with target type
fail_compilation/fail20000.d(69): Error: cast from `fail20000.CppInterface2` to `fail20000.CppInterface` not allowed in safe code
bool isCppInterface(CppInterface2 a) @safe { return cast(CppInterface) a !is null; }
                                                    ^
fail_compilation/fail20000.d(69):        Source object type is incompatible with target type
fail_compilation/fail20000.d(71): Error: cast from `fail20000.CppClass` to `fail20000.DClass` not allowed in safe code
bool isDClass(CppClass a) @safe { return cast(DClass) a !is null; }
                                         ^
fail_compilation/fail20000.d(71):        Source object type is incompatible with target type
fail_compilation/fail20000.d(72): Error: cast from `fail20000.CppInterface` to `fail20000.DClass` not allowed in safe code
bool isDClass(CppInterface a) @safe { return cast(DClass) a !is null; }
                                             ^
fail_compilation/fail20000.d(72):        Source object type is incompatible with target type
fail_compilation/fail20000.d(74): Error: cast from `fail20000.CppClass` to `fail20000.DInterface` not allowed in safe code
bool isDInterface(CppClass a) @safe { return cast(DInterface) a !is null; }
                                             ^
fail_compilation/fail20000.d(74):        Source object type is incompatible with target type
fail_compilation/fail20000.d(75): Error: cast from `fail20000.CppInterface` to `fail20000.DInterface` not allowed in safe code
bool isDInterface(CppInterface a) @safe { return cast(DInterface) a !is null; }
                                                 ^
fail_compilation/fail20000.d(75):        Source object type is incompatible with target type
---
*/
extern(C++) class CppClass { int a; }
extern(C++) class CppClass2 { void* a; }
extern(C++) interface CppInterface { int b(); }
extern(C++) interface CppInterface2 { void* b(); }
class DClass { int c; }
interface DInterface { int d(); }

bool isCppClass(DClass a) @safe { return cast(CppClass) a !is null; }
bool isCppClass(DInterface a) @safe { return cast(CppClass) a !is null; }
bool isCppClass(CppClass2 a) @safe { return cast(CppClass) a !is null; }
bool isCppClass(CppInterface2 a) @safe { return cast(CppClass) a !is null; }

bool isCppInterface(DClass a) @safe { return cast(CppInterface) a !is null; }
bool isCppInterface(DInterface a) @safe { return cast(CppInterface) a !is null; }
bool isCppInterface(CppClass2 a) @safe { return cast(CppInterface) a !is null; }
bool isCppInterface(CppInterface2 a) @safe { return cast(CppInterface) a !is null; }

bool isDClass(CppClass a) @safe { return cast(DClass) a !is null; }
bool isDClass(CppInterface a) @safe { return cast(DClass) a !is null; }

bool isDInterface(CppClass a) @safe { return cast(DInterface) a !is null; }
bool isDInterface(CppInterface a) @safe { return cast(DInterface) a !is null; }
