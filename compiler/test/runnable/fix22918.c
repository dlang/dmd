// https://issues.dlang.org/show_bug.cgi?id=22918

const char c;
const double dbl;
enum E { a = 1, };
const enum E myE;

int printf(char *, ...);
void exit(int);

void assert(int b, int line)
{
    if (!b)
    {
        printf("failed test %d\n", line);
        exit(1);
    }
}

int main()
{
    printf("%d\n", (int)c);
    printf("%lf\n", dbl);
    printf("%d\n", (int)myE);

    char ca[2] = {0};
    printf("%d %d\n", (int)ca[0], (int)ca[1]);

    assert(c == 0, 1);
    assert(dbl == 0.0, 2);
    assert(myE == 0, 3);
    assert(ca[0] == 0, 4);
    assert(ca[1] == 0, 5);

    return 0;
}
