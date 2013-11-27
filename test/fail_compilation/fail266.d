/*
TEST_OUTPUT:
---
fail_compilation/fail266.d(10): Error: Array operation a + a not implemented
---
*/

void b(int[] a)
{
    b(a + a);
}
