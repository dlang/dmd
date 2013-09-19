/*
TEST_OUTPUT:
---
fail_compilation/test10552.d(8): Error: enum member a : only anonymous enum members can have access specifiers
fail_compilation/test10552.d(8): Error: enum member b : only anonymous enum members can have access specifiers
---
*/
enum E { private a, public b }
