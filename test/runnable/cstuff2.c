
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

int main()
{
    test1();
    test2();
    test3();
    return 0;
}

