// REQUIRED_ARGS: -defaultlib= -betterC

import core.stdc.stdio : printf;

struct S
{
    void foo()
    {
        printf("call S.foo, &this = %p\n", &this);
    }
}

void test1()
{
    import std.algorithm : map;
    int[3] sa = [1,2,3];
    int[3] r;
    size_t i = 0;
    foreach (e; sa[].map!(a => a * 2))
    {
        r[i] = e;
        printf("[%d] e = %d\n", i, e);
        ++i;
    }
    assert(r[0] == 2 && r[1] == 4 && r[2] == 6);
}

extern(C) int main(int argc, char** argv)
{
    S s;
    s.foo();

    assert(1);

    int[3] sa;
    int[] a = sa[];
    //a[] = 1;  // requires _memset32

    int[] b = a[0..1];

    int n = a[0];

    test1();

    return 0;
}
