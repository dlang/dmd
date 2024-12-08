/*
TEST_OUTPUT:
---
fail_compilation/fail40.d(13): Error: variable `yuiop` cannot be read at compile time
    int* asdfg = yuiop.ptr;
                 ^
---
*/

struct Qwert
{
    int[20] yuiop;
    int* asdfg = yuiop.ptr;
}
