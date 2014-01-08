/*
TEST_OUTPUT:
---
fail_compilation/fail90.d(9): Error: forward reference of variable a
---
*/

const auto a = b;
const auto b = a;
