// https://github.com/dlang/dmd/issues/24017

/*
TEST_OUTPUT:
---
fail_compilation/test24017.d(15): Error: index 1 exceeds array length 1
fail_compilation/test24017.d(18):        called from here: `f()`
---
*/

int f()
{
    int[] a = [1, 2, 3];
    int[] s = a[0 .. 1];
    return s[1];
}

enum x = f();
