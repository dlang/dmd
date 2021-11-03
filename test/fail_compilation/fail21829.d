// REQUIRED_ARGS: -de
// EXTRA_FILES: imports/a21829.d

/*
TEST_OUTPUT:
---
fail_compilation/fail21829.d(14): Deprecation: Function `imports.a21829.foo` of type `void(int)` is not accessible from module `fail21829`
---
*/

void main()
{
    import imports.a21829;
    foo(2);
}
