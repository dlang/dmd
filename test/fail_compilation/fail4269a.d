/*
TEST_OUTPUT:
---
fail_compilation/fail4269a.d(14): Error: undefined identifier B1, did you mean interface A1?
fail_compilation/fail4269a.d(14): Error: variable fail4269a.A1.blah field not allowed in interface
fail_compilation/fail4269a.d(15): Error: undefined identifier B1, did you mean interface A1?
fail_compilation/fail4269a.d(15): Error: function fail4269a.A1.foo function body only allowed in final functions in interface A1
---
*/

enum bool WWW1 = is(typeof(A1.x));
interface A1
{
    B1 blah;
    void foo(B1 b) {}
}
