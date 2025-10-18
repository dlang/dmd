struct S0
{
    int x = void;
}
struct S1
{
    S0  x = S0(42);
}
shared static this()
{
    S1  x;
    assert(x.x.x == 42);
}
