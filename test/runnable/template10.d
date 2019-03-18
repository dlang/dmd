
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

struct S3
{
    int m;
    auto exec(alias f)()
    {
        f(m);
    }
}

void test3()
{
    int a = 1;

    auto set(alias b)(int c) { b = c; }

    S3(10).exec!(set!a)();
    assert(a == 10);

    auto dg = &S3(20).exec!(set!a);
    dg();
    assert(a == 20);
}

/********************************************/

struct S4
{
    int m;

    auto add(alias a)(int b)
    {
        return a + m + b;
    }

    auto inner(alias a)(int i)
    {
        class I
        {
            int n;
            this() { n = i; }
            auto add(int b)
            {
                return a + n + m + b;
            }
            auto add2(alias c)(int b)
            {
                return a + n + m + b + c;
            }
        }
        return new I;
    }
}

void test4i(T)(T i)
{
    int b = 2;

    assert(i.add(7) == 5+1+6+7);
    auto dg = &i.add;
    assert(dg(8) == 5+1+6+8);

    assert(i.add2!b(7) == 5+1+6+7+2);
    auto dg2 = &i.add2!b;
    assert(dg2(8) == 5+1+6+8+2);
}

auto get4i(int a)
{
    return S4(5).inner!a(6);
}

void test4()
{
    int a = 1;

    assert(S4(4).add!a(10) == 4+1+10);

    auto dg = &S4(4).add!a;
    assert(dg(11) == 4+1+11);

    auto i = get4i(a);
    test4i(i);

    // type checking
    auto o0 = S4(10);
    auto o1 = S4(11);
    alias T0 = typeof(o0.inner!a(1));
    alias T1 = typeof(o1.inner!a(1));
    static assert(is(T0 == T1));
}

/********************************************/

struct S5
{
    int m;
    auto add(alias f)(int a)
    {
        auto add(int b) { return a + b; }
        return exec2!(f, add)();
    }
    auto exec2(alias f, alias g)()
    {
        return g(f(m));
    }
}

void test5()
{
    int a = 10;
    auto o = S5(1);
    auto fun(int m) { return m + a; }
    assert(o.add!fun(20) == 1+10+20);
}

/********************************************/

void main()
{
    test1();
    test2();
    test3();
    test4();
    test5();
}
