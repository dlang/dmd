/*
TEST_OUTPUT:
---
fail_compilation/ice13987.d(9): Error: cannot infer type from struct initializer
---
*/

struct S {}
S s = [{}];
