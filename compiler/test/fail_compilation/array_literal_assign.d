/*
TEST_OUTPUT:
---
fail_compilation/array_literal_assign.d(20): Error: cannot modify the content of array literal `[1, 2, 3]`
fail_compilation/array_literal_assign.d(20): Error: cannot modify the content of array literal `[1, 2, 3]`
fail_compilation/array_literal_assign.d(20): Error: discarded assignment to indexed array literal
fail_compilation/array_literal_assign.d(22): Error: cannot modify the content of array literal `[1, 2]`
fail_compilation/array_literal_assign.d(22): Error: discarded assignment to indexed array literal
fail_compilation/array_literal_assign.d(23): Error: cannot modify the content of array literal `[1, 2]`
fail_compilation/array_literal_assign.d(23): Error: discarded assignment to indexed array literal
fail_compilation/array_literal_assign.d(24): Error: cannot modify the content of array literal `[1, 2]`
fail_compilation/array_literal_assign.d(24): Error: discarded assignment to indexed array literal
fail_compilation/array_literal_assign.d(26): Error: cannot modify the content of array literal `[1, 2]`
fail_compilation/array_literal_assign.d(26): Error: cannot modify the content of array literal `[1, 2]`
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
