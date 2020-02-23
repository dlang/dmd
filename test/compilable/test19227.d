// https://issues.dlang.org/show_bug.cgi?id=19227

struct S
{
    float f;
}

struct T
{
    cfloat cf;
}

void main()
{
    static assert(S.init is S.init);
    static assert(S.init != S.init);

    static assert(T.init is T.init);
    static assert(T.init != T.init);
}

