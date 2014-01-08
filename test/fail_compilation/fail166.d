/*
TEST_OUTPUT:
---
fail_compilation/fail166.d(12): Error: cannot implicitly convert expression (cp) of type const(int)***[] to const(uint***)[]
---
*/

void foo()
{
    const(uint***)[] p;
    const(int)***[] cp;
    p = cp;
}
