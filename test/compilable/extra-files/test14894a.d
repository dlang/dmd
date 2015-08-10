module imports.test14894a;

mixin template Protocol()
{
    void onReceive() {}
}

struct Foo
{
    mixin Protocol!();

    unittest
    {
    }
}
