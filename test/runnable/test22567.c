// https://issues.dlang.org/show_bug.cgi?id=22576

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

typedef struct S { int x; } S;

void test(int i, S s)
{
   int a[1] = { i };
   assert(a[0] == 3, 1);
   S b[1] = { (S){2} };
   assert(b[0].x == 2, 2);
   S c[1] = { s };
   assert(c[0].x == 7, 3);
}

int main()
{
    S s;
    s.x = 7;
    test(3, s);
    return 0;
}
