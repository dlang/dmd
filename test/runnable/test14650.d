int a = 0;

struct S
{ ~this() { ++a; } }


static ~this()
{
    assert(a == 1);
}

S s;
void main()
{
}
