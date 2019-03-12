struct Foo
{
    Object obj_;

    invariant (obj_ !is null);

    auto obj()
    {
        return this.obj_;
    }

    alias type = typeof(&Foo.init.obj);
}

void main()
{
    import core.exception : AssertError;

    Foo foo = Foo.init;

    try
    {
        foo.obj.toString();
    }
    catch (AssertError)
    {
    }
}
