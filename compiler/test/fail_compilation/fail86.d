/*
TEST_OUTPUT:
---
fail_compilation/fail86.d(14): Error: alias `Foo` recursive alias declaration
    alias Foo!(int) Foo;
    ^
---
*/

template Foo(TYPE) {}

void main()
{
    alias Foo!(int) Foo;
}
