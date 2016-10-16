import mydll;

int main()
{
    int n1 = mydll.multiply10(2);
    assert(mydll.saved_var == 2);
    assert(n1 == 20);

    auto pvar = &mydll.saved_var;
    auto funcptr = &mydll.multiply10;

    int n2 = funcptr(4);
    assert(mydll.saved_var == 4);
    assert(*pvar == 4);
    assert(n2 == 40);

    return 0;
}
