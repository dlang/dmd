/*
TEST_OUTPUT:
---
fail_compilation/fail7424c.d(12): Error: template `this.g()()` has no value
    void test() immutable { int f = g; }
                                    ^
---
*/
struct S7424c
{
    @property int g()() { return 0; }
    void test() immutable { int f = g; }
}
