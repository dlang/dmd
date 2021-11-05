// https://issues.dlang.org/show_bug.cgi?id=22042

shared(void delegate()[]) onRelease;

void main()
{
	onRelease ~= (){};
}
