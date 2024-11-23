/*
TEST_OUTPUT:
---
fail_compilation/diag7477.d(17): Error: cannot generate 0 value of type `Foo` for `a`
    a,
    ^
fail_compilation/diag7477.d(24): Error: cannot generate 0 value of type `string` for `a`
    a,
    ^
---
*/

struct Foo { int x; }

enum Bar : Foo
{
    a,
    b,
    c
}

enum Baz : string
{
    a,
    b,
}
