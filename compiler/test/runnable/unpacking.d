/*
REQUIRED_ARGS: -preview=tuples
*/

// test unpacking works with custom struct
struct Tuple(T...)
{
    T expand;
    alias this = expand;
}
auto tuple(T...)(T args) => Tuple!T(args);

void main()
{
    auto (x, const y, z) = tuple(1, 2L, "three");
    static assert(is(typeof(x) == int));
    static assert(is(typeof(y) == const long));
    static assert(is(typeof(z) == string));
    assert(x == 1);
    assert(y == 2L);
    assert(z == "three");

    (string a, int b) = tuple("four", 5);
    assert(a == "four");
    assert(b == 5);

    // foreach unpacking
    auto tc = tuple(0, "");
    foreach ((i, s); [tuple(1, "one"), tuple(2, "two")])
    {
        tc[0] += i;
        tc[1] ~= s;
    }
    assert(tc[0] == 3);
    assert(tc[1] == "onetwo");

    // foreach over a range
    struct R
    {
        auto a = [tuple(2L, '5'), tuple(4L, '6'), tuple(1L, '7')];
        auto front() => a[0];
        auto empty() => !a.length;
        void popFront() { a = a[1..$]; }
    }
    Tuple!(long[], string) tr;
    // specify element types
    foreach ((long i, char ch); R())
    {
        tr[0] ~= i;
        tr[1] ~= ch;
    }
    assert(tr[0] == [2, 4, 1]);
    assert(tr[1] == "567");

    // unpack sequence
    alias Seq(E...) = E;
    const (c, d) = Seq!(false, byte(4));
    static assert(is(typeof(c) == const bool));
    static assert(is(typeof(d) == const byte));
    assert(!c);
    assert(d == 4);
}
