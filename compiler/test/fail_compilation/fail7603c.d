/*
TEST_OUTPUT:
---
fail_compilation/fail7603c.d(8): Error: `3` is a constant, not an lvalue
---
*/
enum x = 3;
void test(ref int val = x) { }
