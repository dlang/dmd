/*
TEST_OUTPUT:
---
fail_compilation/ice12827.d(10): Error: circular initialization of i
---
*/

struct Test
{
	immutable int i = i;
}

void main()
{
}
