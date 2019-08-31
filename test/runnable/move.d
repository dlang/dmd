import core.stdc.stdio;

int moveCtor;
int moveAssign;

struct S
{
    long[3] a;

    __move_ctor(ref S)
    {
        ++moveCtor;
        printf("mc\n");
    }

    auto opMoveAssign(ref S)
    {
        ++moveAssign;
        printf("m=\n");
    }

    ~this()
    {
        printf("~\n");
    }
}

S get() { return S(); }

void main()
{
    S b = get();
    assert(moveCtor == 1);

    S a;
    a = get();
    assert(moveAssign == 1);
}
