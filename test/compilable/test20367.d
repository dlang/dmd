// https://issues.dlang.org/show_bug.cgi?id=20367

import std.stdio;

struct A
{
	int x;
	this(ref return scope A rhs) {}
	@disable this(this) {}
}

void main()
{
	A a;
	A b = a; // copy constructor gets called
}
