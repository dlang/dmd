// REQUIRED_ARGS:
/*
TEST_OUTPUT:
---
fail_compilation/bug18743.d(22): Error: `a ? a = 4 : a` must be surrounded by parentheses when next to operator `=`
	a ? a = 4 : a = 5;
 ^
fail_compilation/bug18743.d(23): Error: `a ? --a : a` must be surrounded by parentheses when next to operator `+=`
	a ? --a : a += 1;
 ^
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
