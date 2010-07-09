// 402

template Foo(alias b)
{
    int a() { return b; }
}

void main()
{
    mixin Foo!(y) y;
}
