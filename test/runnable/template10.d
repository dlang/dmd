// PERMUTE_ARGS: -inline

/********************************************/

void test1a()
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

auto test1b()
{
    auto f(alias a)() { return a; }

    auto f0()
    {
        int a = 10;
        return f!a();
    }
    assert(f0() == 10);
}

template t1c(alias a)
{
    template u(alias b)
    {
        template v(alias c)
        {
            auto sum()
            {
                return a + b + c;
            }
        }
    }
}

void test1c()
{
    int c = 3;
    auto f0()
    {
        int a = 1;
        auto f1()
        {
            int b = 2;
            auto r = t1c!a.u!b.v!c.sum();
            assert(r == 6);
        }
    }
}

void test1()
{
    test1a();
    test1b();
    test1c();
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
    if (__ctfe)
        return; // nested classes not yet ctfeable

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
    if (__ctfe)
        return; // nested classes not yet ctfeable

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
// inline tests

void test6a()
{
    if (__ctfe)
        return; // nested classes not yet ctfeable

    int i = 10;
    int j, k;

    class A
    {
        auto makeR(alias a)()
        {
            int m = 1;
            class O
            {
                class R
                {
                    pragma(inline, true)
                    final auto inc(alias v)()
                    {
                        ++v;
                        ++m;
                        ++i;
                    }
                    auto getM() { return m; }
                }
            }
            return new O().new R();
        }
    }

    auto a = new A;
    auto r = a.makeR!j();
    r.inc!k();          // inlined
    assert(i == 11);
    assert(k == 1);
    assert(r.getM == 2);
}


auto get6b()
{
    struct S
    {
        auto f0(alias a)()
        {
            auto seta(int m) {
                pragma(inline, true);
                a = m;
            }

            struct T(alias f)
            {
                int m = 10;
                void exec()
                {
                    f(m); // inlined
                }
            }
            return T!seta();
        }
    }
    return S();
}

void test6b()
{
    int a = 1;
    auto s = get6b();
    auto t = s.f0!a();
    t.exec();
    assert(a == 10);
}

struct S6c
{
    int m;
    auto exec(alias f)()
    {
        return f(); // inlined
    }
}

void test6c()
{
    int a;

    auto f0()
    {
        auto f()
        {
            pragma(inline, true);
            return ++a;
        }

        auto s = S6c();
        s.exec!f();
        assert(a == 1);
    }

    f0();
}

void test6()
{
    test6a();
    test6b();
    test6c();
}

/********************************************/

class C7
{
    int m = 10;
    template A(alias a)
    {
        template B(alias b)
        {
            template C(alias c)
            {
                auto sum()
                {
                    return a + b + c + m;
                }
                class K
                {
                    int n;
                    this(int i) { n = i; }
                    auto sum()
                    {
                        return a + b + c + m + n;
                    }
                }
            }
        }
    }
}

void test7()
{
    if (__ctfe)
        return; // nested classes not yet ctfeable

    auto a = 1;
    auto b = 2;
    auto c = 3;

    assert(new C7().A!a.B!b.C!c.sum() == 1+2+3+10);
    assert(new C7().new C7.A!a.B!b.C!c.K(20).sum() == 1+2+3+10+20);
}

/********************************************/

interface I8
{
    int get();
    int sub(alias v)()
    {
        return get() - v;
    }
}

class A8
{
    int m;
    this(int m)
    {
        this.m = m;
    }
    this() {}
}

class B8 : A8, I8
{
    this(alias i)()
    {
        super(i);
    }
    auto add(alias v)()
    {
        return super.m + v;
    }
    int get()
    {
        return m;
    }
    this() {}
}

void test8()
{
    int a = 4;
    int b = 2;
    auto o = new B8;
    o.__ctor!a;
    assert(o.m == 4);
    assert(o.add!b == 4+2);
    assert(o.sub!b == 4-2);
}

/********************************************/

struct A9
{
    int m;
    auto add(alias a)()
    {
        m += a;
    }
}

struct B9
{
    int i;
    A9 a;
    alias a this;
}

struct S9
{
    int j;
    B9 b;
    alias b this;
}

void test9()
{
    int a = 9;
    auto o = S9(1, B9(1, A9(10)));
    o.add!9();
    assert(o.b.a.m == 10+9);
}

/********************************************/

struct S10
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

void test10()
{
    int a = 10;
    auto o = S10(1);
    auto fun(int m) { return m + a; }
    assert(o.add!fun(20) == 1+10+20);
}

/********************************************/

struct S11
{
    int m;
    S11 getVal(alias a)()
    {
        return this;
    }
    ref getRef(alias a)()
    {
        return this;
    }
}

void test11()
{
    int a;
    auto s = S11(1);

    if (__ctfe)
    {
        // 'this' is currently only
        // returned by ref in __ctfe
    }
    else
    {
        ++s.getVal!a().m;
        assert(s.m == 1);
    }

    ++s.getRef!a().m;
    assert(s.m == 2);
}

/********************************************/

class B12
{
    int m;

    auto sum(alias a)()
    {
        return a + m;
    }

    auto inner(alias a)()
    {
        class I
        {
            int i = 20;
            auto sum()
            {
                return i + a;
            }
        }
        return new I();
    }

    class R(alias a)
    {
        int i = 30;
        auto sum()
        {
            return i + a;
        }
    }
}

class N12
{
    int n;

    auto sum()
    {
        auto o = new B12();
        o.m = 10;
        return o.sum!n();
    }

    auto sumi()
    {
        auto o = new B12();
        return o.inner!n().sum();
    }

    auto sumr()
    {
        auto o = new B12().new B12.R!n;
        return o.sum();
    }
}

void test12a()
{
    int i = 10;
    class A(alias a)
    {
        int sum()
        {
            return a + i;
        }
    }

    class B
    {
        int n;
        int sum()
        {
            return new A!n().sum();
        }
    }

    auto b = new B();
    b.n = 1;
    assert(b.sum() == 11);
}

void test12()
{
    auto o = new N12();
    o.n = 1;
    assert(o.sum() == 11);

    if (!__ctfe) // nested classes not yet ctfeable
    {
        assert(o.sumi() == 21);
        assert(o.sumr() == 31);
        test12a();
    }
}

/********************************************/

auto getC13a()
{
    int i = 10;

    auto makeC() // should be a closure
    {
        int j;
        auto incJ() { ++j; }

        class C
        {
            auto getI(alias a)()
            {
                return i;
            }
        }

        return new C();
    }
    return makeC();
}

auto test13a()
{
    if (__ctfe)
        return; // nested classes not yet ctfeable

    int a;
    auto c = getC13a();

    function()
    {
        // clean stack
        pragma(inline, false);
        long[0x500] a = 0;
    }();

    assert(*cast(size_t*)c.outer != 0); // error: frame of getC.makeC wasn't made a closure
    auto i = c.getI!a(); // segfault
}

void test13b()
{
    if (__ctfe)
        return; // nested classes not yet ctfeable

    auto getC()
    {
        int i = 10; // error: value lost, no closure made

        auto fun(alias a)()
        {
            return i;
        }

        class C
        {
            int n;
            auto getI()
            {
                return fun!n();
            }
        }
        return new C();
    }

    auto c = getC();
    assert(c.getI() == 10);
}

void test13()
{
    test13a();
    test13b();
}

/********************************************/

int runTests()
{
    test1();
    test2();
    test3();
    test4();
    test5();
    test6();
    test7();
    test8();
    test9();
    test10();
    test11();
    test12();
    test13();
    return 0;
}

void main()
{
    runTests();          // runtime
    enum _ = runTests(); // ctfe
}
