// REQUIRED_ARGS: -preview=rvaluetype
// PERMUTE_ARGS: -O -inline

int func(@rvalue ref int p) { return 1; }
int func(@rvalue ref const int p) { return 11; }

int func(ref int p) { return 2; }
int func(ref const int p) { return 22; }

void run1a(@rvalue ref int p)
{
    assert(func(p) == 1);
    assert(func(cast(int)p) == 2);

    assert(func(cast(const)p) == 11);
    const i = cast(int)p;
    assert(func(i) == 22);
}

int gun(@rvalue ref const int) { return 1; }
int gun(ref int) { return 2; }

void run1b(@rvalue ref int p)
{
    assert(gun(p) == 1);
    assert(gun(cast(int)p) == 2);
}

void test1()
{
    assert(func(0) == 1);
    int i;
    assert(func(i) == 2);
    assert(func(cast(@rvalue)i) == 1);

    assert(func(cast(const)0) == 11);
    const int c;
    assert(func(c) == 22);
    assert(func(cast(@rvalue)c) == 11);

    run1a(0);
    run1b(0);
}

struct S2
{
    int i;
    this(int n) { i = n; }

    this(ref S2) { ++i; }
    ~this() { ++i; }
}

ref @rvalue(S2) func2(@rvalue ref S2 a, int i = 0)
{
    if (i < 20)
        return func2(a, ++i);
    return a;
}

void test2()
{
    assert(func2(S2(10)).i == 10);
    auto s = S2(2);
    assert(func2(cast(@rvalue)s).i == 2);
}

int tests()
{
    test1();
    test2();

    return 0;
}

void main()
{
    tests();
    enum _ = tests();
}
