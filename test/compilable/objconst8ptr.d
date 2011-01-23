
void main()
{
	const(Object)ref* p = (new const(Object)ref[1]).ptr; // hard to get a new "const(Object)ref*"
	*p = new Object;
}