// REQUIRED_ARGS: -o-
// PERMUTE_ARGS:

struct Foo
{
    uint val;
    alias val this;
}

void test13820()
{
    int n = 1;
    auto foo = Foo(2);

    switch (foo)
    {
        case n: break;
        case foo: break;
        case Foo(3): break;
        default: break;
    }
}
