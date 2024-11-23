// REQUIRED_ARGS: -m32
/*
TEST_OUTPUT:
---
fail_compilation/fail13434_m32.d(15): Error: cannot implicitly convert expression `()` of type `()` to `uint`
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
