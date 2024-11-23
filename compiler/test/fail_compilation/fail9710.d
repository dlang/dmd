/*
TEST_OUTPUT:
---
fail_compilation/fail9710.d(11): Error: static variable `e` cannot be read at compile time
enum v = e[1];
         ^
---
*/

int* e;
enum v = e[1];
