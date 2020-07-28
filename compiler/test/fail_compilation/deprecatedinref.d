/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/deprecatedinref.d(9): Error: attribute `ref` is redundant with previously-applied `in`
fail_compilation/deprecatedinref.d(10): Error: attribute `in` cannot be added after `ref`: remove `ref`
---
*/
void foo(in ref int);
void foor(ref in int);
