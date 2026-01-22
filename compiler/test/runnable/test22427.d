// https://github.com/dlang/dmd/issues/22427

noreturn exit1()
{
    throw new Exception("exit(1)");
}

noreturn exit0()
{
    throw new Exception("exit(0)");
}

void main()
{
    try
    {
        scope exitProgram = (bool failure) @trusted {
            return failure
                ? throw new Exception("exit(1)")
                : throw new Exception("exit(0)");
        };
        exitProgram(false);
    }
    catch (Exception e)
    {
        assert(e.message == "exit(0)");
    }

    try
    {
        scope exitProgram = (bool failure) @trusted {
            return failure ? exit1() : exit0();
        };
        exitProgram(false);
    }
    catch (Exception e)
    {
        assert(e.message == "exit(0)");
    }
}
