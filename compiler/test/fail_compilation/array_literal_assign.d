/*
TEST_OUTPUT:
---
fail_compilation/array_literal_assign.d(13): Error: discarded assignment to indexed array literal
fail_compilation/array_literal_assign.d(15): Error: discarded assignment to indexed array literal
fail_compilation/array_literal_assign.d(16): Error: discarded assignment to indexed array literal
fail_compilation/array_literal_assign.d(17): Error: discarded assignment to indexed array literal
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
