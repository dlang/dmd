/**
https://issues.dlang.org/show_bug.cgi?id=21799

PERMUTE_ARGS:
**/

int main()
{
	testDeleteD();
	testDeleteDScope();
	testDeleteWithoutD();
	testDeleteCpp();
	testDeleteCppScope();
	testDeleteWithoutCpp();
	testThrowingDtor();
	return 0;
}

enum forceCtfe = main();

/*************************************************/

class ParentD
{
	char[]* ptr;

	~this()
	{
		*ptr ~= 'A';
	}
}

class ChildD : ParentD
{
	~this()
	{
		*ptr ~= 'B';
	}
}

void testDeleteD()
{
	char[] res;
	ChildD cd = new ChildD();
	cd.ptr = &res;
	if (!__ctfe)
	{
		destroy(cd);
		assert(res == "BA", cast(string) res);
	}
}

void testDeleteDScope()
{
	char[] res;
	{
		scope cd = new ChildD();
		cd.ptr = &res;
	}
	assert(res == "BA", cast(string) res);
}

/*************************************************/

class ChildWithoutDtorD : ChildD {}

void testDeleteWithoutD()
{
	char[] res;
	ChildWithoutDtorD cd = new ChildWithoutDtorD();
	cd.ptr = &res;
	if (!__ctfe)
	{
		destroy(cd);
		assert(res == "BA", cast(string) res);
	}
}

/*************************************************/

extern (C++) class ParentCpp
{
	char[]* ptr;

	~this()
	{
		*ptr ~= 'C';
	}
}

extern (C++) class ChildCpp : ParentCpp
{
	~this()
	{
		*ptr ~= 'D';
	}
}

void testDeleteCpp()
{
	// Internal assertion failure
	version (Windows)
		return;

	// Segfault at runtime
	if (!__ctfe)
		return;

	char[] res;
	ChildCpp cc = new ChildCpp();
	cc.ptr = &res;
	if (!__ctfe)
	{
		destroy(cc);
		assert(res == "DC", cast(string) res);
	}
}

void testDeleteCppScope()
{
	// Unsupported pointer cast
	version (Windows) if (__ctfe)
		return;

	char[] res;
	{
		scope cc = new ChildCpp();
		cc.ptr = &res;
	}
	assert(res == "DC", cast(string) res);
}

/*************************************************/

class ChildWithoutDtorCpp : ChildCpp {}

void testDeleteWithoutCpp()
{
	// delete segfaults at runtime
	if (!__ctfe)
		return;

	char[] res;
	ChildWithoutDtorCpp cd = new ChildWithoutDtorCpp();
	cd.ptr = &res;
	if (!__ctfe)
	{
		destroy(cd);
		assert(res == "DC", cast(string) res);
	}
}

/*************************************************/

class ThrowingChildD : ChildD
{
	static Exception ex;

	static this()
	{
		ex = new Exception("STOP");
	}

	~this()
	{
		throw ex;
	}
}

void testThrowingDtor()
{
	// Finalization error at runtime
	if (!__ctfe)
		return;

	char[] res;
	ThrowingChildD tcd = new ThrowingChildD();
	tcd.ptr = &res;

	if (!__ctfe)
	{
		try
		{
			destroy(tcd);
			assert(false, "No exception thrown!");
		}
		catch (Exception e)
		{
			assert(e is ThrowingChildD.ex);
		}

		assert(res == "", cast(string) res);
	}
}
