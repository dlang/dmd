/*
TEST_OUTPUT:
---
compilable/test2525e.d(24): Deprecation: class `test2525e.B` interface function `void foo()` is not implemented
compilable/test2525e.d(24): Deprecation: class `test2525e.B` interface function `void bar()` is not implemented
---
*/
// https://issues.dlang.org/show_bug.cgi?id=2525

interface IA
{
	void foo();
}

interface IB : IA
{
	void bar();
}

abstract class A : IB
{
}

class B : A
{
}
