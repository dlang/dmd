/*
TEST_OUTPUT:
---
fail_compilation/fail13064.d(10): Error: function `fail13064.f` storage class `auto` has no effect if return type is not inferred
auto void f() { }
          ^
---
*/

auto void f() { }
