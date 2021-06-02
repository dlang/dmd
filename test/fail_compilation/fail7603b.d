/*
TEST_OUTPUT:
---
fail_compilation/fail7603b.d(8): Error: cannot modify constant `true`
       use `-preview=in` or `preview=rvaluerefparam`
---
*/
void test(out bool val = true) { }
