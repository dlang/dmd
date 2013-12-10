/*
TEST_OUTPUT:
---
fail_compilation/fail163.d(13): Error: cannot implicitly convert expression (q) of type const(char)[] to char[]
---
*/

void foo()
{
    char[] p;
    const(char)[] q;

    p = q;
}
