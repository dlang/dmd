/*
TEST_OUTPUT:
---
fail_compilation/test22397.d(13): Error: this array literal causes a GC allocation in `@nogc` function `main`
fail_compilation/test22397.d(14): Error: this array literal causes a GC allocation in `@nogc` function `main`
fail_compilation/test22397.d(15): Error: this array literal causes a GC allocation in `@nogc` function `main`
---
*/

// https://issues.dlang.org/show_bug.cgi?id=22397
@nogc void main()
{
    @("uda") int[] a = [1, 2];      // should error
    align(8) int[] b = [3, 4];      // should error
    extern(C) int[] c = [5, 6];     // should error
}
