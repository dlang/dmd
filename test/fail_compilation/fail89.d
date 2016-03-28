/*
TEST_OUTPUT:
---
fail_compilation/fail89.d(9): Error: circular initialization of a
---
*/

const int a = b;
const int b = .a;
