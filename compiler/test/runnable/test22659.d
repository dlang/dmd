// https://github.com/dlang/dmd/issues/22659

int[] foo()
{
    int[4] sarr = [10, 20, 30, 40];
    int[] data = new int[4];
    cast(int[4]) data[0 .. 4] = sarr;
    return data;
}

void main()
{
    auto result = foo();
    assert(result == [10, 20, 30, 40]);
    static assert(foo() == [10, 20, 30, 40]);
}
