/*
TEST_OUTPUT:
---
fail_compilation/fail12622.d(26): Error: `pure` function `fail12622.foo` cannot call impure function pointer `fp`
fail_compilation/fail12622.d(28): Error: `pure` function `fail12622.foo` cannot call impure function pointer `fp`
fail_compilation/fail12622.d(30): Error: `pure` function `fail12622.foo` cannot call impure function `fail12622.bar`
---
*/
// Note that, today nothrow violation errors are accidentally hidden.

#line 20
void bar();

pure nothrow @nogc @safe void foo()
{
    auto fp = &bar;

    (*fp)();

    fp();

    bar();
}
