/*
TEST_OUTPUT:
----
fail_compilation/ice11856_1.d(24): Error: no property `g` for `A()` of type `A`
void main() { A().g(); }
                   ^
fail_compilation/ice11856_1.d(24):        the following error occured while looking for a UFCS match
fail_compilation/ice11856_1.d(24): Error: template `g` is not callable using argument types `!()(A)`
void main() { A().g(); }
                   ^
fail_compilation/ice11856_1.d(22):        Candidate is: `g(T)(T x)`
  with `T = A`
  must satisfy the following constraint:
`       is(typeof(x.f()))`
void g(T)(T x) if (is(typeof(x.f()))) {}
     ^
----
*/
struct A {}

void f(T)(T x) if (is(typeof(x.g()))) {}
void g(T)(T x) if (is(typeof(x.f()))) {}

void main() { A().g(); }
