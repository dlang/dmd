extern(C) int printf(const char*, ...);

/***************************************************/
// 8119

struct S8119;

void test8119()
{
    void* v;
    auto sp1 = cast(S8119*)v;

    int* i;
    auto sp2 = cast(S8119*)i;

    S8119* s;
    auto ip = cast(int*)s;
}

/***************************************************/
// 8645

template TypeTuple8645(TL...)
{
    alias TL TypeTuple8645;
}

void test8645()
{
    alias TypeTuple8645!(int) Foo;
    int bar;
    static assert(!is(typeof( cast(Foo)bar )));
}

/***************************************************/
// 10497

struct S10497;

void test10497(S10497** s)
{
    void* ptr;
    *s = cast(S10497*)ptr;
}

/***************************************************/
// 10646

void test10646()
{
    class C { }

    C[] csd;
    C[2] css;

    static assert(!__traits(compiles, { auto c1 = cast(C)csd; }));
    static assert(!__traits(compiles, { auto c2 = cast(C)css; }));
}

/***************************************************/
// 10793

struct RealFoo10793
{
    int i;
}

struct Foo10793;

void test10793()
{
    auto rf = RealFoo10793(10);
    void* prf = cast(void*)&rf;
    Foo10793* f = cast(Foo10793*)prf;
}

/***************************************************/
// 10834

void test10834()
{
    struct S { int i; }
    S s;
    cast(void)s;

    class C { int i; }
    C c;
    cast(void)c;

    enum E { a, b }
    E e;
    cast(void)e;

    int[] ia;
    cast(void)ia;
}

/***************************************************/

int main()
{
    test8119();
    test8645();
    test10646();
    test10793();
    test10834();

    printf("Success\n");
    return 0;
}
