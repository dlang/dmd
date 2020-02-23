/*
REQUIRED_ARGS: -checkaction=context -dip25 -dip1000
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

void test20375() @safe
{
    static struct RefCounted
    {
        // Force temporary through "impure" generator function
        static RefCounted create() @trusted
        {
            __gshared int counter = 0;
            return RefCounted(++counter > 0);
        }

        static int instances;

        this(bool) @safe
        {
            instances++;
        }

        this(this) @safe
        {
            instances++;
        }

        ~this() @safe
        {
            assert(instances > 0);
            instances--;
        }

        bool opEquals(RefCounted) @safe
        {
            return true;
        }
    }

    {
        auto a = RefCounted.create();
        assert(a == RefCounted.create());
    }

    assert(RefCounted.instances == 0);

    {
        auto a = RefCounted.create();
        const msg = getMessage(assert(a != RefCounted.create()));
        // assert(msg == "RefCounted() == RefCounted()"); // Currently not formatted
        assert(msg == "assert(a != RefCounted.create()) failed");
    }

    assert(RefCounted.instances == 0);
}

string getMessage(T)(lazy T expr) @trusted
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
    test20375();
}
