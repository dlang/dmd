

struct S
{
    int x;
    int* p;
}


void test(const(S) s, const(int) i)
{
    immutable int j = 3;
    j = 4;
    i = 4;
    s.x = 3;
    *s.p = 4;
}
