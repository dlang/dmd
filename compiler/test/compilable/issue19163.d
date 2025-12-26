struct NameAttribute
{
    int delegate() foo;
}

static NameAttribute getNamedAttribute(alias S)()
{
    return __traits(getAttributes, S)[0];
}

struct MyStruct
{
    @NameAttribute({ return 42; }) int a;
}

void main()
{
    MyStruct m;
    enum nameAttr = getNamedAttribute!(m.a);
}
