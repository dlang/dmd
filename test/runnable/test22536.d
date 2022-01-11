// https://issues.dlang.org/show_bug.cgi?id=22536

void foo(T)(scope T[]) {}
void foo(T)(scope T[], scope T[]) {}

int bar()
{
    int numDtor;

    struct S
    {
        int x;
        ~this() { ++numDtor; }
    }

    foo([S(1), S(2)]);
    return numDtor;
}

int bar2()
{

    int numDtor;

    struct S
    {
        int x;
        ~this() { ++numDtor; }
    }

    foo([S(1), S(2)], [S(3), S(4)]);
    return numDtor;
}

void main()
{
    assert(bar() == 2);
    assert(bar2() == 4);
}

static assert(bar() == 2);
static assert(bar2() == 4);
