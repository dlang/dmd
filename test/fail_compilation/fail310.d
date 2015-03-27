/*
TEST_OUTPUT:
---
fail_compilation/fail310.d(9): Error: undefined identifier 'Foo', did you mean function 'foo'?
fail_compilation/fail310.d(13): Error: template instance fail310.foo!(1, 2) error instantiating
---
*/

Foo foo(A...)()
{
}

static assert(foo!(1, 2)());
