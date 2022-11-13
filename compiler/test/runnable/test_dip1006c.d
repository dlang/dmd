// ARG_SETS: -check=on -version=CheckOn
// ARG_SETS: -check=off -version=CheckOff
// PERMUTE_ARGS:

import core.exception : AssertError, SwitchError;

struct S
{
    int foo(int a)
    in(a <= 0)
    out(res; res >= 0)
    do
    {
        return a;
    }

    int bar(int a)
    {
        assert(a != 0);
        return 0;
    }

    invariant
    {
        assert(false);
    }
}

void main()
{
    S s;
    test(() => s.foo(1));  // Trigger in
    test(() => s.foo(-1)); // Trigger out
    test(() => s.bar(1));  // Trigger invariant
    test(() => s.bar(0));  // Trigger assert

    // Trigger final switch
    version (CheckOn)
    {
        try
        {
            int i = 0;
            final switch (i)
            {
                case 1: break;
            }
            throw new Exception("Check skipped!");
        }
        catch (SwitchError) {}
    }
}

void test(int delegate() test)
{
    try
    {
        test();

        version (CheckOn)
            throw new Exception("Check skipped!");
    }
    catch (AssertError e)
    {
        version (CheckOff)
            throw new Exception("Check not skipped!");
    }
}
