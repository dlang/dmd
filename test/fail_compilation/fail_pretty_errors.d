/*
REQUIRED_ARGS: -verrors=context
TEST_OUTPUT:
---
Deprecation: -verrors=context is redundant, and will be removed in future DMD versions.
fail_compilation/fail_pretty_errors.d(15): Error: undefined identifier `a`
fail_compilation/fail_pretty_errors.d-mixin-20(20): Error: undefined identifier `b`
fail_compilation/fail_pretty_errors.d(25): Error: cannot implicitly convert expression `5` of type `int` to `string`
fail_compilation/fail_pretty_errors.d(30): Error: mixin `fail_pretty_errors.testMixin2.mixinTemplate!()` error instantiating
---
*/

void foo()
{
    a = 1;
}

void testMixin1()
{
    mixin("b = 1;");
}

mixin template mixinTemplate()
{
    string x = 5;
}

void testMixin2()
{
    mixin mixinTemplate;
}
