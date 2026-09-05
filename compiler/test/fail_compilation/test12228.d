/*
TEST_OUTPUT:
---
fail_compilation/test12228.d(12): Error: basic type expected, not `this`, did you mean `typeof(this)`?
fail_compilation/test12228.d(18): Error: basic type expected, not `super`, did you mean `typeof(super)`?
fail_compilation/test12228.d(19): Error: basic type expected, not `super`, did you mean `typeof(super)`?
---
*/

class C
{
    shared(this) x;
}

class D : C
{
    alias x = typeof(super).x;
    shared(super) a;
    super b;
}
