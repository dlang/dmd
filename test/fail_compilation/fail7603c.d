/*
TEST_OUTPUT:
---
fail_compilation/fail7603c.d(9): Error: cannot modify constant `3`
       use `-preview=in` or `preview=rvaluerefparam`
---
*/
enum x = 3;
void test(ref int val = x) { }
