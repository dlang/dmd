
int printf(const char *, ...);
void exit(int);

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

int main()
{
    test1();
    return 0;
}

