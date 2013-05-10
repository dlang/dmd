struct Snothrowpure
{
    nothrow ~this() pure { }
}

struct Spure
{
    pure ~this() { }
}

struct SX
{
    Snothrowpure s1;
    Spure s2;

    ~this() nothrow { }
}

void main() { }
