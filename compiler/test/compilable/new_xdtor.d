// https://github.com/dlang/dmd/issues/22609
struct S
{
    private ~this() {}
}

void f()
{
    auto x = new S;
}
