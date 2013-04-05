/*
TEST_OUTPUT:
---
fail_compilation/fail4269b.d(12): Error: undefined identifier B2, did you mean struct A2?
fail_compilation/fail4269b.d(13): Error: undefined identifier B2, did you mean struct A2?
---
*/

enum bool WWW2 = is(typeof(A2.x));
struct A2
{
    B2 blah;
    void foo(B2 b) {}
}
