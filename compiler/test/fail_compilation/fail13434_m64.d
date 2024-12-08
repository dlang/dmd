// REQUIRED_ARGS: -m64
/*
TEST_OUTPUT:
---
fail_compilation/fail13434_m64.d(15): Error: cannot implicitly convert expression `()` of type `()` to `ulong`
    arr[tuple!()] = 0;
        ^
---
*/

alias tuple(A...) = A;
void main()
{
    float[] arr;
    arr[tuple!()] = 0;
}
