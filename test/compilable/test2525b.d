/*
*/
// https://issues.dlang.org/show_bug.cgi?id=2525

interface A
{
	void foo();
}

abstract class B : A
{
	override void foo() {}
}

class C : B
{
}
