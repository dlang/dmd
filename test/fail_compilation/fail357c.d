void fail357()
{
    // symbol collision
    import Foo = imports.fail357a;
    import imports.fail357b : Foo;
    alias Foo.foo fun;
}
