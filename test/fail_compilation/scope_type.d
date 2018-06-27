/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/scope_type.d(11): Deprecation: `scope` as a type constraint is deprecated.  Use `scope` at the usage site.
fail_compilation/scope_type.d(12): Deprecation: `scope` as a type constraint is deprecated.  Use `scope` at the usage site.
fail_compilation/scope_type.d(13): Deprecation: `scope` as a type constraint is deprecated.  Use `scope` at the usage site.
---
*/

scope class C { }
scope struct S { }
scope interface I { }
