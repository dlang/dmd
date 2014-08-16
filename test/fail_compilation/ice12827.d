/*
TEST_OUTPUT:
---
fail_compilation/ice12827.d(11): Deprecation: variable ice12827.Test.i immutable field with initializer should be static, __gshared, or an enum
fail_compilation/ice12827.d(11): Error: circular initialization of i
---
*/

struct Test
{
	immutable int i = i;
}

void main()
{
}
