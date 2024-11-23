/*
TEST_OUTPUT:
---
fail_compilation/test16694.d(10): Error: cannot take address of imported symbol `bar` at compile time
auto barptr = &bar;
              ^
---
*/
export void bar();
auto barptr = &bar;
