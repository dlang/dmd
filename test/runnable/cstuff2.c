
int printf(const char *, ...);
void exit(int);

/*********************************/

void test1()
{
    static int a[3] = {1, 2, 3};
    if (a[0] != 1 ||
        a[1] != 2 ||
        a[2] != 3)
    {
        printf("error 1\n");
        exit(1);
    }
}

/*********************************/

void test2()
{
    static int a[4] = {1, 2, 3};
    if (a[0] != 1 ||
        a[1] != 2 ||
        a[2] != 3 ||
        a[3] != 0)
    {
        printf("error 2\n");
        exit(1);
    }
}

/*********************************/

void test3()
{
    static int a[] = {1, 2, 3};
    if (sizeof(a) != 3 * sizeof(int) ||
        a[0] != 1 ||
        a[1] != 2 ||
        a[2] != 3)
    {
        printf("error 3\n");
        exit(1);
    }
}

/*********************************/

void test4()
{
    static int a[3] = {1, 2, 3};
    int i;
    for (i = 0; i < 3; ++i)
    {
        if (a[i] != i + 1)
        {
            printf("error 4\n");
            exit(1);
        }
    }
}

/*********************************/

void test5()
{
    static int b[3][2] = { 1,2,3,4,5,6 };
    int i;
    for (i = 0; i < 3; ++i)
    {
        int j;
        for (j = 0; j < 2; ++j)
        {
            if (b[i][j] != i * 2 + j + 1)
            {
                printf("error 5\n");
                exit(1);
            }
        }
    }
}

/*********************************/

void test6()
{
    static int c[3][2] = { {1,2},{3,4},{5,6} };
    int i;
    for (i = 0; i < 3; ++i)
    {
        int j;
        for (j = 0; j < 2; ++j)
        {
            if (c[i][j] != i * 2 + j + 1)
            {
                printf("error 6\n");
                exit(1);
            }
        }
    }
}

/*********************************/

void test7()
{
    static int d[3][2] = { {1,2},3,4,{5,6} };
    int i;
    for (i = 0; i < 3; ++i)
    {
        int j;
        for (j = 0; j < 2; ++j)
        {
            if (d[i][j] != i * 2 + j + 1)
            {
                printf("error 7\n");
                exit(1);
            }
        }
    }
}

/*********************************/

void test8()
{
    static int d[3][2] = { {1,2} };
    int i;
    for (i = 0; i < 3; ++i)
    {
        int j;
        for (j = 0; j < 2; ++j)
        {
            if (i == 0)
            {
                if (d[i][j] != j + 1)
                {
                    printf("error 8a\n");
                    exit(1);
                }
            }
            else if (d[i][j] != 0)
            {
                printf("error 8b\n");
                exit(1);
            }
        }
    }
}

/*********************************/

void test8a()
{
    int i;
    static int a[3] = { 1,2,3 };
    // Casting to an array type is not allowed by C11, but
    // CompoundLiterals are not there yet to test this
    // grammar
    i = ((int[3])a)[2];
    if (i != 3) { printf("test8a\n"); exit(1); }
}

/*********************************/

void test8b()
{
    struct S { int a, b; };
    static struct S ax[3] = { 0x11,0x22,0x33,0 };
    //printf("%x %x %x %x\n", ax[0].a, ax[0].b, ax[1].a, ax[1].b);
    if (ax[0].a != 0x11 ||
        ax[0].b != 0x22 ||
        ax[1].a != 0x33 ||
        ax[1].b != 0) { printf("test8b\n"); exit(1); }
}

/*********************************/

void test9()
{
    int i = 1;            if (i != 1) { printf("error 9i\n"); exit(1); }
    int j = { 2 };        if (j != 2) { printf("error 9j\n"); exit(1); }
    int k = { 3,};        if (k != 3) { printf("error 9k\n"); exit(1); }

    static int l = 4;     if (l != 4) { printf("error 9l\n"); exit(1); }
    static int m = { 5 }; if (m != 5) { printf("error 9m\n"); exit(1); }
    static int n = { 6,}; if (n != 6) { printf("error 9n\n"); exit(1); }
}

/*********************************/

void test10()
{
    char s[6] = { "s" }; if (s[0] != 's')                     { printf("error 10s\n"); exit(1); }
    char t[7] = { "t" }; if (t[0] != 't' && t[1] != 0)        { printf("error 10t\n"); exit(1); }
    static char u[6] = { "u" }; if (u[0] != 'u')              { printf("error 10u\n"); exit(1); }
    static char v[7] = { "v" }; if (v[0] != 'v' && v[1] != 0) { printf("error 10v\n"); exit(1); }
}

/*********************************/

void test11()
{
    struct S { int a, b; };
    struct S s = { 1, 2 };
    if (s.a != 1 || s.b != 2) { printf("xx\n"); exit(1); }
    static struct S s2 = { 1, };
    if (s2.a != 1 || s2.b != 0) { printf("xx\n"); exit(1); }

    struct T { int a; struct { int b, c; }; };
    struct T t = { 1, 2, 3 };
    if (t.a != 1 || t.b != 2 || t.c != 3) { printf("xx\n"); exit(1); }

    struct U { int a; union { int b, c; }; int d; };
    struct U u = { 1, 2, 3 };
    if (u.a != 1 ||
        u.b != 2 ||
        u.c != 2 ||
        u.d != 3) { printf("%d %d %d %d\n", u.a, u.b, u.c, u.d); exit(1); }
}

/*********************************/

void test12()
{
    int i;
    i = (int) { 3 };
    if (i != 3) { printf("test12\n"); exit(1); }
}

/*********************************/

int main()
{
    test1();
    test2();
    test3();
    test4();
    test5();
    test6();
    test7();
    test8();
    test8a();
    test8b();
    test9();
    test10();
    test11();
    test12();

    return 0;
}

