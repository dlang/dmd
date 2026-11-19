/*
TEST_OUTPUT:
---
fail_compilation/fail9710.d(10): Error: static variable `e` cannot be read at compile time
fail_compilation/fail9710.d(13): Error: mutable variable `g` cannot be read at compile time, even through a pointer
---
*/

int* e;
enum v = e[1];

__gshared int g;
enum w = (&g)[0];
