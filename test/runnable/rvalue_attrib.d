// REQUIRED_ARGS: -preview=rvalueattribute
// PERMUTE_ARGS: -inline -O

struct S
{
    int ref_;
    int rvalueref;

    void f(@rvalue ref int) { ++rvalueref; }
    void f(ref int) { ++ref_; }
}

@rvalue ref int get(ref int a)
{
    return cast(@rvalue ref) a;
}

void test()
{
    S s;

    s.f(0);
    assert(s.rvalueref == 1);

    int i;
    s.f(i);
    assert(s.ref_ == 1);

    i = 10;
    assert(get(i) == i);

    s.f(get(i));
    assert(s.rvalueref == 2);

    s.f(cast(@rvalue ref) i);
    assert(s.rvalueref == 3);
}

ref get2(@rvalue ref int a)
{
    return a;
}

void test2()
{
    int a;
    assert(&a == &get2(cast(@rvalue ref)a));
}

@rvalue ref int f3(@rvalue ref int a)
in(a == 10)
out(r; a == 10 && r == a)
do { return cast(@rvalue ref)a; }

void test3()
{
    assert(f3(10) == 10);
    int a = 10;
    assert(&a == &f3(cast(@rvalue ref)a));
}

int tests()
{
    test();
    test2();
    test3();

    return 0;
}

void main()
{
    tests();
    enum _ = tests();
}
