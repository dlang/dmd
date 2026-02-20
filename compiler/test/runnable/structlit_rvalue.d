struct S22585_1
{
    char[32] a;
    int b = 1;

    this(ref S22585_1 s)
    {
        s.b = 2;
    }
}

struct T22585_1
{
    S22585_1 s;
}

void copyConstruct(S22585_1) {}

void mutate(ref S22585_1 s)
{
    s.b = 2;
}

struct S22585_2
{
    char[32] a;
    int b = 1;
    ~this() {}
}

struct T22585_2
{
    S22585_2 s;
}

pragma(inline, true)
S22585_2 inlinedRvalue1()
{
    bool b;
    return (b ? T22585_2.init : T22585_2.init).s;
}

void mutateCopyOf(S22585_2 s)
{
    s.b = 2;
}

pragma(inline, true)
S22585_2 inlinedRvalue2()
{
    return S22585_2.init;
}

void assignCopyOf(S22585_2 s)
{
    s = S22585_2.init;
}

void main()
{
    bool b;
    copyConstruct((b ? T22585_1.init : T22585_1.init).s);
    mutate((b ? T22585_1.init : T22585_1.init).s);
    mutateCopyOf(inlinedRvalue1());
    inlinedRvalue2.b = 2;
    assignCopyOf(S22585_2.init);
}
