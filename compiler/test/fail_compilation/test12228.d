/*
TEST_OUTPUT:
---
fail_compilation/test12228.d(18): Error: undefined identifier `this`, did you mean `typeof(this)`?
    shared(this) x;
                 ^
fail_compilation/test12228.d(24): Error: undefined identifier `super`, did you mean `typeof(super)`?
    shared(super) a;
                  ^
fail_compilation/test12228.d(25): Error: undefined identifier `super`, did you mean `typeof(super)`?
    super b;
          ^
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
