/*
TEST_OUTPUT:
---
fail_compilation/ice10616.d(8): Error: undefined identifier `B`
---
*/

class A : B
{
    interface B {}
}
