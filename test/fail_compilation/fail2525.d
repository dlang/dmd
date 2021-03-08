/*
TEST_OUTPUT:
---
fail_compilation/fail2525.d(14): Error: class `fail2525.B` interface function `void foo()` is not implemented
---
*/
// https://issues.dlang.org/show_bug.cgi?id=2525

interface A
{
	void foo();
}

class B : A
{
}
