// PERMUTE_ARGS:

int bar()
{
    try
    {
	throw new Exception("message");
    }
    catch (Exception e)
    {
	return 7;
    }
}


void foo()
{
    enum r = bar();
    static assert(r == 7);
}
