/* TEST_OUTPUT:
---
Foo
Bar
~Baz
Foo
Foo
---
*/
class Foo
{
    void opDispatch(string name)() { pragma(msg, "Foo"); }
}
class Bar
{
    void opDispatch(string name)() { pragma(msg, "Bar"); }
}
class Baz
{
}

void main()
{
    auto foo = new Foo;
    auto bar = new Bar;
    auto baz = new Baz;

    with (foo)
    {
        f0();
        with (bar)
        {
            f1();
        }
        with (baz)
        {
            pragma(msg, "~Baz");
            static assert(__traits(compiles, f2()));
            static assert(__traits(compiles, f3()));
        }
    }
}
