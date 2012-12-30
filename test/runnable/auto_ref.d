int* getAddress(auto ref int a)
{
    return &a; 
}

int foo(auto ref int a)
{
    return 1;
}

int foo(int a)
{
    return 2;
}

void main()
{
    int lval = 1;
    enum int rval = 1;

    assert(getAddress(lval) == &lval);
    assert(foo(rval) == 2);
}
