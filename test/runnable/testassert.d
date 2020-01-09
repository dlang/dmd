/*
REQUIRED_ARGS: -checkaction=context
*/

void test8765()
{
    string msg;
    try
    {
        int a = 0;
        assert(a);
    }
    catch (Throwable e)
    {
        // no-message -> assert expression
        msg = e.msg;
    }
    assert(msg && msg == "assert(a) failed");
}

 void test9255()
{
    string file;
    try
    {
        int x = 0;
        assert(x);
    }
    catch (Throwable e)
    {
        file = e.file;
    }

    version(Windows)
        assert(file && file == r"runnable\testassert.d");
    else
        assert(file && file == "runnable/testassert.d");
}

// https://issues.dlang.org/show_bug.cgi?id=20114
void test20114()
{
    // Function call returning simple type
    static int fun() {
        static int i = 0;
        assert(i++ == 0);
        return 3;
    }

    const a = getMessage(assert(fun() == 4));
    assert(a == "3 != 4");

    // Function call returning complex type with opEquals
    static struct S
    {
        bool opEquals(const int x) const
        {
            return false;
        }
    }

    static S bar()
    {
        static int i = 0;
        assert(i++ == 0);
        return S.init;
    }

    const b = getMessage(assert(bar() == 4));
    assert(b == "S() != 4");

    // Non-call expression with side effects
    int i = 0;
    const c = getMessage(assert(++i == 0));
    assert(c == "1 != 0");
}

string getMessage(T)(lazy T expr)
{
    try
    {
        expr();
        return null;
    }
    catch (Throwable t)
    {
        return t.msg;
    }
}

void main()
{
    test8765();
    test9255();
    test20114();
}
