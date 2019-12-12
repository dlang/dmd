// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/fail20164.d(12): Deprecation: module `imports.fail20164` is deprecated
---
*/
module fail20164;

void foo()
{
    import imports.fail20164;
}
