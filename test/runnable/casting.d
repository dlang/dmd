extern(C) int printf(const char*, ...);

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

int main()
{
    test8645();

    printf("Success\n");
    return 0;
}
