/*
TEST_OUTPUT:
---
fail_compilation/array_literal_assign.d(17): Error: cannot modify the content of array literal `[1, 2, 3]`
fail_compilation/array_literal_assign.d(17): Error: cannot modify the content of array literal `[1, 2, 3]`
fail_compilation/array_literal_assign.d(19): Error: cannot modify the content of array literal `[1, 2]`
fail_compilation/array_literal_assign.d(20): Error: cannot modify the content of array literal `[1, 2]`
fail_compilation/array_literal_assign.d(21): Error: cannot modify the content of array literal `[1, 2]`
fail_compilation/array_literal_assign.d(23): Error: cannot modify the content of array literal `[1, 2]`
fail_compilation/array_literal_assign.d(23): Error: cannot modify the content of array literal `[1, 2]`
fail_compilation/array_literal_assign.d(23): Error: rvalue `__error` cannot be assigned to `ref x`
---
*/

void main()
{
	[1, 2, 3][2] = 4;
	enum e = [1, 2];
	e[0]++;
	++e[0];
	e[0] += 1;

	ref x = (e[0] = 4); // OK
	x++;
	assert(x == 5);
}
