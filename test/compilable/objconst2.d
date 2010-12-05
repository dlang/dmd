
void main()
{
	const(Object)ref[] copy = new const(Object)ref[12];
	const(Object)[] value = new const(Object)ref[12];
	copy[] = value[];
}