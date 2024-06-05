module foo.bar.ba;
nothrow pure @nogc @safe package(foo)
{
	void foo();
	package(foo.bar) void foo2() nothrow pure @nogc @safe;
}
