
auto makeAA()
{
    return
    [
        1 : 2,
        2 : 3,
        3 : 4,
        4 : 5,
        5 : 6,
        6 : 7,
        7 : 8,
        8 : 9,
        9 : 10,
    ];
}


struct testAA(T, U)
{
    static void testAA(T key, U value)()
    {
        static a = [key : value];
        auto b = [key : value];
        assert(a == b);
    }
}

alias TT(T...) = T;

void main()
{
    static a = makeAA();
    auto b = makeAA();

    assert(a == b);

    foreach(V; TT!(char, wchar, dchar, byte, ubyte, short, ushort, int, uint))
    {
        testAA!(int, V).testAA!(1, 1)();
    }
}
