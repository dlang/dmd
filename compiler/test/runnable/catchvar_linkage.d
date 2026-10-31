// A caught Throwable must always get D linkage for its variable, even
// inside an extern(C) function - it was inheriting the enclosing scope's
// C linkage instead, which some backends mishandle when generating the
// exception landing pad for it (crashed under Windows LDC specifically).

extern(C) int caughtPath()
{
    try
    {
        throw new Exception("test");
    }
    catch (Throwable e)
    {
        return 2;
    }
}

void main()
{
    assert(caughtPath() == 2);
}
