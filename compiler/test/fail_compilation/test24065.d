/*
REQUIRED_ARGS: -preview=dip1000
TEST_OUTPUT:
---
fail_compilation/test24065.d(18): Error: string expected as argument of __traits `getTargetInfo` instead of `int`
fail_compilation/test24065.d(20): Error: string expected as argument of __traits `getTargetInfo` instead of `foo`
fail_compilation/test24065.d(22): Error: string expected as argument of __traits `getTargetInfo` instead of `e`
fail_compilation/test24065.d(24): Error: assigning reference to local `r` to non-scope `dg` is not allowed in a `@safe` function
---
*/

// https://issues.dlang.org/show_bug.cgi?id=24065

int delegate() @safe dg;

void f(ref int r) @safe
{
    auto s1 = __traits(getTargetInfo, int);
    void foo() {}
    auto s2 = __traits(getTargetInfo, foo);
    enum e;
    auto s3 = __traits(getTargetInfo, e);
    int x;
    dg = () => x + r;
}
