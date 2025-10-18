struct S { int i; }

auto f()
{
    S[] ss;
    ss.length = 1;
    return 0;
}

enum a = f();

shared static this()
{
    f();
}
