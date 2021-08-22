int printf(const char *fmt, ...);
void exit(int);

struct S
{
    int a:2, b:4;
};

_Static_assert(sizeof(struct S) == 4, "in");

void test1()
{
    struct S s;
    s.a = 3;
    if (s.a != -1)
    {
        printf("error %d\n", s.a);
        exit(1);
    }

    s.b = 4;
    if (s.b != 4)
    {
        printf("error %d\n", s.b);
        exit(1);
    }
}

/******************************************/

struct S2
{
    unsigned a:2, b:4;
};

struct S2 foo()
{
    struct S2 s = { 7, 8 };     // test struct literal expressions
    return s;
}

void test2()
{
    struct S2 s = foo();

    if (s.a != 3)
    {
        printf("error %d\n", s.a);
        exit(1);
    }

    if (s.b != 8)
    {
        printf("error %d\n", s.b);
        exit(1);
    }
}

/******************************************/

int main()
{
    test1();
    test2();

    return 0;
}
