/* https://issues.dlang.org/show_bug.cgi?id=22351
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/fail22351.d(22): Deprecation: overriding `extern(C++)` function `fail22351.C22351.func(int*)` with `const` qualified function `fail22351.Fail22351.func(const(int*))` is deprecated
    override void func(const int*) { }
                  ^
fail_compilation/fail22351.d(22):        Either remove `override`, or adjust the `const` qualifiers of the overriding function parameters
fail_compilation/fail22351.d(23): Error: function `extern (C++) void fail22351.Fail22351.func(const(int*)**)` does not override any function, did you mean to override `extern (C++) void fail22351.C22351.func(int*)`?
    override void func(const(int*)**) { }
                  ^
---
*/
extern(C++) class C22351
{
    void func(int*) { }
    void func(int***) { }
}

extern(C++) final class Fail22351 : C22351
{
    override void func(const int*) { }
    override void func(const(int*)**) { }
}
