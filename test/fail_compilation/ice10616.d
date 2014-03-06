/*
TEST_OUTPUT:
---
fail_compilation/ice10616.d(9): Error: no property 'B' for type 'ice10616.A'
fail_compilation/ice10616.d(9): Error: A.B is used as a type
---
*/

class A : A.B
{
    interface B {}
}
