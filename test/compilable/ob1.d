
@live int* foo1(int* p)
{
    return p;
}

@live int* foo2()
{
    int* p = null;
    return p;
}

@live int* foo3(int* p)
{
    scope int* q = p;
    return p;
}

@live int* foo4(int* p)
{
    scope int* bq = p;
    scope const int* cq = p;
    return p;
}

