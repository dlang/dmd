/*
https://github.com/dlang/dmd/issues/18670
Default arguments bypass most attributes check (pure, @safe, @nogc)

TEST_OUTPUT:
---
fail_compilation/test18670.d(23): Deprecation: `pure` function `test18670.testPure` calling impure function `test18670.impure` in default argument
fail_compilation/test18670.d(28): Deprecation: `pure` function `test18670.testPure2` accessing mutable static data `globalVar` in default argument
fail_compilation/test18670.d(33): Deprecation: `@safe` function `test18670.testSafe` calling `@system` function `test18670.unsafe` in default argument
fail_compilation/test18670.d(38): Error: indexing pointer `globalPtr` is not allowed in a `@safe` function
fail_compilation/test18670.d(43): Deprecation: `@nogc` function `test18670.testNogc` calling non-@nogc function `test18670.gcAllocate` in default argument
fail_compilation/test18670.d(47): Error: allocating with `new` causes a GC allocation in `@nogc` function `testNogc2`
fail_compilation/test18670.d(53): Error: function `test18670.throwing` is not `nothrow`
fail_compilation/test18670.d(53): Error: function `test18670.testNothrow` may throw but is marked as `nothrow`
fail_compilation/test18670.d(56): Error: `object.Exception` is thrown but not caught
fail_compilation/test18670.d(57): Error: function `test18670.testNothrow2` may throw but is marked as `nothrow`
---
*/


// pure call
int impure() => 0;
void defaultImpure(int x = impure()) pure {}
void testPure() pure => defaultImpure();

// pure direct
int globalVar = 7;
void defaultImpure2(int x = globalVar) pure {}
void testPure2() pure => defaultImpure2();

// @safe call
int unsafe() @system => 0;
void defaultUnsafe(int x = unsafe()) @safe {}
void testSafe() @safe => defaultUnsafe();

// @safe direct
int* globalPtr;
void defaultUnsafe2(int x = globalPtr[1]) @safe {}
void testSafe2() @safe => defaultUnsafe2();

// @nogc call
int gcAllocate() => *new int(3);
void defaultGc(int x = gcAllocate()) @nogc {}
void testNogc() @nogc => defaultGc();

// @nogc direct
void defaultGc2(int x = *new int(3)) @nogc {}
void testNogc2() @nogc => defaultGc2();

// nothrow call
int throwing() => throw Exception.init;
void defaultThrowing(int x = throwing()) nothrow {}
void testNothrow() nothrow => defaultThrowing();

// nothrow direct
void defaultThrowing2(int x = throw new Exception("")) nothrow {}
void testNothrow2() nothrow => defaultThrowing2();
