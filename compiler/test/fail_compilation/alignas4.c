/*
TEST_OUTPUT:
---
fail_compilation/alignas4.c(12): Error: `_Alignas` specifier cannot be less strict than alignment of `c`
fail_compilation/alignas4.c(13): Error: alignment must be an integer positive power of 2, not 0x1
---
*/
int main()
{
    _Alignas(1) _Alignas(int) int a;
    _Alignas(1) _Alignas(16) int b;
    _Alignas(1) int c;
    _Alignas((void*)1) int d;
}
