/*
TEST_OUTPUT:
---
fail_compilation/fail19913.d(11): Error: no property `b` for `a` of type `int`
---
*/


struct S
{
    mixin a.b;
    enum { a }
}
