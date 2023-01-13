/*
TEST_OUTPUT:
---
fail_compilation/fail299.d(14): Error: too many initializers for `Foo`
---
*/

struct Foo {}

void foo (Foo b, void delegate ()) {}

void main ()
{
    foo(Foo(1), (){});
}
