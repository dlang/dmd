/*
TEST_OUTPUT:
---
fail_compilation/fail290.d(17): Error: no `this` to create delegate for `foo`
    void delegate (int) a = &Foo.foo;
                            ^
---
*/

struct Foo
{
    void foo(int x) {}
}

void main()
{
    void delegate (int) a = &Foo.foo;
}
