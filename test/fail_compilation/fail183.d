/*
TEST_OUTPUT:
---
fail_compilation/fail183.d(10): Deprecation: `in` is defined as `scope const`.  However, `in` has not yet been properly implemented, so its current implementation is equivalent to `const`. It is recommended to avoid using `in`, and explicitly use `scope const` or `const` instead, until `in` is properly implemented.
fail_compilation/fail183.d(10): Deprecation: `in` is defined as `scope const`.  However, `in` has not yet been properly implemented, so its current implementation is equivalent to `const`. It is recommended to avoid using `in`, and explicitly use `scope const` or `const` instead, until `in` is properly implemented.
fail_compilation/fail183.d(10): Error: redundant attribute `const`
fail_compilation/fail183.d(10): Deprecation: `in` is defined as `scope const`.  However, `in` has not yet been properly implemented, so its current implementation is equivalent to `const`. It is recommended to avoid using `in`, and explicitly use `scope const` or `const` instead, until `in` is properly implemented.
fail_compilation/fail183.d(10): Error: redundant attribute `scope`
fail_compilation/fail183.d(11): Error: redundant attribute `in`
---
*/

#line 10
void f(in final const scope int x) {}
void g(final const scope in int x) {}
