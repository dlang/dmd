/*
TEST_OUTPUT:
---
fail_compilation/fail7603a.d(9): Error: cannot create default argument for `ref` / `out` parameter from constant `true`
void test(ref bool val = true) { }
                         ^
---
*/
void test(ref bool val = true) { }
