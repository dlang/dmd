/*
TEST_OUTPUT:
---
fail_compilation/template_function_oop.d(15): Error: a function template cannot be `override`
fail_compilation/template_function_oop.d(16): Error: a function template cannot be `abstract`
---
*/
class C
{
    void f();
}

class D : C
{
    override void f()() {}
    abstract void g()();
}
