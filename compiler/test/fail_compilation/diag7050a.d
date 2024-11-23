/*
TEST_OUTPUT:
---
fail_compilation/diag7050a.d(19): Error: `@safe` function `diag7050a.foo` cannot call `@system` constructor `diag7050a.Foo.this`
    auto f = Foo(3);
                ^
fail_compilation/diag7050a.d(15):        `diag7050a.Foo.this` is declared here
    this (int a) {}
    ^
---
*/

struct Foo
{
    this (int a) {}
}
@safe void foo()
{
    auto f = Foo(3);
}
