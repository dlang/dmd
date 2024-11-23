/*
TEST_OUTPUT:
---
fail_compilation/diag9880.d(14): Error: template instance `diag9880.foo!string` does not match template declaration `foo(T)(int)`
  with `T = string`
  must satisfy the following constraint:
`       is(T == int)`
void main() { alias f = foo!string; }
                        ^
---
*/

void foo(T)(int) if (is(T == int)) {}
void main() { alias f = foo!string; }
