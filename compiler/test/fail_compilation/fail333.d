/*
TEST_OUTPUT:
---
fail_compilation/fail333.d(10): Error: forward reference to `test`
void test(typeof(test) p) { }
     ^
---
*/

void test(typeof(test) p) { }
