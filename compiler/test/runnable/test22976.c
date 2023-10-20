/* https://issues.dlang.org/show_bug.cgi?id=22976
 */

// https://issues.dlang.org/show_bug.cgi?id=22705

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

struct S { unsigned short xs[2]; };
struct S s1 = { { 0xabcd, 0x1234 } };
struct S *sp = &s1;

int main()
{
    unsigned short *xp = &sp->xs[1];
    printf("%hx\n", *xp); // 34ab
    assert(*xp == 0x1234, 1);

    unsigned short x = sp->xs[1];
    printf("%hx\n", x); // 1234
    assert(x == 0x1234, 2);

    return 0;
}
