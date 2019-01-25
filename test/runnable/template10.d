
/********************************************/

void test1()
{
    int a = 1;

    auto func(alias b)()
    {
        ++a;
        ++b;
    }

    int b = 1;
    func!b;
    assert(a == 2);
    assert(b == 2);

    auto dg = &func!b;
    dg();
    assert(a == 3);
    assert(b == 3);

    template TA(alias i) { int v = i; }
    mixin TA!a;
    assert(v == 3);
}

/********************************************/

void main()
{
    test1();
}
