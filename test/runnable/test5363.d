struct S1
{
    int dummy;
    alias dummy this;
}

int foo(int){ return 1; }
int foo(const(S1)){ return 2; }
int foo(const(S2)){ return 3; }

class S2
{
    int dummy;
    alias dummy this;
}

void main()
{
    S1 s1;
    assert(foo(s1) == 2);

    S2 s2;
    assert(foo(s2) == 3);
}
