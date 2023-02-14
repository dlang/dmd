/*
TEST_OUTPUT:
---
fail_compilation/fail290.d(15): Error: cannot cast from function pointer to delegate
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
