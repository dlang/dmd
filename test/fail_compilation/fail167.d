/*
TEST_OUTPUT:
---
fail_compilation/fail167.d(12): Error: cannot modify const expression *p
---
*/

void main()
{
    int x;
    const(int)* p = &x;
    *p = 3;
}
