
struct S
{
	const(Object)ref o;
}

void main()
{
	S s;
	s.o = new Object;
}