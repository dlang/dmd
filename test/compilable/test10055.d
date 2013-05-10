struct S1
{
    @safe ~this() pure { }
}
struct S2
{
    @trusted ~this() nothrow { }
}

struct SX1
{
    S1 s1;
    S2 s2;
}

@safe void foo()
{
    SX1 s;
}

struct SX2
{
    S1 s1;
    S2 s2;

    @safe ~this() { }
}

void main() { }
