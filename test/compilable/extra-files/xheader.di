class C
{
}
void foo(const C c, const(char)[] s, const int* q, const(int*) p);
void bar(in void* p);
void f(void function() f2);
class C2;
void foo2(const C2 c);
struct Foo3
{
	int k;
	~this();
	this(this);
}
class C3
{
	@property int get();

}
template foo3(T)
{
	T foo3()
	{
	}

}
template Foo4(T)
{
	struct Foo4
	{
		T x;
	}
}
template C4(T)
{
	class C4
	{
		T x;
	}
}
