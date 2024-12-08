/*
TEST_OUTPUT:
---
fail_compilation/fail101.d(13): Deprecation: use of complex type `creal` is deprecated, use `std.complex.Complex!(real)` instead
creal c = 1;
      ^
fail_compilation/fail101.d(13): Error: cannot implicitly convert expression `1` of type `int` to `creal`
creal c = 1;
          ^
---
*/

creal c = 1;
