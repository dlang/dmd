
/********************************************/

@safe
{
SafeRefCounted map(return scope SafeRefCounted r)
{
    return r;
}

struct SafeRefCounted
{
    ~this() scope { }
    int* p;
}

SafeRefCounted listdir()
{
    return map(SafeRefCounted());
}
}

/********************************************/

struct Probe
{
    ~this() { }
}

void test()
{
    staticArrayX([Probe(), Probe()]);
}

pragma(inline, true)
Probe[2] staticArrayX(Probe[2] a)
{
    return a;
}
