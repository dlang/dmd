/*
TEST_OUTPUT:
---
fail_compilation/uda_rvalueref0.d(13): Error: `@rvalue_ref` can only apply to C++ function parameters
fail_compilation/uda_rvalueref0.d(14): Error: `@rvalue_ref` can only apply to C++ function parameters
fail_compilation/uda_rvalueref0.d(15): Error: `@rvalue_ref` can only apply to C++ function parameters
fail_compilation/uda_rvalueref0.d(19): Error: `@rvalue_ref` can only apply to `ref` or `out` parameters
---
*/

struct rvalue_ref {}

void f(@rvalue_ref int i);
void f(@rvalue_ref ref int i);
void f(@rvalue_ref out int i);

extern(C++)
{
void g(@rvalue_ref int i);
void g(@rvalue_ref ref int i);
void g(@rvalue_ref out int i);
}
