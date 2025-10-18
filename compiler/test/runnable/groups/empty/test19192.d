// https://issues.dlang.org/show_bug.cgi?id=19192
interface Foo
{
    Foo covariant();
}

abstract class Frop : Foo {}

class Bar : Frop
{
    Bar covariant() { return this; }
}

shared static this()
{
    Foo foo = new Bar;
    assert(foo is foo.covariant());
}
