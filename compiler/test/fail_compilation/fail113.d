/*
TEST_OUTPUT:
---
fail_compilation/fail113.d(12): Error: forward reference to `test`
void test(typeof(test) p) {}
     ^
---
*/

// https://issues.dlang.org/show_bug.cgi?id=370
// Compiler stack overflow on recursive typeof in function declaration.
void test(typeof(test) p) {}
