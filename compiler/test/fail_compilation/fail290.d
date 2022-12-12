/*
TEST_OUTPUT:
---
fail_compilation/fail290.d(15): Error: cannot implicitly convert expression `& foo` of type `void*` to `void delegate(int)`
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
