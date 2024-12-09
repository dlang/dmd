/*
TEST_OUTPUT:
---
fail_compilation/fail10.d(20): Error: mixin `Foo!y` cannot resolve forward reference
    mixin Foo!(y) y;
    ^
---
*/

template Foo(alias b)
{
    int a()
    {
        return b;
    }
}

void test()
{
    mixin Foo!(y) y;
}
