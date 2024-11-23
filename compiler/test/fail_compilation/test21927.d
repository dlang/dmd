// https://issues.dlang.org/show_bug.cgi?id=21927
/*
TEST_OUTPUT:
---
fail_compilation/test21927.d(21): Error: invalid `foreach` aggregate `this.T2(Args2...)` of type `void`
        static foreach (p; this.T2) {} // ICE
                           ^
fail_compilation/test21927.d(22): Error: invalid `foreach` aggregate `this.T2!()` of type `void`
        static foreach (p; this.T2!()) {} // ICE
                               ^
---
*/

struct S
{
    template T2(Args2...) {}

    void fun()
    {
        // original test case
        static foreach (p; this.T2) {} // ICE
        static foreach (p; this.T2!()) {} // ICE
    }
}
