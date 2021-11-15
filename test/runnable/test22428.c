// https://issues.dlang.org/show_bug.cgi?id=22428

int printf(const char *, ...);

static int staticFunc(int i) { return i * 2; }

int main()
{
    int x = staticFunc(3);
    printf("%d\n", x);
    if (x != 6)
        return 1;

    int (*fp)(int);
    fp = &staticFunc;
    x = (*fp)(5);
    printf("%d\n", x);
    if (x != 10)
        return 1;

    return 0;
}
