
static if (__traits(compiles, __vector(float[4])))
{
	struct Foo
	{
		__vector(float[4]) x;
	}
	static assert(Foo.x.offsetof == 0);
	static assert(Foo.x.stringof == "x");
}
