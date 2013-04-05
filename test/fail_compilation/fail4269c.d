/*
TEST_OUTPUT:
---
fail_compilation/fail4269c.d(12): Error: undefined identifier B3, did you mean class A3?
fail_compilation/fail4269c.d(13): Error: undefined identifier B3, did you mean class A3?
---
*/

enum bool WWW3 = is(typeof(A3.x));
class A3
{
    B3 blah;
    void foo(B3 b) {}
}
