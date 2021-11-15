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

struct S3
{
    int i1;
    unsigned a:2, b:4, c:6;
    int i2;
};

_Static_assert(sizeof(struct S3) == 12, "in");

struct S3 s3 = { 63, 7, 8 };

void test3()
{
    if (s3.i1 != 63)
    {
        printf("test3 1 %d\n", s3.i1);
        exit(1);
    }

    if (s3.a != 3)
    {
        printf("test3 2 %d\n", s3.a);
        exit(1);
    }

    if (s3.b != 8)
    {
        printf("test3 3 %d\n", s3.b);
        exit(1);
    }

    if (s3.c != 0)
    {
        printf("test3 4 %d\n", s3.c);
        exit(1);
    }

    if (s3.i2 != 0)
    {
        printf("test3 5 %d\n", s3.i2);
        exit(1);
    }
}

/******************************************/

struct S4
{
    int i1;
    unsigned a:2, b:31;
};

_Static_assert(sizeof(struct S4) == 12, "in");

struct S4 s4 = { 63, 7, 8 };

void test4()
{
    if (s4.i1 != 63)
    {
        printf("test4 1 %d\n", s4.i1);
        exit(1);
    }

    if (s4.a != 3)
    {
        printf("test4 2 %d\n", s4.a);
        exit(1);
    }

    if (s4.b != 8)
    {
        printf("test4 3 %d\n", s4.b);
        exit(1);
    }
}

/******************************************/

struct S5
{
    int i1;
    unsigned a:2, :0, b:5;
};

_Static_assert(sizeof(struct S5) == 12, "in");

struct S5 s5 = { 63, 7, 8 };

void test5()
{
    if (s5.i1 != 63)
    {
        printf("test5 1 %d\n", s5.i1);
        exit(1);
    }

    if (s5.a != 3)
    {
        printf("test5 2 %d\n", s5.a);
        exit(1);
    }

    if (s5.b != 8)
    {
        printf("test5 3 %d\n", s5.b);
        exit(1);
    }
}

/******************************************/

int main()
{
    test1();
    test2();
    test3();
    test4();
    test5();

    return 0;
}
