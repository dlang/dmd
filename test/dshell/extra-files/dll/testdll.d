import mydll;

void test1()
{
    int n1 = mydll.multiply10(2);
    assert(mydll.saved_var == 2);
    assert(n1 == 20);
}

void test2()
{
    auto pvar = &mydll.saved_var;
    auto funcptr = &mydll.multiply10;

    int n2 = funcptr(4);
    assert(mydll.saved_var == 4);
    assert(*pvar == 4);
    assert(n2 == 40);
}

void test3()
{
    S s;
    assert(s.add(2) == 2);
    assert(s.add(2) == 4);
}

void test9729()
{
    I9729 i = I9729.create();
    C9729 c = i.foo(i);
    assert(c is i);
}

void test10462()
{
    test10462_dll();
}

// https://issues.dlang.org/show_bug.cgi?id=19660
extern (C)
{
    export extern __gshared int someValue19660;
    export void setSomeValue19660(int v);
    export int getSomeValue19660();
}

extern (C++)
{
    export extern __gshared int someValueCPP19660;
    export void setSomeValueCPP19660(int v);
    export int getSomeValueCPP19660();
}

void test19660()
{
    assert(someValue19660 == 0xF1234);
    assert(getSomeValue19660() == 0xF1234);
    setSomeValue19660(100);
    assert(someValue19660 == 100);
    assert(getSomeValue19660() == 100);
    someValue19660 = 200;
    assert(someValue19660 == 200);
    assert(getSomeValue19660() == 200);

    assert(someValueCPP19660 == 0xF1234);
    assert(getSomeValueCPP19660() == 0xF1234);
    setSomeValueCPP19660(100);
    assert(someValueCPP19660 == 100);
    assert(getSomeValueCPP19660() == 100);
    someValueCPP19660 = 200;
    assert(someValueCPP19660 == 200);
    assert(getSomeValueCPP19660() == 200);
}

void main()
{
    test1();
    test2();
    test3();
    test9729();
    test10462();
    test19660();
}
