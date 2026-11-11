/*
TEST_OUTPUT:
---
fail_compilation/fail24238.d(14): Error: cannot cast `a` of type `int[]` to `void[0][]` with zero-size elements
fail_compilation/fail24238.d(15): Error: cannot cast `v` of type `void[]` to `byte[0][]` with zero-size elements
---
*/
// https://github.com/dlang/dmd/issues/24238

void main()
{
    int[] a;
    void[] v;
    auto b = cast(void[0][]) a;
    auto c = cast(byte[0][]) v;
}
