
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
    for (int i = 0; i < 3; ++i)
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
    for (int i = 0; i < 3; ++i)
    {
        for (int j = 0; j < 2; ++j)
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
    for (int i = 0; i < 3; ++i)
    {
        for (int j = 0; j < 2; ++j)
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
    for (int i = 0; i < 3; ++i)
    {
        for (int j = 0; j < 2; ++j)
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
    for (int i = 0; i < 3; ++i)
    {
        for (int j = 0; j < 2; ++j)
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

    return 0;
}

