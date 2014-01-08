/*
TEST_OUTPUT:
---
fail_compilation/fail174.d(17): Error: can only initialize const member x inside constructor
fail_compilation/fail174.d(20): Error: can only initialize const member x inside constructor
---
*/

struct S
{
    int x;
}

void main()
{
    const(S) s1;
    s1.x = 3;

    const S s2;
    s2.x = 3;
}
