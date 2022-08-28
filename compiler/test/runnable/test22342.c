// https://issues.dlang.org/show_bug.cgi?id=22342

int printf(const char *, ...);
int counter = 0;

int foo()
{
    counter += 1;
    return counter;
}

int bar()
{
    counter += 2;
    return counter;
}

int main()
{
    int v;
    int res = bar(1, &v, foo(), "str", bar());
    if (res != 5)
    {
        printf("bar() = %d != 5\n", res);
        return 1;
    }
    return 0;
}
