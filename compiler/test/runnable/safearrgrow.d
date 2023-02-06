// REQUIRED_ARGS:  -d
struct S
{
    string[] a;
    @safe void reserve() scope
    {
        a.length += 1;
    }
}

void main()
{
    S s;
    s.reserve;
    assert(s.a.length >= 1);
}
