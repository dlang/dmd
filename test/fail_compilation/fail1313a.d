/*
TEST_OUTPUT:
---
fail_compilation/fail1313a.d(13): Error: escaping reference to local variable a
---
*/

int[] test()
//out{}
body
{
    int[2] a;
    return a;
}
