// https://issues.dlang.org/show_bug.cgi?id=22333

int printf(const char *, ...);
void exit(int);

int gnumbers[4] = {1,2,3,4};

int num1(void)
{
    int numbers[4] = {1, 2, 3, 4};
    return numbers[1];
}

int num2(void)
{
    int numbers[] = {1, 2, 3, 4};
    return numbers[1];
}

int main()
{
    printf("%d %d %d\n", gnumbers[1], num1(), num2());
    if (gnumbers[1] != 2)
        exit(1);
    if (num1() != 2)
        exit(1);
    if (num2() != 2)
        exit(1);
    return 0;
}
