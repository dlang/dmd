// https://issues.dlang.org/show_bug.cgi?id=11720

void test11720()
{
    foo();
    bar();
}

alias TypeTuple(T...) = T;

void foo()()
{
    foreach (T; TypeTuple!(int, double))
    {
        static temp = T.stringof;
    }
}

void bar()
{
    foreach (T; TypeTuple!(int, double))
    {
        static temp = T.stringof;
    }
}

/*********************************************/

// https://issues.dlang.org/show_bug.cgi?id=18266

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

