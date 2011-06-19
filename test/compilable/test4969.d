// PERMUTE_ARGS:

class MyException : Exception
{
    this()
    {
        super("An exception!");
    }
}

void throwAway()
{
    throw new MyException;
}

void cantthrow() nothrow
{
    try
        throwAway();
    catch(MyException me)
        assert(0);
    catch(Exception e)
        assert(0);
}

void main()
{
}


