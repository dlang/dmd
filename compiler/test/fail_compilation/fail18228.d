/*
TEST_OUTPUT:
---
fail_compilation/fail18228.d(18): Error: undefined identifier `this`, did you mean `typeof(this)`?
    this(this a) {}
    ^
fail_compilation/fail18228.d(19): Error: undefined identifier `this`, did you mean `typeof(this)`?
    this(int a, this b) {}
    ^
fail_compilation/fail18228.d(20): Error: undefined identifier `super`, did you mean `typeof(super)`?
    this(super a) {}
    ^
---
*/

class C
{
    this(this a) {}
    this(int a, this b) {}
    this(super a) {}
}
