// REQUIRED_ARGS: -preview=dip1000
// Issue 20674 - [DIP1000] inference of `scope` is easily confused
// https://issues.dlang.org/show_bug.cgi?id=20674

int* f()(int* p)
{
    static int g;
    g = 0; // do not infer pure

    auto p2 = p;
    return new int;
}

int* g() @safe
{
    int x;
    return f(&x);
}
