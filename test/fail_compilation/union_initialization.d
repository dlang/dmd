/*
https://issues.dlang.org/show_bug.cgi?id=20068

TEST_OUTPUT:
---
fail_compilation/union_initialization.d(19): Error: field `B.p` cannot access pointers in `@safe` code that overlap other fields
fail_compilation/union_initialization.d(25): Error: field `B.p` cannot access pointers in `@safe` code that overlap other fields
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

/*
TEST_OUTPUT:
---
fail_compilation/union_initialization.d(109): Error: immutable field `p` initialized multiple times
fail_compilation/union_initialization.d(108):        Previous initialization is here.
---
*/
#line 100

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
