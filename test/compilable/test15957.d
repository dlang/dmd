// https://issues.dlang.org/show_bug.cgi?id=15957

struct S
{
    @disable this(this);

    mixin Impl;
}

template Impl ( ) 
{
    void opAssign ( int x ); 
}

void test()
{
    S s;
    s = 1;
}

