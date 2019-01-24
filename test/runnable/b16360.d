// REQUIRED_ARGS: -inline

pragma(inline, true)
auto foo()
{
    static struct U
    {
        int a = 42;
        float b;
    }
    U u;
    return u.a;
}

pragma(inline, true)
T bitCast(T, S)(auto ref S s)
{
    union BitCaster
    {
        S ss;
        T tt;
    }
    BitCaster bt;
    bt.ss = s;
    return bt.tt;
}

void main()
{
    assert(foo == 42);
    assert(bitCast!int(1.0f) == 0x3f800000);
}
