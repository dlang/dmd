/*
TEST_OUTPUT:
---
fail_compilation/fail1313b.d(13): Error: escaping reference to local a
---
*/

int[] test()
out{}
body
{
    int a[2];
    return a;
}
