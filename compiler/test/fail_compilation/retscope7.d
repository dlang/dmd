/*
REQUIRED_ARGS: -preview=dip1000
TEST_OUTPUT:
---
fail_compilation/retscope7.d(22): Error: scope variable `y` may not be returned
---
*/

@safe:
int* f()
{
	int local;

	int* x;
	int* y;

	foreach(i; 0..2)
	{
		y = x;
		x = &local;
	}
	return y;
}
