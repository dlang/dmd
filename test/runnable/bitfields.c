int printf(const char *fmt, ...);
void exit(int);

struct S
{
    int a:2, b:4;
};

_Static_assert(sizeof(struct S) == 4, "in");

int main()
{
    struct S s;
    s.a = 3;
    if (s.a != -1)
    {
        printf("error %d\n", s.a);
        exit(1);
    }

    s.b = 4;
    if (s.b != 4)
    {
        printf("error %d\n", s.b);
        exit(1);
    }

    return 0;
}
