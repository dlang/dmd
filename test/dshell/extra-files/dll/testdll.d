import mydll;

void main()
{
    int n1 = mydll.multiply10(2);
    version (Windows) assert(mydll.saved_var == 2);
    assert(n1 == 20);

    version (Windows) auto pvar = &mydll.saved_var;
    auto funcptr = &mydll.multiply10;

    int n2 = funcptr(4);
    version (Windows) assert(mydll.saved_var == 4);
    version (Windows) assert(*pvar == 4);
    assert(n2 == 40);

    S s;
    assert(s.add(2) == 2);
    assert(s.add(2) == 4);

    I i = I.create();
    C c = i.foo(i);
    assert(c is i);
}
