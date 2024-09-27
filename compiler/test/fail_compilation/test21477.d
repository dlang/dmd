/* REQUIRED_ARGS: -betterC
TEST_OUTPUT:
---
fail_compilation/test21477.d(14): Error: expression `[1]` uses the GC and cannot be used with switch `-betterC`
---
*/

// https://issues.dlang.org/show_bug.cgi?id=21477

int[] global;

int test()
{
    int[] foo = [1];
    global = foo;
    return 0;
}
