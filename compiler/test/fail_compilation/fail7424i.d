/*
TEST_OUTPUT:
---
fail_compilation/fail7424i.d(12): Error: template `this.g()() immutable` has no value
    void test() inout { int f = g; }
                                ^
---
*/
struct S7424g
{
    @property int g()() immutable { return 0; }
    void test() inout { int f = g; }
}
