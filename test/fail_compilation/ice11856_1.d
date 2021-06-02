/*
TEST_OUTPUT:
---
fail_compilation/ice11856_1.d(13): Error: template `ice11856_1.g` cannot deduce function from argument types `!()(A)`, candidates are:
fail_compilation/ice11856_1.d(11):        `g(T)(T x)`
---
*/
struct A {}

void f(T)(T x) if (is(typeof(x.g()))) {}
void g(T)(T x) if (is(typeof(x.f()))) {}

void main() { A().g(); }
