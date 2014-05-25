/*
TEST_OUTPUT:
---
fail_compilation/fail52.d(11): Error: class fail52.C circular inheritance
fail_compilation/fail52.d(10): Deprecation: implicitly overriding base class method fail52.C.g with fail52.B.g deprecated; add 'override' attribute
---
*/

class A : B { void f(); }
class B : C { void g(); }
class C : A { void g(); }
