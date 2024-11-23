/*
TEST_OUTPUT:
---
fail_compilation/fail19913.d(15): Error: no property `b` for `a` of type `int`
    mixin a.b;
    ^
fail_compilation/fail19913.d(15): Error: mixin `fail19913.S.b!()` is not defined
    mixin a.b;
    ^
---
*/

struct S
{
    mixin a.b;
    enum { a }
}
