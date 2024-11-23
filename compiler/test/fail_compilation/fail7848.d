// REQUIRED_ARGS: -unittest

/*
TEST_OUTPUT:
---
fail_compilation/fail7848.d(51): Error: `pure` function `fail7848.C.__unittest_L49_C30` cannot call impure function `fail7848.func`
        func();
            ^
fail_compilation/fail7848.d(51): Error: `@safe` function `fail7848.C.__unittest_L49_C30` cannot call `@system` function `fail7848.func`
        func();
            ^
fail_compilation/fail7848.d(45):        `fail7848.func` is declared here
void func() {}
     ^
fail_compilation/fail7848.d(51): Error: `@nogc` function `fail7848.C.__unittest_L49_C30` cannot call non-@nogc function `fail7848.func`
        func();
            ^
fail_compilation/fail7848.d(51): Error: function `fail7848.func` is not `nothrow`
        func();
            ^
fail_compilation/fail7848.d(49): Error: function `fail7848.C.__unittest_L49_C30` may throw but is marked as `nothrow`
    @safe pure nothrow @nogc unittest
                             ^
fail_compilation/fail7848.d(56): Error: `pure` function `fail7848.C.__invariant0` cannot call impure function `fail7848.func`
        func();
            ^
fail_compilation/fail7848.d(56): Error: `@safe` function `fail7848.C.__invariant0` cannot call `@system` function `fail7848.func`
        func();
            ^
fail_compilation/fail7848.d(45):        `fail7848.func` is declared here
void func() {}
     ^
fail_compilation/fail7848.d(56): Error: `@nogc` function `fail7848.C.__invariant0` cannot call non-@nogc function `fail7848.func`
        func();
            ^
fail_compilation/fail7848.d(56): Error: function `fail7848.func` is not `nothrow`
        func();
            ^
fail_compilation/fail7848.d(54): Error: function `fail7848.C.__invariant0` may throw but is marked as `nothrow`
    @safe pure nothrow @nogc invariant
                             ^
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
}
