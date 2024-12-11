/*
TEST_OUTPUT:
---
fail_compilation/fail7424b.d(12): Error: template `this.g()()` has no value
    void test() const { int f = g; }
                                ^
---
*/
struct S7424b
{
    @property int g()() { return 0; }
    void test() const { int f = g; }
}
