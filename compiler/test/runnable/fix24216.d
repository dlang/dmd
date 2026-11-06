struct S
{
    int x;

    ref S byRef() return
    {
        return x == 1
            ? this
            : throw new Exception("Test");
    }
}

void main()
{
    S s;
    s.x = 1;

    auto s2 = s.byRef();
    s2.x = 2;
    assert(s.x == 2);
}
