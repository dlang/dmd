/*
TEST_OUTPUT:
---
fail_compilation/diag9880.d(102): Error: template instance `diag9880.foo!string` does not match template declaration `foo(T)(int)`
  with `T = string`
  must satisfy the following constraint:
`       is(T == int)`
fail_compilation/diag9880.d(102):        instantiated from here: `foo!string`
fail_compilation/diag9880.d(101):        Candidate match: foo(T)(int) if (is(T == int))
---
*/

#line 100

void foo(T)(int) if (is(T == int)) {}
void main() { alias f = foo!string; }
