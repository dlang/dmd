
void main()
{
	assert((const(Object)ref).stringof == "const(Object)ref");
	assert((const(Object ref)).stringof == "const(Object)");
	assert((const(Object)).stringof == "const(Object)");
}