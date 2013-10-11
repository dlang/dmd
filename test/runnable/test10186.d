struct S
{
    int val;
    @disable this();
    this(int i) { val = i; }
}

class C
{
    this(int i = 10)
    {
        s = S(i);
    }

    S s;
}

void main()
{
    auto c0 = new C();
    assert(c0.s.val == 10);

    auto c1 = new C(20);
    assert(c1.s.val == 20);

    assert(typeid(C).defaultConstructor !is null);
    auto c2 = cast(C)Object.factory(__MODULE__~".C");
    assert(c2 && c2.s.val == 10);
}
