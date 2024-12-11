/*
TEST_OUTPUT:
---
fail_compilation/diag7050c.d(18): Error: `@safe` destructor `diag7050c.B.~this` cannot call `@system` destructor `diag7050c.A.~this`
@safe struct B
      ^
fail_compilation/diag7050c.d(15):        `diag7050c.A.~this` is declared here
    ~this(){}
    ^
---
*/

struct A
{
    ~this(){}
}

@safe struct B
{
    A a;
}

@safe void f()
{
    auto x = B.init;
}
