/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/template_function_oop.d(20): Deprecation: a function template is not virtual so cannot be marked `override`
    override void f()() {}
                  ^
fail_compilation/template_function_oop.d(21): Deprecation: a function template is not virtual so cannot be marked `abstract`
    abstract void g()();
                  ^
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
