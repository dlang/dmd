// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/fail18228.d(13): Deprecation: Using `this` as a type is deprecated. Use `typeof(this)` instead
fail_compilation/fail18228.d(14): Deprecation: Using `this` as a type is deprecated. Use `typeof(this)` instead
fail_compilation/fail18228.d(15): Deprecation: Using `super` as a type is deprecated. Use `typeof(super)` instead
---
*/

class C
{
    this(this a) {}
    this(int a, this b) {}
    this(super a) {}
}
