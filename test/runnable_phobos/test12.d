// PERMUTE_ARGS: -unittest -O -release -inline -fPIC -g

extern(C) int printf(const char*, ...);

/**************************************/

struct Shell
{
    string str;

    const int opCmp(ref const Shell s)
    {
        import std.algorithm;
        return std.algorithm.cmp(this.str, s.str);
    }
}

void test45()
{
    import std.algorithm;

    Shell[3] a;

    a[0].str = "hello";
    a[1].str = "betty";
    a[2].str = "fred";

    a[].sort;

    foreach (Shell s; a)
    {
        printf("%.*s\n", cast(int)s.str.length, s.str.ptr);
    }

    assert(a[0].str == "betty");
    assert(a[1].str == "fred");
    assert(a[2].str == "hello");
}

/**************************************/

int main(string[] argv)
{
    test45();

    printf("Success\n");
    return 0;
}

