
void main()
{
	const(Object)ref[] objects = new const(Object)ref[12];
	foreach (ref object; objects)
	{
		static assert(is(typeof(object) == const(Object)ref));
		object = new Object;
	}
}