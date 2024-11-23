/*
TEST_OUTPUT:
---
fail_compilation/fail303.d(34): Deprecation: use of imaginary type `ireal` is deprecated, use `real` instead
    ireal x = 3.0i;
          ^
fail_compilation/fail303.d(36): Error: `double /= cdouble` is undefined. Did you mean `double /= cdouble.re`?
    y /= 2.0 + 6i;
      ^
fail_compilation/fail303.d(37): Error: `ireal *= ireal` is an undefined operation
    x *= 7.0i;
      ^
fail_compilation/fail303.d(38): Error: `ireal *= creal` is undefined. Did you mean `ireal *= creal.im`?
    x *= 3.0i + 2;
      ^
fail_compilation/fail303.d(39): Error: `ireal %= creal` is undefined. Did you mean `ireal %= creal.im`?
    x %= (2 + 6.0i);
      ^
fail_compilation/fail303.d(40): Error: `ireal += real` is undefined (result is complex)
    x += 2.0;
      ^
fail_compilation/fail303.d(41): Error: `ireal -= creal` is undefined (result is complex)
    x -= 1 + 4i;
      ^
fail_compilation/fail303.d(42): Error: `double -= idouble` is undefined (result is complex)
    y -= 3.0i;
      ^
---
*/


void main()
{
    ireal x = 3.0i;
    double y = 3;
    y /= 2.0 + 6i;
    x *= 7.0i;
    x *= 3.0i + 2;
    x %= (2 + 6.0i);
    x += 2.0;
    x -= 1 + 4i;
    y -= 3.0i;
}
