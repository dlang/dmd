void main()
{
    int* pfoo1;
    int* pfoo2;
    int* pfoo3;

    if (true ) {
        static int foo;
        pfoo1 = &foo;
        assert(0 == foo);
        ++foo;
        assert(1 == foo);
        foo = 10;
        assert(10 == foo);
    }
    assert(10 == *pfoo1);

    int i = 0;
    do {
        static int foo;
        pfoo2 = &foo;
        assert(i == foo);
        ++foo;
        ++i;
    } while (i < 10);
    assert(i == *pfoo2);

    for (int j = 0; j < 10; ++j)
    {
        static int foo;
        pfoo3 = &foo;
        assert(j == foo);
        ++foo;
    }

    assert(pfoo2 !is pfoo1);
    assert(pfoo3 !is pfoo1);
    assert(pfoo3 !is pfoo2);

    {
        static int fui;
        static void foo() { }
        void bar() { }
        interface A { }
        class tem(T) { }
        class omg { }
        struct fff { }
        alias omg OMG;
        typedef fff FFF;
    }
    {
        static int fui;
        static void foo() { }
        void bar() { }
        interface A { }
        class tem(T) { }
        class omg { }
        struct fff { }
        alias omg OMG;
        typedef fff FFF;
    }
}
