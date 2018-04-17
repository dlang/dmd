import imports.a14407;

/*
TEST_OUTPUT:
---
fail_compilation/imports/a14407.d(5): Deprecation: class allocators have been deprecated, consider moving the allocation strategy outside of the class
fail_compilation/imports/a14407.d(14): Deprecation: class allocators have been deprecated, consider moving the allocation strategy outside of the class
fail_compilation/fail14407.d(25): Deprecation: class `imports.a14407.C` is deprecated
fail_compilation/fail14407.d(25): Deprecation: allocator `imports.a14407.C.new` is deprecated
fail_compilation/fail14407.d(25): Error: `pure` function `fail14407.testC` cannot call impure allocator `imports.a14407.C.new`
fail_compilation/fail14407.d(25): Error: `@safe` function `fail14407.testC` cannot call `@system` allocator `imports.a14407.C.new`
fail_compilation/fail14407.d(25): Error: `@nogc` function `fail14407.testC` cannot call non-@nogc allocator `imports.a14407.C.new`
fail_compilation/fail14407.d(25): Error: class `imports.a14407.C` member `new` is not accessible
fail_compilation/fail14407.d(25): Error: `pure` function `fail14407.testC` cannot call impure constructor `imports.a14407.C.this`
fail_compilation/fail14407.d(25): Error: `@safe` function `fail14407.testC` cannot call `@system` constructor `imports.a14407.C.this`
fail_compilation/fail14407.d(25): Error: `@nogc` function `fail14407.testC` cannot call non-@nogc constructor `imports.a14407.C.this`
fail_compilation/fail14407.d(25): Error: class `imports.a14407.C` member `this` is not accessible
fail_compilation/fail14407.d(25): Error: allocator `imports.a14407.C.new` is not `nothrow`
fail_compilation/fail14407.d(25): Error: constructor `imports.a14407.C.this` is not `nothrow`
fail_compilation/fail14407.d(23): Error: `nothrow` function `fail14407.testC` may throw
---
*/
void testC() pure nothrow @safe @nogc
{
    new("arg") C(0);
}

/*
TEST_OUTPUT:
---
fail_compilation/fail14407.d(48): Deprecation: struct `imports.a14407.S` is deprecated
fail_compilation/fail14407.d(48): Deprecation: allocator `imports.a14407.S.new` is deprecated
fail_compilation/fail14407.d(48): Error: `pure` function `fail14407.testS` cannot call impure allocator `imports.a14407.S.new`
fail_compilation/fail14407.d(48): Error: `@safe` function `fail14407.testS` cannot call `@system` allocator `imports.a14407.S.new`
fail_compilation/fail14407.d(48): Error: `@nogc` function `fail14407.testS` cannot call non-@nogc allocator `imports.a14407.S.new`
fail_compilation/fail14407.d(48): Error: struct `imports.a14407.S` member `new` is not accessible
fail_compilation/fail14407.d(48): Error: `pure` function `fail14407.testS` cannot call impure constructor `imports.a14407.S.this`
fail_compilation/fail14407.d(48): Error: `@safe` function `fail14407.testS` cannot call `@system` constructor `imports.a14407.S.this`
fail_compilation/fail14407.d(48): Error: `@nogc` function `fail14407.testS` cannot call non-@nogc constructor `imports.a14407.S.this`
fail_compilation/fail14407.d(48): Error: struct `imports.a14407.S` member `this` is not accessible
fail_compilation/fail14407.d(48): Error: allocator `imports.a14407.S.new` is not `nothrow`
fail_compilation/fail14407.d(48): Error: constructor `imports.a14407.S.this` is not `nothrow`
fail_compilation/fail14407.d(46): Error: `nothrow` function `fail14407.testS` may throw
---
*/
void testS() pure nothrow @safe @nogc
{
    new("arg") S(0);
}
