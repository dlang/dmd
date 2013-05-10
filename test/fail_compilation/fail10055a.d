struct Ssafe
{
    @safe ~this() { }
}

struct Strusted
{
    ~this() @trusted { }
}

struct S
{
    ~this() { }
}

struct SX
{
    Ssafe s1;
    Strusted s2;
    S s3;

    ~this() @safe { }
}

void main() { }
