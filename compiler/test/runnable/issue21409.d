module issue21409;

void test1()
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
}

void test2()
{
    struct S
    {
        uint p0 = 18;
        uint p1 = 1;
    }
    S s;

    static void f1(uint c0 = s.p0, uint c1 = s.p1)
    {
        assert(c0 + c1 == 19); // fails
    }

    void f0()
    {
        f1();
    }

    f0();
}

void test3()
{
    uint p0 = 8;
    uint p1 = 9;

    static void f1(uint c0 = p0 + 1, uint c1 = p1)
    {
        assert(c0 + c1 == 18); // fails
    }

    void f0()
    {
        /* uncomment to remind the compiler
        it has to create a closure for p0 and p1 */
        // if (p0 || p1) {}

        f1();
    }

    f0();
}

// see InlineCostVisitor.visit(ThisExp)
/*void test4()
{
    struct S
    {
        uint p0 = 18;
        uint p1 = 1;

        void test()
        {
            static void f3(S vthis = this)
            {
                assert(vthis.p0 + vthis.p1 == 19);
            }

            void f2()
            {
                f3();
            }

            f2();
        }
    }
    S s;
    s.test();
}*/

void main()
{
    test1();
    test2();
    test3();
    //test4();
}
