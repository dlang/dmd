// https://issues.dlang.org/show_bug.cgi?id=19818

struct S
{
    bool delegate(string) f;
}

@S(str => true)
int a;

S s = S(str => true);

struct S2
{
    @S(str => false)
    int a;
}
