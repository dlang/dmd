/*
TEST_OUTPUT:
---
fail_compilation/fail168.d(12): Error: cannot implicitly convert expression (& x) of type int* to immutable(int)*
fail_compilation/fail168.d(13): Error: cannot modify immutable expression *p
---
*/

void main()
{
    int x;
    immutable(int)* p = &x;
    *p = 3;
}
