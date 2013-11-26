/*
TEST_OUTPUT:
---
fail_compilation/fail40.d(12): Error: need 'this' for address of yuiop
fail_compilation/fail40.d(12): Error: variable yuiop cannot be read at compile time
---
*/

struct Qwert
{
    int[20] yuiop;
    int* asdfg = yuiop.ptr;
}
