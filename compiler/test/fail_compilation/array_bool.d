/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/array_bool.d(19): Deprecation: boolean evaluation of array literals and string literals is deprecated
fail_compilation/array_bool.d(19):        If intentional, use `[2] !is null` instead to preserve behaviour
fail_compilation/array_bool.d(20): Deprecation: boolean evaluation of array literals and string literals is deprecated
fail_compilation/array_bool.d(20):        If intentional, use `[1] !is null` instead to preserve behaviour
fail_compilation/array_bool.d(21): Deprecation: boolean evaluation of array literals and string literals is deprecated
fail_compilation/array_bool.d(21):        If intentional, use `"foo" !is null` instead to preserve behaviour
fail_compilation/array_bool.d(23): Deprecation: boolean evaluation of array literals and string literals is deprecated
fail_compilation/array_bool.d(23):        If intentional, use `"bar" !is null` instead to preserve behaviour
fail_compilation/array_bool.d(23):        while evaluating: `static assert(e)`
---
*/
void main()
{
    enum a = [2];
    if (a) {}
    auto b = [1] && true;
    assert("foo");
    enum e = "bar";
    static assert(e);

    // OK
    b = "".ptr || false;
    b = a.ptr || false;
}
