// https://issues.dlang.org/show_bug.cgi?id=24353

/*
TEST_OUTPUT:
---
fail_compilation/test24353.d(25): Error: mutable method `test24353.S.opApply` is not callable using a `const(S)` foreach aggregate
fail_compilation/test24353.d(16):        Consider adding a method type qualifier here
fail_compilation/test24353.d(28): Error:  shared const method `test24353.S2.opApply` is not callable using a `const(S2)` foreach aggregate
fail_compilation/test24353.d(33):        Consider adding a method type qualifier here
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

    const S2 s2;
    foreach (i, e; s2) {} // Error expected here
}

struct S2
{
    int opApply(int delegate(int, int) dg) const shared
    {
        return 0;
    }
}
