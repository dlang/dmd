/*
TEST_OUTPUT:
---
fail_compilation/diag8777c.d(4): Error: cannot modify const expression x
---
*/

#line 1
void test()
{
    const int x;
    x = 1;
}
