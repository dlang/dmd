
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

class C2
{
    int m = 10;

    class K(alias a)
    {
        int n;
        this(int i) { n = i; }
        auto sum()
        {
            return a + m + n;
        }
    }
}

void test2()
{
    int a = 20;
    auto o = new C2;
    auto k = o.new C2.K!a(30);
    assert(k.sum() == 10+20+30);
}

/********************************************/

void main()
{
    test1();
    test2();
}
