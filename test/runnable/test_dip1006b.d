// REQUIRED_ARGS: -release=in,invariant
// PERMUTE_ARGS:
class C
{
    int foo(int a)
    in { assert(a != 0); } // skipped
    out(res) { assert(res != 0, "out"); } // triggered
    body
    {
        return a;
    }

    invariant // skipped
    {
        assert(false);
    }
}

void main()
{
    import core.exception : AssertError;

    auto c = new C;
    bool catched;
    try
        c.foo(0);
    catch (AssertError e)
        catched = e.msg == "out";

    if (!catched)
        assert(0);
}
