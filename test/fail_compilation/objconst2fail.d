
void main()
{
	const(Object)[] copy = new const(Object)ref[12];
	const(Object)[] value = new const(Object)ref[12];
	copy[] = value[];
}