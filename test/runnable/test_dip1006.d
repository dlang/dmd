// REQUIRED_ARGS: -release=in,out,invariant
// PERMUTE_ARGS:
class C
{
    int foo(int a)
    in { assert(a != 0); } // skipped
    out(res) { assert(res != 0); } // skipped
    body
    {
        return a;
    }

    invariant // skipped
    {
        assert(false);
    }

    void bar(int a)
    {
        assert(a != 0); // triggered
    }
}

void main()
{
    import core.exception : AssertError;

    auto c = new C;
    c.foo(0);

    bool catched;
    try
        c.bar(0);
    catch (AssertError e)
        catched = true;
    if (!catched)
        assert(0);
}
