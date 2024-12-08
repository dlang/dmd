/*
TEST_OUTPUT:
---
fail_compilation/fail7424g.d(12): Error: template `this.g()()` has no value
    void test() shared { int f = g; }
                                 ^
---
*/
struct S7424g
{
    @property int g()() { return 0; }
    void test() shared { int f = g; }
}
