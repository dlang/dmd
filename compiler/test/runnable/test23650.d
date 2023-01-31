__gshared int x;

// https://issues.dlang.org/show_bug.cgi?id=23650
void test23650()
{

    static assert(__traits(compiles,
    {
        struct S { int *p = &x; }
        auto t = typeid(S);
    }));
}

// https://issues.dlang.org/show_bug.cgi?id=23661
void foo(T)()
{
    auto x = typeid(T);
}

void test23661()
{
    static assert(__traits(compiles,
    {
        struct S { int *p = &x; }
        foo!S();
    }));
}

void main()
{
    test23650();
    test23661();
}
