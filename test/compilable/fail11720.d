void main()
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
