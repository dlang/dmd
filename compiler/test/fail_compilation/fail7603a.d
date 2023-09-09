/*
TEST_OUTPUT:
---
fail_compilation/fail7603a.d(7): Error: `true` is a constant, not an lvalue
---
*/
void test(ref bool val = true) { }
