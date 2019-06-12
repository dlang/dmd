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

// https://issues.dlang.org/show_bug.cgi?id=519
class C519
{
    invariant
    {
        printf("C519.invariant\n");
        ++x;
    }
    __gshared int x;
}

struct S519
{
    invariant()
    {
        printf("S519.invariant\n");
        ++x;
    }
    __gshared int x;
}

struct S519c
{
    invariant()
    {
        printf("S519c.invariant\n");
        ++x;
    }
    __gshared int x;
    int y;
}

void test519()
{
    //printf("test1\n");
    {
        auto foo = new C519();
        assert(C519.x == 0);
        printf("lifetime of foo\n");
        destroy(foo);
        assert(C519.x == 1);
    }
    {
        scope auto foo = new C519();
        assert(C519.x == 1);
        printf("lifetime of foo\n");
    }
    assert(C519.x == 2);

    //printf("test2\n");
    {
        auto foo = new S519();
        printf("%d\n", S519.x);
        assert(S519.x == 0);
        printf("lifetime of foo\n");
        destroy(*foo);
        assert(S519.x == 1);
    }
    {
        auto foo = S519();
        assert(S519.x == 1);
        printf("lifetime of foo\n");
    }
    assert(S519.x == 2);

    //printf("test3\n");
    {
        auto foo = new S519c(1);
        assert(S519c.x == 1);
        printf("lifetime of foo\n");
    }
    {
        auto foo = S519c(1);
        assert(S519c.x == 2);
        printf("lifetime of foo\n");
    }
    assert(S519c.x == 3);
}

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=6453

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

    static struct S6453a
    {
        pure    invariant() {}
        nothrow invariant() {}
        @safe   invariant() {}
    }
    static struct S6453b
    {
        pure    shared invariant() {}
        nothrow shared invariant() {}
        @safe   shared invariant() {}
    }
    static class C6453c
    {
        pure    synchronized invariant() {}
        nothrow synchronized invariant() {}
        @safe   synchronized invariant() {}
    }
}

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=13113

struct S13113
{
    static int count;
    invariant() // impure, throwable, system, and gc-able
    {
        ++count;    // impure
    }

    this(int) pure nothrow @safe @nogc {}
    // post invaiant is called directly but doesn't interfere with constructor attributes

    ~this() pure nothrow @safe @nogc {}
    // pre invaiant is called directly but doesn't interfere with destructor attributes

    void foo() pure nothrow @safe @nogc {}
    // pre & post invariant calls don't interfere with method attributes
}

void test13113()
{
    assert(S13113.count == 0);
    {
        auto s = S13113(1);
        assert(S13113.count == 1);
        s.foo();
        assert(S13113.count == 3);
    }
    assert(S13113.count == 4);
}

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=13147

version (D_InlineAsm_X86)
    enum x86iasm = true;
else version (D_InlineAsm_X86_64)
    enum x86iasm = true;
else
    enum x86iasm = false;

class C13147
{
    extern (C++) C13147 test()
    {
        static if (x86iasm)
            asm { naked; ret; }
        return this;
    }
}

struct S13147
{
    void test()
    {
        static if (x86iasm)
            asm { naked; ret; }
    }
}

void test13147()
{
    auto c = new C13147();
    c.test();
    S13147 s;
    s.test();
}


/***************************************************/

void main()
{
    testinvariant();
    test519();
    test6453();
    test13113();
    test13147();
}
