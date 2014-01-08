/*
TEST_OUTPUT:
---
fail_compilation/fail88.d(8): Error: forward reference of variable a
---
*/

const auto a = a;
