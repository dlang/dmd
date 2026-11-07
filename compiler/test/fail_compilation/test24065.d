// https://issues.dlang.org/show_bug.cgi?id=24065

int delegate() @safe dg;

void f(ref int r) @safe
{
    int x;
    dg = () => x + r;
}
