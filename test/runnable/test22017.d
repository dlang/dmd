// https://issues.dlang.org/show_bug.cgi?id=22017

struct S
{
    bool destroyed;
    ~this() { destroyed = true; }
    ref S foo() return { return this; }
}

void main()
{
    with (S().foo)
    {
        assert(!destroyed);
    }
}
