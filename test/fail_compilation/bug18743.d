// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/bug18743.d(18): Deprecation: `a ? a = 4 : a` must be surrounded by parentheses when next to operator `=`
fail_compilation/bug18743.d(19): Deprecation: `a ? --a : a` must be surrounded by parentheses when next to operator `+=`
---
*/

void main()
{
	int a;

	// ok
	(a ? a = 4 : a) = 5;
	a ? a = 4 : (a = 5);

	a ? a = 4 : a = 5;
	a ? --a : a += 1;

	a ? a = 4 : a++; // ok
}
