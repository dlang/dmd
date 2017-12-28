// https://issues.dlang.org/show_bug.cgi?id=18030

struct S(T)
{
	T var;
	pragma(
		msg,
		"Inside S: func() is ",
		__traits(getProtection, __traits(getMember, T, "func"))
	);
}

class C
{
	alias Al = S!C;
	
	static void func(U)(U var) { }
}
