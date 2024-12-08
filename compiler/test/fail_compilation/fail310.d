/*
TEST_OUTPUT:
---
fail_compilation/fail310.d(16): Error: undefined identifier `Foo`, did you mean function `foo`?
Foo foo(A...)()
    ^
fail_compilation/fail310.d(20): Error: template instance `fail310.foo!(1, 2)` error instantiating
static assert(foo!(1, 2)());
              ^
fail_compilation/fail310.d(20):        while evaluating: `static assert(foo!(1, 2)())`
static assert(foo!(1, 2)());
^
---
*/

Foo foo(A...)()
{
}

static assert(foo!(1, 2)());
