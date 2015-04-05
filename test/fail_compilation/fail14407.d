import imports.a14407;

/*
TEST_OUTPUT:
---
fail_compilation/fail14407.d(22): Deprecation: class imports.a14407.C is deprecated
fail_compilation/fail14407.d(22): Deprecation: allocator imports.a14407.C.new is deprecated
fail_compilation/fail14407.d(22): Error: pure function 'fail14407.testC' cannot call impure function 'imports.a14407.C.new'
fail_compilation/fail14407.d(22): Error: safe function 'fail14407.testC' cannot call system function 'imports.a14407.C.new'
fail_compilation/fail14407.d(22): Error: @nogc function 'fail14407.testC' cannot call non-@nogc function 'imports.a14407.C.new'
fail_compilation/fail14407.d(22): Error: class imports.a14407.C member new is not accessible from module fail14407
fail_compilation/fail14407.d(22): Error: pure function 'fail14407.testC' cannot call impure function 'imports.a14407.C.this'
fail_compilation/fail14407.d(22): Error: safe function 'fail14407.testC' cannot call system function 'imports.a14407.C.this'
fail_compilation/fail14407.d(22): Error: @nogc function 'fail14407.testC' cannot call non-@nogc function 'imports.a14407.C.this'
fail_compilation/fail14407.d(22): Error: class imports.a14407.C member this is not accessible from module fail14407
fail_compilation/fail14407.d(22): Error: constructor this is not nothrow
fail_compilation/fail14407.d(20): Error: function 'fail14407.testC' is nothrow yet may throw
---
*/
void testC() pure nothrow @safe @nogc
{
    new("arg") C(0);
}

/*
TEST_OUTPUT:
---
fail_compilation/fail14407.d(44): Deprecation: struct imports.a14407.S is deprecated
fail_compilation/fail14407.d(44): Deprecation: allocator imports.a14407.S.new is deprecated
fail_compilation/fail14407.d(44): Error: pure function 'fail14407.testS' cannot call impure function 'imports.a14407.S.new'
fail_compilation/fail14407.d(44): Error: safe function 'fail14407.testS' cannot call system function 'imports.a14407.S.new'
fail_compilation/fail14407.d(44): Error: @nogc function 'fail14407.testS' cannot call non-@nogc function 'imports.a14407.S.new'
fail_compilation/fail14407.d(44): Error: struct imports.a14407.S member new is not accessible from module fail14407
fail_compilation/fail14407.d(44): Error: pure function 'fail14407.testS' cannot call impure function 'imports.a14407.S.this'
fail_compilation/fail14407.d(44): Error: safe function 'fail14407.testS' cannot call system function 'imports.a14407.S.this'
fail_compilation/fail14407.d(44): Error: @nogc function 'fail14407.testS' cannot call non-@nogc function 'imports.a14407.S.this'
fail_compilation/fail14407.d(44): Error: struct imports.a14407.S member this is not accessible from module fail14407
fail_compilation/fail14407.d(44): Error: constructor this is not nothrow
fail_compilation/fail14407.d(42): Error: function 'fail14407.testS' is nothrow yet may throw
---
*/
void testS() pure nothrow @safe @nogc
{
    new("arg") S(0);
}
