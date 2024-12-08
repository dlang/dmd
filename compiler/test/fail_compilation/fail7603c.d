/*
TEST_OUTPUT:
---
fail_compilation/fail7603c.d(10): Error: cannot create default argument for `ref` / `out` parameter from constant `3`
void test(ref int val = x) { }
                        ^
---
*/
enum x = 3;
void test(ref int val = x) { }
