/*
TEST_OUTPUT:
---
fail_compilation/fail8631.d(14): Error: function `int fail8631.D.foo() shared const` does not override any function, did you mean to override `int fail8631.B.foo() immutable`?
---
*/

class B {
    int foo() immutable { return 2; }
    int foo() const { return 2; }
}
class D : B {
    override int foo() immutable { return 2; }
    override int foo() const shared { return 2; }   // doesn't override any
    override int foo() const { return 2; }
}
