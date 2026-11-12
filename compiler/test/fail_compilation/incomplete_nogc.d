/*
TEST_OUTPUT:
---
fail_compilation/incomplete_nogc.d(103): Error: `@nogc` function `incomplete_nogc.test` cannot call non-@nogc function `incomplete_nogc.a!()`
fail_compilation/incomplete_nogc.d(101):        `@nogc` inference for `incomplete_nogc.a!()` could not complete because its attributes were queried while its body was still being analyzed
fail_compilation/incomplete_nogc.d(107): Error: `@nogc` function `incomplete_nogc.testExternal` cannot call non-@nogc function `incomplete_nogc.externalFunction`
fail_compilation/incomplete_nogc.d(114): Error: `@nogc` function `incomplete_nogc.testEffect` cannot call non-@nogc function `incomplete_nogc.effectA!()`
fail_compilation/incomplete_nogc.d(110):        `@nogc` inference for `incomplete_nogc.effectA!()` could not complete because its attributes were queried while its body was still being analyzed
---
*/
module incomplete_nogc;
#line 101
int a()(int n) { return n ? b(n - 1) : 0; }
int b()(int n) { return n ? a(n - 1) : 0; }
void test() @nogc { a(3); }

// A declaration without inference must not acquire an incomplete-inference note.
void externalFunction();
void testExternal() @nogc { externalFunction(); }

// The note describes the query even when a later operation allocates.
int effectA()(int n) { return n ? effectB(n - 1) : 0; }
int effectB()(int n) { auto result = n ? effectA(n - 1) : 0; return result + *new int; }

#line 114
void testEffect() @nogc { effectA(3); }
