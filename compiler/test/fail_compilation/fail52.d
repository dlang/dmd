/*
TEST_OUTPUT:
---
fail_compilation/fail52.d(12): Error: class `fail52.C` circular inheritance
class C : A { void g(); }
^
---
*/

class A : B { void f(); }
class B : C { override void g(); }
class C : A { void g(); }
