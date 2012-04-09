struct Foo
{
    void bug()
    {
        // cyclic reference
        tab["A"] = Bar(&this);
        auto pbar = "A" in tab;
        // triggers stack overflow in Expression::apply for hasSideEffect
        auto bar = *pbar;
    }

    Bar[string] tab;
}

struct Bar
{
    Foo* foo;
    int val;
}

int ctfe()
{
    auto foo = Foo();
    foo.bug();
    return 0;
}

static assert(ctfe() == 0);
