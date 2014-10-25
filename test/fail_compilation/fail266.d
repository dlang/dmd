/*
TEST_OUTPUT:
---
fail_compilation/fail266.d(10): Error: invalid array operation a + a (possible missing [])
---
*/

void b(int[] a)
{
    b(a + a);
}
