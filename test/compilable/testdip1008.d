// PERMUTE_ARGS:
// won't work until druntime is updated, so disable XXXEQUIRED_ARGS: -dip1008

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
