/*
TEST_OUTPUT:
---
fail_compilation/diag13215.d(13): Error: cannot implicitly convert expression `[1, 2, 3]` of type `int[]` to `immutable(uint[2])[]`
    arr2 = [1, 2, 3];
           ^
---
*/

enum uint N = 10;
immutable uint[2][3] arr2;
shared static this() {
    arr2 = [1, 2, 3];
}
