// https://github.com/dlang/dmd/issues/20842
// Expanding an empty tuple should preserve side effects

struct Tuple(T...)
{
    T expand;
}

int x = 0;
Tuple!() foo()
{
    x = 2;
    return Tuple!()();
}

void main()
{
    auto empty = foo().expand;
    assert(x == 2);
}
