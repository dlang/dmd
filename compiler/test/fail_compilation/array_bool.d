/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/array_bool.d(13): Deprecation: assert condition cannot be a string literal
fail_compilation/array_bool.d(13):        If intentional, use `"foo" !is null` instead to preserve behaviour
fail_compilation/array_bool.d(15): Deprecation: static assert condition cannot be a string literal
fail_compilation/array_bool.d(15):        If intentional, use `"bar" !is null` instead to preserve behaviour
---
*/
void main()
{
    assert("foo");
    enum e = "bar";
    static assert(e);

    static assert("foo".ptr); // OK
    assert(e.ptr); // OK
}
