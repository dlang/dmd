// https://issues.dlang.org/show_bug.cgi?id=24159
// REQUIRED_ARGS: -betterC
/*
TEST_OUTPUT:
---
fail_compilation/test24159.d(15): Error: appending to array in `x ~= 3` requires the GC which is not available with -betterC
    x ~= 3;
      ^
---
*/

extern(C) void main()
{
    int[] x = null;
    x ~= 3;
}
