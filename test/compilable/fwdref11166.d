
template Tup11166(T...) { alias Tup11166 = T; }

struct S11166a
{
    enum S11166a a = S11166a(0);
    enum S11166a b = S11166a(1);

    this(long value) { }

    long value;

    // only triggered when private and a template instance.
    private alias types = Tup11166!(a, b);
}

struct S11166b
{
    enum S11166b a = S11166b(0);
    enum S11166b b = S11166b(1);

    // not at the last of members
    alias types = Tup11166!(a, b);

    this(long value) { }

    long value;
}
