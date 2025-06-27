/*
TEST_OUTPUT:
---
fail_compilation\call_function_type.d(16): Error: type `int(int)` is not an expression
fail_compilation/call_function_type.d(17): Error: type `int(int)` is not an expression
---
*/
// This is a rare case where `dmd.expressionsem.functionParameters` catches a missing argument error,
// which is usually caught earlier by `TypeFunction.callMatch`, and had no test coverage yet.
// This was found while implementing named arguments and reduced from `vibe.internal.meta.traits`.
int f(int);

void m()
{
	alias FT = typeof(f);
	enum X0 = FT();
	enum X1 = FT(3);
}
