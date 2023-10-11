/*
*/
// https://issues.dlang.org/show_bug.cgi?id=2525

interface A
{
	void foo();
}

abstract class B : A
{
}

abstract class C : B
{
}

class D : C
{
	override void foo() {}
}

void main()
{
	auto c = new D();
	c.foo();
}
