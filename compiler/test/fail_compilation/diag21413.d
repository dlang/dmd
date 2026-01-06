/*
TEST_OUTPUT:
---
fail_compilation\diag21413.d(13): Error: undefined identifier `Potato`
---
*/
// https://github.com/dlang/dmd/issues/21413

void main()
{
	throw
	new
	Potato
	();
}
