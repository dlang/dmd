/*
TEST_OUTPUT:
---
fail_compilation/fail183.d(1): Error: redundant attribute `const`
fail_compilation/fail183.d(2): Error: redundant attribute `in`
fail_compilation/fail183.d(4): Error: redundant attribute `const`
fail_compilation/fail183.d(5): Error: redundant attribute `in`
---
*/

#line 1
void f(in final const scope int x) {}
void g(final const scope in int x) {}
// Part of https://issues.dlang.org/show_bug.cgi?id=17408
void h(in const int x) {}
void i(const in int x) {}
