/*
TEST_OUTPUT:
---
compilable/test2525d.d(18): Deprecation: class `test2525d.C` interface function `void foo()` is not implemented
---
*/
// https://issues.dlang.org/show_bug.cgi?id=2525

interface A
{
	void foo();
}

abstract class B : A
{
}

class C : B
{
}
