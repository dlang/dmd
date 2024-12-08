/*
TEST_OUTPUT:
---
fail_compilation/ice4983.d(16): Error: circular reference to `ice4983.Foo.dg`
    void delegate() dg = &Foo.init.bar;
                          ^
---
*/

struct Foo
{
    void bar()
    {
    }

    void delegate() dg = &Foo.init.bar;
}
