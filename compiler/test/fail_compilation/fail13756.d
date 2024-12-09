/*
TEST_OUTPUT:
---
fail_compilation/fail13756.d(13): Error: `foreach`: index must be type `const(int)`, not `int`
    foreach (ref int k, v; aa)
    ^
---
*/

void maiin()
{
    int[int] aa = [1:2];
    foreach (ref int k, v; aa)
    {
    }
}
