// https://issues.dlang.org/show_bug.cgi?id=19465

/*
REQUIRED_ARGS: -verrors=context
TEST_OUTPUT:
---
fail_compilation/test19465.d(30): Error: cannot uniquely infer `foreach` argument types
    foreach (string x; s) {}
    ^
fail_compilation/test19465.d(21):        `int(int delegate(int) dg)`:
    int opApply(int delegate(int) dg)
        ^
fail_compilation/test19465.d(21):            parameter 1: `foreach` declares `string`, expected `int`
    int opApply(int delegate(int) dg)
        ^
---
*/

struct S
{
    int opApply(int delegate(int) dg)
    {
        return 0;
    }
}

void test()
{
    S s;
    foreach (string x; s) {}
}
