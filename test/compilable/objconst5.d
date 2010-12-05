
void main()
{
	auto o = cast(const(Object)ref)(new const(Object));
	static assert(is(typeof(o) == const(Object)ref));
}