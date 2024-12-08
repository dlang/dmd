// https://issues.dlang.org/show_bug.cgi?id=24353

/**
TEST_OUTPUT:
---
fail_compilation/test24353.d(27): Error: mutable method `test24353.S.opApply` is not callable using a `const` object
    foreach (e; s) {} // Error expected here
    ^
fail_compilation/test24353.d(18):        Consider adding `const` or `inout` here
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

void example()
{
    const S s;
    foreach (e; s) {} // Error expected here
}
