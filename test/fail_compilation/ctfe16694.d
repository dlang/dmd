/*
TEST_OUTPUT:
---
fail_compilation/ctfe16694.d(8): Error: cannot take address of imported symbol bar at compile time
---
*/
export void bar();
auto barptr = &bar;
