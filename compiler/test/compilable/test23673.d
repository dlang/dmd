// https://github.com/dlang/dmd/issues/23673

struct S
{
    int x;
    @disable this();
    this(int x) { this.x = x; }
}

class C
{
    S s;
    this(int x = 0) { s = S(x); }
}

class CT
{
    S s;
    this()(int x = 0) { s = S(x); }
}

void test()
{
    auto c = new C();
    auto c2 = new C;
    auto c3 = new C(1);
    auto ct = new CT();
}
