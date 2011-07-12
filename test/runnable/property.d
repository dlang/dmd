
struct Foo
{
    int v;

    int bar(int value) { return v = value + 2; }
    int bar() { return 73; }
}

void test1()
{
    Foo f;
    int i;

    i = (f.bar = 6);
    assert(i == 8);
    assert(f.v == 8);

    i = f.bar;
    assert(i == 73);
}

/***************************************************/

@property ref const(int) bug6259() { return *(new int); }
@property void bug6259(int) {}

void test6259()
{
    bug6259 = 3;
}

/***************************************************/

void main()
{
    test1();
    test6259();
}
