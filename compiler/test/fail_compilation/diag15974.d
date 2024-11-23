/*
TEST_OUTPUT:
---
fail_compilation/diag15974.d(29): Error: variable `f` cannot be read at compile time
    mixin(format("%s", f));
                       ^
fail_compilation/diag15974.d(29):        called from here: `format("%s", f)`
    mixin(format("%s", f));
                ^
fail_compilation/diag15974.d(34): Error: variable `f` cannot be read at compile time
        mixin(format("%s", f));
                           ^
fail_compilation/diag15974.d(34):        called from here: `format("%s", f)`
        mixin(format("%s", f));
                    ^
---
*/

void test15974()
{
    string format(Args...)(string fmt, Args args)
    {
        return "";
    }

    string f = "vkCreateSampler";

    // CompileStatement
    mixin(format("%s", f));

    struct S
    {
        // CompileDeclaration
        mixin(format("%s", f));
    }
}
