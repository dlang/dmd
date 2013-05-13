// PERMUTE_ARGS:

extern(C) int printf(const char*, ...);

class Foo : Object
{
    void test() { }

    invariant()
    {
        printf("in invariant %p\n", this);
    }
}

int testinvariant()
{
    printf("hello\n");
    Foo f = new Foo();
    printf("f = %p\n", f);
    printf("f.sizeof = x%x\n", Foo.sizeof);
    printf("f.classinfo = %p\n", f.classinfo);
    printf("f.classinfo._invariant = %p\n", f.classinfo.base);
    f.test();
    printf("world\n");
    return 0;
}

/***************************************************/
// 6453

void test6453()
{
    static class C
    {
        static uint called;
        invariant() { called += 1; }
        invariant() { called += 4; }
        invariant() { called += 16; }

        void publicMember() { assert(called == 21); }
    }

    static struct S
    {
        static uint called;
        invariant() { called += 1; }
        invariant() { called += 4; }
        invariant() { called += 16; }

        void publicMember() { assert(called == 21); }
    }

    auto c = new C();
    C.called = 0;
    c.publicMember();
    assert(C.called == 42);

    auto s = new S();
    S.called = 0;
    s.publicMember();
    assert(S.called == 42);

    // Defined symbols in one invariant cannot be seen from others.
    static struct S6453
    {
        invariant()
        {
            struct S {}
            int x;
            static assert(!__traits(compiles, y));
            static assert(!__traits(compiles, z));
        }
        invariant()
        {
            struct S {}
            int y;
            static assert(!__traits(compiles, x));
            static assert(!__traits(compiles, z));
        }
        invariant()
        {
            struct S {}
            int z;
            static assert(!__traits(compiles, x));
            static assert(!__traits(compiles, y));
        }
    }
}

/***************************************************/

void main()
{
    testinvariant();
    test6453();
}
