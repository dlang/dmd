// PERMUTE_ARGS:
struct Foo
{
    Object obj_;

    invariant (obj_ !is null);

    auto obj7()
    {
        return this.obj_;
    }

    enum compiles = __traits(compiles, &Foo.init.obj7);
}

class Foo2
{
    Object obj_;

    invariant (obj_ !is null);

    final auto obj7()
    {
        return this.obj_;
    }

    enum compiles = __traits(compiles, &Foo.init.obj7);
}

void main()
{
    import core.exception : AssertError;
    Foo foo = Foo();
    Foo2 foo2 = new Foo2();

    try
    {
        foo.obj7.toString();
    }
    catch(AssertError)
    {
        try
        {
            foo2.obj7.toString();
        }
        catch(AssertError)
        {
            return;
        }
        assert(0);
    }
    assert(0);
}
