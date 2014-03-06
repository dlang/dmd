/*
TEST_OUTPUT:
---
fail_compilation/fail183.d(10): Error: redundant storage class 'const'
fail_compilation/fail183.d(10): Error: redundant storage class 'scope'
fail_compilation/fail183.d(11): Error: redundant storage class 'in'
---
*/

void f(in final const scope int x) {}
void g(final const scope in int x) {}
