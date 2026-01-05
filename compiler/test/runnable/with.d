
struct S
{
    int x;
}
S s;
void main()
{
    with(auto ss = S())
    {
        x = 42;
        s.x = x;
    }
    assert(s.x == 42);
}
