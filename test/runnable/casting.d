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

int main()
{
    test8119();
    test8645();
    test10646();

    printf("Success\n");
    return 0;
}
