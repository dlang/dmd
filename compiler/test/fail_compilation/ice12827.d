/*
TEST_OUTPUT:
---
fail_compilation/ice12827.d(12): Error: circular initialization of variable `ice12827.Test.i`
	immutable int i = i;
                   ^
---
*/

struct Test
{
	immutable int i = i;
}

void main()
{
}
