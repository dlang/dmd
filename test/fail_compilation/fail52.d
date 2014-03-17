/*
TEST_OUTPUT:
---
fail_compilation/fail52.d(11): Error: class fail52.C circular inheritance
fail_compilation/fail52.d(10): Deprecation: overriding base class function without using override attribute is deprecated (fail52.B.g overrides fail52.C.g)
---
*/

class A : B { void f(); }
class B : C { void g(); }
class C : A { void g(); }
