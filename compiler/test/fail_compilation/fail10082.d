/*
TEST_OUTPUT:
---
fail_compilation/fail10082.d(26): Error: cannot infer type from overloaded function symbol `&foo`
    auto x = &A.foo;
             ^
---
*/

mixin template T()
{
    int foo()
    {
        return 0;
    }
}

class A
{
    mixin T;
    mixin T;
}

void main()
{
    auto x = &A.foo;
}
