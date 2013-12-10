/*
TEST_OUTPUT:
---
fail_compilation/fail164.d(12): Error: cannot implicitly convert expression (p) of type const(int***) to const(int)***
---
*/

void foo()
{
    const int*** p;
    const(int)*** cp;
    cp = p;
}
