struct S
{
    ~this()
    {
        assert(false);
    }
}

void lazily(lazy S)
{
}

shared static this()
{
    lazily(S());
}
