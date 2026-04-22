/*
TEST_OUTPUT:
---
fail_compilation/fail18228.d(12): Error: basic type expected, not `this`, did you mean `typeof(this)`?
fail_compilation/fail18228.d(13): Error: basic type expected, not `this`, did you mean `typeof(this)`?
fail_compilation/fail18228.d(14): Error: basic type expected, not `super`, did you mean `typeof(super)`?
---
*/

class C
{
    this(this a) {}
    this(int a, this b) {}
    this(super a) {}
}
