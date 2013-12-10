/*
TEST_OUTPUT:
---
fail_compilation/fail191.d(8): Error: scope cannot be ref or out
---
*/

void foo(scope ref int x) { }
