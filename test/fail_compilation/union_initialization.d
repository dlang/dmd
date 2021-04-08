
/*
https://issues.dlang.org/show_bug.cgi?id=21229

TEST_OUTPUT:
---
fail_compilation/union_initialization.d(223): Error: field `union_` must be initialized in constructor
fail_compilation/union_initialization.d(223): Error: field `proxy` must be initialized in constructor
---
*/
#line 200

struct NeedsInit
{
	int var;
	long lo;
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

	this(int arg)
	{
		union_.ni.var = arg;
		proxy.union_.ni.var = arg;
	}
}
