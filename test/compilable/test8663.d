// https://issues.dlang.org/show_bug.cgi?id=8663

void main()
{
	C c = C("foo");	
	assert(c == "foo");
}

struct C
{
	string v;
	
	// This does not work
	alias v this;
	
	this(string val) { v = val; }
}
