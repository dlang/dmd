void foo(auto ref int a)
{
}

void bar(auto ref const int a)
{
}

void baz(auto ref int a)
{
}

void baz(int a)
{
}

void callAll()
{
    int lval = 1;
    enum int rval = 1;
    
    foo(lval);
    foo(rval);
    
    bar(lval);
    bar(rval);

    baz(lval);
    baz(rval);
}
