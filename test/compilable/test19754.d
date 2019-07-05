void main()
{
    shared int x;
    static assert((cast(int*) &x) == &(cast() x));
    (cast() x) = 5;
    (cast() x) += 3;

    const int x1;
    static assert(&x1 == &(cast() x1));
    (cast() x1) = 5;
    (cast() x1) *= 3;

    immutable int x2;
    static assert(&x2 == &(cast() x2));
    (cast() x2) = 5;
    (cast() x2) &= 3;

    int[4] a;
    (cast(long[2]) a)[0] = 5;
    (cast(long[2]) a)[0] += 3;

    static if (is(typeof(__vector(int[4]))))
    {
        __vector(int[4]) v;
        (cast(int[4]) v)[0] = 5;
        (cast(int[4]) v)[0] += 3;
    }
}
