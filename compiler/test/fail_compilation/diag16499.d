/*
TEST_OUTPUT:
---
fail_compilation/diag16499.d(26): Error: incompatible types for `(2) in (foo)`: `int` and `A`
	2 in foo;
 ^
fail_compilation/diag16499.d(28): Error: incompatible types for `(1.0) in (bar)`: `double` and `B`
	1.0 in bar;
 ^
---
*/

struct A {}
struct B {
	void* opBinaryRight(string op)(int b) if (op == "in")
	{
		return null;
	}
}

void main()
{
	A foo;
	B bar;

	2 in foo;
	2 in bar; // OK
	1.0 in bar;
}
