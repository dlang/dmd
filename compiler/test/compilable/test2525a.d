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

class C : B
{
	override void foo()
	{
	}
}
