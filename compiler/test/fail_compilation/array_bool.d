/*
REQUIRED_ARGS: -wo -w
TEST_OUTPUT:
---
fail_compilation/array_bool.d(20): Warning: boolean evaluation of dynamic arrays is obsolete
fail_compilation/array_bool.d(20):        Use one of: a !is null, a.length, or a.ptr instead
fail_compilation/array_bool.d(21): Warning: boolean evaluation of dynamic arrays is obsolete
fail_compilation/array_bool.d(21):        Use one of: [1] !is null, [1].length, or [1].ptr instead
fail_compilation/array_bool.d(22): Warning: boolean evaluation of dynamic arrays is obsolete
fail_compilation/array_bool.d(22):        Use one of: "foo" !is null, "foo".length, or "foo".ptr instead
fail_compilation/array_bool.d(24): Warning: boolean evaluation of dynamic arrays is obsolete
fail_compilation/array_bool.d(24):        Use one of: "bar" !is null, "bar".length, or "bar".ptr instead
Error: warnings are treated as errors
       Use -wi if you wish to treat warnings only as informational.
---
*/
void main()
{
    int[] a = [2];
    if (a) {}
    auto b = [1] && true;
    assert("foo");
    enum e = "bar";
    static assert(e);
}
