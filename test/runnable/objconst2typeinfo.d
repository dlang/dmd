
void main()
{
	// This tests wehther typeinfo was generated correctly.
	typeid(const(Object)ref).toString();
	typeid(immutable(Object)ref).toString();
	typeid(shared(Object)ref).toString();
	typeid(shared(const(Object))ref).toString();
	typeid(inout(Object)ref).toString();
	typeid(inout(shared(Object))ref).toString();
	typeid(inout(shared(Object)ref)).toString();
	typeid(const(shared(Object)ref)).toString();
	typeid(shared(immutable(Object)ref)).toString();
}