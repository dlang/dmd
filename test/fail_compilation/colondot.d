/*
PERMUTE_ARGS:
TEST_OUTPUT:
---
fail_compilation/colondot.d(16): Error: '::' is not a valid token, perhaps '.' was meant?
---
*/

struct S
{
    static int a;
}

int foo(S* s)
{
    return S::a;
}
