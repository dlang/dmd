/*
TEST_OUTPUT:
---
fail_compilation/fail7603b.d(7): Error: `true` is a constant, not an lvalue
---
*/
void test(out bool val = true) { }
