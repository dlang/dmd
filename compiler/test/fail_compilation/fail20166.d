/*
TEST_OUTPUT:
---
fail_compilation/fail20166.d(18): Error: no property `bar` for `f` of type `Foo`
---
*/

struct Foo
{
    int b;
}

int bar;

void test20166()
{
    Foo f;
    bar = f.bar;
}
