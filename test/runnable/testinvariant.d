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

void test6453()
{
    static class C
    {
        static uint called;
        invariant() { called += 1; }
        invariant() { called += 4; }
        invariant() { called += 16; }

        void publicmember() {}
    }

    static struct S
    {
        static uint called;
        invariant() { called += 1; }
        invariant() { called += 4; }
        invariant() { called += 16; }

        void publicmember() {}
    }

    auto c = new C();
    C.called = 0;
    c.publicmember();
    assert(C.called == 42);

    C.called = 0;
    c.__invariant();
    assert(C.called == 21);

    auto s = new S();
    S.called = 0;
    s.publicmember();
    assert(S.called == 42);

    S.called = 0;
    s.__invariant();
    assert(S.called == 21);
}

/***************************************************/

void main()
{
    testinvariant();
    test6453();
}
