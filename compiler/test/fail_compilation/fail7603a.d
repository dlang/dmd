/*
TEST_OUTPUT:
---
fail_compilation/fail7603a.d(10): Error: `true` is a constant, not an lvalue
fail_compilation/fail7603a.d(11): Error: `true` is a constant, not an lvalue
fail_compilation/fail7603a.d(14): Error: `3` is a constant, not an lvalue
fail_compilation/fail7603a.d(17): Error: `S` is a `struct` definition, not an lvalue
---
*/
void test(ref bool val = true) { }
void test(out bool val = true) { }

enum x = 3;
void test(ref int val = x) { }

struct S;
void test(ref S val = S) { }
