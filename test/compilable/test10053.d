struct S1
{
    ~this() pure { }
}

struct S2
{
    S1 s;
    ~this() { }
}

void main() { }
