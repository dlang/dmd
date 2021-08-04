import mydll;

void test1()
{
    int n1 = mydll.multiply10(2);
    version (Windows) assert(mydll.saved_var == 2);
    assert(n1 == 20);
}

void test2()
{
    version (Windows) auto pvar = &mydll.saved_var;
    auto funcptr = &mydll.multiply10;

    int n2 = funcptr(4);
    version (Windows) assert(mydll.saved_var == 4);
    version (Windows) assert(*pvar == 4);
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

void main()
{
    test1();
    test2();
    test3();
    test9729();
    test10462();
}
