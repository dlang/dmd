// https://issues.dlang.org/show_bug.cgi?id=20687

struct S
{
    void foo(){}
}

void main()
{
    S i;
    enum fp = &S.foo;
    auto dg = &i.foo;
    static immutable dgfp = &S.foo; // Allow this
    assert(fp == dg.funcptr && fp == dgfp);
}
