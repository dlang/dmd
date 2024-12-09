/*
TEST_OUTPUT:
---
fail_compilation/fail6242.d(11): Error: cannot implicitly override base class method `fail6242.A.fun` with `fail6242.B.fun`; add `override` attribute
class B : A { void fun(int x) in { assert(x > 0); } do {} }
                   ^
---
*/
class A { void fun(int) {} }

class B : A { void fun(int x) in { assert(x > 0); } do {} }
