// https://issues.dlang.org/show_bug.cgi?id=15467

class MeaCulpa: Exception
{
	this()
	{
		super("");
	}
}

class Other: MeaCulpa {}

void foo() nothrow
{
	try
		throw new MeaCulpa();
	catch (MeaCulpa e)
	{}

	try
	{
		try
		{
			throw new MeaCulpa();
		}
		finally
		{
			foo();
		}
	}
	catch (MeaCulpa e)
	{}

	try
	{
		try
		{
			try
				throw new MeaCulpa();
			catch (Other)
			{}
		}
		finally
		{
			foo();
		}
	}
	catch (MeaCulpa e)
	{}
}

/********************************************************/
// Shouldn't affect template attribute inference

void fooTempl()()
{
	try
		throw new MeaCulpa();
	catch (MeaCulpa e)
	{}

	try
	{
		try
		{
			throw new MeaCulpa();
		}
		finally
		{
			foo();
		}
	}
	catch (MeaCulpa e)
	{}

	try
	{
		try
		{
			try
				throw new MeaCulpa();
			catch (Other)
			{}
		}
		finally
		{
			foo();
		}
	}
	catch (MeaCulpa e)
	{}
}

void isNothrow() nothrow
{
	fooTempl();
}

// /*******************************************/

char[] parseBackrefType(scope char[] delegate() parseDg)
{
	scope(success) {}
	return parseDg();
}

/+
Function is lowered to:

char[] parseBackrefType(scope char[] delegate() parseDg)
{
	bool __os2 = false;
	try
	{
		try
		{
			return parseDg();
		}
		catch(Throwable __o3)
		{
			__os2 = true;
			throw __o3;
		}
	}
	finally
		if (!__os2)
		{
		}
}
+/
