/*
TEST_OUTPUT:
---
fail_compilation/fail7603a.d(8): Error: cannot modify constant `true`
       use `-preview=in` or `preview=rvaluerefparam`
---
*/
void test(ref bool val = true) { }
