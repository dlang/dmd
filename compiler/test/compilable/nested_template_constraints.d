// https://issues.dlang.org/show_bug.cgi?id=21752

void foo(A)(A a)
{}

template foo()
{
	void foo()()
	if (true)  // Comment this constraint to make it pass
	{}
}

template bar()
{
	template bar()
	{
		void bar()()
		if (true)  // Comment this constraint to make it pass
		{}
	}
}

void main()
{
	foo!()();
	bar!()();
}
