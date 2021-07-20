void main()
{
    enum E1{ e1, e2, e3 }

    int i;
    foreach (e; E1.tupleof)
        assert(e == i++);

    enum E2{ e1 = 0, e2 = 2, e3 = 4 }
    foreach (j, e; E2.tupleof)
        assert(e == j * 2);

    static foreach (e; E1.tupleof)
        static assert(e + 1);

    static foreach (j, e; E1.tupleof)
        static assert(j == e);

}
