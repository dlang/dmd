module issue21409;

void test()
{
    uint p0 = 8;
    uint p1 = 9;

    static void f1(uint c0 = p0, uint c1 = p1)
    {
        assert(c0 + c1 == 17); // fails
    }

    void f0()
    {
        /* uncomment to remind the compiler
        it has to create a closure for p0 and p1 */
        // if (p0 || p1) {}

        f1();
    }

    f0();

    // ---

    struct S
    {
        uint p0 = 18;
        uint p1 = 1;
    }
    S s;

    static void f3(uint c0 = s.p0, uint c1 = s.p1)
    {
        assert(c0 + c1 == 19); // fails
    }

    void f2()
    {
        f3();
    }

    f2();
}

void main()
{
    test();
}
