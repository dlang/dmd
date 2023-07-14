/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/array_bool.d(15): Deprecation: boolean evaluation of array/string literals is deprecated
fail_compilation/array_bool.d(16): Deprecation: boolean evaluation of array/string literals is deprecated
fail_compilation/array_bool.d(17): Deprecation: boolean evaluation of array/string literals is deprecated
fail_compilation/array_bool.d(19): Deprecation: boolean evaluation of array/string literals is deprecated
fail_compilation/array_bool.d(19):        while evaluating: `static assert(e)`
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
}
