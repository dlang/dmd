/*
TEST_OUTPUT:
---
fail_compilation/fail291.d(11): Error: variable `fail291.X` cannot be declared to be a function
typeof(a) X;
          ^
---
*/

auto a() { return 0; }
typeof(a) X;
