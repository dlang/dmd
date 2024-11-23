/*
TEST_OUTPUT:
---
fail_compilation/fail7424h.d(12): Error: template `this.g()()` has no value
    void test() inout { int f = g; }
                                ^
---
*/
struct S7424g
{
    @property int g()() { return 0; }
    void test() inout { int f = g; }
}
