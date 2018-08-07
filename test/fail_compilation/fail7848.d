// REQUIRED_ARGS: -unittest

/*
TEST_OUTPUT:
---
fail_compilation/fail7848.d(49): Deprecation: class allocators have been deprecated, consider moving the allocation strategy outside of the class
fail_compilation/fail7848.d(55): Deprecation: class deallocators have been deprecated, consider moving the deallocation strategy outside of the class
fail_compilation/fail7848.d(41): Error: `pure` function `fail7848.C.__unittest_L39_C30` cannot call impure function `fail7848.func`
fail_compilation/fail7848.d(41): Error: `@safe` function `fail7848.C.__unittest_L39_C30` cannot call `@system` function `fail7848.func`
fail_compilation/fail7848.d(35):        `fail7848.func` is declared here
fail_compilation/fail7848.d(41): Error: `@nogc` function `fail7848.C.__unittest_L39_C30` cannot call non-@nogc function `fail7848.func`
fail_compilation/fail7848.d(41): Error: function `fail7848.func` is not `nothrow`
fail_compilation/fail7848.d(39): Error: `nothrow` function `fail7848.C.__unittest_L39_C30` may throw
fail_compilation/fail7848.d(46): Error: `pure` function `fail7848.C.__invariant1` cannot call impure function `fail7848.func`
fail_compilation/fail7848.d(46): Error: `@safe` function `fail7848.C.__invariant1` cannot call `@system` function `fail7848.func`
fail_compilation/fail7848.d(35):        `fail7848.func` is declared here
fail_compilation/fail7848.d(46): Error: `@nogc` function `fail7848.C.__invariant1` cannot call non-@nogc function `fail7848.func`
fail_compilation/fail7848.d(46): Error: function `fail7848.func` is not `nothrow`
fail_compilation/fail7848.d(44): Error: `nothrow` function `fail7848.C.__invariant1` may throw
fail_compilation/fail7848.d(51): Error: `pure` allocator `fail7848.C.new` cannot call impure function `fail7848.func`
fail_compilation/fail7848.d(51): Error: `@safe` allocator `fail7848.C.new` cannot call `@system` function `fail7848.func`
fail_compilation/fail7848.d(35):        `fail7848.func` is declared here
fail_compilation/fail7848.d(51): Error: `@nogc` allocator `fail7848.C.new` cannot call non-@nogc function `fail7848.func`
fail_compilation/fail7848.d(51): Error: function `fail7848.func` is not `nothrow`
fail_compilation/fail7848.d(49): Error: `nothrow` allocator `fail7848.C.new` may throw
fail_compilation/fail7848.d(57): Error: `pure` deallocator `fail7848.C.delete` cannot call impure function `fail7848.func`
fail_compilation/fail7848.d(57): Error: `@safe` deallocator `fail7848.C.delete` cannot call `@system` function `fail7848.func`
fail_compilation/fail7848.d(35):        `fail7848.func` is declared here
fail_compilation/fail7848.d(57): Error: `@nogc` deallocator `fail7848.C.delete` cannot call non-@nogc function `fail7848.func`
fail_compilation/fail7848.d(57): Error: function `fail7848.func` is not `nothrow`
fail_compilation/fail7848.d(55): Error: `nothrow` deallocator `fail7848.C.delete` may throw
---
*/

void func() {}

class C
{
    @safe pure nothrow @nogc unittest
    {
        func();
    }

    @safe pure nothrow @nogc invariant
    {
        func();
    }

    @safe pure nothrow @nogc new (size_t sz)
    {
        func();
        return null;
    }

    @safe pure nothrow @nogc delete (void* p)
    {
        func();
    }
}
