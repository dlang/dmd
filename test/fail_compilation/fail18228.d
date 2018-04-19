// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/fail18228.d(12): Deprecation: `this` cannot be used as a parameter type. Use `typeof(this)` instead
fail_compilation/fail18228.d(13): Deprecation: `this` cannot be used as a parameter type. Use `typeof(this)` instead
---
*/

struct C
{
    this(this a) {}
    this(int a, this b) {}
}
