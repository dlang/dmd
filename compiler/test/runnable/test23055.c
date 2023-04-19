// https://issues.dlang.org/show_bug?id=23055

//#include <stdio.h>

int fn()
{
    int *p = (int[1]){0};
    *p = 0;
    return *p;
}

_Static_assert(fn() == 0, "");

int main()
{
//    printf("fn(): %d\n", fn());
    return fn();
}
