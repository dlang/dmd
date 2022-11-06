/*
REQUIRED_ARGS: -verrors=context
TEST_OUTPUT:
---
fail_compilation/fail_pretty_errors.d(24): Error: undefined identifier `a`
    a = 1;
    ^
fail_compilation/fail_pretty_errors.d-mixin-25(29): Error: undefined identifier `b`
fail_compilation/fail_pretty_errors.d(34): Error: cannot implicitly convert expression `5` of type `int` to `string`
    string x = 5;
               ^
fail_compilation/fail_pretty_errors.d(39): Error: mixin `fail_pretty_errors.testMixin2.mixinTemplate!()` error instantiating
    mixin mixinTemplate;
    ^
fail_compilation/fail_pretty_errors.d(44): Error: invalid array operation `"" + ""` (possible missing [])
    auto x = ""+"";
             ^
fail_compilation/fail_pretty_errors.d(44):        did you mean to concatenate (`"" ~ ""`) instead ?
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

void f()
{
    auto x = ""+""; // check supplemental error doesn't show context
}
