// Copy of fail_compilation/fail19103.d for testing public import inside mixin template. See:
// https://issues.dlang.org/show_bug.cgi?id=21539

void main()
{
    (new C).writeln("OK.");
    S1 s1;
    s1.writeln("OK.");
    S2 s2;
    s2.writeln("OK.");
}

mixin template T()
{
    public import std.stdio;
}

class C
{
    mixin T;
}
struct S1
{
    mixin T;
}

struct S2
{
    public import std.stdio;
}
