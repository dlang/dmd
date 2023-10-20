// https://issues.dlang.org/show_bug.cgi?id=22513

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

struct S s;
int* p = &s.t.x;

struct S { int a; struct T t; };
struct T { int b; int x; };

int main()
{
    s.t.x = 5;
    assert(*p == 5, 1);
    return 0;
}
