/*
TEST_OUTPUT:
---
fail_compilation/ice10419.d(14): Error: cannot modify expression `arr().length` because it is not an lvalue
    arr().length = 1;
       ^
---
*/

int[] arr() { return []; }

void main()
{
    arr().length = 1;
}
