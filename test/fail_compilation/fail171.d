/*
TEST_OUTPUT:
---
fail_compilation/fail171.d(11): Error: cannot implicitly convert expression (& x) of type const(int)* to int*
---
*/

void main()
{
    const(int) x = 3;
    int* p = &x;
}
