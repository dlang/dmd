// REQUIRED_ARGS: -unittest

/*
TEST_OUTPUT:
---
fail_compilation/fail7848.d(45): Deprecation: class allocators have been deprecated, consider moving the allocation strategy outside of the class
fail_compilation/fail7848.d(51): Deprecation: class deallocators have been deprecated, consider moving the deallocation strategy outside of the class
fail_compilation/fail7848.d(37): Error: `pure` function `fail7848.C.__unittest_L35_C30` cannot call impure function `fail7848.func`
fail_compilation/fail7848.d(37): Error: `@safe` function `fail7848.C.__unittest_L35_C30` cannot call `@system` function `fail7848.func`
fail_compilation/fail7848.d(37): Error: `@nogc` function `fail7848.C.__unittest_L35_C30` cannot call non-@nogc function `fail7848.func`
fail_compilation/fail7848.d(37): Error: function `fail7848.func` is not `nothrow`
fail_compilation/fail7848.d(35): Error: `nothrow` function `fail7848.C.__unittest_L35_C30` may throw
fail_compilation/fail7848.d(42): Error: `pure` function `fail7848.C.__invariant1` cannot call impure function `fail7848.func`
fail_compilation/fail7848.d(42): Error: `@safe` function `fail7848.C.__invariant1` cannot call `@system` function `fail7848.func`
fail_compilation/fail7848.d(42): Error: `@nogc` function `fail7848.C.__invariant1` cannot call non-@nogc function `fail7848.func`
fail_compilation/fail7848.d(42): Error: function `fail7848.func` is not `nothrow`
fail_compilation/fail7848.d(40): Error: `nothrow` function `fail7848.C.__invariant1` may throw
fail_compilation/fail7848.d(47): Error: `pure` allocator `fail7848.C.new` cannot call impure function `fail7848.func`
fail_compilation/fail7848.d(47): Error: `@safe` allocator `fail7848.C.new` cannot call `@system` function `fail7848.func`
fail_compilation/fail7848.d(47): Error: `@nogc` allocator `fail7848.C.new` cannot call non-@nogc function `fail7848.func`
fail_compilation/fail7848.d(47): Error: function `fail7848.func` is not `nothrow`
fail_compilation/fail7848.d(45): Error: `nothrow` allocator `fail7848.C.new` may throw
fail_compilation/fail7848.d(53): Error: `pure` deallocator `fail7848.C.delete` cannot call impure function `fail7848.func`
fail_compilation/fail7848.d(53): Error: `@safe` deallocator `fail7848.C.delete` cannot call `@system` function `fail7848.func`
fail_compilation/fail7848.d(53): Error: `@nogc` deallocator `fail7848.C.delete` cannot call non-@nogc function `fail7848.func`
fail_compilation/fail7848.d(53): Error: function `fail7848.func` is not `nothrow`
fail_compilation/fail7848.d(51): Error: `nothrow` deallocator `fail7848.C.delete` may throw
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
