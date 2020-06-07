// https://issues.dlang.org/show_bug.cgi?id=3031
module b3031;

void test1()
{
    void*[4] ptrs;
    {extern(D) static int a; a = 1; assert(a == 1); ptrs[0] = &a; }
    {extern(D) __gshared int a; a = 2; assert(a == 2); ptrs[1] = &a; }
    {extern(C) static int a; a = 3; assert(a == 3); ptrs[2] = &a; }
    {extern(C) __gshared int a; a = 4; assert(a == 4); ptrs[3] = &a; }
    foreach (i; 0 .. 4)
        foreach (j; 0 .. 4)
    {
        if (i != j)
            assert(ptrs[i] !is ptrs[j]);
    }
}

void test2()
{
    void*[4] ptrs;
    {extern(D) static int a(){return 1;} assert(a() == 1); ptrs[0] = &a; }
    {extern(D) static int a(){return 2;} assert(a() == 2); ptrs[1] = &a; }
    {extern(C) static int a(){return 3;} assert(a() == 3); ptrs[2] = &a; }
    {extern(C) static int a(){return 4;} assert(a() == 4); ptrs[3] = &a; }
    foreach (i; 0 .. 4)
        foreach (j; 0 .. 4)
    {
        if (i != j)
            assert(ptrs[i] !is ptrs[j]);
    }
}

void test3()
{
    int[4] vals;
    { enum a = 0; vals[0] = a; }
    { enum a = 1; vals[1] = a; }
    { enum a = 2; vals[2] = a; }
    { enum a = 3; vals[3] = a; }
    foreach (i; 0 .. 4)
        foreach (j; 0 .. 4)
    {
        if (i != j)
            assert(vals[i] != vals[j]);
    }
}

void testReportedCase(int i)
{
    switch(i)
    {
        case 1:{static int j;break;}
        case 2:{static int j;break;}
        default:
    }
}

void testGenerated()
{
    template A(T)
    {
        static T a;
    }
    mixin("{static int a;}");
    mixin("{static int a;}");
    static foreach (i; 0 .. 2)
    {
        { static int a; }
        mixin("{static int a;}");
        mixin A!int;
    }
}

void testAg()
{
    void*[4] ptrs;
    { static struct A { int m; } A a; ptrs[0] = &a.m; }
    { static struct A { int m; } A a; ptrs[1] = &a.m; }
    { static struct A { int m; } A a; ptrs[2] = &a.m; }
    { static struct A { int m; } A a; ptrs[3] = &a.m; }
    foreach (i; 0 .. 4)
        foreach (j; 0 .. 4)
    {
        if (i != j)
            assert(ptrs[i] !is ptrs[j]);
    }
}

// https://issues.dlang.org/show_bug.cgi?id=18266
// no more ICE but also allowed now
void test18266()
{
    foreach (i; 0 .. 10)
    {
        struct S
        {
            int x;
        }
        auto s = S(i);
    }
    foreach (i; 11 .. 20)
    {
        struct S
        {
            int y;
        }
        auto s = S(i);
    }
}

void main()
{
    test1();
    test2();
    test3();
    testReportedCase(42);
    testGenerated();
    testAg();
    test18266();
}
