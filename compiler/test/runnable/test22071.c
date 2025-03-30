// https://issues.dlang.org/show_bug.cgi?id=22071

int printf(const char *, ...);

struct S { int a, b; };

struct S *abc = &(struct S){ 1, 2 };

int test()
{
    struct S *var = &(struct S){ 1, 2 };
    return var->b;
}

_Static_assert(test() == 2, "in");

int main()
{
    int i = test();
    if (i != 2)
        return 1;
    int j = abc->b;
    if (j != 2)
        return 1;
    return 0;
}
