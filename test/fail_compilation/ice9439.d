/*
TEST_OUTPUT:
---
fail_compilation/ice9439.d(12): Error: value of 'this' is not known at compile time
fail_compilation/ice9439.d(12):        while evaluating: static assert(this.foo())
fail_compilation/ice9439.d(19): Error: template instance ice9439.Derived.boo!(foo) error instantiating
---
*/

class Base {
    void boo(alias F)() {
        static assert(F());
    }
}

class Derived : Base {
    int foo() { return 1; }
    void bug() {
        boo!(foo)();
    }
}
