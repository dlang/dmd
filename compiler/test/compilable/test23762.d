// https://github.com/dlang/dmd/issues/23762

struct S
{
    enum e = __traits(compiles, S(0));
    this(T)(T n) {}
}

static assert(S.e);

void main()
{
    auto x = S(1);
}
