
/**************************************************************/
// https://issues.dlang.org/show_bug.cgi?id=21229

struct NeedsInit
{
	int var;
	@disable this();
}

union Union
{
	NeedsInit ni;
}

union Proxy
{
	Union union_;
}

struct S
{
	Union union_;
	Proxy proxy;

	this(NeedsInit arg)
	{
		union_.ni = arg;
		proxy.union_.ni = arg;
	}
}
