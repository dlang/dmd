// https://issues.dlang.org/show_bug.cgi?id=2437

struct S2437
{
    int	m;

    this(int a)
    {
        m = a;
    }
}

class C2437
{
    void fun(S2437 a = S2437(44)) { }
}

void main()
{
    C2437 a = new C2437();
    a.fun();
}
