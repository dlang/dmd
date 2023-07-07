/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/template_function_oop.d(16): Deprecation: a function template is not virtual so cannot be marked `override`
fail_compilation/template_function_oop.d(17): Deprecation: a function template is not virtual so cannot be marked `abstract`
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
