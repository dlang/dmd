/*
https://issues.dlang.org/show_bug.cgi?id=20068
https://issues.dlang.org/show_bug.cgi?id=21229

TEST_OUTPUT:
---
fail_compilation/union_initialization.d(36): Error: field `B.p` cannot access pointers in `@safe` code that overlap other fields
		int* x = this.p;
           ^
fail_compilation/union_initialization.d(42): Error: field `B.p` cannot access pointers in `@safe` code that overlap other fields
		this.p = *i;
  ^
fail_compilation/union_initialization.d(56): Error: immutable field `p` initialized multiple times
		this.p = null;
  ^
fail_compilation/union_initialization.d(55):        Previous initialization is here.
		this.p = p;
  ^
fail_compilation/union_initialization.d(84): Error: field `union_` must be initialized in constructor
	this(int arg)
 ^
fail_compilation/union_initialization.d(84): Error: field `proxy` must be initialized in constructor
	this(int arg)
 ^
---
*/

union B
{
	int i;
	int* p;

	@safe this(int* p)
	{
		this.p = p;
		int* x = this.p;
	}

	@safe this(int** i)
	{
		this.p = null;
		this.p = *i;
	}
}

// Line 100 starts here

union C
{
	int i;
	immutable int* p;

	@safe this(immutable int* p)
	{
		this.p = p;
		this.p = null;
	}
}

// Line 200 starts here

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
