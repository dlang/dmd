/*
TEST_OUTPUT:
---
fail_compilation/fail7424d.d(12): Error: template `this.g()() immutable` has no value
    void test() const { int f = g; }
                                ^
---
*/
struct S7424d
{
    @property int g()() immutable { return 0; }
    void test() const { int f = g; }
}
