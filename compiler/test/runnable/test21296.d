// https://github.com/dlang/dmd/issues/21296

alias Seq(T...) = T;

struct T1
{
    int x;
    alias y = x;
    alias expand = Seq!x;
}

struct T2
{
    int _x;

    @property int x() { return _x; }

    alias y = x;
    alias expand = Seq!x;
}

void main()
{
    auto t1 = T1(1);
    assert(t1.y == 1);
    assert(t1.expand[0] == 1);

    auto t2 = T2(2);
    assert(t2.y == 2);
    assert(t2.expand[0] == 2);
}
