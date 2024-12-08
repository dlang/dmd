/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/array_bool.d(17): Deprecation: assert condition cannot be a string literal
    assert("foo");
           ^
fail_compilation/array_bool.d(17):        If intentional, use `"foo" !is null` instead to preserve behaviour
fail_compilation/array_bool.d(18): Deprecation: static assert condition cannot be a string literal
    static assert("foo");
                  ^
fail_compilation/array_bool.d(18):        If intentional, use `"foo" !is null` instead to preserve behaviour
---
*/
void main()
{
    assert("foo");
    static assert("foo");

    assert("foo".ptr); // OK
    static assert("foo".ptr); // OK

    enum e = "bar";
    static assert(e); // OK
    assert(e); // OK
}
