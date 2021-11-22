// https://issues.dlang.org/show_bug.cgi?id=22500

int printf(const char *s, ...);
void exit(int);

void assert(int b, int line)
{
    if (!b)
    {
        printf("failed test %d\n", line);
        exit(1);
    }
}

int foo(int i) { return i + 7; }

int (*fp)(int) = foo;

int main()
{
    int x = (*fp)(3);
    assert(x == 10, 1);
    return 0;
}
