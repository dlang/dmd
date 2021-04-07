// https://issues.dlang.org/show_bug.cgi?id=20068

union B
{
	int i;
	int* p;
	@safe this(int* p)
	{
		// Error: cannot access pointers in @safe code that overlap other fields
		this.p = p;
	}
}
