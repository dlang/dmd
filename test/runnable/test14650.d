int a = 0;

struct S
{ ~this() { ++a; } }


static ~this()
{
    assert(a == 2);
}

S s;
void main()
{
    static S s;
} 
