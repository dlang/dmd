/*
TEST_OUTPUT:
---
fail_compilation/fail266.d(10): Error: invalid array operation a + a (did you forget a [] ?)
---
*/

void b(int[] a)
{
    b(a + a);
}
