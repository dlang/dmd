/*
TEST_OUTPUT:
---
fail_compilation/ice9439.d(18): Error: calling non-static function `foo` requires an instance of type `Derived`
        static assert(F());
                       ^
fail_compilation/ice9439.d(18):        while evaluating: `static assert(foo())`
        static assert(F());
        ^
fail_compilation/ice9439.d(25): Error: template instance `ice9439.Base.boo!(foo)` error instantiating
        boo!(foo)();
        ^
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
