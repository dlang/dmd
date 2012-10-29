/*
TEST_OUTPUT:
---
fail_compilation/diag8777d.d(4): Error: cannot modify immutable expression x
---
*/

#line 1
void test()
{
    immutable int x;
    x = 1;
}
