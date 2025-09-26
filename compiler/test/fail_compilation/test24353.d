// https://issues.dlang.org/show_bug.cgi?id=24353

/*
TEST_OUTPUT:
---
fail_compilation/test24353.d(26): Error: mutable method `test24353.S.opApply` is not callable using a `const(S)` foreach aggregate
fail_compilation/test24353.d(17):        Consider adding a method type qualifier here
fail_compilation/test24353.d(29): Error:  shared const method `test24353.S2.opApply` is not callable using a `const(S2)` foreach aggregate
fail_compilation/test24353.d(36):        Consider adding a method type qualifier here
fail_compilation/test24353.d(31): Error: cannot uniquely infer `foreach` argument types
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
    foreach (e; s) {} // mod error

    const S2 s2;
    foreach (i, e; s2) {} // mod error

    foreach (e; const S3()) {} // cannot infer
}

struct S2
{
    int opApply(int delegate(int, int) dg) const shared;
}

struct S3
{
    int opApply(int delegate(int) dg);
    int opApply(int delegate(int, int) dg);
}
