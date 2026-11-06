// https://github.com/dlang/dmd/issues/17906

// A recursive call must not be assumed `nothrow` while inferring `nothrow`,
// otherwise the `catch (Exception)` clause around it gets wrongly elided and
// the exception is only caught by a more general `catch (Throwable)`.

string caught;

void foo(bool shouldThrow)
{
    if (shouldThrow)
        throw new Exception("here");

    try
        foo(true);
    catch (Exception e)
        caught = "exception";
    catch (Throwable t)
        caught = "throwable";
}

int eval(int c)
{
    if (c > 0)
    {
        try
            return eval(c - 1);
        catch (Exception e)
            return c;
    }
    throw new Exception("boom");
}

void main()
{
    foo(false);
    assert(caught == "exception");

    assert(eval(1) == 1);
}
