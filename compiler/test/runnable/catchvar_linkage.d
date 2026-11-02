// A caught Throwable must always get D linkage for its variable, even
// inside an extern(C) function.

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
