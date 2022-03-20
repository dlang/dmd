// https://issues.dlang.org/show_bug.cgi?id=22897

int printf(const char*, ...);
void exit(int);

static int bob(void) { return 1; }

static int other(void);
int main()
{
    int (*fn)(void) = other;
    //printf("%d\n", fn());
    if (fn() != 2)
        exit(1);
    return 0;
}
static int other(void) { return 2; }
