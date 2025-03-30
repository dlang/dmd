void main()
{
    bool checkStack(Throwable ex)
    {
        auto stack = ex.info.toString();
        for(size_t i = 0; i < stack.length - 6; i++)
            if(stack[i .. i + 6] == "D main" || stack[i .. i + 6] == "_Dmain")
                return true;
        return false;
        // It seems that _Dmain is not demangled for -m32 targets
        // Might be an optlink or OMF issue
    }

    try
    {
        regular();
        assert(false, "Not thrown");
    }
    catch(Exception ex)
    {
        assert(checkStack(ex), "Bad stack");
    }

    version(Win32)
    {
        // Cannot catch exceptions on Win64 because
        // dmd implements its own exception handling

        try
        {
            // Check for simple access violation
            int* p = cast(int*)0;
            *p = 5;
            assert(false, "Not thrown");
        }
        catch(Error ex)
        {
            assert(checkStack(ex), "Bad stack");
        }

        try
        {
            // Check for null function call and recursion
            recursion(0);
            assert(false, "Not thrown");
        }
        catch(Error ex)
        {
            assert(checkStack(ex), "Bad stack");
        }
    }

    // see https://issues.dlang.org/show_bug.cgi?id=23859
    try
    {
        recurseThrow(200);
    }
    catch(Exception e)
    {
    }
}

void regular()
{
    throw new Exception("Nothing special");
}

void recursion(int i)
{
    if (i < 5)
        recursion(i + 1);
    else
    {
        void function() f = cast(void function())0;
        f();
    }
}

void* recurseThrow(int n)
{
    if (n > 0)
        return recurseThrow(n - 1) + 1; // avoid tail call optimization
    throw new Exception("cancel");
}
