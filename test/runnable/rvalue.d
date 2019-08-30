import core.stdc.stdio;

int copyCtor;
int dtor;

struct S
{
    long[4] a;

nothrow:
    this(ref S)
    {
        ++copyCtor;
        printf("copy constructor\n");
    }

    ~this()
    {
        ++dtor;
        printf("destructor\n");
    }
}

void testCopy()
{
    S a;
    S b = a;
}

void testMove()
{
    S a;
    S b = __traits(getRvalue, a);
}

void main()
{
    testCopy();
    assert(copyCtor == 1);
    assert(dtor == 2);

    copyCtor = dtor = 0;

    testMove();
    assert(copyCtor == 0);
    assert(dtor == 2);
}
