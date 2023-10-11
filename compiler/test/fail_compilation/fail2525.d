/*
TEST_OUTPUT:
---
fail_compilation/fail2525.d(15): Error: class `fail2525.B` interface function `void foo()` is not implemented
fail_compilation/fail2525.d(24): Deprecation: class `fail2525.D` interface function `void foo()` is not implemented
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

abstract class C : A
{
	void bar();
}

class D : C
{
    // FIXME: no error for missing bar!
}
