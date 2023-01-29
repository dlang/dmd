/*
TEST_OUTPUT:
---
fail_compilation/fail12636.d(14): Error: C++ class `fail12636.C` cannot implement D interface `fail12636.D`
fail_compilation/fail12636.d(16): Error: function `void fail12636.C.foo()` does not override any function, did you mean to override `void fail12636.D.foo()`?
---
*/

interface D
{
    void foo();
}

extern(C++) class C : D
{
    extern(D) override void foo() { }
}

void main()
{
    auto c = new C;
    c.foo(); // works
    D d = c;
    d.foo(); // segfault
}
