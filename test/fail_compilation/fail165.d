/*
TEST_OUTPUT:
---
fail_compilation/fail165.d(13): Error: cannot modify const expression p
---
*/


void foo()
{
    const(uint***) p;
    const(int)*** cp;
    p = cp;
}
