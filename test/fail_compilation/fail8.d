/*
TEST_OUTPUT:
---
fail_compilation/fail8.d(12): Error: cannot implicitly convert expression (0) of type int to Foo
---
*/

struct Foo { int x; }

enum Bar : Foo
{
    a,
    b,
    c
}
