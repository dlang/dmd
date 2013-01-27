class C1
{
    int x;
    const invariant()
    {
        static assert(!__traits(compiles, x = 1));
    }
}

class C2
{
    int x;
    invariant() const
    {
        static assert(!__traits(compiles, x = 1));
    }
}

class C3
{
    int x;
    invariant()
    {
        x = 1;
    }
}
